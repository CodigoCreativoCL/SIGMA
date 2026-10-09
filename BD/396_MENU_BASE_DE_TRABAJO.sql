SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 396 · «Biblioteca» pasa a llamarse «Base de trabajo» en el menú Mantenimiento · 09-10-2026
   El material con que se arman planes, inspecciones y tareas (procedimientos, pautas de inspección, calendarios y ajustes).
   La URL y el rótulo «Recursos» no cambian. Idempotente. */
UPDATE [dbo].[Menus]
   SET mnu_nombre = N'Base de trabajo',
       mnu_descripcion = N'El material con que se arman planes, inspecciones y tareas: procedimientos, pautas de inspección, calendarios compartidos y ajustes.'
 WHERE mnu_padre = 2154 AND mnu_link = N'~/View/Mantenimiento/Biblioteca/Biblioteca.aspx'
GO
PRINT '396_MENU_BASE_DE_TRABAJO aplicado.'
GO
