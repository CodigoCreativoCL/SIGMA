/* SIGMA — Bloque 101: contexto operativo en permisos vigentes. */
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_VIGENTE]
    @CLIENTE           INT,
    @DIAS_AVISO        INT = 7,
    @TIPO              INT = NULL,
    @INCLUIR_VENCIDOS  BIT = 1,
    @SOLO_POR_VENCER   BIT = 0,
    @FILTRO            VARCHAR(200) = NULL
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME
SET @HOY = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))

;WITH BASE AS
(
    SELECT  p.ptr_id,
            p.ptr_permiso_trabajo_tipo,
            ISNULL(p.ptr_numero, '') AS ptr_numero,
            p.ptr_fecha_vigencia_inicio_utc,
            p.ptr_fecha_vigencia_fin_utc,
            p.ptr_archivo,
            ti.ptt_nombre AS TIPO_NOMBRE,
            es.pte_nombre AS ESTADO_NOMBRE,
            es.pte_codigo AS ESTADO_CODIGO,
            ISNULL(so.usu_nombre + ' ' + so.usu_apellido_paterno, '') AS SOLICITANTE_NOMBRE,
            /* La identidad del solicitante, no solo su nombre.

               El listado dibuja su avatar, y un avatar necesita dos cosas que
               un nombre no trae: el ID -de donde sale su color, que es lo que
               permite reconocerlo de una pantalla a otra- y la foto si la
               subio. Sin el id, el color tendria que salir del nombre, y un
               hash de letras da colores repetidos: con los siete usuarios
               reales del cliente daba solo cuatro. */
            ISNULL(so.usu_id, 0) AS SOLICITANTE_ID,
            ISNULL(so.usu_archivo_foto, 0) AS SOLICITANTE_FOTO,
            ISNULL(ot.otr_correlativo, '') AS ORDEN_CORRELATIVO,
            ISNULL(ot.otr_titulo, '') AS ORDEN_TITULO,
            ISNULL(cin.cin_nombre, '') AS INSTALACION_NOMBRE,
            ISNULL(act.act_codigo, '') AS ACTIVO_CODIGO,
            ISNULL(act.act_nombre, '') AS ACTIVO_NOMBRE,
            CAST(CASE WHEN p.ptr_archivo IS NULL THEN 0 ELSE 1 END AS BIT) AS TIENE_DOCUMENTO,

            /* El panel de detalle muestra el respaldo, no solo dice que
               existe. Para eso necesita saber COMO se llama y de que tipo es:
               una foto se muestra, un PDF se ofrece para bajar. Sin el mime,
               habria que abrir el archivo para saber cual de las dos cosas
               hacer.

               Solo se entrega si el antivirus lo dio por limpio (estado 2).
               Un archivo retenido existe, pero ofrecerlo para descargar seria
               repartir justamente lo que se puso en cuarentena. */
            ISNULL(ar.arc_nombre_original, '') AS ARCHIVO_NOMBRE,
            ISNULL(ar.arc_extension, '')       AS ARCHIVO_EXTENSION,
            ISNULL(ar.arc_mime, '')            AS ARCHIVO_MIME,
            ISNULL(ar.arc_byte, 0)             AS ARCHIVO_BYTE,
            CASE WHEN p.ptr_fecha_vigencia_fin_utc IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, @HOY, p.ptr_fecha_vigencia_fin_utc) END AS DIAS_RESTANTES
    FROM    [dbo].[Permiso_Trabajo] p
    JOIN    [dbo].[Permiso_Trabajo_Tipo] ti ON ti.ptt_id = p.ptr_permiso_trabajo_tipo
    JOIN    [dbo].[Permiso_Trabajo_Estado] es ON es.pte_id = p.ptr_permiso_trabajo_estado
    LEFT JOIN [dbo].[Usuario] so ON so.usu_id = p.ptr_usuario_solicitante
    /* Se excluyen INFECTADO (3) y ERROR (4), no se exige LIMPIO (2).

       La diferencia importa: no hay antivirus conectado todavia, asi que
       TODOS los archivos del sistema estan en PENDIENTE (1). Exigir LIMPIO
       dejaba el panel sin mostrar nunca ningun respaldo -se probo, y no
       aparecia ninguno de los dos que hay cargados-. Y seria mas estricto
       que el resto del producto, donde esos mismos archivos ya se descargan
       desde la ficha.

       Escrito asi, el dia que haya antivirus lo que marque como infectado o
       fallido deja de ofrecerse solo, sin volver a tocar esto. */
    LEFT JOIN [dbo].[Archivo] ar ON ar.arc_id = p.ptr_archivo
                                AND ar.arc_habilitado = 1
                                AND ar.arc_archivo_antivirus_estado NOT IN (3, 4)
    LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = p.ptr_orden_trabajo
    LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ot.otr_cliente_instalacion
    LEFT JOIN [dbo].[Activo] act ON act.act_id = ot.otr_activo
    WHERE   p.ptr_cliente = @CLIENTE
      AND   p.ptr_habilitado = 1
      AND  (@TIPO IS NULL OR p.ptr_permiso_trabajo_tipo = @TIPO)
      AND  (@FILTRO IS NULL
            OR p.ptr_numero LIKE '%' + @FILTRO + '%'
            OR ti.ptt_nombre LIKE '%' + @FILTRO + '%'
            OR ot.otr_correlativo LIKE '%' + @FILTRO + '%'
            OR ot.otr_titulo LIKE '%' + @FILTRO + '%'
            OR cin.cin_nombre LIKE '%' + @FILTRO + '%'
            OR act.act_codigo LIKE '%' + @FILTRO + '%'
            OR act.act_nombre LIKE '%' + @FILTRO + '%'
            OR so.usu_nombre LIKE '%' + @FILTRO + '%'
            OR so.usu_apellido_paterno LIKE '%' + @FILTRO + '%')
), CON_SITUACION AS
(
    SELECT b.*, [dbo].[FNC_PERMISO_SITUACION](b.ESTADO_CODIGO, b.DIAS_RESTANTES, @DIAS_AVISO) AS SITUACION
    FROM BASE b
)
SELECT  s.*
FROM    CON_SITUACION s
WHERE   s.SITUACION IN ('VIGENTE', 'POR VENCER', 'VENCIDO')
  AND  (@INCLUIR_VENCIDOS = 1 OR s.SITUACION <> 'VENCIDO')
  AND  (@SOLO_POR_VENCER = 0 OR s.SITUACION = 'POR VENCER')
ORDER BY CASE s.SITUACION WHEN 'VENCIDO' THEN 0 WHEN 'POR VENCER' THEN 1 ELSE 2 END,
         s.DIAS_RESTANTES,
         s.ptr_id DESC
GO

PRINT '101_PERMISO_VIGENTE_CONTEXTO aplicado.'
GO
