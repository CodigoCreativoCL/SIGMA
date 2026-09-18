/* ============================================================================
   SIGMA — Bloque 245
   INVESTIGACION AZURE MACHINE LEARNING · SIGMA FAILURE 30 DIAS
   ----------------------------------------------------------------------------

   Lo que este bloque deja en la base es el CAMINO COMPLETO de un modelo que
   aprende, de punta a punta y sin costo:

     dataset (SQL, sin fuga)  ->  entrenamiento local (Python)  ->
     registro (Azure ML, gratis)  ->  puntuacion dentro de la API  ->
     Prediccion / Alerta, en las mismas tablas y pantallas que ya existen.

   POR QUE "SIGMA FAILURE 30 DIAS" Y NO OTRO
     Es el objetivo 1 del catalogo (PROBABILIDAD FALLA) y el unico de los
     tres de SIGMA AI cuyo label sale de una tabla que ya se llena en
     operacion: `Falla`. RUL necesita retiros de repuestos con motivo y
     VISION necesita imagenes etiquetadas; los dos vienen despues.

   LA REGLA QUE HACE QUE NO SEA HUMO (modelo logico §11.3)
     Cada fila del dataset es un (equipo, fecha de corte). Todo lo que se
     usa como caracteristica ocurrio ESTRICTAMENTE ANTES del corte y el
     label es "hubo una falla en los 30 dias SIGUIENTES". Ninguna columna
     mira hacia adelante; la funcion que las calcula lleva la fecha de corte
     como parametro para que eso sea verificable leyendo el SQL, no
     confiando en quien lo escribio.

   DONDE VIVEN LOS PESOS
     `Modelo_Predictivo_Version.mpv_parametro` guarda, en JSON, lo que hace
     falta para puntuar SIN el artefacto: la lista de caracteristicas, la
     media y desviacion con que se estandarizaron, los coeficientes y el
     intercepto. El .onnx queda registrado en Azure ML (mpv_ruta) y su hash
     en mpv_hash: es el artefacto oficial y el JSON es su copia legible. La
     API puntua con el JSON y el entrenador comprueba que el ONNX y el JSON
     den lo mismo antes de mandarlos; si no dan lo mismo no se registra.

   IDEMPOTENTE. Se puede volver a correr.
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
   1. LA COLUMNA QUE FALTABA: los pesos legibles de la version
   --------------------------------------------------------------------------- */
IF COL_LENGTH('dbo.Modelo_Predictivo_Version', 'mpv_parametro') IS NULL
    ALTER TABLE [dbo].[Modelo_Predictivo_Version] ADD [mpv_parametro] NVARCHAR(MAX) NULL
GO

/* ---------------------------------------------------------------------------
   2. EL MODELO Y SUS CARACTERISTICAS
   --------------------------------------------------------------------------- */
DECLARE @ROOT INT = 1, @MPR INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA FAILURE 30D')
    INSERT INTO [dbo].[Modelo_Predictivo]
        ([mpr_cliente], [mpr_modelo_objetivo], [mpr_codigo], [mpr_nombre], [mpr_descripcion]
        ,[mpr_horizonte_dia], [mpr_umbral_alerta], [mpr_umbral_critico]
        ,[mpr_usuario_creacion], [mpr_fecha_creacion], [mpr_habilitado])
    VALUES
        (NULL, 1, N'SIGMA FAILURE 30D', N'Probabilidad de falla a 30 dias'
        ,N'Clasificador entrenado sobre el historial de cada equipo: fallas, mantenciones, mediciones fuera de rango, tendencia, bitacora e indisponibilidad, todo anterior a la fecha de corte. Devuelve la probabilidad de que el equipo registre una falla en los 30 dias siguientes. Se entrena fuera de linea, se registra en Azure ML y se puntua dentro de la API con los pesos de la version publicada.'
        ,30, 0.50, 0.80, @ROOT, GETDATE(), 1)

SELECT @MPR = [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA FAILURE 30D'

DECLARE @C TABLE (codigo NVARCHAR(100), etiqueta NVARCHAR(200), descripcion NVARCHAR(500), tipo INT, ventana INT, agregacion NVARCHAR(30), orden INT)
INSERT INTO @C VALUES
 (N'CRITICIDAD',            N'Criticidad del equipo',              N'Nivel de criticidad declarado en la ficha (1 baja .. 4 critica).',                     1, NULL, NULL,        1)
,(N'EDAD_DIAS',             N'Edad en dias',                       N'Dias desde la puesta en marcha (o desde el alta en SIGMA si no se declaro).',           1, NULL, NULL,        2)
,(N'LECTURA_MEDIDOR',       N'Lectura del medidor',                N'Ultimo valor acumulado del horometro (u otro medidor) del equipo al corte.',            1, NULL, N'ULTIMO',   3)
,(N'FALLAS_90D',            N'Fallas en 90 dias',                  N'Fallas registradas en los 90 dias anteriores al corte.',                                1, 90,   N'CONTEO',   4)
,(N'FALLAS_TOTAL',          N'Fallas historicas',                  N'Fallas registradas desde siempre hasta el corte.',                                       1, NULL, N'CONTEO',   5)
,(N'DIAS_DESDE_FALLA',      N'Dias desde la ultima falla',         N'Dias entre la ultima falla y el corte (365 si nunca fallo).',                           1, NULL, N'MAX',      6)
,(N'OT_CERRADAS_180D',      N'Ordenes cerradas en 180 dias',       N'Ordenes de trabajo cerradas en los 180 dias anteriores al corte.',                      1, 180,  N'CONTEO',   7)
,(N'OT_CORRECTIVAS_180D',   N'Correctivas en 180 dias',            N'Ordenes correctivas (tipo CORRECTIVA o nacidas de una falla) en 180 dias.',             1, 180,  N'CONTEO',   8)
,(N'DIAS_DESDE_MANTENCION', N'Dias desde la ultima mantencion',    N'Dias entre la ultima orden cerrada y el corte (365 si nunca se intervino).',            1, NULL, N'MAX',      9)
,(N'MED_30D_N',             N'Mediciones en 30 dias',              N'Cantidad de mediciones de condicion en los 30 dias anteriores al corte.',               1, 30,   N'CONTEO',  10)
,(N'MED_30D_ADVERTENCIA',   N'Mediciones sobre advertencia',       N'Mediciones que superaron el valor de advertencia de su variable en 30 dias.',           1, 30,   N'CONTEO',  11)
,(N'MED_30D_RATIO_CRITICO', N'Cercania al limite critico',         N'Mayor cociente valor / valor critico observado en 30 dias (1 = en el limite).',         5, 30,   N'MAX',     12)
,(N'TENDENCIA_30D',         N'Tendencia en 30 dias',               N'Mayor pendiente (en fraccion del limite critico por dia) entre las variables medidas.',  5, 30,   N'PENDIENTE',13)
,(N'BITACORA_30D',          N'Incidentes en bitacora',             N'Incidentes y hallazgos anotados en la bitacora de planta en 30 dias.',                  1, 30,   N'CONTEO',  14)
,(N'INDISP_MIN_90D',        N'Minutos indisponible en 90 dias',    N'Minutos de indisponibilidad registrados en los 90 dias anteriores al corte.',           1, 90,   N'SUMA',    15)

INSERT INTO [dbo].[Caracteristica_Modelo]
    ([cmo_modelo_predictivo], [cmo_codigo], [cmo_etiqueta], [cmo_descripcion], [cmo_caracteristica_tipo]
    ,[cmo_ventana_dia], [cmo_agregacion], [cmo_orden], [cmo_obligatoria]
    ,[cmo_usuario_creacion], [cmo_fecha_creacion], [cmo_habilitado])
SELECT @MPR, c.codigo, c.etiqueta, c.descripcion, c.tipo, c.ventana, c.agregacion, c.orden, 1, @ROOT, GETDATE(), 1
  FROM @C c
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Modelo] x WHERE x.[cmo_modelo_predictivo] = @MPR AND x.[cmo_codigo] = c.codigo)

DECLARE @NC INT = (SELECT COUNT(*) FROM [dbo].[Caracteristica_Modelo] WHERE [cmo_modelo_predictivo] = @MPR)
PRINT '--- Modelo SIGMA FAILURE 30D: ' + LTRIM(STR(@MPR)) + ', caracteristicas: ' + LTRIM(STR(@NC)) + ' (esperado 15)'
GO

