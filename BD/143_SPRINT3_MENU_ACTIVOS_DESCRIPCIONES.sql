USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - DESCRIPCIONES CLARAS DE LOS CATALOGOS DE ACTIVOS.
-- =============================================
-- Se conservan los nombres GENERICOS (SIGMA es un formato base multi-industria:
-- sirve para plantas, hoteles, etc.), pero se agrega una descripcion clara en
-- cada item del menu "Configuracion de activos" para que se entienda sin jerga.
-- Idempotente.
-- =============================================

SET NOCOUNT ON
GO

UPDATE [dbo].[Menus] SET mnu_descripcion = N'Las clases o categorias con que agrupas los equipos (motor, caldera, ascensor, camara de frio...).'
WHERE  mnu_nombre = N'Tipos de activo';

UPDATE [dbo].[Menus] SET mnu_descripcion = N'El fabricante y modelo de cada tipo de equipo (marca + modelo); se reutiliza en los activos iguales.'
WHERE  mnu_nombre = N'Modelos de activo';

UPDATE [dbo].[Menus] SET mnu_descripcion = N'Los datos tecnicos que describen cada tipo de equipo (potencia, voltaje, capacidad...).'
WHERE  mnu_nombre = N'Atributos técnicos';

UPDATE [dbo].[Menus] SET mnu_descripcion = N'Catalogos base: clases de equipo, sus modelos y sus datos tecnicos. Se definen una vez y se reutilizan.'
WHERE  mnu_nombre = N'Configuración de activos';

PRINT '143_SPRINT3_MENU_ACTIVOS_DESCRIPCIONES aplicado.';
GO

SELECT mnu_nombre, mnu_descripcion FROM [dbo].[Menus]
WHERE  mnu_nombre IN (N'Tipos de activo', N'Modelos de activo', N'Atributos técnicos', N'Configuración de activos');
GO
