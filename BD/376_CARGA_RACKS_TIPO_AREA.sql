USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 376: la carga masiva de RACKS lee TIPO_AREA (Pasillo, Sala, Zona...) y lo guarda en el rack (BD 375). Sin la columna, Pasillo.
CREATE OR ALTER PROCEDURE [dbo].[PRC_CARGA_INVENTARIO]
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

UPDATE [dbo].[Carga_Masiva] SET cma_estado = 'PROCESANDO', cma_fase = N'Revisando bodegas' WHERE cma_id = @CARGA
DELETE FROM [dbo].[Carga_Masiva_Error] WHERE cme_carga = @CARGA
UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = NULL, cmf_id = NULL WHERE cmf_carga = @CARGA

DECLARE @f INT, @n INT = 0, @id INT, @nuevo INT, @msg NVARCHAR(800), @hoy DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @obs NVARCHAR(500) = N'Carga de datos N° ' + LTRIM(STR(@CARGA))
DECLARE @CI NVARCHAR(10) = N''   -- (solo para leer: las comparaciones van con COLLATE Latin1_General_CI_AI)

/* ======================================================================
   1. BODEGAS
   ====================================================================== */
CREATE TABLE #bod (
    fila INT PRIMARY KEY, codigo NVARCHAR(100), nombre NVARCHAR(400), planta NVARCHAR(400),
    descripcion NVARCHAR(1000), metodo NVARCHAR(20),
    planta_id INT, id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #bod (fila, codigo, nombre, planta, descripcion, metodo)
SELECT f.cmf_fila, NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.planta)), N''),
       NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.metodo))), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', planta NVARCHAR(400) '$.PLANTA',
                                        descripcion NVARCHAR(1000) '$.DESCRIPCION', metodo NVARCHAR(20) '$.METODO_SALIDA') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'BODEGAS'

UPDATE b SET planta_id = x.cin_id
FROM   #bod b
CROSS APPLY (SELECT TOP 1 cin_id FROM [dbo].[Cliente_Instalacion]
             WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1
               AND (cin_nombre COLLATE Latin1_General_CI_AI = b.planta OR cin_codigo COLLATE Latin1_General_CI_AI = b.planta)
             ORDER BY cin_id) x
WHERE  b.planta IS NOT NULL

UPDATE b SET id = x.bod_id
FROM   #bod b
CROSS APPLY (SELECT TOP 1 bod_id FROM [dbo].[Bodega]
             WHERE bod_cliente = @CLIENTE
               AND ((b.codigo IS NOT NULL AND bod_codigo COLLATE Latin1_General_CI_AI = b.codigo)
                 OR (b.codigo IS NULL AND bod_nombre COLLATE Latin1_General_CI_AI = b.nombre
                     AND (b.planta_id IS NULL OR bod_cliente_instalacion = b.planta_id)))
             ORDER BY bod_id) x

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'BODEGAS', fila, N'NOMBRE', NULL, N'Falta el nombre de la bodega.' FROM #bod WHERE id IS NULL AND nombre IS NULL
UNION ALL
SELECT @CARGA, 'BODEGAS', fila, N'PLANTA', NULL, N'Falta la planta a la que pertenece.' FROM #bod WHERE id IS NULL AND planta IS NULL
UNION ALL
SELECT @CARGA, 'BODEGAS', fila, N'PLANTA', planta, N'La planta no existe o está deshabilitada. Escríbala como en la hoja PLANTAS.' FROM #bod WHERE planta IS NOT NULL AND planta_id IS NULL
UNION ALL
SELECT @CARGA, 'BODEGAS', fila, N'METODO SALIDA', metodo, N'El método de salida es FEFO, FIFO o LIFO.' FROM #bod WHERE metodo IS NOT NULL AND metodo NOT IN (N'FEFO', N'FIFO', N'LIFO')
UNION ALL
SELECT @CARGA, 'BODEGAS', b.fila, N'CODIGO', b.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #bod b CROSS APPLY (SELECT TOP 1 fila FROM #bod x WHERE x.codigo = b.codigo AND x.fila < b.fila ORDER BY x.fila) p
WHERE  b.codigo IS NOT NULL
UNION ALL
SELECT @CARGA, 'BODEGAS', b.fila, N'NOMBRE', b.nombre, N'La bodega se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #bod b CROSS APPLY (SELECT TOP 1 fila FROM #bod x WHERE x.codigo IS NULL AND x.nombre = b.nombre AND x.fila < b.fila ORDER BY x.fila) p
WHERE  b.codigo IS NULL AND b.nombre IS NOT NULL

UPDATE b SET err = 1 FROM #bod b WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'BODEGAS' AND e.cme_fila = b.fila)
UPDATE #bod SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando bodegas' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #bod WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @bCod NVARCHAR(100), @bNom NVARCHAR(400), @bPla INT, @bDes NVARCHAR(1000), @bMet NVARCHAR(20)
            SELECT @id = id, @bCod = codigo, @bNom = nombre, @bPla = planta_id, @bDes = descripcion, @bMet = metodo FROM #bod WHERE fila = @f
            IF @id IS NULL
            BEGIN
                SET @nuevo = NULL
                SELECT @bCod = ISNULL(@bCod, N'AUTO'), @bDes = ISNULL(@bDes, N'')   -- vacio: el SP numera BOD-<id>
                EXEC [dbo].[INS_BODEGA] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @INSTALACION = @bPla, @CODIGO = @bCod,
                     @NOMBRE = @bNom, @DESCRIPCION = @bDes, @USUARIO = @USUARIO
                SET @id = @nuevo
            END
            ELSE
            BEGIN
                DECLARE @bPla0 INT, @bNom0 NVARCHAR(400), @bDes0 NVARCHAR(1000), @bHab0 BIT
                SELECT @bPla0 = bod_cliente_instalacion, @bNom0 = bod_nombre, @bDes0 = bod_descripcion, @bHab0 = bod_habilitado FROM [dbo].[Bodega] WHERE bod_id = @id
                -- EXEC no acepta expresiones: las celdas vacias conservan lo que habia
                SELECT @bPla = ISNULL(@bPla, @bPla0), @bNom = ISNULL(@bNom, @bNom0), @bDes = ISNULL(@bDes, ISNULL(@bDes0, N''))
                EXEC [dbo].[UPD_BODEGA] @ID = @id, @CLIENTE = @CLIENTE, @INSTALACION = @bPla, @NOMBRE = @bNom,
                     @DESCRIPCION = @bDes, @HABILITADO = @bHab0, @USUARIO = @USUARIO
            END
            IF @bMet IS NOT NULL
                EXEC [dbo].[UPD_BODEGA_METODO_SALIDA] @CLIENTE = @CLIENTE, @BODEGA = @id, @METODO = @bMet, @USUARIO = @USUARIO
            UPDATE #bod SET id = @id WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #bod WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'BODEGAS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            /* Solo se deshace lo que dejo abierto el SP que fallo. Si quien llamo
               ya tenia una transaccion (una prueba), no se sigue escribiendo fuera de ella. */
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'BODEGAS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #bod SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = b.res, cmf_id = ISNULL(f.cmf_id, b.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #bod b ON b.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'BODEGAS' AND (f.cmf_resultado IS NULL OR b.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando racks'

/* Resolver una bodega por codigo o nombre: la base o, si no, una fila valida
   de la hoja BODEGAS (que al cargar ya tiene id). */
CREATE TABLE #bodref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #bodref (clave, id, fila)
SELECT bod_codigo, bod_id, NULL FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE
UNION ALL SELECT bod_nombre, bod_id, NULL FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE
UNION ALL SELECT codigo, id, fila FROM #bod WHERE err = 0 AND codigo IS NOT NULL
UNION ALL SELECT nombre, id, fila FROM #bod WHERE err = 0 AND nombre IS NOT NULL

/* ======================================================================
   2. RACKS
   ====================================================================== */
CREATE TABLE #rack (
    fila INT PRIMARY KEY, bodega NVARCHAR(400), codigo NVARCHAR(100), pasillo NVARCHAR(10), area NVARCHAR(60), numero_t NVARCHAR(40),
    nombre NVARCHAR(400), carga_t NVARCHAR(40),
    bodega_id INT, bodega_fila INT, numero INT, carga DECIMAL(10,2), cod_final NVARCHAR(100), nombre_def NVARCHAR(400),
    id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #rack (fila, bodega, codigo, pasillo, area, numero_t, nombre, carga_t)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.bodega)), N''), NULLIF(UPPER(REPLACE(LTRIM(RTRIM(j.codigo)), N' ', N'')), N''),
       NULLIF(UPPER(LTRIM(RTRIM(j.pasillo))), N''), ISNULL(NULLIF(LEFT(LTRIM(RTRIM(j.area)), 60), N''), N'Pasillo'), NULLIF(LTRIM(RTRIM(j.numero)), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.carga)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (bodega NVARCHAR(400) '$.BODEGA', codigo NVARCHAR(100) '$.CODIGO', pasillo NVARCHAR(10) '$.PASILLO', area NVARCHAR(60) '$.TIPO_AREA',
                                        numero NVARCHAR(40) '$.NUMERO', nombre NVARCHAR(400) '$.NOMBRE', carga NVARCHAR(40) '$.CARGA_NIVEL_KG') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'RACKS'

UPDATE r SET bodega_id = x.id, bodega_fila = x.fila
FROM   #rack r CROSS APPLY (SELECT TOP 1 id, fila FROM #bodref WHERE clave = r.bodega COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x
WHERE  r.bodega IS NOT NULL

UPDATE #rack SET numero = TRY_CONVERT(INT, numero_t), carga = TRY_CONVERT(DECIMAL(10,2), carga_t)

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'RACKS', fila, N'BODEGA', NULL, N'Falta la bodega del rack.' FROM #rack WHERE bodega IS NULL
UNION ALL
SELECT @CARGA, 'RACKS', fila, N'BODEGA', bodega, N'La bodega no existe ni viene en la hoja BODEGAS.' FROM #rack WHERE bodega IS NOT NULL AND bodega_id IS NULL AND bodega_fila IS NULL
UNION ALL
SELECT @CARGA, 'RACKS', fila, N'PASILLO', pasillo, N'Sin código, el rack necesita el código de su área: de 1 a 3 letras (A, B, AB).'
FROM   #rack WHERE codigo IS NULL AND (pasillo IS NULL OR LEN(pasillo) > 3 OR pasillo LIKE N'%[^A-Z]%')
UNION ALL
SELECT @CARGA, 'RACKS', fila, N'NUMERO', numero_t, N'El número del rack es un entero mayor que cero.' FROM #rack WHERE numero_t IS NOT NULL AND ISNULL(numero, 0) <= 0
UNION ALL
SELECT @CARGA, 'RACKS', fila, N'CARGA NIVEL KG', carga_t, N'La carga por nivel es un número mayor que cero, en kg.' FROM #rack WHERE carga_t IS NOT NULL AND ISNULL(carga, 0) <= 0

UPDATE r SET err = 1 FROM #rack r WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'RACKS' AND e.cme_fila = r.fila)

/* El codigo final: el escrito, o <prefijo>-<pasillo>-R<nn> desde el siguiente
   numero libre del pasillo (los de la base y los numeros escritos en la
   planilla), como lo sugiere el mapa 3D. Para una bodega que todavia no
   existe (al validar) no se puede saber: se asigna al crear. */
;WITH base AS (
    SELECT r.fila, r.bodega_id, r.pasillo, r.numero,
           ISNULL((SELECT MAX([dbo].[FNC_RACK_NUMERO](u.bub_codigo)) FROM [dbo].[Bodega_Ubicacion] u
                   WHERE u.bub_bodega = r.bodega_id AND [dbo].[FNC_RACK_PASILLO](u.bub_codigo) = r.pasillo), 0) AS max_db,
           ISNULL((SELECT MAX(x.numero) FROM #rack x WHERE ISNULL(x.bodega_id, -x.bodega_fila) = ISNULL(r.bodega_id, -r.bodega_fila)
                   AND x.pasillo = r.pasillo AND x.codigo IS NULL AND x.err = 0), 0) AS max_fi,
           ROW_NUMBER() OVER (PARTITION BY ISNULL(r.bodega_id, -r.bodega_fila), r.pasillo, CASE WHEN r.numero IS NULL THEN 1 ELSE 0 END ORDER BY r.fila) AS k
    FROM   #rack r
    WHERE  r.codigo IS NULL AND r.err = 0 AND (r.bodega_id IS NOT NULL OR r.bodega_fila IS NOT NULL)
)
UPDATE r SET numero = CASE WHEN b.numero IS NOT NULL THEN b.numero
                           ELSE (CASE WHEN b.max_db > b.max_fi THEN b.max_db ELSE b.max_fi END) + b.k END
FROM   #rack r JOIN base b ON b.fila = r.fila

UPDATE r SET cod_final = CASE WHEN r.codigo IS NOT NULL THEN r.codigo
                              WHEN r.bodega_id IS NULL THEN NULL
                              ELSE [dbo].[FNC_BODEGA_PREFIJO_RACK](r.bodega_id) + N'-' + r.pasillo + N'-R' +
                                   CASE WHEN r.numero < 10 THEN N'0' ELSE N'' END + LTRIM(STR(r.numero)) END
FROM   #rack r WHERE r.err = 0

-- el nombre que tendra (el escrito o «Pasillo A · Rack 01»): el stock inicial puede nombrar el rack asi
UPDATE #rack SET nombre_def = ISNULL(nombre, CASE WHEN pasillo IS NOT NULL AND numero IS NOT NULL
                                              THEN area + N' ' + pasillo + N' · Rack ' + CASE WHEN numero < 10 THEN N'0' ELSE N'' END + LTRIM(STR(numero))
                                              ELSE cod_final END)
WHERE  err = 0

UPDATE r SET id = u.bub_id
FROM   #rack r JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_bodega = r.bodega_id AND u.bub_codigo COLLATE Latin1_General_CI_AI = r.cod_final
WHERE  r.cod_final IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'RACKS', r.fila, N'CODIGO', r.cod_final, N'El rack se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #rack r CROSS APPLY (SELECT TOP 1 fila FROM #rack x WHERE x.err = 0 AND x.cod_final = r.cod_final AND ISNULL(x.bodega_id, -x.bodega_fila) = ISNULL(r.bodega_id, -r.bodega_fila) AND x.fila < r.fila ORDER BY x.fila) p
WHERE  r.err = 0 AND r.cod_final IS NOT NULL

