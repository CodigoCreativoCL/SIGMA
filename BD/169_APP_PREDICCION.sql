USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LEER Y REVISAR LAS PREDICCIONES. HU-173 y HU-175.
-- =============================================
-- LOS SILENCIOS TAMBIEN SE CONSULTAN
--
--   La especificacion pide, en la misma pantalla, «predicciones vigentes» y
--   «equipos vigilados cuando no existan predicciones» y «aviso de datos
--   insuficientes y lecturas faltantes». O sea que **el vacio no es un estado
--   de error de la pantalla: es informacion**.
--
--   Un panel de SIGMA AI que no muestra nada puede significar tres cosas muy
--   distintas -no hay equipos vigilados, hay equipos pero nadie los mide, o se
--   miden y estan todos tranquilos- y la persona que lo mira necesita saber
--   cual de las tres es. Por eso el @TIPO 5 devuelve los equipos vigilados con
--   el motivo de su silencio, y no una lista vacia.
--
-- LO QUE SE MUESTRA SIEMPRE EN CONDICIONAL
--
--   Ningun texto de este bloque afirma que un equipo va a fallar. Afirma que
--   una variable medida va a cruzar un limite declarado si la tendencia se
--   mantiene, que es lo unico que el modelo puede sostener.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - LA SABANA
-- ---------------------------------------------------------------------------
--   @TIPO  1 = panel: predicciones vigentes, la mas urgente primero
--          2 = la ficha de una prediccion
--          3 = sus tres razones
--          4 = lo que se uso para calcularla
--          5 = equipos vigilados, con el motivo de su silencio
--          6 = la serie de la variable, para el grafico
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_PREDICCION]
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

    DECLARE @HOY DATETIME = GETUTCDATE()


    -- ------------------------------------------------------------ PANEL ----
    IF @TIPO = 1
    BEGIN
        SELECT
             pre.[pre_id]
            ,pre.[pre_uuid]
            ,pre.[pre_activo]                  AS [ACTIVO_ID]
            ,act.[act_codigo]                  AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                  AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                  AS [AREA_NOMBRE]
            ,cin.[cin_nombre]                  AS [INSTALACION_NOMBRE]

            /* La foto del equipo sale del vinculo de archivos, igual que en la
               ficha del activo: una sola forma de colgar imagenes. */
            ,(SELECT TOP 1 a.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] av
                JOIN [dbo].[Archivo]          a ON a.[arc_id] = av.[avi_archivo]
               WHERE av.[avi_activo] = act.[act_id]
                 AND av.[avi_habilitado] = 1 AND a.[arc_habilitado] = 1
               ORDER BY av.[avi_orden], a.[arc_id])
                                               AS [ACTIVO_FOTO]

            ,vme.[vme_nombre]                  AS [VARIABLE_NOMBRE]
            ,ume.[ume_simbolo]                 AS [UNIDAD]
            ,pre.[pre_valor]                   AS [VALOR_ACTUAL]
            ,ava.[ava_valor_critico]           AS [VALOR_CRITICO]
            ,ava.[ava_valor_advertencia]       AS [VALOR_ADVERTENCIA]

            ,pre.[pre_dia_restante]
            ,pre.[pre_fecha_evento_estimada_utc]
            ,pre.[pre_probabilidad]
            ,pre.[pre_confianza]
            ,pre.[pre_intervalo_inferior]      AS [DIA_MINIMO]
            ,pre.[pre_intervalo_superior]      AS [DIA_MAXIMO]
            ,pre.[pre_severidad]               AS [SEVERIDAD_ID]
            ,sev.[sev_codigo]                  AS [SEVERIDAD_CODIGO]
            ,sev.[sev_nombre]                  AS [SEVERIDAD_NOMBRE]

            ,pre.[pre_prediccion_estado]       AS [ESTADO_ID]
            ,pde.[pde_nombre]                  AS [ESTADO_NOMBRE]
            ,pre.[pre_fecha_calculo_utc]

            ,mpr.[mpr_nombre]                  AS [MODELO_NOMBRE]
            ,mpv.[mpv_numero]                  AS [MODELO_VERSION]

            ,pre.[pre_alerta]                  AS [ALERTA_ID]
            ,ale.[ale_orden_trabajo]           AS [ORDEN_TRABAJO_ID]
            ,otr.[otr_correlativo]             AS [ORDEN_CORRELATIVO]

          FROM [dbo].[Prediccion]                  pre
          JOIN [dbo].[Activo]                      act ON act.[act_id] = pre.[pre_activo]
          JOIN [dbo].[Modelo_Predictivo_Version]   mpv ON mpv.[mpv_id] = pre.[pre_modelo_predictivo_version]
          JOIN [dbo].[Modelo_Predictivo]           mpr ON mpr.[mpr_id] = mpv.[mpv_modelo_predictivo]
     LEFT JOIN [dbo].[Severidad]                   sev ON sev.[sev_id] = pre.[pre_severidad]
     LEFT JOIN [dbo].[Prediccion_Estado]           pde ON pde.[pde_id] = pre.[pre_prediccion_estado]
     LEFT JOIN [dbo].[Instalacion_Area]            iar ON iar.[iar_id] = act.[act_instalacion_area]
     LEFT JOIN [dbo].[Cliente_Instalacion]         cin ON cin.[cin_id] = act.[act_cliente_instalacion]
     LEFT JOIN [dbo].[Alerta]                      ale ON ale.[ale_id] = pre.[pre_alerta]
     LEFT JOIN [dbo].[Orden_Trabajo]               otr ON otr.[otr_id] = ale.[ale_orden_trabajo]

     /* La variable: se llega por el activo. Una prediccion mira una variable a
        la vez, y es la que dio origen a la explicacion de la pendiente. */
     LEFT JOIN [dbo].[Activo_Variable]             ava ON ava.[ava_activo] = pre.[pre_activo]
                                                     AND ava.[ava_habilitado] = 1
     LEFT JOIN [dbo].[Variable_Medicion]           vme ON vme.[vme_id] = ava.[ava_variable_medicion]
     LEFT JOIN [dbo].[Unidad_Medida]               ume ON ume.[ume_id] = ava.[ava_unidad_medida]

         WHERE pre.[pre_cliente]    = @CLIENTE
           AND pre.[pre_habilitado] = 1
           AND act.[act_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)

           /* Vigentes: ni vencidas ni descartadas. Una prediccion vieja
              colgada en la pantalla es peor que ninguna -se sigue mirando un
              numero que el modelo ya no sostiene-. */
           AND (pre.[pre_fecha_vigencia_hasta_utc] IS NULL
                OR pre.[pre_fecha_vigencia_hasta_utc] >= @HOY)
           AND pre.[pre_prediccion_estado] <> 4              -- 4 = DESCARTADA

         ORDER BY ISNULL(sev.[sev_orden], 0) DESC
                 ,pre.[pre_dia_restante]
                 ,pre.[pre_id]
    END


    -- ------------------------------------------------------------ FICHA ----
    IF @TIPO = 2
    BEGIN
        SELECT
             pre.[pre_id]
            ,pre.[pre_activo]                  AS [ACTIVO_ID]
            ,act.[act_codigo]                  AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                  AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                  AS [AREA_NOMBRE]
            ,cin.[cin_nombre]                  AS [INSTALACION_NOMBRE]
            ,(SELECT TOP 1 a.[arc_ruta]
                FROM [dbo].[Archivo_Vinculo] av
                JOIN [dbo].[Archivo]          a ON a.[arc_id] = av.[avi_archivo]
               WHERE av.[avi_activo] = act.[act_id]
                 AND av.[avi_habilitado] = 1 AND a.[arc_habilitado] = 1
               ORDER BY av.[avi_orden], a.[arc_id])
                                               AS [ACTIVO_FOTO]

            ,vme.[vme_nombre]                  AS [VARIABLE_NOMBRE]
            ,ume.[ume_simbolo]                 AS [UNIDAD]
            ,pre.[pre_valor]                   AS [VALOR_ACTUAL]
            ,ava.[ava_valor_advertencia]       AS [VALOR_ADVERTENCIA]
            ,ava.[ava_valor_critico]           AS [VALOR_CRITICO]

            ,pre.[pre_dia_restante]
            ,pre.[pre_fecha_evento_estimada_utc]
            ,pre.[pre_probabilidad]
            ,pre.[pre_confianza]
            ,pre.[pre_intervalo_inferior]      AS [DIA_MINIMO]
            ,pre.[pre_intervalo_superior]      AS [DIA_MAXIMO]
            ,pre.[pre_severidad]               AS [SEVERIDAD_ID]
            ,sev.[sev_codigo]                  AS [SEVERIDAD_CODIGO]
            ,sev.[sev_nombre]                  AS [SEVERIDAD_NOMBRE]
            ,pre.[pre_prediccion_estado]       AS [ESTADO_ID]
            ,pde.[pde_nombre]                  AS [ESTADO_NOMBRE]
            ,pre.[pre_motivo_descarte]
            ,pre.[pre_fecha_calculo_utc]
            ,pre.[pre_fecha_vigencia_hasta_utc]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [REVISADA_POR]
            ,pre.[pre_fecha_revision_utc]

            /* Modelo, version y como calcula: la especificacion los pide en la
               ficha, y con razon. Quien decide desarmar una maquina por esto
               tiene derecho a saber que lo dijo una regresion lineal y no un
               oraculo. */
            ,mpr.[mpr_nombre]                  AS [MODELO_NOMBRE]
            ,mpr.[mpr_descripcion]             AS [MODELO_DESCRIPCION]
            ,mpv.[mpv_numero]                  AS [MODELO_VERSION]
            ,mpv.[mpv_algoritmo]               AS [MODELO_ALGORITMO]
            ,mfo.[mfo_nombre]                  AS [MODELO_FORMATO]
            ,mob.[mob_nombre]                  AS [MODELO_OBJETIVO]
            ,mpr.[mpr_horizonte_dia]           AS [MODELO_HORIZONTE]

            ,pre.[pre_alerta]                  AS [ALERTA_ID]
            ,ale.[ale_orden_trabajo]           AS [ORDEN_TRABAJO_ID]
            ,otr.[otr_correlativo]             AS [ORDEN_CORRELATIVO]

            /* Cuantas fotos tiene el equipo: la ficha ofrece «evidencia
               relacionada» y sin esto no sabe si mostrar la seccion. */
            ,(SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av
               WHERE av.[avi_activo] = act.[act_id] AND av.[avi_habilitado] = 1)
                                               AS [EVIDENCIAS]

          FROM [dbo].[Prediccion]                  pre
          JOIN [dbo].[Activo]                      act ON act.[act_id] = pre.[pre_activo]
          JOIN [dbo].[Modelo_Predictivo_Version]   mpv ON mpv.[mpv_id] = pre.[pre_modelo_predictivo_version]
          JOIN [dbo].[Modelo_Predictivo]           mpr ON mpr.[mpr_id] = mpv.[mpv_modelo_predictivo]
     LEFT JOIN [dbo].[Modelo_Formato]              mfo ON mfo.[mfo_id] = mpv.[mpv_modelo_formato]
     LEFT JOIN [dbo].[Modelo_Objetivo]             mob ON mob.[mob_id] = mpr.[mpr_modelo_objetivo]
     LEFT JOIN [dbo].[Severidad]                   sev ON sev.[sev_id] = pre.[pre_severidad]
     LEFT JOIN [dbo].[Prediccion_Estado]           pde ON pde.[pde_id] = pre.[pre_prediccion_estado]
     LEFT JOIN [dbo].[Instalacion_Area]            iar ON iar.[iar_id] = act.[act_instalacion_area]
     LEFT JOIN [dbo].[Cliente_Instalacion]         cin ON cin.[cin_id] = act.[act_cliente_instalacion]
     LEFT JOIN [dbo].[Usuario]                     usr ON usr.[usu_id] = pre.[pre_usuario_revision]
     LEFT JOIN [dbo].[Alerta]                      ale ON ale.[ale_id] = pre.[pre_alerta]
     LEFT JOIN [dbo].[Orden_Trabajo]               otr ON otr.[otr_id] = ale.[ale_orden_trabajo]
     LEFT JOIN [dbo].[Activo_Variable]             ava ON ava.[ava_activo] = pre.[pre_activo]
                                                     AND ava.[ava_habilitado] = 1
     LEFT JOIN [dbo].[Variable_Medicion]           vme ON vme.[vme_id] = ava.[ava_variable_medicion]
     LEFT JOIN [dbo].[Unidad_Medida]               ume ON ume.[ume_id] = ava.[ava_unidad_medida]

         WHERE pre.[pre_id]      = @ID
           AND pre.[pre_cliente] = @CLIENTE
    END


    -- ---------------------------------------------------------- RAZONES ----
    IF @TIPO = 3
    BEGIN
        SELECT
             pex.[pex_orden]
            ,pex.[pex_texto]
            ,pex.[pex_direccion]
            ,pex.[pex_valor_observado]
            ,pex.[pex_valor_referencia]
            ,cmo.[cmo_etiqueta]                AS [CARACTERISTICA]
          FROM [dbo].[Prediccion_Explicacion]  pex
          JOIN [dbo].[Prediccion]              pre ON pre.[pre_id] = pex.[pex_prediccion]
     LEFT JOIN [dbo].[Caracteristica_Modelo]   cmo ON cmo.[cmo_id] = pex.[pex_caracteristica_modelo]
         WHERE pex.[pex_prediccion] = @ID
           AND pre.[pre_cliente]    = @CLIENTE
         ORDER BY pex.[pex_orden], pex.[pex_id]
    END


    -- ------------------------------------------------------ DATOS USADOS ----
    IF @TIPO = 4
    BEGIN
        SELECT
             cmo.[cmo_codigo]
            ,cmo.[cmo_etiqueta]
            ,cmo.[cmo_descripcion]
            ,pcr.[pcr_valor]
            ,pcr.[pcr_valor_texto]
            ,pcr.[pcr_imputado]
          FROM [dbo].[Prediccion_Caracteristica] pcr
          JOIN [dbo].[Prediccion]                pre ON pre.[pre_id] = pcr.[pcr_prediccion]
          JOIN [dbo].[Caracteristica_Modelo]     cmo ON cmo.[cmo_id] = pcr.[pcr_caracteristica_modelo]
         WHERE pcr.[pcr_prediccion] = @ID
           AND pre.[pre_cliente]    = @CLIENTE
         ORDER BY ISNULL(cmo.[cmo_orden], 999)
    END


    -- ------------------------------------------------- EQUIPOS VIGILADOS ----
    --  El silencio con su motivo. Sin esto un panel vacio no se distingue de
    --  un panel roto.
    IF @TIPO = 5
    BEGIN
        DECLARE @MINIMO INT = 4, @VENTANA INT = 120

        SELECT
             ava.[ava_id]
            ,act.[act_id]                      AS [ACTIVO_ID]
            ,act.[act_codigo]                  AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                  AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                  AS [AREA_NOMBRE]
            ,vme.[vme_nombre]                  AS [VARIABLE_NOMBRE]
            ,ume.[ume_simbolo]                 AS [UNIDAD]
            ,ava.[ava_valor_advertencia]       AS [VALOR_ADVERTENCIA]
            ,ava.[ava_valor_critico]           AS [VALOR_CRITICO]
            ,ava.[ava_frecuencia_esperada_hora] AS [CADA_HORAS]
            ,l.[LECTURAS]
            ,l.[ULTIMA_UTC]
            ,l.[ULTIMO_VALOR]

            /* Horas desde la ultima lectura. La especificacion pide avisar de
               «lecturas faltantes» y esto es lo que lo permite: un equipo que
               se deberia medir cada 24 horas y lleva 90 sin medirse no esta
               vigilado, esta abandonado. */
            ,CASE WHEN l.[ULTIMA_UTC] IS NULL THEN NULL
                  ELSE DATEDIFF(HOUR, l.[ULTIMA_UTC], @HOY) END
                                               AS [HORAS_SIN_LECTURA]

            ,CAST(CASE WHEN ava.[ava_frecuencia_esperada_hora] IS NOT NULL
                        AND l.[ULTIMA_UTC] IS NOT NULL
                        AND DATEDIFF(HOUR, l.[ULTIMA_UTC], @HOY) > ava.[ava_frecuencia_esperada_hora]
                       THEN 1 ELSE 0 END AS BIT)
                                               AS [ATRASADA]

            /* El motivo del silencio, en tres estados honestos. No se
               distingue «plano» de «sin patron» de «cruza mas alla del
               horizonte» porque para saberlo habria que reejecutar la
               regresion aca, y una segunda copia de esa formula terminaria
               discrepando con la del generador. */
            ,CASE
                WHEN l.[LECTURAS] IS NULL OR l.[LECTURAS] = 0 THEN N'SIN LECTURAS'
                WHEN l.[LECTURAS] < @MINIMO                   THEN N'FALTAN LECTURAS'
                ELSE N'SIN SENALES'
             END                               AS [MOTIVO]

          FROM [dbo].[Activo_Variable]         ava
          JOIN [dbo].[Activo]                  act ON act.[act_id] = ava.[ava_activo]
          JOIN [dbo].[Variable_Medicion]       vme ON vme.[vme_id] = ava.[ava_variable_medicion]
     LEFT JOIN [dbo].[Unidad_Medida]           ume ON ume.[ume_id] = ava.[ava_unidad_medida]
     LEFT JOIN [dbo].[Instalacion_Area]        iar ON iar.[iar_id] = act.[act_instalacion_area]

     OUTER APPLY (SELECT [LECTURAS]     = COUNT(*)
                        ,[ULTIMA_UTC]   = MAX(amd.[amd_fecha_medicion_utc])
                        ,[ULTIMO_VALOR] = MAX(CASE WHEN amd.[amd_fecha_medicion_utc] =
                                                        (SELECT MAX(x.[amd_fecha_medicion_utc])
                                                           FROM [dbo].[Activo_Medicion] x
                                                          WHERE x.[amd_activo_variable] = ava.[ava_id])
                                                   THEN amd.[amd_valor_canonico] END)
                    FROM [dbo].[Activo_Medicion] amd
                   WHERE amd.[amd_activo_variable]  = ava.[ava_id]
                     AND amd.[amd_medicion_calidad] = 1
                     AND amd.[amd_fecha_medicion_utc] >= DATEADD(DAY, -@VENTANA, @HOY)) l

         WHERE ava.[ava_cliente]    = @CLIENTE
           AND ava.[ava_habilitado] = 1
           AND act.[act_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)

           /* Solo los que NO tienen prediccion vigente: los que si la tienen ya
              salieron en el @TIPO 1 y repetirlos aca seria contarlos dos
              veces en la misma pantalla. */
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion] p
                            WHERE p.[pre_activo]    = act.[act_id]
                              AND p.[pre_cliente]   = @CLIENTE
                              AND p.[pre_habilitado] = 1
                              AND p.[pre_prediccion_estado] <> 4
                              AND (p.[pre_fecha_vigencia_hasta_utc] IS NULL
                                   OR p.[pre_fecha_vigencia_hasta_utc] >= @HOY))

         ORDER BY CASE WHEN ISNULL(l.[LECTURAS], 0) = 0 THEN 0
                       WHEN l.[LECTURAS] < @MINIMO      THEN 1
                       ELSE 2 END
                 ,act.[act_codigo]
    END


    -- ------------------------------------------------------------ SERIE ----
    --  Las lecturas de la variable de esta prediccion, para el grafico. La
    --  especificacion lo pide como «variable determinante y grafico»: sin la
    --  serie, las razones son afirmaciones que hay que creer.
    IF @TIPO = 6
    BEGIN
        SELECT
             amd.[amd_fecha_medicion_utc]      AS [FECHA]
            ,amd.[amd_valor_canonico]          AS [VALOR]
          FROM [dbo].[Prediccion]         pre
          JOIN [dbo].[Activo_Variable]    ava ON ava.[ava_activo] = pre.[pre_activo]
                                             AND ava.[ava_habilitado] = 1
          JOIN [dbo].[Activo_Medicion]    amd ON amd.[amd_activo_variable] = ava.[ava_id]
         WHERE pre.[pre_id]      = @ID
           AND pre.[pre_cliente] = @CLIENTE
           AND amd.[amd_medicion_calidad] = 1
           AND amd.[amd_fecha_medicion_utc] >= DATEADD(DAY, -120, @HOY)
         ORDER BY amd.[amd_fecha_medicion_utc]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 2 - RECONOCER O DESCARTAR
