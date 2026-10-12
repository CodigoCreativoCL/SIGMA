/* ============================================================================
   SIGMA — Bloque 442
   RECTIFICAR UNA ENTRADA DE BITÁCORA, IDEMPOTENTE POR UUID (HU-131, T-5317)
   ----------------------------------------------------------------------------

   La rectificación se escribe desde el teléfono, que puede estar sin señal y
   reenviar la cola. Sin una llave idempotente, un reintento dejaría DOS
   rectificaciones iguales, y en una bitácora eso no es un duplicado molesto:
   es un relato que se contradice. Se agrega `bre_uuid`, generado en el
   teléfono al empezar a escribir —no al enviar—, igual que `bit_uuid` en la
   entrada (bloque 171, HU-130).

   El SP `API_INS_BITACORA_RECTIFICACION` pasa a:
     · recibir @UUID (opcional por compatibilidad; la idempotencia solo actúa
       si viene);
     · si ese uuid ya existe, devolver la rectificación que ya estaba
       (bre_id + YA_ESTABA = 1) sin insertar otra;
     · conservar todas las reglas que ya tenía: solo el autor, motivo
       obligatorio, texto no vacío y distinto del vigente.

   TODO IDEMPOTENTE (la columna, el índice y el SP se pueden re-aplicar).
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora_Rectificacion]')
                  AND name = N'bre_uuid')
BEGIN
    ALTER TABLE [dbo].[Bitacora_Rectificacion] ADD [bre_uuid] UNIQUEIDENTIFIER NULL
    PRINT '--- Bitacora_Rectificacion.bre_uuid agregada.'
END
ELSE PRINT '--- Bitacora_Rectificacion.bre_uuid ya existía.'
GO

/* Un uuid no se repite, pero las rectificaciones viejas no lo tienen: índice
   único FILTRADO a las que sí, para que los NULL no choquen entre sí. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_BRE_UUID'
                 AND object_id = OBJECT_ID(N'[dbo].[Bitacora_Rectificacion]'))
    CREATE UNIQUE NONCLUSTERED INDEX [UX_BRE_UUID]
        ON [dbo].[Bitacora_Rectificacion] ([bre_uuid])
        WHERE [bre_uuid] IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_RECTIFICACION]
     @UUID      UNIQUEIDENTIFIER = NULL
    ,@BITACORA  INT
    ,@USUARIO   INT
    ,@CLIENTE   INT
    ,@TEXTO     NVARCHAR(MAX)
    ,@MOTIVO    NVARCHAR(1000)
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        /* ---- Reenvío de la cola: el mismo uuid no escribe dos veces ---- */
        IF @UUID IS NOT NULL
        BEGIN
            DECLARE @YA INT
            SELECT @YA = [bre_id] FROM [dbo].[Bitacora_Rectificacion] WHERE [bre_uuid] = @UUID

            IF @YA IS NOT NULL
            BEGIN
                COMMIT TRANSACTION
                SELECT @YA AS [bre_id], 1 AS [YA_ESTABA]
                RETURN
            END
        END

        DECLARE @AUTOR INT, @ORIGINAL NVARCHAR(MAX)

        SELECT @AUTOR = bit.[bit_usuario_creacion]
              ,@ORIGINAL = bit.[bit_texto]
          FROM [dbo].[Bitacora] bit
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = bit.[bit_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE bit.[bit_id]      = @BITACORA
           AND bit.[bit_cliente] = @CLIENTE

        IF @AUTOR IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @AUTOR <> @USUARIO
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Solo quien escribio la entrada puede rectificarla. Si hay algo que agregar, comenta.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto rectificado esta vacio.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@MOTIVO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Para rectificar hay que decir por que.', 16, 1)
            RETURN
        END

        /* El texto vigente: el ultimo rectificado, o el original si es la
           primera correccion. Rectificar dejandolo igual no aporta nada y
           ensucia la historia. */
        DECLARE @VIGENTE NVARCHAR(MAX) =
            ISNULL((SELECT TOP 1 [bre_texto_rectificado]
                      FROM [dbo].[Bitacora_Rectificacion]
                     WHERE [bre_bitacora] = @BITACORA
                     ORDER BY [bre_id] DESC), @ORIGINAL)

        IF @TEXTO = @VIGENTE
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto es el mismo que ya estaba.', 16, 1)
            RETURN
        END

        INSERT INTO [dbo].[Bitacora_Rectificacion]
            ([bre_bitacora], [bre_texto_rectificado], [bre_motivo]
            ,[bre_usuario_creacion], [bre_fecha_creacion], [bre_uuid])
        VALUES
            (@BITACORA, @TEXTO, @MOTIVO, @USUARIO, GETDATE(), @UUID)

        DECLARE @BRE INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @BRE AS [bre_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

PRINT '--- API_INS_BITACORA_RECTIFICACION ahora es idempotente por uuid (bloque 442).'
GO
