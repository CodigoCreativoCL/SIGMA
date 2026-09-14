USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     IDEMPOTENCIA POR UUID PARA LO QUE LA APP ENCOLA DEL
--                  CICLO DE LA OT: FALLA, DIAGNOSTICO, ACCION,
--                  INDISPONIBILIDAD Y ASIGNACION.
-- =============================================
-- Bryan: «del sprint 5 asigname todo lo correspondiente a las OTs, haz la APP».
--
-- LA REGLA DE LA APP
--   Toda captura de terreno se encola, con el uuid generado AL ENCOLAR, y el
--   reintento tiene que responder lo mismo que la primera vez. Los cinco INS
--   del bloque 225 nacieron para la web (sin uuid). Aqui reciben @UUID
--   opcional -va ultimo: la web sigue llamando igual- y hacen el corte ANTES
--   de validar, como 209: un reintento sobre una falla que entretanto se
--   resolvio no puede responder «la falla ya esta resuelta» por una accion
--   que SI se registro.
--
-- LOS INDICES SON FILTRADOS
--   Lo que crea la web no lleva uuid y son todos NULL; un unique normal
--   dejaria pasar uno solo en toda la tabla. Falla ya tenia fal_uuid con
--   UX_FAL_UUID (NEWID() en el INSERT); ahora, si viene @UUID, se guarda ese.
--
-- LO QUE NO CAMBIA
--   Las reglas de negocio quedan donde estaban; este script solo antepone el
--   corte y guarda la columna. Las definiciones se generaron parcheando el
--   bloque 225 (\_scratch/gen_226.py), no reescribiendolas a mano.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA]
@ID                    INT = NULL OUTPUT,
@CLIENTE               INT,
@ACTIVO                INT,
@ACTIVO_COMPONENTE     INT = NULL,
@FALLA_SINTOMA         INT = NULL,
@CRITICIDAD_NIVEL      INT,
@TITULO                NVARCHAR(400),
@DESCRIPCION           NVARCHAR(MAX) = NULL,
@CONSECUENCIA          NVARCHAR(MAX) = NULL,
@ESTADO_POSTERIOR      INT = NULL,
@DETUVO_PRODUCCION     BIT = 0,
@FECHA_DETECCION_UTC   DATETIME = NULL,
@USUARIO               INT,
@UUID                  UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL
BEGIN
    SELECT @ID = fal_id FROM [dbo].[Falla] WHERE fal_uuid = @UUID
    IF @ID IS NOT NULL RETURN 0
END
SET @TITULO = LTRIM(RTRIM(@TITULO))
IF @FECHA_DETECCION_UTC IS NULL SET @FECHA_DETECCION_UTC = GETUTCDATE()

IF (@TITULO IS NULL OR @TITULO = N'')
BEGIN
    RAISERROR('1.- INDIQUE EL SÍNTOMA O TÍTULO DE LA FALLA.', 16, 1)
    RETURN -1
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ACTIVO_COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO)
BEGIN
    RAISERROR('3.- EL COMPONENTE NO ES DE ESE EQUIPO.', 16, 1)
    RETURN -1
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE crn_id = @CRITICIDAD_NIVEL AND crn_habilitado = 1)
BEGIN
    RAISERROR('4.- INDIQUE LA CRITICIDAD DE LA FALLA.', 16, 1)
    RETURN -1
