USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     SPRINT 2 - HU-035 REGISTRAR UN ACTIVO. MODELO, SEL/INS/UPD/DEL Y LOOKUPS.
-- =============================================
-- Va DESPUES de 73_SALDO_LISTADO_AGRUPADO.
--
-- QUE CUBRE ESTE BLOQUE (tareas del Sprint 2)
--   T-2001  Revision del modelo Activo: columnas, FK e indices. Confirma
--           el indice unico del codigo dentro del cliente.
--   T-2002  SEL_ACTIVO: listado con filtros opcionales y ORDER BY estable.
--           Un solo SP sirve a la grilla y a la ficha.
--   T-2003  INS_ACTIVO: alta en transaccion, codigo unico por cliente,
--           fecha sellada con FNC_PAIS_HORA.
--   T-2004  UPD_ACTIVO: edicion con ISNULL(@X, columna) para no borrar lo
--           que la ficha no muestra.
--   T-2005  DEL_ACTIVO: baja logica que rechaza si hay dependientes.
--
--   Ademas: los SEL_ de los catalogos que pueblan los combos de la ficha
--   (Activo_Tipo, Activo_Estado, Criticidad_Nivel). El estandar prohibe
--   escribir un catalogo a mano en el .aspx: se lee del SEL_. Si no existe,
--   se crea (CHECKLIST_ENTIDAD_NUEVA §4).
--
-- ES IDEMPOTENTE
--   CREATE OR ALTER en los SP; el indice se crea solo si falta.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-2001 - REVISION DEL MODELO Activo
   ------------------------------------------------------------------------
   La tabla Activo se creo en el bloque 11 (11_ACTIVOS_MEDICIONES). Aqui
   NO se recrea: solo se confirma lo que HU-035 necesita.

     - PK           PK_ACTIVO (act_id)
     - Codigo unico POR CLIENTE  ->  UX_ACT_CLIENTE_CODIGO (act_cliente, act_codigo)
     - FK a Cliente, Cliente_Instalacion, Instalacion_Area, Activo_Posicion,
       Activo_Tipo, Activo_Modelo, Activo_Estado, Activo (padre),
       Centro_Costo, Criticidad_Nivel y Registro_Origen.
     - Columnas de auditoria: act_usuario_creacion / act_fecha_creacion /
       act_usuario_actualizacion / act_fecha_actualizacion / act_habilitado.

   El indice unico del codigo dentro del cliente es la regla de negocio del
   escenario 2 de HU-035 ("no puede haber dos activos con el mismo codigo en
   el mismo cliente"). Se garantiza que exista de forma idempotente: si el
   bloque 11 ya lo creo, esto no hace nada; si por algun motivo faltara, lo
   deja. La validacion tambien vive en INS_/UPD_ para devolver un mensaje
   claro en vez del error 2601 crudo del indice.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_ACT_CLIENTE_CODIGO'
                  AND object_id = OBJECT_ID(N'[dbo].[Activo]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACT_CLIENTE_CODIGO
        ON [dbo].[Activo] ([act_cliente], [act_codigo])
    PRINT '--- Indice unico UX_ACT_CLIENTE_CODIGO creado.'
END
ELSE
    PRINT '--- Indice unico UX_ACT_CLIENTE_CODIGO ya existe (creado en el bloque 11). OK.'
GO


/* ========================================================================
   T-2003 - INS_ACTIVO
      Alta de un activo dentro de transaccion. Valida el codigo unico por
      cliente ANTES de la transaccion y sella las fechas con la hora local
      del pais del cliente (FNC_PAIS_HORA), no con GETDATE(): SIGMA opera en
      cinco paises y un activo creado en Panama no puede fecharse con la hora
      de Chile.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CLIENTE_INSTALACION    INT,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT,
@ACTIVO_MODELO          INT = NULL,
@ACTIVO_ESTADO          INT,
@ACTIVO_PADRE           INT = NULL,
@CENTRO_COSTO           INT = NULL,
@CRITICIDAD_NIVEL       INT,
@CODIGO                 NVARCHAR(50),
@NOMBRE                 NVARCHAR(200),
@NUMERO_SERIE           NVARCHAR(100) = NULL,
@FABRICANTE             NVARCHAR(200) = NULL,
@ANIO_FABRICACION       INT = NULL,
@FECHA_PUESTA_MARCHA    DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@REGISTRO_ORIGEN        INT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

-- Origen por defecto: creado en la web (Registro_Origen id 2 = PLANIFICADOR WEB).
SET @REGISTRO_ORIGEN = ISNULL(@REGISTRO_ORIGEN, 2)

BEGIN
    -- Codigo unico por cliente (HU-035 escenario 2).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo]
                WHERE act_cliente = @CLIENTE AND act_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN ACTIVO CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta tiene que ser del mismo cliente: un activo no puede colgar
    -- de la instalacion de otra empresa.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- El activo padre, si se indica, tambien es del mismo cliente.
    IF @ACTIVO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                        WHERE act_id = @ACTIVO_PADRE AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL ACTIVO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo]
        (
            act_cliente,
            act_cliente_instalacion,
            act_instalacion_area,
            act_activo_tipo,
            act_activo_modelo,
            act_activo_estado,
            act_activo_padre,
            act_centro_costo,
            act_criticidad_nivel,
            act_codigo,
            act_nombre,
            act_numero_serie,
            act_fabricante,
            act_anio_fabricacion,
            act_fecha_puesta_marcha,
            act_descripcion,
            act_registro_origen,
            act_usuario_creacion,
            act_fecha_creacion,
            act_usuario_actualizacion,
            act_fecha_actualizacion,
            act_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @INSTALACION_AREA,
            @ACTIVO_TIPO,
            @ACTIVO_MODELO,
            @ACTIVO_ESTADO,
            @ACTIVO_PADRE,
            @CENTRO_COSTO,
            @CRITICIDAD_NIVEL,
            @CODIGO,
            @NOMBRE,
            @NUMERO_SERIE,
            @FABRICANTE,
            @ANIO_FABRICACION,
            @FECHA_PUESTA_MARCHA,
            @DESCRIPCION,
            @REGISTRO_ORIGEN,
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
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2002 - SEL_ACTIVO
      Listado con filtros opcionales (id, texto, habilitado, planta, tipo,
      estado) y ORDER BY estable. El mismo SP sirve la grilla y la ficha
      (@ID) y puebla el combo de "activo padre" (@HABILITADO = 1).

      Devuelve el nombre de cada FK y las cuatro columnas de auditoria con
      el nombre del usuario (LEFT JOIN a Usuario): sin eso la ficha no puede
      mostrar quien creo o edito, que es justo para lo que existen esas
      columnas. Sigue el patron dinamico @SELECT/@FROM/@WHERE de PATRON_SP,
      con el @FILTRO escapado para que un apostrofo no rompa el SP ni abra
      inyeccion.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO]
@ID                     INT = NULL,
@CLIENTE                INT = NULL,
@CLIENTE_INSTALACION    INT = NULL,
@ACTIVO_TIPO            INT = NULL,
@ACTIVO_ESTADO          INT = NULL,
@ACTIVO_PADRE           INT = NULL,
@HABILITADO             BIT = NULL,
@FILTRO                 VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT act.act_id                    AS ACT_ID
                                  ,act.act_cliente                AS ACT_CLIENTE
                                  ,act.act_cliente_instalacion    AS ACT_CLIENTE_INSTALACION
                                  ,act.act_instalacion_area       AS ACT_INSTALACION_AREA
                                  ,act.act_activo_tipo            AS ACT_ACTIVO_TIPO
                                  ,act.act_activo_modelo          AS ACT_ACTIVO_MODELO
                                  ,act.act_activo_estado          AS ACT_ACTIVO_ESTADO
                                  ,act.act_activo_padre           AS ACT_ACTIVO_PADRE
                                  ,act.act_centro_costo           AS ACT_CENTRO_COSTO
                                  ,act.act_criticidad_nivel       AS ACT_CRITICIDAD_NIVEL
                                  ,act.act_codigo                 AS ACT_CODIGO
                                  ,act.act_nombre                 AS ACT_NOMBRE
                                  ,act.act_numero_serie           AS ACT_NUMERO_SERIE
                                  ,act.act_fabricante             AS ACT_FABRICANTE
                                  ,act.act_anio_fabricacion       AS ACT_ANIO_FABRICACION
                                  ,act.act_fecha_puesta_marcha    AS ACT_FECHA_PUESTA_MARCHA
                                  ,act.act_fecha_baja             AS ACT_FECHA_BAJA
                                  ,act.act_descripcion            AS ACT_DESCRIPCION
                                  ,act.act_registro_origen        AS ACT_REGISTRO_ORIGEN
                                  ,act.act_usuario_creacion       AS ACT_USUARIO_CREACION
                                  ,act.act_fecha_creacion         AS ACT_FECHA_CREACION
                                  ,act.act_usuario_actualizacion  AS ACT_USUARIO_ACTUALIZACION
                                  ,act.act_fecha_actualizacion    AS ACT_FECHA_ACTUALIZACION
                                  ,act.act_habilitado             AS ACT_HABILITADO
                                  ,cin.cin_nombre                 AS PLANTA_NOMBRE
                                  ,iar.iar_nombre                 AS AREA_NOMBRE
                                  ,ati.ati_nombre                 AS TIPO_NOMBRE
                                  ,aes.aes_nombre                 AS ESTADO_NOMBRE
                                  ,crn.crn_nombre                 AS CRITICIDAD_NOMBRE
                                  ,cco.cco_nombre                 AS CENTRO_COSTO_NOMBRE
                                  ,pad.act_codigo                 AS PADRE_CODIGO
                                  ,pad.act_nombre                 AS PADRE_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Activo] act
                  INNER JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
                  INNER JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = act.act_activo_tipo
                  INNER JOIN [dbo].[Activo_Estado]       aes ON aes.aes_id = act.act_activo_estado
                  INNER JOIN [dbo].[Criticidad_Nivel]    crn ON crn.crn_id = act.act_criticidad_nivel
                  LEFT  JOIN [dbo].[Instalacion_Area]    iar ON iar.iar_id = act.act_instalacion_area
                  LEFT  JOIN [dbo].[Centro_Costo]        cco ON cco.cco_id = act.act_centro_costo
                  LEFT  JOIN [dbo].[Activo]              pad ON pad.act_id = act.act_activo_padre
                  LEFT  JOIN [dbo].[Usuario]             uc  ON uc.usu_id  = act.act_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]             ua  ON ua.usu_id  = act.act_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@ACTIVO_TIPO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_tipo = ' + LTRIM(@ACTIVO_TIPO)
    END

    IF (@ACTIVO_ESTADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_estado = ' + LTRIM(@ACTIVO_ESTADO)
    END

    IF (@ACTIVO_PADRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_padre = ' + LTRIM(@ACTIVO_PADRE)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_numero_serie LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_fabricante LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    -- ORDER BY estable: el codigo es unico por cliente, asi que dos filas
    -- nunca empatan y el orden no baila entre ejecuciones.
    SET @WHERE = @WHERE + ' ORDER BY act.act_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   T-2004 - UPD_ACTIVO
      Edicion. @ID y @USUARIO obligatorios; el resto opcional. Los campos
      que la ficha SI muestra y que pueden quedar en blanco a proposito
      (area, modelo, centro de costo, padre, serie, fabricante, etc.) se
      asignan directo. Los que la ficha podria no traer se conservan con
      ISNULL(@X, columna) para no borrarlos al guardar. La fecha se sella con
      la hora local del pais del cliente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO]
@ID                     INT,
@CLIENTE_INSTALACION    INT = NULL,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT = NULL,
@ACTIVO_MODELO          INT = NULL,
@ACTIVO_ESTADO          INT = NULL,
@ACTIVO_PADRE           INT = NULL,
@CENTRO_COSTO           INT = NULL,
@CRITICIDAD_NIVEL       INT = NULL,
@CODIGO                 NVARCHAR(50) = NULL,
@NOMBRE                 NVARCHAR(200) = NULL,
@NUMERO_SERIE           NVARCHAR(100) = NULL,
@FABRICANTE             NVARCHAR(200) = NULL,
@ANIO_FABRICACION       INT = NULL,
@FECHA_PUESTA_MARCHA    DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@HABILITADO             BIT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente, excluyendo el propio registro.
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo]
                    WHERE act_cliente = @CLIENTE AND act_codigo = @CODIGO AND act_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN ACTIVO CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Un activo no puede ser su propio padre.
    IF @ACTIVO_PADRE IS NOT NULL AND @ACTIVO_PADRE = @ID
    BEGIN
        RAISERROR('3.- UN ACTIVO NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
        RETURN -1
    END

    IF @ACTIVO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                        WHERE act_id = @ACTIVO_PADRE AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- EL ACTIVO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo]
    SET     act_cliente_instalacion   = ISNULL(@CLIENTE_INSTALACION, act_cliente_instalacion)
           ,act_instalacion_area      = @INSTALACION_AREA
           ,act_activo_tipo           = ISNULL(@ACTIVO_TIPO, act_activo_tipo)
           ,act_activo_modelo         = @ACTIVO_MODELO
           ,act_activo_estado         = ISNULL(@ACTIVO_ESTADO, act_activo_estado)
           ,act_activo_padre          = @ACTIVO_PADRE
           ,act_centro_costo          = @CENTRO_COSTO
           ,act_criticidad_nivel      = ISNULL(@CRITICIDAD_NIVEL, act_criticidad_nivel)
           ,act_codigo                = ISNULL(@CODIGO, act_codigo)
           ,act_nombre                = ISNULL(@NOMBRE, act_nombre)
           ,act_numero_serie          = @NUMERO_SERIE
           ,act_fabricante            = @FABRICANTE
           ,act_anio_fabricacion      = @ANIO_FABRICACION
           ,act_fecha_puesta_marcha   = @FECHA_PUESTA_MARCHA
           ,act_descripcion           = @DESCRIPCION
           ,act_habilitado            = ISNULL(@HABILITADO, act_habilitado)
           ,act_usuario_actualizacion = @USUARIO
           ,act_fecha_actualizacion   = @DATE_NOW
    WHERE   act_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ACTIVO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2005 - DEL_ACTIVO
      Baja LOGICA, no fisica. Un activo tiene historia (posiciones,
      mediciones, ordenes de trabajo) que no se puede tirar. Rechaza con un
      mensaje claro si tiene subactivos habilitados colgando, en vez de
      dejarlos huerfanos apuntando a un padre que ya no esta.

      La baja marca act_habilitado = 0 y sella act_fecha_baja con la hora
      local del pais. @USUARIO es obligatorio para la auditoria del cambio.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN
    -- Subactivos habilitados: son los dependientes directos. Deshabilitarlos
    -- primero es una decision, no un efecto colateral de bajar el padre.
    IF EXISTS (SELECT 1 FROM [dbo].[Activo]
                WHERE act_activo_padre = @ID AND act_habilitado = 1)
    BEGIN
        RAISERROR('2.- EL ACTIVO TIENE SUBACTIVOS HABILITADOS. DE BAJA PRIMERO SUS DEPENDIENTES.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo]
    SET     act_habilitado            = 0
           ,act_fecha_baja            = CAST(@DATE_NOW AS DATE)
           ,act_usuario_actualizacion = @USUARIO
           ,act_fecha_actualizacion   = @DATE_NOW
    WHERE   act_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_ACTIVO ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE DAR DE BAJA EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   LOOKUPS PARA LOS COMBOS DE LA FICHA
      La ficha del activo tiene combos obligatorios (tipo, estado,
      criticidad). El estandar prohibe escribir el catalogo a mano en el
      .aspx: se lee de su SEL_. Ninguno existia, asi que se crean aqui.

      Activo_Tipo es por cliente (ati_cliente NULL = tipo global de SIGMA):
      el SEL devuelve los del cliente MAS los globales. Activo_Estado y
      Criticidad_Nivel son catalogos globales, sin cliente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_TIPO]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@HABILITADO  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  ati.ati_id                AS ATI_ID
           ,ati.ati_cliente           AS ATI_CLIENTE
           ,ati.ati_activo_tipo_padre AS ATI_ACTIVO_TIPO_PADRE
           ,ati.ati_codigo            AS ATI_CODIGO
           ,ati.ati_nombre            AS ATI_NOMBRE
           ,ati.ati_descripcion       AS ATI_DESCRIPCION
           ,ati.ati_habilitado        AS ATI_HABILITADO
    FROM    [dbo].[Activo_Tipo] ati
    WHERE   (@ID IS NULL OR ati.ati_id = @ID)
      -- Los globales (ati_cliente NULL) valen para todos; ademas los del
      -- cliente pedido.
      AND   (@CLIENTE IS NULL OR ati.ati_cliente = @CLIENTE OR ati.ati_cliente IS NULL)
      AND   (@HABILITADO IS NULL OR ati.ati_habilitado = @HABILITADO)
    ORDER BY ati.ati_nombre
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ESTADO]
@ID          INT = NULL,
@HABILITADO  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  aes.aes_id         AS AES_ID
           ,aes.aes_codigo     AS AES_CODIGO
           ,aes.aes_nombre     AS AES_NOMBRE
           ,aes.aes_icono      AS AES_ICONO
           ,aes.aes_orden      AS AES_ORDEN
           ,aes.aes_habilitado AS AES_HABILITADO
    FROM    [dbo].[Activo_Estado] aes
    WHERE   (@ID IS NULL OR aes.aes_id = @ID)
      AND   (@HABILITADO IS NULL OR aes.aes_habilitado = @HABILITADO)
    ORDER BY aes.aes_orden, aes.aes_nombre
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_CRITICIDAD_NIVEL]
@ID          INT = NULL,
@HABILITADO  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  crn.crn_id         AS CRN_ID
           ,crn.crn_codigo     AS CRN_CODIGO
           ,crn.crn_nombre     AS CRN_NOMBRE
           ,crn.crn_icono      AS CRN_ICONO
           ,crn.crn_orden      AS CRN_ORDEN
           ,crn.crn_habilitado AS CRN_HABILITADO
    FROM    [dbo].[Criticidad_Nivel] crn
    WHERE   (@ID IS NULL OR crn.crn_id = @ID)
      AND   (@HABILITADO IS NULL OR crn.crn_habilitado = @HABILITADO)
    ORDER BY crn.crn_orden, crn.crn_nombre
GO


PRINT '74_SPRINT2_ACTIVO aplicado: modelo revisado, SEL/INS/UPD/DEL_ACTIVO y lookups.'
GO
