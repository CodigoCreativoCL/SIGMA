USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     UNA PAUTA PUBLICADA Y SU OCURRENCIA, PARA PROBAR HU-095.
-- =============================================
-- POR QUE HACE FALTA
--
--   Checklist_Plantilla tenia 0 filas. Con el catalogo vacio, la bandeja de
--   pautas de la app devuelve nada y el sintoma es indistinguible de un fallo
--   de la API.
--
-- LA PAUTA ES DE VERDAD
--
--   Seis items que cubren los tipos que el terreno usa de verdad: SI/NO,
--   medicion con rango, seleccion, texto y fotografia. Uno de ellos
--   -vibracion- lleva rango 0 a 4,5 mm/s y `genera_hallazgo`, para poder
--   comprobar que un valor fuera de norma abre el Checklist_Hallazgo solo.
--
-- ES REEJECUTABLE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE     INT = 1
DECLARE @ROOT        INT = 1
DECLARE @INSTALACION INT = (SELECT TOP 1 [cin_id] FROM [dbo].[Cliente_Instalacion]
                             WHERE [cin_cliente] = @CLIENTE AND [cin_habilitado] = 1
                             ORDER BY [cin_id])
DECLARE @ACTIVO      INT = (SELECT TOP 1 [act_id] FROM [dbo].[Activo]
                             WHERE [act_cliente_instalacion] = @INSTALACION
                               AND [act_habilitado] = 1
                             ORDER BY [act_id])
DECLARE @UME_MM      INT = (SELECT TOP 1 [ume_id] FROM [dbo].[Unidad_Medida] ORDER BY [ume_id])


-- ---------------------------------------------------------------------------
-- 1 - LA PLANTILLA Y SU VERSION PUBLICADA
-- ---------------------------------------------------------------------------
DECLARE @CPL INT = (SELECT [cpl_id] FROM [dbo].[Checklist_Plantilla]
                     WHERE [cpl_cliente] = @CLIENTE AND [cpl_codigo] = N'CHK-RONDA-MOT')

IF @CPL IS NULL
BEGIN
    INSERT INTO [dbo].[Checklist_Plantilla]
        ([cpl_cliente], [cpl_cliente_instalacion], [cpl_codigo], [cpl_nombre]
        ,[cpl_descripcion], [cpl_usuario_creacion], [cpl_fecha_creacion], [cpl_habilitado])
    VALUES
        (@CLIENTE, @INSTALACION, N'CHK-RONDA-MOT', N'Ronda diaria de motobombas'
        ,N'Inspeccion visual y de condicion al inicio de turno.'
        ,@ROOT, GETDATE(), 1)

    SET @CPL = SCOPE_IDENTITY()
END

DECLARE @CPV INT = (SELECT TOP 1 [cpv_id] FROM [dbo].[Checklist_Plantilla_Version]
                     WHERE [cpv_checklist_plantilla] = @CPL AND [cpv_numero] = 1)

IF @CPV IS NULL
BEGIN
    INSERT INTO [dbo].[Checklist_Plantilla_Version]
        ([cpv_checklist_plantilla], [cpv_numero], [cpv_checklist_version_estado]
        ,[cpv_fecha_publicacion], [cpv_usuario_publicacion]
        ,[cpv_usuario_creacion], [cpv_fecha_creacion], [cpv_habilitado])
    VALUES
        (@CPL, 1, 2                    -- 2 PUBLICADO
        ,GETDATE(), @ROOT
        ,@ROOT, GETDATE(), 1)

    SET @CPV = SCOPE_IDENTITY()
END


-- ---------------------------------------------------------------------------
-- 2 - SECCIONES E ITEMS
-- ---------------------------------------------------------------------------
DECLARE @SEC_VIS INT = (SELECT [cps_id] FROM [dbo].[Checklist_Plantilla_Seccion]
                         WHERE [cps_checklist_plantilla_version] = @CPV AND [cps_codigo] = N'VIS')
IF @SEC_VIS IS NULL
BEGIN
    INSERT INTO [dbo].[Checklist_Plantilla_Seccion]
        ([cps_checklist_plantilla_version], [cps_codigo], [cps_nombre], [cps_orden]
        ,[cps_usuario_creacion], [cps_fecha_creacion], [cps_habilitado])
    VALUES (@CPV, N'VIS', N'Inspeccion visual', 1, @ROOT, GETDATE(), 1)
    SET @SEC_VIS = SCOPE_IDENTITY()
END

