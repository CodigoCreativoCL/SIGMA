USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     CARGA DEL PLAN DE MANTENIMIENTO DE BLOWERS DE HAMBURGO.
-- =============================================
-- FUENTE OFICIAL DEL CLIENTE
--
--   «HAM006 PLAN ANUAL DE MANTENIMIENTO DE BLOWERS.xlsx», hojas «Equipos
--   Blowers» (ficha técnica) y «Plan de tarea» (tareas por horas de marcha).
--
-- QUE CARGA
--
--   1. Los cuatro blowers Aerzen GM10S (CB01..CB04), si aún no existen.
--   2. Un horómetro por blower (MED-CBxx-H, unidad Hora): las horas de marcha.
--   3. Un plan «PMA-BLOWERS» con un hito por nivel del plan del cliente,
--      cada uno con una programación POR MEDIDOR genérica (sin medidor fijo):
--      el disparo lo pone el horómetro de cada blower vía pac_activo_medidor.
--   4. Las actividades de cada hito, tal como las escribió el cliente.
--   5. Los cuatro blowers asociados al plan con su horómetro, y publicación.
--
-- DECISIONES
--
--   * El nivel «500 HRS» del cliente es el cambio de rodaje (una sola vez):
--     una programación por medidor es recurrente, así que no se carga como
--     hito; si se cargara, cambiaría aceite cada 500 h y contradice el 3000.
--   * El «12000 HRS» repite filtro + aceite: se carga igual, como lo pide el
--     documento.
--   * Serie de CB03 viene «1559O76» (letra O): se corrige a 1559076.
--   * Los horómetros nacen en 0: el cliente no entregó horas acumuladas.
--     Hay que cargar la lectura real de cada uno antes de que el plan proyecte.
--
--   Idempotente: busca por código antes de crear.
-- =============================================
SET NOCOUNT ON
SET XACT_ABORT ON
GO

DECLARE @CLIENTE INT = 1
/* El planificador de Hamburgo si existe; si no, el usuario de plataforma. */
DECLARE @USUARIO INT = COALESCE((SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl'),
                                 (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'root@codigocreativo.cl'))
DECLARE @PLANTA  INT = (SELECT TOP 1 cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE ORDER BY cin_id)
DECLARE @TIPO    INT = (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo]
                         WHERE ISNULL(ati_cliente, @CLIENTE) = @CLIENTE AND ati_habilitado = 1
                           AND (ati_nombre LIKE N'Soplador%' OR ati_nombre LIKE N'Blower%')
                         ORDER BY ati_id)
DECLARE @HORA    INT = 13   -- Unidad_Medida: Hora
DECLARE @ID INT, @PLAN INT, @VERSION INT, @PROG INT, @HITO INT, @ACT INT, @MED INT

IF (@USUARIO IS NULL OR @PLANTA IS NULL)
BEGIN
    RAISERROR('1.- FALTA EL USUARIO O LA PLANTA DE HAMBURGO.', 16, 1)
    RETURN
END

/* Sin tipo «Sopladores» se crea (blower = soplador), en el estilo de «Compresores». */
IF @TIPO IS NULL
BEGIN
    EXEC [dbo].[INS_ACTIVO_TIPO] @ID = @TIPO OUTPUT, @CLIENTE = @CLIENTE, @CODIGO = N'TIP-SOPLADOR',
         @NOMBRE = N'Sopladores', @DESCRIPCION = N'Sopladores de transporte neumático (harina, microingredientes, cernidor).',
         @USUARIO = @USUARIO
    SET @TIPO = (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_nombre = N'Sopladores')
END

/* -------------------------------------------------------------------------
   1) Activos y horómetros
   ------------------------------------------------------------------------- */
