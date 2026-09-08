USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LOS MINUTOS MEDIDOS POR LA APP AL CERRAR UNA PAUTA.
-- =============================================
-- La duracion se calculaba con DATEDIFF sobre la hora de inicio, que cuenta
-- como trabajo el rato que se espero una pieza o un permiso. La app ahora
-- cronometra la ronda y sabe descontar las pausas, asi que manda su medicion.
--
-- @MINUTOS es OPCIONAL: sin el, el SP se comporta exactamente como antes.
-- Eso deja seguir cerrando desde la web y desde versiones anteriores de la
-- app sin cambiar nada.
--
-- La columna cej_duracion_minuto ya existia: faltaba poder alimentarla.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 4 - CERRAR LA EJECUCION
-- ---------------------------------------------------------------------------
--   Se exige que los OBLIGATORIOS esten respondidos. �No aplica� cuenta como
--   respuesta: no todo item corresponde a todo equipo, y obligar a inventar un
--   valor para poder cerrar es peor que aceptar el �no aplica�.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_CHECKLIST_CERRAR]
     @CEJ_ID       INT
    ,@USUARIO      INT
    ,@CLIENTE      INT
    ,@OBSERVACION  NVARCHAR(MAX) = NULL
    /* Los minutos que MIDIO la app, descontando las pausas.

       `DATEDIFF` sobre la hora de inicio cuenta como trabajo el rato que se
       espero una pieza o un permiso, y esa espera es justo lo que ensucia el
       dato que esta medicion existe para obtener. Cuando la app manda su
       cronometro, manda el suyo; si no viene —una ejecucion cerrada desde la
       web, o una version anterior de la app— se conserva el calculo de antes,
       que es mejor que nada. */
    ,@MINUTOS      INT = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @OCU INT, @INICIO DATETIME

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@OCU    = [cej_checklist_ocurrencia]
              ,@INICIO = [cej_fecha_inicio_utc]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_id]              = @CEJ_ID
           AND [cej_cliente]         = @CLIENTE
           AND [cej_usuario_ejecutor] = @USUARIO
           AND [cej_habilitado]      = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La ejecucion no existe o no es tuya.', 16, 1)
            RETURN
        END

        /* Idempotente: cerrar dos veces responde lo mismo. Es el caso del
           reintento de la cola. */
        IF @ESTADO <> 1
        BEGIN
            COMMIT TRANSACTION
            SELECT @CEJ_ID AS [cej_id], 1 AS [YA_ESTABA]
            RETURN
        END

        DECLARE @FALTAN INT =
            (SELECT COUNT(*)
               FROM [dbo].[Checklist_Plantilla_Item] i
              WHERE i.[cpi_checklist_plantilla_version] = @VER
                AND i.[cpi_habilitado]   = 1
                AND i.[cpi_obligatorio]  = 1
                AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Respuesta] r
                                 WHERE r.[cer_checklist_ejecucion]      = @CEJ_ID
                                   AND r.[cer_checklist_plantilla_item] = i.[cpi_id]
                                   AND r.[cer_habilitado]               = 1))

        IF @FALTAN > 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @M NVARCHAR(200) =
                CONCAT(N'Faltan ', @FALTAN, N' items obligatorios por responder.')
            RAISERROR(@M, 16, 1)
            RETURN
        END

        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_checklist_ejecucion_estado] = 3           -- ENVIADA
              ,[cej_fecha_fin_utc]              = GETUTCDATE()
              ,[cej_duracion_minuto]            = ISNULL(@MINUTOS, DATEDIFF(MINUTE, @INICIO, GETUTCDATE()))
              ,[cej_fecha_sincronizacion_utc]   = GETUTCDATE()
              ,[cej_observacion]                = ISNULL(@OBSERVACION, [cej_observacion])
              ,[cej_usuario_actualizacion]      = @USUARIO
              ,[cej_fecha_actualizacion]        = GETDATE()
         WHERE [cej_id] = @CEJ_ID

        IF @OCU IS NOT NULL
            UPDATE [dbo].[Checklist_Ocurrencia]
               SET [coc_checklist_ocurrencia_estado] = 4      -- COMPLETADA
                  ,[coc_usuario_actualizacion]       = @USUARIO
                  ,[coc_fecha_actualizacion]         = GETDATE()
             WHERE [coc_id] = @OCU

        COMMIT TRANSACTION

        SELECT @CEJ_ID AS [cej_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO
