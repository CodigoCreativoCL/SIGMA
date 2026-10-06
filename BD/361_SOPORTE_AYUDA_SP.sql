USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: centro de ayuda. Contenidos, versiones,
--                  vinculacion contextual, sugerencia antes del ticket,
--                  ayuda «? Ayuda» de cada pantalla y su analitica.
-- =============================================
-- Va DESPUES de 360_SOPORTE_TICKETS_SP.
--
-- LA VERSION ES UNA FOTO
--   Publicar guarda en Ayuda_Contenido_Version el JSON completo (contenido,
--   pasos, recomendaciones y vinculos). Restaurar aplica esa foto y publica
--   una version NUEVA: el historial nunca se pisa.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. AUXILIARES
   ======================================================================== */

/* ¿Puede esta persona ver este contenido? Publicado y dentro de su
   audiencia, o es administrador de la ayuda. */
CREATE OR ALTER FUNCTION [dbo].[FNC_AYUDA_VISIBLE] (@CONTENIDO INT, @USUARIO INT, @CLIENTE INT)
RETURNS BIT
AS
BEGIN
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 1
        RETURN CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @CONTENIDO AND ayc_habilitado = 1) THEN 1 ELSE 0 END

    DECLARE @COND NVARCHAR(MAX), @UNION VARCHAR(3), @EST VARCHAR(12)
    SELECT @COND = ayc_audiencia_condiciones, @UNION = ayc_audiencia_union, @EST = ayc_estado
      FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @CONTENIDO AND ayc_habilitado = 1
    IF @EST IS NULL OR @EST <> 'Publicado' RETURN 0
    IF @COND IS NULL OR ISJSON(@COND) = 0 OR @COND = '[]' RETURN 1
    /* Las cuentas de plataforma no tienen audiencia: ven todo lo publicado. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO) RETURN 1
    RETURN CASE WHEN EXISTS (SELECT 1 FROM [dbo].[FNC_CAMPANA_AUDIENCIA](@COND, @UNION, @USUARIO) a WHERE a.cliente = @CLIENTE) THEN 1 ELSE 0 END
END
GO

/* «v1.3» -> «v1.4». */
CREATE OR ALTER FUNCTION [dbo].[FNC_AYUDA_SIGUIENTE_VERSION] (@V VARCHAR(12))
RETURNS VARCHAR(12)
AS
BEGIN
    DECLARE @N DECIMAL(9,1) = TRY_CAST(REPLACE(REPLACE(ISNULL(@V, 'v1.0'), 'v', ''), 'V', '') AS DECIMAL(9,1))
    IF @N IS NULL RETURN 'v1.0'
    RETURN 'v' + CAST(CAST(@N + 0.1 AS DECIMAL(9,1)) AS VARCHAR(10))
END
GO

