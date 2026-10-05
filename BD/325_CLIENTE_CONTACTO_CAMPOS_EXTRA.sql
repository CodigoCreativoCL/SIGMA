USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           04-10-2026
-- DESCRIPTION:     Extiende los contactos del cliente (Cliente_Contacto) con los
--                  campos del formulario ampliado: empresa, rubro, direccion y
--                  notas, mas un numero correlativo por cliente (desde 001) que
--                  se asigna al crear. La "funcion" reutiliza ccn_cargo.
--                  Actualiza SEL/INS/UPD_CLIENTE_CONTACTO. Es idempotente.
-- =============================================
GO

-- ---------------------------------------------------------------------------
-- 1) Columnas nuevas (solo si no existen)
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.Cliente_Contacto', 'ccn_numero')    IS NULL ALTER TABLE [dbo].[Cliente_Contacto] ADD ccn_numero    INT            NULL
GO
IF COL_LENGTH('dbo.Cliente_Contacto', 'ccn_empresa')   IS NULL ALTER TABLE [dbo].[Cliente_Contacto] ADD ccn_empresa   NVARCHAR(200)  NULL
GO
IF COL_LENGTH('dbo.Cliente_Contacto', 'ccn_rubro')     IS NULL ALTER TABLE [dbo].[Cliente_Contacto] ADD ccn_rubro     NVARCHAR(150)  NULL
GO
IF COL_LENGTH('dbo.Cliente_Contacto', 'ccn_direccion') IS NULL ALTER TABLE [dbo].[Cliente_Contacto] ADD ccn_direccion NVARCHAR(300)  NULL
GO
IF COL_LENGTH('dbo.Cliente_Contacto', 'ccn_notas')     IS NULL ALTER TABLE [dbo].[Cliente_Contacto] ADD ccn_notas     NVARCHAR(1000) NULL
GO

-- ---------------------------------------------------------------------------
-- 2) Backfill del correlativo para los contactos ya existentes (por cliente)
-- ---------------------------------------------------------------------------
;WITH q AS (
    SELECT ccn_id,
           ROW_NUMBER() OVER (PARTITION BY ccn_cliente ORDER BY ccn_fecha_creacion, ccn_id) AS rn
    FROM [dbo].[Cliente_Contacto]
)
UPDATE c SET c.ccn_numero = q.rn
FROM [dbo].[Cliente_Contacto] c
JOIN q ON q.ccn_id = c.ccn_id
WHERE c.ccn_numero IS NULL
GO


-- ---------------------------------------------------------------------------
-- 3) SEL: devuelve tambien los campos nuevos y el numero
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_CONTACTO]
    @CLIENTE        INT,
    @ID             INT = NULL,
    @HABILITADO     BIT = 1
AS
SET NOCOUNT ON

    SELECT  c.ccn_id,
            c.ccn_cliente,
            c.ccn_numero,
            c.ccn_nombre,
            ISNULL(c.ccn_cargo, '')     AS ccn_cargo,
            ISNULL(c.ccn_empresa, '')   AS ccn_empresa,
            ISNULL(c.ccn_rubro, '')     AS ccn_rubro,
            ISNULL(c.ccn_email, '')     AS ccn_email,
            ISNULL(c.ccn_telefono, '')  AS ccn_telefono,
            ISNULL(c.ccn_direccion, '') AS ccn_direccion,
            ISNULL(c.ccn_notas, '')     AS ccn_notas,
            c.ccn_principal,
            c.ccn_habilitado,
            c.ccn_usuario_creacion,
            c.ccn_fecha_creacion,
            c.ccn_usuario_actualizacion,
            c.ccn_fecha_actualizacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Cliente_Contacto] c
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = c.ccn_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = c.ccn_usuario_actualizacion
    WHERE   c.ccn_cliente = @CLIENTE
      AND   (@ID IS NULL OR c.ccn_id = @ID)
      AND   (@HABILITADO IS NULL OR c.ccn_habilitado = @HABILITADO)
    /* El principal primero: es el que se busca en el 90% de los casos. */
    ORDER BY c.ccn_principal DESC, c.ccn_numero
GO


-- ---------------------------------------------------------------------------
-- 4) INS: agrega empresa/rubro/direccion/notas y asigna el correlativo
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_CONTACTO]
    @ID             INT OUTPUT,
    @CLIENTE        INT,
    @NOMBRE         NVARCHAR(200),
    @CARGO          NVARCHAR(200)  = NULL,
    @EMPRESA        NVARCHAR(200)  = NULL,
    @RUBRO          NVARCHAR(150)  = NULL,
    @EMAIL          NVARCHAR(200)  = NULL,
    @TELEFONO       NVARCHAR(50)   = NULL,
    @DIRECCION      NVARCHAR(300)  = NULL,
    @NOTAS          NVARCHAR(1000) = NULL,
    @PRINCIPAL      BIT = 0,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @NUMERO INT

