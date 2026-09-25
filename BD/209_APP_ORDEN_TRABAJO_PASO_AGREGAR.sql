USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     EL TECNICO ANOTA LO QUE HIZO EN UNA OT.
-- =============================================
-- Bryan: «cuando se abre una OT debe de alguna forma el tecnico indicar que
-- fue lo que le realizo, ya que se crea la OT pero sin pasos ni donde
-- escribir».
--
-- Es exacto. `Orden_Trabajo_Paso` tenia UPD y no INS: se podian marcar los
-- pasos que alguien definio antes, y no agregar ninguno. Una correctiva abierta
-- en terreno nace sin pauta -no todo trabajo correctivo tiene uno- asi que el
-- tecnico se quedaba sin ningun sitio donde registrar el trabajo hasta el
-- cuadro de «Resultado» del cierre, que es una sola caja al final y para
-- entonces ya se olvido la mitad.
--
-- POR QUE UN PASO Y NO UN CAMPO DE NOTAS
--   El modelo ya tiene el concepto: un paso es una accion con su resultado,
--   su ejecutor y su hora, y `Archivo_Vinculo` sabe colgarle evidencia con
--   destino PASO. Un campo de texto libre en la cabecera seria una segunda
--   forma de decir lo mismo, sin ejecutor, sin hora y sin fotos.
--
-- EL PASO NACE HECHO, NO PENDIENTE
--   No se esta planificando: se esta anotando lo que YA se hizo. Por eso
--   acepta el resultado en el mismo INSERT y queda con su ejecutor y su hora.
--   Si no viene resultado, queda pendiente y sirve como recordatorio.
--
-- NUNCA OBLIGATORIO
--   `otp_obligatorio = 0` a proposito: un paso que el propio tecnico agrega
--   mientras trabaja no puede convertirse en un requisito que despues le
--   impida finalizar la orden.
-- =============================================
SET NOCOUNT ON
GO

/* Idempotencia: el paso se encola desde el telefono. */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Paso]')
                  AND name = 'otp_uuid')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Paso]
        ADD otp_uuid UNIQUEIDENTIFIER NULL
END
GO

/* Filtrado: los pasos que crea la web o una pauta no llevan uuid y son todos
   NULL; un unique normal dejaria pasar uno solo en toda la tabla. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Paso]')
                  AND name = 'UQ_OTP_UUID')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_OTP_UUID
        ON [dbo].[Orden_Trabajo_Paso](otp_uuid)
        WHERE otp_uuid IS NOT NULL
END
GO

CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_PASO]
    /* @ID primero y OUTPUT, como manda PATRON_SP. No es un detalle: el
       controller llama con `devuelveId: true` y `Datos.Ejecutar` agrega este
       parametro, asi que un SP que no lo declare responde
       «@ID is not a parameter» y el endpoint entero devuelve 400. */
     @ID              INT = NULL OUTPUT
    ,@OTR_ID          INT
    ,@USUARIO         INT
    ,@CLIENTE         INT
    ,@NOMBRE          NVARCHAR(400)
    ,@DESCRIPCION     NVARCHAR(MAX)  = NULL
    /* 1 CONFORME, 2 NO CONFORME, 3 NO APLICA. Nulo = queda pendiente. */
    ,@RESULTADO_PASO  INT            = NULL
    ,@OBSERVACION     NVARCHAR(MAX)  = NULL
    ,@UUID            UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    /* ---- Idempotencia: va ANTES de toda validacion ----
       Un reintento sobre una orden que entretanto se finalizo respondia «la
       orden ya no esta en ejecucion» por un paso que SI se habia registrado. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [otp_id] FROM [dbo].[Orden_Trabajo_Paso]
         WHERE [otp_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SET @ID = @YA
            SELECT @YA AS [otp_id]
            RETURN
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

        /* La misma regla de plantas que el resto: la orden tiene que estar en
           una instalacion autorizada para esta persona. */
        SELECT @ESTADO = otr.[otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo] otr
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = otr.[otr_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE otr.[otr_id]         = @OTR_ID
           AND otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* Mismo corte que la mano de obra: sobre una orden cerrada no se
           escribe. Antes de eso si, porque alguien puede acordarse de algo
           mientras la orden espera cierre. */
        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden esta cerrada. No se le pueden agregar pasos.', 16, 1)
            RETURN
        END

        IF (@NOMBRE IS NULL OR LTRIM(RTRIM(@NOMBRE)) = N'')
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Escribe que fue lo que hiciste.', 16, 1)
            RETURN
        END

        /* Al final de los que ya hay: lo que se agrega mientras se trabaja va
           despues de la pauta, en el orden en que ocurrio. */
        DECLARE @ORDEN INT = ISNULL(
            (SELECT MAX([otp_orden]) FROM [dbo].[Orden_Trabajo_Paso]
              WHERE [otp_orden_trabajo] = @OTR_ID), 0) + 1

        DECLARE @HECHO BIT = CASE WHEN @RESULTADO_PASO IS NULL THEN 0 ELSE 1 END

        INSERT INTO [dbo].[Orden_Trabajo_Paso]
            ([otp_orden_trabajo], [otp_orden], [otp_nombre], [otp_descripcion]
            ,[otp_obligatorio], [otp_resultado_paso], [otp_resultado]
            ,[otp_usuario_ejecutor], [otp_fecha_ejecucion_utc]
            ,[otp_uuid], [otp_usuario_creacion], [otp_fecha_creacion]
            ,[otp_habilitado])
        VALUES
            (@OTR_ID, @ORDEN, LTRIM(RTRIM(@NOMBRE)), @DESCRIPCION
            /* Nunca obligatorio: lo agrega quien trabaja, y no puede acabar
               siendo un requisito que le impida cerrar su propia orden. */
            ,0, ISNULL(@RESULTADO_PASO, 0), @OBSERVACION
            ,CASE WHEN @HECHO = 1 THEN @USUARIO END
            ,CASE WHEN @HECHO = 1 THEN GETUTCDATE() END
            ,@UUID, @USUARIO, GETDATE()
            ,1)

        SET @ID = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @ID AS [otp_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO
