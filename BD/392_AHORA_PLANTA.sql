/* ============================================================================
   392 · «Ahora» en hora de la planta para vencidas, atrasadas y disponibles · 09-10-2026

   Las fechas de las ejecuciones (pmo_fecha_programada_utc, _limite_utc y
   _disponible_utc) se guardan en HORA DE LA PLANTA, no en UTC, a pesar del
   sufijo (ver BD/389). Estos SP las comparaban con GETUTCDATE(): desde las
   21:00 en Chile, UTC ya es el día siguiente y una ejecución de ese día salía
   «Vencida» o «Atrasada» antes de tiempo (ej.: reprogramada al 09-10 00:00,
   vencida a las 21:55 del 08-10).

   Ahora comparan con [dbo].[FNC_AHORA]() (hora de Santiago, la misma que usa
   la pantalla para «hoy»). Solo cambia esa declaración; el resto de cada SP
   es el de su script de origen:
     SEL_PLAN_OCURRENCIA_BANDEJA (BD/384) · pestaña Ejecuciones
     SEL_PLAN_FICHA              (BD/384) · ficha del plan
     SEL_PLAN_CENTRO             (BD/388) · lista de planes (vencidas/atrasadas)
     SEL_PLAN_MONITOREO          (BD/389) · Monitoreo
   ============================================================================ */

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

    DECLARE @HOY DATETIME = [dbo].[FNC_AHORA]()   -- 392: hora de la planta, como las fechas

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
                otr.otr_orden_trabajo_estado AS ORDEN_TRABAJO_ESTADO_ID,
                ote.ote_nombre      AS ORDEN_TRABAJO_ESTADO,
                pmh.pmh_usuario_responsable AS RESPONSABLE_ID,
                LTRIM(RTRIM(ISNULL(urs.usu_nombre, N'') + N' ' + ISNULL(urs.usu_apellido_paterno, N''))) AS RESPONSABLE_NOMBRE,
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
        LEFT JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.ote_id = otr.otr_orden_trabajo_estado
        LEFT JOIN [dbo].[Usuario]                  urs ON urs.usu_id = pmh.pmh_usuario_responsable
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
            f.ORDEN_TRABAJO_ESTADO_ID, f.ORDEN_TRABAJO_ESTADO, f.RESPONSABLE_ID, f.RESPONSABLE_NOMBRE,
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

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_FICHA]
    @CLIENTE INT,
    @PLAN    INT
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = [dbo].[FNC_AHORA]()   -- 392: hora de la planta, como las fechas
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @PUB INT, @BOR INT, @RET INT, @VER INT
SELECT TOP 1 @PUB = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 2 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SELECT TOP 1 @BOR = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SELECT TOP 1 @RET = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 3 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SET @VER = COALESCE(@BOR, @PUB, @RET)

/* Cambios del borrador frente a la vigente, comparando el contenido:
   intervenciones, actividades, activos y repuestos distintos, nuevos o
   quitados (cada diferencia cuenta una vez por lado). */
DECLARE @CAMBIOS INT = 0
IF @BOR IS NOT NULL AND @PUB IS NOT NULL
BEGIN
    SET @CAMBIOS =
          (SELECT COUNT(*) FROM (
               SELECT pmh_codigo, pmh_nombre, pmh_programacion, pmh_duracion_estimada_minuto, pmh_requiere_parada, pmh_es_overhaul,
                      pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, ISNULL(pmh_descripcion, N'') AS d, pmh_habilitado,
                      pmh_usuario_responsable, pmh_grupo_trabajo, pmh_orden
                 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @BOR
               EXCEPT
               SELECT pmh_codigo, pmh_nombre, pmh_programacion, pmh_duracion_estimada_minuto, pmh_requiere_parada, pmh_es_overhaul,
                      pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, ISNULL(pmh_descripcion, N''), pmh_habilitado,
                      pmh_usuario_responsable, pmh_grupo_trabajo, pmh_orden
                 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @PUB) x)
        + (SELECT COUNT(*) FROM (
               SELECT pmh_codigo FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @PUB
               EXCEPT
               SELECT pmh_codigo FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @BOR) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo, a.paa_nombre, ISNULL(a.paa_descripcion, N'') AS d, a.paa_procedimiento, a.paa_duracion_estimada_minuto,
                      a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo, a.paa_orden
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo, a.paa_nombre, ISNULL(a.paa_descripcion, N''), a.paa_procedimiento, a.paa_duracion_estimada_minuto,
                      a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo, a.paa_orden
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1) x)
        + (SELECT COUNT(*) FROM (
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) AS c FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @BOR
               EXCEPT
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @PUB) x)
        + (SELECT COUNT(*) FROM (
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) AS c FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @PUB
               EXCEPT
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @BOR) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo, r.pra_repuesto, r.pra_cantidad
                 FROM [dbo].[Plan_Actividad_Repuesto] r JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
                 JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo, r.pra_repuesto, r.pra_cantidad
                 FROM [dbo].[Plan_Actividad_Repuesto] r JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
                 JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1) x)
END

