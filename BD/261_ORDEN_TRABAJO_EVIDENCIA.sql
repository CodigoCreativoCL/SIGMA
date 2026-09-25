USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     LAS EVIDENCIAS DE UNA ORDEN DE TRABAJO, EN LA WEB.
--                  1. SEL_ORDEN_TRABAJO_ARCHIVO: lo que llego desde la app.
--                  2. VIN_ORDEN_TRABAJO_ARCHIVO: enlaza un archivo ya subido
--                     a la orden o a uno de sus pasos (la firma del cierre).
-- =============================================
-- El telefono ya sube fotos, videos y audios y los enlaza por Archivo_Vinculo
-- (avi_orden_trabajo / avi_orden_trabajo_paso). La web no tenia como leerlos:
-- API_SEL_EVIDENCIA vive del lado de la API y devuelve un destino a la vez.
-- Aca se lee la orden COMPLETA -lo suyo y lo de todos sus pasos- porque la
-- pantalla los muestra juntos y filtra por paso en el navegador.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_ORDEN_TRABAJO_ARCHIVO

   Devuelve la RUTA del blob, no los bytes: la pantalla arma la miniatura
   con VerArchivo.aspx y el navegador la cachea. Mandar las imagenes dentro
   de la consulta haria que abrir una orden con seis fotos costara seis
   megas de HTML.

   Que el paso venga o no dice de donde salio la evidencia: la que el
   tecnico saco en el paso 3 trae su numero y su nombre; la que subio
   contra la orden entera, no.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_ARCHIVO]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  arc.arc_id,
            arc.arc_nombre_original,
            ISNULL(arc.arc_mime, '')                      AS arc_mime,
            ISNULL(arc.arc_byte, 0)                       AS arc_byte,
            arc.arc_fecha_creacion,
            ISNULL(aca.aca_codigo, '')                    AS CATEGORIA_CODIGO,
            ISNULL(aca.aca_nombre, '')                    AS CATEGORIA_NOMBRE,
            ISNULL(avi.avi_titulo, '')                    AS AVI_TITULO,
            ISNULL(avi.avi_descripcion, '')               AS AVI_DESCRIPCION,
            avi.avi_orden_trabajo_paso                    AS PASO_ID,
            ISNULL(otp.otp_orden, 0)                      AS PASO_ORDEN,
            ISNULL(otp.otp_nombre, '')                    AS PASO_NOMBRE,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE,

            /* El tipo se decide aca y no en la pantalla: es la misma regla
               para la galeria, los contadores y el icono, y repartida en tres
               lugares se desincroniza a la primera extension nueva. */
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'image/%' THEN 1 ELSE 0 END AS INT) AS ES_IMAGEN,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'video/%' THEN 1 ELSE 0 END AS INT) AS ES_VIDEO,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'audio/%' THEN 1 ELSE 0 END AS INT) AS ES_AUDIO

    FROM    [dbo].[Archivo_Vinculo] avi
    JOIN    [dbo].[Archivo]         arc ON arc.arc_id = avi.avi_archivo
    LEFT JOIN [dbo].[Archivo_Categoria]   aca ON aca.aca_id = arc.arc_archivo_categoria
    LEFT JOIN [dbo].[Orden_Trabajo_Paso]  otp ON otp.otp_id = avi.avi_orden_trabajo_paso
    LEFT JOIN [dbo].[Usuario]             usr ON usr.usu_id = arc.arc_usuario_creacion

    WHERE   arc.arc_cliente    = @CLIENTE
      AND   arc.arc_habilitado = 1
      AND   avi.avi_habilitado = 1
      AND   (avi.avi_orden_trabajo = @ORDEN
             OR avi.avi_orden_trabajo_paso IN (SELECT otp_id FROM [dbo].[Orden_Trabajo_Paso] WHERE otp_orden_trabajo = @ORDEN))

    ORDER BY ISNULL(otp.otp_orden, 0), avi.avi_orden, arc.arc_id
GO
PRINT '--- SEL_ORDEN_TRABAJO_ARCHIVO creado.'
GO


/* ========================================================================
   2. VIN_ORDEN_TRABAJO_ARCHIVO

   Enlaza un archivo YA SUBIDO al blob (lo sube ArchivoController, que
   escribe primero el binario y despues la fila) con la orden o con uno de
   sus pasos. Hoy lo usa la firma del cierre; sirve igual para cualquier
   respaldo que se adjunte desde la web.

   El archivo tiene que ser del mismo cliente que la orden: el id viaja por
   el navegador y adivinar un correlativo es barato.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[VIN_ORDEN_TRABAJO_ARCHIVO]
    @ID          INT = NULL OUTPUT,
    @ORDEN       INT,
    @ARCHIVO     INT,
    @PASO        INT = NULL,
    @TITULO      NVARCHAR(200) = NULL,
    @DESCRIPCION NVARCHAR(500) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @ARC_CLIENTE INT, @PAIS INT, @NOW DATETIME

SELECT @CLIENTE = otr_cliente FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN
IF @CLIENTE IS NULL
BEGIN RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE.', 16, 1) RETURN -1 END

SELECT @ARC_CLIENTE = arc_cliente FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO
IF @ARC_CLIENTE IS NULL
BEGIN RAISERROR('2.- EL ARCHIVO NO EXISTE.', 16, 1) RETURN -1 END

IF @ARC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('3.- EL ARCHIVO PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

IF @PASO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso] WHERE otp_id = @PASO AND otp_orden_trabajo = @ORDEN)
BEGIN RAISERROR('4.- EL PASO NO ES DE ESTA ORDEN.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET    @NOW  = [dbo].[FNC_PAIS_HORA](@PAIS)

INSERT [dbo].[Archivo_Vinculo]
    (avi_archivo, avi_orden_trabajo, avi_orden_trabajo_paso, avi_titulo, avi_descripcion,
     avi_es_referencia, avi_orden, avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
VALUES
    (@ARCHIVO, @ORDEN, @PASO, @TITULO, @DESCRIPCION,
     0, 0, @USUARIO, @NOW, 1)

SET @ID = SCOPE_IDENTITY()

SELECT 200 AS ID, 200 AS CODE, 'Archivo enlazado a la orden.' AS MENSAJE
GO
PRINT '--- VIN_ORDEN_TRABAJO_ARCHIVO creado.'
GO

PRINT '261_ORDEN_TRABAJO_EVIDENCIA aplicado.'
GO
