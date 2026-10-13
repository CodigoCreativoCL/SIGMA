/* ============================================================================
   454 · Imágenes de referencia (HU-143) — 12-10-2026. Autora: Catalina Pescio.
   T-5262 a T-5266 (SP y datos de prueba).

   QUÉ ES UNA REFERENCIA
     La foto de cómo debe quedar un trabajo. Vive en Archivo_Vinculo con UNO de
     dos destinos (CK_AVI_UN_PADRE): la actividad del plan
     (avi_plan_mantenimiento_actividad) o el ítem de la pauta
     (avi_checklist_plantilla_item), con avi_es_referencia = 1. Se reconoce por el
     DESTINO, no por la bandera (ver BD/433: la bandera está sobrecargada).
     El archivo nace con la categoría 10 (REFERENCIA).

   POR QUÉ NO HAY TABLA NUEVA NI CÓDIGO
     Las tareas pedían un mantenedor con «código único por cliente»: no aplica.
     Una referencia no tiene identidad propia, es un archivo pegado a su destino.
     Se edita en el cajón de la actividad (Centro de Planificación) y del ítem
     (Biblioteca › Pautas), sin pantallas aparte (regla del equipo: solo cajón).

   PLANES Y PAUTAS SE VERSIONAN
     Editar un plan activo abre un borrador que CLONA hitos y actividades con ids
     nuevos (INS_PLAN_VERSION_NUEVA); lo mismo hace la pauta (GET_CHECKLIST_BORRADOR).
     Sin cambios aquí la referencia se quedaría en la versión vieja y se perdería
     en la siguiente publicada. Por eso los SP que clonan copian también los
     vínculos (apuntan al MISMO archivo, no lo duplican), y los que borran un
     borrador físicamente quitan antes sus vínculos (si no, FK_AVI_PAA / FK_AVI_CPI
     hacen fallar «Descartar cambios»).
     Se adjunta a la versión que muestra la ficha: el borrador si existe, si no la
     publicada. Pegada a la publicada, la ve de inmediato quien ejecute.

   Aplicar con -I (índices filtrados). Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACIÓN:  12-10-2026
-- DESCRIPTION:     SELECT REFERENCIAS DE ACTIVIDADES DEL PLAN O DE ÍTEMS DE PAUTA
--   @ACTIVIDADES / @ITEMS: ids separados por coma (lo que pinta una ficha).
--   @PLANTILLA: los ítems de la versión que muestra el cajón de la pauta
--   (borrador si existe, si no la publicada), como SEL_RECURSOS_PAUTA.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ARCHIVO_REFERENCIA]
    @CLIENTE     INT,
    @ID          INT           = NULL,
    @ACTIVIDADES NVARCHAR(MAX) = NULL,
    @ITEMS       NVARCHAR(MAX) = NULL,
    @PLANTILLA   INT           = NULL
AS
SET NOCOUNT ON
DECLARE @VER INT
IF @PLANTILLA IS NOT NULL
BEGIN
    SELECT TOP 1 @VER = v.cpv_id
    FROM   [dbo].[Checklist_Plantilla_Version] v JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
    WHERE  v.cpv_checklist_plantilla = @PLANTILLA AND p.cpl_cliente = @CLIENTE AND v.cpv_checklist_version_estado IN (1, 2) AND v.cpv_habilitado = 1
    ORDER BY CASE v.cpv_checklist_version_estado WHEN 1 THEN 0 ELSE 1 END, v.cpv_numero DESC
END

;WITH ref AS (
    SELECT avi.avi_id, avi.avi_archivo, avi.avi_titulo, avi.avi_orden, avi.avi_fecha_creacion,
           avi.avi_plan_mantenimiento_actividad, avi.avi_checklist_plantilla_item
    FROM   [dbo].[Archivo_Vinculo] avi
    WHERE  avi.avi_habilitado = 1
      AND  (avi.avi_plan_mantenimiento_actividad IS NOT NULL OR avi.avi_checklist_plantilla_item IS NOT NULL)
      AND  (   (@ID IS NOT NULL AND avi.avi_id = @ID)
            OR (@ACTIVIDADES IS NOT NULL AND avi.avi_plan_mantenimiento_actividad IN (SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@ACTIVIDADES, ',')))
            OR (@ITEMS IS NOT NULL AND avi.avi_checklist_plantilla_item IN (SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@ITEMS, ',')))
            OR (@VER IS NOT NULL AND avi.avi_checklist_plantilla_item IN (SELECT cpi_id FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_checklist_plantilla_version = @VER)))
)
SELECT  r.avi_id AS ID, r.avi_archivo AS ARCHIVO,
        r.avi_plan_mantenimiento_actividad AS ACTIVIDAD, r.avi_checklist_plantilla_item AS ITEM, i.cpi_codigo AS ITEM_CODIGO,
        ISNULL(NULLIF(r.avi_titulo, N''), N'') AS TITULO, arc.arc_nombre_original AS NOMBRE, arc.arc_mime AS MIME,
        ISNULL(r.avi_orden, 0) AS ORDEN, r.avi_fecha_creacion AS FECHA
FROM    ref r
JOIN    [dbo].[Archivo] arc ON arc.arc_id = r.avi_archivo AND arc.arc_cliente = @CLIENTE AND arc.arc_habilitado = 1
LEFT JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = r.avi_checklist_plantilla_item
ORDER BY ISNULL(r.avi_plan_mantenimiento_actividad, 0), ISNULL(r.avi_checklist_plantilla_item, 0), ISNULL(r.avi_orden, 0), r.avi_id
GO

-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACIÓN:  12-10-2026
-- DESCRIPTION:     INSERTA UNA IMAGEN DE REFERENCIA EN UNA ACTIVIDAD DEL PLAN O EN UN ÍTEM DE PAUTA
--   El ítem llega por @ITEM, o por @PLANTILLA + @ITEM_CODIGO (el cajón de la
--   pauta conoce el código, no el id: el id cambia con cada versión).
--   Tope de 6 por destino: es una guía, no una galería.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_ARCHIVO_REFERENCIA]
    @ID          INT           = NULL OUTPUT,
    @CLIENTE     INT,
    @ARCHIVO     INT,
    @ACTIVIDAD   INT           = NULL,
    @ITEM        INT           = NULL,
    @PLANTILLA   INT           = NULL,
    @ITEM_CODIGO NVARCHAR(50)  = NULL,
    @TITULO      NVARCHAR(200) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF @ITEM IS NULL AND @PLANTILLA IS NOT NULL AND NULLIF(@ITEM_CODIGO, N'') IS NOT NULL
BEGIN
    SELECT TOP 1 @ITEM = i.cpi_id
    FROM   [dbo].[Checklist_Plantilla_Item] i
    JOIN   [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
    JOIN   [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
    WHERE  p.cpl_id = @PLANTILLA AND p.cpl_cliente = @CLIENTE AND i.cpi_codigo = @ITEM_CODIGO AND i.cpi_habilitado = 1
      AND  v.cpv_checklist_version_estado IN (1, 2) AND v.cpv_habilitado = 1
    ORDER BY CASE v.cpv_checklist_version_estado WHEN 1 THEN 0 ELSE 1 END, v.cpv_numero DESC
    IF @ITEM IS NULL
    BEGIN
        RAISERROR('1.- GUARDA LA PAUTA ANTES DE ADJUNTAR LA REFERENCIA A ESTE ÍTEM.', 16, 1)
        RETURN -1
    END
END

IF (CASE WHEN @ACTIVIDAD IS NULL THEN 0 ELSE 1 END) + (CASE WHEN @ITEM IS NULL THEN 0 ELSE 1 END) <> 1
BEGIN
    RAISERROR('2.- LA REFERENCIA VA EN UNA ACTIVIDAD O EN UN ÍTEM, NO EN AMBOS NI EN NINGUNO.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE AND arc_habilitado = 1 AND arc_mime LIKE 'image/%')
BEGIN
    RAISERROR('3.- LA REFERENCIA DEBE SER UNA IMAGEN DE ESTA EMPRESA.', 16, 1)
    RETURN -1
END

IF @ACTIVIDAD IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] a
    JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
    JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
    JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
    WHERE a.paa_id = @ACTIVIDAD AND a.paa_habilitado = 1 AND p.pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('4.- LA ACTIVIDAD NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ITEM IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM [dbo].[Checklist_Plantilla_Item] i
    JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
    JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
    WHERE i.cpi_id = @ITEM AND i.cpi_habilitado = 1 AND p.cpl_cliente = @CLIENTE)
BEGIN
    RAISERROR('5.- EL ÍTEM NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo]
     WHERE avi_habilitado = 1 AND (avi_plan_mantenimiento_actividad = @ACTIVIDAD OR avi_checklist_plantilla_item = @ITEM)) >= 6
BEGIN
    RAISERROR('6.- YA HAY 6 IMÁGENES DE REFERENCIA: QUITA UNA ANTES DE AGREGAR OTRA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    INSERT INTO [dbo].[Archivo_Vinculo]
        (avi_archivo, avi_plan_mantenimiento_actividad, avi_checklist_plantilla_item, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo,
         avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    SELECT @ARCHIVO, @ACTIVIDAD, @ITEM, 1, 1,
           ISNULL((SELECT MAX(avi_orden) FROM [dbo].[Archivo_Vinculo] WHERE avi_habilitado = 1 AND (avi_plan_mantenimiento_actividad = @ACTIVIDAD OR avi_checklist_plantilla_item = @ITEM)), 0) + 1,
           NULLIF(LTRIM(RTRIM(@TITULO)), N''), @USUARIO, [dbo].[FNC_AHORA](), 1
    SET @ID = SCOPE_IDENTITY()
COMMIT TRANSACTION

SELECT @ID AS ID
RETURN(0)
GO

-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACIÓN:  12-10-2026
-- DESCRIPTION:     ACTUALIZA EL TEXTO DE UNA IMAGEN DE REFERENCIA («QUÉ DEBE VERSE»)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_ARCHIVO_REFERENCIA]
    @ID      INT,
    @CLIENTE INT,
    @TITULO  NVARCHAR(200) = NULL,
    @USUARIO INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
                WHERE v.avi_id = @ID AND v.avi_habilitado = 1 AND a.arc_cliente = @CLIENTE
                  AND (v.avi_plan_mantenimiento_actividad IS NOT NULL OR v.avi_checklist_plantilla_item IS NOT NULL))
BEGIN
    RAISERROR('1.- LA IMAGEN DE REFERENCIA NO EXISTE.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_titulo = NULLIF(LTRIM(RTRIM(@TITULO)), N''), avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  avi_id = @ID
RETURN(0)
GO

-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACIÓN:  12-10-2026
-- DESCRIPTION:     ELIMINA (BAJA LÓGICA) UNA IMAGEN DE REFERENCIA
--   Baja lógica: el archivo puede seguir pegado a otra versión del plan o de la
--   pauta (los clones apuntan al mismo archivo). No tiene dependientes.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_ARCHIVO_REFERENCIA]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
                WHERE v.avi_id = @ID AND v.avi_habilitado = 1 AND a.arc_cliente = @CLIENTE
                  AND (v.avi_plan_mantenimiento_actividad IS NOT NULL OR v.avi_checklist_plantilla_item IS NOT NULL))
BEGIN
    RAISERROR('1.- LA IMAGEN DE REFERENCIA NO EXISTE O YA SE QUITÓ.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Archivo_Vinculo]
SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  avi_id = @ID
RETURN(0)
GO

/* ============================================================================
   SP VIGENTES QUE CLONAN O BORRAN ACTIVIDADES E ÍTEMS
   Copiados de la base (OBJECT_DEFINITION, 12-10-2026) para no partir de un
   archivo viejo; el único cambio es el bloque marcado «454 (HU-143)».
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_VERSION_NUEVA]
@ID          INT = NULL OUTPUT,
@CLIENTE     INT,
@PLAN        INT,
@OBSERVACION NVARCHAR(1000) = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE AND pma_habilitado = 1)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE O ESTÁ DESHABILITADO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1)
BEGIN
    RAISERROR('2.- EL PLAN YA TIENE UNA VERSIÓN EN BORRADOR; EDÍTELA O PUBLÍQUELA ANTES DE ABRIR OTRA.', 16, 1)
    RETURN -1
END

-- La version que manda: la publicada; si no hay, la ultima que exista.
DECLARE @ORIGEN INT = [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN)
IF @ORIGEN IS NULL
    SET @ORIGEN = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)

DECLARE @NUMERO INT = ISNULL((SELECT MAX(pmv_numero) FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN), 0) + 1

BEGIN TRY
    BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Version]
        (pmv_plan_mantenimiento, pmv_numero, pmv_plan_version_estado, pmv_observacion,
         pmv_usuario_creacion, pmv_fecha_creacion, pmv_usuario_actualizacion, pmv_fecha_actualizacion, pmv_habilitado)
    VALUES
        (@PLAN, @NUMERO, 1, @OBSERVACION, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @ORIGEN IS NOT NULL
    BEGIN
        -- Hitos (384: tambien los deshabilitados: en el Centro, deshabilitar
        -- una intervencion es un estado, no una baja), con su mapa
        DECLARE @MAPA TABLE (viejo INT, nuevo INT)

        MERGE [dbo].[Plan_Mantenimiento_Hito] AS destino
        USING (SELECT * FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @ORIGEN) AS h
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
                    pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
                    pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion,
                    pmh_usuario_responsable, pmh_grupo_trabajo,
                    pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion, pmh_habilitado)
            VALUES (@ID, h.pmh_programacion, h.pmh_codigo, h.pmh_nombre, h.pmh_orden, h.pmh_valor_medidor,
                    h.pmh_unidad_medida, h.pmh_es_overhaul, h.pmh_requiere_parada, h.pmh_duracion_estimada_minuto,
                    h.pmh_orden_trabajo_tipo, h.pmh_orden_trabajo_prioridad, h.pmh_descripcion,
                    h.pmh_usuario_responsable, h.pmh_grupo_trabajo,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, h.pmh_habilitado)
        OUTPUT h.pmh_id, inserted.pmh_id INTO @MAPA (viejo, nuevo);

        -- 391: los responsables de cada intervención viajan con ella
        INSERT INTO [dbo].[Plan_Mantenimiento_Hito_Responsable]
            (phr_plan_mantenimiento_hito, phr_usuario, phr_orden, phr_usuario_creacion, phr_fecha_creacion)
        SELECT m.nuevo, r.phr_usuario, r.phr_orden, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Mantenimiento_Hito_Responsable] r
        JOIN   @MAPA m ON m.viejo = r.phr_plan_mantenimiento_hito

        /* 411: la empresa externa de cada intervención también viaja con ella. */
        INSERT INTO [dbo].[Plan_Mantenimiento_Hito_Proveedor] (php_plan_mantenimiento_hito, php_proveedor, php_usuario_creacion, php_fecha_creacion)
        SELECT m.nuevo, x.php_proveedor, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Mantenimiento_Hito_Proveedor] x
        JOIN   @MAPA m ON m.viejo = x.php_plan_mantenimiento_hito

        -- Actividades de cada hito (HU-082), con su mapa para los repuestos
        DECLARE @MAPA_ACT TABLE (viejo INT, nuevo INT)

        MERGE [dbo].[Plan_Mantenimiento_Actividad] AS d
        USING (SELECT a.*, m.nuevo AS hito_nuevo FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN @MAPA m ON m.viejo = a.paa_plan_mantenimiento_hito
                WHERE a.paa_habilitado = 1) AS a
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion, paa_orden,
                    paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada, paa_requiere_permiso, paa_permiso_trabajo_tipo,
                    paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion, paa_habilitado)
            VALUES (a.hito_nuevo, a.paa_procedimiento, a.paa_codigo, a.paa_nombre, a.paa_descripcion, a.paa_orden,
                    a.paa_duracion_estimada_minuto, a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT a.paa_id, inserted.paa_id INTO @MAPA_ACT (viejo, nuevo);

        -- 384: los repuestos planificados viajan con su actividad
        INSERT [dbo].[Plan_Actividad_Repuesto]
            (pra_plan_mantenimiento_actividad, pra_repuesto, pra_cantidad, pra_unidad_medida, pra_obligatorio, pra_observacion,
             pra_usuario_creacion, pra_fecha_creacion)
        SELECT m.nuevo, r.pra_repuesto, r.pra_cantidad, r.pra_unidad_medida, r.pra_obligatorio, r.pra_observacion, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Actividad_Repuesto] r JOIN @MAPA_ACT m ON m.viejo = r.pra_plan_mantenimiento_actividad

        -- 454 (HU-143): las imágenes de referencia viajan con su actividad (apuntan al mismo archivo)
        INSERT [dbo].[Archivo_Vinculo]
            (avi_archivo, avi_plan_mantenimiento_actividad, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo, avi_descripcion,
             avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
        SELECT v.avi_archivo, m.nuevo, 1, v.avi_es_foto, v.avi_orden, v.avi_titulo, v.avi_descripcion, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Archivo_Vinculo] v JOIN @MAPA_ACT m ON m.viejo = v.avi_plan_mantenimiento_actividad
        WHERE  v.avi_habilitado = 1

        -- Equipos
        INSERT [dbo].[Plan_Mantenimiento_Activo]
            (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor, pac_usuario_creacion, pac_fecha_creacion)
        SELECT @ID, pac_activo, pac_activo_componente, pac_activo_medidor, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Mantenimiento_Activo]
        WHERE  pac_plan_mantenimiento_version = @ORIGEN
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_PLAN_VERSION_NUEVA', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE ABRIR LA VERSIÓN NUEVA: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ---- 7 · copias y OT (BD/384 + 391) ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_DUPLICAR]
    @ID          INT = NULL OUTPUT,
    @CLIENTE     INT,
    @PLAN        INT,
    @NOMBRE      NVARCHAR(400) = NULL,
    @CON_ACTIVOS BIT = 0,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @ORIGEN INT, @R INT, @VNUEVA INT, @CODIGO NVARCHAR(100)
