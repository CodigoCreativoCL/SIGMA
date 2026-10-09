SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   398 · Órdenes de trabajo: lista y ficha nuevas · 09-10-2026  (parte c)

   La lista y la ficha del lugar «Órdenes de trabajo» (Ordenes/Ordenes.aspx) leen:
     SEL_OT_LISTA ........... la lista (con «Viene de» y los responsables)
     SEL_OT_FICHA_EXTRA ..... de dónde viene, avisos vinculados y bitácora de una OT
   y escriben con los SP que ya existían (UPD_ORDEN_TRABAJO_TOMAR / _FINALIZAR /
   _CERRAR_WEB, INS/DEL_ORDEN_TRABAJO_ASIGNACION, API_UPD_ORDEN_TRABAJO_PASO) más:
     UPS_OT_INFORME ......... el informe de cierre: trabajo realizado (≥ 10 caracteres),
                              horas reales, estado del activo al terminar y causa
     UPD_OT_DEVOLVER ........ quien tiene la facultad de cerrar la devuelve de «En espera de cierre» a «En ejecución»
     INS_OT_HALLAZGO_EN_OT .. «¿Encontraste algo que no es parte de esta OT?»: crea un
                              aviso de origen 9 enlazado a la OT donde se encontró
   Las fechas de la OT se muestran como están guardadas (hora de la planta).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO

/* ---- la lista ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_LISTA]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT  o.otr_id AS OT_ID, o.otr_correlativo AS NUMERO, o.otr_titulo AS TITULO,
        o.otr_cliente_instalacion AS PLANTA_ID, o.otr_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA,
        o.otr_activo AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, aco.aco_nombre AS COMPONENTE,
        o.otr_orden_trabajo_tipo AS TIPO_ID, o.otr_orden_trabajo_prioridad AS PRIORIDAD_ID, o.otr_orden_trabajo_estado AS ESTADO_ID,
        o.otr_orden_trabajo_origen AS ORIGEN_ID,
        CASE o.otr_orden_trabajo_origen
             WHEN 2 THEN ISNULL((SELECT TOP 1 pma.pma_codigo FROM [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
                                 JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = pmo.pmo_plan_mantenimiento_hito
                                 JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
                                 JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
                                 WHERE pmo.pmo_id = o.otr_plan_mantenimiento_ocurrencia), N'')
             WHEN 3 THEN ISNULL((SELECT TOP 1 t.tar_codigo FROM [dbo].[Tarea_Ocurrencia] toc JOIN [dbo].[Tarea] t ON t.tar_id = toc.toc_tarea WHERE toc.toc_id = o.otr_tarea_ocurrencia), N'')
             WHEN 4 THEN N'HAL-' + CAST(o.otr_checklist_hallazgo AS NVARCHAR(12))
             WHEN 7 THEN N'FAL-' + CAST(o.otr_falla AS NVARCHAR(12))
             ELSE N'' END AS REFERENCIA,
        o.otr_fecha_programada_utc AS PROGRAMADA, o.otr_fecha_cierre AS CIERRE,
        CAST(CASE WHEN ISNULL(o.otr_minuto_parada_activo, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS PARADA,
        (SELECT STRING_AGG(LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))), N'|') WITHIN GROUP (ORDER BY a.ota_es_responsable DESC, a.ota_id)
           FROM [dbo].[Orden_Trabajo_Asignacion] a JOIN [dbo].[Usuario] u ON u.usu_id = a.ota_usuario
          WHERE a.ota_orden_trabajo = o.otr_id AND a.ota_habilitado = 1 AND a.ota_usuario IS NOT NULL) AS RESPONSABLES
FROM    [dbo].[Orden_Trabajo] o
JOIN    [dbo].[Activo] act ON act.act_id = o.otr_activo
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = o.otr_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.otr_activo_componente
WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
  AND   (@INSTALACION IS NULL OR o.otr_cliente_instalacion = @INSTALACION)
  AND   (o.otr_orden_trabajo_estado < 4 OR o.otr_fecha_cierre >= DATEADD(DAY, -120, [dbo].[FNC_AHORA]()))
ORDER BY CASE o.otr_orden_trabajo_estado WHEN 2 THEN 0 WHEN 1 THEN 1 WHEN 3 THEN 2 ELSE 3 END, o.otr_fecha_programada_utc, o.otr_id DESC
RETURN 0
GO

/* ---- lo que la ficha necesita además de SEL_ORDEN_TRABAJO y sus pasos, repuestos y asignaciones ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_FICHA_EXTRA]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
/* 0 · de dónde viene: el plan (con su ficha), la tarea, el hallazgo, la falla, la predicción o la alerta */
SELECT  o.otr_orden_trabajo_origen AS ORIGEN_ID,
        pma.pma_id AS PLAN_ID, pma.pma_codigo AS PLAN_CODIGO, pma.pma_nombre AS PLAN_NOMBRE, h.pmh_nombre AS INTERVENCION,
        t.tar_id AS TAREA_ID, t.tar_codigo AS TAREA_CODIGO, t.tar_titulo AS TAREA_TITULO,
        o.otr_checklist_hallazgo AS HALLAZGO_ID, o.otr_falla AS FALLA_ID, o.otr_prediccion AS PREDICCION_ID,
        orig.otr_id AS OT_ORIGEN_ID, orig.otr_correlativo AS OT_ORIGEN_NUMERO
FROM    [dbo].[Orden_Trabajo] o
LEFT JOIN [dbo].[Plan_Mantenimiento_Ocurrencia] pmo ON pmo.pmo_id = o.otr_plan_mantenimiento_ocurrencia
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = pmo.pmo_plan_mantenimiento_hito
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Tarea_Ocurrencia] toc ON toc.toc_id = o.otr_tarea_ocurrencia
LEFT JOIN [dbo].[Tarea] t ON t.tar_id = toc.toc_tarea
LEFT JOIN [dbo].[Orden_Trabajo] orig ON orig.otr_id = o.otr_ot_origen
WHERE   o.otr_id = @ID AND o.otr_cliente = @CLIENTE

/* 1 · los avisos que esta OT resolvió (o que se vincularon a ella) y los que se encontraron al ejecutarla */
SELECT  v.AVISO, v.ORIGEN, v.REF, v.TITULO, v.SEVERIDAD, v.ESTADO,
        CASE WHEN v.OT_ID = @ID THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS RESUELTO_AQUI
FROM    [dbo].[VW_AVISOS] v
WHERE   v.CLIENTE = @CLIENTE AND (v.OT_ID = @ID OR (v.ORIGEN = 9 AND v.OT_ORIGEN = @ID))
ORDER BY v.FECHA DESC

/* 2 · la bitácora: cambios de estado con quién y cuándo */
SELECT  h.oeh_id AS ID, h.oeh_estado_anterior AS ESTADO_ANTERIOR, h.oeh_estado_nuevo AS ESTADO_NUEVO, h.oeh_motivo AS MOTIVO,
        h.oeh_fecha_cambio_utc AS FECHA_UTC, h.oeh_fecha_creacion AS FECHA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS QUIEN
FROM    [dbo].[Orden_Trabajo_Estado_Historial] h
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.oeh_usuario_creacion
WHERE   h.oeh_orden_trabajo = @ID
ORDER BY h.oeh_id DESC
RETURN 0
GO

