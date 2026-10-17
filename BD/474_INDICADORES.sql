/* ============================================================================
   474 · Indicadores de gestión (EP-18: HU-180, HU-181, HU-182, HU-183, HU-185) · 17-10-2026
   ----------------------------------------------------------------------------
   Mantenimiento › Indicadores: tablero (cumplimiento, disponibilidad, tiempo medio entre fallas,
   tiempo medio de reparación y órdenes pendientes de cierre) con su variación contra el período
   anterior, detalle de cada indicador, y costos por equipo y por centro de costo.

   · Cumplimiento = hechas / vencidas, medido contra la fecha original (reutiliza SEL_OPERACION_EJECUCIONES,
     la misma regla de Operación › Cumplimiento).
   · Disponibilidad = 1 − indisponibilidad NO planificada / tiempo del período (la planificada se informa aparte).
   · Tiempo medio entre fallas = tiempo operativo total / cantidad de fallas (se avisa si hay menos de 3 fallas).
   · Tiempo medio de reparación = promedio de la duración real de las correctivas cerradas.
   · Costos: repuestos consumidos + mano de obra + servicios de terceros, SIEMPRE separados por moneda.
   Permiso nuevo VER INDICADORES (a quien ya ve órdenes de trabajo) y menú bajo Mantenimiento.
   Aplicar con -I (QUOTED_IDENTIFIER). Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---------- minutos de indisponibilidad que caen dentro de [@D, @H) ---------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_INDISP_MINUTOS] (@CLIENTE INT, @D DATETIME, @H DATETIME)
RETURNS TABLE
AS
RETURN
SELECT  i.ain_id AS ID, i.ain_activo AS ACTIVO, i.ain_orden_trabajo AS OT, i.ain_falla AS FALLA, CAST(ISNULL(i.ain_planificada, 0) AS BIT) AS PLANIFICADA,
        i.ain_fecha_inicio_utc AS INICIO, i.ain_fecha_fin_utc AS FIN, i.ain_motivo AS MOTIVO,
        DATEDIFF(MINUTE,
                 CASE WHEN i.ain_fecha_inicio_utc > @D THEN i.ain_fecha_inicio_utc ELSE @D END,
                 CASE WHEN ISNULL(i.ain_fecha_fin_utc, [dbo].[FNC_AHORA]()) < @H THEN ISNULL(i.ain_fecha_fin_utc, [dbo].[FNC_AHORA]()) ELSE @H END) AS MINUTOS
FROM    [dbo].[Activo_Indisponibilidad] i
WHERE   i.ain_cliente = @CLIENTE AND i.ain_habilitado = 1
  AND   i.ain_fecha_inicio_utc < @H AND ISNULL(i.ain_fecha_fin_utc, [dbo].[FNC_AHORA]()) > @D
GO

/* ---------- tablero ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INDICADORES_TABLERO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @ACTIVO      INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATE = CAST(@AHORA AS DATE)
IF @HASTA IS NULL SET @HASTA = @HOY
IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -29, @HASTA)
IF @DESDE > @HASTA SET @DESDE = @HASTA
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))
DECLARE @LARGO INT = DATEDIFF(DAY, @D, @H)
DECLARE @D1 DATETIME = DATEADD(DAY, -@LARGO, @D), @H1 DATETIME = @D        -- período anterior, del mismo largo

SELECT a.act_id AS ACTIVO_ID INTO #ACT
FROM   [dbo].[Activo] a
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1
  AND  (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND  (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND  (@ACTIVO IS NULL OR a.act_id = @ACTIVO)
DECLARE @NACT INT = (SELECT COUNT(*) FROM #ACT)

/* ---- cumplimiento: ejecuciones del período actual y del anterior ---- */
CREATE TABLE #EJ (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, ESTADO_ID INT, SITUACION VARCHAR(12), ACTIVO_ID INT, ACTIVO_CODIGO NVARCHAR(100), ACTIVO NVARCHAR(300), AREA NVARCHAR(200), CRITICIDAD INT,
                 TITULO NVARCHAR(300), REF NVARCHAR(60), REF_NOMBRE NVARCHAR(300), ACTIVIDADES INT, PARADA BIT, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, HALLAZGOS INT, RESPONSABLE NVARCHAR(200))
