USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     ALTA DE ORDEN DE TRABAJO CORRECTIVA DESDE TERRENO
--                  (HU-110, Sprint 5) Y SUS PASOS.
-- =============================================
-- IDEMPOTENTE POR UUID, Y NO ES UN ADORNO
--
--   El telefono encola el alta y la envia cuando hay senal. Si el servidor
--   graba pero la respuesta se pierde -el caso del timeout, que en una sala
--   de maquinas es lo normal-, el reintento llega con el MISMO uuid y aca se
--   responde la orden ya creada en vez de crear una segunda.
--
--   El uuid lo genera la app AL ENCOLAR, no al enviar. Generado al enviar,
--   cada reintento traeria uno nuevo y esta proteccion no serviria de nada.
--
-- EL CORRELATIVO SE CALCULA ADENTRO
--
--   Por cliente, con UPDLOCK/HOLDLOCK sobre la lectura del maximo. Dos altas
--   simultaneas del mismo cliente se serializan; si el numero lo eligiera la
--   app, dos tecnicos sin senal crearian la OT-15 los dos.
--
-- LOS PASOS ENTRAN EN LA MISMA TRANSACCION
--
--   Una OT correctiva sin pasos no se puede ejecutar, y una OT a medias es
--   peor que ninguna: el tecnico la ve en la bandeja, la toma, y no tiene que
--   hacer. Van juntas o no va ninguna.
-- =============================================


CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO]
     @UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@INSTALACION       INT
    ,@TITULO            NVARCHAR(400)
    ,@DESCRIPCION       NVARCHAR(MAX) = NULL
    ,@ACTIVO            INT           = NULL
    ,@AREA              INT           = NULL
    ,@TIPO              INT           = 2      -- 2 CORRECTIVA
    ,@ESTRATEGIA        INT           = 3      -- 3 EMERGENCIA
    ,@PRIORIDAD         INT           = 3      -- 3 ALTA
    ,@FECHA_EVENTO_UTC  DATETIME      = NULL
    ,@REQUIERE_PERMISO  BIT           = 0
    ,@PASOS             NVARCHAR(MAX) = NULL   -- un paso por linea
    ,@ENTRADA_MODO      INT           = 1      -- 1 TECLADO, 2 VOZ
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        /* ---- Idempotencia. Va PRIMERO: si ya existe no se valida nada mas,
           porque revalidar podria rechazar hoy algo que ayer se acepto. ---- */
        DECLARE @YA INT

        SELECT @YA = [otr_id]
          FROM [dbo].[Orden_Trabajo]
         WHERE [otr_uuid]    = @UUID
           AND [otr_cliente] = @CLIENTE

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SELECT @YA AS [otr_id], 1 AS [YA_EXISTIA]
            RETURN
        END

        /* ---- La instalacion tiene que ser del cliente Y estar autorizada
           para esta persona. Las dos cosas: la primera evita crear en otra
           empresa, la segunda evita crear en una planta que no le toca. ---- */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion] cin
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = cin.[cin_id]
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE cin.[cin_id]         = @INSTALACION
                          AND cin.[cin_cliente]    = @CLIENTE
                          AND cin.[cin_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No tienes autorizada esa instalacion.', 16, 1)
            RETURN
        END

        IF @ACTIVO IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                            WHERE [act_id]                  = @ACTIVO
                              AND [act_cliente_instalacion] = @INSTALACION
                              AND [act_habilitado]          = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El activo no pertenece a esa instalacion.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TITULO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden necesita un titulo que diga que pasa.', 16, 1)
            RETURN
        END

        /* ---- El correlativo, serializado por cliente. ---- */
        DECLARE @CORRELATIVO INT

        SELECT @CORRELATIVO = ISNULL(MAX([otr_correlativo]), 0) + 1
          FROM [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
         WHERE [otr_cliente] = @CLIENTE

        INSERT INTO [dbo].[Orden_Trabajo]
            ([otr_uuid], [otr_cliente], [otr_cliente_instalacion], [otr_correlativo]
            ,[otr_instalacion_area], [otr_activo]
            ,[otr_orden_trabajo_tipo], [otr_orden_trabajo_estrategia]
            ,[otr_orden_trabajo_origen], [otr_orden_trabajo_estado]
            ,[otr_orden_trabajo_prioridad]
            ,[otr_usuario_generador], [otr_titulo], [otr_descripcion]
            ,[otr_fecha_evento_utc], [otr_requiere_permiso]
            ,[otr_registro_posterior], [otr_entrada_modo]
            ,[otr_usuario_creacion], [otr_fecha_creacion], [otr_habilitado])
        VALUES
            (@UUID, @CLIENTE, @INSTALACION, @CORRELATIVO
            ,@AREA, @ACTIVO
            ,@TIPO, @ESTRATEGIA
            ,1, 1                              -- origen 1, estado 1 ABIERTA
            ,@PRIORIDAD
            ,@USUARIO, @TITULO, @DESCRIPCION
            ,ISNULL(@FECHA_EVENTO_UTC, GETUTCDATE()), @REQUIERE_PERMISO
            /* Si el evento ocurrio antes de que se registre, queda marcado.
               Una OT abierta tres horas despues de la falla no miente sobre
               cuando paro la maquina. */
            ,CASE WHEN @FECHA_EVENTO_UTC IS NOT NULL
                   AND @FECHA_EVENTO_UTC < DATEADD(MINUTE, -30, GETUTCDATE())
                  THEN 1 ELSE 0 END
            ,@ENTRADA_MODO
            ,@USUARIO, GETDATE(), 1)

        DECLARE @OTR_ID INT = SCOPE_IDENTITY()

        /* ---- Los pasos, uno por linea. ---- */
        IF @PASOS IS NOT NULL AND LTRIM(RTRIM(@PASOS)) <> N''
        BEGIN
            INSERT INTO [dbo].[Orden_Trabajo_Paso]
                ([otp_orden_trabajo], [otp_orden], [otp_nombre]
                ,[otp_obligatorio], [otp_resultado_paso]
                ,[otp_usuario_creacion], [otp_fecha_creacion], [otp_habilitado])
            SELECT
                 @OTR_ID
                ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                ,LTRIM(RTRIM([value]))
                ,1
                ,4                              -- 4 PENDIENTE
                ,@USUARIO, GETDATE(), 1
              FROM STRING_SPLIT(@PASOS, NCHAR(10))
             WHERE LTRIM(RTRIM([value])) <> N''
        END

        INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
            ([oeh_orden_trabajo], [oeh_estado_anterior], [oeh_estado_nuevo]
            ,[oeh_motivo], [oeh_usuario_creacion])
        VALUES
            (@OTR_ID, NULL, 1, N'Creada desde terreno', @USUARIO)

        COMMIT TRANSACTION

        SELECT @OTR_ID AS [otr_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO
