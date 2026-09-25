USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     REGISTRAR UNA LECTURA DESDE LA WEB.
-- =============================================
-- POR QUE HACIA FALTA LA PANTALLA
--   Las mediciones y las lecturas de contador solo entraban por la app
--   -API_INS_ACTIVO_MEDICION y API_INS_ACTIVO_MEDIDOR_LECTURA-. El planificador
--   que recibe un valor por telefono o por correo no tenia donde anotarlo: la
--   variable quedaba "sin lectura" hasta que alguien pasara por la maquina.
--
--   Los permisos ya existian -99 REGISTRAR LECTURA y 100 REGISTRAR MEDICION-:
--   lo unico que faltaba era una pantalla, y en SIGMA una pantalla existe
--   cuando tiene su fila en Menus.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @PADRE INT, @ID INT

SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_id = 2123   -- Activos

IF @PADRE IS NULL
BEGIN
    RAISERROR('NO EXISTE EL MENU PADRE DE ACTIVOS.', 16, 1)
    RETURN
END

SELECT @ID = mnu_id
  FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Activos/Ficha/RegistrarLectura.aspx'

IF @ID IS NULL
BEGIN
    /* Cuelga del Centro del activo, que es desde donde se abre, y va oculta:
       es un modal, no una entrada del menu lateral. */
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Registrar lectura',
         'Registro manual de una medicion de condicion o de una lectura de contador.',
         3, @PADRE,
         (SELECT ISNULL(MAX(mnu_orden), 0) + 1 FROM [dbo].[Menus] WHERE mnu_padre = @PADRE),
         '~/View/Activos/Ficha/RegistrarLectura.aspx',
         0, 'mdi-gauge', 100, 1)

    SELECT @ID = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Ficha/RegistrarLectura.aspx'

    PRINT '--- Menu "Registrar lectura" creado.'
END
ELSE
BEGIN
    /* Nunca se borra un menu: se corrige. Borrarlo dejaria sin pantalla a
       quien ya la tenia asignada en su perfil. */
    UPDATE [dbo].[Menus]
       SET mnu_permiso = 100,
           mnu_visible = 0,
           mnu_padre   = @PADRE
     WHERE mnu_id = @ID

    PRINT '--- Menu "Registrar lectura" ya existia: corregido.'
END
GO

PRINT '278_MENU_REGISTRAR_LECTURA aplicado.'
GO