DECLARE @DD DATE = CAST(@D1 AS DATE)
INSERT INTO #EJ EXEC [dbo].[SEL_OPERACION_EJECUCIONES] @CLIENTE = @CLIENTE, @INSTALACION = @INSTALACION, @AREA = @AREA, @DESDE = @DD, @HASTA = @HASTA
DELETE FROM #EJ WHERE SITUACION = 'CANCELADA' OR ACTIVO_ID NOT IN (SELECT ACTIVO_ID FROM #ACT)
SELECT *, CAST(CASE WHEN ISNULL(LIMITE, FECHA) < @AHORA THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
          CAST(CASE WHEN ESTADO_ID = 4 OR OT_ESTADO = 4 THEN 1 ELSE 0 END AS BIT) AS HECHA
INTO #X FROM #EJ

DECLARE @VEN0 INT = (SELECT COUNT(*) FROM #X WHERE FECHA >= @D AND FECHA < @H AND VENCIDA = 1)
DECLARE @HEC0 INT = (SELECT COUNT(*) FROM #X WHERE FECHA >= @D AND FECHA < @H AND VENCIDA = 1 AND HECHA = 1)
DECLARE @VEN1 INT = (SELECT COUNT(*) FROM #X WHERE FECHA >= @D1 AND FECHA < @H1 AND VENCIDA = 1)
DECLARE @HEC1 INT = (SELECT COUNT(*) FROM #X WHERE FECHA >= @D1 AND FECHA < @H1 AND VENCIDA = 1 AND HECHA = 1)

/* ---- disponibilidad, fallas y tiempo medio entre fallas ---- */
DECLARE @MIN0 BIGINT = CAST(@NACT AS BIGINT) * DATEDIFF(MINUTE, @D, CASE WHEN @H > @AHORA THEN @AHORA ELSE @H END)
DECLARE @MIN1 BIGINT = CAST(@NACT AS BIGINT) * DATEDIFF(MINUTE, @D1, @H1)
IF @MIN0 < 0 SET @MIN0 = 0
DECLARE @NP0 BIGINT = (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f WHERE f.PLANIFICADA = 0 AND f.ACTIVO IN (SELECT ACTIVO_ID FROM #ACT))
DECLARE @PL0 BIGINT = (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f WHERE f.PLANIFICADA = 1 AND f.ACTIVO IN (SELECT ACTIVO_ID FROM #ACT))
DECLARE @NP1 BIGINT = (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D1, @H1) f WHERE f.PLANIFICADA = 0 AND f.ACTIVO IN (SELECT ACTIVO_ID FROM #ACT))
DECLARE @FAL0 INT = (SELECT COUNT(*) FROM [dbo].[Falla] f WHERE f.fal_cliente = @CLIENTE AND f.fal_habilitado = 1 AND f.fal_fecha_descarte_utc IS NULL
                      AND f.fal_fecha_deteccion_utc >= @D AND f.fal_fecha_deteccion_utc < @H AND f.fal_activo IN (SELECT ACTIVO_ID FROM #ACT))
DECLARE @FAL1 INT = (SELECT COUNT(*) FROM [dbo].[Falla] f WHERE f.fal_cliente = @CLIENTE AND f.fal_habilitado = 1 AND f.fal_fecha_descarte_utc IS NULL
                      AND f.fal_fecha_deteccion_utc >= @D1 AND f.fal_fecha_deteccion_utc < @H1 AND f.fal_activo IN (SELECT ACTIVO_ID FROM #ACT))

/* ---- tiempo medio de reparación: correctivas cerradas ---- */
CREATE TABLE #COR (OT INT, ACTIVO INT, FECHA DATETIME, MINUTOS INT)
INSERT INTO #COR
SELECT o.otr_id, o.otr_activo, ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion)), o.otr_duracion_real_minuto
FROM   [dbo].[Orden_Trabajo] o
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_tipo = 2 AND o.otr_orden_trabajo_estado = 4
  AND  ISNULL(o.otr_duracion_real_minuto, 0) > 0 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT)

/* ---- pendientes de cierre: terminadas y aún no cerradas, hoy y al cierre del período anterior ---- */
DECLARE @PC0 INT = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado = 3 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT))
DECLARE @PC1 INT = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT)
                     AND o.otr_fecha_fin_real_utc IS NOT NULL AND o.otr_fecha_fin_real_utc < @H1 AND (o.otr_fecha_cierre IS NULL OR o.otr_fecha_cierre >= @H1))

SELECT
    DESDE = @DESDE, HASTA = @HASTA, DIAS = @LARGO, ACTIVOS = @NACT,
    CUMPL_ACT = CASE WHEN @VEN0 = 0 THEN NULL ELSE CAST(100.0 * @HEC0 / @VEN0 AS DECIMAL(6, 1)) END,
    CUMPL_ANT = CASE WHEN @VEN1 = 0 THEN NULL ELSE CAST(100.0 * @HEC1 / @VEN1 AS DECIMAL(6, 1)) END,
    CUMPL_VENCIDAS = @VEN0, CUMPL_HECHAS = @HEC0,
    DISP_ACT = CASE WHEN @MIN0 = 0 THEN NULL ELSE CAST(100.0 * (@MIN0 - @NP0) / @MIN0 AS DECIMAL(6, 2)) END,
    DISP_ANT = CASE WHEN @MIN1 = 0 THEN NULL ELSE CAST(100.0 * (@MIN1 - @NP1) / @MIN1 AS DECIMAL(6, 2)) END,
    DISP_NOPLAN_MIN = @NP0, DISP_PLAN_MIN = @PL0,
    FALLAS_ACT = @FAL0, FALLAS_ANT = @FAL1,
    MTBF_H_ACT = CASE WHEN @FAL0 = 0 THEN NULL ELSE CAST((@MIN0 - @NP0) / 60.0 / @FAL0 AS DECIMAL(12, 1)) END,
    MTBF_H_ANT = CASE WHEN @FAL1 = 0 THEN NULL ELSE CAST((@MIN1 - @NP1) / 60.0 / @FAL1 AS DECIMAL(12, 1)) END,
    MTBF_REPRESENTATIVO = CAST(CASE WHEN @FAL0 >= 3 THEN 1 ELSE 0 END AS BIT),
    MTTR_MIN_ACT = (SELECT CAST(AVG(CAST(MINUTOS AS FLOAT)) AS DECIMAL(12, 1)) FROM #COR WHERE FECHA >= @D AND FECHA < @H),
    MTTR_MIN_ANT = (SELECT CAST(AVG(CAST(MINUTOS AS FLOAT)) AS DECIMAL(12, 1)) FROM #COR WHERE FECHA >= @D1 AND FECHA < @H1),
    MTTR_N = (SELECT COUNT(*) FROM #COR WHERE FECHA >= @D AND FECHA < @H),
    PEND_ACT = @PC0, PEND_ANT = @PC1

/* ---- cumplimiento por área, para mirar dónde se atrasa ---- */
SELECT TOP 8 a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, COUNT(*) AS VENCIDAS, SUM(CASE WHEN x.HECHA = 1 THEN 1 ELSE 0 END) AS HECHAS
FROM   #X x JOIN [dbo].[Activo] a ON a.act_id = x.ACTIVO_ID
WHERE  x.FECHA >= @D AND x.FECHA < @H AND x.VENCIDA = 1
GROUP BY a.act_codigo, a.act_nombre
ORDER BY 1.0 * SUM(CASE WHEN x.HECHA = 1 THEN 1 ELSE 0 END) / COUNT(*), COUNT(*) DESC
RETURN 0
GO

/* ---------- detalle de un indicador (lo que lo compone) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INDICADOR_DETALLE]
    @CLIENTE     INT,
    @INDICADOR   VARCHAR(20),      -- CUMPLIMIENTO | DISPONIBILIDAD | MTBF | MTTR | PENDIENTES
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @ACTIVO      INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATE = CAST(@AHORA AS DATE)
IF @HASTA IS NULL SET @HASTA = @HOY
IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -29, @HASTA)
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

SELECT a.act_id AS ACTIVO_ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE INTO #ACT
FROM   [dbo].[Activo] a
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1
  AND  (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND  (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND  (@ACTIVO IS NULL OR a.act_id = @ACTIVO)

IF @INDICADOR = 'CUMPLIMIENTO'
BEGIN
    CREATE TABLE #EJ (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, ESTADO_ID INT, SITUACION VARCHAR(12), ACTIVO_ID INT, ACTIVO_CODIGO NVARCHAR(100), ACTIVO NVARCHAR(300), AREA NVARCHAR(200), CRITICIDAD INT,
                     TITULO NVARCHAR(300), REF NVARCHAR(60), REF_NOMBRE NVARCHAR(300), ACTIVIDADES INT, PARADA BIT, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, HALLAZGOS INT, RESPONSABLE NVARCHAR(200))
    INSERT INTO #EJ EXEC [dbo].[SEL_OPERACION_EJECUCIONES] @CLIENTE = @CLIENTE, @INSTALACION = @INSTALACION, @AREA = @AREA, @DESDE = @DESDE, @HASTA = @HASTA
    SELECT  e.TIPO, e.ID, e.ACTIVO_CODIGO AS CODIGO, e.ACTIVO AS ACTIVO, e.FECHA, e.TITULO AS DETALLE,
            CASE WHEN e.ESTADO_ID = 4 OR e.OT_ESTADO = 4 THEN 'Hecha' WHEN ISNULL(e.LIMITE, e.FECHA) < @AHORA THEN 'Vencida sin hacer' ELSE 'En plazo' END AS RESULTADO,
            e.OT_ID, e.OT_NUMERO
    FROM    #EJ e
    WHERE   e.SITUACION <> 'CANCELADA' AND e.ACTIVO_ID IN (SELECT ACTIVO_ID FROM #ACT) AND ISNULL(e.LIMITE, e.FECHA) < @AHORA
    ORDER BY CASE WHEN e.ESTADO_ID = 4 OR e.OT_ESTADO = 4 THEN 1 ELSE 0 END, e.FECHA DESC
END
ELSE IF @INDICADOR IN ('DISPONIBILIDAD', 'MTBF')
BEGIN
    SELECT  f.ID, a.CODIGO, a.NOMBRE AS ACTIVO, f.INICIO AS FECHA, f.FIN, f.MINUTOS,
            CASE WHEN f.PLANIFICADA = 1 THEN 'Planificada' ELSE 'No planificada' END AS RESULTADO,
            ISNULL(f.MOTIVO, N'') AS DETALLE, f.OT AS OT_ID, ot.otr_correlativo AS OT_NUMERO
    FROM    [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f
    JOIN    #ACT a ON a.ACTIVO_ID = f.ACTIVO
    LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = f.OT
    WHERE   f.MINUTOS > 0
    ORDER BY f.INICIO DESC

    -- por equipo: fallas, tiempo operativo y tiempo medio entre fallas
    SELECT  a.CODIGO, a.NOMBRE AS ACTIVO,
            (SELECT COUNT(*) FROM [dbo].[Falla] x WHERE x.fal_activo = a.ACTIVO_ID AND x.fal_habilitado = 1 AND x.fal_fecha_descarte_utc IS NULL AND x.fal_fecha_deteccion_utc >= @D AND x.fal_fecha_deteccion_utc < @H) AS FALLAS,
            DATEDIFF(MINUTE, @D, CASE WHEN @H > @AHORA THEN @AHORA ELSE @H END)
              - (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f WHERE f.ACTIVO = a.ACTIVO_ID AND f.PLANIFICADA = 0) AS MIN_OPERATIVOS,
            (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f WHERE f.ACTIVO = a.ACTIVO_ID AND f.PLANIFICADA = 0) AS MIN_NO_PLAN,
            (SELECT ISNULL(SUM(MINUTOS), 0) FROM [dbo].[FNC_INDISP_MINUTOS](@CLIENTE, @D, @H) f WHERE f.ACTIVO = a.ACTIVO_ID AND f.PLANIFICADA = 1) AS MIN_PLAN
    FROM    #ACT a
    ORDER BY a.CODIGO
END
ELSE IF @INDICADOR = 'MTTR'
BEGIN
    SELECT  o.otr_id AS ID, o.otr_correlativo AS OT_NUMERO, o.otr_id AS OT_ID, a.CODIGO, a.NOMBRE AS ACTIVO, o.otr_titulo AS DETALLE,
            ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion)) AS FECHA, o.otr_duracion_real_minuto AS MINUTOS, 'Correctiva cerrada' AS RESULTADO
    FROM    [dbo].[Orden_Trabajo] o JOIN #ACT a ON a.ACTIVO_ID = o.otr_activo
    WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_tipo = 2 AND o.otr_orden_trabajo_estado = 4 AND ISNULL(o.otr_duracion_real_minuto, 0) > 0
      AND   ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion)) >= @D AND ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion)) < @H
    ORDER BY FECHA DESC
END
ELSE IF @INDICADOR = 'PENDIENTES'
BEGIN
    SELECT  o.otr_id AS ID, o.otr_correlativo AS OT_NUMERO, o.otr_id AS OT_ID, a.CODIGO, a.NOMBRE AS ACTIVO, o.otr_titulo AS DETALLE,
            o.otr_fecha_fin_real_utc AS FECHA, DATEDIFF(DAY, o.otr_fecha_fin_real_utc, @AHORA) AS DIAS_ESPERA, 'En espera de cierre' AS RESULTADO
    FROM    [dbo].[Orden_Trabajo] o JOIN #ACT a ON a.ACTIVO_ID = o.otr_activo
    WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado = 3
    ORDER BY o.otr_fecha_fin_real_utc
END
RETURN 0
GO

/* ---------- costos ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INDICADORES_COSTOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @ACTIVO      INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATE = CAST(@AHORA AS DATE)
IF @HASTA IS NULL SET @HASTA = @HOY
IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -29, @HASTA)
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))
DECLARE @LARGO INT = DATEDIFF(DAY, @D, @H)
DECLARE @D1 DATETIME = DATEADD(DAY, -@LARGO, @D), @H1 DATETIME = @D

SELECT a.act_id AS ACTIVO_ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE INTO #ACT
FROM   [dbo].[Activo] a
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1
  AND  (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND  (@AREA IS NULL OR a.act_instalacion_area IN (SELECT ID FROM [dbo].[FNC_AREA_Y_HIJAS](@AREA)))
  AND  (@ACTIVO IS NULL OR a.act_id = @ACTIVO)

/* una fila por línea de costo: la fecha del costo es la del cierre de la orden (o la última que tenga) */
CREATE TABLE #C (OT INT, ACTIVO INT, CC INT, FECHA DATETIME, MONEDA NVARCHAR(10) COLLATE Latin1_General_CI_AI, TIPO CHAR(3), MONTO DECIMAL(18, 2))
INSERT INTO #C
SELECT o.otr_id, o.otr_activo, o.otr_centro_costo, ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, ISNULL(o.otr_fecha_inicio_real_utc, o.otr_fecha_creacion))),
       ISNULL((SELECT mon_codigo FROM [dbo].[Moneda] WHERE mon_id = r.ore_moneda), N'CLP'), 'REP', ISNULL(r.ore_cantidad_consumida, 0) * ISNULL(r.ore_costo_unitario, 0)
FROM   [dbo].[Orden_Trabajo_Repuesto] r JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = r.ore_orden_trabajo
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND r.ore_habilitado = 1 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT)
INSERT INTO #C
SELECT o.otr_id, o.otr_activo, o.otr_centro_costo, ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, ISNULL(o.otr_fecha_inicio_real_utc, o.otr_fecha_creacion))),
       ISNULL((SELECT mon_codigo FROM [dbo].[Moneda] WHERE mon_id = m.omo_moneda), N'CLP'), 'MO ', ISNULL(m.omo_minuto, 0) / 60.0 * ISNULL(m.omo_costo_hora, 0)
FROM   [dbo].[Orden_Trabajo_Mano_Obra] m JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = m.omo_orden_trabajo
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT)
INSERT INTO #C
SELECT o.otr_id, o.otr_activo, o.otr_centro_costo, ISNULL(o.otr_fecha_cierre, ISNULL(o.otr_fecha_fin_real_utc, ISNULL(o.otr_fecha_inicio_real_utc, o.otr_fecha_creacion))),
       ISNULL((SELECT mon_codigo FROM [dbo].[Moneda] WHERE mon_id = s.ots_moneda), N'CLP'), 'SRV', ISNULL(s.ots_monto, 0)
FROM   [dbo].[Orden_Trabajo_Servicio] s JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND s.ots_habilitado = 1 AND o.otr_activo IN (SELECT ACTIVO_ID FROM #ACT)

/* 0 · por equipo y moneda */
SELECT  a.CODIGO, a.NOMBRE AS ACTIVO, c.MONEDA,
        SUM(CASE WHEN c.TIPO = 'REP' THEN c.MONTO ELSE 0 END) AS REPUESTOS,
        SUM(CASE WHEN c.TIPO = 'MO ' THEN c.MONTO ELSE 0 END) AS MANO_OBRA,
        SUM(CASE WHEN c.TIPO = 'SRV' THEN c.MONTO ELSE 0 END) AS SERVICIOS,
        SUM(c.MONTO) AS TOTAL, COUNT(DISTINCT c.OT) AS ORDENES
FROM    #C c JOIN #ACT a ON a.ACTIVO_ID = c.ACTIVO
WHERE   c.FECHA >= @D AND c.FECHA < @H
GROUP BY a.CODIGO, a.NOMBRE, c.MONEDA
HAVING  SUM(c.MONTO) <> 0
ORDER BY c.MONEDA, SUM(c.MONTO) DESC

/* 1 · por centro de costo: cada centro suma el de sus centros dependientes */
;WITH T AS (
    SELECT cco_id AS RAIZ, cco_id AS ID, 0 AS NIVEL FROM [dbo].[Centro_Costo] WHERE cco_cliente = @CLIENTE AND cco_habilitado = 1
    UNION ALL
    SELECT T.RAIZ, h.cco_id, T.NIVEL + 1 FROM [dbo].[Centro_Costo] h JOIN T ON h.cco_centro_costo_padre = T.ID WHERE h.cco_habilitado = 1 AND T.NIVEL < 20
)
SELECT  r.cco_codigo AS CODIGO, r.cco_nombre AS CENTRO, p.cco_codigo AS PADRE_CODIGO, c.MONEDA,
        SUM(CASE WHEN c.CC = r.cco_id THEN c.MONTO ELSE 0 END) AS PROPIO,
        SUM(CASE WHEN c.CC <> r.cco_id THEN c.MONTO ELSE 0 END) AS DEPENDIENTES,
        SUM(c.MONTO) AS TOTAL
FROM    T
JOIN    [dbo].[Centro_Costo] r ON r.cco_id = T.RAIZ
LEFT JOIN [dbo].[Centro_Costo] p ON p.cco_id = r.cco_centro_costo_padre
JOIN    #C c ON c.CC = T.ID AND c.FECHA >= @D AND c.FECHA < @H
GROUP BY r.cco_id, r.cco_codigo, r.cco_nombre, p.cco_codigo, c.MONEDA
HAVING  SUM(c.MONTO) <> 0
ORDER BY c.MONEDA, SUM(c.MONTO) DESC

/* 2 · comparación entre períodos, por moneda */
SELECT  m.MONEDA,
        ISNULL(a.TOTAL, 0) AS TOTAL_ACT, ISNULL(b.TOTAL, 0) AS TOTAL_ANT,
        ISNULL(a.TOTAL, 0) - ISNULL(b.TOTAL, 0) AS VARIACION,
        CASE WHEN ISNULL(b.TOTAL, 0) = 0 THEN NULL ELSE CAST(100.0 * (ISNULL(a.TOTAL, 0) - b.TOTAL) / b.TOTAL AS DECIMAL(10, 1)) END AS VARIACION_PCT,
        ISNULL(a.REP, 0) AS REP_ACT, ISNULL(a.MO, 0) AS MO_ACT, ISNULL(a.SRV, 0) AS SRV_ACT
FROM    (SELECT DISTINCT MONEDA FROM #C WHERE FECHA >= @D1 AND FECHA < @H) m
LEFT JOIN (SELECT MONEDA, SUM(MONTO) TOTAL, SUM(CASE WHEN TIPO = 'REP' THEN MONTO ELSE 0 END) REP, SUM(CASE WHEN TIPO = 'MO ' THEN MONTO ELSE 0 END) MO, SUM(CASE WHEN TIPO = 'SRV' THEN MONTO ELSE 0 END) SRV
           FROM #C WHERE FECHA >= @D AND FECHA < @H GROUP BY MONEDA) a ON a.MONEDA = m.MONEDA
LEFT JOIN (SELECT MONEDA, SUM(MONTO) TOTAL FROM #C WHERE FECHA >= @D1 AND FECHA < @H1 GROUP BY MONEDA) b ON b.MONEDA = m.MONEDA
ORDER BY m.MONEDA
RETURN 0
GO

/* ---------- áreas y equipos para los filtros ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INDICADORES_FILTROS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT iar.iar_id AS ID, iar.iar_nombre AS NOMBRE, iar.iar_area_padre AS PADRE
FROM   [dbo].[Instalacion_Area] iar
JOIN   [dbo].[Cliente_Instalacion] ci ON ci.cin_id = iar.iar_cliente_instalacion
WHERE  ci.cin_cliente = @CLIENTE AND iar.iar_habilitado = 1 AND (@INSTALACION IS NULL OR iar.iar_cliente_instalacion = @INSTALACION)
ORDER BY iar.iar_nombre
SELECT a.act_id AS ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, a.act_instalacion_area AS AREA
FROM   [dbo].[Activo] a
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
ORDER BY a.act_codigo
RETURN 0
GO

/* ---------- permiso, perfiles y menú ---------- */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()
MERGE [dbo].[Permiso] AS D
USING (VALUES ('VER INDICADORES', 'Ver los indicadores de gestión', 'MANTENIMIENTO', 2,
               'Permite ver el tablero de indicadores de mantenimiento (cumplimiento, disponibilidad, tiempo medio entre fallas y de reparación, pendientes de cierre) y los costos.')
) AS O (codigo, nombre, modulo, ambito, descripcion)
   ON D.prm_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion)
    VALUES (O.codigo, O.nombre, O.modulo, O.ambito, O.descripcion, @ROOT, @AHORA)
WHEN MATCHED THEN
    UPDATE SET D.prm_nombre = O.nombre, D.prm_modulo = O.modulo, D.prm_descripcion = O.descripcion;
GO
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()
INSERT [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT DISTINCT pp.ppe_perfil, nuevo.prm_id, @ROOT, @AHORA
FROM   [dbo].[Perfil_Permiso] pp
JOIN   [dbo].[Permiso] ver ON ver.prm_id = pp.ppe_permiso AND ver.prm_codigo = N'VER ORDENES TRABAJO'
CROSS JOIN (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER INDICADORES') nuevo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = nuevo.prm_id)
GO
DECLARE @MANT INT = 2154
INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden], [mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT N'Indicadores', N'Cumplimiento, disponibilidad, tiempos medios y costos de mantenimiento', 3, @MANT, 7,
       N'~/View/Mantenimiento/Indicadores/Indicadores.aspx', 1, N'mdi mdi-chart-line', p.[prm_id], 1
FROM   [dbo].[Permiso] p
WHERE  p.[prm_codigo] = N'VER INDICADORES'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m WHERE m.[mnu_link] = N'~/View/Mantenimiento/Indicadores/Indicadores.aspx')
GO
PRINT '474_INDICADORES aplicado.'
GO
