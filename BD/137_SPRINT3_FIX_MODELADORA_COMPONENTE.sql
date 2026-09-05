USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - CORRIGE EL ENCUADRE DEL EQUIPO REAL.
-- =============================================
-- Va DESPUES de 136_SPRINT3_DEMO_MOTOR_SEW.
--
-- CONTEXTO: en 136 se cargo, por error de encuadre, el MOTORREDUCTOR como si
-- fuera el activo. El activo real es el EQUIPO: la MODELADORA (linea Fritsch),
-- y el motorreductor SEW es una PARTE (componente) de esa modeladora.
--
-- Segun la decision de Emilio, el motor va como COMPONENTE (despiece), no como
-- sub-activo: no lleva historial/OT propio ni se enlaza al catalogo de modelos
-- ni a atributos tecnicos. Sus datos de placa quedan en la descripcion del
-- componente; su catalogo/foto/placa se guardan en el MODELO SEW (que se deja
-- en el catalogo justo como hogar de esos archivos).
--
-- QUE HACE:
--   1) Convierte el activo ACT-33 (motor) en la MODELADORA (Fritsch).
--   2) Crea el motorreductor SEW como COMPONENTE (tipo Motor) de la modeladora.
--   3) Da de baja (logica) los atributos del tipo Motorreductor sembrados en
--      136: con el encuadre "componente" no se usan (reversibles).
--
-- El MODELO SEW (Activo_Modelo id del 136) se CONSERVA a proposito.
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   0) UBICACION: planta "Panaderia" con area "Linea 1".
      En 136 se creo una "Planta Principal"; se renombra a Panaderia y se le
      crea el area de produccion "Linea 1" donde se instala la modeladora.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTA INT, @AREA INT = NULL, @NEW INT = NULL;

SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE ORDER BY cin_id;

IF @PLANTA IS NOT NULL
BEGIN
    UPDATE [dbo].[Cliente_Instalacion]
    SET    cin_nombre = N'Panaderia',
           cin_descripcion = N'Planta de panaderia de Hamburgo SA.'
    WHERE  cin_id = @PLANTA;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                   WHERE iar_cliente_instalacion = @PLANTA AND iar_nombre = N'Linea 1')
    BEGIN
        EXEC [dbo].[INS_INSTALACION_AREA]
             @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
             @AREA_PADRE = NULL, @INSTALACION_AREA_TIPO = 3,   -- Linea de produccion
             @CODIGO = N'LN-1', @NOMBRE = N'Linea 1',
             @DESCRIPCION = N'Linea de produccion 1.', @USUARIO = @USUARIO;
    END
    PRINT '--- Ubicacion lista: planta Panaderia / area Linea 1.';
END
GO

