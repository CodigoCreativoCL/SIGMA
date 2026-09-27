USE [db_acd593_sigma]
GO
SET NOCOUNT ON
GO
-- Programaciones (2155) deja de colgar de Planificación (2222) y pasa a ser
-- su hermana dentro de Centro de Mantenimiento (2154).
--
-- Por qué: desde BD/296 Planificación es una PÁGINA, no una carpeta, y
-- MenusLateral.ascx.cs no sabe dibujar una página con hijos visibles (los
-- agrega sin su <ul>): Programaciones salía como ítem huérfano con otra
-- sangría. Además, a quien solo tiene VER PROGRAMACIONES (92) no se le
-- muestra Planificación (116), así que la hija tampoco le quedaba a la vista.
-- Como hermana se dibuja bien y conserva el acceso con el permiso 92.
-- Permiso y visibilidad no cambian.

UPDATE [dbo].[Menus] SET mnu_padre = 2154, mnu_orden = 2 WHERE mnu_id = 2155
UPDATE [dbo].[Menus] SET mnu_orden = 3 WHERE mnu_id = 2161   -- Procedimientos corre un lugar
GO

SELECT mnu_id, mnu_padre, mnu_nombre, mnu_orden, mnu_visible, mnu_permiso
  FROM [dbo].[Menus] WHERE mnu_padre = 2154 AND mnu_visible = 1 ORDER BY mnu_orden
GO
