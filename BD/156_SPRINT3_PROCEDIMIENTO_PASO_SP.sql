USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     SPRINT 3 (HU-062) - SP DE PASOS DE PROCEDIMIENTO.
--                  T-3284 SEL / T-3285 INS / T-3286 UPD / T-3287 DEL.
-- =============================================
-- Los pasos cuelgan de un Procedimiento (Procedimiento_Paso). No tienen
-- cliente propio: el cliente y "es global" salen del procedimiento padre. Solo
-- se pueden crear/editar/dar de baja pasos de procedimientos DEL CLIENTE (los
-- globales se ven, no se tocan). El (procedimiento, orden) es unico. Un paso con
-- medicion exige la variable. La baja es logica y rechaza si el paso ya se uso
-- en una orden. Fechas selladas con FNC_PAIS_HORA. TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_PROCEDIMIENTO_PASO                                        T-3284
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROCEDIMIENTO_PASO]
    @CLIENTE        INT,
    @ID             INT = NULL,
    @PROCEDIMIENTO  INT = NULL,
    @FILTRO         VARCHAR(200) = NULL,
    @HABILITADO     BIT = NULL
AS
SET NOCOUNT ON

    SELECT  s.ppa_id,
            s.ppa_procedimiento,
            s.ppa_orden,
            s.ppa_nombre,
            ISNULL(s.ppa_instruccion, '')             AS ppa_instruccion,
            s.ppa_es_punto_control,
            s.ppa_requiere_evidencia,
            s.ppa_requiere_medicion,
            s.ppa_variable_medicion,
            s.ppa_duracion_estimada_minuto,
            s.ppa_habilitado,
            s.ppa_usuario_creacion,
            s.ppa_fecha_creacion,
            s.ppa_usuario_actualizacion,
            s.ppa_fecha_actualizacion,

            p.prc_codigo                              AS PROCEDIMIENTO_CODIGO,
            p.prc_nombre                              AS PROCEDIMIENTO_NOMBRE,
            p.prc_version                             AS PROCEDIMIENTO_VERSION,
            CAST(CASE WHEN p.prc_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(v.vme_nombre, '')                  AS VARIABLE_NOMBRE,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Procedimiento_Paso] s
    JOIN    [dbo].[Procedimiento] p            ON p.prc_id = s.ppa_procedimiento
    LEFT JOIN [dbo].[Variable_Medicion] v      ON v.vme_id = s.ppa_variable_medicion
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = s.ppa_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = s.ppa_usuario_actualizacion
    /* Los pasos de procedimientos globales (cliente NULL) valen para todos. */
    WHERE   (p.prc_cliente IS NULL OR p.prc_cliente = @CLIENTE)
      AND   (@ID           IS NULL OR s.ppa_id           = @ID)
      AND   (@PROCEDIMIENTO IS NULL OR s.ppa_procedimiento = @PROCEDIMIENTO)
      AND   (@HABILITADO   IS NULL OR s.ppa_habilitado   = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR s.ppa_nombre      LIKE '%' + @FILTRO + '%'
             OR s.ppa_instruccion LIKE '%' + @FILTRO + '%'
             OR p.prc_codigo      LIKE '%' + @FILTRO + '%'
             OR p.prc_nombre      LIKE '%' + @FILTRO + '%')
    ORDER BY p.prc_codigo, p.prc_version, s.ppa_orden
GO
PRINT '--- SEL_PROCEDIMIENTO_PASO creado.'
GO


