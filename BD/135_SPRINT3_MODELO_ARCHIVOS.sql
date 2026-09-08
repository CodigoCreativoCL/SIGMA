USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     ARCHIVOS ADJUNTOS DE UN MODELO DE ACTIVO (catalogo, foto de placa…).
-- =============================================
-- Va DESPUES de 134_SPRINT3_FIX_CODIGO_AUTO_ROWCOUNT.
--
-- IDEA
--   Un modelo (p. ej. "SEW <modelo>") puede tener DOCUMENTOS y FOTOS que son
--   iguales para todas las unidades: el catalogo del fabricante, la foto de la
--   placa caracteristica, el manual. Son OPCIONALES y pueden ser VARIOS.
--
--   Se reutiliza el mismo sistema de archivos (Archivo + Azure) que la imagen
--   del activo. Solo faltaba enlazar un archivo a un MODELO: se agrega la
--   columna avi_activo_modelo a Archivo_Vinculo (los activos ya tenian la suya).
--
--   A diferencia de la imagen del activo (una sola vigente), aca se permiten
--   VARIOS: no se apaga el anterior.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* 1) Columna de enlace archivo -> modelo. */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Archivo_Vinculo') AND name='avi_activo_modelo')
BEGIN
    ALTER TABLE [dbo].[Archivo_Vinculo] ADD [avi_activo_modelo] INT NULL
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_AVI_ACTIVO_MODELO')
    ALTER TABLE [dbo].[Archivo_Vinculo] WITH NOCHECK
        ADD CONSTRAINT [FK_AVI_ACTIVO_MODELO] FOREIGN KEY ([avi_activo_modelo])
        REFERENCES [dbo].[Activo_Modelo]([amo_id])
GO


/* 2) SEL_ACTIVO_MODELO_ARCHIVO - los archivos vigentes de un modelo. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MODELO_ARCHIVO]
@MODELO INT, @CLIENTE INT
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
    WHERE   v.avi_activo_modelo = @MODELO
      AND   v.avi_habilitado = 1
      AND   a.arc_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
    ORDER BY a.arc_id
GO


/* 3) VIN_ACTIVO_MODELO_ARCHIVO - enlaza un archivo ya subido al modelo. */
CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_MODELO_ARCHIVO]
@ID       INT = NULL OUTPUT,
@MODELO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT
SELECT @CLIENTE = amo_cliente FROM [dbo].[Activo_Modelo] WHERE amo_id = @MODELO
-- Un modelo global (cliente NULL) igual puede tener adjuntos de plataforma;
-- para fechar usamos el pais del cliente del archivo si el modelo no tiene.
IF @CLIENTE IS NULL SELECT @CLIENTE = arc_cliente FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

INSERT [dbo].[Archivo_Vinculo]
    (avi_archivo, avi_activo_modelo, avi_es_referencia, avi_orden,
     avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
VALUES
    (@ARCHIVO, @MODELO, 0, 0, @USUARIO, @NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN(0)
GO


/* 4) DEL_ACTIVO_MODELO_ARCHIVO - quita (baja logica) un archivo del modelo. */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_MODELO_ARCHIVO]
@MODELO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT
SELECT @CLIENTE = amo_cliente FROM [dbo].[Activo_Modelo] WHERE amo_id = @MODELO
IF @CLIENTE IS NULL SELECT @CLIENTE = arc_cliente FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
WHERE  avi_activo_modelo = @MODELO AND avi_archivo = @ARCHIVO AND avi_habilitado = 1

-- El Archivo tambien se apaga (deja de servirse), pero el blob queda en Azure.
UPDATE [dbo].[Archivo]
SET    arc_habilitado = 0, arc_usuario_actualizacion = @USUARIO, arc_fecha_actualizacion = @NOW
WHERE  arc_id = @ARCHIVO
GO


PRINT '135_SPRINT3_MODELO_ARCHIVOS aplicado: columna avi_activo_modelo + SEL/VIN/DEL_ACTIVO_MODELO_ARCHIVO.'
GO
