USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     CORRIGE LA FK DE PERFIL Y CARGA EL EQUIPO DE HAMBURGO.
-- =============================================
-- Va DESPUES de 37_SPRINT1_DATOS_DEMO.
--
-- 1. UN DEFECTO DE MODELO QUE ROMPIA LA SEGURIDAD
--
--    Cliente_Usuario_Perfil.cup_id_perfil tenia su clave foranea apuntando
--    a Usuario_Perfil.upe_id, es decir al id de una FILA de la tabla
--    intermedia, en vez de a Perfiles.per_id.
--
--    No es un detalle: FNC_USUARIO_TIENE_PERMISO -que es la unica fuente de
--    verdad de la autorizacion- hace
--
--        JOIN Perfil_Permiso ppe ON ppe.ppe_perfil = cup.cup_id_perfil
--
--    o sea que trata ese campo como un id de PERFIL. Con la FK apuntando a
--    otra parte, el valor guardado no era el perfil de la persona sino el
--    numero de una fila, y el motor resolvia los permisos de un perfil
--    distinto al asignado. Alguien podia terminar con mas permisos de los
--    que le correspondian sin que nada fallara.
--
--    Es el mismo error que ya se corrigio dentro de INS_CLIENTE en el
--    bloque 29, donde se insertaba UPE_ID en esa columna. Aqui se corrige
--    en la estructura, que es donde estaba el origen.
--
-- 2. EL EQUIPO DE HAMBURGO
--
--    Las cuentas del equipo (Root, Emilio, Catalina) son de PLATAFORMA: no
--    se afilian a ningun cliente. Para poder probar y demostrar el sistema
--    se cargan personas ficticias de Hamburgo, una por cada perfil base.
--
--    Para que un administrador de plataforma pueda igual trabajar dentro de
--    un cliente, se ajusta el selector: quien tiene la facultad de ver
--    clientes puede elegir cualquiera, sin necesidad de estar afiliado.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA CLAVE FORANEA, APUNTANDO A DONDE CORRESPONDE
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Cliente_Usuario_Perfil_Usuario_Perfil')
BEGIN
    ALTER TABLE [dbo].[Cliente_Usuario_Perfil]
        DROP CONSTRAINT [FK_Cliente_Usuario_Perfil_Usuario_Perfil]
    PRINT 'FK antigua (apuntaba a Usuario_Perfil.upe_id) eliminada.'
END
GO

/* Antes de recrearla hay que limpiar lo que ya no valdria: filas cuyo
   cup_id_perfil no sea un perfil existente. Son justamente las que se
   escribieron con el id equivocado. */
DELETE cp
FROM   [dbo].[Cliente_Usuario_Perfil] cp
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = cp.cup_id_perfil)
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CUP_PERFIL')
BEGIN
    ALTER TABLE [dbo].[Cliente_Usuario_Perfil] WITH CHECK
        ADD CONSTRAINT [FK_CUP_PERFIL] FOREIGN KEY ([cup_id_perfil])
            REFERENCES [dbo].[Perfiles] ([per_id])
    PRINT 'FK_CUP_PERFIL creada apuntando a Perfiles.per_id.'
END
ELSE PRINT 'FK_CUP_PERFIL ya existe.'
GO


/* ========================================================================
   2. FNC_RUT_DV

      Calcula el digito verificador en vez de escribirlo a mano. Los RUT de
      las personas ficticias tienen que pasar la validacion de INS_USUARIO,
      y un DV mal calculado a mano haria fallar la carga sin motivo
      aparente.

      Complementa FNC_RUT_VALIDO del bloque 29: una calcula, la otra
      comprueba, y las dos usan el mismo modulo 11.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_RUT_DV]
(
    @CUERPO VARCHAR(20)
)
RETURNS CHAR(1)
AS
BEGIN
    IF @CUERPO IS NULL OR @CUERPO LIKE '%[^0-9]%' RETURN NULL

    DECLARE @I     INT = LEN(@CUERPO)
    DECLARE @MULT  INT = 2
    DECLARE @SUMA  INT = 0
    DECLARE @RESTO INT

    WHILE @I >= 1
    BEGIN
        SET @SUMA = @SUMA + (CAST(SUBSTRING(@CUERPO, @I, 1) AS INT) * @MULT)
        SET @MULT = CASE WHEN @MULT = 7 THEN 2 ELSE @MULT + 1 END
        SET @I    = @I - 1
    END

    SET @RESTO = 11 - (@SUMA % 11)

    RETURN CASE WHEN @RESTO = 11 THEN '0'
                WHEN @RESTO = 10 THEN 'K'
                ELSE CAST(@RESTO AS CHAR(1)) END
END
GO


/* ========================================================================
   3. LAS CUENTAS DEL EQUIPO NO SON DE CLIENTE

      Root, Emilio y Catalina administran la plataforma. Afiliarlos a
      Hamburgo los mezclaria con el personal de la planta en cada listado y
      en cada asignacion de trabajo.
   ======================================================================== */

DELETE FROM [dbo].[Cliente_Instalacion_Usuario] WHERE ciu_id_usuario IN (1, 2, 3)
DELETE FROM [dbo].[Cliente_Usuario_Perfil]
 WHERE cup_id_cliente_usuario IN (SELECT ucl_id FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario IN (1, 2, 3))
DELETE FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario IN (1, 2, 3)
GO


/* ========================================================================
   4. EL PERSONAL DE HAMBURGO

      Una persona por perfil, mas dos tecnicos: un grupo de trabajo con un
      solo integrante no permite probar la regla del lider unico ni la
      asignacion a una cuadrilla.

      La contrasena inicial de todas es Sigma2026 y entra hasheada, porque
      pasa por INS_USUARIO.
   ======================================================================== */

DECLARE @U TABLE
(
    orden     INT IDENTITY(1,1),
    cuerpo    VARCHAR(20),
    nombre    VARCHAR(200),
    paterno   VARCHAR(100),
    materno   VARCHAR(100),
    correo    VARCHAR(200),
    telefono  VARCHAR(50),
    perfil    NVARCHAR(200)
)

INSERT INTO @U (cuerpo, nombre, paterno, materno, correo, telefono, perfil) VALUES
 ('15782341', 'Marcela',  'Aravena',  'Soto',     'marcela.aravena@hamburgo.cl',  '+56 9 8412 7730', N'Administrador del Cliente'),
 ('13094522', 'Rodrigo',  'Quezada',  'Molina',   'rodrigo.quezada@hamburgo.cl',  '+56 9 7733 2018', N'Jefe de Mantenimiento'),
 ('16204877', 'Emilio',   'Fuentes',  'Cárdenas', 'emilio.fuentes@hamburgo.cl',   '+56 9 6621 4409', N'Planificador de Mantenimiento'),
 ('17553019', 'Paula',    'Barriga',  'Núñez',    'paula.barriga@hamburgo.cl',    '+56 9 9014 5562', N'Supervisor de Mantenimiento'),
 ('18930244', 'Cristián', 'Muñoz',    'Tapia',    'cristian.munoz@hamburgo.cl',   '+56 9 5528 8871', N'Técnico de Mantenimiento'),
 ('19417688', 'Jonathan', 'Sepúlveda','Rojas',    'jonathan.sepulveda@hamburgo.cl','+56 9 8890 3345', N'Técnico de Mantenimiento'),
 ('14672905', 'Ximena',   'Leiva',    'Contreras','ximena.leiva@hamburgo.cl',     '+56 9 7126 9987', N'Bodeguero')

DECLARE @cuerpo VARCHAR(20), @nombre VARCHAR(200), @paterno VARCHAR(100),
        @materno VARCHAR(100), @correo VARCHAR(200), @telefono VARCHAR(50),
        @perfil NVARCHAR(200), @rut VARCHAR(100), @id INT

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT cuerpo, nombre, paterno, materno, correo, telefono, perfil FROM @U ORDER BY orden

OPEN cur
FETCH NEXT FROM cur INTO @cuerpo, @nombre, @paterno, @materno, @correo, @telefono, @perfil

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @rut = @cuerpo + '-' + [dbo].[FNC_RUT_DV](@cuerpo)

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_correo = @correo)
    BEGIN
        SET @id = NULL

        EXEC [dbo].[INS_USUARIO]
             @ID               = @id OUTPUT,
             @IDENTIFICADOR    = @rut,
             @CLIENTE          = 1,
             @LOGIN            = @correo,
             @PASSWORD         = 'Sigma2026',
             @NOMBRES          = @nombre,
             @APELLIDO_PATERNO = @paterno,
             @APELLIDO_MATERNO = @materno,
             @FONO1            = @telefono,
             @CORREO           = @correo,
             @USUARIO          = 1,
             @HABILITADO       = 1
    END

    SELECT @id = usu_id FROM [dbo].[Usuario] WHERE usu_correo = @correo

    -- Afiliacion al cliente
    IF @id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                                        WHERE ucl_id_usuario = @id AND ucl_id_cliente = 1)
        INSERT INTO [dbo].[Cliente_Usuario]
            (ucl_id_usuario, ucl_id_cliente, ucl_habilitado,
             ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
        VALUES (@id, 1, 1, 1, GETDATE(), 1, GETDATE())

    -- Perfil dentro del cliente
    IF @id IS NOT NULL
        INSERT INTO [dbo].[Cliente_Usuario_Perfil]
            (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
        SELECT  cu.ucl_id, p.per_id, 1, GETDATE()
        FROM    [dbo].[Cliente_Usuario] cu
        INNER JOIN [dbo].[Perfiles] p
                ON p.per_nombre COLLATE DATABASE_DEFAULT = @perfil COLLATE DATABASE_DEFAULT
               AND p.per_cliente IS NULL
        WHERE   cu.ucl_id_usuario = @id AND cu.ucl_id_cliente = 1
          AND   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario_Perfil]
                            WHERE cup_id_cliente_usuario = cu.ucl_id)

    -- Autorizacion en las plantas del cliente
    IF @id IS NOT NULL
        INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
            (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
             ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin)
        SELECT  ci.cin_id, @id, 1, GETDATE(), 1, CAST(GETDATE() AS DATE), NULL
        FROM    [dbo].[Cliente_Instalacion] ci
        WHERE   ci.cin_cliente = 1
          AND   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                            WHERE ciu_id_usuario = @id AND ciu_id_instalacion = ci.cin_id)

    FETCH NEXT FROM cur INTO @cuerpo, @nombre, @paterno, @materno, @correo, @telefono, @perfil
END

CLOSE cur
DEALLOCATE cur
GO

PRINT 'Personal de Hamburgo cargado.'
GO


/* ========================================================================
   5. EL SELECTOR PARA QUIEN ADMINISTRA LA PLATAFORMA            HU-002

      Un administrador de plataforma no esta afiliado a ningun cliente -no
      trabaja en ninguna planta- pero tiene que poder entrar a cualquiera
      para configurarlo. Es quien da de alta al cliente en HU-010: si no
      pudiera elegirlo despues, no podria terminar de dejarlo andando.

      La condicion no es "ser Root": es TENER la facultad de ver clientes.
      Asi, el dia que exista un perfil de plataforma nuevo, basta con darle
      ese permiso.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_ELEGIBLE]
@USUARIO INT
AS
SET NOCOUNT ON

DECLARE @ES_PLATAFORMA BIT = 0

/* Se mira el permiso por los perfiles GLOBALES de la persona
   (Usuario_Perfil), no por los de un cliente: justamente estamos
   resolviendo a que cliente puede entrar, asi que todavia no hay uno. */
IF EXISTS (SELECT 1
             FROM [dbo].[Usuario_Perfil] up
             JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = up.upe_perfil
             JOIN [dbo].[Permiso] p         ON p.prm_id      = pp.ppe_permiso
            WHERE up.upe_usuario = @USUARIO
              AND p.prm_codigo   = N'VER CLIENTES'
              AND p.prm_habilitado = 1)
    SET @ES_PLATAFORMA = 1

IF @ES_PLATAFORMA = 1
BEGIN
    SELECT  c.cli_id                              AS CLI_ID,
            c.cli_nombre                          AS CLI_NOMBRE,
            c.cli_razon_social                    AS CLI_RAZON_SOCIAL,
            c.cli_identificador                   AS CLI_IDENTIFICADOR,
            ISNULL(c.cli_nombre_fantasia, c.cli_nombre) AS CLI_ETIQUETA
    FROM    [dbo].[Cliente] c
    WHERE   ISNULL(c.cli_habilitado, 0) = 1
    ORDER BY c.cli_nombre

    RETURN(0)
END

SELECT  c.cli_id                              AS CLI_ID,
        c.cli_nombre                          AS CLI_NOMBRE,
        c.cli_razon_social                    AS CLI_RAZON_SOCIAL,
        c.cli_identificador                   AS CLI_IDENTIFICADOR,
        ISNULL(c.cli_nombre_fantasia, c.cli_nombre) AS CLI_ETIQUETA
FROM    [dbo].[Cliente_Usuario] cu
INNER JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
WHERE   cu.ucl_id_usuario = @USUARIO
  AND   ISNULL(cu.ucl_habilitado, 0) = 1
  AND   ISNULL(c.cli_habilitado, 0)  = 1
ORDER BY c.cli_nombre

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT  u.usu_id,
        u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS persona,
        u.usu_identificador                              AS rut,
        [dbo].[FNC_RUT_VALIDO](u.usu_identificador)      AS rut_valido,
        u.usu_correo                                     AS correo,
        ISNULL(p.per_nombre, '(sin perfil)')             AS perfil,
        (SELECT COUNT(*) FROM [dbo].[Cliente_Instalacion_Usuario]
          WHERE ciu_id_usuario = u.usu_id AND ciu_habilitado = 1) AS plantas
FROM    [dbo].[Usuario] u
INNER JOIN [dbo].[Cliente_Usuario] cu       ON cu.ucl_id_usuario = u.usu_id AND cu.ucl_id_cliente = 1
LEFT  JOIN [dbo].[Cliente_Usuario_Perfil] cp ON cp.cup_id_cliente_usuario = cu.ucl_id
LEFT  JOIN [dbo].[Perfiles] p               ON p.per_id = cp.cup_id_perfil
ORDER BY u.usu_id
GO

SELECT 'personal de Hamburgo'  AS control, COUNT(*) AS valor, 7 AS esperado
FROM   [dbo].[Cliente_Usuario] WHERE ucl_id_cliente = 1 AND ucl_habilitado = 1
UNION ALL
SELECT 'todos con perfil', COUNT(*), 7
FROM   [dbo].[Cliente_Usuario_Perfil]
UNION ALL
SELECT 'RUT invalidos (deben ser 0)', COUNT(*), 0
FROM   [dbo].[Usuario] WHERE [dbo].[FNC_RUT_VALIDO](usu_identificador) = 0
UNION ALL
SELECT 'cuentas de plataforma sin cliente', COUNT(*), 3
FROM   [dbo].[Usuario] u
WHERE  u.usu_id IN (1,2,3)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = u.usu_id)
UNION ALL
SELECT 'FK de perfil bien apuntada', COUNT(*), 1
FROM   sys.foreign_keys fk
JOIN   sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
WHERE  fk.name = 'FK_CUP_PERFIL'
  AND  OBJECT_NAME(fk.referenced_object_id) = 'Perfiles'
GO