UPDATE r SET err = 1 FROM #rack r WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'RACKS' AND e.cme_fila = r.fila)
UPDATE #rack SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando racks' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #rack WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @rBod INT, @rCod NVARCHAR(100), @rNom NVARCHAR(400), @rCar DECIMAL(10,2), @rPas NVARCHAR(10), @rNum INT, @rArea NVARCHAR(60), @aid INT
            SELECT @id = id, @rBod = bodega_id, @rCod = cod_final, @rNom = CASE WHEN id IS NULL THEN nombre_def ELSE nombre END, @rCar = carga, @rPas = pasillo, @rNum = numero, @rArea = area FROM #rack WHERE fila = @f
            IF @id IS NULL
            BEGIN
                SET @nuevo = NULL
                SET @rNom = ISNULL(@rNom, CASE WHEN @rPas IS NOT NULL AND @rNum IS NOT NULL
                                               THEN ISNULL(@rArea, N'Pasillo') + N' ' + @rPas + N' · Rack ' + CASE WHEN @rNum < 10 THEN N'0' ELSE N'' END + LTRIM(STR(@rNum))
                                               ELSE @rCod END)
                EXEC [dbo].[INS_BODEGA_UBICACION] @ID = @nuevo OUTPUT, @BODEGA = @rBod, @CLIENTE = @CLIENTE, @CODIGO = @rCod,
                     @NOMBRE = @rNom, @USUARIO = @USUARIO
                SET @id = @nuevo
                /* El tipo de area del rack (BD 375); si no existe en el catalogo se crea. */
                IF @id IS NOT NULL AND @rArea IS NOT NULL
                BEGIN
                    SET @aid = (SELECT TOP 1 bat_id FROM [dbo].[Bodega_Area_Tipo] WHERE bat_nombre = @rArea AND (bat_cliente IS NULL OR bat_cliente = @CLIENTE) ORDER BY bat_cliente DESC)
                    IF @aid IS NULL
                    BEGIN
                        INSERT INTO [dbo].[Bodega_Area_Tipo] (bat_cliente, bat_nombre) VALUES (@CLIENTE, @rArea)
                        SET @aid = SCOPE_IDENTITY()
                    END
                    UPDATE [dbo].[Bodega_Ubicacion] SET bub_area_tipo = @aid WHERE bub_id = @id
                END
            END
            ELSE IF @rNom IS NOT NULL
                EXEC [dbo].[UPD_BODEGA_UBICACION] @ID = @id, @CLIENTE = @CLIENTE, @NOMBRE = @rNom, @HABILITADO = 1, @USUARIO = @USUARIO
            IF @rCar IS NOT NULL
                EXEC [dbo].[UPD_UBICACION_CARGA] @CLIENTE = @CLIENTE, @UBICACION = @id, @CARGA = @rCar, @USUARIO = @USUARIO
            UPDATE #rack SET id = @id WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #rack WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'RACKS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            /* Solo se deshace lo que dejo abierto el SP que fallo. Si quien llamo
               ya tenia una transaccion (una prueba), no se sigue escribiendo fuera de ella. */
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'RACKS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #rack SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = r.res, cmf_id = ISNULL(f.cmf_id, r.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #rack r ON r.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'RACKS' AND (f.cmf_resultado IS NULL OR r.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando repuestos'

/* ======================================================================
   3. REPUESTOS
   ====================================================================== */
CREATE TABLE #rep (
    fila INT PRIMARY KEY, codigo NVARCHAR(100), nombre NVARCHAR(400), unidad NVARCHAR(100), fabricante NVARCHAR(400), modelo NVARCHAR(400),
    lote_t NVARCHAR(40), cons_t NVARCHAR(40), repa_t NVARCHAR(40), costo_t NVARCHAR(40), vh_t NVARCHAR(40), vd_t NVARCHAR(40), vc_t NVARCHAR(40),
    descripcion NVARCHAR(1000), hab_t NVARCHAR(40), tipo NVARCHAR(200), metodo NVARCHAR(40),
    largo_t NVARCHAR(40), ancho_t NVARCHAR(40), alto_t NVARCHAR(40), peso_t NVARCHAR(40),
    unidad_id INT, tipo_id INT, lote INT, cons INT, repa INT, hab INT,
    costo DECIMAL(18,2), vh DECIMAL(18,2), vd INT, vc DECIMAL(18,2), largo DECIMAL(9,2), ancho DECIMAL(9,2), alto DECIMAL(9,2), peso DECIMAL(10,3),
    id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #rep (fila, codigo, nombre, unidad, fabricante, modelo, lote_t, cons_t, repa_t, costo_t, vh_t, vd_t, vc_t, descripcion, hab_t, tipo, metodo, largo_t, ancho_t, alto_t, peso_t)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.codigo)), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.unidad)), N''),
       NULLIF(LTRIM(RTRIM(j.fabricante)), N''), NULLIF(LTRIM(RTRIM(j.modelo)), N''),
       NULLIF(LTRIM(RTRIM(j.lote)), N''), NULLIF(LTRIM(RTRIM(j.cons)), N''), NULLIF(LTRIM(RTRIM(j.repa)), N''),
       NULLIF(LTRIM(RTRIM(j.costo)), N''), NULLIF(LTRIM(RTRIM(j.vh)), N''), NULLIF(LTRIM(RTRIM(j.vd)), N''), NULLIF(LTRIM(RTRIM(j.vc)), N''),
       NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(LTRIM(RTRIM(j.hab)), N''), NULLIF(LTRIM(RTRIM(j.tipo)), N''),
       NULLIF(UPPER(LTRIM(RTRIM(j.metodo))), N''),
       NULLIF(LTRIM(RTRIM(j.largo)), N''), NULLIF(LTRIM(RTRIM(j.ancho)), N''), NULLIF(LTRIM(RTRIM(j.alto)), N''), NULLIF(LTRIM(RTRIM(j.peso)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (
    codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', unidad NVARCHAR(100) '$.UNIDAD', fabricante NVARCHAR(400) '$.FABRICANTE',
    modelo NVARCHAR(400) '$.MODELO', lote NVARCHAR(40) '$.CONTROLA_LOTE', cons NVARCHAR(40) '$.CONSUMIBLE', repa NVARCHAR(40) '$.REPARABLE',
    costo NVARCHAR(40) '$.COSTO_REFERENCIA', vh NVARCHAR(40) '$.VIDA_UTIL_HORAS', vd NVARCHAR(40) '$.VIDA_UTIL_DIAS', vc NVARCHAR(40) '$.VIDA_UTIL_CICLOS',
    descripcion NVARCHAR(1000) '$.DESCRIPCION', hab NVARCHAR(40) '$.HABILITADO', tipo NVARCHAR(200) '$.TIPO', metodo NVARCHAR(40) '$.METODO_SALIDA',
    largo NVARCHAR(40) '$.LARGO_CM', ancho NVARCHAR(40) '$.ANCHO_CM', alto NVARCHAR(40) '$.ALTO_CM', peso NVARCHAR(40) '$.PESO_KG') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'REPUESTOS'

UPDATE r SET id = x.rep_id
FROM   #rep r CROSS APPLY (SELECT TOP 1 rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND rep_codigo COLLATE Latin1_General_CI_AI = r.codigo ORDER BY rep_id) x
WHERE  r.codigo IS NOT NULL

UPDATE r SET unidad_id = x.ume_id
FROM   #rep r CROSS APPLY (SELECT TOP 1 ume_id FROM [dbo].[Unidad_Medida]
                           WHERE ume_habilitado = 1 AND (ume_codigo COLLATE Latin1_General_CI_AI = r.unidad OR ume_nombre COLLATE Latin1_General_CI_AI = r.unidad
                                                         OR ume_simbolo COLLATE Latin1_General_CS_AS = r.unidad COLLATE Latin1_General_CS_AS)
                           ORDER BY CASE WHEN ume_codigo COLLATE Latin1_General_CI_AI = r.unidad THEN 0 ELSE 1 END, ume_id) x
WHERE  r.unidad IS NOT NULL

UPDATE r SET tipo_id = x.rti_id
FROM   #rep r CROSS APPLY (SELECT TOP 1 rti_id FROM [dbo].[Repuesto_Tipo]
                           WHERE rti_cliente = @CLIENTE AND rti_habilitado = 1
                             AND (rti_codigo COLLATE Latin1_General_CI_AI = r.tipo OR rti_nombre COLLATE Latin1_General_CI_AI = r.tipo)
                           ORDER BY rti_id) x
WHERE  r.tipo IS NOT NULL

UPDATE #rep SET lote = [dbo].[FNC_CM_BOOL](lote_t), cons = [dbo].[FNC_CM_BOOL](cons_t), repa = [dbo].[FNC_CM_BOOL](repa_t), hab = [dbo].[FNC_CM_BOOL](hab_t),
                costo = TRY_CONVERT(DECIMAL(18,2), costo_t), vh = TRY_CONVERT(DECIMAL(18,2), vh_t), vd = TRY_CONVERT(INT, vd_t), vc = TRY_CONVERT(DECIMAL(18,2), vc_t),
                largo = TRY_CONVERT(DECIMAL(9,2), largo_t), ancho = TRY_CONVERT(DECIMAL(9,2), ancho_t), alto = TRY_CONVERT(DECIMAL(9,2), alto_t), peso = TRY_CONVERT(DECIMAL(10,3), peso_t),
                metodo = CASE WHEN metodo IN (N'SEGUN BODEGA', N'SEGÚN BODEGA', N'SEGUN LA BODEGA', N'SEGÚN LA BODEGA', N'BODEGA') THEN N'BODEGA' ELSE metodo END

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'REPUESTOS', fila, N'NOMBRE', NULL, N'Falta el nombre del repuesto.' FROM #rep WHERE id IS NULL AND nombre IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'UNIDAD', NULL, N'Falta la unidad de medida.' FROM #rep WHERE id IS NULL AND unidad IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'UNIDAD', unidad, N'La unidad no existe. Escríbala como en la hoja UNIDADES.' FROM #rep WHERE unidad IS NOT NULL AND unidad_id IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'TIPO', tipo, N'El tipo no existe. Escríbalo como en la hoja TIPOS.' FROM #rep WHERE tipo IS NOT NULL AND tipo_id IS NULL
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'CONTROLA LOTE', lote_t, N'Escriba SI o NO.' FROM #rep WHERE lote = 2
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'CONSUMIBLE', cons_t, N'Escriba SI o NO.' FROM #rep WHERE cons = 2
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'REPARABLE', repa_t, N'Escriba SI o NO.' FROM #rep WHERE repa = 2
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'HABILITADO', hab_t, N'Escriba SI o NO.' FROM #rep WHERE hab = 2
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'COSTO REFERENCIA', costo_t, N'El costo es un número mayor o igual a cero.' FROM #rep WHERE costo_t IS NOT NULL AND (costo IS NULL OR costo < 0)
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'VIDA UTIL HORAS', vh_t, N'Las horas son un número mayor que cero.' FROM #rep WHERE vh_t IS NOT NULL AND (vh IS NULL OR vh <= 0)
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'VIDA UTIL DIAS', vd_t, N'Los días son un número entero mayor que cero.' FROM #rep WHERE vd_t IS NOT NULL AND (vd IS NULL OR vd <= 0)
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'VIDA UTIL CICLOS', vc_t, N'Los ciclos son un número mayor que cero.' FROM #rep WHERE vc_t IS NOT NULL AND (vc IS NULL OR vc <= 0)
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'METODO SALIDA', metodo, N'El método es FEFO, FIFO, LIFO o «Según bodega».' FROM #rep WHERE metodo IS NOT NULL AND metodo NOT IN (N'FEFO', N'FIFO', N'LIFO', N'BODEGA')
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'LARGO CM', largo_t, N'Las medidas son números mayores que cero, en cm.' FROM #rep WHERE largo_t IS NOT NULL AND ISNULL(largo, 0) <= 0
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'ANCHO CM', ancho_t, N'Las medidas son números mayores que cero, en cm.' FROM #rep WHERE ancho_t IS NOT NULL AND ISNULL(ancho, 0) <= 0
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'ALTO CM', alto_t, N'Las medidas son números mayores que cero, en cm.' FROM #rep WHERE alto_t IS NOT NULL AND ISNULL(alto, 0) <= 0
UNION ALL SELECT @CARGA, 'REPUESTOS', fila, N'PESO KG', peso_t, N'El peso es un número mayor o igual a cero, en kg.' FROM #rep WHERE peso_t IS NOT NULL AND (peso IS NULL OR peso < 0)
UNION ALL
SELECT @CARGA, 'REPUESTOS', r.fila, N'CODIGO', r.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #rep r CROSS APPLY (SELECT TOP 1 fila FROM #rep x WHERE x.codigo = r.codigo AND x.fila < r.fila ORDER BY x.fila) p
WHERE  r.codigo IS NOT NULL

UPDATE r SET err = 1 FROM #rep r WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'REPUESTOS' AND e.cme_fila = r.fila)
UPDATE #rep SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando repuestos' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #rep WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @pCod NVARCHAR(100), @pNom NVARCHAR(400), @pUni INT, @pFab NVARCHAR(400), @pMod NVARCHAR(400), @pDes NVARCHAR(1000),
                    @pRepa INT, @pCons INT, @pLote INT, @pHab INT, @pCosto DECIMAL(18,2), @pVh DECIMAL(18,2), @pVd INT, @pVc DECIMAL(18,2), @pTipo INT,
                    @pMet NVARCHAR(40), @pLa DECIMAL(9,2), @pAn DECIMAL(9,2), @pAl DECIMAL(9,2), @pPe DECIMAL(10,3)
            SELECT @id = id, @pCod = codigo, @pNom = nombre, @pUni = unidad_id, @pFab = fabricante, @pMod = modelo, @pDes = descripcion,
                   @pRepa = repa, @pCons = cons, @pLote = lote, @pHab = hab, @pCosto = costo, @pVh = vh, @pVd = vd, @pVc = vc, @pTipo = tipo_id,
                   @pMet = metodo, @pLa = largo, @pAn = ancho, @pAl = alto, @pPe = peso
            FROM   #rep WHERE fila = @f
            IF @id IS NULL
            BEGIN
                SET @nuevo = NULL
                SELECT @pCod = ISNULL(@pCod, N'AUTO'), @pFab = ISNULL(@pFab, N''), @pMod = ISNULL(@pMod, N''), @pDes = ISNULL(@pDes, N''),
                       @pRepa = ISNULL(@pRepa, 0), @pCons = ISNULL(@pCons, 0), @pLote = ISNULL(@pLote, 0)
                EXEC [dbo].[INS_REPUESTO] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CODIGO = @pCod, @NOMBRE = @pNom, @UNIDAD_MEDIDA = @pUni,
                     @FABRICANTE = @pFab, @MODELO = @pMod, @DESCRIPCION = @pDes,
                     @ES_REPARABLE = @pRepa, @ES_CONSUMIBLE = @pCons, @CONTROLA_LOTE = @pLote, @COSTO_REFERENCIA = @pCosto, @MONEDA = NULL,
                     @VIDA_UTIL_HORA = @pVh, @VIDA_UTIL_DIA = @pVd, @VIDA_UTIL_CICLO = @pVc, @REPUESTO_TIPO = @pTipo, @USUARIO = @USUARIO
                SET @id = @nuevo
            END
            ELSE
            BEGIN
                -- las celdas vacias conservan lo que habia
                DECLARE @q TABLE (nom NVARCHAR(400), uni INT, fab NVARCHAR(400), mo NVARCHAR(400), des NVARCHAR(1000), repa BIT, cons BIT, lote BIT,
                                  costo DECIMAL(18,2), mon INT, vh DECIMAL(18,2), vd INT, vc DECIMAL(18,2), tipo INT, hab BIT)
                DELETE FROM @q
                INSERT INTO @q SELECT rep_nombre, rep_unidad_medida, rep_fabricante, rep_modelo, rep_descripcion, rep_es_reparable, rep_es_consumible, rep_controla_lote,
                                      rep_costo_referencia, rep_moneda, rep_vida_util_hora, rep_vida_util_dia, rep_vida_util_ciclo, rep_repuesto_tipo, rep_habilitado
                               FROM [dbo].[Repuesto] WHERE rep_id = @id
                DECLARE @qNom NVARCHAR(400), @qUni INT, @qFab NVARCHAR(400), @qMo NVARCHAR(400), @qDes NVARCHAR(1000), @qRepa BIT, @qCons BIT, @qLote BIT,
                        @qCosto DECIMAL(18,2), @qMon INT, @qVh DECIMAL(18,2), @qVd INT, @qVc DECIMAL(18,2), @qTipo INT, @qHab BIT
                SELECT @qNom = nom, @qUni = uni, @qFab = fab, @qMo = mo, @qDes = des, @qRepa = repa, @qCons = cons, @qLote = lote, @qCosto = costo, @qMon = mon,
                       @qVh = vh, @qVd = vd, @qVc = vc, @qTipo = tipo, @qHab = hab FROM @q
                SELECT @pNom = ISNULL(@pNom, @qNom), @pUni = ISNULL(@pUni, @qUni), @pFab = ISNULL(@pFab, @qFab), @pMod = ISNULL(@pMod, @qMo),
                       @pDes = ISNULL(@pDes, @qDes), @pRepa = ISNULL(@pRepa, @qRepa), @pCons = ISNULL(@pCons, @qCons), @pLote = ISNULL(@pLote, @qLote),
                       @pCosto = ISNULL(@pCosto, @qCosto), @pVh = ISNULL(@pVh, @qVh), @pVd = ISNULL(@pVd, @qVd), @pVc = ISNULL(@pVc, @qVc),
                       @pTipo = ISNULL(@pTipo, @qTipo), @pHab = ISNULL(@pHab, @qHab)
                EXEC [dbo].[UPD_REPUESTO] @ID = @id, @CLIENTE = @CLIENTE, @NOMBRE = @pNom, @UNIDAD_MEDIDA = @pUni,
                     @FABRICANTE = @pFab, @MODELO = @pMod, @DESCRIPCION = @pDes,
                     @ES_REPARABLE = @pRepa, @ES_CONSUMIBLE = @pCons, @CONTROLA_LOTE = @pLote,
                     @COSTO_REFERENCIA = @pCosto, @MONEDA = @qMon, @VIDA_UTIL_HORA = @pVh, @VIDA_UTIL_DIA = @pVd,
                     @VIDA_UTIL_CICLO = @pVc, @REPUESTO_TIPO = @pTipo, @LIMPIA_VIDA_UTIL = 0,
                     @HABILITADO = @pHab, @USUARIO = @USUARIO
            END
            IF @pMet IS NOT NULL
            BEGIN
                DECLARE @pMet2 VARCHAR(4) = CASE WHEN @pMet = N'BODEGA' THEN NULL ELSE @pMet END
                EXEC [dbo].[UPD_REPUESTO_METODO_SALIDA] @CLIENTE = @CLIENTE, @REPUESTO = @id, @METODO = @pMet2, @USUARIO = @USUARIO
            END
            IF @pLa IS NOT NULL OR @pAn IS NOT NULL OR @pAl IS NOT NULL OR @pPe IS NOT NULL
            BEGIN
                DECLARE @mLa DECIMAL(9,2), @mAn DECIMAL(9,2), @mAl DECIMAL(9,2), @mPe DECIMAL(10,3)
                SELECT @mLa = ISNULL(@pLa, rep_largo_cm), @mAn = ISNULL(@pAn, rep_ancho_cm), @mAl = ISNULL(@pAl, rep_alto_cm), @mPe = ISNULL(@pPe, rep_peso_kg)
                FROM   [dbo].[Repuesto] WHERE rep_id = @id
                EXEC [dbo].[UPD_REPUESTO_DIMENSIONES] @CLIENTE = @CLIENTE, @REPUESTO = @id, @LARGO = @mLa, @ANCHO = @mAn, @ALTO = @mAl, @PESO = @mPe, @USUARIO = @USUARIO
            END
            UPDATE #rep SET id = @id WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #rep WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'REPUESTOS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            /* Solo se deshace lo que dejo abierto el SP que fallo. Si quien llamo
               ya tenia una transaccion (una prueba), no se sigue escribiendo fuera de ella. */
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'REPUESTOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #rep SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = r.res, cmf_id = ISNULL(f.cmf_id, r.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #rep r ON r.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'REPUESTOS' AND (f.cmf_resultado IS NULL OR r.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando umbrales'

/* Resolver un repuesto: la base o una fila valida de REPUESTOS. */
CREATE TABLE #repref (clave NVARCHAR(100) COLLATE Latin1_General_CI_AI, id INT, fila INT, lote BIT)
INSERT INTO #repref (clave, id, fila, lote)
SELECT rep_codigo, rep_id, NULL, rep_controla_lote FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE
UNION ALL SELECT codigo, id, fila, ISNULL(lote, 0) FROM #rep WHERE err = 0 AND codigo IS NOT NULL AND id IS NULL

-- las bodegas pudieron crearse en este proceso: la referencia se refresca
DELETE FROM #bodref
INSERT INTO #bodref (clave, id, fila)
SELECT bod_codigo, bod_id, NULL FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE
UNION ALL SELECT bod_nombre, bod_id, NULL FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE
UNION ALL SELECT codigo, id, fila FROM #bod WHERE err = 0 AND codigo IS NOT NULL AND id IS NULL
UNION ALL SELECT nombre, id, fila FROM #bod WHERE err = 0 AND nombre IS NOT NULL AND id IS NULL

/* ======================================================================
   4. UMBRALES
   ====================================================================== */