SET @NOMBRE    = LTRIM(RTRIM(@NOMBRE))
SET @EMAIL     = NULLIF(LTRIM(RTRIM(ISNULL(@EMAIL, ''))), '')
SET @TELEFONO  = NULLIF(LTRIM(RTRIM(ISNULL(@TELEFONO, ''))), '')
SET @CARGO     = NULLIF(LTRIM(RTRIM(ISNULL(@CARGO, ''))), '')
SET @EMPRESA   = NULLIF(LTRIM(RTRIM(ISNULL(@EMPRESA, ''))), '')
SET @RUBRO     = NULLIF(LTRIM(RTRIM(ISNULL(@RUBRO, ''))), '')
SET @DIRECCION = NULLIF(LTRIM(RTRIM(ISNULL(@DIRECCION, ''))), '')
SET @NOTAS     = NULLIF(LTRIM(RTRIM(ISNULL(@NOTAS, ''))), '')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
BEGIN RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1) RETURN -1 END

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN RAISERROR('2.- INDIQUE EL NOMBRE DEL CONTACTO.', 16, 1) RETURN -1 END

/* Un nombre suelto no alcanza para contactar a nadie. */
IF (@EMAIL IS NULL AND @TELEFONO IS NULL)
BEGIN RAISERROR('3.- INDIQUE AL MENOS UN CORREO O UN TELEFONO.', 16, 1) RETURN -1 END

IF (@EMAIL IS NOT NULL AND (@EMAIL NOT LIKE '%_@_%._%' OR @EMAIL LIKE '% %'))
BEGIN RAISERROR('4.- EL CORREO NO TIENE UN FORMATO VALIDO.', 16, 1) RETURN -1 END

IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
            WHERE ccn_cliente = @CLIENTE AND ccn_habilitado = 1
              AND LTRIM(RTRIM(ccn_nombre)) = @NOMBRE)
BEGIN RAISERROR('5.- ESE CONTACTO YA ESTA REGISTRADO PARA EL CLIENTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    IF (@PRINCIPAL = 1)
        UPDATE [dbo].[Cliente_Contacto]
           SET ccn_principal = 0, ccn_usuario_actualizacion = @USUARIO, ccn_fecha_actualizacion = @AHORA
         WHERE ccn_cliente = @CLIENTE AND ccn_principal = 1

    IF (@PRINCIPAL = 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                                        WHERE ccn_cliente = @CLIENTE AND ccn_habilitado = 1))
        SET @PRINCIPAL = 1

    /* Correlativo por cliente, desde 1 (la pantalla lo muestra como 001). */
    SELECT @NUMERO = ISNULL(MAX(ccn_numero), 0) + 1
    FROM [dbo].[Cliente_Contacto] WHERE ccn_cliente = @CLIENTE

    INSERT INTO [dbo].[Cliente_Contacto]
        (ccn_cliente, ccn_numero, ccn_nombre, ccn_cargo, ccn_empresa, ccn_rubro,
         ccn_email, ccn_telefono, ccn_direccion, ccn_notas,
         ccn_principal, ccn_habilitado, ccn_usuario_creacion, ccn_fecha_creacion)
    VALUES
        (@CLIENTE, @NUMERO, @NOMBRE, @CARGO, @EMPRESA, @RUBRO,
         @EMAIL, @TELEFONO, @DIRECCION, @NOTAS,
         @PRINCIPAL, 1, @USUARIO, @AHORA)

    DECLARE @FILAS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN ROLLBACK TRANSACTION RAISERROR('6.- NO FUE POSIBLE CREAR EL CONTACTO.', 16, 1) RETURN -1 END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Contacto creado con exito.' AS MENSAJE
GO


-- ---------------------------------------------------------------------------
-- 5) UPD: actualiza tambien empresa/rubro/direccion/notas (el numero no cambia)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_CONTACTO]
    @ID             INT,
    @CLIENTE        INT,
    @NOMBRE         NVARCHAR(200)  = NULL,
    @CARGO          NVARCHAR(200)  = NULL,
    @EMPRESA        NVARCHAR(200)  = NULL,
    @RUBRO          NVARCHAR(150)  = NULL,
    @EMAIL          NVARCHAR(200)  = NULL,
    @TELEFONO       NVARCHAR(50)   = NULL,
    @DIRECCION      NVARCHAR(300)  = NULL,
    @NOTAS          NVARCHAR(1000) = NULL,
    @PRINCIPAL      BIT = NULL,
    @HABILITADO     BIT = NULL,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @EMAIL_FINAL NVARCHAR(200), @TEL_FINAL NVARCHAR(50)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                WHERE ccn_id = @ID AND ccn_cliente = @CLIENTE)
BEGIN RAISERROR('1.- EL CONTACTO NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END

SET @NOMBRE   = NULLIF(LTRIM(RTRIM(ISNULL(@NOMBRE, ''))), '')
SET @CARGO    = LTRIM(RTRIM(ISNULL(@CARGO, '')))
SET @EMAIL    = LTRIM(RTRIM(ISNULL(@EMAIL, '')))
SET @TELEFONO = LTRIM(RTRIM(ISNULL(@TELEFONO, '')))

SELECT  @EMAIL_FINAL = CASE WHEN @EMAIL = '' THEN NULL ELSE @EMAIL END,
        @TEL_FINAL   = CASE WHEN @TELEFONO = '' THEN NULL ELSE @TELEFONO END

IF (@EMAIL_FINAL IS NULL AND @TEL_FINAL IS NULL)
BEGIN RAISERROR('2.- INDIQUE AL MENOS UN CORREO O UN TELEFONO.', 16, 1) RETURN -1 END

IF (@EMAIL_FINAL IS NOT NULL AND (@EMAIL_FINAL NOT LIKE '%_@_%._%' OR @EMAIL_FINAL LIKE '% %'))
BEGIN RAISERROR('3.- EL CORREO NO TIENE UN FORMATO VALIDO.', 16, 1) RETURN -1 END

IF (@NOMBRE IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                                     WHERE ccn_cliente = @CLIENTE AND ccn_habilitado = 1
                                       AND ccn_id <> @ID AND LTRIM(RTRIM(ccn_nombre)) = @NOMBRE))
BEGIN RAISERROR('4.- ESE CONTACTO YA ESTA REGISTRADO PARA EL CLIENTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    IF (@PRINCIPAL = 1)
        UPDATE [dbo].[Cliente_Contacto]
           SET ccn_principal = 0, ccn_usuario_actualizacion = @USUARIO, ccn_fecha_actualizacion = @AHORA
         WHERE ccn_cliente = @CLIENTE AND ccn_principal = 1 AND ccn_id <> @ID

    UPDATE  [dbo].[Cliente_Contacto]
    SET     ccn_nombre     = ISNULL(@NOMBRE, ccn_nombre),
            ccn_cargo      = CASE WHEN @CARGO = '' THEN NULL ELSE @CARGO END,
            ccn_empresa    = CASE WHEN LTRIM(RTRIM(ISNULL(@EMPRESA, ''))) = '' THEN NULL ELSE LTRIM(RTRIM(@EMPRESA)) END,
            ccn_rubro      = CASE WHEN LTRIM(RTRIM(ISNULL(@RUBRO, ''))) = '' THEN NULL ELSE LTRIM(RTRIM(@RUBRO)) END,
            ccn_email      = @EMAIL_FINAL,
            ccn_telefono   = @TEL_FINAL,
            ccn_direccion  = CASE WHEN LTRIM(RTRIM(ISNULL(@DIRECCION, ''))) = '' THEN NULL ELSE LTRIM(RTRIM(@DIRECCION)) END,
            ccn_notas      = CASE WHEN LTRIM(RTRIM(ISNULL(@NOTAS, ''))) = '' THEN NULL ELSE LTRIM(RTRIM(@NOTAS)) END,
            ccn_principal  = ISNULL(@PRINCIPAL, ccn_principal),
            ccn_habilitado = ISNULL(@HABILITADO, ccn_habilitado),
            ccn_usuario_actualizacion = @USUARIO,
            ccn_fecha_actualizacion = @AHORA
    WHERE   ccn_id = @ID AND ccn_cliente = @CLIENTE

    DECLARE @FILAS INT = @@ROWCOUNT

    IF @FILAS = 0
    BEGIN ROLLBACK TRANSACTION RAISERROR('5.- NO FUE POSIBLE ACTUALIZAR EL CONTACTO.', 16, 1) RETURN -1 END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Contacto actualizado con exito.' AS MENSAJE
GO

PRINT '325_CLIENTE_CONTACTO_CAMPOS_EXTRA aplicado.'
GO
