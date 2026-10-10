/* ============================================================================
   423 · Parte f · SIGMA AI Chat y SIGMA Twin según el plan comercial (09-10-2026)

   Hasta ahora el menú SIGMA Twin y el chat de SIGMA AI solo dependían del permiso del perfil.
   Ahora además dependen de que el plan comercial del cliente los incluya (con la excepción por
   cliente de siempre: la fila con pcf_cliente gana, FNC_CLIENTE_TIENE_FUNCIONALIDAD).
     · Funcionalidad: SIGMA AI CHAT y SIGMA TWIN (tipo INCLUSION).
     · Plan_Comercial_Funcionalidad: Básico ninguno · Medio el chat · Full los dos.
       (Se cambia en Comercial › Planes, como cualquier otra funcionalidad.)
     · SEL_CLIENTE_FUNCIONALIDADES(@CLIENTE): qué incluye el plan del cliente (lo cachea la sesión).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SIGMA AI CHAT')
    INSERT [dbo].[Funcionalidad] (fun_codigo, fun_nombre, fun_orden, fun_habilitado) VALUES (N'SIGMA AI CHAT', N'SIGMA AI Chat: asistente conversacional', 27, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SIGMA TWIN')
    INSERT [dbo].[Funcionalidad] (fun_codigo, fun_nombre, fun_orden, fun_habilitado) VALUES (N'SIGMA TWIN', N'SIGMA Twin: gemelo digital de bodegas en 3D', 28, 1)
GO
DECLARE @CHAT INT = (SELECT fun_id FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SIGMA AI CHAT'),
        @TWIN INT = (SELECT fun_id FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SIGMA TWIN')
DECLARE @R TABLE (pl VARCHAR(20), fun INT, inc BIT)
INSERT @R VALUES ('BASICO', @CHAT, 0), ('BASICO', @TWIN, 0), ('MEDIO', @CHAT, 1), ('MEDIO', @TWIN, 0), ('FULL', @CHAT, 1), ('FULL', @TWIN, 1)
INSERT [dbo].[Plan_Comercial_Funcionalidad] (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo, pcf_incluida, pcf_usuario_creacion, pcf_fecha_creacion, pcf_habilitado)
SELECT  p.plc_id, r.fun, NULL, 1, r.inc, 1, [dbo].[FNC_AHORA](), 1
FROM    @R r JOIN [dbo].[Plan_Comercial] p ON p.plc_codigo = r.pl
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] x WHERE x.pcf_plan_comercial = p.plc_id AND x.pcf_funcionalidad = r.fun AND x.pcf_cliente IS NULL)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_FUNCIONALIDADES]
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @PLAN INT = (SELECT TOP 1 sus_plan_comercial FROM [dbo].[Suscripcion] WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1)
SELECT  f.fun_codigo AS CODIGO, CAST(CASE WHEN @PLAN IS NULL THEN 1 ELSE [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](@CLIENTE, f.fun_codigo) END AS BIT) AS INCLUIDA,
        CAST(CASE WHEN @PLAN IS NULL THEN 0 ELSE 1 END AS BIT) AS CON_PLAN
FROM    [dbo].[Funcionalidad] f
WHERE   f.fun_habilitado = 1
RETURN 0
GO
PRINT '423_FUNCIONALIDAD_AI_CHAT_TWIN aplicado.'
GO
