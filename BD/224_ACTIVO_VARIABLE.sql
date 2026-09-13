USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     ADMINISTRAR LAS VARIABLES DE CONDICION DE UN ACTIVO (HU-041, Sprint 2).
--                  DESBLOQUEA HU-074 (programacion por condicion) Y HU-073 #3 (un horometro por equipo).
-- =============================================
-- T-2237 · EL MODELO, REVISADO
--
--   `Activo_Variable` es «este equipo (o este componente) mide esta variable,
--   en esta unidad, con estos umbrales». No tiene codigo: la identifica la
--   terna (activo, componente, variable) —UX_AVA_ACTIVO_COMPONENTE_VARIABLE—
--   asi que el «unico por codigo dentro del cliente» de la plantilla no
--   aplica. CK_AVA_RANGO exige maximo >= minimo. `ava_registro_descubrimiento`
--   apunta al descubrimiento en terreno (HU-155) cuando la variable nacio
--   desde el telefono.
--
--   El bloque 105 dejo un SEL_ACTIVO_VARIABLE minimo «hasta que se cierre
--   HU-041». Aqui se cierra: SEL completo, INS, UPD y DEL. Los umbrales se
--   validan en orden (minimo <= advertencia <= critico <= maximo) cuando
--   vienen los cuatro; la tabla solo exige min <= max.
--
-- HU-073 #3 · UN HOROMETRO POR EQUIPO — LA DECISION
--
--   `Programacion_Medidor.pme_activo_medidor` era NOT NULL: una programacion
--   por medidor ataba UN horometro, y un plan sobre cuatro blowers
--   necesitaba cuatro programaciones. Se deja NULLABLE: cuando es NULL, el
--   medidor lo pone cada equipo del plan (Plan_Mantenimiento_Activo.
--   pac_activo_medidor, HU-083). La programacion dice «cada 500 horas»; el
--   equipo dice «con este horometro». Una programacion, cuatro equipos.
-- =============================================

