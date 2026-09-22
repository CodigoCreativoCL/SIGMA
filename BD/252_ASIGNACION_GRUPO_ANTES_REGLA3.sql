/* ============================================================================
   SIGMA — Bloque 252
   ORDEN ASIGNADA A UN GRUPO: EL LÍDER SALE ANTES DE LA REGLA 3        HU-016 #1
   ----------------------------------------------------------------------------

   El bloque 249 resolvia "grupo -> lider" DESPUES de la regla 3 ("indique un
   tecnico o una empresa externa"), asi que asignar una orden a un grupo desde
   el modal (sin tecnico) moria en la regla 3 antes de llegar al lider. Mismo
   SP, mismo texto: solo se mueve el bloque del grupo justo despues de la
   regla 2. IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

/* HU-016 #1/#2: la orden se asigna al GRUPO y la recibe su lider. Va antes
   de la regla 3 porque el grupo llega sin tecnico ni empresa: el lider sale
   de aqui. Si el grupo no tiene lider vigente hoy, se rechaza. */
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

PRINT '--- INS_ORDEN_TRABAJO_ASIGNACION resuelve el grupo antes de la regla 3 (bloque 252).'
GO
