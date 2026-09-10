USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LAS TAREAS CERRADAS, NO SOLO LAS PENDIENTES.
-- =============================================
-- Bryan: «debo poder ver mis tareas completadas y las pendientes».
--
-- `API_SEL_TAREA` solo devolvia los estados 1, 2 y 3, asi que una tarea
-- desaparecia de la app en cuanto se cerraba: no habia forma de comprobar que
-- se registro, ni de mirar que se le hizo a una maquina la semana pasada.
--
-- Se agrega `@CERRADAS` en vez de un bloque nuevo: un @TIPO aparte serian
-- noventa lineas identicas salvo una del WHERE, y dos copias de eso terminan
-- mostrando cosas distintas.
--
-- El valor por defecto es 0, que es exactamente lo que hacia antes: quien ya
-- llama a este SP -incluido el bloque 10 de la sabana- no se entera.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 4 - LA FICHA TIENE QUE DECIR SI FALTA LA FOTO
-- ---------------------------------------------------------------------------
--   Sin esto la app no puede saber si ya hay evidencia y el boton ���Listo���
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

/* QUE TAREAS: LAS ABIERTAS O LAS YA CERRADAS

   0 -por omision- son las de siempre: pendiente, aceptada y en ejecucion. Es
   lo que la bandeja pedia y por eso el valor por defecto conserva el
   comportamiento de antes sin tocar a quien ya llama a este SP.

   1 son las CERRADAS: completada y no realizada. No cancelada ni
   reprogramada, que no son trabajo de nadie -una cancelada no la hizo el
   tecnico, se la quitaron-.

   POR QUE UN PARAMETRO Y NO UN @TIPO NUEVO
     Un bloque aparte serian noventa lineas identicas salvo una linea del
     WHERE: la foto del activo, la estrella, la linea de montaje, la situacion
     y el conteo de comentarios. Dos copias de eso es garantizar que un dia la
     lista de cerradas muestre algo distinto de la de abiertas. */
    ,@CERRADAS     BIT = 0
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
               porque es TOP 1 �?"la imagen de referencia�?" no una relacion. */
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
            /* La estrella. Un tecnico vuelve una y otra vez a las mismas tres
               de veinte, y hoy las busca desplazando la lista cada vez.

               Va como EXISTS y no como JOIN: un JOIN a una tabla donde la
               persona puede no tener ninguna fila obliga a un LEFT y a
               acordarse del NULL en cada uso. */
            ,CAST(CASE WHEN EXISTS (
                SELECT 1 FROM [dbo].[Usuario_Favorito] ufv
                 WHERE ufv.[ufv_usuario] = @USUARIO
                   AND ufv.[ufv_tarea_ocurrencia] = toc.[toc_id]) THEN 1 ELSE 0 END AS BIT)
                                                   AS [ES_FAVORITO]

            /* La LINEA donde esta montado el equipo. En una planta, ��Linea 3��
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
           AND (   (@CERRADAS = 0 AND toc.[toc_tarea_ocurrencia_estado] IN (1, 2, 3))
                OR (@CERRADAS = 1 AND toc.[toc_tarea_ocurrencia_estado] IN (4, 5)))
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

         /* LO ABIERTO SE ORDENA POR URGENCIA; LO CERRADO, POR RECIENTE

            En la bandeja lo vencido va primero porque es lo que hay que hacer
            ahora. En el historial esa pregunta ya no existe: lo que se busca
            es «que hice hoy» y «que se hizo con esta maquina la semana pasada»,
            asi que manda la fecha, de lo mas nuevo a lo mas viejo. */
         ORDER BY
              CASE WHEN @CERRADAS = 1 THEN 1 ELSE
                   CASE WHEN toc.[toc_fecha_limite_utc] < GETUTCDATE() THEN 0 ELSE 1 END
              END
             ,CASE WHEN @CERRADAS = 1 THEN 0 ELSE ISNULL(tpa.[tpa_orden], 0) END DESC
             ,CASE WHEN @CERRADAS = 1
                   THEN NULL ELSE toc.[toc_fecha_limite_utc] END
             ,CASE WHEN @CERRADAS = 1 THEN toc.[toc_id] END DESC
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
               porque es TOP 1 �?"la imagen de referencia�?" no una relacion. */
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
            /* La estrella. Un tecnico vuelve una y otra vez a las mismas tres
               de veinte, y hoy las busca desplazando la lista cada vez.

               Va como EXISTS y no como JOIN: un JOIN a una tabla donde la
               persona puede no tener ninguna fila obliga a un LEFT y a
               acordarse del NULL en cada uso. */
            ,CAST(CASE WHEN EXISTS (
                SELECT 1 FROM [dbo].[Usuario_Favorito] ufv
                 WHERE ufv.[ufv_usuario] = @USUARIO
                   AND ufv.[ufv_tarea_ocurrencia] = toc.[toc_id]) THEN 1 ELSE 0 END AS BIT)
                                                   AS [ES_FAVORITO]

            /* La LINEA donde esta montado el equipo. En una planta, ��Linea 3��
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
               ofrecer ���Listo��� o si todavia falta la evidencia. */
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
