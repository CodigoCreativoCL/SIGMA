USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     T-2013 REGISTRA LAS PANTALLAS DE ACTIVO EN MENUS, CON SU PERMISO Y SU FUNCION.
-- =============================================
-- Va DESPUES de 75_SPRINT2_ACTIVO_DEMO.
--
-- POR QUE ESTE BLOQUE EXISTE
--   En SIGMA una pantalla que no esta en Menus NO SE PUEDE ABRIR:
--   Token.ExigirPagina() la deniega por omision. Registrar la pantalla es un
--   INSERT en Menus, no un cambio de codigo. Sin este bloque, Activos.aspx y
--   Activo.aspx darian acceso denegado aunque el .aspx exista.
--
--   Ademas de la fila en Menus hacen falta:
--     - El PERMISO que abre la pantalla (mnu_permiso -> Token.PuedePagina).
--     - La FUNCION de escritura (Menu_Funcion), que es lo que consulta
--       Token.PuedeFuncion("Crear y editar") para mostrar el boton Nuevo.
--       Sin fila en Menu_Funcion la funcion devuelve false PARA TODOS -Root
--       incluido- y el boton simplemente no aparece: el sintoma enganna.
--     - Los permisos a los perfiles que corresponda.
--
-- ES IDEMPOTENTE
--   Todo se busca por su codigo o su ruta antes de insertar.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. PERMISOS
      Uno para ver (VER ACTIVOS) y uno para escribir (CREAR EDITAR ACTIVOS).
      Ver es AMBOS (3): la app movil tambien consulta el maestro de activos.
      Crear y editar es WEB (1): el alta administrativa se hace en el sitio.

      La @P se declara con la collation de la base: una tabla de variable
      nace con la de tempdb y compararla contra Permiso reventaria.
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  ambito INT)

INSERT INTO @P VALUES
    (N'VER ACTIVOS',          N'Ver los activos del cliente', N'ACTIVOS', 3),
    (N'CREAR EDITAR ACTIVOS', N'Crear y editar activos',      N'ACTIVOS', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Activos: ' + LTRIM(STR(@N_PERM)) + ' (esperado 2)'
GO


/* ========================================================================
   2. MENUS
      Activos nace como nodo de nivel 2, al lado de Organizacion, Comercial e
      Inventario: es operacion del cliente. La ficha va con orden 99 y
      mnu_visible 0 -no aparece en el arbol- pero CON su fila, porque sin ella
      no se abre.
   ======================================================================== */

DECLARE @RAIZ INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Activos' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Activos', 'Máquinas y equipos del cliente', 2, 1, 5, '#', 1,
            'mdi mdi-cog-outline', NULL, 1)

SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Activos' AND mnu_nivel = 2

DECLARE @M TABLE (nombre  NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden   INT,
                  visible BIT,
                  icono   NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @M VALUES
    (N'Activos',          N'~/View/Activos/Activos/Activos.aspx', 1, 1, N'mdi mdi-cog-outline', N'VER ACTIVOS'),
    (N'Activo (detalle)', N'~/View/Activos/Activos/Activo.aspx',  99, 0, NULL,                  N'VER ACTIVOS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                     WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @RAIZ
PRINT '--- Menus de Activos: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO


/* ========================================================================
   3. MENU_FUNCION
      La funcion de escritura cuelga del LISTADO (desde la ficha no resuelve).
      El nombre "Crear y editar" tiene que calzar EXACTO con el que usa el
      .aspx.cs: es el mismo que usa todo el sitio.
   ======================================================================== */

DECLARE @F TABLE (link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @F VALUES
    (N'~/View/Activos/Activos/Activos.aspx', N'Crear y editar', N'CREAR EDITAR ACTIVOS')

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
   4. QUIEN PUEDE QUE
      El jefe y el planificador dan de alta y editan activos; el
      administrador del cliente tambien. Supervisor, tecnico y bodeguero solo
      consultan. Root se deja explicito para que la matriz se pueda leer,
      aunque SEL_USUARIO_PERMISOS ya se lo resuelve por regla.
   ======================================================================== */

DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @PP VALUES
    -- Root (1)
    (1,  N'VER ACTIVOS'), (1,  N'CREAR EDITAR ACTIVOS'),
    -- Administrador del Cliente (10)
    (10, N'VER ACTIVOS'), (10, N'CREAR EDITAR ACTIVOS'),
    -- Jefe de Mantenimiento (5)
    (5,  N'VER ACTIVOS'), (5,  N'CREAR EDITAR ACTIVOS'),
    -- Planificador (11)
    (11, N'VER ACTIVOS'), (11, N'CREAR EDITAR ACTIVOS'),
    -- Supervisor (12), Tecnico (13), Bodeguero (4): consulta
    (12, N'VER ACTIVOS'),
    (13, N'VER ACTIVOS'),
    (4,  N'VER ACTIVOS')

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

SELECT 'permisos de Activos' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo IN (N'VER ACTIVOS', N'CREAR EDITAR ACTIVOS')
UNION ALL
SELECT 'pantallas de Activos', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/%'
UNION ALL
SELECT 'funciones de Activos', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf
JOIN   [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Activos/%'
GO

PRINT '76_SPRINT2_ACTIVO_MENUS aplicado.'
GO
