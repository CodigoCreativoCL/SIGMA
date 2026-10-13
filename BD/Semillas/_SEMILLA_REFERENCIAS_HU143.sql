/* ============================================================================
   Semilla · Imágenes de referencia (HU-143, T-5266) · 12-10-2026 · Catalina Pescio
   Datos de PRUEBA para ejercitar los criterios de aceptación. No va a producción.

   Qué deja (cliente 1, Hamburgo), con dos archivos PRUEBA_HU143_* de categoría 10
   (REFERENCIA) que reutilizan blobs de la semilla de HU-142 (se ven en VerArchivo):
     · Plan 1 «Preventivo Dosificadoras»: una referencia en su primera actividad de
       la versión PUBLICADA (la ven los pasos de las OT que ya nacieron de ella) y la
       misma en su gemela del BORRADOR, si existe (la que muestra la ficha).
       → Criterio 1: el técnico la ve en el paso de la OT, marcada como referencia.
     · Pauta 1 (PAU-001): una referencia en su primer ítem, en la versión publicada
       y en el borrador si existe.
       → Criterio 2: se muestra junto a la pregunta en la inspección de Operación.
   Se reconocen por arc_nombre_original LIKE 'PRUEBA_HU143_%'. Para quitarlas, el
   bloque comentado del final. Idempotente: si ya están, no hace nada.
   Aplicar con -I (Archivo_Vinculo tiene índices filtrados).
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO
IF EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original LIKE N'PRUEBA[_]HU143[_]%')
BEGIN
    PRINT 'Semilla de referencias ya cargada: no se hace nada.'
    RETURN
END

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @F1 INT, @F2 INT

BEGIN TRANSACTION
    INSERT INTO [dbo].[Archivo] (arc_uuid, arc_cliente, arc_archivo_categoria, arc_nombre_original, arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
                                 arc_ancho_pixel, arc_alto_pixel, arc_hash, arc_archivo_antivirus_estado, arc_usuario_creacion, arc_fecha_creacion, arc_habilitado)
    SELECT NEWID(), 1, 10, N'PRUEBA_HU143_01' + ISNULL(arc_extension, N'.jpg'), arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
           arc_ancho_pixel, arc_alto_pixel, arc_hash, arc_archivo_antivirus_estado, 1, @AHORA, 1
    FROM   [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original = N'PRUEBA_HU142_12.jpg'
    SET @F1 = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Archivo] (arc_uuid, arc_cliente, arc_archivo_categoria, arc_nombre_original, arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
                                 arc_ancho_pixel, arc_alto_pixel, arc_hash, arc_archivo_antivirus_estado, arc_usuario_creacion, arc_fecha_creacion, arc_habilitado)
    SELECT NEWID(), 1, 10, N'PRUEBA_HU143_02' + ISNULL(arc_extension, N'.jpg'), arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
           arc_ancho_pixel, arc_alto_pixel, arc_hash, arc_archivo_antivirus_estado, 1, @AHORA, 1
    FROM   [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original = N'PRUEBA_HU142_09.jpg'
    SET @F2 = SCOPE_IDENTITY()

    IF @F1 IS NULL OR @F2 IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('Falta la semilla de HU-142 (BD/Semillas/_SEMILLA_GALERIA_EVIDENCIAS.sql): de ahí salen las fotos.', 16, 1)
        RETURN
    END

    /* Plan 1: primera actividad de la versión publicada y su gemela (mismo hito y código) en el borrador */
    ;WITH act AS (
        SELECT a.paa_id, a.paa_codigo, h.pmh_codigo, v.pmv_plan_version_estado,
               ROW_NUMBER() OVER (PARTITION BY v.pmv_id ORDER BY h.pmh_orden, a.paa_orden, a.paa_id) AS n
        FROM   [dbo].[Plan_Mantenimiento_Actividad] a
        JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
        JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
        WHERE  v.pmv_plan_mantenimiento = 1 AND v.pmv_plan_version_estado IN (1, 2) AND v.pmv_habilitado = 1 AND a.paa_habilitado = 1
    ), pub AS (SELECT TOP 1 * FROM act WHERE pmv_plan_version_estado = 2 AND n = 1)
    INSERT INTO [dbo].[Archivo_Vinculo] (avi_archivo, avi_plan_mantenimiento_actividad, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo, avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    SELECT @F1, a.paa_id, 1, 1, 1, N'Así debe quedar: dosificador limpio y conexiones apretadas', 1, @AHORA, 1
    FROM   act a JOIN pub p ON p.pmh_codigo = a.pmh_codigo AND p.paa_codigo = a.paa_codigo

    /* Pauta 1: primer ítem de la publicada y su gemelo (mismo código) en el borrador */
    ;WITH itm AS (
        SELECT TOP 1 i.cpi_codigo
        FROM   [dbo].[Checklist_Plantilla_Item] i JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
        WHERE  v.cpv_checklist_plantilla = 1 AND v.cpv_checklist_version_estado = 2 AND v.cpv_habilitado = 1 AND i.cpi_habilitado = 1
        ORDER BY v.cpv_numero DESC, i.cpi_orden
    )
    INSERT INTO [dbo].[Archivo_Vinculo] (avi_archivo, avi_checklist_plantilla_item, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo, avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    SELECT @F2, i.cpi_id, 1, 1, 1, N'Referencia: así se ve la bomba en buen estado', 1, @AHORA, 1
    FROM   [dbo].[Checklist_Plantilla_Item] i
    JOIN   [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
    JOIN   itm ON itm.cpi_codigo = i.cpi_codigo
    WHERE  v.cpv_checklist_plantilla = 1 AND v.cpv_checklist_version_estado IN (1, 2) AND v.cpv_habilitado = 1 AND i.cpi_habilitado = 1
COMMIT TRANSACTION

SELECT 'Referencias de prueba' AS q, v.avi_id, v.avi_plan_mantenimiento_actividad AS actividad, v.avi_checklist_plantilla_item AS item, v.avi_titulo
FROM   [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
WHERE  a.arc_nombre_original LIKE N'PRUEBA[_]HU143[_]%'
GO

/* Para quitarlas (los vínculos primero):
DELETE v FROM [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo WHERE a.arc_cliente = 1 AND a.arc_nombre_original LIKE N'PRUEBA[_]HU143[_]%'
DELETE FROM [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original LIKE N'PRUEBA[_]HU143[_]%'
*/
