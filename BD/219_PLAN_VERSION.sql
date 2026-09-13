USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     VERSIONES DE UN PLAN: LISTAR, ABRIR UNA NUEVA Y PUBLICAR (HU-084).
-- =============================================
-- LO QUE YA HABIA Y LO QUE FALTABA
--
--   El bloque 14 trae UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR (publica y
--   retira la anterior en la misma transaccion, exige hitos y equipos) y
--   FNC_PLAN_VERSION_VIGENTE. Lo que NO habia era una forma de ABRIR una
--   version nueva: una vez publicada la v1, sus hitos y equipos quedan
--   congelados -correcto- y el plan no tenia por donde seguir. Este bloque
--   cierra el ciclo: SEL para la pestaña Versiones, INS_PLAN_VERSION_NUEVA
--   para abrir el borrador siguiente, y un UPD_PLAN_VERSION_PUBLICAR delgado
--   sobre el del bloque 14 que agrega la observacion y los mensajes
--   numerados del sitio.
--
-- LA VERSION NUEVA NACE COMO COPIA DE LA VIGENTE
--
--   Un plan de 40 hitos no se vuelve a tipear para cambiar uno. La v(n+1)
--   se abre en BORRADOR con los hitos y los equipos de la version que
--   manda (la publicada; si no hay, la ultima) copiados, y desde ahi se
--   edita. Los codigos de hito se conservan: UX_PMH_VERSION_CODIGO es por
--   version, asi que no chocan. Las actividades de cada hito (HU-082) se
--   copian tambien si existen: un hito sin sus actividades es medio hito.
--
-- UN SOLO BORRADOR POR PLAN
--
--   La tabla no lo impide, pero dos borradores a la vez no tienen sentido:
--   ¿cual se publica? INS_PLAN_VERSION_NUEVA rechaza si ya hay uno.
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_VERSION
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_VERSION]
@ID      INT = NULL,
@CLIENTE INT = NULL,
@PLAN    INT = NULL

AS
SET NOCOUNT ON

SELECT  pmv.pmv_id                    AS PMV_ID,
        pmv.pmv_plan_mantenimiento    AS PMV_PLAN_MANTENIMIENTO,
        pmv.pmv_numero                AS PMV_NUMERO,
        pmv.pmv_plan_version_estado   AS PMV_PLAN_VERSION_ESTADO,
        pve.pve_codigo                AS ESTADO_CODIGO,
        pve.pve_nombre                AS ESTADO_NOMBRE,
        pmv.pmv_fecha_publicacion     AS PMV_FECHA_PUBLICACION,
        LTRIM(RTRIM(ISNULL(up.usu_nombre,'') + ' ' + ISNULL(up.usu_apellido_paterno,''))) AS USUARIO_PUBLICACION_NOMBRE,
        pmv.pmv_fecha_retiro          AS PMV_FECHA_RETIRO,
        pmv.pmv_observacion           AS PMV_OBSERVACION,
        pmv.pmv_fecha_creacion        AS PMV_FECHA_CREACION,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
        pmv.pmv_habilitado            AS PMV_HABILITADO,
        pma.pma_cliente               AS PLAN_CLIENTE,
        pma.pma_codigo                AS PLAN_CODIGO,
        pma.pma_nombre                AS PLAN_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito]   h WHERE h.pmh_plan_mantenimiento_version = pmv.pmv_id AND h.pmh_habilitado = 1) AS HITOS,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = pmv.pmv_id) AS ACTIVOS,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
           JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          WHERE h.pmh_plan_mantenimiento_version = pmv.pmv_id AND o.pmo_habilitado = 1) AS OCURRENCIAS
FROM    [dbo].[Plan_Mantenimiento_Version] pmv
JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Plan_Version_Estado]      pve ON pve.pve_id = pmv.pmv_plan_version_estado
LEFT JOIN [dbo].[Usuario]                  up  ON up.usu_id = pmv.pmv_usuario_publicacion
LEFT JOIN [dbo].[Usuario]                  uc  ON uc.usu_id = pmv.pmv_usuario_creacion
WHERE   pmv.pmv_habilitado = 1
  AND   (@ID IS NULL OR pmv.pmv_id = @ID)
  AND   (@CLIENTE IS NULL OR pma.pma_cliente = @CLIENTE)
  AND   (@PLAN IS NULL OR pmv.pmv_plan_mantenimiento = @PLAN)
ORDER BY pmv.pmv_numero DESC
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_VERSION_NUEVA — el borrador siguiente, copia de la vigente
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_VERSION_NUEVA]
@ID          INT = NULL OUTPUT,
@CLIENTE     INT,
@PLAN        INT,
@OBSERVACION NVARCHAR(1000) = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE AND pma_habilitado = 1)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE O ESTÁ DESHABILITADO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1)
BEGIN
    RAISERROR('2.- EL PLAN YA TIENE UNA VERSIÓN EN BORRADOR; EDÍTELA O PUBLÍQUELA ANTES DE ABRIR OTRA.', 16, 1)
    RETURN -1
