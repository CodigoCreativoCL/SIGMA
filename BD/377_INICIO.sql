USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     INICIO DE SIGMA (Default.aspx) · PROPUESTA 1: ACCESOS DIRECTOS POR USUARIO Y DATOS EN VIVO.
-- =============================================
-- POR QUE
--   El inicio se arma con cifras reales: ninguna se escribe a mano. Todo sale de estos SP y,
--   mientras no haya datos (hoy no hay ordenes de trabajo ni predicciones), la pantalla muestra
--   su estado vacio.
--
--   Usuario_Acceso_Directo ....... los accesos directos que cada persona eligio (por cliente).
--   SEL_INICIO_ACCESOS / UPD_INICIO_ACCESOS ... leer y guardar esa eleccion (lista separada por comas).
--   SEL_INICIO_RESUMEN ........... las cifras de las tarjetas de acceso y del widget SIGMA AI.
--   SEL_INICIO_INDICADORES ....... OT abiertas, cumplimiento del preventivo, disponibilidad, MTTR (+ 8 semanas).
--   SEL_INICIO_ORDENES ........... las 5 ordenes de trabajo mas recientes.
--   SEL_INICIO_HOY ............... las tareas de hoy de la persona.
--   SEL_INICIO_PREDICCIONES ...... predicciones activas, sus razones, la curva del activo y las cifras del modelo.
--   UPD_INICIO_PREDICCION_DESCARTAR  descarta una prediccion para que el modelo aprenda.
--   Las horas de las tablas estan en UTC: aqui se convierten a la hora de la plataforma (FNC_AHORA).
-- TODO IDEMPOTENTE.
-- =============================================

IF OBJECT_ID('dbo.Usuario_Acceso_Directo', 'U') IS NULL
CREATE TABLE [dbo].[Usuario_Acceso_Directo](
    uad_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario_Acceso_Directo PRIMARY KEY,
    uad_cliente INT NOT NULL,
    uad_usuario INT NOT NULL,
    uad_modulo  NVARCHAR(30) NOT NULL,
    uad_orden   INT NOT NULL,
    uad_fecha   DATETIME NOT NULL CONSTRAINT DF_UAD_FECHA DEFAULT GETUTCDATE(),
    CONSTRAINT UQ_Usuario_Acceso_Directo UNIQUE (uad_cliente, uad_usuario, uad_modulo)
)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_ACCESOS]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SELECT uad_modulo AS MODULO, uad_orden AS ORDEN
FROM   [dbo].[Usuario_Acceso_Directo]
WHERE  uad_cliente = @CLIENTE AND uad_usuario = @USUARIO
ORDER BY uad_orden
GO

/* Reemplaza la eleccion. @MODULOS es una lista separada por comas; «-» sola = «no quiero ninguno». */
CREATE OR ALTER PROCEDURE [dbo].[UPD_INICIO_ACCESOS]
    @CLIENTE INT,
    @USUARIO INT,
    @MODULOS NVARCHAR(400)
AS
SET NOCOUNT ON
DELETE FROM [dbo].[Usuario_Acceso_Directo] WHERE uad_cliente = @CLIENTE AND uad_usuario = @USUARIO
INSERT INTO [dbo].[Usuario_Acceso_Directo] (uad_cliente, uad_usuario, uad_modulo, uad_orden)
SELECT @CLIENTE, @USUARIO, m.v, m.n
FROM (SELECT LTRIM(RTRIM(value)) AS v, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS n FROM STRING_SPLIT(ISNULL(@MODULOS, N''), N',')) m
WHERE m.v <> N'' AND LEN(m.v) <= 30
GO

