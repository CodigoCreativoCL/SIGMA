USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     EJECUTAR UN CHECKLIST EN TERRENO (HU-095, Sprint 4).
-- =============================================
-- EL MODELO YA ESTABA, Y ESTA BIEN PENSADO PARA TERRENO
--
--   Checklist_Ejecucion trae `cej_uuid`, `cej_offline_creado` y
--   `cej_fecha_sincronizacion_utc`; la respuesta trae `cer_entrada_modo` -para
--   distinguir lo dictado de lo tecleado- y `cer_valor_canonico` con su
--   unidad. Todo eso existe porque la pauta se llena SIN SENAL y se envia
--   despues. Este bloque se limita a respetarlo.
--
-- LA VALIDACION VIVE EN LA PLANTILLA, NO EN LA PANTALLA
--
--   Checklist_Item_Validacion dice el rango esperado, si genera hallazgo y que
--   mensaje mostrar. El SP lo evalua al grabar la respuesta y marca
--   `cer_fuera_rango`. Si lo evaluara la app, una version vieja del telefono
--   aceptaria en silencio lo que la planta ya considera fuera de norma.
--
-- FUERA DE RANGO NO IMPIDE RESPONDER
--
--   Es justo lo contrario: un valor fuera de rango ES el hallazgo, y bloquear
--   su captura obligaria al tecnico a anotarlo en papel. Se graba, se marca y
--   -si la plantilla lo pide- se abre el hallazgo.
--
-- IDEMPOTENTE EN LOS DOS NIVELES
--
--   La ejecucion por `cej_uuid`; la respuesta, por (ejecucion, item): volver a
--   responder el mismo item lo ACTUALIZA en vez de duplicarlo. Es lo que hace
--   que reenviar una pauta de treinta items desde la cola sea seguro.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - LA SABANA DEL CHECKLIST
-- ---------------------------------------------------------------------------
--   @TIPO  1 = pendientes de esta persona (ocurrencias por hacer)
--          2 = la plantilla: secciones e items de una version
--          3 = una ejecucion con sus respuestas
--          4 = opciones y validaciones de los items de una version
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_CHECKLIST]
     @USUARIO      INT
    ,@CLIENTE      INT
    ,@TIPO         INT = 1
    ,@ID           INT = NULL      -- ocurrencia, version o ejecucion segun @TIPO
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
             coc.[coc_id]
            ,coc.[coc_uuid]
            ,coc.[coc_checklist_plantilla_version]   AS [VERSION_ID]
            ,cpl.[cpl_codigo]                        AS [PLANTILLA_CODIGO]
            ,cpl.[cpl_nombre]                        AS [PLANTILLA_NOMBRE]
            ,cpl.[cpl_descripcion]                   AS [PLANTILLA_DESCRIPCION]
            ,cpv.[cpv_numero]                        AS [VERSION_NUMERO]
            ,coc.[coc_activo]                        AS [ACTIVO_ID]
            ,act.[act_codigo]                        AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                        AS [ACTIVO_NOMBRE]
            ,iar.[iar_nombre]                        AS [AREA_NOMBRE]
            ,coc.[coc_checklist_ocurrencia_estado]   AS [ESTADO_ID]
            ,coe.[coe_nombre]                        AS [ESTADO_NOMBRE]
            ,coc.[coc_fecha_programada_utc]
            ,coc.[coc_fecha_limite_utc]

            /* La situacion la decide el SP: si la calculara la app, dos
               telefonos con distinta hora dirian cosas distintas de la misma
               pauta. */
            ,CASE
                WHEN coc.[coc_fecha_limite_utc] IS NULL THEN N'SIN PLAZO'
                WHEN coc.[coc_fecha_limite_utc] < GETUTCDATE() THEN N'VENCIDA'
                WHEN CAST(coc.[coc_fecha_limite_utc] AS DATE) = CAST(GETUTCDATE() AS DATE)
                     THEN N'VENCE HOY'
                ELSE N'EN PLAZO'
             END                                     AS [SITUACION]

            ,(SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i
               WHERE i.[cpi_checklist_plantilla_version] = coc.[coc_checklist_plantilla_version]
                 AND i.[cpi_habilitado] = 1)          AS [ITEM_TOTAL]

            /* Si ya hay una ejecucion en borrador, la app tiene que retomarla
               en vez de empezar otra: una pauta a medias que se abandona y se
               rehace pierde lo que ya se camino. */
            ,(SELECT TOP 1 e.[cej_id] FROM [dbo].[Checklist_Ejecucion] e
               WHERE e.[cej_checklist_ocurrencia] = coc.[coc_id]
                 AND e.[cej_usuario_ejecutor]     = @USUARIO
                 AND e.[cej_checklist_ejecucion_estado] = 1
                 AND e.[cej_habilitado] = 1
               ORDER BY e.[cej_id] DESC)              AS [EJECUCION_BORRADOR]

          FROM [dbo].[Checklist_Ocurrencia]            coc
          JOIN [dbo].[Checklist_Plantilla_Version]     cpv ON cpv.[cpv_id] = coc.[coc_checklist_plantilla_version]
          JOIN [dbo].[Checklist_Plantilla]             cpl ON cpl.[cpl_id] = cpv.[cpv_checklist_plantilla]
          JOIN [dbo].[Checklist_Ocurrencia_Estado]     coe ON coe.[coe_id] = coc.[coc_checklist_ocurrencia_estado]
     LEFT JOIN [dbo].[Activo]                          act ON act.[act_id] = coc.[coc_activo]
     LEFT JOIN [dbo].[Instalacion_Area]                iar ON iar.[iar_id] = coc.[coc_instalacion_area]

         WHERE coc.[coc_cliente]    = @CLIENTE
           AND coc.[coc_habilitado] = 1
           AND coc.[coc_checklist_ocurrencia_estado] IN (1, 2, 3)   -- por hacer
           /* La ocurrencia se acota por la planta del activo o del area. Una
              sin ninguno de los dos es de la instalacion de la plantilla. */
           AND (   act.[act_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
                OR iar.[iar_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
                OR cpl.[cpl_cliente_instalacion] IN (SELECT [cin_id] FROM @PLANTAS)
                OR cpl.[cpl_cliente_instalacion] IS NULL)

         ORDER BY
              CASE WHEN coc.[coc_fecha_limite_utc] < GETUTCDATE() THEN 0 ELSE 1 END
             ,coc.[coc_fecha_limite_utc]
             ,coc.[coc_id]
    END


    -- --------------------------------------------------- LA PLANTILLA ----
    IF @TIPO = 2
    BEGIN
        SELECT
             cpi.[cpi_id]
            ,cpi.[cpi_codigo]
            ,cpi.[cpi_texto]
            ,cpi.[cpi_ayuda]
            ,cpi.[cpi_orden]
            ,cpi.[cpi_obligatorio]
            ,cpi.[cpi_permite_comentario]
            ,cpi.[cpi_requiere_evidencia]
            ,cpi.[cpi_genera_medicion]
            ,cpi.[cpi_pregunta_voz]
            ,cpi.[cpi_checklist_item_tipo]  AS [TIPO_ID]
            ,cit.[cit_codigo]               AS [TIPO_CODIGO]
            ,cit.[cit_nombre]               AS [TIPO_NOMBRE]
            ,ume.[ume_simbolo]              AS [UNIDAD_SIMBOLO]
            ,cps.[cps_id]                   AS [SECCION_ID]
            ,cps.[cps_nombre]               AS [SECCION_NOMBRE]
            ,cps.[cps_orden]                AS [SECCION_ORDEN]

            /* El rango viene con el item: la app lo necesita para avisar en el
               momento, aunque el veredicto final lo ponga el servidor. */
            ,civ.[civ_valor_minimo]
            ,civ.[civ_valor_maximo]
            ,civ.[civ_mensaje]
            ,civ.[civ_requiere_comentario_fuera_rango]
            ,civ.[civ_genera_hallazgo]

          FROM [dbo].[Checklist_Plantilla_Item]    cpi
          JOIN [dbo].[Checklist_Item_Tipo]         cit ON cit.[cit_id] = cpi.[cpi_checklist_item_tipo]
     LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] cps ON cps.[cps_id] = cpi.[cpi_checklist_plantilla_seccion]
     LEFT JOIN [dbo].[Unidad_Medida]               ume ON ume.[ume_id] = cpi.[cpi_unidad_medida]
     LEFT JOIN [dbo].[Checklist_Item_Validacion]   civ ON civ.[civ_checklist_plantilla_item] = cpi.[cpi_id]
                                                      AND civ.[civ_habilitado] = 1

         WHERE cpi.[cpi_checklist_plantilla_version] = @ID
           AND cpi.[cpi_habilitado] = 1

         ORDER BY ISNULL(cps.[cps_orden], 0), cpi.[cpi_orden], cpi.[cpi_id]
    END


    -- ------------------------------------------------------- EJECUCION ----
    IF @TIPO = 3
    BEGIN
        SELECT
             cej.[cej_id]
            ,cej.[cej_uuid]
            ,cej.[cej_checklist_ocurrencia]        AS [OCURRENCIA_ID]
            ,cej.[cej_checklist_plantilla_version] AS [VERSION_ID]
            ,cpl.[cpl_nombre]                      AS [PLANTILLA_NOMBRE]
            ,cej.[cej_activo]                      AS [ACTIVO_ID]
            ,act.[act_codigo]                      AS [ACTIVO_CODIGO]
            ,act.[act_nombre]                      AS [ACTIVO_NOMBRE]
            ,cej.[cej_checklist_ejecucion_estado]  AS [ESTADO_ID]
            ,cee.[cee_nombre]                      AS [ESTADO_NOMBRE]
            ,cej.[cej_fecha_inicio_utc]
            ,cej.[cej_fecha_fin_utc]
            ,cej.[cej_duracion_minuto]
            ,cej.[cej_item_total]
            ,cej.[cej_item_respondido]
            ,cej.[cej_item_no_conforme]
            ,cej.[cej_observacion]
            ,cej.[cej_offline_creado]

          FROM [dbo].[Checklist_Ejecucion]              cej
          JOIN [dbo].[Checklist_Plantilla_Version]      cpv ON cpv.[cpv_id] = cej.[cej_checklist_plantilla_version]
          JOIN [dbo].[Checklist_Plantilla]              cpl ON cpl.[cpl_id] = cpv.[cpv_checklist_plantilla]
          JOIN [dbo].[Checklist_Ejecucion_Estado]       cee ON cee.[cee_id] = cej.[cej_checklist_ejecucion_estado]
     LEFT JOIN [dbo].[Activo]                           act ON act.[act_id] = cej.[cej_activo]

         WHERE cej.[cej_id]         = @ID
           AND cej.[cej_cliente]    = @CLIENTE
           AND cej.[cej_habilitado] = 1

        /* Segundo resultado: las respuestas que ya tiene. */
        SELECT
             cer.[cer_id]
            ,cer.[cer_checklist_plantilla_item] AS [ITEM_ID]
            ,cer.[cer_valor_texto]
            ,cer.[cer_valor_numero]
            ,cer.[cer_valor_booleano]
            ,cer.[cer_valor_fecha]
            ,cer.[cer_fuera_rango]
            ,cer.[cer_no_aplica]
            ,cer.[cer_comentario]
            ,cer.[cer_entrada_modo]
            ,cer.[cer_fecha_respuesta_utc]

          FROM [dbo].[Checklist_Ejecucion_Respuesta] cer
          JOIN [dbo].[Checklist_Ejecucion]           cej ON cej.[cej_id] = cer.[cer_checklist_ejecucion]

         WHERE cer.[cer_checklist_ejecucion] = @ID
           AND cej.[cej_cliente]             = @CLIENTE
           AND cer.[cer_habilitado]          = 1

         ORDER BY cer.[cer_id]
    END


    -- --------------------------------------------------------- OPCIONES ----
    IF @TIPO = 4
    BEGIN
        SELECT
             cio.[cio_id]
            ,cio.[cio_checklist_plantilla_item] AS [ITEM_ID]
            ,cio.[cio_codigo]
            ,cio.[cio_texto]
            ,cio.[cio_valor]
            ,cio.[cio_orden]
            ,cio.[cio_es_conforme]
            ,cio.[cio_requiere_comentario]

          FROM [dbo].[Checklist_Item_Opcion]     cio
          JOIN [dbo].[Checklist_Plantilla_Item]  cpi ON cpi.[cpi_id] = cio.[cio_checklist_plantilla_item]

         WHERE cpi.[cpi_checklist_plantilla_version] = @ID
           AND cio.[cio_habilitado] = 1

         ORDER BY cio.[cio_checklist_plantilla_item], cio.[cio_orden], cio.[cio_id]
    END

END
GO


-- ---------------------------------------------------------------------------
-- 2 - ABRIR (O RETOMAR) UNA EJECUCION
-- ---------------------------------------------------------------------------
--   Idempotente por uuid. Y ademas: si esta persona ya tiene un BORRADOR de
--   esta ocurrencia, se devuelve ese en vez de crear otro. Una pauta a medias
--   que se abandona y se rehace pierde lo caminado, y en terreno eso significa
--   volver a recorrer la planta.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_CHECKLIST_EJECUCION]
     @UUID          UNIQUEIDENTIFIER
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
        SELECT @CEJ AS [cej_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 3 - RESPONDER UN ITEM
-- ---------------------------------------------------------------------------
--   Es un UPSERT por (ejecucion, item): volver a responder ACTUALIZA. Eso es
--   lo que hace que reenviar una pauta de treinta items desde la cola sea
--   seguro, y tambien que el tecnico pueda corregirse antes de cerrar.
--
--   El rango se evalua ACA contra Checklist_Item_Validacion. Fuera de rango
--   no impide grabar -es el hallazgo- pero queda marcado, y si la plantilla
--   lo pide se abre el Checklist_Hallazgo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_CHECKLIST_RESPUESTA]
     @CEJ_ID         INT
    ,@USUARIO        INT
    ,@CLIENTE        INT
    ,@ITEM           INT
    ,@VALOR_TEXTO    NVARCHAR(MAX)  = NULL
    ,@VALOR_NUMERO   DECIMAL(18,4)  = NULL
    ,@VALOR_BOOLEANO BIT            = NULL
    ,@VALOR_FECHA    DATETIME       = NULL
    ,@NO_APLICA      BIT            = 0
    ,@COMENTARIO     NVARCHAR(MAX)  = NULL
    ,@ENTRADA_MODO   INT            = 1
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @ACTIVO INT

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@ACTIVO = [cej_activo]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_id]              = @CEJ_ID
           AND [cej_cliente]         = @CLIENTE
           AND [cej_usuario_ejecutor] = @USUARIO
           AND [cej_habilitado]      = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La ejecucion no existe o no es tuya.', 16, 1)
            RETURN
        END

        IF @ESTADO <> 1
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La pauta ya fue enviada. No se puede cambiar una respuesta.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item]
                        WHERE [cpi_id] = @ITEM
                          AND [cpi_checklist_plantilla_version] = @VER
                          AND [cpi_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Ese item no pertenece a la pauta que se esta llenando.', 16, 1)
            RETURN
        END

        /* ---- El rango, contra la validacion de la plantilla ---- */
        DECLARE @FUERA BIT = 0, @HALLAZGO BIT = 0, @MENSAJE_VAL NVARCHAR(500)

        SELECT TOP 1
               @FUERA = CASE
                   WHEN @NO_APLICA = 1 OR @VALOR_NUMERO IS NULL THEN 0
                   WHEN [civ_valor_minimo] IS NOT NULL AND @VALOR_NUMERO < [civ_valor_minimo] THEN 1
                   WHEN [civ_valor_maximo] IS NOT NULL AND @VALOR_NUMERO > [civ_valor_maximo] THEN 1
                   ELSE 0 END
              ,@HALLAZGO    = ISNULL([civ_genera_hallazgo], 0)
              ,@MENSAJE_VAL = [civ_mensaje]
          FROM [dbo].[Checklist_Item_Validacion]
         WHERE [civ_checklist_plantilla_item] = @ITEM
           AND [civ_habilitado] = 1

        /* Una opcion marcada como no conforme tambien es un hallazgo. */
        IF @FUERA = 0 AND @VALOR_TEXTO IS NOT NULL
            SELECT @FUERA = CASE WHEN ISNULL([cio_es_conforme], 1) = 0 THEN 1 ELSE 0 END
              FROM [dbo].[Checklist_Item_Opcion]
             WHERE [cio_checklist_plantilla_item] = @ITEM
               AND [cio_codigo]                   = @VALOR_TEXTO
               AND [cio_habilitado]               = 1

        /* Un SI/NO respondido NO tambien cuenta como no conforme. */
        IF @FUERA = 0 AND @VALOR_BOOLEANO = 0 AND @NO_APLICA = 0
           AND EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item]
                        WHERE [cpi_id] = @ITEM AND [cpi_checklist_item_tipo] = 5)
            SET @FUERA = 1

        /* ---- El UPSERT ---- */
        DECLARE @CER INT

        SELECT @CER = [cer_id]
          FROM [dbo].[Checklist_Ejecucion_Respuesta]
         WHERE [cer_checklist_ejecucion]      = @CEJ_ID
           AND [cer_checklist_plantilla_item] = @ITEM

        IF @CER IS NULL
        BEGIN
            INSERT INTO [dbo].[Checklist_Ejecucion_Respuesta]
                ([cer_checklist_ejecucion], [cer_checklist_plantilla_item]
                ,[cer_valor_texto], [cer_valor_numero], [cer_valor_booleano]
                ,[cer_valor_fecha], [cer_fuera_rango], [cer_no_aplica]
                ,[cer_comentario], [cer_entrada_modo], [cer_fecha_respuesta_utc]
                ,[cer_usuario_creacion], [cer_fecha_creacion], [cer_habilitado])
            VALUES
                (@CEJ_ID, @ITEM
                ,@VALOR_TEXTO, @VALOR_NUMERO, @VALOR_BOOLEANO
                ,@VALOR_FECHA, @FUERA, @NO_APLICA
                ,@COMENTARIO, @ENTRADA_MODO, GETUTCDATE()
                ,@USUARIO, GETDATE(), 1)

            SET @CER = SCOPE_IDENTITY()
        END
        ELSE
        BEGIN
            UPDATE [dbo].[Checklist_Ejecucion_Respuesta]
               SET [cer_valor_texto]           = @VALOR_TEXTO
                  ,[cer_valor_numero]          = @VALOR_NUMERO
                  ,[cer_valor_booleano]        = @VALOR_BOOLEANO
                  ,[cer_valor_fecha]           = @VALOR_FECHA
                  ,[cer_fuera_rango]           = @FUERA
                  ,[cer_no_aplica]             = @NO_APLICA
                  ,[cer_comentario]            = @COMENTARIO
                  ,[cer_entrada_modo]          = @ENTRADA_MODO
                  ,[cer_fecha_respuesta_utc]   = GETUTCDATE()
                  ,[cer_usuario_actualizacion] = @USUARIO
                  ,[cer_fecha_actualizacion]   = GETDATE()
             WHERE [cer_id] = @CER
        END

        /* ---- El hallazgo, si la plantilla lo pide y el valor lo amerita ----

           Uno por respuesta: si el tecnico corrige el valor y vuelve a quedar
           fuera de rango, no se abren dos. */
        IF @FUERA = 1 AND @HALLAZGO = 1
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo]
                            WHERE [cha_checklist_ejecucion_respuesta] = @CER)
        BEGIN
            DECLARE @TEXTO NVARCHAR(400) =
                (SELECT [cpi_texto] FROM [dbo].[Checklist_Plantilla_Item] WHERE [cpi_id] = @ITEM)

            INSERT INTO [dbo].[Checklist_Hallazgo]
                ([cha_uuid], [cha_cliente], [cha_checklist_ejecucion]
                ,[cha_checklist_ejecucion_respuesta], [cha_activo]
                ,[cha_titulo], [cha_descripcion], [cha_proceso_estado]
                ,[cha_generado_ia], [cha_usuario_creacion], [cha_fecha_creacion]
                ,[cha_habilitado])
            VALUES
                (NEWID(), @CLIENTE, @CEJ_ID
                ,@CER, @ACTIVO
                ,LEFT(ISNULL(@TEXTO, N'Hallazgo de checklist'), 400)
                ,ISNULL(@MENSAJE_VAL, @COMENTARIO), 1
                ,0, @USUARIO, GETDATE()
                ,1)
        END

        /* ---- Los contadores de la ejecucion.

           Se recalculan, no se acumulan: acumular deja el total mintiendo el
           dia que una respuesta cambie de conforme a no conforme. ---- */
        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_item_respondido] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1)
              ,[cej_item_no_conforme] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1
                       AND [cer_fuera_rango] = 1)
              ,[cej_usuario_actualizacion] = @USUARIO
              ,[cej_fecha_actualizacion]   = GETDATE()
         WHERE [cej_id] = @CEJ_ID

        COMMIT TRANSACTION

        SELECT @CER AS [cer_id], @FUERA AS [fuera_rango],
               @MENSAJE_VAL AS [mensaje]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO


-- ---------------------------------------------------------------------------
-- 4 - CERRAR LA EJECUCION
-- ---------------------------------------------------------------------------
--   Se exige que los OBLIGATORIOS esten respondidos. «No aplica» cuenta como
--   respuesta: no todo item corresponde a todo equipo, y obligar a inventar un
--   valor para poder cerrar es peor que aceptar el «no aplica».
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_CHECKLIST_CERRAR]
     @CEJ_ID       INT
    ,@USUARIO      INT
    ,@CLIENTE      INT
    ,@OBSERVACION  NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @OCU INT, @INICIO DATETIME

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@OCU    = [cej_checklist_ocurrencia]
              ,@INICIO = [cej_fecha_inicio_utc]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_id]              = @CEJ_ID
           AND [cej_cliente]         = @CLIENTE
           AND [cej_usuario_ejecutor] = @USUARIO
           AND [cej_habilitado]      = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La ejecucion no existe o no es tuya.', 16, 1)
            RETURN
        END

        /* Idempotente: cerrar dos veces responde lo mismo. Es el caso del
           reintento de la cola. */
        IF @ESTADO <> 1
        BEGIN
            COMMIT TRANSACTION
            SELECT @CEJ_ID AS [cej_id], 1 AS [YA_ESTABA]
            RETURN
        END

        DECLARE @FALTAN INT =
            (SELECT COUNT(*)
               FROM [dbo].[Checklist_Plantilla_Item] i
              WHERE i.[cpi_checklist_plantilla_version] = @VER
                AND i.[cpi_habilitado]   = 1
                AND i.[cpi_obligatorio]  = 1
                AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Respuesta] r
                                 WHERE r.[cer_checklist_ejecucion]      = @CEJ_ID
                                   AND r.[cer_checklist_plantilla_item] = i.[cpi_id]
                                   AND r.[cer_habilitado]               = 1))

        IF @FALTAN > 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @M NVARCHAR(200) =
                CONCAT(N'Faltan ', @FALTAN, N' items obligatorios por responder.')
            RAISERROR(@M, 16, 1)
            RETURN
        END

        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_checklist_ejecucion_estado] = 3           -- ENVIADA
              ,[cej_fecha_fin_utc]              = GETUTCDATE()
              ,[cej_duracion_minuto]            = DATEDIFF(MINUTE, @INICIO, GETUTCDATE())
              ,[cej_fecha_sincronizacion_utc]   = GETUTCDATE()
              ,[cej_observacion]                = ISNULL(@OBSERVACION, [cej_observacion])
              ,[cej_usuario_actualizacion]      = @USUARIO
              ,[cej_fecha_actualizacion]        = GETDATE()
         WHERE [cej_id] = @CEJ_ID

        IF @OCU IS NOT NULL
            UPDATE [dbo].[Checklist_Ocurrencia]
               SET [coc_checklist_ocurrencia_estado] = 4      -- COMPLETADA
                  ,[coc_usuario_actualizacion]       = @USUARIO
                  ,[coc_fecha_actualizacion]         = GETDATE()
             WHERE [coc_id] = @OCU

        COMMIT TRANSACTION

        SELECT @CEJ_ID AS [cej_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO
