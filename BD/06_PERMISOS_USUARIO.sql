USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     PERMISOS ASIGNADOS POR USUARIO DENTRO DE UN CLIENTE.
-- =============================================
-- Ver SIGMA_ANEXO_D_PERMISOS_USUARIO.md
--
-- DEPENDENCIAS
--   Requiere: Cliente, Cliente_Usuario, Cliente_Instalacion, Usuario,
--             Cliente_Instalacion_Usuario, Cliente_Usuario_Perfil (02_FIX_SEGURIDAD)
--   Requiere: Permiso, Perfil_Permiso (bloque 1), Permiso_Ambito (04_CATALOGOS)
-- =============================================


/* ========================================================================
   0. VIGENCIA EN LA AUTORIZACION POR PLANTA
      FNC_USUARIO_TIENE_PERMISO exige que la autorizacion del usuario en la
      planta este VIGENTE. La tabla Cliente_Instalacion_Usuario viene de
      SGF y solo guarda el vinculo, sin estado ni fechas. Se le agregan
      aqui, con el mismo patron de ALTER del bloque 10.
   ======================================================================== */
IF COL_LENGTH('dbo.Cliente_Instalacion_Usuario','ciu_habilitado') IS NULL
    ALTER TABLE [dbo].[Cliente_Instalacion_Usuario]
        ADD [ciu_habilitado] BIT NOT NULL CONSTRAINT DF_CIU_HABILITADO DEFAULT 1
GO
IF COL_LENGTH('dbo.Cliente_Instalacion_Usuario','ciu_fecha_inicio') IS NULL
    ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_fecha_inicio] DATE NULL
GO
IF COL_LENGTH('dbo.Cliente_Instalacion_Usuario','ciu_fecha_fin') IS NULL
    ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_fecha_fin] DATE NULL
GO