/* Cifras de las tarjetas y del widget SIGMA AI. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_RESUMEN]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @SEM1 DATETIME = DATEADD(MINUTE, -@OFF, CAST(DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @HOY) % 7), @HOY) AS DATETIME))   -- lunes de esta semana (hora local, en UTC)
SELECT
    BODEGAS      = (SELECT COUNT(*) FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE AND bod_habilitado = 1),
    ACTIVOS      = (SELECT COUNT(*) FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_habilitado = 1 AND act_fecha_baja IS NULL),
    OT_TOTAL     = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1),
    OT_ABIERTAS  = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4),
    OT_VENCIDAS  = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_fecha_programada_utc < @UTC),
    OT_ALTA      = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_orden_trabajo_prioridad >= 3),
    PLANES       = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1),
    PLAN_SEMANA  = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_cliente = @CLIENTE AND pmo_habilitado = 1 AND pmo_plan_ocurrencia_estado NOT IN (6, 7)
                     AND pmo_fecha_programada_utc >= @SEM1 AND pmo_fecha_programada_utc < DATEADD(DAY, 7, @SEM1)),
    SEMANA_ISO   = DATEPART(ISO_WEEK, @HOY),
    TICKETS      = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado
                     WHERE t.stk_cliente = @CLIENTE AND t.stk_usuario = @USUARIO AND t.stk_habilitado = 1 AND e.ses_abierto = 1),
    PRED_NUEVAS  = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL AND pre_fecha_calculo_utc >= DATEADD(HOUR, -24, @UTC)),
    PRED_ACTIVAS = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL
                     AND (pre_fecha_vigencia_hasta_utc IS NULL OR pre_fecha_vigencia_hasta_utc >= @UTC)),
    DIAS_LECTURAS = ISNULL((SELECT DATEDIFF(DAY, MIN(aml_fecha_lectura_utc), @UTC) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_cliente = @CLIENTE), 0),
    SENALES_MIN  = CAST(ISNULL((SELECT COUNT(*) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_cliente = @CLIENTE AND aml_fecha_lectura_utc >= DATEADD(HOUR, -1, @UTC)), 0) / 60.0 AS DECIMAL(9,1)),
    ACTIVOS_CON_LECTURA = (SELECT COUNT(DISTINCT m.ame_activo) FROM [dbo].[Activo_Medidor_Lectura] l JOIN [dbo].[Activo_Medidor] m ON m.ame_id = l.aml_activo_medidor
                            WHERE l.aml_cliente = @CLIENTE AND l.aml_fecha_lectura_utc >= DATEADD(DAY, -7, @UTC))
GO

/* Las cifras del widget SIGMA AI, de toda la empresa o solo de las plantas de @PLANTAS (lista separada por comas). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_AI]
    @CLIENTE INT,
    @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
SELECT act_id INTO #a FROM [dbo].[Activo]
WHERE  act_cliente = @CLIENTE AND act_habilitado = 1 AND act_fecha_baja IS NULL
  AND  (@PLANTAS IS NULL OR act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N',')))
SELECT
    AI_ACTIVOS   = (SELECT COUNT(*) FROM #a),
    PRED_NUEVAS  = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL AND pre_fecha_calculo_utc >= DATEADD(HOUR, -24, @UTC) AND pre_activo IN (SELECT act_id FROM #a)),
    PRED_ACTIVAS = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL AND pre_activo IN (SELECT act_id FROM #a)
                     AND (pre_fecha_vigencia_hasta_utc IS NULL OR pre_fecha_vigencia_hasta_utc >= @UTC)),
    DIAS_LECTURAS = ISNULL((SELECT DATEDIFF(DAY, MIN(l.aml_fecha_lectura_utc), @UTC) FROM [dbo].[Activo_Medidor_Lectura] l JOIN [dbo].[Activo_Medidor] m ON m.ame_id = l.aml_activo_medidor WHERE l.aml_cliente = @CLIENTE AND m.ame_activo IN (SELECT act_id FROM #a)), 0),
    SENALES_MIN  = CAST(ISNULL((SELECT COUNT(*) FROM [dbo].[Activo_Medidor_Lectura] l JOIN [dbo].[Activo_Medidor] m ON m.ame_id = l.aml_activo_medidor WHERE l.aml_cliente = @CLIENTE AND l.aml_fecha_lectura_utc >= DATEADD(HOUR, -1, @UTC) AND m.ame_activo IN (SELECT act_id FROM #a)), 0) / 60.0 AS DECIMAL(9,1)),
    ACTIVOS_CON_LECTURA = (SELECT COUNT(DISTINCT m.ame_activo) FROM [dbo].[Activo_Medidor_Lectura] l JOIN [dbo].[Activo_Medidor] m ON m.ame_id = l.aml_activo_medidor
                            WHERE l.aml_cliente = @CLIENTE AND l.aml_fecha_lectura_utc >= DATEADD(DAY, -7, @UTC) AND m.ame_activo IN (SELECT act_id FROM #a))
GO

/* OT abiertas, cumplimiento del preventivo, disponibilidad y MTTR. El 2.o resultado son las 8 ultimas semanas. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_INDICADORES]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @ACTIVOS INT = (SELECT COUNT(*) FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_habilitado = 1 AND act_fecha_baja IS NULL)
DECLARE @M0 DATETIME = DATEADD(DAY, -30, @UTC), @M1 DATETIME = DATEADD(DAY, -60, @UTC)

DECLARE @cum_t INT = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_cliente = @CLIENTE AND pmo_habilitado = 1 AND pmo_plan_ocurrencia_estado NOT IN (6, 7)
                       AND pmo_fecha_programada_utc >= @M0 AND pmo_fecha_programada_utc < @UTC)
DECLARE @cum_ok INT = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_cliente = @CLIENTE AND pmo_habilitado = 1 AND pmo_plan_ocurrencia_estado = 4
                        AND pmo_fecha_programada_utc >= @M0 AND pmo_fecha_programada_utc < @UTC)

/* Paradas y reparaciones de ordenes cerradas en cada ventana de 30 dias. */
DECLARE @par0 INT, @par1 INT, @n_par0 INT, @n_par1 INT, @mttr0 DECIMAL(9,2), @mttr1 DECIMAL(9,2)
SELECT @par0 = SUM(otr_minuto_parada_activo), @n_par0 = COUNT(otr_minuto_parada_activo), @mttr0 = AVG(CASE WHEN otr_duracion_real_minuto > 0 THEN otr_duracion_real_minuto END) / 60.0
FROM   [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado = 4 AND otr_fecha_fin_real_utc >= @M0 AND otr_fecha_fin_real_utc < @UTC
SELECT @par1 = SUM(otr_minuto_parada_activo), @n_par1 = COUNT(otr_minuto_parada_activo), @mttr1 = AVG(CASE WHEN otr_duracion_real_minuto > 0 THEN otr_duracion_real_minuto END) / 60.0
FROM   [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado = 4 AND otr_fecha_fin_real_utc >= @M1 AND otr_fecha_fin_real_utc < @M0

SELECT
    OT_TOTAL    = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1),
    OT_ABIERTAS = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4),
    OT_VENCIDAS = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_fecha_programada_utc < @UTC),
    OT_ALTA     = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_orden_trabajo_prioridad >= 3),
    CUMPLIMIENTO = CAST(CASE WHEN @cum_t > 0 THEN 100.0 * @cum_ok / @cum_t END AS DECIMAL(5,1)),
    CUMPLIMIENTO_N = @cum_t,
    SEMANA_ISO  = DATEPART(ISO_WEEK, @HOY),
    DISPONIBILIDAD = CAST(CASE WHEN @n_par0 > 0 AND @ACTIVOS > 0 THEN 100.0 * (1 - @par0 / (@ACTIVOS * 43200.0)) END AS DECIMAL(5,2)),
    DISPONIBILIDAD_ANT = CAST(CASE WHEN @n_par1 > 0 AND @ACTIVOS > 0 THEN 100.0 * (1 - @par1 / (@ACTIVOS * 43200.0)) END AS DECIMAL(5,2)),
    MTTR_H      = @mttr0,
    MTTR_H_ANT  = @mttr1

