/* ============================================================================
   389 · Monitoreo de planes (sala de control) · 08-10-2026

   SEL_PLAN_MONITOREO(@CLIENTE, @INSTALACION, @DESDE, @HASTA) devuelve lo que
   necesita la vista «Monitoreo» del Centro de Planificación:
     0 · ejecuciones reales del rango (de cualquier plan), con la ubicación del
         activo (planta › área) y su componente;
     1 · proyección de lo que aún no existe como ejecución: planes en borrador
         y fechas de planes activos más allá del horizonte generado
         (FNC_PROGRAMACION_FECHAS);
     2 · todas las áreas de la planta, para decir cuáles NO tienen mantención.
   La fecha programada es la hora de la PLANTA (no UTC), como en el resto.
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_MONITOREO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @DESDE       DATE,
    @HASTA       DATE
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

/* 0 · ejecuciones reales */
SELECT  o.pmo_id AS PMO_ID, o.pmo_fecha_programada_utc AS FECHA, o.pmo_fecha_limite_utc AS LIMITE,
        o.pmo_plan_ocurrencia_estado AS ESTADO_ID,
        CASE WHEN o.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7) THEN 'CERRADA'
             WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 'VENCIDA'
             WHEN o.pmo_fecha_programada_utc < @UTC THEN 'ATRASADA'
             WHEN o.pmo_fecha_disponible_utc IS NOT NULL AND o.pmo_fecha_disponible_utc <= @UTC THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        pma.pma_id AS PLAN_ID, pma.pma_codigo AS PLAN_CODIGO, pma.pma_nombre AS PLAN_NOMBRE,
        h.pmh_id AS HITO_ID, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO_NOMBRE,
        ISNULL(h.pmh_duracion_estimada_minuto, 0) AS DURACION, h.pmh_requiere_parada AS PARADA,
        act.act_id AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        act.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA, aco.aco_nombre AS COMPONENTE,
        ot.otr_id AS OT_ID, ot.otr_correlativo AS OT_NUMERO, ot.otr_orden_trabajo_estado AS OT_ESTADO_ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
JOIN    [dbo].[Activo] act ON act.act_id = o.pmo_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.pmo_activo_componente
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
WHERE   o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1
  AND   o.pmo_plan_ocurrencia_estado NOT IN (6, 7)
  AND   o.pmo_fecha_programada_utc >= @D AND o.pmo_fecha_programada_utc < @H
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
ORDER BY o.pmo_fecha_programada_utc, act.act_codigo

/* 1 · proyección: borradores y más allá de lo ya generado */
DECLARE @LIM DATE = DATEADD(DAY, 90, CAST(@UTC AS DATE))
SELECT  f.FECHA AS FECHA, pma.pma_id AS PLAN_ID, pma.pma_codigo AS PLAN_CODIGO, pma.pma_nombre AS PLAN_NOMBRE,
        h.pmh_id AS HITO_ID, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO_NOMBRE,
        ISNULL(h.pmh_duracion_estimada_minuto, 0) AS DURACION, h.pmh_requiere_parada AS PARADA,
        act.act_id AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        act.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA, aco.aco_nombre AS COMPONENTE,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        CAST(CASE WHEN v.pmv_plan_version_estado = 1 THEN 1 ELSE 0 END AS BIT) AS BORRADOR
FROM    [dbo].[Plan_Mantenimiento] pma
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = v.pmv_id
JOIN    [dbo].[Activo] act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = a.pac_activo_componente
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @DESDE, @HASTA) f
WHERE   pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1 AND f.DESCARTADA = 0
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
  AND   ( (v.pmv_plan_version_estado = 1 AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] x WHERE x.pmv_plan_mantenimiento = pma.pma_id AND x.pmv_plan_version_estado = 2 AND x.pmv_habilitado = 1))
       OR (v.pmv_plan_version_estado = 2 AND CAST(f.FECHA AS DATE) > @LIM) )
ORDER BY f.FECHA, act.act_codigo

/* 2 · áreas de la planta (las que no tienen trabajo se listan como «operando») */
SELECT  iar.iar_id AS AREA_ID, iar.iar_nombre AS AREA, iar.iar_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA
FROM    [dbo].[Instalacion_Area] iar
JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = iar.iar_cliente_instalacion
WHERE   iar.iar_cliente = @CLIENTE AND iar.iar_habilitado = 1
  AND   (@INSTALACION IS NULL OR iar.iar_cliente_instalacion = @INSTALACION)
ORDER BY cin.cin_nombre, iar.iar_orden, iar.iar_nombre

RETURN(0)
GO
PRINT '389_PLAN_MONITOREO aplicado.'
GO