/* ========================================================================
   1. PERMISO: AMBITO Y ASIGNABILIDAD
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Permiso]') AND name = 'prm_permiso_ambito')
BEGIN
    ALTER TABLE [dbo].[Permiso] ADD [prm_permiso_ambito] INT NULL
    PRINT 'Columna prm_permiso_ambito agregada a Permiso.'
END
ELSE
    PRINT 'Columna prm_permiso_ambito ya existe en Permiso.'
GO

-- Todo permiso preexistente queda como WEB antes de exigir NOT NULL.
UPDATE [dbo].[Permiso] SET [prm_permiso_ambito] = 1 WHERE [prm_permiso_ambito] IS NULL
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Permiso]')
            AND name = 'prm_permiso_ambito' AND is_nullable = 1)
    ALTER TABLE [dbo].[Permiso] ALTER COLUMN [prm_permiso_ambito] INT NOT NULL
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PRM_PERMISO_AMBITO')
    ALTER TABLE [dbo].[Permiso] WITH CHECK ADD CONSTRAINT [FK_PRM_PERMISO_AMBITO]
        FOREIGN KEY ([prm_permiso_ambito]) REFERENCES [dbo].[Permiso_Ambito] ([pam_id])
GO

-- Cierre de seguridad: si es 0, la pantalla del planificador no lo ofrece
-- y el SP de asignacion lo rechaza.
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Permiso]') AND name = 'prm_asignable_usuario')
BEGIN
    ALTER TABLE [dbo].[Permiso]
        ADD [prm_asignable_usuario] BIT NOT NULL CONSTRAINT DF_PRM_ASIGNABLE_USUARIO DEFAULT 0
    PRINT 'Columna prm_asignable_usuario agregada a Permiso.'
END
ELSE
    PRINT 'Columna prm_asignable_usuario ya existe en Permiso.'
GO


/* ========================================================================
   2. LOS CUATRO PERMISOS
      Los tres de terreno son asignables a una persona.
      El de asignar NO lo es: nadie se otorga la facultad de otorgar.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = N'ASIGNAR PERMISO TERRENO')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_modulo], [prm_descripcion],
                                 [prm_permiso_ambito], [prm_asignable_usuario],
                                 [prm_usuario_creacion], [prm_fecha_creacion], [prm_habilitado])
    VALUES (N'ASIGNAR PERMISO TERRENO', N'Asignar permisos de terreno', N'Seguridad',
            N'Permite otorgar y revocar permisos de terreno a tecnicos de sus plantas.',
            1, 0, 1, GETDATE(), 1)
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = N'CREAR ACTIVO TERRENO')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_modulo], [prm_descripcion],
                                 [prm_permiso_ambito], [prm_asignable_usuario],
                                 [prm_usuario_creacion], [prm_fecha_creacion], [prm_habilitado])
    VALUES (N'CREAR ACTIVO TERRENO', N'Crear activo desde terreno', N'Activos',
            N'Permite registrar una maquina no existente durante una ejecucion en planta.',
            2, 1, 1, GETDATE(), 1)
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = N'CREAR COMPONENTE TERRENO')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_modulo], [prm_descripcion],
                                 [prm_permiso_ambito], [prm_asignable_usuario],
                                 [prm_usuario_creacion], [prm_fecha_creacion], [prm_habilitado])
    VALUES (N'CREAR COMPONENTE TERRENO', N'Crear componente desde terreno', N'Activos',
            N'Permite registrar componentes, medidores, atributos y variables en planta.',
            2, 1, 1, GETDATE(), 1)
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = N'CREAR REPUESTO TERRENO')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_modulo], [prm_descripcion],
                                 [prm_permiso_ambito], [prm_asignable_usuario],
                                 [prm_usuario_creacion], [prm_fecha_creacion], [prm_habilitado])
    VALUES (N'CREAR REPUESTO TERRENO', N'Crear repuesto desde terreno', N'Repuestos',
            N'Permite registrar un repuesto fuera de catalogo durante una ejecucion.',
            2, 1, 1, GETDATE(), 1)
GO


/* ========================================================================
   3. CLIENTE_USUARIO_PERMISO
      La concesion cuelga de Cliente_Usuario, no de Usuario: un tecnico
      puede trabajar para dos clientes y el permiso no debe cruzarse.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Usuario_Permiso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Cliente_Usuario_Permiso]
    (
        [cpm_id]                        INT             NOT NULL IDENTITY(1,1),
        [cpm_cliente_usuario]           INT             NOT NULL,
        [cpm_permiso]                   INT             NOT NULL,
        [cpm_cliente_instalacion]       INT             NULL,       -- NULL = todas las plantas autorizadas
        [cpm_otorgado]                  BIT             NOT NULL CONSTRAINT DF_CPM_OTORGADO DEFAULT 1,
        [cpm_fecha_inicio]              DATE            NULL,
        [cpm_fecha_fin]                 DATE            NULL,
        [cpm_motivo]                    NVARCHAR(500)   NULL,
        [cpm_usuario_creacion]          INT             NOT NULL,   -- el planificador que lo otorgo
        [cpm_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CPM_FECHA_CREACION DEFAULT GETDATE(),
        [cpm_usuario_actualizacion]     INT             NULL,
        [cpm_fecha_actualizacion]       DATETIME        NULL,
        [cpm_habilitado]                BIT             NOT NULL CONSTRAINT DF_CPM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CLIENTE_USUARIO_PERMISO PRIMARY KEY CLUSTERED ([cpm_id] ASC),
        CONSTRAINT FK_CPM_CLIENTE_USUARIO FOREIGN KEY ([cpm_cliente_usuario])
            REFERENCES [dbo].[Cliente_Usuario] ([ucl_id]),
        CONSTRAINT FK_CPM_PERMISO FOREIGN KEY ([cpm_permiso])
            REFERENCES [dbo].[Permiso] ([prm_id]),
        CONSTRAINT FK_CPM_CLIENTE_INSTALACION FOREIGN KEY ([cpm_cliente_instalacion])
            REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT CK_CPM_VIGENCIA CHECK ([cpm_fecha_fin] IS NULL OR [cpm_fecha_inicio] IS NULL
                                          OR [cpm_fecha_fin] >= [cpm_fecha_inicio])
    )

    -- Una sola regla por combinacion: sin esto habria dos filas contradictorias.
    CREATE UNIQUE NONCLUSTERED INDEX UX_CPM_USUARIO_PERMISO_INSTALACION
        ON [dbo].[Cliente_Usuario_Permiso] ([cpm_cliente_usuario], [cpm_permiso], [cpm_cliente_instalacion])

    -- Resolucion del permiso en cada llamada de la API.
    CREATE NONCLUSTERED INDEX IX_CPM_CLIENTE_USUARIO_PERMISO
        ON [dbo].[Cliente_Usuario_Permiso] ([cpm_cliente_usuario], [cpm_permiso])
        INCLUDE ([cpm_cliente_instalacion], [cpm_otorgado], [cpm_fecha_inicio], [cpm_fecha_fin])
        WHERE [cpm_habilitado] = 1

    PRINT 'Tabla Cliente_Usuario_Permiso creada correctamente.'
END
ELSE
    PRINT 'Tabla Cliente_Usuario_Permiso ya existe.'
GO


/* ========================================================================
   4. AUDITORIA
      El mecanismo Log + Log_Tabla de SGF se dio de baja en el bloque 00:
      esas tablas nunca existieron en esta base. La auditoria de SIGMA es
      el dominio D10 Bitacora (bloque 23).
   ======================================================================== */


