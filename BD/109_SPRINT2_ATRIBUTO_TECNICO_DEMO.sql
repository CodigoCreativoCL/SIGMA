USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2300 DATOS DE PRUEBA PARA ATRIBUTOS TECNICOS (HU-032).
-- =============================================
-- Va DESPUES de 108_SPRINT2_CODIGO_AUTO_ATRIBUTO.
--
-- Ejercita el propio INS_ATRIBUTO_TECNICO (con codigo automatico ATR-<id>).
-- IDEMPOTENTE: solo siembra si el cliente no tiene atributos aun.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT, @TIPO INT, @USUARIO INT, @NEW INT
DECLARE @TD_DEC INT, @TD_ENT INT, @TD_BIT INT, @UME_KW INT, @UME_V INT

SELECT TOP 1 @CLIENTE = t.ati_cliente, @TIPO = t.ati_id
FROM   [dbo].[Activo_Tipo] t WHERE t.ati_cliente IS NOT NULL AND t.ati_habilitado = 1
ORDER  BY t.ati_cliente, t.ati_id

SELECT TOP 1 @USUARIO = usu_id FROM [dbo].[Usuario] ORDER BY usu_id

SELECT @TD_DEC = tda_id FROM [dbo].[Tipo_Dato] WHERE tda_codigo = 'DECIMAL'
SELECT @TD_ENT = tda_id FROM [dbo].[Tipo_Dato] WHERE tda_codigo = 'ENTERO'
SELECT @TD_BIT = tda_id FROM [dbo].[Tipo_Dato] WHERE tda_codigo = 'BIT'
SELECT TOP 1 @UME_KW = ume_id FROM [dbo].[Unidad_Medida] ORDER BY ume_id

IF @CLIENTE IS NULL OR @TIPO IS NULL OR @TD_DEC IS NULL
BEGIN
    PRINT '--- Falta cliente/tipo/tipo de dato para sembrar. Se omite la demo.'
    RETURN
END

IF EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico] WHERE ate_cliente = @CLIENTE)
BEGIN
    PRINT '--- El cliente ya tiene atributos. Se omite la demo.'
    RETURN
END

EXEC [dbo].[INS_ATRIBUTO_TECNICO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=@TIPO,
     @TIPO_DATO=@TD_DEC, @UNIDAD_MEDIDA=@UME_KW, @CODIGO=N'AUTO', @NOMBRE=N'Potencia', @ORDEN=1, @USUARIO=@USUARIO
EXEC [dbo].[INS_ATRIBUTO_TECNICO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=@TIPO,
     @TIPO_DATO=@TD_ENT, @UNIDAD_MEDIDA=NULL, @CODIGO=N'AUTO', @NOMBRE=N'Voltaje nominal', @ORDEN=2, @USUARIO=@USUARIO
EXEC [dbo].[INS_ATRIBUTO_TECNICO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=NULL,
     @TIPO_DATO=@TD_BIT, @UNIDAD_MEDIDA=NULL, @CODIGO=N'AUTO', @NOMBRE=N'Requiere certificación', @ORDEN=3, @USUARIO=@USUARIO

PRINT '--- Atributos tecnicos sembrados para el cliente ' + LTRIM(STR(@CLIENTE)) + ' (proceso ejercitado).'
GO


/* ========================================================================
   COMPROBACION - los codigos deben venir ATR-<id> (no 'AUTO')
   ======================================================================== */
SELECT ate_id, ate_cliente, ate_activo_tipo, ate_tipo_dato, ate_codigo, ate_nombre, ate_habilitado
FROM   [dbo].[Atributo_Tecnico]
ORDER  BY ate_id
GO

PRINT '109_SPRINT2_ATRIBUTO_TECNICO_DEMO aplicado.'
GO
