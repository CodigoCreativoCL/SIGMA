/* ============================================================================
   480 · Carga de Mantenimiento: «checklist» se llama «inspección» (17-10-2026)
   Hojas INSPECCIONES, ITEMS DE INSPECCION e INSPECCIONES PROGRAMADAS; la ayuda INSPECCIONES EXISTENTES. Solo cambian los textos que
   ve la persona (mensajes y fases): las claves internas y las tablas siguen igual. El libro con los nombres viejos se sigue leyendo.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   PRC_CARGA_MANTENIMIENTO · mismo contrato que PRC_CARGA_ACTIVOS (Carga_Masiva, Carga_Masiva_Fila con
   el JSON de cada fila, Carga_Masiva_Error, REVISAR antes de CARGAR, ACTUALIZAR / OMITIR existentes).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[PRC_CARGA_MANTENIMIENTO]
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

UPDATE [dbo].[Carga_Masiva] SET cma_estado = 'PROCESANDO', cma_fase = N'Revisando frecuencias' WHERE cma_id = @CARGA
DELETE FROM [dbo].[Carga_Masiva_Error] WHERE cme_carga = @CARGA
UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = NULL, cmf_id = NULL WHERE cmf_carga = @CARGA

DECLARE @f INT, @n INT = 0, @id INT, @nuevo INT, @hoy DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @pid INT, @pin INT, @msg NVARCHAR(800)

/* ---- catalogos que usan varias hojas (la clave se compara sin mayusculas ni acentos) ---- */
CREATE TABLE #usr (clave NVARCHAR(300) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #usr SELECT u.usu_correo, u.usu_id FROM [dbo].[Usuario] u JOIN [dbo].[Cliente_Usuario] c ON c.ucl_id_usuario = u.usu_id AND c.ucl_id_cliente = @CLIENTE
 WHERE u.usu_correo IS NOT NULL AND ISNULL(c.ucl_habilitado, 1) = 1
INSERT INTO #usr SELECT u.usu_login, u.usu_id FROM [dbo].[Usuario] u JOIN [dbo].[Cliente_Usuario] c ON c.ucl_id_usuario = u.usu_id AND c.ucl_id_cliente = @CLIENTE
 WHERE u.usu_login IS NOT NULL AND ISNULL(c.ucl_habilitado, 1) = 1
CREATE TABLE #grp (clave NVARCHAR(300) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #grp SELECT gtr_nombre, gtr_id FROM [dbo].[Grupo_Trabajo] WHERE gtr_cliente = @CLIENTE AND gtr_habilitado = 1
INSERT INTO #grp SELECT gtr_codigo, gtr_id FROM [dbo].[Grupo_Trabajo] WHERE gtr_cliente = @CLIENTE AND gtr_habilitado = 1 AND gtr_codigo IS NOT NULL
CREATE TABLE #pla (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #pla SELECT cin_nombre, cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1
INSERT INTO #pla SELECT cin_codigo, cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1 AND cin_codigo IS NOT NULL
CREATE TABLE #are (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, planta INT)
INSERT INTO #are SELECT iar_nombre, iar_id, iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_cliente = @CLIENTE AND ISNULL(iar_habilitado, 1) = 1
INSERT INTO #are SELECT iar_codigo, iar_id, iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_cliente = @CLIENTE AND ISNULL(iar_habilitado, 1) = 1 AND iar_codigo IS NOT NULL
CREATE TABLE #act (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, planta INT, tipo INT, modelo INT)
INSERT INTO #act SELECT act_codigo, act_id, act_cliente_instalacion, act_activo_tipo, act_activo_modelo FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_habilitado = 1
INSERT INTO #act SELECT SUBSTRING(act_codigo, 5, 100), act_id, act_cliente_instalacion, act_activo_tipo, act_activo_modelo FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_habilitado = 1 AND act_codigo LIKE N'ACT-%'
INSERT INTO #act SELECT act_nombre, act_id, act_cliente_instalacion, act_activo_tipo, act_activo_modelo FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_habilitado = 1
CREATE TABLE #uni (clave NVARCHAR(200) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #uni SELECT ume_codigo, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1
INSERT INTO #uni SELECT ume_nombre, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1
INSERT INTO #uni SELECT ume_simbolo, ume_id FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1 AND ume_simbolo IS NOT NULL

/* ======================================================================
   1. FRECUENCIAS
   ====================================================================== */
CREATE TABLE #dmap (t NVARCHAR(3) COLLATE Latin1_General_CI_AI, n INT)
INSERT INTO #dmap VALUES (N'LUN',1),(N'MAR',2),(N'MIE',3),(N'JUE',4),(N'VIE',5),(N'SAB',6),(N'DOM',7),(N'1',1),(N'2',2),(N'3',3),(N'4',4),(N'5',5),(N'6',6),(N'7',7)
CREATE TABLE #umap (t NVARCHAR(3) COLLATE Latin1_General_CI_AI, id INT)
INSERT INTO #umap VALUES (N'MIN',1),(N'HOR',2),(N'DIA',3),(N'SEM',4),(N'MES',5),(N'ANO',6),(N'ANI',6)

CREATE TABLE #fre (fila INT PRIMARY KEY, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI, tipo_t NVARCHAR(40) COLLATE Latin1_General_CI_AI, dias_t NVARCHAR(100) COLLATE Latin1_General_CI_AI, mes_t NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    cada_t NVARCHAR(10) COLLATE Latin1_General_CI_AI, unidad_t NVARCHAR(40) COLLATE Latin1_General_CI_AI, hora_t NVARCHAR(20) COLLATE Latin1_General_CI_AI, desde_t NVARCHAR(40) COLLATE Latin1_General_CI_AI,
    modo CHAR(1), dias NVARCHAR(50) COLLATE Latin1_General_CI_AI, dia_mes INT, cada INT, uti INT, hora TIME, desde DATE, id INT, privada BIT,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #fre (fila, nombre, tipo_t, dias_t, mes_t, cada_t, unidad_t, hora_t, desde_t)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.tipo)), N''), NULLIF(LTRIM(RTRIM(j.dias)), N''), NULLIF(LTRIM(RTRIM(j.dia_mes)), N''),
       NULLIF(LTRIM(RTRIM(j.cada)), N''), NULLIF(LTRIM(RTRIM(j.unidad)), N''), NULLIF(LTRIM(RTRIM(j.hora)), N''), NULLIF(LTRIM(RTRIM(j.desde)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (nombre NVARCHAR(400) '$.NOMBRE', tipo NVARCHAR(40) '$.TIPO', dias NVARCHAR(100) '$.DIAS', dia_mes NVARCHAR(10) '$.DIA_MES',
        cada NVARCHAR(10) '$.CADA', unidad NVARCHAR(40) '$.UNIDAD', hora NVARCHAR(20) '$.HORA', desde NVARCHAR(40) '$.DESDE') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'FRECUENCIAS'

UPDATE #fre SET modo = CASE WHEN tipo_t IN (N'SEMANAL', N'SEMANA', N'SEMANALES') THEN 'S' WHEN tipo_t IN (N'MENSUAL', N'MES', N'MENSUALES') THEN 'M'
                            WHEN tipo_t IN (N'CADA', N'INTERVALO', N'PERIODICA', N'PERIODICO') THEN 'C' END
UPDATE #fre SET dia_mes = TRY_CONVERT(INT, mes_t), cada = TRY_CONVERT(INT, cada_t), hora = TRY_CONVERT(TIME(0), hora_t), desde = TRY_CONVERT(DATE, desde_t)
UPDATE h SET uti = x.id FROM #fre h CROSS APPLY (SELECT TOP 1 id FROM #umap WHERE t = LEFT(h.unidad_t, 3)) x WHERE h.unidad_t IS NOT NULL
CREATE TABLE #fd (fila INT, n INT NULL)
INSERT INTO #fd SELECT h.fila, m.n FROM #fre h CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(h.dias_t, N';', N','), N' ', N','), N',') s
       LEFT JOIN #dmap m ON m.t = LEFT(LTRIM(RTRIM(s.value)), 3)
 WHERE h.modo = 'S' AND LTRIM(RTRIM(s.value)) <> N''
UPDATE h SET dias = (SELECT STRING_AGG(CAST(q.n AS NVARCHAR(1)), N',') WITHIN GROUP (ORDER BY q.n) FROM (SELECT DISTINCT n FROM #fd WHERE fila = h.fila AND n IS NOT NULL) q) FROM #fre h WHERE h.modo = 'S'
UPDATE h SET id = x.pro_id, privada = x.pro_es_privada FROM #fre h
CROSS APPLY (SELECT TOP 1 pro_id, pro_es_privada FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_habilitado = 1
             AND pro_nombre COLLATE Latin1_General_CI_AI = h.nombre ORDER BY pro_id) x WHERE h.nombre IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'FRECUENCIAS', fila, N'NOMBRE', NULL, N'Falta el nombre de la frecuencia.' FROM #fre WHERE nombre IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'TIPO', tipo_t, N'El tipo es SEMANAL, MENSUAL o CADA.' FROM #fre WHERE modo IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'DIAS', dias_t, N'Una frecuencia SEMANAL necesita sus días (LUN, MAR, MIE, JUE, VIE, SAB, DOM o 1 a 7).' FROM #fre WHERE modo = 'S' AND dias_t IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'DIAS', dias_t, N'Hay un día que no se entiende. Escriba LUN, MAR, MIE, JUE, VIE, SAB, DOM o 1 a 7 separados por coma.' FROM #fre h
       WHERE modo = 'S' AND dias_t IS NOT NULL AND EXISTS (SELECT 1 FROM #fd WHERE fila = h.fila AND n IS NULL)
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'DIA MES', mes_t, N'Una frecuencia MENSUAL necesita el día del mes (1 a 31).' FROM #fre WHERE modo = 'M' AND (dia_mes IS NULL OR dia_mes < 1 OR dia_mes > 31)
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'CADA', cada_t, N'«Cada» es un número entero desde 1 (cada 15 días, cada 3 meses…).' FROM #fre WHERE modo = 'C' AND (cada IS NULL OR cada < 1)
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'UNIDAD', unidad_t, N'La unidad es HORA, DIA, SEMANA, MES o AÑO.' FROM #fre WHERE modo = 'C' AND uti IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'HORA', hora_t, N'La hora se escribe así: 08:00.' FROM #fre WHERE hora_t IS NOT NULL AND hora IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', fila, N'DESDE', desde_t, N'La fecha de inicio no se entiende (dd-mm-aaaa).' FROM #fre WHERE desde_t IS NOT NULL AND desde IS NULL
UNION ALL SELECT @CARGA, 'FRECUENCIAS', a.fila, N'NOMBRE', a.nombre, N'La frecuencia se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #fre a CROSS APPLY (SELECT TOP 1 fila FROM #fre x WHERE x.nombre = a.nombre AND x.fila < a.fila ORDER BY x.fila) p WHERE a.nombre IS NOT NULL
UPDATE a SET err = 1 FROM #fre a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'FRECUENCIAS' AND e.cme_fila = a.fila)
/* Una compartida no se edita desde una carga: su pantalla es la de Programaciones. */
UPDATE #fre SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 OR privada = 0 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando frecuencias' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #fre WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @fNom NVARCHAR(400), @fModo CHAR(1), @fModoSp CHAR(1), @fDias NVARCHAR(50), @fDM INT, @fCada INT, @fUti INT, @fHora TIME(0), @fDesde DATE, @fAncla DATETIME
            SELECT @id = id, @fNom = nombre, @fModo = modo, @fDias = dias, @fDM = dia_mes, @fCada = cada, @fUti = uti, @fHora = hora, @fDesde = desde FROM #fre WHERE fila = @f
            IF @fModo IN ('S', 'M')
            BEGIN
                SET @fModoSp = CASE WHEN @fModo = 'S' THEN 'w' ELSE 'm' END
                EXEC [dbo].[UPS_PROGRAMACION_SIMPLE] @ID = @id OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @fNom, @MODO = @fModoSp,
                     @DIAS = @fDias, @DIA_MES = @fDM, @HORA = @fHora, @USUARIO = @USUARIO
                IF @fDesde IS NOT NULL UPDATE [dbo].[Programacion] SET pro_fecha_inicio = @fDesde WHERE pro_id = @id
            END
            ELSE
            BEGIN
                IF @id IS NULL EXEC [dbo].[INS_PROGRAMACION_PRIVADA] @ID = @id OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @fNom, @USUARIO = @USUARIO
                UPDATE [dbo].[Programacion]
                   SET pro_programacion_tipo = (SELECT pti_id FROM [dbo].[Programacion_Tipo] WHERE pti_codigo = 'INTERVALO TIEMPO'),
                       pro_fecha_inicio = ISNULL(@fDesde, ISNULL(pro_fecha_inicio, @hoy)), pro_habilitado = 1
                 WHERE pro_id = @id
                SET @pin = NULL
                SET @fAncla = CAST(@fDesde AS DATETIME)
                EXEC [dbo].[UPS_PROGRAMACION_INTERVALO] @ID = @pin OUTPUT, @PROGRAMACION = @id, @CLIENTE = @CLIENTE, @UNIDAD_TIEMPO = @fUti, @CANTIDAD = @fCada,
                     @FECHA_ANCLA_UTC = @fAncla, @DESDE_EJECUCION = 0, @USUARIO = @USUARIO
            END
            UPDATE #fre SET id = @id, cmf = 1 WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #fre WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'FRECUENCIAS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'FRECUENCIAS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #fre SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res, cmf_id = ISNULL(f.cmf_id, a.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #fre a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'FRECUENCIAS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando tareas'

/* Referencias a una frecuencia desde las otras hojas: nombre, de la base o de una fila valida de FRECUENCIAS. */
CREATE TABLE #fref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #fref SELECT pro_nombre, pro_id, NULL FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_habilitado = 1
INSERT INTO #fref SELECT nombre, id, fila FROM #fre WHERE err = 0 AND nombre IS NOT NULL

/* ======================================================================
   2. TAREAS
   ====================================================================== */
CREATE TABLE #tar (fila INT PRIMARY KEY, codigo NVARCHAR(100) COLLATE Latin1_General_CI_AI, titulo NVARCHAR(400) COLLATE Latin1_General_CI_AI, descripcion NVARCHAR(MAX) COLLATE Latin1_General_CI_AI,
    prioridad NVARCHAR(100) COLLATE Latin1_General_CI_AI, dur_t NVARCHAR(20) COLLATE Latin1_General_CI_AI, evid NVARCHAR(10) COLLATE Latin1_General_CI_AI, categoria NVARCHAR(200) COLLATE Latin1_General_CI_AI, planta NVARCHAR(400) COLLATE Latin1_General_CI_AI, area NVARCHAR(400) COLLATE Latin1_General_CI_AI, equipo NVARCHAR(400) COLLATE Latin1_General_CI_AI, habil NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    cod_final NVARCHAR(100) COLLATE Latin1_General_CI_AI, pri_id INT, dur INT, cat_id INT, planta_id INT, area_id INT, activo_id INT, id INT,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #tar (fila, codigo, titulo, descripcion, prioridad, dur_t, evid, categoria, planta, area, equipo, habil)
SELECT f.cmf_fila, NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.titulo)), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(LTRIM(RTRIM(j.prioridad)), N''),
       NULLIF(LTRIM(RTRIM(j.dur)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.evid))), N''), NULLIF(LTRIM(RTRIM(j.categoria)), N''), NULLIF(LTRIM(RTRIM(j.planta)), N''),
       NULLIF(LTRIM(RTRIM(j.area)), N''), NULLIF(LTRIM(RTRIM(j.equipo)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.habil))), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (codigo NVARCHAR(100) '$.CODIGO', titulo NVARCHAR(400) '$.TITULO', descripcion NVARCHAR(MAX) '$.DESCRIPCION', prioridad NVARCHAR(100) '$.PRIORIDAD',
        dur NVARCHAR(20) '$.DURACION_MIN', evid NVARCHAR(10) '$.REQUIERE_EVIDENCIA', categoria NVARCHAR(200) '$.CATEGORIA', planta NVARCHAR(400) '$.PLANTA',
        area NVARCHAR(400) '$.AREA', equipo NVARCHAR(400) '$.EQUIPO', habil NVARCHAR(10) '$.HABILITADA') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'TAREAS'

UPDATE #tar SET cod_final = CASE WHEN codigo IS NULL THEN NULL WHEN codigo LIKE N'TAR-%' THEN codigo ELSE N'TAR-' + codigo END, dur = TRY_CONVERT(INT, dur_t)
UPDATE t SET pri_id = x.tpa_id FROM #tar t
CROSS APPLY (SELECT TOP 1 tpa_id FROM [dbo].[Tarea_Prioridad] WHERE tpa_habilitado = 1
             AND (tpa_nombre COLLATE Latin1_General_CI_AI = t.prioridad OR tpa_codigo COLLATE Latin1_General_CI_AI = t.prioridad)) x WHERE t.prioridad IS NOT NULL
UPDATE t SET planta_id = x.id FROM #tar t CROSS APPLY (SELECT TOP 1 id FROM #pla WHERE clave = t.planta ORDER BY id) x WHERE t.planta IS NOT NULL
UPDATE t SET area_id = x.id FROM #tar t CROSS APPLY (SELECT TOP 1 id FROM #are WHERE clave = t.area AND (t.planta_id IS NULL OR planta = t.planta_id) ORDER BY id) x WHERE t.area IS NOT NULL
UPDATE t SET activo_id = x.id FROM #tar t CROSS APPLY (SELECT TOP 1 id FROM #act WHERE clave = t.equipo ORDER BY id) x WHERE t.equipo IS NOT NULL
UPDATE t SET cat_id = x.tca_id FROM #tar t
CROSS APPLY (SELECT TOP 1 tca_id FROM [dbo].[Tarea_Categoria] WHERE (tca_cliente = @CLIENTE OR tca_cliente IS NULL) AND ISNULL(tca_habilitado, 1) = 1
             AND tca_nombre COLLATE Latin1_General_CI_AI = t.categoria ORDER BY tca_id) x WHERE t.categoria IS NOT NULL
UPDATE t SET id = x.tar_id FROM #tar t
CROSS APPLY (SELECT TOP 1 tar_id FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE
             AND ((t.cod_final IS NOT NULL AND tar_codigo COLLATE Latin1_General_CI_AI = t.cod_final)
               OR (t.cod_final IS NULL AND tar_titulo COLLATE Latin1_General_CI_AI = t.titulo)) ORDER BY tar_id) x

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'TAREAS', fila, N'TITULO', NULL, N'Falta el título de la tarea.' FROM #tar WHERE id IS NULL AND titulo IS NULL
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'PRIORIDAD', prioridad, N'La prioridad es Baja, Media, Alta o Crítica.' FROM #tar WHERE prioridad IS NOT NULL AND pri_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'DURACION MIN', dur_t, N'La duración son minutos, un número entero mayor que cero.' FROM #tar WHERE dur_t IS NOT NULL AND (dur IS NULL OR dur < 1)
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'PLANTA', planta, N'La planta no existe. Escríbala como en la hoja PLANTAS.' FROM #tar WHERE planta IS NOT NULL AND planta_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'AREA', area, N'El área no existe en esa planta. Escríbala como en la hoja AREAS.' FROM #tar WHERE area IS NOT NULL AND area_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'EQUIPO', equipo, N'El equipo no existe. Escriba su código o nombre como en la hoja ACTIVOS EXISTENTES.' FROM #tar WHERE equipo IS NOT NULL AND activo_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'CATEGORIA', categoria, N'La categoría necesita al menos 3 letras.' FROM #tar WHERE categoria IS NOT NULL AND cat_id IS NULL AND LEN(categoria) < 3
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'REQUIERE EVIDENCIA', evid, N'Escriba SI o NO.' FROM #tar WHERE evid IS NOT NULL AND evid NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'TAREAS', fila, N'HABILITADA', habil, N'Escriba SI o NO.' FROM #tar WHERE habil IS NOT NULL AND habil NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'TAREAS', a.fila, N'CODIGO', a.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #tar a CROSS APPLY (SELECT TOP 1 fila FROM #tar x WHERE x.cod_final = a.cod_final AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NOT NULL
UNION ALL SELECT @CARGA, 'TAREAS', a.fila, N'TITULO', a.titulo, N'La tarea se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #tar a CROSS APPLY (SELECT TOP 1 fila FROM #tar x WHERE x.cod_final IS NULL AND x.titulo = a.titulo AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NULL AND a.titulo IS NOT NULL
UPDATE a SET err = 1 FROM #tar a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'TAREAS' AND e.cme_fila = a.fila)
UPDATE #tar SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando tareas' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #tar WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @tCod NVARCHAR(100), @tTit NVARCHAR(400), @tDes NVARCHAR(MAX), @tPri INT, @tDur INT, @tEv BIT, @tCatT NVARCHAR(200), @tCat INT,
                    @tPla INT, @tAre INT, @tAct INT, @tHab BIT
            SELECT @id = id, @tCod = ISNULL(cod_final, N'AUTO'), @tTit = titulo, @tDes = descripcion, @tPri = pri_id, @tDur = dur, @tCatT = categoria, @tCat = cat_id,
                   @tPla = planta_id, @tAre = area_id, @tAct = activo_id,
                   @tEv = CASE WHEN evid IN (N'SI', N'SÍ') THEN 1 WHEN evid = N'NO' THEN 0 END,
                   @tHab = CASE WHEN habil = N'NO' THEN 0 WHEN habil IN (N'SI', N'SÍ') THEN 1 END
            FROM #tar WHERE fila = @f
            IF @tCat IS NULL AND @tCatT IS NOT NULL
                EXEC [dbo].[UPS_TAREA_CATEGORIA_NOMBRE] @ID = @tCat OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @tCatT, @USUARIO = @USUARIO
            IF @id IS NULL
            BEGIN
                SET @nuevo = NULL
                EXEC [dbo].[INS_TAREA] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CODIGO = @tCod, @TITULO = @tTit, @DESCRIPCION = @tDes,
                     @TAREA_PRIORIDAD = @tPri, @CLIENTE_INSTALACION = @tPla, @INSTALACION_AREA = @tAre, @ACTIVO = @tAct, @TAREA_CATEGORIA = @tCat,
                     @DURACION_ESTIMADA_MINUTO = @tDur, @REQUIERE_EVIDENCIA = @tEv, @USUARIO = @USUARIO
                SET @id = @nuevo
                IF @tHab = 0 EXEC [dbo].[UPD_TAREA] @ID = @id, @HABILITADO = 0, @USUARIO = @USUARIO
            END
            ELSE
                EXEC [dbo].[UPD_TAREA] @ID = @id, @TITULO = @tTit, @DESCRIPCION = @tDes, @TAREA_PRIORIDAD = @tPri, @CLIENTE_INSTALACION = @tPla,
                     @INSTALACION_AREA = @tAre, @ACTIVO = @tAct, @TAREA_CATEGORIA = @tCat, @DURACION_ESTIMADA_MINUTO = @tDur,
                     @REQUIERE_EVIDENCIA = @tEv, @HABILITADO = @tHab, @USUARIO = @USUARIO
            UPDATE #tar SET id = @id, cmf = 1 WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #tar WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'TAREAS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'TAREAS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #tar SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res, cmf_id = ISNULL(f.cmf_id, a.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #tar a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'TAREAS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando tareas programadas'

/* Referencias a una tarea: codigo (con o sin TAR-) o titulo, de la base o de una fila valida de TAREAS. */
CREATE TABLE #tref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #tref SELECT tar_codigo, tar_id, NULL FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_habilitado = 1
INSERT INTO #tref SELECT SUBSTRING(tar_codigo, 5, 100), tar_id, NULL FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_habilitado = 1 AND tar_codigo LIKE N'TAR-%'
INSERT INTO #tref SELECT tar_titulo, tar_id, NULL FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_habilitado = 1
INSERT INTO #tref SELECT cod_final, id, fila FROM #tar WHERE err = 0 AND cod_final IS NOT NULL
INSERT INTO #tref SELECT codigo, id, fila FROM #tar WHERE err = 0 AND codigo IS NOT NULL
INSERT INTO #tref SELECT titulo, id, fila FROM #tar WHERE err = 0 AND titulo IS NOT NULL

/* ======================================================================
   3. TAREAS PROGRAMADAS
   ====================================================================== */
