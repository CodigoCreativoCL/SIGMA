/* ============================================================================
   SIGMA - Bloque 341
   LOS PERFILES LOS DEFINE CADA CLIENTE
   ----------------------------------------------------------------------------
   Hasta aqui los perfiles de cliente (Bodeguero, Jefe de Mantenimiento,
   Tecnico...) eran fijos y compartidos por todas las empresas. El cliente
   pidio (bug 8) que su Administrador cree los perfiles que su empresa usa
   -jardinero, mayordomo, jefe de turno- y decida que permisos da cada uno.

   El motor ya lo soportaba: SEL_USUARIO_PERMISOS calcula los permisos dentro
   del cliente desde Cliente_Usuario_Perfil + Perfil_Permiso, y Perfiles tiene
   per_cliente desde el bloque 30 (HU-015). Lo que faltaba:

     1. Permiso.prm_asignable_cliente: que puede repartir un cliente. Todo lo
        operativo y lo que ya tiene su Administrador; nunca lo de plataforma
        (comercial, sistema, paises, "ver todo").
     2. El permiso GESTIONAR PERFILES CLIENTE y el menu
        Cliente > Usuarios > Perfiles, ANTES de Usuarios: primero se crea el
        perfil, despues se asigna.
     3. Migracion (opcion A1): cada cliente recibe una copia PROPIA solo de
        los perfiles fijos que SUS usuarios ya usaban, con los mismos permisos;
        sus usuarios pasan a la copia. Una empresa que no usaba un perfil no lo
        recibe: cada cliente arma sus cargos (Bryan, 04-10-2026). Los fijos
        quedan deshabilitados como "Modelo SIGMA" para copiar. Nadie pierde
        acceso. El Administrador del Cliente sigue siendo del
        sistema: lo asigna SIGMA al crear la empresa y desde ahi arma el resto.
     4. SP que validan que el perfil sea del cliente de la sesion y que solo
        se den permisos asignables. La pantalla no es la que protege.

   Idempotente: se puede volver a correr.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

-- ---------------------------------------------------------------------------
-- 1) Que permisos puede repartir un cliente
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Permiso]') AND name = 'prm_asignable_cliente')
    ALTER TABLE [dbo].[Permiso] ADD [prm_asignable_cliente] BIT NOT NULL
        CONSTRAINT DF_PRM_ASIGNABLE_CLIENTE DEFAULT (0)
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'GESTIONAR PERFILES CLIENTE')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES (N'GESTIONAR PERFILES CLIENTE', N'Crear perfiles y decidir sus permisos', N'SEGURIDAD', 1,
            N'Crea los perfiles de la empresa (jardinero, jefe de turno...) y define que puede hacer cada uno.',
            1, GETDATE(), 1, 0)
GO

UPDATE p SET prm_asignable_cliente = 1
FROM   [dbo].[Permiso] p
WHERE  p.prm_habilitado = 1
  AND (
        p.prm_modulo IN (N'ACTIVOS', N'INVENTARIO', N'REPUESTOS', N'MANTENIMIENTO', N'ORDEN TRABAJO',
                         N'ORGANIZACION', N'PERMISO TRABAJO', N'TERCEROS', N'UTILIDADES')
     -- lo que ya tiene el Administrador del Cliente, salvo lo que mira mas alla de su empresa
     OR EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                JOIN [dbo].[Perfiles] pf ON pf.per_id = pp.ppe_perfil
                WHERE pp.ppe_permiso = p.prm_id AND pf.per_nombre = N'Administrador del Cliente' AND pf.per_cliente IS NULL)
     OR p.prm_codigo = N'GESTIONAR PERFILES CLIENTE'
      )
  AND p.prm_codigo NOT LIKE N'VER TODO%'
  AND p.prm_modulo NOT IN (N'COMERCIAL', N'SISTEMA')
GO
-- Renovar y pagar la suscripcion es del cliente aunque el modulo sea COMERCIAL
UPDATE [dbo].[Permiso] SET prm_asignable_cliente = 1
WHERE  prm_codigo IN (N'RENOVAR SUSCRIPCION', N'DECLARAR PAGO SUSCRIPCION', N'VER CATALOGOS', N'CREAR EDITAR CATALOGOS')
GO

-- Root y Administrador del Cliente gestionan perfiles
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pf.per_id, p.prm_id, 1, GETDATE()
FROM   [dbo].[Permiso] p
JOIN   [dbo].[Perfiles] pf ON pf.per_cliente IS NULL
                          AND pf.per_nombre IN (N'Root', N'Administrador del Cliente')
WHERE  p.prm_codigo = N'GESTIONAR PERFILES CLIENTE'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pf.per_id AND x.ppe_permiso = p.prm_id)
GO

-- ---------------------------------------------------------------------------
-- 2) Menu Cliente > Usuarios > Perfiles, antes de Usuarios
-- ---------------------------------------------------------------------------
DECLARE @PADRE INT = (SELECT TOP 1 m.mnu_id FROM [dbo].[Menus] m
                      JOIN [dbo].[Menus] c ON c.mnu_id = m.mnu_padre
                      WHERE m.mnu_nombre COLLATE DATABASE_DEFAULT = N'Usuarios' AND m.mnu_link = N'#'
                        AND c.mnu_nombre COLLATE DATABASE_DEFAULT = N'Cliente')
IF @PADRE IS NULL BEGIN RAISERROR('No existe el menu Cliente > Usuarios.', 16, 1) RETURN END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Clientes/Perfiles/PerfilesCliente.aspx')
BEGIN
    -- corre los hermanos visibles un lugar para dejar Perfiles primero
    UPDATE [dbo].[Menus] SET mnu_orden = mnu_orden + 1 WHERE mnu_padre = @PADRE AND mnu_orden < 99

    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Perfiles', N'Los perfiles de la empresa y lo que puede hacer cada uno.',
            3, @PADRE, 1, N'~/View/Clientes/Perfiles/PerfilesCliente.aspx', 1, N'mdi mdi-badge-account-horizontal-outline',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'GESTIONAR PERFILES CLIENTE'), 1)
END
GO

-- ---------------------------------------------------------------------------
-- 3) Migracion A1: cada cliente copia solo los perfiles fijos que usa
-- ---------------------------------------------------------------------------
DECLARE @MAPA TABLE (cliente INT, viejo INT, nuevo INT)

-- perfiles fijos de cliente (todos menos el Administrador, que sigue siendo del sistema)
DECLARE @FIJOS TABLE (per_id INT PRIMARY KEY)
INSERT INTO @FIJOS
SELECT per_id FROM [dbo].[Perfiles]
WHERE  per_tipo = 2 AND per_cliente IS NULL AND per_habilitado = 1
  AND  per_nombre <> N'Administrador del Cliente'

INSERT INTO [dbo].[Perfiles]
    (per_nombre, per_descripcion, per_tipo, per_cliente, per_solo_ejecucion, per_ambito, per_habilitado,
     per_usuario_creacion, per_fecha_creacion, per_usuario_act, per_fecha_act)
SELECT f.per_nombre, f.per_descripcion, 2, c.cli_id, f.per_solo_ejecucion, f.per_ambito, 1,
       1, GETDATE(), 1, GETDATE()
FROM   [dbo].[Perfiles] f
JOIN   @FIJOS x ON x.per_id = f.per_id
JOIN  (SELECT DISTINCT ucl.ucl_id_cliente AS cli_id, cup.cup_id_perfil AS per_id
       FROM   [dbo].[Cliente_Usuario_Perfil] cup
       JOIN   [dbo].[Cliente_Usuario] ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario) c
       ON c.per_id = f.per_id
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] y WHERE y.per_cliente = c.cli_id AND y.per_nombre = f.per_nombre)

INSERT INTO @MAPA (cliente, viejo, nuevo)
SELECT n.per_cliente, f.per_id, n.per_id
FROM   [dbo].[Perfiles] f
JOIN   @FIJOS x ON x.per_id = f.per_id
JOIN   [dbo].[Perfiles] n ON n.per_cliente IS NOT NULL AND n.per_nombre = f.per_nombre

-- los permisos de la copia = los del fijo
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT m.nuevo, pp.ppe_permiso, 1, GETDATE()
FROM   @MAPA m
JOIN   [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = m.viejo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] z WHERE z.ppe_perfil = m.nuevo AND z.ppe_permiso = pp.ppe_permiso)

-- cada usuario pasa a la copia de SU cliente
UPDATE cup SET cup.cup_id_perfil = m.nuevo
FROM   [dbo].[Cliente_Usuario_Perfil] cup
JOIN   [dbo].[Cliente_Usuario] ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario
JOIN   @MAPA m ON m.viejo = cup.cup_id_perfil AND m.cliente = ucl.ucl_id_cliente

-- el espejo de Usuario_Perfil (bloque 49) sigue al primero de sus clientes
UPDATE up SET up.upe_perfil = m.nuevo
FROM   [dbo].[Usuario_Perfil] up
JOIN   @MAPA m ON m.viejo = up.upe_perfil
WHERE  m.cliente = (SELECT MIN(ucl.ucl_id_cliente) FROM [dbo].[Cliente_Usuario] ucl
                    JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = ucl.ucl_id
                    WHERE ucl.ucl_id_usuario = up.upe_usuario AND cup.cup_id_perfil = m.nuevo)

-- los fijos quedan como plantilla: deshabilitados, nunca borrados
UPDATE f SET per_habilitado = 0, per_fecha_act = GETDATE()
FROM   [dbo].[Perfiles] f JOIN @FIJOS x ON x.per_id = f.per_id
GO

-- ---------------------------------------------------------------------------
-- 4) SP de la pantalla
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     SELECT PERFILES DEL CLIENTE (PROPIOS + ADMINISTRADOR DEL SISTEMA)
--                  @PLANTILLAS = 1 DEVUELVE LOS FIJOS DESHABILITADOS PARA COPIAR
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_PERFIL_CLIENTE]
    @CLIENTE    INT,
    @ID         INT = NULL,
    @FILTRO     NVARCHAR(200) = NULL,
    @HABILITADO BIT = NULL,
    @PLANTILLAS BIT = 0
AS
SET NOCOUNT ON

    SELECT  p.per_id                                   AS PER_ID,
            p.per_nombre                               AS PER_NOMBRE,
            ISNULL(p.per_descripcion, '')              AS PER_DESCRIPCION,
            p.per_ambito                               AS PER_AMBITO,
            p.per_solo_ejecucion                       AS PER_SOLO_EJECUCION,
            p.per_habilitado                           AS PER_HABILITADO,
            CAST(CASE WHEN p.per_cliente IS NULL THEN 1 ELSE 0 END AS BIT) AS ES_SISTEMA,
            (SELECT COUNT(*) FROM [dbo].[Cliente_Usuario_Perfil] cup
              JOIN [dbo].[Cliente_Usuario] ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario
             WHERE cup.cup_id_perfil = p.per_id AND ucl.ucl_id_cliente = @CLIENTE
               AND ISNULL(ucl.ucl_habilitado, 0) = 1)  AS USUARIOS,
            (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
              JOIN [dbo].[Permiso] pr ON pr.prm_id = pp.ppe_permiso AND pr.prm_asignable_cliente = 1
             WHERE pp.ppe_perfil = p.per_id)           AS PERMISOS,
            p.per_fecha_act                            AS PER_FECHA_ACT
    FROM    [dbo].[Perfiles] p
    WHERE   p.per_tipo = 2
      AND ( (@PLANTILLAS = 0 AND (p.per_cliente = @CLIENTE
                                  OR (p.per_cliente IS NULL AND p.per_habilitado = 1)))
         OR (@PLANTILLAS = 1 AND p.per_cliente IS NULL AND p.per_habilitado = 0) )
      AND  (@ID IS NULL OR p.per_id = @ID)
      AND  (@HABILITADO IS NULL OR p.per_habilitado = @HABILITADO)
      AND  (@FILTRO IS NULL OR p.per_nombre LIKE N'%' + @FILTRO + N'%' OR p.per_descripcion LIKE N'%' + @FILTRO + N'%')
    ORDER BY CASE WHEN p.per_cliente IS NULL THEN 0 ELSE 1 END, p.per_habilitado DESC, p.per_nombre
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     SELECT PERMISOS QUE EL CLIENTE PUEDE DAR, MARCANDO LOS DEL PERFIL
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_PERFIL_CLIENTE_PERMISO]
    @CLIENTE INT,
    @PERFIL  INT = NULL
AS
SET NOCOUNT ON

    -- Se puede leer un perfil propio, el Administrador o una plantilla del sistema
    IF @PERFIL IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                                            WHERE per_id = @PERFIL AND per_tipo = 2
                                              AND (per_cliente = @CLIENTE OR per_cliente IS NULL))
    BEGIN
        RAISERROR('1.- EL PERFIL NO ES DE ESTA EMPRESA.', 16, 1)
        RETURN -1
    END

    SELECT  pr.prm_id                          AS PRM_ID,
            pr.prm_codigo                      AS PRM_CODIGO,
            pr.prm_nombre                      AS PRM_NOMBRE,
            ISNULL(pr.prm_descripcion, '')     AS PRM_DESCRIPCION,
            ISNULL(pr.prm_modulo, 'OTROS')     AS PRM_MODULO,
            CAST(CASE WHEN pp.ppe_id IS NULL THEN 0 ELSE 1 END AS BIT) AS ASIGNADO
    FROM    [dbo].[Permiso] pr
    LEFT JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_permiso = pr.prm_id AND pp.ppe_perfil = @PERFIL
    WHERE   pr.prm_habilitado = 1 AND pr.prm_asignable_cliente = 1
    ORDER BY pr.prm_modulo, CASE WHEN pr.prm_codigo LIKE 'VER %' THEN 0 ELSE 1 END, pr.prm_nombre
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     INSERTA O ACTUALIZA UN PERFIL PROPIO DEL CLIENTE
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_PERFIL_CLIENTE]
    @ID             INT = NULL OUTPUT,
    @CLIENTE        INT,
    @NOMBRE         NVARCHAR(200),
    @DESCRIPCION    NVARCHAR(1000) = NULL,
    @AMBITO         INT,
    @SOLO_EJECUCION BIT = 0,
    @HABILITADO     BIT = 1,
    @USUARIO        INT
AS
SET NOCOUNT ON

    SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
    IF @ID = 0 SET @ID = NULL

    IF @NOMBRE = N''
    BEGIN RAISERROR('1.- ESCRIBA EL NOMBRE DEL PERFIL.', 16, 1) RETURN -1 END

    IF @AMBITO NOT IN (1, 2, 3)
    BEGIN RAISERROR('2.- ELIJA DONDE TRABAJA ESTE PERFIL: WEB, APP O AMBOS.', 16, 1) RETURN -1 END

    IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @ID AND per_cliente = @CLIENTE)
    BEGIN RAISERROR('3.- ESE PERFIL NO ES DE SU EMPRESA. LOS PERFILES DEL SISTEMA NO SE MODIFICAN.', 16, 1) RETURN -1 END

    IF EXISTS (SELECT 1 FROM [dbo].[Perfiles]
               WHERE per_nombre = @NOMBRE AND (per_cliente = @CLIENTE OR (per_cliente IS NULL AND per_habilitado = 1))
                 AND per_id <> ISNULL(@ID, 0))
    BEGIN RAISERROR('4.- YA EXISTE UN PERFIL LLAMADO "%s". ELIJA OTRO NOMBRE.', 16, 1, @NOMBRE) RETURN -1 END

    IF @ID IS NOT NULL AND @HABILITADO = 0
       AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario_Perfil] cup
                   JOIN [dbo].[Cliente_Usuario] ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario
                   WHERE cup.cup_id_perfil = @ID AND ISNULL(ucl.ucl_habilitado, 0) = 1)
    BEGIN RAISERROR('5.- HAY USUARIOS CON ESTE PERFIL. ASÍGNELES OTRO ANTES DE DESACTIVARLO.', 16, 1) RETURN -1 END

    IF @SOLO_EJECUCION = 1 AND @ID IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
                   WHERE pp.ppe_perfil = @ID AND p.prm_codigo = N'CERRAR OT')
    BEGIN RAISERROR('6.- ESTE PERFIL PUEDE CERRAR ÓRDENES. QUÍTELE ESE PERMISO ANTES DE MARCARLO COMO SÓLO EJECUCIÓN.', 16, 1) RETURN -1 END

BEGIN TRANSACTION

    IF @ID IS NULL
    BEGIN
        INSERT INTO [dbo].[Perfiles]
            (per_nombre, per_descripcion, per_tipo, per_cliente, per_solo_ejecucion, per_ambito, per_habilitado,
             per_usuario_creacion, per_fecha_creacion, per_usuario_act, per_fecha_act)
        VALUES (@NOMBRE, NULLIF(LTRIM(RTRIM(@DESCRIPCION)), N''), 2, @CLIENTE, ISNULL(@SOLO_EJECUCION, 0), @AMBITO,
                ISNULL(@HABILITADO, 1), @USUARIO, GETDATE(), @USUARIO, GETDATE())
        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
        UPDATE [dbo].[Perfiles]
        SET    per_nombre = @NOMBRE,
               per_descripcion = NULLIF(LTRIM(RTRIM(@DESCRIPCION)), N''),
               per_ambito = @AMBITO,
               per_solo_ejecucion = ISNULL(@SOLO_EJECUCION, per_solo_ejecucion),
               per_habilitado = ISNULL(@HABILITADO, per_habilitado),
               per_usuario_act = @USUARIO,
               per_fecha_act = GETDATE()
        WHERE  per_id = @ID AND per_cliente = @CLIENTE

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PERFIL_CLIENTE @ID=' + LTRIM(STR(ISNULL(@ID, 0))) + ',@CLIENTE=' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @MSG = '7.- NO FUE POSIBLE GUARDAR EL PERFIL.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     REEMPLAZA LOS PERMISOS DE UN PERFIL PROPIO DEL CLIENTE
--                  @PERMISOS: IDS SEPARADOS POR COMA. SOLO ENTRAN LOS ASIGNABLES.
--                  QUIEN PUEDE CREAR/EDITAR ALGO TAMBIEN LO PUEDE VER.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_PERFIL_CLIENTE_PERMISO]
    @PERFIL   INT,
    @CLIENTE  INT,
    @PERMISOS NVARCHAR(MAX),
    @USUARIO  INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @PERFIL AND per_cliente = @CLIENTE)
    BEGIN RAISERROR('1.- ESE PERFIL NO ES DE SU EMPRESA.', 16, 1) RETURN -1 END

    DECLARE @NUEVOS TABLE (prm_id INT PRIMARY KEY)
    INSERT INTO @NUEVOS (prm_id)
    SELECT DISTINCT p.prm_id
    FROM   STRING_SPLIT(ISNULL(@PERMISOS, N''), N',') s
    JOIN   [dbo].[Permiso] p ON p.prm_id = TRY_CAST(LTRIM(RTRIM(s.value)) AS INT)
    WHERE  p.prm_habilitado = 1 AND p.prm_asignable_cliente = 1

    -- "Crear y editar X" sin "Ver X" es una pantalla que no se puede abrir
    INSERT INTO @NUEVOS (prm_id)
    SELECT DISTINCT v.prm_id
    FROM   @NUEVOS n
    JOIN   [dbo].[Permiso] c ON c.prm_id = n.prm_id AND c.prm_codigo LIKE N'CREAR EDITAR %'
    JOIN   [dbo].[Permiso] v ON v.prm_codigo = N'VER ' + SUBSTRING(c.prm_codigo, 14, 200)
                            AND v.prm_habilitado = 1 AND v.prm_asignable_cliente = 1
    WHERE  NOT EXISTS (SELECT 1 FROM @NUEVOS x WHERE x.prm_id = v.prm_id)

    IF EXISTS (SELECT 1 FROM @NUEVOS n JOIN [dbo].[Permiso] p ON p.prm_id = n.prm_id AND p.prm_codigo = N'CERRAR OT')
       AND EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @PERFIL AND per_solo_ejecucion = 1)
    BEGIN RAISERROR('2.- ESTE PERFIL SÓLO EJECUTA TRABAJO: NO PUEDE CERRAR ÓRDENES.', 16, 1) RETURN -1 END

BEGIN TRANSACTION

    -- solo se tocan los asignables: lo que no ve el cliente no se lo puede quitar
    DELETE pp
    FROM   [dbo].[Perfil_Permiso] pp
    JOIN   [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso AND p.prm_asignable_cliente = 1
    WHERE  pp.ppe_perfil = @PERFIL
      AND  NOT EXISTS (SELECT 1 FROM @NUEVOS n WHERE n.prm_id = pp.ppe_permiso)

    INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
    SELECT @PERFIL, n.prm_id, @USUARIO, GETDATE()
    FROM   @NUEVOS n
    WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = @PERFIL AND x.ppe_permiso = n.prm_id)

    UPDATE [dbo].[Perfiles] SET per_usuario_act = @USUARIO, per_fecha_act = GETDATE() WHERE per_id = @PERFIL

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PERFIL_CLIENTE_PERMISO @PERFIL=' + LTRIM(STR(@PERFIL))
        EXEC [dbo].[INS_EXCEPCION] @MSG = '3.- NO FUE POSIBLE GUARDAR LOS PERMISOS.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'ASIGNABLES' AS QUE, COUNT(*) AS N FROM [dbo].[Permiso] WHERE prm_asignable_cliente = 1
UNION ALL SELECT 'PERFILES PROPIOS', COUNT(*) FROM [dbo].[Perfiles] WHERE per_cliente IS NOT NULL
UNION ALL SELECT 'USUARIOS EN PERFIL FIJO', COUNT(*) FROM [dbo].[Cliente_Usuario_Perfil] cup
          JOIN [dbo].[Perfiles] p ON p.per_id = cup.cup_id_perfil WHERE p.per_cliente IS NULL AND p.per_habilitado = 0
GO
