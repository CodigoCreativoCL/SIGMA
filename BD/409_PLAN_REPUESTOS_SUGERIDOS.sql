/* ============================================================================
   409 · Plan › Repuestos planificados: sugerencias por compatibilidad (09-10-2026)

   Al planificar los repuestos de una actividad se sugieren los que Repuesto_Compatibilidad
   declara compatibles con lo que el plan mantiene: el activo o subactivo, su componente, o el
   modelo y el tipo del activo. Se mira la versión en edición del plan (borrador si hay; si no,
   la publicada). POR dice por qué calza («ACT-10 › Motor principal», «Modelo CB-700»…).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_REPUESTOS_SUGERIDOS]
    @CLIENTE INT,
    @PLAN    INT
AS
SET NOCOUNT ON
DECLARE @VER INT = (SELECT TOP 1 v.pmv_id FROM [dbo].[Plan_Mantenimiento_Version] v JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
                    WHERE v.pmv_plan_mantenimiento = @PLAN AND p.pma_cliente = @CLIENTE AND v.pmv_habilitado = 1 AND v.pmv_plan_version_estado IN (1, 2) ORDER BY v.pmv_numero DESC)
;WITH O AS (
    SELECT pac.pac_activo AS ACT, pac.pac_activo_componente AS COMP, a.act_activo_modelo AS MODELO, a.act_activo_tipo AS TIPO, a.act_codigo AS COD, c.aco_nombre AS COMPN
    FROM   [dbo].[Plan_Mantenimiento_Activo] pac
    JOIN   [dbo].[Activo] a ON a.act_id = pac.pac_activo
    LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = pac.pac_activo_componente
    WHERE  pac.pac_plan_mantenimiento_version = @VER
), M AS (
    SELECT rc.rco_repuesto AS REP,
           CASE WHEN rc.rco_activo_componente IS NOT NULL THEN 1 WHEN rc.rco_activo IS NOT NULL THEN 2 WHEN rc.rco_activo_modelo IS NOT NULL THEN 3 ELSE 4 END AS PRIO,
           CASE WHEN rc.rco_activo_componente IS NOT NULL THEN o.COD + N' › ' + ISNULL(cc.aco_nombre, N'componente')
                WHEN rc.rco_activo IS NOT NULL THEN o.COD
                WHEN rc.rco_activo_modelo IS NOT NULL THEN N'Modelo ' + ISNULL(mo.amo_nombre, N'')
                ELSE N'Tipo ' + ISNULL(ti.ati_nombre, N'') END AS POR
    FROM   [dbo].[Repuesto_Compatibilidad] rc
    JOIN   O o ON (rc.rco_activo_componente IS NOT NULL AND (rc.rco_activo_componente = o.COMP
                     OR EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] x WHERE x.aco_id = rc.rco_activo_componente AND x.aco_activo = o.ACT AND o.COMP IS NULL)))
              OR (rc.rco_activo_componente IS NULL AND rc.rco_activo = o.ACT)
              OR (rc.rco_activo_componente IS NULL AND rc.rco_activo IS NULL AND rc.rco_activo_modelo = o.MODELO)
              OR (rc.rco_activo_componente IS NULL AND rc.rco_activo IS NULL AND rc.rco_activo_modelo IS NULL AND rc.rco_activo_tipo = o.TIPO)
    LEFT JOIN [dbo].[Activo_Componente] cc ON cc.aco_id = rc.rco_activo_componente
    LEFT JOIN [dbo].[Activo_Modelo] mo ON mo.amo_id = rc.rco_activo_modelo
    LEFT JOIN [dbo].[Activo_Tipo] ti ON ti.ati_id = rc.rco_activo_tipo
)
SELECT  r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
        STUFF((SELECT DISTINCT N', ' + m2.POR FROM M m2 WHERE m2.REP = r.rep_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS POR,
        MIN(m.PRIO) AS PRIO
FROM    M m JOIN [dbo].[Repuesto] r ON r.rep_id = m.REP
WHERE   r.rep_habilitado = 1 AND (r.rep_cliente = @CLIENTE OR r.rep_cliente IS NULL)
GROUP BY r.rep_id, r.rep_codigo, r.rep_nombre
ORDER BY MIN(m.PRIO), r.rep_nombre
GO
PRINT '409_PLAN_REPUESTOS_SUGERIDOS aplicado.'
GO
