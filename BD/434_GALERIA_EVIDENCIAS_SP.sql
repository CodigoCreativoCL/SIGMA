/* ============================================================================
   434 · Galería de evidencias: SEL_ARCHIVO_VINCULO (10-10-2026)
   HU-142 (T-5251) y la distinción de HU-143 (criterio 3). Autora: Catalina Pescio.

   Un solo SP para las dos galerías de la historia. Se elige por parámetro:
     · @ORDEN_TRABAJO → criterio 1: las fotos de la orden y de todos sus pasos,
       agrupadas por paso y por momento (Antes, Durante, Después, otras).
     · @ACTIVO        → criterio 2: las fotos de TODAS las órdenes del equipo,
       de la más nueva a la más antigua. Sale por Orden_Trabajo.otr_activo, no por
       avi_activo: CK_AVI_UN_PADRE no deja que una foto de OT traiga el activo, y
       avi_activo son las fotos de catálogo (BD/433).
   Si llegan los dos, manda la orden. Si no llega ninguno, no devuelve filas.

   Lo que la galería deja fuera, aquí y no en la pantalla:
     · La FIRMA (categoría 8): es respaldo del cierre, no evidencia; la ficha de la
       orden ya la separaba (WsOrdenes, ES_FIRMA).
     · Vínculos o archivos deshabilitados, y archivos de otro cliente.

   Las imágenes de REFERENCIA (HU-143) vienen en las mismas filas con
   ES_REFERENCIA = 1 y ordenadas primero, para que la pantalla las muestre en su
   propio bloque: son las adjuntas a la actividad del plan de la que nació cada
   paso (Orden_Trabajo_Paso.otp_plan_mantenimiento_actividad). Se reconocen por ese
   destino, no por avi_es_referencia ni por la categoría 10, que también se usan
   para el catálogo (ver Trampas en el MD de estado). Una referencia es de la
   ACTIVIDAD, no del paso: sale una sola vez aunque varios pasos (o varias órdenes)
   nazcan de la misma actividad, con ACTIVIDAD_NOMBRE y MOMENTO = 'REFERENCIA'.
   Las evidencias también traen ACTIVIDAD_ID / ACTIVIDAD_NOMBRE de su paso.

   Filtros opcionales: @MOMENTO ('ANTES' | 'DURANTE' | 'DESPUES' | 'OTRO' | 'REFERENCIA'),
   @SOLO_IMAGENES y @INCLUIR_REFERENCIAS. Paginación con @PAGINA (desde 1) y
   @TAMANO (60 por omisión, tope 200); TOTAL trae el total sin paginar.
   FECHA es la hora de captura pasada a la hora de la planta y, si el teléfono no
   la mandó, la de creación del archivo (que ya está en esa hora, FNC_AHORA).
   Sin SQL dinámico: todo por parámetros. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_ARCHIVO_VINCULO]
    @CLIENTE             INT,
    @ORDEN_TRABAJO       INT          = NULL,
    @ACTIVO              INT          = NULL,
    @MOMENTO             VARCHAR(10)  = NULL,
    @SOLO_IMAGENES       BIT          = 0,
    @INCLUIR_REFERENCIAS BIT          = 1,
    @PAGINA              INT          = 1,
    @TAMANO              INT          = 60
AS
SET NOCOUNT ON
DECLARE @MIN INT = DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]())
IF @ORDEN_TRABAJO IS NOT NULL SET @ACTIVO = NULL
SET @PAGINA = CASE WHEN ISNULL(@PAGINA, 1) < 1 THEN 1 ELSE @PAGINA END
SET @TAMANO = CASE WHEN ISNULL(@TAMANO, 60) < 1 THEN 60 WHEN @TAMANO > 200 THEN 200 ELSE @TAMANO END

/* Las órdenes que entran en la galería, ya filtradas por cliente. */
DECLARE @OT TABLE (ot INT PRIMARY KEY)
INSERT @OT
SELECT o.otr_id FROM [dbo].[Orden_Trabajo] o
WHERE  o.otr_cliente = @CLIENTE
  AND  ((@ORDEN_TRABAJO IS NOT NULL AND o.otr_id = @ORDEN_TRABAJO)
     OR (@ACTIVO IS NOT NULL AND o.otr_activo = @ACTIVO));

WITH ev AS (
    /* Evidencias de terreno: en la orden o en uno de sus pasos. */
    SELECT  avi.avi_id, avi.avi_archivo, avi.avi_orden, avi.avi_titulo, avi.avi_descripcion,
            ISNULL(avi.avi_orden_trabajo, otp.otp_orden_trabajo) AS OT_ID,
            otp.otp_id AS PASO_ID, otp.otp_orden AS PASO_ORDEN, otp.otp_nombre AS PASO_NOMBRE,
            otp.otp_plan_mantenimiento_actividad AS ACTIVIDAD_ID,
            CAST(0 AS BIT) AS ES_REFERENCIA
    FROM    [dbo].[Archivo_Vinculo] avi
    LEFT JOIN [dbo].[Orden_Trabajo_Paso] otp ON otp.otp_id = avi.avi_orden_trabajo_paso
    WHERE   avi.avi_habilitado = 1
      AND   (avi.avi_orden_trabajo IN (SELECT ot FROM @OT)
             OR otp.otp_orden_trabajo IN (SELECT ot FROM @OT))
    UNION ALL
    /* Referencias: las de la actividad del plan de la que nació algún paso de estas
       órdenes. Una vez por vínculo: son de la actividad, no de cada paso. */
    SELECT  avi.avi_id, avi.avi_archivo, avi.avi_orden, avi.avi_titulo, avi.avi_descripcion,
            NULL, NULL, NULL, NULL, avi.avi_plan_mantenimiento_actividad, CAST(1 AS BIT)
    FROM    [dbo].[Archivo_Vinculo] avi
    WHERE   @INCLUIR_REFERENCIAS = 1
      AND   avi.avi_habilitado = 1
      AND   avi.avi_plan_mantenimiento_actividad IN
            (SELECT otp.otp_plan_mantenimiento_actividad FROM [dbo].[Orden_Trabajo_Paso] otp
              WHERE otp.otp_orden_trabajo IN (SELECT ot FROM @OT) AND otp.otp_habilitado = 1)
),
fi AS (
    SELECT  ev.*, arc.arc_id, arc.arc_nombre_original, ISNULL(arc.arc_mime, '') AS arc_mime, ISNULL(arc.arc_byte, 0) AS arc_byte,
            ISNULL(DATEADD(MINUTE, @MIN, arc.arc_fecha_captura_utc), arc.arc_fecha_creacion) AS FECHA,
            arc.arc_usuario_creacion, aca.aca_codigo, aca.aca_nombre,
            CASE WHEN ev.ES_REFERENCIA = 1 THEN 'REFERENCIA'
                 ELSE CASE aca.aca_codigo WHEN 'ANTES' THEN 'ANTES' WHEN 'DURANTE' THEN 'DURANTE' WHEN 'DESPUES' THEN 'DESPUES' ELSE 'OTRO' END END AS MOMENTO,
            CASE WHEN ev.ES_REFERENCIA = 1 THEN 0
                 ELSE CASE aca.aca_codigo WHEN 'ANTES' THEN 1 WHEN 'DURANTE' THEN 2 WHEN 'DESPUES' THEN 3 ELSE 4 END END AS MOMENTO_ORDEN,
            paa.paa_nombre AS ACTIVIDAD_NOMBRE
    FROM    ev
    JOIN    [dbo].[Archivo] arc ON arc.arc_id = ev.avi_archivo
    LEFT JOIN [dbo].[Archivo_Categoria] aca ON aca.aca_id = arc.arc_archivo_categoria
    LEFT JOIN [dbo].[Plan_Mantenimiento_Actividad] paa ON paa.paa_id = ev.ACTIVIDAD_ID
    WHERE   arc.arc_cliente = @CLIENTE
      AND   arc.arc_habilitado = 1
      AND   ISNULL(aca.aca_codigo, '') <> 'FIRMA'
)
SELECT  fi.arc_id                                   AS ARCHIVO_ID,
        fi.avi_id                                   AS VINCULO_ID,
        fi.arc_nombre_original                      AS NOMBRE,
        ISNULL(NULLIF(fi.avi_titulo, N''), fi.arc_nombre_original) AS TITULO,
        ISNULL(fi.avi_descripcion, N'')             AS DESCRIPCION,
        fi.arc_mime                                 AS MIME,
        fi.arc_byte                                 AS BYTES,
        fi.FECHA,
        fi.MOMENTO,
        fi.MOMENTO_ORDEN,
        ISNULL(fi.aca_codigo, '')                   AS CATEGORIA_CODIGO,
        ISNULL(fi.aca_nombre, N'')                  AS CATEGORIA_NOMBRE,
        fi.ES_REFERENCIA,
        fi.OT_ID,
        o.otr_correlativo                           AS OT_NUMERO,
        o.otr_titulo                                AS OT_TITULO,
        fi.PASO_ID,
        fi.PASO_ORDEN,
        fi.PASO_NOMBRE,
        fi.ACTIVIDAD_ID,
        fi.ACTIVIDAD_NOMBRE,
        ISNULL([dbo].[FNC_NOMBRE_USUARIO_SIMPLE](fi.arc_usuario_creacion), N'') AS QUIEN,
        CAST(CASE WHEN fi.arc_mime LIKE 'image/%' THEN 1 ELSE 0 END AS BIT) AS ES_IMAGEN,
        CAST(CASE WHEN fi.arc_mime LIKE 'video/%' THEN 1 ELSE 0 END AS BIT) AS ES_VIDEO,
        CAST(CASE WHEN fi.arc_mime LIKE 'audio/%' THEN 1 ELSE 0 END AS BIT) AS ES_AUDIO,
        COUNT(*) OVER ()                            AS TOTAL
FROM    fi
LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = fi.OT_ID
WHERE   (@MOMENTO IS NULL OR fi.MOMENTO = @MOMENTO)
  AND   (ISNULL(@SOLO_IMAGENES, 0) = 0 OR fi.arc_mime LIKE 'image/%')
ORDER BY fi.ES_REFERENCIA DESC,
         /* Orden: por paso (lo de la orden sin paso, primero) y momento. Equipo: lo más nuevo arriba. */
         CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN ISNULL(fi.PASO_ORDEN, 0) END,
         CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN fi.MOMENTO_ORDEN END,
         CASE WHEN @ORDEN_TRABAJO IS NULL THEN fi.FECHA END DESC,
         fi.OT_ID DESC, ISNULL(fi.PASO_ORDEN, 0), fi.MOMENTO_ORDEN, fi.avi_orden, fi.arc_id
OFFSET (@PAGINA - 1) * @TAMANO ROWS FETCH NEXT @TAMANO ROWS ONLY
RETURN 0
GO
PRINT '434_GALERIA_EVIDENCIAS_SP aplicado.'
GO
