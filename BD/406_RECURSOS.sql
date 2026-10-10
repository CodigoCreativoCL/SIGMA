/* ============================================================================
   406 · Recursos (rediseño de Mantenimiento en cinco lugares, parte e) · 09-10-2026

   Las lecturas y escrituras de la página Recursos (View/Mantenimiento/Biblioteca):
     1. Checklist_Plantilla_Item.cpi_critico: el «Ítem crítico» del mockup (el hallazgo
        nace con severidad alta). GET_CHECKLIST_BORRADOR lo copia al clonar la publicada.
     2. SEL_RECURSOS_PROCEDIMIENTOS  · la tabla de Procedimientos con «Dónde se usa».
     3. SEL_RECURSOS_PAUTAS / SEL_RECURSOS_PAUTA · lista y detalle de las pautas.
     4. SEL_RECURSOS_AJUSTES / UPS_RECURSOS_AJUSTE · categorías de tarea, tipos de OT y
        motivos de descarte, con su conteo de uso. Solo se quita lo que nadie usa.
   Aplicar con -I (QUOTED_IDENTIFIER ON). Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---- 1 · ítem crítico ---- */
IF COL_LENGTH('dbo.Checklist_Plantilla_Item', 'cpi_critico') IS NULL
    ALTER TABLE [dbo].[Checklist_Plantilla_Item] ADD cpi_critico BIT NOT NULL CONSTRAINT DF_CPI_CRITICO DEFAULT (0)
GO

/* GET_CHECKLIST_BORRADOR (315) + cpi_critico en la copia de los ítems. */
CREATE OR ALTER PROCEDURE [dbo].[GET_CHECKLIST_BORRADOR]
@PLANTILLA  INT,
@USUARIO    INT,
@CREAR      BIT = 1,
@VERSION    INT = NULL OUTPUT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @PLANTILLA
IF @CLIENTE IS NULL
BEGIN RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT TOP 1 @VERSION = cpv_id
FROM   [dbo].[Checklist_Plantilla_Version]
WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 1
ORDER BY cpv_numero DESC

IF @VERSION IS NOT NULL OR @CREAR = 0
BEGIN
    SELECT @VERSION AS VERSION
    RETURN
END

BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @NUM INT
    SELECT @NUM = ISNULL(MAX(cpv_numero), 0) + 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @PLANTILLA

    INSERT [dbo].[Checklist_Plantilla_Version]
        (cpv_checklist_plantilla, cpv_numero, cpv_checklist_version_estado,
         cpv_usuario_creacion, cpv_fecha_creacion, cpv_usuario_actualizacion, cpv_fecha_actualizacion, cpv_habilitado)
    VALUES
        (@PLANTILLA, @NUM, 1, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
    SET @VERSION = SCOPE_IDENTITY()

    DECLARE @PUB INT
    SELECT TOP 1 @PUB = cpv_id
    FROM   [dbo].[Checklist_Plantilla_Version]
    WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 2
    ORDER BY cpv_numero DESC

    IF @PUB IS NOT NULL
    BEGIN
        DECLARE @mapSec TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Plantilla_Seccion] AS T
        USING (SELECT cps_id, cps_codigo, cps_nombre, cps_orden
               FROM   [dbo].[Checklist_Plantilla_Seccion]
               WHERE  cps_checklist_plantilla_version = @PUB AND cps_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cps_checklist_plantilla_version, cps_codigo, cps_nombre, cps_orden,
                    cps_usuario_creacion, cps_fecha_creacion, cps_usuario_actualizacion, cps_fecha_actualizacion, cps_habilitado)
            VALUES (@VERSION, S.cps_codigo, S.cps_nombre, S.cps_orden,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cps_id, inserted.cps_id INTO @mapSec (old, new);

        DECLARE @mapItem TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Plantilla_Item] AS T
        USING (SELECT i.cpi_id, ms.new AS new_sec, i.cpi_codigo, i.cpi_texto, i.cpi_ayuda,
                      i.cpi_checklist_item_tipo, i.cpi_orden, i.cpi_obligatorio, i.cpi_permite_comentario,
                      i.cpi_requiere_evidencia, i.cpi_unidad_medida, i.cpi_genera_medicion, i.cpi_activo_variable, i.cpi_critico
               FROM   [dbo].[Checklist_Plantilla_Item] i
               LEFT JOIN @mapSec ms ON ms.old = i.cpi_checklist_plantilla_seccion
               WHERE  i.cpi_checklist_plantilla_version = @PUB AND i.cpi_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cpi_checklist_plantilla_version, cpi_checklist_plantilla_seccion, cpi_codigo, cpi_texto, cpi_ayuda,
                    cpi_checklist_item_tipo, cpi_orden, cpi_obligatorio, cpi_permite_comentario, cpi_requiere_evidencia,
                    cpi_unidad_medida, cpi_genera_medicion, cpi_activo_variable, cpi_critico,
                    cpi_usuario_creacion, cpi_fecha_creacion, cpi_usuario_actualizacion, cpi_fecha_actualizacion, cpi_habilitado)
            VALUES (@VERSION, S.new_sec, S.cpi_codigo, S.cpi_texto, S.cpi_ayuda,
                    S.cpi_checklist_item_tipo, S.cpi_orden, S.cpi_obligatorio, S.cpi_permite_comentario, S.cpi_requiere_evidencia,
                    S.cpi_unidad_medida, S.cpi_genera_medicion, S.cpi_activo_variable, S.cpi_critico,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cpi_id, inserted.cpi_id INTO @mapItem (old, new);

        DECLARE @mapOp TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Item_Opcion] AS T
        USING (SELECT o.cio_id, mi.new AS new_item, o.cio_codigo, o.cio_texto, o.cio_valor, o.cio_orden,
                      o.cio_es_conforme, o.cio_severidad, o.cio_requiere_comentario, o.cio_requiere_evidencia
               FROM   [dbo].[Checklist_Item_Opcion] o
               JOIN   @mapItem mi ON mi.old = o.cio_checklist_plantilla_item
               WHERE  o.cio_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cio_checklist_plantilla_item, cio_codigo, cio_texto, cio_valor, cio_orden,
                    cio_es_conforme, cio_severidad, cio_requiere_comentario, cio_requiere_evidencia,
                    cio_usuario_creacion, cio_fecha_creacion, cio_usuario_actualizacion, cio_fecha_actualizacion, cio_habilitado)
            VALUES (S.new_item, S.cio_codigo, S.cio_texto, S.cio_valor, S.cio_orden,
                    S.cio_es_conforme, S.cio_severidad, S.cio_requiere_comentario, S.cio_requiere_evidencia,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cio_id, inserted.cio_id INTO @mapOp (old, new);

        INSERT [dbo].[Checklist_Item_Validacion]
            (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_valor_advertencia, civ_valor_critico,
             civ_largo_minimo, civ_largo_maximo, civ_expresion_regular, civ_unidad_medida,
             civ_requiere_comentario_fuera_rango, civ_requiere_evidencia_fuera_rango, civ_genera_alerta, civ_genera_hallazgo, civ_mensaje,
             civ_usuario_creacion, civ_fecha_creacion, civ_usuario_actualizacion, civ_fecha_actualizacion, civ_habilitado)
        SELECT mi.new, v.civ_valor_minimo, v.civ_valor_maximo, v.civ_valor_advertencia, v.civ_valor_critico,
               v.civ_largo_minimo, v.civ_largo_maximo, v.civ_expresion_regular, v.civ_unidad_medida,
               v.civ_requiere_comentario_fuera_rango, v.civ_requiere_evidencia_fuera_rango, v.civ_genera_alerta, v.civ_genera_hallazgo, v.civ_mensaje,
               @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Checklist_Item_Validacion] v
        JOIN   @mapItem mi ON mi.old = v.civ_checklist_plantilla_item
        WHERE  v.civ_habilitado = 1;

        INSERT [dbo].[Checklist_Item_Dependencia]
            (cid_checklist_plantilla_item, cid_item_condicion, cid_operador_comparacion, cid_valor_comparacion,
             cid_checklist_item_opcion, cid_dependencia_accion,
             cid_usuario_creacion, cid_fecha_creacion, cid_usuario_actualizacion, cid_fecha_actualizacion, cid_habilitado)
        SELECT mi.new, mc.new, d.cid_operador_comparacion, d.cid_valor_comparacion,
               mo.new, d.cid_dependencia_accion,
               @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Checklist_Item_Dependencia] d
        JOIN   @mapItem mi ON mi.old = d.cid_checklist_plantilla_item
        JOIN   @mapItem mc ON mc.old = d.cid_item_condicion
        LEFT JOIN @mapOp mo ON mo.old = d.cid_checklist_item_opcion
        WHERE  d.cid_habilitado = 1;
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(2000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GET_CHECKLIST_BORRADOR', @MSG = @MSG
    SET @VERSION = NULL
    RETURN -1
END CATCH

SELECT @VERSION AS VERSION
GO

/* ---- 2 · Procedimientos: la versión vigente de cada código, con sus conteos y dónde se usa ----
   «Se usa» = actividades habilitadas en versiones de plan que no están retiradas
   (borrador o publicada), de cualquier versión del mismo código. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PROCEDIMIENTOS]
    @CLIENTE INT
AS
SET NOCOUNT ON
;WITH P AS (
    SELECT p.*, MAX(p.prc_version) OVER (PARTITION BY ISNULL(p.prc_cliente, 0), p.prc_codigo) AS VMAX
    FROM   [dbo].[Procedimiento] p
    WHERE  (p.prc_cliente IS NULL OR p.prc_cliente = @CLIENTE) AND p.prc_habilitado = 1
), U AS (
    SELECT ISNULL(pr.prc_cliente, 0) AS CLI, pr.prc_codigo AS COD, COUNT(DISTINCT a.paa_id) AS ACTIVIDADES, COUNT(DISTINCT v.pmv_plan_mantenimiento) AS PLANES
    FROM   [dbo].[Plan_Mantenimiento_Actividad] a
    JOIN   [dbo].[Procedimiento] pr                ON pr.prc_id = a.paa_procedimiento
    JOIN   [dbo].[Plan_Mantenimiento_Hito] h       ON h.pmh_id = a.paa_plan_mantenimiento_hito AND h.pmh_habilitado = 1
    JOIN   [dbo].[Plan_Mantenimiento_Version] v    ON v.pmv_id = h.pmh_plan_mantenimiento_version AND v.pmv_habilitado = 1 AND v.pmv_plan_version_estado IN (1, 2)
    JOIN   [dbo].[Plan_Mantenimiento] pm           ON pm.pma_id = v.pmv_plan_mantenimiento AND pm.pma_cliente = @CLIENTE AND pm.pma_habilitado = 1
    WHERE  a.paa_habilitado = 1
    GROUP BY ISNULL(pr.prc_cliente, 0), pr.prc_codigo
)
SELECT  p.prc_id AS ID, p.prc_codigo AS CODIGO, p.prc_version AS VERSION, p.prc_nombre AS NOMBRE,
        p.prc_activo_tipo AS TIPO_ID, ISNULL(at.ati_nombre, N'') AS TIPO,
        ISNULL(pt.ptt_nombre, N'') AS PERMISO, p.prc_duracion_estimada_minuto AS DURACION,
        CAST(CASE WHEN p.prc_cliente IS NULL THEN 1 ELSE 0 END AS BIT) AS ES_GLOBAL,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1) AS PASOS,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1 AND s.ppa_es_punto_control = 1) AS CONTROLES,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1 AND s.ppa_requiere_medicion = 1) AS MEDICIONES,
        ISNULL(u.ACTIVIDADES, 0) AS ACTIVIDADES, ISNULL(u.PLANES, 0) AS PLANES
FROM    P p
LEFT JOIN [dbo].[Activo_Tipo] at          ON at.ati_id = p.prc_activo_tipo
LEFT JOIN [dbo].[Permiso_Trabajo_Tipo] pt ON pt.ptt_id = p.prc_permiso_trabajo_tipo
LEFT JOIN U u ON u.CLI = ISNULL(p.prc_cliente, 0) AND u.COD = p.prc_codigo
WHERE   p.prc_version = p.VMAX
ORDER BY CASE WHEN p.prc_cliente IS NULL THEN 1 ELSE 0 END, p.prc_codigo
GO

/* Los planes que usan un procedimiento (el aviso del cajón al editarlo). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PROCEDIMIENTO_USOS]
    @CLIENTE INT,
    @PROCEDIMIENTO INT
AS
SET NOCOUNT ON
SELECT  pm.pma_id AS PLAN_ID, pm.pma_codigo AS PLAN_CODIGO, pm.pma_nombre AS PLAN_NOMBRE, v.pmv_plan_version_estado AS ESTADO, COUNT(DISTINCT a.paa_id) AS ACTIVIDADES
FROM    [dbo].[Procedimiento] me
JOIN    [dbo].[Procedimiento] pr             ON ISNULL(pr.prc_cliente, 0) = ISNULL(me.prc_cliente, 0) AND pr.prc_codigo = me.prc_codigo
JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_procedimiento = pr.prc_id AND a.paa_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Hito] h    ON h.pmh_id = a.paa_plan_mantenimiento_hito AND h.pmh_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version AND v.pmv_habilitado = 1 AND v.pmv_plan_version_estado IN (1, 2)
JOIN    [dbo].[Plan_Mantenimiento] pm        ON pm.pma_id = v.pmv_plan_mantenimiento AND pm.pma_cliente = @CLIENTE AND pm.pma_habilitado = 1
WHERE   me.prc_id = @PROCEDIMIENTO AND (me.prc_cliente IS NULL OR me.prc_cliente = @CLIENTE)
GROUP BY pm.pma_id, pm.pma_codigo, pm.pma_nombre, v.pmv_plan_version_estado
ORDER BY pm.pma_codigo
GO

/* ---- 3 · Pautas ----
   La versión que se muestra es la publicada; si no hay, el borrador. BORRADOR = 1 cuando
   hay cambios sin publicar (un borrador más nuevo que la publicada). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PAUTAS]
    @CLIENTE INT
AS
SET NOCOUNT ON
;WITH V AS (
    SELECT  cpl.cpl_id,
            (SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] x WHERE x.cpv_checklist_plantilla = cpl.cpl_id AND x.cpv_checklist_version_estado = 2 AND x.cpv_habilitado = 1 ORDER BY x.cpv_numero DESC) AS PUB,
            (SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] x WHERE x.cpv_checklist_plantilla = cpl.cpl_id AND x.cpv_checklist_version_estado = 1 AND x.cpv_habilitado = 1 ORDER BY x.cpv_numero DESC) AS BOR
    FROM    [dbo].[Checklist_Plantilla] cpl
    WHERE   cpl.cpl_cliente = @CLIENTE AND cpl.cpl_habilitado = 1
), W AS (SELECT cpl_id, ISNULL(PUB, BOR) AS VER, PUB, BOR FROM V)
SELECT  cpl.cpl_id AS ID, cpl.cpl_codigo AS CODIGO, cpl.cpl_nombre AS NOMBRE,
        ISNULL(cin.cin_nombre, N'') AS PLANTA, ISNULL(at.ati_nombre, N'') AS TIPO,
        ISNULL(cv.cpv_numero, 0) AS VERSION, CAST(CASE WHEN w.PUB IS NULL THEN 0 ELSE 1 END AS BIT) AS PUBLICADA,
        CAST(CASE WHEN w.BOR IS NOT NULL AND w.PUB IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS CAMBIOS,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Seccion] s WHERE s.cps_checklist_plantilla_version = w.VER AND s.cps_habilitado = 1) AS SECCIONES,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i WHERE i.cpi_checklist_plantilla_version = w.VER AND i.cpi_habilitado = 1) AS ITEMS,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i WHERE i.cpi_checklist_plantilla_version = w.VER AND i.cpi_habilitado = 1 AND i.cpi_critico = 1) AS CRITICOS,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i JOIN [dbo].[Checklist_Item_Validacion] c ON c.civ_checklist_plantilla_item = i.cpi_id AND c.civ_habilitado = 1
          WHERE i.cpi_checklist_plantilla_version = w.VER AND i.cpi_habilitado = 1 AND (c.civ_valor_minimo IS NOT NULL OR c.civ_valor_maximo IS NOT NULL)) AS UMBRALES,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i JOIN [dbo].[Checklist_Item_Dependencia] d ON d.cid_checklist_plantilla_item = i.cpi_id AND d.cid_habilitado = 1
          WHERE i.cpi_checklist_plantilla_version = w.VER AND i.cpi_habilitado = 1) AS DEPENDENCIAS,
        (SELECT COUNT(DISTINCT cpr.cpr_programacion) FROM [dbo].[Checklist_Programacion] cpr JOIN [dbo].[Checklist_Plantilla_Version] x ON x.cpv_id = cpr.cpr_checklist_plantilla_version
          WHERE x.cpv_checklist_plantilla = cpl.cpl_id AND cpr.cpr_habilitado = 1 AND cpr.cpr_cliente = @CLIENTE) AS USOS,
        ISNULL(STUFF((SELECT DISTINCT N', ' + ISNULL(NULLIF(cpr.cpr_nombre, N''), N'Inspección ' + CAST(cpr.cpr_programacion AS NVARCHAR(12)))
          FROM [dbo].[Checklist_Programacion] cpr JOIN [dbo].[Checklist_Plantilla_Version] x ON x.cpv_id = cpr.cpr_checklist_plantilla_version
          WHERE x.cpv_checklist_plantilla = cpl.cpl_id AND cpr.cpr_habilitado = 1 AND cpr.cpr_cliente = @CLIENTE FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), N'') AS USOS_TXT
FROM    W w
JOIN    [dbo].[Checklist_Plantilla] cpl ON cpl.cpl_id = w.cpl_id
LEFT JOIN [dbo].[Checklist_Plantilla_Version] cv ON cv.cpv_id = w.VER
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = cpl.cpl_cliente_instalacion
LEFT JOIN [dbo].[Activo_Tipo] at ON at.ati_id = cpl.cpl_activo_tipo
ORDER BY cpl.cpl_codigo
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
SELECT  da.dac_nombre + N' «' + it.cpi_texto + N'» cuando «' + ic.cpi_texto + N'» ' + LOWER(oc.opc_nombre) + N' ' + ISNULL(op.cio_texto, ISNULL(d.cid_valor_comparacion, N'')) AS TEXTO
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

/* Marca crítico en un ítem del borrador (lo usa el guardado del cajón). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_ITEM_CRITICO]
    @ID INT,
    @CRITICO BIT,
    @USUARIO INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Checklist_Plantilla_Item]
SET    cpi_critico = @CRITICO, cpi_usuario_actualizacion = @USUARIO, cpi_fecha_actualizacion = GETDATE()
WHERE  cpi_id = @ID
GO

/* Secciones e ítems vivos del borrador, por código (el guardado del cajón reconcilia con ellos). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_PAUTA_BORRADOR]
    @VERSION INT
AS
SET NOCOUNT ON
SELECT cps_id AS ID, cps_codigo AS CODIGO FROM [dbo].[Checklist_Plantilla_Seccion] WHERE cps_checklist_plantilla_version = @VERSION AND cps_habilitado = 1
SELECT cpi_id AS ID, cpi_codigo AS CODIGO FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_checklist_plantilla_version = @VERSION AND cpi_habilitado = 1
GO

/* Solo la sección y el orden de un ítem que ya existe (sin tocar texto, tipo ni unidad). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_ITEM_ORDEN_RECURSOS]
    @ID INT,
    @SECCION INT,
    @ORDEN INT,
    @USUARIO INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Checklist_Plantilla_Item]
SET    cpi_checklist_plantilla_seccion = @SECCION, cpi_orden = @ORDEN, cpi_usuario_actualizacion = @USUARIO, cpi_fecha_actualizacion = GETDATE()
WHERE  cpi_id = @ID
GO

/* Unidades de medida para el combo de la pauta. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_UNIDAD_MEDIDA_RECURSOS]
AS
SET NOCOUNT ON
SELECT ume_id AS ID, ume_simbolo AS SIMBOLO, ume_nombre AS NOMBRE FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1 ORDER BY ume_nombre
GO

/* ---- 4 · Ajustes ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_AJUSTES]
    @CLIENTE INT
AS
SET NOCOUNT ON
SELECT  c.tca_id AS ID, c.tca_nombre AS NOMBRE, ISNULL(c.tca_color, N'') AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[Tarea] t WHERE t.tar_tarea_categoria = c.tca_id AND t.tar_habilitado = 1) AS USOS
FROM    [dbo].[Tarea_Categoria] c
WHERE   (c.tca_cliente = @CLIENTE OR c.tca_cliente IS NULL) AND c.tca_habilitado = 1
ORDER BY ISNULL(c.tca_orden, 999), c.tca_nombre

SELECT  t.ott_id AS ID, t.ott_nombre AS NOMBRE, N'' AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_orden_trabajo_tipo = t.ott_id AND o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1)
      + (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
           JOIN [dbo].[Plan_Mantenimiento] pm ON pm.pma_id = v.pmv_plan_mantenimiento
          WHERE h.pmh_orden_trabajo_tipo = t.ott_id AND h.pmh_habilitado = 1 AND pm.pma_cliente = @CLIENTE AND v.pmv_plan_version_estado IN (1, 2)) AS USOS,
        CAST(CASE WHEN t.ott_id <= 3 THEN 1 ELSE 0 END AS BIT) AS SISTEMA
FROM    [dbo].[Orden_Trabajo_Tipo] t
WHERE   t.ott_habilitado = 1
ORDER BY ISNULL(t.ott_orden, 999), t.ott_nombre

SELECT  m.amd_id AS ID, m.amd_nombre AS NOMBRE, N'' AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[VW_AVISOS] a WHERE a.CLIENTE = @CLIENTE AND a.ESTADO = 'DESCARTADO' AND a.MOTIVO = m.amd_nombre) AS USOS
FROM    [dbo].[Aviso_Motivo_Descarte] m
WHERE   m.amd_habilitado = 1
ORDER BY m.amd_orden, m.amd_nombre
GO

/* Agregar o quitar un ítem de un catálogo de Ajustes.
   @TIPO: CAT (categoría de tarea, del cliente) · TIPO (tipo de OT, global) · MOT (motivo de descarte, global).
   Quitar es dar de baja, y solo si nadie lo usa. Los tipos de OT base (1-3) no se quitan. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_RECURSOS_AJUSTE]
    @CLIENTE INT,
    @TIPO    VARCHAR(10),
    @ACCION  VARCHAR(10),
    @ID      INT = NULL,
    @NOMBRE  NVARCHAR(200) = NULL,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @USOS INT = 0, @NUEVO INT
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))

IF @ACCION = 'ADD' AND LEN(@NOMBRE) < 3
BEGIN RAISERROR('1.- ESCRIBE UN NOMBRE DE AL MENOS 3 LETRAS.', 16, 1) RETURN -1 END

IF @TIPO = 'CAT'
BEGIN
    IF @ACCION = 'ADD'
    BEGIN
        SELECT TOP 1 @NUEVO = tca_id FROM [dbo].[Tarea_Categoria] WHERE tca_cliente = @CLIENTE AND tca_nombre = @NOMBRE COLLATE Latin1_General_CI_AI
        IF @NUEVO IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @NUEVO AND tca_habilitado = 1)
            BEGIN RAISERROR('2.- YA EXISTE UNA CATEGORÍA CON ESE NOMBRE.', 16, 1) RETURN -1 END
            UPDATE [dbo].[Tarea_Categoria] SET tca_habilitado = 1, tca_usuario_actualizacion = @USUARIO, tca_fecha_actualizacion = GETDATE() WHERE tca_id = @NUEVO
        END
        ELSE
        BEGIN
            DECLARE @N INT = (SELECT COUNT(*) FROM [dbo].[Tarea_Categoria] WHERE tca_cliente = @CLIENTE)
            DECLARE @COD NVARCHAR(50) = N'CAT-' + RIGHT(N'000' + CAST(@N + 1 AS NVARCHAR(10)), 3)
            WHILE EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_cliente = @CLIENTE AND tca_codigo = @COD)
            BEGIN SET @N = @N + 1 SET @COD = N'CAT-' + RIGHT(N'000' + CAST(@N + 1 AS NVARCHAR(10)), 3) END
            DECLARE @COLOR NVARCHAR(20) = CHOOSE((@N % 6) + 1, N'#6732F4', N'#087BEA', N'#007F8A', N'#16855B', N'#B65C00', N'#C7352B')
            INSERT INTO [dbo].[Tarea_Categoria] (tca_cliente, tca_codigo, tca_nombre, tca_color, tca_orden, tca_usuario_creacion, tca_fecha_creacion, tca_habilitado)
            VALUES (@CLIENTE, @COD, @NOMBRE, @COLOR, @N + 1, @USUARIO, GETDATE(), 1)
            SET @NUEVO = SCOPE_IDENTITY()
        END
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @ID AND tca_cliente = @CLIENTE)
        BEGIN RAISERROR('3.- LA CATEGORÍA NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END
        SELECT @USOS = COUNT(*) FROM [dbo].[Tarea] WHERE tar_tarea_categoria = @ID AND tar_habilitado = 1
        IF @USOS > 0 BEGIN RAISERROR('4.- LA CATEGORÍA ESTÁ EN USO: NO SE PUEDE QUITAR.', 16, 1) RETURN -1 END
        UPDATE [dbo].[Tarea_Categoria] SET tca_habilitado = 0, tca_usuario_actualizacion = @USUARIO, tca_fecha_actualizacion = GETDATE() WHERE tca_id = @ID
        SET @NUEVO = @ID
    END
END
ELSE IF @TIPO = 'TIPO'
BEGIN
    IF @ACCION = 'ADD'
    BEGIN
        IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_nombre = @NOMBRE COLLATE Latin1_General_CI_AI AND ott_habilitado = 1)
        BEGIN RAISERROR('2.- YA EXISTE UN TIPO DE OT CON ESE NOMBRE.', 16, 1) RETURN -1 END
        DECLARE @T TABLE (ID INT)
        INSERT @T EXEC [dbo].[INS_ORDEN_TRABAJO_TIPO] @ID = @NUEVO OUTPUT, @NOMBRE = @NOMBRE, @USUARIO = @USUARIO
    END
    ELSE
    BEGIN
        IF @ID <= 3 BEGIN RAISERROR('5.- LOS TIPOS DE OT BASE DE SIGMA NO SE QUITAN.', 16, 1) RETURN -1 END
        SELECT @USOS = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_orden_trabajo_tipo = @ID)
                     + (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_orden_trabajo_tipo = @ID AND pmh_habilitado = 1)
        IF @USOS > 0 BEGIN RAISERROR('4.- EL TIPO DE OT ESTÁ EN USO: NO SE PUEDE QUITAR.', 16, 1) RETURN -1 END
        UPDATE [dbo].[Orden_Trabajo_Tipo] SET ott_habilitado = 0 WHERE ott_id = @ID
        SET @NUEVO = @ID
    END
END
ELSE IF @TIPO = 'MOT'
BEGIN
    IF @ACCION = 'ADD'
    BEGIN
        SELECT TOP 1 @NUEVO = amd_id FROM [dbo].[Aviso_Motivo_Descarte] WHERE amd_nombre = @NOMBRE COLLATE Latin1_General_CI_AI
        IF @NUEVO IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM [dbo].[Aviso_Motivo_Descarte] WHERE amd_id = @NUEVO AND amd_habilitado = 1)
            BEGIN RAISERROR('2.- YA EXISTE ESE MOTIVO.', 16, 1) RETURN -1 END
            UPDATE [dbo].[Aviso_Motivo_Descarte] SET amd_habilitado = 1 WHERE amd_id = @NUEVO
        END
        ELSE
        BEGIN
            INSERT INTO [dbo].[Aviso_Motivo_Descarte] (amd_nombre, amd_orden, amd_usuario_creacion)
            VALUES (@NOMBRE, ISNULL((SELECT MAX(amd_orden) FROM [dbo].[Aviso_Motivo_Descarte]), 0) + 1, @USUARIO)
            SET @NUEVO = SCOPE_IDENTITY()
        END
    END
    ELSE
    BEGIN
        DECLARE @MN NVARCHAR(200) = (SELECT amd_nombre FROM [dbo].[Aviso_Motivo_Descarte] WHERE amd_id = @ID)
        IF @MN IS NULL BEGIN RAISERROR('3.- EL MOTIVO NO EXISTE.', 16, 1) RETURN -1 END
        SELECT @USOS = COUNT(*) FROM [dbo].[VW_AVISOS] WHERE ESTADO = 'DESCARTADO' AND MOTIVO = @MN
        IF @USOS > 0 BEGIN RAISERROR('4.- EL MOTIVO ESTÁ EN USO: NO SE PUEDE QUITAR.', 16, 1) RETURN -1 END
        UPDATE [dbo].[Aviso_Motivo_Descarte] SET amd_habilitado = 0 WHERE amd_id = @ID
        SET @NUEVO = @ID
    END
END
ELSE
BEGIN RAISERROR('6.- EL CATÁLOGO NO EXISTE.', 16, 1) RETURN -1 END

SELECT @NUEVO AS ID
GO
PRINT '406_RECURSOS aplicado.'
GO
