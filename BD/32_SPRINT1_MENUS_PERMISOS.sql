USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     REGISTRA LAS PANTALLAS DEL SPRINT 1 Y SUS PERMISOS.
-- =============================================
-- Va DESPUES de 31_SPRINT1_CATALOGOS.
--
-- POR QUE ESTE BLOQUE EXISTE
--   En SIGMA una pantalla que no esta en Menus NO SE PUEDE ABRIR: Token
--   .ExigirPagina() la deniega por defecto. Eso fue una decision explicita
--   -que registrar una pantalla sea un INSERT y no un cambio de codigo- y
--   la contrapartida es que el registro hay que hacerlo. Sin este bloque,
--   las pantallas nuevas darian acceso denegado aunque el .aspx exista.
--
--   Las paginas de DETALLE (formularios que se abren desde un listado) se
--   registran con mnu_visible = 0: necesitan permiso para abrirse, pero no
--   aparecen en el menu lateral.
--
-- LOS ICONOS
--   Todos MDI con variante -outline, como el resto del sitio desde el
--   bloque 07.
--
-- ES IDEMPOTENTE
--   Todo se busca por su ruta o su codigo antes de insertar, asi que se
--   puede re-ejecutar. Los ids son IDENTITY: no se fuerzan.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. PERMISOS
      Un permiso por pantalla (VER ...) y uno por facultad de escritura.
      El codigo es la llave que usa Token.Puede(); el nombre es lo que ve
      el administrador en la matriz de perfiles.
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(200), nombre NVARCHAR(400), modulo NVARCHAR(200), asignable BIT)

INSERT INTO @P (codigo, nombre, modulo, asignable) VALUES
 (N'VER PLANTAS',                  N'Ver las plantas del cliente',              N'ORGANIZACION', 0),
 (N'CREAR EDITAR PLANTAS',         N'Crear y editar plantas',                   N'ORGANIZACION', 0),
 (N'VER AREAS',                    N'Ver las áreas de una planta',              N'ORGANIZACION', 0),
 (N'CREAR EDITAR AREAS',           N'Crear y editar áreas',                     N'ORGANIZACION', 0),
 (N'VER CENTROS COSTO',            N'Ver los centros de costo',                 N'ORGANIZACION', 0),
 (N'CREAR EDITAR CENTROS COSTO',   N'Crear y editar centros de costo',          N'ORGANIZACION', 0),
 (N'VER GRUPOS TRABAJO',           N'Ver los grupos de trabajo',                N'ORGANIZACION', 0),
 (N'CREAR EDITAR GRUPOS TRABAJO',  N'Crear y editar grupos de trabajo',         N'ORGANIZACION', 0),
 (N'VER ESPECIALIDADES USUARIO',   N'Ver las especialidades de un usuario',     N'ORGANIZACION', 0),
 (N'CREAR EDITAR ESPECIALIDADES USUARIO', N'Registrar especialidades y certificaciones', N'ORGANIZACION', 0),
 (N'VER CATALOGOS',                N'Consultar los catálogos del sistema',      N'SISTEMA',      0),
 (N'CREAR EDITAR CATALOGOS',       N'Agregar valores propios a un catálogo',    N'SISTEMA',      0),
 (N'VER PERMISOS USUARIO',         N'Ver los permisos puntuales de un usuario', N'SEGURIDAD',    0)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo,
        /* Ambito WEB: son pantallas del administrativo, no de la app. */
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        NULL, 1, GETDATE(), 1, GETDATE(), 1, p.asignable
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)
GO

PRINT 'Permisos del Sprint 1 registrados.'
GO


/* ========================================================================
   2. MENU CONTENEDOR "ORGANIZACION"
      Cuelga de la raiz, junto a Sistema, Comercial y Clientes. Es donde
      vive la estructura fisica del cliente: plantas, areas, centros de
      costo y cuadrillas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre = N'Organización' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
    VALUES (N'Organización', N'Estructura organizacional del cliente', 2, 1, 4, N'#', 1, N'mdi mdi-sitemap-outline', NULL)
GO


/* ========================================================================
   3. PANTALLAS
      Se insertan por ruta. La ruta es la identidad de la pantalla: es lo
      que compara Token.PuedePagina() contra la peticion.
   ======================================================================== */

DECLARE @ORG    INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Organización' AND mnu_nivel = 2)
DECLARE @ACCESO INT = 3      -- Sistema > Acceso
DECLARE @MANT   INT = 1061   -- Sistema > Mantenedores

DECLARE @M TABLE
(
    nombre    NVARCHAR(200),
    descripcion NVARCHAR(400),
    nivel     INT,
    padre     INT,
    orden     INT,
    link      NVARCHAR(400),
    visible   BIT,
    icono     NVARCHAR(100),
    permiso   NVARCHAR(200)
)

INSERT INTO @M VALUES
 -- Organizacion (listados)
 (N'Plantas',           N'Plantas o instalaciones del cliente', 3, @ORG, 1, N'~/View/Organizacion/Plantas/Plantas.aspx',              1, N'mdi mdi-factory',                 N'VER PLANTAS'),
 (N'Áreas',             N'Áreas y subáreas de una planta',      3, @ORG, 2, N'~/View/Organizacion/Areas/Areas.aspx',                  1, N'mdi mdi-file-tree-outline',       N'VER AREAS'),
 (N'Centros de Costo',  N'Árbol de centros de costo',           3, @ORG, 3, N'~/View/Organizacion/CentrosCosto/CentrosCosto.aspx',    1, N'mdi mdi-cash-multiple',           N'VER CENTROS COSTO'),
 (N'Grupos de Trabajo', N'Cuadrillas y turnos',                 3, @ORG, 4, N'~/View/Organizacion/Grupos/Grupos.aspx',                1, N'mdi mdi-account-hard-hat-outline', N'VER GRUPOS TRABAJO'),
 -- Organizacion (detalles, no visibles)
 (N'Planta (detalle)',          N'Ficha de la planta',           4, @ORG, 99, N'~/View/Organizacion/Plantas/Planta.aspx',             0, NULL, N'VER PLANTAS'),
 (N'Área (detalle)',            N'Ficha del área',               4, @ORG, 99, N'~/View/Organizacion/Areas/Area.aspx',                 0, NULL, N'VER AREAS'),
 (N'Centro de costo (detalle)', N'Ficha del centro de costo',    4, @ORG, 99, N'~/View/Organizacion/CentrosCosto/CentroCosto.aspx',   0, NULL, N'VER CENTROS COSTO'),
 (N'Grupo de trabajo (detalle)',N'Ficha del grupo de trabajo',   4, @ORG, 99, N'~/View/Organizacion/Grupos/Grupo.aspx',               0, NULL, N'VER GRUPOS TRABAJO'),
 (N'Especialidades del usuario',N'Especialidades y certificaciones', 4, @ORG, 99, N'~/View/Organizacion/Especialidades/UsuarioEspecialidades.aspx', 0, NULL, N'VER ESPECIALIDADES USUARIO'),
 -- Sistema > Mantenedores
 (N'Catálogos',         N'Catálogos del sistema',               4, @MANT, 3, N'~/View/Sistema/Catalogos/Catalogos.aspx',              1, N'mdi mdi-format-list-bulleted-type', N'VER CATALOGOS'),
 -- Sistema > Acceso
 (N'Permisos por usuario', N'Excepciones de permiso por persona', 4, @ACCESO, 5, N'~/View/Root/Mantenedores/PermisosUsuario/PermisosUsuario.aspx', 1, N'mdi mdi-account-key-outline', N'VER PERMISOS USUARIO'),
 (N'Permiso de usuario (detalle)', N'Otorgar o revocar un permiso', 4, @ACCESO, 99, N'~/View/Root/Mantenedores/PermisosUsuario/PermisoUsuario.aspx', 0, NULL, N'VER PERMISOS USUARIO')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT  m.nombre, m.descripcion, m.nivel, m.padre, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso)
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                    WHERE LOWER(x.mnu_link) = LOWER(m.link) COLLATE DATABASE_DEFAULT)
GO

PRINT 'Pantallas del Sprint 1 registradas.'
GO


/* ========================================================================
   4. FUNCIONES DE CADA PANTALLA
      Una funcion es un permiso DENTRO de una pantalla. Aqui la unica que
      aplica de forma transversal es la de escritura: sin ella la pantalla
      se abre en solo lectura.
   ======================================================================== */

DECLARE @F TABLE (ruta NVARCHAR(400), nombre NVARCHAR(200), permiso NVARCHAR(200))

INSERT INTO @F VALUES
 (N'~/View/Organizacion/Plantas/Plantas.aspx',           N'Crear y editar', N'CREAR EDITAR PLANTAS'),
 (N'~/View/Organizacion/Areas/Areas.aspx',               N'Crear y editar', N'CREAR EDITAR AREAS'),
 (N'~/View/Organizacion/CentrosCosto/CentrosCosto.aspx', N'Crear y editar', N'CREAR EDITAR CENTROS COSTO'),
 (N'~/View/Organizacion/Grupos/Grupos.aspx',             N'Crear y editar', N'CREAR EDITAR GRUPOS TRABAJO'),
 (N'~/View/Organizacion/Especialidades/UsuarioEspecialidades.aspx', N'Crear y editar', N'CREAR EDITAR ESPECIALIDADES USUARIO'),
 (N'~/View/Sistema/Catalogos/Catalogos.aspx',            N'Crear y editar', N'CREAR EDITAR CATALOGOS'),
 (N'~/View/Root/Mantenedores/PermisosUsuario/PermisosUsuario.aspx', N'Otorgar y revocar', N'ASIGNAR PERMISO TERRENO')

INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
SELECT  f.nombre,
        (SELECT mnu_id FROM [dbo].[Menus] WHERE LOWER(mnu_link) = LOWER(f.ruta) COLLATE DATABASE_DEFAULT),
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = f.permiso)
FROM    @F f
WHERE   EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE LOWER(mnu_link) = LOWER(f.ruta) COLLATE DATABASE_DEFAULT)
  AND   NOT EXISTS (
            SELECT 1 FROM [dbo].[Menu_Funcion] mf
            WHERE mf.mfu_menu = (SELECT mnu_id FROM [dbo].[Menus] WHERE LOWER(mnu_link) = LOWER(f.ruta) COLLATE DATABASE_DEFAULT)
              AND mf.mfu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = f.permiso))
GO

PRINT 'Funciones de las pantallas nuevas registradas.'
GO


/* ========================================================================
   5. RECUPERACION DE CONTRASENA: PAGINAS PUBLICAS

      Estas dos NO llevan permiso: se abren sin sesion, que es justamente el
      caso de HU-004 -alguien que no puede entrar-. Token.ExigirPagina()
      tiene una lista de paginas exentas y estas dos hay que agregarlas ahi;
      no basta con la base. Queda anotado aqui para que no se pierda:

          App_Code/SitioBase/Token.cs -> EXENTAS
          ~/recuperarclave.aspx
          ~/restablecerclave.aspx

      Se registran igual en Menus, invisibles y sin permiso, para que la
      pantalla de mantenedor de menus las muestre y nadie las de por
      inexistentes.
   ======================================================================== */

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT N'Recuperar contraseña', N'Solicitud del enlace de recuperación', 2, 1, 98, N'~/RecuperarClave.aspx', 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE LOWER(mnu_link) = N'~/recuperarclave.aspx' COLLATE DATABASE_DEFAULT)
GO

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT N'Restablecer contraseña', N'Fijar la contraseña nueva con el enlace', 2, 1, 99, N'~/RestablecerClave.aspx', 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE LOWER(mnu_link) = N'~/restablecerclave.aspx' COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   6. TODO AL PERFIL ROOT

      Sin esto las pantallas quedan creadas pero nadie las ve, ni siquiera
      quien administra. Los demas perfiles se configuran desde
      Sistema > Acceso > Menus, que es para lo que existe esa pantalla.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO

PRINT 'Permisos asignados al perfil Root.'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'permisos nuevos'   AS control, COUNT(*) AS valor, 13 AS esperado
FROM   [dbo].[Permiso]
WHERE  prm_codigo IN (N'VER PLANTAS',N'CREAR EDITAR PLANTAS',N'VER AREAS',N'CREAR EDITAR AREAS',
                      N'VER CENTROS COSTO',N'CREAR EDITAR CENTROS COSTO',N'VER GRUPOS TRABAJO',
                      N'CREAR EDITAR GRUPOS TRABAJO',N'VER ESPECIALIDADES USUARIO',
                      N'CREAR EDITAR ESPECIALIDADES USUARIO',N'VER CATALOGOS',
                      N'CREAR EDITAR CATALOGOS',N'VER PERMISOS USUARIO')
UNION ALL
SELECT 'pantallas nuevas', COUNT(*), 14
FROM   [dbo].[Menus]
WHERE  mnu_link LIKE N'~/View/Organizacion/%'
    OR mnu_link LIKE N'~/View/Sistema/Catalogos/%'
    OR mnu_link LIKE N'~/View/Root/Mantenedores/PermisosUsuario/%'
    OR mnu_link IN (N'~/RecuperarClave.aspx', N'~/RestablecerClave.aspx')
UNION ALL
SELECT 'funciones nuevas', COUNT(*), 7
FROM   [dbo].[Menu_Funcion] mf
INNER JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  m.mnu_link LIKE N'~/View/Organizacion/%'
    OR m.mnu_link LIKE N'~/View/Sistema/Catalogos/%'
    OR m.mnu_link LIKE N'~/View/Root/Mantenedores/PermisosUsuario/%'
UNION ALL
SELECT 'paginas con permiso', COUNT(*), NULL
FROM   [dbo].[Menus] WHERE mnu_link <> N'#' AND mnu_permiso IS NOT NULL
UNION ALL
SELECT 'paginas SIN permiso (deben ser 2, las publicas)', COUNT(*), 2
FROM   [dbo].[Menus] WHERE mnu_link <> N'#' AND mnu_permiso IS NULL
UNION ALL
SELECT 'permisos del perfil Root', COUNT(*), NULL
FROM   [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1
GO
