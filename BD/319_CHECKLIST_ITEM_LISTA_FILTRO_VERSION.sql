/* ============================================================================
   319 - SEL_CHECKLIST_ITEM_LISTA: filtro opcional por @VERSION
   ----------------------------------------------------------------------------
   El selector de ítem de las fichas de umbral/dependencia (botón "Nuevo" abierto
   desde el centro de la pauta) se acota al BORRADOR de esa pauta, para no poder
   colgar umbrales/dependencias de ítems de otras pautas o de versiones congeladas.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_LISTA]
@CLIENTE INT,
@VERSION INT = NULL
AS
SET NOCOUNT ON

SELECT  i.cpi_id                 AS ITEM_ID,
        i.cpi_codigo             AS ITEM_CODIGO,
        i.cpi_texto              AS ITEM_TEXTO,
        t.cit_codigo             AS TIPO_CODIGO,
        t.cit_nombre             AS TIPO_NOMBRE,
        pl.cpl_nombre            AS PLANTILLA_NOMBRE,
        ISNULL(s.cps_nombre, '') AS SECCION_NOMBRE,
        CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] v
                          WHERE v.civ_checklist_plantilla_item = i.cpi_id AND v.civ_habilitado = 1)
             THEN 1 ELSE 0 END   AS TIENE_VALIDACION
FROM    [dbo].[Checklist_Plantilla_Item]      i
JOIN    [dbo].[Checklist_Item_Tipo]           t   ON t.cit_id   = i.cpi_checklist_item_tipo
JOIN    [dbo].[Checklist_Plantilla_Version]   ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]           pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s   ON s.cps_id   = i.cpi_checklist_plantilla_seccion
WHERE   pl.cpl_cliente = @CLIENTE AND i.cpi_habilitado = 1
  AND   (@VERSION IS NULL OR i.cpi_checklist_plantilla_version = @VERSION)
ORDER BY pl.cpl_nombre, s.cps_orden, i.cpi_orden, i.cpi_id
GO
