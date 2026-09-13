USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     CONSULTAR LOS HALLAZGOS DE LOS CHECKLIST (HU-096).
-- =============================================
-- T-4084 · EL MODELO, REVISADO
--
--   `Checklist_Hallazgo` nace cuando una respuesta queda fuera de rango o
--   el tecnico marca no conforme (bloque 156, API_UPS_CHECKLIST_RESPUESTA).
--   Tiene uuid unico para el telefono, y NO tiene codigo: lo identifica su
--   uuid y su ejecucion + respuesta. El «indice unico del codigo dentro del
--   cliente» de la plantilla no aplica. Trae severidad, criticidad, el
--   estado de proceso (Proceso_Estado: pendiente, en proceso, procesado,
--   error, cancelado), si lo genero la IA y con que confianza, la OT si ya
--   se creo una, y quien lo confirmo o por que se descarto.
--
-- T-4086 · INDICES
--
--   Solo habia IX_CHA_PENDIENTE (cliente, fecha). La bandeja filtra por
--   estado de proceso y por severidad, y la ficha del equipo pide «sus
--   hallazgos»: se agregan cliente + estado + fecha, y activo + fecha.
--
-- T-4085 · SEL_CHECKLIST_HALLAZGO
--
--   Solo lectura, sin SQL armado, OFFSET/FETCH y TOTAL por fila, como el
--   calendario. Devuelve la respuesta que lo origino (valor, unidad, si
--   estaba fuera de rango) para que se entienda de donde salio sin ir a la
--   ejecucion.
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) Indices (T-4086)
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CHA_CLIENTE_ESTADO_FECHA' AND object_id = OBJECT_ID('dbo.Checklist_Hallazgo'))
    CREATE NONCLUSTERED INDEX [IX_CHA_CLIENTE_ESTADO_FECHA]
        ON [dbo].[Checklist_Hallazgo] ([cha_cliente], [cha_proceso_estado], [cha_fecha_creacion])
        INCLUDE ([cha_severidad], [cha_activo], [cha_habilitado])
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CHA_ACTIVO_FECHA' AND object_id = OBJECT_ID('dbo.Checklist_Hallazgo'))
    CREATE NONCLUSTERED INDEX [IX_CHA_ACTIVO_FECHA]
        ON [dbo].[Checklist_Hallazgo] ([cha_activo], [cha_fecha_creacion])
        INCLUDE ([cha_proceso_estado], [cha_severidad], [cha_habilitado])
GO

-- ---------------------------------------------------------------------------
-- 2) SEL_CHECKLIST_HALLAZGO (T-4085)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_HALLAZGO]
@ID          INT = NULL,
@CLIENTE     INT,
@INSTALACION INT = NULL,
@ACTIVO      INT = NULL,
@SEVERIDAD   INT = NULL,
@ESTADO      INT = NULL,
@DESDE       DATE = NULL,
@HASTA       DATE = NULL,
@FILTRO      NVARCHAR(200) = NULL,
@PAGINA      INT = NULL,
@TAMANO      INT = NULL

AS
SET NOCOUNT ON

IF (@PAGINA IS NULL OR @PAGINA < 1) SET @PAGINA = 1
IF (@TAMANO IS NULL OR @TAMANO < 1) SET @TAMANO = 1000000

