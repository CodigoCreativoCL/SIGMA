/* ============================================================================
   SIGMA — Bloque 450
   SP DEL_USUARIO_ACCESIBILIDAD (HU-162, T-5330)
   ----------------------------------------------------------------------------

   Baja LÓGICA: uac_habilitado = 0. No se borra la fila —la preferencia vuelve a
   sus valores por defecto en la interfaz, pero el registro queda—.

   «Rechaza si tiene dependientes»: esta tabla no tiene hijos (nadie cuelga de
   una preferencia de accesibilidad), así que la baja siempre procede. Se deja el
   SP por consistencia del CRUD y para que la web/API tengan un único camino.

   Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO_ACCESIBILIDAD]
     @ID                     INT
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
           SET [uac_habilitado] = 0
              ,[uac_usuario_actualizacion] = @USUARIO_ACTUALIZACION
              ,[uac_fecha_actualizacion]   = @AHORA
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

PRINT '--- DEL_USUARIO_ACCESIBILIDAD creado (bloque 450).'
GO
