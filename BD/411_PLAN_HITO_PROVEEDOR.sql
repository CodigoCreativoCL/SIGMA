/* ============================================================================
   411 · Plan › empresa externa en la intervención (09-10-2026)

   Paso «Responsable» del plan: además de una o más personas y un grupo, la intervención
   puede ir a una EMPRESA EXTERNA (proveedor contratista). Sin nadie, queda «Disponible»:
   en la app cualquiera la toma.
     · Plan_Mantenimiento_Hito_Proveedor (una por intervención) + UPS_/SEL_PLAN_HITO_PROVEEDOR.
     · INS_PLAN_DUPLICAR e INS_PLAN_VERSION_NUEVA la copian con la intervención.
     · INS_ORDEN_TRABAJO_OCURRENCIA la asigna en la OT: responsable si no hay persona
       responsable; si la hay, apoyo.
   Los tres SP son los vigentes (BD/391) con el bloque «411» agregado. Aplicar con -I.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID('dbo.Plan_Mantenimiento_Hito_Proveedor', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Hito_Proveedor]
    (
        php_id                      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PLAN_HITO_PROVEEDOR PRIMARY KEY,
        php_plan_mantenimiento_hito INT NOT NULL,
        php_proveedor               INT NOT NULL,
        php_usuario_creacion        INT NULL,
        php_fecha_creacion          DATETIME NULL,
        CONSTRAINT FK_PHP_HITO FOREIGN KEY (php_plan_mantenimiento_hito) REFERENCES [dbo].[Plan_Mantenimiento_Hito] (pmh_id) ON DELETE CASCADE,
        CONSTRAINT FK_PHP_PROVEEDOR FOREIGN KEY (php_proveedor) REFERENCES [dbo].[Proveedor] (prv_id)
    )
    CREATE UNIQUE INDEX UX_PHP_HITO ON [dbo].[Plan_Mantenimiento_Hito_Proveedor] (php_plan_mantenimiento_hito)
END
GO

/* Fija (o quita, con @PROVEEDOR NULL) la empresa externa de una intervención en borrador. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_HITO_PROVEEDOR]
    @CLIENTE   INT,
    @HITO      INT,
    @PROVEEDOR INT = NULL,
    @USUARIO   INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
               JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento WHERE h.pmh_id = @HITO AND p.pma_cliente = @CLIENTE)
BEGIN RAISERROR('1.- LA INTERVENCION NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END
DELETE FROM [dbo].[Plan_Mantenimiento_Hito_Proveedor] WHERE php_plan_mantenimiento_hito = @HITO
IF @PROVEEDOR IS NOT NULL
    INSERT INTO [dbo].[Plan_Mantenimiento_Hito_Proveedor] (php_plan_mantenimiento_hito, php_proveedor, php_usuario_creacion, php_fecha_creacion)
    VALUES (@HITO, @PROVEEDOR, @USUARIO, [dbo].[FNC_AHORA]())
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_HITO_PROVEEDOR]
    @CLIENTE INT,
    @PLAN    INT
AS
SET NOCOUNT ON
SELECT  x.php_plan_mantenimiento_hito AS HITO_ID, x.php_proveedor AS PROVEEDOR_ID, pr.prv_razon_social AS PROVEEDOR
FROM    [dbo].[Plan_Mantenimiento_Hito_Proveedor] x
JOIN    [dbo].[Proveedor] pr ON pr.prv_id = x.php_proveedor
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = x.php_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
WHERE   p.pma_id = @PLAN AND p.pma_cliente = @CLIENTE
RETURN 0
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

CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_OCURRENCIA]
@ID         INT = NULL OUTPUT,
@CLIENTE    INT,
@OCURRENCIA INT,
@USUARIO    INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @ESTADO INT, @OT_EXISTE INT, @HITO INT, @ACTIVO INT, @COMPONENTE INT, @FECHA DATETIME,
        @PLAN_CODIGO NVARCHAR(100), @PLAN_NOMBRE NVARCHAR(400), @VERSION INT,
        @HITO_CODIGO NVARCHAR(100), @HITO_NOMBRE NVARCHAR(400), @HITO_DESC NVARCHAR(MAX),
        @OT_TIPO INT, @OT_PRIORIDAD INT, @PARADA BIT, @OVERHAUL BIT, @DURACION INT,
        @INST INT, @AREA INT, @ACT_CODIGO NVARCHAR(100), @ACT_NOMBRE NVARCHAR(400),
        @RESP INT, @GRUPO INT

SELECT  @ESTADO      = o.pmo_plan_ocurrencia_estado,
        @OT_EXISTE   = o.pmo_orden_trabajo,
        @HITO        = o.pmo_plan_mantenimiento_hito,
        @ACTIVO      = o.pmo_activo,
        @COMPONENTE  = o.pmo_activo_componente,
        @FECHA       = o.pmo_fecha_programada_utc,
        @PLAN_CODIGO = pma.pma_codigo,
        @PLAN_NOMBRE = pma.pma_nombre,
        @VERSION     = pmv.pmv_numero,
        @HITO_CODIGO = h.pmh_codigo,
        @HITO_NOMBRE = h.pmh_nombre,
        @HITO_DESC   = h.pmh_descripcion,
        @OT_TIPO     = ISNULL(h.pmh_orden_trabajo_tipo, 1),          -- PREVENTIVA
        @OT_PRIORIDAD= ISNULL(h.pmh_orden_trabajo_prioridad, 2),     -- MEDIA
        @PARADA      = h.pmh_requiere_parada,
        @OVERHAUL    = h.pmh_es_overhaul,
        @DURACION    = h.pmh_duracion_estimada_minuto,
        @INST        = act.act_cliente_instalacion,
        @AREA        = act.act_instalacion_area,
        @ACT_CODIGO  = act.act_codigo,
        @ACT_NOMBRE  = act.act_nombre,
        @RESP        = h.pmh_usuario_responsable,
        @GRUPO       = h.pmh_grupo_trabajo
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
WHERE   o.pmo_id = @OCURRENCIA AND o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1

IF @HITO IS NULL
BEGIN
    RAISERROR('1.- LA OCURRENCIA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- Idempotente: la que ya tiene orden devuelve esa.
IF @OT_EXISTE IS NOT NULL
BEGIN
    SET @ID = @OT_EXISTE
    SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(1 AS BIT) AS YA_EXISTIA
    FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @OT_EXISTE
    RETURN 0
END

IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('2.- SOLO SE GENERA ORDEN DESDE UNA OCURRENCIA PENDIENTE O DISPONIBLE.', 16, 1)
    RETURN -1
END

IF @INST IS NULL
BEGIN
    RAISERROR('3.- EL EQUIPO %s NO TIENE PLANTA: NO SE PUEDE GENERAR LA ORDEN.', 16, 1, @ACT_CODIGO)
    RETURN -1
END

DECLARE @TITULO NVARCHAR(400) = LEFT(@HITO_NOMBRE + N' · ' + @ACT_CODIGO + N' ' + @ACT_NOMBRE, 400)
DECLARE @CUERPO NVARCHAR(MAX) = ISNULL(@HITO_DESC, N'')
    + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + N'Generada desde el plan ' + @PLAN_CODIGO + N' «' + @PLAN_NOMBRE + N'» v' + CAST(@VERSION AS NVARCHAR(10))
    + N', hito ' + @HITO_CODIGO + N', programada para el ' + CONVERT(NVARCHAR(10), @FECHA, 103) + N'.'
    + CASE WHEN @PARADA = 1 THEN CHAR(13) + CHAR(10) + N'REQUIERE PARADA DEL EQUIPO.' ELSE N'' END

DECLARE @REQUIERE_PERMISO BIT = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                                                   WHERE paa_plan_mantenimiento_hito = @HITO AND paa_habilitado = 1 AND paa_requiere_permiso = 1)
                                     THEN 1 ELSE 0 END

BEGIN TRY
    BEGIN TRANSACTION

    -- Correlativo con el candado puesto: dos generaciones a la vez no sacan el mismo numero.
    DECLARE @CORR INT
    SELECT  @CORR = ISNULL(MAX(otr_correlativo), 0) + 1
    FROM    [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
    WHERE   otr_cliente = @CLIENTE

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo,
         otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen,
         otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion,
         otr_fecha_programada_utc, otr_duracion_estimada_minuto,
         otr_minuto_parada_activo, otr_requiere_permiso,
         otr_plan_mantenimiento_ocurrencia, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @INST, @AREA, @CORR,
         @ACTIVO, @COMPONENTE,
         @OT_TIPO, CASE WHEN @OVERHAUL = 1 THEN 5 ELSE 2 END, 2,
         1, @OT_PRIORIDAD,
         @USUARIO, @TITULO, @CUERPO,
         @FECHA, @DURACION,
         CASE WHEN @PARADA = 1 THEN @DURACION ELSE NULL END, @REQUIERE_PERMISO,
         @OCURRENCIA, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES
        (@ID, NULL, 1, N'Generada desde la ocurrencia del plan ' + @PLAN_CODIGO, GETUTCDATE(), @USUARIO, @DATE_NOW)

    -- Un paso por actividad, con el texto COPIADO (criterio 2)
    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        (otp_orden_trabajo, otp_procedimiento_paso, otp_plan_mantenimiento_actividad, otp_orden, otp_nombre, otp_descripcion,
         otp_obligatorio, otp_resultado_paso, otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
    /* HU-062 #1 / HU-061 #2: si la actividad referencia un procedimiento,
       la orden trae un paso por cada paso del procedimiento, con el nombre
       y la instruccion COPIADOS en ese momento. Asi la orden conserva el
       texto que tenia al ejecutarse aunque el procedimiento cambie despues.
       Una actividad sin procedimiento sigue siendo un solo paso. */
    SELECT  @ID, pp.ppa_id, a.paa_id,
            ROW_NUMBER() OVER (ORDER BY a.paa_orden, a.paa_id, pp.ppa_orden),
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_nombre
                 ELSE a.paa_nombre + N' · ' + CAST(pp.ppa_orden AS NVARCHAR(10)) + N'. ' + pp.ppa_nombre END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_descripcion ELSE ISNULL(pp.ppa_instruccion, a.paa_descripcion) END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_obligatoria
                 WHEN pp.ppa_es_punto_control = 1 THEN 1 ELSE a.paa_obligatoria END,
            4, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Actividad] a
    LEFT JOIN [dbo].[Procedimiento_Paso] pp
           ON pp.ppa_procedimiento = a.paa_procedimiento AND pp.ppa_habilitado = 1
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1

    -- Sin actividades cargadas: el hito es el unico paso, para que la orden sea ejecutable.
    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[Orden_Trabajo_Paso]
            (otp_orden_trabajo, otp_orden, otp_nombre, otp_descripcion, otp_obligatorio, otp_resultado_paso,
             otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
        VALUES
            (@ID, 1, @HITO_NOMBRE, @HITO_DESC, 1, 4, @USUARIO, @DATE_NOW, 1)

    -- Repuestos planificados de esas actividades
    INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
        (ore_orden_trabajo, ore_repuesto, ore_cantidad_planificada, ore_observacion, ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
    SELECT  @ID, r.pra_repuesto, SUM(r.pra_cantidad),
            CASE WHEN MAX(CAST(r.pra_obligatorio AS INT)) = 1 THEN N'Planificado por el plan (obligatorio)' ELSE N'Planificado por el plan' END,
            @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Actividad_Repuesto] r
    JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1
    GROUP BY r.pra_repuesto

    /* 384 · RP-09: la OT nace asignada al responsable de la intervención o,
       si solo tiene grupo, a su líder vigente (como INS_ORDEN_TRABAJO_ASIGNACION). */
    DECLARE @ASIGNADO INT = @RESP
    IF @ASIGNADO IS NULL AND @GRUPO IS NOT NULL
        SELECT TOP 1 @ASIGNADO = gtu_usuario
          FROM [dbo].[Grupo_Trabajo_Usuario]
         WHERE gtu_grupo_trabajo = @GRUPO AND gtu_es_lider = 1
           AND gtu_fecha_inicio <= CAST(@DATE_NOW AS DATE) AND (gtu_fecha_fin IS NULL OR gtu_fecha_fin >= CAST(@DATE_NOW AS DATE))
         ORDER BY gtu_fecha_inicio DESC

    IF @ASIGNADO IS NOT NULL
    BEGIN
        INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
            (ota_orden_trabajo, ota_usuario, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_asignado_por,
             ota_observacion, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
        VALUES
            (@ID, @ASIGNADO, @GRUPO, 1, 1, @USUARIO,
             N'Asignada por el plan ' + @PLAN_CODIGO, @USUARIO, @DATE_NOW, 1)

        UPDATE [dbo].[Orden_Trabajo] SET otr_usuario_responsable = @ASIGNADO WHERE otr_id = @ID
    END

    /* 391: los demás responsables de la intervención entran como apoyo
       (UX_OTA_RESPONSABLE admite un solo responsable por OT). */
    INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
        (ota_orden_trabajo, ota_usuario, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_asignado_por,
         ota_observacion, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
    SELECT  @ID, r.phr_usuario, @GRUPO, 0, 2, @USUARIO,
            N'Asignada por el plan ' + @PLAN_CODIGO, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Hito_Responsable] r
    WHERE   r.phr_plan_mantenimiento_hito = @HITO AND r.phr_usuario <> ISNULL(@ASIGNADO, 0)
    ORDER BY r.phr_orden

    /* 411: la empresa externa de la intervención: responsable si nadie más lo es; si no, apoyo. */
    INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
        (ota_orden_trabajo, ota_usuario, ota_proveedor, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_asignado_por,
         ota_observacion, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
    SELECT  @ID, NULL, x.php_proveedor, NULL, CASE WHEN @ASIGNADO IS NULL THEN 1 ELSE 0 END, CASE WHEN @ASIGNADO IS NULL THEN 1 ELSE 2 END, @USUARIO,
            N'Asignada por el plan ' + @PLAN_CODIGO, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Hito_Proveedor] x
    WHERE   x.php_plan_mantenimiento_hito = @HITO

    -- La ocurrencia queda enlazada y en ejecucion, con su rastro
    UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
    SET    pmo_orden_trabajo = @ID,
           pmo_plan_ocurrencia_estado = 3,
           pmo_usuario_actualizacion = @USUARIO,
           pmo_fecha_actualizacion = @DATE_NOW
    WHERE  pmo_id = @OCURRENCIA

    INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
        (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
    VALUES
        (@OCURRENCIA, @ESTADO, 3, N'Se generó la orden de trabajo OT-' + CAST(@CORR AS NVARCHAR(10)), @USUARIO, @DATE_NOW)

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_OCURRENCIA', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE GENERAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(0 AS BIT) AS YA_EXISTIA
FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @ID

RETURN 0
GO

PRINT '411_PLAN_HITO_PROVEEDOR aplicado.'
GO
