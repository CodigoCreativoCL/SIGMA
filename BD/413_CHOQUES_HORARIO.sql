/* ============================================================================
   413 · Choques de horario sobre un mismo objeto mantenible (09-10-2026)

   CRITERIOS (pedido del cliente, 09-10-2026):
     CA-1  Un activo, subactivo o componente no debería estar en dos planes, inspecciones o
           tareas a la misma hora. Si pasa, SIGMA lo ADVIERTE (no lo bloquea).
     CA-2  «Mismo objeto» = el mismo, o uno contiene al otro: el activo completo contiene a sus
           subactivos y a todos sus componentes; un subactivo completo contiene a sus componentes.
           Dos componentes distintos del mismo activo NO chocan.
     CA-3  «Misma hora» = las ventanas [inicio, inicio + duración estimada) se cruzan: mientras dura el
           trabajo el equipo está parado y no se le asigna otra inspección, tarea ni OT. Duración: la
           de la OT si la ocurrencia ya tiene una; si no, la de la intervención (plan) o, sin ella, la
           suma de sus actividades o de sus procedimientos; cpr_duracion_minuto (inspección);
           tar_duracion_estimada_minuto (tarea); otr_duracion_estimada_minuto (OT suelta). Sin dato,
           60 min el plan y la OT, 30 min la inspección y la tarea.
     CA-4  Se miran las ocurrencias PENDIENTES, DISPONIBLES o EN EJECUCIÓN (estados 1–3) y las OT
           abiertas con fecha programada (manuales, correctivas, de avisos), desde
           hoy y hasta 90 días (el horizonte de generación). Lo cerrado o cancelado no cuenta.
     CA-5  Al guardar una inspección, una tarea o una OT, el cajón muestra los choques de las fechas
           que tendría y pide «Guardar igual». En el plan aparecen en «Revisa antes de activar».
     CA-7  Tampoco la misma persona, grupo o empresa externa en dos trabajos a la misma hora (un grupo
           cuenta a sus integrantes vigentes). Se advierte igual que CA-1 y se resuelve igual (CA-6).
     CA-6  Se reprograma SOLO lo que choca: si de 4 activos de una planificación 2 chocan, solo esas 2
           ocurrencias se mueven (a una hora libre sugerida o elegida); las otras siguen a su hora.

   · VW_AGENDA_OBJETO: la agenda unificada (plan, inspección, tarea) por objeto mantenible.
   · SEL_PLAN_CHOQUES: los choques de algo ya guardado (plan, inspección o tarea).
   · SEL_PLAN_CHOQUES_CANDIDATO: los de algo que se está por guardar (objetos + fechas + duración).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER VIEW [dbo].[VW_AGENDA_OBJETO]
AS
/* Planes: la duración es la de la intervención; sin ella, la suma de sus actividades y, si tampoco, la de sus
   procedimientos (CA-3). Si la ocurrencia ya tiene OT abierta, manda la fecha y la duración de la OT. */
SELECT  'PLAN' AS TIPO, v.pmv_plan_mantenimiento AS REF, pm.pma_cliente AS CLIENTE, pm.pma_codigo AS REF_CODIGO,
        pm.pma_nombre + N' · ' + h.pmh_nombre AS REF_NOMBRE, o.pmo_id AS OCURRENCIA,
        o.pmo_activo AS ACTIVO, ISNULL(a.act_activo_padre, a.act_id) AS RAIZ, o.pmo_activo_componente AS COMPONENTE,
        ISNULL(ot.otr_fecha_programada_utc, o.pmo_fecha_programada_utc) AS INICIO,
        DATEADD(MINUTE, COALESCE(NULLIF(ot.otr_duracion_estimada_minuto, 0), NULLIF(h.pmh_duracion_estimada_minuto, 0), NULLIF(du.ACT, 0), NULLIF(du.PRC, 0), 60),
                ISNULL(ot.otr_fecha_programada_utc, o.pmo_fecha_programada_utc)) AS FIN, o.pmo_orden_trabajo AS OT_ID,
        CASE WHEN o.pmo_plan_ocurrencia_estado IN (1, 2) AND ISNULL(ot.otr_orden_trabajo_estado, 1) = 1 THEN 1 ELSE 0 END AS MOVIBLE
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] pm ON pm.pma_id = v.pmv_plan_mantenimiento
JOIN    [dbo].[Activo] a ON a.act_id = o.pmo_activo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo AND ot.otr_habilitado = 1
OUTER APPLY (SELECT SUM(ISNULL(x.paa_duracion_estimada_minuto, 0)) AS ACT, SUM(ISNULL(pr.prc_duracion_estimada_minuto, 0)) AS PRC
             FROM [dbo].[Plan_Mantenimiento_Actividad] x LEFT JOIN [dbo].[Procedimiento] pr ON pr.prc_id = x.paa_procedimiento
             WHERE x.paa_plan_mantenimiento_hito = h.pmh_id AND x.paa_habilitado = 1) du
