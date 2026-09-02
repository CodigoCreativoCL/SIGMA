/* ============================================================================
   SIGMA — Bloque 87
   DE DONDE SALE LO QUE SALE
   ----------------------------------------------------------------------------

   EL SINTOMA

     La pantalla de movimiento decia "Existencia actual: 340,00 L" y al
     registrar la entrega respondia:

       13.- EXISTENCIA INSUFICIENTE EN ESA UBICACION: HAY 0.00 Y SE INTENTA
            SACAR 340.00.

     Las dos cosas eran ciertas al mismo tiempo, y por eso el mensaje parecia
     un error del sistema cuando no lo era.

   POR QUE PASABA

     Desde el bloque 71 la existencia se guarda por CUBO:

       (cliente, repuesto, bodega, ubicacion, lote)

     Las 340 L de DEMO-ACEITE-68 viven en el cubo (Bodega Central, ZONA-LIQ,
     lote 7). El bodeguero eligio la ubicacion PA-E1-N1 y no eligio lote
     —el formulario ni siquiera se lo ofrecia en una salida—, asi que
     INS_INVENTARIO_MOVIMIENTO fue a buscar el cubo (PA-E1-N1, sin lote), que
     efectivamente tiene 0.

     El SP hizo lo correcto. Lo que mentia era la pantalla: mostraba el total
     de la BODEGA junto al combo de bodega, y despues validaba contra un CUBO.
     Un numero que no es el que se va a validar es peor que no mostrar
     ninguno, porque invita a confiar en el.

   LO QUE HACE ESTE BLOQUE

     Un solo SP que devuelve los cubos con existencia de un repuesto en una
     bodega. Con eso la pantalla puede ofrecer SOLO los lugares de donde
     realmente se puede sacar, con la cantidad al lado, en vez de ofrecer las
     seis ubicaciones de la bodega y dejar que el bodeguero adivine.

     Y un SP para el combo de ordenes de trabajo, que hasta ahora era una
     caja de texto donde se escribia un numero a mano.

   ORDEN: despues de 86_SEVERIDAD_QUIEBRE.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_INVENTARIO_ORIGEN
      Los cubos con existencia de un repuesto en una bodega.

      Se devuelven TAMBIEN los de cantidad cero cuando @SOLO_CON_SALDO = 0,
      porque al INGRESAR mercaderia hay que poder elegir un estante vacio:
      es justamente el caso normal.

      Al SACAR se piden solo los que tienen algo. Ofrecer un estante vacio
      en una salida es ofrecer un camino que el SP va a rechazar.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_INVENTARIO_ORIGEN') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_INVENTARIO_ORIGEN]
GO

CREATE PROCEDURE [dbo].[SEL_INVENTARIO_ORIGEN]
    @CLIENTE         INT,
    @REPUESTO        INT,
    @BODEGA          INT,
    @SOLO_CON_SALDO  BIT = 1
AS
SET NOCOUNT ON

    SELECT  s.isa_bodega_ubicacion                              AS UBICACION_ID,
            ISNULL(ub.bub_codigo, '')                           AS UBICACION_CODIGO,
            ISNULL(ub.bub_nombre, '')                           AS UBICACION_NOMBRE,
            s.isa_repuesto_lote                                 AS LOTE_ID,
            ISNULL(lo.rlo_codigo, '')                           AS LOTE_CODIGO,
            lo.rlo_fecha_vencimiento                            AS LOTE_VENCE,
            CAST(CASE WHEN lo.rlo_fecha_vencimiento IS NOT NULL
                       AND lo.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE)
                      THEN 1 ELSE 0 END AS BIT)                 AS LOTE_VENCIDO,
            s.isa_cantidad                                      AS CANTIDAD,
            ISNULL(ume.ume_simbolo, '')                         AS UNIDAD
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r
            ON  r.rep_id = s.isa_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume
            ON  ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub
            ON  ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] lo
            ON  lo.rlo_id = s.isa_repuesto_lote
    WHERE   s.isa_cliente  = @CLIENTE
      AND   s.isa_repuesto = @REPUESTO
      AND   s.isa_bodega   = @BODEGA
      AND   (@SOLO_CON_SALDO = 0 OR s.isa_cantidad > 0)
    /* El lote que vence primero, primero: es el que hay que consumir antes.
       Dentro de la misma fecha, el estante en orden alfabetico. */
    ORDER BY CASE WHEN lo.rlo_fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
             lo.rlo_fecha_vencimiento,
             ub.bub_codigo,
             s.isa_repuesto_lote
