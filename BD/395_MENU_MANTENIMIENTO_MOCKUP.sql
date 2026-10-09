SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   395 · Menú Mantenimiento como el mockup · 09-10-2026  (ajuste de la parte a)

   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html
   Orden: Planificación · Operación · Órdenes de trabajo · Avisos (contador rojo)
          y, bajo el rótulo «Recursos», Biblioteca.

   - Menus.mnu_separador: rótulo que el sidebar dibuja ANTES de esa opción
     (genérico: cualquier opción de nivel 3 puede abrir un grupo con título).
   - SEL_MENUS_SIDEBAR devuelve también el separador.
   - mnu_contador = 'avisos' en Avisos. La parte b agrega AVISOS a SEL_MENU_CONTADORES (hasta
     entonces no se muestra, sobre VW_AVISOS).
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO
IF COL_LENGTH('dbo.Menus', 'mnu_separador') IS NULL ALTER TABLE [dbo].[Menus] ADD mnu_separador NVARCHAR(40) NULL
GO
UPDATE [dbo].[Menus] SET mnu_orden = 1 WHERE mnu_id = 2222
UPDATE [dbo].[Menus] SET mnu_orden = 2 WHERE mnu_padre = 2154 AND mnu_link = N'~/View/Mantenimiento/Operacion/Operacion.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 3 WHERE mnu_id = 2224
UPDATE [dbo].[Menus] SET mnu_orden = 4, mnu_contador = N'avisos' WHERE mnu_padre = 2154 AND mnu_link = N'~/View/Mantenimiento/Avisos/Avisos.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 5, mnu_separador = N'Recursos' WHERE mnu_padre = 2154 AND mnu_link = N'~/View/Mantenimiento/Biblioteca/Biblioteca.aspx'
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS_SIDEBAR]
AS
SET NOCOUNT ON
SELECT mnu_id AS ID, mnu_grupo AS GRUPO, mnu_nombre_corto AS CORTO, mnu_contador AS CONTADOR, mnu_separador AS SEPARADOR
FROM   [dbo].[Menus]
WHERE  mnu_grupo IS NOT NULL OR mnu_nombre_corto IS NOT NULL OR mnu_contador IS NOT NULL OR mnu_separador IS NOT NULL
GO
PRINT '395_MENU_MANTENIMIENTO_MOCKUP aplicado.'
GO
