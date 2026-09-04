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

USE [db_acd593_sigma]
GO

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
DECLARE @REPUESTO INT, @BODEGA INT, @ZONA VARCHAR(100)

/* Las fechas de Inventario_Movimiento se guardan en UTC. El drawer las
   muestra en la zona del cliente, no en la zona del servidor SQL. El bloque
   128 garantiza que la zona configurada exista en sys.time_zone_info. */
SELECT @ZONA = ISNULL(p.pai_zona_horaria, 'UTC')
FROM   [dbo].[Cliente] c
LEFT JOIN [dbo].[PAISES] p ON p.pai_id = c.cli_pais
WHERE  c.cli_id = @CLIENTE

SET @ZONA = ISNULL(@ZONA, 'UTC')

/* ========================================================================
   EXISTENCIA   (@ID = isa_id)
   ======================================================================== */
IF (@ENTIDAD = 'EXISTENCIA')
BEGIN
    SELECT  @REPUESTO = s.isa_repuesto,
            @BODEGA   = s.isa_bodega
    FROM    [dbo].[Inventario_Saldo] s
    WHERE   s.isa_id = @ID AND s.isa_cliente = @CLIENTE

    /* La fila del listado es el TOTAL (repuesto, bodega), pero isa_id
       identifica solo uno de sus cubos (ubicacion, lote). El id sirve para
       resolver la pareja; desde ahi todos los importes se vuelven a sumar.
       Mostrar el cubo cuyo id era MIN hacia que el drawer contradijera a la
       grilla cuando el repuesto estaba repartido en dos estantes. */
    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Dónde está' AS SECCION, 'Bodega' AS ETIQUETA,
               ISNULL(b.bod_nombre, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Bodega] b
         WHERE b.bod_id = @BODEGA AND b.bod_cliente = @CLIENTE

        UNION ALL SELECT 'Dónde está', 'Ubicación',
               CASE WHEN COUNT(CASE WHEN s.isa_cantidad <> 0 THEN 1 END) = 0
                         THEN 'Sin ubicación registrada'
                    WHEN COUNT(CASE WHEN s.isa_cantidad <> 0 THEN 1 END) = 1
                         THEN ISNULL(MAX(CASE WHEN s.isa_cantidad <> 0
                                              THEN u.bub_codigo + ISNULL(' · ' + u.bub_nombre, '') END),
                                     'Sin ubicación registrada')
                    ELSE CAST(COUNT(CASE WHEN s.isa_cantidad <> 0 THEN 1 END) AS VARCHAR(10)) +
                         ' ubicaciones' END, 2
          FROM [dbo].[Inventario_Saldo] s
          LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = s.isa_bodega_ubicacion
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA

        UNION ALL SELECT 'Dónde está', 'Planta', ISNULL(ci.cin_nombre, ''), 3
          FROM [dbo].[Bodega] b
          LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
         WHERE b.bod_id = @BODEGA AND b.bod_cliente = @CLIENTE

        /* ---- Qué repuesto es ---- */
        UNION ALL SELECT 'El repuesto', 'Código', ISNULL(r.rep_codigo, ''), 10
          FROM [dbo].[Repuesto] r
         WHERE r.rep_id = @REPUESTO AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'El repuesto', 'Nombre', ISNULL(r.rep_nombre, ''), 11
          FROM [dbo].[Repuesto] r
         WHERE r.rep_id = @REPUESTO AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'El repuesto', 'Unidad de medida', ISNULL(um.ume_nombre, ''), 12
          FROM [dbo].[Repuesto] r
          LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
         WHERE r.rep_id = @REPUESTO AND r.rep_cliente = @CLIENTE

        /* ---- Cuánto hay ----
           Disponible = lo que hay menos lo comprometido. Es el numero con el
           que se decide si alcanza, y no coincide con la existencia cuando
           hay reservas: mostrar solo la existencia haria prometer piezas que
           ya tienen dueño. */
        UNION ALL SELECT 'Cuánto hay', 'Existencia',
               CAST(CAST(SUM(s.isa_cantidad) AS DECIMAL(18,2)) AS VARCHAR(30)), 20
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA

        UNION ALL SELECT 'Cuánto hay', 'Reservado',
               CASE WHEN SUM(ISNULL(s.isa_cantidad_reservada, 0)) > 0
                    THEN CAST(CAST(SUM(ISNULL(s.isa_cantidad_reservada, 0)) AS DECIMAL(18,2)) AS VARCHAR(30))
                    ELSE '' END, 21
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA

        UNION ALL SELECT 'Cuánto hay', 'Disponible',
               CAST(CAST(SUM(s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0)) AS DECIMAL(18,2)) AS VARCHAR(30)), 22
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA

        UNION ALL SELECT 'Cuánto hay', 'Mínimo / Máximo',
               CASE WHEN rbs.rbs_id IS NULL THEN ''
                    ELSE CAST(CAST(rbs.rbs_stock_minimo AS DECIMAL(18,2)) AS VARCHAR(30)) + ' / ' +
                         CASE WHEN rbs.rbs_stock_maximo IS NULL THEN 'sin máximo'
                              ELSE CAST(CAST(rbs.rbs_stock_maximo AS DECIMAL(18,2)) AS VARCHAR(30)) END END, 23
          FROM [dbo].[Repuesto_Bodega_Stock] rbs
         WHERE rbs.rbs_cliente = @CLIENTE AND rbs.rbs_repuesto = @REPUESTO
           AND rbs.rbs_bodega = @BODEGA AND rbs.rbs_habilitado = 1

        UNION ALL SELECT 'Cuánto hay', 'Costo promedio',
               CASE WHEN SUM(CASE WHEN s.isa_costo_promedio IS NOT NULL
                                   THEN s.isa_cantidad ELSE 0 END) = 0 THEN ''
                    ELSE CAST(CAST(
                         SUM(s.isa_cantidad * ISNULL(s.isa_costo_promedio, 0)) /
                         NULLIF(SUM(CASE WHEN s.isa_costo_promedio IS NOT NULL
                                          THEN s.isa_cantidad ELSE 0 END), 0)
                         AS DECIMAL(18,0)) AS VARCHAR(30)) END, 24
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA

        UNION ALL SELECT 'Cuánto hay', 'Último movimiento',
               ISNULL(CONVERT(VARCHAR(16),
                      CONVERT(DATETIME, MAX(s.isa_fecha_ultimo_movimiento)
                              AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 105) + ' ' +
                      CONVERT(VARCHAR(5),
                      CONVERT(DATETIME, MAX(s.isa_fecha_ultimo_movimiento)
                              AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 108), ''), 25
          FROM [dbo].[Inventario_Saldo] s
         WHERE s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
           AND s.isa_bodega = @BODEGA
    ) x
    WHERE ISNULL(x.VALOR COLLATE DATABASE_DEFAULT, '') <> ''
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
               ISNULL(' ' + um.ume_nombre, ''), 2
          FROM [dbo].[Inventario_Movimiento] m
          LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
          LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
         WHERE m.imo_id = @ID AND m.imo_cliente = @CLIENTE

        UNION ALL SELECT 'Qué pasó', 'Cuándo',
               CONVERT(VARCHAR(16),
                       CONVERT(DATETIME, m.imo_fecha_movimiento_utc
                               AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 105) + ' ' +
               CONVERT(VARCHAR(5),
                       CONVERT(DATETIME, m.imo_fecha_movimiento_utc
                               AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 108), 3
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
               ISNULL(CAST(ot.otr_correlativo AS VARCHAR(30)) +
                      ISNULL(' · ' + ot.otr_titulo, ''), ''), 30
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
    WHERE ISNULL(x.VALOR COLLATE DATABASE_DEFAULT, '') <> ''
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
        CONVERT(VARCHAR(10),
                CONVERT(DATETIME, m.imo_fecha_movimiento_utc
                        AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 105) AS FECHA,
        CONVERT(VARCHAR(5),
                CONVERT(DATETIME, m.imo_fecha_movimiento_utc
                        AT TIME ZONE 'UTC' AT TIME ZONE @ZONA), 108) AS HORA,
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
        ISNULL(' ' + um.ume_nombre, '') AS CANTIDAD,

        ISNULL(u.usu_nombre + ' ' + u.usu_apellido_paterno, '') AS USUARIO,
        ISNULL(u.usu_id, 0) AS USUARIO_ID,
        ISNULL(u.usu_archivo_foto, 0) AS USUARIO_FOTO,

        ISNULL(m.imo_observacion, '') AS MOTIVO,
        ISNULL(CAST(ot.otr_correlativo AS VARCHAR(30)), '') AS ORDEN_TRABAJO,
        ISNULL(ub.bub_codigo, '') AS UBICACION,

        /* Cual de todos es el que se esta mirando, cuando la entidad es un
           movimiento. Sin esto, el panel muestra ocho hechos iguales y el
           propio se pierde entre ellos. */
        CAST(CASE WHEN @ENTIDAD = 'MOVIMIENTO' AND m.imo_id = @ID THEN 1 ELSE 0 END AS BIT) AS ES_ESTE
FROM    [dbo].[Inventario_Movimiento] m
LEFT JOIN [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
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
