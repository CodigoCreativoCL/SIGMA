USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EL IDENTIFICADOR TRIBUTARIO DEPENDE DEL PAIS, NO DEL CODIGO.
-- =============================================
-- Va DESPUES de 38_SPRINT1_USUARIOS_DEMO.
--
-- EL PROBLEMA
--   SIGMA es multi-pais: hay clientes en Chile, Peru, Argentina, Ecuador y
--   Panama. El identificador tributario NO se llama igual ni se valida
--   igual en cada uno: RUT en Chile, RUC en Peru y Ecuador, CUIT en
--   Argentina.
--
--   El modelo ya era neutro -las columnas se llaman cli_identificador y
--   usu_identificador, no cli_rut- y la validacion del bloque 29 y 30 ya
--   estaba acotada a Chile con un IF. Pero ese IF es CODIGO: dice
--   "si el pais es Chile, modulo 11; si no, cualquier cosa pasa".
--
--   Dos consecuencias:
--     1. Los otros cuatro paises no tienen NINGUNA validacion, ni siquiera
--        de largo. Un identificador peruano vacio o con letras entra igual.
--     2. La pantalla no tiene como saber que etiqueta poner. Un cliente
--        argentino ve "Identificacion" donde deberia decir "CUIT".
--
-- LA SOLUCION
--   Que el pais lo diga. Se agregan dos columnas a Paises: como se llama su
--   identificador y con que regla se valida. Una sola funcion
--   FNC_IDENTIFICADOR_VALIDO despacha segun eso, y agregar un pais nuevo
--   pasa a ser un INSERT.
--
-- LO QUE NO SE INVENTA
--   El digito verificador chileno esta implementado y verificado. Para RUC
--   peruano, CUIT argentino y RUC ecuatoriano hay algoritmos publicados,
--   pero NO se escriben aqui de memoria: se dejan validando estructura
--   -solo digitos y el largo que corresponde- y el algoritmo queda como
--   'PENDIENTE' hasta que alguien lo confirme contra la fuente oficial.
--   Un digito verificador mal implementado es peor que ninguno: rechaza
--   documentos validos y nadie entiende por que.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. LAS COLUMNAS NUEVAS EN Paises
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Paises]') AND name = 'pai_identificador_nombre')
BEGIN
    ALTER TABLE [dbo].[Paises] ADD [pai_identificador_nombre] NVARCHAR(50) NULL
    PRINT 'Columna pai_identificador_nombre agregada a Paises.'
END
ELSE PRINT 'Columna pai_identificador_nombre ya existe en Paises.'
GO

/* Que regla aplicar. Valores:
     MODULO11_CL  digito verificador chileno, implementado y probado
     SOLO_DIGITOS solo estructura: digitos y largo esperado
     NINGUNO      se acepta cualquier texto no vacio                       */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Paises]') AND name = 'pai_identificador_validacion')
BEGIN
    ALTER TABLE [dbo].[Paises] ADD [pai_identificador_validacion] NVARCHAR(30) NULL
    PRINT 'Columna pai_identificador_validacion agregada a Paises.'
END
ELSE PRINT 'Columna pai_identificador_validacion ya existe en Paises.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Paises]') AND name = 'pai_identificador_largo')
BEGIN
    ALTER TABLE [dbo].[Paises] ADD [pai_identificador_largo] INT NULL
    PRINT 'Columna pai_identificador_largo agregada a Paises.'
END
ELSE PRINT 'Columna pai_identificador_largo ya existe en Paises.'
GO


/* ========================================================================
   2. COMO SE LLAMA Y COMO SE VALIDA EN CADA PAIS

      Los largos son los oficiales de cada documento. El algoritmo de
      digito verificador solo esta implementado para Chile; los demas
      quedan en SOLO_DIGITOS, que ya evita basura sin rechazar documentos
      legitimos.
   ======================================================================== */

DECLARE @P TABLE (nombre NVARCHAR(100), etiqueta NVARCHAR(50), validacion NVARCHAR(30), largo INT)

INSERT INTO @P VALUES
 (N'Chile',     N'RUT',  N'MODULO11_CL',  NULL),   -- 7 u 8 digitos + DV
 (N'Perú',      N'RUC',  N'SOLO_DIGITOS', 11),
 (N'Argentina', N'CUIT', N'SOLO_DIGITOS', 11),
 (N'Ecuador',   N'RUC',  N'SOLO_DIGITOS', 13),
 (N'Panamá',    N'RUC',  N'NINGUNO',      NULL)    -- formato variable

UPDATE  p
   SET  p.pai_identificador_nombre     = a.etiqueta,
        p.pai_identificador_validacion = a.validacion,
        p.pai_identificador_largo      = a.largo
FROM    [dbo].[Paises] p
JOIN    @P a ON a.nombre COLLATE DATABASE_DEFAULT = p.pai_nombre COLLATE DATABASE_DEFAULT
GO

/* Un pais que se agregue despues y nadie configure: se acepta cualquier
   texto en vez de rechazarlo todo. Fallar abierto aqui es lo correcto:
   bloquear el alta de clientes de un pais nuevo por falta de una fila de
   catalogo seria peor que no validar. */
UPDATE [dbo].[Paises]
   SET pai_identificador_nombre     = ISNULL(pai_identificador_nombre, N'Identificación'),
       pai_identificador_validacion = ISNULL(pai_identificador_validacion, N'NINGUNO')
GO


/* ========================================================================
   3. FNC_IDENTIFICADOR_VALIDO

      La unica puerta de validacion. Reemplaza las llamadas directas a
      FNC_RUT_VALIDO en los SP de cliente y de usuario.

      FNC_RUT_VALIDO NO se elimina: sigue siendo quien sabe hacer el modulo
      11 chileno, y esta funcion la invoca. Separar "que regla toca" de
      "como se aplica la regla" es lo que permite sumar paises sin tocar a
      los que ya funcionan.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_IDENTIFICADOR_VALIDO]
(
    @PAIS          INT,
    @IDENTIFICADOR VARCHAR(100)
)
RETURNS BIT
AS
BEGIN
    IF @IDENTIFICADOR IS NULL OR LTRIM(RTRIM(@IDENTIFICADOR)) = '' RETURN 0

    DECLARE @VALIDACION NVARCHAR(30)
    DECLARE @LARGO      INT
    DECLARE @LIMPIO     VARCHAR(100)

    SELECT @VALIDACION = pai_identificador_validacion,
           @LARGO      = pai_identificador_largo
      FROM [dbo].[Paises]
     WHERE pai_id = @PAIS

    -- Pais no informado o sin configurar: no se bloquea el alta.
    IF @VALIDACION IS NULL RETURN 1

    IF @VALIDACION = N'MODULO11_CL'
        RETURN [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR)

    IF @VALIDACION = N'SOLO_DIGITOS'
    BEGIN
        SET @LIMPIO = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@IDENTIFICADOR)), '.', ''), '-', ''), ' ', '')

        IF @LIMPIO LIKE '%[^0-9]%' RETURN 0
        IF @LARGO IS NOT NULL AND LEN(@LIMPIO) <> @LARGO RETURN 0

        RETURN 1
    END

    -- NINGUNO: basta con que venga algo.
    RETURN 1
END
GO


/* ========================================================================
   4. LOS SP PASAN A USAR EL DESPACHADOR

      Se reemplaza el bloque que comparaba contra el id de Chile por una
      llamada que no sabe de paises. El mensaje de error tambien deja de
      decir "RUT": usa el nombre que el pais declara.
   ======================================================================== */

