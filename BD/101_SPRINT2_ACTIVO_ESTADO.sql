USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-038 CAMBIAR EL ESTADO DE UN ACTIVO INDICANDO EL MOTIVO.
-- =============================================
-- Va DESPUES de 100_SPRINT2_CODIGO_AUTO_ACTIVOS.
--
-- QUE CUBRE
--   T-2146  Revision del modelo Activo_Estado_Historial.
--   T-2147  ACTIVO_ESTADO: el proceso completo en UNA transaccion, con
--           SET XACT_ABORT ON para que un error no deje datos a medias.
--   T-2148  Las reglas de negocio viven en el SP, no en la pantalla: la web
--           y la API tienen que obtener el MISMO resultado.
--   T-2149  SEL_ACTIVO_ESTADO_HISTORIAL: consulta el resultado del proceso
--           (la linea de tiempo de estados de un activo).
--
-- T-2146 - REVISION DEL MODELO
--   Activo_Estado_Historial (bloque 11) NO tiene codigo: es una tabla de
--   EVENTOS, no un maestro. Su llave util es (aeh_activo,
--   aeh_fecha_inicio_utc) y el tramo vigente es el que tiene
--   aeh_fecha_fin_utc NULL. La plantilla de la tarea habla de "codigo unico
--   por cliente" por herencia; aqui no aplica.
--
--   NOMBRE: el SEL se llama SEL_ACTIVO_ESTADO_HISTORIAL y no SEL_ACTIVO_ESTADO
--   porque ese ya existe (el catalogo de estados que usa el combo de la ficha
--   de activo, bloque 74). Son cosas distintas: uno es el catalogo, el otro
--   la historia.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-2147 / T-2148 - ACTIVO_ESTADO
      El proceso: cierra el tramo de estado vigente, abre uno nuevo con el
      motivo, y deja el activo con su estado actual. Todo en una transaccion
      con XACT_ABORT ON. Las reglas (activo del cliente, estado valido, no
      repetir, motivo obligatorio cuando saca de operacion) estan AQUI para
      que la web y la API den el mismo resultado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[ACTIVO_CAMBIAR_ESTADO]
@ID             INT = NULL OUTPUT,
@ACTIVO         INT,
@CLIENTE        INT,
@NUEVO_ESTADO   INT,
@MOTIVO         NVARCHAR(500) = NULL,
@ORDEN_TRABAJO  INT = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @NOW_UTC DATETIME = GETUTCDATE()
DECLARE @ESTADO_ACTUAL INT

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
         aeh_motivo, aeh_orden_trabajo, aeh_usuario_creacion, aeh_fecha_creacion)
    VALUES
        (@CLIENTE, @ACTIVO, @NUEVO_ESTADO, @NOW_UTC, NULL,
         NULLIF(@MOTIVO, N''), @ORDEN_TRABAJO, @USUARIO, @DATE_NOW)

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


/* ========================================================================
   T-2149 - SEL_ACTIVO_ESTADO_HISTORIAL
      La linea de tiempo de estados de un activo. Devuelve el nombre del
      estado, el usuario que lo cambio y si el tramo esta vigente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ESTADO_HISTORIAL]
@ID       INT = NULL,
@ACTIVO   INT = NULL,
@CLIENTE  INT = NULL

AS
SET NOCOUNT ON

    SELECT  aeh.aeh_id                  AS AEH_ID
           ,aeh.aeh_cliente             AS AEH_CLIENTE
           ,aeh.aeh_activo              AS AEH_ACTIVO
           ,aeh.aeh_activo_estado       AS AEH_ACTIVO_ESTADO
           ,aeh.aeh_fecha_inicio_utc    AS AEH_FECHA_INICIO_UTC
           ,aeh.aeh_fecha_fin_utc       AS AEH_FECHA_FIN_UTC
           ,aeh.aeh_motivo              AS AEH_MOTIVO
           ,aeh.aeh_orden_trabajo       AS AEH_ORDEN_TRABAJO
           ,aes.aes_nombre              AS ESTADO_NOMBRE
           ,act.act_codigo              AS ACTIVO_CODIGO
           ,act.act_nombre              AS ACTIVO_NOMBRE
           ,CASE WHEN aeh.aeh_fecha_fin_utc IS NULL THEN 1 ELSE 0 END AS VIGENTE
           ,LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO_NOMBRE
    FROM    [dbo].[Activo_Estado_Historial] aeh
    INNER JOIN [dbo].[Activo_Estado] aes ON aes.aes_id = aeh.aeh_activo_estado
    INNER JOIN [dbo].[Activo]        act ON act.act_id = aeh.aeh_activo
    LEFT  JOIN [dbo].[Usuario]       u   ON u.usu_id   = aeh.aeh_usuario_creacion
    WHERE   (@ID IS NULL OR aeh.aeh_id = @ID)
      AND   (@ACTIVO IS NULL OR aeh.aeh_activo = @ACTIVO)
      AND   (@CLIENTE IS NULL OR aeh.aeh_cliente = @CLIENTE)
    ORDER BY aeh.aeh_fecha_inicio_utc DESC
GO


PRINT '101_SPRINT2_ACTIVO_CAMBIAR_ESTADO aplicado: ACTIVO_ESTADO y SEL_ACTIVO_ESTADO_HISTORIAL.'
GO