CREATE TABLE #tpg (fila INT PRIMARY KEY, tarea NVARCHAR(400) COLLATE Latin1_General_CI_AI, frecuencia NVARCHAR(400) COLLATE Latin1_General_CI_AI, responsable NVARCHAR(300) COLLATE Latin1_General_CI_AI, grupo NVARCHAR(300) COLLATE Latin1_General_CI_AI,
    tarea_id INT, tarea_fila INT, fre_id INT, fre_fila INT, usr_id INT, grp_id INT, id INT, cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #tpg (fila, tarea, frecuencia, responsable, grupo)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.tarea)), N''), NULLIF(LTRIM(RTRIM(j.frecuencia)), N''), NULLIF(LTRIM(RTRIM(j.responsable)), N''), NULLIF(LTRIM(RTRIM(j.grupo)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (tarea NVARCHAR(400) '$.TAREA', frecuencia NVARCHAR(400) '$.FRECUENCIA', responsable NVARCHAR(300) '$.RESPONSABLE', grupo NVARCHAR(300) '$.GRUPO') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'TAREAS_PROGRAMADAS'
UPDATE t SET tarea_id = x.id, tarea_fila = x.fila FROM #tpg t CROSS APPLY (SELECT TOP 1 id, fila FROM #tref WHERE clave = t.tarea ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.tarea IS NOT NULL
UPDATE t SET fre_id = x.id, fre_fila = x.fila FROM #tpg t CROSS APPLY (SELECT TOP 1 id, fila FROM #fref WHERE clave = t.frecuencia ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.frecuencia IS NOT NULL
UPDATE t SET usr_id = (SELECT TOP 1 id FROM #usr WHERE clave = t.responsable) FROM #tpg t WHERE t.responsable IS NOT NULL
UPDATE t SET grp_id = (SELECT TOP 1 id FROM #grp WHERE clave = t.grupo) FROM #tpg t WHERE t.grupo IS NOT NULL
UPDATE t SET id = x.tpr_id FROM #tpg t CROSS APPLY (SELECT TOP 1 tpr_id FROM [dbo].[Tarea_Programacion] WHERE tpr_tarea = t.tarea_id AND tpr_programacion = t.fre_id AND tpr_habilitado = 1) x
WHERE t.tarea_id IS NOT NULL AND t.fre_id IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'TAREAS_PROGRAMADAS', fila, N'TAREA', tarea, CASE WHEN tarea IS NULL THEN N'Falta la tarea.' ELSE N'La tarea no existe ni viene en la hoja TAREAS.' END FROM #tpg WHERE tarea_id IS NULL AND tarea_fila IS NULL
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', fila, N'FRECUENCIA', frecuencia, CASE WHEN frecuencia IS NULL THEN N'Falta la frecuencia.' ELSE N'La frecuencia no existe ni viene en la hoja FRECUENCIAS.' END FROM #tpg WHERE fre_id IS NULL AND fre_fila IS NULL
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', fila, N'RESPONSABLE', responsable, N'La persona no es usuaria de esta empresa. Escriba su correo como en la hoja PERSONAS.' FROM #tpg WHERE responsable IS NOT NULL AND usr_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', fila, N'GRUPO', grupo, N'El grupo de trabajo no existe. Escríbalo como en la hoja GRUPOS.' FROM #tpg WHERE grupo IS NOT NULL AND grp_id IS NULL
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', a.fila, N'TAREA', a.tarea, N'Esa tarea ya tiene esa frecuencia en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #tpg a CROSS APPLY (SELECT TOP 1 fila FROM #tpg x WHERE x.fila < a.fila AND x.tarea = a.tarea AND x.frecuencia = a.frecuencia ORDER BY x.fila) p
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', a.fila, N'TAREA', a.tarea, N'La tarea de la fila ' + LTRIM(STR(a.tarea_fila)) + N' de la hoja TAREAS tiene errores.'
       FROM #tpg a JOIN #tar t ON t.fila = a.tarea_fila WHERE a.tarea_id IS NULL AND t.err = 1
UNION ALL SELECT @CARGA, 'TAREAS_PROGRAMADAS', a.fila, N'FRECUENCIA', a.frecuencia, N'La frecuencia de la fila ' + LTRIM(STR(a.fre_fila)) + N' de la hoja FRECUENCIAS tiene errores.'
       FROM #tpg a JOIN #fre t ON t.fila = a.fre_fila WHERE a.fre_id IS NULL AND t.err = 1
UPDATE a SET err = 1 FROM #tpg a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'TAREAS_PROGRAMADAS' AND e.cme_fila = a.fila)
UPDATE #tpg SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NOT NULL THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Programando tareas' WHERE cma_id = @CARGA
    UPDATE t SET tarea_id = r.id FROM #tpg t JOIN #tar r ON r.fila = t.tarea_fila WHERE t.tarea_id IS NULL AND r.id IS NOT NULL
    UPDATE t SET fre_id = r.id FROM #tpg t JOIN #fre r ON r.fila = t.fre_fila WHERE t.fre_id IS NULL AND r.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #tpg WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @pTar INT, @pFre INT, @pUsr INT, @pGrp INT
            SELECT @pTar = tarea_id, @pFre = fre_id, @pUsr = usr_id, @pGrp = grp_id FROM #tpg WHERE fila = @f
            IF @pTar IS NULL RAISERROR(N'La tarea no se pudo crear.', 16, 1)
            IF @pFre IS NULL RAISERROR(N'La frecuencia no se pudo crear.', 16, 1)
            SET @nuevo = NULL
            EXEC [dbo].[INS_TAREA_PROGRAMACION] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @TAREA = @pTar, @PROGRAMACION = @pFre,
                 @USUARIO_RESPONSABLE = @pUsr, @GRUPO_TRABAJO = @pGrp, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'TAREAS_PROGRAMADAS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'TAREAS_PROGRAMADAS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #tpg SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #tpg a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'TAREAS_PROGRAMADAS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando inspecciones'

/* ======================================================================
   4. CHECKLISTS
   ====================================================================== */
CREATE TABLE #chk (fila INT PRIMARY KEY, codigo NVARCHAR(100) COLLATE Latin1_General_CI_AI, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI, descripcion NVARCHAR(MAX) COLLATE Latin1_General_CI_AI,
    planta NVARCHAR(400) COLLATE Latin1_General_CI_AI, tipo NVARCHAR(400) COLLATE Latin1_General_CI_AI, publicar NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    cod_final NVARCHAR(100) COLLATE Latin1_General_CI_AI, planta_id INT, tipo_id INT, id INT, ver_id INT, items INT NOT NULL DEFAULT 0,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #chk (fila, codigo, nombre, descripcion, planta, tipo, publicar)
SELECT f.cmf_fila, NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(LTRIM(RTRIM(j.planta)), N''),
       NULLIF(LTRIM(RTRIM(j.tipo)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.publicar))), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', descripcion NVARCHAR(MAX) '$.DESCRIPCION', planta NVARCHAR(400) '$.PLANTA',
        tipo NVARCHAR(400) '$.TIPO_ACTIVO', publicar NVARCHAR(10) '$.PUBLICAR') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLISTS'
UPDATE #chk SET cod_final = CASE WHEN codigo IS NULL THEN NULL WHEN codigo LIKE N'PAU-%' THEN codigo ELSE N'PAU-' + codigo END
UPDATE t SET planta_id = x.id FROM #chk t CROSS APPLY (SELECT TOP 1 id FROM #pla WHERE clave = t.planta ORDER BY id) x WHERE t.planta IS NOT NULL
UPDATE t SET tipo_id = x.ati_id FROM #chk t CROSS APPLY (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ISNULL(ati_habilitado, 1) = 1
       AND ati_nombre COLLATE Latin1_General_CI_AI = t.tipo ORDER BY ati_id) x WHERE t.tipo IS NOT NULL
UPDATE t SET id = x.cpl_id FROM #chk t CROSS APPLY (SELECT TOP 1 cpl_id FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_habilitado = 1
       AND ((t.cod_final IS NOT NULL AND cpl_codigo COLLATE Latin1_General_CI_AI = t.cod_final)
         OR (t.cod_final IS NULL AND cpl_nombre COLLATE Latin1_General_CI_AI = t.nombre)) ORDER BY cpl_id) x
UPDATE t SET ver_id = (SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = t.id AND cpv_checklist_version_estado = 1 AND cpv_habilitado = 1 ORDER BY cpv_numero DESC)
FROM #chk t WHERE t.id IS NOT NULL

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'CHECKLISTS', fila, N'NOMBRE', NULL, N'Falta el nombre de la inspección.' FROM #chk WHERE id IS NULL AND nombre IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS', fila, N'PLANTA', planta, N'La planta no existe. Escríbala como en la hoja PLANTAS.' FROM #chk WHERE planta IS NOT NULL AND planta_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS', fila, N'TIPO ACTIVO', tipo, N'El tipo de activo no existe. Escríbalo como en la hoja TIPOS ACTIVO.' FROM #chk WHERE tipo IS NOT NULL AND tipo_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS', fila, N'PUBLICAR', publicar, N'Escriba SI o NO.' FROM #chk WHERE publicar IS NOT NULL AND publicar NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'CHECKLISTS', a.fila, N'CODIGO', a.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #chk a CROSS APPLY (SELECT TOP 1 fila FROM #chk x WHERE x.cod_final = a.cod_final AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NOT NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS', a.fila, N'NOMBRE', a.nombre, N'La inspección se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #chk a CROSS APPLY (SELECT TOP 1 fila FROM #chk x WHERE x.cod_final IS NULL AND x.nombre = a.nombre AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NULL AND a.nombre IS NOT NULL
UPDATE a SET err = 1 FROM #chk a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'CHECKLISTS' AND e.cme_fila = a.fila)
UPDATE #chk SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando inspecciones' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #chk WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @cCod NVARCHAR(100), @cNom NVARCHAR(400), @cDes NVARCHAR(MAX), @cPla INT, @cTipo INT, @cAsig INT, @cMax INT
            SELECT @id = id, @cCod = cod_final, @cNom = nombre, @cDes = descripcion, @cPla = planta_id, @cTipo = tipo_id FROM #chk WHERE fila = @f
            IF @id IS NULL
            BEGIN
                IF @cCod IS NULL
                BEGIN
                    SELECT @cMax = ISNULL(MAX(TRY_CONVERT(INT, SUBSTRING(cpl_codigo, 5, 10))), 0) FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_codigo LIKE N'PAU-%'
                    SET @cCod = N'PAU-' + RIGHT(N'000' + CAST(@cMax + 1 AS NVARCHAR(10)), 3)
                END
                SET @nuevo = NULL
                EXEC [dbo].[INS_CHECKLIST_PLANTILLA] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @cPla, @ACTIVO_TIPO = @cTipo,
                     @CODIGO = @cCod, @NOMBRE = @cNom, @DESCRIPCION = @cDes, @USUARIO = @USUARIO
                SET @id = @nuevo
            END
            ELSE
            BEGIN
                /* UPD_CHECKLIST_PLANTILLA pisa lo que no recibe: las celdas vacias conservan lo que habia. */
                SELECT @cPla = ISNULL(@cPla, cpl_cliente_instalacion), @cTipo = ISNULL(@cTipo, cpl_activo_tipo), @cAsig = cpl_checklist_asignacion_tipo,
                       @cDes = ISNULL(@cDes, cpl_descripcion), @cNom = ISNULL(@cNom, cpl_nombre), @cCod = cpl_codigo
                FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @id
                EXEC [dbo].[UPD_CHECKLIST_PLANTILLA] @ID = @id, @CLIENTE_INSTALACION = @cPla, @CHECKLIST_ASIGNACION_TIPO = @cAsig, @ACTIVO_TIPO = @cTipo,
                     @CODIGO = @cCod, @NOMBRE = @cNom, @DESCRIPCION = @cDes, @USUARIO = @USUARIO
            END
            UPDATE c SET id = @id, cmf = 1, ver_id = (SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @id AND cpv_checklist_version_estado = 1 AND cpv_habilitado = 1 ORDER BY cpv_numero DESC)
            FROM #chk c WHERE c.fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #chk WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'CHECKLISTS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'CHECKLISTS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #chk SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res, cmf_id = ISNULL(f.cmf_id, a.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #chk a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLISTS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando ítems de inspección'

/* Referencias a una pauta: codigo (con o sin PAU-) o nombre. */
CREATE TABLE #cref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #cref SELECT cpl_codigo, cpl_id, NULL FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_habilitado = 1
INSERT INTO #cref SELECT SUBSTRING(cpl_codigo, 5, 100), cpl_id, NULL FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_habilitado = 1 AND cpl_codigo LIKE N'PAU-%'
INSERT INTO #cref SELECT cpl_nombre, cpl_id, NULL FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_habilitado = 1
INSERT INTO #cref SELECT cod_final, id, fila FROM #chk WHERE err = 0 AND cod_final IS NOT NULL
INSERT INTO #cref SELECT codigo, id, fila FROM #chk WHERE err = 0 AND codigo IS NOT NULL
INSERT INTO #cref SELECT nombre, id, fila FROM #chk WHERE err = 0 AND nombre IS NOT NULL

/* ======================================================================
   5. CHECKLIST ITEMS
   ====================================================================== */
CREATE TABLE #cit (fila INT PRIMARY KEY, checklist NVARCHAR(400) COLLATE Latin1_General_CI_AI, seccion NVARCHAR(200) COLLATE Latin1_General_CI_AI, codigo NVARCHAR(50) COLLATE Latin1_General_CI_AI, texto NVARCHAR(500) COLLATE Latin1_General_CI_AI,
    tipo NVARCHAR(100) COLLATE Latin1_General_CI_AI, orden_t NVARCHAR(10) COLLATE Latin1_General_CI_AI, obl NVARCHAR(10) COLLATE Latin1_General_CI_AI, com NVARCHAR(10) COLLATE Latin1_General_CI_AI, evid NVARCHAR(10) COLLATE Latin1_General_CI_AI, unidad NVARCHAR(100) COLLATE Latin1_General_CI_AI,
    chk_id INT, chk_fila INT, tipo_id INT, orden INT, uni_id INT, existe BIT NOT NULL DEFAULT 0, cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #cit (fila, checklist, seccion, codigo, texto, tipo, orden_t, obl, com, evid, unidad)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.checklist)), N''), NULLIF(LTRIM(RTRIM(j.seccion)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.texto)), N''),
       NULLIF(LTRIM(RTRIM(j.tipo)), N''), NULLIF(LTRIM(RTRIM(j.orden)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.obl))), N''), NULLIF(UPPER(LTRIM(RTRIM(j.com))), N''),
       NULLIF(UPPER(LTRIM(RTRIM(j.evid))), N''), NULLIF(LTRIM(RTRIM(j.unidad)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (checklist NVARCHAR(400) '$.CHECKLIST', seccion NVARCHAR(200) '$.SECCION', codigo NVARCHAR(50) '$.CODIGO', texto NVARCHAR(500) '$.TEXTO',
        tipo NVARCHAR(100) '$.TIPO', orden NVARCHAR(10) '$.ORDEN', obl NVARCHAR(10) '$.OBLIGATORIO', com NVARCHAR(10) '$.COMENTARIO', evid NVARCHAR(10) '$.EVIDENCIA',
        unidad NVARCHAR(100) '$.UNIDAD') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLIST_ITEMS'
UPDATE t SET chk_id = x.id, chk_fila = x.fila FROM #cit t CROSS APPLY (SELECT TOP 1 id, fila FROM #cref WHERE clave = t.checklist ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.checklist IS NOT NULL
UPDATE t SET tipo_id = x.cit_id FROM #cit t CROSS APPLY (SELECT TOP 1 cit_id FROM [dbo].[Checklist_Item_Tipo] WHERE cit_habilitado = 1
       AND (cit_nombre COLLATE Latin1_General_CI_AI = t.tipo OR cit_codigo COLLATE Latin1_General_CI_AI = t.tipo)) x WHERE t.tipo IS NOT NULL
UPDATE #cit SET tipo_id = (SELECT cit_id FROM [dbo].[Checklist_Item_Tipo] WHERE cit_codigo = 'TEXTO CORTO') WHERE tipo IS NULL
UPDATE #cit SET orden = TRY_CONVERT(INT, orden_t)
UPDATE t SET uni_id = (SELECT TOP 1 id FROM #uni WHERE clave = t.unidad) FROM #cit t WHERE t.unidad IS NOT NULL
/* Ya existe: mismo codigo (o mismo texto, si no trae codigo) en la version borrador de una pauta de la base, o en la ultima version. */
UPDATE t SET existe = 1 FROM #cit t WHERE t.chk_fila IS NULL AND t.chk_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM [dbo].[Checklist_Plantilla_Item] i
    WHERE i.cpi_habilitado = 1
      AND i.cpi_checklist_plantilla_version = ISNULL((SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = t.chk_id AND cpv_checklist_version_estado = 1 AND cpv_habilitado = 1 ORDER BY cpv_numero DESC),
                                                     (SELECT TOP 1 cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = t.chk_id AND cpv_habilitado = 1 ORDER BY cpv_numero DESC))
      AND ((t.codigo IS NOT NULL AND i.cpi_codigo COLLATE Latin1_General_CI_AI = t.codigo) OR (t.codigo IS NULL AND i.cpi_texto COLLATE Latin1_General_CI_AI = t.texto)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'INSPECCION', checklist, CASE WHEN checklist IS NULL THEN N'Falta la inspección.' ELSE N'La inspección no existe ni viene en la hoja INSPECCIONES.' END FROM #cit WHERE chk_id IS NULL AND chk_fila IS NULL
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'TEXTO', NULL, N'Falta el texto del campo (la pregunta o lo que se revisa).' FROM #cit WHERE texto IS NULL
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'TIPO', tipo, N'El tipo no existe. Use uno de la hoja TIPOS ITEM.' FROM #cit WHERE tipo IS NOT NULL AND tipo_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'ORDEN', orden_t, N'El orden es un número entero.' FROM #cit WHERE orden_t IS NOT NULL AND orden IS NULL
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'UNIDAD', unidad, N'La unidad no existe. Escríbala como en la hoja UNIDADES.' FROM #cit WHERE unidad IS NOT NULL AND uni_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', t.fila, N'UNIDAD', NULL, N'Un campo de tipo Medición necesita su unidad.' FROM #cit t
       WHERE t.uni_id IS NULL AND t.unidad IS NULL AND t.tipo_id = (SELECT cit_id FROM [dbo].[Checklist_Item_Tipo] WHERE cit_codigo = 'MEDICION')
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'OBLIGATORIO', obl, N'Escriba SI o NO.' FROM #cit WHERE obl IS NOT NULL AND obl NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'COMENTARIO', com, N'Escriba SI o NO.' FROM #cit WHERE com IS NOT NULL AND com NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', fila, N'EVIDENCIA', evid, N'Escriba SI o NO.' FROM #cit WHERE evid IS NOT NULL AND evid NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', a.fila, N'CODIGO', a.codigo, N'El código se repite en esa inspección (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #cit a CROSS APPLY (SELECT TOP 1 fila FROM #cit x WHERE x.fila < a.fila AND x.checklist = a.checklist AND x.codigo = a.codigo ORDER BY x.fila) p WHERE a.codigo IS NOT NULL
/* Una pauta ya publicada no se modifica: sus cambios se hacen en una version nueva, desde su ficha. */
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', t.fila, N'INSPECCION', t.checklist, N'Esa inspección ya está publicada: abra una versión nueva desde su ficha para agregarle campos.'
       FROM #cit t WHERE t.chk_fila IS NULL AND t.chk_id IS NOT NULL AND t.existe = 0
         AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = t.chk_id AND cpv_checklist_version_estado = 1 AND cpv_habilitado = 1)
UNION ALL SELECT @CARGA, 'CHECKLIST_ITEMS', a.fila, N'INSPECCION', a.checklist, N'La inspección de la fila ' + LTRIM(STR(a.chk_fila)) + N' de la hoja INSPECCIONES tiene errores.'
       FROM #cit a JOIN #chk c ON c.fila = a.chk_fila WHERE a.chk_id IS NULL AND c.err = 1
UPDATE a SET err = 1 FROM #cit a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'CHECKLIST_ITEMS' AND e.cme_fila = a.fila)
UPDATE #cit SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END
UPDATE c SET items = (SELECT COUNT(*) FROM #cit i WHERE i.chk_fila = c.fila AND i.res = 'C') FROM #chk c

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando campos de inspección' WHERE cma_id = @CARGA
    UPDATE t SET chk_id = c.id FROM #cit t JOIN #chk c ON c.fila = t.chk_fila WHERE t.chk_id IS NULL AND c.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #cit WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @iChk INT, @iVer INT, @iSec NVARCHAR(200), @iSecId INT, @iSecCod NVARCHAR(50), @iSecOrd INT, @iCod NVARCHAR(50), @iTexto NVARCHAR(500), @iTipo INT, @iOrd INT, @iUni INT,
                    @iObl BIT, @iCom BIT, @iEv BIT, @iCnt INT
            SELECT @iChk = chk_id, @iSec = seccion, @iCod = codigo, @iTexto = texto, @iTipo = tipo_id, @iOrd = orden, @iUni = uni_id,
                   @iObl = CASE WHEN obl = N'NO' THEN 0 ELSE 1 END, @iCom = CASE WHEN com = N'NO' THEN 0 ELSE 1 END, @iEv = CASE WHEN evid IN (N'SI', N'SÍ') THEN 1 ELSE 0 END
            FROM #cit WHERE fila = @f
            IF @iChk IS NULL RAISERROR(N'La inspección no se pudo crear.', 16, 1)
            SELECT TOP 1 @iVer = cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @iChk AND cpv_checklist_version_estado = 1 AND cpv_habilitado = 1 ORDER BY cpv_numero DESC
            IF @iVer IS NULL RAISERROR(N'Esa inspección ya está publicada: abra una versión nueva desde su ficha.', 16, 1)
            SET @iSecId = NULL
            IF @iSec IS NOT NULL
            BEGIN
                SELECT TOP 1 @iSecId = cps_id FROM [dbo].[Checklist_Plantilla_Seccion]
                 WHERE cps_checklist_plantilla_version = @iVer AND cps_habilitado = 1 AND cps_nombre COLLATE Latin1_General_CI_AI = @iSec ORDER BY cps_id
                IF @iSecId IS NULL
                BEGIN
                    SELECT @iCnt = COUNT(*) FROM [dbo].[Checklist_Plantilla_Seccion] WHERE cps_checklist_plantilla_version = @iVer
                    SET @iSecCod = N'SEC-' + RIGHT(N'000' + CAST(@iCnt + 1 AS NVARCHAR(10)), 3)
                    SET @iSecOrd = @iCnt + 1
                    SET @nuevo = NULL
                    EXEC [dbo].[INS_CHECKLIST_SECCION] @ID = @nuevo OUTPUT, @VERSION = @iVer, @CODIGO = @iSecCod, @NOMBRE = @iSec, @ORDEN = @iSecOrd, @USUARIO = @USUARIO
                    SET @iSecId = @nuevo
                END
            END
            SELECT @iCnt = COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_checklist_plantilla_version = @iVer
            IF @iOrd IS NULL SET @iOrd = @iCnt + 1
            IF @iCod IS NULL
            BEGIN
                SET @iCod = N'C' + RIGHT(N'000' + CAST(@iCnt + 1 AS NVARCHAR(10)), 3)
                WHILE EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item] WHERE cpi_checklist_plantilla_version = @iVer AND cpi_codigo = @iCod)
                    SET @iCod = N'C' + RIGHT(N'000' + CAST(TRY_CONVERT(INT, SUBSTRING(@iCod, 2, 10)) + 1 AS NVARCHAR(10)), 3)
            END
            SET @nuevo = NULL
            EXEC [dbo].[INS_CHECKLIST_ITEM] @ID = @nuevo OUTPUT, @VERSION = @iVer, @SECCION = @iSecId, @CODIGO = @iCod, @TEXTO = @iTexto, @TIPO = @iTipo,
                 @ORDEN = @iOrd, @OBLIGATORIO = @iObl, @PERMITE_COMENTARIO = @iCom, @REQUIERE_EVIDENCIA = @iEv, @UNIDAD = @iUni, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'CHECKLIST_ITEMS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'CHECKLIST_ITEMS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #cit SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END

    /* Publicar las pautas NUEVAS de esta carga: una pauta en borrador no se puede programar. */
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Publicando inspecciones' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #chk WHERE fila > @f AND res = 'C' AND ISNULL(publicar, N'SI') <> N'NO'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @pubId INT, @pubVer INT
            SELECT @pubId = id FROM #chk WHERE fila = @f
            IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item] i JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
                            WHERE v.cpv_checklist_plantilla = @pubId AND v.cpv_checklist_version_estado = 1 AND i.cpi_habilitado = 1)
                RAISERROR(N'Quedó en borrador: no tiene campos en la hoja ITEMS DE INSPECCION (una inspección sin campos no se publica).', 16, 1)
            SET @pubVer = NULL
            EXEC [dbo].[PUBLICAR_CHECKLIST_VERSION] @PLANTILLA = @pubId, @CLIENTE = @CLIENTE, @OBSERVACION = N'Carga de datos', @USUARIO = @USUARIO, @VERSION = @pubVer OUTPUT
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_mensaje) VALUES (@CARGA, 'CHECKLISTS', @f, N'PUBLICAR', [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #chk SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #cit a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLIST_ITEMS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
UPDATE f SET cmf_resultado = 'E' FROM [dbo].[Carga_Masiva_Fila] f JOIN #chk a ON a.fila = f.cmf_fila WHERE f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLISTS' AND a.res = 'E'
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando inspecciones programadas'

/* ======================================================================
   6. CHECKLISTS PROGRAMADOS
   ====================================================================== */
CREATE TABLE #cpg (fila INT PRIMARY KEY, checklist NVARCHAR(400) COLLATE Latin1_General_CI_AI, frecuencia NVARCHAR(400) COLLATE Latin1_General_CI_AI, equipo NVARCHAR(400) COLLATE Latin1_General_CI_AI, area NVARCHAR(400) COLLATE Latin1_General_CI_AI,
    grupo NVARCHAR(300) COLLATE Latin1_General_CI_AI, responsable NVARCHAR(300) COLLATE Latin1_General_CI_AI, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI,
    chk_id INT, chk_fila INT, fre_id INT, fre_fila INT, act_id INT, are_id INT, grp_id INT, usr_id INT, existe BIT NOT NULL DEFAULT 0,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #cpg (fila, checklist, frecuencia, equipo, area, grupo, responsable, nombre)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.checklist)), N''), NULLIF(LTRIM(RTRIM(j.frecuencia)), N''), NULLIF(LTRIM(RTRIM(j.equipo)), N''), NULLIF(LTRIM(RTRIM(j.area)), N''),
       NULLIF(LTRIM(RTRIM(j.grupo)), N''), NULLIF(LTRIM(RTRIM(j.responsable)), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (checklist NVARCHAR(400) '$.CHECKLIST', frecuencia NVARCHAR(400) '$.FRECUENCIA', equipo NVARCHAR(400) '$.EQUIPO', area NVARCHAR(400) '$.AREA',
        grupo NVARCHAR(300) '$.GRUPO', responsable NVARCHAR(300) '$.RESPONSABLE', nombre NVARCHAR(400) '$.NOMBRE') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLISTS_PROGRAMADOS'
UPDATE t SET chk_id = x.id, chk_fila = x.fila FROM #cpg t CROSS APPLY (SELECT TOP 1 id, fila FROM #cref WHERE clave = t.checklist ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.checklist IS NOT NULL
UPDATE t SET fre_id = x.id, fre_fila = x.fila FROM #cpg t CROSS APPLY (SELECT TOP 1 id, fila FROM #fref WHERE clave = t.frecuencia ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.frecuencia IS NOT NULL
UPDATE t SET act_id = (SELECT TOP 1 id FROM #act WHERE clave = t.equipo ORDER BY id) FROM #cpg t WHERE t.equipo IS NOT NULL
UPDATE t SET are_id = (SELECT TOP 1 id FROM #are WHERE clave = t.area ORDER BY id) FROM #cpg t WHERE t.area IS NOT NULL
UPDATE t SET grp_id = (SELECT TOP 1 id FROM #grp WHERE clave = t.grupo) FROM #cpg t WHERE t.grupo IS NOT NULL
UPDATE t SET usr_id = (SELECT TOP 1 id FROM #usr WHERE clave = t.responsable) FROM #cpg t WHERE t.responsable IS NOT NULL
UPDATE t SET existe = 1 FROM #cpg t WHERE t.chk_fila IS NULL AND t.chk_id IS NOT NULL AND t.fre_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM [dbo].[Checklist_Programacion] c JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = c.cpr_checklist_plantilla_version
    WHERE c.cpr_cliente = @CLIENTE AND c.cpr_habilitado = 1 AND v.cpv_checklist_plantilla = t.chk_id AND c.cpr_programacion = t.fre_id
      AND ISNULL(c.cpr_activo, 0) = ISNULL(t.act_id, 0) AND ISNULL(c.cpr_instalacion_area, 0) = ISNULL(t.are_id, 0))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'INSPECCION', checklist, CASE WHEN checklist IS NULL THEN N'Falta la inspección.' ELSE N'La inspección no existe ni viene en la hoja INSPECCIONES.' END FROM #cpg WHERE chk_id IS NULL AND chk_fila IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'FRECUENCIA', frecuencia, CASE WHEN frecuencia IS NULL THEN N'Falta la frecuencia.' ELSE N'La frecuencia no existe ni viene en la hoja FRECUENCIAS.' END FROM #cpg WHERE fre_id IS NULL AND fre_fila IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'EQUIPO', equipo, N'Indique el equipo o el área donde se hace la inspección.' FROM #cpg WHERE equipo IS NULL AND area IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'EQUIPO', equipo, N'El equipo no existe. Escriba su código o nombre como en la hoja ACTIVOS EXISTENTES.' FROM #cpg WHERE equipo IS NOT NULL AND act_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'AREA', area, N'El área no existe. Escríbala como en la hoja AREAS.' FROM #cpg WHERE area IS NOT NULL AND are_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'GRUPO', grupo, N'El grupo de trabajo no existe. Escríbalo como en la hoja GRUPOS.' FROM #cpg WHERE grupo IS NOT NULL AND grp_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', fila, N'RESPONSABLE', responsable, N'La persona no es usuaria de esta empresa. Escriba su correo como en la hoja PERSONAS.' FROM #cpg WHERE responsable IS NOT NULL AND usr_id IS NULL
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', a.fila, N'INSPECCION', a.checklist, N'La inspección de la fila ' + LTRIM(STR(a.chk_fila)) + N' de la hoja INSPECCIONES tiene errores.'
       FROM #cpg a JOIN #chk c ON c.fila = a.chk_fila WHERE a.chk_id IS NULL AND c.err = 1
UNION ALL SELECT @CARGA, 'CHECKLISTS_PROGRAMADOS', a.fila, N'FRECUENCIA', a.frecuencia, N'La frecuencia de la fila ' + LTRIM(STR(a.fre_fila)) + N' de la hoja FRECUENCIAS tiene errores.'
       FROM #cpg a JOIN #fre c ON c.fila = a.fre_fila WHERE a.fre_id IS NULL AND c.err = 1
UPDATE a SET err = 1 FROM #cpg a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'CHECKLISTS_PROGRAMADOS' AND e.cme_fila = a.fila)
UPDATE #cpg SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Programando inspecciones' WHERE cma_id = @CARGA
    UPDATE t SET chk_id = r.id FROM #cpg t JOIN #chk r ON r.fila = t.chk_fila WHERE t.chk_id IS NULL AND r.id IS NOT NULL
    UPDATE t SET fre_id = r.id FROM #cpg t JOIN #fre r ON r.fila = t.fre_fila WHERE t.fre_id IS NULL AND r.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #cpg WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @gChk INT, @gFre INT, @gAct INT, @gAre INT, @gGrp INT, @gUsr INT, @gNom NVARCHAR(400)
            SELECT @gChk = chk_id, @gFre = fre_id, @gAct = act_id, @gAre = are_id, @gGrp = grp_id, @gUsr = usr_id,
                   @gNom = ISNULL(nombre, LEFT(checklist + N' · ' + ISNULL(equipo, area), 400)) FROM #cpg WHERE fila = @f
            IF @gChk IS NULL RAISERROR(N'La inspección no se pudo crear.', 16, 1)
            IF @gFre IS NULL RAISERROR(N'La frecuencia no se pudo crear.', 16, 1)
            SET @nuevo = NULL
            EXEC [dbo].[INS_CHECKLIST_PROGRAMACION] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CHECKLIST_PLANTILLA = @gChk, @PROGRAMACION = @gFre, @ACTIVO = @gAct,
                 @INSTALACION_AREA = @gAre, @GRUPO_TRABAJO = @gGrp, @USUARIO_RESPONSABLE = @gUsr, @NOMBRE = @gNom, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'CHECKLISTS_PROGRAMADOS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'CHECKLISTS_PROGRAMADOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #cpg SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #cpg a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'CHECKLISTS_PROGRAMADOS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando planes'

/* ======================================================================
   7. PLANES
   ====================================================================== */
CREATE TABLE #pln (fila INT PRIMARY KEY, codigo NVARCHAR(100) COLLATE Latin1_General_CI_AI, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI, descripcion NVARCHAR(MAX) COLLATE Latin1_General_CI_AI,
    planta NVARCHAR(400) COLLATE Latin1_General_CI_AI, planificador NVARCHAR(300) COLLATE Latin1_General_CI_AI, tipo NVARCHAR(400) COLLATE Latin1_General_CI_AI, modelo NVARCHAR(400) COLLATE Latin1_General_CI_AI, activar NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    cod_final NVARCHAR(100) COLLATE Latin1_General_CI_AI, planta_id INT, usr_id INT, tipo_id INT, modelo_id INT, id INT,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #pln (fila, codigo, nombre, descripcion, planta, planificador, tipo, modelo, activar)
SELECT f.cmf_fila, NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(LTRIM(RTRIM(j.planta)), N''),
       NULLIF(LTRIM(RTRIM(j.planificador)), N''), NULLIF(LTRIM(RTRIM(j.tipo)), N''), NULLIF(LTRIM(RTRIM(j.modelo)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.activar))), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', descripcion NVARCHAR(MAX) '$.DESCRIPCION', planta NVARCHAR(400) '$.PLANTA',
        planificador NVARCHAR(300) '$.PLANIFICADOR', tipo NVARCHAR(400) '$.TIPO_ACTIVO', modelo NVARCHAR(400) '$.MODELO', activar NVARCHAR(10) '$.ACTIVAR') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'PLANES'
UPDATE #pln SET cod_final = CASE WHEN codigo IS NULL THEN NULL WHEN codigo LIKE N'PMA-%' THEN codigo ELSE N'PMA-' + codigo END
UPDATE t SET planta_id = x.id FROM #pln t CROSS APPLY (SELECT TOP 1 id FROM #pla WHERE clave = t.planta ORDER BY id) x WHERE t.planta IS NOT NULL
UPDATE t SET usr_id = (SELECT TOP 1 id FROM #usr WHERE clave = t.planificador) FROM #pln t WHERE t.planificador IS NOT NULL
UPDATE t SET tipo_id = x.ati_id FROM #pln t CROSS APPLY (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ISNULL(ati_habilitado, 1) = 1
       AND ati_nombre COLLATE Latin1_General_CI_AI = t.tipo ORDER BY ati_id) x WHERE t.tipo IS NOT NULL
UPDATE t SET modelo_id = x.amo_id FROM #pln t CROSS APPLY (SELECT TOP 1 amo_id FROM [dbo].[Activo_Modelo] WHERE amo_cliente = @CLIENTE AND ISNULL(amo_habilitado, 1) = 1
       AND amo_activo_tipo = t.tipo_id AND amo_nombre COLLATE Latin1_General_CI_AI = t.modelo ORDER BY amo_id) x WHERE t.modelo IS NOT NULL AND t.tipo_id IS NOT NULL
UPDATE t SET id = x.pma_id FROM #pln t CROSS APPLY (SELECT TOP 1 pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1
       AND ((t.cod_final IS NOT NULL AND pma_codigo COLLATE Latin1_General_CI_AI = t.cod_final)
         OR (t.cod_final IS NULL AND pma_nombre COLLATE Latin1_General_CI_AI = t.nombre)) ORDER BY pma_id) x

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'PLANES', fila, N'NOMBRE', NULL, N'Falta el nombre del plan.' FROM #pln WHERE id IS NULL AND nombre IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'PLANTA', planta, N'La planta no existe. Escríbala como en la hoja PLANTAS.' FROM #pln WHERE planta IS NOT NULL AND planta_id IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'PLANIFICADOR', planificador, N'La persona no es usuaria de esta empresa. Escriba su correo como en la hoja PERSONAS.' FROM #pln WHERE planificador IS NOT NULL AND usr_id IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'TIPO ACTIVO', tipo, N'El tipo de activo no existe. Escríbalo como en la hoja TIPOS Y MODELOS.' FROM #pln WHERE tipo IS NOT NULL AND tipo_id IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'MODELO', modelo, N'El modelo no existe en ese tipo de activo (hoja TIPOS Y MODELOS).' FROM #pln WHERE modelo IS NOT NULL AND tipo_id IS NOT NULL AND modelo_id IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'MODELO', modelo, N'Para elegir un modelo, indique también el tipo de activo.' FROM #pln WHERE modelo IS NOT NULL AND tipo IS NULL
UNION ALL SELECT @CARGA, 'PLANES', fila, N'ACTIVAR', activar, N'Escriba SI o NO.' FROM #pln WHERE activar IS NOT NULL AND activar NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'PLANES', a.fila, N'CODIGO', a.codigo, N'El código se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #pln a CROSS APPLY (SELECT TOP 1 fila FROM #pln x WHERE x.cod_final = a.cod_final AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NOT NULL
UNION ALL SELECT @CARGA, 'PLANES', a.fila, N'NOMBRE', a.nombre, N'El plan se repite en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #pln a CROSS APPLY (SELECT TOP 1 fila FROM #pln x WHERE x.cod_final IS NULL AND x.nombre = a.nombre AND x.fila < a.fila ORDER BY x.fila) p WHERE a.cod_final IS NULL AND a.nombre IS NOT NULL
UPDATE a SET err = 1 FROM #pln a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'PLANES' AND e.cme_fila = a.fila)
UPDATE #pln SET res = CASE WHEN err = 1 THEN 'E' WHEN id IS NULL THEN 'C' WHEN @OMITIR = 1 THEN 'O' ELSE 'A' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando planes' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #pln WHERE fila > @f AND res IN ('C', 'A')
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @mCod NVARCHAR(100), @mNom NVARCHAR(400), @mDes NVARCHAR(MAX), @mPla INT, @mUsr INT, @mTipo INT, @mMod INT
            SELECT @id = id, @mCod = ISNULL(cod_final, N'AUTO'), @mNom = nombre, @mDes = descripcion, @mPla = planta_id, @mUsr = usr_id, @mTipo = tipo_id, @mMod = modelo_id FROM #pln WHERE fila = @f
            IF @id IS NULL
            BEGIN
                SET @nuevo = NULL
                EXEC [dbo].[INS_PLAN_MANTENIMIENTO] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @mPla, @CODIGO = @mCod, @NOMBRE = @mNom,
                     @DESCRIPCION = @mDes, @USUARIO_PLANIFICADOR = @mUsr, @ACTIVO_TIPO = @mTipo, @ACTIVO_MODELO = @mMod, @USUARIO = @USUARIO
                SET @id = @nuevo
            END
            ELSE
                EXEC [dbo].[UPD_PLAN_MANTENIMIENTO] @ID = @id, @CLIENTE_INSTALACION = @mPla, @NOMBRE = @mNom, @DESCRIPCION = @mDes, @USUARIO_PLANIFICADOR = @mUsr,
                     @ACTIVO_TIPO = @mTipo, @ACTIVO_MODELO = @mMod, @USUARIO = @USUARIO
            UPDATE #pln SET id = @id, cmf = 1 WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = (SELECT res FROM #pln WHERE fila = @f), cmf_id = @id
            WHERE  cmf_carga = @CARGA AND cmf_hoja = 'PLANES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'PLANES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #pln SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res, cmf_id = ISNULL(f.cmf_id, a.id)
FROM   [dbo].[Carga_Masiva_Fila] f JOIN #pln a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'PLANES' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando hitos'

CREATE TABLE #pref (clave NVARCHAR(400) COLLATE Latin1_General_CI_AI, id INT, fila INT)
INSERT INTO #pref SELECT pma_codigo, pma_id, NULL FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1
INSERT INTO #pref SELECT SUBSTRING(pma_codigo, 5, 100), pma_id, NULL FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1 AND pma_codigo LIKE N'PMA-%'
INSERT INTO #pref SELECT pma_nombre, pma_id, NULL FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1
INSERT INTO #pref SELECT cod_final, id, fila FROM #pln WHERE err = 0 AND cod_final IS NOT NULL
INSERT INTO #pref SELECT codigo, id, fila FROM #pln WHERE err = 0 AND codigo IS NOT NULL
INSERT INTO #pref SELECT nombre, id, fila FROM #pln WHERE err = 0 AND nombre IS NOT NULL

/* ======================================================================
   8. HITOS (intervenciones)
   ====================================================================== */
CREATE TABLE #hit (fila INT PRIMARY KEY, plan_t NVARCHAR(400) COLLATE Latin1_General_CI_AI, codigo NVARCHAR(100) COLLATE Latin1_General_CI_AI, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI, orden_t NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    frecuencia NVARCHAR(400) COLLATE Latin1_General_CI_AI, dur_t NVARCHAR(20) COLLATE Latin1_General_CI_AI, parada NVARCHAR(10) COLLATE Latin1_General_CI_AI, overhaul NVARCHAR(10) COLLATE Latin1_General_CI_AI, tipo_ot NVARCHAR(100) COLLATE Latin1_General_CI_AI, prio_ot NVARCHAR(100) COLLATE Latin1_General_CI_AI,
    responsable NVARCHAR(300) COLLATE Latin1_General_CI_AI, grupo NVARCHAR(300) COLLATE Latin1_General_CI_AI, descripcion NVARCHAR(MAX) COLLATE Latin1_General_CI_AI,
    plan_id INT, plan_fila INT, fre_id INT, fre_fila INT, orden INT, dur INT, tipo_id INT, prio_id INT, usr_id INT, grp_id INT, existe BIT NOT NULL DEFAULT 0, id INT,
    cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #hit (fila, plan_t, codigo, nombre, orden_t, frecuencia, dur_t, parada, overhaul, tipo_ot, prio_ot, responsable, grupo, descripcion)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.plan_t)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''), NULLIF(LTRIM(RTRIM(j.orden)), N''),
       NULLIF(LTRIM(RTRIM(j.frecuencia)), N''), NULLIF(LTRIM(RTRIM(j.dur)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.parada))), N''), NULLIF(UPPER(LTRIM(RTRIM(j.overhaul))), N''),
       NULLIF(LTRIM(RTRIM(j.tipo_ot)), N''), NULLIF(LTRIM(RTRIM(j.prio_ot)), N''), NULLIF(LTRIM(RTRIM(j.responsable)), N''), NULLIF(LTRIM(RTRIM(j.grupo)), N''), NULLIF(LTRIM(RTRIM(j.descripcion)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (plan_t NVARCHAR(400) '$.PLAN', codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE', orden NVARCHAR(10) '$.ORDEN',
        frecuencia NVARCHAR(400) '$.FRECUENCIA', dur NVARCHAR(20) '$.DURACION_MIN', parada NVARCHAR(10) '$.PARADA', overhaul NVARCHAR(10) '$.OVERHAUL', tipo_ot NVARCHAR(100) '$.TIPO_OT',
        prio_ot NVARCHAR(100) '$.PRIORIDAD_OT', responsable NVARCHAR(300) '$.RESPONSABLE', grupo NVARCHAR(300) '$.GRUPO', descripcion NVARCHAR(MAX) '$.DESCRIPCION') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'HITOS'
UPDATE t SET plan_id = x.id, plan_fila = x.fila FROM #hit t CROSS APPLY (SELECT TOP 1 id, fila FROM #pref WHERE clave = t.plan_t ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.plan_t IS NOT NULL
UPDATE t SET fre_id = x.id, fre_fila = x.fila FROM #hit t CROSS APPLY (SELECT TOP 1 id, fila FROM #fref WHERE clave = t.frecuencia ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.frecuencia IS NOT NULL
UPDATE #hit SET orden = TRY_CONVERT(INT, orden_t), dur = TRY_CONVERT(INT, dur_t)
UPDATE t SET tipo_id = x.ott_id FROM #hit t CROSS APPLY (SELECT TOP 1 ott_id FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_habilitado = 1
       AND (ott_nombre COLLATE Latin1_General_CI_AI = t.tipo_ot OR ott_codigo COLLATE Latin1_General_CI_AI = t.tipo_ot)) x WHERE t.tipo_ot IS NOT NULL
UPDATE t SET prio_id = x.opr_id FROM #hit t CROSS APPLY (SELECT TOP 1 opr_id FROM [dbo].[Orden_Trabajo_Prioridad] WHERE opr_habilitado = 1
       AND (opr_nombre COLLATE Latin1_General_CI_AI = t.prio_ot OR opr_codigo COLLATE Latin1_General_CI_AI = t.prio_ot)) x WHERE t.prio_ot IS NOT NULL
