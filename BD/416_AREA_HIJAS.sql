/* ============================================================================
   416 · Filtrar por un área padre incluye sus áreas hijas (09-10-2026)

   Antes los filtros de Operación (Hoy, Ejecuciones, Cumplimiento, Sala de control) y
   Planificación › Cobertura comparaban act_instalacion_area = @AREA: elegir «Despacho»
   no mostraba los activos de sus subáreas.
     · FNC_AREA_Y_HIJAS(@AREA): el área y todas sus descendientes (iar_area_padre, recursivo).
     · Los SP comparan act_instalacion_area IN (SELECT ID FROM FNC_AREA_Y_HIJAS(@AREA)).
   Generado desde la definición vigente con _scratch/gen_416.py. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [dbo].[FNC_AREA_Y_HIJAS] (@AREA INT)
RETURNS TABLE
AS
RETURN
WITH A AS (
    SELECT iar_id AS ID, 0 AS NIVEL FROM [dbo].[Instalacion_Area] WHERE iar_id = @AREA
    UNION ALL
    SELECT h.iar_id, A.NIVEL + 1 FROM [dbo].[Instalacion_Area] h JOIN A ON h.iar_area_padre = A.ID WHERE A.NIVEL < 20
)
SELECT ID FROM A
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_EJECUCIONES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @RESPONSABLE INT = NULL,
    @CRITICIDAD  INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -60, CAST(@AHORA AS DATE))
IF @HASTA IS NULL SET @HASTA = DATEADD(DAY, 60, CAST(@AHORA AS DATE))
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

CREATE TABLE #E (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, DISPONIBLE DATETIME, ESTADO_ID INT, ACTIVO_ID INT, TITULO NVARCHAR(300), REF NVARCHAR(60), REF_NOMBRE NVARCHAR(300),
                 ACTIVIDADES INT, PARADA BIT, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, RESP_ID INT, HALLAZGOS INT)

INSERT INTO #E
SELECT 'PLAN', o.pmo_id, o.pmo_fecha_programada_utc, o.pmo_fecha_limite_utc, o.pmo_fecha_disponible_utc, o.pmo_plan_ocurrencia_estado, o.pmo_activo,
       h.pmh_nombre, pma.pma_codigo, pma.pma_nombre,
       (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] x WHERE x.paa_plan_mantenimiento_hito = h.pmh_id AND x.paa_habilitado = 1),
       ISNULL(h.pmh_requiere_parada, 0), o.pmo_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, h.pmh_usuario_responsable, 0
FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE  o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado <> 7
  AND  o.pmo_fecha_programada_utc >= @D AND o.pmo_fecha_programada_utc < @H

INSERT INTO #E
SELECT 'INSPECCION', c.coc_id, c.coc_fecha_programada_utc, c.coc_fecha_limite_utc, c.coc_fecha_disponible_utc, c.coc_checklist_ocurrencia_estado, c.coc_activo,
       ISNULL(p.cpr_nombre, N'Inspección'), N'', N'', 0, 0, NULL, NULL, NULL, p.cpr_usuario_responsable,
       (SELECT COUNT(*) FROM [dbo].[Checklist_Hallazgo] hz JOIN [dbo].[Checklist_Ejecucion] ej ON ej.cej_id = hz.cha_checklist_ejecucion WHERE ej.cej_checklist_ocurrencia = c.coc_id AND hz.cha_habilitado = 1)
FROM   [dbo].[Checklist_Ocurrencia] c
LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
WHERE  c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado <> 7
  AND  c.coc_fecha_programada_utc >= @D AND c.coc_fecha_programada_utc < @H

INSERT INTO #E
SELECT 'TAREA', t.toc_id, t.toc_fecha_programada_utc, t.toc_fecha_limite_utc, t.toc_fecha_disponible_utc, t.toc_tarea_ocurrencia_estado, tr.tar_activo,
       tr.tar_titulo, tr.tar_codigo, tr.tar_titulo, 0, 0, t.toc_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, NULL, 0
FROM   [dbo].[Tarea_Ocurrencia] t
JOIN   [dbo].[Tarea] tr ON tr.tar_id = t.toc_tarea
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = t.toc_orden_trabajo
WHERE  t.toc_cliente = @CLIENTE AND t.toc_habilitado = 1 AND t.toc_tarea_ocurrencia_estado <> 7
  AND  t.toc_fecha_programada_utc >= @D AND t.toc_fecha_programada_utc < @H

IF @RESPONSABLE IS NOT NULL DELETE FROM #E WHERE ISNULL(RESP_ID, 0) <> @RESPONSABLE

SELECT  e.TIPO, e.ID, e.FECHA, e.LIMITE, e.ESTADO_ID,
        CASE WHEN e.ESTADO_ID IN (4, 5) OR e.OT_ESTADO = 4 THEN 'CERRADA'
             WHEN e.ESTADO_ID = 6 THEN 'CANCELADA'
             WHEN e.OT_ESTADO IN (2, 3) OR e.ESTADO_ID = 3 THEN 'ENCURSO'
             WHEN e.LIMITE IS NOT NULL AND e.LIMITE < @AHORA THEN 'VENCIDA'
             WHEN e.FECHA < @AHORA THEN 'ATRASADA'
             WHEN e.DISPONIBLE IS NOT NULL AND e.DISPONIBLE <= @AHORA THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        a.act_id AS ACTIVO_ID, a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, iar.iar_nombre AS AREA, ISNULL(a.act_criticidad_nivel, 1) AS CRITICIDAD,
        e.TITULO, e.REF, e.REF_NOMBRE, e.ACTIVIDADES, e.PARADA, e.OT_ID, e.OT_NUMERO, e.OT_ESTADO, e.HALLAZGOS,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    #E e
JOIN    [dbo].[Activo] a ON a.act_id = e.ACTIVO_ID AND a.act_cliente = @CLIENTE AND a.act_habilitado = 1
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = e.RESP_ID
WHERE   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND   (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND   (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)
ORDER BY e.FECHA, a.act_codigo
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_CUMPLIMIENTO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @RESPONSABLE INT = NULL,
    @CRITICIDAD  INT = NULL,
    @MES         DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATE = CAST(@AHORA AS DATE)
IF @MES IS NULL SET @MES = DATEADD(DAY, 1 - DAY(@HOY), @HOY)
SET @MES = DATEADD(DAY, 1 - DAY(@MES), @MES)
DECLARE @M0 DATETIME = CAST(@MES AS DATETIME), @M1 DATETIME = DATEADD(MONTH, 1, CAST(@MES AS DATETIME))
DECLARE @SERIE0 DATETIME = DATEADD(MONTH, -5, @M0)

CREATE TABLE #EJ (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, ESTADO_ID INT, SITUACION VARCHAR(12), ACTIVO_ID INT, ACTIVO_CODIGO NVARCHAR(100), ACTIVO NVARCHAR(300), AREA NVARCHAR(200), CRITICIDAD INT,
                 TITULO NVARCHAR(300), REF NVARCHAR(60), REF_NOMBRE NVARCHAR(300), ACTIVIDADES INT, PARADA BIT, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, HALLAZGOS INT, RESPONSABLE NVARCHAR(200))
DECLARE @D DATE = @SERIE0, @H DATE = DATEADD(DAY, -1, CAST(@M1 AS DATE))
INSERT INTO #EJ EXEC [dbo].[SEL_OPERACION_EJECUCIONES] @CLIENTE = @CLIENTE, @INSTALACION = @INSTALACION, @AREA = @AREA, @RESPONSABLE = @RESPONSABLE, @CRITICIDAD = @CRITICIDAD, @DESDE = @D, @HASTA = @H
DELETE FROM #EJ WHERE SITUACION = 'CANCELADA'

/* vencida = ya pasó el límite (o la fecha, si no tiene límite); hecha = cerrada */
SELECT *, CAST(CASE WHEN ISNULL(LIMITE, FECHA) < @AHORA THEN 1 ELSE 0 END AS BIT) AS VENCIDA, CAST(CASE WHEN SITUACION = 'CERRADA' AND ESTADO_ID = 4 OR OT_ESTADO = 4 THEN 1 ELSE 0 END AS BIT) AS HECHA
INTO   #X FROM #EJ

