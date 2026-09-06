USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     DOCUMENTOS ADJUNTOS DE UN ACTIVO (PDF, manuales, planos...).
-- =============================================
-- Ademas de la IMAGEN del activo (avi_activo + avi_es_referencia = 1, una sola
-- vigente), un activo puede tener VARIOS documentos/PDF. Se reutiliza el mismo
-- sistema Archivo (Azure) y el enlace avi_activo, pero con avi_es_referencia = 0
-- para separarlos de la imagen. Son opcionales y pueden ser varios.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* 1) SEL_ACTIVO_ARCHIVO - los documentos vigentes de un activo (no la imagen). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ARCHIVO]
@ACTIVO INT, @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT  a.arc_id                  AS ARC_ID,
            a.arc_uuid                AS ARC_UUID,
            a.arc_nombre_original     AS ARC_NOMBRE,
            a.arc_mime                AS ARC_MIME,
            a.arc_archivo_categoria   AS ARC_CATEGORIA,
            a.arc_byte                AS ARC_BYTE
    FROM    [dbo].[Archivo_Vinculo] v
    INNER JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
    WHERE   v.avi_activo = @ACTIVO
      AND   v.avi_es_referencia = 0        -- 1 = imagen; 0 = documentos
      AND   v.avi_habilitado = 1
      AND   a.arc_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
    ORDER BY a.arc_id
GO


/* 2) VIN_ACTIVO_ARCHIVO - enlaza un archivo ya subido como documento del activo. */
CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_ARCHIVO]
@ID       INT = NULL OUTPUT,
@ACTIVO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT
SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

INSERT [dbo].[Archivo_Vinculo]
    (avi_archivo, avi_activo, avi_es_referencia, avi_orden,
     avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
VALUES
    (@ARCHIVO, @ACTIVO, 0, 0, @USUARIO, @NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN(0)
GO


/* 3) DEL_ACTIVO_ARCHIVO - quita (baja logica) un documento del activo. */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_ARCHIVO]
@ACTIVO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT
SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
WHERE  avi_activo = @ACTIVO AND avi_archivo = @ARCHIVO AND avi_es_referencia = 0 AND avi_habilitado = 1

UPDATE [dbo].[Archivo]
SET    arc_habilitado = 0, arc_usuario_actualizacion = @USUARIO, arc_fecha_actualizacion = @NOW
WHERE  arc_id = @ARCHIVO
GO


PRINT '150_SPRINT3_ACTIVO_ARCHIVOS aplicado: SEL/VIN/DEL_ACTIVO_ARCHIVO (documentos del activo).'
GO
