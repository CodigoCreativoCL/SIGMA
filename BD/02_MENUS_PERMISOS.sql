USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     MENUS Y PERMISOS DINAMICOS. RETIRA Paginas.cs.
-- =============================================
-- Va DESPUES de 01_REPARACION_NUCLEO. Depende de Permiso y Perfil_Permiso
-- (bloque 21) y de Permiso_Ambito (bloque 04).
--
-- EL PROBLEMA QUE RESUELVE
--   Paginas.cs era un espejo COMPILADO de Menus.mnu_id:
--       ver.mpe_menu = (int)Paginas.menu_4.Ver;
--   Cada menu nuevo obligaba a editar el enum, recompilar y desplegar. Y
--   ya se habia desincronizado: menu_9, menu_42, menu_1049, menu_1060 y
--   menu_1064 existian en el codigo y NO tenian fila en Menus.
--
--   Con un mantenedor de menus eso seria peor: el usuario crearia el menu
--   por pantalla y aun asi haria falta un desarrollador para el enum.
--
-- LA SOLUCION
--   El ancla deja de ser un id numerico y pasa a ser Permiso.prm_codigo,
--   que ya existe, es UNIQUE y trae ambito WEB/APP/AMBOS. La pagina dice
--       Token.Exigir('VER PERFILES')
--   y nunca mas menciona un id.
--
-- POR QUE NO UN mnu_codigo DE TEXTO LIBRE
--   Seria un segundo catalogo de permisos en paralelo al de SIGMA, y
--   volveriamos a tener dos fuentes que se desincronizan. Que es
--   exactamente el problema que estamos sacando.
--
-- LOS NODOS CONTENEDORES NO LLEVAN PERMISO
--   Los nodos con mnu_link = '#' quedan con mnu_permiso NULL. La regla en
--   MenusLateral es: un contenedor se muestra si alguno de sus hijos se
--   muestra. Asi no hay que mantener permisos de carpetas ni aparecen
--   menus vacios.
--
-- SE PUEDE ADOPTAR SIN MIGRAR NADA
--   Menu_Perfil, Menu_Funcion y Menu_Funcion_Perfil estan las tres VACIAS.
--   Hoy SecurityManagerPermisoMenu devuelve false cuando no hay fila, o
--   sea que el menu lateral solo lo ve el perfil Root. No hay asignaciones
--   que perder.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. ANCLAR EL ARBOL AL CATALOGO DE PERMISOS
   ======================================================================== */

IF COL_LENGTH('dbo.Menus','mnu_permiso') IS NULL
    ALTER TABLE [dbo].[Menus] ADD [mnu_permiso] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_MNU_PERMISO')
    ALTER TABLE [dbo].[Menus] WITH CHECK ADD CONSTRAINT [FK_MNU_PERMISO]
        FOREIGN KEY ([mnu_permiso]) REFERENCES [dbo].[Permiso] ([prm_id])
GO

IF COL_LENGTH('dbo.Menu_Funcion','mfu_permiso') IS NULL
    ALTER TABLE [dbo].[Menu_Funcion] ADD [mfu_permiso] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_MFU_PERMISO')
    ALTER TABLE [dbo].[Menu_Funcion] WITH CHECK ADD CONSTRAINT [FK_MFU_PERMISO]
        FOREIGN KEY ([mfu_permiso]) REFERENCES [dbo].[Permiso] ([prm_id])
GO


/* ========================================================================
   2. PERMISOS DE LAS PAGINAS QUE HOY EXISTEN
      Uno por cada hoja del arbol. Ambito 1 = WEB.
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(100), nombre NVARCHAR(200), modulo NVARCHAR(100))
INSERT INTO @P VALUES
 (N'VER PERFILES',                      N'Ver el mantenedor de perfiles',          N'SEGURIDAD'),
 (N'VER USUARIOS',                      N'Ver el mantenedor de usuarios',          N'SEGURIDAD'),
 (N'VER ACCESOS',                       N'Ver el mantenedor de accesos y menus',   N'SEGURIDAD'),
 (N'VER PAISES',                        N'Ver el mantenedor de paises',            N'SISTEMA'),
 (N'VER MODULOS SISTEMA',               N'Ver los modulos del sistema',            N'SISTEMA'),
 (N'VER PRIVACIDAD',                    N'Ver la privacidad de modulos',           N'SISTEMA'),
 (N'VER CLIENTES',                      N'Ver el listado comercial de clientes',   N'COMERCIAL'),
 (N'VER REASIGNACION CLIENTES',         N'Ver la reasignacion de clientes',        N'COMERCIAL'),
 (N'VER CLIENTE IDENTIDAD',             N'Ver la identidad del cliente',           N'CLIENTES'),
 (N'VER CLIENTE USUARIOS',              N'Ver los usuarios del cliente',           N'CLIENTES'),
 (N'VER TODO CLIENTES',                 N'Ver todos los clientes',                 N'COMERCIAL'),
 (N'VER TODO PAISES CLIENTES',          N'Ver clientes de todos los paises',       N'COMERCIAL'),
 (N'CREAR EDITAR CLIENTES',             N'Crear y editar clientes',                N'COMERCIAL'),
 (N'VER TODO REASIGNACION',             N'Ver todas las reasignaciones',           N'COMERCIAL'),
 (N'VER TODO PAISES REASIGNACION',      N'Ver reasignaciones de todos los paises', N'COMERCIAL'),
 (N'CREAR EDITAR REASIGNACION',         N'Crear y editar reasignaciones',          N'COMERCIAL'),
 (N'VER TODO CLIENTE IDENTIDAD',        N'Ver la identidad de todos los clientes', N'CLIENTES'),
 (N'VER TODO PAISES CLIENTE IDENTIDAD', N'Ver identidad de todos los paises',      N'CLIENTES'),
 (N'VER TODO CLIENTE USUARIOS',         N'Ver los usuarios de todos los clientes', N'CLIENTES'),
 (N'VER TODO PAISES CLIENTE USUARIOS',  N'Ver usuarios de todos los paises',       N'CLIENTES'),
 (N'CREAR EDITAR CLIENTE USUARIOS',     N'Crear y editar usuarios del cliente',    N'CLIENTES')

INSERT INTO [dbo].[Permiso] ([prm_codigo],[prm_nombre],[prm_modulo],[prm_permiso_ambito],[prm_usuario_creacion])
SELECT p.codigo, p.nombre, p.modulo, 1, 1
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = p.codigo)
GO


/* ========================================================================
   3. ENLAZAR CADA MENU HOJA CON SU PERMISO
      Los contenedores ('#') quedan en NULL a proposito.
   ======================================================================== */

UPDATE m SET m.mnu_permiso = p.prm_id
FROM [dbo].[Menus] m
JOIN (VALUES (4,N'VER PERFILES'),(5,N'VER USUARIOS'),(6,N'VER ACCESOS'),
             (8,N'VER PAISES'),(27,N'VER CLIENTES'),(31,N'VER REASIGNACION CLIENTES'),
             (40,N'VER CLIENTE IDENTIDAD'),(41,N'VER CLIENTE USUARIOS'),
             (1062,N'VER MODULOS SISTEMA'),(1063,N'VER PRIVACIDAD')
     ) v(id, codigo) ON v.id = m.mnu_id
JOIN [dbo].[Permiso] p ON p.prm_codigo = v.codigo
WHERE ISNULL(m.mnu_permiso,0) <> p.prm_id
GO


/* ========================================================================
   4. FUNCIONES DENTRO DE CADA PAGINA
      Menu_Funcion estaba vacia. Se puebla con las que Paginas.cs
      declaraba, ahora ancladas por codigo y no por id.
   ======================================================================== */

DECLARE @F TABLE (menu INT, nombre VARCHAR(100), codigo NVARCHAR(100))
INSERT INTO @F VALUES
 (27, 'Ver todo',        N'VER TODO CLIENTES'),
 (27, 'Ver todo paises', N'VER TODO PAISES CLIENTES'),
 (27, 'Crear y editar',  N'CREAR EDITAR CLIENTES'),
 (31, 'Ver todo',        N'VER TODO REASIGNACION'),
 (31, 'Ver todo paises', N'VER TODO PAISES REASIGNACION'),
 (31, 'Crear y editar',  N'CREAR EDITAR REASIGNACION'),
 (40, 'Ver todo',        N'VER TODO CLIENTE IDENTIDAD'),
 (40, 'Ver todo paises', N'VER TODO PAISES CLIENTE IDENTIDAD'),
 (41, 'Ver todo',        N'VER TODO CLIENTE USUARIOS'),
 (41, 'Ver todo paises', N'VER TODO PAISES CLIENTE USUARIOS'),
 (41, 'Crear y editar',  N'CREAR EDITAR CLIENTE USUARIOS')

INSERT INTO [dbo].[Menu_Funcion] ([mfu_nombre],[mfu_menu],[mfu_permiso])
SELECT f.nombre, f.menu, p.prm_id
FROM   @F f
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.codigo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_permiso = p.prm_id)
GO


/* ========================================================================
   5. EL PERFIL ROOT RECIBE TODO
      Sin esto nadie entra despues del cambio. Root es el perfil 1.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] ([ppe_perfil],[ppe_permiso],[ppe_usuario_creacion])
SELECT 1, p.prm_id, 1
FROM   [dbo].[Permiso] p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1 AND ppe_permiso = p.prm_id)
GO


/* ========================================================================
   6. SEL_USUARIO_PERMISOS
      Devuelve TODOS los codigos vigentes de un usuario en UNA consulta.
      Reemplaza las N llamadas a SEGURIDAD_SEL_MENUS_PERMISO que hacia el
      menu lateral: una por nodo, en cada render de cada pagina.

      Reglas, en orden:
        1. Lo que dan sus perfiles (globales y los del cliente).
        2. La regla puntual del usuario manda sobre el perfil: puede
           OTORGAR lo que el perfil no da y REVOCAR lo que si da.
        3. Se respeta vigencia y alcance por instalacion.
      Es la misma semantica de FNC_USUARIO_TIENE_PERMISO, pero en conjunto.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_PERMISOS]
    @USUARIO     INT,
    @CLIENTE     INT = NULL,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON

    DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

    -- Root ve todo. Se resuelve aqui y no en el codigo.
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] WHERE upe_usuario = @USUARIO AND upe_perfil = 1)
    BEGIN
        SELECT prm_codigo FROM [dbo].[Permiso] WHERE prm_habilitado = 1
        RETURN
    END

    DECLARE @PERFILES TABLE (perfil INT PRIMARY KEY)

    INSERT INTO @PERFILES (perfil)
    SELECT DISTINCT upe_perfil FROM [dbo].[Usuario_Perfil] WHERE upe_usuario = @USUARIO

    IF @CLIENTE IS NOT NULL
        INSERT INTO @PERFILES (perfil)
        SELECT DISTINCT cup.cup_id_perfil
        FROM   [dbo].[Cliente_Usuario_Perfil] cup
        JOIN   [dbo].[Cliente_Usuario]        ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario
        WHERE  ucl.ucl_id_usuario = @USUARIO
          AND  ucl.ucl_id_cliente = @CLIENTE
          AND  ISNULL(ucl.ucl_habilitado,0) = 1
          AND  cup.cup_id_perfil NOT IN (SELECT perfil FROM @PERFILES)

    -- Lo que entrega el perfil
    DECLARE @POR_PERFIL TABLE (permiso INT PRIMARY KEY)
    INSERT INTO @POR_PERFIL (permiso)
    SELECT DISTINCT ppe.ppe_permiso
    FROM   [dbo].[Perfil_Permiso] ppe
    JOIN   @PERFILES pf          ON pf.perfil  = ppe.ppe_perfil
    JOIN   [dbo].[Perfiles] per  ON per.per_id = ppe.ppe_perfil AND per.per_habilitado = 1

    -- La regla puntual del usuario: la de la planta gana sobre la global
    DECLARE @PUNTUAL TABLE (permiso INT PRIMARY KEY, otorgado BIT)
    IF @CLIENTE IS NOT NULL
        INSERT INTO @PUNTUAL (permiso, otorgado)
        SELECT x.cpm_permiso, x.cpm_otorgado
        FROM (
            SELECT cpm.cpm_permiso, cpm.cpm_otorgado,
                   ROW_NUMBER() OVER (PARTITION BY cpm.cpm_permiso
                                      ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END) rn
            FROM   [dbo].[Cliente_Usuario_Permiso] cpm
            JOIN   [dbo].[Cliente_Usuario]         ucl ON ucl.ucl_id = cpm.cpm_cliente_usuario
            WHERE  ucl.ucl_id_usuario = @USUARIO
              AND  ucl.ucl_id_cliente = @CLIENTE
              AND  ISNULL(ucl.ucl_habilitado,0) = 1
              AND  cpm.cpm_habilitado = 1
              AND  (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
              AND  (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
              AND  (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
        ) x
        WHERE x.rn = 1

    SELECT DISTINCT p.prm_codigo
    FROM   [dbo].[Permiso] p
    WHERE  p.prm_habilitado = 1
      AND  (
              EXISTS (SELECT 1 FROM @PUNTUAL q WHERE q.permiso = p.prm_id AND q.otorgado = 1)
              OR ( EXISTS (SELECT 1 FROM @POR_PERFIL r WHERE r.permiso = p.prm_id)
                   AND NOT EXISTS (SELECT 1 FROM @PUNTUAL q WHERE q.permiso = p.prm_id AND q.otorgado = 0) )
           )
GO


/* ========================================================================
   7. MANTENEDOR DE MENUS Y DE FUNCIONES
      No existia ningun INS/UPD/DEL de Menus ni de Menu_Funcion.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_MENUS]
    @ID          INT = NULL OUTPUT,
    @NOMBRE      VARCHAR(100),
    @DESCRIPCION VARCHAR(200) = NULL,
    @NIVEL       INT,
    @PADRE       INT,
    @ORDEN       INT,
    @LINK        VARCHAR(200) = '#',
    @VISIBLE     BIT = 1,
    @ICON        VARCHAR(100) = NULL,
    @PERMISO     INT = NULL
AS
SET NOCOUNT ON

    IF @PADRE <> 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_id = @PADRE)
    BEGIN
        RAISERROR('1.- EL MENU PADRE NO EXISTE.', 16, 1)
        RETURN -1
    END

    -- Una pagina sin permiso no la ve nadie salvo Root: se avisa temprano.
    IF @LINK <> '#' AND @PERMISO IS NULL
    BEGIN
        RAISERROR('2.- UNA PAGINA DEBE TENER UN PERMISO ASOCIADO.', 16, 1)
        RETURN -1
    END

    INSERT INTO [dbo].[Menus] ([mnu_nombre],[mnu_descripcion],[mnu_nivel],[mnu_padre],
                               [mnu_orden],[mnu_link],[mnu_visible],[mnu_icon],[mnu_permiso])
    VALUES (@NOMBRE, @DESCRIPCION, @NIVEL, @PADRE, @ORDEN, @LINK, @VISIBLE, @ICON, @PERMISO)

    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_MENUS]
    @ID          INT,
    @NOMBRE      VARCHAR(100),
    @DESCRIPCION VARCHAR(200) = NULL,
    @NIVEL       INT,
    @PADRE       INT,
    @ORDEN       INT,
    @LINK        VARCHAR(200) = '#',
    @VISIBLE     BIT = 1,
    @ICON        VARCHAR(100) = NULL,
    @PERMISO     INT = NULL
AS
SET NOCOUNT ON

    IF @PADRE = @ID
    BEGIN
        RAISERROR('1.- UN MENU NO PUEDE SER PADRE DE SI MISMO.', 16, 1)
        RETURN -1
    END

    IF @LINK <> '#' AND @PERMISO IS NULL
    BEGIN
        RAISERROR('2.- UNA PAGINA DEBE TENER UN PERMISO ASOCIADO.', 16, 1)
        RETURN -1
    END

    UPDATE [dbo].[Menus]
       SET mnu_nombre = @NOMBRE, mnu_descripcion = @DESCRIPCION, mnu_nivel = @NIVEL,
           mnu_padre  = @PADRE,  mnu_orden = @ORDEN, mnu_link = @LINK,
           mnu_visible = @VISIBLE, mnu_icon = @ICON, mnu_permiso = @PERMISO
     WHERE mnu_id = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[DEL_MENUS]
    @ID INT
AS
SET NOCOUNT ON

    IF EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @ID)
    BEGIN
        RAISERROR('1.- NO SE PUEDE ELIMINAR: EL MENU TIENE HIJOS.', 16, 1)
        RETURN -1
    END

    BEGIN TRANSACTION
        DELETE FROM [dbo].[Menu_Funcion_Perfil]
         WHERE mfp_menu_funcion IN (SELECT mfu_id FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @ID)
        DELETE FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @ID
        DELETE FROM [dbo].[Menu_Perfil]  WHERE mpe_menu = @ID
        DELETE FROM [dbo].[Menus]        WHERE mnu_id   = @ID
    COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_MENU_FUNCION]
    @ID      INT = NULL OUTPUT,
    @NOMBRE  VARCHAR(100),
    @MENU    INT,
    @PERMISO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_id = @MENU)
    BEGIN
        RAISERROR('1.- EL MENU NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MENU AND mfu_permiso = @PERMISO)
    BEGIN
        RAISERROR('2.- ESA FUNCION YA ESTA DEFINIDA EN ESTE MENU.', 16, 1)
        RETURN -1
    END

    INSERT INTO [dbo].[Menu_Funcion] ([mfu_nombre],[mfu_menu],[mfu_permiso])
    VALUES (@NOMBRE, @MENU, @PERMISO)

    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_MENU_FUNCION]
    @ID      INT,
    @NOMBRE  VARCHAR(100),
    @MENU    INT,
    @PERMISO INT
AS
SET NOCOUNT ON

    IF EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MENU AND mfu_permiso = @PERMISO AND mfu_id <> @ID)
    BEGIN
        RAISERROR('1.- ESA FUNCION YA ESTA DEFINIDA EN ESTE MENU.', 16, 1)
        RETURN -1
    END

    UPDATE [dbo].[Menu_Funcion]
       SET mfu_nombre = @NOMBRE, mfu_menu = @MENU, mfu_permiso = @PERMISO
     WHERE mfu_id = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[DEL_MENU_FUNCION]
    @ID INT
AS
SET NOCOUNT ON

    BEGIN TRANSACTION
        DELETE FROM [dbo].[Menu_Funcion_Perfil] WHERE mfp_menu_funcion = @ID
        DELETE FROM [dbo].[Menu_Funcion]        WHERE mfu_id = @ID
    COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_MENU_FUNCION]
    @ID   INT = NULL,
    @MENU INT = NULL
AS
SET NOCOUNT ON

    SELECT f.mfu_id, f.mfu_nombre, f.mfu_menu, m.mnu_nombre,
           f.mfu_permiso, p.prm_codigo, p.prm_nombre, p.prm_modulo
    FROM   [dbo].[Menu_Funcion] f
    JOIN   [dbo].[Menus]        m ON m.mnu_id = f.mfu_menu
    LEFT   JOIN [dbo].[Permiso] p ON p.prm_id = f.mfu_permiso
    WHERE  (@ID   IS NULL OR f.mfu_id   = @ID)
      AND  (@MENU IS NULL OR f.mfu_menu = @MENU)
    ORDER BY m.mnu_nombre, f.mfu_nombre
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PERMISO]
    @ID     INT = NULL,
    @MODULO NVARCHAR(100) = NULL
AS
SET NOCOUNT ON

    SELECT prm_id, prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
           prm_descripcion, prm_habilitado, prm_asignable_usuario
    FROM   [dbo].[Permiso]
    WHERE  (@ID     IS NULL OR prm_id     = @ID)
      AND  (@MODULO IS NULL OR prm_modulo = @MODULO)
    ORDER BY prm_modulo, prm_codigo
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS_PERMISOS_MAPA]
AS
SET NOCOUNT ON

    -- 1. menu -> codigo de permiso  (NULL en contenedores)
    SELECT m.mnu_id, p.prm_codigo
    FROM   [dbo].[Menus] m
    LEFT   JOIN [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso

    -- 2. funcion -> codigo de permiso
    SELECT f.mfu_id, p.prm_codigo
    FROM   [dbo].[Menu_Funcion] f
    LEFT   JOIN [dbo].[Permiso] p ON p.prm_id = f.mfu_permiso
GO


/* ========================================================================
   8. COMPROBACION
      'menus hoja sin permiso' debe ser 0.
   ======================================================================== */

SELECT 'menus hoja sin permiso'   AS control, COUNT(*) AS valor FROM [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_permiso IS NULL
UNION ALL SELECT 'menus contenedores',        COUNT(*) FROM [dbo].[Menus] WHERE mnu_link = '#'
UNION ALL SELECT 'permisos en catalogo',      COUNT(*) FROM [dbo].[Permiso]
UNION ALL SELECT 'funciones de menu',         COUNT(*) FROM [dbo].[Menu_Funcion]
UNION ALL SELECT 'permisos del perfil Root',  COUNT(*) FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1
GO
