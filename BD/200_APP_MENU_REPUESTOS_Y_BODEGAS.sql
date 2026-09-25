USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LAS DOS PANTALLAS NUEVAS DE INVENTARIO EN EL MENU DE LA APP.
-- =============================================
-- REGISTRAR UNA PANTALLA ES UN INSERT, NO CODIGO
--
--   La app arma «Mas» desde GET /menus: una pantalla que no este en esta tabla
--   no aparece, aunque su codigo exista. Es a proposito -sin Paginas.cs- y es
--   lo que hace que revocar un permiso desde la web la esconda del telefono
--   sin recompilar nada.
--
-- LAS DOS VISTAS
--
--   app://repuestos  -> el CATALOGO, una fila por pieza. Vista 10.2 del v3.
--   app://bodegas    -> las bodegas y sus estantes. Vistas 10.5 a 10.8.
--
-- POR QUE EL CATALOGO NO ES LO MISMO QUE EXISTENCIAS
--
--   «Existencias de bodega» -que ya estaba- es una fila POR BODEGA y responde
--   «que esta bajo minimo»: es la pantalla del bodeguero que reparte. El
--   catalogo es una fila POR PIEZA y responde «existe esto en el sistema y con
--   que codigo»: la abre quien tiene un rodamiento en la mano y no sabe como
--   se llama aca. Son dos preguntas distintas, no dos vistas de lo mismo.
--
-- LOS PERMISOS NO SON LOS MISMOS PARA LAS DOS
--
--   El catalogo pide VER REPUESTOS, que tienen los cinco perfiles de terreno.
--   Las bodegas piden VER BODEGAS, que el tecnico NO tiene: un tecnico no
--   administra estantes, y ofrecerle una pantalla que le va a responder 403 es
--   justo lo que se saco de «Mas» esta misma sesion.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @PADRE INT = (SELECT TOP 1 mnu_padre FROM [dbo].[Menus]
                       WHERE mnu_link = 'app://existencias')

IF (@PADRE IS NULL)
BEGIN
    RAISERROR('1.- NO SE ENCONTRO EL NODO RAIZ DE LA APP.', 16, 1)
    RETURN
END

DECLARE @VER_REP INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER REPUESTOS')
DECLARE @VER_BOD INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER BODEGAS')

/* El orden: detras de «Existencias de bodega», que es la que ya conocen. */
DECLARE @ORDEN INT = ISNULL((SELECT MAX(ISNULL(mnu_orden, 0)) FROM [dbo].[Menus]
                              WHERE mnu_padre = @PADRE), 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://repuestos')
BEGIN
    SET @ORDEN = @ORDEN + 1

    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Catálogo de repuestos',
         'Todas las piezas, con su código y su saldo total',
         2, @PADRE, @ORDEN,
         'app://repuestos', 1, 'mdi mdi-package-variant-closed', @VER_REP, 2)
END
GO

DECLARE @PADRE INT = (SELECT TOP 1 mnu_padre FROM [dbo].[Menus]
                       WHERE mnu_link = 'app://existencias')
DECLARE @VER_BOD INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER BODEGAS')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(ISNULL(mnu_orden, 0)) FROM [dbo].[Menus]
                              WHERE mnu_padre = @PADRE), 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://bodegas')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Bodegas y estantes',
         'Dónde está cada cosa dentro de la planta',
         2, @PADRE, @ORDEN + 1,
         'app://bodegas', 1, 'mdi mdi-warehouse', @VER_BOD, 2)
END
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT m.mnu_nombre COLLATE DATABASE_DEFAULT + ' -> ' +
       m.mnu_link COLLATE DATABASE_DEFAULT + ' | permiso=' +
       ISNULL(p.prm_codigo COLLATE DATABASE_DEFAULT, '(ninguno)') AS RESULTADO
FROM [dbo].[Menus] m
LEFT JOIN [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso
WHERE m.mnu_link IN ('app://repuestos', 'app://bodegas', 'app://existencias')
ORDER BY m.mnu_orden
GO