/* La foto JSON del contenido tal como esta ahora. */
CREATE OR ALTER FUNCTION [dbo].[FNC_AYUDA_FOTO] (@ID INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN (
        SELECT  c.ayc_tipo AS tipo, c.ayc_titulo AS titulo, c.ayc_descripcion AS descripcion, c.ayc_objetivo AS objetivo,
                c.ayc_cuerpo AS cuerpo, c.ayc_formato AS formato, c.ayc_duracion AS duracion, c.ayc_paginas AS paginas,
                c.ayc_lectura AS lectura, c.ayc_archivo AS archivo, c.ayc_url AS url, c.ayc_audiencia AS audiencia,
                c.ayc_audiencia_condiciones AS condiciones, c.ayc_audiencia_union AS [union], c.ayc_tema AS tema,
                pasos = (SELECT p.acp_titulo AS t, p.acp_minuto AS m FROM [dbo].[Ayuda_Contenido_Paso] p
                          WHERE p.acp_contenido = c.ayc_id ORDER BY p.acp_orden FOR JSON PATH),
                recs = (SELECT r.acr_texto AS t FROM [dbo].[Ayuda_Contenido_Recomendacion] r
                         WHERE r.acr_contenido = c.ayc_id ORDER BY r.acr_orden FOR JSON PATH),
                vinculos = (SELECT v.acv_modulo AS m, v.acv_submodulo AS s, v.acv_pantalla AS p, v.acv_seccion AS sec
                             FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id ORDER BY v.acv_orden FOR JSON PATH)
        FROM    [dbo].[Ayuda_Contenido] c
        WHERE   c.ayc_id = @ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
END
GO

/* Pasos, recomendaciones y vinculos desde el JSON del asistente (o de una
   foto). Reemplaza los que habia. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_AYUDA_CONTENIDO_DETALLE]
    @ID    INT,
    @DATOS NVARCHAR(MAX)
AS
SET NOCOUNT ON
    DELETE FROM [dbo].[Ayuda_Contenido_Paso] WHERE acp_contenido = @ID
    DELETE FROM [dbo].[Ayuda_Contenido_Recomendacion] WHERE acr_contenido = @ID
    DELETE FROM [dbo].[Ayuda_Contenido_Vinculo] WHERE acv_contenido = @ID

    INSERT INTO [dbo].[Ayuda_Contenido_Paso] (acp_contenido, acp_orden, acp_titulo, acp_minuto)
    SELECT @ID, CAST([key] AS INT) + 1, LEFT(JSON_VALUE(value, '$.t'), 200), NULLIF(LEFT(JSON_VALUE(value, '$.m'), 10), '')
      FROM OPENJSON(@DATOS, '$.pasos')
     WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(value, '$.t'))), '') IS NOT NULL

    INSERT INTO [dbo].[Ayuda_Contenido_Recomendacion] (acr_contenido, acr_orden, acr_texto)
    SELECT @ID, CAST([key] AS INT) + 1, LEFT(JSON_VALUE(value, '$.t'), 400)
      FROM OPENJSON(@DATOS, '$.recs')
     WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(value, '$.t'))), '') IS NOT NULL

    INSERT INTO [dbo].[Ayuda_Contenido_Vinculo] (acv_contenido, acv_modulo, acv_submodulo, acv_pantalla, acv_seccion, acv_orden)
    SELECT @ID, JSON_VALUE(value, '$.m'), NULLIF(JSON_VALUE(value, '$.s'), ''), NULLIF(JSON_VALUE(value, '$.p'), ''),
           NULLIF(JSON_VALUE(value, '$.sec'), ''), CAST([key] AS INT) + 1
      FROM OPENJSON(@DATOS, '$.vinculos')
     WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(value, '$.m'))), '') IS NOT NULL

    /* La categoria sale del modulo del primer vinculo. */
    UPDATE c SET ayc_categoria = (SELECT TOP 1 a.aca_id FROM [dbo].[Ayuda_Categoria] a
                                    JOIN [dbo].[Ayuda_Contenido_Vinculo] v ON v.acv_modulo = a.aca_modulo
                                   WHERE v.acv_contenido = c.ayc_id AND a.aca_habilitado = 1 ORDER BY v.acv_orden)
      FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_id = @ID
GO


/* ========================================================================
   2. PANTALLAS PARA LA VINCULACION
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_PANTALLAS]
AS
SET NOCOUNT ON
    EXEC [dbo].[UPS_AYUDA_PANTALLA_SINCRONIZAR]

    SELECT  apa_id, apa_link, apa_modulo, apa_submodulo, apa_pantalla, apa_visible
    FROM    [dbo].[Ayuda_Pantalla]
    WHERE   apa_habilitado = 1
    ORDER BY apa_modulo, apa_submodulo, apa_visible DESC, apa_pantalla

    /* Secciones ya usadas en alguna pantalla: se ofrecen al vincular. */
    SELECT DISTINCT acv_modulo, acv_submodulo, acv_pantalla, acv_seccion
    FROM    [dbo].[Ayuda_Contenido_Vinculo]
    WHERE   acv_seccion IS NOT NULL
GO


/* ========================================================================
   3. LISTADO, DETALLE Y USO
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_CONTENIDOS]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    DECLARE @ADMIN BIT = [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR')
    DECLARE @H30 DATETIME = DATEADD(DAY, -30, [dbo].[FNC_AHORA]())

    SELECT  c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_descripcion, c.ayc_formato, c.ayc_duracion, c.ayc_paginas, c.ayc_lectura,
            c.ayc_estado, c.ayc_version, c.ayc_categoria, c.ayc_tema, c.ayc_fecha_actualizacion, c.ayc_audiencia,
            [dbo].[FNC_SOPORTE_NOMBRE](ISNULL(c.ayc_usuario_actualizacion, c.ayc_usuario_creacion)) AS AUTOR,
            v.acv_modulo AS MODULO, v.acv_submodulo AS SUBMODULO, v.acv_pantalla AS PANTALLA, v.acv_seccion AS SECCION,
            NOTA = (SELECT TOP 1 x.aver_nota FROM [dbo].[Ayuda_Contenido_Version] x WHERE x.aver_contenido = c.ayc_id ORDER BY x.aver_id DESC),
            VISTAS   = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'vista' AND w.avs_fecha >= @H30),
            VISTAS_TOTAL = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'vista'),
            UNICOS   = (SELECT COUNT(DISTINCT w.avs_usuario) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_fecha >= @H30),
            DESCARGAS = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'descarga' AND w.avs_fecha >= @H30),
            REPRODUCCIONES = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'reproduccion' AND w.avs_fecha >= @H30),
            COMPLETOS = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'completo' AND w.avs_fecha >= @H30),
            VALORACION = (SELECT CAST(AVG(CAST(a.ava_estrellas AS DECIMAL(4,2))) AS DECIMAL(3,1)) FROM [dbo].[Ayuda_Valoracion] a WHERE a.ava_contenido = c.ayc_id),
            VALORACIONES = (SELECT COUNT(*) FROM [dbo].[Ayuda_Valoracion] a WHERE a.ava_contenido = c.ayc_id)
    FROM    [dbo].[Ayuda_Contenido] c
    OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Ayuda_Contenido_Vinculo] x WHERE x.acv_contenido = c.ayc_id ORDER BY x.acv_orden) v
    WHERE   c.ayc_habilitado = 1
      AND   c.ayc_estado <> 'Archivado'
      AND   (@ADMIN = 1 OR [dbo].[FNC_AYUDA_VISIBLE](c.ayc_id, @USUARIO, @CLIENTE) = 1)
    ORDER BY c.ayc_fecha_actualizacion DESC

    SELECT  a.aca_id, a.aca_nombre, a.aca_modulo, a.aca_icono, a.aca_tono, a.aca_orden
    FROM    [dbo].[Ayuda_Categoria] a WHERE a.aca_habilitado = 1 ORDER BY a.aca_orden, a.aca_nombre

    SELECT @ADMIN AS ADMIN, [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') AS CAMPANAS,
           [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'SOPORTE ANALITICA') AS ANALITICA
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_CONTENIDO]
    @ID      INT,
    @USUARIO INT,
    @CLIENTE INT,
    @ORIGEN  VARCHAR(20) = NULL     -- si viene, cuenta como una vista
AS
SET NOCOUNT ON
    IF [dbo].[FNC_AYUDA_VISIBLE](@ID, @USUARIO, @CLIENTE) = 0
    BEGIN RAISERROR(N'Ese contenido no existe o ya no está publicado.', 16, 1) RETURN END

    IF @ORIGEN IS NOT NULL
        INSERT INTO [dbo].[Ayuda_Vista] (avs_contenido, avs_usuario, avs_cliente, avs_tipo, avs_origen)
        VALUES (@ID, @USUARIO, NULLIF(@CLIENTE, 0), 'vista', LEFT(@ORIGEN, 20))

    DECLARE @H30 DATETIME = DATEADD(DAY, -30, [dbo].[FNC_AHORA]())

    /* 1. El contenido */
    SELECT  c.*, [dbo].[FNC_SOPORTE_NOMBRE](c.ayc_usuario_creacion) AS AUTOR,
            [dbo].[FNC_SOPORTE_NOMBRE](ISNULL(c.ayc_usuario_actualizacion, c.ayc_usuario_creacion)) AS EDITOR,
            a.ar_nombre AS ARCHIVO_NOMBRE, a.ar_extension AS ARCHIVO_EXTENSION, a.ar_byte AS ARCHIVO_BYTE, a.ar_mime AS ARCHIVO_MIME,
            [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') AS ADMIN,
            [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'CAMPANAS ADMINISTRAR') AS CAMPANAS
    FROM    [dbo].[Ayuda_Contenido] c
    OUTER APPLY (SELECT arc_nombre_original AS ar_nombre, arc_extension AS ar_extension, arc_byte AS ar_byte, arc_mime AS ar_mime
                   FROM [dbo].[Archivo] WHERE arc_id = c.ayc_archivo) a
    WHERE   c.ayc_id = @ID

    /* 2. Pasos, 3. recomendaciones, 4. vinculos */
    SELECT acp_orden, acp_titulo, acp_minuto FROM [dbo].[Ayuda_Contenido_Paso] WHERE acp_contenido = @ID ORDER BY acp_orden
    SELECT acr_orden, acr_texto FROM [dbo].[Ayuda_Contenido_Recomendacion] WHERE acr_contenido = @ID ORDER BY acr_orden
    SELECT acv_modulo, acv_submodulo, acv_pantalla, acv_seccion,
           LINK = (SELECT TOP 1 p.apa_link FROM [dbo].[Ayuda_Pantalla] p
                    WHERE p.apa_habilitado = 1 AND p.apa_modulo = v.acv_modulo
                      AND (v.acv_submodulo IS NULL OR p.apa_submodulo = v.acv_submodulo)
                      AND (v.acv_pantalla IS NULL OR p.apa_pantalla = v.acv_pantalla)
                    ORDER BY p.apa_visible DESC, p.apa_id)
      FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE acv_contenido = @ID ORDER BY acv_orden

    /* 5. Versiones */
    SELECT  aver_id, aver_version, aver_nota, aver_estado, aver_archivo, aver_fecha, [dbo].[FNC_SOPORTE_NOMBRE](aver_usuario) AS AUTOR
    FROM    [dbo].[Ayuda_Contenido_Version] WHERE aver_contenido = @ID ORDER BY aver_id DESC

    /* 6. Relacionados: del mismo modulo, lo mas visto */
    DECLARE @MOD NVARCHAR(150) = (SELECT TOP 1 acv_modulo FROM [dbo].[Ayuda_Contenido_Vinculo] WHERE acv_contenido = @ID ORDER BY acv_orden)
    SELECT TOP 3 c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_descripcion, c.ayc_duracion, c.ayc_paginas, c.ayc_lectura, c.ayc_formato,
            c.ayc_estado, c.ayc_tema, @MOD AS MODULO,
            VISTAS_TOTAL = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'vista'),
            VALORACION = (SELECT CAST(AVG(CAST(a.ava_estrellas AS DECIMAL(4,2))) AS DECIMAL(3,1)) FROM [dbo].[Ayuda_Valoracion] a WHERE a.ava_contenido = c.ayc_id)
    FROM    [dbo].[Ayuda_Contenido] c
    WHERE   c.ayc_id <> @ID AND c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
      AND   EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id AND v.acv_modulo = @MOD)
      AND   [dbo].[FNC_AYUDA_VISIBLE](c.ayc_id, @USUARIO, @CLIENTE) = 1
    ORDER BY VISTAS_TOTAL DESC

    /* 7. Uso de los ultimos 30 dias */
    SELECT  VISTAS = SUM(CASE WHEN avs_tipo = 'vista' THEN 1 ELSE 0 END),
            UNICOS = COUNT(DISTINCT avs_usuario),
            DESCARGAS = SUM(CASE WHEN avs_tipo = 'descarga' THEN 1 ELSE 0 END),
            REPRODUCCIONES = SUM(CASE WHEN avs_tipo = 'reproduccion' THEN 1 ELSE 0 END),
            COMPLETOS = SUM(CASE WHEN avs_tipo = 'completo' THEN 1 ELSE 0 END),
            VALORACION = (SELECT CAST(AVG(CAST(a.ava_estrellas AS DECIMAL(4,2))) AS DECIMAL(3,1)) FROM [dbo].[Ayuda_Valoracion] a WHERE a.ava_contenido = @ID),
            EVITADOS = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket_Evitado] e WHERE e.stv_contenido = @ID AND e.stv_fecha >= @H30)
    FROM    [dbo].[Ayuda_Vista] WHERE avs_contenido = @ID AND avs_fecha >= @H30

    /* 8. Lo que esta persona ya dijo */
    SELECT ava_util, ava_estrellas FROM [dbo].[Ayuda_Valoracion] WHERE ava_contenido = @ID AND ava_usuario = @USUARIO
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_AYUDA_INTERACCION]
    @ID      INT,
    @USUARIO INT,
    @CLIENTE INT,
    @TIPO    VARCHAR(12),
    @ORIGEN  VARCHAR(20) = NULL
AS
SET NOCOUNT ON
    IF @TIPO NOT IN ('vista','descarga','reproduccion','completo') RETURN
    IF [dbo].[FNC_AYUDA_VISIBLE](@ID, @USUARIO, @CLIENTE) = 0 RETURN
    INSERT INTO [dbo].[Ayuda_Vista] (avs_contenido, avs_usuario, avs_cliente, avs_tipo, avs_origen)
    VALUES (@ID, @USUARIO, NULLIF(@CLIENTE, 0), @TIPO, LEFT(@ORIGEN, 20))
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_AYUDA_VALORACION]
    @ID        INT,
    @USUARIO   INT,
    @CLIENTE   INT,
    @UTIL      BIT,
    @ESTRELLAS INT = NULL
AS
SET NOCOUNT ON
    IF [dbo].[FNC_AYUDA_VISIBLE](@ID, @USUARIO, @CLIENTE) = 0
    BEGIN RAISERROR(N'Ese contenido no existe.', 16, 1) RETURN END
    IF @ESTRELLAS IS NULL OR @ESTRELLAS NOT BETWEEN 1 AND 5 SET @ESTRELLAS = CASE WHEN @UTIL = 1 THEN 5 ELSE 2 END

    MERGE [dbo].[Ayuda_Valoracion] AS t
    USING (SELECT @ID AS c, @USUARIO AS u) AS s ON t.ava_contenido = s.c AND t.ava_usuario = s.u
    WHEN MATCHED THEN UPDATE SET ava_util = @UTIL, ava_estrellas = @ESTRELLAS, ava_fecha = [dbo].[FNC_AHORA]()
    WHEN NOT MATCHED THEN INSERT (ava_contenido, ava_usuario, ava_util, ava_estrellas) VALUES (@ID, @USUARIO, @UTIL, @ESTRELLAS);
    SELECT 1 AS OK
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_AYUDA_BUSQUEDA]
    @TEXTO      NVARCHAR(200),
    @RESULTADOS INT,
    @USUARIO    INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON
    SET @TEXTO = LOWER(LTRIM(RTRIM(@TEXTO)))
    IF LEN(@TEXTO) < 3 RETURN
    /* Una persona escribiendo «ubic», «ubica», «ubicacion» es una sola
       busqueda: si la anterior de los ultimos 2 minutos es un prefijo, se
       reemplaza. */
    DELETE FROM [dbo].[Ayuda_Busqueda]
     WHERE abu_usuario = @USUARIO AND abu_fecha >= DATEADD(MINUTE, -2, [dbo].[FNC_AHORA]())
       AND @TEXTO LIKE abu_texto + N'%'
    INSERT INTO [dbo].[Ayuda_Busqueda] (abu_texto, abu_resultados, abu_usuario, abu_cliente)
    VALUES (LEFT(@TEXTO, 200), ISNULL(@RESULTADOS, 0), @USUARIO, NULLIF(@CLIENTE, 0))
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_SOPORTE_TICKET_EVITADO]
    @USUARIO   INT,
    @CLIENTE   INT,
    @CONTENIDO INT = NULL,
    @TITULO    NVARCHAR(200) = NULL,
    @MODULO    NVARCHAR(150) = NULL,
    @PANTALLA  NVARCHAR(150) = NULL
AS
SET NOCOUNT ON
    INSERT INTO [dbo].[Soporte_Ticket_Evitado] (stv_usuario, stv_cliente, stv_contenido, stv_titulo, stv_modulo, stv_pantalla)
    VALUES (@USUARIO, @CLIENTE, @CONTENIDO, LEFT(NULLIF(LTRIM(RTRIM(@TITULO)), ''), 200), @MODULO, @PANTALLA)
    SELECT SCOPE_IDENTITY() AS stv_id
GO


/* ========================================================================
   4. AYUDA CONTEXTUAL Y SUGERENCIA ANTES DEL TICKET
   ======================================================================== */

/* Hasta 3 contenidos para la pantalla donde esta la persona. Puntua cuantos
   niveles de la ruta coinciden en orden (modulo, submodulo, pantalla,
   seccion) y exige al menos dos —o uno si solo se conoce el modulo—. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_CONTEXTUAL]
    @USUARIO   INT,
    @CLIENTE   INT,
    @MODULO    NVARCHAR(150),
    @SUBMODULO NVARCHAR(150) = NULL,
    @PANTALLA  NVARCHAR(150) = NULL,
    @SECCION   NVARCHAR(150) = NULL
AS
SET NOCOUNT ON
    DECLARE @PROF INT = CASE WHEN @SECCION IS NOT NULL THEN 4 WHEN @PANTALLA IS NOT NULL THEN 3 WHEN @SUBMODULO IS NOT NULL THEN 2 ELSE 1 END
    DECLARE @MIN INT = CASE WHEN @PROF < 2 THEN @PROF ELSE 2 END

    ;WITH S AS (
        SELECT  v.acv_contenido,
                PUNTOS = MAX(CASE WHEN v.acv_modulo <> @MODULO THEN 0
                                  WHEN v.acv_submodulo IS NULL OR @SUBMODULO IS NULL OR v.acv_submodulo <> @SUBMODULO THEN 1
                                  WHEN v.acv_pantalla IS NULL OR @PANTALLA IS NULL OR v.acv_pantalla <> @PANTALLA THEN 2
                                  WHEN v.acv_seccion IS NULL OR @SECCION IS NULL OR v.acv_seccion <> @SECCION THEN 3
                                  ELSE 4 END)
        FROM    [dbo].[Ayuda_Contenido_Vinculo] v
        GROUP BY v.acv_contenido
    )
    SELECT TOP 3 c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_duracion, c.ayc_paginas, c.ayc_lectura, c.ayc_formato, S.PUNTOS
    FROM    S
    JOIN    [dbo].[Ayuda_Contenido] c ON c.ayc_id = S.acv_contenido
    WHERE   S.PUNTOS >= @MIN
      AND   c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
      AND   [dbo].[FNC_AYUDA_VISIBLE](c.ayc_id, @USUARIO, @CLIENTE) = 1
    ORDER BY S.PUNTOS DESC, (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id) DESC
GO

/* Lo que se le sugiere mientras escribe el reporte: palabras del titulo y
   la descripcion contra titulo, descripcion y ruta del contenido, sin
   acentos ni mayusculas; suma si es de la misma pantalla y mas si es la
   ayuda del problema recurrente de esa pantalla. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_SUGERENCIA]
    @USUARIO  INT,
    @CLIENTE  INT,
    @TEXTO    NVARCHAR(1000),
    @MODULO   NVARCHAR(150) = NULL,
    @PANTALLA NVARCHAR(150) = NULL
AS
SET NOCOUNT ON
    DECLARE @P TABLE (w NVARCHAR(60) COLLATE Latin1_General_CI_AI)
    INSERT INTO @P (w)
    SELECT DISTINCT LEFT(LTRIM(RTRIM(value)), CASE WHEN LEN(LTRIM(RTRIM(value))) > 5 THEN LEN(LTRIM(RTRIM(value))) - 1 ELSE 60 END)
      FROM STRING_SPLIT(TRANSLATE(LOWER(ISNULL(@TEXTO, '')), N'.,;:¿?¡!()«»"', N'             '), ' ')
     WHERE LEN(LTRIM(RTRIM(value))) > 3
       AND LTRIM(RTRIM(value)) COLLATE Latin1_General_CI_AI NOT IN (N'como', N'para', N'pero', N'tengo', N'puedo', N'sobre', N'desde',
                                                                     N'donde', N'cuando', N'porque', N'esta', N'este', N'esto', N'sale',
                                                                     N'hace', N'tiene', N'nada', N'algo')
    IF NOT EXISTS (SELECT 1 FROM @P) RETURN

    DECLARE @REC INT = (SELECT TOP 1 sre_contenido FROM [dbo].[Soporte_Recurrente]
                         WHERE sre_habilitado = 1 AND sre_modulo = @MODULO AND sre_pantalla = @PANTALLA AND sre_contenido IS NOT NULL)

    ;WITH C AS (
        SELECT  c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_duracion, c.ayc_paginas, c.ayc_lectura, c.ayc_formato,
                HAY = (c.ayc_titulo + N' ' + ISNULL(c.ayc_descripcion, N'') + N' ' +
                       ISNULL((SELECT STRING_AGG(CAST(v.acv_modulo + N' ' + ISNULL(v.acv_pantalla, N'') + N' ' + ISNULL(v.acv_seccion, N'') AS NVARCHAR(MAX)), ' ')
                                 FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id), N'')) COLLATE Latin1_General_CI_AI,
                MISMA = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id
                                            AND v.acv_modulo = @MODULO AND v.acv_pantalla = @PANTALLA) THEN 1 ELSE 0 END
        FROM    [dbo].[Ayuda_Contenido] c
        WHERE   c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
    )
    SELECT TOP 2 C.ayc_id, C.ayc_tipo, C.ayc_titulo, C.ayc_duracion, C.ayc_paginas, C.ayc_lectura, C.ayc_formato,
            PUNTOS = (SELECT COUNT(*) FROM @P p WHERE C.HAY LIKE N'%' + p.w + N'%') + C.MISMA + CASE WHEN C.ayc_id = @REC THEN 2 ELSE 0 END
    FROM    C
    WHERE   (SELECT COUNT(*) FROM @P p WHERE C.HAY LIKE N'%' + p.w + N'%') >= 1
      AND   [dbo].[FNC_AYUDA_VISIBLE](C.ayc_id, @USUARIO, @CLIENTE) = 1
    ORDER BY PUNTOS DESC, C.ayc_id DESC
GO


/* ========================================================================
   5. CREAR, EDITAR, VERSIONAR Y RESTAURAR (AYUDA ADMINISTRAR)
   ======================================================================== */

/* @DATOS: {"id":null,"tipo":"capsula","titulo":"...","descripcion":"...",
   "objetivo":"...","cuerpo":"...","formato":"MP4","duracion":"2:34",
   "paginas":null,"lectura":null,"archivo":123,"url":null,
   "estado":"Publicado","version":"v1.0","nota":"Primera versión.",
   "audiencia":"Todos los usuarios","condiciones":[...],"union":"AND",
   "tema":0,"recurrente":null,"pasos":[{"t":"...","m":"0:00"}],
   "recs":[{"t":"..."}],"vinculos":[{"m":"..","s":"..","p":"..","sec":".."}]} */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AYUDA_CONTENIDO]
    @USUARIO INT,
    @DATOS   NVARCHAR(MAX)
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para administrar el centro de ayuda.', 16, 1) RETURN END
    IF ISJSON(@DATOS) = 0 BEGIN RAISERROR(N'Datos no válidos.', 16, 1) RETURN END

    DECLARE @ID INT = TRY_CAST(JSON_VALUE(@DATOS, '$.id') AS INT)
    DECLARE @TITULO NVARCHAR(200) = LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.titulo')))
    DECLARE @TIPO VARCHAR(12) = JSON_VALUE(@DATOS, '$.tipo')
    DECLARE @ESTADO VARCHAR(12) = ISNULL(JSON_VALUE(@DATOS, '$.estado'), 'Borrador')
    DECLARE @VERSION VARCHAR(12) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.version'))), '')
    DECLARE @NOTA NVARCHAR(400) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.nota'))), '')
    DECLARE @COND NVARCHAR(MAX) = JSON_QUERY(@DATOS, '$.condiciones')
    DECLARE @REC INT = TRY_CAST(JSON_VALUE(@DATOS, '$.recurrente') AS INT)
    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    IF LEN(ISNULL(@TITULO, '')) < 3 BEGIN RAISERROR(N'Escribe un título de al menos 3 letras.', 16, 1) RETURN END
    IF @TIPO NOT IN ('capsula','video','manual','documento','guia','faq') BEGIN RAISERROR(N'Elige el tipo de contenido.', 16, 1) RETURN END
    IF @ESTADO NOT IN ('Publicado','Borrador','En revisión') SET @ESTADO = 'Borrador'
    IF @COND = '[]' SET @COND = NULL

    BEGIN TRAN
        IF @ID IS NULL
        BEGIN
            INSERT INTO [dbo].[Ayuda_Contenido] (ayc_tipo, ayc_titulo, ayc_estado, ayc_version, ayc_usuario_creacion)
            VALUES (@TIPO, @TITULO, @ESTADO, ISNULL(@VERSION, 'v1.0'), @USUARIO)
            SET @ID = SCOPE_IDENTITY()
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @ID AND ayc_habilitado = 1)
        BEGIN ROLLBACK RAISERROR(N'El contenido no existe.', 16, 1) RETURN END

        UPDATE [dbo].[Ayuda_Contenido]
           SET ayc_tipo = @TIPO, ayc_titulo = @TITULO,
               ayc_descripcion = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.descripcion'))), ''),
               ayc_objetivo = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.objetivo'))), ''),
               ayc_cuerpo = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.cuerpo'))), ''),
               ayc_formato = NULLIF(JSON_VALUE(@DATOS, '$.formato'), ''),
               ayc_duracion = NULLIF(JSON_VALUE(@DATOS, '$.duracion'), ''),
               ayc_paginas = TRY_CAST(JSON_VALUE(@DATOS, '$.paginas') AS INT),
               ayc_lectura = NULLIF(JSON_VALUE(@DATOS, '$.lectura'), ''),
               ayc_archivo = ISNULL(TRY_CAST(JSON_VALUE(@DATOS, '$.archivo') AS INT), ayc_archivo),
               ayc_url = NULLIF(LTRIM(RTRIM(JSON_VALUE(@DATOS, '$.url'))), ''),
               ayc_estado = @ESTADO,
               ayc_version = ISNULL(@VERSION, ayc_version),
               ayc_audiencia = NULLIF(JSON_VALUE(@DATOS, '$.audiencia'), ''),
               ayc_audiencia_condiciones = @COND,
               ayc_audiencia_union = CASE WHEN JSON_VALUE(@DATOS, '$.union') = 'OR' THEN 'OR' ELSE 'AND' END,
               ayc_tema = ISNULL(TRY_CAST(JSON_VALUE(@DATOS, '$.tema') AS INT), 0),
               ayc_recurrente = ISNULL(@REC, ayc_recurrente),
               ayc_usuario_actualizacion = @USUARIO,
               ayc_fecha_actualizacion = @AHORA
         WHERE ayc_id = @ID

        EXEC [dbo].[UPD_AYUDA_CONTENIDO_DETALLE] @ID, @DATOS

        /* Publicar deja la foto como version. */
        IF @ESTADO = 'Publicado'
            INSERT INTO [dbo].[Ayuda_Contenido_Version] (aver_contenido, aver_version, aver_nota, aver_estado, aver_archivo, aver_foto, aver_usuario)
            SELECT @ID, c.ayc_version, ISNULL(@NOTA, N'Publicación.'), c.ayc_estado, c.ayc_archivo, [dbo].[FNC_AYUDA_FOTO](@ID), @USUARIO
              FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_id = @ID

        /* Creada desde un problema recurrente: los tickets nuevos de esa
           pantalla la reciben como sugerencia. */
        IF @REC IS NOT NULL
            UPDATE [dbo].[Soporte_Recurrente] SET sre_contenido = @ID, sre_fecha_actualizacion = @AHORA WHERE sre_id = @REC
    COMMIT

    SELECT ayc_id, ayc_estado, ayc_version FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @ID
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_AYUDA_VERSION]
    @ID      INT,
    @USUARIO INT,
    @VERSION VARCHAR(12) = NULL,
    @NOTA    NVARCHAR(400) = NULL,
    @ARCHIVO INT = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para versionar contenido.', 16, 1) RETURN END
    DECLARE @ACT VARCHAR(12) = (SELECT ayc_version FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @ID AND ayc_habilitado = 1)
    IF @ACT IS NULL BEGIN RAISERROR(N'El contenido no existe.', 16, 1) RETURN END
    SET @VERSION = ISNULL(NULLIF(LTRIM(RTRIM(@VERSION)), ''), [dbo].[FNC_AYUDA_SIGUIENTE_VERSION](@ACT))
    IF EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Version] WHERE aver_contenido = @ID AND aver_version = @VERSION)
    BEGIN RAISERROR(N'Esa versión ya existe. Usa un número nuevo.', 16, 1) RETURN END

    BEGIN TRAN
        UPDATE [dbo].[Ayuda_Contenido]
           SET ayc_version = @VERSION, ayc_archivo = ISNULL(@ARCHIVO, ayc_archivo), ayc_estado = 'Publicado',
               ayc_usuario_actualizacion = @USUARIO, ayc_fecha_actualizacion = [dbo].[FNC_AHORA](),
               ayc_formato = CASE WHEN @ARCHIVO IS NULL THEN ayc_formato
                                  ELSE ISNULL(UPPER(REPLACE((SELECT arc_extension FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO), '.', '')), ayc_formato) END
         WHERE ayc_id = @ID
        INSERT INTO [dbo].[Ayuda_Contenido_Version] (aver_contenido, aver_version, aver_nota, aver_estado, aver_archivo, aver_foto, aver_usuario)
        SELECT @ID, @VERSION, ISNULL(NULLIF(LTRIM(RTRIM(@NOTA)), ''), N'Actualización'), 'Publicado', c.ayc_archivo, [dbo].[FNC_AYUDA_FOTO](@ID), @USUARIO
          FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_id = @ID
    COMMIT

    SELECT @ID AS ayc_id, @VERSION AS ayc_version
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_AYUDA_RESTAURAR]
    @VERSION_ID INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para restaurar versiones.', 16, 1) RETURN END

    DECLARE @ID INT, @FOTO NVARCHAR(MAX), @V VARCHAR(12), @ARCH INT
    SELECT @ID = aver_contenido, @FOTO = aver_foto, @V = aver_version, @ARCH = aver_archivo
      FROM [dbo].[Ayuda_Contenido_Version] WHERE aver_id = @VERSION_ID
    IF @ID IS NULL BEGIN RAISERROR(N'La versión no existe.', 16, 1) RETURN END

    DECLARE @NUEVA VARCHAR(12) = [dbo].[FNC_AYUDA_SIGUIENTE_VERSION]((SELECT ayc_version FROM [dbo].[Ayuda_Contenido] WHERE ayc_id = @ID))
    WHILE EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Version] WHERE aver_contenido = @ID AND aver_version = @NUEVA)
        SET @NUEVA = [dbo].[FNC_AYUDA_SIGUIENTE_VERSION](@NUEVA)

    BEGIN TRAN
        UPDATE [dbo].[Ayuda_Contenido]
           SET ayc_tipo = ISNULL(JSON_VALUE(@FOTO, '$.tipo'), ayc_tipo),
               ayc_titulo = ISNULL(JSON_VALUE(@FOTO, '$.titulo'), ayc_titulo),
               ayc_descripcion = JSON_VALUE(@FOTO, '$.descripcion'),
               ayc_objetivo = JSON_VALUE(@FOTO, '$.objetivo'),
               ayc_cuerpo = JSON_VALUE(@FOTO, '$.cuerpo'),
               ayc_formato = JSON_VALUE(@FOTO, '$.formato'),
               ayc_duracion = JSON_VALUE(@FOTO, '$.duracion'),
               ayc_paginas = TRY_CAST(JSON_VALUE(@FOTO, '$.paginas') AS INT),
               ayc_lectura = JSON_VALUE(@FOTO, '$.lectura'),
               ayc_archivo = @ARCH,
               ayc_url = JSON_VALUE(@FOTO, '$.url'),
               ayc_audiencia = JSON_VALUE(@FOTO, '$.audiencia'),
               ayc_audiencia_condiciones = JSON_VALUE(@FOTO, '$.condiciones'),
               ayc_audiencia_union = ISNULL(JSON_VALUE(@FOTO, '$.union'), 'AND'),
               ayc_estado = 'Publicado', ayc_version = @NUEVA,
               ayc_usuario_actualizacion = @USUARIO, ayc_fecha_actualizacion = [dbo].[FNC_AHORA]()
         WHERE ayc_id = @ID

        /* La foto guarda pasos/recs con la clave «t»; el detalle los lee igual. */
        EXEC [dbo].[UPD_AYUDA_CONTENIDO_DETALLE] @ID, @FOTO

        INSERT INTO [dbo].[Ayuda_Contenido_Version] (aver_contenido, aver_version, aver_nota, aver_estado, aver_archivo, aver_foto, aver_usuario)
        VALUES (@ID, @NUEVA, N'Restaurada desde ' + @V, 'Publicado', @ARCH, [dbo].[FNC_AYUDA_FOTO](@ID), @USUARIO)
    COMMIT

    SELECT @ID AS ayc_id, @NUEVA AS ayc_version
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_AYUDA_CONTENIDO_ESTADO]
    @ID      INT,
    @USUARIO INT,
    @ESTADO  VARCHAR(12)
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para cambiar el estado.', 16, 1) RETURN END
    IF @ESTADO NOT IN ('Publicado','Borrador','En revisión','Archivado') BEGIN RAISERROR(N'Estado no válido.', 16, 1) RETURN END

    UPDATE [dbo].[Ayuda_Contenido] SET ayc_estado = @ESTADO, ayc_usuario_actualizacion = @USUARIO, ayc_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE ayc_id = @ID AND ayc_habilitado = 1
    IF @ESTADO = 'Publicado'
        INSERT INTO [dbo].[Ayuda_Contenido_Version] (aver_contenido, aver_version, aver_nota, aver_estado, aver_archivo, aver_foto, aver_usuario)
        SELECT @ID, c.ayc_version, N'Publicación.', 'Publicado', c.ayc_archivo, [dbo].[FNC_AYUDA_FOTO](@ID), @USUARIO
          FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_id = @ID
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Version] x WHERE x.aver_contenido = @ID AND x.aver_version = c.ayc_version)
    SELECT @ID AS ayc_id
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_AYUDA_CATEGORIA]
    @ID      INT = NULL,
    @USUARIO INT,
    @NOMBRE  NVARCHAR(100),
    @MODULO  NVARCHAR(150),
    @ICONO   VARCHAR(20) = 'folder',
    @TONO    VARCHAR(10) = 'p'
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para administrar categorías.', 16, 1) RETURN END
    SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))
    IF ISNULL(@NOMBRE, '') = '' OR ISNULL(@MODULO, '') = '' BEGIN RAISERROR(N'Escribe el nombre y elige el módulo.', 16, 1) RETURN END

    IF @ID IS NULL
    BEGIN
        INSERT INTO [dbo].[Ayuda_Categoria] (aca_nombre, aca_modulo, aca_icono, aca_tono, aca_orden)
        VALUES (@NOMBRE, @MODULO, ISNULL(@ICONO, 'folder'), ISNULL(@TONO, 'p'), (SELECT ISNULL(MAX(aca_orden), 0) + 1 FROM [dbo].[Ayuda_Categoria]))
        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
        UPDATE [dbo].[Ayuda_Categoria] SET aca_nombre = @NOMBRE, aca_modulo = @MODULO, aca_icono = ISNULL(@ICONO, aca_icono), aca_tono = ISNULL(@TONO, aca_tono)
         WHERE aca_id = @ID
    SELECT @ID AS aca_id
GO


/* ========================================================================
   6. ANALITICA DEL CENTRO DE AYUDA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_AYUDA_ANALITICA]
    @USUARIO INT,
    @DIAS    INT = 30
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'SOPORTE ANALITICA') = 0
    BEGIN RAISERROR(N'No tienes acceso a la analítica.', 16, 1) RETURN END
    IF @DIAS NOT IN (7, 30, 90) SET @DIAS = 30

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @DESDE DATETIME = DATEADD(DAY, -@DIAS, CAST(@AHORA AS DATE)), @PREV DATETIME = DATEADD(DAY, -2 * @DIAS, CAST(@AHORA AS DATE))

    /* 1. Indicadores */
    SELECT  VISTAS = SUM(CASE WHEN avs_tipo = 'vista' AND avs_fecha >= @DESDE THEN 1 ELSE 0 END),
            VISTAS_PREV = SUM(CASE WHEN avs_tipo = 'vista' AND avs_fecha >= @PREV AND avs_fecha < @DESDE THEN 1 ELSE 0 END),
            UNICOS = COUNT(DISTINCT CASE WHEN avs_fecha >= @DESDE THEN avs_usuario END),
            DESCARGAS = SUM(CASE WHEN avs_tipo = 'descarga' AND avs_fecha >= @DESDE THEN 1 ELSE 0 END),
            REPRODUCCIONES = SUM(CASE WHEN avs_tipo = 'reproduccion' AND avs_fecha >= @DESDE THEN 1 ELSE 0 END),
            COMPLETOS = SUM(CASE WHEN avs_tipo = 'completo' AND avs_fecha >= @DESDE THEN 1 ELSE 0 END),
            VALORACION = (SELECT CAST(AVG(CAST(ava_estrellas AS DECIMAL(4,2))) AS DECIMAL(3,1)) FROM [dbo].[Ayuda_Valoracion]),
            VALORACIONES = (SELECT COUNT(*) FROM [dbo].[Ayuda_Valoracion]),
            EVITADOS = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket_Evitado] WHERE stv_fecha >= @DESDE),
            /* Reportes iniciados = los que no se crearon + los que se crearon. */
            TICKETS = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] WHERE stk_habilitado = 1 AND stk_fecha_creacion >= @DESDE)
    FROM    [dbo].[Ayuda_Vista]

    /* 2. Vistas por dia */
    ;WITH D AS (SELECT TOP (@DIAS) DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - @DIAS, CAST(@AHORA AS DATE)) AS dia FROM sys.all_objects)
    SELECT D.dia, N = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_tipo = 'vista' AND CAST(w.avs_fecha AS DATE) = D.dia)
    FROM D ORDER BY D.dia

    /* 3. La ayuda que evito tickets */
    SELECT TOP 5 c.ayc_id, c.ayc_titulo, COUNT(*) AS N
    FROM [dbo].[Soporte_Ticket_Evitado] e JOIN [dbo].[Ayuda_Contenido] c ON c.ayc_id = e.stv_contenido
    WHERE e.stv_fecha >= @DESDE
    GROUP BY c.ayc_id, c.ayc_titulo ORDER BY COUNT(*) DESC

    /* 4. Busquedas sin resultados */
    SELECT TOP 6 abu_texto, COUNT(*) AS N
    FROM [dbo].[Ayuda_Busqueda] WHERE abu_resultados = 0 AND abu_fecha >= @DESDE
    GROUP BY abu_texto ORDER BY COUNT(*) DESC
GO
