USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-02. CLIENTES Y PLANTAS. HU-010 Y HU-011.
-- =============================================
-- Va DESPUES de 28_SPRINT1_EQUIPOS.
--
-- QUE CUBRE
--   HU-010  Alta y mantencion de clientes: RUT valido y unico, zona
--           horaria, idioma, moneda, nombre de fantasia y baja logica.
--   HU-011  Plantas del cliente: codigo unico, zona horaria propia y
--           coordenadas.
--
-- POR QUE SE REESCRIBEN SPs QUE YA EXISTIAN
--   El bloque 25 les agrego columnas a Cliente y Cliente_Instalacion.
--   PATRON_TABLAS §7 es explicito: despues de un ALTER hay que actualizar
--   en el mismo cambio el SEL_, el INS_ y el UPD_. Si no, las columnas
--   nuevas quedan invisibles para la aplicacion.
--
--   Se conserva el comportamiento existente tal cual, incluida la
--   asociacion automatica del usuario creador al cliente nuevo. Solo se
--   agrega lo que falta y se corrigen dos defectos que se detallan abajo.
--
-- DOS DEFECTOS CORREGIDOS EN INS_CLIENTE
--
--   a) Al copiar los perfiles del usuario creador hacia el cliente nuevo,
--      insertaba UPE_ID (el id de la FILA de Usuario_Perfil) en la columna
--      CUP_ID_PERFIL, que espera un id de PERFIL. Hoy no se nota porque en
--      el usuario Root ambos valen 1, pero para el usuario 2 el id de fila
--      es 2 y su perfil es 1: le habria asignado el perfil equivocado.
--
--   b) Si el usuario creador no tenia ninguna fila en Usuario_Perfil, ese
--      INSERT afectaba cero filas, hacia ROLLBACK y el cliente NO se creaba,
--      con un mensaje que hablaba de "no fue posible insertar el cliente".
--      Crear clientes es justamente lo que hace un administrador de
--      plataforma, que puede no tener perfiles de cliente. Ahora la copia
--      de perfiles es opcional.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. FNC_RUT_VALIDO

      Digito verificador chileno, modulo 11.

      SIGMA es multi-pais: hay clientes en Peru, Argentina, Ecuador y
      Panama, donde el identificador tributario tiene otro formato. Esta
      funcion resuelve SOLO la aritmetica del RUT chileno; QUIEN decide si
      corresponde aplicarla es el SP, mirando el pais del cliente. Aplicarla
      a ciegas rechazaria identificadores extranjeros perfectamente validos.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_RUT_VALIDO]
(
    @RUT VARCHAR(100)
)
RETURNS BIT
AS
BEGIN
    IF @RUT IS NULL RETURN 0

    DECLARE @LIMPIO   VARCHAR(100)
    DECLARE @CUERPO   VARCHAR(100)
    DECLARE @DV       CHAR(1)
    DECLARE @I        INT
    DECLARE @MULT     INT = 2
    DECLARE @SUMA     INT = 0
    DECLARE @RESTO    INT
    DECLARE @DV_CALC  CHAR(1)
    DECLARE @CAR      CHAR(1)

    -- Se quitan puntos, guiones y espacios
    SET @LIMPIO = UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@RUT)), '.', ''), '-', ''), ' ', ''))

    IF LEN(@LIMPIO) < 2 RETURN 0

    SET @DV     = RIGHT(@LIMPIO, 1)
    SET @CUERPO = LEFT(@LIMPIO, LEN(@LIMPIO) - 1)

    -- El cuerpo tiene que ser todo digitos
    IF @CUERPO LIKE '%[^0-9]%' RETURN 0
    IF LEN(@CUERPO) < 7 OR LEN(@CUERPO) > 8 RETURN 0

    -- El DV es un digito o la letra K
    IF @DV NOT LIKE '[0-9K]' RETURN 0

    -- Suma ponderada de derecha a izquierda con la serie 2,3,4,5,6,7
    SET @I = LEN(@CUERPO)
    WHILE @I >= 1
    BEGIN
        SET @CAR  = SUBSTRING(@CUERPO, @I, 1)
        SET @SUMA = @SUMA + (CAST(@CAR AS INT) * @MULT)
        SET @MULT = CASE WHEN @MULT = 7 THEN 2 ELSE @MULT + 1 END
        SET @I    = @I - 1
    END

    SET @RESTO   = 11 - (@SUMA % 11)
    SET @DV_CALC = CASE WHEN @RESTO = 11 THEN '0'
                        WHEN @RESTO = 10 THEN 'K'
                        ELSE CAST(@RESTO AS CHAR(1)) END

    IF @DV_CALC = @DV RETURN 1
    RETURN 0
