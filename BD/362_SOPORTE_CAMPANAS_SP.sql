USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: campanas. Constructor de audiencia con
--                  conteo en vivo, publicacion y programacion, entrega al
--                  usuario (banner, modal, card y campana) y seguimiento.
-- =============================================
-- Va DESPUES de 361_SOPORTE_AYUDA_SP.
--
-- SIN JOB PROGRAMADO
--   El hosting no da SQL Agent. Una campana programada pasa a activa (y una
--   vencida a finalizada) la primera vez que alguien consulta campanas: lo
--   hacen SEL_CAMPANAS y SEL_CAMPANA_PENDIENTES, que corre en cada pagina.
--
-- LA NOTIFICACION ES UNA ALERTA
--   El formato «Centro de notificaciones» no tiene tabla propia: al entregar
--   la campana a una persona se le crea una fila en Alerta (tipo CAMPANA) y
--   se ve en la campana de siempre.
-- =============================================

SET NOCOUNT ON
GO


CREATE OR ALTER PROCEDURE [dbo].[UPD_CAMPANA_VIGENCIA]
AS
SET NOCOUNT ON
    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    UPDATE [dbo].[Campana] SET cam_estado = 'activa', cam_fecha_actualizacion = @AHORA
     WHERE cam_habilitado = 1 AND cam_estado = 'programada' AND cam_desde <= @AHORA
    UPDATE [dbo].[Campana] SET cam_estado = 'finalizada', cam_fecha_actualizacion = @AHORA
     WHERE cam_habilitado = 1 AND cam_estado IN ('activa','pausada','programada') AND cam_hasta IS NOT NULL AND cam_hasta < @AHORA
GO

