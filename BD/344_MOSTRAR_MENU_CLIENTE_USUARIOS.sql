USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           04-10-2026
-- DESCRIPTION:     Revierte BD/326: la pantalla "Usuarios" por cliente
--                  (~/View/Clientes/Cliente/Usuarios.aspx) vuelve a verse.
--                  Bryan la mantuvo usando el cliente de la barra superior
--                  (b993620) y BD/341 deja el flujo Cliente > Usuarios:
--                  primero Perfiles, luego Usuarios. Idempotente.
-- =============================================
SET NOCOUNT ON
GO

UPDATE [dbo].[Menus]
   SET mnu_visible = 1
 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Clientes/Cliente/Usuarios.aspx'
   AND mnu_visible = 0
GO

SELECT mnu_id, mnu_nombre, mnu_link, mnu_visible, mnu_orden
FROM   [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Clientes/Cliente/Usuarios.aspx'
GO

PRINT '344_MOSTRAR_MENU_CLIENTE_USUARIOS aplicado.'
GO
