USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     EJECUTAR Y COMENTAR UNA TAREA EN TERRENO.
--                  HU-103 y HU-104, Sprint 4.
-- =============================================
-- QUE ES UNA TAREA Y POR QUE NO ES UNA ORDEN
--
--   Una tarea es el trabajo breve que hoy no deja ningun registro: revisar un
--   nivel, apretar un prensaestopas, limpiar un filtro. Abrir una OT para eso
--   es tanto papeleo que nadie lo hace, y lo que no se registra no existe -ni
--   para el historial del activo ni para dimensionar la carga real del
--   equipo-.
--
--   Por eso la tarea NO tiene pasos, ni permiso de trabajo, ni cierre por un
--   supervisor. Tiene una ocurrencia, alguien que la ejecuta y un resultado.
--
-- EL COMENTARIO ES APPEND-ONLY, Y LA TABLA LO DICE
--
--   Tarea_Comentario no tiene `habilitado` ni auditoria de actualizacion, y si
--   tiene `tco_comentario_padre`. La decision del modelo es clara: un
--   comentario no se edita ni se borra, se responde. Este bloque la respeta —
--   hay INS, no hay UPD ni DEL— porque un hilo que se puede reescribir deja de
--   servir como registro de lo que se dijo y cuando.
--
-- IDEMPOTENTE POR UUID
--
--   La ejecucion, por `tej_uuid`. El comentario, por (ocurrencia, usuario,
--   texto) dentro de una ventana corta: no tiene columna uuid propia, asi que
--   la proteccion es el contenido. Sin eso, un reintento de la cola dejaria el
--   hilo con el mismo comentario dos veces.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - LA SABANA DE TAREAS
-- ---------------------------------------------------------------------------
--   @TIPO  1 = mis tareas pendientes
--          2 = una ocurrencia con su ejecucion
--          3 = el hilo de comentarios
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_TAREA]
     @USUARIO      INT
    ,@CLIENTE      INT
    ,@TIPO         INT = 1
    ,@ID           INT = NULL
    ,@INSTALACION  INT = NULL
AS
SET NOCOUNT ON

BEGIN

    DECLARE @PLANTAS TABLE ([cin_id] INT PRIMARY KEY)

    INSERT INTO @PLANTAS ([cin_id])
    SELECT cin.[cin_id]
      FROM [dbo].[Cliente_Instalacion]         cin
      JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
             ON  ciu.[ciu_id_instalacion] = cin.[cin_id]
             AND ciu.[ciu_id_usuario]     = @USUARIO
             AND ISNULL(ciu.[ciu_habilitado], 0) = 1
     WHERE cin.[cin_cliente]    = @CLIENTE
       AND cin.[cin_habilitado] = 1
       AND (@INSTALACION IS NULL OR cin.[cin_id] = @INSTALACION)


    -- ------------------------------------------------------- PENDIENTES ----
    IF @TIPO = 1
    BEGIN
        SELECT
             toc.[toc_id]
            ,toc.[toc_uuid]
            ,tar.[tar_id]                       AS [TAREA_ID]
            ,tar.[tar_codigo]                   AS [TAREA_CODIGO]
            ,tar.[tar_titulo]
            ,tar.[tar_descripcion]
            ,tar.[tar_duracion_estimada_minuto]
            ,tar.[tar_requiere_evidencia]
            ,tpa.[tpa_codigo]                   AS [PRIORIDAD_CODIGO]
            ,tpa.[tpa_nombre]                   AS [PRIORIDAD_NOMBRE]
            ,tar.[tar_tarea_prioridad]          AS [PRIORIDAD_ID]
            ,act.[act_codigo]                   AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                   AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                   AS [AREA_NOMBRE]
            ,toc.[toc_tarea_ocurrencia_estado]  AS [ESTADO_ID]
            ,toe.[toe_codigo]                   AS [ESTADO_CODIGO]
            ,toe.[toe_nombre]                   AS [ESTADO_NOMBRE]
            ,toc.[toc_fecha_programada_utc]
            ,toc.[toc_fecha_limite_utc]
            ,toc.[toc_orden_trabajo]            AS [ORDEN_TRABAJO_ID]

            /* La situacion la decide el SP: si la calculara la app, dos
               telefonos con distinta hora dirian cosas distintas. */
            ,CASE
                WHEN toc.[toc_fecha_limite_utc] IS NULL THEN N'SIN PLAZO'
                WHEN toc.[toc_fecha_limite_utc] < GETUTCDATE() THEN N'VENCIDA'
                WHEN CAST(toc.[toc_fecha_limite_utc] AS DATE) = CAST(GETUTCDATE() AS DATE)
                     THEN N'VENCE HOY'
                ELSE N'EN PLAZO'
             END                                AS [SITUACION]

            ,(SELECT COUNT(*) FROM [dbo].[Tarea_Comentario] c
               WHERE c.[tco_tarea_ocurrencia] = toc.[toc_id])
                                                AS [COMENTARIOS]

            /* Una ejecucion abierta se retoma en vez de empezar otra. */
            ,(SELECT TOP 1 e.[tej_id] FROM [dbo].[Tarea_Ejecucion] e
               WHERE e.[tej_tarea_ocurrencia] = toc.[toc_id]
                 AND e.[tej_usuario_ejecutor] = @USUARIO
                 AND e.[tej_fecha_fin_utc] IS NULL
                 AND e.[tej_habilitado] = 1
               ORDER BY e.[tej_id] DESC)        AS [EJECUCION_ABIERTA]

          FROM [dbo].[Tarea_Ocurrencia]           toc
          JOIN [dbo].[Tarea]                      tar ON tar.[tar_id] = toc.[toc_tarea]
          JOIN [dbo].[Tarea_Ocurrencia_Estado]    toe ON toe.[toe_id] = toc.[toc_tarea_ocurrencia_estado]
     LEFT JOIN [dbo].[Tarea_Prioridad]            tpa ON tpa.[tpa_id] = tar.[tar_tarea_prioridad]
     LEFT JOIN [dbo].[Activo]                     act ON act.[act_id] = tar.[tar_activo]
     LEFT JOIN [dbo].[Instalacion_Area]           iar ON iar.[iar_id] = tar.[tar_instalacion_area]

         WHERE toc.[toc_cliente]    = @CLIENTE
           AND toc.[toc_habilitado] = 1
           AND toc.[toc_tarea_ocurrencia_estado] IN (1, 2, 3)
           AND (   tar.[tar_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
                OR act.[act_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
                OR iar.[iar_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS))
           /* Mias o sin dueno: una tarea breve sin asignar la puede tomar
              cualquiera del turno, que es justo lo que la hace util. */
           AND (   NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Asignacion] a
                                WHERE a.[toa_tarea_ocurrencia] = toc.[toc_id])
                OR EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Asignacion] a
                            WHERE a.[toa_tarea_ocurrencia] = toc.[toc_id]
                              AND a.[toa_usuario]          = @USUARIO))

         ORDER BY
              CASE WHEN toc.[toc_fecha_limite_utc] < GETUTCDATE() THEN 0 ELSE 1 END
             ,ISNULL(tpa.[tpa_orden], 0) DESC
             ,toc.[toc_fecha_limite_utc]
             ,toc.[toc_id]
    END


    -- -------------------------------------------------------- OCURRENCIA ----
    IF @TIPO = 2
    BEGIN
        SELECT
             toc.[toc_id]
            ,tar.[tar_codigo]                   AS [TAREA_CODIGO]
            ,tar.[tar_titulo]
            ,tar.[tar_descripcion]
            ,tar.[tar_requiere_evidencia]
            ,tar.[tar_duracion_estimada_minuto]
            ,tpa.[tpa_nombre]                   AS [PRIORIDAD_NOMBRE]
            ,tar.[tar_tarea_prioridad]          AS [PRIORIDAD_ID]
            ,act.[act_codigo]                   AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                   AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                   AS [AREA_NOMBRE]
            ,toc.[toc_tarea_ocurrencia_estado]  AS [ESTADO_ID]
            ,toe.[toe_nombre]                   AS [ESTADO_NOMBRE]
            ,toc.[toc_fecha_limite_utc]
            ,toc.[toc_observacion]
            ,tej.[tej_id]                       AS [EJECUCION_ID]
            ,tej.[tej_fecha_inicio_utc]
            ,tej.[tej_fecha_fin_utc]
            ,tej.[tej_duracion_minuto]
            ,tej.[tej_resultado]
            ,tej.[tej_conforme]

          FROM [dbo].[Tarea_Ocurrencia]        toc
          JOIN [dbo].[Tarea]                   tar ON tar.[tar_id] = toc.[toc_tarea]
          JOIN [dbo].[Tarea_Ocurrencia_Estado] toe ON toe.[toe_id] = toc.[toc_tarea_ocurrencia_estado]
     LEFT JOIN [dbo].[Tarea_Prioridad]         tpa ON tpa.[tpa_id] = tar.[tar_tarea_prioridad]
     LEFT JOIN [dbo].[Activo]                  act ON act.[act_id] = tar.[tar_activo]
     LEFT JOIN [dbo].[Instalacion_Area]        iar ON iar.[iar_id] = tar.[tar_instalacion_area]
     LEFT JOIN [dbo].[Tarea_Ejecucion]         tej ON tej.[tej_tarea_ocurrencia] = toc.[toc_id]
                                                  AND tej.[tej_habilitado] = 1

         WHERE toc.[toc_id]      = @ID
           AND toc.[toc_cliente] = @CLIENTE
    END


    -- ------------------------------------------------------- COMENTARIOS ----
    IF @TIPO = 3
    BEGIN
        SELECT
             tco.[tco_id]
            ,tco.[tco_comentario_padre]        AS [PADRE_ID]
            ,tco.[tco_texto]
            ,tco.[tco_dictado_voz]             AS [POR_VOZ]
            ,tco.[tco_usuario_creacion]        AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [USUARIO_NOMBRE]
            ,tco.[tco_fecha_creacion]

          FROM [dbo].[Tarea_Comentario]  tco
          JOIN [dbo].[Tarea_Ocurrencia]  toc ON toc.[toc_id] = tco.[tco_tarea_ocurrencia]
     LEFT JOIN [dbo].[Usuario]           usr ON usr.[usu_id] = tco.[tco_usuario_creacion]

         WHERE tco.[tco_tarea_ocurrencia] = @ID
           AND toc.[toc_cliente]          = @CLIENTE

         /* Por fecha y no por id: el hilo se lee en el orden en que se dijo,
            y con captura sin senal el id no respeta ese orden. */
         ORDER BY tco.[tco_fecha_creacion], tco.[tco_id]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 2 - EMPEZAR Y TERMINAR UNA TAREA (HU-103)
-- ---------------------------------------------------------------------------
--   Un solo SP para las dos cosas. La tarea breve se empieza y se termina en
--   minutos, muchas veces en la misma pantalla y sin senal: partirlo en dos
--   endpoints obligaria a la cola a mantener el orden entre ellos, y un
--   «terminar» que llega antes que su «empezar» no tiene arreglo.
--
--   Con @FINALIZAR = 0 abre (o retoma); con 1 cierra. Idempotente por uuid en
--   la apertura, y por estado en el cierre.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID          UNIQUEIDENTIFIER
    ,@USUARIO       INT
    ,@CLIENTE       INT
    ,@OCURRENCIA    INT
    ,@FINALIZAR     BIT            = 0
    ,@CONFORME      BIT            = NULL
    ,@RESULTADO     NVARCHAR(MAX)  = NULL
    ,@MINUTOS       INT            = NULL
    ,@DISPOSITIVO   NVARCHAR(200)  = NULL
    ,@OFFLINE       BIT            = 0
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

        SELECT @ESTADO = toc.[toc_tarea_ocurrencia_estado]
          FROM [dbo].[Tarea_Ocurrencia] toc
          JOIN [dbo].[Tarea]            tar ON tar.[tar_id] = toc.[toc_tarea]
     LEFT JOIN [dbo].[Activo]           act ON act.[act_id] = tar.[tar_activo]
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = ISNULL(tar.[tar_cliente_instalacion],
                                                       act.[act_cliente_instalacion])
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE toc.[toc_id]         = @OCURRENCIA
           AND toc.[toc_cliente]    = @CLIENTE
           AND toc.[toc_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La tarea no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta tarea ya esta cerrada.', 16, 1)
            RETURN
        END

        /* ---- La ejecucion: por uuid, o la abierta de esta persona ---- */
        DECLARE @TEJ INT

        SELECT @TEJ = [tej_id]
          FROM [dbo].[Tarea_Ejecucion]
         WHERE [tej_uuid] = @UUID

        IF @TEJ IS NULL
            SELECT TOP 1 @TEJ = [tej_id]
              FROM [dbo].[Tarea_Ejecucion]
             WHERE [tej_tarea_ocurrencia] = @OCURRENCIA
               AND [tej_usuario_ejecutor] = @USUARIO
               AND [tej_fecha_fin_utc] IS NULL
               AND [tej_habilitado]       = 1
             ORDER BY [tej_id] DESC

        IF @TEJ IS NULL
        BEGIN
            INSERT INTO [dbo].[Tarea_Ejecucion]
                ([tej_uuid], [tej_tarea_ocurrencia], [tej_usuario_ejecutor]
                ,[tej_fecha_inicio_utc], [tej_dispositivo], [tej_offline_creado]
                ,[tej_usuario_creacion], [tej_fecha_creacion], [tej_habilitado])
            VALUES
                (@UUID, @OCURRENCIA, @USUARIO
                ,GETUTCDATE(), @DISPOSITIVO, @OFFLINE
                ,@USUARIO, GETDATE(), 1)

            SET @TEJ = SCOPE_IDENTITY()

            UPDATE [dbo].[Tarea_Ocurrencia]
               SET [toc_tarea_ocurrencia_estado] = 3          -- EN EJECUCION
                  ,[toc_usuario_actualizacion]   = @USUARIO
                  ,[toc_fecha_actualizacion]     = GETDATE()
             WHERE [toc_id] = @OCURRENCIA
               AND [toc_tarea_ocurrencia_estado] IN (1, 2)

            /* Quien la toma queda como responsable, si no habia ninguno. */
            IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Asignacion]
                            WHERE [toa_tarea_ocurrencia] = @OCURRENCIA
                              AND [toa_es_responsable]   = 1)
                INSERT INTO [dbo].[Tarea_Ocurrencia_Asignacion]
                    ([toa_tarea_ocurrencia], [toa_usuario], [toa_es_responsable]
                    ,[toa_fecha_asignacion_utc], [toa_fecha_aceptacion_utc]
                    ,[toa_usuario_creacion], [toa_fecha_creacion])
                VALUES
                    (@OCURRENCIA, @USUARIO, 1
                    ,GETUTCDATE(), GETUTCDATE()
                    ,@USUARIO, GETDATE())
        END

        /* ---- El cierre ---- */
        IF @FINALIZAR = 1
        BEGIN
            DECLARE @YA_CERRADA BIT =
                CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Tarea_Ejecucion]
                                   WHERE [tej_id] = @TEJ
                                     AND [tej_fecha_fin_utc] IS NOT NULL)
                     THEN 1 ELSE 0 END

            IF @YA_CERRADA = 1
            BEGIN
                COMMIT TRANSACTION
                SELECT @TEJ AS [tej_id], 1 AS [YA_ESTABA]
                RETURN
            END

            /* «No realizada» necesita explicacion: sin motivo, una tarea que
               no se hizo es indistinguible de una que se olvido, y el
               historial del activo queda con un hueco que nadie puede
               interpretar despues. */
            IF @CONFORME = 0 AND LTRIM(RTRIM(ISNULL(@RESULTADO, N''))) = N''
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('Si la tarea no se pudo hacer, escribe por que.', 16, 1)
                RETURN
            END

            DECLARE @INICIO DATETIME =
                (SELECT [tej_fecha_inicio_utc] FROM [dbo].[Tarea_Ejecucion] WHERE [tej_id] = @TEJ)

            UPDATE [dbo].[Tarea_Ejecucion]
               SET [tej_fecha_fin_utc]            = GETUTCDATE()
                  ,[tej_duracion_minuto]          = ISNULL(@MINUTOS,
                                                      DATEDIFF(MINUTE, @INICIO, GETUTCDATE()))
                  ,[tej_resultado]                = @RESULTADO
                  ,[tej_conforme]                 = ISNULL(@CONFORME, 1)
                  ,[tej_fecha_sincronizacion_utc] = GETUTCDATE()
                  ,[tej_usuario_actualizacion]    = @USUARIO
                  ,[tej_fecha_actualizacion]      = GETDATE()
             WHERE [tej_id] = @TEJ

            /* Conforme -> COMPLETADA; no conforme -> NO REALIZADA. Son dos
               desenlaces distintos y el historial tiene que distinguirlos. */
            UPDATE [dbo].[Tarea_Ocurrencia]
               SET [toc_tarea_ocurrencia_estado] =
                       CASE WHEN ISNULL(@CONFORME, 1) = 1 THEN 4 ELSE 5 END
                  ,[toc_usuario_actualizacion]   = @USUARIO
                  ,[toc_fecha_actualizacion]     = GETDATE()
             WHERE [toc_id] = @OCURRENCIA
        END

        COMMIT TRANSACTION
        SELECT @TEJ AS [tej_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 3 - COMENTAR (HU-104)
-- ---------------------------------------------------------------------------
--   No hay UPD ni DEL a proposito: Tarea_Comentario no tiene `habilitado` ni
--   auditoria de actualizacion, y si tiene `tco_comentario_padre`. El modelo
--   dice que un comentario no se edita, se responde -y un hilo que se puede
--   reescribir deja de servir como registro de lo que se dijo y cuando-.
--
--   La idempotencia va por contenido: la tabla no tiene uuid, asi que se
--   compara (ocurrencia, usuario, texto) dentro de cinco minutos. Sin eso, un
--   reintento de la cola dejaria el mismo comentario dos veces en el hilo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_TAREA_COMENTARIO]
     @OCURRENCIA  INT
    ,@USUARIO     INT
    ,@CLIENTE     INT
    ,@TEXTO       NVARCHAR(MAX)
    ,@PADRE       INT = NULL
    ,@POR_VOZ     BIT = 0
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario esta vacio.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Tarea_Ocurrencia] toc
                         JOIN [dbo].[Tarea]            tar ON tar.[tar_id] = toc.[toc_tarea]
                    LEFT JOIN [dbo].[Activo]           act ON act.[act_id] = tar.[tar_activo]
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = ISNULL(tar.[tar_cliente_instalacion],
                                                                      act.[act_cliente_instalacion])
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE toc.[toc_id]      = @OCURRENCIA
                          AND toc.[toc_cliente] = @CLIENTE)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La tarea no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* El padre tiene que ser del mismo hilo: una respuesta que apunta a
           otro comentario deja el arbol imposible de dibujar. */
        IF @PADRE IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Comentario]
                            WHERE [tco_id] = @PADRE
                              AND [tco_tarea_ocurrencia] = @OCURRENCIA)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario al que respondes no es de esta tarea.', 16, 1)
            RETURN
        END

        DECLARE @YA INT

        SELECT TOP 1 @YA = [tco_id]
          FROM [dbo].[Tarea_Comentario]
         WHERE [tco_tarea_ocurrencia] = @OCURRENCIA
           AND [tco_usuario_creacion] = @USUARIO
           AND [tco_texto]            = @TEXTO
           AND [tco_fecha_creacion]  >= DATEADD(MINUTE, -5, GETDATE())
         ORDER BY [tco_id] DESC

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SELECT @YA AS [tco_id], 1 AS [YA_ESTABA]
            RETURN
        END

        INSERT INTO [dbo].[Tarea_Comentario]
            ([tco_tarea_ocurrencia], [tco_comentario_padre], [tco_texto]
            ,[tco_dictado_voz], [tco_usuario_creacion], [tco_fecha_creacion])
        VALUES
            (@OCURRENCIA, @PADRE, @TEXTO
            ,CASE WHEN @POR_VOZ = 1 THEN 2 ELSE NULL END
            ,@USUARIO, GETDATE())

        DECLARE @TCO INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @TCO AS [tco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO
