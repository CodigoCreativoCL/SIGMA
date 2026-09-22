/* ============================================================================
   SIGMA — Bloque 249
   LAS REGLAS DEL SPRINT 1 QUE FALTABAN                HU-011 · HU-016 · HU-017
   ----------------------------------------------------------------------------

   Se detectaron el 22-09-2026 al completar la evidencia del Sprint 1. Los
   criterios existian desde el Product Backlog; ningun SP los hacia valer.

   HU-011 #2  Una planta con zona horaria propia: sus programaciones se
              calculan con esa zona. FNC_INSTALACION_HORA(@INSTALACION) da
              la hora local de la planta (Zona_Horaria del cliente si no
              declaro una) y GEN_PLAN_OCURRENCIAS abre la ventana de
              generacion con el HOY de cada planta, no con el UTC del
              servidor.

   HU-017 #2  Asignar un tecnico cuya certificacion de la especialidad
              exigida esta vencida: se advierte «Certificacion vencida el
              {fecha}», se permite, y la advertencia queda en la
              asignacion (ota_observacion).

   HU-017 #3  Una certificacion que vence en menos de 30 dias (o ya vencio)
              aparece en el panel de alertas: tipo CERTIFICACION POR VENCER,
              seccion 7 del detector GEN_ALERTA_OPERACION, con
              Alerta.ale_usuario_especialidad como llave para abrir una sola
              y cerrarla cuando se renueve.

   HU-016 #2  Una orden asignada a un grupo la recibe su lider vigente: la
              bandeja de SIGMA es por persona, y sin lider se rechaza.

   SP completos con las reglas nuevas, tomados de la definicion vigente.
   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---- la hora de la planta ---- */
CREATE OR ALTER FUNCTION [dbo].[FNC_INSTALACION_HORA] (@INSTALACION INT)
RETURNS DATETIME
AS
BEGIN
    DECLARE @ZONA NVARCHAR(100), @PAIS INT
    SELECT @ZONA = z.zho_identificador_windows, @PAIS = c.cli_pais
      FROM [dbo].[Cliente_Instalacion] ci
      JOIN [dbo].[Cliente] c ON c.cli_id = ci.cin_cliente
      LEFT JOIN [dbo].[Zona_Horaria] z ON z.zho_id = ci.cin_zona_horaria AND z.zho_habilitado = 1
     WHERE ci.cin_id = @INSTALACION
    IF @ZONA IS NOT NULL AND @ZONA <> N''
        RETURN CAST(SYSDATETIMEOFFSET() AT TIME ZONE @ZONA AS DATETIME)
    RETURN [dbo].[FNC_PAIS_HORA](@PAIS)
END
GO
PRINT '--- FNC_INSTALACION_HORA creada.'
GO

/* ---- el tipo de alerta y su llave ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'CERTIFICACION POR VENCER')
    INSERT INTO [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado, alt_permiso, alt_icono, alt_menu_link)
    VALUES ('CERTIFICACION POR VENCER', N'Certificación por vencer', 15, 1,
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ESPECIALIDADES USUARIO'),
            'mdi mdi-certificate-outline', '~/View/Organizacion/Especialidades/UsuarioEspecialidades.aspx')
/* Si ya existia sin enlace (primera corrida de este bloque), se completa. */
UPDATE [dbo].[Alerta_Tipo]
   SET alt_permiso = ISNULL(alt_permiso, (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ESPECIALIDADES USUARIO')),
       alt_icono = ISNULL(alt_icono, 'mdi mdi-certificate-outline'),
       alt_menu_link = ISNULL(alt_menu_link, '~/View/Organizacion/Especialidades/UsuarioEspecialidades.aspx')
 WHERE alt_codigo = 'CERTIFICACION POR VENCER'
IF COL_LENGTH('dbo.Alerta', 'ale_usuario_especialidad') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_usuario_especialidad] INT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[GEN_PLAN_OCURRENCIAS]
@CLIENTE          INT,
@PLAN             INT = NULL,
@HORIZONTE_DIA    INT = 90,
@SOLO_AUTOMATICAS BIT = 0,
@USUARIO          INT,
@GENERADAS        INT = NULL OUTPUT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@HORIZONTE_DIA IS NULL OR @HORIZONTE_DIA < 1) SET @HORIZONTE_DIA = 90
IF (@HORIZONTE_DIA > 730) SET @HORIZONTE_DIA = 730

DECLARE @DESDE DATE = CAST(GETUTCDATE() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, @HORIZONTE_DIA, @DESDE)

IF @PLAN IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @PLAN IS NOT NULL AND [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN) IS NULL
BEGIN
    RAISERROR('2.- EL PLAN NO TIENE UNA VERSIÓN PUBLICADA: PUBLIQUE EL BORRADOR ANTES DE GENERAR.', 16, 1)
    RETURN -1
END

-- Lo que toca: hito x equipo x fecha, solo de versiones publicadas
DECLARE @NUEVAS TABLE (hito INT, programacion INT, activo INT, componente INT, fecha DATETIME, antes INT, despues INT, plan_codigo NVARCHAR(100), hito_codigo NVARCHAR(100), activo_codigo NVARCHAR(100))

INSERT INTO @NUEVAS (hito, programacion, activo, componente, fecha, antes, despues, plan_codigo, hito_codigo, activo_codigo)
SELECT  h.pmh_id, h.pmh_programacion, a.pac_activo, a.pac_activo_componente, f.FECHA,
        ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0),
        pma.pma_codigo, h.pmh_codigo, act.act_codigo
FROM    [dbo].[Plan_Mantenimiento]         pma
JOIN    [dbo].[Plan_Mantenimiento_Version] v   ON v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1
JOIN    [dbo].[Programacion]               p   ON p.pro_id = h.pmh_programacion AND p.pro_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Activo]  a   ON a.pac_plan_mantenimiento_version = v.pmv_id
JOIN    [dbo].[Activo]                     act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
/* HU-011 #2: la ventana se abre con el HOY DE LA PLANTA del equipo, no con
   el de Santiago ni con el UTC del servidor. Una planta en Isla de Pascua
   (UTC-6) sigue en el dia anterior cuando en Renca ya es medianoche; su
   ocurrencia de "hoy" se calcula con su propio reloj. */
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion,
                                            CAST([dbo].[FNC_INSTALACION_HORA](act.act_cliente_instalacion) AS DATE),
                                            DATEADD(DAY, @HORIZONTE_DIA, CAST([dbo].[FNC_INSTALACION_HORA](act.act_cliente_instalacion) AS DATE))) f
WHERE   pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)
  AND   (@SOLO_AUTOMATICAS = 0 OR p.pro_genera_automaticamente = 1)
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    WHERE o.pmo_plan_mantenimiento_hito = h.pmh_id AND o.pmo_activo = a.pac_activo AND o.pmo_fecha_programada_utc = f.FECHA)
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    WHERE o.pmo_programacion = h.pmh_programacion AND o.pmo_activo = a.pac_activo AND o.pmo_fecha_programada_utc = f.FECHA)

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
        (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
         pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc,
         pmo_plan_ocurrencia_estado, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
    SELECT  NEWID(), @CLIENTE, hito, programacion, activo, componente,
            fecha, DATEADD(MINUTE, despues, fecha), DATEADD(MINUTE, -antes, fecha),
            1, @USUARIO, @DATE_NOW, 1
    FROM    @NUEVAS

    SET @GENERADAS = @@ROWCOUNT

    -- El rastro por programacion: hasta cuando se genero y cuantas
    MERGE [dbo].[Programacion_Generacion] AS g
    USING (SELECT programacion, COUNT(*) n FROM @NUEVAS GROUP BY programacion) AS s
       ON g.pge_programacion = s.programacion
    WHEN MATCHED THEN UPDATE SET
         pge_horizonte_dia = @HORIZONTE_DIA, pge_fecha_generada_hasta_utc = @HASTA, pge_ultima_ejecucion_utc = GETUTCDATE(),
         pge_ocurrencias_generadas = g.pge_ocurrencias_generadas + s.n, pge_ultimo_error = NULL,
         pge_usuario_actualizacion = @USUARIO, pge_fecha_actualizacion = @DATE_NOW
    WHEN NOT MATCHED THEN INSERT
         (pge_programacion, pge_horizonte_dia, pge_fecha_generada_hasta_utc, pge_ultima_ejecucion_utc, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
         VALUES (s.programacion, @HORIZONTE_DIA, @HASTA, GETUTCDATE(), s.n, @USUARIO, @DATE_NOW);

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GEN_PLAN_OCURRENCIAS', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE GENERAR LAS OCURRENCIAS: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

-- Resumen para la pantalla: que se genero, por plan e hito
SELECT plan_codigo AS PLAN_CODIGO, hito_codigo AS HITO_CODIGO, COUNT(DISTINCT activo) AS EQUIPOS, COUNT(*) AS GENERADAS,
       MIN(fecha) AS PRIMERA, MAX(fecha) AS ULTIMA
FROM   @NUEVAS
GROUP BY plan_codigo, hito_codigo
ORDER BY plan_codigo, hito_codigo

RETURN 0
GO

PRINT '--- GEN_PLAN_OCURRENCIAS abre la ventana con la hora de cada planta (bloque 249).'
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_ASIGNACION]
@ID             INT = NULL OUTPUT,
@CLIENTE        INT,
@ORDEN          INT,
@USUARIO_ASIG   INT = NULL,
@PROVEEDOR      INT = NULL,
@GRUPO_TRABAJO  INT = NULL,
@ES_RESPONSABLE BIT = 1,
@ROL_EJECUCION  INT = NULL,
@OBSERVACION    NVARCHAR(1000) = NULL,
@USUARIO        INT,
@UUID                  UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT, @ADVERTENCIA NVARCHAR(400) = NULL
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL
BEGIN
    SELECT @ID = ota_id FROM [dbo].[Orden_Trabajo_Asignacion] WHERE ota_uuid = @UUID
    IF @ID IS NOT NULL
    BEGIN
        SELECT @ID AS OTA_ID, CAST(NULL AS NVARCHAR(400)) AS ADVERTENCIA
        RETURN 0
    END
END
SELECT @ESTADO = otr_orden_trabajo_estado FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

IF @ESTADO IN (3, 4)
BEGIN
    RAISERROR('2.- UNA ORDEN EN ESPERA DE CIERRE O CERRADA YA NO SE ASIGNA.', 16, 1)
    RETURN -1
END

-- Una persona O una empresa externa (CK_OTA_EJECUTANTE), no las dos ni ninguna
IF (@USUARIO_ASIG IS NULL AND @PROVEEDOR IS NULL) OR (@USUARIO_ASIG IS NOT NULL AND @PROVEEDOR IS NOT NULL)
BEGIN
    RAISERROR('3.- INDIQUE UN TÉCNICO O UNA EMPRESA EXTERNA, NO AMBOS.', 16, 1)
    RETURN -1
END

IF @USUARIO_ASIG IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO_ASIG AND ucl_id_cliente = @CLIENTE AND ucl_habilitado = 1)
BEGIN
    RAISERROR('4.- EL TÉCNICO NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- HU-112 #2: la empresa sale del registro de contratistas; no se crea usuario
IF @PROVEEDOR IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor] WHERE prv_id = @PROVEEDOR AND prv_cliente = @CLIENTE AND prv_es_contratista = 1 AND prv_habilitado = 1)
BEGIN
    RAISERROR('5.- LA EMPRESA NO ESTÁ REGISTRADA COMO CONTRATISTA DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @GRUPO_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE)
BEGIN
    RAISERROR('6.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ROL_EJECUCION IS NULL SET @ROL_EJECUCION = CASE WHEN @ES_RESPONSABLE = 1 THEN 1 ELSE 2 END

-- Ya esta en la orden: se actualiza esa fila en vez de duplicar
DECLARE @YA INT = (SELECT TOP 1 ota_id FROM [dbo].[Orden_Trabajo_Asignacion]
                   WHERE ota_orden_trabajo = @ORDEN AND ota_habilitado = 1
                     AND ((@USUARIO_ASIG IS NOT NULL AND ota_usuario = @USUARIO_ASIG) OR (@PROVEEDOR IS NOT NULL AND ota_proveedor = @PROVEEDOR)))

/* HU-016 #2: una orden asignada a un GRUPO la recibe su lider vigente.
   Las notificaciones de SIGMA son la bandeja de cada persona ("Mis
   ordenes"): sin un usuario, la orden no le aparece a nadie. Si el grupo
   tiene lider vigente hoy, el es la persona asignada; si no lo tiene, se
   rechaza para que alguien lo nombre antes. */
IF @GRUPO_TRABAJO IS NOT NULL AND @USUARIO_ASIG IS NULL AND @PROVEEDOR IS NULL
BEGIN
    DECLARE @HOY_GRUPO DATE = CAST(@DATE_NOW AS DATE)
    SELECT TOP 1 @USUARIO_ASIG = gtu_usuario
      FROM [dbo].[Grupo_Trabajo_Usuario]
     WHERE gtu_grupo_trabajo = @GRUPO_TRABAJO AND gtu_es_lider = 1
       AND gtu_fecha_inicio <= @HOY_GRUPO AND (gtu_fecha_fin IS NULL OR gtu_fecha_fin >= @HOY_GRUPO)
     ORDER BY gtu_fecha_inicio DESC
    IF @USUARIO_ASIG IS NULL
    BEGIN
        RAISERROR('8.- EL GRUPO NO TIENE UN LÍDER VIGENTE: NOMBRE UNO ANTES DE ASIGNARLE ÓRDENES.', 16, 1)
        RETURN -1
    END
    SET @ADVERTENCIA = N'Asignada al grupo ' + ISNULL((SELECT gtr_nombre FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO), N'')
                     + N'; la recibe su líder.'
END

-- HU-112 #4: especialidad requerida que el tecnico no tiene -> se advierte y se permite
IF @USUARIO_ASIG IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Especialidad] WHERE oep_orden_trabajo = @ORDEN)
BEGIN
    DECLARE @FALTAN NVARCHAR(400) =
        STUFF((SELECT ', ' + e.esp_nombre
               FROM [dbo].[Orden_Trabajo_Especialidad] oe JOIN [dbo].[Especialidad] e ON e.esp_id = oe.oep_especialidad
               WHERE oe.oep_orden_trabajo = @ORDEN
                 AND NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Especialidad] ue WHERE ue.ues_usuario = @USUARIO_ASIG AND ue.ues_especialidad = oe.oep_especialidad AND ue.ues_habilitado = 1)
               FOR XML PATH('')), 1, 2, '')
    IF @FALTAN IS NOT NULL
        SET @ADVERTENCIA = ISNULL(@ADVERTENCIA + N' ', N'') + N'El técnico no tiene la especialidad requerida: ' + @FALTAN + N'.'

    /* HU-017 #2: la tiene, pero con la certificacion vencida -> se advierte
       con la fecha, se permite, y la advertencia queda en la asignacion. */
    DECLARE @VENCIDAS NVARCHAR(400) =
        STUFF((SELECT ', ' + e.esp_nombre + N' (vencida el ' + CONVERT(NVARCHAR(10), ue.ues_fecha_vencimiento, 103) + N')'
               FROM [dbo].[Orden_Trabajo_Especialidad] oe
               JOIN [dbo].[Especialidad] e ON e.esp_id = oe.oep_especialidad
               JOIN [dbo].[Usuario_Especialidad] ue ON ue.ues_usuario = @USUARIO_ASIG AND ue.ues_especialidad = oe.oep_especialidad AND ue.ues_habilitado = 1
               WHERE oe.oep_orden_trabajo = @ORDEN
                 AND ue.ues_fecha_vencimiento IS NOT NULL AND ue.ues_fecha_vencimiento < CAST(@DATE_NOW AS DATE)
               FOR XML PATH('')), 1, 2, '')
    IF @VENCIDAS IS NOT NULL
        SET @ADVERTENCIA = ISNULL(@ADVERTENCIA + N' ', N'') + N'Certificación vencida: ' + @VENCIDAS + N'.'
