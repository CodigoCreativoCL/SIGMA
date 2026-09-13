USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     MENU DE LA CARGA MASIVA DE PLANES DE MANTENIMIENTO COMPLETOS.
-- =============================================
-- La carga masiva es un modal sobre el listado de planes (patron de
-- CargaMasivaRepuestos). Como toda pagina, necesita su fila en Menus para
-- abrirse; va con orden 99 e invisible. Sin SP nuevo: la carga reusa
-- INS_PLAN_MANTENIMIENTO, INS_PLAN_HITO e INS_PLAN_ACTIVO fila por fila.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @VER   INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PLANES MANTENIMIENTO')
DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')

IF (@VER IS NULL OR @PADRE IS NULL)
BEGIN
    RAISERROR('CORRA BD/212 ANTES QUE ESTE.', 16, 1)
    RETURN
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/CargaMasivaPlanes.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Carga masiva de planes', 'Planes completos (plan, hitos y equipos) desde una planilla',
         3, @PADRE, 99,
         '~/View/Mantenimiento/Planes/CargaMasivaPlanes.aspx', 0, '', @VER, 1)
GO

SELECT 'Menu = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/CargaMasivaPlanes.aspx') AS VARCHAR) + ' de 1' AS RESULTADO
GO
