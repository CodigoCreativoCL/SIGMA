USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     PLAN DE MANTENIMIENTO: SP, CODIGO, MENU Y PERMISOS (HU-080).
-- =============================================
-- T-4001 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento` ya existe con sus FK y con `UX_PMA_CLIENTE_CODIGO`
--   unico sobre (cliente, codigo): el codigo es unico DENTRO del cliente, que
--   es lo que pedia la tarea confirmar. No se toca ninguna columna.
--
--   Lo que si hay que saber para escribir estos SP: el plan NO cuelga sus
--   hitos ni sus activos directamente. Entre medio esta
--   `Plan_Mantenimiento_Version` (BORRADOR / PUBLICADO / RETIRADO, HU-084), y
--   los hitos y los activos cuelgan de la VERSION. Un plan sin version es un
--   plan al que no se le puede definir nada.
--
-- POR ESO EL INS CREA LA VERSION 1
--
--   En la misma transaccion. Si el plan naciera solo, la primera pantalla que
--   abriera el planificador despues -la de hitos- no tendria donde escribir,
--   y tendria que existir un boton «crear version» que nadie sabe que hay que
--   apretar antes. Un plan nuevo nace con su borrador, como un documento nace
--   con su primera pagina.
--
-- LA BAJA ES LOGICA, Y RECHAZA SI HAY HUERFANOS POSIBLES
--
--   `DEL_` pone `pma_habilitado = 0`. No borra: un plan que ya genero
--   ocurrencias es historia de mantencion, y borrarla deja ordenes de trabajo
--   apuntando a la nada. Si alguna de sus versiones tiene ocurrencias, el SP
--   rechaza con mensaje y le dice al usuario que lo deshabilite... que es lo
--   mismo que hace este SP cuando NO hay ocurrencias. La diferencia es de
--   intencion: con ocurrencias, quien «elimina» tiene que saber que esta
--   escondiendo historia, no borrando un borrador.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 0) El prefijo del codigo automatico
-- ---------------------------------------------------------------------------
--
-- Como todo maestro del sitio: quien crea puede escribir el sufijo, y si lo
-- deja vacio el SP numera solo (PMA-<id>). El prefijo lo lee la ficha de esta
-- tabla, no lo tiene escrito en el .aspx.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Plan_Mantenimiento')
BEGIN
    INSERT INTO [dbo].[Modulo_Codigo]
        (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento, mco_habilitado)
    VALUES
        ('Plan_Mantenimiento', 'PMA', 'pma_codigo', 'pma_id', 'INS_PLAN_MANTENIMIENTO', 1)
END
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_MANTENIMIENTO — la grilla y la ficha con un solo SP
-- ---------------------------------------------------------------------------
--
-- Devuelve las cuatro columnas de auditoria CON el nombre de la persona: una
-- auditoria que solo se puede leer con acceso a la base no sirve para lo que
-- se hizo. Y trae la version vigente resuelta -numero y estado- porque es lo
-- primero que se pregunta de un plan: ¿esta publicado o es un borrador?
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_MANTENIMIENTO]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@INSTALACION INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT pma.pma_id                    AS PMA_ID
                                  ,pma.pma_cliente               AS PMA_CLIENTE
                                  ,pma.pma_cliente_instalacion   AS PMA_CLIENTE_INSTALACION
                                  ,pma.pma_codigo                AS PMA_CODIGO
                                  ,pma.pma_nombre                AS PMA_NOMBRE
                                  ,pma.pma_descripcion           AS PMA_DESCRIPCION
                                  ,pma.pma_usuario_planificador  AS PMA_USUARIO_PLANIFICADOR
                                  ,pma.pma_activo_tipo           AS PMA_ACTIVO_TIPO
                                  ,pma.pma_activo_modelo         AS PMA_ACTIVO_MODELO
                                  ,pma.pma_usuario_creacion      AS PMA_USUARIO_CREACION
                                  ,pma.pma_fecha_creacion        AS PMA_FECHA_CREACION
                                  ,pma.pma_usuario_actualizacion AS PMA_USUARIO_ACTUALIZACION
                                  ,pma.pma_fecha_actualizacion   AS PMA_FECHA_ACTUALIZACION
                                  ,pma.pma_habilitado            AS PMA_HABILITADO
                                  ,cin.cin_nombre                AS PLANTA_NOMBRE
                                  ,ati.ati_nombre                AS TIPO_NOMBRE
                                  ,amo.amo_nombre                AS MODELO_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(pla.usu_nombre,'''') + '' '' + ISNULL(pla.usu_apellido_paterno,''''))) AS PLANIFICADOR_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''')  + '' '' + ISNULL(uc.usu_apellido_paterno,'''')))  AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''')  + '' '' + ISNULL(ua.usu_apellido_paterno,'''')))  AS USUARIO_ACTUALIZACION_NOMBRE
                                  ,ver.pmv_id                    AS VERSION_ID
                                  ,ver.pmv_numero                AS VERSION_NUMERO
                                  ,pve.pve_codigo                AS VERSION_ESTADO_CODIGO
                                  ,pve.pve_nombre                AS VERSION_ESTADO_NOMBRE
                                  ,ISNULL(hit.cuantos, 0)        AS HITOS
                                  ,ISNULL(acs.cuantos, 0)        AS ACTIVOS
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Plan_Mantenimiento] pma
                  LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = pma.pma_cliente_instalacion
                  LEFT JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = pma.pma_activo_tipo
                  LEFT JOIN [dbo].[Activo_Modelo]       amo ON amo.amo_id = pma.pma_activo_modelo
                  LEFT JOIN [dbo].[Usuario]             pla ON pla.usu_id = pma.pma_usuario_planificador
                  LEFT JOIN [dbo].[Usuario]             uc  ON uc.usu_id  = pma.pma_usuario_creacion
                  LEFT JOIN [dbo].[Usuario]             ua  ON ua.usu_id  = pma.pma_usuario_actualizacion
                  /* LA VERSION QUE MANDA

                     La publicada, si hay una; si no, la ultima. Es la que ve
                     el planificador al abrir el plan y sobre la que se cuenta
                     cuantos hitos y activos tiene. */
                  OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero, v.pmv_plan_version_estado
                               FROM   [dbo].[Plan_Mantenimiento_Version] v
                               WHERE  v.pmv_plan_mantenimiento = pma.pma_id
                                 AND  v.pmv_habilitado = 1
                               ORDER BY CASE WHEN v.pmv_plan_version_estado = 2 THEN 0 ELSE 1 END,
                                        v.pmv_numero DESC) ver
                  LEFT JOIN [dbo].[Plan_Version_Estado] pve ON pve.pve_id = ver.pmv_plan_version_estado
                  OUTER APPLY (SELECT COUNT(*) AS cuantos FROM [dbo].[Plan_Mantenimiento_Hito] h
                               WHERE  h.pmh_plan_mantenimiento_version = ver.pmv_id AND h.pmh_habilitado = 1) hit
                  OUTER APPLY (SELECT COUNT(*) AS cuantos FROM [dbo].[Plan_Mantenimiento_Activo] a
                               WHERE  a.pac_plan_mantenimiento_version = ver.pmv_id) acs
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)          SET @WHERE = @WHERE + ' AND pma.pma_id = ' + LTRIM(@ID)
    IF (@CLIENTE IS NOT NULL)     SET @WHERE = @WHERE + ' AND pma.pma_cliente = ' + LTRIM(@CLIENTE)
    IF (@INSTALACION IS NOT NULL) SET @WHERE = @WHERE + ' AND pma.pma_cliente_instalacion = ' + LTRIM(@INSTALACION)
    IF (@HABILITADO IS NOT NULL)  SET @WHERE = @WHERE + ' AND pma.pma_habilitado = ' + LTRIM(@HABILITADO)

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (pma.pma_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pma.pma_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cin.cin_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ati.ati_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    -- Estable: por codigo, que es unico dentro del cliente.
    SET @WHERE = @WHERE + ' ORDER BY pma.pma_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_MANTENIMIENTO — el plan y su primera version, juntos
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_MANTENIMIENTO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@CLIENTE_INSTALACION INT = NULL,
@CODIGO              NVARCHAR(100),
@NOMBRE              NVARCHAR(400),
@DESCRIPCION         NVARCHAR(MAX) = NULL,
@USUARIO_PLANIFICADOR INT = NULL,
@ACTIVO_TIPO         INT = NULL,
@ACTIVO_MODELO       INT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF (@NOMBRE IS NULL OR @NOMBRE = N'')
    BEGIN
        RAISERROR('1.- INDIQUE EL NOMBRE DEL PLAN.', 16, 1)
        RETURN -1
    END

    -- Codigo unico por cliente: lo garantiza UX_PMA_CLIENTE_CODIGO, pero un
    -- mensaje propio dice QUE codigo choco en vez del nombre del indice.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento]
                WHERE pma_cliente = @CLIENTE AND pma_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UN PLAN CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Lo que se referencia tiene que ser de este cliente. Sin esto, un id
    -- ajeno escrito en el querystring colgaria el plan de la planta de otra
    -- empresa.
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @ACTIVO_MODELO IS NOT NULL AND @ACTIVO_TIPO IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo]
                        WHERE amo_id = @ACTIVO_MODELO AND amo_activo_tipo = @ACTIVO_TIPO)
    BEGIN
        RAISERROR('4.- EL MODELO NO ES DEL TIPO DE ACTIVO INDICADO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento]
        (
            pma_cliente,
            pma_cliente_instalacion,
            pma_codigo,
            pma_nombre,
            pma_descripcion,
            pma_usuario_planificador,
            pma_activo_tipo,
            pma_activo_modelo,
            pma_usuario_creacion,
            pma_fecha_creacion,
            pma_usuario_actualizacion,
            pma_fecha_actualizacion,
            pma_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
            @USUARIO_PLANIFICADOR,
            @ACTIVO_TIPO,
            @ACTIVO_MODELO,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea. La ficha
       manda 'AUTO': satisface el NOT NULL, pasa por el INSERT y nunca queda
       guardado. Mismo mecanismo que todos los maestros del sitio. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR @CODIGO = 'AUTO')
        UPDATE [dbo].[Plan_Mantenimiento]
        SET    pma_codigo = [dbo].[FNC_CODIGO_AUTOMATICO]('PMA', @ID)
        WHERE  pma_id = @ID

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_MANTENIMIENTO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
             @MSG = '5.- NO FUE POSIBLE INSERTAR EL PLAN.'
        RETURN -1
    END

    /* ---- LA VERSION 1, EN BORRADOR ----
       Los hitos y los activos cuelgan de la version, no del plan. Sin esta
       fila el plan recien creado no tiene donde recibir su primer hito. */
    INSERT [dbo].[Plan_Mantenimiento_Version]
        (
            pmv_plan_mantenimiento,
            pmv_numero,
            pmv_plan_version_estado,
            pmv_usuario_creacion,
            pmv_fecha_creacion,
            pmv_usuario_actualizacion,
            pmv_fecha_actualizacion,
            pmv_habilitado
        )
    VALUES
        (
            @ID,
            1,
            1,          -- BORRADOR
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_PLAN_MANTENIMIENTO version 1',
             @MSG = '6.- NO FUE POSIBLE CREAR LA PRIMERA VERSIÓN DEL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_MANTENIMIENTO — lo que la ficha no manda, se conserva
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_MANTENIMIENTO]
@ID                  INT,
@CLIENTE_INSTALACION INT = NULL,
@CODIGO              NVARCHAR(100) = NULL,
@NOMBRE              NVARCHAR(400) = NULL,
@DESCRIPCION         NVARCHAR(MAX) = NULL,
@USUARIO_PLANIFICADOR INT = NULL,
@ACTIVO_TIPO         INT = NULL,
@ACTIVO_MODELO       INT = NULL,
@HABILITADO          BIT = NULL,
/* Los combos opcionales: vacio al editar significa «quitalo», no «no lo
   toques». Sin estas banderas, el ISNULL conservaria el valor viejo y el
   cambio se perderia en silencio. Mismo caso que el padre del centro de
   costo. */
@QUITA_INSTALACION   BIT = 0,
@QUITA_PLANIFICADOR  BIT = 0,
@QUITA_TIPO          BIT = 0,
@QUITA_MODELO        BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = pma_cliente FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
IF @NOMBRE IS NOT NULL SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF @NOMBRE IS NOT NULL AND @NOMBRE = N''
    BEGIN
        RAISERROR('2.- INDIQUE EL NOMBRE DEL PLAN.', 16, 1)
        RETURN -1
    END

    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento]
                    WHERE pma_cliente = @CLIENTE AND pma_codigo = @CODIGO AND pma_id <> @ID)
    BEGIN
        RAISERROR('3.- YA EXISTE UN PLAN CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento]
    SET     pma_cliente_instalacion   = CASE WHEN @QUITA_INSTALACION = 1 THEN NULL
                                             ELSE ISNULL(@CLIENTE_INSTALACION, pma_cliente_instalacion) END
           ,pma_codigo                = ISNULL(@CODIGO, pma_codigo)
           ,pma_nombre                = ISNULL(@NOMBRE, pma_nombre)
           ,pma_descripcion           = ISNULL(@DESCRIPCION, pma_descripcion)
           ,pma_usuario_planificador  = CASE WHEN @QUITA_PLANIFICADOR = 1 THEN NULL
                                             ELSE ISNULL(@USUARIO_PLANIFICADOR, pma_usuario_planificador) END
           ,pma_activo_tipo           = CASE WHEN @QUITA_TIPO = 1 THEN NULL
                                             ELSE ISNULL(@ACTIVO_TIPO, pma_activo_tipo) END
           ,pma_activo_modelo         = CASE WHEN @QUITA_MODELO = 1 OR @QUITA_TIPO = 1 THEN NULL
                                             ELSE ISNULL(@ACTIVO_MODELO, pma_activo_modelo) END
           ,pma_habilitado            = ISNULL(@HABILITADO, pma_habilitado)
           ,pma_usuario_actualizacion = @USUARIO
           ,pma_fecha_actualizacion   = @DATE_NOW
    WHERE   pma_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_MANTENIMIENTO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
             @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 4) DEL_PLAN_MANTENIMIENTO — baja logica
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_MANTENIMIENTO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = pma_cliente FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    /* Con ocurrencias generadas el plan es historia de mantencion: hay
       ordenes de trabajo que nacieron de el. Se rechaza, y el mensaje dice
       que hacer en vez de solo decir que no. */
    IF EXISTS (SELECT 1
               FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
               INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    h ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
               INNER JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id  = h.pmh_plan_mantenimiento_version
               WHERE  v.pmv_plan_mantenimiento = @ID)
    BEGIN
        RAISERROR('2.- EL PLAN YA GENERÓ MANTENCIONES Y NO SE PUEDE ELIMINAR. RETIRE SU VERSIÓN PUBLICADA Y DESHABILÍTELO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version]
                WHERE pmv_plan_mantenimiento = @ID AND pmv_plan_version_estado = 2)
    BEGIN
        RAISERROR('3.- EL PLAN TIENE UNA VERSIÓN PUBLICADA. RETÍRELA ANTES DE ELIMINARLO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento]
    SET     pma_habilitado            = 0
           ,pma_usuario_actualizacion = @USUARIO
           ,pma_fecha_actualizacion   = @DATE_NOW
    WHERE   pma_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_MANTENIMIENTO ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
             @MSG = '4.- NO FUE POSIBLE ELIMINAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 5) Permisos, menu y funciones (T-4013, T-4014)
-- ---------------------------------------------------------------------------
--
-- La seguridad es por datos: sin fila en Menus la pantalla no se abre, y sin
-- fila en Menu_Funcion el boton «Nuevo» no aparece PARA NADIE, Root incluido.
-- Los permisos copian modulo y ambito de VER PROGRAMACIONES, su hermano.
DECLARE @HOY DATETIME = GETDATE()

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PLANES MANTENIMIENTO')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'VER PLANES MANTENIMIENTO', 'Ver planes de mantenimiento', p.prm_modulo, 1,
           'Consultar los planes de mantenimiento preventivo y sus versiones',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM   [dbo].[Permiso] p WHERE p.prm_codigo = 'VER PROGRAMACIONES'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PLANES MANTENIMIENTO')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'CREAR EDITAR PLANES MANTENIMIENTO', 'Crear y editar planes de mantenimiento', p.prm_modulo, 1,
           'Crear, editar y deshabilitar planes de mantenimiento preventivo',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM   [dbo].[Permiso] p WHERE p.prm_codigo = 'CREAR EDITAR PROGRAMACIONES'

DECLARE @VER    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PLANES MANTENIMIENTO')
DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PLANES MANTENIMIENTO')
DECLARE @VER_PROG    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROGRAMACIONES')
DECLARE @EDITAR_PROG INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROGRAMACIONES')

-- A los mismos perfiles que ya manejan programaciones: son la misma gente.
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @VER, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp
WHERE  pp.ppe_permiso = @VER_PROG
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @VER)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @EDITAR, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp
WHERE  pp.ppe_permiso = @EDITAR_PROG
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @EDITAR)

-- El nodo Mantenimiento, donde ya viven Programaciones y Procedimientos.
DECLARE @PADRE INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Programaciones/Programaciones.aspx')
SET @PADRE = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_id = @PADRE)

IF (@PADRE IS NULL)
BEGIN
    RAISERROR('NO SE ENCONTRO EL NODO MANTENIMIENTO DEL MENU.', 16, 1)
    RETURN
END

/* EL ORDEN LO DICTA LA DEPENDENCIA

   Un hito del plan apunta a una programacion y una actividad a un
   procedimiento. Quien entra por primera vez tiene que haber pasado por esas
   dos pantallas ANTES de poder armar un plan, asi que Planes va despues de
   ellas y no arriba, aunque sea la pantalla mas importante del modulo. */
DECLARE @ORDEN INT = ISNULL((SELECT MAX(ISNULL(mnu_orden, 0)) FROM [dbo].[Menus]
                              WHERE mnu_padre = @PADRE AND mnu_orden < 99), 0) + 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Planes de mantenimiento',
         'Los planes preventivos: qué se le hace a cada equipo y cada cuánto',
         3, @PADRE, @ORDEN,
         '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx', 1,
         'mdi mdi-calendar-check-outline', @VER, 1)

-- La ficha: con fila porque sin ella no se abre, pero no es opcion del arbol.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimiento.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Plan de mantenimiento (detalle)', 'Ficha de un plan',
         3, @PADRE, 99,
         '~/View/Mantenimiento/Planes/PlanMantenimiento.aspx', 0, '', @VER, 1)

DECLARE @MENU INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')

-- Las funciones del listado. El nombre es TEXTO y calza con el .aspx.cs.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @MENU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @MENU, @EDITAR)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures
                        WHERE name IN ('SEL_PLAN_MANTENIMIENTO','INS_PLAN_MANTENIMIENTO',
                                       'UPD_PLAN_MANTENIMIENTO','DEL_PLAN_MANTENIMIENTO')) AS VARCHAR) + ' de 4' AS RESULTADO
UNION ALL
SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Planes/PlanMantenimiento%') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Funciones = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
                               WHERE m.mnu_link LIKE '%/Planes/PlanMantenimientos.aspx') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Perfiles con VER = ' + CAST((SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
                                      WHERE p.prm_codigo = 'VER PLANES MANTENIMIENTO') AS VARCHAR)
UNION ALL
SELECT 'Modulo_Codigo = ' + CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Plan_Mantenimiento') THEN 'OK' ELSE 'FALTA' END
GO