/* ========================================================================
   1) ACT-33 pasa a ser la MODELADORA (Fritsch), ubicada en Panaderia/Linea 1.
      Se limpian los datos que eran del MOTOR (N| de serie SEW y el modelo
      SEW): esos pertenecen al componente, no al equipo. La Modeladora tiene
      su propia placa Fritsch, que el usuario cargara luego.
      UPDATE directo (no UPD_ACTIVO) porque hay que poner campos en NULL, y el
      SP usa ISNULL y no permitiria vaciarlos.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTA INT, @AREA INT;

SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE ORDER BY cin_id;
SELECT @AREA = iar_id FROM [dbo].[Instalacion_Area]
WHERE  iar_cliente_instalacion = @PLANTA AND iar_nombre = N'Linea 1';

IF EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_codigo = 'ACT-33' AND act_cliente = @CLIENTE)
BEGIN
    UPDATE [dbo].[Activo]
    SET act_nombre       = N'Modeladora',
        act_activo_tipo  = 26,               -- Panificacion (TIP-1): familia del equipo
        act_activo_modelo = NULL,            -- el modelo SEW era del motor
        act_fabricante   = N'Fritsch',
        act_numero_serie = NULL,             -- la serie SEW es del motor
        act_cliente_instalacion = @PLANTA,   -- planta Panaderia
        act_instalacion_area    = @AREA,     -- area Linea 1
        act_descripcion  = N'Modeladora de masa, linea Fritsch. Equipo de panificacion.',
        act_usuario_actualizacion = @USUARIO,
        act_fecha_actualizacion   = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM Cliente WHERE cli_id = @CLIENTE))
    WHERE act_codigo = 'ACT-33' AND act_cliente = @CLIENTE;
    PRINT '--- ACT-33 convertido en Modeladora (Fritsch), en Panaderia/Linea 1.';
END
ELSE
    PRINT '--- No se encontro ACT-33; se omite la conversion.';
GO

/* ========================================================================
   2) EL DESPIECE de la modeladora (sus partes).
      El motorreductor SEW lleva los datos reales de placa; el resto
      (sensor, rodamiento, polin) van como piezas de ejemplo que el usuario
      completa. Cada una es idempotente por nombre. Codigo automatico.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @MODELADORA INT, @NEW INT = NULL;

SELECT @MODELADORA = act_id FROM [dbo].[Activo]
WHERE  act_codigo = 'ACT-33' AND act_cliente = @CLIENTE;

-- Lista del despiece: (tipo de componente, nombre, criticidad, descripcion).
DECLARE @partes TABLE (orden INT IDENTITY(1,1), tipo INT, nombre NVARCHAR(200), crit INT, descr NVARCHAR(500));
INSERT INTO @partes (tipo, nombre, crit, descr) VALUES
    (1,  N'Motorreductor SEW W30 DT71D4/TH', 2,
         N'SEW-Eurodrive W30 DT71D4/TH. Serie 01.3338518005.0001.04. Placa: 0,37 kW S1 - 1700/44 rpm - 52 Nm - 277/480 V (D/Y) - 1,66/0,95 A - 60 Hz - PF 0,71 - IP54 - Aisl. B - IM M1B - 10,42 kg - Lubricante SEW FG 460 0,40 L.'),
    (9,  N'Sensor de posicion',    2, N'Sensor de la modeladora (completar marca/modelo).'),
    (3,  N'Rodamiento eje motriz', 2, N'Rodamiento del eje (completar referencia).'),
    (14, N'Polin transportador',   1, N'Polin/rodillo de arrastre (completar referencia).');

IF @MODELADORA IS NOT NULL
BEGIN
    DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @partes);
    DECLARE @tipo INT, @nom NVARCHAR(200), @crit INT, @descr NVARCHAR(500);
    WHILE @i <= @tot
    BEGIN
        SELECT @tipo = tipo, @nom = nombre, @crit = crit, @descr = descr FROM @partes WHERE orden = @i;
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                       WHERE aco_activo = @MODELADORA AND aco_nombre = @nom)
        BEGIN
            EXEC [dbo].[INS_ACTIVO_COMPONENTE]
                 @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @MODELADORA,
                 @COMPONENTE_PADRE = NULL, @COMPONENTE_TIPO = @tipo, @COMPONENTE_POSICION = @i,
                 @CRITICIDAD_NIVEL = @crit, @ACTIVO_COMPONENTE_ESTADO = 1,
                 @CODIGO = N'AUTO', @NOMBRE = @nom, @FECHA_INSTALACION = NULL,
                 @DESCRIPCION = @descr, @USUARIO = @USUARIO;
        END
        SET @i = @i + 1;
    END
    PRINT '--- Despiece de la modeladora sembrado (motor real + piezas de ejemplo).';
END
ELSE
    PRINT '--- No hay modeladora; se omite el despiece.';
GO

/* ========================================================================
   3) Baja logica de los atributos del tipo Motorreductor sembrados en 136.
      Con el encuadre "componente" no se usan. Reversibles (habilitado=0).
   ======================================================================== */
DECLARE @USUARIO INT = 9, @aid INT;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT ate_id FROM [dbo].[Atributo_Tecnico]
    WHERE ate_activo_tipo = 30 AND ate_cliente = 1 AND ate_habilitado = 1;
OPEN cur; FETCH NEXT FROM cur INTO @aid;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [dbo].[DEL_ATRIBUTO_TECNICO] @ID = @aid, @USUARIO = @USUARIO;
    FETCH NEXT FROM cur INTO @aid;
END
CLOSE cur; DEALLOCATE cur;
PRINT '--- Atributos del tipo Motorreductor dados de baja (no aplican al componente).';
GO

/* ========================================================================
   COMPROBACION
   ======================================================================== */
PRINT '=== ACTIVO (equipo) ===';
SELECT act_id, act_codigo, act_nombre, act_fabricante, act_activo_tipo, act_numero_serie, act_activo_modelo
FROM   [dbo].[Activo] WHERE act_codigo = 'ACT-33';

PRINT '=== COMPONENTES DEL EQUIPO ===';
SELECT aco_id, aco_codigo, aco_nombre, aco_componente_tipo, aco_activo_componente_estado
FROM   [dbo].[Activo_Componente] WHERE aco_activo = (SELECT act_id FROM Activo WHERE act_codigo='ACT-33');

PRINT '=== MODELO SEW (hogar de catalogo/foto/placa del motor) ===';
SELECT amo_id, amo_fabricante, amo_nombre FROM [dbo].[Activo_Modelo]
WHERE amo_fabricante = N'SEW-Eurodrive' AND amo_nombre = N'W30 DT71D4/TH';
GO

PRINT '137_SPRINT3_FIX_MODELADORA_COMPONENTE aplicado.';
GO
