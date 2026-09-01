/* ============================================================================
   SIGMA — Bloque 81
   NOTIFICACIONES: EL SISTEMA AVISA LO QUE ENCUENTRA
   ----------------------------------------------------------------------------

   NO SE INVENTA UNA TABLA DE NOTIFICACIONES

     Alerta ya existe, con diez tipos, cinco estados y columnas para colgar el
     hallazgo de lo que sea -activo, medidor, repuesto, bodega, orden de
     trabajo, prediccion-. Estaba vacia porque nadie la llenaba, no porque
     estuviera mal.

     Una tabla nueva de "notificaciones" al lado terminaria duplicando lo
     mismo, y el dia que alguien pregunte "cuantos problemas abiertos hay"
     habria dos respuestas distintas.

   LA ALERTA ES DEL CLIENTE, LA LECTURA ES DE CADA PERSONA

     Que un repuesto este bajo el minimo es UN hecho, no uno por usuario. Pero
     "no leidas" es de cada uno: que el jefe ya la haya visto no significa que
     el bodeguero tambien.

     Por eso Alerta_Lectura es una tabla aparte. Meter una marca de leido en
     Alerta obligaria a crear una fila por usuario y por hallazgo, y con
     cincuenta usuarios eso son cincuenta filas para decir una sola cosa.

   QUIEN VE QUE: EL PERMISO, NO UNA LISTA DE DESTINATARIOS

     Cada tipo de alerta declara el permiso que hay que tener para verla. Una
     alerta de stock la ven quienes pueden ver existencias; una de activo,
     quienes pueden ver activos.

     La alternativa -guardar destinatarios por alerta- obliga a decidir a
     quien avisar en el momento de detectar, y ese dia el organigrama todavia
     no cambio. Con el permiso, cuando alguien entra al perfil de bodeguero ve
     las alertas de bodega sin que nadie tenga que reasignar nada.

   EL DETECTOR ES IDEMPOTENTE, Y CIERRA LO QUE YA NO PASA

     Se puede correr cada cinco minutos. Si el hallazgo sigue abierto no crea
     otro; si la condicion dejo de cumplirse -alguien repuso el stock- la
     cierra sola. Una bandeja que solo acumula deja de leerse a la semana.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. EL TIPO DE ALERTA APRENDE A QUIEN LE IMPORTA
   ======================================================================== */
IF COL_LENGTH('dbo.Alerta_Tipo', 'alt_permiso') IS NULL
    ALTER TABLE [dbo].[Alerta_Tipo] ADD [alt_permiso] INT NULL
GO

IF COL_LENGTH('dbo.Alerta_Tipo', 'alt_icono') IS NULL
    ALTER TABLE [dbo].[Alerta_Tipo] ADD [alt_icono] NVARCHAR(80) NULL
GO

/* Donde se resuelve el hallazgo. Es lo que convierte una notificacion en algo
   accionable: sin destino, avisar que hay un problema deja a la persona
   buscandolo por el menu. */
IF COL_LENGTH('dbo.Alerta_Tipo', 'alt_menu_link') IS NULL
    ALTER TABLE [dbo].[Alerta_Tipo] ADD [alt_menu_link] NVARCHAR(400) NULL
GO

IF COL_LENGTH('dbo.Alerta', 'ale_repuesto_lote') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_repuesto_lote] INT NULL
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Alerta_Repuesto_Lote')
    ALTER TABLE [dbo].[Alerta] WITH CHECK ADD CONSTRAINT [FK_Alerta_Repuesto_Lote]
        FOREIGN KEY ([ale_repuesto_lote]) REFERENCES [dbo].[Repuesto_Lote]([rlo_id])
GO