DECLARE @SEC_CON INT = (SELECT [cps_id] FROM [dbo].[Checklist_Plantilla_Seccion]
                         WHERE [cps_checklist_plantilla_version] = @CPV AND [cps_codigo] = N'CON')
IF @SEC_CON IS NULL
BEGIN
    INSERT INTO [dbo].[Checklist_Plantilla_Seccion]
        ([cps_checklist_plantilla_version], [cps_codigo], [cps_nombre], [cps_orden]
        ,[cps_usuario_creacion], [cps_fecha_creacion], [cps_habilitado])
    VALUES (@CPV, N'CON', N'Condicion', 2, @ROOT, GETDATE(), 1)
    SET @SEC_CON = SCOPE_IDENTITY()
END

/* Los items. El tipo sale del catalogo Checklist_Item_Tipo:
   5 = SI/NO, 4 = DECIMAL, 9 = SELECCION SIMPLE, 2 = TEXTO LARGO, 12 = FOTO. */
DECLARE @ITEMS TABLE (
     [codigo] NVARCHAR(100), [texto] NVARCHAR(1000), [tipo] INT
    ,[seccion] INT, [orden] INT, [oblig] BIT, [voz] NVARCHAR(400)
)

INSERT INTO @ITEMS VALUES
     (N'FUGA',  N'¿Hay fugas visibles en el sello?',        5, @SEC_VIS, 1, 1, N'¿hay fugas?')
    ,(N'RUIDO', N'¿El equipo opera sin ruidos anormales?',  5, @SEC_VIS, 2, 1, N'¿se escucha normal?')
    ,(N'VIBRA', N'Vibracion RMS en descanso lado acople',   4, @SEC_CON, 3, 1, N'vibracion')
    ,(N'TEMP',  N'Temperatura de descanso',                 4, @SEC_CON, 4, 1, N'temperatura')
    ,(N'ESTADO',N'Estado general del equipo',               9, @SEC_CON, 5, 0, NULL)
    ,(N'OBS',   N'Observaciones de la ronda',               2, @SEC_CON, 6, 0, N'observacion')

DECLARE @cod NVARCHAR(100), @txt NVARCHAR(1000), @tip INT,
        @sec INT, @ord INT, @obl BIT, @voz NVARCHAR(400)

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT [codigo], [texto], [tipo], [seccion], [orden], [oblig], [voz] FROM @ITEMS

OPEN cur
FETCH NEXT FROM cur INTO @cod, @txt, @tip, @sec, @ord, @obl, @voz

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item]
                    WHERE [cpi_checklist_plantilla_version] = @CPV AND [cpi_codigo] = @cod)
        INSERT INTO [dbo].[Checklist_Plantilla_Item]
            ([cpi_checklist_plantilla_version], [cpi_checklist_plantilla_seccion]
            ,[cpi_codigo], [cpi_texto], [cpi_checklist_item_tipo], [cpi_orden]
            ,[cpi_obligatorio], [cpi_permite_comentario], [cpi_requiere_evidencia]
            ,[cpi_genera_medicion], [cpi_unidad_medida], [cpi_pregunta_voz]
            ,[cpi_usuario_creacion], [cpi_fecha_creacion], [cpi_habilitado])
        VALUES
            (@CPV, @sec
            ,@cod, @txt, @tip, @ord
            ,@obl, 1, 0
            ,CASE WHEN @tip = 4 THEN 1 ELSE 0 END
            ,CASE WHEN @tip = 4 THEN @UME_MM ELSE NULL END
            ,@voz
            ,@ROOT, GETDATE(), 1)

    FETCH NEXT FROM cur INTO @cod, @txt, @tip, @sec, @ord, @obl, @voz
END

CLOSE cur
DEALLOCATE cur


-- ---------------------------------------------------------------------------
-- 3 - LA VALIDACION DE VIBRACION
-- ---------------------------------------------------------------------------
--   0 a 4,5 y genera hallazgo. Es la que permite comprobar que un valor fuera
--   de norma abre el Checklist_Hallazgo solo, sin que nadie lo pida.
-- ---------------------------------------------------------------------------
DECLARE @IT_VIBRA INT = (SELECT [cpi_id] FROM [dbo].[Checklist_Plantilla_Item]
                          WHERE [cpi_checklist_plantilla_version] = @CPV AND [cpi_codigo] = N'VIBRA')

