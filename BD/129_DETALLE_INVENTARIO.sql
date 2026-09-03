/* ============================================================================
   SIGMA - Bloque 129
   EL PANEL LATERAL DE EXISTENCIAS Y MOVIMIENTOS
   ----------------------------------------------------------------------------

   QUE AGREGA

     Dos entidades nuevas a SEL_DETALLE_FICHA -EXISTENCIA y MOVIMIENTO- y, lo
     importante, un SEGUNDO RESULTADO con los ultimos movimientos.

   POR QUE UN SEGUNDO RESULTADO Y NO MAS PARES ETIQUETA/VALOR

     El primer resultado responde "que es esto y donde esta": son datos
     sueltos, cada uno con su rotulo. Los movimientos son otra cosa: una
     secuencia de hechos, cada uno con fecha, cantidad, responsable y motivo.
     Aplanarlos a pares daria "Movimiento 1 - fecha", "Movimiento 1 - quien",
     "Movimiento 2 - fecha"... y el panel tendria que volver a armarlos para
     poder dibujarlos como lo que son.

     Van aparte, con una fila por movimiento, y el panel los dibuja como una
     linea de tiempo.

   LA CANTIDAD LLEVA SIGNO

     `imo_cantidad` es siempre positiva: lo que dice si suma o resta es el
     TIPO. Un panel que muestre "5" sin saber el tipo no dice nada -pudo
     entrar o salir-. Aca sale ya resuelto en SENTIDO: ENTRADA, SALIDA o
     NEUTRO, y el panel solo se ocupa de pintarlo.

     REUBICACION es NEUTRO a proposito: la pieza no entro ni salio de la
     bodega, se cambio de estante. Contarlo como entrada o salida haria que
     los numeros no cuadraran con el saldo.

   EL SALDO SI ESTA GUARDADO

     `Inventario_Saldo.isa_cantidad` es el stock actual. `Repuesto_Bodega_Stock`
     guarda minimos y maximos, que es otra cosa: es el rango deseado, no lo que
     hay. Confundirlos mostraria un maximo donde deberia ir una existencia.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_DETALLE_INVENTARIO]
    @ENTIDAD    VARCHAR(40),
    @ID         INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

DECLARE @R TABLE (SECCION NVARCHAR(60), ETIQUETA NVARCHAR(80),
                  VALOR NVARCHAR(400), ORDEN INT)

/* De que repuesto y de que bodega hay que traer los movimientos. Se resuelve
   una sola vez y sirve para las dos entidades. */
DECLARE @REPUESTO INT, @BODEGA INT

/* ========================================================================
   EXISTENCIA   (@ID = isa_id)
   ======================================================================== */
