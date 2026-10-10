/* ============================================================================
   388 · Lista de planes del Centro de Planificación (08-10-2026)

   SEL_PLAN_CENTRO suma lo que pintan la tabla y las tarjetas:
     FRECUENCIAS      en corto («Mensual · Cada 3 meses · Por medidor»);
     RESPONSABLES     hasta tres nombres, separados por «|»;
     FALTAN           cuántos obligatorios le faltan a un borrador (los mismos
                      que valida la ficha: activos, intervención, nombre y
                      duración, frecuencia);
     ACTIVOS_TXT / INTERVENCIONES_TXT   para buscar por activo o intervención.
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CENTRO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @PLAN        INT = NULL
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = GETUTCDATE()

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
PRINT '388_LISTA_PLANES aplicado.'
GO