UPDATE t SET usr_id = (SELECT TOP 1 id FROM #usr WHERE clave = t.responsable) FROM #hit t WHERE t.responsable IS NOT NULL
UPDATE t SET grp_id = (SELECT TOP 1 id FROM #grp WHERE clave = t.grupo) FROM #hit t WHERE t.grupo IS NOT NULL
/* Ya existe: ese codigo en la version del plan (el borrador, o la ultima si no hay). */
UPDATE t SET existe = 1 FROM #hit t WHERE t.plan_fila IS NULL AND t.plan_id IS NOT NULL AND t.codigo IS NOT NULL AND EXISTS (
    SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h
    WHERE h.pmh_habilitado = 1 AND h.pmh_codigo COLLATE Latin1_General_CI_AI = t.codigo
      AND h.pmh_plan_mantenimiento_version = ISNULL((SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC),
                                                    (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'HITOS', fila, N'PLAN', plan_t, CASE WHEN plan_t IS NULL THEN N'Falta el plan.' ELSE N'El plan no existe ni viene en la hoja PLANES.' END FROM #hit WHERE plan_id IS NULL AND plan_fila IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'NOMBRE', NULL, N'Falta el nombre de la intervención.' FROM #hit WHERE existe = 0 AND nombre IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'FRECUENCIA', frecuencia, CASE WHEN frecuencia IS NULL THEN N'Falta la frecuencia: sin ella el plan no se puede activar.' ELSE N'La frecuencia no existe ni viene en la hoja FRECUENCIAS.' END
       FROM #hit WHERE existe = 0 AND fre_id IS NULL AND fre_fila IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'ORDEN', orden_t, N'El orden es un número entero.' FROM #hit WHERE orden_t IS NOT NULL AND orden IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'DURACION MIN', dur_t, N'La duración son minutos, un número entero mayor que cero.' FROM #hit WHERE dur_t IS NOT NULL AND (dur IS NULL OR dur < 1)
UNION ALL SELECT @CARGA, 'HITOS', fila, N'TIPO OT', tipo_ot, N'El tipo de OT no existe. Use uno de la hoja TIPOS OT.' FROM #hit WHERE tipo_ot IS NOT NULL AND tipo_id IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'PRIORIDAD OT', prio_ot, N'La prioridad de OT no existe. Use una de la hoja PRIORIDADES OT.' FROM #hit WHERE prio_ot IS NOT NULL AND prio_id IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'RESPONSABLE', responsable, N'La persona no es usuaria de esta empresa. Escriba su correo como en la hoja PERSONAS.' FROM #hit WHERE responsable IS NOT NULL AND usr_id IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'GRUPO', grupo, N'El grupo de trabajo no existe. Escríbalo como en la hoja GRUPOS.' FROM #hit WHERE grupo IS NOT NULL AND grp_id IS NULL
UNION ALL SELECT @CARGA, 'HITOS', fila, N'PARADA', parada, N'Escriba SI o NO.' FROM #hit WHERE parada IS NOT NULL AND parada NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'HITOS', fila, N'OVERHAUL', overhaul, N'Escriba SI o NO.' FROM #hit WHERE overhaul IS NOT NULL AND overhaul NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'HITOS', a.fila, N'CODIGO', a.codigo, N'El código se repite en ese plan (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #hit a CROSS APPLY (SELECT TOP 1 fila FROM #hit x WHERE x.fila < a.fila AND x.plan_t = a.plan_t AND x.codigo = a.codigo ORDER BY x.fila) p WHERE a.codigo IS NOT NULL
UNION ALL SELECT @CARGA, 'HITOS', a.fila, N'PLAN', a.plan_t, N'El plan de la fila ' + LTRIM(STR(a.plan_fila)) + N' de la hoja PLANES tiene errores.'
       FROM #hit a JOIN #pln c ON c.fila = a.plan_fila WHERE a.plan_id IS NULL AND c.err = 1
UNION ALL SELECT @CARGA, 'HITOS', a.fila, N'FRECUENCIA', a.frecuencia, N'La frecuencia de la fila ' + LTRIM(STR(a.fre_fila)) + N' de la hoja FRECUENCIAS tiene errores.'
       FROM #hit a JOIN #fre c ON c.fila = a.fre_fila WHERE a.fre_id IS NULL AND c.err = 1
UPDATE a SET err = 1 FROM #hit a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'HITOS' AND e.cme_fila = a.fila)
UPDATE #hit SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando hitos' WHERE cma_id = @CARGA
    UPDATE t SET plan_id = r.id FROM #hit t JOIN #pln r ON r.fila = t.plan_fila WHERE t.plan_id IS NULL AND r.id IS NOT NULL
    UPDATE t SET fre_id = r.id FROM #hit t JOIN #fre r ON r.fila = t.fre_fila WHERE t.fre_id IS NULL AND r.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #hit WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @hPlan INT, @hFre INT, @hCod NVARCHAR(100), @hNom NVARCHAR(400), @hOrd INT, @hDur INT, @hPar BIT, @hOver BIT, @hTipo INT, @hPrio INT,
                    @hUsr INT, @hGrp INT, @hDes NVARCHAR(MAX), @hCnt INT
            SELECT @hPlan = plan_id, @hFre = fre_id, @hCod = codigo, @hNom = nombre, @hOrd = orden, @hDur = dur, @hTipo = tipo_id, @hPrio = prio_id, @hUsr = usr_id, @hGrp = grp_id,
                   @hDes = descripcion, @hPar = CASE WHEN parada IN (N'SI', N'SÍ') THEN 1 ELSE 0 END, @hOver = CASE WHEN overhaul IN (N'SI', N'SÍ') THEN 1 ELSE 0 END
            FROM #hit WHERE fila = @f
            IF @hPlan IS NULL RAISERROR(N'El plan no se pudo crear.', 16, 1)
            IF @hFre IS NULL RAISERROR(N'La frecuencia no se pudo crear.', 16, 1)
            IF @hOrd IS NULL
            BEGIN
                SELECT @hCnt = COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
                 WHERE v.pmv_plan_mantenimiento = @hPlan AND v.pmv_plan_version_estado = 1 AND h.pmh_habilitado = 1
                SET @hOrd = @hCnt + 1
            END
            SET @nuevo = NULL
            EXEC [dbo].[INS_PLAN_HITO] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @hPlan, @PROGRAMACION = @hFre, @CODIGO = @hCod, @NOMBRE = @hNom, @ORDEN = @hOrd,
                 @ES_OVERHAUL = @hOver, @REQUIERE_PARADA = @hPar, @DURACION_ESTIMADA_MINUTO = @hDur, @ORDEN_TRABAJO_TIPO = @hTipo, @ORDEN_TRABAJO_PRIORIDAD = @hPrio,
                 @DESCRIPCION = @hDes, @USUARIO_RESPONSABLE = @hUsr, @GRUPO_TRABAJO = @hGrp, @USUARIO = @USUARIO
            UPDATE #hit SET id = @nuevo, cmf = 1 WHERE fila = @f
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'HITOS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'HITOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #hit SET err = 1, res = 'E', cmf = 1 WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #hit a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'HITOS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando actividades'

/* ======================================================================
   9. ACTIVIDADES de cada hito
   ====================================================================== */
CREATE TABLE #ats (fila INT PRIMARY KEY, plan_t NVARCHAR(400) COLLATE Latin1_General_CI_AI, hito NVARCHAR(100) COLLATE Latin1_General_CI_AI, codigo NVARCHAR(100) COLLATE Latin1_General_CI_AI, nombre NVARCHAR(400) COLLATE Latin1_General_CI_AI,
    descripcion NVARCHAR(MAX) COLLATE Latin1_General_CI_AI, orden_t NVARCHAR(10) COLLATE Latin1_General_CI_AI, dur_t NVARCHAR(20) COLLATE Latin1_General_CI_AI, obl NVARCHAR(10) COLLATE Latin1_General_CI_AI, parada NVARCHAR(10) COLLATE Latin1_General_CI_AI,
    plan_id INT, plan_fila INT, hito_id INT, hito_fila INT, orden INT, dur INT, existe BIT NOT NULL DEFAULT 0, cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #ats (fila, plan_t, hito, codigo, nombre, descripcion, orden_t, dur_t, obl, parada)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.plan_t)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.hito))), N''), NULLIF(UPPER(LTRIM(RTRIM(j.codigo))), N''), NULLIF(LTRIM(RTRIM(j.nombre)), N''),
       NULLIF(LTRIM(RTRIM(j.descripcion)), N''), NULLIF(LTRIM(RTRIM(j.orden)), N''), NULLIF(LTRIM(RTRIM(j.dur)), N''), NULLIF(UPPER(LTRIM(RTRIM(j.obl))), N''), NULLIF(UPPER(LTRIM(RTRIM(j.parada))), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (plan_t NVARCHAR(400) '$.PLAN', hito NVARCHAR(100) '$.HITO', codigo NVARCHAR(100) '$.CODIGO', nombre NVARCHAR(400) '$.NOMBRE',
        descripcion NVARCHAR(MAX) '$.DESCRIPCION', orden NVARCHAR(10) '$.ORDEN', dur NVARCHAR(20) '$.DURACION_MIN', obl NVARCHAR(10) '$.OBLIGATORIA', parada NVARCHAR(10) '$.PARADA') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'ACTIVIDADES'
UPDATE t SET plan_id = x.id, plan_fila = x.fila FROM #ats t CROSS APPLY (SELECT TOP 1 id, fila FROM #pref WHERE clave = t.plan_t ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.plan_t IS NOT NULL
UPDATE #ats SET orden = TRY_CONVERT(INT, orden_t), dur = TRY_CONVERT(INT, dur_t)
/* El hito: una fila de la hoja HITOS de ese plan, o uno de la version borrador (o ultima) del plan en la base. */
UPDATE t SET hito_fila = x.fila FROM #ats t CROSS APPLY (SELECT TOP 1 fila FROM #hit h WHERE h.plan_t = t.plan_t AND h.codigo = t.hito AND h.err = 0 ORDER BY fila) x WHERE t.hito IS NOT NULL
UPDATE t SET hito_id = x.pmh_id FROM #ats t CROSS APPLY (SELECT TOP 1 h.pmh_id FROM [dbo].[Plan_Mantenimiento_Hito] h
       WHERE h.pmh_habilitado = 1 AND h.pmh_codigo COLLATE Latin1_General_CI_AI = t.hito
         AND h.pmh_plan_mantenimiento_version = ISNULL((SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC),
                                                       (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_habilitado = 1 ORDER BY pmv_numero DESC))) x
       WHERE t.plan_id IS NOT NULL AND t.hito IS NOT NULL
UPDATE t SET existe = 1 FROM #ats t WHERE t.hito_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] a WHERE a.paa_plan_mantenimiento_hito = t.hito_id AND a.paa_habilitado = 1
      AND ((t.codigo IS NOT NULL AND a.paa_codigo COLLATE Latin1_General_CI_AI = t.codigo) OR (t.codigo IS NULL AND a.paa_nombre COLLATE Latin1_General_CI_AI = t.nombre)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'ACTIVIDADES', fila, N'PLAN', plan_t, CASE WHEN plan_t IS NULL THEN N'Falta el plan.' ELSE N'El plan no existe ni viene en la hoja PLANES.' END FROM #ats WHERE plan_id IS NULL AND plan_fila IS NULL
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'HITO', hito, CASE WHEN hito IS NULL THEN N'Falta el código del hito.' ELSE N'El hito no existe en ese plan ni viene en la hoja HITOS.' END FROM #ats WHERE hito_id IS NULL AND hito_fila IS NULL
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'NOMBRE', NULL, N'Falta el nombre de la actividad.' FROM #ats WHERE existe = 0 AND nombre IS NULL
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'ORDEN', orden_t, N'El orden es un número entero.' FROM #ats WHERE orden_t IS NOT NULL AND orden IS NULL
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'DURACION MIN', dur_t, N'La duración son minutos, un número entero mayor que cero.' FROM #ats WHERE dur_t IS NOT NULL AND (dur IS NULL OR dur < 1)
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'OBLIGATORIA', obl, N'Escriba SI o NO.' FROM #ats WHERE obl IS NOT NULL AND obl NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'ACTIVIDADES', fila, N'PARADA', parada, N'Escriba SI o NO.' FROM #ats WHERE parada IS NOT NULL AND parada NOT IN (N'SI', N'SÍ', N'NO')
UNION ALL SELECT @CARGA, 'ACTIVIDADES', a.fila, N'HITO', a.hito, N'El hito de la fila ' + LTRIM(STR(a.hito_fila)) + N' de la hoja HITOS tiene errores.'
       FROM #ats a JOIN #hit h ON h.fila = a.hito_fila WHERE a.hito_id IS NULL AND h.err = 1
UPDATE a SET err = 1 FROM #ats a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'ACTIVIDADES' AND e.cme_fila = a.fila)
UPDATE #ats SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Creando actividades' WHERE cma_id = @CARGA
    UPDATE t SET hito_id = h.id FROM #ats t JOIN #hit h ON h.fila = t.hito_fila WHERE t.hito_id IS NULL AND h.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #ats WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @aHito INT, @aCod NVARCHAR(100), @aNom NVARCHAR(400), @aDes NVARCHAR(MAX), @aOrd INT, @aDur INT, @aObl BIT, @aPar BIT, @aCnt INT
            SELECT @aHito = hito_id, @aCod = codigo, @aNom = nombre, @aDes = descripcion, @aOrd = orden, @aDur = dur,
                   @aObl = CASE WHEN obl = N'NO' THEN 0 ELSE 1 END, @aPar = CASE WHEN parada IN (N'SI', N'SÍ') THEN 1 ELSE 0 END FROM #ats WHERE fila = @f
            IF @aHito IS NULL RAISERROR(N'El hito no se pudo crear.', 16, 1)
            IF @aOrd IS NULL
            BEGIN
                SELECT @aCnt = COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @aHito AND paa_habilitado = 1
                SET @aOrd = @aCnt + 1
            END
            SET @nuevo = NULL
            EXEC [dbo].[INS_PLAN_ACTIVIDAD] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @HITO = @aHito, @CODIGO = @aCod, @NOMBRE = @aNom, @DESCRIPCION = @aDes, @ORDEN = @aOrd,
                 @PROCEDIMIENTO = NULL, @DURACION_ESTIMADA_MINUTO = @aDur, @OBLIGATORIA = @aObl, @REQUIERE_PARADA = @aPar, @REQUIERE_PERMISO = 0,
                 @PERMISO_TRABAJO_TIPO = NULL, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'ACTIVIDADES' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'ACTIVIDADES', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #ats SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #ats a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'ACTIVIDADES' AND (f.cmf_resultado IS NULL OR a.res = 'E')
EXEC [dbo].[PRC_CM_CONTAR] @CARGA, N'Revisando equipos de los planes'

/* ======================================================================
   10. EQUIPOS de cada plan
   ====================================================================== */
CREATE TABLE #peq (fila INT PRIMARY KEY, plan_t NVARCHAR(400) COLLATE Latin1_General_CI_AI, equipo NVARCHAR(400) COLLATE Latin1_General_CI_AI, componente NVARCHAR(400) COLLATE Latin1_General_CI_AI, medidor NVARCHAR(400) COLLATE Latin1_General_CI_AI,
    plan_id INT, plan_fila INT, act_id INT, com_id INT, med_id INT, existe BIT NOT NULL DEFAULT 0, cmf BIT NULL, err BIT NOT NULL DEFAULT 0, res CHAR(1))
INSERT INTO #peq (fila, plan_t, equipo, componente, medidor)
SELECT f.cmf_fila, NULLIF(LTRIM(RTRIM(j.plan_t)), N''), NULLIF(LTRIM(RTRIM(j.equipo)), N''), NULLIF(LTRIM(RTRIM(j.componente)), N''), NULLIF(LTRIM(RTRIM(j.medidor)), N'')
FROM   [dbo].[Carga_Masiva_Fila] f
CROSS APPLY OPENJSON(f.cmf_datos) WITH (plan_t NVARCHAR(400) '$.PLAN', equipo NVARCHAR(400) '$.EQUIPO', componente NVARCHAR(400) '$.COMPONENTE', medidor NVARCHAR(400) '$.MEDIDOR') j
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'EQUIPOS'
UPDATE t SET plan_id = x.id, plan_fila = x.fila FROM #peq t CROSS APPLY (SELECT TOP 1 id, fila FROM #pref WHERE clave = t.plan_t ORDER BY CASE WHEN fila IS NULL THEN 0 ELSE 1 END) x WHERE t.plan_t IS NOT NULL
UPDATE t SET act_id = (SELECT TOP 1 id FROM #act WHERE clave = t.equipo ORDER BY id) FROM #peq t WHERE t.equipo IS NOT NULL
UPDATE t SET com_id = (SELECT TOP 1 aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = t.act_id AND aco_habilitado = 1 AND aco_nombre COLLATE Latin1_General_CI_AI = t.componente ORDER BY aco_id)
FROM #peq t WHERE t.componente IS NOT NULL AND t.act_id IS NOT NULL
UPDATE t SET med_id = (SELECT TOP 1 ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo = t.act_id AND ame_habilitado = 1 AND ame_nombre COLLATE Latin1_General_CI_AI = t.medidor ORDER BY ame_id)
FROM #peq t WHERE t.medidor IS NOT NULL AND t.act_id IS NOT NULL
UPDATE t SET existe = 1 FROM #peq t WHERE t.plan_fila IS NULL AND t.plan_id IS NOT NULL AND t.act_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a
    WHERE a.pac_activo = t.act_id AND ISNULL(a.pac_activo_componente, 0) = ISNULL(t.com_id, 0)
      AND a.pac_plan_mantenimiento_version = ISNULL((SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC),
                                                    (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = t.plan_id AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)))

INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_valor, cme_mensaje)
SELECT @CARGA, 'EQUIPOS', fila, N'PLAN', plan_t, CASE WHEN plan_t IS NULL THEN N'Falta el plan.' ELSE N'El plan no existe ni viene en la hoja PLANES.' END FROM #peq WHERE plan_id IS NULL AND plan_fila IS NULL
UNION ALL SELECT @CARGA, 'EQUIPOS', fila, N'EQUIPO', equipo, CASE WHEN equipo IS NULL THEN N'Falta el equipo.' ELSE N'El equipo no existe. Escriba su código o nombre como en la hoja ACTIVOS EXISTENTES.' END FROM #peq WHERE act_id IS NULL
UNION ALL SELECT @CARGA, 'EQUIPOS', fila, N'COMPONENTE', componente, N'Ese equipo no tiene un componente con ese nombre.' FROM #peq WHERE componente IS NOT NULL AND act_id IS NOT NULL AND com_id IS NULL
UNION ALL SELECT @CARGA, 'EQUIPOS', fila, N'MEDIDOR', medidor, N'Ese equipo no tiene un medidor con ese nombre.' FROM #peq WHERE medidor IS NOT NULL AND act_id IS NOT NULL AND med_id IS NULL
UNION ALL SELECT @CARGA, 'EQUIPOS', a.fila, N'EQUIPO', a.equipo, N'El equipo ya está en ese plan en la planilla (fila ' + LTRIM(STR(p.fila)) + N').'
       FROM #peq a CROSS APPLY (SELECT TOP 1 fila FROM #peq x WHERE x.fila < a.fila AND x.plan_t = a.plan_t AND x.act_id = a.act_id AND ISNULL(x.com_id, 0) = ISNULL(a.com_id, 0) ORDER BY x.fila) p WHERE a.act_id IS NOT NULL
UNION ALL SELECT @CARGA, 'EQUIPOS', a.fila, N'PLAN', a.plan_t, N'El plan de la fila ' + LTRIM(STR(a.plan_fila)) + N' de la hoja PLANES tiene errores.'
       FROM #peq a JOIN #pln c ON c.fila = a.plan_fila WHERE a.plan_id IS NULL AND c.err = 1
UPDATE a SET err = 1 FROM #peq a WHERE EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Error] e WHERE e.cme_carga = @CARGA AND e.cme_hoja = 'EQUIPOS' AND e.cme_fila = a.fila)
UPDATE #peq SET res = CASE WHEN err = 1 THEN 'E' WHEN existe = 1 THEN 'O' ELSE 'C' END

IF @CARGAR = 1
BEGIN
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Agregando equipos a los planes' WHERE cma_id = @CARGA
    UPDATE t SET plan_id = r.id FROM #peq t JOIN #pln r ON r.fila = t.plan_fila WHERE t.plan_id IS NULL AND r.id IS NOT NULL
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #peq WHERE fila > @f AND res = 'C'
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @qPlan INT, @qAct INT, @qCom INT, @qMed INT
            SELECT @qPlan = plan_id, @qAct = act_id, @qCom = com_id, @qMed = med_id FROM #peq WHERE fila = @f
            IF @qPlan IS NULL RAISERROR(N'El plan no se pudo crear.', 16, 1)
            SET @nuevo = NULL
            EXEC [dbo].[INS_PLAN_ACTIVO] @ID = @nuevo OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @qPlan, @ACTIVO = @qAct, @ACTIVO_COMPONENTE = @qCom, @ACTIVO_MEDIDOR = @qMed, @USUARIO = @USUARIO
            UPDATE [dbo].[Carga_Masiva_Fila] SET cmf_resultado = 'C', cmf_id = @nuevo WHERE cmf_carga = @CARGA AND cmf_hoja = 'EQUIPOS' AND cmf_fila = @f
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_mensaje) VALUES (@CARGA, 'EQUIPOS', @f, [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE()))
            UPDATE #peq SET err = 1, res = 'E' WHERE fila = @f
        END CATCH
        SET @n = @n + 1
        IF @n % 20 = 0 EXEC [dbo].[PRC_CM_CONTAR] @CARGA
    END

    /* ---- Activar los planes que lo piden (ACTIVAR = SI): publica la version y genera las ocurrencias. ---- */
    UPDATE [dbo].[Carga_Masiva] SET cma_fase = N'Activando planes' WHERE cma_id = @CARGA
    SET @f = 0
    WHILE 1 = 1
    BEGIN
        SELECT @f = MIN(fila) FROM #pln WHERE fila > @f AND res IN ('C', 'A', 'O') AND activar IN (N'SI', N'SÍ') AND id IS NOT NULL
        IF @f IS NULL BREAK
        BEGIN TRY
            DECLARE @vPlan INT
            SELECT @vPlan = id FROM #pln WHERE fila = @f
            EXEC [dbo].[UPD_PLAN_ACTIVAR] @CLIENTE = @CLIENTE, @PLAN = @vPlan, @OBSERVACION = N'Carga de datos', @HORIZONTE = 90, @USUARIO = @USUARIO
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 OR @@TRANCOUNT > @TC0 BEGIN ROLLBACK; IF @TC0 > 0 RETURN; END
            SET @msg = [dbo].[FNC_CM_MENSAJE](ERROR_MESSAGE())
            /* Un plan ya activo y sin cambios no es un error. */
            IF @msg NOT LIKE N'%no tiene cambios que aplicar%'
            BEGIN
                INSERT INTO [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila, cme_columna, cme_mensaje)
                VALUES (@CARGA, 'PLANES', @f, N'ACTIVAR', N'Quedó creado pero sin activar: ' + @msg)
                UPDATE #pln SET err = 1, res = 'E' WHERE fila = @f
            END
        END CATCH
    END
END
UPDATE f SET cmf_resultado = a.res FROM [dbo].[Carga_Masiva_Fila] f JOIN #peq a ON a.fila = f.cmf_fila
WHERE  f.cmf_carga = @CARGA AND f.cmf_hoja = 'EQUIPOS' AND (f.cmf_resultado IS NULL OR a.res = 'E')
UPDATE f SET cmf_resultado = 'E' FROM [dbo].[Carga_Masiva_Fila] f JOIN #pln a ON a.fila = f.cmf_fila WHERE f.cmf_carga = @CARGA AND f.cmf_hoja = 'PLANES' AND a.res = 'E'

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
/* Bloque 473: las ayudas de la carga de MANTENIMIENTO. */
ELSE IF @LISTA = 'FRECUENCIAS EXISTENTES'
    SELECT p.pro_nombre AS [ESCRIBA ESTO EN FRECUENCIA], t.pti_nombre AS [TIPO],
           CASE WHEN p.pro_es_privada = 1 THEN N'Propia de una intervención' ELSE N'Compartida' END AS [ALCANCE]
    FROM [dbo].[Programacion] p JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
    WHERE p.pro_cliente = @CLIENTE AND p.pro_habilitado = 1 ORDER BY p.pro_nombre
ELSE IF @LISTA = 'TAREAS EXISTENTES'
    SELECT tar_codigo AS [CODIGO], tar_titulo AS [TITULO] FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_habilitado = 1 ORDER BY tar_codigo
ELSE IF @LISTA = 'INSPECCIONES EXISTENTES'
    SELECT cpl_codigo AS [CODIGO], cpl_nombre AS [NOMBRE] FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_habilitado = 1 ORDER BY cpl_codigo
ELSE IF @LISTA = 'PLANES EXISTENTES'
    SELECT pma_codigo AS [CODIGO], pma_nombre AS [NOMBRE] FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_habilitado = 1 ORDER BY pma_codigo
ELSE IF @LISTA = 'PERSONAS'
    SELECT ISNULL(u.usu_correo, u.usu_login) AS [ESCRIBA ESTO EN RESPONSABLE (correo)], LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS [PERSONA]
    FROM [dbo].[Usuario] u JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = u.usu_id AND cu.ucl_id_cliente = @CLIENTE AND cu.ucl_habilitado = 1
    WHERE u.usu_habilitado = 1 ORDER BY u.usu_nombre
ELSE IF @LISTA = 'GRUPOS'
    SELECT gtr_nombre AS [ESCRIBA ESTO EN GRUPO], ISNULL(gtr_codigo, N'') AS [O SU CODIGO] FROM [dbo].[Grupo_Trabajo]
    WHERE gtr_cliente = @CLIENTE AND gtr_habilitado = 1 ORDER BY gtr_nombre
ELSE IF @LISTA = 'PRIORIDADES'
    SELECT tpa_nombre AS [ESCRIBA ESTO EN PRIORIDAD] FROM [dbo].[Tarea_Prioridad] WHERE tpa_habilitado = 1 ORDER BY tpa_orden
ELSE IF @LISTA = 'CATEGORIAS TAREA'
    SELECT tca_nombre AS [ESCRIBA ESTO EN CATEGORIA (o una nueva)] FROM [dbo].[Tarea_Categoria]
    WHERE (tca_cliente IS NULL OR tca_cliente = @CLIENTE) AND ISNULL(tca_habilitado, 1) = 1 ORDER BY tca_orden, tca_nombre
ELSE IF @LISTA = 'TIPOS ITEM'
    SELECT cit_nombre AS [ESCRIBA ESTO EN TIPO], cit_codigo AS [CODIGO] FROM [dbo].[Checklist_Item_Tipo] WHERE cit_habilitado = 1 ORDER BY cit_orden
ELSE IF @LISTA = 'TIPOS OT'
    SELECT ott_nombre AS [ESCRIBA ESTO EN TIPO OT] FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_habilitado = 1 ORDER BY ott_orden
ELSE IF @LISTA = 'PRIORIDADES OT'
    SELECT opr_nombre AS [ESCRIBA ESTO EN PRIORIDAD OT] FROM [dbo].[Orden_Trabajo_Prioridad] WHERE opr_habilitado = 1 ORDER BY opr_orden
ELSE IF @LISTA = 'TIPOS Y MODELOS'
    SELECT t.ati_nombre AS [TIPO ACTIVO], ISNULL(m.amo_nombre, N'') AS [MODELO] FROM [dbo].[Activo_Tipo] t
    LEFT JOIN [dbo].[Activo_Modelo] m ON m.amo_activo_tipo = t.ati_id AND ISNULL(m.amo_habilitado, 1) = 1
    WHERE t.ati_cliente = @CLIENTE AND ISNULL(t.ati_habilitado, 1) = 1 ORDER BY t.ati_nombre, m.amo_nombre


GO
PRINT '480_CARGA_INSPECCIONES aplicado.'
GO
