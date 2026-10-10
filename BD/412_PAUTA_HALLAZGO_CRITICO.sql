/* ============================================================================
   412 · Pautas de Recursos: lo que no cumple llega a Avisos, y el ítem crítico pesa (09-10-2026)

   1. UPS_CHECKLIST_ITEM_REGLAS_RECURSOS: un ítem creado en el cajón de pauta (Recursos) queda
      listo para generar hallazgo:
        · «Cumple / no cumple» (Sí/No): opciones SI (conforme) y NO (no conforme); la app evalúa
          el Sí/No contra esas opciones (API_UPS_CHECKLIST_RESPUESTA).
        · todos: su validación con civ_genera_hallazgo = 1 (sin ella la respuesta fuera de rango
          o no conforme no abre hallazgo).
   2. API_UPS_CHECKLIST_RESPUESTA (vigente) + cha_severidad: ALTA (4) si el ítem es crítico
      (cpi_critico, BD/406); ADVERTENCIA (3) si no. En Avisos: Alta / Media.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[UPS_CHECKLIST_ITEM_REGLAS_RECURSOS]
    @ITEM    INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @TIPO INT = (SELECT cpi_checklist_item_tipo FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_id = @ITEM), @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF @TIPO IS NULL RETURN 0
IF @TIPO = 5
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Opcion] WHERE cio_checklist_plantilla_item = @ITEM AND cio_codigo = N'SI' AND cio_habilitado = 1)
        INSERT [dbo].[Checklist_Item_Opcion] (cio_checklist_plantilla_item, cio_codigo, cio_texto, cio_valor, cio_orden, cio_es_conforme, cio_requiere_comentario, cio_requiere_evidencia, cio_usuario_creacion, cio_fecha_creacion, cio_habilitado)
        VALUES (@ITEM, N'SI', N'Cumple', 1, 1, 1, 0, 0, @USUARIO, @AHORA, 1)
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Opcion] WHERE cio_checklist_plantilla_item = @ITEM AND cio_codigo = N'NO' AND cio_habilitado = 1)
        INSERT [dbo].[Checklist_Item_Opcion] (cio_checklist_plantilla_item, cio_codigo, cio_texto, cio_valor, cio_orden, cio_es_conforme, cio_requiere_comentario, cio_requiere_evidencia, cio_usuario_creacion, cio_fecha_creacion, cio_habilitado)
        VALUES (@ITEM, N'NO', N'No cumple', 0, 2, 0, 1, 0, @USUARIO, @AHORA, 1)
END
IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] WHERE civ_checklist_plantilla_item = @ITEM AND civ_habilitado = 1)
    UPDATE [dbo].[Checklist_Item_Validacion] SET civ_genera_hallazgo = 1, civ_usuario_actualizacion = @USUARIO, civ_fecha_actualizacion = @AHORA
    WHERE civ_checklist_plantilla_item = @ITEM AND civ_habilitado = 1
ELSE IF @TIPO IN (3, 4, 5)
    INSERT [dbo].[Checklist_Item_Validacion] (civ_checklist_plantilla_item, civ_requiere_comentario_fuera_rango, civ_requiere_evidencia_fuera_rango, civ_genera_alerta, civ_genera_hallazgo,
           civ_usuario_creacion, civ_fecha_creacion, civ_habilitado)
    VALUES (@ITEM, 1, 0, 0, 1, @USUARIO, @AHORA, 1)
RETURN 0
GO

-- ---------- API_UPS_CHECKLIST_RESPUESTA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPS_CHECKLIST_RESPUESTA (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 3 - RESPONDER UN ITEM
-- ---------------------------------------------------------------------------
--   Es un UPSERT por (ejecucion, item): volver a responder ACTUALIZA. Eso es
--   lo que hace que reenviar una pauta de treinta items desde la cola sea
--   seguro, y tambien que el tecnico pueda corregirse antes de cerrar.
--
--   El rango se evalua ACA contra Checklist_Item_Validacion. Fuera de rango
--   no impide grabar -es el hallazgo- pero queda marcado, y si la plantilla
--   lo pide se abre el Checklist_Hallazgo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_CHECKLIST_RESPUESTA]
     @CEJ_ID         INT
    ,@USUARIO        INT
    ,@CLIENTE        INT
    ,@ITEM           INT
    ,@VALOR_TEXTO    NVARCHAR(MAX)  = NULL
    ,@VALOR_NUMERO   DECIMAL(18,4)  = NULL
    ,@VALOR_BOOLEANO BIT            = NULL
    ,@VALOR_FECHA    DATETIME       = NULL
    ,@NO_APLICA      BIT            = 0
    ,@COMENTARIO     NVARCHAR(MAX)  = NULL
    ,@ENTRADA_MODO   INT            = 1
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @ACTIVO INT

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@ACTIVO = [cej_activo]
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

        IF @ESTADO <> 1
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La pauta ya fue enviada. No se puede cambiar una respuesta.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item]
                        WHERE [cpi_id] = @ITEM
                          AND [cpi_checklist_plantilla_version] = @VER
                          AND [cpi_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Ese item no pertenece a la pauta que se esta llenando.', 16, 1)
            RETURN
        END

        /* ---- El rango, contra la validacion de la plantilla ---- */
        DECLARE @FUERA BIT = 0, @HALLAZGO BIT = 0, @MENSAJE_VAL NVARCHAR(500)

        SELECT TOP 1
               @FUERA = CASE
                   WHEN @NO_APLICA = 1 OR @VALOR_NUMERO IS NULL THEN 0
                   WHEN [civ_valor_minimo] IS NOT NULL AND @VALOR_NUMERO < [civ_valor_minimo] THEN 1
                   WHEN [civ_valor_maximo] IS NOT NULL AND @VALOR_NUMERO > [civ_valor_maximo] THEN 1
                   ELSE 0 END
              ,@HALLAZGO    = ISNULL([civ_genera_hallazgo], 0)
              ,@MENSAJE_VAL = [civ_mensaje]
          FROM [dbo].[Checklist_Item_Validacion]
         WHERE [civ_checklist_plantilla_item] = @ITEM
           AND [civ_habilitado] = 1

        /* Una opcion marcada como no conforme tambien es un hallazgo. */
        IF @FUERA = 0 AND @VALOR_TEXTO IS NOT NULL
            SELECT @FUERA = CASE WHEN ISNULL([cio_es_conforme], 1) = 0 THEN 1 ELSE 0 END
              FROM [dbo].[Checklist_Item_Opcion]
             WHERE [cio_checklist_plantilla_item] = @ITEM
               AND [cio_codigo]                   = @VALOR_TEXTO
               AND [cio_habilitado]               = 1

        /* ---- Un SI/NO se evalua contra las opciones de la plantilla, NUNCA
           contra el valor.

           La primera version marcaba como no conforme todo SI/NO respondido
           «No». Es un error de criterio: a «¿Hay fugas visibles?» la buena
           respuesta ES «No», y a «¿Opera sin ruidos?» es «Si». El significado
           depende de como este redactada la pregunta, y eso solo lo sabe quien
           escribio la pauta.

           Por eso la conformidad se declara en Checklist_Item_Opcion con
           `cio_es_conforme` -SI y NO como dos opciones- y aca solo se lee. Una
           pauta que no lo declare no marca nada, que es preferible a marcarlo
           al reves. */
        IF @FUERA = 0 AND @VALOR_BOOLEANO IS NOT NULL AND @NO_APLICA = 0
            SELECT @FUERA = CASE WHEN ISNULL([cio_es_conforme], 1) = 0 THEN 1 ELSE 0 END
              FROM [dbo].[Checklist_Item_Opcion]
             WHERE [cio_checklist_plantilla_item] = @ITEM
               AND [cio_codigo] = CASE WHEN @VALOR_BOOLEANO = 1 THEN N'SI' ELSE N'NO' END
               AND [cio_habilitado] = 1

        /* ---- El UPSERT ---- */
        DECLARE @CER INT

        SELECT @CER = [cer_id]
          FROM [dbo].[Checklist_Ejecucion_Respuesta]
         WHERE [cer_checklist_ejecucion]      = @CEJ_ID
           AND [cer_checklist_plantilla_item] = @ITEM

        IF @CER IS NULL
        BEGIN
            INSERT INTO [dbo].[Checklist_Ejecucion_Respuesta]
                ([cer_checklist_ejecucion], [cer_checklist_plantilla_item]
                ,[cer_valor_texto], [cer_valor_numero], [cer_valor_booleano]
                ,[cer_valor_fecha], [cer_fuera_rango], [cer_no_aplica]
                ,[cer_comentario], [cer_entrada_modo], [cer_fecha_respuesta_utc]
                ,[cer_usuario_creacion], [cer_fecha_creacion], [cer_habilitado])
            VALUES
                (@CEJ_ID, @ITEM
                ,@VALOR_TEXTO, @VALOR_NUMERO, @VALOR_BOOLEANO
                ,@VALOR_FECHA, @FUERA, @NO_APLICA
                ,@COMENTARIO, @ENTRADA_MODO, GETUTCDATE()
                ,@USUARIO, [dbo].[FNC_AHORA](), 1)

            SET @CER = SCOPE_IDENTITY()
        END
        ELSE
        BEGIN
            UPDATE [dbo].[Checklist_Ejecucion_Respuesta]
               SET [cer_valor_texto]           = @VALOR_TEXTO
                  ,[cer_valor_numero]          = @VALOR_NUMERO
                  ,[cer_valor_booleano]        = @VALOR_BOOLEANO
                  ,[cer_valor_fecha]           = @VALOR_FECHA
                  ,[cer_fuera_rango]           = @FUERA
                  ,[cer_no_aplica]             = @NO_APLICA
                  ,[cer_comentario]            = @COMENTARIO
                  ,[cer_entrada_modo]          = @ENTRADA_MODO
                  ,[cer_fecha_respuesta_utc]   = GETUTCDATE()
                  ,[cer_usuario_actualizacion] = @USUARIO
                  ,[cer_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
             WHERE [cer_id] = @CER
        END

        /* ---- El hallazgo, si la plantilla lo pide y el valor lo amerita ----

           Uno por respuesta: si el tecnico corrige el valor y vuelve a quedar
           fuera de rango, no se abren dos. */
        IF @FUERA = 1 AND @HALLAZGO = 1
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo]
                            WHERE [cha_checklist_ejecucion_respuesta] = @CER)
        BEGIN
            DECLARE @TEXTO NVARCHAR(400) =
                (SELECT [cpi_texto] FROM [dbo].[Checklist_Plantilla_Item] WHERE [cpi_id] = @ITEM)

            INSERT INTO [dbo].[Checklist_Hallazgo]
                ([cha_uuid], [cha_cliente], [cha_checklist_ejecucion]
                ,[cha_checklist_ejecucion_respuesta], [cha_activo]
                ,[cha_titulo], [cha_descripcion], [cha_severidad], [cha_proceso_estado]
                ,[cha_generado_ia], [cha_usuario_creacion], [cha_fecha_creacion]
                ,[cha_habilitado])
            VALUES
                (NEWID(), @CLIENTE, @CEJ_ID
                ,@CER, @ACTIVO
                ,LEFT(ISNULL(@TEXTO, N'Hallazgo de checklist'), 400)
                ,ISNULL(@MENSAJE_VAL, @COMENTARIO)
                /* 412: el ítem crítico de la pauta hace nacer el hallazgo con severidad ALTA; los demás, ADVERTENCIA. */
                ,CASE WHEN (SELECT [cpi_critico] FROM [dbo].[Checklist_Plantilla_Item] WHERE [cpi_id] = @ITEM) = 1 THEN 4 ELSE 3 END
                ,1
                ,0, @USUARIO, [dbo].[FNC_AHORA]()
                ,1)
        END

        /* ---- Los contadores de la ejecucion.

           Se recalculan, no se acumulan: acumular deja el total mintiendo el
           dia que una respuesta cambie de conforme a no conforme. ---- */
        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_item_respondido] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1)
              ,[cej_item_no_conforme] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1
                       AND [cer_fuera_rango] = 1)
              ,[cej_usuario_actualizacion] = @USUARIO
              ,[cej_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [cej_id] = @CEJ_ID

        COMMIT TRANSACTION

        SELECT @CER AS [cer_id], @FUERA AS [fuera_rango],
               @MENSAJE_VAL AS [mensaje]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO
PRINT '412_PAUTA_HALLAZGO_CRITICO aplicado.'
GO
