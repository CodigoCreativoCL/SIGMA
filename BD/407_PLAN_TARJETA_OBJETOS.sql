/* ============================================================================
   407 · Tarjeta del plan: qué objetos mantenibles cubre (09-10-2026)

   La tarjeta del Centro de Planificación decía solo «1 activo · 1 intervención»: no se
   sabía qué activos están, ni si es el activo completo, un subactivo o un componente.
   SEL_PLAN_CENTRO_OBJETOS devuelve, por plan, los objetos de su versión en edición
   (el borrador si hay; si no, la publicada):
     TIPO = ACT (activo completo) · SUB (subactivo: activo con act_activo_padre) · COMP (componente).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CENTRO_OBJETOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
;WITH V AS (
    SELECT  pm.pma_id, v.pmv_id,
            ROW_NUMBER() OVER (PARTITION BY pm.pma_id ORDER BY v.pmv_numero DESC) AS RN
    FROM    [dbo].[Plan_Mantenimiento] pm
    JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_plan_mantenimiento = pm.pma_id AND v.pmv_habilitado = 1 AND v.pmv_plan_version_estado IN (1, 2)
    WHERE   pm.pma_cliente = @CLIENTE AND pm.pma_habilitado = 1
      AND   (@INSTALACION IS NULL OR pm.pma_cliente_instalacion = @INSTALACION)
)
SELECT  v.pma_id AS PLAN_ID,
        CASE WHEN pac.pac_activo_componente IS NOT NULL THEN 'COMP' WHEN a.act_activo_padre IS NOT NULL THEN 'SUB' ELSE 'ACT' END AS TIPO,
        a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE,
        ISNULL(ac.aco_nombre, N'') AS COMPONENTE,
        ISNULL(ap.act_nombre, N'') AS PADRE
FROM    V v
JOIN    [dbo].[Plan_Mantenimiento_Activo] pac ON pac.pac_plan_mantenimiento_version = v.pmv_id
JOIN    [dbo].[Activo] a ON a.act_id = pac.pac_activo
LEFT JOIN [dbo].[Activo] ap ON ap.act_id = a.act_activo_padre
LEFT JOIN [dbo].[Activo_Componente] ac ON ac.aco_id = pac.pac_activo_componente
WHERE   v.RN = 1
ORDER BY v.pma_id, a.act_codigo, ac.aco_nombre
GO
PRINT '407_PLAN_TARJETA_OBJETOS aplicado.'
GO
