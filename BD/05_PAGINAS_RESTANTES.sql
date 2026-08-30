USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     REGISTRA LAS PAGINAS QUE FALTABAN EN EL ARBOL.
-- =============================================
-- Va DESPUES de 04_PERMISOS_POR_URL.
--
-- Desde el bloque 04, una pagina sin fila en Menus NO SE PUEDE ABRIR. Eso
-- es lo que se quiere -- el olvido falla del lado seguro -- pero obliga a
-- declarar TODAS las paginas, no solo las del menu lateral.
--
-- Estas usan Simple.master o Privacidad.master: son ventanas de detalle y
-- popups que se abren desde una grilla. Se registran invisibles y con el
-- permiso de la pantalla que las abre, que es la regla que ya seguian
-- cuando citaban el mismo Paginas.menu_N.Ver de su listado.
--
-- LAS DOS QUE NO SE REGISTRAN
--   ~/View/Comun/Procesamiento.aspx  es una pantalla de espera.
--   ~/Privacidad/Privacidad.aspx     es el aviso de privacidad publico.
--   No participan del modelo de permisos: van en Token.EXENTAS junto con
--   Default.aspx y Login.aspx. Son cuatro, y las cuatro son de
--   infraestructura, no de negocio.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @D TABLE (link NVARCHAR(200), nombre NVARCHAR(100), padre INT, codigo NVARCHAR(100))
INSERT INTO @D VALUES
 (N'~/View/Comun/Clientes/AsociarUsuario.aspx',                          N'Asociar usuario',            32, N'VER CLIENTE USUARIOS'),
 (N'~/View/Comun/Clientes/CargaMasivaUsuarios.aspx',                     N'Carga masiva de usuarios',   32, N'VER CLIENTE USUARIOS'),
 (N'~/View/Comun/Clientes/InformeUsuarioMarcacionFoto.aspx',             N'Foto de marcacion',          32, N'VER CLIENTE USUARIOS'),
 (N'~/View/Comun/Clientes/NuevoUsuario.aspx',                            N'Nuevo usuario del cliente',  32, N'VER CLIENTE USUARIOS'),
 (N'~/View/Comun/Clientes/NuevaInstalacion.aspx',                        N'Nueva instalacion',          32, N'VER CLIENTE IDENTIDAD'),
 (N'~/View/Root/ModulosSistema/NuevoModuloSistema.aspx',                 N'Modulo de sistema (detalle)', 2, N'VER MODULOS SISTEMA'),
 (N'~/View/Root/PrivacidadModuloSistema/NuevaPrivacidadModuloSistema.aspx', N'Privacidad (detalle)',     2, N'VER PRIVACIDAD')

INSERT INTO [dbo].[Menus] ([mnu_nombre],[mnu_descripcion],[mnu_nivel],[mnu_padre],
                           [mnu_orden],[mnu_link],[mnu_visible],[mnu_icon],[mnu_permiso])
SELECT d.nombre, d.nombre, 4, d.padre, 99, d.link, 0, N'', p.prm_id
FROM   @D d
JOIN   [dbo].[Permiso] p ON p.prm_codigo COLLATE DATABASE_DEFAULT = d.codigo COLLATE DATABASE_DEFAULT
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = d.link COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'paginas sin permiso (quedan cerradas)' AS control, COUNT(*) AS valor
FROM   [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_permiso IS NULL
UNION ALL SELECT 'paginas registradas',   COUNT(*) FROM [dbo].[Menus] WHERE mnu_link <> '#'
UNION ALL SELECT '  visibles en el menu', COUNT(*) FROM [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_visible = 1
UNION ALL SELECT '  invisibles',          COUNT(*) FROM [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_visible = 0
GO
