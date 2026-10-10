/* ============================================================================
   421 · Choques de horario: quién es el que choca (09-10-2026)
   SEL_PLAN_CHOQUES y SEL_PLAN_CHOQUES_CANDIDATO (BD/413) traen CLAVE ('U:5', 'G:3', 'E:7') en las filas
   de clase RECURSO, para abrir la carga laboral de esa persona, grupo o empresa (BD/420) desde el aviso.
   Generado desde la definición vigente. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
        m.TIPO AS TIPO, m.OCURRENCIA AS OCURRENCIA, DATEDIFF(MINUTE, m.INICIO, m.FIN) AS DURACION, m.MOVIBLE AS MOVIBLE, m.OT_ID AS OT_ID, 'OBJETO' AS CLASE, CAST(NULL AS VARCHAR(20)) AS CLAVE
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
        m.TIPO, m.OCURRENCIA, DATEDIFF(MINUTE, m.INICIO, m.FIN), m.MOVIBLE, m.OT_ID, 'RECURSO', m.CLAVE
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
        g.TIPO AS CON_TIPO, g.REF AS CON_REF, g.REF_CODIGO AS CON_CODIGO, g.REF_NOMBRE AS CON_NOMBRE, g.INICIO AS CON_INICIO, g.FIN AS CON_FIN, 'OBJETO' AS CLASE, CAST(NULL AS VARCHAR(20)) AS CLAVE
FROM    @F f CROSS JOIN @O o
JOIN    [dbo].[VW_AGENDA_OBJETO] g ON g.CLIENTE = @CLIENTE AND NOT (g.TIPO = @TIPO AND g.REF = ISNULL(@REF, -1))
       AND NOT (@TIPO = 'OT' AND ISNULL(g.OT_ID, 0) = ISNULL(@REF, -1))   -- una OT nacida de un plan o tarea no choca consigo misma
       AND g.INICIO < DATEADD(MINUTE, @DUR, f.ini) AND f.ini < g.FIN AND g.RAIZ = o.raiz
       AND [dbo].[FNC_OBJETOS_SE_PISAN](o.raiz, o.act, o.comp, g.RAIZ, g.ACTIVO, g.COMPONENTE) = 1
JOIN    [dbo].[Activo] ac ON ac.act_id = o.act
LEFT JOIN [dbo].[Activo_Componente] cc ON cc.aco_id = o.comp
WHERE   f.ini >= @HOY AND f.ini < @HASTA
UNION ALL
SELECT  DISTINCT TOP 200 f.ini, r.nombre, g.TIPO, g.REF, g.REF_CODIGO, g.REF_NOMBRE, g.INICIO, g.FIN, 'RECURSO', r.clave
FROM    @F f CROSS JOIN @R r
JOIN    [dbo].[VW_AGENDA_RECURSO] g ON g.CLIENTE = @CLIENTE AND g.CLAVE = r.clave AND NOT (g.TIPO = @TIPO AND g.REF = ISNULL(@REF, -1))
       AND NOT (@TIPO = 'OT' AND ISNULL(g.OT_ID, 0) = ISNULL(@REF, -1))
       AND g.INICIO < DATEADD(MINUTE, @DUR, f.ini) AND f.ini < g.FIN
WHERE   f.ini >= @HOY AND f.ini < @HASTA
) z
ORDER BY FECHA, CON_INICIO
GO

PRINT '421_CHOQUES_CLAVE aplicado.'
GO
