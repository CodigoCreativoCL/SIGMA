/* ============================================================================
   317 - SEL_CHECKLIST_ITEM_VALIDACION: filtro opcional por @VERSION
   ----------------------------------------------------------------------------
   El centro de la pauta abre "Umbrales" en modal filtrado al BORRADOR de la
   pauta (no a todas las versiones), para no mezclar los umbrales congelados de
   la publicada con los editables del borrador. Se agrega @VERSION opcional.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_VALIDACION]
@CLIENTE    INT,
@ID         INT = NULL,
@PLANTILLA  INT = NULL,
@VERSION    INT = NULL,
@FILTRO     NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  v.civ_id                                   AS CIV_ID,
        v.civ_checklist_plantilla_item             AS ITEM_ID,
        i.cpi_codigo                               AS ITEM_CODIGO,
        i.cpi_texto                                AS ITEM_TEXTO,
        t.cit_codigo                               AS TIPO_CODIGO,
        t.cit_nombre                               AS TIPO_NOMBRE,
        ISNULL(s.cps_nombre, '')                   AS SECCION_NOMBRE,
        pl.cpl_id                                  AS PLANTILLA_ID,
        pl.cpl_nombre                              AS PLANTILLA_NOMBRE,
        ver.cpv_numero                             AS VERSION_NUMERO,
        v.civ_valor_minimo                         AS VALOR_MINIMO,
        v.civ_valor_maximo                         AS VALOR_MAXIMO,
        v.civ_valor_advertencia                    AS VALOR_ADVERTENCIA,
        v.civ_valor_critico                        AS VALOR_CRITICO,
        v.civ_largo_minimo                         AS LARGO_MINIMO,
        v.civ_largo_maximo                         AS LARGO_MAXIMO,
        v.civ_expresion_regular                    AS EXPRESION_REGULAR,
        v.civ_unidad_medida                        AS UNIDAD_MEDIDA,
        v.civ_requiere_comentario_fuera_rango      AS REQUIERE_COMENTARIO,
        v.civ_requiere_evidencia_fuera_rango       AS REQUIERE_EVIDENCIA,
        v.civ_genera_alerta                        AS GENERA_ALERTA,
        v.civ_genera_hallazgo                      AS GENERA_HALLAZGO,
        ISNULL(v.civ_mensaje, '')                  AS MENSAJE,
        v.civ_habilitado                           AS HABILITADO
FROM    [dbo].[Checklist_Item_Validacion]     v
JOIN    [dbo].[Checklist_Plantilla_Item]      i   ON i.cpi_id  = v.civ_checklist_plantilla_item
JOIN    [dbo].[Checklist_Item_Tipo]           t   ON t.cit_id  = i.cpi_checklist_item_tipo
JOIN    [dbo].[Checklist_Plantilla_Version]   ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]           pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s   ON s.cps_id   = i.cpi_checklist_plantilla_seccion
WHERE   pl.cpl_cliente = @CLIENTE
  AND   (@ID IS NULL OR v.civ_id = @ID)
  AND   (@PLANTILLA IS NULL OR pl.cpl_id = @PLANTILLA)
  AND   (@VERSION IS NULL OR i.cpi_checklist_plantilla_version = @VERSION)
  -- El listado muestra solo habilitadas; la ficha (por @ID) trae aunque este de baja.
  AND   (@ID IS NOT NULL OR v.civ_habilitado = 1)
  AND   (@FILTRO IS NULL OR @FILTRO = '' OR i.cpi_texto LIKE '%' + @FILTRO + '%' OR i.cpi_codigo LIKE '%' + @FILTRO + '%')
ORDER BY pl.cpl_nombre, s.cps_orden, i.cpi_orden, i.cpi_id
GO
