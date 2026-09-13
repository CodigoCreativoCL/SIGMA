USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA HITOS DE PLAN (T-4023).
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   Filas de ejemplo para ejercitar HU-081. Corre despues de
--   _SEMILLA_PLANES_MANTENIMIENTO.sql, porque un hito sin plan no existe.
--
--   Tambien crea UNA programacion, porque `Programacion` estaba en cero y un
--   hito sin programacion no se puede guardar: es la FK que dice «cada
--   cuanto». Se crea por INS_PROGRAMACION + UPS_PROGRAMACION_INTERVALO, que
--   es como la crea la pantalla de Programaciones.
--
-- LOS CASOS
--
--   1. Un hito mensual normal, con duracion y prioridad.
--   2. Un overhaul con parada, para que las marcas de la grilla tengan algo
--      que marcar.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @PLAN    INT = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-HORNOS-L1')
DECLARE @PROG    INT, @PROG6 INT, @ID INT

IF (@PLAN IS NULL OR @USUARIO IS NULL)
BEGIN
    RAISERROR('1.- CORRA _SEMILLA_PLANES_MANTENIMIENTO.sql ANTES.', 16, 1)
    RETURN
END

-- ---------------------------------------------------------------------------
-- Una programacion: cada 1 mes, desde hoy
-- ---------------------------------------------------------------------------
SET @PROG = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Mensual (semilla)')

IF (@PROG IS NULL)
BEGIN
    EXEC [dbo].[INS_PROGRAMACION]
         @ID = @PROG OUTPUT, @CLIENTE = @CLIENTE, @TIPO = 4,   -- INTERVALO TIEMPO
         @NOMBRE = N'Mensual (semilla)', @FECHA_INICIO = '2026-01-01', @FECHA_FIN = NULL,
         @ZONA_HORARIA = 1, @TOLERANCIA_ANTES = 1440, @TOLERANCIA_DESPUES = 4320,
         @PERMITE_ANTICIPADA = 1, @PERMITE_ATRASADA = 1, @CUMPLIMIENTO_POLITICA = 1,
         @GENERA_AUTOMATICAMENTE = 1, @INSTALACION = NULL, @AREA = NULL, @ACTIVO = NULL, @GRUPO = NULL,
         @USUARIO = @USUARIO

    EXEC [dbo].[UPS_PROGRAMACION_INTERVALO]
         @ID = @ID OUTPUT, @PROGRAMACION = @PROG, @CLIENTE = @CLIENTE,
         @UNIDAD_TIEMPO = 5,   -- MES
         @CANTIDAD = 1, @FECHA_ANCLA_UTC = '2026-01-01', @DESDE_EJECUCION = 0,
         @USUARIO = @USUARIO
END

-- ---------------------------------------------------------------------------
-- Otra programacion para el overhaul: cada 6 meses
--
--   Dos hitos del mismo plan NO pueden compartir programacion: la ocurrencia
--   es unica por (programacion, equipo, fecha) -UX_PMO_PROGRAMACION_ACTIVO_
--   FECHA- y el segundo hito chocaria con el primero al generar. Un
--   overhaul mensual tampoco tenia sentido.
-- ---------------------------------------------------------------------------
SET @PROG6 = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Semestral (semilla)')

IF (@PROG6 IS NULL)
BEGIN
    EXEC [dbo].[INS_PROGRAMACION]
         @ID = @PROG6 OUTPUT, @CLIENTE = @CLIENTE, @TIPO = 4,   -- INTERVALO TIEMPO
         @NOMBRE = N'Semestral (semilla)', @FECHA_INICIO = '2026-01-01', @FECHA_FIN = NULL,
         @ZONA_HORARIA = 1, @TOLERANCIA_ANTES = 10080, @TOLERANCIA_DESPUES = 20160,
         @PERMITE_ANTICIPADA = 1, @PERMITE_ATRASADA = 1, @CUMPLIMIENTO_POLITICA = 1,
         @GENERA_AUTOMATICAMENTE = 1, @INSTALACION = NULL, @AREA = NULL, @ACTIVO = NULL, @GRUPO = NULL,
         @USUARIO = @USUARIO

    EXEC [dbo].[UPS_PROGRAMACION_INTERVALO]
         @ID = @ID OUTPUT, @PROGRAMACION = @PROG6, @CLIENTE = @CLIENTE,
         @UNIDAD_TIEMPO = 5,   -- MES
         @CANTIDAD = 6, @FECHA_ANCLA_UTC = '2026-03-15', @DESDE_EJECUCION = 0,
         @USUARIO = @USUARIO
END

-- ---------------------------------------------------------------------------
-- Dos hitos sobre el borrador del plan de hornos
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
               WHERE v.pmv_plan_mantenimiento = @PLAN AND h.pmh_codigo = 'LUB-MENSUAL')
    EXEC [dbo].[INS_PLAN_HITO]
         @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN, @PROGRAMACION = @PROG,
         @CODIGO = N'LUB-MENSUAL', @NOMBRE = N'Lubricación de cadenas y rodamientos',
         @ORDEN = 1, @DURACION_ESTIMADA_MINUTO = 90,
         @ORDEN_TRABAJO_TIPO = 1, @ORDEN_TRABAJO_PRIORIDAD = 2,
         @DESCRIPCION = N'Engrase de cadena de transporte y rodamientos de los ventiladores.',
         @USUARIO = @USUARIO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
               WHERE v.pmv_plan_mantenimiento = @PLAN AND h.pmh_codigo = 'OVH-QUEMADOR')
    EXEC [dbo].[INS_PLAN_HITO]
         @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN, @PROGRAMACION = @PROG6,
         @CODIGO = N'OVH-QUEMADOR', @NOMBRE = N'Overhaul del quemador',
         @ORDEN = 2, @DURACION_ESTIMADA_MINUTO = 480,
         @ES_OVERHAUL = 1, @REQUIERE_PARADA = 1,
         @ORDEN_TRABAJO_TIPO = 1, @ORDEN_TRABAJO_PRIORIDAD = 3,
         @DESCRIPCION = N'Desmontaje, limpieza y calibración completa del quemador. Línea detenida.',
         @USUARIO = @USUARIO
GO

-- ---------------------------------------------------------------------------
-- Verificacion: lo que va a mostrar la grilla
-- ---------------------------------------------------------------------------
SELECT pma.pma_codigo + ' v' + CAST(pmv.pmv_numero AS VARCHAR) + ' · #' + CAST(pmh.pmh_orden AS VARCHAR) + ' ' + pmh.pmh_codigo
       + ' · ' + pro.pro_nombre + ' · parada=' + CAST(pmh.pmh_requiere_parada AS VARCHAR)
       + ' · overhaul=' + CAST(pmh.pmh_es_overhaul AS VARCHAR) AS RESULTADO
FROM   [dbo].[Plan_Mantenimiento_Hito] pmh
JOIN   [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN   [dbo].[Programacion] pro ON pro.pro_id = pmh.pmh_programacion
WHERE  pma.pma_cliente = 1
ORDER BY pma.pma_codigo, pmh.pmh_orden
GO
