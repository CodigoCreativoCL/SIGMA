/* ======================================================================
   369 · PRESENTACION DE LA CAMPAÑA (06-10-2026)

   Cómo se muestra la imagen y el aviso: ajuste (llenar o completa), punto
   de enfoque, alto de la imagen y tamaño del modal. Se guarda como JSON en
   cam_presentacion; el asistente lo arma en «Contenido» y lo prueba en
   «Vista previa». Re-ejecutable.
   ====================================================================== */
USE [db_acd593_sigma]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
IF COL_LENGTH('dbo.Campana', 'cam_presentacion') IS NULL
    ALTER TABLE [dbo].[Campana] ADD cam_presentacion NVARCHAR(400) NULL
GO
/* ========================================================================

   3. GUARDAR Y PUBLICAR

   ======================================================================== */



/* @DATOS: {"id":null,"accion":"borrador|publicar","tipo":"novedad",

   "titulo":"...","descripcion":"...","medio":"imagen","tema":0,

   "archivo":null,"formatos":["banner","notif"],"donde":"login",

   "dondeModulo":null,"cerrable":true,"confirmar":false,

   "cta":{"a":"modulo","l":"Ver novedad","dest":"..."},"contenido":null,

   "union":"AND","condiciones":[...],"frecuencia":"usuario","cadaDias":7,

   "cuando":"now|prog","desde":"2026-10-08T09:00","hasta":null} */

CREATE OR ALTER PROCEDURE [dbo].[UPS_CAMPANA]

    @USUARIO INT,

    @DATOS   NVARCHAR(MAX)

AS

SET NOCOUNT ON

SET XACT_ABORT ON

    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0

    BEGIN RAISERROR(N'No tienes permiso para administrar campañas.', 16, 1) RETURN END

    IF ISJSON(@DATOS) = 0 BEGIN RAISERROR(N'Datos no válidos.', 16, 1) RETURN END



    DECLARE @ID INT = TRY_CAST(JSON_VALUE(@DATOS, '$.id') AS INT)

    DECLARE @ACCION VARCHAR(10) = ISNULL(JSON_VALUE(@DATOS, '$.accion'), 'borrador')

    DECLARE @TITULO NVARCHAR(70) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@DATOS, '$.titulo'), ''))), 70)

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    DECLARE @COND NVARCHAR(MAX) = ISNULL(JSON_QUERY(@DATOS, '$.condiciones'), N'[]')

    DECLARE @UNION VARCHAR(3) = CASE WHEN JSON_VALUE(@DATOS, '$.union') = 'OR' THEN 'OR' ELSE 'AND' END

    DECLARE @FMT VARCHAR(40) = (SELECT STRING_AGG(CAST(value AS VARCHAR(10)), ',') FROM OPENJSON(@DATOS, '$.formatos')

                                 WHERE value IN ('banner','modal','card','notif'))

    DECLARE @DESDE DATETIME = CASE WHEN JSON_VALUE(@DATOS, '$.cuando') = 'prog' THEN TRY_CAST(JSON_VALUE(@DATOS, '$.desde') AS DATETIME) ELSE @AHORA END

    DECLARE @HASTA DATETIME = TRY_CAST(JSON_VALUE(@DATOS, '$.hasta') AS DATETIME)



    IF @ACCION = 'publicar'

    BEGIN

        IF @TITULO = '' BEGIN RAISERROR(N'Falta el título de la campaña.', 16, 1) RETURN END

        IF @FMT IS NULL BEGIN RAISERROR(N'Elige al menos un formato.', 16, 1) RETURN END

        IF @DESDE IS NULL BEGIN RAISERROR(N'Elige la fecha de inicio.', 16, 1) RETURN END

        IF @HASTA IS NOT NULL AND @HASTA <= @DESDE BEGIN RAISERROR(N'La fecha de término debe ser posterior al inicio.', 16, 1) RETURN END

    END

    IF @TITULO = '' SET @TITULO = N'Campaña sin título'



    DECLARE @ESTADO VARCHAR(12) = CASE WHEN @ACCION <> 'publicar' THEN 'borrador'

                                       WHEN @DESDE > @AHORA THEN 'programada' ELSE 'activa' END

    DECLARE @ALCANCE INT = (SELECT COUNT(*) FROM [dbo].[FNC_CAMPANA_AUDIENCIA](@COND, @UNION, NULL))



    BEGIN TRAN

        IF @ID IS NULL

        BEGIN

            INSERT INTO [dbo].[Campana] (cam_tipo, cam_titulo, cam_estado, cam_usuario_creacion)

            VALUES (ISNULL(JSON_VALUE(@DATOS, '$.tipo'), 'novedad'), @TITULO, @ESTADO, @USUARIO)

            SET @ID = SCOPE_IDENTITY()

        END

        ELSE IF NOT EXISTS (SELECT 1 FROM [dbo].[Campana] WHERE cam_id = @ID AND cam_habilitado = 1)

        BEGIN ROLLBACK RAISERROR(N'La campaña no existe.', 16, 1) RETURN END



        UPDATE [dbo].[Campana]

           SET cam_tipo = ISNULL(JSON_VALUE(@DATOS, '$.tipo'), 'novedad'),

               cam_titulo = @TITULO,

               cam_descripcion = LEFT(NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.descripcion'))), ''), 220),

               cam_estado = @ESTADO,

               cam_medio = ISNULL(JSON_VALUE(@DATOS, '$.medio'), 'imagen'),

               cam_tema = ISNULL(TRY_CAST(JSON_VALUE(@DATOS, '$.tema') AS INT), 0),

               cam_archivo = TRY_CAST(JSON_VALUE(@DATOS, '$.archivo') AS INT),

               cam_formatos = ISNULL(@FMT, 'banner'),
               cam_presentacion = LEFT(JSON_QUERY(@DATOS, '$.presentacion'), 400),

               cam_donde = CASE WHEN JSON_VALUE(@DATOS, '$.donde') = 'modulo' THEN 'modulo' ELSE 'login' END,

               cam_donde_modulo = NULLIF(JSON_VALUE(@DATOS, '$.dondeModulo'), ''),

               cam_cerrable = ISNULL(TRY_CAST(JSON_VALUE(@DATOS, '$.cerrable') AS BIT), 1),

               cam_confirmar = ISNULL(TRY_CAST(JSON_VALUE(@DATOS, '$.confirmar') AS BIT), 0),

               cam_cta_accion = ISNULL(JSON_VALUE(@DATOS, '$.cta.a'), 'nada'),

               cam_cta_texto = NULLIF(LEFT(JSON_VALUE(@DATOS, '$.cta.l'), 60), ''),

               cam_cta_destino = NULLIF(LEFT(JSON_VALUE(@DATOS, '$.cta.dest'), 600), ''),

               cam_contenido = TRY_CAST(JSON_VALUE(@DATOS, '$.contenido') AS INT),

               cam_union = @UNION,

               cam_frecuencia = CASE WHEN JSON_VALUE(@DATOS, '$.frecuencia') IN ('una','usuario','leer','repetir') THEN JSON_VALUE(@DATOS, '$.frecuencia') ELSE 'usuario' END,

               cam_cada_dias = TRY_CAST(JSON_VALUE(@DATOS, '$.cadaDias') AS INT),

               cam_desde = CASE WHEN @ACCION = 'publicar' THEN @DESDE ELSE cam_desde END,

               cam_hasta = @HASTA,

               cam_alcance = @ALCANCE,

               cam_usuario_actualizacion = @USUARIO,

               cam_fecha_actualizacion = @AHORA

         WHERE cam_id = @ID



        DELETE FROM [dbo].[Campana_Condicion] WHERE ccn_campana = @ID

        INSERT INTO [dbo].[Campana_Condicion] (ccn_campana, ccn_orden, ccn_campo, ccn_operador, ccn_valor)

        SELECT @ID, CAST([key] AS INT) + 1, JSON_VALUE(value, '$.campo'),

               CASE WHEN JSON_VALUE(value, '$.op') = '!=' THEN '!=' ELSE '=' END, LEFT(JSON_VALUE(value, '$.valor'), 200)

          FROM OPENJSON(@COND)

         WHERE JSON_VALUE(value, '$.campo') IN ('estado','perfil','cliente','planta','usuario') AND JSON_VALUE(value, '$.valor') IS NOT NULL

    COMMIT



    SELECT cam_id, cam_estado, cam_alcance, cam_desde FROM [dbo].[Campana] WHERE cam_id = @ID
GO
/* ========================================================================

   4. ENTREGA AL USUARIO

   ======================================================================== */



/* Lo que le toca ver a esta persona en esta pagina. Corre en cada pagina:

   la audiencia se calcula solo para ella (@USUARIO en la funcion). */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_PENDIENTES]

    @USUARIO INT,

    @CLIENTE INT,

    @MODULO  NVARCHAR(150) = NULL

AS

SET NOCOUNT ON

    EXEC [dbo].[UPD_CAMPANA_VIGENCIA]



    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    DECLARE @C TABLE (cam_id INT PRIMARY KEY)



    INSERT INTO @C (cam_id)

    SELECT  c.cam_id

    FROM    [dbo].[Campana] c

    WHERE   c.cam_habilitado = 1 AND c.cam_estado = 'activa'

      AND   c.cam_desde <= @AHORA AND (c.cam_hasta IS NULL OR c.cam_hasta >= @AHORA)

      AND   EXISTS (SELECT 1 FROM [dbo].[FNC_CAMPANA_AUDIENCIA]([dbo].[FNC_CAMPANA_CONDICIONES](c.cam_id), c.cam_union, @USUARIO) a

                     WHERE a.cliente = @CLIENTE)



    IF NOT EXISTS (SELECT 1 FROM @C) RETURN



    /* La fila de entrega existe desde que le corresponde, aunque no la vea:

       ahi se cuelga su aviso en la campana. */

    INSERT INTO [dbo].[Campana_Entrega] (cen_campana, cen_usuario, cen_cliente)

    SELECT c.cam_id, @USUARIO, @CLIENTE FROM @C c

     WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = c.cam_id AND e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE)



    /* Formato «Centro de notificaciones»: una alerta dirigida, una vez. */

    DECLARE @TIPO INT = (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = N'CAMPANA')

    DECLARE @NUEVA INT = (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA')

    DECLARE @E INT, @CAM INT

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR

        SELECT e.cen_id, e.cen_campana FROM [dbo].[Campana_Entrega] e JOIN @C c ON c.cam_id = e.cen_campana

          JOIN [dbo].[Campana] k ON k.cam_id = e.cen_campana

         WHERE e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE AND e.cen_alerta IS NULL

           AND (',' + k.cam_formatos + ',') LIKE '%,notif,%'

    OPEN cur

    FETCH NEXT FROM cur INTO @E, @CAM

    WHILE @@FETCH_STATUS = 0

    BEGIN

        INSERT INTO [dbo].[Alerta] (ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_titulo, ale_descripcion, ale_usuario_destinatario,

                                    ale_campana, ale_ayuda_contenido, ale_usuario_creacion, ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc)

        SELECT @CLIENTE, @TIPO, @NUEVA, k.cam_titulo, k.cam_descripcion, @USUARIO, k.cam_id, k.cam_contenido, k.cam_usuario_creacion, GETUTCDATE(), GETUTCDATE()

          FROM [dbo].[Campana] k WHERE k.cam_id = @CAM

        UPDATE [dbo].[Campana_Entrega] SET cen_alerta = SCOPE_IDENTITY() WHERE cen_id = @E

        FETCH NEXT FROM cur INTO @E, @CAM

    END

    CLOSE cur

    DEALLOCATE cur



    /* Las que se muestran ahora, segun su frecuencia y donde aparecen. */

    SELECT  k.cam_id, k.cam_tipo, k.cam_titulo, k.cam_descripcion, k.cam_medio, k.cam_tema, k.cam_archivo, k.cam_formatos, k.cam_presentacion,

            k.cam_cerrable, k.cam_confirmar, k.cam_cta_accion, k.cam_cta_texto, k.cam_cta_destino,

            k.cam_contenido, a.ayc_titulo AS CONTENIDO_TITULO, a.ayc_tipo AS CONTENIDO_TIPO, k.cam_frecuencia,

            e.cen_veces

    FROM    @C c

    JOIN    [dbo].[Campana] k ON k.cam_id = c.cam_id

    JOIN    [dbo].[Campana_Entrega] e ON e.cen_campana = k.cam_id AND e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE

    LEFT JOIN [dbo].[Ayuda_Contenido] a ON a.ayc_id = k.cam_contenido AND a.ayc_estado = 'Publicado'

    WHERE   (k.cam_donde = 'login' OR k.cam_donde_modulo = @MODULO)

            /* tiene algo que mostrar en la pagina (la campana ya se resolvio arriba) */

      AND   ((',' + k.cam_formatos + ',') LIKE '%,banner,%' OR (',' + k.cam_formatos + ',') LIKE '%,modal,%' OR (',' + k.cam_formatos + ',') LIKE '%,card,%')

      AND   CASE k.cam_frecuencia

                /* una vez: la primera vista la da por cumplida */

                WHEN 'una'     THEN CASE WHEN e.cen_veces = 0 THEN 1 ELSE 0 END

                /* una vez por persona, aunque trabaje en varios clientes */

                WHEN 'usuario' THEN CASE WHEN NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] x WHERE x.cen_campana = k.cam_id

                                                              AND x.cen_usuario = @USUARIO AND x.cen_veces > 0) THEN 1 ELSE 0 END

                /* hasta que la lea: cerrarla, tocar el boton o confirmarla */

                WHEN 'leer'    THEN CASE WHEN e.cen_fecha_descarte IS NULL THEN 1 ELSE 0 END

                /* cada X dias */

                WHEN 'repetir' THEN CASE WHEN e.cen_veces = 0 OR e.cen_fecha_ultima <= DATEADD(DAY, -ISNULL(k.cam_cada_dias, 7), @AHORA) THEN 1 ELSE 0 END

                ELSE 0 END = 1

    ORDER BY CASE k.cam_tipo WHEN 'importante' THEN 1 WHEN 'mant' THEN 2 ELSE 3 END, k.cam_desde DESC
GO
/* ========================================================================

   2. CENTRO DE CAMPANAS Y DETALLE

   ======================================================================== */



CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANAS]

    @USUARIO INT

AS

SET NOCOUNT ON

    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0

    BEGIN RAISERROR(N'No tienes permiso para ver campañas.', 16, 1) RETURN END

    EXEC [dbo].[UPD_CAMPANA_VIGENCIA]



    SELECT  c.cam_id, c.cam_tipo, c.cam_titulo, c.cam_descripcion, c.cam_estado, c.cam_medio, c.cam_tema, c.cam_archivo, c.cam_formatos, c.cam_presentacion,

            c.cam_donde, c.cam_donde_modulo, c.cam_cerrable, c.cam_confirmar, c.cam_cta_accion, c.cam_cta_texto, c.cam_cta_destino,

            c.cam_contenido, k.ayc_titulo AS CONTENIDO_TITULO, k.ayc_tipo AS CONTENIDO_TIPO,

            c.cam_union, c.cam_frecuencia, c.cam_cada_dias, c.cam_desde, c.cam_hasta, c.cam_alcance, c.cam_fecha_actualizacion,

            [dbo].[FNC_CAMPANA_CONDICIONES](c.cam_id) AS CONDICIONES,

            VISTOS = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = c.cam_id AND e.cen_veces > 0),

            INTERACCIONES = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = c.cam_id AND (e.cen_fecha_interaccion IS NOT NULL OR e.cen_fecha_confirmacion IS NOT NULL))

    FROM    [dbo].[Campana] c

    LEFT JOIN [dbo].[Ayuda_Contenido] k ON k.ayc_id = c.cam_contenido

    WHERE   c.cam_habilitado = 1

    ORDER BY CASE c.cam_estado WHEN 'activa' THEN 1 WHEN 'pausada' THEN 2 WHEN 'programada' THEN 3 WHEN 'borrador' THEN 4 ELSE 5 END,

             c.cam_fecha_actualizacion DESC
GO