END
IF @FECHA_DETECCION_UTC > DATEADD(MINUTE, 5, GETUTCDATE())
BEGIN
    RAISERROR('5.- LA FECHA DE DETECCIÓN NO PUEDE SER FUTURA.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Falla]
        (fal_uuid, fal_cliente, fal_activo, fal_activo_componente, fal_falla_sintoma, fal_criticidad_nivel, fal_titulo, fal_descripcion, fal_consecuencia,
         fal_activo_estado_posterior, fal_detuvo_produccion, fal_fecha_deteccion_utc, fal_usuario_reporta, fal_usuario_creacion, fal_fecha_creacion, fal_habilitado)
    VALUES
        (ISNULL(@UUID, NEWID()), @CLIENTE, @ACTIVO, @ACTIVO_COMPONENTE, @FALLA_SINTOMA, @CRITICIDAD_NIVEL, @TITULO, @DESCRIPCION, @CONSECUENCIA,
         @ESTADO_POSTERIOR, ISNULL(@DETUVO_PRODUCCION, 0), @FECHA_DETECCION_UTC, @USUARIO, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    -- HU-123 #4: el estado en que queda el equipo se registra en su historial, con el mismo SP de «Cambiar estado».
    -- Si el equipo ya esta en ese estado (una segunda falla del mismo equipo detenido) no hay cambio que registrar:
    -- la falla se guarda igual, con el estado posterior anotado.
    IF @ESTADO_POSTERIOR IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_activo_estado = @ESTADO_POSTERIOR)
    BEGIN
        DECLARE @MOT NVARCHAR(500) = LEFT(N'Falla: ' + @TITULO, 500), @H INT
        EXEC [dbo].[ACTIVO_CAMBIAR_ESTADO] @ID = @H OUTPUT, @ACTIVO = @ACTIVO, @CLIENTE = @CLIENTE, @NUEVO_ESTADO = @ESTADO_POSTERIOR, @MOTIVO = @MOT, @USUARIO = @USUARIO
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_FALLA', @MSG = @MSG
    RAISERROR('6.- NO FUE POSIBLE REGISTRAR LA FALLA: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN 0
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Falla_Diagnostico]') AND name = 'fdi_uuid')
    ALTER TABLE [dbo].[Falla_Diagnostico] ADD fdi_uuid UNIQUEIDENTIFIER NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[dbo].[Falla_Diagnostico]') AND name = 'UQ_FDI_UUID')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_FDI_UUID ON [dbo].[Falla_Diagnostico](fdi_uuid) WHERE fdi_uuid IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA_DIAGNOSTICO]
@ID                 INT = NULL OUTPUT,
@CLIENTE            INT,
@FALLA              INT,
@FALLA_MODO         INT = NULL,
@FALLA_CAUSA        INT = NULL,
@DIAGNOSTICO_METODO INT = NULL,
@DESCRIPCION        NVARCHAR(MAX),
@ES_DEFINITIVO      BIT = 0,
@CONFIANZA          DECIMAL(5,2) = NULL,
@USUARIO            INT,
@UUID                  UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL
BEGIN
    SELECT @ID = fdi_id FROM [dbo].[Falla_Diagnostico] WHERE fdi_uuid = @UUID
    IF @ID IS NOT NULL RETURN 0
END
SET @DESCRIPCION = LTRIM(RTRIM(@DESCRIPCION))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF (@DESCRIPCION IS NULL OR @DESCRIPCION = N'')
BEGIN
    RAISERROR('2.- DESCRIBA EL DIAGNÓSTICO.', 16, 1)
    RETURN -1
END
IF @CONFIANZA IS NOT NULL AND (@CONFIANZA < 0 OR @CONFIANZA > 100)
BEGIN
    RAISERROR('3.- LA CONFIANZA VA DE 0 A 100.', 16, 1)
    RETURN -1
END

-- Varios diagnosticos sucesivos (#2): el definitivo desmarca a los anteriores
IF @ES_DEFINITIVO = 1
    UPDATE [dbo].[Falla_Diagnostico] SET fdi_es_definitivo = 0, fdi_usuario_actualizacion = @USUARIO, fdi_fecha_actualizacion = @DATE_NOW
    WHERE fdi_falla = @FALLA AND fdi_es_definitivo = 1

INSERT INTO [dbo].[Falla_Diagnostico]
    (fdi_uuid, fdi_falla, fdi_falla_modo, fdi_falla_causa, fdi_diagnostico_metodo, fdi_descripcion, fdi_es_definitivo, fdi_confianza,
     fdi_usuario_diagnostica, fdi_fecha_diagnostico_utc, fdi_usuario_creacion, fdi_fecha_creacion, fdi_habilitado)
VALUES
    (@UUID, @FALLA, @FALLA_MODO, @FALLA_CAUSA, @DIAGNOSTICO_METODO, @DESCRIPCION, ISNULL(@ES_DEFINITIVO, 0), @CONFIANZA,
     @USUARIO, GETUTCDATE(), @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Falla_Accion]') AND name = 'fac_uuid')
    ALTER TABLE [dbo].[Falla_Accion] ADD fac_uuid UNIQUEIDENTIFIER NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[dbo].[Falla_Accion]') AND name = 'UQ_FAC_UUID')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_FAC_UUID ON [dbo].[Falla_Accion](fac_uuid) WHERE fac_uuid IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA_ACCION]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@FALLA             INT,
@FALLA_DIAGNOSTICO INT = NULL,
@ORDEN_TRABAJO     INT = NULL,
@DESCRIPCION       NVARCHAR(MAX),
@ES_DEFINITIVA     BIT = 0,
@FECHA_ACCION_UTC  DATETIME = NULL,
@USUARIO           INT,
@UUID                  UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL
BEGIN
    SELECT @ID = fac_id FROM [dbo].[Falla_Accion] WHERE fac_uuid = @UUID
    IF @ID IS NOT NULL RETURN 0
END
SET @DESCRIPCION = LTRIM(RTRIM(@DESCRIPCION))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF (@DESCRIPCION IS NULL OR @DESCRIPCION = N'')
BEGIN
    RAISERROR('2.- DESCRIBA LA ACCIÓN.', 16, 1)
    RETURN -1
END
IF @FALLA_DIAGNOSTICO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla_Diagnostico] WHERE fdi_id = @FALLA_DIAGNOSTICO AND fdi_falla = @FALLA)
BEGIN
    RAISERROR('3.- EL DIAGNÓSTICO NO ES DE ESTA FALLA.', 16, 1)
    RETURN -1
END
IF @ORDEN_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('4.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

INSERT INTO [dbo].[Falla_Accion]
    (fac_uuid, fac_falla, fac_falla_diagnostico, fac_orden_trabajo, fac_descripcion, fac_es_definitiva, fac_fecha_accion_utc, fac_usuario_ejecuta,
     fac_usuario_creacion, fac_fecha_creacion, fac_habilitado)
VALUES
    (@UUID, @FALLA, @FALLA_DIAGNOSTICO, @ORDEN_TRABAJO, @DESCRIPCION, ISNULL(@ES_DEFINITIVA, 0), ISNULL(@FECHA_ACCION_UTC, GETUTCDATE()), @USUARIO,
     @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()

-- Una accion definitiva cierra la falla si no tenia fecha de solucion
IF @ES_DEFINITIVA = 1
    UPDATE [dbo].[Falla] SET fal_fecha_solucion_utc = ISNULL(fal_fecha_solucion_utc, ISNULL(@FECHA_ACCION_UTC, GETUTCDATE())),
           fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW
    WHERE fal_id = @FALLA

RETURN 0
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Activo_Indisponibilidad]') AND name = 'ain_uuid')
    ALTER TABLE [dbo].[Activo_Indisponibilidad] ADD ain_uuid UNIQUEIDENTIFIER NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[dbo].[Activo_Indisponibilidad]') AND name = 'UQ_AIN_UUID')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_AIN_UUID ON [dbo].[Activo_Indisponibilidad](ain_uuid) WHERE ain_uuid IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_INDISPONIBILIDAD]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@ACTIVO            INT,
@ORDEN_TRABAJO     INT = NULL,
@FALLA             INT = NULL,
@FECHA_INICIO_UTC  DATETIME,
@FECHA_FIN_UTC     DATETIME = NULL,
@PLANIFICADA       BIT = 0,
@DETUVO_PRODUCCION BIT = 0,
@MOTIVO_CATALOGO   INT = NULL,
@MOTIVO            NVARCHAR(1000) = NULL,
@USUARIO           INT,
@UUID                  UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL
BEGIN
    SELECT @ID = ain_id FROM [dbo].[Activo_Indisponibilidad] WHERE ain_uuid = @UUID
    IF @ID IS NOT NULL RETURN 0
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @FECHA_INICIO_UTC IS NULL
BEGIN
    RAISERROR('2.- INDIQUE CUÁNDO EMPEZÓ LA INDISPONIBILIDAD.', 16, 1)
    RETURN -1
END
IF @FECHA_FIN_UTC IS NOT NULL AND @FECHA_FIN_UTC < @FECHA_INICIO_UTC
BEGIN
    RAISERROR('3.- EL TÉRMINO NO PUEDE SER ANTERIOR AL INICIO.', 16, 1)
    RETURN -1
END
IF @ORDEN_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('4.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END
IF @FALLA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('5.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF @MOTIVO_CATALOGO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE inm_id = @MOTIVO_CATALOGO AND inm_habilitado = 1)
BEGIN
    RAISERROR('6.- EL MOTIVO NO EXISTE.', 16, 1)
    RETURN -1
END
IF @MOTIVO_CATALOGO IS NULL AND (@MOTIVO IS NULL OR LTRIM(RTRIM(@MOTIVO)) = N'')
BEGIN
    RAISERROR('7.- INDIQUE EL MOTIVO DE LA INDISPONIBILIDAD.', 16, 1)
    RETURN -1
END

INSERT INTO [dbo].[Activo_Indisponibilidad]
    (ain_uuid, ain_cliente, ain_activo, ain_orden_trabajo, ain_falla, ain_fecha_inicio_utc, ain_fecha_fin_utc,
     ain_minuto, ain_planificada, ain_detuvo_produccion, ain_indisponibilidad_motivo, ain_motivo,
     ain_usuario_creacion, ain_fecha_creacion, ain_habilitado)
VALUES
    (@UUID, @CLIENTE, @ACTIVO, @ORDEN_TRABAJO, @FALLA, @FECHA_INICIO_UTC, @FECHA_FIN_UTC,
     CASE WHEN @FECHA_FIN_UTC IS NULL THEN NULL ELSE DATEDIFF(MINUTE, @FECHA_INICIO_UTC, @FECHA_FIN_UTC) END,   -- #1 los minutos se calculan
     ISNULL(@PLANIFICADA, 0), ISNULL(@DETUVO_PRODUCCION, 0), @MOTIVO_CATALOGO, @MOTIVO,
     @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Asignacion]') AND name = 'ota_uuid')
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion] ADD ota_uuid UNIQUEIDENTIFIER NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Asignacion]') AND name = 'UQ_OTA_UUID')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_OTA_UUID ON [dbo].[Orden_Trabajo_Asignacion](ota_uuid) WHERE ota_uuid IS NOT NULL
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
        SET @ADVERTENCIA = N'El técnico no tiene la especialidad requerida: ' + @FALTAN + N'.'
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

-- ---------------------------------------------------------------------------
-- Menu de la app: «Fallas». La navegacion del telefono se arma desde Menus
-- (GET /menus); sin esta fila la pantalla existe y nadie llega a ella.
-- Permiso 101 VER ORDENES TRABAJO para ver; registrar lo gobierna
-- REGISTRAR FALLA en la pantalla y en la API.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://fallas')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Fallas', N'Qué se rompió, qué se encontró y cómo se reparó', 2, 2109, 10, 'app://fallas', 1, 'mdi mdi-alert-circle-outline', 101, 2)
GO
