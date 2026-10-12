/* ============================================================================
   SIGMA — Bloque 438
   SP UPD_USUARIO_ACCESIBILIDAD (HU-162, T-5329)
   ----------------------------------------------------------------------------

   Edición de las preferencias. Cada campo entra como NULL = «no lo cambies»:
   se guarda con ISNULL(@X, columna) para que una pantalla que no muestra todos
   los campos no borre los que no manda al guardar. uac_fecha_actualizacion se
   sella con la hora del país del cliente de la persona (igual que el alta).

   Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_ACCESIBILIDAD]
     @ID                     INT
    ,@ENTRADA_VOZ            BIT            = NULL
    ,@LECTURA_VOZ            BIT            = NULL
    ,@CONFIRMACION_HABLADA   BIT            = NULL
    ,@VELOCIDAD_VOZ          DECIMAL(18,2)  = NULL
    ,@TEXTO_GRANDE           BIT            = NULL
    ,@ALTO_CONTRASTE         BIT            = NULL
    ,@ICONOS_GRANDES         BIT            = NULL
    ,@IDIOMA                 INT            = NULL
    ,@VOLUMEN                DECIMAL(18,2)  = NULL
    ,@SILENCIAR_ALERTAS      BIT            = NULL
    ,@USUARIO_ACTUALIZACION  INT
AS
SET NOCOUNT ON

BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Accesibilidad] WHERE [uac_id] = @ID)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No existe ese registro de accesibilidad.', 16, 1)
            RETURN
        END

        DECLARE @PAIS INT = (SELECT TOP 1 c.[cli_pais]
                               FROM [dbo].[Usuario_Accesibilidad] uac
                               JOIN [dbo].[Cliente_Usuario] cu ON cu.[ucl_id_usuario] = uac.[uac_usuario] AND ISNULL(cu.[ucl_habilitado], 0) = 1
                               JOIN [dbo].[Cliente] c ON c.[cli_id] = cu.[ucl_id_cliente]
                              WHERE uac.[uac_id] = @ID)
        DECLARE @AHORA DATETIME = CASE WHEN @PAIS IS NULL THEN GETDATE() ELSE [dbo].[FNC_PAIS_HORA](@PAIS) END

        UPDATE [dbo].[Usuario_Accesibilidad]
           SET [uac_entrada_voz]          = ISNULL(@ENTRADA_VOZ,          [uac_entrada_voz])
              ,[uac_lectura_voz]          = ISNULL(@LECTURA_VOZ,          [uac_lectura_voz])
              ,[uac_confirmacion_hablada] = ISNULL(@CONFIRMACION_HABLADA, [uac_confirmacion_hablada])
              ,[uac_velocidad_voz]        = ISNULL(@VELOCIDAD_VOZ,        [uac_velocidad_voz])
              ,[uac_texto_grande]         = ISNULL(@TEXTO_GRANDE,         [uac_texto_grande])
              ,[uac_alto_contraste]       = ISNULL(@ALTO_CONTRASTE,       [uac_alto_contraste])
              ,[uac_iconos_grandes]       = ISNULL(@ICONOS_GRANDES,       [uac_iconos_grandes])
              ,[uac_idioma]               = ISNULL(@IDIOMA,               [uac_idioma])
              ,[uac_volumen]              = ISNULL(@VOLUMEN,              [uac_volumen])
              ,[uac_silenciar_alertas]    = ISNULL(@SILENCIAR_ALERTAS,    [uac_silenciar_alertas])
              ,[uac_usuario_actualizacion]= @USUARIO_ACTUALIZACION
              ,[uac_fecha_actualizacion]  = @AHORA
         WHERE [uac_id] = @ID

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH
END
GO

PRINT '--- UPD_USUARIO_ACCESIBILIDAD creado (bloque 438).'
GO
