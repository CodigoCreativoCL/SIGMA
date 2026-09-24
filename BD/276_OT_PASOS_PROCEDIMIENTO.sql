USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     PONERLE LOS PASOS DE UN PROCEDIMIENTO A UNA ORDEN.
-- =============================================
-- UNA ORDEN CORRECTIVA NACIA SIN PASOS Y NO HABIA COMO PONERSELOS
--
-- Los pasos de una orden salen hoy de tres lados:
--   INS_ORDEN_TRABAJO_OCURRENCIA  copia los del plan -la actividad del hito
--                                 y, si referencia un procedimiento, uno por
--                                 cada paso suyo-
--   INS_ORDEN_TRABAJO_HALLAZGO    los del hallazgo de inspeccion
--   API_INS_ORDEN_TRABAJO_PASO    los que agrega el tecnico en terreno
--
-- INS_ORDEN_TRABAJO -la correctiva que se crea desde la web, HU-110- no toca
-- Orden_Trabajo_Paso: la orden nace vacia. Quien la crea sabe lo que hay que
-- hacer y no tenia donde escribirlo, asi que el tecnico llegaba a la maquina
-- con un titulo y ninguna instruccion.
--
-- Este copia los pasos de UN procedimiento a la orden, igual que lo hace la
-- ocurrencia: el nombre y la instruccion se COPIAN, no se referencian. Si
-- manana alguien edita el procedimiento, la orden ya ejecutada sigue diciendo
-- lo que se mando a hacer ese dia.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_PASO_PROCEDIMIENTO]
    @ID            INT = NULL OUTPUT,
    @ORDEN         INT,
    @PROCEDIMIENTO INT,
    @USUARIO       INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @ESTADO INT, @NOW DATETIME, @PAIS INT, @DESDE INT

SELECT  @CLIENTE = otr_cliente, @ESTADO = otr_orden_trabajo_estado
  FROM  [dbo].[Orden_Trabajo]
 WHERE  otr_id = @ORDEN

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE.', 16, 1)
    RETURN -1
END

/* Una orden cerrada no recibe pasos nuevos: lo que se hizo, se hizo. */
IF @ESTADO = 4
BEGIN
    RAISERROR('2.- LA ORDEN YA ESTA CERRADA: NO SE LE PUEDEN AGREGAR PASOS.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Procedimiento]
                WHERE prc_id = @PROCEDIMIENTO AND prc_cliente = @CLIENTE)
BEGIN
    RAISERROR('3.- EL PROCEDIMIENTO NO EXISTE O ES DE OTRO CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Los pasos nuevos van DESPUES de los que ya tiene: si la orden ya traia
   pasos del plan, los del procedimiento se suman al final y no se mezclan
   en medio de lo que el tecnico ya venia siguiendo. */
SELECT @DESDE = ISNULL(MAX(otp_orden), 0)
  FROM [dbo].[Orden_Trabajo_Paso]
 WHERE otp_orden_trabajo = @ORDEN

BEGIN TRANSACTION

    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        ([otp_uuid], [otp_orden_trabajo], [otp_procedimiento_paso], [otp_orden],
         [otp_nombre], [otp_descripcion], [otp_obligatorio], [otp_resultado_paso],
         [otp_usuario_creacion], [otp_fecha_creacion], [otp_habilitado])
    SELECT  NEWID(),
            @ORDEN,
            p.ppa_id,
            @DESDE + ROW_NUMBER() OVER (ORDER BY p.ppa_orden, p.ppa_id),
            p.ppa_nombre,
            p.ppa_instruccion,

            /* Un punto de control no se puede saltar: si el procedimiento lo
               marco asi, el paso nace obligatorio. */
            ISNULL(p.ppa_es_punto_control, 0),

            /* PENDIENTE es 4, no 1: CK_OTP_RESUELTO solo deja nacer el paso
               sin ejecutor ni fecha si el resultado es PENDIENTE. */
            4,
            @USUARIO,
            @NOW,
            1

    FROM    [dbo].[Procedimiento_Paso] p

    WHERE   p.ppa_procedimiento = @PROCEDIMIENTO
      AND   ISNULL(p.ppa_habilitado, 1) = 1

      /* Volver a apretar el boton no duplica la lista: el paso que ya vino de
         este procedimiento no se copia otra vez. */
      AND   NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso] y
                         WHERE y.otp_orden_trabajo = @ORDEN
                           AND y.otp_procedimiento_paso = p.ppa_id
                           AND ISNULL(y.otp_habilitado, 1) = 1)

    SET @ID = @@ROWCOUNT

COMMIT TRANSACTION

SELECT @ID AS AGREGADOS
GO
PRINT '--- INS_ORDEN_TRABAJO_PASO_PROCEDIMIENTO creado.'
GO

PRINT '276_OT_PASOS_PROCEDIMIENTO aplicado.'
GO
