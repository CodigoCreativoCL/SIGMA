/* ============================================================================
   SIGMA — Bloque 71
   EL SALDO PASA A LLEVARSE POR UBICACION Y POR LOTE
   ----------------------------------------------------------------------------

   HASTA AHORA

     Inventario_Saldo tenia la llave (cliente, repuesto, bodega). La ubicacion
     existia solo en el movimiento: era "donde se dejo la ultima vez", no
     "donde esta". Con un repuesto en dos estantes, el sistema no sabia
     cuanto habia en cada uno.

     Eso alcanza mientras nadie le pregunte a un estante que tiene adentro.
     En cuanto se imprime una etiqueta con codigo de ubicacion y se escanea
     para ver el desglose, la respuesta tendria que inventarse un numero: la
     cantidad de la BODEGA mostrada como si fuera la del estante.

     Una pantalla que muestra un numero que no es el numero es peor que no
     tener la pantalla.

   AHORA

     La llave es (cliente, repuesto, bodega, ubicacion). Cada ubicacion sabe
     lo que tiene. El total de la bodega es la suma, y se sigue pudiendo
     preguntar por bodega sin saber nada de ubicaciones.

   LA UBICACION NULA NO ES UN HUECO

     Es un cubo legitimo: "en esta bodega, sin ubicacion asignada". Las
     bodegas sin estanteria definida operan enteras ahi, y los movimientos
     que ya existen migran ahi sin perder nada. El indice unico trata los
     NULL como iguales, asi que hay exactamente un cubo nulo por bodega y
     repuesto, que es justo lo que se quiere.

   LO QUE FALTABA PARA QUE LA UBICACION SIRVA

     No habia forma de decir "esto se movio del estante A al estante B".
     Traslado (tipo 6) es entre BODEGAS. Cambiar de estante dentro de la
     misma bodega no tenia representacion, asi que la unica manera de
     corregir una ubicacion era una salida y una entrada, que ensucia el
     historial con movimientos que nunca ocurrieron.

     Se agrega el tipo 9, REUBICACION, y la columna de ubicacion destino.

   EL LOTE ENTRA EN LA MISMA LLAVE, Y NO EN UNA MIGRACION APARTE

     Repuesto_Lote no tiene columna de cantidad: en ninguna parte estaba
     escrito cuantas unidades vinieron en un lote. Se podia deducir sumando
     el libro, pero nadie lo estaba sumando, asi que la pregunta "cuanto me
     queda de este lote" no tenia respuesta en pantalla.

     Se resuelve aca y no despues porque el saldo se reconstruye una sola
     vez: agregar el lote en una segunda migracion obligaria a vaciar y
     rehacer la tabla otra vez, con el riesgo que eso trae, para llegar al
     mismo lugar.

     La llave final es (cliente, repuesto, bodega, ubicacion, lote). El lote
     nulo es un cubo legitimo igual que la ubicacion nula: los repuestos que
     no controlan lote viven ahi.

   LA TRAZABILIDAD YA ESTABA, PERO NO SE PODIA LEER

     Cada movimiento guarda ubicacion, fecha y usuario desde siempre. Lo que
     no habia era la pregunta hecha: "por que ubicaciones paso este
     repuesto". SEL_REPUESTO_UBICACION_HISTORIAL la hace.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LAS COLUMNAS NUEVAS
   ======================================================================== */
IF COL_LENGTH('dbo.Inventario_Saldo', 'isa_bodega_ubicacion') IS NULL
BEGIN
    ALTER TABLE [dbo].[Inventario_Saldo] ADD [isa_bodega_ubicacion] INT NULL
    PRINT '--- Inventario_Saldo.isa_bodega_ubicacion agregada'
END
ELSE PRINT '--- Inventario_Saldo.isa_bodega_ubicacion ya existia'
GO

IF COL_LENGTH('dbo.Inventario_Saldo', 'isa_repuesto_lote') IS NULL
BEGIN
    ALTER TABLE [dbo].[Inventario_Saldo] ADD [isa_repuesto_lote] INT NULL
    PRINT '--- Inventario_Saldo.isa_repuesto_lote agregada'
