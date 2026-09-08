USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LA BITACORA DE PLANTA. HU-130 y HU-131, Sprint 5.
-- =============================================
-- LO QUE SE ESCRIBIO NO SE REESCRIBE
--
--   `Bitacora` no tiene `habilitado` ni auditoria de actualizacion. No es un
--   olvido: es la decision del modelo. Una bitacora es el relato de lo que
--   paso en el turno, y un relato que se puede editar despues deja de servir
--   como relato -sobre todo el dia que alguien tenga que explicar por que se
--   quemo un motor-.
--
--   Por eso este bloque tiene INS y no tiene UPD ni DEL. Corregir se hace
--   escribiendo, no borrando.
--
-- LA RECTIFICACION ES OTRA FILA, Y EXIGE MOTIVO
--
--   `Bitacora_Rectificacion` es una tabla aparte con `bre_motivo` NOT NULL.
--   La entrada original queda intacta en `bit_texto` y la pantalla la muestra
--   siempre; encima aparece la version corregida con el motivo del cambio.
--
--   La especificacion pide exactamente eso -«rectificacion con motivo
--   obligatorio, registro original siempre visible»- y el modelo ya lo tenia
--   resuelto. Lo unico que faltaba eran los procedimientos.
--
--   Se pueden encadenar: una entrada puede rectificarse dos veces y las dos
--   quedan. Vale la ultima, se ven todas.
--
-- SE ESCRIBE SIN SENAL
--
--   `bit_uuid`, `bit_offline_creado` y `bit_fecha_sincronizacion_utc` estaban
--   pensados para eso. La entrada se escribe en la sala de maquinas y sube
--   cuando hay red; idempotente por uuid, para que un reintento de la cola no
--   deje el turno contado dos veces.
--
-- EL DICTADO ES EL MISMO DE SIEMPRE
--
--   `bit_dictado_voz` y `bco_dictado_voz` son FK a `Dictado_Voz`, igual que en
--   las tareas. Se reusa `API_INS_DICTADO_VOZ` del bloque 160: la transcripcion
--   cruda se guarda junto al texto que la persona dio por bueno.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - LA SABANA
-- ---------------------------------------------------------------------------
--   @TIPO  1 = la linea de tiempo
--          2 = una entrada
--          3 = sus comentarios
--          4 = sus rectificaciones
--          5 = los tipos de entrada
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_BITACORA]
     @USUARIO      INT
    ,@CLIENTE      INT
    ,@TIPO         INT = 1
    ,@ID           INT = NULL
    ,@INSTALACION  INT = NULL
    ,@ACTIVO       INT = NULL
    ,@AREA         INT = NULL
    ,@DESDE        DATETIME = NULL
    ,@SOLO_ATENCION BIT = 0
    ,@PAGINA       INT = 1
    ,@TAMANO       INT = 30
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


    -- ------------------------------------------------- LINEA DE TIEMPO ----
    IF @TIPO = 1
    BEGIN
        IF @PAGINA < 1 SET @PAGINA = 1
        IF @TAMANO < 1 OR @TAMANO > 100 SET @TAMANO = 30

        SELECT
             bit.[bit_id]
            ,bit.[bit_uuid]
            ,bit.[bit_titulo]
            ,bit.[bit_texto]
            ,bit.[bit_fecha_evento_utc]
            ,bit.[bit_turno]
            ,bit.[bit_requiere_atencion]
            ,bit.[bit_offline_creado]
            ,bit.[bit_bitacora_tipo]           AS [TIPO_ID]
            ,bti.[bti_codigo]                  AS [TIPO_CODIGO]
            ,bti.[bti_nombre]                  AS [TIPO_NOMBRE]
            ,bit.[bit_severidad]               AS [SEVERIDAD_ID]
            ,sev.[sev_codigo]                  AS [SEVERIDAD_CODIGO]
            ,sev.[sev_nombre]                  AS [SEVERIDAD_NOMBRE]
            ,bit.[bit_activo]                  AS [ACTIVO_ID]
            ,act.[act_codigo]                  AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                  AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                  AS [AREA_NOMBRE]
            ,cin.[cin_nombre]                  AS [INSTALACION_NOMBRE]
            ,bit.[bit_orden_trabajo]           AS [ORDEN_TRABAJO_ID]
            ,otr.[otr_correlativo]             AS [ORDEN_CORRELATIVO]
            ,bit.[bit_usuario_creacion]        AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [USUARIO_NOMBRE]
            ,bit.[bit_fecha_creacion]

            ,CAST(CASE WHEN bit.[bit_dictado_voz] IS NULL THEN 0 ELSE 1 END AS BIT)
                                               AS [POR_VOZ]

            ,(SELECT COUNT(*) FROM [dbo].[Bitacora_Comentario] c
               WHERE c.[bco_bitacora] = bit.[bit_id])
                                               AS [COMENTARIOS]

            /* Cuantas veces se rectifico. La pantalla lo necesita para
               mostrar «corregida» sin tener que pedir la lista completa. */
            ,(SELECT COUNT(*) FROM [dbo].[Bitacora_Rectificacion] r
               WHERE r.[bre_bitacora] = bit.[bit_id])
                                               AS [RECTIFICACIONES]

            /* El texto que vale hoy: la ultima rectificacion si la hubo, y si
               no el original. El original NO se pisa -sigue en `bit_texto`- y
               la ficha muestra los dos. */
            ,ISNULL((SELECT TOP 1 r.[bre_texto_rectificado]
                       FROM [dbo].[Bitacora_Rectificacion] r
                      WHERE r.[bre_bitacora] = bit.[bit_id]
                      ORDER BY r.[bre_id] DESC), bit.[bit_texto])
                                               AS [TEXTO_VIGENTE]

            ,(SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av
               WHERE av.[avi_bitacora] = bit.[bit_id]
                 AND av.[avi_habilitado] = 1)  AS [EVIDENCIAS]

            ,COUNT(*) OVER ()                  AS [TOTAL]

          FROM [dbo].[Bitacora]                bit
          JOIN [dbo].[Bitacora_Tipo]           bti ON bti.[bti_id] = bit.[bit_bitacora_tipo]
     LEFT JOIN [dbo].[Severidad]               sev ON sev.[sev_id] = bit.[bit_severidad]
     LEFT JOIN [dbo].[Activo]                  act ON act.[act_id] = bit.[bit_activo]
     LEFT JOIN [dbo].[Instalacion_Area]        iar ON iar.[iar_id] = bit.[bit_instalacion_area]
     LEFT JOIN [dbo].[Cliente_Instalacion]     cin ON cin.[cin_id] = bit.[bit_cliente_instalacion]
     LEFT JOIN [dbo].[Orden_Trabajo]           otr ON otr.[otr_id] = bit.[bit_orden_trabajo]
     LEFT JOIN [dbo].[Usuario]                 usr ON usr.[usu_id] = bit.[bit_usuario_creacion]

         WHERE bit.[bit_cliente] = @CLIENTE
           AND bit.[bit_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
           AND (@ACTIVO IS NULL OR bit.[bit_activo] = @ACTIVO)
           AND (@AREA   IS NULL OR bit.[bit_instalacion_area] = @AREA)
           AND (@DESDE  IS NULL OR bit.[bit_fecha_evento_utc] >= @DESDE)
           AND (@SOLO_ATENCION = 0 OR bit.[bit_requiere_atencion] = 1)

         /* Por fecha del EVENTO y no de creacion: una entrada escrita sin
            senal a las tres de la manana y subida a las nueve pertenece a la
            noche, no a la manana. */
         ORDER BY bit.[bit_fecha_evento_utc] DESC, bit.[bit_id] DESC
         OFFSET (@PAGINA - 1) * @TAMANO ROWS
         FETCH NEXT @TAMANO ROWS ONLY
    END


    -- ------------------------------------------------------------ FICHA ----
    IF @TIPO = 2
    BEGIN
        SELECT
             bit.[bit_id]
            ,bit.[bit_uuid]
            ,bit.[bit_titulo]
            ,bit.[bit_texto]                   AS [TEXTO_ORIGINAL]
            ,ISNULL((SELECT TOP 1 r.[bre_texto_rectificado]
                       FROM [dbo].[Bitacora_Rectificacion] r
                      WHERE r.[bre_bitacora] = bit.[bit_id]
                      ORDER BY r.[bre_id] DESC), bit.[bit_texto])
                                               AS [TEXTO_VIGENTE]
            ,bit.[bit_fecha_evento_utc]
            ,bit.[bit_turno]
            ,bit.[bit_requiere_atencion]
            ,bit.[bit_offline_creado]
            ,bit.[bit_fecha_sincronizacion_utc]
            ,bit.[bit_bitacora_tipo]           AS [TIPO_ID]
            ,bti.[bti_codigo]                  AS [TIPO_CODIGO]
            ,bti.[bti_nombre]                  AS [TIPO_NOMBRE]
            ,bit.[bit_severidad]               AS [SEVERIDAD_ID]
            ,sev.[sev_nombre]                  AS [SEVERIDAD_NOMBRE]
            ,bit.[bit_activo]                  AS [ACTIVO_ID]
            ,act.[act_codigo]                  AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                  AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                  AS [AREA_NOMBRE]
            ,cin.[cin_nombre]                  AS [INSTALACION_NOMBRE]
            ,bit.[bit_orden_trabajo]           AS [ORDEN_TRABAJO_ID]
            ,otr.[otr_correlativo]             AS [ORDEN_CORRELATIVO]
            ,bit.[bit_alerta]                  AS [ALERTA_ID]
            ,bit.[bit_usuario_creacion]        AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [USUARIO_NOMBRE]
            ,bit.[bit_fecha_creacion]

            /* Lo dictado y lo confirmado, como en los comentarios de tarea.
               Comparar los dos es lo unico que despues dice si dictar sirve en
               una sala de maquinas. */
            ,CAST(CASE WHEN bit.[bit_dictado_voz] IS NULL THEN 0 ELSE 1 END AS BIT)
                                               AS [POR_VOZ]
            ,dvo.[dvo_texto]                   AS [TEXTO_DICTADO]
            ,dvo.[dvo_confianza]               AS [DICTADO_CONFIANZA]
            ,CAST(CASE WHEN dvo.[dvo_id] IS NOT NULL AND dvo.[dvo_texto] <> bit.[bit_texto]
                       THEN 1 ELSE 0 END AS BIT)
                                               AS [DICTADO_CORREGIDO]

            ,(SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av
               WHERE av.[avi_bitacora] = bit.[bit_id]
                 AND av.[avi_habilitado] = 1)  AS [EVIDENCIAS]

          FROM [dbo].[Bitacora]                bit
          JOIN [dbo].[Bitacora_Tipo]           bti ON bti.[bti_id] = bit.[bit_bitacora_tipo]
     LEFT JOIN [dbo].[Severidad]               sev ON sev.[sev_id] = bit.[bit_severidad]
     LEFT JOIN [dbo].[Activo]                  act ON act.[act_id] = bit.[bit_activo]
     LEFT JOIN [dbo].[Instalacion_Area]        iar ON iar.[iar_id] = bit.[bit_instalacion_area]
     LEFT JOIN [dbo].[Cliente_Instalacion]     cin ON cin.[cin_id] = bit.[bit_cliente_instalacion]
     LEFT JOIN [dbo].[Orden_Trabajo]           otr ON otr.[otr_id] = bit.[bit_orden_trabajo]
     LEFT JOIN [dbo].[Usuario]                 usr ON usr.[usu_id] = bit.[bit_usuario_creacion]
     LEFT JOIN [dbo].[Dictado_Voz]             dvo ON dvo.[dvo_id] = bit.[bit_dictado_voz]

         WHERE bit.[bit_id]      = @ID
           AND bit.[bit_cliente] = @CLIENTE
    END


    -- ------------------------------------------------------ COMENTARIOS ----
    IF @TIPO = 3
    BEGIN
        SELECT
             bco.[bco_id]
            ,bco.[bco_comentario_padre]        AS [PADRE_ID]
            ,bco.[bco_texto]
            ,CAST(CASE WHEN bco.[bco_dictado_voz] IS NULL THEN 0 ELSE 1 END AS BIT)
                                               AS [POR_VOZ]
            ,dvo.[dvo_texto]                   AS [TEXTO_DICTADO]
            ,CAST(CASE WHEN dvo.[dvo_id] IS NOT NULL AND dvo.[dvo_texto] <> bco.[bco_texto]
                       THEN 1 ELSE 0 END AS BIT)
                                               AS [DICTADO_CORREGIDO]
            ,bco.[bco_usuario_creacion]        AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [USUARIO_NOMBRE]
            ,bco.[bco_fecha_creacion]

          FROM [dbo].[Bitacora_Comentario] bco
          JOIN [dbo].[Bitacora]            bit ON bit.[bit_id] = bco.[bco_bitacora]
     LEFT JOIN [dbo].[Usuario]             usr ON usr.[usu_id] = bco.[bco_usuario_creacion]
     LEFT JOIN [dbo].[Dictado_Voz]         dvo ON dvo.[dvo_id] = bco.[bco_dictado_voz]

         WHERE bco.[bco_bitacora] = @ID
           AND bit.[bit_cliente]  = @CLIENTE

         ORDER BY bco.[bco_fecha_creacion], bco.[bco_id]
    END


    -- --------------------------------------------------- RECTIFICACIONES ----
    --  De la mas vieja a la mas nueva: se lee como lo que es, la historia de
    --  las correcciones. El original va aparte, en la ficha.
    IF @TIPO = 4
    BEGIN
        SELECT
             bre.[bre_id]
            ,bre.[bre_texto_rectificado]
            ,bre.[bre_motivo]
            ,bre.[bre_usuario_creacion]        AS [USUARIO_ID]
            ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                               AS [USUARIO_NOMBRE]
            ,bre.[bre_fecha_creacion]

          FROM [dbo].[Bitacora_Rectificacion] bre
          JOIN [dbo].[Bitacora]              bit ON bit.[bit_id] = bre.[bre_bitacora]
     LEFT JOIN [dbo].[Usuario]               usr ON usr.[usu_id] = bre.[bre_usuario_creacion]

         WHERE bre.[bre_bitacora] = @ID
           AND bit.[bit_cliente]  = @CLIENTE

         ORDER BY bre.[bre_id]
    END


    -- ------------------------------------------------------------ TIPOS ----
    IF @TIPO = 5
    BEGIN
        SELECT [bti_id], [bti_codigo], [bti_nombre], [bti_icono], [bti_orden]
          FROM [dbo].[Bitacora_Tipo]
         WHERE [bti_habilitado] = 1
         ORDER BY [bti_orden], [bti_id]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 2 - ESCRIBIR UNA ENTRADA (HU-130)
-- ---------------------------------------------------------------------------
--   Idempotente por `bit_uuid`, generado en el telefono al empezar a escribir.
--   Si se generara al enviar, un reintento de la cola dejaria el turno contado
--   dos veces -y en una bitacora eso no es un duplicado molesto, es un relato
--   que se contradice-.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA]
     @UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@INSTALACION       INT
    ,@TIPO              INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@TITULO            NVARCHAR(400)    = NULL
    ,@AREA              INT              = NULL
    ,@ACTIVO            INT              = NULL
    ,@COMPONENTE        INT              = NULL
    ,@ORDEN_TRABAJO     INT              = NULL
    ,@FECHA_EVENTO      DATETIME         = NULL
    ,@TURNO             NVARCHAR(40)     = NULL
    ,@REQUIERE_ATENCION BIT              = 0
    ,@SEVERIDAD         INT              = NULL
    ,@LATITUD           DECIMAL(9,6)     = NULL
    ,@LONGITUD          DECIMAL(9,6)     = NULL
    ,@OFFLINE           BIT              = 0
    ,@ENTRADA_MODO      INT              = 1        -- 1 = TECLADO
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        /* ---- Reenvio de la cola ---- */
        DECLARE @YA INT
        SELECT @YA = [bit_id] FROM [dbo].[Bitacora] WHERE [bit_uuid] = @UUID

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SELECT @YA AS [bit_id], 1 AS [YA_ESTABA]
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada esta vacia.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE [ciu_id_instalacion] = @INSTALACION
                          AND [ciu_id_usuario]     = @USUARIO
                          AND ISNULL([ciu_habilitado], 0) = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No estas afiliado a esa planta.', 16, 1)
            RETURN
        END

        /* Un incidente sin severidad no se puede priorizar despues, y la
           bitacora sirve justamente para eso: que el turno siguiente sepa que
           mirar primero. */
        IF @TIPO = 3 AND @SEVERIDAD IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Un incidente necesita su severidad.', 16, 1)
            RETURN
        END

        /* ---- El dictado, si lo hubo ---- */
        DECLARE @DVO INT = NULL

        IF @DICTADO_UUID IS NOT NULL
            EXEC [dbo].[API_INS_DICTADO_VOZ]
                 @UUID        = @DICTADO_UUID
                ,@USUARIO     = @USUARIO
                ,@CLIENTE     = @CLIENTE
                ,@TEXTO       = @TEXTO_DICTADO      -- lo crudo, no lo corregido
                ,@CONFIANZA   = @DICTADO_CONFIANZA
                ,@SEGUNDOS    = @DICTADO_SEGUNDOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Bitacora]
            ([bit_uuid], [bit_cliente], [bit_cliente_instalacion]
            ,[bit_instalacion_area], [bit_bitacora_tipo]
            ,[bit_activo], [bit_activo_componente], [bit_orden_trabajo]
            ,[bit_titulo], [bit_texto], [bit_fecha_evento_utc], [bit_turno]
            ,[bit_requiere_atencion], [bit_severidad]
            ,[bit_dictado_voz], [bit_entrada_modo]
            ,[bit_latitud], [bit_longitud]
            ,[bit_offline_creado], [bit_fecha_sincronizacion_utc]
            ,[bit_usuario_creacion], [bit_fecha_creacion])
        VALUES
            (@UUID, @CLIENTE, @INSTALACION
            ,@AREA, @TIPO
            ,@ACTIVO, @COMPONENTE, @ORDEN_TRABAJO
            ,@TITULO, @TEXTO, ISNULL(@FECHA_EVENTO, GETUTCDATE()), @TURNO
            ,@REQUIERE_ATENCION, @SEVERIDAD
            ,@DVO, CASE WHEN @DVO IS NOT NULL THEN 2 ELSE @ENTRADA_MODO END
            ,@LATITUD, @LONGITUD
            ,@OFFLINE, GETUTCDATE()
            ,@USUARIO, GETDATE())

        DECLARE @BIT INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @BIT AS [bit_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 3 - RECTIFICAR (HU-131)
-- ---------------------------------------------------------------------------
--   No es un UPDATE. La entrada original queda intacta y esto agrega una fila
--   con el texto corregido y **el motivo, que es obligatorio**.
--
--   Sin motivo la rectificacion no vale nada: quien lea la bitacora despues
--   necesita saber si el texto cambio porque el primero estaba mal escrito,
--   porque se supo algo nuevo, o porque a alguien no le gusto como sonaba. Las
--   tres cosas se leen muy distinto.
--
--   Solo puede rectificar quien escribio. Que un tercero corrija el relato de
--   otro convierte la bitacora en un documento sin autor.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_RECTIFICACION]
     @BITACORA  INT
    ,@USUARIO   INT
    ,@CLIENTE   INT
    ,@TEXTO     NVARCHAR(MAX)
    ,@MOTIVO    NVARCHAR(1000)
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @AUTOR INT, @ORIGINAL NVARCHAR(MAX)

        SELECT @AUTOR = bit.[bit_usuario_creacion]
              ,@ORIGINAL = bit.[bit_texto]
          FROM [dbo].[Bitacora] bit
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = bit.[bit_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE bit.[bit_id]      = @BITACORA
           AND bit.[bit_cliente] = @CLIENTE

        IF @AUTOR IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @AUTOR <> @USUARIO
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Solo quien escribio la entrada puede rectificarla. Si hay algo que agregar, comenta.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto rectificado esta vacio.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@MOTIVO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Para rectificar hay que decir por que.', 16, 1)
            RETURN
        END

        /* El texto vigente: el ultimo rectificado, o el original si es la
           primera correccion. Rectificar dejandolo igual no aporta nada y
           ensucia la historia. */
        DECLARE @VIGENTE NVARCHAR(MAX) =
            ISNULL((SELECT TOP 1 [bre_texto_rectificado]
                      FROM [dbo].[Bitacora_Rectificacion]
                     WHERE [bre_bitacora] = @BITACORA
                     ORDER BY [bre_id] DESC), @ORIGINAL)

        IF @TEXTO = @VIGENTE
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto es el mismo que ya estaba.', 16, 1)
            RETURN
        END

        INSERT INTO [dbo].[Bitacora_Rectificacion]
            ([bre_bitacora], [bre_texto_rectificado], [bre_motivo]
            ,[bre_usuario_creacion], [bre_fecha_creacion])
        VALUES
            (@BITACORA, @TEXTO, @MOTIVO, @USUARIO, GETDATE())

        DECLARE @BRE INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @BRE AS [bre_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 4 - COMENTAR UNA ENTRADA
-- ---------------------------------------------------------------------------
--   Igual que en las tareas: append-only, con hilo por `bco_comentario_padre`
--   y sin uuid propio, asi que la proteccion contra el reenvio es el contenido
--   dentro de una ventana corta.
--
--   Comentar es lo que puede hacer un tercero. Rectificar, no: agregar es de
--   cualquiera, corregir el relato es de quien lo escribio.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_COMENTARIO]
     @BITACORA          INT
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@PADRE             INT              = NULL
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
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
                         FROM [dbo].[Bitacora] bit
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = bit.[bit_cliente_instalacion]
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE bit.[bit_id]      = @BITACORA
                          AND bit.[bit_cliente] = @CLIENTE)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @PADRE IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Comentario]
                            WHERE [bco_id] = @PADRE
                              AND [bco_bitacora] = @BITACORA)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario al que respondes no es de esta entrada.', 16, 1)
            RETURN
        END

        DECLARE @YA INT

        SELECT TOP 1 @YA = [bco_id]
          FROM [dbo].[Bitacora_Comentario]
         WHERE [bco_bitacora]        = @BITACORA
           AND [bco_usuario_creacion] = @USUARIO
           AND [bco_texto]            = @TEXTO
           AND [bco_fecha_creacion]  >= DATEADD(MINUTE, -5, GETDATE())
         ORDER BY [bco_id] DESC

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SELECT @YA AS [bco_id], 1 AS [YA_ESTABA]
            RETURN
        END

        DECLARE @DVO INT = NULL

        IF @DICTADO_UUID IS NOT NULL
            EXEC [dbo].[API_INS_DICTADO_VOZ]
                 @UUID        = @DICTADO_UUID
                ,@USUARIO     = @USUARIO
                ,@CLIENTE     = @CLIENTE
                ,@TEXTO       = @TEXTO_DICTADO
                ,@CONFIANZA   = @DICTADO_CONFIANZA
                ,@SEGUNDOS    = @DICTADO_SEGUNDOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Bitacora_Comentario]
            ([bco_bitacora], [bco_comentario_padre], [bco_texto]
            ,[bco_dictado_voz], [bco_usuario_creacion], [bco_fecha_creacion])
        VALUES
            (@BITACORA, @PADRE, @TEXTO, @DVO, @USUARIO, GETDATE())

        DECLARE @BCO INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @BCO AS [bco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO
