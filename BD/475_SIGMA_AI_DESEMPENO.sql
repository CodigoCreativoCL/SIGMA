/* ============================================================================
   475 · SIGMA AI · evaluar predicciones y desempeño del modelo (EP-17: HU-177, HU-178) · 17-10-2026
   ----------------------------------------------------------------------------
   HU-177 · cada predicción cuyo horizonte venció se evalúa: ¿el evento ocurrió y cuándo? El error respecto de
            la fecha estimada se calcula solo. Si NO ocurrió pero hubo una intervención previa, es «acierto con
            intervención» y NO cuenta como falso positivo.
   HU-178 · panel de desempeño por versión y mes: predicciones, evaluadas, clasificación y aciertos con
            intervención (aparte). Si la precisión actual cae bajo la de referencia de la versión (con al menos
            5 evaluadas) la versión queda «candidata a reentrenamiento».
   La desviación de los datos de entrada (CA3 de HU-178) NO se calcula aquí: pide la distribución del
   entrenamiento, que hoy no se guarda; mmo_deriva_datos queda NULL y la pantalla lo dice.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---------- el catálogo de estados de la predicción estaba VACÍO en la base compartida ----------
   Sin estas cinco filas, INSERT en Prediccion falla por FK_PRE_ESTADO: SIGMA AI no podía guardar ninguna
   predicción. Mismas filas de BD/04 (ids fijos: el código depende de ellos). */