SELECT a.act_id AS ACTIVO_ID INTO #ACT
FROM   [dbo].[Activo] a
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND  (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA))) AND (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)

SELECT o.otr_id, o.otr_orden_trabajo_estado AS ESTADO, o.otr_fecha_programada_utc AS PROGRAMADA, o.otr_fecha_creacion AS CREADA, o.otr_fecha_cierre AS CIERRE,
       ISNULL(o.otr_duracion_estimada_minuto, 0) AS DURACION, ISNULL(o.otr_duracion_real_minuto, 0) AS REAL
INTO   #OT
FROM   [dbo].[Orden_Trabajo] o JOIN #ACT a ON a.ACTIVO_ID = o.otr_activo
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1

/* ======================= 0 · indicadores del mes ======================= */
SELECT
    PLANIFICADO  = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1),
    VENCIDAS     = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND VENCIDA = 1),
    CUMPLIDAS    = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND VENCIDA = 1 AND HECHA = 1),
    EJECUTADO    = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND HECHA = 1),
    PENDIENTE    = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND HECHA = 0 AND FECHA >= @AHORA),
    ATRASADO     = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL),
    EN_EJECUCION = (SELECT COUNT(*) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND OT_ESTADO IN (2, 3)),
    OT_ABIERTAS  = (SELECT COUNT(*) FROM #OT WHERE ESTADO < 4 AND PROGRAMADA >= @M0 AND PROGRAMADA < @M1),
    OT_VENCIDAS  = (SELECT COUNT(*) FROM #OT WHERE ESTADO < 4 AND PROGRAMADA >= @M0 AND PROGRAMADA < @M1 AND PROGRAMADA < @AHORA),
    TIEMPO_PROM  = (SELECT ISNULL(AVG(DATEDIFF(MINUTE, CREADA, CIERRE)), 0) FROM #OT WHERE ESTADO = 4 AND CIERRE >= @M0 AND CIERRE < @M1),
    DURACION_MIN = (SELECT ISNULL(SUM(REAL), 0) FROM #OT WHERE ESTADO = 4 AND CIERRE >= @M0 AND CIERRE < @M1),
    BACKLOG_MIN  = (SELECT ISNULL(SUM(DURACION), 0) FROM #OT WHERE ESTADO < 4),
    AFECTADOS    = (SELECT COUNT(DISTINCT ACTIVO_ID) FROM #X WHERE FECHA >= @M0 AND FECHA < @M1 AND HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL)

/* ======================= 1 · serie de 6 meses ======================= */
;WITH M AS (SELECT 0 AS N UNION ALL SELECT N + 1 FROM M WHERE N < 5)
SELECT CONVERT(VARCHAR(7), DATEADD(MONTH, N, @SERIE0), 120) AS MES,
       CUMPLIMIENTO = (SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE CAST(ROUND(100.0 * SUM(CASE WHEN HECHA = 1 THEN 1 ELSE 0 END) / COUNT(*), 0) AS INT) END
                         FROM #X WHERE VENCIDA = 1 AND FECHA >= DATEADD(MONTH, N, @SERIE0) AND FECHA < DATEADD(MONTH, N + 1, @SERIE0))
FROM M ORDER BY N

/* ======================= 2 · por tipo de trabajo ======================= */
SELECT TIPO, COUNT(*) AS N, SUM(CAST(VENCIDA AS INT)) AS VENCIDAS, SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) AS CUMPLIDAS
FROM   #X WHERE FECHA >= @M0 AND FECHA < @M1 GROUP BY TIPO

/* ======================= 3 · por plan, inspección o tarea ======================= */
SELECT TOP 12 TIPO, ISNULL(NULLIF(REF, N''), TITULO) AS CLAVE, MAX(CASE WHEN TIPO = 'PLAN' THEN REF_NOMBRE ELSE TITULO END) AS NOMBRE, COUNT(*) AS N,
       SUM(CAST(VENCIDA AS INT)) AS VENCIDAS, SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) AS CUMPLIDAS,
       SUM(CASE WHEN HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL THEN 1 ELSE 0 END) AS ATRASADAS
FROM   #X WHERE FECHA >= @M0 AND FECHA < @M1
GROUP BY TIPO, ISNULL(NULLIF(REF, N''), TITULO)
ORDER BY CASE WHEN SUM(CAST(VENCIDA AS INT)) = 0 THEN 1 ELSE 0 END,
         1.0 * SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) / NULLIF(SUM(CAST(VENCIDA AS INT)), 0),
         SUM(CASE WHEN HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL THEN 1 ELSE 0 END) DESC

/* ======================= 4 · por activo ======================= */
SELECT TOP 8 ACTIVO_ID, MAX(ACTIVO_CODIGO) AS CODIGO, MAX(ACTIVO) AS NOMBRE, MAX(AREA) AS AREA, MAX(CRITICIDAD) AS CRITICIDAD, COUNT(*) AS N,
       SUM(CAST(VENCIDA AS INT)) AS VENCIDAS, SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) AS CUMPLIDAS,
       SUM(CASE WHEN HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL THEN 1 ELSE 0 END) AS ATRASADAS
FROM   #X WHERE FECHA >= @M0 AND FECHA < @M1
GROUP BY ACTIVO_ID
ORDER BY CASE WHEN SUM(CAST(VENCIDA AS INT)) = 0 THEN 1 ELSE 0 END,
         1.0 * SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) / NULLIF(SUM(CAST(VENCIDA AS INT)), 0)

/* ======================= 5 · por responsable ======================= */
SELECT RESPONSABLE, COUNT(*) AS N, SUM(CAST(VENCIDA AS INT)) AS VENCIDAS, SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) AS CUMPLIDAS,
       SUM(CASE WHEN HECHA = 0 AND FECHA < @AHORA AND OT_ID IS NULL THEN 1 ELSE 0 END) AS ATRASADAS
FROM   #X WHERE FECHA >= @M0 AND FECHA < @M1 AND RESPONSABLE <> N''
GROUP BY RESPONSABLE
ORDER BY CASE WHEN SUM(CAST(VENCIDA AS INT)) = 0 THEN 1 ELSE 0 END, 1.0 * SUM(CASE WHEN VENCIDA = 1 AND HECHA = 1 THEN 1 ELSE 0 END) / NULLIF(SUM(CAST(VENCIDA AS INT)), 0)
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_HOY]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @RESPONSABLE INT = NULL,
    @CRITICIDAD  INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATE = CAST(@AHORA AS DATE)