/* ========================================================================
   2. INS_PROCEDIMIENTO_PASO                                        T-3285
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_PROCEDIMIENTO_PASO]
    @ID                 INT OUTPUT,
    @CLIENTE            INT,
    @PROCEDIMIENTO      INT,
    @ORDEN             INT = NULL,
    @NOMBRE            NVARCHAR(200),
    @INSTRUCCION       NVARCHAR(MAX) = NULL,
    @ES_PUNTO_CONTROL  BIT = 0,
    @REQUIERE_EVIDENCIA BIT = 0,
    @REQUIERE_MEDICION BIT = 0,
    @VARIABLE          INT = NULL,
    @DURACION          INT = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PRC_CLIENTE INT, @PAIS INT, @AHORA DATETIME, @EXISTE BIT
SELECT @PRC_CLIENTE = prc_cliente, @EXISTE = 1 FROM [dbo].[Procedimiento] WHERE prc_id = @PROCEDIMIENTO

SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

IF @EXISTE IS NULL
BEGIN RAISERROR('1.- EL PROCEDIMIENTO NO EXISTE.', 16, 1) RETURN -1 END

IF @PRC_CLIENTE IS NULL
BEGIN RAISERROR('2.- ES UN PROCEDIMIENTO GLOBAL DEL SISTEMA: NO SE LE AGREGAN PASOS DESDE EL CLIENTE.', 16, 1) RETURN -1 END

IF @PRC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('3.- EL PROCEDIMIENTO PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN RAISERROR('4.- INDIQUE EL NOMBRE DEL PASO.', 16, 1) RETURN -1 END

-- Medicion exige variable; sin medicion no se guarda variable.
IF @REQUIERE_MEDICION = 1 AND @VARIABLE IS NULL
BEGIN RAISERROR('5.- EL PASO REQUIERE MEDICION: INDIQUE LA VARIABLE.', 16, 1) RETURN -1 END
IF @REQUIERE_MEDICION = 0 SET @VARIABLE = NULL

-- Orden: si no viene, va al final; si viene, debe ser unico en el procedimiento.
IF @ORDEN IS NULL OR @ORDEN < 1
    SELECT @ORDEN = ISNULL(MAX(ppa_orden), 0) + 1 FROM [dbo].[Procedimiento_Paso] WHERE ppa_procedimiento = @PROCEDIMIENTO

IF EXISTS (SELECT 1 FROM [dbo].[Procedimiento_Paso] WHERE ppa_procedimiento = @PROCEDIMIENTO AND ppa_orden = @ORDEN)
BEGIN RAISERROR('6.- YA EXISTE UN PASO CON ESE ORDEN EN EL PROCEDIMIENTO.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET    @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRAN
    INSERT INTO [dbo].[Procedimiento_Paso]
        (ppa_procedimiento, ppa_orden, ppa_nombre, ppa_instruccion,
         ppa_es_punto_control, ppa_requiere_evidencia, ppa_requiere_medicion, ppa_variable_medicion,
         ppa_duracion_estimada_minuto, ppa_usuario_creacion, ppa_fecha_creacion, ppa_habilitado)
    VALUES
        (@PROCEDIMIENTO, @ORDEN, @NOMBRE, @INSTRUCCION,
         @ES_PUNTO_CONTROL, @REQUIERE_EVIDENCIA, @REQUIERE_MEDICION, @VARIABLE,
         @DURACION, @USUARIO, @AHORA, 1)
    SET @ID = SCOPE_IDENTITY()
COMMIT

SELECT 200 AS ID, 200 AS CODE, 'Paso creado con exito.' AS MENSAJE
GO
PRINT '--- INS_PROCEDIMIENTO_PASO creado.'
GO


/* ========================================================================
   3. UPD_PROCEDIMIENTO_PASO                                        T-3286
   ======================================================================== */
-- Los campos que la ficha no muestra se conservan con ISNULL(@X, columna).
CREATE OR ALTER PROCEDURE [dbo].[UPD_PROCEDIMIENTO_PASO]
    @ID                 INT,
    @CLIENTE            INT,
    @ORDEN             INT = NULL,
    @NOMBRE            NVARCHAR(200) = NULL,
    @INSTRUCCION       NVARCHAR(MAX) = NULL,
    @ES_PUNTO_CONTROL  BIT = NULL,
    @REQUIERE_EVIDENCIA BIT = NULL,
    @REQUIERE_MEDICION BIT = NULL,
    @VARIABLE          INT = NULL,
    @QUITA_VARIABLE    BIT = 0,
    @DURACION          INT = NULL,
    @HABILITADO        BIT = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PRC INT, @PRC_CLIENTE INT, @PAIS INT, @AHORA DATETIME
DECLARE @O INT, @NOM NVARCHAR(200), @INS NVARCHAR(MAX), @PC BIT, @EV BIT, @MED BIT, @VAR INT, @DUR INT, @HAB BIT

SELECT @PRC = s.ppa_procedimiento, @PRC_CLIENTE = p.prc_cliente,
       @O = s.ppa_orden, @NOM = s.ppa_nombre, @INS = s.ppa_instruccion,
       @PC = s.ppa_es_punto_control, @EV = s.ppa_requiere_evidencia,
       @MED = s.ppa_requiere_medicion, @VAR = s.ppa_variable_medicion,
       @DUR = s.ppa_duracion_estimada_minuto, @HAB = s.ppa_habilitado
FROM   [dbo].[Procedimiento_Paso] s
JOIN   [dbo].[Procedimiento] p ON p.prc_id = s.ppa_procedimiento
WHERE  s.ppa_id = @ID

IF @PRC IS NULL
BEGIN RAISERROR('1.- EL PASO NO EXISTE.', 16, 1) RETURN -1 END
IF @PRC_CLIENTE IS NULL
BEGIN RAISERROR('2.- ES UN PASO DE UN PROCEDIMIENTO GLOBAL: NO SE EDITA DESDE EL CLIENTE.', 16, 1) RETURN -1 END
IF @PRC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('3.- EL PASO PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

-- Valores finales (lo que no viene se conserva).
SET @NOM = LTRIM(RTRIM(ISNULL(@NOMBRE, @NOM)))
SET @INS = ISNULL(@INSTRUCCION, @INS)
SET @PC  = ISNULL(@ES_PUNTO_CONTROL, @PC)
SET @EV  = ISNULL(@REQUIERE_EVIDENCIA, @EV)
SET @MED = ISNULL(@REQUIERE_MEDICION, @MED)
SET @DUR = ISNULL(@DURACION, @DUR)
SET @HAB = ISNULL(@HABILITADO, @HAB)
IF @ORDEN IS NOT NULL AND @ORDEN >= 1 SET @O = @ORDEN

-- Variable: se puede fijar (@VARIABLE) o quitar (@QUITA_VARIABLE); si no, se conserva.
IF @QUITA_VARIABLE = 1 SET @VAR = NULL
ELSE IF @VARIABLE IS NOT NULL SET @VAR = @VARIABLE

IF (@NOM IS NULL OR LEN(@NOM) = 0)
BEGIN RAISERROR('4.- INDIQUE EL NOMBRE DEL PASO.', 16, 1) RETURN -1 END
IF @MED = 1 AND @VAR IS NULL
BEGIN RAISERROR('5.- EL PASO REQUIERE MEDICION: INDIQUE LA VARIABLE.', 16, 1) RETURN -1 END
IF @MED = 0 SET @VAR = NULL

-- Orden unico dentro del procedimiento (excluyendo el propio paso).
IF EXISTS (SELECT 1 FROM [dbo].[Procedimiento_Paso]
           WHERE ppa_procedimiento = @PRC AND ppa_orden = @O AND ppa_id <> @ID)
BEGIN RAISERROR('6.- YA EXISTE OTRO PASO CON ESE ORDEN EN EL PROCEDIMIENTO.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET    @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRAN
    UPDATE [dbo].[Procedimiento_Paso]
    SET    ppa_orden = @O, ppa_nombre = @NOM, ppa_instruccion = @INS,
           ppa_es_punto_control = @PC, ppa_requiere_evidencia = @EV,
           ppa_requiere_medicion = @MED, ppa_variable_medicion = @VAR,
           ppa_duracion_estimada_minuto = @DUR, ppa_habilitado = @HAB,
           ppa_usuario_actualizacion = @USUARIO, ppa_fecha_actualizacion = @AHORA
    WHERE  ppa_id = @ID
COMMIT

SELECT 200 AS ID, 200 AS CODE, 'Paso actualizado con exito.' AS MENSAJE
GO
PRINT '--- UPD_PROCEDIMIENTO_PASO creado.'
GO


/* ========================================================================
   4. DEL_PROCEDIMIENTO_PASO  (baja logica)                         T-3287
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_PROCEDIMIENTO_PASO]
    @ID       INT,
    @CLIENTE  INT,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PRC_CLIENTE INT, @PAIS INT, @AHORA DATETIME
SELECT @PRC_CLIENTE = p.prc_cliente
FROM   [dbo].[Procedimiento_Paso] s
JOIN   [dbo].[Procedimiento] p ON p.prc_id = s.ppa_procedimiento
WHERE  s.ppa_id = @ID

IF @@ROWCOUNT = 0
BEGIN RAISERROR('1.- EL PASO NO EXISTE.', 16, 1) RETURN -1 END
IF @PRC_CLIENTE IS NULL
BEGIN RAISERROR('2.- ES UN PASO DE UN PROCEDIMIENTO GLOBAL: NO SE DA DE BAJA DESDE EL CLIENTE.', 16, 1) RETURN -1 END
IF @PRC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('3.- EL PASO PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

-- No dejar huerfanos: si el paso ya se ejecuto en una orden, no se borra.
IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso] WHERE otp_procedimiento_paso = @ID)
BEGIN RAISERROR('4.- EL PASO YA SE USO EN UNA ORDEN DE TRABAJO Y NO SE PUEDE DAR DE BAJA.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET    @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRAN
    UPDATE [dbo].[Procedimiento_Paso]
    SET    ppa_habilitado = 0, ppa_usuario_actualizacion = @USUARIO, ppa_fecha_actualizacion = @AHORA
    WHERE  ppa_id = @ID
COMMIT

SELECT 200 AS ID, 200 AS CODE, 'Paso dado de baja con exito.' AS MENSAJE
GO
PRINT '--- DEL_PROCEDIMIENTO_PASO creado.'
GO

PRINT '156_SPRINT3_PROCEDIMIENTO_PASO_SP aplicado.'
GO
