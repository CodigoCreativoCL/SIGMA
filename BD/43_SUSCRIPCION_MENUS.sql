USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     BLOQUE C.2 PERMISOS Y MENUS DE LAS PANTALLAS DE SUSCRIPCION.
-- =============================================
-- Va DESPUES de 42_SUSCRIPCION_ARCHIVOS.
--
-- RECORDATORIO
--   Una pagina sin fila en Menus NO SE PUEDE ABRIR. Token.ExigirPagina()
--   deniega por defecto. Las pantallas del bloque C existen como .aspx,
--   pero hasta este script no las abre nadie.
--
-- POR QUE HAY TANTOS PERMISOS
--   Porque las acciones de esta pantalla no son intercambiables. Ver el
--   estado de la suscripcion, emitir un periodo (que es facturar) y
--   verificar un pago contra la cartola (que es dar por cobrado) son tres
--   facultades distintas y las hace gente distinta. Un solo permiso
--   "administrar suscripciones" obligaria a darle a quien solo consulta la
--   capacidad de dar por pagada una factura.
--
--   DECLARAR PAGO se separa de VERIFICAR PAGO por la misma razon de fondo
--   que el SP no da por pagado lo declarado: quien declara es el cliente,
--   quien verifica es SIGMA. Si fuera un permiso solo, el cliente podria
--   verificarse a si mismo.
--
-- EL MULTICLIENTE
--   Estas pantallas filtran por el cliente seleccionado en la cabecera,
--   igual que Plantas o Areas. No se invento un permiso "ver todas las
--   suscripciones": quien administra la plataforma ya puede elegir
--   cualquier cliente (decision del bloque 30), asi que cambiar de cliente
--   en el selector es como se recorre la cartera. Una pantalla mas con su
--   propia regla de alcance seria una segunda forma de responder la misma
--   pregunta, y tarde o temprano las dos dirian cosas distintas.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. PERMISOS
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(200), nombre NVARCHAR(400), modulo NVARCHAR(200))

INSERT INTO @P (codigo, nombre, modulo) VALUES
 (N'VER PLANES COMERCIALES',    N'Consultar los planes y sus precios vigentes',   N'COMERCIAL'),
 (N'VER SUSCRIPCIONES',         N'Ver la suscripción del cliente',                N'COMERCIAL'),
 (N'CREAR EDITAR SUSCRIPCIONES',N'Crear la suscripción y mantener su contacto',   N'COMERCIAL'),
 (N'CAMBIAR PLAN SUSCRIPCION',  N'Subir o bajar de plan',                         N'COMERCIAL'),
 (N'EMITIR PERIODOS SUSCRIPCION',N'Emitir un período de cobro',                   N'COMERCIAL'),
 (N'VER PAGOS SUSCRIPCION',     N'Ver los pagos declarados y su estado',          N'COMERCIAL'),
 (N'DECLARAR PAGO SUSCRIPCION', N'Declarar una transferencia con su comprobante', N'COMERCIAL'),
 (N'VERIFICAR PAGOS SUSCRIPCION',N'Verificar o rechazar un pago contra la cartola',N'COMERCIAL')

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo,
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        NULL, 1, GETDATE(), 1, GETDATE(), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)
GO

PRINT 'Permisos de suscripción registrados.'
GO


/* ========================================================================
   2. MENU CONTENEDOR "COMERCIAL"

      Puede existir de antes (el sitio heredado ya tenia una rama
      Comercial). Se busca por nombre y solo se crea si falta, para no
      partir el arbol en dos ramas con el mismo titulo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
    VALUES (N'Comercial', N'Planes, suscripción y cobros', 2, 1, 5, N'#', 1, N'mdi mdi-briefcase-outline', NULL)
GO


/* ========================================================================
   3. PANTALLAS
   ======================================================================== */

DECLARE @COM INT = (SELECT MIN(mnu_id) FROM [dbo].[Menus] WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2)

DECLARE @M TABLE
(
    nombre      NVARCHAR(200),
    descripcion NVARCHAR(400),
    nivel       INT,
    padre       INT,
    orden       INT,
    link        NVARCHAR(400),
    visible     BIT,
    icono       NVARCHAR(100),
    permiso     NVARCHAR(200)
)

/* El orden arranca en 10 y no en 1: bajo Comercial ya cuelga "Cliente" con
   mnu_orden = 2, y empezar en 1 dejaba a Planes y a Cliente empatados en el
   mismo tramo, con el arbol resolviendo el desempate por id. Los cobros van
   despues de la ficha del cliente, que es el orden en que se trabaja. */

INSERT INTO @M VALUES
 -- Listados
 (N'Planes',         N'Planes comerciales y precios vigentes',   3, @COM, 10, N'~/View/Comercial/Suscripciones/Planes.aspx',        1, N'mdi mdi-tag-multiple-outline',  N'VER PLANES COMERCIALES'),
 (N'Suscripción',    N'Suscripción del cliente y su vigencia',   3, @COM, 11, N'~/View/Comercial/Suscripciones/Suscripciones.aspx', 1, N'mdi mdi-card-account-details-outline', N'VER SUSCRIPCIONES'),
 (N'Períodos',       N'Períodos de cobro emitidos',              3, @COM, 12, N'~/View/Comercial/Suscripciones/Periodos.aspx',      1, N'mdi mdi-calendar-clock',        N'VER SUSCRIPCIONES'),
 (N'Pagos',          N'Pagos declarados y su verificación',      3, @COM, 13, N'~/View/Comercial/Suscripciones/Pagos.aspx',         1, N'mdi mdi-cash-check',            N'VER PAGOS SUSCRIPCION'),
 -- Detalles: se abren desde su listado, no desde el menu lateral
 (N'Suscripción (detalle)', N'Ficha de la suscripción',          4, @COM, 99, N'~/View/Comercial/Suscripciones/Suscripcion.aspx',  0, NULL, N'VER SUSCRIPCIONES'),
 (N'Período (detalle)',     N'Detalle del período y sus pagos',  4, @COM, 99, N'~/View/Comercial/Suscripciones/Periodo.aspx',      0, NULL, N'VER SUSCRIPCIONES'),
 (N'Pago (detalle)',        N'Declaración y verificación de un pago', 4, @COM, 99, N'~/View/Comercial/Suscripciones/Pago.aspx',    0, NULL, N'VER PAGOS SUSCRIPCION')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT  m.nombre, m.descripcion, m.nivel, m.padre, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso)
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                    WHERE LOWER(x.mnu_link) = LOWER(m.link) COLLATE DATABASE_DEFAULT)
GO

/* Orden e ICONO se reafirman por si las filas ya existian de una corrida
   anterior: el INSERT de arriba no vuelve a tocarlas.

   LOS ICONOS: verificados contra MDI 7.4.47, que es lo que sirve el sitio
   desde Css/LookAndFeel/mdi/. Una clase de icono inexistente NO da error:
   simplemente no pinta, y el menu queda con un hueco que se lee como un
   problema de permisos. */
UPDATE m
   SET m.mnu_orden = v.orden,
       m.mnu_icon  = v.icono
FROM [dbo].[Menus] m
INNER JOIN (VALUES
    (N'~/view/comercial/suscripciones/planes.aspx',        10, N'mdi mdi-tag-multiple-outline'),
    (N'~/view/comercial/suscripciones/suscripciones.aspx', 11, N'mdi mdi-card-account-details-outline'),
    (N'~/view/comercial/suscripciones/periodos.aspx',      12, N'mdi mdi-calendar-clock'),
    (N'~/view/comercial/suscripciones/pagos.aspx',         13, N'mdi mdi-cash-check')
) v(link, orden, icono) ON LOWER(m.mnu_link) = v.link COLLATE DATABASE_DEFAULT
GO

UPDATE [dbo].[Menus]
   SET mnu_icon = N'mdi mdi-briefcase-outline'
 WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2
GO

UPDATE [dbo].[Archivo_Categoria]
   SET aca_icono = N'mdi mdi-receipt-text-outline'
 WHERE aca_codigo = N'COMPROBANTE PAGO'
GO

PRINT 'Pantallas de suscripción registradas.'
GO


/* ========================================================================
   4. FUNCIONES DENTRO DE CADA PANTALLA

      Una funcion es un permiso DENTRO de una pantalla: sin ella la
      pantalla se abre, pero en solo lectura. Aqui es donde se separa
      mirar de cobrar.
   ======================================================================== */

DECLARE @F TABLE (ruta NVARCHAR(400), nombre NVARCHAR(200), permiso NVARCHAR(200))

INSERT INTO @F VALUES
 (N'~/View/Comercial/Suscripciones/Suscripciones.aspx', N'Crear y editar',   N'CREAR EDITAR SUSCRIPCIONES'),
 (N'~/View/Comercial/Suscripciones/Suscripciones.aspx', N'Cambiar de plan',  N'CAMBIAR PLAN SUSCRIPCION'),
 (N'~/View/Comercial/Suscripciones/Periodos.aspx',      N'Emitir período',   N'EMITIR PERIODOS SUSCRIPCION'),
 (N'~/View/Comercial/Suscripciones/Pagos.aspx',         N'Declarar pago',    N'DECLARAR PAGO SUSCRIPCION'),
 (N'~/View/Comercial/Suscripciones/Pagos.aspx',         N'Verificar pago',   N'VERIFICAR PAGOS SUSCRIPCION')

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

PRINT 'Funciones de las pantallas de suscripción registradas.'
GO


/* ========================================================================
   5. QUIEN PUEDE QUE

      Root (1): todo, como siempre.

      Gerente Comercial (3): la cartera es su trabajo. Se le dan las ocho
      facultades MENOS ninguna: es quien cotiza, emite y cobra. Este perfil
      estaba con dos permisos y sin definir; esto no lo define entero -sigue
      pendiente que producto diga que mas ve- pero deja de estar vacio en lo
      que si le corresponde sin discusion.

      Administrador del Cliente (4): ve su propia suscripcion y declara sus
      pagos. NO verifica: verificarse a si mismo es exactamente lo que el
      flujo de 5.4 evita. NO emite periodos ni cambia de plan: eso lo
      ejecuta SIGMA despues de acordarlo, no el cliente por su cuenta.

      Los demas perfiles (Jefe, Planificador, Supervisor, Tecnico,
      Bodeguero) no reciben nada: la suscripcion no es asunto de
      mantenimiento.
   ======================================================================== */

-- Root: todo permiso existente.
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO

DECLARE @PP TABLE (perfil NVARCHAR(200), permiso NVARCHAR(200))

INSERT INTO @PP VALUES
 -- Gerente Comercial
 (N'2. Gerente Comercial', N'VER PLANES COMERCIALES'),
 (N'2. Gerente Comercial', N'VER SUSCRIPCIONES'),
 (N'2. Gerente Comercial', N'CREAR EDITAR SUSCRIPCIONES'),
 (N'2. Gerente Comercial', N'CAMBIAR PLAN SUSCRIPCION'),
 (N'2. Gerente Comercial', N'EMITIR PERIODOS SUSCRIPCION'),
 (N'2. Gerente Comercial', N'VER PAGOS SUSCRIPCION'),
 (N'2. Gerente Comercial', N'DECLARAR PAGO SUSCRIPCION'),
 (N'2. Gerente Comercial', N'VERIFICAR PAGOS SUSCRIPCION'),
 -- Administrador del Cliente
 (N'Administrador del Cliente', N'VER PLANES COMERCIALES'),
 (N'Administrador del Cliente', N'VER SUSCRIPCIONES'),
 (N'Administrador del Cliente', N'VER PAGOS SUSCRIPCION'),
 (N'Administrador del Cliente', N'DECLARAR PAGO SUSCRIPCION')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  pf.per_id, pm.prm_id, 1
FROM    @PP x
INNER JOIN [dbo].[Perfiles] pf  ON pf.per_nombre = x.perfil COLLATE DATABASE_DEFAULT
INNER JOIN [dbo].[Permiso] pm ON pm.prm_codigo = x.permiso COLLATE DATABASE_DEFAULT
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = pf.per_id AND pp.ppe_permiso = pm.prm_id)
GO

PRINT 'Permisos de suscripción asignados a los perfiles.'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

/* Se cuentan los ocho CODIGOS, no el modulo: bajo COMERCIAL ya vivian los
   ocho permisos heredados de Clientes y Reasignacion, asi que contar por
   modulo daba 16 y parecia un error que no existia. */
SELECT 'permisos de suscripción' AS control, COUNT(*) AS valor, 8 AS esperado
FROM   [dbo].[Permiso]
WHERE  prm_codigo IN (N'VER PLANES COMERCIALES', N'VER SUSCRIPCIONES',
                      N'CREAR EDITAR SUSCRIPCIONES', N'CAMBIAR PLAN SUSCRIPCION',
                      N'EMITIR PERIODOS SUSCRIPCION', N'VER PAGOS SUSCRIPCION',
                      N'DECLARAR PAGO SUSCRIPCION', N'VERIFICAR PAGOS SUSCRIPCION')
UNION ALL
SELECT 'pantallas de suscripción', COUNT(*), 7
FROM   [dbo].[Menus] WHERE mnu_link LIKE N'~/View/Comercial/Suscripciones/%'
UNION ALL
SELECT 'funciones de suscripción', COUNT(*), 5
FROM   [dbo].[Menu_Funcion] mf
INNER JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  m.mnu_link LIKE N'~/View/Comercial/Suscripciones/%'
UNION ALL
SELECT 'permisos del Gerente Comercial', COUNT(*), NULL
FROM   [dbo].[Perfil_Permiso] pp
INNER JOIN [dbo].[Perfiles] pf ON pf.per_id = pp.ppe_perfil
WHERE  pf.per_nombre = N'2. Gerente Comercial' COLLATE DATABASE_DEFAULT
UNION ALL
SELECT 'permisos del Administrador del Cliente', COUNT(*), NULL
FROM   [dbo].[Perfil_Permiso] pp
INNER JOIN [dbo].[Perfiles] pf ON pf.per_id = pp.ppe_perfil
WHERE  pf.per_nombre = N'Administrador del Cliente' COLLATE DATABASE_DEFAULT
GO