END

BEGIN TRY
    BEGIN TRANSACTION

    -- HU-112 #3: un solo responsable; el anterior pasa a apoyo
    IF @ES_RESPONSABLE = 1
        UPDATE [dbo].[Orden_Trabajo_Asignacion]
        SET ota_es_responsable = 0, ota_rol_ejecucion = 2, ota_usuario_actualizacion = @USUARIO, ota_fecha_actualizacion = @DATE_NOW
        WHERE ota_orden_trabajo = @ORDEN AND ota_es_responsable = 1 AND ota_habilitado = 1 AND ISNULL(ota_id, 0) <> ISNULL(@YA, 0)

    IF @YA IS NOT NULL
    BEGIN
        UPDATE [dbo].[Orden_Trabajo_Asignacion]
        SET ota_es_responsable = @ES_RESPONSABLE, ota_rol_ejecucion = @ROL_EJECUCION, ota_grupo_trabajo = ISNULL(@GRUPO_TRABAJO, ota_grupo_trabajo),
            ota_observacion = ISNULL(@ADVERTENCIA + CHAR(13) + CHAR(10), N'') + ISNULL(@OBSERVACION, N''),
            ota_usuario_actualizacion = @USUARIO, ota_fecha_actualizacion = @DATE_NOW
        WHERE ota_id = @YA
        SET @ID = @YA
    END
    ELSE
    BEGIN
        INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
            (ota_uuid, ota_orden_trabajo, ota_usuario, ota_proveedor, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_fecha_asignacion_utc,
             ota_observacion, ota_asignado_por, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
        VALUES
            (@UUID, @ORDEN, @USUARIO_ASIG, @PROVEEDOR, @GRUPO_TRABAJO, @ES_RESPONSABLE, @ROL_EJECUCION, GETUTCDATE(),
             ISNULL(@ADVERTENCIA + CHAR(13) + CHAR(10), N'') + ISNULL(@OBSERVACION, N''), @USUARIO, @USUARIO, @DATE_NOW, 1)
        SET @ID = SCOPE_IDENTITY()
    END

    -- HU-112 #1: le aparece en su bandeja y recibe una notificacion
    IF @USUARIO_ASIG IS NOT NULL AND OBJECT_ID('dbo.INS_NOTIFICACION') IS NOT NULL
    BEGIN
        DECLARE @TIT NVARCHAR(200) = (SELECT N'OT-' + CAST(otr_correlativo AS NVARCHAR(10)) + N' · ' + LEFT(otr_titulo, 150) FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN)
        BEGIN TRY
            EXEC [dbo].[INS_NOTIFICACION] @CLIENTE = @CLIENTE, @USUARIO_DESTINO = @USUARIO_ASIG, @TITULO = N'Te asignaron una orden de trabajo',
                 @MENSAJE = @TIT, @ENTIDAD = N'ORDEN', @ENTIDAD_ID = @ORDEN, @USUARIO = @USUARIO
        END TRY
        BEGIN CATCH
            -- La notificacion no puede tumbar la asignacion.
        END CATCH
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_ASIGNACION', @MSG = @MSG
    RAISERROR('7.- NO FUE POSIBLE ASIGNAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT @ID AS OTA_ID, @ADVERTENCIA AS ADVERTENCIA
RETURN 0
GO

PRINT '--- INS_ORDEN_TRABAJO_ASIGNACION advierte certificacion vencida y entrega al lider del grupo (bloque 249).'
GO

CREATE OR ALTER PROCEDURE [dbo].[GEN_ALERTA_OPERACION]
    @CLIENTE INT,
    @USUARIO INT = 1,
    /* Con cuantos dias de atraso una ocurrencia pasa de advertencia a alta. */
    @DIAS_ATRASO_ALTA INT = 7
AS
SET NOCOUNT ON

DECLARE @T_OCURRENCIA INT, @T_PERMISO INT, @T_SIN_LECTURA INT, @T_HALLAZGO INT, @T_DESCUBRIMIENTO INT, @T_PROXIMO INT
DECLARE @NUEVA INT, @RESUELTA INT, @DESCARTADA INT
DECLARE @SEV_ALTA INT, @SEV_ADV INT, @SEV_CRITICA INT
DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

SELECT @T_OCURRENCIA    = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'OCURRENCIA VENCIDA'
SELECT @T_PERMISO       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'PERMISO VENCIDO'
SELECT @T_SIN_LECTURA   = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDIDOR SIN LECTURA'
SELECT @T_HALLAZGO      = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'HALLAZGO CRITICO'
SELECT @T_DESCUBRIMIENTO= alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'DESCUBRIMIENTO TERRENO'
SELECT @T_PROXIMO       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDIDOR PROXIMO MANTENIMIENTO'
DECLARE @T_CERTIFICACION INT
SELECT @T_CERTIFICACION = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'CERTIFICACION POR VENCER'

SELECT @NUEVA      = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'
SELECT @RESUELTA   = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA'
SELECT @DESCARTADA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'

SELECT @SEV_ALTA    = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'
SELECT @SEV_ADV     = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ADVERTENCIA'
SELECT @SEV_CRITICA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'CRITICA'

IF OBJECT_ID('tempdb..#HALLAZGO') IS NOT NULL DROP TABLE #HALLAZGO

CREATE TABLE #HALLAZGO (
    TIPO INT, INSTALACION INT NULL,
    ACTIVO INT NULL, COMPONENTE INT NULL, MEDIDOR INT NULL, VARIABLE INT NULL,
    OCURRENCIA INT NULL, PERMISO INT NULL, HALLAZGO INT NULL, ORDEN INT NULL, ESPECIALIDAD_USUARIO INT NULL,
    TITULO NVARCHAR(400), DESCRIPCION NVARCHAR(1000),
    OBSERVADO DECIMAL(18,4) NULL, UMBRAL DECIMAL(18,4) NULL, UNIDAD INT NULL,
    SEVERIDAD INT)

/* ---- 1. Ocurrencias del plan vencidas y sin orden ----
   La fecha limite manda; si el hito no la tiene, la programada. Vencida es
   ANTES de hoy: la de hoy todavia esta a tiempo. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, OCURRENCIA, TITULO, DESCRIPCION, OBSERVADO, SEVERIDAD)
SELECT  @T_OCURRENCIA, a.act_cliente_instalacion, o.pmo_activo, o.pmo_activo_componente, o.pmo_id,
        N'Ocurrencia vencida: ' + ISNULL(h.pmh_nombre, N'hito del plan') + N' · ' + a.act_codigo,
        N'Estaba para el ' + CONVERT(NVARCHAR(10), CAST(ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc) AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        N' y lleva ' + LTRIM(STR(DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA))) +
        N' días sin orden de trabajo en ' + a.act_nombre + N'.',
        DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA),
        CASE WHEN DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA) > @DIAS_ATRASO_ALTA
             THEN @SEV_ALTA ELSE @SEV_ADV END
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Ocurrencia_Estado] e ON e.poe_id = o.pmo_plan_ocurrencia_estado
JOIN    [dbo].[Activo] a ON a.act_id = o.pmo_activo
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
WHERE   o.pmo_cliente = @CLIENTE
  AND   o.pmo_habilitado = 1
  AND   o.pmo_orden_trabajo IS NULL
  AND   e.poe_codigo IN ('PENDIENTE', 'DISPONIBLE')
  AND   CAST(ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc) AS DATE) < CAST(@AHORA AS DATE)

/* ---- 2. Permisos de trabajo vencidos que siguen solicitados o autorizados ----
   No se cambia el estado del permiso: eso es de su modulo. Aca solo se avisa. */
INSERT INTO #HALLAZGO (TIPO, ORDEN, PERMISO, TITULO, DESCRIPCION, OBSERVADO, SEVERIDAD)
SELECT  @T_PERMISO, p.ptr_orden_trabajo, p.ptr_id,
        N'Permiso vencido: ' + t.ptt_nombre + ISNULL(N' · folio ' + NULLIF(p.ptr_numero, N''), N''),
        N'Venció el ' + CONVERT(NVARCHAR(10), CAST(p.ptr_fecha_vigencia_fin_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        N' y sigue ' + LOWER(e.pte_nombre) + ISNULL(N' en la OT ' + LTRIM(STR(o.otr_correlativo)), N'') + N'.',
        DATEDIFF(DAY, p.ptr_fecha_vigencia_fin_utc, @AHORA),
        @SEV_ALTA
FROM    [dbo].[Permiso_Trabajo] p
JOIN    [dbo].[Permiso_Trabajo_Tipo] t ON t.ptt_id = p.ptr_permiso_trabajo_tipo
JOIN    [dbo].[Permiso_Trabajo_Estado] e ON e.pte_id = p.ptr_permiso_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = p.ptr_orden_trabajo
WHERE   p.ptr_cliente = @CLIENTE
  AND   p.ptr_habilitado = 1
  AND   e.pte_codigo IN ('SOLICITADO', 'AUTORIZADO')
  AND   p.ptr_fecha_vigencia_fin_utc IS NOT NULL
  AND   p.ptr_fecha_vigencia_fin_utc < @AHORA

/* ---- 3. Variables con frecuencia esperada y sin medicion en ese plazo ----
   "Sin lectura" es que la ultima medicion es mas vieja que la frecuencia; si
   nunca se midio, cuenta desde que se definio la variable. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, VARIABLE, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, SEVERIDAD)
SELECT  @T_SIN_LECTURA, a.act_cliente_instalacion, v.ava_activo, v.ava_activo_componente, v.ava_id,
        N'Sin medición de ' + vm.vme_nombre + N' en ' + a.act_codigo,
        N'Se esperaba cada ' + LTRIM(STR(v.ava_frecuencia_esperada_hora)) + N' h y ' +
        CASE WHEN u.ULTIMA IS NULL THEN N'nunca se ha medido desde que se definió'
             ELSE N'la última fue hace ' + LTRIM(STR(DATEDIFF(HOUR, u.ULTIMA, @AHORA))) + N' h' END + N'.',
        DATEDIFF(HOUR, ISNULL(u.ULTIMA, v.ava_fecha_creacion), @AHORA),
        v.ava_frecuencia_esperada_hora,
        @SEV_ADV
FROM    [dbo].[Activo_Variable] v
JOIN    [dbo].[Activo] a ON a.act_id = v.ava_activo
JOIN    [dbo].[Variable_Medicion] vm ON vm.vme_id = v.ava_variable_medicion
OUTER APPLY (SELECT MAX(m.amd_fecha_medicion_utc) AS ULTIMA
             FROM   [dbo].[Activo_Medicion] m
             WHERE  m.amd_activo_variable = v.ava_id) u
WHERE   v.ava_cliente = @CLIENTE
  AND   v.ava_habilitado = 1
  AND   a.act_habilitado = 1
  AND   v.ava_frecuencia_esperada_hora IS NOT NULL
  AND   v.ava_frecuencia_esperada_hora > 0
  AND   DATEDIFF(HOUR, ISNULL(u.ULTIMA, v.ava_fecha_creacion), @AHORA) > v.ava_frecuencia_esperada_hora

/* ---- 4. Hallazgos criticos o altos de checklist sin orden de trabajo ---- */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, HALLAZGO, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_HALLAZGO, a.act_cliente_instalacion, h.cha_activo, h.cha_activo_componente, h.cha_id,
        N'Hallazgo ' + CASE WHEN s.sev_codigo = 'CRITICA' THEN N'crítico' ELSE N'alto' END + N': ' + h.cha_titulo,
        ISNULL(LEFT(h.cha_descripcion, 800), N'') +
        CASE WHEN a.act_id IS NULL THEN N'' ELSE N' (' + a.act_codigo + N' ' + a.act_nombre + N')' END +
        N'. Sin orden de trabajo.',
        h.cha_severidad
FROM    [dbo].[Checklist_Hallazgo] h
JOIN    [dbo].[Severidad] s ON s.sev_id = h.cha_severidad
JOIN    [dbo].[Proceso_Estado] pe ON pe.pes_id = h.cha_proceso_estado
LEFT JOIN [dbo].[Activo] a ON a.act_id = h.cha_activo
WHERE   h.cha_cliente = @CLIENTE
  AND   h.cha_habilitado = 1
  AND   h.cha_orden_trabajo IS NULL
  AND   pe.pes_codigo IN ('PENDIENTE', 'EN PROCESO')
  AND   s.sev_codigo IN ('ALTA', 'CRITICA')

/* ---- 5. Registros creados en terreno que nadie ha revisado ----
   Activos y medidores nacidos en terreno (Anexo C): la alerta vive hasta que
   alguien revisa el descubrimiento desde la web. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_DESCUBRIMIENTO, a.act_cliente_instalacion, a.act_id,
        N'Equipo creado en terreno sin revisar: ' + a.act_codigo,
        a.act_nombre + N' se registró desde el teléfono el ' +
        CONVERT(NVARCHAR(10), CAST(d.rde_fecha_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        ISNULL(N' por ' + u.usu_nombre + N' ' + u.usu_apellido_paterno, N'') + N'. Falta revisarlo.',
        @SEV_ADV
FROM    [dbo].[Activo] a
JOIN    [dbo].[Registro_Descubrimiento] d ON d.rde_id = a.act_registro_descubrimiento
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = d.rde_usuario
WHERE   a.act_cliente = @CLIENTE
  AND   a.act_habilitado = 1
  AND   a.act_fusionado_en IS NULL
  AND   d.rde_fecha_revision IS NULL

INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, MEDIDOR, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_DESCUBRIMIENTO, a.act_cliente_instalacion, m.ame_activo, m.ame_id,
        N'Medidor creado en terreno sin revisar: ' + m.ame_codigo,
        m.ame_nombre + N' de ' + a.act_codigo + N' se registró desde el teléfono el ' +
        CONVERT(NVARCHAR(10), CAST(d.rde_fecha_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) + N'. Falta revisarlo.',
        @SEV_ADV
FROM    [dbo].[Activo_Medidor] m
JOIN    [dbo].[Activo] a ON a.act_id = m.ame_activo
JOIN    [dbo].[Registro_Descubrimiento] d ON d.rde_id = m.ame_registro_descubrimiento
WHERE   m.ame_cliente = @CLIENTE
  AND   m.ame_habilitado = 1
  AND   d.rde_fecha_revision IS NULL

/* ---- 6. El horometro se acerca al valor de disparo del plan ----
   La misma vista que usa el generador (FNC_PLAN_MEDIDOR_ESTADO): medidor
   por equipo y proximo objetivo desde la ultima ocurrencia. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, MEDIDOR, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, UNIDAD, SEVERIDAD)
SELECT  @T_PROXIMO, a.act_cliente_instalacion, e.ACTIVO, e.MEDIDOR,
        N'Se acerca el mantenimiento por ' + e.MEDIDOR_NOMBRE + N' en ' + a.act_codigo,
        N'Va en ' + LTRIM(STR(e.VALOR_ACTUAL, 18, 1)) + N' ' + ISNULL(um.ume_simbolo, N'') +
        N' y el hito «' + e.HITO_NOMBRE + N'» dispara a los ' + LTRIM(STR(e.PROXIMO, 18, 1)) + N' ' + ISNULL(um.ume_simbolo, N'') + N'. Solo aviso: la orden nace con la ocurrencia.',
        e.VALOR_ACTUAL, e.PROXIMO, e.UNIDAD, @SEV_ADV
FROM    [dbo].[FNC_PLAN_MEDIDOR_ESTADO](@CLIENTE) e
JOIN    [dbo].[Activo] a ON a.act_id = e.ACTIVO
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = e.UNIDAD
WHERE   e.VALOR_ACTUAL IS NOT NULL AND e.AVISO > 0
  AND   e.VALOR_ACTUAL >= e.PROXIMO - e.AVISO AND e.VALOR_ACTUAL < e.PROXIMO


/* ---- 7. Certificaciones de especialidad vencidas o por vencer (HU-017 #3) ----
   Aviso desde 30 dias antes; vencida es ALTA. Es de la administracion del
   cliente, no de una planta: la persona trabaja donde la manden. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ESPECIALIDAD_USUARIO, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, SEVERIDAD)
SELECT  @T_CERTIFICACION, NULL, ue.ues_id,
        CASE WHEN ue.ues_fecha_vencimiento < @HOY THEN N'Certificación vencida: ' ELSE N'Certificación por vencer: ' END
            + e.esp_nombre + N' · ' + u.usu_nombre + N' ' + u.usu_apellido_paterno,
        CASE WHEN ue.ues_fecha_vencimiento < @HOY
             THEN N'La certificación de ' + e.esp_nombre + N' de ' + u.usu_nombre + N' ' + u.usu_apellido_paterno + N' venció el '
                  + CONVERT(NVARCHAR(10), ue.ues_fecha_vencimiento, 103) + N'. Mientras no se renueve, cada asignación que la exija quedará advertida.'
             ELSE N'La certificación de ' + e.esp_nombre + N' de ' + u.usu_nombre + N' ' + u.usu_apellido_paterno + N' vence el '
                  + CONVERT(NVARCHAR(10), ue.ues_fecha_vencimiento, 103) + N' (en ' + LTRIM(STR(DATEDIFF(DAY, @HOY, ue.ues_fecha_vencimiento))) + N' días). Programe la renovación.' END,
        DATEDIFF(DAY, @HOY, ue.ues_fecha_vencimiento), 30,
        CASE WHEN ue.ues_fecha_vencimiento < @HOY THEN @SEV_ALTA ELSE @SEV_ADV END
FROM    [dbo].[Usuario_Especialidad] ue
JOIN    [dbo].[Especialidad] e ON e.esp_id = ue.ues_especialidad
JOIN    [dbo].[Usuario] u ON u.usu_id = ue.ues_usuario
WHERE   ue.ues_cliente = @CLIENTE AND ue.ues_habilitado = 1 AND u.usu_habilitado = 1
  AND   ue.ues_fecha_vencimiento IS NOT NULL
  AND   ue.ues_fecha_vencimiento <= DATEADD(DAY, 30, @HOY)


/* ---- Abrir lo que empezo a pasar ---- */
INSERT INTO [dbo].[Alerta]
    (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
     ale_titulo, ale_descripcion, ale_fecha_deteccion_utc,
     ale_activo, ale_activo_componente, ale_activo_medidor, ale_activo_variable,
     ale_plan_mantenimiento_ocurrencia, ale_permiso_trabajo, ale_checklist_hallazgo, ale_orden_trabajo, ale_usuario_especialidad,
     ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
     ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
SELECT  NEWID(), @CLIENTE, h.INSTALACION, h.TIPO, @NUEVA, h.SEVERIDAD,
        h.TITULO, h.DESCRIPCION, @AHORA,
        h.ACTIVO, h.COMPONENTE, h.MEDIDOR, h.VARIABLE,
        h.OCURRENCIA, h.PERMISO, h.HALLAZGO, h.ORDEN, h.ESPECIALIDAD_USUARIO,
        h.OBSERVADO, h.UMBRAL, h.UNIDAD,
        @USUARIO, [dbo].[FNC_AHORA](), 1
FROM    #HALLAZGO h
WHERE   NOT EXISTS (
            SELECT 1 FROM [dbo].[Alerta] a
            WHERE  a.ale_cliente = @CLIENTE
              AND  a.ale_alerta_tipo = h.TIPO
              AND  a.ale_habilitado = 1
              AND  a.ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA)
              AND  ISNULL(a.ale_activo, -1)                       = ISNULL(h.ACTIVO, -1)
              AND  ISNULL(a.ale_activo_medidor, -1)               = ISNULL(h.MEDIDOR, -1)
              AND  ISNULL(a.ale_activo_variable, -1)              = ISNULL(h.VARIABLE, -1)
              AND  ISNULL(a.ale_plan_mantenimiento_ocurrencia, -1)= ISNULL(h.OCURRENCIA, -1)
              AND  ISNULL(a.ale_permiso_trabajo, -1)              = ISNULL(h.PERMISO, -1)
              AND  ISNULL(a.ale_checklist_hallazgo, -1)           = ISNULL(h.HALLAZGO, -1)
              AND  ISNULL(a.ale_usuario_especialidad, -1)         = ISNULL(h.ESPECIALIDAD_USUARIO, -1))

DECLARE @ABIERTAS_N INT = @@ROWCOUNT

/* ---- Cerrar lo que dejo de pasar ----
   Solo los tipos de ESTE detector: los de inventario los cierra el suyo. */
UPDATE  a
SET     a.ale_alerta_estado         = @RESUELTA,
        a.ale_fecha_atencion_utc    = @AHORA,
        /* CK_ALE_ATENCION: una fecha de atencion exige quien atendio. Lo
           atendio el detector, en nombre de quien lo disparo. */
        a.ale_usuario_atencion      = ISNULL(a.ale_usuario_atencion, @USUARIO),
        a.ale_motivo_resolucion     = ISNULL(a.ale_motivo_resolucion, N'La condición dejó de darse (detector automático).'),
        a.ale_usuario_actualizacion = @USUARIO,
        a.ale_fecha_actualizacion   = [dbo].[FNC_AHORA]()
FROM    [dbo].[Alerta] a
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   a.ale_alerta_tipo IN (@T_OCURRENCIA, @T_PERMISO, @T_SIN_LECTURA, @T_HALLAZGO, @T_DESCUBRIMIENTO, @T_PROXIMO, @T_CERTIFICACION)
  AND   a.ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA)
  AND   NOT EXISTS (
            SELECT 1 FROM #HALLAZGO h
            WHERE  h.TIPO = a.ale_alerta_tipo
              AND  ISNULL(h.ACTIVO, -1)     = ISNULL(a.ale_activo, -1)
              AND  ISNULL(h.MEDIDOR, -1)    = ISNULL(a.ale_activo_medidor, -1)
              AND  ISNULL(h.VARIABLE, -1)   = ISNULL(a.ale_activo_variable, -1)
              AND  ISNULL(h.OCURRENCIA, -1) = ISNULL(a.ale_plan_mantenimiento_ocurrencia, -1)
              AND  ISNULL(h.PERMISO, -1)    = ISNULL(a.ale_permiso_trabajo, -1)
              AND  ISNULL(h.HALLAZGO, -1)   = ISNULL(a.ale_checklist_hallazgo, -1)
              AND  ISNULL(h.ESPECIALIDAD_USUARIO, -1) = ISNULL(a.ale_usuario_especialidad, -1))

SELECT  @ABIERTAS_N AS ABIERTAS, @@ROWCOUNT AS CERRADAS
RETURN 0
GO

PRINT '--- GEN_ALERTA_OPERACION detecta certificaciones por vencer (bloque 249).'
GO
