USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     LA IMAGEN DE UN COMPONENTE.
-- =============================================
-- El activo tiene su imagen desde el Sprint 2 (SEL/VIN/DEL_ACTIVO_IMAGEN) y
-- el componente no, aunque la columna para colgarla -avi_activo_componente-
-- existe desde el bloque 202. En el centro eso se nota: la lista de piezas es
-- una lista de nombres, y "cambiar el rodamiento lado motor" se decide
-- mirando la pieza, no leyendo su codigo.
--
-- Son los mismos tres procedimientos del activo, apuntando a la otra columna.
-- Una sola imagen vigente por componente: la anterior se apaga, no se borra,
-- porque el archivo sigue en Blob Storage y puede estar citado en una orden.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_ACTIVO_COMPONENTE_IMAGEN
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE_IMAGEN]
    @COMPONENTE INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

    SELECT TOP 1
            a.arc_id                AS ARC_ID,
            a.arc_uuid              AS ARC_UUID,
            ISNULL(a.arc_mime, '')  AS ARC_MIME,
            ISNULL(a.arc_nombre_original, '') AS ARC_NOMBRE

    FROM    [dbo].[Archivo_Vinculo] v
    JOIN    [dbo].[Archivo] a ON a.arc_id = v.avi_archivo

    WHERE   v.avi_activo_componente = @COMPONENTE
      AND   v.avi_es_referencia = 1
      AND   ISNULL(v.avi_habilitado, 1) = 1
      AND   ISNULL(a.arc_habilitado, 1) = 1
      AND   a.arc_cliente = @CLIENTE

    ORDER BY v.avi_id DESC
GO
PRINT '--- SEL_ACTIVO_COMPONENTE_IMAGEN creado.'
GO


/* ========================================================================
   2. VIN_ACTIVO_COMPONENTE_IMAGEN

   Una sola vigente: la anterior se apaga en la misma transaccion. Si se
   apagara despues, un error en el medio dejaria dos imagenes vigentes y la
   pantalla mostraria la que viniera primero.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_COMPONENTE_IMAGEN]
    @ID         INT = NULL OUTPUT,
    @COMPONENTE INT,
    @ARCHIVO    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT

SELECT  @CLIENTE = aco_cliente
  FROM  [dbo].[Activo_Componente]
 WHERE  aco_id = @COMPONENTE

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Archivo_Vinculo]
       SET  avi_habilitado = 0,
            avi_usuario_actualizacion = @USUARIO,
            avi_fecha_actualizacion = @NOW
     WHERE  avi_activo_componente = @COMPONENTE
       AND  avi_es_referencia = 1
       AND  ISNULL(avi_habilitado, 1) = 1

    INSERT INTO [dbo].[Archivo_Vinculo]
        ([avi_archivo], [avi_activo_componente], [avi_es_referencia],
         [avi_usuario_creacion], [avi_fecha_creacion], [avi_habilitado])
    VALUES
        (@ARCHIVO, @COMPONENTE, 1, @USUARIO, @NOW, 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

SELECT @ID AS ID
GO
PRINT '--- VIN_ACTIVO_COMPONENTE_IMAGEN creado.'
GO


/* ========================================================================
   3. DEL_ACTIVO_COMPONENTE_IMAGEN

   Apaga el vinculo; el archivo se queda. Puede estar citado en la evidencia
   de una orden, y borrarlo dejaria esa orden con una foto rota.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_COMPONENTE_IMAGEN]
    @COMPONENTE INT,
    @USUARIO    INT
AS
SET NOCOUNT ON

    UPDATE  [dbo].[Archivo_Vinculo]
       SET  avi_habilitado = 0,
            avi_usuario_actualizacion = @USUARIO,
            avi_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE  avi_activo_componente = @COMPONENTE
       AND  avi_es_referencia = 1
       AND  ISNULL(avi_habilitado, 1) = 1

    SELECT @@ROWCOUNT AS FILAS
GO
PRINT '--- DEL_ACTIVO_COMPONENTE_IMAGEN creado.'
GO

PRINT '274_COMPONENTE_IMAGEN aplicado.'
GO
