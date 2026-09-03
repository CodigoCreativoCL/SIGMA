/* ============================================================================
   SIGMA — Bloque 113
   TENDENCIA Y SERIE DE LOS INDICADORES
   ----------------------------------------------------------------------------

   La maqueta del Centro de Accion Operacional muestra bajo cada indicador un
   "12% vs ayer" y una linea de tendencia.

   ESO SE PUEDE CALCULAR DE VERDAD, ASI QUE NO SE INVENTA

     `Alerta.ale_fecha_deteccion_utc` ya guarda cuando aparecio cada hallazgo.
     Con eso salen las dos cosas: cuantas se detectaron cada uno de los
     ultimos siete dias -la linea- y la comparacion de hoy contra ayer -el
     porcentaje-.

     No hace falta una tabla de historico ni un proceso nocturno: la serie es
     una agrupacion por dia sobre lo que ya existe.

   SE AGREGA UN TERCER RESULTADO, NO SE CAMBIAN LOS DOS PRIMEROS

     `AlertaController.GetResumen` lee el primero -los contadores- y el
     segundo -el desglose por menu-. Un tercero al final no le afecta: si un
     consumidor viejo no lo lee, simplemente lo ignora.

   EL PORCENTAJE CUANDO AYER FUE CERO

     Pasar de 0 a 3 no es "un aumento del 300%": es que antes no habia nada.
     En ese caso se devuelve NULL y la pantalla no dibuja la comparacion, en
     vez de mostrar un numero que no significa nada.
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

/* Los dias del periodo, incluidos los que no tuvieron ninguna alerta: una
   linea que se salta los dias vacios miente sobre la forma de la curva. */
DECLARE @DIA TABLE (D DATE PRIMARY KEY)

;WITH N AS (SELECT TOP (@DIAS) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects)
INSERT INTO @DIA (D)
SELECT DATEADD(DAY, -n, @HOY) FROM N

/* Solo lo que esta persona puede ver, con la misma regla de permiso que el
   resto del modulo. Un indicador que cuenta alertas que el usuario no puede
   abrir es un numero que no le sirve. */
DECLARE @V TABLE (F DATE, SEV NVARCHAR(50))

INSERT INTO @V
SELECT  CAST(a.ale_fecha_deteccion_utc AS DATE),
        ISNULL(s.sev_codigo, 'NORMAL')
FROM    [dbo].[Alerta] a
JOIN    [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
LEFT JOIN [dbo].[Permiso] pm  ON pm.prm_id = t.alt_permiso
LEFT JOIN [dbo].[Severidad] s ON s.sev_id = a.ale_severidad
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   a.ale_fecha_deteccion_utc >= DATEADD(DAY, -@DIAS, @HOY)
  AND   (t.alt_permiso IS NULL
         OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)

    /* ---- 1. la serie, del mas antiguo al mas reciente ---- */
    SELECT  FECHA = d.D,
            TOTAL = (SELECT COUNT(*) FROM @V v WHERE v.F = d.D),
            CRITICAS = (SELECT COUNT(*) FROM @V v WHERE v.F = d.D AND v.SEV = 'CRITICA')
    FROM    @DIA d
    ORDER BY d.D

    /* ---- 2. hoy contra ayer ---- */
    DECLARE @HOY_N INT, @AYER_N INT, @HOY_C INT, @AYER_C INT

    SELECT @HOY_N  = COUNT(*) FROM @V WHERE F = @HOY
    SELECT @AYER_N = COUNT(*) FROM @V WHERE F = DATEADD(DAY, -1, @HOY)
    SELECT @HOY_C  = COUNT(*) FROM @V WHERE F = @HOY AND SEV = 'CRITICA'
    SELECT @AYER_C = COUNT(*) FROM @V WHERE F = DATEADD(DAY, -1, @HOY) AND SEV = 'CRITICA'

    SELECT  HOY = @HOY_N,
            AYER = @AYER_N,
            /* NULL cuando ayer fue cero: pasar de 0 a 3 no es un aumento del
               300%, es que antes no habia nada. La pantalla esconde la
               comparacion en vez de escribir un numero sin sentido. */
            VARIACION = CASE WHEN @AYER_N > 0
                             THEN CAST(ROUND((@HOY_N - @AYER_N) * 100.0 / @AYER_N, 0) AS INT)
                        END,
            HOY_CRITICAS = @HOY_C,
            AYER_CRITICAS = @AYER_C,
            VARIACION_CRITICAS = CASE WHEN @AYER_C > 0
                                      THEN CAST(ROUND((@HOY_C - @AYER_C) * 100.0 / @AYER_C, 0) AS INT)
                                 END
GO

PRINT '--- SEL_ALERTA_TENDENCIA creado.'
GO

EXEC [dbo].[SEL_ALERTA_TENDENCIA] @CLIENTE = 1, @USUARIO = 1
GO

PRINT '113_ALERTA_TENDENCIA aplicado.'
GO
