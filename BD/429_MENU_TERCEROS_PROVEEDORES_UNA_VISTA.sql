/* ============================================================================
   SIGMA — Bloque 429
   PROVEEDORES EN UNA SOLA VISTA
   ----------------------------------------------------------------------------

   El Maestro de proveedores y el Historial de servicios eran dos pantallas
   sueltas bajo la carpeta «Proveedores» de Terceros. Como se hizo en Activos
   y en Mantenimiento, se unifican en UNA pantalla con pestañas
   (View/Terceros/Proveedores/Proveedores.aspx): «Maestro de proveedores» e
   «Historial de servicios». Así Terceros queda con un solo ítem «Proveedores»
   (y, aparte, «Permisos de trabajo»).

   Queda:
     Terceros
       Proveedores            -> Proveedores.aspx   (las dos pestañas)
       Permisos de trabajo    (carpeta, sin cambios)

   NADA SE BORRA, SE ESCONDE
     Una pantalla existe porque tiene fila en Menus: borrarla le quitaría el
     permiso a quien entre por una alerta o por un enlace guardado. La carpeta
     «Proveedores» deja de ser contenedor (mnu_link '#') y pasa a enlazar
     directo la vista unificada; el renderer, al ver un link distinto de '#',
     la muestra como ítem y no recorre sus hijos. Las dos pantallas que eran
     ítems se dejan con mnu_visible = 0: siguen resolviendo su permiso por el
     link y los enlaces guardados a ProveedorHistorial.aspx siguen abriendo.

   Idempotente: se reconoce por el nombre de la carpeta y por el link de cada
   fila.
   ============================================================================ */
DECLARE @TERCEROS INT, @PROV INT
SELECT @TERCEROS = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Terceros' AND mnu_nivel = 2
SELECT @PROV = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_nivel = 3 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Proveedores'

/* ---- la carpeta «Proveedores» pasa a ser el enlace directo a la vista ---- */
UPDATE [dbo].[Menus]
   SET mnu_link = N'~/View/Terceros/Proveedores/Proveedores.aspx',
       mnu_descripcion = N'El maestro de contratistas y proveedores de repuestos, y el historial de lo que se les ha contratado',
       mnu_icon = N'mdi mdi-domain'
 WHERE mnu_id = @PROV

/* ---- las dos pantallas pasan a ser pestañas: se ocultan, no se borran ---- */
UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link = N'~/View/Terceros/Proveedores/Proveedores.aspx' AND mnu_id <> @PROV   -- era «Maestro de proveedores»
UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link = N'~/View/Terceros/Proveedores/ProveedorHistorial.aspx'                -- era «Historial de servicios»
/* Proveedor.aspx (detalle/modal) ya estaba oculto. */

PRINT '--- Terceros: Proveedores unificado en una sola vista con pestañas (bloque 429).'
GO