-- ---------------------------------------------------------------------------
--   Descartar **exige motivo**. Una prediccion descartada sin explicacion no
--   se puede aprender: cuando alguien revise si el modelo sirve, necesita
--   saber si se descarto porque era un falso positivo, porque el equipo ya se
--   iba a cambiar, o porque nadie le creyo. Las tres cosas llevan a decisiones
--   distintas sobre el modelo.
--
--   Y el motivo es lo unico que hoy sostiene a `Modelo_Monitoreo`: los falsos
--   positivos que ahi se cuentan salen de aca.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_PREDICCION_REVISION]
     @ID        INT
    ,@USUARIO   INT
    ,@CLIENTE   INT
    ,@ACEPTAR   BIT
    ,@MOTIVO    NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @ALERTA INT

        SELECT @ESTADO = pre.[pre_prediccion_estado]
              ,@ALERTA = pre.[pre_alerta]
          FROM [dbo].[Prediccion] pre
          JOIN [dbo].[Activo]     act ON act.[act_id] = pre.[pre_activo]
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = act.[act_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE pre.[pre_id]         = @ID
           AND pre.[pre_cliente]    = @CLIENTE
           AND pre.[pre_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La prediccion no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* Ya materializada: salio una orden de trabajo de ella y revisarla
           ahora no cambiaria nada. */
        IF @ESTADO = 5
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta prediccion ya se convirtio en una orden de trabajo.', 16, 1)
            RETURN
        END

        IF @ACEPTAR = 0 AND LTRIM(RTRIM(ISNULL(@MOTIVO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Para descartar una prediccion hay que decir por que.', 16, 1)
            RETURN
        END

        /* Ya revisada con el mismo veredicto: la cola reintentando. */
        IF (@ACEPTAR = 1 AND @ESTADO = 3) OR (@ACEPTAR = 0 AND @ESTADO = 4)
        BEGIN
            COMMIT TRANSACTION
            SELECT @ID AS [pre_id], 1 AS [YA_ESTABA]
            RETURN
        END

        UPDATE [dbo].[Prediccion]
           SET [pre_prediccion_estado]    = CASE WHEN @ACEPTAR = 1 THEN 3 ELSE 4 END
              ,[pre_usuario_revision]     = @USUARIO
              ,[pre_fecha_revision_utc]   = GETUTCDATE()
              ,[pre_motivo_descarte]      = CASE WHEN @ACEPTAR = 0 THEN @MOTIVO END
              ,[pre_usuario_actualizacion] = @USUARIO
              ,[pre_fecha_actualizacion]  = GETDATE()
         WHERE [pre_id] = @ID

        /* La alerta sigue a la prediccion. Se reusa el SP de estado en vez de
           escribir las columnas a mano: es el que sabe cuales mueve y el que
           deja el rastro en Alerta_Historial. */
        IF @ALERTA IS NOT NULL
            EXEC [dbo].[UPD_ALERTA_ESTADO]
                 @ALERTA      = @ALERTA
                ,@CLIENTE     = @CLIENTE
                ,@USUARIO     = @USUARIO
                ,@ESTADO      = CASE WHEN @ACEPTAR = 1 THEN 'RECONOCIDA' ELSE 'DESCARTADA' END
                ,@MOTIVO      = @MOTIVO
                ,@RESPONSABLE = NULL

        COMMIT TRANSACTION
        SELECT @ID AS [pre_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 3 - EL PERMISO DE VER
-- ---------------------------------------------------------------------------
--   `GENERAR OT PREDICCION` ya existia (id 96) pero no habia ninguno para
--   **mirar** el analisis: quedaba el absurdo de poder generar una orden desde
--   una prediccion que no se tenia derecho a ver.
-- ---------------------------------------------------------------------------
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('VER PREDICCIONES', 'Ver el analisis de SIGMA AI',
       'MANTENIMIENTO', 2,
       'Permite ver las predicciones vigentes, sus razones y los equipos vigilados, y reconocer o descartar una prediccion.')
) AS O (codigo, nombre, modulo, ambito, descripcion)
   ON D.prm_codigo = O.codigo

WHEN NOT MATCHED THEN
    INSERT (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
            prm_descripcion, prm_usuario_creacion, prm_fecha_creacion)
    VALUES (O.codigo, O.nombre, O.modulo, O.ambito,
            O.descripcion, @ROOT, @AHORA)

WHEN MATCHED THEN
    UPDATE SET  D.prm_nombre      = O.nombre
               ,D.prm_descripcion = O.descripcion;
GO


/* Lo ve quien puede hacer algo con la informacion: los tres de planta y el
   planificador, que es quien reprograma cuando el analisis dice que un equipo
   no llega al proximo mantenimiento. */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

DECLARE @ASIGNAR TABLE ([perfil] NVARCHAR(120))
INSERT INTO @ASIGNAR VALUES
     ('Tecnico de Mantenimiento'), ('Técnico de Mantenimiento')
    ,('Supervisor de Mantenimiento'), ('Jefe de Mantenimiento')
    ,('Planificador de Mantenimiento')

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    @ASIGNAR              A
JOIN    [dbo].[Perfiles] PER ON PER.per_nombre COLLATE DATABASE_DEFAULT = A.[perfil]
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo = 'VER PREDICCIONES'
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permiso VER PREDICCIONES asignado.'
GO
