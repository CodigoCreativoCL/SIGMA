/* ============================================================================
   SIGMA — Bloque 124
   LOS CONTACTOS DEL CLIENTE
   ----------------------------------------------------------------------------

   QUE FALTABA

     `Cliente` guarda razon social, RUT, pais y configuracion regional, pero no
     a QUIEN llamar. La ficha decia "sin contacto configurado" porque
     literalmente no habia donde escribirlo.

   POR QUE UNA TABLA Y NO TRES COLUMNAS EN Cliente

     Una empresa no tiene "un" contacto: tiene el de operaciones —a quien se
     avisa que la cuadrilla llega manana—, el comercial y el de facturacion.
     Meter `cli_email` y `cli_telefono` en la cabecera obliga a elegir cual de
     los tres cabe, y el dia que hagan falta dos ya no se puede sin migrar.

   UNO PRINCIPAL, Y SOLO UNO

     Es el que la ficha muestra arriba y el que usa cualquier aviso automatico
     que se escriba despues. Dos principales dejan esa decision al azar del
     ORDER BY, asi que lo impide un indice unico filtrado; poner uno nuevo
     baja al anterior, dentro de la misma transaccion.

   EL CORREO SE VALIDA, EL TELEFONO NO

     Un correo mal escrito hace fallar un envio en silencio meses despues, y
     la forma es comprobable. Un telefono varia demasiado entre paises —+56 9,
     anexos, dos numeros en el mismo campo— y una validacion estricta terminaria
     rechazando numeros validos.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. LA TABLA
   ======================================================================== */
IF OBJECT_ID('dbo.Cliente_Contacto') IS NULL
BEGIN
    CREATE TABLE [dbo].[Cliente_Contacto] (
        ccn_id                  INT IDENTITY(1,1)   NOT NULL,
        ccn_cliente             INT                 NOT NULL,

        ccn_nombre              NVARCHAR(200)       NOT NULL,
        ccn_cargo               NVARCHAR(200)       NULL,
        ccn_email               NVARCHAR(200)       NULL,
        ccn_telefono            NVARCHAR(50)        NULL,

        /* El que la ficha muestra arriba y el que usaria cualquier aviso
           automatico. */
        ccn_principal           BIT                 NOT NULL
            CONSTRAINT DF_CCN_PRINCIPAL DEFAULT (0),

        ccn_habilitado          BIT                 NOT NULL
            CONSTRAINT DF_CCN_HABILITADO DEFAULT (1),

        ccn_usuario_creacion    INT                 NOT NULL,
        ccn_fecha_creacion      DATETIME            NOT NULL
            CONSTRAINT DF_CCN_FECHA_CREACION DEFAULT (GETDATE()),
        ccn_usuario_actualizacion INT               NULL,
        ccn_fecha_actualizacion DATETIME            NULL,

        CONSTRAINT PK_CLIENTE_CONTACTO PRIMARY KEY (ccn_id),

        CONSTRAINT FK_CCN_CLIENTE FOREIGN KEY (ccn_cliente)
            REFERENCES [dbo].[Cliente] (cli_id),

        /* Un nombre en blanco deja una fila que no sirve para nada y que
           igual aparece en la lista. */
        CONSTRAINT CK_CCN_NOMBRE CHECK (LEN(LTRIM(RTRIM(ccn_nombre))) > 0),

        /* Un contacto sin correo NI telefono no es un contacto: es un
           nombre. Al menos una de las dos formas de alcanzarlo. */
        CONSTRAINT CK_CCN_CONTACTABLE CHECK
            (ccn_email IS NOT NULL OR ccn_telefono IS NOT NULL)
    )

    PRINT '--- Cliente_Contacto creada.'
END
ELSE
    PRINT '--- Cliente_Contacto ya existia.'
GO

/* Un solo principal por cliente. Filtrado: los NO principales pueden ser
   muchos, y los deshabilitados no compiten por el puesto. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CCN_PRINCIPAL')
BEGIN
    CREATE UNIQUE INDEX UX_CCN_PRINCIPAL
        ON [dbo].[Cliente_Contacto] (ccn_cliente)
        WHERE ccn_principal = 1 AND ccn_habilitado = 1

    PRINT '--- UX_CCN_PRINCIPAL creado.'
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CCN_CLIENTE')
BEGIN
    CREATE INDEX IX_CCN_CLIENTE
        ON [dbo].[Cliente_Contacto] (ccn_cliente, ccn_habilitado)
        INCLUDE (ccn_nombre, ccn_principal)

    PRINT '--- IX_CCN_CLIENTE creado.'
END
GO


/* ========================================================================
   2. SEL
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_CLIENTE_CONTACTO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_CLIENTE_CONTACTO]
GO

CREATE PROCEDURE [dbo].[SEL_CLIENTE_CONTACTO]
    @CLIENTE        INT,
    @ID             INT = NULL,
    @HABILITADO     BIT = 1
AS
SET NOCOUNT ON

    SELECT  c.ccn_id,
            c.ccn_cliente,
            c.ccn_nombre,
            ISNULL(c.ccn_cargo, '')     AS ccn_cargo,
            ISNULL(c.ccn_email, '')     AS ccn_email,
            ISNULL(c.ccn_telefono, '')  AS ccn_telefono,
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
    ORDER BY c.ccn_principal DESC, c.ccn_nombre
GO

PRINT '--- SEL_CLIENTE_CONTACTO creado.'
GO


/* ========================================================================
   3. INS
   ======================================================================== */
IF OBJECT_ID('dbo.INS_CLIENTE_CONTACTO') IS NOT NULL
    DROP PROCEDURE [dbo].[INS_CLIENTE_CONTACTO]
GO

CREATE PROCEDURE [dbo].[INS_CLIENTE_CONTACTO]
    @ID             INT OUTPUT,
    @CLIENTE        INT,
    @NOMBRE         NVARCHAR(200),
    @CARGO          NVARCHAR(200) = NULL,
    @EMAIL          NVARCHAR(200) = NULL,
    @TELEFONO       NVARCHAR(50)  = NULL,
    @PRINCIPAL      BIT = 0,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME

SET @NOMBRE   = LTRIM(RTRIM(@NOMBRE))
SET @EMAIL    = NULLIF(LTRIM(RTRIM(ISNULL(@EMAIL, ''))), '')
SET @TELEFONO = NULLIF(LTRIM(RTRIM(ISNULL(@TELEFONO, ''))), '')
SET @CARGO    = NULLIF(LTRIM(RTRIM(ISNULL(@CARGO, ''))), '')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
BEGIN
    RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN
    RAISERROR('2.- INDIQUE EL NOMBRE DEL CONTACTO.', 16, 1)
    RETURN -1
END

/* Un nombre suelto no alcanza para contactar a nadie. */
IF (@EMAIL IS NULL AND @TELEFONO IS NULL)
BEGIN
    RAISERROR('3.- INDIQUE AL MENOS UN CORREO O UN TELEFONO.', 16, 1)
    RETURN -1
END

/* La forma del correo se comprueba; la del telefono no, porque varia
   demasiado entre paises y una regla estricta rechazaria numeros validos. */
IF (@EMAIL IS NOT NULL AND (@EMAIL NOT LIKE '%_@_%._%' OR @EMAIL LIKE '% %'))
BEGIN
    RAISERROR('4.- EL CORREO NO TIENE UN FORMATO VALIDO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
            WHERE ccn_cliente = @CLIENTE
              AND ccn_habilitado = 1
              AND LTRIM(RTRIM(ccn_nombre)) = @NOMBRE)
