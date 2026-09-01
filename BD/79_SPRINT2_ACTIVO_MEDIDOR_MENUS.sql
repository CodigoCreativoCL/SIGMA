USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     T-2030 REGISTRA LAS PANTALLAS DE ACTIVO_MEDIDOR EN MENUS, CON PERMISO Y FUNCION.
-- =============================================
-- Va DESPUES de 78_SPRINT2_ACTIVO_MEDIDOR_DEMO.
--
-- Las pantallas de medidores cuelgan del nodo "Activos" que creo el bloque
-- 76. Sin fila en Menus la pantalla no se abre (Token.ExigirPagina niega por
-- omision). La ficha va con mnu_orden 99 y mnu_visible 0, pero CON su fila.
-- La funcion de escritura va en Menu_Funcion: sin ella el boton "Nuevo" no
-- aparece ni para Root.
--
-- ES IDEMPOTENTE: todo se busca por su codigo o su ruta antes de insertar.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. PERMISOS
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  ambito INT)

INSERT INTO @P VALUES
    (N'VER MEDIDORES',          N'Ver los medidores de los activos', N'ACTIVOS', 3),
    (N'CREAR EDITAR MEDIDORES', N'Configurar medidores de activos',  N'ACTIVOS', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Medidores: ' + LTRIM(STR(@N_PERM)) + ' (esperado 2)'
GO


/* ========================================================================
   2. MENUS (bajo el nodo Activos, nivel 2)
   ======================================================================== */

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Activos' AND mnu_nivel = 2

IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Activos. Ejecute antes el bloque 76.', 16, 1)
    RETURN
END

DECLARE @M TABLE (nombre  NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden   INT,
                  visible BIT,
                  icono   NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @M VALUES
    (N'Medidores',                 N'~/View/Activos/Medidores/ActivoMedidores.aspx', 2, 1, N'mdi mdi-gauge', N'VER MEDIDORES'),
    (N'Medidor de activo (detalle)', N'~/View/Activos/Medidores/ActivoMedidor.aspx', 99, 0, NULL,            N'VER MEDIDORES')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                     WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus]
 WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Medidores/%'
PRINT '--- Menus de Medidores: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO


/* ========================================================================
   3. MENU_FUNCION (cuelga del listado)
   ======================================================================== */

DECLARE @F TABLE (link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @F VALUES
    (N'~/View/Activos/Medidores/ActivoMedidores.aspx', N'Crear y editar', N'CREAR EDITAR MEDIDORES')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT  m.mnu_id, f.funcion, p.prm_id
FROM    @F f
JOIN    [dbo].[Menus]   m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN    [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x
                     WHERE x.mfu_menu = m.mnu_id
                       AND x.mfu_nombre COLLATE DATABASE_DEFAULT = f.funcion)
GO


/* ========================================================================
   4. QUIEN PUEDE QUE (mismos perfiles que Activos)
   ======================================================================== */

DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @PP VALUES
    (1,  N'VER MEDIDORES'), (1,  N'CREAR EDITAR MEDIDORES'),
    (10, N'VER MEDIDORES'), (10, N'CREAR EDITAR MEDIDORES'),
    (5,  N'VER MEDIDORES'), (5,  N'CREAR EDITAR MEDIDORES'),
    (11, N'VER MEDIDORES'), (11, N'CREAR EDITAR MEDIDORES'),
    (12, N'VER MEDIDORES'),
    (13, N'VER MEDIDORES'),
    (4,  N'VER MEDIDORES')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  pp.perfil, p.prm_id, 1, GETDATE()
FROM    @PP pp
JOIN    [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x
                     WHERE x.ppe_perfil = pp.perfil AND x.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'permisos de Medidores' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo IN (N'VER MEDIDORES', N'CREAR EDITAR MEDIDORES')
UNION ALL
SELECT 'pantallas de Medidores', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Medidores/%'
UNION ALL
SELECT 'funciones de Medidores', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf
JOIN   [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/Medidores/%'
GO

PRINT '79_SPRINT2_ACTIVO_MEDIDOR_MENUS aplicado.'
GO
