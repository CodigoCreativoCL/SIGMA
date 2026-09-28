USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     NUMERO DE SERIE, FABRICANTE Y MODELO DE UN COMPONENTE.
-- =============================================
-- POR QUE ESTAS TRES Y NO LAS OTRAS DEL MOCKUP
--   El criterio es simple: si no hay donde capturar el dato, no se agrega la
--   columna. Una columna que nadie puede llenar se ve igual de vacia que no
--   tenerla, y encima promete algo.
--
--   Estas tres SI tienen donde: la ficha del componente es un formulario que
--   ya se edita, y agregarle tres campos es todo lo que hace falta. Sin
--   ellas, para saber que rodamiento comprar hay que abrir la foto o
--   preguntarle al que lo instalo.
--
--   Quedaron fuera, y por que:
--     - La etapa de la evidencia -antes / despues / verificacion- se elige
--       cuando se saca la foto, o sea EN LA APP. La web no sube evidencias de
--       orden, asi que la columna nace vacia para siempre.
--     - El origen -web o app- de un cambio de estado habria que escribirlo en
--       los historiales, y esos SP los comparte la app: cambiar su contrato
--       por una columna informativa no se paga.
--     - El folio del cambio de atributo y los documentos exigidos por tipo de
--       activo son dos modulos con su propia pantalla, no un ajuste.
--
-- POR QUE NO SE TOCAN INS/UPD_ACTIVO_COMPONENTE
--   Esos dos los llama tambien la app. Sumarles tres parametros obliga a
--   revisar cada llamada para ganar un UPDATE de tres columnas. La placa va
--   en su propio SP, igual que UPD_ACTIVO_MEDIDOR_MAXIMO_DIARIO en el bloque
--   235 y por la misma razon.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

IF COL_LENGTH('dbo.Activo_Componente', 'aco_numero_serie') IS NULL
BEGIN
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_numero_serie] VARCHAR(100) NULL
    PRINT '--- aco_numero_serie agregada.'
END
GO

IF COL_LENGTH('dbo.Activo_Componente', 'aco_fabricante') IS NULL
BEGIN
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_fabricante] VARCHAR(150) NULL
    PRINT '--- aco_fabricante agregada.'
END
GO

IF COL_LENGTH('dbo.Activo_Componente', 'aco_modelo') IS NULL
BEGIN
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_modelo] VARCHAR(150) NULL
    PRINT '--- aco_modelo agregada.'
END
GO

/* ========================================================================
   Guardar la placa. Se llama despues de INS o de UPD, con lo que la ficha
   tenga escrito: tres campos de texto, sin reglas que validar mas alla de
   que la pieza exista y sea del cliente.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPS_ACTIVO_COMPONENTE_PLACA]
    @ID          INT,
    @NUMERO_SERIE VARCHAR(100) = NULL,
    @FABRICANTE  VARCHAR(150) = NULL,
    @MODELO      VARCHAR(150) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT

SELECT @CLIENTE = aco_cliente FROM [dbo].[Activo_Componente] WHERE aco_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

DECLARE @PAIS INT, @NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Vacio se guarda como NULL y no como cadena vacia: "sin registrar" es un
   dato que falta, no un texto en blanco, y asi la pantalla puede decirlo. */
UPDATE  [dbo].[Activo_Componente]
   SET  aco_numero_serie = NULLIF(LTRIM(RTRIM(ISNULL(@NUMERO_SERIE, ''))), ''),
        aco_fabricante   = NULLIF(LTRIM(RTRIM(ISNULL(@FABRICANTE, ''))), ''),
        aco_modelo       = NULLIF(LTRIM(RTRIM(ISNULL(@MODELO, ''))), ''),
        aco_usuario_actualizacion = @USUARIO,
        aco_fecha_actualizacion   = @NOW
 WHERE  aco_id = @ID
GO
PRINT '--- UPS_ACTIVO_COMPONENTE_PLACA creado.'
GO

/* ========================================================================
   Leer la placa. Por pieza para su ficha, o por activo para el centro: la
   lista de componentes muestra la placa de cada uno y pedirla de a una seria
   una consulta por fila.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE_PLACA]
    @CLIENTE     INT,
    @ACTIVO      INT = NULL,
    @COMPONENTE  INT = NULL
AS
SET NOCOUNT ON

    SELECT  c.aco_id                                  AS COMPONENTE_ID,
            ISNULL(c.aco_numero_serie, '')            AS NUMERO_SERIE,
            ISNULL(c.aco_fabricante, '')              AS FABRICANTE,
            ISNULL(c.aco_modelo, '')                  AS MODELO

    FROM    [dbo].[Activo_Componente] c

    WHERE   c.aco_cliente = @CLIENTE
      AND   (@ACTIVO IS NULL OR c.aco_activo = @ACTIVO)
      AND   (@COMPONENTE IS NULL OR c.aco_id = @COMPONENTE)
      AND   ISNULL(c.aco_habilitado, 1) = 1
GO
PRINT '--- SEL_ACTIVO_COMPONENTE_PLACA creado.'
GO

PRINT '288_COMPONENTE_PLACA aplicado.'
GO
