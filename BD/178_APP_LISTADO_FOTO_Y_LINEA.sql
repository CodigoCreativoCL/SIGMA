USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     FOTO Y LINEA DEL ACTIVO EN LOS LISTADOS DE TERRENO.
-- =============================================
-- POR QUE
--
--   La bandeja de «Mis trabajos» mostraba un icono generico donde va el
--   equipo. En terreno eso obliga a abrir la orden para saber de que maquina
--   se trata, y la foto es lo que hace que se reconozca de un vistazo.
--
--   Se agregan dos columnas a los DOS bloques de cada SP —el listado y la
--   ficha—, porque una tarjeta que cambia de aspecto al abrirla se lee como
--   si fueran dos cosas distintas:
--
--     ACTIVO_FOTO      la RUTA del blob de la imagen de referencia
--     POSICION_CODIGO  la linea donde esta montado el equipo
--
--   Van como SUBCONSULTA y no como JOIN: no se toca el FROM de un SP que ya
--   funciona, y son TOP 1 —una imagen de referencia, una posicion—, no una
--   relacion que multiplique filas.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
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
    SELECT cin.[cin_id]
      FROM [dbo].[Cliente_Instalacion]         cin
      JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
             ON  ciu.[ciu_id_instalacion] = cin.[cin_id]
             AND ciu.[ciu_id_usuario]     = @USUARIO
             AND ISNULL(ciu.[ciu_habilitado], 0) = 1
     WHERE cin.[cin_cliente]    = @CLIENTE
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
            /* La foto del activo, por su RUTA de blob: la app la pide a
               `GET /archivo/ver?ruta=` y la cachea. Va como subconsulta y no
               como JOIN para no tocar el FROM de un SP que ya funciona, y
               porque es TOP 1 —la imagen de referencia— no una relacion. */
            ,(SELECT TOP 1 arc.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] avi
                JOIN [dbo].[Archivo]         arc ON arc.[arc_id] = avi.[avi_archivo]
               WHERE avi.[avi_activo]       = act.[act_id]
                 AND avi.[avi_es_referencia] = 1
                 AND avi.[avi_habilitado]    = 1
                 AND arc.[arc_habilitado]    = 1
                 AND arc.[arc_mime] LIKE 'image/%%'
               ORDER BY ISNULL(avi.[avi_orden], 0), arc.[arc_id] DESC)
                                                   AS [ACTIVO_FOTO]

            /* La LINEA donde esta montado el equipo. En una planta, «Linea 3»
               identifica el trabajo mas rapido que el nombre del activo:
               puede haber cinco motores iguales y solo uno esta en la 3. */
            ,(SELECT apo.[apo_codigo]
                FROM [dbo].[Activo_Posicion] apo
               WHERE apo.[apo_id] = act.[act_activo_posicion])
                                                   AS [POSICION_CODIGO]
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
            /* La foto del activo, por su RUTA de blob: la app la pide a
               `GET /archivo/ver?ruta=` y la cachea. Va como subconsulta y no
               como JOIN para no tocar el FROM de un SP que ya funciona, y
               porque es TOP 1 —la imagen de referencia— no una relacion. */
            ,(SELECT TOP 1 arc.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] avi
                JOIN [dbo].[Archivo]         arc ON arc.[arc_id] = avi.[avi_archivo]
               WHERE avi.[avi_activo]       = act.[act_id]
                 AND avi.[avi_es_referencia] = 1
                 AND avi.[avi_habilitado]    = 1
                 AND arc.[arc_habilitado]    = 1
                 AND arc.[arc_mime] LIKE 'image/%%'
               ORDER BY ISNULL(avi.[avi_orden], 0), arc.[arc_id] DESC)
                                                   AS [ACTIVO_FOTO]

            /* La LINEA donde esta montado el equipo. En una planta, «Linea 3»
               identifica el trabajo mas rapido que el nombre del activo:
               puede haber cinco motores iguales y solo uno esta en la 3. */
            ,(SELECT apo.[apo_codigo]
                FROM [dbo].[Activo_Posicion] apo
               WHERE apo.[apo_id] = act.[act_activo_posicion])
                                                   AS [POSICION_CODIGO]
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
-- 4 - LA FICHA TIENE QUE DECIR SI FALTA LA FOTO
-- ---------------------------------------------------------------------------
--   Sin esto la app no puede saber si ya hay evidencia y el boton �Listo�
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
            /* La foto del activo, por su RUTA de blob: la app la pide a
               `GET /archivo/ver?ruta=` y la cachea. Va como subconsulta y no
               como JOIN para no tocar el FROM de un SP que ya funciona, y
               porque es TOP 1 —la imagen de referencia— no una relacion. */
            ,(SELECT TOP 1 arc.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] avi
                JOIN [dbo].[Archivo]         arc ON arc.[arc_id] = avi.[avi_archivo]
               WHERE avi.[avi_activo]       = act.[act_id]
                 AND avi.[avi_es_referencia] = 1
                 AND avi.[avi_habilitado]    = 1
                 AND arc.[arc_habilitado]    = 1
                 AND arc.[arc_mime] LIKE 'image/%%'
               ORDER BY ISNULL(avi.[avi_orden], 0), arc.[arc_id] DESC)
                                                   AS [ACTIVO_FOTO]

            /* La LINEA donde esta montado el equipo. En una planta, «Linea 3»
               identifica el trabajo mas rapido que el nombre del activo:
               puede haber cinco motores iguales y solo uno esta en la 3. */
            ,(SELECT apo.[apo_codigo]
                FROM [dbo].[Activo_Posicion] apo
               WHERE apo.[apo_id] = act.[act_activo_posicion])
                                                   AS [POSICION_CODIGO]
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
            /* La foto del activo, por su RUTA de blob: la app la pide a
               `GET /archivo/ver?ruta=` y la cachea. Va como subconsulta y no
               como JOIN para no tocar el FROM de un SP que ya funciona, y
               porque es TOP 1 —la imagen de referencia— no una relacion. */
            ,(SELECT TOP 1 arc.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] avi
                JOIN [dbo].[Archivo]         arc ON arc.[arc_id] = avi.[avi_archivo]
               WHERE avi.[avi_activo]       = act.[act_id]
                 AND avi.[avi_es_referencia] = 1
                 AND avi.[avi_habilitado]    = 1
                 AND arc.[arc_habilitado]    = 1
                 AND arc.[arc_mime] LIKE 'image/%%'
               ORDER BY ISNULL(avi.[avi_orden], 0), arc.[arc_id] DESC)
                                                   AS [ACTIVO_FOTO]

            /* La LINEA donde esta montado el equipo. En una planta, «Linea 3»
               identifica el trabajo mas rapido que el nombre del activo:
               puede haber cinco motores iguales y solo uno esta en la 3. */
            ,(SELECT apo.[apo_codigo]
                FROM [dbo].[Activo_Posicion] apo
               WHERE apo.[apo_id] = act.[act_activo_posicion])
                                                   AS [POSICION_CODIGO]
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
               ofrecer �Listo� o si todavia falta la evidencia. */
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
