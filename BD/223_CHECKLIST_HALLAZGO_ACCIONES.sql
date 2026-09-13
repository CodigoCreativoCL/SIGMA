USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     RESOLVER UN HALLAZGO: ORDEN DE TRABAJO O DESCARTE (HU-096 criterios 2 y 3).
-- =============================================
-- Un hallazgo pendiente termina de dos formas: se convierte en una orden
-- (origen HALLAZGO CHECKLIST, el hallazgo queda enlazado y PROCESADO, sale
-- de la bandeja) o se descarta con un motivo de al menos 10 caracteres
-- (queda CANCELADO con quien y cuando). Ninguna de las dos se deshace: por
-- eso ambas exigen que el hallazgo este PENDIENTE o EN PROCESO.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_HALLAZGO]
@ID       INT = NULL OUTPUT,
@CLIENTE  INT,
@HALLAZGO INT,
@USUARIO  INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @ESTADO INT, @OT INT, @ACTIVO INT, @COMPONENTE INT, @TITULO NVARCHAR(400), @DESC NVARCHAR(MAX),
        @SEV NVARCHAR(100), @INST INT, @AREA INT, @ACT_CODIGO NVARCHAR(100)

SELECT  @ESTADO = h.cha_proceso_estado, @OT = h.cha_orden_trabajo, @ACTIVO = h.cha_activo, @COMPONENTE = h.cha_activo_componente,
        @TITULO = h.cha_titulo, @DESC = h.cha_descripcion, @SEV = sev.sev_codigo,
        @INST = ISNULL(act.act_cliente_instalacion, cpl.cpl_cliente_instalacion), @AREA = act.act_instalacion_area, @ACT_CODIGO = act.act_codigo
FROM    [dbo].[Checklist_Hallazgo] h
LEFT JOIN [dbo].[Severidad] sev ON sev.sev_id = h.cha_severidad
LEFT JOIN [dbo].[Activo]    act ON act.act_id = h.cha_activo
LEFT JOIN [dbo].[Checklist_Ejecucion] cej ON cej.cej_id = h.cha_checklist_ejecucion
LEFT JOIN [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = cej.cej_checklist_plantilla_version
LEFT JOIN [dbo].[Checklist_Plantilla] cpl ON cpl.cpl_id = cpv.cpv_checklist_plantilla
WHERE   h.cha_id = @HALLAZGO AND h.cha_cliente = @CLIENTE AND h.cha_habilitado = 1

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- EL HALLAZGO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @OT IS NOT NULL
BEGIN
    SET @ID = @OT
    SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(1 AS BIT) AS YA_EXISTIA FROM [dbo].[Orden_Trabajo] WHERE otr_id = @OT
    RETURN 0
END

IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('2.- EL HALLAZGO YA FUE RESUELTO; NO SE GENERA ORDEN DESDE UNO PROCESADO O DESCARTADO.', 16, 1)
    RETURN -1
END

IF @INST IS NULL
BEGIN
    RAISERROR('3.- EL HALLAZGO NO TIENE PLANTA (NI POR EL EQUIPO NI POR LA PAUTA): NO SE PUEDE GENERAR LA ORDEN.', 16, 1)
    RETURN -1
END

DECLARE @PRIORIDAD INT = CASE @SEV WHEN 'CRITICA' THEN 4 WHEN 'ALTA' THEN 3 WHEN 'ADVERTENCIA' THEN 2 ELSE 1 END
DECLARE @CUERPO NVARCHAR(MAX) = ISNULL(@DESC, N'') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + N'Generada desde un hallazgo de inspección' + CASE WHEN @SEV IS NULL THEN N'' ELSE N' de severidad ' + LOWER(@SEV) END + N'.'

BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @CORR INT
    SELECT @CORR = ISNULL(MAX(otr_correlativo), 0) + 1 FROM [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK) WHERE otr_cliente = @CLIENTE

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo, otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen, otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion, otr_checklist_hallazgo, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @INST, @AREA, @CORR, @ACTIVO, @COMPONENTE,
         2, 1, 4, 1, @PRIORIDAD,          -- CORRECTIVA · RUTINARIO · HALLAZGO CHECKLIST · ABIERTA
         @USUARIO, LEFT(@TITULO, 400), @CUERPO, @HALLAZGO, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES (@ID, NULL, 1, N'Generada desde el hallazgo de inspección', GETUTCDATE(), @USUARIO, @DATE_NOW)

    -- Un paso: atender el hallazgo. Sin el, la orden no se puede finalizar.
    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        (otp_orden_trabajo, otp_orden, otp_nombre, otp_descripcion, otp_obligatorio, otp_resultado_paso, otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
    VALUES (@ID, 1, LEFT(N'Atender: ' + @TITULO, 400), @DESC, 1, 4, @USUARIO, @DATE_NOW, 1)

    UPDATE [dbo].[Checklist_Hallazgo]
    SET    cha_orden_trabajo = @ID, cha_proceso_estado = 3, cha_usuario_confirmacion = @USUARIO, cha_fecha_confirmacion_utc = GETUTCDATE(),
           cha_usuario_actualizacion = @USUARIO, cha_fecha_actualizacion = @DATE_NOW
    WHERE  cha_id = @HALLAZGO

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_HALLAZGO', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE GENERAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(0 AS BIT) AS YA_EXISTIA FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_HALLAZGO_DESCARTAR]
@ID      INT,
@CLIENTE INT,
@MOTIVO  NVARCHAR(1000),
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @MOTIVO = LTRIM(RTRIM(@MOTIVO))

DECLARE @ESTADO INT = (SELECT cha_proceso_estado FROM [dbo].[Checklist_Hallazgo] WHERE cha_id = @ID AND cha_cliente = @CLIENTE AND cha_habilitado = 1)

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- EL HALLAZGO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('2.- EL HALLAZGO YA FUE RESUELTO.', 16, 1)
    RETURN -1
END

IF @MOTIVO IS NULL OR LEN(@MOTIVO) < 10
BEGIN
    RAISERROR('3.- INDIQUE EL MOTIVO DEL DESCARTE (AL MENOS 10 CARACTERES).', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Checklist_Hallazgo]
SET    cha_proceso_estado = 5, cha_motivo_descarte = @MOTIVO, cha_usuario_confirmacion = @USUARIO, cha_fecha_confirmacion_utc = GETUTCDATE(),
       cha_usuario_actualizacion = @USUARIO, cha_fecha_actualizacion = @DATE_NOW
WHERE  cha_id = @ID

IF @@ROWCOUNT = 0
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_CHECKLIST_HALLAZGO_DESCARTAR', @MSG = '4.- NO FUE POSIBLE DESCARTAR EL HALLAZGO.'
    RETURN -1
END

RETURN 0
GO

-- Funciones de la bandeja: resolver exige crear OT (el permiso que ya existe)
DECLARE @M INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx')
DECLARE @P INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR ORDEN TRABAJO')
IF @M IS NOT NULL AND @P IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @P)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('INS_ORDEN_TRABAJO_HALLAZGO','UPD_CHECKLIST_HALLAZGO_DESCARTAR')) AS VARCHAR) + ' de 2' AS RESULTADO
GO
