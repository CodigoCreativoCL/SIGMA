/* ============================================================================
   SIGMA — Bloque 75
   EL DESGLOSE COMPLETO DE LO QUE SE ESCANEA
   ----------------------------------------------------------------------------

   TRES PREGUNTAS, LA MISMA PANTALLA

     Se escanea una bodega, un estante o un repuesto, y en los tres casos la
     pregunta es la misma: "que hay aca, completo". Los tres SP devuelven
     cabecera + detalle con la misma forma, para que la pantalla no tenga
     tres maneras de dibujar lo mismo.

   EL LOTE FALTABA Y SE NOTABA COMO UN ERROR

     Desde el bloque 71 el saldo se lleva por (repuesto, bodega, ubicacion,
     lote). SEL_UBICACION_DESGLOSE leia esa tabla sin mostrar el lote, asi
     que un repuesto con dos lotes en el mismo estante aparecia DOS VECES,
     con dos cantidades, y sin nada que explicara por que.

     Se lee como un error de la pantalla. Es el dato correcto al que le
     falta la columna que lo justifica.

   EL REPUESTO YA NO REDIRIGE

     Escanear un repuesto mandaba a su ficha de existencia. Funcionaba, pero
     rompia lo que se esta armando: el bodeguero esta de pie frente a un
     estante con el telefono en la mano, y sacarlo a otra pantalla lo obliga
     a volver para escanear lo siguiente. Ahora contesta en el mismo lugar
     que las otras dos.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. QUE HAY EN ESTE ESTANTE — ahora con el lote
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_UBICACION_DESGLOSE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_UBICACION_DESGLOSE]
GO

CREATE PROCEDURE [dbo].[SEL_UBICACION_DESGLOSE]
    @CLIENTE   INT,
    @UBICACION INT
AS
SET NOCOUNT ON

    SELECT  ub.bub_id, ub.bub_codigo, ub.bub_nombre, ub.bub_habilitado,
            b.bod_id, b.bod_codigo, b.bod_nombre,
            ISNULL(ci.cin_nombre, '') AS PLANTA
    FROM    [dbo].[Bodega_Ubicacion] ub
    JOIN    [dbo].[Bodega] b ON b.bod_id = ub.bub_bodega
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   ub.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ''                           AS UBICACION,
            ''                           AS UBICACION_NOMBRE,
            ''                           AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega_ubicacion = @UBICACION
      AND   s.isa_cantidad <> 0
    ORDER BY r.rep_codigo, l.rlo_fecha_vencimiento
GO


/* ========================================================================
   2. QUE HAY EN ESTA BODEGA — estante por estante, lote por lote
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_BODEGA_DESGLOSE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_BODEGA_DESGLOSE]
GO

CREATE PROCEDURE [dbo].[SEL_BODEGA_DESGLOSE]
    @CLIENTE INT,
    @BODEGA  INT
AS
SET NOCOUNT ON

    SELECT  b.bod_id, b.bod_codigo, b.bod_nombre, b.bod_habilitado,
            ISNULL(b.bod_descripcion, '') AS bod_descripcion,
            ISNULL(ci.cin_nombre, '')     AS PLANTA
    FROM    [dbo].[Bodega] b
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_id = @BODEGA AND b.bod_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')    AS UBICACION_NOMBRE,
            ''                           AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega  = @BODEGA
      AND   s.isa_cantidad <> 0
    ORDER BY UBICACION, r.rep_codigo, l.rlo_fecha_vencimiento
GO


/* ========================================================================
   3. DONDE ESTA ESTE REPUESTO

      La cabecera trae el TOTAL: parado frente al estante, la primera
      pregunta es "cuanto tengo en total", y sumar de cabeza las filas del
      detalle es justo lo que no hay que pedirle a nadie.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_DESGLOSE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_REPUESTO_DESGLOSE]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_DESGLOSE]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre, r.rep_habilitado,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            r.rep_controla_lote,
            ume.ume_simbolo              AS UNIDAD,
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id AND s.isa_cliente = @CLIENTE), 0) AS TOTAL
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    WHERE   r.rep_id = @REPUESTO AND r.rep_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')    AS UBICACION_NOMBRE,
            b.bod_codigo + ' · ' + b.bod_nombre AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    JOIN    [dbo].[Bodega] b          ON b.bod_id = s.isa_bodega
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_repuesto = @REPUESTO
      AND   s.isa_cantidad <> 0
    ORDER BY b.bod_codigo, UBICACION, l.rlo_fecha_vencimiento
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
DECLARE @UBI INT, @BOD INT, @REP INT

SELECT @UBI = bub_id FROM [dbo].[Bodega_Ubicacion] WHERE bub_codigo = 'ZONA-LIQ'
SELECT @BOD = bod_id FROM [dbo].[Bodega] WHERE bod_codigo = 'DEMO-BOD-CENTRAL'
SELECT @REP = rep_id FROM [dbo].[Repuesto] WHERE rep_codigo = 'DEMO-ACEITE-68'

PRINT '--- Estante ZONA-LIQ ---'
EXEC [dbo].[SEL_UBICACION_DESGLOSE] @CLIENTE = 1, @UBICACION = @UBI

PRINT '--- Repuesto DEMO-ACEITE-68 ---'
EXEC [dbo].[SEL_REPUESTO_DESGLOSE] @CLIENTE = 1, @REPUESTO = @REP
GO
