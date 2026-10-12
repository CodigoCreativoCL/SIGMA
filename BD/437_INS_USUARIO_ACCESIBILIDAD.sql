/* ============================================================================
   SIGMA — Bloque 437
   SP INS_USUARIO_ACCESIBILIDAD (HU-162, T-5328)
   ----------------------------------------------------------------------------

   Alta de las preferencias de accesibilidad de una persona, en transacción.

   UNA FILA POR USUARIO
     La preferencia es de la persona (UX_UAC_USUARIO es único). Si ya tiene una,
     el alta se rechaza y se corrige con UPD_USUARIO_ACCESIBILIDAD. Esto ocupa el
     lugar del «código único» de la plantilla: acá lo único por cliente/usuario
     es el usuario mismo.

   LA FECHA SE SELLA CON LA HORA DEL PAÍS
     uac_fecha_creacion = FNC_PAIS_HORA(cli_pais) del cliente de la persona, no
     GETDATE() del servidor: la bitácora de cuándo cambió sus opciones tiene que
     leerse en la hora de quien las cambió.

   Devuelve el uac_id creado por OUTPUT. Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO_ACCESIBILIDAD]
     @USUARIO                INT
    ,@ENTRADA_VOZ            BIT            = 0
    ,@LECTURA_VOZ            BIT            = 0
    ,@CONFIRMACION_HABLADA   BIT            = 0
    ,@VELOCIDAD_VOZ          DECIMAL(18,2)  = 1.00
    ,@TEXTO_GRANDE           BIT            = 0
    ,@ALTO_CONTRASTE         BIT            = 0
    ,@ICONOS_GRANDES         BIT            = 0
    ,@IDIOMA                 INT            = NULL
    ,@VOLUMEN                DECIMAL(18,2)  = 1.00
    ,@SILENCIAR_ALERTAS      BIT            = 0
    ,@USUARIO_CREACION       INT
    ,@ID                     INT            OUTPUT
AS
SET NOCOUNT ON

BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Accesibilidad] WHERE [uac_usuario] = @USUARIO)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta persona ya tiene sus opciones de accesibilidad; se corrigen, no se crean de nuevo.', 16, 1)
            RETURN
        END

        /* La hora del país del cliente de la persona; si no se puede resolver,
           la del servidor como respaldo. */
        DECLARE @PAIS INT = (SELECT TOP 1 c.[cli_pais]
                               FROM [dbo].[Cliente_Usuario] cu
                               JOIN [dbo].[Cliente] c ON c.[cli_id] = cu.[ucl_id_cliente]
                              WHERE cu.[ucl_id_usuario] = @USUARIO AND ISNULL(cu.[ucl_habilitado], 0) = 1)
        DECLARE @AHORA DATETIME = CASE WHEN @PAIS IS NULL THEN GETDATE() ELSE [dbo].[FNC_PAIS_HORA](@PAIS) END

        INSERT INTO [dbo].[Usuario_Accesibilidad]
            ([uac_usuario], [uac_entrada_voz], [uac_lectura_voz], [uac_confirmacion_hablada]
            ,[uac_velocidad_voz], [uac_texto_grande], [uac_alto_contraste], [uac_iconos_grandes]
            ,[uac_idioma], [uac_volumen], [uac_silenciar_alertas]
            ,[uac_usuario_creacion], [uac_fecha_creacion], [uac_habilitado])
        VALUES
            (@USUARIO, @ENTRADA_VOZ, @LECTURA_VOZ, @CONFIRMACION_HABLADA
            ,@VELOCIDAD_VOZ, @TEXTO_GRANDE, @ALTO_CONTRASTE, @ICONOS_GRANDES
            ,@IDIOMA, @VOLUMEN, @SILENCIAR_ALERTAS
            ,@USUARIO_CREACION, @AHORA, 1)

        SET @ID = SCOPE_IDENTITY()

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH
END
GO

PRINT '--- INS_USUARIO_ACCESIBILIDAD creado (bloque 437).'
GO
