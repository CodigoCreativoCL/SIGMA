USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-02. AREAS, CENTROS DE COSTO, GRUPOS Y ESPECIALIDADES.
-- =============================================
-- Va DESPUES de 26_SPRINT1_SEGURIDAD.
--
-- QUE CUBRE
--   HU-012  Areas de una planta, en arbol y sin ciclos.
--   HU-013  Centros de costo, en arbol y con codigo unico.
--   HU-016  Grupos de trabajo y sus integrantes, con un solo lider vigente.
--   HU-017  Especialidades y certificaciones de un usuario.
--
-- LA FECHA
--   SIGMA es multi-pais: existen Paises, Usuario_Paises y FNC_PAIS_HORA.
--   Por eso las fechas de auditoria se calculan con la hora del pais del
--   cliente y no con GETDATE(), igual que en INS_CLIENTE_INSTALACION
--   (PATRON_SP §5).
--
-- LOS CICLOS
--   HU-012 escenario 2 y HU-013 exigen impedir que un nodo dependa de un
--   descendiente suyo. No basta con comparar padre <> hijo: A->B->C->A
--   pasaria esa prueba. Se recorre la descendencia con un CTE recursivo.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ########################################################################
   HU-012 - INSTALACION_AREA
   ######################################################################## */

/* ========================================================================
   INS_INSTALACION_AREA
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_INSTALACION_AREA]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CLIENTE_INSTALACION    INT,
@AREA_PADRE             INT = NULL,
@INSTALACION_AREA_TIPO  INT = NULL,
@CODIGO                 NVARCHAR(100),
@NOMBRE                 NVARCHAR(400),
@DESCRIPCION            NVARCHAR(1000) = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El codigo viaja en mayusculas y sin espacios, como pide la HU. Se
   normaliza aqui y no solo en la pantalla: la API tambien va a insertar. */
SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    -- 1. La planta debe ser del cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 2. Codigo unico dentro de la planta
    IF EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                WHERE iar_cliente_instalacion = @CLIENTE_INSTALACION AND iar_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UN ÁREA CON EL CÓDIGO "%s" EN ESTA PLANTA.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- 3. El area superior debe estar en la misma planta
    IF @AREA_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                        WHERE iar_id = @AREA_PADRE AND iar_cliente_instalacion = @CLIENTE_INSTALACION)
    BEGIN
        RAISERROR('3.- EL ÁREA SUPERIOR NO PERTENECE A ESTA PLANTA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Instalacion_Area]
        (
            iar_cliente,
            iar_cliente_instalacion,
            iar_area_padre,
            iar_instalacion_area_tipo,
            iar_codigo,
            iar_nombre,
            iar_descripcion,
            iar_usuario_creacion,
            iar_fecha_creacion,
            iar_usuario_actualizacion,
            iar_fecha_actualizacion,
            iar_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @AREA_PADRE,
            @INSTALACION_AREA_TIPO,
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
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
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_INSTALACION_AREA ' +
              '@CLIENTE_INSTALACION = ' + LTRIM(STR(@CLIENTE_INSTALACION)) + ',' +
              '@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL ÁREA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   SEL_INSTALACION_AREA

   NIVEL y RUTA se calculan con un CTE recursivo para que la pantalla pueda
   pintar el arbol sin ir a la base una vez por rama.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INSTALACION_AREA]
@ID                     INT = NULL,
@CLIENTE                INT = NULL,
@CLIENTE_INSTALACION    INT = NULL,
@AREA_PADRE             INT = NULL,
@SOLO_RAIZ              BIT = NULL,
@HABILITADO             BIT = NULL,
@FILTRO                 VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = ';WITH arbol AS (
                        SELECT iar_id, iar_area_padre, 1 AS nivel,
                               CAST(iar_nombre AS NVARCHAR(4000)) AS ruta
                        FROM   Instalacion_Area
                        WHERE  iar_area_padre IS NULL
                        UNION ALL
                        SELECT h.iar_id, h.iar_area_padre, a.nivel + 1,
                               CAST(a.ruta + N'' / '' + h.iar_nombre AS NVARCHAR(4000))
                        FROM   Instalacion_Area h
                        INNER JOIN arbol a ON a.iar_id = h.iar_area_padre
                    )
                    SELECT DISTINCT iar.iar_id                    AS IAR_ID
                                  ,iar.iar_cliente                AS IAR_CLIENTE
                                  ,iar.iar_cliente_instalacion    AS IAR_CLIENTE_INSTALACION
                                  ,iar.iar_area_padre             AS IAR_AREA_PADRE
                                  ,iar.iar_instalacion_area_tipo  AS IAR_INSTALACION_AREA_TIPO
                                  ,iar.iar_codigo                 AS IAR_CODIGO
                                  ,iar.iar_nombre                 AS IAR_NOMBRE
                                  ,iar.iar_descripcion            AS IAR_DESCRIPCION
                                  ,iar.iar_usuario_creacion       AS IAR_USUARIO_CREACION
                                  ,iar.iar_fecha_creacion         AS IAR_FECHA_CREACION
                                  ,iar.iar_usuario_actualizacion  AS IAR_USUARIO_ACTUALIZACION
                                  ,iar.iar_fecha_actualizacion    AS IAR_FECHA_ACTUALIZACION
                                  ,iar.iar_habilitado             AS IAR_HABILITADO
                                  ,cin.cin_nombre                 AS CIN_NOMBRE
                                  ,pad.iar_nombre                 AS PADRE_NOMBRE
                                  ,iat.iat_nombre                 AS IAT_NOMBRE
                                  ,arb.nivel                      AS NIVEL
                                  ,arb.ruta                       AS RUTA
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Instalacion_Area iar
                       INNER JOIN arbol arb                ON arb.iar_id = iar.iar_id
                       INNER JOIN Cliente_Instalacion cin  ON cin.cin_id = iar.iar_cliente_instalacion
                       LEFT  JOIN Instalacion_Area pad     ON pad.iar_id = iar.iar_area_padre
                       LEFT  JOIN Instalacion_Area_Tipo iat ON iat.iat_id = iar.iar_instalacion_area_tipo
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@AREA_PADRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_area_padre = ' + LTRIM(@AREA_PADRE)
    END

    IF (@SOLO_RAIZ = 1) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_area_padre IS NULL '
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND iar.iar_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (iar.iar_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR iar.iar_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR iar.iar_descripcion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY arb.ruta '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   UPD_INSTALACION_AREA

   Aqui vive la comprobacion de ciclo (HU-012 escenario 2). En el INSERT no
   hace falta: un area recien creada no tiene descendencia.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_INSTALACION_AREA]
@ID                     INT,
@AREA_PADRE             INT = NULL,
@INSTALACION_AREA_TIPO  INT = NULL,
@CODIGO                 NVARCHAR(100) = NULL,
@NOMBRE                 NVARCHAR(400) = NULL,
@DESCRIPCION            NVARCHAR(1000) = NULL,
@HABILITADO             BIT = NULL,
@QUITA_PADRE            BIT = 0,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @INSTALACION INT, @CLIENTE INT
DECLARE @ES_DESCENDIENTE BIT = 0

SELECT  @INSTALACION = iar_cliente_instalacion, @CLIENTE = iar_cliente
FROM    [dbo].[Instalacion_Area] WHERE iar_id = @ID

IF @INSTALACION IS NULL
BEGIN
    RAISERROR('1.- EL ÁREA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    -- Codigo unico dentro de la planta
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                    WHERE iar_cliente_instalacion = @INSTALACION
                      AND iar_codigo = @CODIGO AND iar_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN ÁREA CON EL CÓDIGO "%s" EN ESTA PLANTA.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @AREA_PADRE IS NOT NULL
    BEGIN
        -- No puede ser su propio padre
        IF @AREA_PADRE = @ID
        BEGIN
            RAISERROR('3.- Un área no puede depender de si misma.', 16, 1)
            RETURN -1
        END

        -- El padre debe estar en la misma planta
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                        WHERE iar_id = @AREA_PADRE AND iar_cliente_instalacion = @INSTALACION)
        BEGIN
            RAISERROR('4.- EL ÁREA SUPERIOR NO PERTENECE A ESTA PLANTA.', 16, 1)
            RETURN -1
        END

        /* El padre propuesto no puede ser descendiente del area. Se recorre
           la descendencia completa: A->B->C->A no lo detectaria una simple
           comparacion de un nivel.

           El CTE no puede ir dentro de un EXISTS, asi que se resuelve a una
           variable y despues se pregunta por ella. */
        ;WITH descendencia AS (
            SELECT iar_id FROM [dbo].[Instalacion_Area] WHERE iar_area_padre = @ID
            UNION ALL
            SELECT h.iar_id FROM [dbo].[Instalacion_Area] h
            INNER JOIN descendencia d ON d.iar_id = h.iar_area_padre
        )
        SELECT @ES_DESCENDIENTE = 1 FROM descendencia WHERE iar_id = @AREA_PADRE

        IF @ES_DESCENDIENTE = 1
        BEGIN
            RAISERROR('3.- Un área no puede depender de si misma.', 16, 1)
            RETURN -1
        END
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Instalacion_Area]
    SET     iar_area_padre            = CASE WHEN @QUITA_PADRE = 1 THEN NULL
                                             ELSE ISNULL(@AREA_PADRE, iar_area_padre) END
           ,iar_instalacion_area_tipo = @INSTALACION_AREA_TIPO
           ,iar_codigo                = ISNULL(@CODIGO, iar_codigo)
           ,iar_nombre                = ISNULL(@NOMBRE, iar_nombre)
           ,iar_descripcion           = @DESCRIPCION
           ,iar_habilitado            = ISNULL(@HABILITADO, iar_habilitado)
           ,iar_usuario_actualizacion = @USUARIO
           ,iar_fecha_actualizacion   = @DATE_NOW
    WHERE   iar_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_INSTALACION_AREA @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL ÁREA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   DEL_INSTALACION_AREA

   Borrado FISICO solo si el area esta vacia. Un area con hijas o con
   activos colgando se deshabilita con UPD_ (@HABILITADO = 0), no se borra:
   los registros historicos que la referencian deben seguir resolviendo su
   nombre.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_INSTALACION_AREA]
