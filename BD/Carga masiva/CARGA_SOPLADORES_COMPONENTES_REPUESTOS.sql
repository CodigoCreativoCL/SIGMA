SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     COMPONENTES Y REPUESTOS DE LOS SOPLADORES (BLOWERS) DE
--                  HAMBURGO, Y SU CONSUMO EN EL PLAN PMA-BLOWERS.
-- =============================================
-- REQUISITO: CARGA_PLAN_BLOWERS_HAMBURGO.sql (activos CB01..CB04 y el plan).
--
-- QUE CARGA
--
--   1. Árbol de componentes por soplador (mismo árbol en los cuatro):
--        Unidad de soplado (lóbulos) ─ retén de aceite, anillos, filtro de aire
--        Motor eléctrico 30 kW       ─ rodamiento 6312-C3, rodamiento 6212-C3
--        Transmisión                 ─ correas, polea motor, polea soplador
--        Válvula check, válvula de alivio, manómetro, vacuómetro
--   2. Repuestos BLW-* específicos del Aerzen GM10S, compatibles con el tipo
--      «Sopladores». Los rodamientos salen de la ficha del cliente; el resto
--      queda con especificación por confirmar (el documento no la trae).
--   3. Procedimientos PRC-BLW-01..13 con pasos (bloqueo, tarea, prueba en
--      marcha), uno por tarea. Los pasos son práctica estándar: validar con
--      Hamburgo.
--   3b. Versión 2 del plan con procedimiento y repuestos por actividad, y
--      publicación.
--   4. Stock mínimo en Bodega Piso 1 y, SOLO EN DESA, un ingreso de prueba
--      para poder cerrar una OT de punta a punta.
--
--   Idempotente: busca por código antes de crear.
-- =============================================
SET NOCOUNT ON
SET XACT_ABORT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = COALESCE((SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl'),
                                 (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'root@codigocreativo.cl'))
DECLARE @TIPO    INT = (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_codigo = N'TIP-SOPLADOR')
DECLARE @PLAN    INT = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = N'PMA-BLOWERS')
DECLARE @BODEGA  INT = (SELECT TOP 1 bod_id FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE AND bod_codigo = N'BOD-1')
DECLARE @ID INT

IF (@USUARIO IS NULL OR @TIPO IS NULL OR @PLAN IS NULL)
BEGIN
    RAISERROR('1.- CORRA CARGA_PLAN_BLOWERS_HAMBURGO.sql ANTES.', 16, 1)
    RETURN
END

/* -------------------------------------------------------------------------
   1) Repuestos
   ------------------------------------------------------------------------- */
DECLARE @R TABLE (codigo NVARCHAR(50), nombre NVARCHAR(200), tipo NVARCHAR(50), unidad INT,
                  fabricante NVARCHAR(200), modelo NVARCHAR(200), consumible BIT, vida_h DECIMAL(18,2),
                  minimo DECIMAL(18,2), descripcion NVARCHAR(500))
INSERT INTO @R VALUES
 (N'BLW-ROD-6312C3', N'Rodamiento rígido de bolas 6312-C3 60x130x31 mm', N'MEC-RODAMIENTO', 3, NULL, N'6312-C3', 0, 15000, 2,
  N'Motor del soplador Aerzen GM10S, lado acople. Dato de la ficha HAM006.'),
 (N'BLW-ROD-6212C3', N'Rodamiento rígido de bolas 6212-C3 60x110x22 mm', N'MEC-RODAMIENTO', 3, NULL, N'6212-C3', 0, 15000, 2,
  N'Motor del soplador Aerzen GM10S, lado opuesto al acople. Dato de la ficha HAM006.'),
 (N'BLW-FILTRO-AIRE', N'Elemento filtro de aire de aspiración soplador Aerzen GM10S', N'LUB-FILTRO', 3, N'Aerzen', N'GM10S', 1, 3000, 4,
  N'Se cambia en cada preventivo. Código Aerzen por confirmar con el cliente.'),
 (N'BLW-ACEITE', N'Aceite para soplador Aerzen (Delta Lube 06 o equivalente)', N'LUB-ACEITE', 6, N'Aerzen', N'Delta Lube 06', 1, 3000, 8,
  N'Cárter de engranajes y rodamientos del soplador. Volumen por confirmar con el manual del GM10S.'),
 (N'BLW-RETEN', N'Retén de aceite soplador Aerzen GM10S', N'MEC-RETEN', 3, N'Aerzen', N'GM10S', 0, 6000, 2,
  N'Medida por confirmar con el cliente.'),
 (N'BLW-CORREA', N'Juego de correas de transmisión soplador Aerzen GM10S', N'MEC-CORREA', 3, NULL, NULL, 0, 9000, 1,
  N'Perfil y largo por confirmar en terreno.'),
 (N'BLW-POLEA-MOTOR', N'Polea motor soplador Aerzen GM10S', N'MEC-POLEA', 3, NULL, NULL, 0, NULL, 0,
  N'Se cambia solo si la evaluación del overhaul lo indica.'),
 (N'BLW-POLEA-SOPLADOR', N'Polea soplador Aerzen GM10S', N'MEC-POLEA', 3, NULL, NULL, 0, NULL, 0,
  N'Se cambia solo si la evaluación del overhaul lo indica.'),
 (N'BLW-ANILLOS', N'Juego de anillos de sello soplador Aerzen GM10S', N'MEC-SELLO', 3, N'Aerzen', N'GM10S', 0, 15000, 1,
  N'Overhaul 15.000 h.'),
 (N'BLW-PORTA-ANILLERA', N'Porta anillera soplador Aerzen GM10S', N'MEC-SELLO', 3, N'Aerzen', N'GM10S', 0, 15000, 1,
  N'Overhaul 15.000 h.'),
 (N'BLW-KIT-CHECK', N'Kit de mantención válvula check soplador Aerzen', N'MEC-VALVULA', 3, N'Aerzen', NULL, 0, 9000, 1,
  N'Preventivo 9.000 h.'),
 (N'BLW-KIT-ALIVIO', N'Kit de mantención válvula de alivio soplador Aerzen', N'MEC-VALVULA', 3, N'Aerzen', NULL, 0, 9000, 1,
  N'Preventivo 9.000 h.')