END
ELSE PRINT '--- Inventario_Saldo.isa_repuesto_lote ya existia'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Inventario_Saldo_Repuesto_Lote')
    ALTER TABLE [dbo].[Inventario_Saldo] WITH CHECK
        ADD CONSTRAINT [FK_Inventario_Saldo_Repuesto_Lote]
        FOREIGN KEY ([isa_repuesto_lote]) REFERENCES [dbo].[Repuesto_Lote]([rlo_id])
GO

IF COL_LENGTH('dbo.Inventario_Movimiento', 'imo_bodega_ubicacion_destino') IS NULL
BEGIN
    ALTER TABLE [dbo].[Inventario_Movimiento] ADD [imo_bodega_ubicacion_destino] INT NULL
    PRINT '--- Inventario_Movimiento.imo_bodega_ubicacion_destino agregada'
END
ELSE PRINT '--- Inventario_Movimiento.imo_bodega_ubicacion_destino ya existia'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Inventario_Saldo_Bodega_Ubicacion')
    ALTER TABLE [dbo].[Inventario_Saldo] WITH CHECK
        ADD CONSTRAINT [FK_Inventario_Saldo_Bodega_Ubicacion]
        FOREIGN KEY ([isa_bodega_ubicacion]) REFERENCES [dbo].[Bodega_Ubicacion]([bub_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Inventario_Movimiento_Ubicacion_Destino')
    ALTER TABLE [dbo].[Inventario_Movimiento] WITH CHECK
        ADD CONSTRAINT [FK_Inventario_Movimiento_Ubicacion_Destino]
        FOREIGN KEY ([imo_bodega_ubicacion_destino]) REFERENCES [dbo].[Bodega_Ubicacion]([bub_id])
GO


/* ========================================================================
   2. EL TIPO 9: REUBICACION

      Se distingue de un traslado en que no cambia de bodega, y del resto en
      que el saldo de la bodega no se mueve: solo cambia de estante. Por eso
      no entra en la tabla de signos.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE imt_id = 9)
BEGIN
    SET IDENTITY_INSERT [dbo].[Inventario_Movimiento_Tipo] ON

    INSERT INTO [dbo].[Inventario_Movimiento_Tipo]
        (imt_id, imt_codigo, imt_nombre, imt_habilitado)
    VALUES (9, 'REUBICACION', 'Cambio de ubicación', 1)

    SET IDENTITY_INSERT [dbo].[Inventario_Movimiento_Tipo] OFF
    PRINT '--- Tipo 9 REUBICACION creado'
END
ELSE PRINT '--- Tipo 9 REUBICACION ya existia'
GO


/* ========================================================================
   3. RECALCULAR EL SALDO REPRODUCIENDO EL LIBRO EN ORDEN

      NO SIRVE AGRUPAR Y SUMAR

        El primer intento agrupaba los movimientos por (repuesto, bodega,
        ubicacion, lote) y sumaba. Reviento contra CK_ISA_CANTIDAD, y con
        razon: las ENTRADAS traen ubicacion y las SALIDAS no. Agrupando, las
        entradas caian en el cubo del estante y las salidas en el cubo nulo,
        que quedaba en negativo mientras el estante conservaba todo.

        El total por bodega daba bien. Cada cubo daba mal. Es exactamente el
        error que se quiere dejar de cometer: un total correcto compuesto de
        partes falsas.

      SE REPRODUCE EL LIBRO

        Los movimientos se recorren en orden cronologico. Una entrada suma
        al cubo que indica. Una salida que dice de donde sale, descuenta de
        ahi. Una salida que NO lo dice -que es como se registro hasta hoy-
        se descuenta FIFO: del cubo que recibio primero.

        FIFO y no "el que mas tiene" porque es el criterio de cualquier
        bodega con material que vence, y porque es reproducible: dos
        ejecuciones de esta migracion dan el mismo resultado.

      NO SE REESCRIBE EL LIBRO

        Seria facil rellenar imo_bodega_ubicacion en las salidas viejas con
        el cubo que FIFO eligio, y la trazabilidad por ubicacion se veria
        completa. Seria mentira: nadie registro esa ubicacion, la elegimos
        nosotros ahora. El libro queda como esta y la asignacion vive solo
        en el saldo.

        Hacia adelante el problema no se repite: el SP exige la ubicacion.
   ======================================================================== */
IF OBJECT_ID('tempdb..#ANTES') IS NOT NULL DROP TABLE #ANTES
IF OBJECT_ID('tempdb..#MOV')   IS NOT NULL DROP TABLE #MOV
IF OBJECT_ID('tempdb..#S')     IS NOT NULL DROP TABLE #S

SELECT isa_repuesto, isa_bodega, SUM(isa_cantidad) AS CANTIDAD
INTO   #ANTES
FROM   [dbo].[Inventario_Saldo]
GROUP BY isa_repuesto, isa_bodega

/* El libro, numerado en orden. */
SELECT  ROW_NUMBER() OVER (ORDER BY m.imo_fecha_movimiento_utc, m.imo_id) AS N,
        m.imo_id, m.imo_cliente, m.imo_repuesto, m.imo_bodega,
        m.imo_bodega_ubicacion, m.imo_bodega_ubicacion_destino,
        m.imo_repuesto_lote, m.imo_inventario_movimiento_tipo AS TIPO,
        m.imo_cantidad, m.imo_costo_unitario,
        m.imo_fecha_movimiento_utc, m.imo_usuario_creacion
INTO    #MOV
FROM    [dbo].[Inventario_Movimiento] m

/* Los cubos en construccion. ORDEN guarda cuando se lleno cada uno, que es
   lo que hace posible el FIFO. */
CREATE TABLE #S (
    CLIENTE INT, REPUESTO INT, BODEGA INT, UBI INT NULL, LOTE INT NULL,
    CANT DECIMAL(18,4), COSTO DECIMAL(18,4) NULL,
    ORDEN INT, FECHA DATETIME, USUARIO INT)
GO

BEGIN TRANSACTION

    DECLARE @IX NVARCHAR(200), @SQL NVARCHAR(MAX), @DESCUADRE INT, @NEGATIVOS INT
    DECLARE @N INT = 1, @TOTAL INT
    DECLARE @cli INT, @rep INT, @bod INT, @ubi INT, @ubid INT, @lot INT
    DECLARE @tipo INT, @cant DECIMAL(18,4), @costo DECIMAL(18,4)
    DECLARE @fec DATETIME, @usu INT, @resta DECIMAL(18,4), @tomar DECIMAL(18,4)
    DECLARE @cubo INT, @hay INT

    SELECT @TOTAL = COUNT(*) FROM #MOV

    WHILE (@N <= @TOTAL)
    BEGIN
        SELECT @cli = imo_cliente, @rep = imo_repuesto, @bod = imo_bodega,
               @ubi = imo_bodega_ubicacion, @ubid = imo_bodega_ubicacion_destino,
               @lot = imo_repuesto_lote, @tipo = TIPO, @cant = imo_cantidad,
               @costo = imo_costo_unitario, @fec = imo_fecha_movimiento_utc,
               @usu = imo_usuario_creacion
        FROM   #MOV WHERE N = @N

        IF (@tipo IN (1, 3, 4, 7))
        BEGIN
            /* ---- Entra: al cubo que indica ---- */
            IF EXISTS (SELECT 1 FROM #S
                        WHERE CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                          AND ISNULL(UBI, -1) = ISNULL(@ubi, -1)
                          AND ISNULL(LOTE, -1) = ISNULL(@lot, -1))
                UPDATE #S
                SET    CANT = CANT + @cant, FECHA = @fec, USUARIO = @usu,
                       COSTO = ISNULL(@costo, COSTO)
                WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                  AND  ISNULL(UBI, -1) = ISNULL(@ubi, -1)
                  AND  ISNULL(LOTE, -1) = ISNULL(@lot, -1)
            ELSE
                INSERT INTO #S VALUES (@cli, @rep, @bod, @ubi, @lot, @cant, @costo, @N, @fec, @usu)
        END
        ELSE IF (@tipo = 9)
        BEGIN
            /* ---- Cambia de estante: sale de uno y entra al otro ---- */
            UPDATE #S SET CANT = CANT - @cant, FECHA = @fec, USUARIO = @usu
            WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
              AND  ISNULL(UBI, -1) = ISNULL(@ubi, -1)
              AND  ISNULL(LOTE, -1) = ISNULL(@lot, -1)

            IF EXISTS (SELECT 1 FROM #S
                        WHERE CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                          AND ISNULL(UBI, -1) = ISNULL(@ubid, -1)
                          AND ISNULL(LOTE, -1) = ISNULL(@lot, -1))
                UPDATE #S SET CANT = CANT + @cant, FECHA = @fec, USUARIO = @usu
                WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                  AND  ISNULL(UBI, -1) = ISNULL(@ubid, -1)
                  AND  ISNULL(LOTE, -1) = ISNULL(@lot, -1)
            ELSE
                INSERT INTO #S VALUES (@cli, @rep, @bod, @ubid, @lot, @cant, NULL, @N, @fec, @usu)
        END
        ELSE
        BEGIN
            /* ---- Sale ---- */
            SET @resta = @cant

            /* Si el movimiento dice de donde sale, se respeta. */
            IF (@ubi IS NOT NULL)
            BEGIN
                UPDATE #S SET CANT = CANT - @resta, FECHA = @fec, USUARIO = @usu
                WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                  AND  ISNULL(UBI, -1) = ISNULL(@ubi, -1)
                  AND  ISNULL(LOTE, -1) = ISNULL(@lot, -1)

                SET @resta = 0
            END

            /* Si no lo dice, FIFO sobre los cubos con existencia. */
            WHILE (@resta > 0)
            BEGIN
                SET @cubo = NULL

                SELECT TOP 1 @cubo = ORDEN, @tomar = CANT
                FROM   #S
                WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                  AND  CANT > 0
                  AND  (@lot IS NULL OR ISNULL(LOTE, -1) = @lot)
                ORDER BY ORDEN

                IF (@cubo IS NULL)
                BEGIN
                    /* No queda de donde sacar. Se deja en el cubo nulo, en
                       negativo, y la comprobacion de abajo lo hace notar en
                       vez de dejarlo pasar. */
                    IF EXISTS (SELECT 1 FROM #S
                                WHERE CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                                  AND UBI IS NULL AND ISNULL(LOTE, -1) = ISNULL(@lot, -1))
                        UPDATE #S SET CANT = CANT - @resta
                        WHERE  CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod
                          AND  UBI IS NULL AND ISNULL(LOTE, -1) = ISNULL(@lot, -1)
                    ELSE
                        INSERT INTO #S VALUES (@cli, @rep, @bod, NULL, @lot, -@resta, NULL, @N, @fec, @usu)

                    SET @resta = 0
                END
                ELSE
                BEGIN
                    IF (@tomar >= @resta) SET @tomar = @resta

                    UPDATE #S SET CANT = CANT - @tomar, FECHA = @fec, USUARIO = @usu
                    WHERE  ORDEN = @cubo AND CLIENTE = @cli AND REPUESTO = @rep AND BODEGA = @bod

                    SET @resta = @resta - @tomar
                END
            END
        END

        SET @N = @N + 1
    END

    /* ---- Ningun cubo puede haber quedado negativo ---- */
    SELECT @NEGATIVOS = COUNT(*) FROM #S WHERE CANT < 0

    /* El indice unico viejo estorba: era por (repuesto, bodega). */
    SELECT @IX = i.name
    FROM   sys.indexes i
    WHERE  i.object_id = OBJECT_ID('dbo.Inventario_Saldo')
      AND  i.is_unique = 1 AND i.is_primary_key = 0

    IF @IX IS NOT NULL
    BEGIN
        SET @SQL = 'DROP INDEX [' + @IX + '] ON [dbo].[Inventario_Saldo]'
        EXEC sp_executesql @SQL
        PRINT '--- Indice unico viejo eliminado: ' + @IX
    END

    DELETE FROM [dbo].[Inventario_Saldo]

    INSERT INTO [dbo].[Inventario_Saldo]
        (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
         isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
         isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
    SELECT  CLIENTE, REPUESTO, BODEGA, UBI, LOTE, CANT, 0, COSTO, FECHA, USUARIO, GETDATE()
    FROM    #S
    WHERE   CANT <> 0

    /* ---- Los totales por bodega tienen que dar lo mismo que antes ---- */
    SELECT @DESCUADRE = COUNT(*)
    FROM   #ANTES a
    FULL JOIN (SELECT isa_repuesto, isa_bodega, SUM(isa_cantidad) AS CANTIDAD
               FROM   [dbo].[Inventario_Saldo]
               GROUP BY isa_repuesto, isa_bodega) d
           ON d.isa_repuesto = a.isa_repuesto AND d.isa_bodega = a.isa_bodega
    WHERE  ISNULL(a.CANTIDAD, 0) <> ISNULL(d.CANTIDAD, 0)

    IF (@DESCUADRE > 0 OR @NEGATIVOS > 0)
    BEGIN
        PRINT '*** DESCUADRE: ' + LTRIM(STR(@DESCUADRE)) + ' par(es) repuesto/bodega, '
            + LTRIM(STR(@NEGATIVOS)) + ' cubo(s) en negativo. SE DESHACE.'
        ROLLBACK TRANSACTION
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION
        PRINT '--- Saldo reconstruido por ubicacion y lote. Los totales por bodega cuadran.'
    END
GO

/* El indice unico nuevo. Los NULL cuentan como iguales entre si, asi que
   queda un solo cubo "sin ubicacion" por repuesto y bodega. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_ISA_CLI_REP_BOD_UBI_LOT'
                  AND object_id = OBJECT_ID('dbo.Inventario_Saldo'))
    CREATE UNIQUE INDEX [UX_ISA_CLI_REP_BOD_UBI_LOT]
        ON [dbo].[Inventario_Saldo] (isa_cliente, isa_repuesto, isa_bodega,
                                     isa_bodega_ubicacion, isa_repuesto_lote)
GO


/* ========================================================================
   4. POR DONDE PASO ESTE REPUESTO

      La pregunta de trazabilidad que pide el bodeguero: cada ubicacion por
      la que paso, cuando y quien lo movio. Sale del libro, no de una tabla
      nueva: el libro ya lo sabia.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_UBICACION_HISTORIAL') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_REPUESTO_UBICACION_HISTORIAL]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_UBICACION_HISTORIAL]
    @CLIENTE   INT,
    @REPUESTO  INT,
    @BODEGA    INT = NULL,
    @UBICACION INT = NULL
AS
SET NOCOUNT ON

    SELECT  m.imo_id,
            m.imo_fecha_movimiento_utc                  AS FECHA,
            t.imt_nombre                                AS MOVIMIENTO,
            b.bod_codigo                                AS BODEGA,
            ISNULL(uo.bub_codigo, '(sin ubicación)')    AS UBICACION,
            ISNULL(uo.bub_nombre, '')                   AS UBICACION_NOMBRE,
            ud.bub_codigo                               AS UBICACION_DESTINO,
            CASE WHEN t.imt_id IN (1, 3, 4, 7) THEN m.imo_cantidad
                 WHEN t.imt_id = 9             THEN 0
                 ELSE -m.imo_cantidad END               AS CANTIDAD,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO,
            ISNULL(m.imo_observacion, '')               AS OBSERVACION
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
    JOIN    [dbo].[Bodega] b  ON b.bod_id = m.imo_bodega
    LEFT JOIN [dbo].[Bodega_Ubicacion] uo ON uo.bub_id = m.imo_bodega_ubicacion
    LEFT JOIN [dbo].[Bodega_Ubicacion] ud ON ud.bub_id = m.imo_bodega_ubicacion_destino
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = m.imo_usuario_creacion
    WHERE   m.imo_cliente  = @CLIENTE
      AND   m.imo_repuesto = @REPUESTO
      AND   (@BODEGA    IS NULL OR m.imo_bodega = @BODEGA)
      AND   (@UBICACION IS NULL OR m.imo_bodega_ubicacion = @UBICACION
                                OR m.imo_bodega_ubicacion_destino = @UBICACION)
    ORDER BY m.imo_fecha_movimiento_utc DESC, m.imo_id DESC
GO


/* ========================================================================
   5. QUE HAY EN ESTA UBICACION  /  QUE HAY EN ESTA BODEGA

      Las dos preguntas que contesta el escaneo de una etiqueta.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_UBICACION_DESGLOSE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_UBICACION_DESGLOSE]
GO

CREATE PROCEDURE [dbo].[SEL_UBICACION_DESGLOSE]
    @CLIENTE   INT,
    @UBICACION INT
AS
SET NOCOUNT ON

    /* Encabezado: que ubicacion es y de que bodega. */
    SELECT  ub.bub_id, ub.bub_codigo, ub.bub_nombre, ub.bub_habilitado,
            b.bod_id, b.bod_codigo, b.bod_nombre,
            ci.cin_nombre AS PLANTA
    FROM    [dbo].[Bodega_Ubicacion] ub
    JOIN    [dbo].[Bodega] b ON b.bod_id = ub.bub_bodega
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   ub.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE

    /* Detalle: lo que hay ahi ahora. */
    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r    ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Usuario] u   ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega_ubicacion = @UBICACION
      AND   s.isa_cantidad <> 0
    ORDER BY r.rep_codigo
GO


IF OBJECT_ID('dbo.SEL_BODEGA_DESGLOSE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_BODEGA_DESGLOSE]
GO

CREATE PROCEDURE [dbo].[SEL_BODEGA_DESGLOSE]
    @CLIENTE INT,
    @BODEGA  INT
AS
SET NOCOUNT ON

    /* Encabezado. */
    SELECT  b.bod_id, b.bod_codigo, b.bod_nombre, b.bod_habilitado,
            ISNULL(b.bod_descripcion, '') AS bod_descripcion,
            ci.cin_nombre AS PLANTA
    FROM    [dbo].[Bodega] b
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_id = @BODEGA AND b.bod_cliente = @CLIENTE

    /* Detalle repuesto por repuesto y ubicacion por ubicacion. */
    SELECT  ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')                AS UBICACION_NOMBRE,
            ub.bub_id,
            r.rep_id, r.rep_codigo, r.rep_nombre,
            ume.ume_simbolo      AS UNIDAD,
            s.isa_cantidad       AS CANTIDAD,
            s.isa_costo_promedio AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega  = @BODEGA
      AND   s.isa_cantidad <> 0
    ORDER BY UBICACION, r.rep_codigo

    /* Resumen por ubicacion, para el encabezado del desglose. */
    SELECT  ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            COUNT(DISTINCT s.isa_repuesto) AS REPUESTOS,
            SUM(s.isa_cantidad)            AS UNIDADES
    FROM    [dbo].[Inventario_Saldo] s
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega  = @BODEGA
      AND   s.isa_cantidad <> 0
    GROUP BY ub.bub_codigo
    ORDER BY UBICACION
GO



/* ========================================================================
   5b. CUANTO VINO EN EL LOTE Y CUANTO QUEDA

      RECIBIDO no sale de una columna: sale de sumar las entradas del libro
      que citan ese lote. Es la unica cifra que no se puede falsear, porque
      es exactamente la mercaderia que alguien registro recibir.

      QUEDA es el saldo vivo de ese lote. La diferencia entre las dos es lo
      que se consumio, y se muestra armada para no obligar a restar de
      cabeza.

      CONSUMIDO puede dar distinto de RECIBIDO - QUEDA si hubo mermas o
      ajustes, y por eso se calcula aparte en vez de deducirse.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_LOTE_SALDO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_REPUESTO_LOTE_SALDO]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_LOTE_SALDO]
    @CLIENTE  INT,
    @REPUESTO INT = NULL,
    @LOTE     INT = NULL
AS
SET NOCOUNT ON

    SELECT  l.rlo_id,
            l.rlo_codigo,
            l.rlo_fecha_ingreso,
            l.rlo_fecha_vencimiento,
            l.rlo_habilitado,
            r.rep_id,
            r.rep_codigo,
            r.rep_nombre,
            ume.ume_simbolo AS UNIDAD,

            /* Lo que entro con este lote. */
            ISNULL((SELECT SUM(m.imo_cantidad)
                    FROM   [dbo].[Inventario_Movimiento] m
                    WHERE  m.imo_repuesto_lote = l.rlo_id
                      AND  m.imo_inventario_movimiento_tipo IN (1, 3, 4, 7)), 0) AS RECIBIDO,

            /* Lo que salio. */
            ISNULL((SELECT SUM(m.imo_cantidad)
                    FROM   [dbo].[Inventario_Movimiento] m
                    WHERE  m.imo_repuesto_lote = l.rlo_id
                      AND  m.imo_inventario_movimiento_tipo IN (2, 5, 6, 8)), 0) AS CONSUMIDO,

            /* Lo que queda, tomado del saldo y no de la resta. */
            ISNULL((SELECT SUM(s.isa_cantidad)
                    FROM   [dbo].[Inventario_Saldo] s
                    WHERE  s.isa_repuesto_lote = l.rlo_id), 0) AS QUEDA,

            /* En cuantas ubicaciones esta repartido lo que queda. */
            ISNULL((SELECT COUNT(*)
                    FROM   [dbo].[Inventario_Saldo] s
                    WHERE  s.isa_repuesto_lote = l.rlo_id
                      AND  s.isa_cantidad <> 0), 0) AS UBICACIONES,

            /* Cuando vence, en dias. Negativo quiere decir vencido. */
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), l.rlo_fecha_vencimiento)
            END AS DIAS_PARA_VENCER,

            LTRIM(RTRIM(ISNULL(uc.usu_nombre, '') + ' '
                      + ISNULL(uc.usu_apellido_paterno, ''))) AS USUARIO_CREACION,
            l.rlo_fecha_creacion,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre, '') + ' '
                      + ISNULL(ua.usu_apellido_paterno, ''))) AS USUARIO_ACTUALIZACION,
            l.rlo_fecha_actualizacion
    FROM    [dbo].[Repuesto_Lote] l
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = l.rlo_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Usuario] uc      ON uc.usu_id = l.rlo_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua      ON ua.usu_id = l.rlo_usuario_actualizacion
    WHERE   l.rlo_cliente = @CLIENTE
      AND   (@REPUESTO IS NULL OR l.rlo_repuesto = @REPUESTO)
      AND   (@LOTE     IS NULL OR l.rlo_id       = @LOTE)
    ORDER BY r.rep_codigo, l.rlo_fecha_ingreso DESC, l.rlo_codigo
GO


/* Donde esta repartido un lote. */
IF OBJECT_ID('dbo.SEL_REPUESTO_LOTE_UBICACION') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_REPUESTO_LOTE_UBICACION]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_LOTE_UBICACION]
    @CLIENTE INT,
    @LOTE    INT
AS
SET NOCOUNT ON

    SELECT  b.bod_codigo AS BODEGA,
            b.bod_nombre AS BODEGA_NOMBRE,
            ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')                AS UBICACION_NOMBRE,
            s.isa_cantidad                           AS CANTIDAD,
            s.isa_fecha_ultimo_movimiento            AS ULTIMO_MOVIMIENTO
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Bodega] b ON b.bod_id = s.isa_bodega
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_repuesto_lote = @LOTE
      AND   s.isa_cantidad <> 0
    ORDER BY b.bod_codigo, UBICACION
GO


/* ========================================================================
   6. VERIFICACION
   ======================================================================== */
PRINT '--- Saldo por ubicacion ---'
SELECT  b.bod_codigo AS BODEGA, ISNULL(u.bub_codigo, '(sin ubicacion)') AS UBICACION,
        r.rep_codigo AS REPUESTO, s.isa_cantidad AS CANTIDAD
FROM    [dbo].[Inventario_Saldo] s
JOIN    [dbo].[Bodega] b   ON b.bod_id = s.isa_bodega
JOIN    [dbo].[Repuesto] r ON r.rep_id = s.isa_repuesto
LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = s.isa_bodega_ubicacion
ORDER BY b.bod_codigo, UBICACION, r.rep_codigo
GO

PRINT '--- Lotes: cuanto vino y cuanto queda ---'
EXEC [dbo].[SEL_REPUESTO_LOTE_SALDO] @CLIENTE = 1
GO
