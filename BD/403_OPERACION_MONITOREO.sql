SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   403 · Operación › Sala de control · 09-10-2026  (parte d)

   SEL_OPERACION_MONITOREO entrega lo que la sala de control dibuja entre dos fechas:
     0 · cada trabajo: ejecuciones de planes, inspecciones y tareas, más las OT abiertas que no
         vienen de una ejecución (p. ej. una correctiva en curso que detiene un activo), con su
         ubicación (planta › área), activo, componente, hora, duración y si detiene el activo;
     1 · todas las áreas de las plantas (para decir cuáles operan sin mantención).
   Las fechas están en hora de la planta. Mismos filtros que el resto de Operación.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_MONITOREO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @RESPONSABLE INT = NULL,
    @CRITICIDAD  INT = NULL,
    @DESDE       DATE,
    @HASTA       DATE
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

CREATE TABLE #M (TIPO VARCHAR(10), ID INT, FECHA DATETIME, DURACION INT, PARADA BIT, ACTIVO_ID INT, COMPONENTE NVARCHAR(200), TITULO NVARCHAR(300), REF NVARCHAR(60),
                 ESTADO_ID INT, LIMITE DATETIME, DISPONIBLE DATETIME, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, RESP_ID INT)
INSERT INTO #M
SELECT 'PLAN', o.pmo_id, o.pmo_fecha_programada_utc, ISNULL(h.pmh_duracion_estimada_minuto, 60), ISNULL(h.pmh_requiere_parada, 0), o.pmo_activo, aco.aco_nombre, h.pmh_nombre, pma.pma_codigo,
       o.pmo_plan_ocurrencia_estado, o.pmo_fecha_limite_utc, o.pmo_fecha_disponible_utc, o.pmo_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, h.pmh_usuario_responsable
FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.pmo_activo_componente
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE  o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado NOT IN (6, 7)
  AND  o.pmo_fecha_programada_utc >= @D AND o.pmo_fecha_programada_utc < @H
INSERT INTO #M
SELECT 'INSPECCION', c.coc_id, c.coc_fecha_programada_utc, 30, 0, c.coc_activo, NULL, ISNULL(p.cpr_nombre, N'Inspección'), N'',
       c.coc_checklist_ocurrencia_estado, c.coc_fecha_limite_utc, c.coc_fecha_disponible_utc, NULL, NULL, NULL, p.cpr_usuario_responsable
FROM   [dbo].[Checklist_Ocurrencia] c LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
WHERE  c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado NOT IN (6, 7)
  AND  c.coc_fecha_programada_utc >= @D AND c.coc_fecha_programada_utc < @H
INSERT INTO #M
SELECT 'TAREA', t.toc_id, t.toc_fecha_programada_utc, ISNULL(tr.tar_duracion_estimada_minuto, 30), 0, tr.tar_activo, NULL, tr.tar_titulo, tr.tar_codigo,
       t.toc_tarea_ocurrencia_estado, t.toc_fecha_limite_utc, t.toc_fecha_disponible_utc, t.toc_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, NULL
FROM   [dbo].[Tarea_Ocurrencia] t JOIN [dbo].[Tarea] tr ON tr.tar_id = t.toc_tarea LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = t.toc_orden_trabajo
WHERE  t.toc_cliente = @CLIENTE AND t.toc_habilitado = 1 AND t.toc_tarea_ocurrencia_estado NOT IN (6, 7)
  AND  t.toc_fecha_programada_utc >= @D AND t.toc_fecha_programada_utc < @H
/* OT que no nacen de una ejecución */
INSERT INTO #M
SELECT 'OT', o.otr_id, o.otr_fecha_programada_utc, ISNULL(o.otr_duracion_estimada_minuto, 60), CASE WHEN ISNULL(o.otr_minuto_parada_activo, 0) > 0 THEN 1 ELSE 0 END, o.otr_activo, aco.aco_nombre, o.otr_titulo, N'',
       0, NULL, NULL, o.otr_id, o.otr_correlativo, o.otr_orden_trabajo_estado,
       (SELECT TOP 1 a.ota_usuario FROM [dbo].[Orden_Trabajo_Asignacion] a WHERE a.ota_orden_trabajo = o.otr_id AND a.ota_habilitado = 1 AND a.ota_es_responsable = 1)
FROM   [dbo].[Orden_Trabajo] o LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.otr_activo_componente
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado < 4
  AND  o.otr_plan_mantenimiento_ocurrencia IS NULL AND o.otr_tarea_ocurrencia IS NULL
  AND  o.otr_fecha_programada_utc >= @D AND o.otr_fecha_programada_utc < @H
IF @RESPONSABLE IS NOT NULL DELETE FROM #M WHERE ISNULL(RESP_ID, 0) <> @RESPONSABLE

SELECT  m.TIPO, m.ID, m.FECHA, m.DURACION, m.PARADA, a.act_id AS ACTIVO_ID, a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, m.COMPONENTE,
        a.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA, a.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA,
        m.TITULO, m.REF, m.ESTADO_ID, m.OT_ID, m.OT_NUMERO, m.OT_ESTADO,
        CASE WHEN m.TIPO = 'OT' THEN 'OT'
             WHEN m.ESTADO_ID IN (4, 5) OR m.OT_ESTADO = 4 THEN 'CERRADA'
             WHEN m.OT_ESTADO IN (2, 3) OR m.ESTADO_ID = 3 THEN 'ENCURSO'
             WHEN m.OT_ID IS NOT NULL THEN 'OT'
             WHEN m.LIMITE IS NOT NULL AND m.LIMITE < @AHORA THEN 'VENCIDA'
             WHEN m.FECHA < @AHORA THEN 'ATRASADA'
             WHEN m.DISPONIBLE IS NOT NULL AND m.DISPONIBLE <= @AHORA THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    #M m
JOIN    [dbo].[Activo] a ON a.act_id = m.ACTIVO_ID AND a.act_cliente = @CLIENTE AND a.act_habilitado = 1
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = a.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = m.RESP_ID
WHERE   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION) AND (@AREA IS NULL OR a.act_instalacion_area = @AREA)
  AND   (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)
ORDER BY m.FECHA, a.act_codigo

SELECT iar.iar_id AS AREA_ID, iar.iar_nombre AS AREA, iar.iar_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA
FROM   [dbo].[Instalacion_Area] iar JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = iar.iar_cliente_instalacion
WHERE  iar.iar_cliente = @CLIENTE AND iar.iar_habilitado = 1 AND (@INSTALACION IS NULL OR iar.iar_cliente_instalacion = @INSTALACION) AND (@AREA IS NULL OR iar.iar_id = @AREA)
ORDER BY cin.cin_nombre, iar.iar_orden, iar.iar_nombre
RETURN 0
GO
PRINT '403_OPERACION_MONITOREO aplicado.'
GO
