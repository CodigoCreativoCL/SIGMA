/* ============================================================================
   417 · Pautas de Recursos: editar un ítem existente y sus dependencias (09-10-2026)

   El cajón de pauta ya no obliga a quitar y volver a agregar un ítem para corregirlo, y las
   dependencias («Mostrar X cuando Y no cumple») se agregan y quitan ahí mismo.
     · UPS_RECURSOS_PAUTA_ITEM_RANGO: fija o quita el rango mín./máx. de un ítem (deja el resto de la
       validación; civ_genera_hallazgo lo vuelve a poner UPS_CHECKLIST_ITEM_REGLAS_RECURSOS, BD/412).
     · SEL_RECURSOS_PAUTA (BD/406): las dependencias traen ITEM, COND, ACCION, OPERADOR, VALOR, OPCION.
     · SEL_RECURSOS_PAUTA_BORRADOR (BD/406) + conjunto 2 (dependencias vivas) y 3 (opciones por ítem).
   Aplicar DESPUÉS de 406 y 412. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[UPS_RECURSOS_PAUTA_ITEM_RANGO]
    @ITEM          INT,
    @MINIMO        DECIMAL(18,6) = NULL,
    @MAXIMO        DECIMAL(18,6) = NULL,
    @GENERA_ALERTA BIT = 0,
    @USUARIO       INT
AS
SET NOCOUNT ON
IF @MINIMO IS NOT NULL AND @MAXIMO IS NOT NULL AND @MINIMO > @MAXIMO
BEGIN RAISERROR('1.- EL MINIMO NO PUEDE SER MAYOR QUE EL MAXIMO.', 16, 1) RETURN -1 END
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] WHERE civ_checklist_plantilla_item = @ITEM AND civ_habilitado = 1)
    UPDATE [dbo].[Checklist_Item_Validacion]
    SET civ_valor_minimo = @MINIMO, civ_valor_maximo = @MAXIMO, civ_genera_alerta = ISNULL(@GENERA_ALERTA, 0),
        civ_usuario_actualizacion = @USUARIO, civ_fecha_actualizacion = @AHORA
    WHERE civ_checklist_plantilla_item = @ITEM AND civ_habilitado = 1
ELSE IF @MINIMO IS NOT NULL OR @MAXIMO IS NOT NULL
    INSERT [dbo].[Checklist_Item_Validacion] (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_genera_alerta, civ_requiere_comentario_fuera_rango,
           civ_requiere_evidencia_fuera_rango, civ_genera_hallazgo, civ_usuario_creacion, civ_fecha_creacion, civ_usuario_actualizacion, civ_fecha_actualizacion, civ_habilitado)
    VALUES (@ITEM, @MINIMO, @MAXIMO, ISNULL(@GENERA_ALERTA, 0), 1, 0, 1, @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
RETURN 0
GO

/* Detalle para el cajón: el borrador si hay cambios sin publicar; si no, la publicada.
   Ítems y secciones se identifican por su CÓDIGO (se conserva al clonar). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PAUTA]
    @CLIENTE   INT,
    @PLANTILLA INT
AS
SET NOCOUNT ON
DECLARE @VER INT, @PUB INT
SELECT TOP 1 @PUB = cpv_id FROM [dbo].[Checklist_Plantilla_Version] v JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
 WHERE v.cpv_checklist_plantilla = @PLANTILLA AND p.cpl_cliente = @CLIENTE AND v.cpv_checklist_version_estado = 2 AND v.cpv_habilitado = 1 ORDER BY v.cpv_numero DESC
SELECT TOP 1 @VER = cpv_id FROM [dbo].[Checklist_Plantilla_Version] v JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
 WHERE v.cpv_checklist_plantilla = @PLANTILLA AND p.cpl_cliente = @CLIENTE AND v.cpv_checklist_version_estado = 1 AND v.cpv_habilitado = 1 ORDER BY v.cpv_numero DESC
SET @VER = ISNULL(@VER, @PUB)

SELECT  p.cpl_id AS ID, p.cpl_codigo AS CODIGO, p.cpl_nombre AS NOMBRE, p.cpl_cliente_instalacion AS PLANTA, p.cpl_activo_tipo AS TIPO,
        (SELECT cpv_numero FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_id = @PUB) AS VERSION_PUBLICADA,
        CAST(CASE WHEN @VER <> ISNULL(@PUB, 0) THEN 1 ELSE 0 END AS BIT) AS ES_BORRADOR
FROM    [dbo].[Checklist_Plantilla] p
WHERE   p.cpl_id = @PLANTILLA AND p.cpl_cliente = @CLIENTE

SELECT  s.cps_codigo AS CODIGO, s.cps_nombre AS NOMBRE, s.cps_orden AS ORDEN
FROM    [dbo].[Checklist_Plantilla_Seccion] s
WHERE   s.cps_checklist_plantilla_version = @VER AND s.cps_habilitado = 1
ORDER BY s.cps_orden

SELECT  i.cpi_codigo AS CODIGO, s.cps_codigo AS SECCION, i.cpi_texto AS TEXTO, i.cpi_checklist_item_tipo AS TIPO, t.cit_nombre AS TIPO_NOMBRE,
        i.cpi_unidad_medida AS UNIDAD, ISNULL(u.ume_simbolo, N'') AS UNIDAD_SIMBOLO, c.civ_valor_minimo AS MINIMO, c.civ_valor_maximo AS MAXIMO, i.cpi_critico AS CRITICO, i.cpi_orden AS ORDEN
FROM    [dbo].[Checklist_Plantilla_Item] i
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s ON s.cps_id = i.cpi_checklist_plantilla_seccion
JOIN    [dbo].[Checklist_Item_Tipo] t ON t.cit_id = i.cpi_checklist_item_tipo
LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = i.cpi_unidad_medida
LEFT JOIN [dbo].[Checklist_Item_Validacion] c ON c.civ_checklist_plantilla_item = i.cpi_id AND c.civ_habilitado = 1
WHERE   i.cpi_checklist_plantilla_version = @VER AND i.cpi_habilitado = 1
ORDER BY s.cps_orden, i.cpi_orden

/* Dependencias en palabras: «Mostrar X si Y = valor». */
SELECT  da.dac_nombre + N' «' + it.cpi_texto + N'» cuando «' + ic.cpi_texto + N'» ' + LOWER(oc.opc_nombre) + N' ' + ISNULL(op.cio_texto, ISNULL(d.cid_valor_comparacion, N'')) AS TEXTO,
        it.cpi_codigo AS ITEM, ic.cpi_codigo AS COND, d.cid_dependencia_accion AS ACCION, d.cid_operador_comparacion AS OPERADOR,
        d.cid_valor_comparacion AS VALOR, op.cio_codigo AS OPCION
