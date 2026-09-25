/* ============================================================================
   SIGMA — Bloque 247
   SIGMA RUL: VIDA UTIL RESTANTE DEL REPUESTO INSTALADO
   ----------------------------------------------------------------------------

   El segundo objetivo de SIGMA AI, por el mismo camino que SIGMA FAILURE
   (bloques 245/246): dataset sin fuga desde la base, entrenamiento local,
   registro en Azure ML, puntuacion dentro de la API.

   LA UNIDAD ES LA INSTALACION DE UN REPUESTO
     Una fila es (Componente_Repuesto_Instalacion, fecha de corte): un
     repuesto puesto en un componente, mirado en una fecha en que todavia
     estaba puesto. Las caracteristicas cuentan lo que paso hasta el corte
     (horas y dias corriendo, vida nominal, cuanto de ella va consumida,
     instalaciones anteriores del mismo repuesto en ese componente y lo que
     duraron, el estado del equipo al corte) y el label es CUANTO MAS DURO:
     dias (y horas, si hay horometro) entre el corte y el retiro.

   LA CENSURA NO ES UN DETALLE (modelo logico §11.3, regla 2)
     Un retiro preventivo, una mejora o "sigue puesto hoy" no dicen cuanto
     duro: dicen que duro AL MENOS eso. `CENSURADO = 1` los marca y el
     entrenador los usa como cota inferior (regresion AFT log-normal con
     censura), no como si hubieran fallado ese dia. Tratarlos como fallas
     ensena la politica de mantenimiento vigente, no el deterioro.

   LO QUE SALE
     Dias restantes (mediana), un intervalo del 80 % y la fecha estimada,
     en `Prediccion` con la instalacion como sujeto
     (pre_componente_repuesto_instalacion), y alerta PREDICCION RIESGO si
     quedan menos dias que el umbral del modelo.

   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO

/* ---------------------------------------------------------------------------
   1. EL MODELO Y SUS CARACTERISTICAS
   --------------------------------------------------------------------------- */
DECLARE @ROOT INT = 1, @MPR INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA RUL')
    INSERT INTO [dbo].[Modelo_Predictivo]
        ([mpr_cliente], [mpr_modelo_objetivo], [mpr_codigo], [mpr_nombre], [mpr_descripcion]
        ,[mpr_horizonte_dia], [mpr_umbral_alerta], [mpr_umbral_critico]
        ,[mpr_usuario_creacion], [mpr_fecha_creacion], [mpr_habilitado])
    VALUES
        (NULL, 2, N'SIGMA RUL', N'Vida util restante del repuesto instalado'
        ,N'Regresion de supervivencia (AFT log-normal con censura) sobre las instalaciones de repuestos: horas y dias corriendo, vida nominal y consumida, historial del mismo repuesto en ese componente y estado del equipo al corte. Devuelve los dias restantes (mediana) con un intervalo del 80 % y la fecha estimada. Un retiro preventivo cuenta como "duro al menos", nunca como falla.'
        /* Los umbrales del catalogo van de 0 a 1 (CK_MPR_UMBRAL): aqui son
           FRACCION DEL HORIZONTE. Horizonte 90 dias; se avisa con menos de
           30 dias restantes (0,3333) y es critico con menos de 7 (0,0778). */
        ,90, 0.333333, 0.077778
        ,@ROOT, GETDATE(), 1)

SELECT @MPR = [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA RUL'

DECLARE @C TABLE (codigo NVARCHAR(100), etiqueta NVARCHAR(200), descripcion NVARCHAR(500), tipo INT, ventana INT, agregacion NVARCHAR(30), orden INT)
INSERT INTO @C VALUES
 (N'DIAS_CORRIENDO',        N'Dias instalado',                     N'Dias entre la instalacion del repuesto y el corte.',                                          1, NULL, NULL,        1)
,(N'HORAS_CORRIENDO',       N'Horas corriendo',                    N'Horas del horometro del componente desde la instalacion hasta el corte (0 si no hay).',        1, NULL, N'ULTIMO',   2)
,(N'VIDA_NOMINAL_HORAS',    N'Vida nominal (horas)',               N'Vida util declarada del repuesto en horas (0 si no se declaro).',                            1, NULL, NULL,        3)
,(N'VIDA_NOMINAL_DIAS',     N'Vida nominal (dias)',                N'Vida util declarada del repuesto en dias (0 si no se declaro).',                             1, NULL, NULL,        4)
,(N'RATIO_CONSUMIDO',       N'Vida consumida',                     N'Horas corriendo / vida nominal en horas (o dias / dias); 0 si no hay vida declarada.',        5, NULL, NULL,        5)
,(N'INSTALACIONES_PREVIAS', N'Instalaciones previas',              N'Cuantas veces se puso antes el mismo repuesto en ese componente.',                           1, NULL, N'CONTEO',   6)
,(N'DURACION_PREVIA_DIAS',  N'Duracion previa (dias)',             N'Cuanto duro en promedio el mismo repuesto en ese componente (0 si no hay historial).',         1, NULL, N'MEDIA',    7)
,(N'FALLOS_PREVIOS',        N'Retiros por falla previos',          N'Instalaciones anteriores del mismo repuesto en ese componente retiradas por falla.',            1, NULL, N'CONTEO',   8)
,(N'CRITICIDAD',            N'Criticidad del componente',          N'Nivel de criticidad del componente (o del equipo si no se declaro).',                        1, NULL, NULL,        9)
,(N'FALLAS_90D',            N'Fallas del equipo en 90 dias',       N'Fallas del equipo en los 90 dias anteriores al corte.',                                     1, 90,   N'CONTEO',  10)
,(N'DIAS_DESDE_MANTENCION', N'Dias desde la ultima mantencion',    N'Dias entre la ultima orden cerrada del equipo y el corte (365 si nunca).',                    1, NULL, N'MAX',     11)
,(N'MED_30D_ADVERTENCIA',   N'Mediciones sobre advertencia',       N'Mediciones del equipo sobre advertencia en 30 dias.',                                        1, 30,   N'CONTEO',  12)
,(N'MED_30D_RATIO_CRITICO', N'Cercania al limite critico',         N'Mayor cociente valor / critico observado en el equipo en 30 dias.',                          5, 30,   N'MAX',     13)
,(N'TENDENCIA_30D',         N'Tendencia en 30 dias',               N'Mayor pendiente (fraccion del limite por dia) entre las variables del equipo.',              5, 30,   N'PENDIENTE',14)

INSERT INTO [dbo].[Caracteristica_Modelo]
    ([cmo_modelo_predictivo], [cmo_codigo], [cmo_etiqueta], [cmo_descripcion], [cmo_caracteristica_tipo]
    ,[cmo_ventana_dia], [cmo_agregacion], [cmo_orden], [cmo_obligatoria]
    ,[cmo_usuario_creacion], [cmo_fecha_creacion], [cmo_habilitado])
SELECT @MPR, c.codigo, c.etiqueta, c.descripcion, c.tipo, c.ventana, c.agregacion, c.orden, 1, @ROOT, GETDATE(), 1
  FROM @C c
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Modelo] x WHERE x.[cmo_modelo_predictivo] = @MPR AND x.[cmo_codigo] = c.codigo)

DECLARE @NC INT = (SELECT COUNT(*) FROM [dbo].[Caracteristica_Modelo] WHERE [cmo_modelo_predictivo] = @MPR)
PRINT '--- Modelo SIGMA RUL: ' + LTRIM(STR(@MPR)) + ', caracteristicas: ' + LTRIM(STR(@NC)) + ' (esperado 14)'
GO

/* ---------------------------------------------------------------------------
   2. LAS CARACTERISTICAS DE CADA INSTALACION A UNA FECHA DE CORTE
      Las del equipo se toman de FNC_ML_ACTIVO_HISTORICO_V1 al mismo corte:
      una sola definicion de "estado del equipo", compartida por los
      modelos.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_ML_COMPONENTE_HISTORICO_V1] (@CLIENTE INT, @CORTE DATETIME)
RETURNS TABLE
AS
RETURN
(
    SELECT i.[cri_id]                                   AS INSTALACION
          ,i.[cri_activo_componente]                    AS COMPONENTE
          ,co.[aco_codigo]                              AS COMPONENTE_CODIGO
          ,co.[aco_nombre]                              AS COMPONENTE_NOMBRE
          ,co.[aco_activo]                              AS ACTIVO
          ,a.[act_codigo]                               AS ACTIVO_CODIGO
          ,i.[cri_repuesto]                             AS REPUESTO
          ,r.[rep_codigo]                               AS REPUESTO_CODIGO
          ,r.[rep_nombre]                               AS REPUESTO_NOMBRE
          ,i.[cri_fecha_instalacion_utc]                AS INSTALADO
          ,@CORTE                                       AS CORTE
          /* ---- caracteristicas: hasta el corte ---- */
          ,DATEDIFF(DAY, i.[cri_fecha_instalacion_utc], @CORTE)                       AS DIAS_CORRIENDO
          /* Si el horometro marca menos que la lectura inicial (reinicio o dato
             mal anotado) no hay horas confiables: 0, no un negativo. */
          ,CAST(CASE WHEN med.LECTURA >= i.[cri_lectura_inicial] THEN med.LECTURA - i.[cri_lectura_inicial] ELSE 0 END AS DECIMAL(18,2)) AS HORAS_CORRIENDO
          ,ISNULL(r.[rep_vida_util_hora], 0)                                            AS VIDA_NOMINAL_HORAS
          ,ISNULL(r.[rep_vida_util_dia], 0)                                             AS VIDA_NOMINAL_DIAS
          ,CAST(CASE WHEN ISNULL(r.[rep_vida_util_hora], 0) > 0 AND med.LECTURA >= i.[cri_lectura_inicial]
                          THEN (med.LECTURA - i.[cri_lectura_inicial]) / r.[rep_vida_util_hora]
                     WHEN ISNULL(r.[rep_vida_util_dia], 0) > 0
                          THEN CAST(DATEDIFF(DAY, i.[cri_fecha_instalacion_utc], @CORTE) AS DECIMAL(18,6)) / r.[rep_vida_util_dia]
                     ELSE 0 END AS DECIMAL(18,6))                                       AS RATIO_CONSUMIDO
          ,ISNULL(pr.N, 0)                                                              AS INSTALACIONES_PREVIAS
          ,ISNULL(pr.DURACION, 0)                                                       AS DURACION_PREVIA_DIAS
          ,ISNULL(pr.FALLOS, 0)                                                         AS FALLOS_PREVIOS
          ,ISNULL(co.[aco_criticidad_nivel], ISNULL(a.[act_criticidad_nivel], 0))      AS CRITICIDAD
          ,ISNULL(eq.FALLAS_90D, 0)                                                     AS FALLAS_90D
          ,ISNULL(eq.DIAS_DESDE_MANTENCION, 365)                                        AS DIAS_DESDE_MANTENCION
          ,ISNULL(eq.MED_30D_ADVERTENCIA, 0)                                            AS MED_30D_ADVERTENCIA
          ,ISNULL(eq.MED_30D_RATIO_CRITICO, 0)                                          AS MED_30D_RATIO_CRITICO
          ,ISNULL(eq.TENDENCIA_30D, 0)                                                  AS TENDENCIA_30D
          /* ---- label: cuanto mas duro desde el corte ---- */
          ,CASE WHEN i.[cri_fecha_retiro_utc] IS NOT NULL THEN DATEDIFF(DAY, @CORTE, i.[cri_fecha_retiro_utc])
                ELSE DATEDIFF(DAY, @CORTE, GETUTCDATE()) END                            AS DIAS_RESTANTES
          ,CASE WHEN i.[cri_fecha_retiro_utc] IS NOT NULL AND i.[cri_lectura_final] >= med.LECTURA
                THEN CAST(i.[cri_lectura_final] - med.LECTURA AS DECIMAL(18,2)) END     AS HORAS_RESTANTES
          /* 0 = se retiro por falla o desgaste (se sabe cuanto duro);
             1 = sigue puesto o se retiro por otro motivo (duro AL MENOS eso) */
          ,CASE WHEN i.[cri_fecha_retiro_utc] IS NOT NULL
                 AND (i.[cri_fallo] = 1 OR i.[cri_repuesto_retiro_motivo] IN (1, 2)) THEN 0
                ELSE 1 END                                                              AS CENSURADO
      FROM [dbo].[Componente_Repuesto_Instalacion] i
      JOIN [dbo].[Activo_Componente] co ON co.[aco_id] = i.[cri_activo_componente]
      JOIN [dbo].[Activo] a ON a.[act_id] = co.[aco_activo]
      JOIN [dbo].[Repuesto] r ON r.[rep_id] = i.[cri_repuesto]
      OUTER APPLY (SELECT MAX(l.[aml_valor_acumulado]) AS LECTURA
                     FROM [dbo].[Activo_Medidor_Lectura] l
                    WHERE l.[aml_activo_medidor] = i.[cri_activo_medidor]
                      AND l.[aml_fecha_lectura_utc] < @CORTE) med
      OUTER APPLY (SELECT COUNT(*) AS N
                          ,AVG(CAST(DATEDIFF(DAY, p.[cri_fecha_instalacion_utc], p.[cri_fecha_retiro_utc]) AS DECIMAL(18,2))) AS DURACION
                          ,SUM(CASE WHEN p.[cri_fallo] = 1 OR p.[cri_repuesto_retiro_motivo] IN (1, 2) THEN 1 ELSE 0 END) AS FALLOS
                     FROM [dbo].[Componente_Repuesto_Instalacion] p
                    WHERE p.[cri_activo_componente] = i.[cri_activo_componente]
                      AND p.[cri_repuesto] = i.[cri_repuesto]
                      AND p.[cri_id] <> i.[cri_id]
                      AND p.[cri_fecha_retiro_utc] IS NOT NULL
                      AND p.[cri_fecha_retiro_utc] <= i.[cri_fecha_instalacion_utc]) pr
      OUTER APPLY (SELECT f.FALLAS_90D, f.DIAS_DESDE_MANTENCION, f.MED_30D_ADVERTENCIA, f.MED_30D_RATIO_CRITICO, f.TENDENCIA_30D
                     FROM [dbo].[FNC_ML_ACTIVO_HISTORICO_V1](@CLIENTE, @CORTE) f
                    WHERE f.ACTIVO = co.[aco_activo]) eq
     WHERE i.[cri_cliente] = @CLIENTE
       AND i.[cri_fecha_instalacion_utc] < @CORTE
       AND (i.[cri_fecha_retiro_utc] IS NULL OR i.[cri_fecha_retiro_utc] > @CORTE)
)
GO
PRINT '--- FNC_ML_COMPONENTE_HISTORICO_V1 creada.'
GO

/* ---------------------------------------------------------------------------
   3. EL DATASET
      Igual que el de falla: un corte cada @PASO_DIAS. @HOY = 1 devuelve las
      instalaciones que siguen puestas, al corte de ahora (sin label util).
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML_DATASET_RUL]
     @CLIENTE   INT
    ,@USUARIO   INT      = NULL
    ,@DESDE     DATE     = NULL
    ,@HASTA     DATE     = NULL
    ,@PASO_DIAS INT      = 7
    ,@HOY       BIT      = 0
    ,@ACTIVO    INT      = NULL
AS
SET NOCOUNT ON
    DECLARE @T TABLE (
        INSTALACION INT, COMPONENTE INT, COMPONENTE_CODIGO NVARCHAR(50), COMPONENTE_NOMBRE NVARCHAR(200), ACTIVO INT, ACTIVO_CODIGO NVARCHAR(50)
       ,REPUESTO INT, REPUESTO_CODIGO NVARCHAR(50), REPUESTO_NOMBRE NVARCHAR(200), INSTALADO DATETIME, CORTE DATETIME
       ,DIAS_CORRIENDO INT, HORAS_CORRIENDO DECIMAL(18,2), VIDA_NOMINAL_HORAS INT, VIDA_NOMINAL_DIAS INT, RATIO_CONSUMIDO DECIMAL(18,6)
       ,INSTALACIONES_PREVIAS INT, DURACION_PREVIA_DIAS DECIMAL(18,2), FALLOS_PREVIOS INT, CRITICIDAD INT
       ,FALLAS_90D INT, DIAS_DESDE_MANTENCION INT, MED_30D_ADVERTENCIA INT, MED_30D_RATIO_CRITICO DECIMAL(18,6), TENDENCIA_30D DECIMAL(18,6)
       ,DIAS_RESTANTES INT, HORAS_RESTANTES DECIMAL(18,2), CENSURADO BIT)

    IF @HOY = 1
    BEGIN
        INSERT INTO @T SELECT * FROM [dbo].[FNC_ML_COMPONENTE_HISTORICO_V1](@CLIENTE, GETUTCDATE())
         WHERE @ACTIVO IS NULL OR ACTIVO = @ACTIVO
    END
    ELSE
    BEGIN
        IF @PASO_DIAS IS NULL OR @PASO_DIAS < 1 SET @PASO_DIAS = 7
        IF @DESDE IS NULL
            SELECT @DESDE = CAST(MIN([cri_fecha_instalacion_utc]) AS DATE) FROM [dbo].[Componente_Repuesto_Instalacion] WHERE [cri_cliente] = @CLIENTE
        IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -365, CAST(GETUTCDATE() AS DATE))
        IF @HASTA IS NULL SET @HASTA = CAST(GETUTCDATE() AS DATE)

        DECLARE @CORTE DATETIME = DATEADD(DAY, 1, CAST(@DESDE AS DATETIME))
        WHILE @CORTE <= CAST(@HASTA AS DATETIME)
        BEGIN
            INSERT INTO @T SELECT * FROM [dbo].[FNC_ML_COMPONENTE_HISTORICO_V1](@CLIENTE, @CORTE)
             WHERE @ACTIVO IS NULL OR ACTIVO = @ACTIVO
            SET @CORTE = DATEADD(DAY, @PASO_DIAS, @CORTE)
        END
    END

    SELECT * FROM @T ORDER BY CORTE, INSTALACION
GO
PRINT '--- API_SEL_ML_DATASET_RUL creado.'
GO

/* ---------------------------------------------------------------------------
   4. GUARDAR UNA PREDICCION DE VIDA RESTANTE
      El sujeto es la instalacion (pre_componente_repuesto_instalacion), con
      su componente y equipo. Dias restantes = mediana; intervalo del 80 %.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_PREDICCION_RUL]
     @ID              INT OUTPUT
    ,@CLIENTE         INT
    ,@USUARIO         INT
    ,@VERSION         INT
    ,@INSTALACION     INT
    ,@DIAS            DECIMAL(18,2)
    ,@DIAS_INFERIOR   DECIMAL(18,2) = NULL
    ,@DIAS_SUPERIOR   DECIMAL(18,2) = NULL
    ,@CONFIANZA       DECIMAL(18,6) = 0.80
    ,@CARACTERISTICAS NVARCHAR(MAX) = NULL
    ,@EXPLICACIONES   NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT, @ESTADO INT, @UMB_ALERTA DECIMAL(18,6), @UMB_CRITICO DECIMAL(18,6)
    /* Los umbrales del modelo son fraccion del horizonte: se pasan a dias. */
    SELECT @MPR = v.[mpv_modelo_predictivo], @ESTADO = v.[mpv_plan_version_estado]
          ,@UMB_ALERTA  = ROUND(ISNULL(m.[mpr_horizonte_dia], 90) * ISNULL(m.[mpr_umbral_alerta], 0.333333), 0)
          ,@UMB_CRITICO = ROUND(ISNULL(m.[mpr_horizonte_dia], 90) * ISNULL(m.[mpr_umbral_critico], 0.077778), 0)
      FROM [dbo].[Modelo_Predictivo_Version] v
      JOIN [dbo].[Modelo_Predictivo] m ON m.[mpr_id] = v.[mpv_modelo_predictivo]
     WHERE v.[mpv_id] = @VERSION AND v.[mpv_habilitado] = 1
    IF @MPR IS NULL BEGIN RAISERROR('1.- LA VERSION DEL MODELO NO EXISTE.', 16, 1) RETURN -1 END
    IF @ESTADO <> 2 BEGIN RAISERROR('2.- SOLO SE PUNTUA CON UNA VERSION PUBLICADA.', 16, 1) RETURN -1 END

    DECLARE @ACTIVO INT, @COMPONENTE INT
    SELECT @COMPONENTE = i.[cri_activo_componente], @ACTIVO = co.[aco_activo]
      FROM [dbo].[Componente_Repuesto_Instalacion] i
      JOIN [dbo].[Activo_Componente] co ON co.[aco_id] = i.[cri_activo_componente]
     WHERE i.[cri_id] = @INSTALACION AND i.[cri_cliente] = @CLIENTE
    IF @ACTIVO IS NULL BEGIN RAISERROR('3.- LA INSTALACION NO ES DEL CLIENTE EN SESION.', 16, 1) RETURN -1 END
    IF @DIAS < 0 SET @DIAS = 0

    DECLARE @HOY DATETIME = GETUTCDATE()
    DECLARE @UUID UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER,
        HASHBYTES('MD5', CONCAT(N'RUL|', @CLIENTE, N'|', @INSTALACION, N'|', @VERSION, N'|', CONVERT(NVARCHAR(10), @HOY, 112))))
    SELECT @ID = [pre_id] FROM [dbo].[Prediccion] WHERE [pre_uuid] = @UUID
    IF @ID IS NOT NULL RETURN 0

    DECLARE @SEV INT = CASE WHEN @DIAS <= @UMB_CRITICO THEN 4
                            WHEN @DIAS <= @UMB_ALERTA  THEN 3
                            WHEN @DIAS <= @UMB_ALERTA * 3 THEN 2
                            ELSE 1 END

    BEGIN TRY
        BEGIN TRANSACTION
        UPDATE p SET p.[pre_fecha_vigencia_hasta_utc] = @HOY
          FROM [dbo].[Prediccion] p
          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND p.[pre_cliente] = @CLIENTE
           AND p.[pre_componente_repuesto_instalacion] = @INSTALACION AND p.[pre_fecha_vigencia_hasta_utc] > @HOY

        INSERT INTO [dbo].[Prediccion]
            ([pre_uuid], [pre_cliente], [pre_modelo_predictivo_version], [pre_prediccion_estado]
            ,[pre_activo], [pre_activo_componente], [pre_componente_repuesto_instalacion]
            ,[pre_valor], [pre_dia_restante], [pre_fecha_evento_estimada_utc], [pre_severidad], [pre_confianza]
            ,[pre_intervalo_inferior], [pre_intervalo_superior]
            ,[pre_fecha_calculo_utc], [pre_fecha_vigencia_hasta_utc]
            ,[pre_usuario_creacion], [pre_fecha_creacion], [pre_habilitado])
        VALUES (@UUID, @CLIENTE, @VERSION, 1
               ,@ACTIVO, @COMPONENTE, @INSTALACION
               ,@DIAS, CAST(ROUND(@DIAS, 0) AS INT), DATEADD(HOUR, CAST(@DIAS * 24 AS INT), @HOY), @SEV, @CONFIANZA
               ,@DIAS_INFERIOR, @DIAS_SUPERIOR
               ,@HOY, DATEADD(DAY, 7, @HOY)
               ,@USUARIO, GETDATE(), 1)
        SET @ID = SCOPE_IDENTITY()

        IF @CARACTERISTICAS IS NOT NULL
            INSERT INTO [dbo].[Prediccion_Caracteristica]
                ([pcr_prediccion], [pcr_caracteristica_modelo], [pcr_valor], [pcr_imputado], [pcr_usuario_creacion], [pcr_fecha_creacion])
            SELECT @ID, c.[cmo_id], CAST(j.valor AS DECIMAL(18,6)), 0, @USUARIO, GETDATE()
              FROM OPENJSON(@CARACTERISTICAS) WITH (codigo NVARCHAR(100) '$.codigo', valor FLOAT '$.valor') j
              JOIN [dbo].[Caracteristica_Modelo] c ON c.[cmo_modelo_predictivo] = @MPR AND c.[cmo_codigo] = j.codigo

        IF @EXPLICACIONES IS NOT NULL
            INSERT INTO [dbo].[Prediccion_Explicacion]
                ([pex_prediccion], [pex_caracteristica_modelo], [pex_orden], [pex_texto], [pex_contribucion], [pex_direccion]
                ,[pex_valor_observado], [pex_valor_referencia], [pex_usuario_creacion], [pex_fecha_creacion])
            SELECT @ID, c.[cmo_id], ROW_NUMBER() OVER (ORDER BY ABS(ISNULL(j.contribucion, 0)) DESC)
                  ,LEFT(j.texto, 500), CAST(j.contribucion AS DECIMAL(18,6)), j.direccion
                  ,CAST(j.observado AS DECIMAL(18,6)), CAST(j.referencia AS DECIMAL(18,6)), @USUARIO, GETDATE()
              FROM OPENJSON(@EXPLICACIONES) WITH (codigo NVARCHAR(100) '$.codigo', texto NVARCHAR(500) '$.texto'
                                                 ,contribucion FLOAT '$.contribucion', direccion NVARCHAR(20) '$.direccion'
                                                 ,observado FLOAT '$.observado', referencia FLOAT '$.referencia') j
              LEFT JOIN [dbo].[Caracteristica_Modelo] c ON c.[cmo_modelo_predictivo] = @MPR AND c.[cmo_codigo] = j.codigo
             WHERE j.texto IS NOT NULL

        IF @DIAS <= @UMB_ALERTA
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] x
                            WHERE x.[ale_activo] = @ACTIVO AND x.[ale_alerta_tipo] = 4 AND x.[ale_alerta_estado] = 1
                              AND x.[ale_prediccion] IN (SELECT p.[pre_id] FROM [dbo].[Prediccion] p
                                                         WHERE p.[pre_componente_repuesto_instalacion] = @INSTALACION))
        BEGIN
            DECLARE @NOMBRE NVARCHAR(400) = (SELECT CONCAT(r.[rep_codigo], N' ', r.[rep_nombre], N' en ', co.[aco_codigo], N' ', co.[aco_nombre])
                                               FROM [dbo].[Componente_Repuesto_Instalacion] i
                                               JOIN [dbo].[Activo_Componente] co ON co.[aco_id] = i.[cri_activo_componente]
                                               JOIN [dbo].[Repuesto] r ON r.[rep_id] = i.[cri_repuesto]
                                              WHERE i.[cri_id] = @INSTALACION)
            DECLARE @INST INT = (SELECT [act_cliente_instalacion] FROM [dbo].[Activo] WHERE [act_id] = @ACTIVO)
            DECLARE @RAZON NVARCHAR(500) = (SELECT TOP 1 [pex_texto] FROM [dbo].[Prediccion_Explicacion] WHERE [pex_prediccion] = @ID ORDER BY [pex_orden])

            INSERT INTO [dbo].[Alerta]
                ([ale_uuid], [ale_cliente], [ale_cliente_instalacion], [ale_alerta_tipo], [ale_alerta_estado], [ale_severidad]
                ,[ale_titulo], [ale_descripcion], [ale_fecha_deteccion_utc], [ale_activo], [ale_prediccion]
                ,[ale_valor_observado], [ale_valor_umbral]
                ,[ale_fecha_primera_ocurrencia_utc], [ale_fecha_ultima_ocurrencia_utc], [ale_ocurrencias]
                ,[ale_usuario_creacion], [ale_fecha_creacion], [ale_habilitado])
            VALUES (NEWID(), @CLIENTE, @INST, 4, 1, @SEV
                   ,CONCAT(N'Vida util por agotarse: ', LEFT(@NOMBRE, 150))
                   ,CONCAT(N'SIGMA RUL estima unos ', CAST(CAST(ROUND(@DIAS, 0) AS INT) AS NVARCHAR(10)), N' dias de vida restante',
                           CASE WHEN @DIAS_INFERIOR IS NOT NULL THEN CONCAT(N' (entre ', CAST(CAST(ROUND(@DIAS_INFERIOR, 0) AS INT) AS NVARCHAR(10)),
                                                                            N' y ', CAST(CAST(ROUND(@DIAS_SUPERIOR, 0) AS INT) AS NVARCHAR(10)), N')') ELSE N'' END,
                           N'.', CASE WHEN @RAZON IS NOT NULL THEN N' ' + @RAZON ELSE N'' END)
                   ,@HOY, @ACTIVO, @ID
                   ,@DIAS, @UMB_ALERTA
                   ,@HOY, @HOY, 1
                   ,@USUARIO, GETDATE(), 1)
            UPDATE [dbo].[Prediccion] SET [pre_alerta] = SCOPE_IDENTITY() WHERE [pre_id] = @ID
        END
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @E NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@E, 16, 1)
        RETURN -1
    END CATCH