DECLARE @B TABLE (codigo NVARCHAR(50), nombre NVARCHAR(200), serie NVARCHAR(100), descripcion NVARCHAR(500))
INSERT INTO @B VALUES
 (N'CB01', N'Soplador 1 (blower)', N'1559766', N'Aerzen GM10S · 24,5 kW · 4800 rpm. Trabaja con líneas de harina. Motor Aerzen 30 kW 2960 rpm, rodamientos 6312-C3 / 6212-C3.'),
 (N'CB02', N'Soplador 2 (blower)', N'1559077', N'Aerzen GM10S · 24,5 kW · 4800 rpm. Trabaja con líneas de harina. Motor Aerzen 30 kW 2960 rpm, rodamientos 6312-C3 / 6212-C3.'),
 (N'CB03', N'Soplador 3 (blower)', N'1559076', N'Aerzen GM10S · 24,5 kW · 4800 rpm. Carga microingredientes. Motor Aerzen 30 kW 2960 rpm, rodamientos 6312-C3 / 6212-C3.'),
 (N'CB04', N'Soplador 4 (blower)', N'1559080', N'Aerzen GM10S · 24,5 kW · 4800 rpm. Carga cernidor. Motor Aerzen 30 kW 2960 rpm, rodamientos 6312-C3 / 6212-C3.')

DECLARE @COD NVARCHAR(50), @NOM NVARCHAR(200), @SER NVARCHAR(100), @DES NVARCHAR(500)
DECLARE @MCOD NVARCHAR(50), @MNOM NVARCHAR(200)
DECLARE cb CURSOR LOCAL FAST_FORWARD FOR SELECT codigo, nombre, serie, descripcion FROM @B ORDER BY codigo
OPEN cb
FETCH NEXT FROM cb INTO @COD, @NOM, @SER, @DES
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ACT = (SELECT TOP 1 act_id FROM [dbo].[Activo]
                 WHERE act_cliente = @CLIENTE AND (act_codigo = @COD OR act_numero_serie = @SER)
                 ORDER BY CASE WHEN act_codigo = @COD THEN 0 ELSE 1 END)
    IF @ACT IS NULL
    BEGIN
        IF @TIPO IS NULL
        BEGIN
            RAISERROR('2.- NO SE PUDO CREAR EL TIPO «Sopladores».', 16, 1)
            RETURN
        END
        EXEC [dbo].[INS_ACTIVO]
             @ID = @ACT OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
             @ACTIVO_TIPO = @TIPO, @ACTIVO_ESTADO = 1,   -- OPERATIVO
             @CRITICIDAD_NIVEL = 3,                      -- ALTA
             @CODIGO = @COD, @NOMBRE = @NOM, @NUMERO_SERIE = @SER,
             @FABRICANTE = N'Aerzen', @DESCRIPCION = @DES, @USUARIO = @USUARIO
        SET @ACT = (SELECT act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = @COD)
    END

    SET @MCOD = N'MED-' + @COD + N'-H'
    SET @MNOM = N'Horas de marcha soplador ' + RIGHT(@COD, 1)
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor] WHERE ame_cliente = @CLIENTE AND ame_codigo = @MCOD)
        EXEC [dbo].[INS_ACTIVO_MEDIDOR]
             @ID = @MED OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACT,
             @UNIDAD_MEDIDA = @HORA,
             @CODIGO = @MCOD, @NOMBRE = @MNOM,
             @VALOR_ACTUAL = 0, @VALOR_REINICIO = NULL, @PERMITE_REINICIO = 0,
             @USUARIO = @USUARIO

    FETCH NEXT FROM cb INTO @COD, @NOM, @SER, @DES
END
CLOSE cb
DEALLOCATE cb

/* -------------------------------------------------------------------------
   2) Plan
   ------------------------------------------------------------------------- */
SET @PLAN = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = N'PMA-BLOWERS')
IF @PLAN IS NULL
    EXEC [dbo].[INS_PLAN_MANTENIMIENTO]
         @ID = @PLAN OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
         @CODIGO = N'PMA-BLOWERS', @NOMBRE = N'Plan preventivo sopladores (blowers) Aerzen GM10S',
         @DESCRIPCION = N'HAM006 · Plan anual de mantenimiento de blowers de harina, por horas de marcha. Fuente: documento oficial de Hamburgo.',
         @USUARIO_PLANIFICADOR = @USUARIO, @ACTIVO_TIPO = @TIPO, @ACTIVO_MODELO = NULL,
         @USUARIO = @USUARIO
SET @PLAN = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = N'PMA-BLOWERS')

/* Ya publicado: no se toca (una nueva versión se hace desde el Centro de
   Planificación). */
IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version]
            WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 2)
BEGIN
    PRINT 'PMA-BLOWERS YA ESTA PUBLICADO: NO SE MODIFICA.'
    RETURN
END
SET @VERSION = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
                 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 ORDER BY pmv_id DESC)

/* -------------------------------------------------------------------------
   3) Hitos (uno por nivel de horas) y sus actividades
   ------------------------------------------------------------------------- */
DECLARE @H TABLE (orden INT, codigo NVARCHAR(100), nombre NVARCHAR(400), horas DECIMAL(18,2),
                  overhaul BIT, parada BIT, duracion INT, prioridad INT)
INSERT INTO @H VALUES
 (1, N'PM-3000',   N'Preventivo 3.000 h de marcha',  3000,  0, 1,  120, 2),
 (2, N'PM-6000',   N'Preventivo 6.000 h de marcha',  6000,  0, 1,  240, 2),
 (3, N'PM-9000',   N'Preventivo 9.000 h de marcha',  9000,  0, 1,  360, 3),
 (4, N'PM-12000',  N'Preventivo 12.000 h de marcha', 12000, 0, 1,  120, 2),
 (5, N'OVH-15000', N'Overhaul 15.000 h de marcha',   15000, 1, 1,  960, 3)

DECLARE @A TABLE (hito NVARCHAR(100), orden INT, nombre NVARCHAR(400), obligatoria BIT)
INSERT INTO @A VALUES
 (N'PM-3000', 1, N'Cambio de filtro de aire', 1),
 (N'PM-3000', 2, N'Cambio de aceite', 1),
 (N'PM-3000', 3, N'Cambio de retén de aceite (a evaluar)', 0),
 (N'PM-6000', 1, N'Cambio de filtro de aire', 1),
 (N'PM-6000', 2, N'Cambio de aceite', 1),
 (N'PM-6000', 3, N'Revisión de instrumentación (manómetros, vacuómetros)', 1),
 (N'PM-6000', 4, N'Cambio de retén de aceite', 1),
 (N'PM-9000', 1, N'Cambio de filtro de aire', 1),
 (N'PM-9000', 2, N'Cambio de aceite', 1),
 (N'PM-9000', 3, N'Cambio de correas', 1),
 (N'PM-9000', 4, N'Revisión de instrumentación (manómetros, vacuómetros)', 1),
 (N'PM-9000', 5, N'Mantención y calibración de válvula check', 1),
 (N'PM-9000', 6, N'Mantención y calibración de válvula de alivio', 1),
 (N'PM-12000', 1, N'Cambio de filtro de aire', 1),
 (N'PM-12000', 2, N'Cambio de aceite', 1),
 (N'OVH-15000',  1, N'Cambio de filtro de aire', 1),
 (N'OVH-15000',  2, N'Cambio de aceite', 1),
 (N'OVH-15000',  3, N'Mantención y balanceo de unidad de lóbulos', 1),
 (N'OVH-15000',  4, N'Cambio de rodamientos del soplador', 1),
 (N'OVH-15000',  5, N'Cambio de retén de aceite', 1),
 (N'OVH-15000',  6, N'Cambio de porta anillera', 1),
 (N'OVH-15000',  7, N'Cambio de anillos', 1),
 (N'OVH-15000',  8, N'Revisión de instrumentación (manómetros, vacuómetros)', 1),
 (N'OVH-15000',  9, N'Mantención del motor', 1),
 (N'OVH-15000', 10, N'Cambio de rodamientos del motor', 1),
 (N'OVH-15000', 11, N'Cambio de poleas (se evalúa caso a caso)', 0)