/* ---- el informe de cierre de quien ejecuta ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_OT_INFORME]
    @CLIENTE          INT,
    @ID               INT,
    @INFORME          NVARCHAR(MAX),
    @HORAS_REALES     DECIMAL(9,2) = NULL,
    @ESTADO_ACTIVO    INT = NULL,
    @CAUSA            NVARCHAR(500) = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
SET @INFORME = LTRIM(RTRIM(ISNULL(@INFORME, N'')))
IF LEN(@INFORME) < 10
BEGIN
    RAISERROR('1.- DESCRIBA EL TRABAJO REALIZADO (AL MENOS 10 CARACTERES).', 16, 1)
    RETURN -1
END
IF @HORAS_REALES IS NOT NULL AND (@HORAS_REALES < 0 OR @HORAS_REALES > 999)
BEGIN
    RAISERROR('2.- LAS HORAS REALES NO SON VÁLIDAS.', 16, 1)
    RETURN -1
END
DECLARE @ESTADO INT, @ACTIVO INT, @TIPO INT, @CORR INT
SELECT @ESTADO = otr_orden_trabajo_estado, @ACTIVO = otr_activo, @TIPO = otr_orden_trabajo_tipo, @CORR = otr_correlativo
FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID AND otr_cliente = @CLIENTE AND otr_habilitado = 1
IF @ESTADO IS NULL
BEGIN
    RAISERROR('3.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END
IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('4.- LA ORDEN YA NO ESTÁ EN EJECUCIÓN: EL INFORME NO SE PUEDE CAMBIAR.', 16, 1)
    RETURN -1
END
IF @TIPO = 2 AND LEN(LTRIM(RTRIM(ISNULL(@CAUSA, N'')))) < 3
BEGIN
    RAISERROR('5.- INDIQUE LA CAUSA DE LA FALLA (ES UNA ORDEN CORRECTIVA).', 16, 1)
    RETURN -1
END
BEGIN TRY
    BEGIN TRANSACTION
    UPDATE [dbo].[Orden_Trabajo]
    SET    otr_resultado = @INFORME,
           otr_duracion_real_minuto = CASE WHEN @HORAS_REALES IS NULL THEN otr_duracion_real_minuto ELSE CAST(ROUND(@HORAS_REALES * 60, 0) AS INT) END,
           otr_notas = CASE WHEN LEN(LTRIM(RTRIM(ISNULL(@CAUSA, N'')))) = 0 THEN otr_notas
                            ELSE LEFT(ISNULL(otr_notas + CHAR(13) + CHAR(10), N'') + N'Causa de la falla: ' + LTRIM(RTRIM(@CAUSA)), 4000) END,
           otr_usuario_actualizacion = @USUARIO, otr_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  otr_id = @ID
    IF @ESTADO_ACTIVO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_activo_estado = @ESTADO_ACTIVO)
    BEGIN
        DECLARE @H INT, @MOT NVARCHAR(500) = N'Al terminar la OT-' + CAST(@CORR AS NVARCHAR(12))
        EXEC [dbo].[ACTIVO_CAMBIAR_ESTADO] @ID = @H OUTPUT, @ACTIVO = @ACTIVO, @CLIENTE = @CLIENTE, @NUEVO_ESTADO = @ESTADO_ACTIVO, @MOTIVO = @MOT, @ORDEN_TRABAJO = @ID, @USUARIO = @USUARIO
    END
    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPS_OT_INFORME', @MSG = @MSG
    RAISERROR('6.- NO FUE POSIBLE GUARDAR EL INFORME: %s', 16, 1, @MSG)
    RETURN -1
END CATCH
RETURN 0
GO

/* ---- devolver a ejecución (quien revisa no aprueba el informe) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_OT_DEVOLVER]
    @CLIENTE INT,
    @ID      INT,
    @MOTIVO  NVARCHAR(500),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
SET @MOTIVO = LTRIM(RTRIM(ISNULL(@MOTIVO, N'')))
IF LEN(@MOTIVO) < 5
BEGIN
    RAISERROR('1.- INDIQUE QUÉ FALTA CORREGIR (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END
IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
BEGIN
    RAISERROR('2.- SU PERFIL NO TIENE LA FACULTAD DE CERRAR ÓRDENES DE TRABAJO.', 16, 1)
    RETURN -1
END
UPDATE [dbo].[Orden_Trabajo]
SET    otr_orden_trabajo_estado = 2, otr_fecha_fin_real_utc = NULL, otr_usuario_actualizacion = @USUARIO, otr_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  otr_id = @ID AND otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado = 3
IF @@ROWCOUNT = 0
BEGIN
    RAISERROR('3.- LA ORDEN NO ESTÁ EN ESPERA DE CIERRE.', 16, 1)
    RETURN -1
END
INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial] (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_usuario_creacion)
VALUES (@ID, 3, 2, LEFT(N'Devuelta a ejecución: ' + @MOTIVO, 500), @USUARIO)
RETURN 0
GO

/* ---- «¿Encontraste algo que no es parte de esta OT?» → aviso de origen 9 ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_OT_HALLAZGO_EN_OT]
    @CLIENTE    INT,
    @OT         INT,
    @TITULO     NVARCHAR(400),
    @COMPONENTE INT = NULL,
    @SEVERIDAD  INT,                 -- 1 Baja · 2 Media · 3 Alta · 4 Crítica
    @DETALLE    NVARCHAR(MAX) = NULL,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
SET @TITULO = LTRIM(RTRIM(ISNULL(@TITULO, N'')))
IF LEN(@TITULO) < 5
BEGIN
    RAISERROR('1.- DESCRIBA LO QUE ENCONTRASTE (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END
IF @SEVERIDAD NOT BETWEEN 1 AND 4
BEGIN
    RAISERROR('2.- ELIJA LA SEVERIDAD.', 16, 1)
    RETURN -1
END
DECLARE @ACTIVO INT, @ESTADO INT, @CORR INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @ACTIVO = otr_activo, @ESTADO = otr_orden_trabajo_estado, @CORR = otr_correlativo FROM [dbo].[Orden_Trabajo] WHERE otr_id = @OT AND otr_cliente = @CLIENTE AND otr_habilitado = 1
IF @ACTIVO IS NULL
BEGIN
    RAISERROR('3.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
IF @COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @COMPONENTE AND aco_activo = @ACTIVO)
    SET @COMPONENTE = NULL
DECLARE @SEV INT = CASE @SEVERIDAD WHEN 4 THEN 5 WHEN 3 THEN 4 WHEN 2 THEN 3 ELSE 2 END   -- a la escala del catálogo Severidad
INSERT INTO [dbo].[Checklist_Hallazgo]
    (cha_cliente, cha_activo, cha_activo_componente, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado, cha_orden_trabajo_origen, cha_usuario_creacion, cha_fecha_creacion)
VALUES
    (@CLIENTE, @ACTIVO, @COMPONENTE, @TITULO, ISNULL(@DETALLE, N'Detectado al ejecutar la OT-' + CAST(@CORR AS NVARCHAR(12)) + N'.'), @SEV, 1, @OT, @USUARIO, @DATE_NOW)
SELECT SCOPE_IDENTITY() AS HALLAZGO_ID
RETURN 0
GO
/* ---- «Nueva OT» manual: la crea con el SP de siempre y asigna al responsable ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_OT_NUEVA]
    @CLIENTE      INT,
    @ACTIVO       INT,
    @COMPONENTE   INT = NULL,
    @TITULO       NVARCHAR(400),
    @DESCRIPCION  NVARCHAR(MAX) = NULL,
    @TIPO         INT,
    @PRIORIDAD    INT,
    @FECHA        DATETIME = NULL,
    @DURACION_MIN INT = NULL,
    @RESPONSABLE  INT = NULL,
    @USUARIO      INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @ID INT, @CORR INT
EXEC [dbo].[INS_ORDEN_TRABAJO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO, @ACTIVO_COMPONENTE = @COMPONENTE,
     @TIPO = @TIPO, @ESTRATEGIA = 1, @PRIORIDAD = @PRIORIDAD, @TITULO = @TITULO, @DESCRIPCION = @DESCRIPCION,
     @FECHA_PROGRAMADA_UTC = @FECHA, @DURACION_ESTIMADA_MINUTO = @DURACION_MIN, @USUARIO = @USUARIO
IF @ID IS NULL RETURN -1
IF @RESPONSABLE IS NOT NULL
BEGIN
    DECLARE @A INT
    EXEC [dbo].[INS_ORDEN_TRABAJO_ASIGNACION] @ID = @A OUTPUT, @CLIENTE = @CLIENTE, @ORDEN = @ID, @USUARIO_ASIG = @RESPONSABLE, @ES_RESPONSABLE = 1, @ROL_EJECUCION = 1, @USUARIO = @USUARIO
END
SELECT @CORR = otr_correlativo FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID
SELECT @ID AS OTR_ID, @CORR AS OTR_CORRELATIVO
RETURN 0
GO
/* ---- los motivos de cierre (para quien cierra) ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_CIERRE_MOTIVO]
AS
SET NOCOUNT ON
SELECT ocm_id AS ID, ocm_nombre AS NOMBRE FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_habilitado = 1 ORDER BY ocm_orden, ocm_id
RETURN 0
GO
/* ---- ¿puede esta persona cerrar OT? (la facultad del perfil: la misma que exigen los SP de cierre) ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_PUEDE_CERRAR]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SELECT CAST([dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) AS BIT) AS PUEDE
RETURN 0
GO
PRINT '398_OT_FICHA aplicado.'
GO