SELECT  cha.cha_id                      AS CHA_ID,
        cha.cha_uuid                    AS CHA_UUID,
        cha.cha_titulo                  AS CHA_TITULO,
        cha.cha_descripcion             AS CHA_DESCRIPCION,
        cha.cha_fecha_creacion          AS CHA_FECHA_CREACION,
        cha.cha_generado_ia             AS CHA_GENERADO_IA,
        cha.cha_confianza_ia            AS CHA_CONFIANZA_IA,
        cha.cha_motivo_descarte         AS CHA_MOTIVO_DESCARTE,
        cha.cha_fecha_confirmacion_utc  AS CHA_FECHA_CONFIRMACION,
        cha.cha_habilitado              AS CHA_HABILITADO,
        sev.sev_id                      AS SEVERIDAD_ID,
        sev.sev_codigo                  AS SEVERIDAD_CODIGO,
        sev.sev_nombre                  AS SEVERIDAD_NOMBRE,
        crn.crn_nombre                  AS CRITICIDAD_NOMBRE,
        pes.pes_id                      AS ESTADO_ID,
        pes.pes_codigo                  AS ESTADO_CODIGO,
        pes.pes_nombre                  AS ESTADO_NOMBRE,
        act.act_id                      AS ACTIVO_ID,
        act.act_codigo                  AS ACTIVO_CODIGO,
        act.act_nombre                  AS ACTIVO_NOMBRE,
        cin.cin_nombre                  AS PLANTA_NOMBRE,
        aco.aco_nombre                  AS COMPONENTE_NOMBRE,
        cej.cej_id                      AS EJECUCION_ID,
        cej.cej_fecha_fin_utc           AS EJECUCION_FECHA,
        cpl.cpl_codigo                  AS PLANTILLA_CODIGO,
        cpl.cpl_nombre                  AS PLANTILLA_NOMBRE,
        LTRIM(RTRIM(ISNULL(ue.usu_nombre,'') + ' ' + ISNULL(ue.usu_apellido_paterno,''))) AS EJECUTOR_NOMBRE,
        cpi.cpi_texto                   AS ITEM_TEXTO,
        cer.cer_valor_texto             AS RESPUESTA_TEXTO,
        cer.cer_valor_numero            AS RESPUESTA_NUMERO,
        ume.ume_simbolo                 AS RESPUESTA_UNIDAD,
        cer.cer_fuera_rango             AS RESPUESTA_FUERA_RANGO,
        cer.cer_comentario              AS RESPUESTA_COMENTARIO,
        otr.otr_id                      AS ORDEN_TRABAJO_ID,
        otr.otr_correlativo             AS ORDEN_TRABAJO_CORRELATIVO,
        ote.ote_nombre                  AS ORDEN_TRABAJO_ESTADO,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS CONFIRMADOR_NOMBRE,
        COUNT(*) OVER ()                AS TOTAL
FROM    [dbo].[Checklist_Hallazgo]          cha
JOIN    [dbo].[Checklist_Ejecucion]         cej ON cej.cej_id = cha.cha_checklist_ejecucion
LEFT JOIN [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = cej.cej_checklist_plantilla_version
LEFT JOIN [dbo].[Checklist_Plantilla]       cpl ON cpl.cpl_id = cpv.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_id = cha.cha_checklist_ejecucion_respuesta
LEFT JOIN [dbo].[Checklist_Plantilla_Item]  cpi ON cpi.cpi_id = cer.cer_checklist_plantilla_item
LEFT JOIN [dbo].[Unidad_Medida]             ume ON ume.ume_id = cer.cer_unidad_medida
LEFT JOIN [dbo].[Severidad]                 sev ON sev.sev_id = cha.cha_severidad
LEFT JOIN [dbo].[Criticidad_Nivel]          crn ON crn.crn_id = cha.cha_criticidad_nivel
LEFT JOIN [dbo].[Proceso_Estado]            pes ON pes.pes_id = cha.cha_proceso_estado
LEFT JOIN [dbo].[Activo]                    act ON act.act_id = cha.cha_activo
LEFT JOIN [dbo].[Cliente_Instalacion]       cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Activo_Componente]         aco ON aco.aco_id = cha.cha_activo_componente
LEFT JOIN [dbo].[Usuario]                   ue  ON ue.usu_id  = cej.cej_usuario_ejecutor
LEFT JOIN [dbo].[Orden_Trabajo]             otr ON otr.otr_id = cha.cha_orden_trabajo
LEFT JOIN [dbo].[Orden_Trabajo_Estado]      ote ON ote.ote_id = otr.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Usuario]                   uc  ON uc.usu_id  = cha.cha_usuario_confirmacion
WHERE   cha.cha_cliente = @CLIENTE
  AND   cha.cha_habilitado = 1
  AND   (@ID IS NULL OR cha.cha_id = @ID)
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
  AND   (@ACTIVO IS NULL OR cha.cha_activo = @ACTIVO)
  AND   (@SEVERIDAD IS NULL OR cha.cha_severidad = @SEVERIDAD)
  AND   (@ESTADO IS NULL OR cha.cha_proceso_estado = @ESTADO)
  AND   (@DESDE IS NULL OR cha.cha_fecha_creacion >= CAST(@DESDE AS DATETIME))
  AND   (@HASTA IS NULL OR cha.cha_fecha_creacion <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
  AND   (@FILTRO IS NULL OR cha.cha_titulo LIKE '%' + @FILTRO + '%'
                         OR cha.cha_descripcion LIKE '%' + @FILTRO + '%'
                         OR act.act_codigo LIKE '%' + @FILTRO + '%'
                         OR act.act_nombre LIKE '%' + @FILTRO + '%'
                         OR cpl.cpl_nombre LIKE '%' + @FILTRO + '%')
ORDER BY cha.cha_fecha_creacion DESC, cha.cha_id DESC
OFFSET (@PAGINA - 1) * @TAMANO ROWS
FETCH NEXT @TAMANO ROWS ONLY
GO

-- ---------------------------------------------------------------------------
-- 3) RPT_CHECKLIST_HALLAZGO_EXCEL — lo que se ve, para llevarselo
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[RPT_CHECKLIST_HALLAZGO_EXCEL]
@CLIENTE     INT,
@INSTALACION INT = NULL,
@ACTIVO      INT = NULL,
@SEVERIDAD   INT = NULL,
@ESTADO      INT = NULL,
@DESDE       DATE = NULL,
@HASTA       DATE = NULL,
@FILTRO      NVARCHAR(200) = NULL