DECLARE @RCOD NVARCHAR(50), @RNOM NVARCHAR(200), @RTIP NVARCHAR(50), @RUNI INT, @RFAB NVARCHAR(200), @RMOD NVARCHAR(200),
        @RCON BIT, @RVID DECIMAL(18,2), @RMIN DECIMAL(18,2), @RDES NVARCHAR(500), @REP INT, @RTI INT
DECLARE cr CURSOR LOCAL FAST_FORWARD FOR
    SELECT codigo, nombre, tipo, unidad, fabricante, modelo, consumible, vida_h, minimo, descripcion FROM @R
OPEN cr
FETCH NEXT FROM cr INTO @RCOD, @RNOM, @RTIP, @RUNI, @RFAB, @RMOD, @RCON, @RVID, @RMIN, @RDES
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RTI = (SELECT TOP 1 rti_id FROM [dbo].[Repuesto_Tipo] WHERE rti_cliente = @CLIENTE AND rti_codigo = @RTIP)
    SET @REP = (SELECT rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND rep_codigo = @RCOD)
    IF @REP IS NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO]
             @ID = @REP OUTPUT, @CLIENTE = @CLIENTE, @CODIGO = @RCOD, @NOMBRE = @RNOM, @UNIDAD_MEDIDA = @RUNI,
             @FABRICANTE = @RFAB, @MODELO = @RMOD, @DESCRIPCION = @RDES,
             @ES_REPARABLE = 0, @ES_CONSUMIBLE = @RCON, @CONTROLA_LOTE = 0,
             @COSTO_REFERENCIA = NULL, @MONEDA = NULL,
             @VIDA_UTIL_HORA = @RVID, @VIDA_UTIL_DIA = NULL, @VIDA_UTIL_CICLO = NULL,
             @REPUESTO_TIPO = @RTI, @USUARIO = @USUARIO
        SET @REP = (SELECT rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND rep_codigo = @RCOD)
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] WHERE rco_repuesto = @REP AND rco_activo_tipo = @TIPO)
        EXEC [dbo].[INS_REPUESTO_COMPATIBILIDAD]
             @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @REP, @TIPO = @TIPO, @MODELO = NULL, @COMPONENTE = NULL,
             @OBSERVACION = N'Sopladores Aerzen GM10S (CB01..CB04).', @USUARIO = @USUARIO

    IF @BODEGA IS NOT NULL AND @RMIN > 0
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Bodega_Stock] WHERE rbs_repuesto = @REP AND rbs_bodega = @BODEGA)
        EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK]
             @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @REPUESTO = @REP, @BODEGA = @BODEGA,
             @STOCK_MINIMO = @RMIN, @STOCK_MAXIMO = NULL, @PUNTO_REPOSICION = NULL,
             @OBSERVACION = N'Mínimo para los cuatro sopladores.', @USUARIO = @USUARIO

    FETCH NEXT FROM cr INTO @RCOD, @RNOM, @RTIP, @RUNI, @RFAB, @RMOD, @RCON, @RVID, @RMIN, @RDES
END
CLOSE cr
DEALLOCATE cr

/* -------------------------------------------------------------------------
   2) Componentes: el mismo árbol en cada soplador
      sufijo, padre, tipo (Componente_Tipo), posición (Componente_Posicion),
      criticidad
   ------------------------------------------------------------------------- */
DECLARE @C TABLE (sufijo NVARCHAR(10), padre NVARCHAR(10), tipo INT, posicion INT, criticidad INT,
                  nombre NVARCHAR(200), descripcion NVARCHAR(500))
INSERT INTO @C VALUES
 (N'01', NULL,  14, 14, 4, N'Unidad de soplado (lóbulos) GM10S', N'Aerzen GM10S · 24,5 kW · 4800 rpm · 106 kg.'),
 (N'02', N'01', 12, 14, 3, N'Retén de aceite',                  N'Repuesto BLW-RETEN.'),
 (N'03', N'01', 14, 13, 3, N'Anillos y porta anillera',         N'Repuestos BLW-ANILLOS y BLW-PORTA-ANILLERA.'),
 (N'04', N'01', 11,  5, 2, N'Filtro de aire de aspiración',     N'Repuesto BLW-FILTRO-AIRE.'),
 (N'05', NULL,   1, 14, 4, N'Motor eléctrico 30 kW',            N'Aerzen · 30 kW · 2960 rpm · 238 kg · modelo TE1BF0X0$.'),
 (N'06', N'05',  3,  4, 3, N'Rodamiento 6312-C3',               N'Lado acople. Repuesto BLW-ROD-6312C3.'),
 (N'07', N'05',  3, 12, 3, N'Rodamiento 6212-C3',               N'Lado opuesto. Repuesto BLW-ROD-6212C3.'),
 (N'08', NULL,  14,  4, 3, N'Transmisión por correas',          N'Motor a soplador.'),
 (N'09', N'08',  5, 14, 3, N'Correas',                          N'Repuesto BLW-CORREA.'),
 (N'10', N'08', 13,  3, 2, N'Polea motor',                      N'Repuesto BLW-POLEA-MOTOR.'),
 (N'11', N'08', 13,  4, 2, N'Polea soplador',                   N'Repuesto BLW-POLEA-SOPLADOR.'),
 (N'12', NULL,   8,  6, 3, N'Válvula check',                    N'Descarga. Repuesto BLW-KIT-CHECK.'),
 (N'13', NULL,   8,  7, 4, N'Válvula de alivio',                N'Descarga. Repuesto BLW-KIT-ALIVIO.'),
 (N'14', NULL,   9,  6, 2, N'Manómetro de descarga',            N'Instrumentación.'),
 (N'15', NULL,   9,  5, 2, N'Vacuómetro de aspiración',         N'Instrumentación.')

DECLARE @ACT INT, @ACOD NVARCHAR(50), @SUF NVARCHAR(10), @PAD NVARCHAR(10), @CTI INT, @CPO INT, @CRI INT,
        @CNOM NVARCHAR(200), @CDES NVARCHAR(500), @CCOD NVARCHAR(50), @PADRE INT, @COMP INT
DECLARE ca CURSOR LOCAL FAST_FORWARD FOR
    SELECT act_id, act_codigo FROM [dbo].[Activo]
     WHERE act_cliente = @CLIENTE AND act_codigo IN (N'CB01', N'CB02', N'CB03', N'CB04') ORDER BY act_codigo
OPEN ca
FETCH NEXT FROM ca INTO @ACT, @ACOD
WHILE @@FETCH_STATUS = 0
BEGIN
    /* Padres primero: el orden de la tabla ya los deja antes que sus hijos. */
    DECLARE cc CURSOR LOCAL FAST_FORWARD FOR
        SELECT sufijo, padre, tipo, posicion, criticidad, nombre, descripcion FROM @C ORDER BY sufijo
    OPEN cc
    FETCH NEXT FROM cc INTO @SUF, @PAD, @CTI, @CPO, @CRI, @CNOM, @CDES
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CCOD  = N'CMP-' + @ACOD + N'-' + @SUF
        SET @PADRE = (SELECT aco_id FROM [dbo].[Activo_Componente]
                       WHERE aco_cliente = @CLIENTE AND aco_codigo = N'CMP-' + @ACOD + N'-' + @PAD)
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_cliente = @CLIENTE AND aco_codigo = @CCOD)
            EXEC [dbo].[INS_ACTIVO_COMPONENTE]
                 @ID = @COMP OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACT,
                 @COMPONENTE_PADRE = @PADRE, @COMPONENTE_TIPO = @CTI,
                 @COMPONENTE_POSICION = @CPO, @CRITICIDAD_NIVEL = @CRI,
                 @ACTIVO_COMPONENTE_ESTADO = 1,
                 @CODIGO = @CCOD, @NOMBRE = @CNOM,
                 @FECHA_INSTALACION = NULL, @DESCRIPCION = @CDES,
                 @USUARIO = @USUARIO
        FETCH NEXT FROM cc INTO @SUF, @PAD, @CTI, @CPO, @CRI, @CNOM, @CDES
    END
    CLOSE cc
    DEALLOCATE cc
    FETCH NEXT FROM ca INTO @ACT, @ACOD
END
CLOSE ca
DEALLOCATE ca

/* -------------------------------------------------------------------------
   2b) Procedimientos: uno por tarea del plan, con sus pasos. El cliente
       entregó solo el nombre de la tarea; los pasos son la práctica estándar
       para un soplador de lóbulos y quedan para validar con Hamburgo.
   ------------------------------------------------------------------------- */
DECLARE @P TABLE (codigo NVARCHAR(100), nombre NVARCHAR(400), duracion INT, descripcion NVARCHAR(1000))
INSERT INTO @P VALUES
 (N'PRC-BLW-01', N'Cambio de filtro de aire del soplador', 20, N'Elemento de aspiración del Aerzen GM10S.'),
 (N'PRC-BLW-02', N'Cambio de aceite del soplador', 40, N'Cárter de engranajes y rodamientos (lado engranajes y lado accionamiento).'),
 (N'PRC-BLW-03', N'Cambio de retén de aceite del soplador', 90, N'Retén del eje de accionamiento.'),
 (N'PRC-BLW-04', N'Revisión de instrumentación (manómetros, vacuómetros)', 30, N'Manómetro de descarga y vacuómetro de aspiración.'),
 (N'PRC-BLW-05', N'Cambio de correas de transmisión', 60, N'Juego completo: nunca se cambia una sola correa.'),
 (N'PRC-BLW-06', N'Mantención y calibración de válvula check', 60, N'Válvula de retención de la descarga.'),
 (N'PRC-BLW-07', N'Mantención y calibración de válvula de alivio', 60, N'Válvula de seguridad de la descarga.'),
 (N'PRC-BLW-08', N'Mantención y balanceo de unidad de lóbulos', 240, N'Overhaul de la unidad de soplado. Lo ejecuta el servicio técnico externo.'),
 (N'PRC-BLW-09', N'Cambio de rodamientos del soplador', 180, N'Rodamientos de la unidad de lóbulos. Overhaul.'),
 (N'PRC-BLW-10', N'Cambio de anillos y porta anillera', 180, N'Sellos de los ejes de la unidad de lóbulos. Overhaul.'),
 (N'PRC-BLW-11', N'Mantención del motor eléctrico', 90, N'Motor Aerzen 30 kW 2960 rpm.'),
 (N'PRC-BLW-12', N'Cambio de rodamientos del motor', 120, N'6312-C3 lado acople y 6212-C3 lado opuesto.'),
 (N'PRC-BLW-13', N'Evaluación y cambio de poleas', 60, N'Se cambia solo si el desgaste lo justifica.')

/* Primer y último paso son comunes: bloqueo y prueba en marcha. */
DECLARE @S TABLE (prc NVARCHAR(100), orden INT, nombre NVARCHAR(200), instruccion NVARCHAR(1000), control BIT, evidencia BIT)
INSERT INTO @S
SELECT codigo, 1, N'Detener y bloquear el soplador',
       N'Detener el equipo, aislar energía eléctrica, bloquear y etiquetar. Verificar energía cero y despresurizar la línea.', 1, 1
FROM @P
INSERT INTO @S VALUES
 (N'PRC-BLW-01', 2, N'Retirar el elemento filtrante', N'Abrir la tapa del silenciador de aspiración y retirar el elemento sin dejar caer suciedad hacia la entrada.', 0, 0),
 (N'PRC-BLW-01', 3, N'Limpiar la carcasa del filtro', N'Limpiar con paño seco; nunca con aire a presión hacia la aspiración.', 0, 0),
 (N'PRC-BLW-01', 4, N'Instalar el filtro nuevo', N'Instalar el elemento BLW-FILTRO-AIRE, revisar el sello y cerrar la tapa.', 1, 1),
 (N'PRC-BLW-02', 2, N'Drenar el aceite en caliente', N'Con el equipo aún tibio, abrir los tapones de drenaje de ambos cárteres y recibir el aceite en bandeja.', 0, 0),
 (N'PRC-BLW-02', 3, N'Revisar el aceite retirado', N'Registrar color, olor y presencia de partículas o agua: anticipa desgaste de engranajes y rodamientos.', 1, 1),
 (N'PRC-BLW-02', 4, N'Llenar con aceite nuevo', N'Cerrar drenajes y llenar con BLW-ACEITE hasta el centro del visor de nivel de cada cárter.', 1, 1),
 (N'PRC-BLW-03', 2, N'Retirar correas y polea del soplador', N'Destensar el motor, retirar correas y extraer la polea con extractor.', 0, 0),
 (N'PRC-BLW-03', 3, N'Extraer el retén dañado', N'Retirar el retén sin rayar el eje; revisar la pista del eje.', 1, 1),
 (N'PRC-BLW-03', 4, N'Instalar el retén nuevo', N'Lubricar el labio e instalar BLW-RETEN con botador, a escuadra.', 1, 0),
 (N'PRC-BLW-03', 5, N'Montar polea y correas', N'Reinstalar polea y correas, y tensar según el procedimiento de correas.', 0, 0),
 (N'PRC-BLW-04', 2, N'Revisar manómetro y vacuómetro', N'Verificar que la aguja vuelve a cero, vidrio sano y sin fugas en la conexión.', 1, 0),
 (N'PRC-BLW-04', 3, N'Contrastar con instrumento patrón', N'Comparar la lectura en marcha con un instrumento patrón; cambiar si la diferencia supera el 2 %.', 1, 1),
 (N'PRC-BLW-05', 2, N'Destensar y retirar correas', N'Aflojar la base del motor y retirar el juego completo.', 0, 0),
 (N'PRC-BLW-05', 3, N'Revisar alineación de poleas', N'Verificar alineación con regla o láser y estado de los canales.', 1, 1),
 (N'PRC-BLW-05', 4, N'Instalar y tensar correas nuevas', N'Instalar BLW-CORREA y tensar según tabla del fabricante; volver a tensar a las 24 h de marcha.', 1, 1),
 (N'PRC-BLW-06', 2, N'Desmontar la válvula check', N'Retirar la válvula de la descarga y revisar clapeta, asiento y resorte.', 0, 1),
 (N'PRC-BLW-06', 3, N'Cambiar componentes de desgaste', N'Instalar BLW-KIT-CHECK y verificar cierre hermético.', 1, 0),
 (N'PRC-BLW-07', 2, N'Desmontar la válvula de alivio', N'Retirar la válvula y revisar asiento, plato y resorte.', 0, 1),
 (N'PRC-BLW-07', 3, N'Cambiar kit y calibrar', N'Instalar BLW-KIT-ALIVIO y calibrar a la presión de apertura indicada en la placa del soplador.', 1, 1),
 (N'PRC-BLW-08', 2, N'Desmontar la unidad de soplado', N'Retirar el soplador de la base y llevarlo al taller del servicio técnico.', 0, 1),
 (N'PRC-BLW-08', 3, N'Inspeccionar lóbulos y engranajes', N'Medir juegos entre lóbulos y entre lóbulo y carcasa; revisar engranajes de sincronismo.', 1, 1),
 (N'PRC-BLW-08', 4, N'Balancear y rearmar', N'Balancear el conjunto rotor y rearmar con los juegos de fábrica.', 1, 1),
 (N'PRC-BLW-09', 2, N'Desarmar lado engranajes y lado accionamiento', N'Retirar tapas y engranajes de sincronismo marcando su posición.', 0, 0),
 (N'PRC-BLW-09', 3, N'Cambiar rodamientos', N'Extraer y montar rodamientos nuevos en caliente; nunca a golpes sobre la pista.', 1, 1),
 (N'PRC-BLW-10', 2, N'Retirar anillos y porta anillera', N'Desmontar los sellos de cada eje y limpiar los alojamientos.', 0, 0),
 (N'PRC-BLW-10', 3, N'Instalar porta anillera y anillos nuevos', N'Montar BLW-PORTA-ANILLERA y BLW-ANILLOS respetando la orientación.', 1, 1),
 (N'PRC-BLW-11', 2, N'Limpiar y revisar el motor', N'Limpiar aletas y ventilador, revisar caja de conexiones y apriete de bornes.', 0, 0),
 (N'PRC-BLW-11', 3, N'Medir aislamiento', N'Medir aislamiento de bobinas con megóhmetro a 500 V y registrar el valor (mínimo 100 MΩ).', 1, 1),
 (N'PRC-BLW-12', 2, N'Desacoplar y desarmar el motor', N'Retirar polea, tapas y rotor.', 0, 0),
 (N'PRC-BLW-12', 3, N'Cambiar rodamientos 6312-C3 y 6212-C3', N'Montar en caliente BLW-ROD-6312C3 lado acople y BLW-ROD-6212C3 lado opuesto, y engrasar.', 1, 1),
 (N'PRC-BLW-13', 2, N'Evaluar el desgaste de canales', N'Medir los canales con galga de poleas y registrar el resultado.', 1, 1),
 (N'PRC-BLW-13', 3, N'Cambiar poleas si corresponde', N'Instalar BLW-POLEA-MOTOR y/o BLW-POLEA-SOPLADOR y alinear.', 0, 0)
INSERT INTO @S
SELECT codigo, 99, N'Prueba en marcha y liberación',
       N'Retirar bloqueos, arrancar y verificar ruido, vibración, temperatura, presión de descarga y ausencia de fugas. Registrar la lectura del horómetro.', 1, 1
FROM @P

DECLARE @PCOD NVARCHAR(100), @PNOM2 NVARCHAR(400), @PDUR INT, @PDES NVARCHAR(1000), @PRC INT
DECLARE @SORD INT, @SNOM NVARCHAR(200), @SINS NVARCHAR(1000), @SCTL BIT, @SEVI BIT, @N INT
DECLARE cp CURSOR LOCAL FAST_FORWARD FOR SELECT codigo, nombre, duracion, descripcion FROM @P ORDER BY codigo
OPEN cp
FETCH NEXT FROM cp INTO @PCOD, @PNOM2, @PDUR, @PDES
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @PRC = (SELECT prc_id FROM [dbo].[Procedimiento] WHERE prc_cliente = @CLIENTE AND prc_codigo = @PCOD)
    IF @PRC IS NULL
    BEGIN
        EXEC [dbo].[INS_PROCEDIMIENTO] @ID = @PRC OUTPUT, @CLIENTE = @CLIENTE, @CODIGO = @PCOD, @NOMBRE = @PNOM2,
             @VERSION = 1, @ACTIVO_TIPO = @TIPO, @DESCRIPCION = @PDES, @DURACION = @PDUR,
             @REQUIERE_PERMISO = 0, @PERMISO_TIPO = NULL, @USUARIO = @USUARIO
        SET @PRC = (SELECT prc_id FROM [dbo].[Procedimiento] WHERE prc_cliente = @CLIENTE AND prc_codigo = @PCOD)
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Procedimiento_Paso] WHERE ppa_procedimiento = @PRC)
    BEGIN
        SET @N = 0
        DECLARE cs CURSOR LOCAL FAST_FORWARD FOR SELECT orden, nombre, instruccion, control, evidencia FROM @S WHERE prc = @PCOD ORDER BY orden
        OPEN cs
        FETCH NEXT FROM cs INTO @SORD, @SNOM, @SINS, @SCTL, @SEVI
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @N = @N + 1
            EXEC [dbo].[INS_PROCEDIMIENTO_PASO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PROCEDIMIENTO = @PRC, @ORDEN = @N,
                 @NOMBRE = @SNOM, @INSTRUCCION = @SINS, @ES_PUNTO_CONTROL = @SCTL, @REQUIERE_EVIDENCIA = @SEVI,
                 @REQUIERE_MEDICION = 0, @VARIABLE = NULL, @DURACION = NULL, @USUARIO = @USUARIO
            FETCH NEXT FROM cs INTO @SORD, @SNOM, @SINS, @SCTL, @SEVI
        END
        CLOSE cs
        DEALLOCATE cs
    END
    FETCH NEXT FROM cp INTO @PCOD, @PNOM2, @PDUR, @PDES
END
CLOSE cp
DEALLOCATE cp

/* -------------------------------------------------------------------------
   3) Repuestos en el plan: versión nueva, repuestos por actividad, publicar
   ------------------------------------------------------------------------- */
DECLARE @VERSION INT = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
                         WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 ORDER BY pmv_id DESC)
/* Si la vigente ya tiene repuestos, la carga ya se hizo. */
IF @VERSION IS NULL AND NOT EXISTS (
       SELECT 1 FROM [dbo].[Plan_Actividad_Repuesto] r
       JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
       JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
       JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
      WHERE v.pmv_plan_mantenimiento = @PLAN AND v.pmv_plan_version_estado = 2)
BEGIN
    EXEC [dbo].[INS_PLAN_VERSION_NUEVA] @ID = @VERSION OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN,
         @OBSERVACION = N'Procedimientos y repuestos por actividad (Aerzen GM10S).', @USUARIO = @USUARIO
    SET @VERSION = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
                     WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 ORDER BY pmv_id DESC)
END

IF @VERSION IS NOT NULL
BEGIN
    /* Actividad (por nombre, en todos los hitos que la tengan) -> repuesto */
    DECLARE @M TABLE (actividad NVARCHAR(400), hito NVARCHAR(100), repuesto NVARCHAR(50), cantidad DECIMAL(18,2), obligatorio BIT, obs NVARCHAR(200))
    INSERT INTO @M VALUES
     (N'Cambio de filtro de aire', NULL, N'BLW-FILTRO-AIRE', 1, 1, NULL),
     (N'Cambio de aceite', NULL, N'BLW-ACEITE', 1.5, 1, N'Volumen por confirmar con el manual del GM10S.'),
     (N'Cambio de retén de aceite (a evaluar)', NULL, N'BLW-RETEN', 1, 0, N'Solo si la evaluación lo indica.'),
     (N'Cambio de retén de aceite', NULL, N'BLW-RETEN', 1, 1, NULL),
     (N'Cambio de correas', NULL, N'BLW-CORREA', 1, 1, NULL),
     (N'Mantención y calibración de válvula check', NULL, N'BLW-KIT-CHECK', 1, 1, NULL),
     (N'Mantención y calibración de válvula de alivio', NULL, N'BLW-KIT-ALIVIO', 1, 1, NULL),
     (N'Cambio de rodamientos del motor', NULL, N'BLW-ROD-6312C3', 1, 1, N'Lado acople.'),
     (N'Cambio de rodamientos del motor', NULL, N'BLW-ROD-6212C3', 1, 1, N'Lado opuesto.'),
     (N'Cambio de porta anillera', NULL, N'BLW-PORTA-ANILLERA', 1, 1, NULL),
     (N'Cambio de anillos', NULL, N'BLW-ANILLOS', 1, 1, NULL),
     (N'Cambio de poleas (se evalúa caso a caso)', NULL, N'BLW-POLEA-MOTOR', 1, 0, N'Solo si la evaluación lo indica.'),
     (N'Cambio de poleas (se evalúa caso a caso)', NULL, N'BLW-POLEA-SOPLADOR', 1, 0, N'Solo si la evaluación lo indica.')

    DECLARE @PAA INT, @MREP INT, @MCAN DECIMAL(18,2), @MOBL BIT, @MOBS NVARCHAR(200)
    DECLARE cm CURSOR LOCAL FAST_FORWARD FOR
        SELECT a.paa_id, r.rep_id, m.cantidad, m.obligatorio, m.obs
          FROM @M m
          JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_nombre = m.actividad
          JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito AND h.pmh_plan_mantenimiento_version = @VERSION
          JOIN [dbo].[Repuesto] r ON r.rep_cliente = @CLIENTE AND r.rep_codigo = m.repuesto
         WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Actividad_Repuesto] x
                            WHERE x.pra_plan_mantenimiento_actividad = a.paa_id AND x.pra_repuesto = r.rep_id)
    OPEN cm
    FETCH NEXT FROM cm INTO @PAA, @MREP, @MCAN, @MOBL, @MOBS
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[INS_PLAN_ACTIVIDAD_REPUESTO]
             @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @ACTIVIDAD = @PAA, @REPUESTO = @MREP,
             @CANTIDAD = @MCAN, @OBLIGATORIO = @MOBL, @OBSERVACION = @MOBS, @USUARIO = @USUARIO
        FETCH NEXT FROM cm INTO @PAA, @MREP, @MCAN, @MOBL, @MOBS
    END
    CLOSE cm
    DEALLOCATE cm

    /* Procedimiento de cada actividad (por nombre) */
    DECLARE @L TABLE (actividad NVARCHAR(400), prc NVARCHAR(100))
    INSERT INTO @L VALUES
     (N'Cambio de filtro de aire', N'PRC-BLW-01'),
     (N'Cambio de aceite', N'PRC-BLW-02'),
     (N'Cambio de retén de aceite (a evaluar)', N'PRC-BLW-03'),
     (N'Cambio de retén de aceite', N'PRC-BLW-03'),
     (N'Revisión de instrumentación (manómetros, vacuómetros)', N'PRC-BLW-04'),
     (N'Cambio de correas', N'PRC-BLW-05'),
     (N'Mantención y calibración de válvula check', N'PRC-BLW-06'),
     (N'Mantención y calibración de válvula de alivio', N'PRC-BLW-07'),
     (N'Mantención y balanceo de unidad de lóbulos', N'PRC-BLW-08'),
     (N'Cambio de rodamientos del soplador', N'PRC-BLW-09'),
     (N'Cambio de porta anillera', N'PRC-BLW-10'),
     (N'Cambio de anillos', N'PRC-BLW-10'),
     (N'Mantención del motor', N'PRC-BLW-11'),
     (N'Cambio de rodamientos del motor', N'PRC-BLW-12'),
     (N'Cambio de poleas (se evalúa caso a caso)', N'PRC-BLW-13')

    DECLARE @LPAA INT, @LPRC INT, @LDUR INT
    DECLARE cl CURSOR LOCAL FAST_FORWARD FOR
        SELECT a.paa_id, p.prc_id, p.prc_duracion_estimada_minuto
          FROM @L l
          JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_nombre = l.actividad
          JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito AND h.pmh_plan_mantenimiento_version = @VERSION
          JOIN [dbo].[Procedimiento] p ON p.prc_cliente = @CLIENTE AND p.prc_codigo = l.prc
         WHERE ISNULL(a.paa_procedimiento, 0) <> p.prc_id
    OPEN cl
    FETCH NEXT FROM cl INTO @LPAA, @LPRC, @LDUR
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[UPD_PLAN_ACTIVIDAD] @ID = @LPAA, @PROCEDIMIENTO = @LPRC, @DURACION_ESTIMADA_MINUTO = @LDUR, @USUARIO = @USUARIO
        FETCH NEXT FROM cl INTO @LPAA, @LPRC, @LDUR
    END
    CLOSE cl
    DEALLOCATE cl

    EXEC [dbo].[UPD_PLAN_VERSION_PUBLICAR] @ID = @VERSION, @CLIENTE = @CLIENTE,
         @OBSERVACION = N'Procedimientos y repuestos por actividad (Aerzen GM10S).', @USUARIO = @USUARIO
END
GO

/* -------------------------------------------------------------------------
   5) SOLO EN DESA: stock de prueba en Bodega Piso 1 para cerrar una OT de
      punta a punta. En otra base no hace nada: el stock real lo carga bodega.
   ------------------------------------------------------------------------- */
IF DB_NAME() = N'db71936'
BEGIN
    DECLARE @CLI INT = 1
    DECLARE @USU INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'root@codigocreativo.cl')
    DECLARE @BOD INT = (SELECT TOP 1 bod_id FROM [dbo].[Bodega] WHERE bod_cliente = @CLI AND bod_codigo = N'BOD-1')
    DECLARE @UBI INT = (SELECT TOP 1 bub_id FROM [dbo].[Bodega_Ubicacion] WHERE bub_bodega = @BOD ORDER BY bub_id)
    DECLARE @SREP INT, @SCAN DECIMAL(18,2), @SID INT
    DECLARE cst CURSOR LOCAL FAST_FORWARD FOR
        SELECT r.rep_id, CASE WHEN r.rep_codigo = N'BLW-ACEITE' THEN 20 ELSE 4 END
          FROM [dbo].[Repuesto] r
         WHERE r.rep_cliente = @CLI AND r.rep_codigo LIKE N'BLW-%'
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento] m WHERE m.imo_repuesto = r.rep_id)
    OPEN cst
    FETCH NEXT FROM cst INTO @SREP, @SCAN
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO]
             @ID = @SID OUTPUT, @CLIENTE = @CLI, @REPUESTO = @SREP, @BODEGA = @BOD, @TIPO = 4,   -- AJUSTE POSITIVO
             @CANTIDAD = @SCAN, @UBICACION = @UBI, @LOTE = NULL, @COSTO_UNITARIO = NULL, @MONEDA = NULL,
             @ORDEN_TRABAJO = NULL, @BODEGA_DESTINO = NULL, @UBICACION_DESTINO = NULL,
             @OBSERVACION = N'Stock de prueba (desa) para el end to end de sopladores.', @UUID = NULL, @USUARIO = @USU
        FETCH NEXT FROM cst INTO @SREP, @SCAN
    END
    CLOSE cst
    DEALLOCATE cst
END
GO

-- ---------------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------------
SELECT a.act_codigo, COUNT(c.aco_id) AS componentes
FROM   [dbo].[Activo] a LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_activo = a.act_id AND c.aco_habilitado = 1
WHERE  a.act_cliente = 1 AND a.act_codigo LIKE N'CB0_'
GROUP BY a.act_codigo
GO
SELECT 'v' + CAST(v.pmv_numero AS VARCHAR) + ' ' + pve.pve_codigo + ' · ' + h.pmh_codigo + ' · ' + a.paa_nombre
       + ' -> ' + r.rep_codigo + ' x' + CAST(p.pra_cantidad AS VARCHAR) AS RESULTADO
FROM   [dbo].[Plan_Actividad_Repuesto] p
JOIN   [dbo].[Repuesto] r ON r.rep_id = p.pra_repuesto
JOIN   [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = p.pra_plan_mantenimiento_actividad
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Version_Estado] pve ON pve.pve_id = v.pmv_plan_version_estado
JOIN   [dbo].[Plan_Mantenimiento] pm ON pm.pma_id = v.pmv_plan_mantenimiento
WHERE  pm.pma_codigo = N'PMA-BLOWERS' AND pm.pma_cliente = 1
ORDER BY v.pmv_numero, h.pmh_orden, a.paa_orden
GO