WHERE   o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3) AND ISNULL(ot.otr_orden_trabajo_estado, 1) IN (1, 2, 3)
UNION ALL
/* Inspecciones */
SELECT  'INS', cp.cpr_inspeccion, cp.cpr_cliente, N'INS-' + RIGHT(N'000' + CAST(cp.cpr_inspeccion AS NVARCHAR(10)), 3),
        cp.cpr_nombre, o.coc_id,
        cp.cpr_activo, ISNULL(a.act_activo_padre, a.act_id), cp.cpr_activo_componente,
        o.coc_fecha_programada_utc, DATEADD(MINUTE, ISNULL(NULLIF(cp.cpr_duracion_minuto, 0), 30), o.coc_fecha_programada_utc), CAST(NULL AS INT), CASE WHEN o.coc_checklist_ocurrencia_estado IN (1, 2) THEN 1 ELSE 0 END
FROM    [dbo].[Checklist_Ocurrencia] o
JOIN    [dbo].[Checklist_Programacion] cp ON cp.cpr_id = o.coc_checklist_programacion
JOIN    [dbo].[Activo] a ON a.act_id = cp.cpr_activo
WHERE   o.coc_habilitado = 1 AND o.coc_checklist_ocurrencia_estado IN (1, 2, 3)
UNION ALL
/* Tareas */
SELECT  'TAR', t.tar_id, t.tar_cliente, t.tar_codigo, t.tar_titulo, o.toc_id,
        t.tar_activo, ISNULL(a.act_activo_padre, a.act_id), t.tar_activo_componente,
        o.toc_fecha_programada_utc, DATEADD(MINUTE, ISNULL(NULLIF(t.tar_duracion_estimada_minuto, 0), 30), o.toc_fecha_programada_utc), o.toc_orden_trabajo, CASE WHEN o.toc_tarea_ocurrencia_estado IN (1, 2) AND o.toc_orden_trabajo IS NULL THEN 1 ELSE 0 END
FROM    [dbo].[Tarea_Ocurrencia] o
JOIN    [dbo].[Tarea] t ON t.tar_id = o.toc_tarea
JOIN    [dbo].[Activo] a ON a.act_id = t.tar_activo
WHERE   o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado IN (1, 2, 3)
UNION ALL
/* OT sueltas (manuales, correctivas, de avisos): las de un plan o una tarea ya están arriba como su ocurrencia. */
SELECT  'OT', ot.otr_id, ot.otr_cliente, N'OT-' + CAST(ot.otr_correlativo AS NVARCHAR(12)), ot.otr_titulo, ot.otr_id,
        ot.otr_activo, ISNULL(a.act_activo_padre, a.act_id), ot.otr_activo_componente,
        ot.otr_fecha_programada_utc, DATEADD(MINUTE, ISNULL(NULLIF(ot.otr_duracion_estimada_minuto, 0), 60), ot.otr_fecha_programada_utc), ot.otr_id, CASE WHEN ot.otr_orden_trabajo_estado = 1 THEN 1 ELSE 0 END
FROM    [dbo].[Orden_Trabajo] ot
JOIN    [dbo].[Activo] a ON a.act_id = ot.otr_activo
WHERE   ot.otr_habilitado = 1 AND ot.otr_orden_trabajo_estado IN (1, 2, 3) AND ot.otr_fecha_programada_utc IS NOT NULL
  AND   ot.otr_plan_mantenimiento_ocurrencia IS NULL AND ot.otr_tarea_ocurrencia IS NULL
GO


/* CA-7 (09-10-2026): tampoco la misma PERSONA, GRUPO o EMPRESA EXTERNA en dos trabajos a la misma hora.
   VW_AGENDA_RECURSO: cada ocurrencia de la agenda con quién la ejecuta, como clave U:<usuario>, G:<grupo>,
   E:<proveedor>. Si tiene OT manda la asignación de la OT; si no, la de la ocurrencia (inspección, tarea)
   o la de la intervención (plan: responsables, grupo, empresa). Un grupo también aporta a cada integrante
   vigente (U:), así una persona choca con un grupo del que es parte. Disponible = sin filas. */