END
GO


/* ========================================================================
   2. INS_CLIENTE                                                   HU-010
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE]
@ID                INT = NULL OUTPUT,
@NOMBRE            VARCHAR(200),
@PAIS              INT,
@LOGO              VARBINARY(MAX) = NULL,
@RAZON_SOCIAL      VARCHAR(200),
@IDENTIFICADOR     VARCHAR(100),
@NOMBRE_FANTASIA   NVARCHAR(200) = NULL,
@ZONA_HORARIA      INT = NULL,
@IDIOMA            INT = NULL,
@MONEDA            INT = NULL,
@HABILITADO        BIT,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @DATE_NOW DATETIME = [dbo].[FNC_PAIS_HORA](@PAIS)
DECLARE @PAIS_CHILE INT

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

BEGIN
    -- 1. Digito verificador, solo para clientes chilenos
    IF @PAIS = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('1.- EL RUT "%s" NO ES VÁLIDO.', 16, 1, @IDENTIFICADOR)
        RETURN -1
    END

    -- 2. RUT unico en la plataforma
    IF EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_identificador = @IDENTIFICADOR)
    BEGIN
        RAISERROR('2.- YA EXISTE UN CLIENTE CON EL RUT "%s".', 16, 1, @IDENTIFICADOR)
        RETURN -1
    END
END

BEGIN TRANSACTION

    --INSERTO EL CLIENTE
    BEGIN
        INSERT [dbo].[Cliente]
            (
                cli_nombre,
                cli_habilitado,
                cli_pais,
                cli_razon_social,
                cli_identificador,
                cli_nombre_fantasia,
                cli_zona_horaria,
                cli_idioma,
                cli_moneda,
                cli_usuario_creacion,
                cli_fecha_creacion,
                cli_usuario_actualizacion,
                cli_fecha_actualizacion,
                cli_logo
            )
        VALUES
            (
                @NOMBRE,
                @HABILITADO,
                @PAIS,
                @RAZON_SOCIAL,
                @IDENTIFICADOR,
                @NOMBRE_FANTASIA,
                @ZONA_HORARIA,
                @IDIOMA,
                @MONEDA,
                @USUARIO,
                @DATE_NOW,
                @USUARIO,
                @DATE_NOW,
                @LOGO
            )

        SET @ID = SCOPE_IDENTITY()

        IF @@ROWCOUNT = 0 BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'INS_CLIENTE ' + ISNULL(@NOMBRE, '')

            EXEC [dbo].[INS_EXCEPCION]
                @MSG = '3.- NO FUE POSIBLE INSERTAR EL CLIENTE.',
                @VARIABLES = @VARIABLES
            RETURN -1
        END
    END

    --ASOCIO AL USUARIO QUE LO CREA
    BEGIN
        DECLARE @ID_CLIENTE_USUARIO INT

        INSERT [dbo].[Cliente_Usuario]
            (
                ucl_id_usuario
                ,ucl_id_cliente
                ,ucl_usuario_creacion
                ,ucl_fecha_creacion
                ,ucl_usuario_act
                ,ucl_fecha_act
                ,ucl_habilitado
            )
        VALUES
            (
                @USUARIO
                ,@ID
                ,@USUARIO
                ,@DATE_NOW
                ,@USUARIO
                ,@DATE_NOW
                ,1
            )

        SET @ID_CLIENTE_USUARIO = SCOPE_IDENTITY()

        IF @@ROWCOUNT = 0 BEGIN
            ROLLBACK TRANSACTION
            SET @VARIABLES = 'INS_CLIENTE ' + ISNULL(@NOMBRE, '')

            EXEC [dbo].[INS_EXCEPCION]
                @MSG = '4.- NO FUE POSIBLE ASOCIAR EL USUARIO AL CLIENTE.',
                @VARIABLES = @VARIABLES
            RETURN -1
        END
    END

    /* COPIO LOS PERFILES DEL USUARIO CREADOR

       Se inserta UPE_PERFIL, no UPE_ID: la columna destino es un id de
       perfil. Antes copiaba el id de la fila de Usuario_Perfil.

       Y NO se comprueba @@ROWCOUNT: un administrador de plataforma puede no
       tener perfiles de cliente, y en ese caso el cliente igual debe
       quedar creado. Antes esto abortaba la operacion completa. */
    BEGIN
        INSERT [dbo].[Cliente_Usuario_Perfil]
            (
                cup_id_cliente_usuario
                ,cup_id_perfil
                ,cup_usuario_creacion
                ,cup_fecha_creacion
            )
        SELECT  @ID_CLIENTE_USUARIO,
                upe.upe_perfil,
                @USUARIO,
                @DATE_NOW
        FROM    [dbo].[Usuario_Perfil] upe
        WHERE   upe.upe_usuario = @USUARIO
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. UPD_CLIENTE                                                   HU-010

      La baja logica del escenario 2 se hace por aqui, con @HABILITADO = 0.
      Los usuarios de ese cliente dejan de poder entrar porque SEL_LOGIN
      exige una afiliacion vigente a un cliente habilitado (bloque 26).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE]
