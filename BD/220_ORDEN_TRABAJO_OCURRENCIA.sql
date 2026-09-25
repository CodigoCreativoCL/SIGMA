USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     GENERAR UNA ORDEN DE TRABAJO DESDE LA OCURRENCIA DE UN PLAN (HU-111).
-- =============================================
-- ES EL PASO QUE FALTABA ENTRE EL PLAN Y EL TRABAJO
--
--   El plan dice que y cada cuanto; la ocurrencia dice cuando y a que
--   equipo; la orden es lo que el tecnico ejecuta. Hasta aqui la ocurrencia
--   quedaba en el calendario sin forma de volverse trabajo.
--
-- TODO EL PROCESO EN UNA TRANSACCION, CON XACT_ABORT
--
--   Orden + pasos + repuestos + marca en la ocurrencia + historial. Si algo
--   falla a mitad, no queda una orden sin pasos ni una ocurrencia que dice
--   «tiene OT» apuntando a nada. SET XACT_ABORT ON hace que cualquier error
--   de la base -no solo los RAISERROR propios- deshaga todo.
--
-- LAS REGLAS VIVEN AQUI, NO EN LA PANTALLA (T-5048)
--
--   La web y la API llaman a este SP y obtienen lo mismo:
--     · solo ocurrencias del cliente, habilitadas y PENDIENTE o DISPONIBLE;
--     · una ocurrencia que ya tiene OT devuelve ESA (YA_EXISTIA = 1), nunca
--       genera dos: la generacion masiva reintenta sin miedo;
--     · el texto de cada paso se COPIA de la actividad (criterio 2): un
--       cambio posterior del plan no altera la orden ya generada; el paso
--       guarda el id de la actividad solo por trazabilidad;
--     · un paso por actividad habilitada del hito (criterio 1). Si el hito
--       no tiene actividades -HU-082 aun no cargo ninguna-, la orden nace
--       con UN paso que es el hito mismo, para que sea ejecutable: una
--       orden sin pasos no se puede finalizar;
--     · los repuestos planificados de esas actividades quedan cargados en
--       Orden_Trabajo_Repuesto con su cantidad planificada;
--     · tipo, prioridad, parada y duracion salen del hito; la estrategia es
--       OVERHAUL si el hito lo es y PROGRAMADO si no; el origen es PLAN.
--
-- LA OCURRENCIA PASA A «EN EJECUCION»
--
--   Es el estado que Plan_Ocurrencia_Estado tiene para «ya hay trabajo
--   abierto por esto». COMPLETADA la pondra el cierre de la OT (HU-120).
--   El cambio queda en Plan_Ocurrencia_Historial con su motivo.
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) INS_ORDEN_TRABAJO_OCURRENCIA
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_OCURRENCIA]
@ID         INT = NULL OUTPUT,
@CLIENTE    INT,
@OCURRENCIA INT,
@USUARIO    INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @ESTADO INT, @OT_EXISTE INT, @HITO INT, @ACTIVO INT, @COMPONENTE INT, @FECHA DATETIME,
        @PLAN_CODIGO NVARCHAR(100), @PLAN_NOMBRE NVARCHAR(400), @VERSION INT,
        @HITO_CODIGO NVARCHAR(100), @HITO_NOMBRE NVARCHAR(400), @HITO_DESC NVARCHAR(MAX),
        @OT_TIPO INT, @OT_PRIORIDAD INT, @PARADA BIT, @OVERHAUL BIT, @DURACION INT,
        @INST INT, @AREA INT, @ACT_CODIGO NVARCHAR(100), @ACT_NOMBRE NVARCHAR(400)

SELECT  @ESTADO      = o.pmo_plan_ocurrencia_estado,
        @OT_EXISTE   = o.pmo_orden_trabajo,
        @HITO        = o.pmo_plan_mantenimiento_hito,
        @ACTIVO      = o.pmo_activo,
        @COMPONENTE  = o.pmo_activo_componente,
        @FECHA       = o.pmo_fecha_programada_utc,
        @PLAN_CODIGO = pma.pma_codigo,
        @PLAN_NOMBRE = pma.pma_nombre,
        @VERSION     = pmv.pmv_numero,
        @HITO_CODIGO = h.pmh_codigo,
        @HITO_NOMBRE = h.pmh_nombre,
        @HITO_DESC   = h.pmh_descripcion,
        @OT_TIPO     = ISNULL(h.pmh_orden_trabajo_tipo, 1),          -- PREVENTIVA
        @OT_PRIORIDAD= ISNULL(h.pmh_orden_trabajo_prioridad, 2),     -- MEDIA
        @PARADA      = h.pmh_requiere_parada,
        @OVERHAUL    = h.pmh_es_overhaul,
        @DURACION    = h.pmh_duracion_estimada_minuto,
        @INST        = act.act_cliente_instalacion,
        @AREA        = act.act_instalacion_area,
        @ACT_CODIGO  = act.act_codigo,
        @ACT_NOMBRE  = act.act_nombre
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
WHERE   o.pmo_id = @OCURRENCIA AND o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1

IF @HITO IS NULL
BEGIN
    RAISERROR('1.- LA OCURRENCIA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- Idempotente: la que ya tiene orden devuelve esa.
IF @OT_EXISTE IS NOT NULL
BEGIN
    SET @ID = @OT_EXISTE
    SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(1 AS BIT) AS YA_EXISTIA
    FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @OT_EXISTE
    RETURN 0
END

IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('2.- SOLO SE GENERA ORDEN DESDE UNA OCURRENCIA PENDIENTE O DISPONIBLE.', 16, 1)
    RETURN -1
END

IF @INST IS NULL
BEGIN
    RAISERROR('3.- EL EQUIPO %s NO TIENE PLANTA: NO SE PUEDE GENERAR LA ORDEN.', 16, 1, @ACT_CODIGO)
    RETURN -1
END

DECLARE @TITULO NVARCHAR(400) = LEFT(@HITO_NOMBRE + N' · ' + @ACT_CODIGO + N' ' + @ACT_NOMBRE, 400)
DECLARE @CUERPO NVARCHAR(MAX) = ISNULL(@HITO_DESC, N'')
    + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + N'Generada desde el plan ' + @PLAN_CODIGO + N' «' + @PLAN_NOMBRE + N'» v' + CAST(@VERSION AS NVARCHAR(10))
    + N', hito ' + @HITO_CODIGO + N', programada para el ' + CONVERT(NVARCHAR(10), @FECHA, 103) + N'.'
    + CASE WHEN @PARADA = 1 THEN CHAR(13) + CHAR(10) + N'REQUIERE PARADA DEL EQUIPO.' ELSE N'' END

DECLARE @REQUIERE_PERMISO BIT = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                                                   WHERE paa_plan_mantenimiento_hito = @HITO AND paa_habilitado = 1 AND paa_requiere_permiso = 1)
                                     THEN 1 ELSE 0 END

BEGIN TRY
    BEGIN TRANSACTION

    -- Correlativo con el candado puesto: dos generaciones a la vez no sacan el mismo numero.
    DECLARE @CORR INT
    SELECT  @CORR = ISNULL(MAX(otr_correlativo), 0) + 1
    FROM    [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
    WHERE   otr_cliente = @CLIENTE

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo,
         otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen,
         otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion,
         otr_fecha_programada_utc, otr_duracion_estimada_minuto,
         otr_minuto_parada_activo, otr_requiere_permiso,
         otr_plan_mantenimiento_ocurrencia, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @INST, @AREA, @CORR,
         @ACTIVO, @COMPONENTE,
         @OT_TIPO, CASE WHEN @OVERHAUL = 1 THEN 5 ELSE 2 END, 2,
         1, @OT_PRIORIDAD,
         @USUARIO, @TITULO, @CUERPO,
         @FECHA, @DURACION,
         CASE WHEN @PARADA = 1 THEN @DURACION ELSE NULL END, @REQUIERE_PERMISO,
         @OCURRENCIA, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES
        (@ID, NULL, 1, N'Generada desde la ocurrencia del plan ' + @PLAN_CODIGO, GETUTCDATE(), @USUARIO, @DATE_NOW)

    -- Un paso por actividad, con el texto COPIADO (criterio 2)
    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        (otp_orden_trabajo, otp_procedimiento_paso, otp_plan_mantenimiento_actividad, otp_orden, otp_nombre, otp_descripcion,
         otp_obligatorio, otp_resultado_paso, otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
    SELECT  @ID, NULL, a.paa_id, ROW_NUMBER() OVER (ORDER BY a.paa_orden, a.paa_id), a.paa_nombre, a.paa_descripcion,
            a.paa_obligatoria, 4, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Actividad] a
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1

    -- Sin actividades cargadas: el hito es el unico paso, para que la orden sea ejecutable.
    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[Orden_Trabajo_Paso]
            (otp_orden_trabajo, otp_orden, otp_nombre, otp_descripcion, otp_obligatorio, otp_resultado_paso,
             otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
        VALUES
            (@ID, 1, @HITO_NOMBRE, @HITO_DESC, 1, 4, @USUARIO, @DATE_NOW, 1)

    -- Repuestos planificados de esas actividades
    INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
        (ore_orden_trabajo, ore_repuesto, ore_cantidad_planificada, ore_observacion, ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
    SELECT  @ID, r.pra_repuesto, SUM(r.pra_cantidad),
            CASE WHEN MAX(CAST(r.pra_obligatorio AS INT)) = 1 THEN N'Planificado por el plan (obligatorio)' ELSE N'Planificado por el plan' END,
            @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Actividad_Repuesto] r
    JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1
    GROUP BY r.pra_repuesto

    -- La ocurrencia queda enlazada y en ejecucion, con su rastro
    UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
    SET    pmo_orden_trabajo = @ID,
           pmo_plan_ocurrencia_estado = 3,
           pmo_usuario_actualizacion = @USUARIO,
           pmo_fecha_actualizacion = @DATE_NOW
    WHERE  pmo_id = @OCURRENCIA

    INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
        (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
    VALUES
        (@OCURRENCIA, @ESTADO, 3, N'Se generó la orden de trabajo OT-' + CAST(@CORR AS NVARCHAR(10)), @USUARIO, @DATE_NOW)

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_OCURRENCIA', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE GENERAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(0 AS BIT) AS YA_EXISTIA
FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @ID

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 2) SEL_ORDEN_TRABAJO_OCURRENCIA — el resultado del proceso
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_OCURRENCIA]
@CLIENTE    INT,
@OCURRENCIA INT = NULL,
@PLAN       INT = NULL,
@DESDE      DATE = NULL,
@HASTA      DATE = NULL

AS
SET NOCOUNT ON

SELECT  o.pmo_id                         AS PMO_ID,
        o.pmo_fecha_programada_utc       AS FECHA_PROGRAMADA,
        poe.poe_codigo                   AS OCURRENCIA_ESTADO_CODIGO,
        poe.poe_nombre                   AS OCURRENCIA_ESTADO_NOMBRE,
        pma.pma_id                       AS PLAN_ID,
        pma.pma_codigo                   AS PLAN_CODIGO,
        h.pmh_codigo                     AS HITO_CODIGO,
        h.pmh_nombre                     AS HITO_NOMBRE,
        act.act_codigo                   AS ACTIVO_CODIGO,
        act.act_nombre                   AS ACTIVO_NOMBRE,
        otr.otr_id                       AS OTR_ID,
        otr.otr_correlativo              AS OTR_CORRELATIVO,
        otr.otr_titulo                   AS OTR_TITULO,
        ote.ote_codigo                   AS OT_ESTADO_CODIGO,
        ote.ote_nombre                   AS OT_ESTADO_NOMBRE,
        oto.oto_nombre                   AS OT_ORIGEN_NOMBRE,
        otr.otr_fecha_creacion           AS OTR_FECHA_CREACION,
        LTRIM(RTRIM(ISNULL(ug.usu_nombre,'') + ' ' + ISNULL(ug.usu_apellido_paterno,''))) AS GENERADOR_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p WHERE p.otp_orden_trabajo = otr.otr_id AND p.otp_habilitado = 1) AS PASOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Repuesto] r WHERE r.ore_orden_trabajo = otr.otr_id AND r.ore_habilitado = 1) AS REPUESTOS
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
JOIN    [dbo].[Plan_Ocurrencia_Estado]     poe ON poe.poe_id = o.pmo_plan_ocurrencia_estado
LEFT JOIN [dbo].[Orden_Trabajo]            otr ON otr.otr_id = o.pmo_orden_trabajo
LEFT JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.ote_id = otr.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo_Origen]     oto ON oto.oto_id = otr.otr_orden_trabajo_origen
LEFT JOIN [dbo].[Usuario]                  ug  ON ug.usu_id  = otr.otr_usuario_generador
WHERE   o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1
  AND   o.pmo_orden_trabajo IS NOT NULL
  AND   (@OCURRENCIA IS NULL OR o.pmo_id = @OCURRENCIA)
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)
  AND   (@DESDE IS NULL OR o.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
  AND   (@HASTA IS NULL OR o.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
ORDER BY otr.otr_correlativo DESC
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('INS_ORDEN_TRABAJO_OCURRENCIA','SEL_ORDEN_TRABAJO_OCURRENCIA')) AS VARCHAR) + ' de 2' AS RESULTADO
GO
