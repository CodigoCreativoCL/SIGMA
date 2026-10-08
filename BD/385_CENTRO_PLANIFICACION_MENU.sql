/* ============================================================================
   385 · Centro de Planificación · menú (08-10-2026)

   «Planificación» (2222) pasa a llamarse Centro de Planificación. Programaciones
   (2155) y Procedimientos (2161) dejan de ser entradas del menú: viven en la
   Biblioteca del Centro (con sus permisos 92 y 97). Los menús nunca se borran:
   mnu_visible = 0. El permiso de entrada al Centro sigue siendo el 116.
   ============================================================================ */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Centro de Planificación', mnu_descripcion = N'Centro de Planificación' WHERE mnu_id = 2222
UPDATE [dbo].[Menus] SET mnu_visible = 0 WHERE mnu_id IN (2155, 2161)
GO
PRINT '385_CENTRO_PLANIFICACION_MENU aplicado.'
GO
