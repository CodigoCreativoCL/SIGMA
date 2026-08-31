/* ============================================================================
   SIGMA — Bloque 66
   EL ORDEN DE UN MENU ES EL ORDEN EN QUE SE USA
   ----------------------------------------------------------------------------

   LA REGLA

     Los hijos de un nodo se ordenan por **lo que hay que hacer primero**,
     no alfabeticamente ni por importancia. Si B necesita que A exista, A va
     arriba.

     Un menu ordenado de otra forma le miente al que entra por primera vez:
     abre la primera opcion, la encuentra vacia, y no tiene como saber que
     lo que falta es haber pasado por otra pantalla.

   QUE ESTABA MAL

     Inventario abria con Repuestos. Pero un repuesto sin bodega no tiene
     donde existir: sus umbrales se definen POR BODEGA, y el primer ingreso
     pide una. Quien entraba veia el catalogo primero y chocaba con la
     bodega despues, al revez de como se arma.

       antes                    ahora
       1. Repuestos             1. Bodegas       <- no depende de nada
       2. Bodegas               2. Repuestos     <- sus umbrales piden bodega
       3. Existencias           3. Existencias   <- resultado de los dos
       4. Movimientos           4. Movimientos   <- el registro de lo que paso

   POR QUE EXISTENCIAS ANTES QUE MOVIMIENTOS

     Por dependencia estricta seria al reves: la existencia es la suma de
     los movimientos. Se deja Existencias antes porque es una CONSULTA y la
     otra es un REGISTRO: se mira cien veces por cada vez que se escribe.
     Cuando la dependencia y el uso apuntan distinto, entre dos pantallas
     que ya se pueden abrir, manda el uso.

   QUEDA ESCRITO
     En PATRONES/ASP/CHECKLIST_ENTIDAD_NUEVA.md §5, junto a la regla de
     Menu_Funcion.
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @RAIZ INT

SELECT @RAIZ = mnu_id
FROM   [dbo].[Menus]
WHERE  mnu_nombre COLLATE DATABASE_DEFAULT = 'Inventario' AND mnu_nivel = 2

IF (@RAIZ IS NULL)
BEGIN
    PRINT '--- No existe el nodo Inventario. Nada que reordenar.'
    RETURN
END

/* Se ordena por el link y no por el nombre: el nombre visible se puede
   editar desde el mantenedor de menus, el link no. */
UPDATE [dbo].[Menus] SET mnu_orden = 1
 WHERE mnu_padre = @RAIZ AND mnu_link = '~/View/Inventario/Bodegas/Bodegas.aspx'

UPDATE [dbo].[Menus] SET mnu_orden = 2
 WHERE mnu_padre = @RAIZ AND mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

UPDATE [dbo].[Menus] SET mnu_orden = 3
 WHERE mnu_padre = @RAIZ AND mnu_link = '~/View/Inventario/Existencias/Existencias.aspx'

UPDATE [dbo].[Menus] SET mnu_orden = 4
 WHERE mnu_padre = @RAIZ AND mnu_link = '~/View/Inventario/Movimientos/Movimientos.aspx'

PRINT '--- Inventario reordenado por dependencia'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  m.mnu_orden, m.mnu_nombre, m.mnu_visible, m.mnu_link
FROM    [dbo].[Menus] m
JOIN    [dbo].[Menus] p ON p.mnu_id = m.mnu_padre
WHERE   p.mnu_nombre COLLATE DATABASE_DEFAULT = 'Inventario'
ORDER BY m.mnu_orden, m.mnu_nombre
GO
