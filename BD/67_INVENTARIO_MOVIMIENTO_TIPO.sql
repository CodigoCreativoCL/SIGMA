/* ============================================================================
   SIGMA — Bloque 67
   EL CATALOGO DE TIPOS DE MOVIMIENTO, PARA LOS FILTROS
   ----------------------------------------------------------------------------

   El filtro de la pantalla de Movimientos necesita ofrecer los tipos. Las
   dos formas de resolverlo eran:

     a) escribir los ocho <rad:RadComboBoxItem> a mano en el .aspx;
     b) leerlos de la tabla.

   Se hace (b). Un catalogo escrito en el markup es una copia que nadie
   recuerda actualizar: el dia que se agregue un tipo o se deshabilite uno,
   la base y la pantalla dicen cosas distintas, y el filtro devuelve vacio
   sin explicar por que. CONVENCIONES.md ya lo dice para los catalogos del
   sistema; esto es lo mismo.

   Devuelve tambien la FAMILIA, que es como se agrupan en la grilla —los
   ajustes se distinguen de los ingresos y de los consumos, HU-057 CA2— para
   que el combo pueda ordenarse igual que lo que se ve.
   ============================================================================ */

SET NOCOUNT ON
GO

IF OBJECT_ID('dbo.SEL_INVENTARIO_MOVIMIENTO_TIPO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO_TIPO]
GO

CREATE PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO_TIPO]
    @ID          INT = NULL,
    @HABILITADO  BIT = 1,
    @SIN_TRASLADO_INGRESO BIT = 0
AS
SET NOCOUNT ON

    SELECT  t.imt_id, t.imt_codigo, t.imt_nombre, t.imt_orden, t.imt_habilitado,
            CASE WHEN t.imt_id IN (1, 3, 4, 7) THEN 1 ELSE -1 END AS SIGNO,
            CASE WHEN t.imt_id IN (4, 5, 8) THEN 'AJUSTE'
                 WHEN t.imt_id IN (6, 7)    THEN 'TRASLADO'
                 WHEN t.imt_id = 2          THEN 'CONSUMO'
                 ELSE 'INGRESO' END AS FAMILIA
    FROM    [dbo].[Inventario_Movimiento_Tipo] t
    WHERE   (@ID IS NULL OR t.imt_id = @ID)
      AND   (@HABILITADO IS NULL OR t.imt_habilitado = @HABILITADO)
      /* El traslado de ingreso (7) no se elige nunca al REGISTRAR: lo genera
         el traslado de salida. Para FILTRAR si sirve, asi que la exclusion
         es opcional y la decide quien llama. */
      AND   (@SIN_TRASLADO_INGRESO = 0 OR t.imt_id <> 7)
    ORDER BY t.imt_orden, t.imt_nombre
GO


PRINT '--- Tipos de movimiento ---'
EXEC [dbo].[SEL_INVENTARIO_MOVIMIENTO_TIPO]
GO