BEGIN
    RAISERROR('5.- ESE CONTACTO YA ESTA REGISTRADO PARA EL CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    /* El principal nuevo baja al anterior. Va DENTRO de la transaccion: si el
       alta falla despues, el cliente no puede quedarse sin ninguno. */
    IF (@PRINCIPAL = 1)
        UPDATE [dbo].[Cliente_Contacto]
           SET ccn_principal = 0,
               ccn_usuario_actualizacion = @USUARIO,
               ccn_fecha_actualizacion = @AHORA
         WHERE ccn_cliente = @CLIENTE AND ccn_principal = 1

    /* El primero es principal aunque nadie lo pida: un cliente con un solo
       contacto y ninguno marcado deja la ficha diciendo "sin contacto
       principal" con el contacto ahi mismo. */
    IF (@PRINCIPAL = 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                                        WHERE ccn_cliente = @CLIENTE AND ccn_habilitado = 1))
        SET @PRINCIPAL = 1

    INSERT INTO [dbo].[Cliente_Contacto]
        (ccn_cliente, ccn_nombre, ccn_cargo, ccn_email, ccn_telefono,
         ccn_principal, ccn_habilitado, ccn_usuario_creacion, ccn_fecha_creacion)
    VALUES
        (@CLIENTE, @NOMBRE, @CARGO, @EMAIL, @TELEFONO,
         @PRINCIPAL, 1, @USUARIO, @AHORA)

    DECLARE @FILAS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('6.- NO FUE POSIBLE CREAR EL CONTACTO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Contacto creado con éxito.' AS MENSAJE
GO

PRINT '--- INS_CLIENTE_CONTACTO creado.'
GO


/* ========================================================================
   4. UPD
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_CLIENTE_CONTACTO') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_CLIENTE_CONTACTO]
GO

CREATE PROCEDURE [dbo].[UPD_CLIENTE_CONTACTO]
    @ID             INT,
    @CLIENTE        INT,
    @NOMBRE         NVARCHAR(200) = NULL,
    @CARGO          NVARCHAR(200) = NULL,
    @EMAIL          NVARCHAR(200) = NULL,
    @TELEFONO       NVARCHAR(50)  = NULL,
    @PRINCIPAL      BIT = NULL,
    @HABILITADO     BIT = NULL,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @EMAIL_FINAL NVARCHAR(200), @TEL_FINAL NVARCHAR(50)

/* El cliente se comprueba en el WHERE y no solo por el id: una fila sola no
   sabe de quien es, y sin esto cualquiera con el id editaria el contacto de
   otra empresa. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                WHERE ccn_id = @ID AND ccn_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL CONTACTO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SET @NOMBRE   = NULLIF(LTRIM(RTRIM(ISNULL(@NOMBRE, ''))), '')
SET @CARGO    = LTRIM(RTRIM(ISNULL(@CARGO, '')))
SET @EMAIL    = LTRIM(RTRIM(ISNULL(@EMAIL, '')))
SET @TELEFONO = LTRIM(RTRIM(ISNULL(@TELEFONO, '')))

/* Como quedaria despues de guardar: la comprobacion de "contactable" se hace
   sobre el resultado, no sobre lo que vino. */
SELECT  @EMAIL_FINAL = CASE WHEN @EMAIL = '' THEN NULL ELSE @EMAIL END,
        @TEL_FINAL   = CASE WHEN @TELEFONO = '' THEN NULL ELSE @TELEFONO END

IF (@EMAIL_FINAL IS NULL AND @TEL_FINAL IS NULL)
BEGIN
    RAISERROR('2.- INDIQUE AL MENOS UN CORREO O UN TELEFONO.', 16, 1)
    RETURN -1
END

IF (@EMAIL_FINAL IS NOT NULL AND (@EMAIL_FINAL NOT LIKE '%_@_%._%' OR @EMAIL_FINAL LIKE '% %'))
BEGIN
    RAISERROR('3.- EL CORREO NO TIENE UN FORMATO VALIDO.', 16, 1)
    RETURN -1
END

IF (@NOMBRE IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Contacto]
                                     WHERE ccn_cliente = @CLIENTE
                                       AND ccn_habilitado = 1
                                       AND ccn_id <> @ID
                                       AND LTRIM(RTRIM(ccn_nombre)) = @NOMBRE))
