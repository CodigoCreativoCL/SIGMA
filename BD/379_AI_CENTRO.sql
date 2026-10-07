USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     SIGMA AI · CENTRO DE MONITOREO (View/SigmaAI/Centro.aspx).
-- =============================================
-- POR QUE
--   Ninguna cifra de la vista esta escrita a mano: todo sale de estos SP. Se apoyan en lo que ya guardan
--   /sigma-ai/predecir (Prediccion, Prediccion_Explicacion), SIGMA RUL (Prediccion de ese modelo),
--   SIGMA VISION (Analisis_Visual_*) y las versiones de Modelo_Predictivo_Version.
--
--   AI_Evento ................... la bitacora en vivo: lo que SIGMA AI hace y lo que las personas hacen con SIGMA AI.
--   Prediccion_Retroalimentacion  el motivo con que alguien descarta una prediccion: alimenta el proximo dataset.
--   Solicitud_Compra ............ «Pedir reposicion» de un repuesto que se acaba antes de terminar su vida util.
--   SEL_AI_PLANTA / COLA / DETALLE / RUL / VISION / MODELOS / MES / EVENTOS, INS_AI_EVENTO,
--   UPD_AI_PREDICCION_DESCARTAR, INS_SOLICITUD_COMPRA.
--   El menu «SIGMA AI» pasa a abrir esta vista (el laboratorio de Experimentos queda oculto: fue la investigacion del equipo, el cliente no lo ve).
-- TODO IDEMPOTENTE. Las horas de las tablas estan en UTC: aqui se entregan en la hora de la plataforma.
-- =============================================

IF OBJECT_ID('dbo.AI_Evento', 'U') IS NULL
CREATE TABLE [dbo].[AI_Evento](
    aie_id        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AI_Evento PRIMARY KEY,
    aie_cliente   INT NOT NULL,
    aie_tipo      CHAR(1) NOT NULL,                 -- f falla · r vida util · v vision · s sensor · o orden de trabajo
    aie_mensaje   NVARCHAR(400) NOT NULL,           -- los **asteriscos** marcan lo importante
    aie_activo    INT NULL,
    aie_usuario   INT NULL,
    aie_fecha_utc DATETIME NOT NULL CONSTRAINT DF_AIEVENTO_FECHA DEFAULT GETUTCDATE()
)
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AI_Evento_cliente_fecha')
    CREATE INDEX IX_AI_Evento_cliente_fecha ON [dbo].[AI_Evento] (aie_cliente, aie_fecha_utc DESC)
GO

IF OBJECT_ID('dbo.Prediccion_Retroalimentacion', 'U') IS NULL
CREATE TABLE [dbo].[Prediccion_Retroalimentacion](
    prr_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Prediccion_Retroalimentacion PRIMARY KEY,
    prr_prediccion INT NOT NULL,
    prr_cliente    INT NOT NULL,
    prr_motivo     NVARCHAR(30) NOT NULL,           -- YA_INTERVENIDO · FALSA_ALARMA · SENSOR_FALLA · OTRO
    prr_detalle    NVARCHAR(400) NULL,
    prr_usuario    INT NOT NULL,
    prr_fecha_utc  DATETIME NOT NULL CONSTRAINT DF_PRRETRO_FECHA DEFAULT GETUTCDATE()
)
GO

IF OBJECT_ID('dbo.Solicitud_Compra', 'U') IS NULL
CREATE TABLE [dbo].[Solicitud_Compra](
    sco_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Solicitud_Compra PRIMARY KEY,
    sco_cliente    INT NOT NULL,
    sco_numero     INT NOT NULL,
    sco_repuesto   INT NOT NULL,
    sco_cantidad   DECIMAL(18,4) NOT NULL,
    sco_motivo     NVARCHAR(400) NULL,
    sco_prediccion INT NULL,
    sco_estado     NVARCHAR(20) NOT NULL CONSTRAINT DF_SOLCOMPRA_ESTADO DEFAULT N'SOLICITADA',   -- SOLICITADA · RECIBIDA · CANCELADA
    sco_usuario    INT NOT NULL,
    sco_fecha_utc  DATETIME NOT NULL CONSTRAINT DF_SOLCOMPRA_FECHA DEFAULT GETUTCDATE()
)
GO

/* ---------------------------------------------------------------------------------------------- eventos */
CREATE OR ALTER PROCEDURE [dbo].[INS_AI_EVENTO]
    @CLIENTE INT, @USUARIO INT = NULL, @TIPO CHAR(1), @MENSAJE NVARCHAR(400), @ACTIVO INT = NULL
AS
SET NOCOUNT ON
INSERT INTO [dbo].[AI_Evento] (aie_cliente, aie_tipo, aie_mensaje, aie_activo, aie_usuario) VALUES (@CLIENTE, @TIPO, LEFT(@MENSAJE, 400), @ACTIVO, @USUARIO)
GO

