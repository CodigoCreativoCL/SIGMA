/* ============================================================================
   318 - SEL_CHECKLIST_ITEM_DEPENDENCIA: filtro opcional por @VERSION
   ----------------------------------------------------------------------------
   El centro de la pauta abre "Dependencias" en modal filtrado al BORRADOR de la
   pauta (no a todas las versiones). Se agrega @VERSION opcional.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_DEPENDENCIA]
@CLIENTE    INT,
@ID         INT = NULL,
@PLANTILLA  INT = NULL,
@VERSION    INT = NULL,
@FILTRO     NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  d.cid_id                          AS CID_ID,
        d.cid_checklist_plantilla_item    AS ITEM_ID,
        i.cpi_texto                       AS ITEM_TEXTO,
        d.cid_item_condicion              AS CONDICION_ID,
        ic.cpi_texto                      AS CONDICION_TEXTO,
        d.cid_operador_comparacion        AS OPERADOR_ID,
        op.opc_nombre                     AS OPERADOR_NOMBRE,
        ISNULL(d.cid_valor_comparacion,'')AS VALOR,
        d.cid_checklist_item_opcion       AS OPCION_ID,
        ISNULL(o.cio_texto,'')            AS OPCION_TEXTO,
        d.cid_dependencia_accion          AS ACCION_ID,
        ac.dac_codigo                     AS ACCION_CODIGO,
        ac.dac_nombre                     AS ACCION_NOMBRE,
        pl.cpl_id                         AS PLANTILLA_ID,
        pl.cpl_nombre                     AS PLANTILLA_NOMBRE,
        d.cid_habilitado                  AS HABILITADO
FROM    [dbo].[Checklist_Item_Dependencia]   d
JOIN    [dbo].[Checklist_Plantilla_Item]     i   ON i.cpi_id  = d.cid_checklist_plantilla_item
JOIN    [dbo].[Checklist_Plantilla_Item]     ic  ON ic.cpi_id = d.cid_item_condicion
JOIN    [dbo].[Operador_Comparacion]         op  ON op.opc_id = d.cid_operador_comparacion
JOIN    [dbo].[Dependencia_Accion]           ac  ON ac.dac_id = d.cid_dependencia_accion
JOIN    [dbo].[Checklist_Plantilla_Version]  ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]          pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Item_Opcion]      o   ON o.cio_id   = d.cid_checklist_item_opcion
WHERE   pl.cpl_cliente = @CLIENTE
  AND   (@ID IS NULL OR d.cid_id = @ID)
  AND   (@PLANTILLA IS NULL OR pl.cpl_id = @PLANTILLA)
  AND   (@VERSION IS NULL OR i.cpi_checklist_plantilla_version = @VERSION)
  AND   (@ID IS NOT NULL OR d.cid_habilitado = 1)
  AND   (@FILTRO IS NULL OR @FILTRO = '' OR i.cpi_texto LIKE '%' + @FILTRO + '%' OR ic.cpi_texto LIKE '%' + @FILTRO + '%')
ORDER BY pl.cpl_nombre, i.cpi_orden, d.cid_id
GO
