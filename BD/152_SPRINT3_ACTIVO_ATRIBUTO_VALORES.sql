USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - VALOR DE LOS ATRIBUTOS TECNICOS POR ACTIVO.
-- =============================================
-- Atributo_Tecnico define los CAMPOS por tipo (Capacidad de tazon, kg). Aqui se
-- guarda el VALOR de cada campo para un activo concreto (Revolvedora 1 = 80 kg),
-- en Activo_Atributo. El valor se guarda en la columna segun el tipo de dato:
--   TEXTO(1)->aat_valor_texto  ENTERO(2)/DECIMAL(3)->aat_valor_numero
--   BIT(4)->aat_valor_bit      FECHA(5/6/7)->aat_valor_fecha
--
-- SEL: trae TODOS los atributos del tipo del activo (haya o no valor), para
--      pintar el formulario y la ficha.
-- GRABAR: upsert de un valor (vacio = se borra).
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* 1) SEL_ACTIVO_ATRIBUTO - atributos del tipo del activo + su valor (si existe). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ATRIBUTO]
@ACTIVO INT, @CLIENTE INT
AS
SET NOCOUNT ON
    DECLARE @TIPO INT
    SELECT @TIPO = act_activo_tipo FROM [dbo].[Activo] WHERE act_id = @ACTIVO

    SELECT  ate.ate_id                       AS ATE_ID,
            ate.ate_codigo                   AS ATE_CODIGO,
            ate.ate_nombre                   AS ATE_NOMBRE,
            ate.ate_tipo_dato                AS ATE_TIPO_DATO,
            LTRIM(ISNULL(u.ume_nombre + ISNULL(' (' + NULLIF(u.ume_simbolo,'') + ')',''), '')) AS UNIDAD,
            ISNULL(u.ume_simbolo,'')         AS UNIDAD_SIMBOLO,
            aat.aat_valor_texto              AS VALOR_TEXTO,
            aat.aat_valor_numero             AS VALOR_NUMERO,
            aat.aat_valor_bit                AS VALOR_BIT,
            aat.aat_valor_fecha              AS VALOR_FECHA
    FROM    [dbo].[Atributo_Tecnico] ate
    LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = ate.ate_unidad_medida
    LEFT JOIN [dbo].[Activo_Atributo] aat
           ON aat.aat_atributo_tecnico = ate.ate_id
          AND aat.aat_activo = @ACTIVO
          AND aat.aat_habilitado = 1
    WHERE   (ate.ate_cliente = @CLIENTE OR ate.ate_cliente IS NULL)
      AND   ate.ate_activo_tipo = @TIPO
      AND   ate.ate_habilitado = 1
    ORDER BY ISNULL(ate.ate_orden, 999), ate.ate_nombre, ate.ate_id
GO


/* 2) GRABAR_ACTIVO_ATRIBUTO - upsert del valor de un atributo para un activo. */
CREATE OR ALTER PROCEDURE [dbo].[GRABAR_ACTIVO_ATRIBUTO]
@ACTIVO   INT,
@ATRIBUTO INT,
@VALOR    NVARCHAR(MAX),
@USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @NOW DATETIME, @PAIS INT, @TD INT, @UNI INT
SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
SELECT @TD = ate_tipo_dato, @UNI = ate_unidad_medida FROM [dbo].[Atributo_Tecnico] WHERE ate_id = @ATRIBUTO
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @VALOR = LTRIM(RTRIM(ISNULL(@VALOR, '')))

-- Valor vacio: se quita el dato del activo.
IF @VALOR = ''
BEGIN
    DELETE FROM [dbo].[Activo_Atributo]
    WHERE aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO
    RETURN
END

DECLARE @vtexto NVARCHAR(MAX) = NULL, @vnum DECIMAL(18,4) = NULL, @vfecha DATETIME = NULL, @vbit BIT = NULL
IF @TD = 1
    SET @vtexto = @VALOR
ELSE IF @TD IN (2, 3)
    SET @vnum = TRY_CONVERT(DECIMAL(18,4), REPLACE(@VALOR, ',', '.'))
ELSE IF @TD = 4
    SET @vbit = CASE WHEN @VALOR IN ('1','true','TRUE','SI','Si','si','Sí','sí') THEN 1 ELSE 0 END
ELSE
    SET @vfecha = TRY_CONVERT(DATETIME, @VALOR)

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Atributo] WHERE aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO)
    UPDATE [dbo].[Activo_Atributo]
    SET    aat_valor_texto = @vtexto, aat_valor_numero = @vnum, aat_valor_fecha = @vfecha, aat_valor_bit = @vbit,
           aat_unidad_medida = @UNI, aat_usuario_actualizacion = @USUARIO, aat_fecha_actualizacion = @NOW, aat_habilitado = 1
    WHERE  aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO
ELSE
    INSERT [dbo].[Activo_Atributo]
        (aat_cliente, aat_activo, aat_atributo_tecnico, aat_unidad_medida,
         aat_valor_texto, aat_valor_numero, aat_valor_fecha, aat_valor_bit,
         aat_usuario_creacion, aat_fecha_creacion, aat_habilitado)
    VALUES
        (@CLIENTE, @ACTIVO, @ATRIBUTO, @UNI,
         @vtexto, @vnum, @vfecha, @vbit,
         @USUARIO, @NOW, 1)
GO

PRINT '152_SPRINT3_ACTIVO_ATRIBUTO_VALORES aplicado: SEL/GRABAR_ACTIVO_ATRIBUTO.';
GO