FROM    [dbo].[Checklist_Item_Dependencia] d
JOIN    [dbo].[Checklist_Plantilla_Item] it ON it.cpi_id = d.cid_checklist_plantilla_item AND it.cpi_habilitado = 1
JOIN    [dbo].[Checklist_Plantilla_Item] ic ON ic.cpi_id = d.cid_item_condicion
JOIN    [dbo].[Dependencia_Accion] da ON da.dac_id = d.cid_dependencia_accion
JOIN    [dbo].[Operador_Comparacion] oc ON oc.opc_id = d.cid_operador_comparacion
LEFT JOIN [dbo].[Checklist_Item_Opcion] op ON op.cio_id = d.cid_checklist_item_opcion
WHERE   it.cpi_checklist_plantilla_version = @VER AND d.cid_habilitado = 1

/* Dónde se usa: las inspecciones vigentes. */
SELECT  DISTINCT cpr.cpr_programacion AS PROGRAMACION, ISNULL(NULLIF(cpr.cpr_nombre, N''), N'Inspección ' + CAST(cpr.cpr_programacion AS NVARCHAR(12))) AS NOMBRE
FROM    [dbo].[Checklist_Programacion] cpr
JOIN    [dbo].[Checklist_Plantilla_Version] x ON x.cpv_id = cpr.cpr_checklist_plantilla_version
WHERE   x.cpv_checklist_plantilla = @PLANTILLA AND cpr.cpr_habilitado = 1 AND cpr.cpr_cliente = @CLIENTE
GO


/* Secciones e ítems vivos del borrador, por código (el guardado del cajón reconcilia con ellos). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PAUTA_BORRADOR]
    @VERSION INT
AS
SET NOCOUNT ON
SELECT cps_id AS ID, cps_codigo AS CODIGO FROM [dbo].[Checklist_Plantilla_Seccion] WHERE cps_checklist_plantilla_version = @VERSION AND cps_habilitado = 1
SELECT cpi_id AS ID, cpi_codigo AS CODIGO FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_checklist_plantilla_version = @VERSION AND cpi_habilitado = 1
/* 417 · 2 · dependencias vivas del borrador (el cajón las reemplaza todas al publicar) */
SELECT d.cid_id AS ID FROM [dbo].[Checklist_Item_Dependencia] d JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = d.cid_checklist_plantilla_item
WHERE i.cpi_checklist_plantilla_version = @VERSION AND d.cid_habilitado = 1
/* 417 · 3 · opciones de cada ítem (Sí/No), por código del ítem */
SELECT i.cpi_codigo AS ITEM, o.cio_id AS ID, o.cio_codigo AS CODIGO FROM [dbo].[Checklist_Item_Opcion] o JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = o.cio_checklist_plantilla_item
WHERE i.cpi_checklist_plantilla_version = @VERSION AND i.cpi_habilitado = 1 AND o.cio_habilitado = 1
GO
PRINT '417_PAUTA_EDITAR_ITEM_DEPENDENCIAS aplicado.'
GO