@ID                INT,
@NOMBRE            VARCHAR(200),
@PAIS              INT,
@RAZON_SOCIAL      VARCHAR(200),
@IDENTIFICADOR     VARCHAR(100),
@LOGO              VARBINARY(MAX) = NULL,
@NOMBRE_FANTASIA   NVARCHAR(200) = NULL,
@ZONA_HORARIA      INT = NULL,
@IDIOMA            INT = NULL,
@MONEDA            INT = NULL,
@HABILITADO        BIT,
@USUARIO           INT,
@CAMBIA_LOGO       BIT = 1

AS
SET NOCOUNT ON

DECLARE @DATE_NOW DATETIME = [dbo].[FNC_PAIS_HORA](@PAIS)
DECLARE @PAIS_CHILE INT

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

BEGIN
    IF @PAIS = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('1.- EL RUT "%s" NO ES VÁLIDO.', 16, 1, @IDENTIFICADOR)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Cliente]
                WHERE cli_identificador = @IDENTIFICADOR AND cli_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE OTRO CLIENTE CON EL RUT "%s".', 16, 1, @IDENTIFICADOR)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Cliente]
    SET     cli_nombre                = @NOMBRE,
            cli_habilitado            = @HABILITADO,
            cli_pais                  = @PAIS,
            cli_razon_social          = @RAZON_SOCIAL,
            cli_identificador         = @IDENTIFICADOR,
            cli_nombre_fantasia       = @NOMBRE_FANTASIA,
            cli_zona_horaria          = @ZONA_HORARIA,
            cli_idioma                = @IDIOMA,
            cli_moneda                = @MONEDA,
            cli_usuario_actualizacion = @USUARIO,
            cli_fecha_actualizacion   = @DATE_NOW,
            /* El logo solo se toca cuando el formulario mando uno. Antes se
               asignaba siempre, asi que guardar el cliente sin volver a
               subir la imagen borraba el logo existente. */
            cli_logo                  = CASE WHEN @CAMBIA_LOGO = 1 THEN @LOGO ELSE cli_logo END
    WHERE   cli_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_CLIENTE ' + LTRIM(STR(@ID)) + ',' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL CLIENTE.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   4. SEL_CLIENTE                                                   HU-010

      Mismos parametros y mismos filtros que antes. Lo unico que cambia es
      que el SELECT ahora incluye las columnas nuevas y el nombre legible de
      zona horaria, idioma y moneda.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE]
@ID                 INT = NULL,
@FILTRO             VARCHAR(2000) = NULL,
@HABILITADO         BIT = NULL,
@USUARIO            INT = NULL,
@FILTRO_USUARIOS    VARCHAR(MAX) = NULL,
@FILTRO_INSTALACION VARCHAR(MAX) = NULL,
@PAISES             VARCHAR(MAX) = NULL,
@FILTRO_PAIS        VARCHAR(MAX) = NULL,
@TIPO_PERFIL        INT = NULL
AS
SET NOCOUNT ON

---SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)

    SET @SELECT = 'SELECT   DISTINCT CLI_ID,
                            CLI_NOMBRE,
                            CLI_HABILITADO,
                            CLI_PAIS,
                            CLI_RAZON_SOCIAL,
                            CLI_IDENTIFICADOR,
                            CLI_NOMBRE_FANTASIA,
                            CLI_ZONA_HORARIA,
                            CLI_IDIOMA,
                            CLI_MONEDA,
                            CLI_USUARIO_CREACION,
                            CLI_FECHA_CREACION,
                            CLI_USUARIO_ACTUALIZACION,
                            CLI_FECHA_ACTUALIZACION,
                            PAI_NOMBRE,
                            ZHO_NOMBRE,
                            IDI_NOMBRE,
                            MON_NOMBRE,
                            CLI_LOGO
                  '
