SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 399 · «Órdenes de trabajo» abre la lista y la ficha nuevas · 09-10-2026  (parte c)
   El menú apunta a Ordenes/Ordenes.aspx. OrdenTrabajos.aspx y OrdenTrabajo.aspx siguen existiendo:
   redirigen al lugar nuevo y «?legacy=1» abre la ficha completa de antes. Idempotente. */
UPDATE [dbo].[Menus] SET mnu_link = N'~/View/Mantenimiento/Ordenes/Ordenes.aspx' WHERE mnu_id = 2224
GO
PRINT '399_MENU_ORDENES aplicado.'
GO
