USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  16-09-2026
-- DESCRIPTION:     LA SERIE HISTORICA DE UNA VARIABLE DE CONDICION (HU-045).
-- =============================================
-- Lo que se mide en terreno (API_INS_ACTIVO_MEDICION, bloque 141) queda en
-- Activo_Medicion, pero no habia como MIRARLO: la ficha de la variable
-- contaba las mediciones y nada mas. Sin la serie, la degradacion que HU-044
-- promete detectar no la ve nadie.
--
-- LO QUE DEVUELVE
--   Un punto por medicion, en el rango pedido (por defecto los ultimos 90
--   dias), con:
--   · el valor EN LA UNIDAD DE LA VARIABLE, que es la de los umbrales: si
--     la medicion se tomo en otra unidad (K en vez de °C) se vuelve desde el
--     canonico con el factor y el offset de la unidad de la variable
--     (canonico = valor * factor + offset, bloque 141). Comparar el canonico
--     contra los umbrales daria CRITICO a 45 °C, porque 318 K > 80;
--   · NIVEL, el veredicto contra los umbrales de la variable, calculado
--     ACA con la misma regla que usa API_INS_ACTIVO_MEDICION al registrar:
--     CRITICO (>= critico), ADVERTENCIA (>= advertencia), FUERA_RANGO
--     (< minimo o > maximo), NORMAL. Un punto no cambia de color entre la
--     app y la web porque las dos preguntan aqui;
--   · el origen del dato (HU-045 #2): quien lo registro, cuando, y si vino
--     de un checklist (con la ejecucion), de una orden (con el correlativo)
--     o a mano; y como se ingreso (teclado o voz).
--   Las fechas van en UTC (como se guardan) y en hora de Santiago (como se
--   muestran).
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MEDICION_SERIE]
@CLIENTE          INT,
@ACTIVO_VARIABLE  INT,
@DESDE            DATETIME = NULL,
@HASTA            DATETIME = NULL,
@MAXIMO           INT = 2000

AS
SET NOCOUNT ON

SET @HASTA = ISNULL(@HASTA, GETUTCDATE())
SET @DESDE = ISNULL(@DESDE, DATEADD(DAY, -90, @HASTA))

DECLARE @MIN DECIMAL(18,6), @MAX DECIMAL(18,6), @ADV DECIMAL(18,6), @CRI DECIMAL(18,6)
       ,@UNIDAD INT, @FACTOR DECIMAL(18,8), @OFFSET DECIMAL(18,8)

SELECT  @MIN = ava_valor_minimo, @MAX = ava_valor_maximo,
        @ADV = ava_valor_advertencia, @CRI = ava_valor_critico,
        @UNIDAD = ava_unidad_medida
FROM    [dbo].[Activo_Variable]
WHERE   ava_id = @ACTIVO_VARIABLE AND ava_cliente = @CLIENTE

IF @@ROWCOUNT = 0
BEGIN
    RAISERROR('1.- LA VARIABLE NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @FACTOR = ISNULL(ume_factor, 1), @OFFSET = ISNULL(ume_offset, 0)
FROM   [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD
SET @FACTOR = ISNULL(@FACTOR, 1); SET @OFFSET = ISNULL(@OFFSET, 0)

    SELECT  TOP (@MAXIMO)
            m.amd_id                                AS AMD_ID
           ,m.amd_fecha_medicion_utc                AS FECHA_UTC
           ,CAST(m.amd_fecha_medicion_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS FECHA
           ,(CASE WHEN m.amd_unidad_medida = @UNIDAD OR m.amd_unidad_medida IS NULL OR m.amd_valor_canonico IS NULL OR @FACTOR = 0 THEN m.amd_valor ELSE (m.amd_valor_canonico - @OFFSET) / @FACTOR END) AS VALOR
           ,m.amd_valor                             AS VALOR_ORIGINAL
           ,ISNULL(um.ume_simbolo, '')              AS UNIDAD_ORIGINAL
           ,CASE
                WHEN @CRI IS NOT NULL AND (CASE WHEN m.amd_unidad_medida = @UNIDAD OR m.amd_unidad_medida IS NULL OR m.amd_valor_canonico IS NULL OR @FACTOR = 0 THEN m.amd_valor ELSE (m.amd_valor_canonico - @OFFSET) / @FACTOR END) >= @CRI THEN 'CRITICO'
                WHEN @ADV IS NOT NULL AND (CASE WHEN m.amd_unidad_medida = @UNIDAD OR m.amd_unidad_medida IS NULL OR m.amd_valor_canonico IS NULL OR @FACTOR = 0 THEN m.amd_valor ELSE (m.amd_valor_canonico - @OFFSET) / @FACTOR END) >= @ADV THEN 'ADVERTENCIA'
                WHEN (@MIN IS NOT NULL AND (CASE WHEN m.amd_unidad_medida = @UNIDAD OR m.amd_unidad_medida IS NULL OR m.amd_valor_canonico IS NULL OR @FACTOR = 0 THEN m.amd_valor ELSE (m.amd_valor_canonico - @OFFSET) / @FACTOR END) < @MIN)
                  OR (@MAX IS NOT NULL AND (CASE WHEN m.amd_unidad_medida = @UNIDAD OR m.amd_unidad_medida IS NULL OR m.amd_valor_canonico IS NULL OR @FACTOR = 0 THEN m.amd_valor ELSE (m.amd_valor_canonico - @OFFSET) / @FACTOR END) > @MAX) THEN 'FUERA_RANGO'
                ELSE 'NORMAL'
            END                                     AS NIVEL
           ,ISNULL(mc.mca_nombre, '')               AS CALIDAD
           ,ISNULL(dor.dor_codigo, 'MANUAL')        AS ORIGEN_CODIGO
           ,ISNULL(dor.dor_nombre, 'Ingreso manual') AS ORIGEN
           ,CASE m.amd_entrada_modo WHEN 2 THEN 'Voz' ELSE 'Teclado' END AS ENTRADA
           ,m.amd_orden_trabajo                     AS ORDEN_TRABAJO
           ,ot.otr_correlativo                      AS OT_CORRELATIVO
           ,cer.cer_checklist_ejecucion             AS CHECKLIST_EJECUCION
           ,m.amd_observacion                       AS OBSERVACION
           ,u.usu_nombre + ' ' + ISNULL(u.usu_apellido_paterno, '') AS USUARIO_NOMBRE
           ,m.amd_fecha_creacion                    AS FECHA_REGISTRO_UTC
    FROM    [dbo].[Activo_Medicion] m
    LEFT JOIN [dbo].[Unidad_Medida]    um  ON um.ume_id  = m.amd_unidad_medida
    LEFT JOIN [dbo].[Medicion_Calidad] mc  ON mc.mca_id  = m.amd_medicion_calidad
    LEFT JOIN [dbo].[Dato_Origen]      dor ON dor.dor_id = m.amd_dato_origen
    LEFT JOIN [dbo].[Orden_Trabajo]    ot  ON ot.otr_id  = m.amd_orden_trabajo
    LEFT JOIN [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_id = m.amd_checklist_ejecucion_respuesta
    LEFT JOIN [dbo].[Usuario]          u   ON u.usu_id   = m.amd_usuario_creacion
    WHERE   m.amd_cliente = @CLIENTE
      AND   m.amd_activo_variable = @ACTIVO_VARIABLE
      AND   m.amd_fecha_medicion_utc >= @DESDE
      AND   m.amd_fecha_medicion_utc <= @HASTA
    ORDER BY m.amd_fecha_medicion_utc

RETURN(0)
GO

/* Un resumen para la cabecera de la pantalla: cuantos puntos, cuantos fuera
   de umbral y la tendencia simple (ultimo valor contra el promedio del
   rango), que es lo que el jefe de mantenimiento mira antes del grafico. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MEDICION_SERIE_RESUMEN]
@CLIENTE          INT,
@ACTIVO_VARIABLE  INT,
@DESDE            DATETIME = NULL,
@HASTA            DATETIME = NULL

AS
SET NOCOUNT ON

SET @HASTA = ISNULL(@HASTA, GETUTCDATE())
SET @DESDE = ISNULL(@DESDE, DATEADD(DAY, -90, @HASTA))

DECLARE @MIN DECIMAL(18,6), @MAX DECIMAL(18,6), @ADV DECIMAL(18,6), @CRI DECIMAL(18,6)
       ,@UNIDAD INT, @FACTOR DECIMAL(18,8), @OFFSET DECIMAL(18,8)
SELECT  @MIN = ava_valor_minimo, @MAX = ava_valor_maximo, @ADV = ava_valor_advertencia, @CRI = ava_valor_critico, @UNIDAD = ava_unidad_medida
FROM    [dbo].[Activo_Variable] WHERE ava_id = @ACTIVO_VARIABLE AND ava_cliente = @CLIENTE
SELECT @FACTOR = ISNULL(ume_factor, 1), @OFFSET = ISNULL(ume_offset, 0) FROM [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD
SET @FACTOR = ISNULL(@FACTOR, 1); SET @OFFSET = ISNULL(@OFFSET, 0)

    SELECT  COUNT(*)                                       AS PUNTOS
           ,SUM(CASE WHEN (@CRI IS NOT NULL AND v >= @CRI) THEN 1 ELSE 0 END) AS CRITICOS
           ,SUM(CASE WHEN (@ADV IS NOT NULL AND v >= @ADV AND (@CRI IS NULL OR v < @CRI)) THEN 1 ELSE 0 END) AS ADVERTENCIAS
           ,SUM(CASE WHEN (@MIN IS NOT NULL AND v < @MIN) OR (@MAX IS NOT NULL AND v > @MAX) THEN 1 ELSE 0 END) AS FUERA_RANGO
           ,MIN(v)                                         AS VALOR_MINIMO
           ,MAX(v)                                         AS VALOR_MAXIMO
           ,AVG(v)                                         AS PROMEDIO
           ,(SELECT TOP 1 (CASE WHEN amd_unidad_medida = @UNIDAD OR amd_unidad_medida IS NULL OR amd_valor_canonico IS NULL OR @FACTOR = 0 THEN amd_valor ELSE (amd_valor_canonico - @OFFSET) / @FACTOR END) FROM [dbo].[Activo_Medicion]
              WHERE amd_cliente = @CLIENTE AND amd_activo_variable = @ACTIVO_VARIABLE
                AND amd_fecha_medicion_utc BETWEEN @DESDE AND @HASTA
              ORDER BY amd_fecha_medicion_utc DESC)        AS ULTIMO_VALOR
           ,(SELECT TOP 1 amd_fecha_medicion_utc FROM [dbo].[Activo_Medicion]
              WHERE amd_cliente = @CLIENTE AND amd_activo_variable = @ACTIVO_VARIABLE
                AND amd_fecha_medicion_utc BETWEEN @DESDE AND @HASTA
              ORDER BY amd_fecha_medicion_utc DESC)        AS ULTIMA_FECHA_UTC
    FROM   (SELECT (CASE WHEN amd_unidad_medida = @UNIDAD OR amd_unidad_medida IS NULL OR amd_valor_canonico IS NULL OR @FACTOR = 0 THEN amd_valor ELSE (amd_valor_canonico - @OFFSET) / @FACTOR END) AS v
            FROM   [dbo].[Activo_Medicion]
            WHERE  amd_cliente = @CLIENTE AND amd_activo_variable = @ACTIVO_VARIABLE
              AND  amd_fecha_medicion_utc BETWEEN @DESDE AND @HASTA) x

RETURN(0)
GO

/* La pantalla de la serie, oculta en el arbol y colgando de Variables. */
DECLARE @RAIZ INT
SELECT @RAIZ = mnu_padre FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Variables/ActivoVariables.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Variables/ActivoVariableSerie.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Serie de una variable (detalle)', N'La evolución de una variable de condición en el tiempo', 3, @RAIZ, 99,
            N'~/View/Activos/Variables/ActivoVariableSerie.aspx', 0, NULL,
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER VARIABLES ACTIVO'), 1)
GO


/* ---------- El origen del dato dice de donde vino de verdad ----------
   API_INS_ACTIVO_MEDICION grababa siempre Dato_Origen 3 (MANUAL) aunque la
   medicion llegara con una orden de trabajo; la serie la mostraba como
   "Ingreso manual · Orden OT-34", que se lee como contradiccion. Con orden,
   el origen es 4 (ORDEN TRABAJO); si no, MANUAL. (El SP no recibe la
   respuesta de checklist: ese enlace lo escribe el cierre del checklist.) Parche sobre la definicion vigente (patron del bloque 76),
   idempotente. */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.API_INS_ACTIVO_MEDICION'))
IF @SQL IS NOT NULL AND @SQL LIKE '%3,   -- MANUAL: no hay sensores%'
BEGIN
    SET @SQL = REPLACE(@SQL, '3,   -- MANUAL: no hay sensores',
        'CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN 4 ELSE 3 END,   -- ORDEN TRABAJO o MANUAL')
    /* La cabecera puede venir como CREATE PROCEDURE, CREATE OR ALTER o con
       varios espacios (la trampa del bloque 77): se normaliza antes. */
    SET @SQL = REPLACE(REPLACE(REPLACE(REPLACE(@SQL,
        'CREATE OR ALTER PROCEDURE', 'ALTER PROCEDURE'),
        'CREATE   PROCEDURE', 'ALTER PROCEDURE'),
        'CREATE  PROCEDURE', 'ALTER PROCEDURE'),
        'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- API_INS_ACTIVO_MEDICION: el origen sigue a la orden'
END
ELSE PRINT '--- API_INS_ACTIVO_MEDICION ya distingue el origen'
GO

UPDATE [dbo].[Activo_Medicion] SET amd_dato_origen = 4 WHERE amd_orden_trabajo IS NOT NULL AND amd_dato_origen = 3
UPDATE [dbo].[Activo_Medicion] SET amd_dato_origen = 1 WHERE amd_checklist_ejecucion_respuesta IS NOT NULL AND amd_dato_origen = 3
GO

PRINT '--- Serie historica de variables lista'
GO