/* ---------------------------------------------------------------------------
   3. LAS CARACTERISTICAS DE CADA EQUIPO A UNA FECHA DE CORTE
      Es la «vista versionada» del modelo logico §11.1, con la fecha de
      corte como parametro: la misma funcion arma el dataset historico
      (muchos cortes) y la fila de hoy (un corte) que se puntua.
   --------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_ML_ACTIVO_HISTORICO_V1] (@CLIENTE INT, @CORTE DATETIME)
RETURNS TABLE
AS
RETURN
(
    SELECT a.[act_id]                                   AS ACTIVO
          ,a.[act_codigo]                               AS ACTIVO_CODIGO
          ,a.[act_nombre]                               AS ACTIVO_NOMBRE
          ,a.[act_cliente_instalacion]                  AS INSTALACION
          ,@CORTE                                       AS CORTE
          /* ---- caracteristicas: todo ANTES del corte ---- */
          ,ISNULL(a.[act_criticidad_nivel], 0)          AS CRITICIDAD
          ,DATEDIFF(DAY, ISNULL(a.[act_fecha_puesta_marcha], CAST(a.[act_fecha_creacion] AS DATE)), @CORTE) AS EDAD_DIAS
          ,ISNULL(med.LECTURA, 0)                       AS LECTURA_MEDIDOR
          ,ISNULL(f.FALLAS_90D, 0)                      AS FALLAS_90D
          ,ISNULL(f.FALLAS_TOTAL, 0)                    AS FALLAS_TOTAL
          ,ISNULL(DATEDIFF(DAY, f.ULTIMA, @CORTE), 365) AS DIAS_DESDE_FALLA
          ,ISNULL(ot.CERRADAS_180D, 0)                  AS OT_CERRADAS_180D
          ,ISNULL(ot.CORRECTIVAS_180D, 0)               AS OT_CORRECTIVAS_180D
          ,ISNULL(DATEDIFF(DAY, ot.ULTIMA, @CORTE), 365) AS DIAS_DESDE_MANTENCION
          ,ISNULL(m.N, 0)                               AS MED_30D_N
          ,ISNULL(m.ADVERTENCIA, 0)                     AS MED_30D_ADVERTENCIA
          ,ISNULL(m.RATIO_CRITICO, 0)                   AS MED_30D_RATIO_CRITICO
          ,ISNULL(t.PENDIENTE, 0)                       AS TENDENCIA_30D
          ,ISNULL(b.N, 0)                               AS BITACORA_30D
          ,ISNULL(i.MINUTOS, 0)                         AS INDISP_MIN_90D
          /* ---- label: los 30 dias SIGUIENTES; NULL si aun no se pueden observar ---- */
          ,CASE WHEN DATEADD(DAY, 30, @CORTE) > GETUTCDATE() THEN NULL
                WHEN EXISTS (SELECT 1 FROM [dbo].[Falla] x
                              WHERE x.[fal_activo] = a.[act_id] AND x.[fal_habilitado] = 1
                                AND x.[fal_fecha_deteccion_utc] >= @CORTE
                                AND x.[fal_fecha_deteccion_utc] <  DATEADD(DAY, 30, @CORTE)) THEN 1
                ELSE 0 END                              AS FALLO_EN_30D
      FROM [dbo].[Activo] a
      OUTER APPLY (SELECT MAX(l.[aml_valor_acumulado]) AS LECTURA
                     FROM [dbo].[Activo_Medidor] am
                     JOIN [dbo].[Activo_Medidor_Lectura] l ON l.[aml_activo_medidor] = am.[ame_id]
                    WHERE am.[ame_activo] = a.[act_id] AND l.[aml_fecha_lectura_utc] < @CORTE) med
      OUTER APPLY (SELECT SUM(CASE WHEN x.[fal_fecha_deteccion_utc] >= DATEADD(DAY, -90, @CORTE) THEN 1 ELSE 0 END) AS FALLAS_90D
                          ,COUNT(*) AS FALLAS_TOTAL
                          ,MAX(x.[fal_fecha_deteccion_utc]) AS ULTIMA
                     FROM [dbo].[Falla] x
                    WHERE x.[fal_activo] = a.[act_id] AND x.[fal_habilitado] = 1
                      AND x.[fal_fecha_deteccion_utc] < @CORTE) f
      OUTER APPLY (SELECT SUM(CASE WHEN o.[otr_fecha_fin_real_utc] >= DATEADD(DAY, -180, @CORTE) THEN 1 ELSE 0 END) AS CERRADAS_180D
                          ,SUM(CASE WHEN o.[otr_fecha_fin_real_utc] >= DATEADD(DAY, -180, @CORTE)
                                     AND (o.[otr_orden_trabajo_tipo] = 2 OR o.[otr_falla] IS NOT NULL) THEN 1 ELSE 0 END) AS CORRECTIVAS_180D
                          ,MAX(o.[otr_fecha_fin_real_utc]) AS ULTIMA
                     FROM [dbo].[Orden_Trabajo] o
                    WHERE o.[otr_activo] = a.[act_id] AND o.[otr_habilitado] = 1
                      AND o.[otr_orden_trabajo_estado] = 4              -- CERRADA
                      AND o.[otr_fecha_fin_real_utc] < @CORTE) ot
      OUTER APPLY (SELECT COUNT(*) AS N
                          ,SUM(CASE WHEN v.[ava_valor_advertencia] IS NOT NULL AND md.[amd_valor] >= v.[ava_valor_advertencia] THEN 1 ELSE 0 END) AS ADVERTENCIA
                          ,MAX(CASE WHEN ISNULL(v.[ava_valor_critico], 0) <> 0 THEN md.[amd_valor] / v.[ava_valor_critico] END) AS RATIO_CRITICO
                     FROM [dbo].[Activo_Medicion] md
                     JOIN [dbo].[Activo_Variable] v ON v.[ava_id] = md.[amd_activo_variable]
                    WHERE md.[amd_activo] = a.[act_id]
                      AND md.[amd_fecha_medicion_utc] >= DATEADD(DAY, -30, @CORTE)
                      AND md.[amd_fecha_medicion_utc] <  @CORTE) m
      /* La pendiente por variable (minimos cuadrados sobre dias, valor/critico)
         y de todas se toma la mayor: la que mas rapido se acerca al limite. */
      OUTER APPLY (SELECT MAX(CASE WHEN s.N >= 3 AND (s.N * s.SXX - s.SX * s.SX) <> 0
                                   THEN (s.N * s.SXY - s.SX * s.SY) / (s.N * s.SXX - s.SX * s.SX) END) AS PENDIENTE
                     FROM (SELECT md.[amd_activo_variable]
                                 ,COUNT(*) AS N
                                 ,SUM(p.X) AS SX, SUM(p.Y) AS SY, SUM(p.X * p.X) AS SXX, SUM(p.X * p.Y) AS SXY
                             FROM [dbo].[Activo_Medicion] md
                             JOIN [dbo].[Activo_Variable] v ON v.[ava_id] = md.[amd_activo_variable]
                            CROSS APPLY (SELECT CAST(DATEDIFF(SECOND, DATEADD(DAY, -30, @CORTE), md.[amd_fecha_medicion_utc]) AS FLOAT) / 86400.0 AS X
                                               ,CAST(md.[amd_valor] / v.[ava_valor_critico] AS FLOAT) AS Y) p
                            WHERE md.[amd_activo] = a.[act_id]
                              AND ISNULL(v.[ava_valor_critico], 0) <> 0
                              AND md.[amd_fecha_medicion_utc] >= DATEADD(DAY, -30, @CORTE)
                              AND md.[amd_fecha_medicion_utc] <  @CORTE
                            GROUP BY md.[amd_activo_variable]) s) t
      OUTER APPLY (SELECT COUNT(*) AS N
                     FROM [dbo].[Bitacora] bt
                    WHERE bt.[bit_activo] = a.[act_id]
                      AND bt.[bit_bitacora_tipo] IN (3, 5)               -- INCIDENTE, HALLAZGO
                      AND bt.[bit_fecha_evento_utc] >= DATEADD(DAY, -30, @CORTE)
                      AND bt.[bit_fecha_evento_utc] <  @CORTE) b
      OUTER APPLY (SELECT SUM(ISNULL(x.[ain_minuto], 0)) AS MINUTOS
                     FROM [dbo].[Activo_Indisponibilidad] x
                    WHERE x.[ain_activo] = a.[act_id] AND x.[ain_habilitado] = 1
                      AND x.[ain_fecha_inicio_utc] >= DATEADD(DAY, -90, @CORTE)
                      AND x.[ain_fecha_inicio_utc] <  @CORTE) i
     WHERE a.[act_cliente] = @CLIENTE
       AND a.[act_habilitado] = 1
       AND a.[act_fusionado_en] IS NULL
       AND ISNULL(a.[act_fecha_puesta_marcha], CAST(a.[act_fecha_creacion] AS DATE)) <= @CORTE
       AND (a.[act_fecha_baja] IS NULL OR a.[act_fecha_baja] > @CORTE)
)
GO
PRINT '--- FNC_ML_ACTIVO_HISTORICO_V1 creada.'
GO

/* ---------------------------------------------------------------------------
   4. EL DATASET: un corte cada @PASO_DIAS entre @DESDE y @HASTA
      @HOY = 1 devuelve solo el corte de ahora (sin label): es lo que se
      puntua. Por defecto @HASTA es hoy - 30, el ultimo corte cuyo label ya
      se puede observar.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML_DATASET_FALLA]
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
        ACTIVO INT, ACTIVO_CODIGO NVARCHAR(50), ACTIVO_NOMBRE NVARCHAR(200), INSTALACION INT, CORTE DATETIME
       ,CRITICIDAD INT, EDAD_DIAS INT, LECTURA_MEDIDOR DECIMAL(18,4)
       ,FALLAS_90D INT, FALLAS_TOTAL INT, DIAS_DESDE_FALLA INT
       ,OT_CERRADAS_180D INT, OT_CORRECTIVAS_180D INT, DIAS_DESDE_MANTENCION INT
       ,MED_30D_N INT, MED_30D_ADVERTENCIA INT, MED_30D_RATIO_CRITICO DECIMAL(18,6), TENDENCIA_30D DECIMAL(18,6)
       ,BITACORA_30D INT, INDISP_MIN_90D INT, FALLO_EN_30D BIT)

    IF @HOY = 1
    BEGIN
        INSERT INTO @T
        SELECT ACTIVO, ACTIVO_CODIGO, ACTIVO_NOMBRE, INSTALACION, CORTE, CRITICIDAD, EDAD_DIAS, LECTURA_MEDIDOR
              ,FALLAS_90D, FALLAS_TOTAL, DIAS_DESDE_FALLA, OT_CERRADAS_180D, OT_CORRECTIVAS_180D, DIAS_DESDE_MANTENCION
              ,MED_30D_N, MED_30D_ADVERTENCIA, MED_30D_RATIO_CRITICO, TENDENCIA_30D, BITACORA_30D, INDISP_MIN_90D, FALLO_EN_30D
          FROM [dbo].[FNC_ML_ACTIVO_HISTORICO_V1](@CLIENTE, GETUTCDATE())
         WHERE @ACTIVO IS NULL OR ACTIVO = @ACTIVO
    END
    ELSE
    BEGIN
        IF @PASO_DIAS IS NULL OR @PASO_DIAS < 1 SET @PASO_DIAS = 7

        /* El primer corte: cuando el cliente empezo a registrar algo. */
        IF @DESDE IS NULL
            SELECT @DESDE = CAST(MIN(x.f) AS DATE)
              FROM (SELECT MIN([amd_fecha_medicion_utc]) f FROM [dbo].[Activo_Medicion] WHERE [amd_cliente] = @CLIENTE
                    UNION ALL SELECT MIN([fal_fecha_deteccion_utc]) FROM [dbo].[Falla] WHERE [fal_cliente] = @CLIENTE
                    UNION ALL SELECT MIN([otr_fecha_creacion]) FROM [dbo].[Orden_Trabajo] WHERE [otr_cliente] = @CLIENTE) x
        IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -365, CAST(GETUTCDATE() AS DATE))
        IF @HASTA IS NULL SET @HASTA = DATEADD(DAY, -30, CAST(GETUTCDATE() AS DATE))

        DECLARE @CORTE DATETIME = CAST(@DESDE AS DATETIME)
        WHILE @CORTE <= CAST(@HASTA AS DATETIME)
        BEGIN
            INSERT INTO @T
            SELECT ACTIVO, ACTIVO_CODIGO, ACTIVO_NOMBRE, INSTALACION, CORTE, CRITICIDAD, EDAD_DIAS, LECTURA_MEDIDOR
                  ,FALLAS_90D, FALLAS_TOTAL, DIAS_DESDE_FALLA, OT_CERRADAS_180D, OT_CORRECTIVAS_180D, DIAS_DESDE_MANTENCION
                  ,MED_30D_N, MED_30D_ADVERTENCIA, MED_30D_RATIO_CRITICO, TENDENCIA_30D, BITACORA_30D, INDISP_MIN_90D, FALLO_EN_30D
              FROM [dbo].[FNC_ML_ACTIVO_HISTORICO_V1](@CLIENTE, @CORTE)
             WHERE @ACTIVO IS NULL OR ACTIVO = @ACTIVO

            SET @CORTE = DATEADD(DAY, @PASO_DIAS, @CORTE)
        END
    END

    SELECT * FROM @T ORDER BY CORTE, ACTIVO
