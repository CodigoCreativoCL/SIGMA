/* ============================================================================
   SIGMA - Bloque 139
   LAS FOTOS DEL REPUESTO
   ----------------------------------------------------------------------------

   NO SE CREA NINGUNA TABLA

     `Archivo_Vinculo` ya tiene la columna `avi_repuesto`: la relacion entre un
     archivo y un repuesto ya estaba modelada, solo faltaban los
     procedimientos para usarla. Crear una tabla nueva habria significado dos
     formas distintas de adjuntar en el mismo producto.

     Trae ademas `avi_orden` -para ordenarlas- y `avi_titulo`, que es todo lo
     que una galeria necesita.

   LA PORTADA ES LA DE ORDEN MENOR

     No hay una columna "es portada". La primera de la lista es la que se ve
     en la grilla, y hacer portada a otra es moverla al orden 0. Una bandera
     aparte obligaria a garantizar que solo una la tenga -y a arreglarlo
     cuando dos la tuvieran-; con el orden, esa situacion no existe.

   SOLO IMAGENES

     `INS_REPUESTO_FOTO` rechaza lo que no sea imagen. Una galeria que acepta
     PDFs muestra recuadros rotos, y para documentos ya esta el adjunto de la
     ficha.

   EL ANTIVIRUS NO SE EXIGE, PERO SI SE RESPETA

     Se excluye lo INFECTADO y lo que fallo. No se exige LIMPIO porque no hay
     antivirus conectado todavia y TODOS los archivos estan en PENDIENTE:
     exigirlo dejaria la galeria siempre vacia. El dia que lo haya, lo que
     marque como infectado deja de mostrarse solo.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

/* ============================================================ SEL_ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_FOTO]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON

SELECT  v.avi_id                        AS VINCULO,
        v.avi_archivo                   AS ARCHIVO,
        ISNULL(v.avi_orden, 999)        AS ORDEN,
        ISNULL(v.avi_titulo, '')        AS TITULO,
        a.arc_nombre_original           AS NOMBRE,
        ISNULL(a.arc_mime, '')          AS MIME,
        ISNULL(a.arc_byte, 0)           AS BYTES,
        ISNULL(a.arc_ancho_pixel, 0)    AS ANCHO,
        ISNULL(a.arc_alto_pixel, 0)     AS ALTO,
        v.avi_fecha_creacion            AS FECHA,
        ISNULL(u.usu_nombre + ' ' + u.usu_apellido_paterno, '') AS USUARIO
FROM    [dbo].[Archivo_Vinculo] v
JOIN    [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = v.avi_usuario_creacion
WHERE   v.avi_repuesto = @REPUESTO
  AND   v.avi_habilitado = 1
  AND   a.arc_cliente = @CLIENTE
  AND   a.arc_habilitado = 1
  AND   a.arc_archivo_antivirus_estado NOT IN (3, 4)
ORDER BY ISNULL(v.avi_orden, 999), v.avi_id
GO

/* ============================================================ INS_ */
CREATE OR ALTER PROCEDURE [dbo].[INS_REPUESTO_FOTO]
    @ID       INT = NULL OUTPUT,
    @CLIENTE  INT,
    @REPUESTO INT,
    @ARCHIVO  INT,
    @TITULO   NVARCHAR(200) = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- EL ARCHIVO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Una galeria que acepta PDFs muestra recuadros rotos. Para documentos esta
   el adjunto de la ficha. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                WHERE arc_id = @ARCHIVO AND ISNULL(arc_mime, '') LIKE 'image/%')
BEGIN
    RAISERROR('3.- SOLO SE PUEDEN AGREGAR IMAGENES A LA GALERIA.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo]
            WHERE avi_repuesto = @REPUESTO AND avi_archivo = @ARCHIVO AND avi_habilitado = 1)
BEGIN
    RAISERROR('4.- ESA IMAGEN YA ESTA EN LA GALERIA DEL REPUESTO.', 16, 1)
    RETURN -1
END

/* Al final de la fila. La primera que se sube queda de portada sin que nadie
   tenga que elegirla. */
DECLARE @ORDEN INT

SELECT  @ORDEN = ISNULL(MAX(ISNULL(avi_orden, 0)), 0) + 1
FROM    [dbo].[Archivo_Vinculo]
WHERE   avi_repuesto = @REPUESTO AND avi_habilitado = 1

INSERT INTO [dbo].[Archivo_Vinculo]
    (avi_archivo, avi_repuesto, avi_es_referencia, avi_orden, avi_titulo,
     avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
VALUES
    (@ARCHIVO, @REPUESTO, 1, @ORDEN, @TITULO, @USUARIO, @AHORA, 1)

SET @ID = SCOPE_IDENTITY()
GO

/* ============================================================ DEL_ */
CREATE OR ALTER PROCEDURE [dbo].[DEL_REPUESTO_FOTO]
    @VINCULO INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Baja logica del VINCULO, no del archivo: la misma imagen puede estar
   vinculada a otra cosa, y borrar el blob dejaria esos vinculos apuntando a
   la nada. */
UPDATE  v
SET     v.avi_habilitado            = 0,
        v.avi_usuario_actualizacion = @USUARIO,
        v.avi_fecha_actualizacion   = @AHORA
FROM    [dbo].[Archivo_Vinculo] v
JOIN    [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
WHERE   v.avi_id = @VINCULO
  AND   v.avi_repuesto IS NOT NULL
  AND   a.arc_cliente = @CLIENTE
GO

/* ==================================================== HACER PORTADA */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO_FOTO_PORTADA]
    @VINCULO INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @REPUESTO INT
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT  @REPUESTO = v.avi_repuesto
FROM    [dbo].[Archivo_Vinculo] v
JOIN    [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
WHERE   v.avi_id = @VINCULO AND a.arc_cliente = @CLIENTE

IF @REPUESTO IS NULL
BEGIN
    RAISERROR('1.- LA IMAGEN NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Las demas bajan un lugar y la elegida queda en 0. No hace falta
   renumerarlas de forma contigua: el orden solo decide la secuencia. */
UPDATE [dbo].[Archivo_Vinculo]
SET    avi_orden = ISNULL(avi_orden, 0) + 1
WHERE  avi_repuesto = @REPUESTO AND avi_habilitado = 1 AND avi_id <> @VINCULO

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_orden                 = 0,
       avi_usuario_actualizacion = @USUARIO,
       avi_fecha_actualizacion   = @AHORA
WHERE  avi_id = @VINCULO
GO

/* ========================================= LA PORTADA, PARA EL LISTADO

   Un solo viaje devuelve la portada de todos los repuestos del cliente: la
   grilla la necesita por fila, y pedirla de a una serian trescientas
   consultas para dibujar una pagina.
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_PORTADA]
    @CLIENTE INT
AS
SET NOCOUNT ON

SELECT  x.avi_repuesto AS REPUESTO,
        x.avi_archivo  AS ARCHIVO
FROM (
    SELECT  v.avi_repuesto,
            v.avi_archivo,
            ROW_NUMBER() OVER (PARTITION BY v.avi_repuesto
                               ORDER BY ISNULL(v.avi_orden, 999), v.avi_id) AS N
    FROM    [dbo].[Archivo_Vinculo] v
    JOIN    [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
    WHERE   v.avi_repuesto IS NOT NULL
      AND   v.avi_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
      AND   a.arc_habilitado = 1
      AND   ISNULL(a.arc_mime, '') LIKE 'image/%'
      AND   a.arc_archivo_antivirus_estado NOT IN (3, 4)
) x
WHERE x.N = 1
GO

PRINT '139_REPUESTO_FOTO aplicado.'
GO
