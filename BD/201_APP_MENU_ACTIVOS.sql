USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     EL LISTADO DE EQUIPOS EN EL MENU DE LA APP (VISTA 7.2).
-- =============================================
-- POR QUE HACE FALTA, SI YA ESTA EL ESCANER
--
--   El escaner sirve estando DELANTE del equipo. Esta pantalla sirve para lo
--   contrario: encontrar uno del que solo se sabe el nombre, o mirar que hay
--   en un area antes de bajar. Y para cuando la etiqueta esta rayada, que en
--   una planta de diez años es la mitad.
--
-- DE DONDE SALEN LOS DATOS
--
--   De la sabana, no de la red: no hay GET /activos -ActivosController expone
--   la ficha y su historial- y no hace falta inventarlo, porque los activos ya
--   bajan enteros al telefono. La pantalla dice que si la sabana no se bajo la
--   lista sale vacia, en vez de dejar creer que la planta no tiene equipos.
--
-- EL PERMISO
--
--   VER ACTIVOS, que tienen los cinco perfiles de terreno y tambien el
--   bodeguero: imprime etiquetas de equipos y necesita encontrarlos.
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

DECLARE @VER INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ACTIVOS')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(ISNULL(mnu_orden, 0)) FROM [dbo].[Menus]
                              WHERE mnu_padre = @PADRE), 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://activos')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Equipos de la planta',
         'Buscar un activo por nombre, código, serie o área',
         2, @PADRE, @ORDEN + 1,
         'app://activos', 1, 'mdi mdi-cube-outline', @VER, 2)
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