DECLARE @ORD INT, @HCOD NVARCHAR(100), @HNOM NVARCHAR(400), @HRS DECIMAL(18,2), @OVH BIT, @PAR BIT, @DUR INT, @PRI INT
DECLARE @PNOM NVARCHAR(200)
DECLARE ch CURSOR LOCAL FAST_FORWARD FOR SELECT orden, codigo, nombre, horas, overhaul, parada, duracion, prioridad FROM @H ORDER BY orden
OPEN ch
FETCH NEXT FROM ch INTO @ORD, @HCOD, @HNOM, @HRS, @OVH, @PAR, @DUR, @PRI
WHILE @@FETCH_STATUS = 0
BEGIN
    /* Programación por medidor, genérica: sin medidor fijo, así sirve a los
       cuatro blowers y cada uno dispara con su propio horómetro. */
    SET @PNOM = N'Sopladores cada ' + FORMAT(@HRS, N'#,0', 'es-CL') + N' h de marcha'
    SET @PROG = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = @PNOM)
    IF @PROG IS NULL
    BEGIN
        EXEC [dbo].[INS_PROGRAMACION]
             @ID = @PROG OUTPUT, @CLIENTE = @CLIENTE, @TIPO = 5,   -- MEDIDOR
             @NOMBRE = @PNOM, @FECHA_INICIO = '2026-10-10', @FECHA_FIN = NULL,
             @ZONA_HORARIA = 1, @TOLERANCIA_ANTES = 0, @TOLERANCIA_DESPUES = 10080,
             @PERMITE_ANTICIPADA = 1, @PERMITE_ATRASADA = 1, @CUMPLIMIENTO_POLITICA = 1,
             @GENERA_AUTOMATICAMENTE = 1, @INSTALACION = @PLANTA, @AREA = NULL, @ACTIVO = NULL, @GRUPO = NULL,
             @USUARIO = @USUARIO
        EXEC [dbo].[UPS_PROGRAMACION_MEDIDOR]
             @ID = @ID OUTPUT, @PROGRAMACION = @PROG, @CLIENTE = @CLIENTE,
             @ACTIVO_MEDIDOR = NULL, @VALOR_INICIAL = 0, @CADA_CANTIDAD = @HRS,
             @AVISO_ANTICIPACION = 150,   -- ~1 semana de marcha antes
             @USUARIO = @USUARIO
    END

    SET @HITO = (SELECT pmh_id FROM [dbo].[Plan_Mantenimiento_Hito]
                  WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @HCOD)
    IF @HITO IS NULL
    BEGIN
        EXEC [dbo].[INS_PLAN_HITO]
             @ID = @HITO OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN, @PROGRAMACION = @PROG,
             @CODIGO = @HCOD, @NOMBRE = @HNOM, @ORDEN = @ORD,
             @UNIDAD_MEDIDA = @HORA, @ES_OVERHAUL = @OVH, @REQUIERE_PARADA = @PAR,
             @DURACION_ESTIMADA_MINUTO = @DUR,
             @ORDEN_TRABAJO_TIPO = 1, @ORDEN_TRABAJO_PRIORIDAD = @PRI,
             @DESCRIPCION = N'Según HAM006 «Plan de tarea». Ejecutante: externo.',
             @USUARIO = @USUARIO
        SET @HITO = (SELECT pmh_id FROM [dbo].[Plan_Mantenimiento_Hito]
                      WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @HCOD)
    END

    DECLARE @AORD INT, @ANOM NVARCHAR(400), @AOBL BIT, @ACOD NVARCHAR(100)
    DECLARE ca CURSOR LOCAL FAST_FORWARD FOR SELECT orden, nombre, obligatoria FROM @A WHERE hito = @HCOD ORDER BY orden
    OPEN ca
    FETCH NEXT FROM ca INTO @AORD, @ANOM, @AOBL
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ACOD = N'ACT-' + RIGHT(N'00' + CAST(@AORD * 10 AS NVARCHAR(10)), 3)
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @HITO AND paa_codigo = @ACOD)
            EXEC [dbo].[INS_PLAN_ACTIVIDAD]
                 @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @HITO = @HITO,
                 @CODIGO = @ACOD, @NOMBRE = @ANOM, @ORDEN = @AORD,
                 @OBLIGATORIA = @AOBL, @REQUIERE_PARADA = @PAR,
                 @USUARIO = @USUARIO
        FETCH NEXT FROM ca INTO @AORD, @ANOM, @AOBL
    END
    CLOSE ca
    DEALLOCATE ca

    FETCH NEXT FROM ch INTO @ORD, @HCOD, @HNOM, @HRS, @OVH, @PAR, @DUR, @PRI
END
CLOSE ch
DEALLOCATE ch

/* -------------------------------------------------------------------------
   4) Blowers al plan, cada uno con su horómetro
   ------------------------------------------------------------------------- */
DECLARE ca2 CURSOR LOCAL FAST_FORWARD FOR
    SELECT a.act_id, m.ame_id
      FROM @B b
      JOIN [dbo].[Activo] a ON a.act_cliente = @CLIENTE AND a.act_codigo = b.codigo
      JOIN [dbo].[Activo_Medidor] m ON m.ame_cliente = @CLIENTE AND m.ame_codigo = N'MED-' + b.codigo + N'-H'
OPEN ca2
FETCH NEXT FROM ca2 INTO @ACT, @MED
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                    WHERE pac_plan_mantenimiento_version = @VERSION AND pac_activo = @ACT AND pac_activo_componente IS NULL)
        EXEC [dbo].[INS_PLAN_ACTIVO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN,
             @ACTIVO = @ACT, @ACTIVO_MEDIDOR = @MED, @USUARIO = @USUARIO
    FETCH NEXT FROM ca2 INTO @ACT, @MED
END
CLOSE ca2
DEALLOCATE ca2

/* -------------------------------------------------------------------------
   5) Publicar
   ------------------------------------------------------------------------- */
EXEC [dbo].[UPD_PLAN_VERSION_PUBLICAR] @ID = @VERSION, @CLIENTE = @CLIENTE,
     @OBSERVACION = N'Carga inicial desde HAM006 (documento oficial del cliente).', @USUARIO = @USUARIO
GO

-- ---------------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------------
SELECT  pma.pma_codigo + ' v' + CAST(pmv.pmv_numero AS VARCHAR) + ' · ' + pmh.pmh_codigo
        + ' · cada ' + CAST(CAST(pme.pme_cada_cantidad AS INT) AS VARCHAR) + ' h · '
        + CAST((SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] x WHERE x.paa_plan_mantenimiento_hito = pmh.pmh_id) AS VARCHAR)
        + ' actividades' AS RESULTADO
FROM    [dbo].[Plan_Mantenimiento] pma
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_plan_mantenimiento = pma.pma_id
JOIN    [dbo].[Plan_Mantenimiento_Hito] pmh ON pmh.pmh_plan_mantenimiento_version = pmv.pmv_id
JOIN    [dbo].[Programacion_Medidor] pme ON pme.pme_programacion = pmh.pmh_programacion
WHERE   pma.pma_cliente = 1 AND pma.pma_codigo = 'PMA-BLOWERS'
ORDER BY pmv.pmv_numero, pmh.pmh_orden
GO
SELECT HITO_NOMBRE + ' · ' + MEDIDOR_NOMBRE + ' · actual ' + CAST(CAST(VALOR_ACTUAL AS INT) AS VARCHAR)
       + ' h · próximo ' + CAST(CAST(PROXIMO AS INT) AS VARCHAR) + ' h' AS RESULTADO
FROM   [dbo].[FNC_PLAN_MEDIDOR_ESTADO](1)
WHERE  MEDIDOR_NOMBRE LIKE N'Horas de marcha soplador%'
ORDER BY MEDIDOR_NOMBRE, PROXIMO
GO
