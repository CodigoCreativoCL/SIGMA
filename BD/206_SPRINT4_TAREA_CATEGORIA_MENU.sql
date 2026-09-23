USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-100) T-4318/T-4319 REGISTRA en Menus el listado
--                  y la ficha de categorias de tarea. El listado visible
--                  (orden 6), la ficha oculta (orden 99, no visible): sin fila
--                  en Menus el servidor no sirve la pantalla. Reusa los permisos
--                  de tareas: ver con VER TAREAS (118) y crear/editar con
--                  CREAR EDITAR TAREAS (119), via Menu_Funcion 'Crear y editar'.
--                  El filtro por cliente lo hace el SP/consulta. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN RAISERROR('No existe el nodo Mantenimiento.', 16, 1) RETURN END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Categorías de tarea',           N'~/View/Mantenimiento/Tareas/TareaCategorias.aspx', 6, 1, N'mdi mdi-tag-multiple', N'VER TAREAS'),
    (N'Categoría de tarea (detalle)',  N'~/View/Mantenimiento/Tareas/TareaCategoria.aspx',  99, 0, NULL,                  N'VER TAREAS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES
    (N'~/View/Mantenimiento/Tareas/TareaCategorias.aspx', N'Crear y editar', N'CREAR EDITAR TAREAS'),
    (N'~/View/Mantenimiento/Tareas/TareaCategorias.aspx', N'Eliminar',       N'CREAR EDITAR TAREAS')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, f.funcion, p.prm_id
FROM   @F f
JOIN   [dbo].[Menus] m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=f.funcion)
GO

SELECT 'pantallas Categorias de tarea' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Tareas/TareaCategoria%'
GO

PRINT '206_SPRINT4_TAREA_CATEGORIA_MENU aplicado.'
GO
