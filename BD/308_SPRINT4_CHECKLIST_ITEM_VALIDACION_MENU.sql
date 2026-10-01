USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACION:  29-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-091) T-4133/T-4134 REGISTRA EL MANTENEDOR DE
--                  UMBRALES Y ACCIONES DE ITEMS EN MENUS, CON PERMISO Y FUNCION.
-- =============================================
-- Cuelga del nodo de checklist (Centro de Mantenimiento). La ficha va oculta
-- (orden 99, visible 0). La funcion de escritura va en Menu_Funcion: sin ella el
-- boton "Nuevo" no aparece. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO


DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES
    (N'VER VALIDACIONES',          N'Ver los umbrales y acciones de los items de las pautas', N'MANTENIMIENTO', 3),
    (N'CREAR EDITAR VALIDACIONES', N'Administrar los umbrales y acciones de los items',        N'MANTENIMIENTO', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)
GO


DECLARE @RAIZ INT
SELECT TOP 1 @RAIZ = mnu_padre FROM [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx'
IF @RAIZ IS NULL
    SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Centro de Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL BEGIN RAISERROR('No existe el nodo padre de checklist.', 16, 1) RETURN END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Umbrales de ítems',            N'~/View/Mantenimiento/Checklist/ChecklistItemValidacions.aspx', 6,  1, N'mdi mdi-gauge'),
    (N'Validación de ítem (detalle)', N'~/View/Mantenimiento/Checklist/ChecklistItemValidacion.aspx',   99, 0, NULL)

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER VALIDACIONES'), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)
GO


INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, N'Crear y editar', p.prm_id
FROM   [dbo].[Menus] m
JOIN   [dbo].[Permiso] p ON p.prm_codigo = N'CREAR EDITAR VALIDACIONES'
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistItemValidacions.aspx'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=N'Crear y editar')
GO


DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (1, N'VER VALIDACIONES'), (1, N'CREAR EDITAR VALIDACIONES'),
    (10,N'VER VALIDACIONES'), (10,N'CREAR EDITAR VALIDACIONES'),
    (5, N'VER VALIDACIONES'), (5, N'CREAR EDITAR VALIDACIONES'),
    (11,N'VER VALIDACIONES'), (11,N'CREAR EDITAR VALIDACIONES'),
    (12,N'VER VALIDACIONES'), (13,N'VER VALIDACIONES'), (4, N'VER VALIDACIONES')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
FROM   @PP pp JOIN [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil=pp.perfil AND x.ppe_permiso=p.prm_id)
GO


SELECT 'permisos'  AS control, COUNT(*) v, 2 esperado FROM [dbo].[Permiso] WHERE prm_codigo IN (N'VER VALIDACIONES', N'CREAR EDITAR VALIDACIONES')
UNION ALL
SELECT 'pantallas', COUNT(*), 2 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Checklist/ChecklistItemValidacion%'
GO

PRINT '308_SPRINT4_CHECKLIST_ITEM_VALIDACION_MENU aplicado.'
GO
