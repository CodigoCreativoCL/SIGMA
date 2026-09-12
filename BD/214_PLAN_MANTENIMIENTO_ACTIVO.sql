USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     ACTIVOS DE UN PLAN DE MANTENIMIENTO: SP, MENU Y PERMISOS (HU-083).
-- =============================================
-- T-4094 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento_Activo` es una tabla de VINCULO: version + activo, y
--   opcionalmente el componente y el medidor sobre el que se aplica. No tiene
--   `habilitado` ni auditoria de actualizacion, solo de creacion. Dos indices
--   unicos filtrados garantizan que un activo no este dos veces en la misma
--   version (con o sin componente).
--
--   Eso decide dos cosas que la plantilla de tareas no sabia:
--
--   - `DEL_` es FISICO. No hay columna para una baja logica, y el patron dice
--     que el DEL_ existe solo si el borrado es fisico. Un vinculo no es un
--     registro con historia: quitar un equipo de un plan es quitarlo.
--   - `UPD_` solo puede cambiar el componente y el medidor. Cambiar el activo
--     seria quitar uno y poner otro, y eso se hace asi, a la vista.
--
-- EL ACTIVO TIENE QUE CABER EN EL ALCANCE DEL PLAN
--
--   El plan puede acotarse a una planta, a un tipo de activo y a un modelo
--   (HU-080). Esos campos no son decorativos: si el plan es «de hornos de la
--   linea 1», una amasadora de Maipu no puede entrar. El INS lo valida y lo
--   dice con palabras, para que el planificador corrija el plan o elija otro
--   equipo, en vez de dejar pasar un vinculo que despues nadie entiende.
--
-- SOLO SOBRE UN BORRADOR
--
--   Misma regla que los hitos: la version publicada ya genera mantenciones
--   para sus equipos, y agregarle o quitarle uno por debajo cambia lo que se
--   comprometio.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_ACTIVO
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_ACTIVO]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@PLAN        INT = NULL,
@VERSION     INT = NULL,
@ACTIVO      INT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT pac.pac_id                          AS PAC_ID
                                  ,pac.pac_plan_mantenimiento_version  AS PAC_PLAN_MANTENIMIENTO_VERSION
                                  ,pac.pac_activo                      AS PAC_ACTIVO
                                  ,pac.pac_activo_componente           AS PAC_ACTIVO_COMPONENTE
                                  ,pac.pac_activo_medidor              AS PAC_ACTIVO_MEDIDOR
                                  ,pac.pac_usuario_creacion            AS PAC_USUARIO_CREACION
                                  ,pac.pac_fecha_creacion              AS PAC_FECHA_CREACION
                                  ,pma.pma_id                          AS PLAN_ID
                                  ,pma.pma_cliente                     AS PLAN_CLIENTE
                                  ,pma.pma_codigo                      AS PLAN_CODIGO
                                  ,pma.pma_nombre                      AS PLAN_NOMBRE
                                  ,pmv.pmv_numero                      AS VERSION_NUMERO
                                  ,pve.pve_codigo                      AS VERSION_ESTADO_CODIGO
                                  ,pve.pve_nombre                      AS VERSION_ESTADO_NOMBRE
                                  ,act.act_codigo                      AS ACTIVO_CODIGO
                                  ,act.act_nombre                      AS ACTIVO_NOMBRE
                                  ,cin.cin_nombre                      AS PLANTA_NOMBRE
                                  ,iar.iar_nombre                      AS AREA_NOMBRE
                                  ,ati.ati_nombre                      AS TIPO_NOMBRE
                                  ,aes.aes_nombre                      AS ESTADO_ACTIVO_NOMBRE
                                  ,aco.aco_codigo                      AS COMPONENTE_CODIGO
                                  ,aco.aco_nombre                      AS COMPONENTE_NOMBRE
                                  ,ame.ame_codigo                      AS MEDIDOR_CODIGO
                                  ,ame.ame_nombre                      AS MEDIDOR_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Plan_Mantenimiento_Activo] pac
                  INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pac.pac_plan_mantenimiento_version
                  INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
                  INNER JOIN [dbo].[Activo]                     act ON act.act_id = pac.pac_activo
                  LEFT  JOIN [dbo].[Plan_Version_Estado]        pve ON pve.pve_id = pmv.pmv_plan_version_estado
                  LEFT  JOIN [dbo].[Cliente_Instalacion]        cin ON cin.cin_id = act.act_cliente_instalacion
                  LEFT  JOIN [dbo].[Instalacion_Area]           iar ON iar.iar_id = act.act_instalacion_area
                  LEFT  JOIN [dbo].[Activo_Tipo]                ati ON ati.ati_id = act.act_activo_tipo
                  LEFT  JOIN [dbo].[Activo_Estado]              aes ON aes.aes_id = act.act_activo_estado
                  LEFT  JOIN [dbo].[Activo_Componente]          aco ON aco.aco_id = pac.pac_activo_componente
                  LEFT  JOIN [dbo].[Activo_Medidor]             ame ON ame.ame_id = pac.pac_activo_medidor
                  LEFT  JOIN [dbo].[Usuario]                    uc  ON uc.usu_id  = pac.pac_usuario_creacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)      SET @WHERE = @WHERE + ' AND pac.pac_id = ' + LTRIM(@ID)
    IF (@CLIENTE IS NOT NULL) SET @WHERE = @WHERE + ' AND pma.pma_cliente = ' + LTRIM(@CLIENTE)
    IF (@PLAN IS NOT NULL)    SET @WHERE = @WHERE + ' AND pma.pma_id = ' + LTRIM(@PLAN)
    IF (@VERSION IS NOT NULL) SET @WHERE = @WHERE + ' AND pmv.pmv_id = ' + LTRIM(@VERSION)
    IF (@ACTIVO IS NOT NULL)  SET @WHERE = @WHERE + ' AND pac.pac_activo = ' + LTRIM(@ACTIVO)

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pma.pma_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pma.pma_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR aco.aco_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY pma.pma_codigo, pmv.pmv_numero DESC, act.act_codigo, aco.aco_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_ACTIVO — el activo cabe en el alcance, sobre el borrador
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_ACTIVO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@PLAN                INT,
@ACTIVO              INT,
@ACTIVO_COMPONENTE   INT = NULL,
@ACTIVO_MEDIDOR      INT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT
DECLARE @PLAN_PLANTA INT, @PLAN_TIPO INT, @PLAN_MODELO INT
DECLARE @ACT_PLANTA INT, @ACT_TIPO INT, @ACT_MODELO INT, @ACT_CODIGO NVARCHAR(100)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    SELECT @PLAN_PLANTA = pma_cliente_instalacion, @PLAN_TIPO = pma_activo_tipo, @PLAN_MODELO = pma_activo_modelo
    FROM   [dbo].[Plan_Mantenimiento]
    WHERE  pma_id = @PLAN AND pma_cliente = @CLIENTE

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('1.- EL PLAN NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    SELECT TOP 1 @VERSION = pmv_id
    FROM   [dbo].[Plan_Mantenimiento_Version]
    WHERE  pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1
    ORDER BY pmv_numero DESC

    IF @VERSION IS NULL
    BEGIN
        RAISERROR('2.- EL PLAN NO TIENE UNA VERSIÓN EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA CAMBIAR SUS EQUIPOS.', 16, 1)
        RETURN -1
    END

    SELECT @ACT_PLANTA = act_cliente_instalacion, @ACT_TIPO = act_activo_tipo,
           @ACT_MODELO = act_activo_modelo, @ACT_CODIGO = act_codigo
    FROM   [dbo].[Activo]
    WHERE  act_id = @ACTIVO AND act_cliente = @CLIENTE AND act_habilitado = 1

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('3.- EL ACTIVO NO EXISTE, ESTÁ DESHABILITADO O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* EL ALCANCE DEL PLAN NO ES DECORATIVO */
    IF @PLAN_PLANTA IS NOT NULL AND @ACT_PLANTA <> @PLAN_PLANTA
    BEGIN
        RAISERROR('4.- EL ACTIVO "%s" ESTÁ EN OTRA PLANTA. EL PLAN ESTÁ ACOTADO A UNA PLANTA DISTINTA.', 16, 1, @ACT_CODIGO)
        RETURN -1
    END

    IF @PLAN_TIPO IS NOT NULL AND @ACT_TIPO <> @PLAN_TIPO
    BEGIN
        RAISERROR('5.- EL ACTIVO "%s" NO ES DEL TIPO AL QUE ESTÁ ACOTADO EL PLAN.', 16, 1, @ACT_CODIGO)
        RETURN -1
    END

    IF @PLAN_MODELO IS NOT NULL AND ISNULL(@ACT_MODELO, -1) <> @PLAN_MODELO
    BEGIN
        RAISERROR('6.- EL ACTIVO "%s" NO ES DEL MODELO AL QUE ESTÁ ACOTADO EL PLAN.', 16, 1, @ACT_CODIGO)
        RETURN -1
    END

    -- El componente y el medidor tienen que ser DE ESE activo.
    IF @ACTIVO_COMPONENTE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                        WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO AND aco_habilitado = 1)
    BEGIN
        RAISERROR('7.- EL COMPONENTE NO PERTENECE A ESE ACTIVO.', 16, 1)
        RETURN -1
    END

    IF @ACTIVO_MEDIDOR IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                        WHERE ame_id = @ACTIVO_MEDIDOR AND ame_activo = @ACTIVO AND ame_habilitado = 1)
    BEGIN
        RAISERROR('8.- EL MEDIDOR NO PERTENECE A ESE ACTIVO.', 16, 1)
        RETURN -1
    END

    -- Lo garantizan los dos indices filtrados; aca se dice con palabras.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                WHERE pac_plan_mantenimiento_version = @VERSION AND pac_activo = @ACTIVO
                  AND ISNULL(pac_activo_componente, 0) = ISNULL(@ACTIVO_COMPONENTE, 0))
    BEGIN
        RAISERROR('9.- EL ACTIVO "%s" YA ESTÁ EN ESTA VERSIÓN DEL PLAN.', 16, 1, @ACT_CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Activo]
        (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor,
         pac_usuario_creacion, pac_fecha_creacion)
    VALUES
        (@VERSION, @ACTIVO, @ACTIVO_COMPONENTE, @ACTIVO_MEDIDOR, @USUARIO, @DATE_NOW)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_ACTIVO @PLAN = ' + LTRIM(STR(@PLAN)) + ',@ACTIVO = ' + LTRIM(STR(@ACTIVO))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '10.- NO FUE POSIBLE ASOCIAR EL ACTIVO.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_ACTIVO — solo componente y medidor
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_ACTIVO]
@ID                  INT,
@ACTIVO_COMPONENTE   INT = NULL,
@ACTIVO_MEDIDOR      INT = NULL,
@QUITA_COMPONENTE    BIT = 0,
@QUITA_MEDIDOR       BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @VERSION INT, @ACTIVO INT, @ESTADO INT

SELECT @VERSION = pac_plan_mantenimiento_version, @ACTIVO = pac_activo
FROM   [dbo].[Plan_Mantenimiento_Activo] WHERE pac_id = @ID

IF @VERSION IS NULL
BEGIN
    RAISERROR('1.- EL VÍNCULO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @ESTADO = pmv_plan_version_estado FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @VERSION

BEGIN
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA CAMBIAR SUS EQUIPOS.', 16, 1)
        RETURN -1
    END

    IF @ACTIVO_COMPONENTE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                        WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO AND aco_habilitado = 1)
    BEGIN
        RAISERROR('3.- EL COMPONENTE NO PERTENECE A ESE ACTIVO.', 16, 1)
        RETURN -1
    END

    IF @ACTIVO_MEDIDOR IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                        WHERE ame_id = @ACTIVO_MEDIDOR AND ame_activo = @ACTIVO AND ame_habilitado = 1)
    BEGIN
        RAISERROR('4.- EL MEDIDOR NO PERTENECE A ESE ACTIVO.', 16, 1)
        RETURN -1
    END

    -- Cambiar el componente puede chocar con otro vinculo del mismo activo.
    DECLARE @COMP_FINAL INT = CASE WHEN @QUITA_COMPONENTE = 1 THEN NULL ELSE ISNULL(@ACTIVO_COMPONENTE,
                              (SELECT pac_activo_componente FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_id = @ID)) END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                WHERE pac_plan_mantenimiento_version = @VERSION AND pac_activo = @ACTIVO
                  AND ISNULL(pac_activo_componente, 0) = ISNULL(@COMP_FINAL, 0) AND pac_id <> @ID)
    BEGIN
        RAISERROR('5.- ESE ACTIVO Y COMPONENTE YA ESTÁN EN ESTA VERSIÓN DEL PLAN.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento_Activo]
    SET     pac_activo_componente = CASE WHEN @QUITA_COMPONENTE = 1 THEN NULL ELSE ISNULL(@ACTIVO_COMPONENTE, pac_activo_componente) END
           ,pac_activo_medidor    = CASE WHEN @QUITA_MEDIDOR = 1 THEN NULL ELSE ISNULL(@ACTIVO_MEDIDOR, pac_activo_medidor) END
    WHERE   pac_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_PLAN_ACTIVO', @MSG = '6.- NO FUE POSIBLE ACTUALIZAR EL VÍNCULO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 4) DEL_PLAN_ACTIVO — fisico, sobre el borrador, sin huerfanos
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_ACTIVO]
@ID INT

AS
SET NOCOUNT ON

DECLARE @VERSION INT, @ACTIVO INT, @ESTADO INT

SELECT @VERSION = pac_plan_mantenimiento_version, @ACTIVO = pac_activo
FROM   [dbo].[Plan_Mantenimiento_Activo] WHERE pac_id = @ID

IF @VERSION IS NULL
BEGIN
    RAISERROR('1.- EL VÍNCULO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @ESTADO = pmv_plan_version_estado FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @VERSION

BEGIN
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA CAMBIAR SUS EQUIPOS.', 16, 1)
        RETURN -1
    END

    /* Las ocurrencias cuelgan del hito y del activo, no del vinculo. Si esta
       version ya genero mantenciones para este equipo, quitarlo dejaria
       ocurrencias apuntando a un equipo que el plan ya no cubre. */
    IF EXISTS (SELECT 1
               FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
               INNER JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               WHERE  h.pmh_plan_mantenimiento_version = @VERSION AND o.pmo_activo = @ACTIVO)
    BEGIN
        RAISERROR('3.- ESTA VERSIÓN YA GENERÓ MANTENCIONES PARA ESE EQUIPO. NO SE PUEDE QUITAR.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    DELETE [dbo].[Plan_Mantenimiento_Activo] WHERE pac_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'DEL_PLAN_ACTIVO', @MSG = '4.- NO FUE POSIBLE QUITAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 5) Menu y funciones (T-4106, T-4107) — mismos permisos que el plan
-- ---------------------------------------------------------------------------
DECLARE @VER    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PLANES MANTENIMIENTO')
DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PLANES MANTENIMIENTO')
DECLARE @PADRE  INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanHitos.aspx')

IF (@PADRE IS NULL OR @VER IS NULL)
BEGIN
    RAISERROR('CORRA BD/212 Y BD/213 ANTES QUE ESTE.', 16, 1)
    RETURN
END

-- Despues de Hitos: primero que se hace, despues a que equipos.
DECLARE @ORDEN_HITOS INT = (SELECT mnu_orden FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanHitos.aspx')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActivos.aspx')
BEGIN
    UPDATE [dbo].[Menus] SET mnu_orden = mnu_orden + 1
    WHERE  mnu_padre = @PADRE AND mnu_orden > @ORDEN_HITOS AND mnu_orden < 99

    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Equipos de plan',
         'A qué equipos se aplica cada plan',
         3, @PADRE, @ORDEN_HITOS + 1,
         '~/View/Mantenimiento/Planes/PlanActivos.aspx', 1,
         'mdi mdi-link-variant', @VER, 1)
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActivo.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Equipo de plan (detalle)', 'Ficha de un vínculo plan-equipo',
         3, @PADRE, 99,
         '~/View/Mantenimiento/Planes/PlanActivo.aspx', 0, '', @VER, 1)

DECLARE @MENU INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActivos.aspx')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @MENU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @MENU, @EDITAR)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures
                        WHERE name IN ('SEL_PLAN_ACTIVO','INS_PLAN_ACTIVO','UPD_PLAN_ACTIVO','DEL_PLAN_ACTIVO')) AS VARCHAR) + ' de 4' AS RESULTADO
UNION ALL
SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Planes/PlanActivo%') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Funciones = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
                               WHERE m.mnu_link LIKE '%/Planes/PlanActivos.aspx') AS VARCHAR) + ' de 2'
GO
