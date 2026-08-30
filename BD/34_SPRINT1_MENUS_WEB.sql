USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     REGISTRA LAS PAGINAS QUE APARECIERON AL ARMAR LA WEB.
-- =============================================
-- Va DESPUES de 33_SPRINT1_AJUSTES.
--
-- POR QUE
--   El bloque 32 registro las pantallas previstas. Al construirlas
--   aparecieron dos formularios de detalle que no estaban en esa lista, y
--   una pantalla que conviene que si aparezca en el menu.
--
--   Recordar: una pagina sin fila en Menus NO SE PUEDE ABRIR. Token
--   .ExigirPagina() la deniega por defecto. Sin este bloque, esos dos
--   formularios darian acceso denegado aunque el .aspx exista.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. FORMULARIOS DE DETALLE QUE FALTABAN

      Van invisibles: se abren desde su listado, no desde el menu lateral.
      Heredan el permiso de la pantalla desde la que se abren, que es como
      estan registrados los demas detalles del sitio.
   ======================================================================== */

DECLARE @ORG  INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Organización' AND mnu_nivel = 2)
DECLARE @MANT INT = 1061   -- Sistema > Mantenedores

DECLARE @M TABLE
(
    nombre      NVARCHAR(200),
    descripcion NVARCHAR(400),
    padre       INT,
    link        NVARCHAR(400),
    permiso     NVARCHAR(200)
)

INSERT INTO @M VALUES
 (N'Valor de catálogo (detalle)', N'Alta y edición de un valor propio',
  @MANT, N'~/View/Sistema/Catalogos/CatalogoValor.aspx', N'VER CATALOGOS'),
 (N'Especialidad de usuario (detalle)', N'Registro de especialidad y certificación',
  @ORG,  N'~/View/Organizacion/Especialidades/UsuarioEspecialidad.aspx', N'VER ESPECIALIDADES USUARIO')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT  m.nombre, m.descripcion, 4, m.padre, 99, m.link, 0, NULL,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso)
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                    WHERE LOWER(x.mnu_link) = LOWER(m.link) COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   2. ESPECIALIDADES PASA A SER UNA PANTALLA DEL MENU

      Se habia registrado invisible, pensando que se abriria desde la ficha
      del usuario. Al construirla quedo claro que tiene sentido propio: es
      donde vive el panel de alertas de certificaciones por vencer que pide
      HU-017 escenario 3, y ese panel hay que poder mirarlo sin entrar
      primero a la ficha de alguien.
   ======================================================================== */

UPDATE [dbo].[Menus]
   SET mnu_visible = 1,
       mnu_nivel   = 3,
       mnu_orden   = 5,
       mnu_icon    = N'mdi mdi-certificate-outline'
 WHERE LOWER(mnu_link) = N'~/view/organizacion/especialidades/usuarioespecialidades.aspx' COLLATE DATABASE_DEFAULT
GO


/* ========================================================================
   3. EL SELECTOR DE CLIENTE                                        HU-002

      Se registra invisible y SIN permiso. No lleva permiso a proposito: se
      abre recien entrado, antes de haber elegido cliente, y exigir un
      permiso de cliente para poder elegir cliente seria un circulo. Token
      la trata como exenta.

      Se deja la fila igual para que el mantenedor de menus la muestre y
      nadie la de por inexistente al revisar el arbol.
   ======================================================================== */

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT N'Seleccionar cliente', N'Elegir con qué cliente se trabaja', 2, 1, 97, N'~/SeleccionarCliente.aspx', 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE LOWER(mnu_link) = N'~/seleccionarcliente.aspx' COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   4. TODO PERMISO NUEVO AL PERFIL ROOT
      Se repite por si el bloque 33 agrego alguno.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   COMPROBACION

      "paginas sin permiso" son las tres publicas o previas a elegir
      cliente: RecuperarClave, RestablecerClave y SeleccionarCliente.
      Cualquier otra sin permiso seria un error de registro.
   ======================================================================== */

SELECT 'paginas del Sprint 1' AS control, COUNT(*) AS valor, 17 AS esperado
FROM   [dbo].[Menus]
WHERE  mnu_link LIKE N'~/View/Organizacion/%'
    OR mnu_link LIKE N'~/View/Sistema/Catalogos/%'
    OR mnu_link LIKE N'~/View/Root/Mantenedores/PermisosUsuario/%'
    OR mnu_link IN (N'~/RecuperarClave.aspx', N'~/RestablecerClave.aspx', N'~/SeleccionarCliente.aspx')
UNION ALL
SELECT 'paginas SIN permiso', COUNT(*), 3
FROM   [dbo].[Menus] WHERE mnu_link <> N'#' AND mnu_permiso IS NULL
UNION ALL
SELECT 'permisos del perfil Root', COUNT(*), NULL
FROM   [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1
GO

-- El menu lateral tal como lo va a ver Root.
SELECT mnu_id, mnu_nombre, mnu_nivel, mnu_padre, mnu_orden, mnu_link, ISNULL(mnu_icon,'') AS icono
FROM   [dbo].[Menus]
WHERE  mnu_visible = 1
ORDER BY mnu_nivel, mnu_padre, mnu_orden
GO