GO
PRINT '--- API_INS_PREDICCION_RUL creado.'
GO

/* ---------------------------------------------------------------------------
   5. API_SEL_ML @TIPO 5 para RUL: la prediccion nombra la instalacion
      (repuesto en componente) ademas del equipo. Se agregan columnas, sin
      quitar ninguna: la pantalla de FAILURE sigue leyendo las suyas.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML]
     @CLIENTE INT
    ,@USUARIO INT          = NULL
    ,@TIPO    INT          = 1
    ,@MODELO  NVARCHAR(50) = N'SIGMA FAILURE 30D'
    ,@ID      INT          = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)

    IF @TIPO = 1
        SELECT m.[mpr_id], m.[mpr_codigo], m.[mpr_nombre], m.[mpr_descripcion], m.[mpr_horizonte_dia]
              ,m.[mpr_umbral_alerta], m.[mpr_umbral_critico]
              ,o.[mob_nombre] AS OBJETIVO, o.[mob_codigo] AS OBJETIVO_CODIGO
              ,v.[mpv_id] AS VERSION_ID, v.[mpv_numero] AS VERSION_NUMERO, v.[mpv_algoritmo] AS VERSION_ALGORITMO
              ,v.[mpv_parametro] AS VERSION_PARAMETRO, v.[mpv_ruta] AS VERSION_RUTA, v.[mpv_hash] AS VERSION_HASH
              ,v.[mpv_registro] AS VERSION_REGISTRO, v.[mpv_fecha_verificacion_utc] AS VERSION_VERIFICADA
              ,v.[mpv_metrica_auc] AS VERSION_AUC, v.[mpv_metrica_precision] AS VERSION_PRECISION
              ,v.[mpv_metrica_recall] AS VERSION_RECALL, v.[mpv_metrica_f1] AS VERSION_F1, v.[mpv_metrica_mae] AS VERSION_MAE
              ,v.[mpv_fecha_publicacion] AS VERSION_PUBLICADA
              ,(SELECT COUNT(*) FROM [dbo].[Dataset_Entrenamiento] WHERE [den_modelo_predictivo] = m.[mpr_id] AND [den_cliente] = @CLIENTE) AS DATASETS
              ,(SELECT COUNT(*) FROM [dbo].[Entrenamiento_Ejecucion] WHERE [eej_modelo_predictivo] = m.[mpr_id]) AS CORRIDAS
              ,(SELECT COUNT(*) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_modelo_predictivo] = m.[mpr_id] AND [mpv_habilitado] = 1) AS VERSIONES
              ,(SELECT COUNT(*) FROM [dbo].[Prediccion] p JOIN [dbo].[Modelo_Predictivo_Version] pv ON pv.[mpv_id] = p.[pre_modelo_predictivo_version]
                 WHERE pv.[mpv_modelo_predictivo] = m.[mpr_id] AND p.[pre_cliente] = @CLIENTE AND p.[pre_habilitado] = 1
                   AND p.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE()) AS PREDICCIONES_VIGENTES
              ,(SELECT COUNT(*) FROM [dbo].[Activo] WHERE [act_cliente] = @CLIENTE AND [act_habilitado] = 1 AND [act_fusionado_en] IS NULL) AS ACTIVOS
              ,(SELECT COUNT(*) FROM [dbo].[Falla] WHERE [fal_cliente] = @CLIENTE AND [fal_habilitado] = 1) AS FALLAS
              ,(SELECT COUNT(*) FROM [dbo].[Activo_Medicion] WHERE [amd_cliente] = @CLIENTE) AS MEDICIONES
              ,(SELECT COUNT(*) FROM [dbo].[Componente_Repuesto_Instalacion] WHERE [cri_cliente] = @CLIENTE) AS INSTALACIONES
              ,(SELECT COUNT(*) FROM [dbo].[Componente_Repuesto_Instalacion] WHERE [cri_cliente] = @CLIENTE AND [cri_fecha_retiro_utc] IS NOT NULL) AS RETIROS
              ,(SELECT COUNT(*) FROM [dbo].[Analisis_Visual_Deteccion] d JOIN [dbo].[Analisis_Visual_Revision] r ON r.[avr_id] = d.[avd_analisis_visual_revision]
                 WHERE r.[avr_cliente] = @CLIENTE AND d.[avd_confirmado_humano] = 1 AND d.[avd_habilitado] = 1) AS IMAGENES_ETIQUETADAS
          FROM [dbo].[Modelo_Predictivo] m
          LEFT JOIN [dbo].[Modelo_Objetivo] o ON o.[mob_id] = m.[mpr_modelo_objetivo]
          LEFT JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_modelo_predictivo] = m.[mpr_id]
                                                        AND v.[mpv_plan_version_estado] = 2 AND v.[mpv_habilitado] = 1
         WHERE m.[mpr_id] = @MPR

    IF @TIPO = 2
        SELECT d.[den_id], d.[den_codigo], d.[den_nombre], d.[den_fecha_desde], d.[den_fecha_hasta]
              ,d.[den_fila_total], d.[den_fila_positiva], d.[den_hash_datos], d.[den_ruta], d.[den_observacion], d.[den_fecha_creacion]
              ,(SELECT COUNT(*) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_dataset_entrenamiento] = d.[den_id]) AS VERSIONES
          FROM [dbo].[Dataset_Entrenamiento] d
         WHERE d.[den_modelo_predictivo] = @MPR AND d.[den_cliente] = @CLIENTE AND d.[den_habilitado] = 1
         ORDER BY d.[den_id] DESC

    IF @TIPO = 3
        SELECT e.[eej_id], e.[eej_dataset_entrenamiento], e.[eej_modelo_predictivo_version]
              ,pe.[pes_nombre] AS ESTADO, e.[eej_entorno], e.[eej_fecha_inicio_utc], e.[eej_fecha_fin_utc]
              ,e.[eej_segundo_duracion], e.[eej_metrica], e.[eej_mensaje]
              ,v.[mpv_numero] AS VERSION_NUMERO, d.[den_codigo] AS DATASET_CODIGO
          FROM [dbo].[Entrenamiento_Ejecucion] e
          LEFT JOIN [dbo].[Proceso_Estado] pe ON pe.[pes_id] = e.[eej_proceso_estado]
          LEFT JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = e.[eej_modelo_predictivo_version]
          LEFT JOIN [dbo].[Dataset_Entrenamiento] d ON d.[den_id] = e.[eej_dataset_entrenamiento]
         WHERE e.[eej_modelo_predictivo] = @MPR
           AND (d.[den_id] IS NULL OR d.[den_cliente] = @CLIENTE)
         ORDER BY e.[eej_id] DESC

    IF @TIPO = 4
        SELECT v.[mpv_id], v.[mpv_numero], f.[mfo_codigo] AS FORMATO, v.[mpv_algoritmo], v.[mpv_hiperparametro], v.[mpv_parametro]
              ,v.[mpv_ruta], v.[mpv_registro], v.[mpv_hash], v.[mpv_byte], v.[mpv_fecha_verificacion_utc]
              ,v.[mpv_metrica_auc], v.[mpv_metrica_precision], v.[mpv_metrica_recall], v.[mpv_metrica_f1], v.[mpv_metrica_mae]
              ,ve.[pve_nombre] AS ESTADO, v.[mpv_plan_version_estado]
              ,v.[mpv_fecha_entrenamiento_utc], v.[mpv_fecha_publicacion], v.[mpv_fecha_retiro], v.[mpv_observacion]
              ,d.[den_codigo] AS DATASET_CODIGO, d.[den_fila_total] AS DATASET_FILAS, d.[den_fila_positiva] AS DATASET_POSITIVAS
          FROM [dbo].[Modelo_Predictivo_Version] v
          LEFT JOIN [dbo].[Modelo_Formato] f ON f.[mfo_id] = v.[mpv_modelo_formato]
          LEFT JOIN [dbo].[Plan_Version_Estado] ve ON ve.[pve_id] = v.[mpv_plan_version_estado]
          LEFT JOIN [dbo].[Dataset_Entrenamiento] d ON d.[den_id] = v.[mpv_dataset_entrenamiento]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND v.[mpv_habilitado] = 1
           AND (@ID IS NULL OR v.[mpv_id] = @ID)
           AND (d.[den_id] IS NULL OR d.[den_cliente] = @CLIENTE)
         ORDER BY v.[mpv_numero] DESC

    IF @TIPO = 5
        SELECT p.[pre_id], p.[pre_activo], a.[act_codigo] AS ACTIVO_CODIGO, a.[act_nombre] AS ACTIVO_NOMBRE
              ,p.[pre_componente_repuesto_instalacion] AS INSTALACION
              ,co.[aco_codigo] AS COMPONENTE_CODIGO, co.[aco_nombre] AS COMPONENTE_NOMBRE
              ,r.[rep_codigo] AS REPUESTO_CODIGO, r.[rep_nombre] AS REPUESTO_NOMBRE
              ,p.[pre_probabilidad], p.[pre_valor], p.[pre_dia_restante], p.[pre_intervalo_inferior], p.[pre_intervalo_superior]
              ,p.[pre_fecha_evento_estimada_utc], p.[pre_confianza]
              ,p.[pre_severidad], cn.[crn_nombre] AS SEVERIDAD
              ,pe.[pde_nombre] AS ESTADO, p.[pre_fecha_calculo_utc], p.[pre_fecha_vigencia_hasta_utc]
              ,v.[mpv_numero] AS VERSION_NUMERO, p.[pre_alerta], p.[pre_orden_trabajo]
              ,(SELECT STRING_AGG(x.[pex_texto], N' | ') WITHIN GROUP (ORDER BY x.[pex_orden])
                  FROM [dbo].[Prediccion_Explicacion] x WHERE x.[pex_prediccion] = p.[pre_id]) AS EXPLICACION
          FROM [dbo].[Prediccion] p
          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
          JOIN [dbo].[Activo] a ON a.[act_id] = p.[pre_activo]
          LEFT JOIN [dbo].[Componente_Repuesto_Instalacion] i ON i.[cri_id] = p.[pre_componente_repuesto_instalacion]
          LEFT JOIN [dbo].[Activo_Componente] co ON co.[aco_id] = i.[cri_activo_componente]
          LEFT JOIN [dbo].[Repuesto] r ON r.[rep_id] = i.[cri_repuesto]
          LEFT JOIN [dbo].[Criticidad_Nivel] cn ON cn.[crn_id] = p.[pre_severidad]
          LEFT JOIN [dbo].[Prediccion_Estado] pe ON pe.[pde_id] = p.[pre_prediccion_estado]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND p.[pre_cliente] = @CLIENTE AND p.[pre_habilitado] = 1
           AND p.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE()
         ORDER BY CASE WHEN p.[pre_dia_restante] IS NOT NULL THEN p.[pre_dia_restante] ELSE 999999 END, p.[pre_probabilidad] DESC, a.[act_codigo]

    IF @TIPO = 6
        SELECT c.[cmo_id], c.[cmo_codigo], c.[cmo_etiqueta], c.[cmo_descripcion], c.[cmo_ventana_dia], c.[cmo_agregacion], c.[cmo_orden]
          FROM [dbo].[Caracteristica_Modelo] c
         WHERE c.[cmo_modelo_predictivo] = @MPR AND c.[cmo_habilitado] = 1
         ORDER BY c.[cmo_orden]
GO
/* ---------------------------------------------------------------------------
   6. API_INS_ML_MODELO_VERSION con @MAE (la metrica de RUL, en dias)
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ML_MODELO_VERSION]
     @ID             INT OUTPUT
    ,@USUARIO        INT
    ,@MODELO         NVARCHAR(50)  = N'SIGMA FAILURE 30D'
    ,@DATASET        INT           = NULL
    ,@EJECUCION      INT           = NULL
    ,@FORMATO        NVARCHAR(20)  = N'ONNX'
    ,@ALGORITMO      NVARCHAR(100)
    ,@HIPERPARAMETRO NVARCHAR(MAX) = NULL
    ,@PARAMETRO      NVARCHAR(MAX)           -- JSON: caracteristicas, media, desviacion, coeficientes, intercepto
    ,@RUTA           NVARCHAR(500) = NULL    -- azureml://.../datastores/.../paths/... del artefacto
    ,@REGISTRO       NVARCHAR(200) = NULL    -- nombre:version en el registro de Azure ML
    ,@HASH           NVARCHAR(64)  = NULL
    ,@BYTE           BIGINT        = NULL
    ,@AUC            DECIMAL(18,6) = NULL
    ,@PRECISION      DECIMAL(18,6) = NULL
    ,@RECALL         DECIMAL(18,6) = NULL
    ,@F1             DECIMAL(18,6) = NULL
    ,@MAE            DECIMAL(18,6) = NULL    -- RUL: error absoluto medio en dias
    ,@OBSERVACION    NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)
    IF @MPR IS NULL BEGIN RAISERROR('1.- EL MODELO %s NO EXISTE.', 16, 1, @MODELO) RETURN -1 END
    DECLARE @MFO INT = (SELECT [mfo_id] FROM [dbo].[Modelo_Formato] WHERE [mfo_codigo] = @FORMATO)
    IF @MFO IS NULL BEGIN RAISERROR('2.- EL FORMATO %s NO EXISTE.', 16, 1, @FORMATO) RETURN -1 END
    IF ISJSON(@PARAMETRO) <> 1 BEGIN RAISERROR('3.- LOS PARAMETROS DEL MODELO DEBEN VENIR EN JSON.', 16, 1) RETURN -1 END
    IF JSON_QUERY(@PARAMETRO, '$.caracteristicas') IS NULL OR JSON_QUERY(@PARAMETRO, '$.coeficientes') IS NULL
       OR JSON_VALUE(@PARAMETRO, '$.intercepto') IS NULL
        BEGIN RAISERROR('4.- LOS PARAMETROS DEBEN TRAER caracteristicas, coeficientes E intercepto.', 16, 1) RETURN -1 END

    BEGIN TRY
        BEGIN TRANSACTION
        DECLARE @N INT = ISNULL((SELECT MAX([mpv_numero]) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_modelo_predictivo] = @MPR), 0) + 1

        INSERT INTO [dbo].[Modelo_Predictivo_Version]
            ([mpv_modelo_predictivo], [mpv_dataset_entrenamiento], [mpv_numero], [mpv_modelo_formato]
            ,[mpv_algoritmo], [mpv_hiperparametro], [mpv_parametro], [mpv_ruta], [mpv_registro], [mpv_hash], [mpv_byte]
            ,[mpv_metrica_auc], [mpv_metrica_precision], [mpv_metrica_recall], [mpv_metrica_f1], [mpv_metrica_mae]
            ,[mpv_plan_version_estado], [mpv_fecha_entrenamiento_utc], [mpv_observacion]
            ,[mpv_usuario_creacion], [mpv_fecha_creacion], [mpv_habilitado])
        VALUES (@MPR, @DATASET, @N, @MFO
               ,@ALGORITMO, @HIPERPARAMETRO, @PARAMETRO, @RUTA, @REGISTRO, @HASH, @BYTE
               ,@AUC, @PRECISION, @RECALL, @F1, @MAE
               ,1, GETUTCDATE(), @OBSERVACION            -- 1 = BORRADOR
               ,@USUARIO, GETDATE(), 1)
        SET @ID = SCOPE_IDENTITY()

        IF @EJECUCION IS NOT NULL
            UPDATE [dbo].[Entrenamiento_Ejecucion] SET [eej_modelo_predictivo_version] = @ID WHERE [eej_id] = @EJECUCION

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @E NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@E, 16, 1)
        RETURN -1
    END CATCH
GO

PRINT '--- Bloque 247: SIGMA RUL listo para el camino completo.'
GO
