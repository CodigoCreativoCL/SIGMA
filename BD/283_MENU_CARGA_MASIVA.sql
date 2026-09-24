USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     REGISTRA LA PANTALLA DE CARGA MASIVA DE ACTIVOS.
-- =============================================
-- POR QUE
--   Un cliente que parte con SIGMA llega con su catalogo en una planilla:
--   doscientos equipos. Cargarlos de a uno por la ficha son doscientas
--   aperturas de modal, y es lo primero que hay que hacer para que el resto
--   del sistema sirva de algo.
--
--   No lleva permiso propio: crear cien activos de una vez es crear activos.
--   Quien puede lo uno puede lo otro, y un permiso mas es una casilla mas que
--   alguien olvida marcar.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @PADRE INT, @ID INT, @PERMISO INT

SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_id = 2123   -- Activos

IF @PADRE IS NULL
BEGIN
    RAISERROR('NO EXISTE EL MENU PADRE DE ACTIVOS.', 16, 1)
    RETURN
END

SELECT @PERMISO = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR ACTIVOS'

IF @PERMISO IS NULL
BEGIN
    RAISERROR('NO EXISTE EL PERMISO CREAR EDITAR ACTIVOS.', 16, 1)
    RETURN
END

SELECT @ID = mnu_id
  FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Activos/Ficha/CargaMasivaActivos.aspx'

IF @ID IS NULL
BEGIN
    /* Oculta: es un modal que se abre desde la lista del centro, no una
       entrada del menu lateral. */
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Carga masiva de activos',
         'Alta de varios activos desde una planilla, con vista previa antes de escribir.',
         3, @PADRE,
         (SELECT ISNULL(MAX(mnu_orden), 0) + 1 FROM [dbo].[Menus] WHERE mnu_padre = @PADRE),
         '~/View/Activos/Ficha/CargaMasivaActivos.aspx',
         0, 'mdi-upload-outline', @PERMISO, 1)

    PRINT '--- Menu "Carga masiva de activos" creado.'
END
ELSE
BEGIN
    UPDATE [dbo].[Menus]
       SET mnu_permiso = @PERMISO,
           mnu_visible = 0,
           mnu_padre   = @PADRE
     WHERE mnu_id = @ID

    PRINT '--- Menu "Carga masiva de activos" ya existia: corregido.'
END
GO

PRINT '283_MENU_CARGA_MASIVA aplicado.'
GO
