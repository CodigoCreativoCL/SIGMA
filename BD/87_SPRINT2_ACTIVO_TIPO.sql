USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     SPRINT 2 - HU-030 ADMINISTRAR TIPOS DE ACTIVO. SEL/INS/UPD/DEL_ACTIVO_TIPO.
-- =============================================
-- Va DESPUES de 79_SPRINT2_ACTIVO_MEDIDOR_MENUS.
--
-- QUE CUBRE (tareas del Sprint 2)
--   T-2221  Revision del modelo Activo_Tipo: columnas, FK e indices.
--   T-2222  SEL_ACTIVO_TIPO: listado con filtros y ORDER BY estable (arbol).
--   T-2223  INS_ACTIVO_TIPO: alta en transaccion, codigo unico por cliente,
--           fecha con FNC_PAIS_HORA.
--   T-2224  UPD_ACTIVO_TIPO: edicion con ISNULL(@X, columna).
--   T-2225  DEL_ACTIVO_TIPO: baja logica que rechaza si tiene dependientes.
--
-- T-2221 - REVISION DEL MODELO
--   Tabla creada en el bloque 04. Es un ARBOL (ati_activo_tipo_padre) y sus
--   filas pueden ser GLOBALES de SIGMA (ati_cliente NULL) o del cliente.
--     - PK              PK_ACTIVO_TIPO (ati_id)
--     - Codigo unico    UX_ATI_CLIENTE_CODIGO (ati_cliente, ati_codigo)
--     - FK a Cliente y a Activo_Tipo (padre).
--   El codigo es unico POR CLIENTE: el cliente puede tener su propio "MOTOR"
--   aunque exista el global, porque NULL y el id del cliente son claves
--   distintas en el indice. INS_/UPD_ validan por (cliente, codigo).
--
--   SE AMPLIA SEL_ACTIVO_TIPO: el del bloque 74 solo tenia @ID/@CLIENTE/
--   @HABILITADO para poblar el combo de la ficha de activo. HU-030 necesita
--   ademas @FILTRO, la jerarquia (padre, ruta, nivel) y la auditoria. Se
--   conservan los parametros previos, asi que el combo sigue funcionando.
--
-- ES IDEMPOTENTE: CREATE OR ALTER; el indice se garantiza si falta.
-- =============================================

SET NOCOUNT ON
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_ATI_CLIENTE_CODIGO'
                  AND object_id = OBJECT_ID(N'[dbo].[Activo_Tipo]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_ATI_CLIENTE_CODIGO
        ON [dbo].[Activo_Tipo] ([ati_cliente], [ati_codigo])
    PRINT '--- Indice unico UX_ATI_CLIENTE_CODIGO creado.'
END
ELSE
    PRINT '--- Indice unico UX_ATI_CLIENTE_CODIGO ya existe (creado en el bloque 04). OK.'
GO


/* ========================================================================
   T-2223 - INS_ACTIVO_TIPO
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_TIPO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@ACTIVO_TIPO_PADRE   INT = NULL,
@CODIGO              NVARCHAR(50),
@NOMBRE              NVARCHAR(200),
@DESCRIPCION         NVARCHAR(500) = NULL,
@ORDEN               INT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente (HU-030).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                WHERE ISNULL(ati_cliente, 0) = @CLIENTE AND ati_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN TIPO DE ACTIVO CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    -- El tipo superior tiene que ser del mismo cliente o global.
    IF @ACTIVO_TIPO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                        WHERE ati_id = @ACTIVO_TIPO_PADRE
                          AND (ati_cliente = @CLIENTE OR ati_cliente IS NULL))
    BEGIN
        RAISERROR('2.- EL TIPO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo_Tipo]
        (
            ati_cliente,
            ati_activo_tipo_padre,
            ati_codigo,
            ati_nombre,
            ati_descripcion,
            ati_orden,
            ati_usuario_creacion,
            ati_fecha_creacion,
            ati_usuario_actualizacion,
            ati_fecha_actualizacion,
            ati_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @ACTIVO_TIPO_PADRE,
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
            @ORDEN,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO_TIPO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL TIPO DE ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2222 - SEL_ACTIVO_TIPO
      Arbol de tipos (globales de SIGMA + del cliente). Filtros opcionales y
      ORDER BY estable por la ruta. Un solo SP sirve la grilla, la ficha
      (@ID) y el combo de la ficha de activo (@CLIENTE, @HABILITADO).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_TIPO]
@ID                  INT = NULL,
@CLIENTE             INT = NULL,
@ACTIVO_TIPO_PADRE   INT = NULL,
@SOLO_RAIZ           BIT = NULL,
@HABILITADO          BIT = NULL,
@FILTRO              VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = ';WITH arbol AS (
                        SELECT ati_id, ati_activo_tipo_padre, 1 AS nivel,
                               CAST(ati_codigo AS NVARCHAR(4000)) AS ruta
                        FROM   Activo_Tipo
                        WHERE  ati_activo_tipo_padre IS NULL
                        UNION ALL
                        SELECT h.ati_id, h.ati_activo_tipo_padre, a.nivel + 1,
                               CAST(a.ruta + N'' / '' + h.ati_codigo AS NVARCHAR(4000))
                        FROM   Activo_Tipo h
                        INNER JOIN arbol a ON a.ati_id = h.ati_activo_tipo_padre
                    )
                    SELECT DISTINCT ati.ati_id                     AS ATI_ID
                                  ,ati.ati_cliente                 AS ATI_CLIENTE
                                  ,ati.ati_activo_tipo_padre       AS ATI_ACTIVO_TIPO_PADRE
                                  ,ati.ati_codigo                  AS ATI_CODIGO
                                  ,ati.ati_nombre                  AS ATI_NOMBRE
                                  ,ati.ati_descripcion             AS ATI_DESCRIPCION
                                  ,ati.ati_orden                   AS ATI_ORDEN
                                  ,ati.ati_usuario_creacion        AS ATI_USUARIO_CREACION
                                  ,ati.ati_fecha_creacion          AS ATI_FECHA_CREACION
                                  ,ati.ati_usuario_actualizacion   AS ATI_USUARIO_ACTUALIZACION
                                  ,ati.ati_fecha_actualizacion     AS ATI_FECHA_ACTUALIZACION
                                  ,ati.ati_habilitado              AS ATI_HABILITADO
                                  ,CASE WHEN ati.ati_cliente IS NULL THEN 1 ELSE 0 END AS ES_GLOBAL
                                  ,pad.ati_nombre                  AS PADRE_NOMBRE
                                  ,arb.nivel                       AS NIVEL
                                  ,arb.ruta                        AS RUTA
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Activo_Tipo ati
                       INNER JOIN arbol arb        ON arb.ati_id = ati.ati_id
                       LEFT  JOIN Activo_Tipo pad  ON pad.ati_id = ati.ati_activo_tipo_padre
                       LEFT  JOIN Usuario uc       ON uc.usu_id  = ati.ati_usuario_creacion
                       LEFT  JOIN Usuario ua       ON ua.usu_id  = ati.ati_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ati.ati_id = ' + LTRIM(@ID)
    END

    -- Del cliente MAS los globales (ati_cliente NULL), que valen para todos.
    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (ati.ati_cliente = ' + LTRIM(@CLIENTE) + ' OR ati.ati_cliente IS NULL) '
    END

    IF (@ACTIVO_TIPO_PADRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ati.ati_activo_tipo_padre = ' + LTRIM(@ACTIVO_TIPO_PADRE)
    END

    IF (@SOLO_RAIZ = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ati.ati_activo_tipo_padre IS NULL '
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ati.ati_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (ati.ati_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ati.ati_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY arb.ruta '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   T-2224 - UPD_ACTIVO_TIPO
      @ID y @USUARIO obligatorios; el resto con ISNULL. Un tipo GLOBAL no se
      edita desde la web -es de plataforma-. No puede depender de si mismo ni
      de un descendiente (arbol, misma logica que Centro_Costo).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_TIPO]
@ID                  INT,
@ACTIVO_TIPO_PADRE   INT = NULL,
@CODIGO              NVARCHAR(50) = NULL,
@NOMBRE              NVARCHAR(200) = NULL,
@DESCRIPCION         NVARCHAR(500) = NULL,
@ORDEN               INT = NULL,
@HABILITADO          BIT = NULL,
@QUITA_PADRE         BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT
DECLARE @ES_DESCENDIENTE BIT = 0

SELECT @CLIENTE = ati_cliente FROM [dbo].[Activo_Tipo] WHERE ati_id = @ID

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_id = @ID)
BEGIN
    RAISERROR('1.- EL TIPO DE ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

-- Un tipo global (sin cliente) es de plataforma: no se edita desde la web.
IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ESTE ES UN TIPO GLOBAL DE SIGMA Y NO SE PUEDE EDITAR DESDE AQUI.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                    WHERE ISNULL(ati_cliente, 0) = @CLIENTE AND ati_codigo = @CODIGO AND ati_id <> @ID)
    BEGIN
        RAISERROR('3.- YA EXISTE UN TIPO DE ACTIVO CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @ACTIVO_TIPO_PADRE IS NOT NULL
    BEGIN
        IF @ACTIVO_TIPO_PADRE = @ID
        BEGIN
            RAISERROR('4.- UN TIPO NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
            RETURN -1
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                        WHERE ati_id = @ACTIVO_TIPO_PADRE
                          AND (ati_cliente = @CLIENTE OR ati_cliente IS NULL))
        BEGIN
            RAISERROR('5.- EL TIPO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END

        /* El CTE se resuelve a una variable porque no puede ir en un EXISTS. */
        ;WITH descendencia AS (
            SELECT ati_id FROM [dbo].[Activo_Tipo] WHERE ati_activo_tipo_padre = @ID
            UNION ALL
            SELECT h.ati_id FROM [dbo].[Activo_Tipo] h
            INNER JOIN descendencia d ON d.ati_id = h.ati_activo_tipo_padre
        )
        SELECT @ES_DESCENDIENTE = 1 FROM descendencia WHERE ati_id = @ACTIVO_TIPO_PADRE

        IF @ES_DESCENDIENTE = 1
        BEGIN
            RAISERROR('4.- UN TIPO NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
            RETURN -1
        END
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Tipo]
    SET     ati_activo_tipo_padre     = CASE WHEN @QUITA_PADRE = 1 THEN NULL
                                             ELSE ISNULL(@ACTIVO_TIPO_PADRE, ati_activo_tipo_padre) END
           ,ati_codigo                = ISNULL(@CODIGO, ati_codigo)
           ,ati_nombre                = ISNULL(@NOMBRE, ati_nombre)
           ,ati_descripcion           = @DESCRIPCION
           ,ati_orden                 = @ORDEN
           ,ati_habilitado            = ISNULL(@HABILITADO, ati_habilitado)
           ,ati_usuario_actualizacion = @USUARIO
           ,ati_fecha_actualizacion   = @DATE_NOW
    WHERE   ati_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ACTIVO_TIPO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE ACTUALIZAR EL TIPO DE ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2225 - DEL_ACTIVO_TIPO
      Baja LOGICA. Rechaza si el tipo tiene dependientes -subtipos, activos o
      modelos que lo usan- en vez de dejarlos huerfanos. Un tipo global no se
      da de baja desde la web.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_TIPO]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_id = @ID)