/* 0 · plan */
SELECT  pma.pma_id AS PLAN_ID, pma.pma_codigo AS CODIGO, pma.pma_nombre AS NOMBRE, pma.pma_descripcion AS DESCRIPCION,
        CASE WHEN pma.pma_habilitado = 0 THEN 'INACTIVO' WHEN @PUB IS NULL THEN 'BORRADOR' WHEN @BOR IS NOT NULL THEN 'CAMBIOS' ELSE 'ACTIVO' END AS ESTADO,
        pma.pma_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        pma.pma_activo_tipo AS TIPO_ID, ati.ati_nombre AS TIPO,
        pma.pma_activo_modelo AS MODELO_ID, amo.amo_nombre AS MODELO,
        pma.pma_usuario_planificador AS PLANIFICADOR_ID,
        @VER AS VERSION_EDICION, @BOR AS BORRADOR_ID, @PUB AS PUBLICADA_ID,
        vp.pmv_numero AS VERSION_VIGENTE, vp.pmv_fecha_publicacion AS VERSION_DESDE,
        vb.pmv_numero AS VERSION_BORRADOR,
        vr.pmv_numero AS VERSION_RETIRADA, vr.pmv_fecha_retiro AS RETIRO_FECHA, vr.pmv_motivo_retiro AS RETIRO_MOTIVO,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre, N'') + N' ' + ISNULL(ur.usu_apellido_paterno, N''))) AS RETIRO_USUARIO,
        @CAMBIOS AS CAMBIOS,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                                JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
                                JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
                               WHERE v.pmv_plan_mantenimiento = @PLAN) THEN 1 ELSE 0 END AS BIT) AS GENERO,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre, N'') + N' ' + ISNULL(uc.usu_apellido_paterno, N''))) AS CREADO_POR,
        pma.pma_fecha_creacion AS CREADO_EL,
        LTRIM(RTRIM(ISNULL(ua.usu_nombre, N'') + N' ' + ISNULL(ua.usu_apellido_paterno, N''))) AS MODIFICADO_POR,
        pma.pma_fecha_actualizacion AS MODIFICADO_EL
FROM    [dbo].[Plan_Mantenimiento] pma
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = pma.pma_cliente_instalacion
LEFT JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = pma.pma_activo_tipo
LEFT JOIN [dbo].[Activo_Modelo]       amo ON amo.amo_id = pma.pma_activo_modelo
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vp ON vp.pmv_id = @PUB
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vb ON vb.pmv_id = @BOR
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vr ON vr.pmv_id = @RET
LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = vr.pmv_usuario_actualizacion
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = pma.pma_usuario_creacion
LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = pma.pma_usuario_actualizacion
WHERE   pma.pma_id = @PLAN

/* 1 · intervenciones de la versión de edición */
SELECT  h.pmh_id AS HITO_ID, h.pmh_codigo AS CODIGO, h.pmh_nombre AS NOMBRE, h.pmh_orden AS ORDEN,
        h.pmh_descripcion AS DESCRIPCION, h.pmh_habilitado AS HABILITADO,
        h.pmh_duracion_estimada_minuto AS DURACION, h.pmh_requiere_parada AS PARADA, h.pmh_es_overhaul AS OVERHAUL,
        h.pmh_orden_trabajo_tipo AS OT_TIPO_ID, ott.ott_nombre AS OT_TIPO,
        h.pmh_orden_trabajo_prioridad AS OT_PRIORIDAD_ID, opr.opr_nombre AS OT_PRIORIDAD,
        h.pmh_usuario_responsable AS RESPONSABLE_ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        h.pmh_grupo_trabajo AS GRUPO_ID, gtr.gtr_nombre AS GRUPO,
        g.pro_id AS PROGRAMACION_ID, g.pro_nombre AS PROGRAMACION, g.pro_es_privada AS PRIVADA,
        t.pti_codigo AS TIPO_CODIGO, t.pti_nombre AS TIPO_NOMBRE,
        g.pro_fecha_inicio AS VIGENCIA_DESDE, g.pro_fecha_fin AS VIGENCIA_HASTA,
        g.pro_tolerancia_antes_minuto AS TOL_ANTES, g.pro_tolerancia_despues_minuto AS TOL_DESPUES,
        g.pro_cumplimiento_politica AS POLITICA_ID,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] x WHERE x.pmh_programacion = g.pro_id AND x.pmh_id <> h.pmh_id AND x.pmh_habilitado = 1)
          + (SELECT COUNT(*) FROM [dbo].[Tarea_Programacion] x WHERE x.tpr_programacion = g.pro_id AND x.tpr_habilitado = 1)
          + (SELECT COUNT(*) FROM [dbo].[Checklist_Programacion] x WHERE x.cpr_programacion = g.pro_id AND x.cpr_habilitado = 1) AS OTROS_USOS,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                                JOIN [dbo].[Plan_Mantenimiento_Hito] x ON x.pmh_id = o.pmo_plan_mantenimiento_hito
                                JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = x.pmh_plan_mantenimiento_version
                               WHERE v.pmv_plan_mantenimiento = @PLAN AND (x.pmh_id = h.pmh_id OR x.pmh_codigo = h.pmh_codigo))
             THEN 1 ELSE 0 END AS BIT) AS GENERO
FROM    [dbo].[Plan_Mantenimiento_Hito] h
JOIN    [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
JOIN    [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Tipo] ott ON ott.ott_id = h.pmh_orden_trabajo_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Prioridad] opr ON opr.opr_id = h.pmh_orden_trabajo_prioridad
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
LEFT JOIN [dbo].[Grupo_Trabajo] gtr ON gtr.gtr_id = h.pmh_grupo_trabajo
WHERE   h.pmh_plan_mantenimiento_version = @VER
ORDER BY h.pmh_orden, h.pmh_id

SELECT DISTINCT h.pmh_programacion AS pro INTO #pro FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_plan_mantenimiento_version = @VER

/* 2 · calendario (días como lista 1..7, lunes = 1) */
SELECT  c.pca_programacion AS PROGRAMACION_ID, c.pca_frecuencia_tipo AS FRECUENCIA_ID, f.fre_codigo AS FRECUENCIA,
        c.pca_intervalo AS INTERVALO, c.pca_semana_ordinal AS ORDINAL, c.pca_dia_mes AS DIA_MES, c.pca_mes AS MES,
        CONVERT(VARCHAR(5), c.pca_hora_local, 108) AS HORA,
        (SELECT STRING_AGG(CAST(d.pcd_dia_semana AS VARCHAR(2)), ',') FROM [dbo].[Programacion_Calendario_Dia] d WHERE d.pcd_programacion_calendario = c.pca_id) AS DIAS
