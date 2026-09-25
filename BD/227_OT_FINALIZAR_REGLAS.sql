USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     FINALIZAR UNA OT DESDE EL TELEFONO CON LAS REGLAS DE
--                  HU-119 EN EL SP, NO EN LA PANTALLA.
-- =============================================
-- LO QUE HABIA
--   UPD_ORDEN_TRABAJO_FINALIZAR (bloque 10) solo cambiaba el estado 1/2 -> 3
--   y dejaba historial. La app impedia finalizar con obligatorios pendientes
--   desde el boton, pero el endpoint dejaba pasar: probado el 14-09-2026, una
--   OT con dos pasos obligatorios PENDIENTES quedo EN ESPERA DE CIERRE por
--   HTTP. Una regla que solo vive en Dart no es una regla.
--
-- LO QUE HACE AHORA
--   · HU-119 #2: si hay pasos obligatorios sin resolver, rechaza y DICE
--     CUALES (los nombres, hasta 400 caracteres). La app puede seguir
--     apagando el boton; el servidor es el que decide.
--   · HU-119 #1: guarda otr_resultado (lo que el tecnico escribio) y
--     otr_fecha_fin_real_utc; el estado pasa a 3 y ya no se modifica
--     (los pasos ya lo exigen: «tomala antes de completar pasos»).
--   · HU-119 #3: sin ningun tramo de mano de obra se PERMITE finalizar y
--     vuelve ADVERTENCIA en el result set; la API la devuelve y la app la
--     muestra. La advertencia queda ademas en el historial de estado.
--   · Misma firma que antes (@ORDEN_TRABAJO, @USUARIO, @OBSERVACION): la
--     API no cambia de llamada, solo lee la advertencia.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_FINALIZAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @OBSERVACION    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @FALTAN NVARCHAR(400) = NULL, @ADVERTENCIA NVARCHAR(400) = NULL

    -- HU-119 #2: los obligatorios pendientes (resultado 4 PENDIENTE) impiden finalizar, y se nombran.
    SELECT @FALTAN = STUFF((
        SELECT N', ' + p.otp_nombre
          FROM [dbo].[Orden_Trabajo_Paso] p
         WHERE p.otp_orden_trabajo = @ORDEN_TRABAJO
           AND p.otp_habilitado = 1
           AND p.otp_obligatorio = 1
           AND p.otp_resultado_paso = 4
         ORDER BY p.otp_orden
           FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')

    IF @FALTAN IS NOT NULL
    BEGIN
        RAISERROR('Faltan pasos obligatorios por resolver: %s', 16, 1, @FALTAN)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 3,      -- EN ESPERA DE CIERRE
           otr_resultado             = ISNULL(NULLIF(LTRIM(RTRIM(@OBSERVACION)), N''), otr_resultado),
           otr_fecha_fin_real_utc    = ISNULL(otr_fecha_fin_real_utc, GETUTCDATE()),
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = GETDATE()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado IN (1, 2)  -- ABIERTA o EN EJECUCION

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La orden de trabajo no esta abierta ni en ejecucion. Alguien mas la movio.', 16, 1)
        RETURN
    END

    -- HU-119 #3: sin mano de obra se advierte y se deja continuar.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Mano_Obra] WHERE omo_orden_trabajo = @ORDEN_TRABAJO)
        SET @ADVERTENCIA = N'Finalizada sin ningún bloque de mano de obra: no habrá duración real ni carga por persona.'

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 3, LEFT(ISNULL(@OBSERVACION, N'') + ISNULL(N' · ' + @ADVERTENCIA, N''), 500), @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 3 AS ESTADO, N'EN ESPERA DE CIERRE' AS ESTADO_NOMBRE, @ADVERTENCIA AS ADVERTENCIA
END
GO

-- ---------------------------------------------------------------------------
-- HU-115 #3 · API_INS_ORDEN_TRABAJO_MANO_OBRA: el ejecutante se valida antes
-- de insertar (antes: FK_OMO_USUARIO crudo hacia el telefono). Copia de la
-- definicion del bloque 193 con la comprobacion agregada.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_MANO_OBRA]
     @ID INT = NULL OUTPUT
    ,@OTR_ID         INT
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
            SET @ID = @YA
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

        /* HU-115 #3: el ejecutante tiene que existir y ser una persona del
           cliente. Antes un usuario_tramo invalido reventaba contra la FK y
           el telefono recibia el texto crudo de SQL Server. */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Usuario] u
                         JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = u.usu_id AND cu.ucl_id_cliente = @CLIENTE
                        WHERE u.usu_id = @DE_QUIEN AND u.usu_habilitado = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Indica quien trabajo el tramo: un usuario del cliente. Sin usuario ni proveedor el tramo se rechaza.', 16, 1)
            RETURN
        END

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
        SET @ID = @OMO_ID
        SELECT @OMO_ID AS [omo_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO
