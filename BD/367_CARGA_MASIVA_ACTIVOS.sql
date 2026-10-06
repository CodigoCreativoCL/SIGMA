USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     CARGA DE DATOS · ACTIVOS: todo lo que pide la ficha de
--                  «Nuevo activo» (6 pasos), desde un libro de Excel.
-- =============================================
-- Mismo contrato que PRC_CARGA_INVENTARIO (Carga_Masiva, Carga_Masiva_Fila
-- con el JSON de cada fila, Carga_Masiva_Error, revisar antes de cargar y
-- ACTUALIZAR/OMITIR los existentes). Hojas, en orden:
--
--   ACTIVOS               paso 1 y 2 de la ficha: codigo, nombre, planta,
--                         area, tipo, modelo, marca, serie, estado,
--                         criticidad, centro de costo, de que activo depende,
--                         año, puesta en marcha, si esta en uso, descripcion.
--   DATOS TECNICOS        paso 3: potencia, voltaje... (GRABAR_DATO_ACTIVO).
--   COMPONENTES           paso 4: que es y donde va (se crean si no existen).
--   VARIABLES             paso 5: lo que se mide y su rango normal.
--   MEDIDORES             paso 6: horas, ciclos, km, con la lectura de hoy.
--   REPUESTOS COMPATIBLES los repuestos de bodega que le sirven.
--
-- Cada hoja nombra activos por CODIGO o NOMBRE, de la base o de la hoja
-- ACTIVOS del mismo archivo. Se escribe por los mismos SP que la ficha:
-- las reglas no se duplican.
--
-- Los hijos (componentes, variables, medidores y repuestos) no se duplican
-- al volver a cargar el archivo: si ya existe uno igual en ese activo, la
-- fila se omite.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[PRC_CARGA_ACTIVOS]
    @CARGA INT
AS
SET NOCOUNT ON
SET XACT_ABORT OFF
DECLARE @TC0 INT = @@TRANCOUNT

DECLARE @CLIENTE INT, @USUARIO INT, @MODO VARCHAR(10), @EXIST VARCHAR(12), @CARGAR BIT, @OMITIR BIT
SELECT @CLIENTE = cma_cliente, @USUARIO = cma_usuario, @MODO = cma_modo, @EXIST = cma_existentes
FROM   [dbo].[Carga_Masiva] WHERE cma_id = @CARGA
IF @CLIENTE IS NULL RETURN
SET @CARGAR = CASE WHEN @MODO = 'CARGAR' THEN 1 ELSE 0 END
SET @OMITIR = CASE WHEN @EXIST = 'OMITIR' THEN 1 ELSE 0 END

UPDATE [dbo].[Carga_Masiva] SET cma_estado = 'PROCESANDO', cma_fase = N'Revisando activos' WHERE cma_id = @CARGA
DELETE FROM [dbo].[Carga_Masiva_Error] WHERE cme_carga = @CARGA
UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = NULL, cmf_id = NULL WHERE cmf_carga = @CARGA

DECLARE @f INT, @n INT = 0, @id INT, @nuevo INT, @hoy DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

/* Unidades: por codigo, nombre o simbolo (como en la hoja UNIDADES). */
CREATE TABLE #uni (clave NVARCHAR(200) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #uni SELECT ume_codigo, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1
INSERT INTO #uni SELECT ume_nombre, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1
INSERT INTO #uni SELECT ume_simbolo, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1 AND ume_simbolo IS NOT NULL

/* ======================================================================
   1. ACTIVOS
   ====================================================================== */
CREATE TABLE #act (
    fila INT PRIMARY KEY, codigo NVARCHAR(100), nombre NVARCHAR(400), planta NVARCHAR(400), area NVARCHAR(400),
    tipo NVARCHAR(400), modelo NVARCHAR(400), marca NVARCHAR(200), serie NVARCHAR(200), estado NVARCHAR(200),
    criticidad NVARCHAR(200), centro NVARCHAR(400), padre NVARCHAR(400), anio_t NVARCHAR(20), puesta_t NVARCHAR(40),
    en_uso NVARCHAR(10), descripcion NVARCHAR(2000),
    cod_final NVARCHAR(100), planta_id INT, area_id INT, estado_id INT, criticidad_id INT, centro_id INT,
    padre_id INT, padre_fila INT, anio INT, puesta DATE,
    id INT, cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #act (fila, codigo, nombre, planta, area, tipo, modelo, marca, serie, estado, criticidad, centro, padre, anio_t, puesta_t, en_uso, descripcion)
SELECT f.cmf_fila, NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.planta)), N''),
       NULLIF(LTRIM(RTRIM(j.area)), N''), NULLIF(LTRIM(RTRIM(j.tipo)), N''), NULLIF(LTRIM(RTRIM(j.modelo)), N''), NULLIF(LTRIM(RTRIM(j.marca)), N''),
       NULLIF(LTRIM(RTRIM(j.serie)), N''), NULLIF(LTRIM(RTRIM(j.estado)), N''), NULLIF(LTRIM(RTRIM(j.criticidad)), N''),
       NULLIF(LTRIM(RTRIM(j.centro)), N''), NULLIF(LTRIM(RTRIM(j.padre)), N''), NULLIF(LTRIM(RTRIM(j.anio)), N''),
       NULLIF(LTRIM(RTRIM(j.puesta)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.en_uso))), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', planta NVARCHAR(400) '$.PLANTA',
        area NVARCHAR(400) '$.AREA', tipo NVARCHAR(400) '$.TIPO', modelo NVARCHAR(400) '$.MODELO', marca NVARCHAR(200) '$.MARCA',
        serie NVARCHAR(200) '$.SERIE', estado NVARCHAR(200) '$.ESTADO', criticidad NVARCHAR(200) '$.CRITICIDAD',
        centro NVARCHAR(400) '$.CENTRO_COSTO', padre NVARCHAR(400) '$.DEPENDE_DE', anio NVARCHAR(20) '$.ANIO_FABRICACION',
        puesta NVARCHAR(40) '$.PUESTA_MARCHA', en_uso NVARCHAR(10) '$.EN_USO', descripcion NVARCHAR(2000) '$.DESCRIPCION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'ACTIVOS'

/* El codigo como lo guarda la ficha: ACT-<lo escrito>. */
UPDATE #act SET cod_final = CASE WHEN codigo IS NULL THEN NULL WHEN codigo LIKE N'ACT-%' THEN codigo ELSE N'ACT-' + codigo END

UPDATE a SET planta_id = x.cin_id FROM #act a
CROSS APPLY (SELECT TOP 1 cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1
             AND (cin_nombre COLLATE Latin1_General_CI_AI = a.planta OR cin_codigo COLLATE Latin1_General_CI_AI = a.planta) ORDER BY cin_id) x
WHERE a.planta IS NOT NULL

UPDATE a SET area_id = x.iar_id FROM #act a
CROSS APPLY (SELECT TOP 1 iar_id FROM [dbo].[Instalacion_Area] WHERE iar_cliente = @CLIENTE AND ISNULL(iar_habilitado, 1) = 1
             AND (a.planta_id IS NULL OR iar_cliente_instalacion = a.planta_id)
             AND (iar_nombre COLLATE Latin1_General_CI_AI = a.area OR iar_codigo COLLATE Latin1_General_CI_AI = a.area) ORDER BY iar_id) x
WHERE a.area IS NOT NULL

UPDATE a SET estado_id = x.aes_id FROM #act a
CROSS APPLY (SELECT TOP 1 aes_id FROM [dbo].[Activo_Estado] WHERE aes_habilitado = 1
             AND (aes_nombre COLLATE Latin1_General_CI_AI = a.estado OR aes_codigo COLLATE Latin1_General_CI_AI = a.estado) ORDER BY aes_orden) x
WHERE a.estado IS NOT NULL

UPDATE a SET criticidad_id = x.crn_id FROM #act a
CROSS APPLY (SELECT TOP 1 crn_id FROM [dbo].[Criticidad_Nivel] WHERE crn_habilitado = 1
             AND (crn_nombre COLLATE Latin1_General_CI_AI = a.criticidad OR crn_codigo COLLATE Latin1_General_CI_AI = a.criticidad) ORDER BY crn_orden) x
WHERE a.criticidad IS NOT NULL

UPDATE a SET centro_id = x.cco_id FROM #act a
CROSS APPLY (SELECT TOP 1 cco_id FROM [dbo].[Centro_Costo] WHERE cco_cliente = @CLIENTE AND ISNULL(cco_habilitado, 1) = 1
             AND (cco_nombre COLLATE Latin1_General_CI_AI = a.centro OR cco_codigo COLLATE Latin1_General_CI_AI = a.centro) ORDER BY cco_id) x
WHERE a.centro IS NOT NULL

UPDATE #act SET anio = TRY_CONVERT(INT, anio_t), puesta = TRY_CONVERT(DATE, puesta_t)

/* Existente: por codigo; sin codigo, por nombre en la misma planta. */
UPDATE a SET id = x.act_id FROM #act a
CROSS APPLY (SELECT TOP 1 act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE
             AND ((a.cod_final IS NOT NULL AND act_codigo COLLATE Latin1_General_CI_AI = a.cod_final)
               OR (a.cod_final IS NULL AND act_nombre COLLATE Latin1_General_CI_AI = a.nombre
                   AND (a.planta_id IS NULL OR act_cliente_instalacion = a.planta_id)))
             ORDER BY act_id) x

/* De que activo depende: de la base o de otra fila de esta hoja. */
UPDATE a SET padre_id = x.act_id FROM #act a
CROSS APPLY (SELECT TOP 1 act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE
             AND (act_codigo COLLATE Latin1_General_CI_AI = a.padre OR act_codigo COLLATE Latin1_General_CI_AI = N'ACT-' + a.padre
                  OR act_nombre COLLATE Latin1_General_CI_AI = a.padre) ORDER BY CASE WHEN act_nombre COLLATE Latin1_General_CI_AI = a.padre THEN 1 ELSE 0 END, act_id) x
WHERE a.padre IS NOT NULL
UPDATE a SET padre_fila = x.fila FROM #act a
CROSS APPLY (SELECT TOP 1 p.fila FROM #act p WHERE p.fila <> a.fila
             AND (p.cod_final COLLATE Latin1_General_CI_AI = a.padre OR p.cod_final COLLATE Latin1_General_CI_AI = N'ACT-' + a.padre
                  OR p.nombre COLLATE Latin1_General_CI_AI = a.padre) ORDER BY p.fila) x
WHERE a.padre IS NOT NULL AND a.padre_id IS NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'ACTIVOS', fila, N'NOMBRE', NULL, N'Falta el nombre del activo.' FROM #act WHERE id IS NULL AND nombre IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'PLANTA', NULL, N'Falta la planta del activo.' FROM #act WHERE id IS NULL AND planta IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'PLANTA', planta, N'La planta no existe o está deshabilitada. Escríbala como en la hoja PLANTAS.' FROM #act WHERE planta IS NOT NULL AND planta_id IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'TIPO', NULL, N'Falta el tipo de activo.' FROM #act WHERE id IS NULL AND tipo IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'ESTADO', NULL, N'Falta el estado.' FROM #act WHERE id IS NULL AND estado IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'ESTADO', estado, N'El estado no existe. Use uno de la hoja ESTADOS.' FROM #act WHERE estado IS NOT NULL AND estado_id IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'CRITICIDAD', NULL, N'Falta la criticidad.' FROM #act WHERE id IS NULL AND criticidad IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'CRITICIDAD', criticidad, N'La criticidad es Baja, Media, Alta o Crítica.' FROM #act WHERE criticidad IS NOT NULL AND criticidad_id IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'AREA', area, N'El área no existe en esa planta. Escríbala como en la hoja AREAS.' FROM #act WHERE area IS NOT NULL AND area_id IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'CENTRO COSTO', centro, N'El centro de costo no existe. Escríbalo como en la hoja CENTROS COSTO.' FROM #act WHERE centro IS NOT NULL AND centro_id IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'DEPENDE DE', padre, N'El activo del que depende no existe ni viene en esta hoja.' FROM #act WHERE padre IS NOT NULL AND padre_id IS NULL AND padre_fila IS NULL
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'DEPENDE DE', padre, N'Un activo no puede depender de sí mismo.' FROM #act WHERE padre_id IS NOT NULL AND padre_id = id
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'ANIO FABRICACION', anio_t, N'El año de fabricación es un número entre 1900 y el año actual.' FROM #act WHERE anio_t IS NOT NULL AND (anio IS NULL OR anio < 1900 OR anio > YEAR(@hoy))
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'PUESTA MARCHA', puesta_t, N'La fecha de puesta en marcha no se entiende o es futura (dd-mm-aaaa).' FROM #act WHERE puesta_t IS NOT NULL AND (puesta IS NULL OR puesta > @hoy)
UNION ALL SELECT @CARGA, 'ACTIVOS', fila, N'EN USO', en_uso, N'En uso es SI o NO.' FROM #act WHERE en_uso IS NOT NULL AND en_uso NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL
SELECT @CARGA, 'ACTIVOS', a.fila, N'CODIGO', a.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #act a CROSS APPLY (SELECT TOP 1 fila FROM #act x WHERE x.cod_final = a.cod_final AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NOT NULL
UNION ALL
SELECT @CARGA, 'ACTIVOS', a.fila, N'NOMBRE', a.nombre, N'El activo se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #act a CROSS APPLY (SELECT TOP 1 fila FROM #act x WHERE x.cod_final IS NULL AND x.nombre = a.nombre AND ISNULL(x.planta_id, 0) = ISNULL(a.planta_id, 0) AND x.fila < a.fila ORDER BY x.fila) p
WHERE  a.cod_final IS NULL AND a.nombre IS NOT NULL

UPDATE a SET err = 1 FROM #act a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'ACTIVOS' AND e.cme_fila = a.fila)
/* Un hijo cuyo padre de la planilla tiene error tampoco puede crearse. */
WHILE 1 = 1
BEGIN
    UPDATE a SET err = 1 FROM #act a JOIN #act p ON p.fila = a.padre_fila WHERE a.err = 0 AND p.err = 1
    IF @@ROWCOUNT = 0 BREAK