/* La bitacora: lo registrado + las puntuaciones recientes. @DESDE (hora de la plataforma) trae solo lo nuevo. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_EVENTOS]
    @CLIENTE INT, @DESDE DATETIME = NULL, @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @D DATETIME = CASE WHEN @DESDE IS NULL THEN DATEADD(DAY, -3, @UTC) ELSE DATEADD(MINUTE, -@OFF, @DESDE) END
SELECT TOP 40 * FROM (
    SELECT e.aie_fecha_utc AS F, e.aie_tipo AS TIPO, e.aie_mensaje AS MENSAJE, e.aie_activo AS ACTIVO
    FROM   [dbo].[AI_Evento] e WHERE e.aie_cliente = @CLIENTE AND e.aie_fecha_utc > @D AND (@PLANTAS IS NULL OR e.aie_activo IS NULL OR e.aie_activo IN (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N','))))
    UNION ALL
    SELECT p.pre_fecha_calculo_utc, CASE WHEN mp.mpr_codigo LIKE N'%RUL%' THEN 'r' ELSE 'f' END,
           CASE WHEN mp.mpr_codigo LIKE N'%RUL%'
                THEN N'**' + ISNULL(a.act_nombre, N'Activo') + N'** · quedan ~' + CAST(ISNULL(p.pre_dia_restante, 0) AS NVARCHAR(10)) + N' días'
                ELSE N'**' + ISNULL(a.act_nombre, N'Activo') + N'** puntuado en ' + CAST(CAST(CASE WHEN p.pre_probabilidad <= 1 THEN p.pre_probabilidad * 100 ELSE p.pre_probabilidad END AS INT) AS NVARCHAR(10)) + N' %' END,
           p.pre_activo
    FROM   [dbo].[Prediccion] p
    JOIN   [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
    JOIN   [dbo].[Modelo_Predictivo] mp ON mp.mpr_id = v.mpv_modelo_predictivo
    LEFT JOIN [dbo].[Activo] a ON a.act_id = p.pre_activo
    WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND p.pre_fecha_calculo_utc > @D AND (@PLANTAS IS NULL OR p.pre_activo IN (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N','))))
) x ORDER BY F DESC
OPTION (RECOMPILE)
GO

/* ---------------------------------------------------------------------------------------------- planta */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_PLANTA]
    @CLIENTE INT, @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @FAIL INT = (SELECT TOP 1 mpr_id FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo LIKE N'%FAILURE%')

/* area de primer nivel de cada activo */
;WITH raiz AS (
    SELECT iar_id, iar_id AS tope FROM [dbo].[Instalacion_Area] WHERE iar_cliente = @CLIENTE AND iar_area_padre IS NULL
    UNION ALL
    SELECT h.iar_id, r.tope FROM [dbo].[Instalacion_Area] h JOIN raiz r ON h.iar_area_padre = r.iar_id
)
SELECT a.act_id AS ID, a.act_nombre AS NOMBRE, a.act_codigo AS CODIGO, ISNULL(r.tope, 0) AS AREA_ID,
       ISNULL(a.act_criticidad_nivel, 1) AS CRITICIDAD
INTO   #act
FROM   [dbo].[Activo] a LEFT JOIN raiz r ON r.iar_id = a.act_instalacion_area
WHERE  a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND a.act_fecha_baja IS NULL
  AND  (@PLANTAS IS NULL OR a.act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N',')))

/* la ultima puntuacion de FAILURE por activo (vigente y sin revisar) */
SELECT p.pre_id, p.pre_activo, p.pre_activo_componente, p.pre_dia_restante, p.pre_intervalo_inferior, p.pre_intervalo_superior, p.pre_fecha_evento_estimada_utc, p.pre_confianza,
       CAST(CASE WHEN p.pre_probabilidad <= 1 THEN p.pre_probabilidad * 100 ELSE p.pre_probabilidad END AS DECIMAL(5,1)) AS prob,
       ROW_NUMBER() OVER (PARTITION BY p.pre_activo ORDER BY p.pre_fecha_calculo_utc DESC) AS rn
