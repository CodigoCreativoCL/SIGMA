USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LECTURAS DE PRUEBA PARA EJERCITAR EL PREDICTOR.
-- =============================================
-- LO QUE ESTAS LECTURAS SON Y LO QUE NO SON
--
--   Son datos de prueba, inventados en este bloque para que el predictor tenga
--   sobre que correr. No vienen de la planta. Lo que **no** es inventado es lo
--   que sale de ellas: la pendiente, el R2, los dias restantes y el intervalo
--   los calcula el SP sobre estos numeros, y si manana entran las lecturas
--   reales el mismo SP dara los numeros reales sin tocar una linea.
--
--   Se registran como origen MANUAL porque asi es como van a entrar de verdad:
--   en SIGMA no hay sensores, las lecturas las toma una persona con el
--   telefono. Un dato de prueba marcado SENSOR estaria mintiendo sobre como
--   llego.
--
-- LOS NUEVE CASOS, INCLUIDOS LOS CUATRO SILENCIOS
--
--   ACT-34 Horno L1   temperatura sube parejo   -> prediccion con dias y riesgo
--   ACT-35 Revolv. 1  vibracion sube despacio   -> prediccion mas lejana
--   ACT-40 Horno L2   temperatura estable       -> NO predice: no sube
--   ACT-41 Horno L3   temperatura sin patron    -> NO predice: R2 bajo
--   ACT-33 Modelad. 1 solo dos lecturas         -> NO predice: faltan lecturas
--   ACT-38, 42, 43, 44 sin ninguna lectura      -> NO predice: nunca se midio
--
--   Los cuatro silencios importan tanto como las dos predicciones. La pantalla
--   de SIGMA AI tiene que poder decir **por que** esta callada sobre un equipo,
--   y si todos los casos de prueba produjeran prediccion nunca sabriamos si esa
--   parte funciona.
--
-- EL RUIDO ES DETERMINISTICO
--
--   Sale de una formula sobre el indice de la lectura, no de RAND(): el bloque
--   tiene que dar el mismo resultado cada vez que se corre, o «probado» no
--   significa nada.
-- =============================================

SET XACT_ABORT ON
GO

DECLARE @CLI INT = 1
DECLARE @USR INT = 11
DECLARE @HOY DATETIME = GETUTCDATE()

/* Se puede volver a correr. */
DELETE FROM [dbo].[Activo_Medicion] WHERE [amd_cliente] = @CLI

/* Los dias: 0 = hace 60 dias, 60 = hoy, cada 5. */
DECLARE @DIAS TABLE ([i] INT PRIMARY KEY, [d] INT)
INSERT INTO @DIAS ([i], [d])
SELECT [n], [n] * 5 FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) AS t([n])

DECLARE @SERIE TABLE
    ([activo]   NVARCHAR(20)
    ,[variable] NVARCHAR(30)
    ,[base]     DECIMAL(18,6)
    ,[pend]     DECIMAL(18,6)   -- por dia
    ,[ruido]    DECIMAL(18,6)   -- amplitud
    ,[desde_i]  INT)            -- desde que indice hay lecturas

INSERT INTO @SERIE VALUES
    --  Sube 0,30 °C por dia desde 62. Hoy va en ~80 y el limite es 90:
    --  quedan unos 33 dias.
     (N'ACT-34', N'TEMPERATURA', 62.0, 0.300, 0.6, 0)

    --  Sube 0,035 mm/s por dia desde 3,2. Hoy ~5,3 contra un limite de 7,1.
    ,(N'ACT-35', N'VIBRACION',    3.2, 0.035, 0.08, 0)

    --  Plano: el horno trabaja igual todos los dias. No hay nada que anunciar
    --  y el predictor tiene que callarse.
    ,(N'ACT-40', N'TEMPERATURA', 63.0, 0.000, 0.5, 0)

    --  Sin patron: sube y baja segun la carga del turno. Es el caso donde una
    --  regresion ingenua inventaria una tendencia; el R2 minimo lo impide.
    ,(N'ACT-41', N'TEMPERATURA', 66.0, 0.000, 6.0, 0)

    --  Solo las dos ultimas: alguien empezo a medir esta semana.
    ,(N'ACT-33', N'CORRIENTE',   24.0, 0.060, 0.3, 11)

