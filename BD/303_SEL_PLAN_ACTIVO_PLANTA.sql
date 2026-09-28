USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- 27-09-2026 · Centro del plan por planta: SEL_PLAN_ACTIVO devuelve ademas
-- PLANTA_ID (la planta del equipo), para que el centro filtre sus equipos por
-- el combo de planta sin comparar nombres. Nada mas cambia.
-- =============================================

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
                                  ,act.act_cliente_instalacion         AS PLANTA_ID
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

PRINT '303_SEL_PLAN_ACTIVO_PLANTA aplicado.'
GO
