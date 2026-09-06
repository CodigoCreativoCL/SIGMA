USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - GRABA UN DATO TECNICO DESDE EL ACTIVO (two-way).
-- =============================================
-- Al agregar un dato en el activo (nombre + unidad + valor), si el atributo no
-- existe para el tipo, se CREA en Atributo_Tecnico (asi aparece en el catalogo
-- y en las demas maquinas del tipo). Luego se guarda el VALOR + UNIDAD en
-- Activo_Atributo. Si @ATRIBUTO viene informado, se usa ese (dato existente).
-- Valor vacio = se quita el valor del activo (el atributo del catalogo se mantiene).
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[GRABAR_DATO_ACTIVO]
@ACTIVO   INT,
@ATRIBUTO INT = NULL,
@NOMBRE   NVARCHAR(200) = NULL,
@UNIDAD   INT = NULL,
@VALOR    NVARCHAR(MAX),
@USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @TIPO INT, @NOW DATETIME, @PAIS INT, @TD INT
SELECT @CLIENTE = act_cliente, @TIPO = act_activo_tipo FROM [dbo].[Activo] WHERE act_id = @ACTIVO
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @VALOR  = LTRIM(RTRIM(ISNULL(@VALOR, '')))
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, '')))

-- 1) Resolver el atributo (buscar o crear por nombre en el tipo del activo).
IF (@ATRIBUTO IS NULL OR @ATRIBUTO = 0)
BEGIN
    IF @NOMBRE = '' RETURN   -- sin nombre no hay dato
    SELECT @ATRIBUTO = ate_id FROM [dbo].[Atributo_Tecnico]
    WHERE  ate_cliente = @CLIENTE AND ate_activo_tipo = @TIPO AND ate_nombre = @NOMBRE AND ate_habilitado = 1

    IF @ATRIBUTO IS NULL
    BEGIN
        -- tipo de dato: numero si el valor es numerico o si trae unidad; si no, texto.
        SET @TD = CASE WHEN TRY_CONVERT(DECIMAL(18,4), REPLACE(@VALOR, ',', '.')) IS NOT NULL OR @UNIDAD IS NOT NULL
                       THEN 3 ELSE 1 END
        DECLARE @tmp NVARCHAR(40) = CONVERT(NVARCHAR(36), NEWID())
        INSERT [dbo].[Atributo_Tecnico]
            (ate_cliente, ate_activo_tipo, ate_tipo_dato, ate_unidad_medida, ate_codigo, ate_nombre,
             ate_orden, ate_usuario_creacion, ate_fecha_creacion, ate_habilitado)
        VALUES
            (@CLIENTE, @TIPO, @TD, NULL, @tmp, @NOMBRE, 999, @USUARIO, @NOW, 1)
        SET @ATRIBUTO = SCOPE_IDENTITY()
        UPDATE [dbo].[Atributo_Tecnico] SET ate_codigo = 'ATR-' + CAST(@ATRIBUTO AS VARCHAR(10)) WHERE ate_id = @ATRIBUTO
    END
END

-- 2) Valor vacio: quitar el valor del activo (el atributo del catalogo se conserva).
IF @VALOR = ''
BEGIN
    DELETE FROM [dbo].[Activo_Atributo] WHERE aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO
    RETURN
END

-- 3) Guardar el valor segun el tipo de dato del atributo.
SELECT @TD = ate_tipo_dato FROM [dbo].[Atributo_Tecnico] WHERE ate_id = @ATRIBUTO

DECLARE @vtexto NVARCHAR(MAX) = NULL, @vnum DECIMAL(18,4) = NULL, @vfecha DATETIME = NULL, @vbit BIT = NULL
IF @TD = 1       SET @vtexto = @VALOR
ELSE IF @TD IN (2,3) SET @vnum = TRY_CONVERT(DECIMAL(18,4), REPLACE(@VALOR, ',', '.'))
ELSE IF @TD = 4  SET @vbit = CASE WHEN @VALOR IN ('1','true','TRUE','SI','Si','si','Sí','sí') THEN 1 ELSE 0 END
ELSE             SET @vfecha = TRY_CONVERT(DATETIME, @VALOR)

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Atributo] WHERE aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO)
    UPDATE [dbo].[Activo_Atributo]
    SET    aat_valor_texto = @vtexto, aat_valor_numero = @vnum, aat_valor_fecha = @vfecha, aat_valor_bit = @vbit,
           aat_unidad_medida = @UNIDAD, aat_usuario_actualizacion = @USUARIO, aat_fecha_actualizacion = @NOW, aat_habilitado = 1
    WHERE  aat_activo = @ACTIVO AND aat_atributo_tecnico = @ATRIBUTO
ELSE
    INSERT [dbo].[Activo_Atributo]
        (aat_cliente, aat_activo, aat_atributo_tecnico, aat_unidad_medida,
         aat_valor_texto, aat_valor_numero, aat_valor_fecha, aat_valor_bit,
         aat_usuario_creacion, aat_fecha_creacion, aat_habilitado)
    VALUES
        (@CLIENTE, @ACTIVO, @ATRIBUTO, @UNIDAD,
         @vtexto, @vnum, @vfecha, @vbit,
         @USUARIO, @NOW, 1)
GO

PRINT '154_SPRINT3_GRABAR_DATO_ACTIVO aplicado.';
GO
