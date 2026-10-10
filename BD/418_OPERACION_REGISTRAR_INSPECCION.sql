/* ============================================================================
   418 · Operación: registrar una inspección desde la web (09-10-2026)

   Operación › Ejecuciones (y Hoy) tenían el botón «Registrar» de una inspección sin hacer nada.
   Ahora abre un cajón con la pauta de la ocurrencia y guarda las respuestas con los MISMOS SP que
   usa la app (API_INS_CHECKLIST_EJECUCION → API_UPS_CHECKLIST_RESPUESTA → API_UPD_CHECKLIST_CERRAR):
   lo que no cumple o sale de rango abre su hallazgo y llega a Avisos igual que desde terreno.
     · SEL_OPERACION_INSPECCION(@CLIENTE, @OCURRENCIA):
         0 · cabecera (pauta y versión, activo, responsable, situación, si ya se registró y por quién)
         1 · ítems de la versión de la pauta (sección, tipo, rango, unidad, crítico)
         2 · hallazgos de la ejecución cerrada (para mostrarlos en el cajón)
     · UPD_CHECKLIST_OCURRENCIAS_VERSION_VIGENTE(@PLANTILLA): al publicar una versión (Recursos ›
       Pautas) las ocurrencias pendientes o disponibles SIN ejecución pasan a la versión vigente
       («rige desde la próxima inspección»). Antes quedaban en la versión retirada y ni la app ni
       la web podían registrarlas («Esa versión de la pauta no está publicada»).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_INSPECCION]
    @CLIENTE    INT,
    @OCURRENCIA INT
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @VER INT, @CEJ INT
SELECT @VER = coc_checklist_plantilla_version FROM [dbo].[Checklist_Ocurrencia] WHERE coc_id = @OCURRENCIA AND coc_cliente = @CLIENTE AND coc_habilitado = 1
SELECT TOP 1 @CEJ = cej_id FROM [dbo].[Checklist_Ejecucion]
WHERE cej_checklist_ocurrencia = @OCURRENCIA AND cej_habilitado = 1 AND cej_checklist_ejecucion_estado IN (2, 3, 4)
ORDER BY cej_id DESC

SELECT  c.coc_id AS OCURRENCIA, ISNULL(NULLIF(p.cpr_nombre, N''), N'Inspección') AS NOMBRE,
        c.coc_fecha_programada_utc AS FECHA, c.coc_fecha_limite_utc AS LIMITE, c.coc_fecha_disponible_utc AS DISPONIBLE,
        c.coc_checklist_ocurrencia_estado AS ESTADO_ID, oe.coe_nombre AS ESTADO,
        CAST(CASE WHEN c.coc_checklist_ocurrencia_estado IN (1, 2, 3) AND ISNULL(c.coc_fecha_disponible_utc, c.coc_fecha_programada_utc) <= @AHORA AND @CEJ IS NULL THEN 1 ELSE 0 END AS BIT) AS PUEDE,
        CAST(CASE WHEN c.coc_fecha_limite_utc IS NOT NULL AND c.coc_fecha_limite_utc < @AHORA AND c.coc_checklist_ocurrencia_estado IN (1, 2, 3) THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
        cpl.cpl_id AS PAUTA_ID, cpl.cpl_codigo AS PAUTA_CODIGO, cpl.cpl_nombre AS PAUTA, v.cpv_numero AS PAUTA_VERSION,
        CAST(CASE WHEN v.cpv_checklist_version_estado = 2 THEN 1 ELSE 0 END AS BIT) AS PUBLICADA,
        a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        @CEJ AS EJECUCION, ej.cej_fecha_fin_utc AS HECHA_EL,
        LTRIM(RTRIM(ISNULL(ue.usu_nombre, N'') + N' ' + ISNULL(ue.usu_apellido_paterno, N''))) AS HECHA_POR
FROM    [dbo].[Checklist_Ocurrencia] c
JOIN    [dbo].[Checklist_Ocurrencia_Estado] oe ON oe.coe_id = c.coc_checklist_ocurrencia_estado
JOIN    [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = c.coc_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla] cpl ON cpl.cpl_id = v.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
LEFT JOIN [dbo].[Activo] a ON a.act_id = c.coc_activo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = p.cpr_usuario_responsable
LEFT JOIN [dbo].[Checklist_Ejecucion] ej ON ej.cej_id = @CEJ
LEFT JOIN [dbo].[Usuario] ue ON ue.usu_id = ej.cej_usuario_ejecutor
WHERE   c.coc_id = @OCURRENCIA AND c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1

SELECT  i.cpi_id AS ID, ISNULL(s.cps_nombre, N'General') AS SECCION, i.cpi_texto AS TEXTO, i.cpi_checklist_item_tipo AS TIPO,
        cv.civ_valor_minimo AS MINIMO, cv.civ_valor_maximo AS MAXIMO, ISNULL(um.ume_simbolo, N'') AS UNIDAD,
        ISNULL(i.cpi_critico, 0) AS CRITICO, i.cpi_obligatorio AS OBLIGATORIO
FROM    [dbo].[Checklist_Plantilla_Item] i
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s ON s.cps_id = i.cpi_checklist_plantilla_seccion
LEFT JOIN [dbo].[Checklist_Item_Validacion] cv ON cv.civ_checklist_plantilla_item = i.cpi_id AND cv.civ_habilitado = 1
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = i.cpi_unidad_medida
WHERE   i.cpi_checklist_plantilla_version = @VER AND i.cpi_habilitado = 1
ORDER BY ISNULL(s.cps_orden, 0), i.cpi_orden

SELECT  hz.cha_id AS ID, hz.cha_titulo AS ITEM, hz.cha_severidad AS SEVERIDAD
FROM    [dbo].[Checklist_Hallazgo] hz
WHERE   hz.cha_checklist_ejecucion = @CEJ AND hz.cha_habilitado = 1
RETURN 0
GO
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_OCURRENCIAS_VERSION_VIGENTE]
    @PLANTILLA INT,
    @USUARIO   INT = NULL
AS
SET NOCOUNT ON
DECLARE @VIG INT
SELECT TOP 1 @VIG = cpv_id FROM [dbo].[Checklist_Plantilla_Version]
WHERE cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 2 AND cpv_habilitado = 1 ORDER BY cpv_numero DESC
IF @VIG IS NULL RETURN 0
UPDATE c SET c.coc_checklist_plantilla_version = @VIG, c.coc_usuario_actualizacion = ISNULL(@USUARIO, c.coc_usuario_actualizacion), c.coc_fecha_actualizacion = [dbo].[FNC_AHORA]()
FROM [dbo].[Checklist_Ocurrencia] c
JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = c.coc_checklist_plantilla_version
WHERE v.cpv_checklist_plantilla = @PLANTILLA AND c.coc_checklist_plantilla_version <> @VIG
  AND c.coc_checklist_ocurrencia_estado IN (1, 2) AND c.coc_habilitado = 1
  AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion] e WHERE e.cej_checklist_ocurrencia = c.coc_id AND e.cej_habilitado = 1)
RETURN 0
GO
/* Las ocurrencias que ya quedaron atrás con versiones retiradas. */
DECLARE @P INT
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT cpl_id FROM [dbo].[Checklist_Plantilla] WHERE cpl_habilitado = 1
OPEN cur FETCH NEXT FROM cur INTO @P
WHILE @@FETCH_STATUS = 0 BEGIN EXEC [dbo].[UPD_CHECKLIST_OCURRENCIAS_VERSION_VIGENTE] @PLANTILLA = @P; FETCH NEXT FROM cur INTO @P END
CLOSE cur DEALLOCATE cur
GO
PRINT '418_OPERACION_REGISTRAR_INSPECCION aplicado.'
GO
