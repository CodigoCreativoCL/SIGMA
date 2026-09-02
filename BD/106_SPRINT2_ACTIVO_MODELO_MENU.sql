USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2275/T-2276 REGISTRA MODELOS DE ACTIVO EN MENUS, CON PERMISO Y FUNCION.
-- =============================================
-- Va DESPUES de 105_SPRINT2_ACTIVO_MODELO_DEMO.
--
-- Las pantallas cuelgan del nodo "Activos" (bloque 76). Sin fila en Menus no
-- se abren; la ficha va con mnu_orden 99 y mnu_visible 0. La funcion de
-- escritura va en Menu_Funcion. La seguridad de datos (T-2276) la hace el
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
    (N'VER MODELOS ACTIVO',          N'Ver los modelos de activo', N'ACTIVOS', 3),
    (N'CREAR EDITAR MODELOS ACTIVO', N'Administrar modelos de activo', N'ACTIVOS', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Modelos: ' + LTRIM(STR(@N_PERM)) + ' (esperado 2)'
GO


DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Activos' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Activos. Ejecute antes el bloque 76.', 16, 1)
    RETURN
END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Modelos de activo',   N'~/View/Activos/Modelos/ActivoModelos.aspx', 7, 1, N'mdi mdi-shape-outline', N'VER MODELOS ACTIVO'),
    (N'Modelo (detalle)',    N'~/View/Activos/Modelos/ActivoModelo.aspx',  99, 0, NULL,                     N'VER MODELOS ACTIVO')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Modelos/%'
PRINT '--- Menus de Modelos: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO


DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES (N'~/View/Activos/Modelos/ActivoModelos.aspx', N'Crear y editar', N'CREAR EDITAR MODELOS ACTIVO')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, f.funcion, p.prm_id
FROM   @F f
JOIN   [dbo].[Menus] m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=f.funcion)
GO


DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (1, N'VER MODELOS ACTIVO'), (1, N'CREAR EDITAR MODELOS ACTIVO'),
    (10,N'VER MODELOS ACTIVO'), (10,N'CREAR EDITAR MODELOS ACTIVO'),
    (5, N'VER MODELOS ACTIVO'), (5, N'CREAR EDITAR MODELOS ACTIVO'),
    (11,N'VER MODELOS ACTIVO'), (11,N'CREAR EDITAR MODELOS ACTIVO'),
    (12,N'VER MODELOS ACTIVO'), (13,N'VER MODELOS ACTIVO'), (4, N'VER MODELOS ACTIVO')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
FROM   @PP pp JOIN [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil=pp.perfil AND x.ppe_permiso=p.prm_id)
GO


SELECT 'permisos de Modelos' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo IN (N'VER MODELOS ACTIVO', N'CREAR EDITAR MODELOS ACTIVO')
UNION ALL
SELECT 'pantallas de Modelos', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Modelos/%'
UNION ALL
SELECT 'funciones de Modelos', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id=mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Modelos/%'
GO

PRINT '106_SPRINT2_ACTIVO_MODELO_MENU aplicado.'
GO
