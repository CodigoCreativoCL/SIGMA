USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     IMAGEN DE REFERENCIA DE UN ACTIVO (ficha e historial + alta de activo).
-- =============================================
-- Va DESPUES de 131_SPRINT3_PROCEDIMIENTO_MENU.
--
-- La imagen del activo no vive en la tabla Activo: se guarda en Archivo y se
-- enlaza por Archivo_Vinculo (avi_activo + avi_es_referencia = 1), el mismo
-- mecanismo polimorfico que ya usan las ordenes, fallas, permisos, etc.
--
--   SEL_ACTIVO_IMAGEN  -> devuelve la imagen de referencia vigente de un activo
--                          (para pintarla en la ficha).
--   VIN_ACTIVO_IMAGEN  -> enlaza un Archivo ya subido como imagen del activo,
--                          dejando UNA sola vigente (apaga las anteriores).
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   SEL_ACTIVO_IMAGEN - la imagen de referencia vigente del activo
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_IMAGEN]
@ACTIVO INT, @CLIENTE INT
AS
SET NOCOUNT ON

    SELECT TOP 1
            a.arc_id     AS ARC_ID,
            a.arc_uuid   AS ARC_UUID,
            a.arc_mime   AS ARC_MIME,
            a.arc_nombre_original AS ARC_NOMBRE
    FROM    [dbo].[Archivo_Vinculo] v
    INNER JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
    WHERE   v.avi_activo = @ACTIVO
      AND   v.avi_es_referencia = 1
      AND   v.avi_habilitado = 1
      AND   a.arc_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
    ORDER BY ISNULL(v.avi_orden, 0), a.arc_id DESC
GO


/* ========================================================================
   VIN_ACTIVO_IMAGEN - deja un Archivo como LA imagen del activo
      Apaga cualquier imagen de referencia anterior del mismo activo, para que
      siempre haya una sola vigente. El Archivo ya tiene que existir (se sube
      con INS_ARCHIVO antes de llamar aca).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_IMAGEN]
@ID       INT = NULL OUTPUT,
@ACTIVO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT

SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    -- Apaga la imagen de referencia anterior (solo una vigente).
    UPDATE [dbo].[Archivo_Vinculo]
    SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
    WHERE  avi_activo = @ACTIVO AND avi_es_referencia = 1 AND avi_habilitado = 1

    INSERT [dbo].[Archivo_Vinculo]
        (avi_archivo, avi_activo, avi_es_referencia, avi_orden,
         avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    VALUES
        (@ARCHIVO, @ACTIVO, 1, 0, @USUARIO, @NOW, 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   DEL_ACTIVO_IMAGEN - quita la imagen de referencia vigente del activo
      Baja logica del vinculo (no borra el Archivo): el activo queda sin
      imagen y la ficha vuelve a mostrar la ilustracion de respaldo.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_IMAGEN]
@ACTIVO   INT,
@USUARIO  INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT
SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
WHERE  avi_activo = @ACTIVO AND avi_es_referencia = 1 AND avi_habilitado = 1

RETURN(0)
GO


PRINT '132_SPRINT3_ACTIVO_IMAGEN aplicado: SEL/VIN/DEL_ACTIVO_IMAGEN.'
GO
