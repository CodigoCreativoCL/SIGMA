USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - AJUSTA LA JERARQUIA DE UBICACION DEL EQUIPO.
-- =============================================
-- Va DESPUES de 137_SPRINT3_FIX_MODELADORA_COMPONENTE.
--
-- La ubicacion esperada es:  Hamburgo S.A. (sitio) -> area Panaderia ->
-- sub-area Linea 1 -> Modeladora.  En 137 quedo plano (planta "Panaderia" /
-- area "Linea 1"); aqui se reencadena:
--   * La planta (Cliente_Instalacion) pasa a llamarse "Hamburgo S.A.".
--   * "Panaderia" se crea como AREA (padre NULL).
--   * "Linea 1" pasa a colgar de "Panaderia" (sub-area).
--   * La Modeladora se ubica en la sub-area mas profunda (Linea 1).
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 9,
        @PLANTA INT, @AREA_PAN INT = NULL, @AREA_L1 INT = NULL, @NEW INT = NULL;

/* 1) La planta = sitio Hamburgo S.A. */
SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE ORDER BY cin_id;

UPDATE [dbo].[Cliente_Instalacion]
SET    cin_nombre = N'Hamburgo S.A.', cin_descripcion = N'Sitio principal de Hamburgo S.A.'
WHERE  cin_id = @PLANTA;

/* 2) "Panaderia" como AREA (padre NULL, tipo AREA=1). */
SELECT @AREA_PAN = iar_id FROM [dbo].[Instalacion_Area]
WHERE  iar_cliente_instalacion = @PLANTA AND iar_nombre = N'Panaderia' AND iar_area_padre IS NULL;

IF @AREA_PAN IS NULL
BEGIN
    EXEC [dbo].[INS_INSTALACION_AREA]
         @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
         @AREA_PADRE = NULL, @INSTALACION_AREA_TIPO = 1,   -- Area
         @CODIGO = N'AR-PAN', @NOMBRE = N'Panaderia',
         @DESCRIPCION = N'Area de panaderia.', @USUARIO = @USUARIO;
    SET @AREA_PAN = @NEW;
END

/* 3) "Linea 1" como SUB-AREA de Panaderia (tipo LINEA PRODUCCION=3). */
SELECT @AREA_L1 = iar_id FROM [dbo].[Instalacion_Area]
WHERE  iar_cliente_instalacion = @PLANTA AND iar_nombre = N'Linea 1';

IF @AREA_L1 IS NULL
BEGIN
    EXEC [dbo].[INS_INSTALACION_AREA]
         @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
         @AREA_PADRE = @AREA_PAN, @INSTALACION_AREA_TIPO = 3,  -- Linea de produccion
         @CODIGO = N'LN-1', @NOMBRE = N'Linea 1',
         @DESCRIPCION = N'Linea de produccion 1.', @USUARIO = @USUARIO;
    SET @AREA_L1 = @NEW;
END
ELSE
    UPDATE [dbo].[Instalacion_Area]
    SET    iar_area_padre = @AREA_PAN, iar_instalacion_area_tipo = 3
    WHERE  iar_id = @AREA_L1;

/* 4) La Modeladora se ubica en Linea 1 (la sub-area mas profunda). */
UPDATE [dbo].[Activo]
SET    act_cliente_instalacion = @PLANTA, act_instalacion_area = @AREA_L1
WHERE  act_codigo = 'ACT-33' AND act_cliente = @CLIENTE;

PRINT '--- Ubicacion reencadenada: Hamburgo S.A. -> Panaderia -> Linea 1 -> Modeladora.';
GO

/* ========================================================================
   COMPROBACION
   ======================================================================== */
SELECT 'PLANTA' AS nivel, ci.cin_id AS id, ci.cin_nombre AS nombre, NULL AS padre
FROM   [dbo].[Cliente_Instalacion] ci WHERE ci.cin_cliente = 1
UNION ALL
SELECT 'AREA', ia.iar_id, ia.iar_nombre, ia.iar_area_padre
FROM   [dbo].[Instalacion_Area] ia
WHERE  ia.iar_cliente_instalacion = (SELECT TOP 1 cin_id FROM Cliente_Instalacion WHERE cin_cliente=1 ORDER BY cin_id)
ORDER  BY nivel, id;

SELECT act_codigo, act_nombre, act_cliente_instalacion, act_instalacion_area
FROM   [dbo].[Activo] WHERE act_codigo = 'ACT-33';
GO

PRINT '138_SPRINT3_FIX_UBICACION aplicado.';
GO
