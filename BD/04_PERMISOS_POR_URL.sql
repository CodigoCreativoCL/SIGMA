USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     EL PERMISO SE RESUELVE POR LA URL. LA PAGINA NO DECLARA NADA.
-- =============================================
-- Va DESPUES de 03_MANTENEDOR_MENUS.
--
-- QUE ESTABA MAL TODAVIA
--   El bloque 02 saco los ids compilados, pero dejo el codigo escrito en
--   cada pagina:
--       Token.Exigir("VER CLIENTES");
--       wucClientes.Ver_Todo = "VER TODO CLIENTES";
--   Eso sigue siendo acoplamiento: cambiar un permiso obliga a tocar y
--   recompilar la pagina. Solo se cambio un id por un string.
--
-- LA IDEA
--   La pagina YA SABE cual es: su propia URL. Y esa URL ya esta en la
--   base, en Menus.mnu_link. Entonces el permiso se resuelve solo:
--
--       Request.AppRelativeCurrentExecutionFilePath
--            -> Menus.mnu_link -> Menus.mnu_permiso -> Permiso.prm_codigo
--
--   El chequeo vive en Default.master y corre para TODA pagina que use
--   ese master. Ninguna pagina declara su permiso. Ninguna lo menciona.
--
--   Para las funciones dentro de una pagina pasa lo mismo: un control
--   pregunta por NOMBRE GENERICO -- "Ver todo", "Crear y editar" -- y se
--   resuelve contra las Menu_Funcion de la pagina donde esta montado. Por
--   eso Clientes.ascx funciona igual en Clientes.aspx que en
--   ReasignacionesClientes.aspx, cada una con su propio permiso, sin que
--   la pagina le pase nada.
--
-- PAGINAS QUE NO SON MENU
--   Los detalles (Pais.aspx, Cliente.aspx, Perfil.aspx...) se abren desde
--   una grilla y no van en la navegacion, pero necesitan permiso igual.
--   Se registran como Menus con mnu_visible = 0 y el permiso de su padre.
--   Una fila invisible es "pagina que existe pero no se muestra".
--
-- PAGINA SIN FILA EN Menus
--   No se puede entrar. Es deliberado: si una pagina no esta declarada,
--   no esta autorizada. Antes el olvido dejaba la pagina ABIERTA.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. LAS PAGINAS DE DETALLE ENTRAN AL ARBOL, INVISIBLES
      Toman el mismo permiso que su listado padre, que es exactamente lo
      que hacian antes cuando citaban el mismo Paginas.menu_N.Ver.
   ======================================================================== */

DECLARE @D TABLE (link NVARCHAR(200), nombre NVARCHAR(100), padre INT, codigo NVARCHAR(100))
INSERT INTO @D VALUES
 (N'~/View/Root/Mantenedores/Perfiles/Perfil.aspx',              N'Perfil (detalle)',              3, N'VER PERFILES'),
 (N'~/View/Root/Mantenedores/Usuarios/Usuario.aspx',             N'Usuario (detalle)',             3, N'VER USUARIOS'),
 (N'~/View/Root/Mantenedores/Usuarios/UsuarioPaises.aspx',       N'Usuario paises (detalle)',      3, N'VER USUARIOS'),
 (N'~/View/Root/Mantenedores/Usuarios/UsuarioPerfiles.aspx',     N'Usuario perfiles (detalle)',    3, N'VER USUARIOS'),
 (N'~/View/Sistema/Mantenedores/Paises/Pais.aspx',               N'Pais (detalle)',                7, N'VER PAISES'),
 (N'~/View/Comercial/Clientes/Cliente.aspx',                     N'Cliente (detalle)',            24, N'VER CLIENTES'),
 (N'~/View/Comercial/Clientes/ReasignacionCliente.aspx',         N'Reasignacion (detalle)',       24, N'VER REASIGNACION CLIENTES'),
 (N'~/View/Root/Mantenedores/Menus/Menu.aspx',                   N'Menu (detalle)',                3, N'VER MANTENEDOR MENUS'),
 (N'~/View/Root/Mantenedores/Menus/MenuFuncion.aspx',            N'Funcion de menu (detalle)',     3, N'VER MANTENEDOR MENUS')

INSERT INTO [dbo].[Menus] ([mnu_nombre],[mnu_descripcion],[mnu_nivel],[mnu_padre],
                           [mnu_orden],[mnu_link],[mnu_visible],[mnu_icon],[mnu_permiso])
SELECT d.nombre, d.nombre, 4, d.padre, 99, d.link, 0, N'', p.prm_id
FROM   @D d
JOIN   [dbo].[Permiso] p ON p.prm_codigo COLLATE DATABASE_DEFAULT = d.codigo COLLATE DATABASE_DEFAULT
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = d.link COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   2. EL MAPA QUE CONSUME Token
      Se reemplaza el de ids por uno de URLs. Dos resultados:
        1. link de pagina  -> codigo de permiso
        2. link de pagina  -> nombre de funcion -> codigo de permiso
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS_PERMISOS_MAPA]
AS
SET NOCOUNT ON

    -- 1. Pagina -> permiso. Solo las que tienen link real y permiso.
    SELECT m.mnu_id, LOWER(m.mnu_link) AS mnu_link, p.prm_codigo
    FROM   [dbo].[Menus] m
    JOIN   [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso
    WHERE  m.mnu_link <> '#' AND m.mnu_link IS NOT NULL

    -- 2. Pagina -> funcion -> permiso
    SELECT LOWER(m.mnu_link) AS mnu_link, f.mfu_nombre, p.prm_codigo
    FROM   [dbo].[Menu_Funcion] f
    JOIN   [dbo].[Menus]   m ON m.mnu_id = f.mfu_menu
    JOIN   [dbo].[Permiso] p ON p.prm_id = f.mfu_permiso
    WHERE  m.mnu_link <> '#' AND m.mnu_link IS NOT NULL
GO


/* ========================================================================
   3. COMPROBACION
      Toda pagina con link debe tener permiso, o queda inaccesible.
   ======================================================================== */

SELECT 'paginas sin permiso (quedan cerradas)' AS control, COUNT(*) AS valor
FROM   [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_permiso IS NULL
UNION ALL SELECT 'paginas registradas',   COUNT(*) FROM [dbo].[Menus] WHERE mnu_link <> '#'
UNION ALL SELECT '  de ellas invisibles', COUNT(*) FROM [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_visible = 0
UNION ALL SELECT 'funciones mapeadas',    COUNT(*) FROM [dbo].[Menu_Funcion] WHERE mfu_permiso IS NOT NULL
GO
