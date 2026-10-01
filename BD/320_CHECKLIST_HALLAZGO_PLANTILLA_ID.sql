/* ============================================================================
   320 - SEL_CHECKLIST_HALLAZGO: exponer PLANTILLA_ID
   ----------------------------------------------------------------------------
   La bandeja necesita el id de la pauta del hallazgo para que "Abrir pauta"
   lleve al centro de ESA pauta (no al listado general). Se agrega la columna
   PLANTILLA_ID (ya existe el JOIN a Checklist_Plantilla).
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
        cpl.cpl_id                      AS PLANTILLA_ID,
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
ORDER BY cha.cha_severidad DESC, cha.cha_fecha_creacion ASC, cha.cha_id ASC
OFFSET (@PAGINA - 1) * @TAMANO ROWS
FETCH NEXT @TAMANO ROWS ONLY
GO