AS
SET NOCOUNT ON

DECLARE @T TABLE (
    CHA_ID INT, CHA_UUID UNIQUEIDENTIFIER, CHA_TITULO NVARCHAR(2000), CHA_DESCRIPCION NVARCHAR(MAX), CHA_FECHA_CREACION DATETIME,
    CHA_GENERADO_IA BIT, CHA_CONFIANZA_IA DECIMAL(18,6), CHA_MOTIVO_DESCARTE NVARCHAR(2000), CHA_FECHA_CONFIRMACION DATETIME, CHA_HABILITADO BIT,
    SEVERIDAD_ID INT, SEVERIDAD_CODIGO NVARCHAR(200), SEVERIDAD_NOMBRE NVARCHAR(200), CRITICIDAD_NOMBRE NVARCHAR(200),
    ESTADO_ID INT, ESTADO_CODIGO NVARCHAR(200), ESTADO_NOMBRE NVARCHAR(200),
    ACTIVO_ID INT, ACTIVO_CODIGO NVARCHAR(500), ACTIVO_NOMBRE NVARCHAR(2000), PLANTA_NOMBRE NVARCHAR(2000), COMPONENTE_NOMBRE NVARCHAR(2000),
    EJECUCION_ID INT, EJECUCION_FECHA DATETIME, PLANTILLA_CODIGO NVARCHAR(500), PLANTILLA_NOMBRE NVARCHAR(2000), EJECUTOR_NOMBRE NVARCHAR(500),
    ITEM_TEXTO NVARCHAR(MAX), RESPUESTA_TEXTO NVARCHAR(MAX), RESPUESTA_NUMERO DECIMAL(18,6), RESPUESTA_UNIDAD NVARCHAR(200), RESPUESTA_FUERA_RANGO BIT,
    RESPUESTA_COMENTARIO NVARCHAR(MAX), ORDEN_TRABAJO_ID INT, ORDEN_TRABAJO_CORRELATIVO INT, ORDEN_TRABAJO_ESTADO NVARCHAR(200), CONFIRMADOR_NOMBRE NVARCHAR(500), TOTAL INT)

