USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-036 REGISTRAR LOS COMPONENTES DE UN ACTIVO.
-- =============================================
-- Va DESPUES de 95_SPRINT2_UNIDAD_MEDIDA_MENU.
--
-- QUE CUBRE
--   T-2104  Revision del modelo Activo_Componente.
--   T-2105  SEL_ACTIVO_COMPONENTE con filtros y ORDER BY estable.
--   T-2106  INS_ACTIVO_COMPONENTE (transaccion, codigo unico, FNC_PAIS_HORA).
--   T-2107  UPD_ACTIVO_COMPONENTE (ISNULL).
--   T-2108  DEL_ACTIVO_COMPONENTE (baja logica, rechaza dependientes).
--   Ademas: SEL de los catalogos que pueblan los combos de la ficha
--   (Componente_Tipo, Activo_Componente_Estado, Componente_Posicion).
--
-- T-2104 - REVISION DEL MODELO
--   Activo_Componente (bloque 11). El codigo es unico POR ACTIVO
--   (UX_ACO_ACTIVO_CODIGO), no por cliente: dos activos pueden tener cada uno
--   su "ROD-01". La plantilla dice "por cliente" por herencia; el ambito real
--   es el activo. Ademas UX_ACO_ACTIVO_TIPO_POSICION impide dos componentes
--   del mismo tipo en la misma posicion del mismo activo; INS_/UPD_ lo validan
--   con un mensaje claro en vez del error crudo del indice.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ACO_ACTIVO_CODIGO' AND object_id=OBJECT_ID(N'[dbo].[Activo_Componente]'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_ACTIVO_CODIGO ON [dbo].[Activo_Componente] ([aco_activo],[aco_codigo])
GO
PRINT '--- Indice UX_ACO_ACTIVO_CODIGO confirmado.'
GO


