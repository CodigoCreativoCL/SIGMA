USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - DATOS DE UN MOTORREDUCTOR REAL (SEW W30 DT71D4/TH).
-- =============================================
-- Carga de datos de un equipo real para probar el flujo completo de Activos,
-- a partir de la placa caracteristica fotografiada. Se cargan SOLO datos; las
-- fotos, la foto de la placa y el catalogo PDF los sube el usuario despues
-- desde las pantallas (esos archivos van a Azure via el uploader).
--
-- QUE SIEMBRA (todo a traves de los SP, con las mismas reglas de la pantalla):
--   1) MODELO de activo  : SEW-Eurodrive / W30 DT71D4/TH (tipo Motorreductor).
--   2) ATRIBUTOS TECNICOS: el esquema tecnico del tipo Motorreductor (potencia,
--      tension, par...). Es la definicion del TIPO, se reutiliza en todos sus
--      activos. Codigo automatico (ATR-<id>).
--   3) ACTIVO fisico     : la unidad instalada, con su N| de serie de placa,
--      apuntando al modelo. Codigo automatico. Los valores de placa quedan en
--      la descripcion (aun no hay pantalla de valor-por-activo).
--
-- ES IDEMPOTENTE: cada bloque se salta si el dato ya existe.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE  INT = 1;    -- Hamburgo SA
DECLARE @TIPO     INT = 30;   -- Motorreductor (TIP-30, bajo Electrico)
DECLARE @USUARIO  INT = 9;    -- emilio.fuentes@hamburgo.cl
DECLARE @MODELO   INT = NULL;
DECLARE @NEW      INT = NULL;

/* ========================================================================
   1) MODELO DE ACTIVO - SEW W30 DT71D4/TH
   ======================================================================== */
SELECT @MODELO = amo_id
FROM   [dbo].[Activo_Modelo]
WHERE  amo_cliente = @CLIENTE AND amo_activo_tipo = @TIPO
  AND  amo_fabricante = N'SEW-Eurodrive' AND amo_nombre = N'W30 DT71D4/TH';

IF @MODELO IS NULL
BEGIN
    EXEC [dbo].[INS_ACTIVO_MODELO]
         @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @TIPO,
         @FABRICANTE  = N'SEW-Eurodrive',
         @NOMBRE      = N'W30 DT71D4/TH',
         @DESCRIPCION = N'Motorreductor sinfin. Motor DT71D4 (0,37 kW, 4 polos) + reductor W30. Salida 44 rpm, par 52 Nm, IP54.',
         @USUARIO     = @USUARIO;
    SET @MODELO = @NEW;
    PRINT '--- Modelo SEW W30 DT71D4/TH creado (id ' + LTRIM(STR(@MODELO)) + ').';
END
ELSE
    PRINT '--- El modelo SEW W30 DT71D4/TH ya existia (id ' + LTRIM(STR(@MODELO)) + '). Se omite.';
GO

/* ========================================================================
   2) ATRIBUTOS TECNICOS DEL TIPO MOTORREDUCTOR
      Esquema tecnico reutilizable. La unidad va en el nombre (el catalogo
      Unidad_Medida no tiene kW/V/A/Hz/Nm), por eso @UNIDAD_MEDIDA = NULL.
      Codigo automatico: se envia 'AUTO'.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @TIPO INT = 30, @USUARIO INT = 9, @NEW INT = NULL, @ORD INT = 1;

-- Tabla local con el esquema a sembrar (nombre, tipo de dato).
DECLARE @attrs TABLE (orden INT IDENTITY(1,1), nombre NVARCHAR(200), tipo_dato INT);
INSERT INTO @attrs (nombre, tipo_dato) VALUES
    (N'Potencia (kW)',            3),   -- 3 = DECIMAL
    (N'Velocidad de salida (rpm)',2),   -- 2 = ENTERO
    (N'Par de salida (Nm)',       3),
    (N'Relacion de reduccion',    1),   -- 1 = TEXTO (ej. 38,6:1)
    (N'Tension (V)',              1),   -- TEXTO (277/480)
    (N'Corriente (A)',            1),   -- TEXTO (1,66/0,95)
    (N'Frecuencia (Hz)',          2),
    (N'Factor de potencia',       3),
    (N'Grado de proteccion (IP)', 1),
    (N'Clase de aislamiento',     1),
    (N'Peso (kg)',                3),
    (N'Posicion de montaje',      1),
    (N'Lubricante',               1);

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @attrs), @nom NVARCHAR(200), @td INT;
WHILE @i <= @tot
BEGIN
    SELECT @nom = nombre, @td = tipo_dato FROM @attrs WHERE orden = @i;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico]
                   WHERE ate_cliente = @CLIENTE AND ate_activo_tipo = @TIPO AND ate_nombre = @nom)
    BEGIN
        EXEC [dbo].[INS_ATRIBUTO_TECNICO]
             @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @TIPO,
             @TIPO_DATO = @td, @UNIDAD_MEDIDA = NULL,
             @CODIGO = N'AUTO', @NOMBRE = @nom, @ORDEN = @i, @USUARIO = @USUARIO;
    END
    SET @i = @i + 1;
END
PRINT '--- Atributos tecnicos del tipo Motorreductor sembrados/verificados.';
GO

/* ========================================================================
   2.5) PLANTA (Cliente_Instalacion) - un activo se instala en una planta del
        cliente. Hamburgo no tenia ninguna, asi que se crea una "Planta
        Principal" para poder ubicar el equipo. El usuario puede renombrarla.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTA INT = NULL, @NEW INT = NULL;

SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE ORDER BY cin_id;

IF @PLANTA IS NULL
BEGIN
    EXEC [dbo].[INS_CLIENTE_INSTALACION]
         @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE,
         @NOMBRE = 'Planta Principal', @DESCRIPCION = 'Planta principal de Hamburgo SA.',
         @DIRECCION = '', @CODIGO = N'PL-01', @ZONA_HORARIA = 1,
         @LATITUD = 0, @LONGITUD = 0, @HABILITADO = 1, @USUARIO = @USUARIO;
    SET @PLANTA = @NEW;
    PRINT '--- Planta Principal creada (id ' + LTRIM(STR(@PLANTA)) + ').';
END
ELSE
    PRINT '--- Ya existe una planta para el cliente (id ' + LTRIM(STR(@PLANTA)) + '). Se usa esa.';
GO

/* ========================================================================
   3) ACTIVO FISICO - la unidad instalada, con su N| de serie de placa.
      Los valores de placa van en la descripcion (aun no hay pantalla de
      valor-por-activo). Codigo automatico ('AUTO').
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @TIPO INT = 30, @USUARIO INT = 9, @NEW INT = NULL, @MODELO INT, @PLANTA INT;

SELECT @MODELO = amo_id FROM [dbo].[Activo_Modelo]
WHERE  amo_cliente = @CLIENTE AND amo_activo_tipo = @TIPO
  AND  amo_fabricante = N'SEW-Eurodrive' AND amo_nombre = N'W30 DT71D4/TH';

SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE ORDER BY cin_id;

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_numero_serie = N'01.3338518005.0001.04')
BEGIN
    EXEC [dbo].[INS_ACTIVO]
         @ID = @NEW OUTPUT,
         @CLIENTE             = @CLIENTE,
         @CLIENTE_INSTALACION = @PLANTA,
         @ACTIVO_TIPO         = @TIPO,
         @ACTIVO_MODELO       = @MODELO,
         @ACTIVO_ESTADO       = 1,           -- Operativo
         @CRITICIDAD_NIVEL    = 2,           -- Media
         @CODIGO              = N'AUTO',
         @NOMBRE              = N'Motorreductor SEW W30 DT71D4/TH',
         @NUMERO_SERIE        = N'01.3338518005.0001.04',
         @FABRICANTE          = N'SEW-Eurodrive',
         @DESCRIPCION         = N'Placa: 0,37 kW S1 - 1700/44 rpm - 52 Nm - 277/480 V (D/Y) - 1,66/0,95 A - 60 Hz - PF 0,71 - IP54 - Aisl. B - IM M1B - 10,42 kg - Lubricante SEW FG 460 0,40 L - 3~ TEFC.',
         @USUARIO             = @USUARIO;
    PRINT '--- Activo fisico creado (id ' + LTRIM(STR(@NEW)) + ').';
END
ELSE
    PRINT '--- Ya existe un activo con ese N| de serie. Se omite.';
GO

/* ========================================================================
   COMPROBACION
   ======================================================================== */
PRINT '=== MODELO ===';
SELECT amo_id, amo_fabricante, amo_nombre, amo_descripcion
FROM   [dbo].[Activo_Modelo]
WHERE  amo_fabricante = N'SEW-Eurodrive' AND amo_nombre = N'W30 DT71D4/TH';

PRINT '=== ATRIBUTOS DEL TIPO MOTORREDUCTOR ===';
SELECT ate_id, ate_codigo, ate_nombre, ate_tipo_dato, ate_orden
FROM   [dbo].[Atributo_Tecnico]
WHERE  ate_activo_tipo = 30 ORDER BY ate_orden;

PRINT '=== ACTIVO ===';
SELECT act_id, act_codigo, act_nombre, act_numero_serie, act_activo_modelo, act_fabricante
FROM   [dbo].[Activo]
WHERE  act_numero_serie = N'01.3338518005.0001.04';
GO

PRINT '136_SPRINT3_DEMO_MOTOR_SEW aplicado.';
GO