INTO   #ult
FROM   [dbo].[Prediccion] p
JOIN   [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND v.mpv_modelo_predictivo = @FAIL AND p.pre_usuario_revision IS NULL
  AND  (@PLANTAS IS NULL OR p.pre_activo IN (SELECT ID FROM #act))
  AND  (p.pre_fecha_vigencia_hasta_utc IS NULL OR p.pre_fecha_vigencia_hasta_utc >= @UTC)

/* 1) areas */
SELECT ar.iar_id AS ID, ar.iar_nombre AS NOMBRE, (SELECT COUNT(*) FROM #act x WHERE x.AREA_ID = ar.iar_id) AS ACTIVOS
FROM   [dbo].[Instalacion_Area] ar
WHERE  ar.iar_cliente = @CLIENTE AND ar.iar_area_padre IS NULL AND ar.iar_habilitado = 1
UNION ALL SELECT 0, N'Sin área', (SELECT COUNT(*) FROM #act WHERE AREA_ID = 0) WHERE EXISTS (SELECT 1 FROM #act WHERE AREA_ID = 0)
ORDER BY ID

/* 2) activos con su ultima prediccion */
SELECT x.ID, x.NOMBRE, x.CODIGO, x.AREA_ID, x.CRITICIDAD, u.pre_id AS PRED_ID, u.prob AS PROB, u.pre_dia_restante AS DIAS, u.pre_intervalo_inferior AS DIAS_MIN, u.pre_intervalo_superior AS DIAS_MAX,
       DATEADD(MINUTE, @OFF, u.pre_fecha_evento_estimada_utc) AS FECHA_EVENTO,
       CAST(CASE WHEN u.pre_confianza <= 1 THEN u.pre_confianza * 100 ELSE u.pre_confianza END AS DECIMAL(5,1)) AS CONFIANZA,
       ISNULL(c.aco_nombre, N'') AS COMPONENTE
FROM   #act x LEFT JOIN #ult u ON u.pre_activo = x.ID AND u.rn = 1
LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = u.pre_activo_componente

/* 3) resumen: salud (100 menos el riesgo medio ponderado por criticidad), severidades y cuantos explican el 70 % */
DECLARE @SW FLOAT = (SELECT ISNULL(SUM(CAST(CRITICIDAD AS FLOAT)), 0) FROM #act)
DECLARE @SR FLOAT = (SELECT ISNULL(SUM(CAST(x.CRITICIDAD AS FLOAT) * ISNULL(u.prob, 0) / 100.0), 0) FROM #act x LEFT JOIN #ult u ON u.pre_activo = x.ID AND u.rn = 1)
DECLARE @TOT FLOAT = (SELECT ISNULL(SUM(ISNULL(u.prob, 0) * x.CRITICIDAD), 0) FROM #act x LEFT JOIN #ult u ON u.pre_activo = x.ID AND u.rn = 1)
;WITH r AS (SELECT ISNULL(u.prob, 0) * x.CRITICIDAD AS rk FROM #act x LEFT JOIN #ult u ON u.pre_activo = x.ID AND u.rn = 1),
      o AS (SELECT rk, SUM(rk) OVER (ORDER BY rk DESC ROWS UNBOUNDED PRECEDING) AS acum, ROW_NUMBER() OVER (ORDER BY rk DESC) AS n FROM r WHERE rk > 0)
SELECT TOTAL = (SELECT COUNT(*) FROM #act),
       SALUD = CAST(CASE WHEN @SW = 0 THEN NULL ELSE 100 - 100.0 * @SR / @SW END AS DECIMAL(5,1)),
       CRITICAS = (SELECT COUNT(*) FROM #ult WHERE rn = 1 AND prob >= 70),
       ALTAS    = (SELECT COUNT(*) FROM #ult WHERE rn = 1 AND prob >= 50 AND prob < 70),
       MEDIAS   = (SELECT COUNT(*) FROM #ult WHERE rn = 1 AND prob >= 25 AND prob < 50),
       SALUDABLES = (SELECT COUNT(*) FROM #act) - (SELECT COUNT(*) FROM #ult WHERE rn = 1 AND prob >= 25),
       EXPLICAN = (SELECT TOP 1 n FROM o WHERE @TOT > 0 AND acum >= 0.7 * @TOT ORDER BY n),
       ULTIMA_PUNTUACION = DATEADD(MINUTE, @OFF, (SELECT MAX(pre_fecha_calculo_utc) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1)),
       PUBLICADOS = (SELECT COUNT(*) FROM [dbo].[Modelo_Predictivo_Version] WHERE mpv_plan_version_estado = 2 AND mpv_fecha_retiro IS NULL AND mpv_modelo_predictivo IN (SELECT mpr_id FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo LIKE N'SIGMA %'))

/* 4) la salud de los ultimos 30 dias: la ultima puntuacion de cada activo hasta el cierre de cada dia */
;WITH d AS (SELECT TOP 30 ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS k FROM sys.all_objects),
      f AS (SELECT DATEADD(DAY, -(30 - k), CAST(@UTC AS DATE)) AS dia FROM d)
SELECT DATEADD(MINUTE, @OFF, CAST(f.dia AS DATETIME)) AS DIA,
       RIESGO = (SELECT ISNULL(SUM(CAST(x.CRITICIDAD AS FLOAT) * ISNULL(h.pp, 0)), 0) / NULLIF(@SW, 0)
                 FROM #act x OUTER APPLY (SELECT TOP 1 CASE WHEN q.pre_probabilidad <= 1 THEN q.pre_probabilidad ELSE q.pre_probabilidad / 100.0 END AS pp
                                           FROM [dbo].[Prediccion] q JOIN [dbo].[Modelo_Predictivo_Version] vv ON vv.mpv_id = q.pre_modelo_predictivo_version
                                           WHERE q.pre_activo = x.ID AND q.pre_habilitado = 1 AND vv.mpv_modelo_predictivo = @FAIL AND q.pre_fecha_calculo_utc < DATEADD(DAY, 1, CAST(f.dia AS DATETIME))
                                           ORDER BY q.pre_fecha_calculo_utc DESC) h)
FROM   f ORDER BY f.dia

/* 5) senales: por minuto, sensores en linea y la ultima lectura */
SELECT SENALES_MIN = CAST(ISNULL((SELECT COUNT(*) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_cliente = @CLIENTE AND (@PLANTAS IS NULL OR aml_activo_medidor IN (SELECT ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo IN (SELECT ID FROM #act))) AND aml_fecha_lectura_utc >= DATEADD(HOUR, -1, @UTC)), 0) / 60.0 AS DECIMAL(9,1)),
       SENSORES = (SELECT COUNT(*) FROM [dbo].[Activo_Medidor] WHERE ame_cliente = @CLIENTE AND ame_habilitado = 1 AND (@PLANTAS IS NULL OR ame_activo IN (SELECT ID FROM #act))),
       EN_LINEA = (SELECT COUNT(*) FROM [dbo].[Activo_Medidor] WHERE ame_cliente = @CLIENTE AND ame_habilitado = 1 AND (@PLANTAS IS NULL OR ame_activo IN (SELECT ID FROM #act)) AND ame_fecha_valor_actual_utc >= DATEADD(DAY, -1, @UTC)),
       ULTIMA_LECTURA = DATEADD(MINUTE, @OFF, (SELECT MAX(aml_fecha_lectura_utc) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_cliente = @CLIENTE AND (@PLANTAS IS NULL OR aml_activo_medidor IN (SELECT ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo IN (SELECT ID FROM #act)))))

/* 6) lecturas por minuto, ultimos 40 minutos */
;WITH m AS (SELECT TOP 40 ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS k FROM sys.all_objects)
SELECT m.k AS MIN_ATRAS_ORDEN,
       (SELECT COUNT(*) FROM [dbo].[Activo_Medidor_Lectura] l WHERE l.aml_cliente = @CLIENTE AND (@PLANTAS IS NULL OR l.aml_activo_medidor IN (SELECT ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo IN (SELECT ID FROM #act))) AND l.aml_fecha_lectura_utc >= DATEADD(MINUTE, -(41 - m.k), @UTC) AND l.aml_fecha_lectura_utc < DATEADD(MINUTE, -(40 - m.k), @UTC)) AS N
FROM   m ORDER BY m.k
GO

/* ---------------------------------------------------------------------------------------------- cola */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_COLA]
    @CLIENTE INT, @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @FAIL INT = (SELECT TOP 1 mpr_id FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo LIKE N'%FAILURE%')
SELECT * INTO #c FROM (
    SELECT p.pre_id AS ID, p.pre_activo AS ACTIVO_ID, ISNULL(a.act_nombre, N'') AS ACTIVO, ISNULL(a.act_codigo, N'') AS CODIGO, ISNULL(ar.iar_nombre, N'') AS AREA, ISNULL(c.aco_nombre, N'') AS COMPONENTE,
           v.mpv_numero AS VERSION,
           CAST(CASE WHEN p.pre_probabilidad <= 1 THEN p.pre_probabilidad * 100 ELSE p.pre_probabilidad END AS DECIMAL(5,1)) AS PROB,
           CAST(CASE WHEN p.pre_confianza <= 1 THEN p.pre_confianza * 100 ELSE p.pre_confianza END AS DECIMAL(5,1)) AS CONFIANZA,
           p.pre_dia_restante AS DIAS, p.pre_intervalo_inferior AS DIAS_MIN, p.pre_intervalo_superior AS DIAS_MAX,
           DATEADD(MINUTE, @OFF, p.pre_fecha_evento_estimada_utc) AS FECHA_EVENTO, DATEADD(MINUTE, @OFF, p.pre_fecha_calculo_utc) AS CALCULADA,
           p.pre_alerta AS ALERTA_ID, p.pre_orden_trabajo AS OT_ID, o.otr_correlativo AS OT_NUM,
           CASE WHEN p.pre_orden_trabajo IS NOT NULL THEN 'o' WHEN p.pre_usuario_revision IS NOT NULL THEN 'd'
                WHEN p.pre_fecha_calculo_utc >= DATEADD(HOUR, -24, @UTC) THEN 'n' ELSE 'r' END AS ESTADO,
           p.pre_motivo_descarte AS MOTIVO,
           ROW_NUMBER() OVER (PARTITION BY p.pre_activo ORDER BY p.pre_fecha_calculo_utc DESC) AS rn
    FROM   [dbo].[Prediccion] p
    JOIN   [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
    LEFT JOIN [dbo].[Activo] a ON a.act_id = p.pre_activo
    LEFT JOIN [dbo].[Instalacion_Area] ar ON ar.iar_id = a.act_instalacion_area
    LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = p.pre_activo_componente
    LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = p.pre_orden_trabajo
    WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND v.mpv_modelo_predictivo = @FAIL
      AND  (@PLANTAS IS NULL OR a.act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N',')))
      AND  ((p.pre_usuario_revision IS NULL AND (p.pre_fecha_vigencia_hasta_utc IS NULL OR p.pre_fecha_vigencia_hasta_utc >= @UTC))
            OR p.pre_fecha_revision_utc >= DATEADD(DAY, -7, @UTC) OR p.pre_orden_trabajo IS NOT NULL)
) z WHERE rn = 1
SELECT * FROM #c ORDER BY PROB DESC
/* la probabilidad de cada activo en los ultimos 14 dias */
SELECT h.pre_activo AS ACTIVO_ID, DATEADD(MINUTE, @OFF, h.pre_fecha_calculo_utc) AS FECHA,
       CAST(CASE WHEN h.pre_probabilidad <= 1 THEN h.pre_probabilidad * 100 ELSE h.pre_probabilidad END AS DECIMAL(5,1)) AS PROB
FROM   [dbo].[Prediccion] h JOIN [dbo].[Modelo_Predictivo_Version] hv ON hv.mpv_id = h.pre_modelo_predictivo_version
WHERE  h.pre_cliente = @CLIENTE AND h.pre_habilitado = 1 AND hv.mpv_modelo_predictivo = @FAIL AND h.pre_fecha_calculo_utc >= DATEADD(DAY, -14, @UTC)
  AND  h.pre_activo IN (SELECT ACTIVO_ID FROM #c)
ORDER BY h.pre_activo, h.pre_fecha_calculo_utc
GO

/* ---------------------------------------------------------------------------------------------- detalle */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_DETALLE]
    @CLIENTE INT, @ID INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
DECLARE @ACT INT = (SELECT pre_activo FROM [dbo].[Prediccion] WHERE pre_id = @ID AND pre_cliente = @CLIENTE)
/* 1) la recomendacion: el repuesto que se instalo en ese componente, su stock y cuanto suele durar una intervencion en este activo */
SELECT TOP 1
       r.rep_id AS REPUESTO_ID, r.rep_codigo AS REPUESTO_CODIGO, r.rep_nombre AS REPUESTO_NOMBRE,
       STOCK = (SELECT ISNULL(SUM(s.isa_cantidad - s.isa_cantidad_reservada), 0) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = r.rep_id),
       MINIMO = (SELECT ISNULL(SUM(b.rbs_stock_minimo), 0) FROM [dbo].[Repuesto_Bodega_Stock] b WHERE b.rbs_cliente = @CLIENTE AND b.rbs_repuesto = r.rep_id AND b.rbs_habilitado = 1),
       DURACION_MIN = (SELECT CAST(AVG(CAST(o.otr_duracion_real_minuto AS FLOAT)) AS INT) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_cliente = @CLIENTE AND o.otr_activo = @ACT AND o.otr_orden_trabajo_estado = 4 AND o.otr_duracion_real_minuto > 0)
FROM   [dbo].[Prediccion] p
LEFT JOIN [dbo].[Componente_Repuesto_Instalacion] i ON i.cri_id = p.pre_componente_repuesto_instalacion
LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = i.cri_repuesto
WHERE  p.pre_id = @ID AND p.pre_cliente = @CLIENTE
/* 2) lo que mas peso: aporte de cada caracteristica a la fila de hoy */
SELECT e.pex_orden AS ORDEN, e.pex_texto AS TEXTO, e.pex_contribucion AS CONTRIBUCION, e.pex_direccion AS DIRECCION, e.pex_valor_observado AS OBSERVADO, e.pex_valor_referencia AS REFERENCIA
FROM   [dbo].[Prediccion_Explicacion] e WHERE e.pex_prediccion = @ID ORDER BY ISNULL(e.pex_orden, 999), e.pex_id
/* 3) la curva: probabilidad de las corridas del activo, 30 dias */
SELECT DATEADD(MINUTE, @OFF, h.pre_fecha_calculo_utc) AS FECHA,
       CAST(CASE WHEN h.pre_probabilidad <= 1 THEN h.pre_probabilidad * 100 ELSE h.pre_probabilidad END AS DECIMAL(5,1)) AS PROB
FROM   [dbo].[Prediccion] h WHERE h.pre_cliente = @CLIENTE AND h.pre_activo = @ACT AND h.pre_habilitado = 1 AND h.pre_fecha_calculo_utc >= DATEADD(DAY, -30, @UTC)
ORDER BY h.pre_fecha_calculo_utc
/* 4) la lectura del medidor del activo (ultimos 30 dias, una por dia) para dibujar la senal cuando existe */
SELECT TOP 31 CAST(DATEADD(MINUTE, @OFF, l.aml_fecha_lectura_utc) AS DATE) AS DIA, m.ame_nombre AS MEDIDOR, AVG(CAST(l.aml_valor_acumulado AS FLOAT)) AS VALOR
FROM   [dbo].[Activo_Medidor_Lectura] l JOIN [dbo].[Activo_Medidor] m ON m.ame_id = l.aml_activo_medidor
WHERE  l.aml_cliente = @CLIENTE AND m.ame_activo = @ACT AND l.aml_fecha_lectura_utc >= DATEADD(DAY, -30, @UTC)
GROUP BY CAST(DATEADD(MINUTE, @OFF, l.aml_fecha_lectura_utc) AS DATE), m.ame_nombre
ORDER BY DIA
GO

/* ---------------------------------------------------------------------------------------------- vida util (SIGMA RUL) */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_RUL]
    @CLIENTE INT, @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @RUL INT = (SELECT TOP 1 mpr_id FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo LIKE N'%RUL%')
SELECT * FROM (
    SELECT p.pre_id AS ID, r.rep_id AS REPUESTO_ID, r.rep_codigo AS CODIGO, r.rep_nombre AS REPUESTO, ISNULL(a.act_nombre, N'') AS ACTIVO,
           p.pre_dia_restante AS DIAS, p.pre_intervalo_inferior AS DIAS_MIN, p.pre_intervalo_superior AS DIAS_MAX,
           STOCK = (SELECT ISNULL(SUM(s.isa_cantidad - s.isa_cantidad_reservada), 0) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = r.rep_id),
           MINIMO = (SELECT ISNULL(SUM(b.rbs_stock_minimo), 0) FROM [dbo].[Repuesto_Bodega_Stock] b WHERE b.rbs_cliente = @CLIENTE AND b.rbs_repuesto = r.rep_id AND b.rbs_habilitado = 1),
           PEDIDO = CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Solicitud_Compra] s WHERE s.sco_cliente = @CLIENTE AND s.sco_repuesto = r.rep_id AND s.sco_estado = N'SOLICITADA') THEN 1 ELSE 0 END AS BIT),
           ROW_NUMBER() OVER (PARTITION BY p.pre_componente_repuesto_instalacion ORDER BY p.pre_fecha_calculo_utc DESC) AS rn
    FROM   [dbo].[Prediccion] p
    JOIN   [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
    JOIN   [dbo].[Componente_Repuesto_Instalacion] i ON i.cri_id = p.pre_componente_repuesto_instalacion
    JOIN   [dbo].[Repuesto] r ON r.rep_id = i.cri_repuesto
    LEFT JOIN [dbo].[Activo] a ON a.act_id = p.pre_activo
    WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND v.mpv_modelo_predictivo = @RUL AND p.pre_dia_restante IS NOT NULL
      AND  (@PLANTAS IS NULL OR a.act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N',')))
      AND  (p.pre_fecha_vigencia_hasta_utc IS NULL OR p.pre_fecha_vigencia_hasta_utc >= @UTC)
) z WHERE rn = 1 ORDER BY DIAS
GO

/* ---------------------------------------------------------------------------------------------- vision */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_VISION]
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
SELECT TOP 12 r.avr_id AS ID, r.avr_archivo AS ARCHIVO, DATEADD(MINUTE, @OFF, r.avr_fecha_proceso_utc) AS FECHA,
       LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS SUBIO,
       ISNULL(f.arc_nombre_original, N'') AS NOMBRE, ISNULL(f.arc_ancho_pixel, 0) AS ANCHO, ISNULL(f.arc_alto_pixel, 0) AS ALTO, r.avr_revisado_humano AS REVISADO,
       v.mpv_numero AS VERSION
INTO   #r
FROM   [dbo].[Analisis_Visual_Revision] r
LEFT JOIN [dbo].[Archivo] f ON f.arc_id = r.avr_archivo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = r.avr_usuario_creacion
LEFT JOIN [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = r.avr_modelo_version
WHERE  r.avr_cliente = @CLIENTE AND r.avr_habilitado = 1
ORDER BY r.avr_fecha_proceso_utc DESC
SELECT * FROM #r ORDER BY FECHA DESC
SELECT d.avd_id AS ID, d.avd_analisis_visual_revision AS REVISION, d.avd_etiqueta AS ETIQUETA,
       CAST(CASE WHEN d.avd_confianza <= 1 THEN d.avd_confianza * 100 ELSE d.avd_confianza END AS DECIMAL(5,1)) AS CONFIANZA,
       CASE WHEN d.avd_caja_ancho IS NULL THEN NULL WHEN d.avd_caja_ancho <= 1 THEN d.avd_caja_x * 100 WHEN r.ANCHO > 0 THEN d.avd_caja_x * 100.0 / r.ANCHO END AS X,
       CASE WHEN d.avd_caja_ancho IS NULL THEN NULL WHEN d.avd_caja_ancho <= 1 THEN d.avd_caja_y * 100 WHEN r.ALTO > 0 THEN d.avd_caja_y * 100.0 / r.ALTO END AS Y,
       CASE WHEN d.avd_caja_ancho IS NULL THEN NULL WHEN d.avd_caja_ancho <= 1 THEN d.avd_caja_ancho * 100 WHEN r.ANCHO > 0 THEN d.avd_caja_ancho * 100.0 / r.ANCHO END AS W,
       CASE WHEN d.avd_caja_ancho IS NULL THEN NULL WHEN d.avd_caja_ancho <= 1 THEN d.avd_caja_alto * 100 WHEN r.ALTO > 0 THEN d.avd_caja_alto * 100.0 / r.ALTO END AS H,
       d.avd_confirmado_humano AS CONFIRMADO
FROM   [dbo].[Analisis_Visual_Deteccion] d JOIN #r r ON r.ID = d.avd_analisis_visual_revision
WHERE  d.avd_habilitado = 1
ORDER BY d.avd_analisis_visual_revision, d.avd_confianza DESC
SELECT PENDIENTES = (SELECT COUNT(DISTINCT d.avd_analisis_visual_revision) FROM [dbo].[Analisis_Visual_Deteccion] d JOIN [dbo].[Analisis_Visual_Revision] r ON r.avr_id = d.avd_analisis_visual_revision
                      WHERE r.avr_cliente = @CLIENTE AND r.avr_habilitado = 1 AND d.avd_habilitado = 1 AND d.avd_confirmado_humano = 0)
GO

/* ---------------------------------------------------------------------------------------------- modelos */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_MODELOS]
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @OFF INT = DATEDIFF(MINUTE, @UTC, [dbo].[FNC_AHORA]())
/* 1) la version vigente (publicada y no retirada) de cada modelo SIGMA */
SELECT mp.mpr_id AS MODELO_ID, mp.mpr_codigo AS MODELO, mp.mpr_descripcion AS DESCRIPCION, v.mpv_id AS VERSION_ID, v.mpv_numero AS VERSION, v.mpv_algoritmo AS ALGORITMO,
       v.mpv_metrica_auc AS AUC, v.mpv_metrica_precision AS PRECISION_, v.mpv_metrica_recall AS RECALL_, v.mpv_metrica_f1 AS F1, v.mpv_metrica_mae AS MAE,
       DATEADD(MINUTE, @OFF, v.mpv_fecha_entrenamiento_utc) AS ENTRENADA, DATEADD(MINUTE, @OFF, v.mpv_fecha_publicacion) AS PUBLICADA,
       v.mpv_hash AS HASH, DATEADD(MINUTE, @OFF, v.mpv_fecha_verificacion_utc) AS VERIFICADA,
       d.den_fila_total AS DATASET_FILAS, DATEADD(MINUTE, @OFF, d.den_fecha_creacion) AS DATASET_FECHA,
       CASE WHEN ISJSON(v.mpv_parametro) = 1 THEN (SELECT COUNT(*) FROM OPENJSON(v.mpv_parametro, '$.caracteristicas')) END AS CARACTERISTICAS,
       CASE WHEN ISJSON(v.mpv_parametro) = 1 THEN TRY_CAST(JSON_VALUE(v.mpv_parametro, '$.cobertura80') AS FLOAT) END AS COBERTURA,
       CASE WHEN ISJSON(v.mpv_parametro) = 1 THEN TRY_CAST(JSON_VALUE(v.mpv_parametro, '$.umbral') AS FLOAT) END AS UMBRAL
FROM   [dbo].[Modelo_Predictivo] mp
OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Modelo_Predictivo_Version] x WHERE x.mpv_modelo_predictivo = mp.mpr_id AND x.mpv_plan_version_estado = 2 AND x.mpv_fecha_retiro IS NULL ORDER BY x.mpv_numero DESC) v
LEFT JOIN [dbo].[Dataset_Entrenamiento] d ON d.den_id = v.mpv_dataset_entrenamiento
WHERE  mp.mpr_codigo LIKE N'SIGMA %'
ORDER BY mp.mpr_id
/* 2) la metrica principal de cada version, para la sparkline */
SELECT mpv_modelo_predictivo AS MODELO_ID, mpv_numero AS VERSION, mpv_metrica_auc AS AUC, mpv_metrica_mae AS MAE
FROM   [dbo].[Modelo_Predictivo_Version] WHERE mpv_plan_version_estado IN (2, 3) ORDER BY mpv_modelo_predictivo, mpv_numero
GO

/* ---------------------------------------------------------------------------------------------- como le fue este mes */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_MES]
    @CLIENTE INT, @PLANTAS NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @INI DATETIME = DATEADD(DAY, 1 - DAY(@UTC), CAST(CAST(@UTC AS DATE) AS DATETIME))
DECLARE @FAIL INT = (SELECT TOP 1 mpr_id FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo LIKE N'%FAILURE%')
/* una prediccion «alta» (>= 50 %) del mes y las correctivas cerradas del mismo activo dentro de los 30 dias siguientes */
;WITH p AS (
    SELECT p.pre_id, p.pre_activo, p.pre_fecha_calculo_utc, p.pre_usuario_revision, p.pre_motivo_descarte
    FROM   [dbo].[Prediccion] p JOIN [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
    WHERE  p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND v.mpv_modelo_predictivo = @FAIL AND p.pre_fecha_calculo_utc >= @INI AND (@PLANTAS IS NULL OR p.pre_activo IN (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N','))))
      AND  (CASE WHEN p.pre_probabilidad <= 1 THEN p.pre_probabilidad * 100 ELSE p.pre_probabilidad END) >= 50
), c AS (
    SELECT o.otr_id, o.otr_activo, ISNULL(o.otr_fecha_inicio_real_utc, o.otr_fecha_evento_utc) AS f
    FROM   [dbo].[Orden_Trabajo] o JOIN [dbo].[Orden_Trabajo_Tipo] t ON t.ott_id = o.otr_orden_trabajo_tipo
    WHERE  o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND t.ott_codigo LIKE N'%CORRECT%' AND ISNULL(o.otr_fecha_inicio_real_utc, o.otr_fecha_evento_utc) >= @INI AND (@PLANTAS IS NULL OR o.otr_activo IN (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_cliente_instalacion IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@PLANTAS, N','))))
)
SELECT ANTICIPADAS = (SELECT COUNT(DISTINCT p.pre_activo) FROM p WHERE EXISTS (SELECT 1 FROM c WHERE c.otr_activo = p.pre_activo AND c.f >= p.pre_fecha_calculo_utc AND c.f < DATEADD(DAY, 30, p.pre_fecha_calculo_utc))),
       FALSAS     = (SELECT COUNT(DISTINCT p.pre_activo) FROM p WHERE p.pre_motivo_descarte LIKE N'%Falsa alarma%'),
       NO_ANTICIPADAS = (SELECT COUNT(*) FROM c WHERE NOT EXISTS (SELECT 1 FROM p WHERE p.pre_activo = c.otr_activo AND p.pre_fecha_calculo_utc <= c.f AND p.pre_fecha_calculo_utc >= DATEADD(DAY, -30, c.f))),
       HORAS_EVITADAS = CAST(NULL AS INT)
GO

/* ---------------------------------------------------------------------------------------------- acciones */
/* Descartar con motivo: queda en la prediccion, en la retroalimentacion (proximo dataset) y en la bitacora. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_AI_PREDICCION_DESCARTAR]
    @CLIENTE INT, @USUARIO INT, @ID INT, @MOTIVO NVARCHAR(30), @DETALLE NVARCHAR(400) = NULL
AS
SET NOCOUNT ON
IF @MOTIVO NOT IN (N'YA_INTERVENIDO', N'FALSA_ALARMA', N'SENSOR_FALLA', N'OTRO')
BEGIN
    RAISERROR('1.- ELIJA UN MOTIVO: YA SE INTERVINO, FALSA ALARMA, EL SENSOR TIENE UNA FALLA U OTRO.', 16, 1)
    RETURN -1
END
DECLARE @TXT NVARCHAR(100) = CASE @MOTIVO WHEN N'YA_INTERVENIDO' THEN N'Ya se intervino' WHEN N'FALSA_ALARMA' THEN N'Falsa alarma' WHEN N'SENSOR_FALLA' THEN N'El sensor tiene una falla' ELSE N'Otro motivo' END
DECLARE @ACT INT, @NOM NVARCHAR(200)
SELECT @ACT = p.pre_activo, @NOM = a.act_nombre FROM [dbo].[Prediccion] p LEFT JOIN [dbo].[Activo] a ON a.act_id = p.pre_activo WHERE p.pre_id = @ID AND p.pre_cliente = @CLIENTE
IF @ACT IS NULL
BEGIN
    RAISERROR('2.- LA PREDICCION NO EXISTE.', 16, 1)
    RETURN -1
END
UPDATE [dbo].[Prediccion] SET pre_usuario_revision = @USUARIO, pre_fecha_revision_utc = GETUTCDATE(),
       pre_motivo_descarte = LEFT(@TXT + ISNULL(N': ' + NULLIF(LTRIM(RTRIM(@DETALLE)), N''), N''), 400), pre_usuario_actualizacion = @USUARIO, pre_fecha_actualizacion = GETUTCDATE()
 WHERE pre_id = @ID AND pre_cliente = @CLIENTE
INSERT INTO [dbo].[Prediccion_Retroalimentacion] (prr_prediccion, prr_cliente, prr_motivo, prr_detalle, prr_usuario) VALUES (@ID, @CLIENTE, @MOTIVO, NULLIF(LTRIM(RTRIM(@DETALLE)), N''), @USUARIO)
DECLARE @MSG NVARCHAR(400) = N'Predicción descartada · **' + ISNULL(@NOM, N'activo') + N'** · motivo: ' + LOWER(@TXT)
EXEC [dbo].[INS_AI_EVENTO] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @TIPO = 'f', @MENSAJE = @MSG, @ACTIVO = @ACT
SELECT @ID AS ID
GO

/* Reabrir una prediccion descartada (quita la revision; la retroalimentacion ya enviada se conserva). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_AI_PREDICCION_REABRIR]
    @CLIENTE INT, @USUARIO INT, @ID INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Prediccion] SET pre_usuario_revision = NULL, pre_fecha_revision_utc = NULL, pre_motivo_descarte = NULL, pre_usuario_actualizacion = @USUARIO, pre_fecha_actualizacion = GETUTCDATE()
 WHERE pre_id = @ID AND pre_cliente = @CLIENTE AND pre_usuario_revision IS NOT NULL AND pre_orden_trabajo IS NULL
SELECT @@ROWCOUNT AS FILAS
GO

/* Pedir reposicion: una solicitud abierta por repuesto (si ya hay una, devuelve esa). */
CREATE OR ALTER PROCEDURE [dbo].[INS_SOLICITUD_COMPRA]
    @CLIENTE INT, @USUARIO INT, @REPUESTO INT, @CANTIDAD DECIMAL(18,4) = NULL, @MOTIVO NVARCHAR(400) = NULL, @PREDICCION INT = NULL
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
    RETURN -1
END
DECLARE @ID INT = (SELECT TOP 1 sco_id FROM [dbo].[Solicitud_Compra] WHERE sco_cliente = @CLIENTE AND sco_repuesto = @REPUESTO AND sco_estado = N'SOLICITADA')
IF @ID IS NULL
BEGIN
    /* cuanto falta para llegar al minimo, y como minimo 1 */
    IF @CANTIDAD IS NULL OR @CANTIDAD <= 0
        SET @CANTIDAD = (SELECT CASE WHEN m.minimo - s.stock >= 1 THEN m.minimo - s.stock ELSE 1 END
                           FROM (SELECT ISNULL(SUM(b.rbs_stock_minimo), 0) AS minimo FROM [dbo].[Repuesto_Bodega_Stock] b WHERE b.rbs_cliente = @CLIENTE AND b.rbs_repuesto = @REPUESTO AND b.rbs_habilitado = 1) m,
                                (SELECT ISNULL(SUM(i.isa_cantidad - i.isa_cantidad_reservada), 0) AS stock FROM [dbo].[Inventario_Saldo] i WHERE i.isa_cliente = @CLIENTE AND i.isa_repuesto = @REPUESTO) s)
    DECLARE @N INT = ISNULL((SELECT MAX(sco_numero) FROM [dbo].[Solicitud_Compra] WHERE sco_cliente = @CLIENTE), 0) + 1
    INSERT INTO [dbo].[Solicitud_Compra] (sco_cliente, sco_numero, sco_repuesto, sco_cantidad, sco_motivo, sco_prediccion, sco_usuario)
    VALUES (@CLIENTE, @N, @REPUESTO, @CANTIDAD, @MOTIVO, @PREDICCION, @USUARIO)
    SET @ID = SCOPE_IDENTITY()
    DECLARE @NOM NVARCHAR(200) = (SELECT rep_codigo + N' · ' + rep_nombre FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO)
    DECLARE @MSG2 NVARCHAR(400) = N'Solicitud de compra creada · **' + @NOM + N'**'
    EXEC [dbo].[INS_AI_EVENTO] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @TIPO = 'r', @MENSAJE = @MSG2, @ACTIVO = NULL
END
SELECT s.sco_id AS ID, s.sco_numero AS NUMERO, s.sco_cantidad AS CANTIDAD FROM [dbo].[Solicitud_Compra] s WHERE s.sco_id = @ID
GO

/* ---------------------------------------------------------------------------------------------- menu */
/* SIGMA AI abre el centro de monitoreo; el laboratorio sigue en su pagina (se enlaza desde el centro). */
UPDATE [dbo].[Menus] SET mnu_link = N'~/View/SigmaAI/Centro.aspx', mnu_descripcion = N'Centro de monitoreo de SIGMA AI: planta en vivo, predicciones, vida util, vision y modelos'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'SIGMA AI' AND mnu_link COLLATE DATABASE_DEFAULT = N'#'
GO
/* El laboratorio (Experimentos) fue la investigacion del equipo para disenar SIGMA AI: no lo ve el cliente. Sigue existiendo por si el equipo lo necesita. */
UPDATE [dbo].[Menus] SET mnu_visible = 0 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/SigmaAI/Experimentos.aspx'
GO

PRINT '379_AI_CENTRO aplicado.'
GO