DECLARE @PLANTA INT, @DESC NVARCHAR(MAX), @PLANIF INT, @TIPO INT, @MODELO INT, @NOMBRE_ORIG NVARCHAR(400)

SELECT @PLANTA = pma_cliente_instalacion, @DESC = pma_descripcion, @PLANIF = pma_usuario_planificador,
       @TIPO = pma_activo_tipo, @MODELO = pma_activo_modelo, @NOMBRE_ORIG = pma_nombre
FROM   [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE

IF @NOMBRE_ORIG IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SET @ORIGEN = [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN)
IF @ORIGEN IS NULL
    SELECT TOP 1 @ORIGEN = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY CASE WHEN pmv_plan_version_estado = 1 THEN 0 ELSE 1 END, pmv_numero DESC

SET @NOMBRE = LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(@NOMBRE)), N''), LEFT(N'Copia de ' + @NOMBRE_ORIG, 400))))

EXEC @R = [dbo].[INS_PLAN_MANTENIMIENTO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
     @CODIGO = 'AUTO', @NOMBRE = @NOMBRE, @DESCRIPCION = @DESC, @USUARIO_PLANIFICADOR = @PLANIF,
     @ACTIVO_TIPO = @TIPO, @ACTIVO_MODELO = @MODELO, @USUARIO = @USUARIO
IF ISNULL(@R, -1) <> 0 OR @ID IS NULL RETURN -1

SELECT @CODIGO = pma_codigo FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @ID
SELECT TOP 1 @VNUEVA = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @ID ORDER BY pmv_numero

IF @ORIGEN IS NOT NULL
BEGIN
    DECLARE @MAPA TABLE (viejo INT, nuevo INT)
    DECLARE @H INT, @PRO INT, @PRIV BIT, @HCOD NVARCHAR(100), @NPRO INT, @NH INT, @NOMPRO NVARCHAR(400)

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT h.pmh_id, h.pmh_programacion, g.pro_es_privada, h.pmh_codigo
        FROM   [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
        WHERE  h.pmh_plan_mantenimiento_version = @ORIGEN AND h.pmh_habilitado = 1
        ORDER BY h.pmh_orden
    OPEN cur
    FETCH NEXT FROM cur INTO @H, @PRO, @PRIV, @HCOD
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NPRO = @PRO
        IF @PRIV = 1
        BEGIN
            SET @NOMPRO = @CODIGO + N' · ' + @HCOD
            EXEC @R = [dbo].[INS_PROGRAMACION_COPIA] @ID = @NPRO OUTPUT, @CLIENTE = @CLIENTE, @ORIGEN = @PRO, @NOMBRE = @NOMPRO, @USUARIO = @USUARIO
        END

        INSERT INTO [dbo].[Plan_Mantenimiento_Hito]
            (pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
             pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
             pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion, pmh_usuario_responsable, pmh_grupo_trabajo,
             pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion, pmh_habilitado)
        SELECT @VNUEVA, @NPRO, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
               pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
               pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion, pmh_usuario_responsable, pmh_grupo_trabajo,
               @USUARIO, @AHORA, @USUARIO, @AHORA, 1
        FROM   [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @H
        SET @NH = SCOPE_IDENTITY()
        INSERT @MAPA VALUES (@H, @NH)

        FETCH NEXT FROM cur INTO @H, @PRO, @PRIV, @HCOD
    END
    CLOSE cur
    DEALLOCATE cur

    /* 391: los responsables de cada intervención viajan con ella. */
    INSERT INTO [dbo].[Plan_Mantenimiento_Hito_Responsable]
        (phr_plan_mantenimiento_hito, phr_usuario, phr_orden, phr_usuario_creacion, phr_fecha_creacion)
    SELECT m.nuevo, r.phr_usuario, r.phr_orden, @USUARIO, @AHORA
    FROM   [dbo].[Plan_Mantenimiento_Hito_Responsable] r
    JOIN   @MAPA m ON m.viejo = r.phr_plan_mantenimiento_hito

    /* 411: la empresa externa de cada intervención también viaja con ella. */
    INSERT INTO [dbo].[Plan_Mantenimiento_Hito_Proveedor] (php_plan_mantenimiento_hito, php_proveedor, php_usuario_creacion, php_fecha_creacion)
    SELECT m.nuevo, x.php_proveedor, @USUARIO, @AHORA
    FROM   [dbo].[Plan_Mantenimiento_Hito_Proveedor] x
    JOIN   @MAPA m ON m.viejo = x.php_plan_mantenimiento_hito

    DECLARE @MAPA_ACT TABLE (viejo INT, nuevo INT)
    MERGE [dbo].[Plan_Mantenimiento_Actividad] AS d
    USING (SELECT a.*, m.nuevo AS hito_nuevo FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN @MAPA m ON m.viejo = a.paa_plan_mantenimiento_hito
            WHERE a.paa_habilitado = 1) AS s
       ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion, paa_orden,
                paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada, paa_requiere_permiso, paa_permiso_trabajo_tipo,
                paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion, paa_habilitado)
        VALUES (s.hito_nuevo, s.paa_procedimiento, s.paa_codigo, s.paa_nombre, s.paa_descripcion, s.paa_orden,
                s.paa_duracion_estimada_minuto, s.paa_obligatoria, s.paa_requiere_parada, s.paa_requiere_permiso, s.paa_permiso_trabajo_tipo,
                @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
    OUTPUT s.paa_id, inserted.paa_id INTO @MAPA_ACT (viejo, nuevo);

    INSERT INTO [dbo].[Plan_Actividad_Repuesto]
        (pra_plan_mantenimiento_actividad, pra_repuesto, pra_cantidad, pra_unidad_medida, pra_obligatorio, pra_observacion, pra_usuario_creacion, pra_fecha_creacion)
    SELECT m.nuevo, r.pra_repuesto, r.pra_cantidad, r.pra_unidad_medida, r.pra_obligatorio, r.pra_observacion, @USUARIO, @AHORA
    FROM   [dbo].[Plan_Actividad_Repuesto] r JOIN @MAPA_ACT m ON m.viejo = r.pra_plan_mantenimiento_actividad

    -- 454 (HU-143): las imágenes de referencia viajan con su actividad (apuntan al mismo archivo)
    INSERT [dbo].[Archivo_Vinculo]
        (avi_archivo, avi_plan_mantenimiento_actividad, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo, avi_descripcion,
         avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
    SELECT v.avi_archivo, m.nuevo, 1, v.avi_es_foto, v.avi_orden, v.avi_titulo, v.avi_descripcion, @USUARIO, @AHORA, 1
    FROM   [dbo].[Archivo_Vinculo] v JOIN @MAPA_ACT m ON m.viejo = v.avi_plan_mantenimiento_actividad
    WHERE  v.avi_habilitado = 1

    IF @CON_ACTIVOS = 1
        INSERT INTO [dbo].[Plan_Mantenimiento_Activo]
            (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor, pac_usuario_creacion, pac_fecha_creacion)
        SELECT @VNUEVA, a.pac_activo, a.pac_activo_componente, a.pac_activo_medidor, @USUARIO, @AHORA
        FROM   [dbo].[Plan_Mantenimiento_Activo] a JOIN [dbo].[Activo] x ON x.act_id = a.pac_activo AND x.act_habilitado = 1
        WHERE  a.pac_plan_mantenimiento_version = @ORIGEN
END

SELECT @ID AS PLAN_ID, @CODIGO AS CODIGO, @NOMBRE AS NOMBRE
RETURN(0)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

        -- 454 (HU-143): las imágenes de referencia viajan con su ítem (apuntan al mismo archivo)
        INSERT [dbo].[Archivo_Vinculo]
            (avi_archivo, avi_checklist_plantilla_item, avi_es_referencia, avi_es_foto, avi_orden, avi_titulo, avi_descripcion,
             avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
        SELECT v.avi_archivo, mi.new, 1, v.avi_es_foto, v.avi_orden, v.avi_titulo, v.avi_descripcion, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Archivo_Vinculo] v
        JOIN   @mapItem mi ON mi.old = v.avi_checklist_plantilla_item
        WHERE  v.avi_habilitado = 1;
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ========================================================================
   11. DEL_PLAN_VERSION_BORRADOR (§26.2 · RP-04)
       «Descartar cambios»: elimina el borrador de un plan que tiene otra
       versión. El borrador nunca generó nada: se borra físicamente, y sus
       frecuencias privadas que ya nadie usa se deshabilitan.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_VERSION_BORRADOR]
    @CLIENTE INT,
    @PLAN    INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @D INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT TOP 1 @D = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC

IF @D IS NULL
BEGIN
    RAISERROR('2.- EL PLAN NO TIENE CAMBIOS SIN APLICAR.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version]
                WHERE pmv_plan_mantenimiento = @PLAN AND pmv_id <> @D AND pmv_plan_version_estado IN (2, 3) AND pmv_habilitado = 1)
BEGIN
    RAISERROR('3.- EL PLAN NO TIENE OTRA VERSIÓN: ELIMÍNELO EN VEZ DE DESCARTAR LOS CAMBIOS.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
            WHERE h.pmh_plan_mantenimiento_version = @D)
BEGIN
    RAISERROR('4.- EL BORRADOR YA TIENE EJECUCIONES Y NO SE PUEDE DESCARTAR.', 16, 1)
    RETURN -1
END

DECLARE @PROS TABLE (pro INT)
INSERT @PROS SELECT DISTINCT pmh_programacion FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @D

BEGIN TRANSACTION
    DELETE r FROM [dbo].[Plan_Actividad_Repuesto] r
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE x FROM [dbo].[Plan_Actividad_Checklist] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pck_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE x FROM [dbo].[Plan_Actividad_Especialidad] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pae_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    -- 454 (HU-143): las referencias del borrador (el archivo queda; puede estar en la versión publicada)
    DELETE v FROM [dbo].[Archivo_Vinculo] v
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = v.avi_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE a FROM [dbo].[Plan_Mantenimiento_Actividad] a
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Hito]   WHERE pmh_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @D

    UPDATE g SET pro_habilitado = 0, pro_usuario_actualizacion = @USUARIO, pro_fecha_actualizacion = [dbo].[FNC_AHORA]()
    FROM   [dbo].[Programacion] g JOIN @PROS p ON p.pro = g.pro_id
    WHERE  g.pro_es_privada = 1
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_programacion = g.pro_id)
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o WHERE o.pmo_programacion = g.pro_id)
COMMIT TRANSACTION

