/* ============================================================================
   415 · Jornada de trabajo de la planta (09-10-2026)

   Para resolver choques de horario (BD/413) SIGMA sugiere horas libres DENTRO de la jornada de la
   planta del activo. Hasta ahora era 06:00–22:00 fijo.
     · Cliente_Instalacion.cin_jornada_inicio / cin_jornada_fin (TIME, opcionales).
     · SEL_RECURSOS_AJUSTES (BD/406) + conjunto 3: las plantas con su jornada (Recursos › Ajustes).
     · UPS_PLANTA_JORNADA: fija o quita la jornada (vacía = 06:00–22:00).
     · SEL_AGENDA_HUECOS (BD/413) usa la jornada de la planta del activo.
   Aplicar DESPUÉS de 406 y 413. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF COL_LENGTH('dbo.Cliente_Instalacion', 'cin_jornada_inicio') IS NULL ALTER TABLE [dbo].[Cliente_Instalacion] ADD cin_jornada_inicio TIME NULL
IF COL_LENGTH('dbo.Cliente_Instalacion', 'cin_jornada_fin') IS NULL ALTER TABLE [dbo].[Cliente_Instalacion] ADD cin_jornada_fin TIME NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_PLANTA_JORNADA]
    @CLIENTE INT,
    @PLANTA  INT,
    @INICIO  TIME = NULL,
    @FIN     TIME = NULL,
    @USUARIO INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @PLANTA AND cin_cliente = @CLIENTE)
BEGIN RAISERROR('1.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END
IF @INICIO IS NOT NULL AND @FIN IS NOT NULL AND @FIN <= @INICIO
BEGIN RAISERROR('2.- EL TERMINO DE LA JORNADA DEBE SER DESPUES DEL INICIO.', 16, 1) RETURN -1 END
UPDATE [dbo].[Cliente_Instalacion] SET cin_jornada_inicio = @INICIO, cin_jornada_fin = @FIN WHERE cin_id = @PLANTA
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_RECURSOS_AJUSTES]
    @CLIENTE INT
AS
SET NOCOUNT ON
SELECT  c.tca_id AS ID, c.tca_nombre AS NOMBRE, ISNULL(c.tca_color, N'') AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[Tarea] t WHERE t.tar_tarea_categoria = c.tca_id AND t.tar_habilitado = 1) AS USOS
FROM    [dbo].[Tarea_Categoria] c
WHERE   (c.tca_cliente = @CLIENTE OR c.tca_cliente IS NULL) AND c.tca_habilitado = 1
ORDER BY ISNULL(c.tca_orden, 999), c.tca_nombre

SELECT  t.ott_id AS ID, t.ott_nombre AS NOMBRE, N'' AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_orden_trabajo_tipo = t.ott_id AND o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1)
      + (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
           JOIN [dbo].[Plan_Mantenimiento] pm ON pm.pma_id = v.pmv_plan_mantenimiento
          WHERE h.pmh_orden_trabajo_tipo = t.ott_id AND h.pmh_habilitado = 1 AND pm.pma_cliente = @CLIENTE AND v.pmv_plan_version_estado IN (1, 2)) AS USOS,
        CAST(CASE WHEN t.ott_id <= 3 THEN 1 ELSE 0 END AS BIT) AS SISTEMA
FROM    [dbo].[Orden_Trabajo_Tipo] t
WHERE   t.ott_habilitado = 1
ORDER BY ISNULL(t.ott_orden, 999), t.ott_nombre

SELECT  m.amd_id AS ID, m.amd_nombre AS NOMBRE, N'' AS COLOR,
        (SELECT COUNT(*) FROM [dbo].[VW_AVISOS] a WHERE a.CLIENTE = @CLIENTE AND a.ESTADO = 'DESCARTADO' AND a.MOTIVO = m.amd_nombre) AS USOS
FROM    [dbo].[Aviso_Motivo_Descarte] m
WHERE   m.amd_habilitado = 1
ORDER BY m.amd_orden, m.amd_nombre

/* 415 · 3 · jornada de trabajo de cada planta (vacía = 06:00–22:00) */
SELECT  cin.cin_id AS ID, cin.cin_nombre AS NOMBRE,
        LEFT(CONVERT(NVARCHAR(8), cin.cin_jornada_inicio, 108), 5) AS INICIO, LEFT(CONVERT(NVARCHAR(8), cin.cin_jornada_fin, 108), 5) AS FIN
FROM    [dbo].[Cliente_Instalacion] cin
WHERE   cin.cin_cliente = @CLIENTE AND cin.cin_habilitado = 1
ORDER BY cin.cin_nombre
GO

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
/* 415: la jornada de la planta del activo (sin dato, 06:00–22:00). */
DECLARE @J0 TIME = '06:00', @J1 TIME = '22:00'
SELECT @J0 = ISNULL(cin.cin_jornada_inicio, @J0), @J1 = ISNULL(cin.cin_jornada_fin, @J1)
FROM [dbo].[Activo] a JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = a.act_cliente_instalacion WHERE a.act_id = @ACT
/* CA-7: quienes la ejecutan tampoco pueden estar ocupados en la hora sugerida. */
DECLARE @K TABLE (clave VARCHAR(20) PRIMARY KEY)
INSERT @K SELECT DISTINCT CLAVE FROM [dbo].[VW_AGENDA_RECURSO] WHERE CLIENTE = @CLIENTE AND TIPO = @TIPO AND OCURRENCIA = @OCURRENCIA
DECLARE @REFX INT = (SELECT TOP 1 REF FROM [dbo].[VW_AGENDA_OBJETO] WHERE CLIENTE = @CLIENTE AND TIPO = @TIPO AND OCURRENCIA = @OCURRENCIA)
;WITH N AS (SELECT TOP 144 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k FROM sys.all_objects),
C AS (SELECT DATEADD(MINUTE, 30 * k, @INI) AS ini FROM N)
SELECT TOP 3 c.ini AS INICIO, DATEADD(MINUTE, @DUR, c.ini) AS FIN
FROM   C c
WHERE  c.ini > @AHORA
  AND  CAST(c.ini AS TIME) >= @J0 AND CAST(DATEADD(MINUTE, @DUR, c.ini) AS TIME) <= @J1 AND CAST(DATEADD(MINUTE, @DUR, c.ini) AS DATE) = CAST(c.ini AS DATE)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[VW_AGENDA_OBJETO] g
                   WHERE g.CLIENTE = @CLIENTE AND NOT (g.TIPO = @TIPO AND g.OCURRENCIA = @OCURRENCIA) AND g.RAIZ = @RAIZ
                     AND g.INICIO < DATEADD(MINUTE, @DUR, c.ini) AND c.ini < g.FIN
                     AND [dbo].[FNC_OBJETOS_SE_PISAN](@RAIZ, @ACT, @COMP, g.RAIZ, g.ACTIVO, g.COMPONENTE) = 1)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[VW_AGENDA_RECURSO] r JOIN @K k ON k.clave = r.CLAVE
                   WHERE r.CLIENTE = @CLIENTE AND NOT (r.TIPO = @TIPO AND r.REF = @REFX)
                     AND r.INICIO < DATEADD(MINUTE, @DUR, c.ini) AND c.ini < r.FIN)
ORDER BY c.ini
GO
PRINT '415_PLANTA_JORNADA aplicado.'
GO
