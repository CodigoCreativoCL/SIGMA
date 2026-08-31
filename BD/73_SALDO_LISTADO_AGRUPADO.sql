/* ============================================================================
   SIGMA — Bloque 73
   EL LISTADO DE EXISTENCIAS VUELVE A MOSTRAR UNA FILA POR REPUESTO Y BODEGA
   ----------------------------------------------------------------------------

   LO QUE ROMPIO EL BLOQUE 71

     Al partir el saldo por ubicacion y lote, SEL_INVENTARIO_SALDO -que hace
     un SELECT plano sobre la tabla- paso a devolver UNA FILA POR CUBO.
     DEMO-ROD-6205 en la bodega central salia dos veces: 1 en el cubo sin
     ubicacion y 2 en PA-E1-N1.

     Y lo peor no era la fila repetida. Era que BAJO_MINIMO comparaba el
     umbral contra la cantidad DE UN CUBO. Un repuesto con minimo 3 y tres
     unidades repartidas en dos estantes disparaba alerta roja en los dos,
     teniendo exactamente lo que debia tener.

   EL NIVEL DE LA PREGUNTA NO ES EL NIVEL DEL DATO

     El saldo se guarda por cubo porque un estante tiene que poder decir que
     tiene. Pero el umbral esta definido en Repuesto_Bodega_Stock por
     (repuesto, bodega): nadie fija un minimo por estante, se fija para la
     bodega. Entonces la alerta se calcula donde esta definida, y el listado
     agrupa.

     El desglose no se pierde: UBICACIONES dice en cuantas esta repartido, y
     SEL_BODEGA_DESGLOSE / SEL_UBICACION_DESGLOSE lo abren.

   UBICACION_CODIGO CAMBIA DE SIGNIFICADO

     Antes era "donde lo dejaron la ultima vez", sacado del ultimo
     movimiento — una aproximacion, porque el ultimo movimiento pudo ser una
     salida. Ahora, cuando hay existencia en UNA sola ubicacion, es
     literalmente donde esta. Cuando esta repartido, se devuelve NULL: la
     pantalla muestra el conteo y no elige una arbitrariamente para llenar
     el hueco.
   ============================================================================ */

SET NOCOUNT ON
GO

IF OBJECT_ID('dbo.SEL_INVENTARIO_SALDO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_INVENTARIO_SALDO]
GO

CREATE PROCEDURE [dbo].[SEL_INVENTARIO_SALDO]
    @CLIENTE     INT,
    @REPUESTO    INT = NULL,
    @BODEGA      INT = NULL,
    @INSTALACION INT = NULL,
    @FILTRO      NVARCHAR(200) = NULL,
    @SOLO_ALERTA BIT = 0,
    @UBICACION   INT = NULL
AS
SET NOCOUNT ON

    ;WITH CUBO AS (
        SELECT  s.isa_cliente, s.isa_repuesto, s.isa_bodega,
                MIN(s.isa_id)                   AS isa_id,
                SUM(s.isa_cantidad)             AS isa_cantidad,
                SUM(ISNULL(s.isa_cantidad_reservada, 0)) AS isa_cantidad_reservada,
                /* Promedio ponderado por lo que hay en cada cubo: promediar
                   los promedios daria el mismo peso a un estante con 300
                   litros que a uno con 2. */
                CASE WHEN SUM(CASE WHEN s.isa_costo_promedio IS NOT NULL
                                   THEN s.isa_cantidad ELSE 0 END) = 0 THEN NULL
                     ELSE SUM(s.isa_cantidad * ISNULL(s.isa_costo_promedio, 0))
                          / NULLIF(SUM(CASE WHEN s.isa_costo_promedio IS NOT NULL
                                            THEN s.isa_cantidad ELSE 0 END), 0)
                END                             AS isa_costo_promedio,
                MAX(s.isa_fecha_ultimo_movimiento) AS isa_fecha_ultimo_movimiento,
                COUNT(CASE WHEN s.isa_cantidad <> 0 THEN 1 END) AS UBICACIONES,
                /* Si esta en una sola, cual. Si esta repartido, NULL. */
                CASE WHEN COUNT(CASE WHEN s.isa_cantidad <> 0 THEN 1 END) = 1
                     THEN MAX(CASE WHEN s.isa_cantidad <> 0
                                   THEN s.isa_bodega_ubicacion END)
                END                             AS UBICACION_UNICA,
                COUNT(DISTINCT s.isa_repuesto_lote) AS LOTES
        FROM    [dbo].[Inventario_Saldo] s
        WHERE   s.isa_cliente = @CLIENTE
          AND   (@UBICACION IS NULL OR s.isa_bodega_ubicacion = @UBICACION)
        GROUP BY s.isa_cliente, s.isa_repuesto, s.isa_bodega
    )
    SELECT  c.isa_id, c.isa_repuesto, c.isa_bodega,
            c.isa_cantidad, c.isa_cantidad_reservada,
            (c.isa_cantidad - ISNULL(c.isa_cantidad_reservada, 0)) AS CANTIDAD_DISPONIBLE,
            c.isa_costo_promedio, c.isa_fecha_ultimo_movimiento,
            r.rep_codigo AS REPUESTO_CODIGO, r.rep_nombre AS REPUESTO_NOMBRE,
            r.rep_controla_lote,
            ume.ume_simbolo AS UNIDAD_SIMBOLO,
            b.bod_codigo AS BODEGA_CODIGO, b.bod_nombre AS BODEGA_NOMBRE,
            cin.cin_nombre AS PLANTA_NOMBRE,
            st.rbs_stock_minimo, st.rbs_stock_maximo, st.rbs_punto_reposicion,

            /* La alerta se calcula sobre el TOTAL de la bodega, que es donde
               esta definido el umbral. */
            CASE WHEN st.rbs_stock_minimo IS NOT NULL
                  AND c.isa_cantidad < st.rbs_stock_minimo THEN 1 ELSE 0 END AS BAJO_MINIMO,
            CASE WHEN st.rbs_stock_maximo IS NOT NULL
                  AND c.isa_cantidad > st.rbs_stock_maximo THEN 1 ELSE 0 END AS SOBRE_MAXIMO,

            c.UBICACIONES,
            c.LOTES,
            u.bub_codigo AS UBICACION_CODIGO,
            u.bub_nombre AS UBICACION_NOMBRE
    FROM    CUBO c
    JOIN    [dbo].[Repuesto] r        ON r.rep_id  = c.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    JOIN    [dbo].[Bodega] b          ON b.bod_id  = c.isa_bodega
    JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = b.bod_cliente_instalacion
    LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = c.UBICACION_UNICA
    LEFT JOIN [dbo].[Repuesto_Bodega_Stock] st
           ON st.rbs_repuesto = c.isa_repuesto
          AND st.rbs_bodega   = c.isa_bodega
          AND st.rbs_habilitado = 1
    WHERE   (@REPUESTO IS NULL OR c.isa_repuesto = @REPUESTO)
      AND   (@BODEGA IS NULL OR c.isa_bodega = @BODEGA)
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
      AND   (@FILTRO IS NULL OR r.rep_codigo LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre LIKE '%' + @FILTRO + '%'
                             OR b.bod_nombre LIKE '%' + @FILTRO + '%')
      AND   (@SOLO_ALERTA = 0
             OR (st.rbs_stock_minimo IS NOT NULL AND c.isa_cantidad < st.rbs_stock_minimo)
             OR (st.rbs_stock_maximo IS NOT NULL AND c.isa_cantidad > st.rbs_stock_maximo))
    ORDER BY r.rep_codigo, b.bod_codigo
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
PRINT '--- Una fila por repuesto y bodega ---'
EXEC [dbo].[SEL_INVENTARIO_SALDO] @CLIENTE = 1
GO
