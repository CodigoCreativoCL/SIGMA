/* ============================================================================
   SIGMA — Bloque 459
   MENÚ COMERCIAL CENTRALIZADO EN EL CENTRO COMERCIAL
   ----------------------------------------------------------------------------
   El grupo «Comercial» del sidebar queda con un solo ítem: Centro Comercial.
   Reasignaciones, Clientes, Planes, Suscripción, Períodos y Pagos dejan de
   verse en el menú y se abren desde el Centro (pestaña Clientes ›
   Administración, y la ficha del cliente concretado).

   NO SE BORRA NADA: mnu_visible = 0. Las filas siguen en Menus con su permiso,
   así Token.ExigirPagina sigue autorizando esas páginas por su mnu_link.
   Para volver atrás: mnu_visible = 1 en los mismos ids.
   ============================================================================ */
SET NOCOUNT ON
UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link IN (N'~/View/Comercial/Clientes/ReasignacionesClientes.aspx',
                    N'~/View/Comercial/Clientes/Clientes.aspx',
                    N'~/View/Comercial/Suscripciones/Planes.aspx',
                    N'~/View/Comercial/Suscripciones/Suscripciones.aspx',
                    N'~/View/Comercial/Suscripciones/Periodos.aspx',
                    N'~/View/Comercial/Suscripciones/Pagos.aspx')
PRINT CAST(@@ROWCOUNT AS VARCHAR(5)) + ' menús comerciales ocultos (bloque 459).'
GO