-- ---------------------------------------------------------------------------
-- 0) HU-073 #3: el medidor de la programacion puede quedar en blanco
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Programacion_Medidor') AND name = 'pme_activo_medidor' AND is_nullable = 0)
    ALTER TABLE [dbo].[Programacion_Medidor] ALTER COLUMN pme_activo_medidor INT NULL
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_ACTIVO_VARIABLE — completo (reemplaza el minimo del bloque 105)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_VARIABLE]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @ACTIVO      INT = NULL,
    @COMPONENTE  INT = NULL,
    @VARIABLE    INT = NULL,
    @INSTALACION INT = NULL,
    @HABILITADO  BIT = NULL,
    @FILTRO      NVARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  v.ava_id,
            v.ava_cliente,
            v.ava_activo,
            ISNULL(a.act_codigo, '')    AS ACTIVO_CODIGO,
            ISNULL(a.act_nombre, '')    AS ACTIVO_NOMBRE,
            cin.cin_nombre              AS PLANTA_NOMBRE,
            v.ava_activo_componente,
            aco.aco_codigo              AS COMPONENTE_CODIGO,
            aco.aco_nombre              AS COMPONENTE_NOMBRE,
            v.ava_variable_medicion,
            vm.vme_codigo               AS VARIABLE_CODIGO,
            vm.vme_nombre               AS VARIABLE_NOMBRE,
            vm.vme_tipo_dato            AS VARIABLE_TIPO_DATO,
            v.ava_unidad_medida,
            um.ume_simbolo              AS UNIDAD_SIMBOLO,
            um.ume_nombre               AS UNIDAD_NOMBRE,
            v.ava_valor_minimo,
            v.ava_valor_maximo,
            v.ava_valor_advertencia,
            v.ava_valor_critico,
            v.ava_frecuencia_esperada_hora,
            v.ava_registro_descubrimiento,
            v.ava_usuario_creacion,
            v.ava_fecha_creacion,
            v.ava_usuario_actualizacion,
            v.ava_fecha_actualizacion,
            v.ava_habilitado,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
            -- La etiqueta que usa el combo de condiciones (bloque 105): «ACT-34 Horno L1 · Temperatura (°C)»
            a.act_codigo + ' ' + a.act_nombre + CASE WHEN aco.aco_id IS NULL THEN '' ELSE ' / ' + aco.aco_nombre END
                + ' · ' + vm.vme_nombre + CASE WHEN um.ume_simbolo IS NULL THEN '' ELSE ' (' + um.ume_simbolo + ')' END AS ETIQUETA,
            (SELECT COUNT(*) FROM [dbo].[Activo_Medicion] m WHERE m.amd_activo_variable = v.ava_id) AS MEDICIONES,
            (SELECT COUNT(*) FROM [dbo].[Programacion_Condicion] c WHERE c.pco_activo_variable = v.ava_id AND c.pco_habilitado = 1) AS CONDICIONES
    FROM    [dbo].[Activo_Variable] v
    JOIN    [dbo].[Activo]              a   ON a.act_id  = v.ava_activo
    LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = a.act_cliente_instalacion
    LEFT JOIN [dbo].[Activo_Componente]   aco ON aco.aco_id = v.ava_activo_componente
    JOIN    [dbo].[Variable_Medicion]   vm  ON vm.vme_id  = v.ava_variable_medicion
    LEFT JOIN [dbo].[Unidad_Medida]     um  ON um.ume_id  = v.ava_unidad_medida
    LEFT JOIN [dbo].[Usuario]           uc  ON uc.usu_id  = v.ava_usuario_creacion
    LEFT JOIN [dbo].[Usuario]           ua  ON ua.usu_id  = v.ava_usuario_actualizacion
    WHERE   v.ava_cliente = @CLIENTE
      AND   (@ID IS NULL OR v.ava_id = @ID)
      AND   (@ACTIVO IS NULL OR v.ava_activo = @ACTIVO)
      AND   (@COMPONENTE IS NULL OR v.ava_activo_componente = @COMPONENTE)
      AND   (@VARIABLE IS NULL OR v.ava_variable_medicion = @VARIABLE)
      AND   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
      AND   (@HABILITADO IS NULL OR v.ava_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL OR a.act_codigo LIKE '%' + @FILTRO + '%' OR a.act_nombre LIKE '%' + @FILTRO + '%'
                             OR vm.vme_nombre LIKE '%' + @FILTRO + '%' OR vm.vme_codigo LIKE '%' + @FILTRO + '%')
    ORDER BY a.act_codigo, vm.vme_nombre, aco.aco_codigo
GO

-- ---------------------------------------------------------------------------
-- 2) Validacion comun de umbrales (min <= adv <= crit <= max, los que vengan)
-- ---------------------------------------------------------------------------
CREATE OR ALTER FUNCTION [dbo].[FNC_ACTIVO_VARIABLE_UMBRALES_OK]
(@MIN DECIMAL(18,6), @ADV DECIMAL(18,6), @CRI DECIMAL(18,6), @MAX DECIMAL(18,6))
RETURNS BIT
AS
BEGIN
    IF @MIN IS NOT NULL AND @MAX IS NOT NULL AND @MAX < @MIN RETURN 0
    IF @ADV IS NOT NULL AND @CRI IS NOT NULL AND @CRI < @ADV RETURN 0
    IF @MIN IS NOT NULL AND @ADV IS NOT NULL AND @ADV < @MIN RETURN 0
    IF @CRI IS NOT NULL AND @MAX IS NOT NULL AND @MAX < @CRI RETURN 0
    RETURN 1
END
GO

-- ---------------------------------------------------------------------------
-- 3) INS_ACTIVO_VARIABLE
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_VARIABLE]
@ID                       INT = NULL OUTPUT,
@CLIENTE                  INT,
@ACTIVO                   INT,
@ACTIVO_COMPONENTE        INT = NULL,
@VARIABLE_MEDICION        INT,
@UNIDAD_MEDIDA            INT = NULL,
@VALOR_MINIMO             DECIMAL(18,6) = NULL,
@VALOR_MAXIMO             DECIMAL(18,6) = NULL,
@VALOR_ADVERTENCIA        DECIMAL(18,6) = NULL,
@VALOR_CRITICO            DECIMAL(18,6) = NULL,
@FRECUENCIA_ESPERADA_HORA INT = NULL,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ACTIVO_COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO)
BEGIN
    RAISERROR('2.- EL COMPONENTE NO ES DE ESE EQUIPO.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Variable_Medicion] WHERE vme_id = @VARIABLE_MEDICION AND ISNULL(vme_cliente, @CLIENTE) = @CLIENTE AND vme_habilitado = 1)
BEGIN
    RAISERROR('3.- INDIQUE LA VARIABLE QUE SE MIDE.', 16, 1)
    RETURN -1
END

-- Sin unidad propia, la de la variable
IF @UNIDAD_MEDIDA IS NULL
    SET @UNIDAD_MEDIDA = (SELECT vme_unidad_medida FROM [dbo].[Variable_Medicion] WHERE vme_id = @VARIABLE_MEDICION)

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Variable]
           WHERE ava_activo = @ACTIVO AND ISNULL(ava_activo_componente, 0) = ISNULL(@ACTIVO_COMPONENTE, 0) AND ava_variable_medicion = @VARIABLE_MEDICION)
BEGIN
    RAISERROR('4.- ESE EQUIPO YA MIDE ESA VARIABLE (EN EL MISMO COMPONENTE). EDITE LA QUE EXISTE.', 16, 1)
    RETURN -1
END

IF [dbo].[FNC_ACTIVO_VARIABLE_UMBRALES_OK](@VALOR_MINIMO, @VALOR_ADVERTENCIA, @VALOR_CRITICO, @VALOR_MAXIMO) = 0
BEGIN
    RAISERROR('5.- LOS UMBRALES TIENEN QUE IR EN ORDEN: MÍNIMO <= ADVERTENCIA <= CRÍTICO <= MÁXIMO.', 16, 1)
    RETURN -1
END

IF @FRECUENCIA_ESPERADA_HORA IS NOT NULL AND @FRECUENCIA_ESPERADA_HORA <= 0
BEGIN
    RAISERROR('6.- LA FRECUENCIA ESPERADA TIENE QUE SER MAYOR QUE CERO (HORAS).', 16, 1)
    RETURN -1
END

INSERT INTO [dbo].[Activo_Variable]
    (ava_cliente, ava_activo, ava_activo_componente, ava_variable_medicion, ava_unidad_medida,
     ava_valor_minimo, ava_valor_maximo, ava_valor_advertencia, ava_valor_critico, ava_frecuencia_esperada_hora,
     ava_usuario_creacion, ava_fecha_creacion, ava_usuario_actualizacion, ava_fecha_actualizacion, ava_habilitado)