BEGIN
    RAISERROR('1.- EL TIPO DE ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @CLIENTE = ati_cliente FROM [dbo].[Activo_Tipo] WHERE ati_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ESTE ES UN TIPO GLOBAL DE SIGMA Y NO SE PUEDE DAR DE BAJA DESDE AQUI.', 16, 1)
    RETURN -1
END

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_activo_tipo_padre = @ID AND ati_habilitado = 1)
    BEGIN
        RAISERROR('3.- EL TIPO TIENE SUBTIPOS HABILITADOS. DE BAJA PRIMERO SUS DEPENDIENTES.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_activo_tipo = @ID)
    BEGIN
        RAISERROR('4.- HAY ACTIVOS QUE USAN ESTE TIPO. NO SE PUEDE DAR DE BAJA.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo] WHERE amo_activo_tipo = @ID)
    BEGIN
        RAISERROR('5.- HAY MODELOS QUE USAN ESTE TIPO. NO SE PUEDE DAR DE BAJA.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Tipo]
    SET     ati_habilitado            = 0
           ,ati_usuario_actualizacion = @USUARIO
           ,ati_fecha_actualizacion   = @DATE_NOW
    WHERE   ati_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_ACTIVO_TIPO ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE DAR DE BAJA EL TIPO DE ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


PRINT '80_SPRINT2_ACTIVO_TIPO aplicado: modelo revisado y SEL/INS/UPD/DEL_ACTIVO_TIPO.'
GO