FROM    [dbo].[Programacion_Calendario] c
JOIN    [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
WHERE   c.pca_programacion IN (SELECT pro FROM #pro) AND c.pca_habilitado = 1

/* 3 · intervalo */
SELECT  i.pin_programacion AS PROGRAMACION_ID, i.pin_cantidad AS CANTIDAD, i.pin_unidad_tiempo AS UNIDAD_ID, u.uti_codigo AS UNIDAD,
        i.pin_fecha_ancla_utc AS ANCLA
FROM    [dbo].[Programacion_Intervalo] i
JOIN    [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
WHERE   i.pin_programacion IN (SELECT pro FROM #pro) AND i.pin_habilitado = 1

/* 4 · medidor */
SELECT  m.pme_programacion AS PROGRAMACION_ID, m.pme_activo_medidor AS MEDIDOR_ID, m.pme_valor_inicial AS VALOR_INICIAL,
        m.pme_cada_cantidad AS CADA, m.pme_aviso_anticipacion AS AVISO
FROM    [dbo].[Programacion_Medidor] m
WHERE   m.pme_programacion IN (SELECT pro FROM #pro) AND m.pme_habilitado = 1

/* 5 · fechas puntuales */
SELECT  f.pfe_id AS ID, f.pfe_programacion AS PROGRAMACION_ID, f.pfe_fecha AS FECHA, CONVERT(VARCHAR(5), f.pfe_hora, 108) AS HORA
FROM    [dbo].[Programacion_Fecha] f
WHERE   f.pfe_programacion IN (SELECT pro FROM #pro) AND f.pfe_incluida = 1
ORDER BY f.pfe_fecha

/* 6 · exclusiones */
SELECT  e.pxc_id AS ID, e.pxc_programacion AS PROGRAMACION_ID,
        e.pxc_fecha_inicio_utc AS DESDE, e.pxc_fecha_fin_utc AS HASTA,
        e.pxc_motivo AS MOTIVO, e.pxc_desplaza AS DESPLAZA
FROM    [dbo].[Programacion_Exclusion] e
WHERE   e.pxc_programacion IN (SELECT pro FROM #pro) AND e.pxc_habilitado = 1
ORDER BY e.pxc_fecha_inicio_utc

/* 7 · condiciones (texto listo para leer) */
SELECT  c.pco_programacion AS PROGRAMACION_ID,
        ISNULL(vme.vme_nombre, N'Variable') + N' ' + ISNULL(op.opc_nombre, N'') + N' ' + CAST(CAST(c.pco_umbral AS DECIMAL(18,2)) AS NVARCHAR(30))
          + ISNULL(N' y ' + CAST(CAST(c.pco_umbral_hasta AS DECIMAL(18,2)) AS NVARCHAR(30)), N'')
          + ISNULL(N' por ' + CAST(c.pco_duracion_minima_minuto AS NVARCHAR(10)) + N' min', N'') AS TEXTO
FROM    [dbo].[Programacion_Condicion] c
LEFT JOIN [dbo].[Activo_Variable] av ON av.ava_id = c.pco_activo_variable
LEFT JOIN [dbo].[Variable_Medicion] vme ON vme.vme_id = av.ava_variable_medicion
LEFT JOIN [dbo].[Operador_Comparacion] op ON op.opc_id = c.pco_operador_comparacion
WHERE   c.pco_programacion IN (SELECT pro FROM #pro) AND c.pco_habilitado = 1

/* 8 · actividades (las dadas de baja no se muestran) */
SELECT  a.paa_id AS ACTIVIDAD_ID, a.paa_plan_mantenimiento_hito AS HITO_ID, a.paa_codigo AS CODIGO, a.paa_nombre AS NOMBRE,
        a.paa_descripcion AS DESCRIPCION, a.paa_orden AS ORDEN, a.paa_duracion_estimada_minuto AS DURACION,
        a.paa_obligatoria AS OBLIGATORIA, a.paa_requiere_parada AS PARADA, a.paa_requiere_permiso AS PERMISO,
        a.paa_permiso_trabajo_tipo AS PERMISO_TIPO_ID, ptt.ptt_nombre AS PERMISO_TIPO,
        a.paa_procedimiento AS PROCEDIMIENTO_ID, prc.prc_codigo AS PROCEDIMIENTO_CODIGO, prc.prc_nombre AS PROCEDIMIENTO,
        prc.prc_version AS PROCEDIMIENTO_VERSION,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] pp WHERE pp.ppa_procedimiento = prc.prc_id AND pp.ppa_habilitado = 1) AS PASOS
FROM    [dbo].[Plan_Mantenimiento_Actividad] a
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
LEFT JOIN [dbo].[Procedimiento] prc ON prc.prc_id = a.paa_procedimiento
LEFT JOIN [dbo].[Permiso_Trabajo_Tipo] ptt ON ptt.ptt_id = a.paa_permiso_trabajo_tipo
WHERE   h.pmh_plan_mantenimiento_version = @VER AND a.paa_habilitado = 1
ORDER BY a.paa_plan_mantenimiento_hito, a.paa_orden, a.paa_id

/* 9 · repuestos planificados */
SELECT  r.pra_id AS ID, r.pra_plan_mantenimiento_actividad AS ACTIVIDAD_ID, r.pra_repuesto AS REPUESTO_ID,
        rep.rep_codigo AS CODIGO, rep.rep_nombre AS NOMBRE, r.pra_cantidad AS CANTIDAD,
        ume.ume_simbolo AS UNIDAD, r.pra_obligatorio AS OBLIGATORIO
FROM    [dbo].[Plan_Actividad_Repuesto] r
JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
JOIN    [dbo].[Repuesto] rep ON rep.rep_id = r.pra_repuesto
LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = r.pra_unidad_medida
WHERE   h.pmh_plan_mantenimiento_version = @VER AND a.paa_habilitado = 1

/* 10 · activos, con su medidor, cobertura y si calzan con el alcance */
SELECT  pac.pac_id AS VINCULO_ID, act.act_id AS ACTIVO_ID, act.act_codigo AS CODIGO, act.act_nombre AS NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA, iar.iar_nombre AS AREA,
        act.act_activo_tipo AS TIPO_ID, ati.ati_nombre AS TIPO, act.act_activo_modelo AS MODELO_ID,
        pac.pac_activo_componente AS COMPONENTE_ID, aco.aco_nombre AS COMPONENTE,
        med.ame_id AS MEDIDOR_ID, med.ame_nombre AS MEDIDOR, med.ame_valor_actual AS MEDIDOR_VALOR, ume.ume_simbolo AS MEDIDOR_UNIDAD,
        (SELECT STRING_AGG(x.pma_codigo, N', ') FROM (
             SELECT DISTINCT p2.pma_codigo FROM [dbo].[Plan_Mantenimiento_Activo] a2
             JOIN [dbo].[Plan_Mantenimiento_Version] v2 ON v2.pmv_id = a2.pac_plan_mantenimiento_version AND v2.pmv_plan_version_estado = 2
             JOIN [dbo].[Plan_Mantenimiento] p2 ON p2.pma_id = v2.pmv_plan_mantenimiento AND p2.pma_habilitado = 1
             WHERE a2.pac_activo = act.act_id AND p2.pma_id <> @PLAN) x) AS OTROS_PLANES,
        CASE WHEN act.act_habilitado = 0 OR act.act_fecha_baja IS NOT NULL THEN N'Dado de baja'
             WHEN pma.pma_cliente_instalacion IS NOT NULL AND act.act_cliente_instalacion <> pma.pma_cliente_instalacion THEN N'Otra planta'
             WHEN pma.pma_activo_tipo IS NOT NULL AND ISNULL(act.act_activo_tipo, 0) <> pma.pma_activo_tipo THEN N'Otro tipo'
             WHEN pma.pma_activo_modelo IS NOT NULL AND ISNULL(act.act_activo_modelo, 0) <> pma.pma_activo_modelo THEN N'Otro modelo'
             ELSE NULL END AS FUERA_ALCANCE
FROM    [dbo].[Plan_Mantenimiento_Activo] pac
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pac.pac_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo] act ON act.act_id = pac.pac_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Tipo] ati ON ati.ati_id = act.act_activo_tipo
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = pac.pac_activo_componente
OUTER APPLY (SELECT TOP 1 m.ame_id, m.ame_nombre, m.ame_valor_actual, m.ame_unidad_medida FROM [dbo].[Activo_Medidor] m
              WHERE m.ame_activo = act.act_id AND m.ame_habilitado = 1
              ORDER BY CASE WHEN m.ame_id = pac.pac_activo_medidor THEN 0 ELSE 1 END, m.ame_id) med
LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = med.ame_unidad_medida
WHERE   pac.pac_plan_mantenimiento_version = @VER
ORDER BY act.act_codigo

/* 11 · próximas ejecuciones (las 10 siguientes, de cualquier versión) */
SELECT TOP 10
        o.pmo_id AS OCURRENCIA_ID, o.pmo_fecha_programada_utc AS FECHA,
        o.pmo_fecha_limite_utc AS LIMITE,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO,
        CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 'VENCIDA'
             WHEN o.pmo_fecha_programada_utc < @UTC THEN 'ATRASADA'
             WHEN o.pmo_fecha_disponible_utc IS NOT NULL AND o.pmo_fecha_disponible_utc <= @UTC THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        o.pmo_orden_trabajo AS OT_ID, ot.otr_correlativo AS OT_NUMERO, ot.otr_orden_trabajo_estado AS OT_ESTADO_ID
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Activo] act ON act.act_id = o.pmo_activo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE   v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)
ORDER BY CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 0
              WHEN o.pmo_fecha_programada_utc < @UTC THEN 1 ELSE 2 END,
         o.pmo_fecha_programada_utc

/* 12 · OT generadas por el plan */
SELECT TOP 100
        ot.otr_id AS OT_ID, ot.otr_correlativo AS NUMERO, ot.otr_titulo AS TITULO,
        ot.otr_orden_trabajo_estado AS ESTADO_ID, ote.ote_codigo AS ESTADO_CODIGO, ote.ote_nombre AS ESTADO,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_nombre AS HITO,
        ot.otr_fecha_programada_utc AS FECHA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    [dbo].[Orden_Trabajo] ot
JOIN    [dbo].[Plan_Mantenimiento_Ocurrencia] o ON o.pmo_id = ot.otr_plan_mantenimiento_ocurrencia
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Activo] act ON act.act_id = ot.otr_activo
LEFT JOIN [dbo].[Orden_Trabajo_Estado] ote ON ote.ote_id = ot.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo_Asignacion] ota ON ota.ota_orden_trabajo = ot.otr_id AND ota.ota_es_responsable = 1 AND ota.ota_habilitado = 1
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = ota.ota_usuario
WHERE   v.pmv_plan_mantenimiento = @PLAN AND ot.otr_habilitado = 1
ORDER BY ot.otr_fecha_creacion DESC

/* 13 · versiones */
SELECT  v.pmv_id AS VERSION_ID, v.pmv_numero AS NUMERO, pve.pve_codigo AS ESTADO_CODIGO, pve.pve_nombre AS ESTADO,
        v.pmv_fecha_publicacion AS PUBLICADA, LTRIM(RTRIM(ISNULL(up.usu_nombre, N'') + N' ' + ISNULL(up.usu_apellido_paterno, N''))) AS PUBLICADA_POR,
        v.pmv_fecha_retiro AS RETIRADA, v.pmv_motivo_retiro AS MOTIVO_RETIRO, v.pmv_observacion AS OBSERVACION,
        v.pmv_fecha_creacion AS CREADA, LTRIM(RTRIM(ISNULL(uc.usu_nombre, N'') + N' ' + ISNULL(uc.usu_apellido_paterno, N''))) AS CREADA_POR,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1) AS INTERVENCIONES,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = v.pmv_id) AS ACTIVOS,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          WHERE h.pmh_plan_mantenimiento_version = v.pmv_id) AS EJECUCIONES
FROM    [dbo].[Plan_Mantenimiento_Version] v
JOIN    [dbo].[Plan_Version_Estado] pve ON pve.pve_id = v.pmv_plan_version_estado
LEFT JOIN [dbo].[Usuario] up ON up.usu_id = v.pmv_usuario_publicacion
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = v.pmv_usuario_creacion
WHERE   v.pmv_plan_mantenimiento = @PLAN AND v.pmv_habilitado = 1
ORDER BY v.pmv_numero DESC

/* 14 · proyección de la versión de edición (10 primeras fechas × activo) */
SELECT TOP 10 f.FECHA, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO
FROM    [dbo].[Plan_Mantenimiento_Hito] h
JOIN    [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Activo] act ON act.act_id = a.pac_activo
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @HOY, DATEADD(DAY, 400, @HOY)) f
WHERE   h.pmh_plan_mantenimiento_version = @VER AND h.pmh_habilitado = 1 AND f.DESCARTADA = 0
ORDER BY f.FECHA, act.act_codigo

/* 15 · próximas fechas de cada intervención (cabecera y vista previa) */
SELECT  x.HITO_ID, x.FECHA, x.FECHA_ORIGINAL, x.DESPLAZADA, x.DESCARTADA, x.MOTIVO
FROM (
    SELECT h.pmh_id AS HITO_ID, f.FECHA, f.FECHA_ORIGINAL, f.DESPLAZADA, f.DESCARTADA, f.MOTIVO,
           ROW_NUMBER() OVER (PARTITION BY h.pmh_id ORDER BY f.FECHA) AS rn
    FROM   [dbo].[Plan_Mantenimiento_Hito] h
    CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @HOY, DATEADD(DAY, 800, @HOY)) f
    WHERE  h.pmh_plan_mantenimiento_version = @VER
) x
WHERE x.rn <= 10
ORDER BY x.HITO_ID, x.FECHA

