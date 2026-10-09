SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 396 · «Biblioteca» pasa a llamarse «Procedimientos y pautas» en el menú Mantenimiento · 09-10-2026
   Describe lo que hay adentro (procedimientos, pautas de inspección, calendarios y ajustes).
   La URL y el rótulo «Recursos» no cambian. Idempotente. */
UPDATE [dbo].[Menus]
   SET mnu_nombre = N'Procedimientos y pautas',
       mnu_descripcion = N'Cómo se hace el trabajo y qué se revisa: procedimientos, pautas de inspección, calendarios compartidos y ajustes.'
 WHERE mnu_padre = 2154 AND mnu_link = N'~/View/Mantenimiento/Biblioteca/Biblioteca.aspx'
GO
PRINT '396_MENU_PROCEDIMIENTOS_PAUTAS aplicado.'
GO