CREATE OR ALTER VIEW [dbo].[VW_AGENDA_RECURSO]
AS
WITH B AS (
    SELECT a.TIPO, a.REF, a.CLIENTE, a.REF_CODIGO, a.REF_NOMBRE, a.OCURRENCIA, a.INICIO, a.FIN, a.OT_ID, a.MOVIBLE, x.U, x.G, x.E
    FROM   [dbo].[VW_AGENDA_OBJETO] a
    CROSS APPLY (
        SELECT ota_usuario AS U, ota_grupo_trabajo AS G, ota_proveedor AS E FROM [dbo].[Orden_Trabajo_Asignacion]
         WHERE a.OT_ID IS NOT NULL AND ota_orden_trabajo = a.OT_ID AND ota_habilitado = 1
        UNION ALL
        SELECT coa_usuario, coa_grupo_trabajo, coa_proveedor FROM [dbo].[Checklist_Ocurrencia_Asignacion]
         WHERE a.OT_ID IS NULL AND a.TIPO = 'INS' AND coa_checklist_ocurrencia = a.OCURRENCIA
        UNION ALL
        SELECT toa_usuario, toa_grupo_trabajo, toa_proveedor FROM [dbo].[Tarea_Ocurrencia_Asignacion]
         WHERE a.OT_ID IS NULL AND a.TIPO = 'TAR' AND toa_tarea_ocurrencia = a.OCURRENCIA
        UNION ALL
        SELECT r.phr_usuario, NULL, NULL FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito_Responsable] r ON r.phr_plan_mantenimiento_hito = o.pmo_plan_mantenimiento_hito
         WHERE a.OT_ID IS NULL AND a.TIPO = 'PLAN' AND o.pmo_id = a.OCURRENCIA
        UNION ALL
        SELECT NULL, h.pmh_grupo_trabajo, NULL FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
         WHERE a.OT_ID IS NULL AND a.TIPO = 'PLAN' AND o.pmo_id = a.OCURRENCIA AND h.pmh_grupo_trabajo IS NOT NULL
        UNION ALL
        SELECT NULL, NULL, x.php_proveedor FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito_Proveedor] x ON x.php_plan_mantenimiento_hito = o.pmo_plan_mantenimiento_hito
         WHERE a.OT_ID IS NULL AND a.TIPO = 'PLAN' AND o.pmo_id = a.OCURRENCIA
    ) x
)
SELECT b.TIPO, b.REF, b.CLIENTE, b.REF_CODIGO, b.REF_NOMBRE, b.OCURRENCIA, b.INICIO, b.FIN, b.OT_ID, b.MOVIBLE,
       'U:' + CAST(b.U AS VARCHAR(12)) AS CLAVE, LTRIM(RTRIM(ISNULL(u.usu_nombre COLLATE DATABASE_DEFAULT, N'') + N' ' + ISNULL(u.usu_apellido_paterno COLLATE DATABASE_DEFAULT, N''))) AS RECURSO
FROM   B b JOIN [dbo].[Usuario] u ON u.usu_id = b.U
UNION ALL
SELECT b.TIPO, b.REF, b.CLIENTE, b.REF_CODIGO, b.REF_NOMBRE, b.OCURRENCIA, b.INICIO, b.FIN, b.OT_ID, b.MOVIBLE,
       'G:' + CAST(b.G AS VARCHAR(12)), N'Grupo ' + g.gtr_nombre COLLATE DATABASE_DEFAULT
FROM   B b JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = b.G
UNION ALL
SELECT b.TIPO, b.REF, b.CLIENTE, b.REF_CODIGO, b.REF_NOMBRE, b.OCURRENCIA, b.INICIO, b.FIN, b.OT_ID, b.MOVIBLE,
       'U:' + CAST(m.gtu_usuario AS VARCHAR(12)), LTRIM(RTRIM(ISNULL(u.usu_nombre COLLATE DATABASE_DEFAULT, N'') + N' ' + ISNULL(u.usu_apellido_paterno COLLATE DATABASE_DEFAULT, N''))) + N' (grupo ' + g.gtr_nombre COLLATE DATABASE_DEFAULT + N')'
FROM   B b JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = b.G
JOIN   [dbo].[Grupo_Trabajo_Usuario] m ON m.gtu_grupo_trabajo = b.G AND m.gtu_fecha_inicio <= CAST(b.INICIO AS DATE) AND (m.gtu_fecha_fin IS NULL OR m.gtu_fecha_fin >= CAST(b.INICIO AS DATE))
JOIN   [dbo].[Usuario] u ON u.usu_id = m.gtu_usuario
WHERE  b.U IS NULL OR b.U <> m.gtu_usuario
UNION ALL
SELECT b.TIPO, b.REF, b.CLIENTE, b.REF_CODIGO, b.REF_NOMBRE, b.OCURRENCIA, b.INICIO, b.FIN, b.OT_ID, b.MOVIBLE,
       'E:' + CAST(b.E AS VARCHAR(12)), N'Empresa ' + pr.prv_razon_social COLLATE DATABASE_DEFAULT
FROM   B b JOIN [dbo].[Proveedor] pr ON pr.prv_id = b.E
GO

/* CA-2: ¿dos objetos se pisan? (la misma raíz y uno contiene al otro) */
CREATE OR ALTER FUNCTION [dbo].[FNC_OBJETOS_SE_PISAN](@R1 INT, @A1 INT, @C1 INT, @R2 INT, @A2 INT, @C2 INT)
RETURNS BIT
AS
BEGIN
    IF @R1 <> @R2 RETURN 0
    IF (@A1 = @R1 AND @C1 IS NULL) OR (@A2 = @R2 AND @C2 IS NULL) RETURN 1   -- un activo completo contiene todo lo suyo
    IF @A1 = @A2 AND (@C1 IS NULL OR @C2 IS NULL OR @C1 = @C2) RETURN 1    -- mismo subactivo, o mismo componente
    RETURN 0
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CHOQUES]
    @CLIENTE INT,
    @TIPO    VARCHAR(4),     -- PLAN · INS · TAR · OT
    @REF     INT
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, 90, @HOY)
SELECT  DISTINCT TOP 200 m.INICIO AS FECHA, ac.act_codigo + ISNULL(N' › ' + cc.aco_nombre, N'') AS OBJETO,
        o.TIPO AS CON_TIPO, o.REF AS CON_REF, o.REF_CODIGO AS CON_CODIGO, o.REF_NOMBRE AS CON_NOMBRE, o.INICIO AS CON_INICIO, o.FIN AS CON_FIN,
        m.TIPO AS TIPO, m.OCURRENCIA AS OCURRENCIA, DATEDIFF(MINUTE, m.INICIO, m.FIN) AS DURACION, m.MOVIBLE AS MOVIBLE, m.OT_ID AS OT_ID, 'OBJETO' AS CLASE
