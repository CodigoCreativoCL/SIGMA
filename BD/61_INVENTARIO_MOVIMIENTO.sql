/* ============================================================================
   SIGMA — Bloque 61
   EL MODULO DEL BODEGUERO (2 de 2): EL MOVIMIENTO DE INVENTARIO
   ----------------------------------------------------------------------------

   HU-054 ingreso · HU-055 entrega y devolucion · HU-056 consulta ·
   HU-057 ajuste. Las cuatro son la misma operacion con distinto signo y
   distintas validaciones.

   UN SOLO PROCEDIMIENTO PARA LOS OCHO TIPOS

     La tentacion es INS_INGRESO, INS_CONSUMO, INS_AJUSTE. No: lo dificil
     de un inventario no es insertar la fila, es que Inventario_Saldo no se
     despegue nunca de Inventario_Movimiento. Con seis procedimientos hay
     seis copias de esa logica, y basta que una se olvide de tocar el saldo
     -o que lo toque distinto- para que la existencia del sistema deje de
     ser la de la estanteria. Que es exactamente el problema que el modulo
     viene a resolver.

     El tipo decide el signo y las validaciones extra. El saldo se actualiza
     en un solo lugar.

   EL SALDO ES DERIVABLE Y AUN ASI SE GUARDA

     Contradice al Anexo A §3.3 -"si es derivable no lleva columna"- y hay
     que decir por que. La existencia de un repuesto es SUM() sobre todos
     sus movimientos desde el principio de los tiempos, y esa consulta la
     hace la app cada vez que un tecnico mira una pieza, con la red de una
     planta. Inventario_Saldo es una materializacion deliberada, con su
     indice unico por repuesto y bodega, y se escribe SOLO aca dentro.

   IDEMPOTENCIA POR UUID

     imo_uuid existe para que la app pueda reintentar. Un tecnico sin senal
     encola el movimiento, la red vuelve a medias y el telefono manda dos
     veces: si el uuid ya esta, se devuelve el id que ya habia y no se
     descuenta dos veces. Es la unica defensa real contra el doble consumo.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. INS_INVENTARIO_MOVIMIENTO

      TIPOS Y SIGNO
        1 INGRESO COMPRA    +      5 AJUSTE NEGATIVO   -
        2 SALIDA CONSUMO    -      6 TRASLADO SALIDA   -  (genera el 7)
        3 DEVOLUCION        +      7 TRASLADO INGRESO  +  (no se pide solo)
        4 AJUSTE POSITIVO   +      8 MERMA             -

      QUE EXIGE CADA UNO
        · ingreso de un repuesto que controla lote  -> el lote  (HU-054 CA2)
        · cualquier salida                          -> saldo suficiente
        · ajuste (4, 5) y merma (8)                 -> motivo   (HU-057 CA1)
        · traslado (6)                              -> bodega destino
   ======================================================================== */
IF OBJECT_ID('dbo.INS_INVENTARIO_MOVIMIENTO') IS NOT NULL
    DROP PROCEDURE [dbo].[INS_INVENTARIO_MOVIMIENTO]
GO

CREATE PROCEDURE [dbo].[INS_INVENTARIO_MOVIMIENTO]
    @ID              INT OUTPUT,
    @CLIENTE         INT,
    @REPUESTO        INT,
    @BODEGA          INT,
    @TIPO            INT,
    @CANTIDAD        DECIMAL(18,4),
    @UBICACION       INT = NULL,
    @LOTE            INT = NULL,
    @COSTO_UNITARIO  DECIMAL(18,4) = NULL,
    @MONEDA          INT = NULL,
    @ORDEN_TRABAJO   INT = NULL,
    @BODEGA_DESTINO  INT = NULL,
    @OBSERVACION     NVARCHAR(1000) = NULL,
    @UUID            UNIQUEIDENTIFIER = NULL,
    @USUARIO         INT
AS
SET NOCOUNT ON

DECLARE @SIGNO        INT
       ,@SALDO        DECIMAL(18,4)
       ,@CONTROLA     BIT
       ,@AHORA        DATETIME = GETUTCDATE()
       ,@MSG          NVARCHAR(500)
       ,@COSTO_PROM   DECIMAL(18,4)
       ,@CANT_PREVIA  DECIMAL(18,4)

/* ---- Idempotencia: si el uuid ya paso, no se repite ----
   Va ANTES de cualquier validacion. Un reintento no tiene por que volver a
   pasar por reglas que ya pasaron, y si entretanto el saldo bajo, la
   segunda llamada fallaria por algo que ya estaba hecho. */
IF (@UUID IS NOT NULL)
BEGIN
    SELECT @ID = imo_id FROM [dbo].[Inventario_Movimiento] WHERE imo_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'El movimiento ya estaba registrado.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

/* ---- Tipo y signo ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo]
                WHERE imt_id = @TIPO AND imt_habilitado = 1)
BEGIN
    RAISERROR('1.- EL TIPO DE MOVIMIENTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@TIPO = 7)
BEGIN
    RAISERROR('2.- EL TRASLADO DE INGRESO NO SE REGISTRA SOLO: LO GENERA EL TRASLADO DE SALIDA.', 16, 1)
    RETURN -1
END

SET @SIGNO = CASE WHEN @TIPO IN (1, 3, 4, 7) THEN 1 ELSE -1 END

/* ---- Cantidad ----
   Siempre positiva. El signo lo pone el tipo, no quien llama: aceptar
   negativos permitiria un "ingreso de -5" que descuenta sin dejar rastro de
   que fue una salida. */
IF (@CANTIDAD IS NULL OR @CANTIDAD <= 0)
BEGIN
    RAISERROR('3.- LA CANTIDAD DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* ---- Repuesto y bodega, del cliente ---- */
SELECT @CONTROLA = rep_controla_lote
FROM   [dbo].[Repuesto]
WHERE  rep_id = @REPUESTO AND rep_cliente = @CLIENTE AND rep_habilitado = 1

IF (@CONTROLA IS NULL)
BEGIN
    RAISERROR('4.- EL REPUESTO NO EXISTE O ESTA DADO DE BAJA.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega]
                WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE AND bod_habilitado = 1)
BEGIN
    RAISERROR('5.- LA BODEGA NO EXISTE O ESTA DADA DE BAJA.', 16, 1)
    RETURN -1
END

IF (@UBICACION IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                     WHERE bub_id = @UBICACION AND bub_bodega = @BODEGA))
BEGIN
    RAISERROR('6.- LA UBICACION NO PERTENECE A ESA BODEGA.', 16, 1)
    RETURN -1
END

/* ---- Lote: HU-054 criterio 2 ---- */
IF (@CONTROLA = 1 AND @SIGNO = 1 AND @LOTE IS NULL)
BEGIN
    RAISERROR('7.- ESTE REPUESTO CONTROLA LOTE: INDIQUE EL LOTE DEL INGRESO.', 16, 1)
    RETURN -1
END

IF (@LOTE IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Lote]
                     WHERE rlo_id = @LOTE AND rlo_repuesto = @REPUESTO))
BEGIN
    RAISERROR('8.- EL LOTE NO PERTENECE A ESE REPUESTO.', 16, 1)
    RETURN -1
END

/* ---- Motivo: HU-057 criterio 1 ----
   Un ajuste sin motivo es una diferencia que nadie va a poder explicar
   despues. Se exige texto, no una marca. */
