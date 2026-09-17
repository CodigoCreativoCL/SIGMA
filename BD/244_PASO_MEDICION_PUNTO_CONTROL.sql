/* ============================================================================
   SIGMA — Bloque 244
   EL PASO QUE EXIGE MEDICION Y EL PUNTO DE CONTROL             HU-062 #2 · #3
   ----------------------------------------------------------------------------

   La definicion ya existia en el maestro (Procedimiento_Paso: requiere
   medicion + variable, punto de control) y el bloque 241 la copia a la
   orden. Lo que faltaba era que el servidor la HICIERA VALER al completar
   el paso, que es donde la app y la web mandan el resultado:

   #2  Un paso que exige medicion no se completa CONFORME / NO CONFORME sin
       el valor; el valor entra por API_INS_ACTIVO_MEDICION contra la
       variable de condicion del equipo de la orden, con la orden como
       origen: queda en la serie historica con umbrales y alerta.
   #3  Un punto de control pendiente bloquea los pasos siguientes.

   La regla vive en el SP y no en la pantalla: la app puede estar
   desactualizada; el servidor no. SP completo con las reglas nuevas.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ORDEN_TRABAJO_PASO]
     @OTP_ID           INT
    ,@USUARIO          INT
    ,@CLIENTE          INT
    ,@RESULTADO_PASO   INT              -- 1 CONFORME, 2 NO CONFORME, 3 NO APLICA
    ,@OBSERVACION      NVARCHAR(MAX) = NULL
    ,@ENTRADA_MODO     INT           = 1  -- 1 TECLADO, 2 VOZ
    ,@VALOR_MEDICION   DECIMAL(18,4) = NULL  -- HU-062 #2: el valor que el paso exige
    ,@UNIDAD_MEDIDA    INT           = NULL  -- unidad en que viene el valor (vacio = la de la variable)
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @OTR_ID INT, @ESTADO INT, @YA INT, @ORDEN INT, @PPA INT, @OT_ACTIVO INT

        SELECT @OTR_ID = otr.[otr_id]
              ,@ESTADO = otr.[otr_orden_trabajo_estado]
              ,@YA     = otp.[otp_resultado_paso]
              ,@ORDEN  = otp.[otp_orden]
              ,@PPA    = otp.[otp_procedimiento_paso]
              ,@OT_ACTIVO = otr.[otr_activo]
          FROM [dbo].[Orden_Trabajo_Paso] otp
          JOIN [dbo].[Orden_Trabajo]      otr ON otr.[otr_id] = otp.[otp_orden_trabajo]
         WHERE otp.[otp_id]        = @OTP_ID
           AND otp.[otp_habilitado] = 1
           AND otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @OTR_ID IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El paso no existe o no pertenece a este cliente.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso]
                        WHERE [rpa_id] = @RESULTADO_PASO AND [rpa_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El resultado indicado no existe.', 16, 1)
            RETURN
        END

        /* Idempotencia: si ya quedo con el mismo resultado, se responde igual
           y no se toca nada. Un reintento del telefono no es un error. */
        IF @YA = @RESULTADO_PASO
        BEGIN
            COMMIT TRANSACTION
            SELECT @OTP_ID AS [otp_id], @OTR_ID AS [otr_id], 1 AS [YA_ESTABA]
            RETURN
        END

        IF @ESTADO <> 2
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no esta en ejecucion. Tomala antes de completar pasos.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] o
                        WHERE o.[otr_id] = @OTR_ID AND o.[otr_usuario_responsable] = @USUARIO)
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] a
                            WHERE a.[ota_orden_trabajo] = @OTR_ID
                              AND a.[ota_usuario]       = @USUARIO
                              AND a.[ota_habilitado]    = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No estas asignado a esta orden de trabajo.', 16, 1)
            RETURN
        END

        /* ---- HU-062 #3: un punto de control anterior sin resolver bloquea ----
           Se mira por orden dentro de la misma orden de trabajo. */
        DECLARE @PC NVARCHAR(300)
        SELECT TOP 1 @PC = CAST(x.otp_orden AS NVARCHAR(10)) + N'. ' + x.otp_nombre
          FROM [dbo].[Orden_Trabajo_Paso] x
          JOIN [dbo].[Procedimiento_Paso] pp ON pp.ppa_id = x.otp_procedimiento_paso
         WHERE x.otp_orden_trabajo = @OTR_ID AND x.otp_habilitado = 1
           AND x.otp_orden < @ORDEN
           AND pp.ppa_es_punto_control = 1
           AND ISNULL(x.otp_resultado_paso, 4) = 4
         ORDER BY x.otp_orden
        IF @PC IS NOT NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El paso %s es un punto de control y sigue pendiente: resuelvelo antes de avanzar.', 16, 1, @PC)
            RETURN
        END

        /* ---- HU-062 #2: el paso exige medicion ----
           Con CONFORME o NO CONFORME hay que traer el valor; queda en la
           serie historica del equipo con la orden como origen. NO APLICA no
           mide nada. */
        DECLARE @REQ_MED BIT = 0, @VME INT, @VME_NOMBRE NVARCHAR(200), @AVA INT, @MED_ID INT
        IF @PPA IS NOT NULL
            SELECT @REQ_MED = pp.ppa_requiere_medicion, @VME = pp.ppa_variable_medicion
              FROM [dbo].[Procedimiento_Paso] pp WHERE pp.ppa_id = @PPA
        IF @REQ_MED = 1 AND @RESULTADO_PASO IN (1, 2)
        BEGIN
            SELECT @VME_NOMBRE = vme_nombre FROM [dbo].[Variable_Medicion] WHERE vme_id = @VME
            IF @VALOR_MEDICION IS NULL
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('Este paso exige registrar la medicion de %s: indica el valor.', 16, 1, @VME_NOMBRE)
                RETURN
            END
            SELECT TOP 1 @AVA = ava_id FROM [dbo].[Activo_Variable]
             WHERE ava_activo = @OT_ACTIVO AND ava_variable_medicion = @VME AND ava_habilitado = 1
             ORDER BY ava_id
            IF @AVA IS NULL
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('El equipo de la orden no tiene definida la variable %s: definela en Activos > Variables de condicion.', 16, 1, @VME_NOMBRE)
                RETURN
            END
            EXEC [dbo].[API_INS_ACTIVO_MEDICION]
                 @ID = @MED_ID OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_VARIABLE = @AVA, @VALOR = @VALOR_MEDICION,
                 @FECHA_MEDICION_UTC = NULL, @UNIDAD_MEDIDA = @UNIDAD_MEDIDA, @ORDEN_TRABAJO = @OTR_ID,
                 @OBSERVACION = @OBSERVACION, @ENTRADA_MODO = @ENTRADA_MODO, @UUID = NULL, @USUARIO = @USUARIO
        END

        UPDATE [dbo].[Orden_Trabajo_Paso]
           SET [otp_resultado_paso]       = @RESULTADO_PASO
              ,[otp_resultado]            = @OBSERVACION
              ,[otp_usuario_ejecutor]     = @USUARIO
              ,[otp_fecha_ejecucion_utc]  = GETUTCDATE()
              ,[otp_usuario_actualizacion] = @USUARIO
              ,[otp_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [otp_id] = @OTP_ID

        /* El modo de entrada queda en la OT: una cifra dictada y una tecleada
           no se auditan igual. */
        IF @ENTRADA_MODO = 2
            UPDATE [dbo].[Orden_Trabajo]
               SET [otr_entrada_modo] = 2
             WHERE [otr_id] = @OTR_ID

        COMMIT TRANSACTION

        SELECT @OTP_ID AS [otp_id], @OTR_ID AS [otr_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

PRINT '--- API_UPD_ORDEN_TRABAJO_PASO exige la medicion y respeta el punto de control (bloque 244).'
GO
