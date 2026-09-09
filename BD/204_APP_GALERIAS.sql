USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LAS FOTOS CON SU FICHA, PARA LAS GALERIAS 7.4 Y 10.4.
-- =============================================
-- POR QUE NO BASTABA CON LO QUE HABIA
--
--   `API_SEL_ACTIVO_FOTO` devolvia ruta, mime, nombre y si era portada. Sirve
--   para pintar la portada de una ficha y no sirve para una galeria: la
--   pregunta que se le hace a una galeria no es «que fotos hay» sino **«como
--   estaba esto en marzo»**, y esa no se puede responder sin la fecha y sin
--   quien la tomo.
--
--   Se le agregan tres columnas al SP que ya existe en vez de crear uno
--   nuevo: es un SP `API_`, lo consume solo la app, y dos consultas que
--   devuelven las fotos del mismo activo terminarian divergiendo.
--
--   Y se crea el gemelo que faltaba para el repuesto (vista 10.4).
--
-- LA FECHA ES LA DE CAPTURA, NO LA DE SUBIDA
--
--   `arc_fecha_captura_utc` es cuando se tomo la foto; `arc_fecha_creacion`
--   es cuando llego al servidor. En terreno se separan por horas o dias -se
--   fotografia sin señal y se sube al volver-, y ordenar una galeria por la
--   segunda cuenta la historia en el orden equivocado. Se usa la de captura
--   con la de creacion como respaldo, que es lo unico que hay cuando la foto
--   vino de la web.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) API_SEL_ACTIVO_FOTO — ahora con quien, cuando y que dice
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ACTIVO_FOTO]
@ACTIVO  INT,
@CLIENTE INT
AS
SET NOCOUNT ON

    /* El cliente se valida contra el activo y no solo contra el archivo: un
       archivo del mismo cliente colgado de OTRO activo no es foto de este. */
    SELECT      a.arc_ruta              AS ARC_RUTA,
                a.arc_mime              AS ARC_MIME,
                a.arc_nombre_original   AS ARC_NOMBRE,
                v.avi_es_referencia     AS ES_PORTADA,
                v.avi_descripcion       AS DESCRIPCION,
                ISNULL(a.arc_fecha_captura_utc, a.arc_fecha_creacion) AS FECHA_CAPTURA_UTC,
                LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' +
                            ISNULL(u.usu_apellido_paterno, N''))) AS AUTOR_NOMBRE
    FROM        [dbo].[Archivo_Vinculo] v
    INNER JOIN  [dbo].[Archivo]         a   ON a.arc_id  = v.avi_archivo
    INNER JOIN  [dbo].[Activo]          act ON act.act_id = v.avi_activo
    LEFT  JOIN  [dbo].[Usuario]         u   ON u.usu_id  = a.arc_usuario_creacion
    WHERE       v.avi_activo        = @ACTIVO
      AND       v.avi_habilitado    = 1
      AND       a.arc_habilitado    = 1
      AND       a.arc_cliente       = @CLIENTE
      AND       act.act_cliente     = @CLIENTE
      /* Solo imagenes: un PDF de manual colgado del mismo activo no se puede
         dibujar en una miniatura, y pedirlo seria bajar megabytes para nada. */
      AND       a.arc_mime LIKE 'image/%'
      AND       LTRIM(RTRIM(ISNULL(a.arc_ruta, ''))) <> ''
    ORDER BY    v.avi_es_referencia DESC,
                ISNULL(v.avi_orden, 0),
                a.arc_id
GO

-- ---------------------------------------------------------------------------
-- 2) API_SEL_REPUESTO_FOTO — el que faltaba (vista 10.4)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_REPUESTO_FOTO]
@REPUESTO INT,
@CLIENTE  INT
AS
SET NOCOUNT ON

    SELECT      a.arc_ruta              AS ARC_RUTA,
                a.arc_mime              AS ARC_MIME,
                a.arc_nombre_original   AS ARC_NOMBRE,
                v.avi_es_referencia     AS ES_PORTADA,
                v.avi_descripcion       AS DESCRIPCION,
                ISNULL(a.arc_fecha_captura_utc, a.arc_fecha_creacion) AS FECHA_CAPTURA_UTC,
                LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' +
                            ISNULL(u.usu_apellido_paterno, N''))) AS AUTOR_NOMBRE
    FROM        [dbo].[Archivo_Vinculo] v
    INNER JOIN  [dbo].[Archivo]         a   ON a.arc_id  = v.avi_archivo
    INNER JOIN  [dbo].[Repuesto]        rep ON rep.rep_id = v.avi_repuesto
    LEFT  JOIN  [dbo].[Usuario]         u   ON u.usu_id  = a.arc_usuario_creacion
    WHERE       v.avi_repuesto      = @REPUESTO
      AND       v.avi_habilitado    = 1
      AND       a.arc_habilitado    = 1
      AND       a.arc_cliente       = @CLIENTE
      AND       rep.rep_cliente     = @CLIENTE
      AND       a.arc_mime LIKE 'image/%'
      AND       LTRIM(RTRIM(ISNULL(a.arc_ruta, ''))) <> ''
    ORDER BY    v.avi_es_referencia DESC,
                ISNULL(v.avi_orden, 0),
                a.arc_id
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'API_SEL_ACTIVO_FOTO devuelve ' +
       CAST((SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set(
                N'EXEC [dbo].[API_SEL_ACTIVO_FOTO] @ACTIVO=1, @CLIENTE=1', NULL, 0)) AS VARCHAR) +
       ' columnas (antes 4)' AS RESULTADO
UNION ALL
SELECT 'API_SEL_REPUESTO_FOTO = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_SEL_REPUESTO_FOTO]') IS NULL THEN 'FALTA' ELSE 'OK' END
GO