END
INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'ACTIVOS', a.fila, N'DEPENDE DE', a.padre, N'El activo del que depende (fila ' + LTRIM(STR(a.padre_fila)) + N') tiene errores.'
FROM   #act a WHERE a.err = 1 AND a.padre_fila IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'ACTIVOS' AND e.cme_fila = a.fila)
UPDATE #act SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando activos' WHERE cma_id = @CARGA
    /* Por pasadas: primero los que no dependen de otra fila, despues sus hijos. */
    DECLARE @pasada INT = 0
    WHILE @pasada < 10
    BEGIN
        SET @pasada = @pasada + 1
        UPDATE a SET padre_id = p.id FROM #act a JOIN #act p ON p.fila = a.padre_fila WHERE a.padre_id IS NULL AND p.id IS NOT NULL AND p.res IN ('C','A','O')
        IF NOT EXISTS (SELECT 1 FROM #act WHERE res IN ('C','A') AND cmf IS NULL) BREAK
        SET @f = 0
        WHILE 1 = 1
        BEGIN
            SELECT @f = MIN(fila) FROM #act WHERE fila > @f AND res IN ('C','A') AND cmf IS NULL AND (padre_fila IS NULL OR padre_id IS NOT NULL)
            IF @f IS NULL BREAK
            BEGIN TRY
                DECLARE @aCod NVARCHAR(100), @aNom NVARCHAR(400), @aPla INT, @aAre INT, @aTipoT NVARCHAR(400), @aModT NVARCHAR(400),
                        @aMar NVARCHAR(200), @aSer NVARCHAR(200), @aEst INT, @aCri INT, @aCen INT, @aPad INT, @aAnio INT, @aPue DATE,
                        @aUso NVARCHAR(10), @aDes NVARCHAR(2000), @aTipo INT, @aModelo INT, @aHab BIT
                SELECT @id = id, @aCod = ISNULL(cod_final, N'AUTO'), @aNom = nombre, @aPla = planta_id, @aAre = area_id, @aTipoT = tipo, @aModT = modelo,
                       @aMar = marca, @aSer = serie, @aEst = estado_id, @aCri = criticidad_id, @aCen = centro_id, @aPad = padre_id, @aAnio = anio,
                       @aPue = puesta, @aUso = en_uso, @aDes = descripcion
                FROM   #act WHERE fila = @f

                /* Tipo y modelo se eligen o se escriben: lo que no existe se crea,
                   igual que en la ficha (UPS_ACTIVO_CATALOGO). */
                SELECT @aTipo = NULL, @aModelo = NULL
                IF @id IS NOT NULL
                    SELECT @aTipo = CASE WHEN @aTipoT IS NULL THEN act_activo_tipo END, @aModelo = CASE WHEN @aModT IS NULL THEN act_activo_modelo END
                    FROM [dbo].[Activo] WHERE act_id = @id
                IF @aTipoT IS NOT NULL OR @aModT IS NOT NULL
                BEGIN
                    IF @aTipoT IS NULL SELECT @aTipoT = ati_nombre FROM [dbo].[Activo_Tipo] WHERE ati_id = (SELECT act_activo_tipo FROM [dbo].[Activo] WHERE act_id = @id)
                    EXEC [dbo].[UPS_ACTIVO_CATALOGO] @CLIENTE = @CLIENTE, @TIPO = @aTipo OUTPUT, @TIPO_TEXTO = @aTipoT,
                         @MODELO = @aModelo OUTPUT, @MODELO_TEXTO = @aModT, @FABRICANTE = @aMar, @USUARIO = @USUARIO
                END

                IF @id IS NULL
                BEGIN
                    SET @nuevo = NULL
                    EXEC [dbo].[INS_ACTIVO] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @aPla, @INSTALACION_AREA = @aAre,
                         @ACTIVO_TIPO = @aTipo, @ACTIVO_MODELO = @aModelo, @ACTIVO_ESTADO = @aEst, @ACTIVO_PADRE = @aPad, @CENTRO_COSTO = @aCen,
                         @CRITICIDAD_NIVEL = @aCri, @CODIGO = @aCod, @NOMBRE = @aNom, @NUMERO_SERIE = @aSer, @FABRICANTE = @aMar,
                         @ANIO_FABRICACION = @aAnio, @FECHA_PUESTA_MARCHA = @aPue, @DESCRIPCION = @aDes, @REGISTRO_ORIGEN = 1, @USUARIO = @USUARIO
                    SET @id = @nuevo
                    IF @aUso = N'NO'
                    BEGIN
                        DECLARE @cod0 NVARCHAR(100) = (SELECT act_codigo FROM [dbo].[Activo] WHERE act_id = @id)
                        EXEC [dbo].[UPD_ACTIVO] @ID = @id, @CLIENTE_INSTALACION = @aPla, @INSTALACION_AREA = @aAre, @ACTIVO_TIPO = @aTipo,
                             @ACTIVO_MODELO = @aModelo, @ACTIVO_ESTADO = @aEst, @ACTIVO_PADRE = @aPad, @CENTRO_COSTO = @aCen,
                             @CRITICIDAD_NIVEL = @aCri, @CODIGO = @cod0, @NOMBRE = @aNom, @NUMERO_SERIE = @aSer, @FABRICANTE = @aMar,
                             @ANIO_FABRICACION = @aAnio, @FECHA_PUESTA_MARCHA = @aPue, @DESCRIPCION = @aDes, @HABILITADO = 0, @USUARIO = @USUARIO
                    END
                END
                ELSE
                BEGIN
                    /* Las celdas vacias conservan lo que habia. */
                    SELECT @aPla = ISNULL(@aPla, act_cliente_instalacion), @aAre = ISNULL(@aAre, act_instalacion_area),
                           @aTipo = ISNULL(@aTipo, act_activo_tipo), @aModelo = ISNULL(@aModelo, act_activo_modelo),
                           @aEst = ISNULL(@aEst, act_activo_estado), @aPad = ISNULL(@aPad, act_activo_padre), @aCen = ISNULL(@aCen, act_centro_costo),
                           @aCri = ISNULL(@aCri, act_criticidad_nivel), @aCod = act_codigo, @aNom = ISNULL(@aNom, act_nombre),
                           @aSer = ISNULL(@aSer, act_numero_serie), @aMar = ISNULL(@aMar, act_fabricante), @aAnio = ISNULL(@aAnio, act_anio_fabricacion),
                           @aPue = ISNULL(@aPue, act_fecha_puesta_marcha), @aDes = ISNULL(@aDes, act_descripcion),
                           @aHab = CASE WHEN @aUso = N'NO' THEN 0 WHEN @aUso IN (N'SI', N'SÍ') THEN 1 ELSE act_habilitado END
                    FROM   [dbo].[Activo] WHERE act_id = @id
                    EXEC [dbo].[UPD_ACTIVO] @ID = @id, @CLIENTE_INSTALACION = @aPla, @INSTALACION_AREA = @aAre, @ACTIVO_TIPO = @aTipo,
                         @ACTIVO_MODELO = @aModelo, @ACTIVO_ESTADO = @aEst, @ACTIVO_PADRE = @aPad, @CENTRO_COSTO = @aCen,
                         @CRITICIDAD_NIVEL = @aCri, @CODIGO = @aCod, @NOMBRE = @aNom, @NUMERO_SERIE = @aSer, @FABRICANTE = @aMar,
                         @ANIO_FABRICACION = @aAnio, @FECHA_PUESTA_MARCHA = @aPue, @DESCRIPCION = @aDes, @HABILITADO = @aHab, @USUARIO = @USUARIO
                END
                UPDATE #act SET id = @id, cmf = 1 WHERE fila = @f
                UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #act WHERE fila = @f), cmf_id = @id
                WHERE  cmf_carga = @CARGA AND cmf_hoja = 'ACTIVOS' AND cmf_fila = @f
            END TRY
            BEGIN CATCH
                IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
                INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'ACTIVOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
                UPDATE #act SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
            END CATCH
            SET @n = @n + 1
            IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
        END
        /* Los hijos de un activo que no se pudo crear quedan con error. */
        UPDATE a SET err = 1, res = 'E', cmf = 1 FROM #act a JOIN #act p ON p.fila = a.padre_fila WHERE a.cmf IS NULL AND p.res = 'E'
    END
    INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
    SELECT @CARGA, 'ACTIVOS', fila, N'DEPENDE DE', padre, N'No se pudo crear porque el activo del que depende no se creó.' FROM #act
    WHERE  res = 'E' AND NOT EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'ACTIVOS' AND e.cme_fila = #act.fila)
END
UPDATE f SET cmf_resultado = a.res, cmf_id = ISNULL(f.cmf_id, a.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #act a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'ACTIVOS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando datos técnicos'

/* Referencias a un activo desde las otras hojas: codigo o nombre, de la base
   o de una fila valida de ACTIVOS (que al cargar ya tiene id). */
CREATE TABLE #actref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT, criticidad INT)
INSERT INTO #actref SELECT act_codigo, act_id, NULL, act_criticidad_nivel FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE
INSERT INTO #actref SELECT SUBSTRING(act_codigo, 5, 100), act_id, NULL, act_criticidad_nivel FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo LIKE N'ACT-%'
INSERT INTO #actref SELECT act_nombre, act_id, NULL, act_criticidad_nivel FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE
INSERT INTO #actref SELECT cod_final, id, fila, criticidad_id FROM #act WHERE err = 0 AND cod_final IS NOT NULL
INSERT INTO #actref SELECT codigo, id, fila, criticidad_id FROM #act WHERE err = 0 AND codigo IS NOT NULL
INSERT INTO #actref SELECT nombre, id, fila, criticidad_id FROM #act WHERE err = 0 AND nombre IS NOT NULL

/* ======================================================================
   2. DATOS TECNICOS
   ====================================================================== */
CREATE TABLE #dat (fila INT PRIMARY KEY, activo NVARCHAR(400), dato NVARCHAR(200), valor NVARCHAR(400), unidad NVARCHAR(100),
                   activo_id INT, activo_fila INT, unidad_id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #dat (fila, activo, dato, valor, unidad)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.dato)), N''), NULLIF(LTRIM(RTRIM(j.valor)), N''), NULLIF(LTRIM(RTRIM(j.unidad)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (activo NVARCHAR(400) '$.ACTIVO', dato NVARCHAR(200) '$.DATO', valor NVARCHAR(400) '$.VALOR', unidad NVARCHAR(100) '$.UNIDAD') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'DATOS_TECNICOS'

UPDATE d SET activo_id = x.id, activo_fila = x.fila FROM #dat d
CROSS APPLY (SELECT TOP 1 id, fila FROM #actref WHERE clave = d.activo COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE d.activo IS NOT NULL
UPDATE d SET unidad_id = (SELECT TOP 1 id FROM #uni WHERE clave = d.unidad COLLATE Latin1_General_CI_AI) FROM #dat d WHERE d.unidad IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'DATOS_TECNICOS', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe ni viene en la hoja ACTIVOS.' END FROM #dat WHERE activo_id IS NULL AND activo_fila IS NULL
UNION ALL SELECT @CARGA, 'DATOS_TECNICOS', fila, N'DATO', NULL, N'Falta el nombre del dato (Potencia, Voltaje…).' FROM #dat WHERE dato IS NULL
UNION ALL SELECT @CARGA, 'DATOS_TECNICOS', fila, N'VALOR', NULL, N'Falta el valor.' FROM #dat WHERE valor IS NULL
UNION ALL SELECT @CARGA, 'DATOS_TECNICOS', fila, N'UNIDAD', unidad, N'La unidad no existe. Use una de la hoja UNIDADES.' FROM #dat WHERE unidad IS NOT NULL AND unidad_id IS NULL
UPDATE d SET err = 1 FROM #dat d WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'DATOS_TECNICOS' AND e.cme_fila = d.fila)
/* El dato se graba sobre el que hubiera: siempre es "actualizar" si ya tenia valor. */
UPDATE d SET res = CASE WHEN err = 1 THEN 'E'
                        WHEN activo_id IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Activo_Atributo] aa JOIN [dbo].[Atributo_Tecnico] at ON at.ate_id = aa.aat_atributo_tecnico
                                                                 WHERE aa.aat_activo = d.activo_id AND at.ate_nombre COLLATE Latin1_General_CI_AI = d.dato)
                             THEN CASE WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END
                        ELSE 'C' END
FROM #dat d

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Grabando datos técnicos' WHERE cma_id = @CARGA
    UPDATE d SET activo_id = a.id FROM #dat d JOIN #act a ON a.fila = d.activo_fila WHERE d.activo_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #dat WHERE fila > @f AND res IN ('C','A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @dAct INT, @dNom NVARCHAR(200), @dVal NVARCHAR(400), @dUni INT
            SELECT @dAct = activo_id, @dNom = dato, @dVal = valor, @dUni = ISNULL(unidad_id, 0) FROM #dat WHERE fila = @f
            IF @dAct IS NULL RAISERROR(N'El activo no se pudo crear.', 16, 1)
            EXEC [dbo].[GRABAR_DATO_ACTIVO] @ACTIVO = @dAct, @ATRIBUTO = NULL, @NOMBRE = @dNom, @UNIDAD = @dUni, @VALOR = @dVal, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #dat WHERE fila = @f), cmf_id = @dAct
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'DATOS_TECNICOS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'DATOS_TECNICOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #dat SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = d.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #dat d ON d.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'DATOS_TECNICOS' AND (f.cmf_resultado IS NULL OR d.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando componentes'

/* ======================================================================
   3. COMPONENTES
   ====================================================================== */
CREATE TABLE #com (fila INT PRIMARY KEY, activo NVARCHAR(400), nombre NVARCHAR(400), que_es NVARCHAR(200), donde_va NVARCHAR(200),
                   criticidad NVARCHAR(200), fecha_t NVARCHAR(40), descripcion NVARCHAR(2000),
                   activo_id INT, activo_fila INT, criticidad_id INT, fecha DATE, id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #com (fila, activo, nombre, que_es, donde_va, criticidad, fecha_t, descripcion)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.que_es)), N''),
       NULLIF(LTRIM(RTRIM(j.donde_va)), N''), NULLIF(LTRIM(RTRIM(j.criticidad)), N''), NULLIF(LTRIM(RTRIM(j.fecha)), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (activo NVARCHAR(400) '$.ACTIVO', nombre NVARCHAR(400) '$.NOMBRE', que_es NVARCHAR(200) '$.QUE_ES',
        donde_va NVARCHAR(200) '$.DONDE_VA', criticidad NVARCHAR(200) '$.CRITICIDAD', fecha NVARCHAR(40) '$.FECHA_INSTALACION',
        descripcion NVARCHAR(2000) '$.DESCRIPCION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'COMPONENTES'

UPDATE c SET activo_id = x.id, activo_fila = x.fila, criticidad_id = x.criticidad FROM #com c
CROSS APPLY (SELECT TOP 1 id, fila, criticidad FROM #actref WHERE clave = c.activo COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE c.activo IS NOT NULL
UPDATE c SET criticidad_id = x.crn_id FROM #com c
CROSS APPLY (SELECT TOP 1 crn_id FROM [dbo].[Criticidad_Nivel] WHERE crn_habilitado = 1
             AND (crn_nombre COLLATE Latin1_General_CI_AI = c.criticidad OR crn_codigo COLLATE Latin1_General_CI_AI = c.criticidad)) x
WHERE c.criticidad IS NOT NULL
UPDATE #com SET fecha = TRY_CONVERT(DATE, fecha_t)
UPDATE c SET id = x.aco_id FROM #com c
CROSS APPLY (SELECT TOP 1 aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = c.activo_id AND aco_nombre COLLATE Latin1_General_CI_AI = c.nombre ORDER BY aco_id) x
WHERE c.activo_id IS NOT NULL AND c.nombre IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'COMPONENTES', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe ni viene en la hoja ACTIVOS.' END FROM #com WHERE activo_id IS NULL AND activo_fila IS NULL
UNION ALL SELECT @CARGA, 'COMPONENTES', fila, N'NOMBRE', NULL, N'Falta el nombre del componente.' FROM #com WHERE nombre IS NULL
UNION ALL SELECT @CARGA, 'COMPONENTES', fila, N'CRITICIDAD', criticidad, N'La criticidad es Baja, Media, Alta o Crítica.' FROM #com WHERE criticidad IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE crn_nombre COLLATE Latin1_General_CI_AI = #com.criticidad OR crn_codigo COLLATE Latin1_General_CI_AI = #com.criticidad)
UNION ALL SELECT @CARGA, 'COMPONENTES', fila, N'FECHA INSTALACION', fecha_t, N'La fecha no se entiende o es futura (dd-mm-aaaa).' FROM #com WHERE fecha_t IS NOT NULL AND (fecha IS NULL OR fecha > @hoy)
UNION ALL
SELECT @CARGA, 'COMPONENTES', c.fila, N'NOMBRE', c.nombre, N'El componente se repite en el mismo activo (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #com c CROSS APPLY (SELECT TOP 1 fila FROM #com x WHERE x.activo = c.activo AND x.nombre = c.nombre AND x.fila < c.fila ORDER BY x.fila) p
UPDATE c SET err = 1 FROM #com c WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'COMPONENTES' AND e.cme_fila = c.fila)
UPDATE #com SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NOT NULL THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando componentes' WHERE cma_id = @CARGA
    UPDATE c SET activo_id = a.id, criticidad_id = ISNULL(c.criticidad_id, a.criticidad_id) FROM #com c JOIN #act a ON a.fila = c.activo_fila WHERE c.activo_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #com WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @cAct INT, @cNom NVARCHAR(400), @cQue NVARCHAR(200), @cDon NVARCHAR(200), @cCri INT, @cFec DATE, @cDes NVARCHAR(2000), @cTipo INT, @cPos INT
            SELECT @cAct = activo_id, @cNom = nombre, @cQue = ISNULL(que_es, N'Otro'), @cDon = donde_va, @cCri = criticidad_id,
                   @cFec = ISNULL(fecha, @hoy), @cDes = descripcion
            FROM   #com WHERE fila = @f
            IF @cAct IS NULL RAISERROR(N'El activo no se pudo crear.', 16, 1)
            IF @cCri IS NULL SELECT @cCri = act_criticidad_nivel FROM [dbo].[Activo] WHERE act_id = @cAct
            SELECT @cTipo = NULL, @cPos = NULL
            EXEC [dbo].[UPS_COMPONENTE_TIPO_NOMBRE] @ID = @cTipo OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @cQue, @USUARIO = @USUARIO
            IF @cDon IS NOT NULL
                EXEC [dbo].[UPS_COMPONENTE_POSICION_NOMBRE] @ID = @cPos OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @cDon, @USUARIO = @USUARIO
            SET @nuevo = NULL
            EXEC [dbo].[INS_ACTIVO_COMPONENTE] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @cAct, @COMPONENTE_PADRE = NULL,
                 @COMPONENTE_TIPO = @cTipo, @COMPONENTE_POSICION = @cPos, @CRITICIDAD_NIVEL = @cCri, @ACTIVO_COMPONENTE_ESTADO = 1,
                 @CODIGO = N'AUTO', @NOMBRE = @cNom, @FECHA_INSTALACION = @cFec, @DESCRIPCION = @cDes, @USUARIO = @USUARIO
            UPDATE #com SET id = @nuevo WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'COMPONENTES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'COMPONENTES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #com SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = c.res, cmf_id = ISNULL(f.cmf_id, c.id) FROM [dbo].[Carga_Masiva_Fila] f JOIN #com c ON c.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'COMPONENTES' AND (f.cmf_resultado IS NULL OR c.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando variables'

/* Componente de un activo: de la base o de la hoja COMPONENTES. */
CREATE TABLE #comref (activo_ref NVARCHAR(400) COLLATE Latin1_General_CI_AI, activo_id INT, clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #comref SELECT NULL, aco_activo, aco_nombre, aco_id, NULL FROM [dbo].[Activo_Componente] WHERE aco_cliente = @CLIENTE
INSERT INTO #comref SELECT NULL, aco_activo, aco_codigo, aco_id, NULL FROM [dbo].[Activo_Componente] WHERE aco_cliente = @CLIENTE
INSERT INTO #comref SELECT activo, activo_id, nombre, id, fila FROM #com WHERE err = 0

/* ======================================================================
   4. VARIABLES
   ====================================================================== */
CREATE TABLE #var (fila INT PRIMARY KEY, activo NVARCHAR(400), componente NVARCHAR(400), variable NVARCHAR(200), unidad NVARCHAR(100),
                   min_t NVARCHAR(40), max_t NVARCHAR(40), adv_t NVARCHAR(40), cri_t NVARCHAR(40), frec_t NVARCHAR(40),
                   activo_id INT, activo_fila INT, comp_id INT, comp_fila INT, unidad_id INT, vmin DECIMAL(18,4), vmax DECIMAL(18,4),
                   vadv DECIMAL(18,4), vcri DECIMAL(18,4), frec INT, existe BIT NOT NULL DEFAULT 0, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #var (fila, activo, componente, variable, unidad, min_t, max_t, adv_t, cri_t, frec_t)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.componente)), N''), NULLIF(LTRIM(RTRIM(j.variable)), N''),
       NULLIF(LTRIM(RTRIM(j.unidad)), N''), NULLIF(LTRIM(RTRIM(j.vmin)), N''), NULLIF(LTRIM(RTRIM(j.vmax)), N''),
       NULLIF(LTRIM(RTRIM(j.vadv)), N''), NULLIF(LTRIM(RTRIM(j.vcri)), N''), NULLIF(LTRIM(RTRIM(j.frec)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (activo NVARCHAR(400) '$.ACTIVO', componente NVARCHAR(400) '$.COMPONENTE', variable NVARCHAR(200) '$.VARIABLE',
        unidad NVARCHAR(100) '$.UNIDAD', vmin NVARCHAR(40) '$.MINIMO', vmax NVARCHAR(40) '$.MAXIMO', vadv NVARCHAR(40) '$.ADVERTENCIA',
        vcri NVARCHAR(40) '$.CRITICO', frec NVARCHAR(40) '$.FRECUENCIA_HORAS') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'VARIABLES'

UPDATE v SET activo_id = x.id, activo_fila = x.fila FROM #var v
CROSS APPLY (SELECT TOP 1 id, fila FROM #actref WHERE clave = v.activo COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE v.activo IS NOT NULL
UPDATE v SET comp_id = x.id, comp_fila = x.fila FROM #var v
CROSS APPLY (SELECT TOP 1 id, fila FROM #comref r WHERE r.clave = v.componente COLLATE Latin1_General_CI_AI
             AND ((v.activo_id IS NOT NULL AND r.activo_id = v.activo_id) OR r.activo_ref = v.activo COLLATE Latin1_General_CI_AI)) x
WHERE v.componente IS NOT NULL
UPDATE v SET unidad_id = (SELECT TOP 1 id FROM #uni WHERE clave = v.unidad COLLATE Latin1_General_CI_AI) FROM #var v WHERE v.unidad IS NOT NULL
UPDATE #var SET vmin = TRY_CONVERT(DECIMAL(18,4), min_t), vmax = TRY_CONVERT(DECIMAL(18,4), max_t), vadv = TRY_CONVERT(DECIMAL(18,4), adv_t),
                vcri = TRY_CONVERT(DECIMAL(18,4), cri_t), frec = TRY_CONVERT(INT, frec_t)
UPDATE v SET existe = 1 FROM #var v
WHERE  v.activo_id IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] av JOIN [dbo].[Variable_Medicion] vm ON vm.vme_id = av.ava_variable_medicion
                                           WHERE av.ava_activo = v.activo_id AND vm.vme_nombre COLLATE Latin1_General_CI_AI = v.variable
                                             AND ISNULL(av.ava_activo_componente, 0) = ISNULL(v.comp_id, 0))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'VARIABLES', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe ni viene en la hoja ACTIVOS.' END FROM #var WHERE activo_id IS NULL AND activo_fila IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'COMPONENTE', componente, N'Ese componente no existe en el activo ni viene en la hoja COMPONENTES.' FROM #var WHERE componente IS NOT NULL AND comp_id IS NULL AND comp_fila IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'VARIABLE', NULL, N'Falta qué se mide (Temperatura, Presión…).' FROM #var WHERE variable IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'UNIDAD', unidad, CASE WHEN unidad IS NULL THEN N'Falta la unidad.' ELSE N'La unidad no existe. Use una de la hoja UNIDADES.' END FROM #var WHERE unidad_id IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'MINIMO', min_t, N'El mínimo es un número.' FROM #var WHERE min_t IS NOT NULL AND vmin IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'MAXIMO', max_t, N'El máximo es un número.' FROM #var WHERE max_t IS NOT NULL AND vmax IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'MAXIMO', max_t, N'El máximo tiene que ser mayor que el mínimo.' FROM #var WHERE vmin IS NOT NULL AND vmax IS NOT NULL AND vmax <= vmin
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'ADVERTENCIA', adv_t, N'La advertencia es un número.' FROM #var WHERE adv_t IS NOT NULL AND vadv IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'CRITICO', cri_t, N'El valor crítico es un número.' FROM #var WHERE cri_t IS NOT NULL AND vcri IS NULL
UNION ALL SELECT @CARGA, 'VARIABLES', fila, N'FRECUENCIA HORAS', frec_t, N'La frecuencia es un entero de horas mayor que cero.' FROM #var WHERE frec_t IS NOT NULL AND ISNULL(frec, 0) <= 0
UPDATE v SET err = 1 FROM #var v WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'VARIABLES' AND e.cme_fila = v.fila)
UPDATE #var SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando variables' WHERE cma_id = @CARGA
    UPDATE v SET activo_id = a.id FROM #var v JOIN #act a ON a.fila = v.activo_fila WHERE v.activo_id IS NULL
    UPDATE v SET comp_id = c.id FROM #var v JOIN #com c ON c.fila = v.comp_fila WHERE v.comp_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #var WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @vAct INT, @vCom INT, @vNom NVARCHAR(200), @vUni INT, @vMin DECIMAL(18,4), @vMax DECIMAL(18,4), @vAdv DECIMAL(18,4), @vCri DECIMAL(18,4), @vFre INT, @vVar INT
            SELECT @vAct = activo_id, @vCom = comp_id, @vNom = variable, @vUni = unidad_id, @vMin = vmin, @vMax = vmax, @vAdv = vadv, @vCri = vcri, @vFre = frec
            FROM   #var WHERE fila = @f
            IF @vAct IS NULL RAISERROR(N'El activo no se pudo crear.', 16, 1)
            SET @vVar = NULL
            EXEC [dbo].[UPS_VARIABLE_MEDICION_NOMBRE] @ID = @vVar OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @vNom, @UNIDAD = @vUni, @USUARIO = @USUARIO
            SET @nuevo = NULL
            EXEC [dbo].[INS_ACTIVO_VARIABLE] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @vAct, @ACTIVO_COMPONENTE = @vCom,
                 @VARIABLE_MEDICION = @vVar, @UNIDAD_MEDIDA = @vUni, @VALOR_MINIMO = @vMin, @VALOR_MAXIMO = @vMax,
                 @VALOR_ADVERTENCIA = @vAdv, @VALOR_CRITICO = @vCri, @FRECUENCIA_ESPERADA_HORA = @vFre, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'VARIABLES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'VARIABLES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #var SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = v.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #var v ON v.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'VARIABLES' AND (f.cmf_resultado IS NULL OR v.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando medidores'

/* ======================================================================
   5. MEDIDORES
   ====================================================================== */
CREATE TABLE #med (fila INT PRIMARY KEY, activo NVARCHAR(400), nombre NVARCHAR(400), unidad NVARCHAR(100), lectura_t NVARCHAR(40),
                   reinicio NVARCHAR(10), valor_reinicio_t NVARCHAR(40),
                   activo_id INT, activo_fila INT, unidad_id INT, lectura DECIMAL(18,4), valor_reinicio DECIMAL(18,4),
                   existe BIT NOT NULL DEFAULT 0, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #med (fila, activo, nombre, unidad, lectura_t, reinicio, valor_reinicio_t)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.unidad)), N''),
       NULLIF(LTRIM(RTRIM(j.lectura)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.reinicio))), N''), NULLIF(LTRIM(RTRIM(j.vreinicio)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (activo NVARCHAR(400) '$.ACTIVO', nombre NVARCHAR(400) '$.NOMBRE', unidad NVARCHAR(100) '$.UNIDAD',
        lectura NVARCHAR(40) '$.LECTURA_ACTUAL', reinicio NVARCHAR(10) '$.PERMITE_REINICIO', vreinicio NVARCHAR(40) '$.VALOR_REINICIO') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'MEDIDORES'

UPDATE m SET activo_id = x.id, activo_fila = x.fila FROM #med m
CROSS APPLY (SELECT TOP 1 id, fila FROM #actref WHERE clave = m.activo COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE m.activo IS NOT NULL
UPDATE m SET unidad_id = (SELECT TOP 1 id FROM #uni WHERE clave = m.unidad COLLATE Latin1_General_CI_AI) FROM #med m WHERE m.unidad IS NOT NULL
UPDATE #med SET lectura = TRY_CONVERT(DECIMAL(18,4), lectura_t), valor_reinicio = TRY_CONVERT(DECIMAL(18,4), valor_reinicio_t)
UPDATE m SET existe = 1 FROM #med m
WHERE  m.activo_id IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor] x WHERE x.ame_activo = m.activo_id AND x.ame_nombre COLLATE Latin1_General_CI_AI = m.nombre)

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'MEDIDORES', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe ni viene en la hoja ACTIVOS.' END FROM #med WHERE activo_id IS NULL AND activo_fila IS NULL
UNION ALL SELECT @CARGA, 'MEDIDORES', fila, N'NOMBRE', NULL, N'Falta el nombre del medidor (Horómetro, Odómetro…).' FROM #med WHERE nombre IS NULL
UNION ALL SELECT @CARGA, 'MEDIDORES', fila, N'UNIDAD', unidad, CASE WHEN unidad IS NULL THEN N'Falta la unidad (horas, ciclos, km).' ELSE N'La unidad no existe. Use una de la hoja UNIDADES.' END FROM #med WHERE unidad_id IS NULL
UNION ALL SELECT @CARGA, 'MEDIDORES', fila, N'LECTURA ACTUAL', lectura_t, N'La lectura es un número mayor o igual a cero.' FROM #med WHERE lectura_t IS NOT NULL AND (lectura IS NULL OR lectura < 0)
UNION ALL SELECT @CARGA, 'MEDIDORES', fila, N'PERMITE REINICIO', reinicio, N'Permite reinicio es SI o NO.' FROM #med WHERE reinicio IS NOT NULL AND reinicio NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'MEDIDORES', fila, N'VALOR REINICIO', valor_reinicio_t, N'El valor de reinicio es un número.' FROM #med WHERE valor_reinicio_t IS NOT NULL AND valor_reinicio IS NULL
UNION ALL
SELECT @CARGA, 'MEDIDORES', m.fila, N'NOMBRE', m.nombre, N'El medidor se repite en el mismo activo (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #med m CROSS APPLY (SELECT TOP 1 fila FROM #med x WHERE x.activo = m.activo AND x.nombre = m.nombre AND x.fila < m.fila ORDER BY x.fila) p
UPDATE m SET err = 1 FROM #med m WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'MEDIDORES' AND e.cme_fila = m.fila)
UPDATE #med SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando medidores' WHERE cma_id = @CARGA
    UPDATE m SET activo_id = a.id FROM #med m JOIN #act a ON a.fila = m.activo_fila WHERE m.activo_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #med WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @mAct INT, @mNom NVARCHAR(400), @mUni INT, @mLec DECIMAL(18,4), @mRei BIT, @mVre DECIMAL(18,4)
            SELECT @mAct = activo_id, @mNom = nombre, @mUni = unidad_id, @mLec = ISNULL(lectura, 0),
                   @mRei = CASE WHEN reinicio IN (N'SI', N'SÍ') THEN 1 ELSE 0 END, @mVre = valor_reinicio
            FROM   #med WHERE fila = @f
            IF @mAct IS NULL RAISERROR(N'El activo no se pudo crear.', 16, 1)
            SET @nuevo = NULL
            EXEC [dbo].[INS_ACTIVO_MEDIDOR] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @mAct, @UNIDAD_MEDIDA = @mUni,
                 @CODIGO = N'AUTO', @NOMBRE = @mNom, @VALOR_ACTUAL = @mLec, @VALOR_REINICIO = @mVre, @PERMITE_REINICIO = @mRei, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'MEDIDORES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'MEDIDORES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #med SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = m.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #med m ON m.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'MEDIDORES' AND (f.cmf_resultado IS NULL OR m.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando repuestos compatibles'

/* ======================================================================
   6. REPUESTOS COMPATIBLES
   ====================================================================== */
CREATE TABLE #rco (fila INT PRIMARY KEY, activo NVARCHAR(400), componente NVARCHAR(400), repuesto NVARCHAR(200), observacion NVARCHAR(500),
                   activo_id INT, activo_fila INT, comp_id INT, comp_fila INT, repuesto_id INT,
                   existe BIT NOT NULL DEFAULT 0, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #rco (fila, activo, componente, repuesto, observacion)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.componente)), N''), NULLIF(LTRIM(RTRIM(j.repuesto)), N''), NULLIF(LTRIM(RTRIM(j.obs)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (activo NVARCHAR(400) '$.ACTIVO', componente NVARCHAR(400) '$.COMPONENTE', repuesto NVARCHAR(200) '$.REPUESTO', obs NVARCHAR(500) '$.OBSERVACION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'REPUESTOS_COMPATIBLES'

UPDATE r SET activo_id = x.id, activo_fila = x.fila FROM #rco r
CROSS APPLY (SELECT TOP 1 id, fila FROM #actref WHERE clave = r.activo COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE r.activo IS NOT NULL
UPDATE r SET comp_id = x.id, comp_fila = x.fila FROM #rco r
CROSS APPLY (SELECT TOP 1 id, fila FROM #comref c WHERE c.clave = r.componente COLLATE Latin1_General_CI_AI
             AND ((r.activo_id IS NOT NULL AND c.activo_id = r.activo_id) OR c.activo_ref = r.activo COLLATE Latin1_General_CI_AI)) x
WHERE r.componente IS NOT NULL
UPDATE r SET repuesto_id = x.rep_id FROM #rco r
CROSS APPLY (SELECT TOP 1 rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND ISNULL(rep_habilitado, 1) = 1
             AND (rep_codigo COLLATE Latin1_General_CI_AI = r.repuesto OR rep_nombre COLLATE Latin1_General_CI_AI = r.repuesto)
             ORDER BY CASE WHEN rep_codigo COLLATE Latin1_General_CI_AI = r.repuesto THEN 0 ELSE 1 END, rep_id) x
WHERE r.repuesto IS NOT NULL
UPDATE r SET existe = 1 FROM #rco r
WHERE  r.activo_id IS NOT NULL AND r.repuesto_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] x WHERE x.rco_repuesto = r.repuesto_id
                AND ((r.comp_id IS NOT NULL AND x.rco_activo_componente = r.comp_id)
                  OR (r.comp_id IS NULL AND x.rco_activo = r.activo_id AND x.rco_activo_componente IS NULL)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'REPUESTOS_COMPATIBLES', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe ni viene en la hoja ACTIVOS.' END FROM #rco WHERE activo_id IS NULL AND activo_fila IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS_COMPATIBLES', fila, N'COMPONENTE', componente, N'Ese componente no existe en el activo ni viene en la hoja COMPONENTES.' FROM #rco WHERE componente IS NOT NULL AND comp_id IS NULL AND comp_fila IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS_COMPATIBLES', fila, N'REPUESTO', repuesto, CASE WHEN repuesto IS NULL THEN N'Falta el repuesto.' ELSE N'El repuesto no existe. Créelo antes en la carga de Inventario o use su código.' END FROM #rco WHERE repuesto_id IS NULL
UNION ALL
SELECT @CARGA, 'REPUESTOS_COMPATIBLES', r.fila, N'REPUESTO', r.repuesto, N'El repuesto se repite para el mismo activo (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #rco r CROSS APPLY (SELECT TOP 1 fila FROM #rco x WHERE x.activo = r.activo AND ISNULL(x.componente, N'') = ISNULL(r.componente, N'') AND x.repuesto = r.repuesto AND x.fila < r.fila ORDER BY x.fila) p
UPDATE r SET err = 1 FROM #rco r WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'REPUESTOS_COMPATIBLES' AND e.cme_fila = r.fila)
UPDATE #rco SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Vinculando repuestos' WHERE cma_id = @CARGA
    UPDATE r SET activo_id = a.id FROM #rco r JOIN #act a ON a.fila = r.activo_fila WHERE r.activo_id IS NULL
    UPDATE r SET comp_id = c.id FROM #rco r JOIN #com c ON c.fila = r.comp_fila WHERE r.comp_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #rco WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @rAct INT, @rCom INT, @rRep INT, @rObs NVARCHAR(500)
            SELECT @rAct = activo_id, @rCom = comp_id, @rRep = repuesto_id, @rObs = observacion FROM #rco WHERE fila = @f
            IF @rAct IS NULL RAISERROR(N'El activo no se pudo crear.', 16, 1)
            /* El vinculo es con el activo O con uno de sus componentes, no con los dos. */
            IF @rCom IS NOT NULL SET @rAct = NULL
            SET @nuevo = NULL
            EXEC [dbo].[INS_ACTIVO_REPUESTO_COMPATIBLE] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @rRep, @ACTIVO = @rAct,
                 @COMPONENTE = @rCom, @OBSERVACION = @rObs, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'REPUESTOS_COMPATIBLES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'REPUESTOS_COMPATIBLES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #rco SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = r.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #rco r ON r.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'REPUESTOS_COMPATIBLES' AND (f.cmf_resultado IS NULL OR r.res = 'E')

-- hojas que el modulo no conoce: sus filas no se tocan, pero tampoco quedan "pendientes"
UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'O' WHERE cmf_carga = @CARGA AND cmf_resultado IS NULL

EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Listo'
UPDATE [dbo].[Carga_Masiva]
SET    cma_estado = CASE WHEN cma_errores > 0 THEN 'CON_ERRORES' ELSE 'TERMINADA' END,
       cma_fin = [dbo].[FNC_AHORA](),
       cma_mensaje = CASE WHEN @CARGAR = 1
                          THEN LTRIM(STR(cma_creadas)) + N' creadas, ' + LTRIM(STR(cma_actualizadas)) + N' actualizadas, ' + LTRIM(STR(cma_omitidas)) + N' omitidas y ' + LTRIM(STR(cma_errores)) + N' con error.'
                          ELSE N'Revisión: ' + LTRIM(STR(cma_creadas)) + N' se crearían, ' + LTRIM(STR(cma_actualizadas)) + N' se actualizarían, ' + LTRIM(STR(cma_omitidas)) + N' se omitirían y ' + LTRIM(STR(cma_errores)) + N' tienen errores.' END
WHERE  cma_id = @CARGA
GO

/* Las hojas de ayuda de la plantilla de ACTIVOS (se agregan a las de Inventario). */
/* Las hojas de ayuda de la plantilla: lo que hay que escribir, tal cual. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_AYUDA]
    @CLIENTE INT,
    @LISTA   VARCHAR(30)
AS
SET NOCOUNT ON
IF @LISTA = 'PLANTAS'
    SELECT cin_nombre AS [ESCRIBA ESTO EN PLANTA], ISNULL(cin_codigo, N'') AS [O SU CODIGO]
    FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1 ORDER BY cin_nombre
ELSE IF @LISTA = 'BODEGAS'
    SELECT b.bod_codigo AS [CODIGO], b.bod_nombre AS [NOMBRE], ci.cin_nombre AS [PLANTA], ISNULL(b.bod_metodo_salida, 'FEFO') AS [METODO SALIDA],
           (SELECT COUNT(*) FROM [dbo].[Bodega_Ubicacion] u WHERE u.bub_bodega = b.bod_id AND u.bub_habilitado = 1) AS [RACKS]
    FROM [dbo].[Bodega] b JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE b.bod_cliente = @CLIENTE AND b.bod_habilitado = 1 ORDER BY b.bod_nombre
ELSE IF @LISTA = 'RACKS'
    SELECT b.bod_codigo AS [BODEGA], u.bub_codigo AS [CODIGO], u.bub_nombre AS [NOMBRE]
    FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    WHERE b.bod_cliente = @CLIENTE AND u.bub_habilitado = 1 AND b.bod_habilitado = 1 ORDER BY b.bod_codigo, u.bub_codigo
ELSE IF @LISTA = 'UNIDADES'
    SELECT ume_codigo AS [ESCRIBA ESTO EN UNIDAD], ume_nombre AS [SIGNIFICA], ISNULL(ume_simbolo, N'') AS [SIMBOLO]
    FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1 ORDER BY ume_nombre
ELSE IF @LISTA = 'TIPOS'
    SELECT rti_codigo AS [ESCRIBA ESTO EN TIPO], rti_nombre AS [SIGNIFICA], ISNULL(rti_descripcion, N'') AS [DESCRIPCION]
    FROM [dbo].[Repuesto_Tipo] WHERE rti_cliente = @CLIENTE AND rti_habilitado = 1 ORDER BY rti_orden, rti_nombre
ELSE IF @LISTA = 'FABRICANTES'
    SELECT fab_nombre AS [FABRICANTE] FROM [dbo].[Fabricante] WHERE fab_cliente = @CLIENTE ORDER BY fab_nombre
/* Bloque 367: las ayudas de la carga de ACTIVOS. */
ELSE IF @LISTA = 'AREAS'
    SELECT a.iar_nombre AS [ESCRIBA ESTO EN AREA], ISNULL(a.iar_codigo, N'') AS [O SU CODIGO], ci.cin_nombre AS [PLANTA]
    FROM [dbo].[Instalacion_Area] a JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.iar_cliente_instalacion
    WHERE a.iar_cliente = @CLIENTE AND ISNULL(a.iar_habilitado, 1) = 1 ORDER BY ci.cin_nombre, a.iar_nombre
ELSE IF @LISTA = 'TIPOS ACTIVO'
    SELECT ati_nombre AS [ESCRIBA ESTO EN TIPO (o uno nuevo)], ISNULL(ati_descripcion, N'') AS [DESCRIPCION]
    FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ISNULL(ati_habilitado, 1) = 1 ORDER BY ati_nombre
ELSE IF @LISTA = 'ESTADOS'
    SELECT aes_nombre AS [ESCRIBA ESTO EN ESTADO] FROM [dbo].[Activo_Estado] WHERE aes_habilitado = 1 ORDER BY aes_orden
ELSE IF @LISTA = 'CRITICIDADES'
    SELECT crn_nombre AS [ESCRIBA ESTO EN CRITICIDAD] FROM [dbo].[Criticidad_Nivel] WHERE crn_habilitado = 1 ORDER BY crn_orden
ELSE IF @LISTA = 'CENTROS COSTO'
    SELECT cco_nombre AS [ESCRIBA ESTO EN CENTRO COSTO], ISNULL(cco_codigo, N'') AS [O SU CODIGO]
    FROM [dbo].[Centro_Costo] WHERE cco_cliente = @CLIENTE AND ISNULL(cco_habilitado, 1) = 1 ORDER BY cco_nombre
ELSE IF @LISTA = 'ACTIVOS'
    SELECT a.act_codigo AS [CODIGO], a.act_nombre AS [NOMBRE], ci.cin_nombre AS [PLANTA], ISNULL(t.ati_nombre, N'') AS [TIPO]
    FROM [dbo].[Activo] a JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.act_cliente_instalacion LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
    WHERE a.act_cliente = @CLIENTE ORDER BY a.act_codigo
ELSE IF @LISTA = 'REPUESTOS'
    SELECT rep_codigo AS [CODIGO], rep_nombre AS [NOMBRE] FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND ISNULL(rep_habilitado, 1) = 1 ORDER BY rep_codigo
ELSE IF @LISTA = 'TIPOS COMPONENTE'
    SELECT cto_nombre AS [ESCRIBA ESTO EN QUE ES (o uno nuevo)] FROM [dbo].[Componente_Tipo]
    WHERE (cto_cliente IS NULL OR cto_cliente = @CLIENTE) AND ISNULL(cto_habilitado, 1) = 1 ORDER BY cto_orden, cto_nombre
ELSE IF @LISTA = 'POSICIONES'
    SELECT cpn_nombre AS [ESCRIBA ESTO EN DONDE VA (o uno nuevo)] FROM [dbo].[Componente_Posicion]
    WHERE (cpn_cliente IS NULL OR cpn_cliente = @CLIENTE) AND ISNULL(cpn_habilitado, 1) = 1 ORDER BY cpn_orden, cpn_nombre
GO