SET IDENTITY_INSERT [dbo].[Prediccion_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 1) INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (1, N'GENERADA', N'Generada', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 2) INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (2, N'REVISADA', N'Revisada', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 3) INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (3, N'ACEPTADA', N'Aceptada', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 4) INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (4, N'DESCARTADA', N'Descartada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 5) INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (5, N'MATERIALIZADA', N'Materializada', 5)
SET IDENTITY_INSERT [dbo].[Prediccion_Estado] OFF
GO

/* ---------- el monitoreo mensual de una versión, calculado desde los resultados ---------- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AI_MONITOREO]
    @CLIENTE INT,
    @VERSION INT = NULL
AS
SET NOCOUNT ON
DECLARE @MIN_EVALUADAS INT = 5

;WITH P AS (
    SELECT  p.pre_modelo_predictivo_version AS V, YEAR(p.pre_fecha_calculo_utc) AS A, MONTH(p.pre_fecha_calculo_utc) AS M,
            COUNT(*) AS TOTAL,
            SUM(CASE WHEN r.prs_id IS NOT NULL THEN 1 ELSE 0 END) AS EVAL,
            SUM(CASE WHEN r.prs_clasificacion = 'VERDADERO POSITIVO' THEN 1 ELSE 0 END) AS VP,
            SUM(CASE WHEN r.prs_clasificacion = 'FALSO POSITIVO' THEN 1 ELSE 0 END) AS FP,
            SUM(CASE WHEN r.prs_clasificacion = 'ACIERTO CON INTERVENCION' THEN 1 ELSE 0 END) AS ACI
    FROM    [dbo].[Prediccion] p
    LEFT JOIN [dbo].[Prediccion_Resultado] r ON r.prs_prediccion = p.pre_id AND r.prs_habilitado = 1
    WHERE   p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1 AND (@VERSION IS NULL OR p.pre_modelo_predictivo_version = @VERSION)
    GROUP BY p.pre_modelo_predictivo_version, YEAR(p.pre_fecha_calculo_utc), MONTH(p.pre_fecha_calculo_utc)
)
MERGE [dbo].[Modelo_Monitoreo] AS D
USING (SELECT P.*, v.mpv_metrica_precision AS REF FROM P JOIN [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = P.V) AS O
   ON D.mmo_modelo_predictivo_version = O.V AND D.mmo_cliente = @CLIENTE AND D.mmo_periodo_anio = O.A AND D.mmo_periodo_mes = O.M
WHEN MATCHED THEN UPDATE SET
        mmo_prediccion_total = O.TOTAL, mmo_prediccion_evaluada = O.EVAL, mmo_verdadero_positivo = O.VP, mmo_falso_positivo = O.FP,
        mmo_acierto_con_intervencion = O.ACI,
        mmo_metrica_actual = CASE WHEN O.VP + O.FP > 0 THEN CAST(1.0 * O.VP / (O.VP + O.FP) AS DECIMAL(9, 6)) END,
        mmo_metrica_referencia = O.REF,
        mmo_requiere_reentrenamiento = CASE WHEN O.EVAL >= @MIN_EVALUADAS AND O.VP + O.FP > 0 AND O.REF IS NOT NULL AND 1.0 * O.VP / (O.VP + O.FP) < O.REF THEN 1 ELSE 0 END,
        mmo_observacion = CASE WHEN O.EVAL < @MIN_EVALUADAS THEN N'Con menos de ' + CAST(@MIN_EVALUADAS AS NVARCHAR(5)) + N' predicciones evaluadas no se juzga el desempeño.'
                               WHEN O.REF IS NULL THEN N'La versión no tiene precisión de referencia para comparar.' END,
        mmo_usuario_actualizacion = 1, mmo_fecha_actualizacion = GETDATE()
WHEN NOT MATCHED THEN INSERT
        (mmo_modelo_predictivo_version, mmo_cliente, mmo_periodo_anio, mmo_periodo_mes, mmo_prediccion_total, mmo_prediccion_evaluada,
         mmo_verdadero_positivo, mmo_falso_positivo, mmo_verdadero_negativo, mmo_falso_negativo, mmo_acierto_con_intervencion,
         mmo_metrica_actual, mmo_metrica_referencia, mmo_requiere_reentrenamiento, mmo_observacion, mmo_usuario_creacion, mmo_fecha_creacion, mmo_habilitado)
    VALUES (O.V, @CLIENTE, O.A, O.M, O.TOTAL, O.EVAL, O.VP, O.FP, 0, 0, O.ACI,
            CASE WHEN O.VP + O.FP > 0 THEN CAST(1.0 * O.VP / (O.VP + O.FP) AS DECIMAL(9, 6)) END, O.REF,
            CASE WHEN O.EVAL >= @MIN_EVALUADAS AND O.VP + O.FP > 0 AND O.REF IS NOT NULL AND 1.0 * O.VP / (O.VP + O.FP) < O.REF THEN 1 ELSE 0 END,
            CASE WHEN O.EVAL < @MIN_EVALUADAS THEN N'Con menos de ' + CAST(@MIN_EVALUADAS AS NVARCHAR(5)) + N' predicciones evaluadas no se juzga el desempeño.'
                 WHEN O.REF IS NULL THEN N'La versión no tiene precisión de referencia para comparar.' END, 1, GETDATE(), 1);
RETURN 0
GO

/* ---------- registrar el resultado de una predicción (HU-177) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[INS_AI_PREDICCION_RESULTADO]
    @CLIENTE              INT,
    @PREDICCION           INT,
    @OCURRIO              BIT,
    @FECHA_EVENTO         DATETIME = NULL,
    @MANTENIMIENTO_PREVIO BIT = 0,
    @FALLA                INT = NULL,
    @ORDEN_TRABAJO        INT = NULL,
    @OBSERVACION          NVARCHAR(500) = NULL,
    @USUARIO              INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @VERSION INT, @ESTIMADA DATETIME
SELECT @VERSION = pre_modelo_predictivo_version, @ESTIMADA = pre_fecha_evento_estimada_utc
FROM   [dbo].[Prediccion] WHERE pre_id = @PREDICCION AND pre_cliente = @CLIENTE AND pre_habilitado = 1
IF @VERSION IS NULL THROW 50001, N'La predicción no existe o no es de este cliente.', 1
IF @OCURRIO = 1 AND @FECHA_EVENTO IS NULL THROW 50002, N'Si el evento ocurrió, indica en qué fecha.', 1
IF @FALLA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE) THROW 50003, N'La falla no es de este cliente.', 1
IF @ORDEN_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE) THROW 50004, N'La orden no es de este cliente.', 1

DECLARE @CLASE VARCHAR(30) = CASE WHEN @OCURRIO = 1 THEN 'VERDADERO POSITIVO'
                                  WHEN @MANTENIMIENTO_PREVIO = 1 THEN 'ACIERTO CON INTERVENCION'
                                  ELSE 'FALSO POSITIVO' END
DECLARE @ERROR FLOAT = CASE WHEN @OCURRIO = 1 AND @ESTIMADA IS NOT NULL THEN ABS(DATEDIFF(DAY, @ESTIMADA, @FECHA_EVENTO)) END
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

BEGIN TRAN
IF EXISTS (SELECT 1 FROM [dbo].[Prediccion_Resultado] WHERE prs_prediccion = @PREDICCION)
    UPDATE [dbo].[Prediccion_Resultado]
       SET prs_ocurrio = @OCURRIO, prs_falla = @FALLA, prs_orden_trabajo = @ORDEN_TRABAJO,
           prs_fecha_evento_real_utc = CASE WHEN @OCURRIO = 1 THEN @FECHA_EVENTO END, prs_error_absoluto = @ERROR,
           prs_mantenimiento_previo = @MANTENIMIENTO_PREVIO, prs_clasificacion = @CLASE, prs_observacion = @OBSERVACION,
           prs_usuario_evaluacion = @USUARIO, prs_fecha_evaluacion_utc = @AHORA, prs_habilitado = 1,
           prs_usuario_actualizacion = @USUARIO, prs_fecha_actualizacion = GETDATE()
     WHERE prs_prediccion = @PREDICCION
ELSE
    INSERT INTO [dbo].[Prediccion_Resultado]
        (prs_prediccion, prs_ocurrio, prs_falla, prs_orden_trabajo, prs_fecha_evento_real_utc, prs_error_absoluto, prs_mantenimiento_previo,
         prs_clasificacion, prs_observacion, prs_usuario_evaluacion, prs_fecha_evaluacion_utc, prs_usuario_creacion, prs_fecha_creacion, prs_habilitado)
    VALUES (@PREDICCION, @OCURRIO, @FALLA, @ORDEN_TRABAJO, CASE WHEN @OCURRIO = 1 THEN @FECHA_EVENTO END, @ERROR, @MANTENIMIENTO_PREVIO,
            @CLASE, @OBSERVACION, @USUARIO, @AHORA, @USUARIO, GETDATE(), 1)
EXEC [dbo].[UPS_AI_MONITOREO] @CLIENTE = @CLIENTE, @VERSION = @VERSION
COMMIT
SELECT @PREDICCION AS ID, @CLASE AS CLASIFICACION, @ERROR AS ERROR_DIAS
RETURN 0
GO

/* ---------- predicciones con el horizonte vencido y sin evaluar (HU-177 CA3) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_POR_EVALUAR]
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
SELECT  p.pre_id AS ID, a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, mp.mpr_nombre AS MODELO, v.mpv_numero AS VERSION,
        mo.mob_codigo AS OBJETIVO, p.pre_probabilidad AS PROBABILIDAD, p.pre_dia_restante AS DIAS, p.pre_fecha_calculo_utc AS CALCULADA,
        p.pre_fecha_evento_estimada_utc AS ESTIMADA, p.pre_orden_trabajo AS OT_ID, ot.otr_correlativo AS OT_NUMERO,
        DATEDIFF(DAY, ISNULL(p.pre_fecha_evento_estimada_utc, p.pre_fecha_vigencia_hasta_utc), @AHORA) AS DIAS_VENCIDA,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] o
                               WHERE o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_activo = p.pre_activo AND o.otr_orden_trabajo_estado >= 3
                                 AND o.otr_orden_trabajo_tipo IN (1, 2, 3)
                                 AND ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion) >= p.pre_fecha_calculo_utc
                                 AND ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion) <= ISNULL(p.pre_fecha_evento_estimada_utc, @AHORA)) THEN 1 ELSE 0 END AS BIT) AS HUBO_INTERVENCION,
        (SELECT TOP 1 f.fal_id FROM [dbo].[Falla] f WHERE f.fal_cliente = @CLIENTE AND f.fal_activo = p.pre_activo AND f.fal_habilitado = 1 AND f.fal_fecha_descarte_utc IS NULL
            AND f.fal_fecha_deteccion_utc >= p.pre_fecha_calculo_utc ORDER BY f.fal_fecha_deteccion_utc) AS FALLA_ID
FROM    [dbo].[Prediccion] p
JOIN    [dbo].[Activo] a ON a.act_id = p.pre_activo
JOIN    [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = p.pre_modelo_predictivo_version
JOIN    [dbo].[Modelo_Predictivo] mp ON mp.mpr_id = v.mpv_modelo_predictivo
LEFT JOIN [dbo].[Modelo_Objetivo] mo ON mo.mob_id = mp.mpr_modelo_objetivo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = p.pre_orden_trabajo
WHERE   p.pre_cliente = @CLIENTE AND p.pre_habilitado = 1
  AND   ISNULL(p.pre_fecha_evento_estimada_utc, p.pre_fecha_vigencia_hasta_utc) < @AHORA
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Resultado] r WHERE r.prs_prediccion = p.pre_id AND r.prs_habilitado = 1)
ORDER BY ISNULL(p.pre_fecha_evento_estimada_utc, p.pre_fecha_vigencia_hasta_utc)
RETURN 0
GO

/* ---------- el panel de desempeño (HU-178) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AI_DESEMPENO]
    @CLIENTE INT
AS
SET NOCOUNT ON
EXEC [dbo].[UPS_AI_MONITOREO] @CLIENTE = @CLIENTE
SELECT  m.mmo_id AS ID, mp.mpr_nombre AS MODELO, v.mpv_numero AS VERSION, v.mpv_id AS VERSION_ID,
        m.mmo_periodo_anio AS ANIO, m.mmo_periodo_mes AS MES,
        m.mmo_prediccion_total AS TOTAL, m.mmo_prediccion_evaluada AS EVALUADAS,
        m.mmo_verdadero_positivo AS VP, m.mmo_falso_positivo AS FP, m.mmo_verdadero_negativo AS VN, m.mmo_falso_negativo AS FN,
        m.mmo_acierto_con_intervencion AS ACIERTO_INTERVENCION,
        m.mmo_metrica_actual AS PRECISION_ACTUAL, m.mmo_metrica_referencia AS PRECISION_REFERENCIA,
        m.mmo_deriva_datos AS DERIVA, m.mmo_requiere_reentrenamiento AS REENTRENAR, m.mmo_observacion AS OBSERVACION
FROM    [dbo].[Modelo_Monitoreo] m
JOIN    [dbo].[Modelo_Predictivo_Version] v ON v.mpv_id = m.mmo_modelo_predictivo_version
JOIN    [dbo].[Modelo_Predictivo] mp ON mp.mpr_id = v.mpv_modelo_predictivo
WHERE   m.mmo_cliente = @CLIENTE AND m.mmo_habilitado = 1
ORDER BY m.mmo_periodo_anio DESC, m.mmo_periodo_mes DESC, mp.mpr_nombre, v.mpv_numero DESC
/* las últimas evaluaciones, para ver qué se concluyó */
SELECT TOP 30 r.prs_id AS ID, a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, r.prs_clasificacion AS CLASIFICACION, r.prs_ocurrio AS OCURRIO,
       r.prs_error_absoluto AS ERROR_DIAS, r.prs_mantenimiento_previo AS INTERVENCION, r.prs_fecha_evaluacion_utc AS EVALUADA, r.prs_observacion AS OBSERVACION
FROM   [dbo].[Prediccion_Resultado] r
JOIN   [dbo].[Prediccion] p ON p.pre_id = r.prs_prediccion
JOIN   [dbo].[Activo] a ON a.act_id = p.pre_activo
WHERE  p.pre_cliente = @CLIENTE AND r.prs_habilitado = 1
ORDER BY r.prs_fecha_evaluacion_utc DESC
RETURN 0
GO

/* ---------- menú: SIGMA AI › Desempeño ---------- */
DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_id = 2210)
DECLARE @NIVEL INT = (SELECT mnu_nivel FROM [dbo].[Menus] WHERE mnu_id = 2210)
INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden], [mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT N'Desempeño', N'Evalúa las predicciones vencidas y mide cómo rinde cada versión del modelo', @NIVEL, @PADRE, 3,
       N'~/View/SigmaAI/Desempeno.aspx', 1, N'mdi mdi-chart-bell-curve', p.[prm_id], 1
FROM   [dbo].[Permiso] p
WHERE  p.[prm_codigo] = N'VER PREDICCIONES'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m WHERE m.[mnu_link] = N'~/View/SigmaAI/Desempeno.aspx')
GO
PRINT '475_SIGMA_AI_DESEMPENO aplicado.'
GO
