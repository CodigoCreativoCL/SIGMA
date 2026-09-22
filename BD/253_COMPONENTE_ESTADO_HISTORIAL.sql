/* ============================================================================
   SIGMA — Bloque 253
   EL CAMBIO DE ESTADO DE UN COMPONENTE DEJA HUELLA                   HU-036 #3
   ----------------------------------------------------------------------------

   "Cuando cambio el estado de un componente, el cambio queda registrado con
   fecha, motivo y responsable." Hasta aqui UPD_ACTIVO_COMPONENTE pisaba el
   estado y solo quedaba la auditoria generica (quien y cuando), sin motivo
   ni historia. Ahora:

   1. Activo_Componente_Estado_Historial (append-only, prefijo ceh): una fila
      por cada cambio, con estado anterior, estado nuevo, motivo, quien y
      cuando (hora del pais del cliente).
   2. UPD_ACTIVO_COMPONENTE recibe @MOTIVO. Si el estado cambia y no viene
      motivo, rechaza (regla 6). Si el estado no cambia, el motivo se ignora.
   3. SEL_ACTIVO_COMPONENTE_ESTADO_HISTORIAL: la historia de un componente,
      la mas reciente primero.

   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente_Estado_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Componente_Estado_Historial]
    (
        [ceh_id]                    INT             NOT NULL IDENTITY(1,1),
        [ceh_cliente]               INT             NOT NULL,
        [ceh_activo_componente]     INT             NOT NULL,
        [ceh_estado_anterior]       INT             NULL,       -- NULL: primer registro conocido
        [ceh_estado_nuevo]          INT             NOT NULL,
        [ceh_motivo]                NVARCHAR(500)   NOT NULL,
        [ceh_usuario_creacion]      INT             NOT NULL,
        [ceh_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_CEH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_COMPONENTE_ESTADO_HISTORIAL PRIMARY KEY CLUSTERED ([ceh_id] ASC),
        CONSTRAINT FK_CEH_CLIENTE         FOREIGN KEY ([ceh_cliente])           REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CEH_COMPONENTE      FOREIGN KEY ([ceh_activo_componente]) REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_CEH_ESTADO_ANTERIOR FOREIGN KEY ([ceh_estado_anterior])   REFERENCES [dbo].[Activo_Componente_Estado] ([ace_id]),
        CONSTRAINT FK_CEH_ESTADO_NUEVO    FOREIGN KEY ([ceh_estado_nuevo])      REFERENCES [dbo].[Activo_Componente_Estado] ([ace_id]),
        CONSTRAINT FK_CEH_USUARIO         FOREIGN KEY ([ceh_usuario_creacion])  REFERENCES [dbo].[Usuario] ([usu_id])
    )

    CREATE NONCLUSTERED INDEX IX_CEH_COMPONENTE_FECHA
        ON [dbo].[Activo_Componente_Estado_Historial] ([ceh_activo_componente], [ceh_fecha_creacion] DESC)

    PRINT 'Tabla Activo_Componente_Estado_Historial creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Componente_Estado_Historial ya existe.'
GO

/* ========================================================================
   T-2107 - UPD_ACTIVO_COMPONENTE (bloque 253: @MOTIVO e historial de estado)
      El activo no se cambia (un componente pertenece a su maquina).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_COMPONENTE]
@ID                     INT,
@COMPONENTE_PADRE       INT = NULL,
@COMPONENTE_TIPO        INT = NULL,
@COMPONENTE_POSICION    INT = NULL,
@CRITICIDAD_NIVEL       INT = NULL,
@ACTIVO_COMPONENTE_ESTADO INT = NULL,
@CODIGO                 NVARCHAR(50) = NULL,
@NOMBRE                 NVARCHAR(200) = NULL,
@FECHA_INSTALACION      DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@HABILITADO             BIT = NULL,
@MOTIVO                 NVARCHAR(500) = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @ACTIVO INT
DECLARE @TIPO INT, @POS INT, @ESTADO_ACTUAL INT

SELECT @CLIENTE = aco_cliente, @ACTIVO = aco_activo,
       @TIPO = aco_componente_tipo, @POS = aco_componente_posicion,
       @ESTADO_ACTUAL = aco_activo_componente_estado
FROM   [dbo].[Activo_Componente] WHERE aco_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @MOTIVO = NULLIF(LTRIM(RTRIM(@MOTIVO)), '')

-- El cambio de estado es el unico que exige explicacion (HU-036 #3)
DECLARE @CAMBIA_ESTADO BIT = CASE WHEN @ACTIVO_COMPONENTE_ESTADO IS NOT NULL AND @ACTIVO_COMPONENTE_ESTADO <> @ESTADO_ACTUAL THEN 1 ELSE 0 END

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_activo=@ACTIVO AND aco_codigo=@CODIGO AND aco_id<>@ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN COMPONENTE CON EL CODIGO "%s" EN ESTE ACTIVO.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @COMPONENTE_PADRE IS NOT NULL AND @COMPONENTE_PADRE = @ID
    BEGIN
        RAISERROR('3.- UN COMPONENTE NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
        RETURN -1
    END

    -- Un tipo por posicion (excluyendo el propio registro).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                WHERE aco_activo=@ACTIVO AND aco_id<>@ID
                  AND aco_componente_tipo = ISNULL(@COMPONENTE_TIPO, @TIPO)
                  AND ISNULL(aco_componente_posicion,0) = ISNULL(@COMPONENTE_POSICION, ISNULL(@POS,0)))
    BEGIN
        RAISERROR('4.- YA HAY UN COMPONENTE DE ESE TIPO EN ESA POSICION DEL ACTIVO.', 16, 1)
        RETURN -1
    END

    IF @CAMBIA_ESTADO = 1 AND @MOTIVO IS NULL
    BEGIN
        RAISERROR('6.- INDIQUE EL MOTIVO DEL CAMBIO DE ESTADO DEL COMPONENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Componente]
    SET     aco_componente_padre          = @COMPONENTE_PADRE
           ,aco_componente_tipo           = ISNULL(@COMPONENTE_TIPO, aco_componente_tipo)
           ,aco_componente_posicion       = @COMPONENTE_POSICION
           ,aco_criticidad_nivel          = ISNULL(@CRITICIDAD_NIVEL, aco_criticidad_nivel)
           ,aco_activo_componente_estado  = ISNULL(@ACTIVO_COMPONENTE_ESTADO, aco_activo_componente_estado)
           ,aco_codigo                    = ISNULL(@CODIGO, aco_codigo)
           ,aco_nombre                    = ISNULL(@NOMBRE, aco_nombre)
           ,aco_fecha_instalacion         = @FECHA_INSTALACION
           ,aco_descripcion               = @DESCRIPCION
           ,aco_habilitado                = ISNULL(@HABILITADO, aco_habilitado)
           ,aco_usuario_actualizacion     = @USUARIO
           ,aco_fecha_actualizacion       = @DATE_NOW
    WHERE   aco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'UPD_ACTIVO_COMPONENTE @ID=' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='5.- NO FUE POSIBLE ACTUALIZAR EL COMPONENTE.'
        RETURN -1
    END

    -- La huella del cambio de estado: anterior, nuevo, motivo, quien y cuando
    IF @CAMBIA_ESTADO = 1
        INSERT INTO [dbo].[Activo_Componente_Estado_Historial]
               (ceh_cliente, ceh_activo_componente, ceh_estado_anterior, ceh_estado_nuevo, ceh_motivo, ceh_usuario_creacion, ceh_fecha_creacion)
        VALUES (@CLIENTE, @ID, @ESTADO_ACTUAL, @ACTIVO_COMPONENTE_ESTADO, @MOTIVO, @USUARIO, @DATE_NOW)

COMMIT TRANSACTION
RETURN(0)
GO

/* ========================================================================
   SEL_ACTIVO_COMPONENTE_ESTADO_HISTORIAL
      La historia de estados de un componente, la mas reciente primero.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE_ESTADO_HISTORIAL]
@COMPONENTE INT,
@CLIENTE    INT = NULL
AS
SET NOCOUNT ON

SELECT  h.ceh_id                                    AS CEH_ID
       ,h.ceh_activo_componente                     AS CEH_ACTIVO_COMPONENTE
       ,h.ceh_estado_anterior                       AS CEH_ESTADO_ANTERIOR
       ,ea.ace_nombre                               AS ESTADO_ANTERIOR
       ,h.ceh_estado_nuevo                          AS CEH_ESTADO_NUEVO
       ,en.ace_nombre                               AS ESTADO_NUEVO
       ,h.ceh_motivo                                AS CEH_MOTIVO
       ,h.ceh_usuario_creacion                      AS CEH_USUARIO_CREACION
       ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS RESPONSABLE
       ,h.ceh_fecha_creacion                        AS CEH_FECHA_CREACION
FROM    [dbo].[Activo_Componente_Estado_Historial] h
JOIN    [dbo].[Activo_Componente_Estado] en ON en.ace_id = h.ceh_estado_nuevo
LEFT JOIN [dbo].[Activo_Componente_Estado] ea ON ea.ace_id = h.ceh_estado_anterior
JOIN    [dbo].[Usuario] u ON u.usu_id = h.ceh_usuario_creacion
WHERE   h.ceh_activo_componente = @COMPONENTE
  AND   (@CLIENTE IS NULL OR h.ceh_cliente = @CLIENTE)
ORDER BY h.ceh_fecha_creacion DESC, h.ceh_id DESC
GO

PRINT '--- Historial de estado del componente listo (bloque 253).'
GO