GO
PRINT '--- API_SEL_ML_DATASET_FALLA creado.'
GO

/* ---------------------------------------------------------------------------
   5. REGISTRAR EL DATASET QUE SE USO
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ML_DATASET]
     @ID          INT OUTPUT
    ,@CLIENTE     INT
    ,@USUARIO     INT
    ,@MODELO      NVARCHAR(50)  = N'SIGMA FAILURE 30D'
    ,@CODIGO      NVARCHAR(50)
    ,@NOMBRE      NVARCHAR(200)
    ,@DESDE       DATE
    ,@HASTA       DATE
    ,@FILAS       INT
    ,@POSITIVAS   INT
    ,@HASH        NVARCHAR(64)  = NULL
    ,@RUTA        NVARCHAR(500) = NULL
    ,@OBSERVACION NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)
    IF @MPR IS NULL BEGIN RAISERROR('1.- EL MODELO %s NO EXISTE.', 16, 1, @MODELO) RETURN -1 END
    IF LTRIM(RTRIM(ISNULL(@CODIGO, N''))) = N'' BEGIN RAISERROR('2.- EL CODIGO DEL DATASET ES OBLIGATORIO.', 16, 1) RETURN -1 END

    /* El mismo codigo dos veces es el mismo dataset: se devuelve, no se duplica. */
    SELECT @ID = [den_id] FROM [dbo].[Dataset_Entrenamiento]
     WHERE [den_modelo_predictivo] = @MPR AND [den_cliente] = @CLIENTE AND [den_codigo] = @CODIGO
    IF @ID IS NOT NULL RETURN 0

    INSERT INTO [dbo].[Dataset_Entrenamiento]
        ([den_modelo_predictivo], [den_cliente], [den_codigo], [den_nombre], [den_fecha_desde], [den_fecha_hasta]
        ,[den_fila_total], [den_fila_positiva], [den_hash_datos], [den_ruta], [den_observacion]
        ,[den_usuario_creacion], [den_fecha_creacion], [den_habilitado])
    VALUES (@MPR, @CLIENTE, @CODIGO, @NOMBRE, @DESDE, @HASTA, @FILAS, @POSITIVAS, @HASH, @RUTA, @OBSERVACION
           ,@USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()
GO

/* ---------------------------------------------------------------------------
   6. REGISTRAR UNA CORRIDA DE ENTRENAMIENTO
      Corre fuera de la base (Python, en el equipo de quien entrena) y se
      informa terminada: PROCESADO con sus metricas o ERROR con su mensaje.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ML_ENTRENAMIENTO]
     @ID       INT OUTPUT
    ,@USUARIO  INT
    ,@MODELO   NVARCHAR(50)  = N'SIGMA FAILURE 30D'
    ,@DATASET  INT           = NULL
    ,@ENTORNO  NVARCHAR(200) = NULL     -- p.ej. 'local · azureml run 3f2a...'
    ,@ESTADO   INT           = 3        -- 3 PROCESADO, 4 ERROR
    ,@SEGUNDOS INT           = NULL
    ,@METRICA  NVARCHAR(MAX) = NULL     -- JSON
    ,@MENSAJE  NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)
    IF @MPR IS NULL BEGIN RAISERROR('1.- EL MODELO %s NO EXISTE.', 16, 1, @MODELO) RETURN -1 END
    IF @ESTADO NOT IN (3, 4) BEGIN RAISERROR('2.- EL ESTADO DEBE SER PROCESADO (3) O ERROR (4).', 16, 1) RETURN -1 END

    INSERT INTO [dbo].[Entrenamiento_Ejecucion]
        ([eej_modelo_predictivo], [eej_dataset_entrenamiento], [eej_proceso_estado], [eej_entorno]
        ,[eej_fecha_inicio_utc], [eej_fecha_fin_utc], [eej_segundo_duracion], [eej_metrica], [eej_mensaje]
        ,[eej_usuario_creacion], [eej_fecha_creacion])
    VALUES (@MPR, @DATASET, @ESTADO, @ENTORNO
           ,DATEADD(SECOND, -ISNULL(@SEGUNDOS, 0), GETUTCDATE()), GETUTCDATE(), @SEGUNDOS, @METRICA, @MENSAJE
           ,@USUARIO, GETDATE())
    SET @ID = SCOPE_IDENTITY()
GO

/* ---------------------------------------------------------------------------
   7. REGISTRAR LA VERSION ENTRENADA (queda en BORRADOR)
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
    ,@RUTA           NVARCHAR(500) = NULL    -- azureml://... del artefacto registrado
    ,@HASH           NVARCHAR(64)  = NULL
    ,@BYTE           BIGINT        = NULL
    ,@AUC            DECIMAL(18,6) = NULL
    ,@PRECISION      DECIMAL(18,6) = NULL
    ,@RECALL         DECIMAL(18,6) = NULL
    ,@F1             DECIMAL(18,6) = NULL
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
            ,[mpv_algoritmo], [mpv_hiperparametro], [mpv_parametro], [mpv_ruta], [mpv_hash], [mpv_byte]
            ,[mpv_metrica_auc], [mpv_metrica_precision], [mpv_metrica_recall], [mpv_metrica_f1]
            ,[mpv_plan_version_estado], [mpv_fecha_entrenamiento_utc], [mpv_observacion]
            ,[mpv_usuario_creacion], [mpv_fecha_creacion], [mpv_habilitado])
        VALUES (@MPR, @DATASET, @N, @MFO
               ,@ALGORITMO, @HIPERPARAMETRO, @PARAMETRO, @RUTA, @HASH, @BYTE
               ,@AUC, @PRECISION, @RECALL, @F1
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

/* ---------------------------------------------------------------------------
   8. PUBLICAR UNA VERSION (y retirar la anterior)
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ML_MODELO_VERSION_PUBLICAR]
     @ID      INT
    ,@USUARIO INT
AS
SET NOCOUNT ON
    DECLARE @MPR INT, @ESTADO INT
    SELECT @MPR = [mpv_modelo_predictivo], @ESTADO = [mpv_plan_version_estado]
      FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_id] = @ID AND [mpv_habilitado] = 1
    IF @MPR IS NULL BEGIN RAISERROR('1.- LA VERSION NO EXISTE.', 16, 1) RETURN -1 END
    IF @ESTADO = 2 RETURN 0
    IF @ESTADO = 3 BEGIN RAISERROR('2.- UNA VERSION RETIRADA NO SE VUELVE A PUBLICAR: ENTRENE UNA NUEVA.', 16, 1) RETURN -1 END

    BEGIN TRY
        BEGIN TRANSACTION
        UPDATE [dbo].[Modelo_Predictivo_Version]
           SET [mpv_plan_version_estado] = 3, [mpv_fecha_retiro] = GETDATE()
              ,[mpv_usuario_actualizacion] = @USUARIO, [mpv_fecha_actualizacion] = GETDATE()
         WHERE [mpv_modelo_predictivo] = @MPR AND [mpv_plan_version_estado] = 2 AND [mpv_id] <> @ID

        UPDATE [dbo].[Modelo_Predictivo_Version]
           SET [mpv_plan_version_estado] = 2, [mpv_fecha_publicacion] = GETDATE(), [mpv_usuario_publicacion] = @USUARIO
              ,[mpv_usuario_actualizacion] = @USUARIO, [mpv_fecha_actualizacion] = GETDATE()
         WHERE [mpv_id] = @ID
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @E NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@E, 16, 1)
        RETURN -1
    END CATCH
GO

/* ---------------------------------------------------------------------------
   9. LO QUE MUESTRA LA PANTALLA DE EXPERIMENTOS
      @TIPO 1 modelo (con su version publicada)   2 datasets   3 corridas
            4 versiones   5 predicciones vigentes del modelo   6 caracteristicas
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
              ,o.[mob_nombre] AS OBJETIVO
              ,v.[mpv_id] AS VERSION_ID, v.[mpv_numero] AS VERSION_NUMERO, v.[mpv_algoritmo] AS VERSION_ALGORITMO
              ,v.[mpv_parametro] AS VERSION_PARAMETRO, v.[mpv_ruta] AS VERSION_RUTA, v.[mpv_hash] AS VERSION_HASH
              ,v.[mpv_metrica_auc] AS VERSION_AUC, v.[mpv_metrica_precision] AS VERSION_PRECISION
              ,v.[mpv_metrica_recall] AS VERSION_RECALL, v.[mpv_metrica_f1] AS VERSION_F1
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
              ,v.[mpv_ruta], v.[mpv_hash], v.[mpv_byte]
              ,v.[mpv_metrica_auc], v.[mpv_metrica_precision], v.[mpv_metrica_recall], v.[mpv_metrica_f1]
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
              ,p.[pre_probabilidad], p.[pre_severidad], cn.[crn_nombre] AS SEVERIDAD
              ,pe.[pde_nombre] AS ESTADO, p.[pre_fecha_calculo_utc], p.[pre_fecha_vigencia_hasta_utc]
              ,v.[mpv_numero] AS VERSION_NUMERO, p.[pre_alerta], p.[pre_orden_trabajo]
              ,(SELECT STRING_AGG(x.[pex_texto], N' | ') WITHIN GROUP (ORDER BY x.[pex_orden])
                  FROM [dbo].[Prediccion_Explicacion] x WHERE x.[pex_prediccion] = p.[pre_id]) AS EXPLICACION
          FROM [dbo].[Prediccion] p
          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
          JOIN [dbo].[Activo] a ON a.[act_id] = p.[pre_activo]
          LEFT JOIN [dbo].[Criticidad_Nivel] cn ON cn.[crn_id] = p.[pre_severidad]
          LEFT JOIN [dbo].[Prediccion_Estado] pe ON pe.[pde_id] = p.[pre_prediccion_estado]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND p.[pre_cliente] = @CLIENTE AND p.[pre_habilitado] = 1
           AND p.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE()
         ORDER BY p.[pre_probabilidad] DESC, a.[act_codigo]

    IF @TIPO = 6
        SELECT c.[cmo_id], c.[cmo_codigo], c.[cmo_etiqueta], c.[cmo_descripcion], c.[cmo_ventana_dia], c.[cmo_agregacion], c.[cmo_orden]
          FROM [dbo].[Caracteristica_Modelo] c
         WHERE c.[cmo_modelo_predictivo] = @MPR AND c.[cmo_habilitado] = 1
         ORDER BY c.[cmo_orden]
GO
PRINT '--- API_SEL_ML creado.'
GO

/* ---------------------------------------------------------------------------
   10. GUARDAR UNA PREDICCION PUNTUADA POR LA API
       La API calcula la probabilidad con los pesos de la version publicada
       y manda, ademas del numero, los valores de las caracteristicas que
       uso y las razones (la contribucion de cada una). Aqui se guarda todo
       eso en las mismas tablas del modelo de linea base, y la alerta solo
       si pasa el umbral declarado en el modelo. Una por (activo, version,
       dia): volver a puntuar el mismo dia devuelve la misma prediccion.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_PREDICCION_FALLA]
     @ID              INT OUTPUT
    ,@CLIENTE         INT
    ,@USUARIO         INT
    ,@VERSION         INT
    ,@ACTIVO          INT
    ,@PROBABILIDAD    DECIMAL(18,6)
    ,@CARACTERISTICAS NVARCHAR(MAX) = NULL   -- [{"codigo":"EDAD_DIAS","valor":120}]
    ,@EXPLICACIONES   NVARCHAR(MAX) = NULL   -- [{"codigo":"FALLAS_90D","texto":"...","contribucion":0.8,"direccion":"AUMENTA","observado":2,"referencia":0.3}]
AS
SET NOCOUNT ON
    DECLARE @MPR INT, @ESTADO INT, @UMB_ALERTA DECIMAL(18,6), @UMB_CRITICO DECIMAL(18,6), @HORIZONTE INT
    SELECT @MPR = v.[mpv_modelo_predictivo], @ESTADO = v.[mpv_plan_version_estado]
          ,@UMB_ALERTA = ISNULL(m.[mpr_umbral_alerta], 0.5), @UMB_CRITICO = ISNULL(m.[mpr_umbral_critico], 0.8)
          ,@HORIZONTE = ISNULL(m.[mpr_horizonte_dia], 30)
      FROM [dbo].[Modelo_Predictivo_Version] v
      JOIN [dbo].[Modelo_Predictivo] m ON m.[mpr_id] = v.[mpv_modelo_predictivo]
     WHERE v.[mpv_id] = @VERSION AND v.[mpv_habilitado] = 1
    IF @MPR IS NULL BEGIN RAISERROR('1.- LA VERSION DEL MODELO NO EXISTE.', 16, 1) RETURN -1 END
    IF @ESTADO <> 2 BEGIN RAISERROR('2.- SOLO SE PUNTUA CON UNA VERSION PUBLICADA.', 16, 1) RETURN -1 END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE [act_id] = @ACTIVO AND [act_cliente] = @CLIENTE)
        BEGIN RAISERROR('3.- EL EQUIPO NO ES DEL CLIENTE EN SESION.', 16, 1) RETURN -1 END
    IF @PROBABILIDAD < 0 OR @PROBABILIDAD > 1 BEGIN RAISERROR('4.- LA PROBABILIDAD DEBE ESTAR ENTRE 0 Y 1.', 16, 1) RETURN -1 END
    IF @CARACTERISTICAS IS NOT NULL AND ISJSON(@CARACTERISTICAS) <> 1 BEGIN RAISERROR('5.- LAS CARACTERISTICAS DEBEN VENIR EN JSON.', 16, 1) RETURN -1 END
    IF @EXPLICACIONES IS NOT NULL AND ISJSON(@EXPLICACIONES) <> 1 BEGIN RAISERROR('6.- LAS EXPLICACIONES DEBEN VENIR EN JSON.', 16, 1) RETURN -1 END

    DECLARE @HOY DATETIME = GETUTCDATE()
    DECLARE @UUID UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER,
        HASHBYTES('MD5', CONCAT(N'FALLA|', @CLIENTE, N'|', @ACTIVO, N'|', @VERSION, N'|', CONVERT(NVARCHAR(10), @HOY, 112))))

    SELECT @ID = [pre_id] FROM [dbo].[Prediccion] WHERE [pre_uuid] = @UUID
    IF @ID IS NOT NULL RETURN 0

    DECLARE @SEV INT = CASE WHEN @PROBABILIDAD >= @UMB_CRITICO THEN 4
                            WHEN @PROBABILIDAD >= @UMB_ALERTA  THEN 3
                            WHEN @PROBABILIDAD >= 0.25         THEN 2
                            ELSE 1 END

    BEGIN TRY
        BEGIN TRANSACTION

        /* Las predicciones anteriores del mismo equipo y modelo dejan de
           estar vigentes: la de hoy las reemplaza. */
        UPDATE p SET p.[pre_fecha_vigencia_hasta_utc] = @HOY
          FROM [dbo].[Prediccion] p
          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND p.[pre_cliente] = @CLIENTE AND p.[pre_activo] = @ACTIVO
           AND p.[pre_fecha_vigencia_hasta_utc] > @HOY

        INSERT INTO [dbo].[Prediccion]
            ([pre_uuid], [pre_cliente], [pre_modelo_predictivo_version], [pre_prediccion_estado], [pre_activo]
            ,[pre_probabilidad], [pre_dia_restante], [pre_fecha_evento_estimada_utc], [pre_severidad]
            ,[pre_fecha_calculo_utc], [pre_fecha_vigencia_hasta_utc]
            ,[pre_usuario_creacion], [pre_fecha_creacion], [pre_habilitado])
        VALUES (@UUID, @CLIENTE, @VERSION, 1, @ACTIVO
               ,@PROBABILIDAD, @HORIZONTE, DATEADD(DAY, @HORIZONTE, @HOY), @SEV
               ,@HOY, DATEADD(DAY, 7, @HOY)
               ,@USUARIO, GETDATE(), 1)
        SET @ID = SCOPE_IDENTITY()

        IF @CARACTERISTICAS IS NOT NULL
            INSERT INTO [dbo].[Prediccion_Caracteristica]
                ([pcr_prediccion], [pcr_caracteristica_modelo], [pcr_valor], [pcr_imputado], [pcr_usuario_creacion], [pcr_fecha_creacion])
            /* FLOAT y no DECIMAL en el WITH: un JSON escribe 1.2E-05 y a
               DECIMAL no le gusta la notacion cientifica. */
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

        /* La alerta solo si pasa el umbral, y una sola abierta por equipo. */
        IF @PROBABILIDAD >= @UMB_ALERTA
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] x
                            WHERE x.[ale_activo] = @ACTIVO AND x.[ale_alerta_tipo] = 4 AND x.[ale_alerta_estado] = 1
                              AND x.[ale_prediccion] IN (SELECT p.[pre_id] FROM [dbo].[Prediccion] p
                                                          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
                                                         WHERE v.[mpv_modelo_predictivo] = @MPR))
        BEGIN
            DECLARE @NOMBRE NVARCHAR(300) = (SELECT CONCAT([act_codigo], N' ', [act_nombre]) FROM [dbo].[Activo] WHERE [act_id] = @ACTIVO)
            DECLARE @INST INT = (SELECT [act_cliente_instalacion] FROM [dbo].[Activo] WHERE [act_id] = @ACTIVO)
            DECLARE @PCT NVARCHAR(10) = CAST(CAST(ROUND(@PROBABILIDAD * 100, 0) AS INT) AS NVARCHAR(10))
            DECLARE @RAZON NVARCHAR(500) = (SELECT TOP 1 [pex_texto] FROM [dbo].[Prediccion_Explicacion] WHERE [pex_prediccion] = @ID ORDER BY [pex_orden])

            INSERT INTO [dbo].[Alerta]
                ([ale_uuid], [ale_cliente], [ale_cliente_instalacion], [ale_alerta_tipo], [ale_alerta_estado], [ale_severidad]
                ,[ale_titulo], [ale_descripcion], [ale_fecha_deteccion_utc], [ale_activo], [ale_prediccion]
                ,[ale_valor_observado], [ale_valor_umbral]
                ,[ale_fecha_primera_ocurrencia_utc], [ale_fecha_ultima_ocurrencia_utc], [ale_ocurrencias]
                ,[ale_usuario_creacion], [ale_fecha_creacion], [ale_habilitado])
            VALUES (NEWID(), @CLIENTE, @INST, 4, 1, @SEV
                   ,CONCAT(N'Riesgo de falla en ', @NOMBRE)
                   ,CONCAT(N'SIGMA FAILURE estima un ', @PCT, N' % de probabilidad de falla en los proximos ', @HORIZONTE, N' dias.'
                          ,CASE WHEN @RAZON IS NOT NULL THEN N' ' + @RAZON ELSE N'' END)
                   ,@HOY, @ACTIVO, @ID
                   ,@PROBABILIDAD, @UMB_ALERTA
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
PRINT '--- API_INS_PREDICCION_FALLA creado.'
GO

/* ---------------------------------------------------------------------------
   11. PERMISO, MENU Y FUNCION
       SIGMA AI pasa a tener carpeta propia en la web. Ver la pantalla es VER
       PREDICCIONES (el mismo permiso de la app); entrenar, registrar y
       publicar versiones es un permiso nuevo, de jefatura.
   --------------------------------------------------------------------------- */
DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT, nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES (N'ENTRENAR MODELOS', N'Generar datasets, registrar entrenamientos y publicar versiones de SIGMA AI', N'MANTENIMIENTO', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
  FROM @P p WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

/* VER PREDICCIONES nacio para la app; ahora tambien lo usa la web. */
UPDATE [dbo].[Permiso] SET prm_permiso_ambito = 3 WHERE prm_codigo = N'VER PREDICCIONES' AND prm_permiso_ambito = 2

DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (5, N'ENTRENAR MODELOS'), (10, N'ENTRENAR MODELOS'), (11, N'ENTRENAR MODELOS'),
    (10, N'VER PREDICCIONES')
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
  FROM @PP pp JOIN [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.perfil AND x.ppe_permiso = p.prm_id)

DECLARE @RAIZ INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nivel = 1 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Menus')
DECLARE @IA INT
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nivel = 2 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'SIGMA AI')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'SIGMA AI', N'Analisis predictivo: modelos, entrenamientos y predicciones', 2, @RAIZ, 8, N'#', 1, N'mdi mdi-brain',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PREDICCIONES'), 1)
SELECT @IA = mnu_id FROM [dbo].[Menus] WHERE mnu_nivel = 2 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'SIGMA AI'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/SigmaAI/Experimentos.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Experimentos', N'Investigacion Azure Machine Learning: dataset, entrenamiento, versiones y puntuacion de SIGMA FAILURE', 3, @IA, 1,
            N'~/View/SigmaAI/Experimentos.aspx', 1, N'mdi mdi-flask-outline',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PREDICCIONES'), 1)

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, N'Entrenar y publicar', p.prm_id
  FROM [dbo].[Menus] m, [dbo].[Permiso] p
 WHERE m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/SigmaAI/Experimentos.aspx' AND p.prm_codigo = N'ENTRENAR MODELOS'
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu = m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT = N'Entrenar y publicar')

PRINT '--- Menu SIGMA AI > Experimentos y permiso ENTRENAR MODELOS (bloque 245).'
GO
