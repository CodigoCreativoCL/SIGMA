/* ============================================================================
   SIGMA - Bloque 327
   PICKING DE UNA ORDEN DE TRABAJO (mapa 3D de bodegas)
   ----------------------------------------------------------------------------

   Lo que una orden todavia tiene que sacar de bodega: lo planificado menos lo
   ya consumido, por repuesto. El mapa 3D lo usa para armar la ruta de picking
   y recorrerla en primera persona, rack por rack.

   EL PICKING NO TIENE TABLA PROPIA
     Cada retiro es una SALIDA POR CONSUMO (tipo 2) contra la orden, por
     INS_INVENTARIO_MOVIMIENTO: ese SP ya suma a ore_cantidad_consumida, valida
     el saldo del cubo, el lote y la compatibilidad con el equipo de la orden.
     Asi, lo que queda pendiente se lee siempre de la misma fuente y no hay un
     segundo registro que se desincronice.

   Se agrupa por repuesto porque una orden puede tener el mismo repuesto en dos
   lineas (por ejemplo, dos componentes del equipo): para la bodega es una sola
   cosa que buscar.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_PICKING]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT  r.rep_id                                                        AS REP_ID,
        r.rep_codigo                                                    AS REP_CODIGO,
        r.rep_nombre                                                    AS REP_NOMBRE,
        ISNULL(u.ume_simbolo, u.ume_nombre)                             AS UNIDAD,
        SUM(ISNULL(o.ore_cantidad_planificada, 0))                      AS PLANIFICADA,
        SUM(ISNULL(o.ore_cantidad_consumida, 0))                        AS CONSUMIDA,
        SUM(ISNULL(o.ore_cantidad_planificada, 0)) - SUM(ISNULL(o.ore_cantidad_consumida, 0)) AS PENDIENTE
FROM    [dbo].[Orden_Trabajo_Repuesto] o
JOIN    [dbo].[Repuesto] r          ON r.rep_id = o.ore_repuesto
LEFT JOIN [dbo].[Unidad_Medida] u   ON u.ume_id = r.rep_unidad_medida
WHERE   o.ore_orden_trabajo = @ORDEN
  AND   ISNULL(o.ore_habilitado, 1) = 1
GROUP BY r.rep_id, r.rep_codigo, r.rep_nombre, u.ume_simbolo, u.ume_nombre
HAVING  SUM(ISNULL(o.ore_cantidad_planificada, 0)) - SUM(ISNULL(o.ore_cantidad_consumida, 0)) > 0
ORDER BY r.rep_codigo
RETURN 0
GO