FROM    [dbo].[VW_AGENDA_OBJETO] m
JOIN    [dbo].[VW_AGENDA_OBJETO] o ON o.CLIENTE = m.CLIENTE AND NOT (o.TIPO = m.TIPO AND o.REF = m.REF)
       AND o.INICIO < m.FIN AND m.INICIO < o.FIN AND o.RAIZ = m.RAIZ
       AND [dbo].[FNC_OBJETOS_SE_PISAN](m.RAIZ, m.ACTIVO, m.COMPONENTE, o.RAIZ, o.ACTIVO, o.COMPONENTE) = 1
JOIN    [dbo].[Activo] ac ON ac.act_id = m.ACTIVO
LEFT JOIN [dbo].[Activo_Componente] cc ON cc.aco_id = m.COMPONENTE
WHERE   m.CLIENTE = @CLIENTE AND m.TIPO = @TIPO AND m.REF = @REF AND m.INICIO >= @HOY AND m.INICIO < @HASTA
UNION ALL
SELECT  DISTINCT TOP 200 m.INICIO, m.RECURSO,
        o.TIPO, o.REF, o.REF_CODIGO, o.REF_NOMBRE, o.INICIO, o.FIN,
        m.TIPO, m.OCURRENCIA, DATEDIFF(MINUTE, m.INICIO, m.FIN), m.MOVIBLE, m.OT_ID, 'RECURSO'
FROM    [dbo].[VW_AGENDA_RECURSO] m
JOIN    [dbo].[VW_AGENDA_RECURSO] o ON o.CLIENTE = m.CLIENTE AND o.CLAVE = m.CLAVE AND NOT (o.TIPO = m.TIPO AND o.REF = m.REF)
       AND NOT (ISNULL(o.OT_ID, -1) = ISNULL(m.OT_ID, -2))
       AND o.INICIO < m.FIN AND m.INICIO < o.FIN
WHERE   m.CLIENTE = @CLIENTE AND m.TIPO = @TIPO AND m.REF = @REF AND m.INICIO >= @HOY AND m.INICIO < @HASTA
ORDER BY 1, 7
GO