/* ========================================================================
   SEL de catalogos para los combos (Tipo/Estado/Posicion)
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_COMPONENTE_TIPO]
@ID INT = NULL, @CLIENTE INT = NULL, @HABILITADO BIT = NULL
AS
SET NOCOUNT ON
    SELECT cto_id AS CTO_ID, cto_cliente AS CTO_CLIENTE, cto_codigo AS CTO_CODIGO,
           cto_nombre AS CTO_NOMBRE, cto_habilitado AS CTO_HABILITADO
    FROM   [dbo].[Componente_Tipo]
    WHERE  (@ID IS NULL OR cto_id = @ID)
      AND  (@CLIENTE IS NULL OR cto_cliente = @CLIENTE OR cto_cliente IS NULL)
      AND  (@HABILITADO IS NULL OR cto_habilitado = @HABILITADO)
    ORDER BY cto_orden, cto_nombre
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE_ESTADO]
@ID INT = NULL, @HABILITADO BIT = NULL
AS
SET NOCOUNT ON
    SELECT ace_id AS ACE_ID, ace_codigo AS ACE_CODIGO, ace_nombre AS ACE_NOMBRE,
           ace_habilitado AS ACE_HABILITADO
    FROM   [dbo].[Activo_Componente_Estado]
    WHERE  (@ID IS NULL OR ace_id = @ID)
      AND  (@HABILITADO IS NULL OR ace_habilitado = @HABILITADO)
    ORDER BY ace_orden, ace_nombre
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COMPONENTE_POSICION]
@ID INT = NULL, @CLIENTE INT = NULL, @HABILITADO BIT = NULL
AS
SET NOCOUNT ON
    SELECT cpn_id AS CPN_ID, cpn_cliente AS CPN_CLIENTE, cpn_codigo AS CPN_CODIGO,
           cpn_nombre AS CPN_NOMBRE, cpn_habilitado AS CPN_HABILITADO
    FROM   [dbo].[Componente_Posicion]
    WHERE  (@ID IS NULL OR cpn_id = @ID)
      AND  (@CLIENTE IS NULL OR cpn_cliente = @CLIENTE OR cpn_cliente IS NULL)
      AND  (@HABILITADO IS NULL OR cpn_habilitado = @HABILITADO)
    ORDER BY cpn_orden, cpn_nombre
GO


/* ========================================================================
   T-2106 - INS_ACTIVO_COMPONENTE
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_COMPONENTE]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@ACTIVO                 INT,
@COMPONENTE_PADRE       INT = NULL,
@COMPONENTE_TIPO        INT,
@COMPONENTE_POSICION    INT = NULL,
@CRITICIDAD_NIVEL       INT,
@ACTIVO_COMPONENTE_ESTADO INT,
@CODIGO                 NVARCHAR(50),
@NOMBRE                 NVARCHAR(200),
@FECHA_INSTALACION      DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id=@ACTIVO AND act_cliente=@CLIENTE)
    BEGIN
        RAISERROR('1.- EL ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_activo=@ACTIVO AND aco_codigo=@CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UN COMPONENTE CON EL CODIGO "%s" EN ESTE ACTIVO.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Un tipo por posicion dentro del activo (UX_ACO_ACTIVO_TIPO_POSICION).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                WHERE aco_activo=@ACTIVO AND aco_componente_tipo=@COMPONENTE_TIPO
                  AND ISNULL(aco_componente_posicion,0)=ISNULL(@COMPONENTE_POSICION,0))
    BEGIN
        RAISERROR('3.- YA HAY UN COMPONENTE DE ESE TIPO EN ESA POSICION DEL ACTIVO.', 16, 1)
        RETURN -1
    END

    IF @COMPONENTE_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id=@COMPONENTE_PADRE AND aco_activo=@ACTIVO)
    BEGIN
        RAISERROR('4.- EL COMPONENTE SUPERIOR DEBE SER DEL MISMO ACTIVO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo_Componente]
        (aco_cliente, aco_activo, aco_componente_padre, aco_componente_tipo,
         aco_componente_posicion, aco_criticidad_nivel, aco_activo_componente_estado,
         aco_codigo, aco_nombre, aco_fecha_instalacion, aco_descripcion,
         aco_registro_origen, aco_usuario_creacion, aco_fecha_creacion,
         aco_usuario_actualizacion, aco_fecha_actualizacion, aco_habilitado)
    VALUES
        (@CLIENTE, @ACTIVO, @COMPONENTE_PADRE, @COMPONENTE_TIPO,
         @COMPONENTE_POSICION, @CRITICIDAD_NIVEL, @ACTIVO_COMPONENTE_ESTADO,
         @CODIGO, @NOMBRE, @FECHA_INSTALACION, @DESCRIPCION,
         2, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)   -- 2 = PLANIFICADOR WEB

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'INS_ACTIVO_COMPONENTE @ACTIVO=' + LTRIM(STR(@ACTIVO)) + ',@CODIGO=' + ISNULL(@CODIGO,'')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='5.- NO FUE POSIBLE INSERTAR EL COMPONENTE.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2105 - SEL_ACTIVO_COMPONENTE
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE]
@ID       INT = NULL,
@CLIENTE  INT = NULL,
@ACTIVO   INT = NULL,
@HABILITADO BIT = NULL,
@FILTRO   VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT aco.aco_id                     AS ACO_ID
                                  ,aco.aco_cliente                AS ACO_CLIENTE
                                  ,aco.aco_activo                 AS ACO_ACTIVO
                                  ,aco.aco_componente_padre       AS ACO_COMPONENTE_PADRE
                                  ,aco.aco_componente_tipo        AS ACO_COMPONENTE_TIPO
                                  ,aco.aco_componente_posicion    AS ACO_COMPONENTE_POSICION
                                  ,aco.aco_criticidad_nivel       AS ACO_CRITICIDAD_NIVEL
                                  ,aco.aco_activo_componente_estado AS ACO_ACTIVO_COMPONENTE_ESTADO
                                  ,aco.aco_codigo                 AS ACO_CODIGO
                                  ,aco.aco_nombre                 AS ACO_NOMBRE
                                  ,aco.aco_fecha_instalacion      AS ACO_FECHA_INSTALACION
                                  ,aco.aco_descripcion            AS ACO_DESCRIPCION
                                  ,aco.aco_fecha_creacion         AS ACO_FECHA_CREACION
                                  ,aco.aco_fecha_actualizacion    AS ACO_FECHA_ACTUALIZACION
                                  ,aco.aco_habilitado             AS ACO_HABILITADO
                                  ,act.act_codigo                 AS ACTIVO_CODIGO
                                  ,act.act_nombre                 AS ACTIVO_NOMBRE
                                  ,cto.cto_nombre                 AS TIPO_NOMBRE
                                  ,ace.ace_nombre                 AS ESTADO_NOMBRE
                                  ,crn.crn_nombre                 AS CRITICIDAD_NOMBRE
                                  ,cpn.cpn_nombre                 AS POSICION_NOMBRE
                                  ,pad.aco_nombre                 AS PADRE_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Activo_Componente] aco
                  INNER JOIN [dbo].[Activo]                 act ON act.act_id = aco.aco_activo
                  INNER JOIN [dbo].[Componente_Tipo]        cto ON cto.cto_id = aco.aco_componente_tipo
                  INNER JOIN [dbo].[Activo_Componente_Estado] ace ON ace.ace_id = aco.aco_activo_componente_estado
                  INNER JOIN [dbo].[Criticidad_Nivel]       crn ON crn.crn_id = aco.aco_criticidad_nivel
                  LEFT  JOIN [dbo].[Componente_Posicion]    cpn ON cpn.cpn_id = aco.aco_componente_posicion
                  LEFT  JOIN [dbo].[Activo_Componente]      pad ON pad.aco_id = aco.aco_componente_padre
                  LEFT  JOIN [dbo].[Usuario]                uc  ON uc.usu_id  = aco.aco_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]                ua  ON ua.usu_id  = aco.aco_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)       SET @WHERE = @WHERE + ' AND aco.aco_id = ' + LTRIM(@ID)
    IF (@CLIENTE IS NOT NULL)  SET @WHERE = @WHERE + ' AND aco.aco_cliente = ' + LTRIM(@CLIENTE)
    IF (@ACTIVO IS NOT NULL)   SET @WHERE = @WHERE + ' AND aco.aco_activo = ' + LTRIM(@ACTIVO)
    IF (@HABILITADO IS NOT NULL) SET @WHERE = @WHERE + ' AND aco.aco_habilitado = ' + LTRIM(@HABILITADO)

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (aco.aco_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR aco.aco_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY act.act_codigo, aco.aco_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   T-2107 - UPD_ACTIVO_COMPONENTE
      El activo no se cambia (un componente pertenece a su maquina).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_COMPONENTE]
@ID                     INT,
@COMPONENTE_PADRE       INT = NULL,
@COMPONENTE_TIPO        INT = NULL,
@COMPONENTE_POSICION    INT = NULL,
@CRITICIDAD_NIVEL       INT = NULL,
@ACTIVO_COMPONENTE_ESTADO INT = NULL,
@CODIGO                 NVARCHAR(50) = NULL,
@NOMBRE                 NVARCHAR(200) = NULL,
@FECHA_INSTALACION      DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@HABILITADO             BIT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @ACTIVO INT
DECLARE @TIPO INT, @POS INT

SELECT @CLIENTE = aco_cliente, @ACTIVO = aco_activo,
       @TIPO = aco_componente_tipo, @POS = aco_componente_posicion
FROM   [dbo].[Activo_Componente] WHERE aco_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_activo=@ACTIVO AND aco_codigo=@CODIGO AND aco_id<>@ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN COMPONENTE CON EL CODIGO "%s" EN ESTE ACTIVO.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @COMPONENTE_PADRE IS NOT NULL AND @COMPONENTE_PADRE = @ID
    BEGIN
        RAISERROR('3.- UN COMPONENTE NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
        RETURN -1
    END

    -- Un tipo por posicion (excluyendo el propio registro).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                WHERE aco_activo=@ACTIVO AND aco_id<>@ID
                  AND aco_componente_tipo = ISNULL(@COMPONENTE_TIPO, @TIPO)
                  AND ISNULL(aco_componente_posicion,0) = ISNULL(@COMPONENTE_POSICION, ISNULL(@POS,0)))
    BEGIN
        RAISERROR('4.- YA HAY UN COMPONENTE DE ESE TIPO EN ESA POSICION DEL ACTIVO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Componente]
    SET     aco_componente_padre          = @COMPONENTE_PADRE
           ,aco_componente_tipo           = ISNULL(@COMPONENTE_TIPO, aco_componente_tipo)
           ,aco_componente_posicion       = @COMPONENTE_POSICION
           ,aco_criticidad_nivel          = ISNULL(@CRITICIDAD_NIVEL, aco_criticidad_nivel)
           ,aco_activo_componente_estado  = ISNULL(@ACTIVO_COMPONENTE_ESTADO, aco_activo_componente_estado)
           ,aco_codigo                    = ISNULL(@CODIGO, aco_codigo)
           ,aco_nombre                    = ISNULL(@NOMBRE, aco_nombre)
           ,aco_fecha_instalacion         = @FECHA_INSTALACION
           ,aco_descripcion               = @DESCRIPCION
           ,aco_habilitado                = ISNULL(@HABILITADO, aco_habilitado)
           ,aco_usuario_actualizacion     = @USUARIO
           ,aco_fecha_actualizacion       = @DATE_NOW
    WHERE   aco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'UPD_ACTIVO_COMPONENTE @ID=' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='5.- NO FUE POSIBLE ACTUALIZAR EL COMPONENTE.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2108 - DEL_ACTIVO_COMPONENTE
      Baja logica. Rechaza si tiene subcomponentes habilitados.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_COMPONENTE]
@ID INT, @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT
SELECT @CLIENTE = aco_cliente FROM [dbo].[Activo_Componente] WHERE aco_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_componente_padre=@ID AND aco_habilitado=1)
BEGIN
    RAISERROR('2.- EL COMPONENTE TIENE SUBCOMPONENTES HABILITADOS. DE BAJA PRIMERO SUS DEPENDIENTES.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE [dbo].[Activo_Componente]
    SET    aco_habilitado=0, aco_usuario_actualizacion=@USUARIO, aco_fecha_actualizacion=@DATE_NOW
    WHERE  aco_id=@ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'DEL_ACTIVO_COMPONENTE ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='3.- NO FUE POSIBLE DAR DE BAJA EL COMPONENTE.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


PRINT '96_SPRINT2_ACTIVO_COMPONENTE aplicado.'
GO
