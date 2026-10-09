SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* Semilla de PRUEBA para la bandeja de Avisos (BD/397). Solo desarrollo; idempotente.
   Crea fallas, hallazgos y alertas de ejemplo en el cliente 1 (Hamburgo). */
SET NOCOUNT ON
DECLARE @ID INT
IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_titulo = N'El horno no mantiene la temperatura de consigna')
    EXEC [dbo].[INS_FALLA] @ID = @ID OUTPUT, @CLIENTE = 1, @ACTIVO = 3, @CRITICIDAD_NIVEL = 4, @TITULO = N'El horno no mantiene la temperatura de consigna',
         @DESCRIPCION = N'Baja 25 °C bajo la consigna a los 20 minutos de cargar. Se detuvo la línea 1 por 40 minutos.', @DETUVO_PRODUCCION = 1, @ESTADO_POSTERIOR = 3, @USUARIO = 1
IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_titulo = N'Ruido metálico en la amasadora al subir de velocidad')
    EXEC [dbo].[INS_FALLA] @ID = @ID OUTPUT, @CLIENTE = 1, @ACTIVO = 4, @CRITICIDAD_NIVEL = 3, @TITULO = N'Ruido metálico en la amasadora al subir de velocidad',
         @DESCRIPCION = N'Se oye al pasar de velocidad 1 a 2. Sigue operando.', @DETUVO_PRODUCCION = 0, @USUARIO = 1
IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_titulo = N'Fuga de refrigerante en el compresor Copeland')
    EXEC [dbo].[INS_FALLA] @ID = @ID OUTPUT, @CLIENTE = 1, @ACTIVO = 6, @CRITICIDAD_NIVEL = 2, @TITULO = N'Fuga de refrigerante en el compresor Copeland',
         @DESCRIPCION = N'Mancha de aceite en la unión de succión.', @DETUVO_PRODUCCION = 0, @USUARIO = 1
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo] WHERE cha_titulo = N'Temperatura de descarga 104 °C · el máximo es 100 °C')
    INSERT INTO [dbo].[Checklist_Hallazgo] (cha_cliente, cha_activo, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado, cha_usuario_creacion, cha_fecha_creacion)
    VALUES (1, 7, N'Temperatura de descarga 104 °C · el máximo es 100 °C', N'Ítem «Temperatura de descarga» fuera de umbral en la inspección.', 4, 1, 1, [dbo].[FNC_AHORA]())
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo] WHERE cha_titulo = N'Fuga de aire en la unión de entrada de la cámara')
    INSERT INTO [dbo].[Checklist_Hallazgo] (cha_cliente, cha_activo, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado, cha_usuario_creacion, cha_fecha_creacion)
    VALUES (1, 5, N'Fuga de aire en la unión de entrada de la cámara', N'Ítem «Sellos de puerta» no cumple. Fuga audible.', 3, 1, 1, [dbo].[FNC_AHORA]())
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] WHERE ale_titulo = N'Presión diferencial del separador 0,92 bar · alerta en 0,90')
    INSERT INTO [dbo].[Alerta] (ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_severidad, ale_titulo, ale_descripcion, ale_activo, ale_usuario_creacion)
    VALUES (1, 1, 1, 3, N'Presión diferencial del separador 0,92 bar · alerta en 0,90', N'Tres lecturas seguidas sobre el umbral de alerta.', 6, 1)
GO
PRINT '_SEMILLA_AVISOS aplicada.'
GO
