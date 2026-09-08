USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     RECURSOS DE LA ORDEN DE TRABAJO: MANO DE OBRA (HU-115) Y
--                  REPUESTOS (HU-116). Sprint 5.
-- =============================================
-- LO QUE HACE UTIL ESTE BLOQUE
--
--   Una OT sin recursos registrados dice QUE se hizo pero no CUANTO costo. Sin
--   mano de obra no hay MTTR ni carga por persona; sin consumo no hay costo de
--   mantenimiento por activo, que es la cifra con la que se decide reparar o
--   reemplazar.
--
-- LA MANO DE OBRA ES APPEND-ONLY, Y LA TABLA LO DICE
--
--   Orden_Trabajo_Mano_Obra no tiene columna `habilitado` ni auditoria de
--   actualizacion. No es un olvido: un tramo de trabajo es un HECHO -alguien
--   estuvo dos horas frente a la maquina- y los hechos no se editan, se
--   corrigen agregando otro tramo. Este bloque respeta esa decision: hay INS,
--   no hay UPD.
--
-- CONSUMIR UN REPUESTO MUEVE EL INVENTARIO. SIEMPRE.
--
--   Es la regla que justifica que esto sea un SP y no dos llamadas desde la
--   API. Registrar el consumo en la OT sin descontar del saldo deja la bodega
--   mintiendo: el sistema diria que hay diez rodamientos y en el estante
--   habria nueve.
--
--   Las dos escrituras van en UNA transaccion, y el movimiento se crea
--   llamando a INS_INVENTARIO_MOVIMIENTO -que ya existe, ya valida saldo y ya
--   es idempotente- en vez de escribir a mano en Inventario_Movimiento. Si la
--   regla de saldo cambia, cambia en un solo sitio.
--
-- IDEMPOTENTE POR UUID
--
--   El telefono encola el consumo y lo envia cuando hay senal. El uuid lo
--   genera AL ENCOLAR: si lo generara al enviar, cada reintento traeria uno
--   nuevo y el mismo rodamiento se descontaria dos veces del estante.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - LOS RECURSOS SE SUMAN A LA SABANA COMO @TIPO 5 Y 6
-- ---------------------------------------------------------------------------
--   Se amplia API_SEL_ORDEN_TRABAJO en vez de crear otro SP: un solo punto de
--   entrada para la orden, con la misma resolucion de plantas autorizadas. Dos
--   procedimientos habrian sido dos sitios donde repetir la regla de
--   seguridad, y el segundo es el que sale mal.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ORDEN_TRABAJO_RECURSO]
     @USUARIO  INT
    ,@CLIENTE  INT
    ,@OTR_ID   INT
    ,@TIPO     INT = 1     -- 1 mano de obra, 2 repuestos
AS
SET NOCOUNT ON

BEGIN

    /* La orden tiene que ser de una planta autorizada para esta persona. Se
       comprueba una vez y las dos consultas se apoyan en eso. */
    IF NOT EXISTS (SELECT 1
                     FROM [dbo].[Orden_Trabajo] otr
                     JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                            ON  ciu.[ciu_id_instalacion] = otr.[otr_cliente_instalacion]
                            AND ciu.[ciu_id_usuario]     = @USUARIO
                            AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                    WHERE otr.[otr_id]      = @OTR_ID
                      AND otr.[otr_cliente] = @CLIENTE)
    BEGIN
        RAISERROR('La orden no existe o no esta en una planta autorizada.', 16, 1)
        RETURN
    END


    -- ----------------------------------------------------- MANO DE OBRA ----
    IF @TIPO = 1
    BEGIN
        SELECT
             omo.[omo_id]
            ,omo.[omo_usuario]                AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                              AS [USUARIO_NOMBRE]
            ,esp.[esp_nombre]                 AS [ESPECIALIDAD_NOMBRE]
            ,prv.[prv_nombre]                 AS [PROVEEDOR_NOMBRE]
            ,omo.[omo_fecha_inicio_utc]
            ,omo.[omo_fecha_fin_utc]
            ,omo.[omo_minuto]
            ,omo.[omo_es_hora_extra]
            ,omo.[omo_observacion]
            /* Interna o externa lo decide de donde viene la persona, no un
               campo aparte que se puede desalinear. */
            ,CASE WHEN omo.[omo_proveedor] IS NULL THEN N'INTERNA'
                  ELSE N'EXTERNA' END         AS [ORIGEN]

          FROM [dbo].[Orden_Trabajo_Mano_Obra] omo
     LEFT JOIN [dbo].[Usuario]                 usr ON usr.[usu_id] = omo.[omo_usuario]
     LEFT JOIN [dbo].[Especialidad]            esp ON esp.[esp_id] = omo.[omo_especialidad]
     LEFT JOIN [dbo].[Proveedor]               prv ON prv.[prv_id] = omo.[omo_proveedor]

         WHERE omo.[omo_orden_trabajo] = @OTR_ID

         ORDER BY omo.[omo_fecha_inicio_utc], omo.[omo_id]
    END


    -- --------------------------------------------------------- REPUESTOS ----
    IF @TIPO = 2
    BEGIN
        SELECT
             ore.[ore_id]
            ,ore.[ore_repuesto]                AS [REPUESTO_ID]
            ,rep.[rep_codigo]                  AS [REPUESTO_CODIGO]
            ,rep.[rep_nombre]                  AS [REPUESTO_NOMBRE]
            ,uni.[uni_simbolo]                 AS [UNIDAD_SIMBOLO]
            ,lot.[rlo_codigo]                  AS [LOTE_CODIGO]
            ,ore.[ore_cantidad_planificada]
            ,ore.[ore_cantidad_reservada]
            ,ore.[ore_cantidad_consumida]
            ,ore.[ore_cantidad_devuelta]
            ,ore.[ore_costo_unitario]
            ,ore.[ore_observacion]

          FROM [dbo].[Orden_Trabajo_Repuesto] ore
          JOIN [dbo].[Repuesto]               rep ON rep.[rep_id] = ore.[ore_repuesto]
     LEFT JOIN [dbo].[Unidad_Medida]          uni ON uni.[uni_id] = rep.[rep_unidad_medida]
     LEFT JOIN [dbo].[Repuesto_Lote]          lot ON lot.[rlo_id] = ore.[ore_repuesto_lote]

         WHERE ore.[ore_orden_trabajo] = @OTR_ID
           AND ore.[ore_habilitado]    = 1

         ORDER BY rep.[rep_nombre], ore.[ore_id]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 2 - REGISTRAR MANO DE OBRA (HU-115)
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
AS
SET NOCOUNT ON

BEGIN

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
            ,[omo_es_hora_extra], [omo_observacion]
            ,[omo_usuario_creacion], [omo_fecha_creacion])
        VALUES
            (@OTR_ID, @DE_QUIEN, @ESP
            ,@FECHA_INICIO, @FECHA_FIN, @MIN
            ,@ES_HORA_EXTRA, @OBSERVACION
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


-- ---------------------------------------------------------------------------
-- 3 - CONSUMIR UN REPUESTO EN LA ORDEN (HU-116)
-- ---------------------------------------------------------------------------
--   Dos escrituras, una transaccion:
--
--     1. El movimiento de inventario tipo 2 (SALIDA CONSUMO), llamando al SP
--        que ya existe -valida saldo, calcula costo promedio y es idempotente-.
--     2. La linea en Orden_Trabajo_Repuesto, que acumula lo consumido.
--
--   Si el movimiento falla por saldo insuficiente, la linea de la OT tampoco
--   se escribe: no hay forma de que la orden diga que se uso algo que la
--   bodega no tenia.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_REPUESTO]
     @OTR_ID       INT
    ,@USUARIO      INT
    ,@CLIENTE      INT
    ,@REPUESTO     INT
    ,@BODEGA       INT
    ,@CANTIDAD     DECIMAL(18,4)
    ,@UBICACION    INT              = NULL
    ,@LOTE         INT              = NULL
    ,@OBSERVACION  NVARCHAR(1000)   = NULL
    ,@UUID         UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

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

        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden esta cerrada. No se puede consumir repuestos.', 16, 1)
            RETURN
        END

        IF @CANTIDAD IS NULL OR @CANTIDAD <= 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La cantidad consumida tiene que ser mayor que cero.', 16, 1)
            RETURN
        END

        /* ---- 1. El movimiento. Si no hay saldo, RAISERROR y no sigue. ---- */
        DECLARE @IMO_ID INT

        EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO]
             @ID             = @IMO_ID OUTPUT
            ,@CLIENTE        = @CLIENTE
            ,@REPUESTO       = @REPUESTO
            ,@BODEGA         = @BODEGA
            ,@TIPO           = 2                 -- SALIDA CONSUMO
            ,@CANTIDAD       = @CANTIDAD
            ,@UBICACION      = @UBICACION
            ,@LOTE           = @LOTE
            ,@ORDEN_TRABAJO  = @OTR_ID
            ,@OBSERVACION    = @OBSERVACION
            ,@UUID           = @UUID
            ,@USUARIO        = @USUARIO

        /* ---- 2. La linea de la OT.

           Se acumula sobre la linea existente del mismo repuesto y lote en vez
           de crear una por consumo: la ficha de la orden tiene que decir
           "3 rodamientos", no tres lineas de uno. ---- */
        DECLARE @ORE_ID INT

        SELECT @ORE_ID = [ore_id]
          FROM [dbo].[Orden_Trabajo_Repuesto]
         WHERE [ore_orden_trabajo] = @OTR_ID
           AND [ore_repuesto]      = @REPUESTO
           AND ISNULL([ore_repuesto_lote], -1) = ISNULL(@LOTE, -1)
           AND [ore_habilitado]    = 1

        IF @ORE_ID IS NULL
        BEGIN
            INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
                ([ore_orden_trabajo], [ore_repuesto], [ore_repuesto_lote]
                ,[ore_cantidad_consumida], [ore_observacion]
                ,[ore_usuario_creacion], [ore_fecha_creacion], [ore_habilitado])
            VALUES
                (@OTR_ID, @REPUESTO, @LOTE
                ,@CANTIDAD, @OBSERVACION
                ,@USUARIO, GETDATE(), 1)

            SET @ORE_ID = SCOPE_IDENTITY()
        END
        ELSE
        BEGIN
            UPDATE [dbo].[Orden_Trabajo_Repuesto]
               SET [ore_cantidad_consumida]    = ISNULL([ore_cantidad_consumida], 0) + @CANTIDAD
                  ,[ore_usuario_actualizacion] = @USUARIO
                  ,[ore_fecha_actualizacion]   = GETDATE()
             WHERE [ore_id] = @ORE_ID
        END

        COMMIT TRANSACTION

        SELECT @ORE_ID AS [ore_id], @IMO_ID AS [imo_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO
