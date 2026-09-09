USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LA BUSQUEDA GLOBAL DE COMPONENTES EN EL MENU (VISTA 8.1).
-- =============================================
-- POR QUE UN MENU, SI YA ESTA LA PESTAÑA DEL ACTIVO
--
--   La vista 8.1 pide llegar «desde el activo O desde busqueda global», y son
--   dos caminos distintos porque responden a dos situaciones:
--
--   - Desde el activo: se sabe que equipo es y se quiere ver de que esta
--     hecho. Eso ya esta, como pestaña de la ficha.
--
--   - Desde el menu: se tiene un codigo de pieza en la mano —el de una
--     etiqueta, el de un correo, el que dicto alguien por radio— y NO se sabe
--     de que equipo es. Ese es el caso que la pestaña no puede resolver,
--     porque para abrirla hay que saber el equipo primero.
--
-- EL PERMISO
--
--   VER COMPONENTES, que ya existe. Los perfiles que lo tengan veran la fila;
--   el resto, no. La pantalla no decide nada: el menu que devuelve el
--   servidor es la unica fuente.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @PADRE INT = (SELECT TOP 1 mnu_padre FROM [dbo].[Menus]
                       WHERE mnu_link = 'app://activos')

IF (@PADRE IS NULL)
BEGIN
    RAISERROR('1.- NO SE ENCONTRO EL NODO RAIZ DE LA APP (corre BD/201 antes).', 16, 1)
    RETURN
END

DECLARE @VER INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER COMPONENTES')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(ISNULL(mnu_orden, 0)) FROM [dbo].[Menus]
                              WHERE mnu_padre = @PADRE), 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://componentes')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Componentes',
         'Buscar una pieza por código o nombre',
         2, @PADRE, @ORDEN + 1,
         'app://componentes', 1, 'mdi mdi-cog-outline', @VER, 2)
END
GO

-- ---------------------------------------------------------------------------
-- Verificacion: el menu de la app, como lo va a ver el telefono
-- ---------------------------------------------------------------------------
SELECT CAST(m.mnu_orden AS VARCHAR) + ' · ' +
       m.mnu_nombre COLLATE DATABASE_DEFAULT + ' -> ' +
       m.mnu_link COLLATE DATABASE_DEFAULT + ' | ' +
       ISNULL(p.prm_codigo COLLATE DATABASE_DEFAULT, '(sin permiso)') AS RESULTADO
FROM [dbo].[Menus] m
LEFT JOIN [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso
WHERE m.mnu_link LIKE 'app://%'
ORDER BY m.mnu_orden
GO