IF (@ENTIDAD = 'EXISTENCIA')
BEGIN
    SELECT  @REPUESTO = s.isa_repuesto,
            @BODEGA   = s.isa_bodega
    FROM    [dbo].[Inventario_Saldo] s
    WHERE   s.isa_id = @ID AND s.isa_cliente = @CLIENTE

    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Dónde está' AS SECCION, 'Bodega' AS ETIQUETA,
               ISNULL(b.bod_nombre, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Inventario_Saldo] s
          LEFT JOIN [dbo].[Bodega] b ON b.bod_id = s.isa_bodega
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Dónde está', 'Ubicación',
               ISNULL(u.bub_codigo + ISNULL(' · ' + u.bub_nombre, ''), ''), 2
          FROM [dbo].[Inventario_Saldo] s
          LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = s.isa_bodega_ubicacion
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Dónde está', 'Planta',
               ISNULL(ci.cin_nombre, ''), 3
          FROM [dbo].[Inventario_Saldo] s
          LEFT JOIN [dbo].[Bodega] b ON b.bod_id = s.isa_bodega
          LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        /* ---- Qué repuesto es ---- */
        UNION ALL SELECT 'El repuesto', 'Código', ISNULL(r.rep_codigo, ''), 10
          FROM [dbo].[Inventario_Saldo] s
          JOIN [dbo].[Repuesto] r ON r.rep_id = s.isa_repuesto
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'El repuesto', 'Nombre', ISNULL(r.rep_nombre, ''), 11
          FROM [dbo].[Inventario_Saldo] s
          JOIN [dbo].[Repuesto] r ON r.rep_id = s.isa_repuesto
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'El repuesto', 'Unidad de medida', ISNULL(um.uni_nombre, ''), 12
          FROM [dbo].[Inventario_Saldo] s
          JOIN [dbo].[Repuesto] r ON r.rep_id = s.isa_repuesto
          LEFT JOIN [dbo].[Unidad_Medida] um ON um.uni_id = r.rep_unidad_medida
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        /* ---- Cuánto hay ----
           Disponible = lo que hay menos lo comprometido. Es el numero con el
           que se decide si alcanza, y no coincide con la existencia cuando
           hay reservas: mostrar solo la existencia haria prometer piezas que
           ya tienen dueño. */
        UNION ALL SELECT 'Cuánto hay', 'Existencia',
               CAST(CAST(s.isa_cantidad AS DECIMAL(18,2)) AS VARCHAR(30)), 20
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Cuánto hay', 'Reservado',
               CASE WHEN ISNULL(s.isa_cantidad_reservada, 0) > 0
                    THEN CAST(CAST(s.isa_cantidad_reservada AS DECIMAL(18,2)) AS VARCHAR(30))
                    ELSE '' END, 21
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Cuánto hay', 'Disponible',
               CAST(CAST(s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0) AS DECIMAL(18,2)) AS VARCHAR(30)), 22
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Cuánto hay', 'Mínimo / Máximo',
               CASE WHEN rbs.rbs_id IS NULL THEN ''
                    ELSE CAST(CAST(ISNULL(rbs.rbs_stock_minimo, 0) AS DECIMAL(18,2)) AS VARCHAR(30)) + ' / ' +
                         CAST(CAST(ISNULL(rbs.rbs_stock_maximo, 0) AS DECIMAL(18,2)) AS VARCHAR(30)) END, 23
          FROM [dbo].[Inventario_Saldo] s
          LEFT JOIN [dbo].[Repuesto_Bodega_Stock] rbs
                 ON rbs.rbs_repuesto = s.isa_repuesto AND rbs.rbs_bodega = s.isa_bodega
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Cuánto hay', 'Costo promedio',
               CASE WHEN ISNULL(s.isa_costo_promedio, 0) > 0
                    THEN CAST(CAST(s.isa_costo_promedio AS DECIMAL(18,0)) AS VARCHAR(30))
                    ELSE '' END, 24
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE

        UNION ALL SELECT 'Cuánto hay', 'Último movimiento',
               ISNULL(CONVERT(VARCHAR(16), s.isa_fecha_ultimo_movimiento, 105) + ' ' +
                      CONVERT(VARCHAR(5), s.isa_fecha_ultimo_movimiento, 108), ''), 25
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_id = @ID AND s.isa_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> ''
END

/* ========================================================================
   MOVIMIENTO   (@ID = imo_id)
   ======================================================================== */
