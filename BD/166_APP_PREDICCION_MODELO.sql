USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     EL PRIMER MODELO DE SIGMA AI, Y LO QUE NO ES.
-- =============================================
-- ESTO NO ES APRENDIZAJE AUTOMATICO, Y EL SISTEMA LO DICE
--
--   `Modelo_Predictivo` estaba vacio: cero modelos, cero versiones, cero
--   predicciones. Y `Activo_Variable` y `Activo_Medicion` tambien, o sea que
--   no hay ni una lectura sobre la cual entrenar nada.
--
--   Habia dos caminos. Uno era inventar un «87 % de probabilidad de falla»
--   para que la tarjeta de SIGMA AI se viera llena. La especificacion lo
--   prohibe expresamente -«No mostrar porcentajes, causas ni recomendaciones
--   si el modelo no los entrega»- y con razon: un numero inventado en una
--   pantalla de mantenimiento termina justificando el desarme de un equipo que
--   estaba bien.
--
--   El otro es el que se toma aca: registrar un modelo **de linea base**, que
--   es lo que realmente existe hoy. Una extrapolacion lineal de una variable
--   medida hacia su umbral critico. No aprende, no tiene pesos, no se entrena.
--   Lo que si tiene es que **cada numero que muestra se puede rastrear hasta
--   las lecturas que lo produjeron**, y eso es mas de lo que ofrece la mayoria
--   de los modelos que si aprenden.
--
--   Cuando exista un modelo entrenado de verdad, entra como otra fila en
--   `Modelo_Predictivo` con su version, y las pantallas no cambian: ya estan
--   leyendo del modelo, no de una constante.
--
-- POR QUE UN FORMATO NUEVO
--
--   `Modelo_Formato` ofrece ONNX, Pickle, PMML y SavedModel: los cuatro son
--   artefactos binarios de un entrenamiento. Ninguno describe una regla escrita
--   en SQL. Se agrega REGLA en vez de etiquetar esto como ONNX, porque poner
--   «ONNX» en algo que no lo es haria que alguien busque un archivo que no
--   existe -y, peor, que confie en el numero mas de lo que corresponde-.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1 - EL FORMATO QUE FALTABA
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Formato] WHERE [mfo_codigo] = N'REGLA')
    INSERT INTO [dbo].[Modelo_Formato] ([mfo_codigo], [mfo_nombre], [mfo_orden], [mfo_habilitado])
    VALUES (N'REGLA', N'Regla determinista (sin entrenamiento)', 5, 1)
GO


-- ---------------------------------------------------------------------------
-- 2 - EL MODELO Y SU VERSION
-- ---------------------------------------------------------------------------
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'TENDENCIA VARIABLE')
BEGIN
    INSERT INTO [dbo].[Modelo_Predictivo]
        ([mpr_cliente], [mpr_modelo_objetivo], [mpr_codigo], [mpr_nombre]
        ,[mpr_descripcion], [mpr_horizonte_dia]
        ,[mpr_umbral_alerta], [mpr_umbral_critico]
        ,[mpr_usuario_creacion], [mpr_fecha_creacion], [mpr_habilitado])
    VALUES
        (NULL                                          -- sirve a todos los clientes
        ,2                                             -- 2 = VIDA UTIL RESTANTE
        ,N'TENDENCIA VARIABLE'
        ,N'Tendencia de variable medida'
        ,N'Ajusta una recta por minimos cuadrados sobre las ultimas lecturas de una variable y proyecta cuando alcanzara su valor critico. No aprende ni se entrena: cada resultado se puede rastrear hasta las lecturas que lo produjeron. Es la linea base con la que se compara cualquier modelo que venga despues.'
        ,90                                            -- mira hasta 90 dias adelante
        ,30                                            -- avisa a 30 dias del evento
        ,7                                             -- critico a 7 dias
        ,@ROOT, @AHORA, 1)

    DECLARE @MPR INT = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Modelo_Predictivo_Version]
        ([mpv_modelo_predictivo], [mpv_numero], [mpv_modelo_formato]
        ,[mpv_algoritmo], [mpv_hiperparametro]
        ,[mpv_plan_version_estado], [mpv_fecha_publicacion], [mpv_usuario_publicacion]
        ,[mpv_observacion]
        ,[mpv_usuario_creacion], [mpv_fecha_creacion], [mpv_habilitado])
    VALUES
        (@MPR, 1, (SELECT [mfo_id] FROM [dbo].[Modelo_Formato] WHERE [mfo_codigo] = N'REGLA')
        ,N'Regresion lineal por minimos cuadrados sobre (dias, valor)'
        ,N'{"lecturas_minimas":4,"ventana_dia":120,"r2_minimo":0.35}'
        ,2, @AHORA, @ROOT                              -- 2 = PUBLICADO
        /* Las metricas quedan en NULL a proposito: un AUC o un F1 salen de
           evaluar contra fallas ocurridas, y todavia no hay ninguna. Poner un
           0,9 de adorno seria decir que se valido algo que no se valido. */
        ,N'Linea base. Metricas vacias hasta que existan fallas registradas contra las cuales evaluar.'
        ,@ROOT, @AHORA, 1)

    /* Las caracteristicas: lo que el modelo mira. Son pocas porque el modelo
       es simple, y declararlas igual sirve -la ficha de la prediccion muestra
       que se uso para calcularla, y sin esto no habria nada que mostrar-. */
    INSERT INTO [dbo].[Caracteristica_Modelo]
        ([cmo_modelo_predictivo], [cmo_codigo], [cmo_etiqueta], [cmo_descripcion]
        ,[cmo_caracteristica_tipo], [cmo_ventana_dia], [cmo_agregacion]
        ,[cmo_orden], [cmo_obligatoria]
        ,[cmo_usuario_creacion], [cmo_fecha_creacion], [cmo_habilitado])
    VALUES
         (@MPR, N'VALOR_ACTUAL', N'Ultima lectura'
         ,N'El valor mas reciente de la variable.', 1, 120, N'ULTIMO', 1, 1, @ROOT, @AHORA, 1)
        ,(@MPR, N'PENDIENTE_DIA', N'Cuanto sube por dia'
         ,N'Pendiente de la recta ajustada, en unidades de la variable por dia.', 5, 120, N'REGRESION', 2, 1, @ROOT, @AHORA, 1)
        ,(@MPR, N'LECTURAS', N'Lecturas usadas'
         ,N'Cuantas lecturas entraron en el ajuste. Menos de cuatro no alcanzan para una tendencia.', 1, 120, N'CONTEO', 3, 1, @ROOT, @AHORA, 1)
        ,(@MPR, N'R2', N'Que tan recta es la subida'
         ,N'Coeficiente de determinacion del ajuste. Bajo 0,35 la variable se mueve sin patron y no se emite prediccion.', 1, 120, N'REGRESION', 4, 1, @ROOT, @AHORA, 1)
        ,(@MPR, N'UMBRAL_CRITICO', N'Valor critico de la variable'
         ,N'El umbral declarado en el equipo. Es contra este valor que se proyecta.', 1, NULL, N'CONFIGURACION', 5, 1, @ROOT, @AHORA, 1)

    PRINT '  Modelo de linea base registrado.'