END

---FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)

    SET @FROM = ' FROM  CLIENTE
                        INNER JOIN PAISES               ON CLI_PAIS = PAI_ID
                        LEFT JOIN ZONA_HORARIA          ON ZHO_ID = CLI_ZONA_HORARIA
                        LEFT JOIN IDIOMA                ON IDI_ID = CLI_IDIOMA
                        LEFT JOIN MONEDA                ON MON_ID = CLI_MONEDA
                        LEFT JOIN CLIENTE_USUARIO       ON UCL_ID_CLIENTE = CLI_ID
                        LEFT JOIN USUARIO               ON USU_ID = UCL_ID_USUARIO
                        LEFT JOIN CLIENTE_INSTALACION   ON CIN_CLIENTE = CLI_ID
                '
END

---WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1 = 1
                    '

    IF(@ID IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CLI_ID = ' + LTRIM(@ID)
    END

    IF(@FILTRO IS NOT NULL)BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE +  ' AND (CLI_NOMBRE LIKE ''%' + @FILTRO + '%''
                                   OR CLI_RAZON_SOCIAL LIKE ''%' + @FILTRO + '%''
                                   OR CLI_NOMBRE_FANTASIA LIKE ''%' + @FILTRO + '%''
                                   OR CLI_IDENTIFICADOR LIKE ''%' + @FILTRO + '%'')
                                '
    END

    IF(@HABILITADO IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CLI_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    IF(@USUARIO IS NOT NULL AND @TIPO_PERFIL <> 1)BEGIN
        SET @WHERE = @WHERE +  ' AND UCL_ID_USUARIO = ' + LTRIM(@USUARIO) + '
                                AND UCL_HABILITADO = 1
                                '
    END
    IF(@USUARIO IS NOT NULL AND @TIPO_PERFIL = 1)BEGIN
        SET @WHERE = @WHERE +  ' AND UCL_ID_USUARIO = ' + LTRIM(@USUARIO) + '
                                '
    END

    IF(@PAISES IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PAI_ID IN(' + @PAISES + ') '
    END

    IF(@FILTRO_USUARIOS IS NOT NULL)BEGIN
        SET @FILTRO_USUARIOS = REPLACE(@FILTRO_USUARIOS, '''', '''''')
        SET @WHERE = @WHERE +  'AND     (USU_NOMBRE LIKE ''%' + LTRIM(@FILTRO_USUARIOS) + '%''
                                OR      USU_APELLIDO_PATERNO LIKE ''%' + LTRIM(@FILTRO_USUARIOS) + '%''
                                OR      USU_APELLIDO_MATERNO LIKE ''%' + LTRIM(@FILTRO_USUARIOS) + '%''
                                OR      USU_LOGIN LIKE ''%' + LTRIM(@FILTRO_USUARIOS) + '%''
                                OR      USU_IDENTIFICADOR LIKE ''%' + LTRIM(@FILTRO_USUARIOS) + '%'')
                               '
    END

    IF(@FILTRO_INSTALACION IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CIN_ID IN(' + LTRIM(@FILTRO_INSTALACION)+ ')   '
    END

    IF(@FILTRO_PAIS IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PAI_ID = ' + LTRIM(@FILTRO_PAIS)
    END

END

--ORDER BY
BEGIN
    DECLARE @ORDER_BY VARCHAR(MAX)
    SET @ORDER_BY = '  ORDER BY CLI_HABILITADO DESC, CLI_ID DESC'
END

--PRINT(@SELECT + @FROM + @WHERE + @ORDER_BY)
EXEC(@SELECT + @FROM + @WHERE + @ORDER_BY)
GO


/* ========================================================================
   5. INS_CLIENTE_INSTALACION                                       HU-011
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_INSTALACION]
@ID            INT = NULL OUTPUT,
@CLIENTE       INT = NULL,
@NOMBRE        VARCHAR(200),
@DESCRIPCION   VARCHAR(200) = NULL,
@DIRECCION     VARCHAR(200) = NULL,
@CODIGO        NVARCHAR(100) = NULL,
@ZONA_HORARIA  INT = NULL,
@LATITUD       DECIMAL(9,6) = NULL,
@LONGITUD      DECIMAL(9,6) = NULL,
@HABILITADO    BIT,
@USUARIO       INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    -- Codigo unico dentro del cliente
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_cliente = @CLIENTE AND cin_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA PLANTA CON EL CÓDIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @LATITUD IS NOT NULL AND (@LATITUD < -90 OR @LATITUD > 90)
    BEGIN
        RAISERROR('2.- LA LATITUD DEBE ESTAR ENTRE -90 Y 90.', 16, 1)
        RETURN -1
    END

    IF @LONGITUD IS NOT NULL AND (@LONGITUD < -180 OR @LONGITUD > 180)
    BEGIN
        RAISERROR('3.- LA LONGITUD DEBE ESTAR ENTRE -180 Y 180.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente_Instalacion]
        (
            cin_cliente,
            cin_nombre,
            cin_descripcion,
            cin_direccion,
            cin_codigo,
            cin_zona_horaria,
            cin_latitud,
            cin_longitud,
            cin_habilitado,
            cin_usuario_creacion,
            cin_fecha_creacion,
            cin_usuario_actualizacion,
            cin_fecha_actualizacion
        )
    VALUES
        (
            @CLIENTE,
            @NOMBRE,
            @DESCRIPCION,
            @DIRECCION,
            @CODIGO,
            @ZONA_HORARIA,
            @LATITUD,
            @LONGITUD,
            @HABILITADO,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_CLIENTE_INSTALACION ' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '4.- NO FUE POSIBLE INSERTAR LA PLANTA.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   6. UPD_CLIENTE_INSTALACION                                       HU-011
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_INSTALACION]
@ID            INT,
@CLIENTE       INT = NULL,
@NOMBRE        VARCHAR(200),
@DESCRIPCION   VARCHAR(200) = NULL,
@DIRECCION     VARCHAR(200) = NULL,
@CODIGO        NVARCHAR(100) = NULL,
@ZONA_HORARIA  INT = NULL,
@LATITUD       DECIMAL(9,6) = NULL,
@LONGITUD      DECIMAL(9,6) = NULL,
@HABILITADO    BIT,
@USUARIO       INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

/* Si no viene el cliente, se toma el de la propia planta: una planta no
   cambia de dueno y asi la llamada puede omitirlo. */
IF @CLIENTE IS NULL
    SELECT @CLIENTE = cin_cliente FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @ID

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_cliente = @CLIENTE AND cin_codigo = @CODIGO AND cin_id <> @ID)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA PLANTA CON EL CÓDIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @LATITUD IS NOT NULL AND (@LATITUD < -90 OR @LATITUD > 90)
    BEGIN
        RAISERROR('2.- LA LATITUD DEBE ESTAR ENTRE -90 Y 90.', 16, 1)
        RETURN -1
    END

    IF @LONGITUD IS NOT NULL AND (@LONGITUD < -180 OR @LONGITUD > 180)
    BEGIN
        RAISERROR('3.- LA LONGITUD DEBE ESTAR ENTRE -180 Y 180.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Cliente_Instalacion]
    SET     cin_cliente               = @CLIENTE,
            cin_nombre                = @NOMBRE,
            cin_descripcion           = @DESCRIPCION,
            cin_direccion             = @DIRECCION,
            cin_codigo                = ISNULL(@CODIGO, cin_codigo),
            cin_zona_horaria          = @ZONA_HORARIA,
            cin_latitud               = @LATITUD,
            cin_longitud              = @LONGITUD,
            cin_habilitado            = @HABILITADO,
            cin_usuario_actualizacion = @USUARIO,
            cin_fecha_actualizacion   = @DATE_NOW
    WHERE   cin_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_CLIENTE_INSTALACION ' + LTRIM(STR(@ID)) + ',' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA PLANTA.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   7. SEL_CLIENTE_INSTALACION                                       HU-011

      Mismos parametros y filtros que la version anterior; se agregan las
      columnas nuevas y el nombre de la zona horaria.

      ZONA_HORARIA_EFECTIVA resuelve el escenario 2: si la planta no tiene
      zona propia, hereda la del cliente. Se calcula aqui para que ningun
      consumidor tenga que repetir esa regla.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_INSTALACION]
@ID              INT = NULL,
@CLIENTE         VARCHAR(MAX) = NULL,
@FILTRO          VARCHAR(2000) = NULL,
@USUARIO         INT = NULL,
@USUARIO_CLIENTE INT = NULL,
@PAISES          VARCHAR(MAX) = NULL,
@HABILITADO      INT = NULL

AS
SET NOCOUNT ON

---SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)

    SET @SELECT = 'SELECT   DISTINCT CIN_ID,
                            CIN_CLIENTE,
                            CIN_NOMBRE,
                            CIN_DESCRIPCION,
                            CIN_DIRECCION,
                            CIN_CODIGO,
                            CIN_ZONA_HORARIA,
                            CIN_LATITUD,
                            CIN_LONGITUD,
                            CIN_HABILITADO,
                            CIN_USUARIO_CREACION,
                            CIN_FECHA_CREACION,
                            CIN_USUARIO_ACTUALIZACION,
                            CIN_FECHA_ACTUALIZACION,
                            CLI_NOMBRE,
                            ZHO_NOMBRE,
                            ISNULL(CIN_ZONA_HORARIA, CLI_ZONA_HORARIA) AS ZONA_HORARIA_EFECTIVA
                  '
END

---FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)

    SET @FROM = ' FROM  CLIENTE_INSTALACION
                        LEFT JOIN USUARIO_INSTALACION       ON UIN_INSTALACION = CIN_ID
                        LEFT JOIN USUARIO as usuinstlacion  ON usuinstlacion.USU_ID = UIN_USUARIO
                        LEFT JOIN CLIENTE                   ON CLI_ID = CIN_CLIENTE
                        INNER JOIN PAISES                   ON CLI_PAIS = PAI_ID
                        LEFT JOIN ZONA_HORARIA              ON ZHO_ID = CIN_ZONA_HORARIA
                        LEFT JOIN CLIENTE_USUARIO           ON UCL_ID_CLIENTE = CLI_ID
                        LEFT JOIN USUARIO as usucliente     ON usucliente.USU_ID = UCL_ID_USUARIO
                '
END

---WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1 = 1'

    IF(@ID IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CIN_ID = ' + LTRIM(@ID)
    END

    IF(@CLIENTE IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CIN_CLIENTE IN(' + LTRIM(@CLIENTE)+ ')     '
    END

    IF(@FILTRO IS NOT NULL)BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE +  ' AND (CIN_NOMBRE LIKE ''%' + @FILTRO + '%''
                                   OR CIN_CODIGO LIKE ''%' + @FILTRO + '%''
                                   OR CIN_DIRECCION LIKE ''%' + @FILTRO + '%'')
                                '
    END

    IF(@HABILITADO IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND CIN_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    IF(@USUARIO IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND usuinstlacion.USU_ID = ' + LTRIM(@USUARIO)
    END

    IF(@USUARIO_CLIENTE IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND usucliente.USU_ID = ' + LTRIM(@USUARIO_CLIENTE)
    END

    IF(@PAISES IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PAI_ID IN(' + LTRIM(@PAISES) + ')      '
    END

END

--ORDER BY
BEGIN
    DECLARE @ORDER_BY VARCHAR(MAX)
    SET @ORDER_BY = ' ORDER BY CIN_HABILITADO DESC, CIN_ID DESC'
END

--PRINT(@SELECT + @FROM + @WHERE + @ORDER_BY)
EXEC(@SELECT + @FROM + @WHERE + @ORDER_BY)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'RUT valido 76.415.269-7'   AS control, [dbo].[FNC_RUT_VALIDO]('76.415.269-7') AS valor, 1 AS esperado
UNION ALL SELECT 'RUT invalido 76.415.269-8', [dbo].[FNC_RUT_VALIDO]('76.415.269-8'), 0
UNION ALL SELECT 'RUT con K 12.345.670-K',    [dbo].[FNC_RUT_VALIDO]('12.345.670-K'), 1
UNION ALL SELECT 'RUT sin puntos 764152697',  [dbo].[FNC_RUT_VALIDO]('764152697'), 1
UNION ALL SELECT 'RUT vacio',                 [dbo].[FNC_RUT_VALIDO](''), 0
UNION ALL SELECT 'RUT con letras',            [dbo].[FNC_RUT_VALIDO]('ABC12345-1'), 0
GO

SELECT 'SPs actualizados' AS control, COUNT(*) AS valor, 6 AS esperado
FROM   sys.procedures
WHERE  name IN ('INS_CLIENTE','UPD_CLIENTE','SEL_CLIENTE',
                'INS_CLIENTE_INSTALACION','UPD_CLIENTE_INSTALACION','SEL_CLIENTE_INSTALACION')
GO
