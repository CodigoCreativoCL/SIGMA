/* ============================================================================
   422 · Parte f · Repuestos dentro de las actividades del plan, como el mockup (09-10-2026)

   Los repuestos por actividad ya se guardaban (Plan_Actividad_Repuesto) y pasaban a la OT
   (INS_ORDEN_TRABAJO_OCURRENCIA). Faltaba lo que el mockup muestra para decidir bien:
     · Compatibilidad con lo que mantiene el plan, por NIVEL (repsHTML/compatFor del mockup):
         1 Del objeto mantenible (calza en el activo o el componente exacto que mantiene el plan)
         2 De sus componentes (se instala en un componente del activo que se mantiene completo)
         3 Del activo (por modelo o tipo de activo: consumibles y filtros)
       y con CUÁNTOS de los activos del plan calza (FITS de N).
     · Stock en bodega: disponible (Inventario_Saldo − reservado), mínimo (Repuesto_Bodega_Stock),
       la bodega con más stock y la unidad.
   SEL_PLAN_REPUESTOS_SUGERIDOS (BD/409) se reemplaza:
     0 · compatibles: ID, CODIGO, NOMBRE, POR, PRIO, NIVEL, FITS, DONDE, UNIDAD, STOCK, MINIMO, BODEGA
     1 · stock de los repuestos ya planificados en las actividades (aunque no sean compatibles)
     2 · N: cuántos objetos mantenibles tiene el plan
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [dbo].[FNC_REPUESTO_STOCK] (@CLIENTE INT, @REPUESTO INT)
RETURNS TABLE
AS
RETURN
SELECT  CAST(ISNULL((SELECT SUM(s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0)) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO), 0) AS DECIMAL(18,2)) AS STOCK,
        CAST((SELECT SUM(b.rbs_stock_minimo) FROM [dbo].[Repuesto_Bodega_Stock] b WHERE b.rbs_cliente = @CLIENTE AND b.rbs_repuesto = @REPUESTO AND b.rbs_habilitado = 1) AS DECIMAL(18,2)) AS MINIMO,
        (SELECT TOP 1 bo.bod_nombre FROM [dbo].[Inventario_Saldo] s JOIN [dbo].[Bodega] bo ON bo.bod_id = s.isa_bodega
          WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO GROUP BY bo.bod_nombre ORDER BY SUM(s.isa_cantidad) DESC) AS BODEGA,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo] s WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO)
                    OR EXISTS (SELECT 1 FROM [dbo].[Repuesto_Bodega_Stock] b WHERE b.rbs_cliente = @CLIENTE AND b.rbs_repuesto = @REPUESTO AND b.rbs_habilitado = 1) THEN 1 ELSE 0 END AS BIT) AS CON_REGISTRO
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_REPUESTOS_SUGERIDOS]
    @CLIENTE INT,
    @PLAN    INT
AS
SET NOCOUNT ON
DECLARE @VER INT = (SELECT TOP 1 v.pmv_id FROM [dbo].[Plan_Mantenimiento_Version] v JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
                    WHERE v.pmv_plan_mantenimiento = @PLAN AND p.pma_cliente = @CLIENTE AND v.pmv_habilitado = 1 AND v.pmv_plan_version_estado IN (1, 2) ORDER BY v.pmv_numero DESC)

SELECT  pac.pac_id AS OBJ, pac.pac_activo AS ACT, pac.pac_activo_componente AS COMP, a.act_activo_modelo AS MODELO, a.act_activo_tipo AS TIPO, a.act_codigo AS COD, c.aco_nombre AS COMPN
INTO    #O
FROM    [dbo].[Plan_Mantenimiento_Activo] pac
JOIN    [dbo].[Activo] a ON a.act_id = pac.pac_activo
LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = pac.pac_activo_componente
WHERE   pac.pac_plan_mantenimiento_version = @VER

SELECT  rc.rco_repuesto AS REP, o.OBJ,
        CASE WHEN rc.rco_activo_componente IS NOT NULL THEN 1 WHEN rc.rco_activo IS NOT NULL THEN 2 WHEN rc.rco_activo_modelo IS NOT NULL THEN 3 ELSE 4 END AS PRIO,
        CASE WHEN rc.rco_activo_componente IS NOT NULL AND rc.rco_activo_componente = o.COMP THEN 1
             WHEN rc.rco_activo_componente IS NOT NULL THEN 2
             WHEN rc.rco_activo IS NOT NULL THEN 1
             ELSE 3 END AS NIVEL,
        CASE WHEN rc.rco_activo_componente IS NOT NULL THEN o.COD + N' › ' + ISNULL(cc.aco_nombre, N'componente')
             WHEN rc.rco_activo IS NOT NULL THEN o.COD + N' · activo'
             WHEN rc.rco_activo_modelo IS NOT NULL THEN o.COD + N' · modelo ' + ISNULL(mo.amo_nombre, N'')
             ELSE o.COD + N' · tipo ' + ISNULL(ti.ati_nombre, N'') END AS DONDE,
        CASE WHEN rc.rco_activo_componente IS NOT NULL THEN o.COD + N' › ' + ISNULL(cc.aco_nombre, N'componente')
             WHEN rc.rco_activo IS NOT NULL THEN o.COD
             WHEN rc.rco_activo_modelo IS NOT NULL THEN N'Modelo ' + ISNULL(mo.amo_nombre, N'')
             ELSE N'Tipo ' + ISNULL(ti.ati_nombre, N'') END AS POR
INTO    #M
FROM    [dbo].[Repuesto_Compatibilidad] rc
JOIN    #O o ON (rc.rco_activo_componente IS NOT NULL AND (rc.rco_activo_componente = o.COMP
                 OR EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] x WHERE x.aco_id = rc.rco_activo_componente AND x.aco_activo = o.ACT AND o.COMP IS NULL)))
          OR (rc.rco_activo_componente IS NULL AND rc.rco_activo = o.ACT)
          OR (rc.rco_activo_componente IS NULL AND rc.rco_activo IS NULL AND rc.rco_activo_modelo = o.MODELO)
          OR (rc.rco_activo_componente IS NULL AND rc.rco_activo IS NULL AND rc.rco_activo_modelo IS NULL AND rc.rco_activo_tipo = o.TIPO)
LEFT JOIN [dbo].[Activo_Componente] cc ON cc.aco_id = rc.rco_activo_componente
LEFT JOIN [dbo].[Activo_Modelo] mo ON mo.amo_id = rc.rco_activo_modelo
LEFT JOIN [dbo].[Activo_Tipo] ti ON ti.ati_id = rc.rco_activo_tipo

SELECT  r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
        STUFF((SELECT DISTINCT N', ' + m2.POR FROM #M m2 WHERE m2.REP = r.rep_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS POR,
        STUFF((SELECT DISTINCT N' · ' + m2.DONDE FROM #M m2 WHERE m2.REP = r.rep_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 3, N'') AS DONDE,
        MIN(m.PRIO) AS PRIO, MIN(m.NIVEL) AS NIVEL, COUNT(DISTINCT m.OBJ) AS FITS,
        ISNULL(um.ume_simbolo, N'un') AS UNIDAD, st.STOCK, st.MINIMO, st.BODEGA, st.CON_REGISTRO
FROM    #M m JOIN [dbo].[Repuesto] r ON r.rep_id = m.REP
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
OUTER APPLY [dbo].[FNC_REPUESTO_STOCK](@CLIENTE, r.rep_id) st
WHERE   r.rep_habilitado = 1 AND (r.rep_cliente = @CLIENTE OR r.rep_cliente IS NULL)
GROUP BY r.rep_id, r.rep_codigo, r.rep_nombre, um.ume_simbolo, st.STOCK, st.MINIMO, st.BODEGA, st.CON_REGISTRO
ORDER BY MIN(m.NIVEL), r.rep_nombre

/* 1 · stock de lo ya planificado en las actividades de esta versión */
SELECT  DISTINCT r.pra_repuesto AS ID, st.STOCK, st.MINIMO, st.BODEGA, st.CON_REGISTRO
FROM    [dbo].[Plan_Actividad_Repuesto] r
JOIN    [dbo].[Plan_Mantenimiento_Actividad] pa ON pa.paa_id = r.pra_plan_mantenimiento_actividad
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = pa.paa_plan_mantenimiento_hito
OUTER APPLY [dbo].[FNC_REPUESTO_STOCK](@CLIENTE, r.pra_repuesto) st
WHERE   h.pmh_plan_mantenimiento_version = @VER

/* 2 · cuántos objetos mantenibles tiene el plan */
SELECT COUNT(*) AS N FROM #O
RETURN 0
GO
PRINT '422_PLAN_REPUESTOS_ACTIVIDAD aplicado.'
GO
