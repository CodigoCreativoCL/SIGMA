USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     HITOS DE UN PLAN DE MANTENIMIENTO: SP, MENU Y PERMISOS (HU-081).
-- =============================================
-- T-4018 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento_Hito` existe con sus cinco FK y con
--   `UX_PMH_VERSION_CODIGO` unico sobre (version, codigo): el codigo del hito
--   es unico DENTRO DE LA VERSION, no dentro del cliente. Tiene sentido: dos
--   versiones del mismo plan van a tener un hito «LUB-500» cada una, y el
--   plan de la linea 2 puede tener el suyo. La tarea decia «unico dentro del
--   cliente» porque la plantilla de tareas lo dice de todos; aca lo que manda
--   es el indice, y el SP valida contra ese.
--
--   Tambien trae CK_PMH_ORDEN (orden >= 1) y CK_PMH_DURACION (nula o > 0).
--   No se duplican en el SP: los mensajes del CHECK no se entienden, asi que
--   el SP los traduce ANTES, pero la regla vive en la tabla.
--
-- SOLO SE ESCRIBE SOBRE UN BORRADOR
--
--   El hito cuelga de la version, y una version publicada ya esta generando
--   mantenciones: cambiarle un hito por debajo es cambiar lo que se
--   comprometio. INS y UPD rechazan si la version no esta en BORRADOR. Para
--   modificar un plan publicado hay que sacar una version nueva, que es
--   HU-084 y no esta en este script.
--
-- EL HITO SE CREA CONTRA EL PLAN, NO CONTRA LA VERSION
--
--   La ficha manda @PLAN. El SP busca la version en borrador de ese plan y le
--   cuelga el hito. Pedirle al usuario que elija la version seria pedirle
--   que entienda una tabla intermedia que existe por trazabilidad, no por
--   el.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_HITO — la grilla y la ficha con un solo SP
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_HITO]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@PLAN        INT = NULL,
@VERSION     INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT pmh.pmh_id                          AS PMH_ID
                                  ,pmh.pmh_plan_mantenimiento_version  AS PMH_PLAN_MANTENIMIENTO_VERSION
                                  ,pmh.pmh_programacion                AS PMH_PROGRAMACION
                                  ,pmh.pmh_codigo                      AS PMH_CODIGO
                                  ,pmh.pmh_nombre                      AS PMH_NOMBRE
                                  ,pmh.pmh_orden                       AS PMH_ORDEN
                                  ,pmh.pmh_valor_medidor               AS PMH_VALOR_MEDIDOR
                                  ,pmh.pmh_unidad_medida               AS PMH_UNIDAD_MEDIDA
                                  ,pmh.pmh_es_overhaul                 AS PMH_ES_OVERHAUL
                                  ,pmh.pmh_requiere_parada             AS PMH_REQUIERE_PARADA
                                  ,pmh.pmh_duracion_estimada_minuto    AS PMH_DURACION_ESTIMADA_MINUTO
                                  ,pmh.pmh_orden_trabajo_tipo          AS PMH_ORDEN_TRABAJO_TIPO
                                  ,pmh.pmh_orden_trabajo_prioridad     AS PMH_ORDEN_TRABAJO_PRIORIDAD
                                  ,pmh.pmh_descripcion                 AS PMH_DESCRIPCION
                                  ,pmh.pmh_usuario_creacion            AS PMH_USUARIO_CREACION
                                  ,pmh.pmh_fecha_creacion              AS PMH_FECHA_CREACION
                                  ,pmh.pmh_usuario_actualizacion       AS PMH_USUARIO_ACTUALIZACION
                                  ,pmh.pmh_fecha_actualizacion         AS PMH_FECHA_ACTUALIZACION
                                  ,pmh.pmh_habilitado                  AS PMH_HABILITADO
                                  ,pma.pma_id                          AS PLAN_ID
                                  ,pma.pma_cliente                     AS PLAN_CLIENTE
                                  ,pma.pma_codigo                      AS PLAN_CODIGO
                                  ,pma.pma_nombre                      AS PLAN_NOMBRE
                                  ,pmv.pmv_numero                      AS VERSION_NUMERO
                                  ,pve.pve_codigo                      AS VERSION_ESTADO_CODIGO
                                  ,pve.pve_nombre                      AS VERSION_ESTADO_NOMBRE
                                  ,pro.pro_nombre                      AS PROGRAMACION_NOMBRE
                                  ,pti.pti_nombre                      AS PROGRAMACION_TIPO_NOMBRE
                                  ,ume.ume_simbolo                     AS UNIDAD_SIMBOLO
                                  ,ott.ott_nombre                      AS OT_TIPO_NOMBRE
                                  ,opr.opr_nombre                      AS OT_PRIORIDAD_NOMBRE
                                  ,ISNULL(act.cuantas, 0)              AS ACTIVIDADES
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Plan_Mantenimiento_Hito] pmh
                  INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
                  INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
                  LEFT  JOIN [dbo].[Plan_Version_Estado]        pve ON pve.pve_id = pmv.pmv_plan_version_estado
                  LEFT  JOIN [dbo].[Programacion]               pro ON pro.pro_id = pmh.pmh_programacion
                  LEFT  JOIN [dbo].[Programacion_Tipo]          pti ON pti.pti_id = pro.pro_programacion_tipo
                  LEFT  JOIN [dbo].[Unidad_Medida]              ume ON ume.ume_id = pmh.pmh_unidad_medida
                  LEFT  JOIN [dbo].[Orden_Trabajo_Tipo]         ott ON ott.ott_id = pmh.pmh_orden_trabajo_tipo
                  LEFT  JOIN [dbo].[Orden_Trabajo_Prioridad]    opr ON opr.opr_id = pmh.pmh_orden_trabajo_prioridad
                  LEFT  JOIN [dbo].[Usuario]                    uc  ON uc.usu_id  = pmh.pmh_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]                    ua  ON ua.usu_id  = pmh.pmh_usuario_actualizacion
                  OUTER APPLY (SELECT COUNT(*) AS cuantas FROM [dbo].[Plan_Mantenimiento_Actividad] a
                               WHERE  a.paa_plan_mantenimiento_hito = pmh.pmh_id AND a.paa_habilitado = 1) act
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)         SET @WHERE = @WHERE + ' AND pmh.pmh_id = ' + LTRIM(@ID)
    -- El cliente se filtra a traves del plan: el hito no lleva cliente, y
    -- llevarlo seria repetir un dato que ya esta dos tablas mas arriba.
    IF (@CLIENTE IS NOT NULL)    SET @WHERE = @WHERE + ' AND pma.pma_cliente = ' + LTRIM(@CLIENTE)
    IF (@PLAN IS NOT NULL)       SET @WHERE = @WHERE + ' AND pma.pma_id = ' + LTRIM(@PLAN)
    IF (@VERSION IS NOT NULL)    SET @WHERE = @WHERE + ' AND pmv.pmv_id = ' + LTRIM(@VERSION)
    IF (@HABILITADO IS NOT NULL) SET @WHERE = @WHERE + ' AND pmh.pmh_habilitado = ' + LTRIM(@HABILITADO)

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (pmh.pmh_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pmh.pmh_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pma.pma_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pma.pma_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pro.pro_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    /* Por plan, version y ORDEN: el orden es lo que el planificador definio
       como secuencia de la mantencion, y una grilla que lo ignora obliga a
       leer la columna para reconstruirla. */
    SET @WHERE = @WHERE + ' ORDER BY pma.pma_codigo, pmv.pmv_numero DESC, pmh.pmh_orden, pmh.pmh_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_HITO — sobre el borrador del plan
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_HITO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@PLAN                INT,
@PROGRAMACION        INT,
@CODIGO              NVARCHAR(100),
@NOMBRE              NVARCHAR(400),
@ORDEN               INT = NULL,
@VALOR_MEDIDOR       DECIMAL(18,4) = NULL,
@UNIDAD_MEDIDA       INT = NULL,
@ES_OVERHAUL         BIT = 0,
@REQUIERE_PARADA     BIT = 0,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@ORDEN_TRABAJO_TIPO  INT = NULL,
@ORDEN_TRABAJO_PRIORIDAD INT = NULL,
@DESCRIPCION         NVARCHAR(1000) = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento]
                    WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL PLAN NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* LA VERSION EN BORRADOR, O NADA

       La mas nueva en estado 1. Si el plan no tiene ninguna -esta publicado
       y no se abrio version nueva- no hay donde escribir, y el mensaje dice
       que hacer. */
    SELECT TOP 1 @VERSION = pmv_id
    FROM   [dbo].[Plan_Mantenimiento_Version]
    WHERE  pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1
    ORDER BY pmv_numero DESC

    IF @VERSION IS NULL
    BEGIN
        RAISERROR('2.- EL PLAN NO TIENE UNA VERSIÓN EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICAR SUS HITOS.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR @CODIGO = N'')
    BEGIN
        RAISERROR('3.- INDIQUE EL CÓDIGO DEL HITO.', 16, 1)
        RETURN -1
    END

    IF (@NOMBRE IS NULL OR @NOMBRE = N'')
    BEGIN
        RAISERROR('4.- INDIQUE EL NOMBRE DEL HITO.', 16, 1)
        RETURN -1
    END

    -- Unico dentro de la version: lo garantiza UX_PMH_VERSION_CODIGO, y
    -- aca se dice con palabras que codigo choco.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @CODIGO)
    BEGIN
        RAISERROR('5.- YA EXISTE UN HITO CON EL CÓDIGO "%s" EN ESTA VERSIÓN DEL PLAN.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                    WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
    BEGIN
        RAISERROR('6.- LA PROGRAMACIÓN NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- Las reglas de los CHECK, dichas con palabras antes de que rebote la tabla.
    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('7.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    -- Sin orden, va al final: el planificador rara vez lo escribe a mano.
    IF (@ORDEN IS NULL OR @ORDEN < 1)
        SELECT @ORDEN = ISNULL(MAX(pmh_orden), 0) + 1
        FROM   [dbo].[Plan_Mantenimiento_Hito]
        WHERE  pmh_plan_mantenimiento_version = @VERSION
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Hito]
        (
            pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden,
            pmh_valor_medidor, pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada,
            pmh_duracion_estimada_minuto, pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad,
            pmh_descripcion,
            pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion,
            pmh_habilitado
        )
    VALUES
        (
            @VERSION, @PROGRAMACION, @CODIGO, @NOMBRE, @ORDEN,
            @VALOR_MEDIDOR, @UNIDAD_MEDIDA, ISNULL(@ES_OVERHAUL, 0), ISNULL(@REQUIERE_PARADA, 0),
            @DURACION_ESTIMADA_MINUTO, @ORDEN_TRABAJO_TIPO, @ORDEN_TRABAJO_PRIORIDAD,
            @DESCRIPCION,
            @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW,
            1
        )

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_HITO @PLAN = ' + LTRIM(STR(@PLAN)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '8.- NO FUE POSIBLE INSERTAR EL HITO.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_HITO
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_HITO]
@ID                  INT,
@PROGRAMACION        INT = NULL,
@CODIGO              NVARCHAR(100) = NULL,
@NOMBRE              NVARCHAR(400) = NULL,
@ORDEN               INT = NULL,
@VALOR_MEDIDOR       DECIMAL(18,4) = NULL,
@UNIDAD_MEDIDA       INT = NULL,
@ES_OVERHAUL         BIT = NULL,
@REQUIERE_PARADA     BIT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@ORDEN_TRABAJO_TIPO  INT = NULL,
@ORDEN_TRABAJO_PRIORIDAD INT = NULL,
@DESCRIPCION         NVARCHAR(1000) = NULL,
@HABILITADO          BIT = NULL,
@QUITA_MEDIDOR       BIT = 0,
@QUITA_OT_TIPO       BIT = 0,
@QUITA_OT_PRIORIDAD  BIT = 0,
@QUITA_DURACION      BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @VERSION INT, @ESTADO INT

SELECT @VERSION = pmh_plan_mantenimiento_version FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @ID

IF @VERSION IS NULL
BEGIN
    RAISERROR('1.- EL HITO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @CLIENTE = pma.pma_cliente, @ESTADO = pmv.pmv_plan_version_estado
FROM   [dbo].[Plan_Mantenimiento_Version] pmv
INNER JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
WHERE  pmv.pmv_id = @VERSION

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
IF @NOMBRE IS NOT NULL SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTE HITO YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLO.', 16, 1)
        RETURN -1
    END

    IF @NOMBRE IS NOT NULL AND @NOMBRE = N''
    BEGIN
        RAISERROR('3.- INDIQUE EL NOMBRE DEL HITO.', 16, 1)
        RETURN -1
    END

    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                    WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @CODIGO AND pmh_id <> @ID)
    BEGIN
        RAISERROR('4.- YA EXISTE UN HITO CON EL CÓDIGO "%s" EN ESTA VERSIÓN DEL PLAN.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @PROGRAMACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                        WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
    BEGIN
        RAISERROR('5.- LA PROGRAMACIÓN NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('6.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    IF (@ORDEN IS NOT NULL AND @ORDEN < 1)
    BEGIN
        RAISERROR('7.- EL ORDEN DEBE SER 1 O MAYOR.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento_Hito]
    SET     pmh_programacion             = ISNULL(@PROGRAMACION, pmh_programacion)
           ,pmh_codigo                   = ISNULL(@CODIGO, pmh_codigo)
           ,pmh_nombre                   = ISNULL(@NOMBRE, pmh_nombre)
           ,pmh_orden                    = ISNULL(@ORDEN, pmh_orden)
           ,pmh_valor_medidor            = CASE WHEN @QUITA_MEDIDOR = 1 THEN NULL ELSE ISNULL(@VALOR_MEDIDOR, pmh_valor_medidor) END
           ,pmh_unidad_medida            = CASE WHEN @QUITA_MEDIDOR = 1 THEN NULL ELSE ISNULL(@UNIDAD_MEDIDA, pmh_unidad_medida) END
           ,pmh_es_overhaul              = ISNULL(@ES_OVERHAUL, pmh_es_overhaul)
           ,pmh_requiere_parada          = ISNULL(@REQUIERE_PARADA, pmh_requiere_parada)
           ,pmh_duracion_estimada_minuto = CASE WHEN @QUITA_DURACION = 1 THEN NULL ELSE ISNULL(@DURACION_ESTIMADA_MINUTO, pmh_duracion_estimada_minuto) END
           ,pmh_orden_trabajo_tipo       = CASE WHEN @QUITA_OT_TIPO = 1 THEN NULL ELSE ISNULL(@ORDEN_TRABAJO_TIPO, pmh_orden_trabajo_tipo) END
           ,pmh_orden_trabajo_prioridad  = CASE WHEN @QUITA_OT_PRIORIDAD = 1 THEN NULL ELSE ISNULL(@ORDEN_TRABAJO_PRIORIDAD, pmh_orden_trabajo_prioridad) END
           ,pmh_descripcion              = ISNULL(@DESCRIPCION, pmh_descripcion)
           ,pmh_habilitado               = ISNULL(@HABILITADO, pmh_habilitado)
           ,pmh_usuario_actualizacion    = @USUARIO
           ,pmh_fecha_actualizacion      = @DATE_NOW
    WHERE   pmh_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_HITO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '8.- NO FUE POSIBLE ACTUALIZAR EL HITO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 4) DEL_PLAN_HITO — baja logica, sin huerfanos
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_HITO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @VERSION INT, @ESTADO INT

SELECT @VERSION = pmh_plan_mantenimiento_version FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @ID

IF @VERSION IS NULL
BEGIN
    RAISERROR('1.- EL HITO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @CLIENTE = pma.pma_cliente, @ESTADO = pmv.pmv_plan_version_estado
FROM   [dbo].[Plan_Mantenimiento_Version] pmv
INNER JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
WHERE  pmv.pmv_id = @VERSION

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTE HITO YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_plan_mantenimiento_hito = @ID)
    BEGIN
        RAISERROR('3.- EL HITO YA GENERÓ MANTENCIONES Y NO SE PUEDE ELIMINAR. DESHABILÍTELO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @ID AND paa_habilitado = 1)
    BEGIN
        RAISERROR('4.- EL HITO TIENE ACTIVIDADES. ELIMÍNELAS PRIMERO O DESHABILITE EL HITO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento_Hito]
    SET     pmh_habilitado            = 0
           ,pmh_usuario_actualizacion = @USUARIO
           ,pmh_fecha_actualizacion   = @DATE_NOW
    WHERE   pmh_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_HITO ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '5.- NO FUE POSIBLE ELIMINAR EL HITO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 5) Menu y funciones (T-4030, T-4031)
-- ---------------------------------------------------------------------------
--
-- Los hitos usan LOS MISMOS permisos que el plan. No son otra cosa: son el
-- contenido del plan, y quien puede editar el plan puede definir que se le
-- hace. Un permiso aparte seria un permiso que siempre se otorga junto con
-- el otro, o sea, ninguno.
DECLARE @VER    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PLANES MANTENIMIENTO')
DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PLANES MANTENIMIENTO')
DECLARE @PADRE  INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')

IF (@PADRE IS NULL OR @VER IS NULL)
BEGIN
    RAISERROR('CORRA BD/212_PLAN_MANTENIMIENTO.sql ANTES QUE ESTE.', 16, 1)
    RETURN
END

-- Inmediatamente despues de Planes: es lo siguiente que se hace.
DECLARE @ORDEN_PLANES INT = (SELECT mnu_orden FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanHitos.aspx')
BEGIN
    -- Se corren los que vengan despues para hacer sitio, sin tocar las fichas (99).
    UPDATE [dbo].[Menus] SET mnu_orden = mnu_orden + 1
    WHERE  mnu_padre = @PADRE AND mnu_orden > @ORDEN_PLANES AND mnu_orden < 99

    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Hitos de plan',
         'Qué se le hace al equipo en cada plan y cada cuánto',
         3, @PADRE, @ORDEN_PLANES + 1,
         '~/View/Mantenimiento/Planes/PlanHitos.aspx', 1,
         'mdi mdi-flag-checkered', @VER, 1)
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanHito.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Hito de plan (detalle)', 'Ficha de un hito',
         3, @PADRE, 99,
         '~/View/Mantenimiento/Planes/PlanHito.aspx', 0, '', @VER, 1)

DECLARE @MENU INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanHitos.aspx')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @MENU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @MENU, @EDITAR)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures
                        WHERE name IN ('SEL_PLAN_HITO','INS_PLAN_HITO','UPD_PLAN_HITO','DEL_PLAN_HITO')) AS VARCHAR) + ' de 4' AS RESULTADO
UNION ALL
SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Planes/PlanHito%') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Funciones = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
                               WHERE m.mnu_link LIKE '%/Planes/PlanHitos.aspx') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Orden del nodo Mantenimiento: ' + STUFF((SELECT ', ' + CAST(mnu_orden AS VARCHAR) + ' ' + mnu_nombre
        FROM [dbo].[Menus] WHERE mnu_padre = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Planes/PlanHitos.aspx')
          AND mnu_orden < 99 ORDER BY mnu_orden FOR XML PATH('')), 1, 2, '')
GO
