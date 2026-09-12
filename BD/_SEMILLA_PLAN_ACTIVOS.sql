USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA EQUIPOS DE PLAN (T-4099).
-- =============================================
-- ESTO NO ES UNA MIGRACION. Corre despues de _SEMILLA_PLANES_MANTENIMIENTO.
--
--   Asocia los hornos de la linea 1 al plan de hornos -que esta acotado a
--   la planta Renca y al tipo Horno-, y la modeladora ACT-33 con su motor al
--   plan de seguridad, que no tiene alcance. Idempotente: el INS rechaza el
--   duplicado y aca se pregunta antes.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @HORNOS  INT = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-HORNOS-L1')
DECLARE @SEGUR   INT = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-2')
DECLARE @ID INT, @ACT INT, @COMP INT, @MED INT

IF (@HORNOS IS NULL OR @SEGUR IS NULL OR @USUARIO IS NULL)
BEGIN
    RAISERROR('1.- CORRA _SEMILLA_PLANES_MANTENIMIENTO.sql ANTES.', 16, 1)
    RETURN
END

-- Los hornos de la linea 1 (todos los de tipo Horno en Renca)
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT act_id FROM [dbo].[Activo]
    WHERE  act_cliente = @CLIENTE AND act_habilitado = 1 AND act_codigo IN ('ACT-34', 'ACT-40')
OPEN cur
FETCH NEXT FROM cur INTO @ACT
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a
                   JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = a.pac_plan_mantenimiento_version
                   WHERE v.pmv_plan_mantenimiento = @HORNOS AND a.pac_activo = @ACT AND a.pac_activo_componente IS NULL)
        EXEC [dbo].[INS_PLAN_ACTIVO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @HORNOS, @ACTIVO = @ACT, @USUARIO = @USUARIO
    FETCH NEXT FROM cur INTO @ACT
END
CLOSE cur
DEALLOCATE cur

-- La modeladora, con su motor y el horometro, al plan de seguridad
SET @ACT  = (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = 'ACT-33')
SET @COMP = (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = @ACT AND aco_codigo = 'CMP-33-01')
SET @MED  = (SELECT ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo = @ACT AND ame_codigo = 'MED-33-H')

IF @ACT IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a
                   JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = a.pac_plan_mantenimiento_version
                   WHERE v.pmv_plan_mantenimiento = @SEGUR AND a.pac_activo = @ACT
                     AND ISNULL(a.pac_activo_componente, 0) = ISNULL(@COMP, 0))
    EXEC [dbo].[INS_PLAN_ACTIVO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @SEGUR, @ACTIVO = @ACT,
         @ACTIVO_COMPONENTE = @COMP, @ACTIVO_MEDIDOR = @MED, @USUARIO = @USUARIO
GO

SELECT PLAN_CODIGO + ' v' + CAST(VERSION_NUMERO AS VARCHAR) + ' · ' + ACTIVO_CODIGO + ' ' + ACTIVO_NOMBRE
       + ' · ' + ISNULL(COMPONENTE_NOMBRE, 'equipo completo') + ' · ' + ISNULL(MEDIDOR_NOMBRE, '-') AS RESULTADO
FROM (SELECT * FROM [dbo].[Plan_Mantenimiento_Activo]) x
CROSS APPLY (SELECT pma.pma_codigo AS PLAN_CODIGO, pmv.pmv_numero AS VERSION_NUMERO, act.act_codigo AS ACTIVO_CODIGO,
                    act.act_nombre AS ACTIVO_NOMBRE, aco.aco_nombre AS COMPONENTE_NOMBRE, ame.ame_nombre AS MEDIDOR_NOMBRE
             FROM [dbo].[Plan_Mantenimiento_Version] pmv
             JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
             JOIN [dbo].[Activo] act ON act.act_id = x.pac_activo
             LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = x.pac_activo_componente
             LEFT JOIN [dbo].[Activo_Medidor] ame ON ame.ame_id = x.pac_activo_medidor
             WHERE pmv.pmv_id = x.pac_plan_mantenimiento_version AND pma.pma_cliente = 1) r
ORDER BY 1
GO
