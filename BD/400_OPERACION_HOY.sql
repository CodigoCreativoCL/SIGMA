SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   400 · Operación › Hoy · 09-10-2026  (parte d)

   SEL_OPERACION_HOY junta, en una sola lectura, lo que el centro de control de Operación
   necesita para el día: la agenda, lo atrasado, las OT y el estado por área.

   Una EJECUCIÓN es lo programado: la ocurrencia de un plan, de una inspección o de una tarea.
   Las fechas están en HORA DE LA PLANTA (FNC_AHORA), igual que en Planificación.
   Estados que cuentan: hecha = 4 (COMPLETADA o su OT cerrada); sin efecto = 6 (CANCELADA) y
   7 (REPROGRAMADA); «atrasada» = no hecha, sin OT y con la fecha ya pasada.

   Filtros (todos opcionales): planta, área, responsable y criticidad del activo.

   Devuelve:
     0 · los indicadores
     1 · la agenda de hoy (ejecuciones y OT de hoy)
     2 · lo atrasado (hasta 40 días atrás) con su tipo
     3 · ejecuciones de plan que ya deberían tener OT
     4 · OT vencidas
     5 · avisos sin tratar (fallas, hallazgos) por evaluar
     6 · activos en riesgo
     7 · estado de cada activo por área
     8 · tendencia mensual (6 meses)
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
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
  AND  (@AREA IS NULL OR a.act_instalacion_area = @AREA)
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
/* ---- las áreas de la planta, para el filtro de Operación ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_AREAS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
/* RUTA = «Planta › área padre › …» (sin la propia área): así «Línea 1» se distingue de otra «Línea 1». */
;WITH T AS (
    SELECT iar.iar_id AS ID, iar.iar_nombre AS NOMBRE, iar.iar_area_padre AS PADRE, iar.iar_cliente_instalacion AS PLANTA_ID, iar.iar_orden AS ORDEN,
           CAST(N'' AS NVARCHAR(500)) AS RUTA, CAST(RIGHT('0000' + CAST(iar.iar_orden AS VARCHAR(4)), 4) + iar.iar_nombre AS NVARCHAR(900)) AS CLAVE
    FROM   [dbo].[Instalacion_Area] iar
    WHERE  iar.iar_cliente = @CLIENTE AND iar.iar_habilitado = 1 AND iar.iar_area_padre IS NULL
    UNION ALL
    SELECT h.iar_id, h.iar_nombre, h.iar_area_padre, h.iar_cliente_instalacion, h.iar_orden,
           CAST(CASE WHEN t.RUTA = N'' THEN t.NOMBRE ELSE t.RUTA + N' › ' + t.NOMBRE END AS NVARCHAR(500)),
           CAST(t.CLAVE + N'/' + RIGHT('0000' + CAST(h.iar_orden AS VARCHAR(4)), 4) + h.iar_nombre AS NVARCHAR(900))
    FROM   [dbo].[Instalacion_Area] h JOIN T t ON t.ID = h.iar_area_padre
    WHERE  h.iar_cliente = @CLIENTE AND h.iar_habilitado = 1
)
SELECT t.ID, t.NOMBRE, cin.cin_nombre AS PLANTA, t.RUTA, cin.cin_nombre + CASE WHEN t.RUTA = N'' THEN N'' ELSE N' › ' + t.RUTA END AS UBICACION
FROM   T t JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = t.PLANTA_ID
WHERE  (@INSTALACION IS NULL OR t.PLANTA_ID = @INSTALACION)
ORDER BY cin.cin_nombre, t.CLAVE
OPTION (MAXRECURSION 20)
RETURN 0
GO
PRINT '400_OPERACION_HOY aplicado.'
GO