RETURN(0)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CENTRO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @PLAN        INT = NULL
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = [dbo].[FNC_AHORA]()   -- 392: hora de la planta, como las fechas

SELECT  pma.pma_id, pma.pma_codigo, pma.pma_nombre, pma.pma_habilitado, pma.pma_cliente_instalacion,
        pma.pma_activo_tipo, pma.pma_activo_modelo,
        pub.pmv_id AS PUB_ID, pub.pmv_numero AS PUB_NUM, pub.pmv_fecha_publicacion AS PUB_FECHA,
        bor.pmv_id AS BOR_ID, bor.pmv_numero AS BOR_NUM,
        ret.pmv_id AS RET_ID, ret.pmv_numero AS RET_NUM,
        CAST(NULL AS INT) AS VER_ID
INTO    #p
FROM    [dbo].[Plan_Mantenimiento] pma
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero, v.pmv_fecha_publicacion FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) pub
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 1 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) bor
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 3 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) ret
WHERE   pma.pma_cliente = @CLIENTE
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)

/* Fuera: los eliminados (deshabilitados sin versión publicada ni retirada). */
DELETE FROM #p WHERE pma_habilitado = 0 AND PUB_ID IS NULL AND RET_ID IS NULL
DELETE FROM #p WHERE pma_habilitado = 1 AND PUB_ID IS NULL AND BOR_ID IS NULL

UPDATE #p SET VER_ID = COALESCE(BOR_ID, PUB_ID, RET_ID)

/* Planta: la del plan o, si el plan no tiene, la de alguno de sus activos. */
IF @INSTALACION IS NOT NULL
    DELETE p FROM #p p
    WHERE ISNULL(p.pma_cliente_instalacion, 0) <> @INSTALACION
      AND NOT (p.pma_cliente_instalacion IS NULL AND EXISTS (
               SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a JOIN [dbo].[Activo] x ON x.act_id = a.pac_activo
               WHERE a.pac_plan_mantenimiento_version = p.VER_ID AND x.act_cliente_instalacion = @INSTALACION))

SELECT  p.pma_id                                   AS PLAN_ID,
        p.pma_codigo                               AS CODIGO,
        p.pma_nombre                               AS NOMBRE,
        CASE WHEN p.pma_habilitado = 0 THEN 'INACTIVO'
             WHEN p.PUB_ID IS NULL     THEN 'BORRADOR'
             WHEN p.BOR_ID IS NOT NULL THEN 'CAMBIOS'
             ELSE 'ACTIVO' END                    AS ESTADO,
        p.pma_cliente_instalacion                  AS PLANTA_ID,
        cin.cin_nombre                             AS PLANTA,
        ati.ati_nombre                             AS TIPO,
        amo.amo_nombre                             AS MODELO,
        p.PUB_NUM                                  AS VERSION_VIGENTE,
        p.PUB_FECHA         AS VERSION_DESDE,
        p.VER_ID                                   AS VERSION_EDICION,
        ISNULL(ac.n, 0)                            AS ACTIVOS,
        ISNULL(hi.n, 0)                            AS INTERVENCIONES,
        ISNULL(hi.sin_frecuencia, 0)               AS SIN_FRECUENCIA,
        ISNULL(oc.vencidas, 0)                     AS VENCIDAS,
        ISNULL(oc.atrasadas, 0)                    AS ATRASADAS,
        px.fecha            AS PROXIMA_FECHA,
        px.activo                                  AS PROXIMA_ACTIVO,
        CAST(0 AS BIT)                             AS PROXIMA_PROYECCION,
        fr.texto                                   AS FRECUENCIAS,
        rs.nombre                                  AS RESPONSABLE,
        rsa.todos                                  AS RESPONSABLES,
        bu.activos_txt                             AS ACTIVOS_TXT,
        bu.intervenciones_txt                      AS INTERVENCIONES_TXT,
        ISNULL(fl.faltan, 0)                       AS FALTAN
INTO    #r
FROM    #p p
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = p.pma_cliente_instalacion
LEFT JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = p.pma_activo_tipo
LEFT JOIN [dbo].[Activo_Modelo]       amo ON amo.amo_id = p.pma_activo_modelo
OUTER APPLY (SELECT COUNT(*) AS n FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = p.VER_ID) ac
OUTER APPLY (SELECT COUNT(*) AS n,
                    SUM(CASE WHEN t.pti_codigo = 'ABIERTA' THEN 1 ELSE 0 END) AS sin_frecuencia
               FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
               JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
              WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1) hi
OUTER APPLY (SELECT SUM(CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 1 ELSE 0 END) AS vencidas,
                    SUM(CASE WHEN (o.pmo_fecha_limite_utc IS NULL OR o.pmo_fecha_limite_utc >= @UTC) AND o.pmo_fecha_programada_utc < @UTC THEN 1 ELSE 0 END) AS atrasadas
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
               JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
              WHERE v.pmv_plan_mantenimiento = p.pma_id AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)) oc
OUTER APPLY (SELECT TOP 1 o.pmo_fecha_programada_utc AS fecha, act.act_codigo + N' · ' + act.act_nombre AS activo
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
               JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
               JOIN [dbo].[Activo] act ON act.act_id = o.pmo_activo
              WHERE v.pmv_plan_mantenimiento = p.pma_id AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2)
                AND o.pmo_fecha_programada_utc >= CAST(CAST(@UTC AS DATE) AS DATETIME)
              ORDER BY o.pmo_fecha_programada_utc) px
OUTER APPLY (SELECT STRING_AGG(x.corto, N' · ') AS texto
               FROM (SELECT DISTINCT TOP 4 CASE t.pti_codigo
                        WHEN 'CALENDARIO' THEN CASE WHEN ISNULL(pca.pca_intervalo, 1) <= 1
                                THEN CASE ft.fre_codigo WHEN 'DIARIA' THEN N'Diaria' WHEN 'SEMANAL' THEN N'Semanal' WHEN 'MENSUAL' THEN N'Mensual' WHEN 'ANUAL' THEN N'Anual' ELSE ft.fre_nombre END
                                ELSE N'Cada ' + CAST(pca.pca_intervalo AS NVARCHAR(10)) + N' ' + CASE ft.fre_codigo WHEN 'DIARIA' THEN N'días' WHEN 'SEMANAL' THEN N'semanas' WHEN 'MENSUAL' THEN N'meses' WHEN 'ANUAL' THEN N'años' ELSE LOWER(ft.fre_nombre) END END
                        WHEN 'INTERVALO TIEMPO' THEN N'Cada ' + CAST(pin.pin_cantidad AS NVARCHAR(10)) + N' ' + LOWER(ISNULL(ut.uti_nombre, N'')) + CASE WHEN pin.pin_cantidad > 1 THEN N's' ELSE N'' END
                        WHEN 'MEDIDOR' THEN N'Por medidor'
                        WHEN 'CONDICION' THEN N'Por condición'
                        WHEN 'FECHA UNICA' THEN N'Fechas puntuales'
                        ELSE t.pti_nombre END AS corto
                       FROM [dbo].[Plan_Mantenimiento_Hito] h
                       JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
                       JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
                       LEFT JOIN [dbo].[Programacion_Calendario] pca ON pca.pca_programacion = g.pro_id AND pca.pca_habilitado = 1
                       LEFT JOIN [dbo].[Frecuencia_Tipo] ft ON ft.fre_id = pca.pca_frecuencia_tipo
                       LEFT JOIN [dbo].[Programacion_Intervalo] pin ON pin.pin_programacion = g.pro_id AND pin.pin_habilitado = 1
                       LEFT JOIN [dbo].[Unidad_Tiempo] ut ON ut.uti_id = pin.pin_unidad_tiempo
                      WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1 AND t.pti_codigo <> 'ABIERTA') x) fr
OUTER APPLY (SELECT TOP 1 LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS nombre
               FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
              WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1
              ORDER BY h.pmh_orden) rs
OUTER APPLY (SELECT STRING_AGG(x.nombre, N'|') AS todos FROM (SELECT DISTINCT TOP 3 LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS nombre
               FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
              WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1) x) rsa
OUTER APPLY (SELECT (SELECT STRING_AGG(CAST(act.act_codigo + N' ' + act.act_nombre AS NVARCHAR(MAX)), N' ')
                       FROM [dbo].[Plan_Mantenimiento_Activo] a JOIN [dbo].[Activo] act ON act.act_id = a.pac_activo
                      WHERE a.pac_plan_mantenimiento_version = p.VER_ID) AS activos_txt,
                    (SELECT STRING_AGG(CAST(h.pmh_nombre AS NVARCHAR(MAX)), N' ')
                       FROM [dbo].[Plan_Mantenimiento_Hito] h
                      WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1) AS intervenciones_txt) bu
OUTER APPLY (SELECT (CASE WHEN ISNULL(ac.n, 0) = 0 THEN 1 ELSE 0 END)
                  + (CASE WHEN ISNULL(hi.n, 0) = 0 THEN 1 ELSE 0 END)
                  + (CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h
                                        WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1
                                          AND (LEN(LTRIM(RTRIM(ISNULL(h.pmh_nombre, N'')))) = 0 OR ISNULL(h.pmh_duracion_estimada_minuto, 0) <= 0))
                            OR EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] a2 JOIN [dbo].[Plan_Mantenimiento_Hito] h2 ON h2.pmh_id = a2.paa_plan_mantenimiento_hito
                                        WHERE h2.pmh_plan_mantenimiento_version = p.VER_ID AND h2.pmh_habilitado = 1 AND a2.paa_habilitado = 1
                                          AND LEN(LTRIM(RTRIM(ISNULL(a2.paa_nombre, N'')))) = 0) THEN 1 ELSE 0 END)
                  + (CASE WHEN ISNULL(hi.n, 0) = 0 OR ISNULL(hi.sin_frecuencia, 0) > 0 THEN 1 ELSE 0 END) AS faltan) fl

/* Un plan sin ejecuciones futuras (borrador o activo recién editado):
   la próxima fecha es la PROYECCIÓN de su versión de edición. */