-- 4.1 INS_CLIENTE
EXEC('
ALTER PROCEDURE [dbo].[INS_CLIENTE]
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
DECLARE @ETIQUETA NVARCHAR(50)
DECLARE @MENSAJE  NVARCHAR(400)

SELECT @ETIQUETA = ISNULL(pai_identificador_nombre, N''Identificación'')
  FROM [dbo].[Paises] WHERE pai_id = @PAIS

BEGIN
    -- La regla la pone el pais del cliente, no el codigo.
    IF [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @IDENTIFICADOR) = 0
    BEGIN
        SET @MENSAJE = N''1.- EL '' + ISNULL(@ETIQUETA, N''IDENTIFICADOR'') + N'' "'' + @IDENTIFICADOR + N''" NO ES VÁLIDO.''
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_identificador = @IDENTIFICADOR)
    BEGIN
        SET @MENSAJE = N''2.- YA EXISTE UN CLIENTE CON EL '' + ISNULL(@ETIQUETA, N''IDENTIFICADOR'') + N'' "'' + @IDENTIFICADOR + N''".''
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente]
        (cli_nombre, cli_habilitado, cli_pais, cli_razon_social, cli_identificador,
         cli_nombre_fantasia, cli_zona_horaria, cli_idioma, cli_moneda,
         cli_usuario_creacion, cli_fecha_creacion, cli_usuario_actualizacion,
         cli_fecha_actualizacion, cli_logo)
    VALUES
        (@NOMBRE, @HABILITADO, @PAIS, @RAZON_SOCIAL, @IDENTIFICADOR,
         @NOMBRE_FANTASIA, @ZONA_HORARIA, @IDIOMA, @MONEDA,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, @LOGO)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = ''INS_CLIENTE '' + ISNULL(@NOMBRE, '''')
        EXEC [dbo].[INS_EXCEPCION] @MSG = ''3.- NO FUE POSIBLE INSERTAR EL CLIENTE.'', @VARIABLES = @VARIABLES
        RETURN -1
    END

    DECLARE @ID_CLIENTE_USUARIO INT

    INSERT [dbo].[Cliente_Usuario]
        (ucl_id_usuario, ucl_id_cliente, ucl_usuario_creacion, ucl_fecha_creacion,
         ucl_usuario_act, ucl_fecha_act, ucl_habilitado)
    VALUES (@USUARIO, @ID, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID_CLIENTE_USUARIO = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        SET @VARIABLES = ''INS_CLIENTE '' + ISNULL(@NOMBRE, '''')
        EXEC [dbo].[INS_EXCEPCION] @MSG = ''4.- NO FUE POSIBLE ASOCIAR EL USUARIO AL CLIENTE.'', @VARIABLES = @VARIABLES
        RETURN -1
    END

    /* Copia de perfiles: UPE_PERFIL, no UPE_ID. Y sin comprobar @@ROWCOUNT,
       porque un administrador de plataforma puede no tener perfiles de
       cliente y el alta igual debe completarse. */
    INSERT [dbo].[Cliente_Usuario_Perfil]
        (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
    SELECT @ID_CLIENTE_USUARIO, upe.upe_perfil, @USUARIO, @DATE_NOW
    FROM   [dbo].[Usuario_Perfil] upe
    WHERE  upe.upe_usuario = @USUARIO
      AND  EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = upe.upe_perfil AND per_tipo = 2)

COMMIT TRANSACTION

RETURN(0)
')
GO

-- 4.2 UPD_CLIENTE
EXEC('
ALTER PROCEDURE [dbo].[UPD_CLIENTE]
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
DECLARE @ETIQUETA NVARCHAR(50)
DECLARE @MENSAJE  NVARCHAR(400)

SELECT @ETIQUETA = ISNULL(pai_identificador_nombre, N''Identificación'')
  FROM [dbo].[Paises] WHERE pai_id = @PAIS

BEGIN
    IF [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @IDENTIFICADOR) = 0
    BEGIN
        SET @MENSAJE = N''1.- EL '' + ISNULL(@ETIQUETA, N''IDENTIFICADOR'') + N'' "'' + @IDENTIFICADOR + N''" NO ES VÁLIDO.''
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_identificador = @IDENTIFICADOR AND cli_id <> @ID)
    BEGIN
        SET @MENSAJE = N''2.- YA EXISTE OTRO CLIENTE CON EL '' + ISNULL(@ETIQUETA, N''IDENTIFICADOR'') + N'' "'' + @IDENTIFICADOR + N''".''
        RAISERROR(@MENSAJE, 16, 1)
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
            cli_logo                  = CASE WHEN @CAMBIA_LOGO = 1 THEN @LOGO ELSE cli_logo END
    WHERE   cli_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = ''UPD_CLIENTE '' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @MSG = ''3.- NO FUE POSIBLE ACTUALIZAR EL CLIENTE.'', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
')
GO


/* ========================================================================
   5. LOS SP DE USUARIO

      Se reemplaza solo el bloque de validacion; el resto queda igual. El
      pais sale del cliente al que se esta afiliando la persona.
   ======================================================================== */

DECLARE @SQL NVARCHAR(MAX)

-- INS_USUARIO
SELECT @SQL = REPLACE(
        REPLACE(OBJECT_DEFINITION(OBJECT_ID('INS_USUARIO')), 'CREATE   PROCEDURE', 'ALTER PROCEDURE'),
        'IF @PAIS_CLIENTE = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0',
        'IF @CLIENTE IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_CLIENTE, @IDENTIFICADOR) = 0')

SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
SET @SQL = REPLACE(@SQL, '4. El RUT "%s" no es válido.', '4. El identificador "%s" no es válido para el país del cliente.')
EXEC sp_executesql @SQL
GO

DECLARE @SQL NVARCHAR(MAX)

-- UPD_USUARIO
SELECT @SQL = REPLACE(
        REPLACE(OBJECT_DEFINITION(OBJECT_ID('UPD_USUARIO')), 'CREATE   PROCEDURE', 'ALTER PROCEDURE'),
        'IF @PAIS_CLIENTE = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0',
        'IF @CLIENTE IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_CLIENTE, @IDENTIFICADOR) = 0')

SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
SET @SQL = REPLACE(@SQL, '4. El RUT "%s" no es válido.', '4. El identificador "%s" no es válido para el país del cliente.')
EXEC sp_executesql @SQL
GO


/* ========================================================================
   6. SEL_PAIS_IDENTIFICADOR

      Lo consulta la pantalla para poner la etiqueta correcta: "RUT" en un
      cliente chileno, "CUIT" en uno argentino.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PAIS_IDENTIFICADOR]
@PAIS INT
AS
SET NOCOUNT ON

    SELECT  pai_id                                                    AS PAI_ID,
            pai_nombre                                                AS PAI_NOMBRE,
            ISNULL(pai_identificador_nombre, N'Identificación')       AS ETIQUETA,
            ISNULL(pai_identificador_validacion, N'NINGUNO')          AS VALIDACION,
            pai_identificador_largo                                   AS LARGO
    FROM    [dbo].[Paises]
    WHERE   pai_id = @PAIS
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT  pai_id, pai_nombre,
        pai_identificador_nombre     AS etiqueta,
        pai_identificador_validacion AS regla,
        pai_identificador_largo      AS largo
FROM    [dbo].[Paises]
ORDER BY pai_id
GO

-- Chile aplica modulo 11; los demas solo estructura.
SELECT 'Chile · RUT correcto'          AS caso, [dbo].[FNC_IDENTIFICADOR_VALIDO](1, '76.415.269-7')   AS valido, 1 AS esperado
UNION ALL SELECT 'Chile · DV cambiado',      [dbo].[FNC_IDENTIFICADOR_VALIDO](1, '76.415.269-8'),   0
UNION ALL SELECT 'Perú · RUC de 11 dígitos', [dbo].[FNC_IDENTIFICADOR_VALIDO](3, '20512333797'),    1
UNION ALL SELECT 'Perú · RUC corto',         [dbo].[FNC_IDENTIFICADOR_VALIDO](3, '2051233'),        0
UNION ALL SELECT 'Perú · con letras',        [dbo].[FNC_IDENTIFICADOR_VALIDO](3, '2051233379A'),    0
UNION ALL SELECT 'Argentina · CUIT',         [dbo].[FNC_IDENTIFICADOR_VALIDO](4, '30-71044943-8'),  1
UNION ALL SELECT 'Ecuador · RUC de 13',      [dbo].[FNC_IDENTIFICADOR_VALIDO](5, '1791287541001'),  1
UNION ALL SELECT 'Panamá · formato libre',   [dbo].[FNC_IDENTIFICADOR_VALIDO](6, '155646463-2-2017'), 1
UNION ALL SELECT 'Cualquiera · vacío',       [dbo].[FNC_IDENTIFICADOR_VALIDO](1, ''),               0
GO