RETURN(0)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ========================================================================
   12. DEL_PLAN_HITO_BORRADOR
       Quitar una intervenci�n del borrador. Se borra f�sicamente (con sus
       actividades y repuestos) porque en el borrador nunca gener�: la baja
       l�gica de DEL_PLAN_HITO la dejar�a como �inactiva�, que en el Centro
       significa otra cosa (el interruptor Habilitada).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_HITO_BORRADOR]
    @CLIENTE INT,
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @ESTADO INT, @PRO INT

SELECT @ESTADO = v.pmv_plan_version_estado, @PRO = h.pmh_programacion
FROM   [dbo].[Plan_Mantenimiento_Hito] h
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
WHERE  h.pmh_id = @ID AND p.pma_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA INTERVENCI�N NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ESTADO <> 1
BEGIN
    RAISERROR('2.- LA INTERVENCI�N NO EST� EN UN BORRADOR.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_plan_mantenimiento_hito = @ID)
BEGIN
    RAISERROR('3.- LA INTERVENCI�N YA GENER� EJECUCIONES: DESHABIL�TELA EN VEZ DE QUITARLA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    DELETE r FROM [dbo].[Plan_Actividad_Repuesto] r
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    DELETE x FROM [dbo].[Plan_Actividad_Checklist] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pck_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    DELETE x FROM [dbo].[Plan_Actividad_Especialidad] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pae_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso] s JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = s.otp_plan_mantenimiento_actividad
                WHERE a.paa_plan_mantenimiento_hito = @ID)
        UPDATE [dbo].[Plan_Mantenimiento_Actividad] SET paa_habilitado = 0 WHERE paa_plan_mantenimiento_hito = @ID
    ELSE
    BEGIN
        -- 454 (HU-143): si las actividades se borran, primero sus referencias
        DELETE v FROM [dbo].[Archivo_Vinculo] v
          JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = v.avi_plan_mantenimiento_actividad
         WHERE a.paa_plan_mantenimiento_hito = @ID
        DELETE FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @ID
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @ID)
        UPDATE [dbo].[Plan_Mantenimiento_Hito] SET pmh_habilitado = 0, pmh_usuario_actualizacion = @USUARIO, pmh_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE pmh_id = @ID
    ELSE
        DELETE FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @ID

    UPDATE [dbo].[Programacion] SET pro_habilitado = 0, pro_usuario_actualizacion = @USUARIO, pro_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE pro_id = @PRO AND pro_es_privada = 1
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_programacion = @PRO AND h.pmh_habilitado = 1)
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o WHERE o.pmo_programacion = @PRO)
COMMIT TRANSACTION