IF @IT_VIBRA IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion]
                    WHERE [civ_checklist_plantilla_item] = @IT_VIBRA)
    INSERT INTO [dbo].[Checklist_Item_Validacion]
        ([civ_checklist_plantilla_item], [civ_valor_minimo], [civ_valor_maximo]
        ,[civ_requiere_comentario_fuera_rango], [civ_genera_alerta], [civ_genera_hallazgo]
        ,[civ_mensaje], [civ_usuario_creacion], [civ_fecha_creacion], [civ_habilitado])
    VALUES
        (@IT_VIBRA, 0, 4.5
        ,1, 1, 1
        ,N'Vibracion sobre norma ISO 10816 para este equipo.'
        ,@ROOT, GETDATE(), 1)

DECLARE @IT_TEMP INT = (SELECT [cpi_id] FROM [dbo].[Checklist_Plantilla_Item]
                         WHERE [cpi_checklist_plantilla_version] = @CPV AND [cpi_codigo] = N'TEMP')

IF @IT_TEMP IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion]
                    WHERE [civ_checklist_plantilla_item] = @IT_TEMP)
    INSERT INTO [dbo].[Checklist_Item_Validacion]
        ([civ_checklist_plantilla_item], [civ_valor_minimo], [civ_valor_maximo]
        ,[civ_requiere_comentario_fuera_rango], [civ_genera_hallazgo]
        ,[civ_mensaje], [civ_usuario_creacion], [civ_fecha_creacion], [civ_habilitado])
    VALUES
        (@IT_TEMP, 0, 75
        ,1, 0
        ,N'Temperatura sobre lo esperado para operacion continua.'
        ,@ROOT, GETDATE(), 1)


-- ---------------------------------------------------------------------------
-- 4 - LAS OPCIONES DEL ITEM DE SELECCION
-- ---------------------------------------------------------------------------
DECLARE @IT_EST INT = (SELECT [cpi_id] FROM [dbo].[Checklist_Plantilla_Item]
                        WHERE [cpi_checklist_plantilla_version] = @CPV AND [cpi_codigo] = N'ESTADO')

IF @IT_EST IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Opcion]
                    WHERE [cio_checklist_plantilla_item] = @IT_EST)
    INSERT INTO [dbo].[Checklist_Item_Opcion]
        ([cio_checklist_plantilla_item], [cio_codigo], [cio_texto], [cio_orden]
        ,[cio_es_conforme], [cio_requiere_comentario]
        ,[cio_usuario_creacion], [cio_fecha_creacion], [cio_habilitado])
    VALUES
         (@IT_EST, N'BUENO',    N'Bueno',              1, 1, 0, @ROOT, GETDATE(), 1)
        ,(@IT_EST, N'REGULAR',  N'Regular',            2, 1, 1, @ROOT, GETDATE(), 1)
        ,(@IT_EST, N'MALO',     N'Malo',               3, 0, 1, @ROOT, GETDATE(), 1)


-- ---------------------------------------------------------------------------
-- 5 - LA OCURRENCIA DE HOY
-- ---------------------------------------------------------------------------
DECLARE @UUID_OCU UNIQUEIDENTIFIER = 'D1D2D3D4-0001-4000-8000-000000000001'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia] WHERE [coc_uuid] = @UUID_OCU)
    INSERT INTO [dbo].[Checklist_Ocurrencia]
        ([coc_uuid], [coc_cliente], [coc_checklist_plantilla_version], [coc_activo]
        ,[coc_checklist_ocurrencia_estado], [coc_fecha_programada_utc]
        ,[coc_fecha_disponible_utc], [coc_fecha_limite_utc]
        ,[coc_usuario_creacion], [coc_fecha_creacion], [coc_habilitado])
    VALUES
        (@UUID_OCU, @CLIENTE, @CPV, @ACTIVO
        ,2, CAST(GETUTCDATE() AS DATE)          -- 2 DISPONIBLE
        ,CAST(GETUTCDATE() AS DATE), DATEADD(HOUR, 12, CAST(GETUTCDATE() AS DATE))
        ,@ROOT, GETDATE(), 1)


-- ---------------------------------------------------------------------------
-- 6 - VERIFICACION
-- ---------------------------------------------------------------------------
DECLARE @T INT = (SELECT TOP 1 [ciu_id_usuario] FROM [dbo].[Cliente_Instalacion_Usuario]
                   WHERE [ciu_habilitado] = 1 ORDER BY [ciu_id_usuario])

PRINT '--- Pendientes de la persona ---'
EXEC [dbo].[API_SEL_CHECKLIST] @USUARIO = @T, @CLIENTE = @CLIENTE, @TIPO = 1

PRINT '--- Items de la pauta ---'
EXEC [dbo].[API_SEL_CHECKLIST] @USUARIO = @T, @CLIENTE = @CLIENTE, @TIPO = 2, @ID = @CPV
GO
