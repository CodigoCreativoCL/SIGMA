USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     REGISTRA EL MODAL «CLASIFICAR REPUESTOS» (ClasificarRepuestos.aspx).
-- =============================================
-- POR QUE
--   Antes «Clasificar varios» abria el listado clasico (Repuestos.aspx, con el
--   menu y el encabezado del sitio) dentro de un modal. Ahora es un modal
--   simple: marcar, elegir el tipo y asignar.
--
--   Oculta: se abre desde el Centro de repuestos, no es entrada del menu.
--   Mismo permiso que clasificar siempre: CREAR EDITAR REPUESTOS.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @PADRE INT, @PERMISO INT, @AMBITO INT, @ID INT

SELECT TOP 1 @PADRE = mnu_padre, @AMBITO = mnu_ambito
  FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Repuestos/RepuestoTipo.aspx'

IF @PADRE IS NULL
BEGIN
    RAISERROR('NO SE ENCONTRO EL MENU PADRE DE REPUESTOS (RepuestoTipo.aspx).', 16, 1)
    RETURN
END

SELECT @PERMISO = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR REPUESTOS'

IF @PERMISO IS NULL
BEGIN
    RAISERROR('NO EXISTE EL PERMISO CREAR EDITAR REPUESTOS.', 16, 1)
    RETURN
END

SELECT @ID = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Inventario/Repuestos/ClasificarRepuestos.aspx'

IF @ID IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Clasificar repuestos',
         'Asigna un tipo a varios repuestos de una vez.',
         4, @PADRE, 99,
         '~/View/Inventario/Repuestos/ClasificarRepuestos.aspx',
         0, 'mdi mdi-tag-multiple-outline', @PERMISO, @AMBITO)

    PRINT '--- Menu "Clasificar repuestos" creado.'
END
ELSE
BEGIN
    UPDATE [dbo].[Menus]
       SET mnu_permiso = @PERMISO, mnu_visible = 0, mnu_padre = @PADRE
     WHERE mnu_id = @ID

    PRINT '--- Menu "Clasificar repuestos" ya existia: corregido.'
END
GO

PRINT '370_MENU_CLASIFICAR_REPUESTOS aplicado.'
GO
