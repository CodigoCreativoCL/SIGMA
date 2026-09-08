USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     EL DICTADO POR VOZ COMO REGISTRO, NO COMO FLAG.
-- =============================================
-- LO QUE ME EQUIVOQUE Y LO QUE ENSENA LA TABLA
--
--   El bloque 159 escribio `tco_dictado_voz = 2` creyendo que era una marca de
--   «esto se dicto». No lo es: es una **FK a Dictado_Voz**, y la base la
--   rechazo. La correccion no es cambiar el valor, es entender que el modelo
--   pide otra cosa.
--
--   `Dictado_Voz` la usan seis lugares -orden de trabajo, falla, bitacora,
--   comentario de bitacora, respuesta de checklist y comentario de tarea-. Que
--   sea una tabla compartida y no una columna en cada una significa que el
--   dictado es un hecho por si mismo: quien hablo, cuando, con que motor, en
--   que idioma, cuanto duro, cuantos intentos hizo falta, que confianza
--   devolvio el reconocedor y **que texto salio antes de que la persona lo
--   corrigiera**.
--
--   Esa ultima es la que importa. `dvo_texto` guarda la transcripcion cruda y
--   el comentario guarda lo que la persona dio por bueno. Si fueran el mismo
--   campo no habria forma de saber nunca si el reconocedor sirve en una sala
--   de maquinas -que es exactamente lo que hay que saber antes de apostar la
--   captura en terreno a la voz-.
--
-- EL AUDIO NO SE GUARDA
--
--   `dvo_archivo` queda en NULL siempre. Se graba lo que se transcribio, no la
--   voz: guardar audio de la gente trabajando es una carga de privacidad que
--   no hace falta para nada de lo que el sistema tiene que hacer. La columna
--   existe por si algun dia hay motivo; hoy no lo hay.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - REGISTRAR UN DICTADO
-- ---------------------------------------------------------------------------
--   Idempotente por `dvo_uuid`, generado en el telefono al terminar de
--   dictar. Si el envio se reintenta, devuelve el mismo id en vez de un
--   segundo dictado de la misma frase.
--
--   Nace en PROCESADO (3) y no en PENDIENTE: el reconocimiento ya ocurrio en
--   el telefono antes de llamar. PENDIENTE queda para el dia que exista un
--   motor en la nube que reciba audio y responda despues.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_DICTADO_VOZ]
     @UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@IDIOMA            NVARCHAR(20)   = N'es-CL'
    ,@MOTOR             INT            = 1        -- 1 = en el telefono
    ,@MODELO            NVARCHAR(200)  = NULL
    ,@CONFIANZA         DECIMAL(5,4)   = NULL
    ,@SEGUNDOS          INT            = NULL
    ,@INTENTOS          INT            = 1
    ,@CONFIRMADO        BIT            = 1
    ,@CONFIRMADO_VOZ    BIT            = 0
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
    ,@ID                INT            = NULL OUTPUT
AS
SET NOCOUNT ON

BEGIN

    SELECT @ID = [dvo_id] FROM [dbo].[Dictado_Voz] WHERE [dvo_uuid] = @UUID

    IF @ID IS NOT NULL
        RETURN

    DECLARE @IDI INT =
        (SELECT TOP 1 [idi_id] FROM [dbo].[Idioma]
          WHERE [idi_codigo] = @IDIOMA AND [idi_habilitado] = 1)

    /* Un codigo de idioma que el telefono reporte y aca no exista no puede
       botar el comentario: el dictado se guarda igual, en el idioma por
       omision, porque el texto vale mas que la etiqueta. */
    IF @IDI IS NULL
        SET @IDI = (SELECT TOP 1 [idi_id] FROM [dbo].[Idioma]
                     WHERE [idi_codigo] = N'es-CL')

    INSERT INTO [dbo].[Dictado_Voz]
        ([dvo_uuid], [dvo_cliente], [dvo_usuario], [dvo_fecha_utc]
        ,[dvo_archivo], [dvo_voz_motor], [dvo_modelo_version], [dvo_idioma]
        ,[dvo_texto], [dvo_confianza], [dvo_duracion_segundo], [dvo_intentos]
        ,[dvo_confirmado], [dvo_confirmado_por_voz], [dvo_fecha_confirmacion_utc]
        ,[dvo_dispositivo_uuid], [dvo_proceso_estado]
        ,[dvo_usuario_creacion], [dvo_fecha_creacion])
    VALUES
        (@UUID, @CLIENTE, @USUARIO, GETUTCDATE()
        ,NULL, @MOTOR, @MODELO, @IDI                       -- el audio no se guarda
        ,@TEXTO, @CONFIANZA, @SEGUNDOS, ISNULL(@INTENTOS, 1)
        ,@CONFIRMADO, @CONFIRMADO_VOZ
        ,CASE WHEN @CONFIRMADO = 1 THEN GETUTCDATE() END
        ,@DISPOSITIVO, 3
        ,@USUARIO, GETDATE())

    SET @ID = SCOPE_IDENTITY()

END
GO


-- ---------------------------------------------------------------------------
-- 2 - COMENTAR, CORRIGIENDO EL DICTADO DEL BLOQUE 159
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
     @OCURRENCIA        INT
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
        SELECT @TCO AS [tco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 3 - EL HILO, AHORA CON LO QUE SE DICTO
-- ---------------------------------------------------------------------------
--   @TIPO = 3 vuelve a declararse entero para que el @TIPO 1 y 2 del bloque
--   159 sigan tal cual; solo cambia la lectura del dictado.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_TAREA_COMENTARIO]
     @USUARIO  INT
    ,@CLIENTE  INT
    ,@ID       INT
AS
SET NOCOUNT ON

BEGIN

    SELECT
         tco.[tco_id]
        ,tco.[tco_comentario_padre]        AS [PADRE_ID]
        ,tco.[tco_texto]
        ,CAST(CASE WHEN tco.[tco_dictado_voz] IS NULL THEN 0 ELSE 1 END AS BIT)
                                           AS [POR_VOZ]
        ,dvo.[dvo_texto]                   AS [TEXTO_DICTADO]
        ,dvo.[dvo_confianza]               AS [DICTADO_CONFIANZA]

        /* Corregido = el texto final no es el que salio del reconocedor. Se
           calcula aca y no se guarda: es una comparacion, no un hecho nuevo. */
        ,CAST(CASE WHEN dvo.[dvo_id] IS NOT NULL AND dvo.[dvo_texto] <> tco.[tco_texto]
                   THEN 1 ELSE 0 END AS BIT)
                                           AS [DICTADO_CORREGIDO]

        ,tco.[tco_usuario_creacion]        AS [USUARIO_ID]
        ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                           AS [USUARIO_NOMBRE]
        ,tco.[tco_fecha_creacion]

      FROM [dbo].[Tarea_Comentario]  tco
      JOIN [dbo].[Tarea_Ocurrencia]  toc ON toc.[toc_id] = tco.[tco_tarea_ocurrencia]
 LEFT JOIN [dbo].[Usuario]           usr ON usr.[usu_id] = tco.[tco_usuario_creacion]
 LEFT JOIN [dbo].[Dictado_Voz]       dvo ON dvo.[dvo_id] = tco.[tco_dictado_voz]

     WHERE tco.[tco_tarea_ocurrencia] = @ID
       AND toc.[toc_cliente]          = @CLIENTE

     ORDER BY tco.[tco_fecha_creacion], tco.[tco_id]

END
GO