/* Las condiciones de una campana guardada, en el mismo JSON del asistente. */
CREATE OR ALTER FUNCTION [dbo].[FNC_CAMPANA_CONDICIONES] (@CAMPANA INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN ISNULL((SELECT ccn_campo AS campo, ccn_operador AS op, ccn_valor AS valor
                     FROM [dbo].[Campana_Condicion] WHERE ccn_campana = @CAMPANA ORDER BY ccn_orden
                      FOR JSON PATH), N'[]')
END
GO


/* ========================================================================
   1. AUDIENCIA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_AUDIENCIA]
    @USUARIO     INT,
    @CONDICIONES NVARCHAR(MAX),
    @UNION       VARCHAR(3) = 'AND',
    @DIMENSION   VARCHAR(20) = NULL     -- perfil · planta · cliente: como se reparte
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0 AND [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para armar audiencias.', 16, 1) RETURN END

    DECLARE @A TABLE (usuario INT, cliente INT, PRIMARY KEY (usuario, cliente))
    INSERT INTO @A SELECT usuario, cliente FROM [dbo].[FNC_CAMPANA_AUDIENCIA](@CONDICIONES, @UNION, NULL)

    SELECT  TOTAL = (SELECT COUNT(*) FROM [dbo].[FNC_CAMPANA_AUDIENCIA](N'[]', 'AND', NULL)),
            ALCANCE = (SELECT COUNT(*) FROM @A),
            PERSONAS = (SELECT COUNT(DISTINCT usuario) FROM @A)

    /* Cuatro caras para el contador: iniciales de algunos de la audiencia. */
    SELECT TOP 4 [dbo].[FNC_SOPORTE_NOMBRE](a.usuario) AS NOMBRE FROM @A a ORDER BY a.usuario

    IF @DIMENSION = 'perfil'
        SELECT TOP 4 pe.per_nombre COLLATE DATABASE_DEFAULT AS ETIQUETA, COUNT(DISTINCT CAST(a.usuario AS VARCHAR(10)) + '-' + CAST(a.cliente AS VARCHAR(10))) AS N
        FROM @A a
        JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = a.usuario AND cu.ucl_id_cliente = a.cliente
        JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
        JOIN [dbo].[Perfiles] pe ON pe.per_id = cup.cup_id_perfil
        GROUP BY pe.per_nombre ORDER BY N DESC
    ELSE IF @DIMENSION = 'planta'
        SELECT TOP 4 cin.cin_nombre COLLATE DATABASE_DEFAULT AS ETIQUETA, COUNT(*) AS N
        FROM @A a
        JOIN [dbo].[Cliente_Instalacion_Usuario] ciu ON ciu.ciu_id_usuario = a.usuario AND ISNULL(ciu.ciu_habilitado, 0) = 1
        JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ciu.ciu_id_instalacion AND cin.cin_cliente = a.cliente
        GROUP BY cin.cin_nombre ORDER BY N DESC
    ELSE
        SELECT TOP 4 cl.cli_nombre COLLATE DATABASE_DEFAULT AS ETIQUETA, COUNT(*) AS N
        FROM @A a JOIN [dbo].[Cliente] cl ON cl.cli_id = a.cliente
        GROUP BY cl.cli_nombre ORDER BY N DESC
GO

/* Los valores que ofrece cada campo del constructor. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_AUDIENCIA_VALORES]
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0 AND [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para armar audiencias.', 16, 1) RETURN END

    SELECT 'estado' AS CAMPO, v.v AS VALOR, v.v AS ETIQUETA FROM (VALUES (N'Activo'), (N'Inactivo')) v (v)
    UNION ALL
    SELECT DISTINCT 'perfil', pe.per_nombre COLLATE DATABASE_DEFAULT, pe.per_nombre COLLATE DATABASE_DEFAULT
      FROM [dbo].[Perfiles] pe WHERE pe.per_tipo = 2 AND pe.per_habilitado = 1
    UNION ALL
    SELECT DISTINCT 'cliente', cl.cli_nombre COLLATE DATABASE_DEFAULT, cl.cli_nombre COLLATE DATABASE_DEFAULT
      FROM [dbo].[Cliente] cl WHERE EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu WHERE cu.ucl_id_cliente = cl.cli_id)
    UNION ALL
    SELECT DISTINCT 'planta', cin.cin_nombre COLLATE DATABASE_DEFAULT, cin.cin_nombre COLLATE DATABASE_DEFAULT
      FROM [dbo].[Cliente_Instalacion] cin
    UNION ALL
    SELECT 'usuario', CAST(u.usu_id AS NVARCHAR(20)), [dbo].[FNC_SOPORTE_NOMBRE](u.usu_id)
      FROM [dbo].[Usuario] u
     WHERE ISNULL(u.usu_habilitado, 0) = 1 AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu WHERE cu.ucl_id_usuario = u.usu_id)
    ORDER BY 1, 3

    SELECT csg_id, csg_nombre, csg_union, csg_condiciones FROM [dbo].[Campana_Segmento] WHERE csg_habilitado = 1 ORDER BY csg_nombre
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_CAMPANA_SEGMENTO]
    @USUARIO     INT,
    @NOMBRE      NVARCHAR(100),
    @UNION       VARCHAR(3),
    @CONDICIONES NVARCHAR(MAX)
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para guardar segmentos.', 16, 1) RETURN END
    SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))
    IF ISNULL(@NOMBRE, '') = '' BEGIN RAISERROR(N'Ponle un nombre al segmento.', 16, 1) RETURN END
    IF ISJSON(@CONDICIONES) = 0 BEGIN RAISERROR(N'Condiciones no válidas.', 16, 1) RETURN END

    IF EXISTS (SELECT 1 FROM [dbo].[Campana_Segmento] WHERE csg_nombre = @NOMBRE AND csg_habilitado = 1)
        UPDATE [dbo].[Campana_Segmento] SET csg_union = @UNION, csg_condiciones = @CONDICIONES, csg_usuario = @USUARIO, csg_fecha = [dbo].[FNC_AHORA]()
         WHERE csg_nombre = @NOMBRE AND csg_habilitado = 1
    ELSE
        INSERT INTO [dbo].[Campana_Segmento] (csg_nombre, csg_union, csg_condiciones, csg_usuario)
        VALUES (@NOMBRE, CASE WHEN @UNION = 'OR' THEN 'OR' ELSE 'AND' END, @CONDICIONES, @USUARIO)
    SELECT csg_id FROM [dbo].[Campana_Segmento] WHERE csg_nombre = @NOMBRE AND csg_habilitado = 1
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

    SELECT  c.cam_id, c.cam_tipo, c.cam_titulo, c.cam_descripcion, c.cam_estado, c.cam_medio, c.cam_tema, c.cam_archivo, c.cam_formatos,
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

CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_SEGUIMIENTO]
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para ver campañas.', 16, 1) RETURN END
    DECLARE @AHORA DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    ;WITH D AS (SELECT TOP (14) DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 14, @AHORA) AS dia FROM sys.all_objects)
    SELECT D.dia,
           VISTAS = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = @ID AND CAST(e.cen_fecha_primera AS DATE) = D.dia),
           INTERACCIONES = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = @ID AND CAST(e.cen_fecha_interaccion AS DATE) = D.dia)
    FROM D ORDER BY D.dia

    SELECT CONFIRMADOS = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = @ID AND e.cen_fecha_confirmacion IS NOT NULL),
           DESCARTADOS = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = @ID AND e.cen_fecha_descarte IS NOT NULL)
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

CREATE OR ALTER PROCEDURE [dbo].[UPD_CAMPANA_ESTADO]
    @ID      INT,
    @USUARIO INT,
    @ESTADO  VARCHAR(12)
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para administrar campañas.', 16, 1) RETURN END
    IF @ESTADO NOT IN ('activa','pausada','finalizada') BEGIN RAISERROR(N'Estado no válido.', 16, 1) RETURN END

    UPDATE [dbo].[Campana] SET cam_estado = @ESTADO, cam_usuario_actualizacion = @USUARIO, cam_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE cam_id = @ID AND cam_habilitado = 1 AND cam_estado IN ('activa','pausada')
    IF @@ROWCOUNT = 0 BEGIN RAISERROR(N'Solo se pausan o reanudan campañas publicadas.', 16, 1) RETURN END
    SELECT @ID AS cam_id
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
    SELECT  k.cam_id, k.cam_tipo, k.cam_titulo, k.cam_descripcion, k.cam_medio, k.cam_tema, k.cam_archivo, k.cam_formatos,
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

/* vista · interaccion · descarte · confirmacion */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CAMPANA_ENTREGA]
    @CAMPANA INT,
    @USUARIO INT,
    @CLIENTE INT,
    @ACCION  VARCHAR(12)
AS
SET NOCOUNT ON
    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] WHERE cen_campana = @CAMPANA AND cen_usuario = @USUARIO AND cen_cliente = @CLIENTE)
        RETURN

    UPDATE [dbo].[Campana_Entrega]
       SET cen_veces = cen_veces + CASE WHEN @ACCION = 'vista' THEN 1 ELSE 0 END,
           cen_fecha_primera = CASE WHEN @ACCION = 'vista' THEN ISNULL(cen_fecha_primera, @AHORA) ELSE cen_fecha_primera END,
           cen_fecha_ultima = CASE WHEN @ACCION = 'vista' THEN @AHORA ELSE cen_fecha_ultima END,
           cen_fecha_interaccion = CASE WHEN @ACCION = 'interaccion' THEN ISNULL(cen_fecha_interaccion, @AHORA) ELSE cen_fecha_interaccion END,
           cen_fecha_confirmacion = CASE WHEN @ACCION = 'confirmacion' THEN ISNULL(cen_fecha_confirmacion, @AHORA) ELSE cen_fecha_confirmacion END,
           /* Cerrarla, tocar el boton o confirmarla la da por leida. */
           cen_fecha_descarte = CASE WHEN @ACCION IN ('descarte','interaccion','confirmacion') THEN ISNULL(cen_fecha_descarte, @AHORA) ELSE cen_fecha_descarte END
     WHERE cen_campana = @CAMPANA AND cen_usuario = @USUARIO AND cen_cliente = @CLIENTE

    IF @ACCION IN ('interaccion','confirmacion')
        INSERT INTO [dbo].[Alerta_Lectura] (alr_alerta, alr_usuario, alr_fecha)
        SELECT e.cen_alerta, @USUARIO, @AHORA FROM [dbo].[Campana_Entrega] e
         WHERE e.cen_campana = @CAMPANA AND e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE AND e.cen_alerta IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Lectura] l WHERE l.alr_alerta = e.cen_alerta AND l.alr_usuario = @USUARIO)
    SELECT 1 AS OK
GO