/* ========================================================================
   5. FNC_USUARIO_TIENE_PERMISO
      Unica fuente de verdad. La usan la API, los SP y el armado del token.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,            -- NULL = no se evalua alcance de planta
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST(GETDATE() AS DATE)
    DECLARE @POR_PERFIL      BIT  = 0
    DECLARE @OTORGADO        BIT
    DECLARE @RESULTADO       BIT  = 0

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- 1. Lo que entrega el perfil dentro de ese cliente
    IF EXISTS (SELECT 1
                 FROM [dbo].[Cliente_Usuario_Perfil] cup
                 JOIN [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_id_perfil
                WHERE cup.cup_id_cliente_usuario = @CLIENTE_USUARIO
                  AND ppe.ppe_permiso            = @PERMISO)
        SET @POR_PERFIL = 1

    -- 2. La regla de usuario mas especifica: la de la planta gana sobre la global
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario = @CLIENTE_USUARIO
       AND cpm.cpm_permiso         = @PERMISO
       AND cpm.cpm_habilitado      = 1
       AND (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
     ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END

    -- 3. La regla de usuario manda sobre el perfil, exista o no
    SET @RESULTADO = CASE WHEN @OTORGADO IS NOT NULL THEN @OTORGADO ELSE @POR_PERFIL END

    -- 4. Sin autorizacion vigente en la planta no hay permiso que valga
    IF @RESULTADO = 1 AND @INSTALACION IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            SET @RESULTADO = 0
    END

    RETURN @RESULTADO
END
GO


/* ========================================================================
   6. INS_CLIENTE_USUARIO_PERMISO
      Cinco validaciones antes de otorgar. Ver PATRON_SP.md seccion 3.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_USUARIO_PERMISO]
    @ID                     INT = NULL OUTPUT,
    @CLIENTE_USUARIO        INT,
    @PERMISO                INT,
    @CLIENTE_INSTALACION    INT = NULL,
    @OTORGADO               BIT = 1,
    @FECHA_INICIO           DATE = NULL,
    @FECHA_FIN              DATE = NULL,
    @MOTIVO                 NVARCHAR(500) = NULL,
    @CLIENTE                INT,
    @USUARIO                INT
AS
SET NOCOUNT ON

DECLARE @USUARIO_DESTINO INT

BEGIN
    -- 1. Quien otorga debe tener la facultad en ese cliente
    IF [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, N'ASIGNAR PERMISO TERRENO') = 0
    BEGIN
        RAISERROR('1.- NO TIENE LA FACULTAD DE ASIGNAR PERMISOS DE TERRENO.', 16, 1)
        RETURN -1
    END

    -- 2. El permiso debe ser asignable a una persona
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso]
                    WHERE prm_id = @PERMISO AND prm_asignable_usuario = 1 AND prm_habilitado = 1)
    BEGIN
        RAISERROR('2.- ESE PERMISO NO PUEDE ASIGNARSE A UN USUARIO.', 16, 1)
        RETURN -1
    END

    -- 3. El usuario destino debe estar afiliado a ese cliente
    SELECT @USUARIO_DESTINO = ucl_id_usuario
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id = @CLIENTE_USUARIO AND ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1
    IF @USUARIO_DESTINO IS NULL
    BEGIN
        RAISERROR('3.- EL USUARIO NO ESTA AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 4. Si se acota a una planta, el usuario debe estar autorizado en ella
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE ciu_id_usuario = @USUARIO_DESTINO
                          AND ciu_id_instalacion = @CLIENTE_INSTALACION
                          AND ciu_habilitado = 1)
    BEGIN
        RAISERROR('4.- EL USUARIO NO ESTA AUTORIZADO EN ESA PLANTA.', 16, 1)
        RETURN -1
    END

    -- 5. Nadie se otorga permisos a si mismo
    IF @USUARIO_DESTINO = @USUARIO
    BEGIN
        RAISERROR('5.- NO PUEDE ASIGNARSE PERMISOS A SI MISMO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente_Usuario_Permiso]
        (cpm_cliente_usuario, cpm_permiso, cpm_cliente_instalacion, cpm_otorgado,
         cpm_fecha_inicio, cpm_fecha_fin, cpm_motivo,
         cpm_usuario_creacion, cpm_fecha_creacion,
         cpm_usuario_actualizacion, cpm_fecha_actualizacion, cpm_habilitado)
    VALUES
        (@CLIENTE_USUARIO, @PERMISO, @CLIENTE_INSTALACION, @OTORGADO,
         @FECHA_INICIO, @FECHA_FIN, @MOTIVO,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] '6.- NO FUE POSIBLE ASIGNAR EL PERMISO.', @CLIENTE_USUARIO, @PERMISO
        RETURN -1
    END

COMMIT TRANSACTION
GO

PRINT 'Bloque de permisos por usuario aplicado correctamente.'
GO