BEGIN
    RAISERROR('4.- ESE CONTACTO YA ESTA REGISTRADO PARA EL CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    IF (@PRINCIPAL = 1)
        UPDATE [dbo].[Cliente_Contacto]
           SET ccn_principal = 0,
               ccn_usuario_actualizacion = @USUARIO,
               ccn_fecha_actualizacion = @AHORA
         WHERE ccn_cliente = @CLIENTE AND ccn_principal = 1 AND ccn_id <> @ID

    UPDATE  [dbo].[Cliente_Contacto]
    SET     ccn_nombre     = ISNULL(@NOMBRE, ccn_nombre),
            ccn_cargo      = CASE WHEN @CARGO = '' THEN NULL ELSE @CARGO END,
            ccn_email      = @EMAIL_FINAL,
            ccn_telefono   = @TEL_FINAL,
            ccn_principal  = ISNULL(@PRINCIPAL, ccn_principal),
            ccn_habilitado = ISNULL(@HABILITADO, ccn_habilitado),
            ccn_usuario_actualizacion = @USUARIO,
            ccn_fecha_actualizacion = @AHORA
    WHERE   ccn_id = @ID AND ccn_cliente = @CLIENTE

    DECLARE @FILAS INT = @@ROWCOUNT

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('5.- NO FUE POSIBLE ACTUALIZAR EL CONTACTO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Contacto actualizado con éxito.' AS MENSAJE
GO

PRINT '--- UPD_CLIENTE_CONTACTO creado.'
GO


/* ========================================================================
   5. DEL — baja logica
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_CLIENTE_CONTACTO') IS NOT NULL
    DROP PROCEDURE [dbo].[DEL_CLIENTE_CONTACTO]
GO

CREATE PROCEDURE [dbo].[DEL_CLIENTE_CONTACTO]
    @ID             INT,
    @CLIENTE        INT,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @ERA_PRINCIPAL BIT

SELECT  @ERA_PRINCIPAL = ccn_principal
FROM    [dbo].[Cliente_Contacto]
WHERE   ccn_id = @ID AND ccn_cliente = @CLIENTE

IF (@ERA_PRINCIPAL IS NULL)
BEGIN
    RAISERROR('1.- EL CONTACTO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    /* Baja logica: el contacto pudo haber quedado escrito en una orden o en
       un aviso, y borrarlo dejaria esa referencia sin nombre. */
    UPDATE  [dbo].[Cliente_Contacto]
    SET     ccn_habilitado = 0,
            ccn_principal = 0,
            ccn_usuario_actualizacion = @USUARIO,
            ccn_fecha_actualizacion = @AHORA
    WHERE   ccn_id = @ID AND ccn_cliente = @CLIENTE

    /* Si el que se fue era el principal, el mas antiguo de los que quedan
       toma el puesto. Dejar al cliente sin principal obliga a acordarse de
       nombrar uno, y nadie se acuerda. */
    IF (@ERA_PRINCIPAL = 1)
        UPDATE [dbo].[Cliente_Contacto]
           SET ccn_principal = 1,
               ccn_usuario_actualizacion = @USUARIO,
               ccn_fecha_actualizacion = @AHORA
         WHERE ccn_id = (SELECT TOP 1 ccn_id FROM [dbo].[Cliente_Contacto]
                          WHERE ccn_cliente = @CLIENTE AND ccn_habilitado = 1
                          ORDER BY ccn_id)

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Contacto eliminado con éxito.' AS MENSAJE
GO

PRINT '--- DEL_CLIENTE_CONTACTO creado.'
GO

PRINT '124_CLIENTE_CONTACTO aplicado.'
GO
