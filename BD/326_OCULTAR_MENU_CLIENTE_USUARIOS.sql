USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           04-10-2026
-- DESCRIPTION:     Oculta la pantalla "Usuarios" por cliente
--                  (~/View/Clientes/Cliente/Usuarios.aspx): la selección de
--                  cliente se hace desde la barra superior, así que esa vista
--                  con su propio selector ya no es necesaria.
--                  Los menús no se borran: se deja mnu_visible = 0. Idempotente.
-- =============================================
SET NOCOUNT ON
GO

UPDATE [dbo].[Menus]
   SET mnu_visible = 0
 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Clientes/Cliente/Usuarios.aspx'
   AND mnu_visible = 1
GO

SELECT mnu_id, mnu_nombre, mnu_link, mnu_visible
FROM   [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Clientes/Cliente/Usuarios.aspx'
GO

PRINT '326_OCULTAR_MENU_CLIENTE_USUARIOS aplicado.'
GO
