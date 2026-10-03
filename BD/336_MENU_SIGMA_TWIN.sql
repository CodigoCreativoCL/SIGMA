/* ============================================================================
   SIGMA - Bloque 336
   EL MAPA 3D SE LLAMA SIGMA TWIN
   ----------------------------------------------------------------------------
   "Mapa 3D de bodegas" describia la tecnica, no lo que es: una replica viva
   de la bodega -stock, racks, lotes, conteos, picking, historial- que se
   opera desde la propia escena. Eso es un gemelo digital, y el nombre de
   producto lo dice: SIGMA Twin. El enlace y el permiso no cambian.
   ============================================================================ */
SET NOCOUNT ON
UPDATE [dbo].[Menus]
SET    mnu_nombre = N'SIGMA Twin',
       mnu_descripcion = N'Gemelo digital de bodegas: el stock, los racks y los lotes en 3D, operados desde la escena.'
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Inventario/Bodegas/BodegaMapa3D.aspx'
SELECT mnu_id, mnu_nombre FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Inventario/Bodegas/BodegaMapa3D.aspx'
GO