/* Los dos tipos de lote que faltaban: se construyo el control de vencimiento
   y nadie avisaba de el. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE VENCIDO')
    INSERT INTO [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado)
    VALUES ('LOTE VENCIDO', 'Lote vencido', 11, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE POR VENCER')
    INSERT INTO [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado)
    VALUES ('LOTE POR VENCER', 'Lote próximo a vencer', 12, 1)
GO


UPDATE t
SET    t.alt_permiso   = p.prm_id,
       t.alt_icono     = v.ico,
       t.alt_menu_link = v.lnk
FROM   [dbo].[Alerta_Tipo] t
JOIN   (VALUES
    ('STOCK MINIMO',                  'VER EXISTENCIAS', 'mdi mdi-arrow-down-bold-circle-outline', '~/View/Inventario/Existencias/Existencias.aspx'),
    ('STOCK MAXIMO',                  'VER EXISTENCIAS', 'mdi mdi-arrow-up-bold-circle-outline',   '~/View/Inventario/Existencias/Existencias.aspx'),
    ('LOTE VENCIDO',                  'VER REPUESTOS',   'mdi mdi-calendar-remove-outline',        '~/View/Inventario/Repuestos/Repuestos.aspx'),
    ('LOTE POR VENCER',               'VER REPUESTOS',   'mdi mdi-calendar-clock-outline',         '~/View/Inventario/Repuestos/Repuestos.aspx'),
    ('MEDICION FUERA RANGO',          'VER ACTIVOS',     'mdi mdi-gauge',                          NULL),
    ('HALLAZGO CRITICO',              'VER ACTIVOS',     'mdi mdi-alert-octagon-outline',          NULL),
    ('OCURRENCIA VENCIDA',            'VER ACTIVOS',     'mdi mdi-calendar-alert',                 NULL),
    ('PREDICCION RIESGO',             'VER ACTIVOS',     'mdi mdi-chart-line',                     NULL),
    ('PERMISO VENCIDO',               'VER ACTIVOS',     'mdi mdi-file-document-remove-outline',   NULL),
    ('MEDIDOR SIN LECTURA',           'VER ACTIVOS',     'mdi mdi-eye-off-outline',                NULL),
    ('DESCUBRIMIENTO TERRENO',        'VER ACTIVOS',     'mdi mdi-map-marker-question-outline',    NULL),
    ('MEDIDOR PROXIMO MANTENIMIENTO', 'VER ACTIVOS',     'mdi mdi-wrench-clock',                   NULL)
) AS v (cod, permiso, ico, lnk) ON v.cod = t.alt_codigo
LEFT JOIN [dbo].[Permiso] p ON p.prm_codigo = v.permiso

PRINT '--- Tipos de alerta con permiso, icono y destino: ' + LTRIM(STR(@@ROWCOUNT))
GO


/* ========================================================================
   2. QUIEN LEYO QUE
   ======================================================================== */
IF OBJECT_ID('dbo.Alerta_Lectura') IS NULL
BEGIN
    CREATE TABLE [dbo].[Alerta_Lectura] (
        [alr_id]      INT IDENTITY(1,1) NOT NULL,
        [alr_alerta]  INT NOT NULL,
        [alr_usuario] INT NOT NULL,
        [alr_fecha]   DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT [PK_Alerta_Lectura] PRIMARY KEY CLUSTERED ([alr_id]),
        /* Una lectura por persona y alerta: leer dos veces no es leer mas. */
        CONSTRAINT [UX_Alerta_Lectura] UNIQUE ([alr_alerta], [alr_usuario]),
        CONSTRAINT [FK_Alerta_Lectura_Alerta]  FOREIGN KEY ([alr_alerta])  REFERENCES [dbo].[Alerta]([ale_id]),
        CONSTRAINT [FK_Alerta_Lectura_Usuario] FOREIGN KEY ([alr_usuario]) REFERENCES [dbo].[Usuario]([usu_id])
    )
    PRINT '--- Tabla Alerta_Lectura creada'
END
ELSE PRINT '--- Tabla Alerta_Lectura ya existia'
GO


/* ========================================================================
   3. EL DETECTOR DE INVENTARIO

      Corre entero cada vez: abre lo que empezo a pasar y cierra lo que dejo
      de pasar. Sin lo segundo la bandeja solo crece, y una bandeja que solo
      crece deja de leerse a la semana.
   ======================================================================== */
IF OBJECT_ID('dbo.GEN_ALERTA_INVENTARIO') IS NOT NULL DROP PROCEDURE [dbo].[GEN_ALERTA_INVENTARIO]
GO

CREATE PROCEDURE [dbo].[GEN_ALERTA_INVENTARIO]
    @CLIENTE INT,
    @USUARIO INT = 1,
    @DIAS_AVISO_VENCIMIENTO INT = 60
AS
SET NOCOUNT ON

DECLARE @MIN INT, @MAX INT, @VENC INT, @POR_VENCER INT
DECLARE @NUEVA INT, @RESUELTA INT
DECLARE @SEV_ALTA INT, @SEV_ADV INT
DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @ABIERTAS TABLE (ID INT)

SELECT @MIN        = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'STOCK MINIMO'
SELECT @MAX        = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'STOCK MAXIMO'
SELECT @VENC       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE VENCIDO'
SELECT @POR_VENCER = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE POR VENCER'