/* Lo que se está por guardar: @OBJETOS = 'activo:componente,…' · @FECHAS = 'AAAA-MM-DDTHH:MM,…'
   (o @PROGRAMACION: un calendario compartido, sus fechas de los próximos 90 días). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CHOQUES_CANDIDATO]
    @CLIENTE      INT,
    @TIPO         VARCHAR(4),
    @REF          INT = NULL,          -- lo que se edita: sus propias ocurrencias no cuentan
    @OBJETOS      NVARCHAR(MAX),
    @FECHAS       NVARCHAR(MAX) = NULL,
    @PROGRAMACION INT = NULL,
    @DURACION     INT = NULL,
    @RECURSOS     NVARCHAR(MAX) = NULL     -- quién lo ejecutaría: 'U:1,G:3,E:7' (CA-7)
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, 90, @HOY)
DECLARE @DUR INT = ISNULL(NULLIF(@DURACION, 0), CASE WHEN @TIPO = 'PLAN' THEN 60 ELSE 30 END)
DECLARE @O TABLE (act INT, comp INT, raiz INT)
INSERT @O (act, comp, raiz)
SELECT x.act, x.comp, ISNULL(a.act_activo_padre, a.act_id)
FROM (SELECT TRY_CAST(LEFT(v.value, CHARINDEX(':', v.value + ':') - 1) AS INT) AS act,
             NULLIF(TRY_CAST(SUBSTRING(v.value, CHARINDEX(':', v.value + ':') + 1, 20) AS INT), 0) AS comp
      FROM STRING_SPLIT(ISNULL(@OBJETOS, N''), ',') v WHERE LTRIM(v.value) <> N'') x
JOIN [dbo].[Activo] a ON a.act_id = x.act AND a.act_cliente = @CLIENTE
DECLARE @F TABLE (ini DATETIME)
IF @PROGRAMACION IS NOT NULL
    INSERT @F SELECT f.FECHA FROM [dbo].[FNC_PROGRAMACION_FECHAS](@PROGRAMACION, @HOY, @HASTA) f WHERE f.DESCARTADA = 0
ELSE
    INSERT @F SELECT TRY_CAST(REPLACE(v.value, 'T', ' ') AS DATETIME) FROM STRING_SPLIT(ISNULL(@FECHAS, N''), ',') v WHERE TRY_CAST(REPLACE(v.value, 'T', ' ') AS DATETIME) IS NOT NULL

/* Los recursos del candidato; un grupo aporta también a sus integrantes vigentes. */
DECLARE @R TABLE (clave VARCHAR(20), nombre NVARCHAR(300))
INSERT @R (clave, nombre)
SELECT 'U:' + CAST(u.usu_id AS VARCHAR(12)), LTRIM(RTRIM(ISNULL(u.usu_nombre COLLATE DATABASE_DEFAULT, N'') + N' ' + ISNULL(u.usu_apellido_paterno COLLATE DATABASE_DEFAULT, N'')))
FROM STRING_SPLIT(ISNULL(@RECURSOS, N''), ',') v JOIN [dbo].[Usuario] u ON LEFT(LTRIM(v.value), 2) = 'U:' AND u.usu_id = TRY_CAST(SUBSTRING(LTRIM(v.value), 3, 12) AS INT)
UNION
SELECT 'G:' + CAST(g.gtr_id AS VARCHAR(12)), N'Grupo ' + g.gtr_nombre COLLATE DATABASE_DEFAULT
FROM STRING_SPLIT(ISNULL(@RECURSOS, N''), ',') v JOIN [dbo].[Grupo_Trabajo] g ON LEFT(LTRIM(v.value), 2) = 'G:' AND g.gtr_id = TRY_CAST(SUBSTRING(LTRIM(v.value), 3, 12) AS INT) AND g.gtr_cliente = @CLIENTE
UNION
SELECT 'U:' + CAST(m.gtu_usuario AS VARCHAR(12)), LTRIM(RTRIM(ISNULL(u.usu_nombre COLLATE DATABASE_DEFAULT, N'') + N' ' + ISNULL(u.usu_apellido_paterno COLLATE DATABASE_DEFAULT, N''))) + N' (grupo ' + g.gtr_nombre COLLATE DATABASE_DEFAULT + N')'
FROM STRING_SPLIT(ISNULL(@RECURSOS, N''), ',') v JOIN [dbo].[Grupo_Trabajo] g ON LEFT(LTRIM(v.value), 2) = 'G:' AND g.gtr_id = TRY_CAST(SUBSTRING(LTRIM(v.value), 3, 12) AS INT) AND g.gtr_cliente = @CLIENTE
JOIN [dbo].[Grupo_Trabajo_Usuario] m ON m.gtu_grupo_trabajo = g.gtr_id AND m.gtu_fecha_inicio <= @HOY AND (m.gtu_fecha_fin IS NULL OR m.gtu_fecha_fin >= @HOY)
JOIN [dbo].[Usuario] u ON u.usu_id = m.gtu_usuario
UNION
SELECT 'E:' + CAST(pr.prv_id AS VARCHAR(12)), N'Empresa ' + pr.prv_razon_social COLLATE DATABASE_DEFAULT
FROM STRING_SPLIT(ISNULL(@RECURSOS, N''), ',') v JOIN [dbo].[Proveedor] pr ON LEFT(LTRIM(v.value), 2) = 'E:' AND pr.prv_id = TRY_CAST(SUBSTRING(LTRIM(v.value), 3, 12) AS INT)

SELECT * FROM (
SELECT  DISTINCT TOP 200 f.ini AS FECHA, ac.act_codigo + ISNULL(N' › ' + cc.aco_nombre, N'') AS OBJETO,
        g.TIPO AS CON_TIPO, g.REF AS CON_REF, g.REF_CODIGO AS CON_CODIGO, g.REF_NOMBRE AS CON_NOMBRE, g.INICIO AS CON_INICIO, g.FIN AS CON_FIN, 'OBJETO' AS CLASE
FROM    @F f CROSS JOIN @O o
JOIN    [dbo].[VW_AGENDA_OBJETO] g ON g.CLIENTE = @CLIENTE AND NOT (g.TIPO = @TIPO AND g.REF = ISNULL(@REF, -1))
       AND NOT (@TIPO = 'OT' AND ISNULL(g.OT_ID, 0) = ISNULL(@REF, -1))   -- una OT nacida de un plan o tarea no choca consigo misma
       AND g.INICIO < DATEADD(MINUTE, @DUR, f.ini) AND f.ini < g.FIN AND g.RAIZ = o.raiz
       AND [dbo].[FNC_OBJETOS_SE_PISAN](o.raiz, o.act, o.comp, g.RAIZ, g.ACTIVO, g.COMPONENTE) = 1
JOIN    [dbo].[Activo] ac ON ac.act_id = o.act
LEFT JOIN [dbo].[Activo_Componente] cc ON cc.aco_id = o.comp
WHERE   f.ini >= @HOY AND f.ini < @HASTA
UNION ALL
SELECT  DISTINCT TOP 200 f.ini, r.nombre, g.TIPO, g.REF, g.REF_CODIGO, g.REF_NOMBRE, g.INICIO, g.FIN, 'RECURSO'
FROM    @F f CROSS JOIN @R r
JOIN    [dbo].[VW_AGENDA_RECURSO] g ON g.CLIENTE = @CLIENTE AND g.CLAVE = r.clave AND NOT (g.TIPO = @TIPO AND g.REF = ISNULL(@REF, -1))
       AND NOT (@TIPO = 'OT' AND ISNULL(g.OT_ID, 0) = ISNULL(@REF, -1))
       AND g.INICIO < DATEADD(MINUTE, @DUR, f.ini) AND f.ini < g.FIN
WHERE   f.ini >= @HOY AND f.ini < @HASTA
) z
ORDER BY FECHA, CON_INICIO
GO

/* CA-6 (09-10-2026): si hay choque se reprograma SOLO la ocurrencia que choca; las demás del mismo
   plan, inspección o tarea (otros activos) siguen a su hora.
   SEL_AGENDA_HUECOS: las próximas 3 horas libres para una ocurrencia (de 30 en 30 min, entre las 06:00 y
   las 22:00, hasta 3 días), sin pisar a nadie sobre el mismo objeto mantenible. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AGENDA_HUECOS]
    @CLIENTE    INT,
    @TIPO       VARCHAR(4),
    @OCURRENCIA INT
AS
SET NOCOUNT ON
DECLARE @INI DATETIME, @FIN DATETIME, @ACT INT, @RAIZ INT, @COMP INT
SELECT TOP 1 @INI = INICIO, @FIN = FIN, @ACT = ACTIVO, @RAIZ = RAIZ, @COMP = COMPONENTE
FROM [dbo].[VW_AGENDA_OBJETO] WHERE CLIENTE = @CLIENTE AND TIPO = @TIPO AND OCURRENCIA = @OCURRENCIA
IF @INI IS NULL RETURN 0
DECLARE @DUR INT = DATEDIFF(MINUTE, @INI, @FIN), @AHORA DATETIME = [dbo].[FNC_AHORA]()
/* CA-7: quienes la ejecutan tampoco pueden estar ocupados en la hora sugerida. */
DECLARE @K TABLE (clave VARCHAR(20) PRIMARY KEY)
INSERT @K SELECT DISTINCT CLAVE FROM [dbo].[VW_AGENDA_RECURSO] WHERE CLIENTE = @CLIENTE AND TIPO = @TIPO AND OCURRENCIA = @OCURRENCIA
DECLARE @REFX INT = (SELECT TOP 1 REF FROM [dbo].[VW_AGENDA_OBJETO] WHERE CLIENTE = @CLIENTE AND TIPO = @TIPO AND OCURRENCIA = @OCURRENCIA)
;WITH N AS (SELECT TOP 144 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k FROM sys.all_objects),
C AS (SELECT DATEADD(MINUTE, 30 * k, @INI) AS ini FROM N)
SELECT TOP 3 c.ini AS INICIO, DATEADD(MINUTE, @DUR, c.ini) AS FIN
FROM   C c
WHERE  c.ini > @AHORA
  AND  CAST(c.ini AS TIME) >= '06:00' AND CAST(DATEADD(MINUTE, @DUR, c.ini) AS TIME) <= '22:00' AND CAST(DATEADD(MINUTE, @DUR, c.ini) AS DATE) = CAST(c.ini AS DATE)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[VW_AGENDA_OBJETO] g
                   WHERE g.CLIENTE = @CLIENTE AND NOT (g.TIPO = @TIPO AND g.OCURRENCIA = @OCURRENCIA) AND g.RAIZ = @RAIZ
                     AND g.INICIO < DATEADD(MINUTE, @DUR, c.ini) AND c.ini < g.FIN
                     AND [dbo].[FNC_OBJETOS_SE_PISAN](@RAIZ, @ACT, @COMP, g.RAIZ, g.ACTIVO, g.COMPONENTE) = 1)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[VW_AGENDA_RECURSO] r JOIN @K k ON k.clave = r.CLAVE
                   WHERE r.CLIENTE = @CLIENTE AND NOT (r.TIPO = @TIPO AND r.REF = @REFX)
                     AND r.INICIO < DATEADD(MINUTE, @DUR, c.ini) AND c.ini < r.FIN)
ORDER BY c.ini
GO

/* Reprograma UNA ocurrencia (plan, inspección, tarea u OT suelta) a otra fecha y hora (también el mismo día).
   Como PLAN_OCURRENCIA_REPROGRAMAR: la vieja queda REPROGRAMADA (7) en su fecha —así el generador no la
   vuelve a crear— y nace una nueva en PENDIENTE con la ventana corrida y la fecha original de la cadena.
   Si la ocurrencia del plan ya tiene OT (abierta, sin iniciar), se mueve la OT. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AGENDA_REPROGRAMAR]
    @CLIENTE    INT,
    @TIPO       VARCHAR(4),
    @OCURRENCIA INT,
    @FECHA      DATETIME,
    @MOTIVO     NVARCHAR(500) = NULL,
    @USUARIO    INT,
    @NUEVO      INT = NULL OUTPUT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @ACT DATETIME, @OT INT, @DELTA INT
SET @MOTIVO = ISNULL(NULLIF(LTRIM(RTRIM(@MOTIVO)), N''), N'Choque de horario: se movió a una hora libre')
IF @FECHA IS NULL BEGIN RAISERROR('1.- INDICA LA NUEVA FECHA Y HORA.', 16, 1) RETURN -1 END
IF @FECHA < @AHORA BEGIN RAISERROR('2.- LA NUEVA FECHA YA PASO.', 16, 1) RETURN -1 END

IF @TIPO = 'PLAN'
BEGIN
    SELECT @ACT = pmo_fecha_programada_utc, @OT = pmo_orden_trabajo FROM [dbo].[Plan_Mantenimiento_Ocurrencia]
     WHERE pmo_id = @OCURRENCIA AND pmo_cliente = @CLIENTE AND pmo_habilitado = 1 AND pmo_plan_ocurrencia_estado IN (1, 2, 3)
    IF @ACT IS NULL BEGIN RAISERROR('3.- SOLO SE REPROGRAMA LO PENDIENTE.', 16, 1) RETURN -1 END
    IF @OT IS NOT NULL
    BEGIN
        UPDATE [dbo].[Orden_Trabajo] SET otr_fecha_programada_utc = @FECHA, otr_usuario_actualizacion = @USUARIO, otr_fecha_actualizacion = @AHORA
         WHERE otr_id = @OT AND otr_cliente = @CLIENTE AND otr_orden_trabajo_estado = 1
        IF @@ROWCOUNT = 0 BEGIN RAISERROR('4.- LA OT YA EMPEZO: CAMBIALA DESDE SU FICHA.', 16, 1) RETURN -1 END
        SET @NUEVO = @OCURRENCIA
    END
    ELSE
    BEGIN
        IF @FECHA = @ACT BEGIN RAISERROR('5.- ES LA MISMA FECHA Y HORA.', 16, 1) RETURN -1 END
        SET @DELTA = DATEDIFF(MINUTE, @ACT, @FECHA)
        BEGIN TRANSACTION
            UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia] SET pmo_plan_ocurrencia_estado = 7, pmo_observacion = @MOTIVO, pmo_usuario_actualizacion = @USUARIO, pmo_fecha_actualizacion = @AHORA
             WHERE pmo_id = @OCURRENCIA AND pmo_plan_ocurrencia_estado IN (1, 2)
            IF @@ROWCOUNT = 0 BEGIN ROLLBACK TRANSACTION RAISERROR('6.- LA OCURRENCIA YA NO ESTABA PENDIENTE.', 16, 1) RETURN -1 END
            INSERT [dbo].[Plan_Mantenimiento_Ocurrencia] (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
                   pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc, pmo_fecha_programada_original_utc, pmo_ocurrencia_origen,
                   pmo_valor_medidor_objetivo, pmo_plan_ocurrencia_estado, pmo_observacion, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
            SELECT NEWID(), pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
                   @FECHA, DATEADD(MINUTE, @DELTA, pmo_fecha_limite_utc), DATEADD(MINUTE, @DELTA, pmo_fecha_disponible_utc), ISNULL(pmo_fecha_programada_original_utc, pmo_fecha_programada_utc), pmo_id,
                   pmo_valor_medidor_objetivo, 1, @MOTIVO, @USUARIO, @AHORA, 1
            FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_id = @OCURRENCIA
            SET @NUEVO = SCOPE_IDENTITY()
        COMMIT TRANSACTION
    END
END
ELSE IF @TIPO = 'INS'
BEGIN
    SELECT @ACT = coc_fecha_programada_utc FROM [dbo].[Checklist_Ocurrencia]
     WHERE coc_id = @OCURRENCIA AND coc_cliente = @CLIENTE AND coc_habilitado = 1 AND coc_checklist_ocurrencia_estado IN (1, 2)
    IF @ACT IS NULL BEGIN RAISERROR('3.- SOLO SE REPROGRAMA LO PENDIENTE.', 16, 1) RETURN -1 END
    IF @FECHA = @ACT BEGIN RAISERROR('5.- ES LA MISMA FECHA Y HORA.', 16, 1) RETURN -1 END
    SET @DELTA = DATEDIFF(MINUTE, @ACT, @FECHA)
    BEGIN TRANSACTION
        UPDATE [dbo].[Checklist_Ocurrencia] SET coc_checklist_ocurrencia_estado = 7, coc_usuario_actualizacion = @USUARIO, coc_fecha_actualizacion = @AHORA
         WHERE coc_id = @OCURRENCIA AND coc_checklist_ocurrencia_estado IN (1, 2)
        INSERT [dbo].[Checklist_Ocurrencia] (coc_uuid, coc_cliente, coc_checklist_programacion, coc_checklist_plantilla_version, coc_activo, coc_instalacion_area,
               coc_checklist_ocurrencia_estado, coc_fecha_programada_utc, coc_fecha_disponible_utc, coc_fecha_limite_utc, coc_fecha_programada_original_utc,
               coc_ocurrencia_origen, coc_usuario_creacion, coc_fecha_creacion, coc_habilitado)
        SELECT NEWID(), coc_cliente, coc_checklist_programacion, coc_checklist_plantilla_version, coc_activo, coc_instalacion_area,
               1, @FECHA, DATEADD(MINUTE, @DELTA, coc_fecha_disponible_utc), DATEADD(MINUTE, @DELTA, coc_fecha_limite_utc), ISNULL(coc_fecha_programada_original_utc, coc_fecha_programada_utc),
               coc_id, @USUARIO, @AHORA, 1
        FROM [dbo].[Checklist_Ocurrencia] WHERE coc_id = @OCURRENCIA
        SET @NUEVO = SCOPE_IDENTITY()
        INSERT [dbo].[Checklist_Ocurrencia_Asignacion] (coa_checklist_ocurrencia, coa_usuario, coa_grupo_trabajo, coa_proveedor, coa_es_responsable, coa_fecha_asignacion_utc, coa_usuario_creacion, coa_fecha_creacion)
        SELECT @NUEVO, coa_usuario, coa_grupo_trabajo, coa_proveedor, coa_es_responsable, GETUTCDATE(), @USUARIO, @AHORA FROM [dbo].[Checklist_Ocurrencia_Asignacion] WHERE coa_checklist_ocurrencia = @OCURRENCIA
    COMMIT TRANSACTION
END
ELSE IF @TIPO = 'TAR'
BEGIN
    SELECT @ACT = toc_fecha_programada_utc FROM [dbo].[Tarea_Ocurrencia]
     WHERE toc_id = @OCURRENCIA AND toc_cliente = @CLIENTE AND toc_habilitado = 1 AND toc_tarea_ocurrencia_estado IN (1, 2) AND toc_orden_trabajo IS NULL
    IF @ACT IS NULL BEGIN RAISERROR('3.- SOLO SE REPROGRAMA LO PENDIENTE.', 16, 1) RETURN -1 END
    IF @FECHA = @ACT BEGIN RAISERROR('5.- ES LA MISMA FECHA Y HORA.', 16, 1) RETURN -1 END
    SET @DELTA = DATEDIFF(MINUTE, @ACT, @FECHA)
    BEGIN TRANSACTION
        UPDATE [dbo].[Tarea_Ocurrencia] SET toc_tarea_ocurrencia_estado = 7, toc_observacion = @MOTIVO, toc_usuario_actualizacion = @USUARIO, toc_fecha_actualizacion = @AHORA
         WHERE toc_id = @OCURRENCIA AND toc_tarea_ocurrencia_estado IN (1, 2)
        INSERT [dbo].[Tarea_Ocurrencia] (toc_uuid, toc_cliente, toc_tarea, toc_tarea_programacion, toc_tarea_ocurrencia_estado, toc_fecha_programada_utc, toc_fecha_disponible_utc,
               toc_fecha_limite_utc, toc_fecha_programada_original_utc, toc_ocurrencia_origen, toc_observacion, toc_usuario_creacion, toc_fecha_creacion, toc_habilitado)
        SELECT NEWID(), toc_cliente, toc_tarea, toc_tarea_programacion, 1, @FECHA, DATEADD(MINUTE, @DELTA, toc_fecha_disponible_utc),
               DATEADD(MINUTE, @DELTA, toc_fecha_limite_utc), ISNULL(toc_fecha_programada_original_utc, toc_fecha_programada_utc), toc_id, @MOTIVO, @USUARIO, @AHORA, 1
        FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = @OCURRENCIA
        SET @NUEVO = SCOPE_IDENTITY()
        INSERT [dbo].[Tarea_Ocurrencia_Asignacion] (toa_tarea_ocurrencia, toa_usuario, toa_grupo_trabajo, toa_proveedor, toa_es_responsable, toa_fecha_asignacion_utc, toa_usuario_creacion, toa_fecha_creacion)
        SELECT @NUEVO, toa_usuario, toa_grupo_trabajo, toa_proveedor, toa_es_responsable, GETUTCDATE(), @USUARIO, @AHORA FROM [dbo].[Tarea_Ocurrencia_Asignacion] WHERE toa_tarea_ocurrencia = @OCURRENCIA
    COMMIT TRANSACTION
END
ELSE IF @TIPO = 'OT'
BEGIN
    UPDATE [dbo].[Orden_Trabajo] SET otr_fecha_programada_utc = @FECHA, otr_usuario_actualizacion = @USUARIO, otr_fecha_actualizacion = @AHORA
     WHERE otr_id = @OCURRENCIA AND otr_cliente = @CLIENTE AND otr_orden_trabajo_estado = 1
    IF @@ROWCOUNT = 0 BEGIN RAISERROR('4.- LA OT YA EMPEZO: CAMBIALA DESDE SU FICHA.', 16, 1) RETURN -1 END
    SET @NUEVO = @OCURRENCIA
END
ELSE BEGIN RAISERROR('7.- EL TIPO NO EXISTE.', 16, 1) RETURN -1 END
SELECT @NUEVO AS ID
GO
PRINT '413_CHOQUES_HORARIO aplicado.'
GO
