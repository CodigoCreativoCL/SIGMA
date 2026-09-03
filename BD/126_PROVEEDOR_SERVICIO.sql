/* ============================================================================
   SIGMA — Bloque 126
   LOS SERVICIOS QUE PRESTO UN PROVEEDOR, Y SUS ADJUNTOS
   ----------------------------------------------------------------------------

   QUE RESUELVE

     La ficha del proveedor decia "1 servicio asociado". Es un numero, y un
     numero no sirve para lo que la gente hace con esa pantalla: saber QUE
     hizo, CUANDO, CUANTO costo y con que respaldo.

   LOS ADJUNTOS SON DE LA ORDEN, NO DE LA LINEA

     `Archivo_Vinculo` engancha a `orden_trabajo`, no a
     `orden_trabajo_servicio`. Es decir: los archivos son de la OT completa
     —el informe, las fotos del trabajo, la factura— y no de la linea de
     servicio en particular.

     La pantalla lo dice asi. Rotularlos "adjuntos del servicio" sugeriria que
     alguien los subio para ESA linea, y no es cierto: si la OT tiene dos
     servicios del mismo proveedor, los dos muestran los mismos archivos.

   SOLO SE OFRECEN LOS LIMPIOS

     `arc_archivo_antivirus_estado` = 2 es LIMPIO. Un archivo PENDIENTE
     todavia no se reviso y uno INFECTADO ya se reviso y salio mal: ofrecer
     cualquiera de los dos para descargar es repartir el problema. Los que no
     estan limpios se cuentan aparte para poder decir por que no aparecen, en
     vez de hacerlos desaparecer sin explicacion.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_PROVEEDOR_SERVICIO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROVEEDOR_SERVICIO]
GO

CREATE PROCEDURE [dbo].[SEL_PROVEEDOR_SERVICIO]
    @PROVEEDOR  INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

/* El cliente se comprueba por el proveedor padre: la linea de servicio sola
   no sabe de quien es, y sin esto cualquiera con el id veria los servicios
   —y los adjuntos— de otra empresa. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor]
                WHERE prv_id = @PROVEEDOR AND prv_cliente = @CLIENTE)
BEGIN
    /* Dos resultados vacios, con la misma forma: el C# los lee igual y no
       tiene que distinguir "no existe" de "no tiene". */
    SELECT TOP 0 CAST(NULL AS INT) AS ots_id
    SELECT TOP 0 CAST(NULL AS INT) AS arc_id
    RETURN
END

    /* ---- 1. los servicios ---- */
    SELECT  s.ots_id,
            s.ots_orden_trabajo,
            ISNULL(o.otr_numero_solicitud, '')  AS OT_NUMERO,
            ISNULL(o.otr_titulo, '')            AS OT_TITULO,
            ISNULL(oe.ote_nombre, '')           AS OT_ESTADO,
            ISNULL(st.sti_nombre, '')           AS TIPO_NOMBRE,
            ISNULL(s.ots_descripcion, '')       AS ots_descripcion,
            s.ots_cantidad,
            s.ots_monto_unitario,
            s.ots_monto,
            ISNULL(m.mon_nombre, '')            AS MONEDA_NOMBRE,
            ISNULL(s.ots_documento_referencia, '') AS ots_documento_referencia,
            s.ots_fecha_servicio_utc,
            s.ots_fecha_documento,

            /* Cuantos archivos hay para descargar, y cuantos NO se pueden
               ofrecer todavia. Los dos numeros se muestran: esconder los que
               no estan limpios deja a alguien buscando un informe que si
               existe. */
            ADJUNTOS = (SELECT COUNT(*)
                          FROM [dbo].[Archivo_Vinculo] v
                          JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
                         WHERE v.avi_orden_trabajo = s.ots_orden_trabajo
                           AND v.avi_habilitado = 1
                           AND a.arc_habilitado = 1
                           AND a.arc_cliente = @CLIENTE
                           AND a.arc_archivo_antivirus_estado = 2),

            ADJUNTOS_RETENIDOS = (SELECT COUNT(*)
                          FROM [dbo].[Archivo_Vinculo] v
                          JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
                         WHERE v.avi_orden_trabajo = s.ots_orden_trabajo
                           AND v.avi_habilitado = 1
                           AND a.arc_habilitado = 1
                           AND a.arc_cliente = @CLIENTE
                           AND ISNULL(a.arc_archivo_antivirus_estado, 1) <> 2)

    FROM    [dbo].[Orden_Trabajo_Servicio] s
    JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
    LEFT JOIN [dbo].[Orden_Trabajo_Estado] oe ON oe.ote_id = o.otr_orden_trabajo_estado
    LEFT JOIN [dbo].[Servicio_Tipo] st ON st.sti_id = s.ots_servicio_tipo
    LEFT JOIN [dbo].[Moneda] m ON m.mon_id = s.ots_moneda
    WHERE   s.ots_proveedor = @PROVEEDOR
      AND   s.ots_habilitado = 1
    /* El mas reciente primero: es el que se viene a mirar. */
    ORDER BY ISNULL(s.ots_fecha_servicio_utc, o.otr_fecha_creacion) DESC, s.ots_id DESC

    /* ---- 2. los adjuntos, por orden de trabajo ----

       Van en un resultado aparte y no repetidos dentro de cada servicio: dos
       lineas de la misma OT comparten los mismos archivos, y traerlos dos
       veces es traer el doble para mostrar lo mismo. El C# los agrupa por
       `avi_orden_trabajo`. */
    SELECT DISTINCT
            a.arc_id,
            v.avi_orden_trabajo,
            a.arc_nombre_original,
            ISNULL(a.arc_extension, '')     AS arc_extension,
            ISNULL(a.arc_mime, '')          AS arc_mime,
            a.arc_byte,
            a.arc_fecha_creacion,
            ISNULL(ac.aca_nombre, '')       AS CATEGORIA,
            ISNULL(av.aae_codigo, 'PENDIENTE') AS ANTIVIRUS,
            ISNULL(v.avi_titulo, '')        AS avi_titulo
    FROM    [dbo].[Archivo_Vinculo] v
    JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
    JOIN    [dbo].[Orden_Trabajo_Servicio] s ON s.ots_orden_trabajo = v.avi_orden_trabajo
    LEFT JOIN [dbo].[Archivo_Categoria] ac ON ac.aca_id = a.arc_archivo_categoria
    LEFT JOIN [dbo].[Archivo_Antivirus_Estado] av ON av.aae_id = a.arc_archivo_antivirus_estado
    WHERE   s.ots_proveedor = @PROVEEDOR
      AND   s.ots_habilitado = 1
      AND   v.avi_habilitado = 1
      AND   a.arc_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
      /* Solo los revisados y limpios se ofrecen para abrir. */
      AND   a.arc_archivo_antivirus_estado = 2
    ORDER BY v.avi_orden_trabajo, a.arc_nombre_original
GO

PRINT '--- SEL_PROVEEDOR_SERVICIO creado.'
GO

EXEC [dbo].[SEL_PROVEEDOR_SERVICIO] @PROVEEDOR = 3, @CLIENTE = 1
GO

PRINT '126_PROVEEDOR_SERVICIO aplicado.'
GO
