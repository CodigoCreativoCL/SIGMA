USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2268 DATOS DE PRUEBA PARA ADMINISTRAR MODELOS DE ACTIVO (HU-031).
-- =============================================
-- Va DESPUES de 104_SPRINT2_ACTIVO_MODELO.
--
-- Ejercita el propio INS_ACTIVO_MODELO (no INSERT directo): asi la carga de
-- prueba pasa por las mismas reglas que la pantalla. Es IDEMPOTENTE: solo
-- siembra si el cliente todavia no tiene modelos propios de ese tipo.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT, @TIPO INT, @USUARIO INT, @NEW INT

-- Un cliente con al menos un tipo de activo y un usuario, para la demo.
SELECT TOP 1 @CLIENTE = t.ati_cliente, @TIPO = t.ati_id
FROM   [dbo].[Activo_Tipo] t
WHERE  t.ati_cliente IS NOT NULL AND t.ati_habilitado = 1
ORDER  BY t.ati_cliente, t.ati_id

SELECT TOP 1 @USUARIO = usu_id FROM [dbo].[Usuario] ORDER BY usu_id

IF @CLIENTE IS NULL OR @TIPO IS NULL
BEGIN
    PRINT '--- No hay tipo de activo de cliente para sembrar. Se omite la demo.'
    RETURN
END

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo] WHERE amo_cliente = @CLIENTE AND amo_activo_tipo = @TIPO)
BEGIN
    PRINT '--- El cliente ya tiene modelos para ese tipo. Se omite la demo.'
    RETURN
END

EXEC [dbo].[INS_ACTIVO_MODELO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=@TIPO,
     @FABRICANTE=N'WEG',   @NOMBRE=N'W22 132S', @DESCRIPCION=N'Motor trifásico 7.5 kW, IE3.', @USUARIO=@USUARIO
EXEC [dbo].[INS_ACTIVO_MODELO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=@TIPO,
     @FABRICANTE=N'Siemens', @NOMBRE=N'1LE0', @DESCRIPCION=N'Motor de baja tensión, línea SIMOTICS.', @USUARIO=@USUARIO
EXEC [dbo].[INS_ACTIVO_MODELO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE, @ACTIVO_TIPO=@TIPO,
     @FABRICANTE=NULL,       @NOMBRE=N'Genérico estándar', @DESCRIPCION=NULL, @USUARIO=@USUARIO

PRINT '--- Modelos de activo sembrados para el cliente ' + LTRIM(STR(@CLIENTE)) + ' (proceso ejercitado).'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */
SELECT amo_id, amo_cliente, amo_activo_tipo, amo_fabricante, amo_nombre, amo_habilitado
FROM   [dbo].[Activo_Modelo]
ORDER  BY amo_id
GO

PRINT '105_SPRINT2_ACTIVO_MODELO_DEMO aplicado.'
GO