DECLARE @DESDE DATETIME = DATEADD(DAY, -40, CAST(@HOY AS DATETIME))
DECLARE @MES0 DATETIME = DATEADD(MONTH, -5, DATEADD(DAY, 1 - DAY(@HOY), CAST(@HOY AS DATETIME)))

/* ---- los activos que pasan los filtros ---- */
SELECT a.act_id AS ACTIVO_ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, a.act_cliente_instalacion AS PLANTA_ID, a.act_instalacion_area AS AREA_ID,
       ISNULL(a.act_criticidad_nivel, 1) AS CRIT, iar.iar_nombre AS AREA, cin.cin_nombre AS PLANTA
INTO   #ACT
FROM   [dbo].[Activo] a
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = a.act_cliente_instalacion
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1
  AND  (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND  (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND  (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)

/* ---- las ejecuciones (planes, inspecciones, tareas) del rango ---- */
CREATE TABLE #EJ (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, ESTADO INT, ACTIVO_ID INT, TITULO NVARCHAR(300), REF NVARCHAR(60), OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, RESPONSABLE INT)
INSERT INTO #EJ
SELECT 'PLAN', o.pmo_id, o.pmo_fecha_programada_utc, o.pmo_fecha_limite_utc, o.pmo_plan_ocurrencia_estado, o.pmo_activo, h.pmh_nombre, pma.pma_codigo,
       o.pmo_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, h.pmh_usuario_responsable
FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
JOIN   #ACT a ON a.ACTIVO_ID = o.pmo_activo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE  o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado NOT IN (6, 7)
  AND  o.pmo_fecha_programada_utc >= @DESDE AND o.pmo_fecha_programada_utc < DATEADD(DAY, 1, CAST(@HOY AS DATETIME))
INSERT INTO #EJ
SELECT 'INSPECCION', c.coc_id, c.coc_fecha_programada_utc, c.coc_fecha_limite_utc, c.coc_checklist_ocurrencia_estado, c.coc_activo, ISNULL(p.cpr_nombre, N'Inspección'), N'',
       NULL, NULL, NULL, p.cpr_usuario_responsable
FROM   [dbo].[Checklist_Ocurrencia] c
JOIN   #ACT a ON a.ACTIVO_ID = c.coc_activo
LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
WHERE  c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado NOT IN (6, 7)
  AND  c.coc_fecha_programada_utc >= @DESDE AND c.coc_fecha_programada_utc < DATEADD(DAY, 1, CAST(@HOY AS DATETIME))
INSERT INTO #EJ
SELECT 'TAREA', t.toc_id, t.toc_fecha_programada_utc, t.toc_fecha_limite_utc, t.toc_tarea_ocurrencia_estado, tr.tar_activo, tr.tar_titulo, tr.tar_codigo,
       t.toc_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, NULL
FROM   [dbo].[Tarea_Ocurrencia] t
JOIN   [dbo].[Tarea] tr ON tr.tar_id = t.toc_tarea
JOIN   #ACT a ON a.ACTIVO_ID = tr.tar_activo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = t.toc_orden_trabajo
WHERE  t.toc_cliente = @CLIENTE AND t.toc_habilitado = 1 AND t.toc_tarea_ocurrencia_estado NOT IN (6, 7)
  AND  t.toc_fecha_programada_utc >= @DESDE AND t.toc_fecha_programada_utc < DATEADD(DAY, 1, CAST(@HOY AS DATETIME))
IF @RESPONSABLE IS NOT NULL DELETE FROM #EJ WHERE ISNULL(RESPONSABLE, 0) <> @RESPONSABLE

/* una ejecución con OT cerrada cuenta como hecha; con OT en curso, como en curso */
UPDATE #EJ SET ESTADO = 4 WHERE OT_ESTADO = 4 AND ESTADO <> 4

/* ---- las OT abiertas y las del filtro ---- */
SELECT o.otr_id AS OT_ID, o.otr_correlativo AS NUMERO, o.otr_titulo AS TITULO, o.otr_activo AS ACTIVO_ID, o.otr_orden_trabajo_estado AS ESTADO,
       o.otr_fecha_programada_utc AS PROGRAMADA, o.otr_orden_trabajo_origen AS ORIGEN, ISNULL(o.otr_minuto_parada_activo, 0) AS PARADA,
       o.otr_fecha_cierre AS CIERRE, o.otr_fecha_creacion AS CREADA, o.otr_duracion_estimada_minuto AS DURACION,
       (SELECT TOP 1 a2.ota_usuario FROM [dbo].[Orden_Trabajo_Asignacion] a2 WHERE a2.ota_orden_trabajo = o.otr_id AND a2.ota_habilitado = 1 AND a2.ota_es_responsable = 1) AS RESPONSABLE
INTO   #OT
FROM   [dbo].[Orden_Trabajo] o
JOIN   #ACT a ON a.ACTIVO_ID = o.otr_activo
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
IF @RESPONSABLE IS NOT NULL DELETE FROM #OT WHERE ISNULL(RESPONSABLE, 0) <> @RESPONSABLE

/* ---- avisos sin tratar ---- */
SELECT v.AVISO, v.ORIGEN, v.TITULO, v.SEVERIDAD, v.ACTIVO_ID, v.FECHA, v.DETUVO
INTO   #AV
FROM   [dbo].[VW_AVISOS] v JOIN #ACT a ON a.ACTIVO_ID = v.ACTIVO_ID
WHERE  v.CLIENTE = @CLIENTE AND v.ESTADO = 'NUEVO'

/* ---- activos en riesgo: criticidad alta con una señal ---- */
SELECT a.ACTIVO_ID, a.CODIGO, a.NOMBRE, a.AREA, a.CRIT,
       CASE WHEN EXISTS (SELECT 1 FROM #OT x WHERE x.ACTIVO_ID = a.ACTIVO_ID AND x.ESTADO = 2 AND x.PARADA > 0) THEN N'Detenido por OT'
            WHEN EXISTS (SELECT 1 FROM #AV v WHERE v.ACTIVO_ID = a.ACTIVO_ID AND v.ORIGEN = 5) THEN N'SIGMA AI'
            ELSE N'Aviso alto o crítico' END AS SENAL
INTO   #RIESGO
FROM   #ACT a
WHERE  a.CRIT >= 3 AND (EXISTS (SELECT 1 FROM #AV v WHERE v.ACTIVO_ID = a.ACTIVO_ID AND (v.SEVERIDAD >= 3 OR v.ORIGEN = 5))
                         OR EXISTS (SELECT 1 FROM #OT x WHERE x.ACTIVO_ID = a.ACTIVO_ID AND x.ESTADO = 2 AND x.PARADA > 0))

/* ======================= 0 · indicadores ======================= */
SELECT
    CUMPLIMIENTO = (SELECT CASE WHEN COUNT(*) = 0 THEN 100 ELSE CAST(ROUND(100.0 * SUM(CASE WHEN ESTADO = 4 THEN 1 ELSE 0 END) / COUNT(*), 0) AS INT) END
                      FROM #EJ WHERE LIMITE < @AHORA OR (LIMITE IS NULL AND FECHA < @AHORA)),
    CUMPLIDAS    = (SELECT SUM(CASE WHEN ESTADO = 4 THEN 1 ELSE 0 END) FROM #EJ WHERE LIMITE < @AHORA OR (LIMITE IS NULL AND FECHA < @AHORA)),
    VENCIDAS_N   = (SELECT COUNT(*) FROM #EJ WHERE LIMITE < @AHORA OR (LIMITE IS NULL AND FECHA < @AHORA)),
    HOY_N        = (SELECT COUNT(*) FROM #EJ WHERE CAST(FECHA AS DATE) = @HOY) + (SELECT COUNT(*) FROM #OT o WHERE CAST(o.PROGRAMADA AS DATE) = @HOY AND o.ESTADO < 4 AND NOT EXISTS (SELECT 1 FROM #EJ e WHERE e.OT_ID = o.OT_ID)),
    HOY_HECHAS   = (SELECT COUNT(*) FROM #EJ WHERE CAST(FECHA AS DATE) = @HOY AND ESTADO = 4),
    HOY_CURSO    = (SELECT COUNT(*) FROM #EJ WHERE CAST(FECHA AS DATE) = @HOY AND (ESTADO = 3 OR OT_ESTADO IN (2, 3))),
    ATRASADAS    = (SELECT COUNT(*) FROM #EJ WHERE ESTADO NOT IN (4, 5) AND OT_ID IS NULL AND FECHA < @AHORA),
    OT_ABIERTAS  = (SELECT COUNT(*) FROM #OT WHERE ESTADO < 4),
    OT_PROGRESO  = (SELECT COUNT(*) FROM #OT WHERE ESTADO = 2),
    OT_VENCIDAS  = (SELECT COUNT(*) FROM #OT WHERE ESTADO < 4 AND PROGRAMADA < @AHORA),
    RIESGO       = (SELECT COUNT(*) FROM #RIESGO),
    SIN_OT       = (SELECT COUNT(*) FROM #EJ WHERE TIPO = 'PLAN' AND OT_ID IS NULL AND ESTADO NOT IN (4, 5) AND FECHA < @AHORA),
    AVISOS_N     = (SELECT COUNT(*) FROM #AV)

/* ======================= 1 · agenda de hoy ======================= */
SELECT TIPO, ID, FECHA, TITULO, REF, ESTADO, OT_ID, OT_NUMERO, OT_ESTADO, a.CODIGO AS ACTIVO_CODIGO, a.NOMBRE AS ACTIVO,
       (SELECT LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) FROM [dbo].[Usuario] u WHERE u.usu_id = e.RESPONSABLE) AS RESPONSABLE
FROM   #EJ e JOIN #ACT a ON a.ACTIVO_ID = e.ACTIVO_ID
WHERE  CAST(e.FECHA AS DATE) = @HOY
UNION ALL
SELECT 'OT', o.OT_ID, o.PROGRAMADA, o.TITULO, N'', 0, o.OT_ID, o.NUMERO, o.ESTADO, a.CODIGO, a.NOMBRE,
       (SELECT LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) FROM [dbo].[Usuario] u WHERE u.usu_id = o.RESPONSABLE)
FROM   #OT o JOIN #ACT a ON a.ACTIVO_ID = o.ACTIVO_ID
WHERE  CAST(o.PROGRAMADA AS DATE) = @HOY AND o.ESTADO < 4 AND NOT EXISTS (SELECT 1 FROM #EJ e WHERE e.OT_ID = o.OT_ID)
ORDER BY FECHA

/* ======================= 2 · atrasadas ======================= */
SELECT TOP 12 TIPO, ID, FECHA, TITULO, REF, a.CODIGO AS ACTIVO_CODIGO, DATEDIFF(DAY, FECHA, @AHORA) AS DIAS
FROM   #EJ e JOIN #ACT a ON a.ACTIVO_ID = e.ACTIVO_ID
WHERE  e.ESTADO NOT IN (4, 5) AND e.OT_ID IS NULL AND e.FECHA < @AHORA
ORDER BY e.FECHA

/* ======================= 3 · ejecuciones de plan sin OT ======================= */
SELECT TOP 200 ID, FECHA, TITULO, REF, a.CODIGO AS ACTIVO_CODIGO, a.NOMBRE AS ACTIVO
FROM   #EJ e JOIN #ACT a ON a.ACTIVO_ID = e.ACTIVO_ID
WHERE  e.TIPO = 'PLAN' AND e.OT_ID IS NULL AND e.ESTADO NOT IN (4, 5) AND e.FECHA < @AHORA
ORDER BY e.FECHA

/* ======================= 4 · OT vencidas ======================= */
SELECT TOP 8 o.OT_ID, o.NUMERO, o.TITULO, o.PROGRAMADA, a.CODIGO AS ACTIVO_CODIGO, DATEDIFF(DAY, o.PROGRAMADA, @AHORA) AS DIAS
FROM   #OT o JOIN #ACT a ON a.ACTIVO_ID = o.ACTIVO_ID
WHERE  o.ESTADO < 4 AND o.PROGRAMADA < @AHORA
ORDER BY o.PROGRAMADA

/* ======================= 5 · avisos por evaluar ======================= */
SELECT TOP 8 v.AVISO, v.ORIGEN, v.TITULO, v.SEVERIDAD, a.CODIGO AS ACTIVO_CODIGO, v.FECHA
FROM   #AV v JOIN #ACT a ON a.ACTIVO_ID = v.ACTIVO_ID
ORDER BY v.SEVERIDAD DESC, v.FECHA DESC

/* ======================= 6 · activos en riesgo ======================= */
SELECT TOP 8 ACTIVO_ID, CODIGO, NOMBRE, AREA, SENAL FROM #RIESGO ORDER BY CRIT DESC, CODIGO

/* ======================= 7 · estado de cada activo por área ======================= */
SELECT a.ACTIVO_ID, a.CODIGO, a.NOMBRE, a.AREA_ID, ISNULL(a.AREA, N'Sin área') AS AREA, a.PLANTA,
       CASE WHEN EXISTS (SELECT 1 FROM #OT o WHERE o.ACTIVO_ID = a.ACTIVO_ID AND o.ESTADO = 2 AND o.PARADA > 0) THEN 'DETENIDO'
            WHEN EXISTS (SELECT 1 FROM #OT o WHERE o.ACTIVO_ID = a.ACTIVO_ID AND o.ESTADO = 2) THEN 'MANTENCION'
            WHEN EXISTS (SELECT 1 FROM #EJ e WHERE e.ACTIVO_ID = a.ACTIVO_ID AND e.ESTADO NOT IN (4, 5) AND e.OT_ID IS NULL AND e.FECHA < @AHORA)
              OR EXISTS (SELECT 1 FROM #AV v WHERE v.ACTIVO_ID = a.ACTIVO_ID)
              OR EXISTS (SELECT 1 FROM #OT o WHERE o.ACTIVO_ID = a.ACTIVO_ID AND o.ESTADO < 4 AND o.PROGRAMADA < @AHORA) THEN 'ATENCION'
            WHEN EXISTS (SELECT 1 FROM #EJ e WHERE e.ACTIVO_ID = a.ACTIVO_ID AND CAST(e.FECHA AS DATE) = @HOY AND e.ESTADO NOT IN (4, 5))
              OR EXISTS (SELECT 1 FROM #OT o WHERE o.ACTIVO_ID = a.ACTIVO_ID AND o.ESTADO < 4 AND CAST(o.PROGRAMADA AS DATE) = @HOY) THEN 'PROGRAMADO'
            ELSE 'NORMAL' END AS ESTADO,
       (SELECT COUNT(*) FROM #EJ e WHERE e.ACTIVO_ID = a.ACTIVO_ID AND CAST(e.FECHA AS DATE) = @HOY) AS HOY_N,
       (SELECT COUNT(*) FROM #EJ e WHERE e.ACTIVO_ID = a.ACTIVO_ID AND e.ESTADO NOT IN (4, 5) AND e.OT_ID IS NULL AND e.FECHA < @AHORA) AS ATRASOS_N,
       (SELECT COUNT(*) FROM #OT o WHERE o.ACTIVO_ID = a.ACTIVO_ID AND o.ESTADO < 4) AS OT_N,
       (SELECT COUNT(*) FROM #AV v WHERE v.ACTIVO_ID = a.ACTIVO_ID) AS AVISOS_N
FROM   #ACT a
ORDER BY a.PLANTA, a.AREA, a.CODIGO

/* ======================= 8 · tendencia: 6 meses ======================= */
;WITH M AS (SELECT 0 AS N UNION ALL SELECT N + 1 FROM M WHERE N < 5)
SELECT CONVERT(VARCHAR(7), DATEADD(MONTH, N, @MES0), 120) AS MES,
       CUMPLIMIENTO = (SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE CAST(ROUND(100.0 * SUM(CASE WHEN x.pmo_plan_ocurrencia_estado = 4 THEN 1 ELSE 0 END) / COUNT(*), 0) AS INT) END
                         FROM [dbo].[Plan_Mantenimiento_Ocurrencia] x JOIN #ACT a ON a.ACTIVO_ID = x.pmo_activo
                        WHERE x.pmo_cliente = @CLIENTE AND x.pmo_habilitado = 1 AND x.pmo_plan_ocurrencia_estado NOT IN (6, 7)
                          AND x.pmo_fecha_programada_utc >= DATEADD(MONTH, N, @MES0) AND x.pmo_fecha_programada_utc < DATEADD(MONTH, N + 1, @MES0)
                          AND ISNULL(x.pmo_fecha_limite_utc, x.pmo_fecha_programada_utc) < @AHORA),
       BACKLOG_H = (SELECT CAST(ROUND(ISNULL(SUM(ISNULL(o.otr_duracion_estimada_minuto, 60)), 0) / 60.0, 0) AS INT)
                      FROM [dbo].[Orden_Trabajo] o JOIN #ACT a ON a.ACTIVO_ID = o.otr_activo
                     WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_fecha_creacion < DATEADD(MONTH, N + 1, @MES0)
                       AND (o.otr_fecha_cierre IS NULL OR o.otr_fecha_cierre >= DATEADD(MONTH, N + 1, @MES0))),
       RESOLUCION_H = (SELECT CAST(AVG(DATEDIFF(HOUR, o.otr_fecha_creacion, o.otr_fecha_cierre)) AS INT)
                         FROM [dbo].[Orden_Trabajo] o JOIN #ACT a ON a.ACTIVO_ID = o.otr_activo
                        WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_fecha_cierre >= DATEADD(MONTH, N, @MES0) AND o.otr_fecha_cierre < DATEADD(MONTH, N + 1, @MES0)),
       FALLAS = (SELECT COUNT(*) FROM [dbo].[Falla] f JOIN #ACT a ON a.ACTIVO_ID = f.fal_activo
                  WHERE f.fal_cliente = @CLIENTE AND f.fal_habilitado = 1 AND f.fal_fecha_deteccion_utc >= DATEADD(MONTH, N, @MES0) AND f.fal_fecha_deteccion_utc < DATEADD(MONTH, N + 1, @MES0))
FROM M ORDER BY N
RETURN 0
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
WHERE   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION) AND (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND   (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)
ORDER BY m.FECHA, a.act_codigo

SELECT iar.iar_id AS AREA_ID, iar.iar_nombre AS AREA, iar.iar_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA
FROM   [dbo].[Instalacion_Area] iar JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = iar.iar_cliente_instalacion
WHERE  iar.iar_cliente = @CLIENTE AND iar.iar_habilitado = 1 AND (@INSTALACION IS NULL OR iar.iar_cliente_instalacion = @INSTALACION) AND (@AREA IS NULL OR iar.iar_id IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
ORDER BY cin.cin_nombre, iar.iar_orden, iar.iar_nombre
RETURN 0
GO

-- Cobertura: una fila por equipo habilitado con cuántos planes PUBLICADOS lo
-- cubren. Filtra en servidor por tipo, área y criticidad; @VISTA elige
-- 'SIN' (ningún plan) o 'VARIOS' (dos o más).
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_COBERTURA]
    @CLIENTE INT,
    @INSTALACION INT = NULL,
    @DUPLICADOS BIT = 0,
    @TIPO INT = NULL,
    @AREA INT = NULL,
    @CRITICIDAD INT = NULL
AS
BEGIN
    SET NOCOUNT ON
    ;WITH planes AS (
        SELECT pa.pac_activo, p.pma_id, p.pma_codigo, p.pma_nombre
          FROM Plan_Mantenimiento_Activo pa
          JOIN Plan_Mantenimiento_Version v ON v.pmv_id=pa.pac_plan_mantenimiento_version
                                           AND v.pmv_plan_version_estado=2 AND v.pmv_habilitado=1
          JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento
                                   AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
         GROUP BY pa.pac_activo, p.pma_id, p.pma_codigo, p.pma_nombre
    ), cobertura AS (
        SELECT a.act_id, a.act_codigo, a.act_nombre, atp.ati_id, atp.ati_nombre, ci.cin_nombre,
               ar.iar_id, ar.iar_nombre, cr.crn_id, cr.crn_codigo, cr.crn_nombre,
               (SELECT COUNT(*) FROM planes x WHERE x.pac_activo=a.act_id) AS PLANES,
               STUFF((SELECT N'; ' + x.pma_codigo + N' · ' + x.pma_nombre FROM planes x
                       WHERE x.pac_activo=a.act_id ORDER BY x.pma_codigo
                         FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,N'') AS PLANES_NOMBRES
          FROM Activo a
          LEFT JOIN Activo_Tipo atp ON atp.ati_id=a.act_activo_tipo
          LEFT JOIN Cliente_Instalacion ci ON ci.cin_id=a.act_cliente_instalacion
          LEFT JOIN Instalacion_Area ar ON ar.iar_id=a.act_instalacion_area
          LEFT JOIN Criticidad_Nivel cr ON cr.crn_id=a.act_criticidad_nivel
         WHERE a.act_cliente=@CLIENTE AND a.act_habilitado=1
           AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
           AND (@TIPO IS NULL OR a.act_activo_tipo=@TIPO)
           AND (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
           AND (@CRITICIDAD IS NULL OR a.act_criticidad_nivel=@CRITICIDAD)
    )
    SELECT act_id AS ACTIVO_ID, act_codigo AS ACTIVO_CODIGO, act_nombre AS ACTIVO_NOMBRE,
           ati_id AS TIPO_ID, ati_nombre AS TIPO_NOMBRE, cin_nombre AS PLANTA_NOMBRE,
           iar_id AS AREA_ID, iar_nombre AS AREA_NOMBRE,
           crn_id AS CRITICIDAD_ID, crn_codigo AS CRITICIDAD_CODIGO, crn_nombre AS CRITICIDAD_NOMBRE,
           PLANES, ISNULL(PLANES_NOMBRES,'') AS PLANES_NOMBRES
      FROM cobertura
     WHERE (@DUPLICADOS=0 AND PLANES=0) OR (@DUPLICADOS=1 AND PLANES>=2)
     ORDER BY ISNULL(crn_id,0) DESC, cin_nombre, act_codigo
END
GO

PRINT '416_AREA_HIJAS aplicado.'
GO