END
ELSE
    PRINT '  el modelo ya estaba'
GO


-- ---------------------------------------------------------------------------
-- 3 - QUE SE VIGILA EN CADA EQUIPO
-- ---------------------------------------------------------------------------
--   `Activo_Variable` es lo que convierte a un equipo en «vigilado». Sin una
--   fila aca, un activo no tiene ni umbral ni variable que seguir, y la
--   pantalla de SIGMA AI tiene que decir exactamente eso -«no hay nada que
--   mirar todavia»- en vez de callarse.
--
--   Los umbrales son los de la ficha tecnica del fabricante para equipos de
--   este porte. No salen de una medicion: son lo que el equipo aguanta.
-- ---------------------------------------------------------------------------
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE(), @CLI INT = 1

DECLARE @VIGILAR TABLE
    ([activo]      NVARCHAR(20)
    ,[variable]    NVARCHAR(30)
    ,[advertencia] DECIMAL(18,4)
    ,[critico]     DECIMAL(18,4)
    ,[cada_hora]   INT)

INSERT INTO @VIGILAR VALUES
    -- Los hornos: la temperatura del descanso del ventilador de tiro.
     (N'ACT-34', N'TEMPERATURA',  75,  90, 24)
    ,(N'ACT-40', N'TEMPERATURA',  75,  90, 24)
    ,(N'ACT-41', N'TEMPERATURA',  75,  90, 24)
    ,(N'ACT-42', N'TEMPERATURA',  75,  90, 24)

    -- Las revolvedoras: vibracion en el reductor.
    ,(N'ACT-35', N'VIBRACION',   4.5, 7.1, 24)
    ,(N'ACT-43', N'VIBRACION',   4.5, 7.1, 24)
    ,(N'ACT-44', N'VIBRACION',   4.5, 7.1, 24)

    -- Las modeladoras: corriente del motor principal.
    ,(N'ACT-33', N'CORRIENTE',    28,  34, 24)
    ,(N'ACT-38', N'CORRIENTE',    28,  34, 24)

INSERT INTO [dbo].[Activo_Variable]
    ([ava_cliente], [ava_activo], [ava_variable_medicion], [ava_unidad_medida]
    ,[ava_valor_advertencia], [ava_valor_critico]
    ,[ava_frecuencia_esperada_hora]
    ,[ava_usuario_creacion], [ava_fecha_creacion], [ava_habilitado])
SELECT
     @CLI, act.[act_id], vme.[vme_id], vme.[vme_unidad_medida]
    ,v.[advertencia], v.[critico], v.[cada_hora]
    ,@ROOT, @AHORA, 1
  FROM @VIGILAR                       v
  JOIN [dbo].[Activo]            act ON act.[act_codigo] COLLATE DATABASE_DEFAULT = v.[activo]
  JOIN [dbo].[Variable_Medicion] vme ON vme.[vme_codigo] COLLATE DATABASE_DEFAULT = v.[variable]
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] av
                    WHERE av.[ava_activo] = act.[act_id]
                      AND av.[ava_variable_medicion] = vme.[vme_id])

PRINT '  Variables vigiladas configuradas.'
GO

SELECT   act.[act_codigo], act.[act_nombre], vme.[vme_nombre] AS [VARIABLE]
        ,ava.[ava_valor_advertencia], ava.[ava_valor_critico]
        ,ume.[ume_simbolo]
FROM     [dbo].[Activo_Variable]     ava
JOIN     [dbo].[Activo]              act ON act.[act_id] = ava.[ava_activo]
JOIN     [dbo].[Variable_Medicion]   vme ON vme.[vme_id] = ava.[ava_variable_medicion]
LEFT JOIN [dbo].[Unidad_Medida]      ume ON ume.[ume_id] = ava.[ava_unidad_medida]
ORDER BY act.[act_codigo]
GO