IF (@TIPO IN (4, 5, 8) AND (@OBSERVACION IS NULL OR LEN(LTRIM(@OBSERVACION)) < 5))
BEGIN
    RAISERROR('9.- INDIQUE EL MOTIVO DEL AJUSTE (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END

/* ---- Traslado ---- */
IF (@TIPO = 6)
BEGIN
    IF (@BODEGA_DESTINO IS NULL)
    BEGIN
        RAISERROR('10.- INDIQUE LA BODEGA DE DESTINO DEL TRASLADO.', 16, 1)
        RETURN -1
    END

    IF (@BODEGA_DESTINO = @BODEGA)
    BEGIN
        RAISERROR('11.- LA BODEGA DE DESTINO NO PUEDE SER LA MISMA DE ORIGEN.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega]
                    WHERE bod_id = @BODEGA_DESTINO AND bod_cliente = @CLIENTE AND bod_habilitado = 1)
    BEGIN
        RAISERROR('12.- LA BODEGA DE DESTINO NO EXISTE O ESTA DADA DE BAJA.', 16, 1)
        RETURN -1
    END
END

/* ---- Saldo suficiente: HU-055 criterio 2 ----
   El mensaje dice la existencia actual, que es lo que el criterio pide:
   "rechazada indicando la existencia actual". Un "no hay suficiente" a
   secas obliga al bodeguero a ir a consultar en otra pantalla. */
SELECT @SALDO = ISNULL(isa_cantidad, 0)
FROM   [dbo].[Inventario_Saldo]
WHERE  isa_repuesto = @REPUESTO AND isa_bodega = @BODEGA

SET @SALDO = ISNULL(@SALDO, 0)

IF (@SIGNO = -1 AND @CANTIDAD > @SALDO)
BEGIN
    SET @MSG = '13.- EXISTENCIA INSUFICIENTE: HAY ' + LTRIM(STR(CAST(@SALDO AS DECIMAL(18,2)), 18, 2))
             + ' Y SE INTENTA SACAR ' + LTRIM(STR(CAST(@CANTIDAD AS DECIMAL(18,2)), 18, 2)) + '.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END


/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    /* ---- 1. El movimiento ---- */
    INSERT INTO [dbo].[Inventario_Movimiento]
        (imo_uuid, imo_cliente, imo_repuesto, imo_bodega, imo_bodega_ubicacion,
         imo_repuesto_lote, imo_inventario_movimiento_tipo, imo_cantidad,
         imo_costo_unitario, imo_moneda, imo_fecha_movimiento_utc, imo_orden_trabajo,
         imo_bodega_destino, imo_observacion, imo_usuario_creacion, imo_fecha_creacion)
    VALUES (@UUID, @CLIENTE, @REPUESTO, @BODEGA, @UBICACION, @LOTE, @TIPO, @CANTIDAD,
            @COSTO_UNITARIO, @MONEDA, @AHORA, @ORDEN_TRABAJO, @BODEGA_DESTINO,
            @OBSERVACION, @USUARIO, GETDATE())

    SET @ID = SCOPE_IDENTITY()

    /* ---- 2. El saldo de la bodega de origen ----

       El costo promedio se recalcula SOLO cuando entra mercaderia con
       costo. En una salida el promedio no cambia: sacar diez unidades no
       hace que las que quedan hayan costado otra cosa. */
    SELECT @CANT_PREVIA = isa_cantidad, @COSTO_PROM = isa_costo_promedio
    FROM   [dbo].[Inventario_Saldo]
    WHERE  isa_repuesto = @REPUESTO AND isa_bodega = @BODEGA

    IF (@CANT_PREVIA IS NULL)
    BEGIN
        INSERT INTO [dbo].[Inventario_Saldo]
            (isa_cliente, isa_repuesto, isa_bodega, isa_cantidad, isa_cantidad_reservada,
             isa_costo_promedio, isa_fecha_ultimo_movimiento, isa_usuario_actualizacion,
             isa_fecha_actualizacion)
        VALUES (@CLIENTE, @REPUESTO, @BODEGA, @SIGNO * @CANTIDAD, 0,
                @COSTO_UNITARIO, @AHORA, @USUARIO, GETDATE())
    END
    ELSE
    BEGIN
        IF (@SIGNO = 1 AND @COSTO_UNITARIO IS NOT NULL)
            SET @COSTO_PROM = ((ISNULL(@COSTO_PROM, @COSTO_UNITARIO) * @CANT_PREVIA)
                               + (@COSTO_UNITARIO * @CANTIDAD))
                              / NULLIF(@CANT_PREVIA + @CANTIDAD, 0)

        UPDATE  [dbo].[Inventario_Saldo]
        SET     isa_cantidad                = isa_cantidad + (@SIGNO * @CANTIDAD)
               ,isa_costo_promedio          = @COSTO_PROM
               ,isa_fecha_ultimo_movimiento = @AHORA
               ,isa_usuario_actualizacion   = @USUARIO
               ,isa_fecha_actualizacion     = GETDATE()
        WHERE   isa_repuesto = @REPUESTO AND isa_bodega = @BODEGA
    END

    /* ---- 3. El traslado: su otra mitad ----
       El movimiento de ingreso en destino se genera aca, no lo manda quien
       llama. Si dependiera de dos llamadas, una caida entre las dos dejaria
       el repuesto sin existir en ninguna de las dos bodegas. */
    IF (@TIPO = 6)
    BEGIN
        INSERT INTO [dbo].[Inventario_Movimiento]
            (imo_uuid, imo_cliente, imo_repuesto, imo_bodega, imo_repuesto_lote,
             imo_inventario_movimiento_tipo, imo_cantidad, imo_costo_unitario, imo_moneda,
             imo_fecha_movimiento_utc, imo_observacion, imo_usuario_creacion, imo_fecha_creacion)
        VALUES (NEWID(), @CLIENTE, @REPUESTO, @BODEGA_DESTINO, @LOTE, 7, @CANTIDAD,
                @COSTO_UNITARIO, @MONEDA, @AHORA,
                ISNULL(@OBSERVACION, N'') + N' (traslado desde el movimiento ' + LTRIM(STR(@ID)) + N')',
                @USUARIO, GETDATE())

        IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                    WHERE isa_repuesto = @REPUESTO AND isa_bodega = @BODEGA_DESTINO)
            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + @CANTIDAD
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = GETDATE()
            WHERE   isa_repuesto = @REPUESTO AND isa_bodega = @BODEGA_DESTINO
        ELSE
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_cantidad, isa_cantidad_reservada,
                 isa_costo_promedio, isa_fecha_ultimo_movimiento, isa_usuario_actualizacion,
                 isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA_DESTINO, @CANTIDAD, 0,
                    @COSTO_UNITARIO, @AHORA, @USUARIO, GETDATE())
    END

    /* ---- 4. La orden de trabajo: HU-055 criterios 1 y 3 ----

       Consumo suma a lo consumido. Devolucion suma a lo devuelto Y resta de
       lo consumido, que es literalmente lo que pide el criterio 3: "la
       cantidad consumida de la orden se reduce en la misma cifra".

       No baja de cero: devolver mas de lo que se llevo es un error de
       digitacion, y dejar un consumo negativo contaminaria el costo de la
       intervencion. */
    IF (@ORDEN_TRABAJO IS NOT NULL AND @TIPO IN (2, 3))
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Repuesto]
                        WHERE ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO)
            INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
                (ore_orden_trabajo, ore_repuesto, ore_repuesto_lote, ore_cantidad_consumida,
                 ore_cantidad_devuelta, ore_costo_unitario, ore_moneda,
                 ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
            VALUES (@ORDEN_TRABAJO, @REPUESTO, @LOTE, 0, 0, @COSTO_UNITARIO, @MONEDA,
                    @USUARIO, GETDATE(), 1)

        UPDATE  [dbo].[Orden_Trabajo_Repuesto]
        SET     ore_cantidad_consumida = CASE
                    WHEN @TIPO = 2 THEN ISNULL(ore_cantidad_consumida, 0) + @CANTIDAD
                    ELSE CASE WHEN ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD < 0
                              THEN 0 ELSE ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD END
                END
               ,ore_cantidad_devuelta = CASE
                    WHEN @TIPO = 3 THEN ISNULL(ore_cantidad_devuelta, 0) + @CANTIDAD
                    ELSE ore_cantidad_devuelta
                END
               ,ore_costo_unitario        = ISNULL(@COSTO_UNITARIO, ore_costo_unitario)
               ,ore_usuario_actualizacion = @USUARIO
               ,ore_fecha_actualizacion   = GETDATE()
        WHERE   ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO
    END

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Movimiento registrado.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   2. SEL_INVENTARIO_SALDO  (HU-056)

      "Veo la existencia por bodega, su ubicacion y sus umbrales, y se
      destaca la bodega cuya existencia esta bajo el minimo."

      BAJO_MINIMO y SOBRE_MAXIMO se CALCULAN, no se guardan (Anexo A §3.3):
      dependen del saldo, que cambia con cada movimiento. Una columna con
      esa marca estaria desactualizada la mitad del tiempo.

      La ubicacion sale del ultimo movimiento que la indico. No hay una
      columna "donde vive este repuesto" porque el mismo repuesto puede
      estar en dos estantes de la misma bodega, y el dato que sirve es
      "donde lo dejaron la ultima vez".
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_INVENTARIO_SALDO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_INVENTARIO_SALDO]
GO
CREATE PROCEDURE [dbo].[SEL_INVENTARIO_SALDO]
    @CLIENTE     INT,
    @REPUESTO    INT = NULL,
    @BODEGA      INT = NULL,
    @INSTALACION INT = NULL,
    @FILTRO      NVARCHAR(200) = NULL,
    @SOLO_ALERTA BIT = 0
AS
SET NOCOUNT ON

    SELECT  s.isa_id, s.isa_repuesto, s.isa_bodega,
            s.isa_cantidad, s.isa_cantidad_reservada,
            (s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0)) AS CANTIDAD_DISPONIBLE,
            s.isa_costo_promedio, s.isa_fecha_ultimo_movimiento,
            r.rep_codigo AS REPUESTO_CODIGO, r.rep_nombre AS REPUESTO_NOMBRE,
            r.rep_controla_lote,
            ume.ume_simbolo AS UNIDAD_SIMBOLO,
            b.bod_codigo AS BODEGA_CODIGO, b.bod_nombre AS BODEGA_NOMBRE,
            cin.cin_nombre AS PLANTA_NOMBRE,
            st.rbs_stock_minimo, st.rbs_stock_maximo, st.rbs_punto_reposicion,
            CASE WHEN st.rbs_stock_minimo IS NOT NULL
                  AND s.isa_cantidad < st.rbs_stock_minimo THEN 1 ELSE 0 END AS BAJO_MINIMO,
            CASE WHEN st.rbs_stock_maximo IS NOT NULL
                  AND s.isa_cantidad > st.rbs_stock_maximo THEN 1 ELSE 0 END AS SOBRE_MAXIMO,
            -- Donde lo dejaron la ultima vez.
            (SELECT TOP 1 u.bub_codigo
               FROM [dbo].[Inventario_Movimiento] m
               JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = m.imo_bodega_ubicacion
              WHERE m.imo_repuesto = s.isa_repuesto AND m.imo_bodega = s.isa_bodega
              ORDER BY m.imo_id DESC) AS UBICACION_CODIGO
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id  = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    JOIN    [dbo].[Bodega] b          ON b.bod_id  = s.isa_bodega
    JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = b.bod_cliente_instalacion
    LEFT JOIN [dbo].[Repuesto_Bodega_Stock] st
           ON st.rbs_repuesto = s.isa_repuesto
          AND st.rbs_bodega   = s.isa_bodega
          AND st.rbs_habilitado = 1
    WHERE   s.isa_cliente = @CLIENTE
      AND   (@REPUESTO IS NULL OR s.isa_repuesto = @REPUESTO)
      AND   (@BODEGA IS NULL OR s.isa_bodega = @BODEGA)
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
      AND   (@FILTRO IS NULL OR r.rep_codigo LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre LIKE '%' + @FILTRO + '%'
                             OR b.bod_nombre LIKE '%' + @FILTRO + '%')
      AND   (@SOLO_ALERTA = 0
             OR (st.rbs_stock_minimo IS NOT NULL AND s.isa_cantidad < st.rbs_stock_minimo)
             OR (st.rbs_stock_maximo IS NOT NULL AND s.isa_cantidad > st.rbs_stock_maximo))
    ORDER BY r.rep_codigo, b.bod_codigo
GO


/* ========================================================================
   3. SEL_INVENTARIO_MOVIMIENTO  (HU-057 criterio 2)

      "Los ajustes se distinguen de los ingresos y de los consumos." Por eso
      viaja imt_codigo y no solo el nombre: la pantalla puede pintar cada
      familia distinto sin adivinar por el texto.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_INVENTARIO_MOVIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO]
GO
CREATE PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO]
    @ID          INT = NULL,
    @CLIENTE     INT,
    @REPUESTO    INT = NULL,
    @BODEGA      INT = NULL,
    @TIPO        INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL,
    @FILTRO      NVARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  m.imo_id, m.imo_uuid, m.imo_repuesto, m.imo_bodega,
            m.imo_inventario_movimiento_tipo, m.imo_cantidad,
            m.imo_costo_unitario, m.imo_fecha_movimiento_utc,
            m.imo_orden_trabajo, m.imo_bodega_destino, m.imo_observacion,
            t.imt_codigo AS TIPO_CODIGO, t.imt_nombre AS TIPO_NOMBRE,
            CASE WHEN t.imt_id IN (1, 3, 4, 7) THEN 1 ELSE -1 END AS SIGNO,
            -- Tres familias, para que la pantalla no las deduzca del texto.
            CASE WHEN t.imt_id IN (4, 5, 8) THEN 'AJUSTE'
                 WHEN t.imt_id IN (6, 7)    THEN 'TRASLADO'
                 WHEN t.imt_id = 2          THEN 'CONSUMO'
                 ELSE 'INGRESO' END AS FAMILIA,
            r.rep_codigo AS REPUESTO_CODIGO, r.rep_nombre AS REPUESTO_NOMBRE,
            ume.ume_simbolo AS UNIDAD_SIMBOLO,
            b.bod_codigo AS BODEGA_CODIGO, b.bod_nombre AS BODEGA_NOMBRE,
            bd.bod_nombre AS BODEGA_DESTINO_NOMBRE,
            u.bub_codigo  AS UBICACION_CODIGO,
            lo.rlo_codigo AS LOTE_CODIGO,
            LTRIM(RTRIM(ISNULL(us.usu_nombre, '') + ' ' + ISNULL(us.usu_apellido_paterno, ''))) AS USUARIO_NOMBRE
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id  = m.imo_inventario_movimiento_tipo
    JOIN    [dbo].[Repuesto] r        ON r.rep_id   = m.imo_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    JOIN    [dbo].[Bodega] b          ON b.bod_id   = m.imo_bodega
    LEFT JOIN [dbo].[Bodega] bd            ON bd.bod_id = m.imo_bodega_destino
    LEFT JOIN [dbo].[Bodega_Ubicacion] u   ON u.bub_id  = m.imo_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] lo     ON lo.rlo_id = m.imo_repuesto_lote
    LEFT JOIN [dbo].[Usuario] us           ON us.usu_id = m.imo_usuario_creacion
    WHERE   m.imo_cliente = @CLIENTE
      AND   (@ID IS NULL OR m.imo_id = @ID)
      AND   (@REPUESTO IS NULL OR m.imo_repuesto = @REPUESTO)
      AND   (@BODEGA IS NULL OR m.imo_bodega = @BODEGA)
      AND   (@TIPO IS NULL OR m.imo_inventario_movimiento_tipo = @TIPO)
      AND   (@DESDE IS NULL OR m.imo_fecha_movimiento_utc >= @DESDE)
      AND   (@HASTA IS NULL OR m.imo_fecha_movimiento_utc < DATEADD(DAY, 1, @HASTA))
      AND   (@FILTRO IS NULL OR r.rep_codigo LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre LIKE '%' + @FILTRO + '%'
                             OR m.imo_observacion LIKE '%' + @FILTRO + '%')
    ORDER BY m.imo_id DESC
GO


/* ========================================================================
   4. SEL_REPUESTO_LOTE  e  INS_REPUESTO_LOTE

      El lote se crea al recibir la mercaderia, no antes: nadie sabe el
      numero de lote hasta que llega el camion. Por eso el ingreso puede
      crearlo al vuelo desde la misma pantalla.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_LOTE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_REPUESTO_LOTE]
GO
CREATE PROCEDURE [dbo].[SEL_REPUESTO_LOTE]
    @ID       INT = NULL,
    @CLIENTE  INT,
    @REPUESTO INT = NULL,
    @VIGENTES BIT = 0
AS
SET NOCOUNT ON

    SELECT  l.rlo_id, l.rlo_repuesto, l.rlo_codigo, l.rlo_fecha_ingreso,
            l.rlo_fecha_vencimiento, l.rlo_proveedor, l.rlo_costo_unitario,
            l.rlo_moneda, l.rlo_observacion, l.rlo_habilitado,
            r.rep_codigo AS REPUESTO_CODIGO,
            CASE WHEN l.rlo_fecha_vencimiento IS NOT NULL
                  AND l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE)
                 THEN 1 ELSE 0 END AS VENCIDO
    FROM    [dbo].[Repuesto_Lote] l
    JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto
    WHERE   l.rlo_cliente = @CLIENTE
      AND   (@ID IS NULL OR l.rlo_id = @ID)
      AND   (@REPUESTO IS NULL OR l.rlo_repuesto = @REPUESTO)
      AND   (@VIGENTES = 0 OR (l.rlo_habilitado = 1
             AND (l.rlo_fecha_vencimiento IS NULL
                  OR l.rlo_fecha_vencimiento >= CAST(GETDATE() AS DATE))))
    ORDER BY l.rlo_fecha_vencimiento, l.rlo_codigo
GO


IF OBJECT_ID('dbo.INS_REPUESTO_LOTE') IS NOT NULL DROP PROCEDURE [dbo].[INS_REPUESTO_LOTE]
GO
CREATE PROCEDURE [dbo].[INS_REPUESTO_LOTE]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @CODIGO            NVARCHAR(200),
    @FECHA_INGRESO     DATE = NULL,
    @FECHA_VENCIMIENTO DATE = NULL,
    @PROVEEDOR         INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @MONEDA            INT = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL CODIGO DEL LOTE.', 16, 1)
        RETURN -1
    END

    /* Idempotente por (repuesto, codigo): si el lote ya existe se devuelve.
       Volver a recibir del mismo lote es lo normal, no un error. */
    SELECT @ID = rlo_id FROM [dbo].[Repuesto_Lote]
     WHERE rlo_repuesto = @REPUESTO AND rlo_codigo = @CODIGO

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'El lote ya existía.' [MENSAJE]
        RETURN 0
    END

    IF (@FECHA_VENCIMIENTO IS NOT NULL AND @FECHA_INGRESO IS NOT NULL
        AND @FECHA_VENCIMIENTO < @FECHA_INGRESO)
    BEGIN
        RAISERROR('3.- LA FECHA DE VENCIMIENTO NO PUEDE SER ANTERIOR A LA DE INGRESO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto_Lote]
        (rlo_cliente, rlo_repuesto, rlo_codigo, rlo_fecha_ingreso, rlo_fecha_vencimiento,
         rlo_proveedor, rlo_costo_unitario, rlo_moneda, rlo_observacion,
         rlo_usuario_creacion, rlo_fecha_creacion, rlo_habilitado)
    VALUES (@CLIENTE, @REPUESTO, LTRIM(RTRIM(@CODIGO)),
            ISNULL(@FECHA_INGRESO, CAST(GETDATE() AS DATE)), @FECHA_VENCIMIENTO,
            @PROVEEDOR, @COSTO_UNITARIO, @MONEDA, @OBSERVACION, @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Lote creado.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   5. VERIFICACION
   ======================================================================== */
PRINT '--- SPs del bloque 61 ---'
SELECT name FROM sys.objects
WHERE type = 'P' AND (name LIKE '%INVENTARIO%' OR name LIKE '%REPUESTO_LOTE%')
ORDER BY name
GO
