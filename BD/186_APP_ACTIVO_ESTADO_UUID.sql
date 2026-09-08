USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     IDEMPOTENCIA POR UUID EN EL CAMBIO DE ESTADO DEL ACTIVO.
-- =============================================
-- HU-038. La app encola el cambio de estado como toda captura de terreno: se
-- hace delante del equipo y ahi casi nunca hay señal. El outbox genera el uuid
-- AL ENCOLAR y reintenta hasta tener un veredicto del servidor.
--
-- Sin este parametro, un reintento cuya primera respuesta se perdio no creaba
-- un duplicado —lo frenaba la regla 3, "el activo ya esta en ese estado"—,
-- pero devolvia un ERROR de negocio por algo que en realidad SI se habia
-- guardado. La pantalla mostraba "no se pudo cambiar" sobre un cambio hecho, y
-- la fila quedaba muerta en Pendientes. Es peor que el duplicado: miente.
--
-- El corte por uuid va ANTES de las reglas, igual que en INS_PERMISO_TRABAJO:
-- un reintento no tiene por que volver a pasar validaciones que ya paso.
--
-- @UUID es OPCIONAL, asi que la web sigue llamando exactamente igual.
-- =============================================
SET NOCOUNT ON
GO

/* ---- La columna donde vive el uuid del tramo ----
   NULL-able a proposito: los tramos que ya existen —y los que abre la web—
   no tienen uuid y no deben tenerlo. */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Activo_Estado_Historial]')
                  AND name = 'aeh_uuid')
BEGIN
    ALTER TABLE [dbo].[Activo_Estado_Historial]
        ADD aeh_uuid UNIQUEIDENTIFIER NULL
END
GO

/* El indice es la garantia de verdad. El chequeo del SP evita el trabajo, pero
   dos reintentos simultaneos —el usuario aprieta reenviar mientras el
   despachador ya salio— pueden pasar los dos por el SELECT antes de que
   cualquiera inserte. Filtrado, porque los tramos de la web son todos NULL y
   un unique normal solo dejaria uno. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('[dbo].[Activo_Estado_Historial]')
                  AND name = 'UQ_AEH_UUID')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_AEH_UUID
        ON [dbo].[Activo_Estado_Historial](aeh_uuid)
        WHERE aeh_uuid IS NOT NULL
END
GO

CREATE OR ALTER PROCEDURE [dbo].[ACTIVO_CAMBIAR_ESTADO]
@ID             INT = NULL OUTPUT,
@ACTIVO         INT,
@CLIENTE        INT,
@NUEVO_ESTADO   INT,
@MOTIVO         NVARCHAR(500) = NULL,
@ORDEN_TRABAJO  INT = NULL,
/* IDEMPOTENCIA (08-09-2026). Ver la cabecera del script. Opcional: la web no
   lo manda y no tiene por que. */
@UUID           UNIQUEIDENTIFIER = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @NOW_UTC DATETIME = GETUTCDATE()
DECLARE @ESTADO_ACTUAL INT

-- ---- Idempotencia: si el uuid ya paso, no se repite ----
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el llamador
       manda 0. Sin esto, TODO cambio con uuid responderia "ya estaba
       registrado" y no se guardaria ninguno. */
    SET @ID = NULL

    SELECT @ID = aeh_id FROM [dbo].[Activo_Estado_Historial] WHERE aeh_uuid = @UUID

    IF (@ID IS NOT NULL) RETURN(0)
END

-- ---- Reglas de negocio (antes de la transaccion) ----

-- 1) El activo tiene que ser del cliente.
SELECT @ESTADO_ACTUAL = act_activo_estado
FROM   [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE

IF @ESTADO_ACTUAL IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- 2) El estado destino existe y esta habilitado.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE aes_id = @NUEVO_ESTADO AND aes_habilitado = 1)
BEGIN
    RAISERROR('2.- EL ESTADO INDICADO NO EXISTE.', 16, 1)
    RETURN -1
END

-- 3) No cambiar al mismo estado (no se registra un cambio que no cambia nada).
IF @ESTADO_ACTUAL = @NUEVO_ESTADO
BEGIN
    RAISERROR('3.- EL ACTIVO YA ESTA EN ESE ESTADO.', 16, 1)
    RETURN -1
END

-- 4) Motivo obligatorio cuando el activo SALE de operacion: detenido (3),
--    fuera de servicio (5) o dado de baja (6). Sin motivo no se puede
--    reconstruir por que se paro.
SET @MOTIVO = LTRIM(RTRIM(ISNULL(@MOTIVO, N'')))
IF @NUEVO_ESTADO IN (3, 5, 6) AND LEN(@MOTIVO) = 0
BEGIN
    RAISERROR('4.- ESTE CAMBIO DE ESTADO REQUIERE INDICAR EL MOTIVO.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    -- Cierra el tramo vigente (el que no tiene fin).
    UPDATE [dbo].[Activo_Estado_Historial]
    SET    aeh_fecha_fin_utc = @NOW_UTC
    WHERE  aeh_activo = @ACTIVO AND aeh_fecha_fin_utc IS NULL

    -- Abre el tramo nuevo.
    INSERT [dbo].[Activo_Estado_Historial]
        (aeh_cliente, aeh_activo, aeh_activo_estado, aeh_fecha_inicio_utc, aeh_fecha_fin_utc,
         aeh_motivo, aeh_orden_trabajo, aeh_uuid, aeh_usuario_creacion, aeh_fecha_creacion)
    VALUES
        (@CLIENTE, @ACTIVO, @NUEVO_ESTADO, @NOW_UTC, NULL,
         NULLIF(@MOTIVO, N''), @ORDEN_TRABAJO, @UUID, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    -- Deja el activo con su estado actual (denormalizacion controlada: la
    -- ficha lee act_activo_estado sin recorrer la historia).
    UPDATE [dbo].[Activo]
    SET    act_activo_estado = @NUEVO_ESTADO,
           act_usuario_actualizacion = @USUARIO,
           act_fecha_actualizacion = @DATE_NOW
    WHERE  act_id = @ACTIVO

COMMIT TRANSACTION

RETURN(0)
GO