CREATE TABLE #umb (
    fila INT PRIMARY KEY, repuesto NVARCHAR(100), bodega NVARCHAR(400), min_t NVARCHAR(40), max_t NVARCHAR(40), pr_t NVARCHAR(40), obs NVARCHAR(500),
    rep_id INT, rep_fila INT, bod_id INT, bod_fila INT, mn DECIMAL(18,4), mx DECIMAL(18,4), pr DECIMAL(18,4),
    id INT, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #umb (fila, repuesto, bodega, min_t, max_t, pr_t, obs)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.repuesto)), N''), NULLIF(LTRIM(RTRIM(j.bodega)), N''), NULLIF(LTRIM(RTRIM(j.mn)), N''),
       NULLIF(LTRIM(RTRIM(j.mx)), N''), NULLIF(LTRIM(RTRIM(j.pr)), N''), NULLIF(LTRIM(RTRIM(j.obs)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (repuesto NVARCHAR(100) '$.REPUESTO', bodega NVARCHAR(400) '$.BODEGA', mn NVARCHAR(40) '$.MINIMO',
                                        mx NVARCHAR(40) '$.MAXIMO', pr NVARCHAR(40) '$.PUNTO_REPOSICION', obs NVARCHAR(500) '$.OBSERVACION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'UMBRALES'

UPDATE u SET rep_id = x.id, rep_fila = x.fila FROM #umb u CROSS APPLY (SELECT TOP 1 id, fila FROM #repref WHERE clave = u.repuesto COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE u.repuesto IS NOT NULL
UPDATE u SET bod_id = x.id, bod_fila = x.fila FROM #umb u CROSS APPLY (SELECT TOP 1 id, fila FROM #bodref WHERE clave = u.bodega COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE u.bodega IS NOT NULL
UPDATE #umb SET mn = TRY_CONVERT(DECIMAL(18,4), min_t), mx = TRY_CONVERT(DECIMAL(18,4), max_t), pr = TRY_CONVERT(DECIMAL(18,4), pr_t)
UPDATE u SET id = s.rbs_id FROM #umb u JOIN [dbo].[Repuesto_Bodega_Stock] s ON s.rbs_repuesto = u.rep_id AND s.rbs_bodega = u.bod_id AND s.rbs_cliente = @CLIENTE

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'UMBRALES', fila, N'REPUESTO', repuesto, CASE WHEN repuesto IS NULL THEN N'Falta el código del repuesto.' ELSE N'El repuesto no existe ni viene en la hoja REPUESTOS.' END
FROM   #umb WHERE rep_id IS NULL AND rep_fila IS NULL
UNION ALL
SELECT @CARGA, 'UMBRALES', fila, N'BODEGA', bodega, CASE WHEN bodega IS NULL THEN N'Falta la bodega.' ELSE N'La bodega no existe ni viene en la hoja BODEGAS.' END
FROM   #umb WHERE bod_id IS NULL AND bod_fila IS NULL
UNION ALL SELECT @CARGA, 'UMBRALES', fila, N'MINIMO', min_t, N'El mínimo es obligatorio y es un número mayor o igual a cero.' FROM #umb WHERE mn IS NULL OR mn < 0
UNION ALL SELECT @CARGA, 'UMBRALES', fila, N'MAXIMO', max_t, N'El máximo es un número mayor o igual al mínimo.' FROM #umb WHERE max_t IS NOT NULL AND (mx IS NULL OR mx < ISNULL(mn, 0))
UNION ALL SELECT @CARGA, 'UMBRALES', fila, N'PUNTO REPOSICION', pr_t, N'El punto de reposición es un número entre el mínimo y el máximo.' FROM #umb WHERE pr_t IS NOT NULL AND (pr IS NULL OR pr < ISNULL(mn, 0) OR (mx IS NOT NULL AND pr > mx))
UNION ALL
SELECT @CARGA, 'UMBRALES', u.fila, N'REPUESTO', u.repuesto, N'El repuesto y la bodega se repiten en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #umb u CROSS APPLY (SELECT TOP 1 fila FROM #umb x WHERE x.repuesto = u.repuesto AND x.bodega = u.bodega AND x.fila < u.fila ORDER BY x.fila) p
WHERE  u.repuesto IS NOT NULL AND u.bodega IS NOT NULL

UPDATE u SET err = 1 FROM #umb u WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'UMBRALES' AND e.cme_fila = u.fila)
UPDATE #umb SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Guardando umbrales' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #umb WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @uRep INT, @uBod INT, @uMn DECIMAL(18,4), @uMx DECIMAL(18,4), @uPr DECIMAL(18,4), @uObs NVARCHAR(500)
            SELECT @uRep = rep_id, @uBod = bod_id, @uMn = mn, @uMx = mx, @uPr = pr, @uObs = obs FROM #umb WHERE fila = @f
            SET @nuevo = NULL
            EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @uRep, @BODEGA = @uBod,
                 @STOCK_MINIMO = @uMn, @STOCK_MAXIMO = @uMx, @PUNTO_REPOSICION = @uPr, @OBSERVACION = @uObs, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #umb WHERE fila = @f), cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'UMBRALES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            /* Solo se deshace lo que dejo abierto el SP que fallo. Si quien llamo
               ya tenia una transaccion (una prueba), no se sigue escribiendo fuera de ella. */
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'UMBRALES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #umb SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = u.res
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #umb u ON u.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'UMBRALES' AND (f.cmf_resultado IS NULL OR u.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando stock inicial'

/* ======================================================================
   5. STOCK INICIAL
   ====================================================================== */
-- racks: la base y los validos de la hoja RACKS (por codigo final o nombre)
CREATE TABLE #rackref (bod_id INT, bod_fila INT, clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #rackref (bod_id, bod_fila, clave, id, fila)
SELECT u.bub_bodega, NULL, u.bub_codigo, u.bub_id, NULL FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega AND b.bod_cliente = @CLIENTE WHERE u.bub_habilitado = 1
UNION ALL
SELECT u.bub_bodega, NULL, u.bub_nombre, u.bub_id, NULL FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega AND b.bod_cliente = @CLIENTE WHERE u.bub_habilitado = 1
UNION ALL SELECT bodega_id, bodega_fila, ISNULL(cod_final, codigo), id, fila FROM #rack WHERE err = 0 AND id IS NULL AND ISNULL(cod_final, codigo) IS NOT NULL
UNION ALL SELECT bodega_id, bodega_fila, nombre_def, id, fila FROM #rack WHERE err = 0 AND id IS NULL AND nombre_def IS NOT NULL

CREATE TABLE #stk (
    fila INT PRIMARY KEY, repuesto NVARCHAR(100), bodega NVARCHAR(400), rack NVARCHAR(400), cant_t NVARCHAR(40), costo_t NVARCHAR(40),
    lote NVARCHAR(200), vence_t NVARCHAR(40), obs NVARCHAR(500),
    rep_id INT, rep_fila INT, con_lote BIT, bod_id INT, bod_fila INT, rack_id INT, rack_fila INT, bod_con_racks BIT,
    cant DECIMAL(18,4), costo DECIMAL(18,2), vence DATE, err BIT NOT NULL DEFAULT 0, res CHAR(1))

INSERT INTO #stk (fila, repuesto, bodega, rack, cant_t, costo_t, lote, vence_t, obs)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.repuesto)), N''), NULLIF(LTRIM(RTRIM(j.bodega)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.rack))), N''),
       NULLIF(LTRIM(RTRIM(j.cant)), N''), NULLIF(LTRIM(RTRIM(j.costo)), N''), NULLIF(LTRIM(RTRIM(j.lote)), N''), NULLIF(LTRIM(RTRIM(j.vence)), N''),
       NULLIF(LTRIM(RTRIM(j.obs)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (repuesto NVARCHAR(100) '$.REPUESTO', bodega NVARCHAR(400) '$.BODEGA', rack NVARCHAR(400) '$.RACK',
                                        cant NVARCHAR(40) '$.CANTIDAD', costo NVARCHAR(40) '$.COSTO_UNITARIO', lote NVARCHAR(200) '$.LOTE',
                                        vence NVARCHAR(40) '$.VENCE', obs NVARCHAR(500) '$.OBSERVACION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'STOCK_INICIAL'

UPDATE s SET rep_id = x.id, rep_fila = x.fila, con_lote = x.lote FROM #stk s CROSS APPLY (SELECT TOP 1 id, fila, lote FROM #repref WHERE clave = s.repuesto COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE s.repuesto IS NOT NULL
-- si la planilla cambia CONTROLA LOTE de un repuesto existente, vale lo de la planilla
UPDATE s SET con_lote = r.lote FROM #stk s JOIN #rep r ON r.id = s.rep_id AND r.err = 0 AND r.lote IN (0, 1)
UPDATE s SET bod_id = x.id, bod_fila = x.fila FROM #stk s CROSS APPLY (SELECT TOP 1 id, fila FROM #bodref WHERE clave = s.bodega COLLATE Latin1_General_CI_AI ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE s.bodega IS NOT NULL
UPDATE s SET rack_id = x.id, rack_fila = x.fila
FROM   #stk s CROSS APPLY (SELECT TOP 1 id, fila FROM #rackref r
                           WHERE r.clave = s.rack COLLATE Latin1_General_CI_AI AND (r.bod_id = s.bod_id OR (s.bod_id IS NULL AND r.bod_fila = s.bod_fila))
                           ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x
WHERE  s.rack IS NOT NULL
UPDATE s SET bod_con_racks = CASE WHEN EXISTS (SELECT 1 FROM #rackref r WHERE r.bod_id = s.bod_id OR (s.bod_id IS NULL AND r.bod_fila = s.bod_fila)) THEN 1 ELSE 0 END FROM #stk s
UPDATE #stk SET cant = TRY_CONVERT(DECIMAL(18,4), cant_t), costo = TRY_CONVERT(DECIMAL(18,2), costo_t), vence = TRY_CONVERT(DATE, vence_t, 23)

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'STOCK_INICIAL', fila, N'REPUESTO', repuesto, CASE WHEN repuesto IS NULL THEN N'Falta el código del repuesto.' ELSE N'El repuesto no existe ni viene en la hoja REPUESTOS.' END
FROM   #stk WHERE rep_id IS NULL AND rep_fila IS NULL
UNION ALL
SELECT @CARGA, 'STOCK_INICIAL', fila, N'BODEGA', bodega, CASE WHEN bodega IS NULL THEN N'Falta la bodega.' ELSE N'La bodega no existe ni viene en la hoja BODEGAS.' END
FROM   #stk WHERE bod_id IS NULL AND bod_fila IS NULL
UNION ALL
SELECT @CARGA, 'STOCK_INICIAL', fila, N'RACK', rack, N'El rack no existe en esa bodega ni viene en la hoja RACKS.'
FROM   #stk WHERE rack IS NOT NULL AND rack_id IS NULL AND rack_fila IS NULL AND (bod_id IS NOT NULL OR bod_fila IS NOT NULL)
UNION ALL
SELECT @CARGA, 'STOCK_INICIAL', fila, N'RACK', NULL, N'La bodega tiene racks: indique en cuál queda el stock.'
FROM   #stk WHERE rack IS NULL AND bod_con_racks = 1
UNION ALL SELECT @CARGA, 'STOCK_INICIAL', fila, N'CANTIDAD', cant_t, N'La cantidad es obligatoria y mayor que cero.' FROM #stk WHERE cant IS NULL OR cant <= 0
UNION ALL SELECT @CARGA, 'STOCK_INICIAL', fila, N'COSTO UNITARIO', costo_t, N'El costo es un número mayor o igual a cero.' FROM #stk WHERE costo_t IS NOT NULL AND (costo IS NULL OR costo < 0)
UNION ALL SELECT @CARGA, 'STOCK_INICIAL', fila, N'VENCE', vence_t, N'La fecha de vencimiento no se entiende: use día-mes-año o una fecha de Excel.' FROM #stk WHERE vence_t IS NOT NULL AND vence IS NULL
UNION ALL SELECT @CARGA, 'STOCK_INICIAL', fila, N'LOTE', NULL, N'Este repuesto controla lote: indique el código del lote.' FROM #stk WHERE con_lote = 1 AND lote IS NULL
UNION ALL SELECT @CARGA, 'STOCK_INICIAL', fila, N'LOTE', lote, N'Este repuesto no controla lote: deje LOTE vacío o márquelo CONTROLA LOTE = SI.' FROM #stk WHERE ISNULL(con_lote, 0) = 0 AND lote IS NOT NULL AND (rep_id IS NOT NULL OR rep_fila IS NOT NULL)
UNION ALL
SELECT @CARGA, 'STOCK_INICIAL', s.fila, N'REPUESTO', s.repuesto,
       N'Ya tiene stock en ' + CASE WHEN s.rack IS NULL THEN N'esa bodega' ELSE N'ese rack' END + CASE WHEN s.lote IS NULL THEN N'' ELSE N' con ese lote' END +
       N': el stock inicial se carga una vez. Para corregirlo, use un ajuste.'
FROM   #stk s
WHERE  s.rep_id IS NOT NULL AND s.bod_id IS NOT NULL
  AND  EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo] a
               LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = a.isa_repuesto_lote
               WHERE a.isa_cliente = @CLIENTE AND a.isa_repuesto = s.rep_id AND a.isa_bodega = s.bod_id AND a.isa_cantidad > 0
                 AND ISNULL(a.isa_bodega_ubicacion, 0) = ISNULL(s.rack_id, 0)
                 AND (s.lote IS NULL OR l.rlo_codigo COLLATE Latin1_General_CI_AI = s.lote))
UNION ALL
SELECT @CARGA, 'STOCK_INICIAL', s.fila, N'REPUESTO', s.repuesto, N'El repuesto, la bodega, el rack y el lote se repiten en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #stk s CROSS APPLY (SELECT TOP 1 fila FROM #stk x WHERE x.repuesto = s.repuesto AND x.bodega = s.bodega AND ISNULL(x.rack, N'') = ISNULL(s.rack, N'')
                                                        AND ISNULL(x.lote, N'') = ISNULL(s.lote, N'') AND x.fila < s.fila ORDER BY x.fila) p
WHERE  s.repuesto IS NOT NULL AND s.bodega IS NOT NULL

UPDATE s SET err = 1 FROM #stk s WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'STOCK_INICIAL' AND e.cme_fila = s.fila)
UPDATE #stk SET res = CASE WHEN err = 1 THEN 'E' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Ingresando stock inicial' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #stk WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @sRep INT, @sBod INT, @sRack INT, @sCant DECIMAL(18,4), @sCosto DECIMAL(18,2), @sLoteCod NVARCHAR(200), @sVence DATE,
                    @sObs NVARCHAR(500), @sConLote BIT, @sLote INT, @sMov INT
            SELECT @sRep = rep_id, @sBod = bod_id, @sRack = rack_id, @sCant = cant, @sCosto = costo, @sLoteCod = lote, @sVence = vence,
                   @sObs = ISNULL(obs, @obs), @sConLote = con_lote FROM #stk WHERE fila = @f
            SET @sLote = NULL
            IF @sLoteCod IS NOT NULL
            BEGIN
                SELECT TOP 1 @sLote = rlo_id FROM [dbo].[Repuesto_Lote]
                WHERE rlo_cliente = @CLIENTE AND rlo_repuesto = @sRep AND rlo_codigo COLLATE Latin1_General_CI_AI = @sLoteCod
                IF @sLote IS NULL
                    EXEC [dbo].[INS_REPUESTO_LOTE] @ID = @sLote OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @sRep, @CODIGO = @sLoteCod,
                         @FECHA_INGRESO = @hoy, @FECHA_VENCIMIENTO = @sVence, @PROVEEDOR = NULL, @COSTO_UNITARIO = @sCosto, @MONEDA = NULL,
                         @OBSERVACION = @obs, @USUARIO = @USUARIO
            END
            SET @sMov = NULL
            DECLARE @sUuid UNIQUEIDENTIFIER = NEWID()
            EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID = @sMov OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @sRep, @BODEGA = @sBod, @TIPO = 1,
                 @CANTIDAD = @sCant, @UBICACION = @sRack, @LOTE = @sLote, @COSTO_UNITARIO = @sCosto, @MONEDA = NULL, @ORDEN_TRABAJO = NULL,
                 @BODEGA_DESTINO = NULL, @UBICACION_DESTINO = NULL, @OBSERVACION = @sObs, @UUID = @sUuid, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @sMov
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'STOCK_INICIAL' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            /* Solo se deshace lo que dejo abierto el SP que fallo. Si quien llamo
               ya tenia una transaccion (una prueba), no se sigue escribiendo fuera de ella. */
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'STOCK_INICIAL', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #stk SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = s.res
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #stk s ON s.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'STOCK_INICIAL' AND (f.cmf_resultado IS NULL OR s.res = 'E')

/* ======================================================================
   5. COMPATIBILIDADES (bloque 368): en qué equipos o componentes sirve
   cada repuesto, lo mismo que la ficha del activo vincula a mano. El
   activo tiene que existir (carga de Activos); el repuesto puede venir
   en la hoja REPUESTOS de esta misma planilla.
   ====================================================================== */
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando compatibilidades'
CREATE TABLE #rco (fila INT PRIMARY KEY, repuesto NVARCHAR(400), activo NVARCHAR(400), componente NVARCHAR(400), observacion NVARCHAR(500),
                   repuesto_id INT, repuesto_fila INT, activo_id INT, comp_id INT,
                   existe BIT NOT NULL DEFAULT 0, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #rco (fila, repuesto, activo, componente, observacion)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.repuesto)), N''), NULLIF(LTRIM(RTRIM(j.activo)), N''), NULLIF(LTRIM(RTRIM(j.componente)), N''), NULLIF(LTRIM(RTRIM(j.obs)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (repuesto NVARCHAR(400) '$.REPUESTO', activo NVARCHAR(400) '$.ACTIVO', componente NVARCHAR(400) '$.COMPONENTE', obs NVARCHAR(500) '$.OBSERVACION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'COMPATIBILIDADES'

-- el repuesto: de la base (codigo o nombre) o de la hoja REPUESTOS
UPDATE r SET repuesto_id = x.rep_id FROM #rco r
CROSS APPLY (SELECT TOP 1 rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE
             AND (rep_codigo COLLATE Latin1_General_CI_AI = r.repuesto OR rep_nombre COLLATE Latin1_General_CI_AI = r.repuesto)
             ORDER BY CASE WHEN rep_codigo COLLATE Latin1_General_CI_AI = r.repuesto THEN 0 ELSE 1 END, rep_id) x
WHERE r.repuesto IS NOT NULL
UPDATE r SET repuesto_fila = x.fila FROM #rco r
CROSS APPLY (SELECT TOP 1 p.fila FROM #rep p WHERE p.err = 0
             AND (p.codigo COLLATE Latin1_General_CI_AI = r.repuesto OR p.nombre COLLATE Latin1_General_CI_AI = r.repuesto) ORDER BY p.fila) x
WHERE r.repuesto IS NOT NULL AND r.repuesto_id IS NULL
UPDATE r SET activo_id = x.act_id FROM #rco r
CROSS APPLY (SELECT TOP 1 act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE
             AND (act_codigo COLLATE Latin1_General_CI_AI = r.activo OR act_nombre COLLATE Latin1_General_CI_AI = r.activo)
             ORDER BY CASE WHEN act_codigo COLLATE Latin1_General_CI_AI = r.activo THEN 0 ELSE 1 END, act_id) x
WHERE r.activo IS NOT NULL
UPDATE r SET comp_id = x.aco_id FROM #rco r
CROSS APPLY (SELECT TOP 1 aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = r.activo_id
             AND (aco_nombre COLLATE Latin1_General_CI_AI = r.componente OR aco_codigo COLLATE Latin1_General_CI_AI = r.componente) ORDER BY aco_id) x
WHERE r.componente IS NOT NULL AND r.activo_id IS NOT NULL
UPDATE r SET existe = 1 FROM #rco r
WHERE  r.activo_id IS NOT NULL AND r.repuesto_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] x WHERE x.rco_repuesto = r.repuesto_id
                AND ((r.comp_id IS NOT NULL AND x.rco_activo_componente = r.comp_id)
                  OR (r.componente IS NULL AND x.rco_activo = r.activo_id AND x.rco_activo_componente IS NULL)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'COMPATIBILIDADES', fila, N'REPUESTO', repuesto, CASE WHEN repuesto IS NULL THEN N'Falta el repuesto.' ELSE N'El repuesto no existe ni viene en la hoja REPUESTOS.' END FROM #rco WHERE repuesto_id IS NULL AND repuesto_fila IS NULL
UNION ALL SELECT @CARGA, 'COMPATIBILIDADES', fila, N'ACTIVO', activo, CASE WHEN activo IS NULL THEN N'Falta el activo.' ELSE N'El activo no existe. Escríbalo como en la hoja ACTIVOS (código o nombre).' END FROM #rco WHERE activo_id IS NULL
UNION ALL SELECT @CARGA, 'COMPATIBILIDADES', fila, N'COMPONENTE', componente, N'Ese componente no existe en el activo.' FROM #rco WHERE componente IS NOT NULL AND activo_id IS NOT NULL AND comp_id IS NULL
UNION ALL
SELECT @CARGA, 'COMPATIBILIDADES', r.fila, N'REPUESTO', r.repuesto, N'El repuesto se repite para el mismo activo (fila ' + LTRIM(STR(p.fila)) + N').'
FROM   #rco r CROSS APPLY (SELECT TOP 1 fila FROM #rco x WHERE x.activo = r.activo AND ISNULL(x.componente, N'') = ISNULL(r.componente, N'') AND x.repuesto = r.repuesto AND x.fila < r.fila ORDER BY x.fila) p
UPDATE r SET err = 1 FROM #rco r WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'COMPATIBILIDADES' AND e.cme_fila = r.fila)
UPDATE #rco SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Vinculando compatibilidades' WHERE cma_id = @CARGA
    UPDATE r SET repuesto_id = p.id FROM #rco r JOIN #rep p ON p.fila = r.repuesto_fila WHERE r.repuesto_id IS NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #rco WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @cAct INT, @cCom INT, @cRep INT, @cObs NVARCHAR(500)
            SELECT @cAct = activo_id, @cCom = comp_id, @cRep = repuesto_id, @cObs = observacion FROM #rco WHERE fila = @f
            IF @cRep IS NULL RAISERROR(N'El repuesto no se pudo crear.', 16, 1)
            /* El vinculo es con el activo O con uno de sus componentes, no con los dos. */
            IF @cCom IS NOT NULL SET @cAct = NULL
            SET @nuevo = NULL
            EXEC [dbo].[INS_ACTIVO_REPUESTO_COMPATIBLE] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @cRep, @ACTIVO = @cAct,
                 @COMPONENTE = @cCom, @OBSERVACION = @cObs, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'COMPATIBILIDADES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'COMPATIBILIDADES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #rco SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = r.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #rco r ON r.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'COMPATIBILIDADES' AND (f.cmf_resultado IS NULL OR r.res = 'E')

-- hojas que el modulo no conoce: sus filas no se tocan, pero tampoco quedan "pendientes"
UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'O'
WHERE  cmf_carga = @CARGA AND cmf_resultado IS NULL

EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Listo'
UPDATE [dbo].[Carga_Masiva]
SET    cma_estado = CASE WHEN cma_errores > 0 THEN 'CON_ERRORES' ELSE 'TERMINADA' END,
       cma_fin = [dbo].[FNC_AHORA](),
       cma_mensaje = CASE WHEN @CARGAR = 1
                          THEN LTRIM(STR(cma_creadas)) + N' creadas, ' + LTRIM(STR(cma_actualizadas)) + N' actualizadas, ' + LTRIM(STR(cma_omitidas)) + N' omitidas y ' + LTRIM(STR(cma_errores)) + N' con error.'
                          ELSE N'Revisión: ' + LTRIM(STR(cma_creadas)) + N' se crearían, ' + LTRIM(STR(cma_actualizadas)) + N' se actualizarían, ' + LTRIM(STR(cma_omitidas)) + N' se omitirían y ' + LTRIM(STR(cma_errores)) + N' tienen errores.' END
WHERE  cma_id = @CARGA

GO
PRINT '376_CARGA_RACKS_TIPO_AREA aplicado.'
GO
