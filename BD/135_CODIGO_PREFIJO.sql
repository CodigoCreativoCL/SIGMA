/* ============================================================================
   SIGMA - Bloque 135
   EL PREFIJO DEL MODULO, PARA QUE LA PANTALLA LO MUESTRE
   ----------------------------------------------------------------------------

   QUE CAMBIA

     Hasta ahora el codigo se generaba entero: la ficha mandaba 'AUTO' y el SP
     lo reemplazaba por <PREFIJO>-<id>. Quedaba ARE-7, y el 7 no le dice nada
     a nadie en terreno.

     Ahora el prefijo se muestra fijo en pantalla -"ARE-"- y al lado hay un
     campo donde la persona escribe lo que quiera: ARE-CALDERAS,
     ARE-PISO2-NORTE. El sistema pone la parte que garantiza de que modulo es;
     el cliente pone la parte que le sirve para reconocerlo.

   POR QUE UN PROCEDIMIENTO Y NO UNA CONSTANTE EN EL CODIGO

     Los prefijos ya viven en `Modulo_Codigo`, que es la tabla que usa
     `FNC_CODIGO_AUTOMATICO`. Si la pantalla los escribiera a mano, habria dos
     fuentes para el mismo dato y bastaria cambiar uno para que la etiqueta
     dijera una cosa y lo guardado otra.

     Leyendolo de la misma tabla, cambiar un prefijo es un UPDATE y ninguna
     pantalla se entera.

   SI NO SE PUEDE GENERAR, NO SE INVENTA

     Un modulo sin fila -o deshabilitado- devuelve vacio. La pantalla que
     recibe vacio simplemente no muestra el prefijo y deja escribir el codigo
     completo, que es como funcionaba antes de todo esto.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_MODULO_CODIGO]
    @TABLA VARCHAR(128) = NULL
AS
SET NOCOUNT ON

SELECT  mco_tabla          AS TABLA,
        mco_prefijo        AS PREFIJO,
        mco_columna_codigo AS COLUMNA_CODIGO,
        mco_columna_id     AS COLUMNA_ID
FROM    [dbo].[Modulo_Codigo]
WHERE   mco_habilitado = 1
  AND  (@TABLA IS NULL OR mco_tabla = @TABLA)
ORDER BY mco_tabla
GO

PRINT '--- SEL_MODULO_CODIGO creado.'
GO

/* --------------------------------------------------------------- comprobacion */
EXEC [dbo].[SEL_MODULO_CODIGO] @TABLA = 'Instalacion_Area'
EXEC [dbo].[SEL_MODULO_CODIGO]
GO

PRINT '135_CODIGO_PREFIJO aplicado.'
GO