/* 8 semanas (la ultima es la actual): OT abiertas al cierre de la semana, MTTR y disponibilidad. */
;WITH s AS (SELECT TOP 8 ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS k FROM sys.all_objects),
w AS (SELECT k, DATEADD(DAY, -7 * (8 - k + 1), @UTC) AS ini, DATEADD(DAY, -7 * (8 - k), @UTC) AS fin FROM s)
SELECT  w.k AS SEMANA,
        ABIERTAS = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_fecha_creacion <= w.fin
                     AND (o.otr_fecha_fin_real_utc IS NULL OR o.otr_fecha_fin_real_utc > w.fin) AND (o.otr_orden_trabajo_estado < 4 OR o.otr_fecha_fin_real_utc > w.fin)),
        MTTR_H = (SELECT AVG(CASE WHEN o.otr_duracion_real_minuto > 0 THEN o.otr_duracion_real_minuto END) / 60.0 FROM [dbo].[Orden_Trabajo] o
                   WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado = 4 AND o.otr_fecha_fin_real_utc >= w.ini AND o.otr_fecha_fin_real_utc < w.fin),
        PARADA_MIN = (SELECT SUM(o.otr_minuto_parada_activo) FROM [dbo].[Orden_Trabajo] o
                       WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado = 4 AND o.otr_fecha_fin_real_utc >= w.ini AND o.otr_fecha_fin_real_utc < w.fin),
        ACTIVOS = @ACTIVOS
FROM w ORDER BY w.k
GO

/* Las 5 ordenes de trabajo mas recientes. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_ORDENES]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
SELECT TOP 5
    o.otr_id AS ID, o.otr_correlativo AS CORRELATIVO, o.otr_titulo AS TITULO,
    ISNULL(a.act_nombre, N'') AS ACTIVO, ISNULL(t.ott_nombre, N'') AS TIPO,
    ISNULL(LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))), N'') AS RESPONSABLE,
    p.opr_codigo AS PRIORIDAD, o.otr_orden_trabajo_estado AS ESTADO,
    CAST(CASE WHEN o.otr_orden_trabajo_estado < 4 AND o.otr_fecha_programada_utc < @UTC THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
    DATEADD(MINUTE, @OFF, o.otr_fecha_programada_utc) AS PROGRAMADA,
    DATEDIFF(DAY, o.otr_fecha_programada_utc, @UTC) AS DIAS_VENCIDA
FROM   [dbo].[Orden_Trabajo] o
LEFT JOIN [dbo].[Activo] a ON a.act_id = o.otr_activo
LEFT JOIN [dbo].[Orden_Trabajo_Tipo] t ON t.ott_id = o.otr_orden_trabajo_tipo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = o.otr_usuario_responsable
LEFT JOIN [dbo].[Orden_Trabajo_Prioridad] p ON p.opr_id = o.otr_orden_trabajo_prioridad
WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
ORDER BY o.otr_fecha_creacion DESC, o.otr_id DESC
GO

/* Las tareas de hoy de la persona: sus ordenes y los preventivos del dia. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_HOY]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
SELECT * FROM (
    SELECT  DATEADD(MINUTE, @OFF, o.otr_fecha_programada_utc) AS HORA, o.otr_titulo AS TITULO,
            N'OT ' + CAST(o.otr_correlativo AS NVARCHAR(20)) + ISNULL(N' · ' + a.act_nombre, N'') AS DETALLE,
            CASE WHEN o.otr_orden_trabajo_estado = 4 THEN N'done' WHEN o.otr_orden_trabajo_estado IN (2, 3) THEN N'now' ELSE N'next' END AS ESTADO
    FROM    [dbo].[Orden_Trabajo] o LEFT JOIN [dbo].[Activo] a ON a.act_id = o.otr_activo
    WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
      AND   CAST(DATEADD(MINUTE, @OFF, o.otr_fecha_programada_utc) AS DATE) = @HOY
      AND   (o.otr_usuario_responsable = @USUARIO OR EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] s WHERE s.ota_orden_trabajo = o.otr_id AND s.ota_usuario = @USUARIO AND s.ota_habilitado = 1))
    UNION ALL
    SELECT  DATEADD(MINUTE, @OFF, m.pmo_fecha_programada_utc), ISNULL(pl.pma_nombre, N'Mantenimiento preventivo'),
            N'Plan preventivo' + ISNULL(N' · ' + a.act_nombre, N''),
            CASE WHEN m.pmo_plan_ocurrencia_estado = 4 THEN N'done' WHEN m.pmo_plan_ocurrencia_estado = 3 THEN N'now' ELSE N'next' END
    FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] m
    LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = m.pmo_plan_mantenimiento_hito
    LEFT JOIN [dbo].[Plan_Mantenimiento_Version] pv ON pv.pmv_id = h.pmh_plan_mantenimiento_version
    LEFT JOIN [dbo].[Plan_Mantenimiento] pl ON pl.pma_id = pv.pmv_plan_mantenimiento
    LEFT JOIN [dbo].[Activo] a ON a.act_id = m.pmo_activo
    WHERE   m.pmo_cliente = @CLIENTE AND m.pmo_habilitado = 1 AND m.pmo_orden_trabajo IS NULL AND m.pmo_plan_ocurrencia_estado NOT IN (5, 6, 7)
      AND   CAST(DATEADD(MINUTE, @OFF, m.pmo_fecha_programada_utc) AS DATE) = @HOY
) x ORDER BY HORA
GO

/* Predicciones activas (la mas probable primero) + razones + curva por activo + cifras del modelo.
   @DESDE (hora de la plataforma) devuelve solo lo calculado despues: es el sondeo del widget. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INICIO_PREDICCIONES]
    @CLIENTE INT,
    @USUARIO INT,
    @DESDE   DATETIME = NULL,
    @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @DESDE_UTC DATETIME = CASE WHEN @DESDE IS NULL THEN NULL ELSE DATEADD(MINUTE, -@OFF, @DESDE) END
DECLARE @P TABLE (id INT PRIMARY KEY)
INSERT INTO @P (id)
SELECT TOP 8 p.pre_id FROM [dbo].[Prediccion] p
WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND p.pre_usuario_revision IS NULL
  AND  (@PLANTAS IS NULL OR p.pre_activo IN (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N','))))
  AND  (p.pre_fecha_vigencia_hasta_utc IS NULL OR p.pre_fecha_vigencia_hasta_utc >= @UTC)
  AND  (@DESDE_UTC IS NULL OR p.pre_fecha_calculo_utc > @DESDE_UTC)
ORDER BY CASE WHEN @DESDE_UTC IS NULL THEN p.pre_probabilidad END DESC, p.pre_fecha_calculo_utc DESC

SELECT  p.pre_id AS ID, p.pre_activo AS ACTIVO_ID, ISNULL(a.act_nombre, N'') AS ACTIVO, ISNULL(a.act_codigo, N'') AS CODIGO,
        ISNULL(ar.iar_nombre, N'') AS AREA, ISNULL(c.aco_nombre, N'') AS COMPONENTE,
        CAST(CASE WHEN p.pre_probabilidad <= 1 THEN p.pre_probabilidad * 100 ELSE p.pre_probabilidad END AS DECIMAL(5,1)) AS PROB,
        CAST(CASE WHEN p.pre_confianza <= 1 THEN p.pre_confianza * 100 ELSE p.pre_confianza END AS DECIMAL(5,1)) AS CONFIANZA,
        p.pre_dia_restante AS DIAS, p.pre_intervalo_inferior AS DIAS_MIN, p.pre_intervalo_superior AS DIAS_MAX,
        DATEADD(MINUTE, @OFF, p.pre_fecha_evento_estimada_utc) AS FECHA_EVENTO,
        DATEADD(MINUTE, @OFF, p.pre_fecha_calculo_utc) AS CALCULADA,
        p.pre_alerta AS ALERTA_ID, p.pre_orden_trabajo AS OT_ID
FROM    @P x JOIN [dbo].[Prediccion] p ON p.pre_id = x.id
LEFT JOIN [dbo].[Activo] a ON a.act_id = p.pre_activo
LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = p.pre_activo_componente
LEFT JOIN [dbo].[Instalacion_Area] ar ON ar.iar_id = a.act_instalacion_area
ORDER BY CASE WHEN @DESDE_UTC IS NULL THEN p.pre_probabilidad END DESC, p.pre_fecha_calculo_utc DESC

/* razones */
SELECT  e.pex_prediccion AS PREDICCION, e.pex_texto AS TEXTO
FROM    [dbo].[Prediccion_Explicacion] e JOIN @P x ON x.id = e.pex_prediccion
ORDER BY e.pex_prediccion, ISNULL(e.pex_orden, 999), e.pex_id

