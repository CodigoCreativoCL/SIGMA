USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2291/T-2292 REGISTRA UNIDAD_MEDIDA EN MENUS, CON PERMISO Y FUNCION.
-- =============================================
-- Va DESPUES de 94_SPRINT2_UNIDAD_MEDIDA_DEMO.
--
-- Unidad_Medida es un catalogo GLOBAL de plataforma (sin cliente). Su
-- administracion NO es del cliente -editar una unidad la cambia para TODOS
-- los clientes-, asi que la pantalla va bajo Sistema > Mantenedores, junto a
-- Catalogos, y el permiso se asigna a Root (plataforma), no a los perfiles
-- de cliente.
--
-- Los combos de unidad de medidores, repuestos y variables NO dependen de
-- este permiso: leen del SEL_ directo, asi que siguen funcionando para todos.
--
-- ES IDEMPOTENTE.
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
    (N'VER UNIDADES MEDIDA',          N'Ver las unidades de medida',        N'SISTEMA', 3),
    (N'CREAR EDITAR UNIDADES MEDIDA', N'Administrar las unidades de medida', N'SISTEMA', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Unidades de medida: ' + LTRIM(STR(@N_PERM)) + ' (esperado 2)'
GO


/* ========================================================================
   2. MENUS (bajo Sistema > Mantenedores, el mismo padre que Catalogos)
   ======================================================================== */

-- El nodo Mantenedores que cuelga de Sistema (nivel 2). Catalogos NO sirve
-- de referencia: se movio a Cliente > Configuracion en el bloque 53.
DECLARE @PADRE INT
SELECT @PADRE = mnu_id FROM [dbo].[Menus]
 WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Mantenedores'
   AND mnu_padre = (SELECT mnu_id FROM [dbo].[Menus]
                     WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Sistema' AND mnu_nivel = 2)

IF @PADRE IS NULL
BEGIN
    RAISERROR('No se encontro el nodo Sistema > Mantenedores.', 16, 1)
    RETURN
END

DECLARE @M TABLE (nombre  NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden   INT,
                  visible BIT,
                  icono   NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @M VALUES
    (N'Unidades de medida',          N'~/View/Sistema/UnidadesMedida/UnidadMedidas.aspx', 4, 1, N'mdi mdi-ruler', N'VER UNIDADES MEDIDA'),
    (N'Unidad de medida (detalle)',  N'~/View/Sistema/UnidadesMedida/UnidadMedida.aspx',  99, 0, NULL,           N'VER UNIDADES MEDIDA')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, m.nombre, 4, @PADRE, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                     WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus]
 WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Sistema/UnidadesMedida/%'
PRINT '--- Menus de Unidades de medida: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO


/* ========================================================================
   3. MENU_FUNCION
   ======================================================================== */

DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @F VALUES
    (N'~/View/Sistema/UnidadesMedida/UnidadMedidas.aspx', N'Crear y editar', N'CREAR EDITAR UNIDADES MEDIDA')

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
   4. PERMISOS AL PERFIL ROOT (plataforma)
      Solo Root administra el catalogo global. Los demas perfiles NO: una
      unidad es de todos los clientes.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  1, p.prm_id, 1, GETDATE()
FROM    [dbo].[Permiso] p
WHERE   p.prm_codigo IN (N'VER UNIDADES MEDIDA', N'CREAR EDITAR UNIDADES MEDIDA')
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = 1 AND x.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'permisos de Unidades' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo IN (N'VER UNIDADES MEDIDA', N'CREAR EDITAR UNIDADES MEDIDA')
UNION ALL
SELECT 'pantallas de Unidades', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Sistema/UnidadesMedida/%'
UNION ALL
SELECT 'funciones de Unidades', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf
JOIN   [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Sistema/UnidadesMedida/%'
GO

PRINT '95_SPRINT2_UNIDAD_MEDIDA_MENU aplicado.'
GO
