USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  11-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-090) T-4079/T-4080 REGISTRA LAS PANTALLAS DE PAUTAS EN MENUS, CON PERMISO Y FUNCION.
-- =============================================
-- Va DESPUES de 190_SPRINT4_CHECKLIST_PLANTILLA_DEMO.
--
-- Las pantallas cuelgan del nodo "Mantenimiento". Sin fila en Menus no se
-- abren (Token.ExigirPagina niega por omision); la ficha va con mnu_orden 99 y
-- mnu_visible 0. La funcion de escritura va en Menu_Funcion: sin ella el boton
-- "Nuevo" no aparece ni para Root. La seguridad de datos (T-4080) la hace el
-- filtro por cliente en el listado y en el SP, no esconder el boton.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO


DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES
    (N'VER PAUTAS',          N'Ver las pautas de inspeccion (plantillas de checklist)', N'MANTENIMIENTO', 3),
    (N'CREAR EDITAR PAUTAS', N'Administrar pautas de inspeccion',                        N'MANTENIMIENTO', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Pautas: ' + LTRIM(STR(@N_PERM)) + ' (esperado 2)'
GO


DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Mantenimiento.', 16, 1)
    RETURN
END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Pautas de inspección',           N'~/View/Mantenimiento/Checklist/ChecklistPlantillas.aspx', 4, 1, N'mdi mdi-clipboard-check-outline', N'VER PAUTAS'),
    (N'Pauta de inspección (detalle)',  N'~/View/Mantenimiento/Checklist/ChecklistPlantilla.aspx',  99, 0, NULL,                            N'VER PAUTAS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Checklist/%'
PRINT '--- Menus de Pautas: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO


DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES (N'~/View/Mantenimiento/Checklist/ChecklistPlantillas.aspx', N'Crear y editar', N'CREAR EDITAR PAUTAS')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, f.funcion, p.prm_id
FROM   @F f
JOIN   [dbo].[Menus] m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=f.funcion)
GO


DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (1, N'VER PAUTAS'), (1, N'CREAR EDITAR PAUTAS'),
    (10,N'VER PAUTAS'), (10,N'CREAR EDITAR PAUTAS'),
    (5, N'VER PAUTAS'), (5, N'CREAR EDITAR PAUTAS'),
    (11,N'VER PAUTAS'), (11,N'CREAR EDITAR PAUTAS'),
    (12,N'VER PAUTAS'), (13,N'VER PAUTAS'), (4, N'VER PAUTAS')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
FROM   @PP pp JOIN [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil=pp.perfil AND x.ppe_permiso=p.prm_id)
GO


SELECT 'permisos de Pautas' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo IN (N'VER PAUTAS', N'CREAR EDITAR PAUTAS')
UNION ALL
SELECT 'pantallas de Pautas', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Checklist/%'
UNION ALL
SELECT 'funciones de Pautas', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id=mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Checklist/%'
GO

PRINT '191_SPRINT4_CHECKLIST_PLANTILLA_MENU aplicado.'
GO
