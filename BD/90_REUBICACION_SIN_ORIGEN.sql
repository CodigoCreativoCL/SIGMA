/* ============================================================================
   SIGMA - Bloque 90
   LO QUE NO TIENE ESTANTE TIENE QUE PODER GUARDARSE EN UNO
   ----------------------------------------------------------------------------

   EL PROBLEMA

     Al reconstruir los saldos por ubicacion (bloque 71) quedaron filas de
     Inventario_Saldo con isa_bodega_ubicacion NULL en bodegas que SI tienen
     estantes. Como la ubicacion es obligatoria en esas bodegas (error 15),
     esa existencia no se puede sacar por ningun camino: esta atrapada.

     Y la reubicacion -el tipo 9, que es justo la operacion "esto va a otro
     estante"- tampoco servia para rescatarla:

         IF (@UBICACION IS NULL OR @UBICACION_DESTINO IS NULL)
             RAISERROR('18.- LA REUBICACION NECESITA LA UBICACION DE ORIGEN Y
                        LA DE DESTINO.')

     Exigia ubicacion de ORIGEN, y el origen de lo atrapado es precisamente
     ninguna. La unica operacion capaz de arreglarlo se negaba a intentarlo.

   NO ES SOLO UN RESTO DE LA MIGRACION

     El traslado entre bodegas genera la entrada del otro lado SIN ubicacion
     de destino: el movimiento 54 de la demo dejo 4 fusibles en Bodega
     Central sin estante, y quedaron igual de atrapados. Asi que esto se
     vuelve a producir cada vez que alguien traslada mercaderia, no es un
     hecho aislado del bloque 71.

     Este bloque abre la salida. Cerrar la entrada -exigir la ubicacion de
     destino en el traslado- es otro cambio, y toca la pantalla: hoy el
     formulario de traslado no tiene donde pedirla, asi que exigirla ahora
     dejaria el traslado imposible de completar. Queda anotado.

   QUE CAMBIA

     1. El error 15 deja de aplicar al tipo 9. En una reubicacion el "donde
        queda" lo dice la ubicacion de DESTINO; el origen nulo es justamente
        el caso que hay que poder reparar.

     2. El error 18 pasa a exigir solo el DESTINO. Guardar en su sitio algo
        que estaba suelto es una reubicacion legitima, no un caso raro.

     El resto del procedimiento ya funcionaba con origen nulo: tanto la
     comprobacion de saldo como el descuento del cubo comparan con
     ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1), que encuentra
     la fila del cubo sin ubicacion sin ningun cambio.

   POR QUE UN MOVIMIENTO Y NO UN UPDATE

     Se podria arreglar el dato con un UPDATE a Inventario_Saldo en dos
     lineas. Quedaria bien y no quedaria registro de quien lo hizo ni cuando.
     El inventario de SIGMA es un libro: la existencia es la consecuencia de
     los movimientos, no un numero que se edita. Una correccion que no deja
     rastro es indistinguible de un error.

   ORDEN: despues de 89_ROWCOUNT_CODIGO_AUTOMATICO.sql
   ============================================================================ */

SET NOCOUNT ON
GO

