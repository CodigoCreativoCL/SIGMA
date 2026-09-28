USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     LOS DOS CRITERIOS QUE FALTABAN DE HU-083 Y HU-086.
-- =============================================
-- Cerrando las historias del plan quedaron dos criterios sin construir. No
-- eran pruebas que faltaban: era funcionalidad que nadie habia escrito, y
-- escribir un caso de prueba sobre algo que no existe no lo hace existir.
--
-- ---------------------------------------------------------------------------
-- HU-083 #3 · "EL ACTIVO YA ESTA CUBIERTO POR OTRO PLAN"
--
--   El criterio pide ADVERTIR, no rechazar: "se advierte cual es el otro plan
--   y se permite continuar". La diferencia importa. Que un equipo este en dos
--   planes es a veces un error -dos planes preventivos pisandose- y a veces
--   lo correcto -uno de lubricacion y otro de inspeccion legal-, y el sistema
--   no tiene como distinguirlos. Quien sabe cual de los dos casos es, es el
--   planificador; lo unico que le falta es enterarse.
--
--   Por eso es un SELECT y no una validacion dentro del INS: una regla en el
--   INS solo puede dejar pasar o rechazar, y aca hace falta una tercera cosa
--   -mostrar y seguir-. La pantalla lo consulta al elegir el equipo, que es
--   cuando el dato sirve para decidir, y no al apretar Guardar, que es
--   cuando ya se decidio.
--
-- ---------------------------------------------------------------------------
-- HU-086 #2 · EL CUMPLIMIENTO SE MIDE CONTRA LA FECHA ORIGINAL
--
--   "Cuando se calcula el indicador de cumplimiento, entonces se mide contra
--   la fecha programada original y no contra la nueva". Es la regla que le da
--   sentido a toda HU-086: si reprogramar corriera tambien la vara, el
--   indicador se podria dejar en 100% simplemente moviendo las fechas, y
--   medir dejaria de servir para algo.
--
--   `pmo_fecha_programada_original_utc` guarda SIEMPRE la primera fecha,
--   aunque se reprograme varias veces, asi que el indicador tiene contra que
--   medir sin reconstruir la cadena de reprogramaciones.
--
--   LA TOLERANCIA VIAJA CON LA FECHA. Una ocurrencia tiene fecha programada y
--   fecha limite, y la distancia entre las dos es la tolerancia que le dio su
--   programacion. Al medir contra la fecha original se usa ESA MISMA
--   tolerancia sobre la original: comparar contra la fecha original pelada
--   seria mover la vara en el otro sentido.
--
--   EL SP DEVUELVE LAS DOS CUENTAS -contra la original y contra la vigente-
--   a proposito. La segunda no es el indicador: esta para que la pantalla
--   pueda mostrar la diferencia, que es exactamente lo que el criterio quiere
--   que sea visible.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_ACTIVO_COBERTURA (HU-083 #3)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_ACTIVO_COBERTURA]
    @CLIENTE INT,
    @ACTIVO  INT,
    @PLAN    INT = NULL      -- el plan que se esta editando: no se advierte de si mismo
AS
BEGIN
    SET NOCOUNT ON

    SELECT  pma.pma_id                      AS PLAN_ID,
            pma.pma_codigo                  AS PLAN_CODIGO,
            pma.pma_nombre                  AS PLAN_NOMBRE,
            pmv.pmv_id                      AS VERSION_ID,
            pmv.pmv_numero                  AS VERSION_NUMERO,
            pve.pve_codigo                  AS VERSION_ESTADO_CODIGO,
            pve.pve_nombre                  AS VERSION_ESTADO_NOMBRE,
            ati.ati_nombre                  AS TIPO_NOMBRE,
            ISNULL(hit.cuantos, 0)          AS HITOS,
            /* Mismo tipo de activo = el caso que el criterio llama "otro plan
               vigente del mismo tipo". Si son de tipos distintos la
               advertencia igual se da, pero se puede matizar en la pantalla. */
            CASE WHEN pma.pma_activo_tipo IS NOT NULL
                  AND pma.pma_activo_tipo = act.act_activo_tipo THEN 1 ELSE 0 END AS MISMO_TIPO,
            /* Lo que de verdad se pisa: cuantas ocurrencias abiertas tiene ya
               ese otro plan para este equipo. Dos planes que se solapan en el
               papel pero no generan nada no son el mismo problema. */
            ISNULL(ocu.cuantas, 0)          AS OCURRENCIAS_ABIERTAS

    FROM    [dbo].[Plan_Mantenimiento_Activo] pac
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pac.pac_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento] pma         ON pma.pma_id = pmv.pmv_plan_mantenimiento
    INNER JOIN [dbo].[Activo] act                     ON act.act_id = pac.pac_activo
    LEFT  JOIN [dbo].[Plan_Version_Estado] pve        ON pve.pve_id = pmv.pmv_plan_version_estado
    LEFT  JOIN [dbo].[Activo_Tipo] ati                ON ati.ati_id = pma.pma_activo_tipo
    OUTER APPLY (SELECT COUNT(*) AS cuantos FROM [dbo].[Plan_Mantenimiento_Hito] h
                  WHERE h.pmh_plan_mantenimiento_version = pmv.pmv_id AND h.pmh_habilitado = 1) hit
    OUTER APPLY (SELECT COUNT(*) AS cuantas FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                  INNER JOIN [dbo].[Plan_Mantenimiento_Hito] h2 ON h2.pmh_id = o.pmo_plan_mantenimiento_hito
                  WHERE h2.pmh_plan_mantenimiento_version = pmv.pmv_id
                    AND o.pmo_activo = @ACTIVO
                    AND o.pmo_habilitado = 1
                    AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)) ocu

    WHERE   pac.pac_activo   = @ACTIVO
      AND   pma.pma_cliente  = @CLIENTE
      AND   pma.pma_habilitado = 1
      AND   (@PLAN IS NULL OR pma.pma_id <> @PLAN)
      /* VIGENTE: solo la version publicada. Un borrador de otro plan todavia
         no genera nada, asi que advertir de el seria advertir de una
         intencion, no de un hecho. */
      AND   pmv.pmv_plan_version_estado = 2
      AND   pmv.pmv_habilitado = 1

    ORDER BY pma.pma_codigo
END
GO
PRINT '--- SEL_PLAN_ACTIVO_COBERTURA creado.'
GO

-- ---------------------------------------------------------------------------
-- 2) SEL_PLAN_CUMPLIMIENTO (HU-086 #2)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CUMPLIMIENTO]
    @CLIENTE INT,
    @PLAN    INT  = NULL,
    @ACTIVO  INT  = NULL,
    @DESDE   DATE = NULL,
    @HASTA   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON

    -- Sin rango, el año en curso: es como se lee un indicador de plan.
    IF (@DESDE IS NULL AND @HASTA IS NULL)
    BEGIN
        SET @DESDE = DATEFROMPARTS(YEAR(GETUTCDATE()), 1, 1)
        SET @HASTA = DATEFROMPARTS(YEAR(GETUTCDATE()), 12, 31)
    END

    DECLARE @HOY DATETIME = GETUTCDATE()

    ;WITH base AS (
        SELECT  pmo.pmo_id,
                pmo.pmo_plan_ocurrencia_estado                              AS ESTADO,
                pmo.pmo_fecha_programada_utc                                AS PROGRAMADA,
                /* Si nunca se reprogramo, la original es la programada: la
                   columna puede venir nula en filas viejas. */
                ISNULL(pmo.pmo_fecha_programada_original_utc,
                       pmo.pmo_fecha_programada_utc)                        AS ORIGINAL,
                pmo.pmo_fecha_limite_utc                                    AS LIMITE,
                CASE WHEN pmo.pmo_ocurrencia_origen IS NULL THEN 0 ELSE 1 END AS FUE_REPROGRAMADA,
                /* Cuando se dio por hecha. La orden manda -es el hecho en
                   terreno-; si no la hay, la fecha en que la ocurrencia
                   cambio de estado. */
                COALESCE(otr.otr_fecha_fin_real_utc, otr.otr_fecha_cierre,
                         pmo.pmo_fecha_actualizacion)                       AS CUMPLIDA_EN,
                /* La tolerancia que le dio su programacion, en dias. Viaja
                   con la fecha: al medir contra la original se aplica la
                   misma, o se estaria moviendo la vara en el otro sentido. */
                CASE WHEN pmo.pmo_fecha_limite_utc IS NULL THEN 0
                     ELSE DATEDIFF(DAY, pmo.pmo_fecha_programada_utc, pmo.pmo_fecha_limite_utc) END AS TOLERANCIA
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = pmo.pmo_plan_mantenimiento_hito
        INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
        INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
        LEFT  JOIN [dbo].[Orden_Trabajo]              otr ON otr.otr_id = pmo.pmo_orden_trabajo
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          /* CANCELADA (6) no cuenta ni arriba ni abajo: no se dejo de hacer,
             se decidio que no habia que hacerlo. REPROGRAMADA (7) tampoco:
             la que cuenta es la hija, que lleva la fecha original heredada. */
          AND   pmo.pmo_plan_ocurrencia_estado NOT IN (6, 7)
          AND   (@PLAN   IS NULL OR pma.pma_id  = @PLAN)
          AND   (@ACTIVO IS NULL OR pmo.pmo_activo = @ACTIVO)
          /* El rango se aplica sobre la ORIGINAL: si se aplicara sobre la
             vigente, reprogramar al año siguiente sacaria la ocurrencia del
             indicador de este año, que es la misma trampa por otra puerta. */
          AND   (@DESDE IS NULL OR ISNULL(pmo.pmo_fecha_programada_original_utc, pmo.pmo_fecha_programada_utc) >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA IS NULL OR ISNULL(pmo.pmo_fecha_programada_original_utc, pmo.pmo_fecha_programada_utc) <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
    ),
    medida AS (
        SELECT  b.*,
                DATEADD(DAY, b.TOLERANCIA, b.ORIGINAL)   AS LIMITE_ORIGINAL,
                CASE WHEN b.ESTADO = 4 THEN 1 ELSE 0 END AS CUMPLIDA
        FROM    base b
    )
    SELECT  COUNT(*)                                                    AS PROGRAMADAS,
            SUM(CUMPLIDA)                                               AS CUMPLIDAS,

            /* EL INDICADOR: a tiempo contra la fecha ORIGINAL. */
            SUM(CASE WHEN CUMPLIDA = 1 AND CUMPLIDA_EN IS NOT NULL
                      AND CUMPLIDA_EN <= LIMITE_ORIGINAL THEN 1 ELSE 0 END) AS A_TIEMPO_ORIGINAL,

            /* La misma cuenta contra la fecha vigente. NO es el indicador:
               esta para poder mostrar la diferencia que produce reprogramar. */
            SUM(CASE WHEN CUMPLIDA = 1 AND CUMPLIDA_EN IS NOT NULL
                      AND CUMPLIDA_EN <= ISNULL(LIMITE, PROGRAMADA) THEN 1 ELSE 0 END) AS A_TIEMPO_VIGENTE,

            SUM(CASE WHEN CUMPLIDA = 0 AND ISNULL(LIMITE, PROGRAMADA) < @HOY THEN 1 ELSE 0 END) AS VENCIDAS,
            SUM(FUE_REPROGRAMADA)                                       AS REPROGRAMADAS,

            CAST(CASE WHEN COUNT(*) = 0 THEN 0
                      ELSE 100.0 * SUM(CASE WHEN CUMPLIDA = 1 AND CUMPLIDA_EN IS NOT NULL
                                             AND CUMPLIDA_EN <= LIMITE_ORIGINAL THEN 1 ELSE 0 END) / COUNT(*)
                 END AS DECIMAL(5,1))                                   AS CUMPLIMIENTO,

            CAST(CASE WHEN COUNT(*) = 0 THEN 0
                      ELSE 100.0 * SUM(CASE WHEN CUMPLIDA = 1 AND CUMPLIDA_EN IS NOT NULL
                                             AND CUMPLIDA_EN <= ISNULL(LIMITE, PROGRAMADA) THEN 1 ELSE 0 END) / COUNT(*)
                 END AS DECIMAL(5,1))                                   AS CUMPLIMIENTO_VIGENTE
    FROM    medida
END
GO
PRINT '--- SEL_PLAN_CUMPLIMIENTO creado.'
GO

PRINT '294_PLAN_COBERTURA_CUMPLIMIENTO aplicado.'
GO
