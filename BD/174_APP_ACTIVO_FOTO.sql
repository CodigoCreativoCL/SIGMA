USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LA RUTA DE BLOB DE LAS FOTOS DE UN ACTIVO, PARA LA APP.
-- =============================================
-- POR QUE HIZO FALTA
--
--   La app pinta las fotos pidiendolas por su RUTA de blob
--   (`GET /archivo/ver?ruta=`). Ningun SP se la daba:
--
--     SEL_ACTIVO          -> no trae nada de Archivo.
--     SEL_ACTIVO_IMAGEN   -> devuelve ARC_ID, ARC_UUID, ARC_MIME y ARC_NOMBRE.
--     SEL_ACTIVO_ARCHIVO  -> lo mismo, para los documentos.
--
--   Los tres sirven a la web, que resuelve el archivo por su id contra
--   VerArchivo.aspx. La app no tiene esa pagina: necesita la ruta. Por eso
--   los activos se veian SIN foto teniendola cargada — el telefono nunca
--   recibio donde estaba.
--
-- POR QUE UN SP NUEVO Y NO UN CAMPO MAS EN SEL_ACTIVO
--
--   SEL_ACTIVO arma su consulta con SQL dinamico y lo usan el listado y la
--   ficha de la web. Meterle un JOIN a Archivo_Vinculo le agrega trabajo a
--   toda pantalla que liste activos, para un dato que solo mira la ficha.
--
-- POR QUE DEVUELVE LA PORTADA Y LA GALERIA JUNTAS
--
--   La ficha de la app muestra una foto grande y una tira de miniaturas. En
--   dos llamadas, la tira aparece despues que la portada y la pantalla salta.
--   ES_PORTADA distingue cual es cual: la de referencia va primera.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   API_SEL_ACTIVO_FOTO - las fotos de un activo, con su ruta de blob
   ======================================================================== */
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
                v.avi_es_referencia     AS ES_PORTADA
    FROM        [dbo].[Archivo_Vinculo] v
    INNER JOIN  [dbo].[Archivo]         a   ON a.arc_id  = v.avi_archivo
    INNER JOIN  [dbo].[Activo]          act ON act.act_id = v.avi_activo
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


/* ========================================================================
   API_SEL_ARCHIVO_RUTA - ¿esta ruta de blob es de este cliente?

   POR QUE EXISTE

     `GET /archivo/ver?ruta=` se abrio al token de sesion para que la app
     pueda dibujar las fotos (antes exigia la clave de servicio y respondia
     401 a cada imagen). Pero la ruta es texto libre que manda el cliente:
     sin esta comprobacion, un tecnico de una empresa podria leer los
     archivos de otra escribiendo la ruta a mano.

     La regla es simple y no admite excepcion: con token de sesion solo se
     entrega un blob que este REGISTRADO en Archivo a nombre del cliente que
     lleva el token. Lo que no esta en la tabla no se sirve — aunque exista
     en el contenedor.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ARCHIVO_RUTA]
@RUTA    NVARCHAR(500),
@CLIENTE INT
AS
SET NOCOUNT ON

    SELECT TOP 1
                a.arc_id      AS ARC_ID,
                a.arc_ruta    AS ARC_RUTA,
                a.arc_mime    AS ARC_MIME
    FROM        [dbo].[Archivo] a
    WHERE       a.arc_ruta      = @RUTA
      AND       a.arc_cliente   = @CLIENTE
      AND       a.arc_habilitado = 1
GO