GO

PRINT '--- SEL_INVENTARIO_ORIGEN creado.'
GO


/* ========================================================================
   2. SEL_ORDEN_TRABAJO_COMBO
      Las ordenes a las que se le puede cargar consumo.

      Solo las que siguen abiertas (estados 1, 2 y 3). Cargarle repuestos a
      una orden CERRADA cambia un costo que alguien ya reporto como final,
      asi que no se ofrece.

      Hoy la tabla esta vacia —el modulo de ordenes es de otro sprint— y
      este SP devuelve cero filas. Es correcto que asi sea: es mejor un combo
      que dice "no hay ordenes abiertas" que una caja de texto donde se
      escribe un numero que nadie verifico hasta el final del formulario.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ORDEN_TRABAJO_COMBO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_COMBO]
GO

CREATE PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_COMBO]
    @CLIENTE INT,
    @ACTIVO  INT = NULL
AS
SET NOCOUNT ON

    SELECT  o.otr_id                                            AS ORDEN_ID,
            o.otr_correlativo                                   AS CORRELATIVO,
            ISNULL(o.otr_titulo, '')                            AS TITULO,
            ISNULL(es.ote_nombre, '')                           AS ESTADO,
            ISNULL(a.act_codigo, '')                            AS ACTIVO_CODIGO,
            ISNULL(a.act_nombre, '')                            AS ACTIVO_NOMBRE,
            o.otr_fecha_programada_utc                          AS FECHA_PROGRAMADA
    FROM    [dbo].[Orden_Trabajo] o
    LEFT JOIN [dbo].[Orden_Trabajo_Estado] es
            ON  es.ote_id = o.otr_orden_trabajo_estado
    LEFT JOIN [dbo].[Activo] a
            ON  a.act_id = o.otr_activo
    WHERE   o.otr_cliente = @CLIENTE
      AND   o.otr_orden_trabajo_estado IN (1, 2, 3)
      AND   (@ACTIVO IS NULL OR o.otr_activo = @ACTIVO)
    ORDER BY o.otr_correlativo DESC
GO

PRINT '--- SEL_ORDEN_TRABAJO_COMBO creado.'
GO


/* ========================================================================
   3. CONTROL: existencia atrapada

      Al reconstruir los saldos por ubicacion (bloque 71) quedaron filas con
      isa_bodega_ubicacion NULL en bodegas que SI tienen ubicaciones. Como
      ahora la ubicacion es obligatoria en esas bodegas (error 15), esa
      existencia no se puede sacar por ningun camino: esta atrapada.

      No se corrige sola desde aca a proposito. Mover ese saldo a un estante
      sin que nadie haya ido a mirar seria inventar un dato fisico. Lo que
      corresponde es un ajuste hecho por el bodeguero, que es el que sabe
      donde esta realmente la pieza.

      Este SELECT lo deja a la vista para que alguien lo resuelva.
   ======================================================================== */
SELECT  r.rep_codigo    AS REPUESTO,
        b.bod_nombre    AS BODEGA,
        s.isa_cantidad  AS CANTIDAD_ATRAPADA
FROM    [dbo].[Inventario_Saldo] s
JOIN    [dbo].[Repuesto] r ON r.rep_id  = s.isa_repuesto
JOIN    [dbo].[Bodega]   b ON b.bod_id  = s.isa_bodega
WHERE   s.isa_bodega_ubicacion IS NULL
  AND   s.isa_cantidad <> 0
  AND   EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u
                WHERE u.bub_bodega = s.isa_bodega AND u.bub_habilitado = 1)
GO


PRINT '87_MOVIMIENTO_ORIGEN aplicado: SEL_INVENTARIO_ORIGEN y SEL_ORDEN_TRABAJO_COMBO.'
GO
