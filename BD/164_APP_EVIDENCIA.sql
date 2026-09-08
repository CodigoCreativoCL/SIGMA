USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     FOTOS DE EVIDENCIA DESDE EL TELEFONO.
-- =============================================
-- UN SP Y NO UNO POR PANTALLA
--
--   `Archivo_Vinculo` es polimorfica a proposito: tiene una columna por cada
--   cosa a la que se le puede colgar un archivo -orden, paso, falla, bitacora,
--   respuesta de checklist, hallazgo, permiso de trabajo, tarea-. El modelo ya
--   decidio que la evidencia es una sola idea con muchos duenos, asi que un
--   INS por pantalla seria repetir ocho veces la misma escritura y garantizar
--   que un dia difieran.
--
--   El @DESTINO dice a cual columna va. Es feo comparado con ocho SP, pero es
--   una fealdad que se lee en un solo lugar.
--
-- EL BLOB VA PRIMERO, LA FILA DESPUES
--
--   Es la regla que ya fijo `INS_ARCHIVO` y este bloque la respeta: una fila
--   sin blob es un enlace roto silencioso -alguien abre la foto meses despues
--   y no hay nada-, y un blob sin fila es basura que se puede recolectar. De
--   los dos desastres se elige el recuperable.
--
-- IDEMPOTENTE POR EL UUID DEL ARCHIVO
--
--   Lo genera el telefono al sacar la foto, no al enviarla. Una foto tomada
--   sin senal se reintenta varias veces; sin esto, la tarea quedaria con la
--   misma foto cuatro veces y nadie sabria cual mirar.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - REGISTRAR UNA EVIDENCIA YA SUBIDA AL BLOB
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_EVIDENCIA]
     @UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT

    /* TAREA | ORDEN | PASO | RESPUESTA | FALLA | HALLAZGO | ACTIVO */
    ,@DESTINO           NVARCHAR(20)
    ,@DESTINO_ID        INT

    ,@CATEGORIA         INT            = 5          -- 5 = DURANTE
    ,@NOMBRE_ORIGINAL   NVARCHAR(255)
    ,@NOMBRE_ALMACENADO NVARCHAR(255)
    ,@RUTA              NVARCHAR(500)
    ,@MIME              NVARCHAR(100)  = N'image/jpeg'
    ,@EXTENSION         NVARCHAR(20)   = N'jpg'
    ,@BYTE              BIGINT
    ,@HASH              NVARCHAR(64)   = NULL
    ,@ANCHO             INT            = NULL
    ,@ALTO              INT            = NULL
    ,@LATITUD           DECIMAL(9,6)   = NULL
    ,@LONGITUD          DECIMAL(9,6)   = NULL
    ,@CAPTURA_UTC       DATETIME       = NULL
    ,@DISPOSITIVO       NVARCHAR(400)  = NULL
    ,@TITULO            NVARCHAR(400)  = NULL
    ,@DESCRIPCION       NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY

        DECLARE @DES NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@DESTINO, N''))))

        IF @DES NOT IN (N'TAREA', N'ORDEN', N'PASO', N'RESPUESTA',
                        N'FALLA', N'HALLAZGO', N'ACTIVO')
        BEGIN
            RAISERROR('Ese destino de evidencia no existe.', 16, 1)
            RETURN
        END

        /* ---- Reenvio de la cola: devolver lo mismo, no una segunda foto ---- */
        DECLARE @ARC INT

        SELECT @ARC = [arc_id] FROM [dbo].[Archivo] WHERE [arc_uuid] = @UUID

        IF @ARC IS NOT NULL
        BEGIN
            SELECT @ARC AS [arc_id], 1 AS [YA_ESTABA]
            RETURN
        END

        BEGIN TRANSACTION

        INSERT INTO [dbo].[Archivo]
            ([arc_uuid], [arc_cliente], [arc_archivo_categoria]
            ,[arc_nombre_original], [arc_nombre_almacenado], [arc_ruta]
            ,[arc_mime], [arc_extension], [arc_byte], [arc_hash]
            ,[arc_ancho_pixel], [arc_alto_pixel]
            ,[arc_latitud], [arc_longitud], [arc_fecha_captura_utc]
            ,[arc_dispositivo], [arc_archivo_antivirus_estado]
            ,[arc_usuario_creacion], [arc_fecha_creacion]
            ,[arc_usuario_actualizacion], [arc_fecha_actualizacion]
            ,[arc_habilitado])
        VALUES
            (@UUID, @CLIENTE, @CATEGORIA
            ,@NOMBRE_ORIGINAL, @NOMBRE_ALMACENADO, @RUTA
            ,@MIME, @EXTENSION, @BYTE, @HASH
            ,@ANCHO, @ALTO
            ,@LATITUD, @LONGITUD, @CAPTURA_UTC
            ,@DISPOSITIVO, 1                            -- 1 = PENDIENTE antivirus
            ,@USUARIO, GETDATE()
            ,@USUARIO, GETDATE()
            ,1)

        SET @ARC = SCOPE_IDENTITY()

        /* El orden dentro del destino: se muestran en el orden en que se
           sacaron, y con captura sin senal el id no respeta ese orden. */
        DECLARE @ORDEN INT =
            (SELECT ISNULL(MAX([avi_orden]), 0) + 1
               FROM [dbo].[Archivo_Vinculo]
              WHERE (@DES = N'TAREA'     AND [avi_tarea_ejecucion] = @DESTINO_ID)
                 OR (@DES = N'ORDEN'     AND [avi_orden_trabajo] = @DESTINO_ID)
                 OR (@DES = N'PASO'      AND [avi_orden_trabajo_paso] = @DESTINO_ID)
                 OR (@DES = N'RESPUESTA' AND [avi_checklist_ejecucion_respuesta] = @DESTINO_ID)
                 OR (@DES = N'FALLA'     AND [avi_falla] = @DESTINO_ID)
                 OR (@DES = N'HALLAZGO'  AND [avi_checklist_hallazgo] = @DESTINO_ID)
                 OR (@DES = N'ACTIVO'    AND [avi_activo] = @DESTINO_ID))

        INSERT INTO [dbo].[Archivo_Vinculo]
            ([avi_archivo]
            ,[avi_tarea_ejecucion], [avi_orden_trabajo], [avi_orden_trabajo_paso]
            ,[avi_checklist_ejecucion_respuesta], [avi_falla]
            ,[avi_checklist_hallazgo], [avi_activo]
            ,[avi_es_referencia], [avi_orden], [avi_titulo], [avi_descripcion]
            ,[avi_usuario_creacion], [avi_fecha_creacion], [avi_habilitado])
        VALUES
            (@ARC
            ,CASE WHEN @DES = N'TAREA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ORDEN'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'PASO'      THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'RESPUESTA' THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'FALLA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'HALLAZGO'  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ACTIVO'    THEN @DESTINO_ID END
            /* Una foto de terreno nunca es «de referencia»: la referencia es
               como deberia verse el equipo, y esto es como se veia. */
            ,0, @ORDEN, @TITULO, @DESCRIPCION
            ,@USUARIO, GETDATE(), 1)

        COMMIT TRANSACTION
        SELECT @ARC AS [arc_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 2 - LEER LAS EVIDENCIAS DE ALGO
-- ---------------------------------------------------------------------------
--   Devuelve la ruta del blob, no los bytes. El telefono la pide despues por
--   `/archivo/ver` y la cachea; mandar las fotos dentro de la ficha haria que
--   abrir una tarea con seis fotos costara seis megas en terreno.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_EVIDENCIA]
     @USUARIO     INT
    ,@CLIENTE     INT
    ,@DESTINO     NVARCHAR(20)
    ,@DESTINO_ID  INT
AS
SET NOCOUNT ON

BEGIN

    DECLARE @DES NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@DESTINO, N''))))

    SELECT
         arc.[arc_id]
        ,arc.[arc_uuid]
        ,arc.[arc_ruta]
        ,arc.[arc_nombre_original]
        ,arc.[arc_mime]
        ,arc.[arc_byte]
        ,arc.[arc_ancho_pixel]
        ,arc.[arc_alto_pixel]
        ,arc.[arc_fecha_captura_utc]
        ,aca.[aca_codigo]              AS [CATEGORIA_CODIGO]
        ,aca.[aca_nombre]              AS [CATEGORIA_NOMBRE]
        ,avi.[avi_orden]
        ,avi.[avi_titulo]
        ,avi.[avi_descripcion]
        ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                       AS [USUARIO_NOMBRE]
        ,arc.[arc_fecha_creacion]

      FROM [dbo].[Archivo_Vinculo]      avi
      JOIN [dbo].[Archivo]              arc ON arc.[arc_id] = avi.[avi_archivo]
 LEFT JOIN [dbo].[Archivo_Categoria]    aca ON aca.[aca_id] = arc.[arc_archivo_categoria]
 LEFT JOIN [dbo].[Usuario]              usr ON usr.[usu_id] = arc.[arc_usuario_creacion]

     WHERE arc.[arc_cliente]    = @CLIENTE
       AND arc.[arc_habilitado] = 1
       AND avi.[avi_habilitado] = 1
       AND (   (@DES = N'TAREA'     AND avi.[avi_tarea_ejecucion] = @DESTINO_ID)
            OR (@DES = N'ORDEN'     AND avi.[avi_orden_trabajo] = @DESTINO_ID)
            OR (@DES = N'PASO'      AND avi.[avi_orden_trabajo_paso] = @DESTINO_ID)
            OR (@DES = N'RESPUESTA' AND avi.[avi_checklist_ejecucion_respuesta] = @DESTINO_ID)
            OR (@DES = N'FALLA'     AND avi.[avi_falla] = @DESTINO_ID)
            OR (@DES = N'HALLAZGO'  AND avi.[avi_checklist_hallazgo] = @DESTINO_ID)
            OR (@DES = N'ACTIVO'    AND avi.[avi_activo] = @DESTINO_ID))

     ORDER BY avi.[avi_orden], arc.[arc_id]

END
GO


-- ---------------------------------------------------------------------------
-- 3 - LA TAREA QUE EXIGE EVIDENCIA NO SE CIERRA SIN FOTO
-- ---------------------------------------------------------------------------
--   `tar_requiere_evidencia` estaba en la tabla y no lo miraba nadie: una
--   bandera que no se comprueba es peor que no tenerla, porque quien la marca
--   cree que sirve de algo.
--
--   Se comprueba en el SERVIDOR y no solo en la app: un telefono con la
--   version vieja cerraria sin foto en silencio.
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

        DECLARE @ESTADO INT, @EXIGE BIT

        SELECT @ESTADO = toc.[toc_tarea_ocurrencia_estado]
              ,@EXIGE  = tar.[tar_requiere_evidencia]
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

        /* ---- La ejecucion: por uuid, o la abierta de esta persona ---- */
        --  El uuid se busca ANTES de mirar el estado. Si no, un reintento de
        --  la cola -que reenvia el mismo cierre porque no alcanzo a ver la
        --  respuesta- se encuentra la tarea ya cerrada por el envio anterior y
        --  recibe un error por algo que si quedo grabado. El tecnico veria un
        --  fallo falso y volveria a llenar lo que ya estaba.
        DECLARE @TEJ INT

        SELECT @TEJ = [tej_id]
          FROM [dbo].[Tarea_Ejecucion]
         WHERE [tej_uuid] = @UUID

        IF @TEJ IS NULL AND @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta tarea ya esta cerrada.', 16, 1)
            RETURN
        END

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

            /* La foto se exige solo cuando la tarea SI se hizo. Si no se pudo
               hacer, no hay nada que fotografiar -y pedirla igual dejaria a la
               persona sin forma de cerrar algo que honestamente no ocurrio-. */
            IF @EXIGE = 1 AND ISNULL(@CONFORME, 1) = 1
               AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo]
                                WHERE [avi_tarea_ejecucion] = @TEJ
                                  AND [avi_habilitado] = 1)
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('Esta tarea pide una foto antes de cerrarla.', 16, 1)
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
-- 4 - LA FICHA TIENE QUE DECIR SI FALTA LA FOTO
-- ---------------------------------------------------------------------------
--   Sin esto la app no puede saber si ya hay evidencia y el boton «Listo»
--   mandaria un envio que va a rebotar. Rebotar esta bien como ultima defensa;
--   como unica defensa es hacerle perder el viaje a alguien que esta parado
--   frente a la maquina.
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

            /* Cuantas fotos lleva. La app lo necesita para saber si puede
               ofrecer «Listo» o si todavia falta la evidencia. */
            ,(SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av
               WHERE av.[avi_tarea_ejecucion] = tej.[tej_id]
                 AND av.[avi_habilitado] = 1)   AS [EVIDENCIAS]

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

END
GO