UPDATE r SET PROXIMA_FECHA = pr.fecha, PROXIMA_ACTIVO = pr.activo, PROXIMA_PROYECCION = 1
FROM   #r r
CROSS APPLY (SELECT TOP 1 f.FECHA AS fecha, act.act_codigo + N' · ' + act.act_nombre AS activo
               FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
               JOIN [dbo].[Activo] act ON act.act_id = a.pac_activo
               CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, CAST(@UTC AS DATE), DATEADD(DAY, 400, CAST(@UTC AS DATE))) f
              WHERE h.pmh_plan_mantenimiento_version = r.VERSION_EDICION AND h.pmh_habilitado = 1 AND f.DESCARTADA = 0
              ORDER BY f.FECHA) pr
WHERE  r.PROXIMA_FECHA IS NULL AND r.ESTADO IN ('BORRADOR', 'CAMBIOS')

SELECT  r.*,
        CAST(CASE WHEN r.FALTAN = 0 THEN 1 ELSE 0 END AS BIT) AS LISTO
FROM    #r r
ORDER BY CASE WHEN r.VENCIDAS + r.ATRASADAS > 0 THEN 0 ELSE 1 END,
         CASE WHEN r.PROXIMA_FECHA IS NULL THEN 1 ELSE 0 END,
         r.PROXIMA_FECHA, r.NOMBRE
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_MONITOREO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @DESDE       DATE,
    @HASTA       DATE
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = [dbo].[FNC_AHORA]()   -- 392: hora de la planta, como las fechas
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

/* 0 · ejecuciones reales */
SELECT  o.pmo_id AS PMO_ID, o.pmo_fecha_programada_utc AS FECHA, o.pmo_fecha_limite_utc AS LIMITE,
        o.pmo_plan_ocurrencia_estado AS ESTADO_ID,
        CASE WHEN o.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7) THEN 'CERRADA'
             WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 'VENCIDA'
             WHEN o.pmo_fecha_programada_utc < @UTC THEN 'ATRASADA'
             WHEN o.pmo_fecha_disponible_utc IS NOT NULL AND o.pmo_fecha_disponible_utc <= @UTC THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        pma.pma_id AS PLAN_ID, pma.pma_codigo AS PLAN_CODIGO, pma.pma_nombre AS PLAN_NOMBRE,
        h.pmh_id AS HITO_ID, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO_NOMBRE,
        ISNULL(h.pmh_duracion_estimada_minuto, 0) AS DURACION, h.pmh_requiere_parada AS PARADA,
        act.act_id AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        act.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA, aco.aco_nombre AS COMPONENTE,
        ot.otr_id AS OT_ID, ot.otr_correlativo AS OT_NUMERO, ot.otr_orden_trabajo_estado AS OT_ESTADO_ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
JOIN    [dbo].[Activo] act ON act.act_id = o.pmo_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.pmo_activo_componente
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
WHERE   o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1
  AND   o.pmo_plan_ocurrencia_estado NOT IN (6, 7)
  AND   o.pmo_fecha_programada_utc >= @D AND o.pmo_fecha_programada_utc < @H
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
ORDER BY o.pmo_fecha_programada_utc, act.act_codigo

/* 1 · proyección: borradores y más allá de lo ya generado */
DECLARE @LIM DATE = DATEADD(DAY, 90, CAST(@UTC AS DATE))
SELECT  f.FECHA AS FECHA, pma.pma_id AS PLAN_ID, pma.pma_codigo AS PLAN_CODIGO, pma.pma_nombre AS PLAN_NOMBRE,
        h.pmh_id AS HITO_ID, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO_NOMBRE,
        ISNULL(h.pmh_duracion_estimada_minuto, 0) AS DURACION, h.pmh_requiere_parada AS PARADA,
        act.act_id AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        act.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA, aco.aco_nombre AS COMPONENTE,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        CAST(CASE WHEN v.pmv_plan_version_estado = 1 THEN 1 ELSE 0 END AS BIT) AS BORRADOR
FROM    [dbo].[Plan_Mantenimiento] pma
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = v.pmv_id
JOIN    [dbo].[Activo] act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = a.pac_activo_componente
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @DESDE, @HASTA) f
WHERE   pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1 AND f.DESCARTADA = 0
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
  AND   ( (v.pmv_plan_version_estado = 1 AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] x WHERE x.pmv_plan_mantenimiento = pma.pma_id AND x.pmv_plan_version_estado = 2 AND x.pmv_habilitado = 1))
       OR (v.pmv_plan_version_estado = 2 AND CAST(f.FECHA AS DATE) > @LIM) )
ORDER BY f.FECHA, act.act_codigo

/* 2 · áreas de la planta (las que no tienen trabajo se listan como «operando») */
SELECT  iar.iar_id AS AREA_ID, iar.iar_nombre AS AREA, iar.iar_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA
FROM    [dbo].[Instalacion_Area] iar
JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = iar.iar_cliente_instalacion
WHERE   iar.iar_cliente = @CLIENTE AND iar.iar_habilitado = 1
  AND   (@INSTALACION IS NULL OR iar.iar_cliente_instalacion = @INSTALACION)
ORDER BY cin.cin_nombre, iar.iar_orden, iar.iar_nombre

RETURN(0)
GO

PRINT '392_AHORA_PLANTA aplicado.'
GO
