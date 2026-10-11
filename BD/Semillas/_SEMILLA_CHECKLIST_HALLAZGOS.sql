USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA HALLAZGOS DE CHECKLIST (T-4087).
-- =============================================
-- ESTO NO ES UNA MIGRACION. El hallazgo real lo abre el telefono cuando una
-- respuesta sale de rango (bloque 156). Aqui se agregan tres mas sobre la
-- ejecucion que ya existe, con severidades y estados distintos, para que la
-- bandeja tenga que filtrar. Idempotente por titulo.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @EJEC INT = (SELECT TOP 1 cej_id FROM [dbo].[Checklist_Ejecucion] WHERE cej_cliente = @CLIENTE AND cej_checklist_ejecucion_estado = 3 ORDER BY cej_id)
DECLARE @ACT INT = (SELECT cej_activo FROM [dbo].[Checklist_Ejecucion] WHERE cej_id = @EJEC)
DECLARE @HORNO INT = (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = 'ACT-34')
DECLARE @OT INT = (SELECT TOP 1 otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_activo = @HORNO ORDER BY otr_id)

IF (@EJEC IS NULL OR @USUARIO IS NULL)
BEGIN
    RAISERROR('1.- NO HAY UNA EJECUCION DE CHECKLIST CERRADA (BLOQUE 157).', 16, 1)
    RETURN
END

-- El que ya existe queda con severidad, para que no salga en blanco
UPDATE [dbo].[Checklist_Hallazgo] SET cha_severidad = 4 WHERE cha_cliente = @CLIENTE AND cha_severidad IS NULL

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo] WHERE cha_cliente = @CLIENTE AND cha_titulo = N'Fuga de aceite en reductor (semilla)')
    INSERT INTO [dbo].[Checklist_Hallazgo]
        (cha_uuid, cha_cliente, cha_checklist_ejecucion, cha_activo, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado,
         cha_generado_ia, cha_usuario_creacion, cha_fecha_creacion, cha_habilitado)
    VALUES (NEWID(), @CLIENTE, @EJEC, @ACT, N'Fuga de aceite en reductor (semilla)', N'Goteo constante en el sello de salida. Piso con aceite.',
            5, 1, 0, @USUARIO, DATEADD(DAY, -3, GETDATE()), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo] WHERE cha_cliente = @CLIENTE AND cha_titulo = N'Ruido en rodamiento ventilador (semilla)')
    INSERT INTO [dbo].[Checklist_Hallazgo]
        (cha_uuid, cha_cliente, cha_checklist_ejecucion, cha_activo, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado,
         cha_generado_ia, cha_confianza_ia, cha_orden_trabajo, cha_usuario_confirmacion, cha_fecha_confirmacion_utc,
         cha_usuario_creacion, cha_fecha_creacion, cha_habilitado)
    VALUES (NEWID(), @CLIENTE, @EJEC, ISNULL(@HORNO, @ACT), N'Ruido en rodamiento ventilador (semilla)', N'Detectado por el análisis de audio: patrón compatible con rodamiento dañado.',
            3, 3, 1, 0.87, @OT, @USUARIO, DATEADD(DAY, -2, GETUTCDATE()),
            @USUARIO, DATEADD(DAY, -5, GETDATE()), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo] WHERE cha_cliente = @CLIENTE AND cha_titulo = N'Lectura de temperatura dudosa (semilla)')
    INSERT INTO [dbo].[Checklist_Hallazgo]
        (cha_uuid, cha_cliente, cha_checklist_ejecucion, cha_activo, cha_titulo, cha_descripcion, cha_severidad, cha_proceso_estado,
         cha_generado_ia, cha_motivo_descarte, cha_usuario_confirmacion, cha_fecha_confirmacion_utc,
         cha_usuario_creacion, cha_fecha_creacion, cha_habilitado)
    VALUES (NEWID(), @CLIENTE, @EJEC, @ACT, N'Lectura de temperatura dudosa (semilla)', N'Valor fuera de rango por sensor mal apoyado; se repitió la medición y quedó normal.',
            2, 5, 0, N'Falso positivo: error de medición confirmado en terreno.', @USUARIO, DATEADD(DAY, -1, GETUTCDATE()),
            @USUARIO, DATEADD(DAY, -1, GETDATE()), 1)
GO

SELECT cha_titulo COLLATE DATABASE_DEFAULT + ' · sev ' + CAST(cha_severidad AS VARCHAR) + ' · estado ' + CAST(cha_proceso_estado AS VARCHAR) AS RESULTADO
FROM [dbo].[Checklist_Hallazgo] WHERE cha_cliente = 1 ORDER BY cha_id
GO