VALUES
    (@CLIENTE, @ACTIVO, @ACTIVO_COMPONENTE, @VARIABLE_MEDICION, @UNIDAD_MEDIDA,
     @VALOR_MINIMO, @VALOR_MAXIMO, @VALOR_ADVERTENCIA, @VALOR_CRITICO, @FRECUENCIA_ESPERADA_HORA,
     @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()

IF @ID IS NULL
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ACTIVO_VARIABLE', @MSG = '7.- NO FUE POSIBLE GUARDAR LA VARIABLE DEL EQUIPO.'
    RETURN -1
END

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 4) UPD_ACTIVO_VARIABLE — equipo y variable no cambian; umbrales, unidad y frecuencia si
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_VARIABLE]
@ID                       INT,
@CLIENTE                  INT,
@UNIDAD_MEDIDA            INT = NULL,
@VALOR_MINIMO             DECIMAL(18,6) = NULL,
@VALOR_MAXIMO             DECIMAL(18,6) = NULL,
@VALOR_ADVERTENCIA        DECIMAL(18,6) = NULL,
@VALOR_CRITICO            DECIMAL(18,6) = NULL,
@FRECUENCIA_ESPERADA_HORA INT = NULL,
@HABILITADO               BIT = NULL,
@QUITA_MINIMO             BIT = 0,
@QUITA_MAXIMO             BIT = 0,
@QUITA_ADVERTENCIA        BIT = 0,
@QUITA_CRITICO            BIT = 0,
@QUITA_FRECUENCIA         BIT = 0,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] WHERE ava_id = @ID AND ava_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA VARIABLE DEL EQUIPO NO EXISTE.', 16, 1)
    RETURN -1
END

-- Lo que va a quedar, para validar el orden de los umbrales
DECLARE @MIN DECIMAL(18,6), @MAX DECIMAL(18,6), @ADV DECIMAL(18,6), @CRI DECIMAL(18,6)
SELECT @MIN = CASE WHEN @QUITA_MINIMO = 1 THEN NULL ELSE ISNULL(@VALOR_MINIMO, ava_valor_minimo) END,
       @MAX = CASE WHEN @QUITA_MAXIMO = 1 THEN NULL ELSE ISNULL(@VALOR_MAXIMO, ava_valor_maximo) END,
       @ADV = CASE WHEN @QUITA_ADVERTENCIA = 1 THEN NULL ELSE ISNULL(@VALOR_ADVERTENCIA, ava_valor_advertencia) END,
       @CRI = CASE WHEN @QUITA_CRITICO = 1 THEN NULL ELSE ISNULL(@VALOR_CRITICO, ava_valor_critico) END
FROM   [dbo].[Activo_Variable] WHERE ava_id = @ID

IF [dbo].[FNC_ACTIVO_VARIABLE_UMBRALES_OK](@MIN, @ADV, @CRI, @MAX) = 0
BEGIN
    RAISERROR('2.- LOS UMBRALES TIENEN QUE IR EN ORDEN: MÍNIMO <= ADVERTENCIA <= CRÍTICO <= MÁXIMO.', 16, 1)
    RETURN -1
END

IF @FRECUENCIA_ESPERADA_HORA IS NOT NULL AND @FRECUENCIA_ESPERADA_HORA <= 0
BEGIN
    RAISERROR('3.- LA FRECUENCIA ESPERADA TIENE QUE SER MAYOR QUE CERO (HORAS).', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Activo_Variable]
SET ava_unidad_medida            = ISNULL(@UNIDAD_MEDIDA, ava_unidad_medida),
    ava_valor_minimo             = @MIN,
    ava_valor_maximo             = @MAX,
    ava_valor_advertencia        = @ADV,
    ava_valor_critico            = @CRI,
    ava_frecuencia_esperada_hora = CASE WHEN @QUITA_FRECUENCIA = 1 THEN NULL ELSE ISNULL(@FRECUENCIA_ESPERADA_HORA, ava_frecuencia_esperada_hora) END,
    ava_habilitado               = ISNULL(@HABILITADO, ava_habilitado),
    ava_usuario_actualizacion    = @USUARIO,
    ava_fecha_actualizacion      = @DATE_NOW
WHERE ava_id = @ID

IF @@ROWCOUNT = 0
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_ACTIVO_VARIABLE', @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA VARIABLE DEL EQUIPO.'
    RETURN -1
END

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 5) DEL_ACTIVO_VARIABLE — logico; con condiciones activas o mediciones no se apaga sin aviso
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_VARIABLE]
@ID      INT,
@CLIENTE INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] WHERE ava_id = @ID AND ava_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA VARIABLE DEL EQUIPO NO EXISTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Programacion_Condicion] c JOIN [dbo].[Programacion] p ON p.pro_id = c.pco_programacion
           WHERE c.pco_activo_variable = @ID AND c.pco_habilitado = 1 AND p.pro_habilitado = 1)
BEGIN
    RAISERROR('2.- UNA PROGRAMACIÓN POR CONDICIÓN VIGILA ESTA VARIABLE; QUITE LA CONDICIÓN ANTES.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Activo_Variable]
SET ava_habilitado = 0, ava_usuario_actualizacion = @USUARIO, ava_fecha_actualizacion = @DATE_NOW
WHERE ava_id = @ID

IF @@ROWCOUNT = 0
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'DEL_ACTIVO_VARIABLE', @MSG = '3.- NO FUE POSIBLE DESHABILITAR LA VARIABLE.'
    RETURN -1
END

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 6) Permisos y menu: junto a Medidores, mismos perfiles que VER MEDIDORES
-- ---------------------------------------------------------------------------
DECLARE @HOY DATETIME = GETDATE()
DECLARE @VER_MED INT = (SELECT mnu_permiso FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Medidores/ActivoMedidores.aspx')
DECLARE @EDITAR_MED INT = (SELECT TOP 1 mfu_permiso FROM [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
                           WHERE m.mnu_link = '~/View/Activos/Medidores/ActivoMedidores.aspx' AND mf.mfu_nombre = 'Crear y editar')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER VARIABLES ACTIVO')
    INSERT INTO [dbo].[Permiso] (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'VER VARIABLES ACTIVO', 'Ver variables de condición de los activos', p.prm_modulo, p.prm_permiso_ambito,
           'Consultar qué variables mide cada equipo y con qué umbrales', p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM [dbo].[Permiso] p WHERE p.prm_id = @VER_MED

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR VARIABLES ACTIVO')
    INSERT INTO [dbo].[Permiso] (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'CREAR EDITAR VARIABLES ACTIVO', 'Crear y editar variables de condición', p.prm_modulo, p.prm_permiso_ambito,
           'Definir qué variables mide cada equipo, su unidad y sus umbrales', p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM [dbo].[Permiso] p WHERE p.prm_id = ISNULL(@EDITAR_MED, @VER_MED)

DECLARE @VER INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER VARIABLES ACTIVO')
DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR VARIABLES ACTIVO')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @VER, pp.ppe_usuario_creacion, @HOY FROM [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @VER_MED
  AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @VER)
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @EDITAR, pp.ppe_usuario_creacion, @HOY FROM [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = ISNULL(@EDITAR_MED, @VER_MED)
  AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @EDITAR)

DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Medidores/ActivoMedidores.aspx')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(mnu_orden) FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_orden < 99), 0) + 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Variables/ActivoVariables.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Variables de condición', 'Qué mide cada equipo y con qué umbrales', 3, @PADRE, @ORDEN,
            '~/View/Activos/Variables/ActivoVariables.aspx', 1, 'mdi mdi-thermometer-lines', @VER, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Variables/ActivoVariable.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Variable de condición (detalle)', 'Ficha de una variable de un equipo', 3, @PADRE, 99,
            '~/View/Activos/Variables/ActivoVariable.aspx', 0, '', @VER, 1)

DECLARE @M INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Activos/Variables/ActivoVariables.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @EDITAR)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @M, @EDITAR)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('SEL_ACTIVO_VARIABLE','INS_ACTIVO_VARIABLE','UPD_ACTIVO_VARIABLE','DEL_ACTIVO_VARIABLE')) AS VARCHAR) + ' de 4' AS RESULTADO
UNION ALL SELECT 'pme_activo_medidor nullable = ' + CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Programacion_Medidor') AND name = 'pme_activo_medidor' AND is_nullable = 1) THEN 'SI' ELSE 'NO' END
UNION ALL SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Activos/Variables/%') AS VARCHAR) + ' de 2'
GO
