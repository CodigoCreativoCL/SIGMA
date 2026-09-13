USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     CALENDARIO DE MANTENIMIENTO DE UN PLAN (HU-085).
-- =============================================
-- T-4212 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento_Ocurrencia` es cada vez que a un equipo le toca un
--   hito: (hito, activo, fecha). No tiene codigo -no es algo que alguien
--   nombre- asi que el «indice unico del codigo dentro del cliente» de la
--   plantilla no aplica; lo que la hace unica es UX_PMO_HITO_ACTIVO_FECHA y
--   UX_PMO_PROGRAMACION_ACTIVO_FECHA, y el uuid para el telefono. Trae
--   CK_PMO_LIMITE (la fecha limite no puede ser anterior a la programada),
--   el estado en Plan_Ocurrencia_Estado (1 PENDIENTE ... 7 REPROGRAMADA),
--   la OT que la cumplio y la ocurrencia de origen si fue reprogramada.
--
-- T-4214 · INDICES
--
--   El unico indice de consulta que habia, IX_PMO_CLIENTE_ESTADO_FECHA,
--   parte por el estado: sirve para «las pendientes» pero un calendario
--   -«todo lo del cliente entre enero y diciembre»- no filtra por estado y
--   ese indice no lo cubre. Se agregan uno por cliente + fecha (la consulta
--   del calendario) y uno por activo + fecha (la ficha del equipo, HU-088).
--
-- T-4213 · SEL_PLAN_CALENDARIO
--
--   Solo lectura, sin SQL armado: todos los filtros son parametros
--   opcionales con el patron (@X IS NULL OR col = @X). Pagina con OFFSET /
--   FETCH y devuelve TOTAL en cada fila para que la grilla sepa cuantas hay
--   sin una segunda consulta. La SITUACION no se guarda: se deriva de las
--   fechas contra hoy, como en VW_PLAN_OCURRENCIA_PENDIENTE, para que el
--   calendario no dependa de un job que «venza» filas cada noche.
--
--   Las fechas salen en UTC tal como estan guardadas. El calendario se mira
--   a dia, no a hora, y una diferencia de tres o cuatro horas no cambia el
--   dia salvo en la medianoche; convertir por la zona de la programacion
--   es trabajo de HU-076 cuando genere de verdad.
--
-- LA EXPORTACION VA EN OTRO SP
--
--   RPT_PLAN_CALENDARIO_EXCEL devuelve lo mismo con los encabezados como los
--   lee una persona y sin paginar: el patron de RPT_REPUESTO_EXCEL, que
--   Tools.Excel vuelca tal cual a la planilla.
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) Indices de apoyo (T-4214)
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PMO_CLIENTE_FECHA' AND object_id = OBJECT_ID('dbo.Plan_Mantenimiento_Ocurrencia'))
    CREATE NONCLUSTERED INDEX [IX_PMO_CLIENTE_FECHA]
        ON [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_cliente], [pmo_fecha_programada_utc])
        INCLUDE ([pmo_plan_mantenimiento_hito], [pmo_activo], [pmo_plan_ocurrencia_estado], [pmo_habilitado])
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PMO_ACTIVO_FECHA' AND object_id = OBJECT_ID('dbo.Plan_Mantenimiento_Ocurrencia'))
    CREATE NONCLUSTERED INDEX [IX_PMO_ACTIVO_FECHA]
        ON [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_activo], [pmo_fecha_programada_utc])
        INCLUDE ([pmo_plan_mantenimiento_hito], [pmo_plan_ocurrencia_estado], [pmo_habilitado])
GO

-- ---------------------------------------------------------------------------
-- 2) SEL_PLAN_CALENDARIO (T-4213)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CALENDARIO]
    @CLIENTE        INT,
    @PLAN           INT           = NULL,
    @ACTIVO         INT           = NULL,
    @INSTALACION    INT           = NULL,
    @ESTADO         INT           = NULL,
    @DESDE          DATE          = NULL,
    @HASTA          DATE          = NULL,
    @FILTRO         NVARCHAR(200) = NULL,
    @PAGINA         INT           = NULL,
    @TAMANO         INT           = NULL
AS
BEGIN
    SET NOCOUNT ON

    -- Sin rango, el calendario es el año en curso: es lo que dice la historia.
    IF (@DESDE IS NULL AND @HASTA IS NULL)
    BEGIN
        SET @DESDE = DATEFROMPARTS(YEAR(GETUTCDATE()), 1, 1)
        SET @HASTA = DATEFROMPARTS(YEAR(GETUTCDATE()), 12, 31)
    END

    IF (@PAGINA IS NULL OR @PAGINA < 1)  SET @PAGINA = 1
    IF (@TAMANO IS NULL OR @TAMANO < 1)  SET @TAMANO = 1000000

    DECLARE @HOY DATETIME = GETUTCDATE()

    SELECT  pmo.pmo_id                                  AS PMO_ID,
            pmo.pmo_uuid                                AS PMO_UUID,
            pmo.pmo_fecha_programada_utc                AS FECHA_PROGRAMADA,
            pmo.pmo_fecha_limite_utc                    AS FECHA_LIMITE,
            pmo.pmo_fecha_disponible_utc                AS FECHA_DISPONIBLE,
            pmo.pmo_fecha_programada_original_utc       AS FECHA_ORIGINAL,
            FORMAT(pmo.pmo_fecha_programada_utc, 'yyyy-MM') AS MES,
            pma.pma_id                                  AS PLAN_ID,
            pma.pma_codigo                              AS PLAN_CODIGO,
            pma.pma_nombre                              AS PLAN_NOMBRE,
            pmv.pmv_numero                              AS VERSION_NUMERO,
            pmh.pmh_id                                  AS HITO_ID,
            pmh.pmh_codigo                              AS HITO_CODIGO,
            pmh.pmh_nombre                              AS HITO_NOMBRE,
            pmh.pmh_es_overhaul                         AS ES_OVERHAUL,
            pmh.pmh_requiere_parada                     AS REQUIERE_PARADA,
            pmh.pmh_duracion_estimada_minuto            AS DURACION_ESTIMADA_MINUTO,
            act.act_id                                  AS ACTIVO_ID,
            act.act_codigo                              AS ACTIVO_CODIGO,
            act.act_nombre                              AS ACTIVO_NOMBRE,
            cin.cin_nombre                              AS PLANTA_NOMBRE,
            aco.aco_nombre                              AS COMPONENTE_NOMBRE,
            pmo.pmo_valor_medidor_objetivo              AS VALOR_MEDIDOR_OBJETIVO,
            poe.poe_id                                  AS ESTADO_ID,
            poe.poe_codigo                              AS ESTADO_CODIGO,
            poe.poe_nombre                              AS ESTADO_NOMBRE,
            /* La situacion se deriva, no se guarda: si se guardara habria
               que «vencer» filas cada noche y el dia que ese job falle el
               calendario miente. */
            CASE
                WHEN poe.poe_id IN (4, 5, 6, 7)                                                   THEN 'CERRADA'
                WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY     THEN 'VENCIDA'
                WHEN pmo.pmo_fecha_programada_utc < @HOY                                          THEN 'ATRASADA'
                WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                ELSE 'FUTURA'
            END                                         AS SITUACION,
            DATEDIFF(DAY, @HOY, pmo.pmo_fecha_programada_utc) AS DIAS_RESTANTES,
            CASE WHEN pmo.pmo_ocurrencia_origen IS NULL THEN 0 ELSE 1 END AS FUE_REPROGRAMADA,
            otr.otr_id                                  AS ORDEN_TRABAJO_ID,
            otr.otr_correlativo                         AS ORDEN_TRABAJO_CORRELATIVO,
            otr.otr_titulo                              AS ORDEN_TRABAJO_TITULO,
            pmo.pmo_observacion                         AS OBSERVACION,
            COUNT(*) OVER ()                            AS TOTAL
    FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
    JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id  = pmo.pmo_plan_mantenimiento_hito
    JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id  = pmh.pmh_plan_mantenimiento_version
    JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id  = pmv.pmv_plan_mantenimiento
    JOIN    [dbo].[Activo]                     act ON act.act_id  = pmo.pmo_activo
    JOIN    [dbo].[Plan_Ocurrencia_Estado]     poe ON poe.poe_id  = pmo.pmo_plan_ocurrencia_estado
    LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id  = act.act_cliente_instalacion
    LEFT JOIN [dbo].[Activo_Componente]        aco ON aco.aco_id  = pmo.pmo_activo_componente
    LEFT JOIN [dbo].[Orden_Trabajo]            otr ON otr.otr_id  = pmo.pmo_orden_trabajo
    WHERE   pmo.pmo_cliente   = @CLIENTE
      AND   pmo.pmo_habilitado = 1
      AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
      AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
      AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
      AND   (@ESTADO      IS NULL OR poe.poe_id = @ESTADO)
      AND   (@DESDE       IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
      AND   (@HASTA       IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
      AND   (@FILTRO      IS NULL OR act.act_codigo  LIKE '%' + @FILTRO + '%'
                                  OR act.act_nombre  LIKE '%' + @FILTRO + '%'
                                  OR pmh.pmh_codigo  LIKE '%' + @FILTRO + '%'
                                  OR pmh.pmh_nombre  LIKE '%' + @FILTRO + '%'
                                  OR pma.pma_codigo  LIKE '%' + @FILTRO + '%'
                                  OR pma.pma_nombre  LIKE '%' + @FILTRO + '%')
    ORDER BY pmo.pmo_fecha_programada_utc, pma.pma_codigo, act.act_codigo, pmh.pmh_orden
    OFFSET (@PAGINA - 1) * @TAMANO ROWS
    FETCH NEXT @TAMANO ROWS ONLY
END
GO

-- ---------------------------------------------------------------------------
-- 3) RPT_PLAN_CALENDARIO_EXCEL — lo que se ve, para llevarselo (T-4218)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[RPT_PLAN_CALENDARIO_EXCEL]
    @CLIENTE        INT,
    @PLAN           INT           = NULL,
    @ACTIVO         INT           = NULL,
    @INSTALACION    INT           = NULL,
    @ESTADO         INT           = NULL,
    @DESDE          DATE          = NULL,
    @HASTA          DATE          = NULL,
    @FILTRO         NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @T TABLE (
        PMO_ID INT, PMO_UUID UNIQUEIDENTIFIER, FECHA_PROGRAMADA DATETIME, FECHA_LIMITE DATETIME, FECHA_DISPONIBLE DATETIME,
        FECHA_ORIGINAL DATETIME, MES NVARCHAR(7), PLAN_ID INT, PLAN_CODIGO NVARCHAR(500), PLAN_NOMBRE NVARCHAR(2000),
        VERSION_NUMERO INT, HITO_ID INT, HITO_CODIGO NVARCHAR(500), HITO_NOMBRE NVARCHAR(2000), ES_OVERHAUL BIT,
        REQUIERE_PARADA BIT, DURACION_ESTIMADA_MINUTO INT, ACTIVO_ID INT, ACTIVO_CODIGO NVARCHAR(500), ACTIVO_NOMBRE NVARCHAR(2000),
        PLANTA_NOMBRE NVARCHAR(2000), COMPONENTE_NOMBRE NVARCHAR(2000), VALOR_MEDIDOR_OBJETIVO DECIMAL(18,4), ESTADO_ID INT,
        ESTADO_CODIGO NVARCHAR(500), ESTADO_NOMBRE NVARCHAR(500), SITUACION NVARCHAR(20), DIAS_RESTANTES INT, FUE_REPROGRAMADA INT,
        ORDEN_TRABAJO_ID INT, ORDEN_TRABAJO_CORRELATIVO INT, ORDEN_TRABAJO_TITULO NVARCHAR(2000), OBSERVACION NVARCHAR(2000), TOTAL INT)

    INSERT INTO @T
    EXEC [dbo].[SEL_PLAN_CALENDARIO] @CLIENTE = @CLIENTE, @PLAN = @PLAN, @ACTIVO = @ACTIVO, @INSTALACION = @INSTALACION,
                                     @ESTADO = @ESTADO, @DESDE = @DESDE, @HASTA = @HASTA, @FILTRO = @FILTRO

    SELECT  CONVERT(VARCHAR(10), FECHA_PROGRAMADA, 103)              AS [FECHA],
            CASE DATENAME(WEEKDAY, FECHA_PROGRAMADA)
                 WHEN 'Monday' THEN 'Lunes' WHEN 'Tuesday' THEN 'Martes' WHEN 'Wednesday' THEN 'Miércoles'
                 WHEN 'Thursday' THEN 'Jueves' WHEN 'Friday' THEN 'Viernes' WHEN 'Saturday' THEN 'Sábado'
                 WHEN 'Sunday' THEN 'Domingo' ELSE DATENAME(WEEKDAY, FECHA_PROGRAMADA) END AS [DIA],
            MES                                                       AS [MES],
            PLAN_CODIGO                                               AS [PLAN],
            PLAN_NOMBRE                                               AS [NOMBRE PLAN],
            'v' + CAST(VERSION_NUMERO AS VARCHAR)                     AS [VERSION],
            HITO_CODIGO                                               AS [HITO],
            HITO_NOMBRE                                               AS [NOMBRE HITO],
            ACTIVO_CODIGO                                             AS [EQUIPO],
            ACTIVO_NOMBRE                                             AS [NOMBRE EQUIPO],
            ISNULL(PLANTA_NOMBRE, '')                                 AS [PLANTA],
            ISNULL(COMPONENTE_NOMBRE, 'Equipo completo')              AS [COMPONENTE],
            CASE WHEN REQUIERE_PARADA = 1 THEN 'SI' ELSE 'NO' END     AS [REQUIERE PARADA],
            CASE WHEN ES_OVERHAUL = 1 THEN 'SI' ELSE 'NO' END         AS [OVERHAUL],
            DURACION_ESTIMADA_MINUTO                                  AS [DURACION MIN],
            ESTADO_NOMBRE                                             AS [ESTADO],
            SITUACION                                                 AS [SITUACION],
            CASE WHEN FECHA_LIMITE IS NULL THEN '' ELSE CONVERT(VARCHAR(10), FECHA_LIMITE, 103) END AS [FECHA LIMITE],
            CASE WHEN ORDEN_TRABAJO_CORRELATIVO IS NULL THEN '' ELSE 'OT-' + CAST(ORDEN_TRABAJO_CORRELATIVO AS VARCHAR) END AS [ORDEN DE TRABAJO],
            ISNULL(OBSERVACION, '')                                   AS [OBSERVACION]
    FROM    @T
    ORDER BY FECHA_PROGRAMADA, PLAN_CODIGO, ACTIVO_CODIGO
END
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('SEL_PLAN_CALENDARIO','RPT_PLAN_CALENDARIO_EXCEL')) AS VARCHAR) + ' de 2' AS RESULTADO
UNION ALL
SELECT 'Indices = ' + CAST((SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Plan_Mantenimiento_Ocurrencia')
                            AND name IN ('IX_PMO_CLIENTE_FECHA','IX_PMO_ACTIVO_FECHA')) AS VARCHAR) + ' de 2'
GO
