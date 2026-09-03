/* ============================================================================
   SIGMA — Bloque 115
   LA SERIE DIARIA DE LOS CINCO INDICADORES
   ----------------------------------------------------------------------------

   LA CURVA NO SON "ALERTAS DETECTADAS POR DIA"

     La version anterior devolvia cuantas alertas NACIERON cada dia. Eso no es
     lo que dice la tarjeta: la tarjeta dice "activas", que es un estado, no
     un evento. Un dia sin detecciones nuevas pero con veinte alertas abiertas
     arrastradas tiene veinte activas, y la curva de detecciones lo dibujaba
     como cero.

   SE RECONSTRUYE EL ESTADO DE CADA DIA

     Una alerta estuvo ACTIVA el dia D si se detecto en D o antes, y todavia
     no se habia cerrado al terminar D. Las dos fechas ya existen:
     `ale_fecha_deteccion_utc` y `ale_fecha_atencion_utc`, que es el cierre.

     Con la misma idea salen criticas y predicciones. Y con las columnas del
     bloque 110 salen tambien en gestion —desde `ale_fecha_gestion_utc`— y sin
     responsable, mirando cuando `Alerta_Historial` registro la primera
     asignacion.

   LO QUE NO SE PUEDE RECONSTRUIR, NO SE INVENTA

     Las alertas anteriores al bloque 110 no tienen fecha de gestion: para
     ellas ese dato no existe y no se cuenta. Es preferible una curva que
     empieza donde empezo el registro a una curva completa que se invento la
     mitad.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_ALERTA_TENDENCIA') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_ALERTA_TENDENCIA]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_TENDENCIA]
    @CLIENTE    INT,
    @USUARIO    INT,
    @DIAS       INT = 7
AS
SET NOCOUNT ON

IF (@DIAS IS NULL OR @DIAS < 2) SET @DIAS = 7
IF (@DIAS > 60) SET @DIAS = 60

DECLARE @HOY DATE = CAST(GETUTCDATE() AS DATE)

DECLARE @DIA TABLE (D DATE PRIMARY KEY)

;WITH N AS (SELECT TOP (@DIAS) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects)
INSERT INTO @DIA (D)
SELECT DATEADD(DAY, -n, @HOY) FROM N

/* Las alertas que esta persona puede ver, con sus tres fechas: cuando nacio,
   cuando entro en gestion y cuando se cerro. */
DECLARE @A TABLE (
    ID          INT,
    DETECCION   DATE,
    CIERRE      DATE,
    GESTION     DATE,
    ASIGNACION  DATE,
    ES_CRITICA  BIT,
    ES_PRED     BIT)

INSERT INTO @A
SELECT  a.ale_id,
        CAST(a.ale_fecha_deteccion_utc AS DATE),
        CAST(a.ale_fecha_atencion_utc AS DATE),
        CAST(a.ale_fecha_gestion_utc AS DATE),
        /* Cuando se le puso responsable por primera vez. */
        (SELECT CAST(MIN(h.ahi_fecha_utc) AS DATE)
           FROM [dbo].[Alerta_Historial] h
          WHERE h.ahi_alerta = a.ale_id AND h.ahi_usuario_responsable IS NOT NULL),
        CASE WHEN s.sev_codigo = 'CRITICA' THEN 1 ELSE 0 END,
        CASE WHEN t.alt_codigo = 'PREDICCION RIESGO' AND a.ale_prediccion IS NOT NULL
             THEN 1 ELSE 0 END
FROM    [dbo].[Alerta] a
JOIN    [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
LEFT JOIN [dbo].[Permiso] pm  ON pm.prm_id = t.alt_permiso
LEFT JOIN [dbo].[Severidad] s ON s.sev_id = a.ale_severidad
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   (t.alt_permiso IS NULL
         OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)

    /* ---- 1. la serie: el ESTADO de cada dia ---- */
    SELECT  FECHA           = d.D,
            ACTIVAS         = (SELECT COUNT(*) FROM @A a
                                WHERE a.DETECCION <= d.D
                                  AND (a.CIERRE IS NULL OR a.CIERRE > d.D)),
            CRITICAS        = (SELECT COUNT(*) FROM @A a
                                WHERE a.ES_CRITICA = 1 AND a.DETECCION <= d.D
                                  AND (a.CIERRE IS NULL OR a.CIERRE > d.D)),
            EN_GESTION      = (SELECT COUNT(*) FROM @A a
                                WHERE a.GESTION IS NOT NULL AND a.GESTION <= d.D
                                  AND (a.CIERRE IS NULL OR a.CIERRE > d.D)),
            SIN_RESPONSABLE = (SELECT COUNT(*) FROM @A a
                                WHERE a.DETECCION <= d.D
                                  AND (a.CIERRE IS NULL OR a.CIERRE > d.D)
                                  AND (a.ASIGNACION IS NULL OR a.ASIGNACION > d.D)),
            PREDICCIONES    = (SELECT COUNT(*) FROM @A a
                                WHERE a.ES_PRED = 1 AND a.DETECCION <= d.D
                                  AND (a.CIERRE IS NULL OR a.CIERRE > d.D))
    FROM    @DIA d
    ORDER BY d.D

    /* ---- 2. hoy contra ayer, indicador por indicador ---- */
    DECLARE @AYER DATE = DATEADD(DAY, -1, @HOY)

    ;WITH E AS (
        SELECT  D = x.D,
                ACTIVAS = (SELECT COUNT(*) FROM @A a WHERE a.DETECCION <= x.D AND (a.CIERRE IS NULL OR a.CIERRE > x.D)),
                CRITICAS = (SELECT COUNT(*) FROM @A a WHERE a.ES_CRITICA = 1 AND a.DETECCION <= x.D AND (a.CIERRE IS NULL OR a.CIERRE > x.D)),
                EN_GESTION = (SELECT COUNT(*) FROM @A a WHERE a.GESTION IS NOT NULL AND a.GESTION <= x.D AND (a.CIERRE IS NULL OR a.CIERRE > x.D)),
                SIN_RESPONSABLE = (SELECT COUNT(*) FROM @A a WHERE a.DETECCION <= x.D AND (a.CIERRE IS NULL OR a.CIERRE > x.D) AND (a.ASIGNACION IS NULL OR a.ASIGNACION > x.D)),
                PREDICCIONES = (SELECT COUNT(*) FROM @A a WHERE a.ES_PRED = 1 AND a.DETECCION <= x.D AND (a.CIERRE IS NULL OR a.CIERRE > x.D))
        FROM (SELECT @HOY AS D UNION ALL SELECT @AYER) x
    )
    SELECT
        /* NULL cuando ayer fue cero: pasar de 0 a 3 no es "un aumento del
           300%", es que antes no habia nada. La tarjeta esconde la
           comparacion en vez de escribir un numero sin sentido. */
        VAR_ACTIVAS         = CASE WHEN h.ACTIVAS IS NOT NULL AND y.ACTIVAS > 0
                                   THEN CAST(ROUND((h.ACTIVAS - y.ACTIVAS) * 100.0 / y.ACTIVAS, 0) AS INT) END,
        VAR_CRITICAS        = CASE WHEN y.CRITICAS > 0
                                   THEN CAST(ROUND((h.CRITICAS - y.CRITICAS) * 100.0 / y.CRITICAS, 0) AS INT) END,
        VAR_EN_GESTION      = CASE WHEN y.EN_GESTION > 0
                                   THEN CAST(ROUND((h.EN_GESTION - y.EN_GESTION) * 100.0 / y.EN_GESTION, 0) AS INT) END,
        VAR_SIN_RESPONSABLE = CASE WHEN y.SIN_RESPONSABLE > 0
                                   THEN CAST(ROUND((h.SIN_RESPONSABLE - y.SIN_RESPONSABLE) * 100.0 / y.SIN_RESPONSABLE, 0) AS INT) END,
        VAR_PREDICCIONES    = CASE WHEN y.PREDICCIONES > 0
                                   THEN CAST(ROUND((h.PREDICCIONES - y.PREDICCIONES) * 100.0 / y.PREDICCIONES, 0) AS INT) END
    FROM  (SELECT * FROM E WHERE D = @HOY) h
    CROSS JOIN (SELECT * FROM E WHERE D = @AYER) y
GO

PRINT '--- SEL_ALERTA_TENDENCIA reescrito (estado por dia, no detecciones).'
GO

EXEC [dbo].[SEL_ALERTA_TENDENCIA] @CLIENTE = 1, @USUARIO = 1
GO

PRINT '115_ALERTA_SERIE_KPI aplicado.'
GO