INSERT INTO @T
EXEC [dbo].[SEL_CHECKLIST_HALLAZGO] @CLIENTE = @CLIENTE, @INSTALACION = @INSTALACION, @ACTIVO = @ACTIVO, @SEVERIDAD = @SEVERIDAD,
                                    @ESTADO = @ESTADO, @DESDE = @DESDE, @HASTA = @HASTA, @FILTRO = @FILTRO

SELECT  CONVERT(VARCHAR(16), CHA_FECHA_CREACION, 120)                 AS [FECHA],
        CHA_TITULO                                                      AS [HALLAZGO],
        ISNULL(SEVERIDAD_NOMBRE, '')                                    AS [SEVERIDAD],
        ISNULL(ESTADO_NOMBRE, '')                                       AS [ESTADO],
        ISNULL(ACTIVO_CODIGO, '')                                       AS [EQUIPO],
        ISNULL(ACTIVO_NOMBRE, '')                                       AS [NOMBRE EQUIPO],
        ISNULL(PLANTA_NOMBRE, '')                                       AS [PLANTA],
        ISNULL(COMPONENTE_NOMBRE, '')                                   AS [COMPONENTE],
        ISNULL(PLANTILLA_NOMBRE, '')                                    AS [PAUTA],
        ISNULL(ITEM_TEXTO, '')                                          AS [ITEM],
        ISNULL(RESPUESTA_TEXTO, CASE WHEN RESPUESTA_NUMERO IS NULL THEN '' ELSE CAST(RESPUESTA_NUMERO AS VARCHAR) + ' ' + ISNULL(RESPUESTA_UNIDAD, '') END) AS [RESPUESTA],
        CASE WHEN RESPUESTA_FUERA_RANGO = 1 THEN 'SI' ELSE 'NO' END     AS [FUERA DE RANGO],
        ISNULL(EJECUTOR_NOMBRE, '')                                     AS [TECNICO],
        CASE WHEN CHA_GENERADO_IA = 1 THEN 'SI' ELSE 'NO' END           AS [GENERADO POR IA],
        CASE WHEN ORDEN_TRABAJO_CORRELATIVO IS NULL THEN '' ELSE 'OT-' + CAST(ORDEN_TRABAJO_CORRELATIVO AS VARCHAR) END AS [ORDEN DE TRABAJO],
        ISNULL(CHA_DESCRIPCION, '')                                     AS [DESCRIPCION]
FROM    @T
ORDER BY CHA_FECHA_CREACION DESC
GO

-- ---------------------------------------------------------------------------
-- 4) Permiso y menu: un solo listado, junto a las pautas
-- ---------------------------------------------------------------------------
DECLARE @HOY DATETIME = GETDATE()

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER HALLAZGOS')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'VER HALLAZGOS', 'Ver hallazgos de checklist', p.prm_modulo, p.prm_permiso_ambito,
           'Consultar los hallazgos que dejan las pautas de inspección ejecutadas en terreno',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM   [dbo].[Permiso] p WHERE p.prm_codigo = 'VER PAUTAS'

DECLARE @VER INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER HALLAZGOS')
DECLARE @VER_PAUTAS INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PAUTAS')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @VER, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @VER_PAUTAS
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @VER)

DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(mnu_orden) FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_orden < 99), 0) + 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Hallazgos de inspección', 'Lo que las pautas encontraron fuera de rango o no conforme', 3, @PADRE, @ORDEN,
            '~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx', 1, 'mdi mdi-alert-decagram-outline', @VER, 1)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('SEL_CHECKLIST_HALLAZGO','RPT_CHECKLIST_HALLAZGO_EXCEL')) AS VARCHAR) + ' de 2' AS RESULTADO
UNION ALL SELECT 'Indices = ' + CAST((SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Checklist_Hallazgo') AND name IN ('IX_CHA_CLIENTE_ESTADO_FECHA','IX_CHA_ACTIVO_FECHA')) AS VARCHAR) + ' de 2'
UNION ALL SELECT 'Menu = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Hallazgos/%') AS VARCHAR) + ' de 1'
GO