SELECT @NUEVA    = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'
SELECT @RESUELTA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA'

SELECT @SEV_ALTA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'
SELECT @SEV_ADV  = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ADVERTENCIA'


/* ---- Lo que HOY esta mal ----
   Se calcula una vez y se guarda, porque se usa dos veces: para abrir lo que
   falta y para cerrar lo que sobra. */
IF OBJECT_ID('tempdb..#HALLAZGO') IS NOT NULL DROP TABLE #HALLAZGO

CREATE TABLE #HALLAZGO (
    TIPO INT, REPUESTO INT, BODEGA INT NULL, LOTE INT NULL,
    TITULO NVARCHAR(400), DESCRIPCION NVARCHAR(1000),
    OBSERVADO DECIMAL(18,4), UMBRAL DECIMAL(18,4),
    UNIDAD INT NULL, SEVERIDAD INT)

/* Stock: el umbral esta definido por (repuesto, bodega), asi que la
   comparacion se hace sobre el TOTAL de la bodega y no sobre cada estante. */
;WITH SALDO AS (
    SELECT s.isa_repuesto, s.isa_bodega, SUM(s.isa_cantidad) AS CANT
    FROM   [dbo].[Inventario_Saldo] s
    WHERE  s.isa_cliente = @CLIENTE
    GROUP BY s.isa_repuesto, s.isa_bodega
)
INSERT INTO #HALLAZGO
SELECT  @MIN, r.rep_id, b.bod_id, NULL,
        r.rep_codigo + N' bajo el mínimo en ' + b.bod_nombre,
        N'Hay ' + LTRIM(STR(CAST(ISNULL(sa.CANT, 0) AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo +
        N' y el mínimo es ' + LTRIM(STR(CAST(st.rbs_stock_minimo AS DECIMAL(18,2)), 18, 2)) +
        N'. Faltan ' + LTRIM(STR(CAST(st.rbs_stock_minimo - ISNULL(sa.CANT, 0) AS DECIMAL(18,2)), 18, 2)) + N'.',
        ISNULL(sa.CANT, 0), st.rbs_stock_minimo, r.rep_unidad_medida, @SEV_ALTA
FROM    [dbo].[Repuesto_Bodega_Stock] st
JOIN    [dbo].[Repuesto] r ON r.rep_id = st.rbs_repuesto AND r.rep_cliente = @CLIENTE
JOIN    [dbo].[Bodega] b   ON b.bod_id = st.rbs_bodega
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
LEFT JOIN SALDO sa ON sa.isa_repuesto = st.rbs_repuesto AND sa.isa_bodega = st.rbs_bodega
WHERE   st.rbs_habilitado = 1
  AND   r.rep_habilitado = 1
  AND   st.rbs_stock_minimo IS NOT NULL
  AND   ISNULL(sa.CANT, 0) < st.rbs_stock_minimo

;WITH SALDO AS (
    SELECT s.isa_repuesto, s.isa_bodega, SUM(s.isa_cantidad) AS CANT
    FROM   [dbo].[Inventario_Saldo] s
    WHERE  s.isa_cliente = @CLIENTE
    GROUP BY s.isa_repuesto, s.isa_bodega
)
INSERT INTO #HALLAZGO
SELECT  @MAX, r.rep_id, b.bod_id, NULL,
        r.rep_codigo + N' sobre el máximo en ' + b.bod_nombre,
        N'Hay ' + LTRIM(STR(CAST(sa.CANT AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo +
        N' y el máximo es ' + LTRIM(STR(CAST(st.rbs_stock_maximo AS DECIMAL(18,2)), 18, 2)) + N'.',
        sa.CANT, st.rbs_stock_maximo, r.rep_unidad_medida, @SEV_ADV
FROM    [dbo].[Repuesto_Bodega_Stock] st
JOIN    [dbo].[Repuesto] r ON r.rep_id = st.rbs_repuesto AND r.rep_cliente = @CLIENTE
JOIN    [dbo].[Bodega] b   ON b.bod_id = st.rbs_bodega
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
JOIN    SALDO sa ON sa.isa_repuesto = st.rbs_repuesto AND sa.isa_bodega = st.rbs_bodega
WHERE   st.rbs_habilitado = 1
  AND   r.rep_habilitado = 1
  AND   st.rbs_stock_maximo IS NOT NULL
  AND   sa.CANT > st.rbs_stock_maximo

/* Lotes: solo los que TODAVIA tienen existencia. Avisar de un lote vencido
   que ya se consumio entero es ruido: no hay nada que hacer con el. */
INSERT INTO #HALLAZGO
SELECT  CASE WHEN l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE) THEN @VENC ELSE @POR_VENCER END,
        r.rep_id, NULL, l.rlo_id,
        CASE WHEN l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE)
             THEN N'Lote ' + l.rlo_codigo + N' de ' + r.rep_codigo + N' está vencido'
             ELSE N'Lote ' + l.rlo_codigo + N' de ' + r.rep_codigo + N' vence pronto' END,
        N'Vence el ' + CONVERT(NVARCHAR(10), l.rlo_fecha_vencimiento, 103) +
        N' y quedan ' + LTRIM(STR(CAST(q.CANT AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo + N'.',
        q.CANT, NULL, r.rep_unidad_medida,
        CASE WHEN l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE) THEN @SEV_ALTA ELSE @SEV_ADV END
FROM    [dbo].[Repuesto_Lote] l
JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
JOIN    (SELECT isa_repuesto_lote, SUM(isa_cantidad) AS CANT
         FROM   [dbo].[Inventario_Saldo]
         WHERE  isa_cliente = @CLIENTE AND isa_repuesto_lote IS NOT NULL
         GROUP BY isa_repuesto_lote
         HAVING SUM(isa_cantidad) > 0) q ON q.isa_repuesto_lote = l.rlo_id
WHERE   l.rlo_cliente = @CLIENTE
  AND   l.rlo_habilitado = 1
  AND   l.rlo_fecha_vencimiento IS NOT NULL
  AND   DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.rlo_fecha_vencimiento) <= @DIAS_AVISO_VENCIMIENTO


/* ---- Abrir lo que empezo a pasar ---- */
INSERT INTO [dbo].[Alerta]
    (ale_uuid, ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
     ale_titulo, ale_descripcion, ale_fecha_deteccion_utc,
     ale_repuesto, ale_bodega, ale_repuesto_lote,
     ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
     ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
SELECT  NEWID(), @CLIENTE, h.TIPO, @NUEVA, h.SEVERIDAD,
        h.TITULO, h.DESCRIPCION, @AHORA,
        h.REPUESTO, h.BODEGA, h.LOTE,
        h.OBSERVADO, h.UMBRAL, h.UNIDAD,
        @USUARIO, GETDATE(), 1
FROM    #HALLAZGO h
WHERE   NOT EXISTS (
            SELECT 1 FROM [dbo].[Alerta] a
            WHERE  a.ale_cliente = @CLIENTE
              AND  a.ale_alerta_tipo = h.TIPO
              AND  a.ale_habilitado = 1
              AND  a.ale_alerta_estado NOT IN (@RESUELTA,
                     (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'))
              AND  ISNULL(a.ale_repuesto, -1)      = ISNULL(h.REPUESTO, -1)
              AND  ISNULL(a.ale_bodega, -1)        = ISNULL(h.BODEGA, -1)
              AND  ISNULL(a.ale_repuesto_lote, -1) = ISNULL(h.LOTE, -1))

DECLARE @ABIERTAS_N INT = @@ROWCOUNT


/* ---- Cerrar lo que dejo de pasar ----
   Se marca RESUELTA y no se borra: quien pregunte "cuantas veces nos quedamos
   sin este repuesto" necesita que la historia siga ahi. */
UPDATE  a
SET     a.ale_alerta_estado       = @RESUELTA,
        a.ale_fecha_atencion_utc  = @AHORA,
        a.ale_usuario_actualizacion = @USUARIO,
        a.ale_fecha_actualizacion = GETDATE()
FROM    [dbo].[Alerta] a
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   a.ale_alerta_tipo IN (@MIN, @MAX, @VENC, @POR_VENCER)
  AND   a.ale_alerta_estado NOT IN (@RESUELTA,
          (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'))
  AND   NOT EXISTS (
            SELECT 1 FROM #HALLAZGO h
            WHERE  h.TIPO = a.ale_alerta_tipo
              AND  ISNULL(h.REPUESTO, -1) = ISNULL(a.ale_repuesto, -1)
              AND  ISNULL(h.BODEGA, -1)   = ISNULL(a.ale_bodega, -1)
              AND  ISNULL(h.LOTE, -1)     = ISNULL(a.ale_repuesto_lote, -1))

SELECT  @ABIERTAS_N AS ABIERTAS, @@ROWCOUNT AS CERRADAS
RETURN 0
GO
