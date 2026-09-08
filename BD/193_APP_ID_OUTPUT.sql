USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     @ID OUTPUT EN LOS OCHO SP QUE NO LO DECLARABAN.
-- =============================================
-- NUEVE ENDPOINTS RESPONDIAN 400 Y NO HACIAN NADA
--
--   Datos.Ejecutar(sp, params, devuelveId: true) agrega un parametro que NO
--   esta en el diccionario:
--
--       cmd.Parameters.Add("@ID", SqlDbType.Int).Direction = Output
--
--   Si el SP no lo declara, SQL Server responde "@ID is not a parameter for
--   procedure X" -o "has too many arguments specified"- y ErrorSql lo traduce
--   a un 400 con ese texto tecnico. La pantalla muestra el error y la accion
--   no se hace.
--
--   Caian: crear una OT correctiva, registrar mi tiempo, sumar un compañero,
--   sumarme a un trabajo compartido, escribir / comentar / rectificar en la
--   bitacora, subir cualquier evidencia, empezar una pauta y comentar una
--   tarea.
--
-- EL QUE INCUMPLE ES EL SP, NO EL CONTROLLER
--
--   PATRON_SP.md linea 139: "@ID INT = NULL OUTPUT siempre primero, para
--   devolver el id generado con SCOPE_IDENTITY(). El Controller lo lee como
--   ParameterDirection.Output". El arreglo es agregar el parametro, no quitar
--   el devuelveId.
--
-- POR QUE NINGUNA AUDITORIA LO VEIA
--
--   auditar_sp.py cruza los parametros del Dictionary contra sys.parameters, y
--   @ID no esta en el diccionario: lo agrega Datos.Ejecutar. Compilaba,
--   flutter analyze pasaba, las tres auditorias salian limpias, y el endpoint
--   respondia 400. Solo se ve llamandolo. Por eso nace auditar_id_output.py.
--
-- EL SELECT DE SALIDA SE CONSERVA
--
--   Cada SP seguia devolviendo su id por resultset -SELECT @X AS [xxx_id]-, y
--   eso lo leen los que llaman sin devolveId. Se conserva tal cual y ademas se
--   asigna @ID: los dos caminos dan el mismo numero. En los cortes por
--   idempotencia tambien, que es donde mas importa: un reintento tiene que
--   devolver el id que ya existia, no cero.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
--   Idempotente por `bit_uuid`, generado en el telefono al empezar a escribir.
--   Si se generara al enviar, un reintento de la cola dejaria el turno contado
--   dos veces -y en una bitacora eso no es un duplicado molesto, es un relato
--   que se contradice-.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA]
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
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
            SET @ID = @YA
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
        SET @ID = @BIT
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
--   Igual que en las tareas: append-only, con hilo por `bco_comentario_padre`
--   y sin uuid propio, asi que la proteccion contra el reenvio es el contenido
--   dentro de una ventana corta.
--
--   Comentar es lo que puede hacer un tercero. Rectificar, no: agregar es de
--   cualquiera, corregir el relato es de quien lo escribio.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_COMENTARIO]
     @ID INT = NULL OUTPUT
    ,@BITACORA          INT
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
            SET @ID = @YA
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
        SET @ID = @BCO
        SELECT @BCO AS [bco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

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
     @ID INT = NULL OUTPUT
    ,@BITACORA  INT
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
        SET @ID = @BRE
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
--   Idempotente por uuid. Y ademas: si esta persona ya tiene un BORRADOR de
--   esta ocurrencia, se devuelve ese en vez de crear otro. Una pauta a medias
--   que se abandona y se rehace pierde lo caminado, y en terreno eso significa
--   volver a recorrer la planta.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_CHECKLIST_EJECUCION]
     @ID INT = NULL OUTPUT
    ,@UUID          UNIQUEIDENTIFIER
    ,@USUARIO       INT
    ,@CLIENTE       INT
    ,@OCURRENCIA    INT            = NULL
    ,@VERSION       INT            = NULL
    ,@ACTIVO        INT            = NULL
    ,@DISPOSITIVO   NVARCHAR(200)  = NULL
    ,@OFFLINE       BIT            = 0
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @YA INT

        SELECT @YA = [cej_id]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_uuid]    = @UUID
           AND [cej_cliente] = @CLIENTE

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [cej_id], 1 AS [YA_EXISTIA]
            RETURN
        END

        /* Un borrador previo de la misma ocurrencia se retoma. */
        IF @OCURRENCIA IS NOT NULL
        BEGIN
            SELECT TOP 1 @YA = [cej_id]
              FROM [dbo].[Checklist_Ejecucion]
             WHERE [cej_checklist_ocurrencia]       = @OCURRENCIA
               AND [cej_usuario_ejecutor]           = @USUARIO
               AND [cej_checklist_ejecucion_estado] = 1
               AND [cej_habilitado]                 = 1
             ORDER BY [cej_id] DESC

            IF @YA IS NOT NULL
            BEGIN
                COMMIT TRANSACTION
                SET @ID = @YA
                SELECT @YA AS [cej_id], 1 AS [YA_EXISTIA]
                RETURN
            END
        END

        /* La version: de la ocurrencia si viene, del parametro si no. */
        DECLARE @VER INT = @VERSION

        IF @VER IS NULL AND @OCURRENCIA IS NOT NULL
            SELECT @VER = [coc_checklist_plantilla_version]
                  ,@ACTIVO = ISNULL(@ACTIVO, [coc_activo])
              FROM [dbo].[Checklist_Ocurrencia]
             WHERE [coc_id]      = @OCURRENCIA
               AND [coc_cliente] = @CLIENTE

        IF @VER IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No se indico que pauta ejecutar.', 16, 1)
            RETURN
        END

        /* Solo se ejecutan versiones PUBLICADAS. Una en borrador todavia se
           esta escribiendo, y una retirada dejo de ser la norma: llenarla
           produciria un registro que nadie puede defender en una auditoria. */
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version]
                        WHERE [cpv_id] = @VER
                          AND [cpv_checklist_version_estado] = 2
                          AND [cpv_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esa version de la pauta no esta publicada.', 16, 1)
            RETURN
        END

        DECLARE @TOTAL INT =
            (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item]
              WHERE [cpi_checklist_plantilla_version] = @VER
                AND [cpi_habilitado] = 1)

        INSERT INTO [dbo].[Checklist_Ejecucion]
            ([cej_uuid], [cej_cliente], [cej_checklist_ocurrencia]
            ,[cej_checklist_plantilla_version], [cej_activo]
            ,[cej_usuario_ejecutor], [cej_checklist_ejecucion_estado]
            ,[cej_fecha_inicio_utc], [cej_dispositivo], [cej_offline_creado]
            ,[cej_item_total], [cej_item_respondido], [cej_item_no_conforme]
            ,[cej_usuario_creacion], [cej_fecha_creacion], [cej_habilitado])
        VALUES
            (@UUID, @CLIENTE, @OCURRENCIA
            ,@VER, @ACTIVO
            ,@USUARIO, 1                        -- 1 BORRADOR
            ,GETUTCDATE(), @DISPOSITIVO, @OFFLINE
            ,@TOTAL, 0, 0
            ,@USUARIO, GETDATE(), 1)

        DECLARE @CEJ INT = SCOPE_IDENTITY()

        /* La ocurrencia pasa a EN EJECUCION para que no aparezca dos veces en
           la bandeja de otro. */
        IF @OCURRENCIA IS NOT NULL
            UPDATE [dbo].[Checklist_Ocurrencia]
               SET [coc_checklist_ocurrencia_estado] = 3
                  ,[coc_usuario_actualizacion]       = @USUARIO
                  ,[coc_fecha_actualizacion]         = GETDATE()
             WHERE [coc_id] = @OCURRENCIA
               AND [coc_checklist_ocurrencia_estado] IN (1, 2)

        COMMIT TRANSACTION
        SET @ID = @CEJ
        SELECT @CEJ AS [cej_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

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
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
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
            SET @ID = @ARC
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
        SET @ID = @ARC
        SELECT @ARC AS [arc_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

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
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
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
            SET @ID = @YA
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

        SET @ID = @OTR_ID
        SELECT @OTR_ID AS [otr_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

--   El tecnico registra su propio tramo: entro a las 08:10, salio a las 10:00.
--   Los minutos se calculan aca y no llegan del telefono -un aparato con el
--   reloj corrido reportaria tramos de doce horas- salvo que se manden
--   explicitos, para el caso de registrar a mano un trabajo de ayer.
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

-- ---------------------------------------------------------------------------
--   El dictado se crea **dentro de la misma transaccion** que el comentario y
--   no en una llamada aparte. Un comentario y su dictado son un solo acto: si
--   fueran dos envios, la cola podria dejar uno sin el otro y quedaria o un
--   comentario que miente sobre como se escribio, o un dictado huerfano que no
--   se puede leer desde ninguna parte.
--
--   `@TEXTO` es lo que la persona dio por bueno; `@TEXTO_DICTADO` es lo que
--   entendio el telefono. Cuando no se corrigio nada son iguales, y esta bien
--   que lo sean: lo que importa es poder ver cuando **no** lo fueron.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_TAREA_COMENTARIO]
     @ID INT = NULL OUTPUT
    ,@OCURRENCIA        INT
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@PADRE             INT              = NULL
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DICTADO_INTENTOS  INT              = 1
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
            SET @ID = @YA
            SELECT @YA AS [tco_id], 1 AS [YA_ESTABA]
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
                ,@INTENTOS    = @DICTADO_INTENTOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Tarea_Comentario]
            ([tco_tarea_ocurrencia], [tco_comentario_padre], [tco_texto]
            ,[tco_dictado_voz], [tco_usuario_creacion], [tco_fecha_creacion])
        VALUES
            (@OCURRENCIA, @PADRE, @TEXTO
            ,@DVO, @USUARIO, GETDATE())

        DECLARE @TCO INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SET @ID = @TCO
        SELECT @TCO AS [tco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