IF OBJECT_ID('dbo.INS_INVENTARIO_MOVIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[INS_INVENTARIO_MOVIMIENTO]
GO


CREATE PROCEDURE [dbo].[INS_INVENTARIO_MOVIMIENTO]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @BODEGA            INT,
    @TIPO              INT,
    @CANTIDAD          DECIMAL(18,4),
    @UBICACION         INT = NULL,
    @LOTE              INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @MONEDA            INT = NULL,
    @ORDEN_TRABAJO     INT = NULL,
    @BODEGA_DESTINO    INT = NULL,
    @UBICACION_DESTINO INT = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @UUID              UNIQUEIDENTIFIER = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

DECLARE @SIGNO        INT
       ,@SALDO        DECIMAL(18,4)
       ,@CONTROLA     BIT
       ,@AHORA        DATETIME = GETUTCDATE()
       ,@MSG          NVARCHAR(500)
       ,@COSTO_PROM   DECIMAL(18,4)
       ,@CANT_PREVIA  DECIMAL(18,4)
       ,@TIENE_UBIC   BIT

/* ---- Idempotencia: si el uuid ya paso, no se repite ----
   Va ANTES de cualquier validacion. Un reintento no tiene por que volver a
   pasar por reglas que ya pasaron, y si entretanto el saldo bajo, la
   segunda llamada fallaria por algo que ya estaba hecho. */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODO movimiento con uuid responderia
       "ya estaba registrado" y no se guardaria nada. */
    SET @ID = NULL

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

/* La reubicacion no suma ni resta al total de la bodega. */
SET @SIGNO = CASE WHEN @TIPO = 9              THEN 0
                  WHEN @TIPO IN (1, 3, 4, 7)  THEN 1
                  ELSE -1 END

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

/* ---- La ubicacion es obligatoria si la bodega tiene estantes ----
   Ver el encabezado del bloque: sin esto el saldo por ubicacion se degrada
   con cada movimiento que no la informa. */
SET @TIENE_UBIC = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                                     WHERE bub_bodega = @BODEGA AND bub_habilitado = 1)
                       THEN 1 ELSE 0 END

/* El tipo 9 queda fuera: en una reubicacion el "donde queda" lo dice la
   ubicacion de DESTINO, y el origen nulo es el caso que hay que reparar. */
IF (@TIENE_UBIC = 1 AND @UBICACION IS NULL AND @TIPO <> 9)
BEGIN
    RAISERROR('15.- ESTA BODEGA TIENE UBICACIONES: INDIQUE DE CUAL SALE O A CUAL ENTRA.', 16, 1)
    RETURN -1
END

/* ---- Lote ---- */
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

/* ---- Motivo ----
   Un ajuste sin motivo es una diferencia que nadie va a poder explicar
   despues. Se exige texto, no una marca. */
IF (@TIPO IN (4, 5, 8) AND (@OBSERVACION IS NULL OR LEN(LTRIM(@OBSERVACION)) < 5))
BEGIN
    RAISERROR('9.- INDIQUE EL MOTIVO DEL AJUSTE (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END

/* ---- Traslado entre bodegas ---- */
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

    /* La bodega que recibe tambien puede tener estantes, y entonces hay que
       decir en cual queda. Si no los tiene, entra al cubo sin ubicacion. */
    IF (@UBICACION_DESTINO IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                         WHERE bub_id = @UBICACION_DESTINO AND bub_bodega = @BODEGA_DESTINO))
    BEGIN
        RAISERROR('16.- LA UBICACION DE DESTINO NO PERTENECE A LA BODEGA DE DESTINO.', 16, 1)
        RETURN -1
    END

    IF (@UBICACION_DESTINO IS NULL
        AND EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                     WHERE bub_bodega = @BODEGA_DESTINO AND bub_habilitado = 1))
    BEGIN
        RAISERROR('17.- LA BODEGA DE DESTINO TIENE UBICACIONES: INDIQUE EN CUAL QUEDA.', 16, 1)
        RETURN -1
    END
END

/* ---- Reubicacion dentro de la misma bodega ---- */
IF (@TIPO = 9)
BEGIN
    IF (@UBICACION_DESTINO IS NULL)
    BEGIN
        RAISERROR('18.- LA REUBICACION NECESITA LA UBICACION DE DESTINO.', 16, 1)
        RETURN -1
    END

    IF (@UBICACION = @UBICACION_DESTINO)
    BEGIN
        RAISERROR('19.- LA UBICACION DE DESTINO NO PUEDE SER LA MISMA DE ORIGEN.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                    WHERE bub_id = @UBICACION_DESTINO AND bub_bodega = @BODEGA)
    BEGIN
        RAISERROR('20.- LA UBICACION DE DESTINO NO PERTENECE A ESA BODEGA.', 16, 1)
        RETURN -1
    END

    IF (@BODEGA_DESTINO IS NOT NULL)
    BEGIN
        RAISERROR('21.- LA REUBICACION ES DENTRO DE LA MISMA BODEGA: PARA CAMBIAR DE BODEGA USE UN TRASLADO.', 16, 1)
        RETURN -1
    END
END

/* ---- La orden de trabajo, si viene, es de este cliente ----
   Sin esto lo unico que ataja un numero inventado es la clave foranea, y
   su mensaje no se le puede mostrar a nadie. Y una orden de otro cliente
   la FK la deja pasar: el consumo se anotaria en la orden de otra empresa. */
IF (@ORDEN_TRABAJO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                     WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE))
BEGIN
    RAISERROR('14.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END


/* ---- Saldo suficiente ----

   SE MIDE EL CUBO, NO LA BODEGA

     Antes bastaba que la bodega tuviera suficiente. Ahora se saca de un
     estante concreto: que la bodega tenga 50 no ayuda si en ESE estante
     hay 2. Preguntar por la bodega dejaria pasar la salida y el estante
     quedaria negativo, que es justo lo que el bloque 71 acaba de arreglar.

   El mensaje dice la existencia actual del cubo, que es lo que el bodeguero
   necesita para decidir: un "no hay suficiente" a secas lo obliga a ir a
   consultar en otra pantalla. */
IF (@SIGNO = -1 OR @TIPO = 9)
BEGIN
    SET @SALDO = NULL

    SELECT @SALDO = isa_cantidad
    FROM   [dbo].[Inventario_Saldo]
    WHERE  isa_cliente  = @CLIENTE
      AND  isa_repuesto = @REPUESTO
      AND  isa_bodega   = @BODEGA
      AND  ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
      AND  ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

    SET @SALDO = ISNULL(@SALDO, 0)

    IF (@CANTIDAD > @SALDO)
    BEGIN
        SET @MSG = '13.- EXISTENCIA INSUFICIENTE EN ESA UBICACION: HAY '
                 + LTRIM(STR(CAST(@SALDO AS DECIMAL(18,2)), 18, 2))
                 + ' Y SE INTENTA SACAR ' + LTRIM(STR(CAST(@CANTIDAD AS DECIMAL(18,2)), 18, 2)) + '.'
        RAISERROR(@MSG, 16, 1)
        RETURN -1
    END
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
         imo_bodega_destino, imo_bodega_ubicacion_destino, imo_observacion,
         imo_usuario_creacion, imo_fecha_creacion)
    VALUES (@UUID, @CLIENTE, @REPUESTO, @BODEGA, @UBICACION, @LOTE, @TIPO, @CANTIDAD,
            @COSTO_UNITARIO, @MONEDA, @AHORA, @ORDEN_TRABAJO, @BODEGA_DESTINO,
            @UBICACION_DESTINO, @OBSERVACION, @USUARIO, GETDATE())

    SET @ID = SCOPE_IDENTITY()

    /* ---- 2. El cubo de origen ----

       El costo promedio se recalcula SOLO cuando entra mercaderia con
       costo. En una salida el promedio no cambia: sacar diez unidades no
       hace que las que quedan hayan costado otra cosa. */
    IF (@TIPO <> 9)
    BEGIN
        SET @CANT_PREVIA = NULL

        SELECT @CANT_PREVIA = isa_cantidad, @COSTO_PROM = isa_costo_promedio
        FROM   [dbo].[Inventario_Saldo]
        WHERE  isa_cliente  = @CLIENTE
          AND  isa_repuesto = @REPUESTO
          AND  isa_bodega   = @BODEGA
          AND  ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
          AND  ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

        IF (@CANT_PREVIA IS NULL)
        BEGIN
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA, @UBICACION, @LOTE, @SIGNO * @CANTIDAD, 0,
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
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        END
    END

    /* ---- 3. La reubicacion: sale de un estante y entra al otro ----
       Un solo movimiento, dos cubos. El total de la bodega no se mueve. */
    IF (@TIPO = 9)
    BEGIN
        UPDATE  [dbo].[Inventario_Saldo]
        SET     isa_cantidad                = isa_cantidad - @CANTIDAD
               ,isa_fecha_ultimo_movimiento = @AHORA
               ,isa_usuario_actualizacion   = @USUARIO
               ,isa_fecha_actualizacion     = GETDATE()
        WHERE   isa_cliente  = @CLIENTE
          AND   isa_repuesto = @REPUESTO
          AND   isa_bodega   = @BODEGA
          AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
          AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

        IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                    WHERE isa_cliente  = @CLIENTE
                      AND isa_repuesto = @REPUESTO
                      AND isa_bodega   = @BODEGA
                      AND ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
                      AND ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1))
            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + @CANTIDAD
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = GETDATE()
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        ELSE
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA, @UBICACION_DESTINO, @LOTE, @CANTIDAD, 0,
                    NULL, @AHORA, @USUARIO, GETDATE())
    END

    /* ---- 4. El traslado: su otra mitad ----
       El movimiento de ingreso en destino se genera aca, no lo manda quien
       llama. Si dependiera de dos llamadas, una caida entre las dos dejaria
       el repuesto sin existir en ninguna de las dos bodegas. */
    IF (@TIPO = 6)
    BEGIN
        INSERT INTO [dbo].[Inventario_Movimiento]
            (imo_uuid, imo_cliente, imo_repuesto, imo_bodega, imo_bodega_ubicacion,
             imo_repuesto_lote, imo_inventario_movimiento_tipo, imo_cantidad,
             imo_costo_unitario, imo_moneda, imo_fecha_movimiento_utc, imo_observacion,
             imo_usuario_creacion, imo_fecha_creacion)
        VALUES (NEWID(), @CLIENTE, @REPUESTO, @BODEGA_DESTINO, @UBICACION_DESTINO, @LOTE,
                7, @CANTIDAD, @COSTO_UNITARIO, @MONEDA, @AHORA,
                ISNULL(@OBSERVACION, N'') + N' (traslado desde el movimiento ' + LTRIM(STR(@ID)) + N')',
                @USUARIO, GETDATE())

        IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                    WHERE isa_cliente  = @CLIENTE
                      AND isa_repuesto = @REPUESTO
                      AND isa_bodega   = @BODEGA_DESTINO
                      AND ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
                      AND ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1))
            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + @CANTIDAD
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = GETDATE()
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA_DESTINO
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        ELSE
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA_DESTINO, @UBICACION_DESTINO, @LOTE,
                    @CANTIDAD, 0, @COSTO_UNITARIO, @AHORA, @USUARIO, GETDATE())
    END

    /* ---- 5. La orden de trabajo ----

       Consumo suma a lo consumido. Devolucion suma a lo devuelto Y resta de
       lo consumido, que es literalmente lo que pide el criterio: "la
       cantidad consumida de la orden se reduce en la misma cifra".

       No baja de cero: devolver mas de lo que se llevo es un error de
       digitacion, y dejar un consumo negativo contaminaria el costo de la
       intervencion. */
    IF (@ORDEN_TRABAJO IS NOT NULL AND @TIPO IN (2, 3))
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Repuesto]
                        WHERE ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO)
            INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
                (ore_orden_trabajo, ore_repuesto, ore_cantidad_planificada,
                 ore_cantidad_consumida, ore_cantidad_devuelta,
                 ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
            VALUES (@ORDEN_TRABAJO, @REPUESTO, 0, 0, 0, @USUARIO, GETDATE(), 1)

        UPDATE  [dbo].[Orden_Trabajo_Repuesto]
        SET     ore_cantidad_consumida = CASE
                    WHEN @TIPO = 2 THEN ISNULL(ore_cantidad_consumida, 0) + @CANTIDAD
                    WHEN @TIPO = 3 THEN CASE WHEN ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD < 0
                                             THEN 0
                                             ELSE ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD END
                    ELSE ore_cantidad_consumida END
               ,ore_cantidad_devuelta = CASE
                    WHEN @TIPO = 3 THEN ISNULL(ore_cantidad_devuelta, 0) + @CANTIDAD
                    ELSE ore_cantidad_devuelta END
               ,ore_usuario_actualizacion = @USUARIO
               ,ore_fecha_actualizacion   = GETDATE()
        WHERE   ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO
    END

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Movimiento registrado.' [MENSAJE]
RETURN 0
GO

PRINT '90_REUBICACION_SIN_ORIGEN aplicado: la reubicacion acepta origen sin estante.'
GO
