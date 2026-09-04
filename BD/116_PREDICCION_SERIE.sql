/* ============================================================================
   SIGMA — Bloque 116
   LA CURVA DE RIESGO DEL PANEL PREDICTIVO
   ----------------------------------------------------------------------------

   POR QUE HACE FALTA HISTORIA

     La maqueta dibuja bajo el anillo del 87% una curva de los ultimos siete
     dias. Esa curva no sale de la prediccion de hoy: sale de las
     predicciones ANTERIORES del mismo equipo.

     Un modelo real vuelve a puntuar cada dia y deja una fila por corrida. Sin
     esas filas la curva no se puede dibujar, y dibujarla igual seria inventar
     la unica parte del panel que cuenta una historia.

   SE SIEMBRAN LAS CORRIDAS QUE FALTAN, NO SE PINTA LA LINEA

     Seis predicciones mas, una por dia, con la probabilidad subiendo hasta el
     0.87 de hoy. Van con `pre_alerta` en NULL: la alerta la genero la corrida
     de hoy, que es cuando la probabilidad cruzo el umbral. Las anteriores son
     historial de puntuacion, no avisos.

   Y SE AGREGA LA CONSULTA

     `SEL_ALERTA_PREDICCION` gana un tercer resultado con la serie. Los dos
     primeros no cambian, asi que lo que ya lee el panel sigue igual.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. LAS CORRIDAS ANTERIORES
   ======================================================================== */
DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @PRED INT, @VER INT, @ACT INT, @EST INT, @SEV INT, @CALC DATETIME

SELECT TOP 1 @PRED = pre_id, @VER = pre_modelo_predictivo_version,
             @ACT = pre_activo, @EST = pre_prediccion_estado,
             @SEV = pre_severidad, @CALC = pre_fecha_calculo_utc
FROM [dbo].[Prediccion]
WHERE pre_cliente = @CLI AND pre_alerta IS NOT NULL
ORDER BY pre_id DESC

IF (@PRED IS NULL)
    PRINT '--- No hay prediccion de demo: ejecute antes el bloque 114.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Prediccion]
                 WHERE pre_activo = @ACT AND pre_alerta IS NULL)
    PRINT '--- La historia de la prediccion ya existia.'
ELSE
BEGIN
    /* La probabilidad sube dia a dia hasta el 0.87 de hoy: es la forma que
       tiene un deterioro real y la que hace que la alerta tenga sentido. */
    INSERT INTO [dbo].[Prediccion]
        (pre_cliente, pre_modelo_predictivo_version, pre_prediccion_estado,
         pre_activo, pre_probabilidad, pre_dia_restante, pre_severidad,
         pre_confianza, pre_fecha_calculo_utc, pre_usuario_creacion)
    SELECT  @CLI, @VER, @EST, @ACT, v.P, v.D, @SEV, 0.80,
            DATEADD(DAY, v.N, @CALC), @USU
    FROM (VALUES
            (-6, 0.31, 34),
            (-5, 0.38, 29),
            (-4, 0.44, 25),
            (-3, 0.55, 20),
            (-2, 0.66, 15),
            (-1, 0.78, 12)
         ) AS v(N, P, D)

    PRINT '--- 6 corridas anteriores creadas.'
END
GO


/* ========================================================================
   2. SEL_ALERTA_PREDICCION gana la serie

      Los dos primeros resultados quedan IDENTICOS: el panel ya los lee y
      cambiarlos obligaria a tocar el C# por un anadido.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA_PREDICCION') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_ALERTA_PREDICCION]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_PREDICCION]
    @ALERTA     INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

    /* ---- 1. la prediccion ---- */
    SELECT  p.pre_id,
            p.pre_probabilidad,
            p.pre_dia_restante,
            p.pre_confianza,
            p.pre_valor,
            p.pre_intervalo_inferior,
            p.pre_intervalo_superior,
            p.pre_fecha_calculo_utc,
            p.pre_fecha_evento_estimada_utc,
            ISNULL(mp.mpr_nombre, '')          AS MODELO_NOMBRE,
            ISNULL(CAST(mv.mpv_numero AS VARCHAR(10)), '') AS MODELO_VERSION,
            ISNULL(s.sev_codigo, '')           AS sev_codigo,
            ISNULL(ac.act_codigo, '')          AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')          AS ACTIVO_NOMBRE,
            /* La OT que ya salio de esta prediccion, si es que salio alguna.
               Es lo que decide si la pantalla ofrece generarla o muestra la
               que ya existe. */
            a.ale_orden_trabajo                AS ORDEN_TRABAJO,
            ot.otr_correlativo                 AS ORDEN_CORRELATIVO
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Prediccion] p ON p.pre_id = a.ale_prediccion
    LEFT JOIN [dbo].[Modelo_Predictivo_Version] mv ON mv.mpv_id = p.pre_modelo_predictivo_version
    LEFT JOIN [dbo].[Modelo_Predictivo] mp ON mp.mpr_id = mv.mpv_modelo_predictivo
    LEFT JOIN [dbo].[Severidad] s ON s.sev_id = p.pre_severidad
    LEFT JOIN [dbo].[Activo] ac ON ac.act_id = p.pre_activo
    LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = a.ale_orden_trabajo
    WHERE   a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE

    /* ---- 2. los factores ---- */
    SELECT  ex.pex_orden,
            ex.pex_texto,
            ex.pex_contribucion,
            ex.pex_direccion,
            ex.pex_valor_observado,
            ex.pex_valor_referencia
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Prediccion_Explicacion] ex ON ex.pex_prediccion = a.ale_prediccion
    WHERE   a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE
    ORDER BY ISNULL(ex.pex_orden, 999), ex.pex_id

    /* ---- 3. la curva: como venia la probabilidad de este equipo ----

       Son las corridas del MISMO activo, incluida la de hoy, ordenadas por
       fecha. Si el modelo solo ha puntuado una vez, la serie trae un punto y
       la pantalla no dibuja la curva: una linea de un solo punto no cuenta
       ninguna historia. */
    SELECT  FECHA = CAST(h.pre_fecha_calculo_utc AS DATE),
            PROBABILIDAD = h.pre_probabilidad,
            DIA_RESTANTE = h.pre_dia_restante
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Prediccion] p ON p.pre_id = a.ale_prediccion
    JOIN    [dbo].[Prediccion] h ON h.pre_activo = p.pre_activo
                                AND h.pre_cliente = p.pre_cliente
                                AND h.pre_fecha_calculo_utc <= p.pre_fecha_calculo_utc
    WHERE   a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE
      AND   h.pre_habilitado = 1
    ORDER BY h.pre_fecha_calculo_utc
GO

PRINT '--- SEL_ALERTA_PREDICCION ahora devuelve la serie.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
DECLARE @A INT
SELECT TOP 1 @A = ale_id FROM [dbo].[Alerta] WHERE ale_prediccion IS NOT NULL ORDER BY ale_id DESC
EXEC [dbo].[SEL_ALERTA_PREDICCION] @ALERTA = @A, @CLIENTE = 1
GO

PRINT '116_PREDICCION_SERIE aplicado.'
GO
