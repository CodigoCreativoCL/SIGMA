USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  11-09-2026
-- DESCRIPTION:     SPRINT 4 - HU-090 DISENAR UNA PLANTILLA DE CHECKLIST. MODELO, SEL/INS/UPD/DEL Y LOOKUP.
-- =============================================
-- Sigue la plantilla del bloque 74 (HU-035 Activo) y PATRONES/ASP/BaseDatos/PATRON_SP.md.
--
-- QUE CUBRE ESTE BLOQUE (tareas del Sprint 4)
--   T-4067  Revision del modelo Checklist_Plantilla: columnas, FK e indices.
--           Confirma el indice unico del codigo dentro del cliente.
--   T-4068  SEL_CHECKLIST_PLANTILLA: listado con filtros opcionales y ORDER BY
--           estable. Un solo SP sirve a la grilla y a la ficha.
--   T-4069  INS_CHECKLIST_PLANTILLA: alta en transaccion, codigo unico por
--           cliente, fecha sellada con FNC_PAIS_HORA.
--   T-4070  UPD_CHECKLIST_PLANTILLA: edicion con ISNULL(@X, columna).
--   T-4071  DEL_CHECKLIST_PLANTILLA: baja logica que rechaza si tiene
--           dependientes (versiones publicadas).
--
--   Ademas: SEL_CHECKLIST_ASIGNACION_TIPO para poblar el combo de la ficha
--   (el estandar prohibe escribir el catalogo a mano en el .aspx).
--
-- ES IDEMPOTENTE (CREATE OR ALTER en los SP; el indice se crea solo si falta).
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-4067 - REVISION DEL MODELO Checklist_Plantilla
   ------------------------------------------------------------------------
   La tabla Checklist_Plantilla se creo en el bloque 15 (15_CHECKLIST). Aqui
   NO se recrea: solo se confirma lo que HU-090 necesita.

     - PK           PK_CHECKLIST_PLANTILLA (cpl_id)
     - Codigo unico POR CLIENTE  ->  UX_CPL_CLIENTE_CODIGO (cpl_cliente, cpl_codigo)
     - FK a Cliente, Cliente_Instalacion, Checklist_Asignacion_Tipo, Activo_Tipo.
     - Auditoria: cpl_usuario_creacion / cpl_fecha_creacion /
       cpl_usuario_actualizacion / cpl_fecha_actualizacion / cpl_habilitado.

   El indice unico del codigo dentro del cliente es el escenario de negocio de
   HU-090 ("no puede haber dos plantillas con el mismo codigo en el mismo
   cliente"). Se garantiza idempotente: si el bloque 15 ya lo creo, esto no
   hace nada. La validacion tambien vive en INS_/UPD_ para devolver un mensaje
   claro en vez del error 2601 crudo del indice.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_CPL_CLIENTE_CODIGO'
                  AND object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_CPL_CLIENTE_CODIGO
        ON [dbo].[Checklist_Plantilla] ([cpl_cliente], [cpl_codigo])
    PRINT '--- Indice unico UX_CPL_CLIENTE_CODIGO creado.'
END
ELSE
    PRINT '--- Indice unico UX_CPL_CLIENTE_CODIGO ya existe (creado en el bloque 15). OK.'
GO


/* ========================================================================
   T-4069 - INS_CHECKLIST_PLANTILLA
      Alta dentro de transaccion. Valida el codigo unico por cliente ANTES de
      la transaccion y sella las fechas con la hora local del pais del cliente
      (FNC_PAIS_HORA), no con GETDATE(): SIGMA opera en cinco paises.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_PLANTILLA]
@ID                         INT = NULL OUTPUT,
@CLIENTE                    INT,
@CLIENTE_INSTALACION        INT = NULL,
@CHECKLIST_ASIGNACION_TIPO  INT = NULL,
@ACTIVO_TIPO                INT = NULL,
@CODIGO                     NVARCHAR(50),
@NOMBRE                     NVARCHAR(200),
@DESCRIPCION                NVARCHAR(MAX) = NULL,
@USUARIO                    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente (escenario de negocio de HU-090).
    IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla]
                WHERE cpl_cliente = @CLIENTE AND cpl_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA PLANTILLA CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta, si se indica, tiene que ser del mismo cliente.
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Checklist_Plantilla]
        (
            cpl_cliente,
            cpl_cliente_instalacion,
            cpl_checklist_asignacion_tipo,
            cpl_activo_tipo,
            cpl_codigo,
            cpl_nombre,
            cpl_descripcion,
            cpl_usuario_creacion,
            cpl_fecha_creacion,
            cpl_usuario_actualizacion,
            cpl_fecha_actualizacion,
            cpl_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @CHECKLIST_ASIGNACION_TIPO,
            @ACTIVO_TIPO,
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
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CHECKLIST_PLANTILLA @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR LA PLANTILLA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-4068 - SEL_CHECKLIST_PLANTILLA
      Listado con filtros opcionales (id, cliente, planta, tipo de activo,
      habilitado, texto) y ORDER BY estable. El mismo SP sirve la grilla y la
      ficha (@ID) y puebla combos (@HABILITADO = 1).

      Devuelve el nombre de cada FK y las cuatro columnas de auditoria con el
      nombre del usuario (LEFT JOIN a Usuario). Patron dinamico
      @SELECT/@FROM/@WHERE de PATRON_SP, con @FILTRO escapado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_PLANTILLA]
@ID                     INT = NULL,
@CLIENTE                INT = NULL,
@CLIENTE_INSTALACION    INT = NULL,
@ACTIVO_TIPO            INT = NULL,
@HABILITADO             BIT = NULL,
@FILTRO                 VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT cpl.cpl_id                        AS CPL_ID
                                  ,cpl.cpl_cliente                    AS CPL_CLIENTE
                                  ,cpl.cpl_cliente_instalacion        AS CPL_CLIENTE_INSTALACION
                                  ,cpl.cpl_checklist_asignacion_tipo  AS CPL_CHECKLIST_ASIGNACION_TIPO
                                  ,cpl.cpl_activo_tipo                AS CPL_ACTIVO_TIPO
                                  ,cpl.cpl_codigo                     AS CPL_CODIGO
                                  ,cpl.cpl_nombre                     AS CPL_NOMBRE
                                  ,cpl.cpl_descripcion                AS CPL_DESCRIPCION
                                  ,cpl.cpl_usuario_creacion           AS CPL_USUARIO_CREACION
                                  ,cpl.cpl_fecha_creacion             AS CPL_FECHA_CREACION
                                  ,cpl.cpl_usuario_actualizacion      AS CPL_USUARIO_ACTUALIZACION
                                  ,cpl.cpl_fecha_actualizacion        AS CPL_FECHA_ACTUALIZACION
                                  ,cpl.cpl_habilitado                 AS CPL_HABILITADO
                                  ,ISNULL(cin.cin_nombre, '''')       AS PLANTA_NOMBRE
                                  ,ISNULL(cat.cat_nombre, '''')       AS ASIGNACION_TIPO_NOMBRE
                                  ,ISNULL(ati.ati_nombre, '''')       AS ACTIVO_TIPO_NOMBRE
                                  ,(SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Version] v
                                     WHERE v.cpv_checklist_plantilla = cpl.cpl_id) AS VERSIONES
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Checklist_Plantilla] cpl
                  LEFT JOIN [dbo].[Cliente_Instalacion]        cin ON cin.cin_id = cpl.cpl_cliente_instalacion
                  LEFT JOIN [dbo].[Checklist_Asignacion_Tipo]  cat ON cat.cat_id = cpl.cpl_checklist_asignacion_tipo
                  LEFT JOIN [dbo].[Activo_Tipo]                ati ON ati.ati_id = cpl.cpl_activo_tipo
                  LEFT JOIN [dbo].[Usuario]                    uc  ON uc.usu_id  = cpl.cpl_usuario_creacion
                  LEFT JOIN [dbo].[Usuario]                    ua  ON ua.usu_id  = cpl.cpl_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpl.cpl_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpl.cpl_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpl.cpl_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@ACTIVO_TIPO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpl.cpl_activo_tipo = ' + LTRIM(@ACTIVO_TIPO)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpl.cpl_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (cpl.cpl_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cpl.cpl_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cpl.cpl_descripcion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    -- ORDER BY estable: el codigo es unico por cliente, no hay empates.
    SET @WHERE = @WHERE + ' ORDER BY cpl.cpl_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   T-4070 - UPD_CHECKLIST_PLANTILLA
      Edicion. @ID y @USUARIO obligatorios; el resto opcional. Los campos que
      la ficha muestra y pueden quedar en blanco a proposito (planta, tipo de
      asignacion, tipo de activo, descripcion) se asignan directo. Los que la
      ficha podria no traer se conservan con ISNULL(@X, columna). Fecha sellada
      con la hora local del pais.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_PLANTILLA]
@ID                         INT,
@CLIENTE_INSTALACION        INT = NULL,
@CHECKLIST_ASIGNACION_TIPO  INT = NULL,
@ACTIVO_TIPO                INT = NULL,
@CODIGO                     NVARCHAR(50) = NULL,
@NOMBRE                     NVARCHAR(200) = NULL,
@DESCRIPCION                NVARCHAR(MAX) = NULL,
@HABILITADO                 BIT = NULL,
@USUARIO                    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente, excluyendo el propio registro.
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla]
                    WHERE cpl_cliente = @CLIENTE AND cpl_codigo = @CODIGO AND cpl_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA PLANTILLA CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta, si se indica, tiene que ser del mismo cliente.
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Checklist_Plantilla]
    SET     cpl_cliente_instalacion       = @CLIENTE_INSTALACION
           ,cpl_checklist_asignacion_tipo = @CHECKLIST_ASIGNACION_TIPO
           ,cpl_activo_tipo               = @ACTIVO_TIPO
           ,cpl_codigo                    = ISNULL(@CODIGO, cpl_codigo)
           ,cpl_nombre                    = ISNULL(@NOMBRE, cpl_nombre)
           ,cpl_descripcion               = @DESCRIPCION
           ,cpl_habilitado                = ISNULL(@HABILITADO, cpl_habilitado)
           ,cpl_usuario_actualizacion     = @USUARIO
           ,cpl_fecha_actualizacion       = @DATE_NOW
    WHERE   cpl_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CHECKLIST_PLANTILLA @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA PLANTILLA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-4071 - DEL_CHECKLIST_PLANTILLA
      Baja LOGICA, no fisica. Una plantilla tiene versiones publicadas que
      pueden estar en uso; no se tira. Rechaza con un mensaje claro si tiene
      versiones colgando, en vez de dejarlas huerfanas.

      La baja marca cpl_habilitado = 0. @USUARIO obligatorio para la auditoria.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_CHECKLIST_PLANTILLA]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN
    -- Solo las versiones PUBLICADAS (estado 2) son dependientes reales: pueden
    -- estar en uso. Un BORRADOR (estado 1) es un draft descartable y no bloquea.
    IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version]
                WHERE cpv_checklist_plantilla = @ID AND cpv_checklist_version_estado = 2)
    BEGIN
        RAISERROR('2.- LA PLANTILLA TIENE VERSIONES PUBLICADAS Y NO SE PUEDE DAR DE BAJA.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Checklist_Plantilla]
    SET     cpl_habilitado            = 0
           ,cpl_usuario_actualizacion = @USUARIO
           ,cpl_fecha_actualizacion   = @DATE_NOW
    WHERE   cpl_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_CHECKLIST_PLANTILLA ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE DAR DE BAJA LA PLANTILLA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   LOOKUP PARA EL COMBO DE LA FICHA
      La ficha ofrece el "tipo de asignacion" (a quien se asigna el checklist).
      El estandar prohibe escribir el catalogo a mano en el .aspx: se lee de su
      SEL_. No existia, se crea aqui. Los tipos de activo y las plantas ya
      tienen su SEL_ (SEL_ACTIVO_TIPO, SEL_CLIENTE_INSTALACION).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ASIGNACION_TIPO]
@ID          INT = NULL,
@HABILITADO  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  cat.cat_id         AS CAT_ID
           ,cat.cat_codigo     AS CAT_CODIGO
           ,cat.cat_nombre     AS CAT_NOMBRE
           ,cat.cat_habilitado AS CAT_HABILITADO
    FROM    [dbo].[Checklist_Asignacion_Tipo] cat
    WHERE   (@ID IS NULL OR cat.cat_id = @ID)
      AND   (@HABILITADO IS NULL OR cat.cat_habilitado = @HABILITADO)
    ORDER BY cat.cat_nombre
GO


PRINT '189_SPRINT4_CHECKLIST_PLANTILLA aplicado: modelo revisado, SEL/INS/UPD/DEL_CHECKLIST_PLANTILLA y lookup.'
GO