/* la curva de cada activo: probabilidad de las corridas de los ultimos 30 dias */
SELECT  h.pre_activo AS ACTIVO_ID, DATEADD(MINUTE, @OFF, h.pre_fecha_calculo_utc) AS FECHA,
        CAST(CASE WHEN h.pre_probabilidad <= 1 THEN h.pre_probabilidad * 100 ELSE h.pre_probabilidad END AS DECIMAL(5,1)) AS PROB
FROM    [dbo].[Prediccion] h
WHERE   h.pre_cliente = @CLIENTE AND h.pre_habilitado = 1 AND h.pre_fecha_calculo_utc >= DATEADD(DAY, -30, @UTC)
  AND   h.pre_activo IN (SELECT p2.pre_activo FROM [dbo].[Prediccion] p2 JOIN @P x2 ON x2.id = p2.pre_id)
ORDER BY h.pre_activo, h.pre_fecha_calculo_utc

/* cifras del modelo */
SELECT
    ANTICIPADAS = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_orden_trabajo IS NOT NULL
                    AND pre_fecha_calculo_utc >= DATEADD(DAY, 1 - DAY(@UTC), CAST(CAST(@UTC AS DATE) AS DATETIME))),
    EVALUADAS   = (SELECT COUNT(*) FROM [dbo].[Prediccion_Resultado] r JOIN [dbo].[Prediccion] pp ON pp.pre_id = r.prs_prediccion WHERE pp.pre_cliente = @CLIENTE AND r.prs_habilitado = 1),
    ACIERTOS    = (SELECT COUNT(*) FROM [dbo].[Prediccion_Resultado] r JOIN [dbo].[Prediccion] pp ON pp.pre_id = r.prs_prediccion WHERE pp.pre_cliente = @CLIENTE AND r.prs_habilitado = 1 AND r.prs_ocurrio = 1)
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_INICIO_PREDICCION_DESCARTAR]
    @CLIENTE INT,
    @USUARIO INT,
    @ID      INT,
    @MOTIVO  NVARCHAR(400) = NULL
AS
SET NOCOUNT ON
UPDATE [dbo].[Prediccion]
   SET pre_usuario_revision = @USUARIO, pre_fecha_revision_utc = GETUTCDATE(), pre_motivo_descarte = ISNULL(@MOTIVO, N'Descartada desde el inicio'),
       pre_usuario_actualizacion = @USUARIO, pre_fecha_actualizacion = GETUTCDATE()
 WHERE pre_id = @ID AND pre_cliente = @CLIENTE AND pre_usuario_revision IS NULL
SELECT @@ROWCOUNT AS FILAS
GO

PRINT '377_INICIO aplicado.'
GO
