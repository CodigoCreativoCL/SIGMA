USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     ORDENES DE TRABAJO PARA LA APP MOVIL.
--                  HU-121 (bandeja), HU-113 (tomar), HU-114 (ejecutar
--                  pasos) y HU-119 (finalizar) del Sprint 5.
-- =============================================
-- POR QUE ESTE BLOQUE
--
--   El modelo de ordenes ya estaba completo: Orden_Trabajo con sus quince
--   tablas satelite. Lo que faltaba eran los procedimientos: de los cinco que
--   existian, tres eran de cierre y ninguno sabia LISTAR.
--
--   Sin un SELECT no hay bandeja, y sin bandeja la app no tiene por donde
--   empezar el turno.
--
-- DOS DEFECTOS CORREGIDOS EN UPD_ORDEN_TRABAJO_TOMAR
--
--   (1) La transicion estaba al reves. El catalogo es
--       1 ABIERTA, 2 EN EJECUCION, 3 EN ESPERA DE CIERRE, 4 CERRADA,
--       y el SP hacia 2 -> 3 con el comentario "-- EN EJECUCION" sobre el 3.
--       O sea: tomar una orden ABIERTA no hacia nada (0 filas, y el RAISERROR
--       decia "ya fue tomada por otro"), y una orden ya en ejecucion saltaba
--       a espera de cierre SIN QUE NADIE HICIERA EL TRABAJO.
--       Lo correcto es 1 -> 2, y asi queda.
--
--       Se comprueba contra UPD_ORDEN_TRABAJO_FINALIZAR, que si estaba bien:
--       ese va de IN (1,2) a 3 "EN ESPERA DE CIERRE".
--
--   (2) ota_rol_ejecucion es un INT con FK a Rol_Ejecucion, y el SP insertaba
--       N'EJECUTOR'. Conversion imposible. El valor correcto es 1
--       (EJECUTOR PRINCIPAL).
--
--   Con los dos defectos, este SP nunca pudo ejecutarse con exito.
--
-- LA SEGURIDAD VA ADENTRO
--
--   Igual que en el bloque 140: cliente y plantas autorizadas se resuelven en
--   el propio SP contra Cliente_Instalacion_Usuario. Un filtro en el
--   controller se salta cambiando un parametro; uno aca, no.
--
-- ORDER BY EXPLICITO
--
--   SQLite no conserva el orden de insercion. El orden se define donde se
--   define el dato.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - CORRECCION: tomar una orden es pasar de ABIERTA a EN EJECUCION
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_TOMAR]
     @OTR_ID   INT
    ,@USUARIO  INT
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO_ANTERIOR INT

        SELECT @ESTADO_ANTERIOR = [otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo]
         WHERE [otr_id] = @OTR_ID

        IF @ESTADO_ANTERIOR IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden de trabajo no existe.', 16, 1)
            RETURN
        END

        /* La carrera se decide en el WHERE: dos tecnicos que tocan "Tomar" al
           mismo tiempo llegan los dos aca, y solo uno encuentra la fila en
           estado 1. El otro recibe el mensaje, no un duplicado. */
        UPDATE [dbo].[Orden_Trabajo]
           SET [otr_orden_trabajo_estado]  = 2                   -- EN EJECUCION
              ,[otr_usuario_responsable]   = @USUARIO
              ,[otr_fecha_inicio_real_utc] = ISNULL([otr_fecha_inicio_real_utc], GETUTCDATE())
              ,[otr_usuario_actualizacion] = @USUARIO
              ,[otr_fecha_actualizacion]   = GETDATE()
         WHERE [otr_id]                   = @OTR_ID
           AND [otr_orden_trabajo_estado] = 1                    -- ABIERTA
           AND [otr_habilitado]           = 1

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden ya fue tomada por otro usuario o no esta abierta.', 16, 1)
            RETURN
        END

        /* El que la tomo queda como responsable. Puede sumar a otros despues.
           El rol es 1 = EJECUTOR PRINCIPAL, del catalogo Rol_Ejecucion. */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Orden_Trabajo_Asignacion]
                        WHERE [ota_orden_trabajo]  = @OTR_ID
                          AND [ota_es_responsable] = 1
                          AND [ota_habilitado]     = 1)
            INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
                ([ota_orden_trabajo], [ota_usuario], [ota_es_responsable]
                ,[ota_rol_ejecucion], [ota_fecha_asignacion_utc]
                ,[ota_fecha_aceptacion_utc], [ota_usuario_creacion], [ota_asignado_por])
            VALUES
                (@OTR_ID, @USUARIO, 1, 1, GETUTCDATE(), GETUTCDATE(), @USUARIO, @USUARIO)

        INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
            ([oeh_orden_trabajo], [oeh_estado_anterior], [oeh_estado_nuevo]
            ,[oeh_motivo], [oeh_usuario_creacion])
        VALUES
            (@OTR_ID, @ESTADO_ANTERIOR, 2, N'Tomada por el ejecutante', @USUARIO)

        COMMIT TRANSACTION
        SELECT @OTR_ID AS [otr_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 2 - LA SABANA DE ORDENES: bandeja, ficha, pasos y asignados
-- ---------------------------------------------------------------------------
--   @TIPO  1 = bandeja (lista)
--          2 = ficha (cabecera de una)
--          3 = pasos de una
--          4 = asignados de una
--
--   @AMBITO de la bandeja:
--          1 = mias (soy responsable o estoy asignado)   <- lo normal
--          2 = disponibles (abiertas sin responsable)    <- "tomar trabajo"
--          3 = todas las de mis plantas
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ORDEN_TRABAJO]
     @USUARIO      INT
    ,@CLIENTE      INT
    ,@TIPO         INT      = 1
    ,@OTR_ID       INT      = NULL
    ,@AMBITO       INT      = 1
    ,@INSTALACION  INT      = NULL
    ,@DESDE        DATETIME = NULL
AS
SET NOCOUNT ON

BEGIN

    /* Las plantas que esta persona puede ver. Se resuelve UNA vez: repetir el
       encadenado en cada bloque es repetir la regla de seguridad cuatro
       veces, y la cuarta es la que sale mal. */
    DECLARE @PLANTAS TABLE ([cin_id] INT PRIMARY KEY)

    INSERT INTO @PLANTAS ([cin_id])
    SELECT ciu.[ciu_cliente_instalacion]
      FROM [dbo].[Cliente_Instalacion_Usuario] ciu
      JOIN [dbo].[Cliente_Instalacion]         cin ON cin.[cin_id] = ciu.[ciu_cliente_instalacion]
     WHERE ciu.[ciu_usuario]   = @USUARIO
       AND ciu.[ciu_habilitado] = 1
       AND cin.[cin_cliente]    = @CLIENTE
       AND cin.[cin_habilitado] = 1
       AND (@INSTALACION IS NULL OR cin.[cin_id] = @INSTALACION)


    -- ---------------------------------------------------------- BANDEJA ----
    IF @TIPO = 1
    BEGIN
        SELECT
             otr.[otr_id]
            ,otr.[otr_uuid]
            ,otr.[otr_correlativo]
            ,N'OT-' + CAST(otr.[otr_correlativo] AS NVARCHAR(20)) AS [OT_NUMERO]
            ,otr.[otr_titulo]
            ,otr.[otr_descripcion]
            ,otr.[otr_fecha_programada_utc]
            ,otr.[otr_fecha_inicio_real_utc]
            ,otr.[otr_requiere_permiso]
            ,otr.[otr_duracion_estimada_minuto]

            ,otr.[otr_orden_trabajo_estado]                AS [ESTADO_ID]
            ,ote.[ote_codigo]                              AS [ESTADO_CODIGO]
            ,ote.[ote_nombre]                              AS [ESTADO_NOMBRE]
            ,otr.[otr_orden_trabajo_prioridad]             AS [PRIORIDAD_ID]
            ,opr.[opr_codigo]                              AS [PRIORIDAD_CODIGO]
            ,opr.[opr_nombre]                              AS [PRIORIDAD_NOMBRE]
            ,ott.[ott_nombre]                              AS [TIPO_NOMBRE]
            ,oet.[oet_nombre]                              AS [ESTRATEGIA_NOMBRE]

            ,act.[act_codigo]                              AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                              AS [ACTIVO_NOMBRE]
            ,cin.[cin_nombre]                              AS [PLANTA_NOMBRE]
            ,iar.[iar_nombre]                              AS [AREA_NOMBRE]

            ,otr.[otr_usuario_responsable]                 AS [RESPONSABLE_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'') AS [RESPONSABLE_NOMBRE]

            /* El avance sale de los pasos, no de un campo aparte: un
               porcentaje guardado se desincroniza del detalle en cuanto
               alguien completa un paso desde otro lado. */
            ,(SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p
               WHERE p.[otp_orden_trabajo] = otr.[otr_id] AND p.[otp_habilitado] = 1)
                                                           AS [PASOS_TOTAL]
            ,(SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p
               WHERE p.[otp_orden_trabajo] = otr.[otr_id] AND p.[otp_habilitado] = 1
                 AND p.[otp_resultado_paso] <> 4)          AS [PASOS_LISTOS]

            /* VENCIDA / VENCE HOY / EN PLAZO lo decide el SP, no la pantalla:
               si lo calculara la app, dos telefonos con distinta hora darian
               veredictos distintos sobre la misma orden. */
            ,CASE
                WHEN otr.[otr_fecha_programada_utc] IS NULL THEN N'SIN PLAZO'
                WHEN otr.[otr_fecha_programada_utc] <  CAST(GETUTCDATE() AS DATE) THEN N'VENCIDA'
                WHEN CAST(otr.[otr_fecha_programada_utc] AS DATE) = CAST(GETUTCDATE() AS DATE) THEN N'VENCE HOY'
                ELSE N'EN PLAZO'
             END                                           AS [SITUACION]
            ,DATEDIFF(DAY, GETUTCDATE(), otr.[otr_fecha_programada_utc]) AS [DIAS_RESTANTES]

            ,CASE WHEN otr.[otr_usuario_responsable] = @USUARIO THEN 1 ELSE 0 END AS [ES_MIA]
            ,otr.[otr_fecha_actualizacion]

          FROM [dbo].[Orden_Trabajo]              otr
          JOIN @PLANTAS                            pl ON pl.[cin_id] = otr.[otr_cliente_instalacion]
          JOIN [dbo].[Orden_Trabajo_Estado]       ote ON ote.[ote_id] = otr.[otr_orden_trabajo_estado]
          JOIN [dbo].[Orden_Trabajo_Prioridad]    opr ON opr.[opr_id] = otr.[otr_orden_trabajo_prioridad]
          JOIN [dbo].[Orden_Trabajo_Tipo]         ott ON ott.[ott_id] = otr.[otr_orden_trabajo_tipo]
          JOIN [dbo].[Orden_Trabajo_Estrategia]   oet ON oet.[oet_id] = otr.[otr_orden_trabajo_estrategia]
          JOIN [dbo].[Cliente_Instalacion]        cin ON cin.[cin_id] = otr.[otr_cliente_instalacion]
     LEFT JOIN [dbo].[Activo]                     act ON act.[act_id] = otr.[otr_activo]
     LEFT JOIN [dbo].[Instalacion_Area]           iar ON iar.[iar_id] = otr.[otr_instalacion_area]
     LEFT JOIN [dbo].[Usuario]                    usr ON usr.[usu_id] = otr.[otr_usuario_responsable]

         WHERE otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1
           AND (@DESDE IS NULL OR otr.[otr_fecha_actualizacion] >= @DESDE
                               OR otr.[otr_fecha_creacion]      >= @DESDE)
           AND (
                 /* MIAS: soy el responsable o estoy en la asignacion. */
                 (@AMBITO = 1 AND (otr.[otr_usuario_responsable] = @USUARIO
                                   OR EXISTS (SELECT 1
                                                FROM [dbo].[Orden_Trabajo_Asignacion] a
                                               WHERE a.[ota_orden_trabajo] = otr.[otr_id]
                                                 AND a.[ota_usuario]       = @USUARIO
                                                 AND a.[ota_habilitado]    = 1)))
                 /* DISPONIBLES: abiertas y sin dueno. Es la lista de "tomar
                    trabajo", y por eso excluye las que ya tienen responsable
                    aunque esten abiertas. */
              OR (@AMBITO = 2 AND otr.[otr_orden_trabajo_estado] = 1
                              AND otr.[otr_usuario_responsable] IS NULL)
              OR (@AMBITO = 3)
               )

         ORDER BY
              /* Lo vencido primero, despues lo mas prioritario, despues lo que
                 vence antes. Es el orden en que un tecnico decide que hacer. */
              CASE WHEN otr.[otr_fecha_programada_utc] < GETUTCDATE() THEN 0 ELSE 1 END
             ,opr.[opr_orden] DESC
             ,otr.[otr_fecha_programada_utc]
             ,otr.[otr_id]
    END


    -- ------------------------------------------------------------ FICHA ----
    IF @TIPO = 2
    BEGIN
        SELECT
             otr.[otr_id]
            ,otr.[otr_uuid]
            ,otr.[otr_correlativo]
            ,N'OT-' + CAST(otr.[otr_correlativo] AS NVARCHAR(20)) AS [OT_NUMERO]
            ,otr.[otr_titulo]
            ,otr.[otr_descripcion]
            ,otr.[otr_notas]
            ,otr.[otr_resultado]
            ,otr.[otr_fecha_evento_utc]
            ,otr.[otr_fecha_programada_utc]
            ,otr.[otr_fecha_inicio_real_utc]
            ,otr.[otr_fecha_fin_real_utc]
            ,otr.[otr_duracion_estimada_minuto]
            ,otr.[otr_duracion_real_minuto]
            ,otr.[otr_requiere_permiso]

            ,otr.[otr_orden_trabajo_estado]   AS [ESTADO_ID]
            ,ote.[ote_codigo]                 AS [ESTADO_CODIGO]
            ,ote.[ote_nombre]                 AS [ESTADO_NOMBRE]
            ,opr.[opr_codigo]                 AS [PRIORIDAD_CODIGO]
            ,opr.[opr_nombre]                 AS [PRIORIDAD_NOMBRE]
            ,ott.[ott_nombre]                 AS [TIPO_NOMBRE]
            ,oet.[oet_nombre]                 AS [ESTRATEGIA_NOMBRE]

            ,otr.[otr_activo]                 AS [ACTIVO_ID]
            ,act.[act_codigo]                 AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                 AS [ACTIVO_NOMBRE]
            ,cin.[cin_nombre]                 AS [PLANTA_NOMBRE]
            ,iar.[iar_nombre]                 AS [AREA_NOMBRE]

            ,otr.[otr_usuario_responsable]    AS [RESPONSABLE_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'') AS [RESPONSABLE_NOMBRE]

            ,(SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p
               WHERE p.[otp_orden_trabajo] = otr.[otr_id] AND p.[otp_habilitado] = 1)
                                              AS [PASOS_TOTAL]
            ,(SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p
               WHERE p.[otp_orden_trabajo] = otr.[otr_id] AND p.[otp_habilitado] = 1
                 AND p.[otp_resultado_paso] <> 4)
                                              AS [PASOS_LISTOS]

            /* El permiso de trabajo vigente, si la OT lo exige. Va en la ficha
               y no en una consulta aparte porque sin el no se abre la maquina:
               es parte de poder empezar, no un dato de consulta. */
            ,(SELECT TOP 1 pt.[ptr_numero]
                FROM [dbo].[Permiso_Trabajo] pt
               WHERE pt.[ptr_orden_trabajo] = otr.[otr_id]
                 AND pt.[ptr_habilitado]    = 1
               ORDER BY pt.[ptr_id] DESC)     AS [PERMISO_NUMERO]

          FROM [dbo].[Orden_Trabajo]            otr
          JOIN @PLANTAS                          pl ON pl.[cin_id] = otr.[otr_cliente_instalacion]
          JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.[ote_id] = otr.[otr_orden_trabajo_estado]
          JOIN [dbo].[Orden_Trabajo_Prioridad]  opr ON opr.[opr_id] = otr.[otr_orden_trabajo_prioridad]
          JOIN [dbo].[Orden_Trabajo_Tipo]       ott ON ott.[ott_id] = otr.[otr_orden_trabajo_tipo]
          JOIN [dbo].[Orden_Trabajo_Estrategia] oet ON oet.[oet_id] = otr.[otr_orden_trabajo_estrategia]
          JOIN [dbo].[Cliente_Instalacion]      cin ON cin.[cin_id] = otr.[otr_cliente_instalacion]
     LEFT JOIN [dbo].[Activo]                   act ON act.[act_id] = otr.[otr_activo]
     LEFT JOIN [dbo].[Instalacion_Area]         iar ON iar.[iar_id] = otr.[otr_instalacion_area]
     LEFT JOIN [dbo].[Usuario]                  usr ON usr.[usu_id] = otr.[otr_usuario_responsable]

         WHERE otr.[otr_id]         = @OTR_ID
           AND otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1
    END


    -- ------------------------------------------------------------ PASOS ----
    IF @TIPO = 3
    BEGIN
        SELECT
             otp.[otp_id]
            ,otp.[otp_orden_trabajo]
            ,otp.[otp_orden]
            ,otp.[otp_nombre]
            ,otp.[otp_descripcion]
            ,otp.[otp_obligatorio]
            ,otp.[otp_resultado_paso]      AS [RESULTADO_ID]
            ,rpa.[rpa_codigo]              AS [RESULTADO_CODIGO]
            ,rpa.[rpa_nombre]              AS [RESULTADO_NOMBRE]
            ,otp.[otp_resultado]           AS [OBSERVACION]
            ,otp.[otp_usuario_ejecutor]    AS [EJECUTOR_ID]
            ,usr.[usu_nombre]              AS [EJECUTOR_NOMBRE]
            ,otp.[otp_fecha_ejecucion_utc]

          FROM [dbo].[Orden_Trabajo_Paso] otp
          JOIN [dbo].[Orden_Trabajo]      otr ON otr.[otr_id] = otp.[otp_orden_trabajo]
          JOIN @PLANTAS                    pl ON pl.[cin_id] = otr.[otr_cliente_instalacion]
          JOIN [dbo].[Resultado_Paso]     rpa ON rpa.[rpa_id] = otp.[otp_resultado_paso]
     LEFT JOIN [dbo].[Usuario]            usr ON usr.[usu_id] = otp.[otp_usuario_ejecutor]

         WHERE otp.[otp_orden_trabajo] = @OTR_ID
           AND otr.[otr_cliente]       = @CLIENTE
           AND otp.[otp_habilitado]    = 1

         ORDER BY otp.[otp_orden], otp.[otp_id]
    END


    -- -------------------------------------------------------- ASIGNADOS ----
    IF @TIPO = 4
    BEGIN
        SELECT
             ota.[ota_id]
            ,ota.[ota_usuario]              AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'') AS [USUARIO_NOMBRE]
            ,ota.[ota_es_responsable]
            ,rej.[rej_nombre]               AS [ROL_NOMBRE]
            ,ota.[ota_fecha_asignacion_utc]
            ,ota.[ota_fecha_aceptacion_utc]

          FROM [dbo].[Orden_Trabajo_Asignacion] ota
          JOIN [dbo].[Orden_Trabajo]            otr ON otr.[otr_id] = ota.[ota_orden_trabajo]
          JOIN @PLANTAS                          pl ON pl.[cin_id] = otr.[otr_cliente_instalacion]
     LEFT JOIN [dbo].[Usuario]                  usr ON usr.[usu_id] = ota.[ota_usuario]
     LEFT JOIN [dbo].[Rol_Ejecucion]            rej ON rej.[rej_id] = ota.[ota_rol_ejecucion]

         WHERE ota.[ota_orden_trabajo] = @OTR_ID
           AND otr.[otr_cliente]       = @CLIENTE
           AND ota.[ota_habilitado]    = 1

         ORDER BY ota.[ota_es_responsable] DESC, ota.[ota_id]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 3 - COMPLETAR UN PASO (HU-114)
-- ---------------------------------------------------------------------------
--   La app captura el paso en terreno y lo envia cuando hay senal. Por eso:
--
--   * Se comprueba que la OT este EN EJECUCION: completar pasos de una orden
--     cerrada dejaria un registro que nadie puede explicar.
--
--   * Se comprueba que quien lo completa sea el responsable o este asignado.
--     La regla vive aca y no en la pantalla porque la app puede estar
--     desactualizada; el servidor no.
--
--   * Es IDEMPOTENTE por paso: reenviar el mismo paso ya completado no
--     duplica ni falla, devuelve lo mismo. Es el caso del timeout, donde el
--     servidor grabo pero la respuesta no llego.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ORDEN_TRABAJO_PASO]
     @OTP_ID           INT
    ,@USUARIO          INT
    ,@CLIENTE          INT
    ,@RESULTADO_PASO   INT              -- 1 CONFORME, 2 NO CONFORME, 3 NO APLICA
    ,@OBSERVACION      NVARCHAR(MAX) = NULL
    ,@ENTRADA_MODO     INT           = 1  -- 1 TECLADO, 2 VOZ
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @OTR_ID INT, @ESTADO INT, @YA INT

        SELECT @OTR_ID = otr.[otr_id]
              ,@ESTADO = otr.[otr_orden_trabajo_estado]
              ,@YA     = otp.[otp_resultado_paso]
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

        UPDATE [dbo].[Orden_Trabajo_Paso]
           SET [otp_resultado_paso]       = @RESULTADO_PASO
              ,[otp_resultado]            = @OBSERVACION
              ,[otp_usuario_ejecutor]     = @USUARIO
              ,[otp_fecha_ejecucion_utc]  = GETUTCDATE()
              ,[otp_usuario_actualizacion] = @USUARIO
              ,[otp_fecha_actualizacion]   = GETDATE()
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