IF (@ENTIDAD = 'MOVIMIENTO')
BEGIN
    SELECT  @REPUESTO = m.imo_repuesto,
            @BODEGA   = m.imo_bodega
    FROM    [dbo].[Inventario_Movimiento] m
    WHERE   m.imo_id = @ID AND m.imo_cliente = @CLIENTE

    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Qué pasó' AS SECCION, 'Tipo' AS ETIQUETA,
               ISNULL(t.imt_nombre, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Qué pasó', 'Cantidad',
               CAST(CAST(m.imo_cantidad AS DECIMAL(18,2)) AS VARCHAR(30)) +
               ISNULL(' ' + um.uni_nombre, ''), 2
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
          LEFT JOIN [dbo].[Unidad_Medida] um ON um.uni_id = r.rep_unidad_medida
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Qué pasó', 'Cuándo',
               CONVERT(VARCHAR(16), m.imo_fecha_movimiento_utc, 105) + ' ' +
               CONVERT(VARCHAR(5), m.imo_fecha_movimiento_utc, 108), 3
          FROM [dbo].[Inventario_Movimiento] m
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Qué pasó', 'Quién lo registró',
               ISNULL(u.usu_nombre + ' ' + u.usu_apellido_paterno, ''), 4
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Usuario] u ON u.usu_id = m.imo_usuario_creacion
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Qué pasó', 'Motivo',
               ISNULL(m.imo_observacion, ''), 5
          FROM [dbo].[Inventario_Movimiento] m
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        /* ---- El repuesto ---- */
        UNION ALL SELECT 'El repuesto', 'Código', ISNULL(r.rep_codigo, ''), 10
          FROM [dbo].[Inventario_Movimiento] m
          JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'El repuesto', 'Nombre', ISNULL(r.rep_nombre, ''), 11
          FROM [dbo].[Inventario_Movimiento] m
          JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        /* ---- De dónde a dónde ----
           El destino solo aparece en traslados y reubicaciones. En un consumo
           no existe, y una etiqueta "Destino: vacío" haria pensar que falta un
           dato en vez de que no corresponde. */
        UNION ALL SELECT 'De dónde a dónde', 'Bodega', ISNULL(b.bod_nombre, ''), 20
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'De dónde a dónde', 'Ubicación',
               ISNULL(u1.bub_codigo + ISNULL(' · ' + u1.bub_nombre, ''), ''), 21
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Bodega_Ubicacion] u1 ON u1.bub_id = m.imo_bodega_ubicacion
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'De dónde a dónde', 'Bodega de destino',
               ISNULL(bd.bod_nombre, ''), 22
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Bodega] bd ON bd.bod_id = m.imo_bodega_destino
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'De dónde a dónde', 'Ubicación de destino',
               ISNULL(u2.bub_codigo + ISNULL(' · ' + u2.bub_nombre, ''), ''), 23
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Bodega_Ubicacion] u2 ON u2.bub_id = m.imo_bodega_ubicacion_destino
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        /* ---- Contra qué se cargó ---- */
        UNION ALL SELECT 'Contra qué', 'Orden de trabajo',
               ISNULL(ot.otr_correlativo + ISNULL(' · ' + ot.otr_titulo, ''), ''), 30
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = m.imo_orden_trabajo
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Contra qué', 'Costo unitario',
               CASE WHEN ISNULL(m.imo_costo_unitario, 0) > 0
                    THEN CAST(CAST(m.imo_costo_unitario AS DECIMAL(18,0)) AS VARCHAR(30)) +
                         ISNULL(' ' + mo.mon_nombre, '')
                    ELSE '' END, 31
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Moneda] mo ON mo.mon_id = m.imo_moneda
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> ''
END

/* ---------------------------------------------------------- primer resultado */
SELECT SECCION, ETIQUETA, VALOR, ORDEN FROM @R ORDER BY ORDEN

/* ========================================================================
   SEGUNDO RESULTADO: LOS ULTIMOS MOVIMIENTOS

   Ocho. Con tres no se ve un patron -si esta saliendo mas de lo que entra- y
   con treinta el panel deja de ser un vistazo y pasa a ser otra pantalla, que
   es justo la que ya existe.

   Se filtra por repuesto Y bodega: los movimientos del mismo repuesto en otra
   bodega no explican el saldo que se esta mirando.
   ======================================================================== */
IF @REPUESTO IS NULL
BEGIN
    /* Sin repuesto resuelto no hay historial que mostrar, pero el segundo
       resultado tiene que existir igual: el consumidor lee dos resultados
       siempre, y devolver uno solo lo haria fallar. */
    SELECT TOP 0
           CAST(NULL AS VARCHAR(20))  AS FECHA,
           CAST(NULL AS VARCHAR(10))  AS HORA,
           CAST(NULL AS NVARCHAR(80)) AS TIPO,
           CAST(NULL AS VARCHAR(10))  AS SENTIDO,
           CAST(NULL AS VARCHAR(30))  AS CANTIDAD,
           CAST(NULL AS NVARCHAR(200)) AS USUARIO,
           CAST(NULL AS INT)          AS USUARIO_ID,
           CAST(NULL AS INT)          AS USUARIO_FOTO,
           CAST(NULL AS NVARCHAR(500)) AS MOTIVO,
           CAST(NULL AS NVARCHAR(200)) AS ORDEN_TRABAJO,
           CAST(NULL AS NVARCHAR(200)) AS UBICACION,
           CAST(NULL AS BIT)          AS ES_ESTE
    RETURN
END

SELECT TOP 8
        CONVERT(VARCHAR(10), m.imo_fecha_movimiento_utc, 105) AS FECHA,
        CONVERT(VARCHAR(5),  m.imo_fecha_movimiento_utc, 108) AS HORA,
        ISNULL(t.imt_nombre, '') AS TIPO,

        /* El signo sale del TIPO, no de la cantidad: `imo_cantidad` siempre es
           positiva. REUBICACION queda NEUTRO porque la pieza no entro ni
           salio, solo cambio de estante. */
        CASE WHEN t.imt_codigo IN ('INGRESO COMPRA', 'DEVOLUCION', 'AJUSTE POSITIVO', 'TRASLADO INGRESO')
                  THEN 'ENTRADA'
             WHEN t.imt_codigo IN ('SALIDA CONSUMO', 'AJUSTE NEGATIVO', 'TRASLADO SALIDA', 'MERMA')
                  THEN 'SALIDA'
             ELSE 'NEUTRO' END AS SENTIDO,

        CAST(CAST(m.imo_cantidad AS DECIMAL(18,2)) AS VARCHAR(30)) +
        ISNULL(' ' + um.uni_nombre, '') AS CANTIDAD,

        ISNULL(u.usu_nombre + ' ' + u.usu_apellido_paterno, '') AS USUARIO,
        ISNULL(u.usu_id, 0) AS USUARIO_ID,
        ISNULL(u.usu_archivo_foto, 0) AS USUARIO_FOTO,

        ISNULL(m.imo_observacion, '') AS MOTIVO,
        ISNULL(ot.otr_correlativo, '') AS ORDEN_TRABAJO,
        ISNULL(ub.bub_codigo, '') AS UBICACION,

        /* Cual de todos es el que se esta mirando, cuando la entidad es un
           movimiento. Sin esto, el panel muestra ocho hechos iguales y el
           propio se pierde entre ellos. */
        CAST(CASE WHEN @ENTIDAD = 'MOVIMIENTO' AND m.imo_id = @ID THEN 1 ELSE 0 END AS BIT) AS ES_ESTE
FROM    [dbo].[Inventario_Movimiento] m
LEFT JOIN [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
LEFT JOIN [dbo].[Unidad_Medida] um ON um.uni_id = r.rep_unidad_medida
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = m.imo_usuario_creacion
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = m.imo_orden_trabajo
LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = m.imo_bodega_ubicacion
WHERE   m.imo_cliente = @CLIENTE
  AND   m.imo_repuesto = @REPUESTO
  AND  (@BODEGA IS NULL OR m.imo_bodega = @BODEGA)
ORDER BY m.imo_fecha_movimiento_utc DESC, m.imo_id DESC
GO

PRINT '--- SEL_DETALLE_INVENTARIO creado.'
GO

/* --------------------------------------------------------------- comprobacion */
DECLARE @SALDO INT, @MOV INT
SELECT TOP 1 @SALDO = isa_id FROM [dbo].[Inventario_Saldo] WHERE isa_cliente = 1
SELECT TOP 1 @MOV = imo_id FROM [dbo].[Inventario_Movimiento] WHERE imo_cliente = 1 ORDER BY imo_id DESC

EXEC [dbo].[SEL_DETALLE_INVENTARIO] @ENTIDAD = 'EXISTENCIA', @ID = @SALDO, @CLIENTE = 1
EXEC [dbo].[SEL_DETALLE_INVENTARIO] @ENTIDAD = 'MOVIMIENTO', @ID = @MOV,   @CLIENTE = 1
GO

PRINT '129_DETALLE_INVENTARIO aplicado.'
GO
