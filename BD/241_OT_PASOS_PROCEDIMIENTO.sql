/* ============================================================================
   SIGMA — Bloque 241
   LA ORDEN DESPLIEGA LOS PASOS DEL PROCEDIMIENTO             HU-062 #1 · HU-061 #2
   ----------------------------------------------------------------------------

   INS_ORDEN_TRABAJO_OCURRENCIA creaba un paso por actividad del hito y, si
   la actividad referenciaba un procedimiento (paa_procedimiento), lo
   ignoraba: la orden salia con "Cambio de motorreductor" como paso unico y
   los diez pasos del procedimiento se quedaban en el maestro.

   Ahora cada paso del procedimiento es un paso de la orden
   (otp_procedimiento_paso apunta al origen), con nombre e instruccion
   copiados: la orden ya ejecutada conserva el texto que tenia, aunque el
   procedimiento se versione despues. Un punto de control queda obligatorio.

   Detectado el 17-09-2026 al preparar la evidencia del Sprint 3. SP
   completo tomado de la definicion vigente.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
    /* HU-062 #1 / HU-061 #2: si la actividad referencia un procedimiento,
       la orden trae un paso por cada paso del procedimiento, con el nombre
       y la instruccion COPIADOS en ese momento. Asi la orden conserva el
       texto que tenia al ejecutarse aunque el procedimiento cambie despues.
       Una actividad sin procedimiento sigue siendo un solo paso. */
    SELECT  @ID, pp.ppa_id, a.paa_id,
            ROW_NUMBER() OVER (ORDER BY a.paa_orden, a.paa_id, pp.ppa_orden),
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_nombre
                 ELSE a.paa_nombre + N' · ' + CAST(pp.ppa_orden AS NVARCHAR(10)) + N'. ' + pp.ppa_nombre END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_descripcion ELSE ISNULL(pp.ppa_instruccion, a.paa_descripcion) END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_obligatoria
                 WHEN pp.ppa_es_punto_control = 1 THEN 1 ELSE a.paa_obligatoria END,
            4, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Actividad] a
    LEFT JOIN [dbo].[Procedimiento_Paso] pp
           ON pp.ppa_procedimiento = a.paa_procedimiento AND pp.ppa_habilitado = 1
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

PRINT '--- INS_ORDEN_TRABAJO_OCURRENCIA despliega los pasos del procedimiento (bloque 241).'
GO
