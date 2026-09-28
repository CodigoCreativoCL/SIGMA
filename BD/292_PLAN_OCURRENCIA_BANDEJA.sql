USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     BANDEJA DE OCURRENCIAS PENDIENTES (HU-087).
-- =============================================
-- T-4178 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento_Ocurrencia` es cada vez que a un equipo le toca un
--   hito: (hito, activo, fecha). No tiene codigo -no es algo que alguien
--   nombre-, asi que el "indice unico del codigo dentro del cliente" de la
--   plantilla no aplica: lo que la hace unica es UX_PMO_HITO_ACTIVO_FECHA y
--   UX_PMO_PROGRAMACION_ACTIVO_FECHA, mas UX_PMO_UUID para el telefono. Ya
--   estaba revisado en el bloque 216 y no cambio nada desde entonces.
--
-- POR QUE UN SP PROPIO Y NO UN PARAMETRO MAS EN SEL_PLAN_CALENDARIO
--
--   Se parecen, y esa es la trampa. El calendario responde "que le toca a
--   ESTE plan este año" y lo ordena por fecha para dibujar meses. La bandeja
--   responde "que tengo encima AHORA, de todos los planes", y para eso hace
--   dos cosas que el calendario no puede:
--
--     1. FILTRA POR SITUACION, que es una columna derivada. Vencida,
--        atrasada, disponible y futura no existen en ninguna tabla: se
--        calculan comparando fechas contra ahora. Para filtrar por ellas hay
--        que calcularlas primero -de ahi el CTE-, y el calendario filtra por
--        ESTADO, que es un dato guardado. Son dos preguntas distintas con la
--        misma cara.
--
--     2. DEVUELVE EL RESUMEN. La bandeja abre con "7 vencidas, 2 atrasadas":
--        esos numeros son de TODO lo que cumple el filtro, no de la pagina
--        que se esta mirando, asi que no salen de contar filas en la
--        pantalla. Van en un segundo result set, como SEL_MENUS_PERMISOS_MAPA.
--
--   Meter las dos intenciones en un SP obliga a cada llamador a cargar con
--   las banderas del otro, y a quien lo lea a adivinar cual esta viendo.
--
-- LA SITUACION SE DERIVA, NO SE GUARDA
--
--   Es el criterio 2 de la historia, y esta dicho ahi con todas sus letras:
--   "esa condicion se calcula al consultar, no depende de un proceso
--   nocturno". Si se guardara habria que "vencer" filas cada noche, y el dia
--   que ese job falle la bandeja miente diciendo que no hay nada atrasado.
--
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) Indice de apoyo (T-4180)
-- ---------------------------------------------------------------------------
/* Los que ya estan -IX_PMO_CLIENTE_ESTADO_FECHA, IX_PMO_CLIENTE_FECHA,
   IX_PMO_ACTIVO_FECHA- cubren al calendario y a la ficha del equipo. A la
   bandeja no del todo: su consulta es "del cliente, lo que NO esta cerrado,
   por fecha", y un NOT IN sobre la segunda columna de la clave obliga a
   recorrer todo el rango del cliente, cerradas incluidas. Con el tiempo las
   cerradas son la mayoria -se acumulan para siempre y las abiertas no-, asi
   que ese recorrido crece sin que crezca lo que se busca.

   Un indice FILTRADO deja fuera las cerradas de raiz: ocupa lo que ocupan
   las abiertas y no cambia de tamaño porque el historial engorde. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PMO_ABIERTAS' AND object_id = OBJECT_ID('dbo.Plan_Mantenimiento_Ocurrencia'))
    CREATE NONCLUSTERED INDEX [IX_PMO_ABIERTAS]
        ON [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_cliente], [pmo_fecha_programada_utc])
        INCLUDE ([pmo_plan_mantenimiento_hito], [pmo_activo], [pmo_plan_ocurrencia_estado],
                 [pmo_fecha_limite_utc], [pmo_fecha_disponible_utc], [pmo_orden_trabajo])
        WHERE [pmo_plan_ocurrencia_estado] IN (1, 2, 3) AND [pmo_habilitado] = 1
GO
PRINT '--- IX_PMO_ABIERTAS verificado.'
GO

-- ---------------------------------------------------------------------------
-- 2) SEL_PLAN_OCURRENCIA_BANDEJA (T-4179)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_OCURRENCIA_BANDEJA]
    @CLIENTE        INT,
    @SITUACION      VARCHAR(20)   = NULL,   -- VENCIDA / ATRASADA / DISPONIBLE / FUTURA / CERRADA
    @PLAN           INT           = NULL,
    @ACTIVO         INT           = NULL,
    @INSTALACION    INT           = NULL,
    @ESTADO         INT           = NULL,
    @DESDE          DATE          = NULL,
    @HASTA          DATE          = NULL,
    @SOLO_ABIERTAS  BIT           = 1,
    @SOLO_PARADA    BIT           = NULL,
    @FILTRO         NVARCHAR(200) = NULL,
    @PAGINA         INT           = NULL,
    @TAMANO         INT           = NULL
AS
BEGIN
    SET NOCOUNT ON

    IF (@PAGINA IS NULL OR @PAGINA < 1)  SET @PAGINA = 1
    IF (@TAMANO IS NULL OR @TAMANO < 1)  SET @TAMANO = 1000000

    SET @SITUACION = NULLIF(LTRIM(RTRIM(UPPER(ISNULL(@SITUACION, '')))), '')

    DECLARE @HOY DATETIME = GETUTCDATE()

    /* El CTE existe para poder FILTRAR por la situacion. Calcularla en el
       SELECT y repetir el CASE entero en el WHERE es la otra forma, y es la
       que se desincroniza: alguien corrige una de las dos copias. */
    ;WITH ocu AS (
        SELECT  pmo.pmo_id,
                pmo.pmo_uuid,
                pmo.pmo_fecha_programada_utc,
                pmo.pmo_fecha_limite_utc,
                pmo.pmo_fecha_disponible_utc,
                pmo.pmo_fecha_programada_original_utc,
                pmo.pmo_ocurrencia_origen,
                pmo.pmo_valor_medidor_objetivo,
                pmo.pmo_observacion,
                pmo.pmo_orden_trabajo,
                pmo.pmo_plan_mantenimiento_hito,
                pmo.pmo_activo,
                pmo.pmo_activo_componente,
                pmo.pmo_plan_ocurrencia_estado,
                CASE
                    WHEN pmo.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7)                                    THEN 'CERRADA'
                    WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY          THEN 'VENCIDA'
                    WHEN pmo.pmo_fecha_programada_utc < @HOY                                               THEN 'ATRASADA'
                    WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                    ELSE 'FUTURA'
                END AS SITUACION
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          /* La bandeja es de lo que hay que hacer. Las cerradas se piden a
             proposito, con @SOLO_ABIERTAS = 0, y entonces se ven todas. */
          AND   (ISNULL(@SOLO_ABIERTAS, 1) = 0 OR pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3))
          AND   (@ESTADO IS NULL OR pmo.pmo_plan_ocurrencia_estado = @ESTADO)
          AND   (@DESDE  IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA  IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
    ),
    filtrada AS (
        SELECT  o.*,
                pma.pma_id      AS PLAN_ID,
                pma.pma_codigo  AS PLAN_CODIGO,
                pma.pma_nombre  AS PLAN_NOMBRE,
                pmv.pmv_numero  AS VERSION_NUMERO,
                pmh.pmh_id      AS HITO_ID,
                pmh.pmh_codigo  AS HITO_CODIGO,
                pmh.pmh_nombre  AS HITO_NOMBRE,
                pmh.pmh_es_overhaul               AS ES_OVERHAUL,
                pmh.pmh_requiere_parada           AS REQUIERE_PARADA,
                pmh.pmh_duracion_estimada_minuto  AS DURACION_ESTIMADA_MINUTO,
                act.act_id      AS ACTIVO_ID,
                act.act_codigo  AS ACTIVO_CODIGO,
                act.act_nombre  AS ACTIVO_NOMBRE,
                act.act_cliente_instalacion AS INSTALACION_ID,
                cin.cin_nombre  AS PLANTA_NOMBRE,
                aco.aco_nombre  AS COMPONENTE_NOMBRE,
                poe.poe_id      AS ESTADO_ID,
                poe.poe_codigo  AS ESTADO_CODIGO,
                poe.poe_nombre  AS ESTADO_NOMBRE,
                otr.otr_id          AS ORDEN_TRABAJO_ID,
                otr.otr_correlativo AS ORDEN_TRABAJO_CORRELATIVO,
                otr.otr_titulo      AS ORDEN_TRABAJO_TITULO,
                /* Cuantas actividades trae el hito: una ocurrencia cuyo hito
                   no tiene ninguna genera una orden con un solo paso -el
                   hito- y conviene saberlo antes de generarla. */
                ISNULL(actv.cuantas, 0) AS ACTIVIDADES
        FROM    ocu o
        JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = o.pmo_plan_mantenimiento_hito
        JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
        JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
        JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
        JOIN    [dbo].[Plan_Ocurrencia_Estado]     poe ON poe.poe_id = o.pmo_plan_ocurrencia_estado
        LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = act.act_cliente_instalacion
        LEFT JOIN [dbo].[Activo_Componente]        aco ON aco.aco_id = o.pmo_activo_componente
        LEFT JOIN [dbo].[Orden_Trabajo]            otr ON otr.otr_id = o.pmo_orden_trabajo
        OUTER APPLY (SELECT COUNT(*) AS cuantas FROM [dbo].[Plan_Mantenimiento_Actividad] a
                      WHERE a.paa_plan_mantenimiento_hito = pmh.pmh_id AND a.paa_habilitado = 1) actv
        WHERE   (@SITUACION   IS NULL OR o.SITUACION = @SITUACION)
          AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
          AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
          AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
          AND   (@SOLO_PARADA IS NULL OR pmh.pmh_requiere_parada = @SOLO_PARADA)
          AND   (@FILTRO      IS NULL OR act.act_codigo LIKE '%' + @FILTRO + '%'
                                      OR act.act_nombre LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_codigo LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_nombre LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_codigo LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_nombre LIKE '%' + @FILTRO + '%'
                                      OR cin.cin_nombre LIKE '%' + @FILTRO + '%')
    )
    SELECT  f.pmo_id                                AS PMO_ID,
            f.pmo_uuid                              AS PMO_UUID,
            f.pmo_fecha_programada_utc              AS FECHA_PROGRAMADA,
            f.pmo_fecha_limite_utc                  AS FECHA_LIMITE,
            f.pmo_fecha_disponible_utc              AS FECHA_DISPONIBLE,
            f.pmo_fecha_programada_original_utc     AS FECHA_ORIGINAL,
            f.PLAN_ID, f.PLAN_CODIGO, f.PLAN_NOMBRE, f.VERSION_NUMERO,
            f.HITO_ID, f.HITO_CODIGO, f.HITO_NOMBRE,
            f.ES_OVERHAUL, f.REQUIERE_PARADA, f.DURACION_ESTIMADA_MINUTO,
            f.ACTIVO_ID, f.ACTIVO_CODIGO, f.ACTIVO_NOMBRE, f.INSTALACION_ID,
            f.PLANTA_NOMBRE, f.COMPONENTE_NOMBRE,
            f.pmo_valor_medidor_objetivo            AS VALOR_MEDIDOR_OBJETIVO,
            f.ESTADO_ID, f.ESTADO_CODIGO, f.ESTADO_NOMBRE,
            f.SITUACION,
            f.ACTIVIDADES,
            /* Negativo = ya paso. La pantalla lo lee como "hace N dias" sin
               volver a comparar fechas, que es donde se cuelan los off-by-one. */
            DATEDIFF(DAY, @HOY, f.pmo_fecha_programada_utc) AS DIAS_RESTANTES,
            CASE WHEN f.pmo_fecha_limite_utc IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, @HOY, f.pmo_fecha_limite_utc) END AS DIAS_PARA_LIMITE,
            CASE WHEN f.pmo_ocurrencia_origen IS NULL THEN 0 ELSE 1 END AS FUE_REPROGRAMADA,
            f.ORDEN_TRABAJO_ID, f.ORDEN_TRABAJO_CORRELATIVO, f.ORDEN_TRABAJO_TITULO,
            f.pmo_observacion                       AS OBSERVACION,
            COUNT(*) OVER ()                        AS TOTAL

    FROM    filtrada f

    /* Lo mas urgente primero, y dentro del mismo dia lo que tiene fecha
       limite mas cerca: dos ocurrencias del mismo dia no son igual de
       urgentes si una vence mañana. */
    ORDER BY CASE f.SITUACION
                WHEN 'VENCIDA'    THEN 1
                WHEN 'ATRASADA'   THEN 2
                WHEN 'DISPONIBLE' THEN 3
                WHEN 'FUTURA'     THEN 4
                ELSE 5
             END,
             f.pmo_fecha_programada_utc,
             f.pmo_fecha_limite_utc,
             f.ACTIVO_CODIGO
    OFFSET (@PAGINA - 1) * @TAMANO ROWS
    FETCH NEXT @TAMANO ROWS ONLY

    /* ------------------------------------------------------------------
       Segundo result set: el resumen.

       Cuenta TODO lo que cumple el filtro, no la pagina. Por eso no se puede
       armar contando filas en la pantalla, y por eso no se pide con una
       segunda llamada: seria repetir la misma consulta pesada dos veces.

       El @SITUACION NO se aplica aca a proposito: los contadores son la
       botonera con la que se cambia de situacion, y si se filtraran a si
       mismos, al entrar en "vencidas" el resto marcaria cero y no habria
       como salir.
       ------------------------------------------------------------------ */
    ;WITH ocu2 AS (
        SELECT  CASE
                    WHEN pmo.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7)                                    THEN 'CERRADA'
                    WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY          THEN 'VENCIDA'
                    WHEN pmo.pmo_fecha_programada_utc < @HOY                                               THEN 'ATRASADA'
                    WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                    ELSE 'FUTURA'
                END AS SITUACION,
                pmh.pmh_requiere_parada AS REQUIERE_PARADA
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = pmo.pmo_plan_mantenimiento_hito
        JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
        JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
        JOIN    [dbo].[Activo]                     act ON act.act_id = pmo.pmo_activo
        LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = act.act_cliente_instalacion
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          AND   (ISNULL(@SOLO_ABIERTAS, 1) = 0 OR pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3))
          AND   (@ESTADO      IS NULL OR pmo.pmo_plan_ocurrencia_estado = @ESTADO)
          AND   (@DESDE       IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA       IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
          AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
          AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
          AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
          AND   (@SOLO_PARADA IS NULL OR pmh.pmh_requiere_parada = @SOLO_PARADA)
          AND   (@FILTRO      IS NULL OR act.act_codigo LIKE '%' + @FILTRO + '%'
                                      OR act.act_nombre LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_codigo LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_nombre LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_codigo LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_nombre LIKE '%' + @FILTRO + '%'
                                      OR cin.cin_nombre LIKE '%' + @FILTRO + '%')
    )
    SELECT  SUM(CASE WHEN SITUACION = 'VENCIDA'    THEN 1 ELSE 0 END) AS VENCIDAS,
            SUM(CASE WHEN SITUACION = 'ATRASADA'   THEN 1 ELSE 0 END) AS ATRASADAS,
            SUM(CASE WHEN SITUACION = 'DISPONIBLE' THEN 1 ELSE 0 END) AS DISPONIBLES,
            SUM(CASE WHEN SITUACION = 'FUTURA'     THEN 1 ELSE 0 END) AS FUTURAS,
            SUM(CASE WHEN SITUACION = 'CERRADA'    THEN 1 ELSE 0 END) AS CERRADAS,
            SUM(CASE WHEN REQUIERE_PARADA = 1 AND SITUACION IN ('VENCIDA','ATRASADA','DISPONIBLE') THEN 1 ELSE 0 END) AS CON_PARADA,
            COUNT(*) AS TOTAL
    FROM    ocu2
END
GO
PRINT '--- SEL_PLAN_OCURRENCIA_BANDEJA creado.'
GO

-- ---------------------------------------------------------------------------
-- 3) RPT_PLAN_OCURRENCIA_BANDEJA_EXCEL — lo que se ve, para llevarselo
-- ---------------------------------------------------------------------------
/* Mismo patron que RPT_PLAN_CALENDARIO_EXCEL: los encabezados como los lee
   una persona y sin paginar, porque Tools.Excel vuelca el reader tal cual. */
CREATE OR ALTER PROCEDURE [dbo].[RPT_PLAN_OCURRENCIA_BANDEJA_EXCEL]
    @CLIENTE        INT,
    @SITUACION      VARCHAR(20)   = NULL,
    @PLAN           INT           = NULL,
    @ACTIVO         INT           = NULL,
    @INSTALACION    INT           = NULL,
    @ESTADO         INT           = NULL,
    @DESDE          DATE          = NULL,
    @HASTA          DATE          = NULL,
    @SOLO_ABIERTAS  BIT           = 1,
    @SOLO_PARADA    BIT           = NULL,
    @FILTRO         NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @HOY DATETIME = GETUTCDATE()
    SET @SITUACION = NULLIF(LTRIM(RTRIM(UPPER(ISNULL(@SITUACION, '')))), '')

    ;WITH ocu AS (
        SELECT  pmo.*,
                CASE
                    WHEN pmo.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7)                                    THEN 'CERRADA'
                    WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY          THEN 'VENCIDA'
                    WHEN pmo.pmo_fecha_programada_utc < @HOY                                               THEN 'ATRASADA'
                    WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                    ELSE 'FUTURA'
                END AS SITUACION
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          AND   (ISNULL(@SOLO_ABIERTAS, 1) = 0 OR pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3))
          AND   (@ESTADO IS NULL OR pmo.pmo_plan_ocurrencia_estado = @ESTADO)
          AND   (@DESDE  IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA  IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
    )
    SELECT  o.SITUACION                             AS [Situación],
            poe.poe_nombre                          AS [Estado],
            CONVERT(VARCHAR(10), o.pmo_fecha_programada_utc, 103) AS [Programada],
            CONVERT(VARCHAR(10), o.pmo_fecha_limite_utc, 103)     AS [Fecha límite],
            DATEDIFF(DAY, @HOY, o.pmo_fecha_programada_utc)       AS [Días],
            act.act_codigo                          AS [Código equipo],
            act.act_nombre                          AS [Equipo],
            cin.cin_nombre                          AS [Planta],
            pma.pma_codigo                          AS [Código plan],
            pma.pma_nombre                          AS [Plan],
            pmh.pmh_codigo                          AS [Código hito],
            pmh.pmh_nombre                          AS [Hito],
            CASE WHEN pmh.pmh_requiere_parada = 1 THEN 'Sí' ELSE 'No' END AS [Requiere parada],
            CASE WHEN pmh.pmh_es_overhaul = 1 THEN 'Sí' ELSE 'No' END     AS [Overhaul],
            pmh.pmh_duracion_estimada_minuto        AS [Duración (min)],
            otr.otr_correlativo                     AS [Orden de trabajo],
            o.pmo_observacion                       AS [Observación]

    FROM    ocu o
    JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = o.pmo_plan_mantenimiento_hito
    JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
    JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
    JOIN    [dbo].[Plan_Ocurrencia_Estado]     poe ON poe.poe_id = o.pmo_plan_ocurrencia_estado
    LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = act.act_cliente_instalacion
    LEFT JOIN [dbo].[Orden_Trabajo]            otr ON otr.otr_id = o.pmo_orden_trabajo

    WHERE   (@SITUACION   IS NULL OR o.SITUACION = @SITUACION)
      AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
      AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
      AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
      AND   (@SOLO_PARADA IS NULL OR pmh.pmh_requiere_parada = @SOLO_PARADA)
      AND   (@FILTRO      IS NULL OR act.act_codigo LIKE '%' + @FILTRO + '%'
                                  OR act.act_nombre LIKE '%' + @FILTRO + '%'
                                  OR pmh.pmh_codigo LIKE '%' + @FILTRO + '%'
                                  OR pmh.pmh_nombre LIKE '%' + @FILTRO + '%'
                                  OR pma.pma_codigo LIKE '%' + @FILTRO + '%'
                                  OR pma.pma_nombre LIKE '%' + @FILTRO + '%'
                                  OR cin.cin_nombre LIKE '%' + @FILTRO + '%')

    ORDER BY CASE o.SITUACION
                WHEN 'VENCIDA'    THEN 1
                WHEN 'ATRASADA'   THEN 2
                WHEN 'DISPONIBLE' THEN 3
                WHEN 'FUTURA'     THEN 4
                ELSE 5
             END,
             o.pmo_fecha_programada_utc,
             act.act_codigo
END
GO
PRINT '--- RPT_PLAN_OCURRENCIA_BANDEJA_EXCEL creado.'
GO

PRINT '292_PLAN_OCURRENCIA_BANDEJA aplicado.'
GO