RETURN(0)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ========================================================================
   3. LIMPIAR_CHECKLIST_BORRADOR
      Borra secciones, items, opciones y rangos de una version BORRADOR, para
      re-armarla desde la ficha. Solo actua si la version es BORRADOR.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[LIMPIAR_CHECKLIST_BORRADOR]
@VERSION  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version]
                WHERE cpv_id = @VERSION AND cpv_checklist_version_estado = 1)
BEGIN RAISERROR('1.- LA VERSION NO EXISTE O NO ES BORRADOR.', 16, 1) RETURN -1 END

BEGIN TRAN
    DELETE civ FROM [dbo].[Checklist_Item_Validacion] civ
        JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = civ.civ_checklist_plantilla_item
        WHERE i.cpi_checklist_plantilla_version = @VERSION
    DELETE cio FROM [dbo].[Checklist_Item_Opcion] cio
        JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = cio.cio_checklist_plantilla_item
        WHERE i.cpi_checklist_plantilla_version = @VERSION
    -- 454 (HU-143): las referencias de los ítems del borrador
    DELETE v FROM [dbo].[Archivo_Vinculo] v
        JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = v.avi_checklist_plantilla_item
        WHERE i.cpi_checklist_plantilla_version = @VERSION
    DELETE FROM [dbo].[Checklist_Plantilla_Item]    WHERE cpi_checklist_plantilla_version = @VERSION
    DELETE FROM [dbo].[Checklist_Plantilla_Seccion] WHERE cps_checklist_plantilla_version = @VERSION
COMMIT
GO

PRINT '454_IMAGENES_REFERENCIA aplicado.'
GO