END

-- La version que manda: la publicada; si no hay, la ultima que exista.
DECLARE @ORIGEN INT = [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN)
IF @ORIGEN IS NULL
    SET @ORIGEN = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)

DECLARE @NUMERO INT = ISNULL((SELECT MAX(pmv_numero) FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN), 0) + 1

BEGIN TRY
    BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Version]
        (pmv_plan_mantenimiento, pmv_numero, pmv_plan_version_estado, pmv_observacion,
         pmv_usuario_creacion, pmv_fecha_creacion, pmv_usuario_actualizacion, pmv_fecha_actualizacion, pmv_habilitado)
    VALUES
        (@PLAN, @NUMERO, 1, @OBSERVACION, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @ORIGEN IS NOT NULL
    BEGIN
        -- Hitos, guardando de cual viene cada copia para colgarle sus actividades
        DECLARE @MAPA TABLE (viejo INT, nuevo INT)

        MERGE [dbo].[Plan_Mantenimiento_Hito] AS destino
        USING (SELECT * FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @ORIGEN AND pmh_habilitado = 1) AS h
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
                    pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
                    pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion,
                    pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion, pmh_habilitado)
            VALUES (@ID, h.pmh_programacion, h.pmh_codigo, h.pmh_nombre, h.pmh_orden, h.pmh_valor_medidor,
                    h.pmh_unidad_medida, h.pmh_es_overhaul, h.pmh_requiere_parada, h.pmh_duracion_estimada_minuto,
                    h.pmh_orden_trabajo_tipo, h.pmh_orden_trabajo_prioridad, h.pmh_descripcion,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT h.pmh_id, inserted.pmh_id INTO @MAPA (viejo, nuevo);

        -- Actividades de cada hito (HU-082), si las hay
        INSERT [dbo].[Plan_Mantenimiento_Actividad]
            (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion, paa_orden,
             paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada, paa_requiere_permiso, paa_permiso_trabajo_tipo,
             paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion, paa_habilitado)
        SELECT m.nuevo, a.paa_procedimiento, a.paa_codigo, a.paa_nombre, a.paa_descripcion, a.paa_orden,
               a.paa_duracion_estimada_minuto, a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo,
               @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Plan_Mantenimiento_Actividad] a
        JOIN   @MAPA m ON m.viejo = a.paa_plan_mantenimiento_hito
        WHERE  a.paa_habilitado = 1

        -- Equipos
        INSERT [dbo].[Plan_Mantenimiento_Activo]
            (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor, pac_usuario_creacion, pac_fecha_creacion)
        SELECT @ID, pac_activo, pac_activo_componente, pac_activo_medidor, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Mantenimiento_Activo]
        WHERE  pac_plan_mantenimiento_version = @ORIGEN
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_PLAN_VERSION_NUEVA', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE ABRIR LA VERSIÓN NUEVA: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_VERSION_PUBLICAR — sobre el del bloque 14, con observacion
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_VERSION_PUBLICAR]
@ID          INT,
@CLIENTE     INT,
@OBSERVACION NVARCHAR(1000) = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] v
               JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
               WHERE v.pmv_id = @ID AND p.pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA VERSIÓN NO EXISTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @ID AND pmv_plan_version_estado = 1)
BEGIN
    RAISERROR('2.- SOLO SE PUBLICA UNA VERSIÓN EN BORRADOR.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @ID AND pmh_habilitado = 1)
BEGIN
    RAISERROR('3.- LA VERSIÓN NO TIENE HITOS: NO GENERARÍA NADA NUNCA.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @ID)
BEGIN
    RAISERROR('4.- LA VERSIÓN NO TIENE EQUIPOS: NO HABRÍA PARA QUÉ MÁQUINA GENERAR.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    IF @OBSERVACION IS NOT NULL
        UPDATE [dbo].[Plan_Mantenimiento_Version] SET pmv_observacion = @OBSERVACION WHERE pmv_id = @ID

    -- El del bloque 14 hace el trabajo: retira la publicada anterior y
    -- publica esta solo si TODAVIA es borrador (la carrera se decide ahi).
    EXEC [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR] @PMV_ID = @ID, @USUARIO = @USUARIO

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    RAISERROR('5.- %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('SEL_PLAN_VERSION','INS_PLAN_VERSION_NUEVA','UPD_PLAN_VERSION_PUBLICAR')) AS VARCHAR) + ' de 3' AS RESULTADO
GO
