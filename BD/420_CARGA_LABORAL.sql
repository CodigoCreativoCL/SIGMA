/* ============================================================================
   420 · Carga laboral de personas, grupos y empresas (09-10-2026)

   Pedido del cliente: en toda vista donde se asignan responsables, poder ver EN QUÉ ESTÁ cada uno
   (calendario mensual) y saber quién es el que tiene el choque de horario.
   Lee la agenda de BD/413 (VW_AGENDA_RECURSO: plan, inspección, tarea y OT con su asignación; un
   grupo también aporta a sus integrantes). Solo trabajo pendiente o en curso.
     · SEL_AGENDA_CARGA_MES(@CLIENTE, @CLAVE 'U:5'|'G:3'|'E:7', @DESDE, @HASTA)
         0 · quién es (nombre, detalle) y la capacidad diaria de referencia (480 min = 8 h)
         1 · sus trabajos en el rango, con activo y si choca con otro trabajo suyo (CHOQUE)
     · SEL_AGENDA_CARGA_RESUMEN(@CLIENTE, @CLAVES 'U:5,U:8,G:3', @DESDE, @HASTA)
         por clave: minutos, trabajos, choques y días sobre la capacidad (para los selectores).
   Aplicar DESPUÉS de 413. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_AGENDA_CARGA_MES]
    @CLIENTE INT,
    @CLAVE   VARCHAR(20),
    @DESDE   DATE,
    @HASTA   DATE
AS
SET NOCOUNT ON
DECLARE @T CHAR(1) = LEFT(@CLAVE, 1), @ID INT = TRY_CAST(SUBSTRING(@CLAVE, 3, 12) AS INT)
IF @ID IS NULL OR @T NOT IN ('U', 'G', 'E') BEGIN RAISERROR('1.- RECURSO NO VALIDO.', 16, 1) RETURN -1 END

SELECT  @CLAVE AS CLAVE,
        CASE @T WHEN 'U' THEN (SELECT LTRIM(RTRIM(ISNULL(usu_nombre, N'') + N' ' + ISNULL(usu_apellido_paterno, N''))) COLLATE DATABASE_DEFAULT FROM [dbo].[Usuario] WHERE usu_id = @ID)
                WHEN 'G' THEN (SELECT gtr_nombre COLLATE DATABASE_DEFAULT FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @ID)
                ELSE (SELECT prv_razon_social COLLATE DATABASE_DEFAULT FROM [dbo].[Proveedor] WHERE prv_id = @ID) END AS NOMBRE,
        CASE @T WHEN 'U' THEN N'Persona' WHEN 'G' THEN N'Grupo de trabajo' ELSE N'Empresa externa' END AS TIPO_RECURSO,
        CASE @T WHEN 'G' THEN (SELECT COUNT(*) FROM [dbo].[Grupo_Trabajo_Usuario] m WHERE m.gtu_grupo_trabajo = @ID AND m.gtu_fecha_inicio <= CAST(GETDATE() AS DATE) AND (m.gtu_fecha_fin IS NULL OR m.gtu_fecha_fin >= CAST(GETDATE() AS DATE))) END AS INTEGRANTES,
        480 AS CAPACIDAD_MIN

SELECT  DISTINCT r.TIPO, r.REF, r.REF_CODIGO, r.REF_NOMBRE, r.OCURRENCIA, r.INICIO, r.FIN, r.OT_ID, r.MOVIBLE,
        CASE WHEN r.RECURSO LIKE N'%(grupo %' THEN SUBSTRING(r.RECURSO, CHARINDEX(N'(grupo ', r.RECURSO) + 1, 200) END AS VIA
INTO    #C
FROM    [dbo].[VW_AGENDA_RECURSO] r
WHERE   r.CLIENTE = @CLIENTE AND r.CLAVE = @CLAVE AND r.INICIO < DATEADD(DAY, 1, @HASTA) AND r.FIN > @DESDE

SELECT  c.TIPO, c.REF, c.REF_CODIGO, c.REF_NOMBRE, c.OCURRENCIA, c.INICIO, c.FIN, DATEDIFF(MINUTE, c.INICIO, c.FIN) AS MINUTOS,
        c.OT_ID, ot.otr_correlativo AS OT_NUMERO, c.MOVIBLE, REPLACE(c.VIA, N')', N'') AS VIA,
        a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM #C x WHERE NOT (x.TIPO = c.TIPO AND x.OCURRENCIA = c.OCURRENCIA) AND x.INICIO < c.FIN AND x.FIN > c.INICIO) THEN 1 ELSE 0 END AS BIT) AS CHOQUE
FROM    #C c
OUTER APPLY (SELECT TOP 1 o.ACTIVO FROM [dbo].[VW_AGENDA_OBJETO] o WHERE o.TIPO = c.TIPO AND o.OCURRENCIA = c.OCURRENCIA AND o.CLIENTE = @CLIENTE) ob
LEFT JOIN [dbo].[Activo] a ON a.act_id = ob.ACTIVO
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = c.OT_ID
ORDER BY c.INICIO
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_AGENDA_CARGA_RESUMEN]
    @CLIENTE INT,
    @CLAVES  NVARCHAR(MAX),
    @DESDE   DATE,
    @HASTA   DATE
AS
SET NOCOUNT ON
SELECT DISTINCT LTRIM(RTRIM(value)) AS CLAVE INTO #K FROM STRING_SPLIT(ISNULL(@CLAVES, N''), N',') WHERE LTRIM(RTRIM(value)) <> N''

SELECT  DISTINCT r.CLAVE, r.TIPO, r.OCURRENCIA, r.INICIO, r.FIN
INTO    #C
FROM    [dbo].[VW_AGENDA_RECURSO] r JOIN #K k ON k.CLAVE = r.CLAVE COLLATE DATABASE_DEFAULT
WHERE   r.CLIENTE = @CLIENTE AND r.INICIO < DATEADD(DAY, 1, @HASTA) AND r.FIN > @DESDE

SELECT  k.CLAVE,
        ISNULL((SELECT SUM(DATEDIFF(MINUTE, c.INICIO, c.FIN)) FROM #C c WHERE c.CLAVE = k.CLAVE), 0) AS MINUTOS,
        (SELECT COUNT(*) FROM #C c WHERE c.CLAVE = k.CLAVE) AS TRABAJOS,
        (SELECT COUNT(*) FROM #C c WHERE c.CLAVE = k.CLAVE AND EXISTS (SELECT 1 FROM #C x WHERE x.CLAVE = c.CLAVE AND NOT (x.TIPO = c.TIPO AND x.OCURRENCIA = c.OCURRENCIA) AND x.INICIO < c.FIN AND x.FIN > c.INICIO)) AS CHOQUES,
        (SELECT COUNT(*) FROM (SELECT CAST(c.INICIO AS DATE) AS D FROM #C c WHERE c.CLAVE = k.CLAVE GROUP BY CAST(c.INICIO AS DATE) HAVING SUM(DATEDIFF(MINUTE, c.INICIO, c.FIN)) > 480) z) AS DIAS_SOBRE
FROM    #K k
RETURN 0
GO
PRINT '420_CARGA_LABORAL aplicado.'
GO