INSERT INTO [dbo].[Activo_Medicion]
    ([amd_uuid], [amd_cliente], [amd_activo_variable], [amd_activo]
    ,[amd_fecha_medicion_utc], [amd_valor], [amd_unidad_medida]
    ,[amd_valor_canonico], [amd_unidad_canonica]
    ,[amd_medicion_calidad], [amd_dato_origen], [amd_entrada_modo]
    ,[amd_usuario_creacion], [amd_fecha_creacion])
SELECT
     NEWID(), @CLI, ava.[ava_id], act.[act_id]
    ,DATEADD(HOUR, (d.[d] - 60) * 24 + 9, @HOY)          -- a las 9 de la manana
    ,v.[valor], ava.[ava_unidad_medida]
    ,v.[valor], ava.[ava_unidad_medida]                  -- unidad base: canonico = valor
    ,1, 3, 1                                             -- 1 VALIDA, 3 MANUAL, tecleado
    ,@USR, GETDATE()
  FROM @SERIE                        s
  JOIN @DIAS                         d ON d.[i] >= s.[desde_i]
  JOIN [dbo].[Activo]              act ON act.[act_codigo] COLLATE DATABASE_DEFAULT = s.[activo]
  JOIN [dbo].[Variable_Medicion]   vme ON vme.[vme_codigo] COLLATE DATABASE_DEFAULT = s.[variable]
  JOIN [dbo].[Activo_Variable]     ava ON ava.[ava_activo] = act.[act_id]
                                      AND ava.[ava_variable_medicion] = vme.[vme_id]
  CROSS APPLY (SELECT [valor] = ROUND(
        s.[base] + s.[pend] * d.[d]
        /* Ruido reproducible: depende del indice, no de RAND(). */
        + s.[ruido] * (((d.[i] * 37) % 7) - 3), 2)) v

DECLARE @CUANTAS INT = @@ROWCOUNT
PRINT CONCAT('  lecturas creadas: ', @CUANTAS)
GO


-- ---------------------------------------------------------------------------
-- CORRER EL PREDICTOR
-- ---------------------------------------------------------------------------
DELETE FROM [dbo].[Alerta] WHERE [ale_alerta_tipo] = 4
DELETE FROM [dbo].[Prediccion_Explicacion]
DELETE FROM [dbo].[Prediccion_Caracteristica]
DELETE FROM [dbo].[Prediccion]
GO

PRINT ''
PRINT '== CORRIDA DEL MODELO =='
EXEC [dbo].[API_GEN_PREDICCION_TENDENCIA] @CLIENTE = 1, @USUARIO = 11
GO

PRINT ''
PRINT '== LO QUE SALIO =='
SELECT   act.[act_codigo], act.[act_nombre]
        ,pre.[pre_valor]         AS [HOY]
        ,pre.[pre_dia_restante]  AS [DIAS]
        ,pre.[pre_probabilidad]  AS [PROB]
        ,pre.[pre_confianza]     AS [R2]
        ,pre.[pre_intervalo_inferior] AS [DIAS_MIN]
        ,pre.[pre_intervalo_superior] AS [DIAS_MAX]
        ,sev.[sev_codigo]        AS [SEVERIDAD]
        ,CASE WHEN pre.[pre_alerta] IS NULL THEN N'no' ELSE N'si' END AS [ALERTA]
FROM     [dbo].[Prediccion]  pre
JOIN     [dbo].[Activo]      act ON act.[act_id] = pre.[pre_activo]
LEFT JOIN [dbo].[Severidad]  sev ON sev.[sev_id] = pre.[pre_severidad]
ORDER BY pre.[pre_dia_restante]

PRINT ''
PRINT '== LAS RAZONES =='
SELECT   act.[act_codigo], pex.[pex_orden], pex.[pex_texto]
FROM     [dbo].[Prediccion_Explicacion] pex
JOIN     [dbo].[Prediccion]  pre ON pre.[pre_id] = pex.[pex_prediccion]
JOIN     [dbo].[Activo]      act ON act.[act_id] = pre.[pre_activo]
ORDER BY act.[act_codigo], pex.[pex_orden]
GO