@ID INT
AS
SET NOCOUNT ON

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area] WHERE iar_area_padre = @ID)
    BEGIN
        RAISERROR('1.- EL ÁREA TIENE SUBÁREAS. DESHABILÍTELA EN VEZ DE ELIMINARLA.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_instalacion_area = @ID)
    BEGIN
        RAISERROR('2.- EL ÁREA TIENE ACTIVOS ASOCIADOS. DESHABILÍTELA EN VEZ DE ELIMINARLA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    DELETE  [dbo].[Instalacion_Area]
    WHERE   iar_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_INSTALACION_AREA ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE ELIMINAR EL ÁREA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ########################################################################
   HU-013 - CENTRO_COSTO
   ######################################################################## */

CREATE OR ALTER PROCEDURE [dbo].[INS_CENTRO_COSTO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@CENTRO_COSTO_PADRE  INT = NULL,
@CODIGO              NVARCHAR(100),
@NOMBRE              NVARCHAR(400),
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente (HU-013 escenario 2)
    IF EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                WHERE cco_cliente = @CLIENTE AND cco_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN CENTRO DE COSTO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @CENTRO_COSTO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                        WHERE cco_id = @CENTRO_COSTO_PADRE AND cco_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- EL CENTRO DE COSTO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Centro_Costo]
        (
            cco_cliente,
            cco_centro_costo_padre,
            cco_codigo,
            cco_nombre,
            cco_usuario_creacion,
            cco_fecha_creacion,
            cco_usuario_actualizacion,
            cco_fecha_actualizacion,
            cco_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CENTRO_COSTO_PADRE,
            @CODIGO,
            @NOMBRE,
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
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CENTRO_COSTO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL CENTRO DE COSTO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_CENTRO_COSTO]
@ID                  INT = NULL,
@CLIENTE             INT = NULL,
@CENTRO_COSTO_PADRE  INT = NULL,
@SOLO_RAIZ           BIT = NULL,
@HABILITADO          BIT = NULL,
@FILTRO              VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = ';WITH arbol AS (
                        SELECT cco_id, cco_centro_costo_padre, 1 AS nivel,
                               CAST(cco_codigo AS NVARCHAR(4000)) AS ruta
                        FROM   Centro_Costo
                        WHERE  cco_centro_costo_padre IS NULL
                        UNION ALL
                        SELECT h.cco_id, h.cco_centro_costo_padre, a.nivel + 1,
                               CAST(a.ruta + N'' / '' + h.cco_codigo AS NVARCHAR(4000))
                        FROM   Centro_Costo h
                        INNER JOIN arbol a ON a.cco_id = h.cco_centro_costo_padre
                    )
                    SELECT DISTINCT cco.cco_id                     AS CCO_ID
                                  ,cco.cco_cliente                 AS CCO_CLIENTE
                                  ,cco.cco_centro_costo_padre      AS CCO_CENTRO_COSTO_PADRE
                                  ,cco.cco_codigo                  AS CCO_CODIGO
                                  ,cco.cco_nombre                  AS CCO_NOMBRE
                                  ,cco.cco_usuario_creacion        AS CCO_USUARIO_CREACION
                                  ,cco.cco_fecha_creacion          AS CCO_FECHA_CREACION
                                  ,cco.cco_usuario_actualizacion   AS CCO_USUARIO_ACTUALIZACION
                                  ,cco.cco_fecha_actualizacion     AS CCO_FECHA_ACTUALIZACION
                                  ,cco.cco_habilitado              AS CCO_HABILITADO
                                  ,pad.cco_nombre                  AS PADRE_NOMBRE
                                  ,arb.nivel                       AS NIVEL
                                  ,arb.ruta                        AS RUTA
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Centro_Costo cco
                       INNER JOIN arbol arb        ON arb.cco_id = cco.cco_id
                       LEFT  JOIN Centro_Costo pad ON pad.cco_id = cco.cco_centro_costo_padre
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cco.cco_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cco.cco_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CENTRO_COSTO_PADRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cco.cco_centro_costo_padre = ' + LTRIM(@CENTRO_COSTO_PADRE)
    END

    IF (@SOLO_RAIZ = 1) BEGIN
        SET @WHERE = @WHERE + ' AND cco.cco_centro_costo_padre IS NULL '
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cco.cco_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (cco.cco_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cco.cco_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY arb.ruta '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


CREATE OR ALTER PROCEDURE [dbo].[UPD_CENTRO_COSTO]
@ID                  INT,
@CENTRO_COSTO_PADRE  INT = NULL,
@CODIGO              NVARCHAR(100) = NULL,
@NOMBRE              NVARCHAR(400) = NULL,
@HABILITADO          BIT = NULL,
@QUITA_PADRE         BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT
DECLARE @ES_DESCENDIENTE BIT = 0

SELECT @CLIENTE = cco_cliente FROM [dbo].[Centro_Costo] WHERE cco_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL CENTRO DE COSTO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                    WHERE cco_cliente = @CLIENTE AND cco_codigo = @CODIGO AND cco_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN CENTRO DE COSTO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @CENTRO_COSTO_PADRE IS NOT NULL
    BEGIN
        IF @CENTRO_COSTO_PADRE = @ID
        BEGIN
            RAISERROR('3.- UN CENTRO DE COSTO NO PUEDE DEPENDER DE SÍ MISMO.', 16, 1)
            RETURN -1
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                        WHERE cco_id = @CENTRO_COSTO_PADRE AND cco_cliente = @CLIENTE)
        BEGIN
            RAISERROR('4.- EL CENTRO DE COSTO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END

        /* Misma razon que en las areas: el CTE se resuelve a una variable
           porque no puede ir dentro de un EXISTS. */
        ;WITH descendencia AS (
            SELECT cco_id FROM [dbo].[Centro_Costo] WHERE cco_centro_costo_padre = @ID
            UNION ALL
            SELECT h.cco_id FROM [dbo].[Centro_Costo] h
            INNER JOIN descendencia d ON d.cco_id = h.cco_centro_costo_padre
        )
        SELECT @ES_DESCENDIENTE = 1 FROM descendencia WHERE cco_id = @CENTRO_COSTO_PADRE

        IF @ES_DESCENDIENTE = 1
        BEGIN
            RAISERROR('3.- UN CENTRO DE COSTO NO PUEDE DEPENDER DE SÍ MISMO.', 16, 1)
            RETURN -1
        END
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Centro_Costo]
    SET     cco_centro_costo_padre    = CASE WHEN @QUITA_PADRE = 1 THEN NULL
                                             ELSE ISNULL(@CENTRO_COSTO_PADRE, cco_centro_costo_padre) END
           ,cco_codigo                = ISNULL(@CODIGO, cco_codigo)
           ,cco_nombre                = ISNULL(@NOMBRE, cco_nombre)
           ,cco_habilitado            = ISNULL(@HABILITADO, cco_habilitado)
           ,cco_usuario_actualizacion = @USUARIO
           ,cco_fecha_actualizacion   = @DATE_NOW
    WHERE   cco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CENTRO_COSTO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL CENTRO DE COSTO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


CREATE OR ALTER PROCEDURE [dbo].[DEL_CENTRO_COSTO]
@ID INT
AS
SET NOCOUNT ON

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Centro_Costo] WHERE cco_centro_costo_padre = @ID)
    BEGIN
        RAISERROR('1.- EL CENTRO DE COSTO TIENE DEPENDIENTES. DESHABILÍTELO EN VEZ DE ELIMINARLO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    DELETE  [dbo].[Centro_Costo]
    WHERE   cco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_CENTRO_COSTO ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '2.- NO FUE POSIBLE ELIMINAR EL CENTRO DE COSTO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
