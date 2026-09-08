USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     IDEMPOTENCIA POR UUID EN EL TRAMO DE MANO DE OBRA.
-- =============================================
-- El controller mandaba @UUID y el SP no lo declaraba, asi que TODA alta de
-- mano de obra fallaba con "@UUID is not a parameter for procedure": ni
-- registrar el propio tramo ni sumar al compañero que participo funcionaban.
--
-- Es el mismo desajuste que INS_PERMISO_TRABAJO tenia en el script 177, y se
-- encontro igual: cruzando los Datos.Ejecutar de los controllers contra
-- sys.parameters. Ahi la columna ya existia; aca hay que crearla.
--
-- El corte por uuid va antes de las validaciones: un reintento no tiene por
-- que volver a pasar reglas que ya paso, y si entretanto la orden se cerro, la
-- segunda llamada fallaria por algo que ya estaba hecho.
-- =============================================
SET NOCOUNT ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Mano_Obra]')
                  AND name = 'omo_uuid')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Mano_Obra]
        ADD omo_uuid UNIQUEIDENTIFIER NULL
END
GO

/* Filtrado: los tramos que registra la web no llevan uuid y son todos NULL;
   un unique normal dejaria pasar uno solo. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Mano_Obra]')
                  AND name = 'UQ_OMO_UUID')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_OMO_UUID
        ON [dbo].[Orden_Trabajo_Mano_Obra](omo_uuid)
        WHERE omo_uuid IS NOT NULL
END
GO

-- ---------------------------------------------------------------------------
--   El tecnico registra su propio tramo: entro a las 08:10, salio a las 10:00.
--   Los minutos se calculan aca y no llegan del telefono -un aparato con el
--   reloj corrido reportaria tramos de doce horas- salvo que se manden
--   explicitos, para el caso de registrar a mano un trabajo de ayer.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_MANO_OBRA]
     @OTR_ID         INT
    ,@USUARIO        INT            -- quien registra
    ,@CLIENTE        INT
    ,@FECHA_INICIO   DATETIME
    ,@FECHA_FIN      DATETIME       = NULL
    ,@MINUTOS        INT            = NULL
    ,@ESPECIALIDAD   INT            = NULL
    ,@ES_HORA_EXTRA  BIT            = 0
    ,@OBSERVACION    NVARCHAR(1000) = NULL
    ,@USUARIO_TRAMO  INT            = NULL   -- de quien es el tramo
    /* Nace en el telefono AL ENCOLAR. Opcional: la web no lo manda. */
    ,@UUID           UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    /* ---- Idempotencia: si el uuid ya paso, se devuelve el tramo que ya hay ----
       Va ANTES de la transaccion y de toda validacion. Sin esto, un reintento
       sobre una orden que entretanto se cerro respondia "la orden esta
       cerrada" por un tramo que SI se habia registrado. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [omo_id] FROM [dbo].[Orden_Trabajo_Mano_Obra]
         WHERE [omo_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SELECT @YA AS [omo_id]
            RETURN
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

        SELECT @ESTADO = otr.[otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo] otr
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = otr.[otr_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE otr.[otr_id]      = @OTR_ID
           AND otr.[otr_cliente] = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden esta cerrada. No se puede agregar mano de obra.', 16, 1)
            RETURN
        END

        /* El tramo es de quien lo trabajo; por omision, de quien lo registra. */
        DECLARE @DE_QUIEN INT = ISNULL(@USUARIO_TRAMO, @USUARIO)

        /* Los minutos: del rango si hay fin, del parametro si no. */
        DECLARE @MIN INT = ISNULL(@MINUTOS,
                                  CASE WHEN @FECHA_FIN IS NULL THEN NULL
                                       ELSE DATEDIFF(MINUTE, @FECHA_INICIO, @FECHA_FIN) END)

        IF @MIN IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Falta la hora de termino o la cantidad de minutos.', 16, 1)
            RETURN
        END

        IF @MIN <= 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El termino no puede ser anterior al inicio.', 16, 1)
            RETURN
        END

        /* Un turno no dura mas de un dia. Un tramo de 30 horas es un error de
           fecha, y grabarlo arruina el MTTR del activo por meses. */
        IF @MIN > 1440
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El tramo supera las 24 horas. Revisa las fechas.', 16, 1)
            RETURN
        END

        /* La especialidad, si no viene, se toma de la que tenga la persona.
           Escribirla a mano en cada registro es donde aparecen las faltas de
           ortografia que despues no agrupan en un informe. */
        DECLARE @ESP INT = @ESPECIALIDAD

        IF @ESP IS NULL
            SELECT TOP 1 @ESP = ue.[ues_especialidad]
              FROM [dbo].[Usuario_Especialidad] ue
             WHERE ue.[ues_usuario]    = @DE_QUIEN
               AND ISNULL(ue.[ues_habilitado], 1) = 1
             ORDER BY ue.[ues_id]

        INSERT INTO [dbo].[Orden_Trabajo_Mano_Obra]
            ([omo_orden_trabajo], [omo_usuario], [omo_especialidad]
            ,[omo_fecha_inicio_utc], [omo_fecha_fin_utc], [omo_minuto]
            ,[omo_es_hora_extra], [omo_observacion], [omo_uuid]
            ,[omo_usuario_creacion], [omo_fecha_creacion])
        VALUES
            (@OTR_ID, @DE_QUIEN, @ESP
            ,@FECHA_INICIO, @FECHA_FIN, @MIN
            ,@ES_HORA_EXTRA, @OBSERVACION, @UUID
            ,@USUARIO, GETDATE())

        DECLARE @OMO_ID INT = SCOPE_IDENTITY()

        /* La duracion real de la OT es la suma de sus tramos. Se recalcula en
           vez de acumularse: acumular deja el total mintiendo el dia que un
           tramo se borre. */
        UPDATE [dbo].[Orden_Trabajo]
           SET [otr_duracion_real_minuto] =
                   (SELECT SUM([omo_minuto]) FROM [dbo].[Orden_Trabajo_Mano_Obra]
                     WHERE [omo_orden_trabajo] = @OTR_ID)
              ,[otr_usuario_actualizacion] = @USUARIO
              ,[otr_fecha_actualizacion]   = GETDATE()
         WHERE [otr_id] = @OTR_ID

        COMMIT TRANSACTION
        SELECT @OMO_ID AS [omo_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO
