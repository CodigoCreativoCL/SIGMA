/* ============================================================================
   Semilla · Galería de evidencias (HU-142, T-5253) · 10-10-2026 · Catalina Pescio
   Datos de PRUEBA para ejercitar los criterios de aceptación. No va a producción.

   Qué deja (cliente 1, Hamburgo):
     · OT 1 (ACT-10, 08-10): una foto de la orden y fotos en sus 4 pasos con los tres
       momentos (Antes, Durante, Después), un video, una FIRMA y una foto DESHABILITADA.
       → Criterio 1: agrupadas por paso y por momento; la firma y la deshabilitada no salen.
     · OT 5 (ACT-10, 09-10): Antes en el paso 1, Después en el paso 4 y un PDF.
       → Criterio 2: la galería de ACT-10 junta las dos órdenes ordenadas por fecha.
     · OT 2 (ACT-4): una foto de falla que NO debe aparecer en la galería de ACT-10.

   Los archivos reutilizan blobs que ya existen (fotos de ACT-10, un video, un PDF y
   una firma), así que se ven en VerArchivo.aspx sin subir nada. La web no borra
   blobs (Almacenamiento.Eliminar no tiene llamadas), así que compartir la ruta no
   pone en riesgo la foto original.
   Se reconocen por arc_nombre_original LIKE 'PRUEBA_HU142_%'. Para quitarlas, el
   bloque comentado del final. Idempotente: si ya están, no hace nada.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO
IF EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original LIKE N'PRUEBA[_]HU142[_]%')
BEGIN
    PRINT 'Semilla de galería ya cargada: no se hace nada.'
    RETURN
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = 1 AND otr_cliente = 1 AND otr_activo = 10)
   OR NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = 5 AND otr_cliente = 1 AND otr_activo = 10)
   OR NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = 2 AND otr_cliente = 1)
BEGIN
    PRINT 'Las órdenes 1, 5 y 2 no son las esperadas en esta base: semilla omitida.'
    RETURN
END

DECLARE @S TABLE (n INT, ot INT, paso INT NULL, fuente INT, categoria VARCHAR(20), titulo NVARCHAR(200), minutos INT, habilitado BIT)
INSERT @S VALUES
 ( 1, 1, NULL,  8, 'ANTES',     N'Vista general antes de intervenir',     30, 1),
 ( 2, 1,    1, 10, 'ANTES',     N'Tablero desenergizado y bloqueado',     40, 1),
 ( 3, 1,    2, 19, 'DURANTE',   N'Video del drenaje de aceite',           55, 1),
 ( 4, 1,    2, 11, 'DURANTE',   N'Aceite usado en el recipiente',         60, 1),
 ( 5, 1,    3, 12, 'DURANTE',   N'Nivel de aceite nuevo en el visor',     75, 1),
 ( 6, 1,    4,  8, 'DESPUES',   N'Equipo energizado y en marcha',         90, 1),
 ( 7, 1, NULL, 25, 'FIRMA',     N'Firma de ejecución',                    95, 1),
 ( 8, 1,    3, 10, 'DURANTE',   N'Foto repetida (deshabilitada)',         80, 0),
 ( 9, 5,    1, 11, 'ANTES',     N'Antes de desenergizar',                 20, 1),
 (10, 5,    4, 12, 'DESPUES',   N'Prueba de funcionamiento',              70, 1),
 (11, 5, NULL,  9, 'DOCUMENTO', N'Registro del aceite retirado',          75, 1),
 (12, 2, NULL,  5, 'FALLA',     N'Desgaste visible en el reductor',       15, 1)

SET XACT_ABORT ON
BEGIN TRAN
DECLARE @n INT = 1, @ARC INT
WHILE @n <= 12
BEGIN
    INSERT INTO [dbo].[Archivo]
        (arc_cliente, arc_archivo_categoria, arc_nombre_original, arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
         arc_ancho_pixel, arc_alto_pixel, arc_fecha_captura_utc, arc_dispositivo, arc_archivo_antivirus_estado,
         arc_usuario_creacion, arc_fecha_creacion, arc_habilitado)
    SELECT 1, c.aca_id, N'PRUEBA_HU142_' + RIGHT('0' + CAST(s.n AS VARCHAR), 2) + ISNULL(f.arc_extension, N''),
           f.arc_nombre_almacenado, f.arc_ruta, f.arc_mime, f.arc_extension, f.arc_byte,
           f.arc_ancho_pixel, f.arc_alto_pixel, DATEADD(MINUTE, s.minutos + 180, o.otr_fecha_creacion), N'Semilla HU-142', f.arc_archivo_antivirus_estado,
           1, DATEADD(MINUTE, s.minutos, o.otr_fecha_creacion), 1
    FROM   @S s
    JOIN   [dbo].[Archivo] f ON f.arc_id = s.fuente
    JOIN   [dbo].[Archivo_Categoria] c ON c.aca_codigo = s.categoria
    JOIN   [dbo].[Orden_Trabajo] o ON o.otr_id = s.ot
    WHERE  s.n = @n
    SET @ARC = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Archivo_Vinculo]
        (avi_archivo, avi_orden_trabajo, avi_orden_trabajo_paso, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo,
         avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    SELECT @ARC,
           CASE WHEN s.paso IS NULL THEN s.ot END,
           p.otp_id,
           0, 0,
           ISNULL((SELECT MAX(v.avi_orden) FROM [dbo].[Archivo_Vinculo] v
                    WHERE (s.paso IS NULL AND v.avi_orden_trabajo = s.ot) OR (s.paso IS NOT NULL AND v.avi_orden_trabajo_paso = p.otp_id)), 0) + 1,
           s.titulo, 1, DATEADD(MINUTE, s.minutos, o.otr_fecha_creacion), s.habilitado
    FROM   @S s
    JOIN   [dbo].[Orden_Trabajo] o ON o.otr_id = s.ot
    LEFT JOIN [dbo].[Orden_Trabajo_Paso] p ON p.otp_orden_trabajo = s.ot AND p.otp_orden = s.paso
    WHERE  s.n = @n
    SET @n += 1
END
COMMIT
PRINT 'Semilla de galería cargada: 12 archivos de prueba.'
GO

/* ---- Para quitar la semilla ----
DELETE v FROM [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
 WHERE a.arc_cliente = 1 AND a.arc_nombre_original LIKE N'PRUEBA[_]HU142[_]%'
DELETE FROM [dbo].[Archivo] WHERE arc_cliente = 1 AND arc_nombre_original LIKE N'PRUEBA[_]HU142[_]%'
*/
