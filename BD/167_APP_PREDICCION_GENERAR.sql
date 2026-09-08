USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     EL PREDICTOR DE LINEA BASE DE SIGMA AI.
-- =============================================
-- QUE HACE, EN UNA FRASE
--
--   Para cada variable vigilada de cada equipo, ajusta una recta sobre las
--   lecturas de los ultimos 120 dias y calcula cuando esa recta llegara al
--   valor critico declarado. Nada mas.
--
-- POR QUE CADA NUMERO QUE MUESTRA ES DEFENDIBLE
--
--   `pre_dia_restante` es la solucion de una ecuacion de primer grado sobre
--   datos reales. `pre_confianza` es el R2 del ajuste. El intervalo sale del
--   error estandar de la pendiente, no de un margen elegido a dedo. Y
--   `pre_probabilidad` es **la parte del intervalo de cruce que cae dentro del
--   horizonte**: si el equipo puede cruzar el umbral entre el dia 20 y el dia
--   200, y el horizonte son 90 dias, la probabilidad es la fraccion de esa
--   ventana que queda antes del dia 90.
--
--   Esa definicion importa. «Probabilidad de falla» suena a que el modelo sabe
--   algo sobre fallas, y no sabe nada: no ha visto ninguna. Lo que si puede
--   afirmar es cuando una variable medida va a cruzar un limite declarado, y
--   con cuanta incertidumbre. La pantalla dice exactamente eso.
--
-- CUANDO NO DICE NADA
--
--   Con menos de cuatro lecturas, con R2 bajo 0,35, con pendiente que no sube,
--   o con el cruce mas alla del horizonte: **no se emite prediccion**. Callar
--   es una respuesta valida y es la correcta cuando los datos no alcanzan. La
--   pantalla, en cambio, si tiene que decir por que esta callando -«faltan
--   lecturas», «se mueve sin patron»- y para eso esta el @TIPO 5 del SEL.
--
-- SE PUEDE VOLVER A CORRER
--
--   Una corrida por (activo, variable, dia) gracias al uuid deterministico. Un
--   proceso nocturno que se ejecute dos veces no deja dos predicciones del
--   mismo equipo el mismo dia, que es lo que despues hace que la curva
--   historica tenga escalones falsos.
-- =============================================


CREATE OR ALTER PROCEDURE [dbo].[API_GEN_PREDICCION_TENDENCIA]
     @CLIENTE      INT
    ,@USUARIO      INT
    ,@INSTALACION  INT = NULL
    ,@ACTIVO       INT = NULL
AS
SET NOCOUNT ON

BEGIN

    DECLARE @MPV INT, @HORIZONTE INT, @UMB_ALERTA DECIMAL(9,6), @UMB_CRITICO DECIMAL(9,6)

    SELECT TOP 1
           @MPV         = mpv.[mpv_id]
          ,@HORIZONTE   = mpr.[mpr_horizonte_dia]
          ,@UMB_ALERTA  = mpr.[mpr_umbral_alerta]
          ,@UMB_CRITICO = mpr.[mpr_umbral_critico]
      FROM [dbo].[Modelo_Predictivo]         mpr
      JOIN [dbo].[Modelo_Predictivo_Version] mpv
             ON  mpv.[mpv_modelo_predictivo]   = mpr.[mpr_id]
             AND mpv.[mpv_plan_version_estado] = 2        -- PUBLICADO
             AND mpv.[mpv_habilitado]          = 1
     WHERE mpr.[mpr_codigo]     = N'TENDENCIA VARIABLE'
       AND mpr.[mpr_habilitado] = 1
     ORDER BY mpv.[mpv_numero] DESC

    IF @MPV IS NULL
    BEGIN
        RAISERROR('No hay una version publicada del modelo de tendencia.', 16, 1)
        RETURN
    END

    DECLARE @VENTANA INT = 120, @MINIMO INT = 4, @R2_MINIMO DECIMAL(5,4) = 0.35
    DECLARE @HOY DATETIME = GETUTCDATE()

    /* ---------------------------------------------------------------------
       Las variables a evaluar. Se materializan primero para no recorrer la
       tabla viva mientras se le escriben predicciones.
       --------------------------------------------------------------------- */
    DECLARE @OBJETIVO TABLE
        ([ava_id]   INT PRIMARY KEY
        ,[activo]   INT
        ,[variable] INT
        ,[unidad]   INT
        ,[critico]  DECIMAL(18,6)
        ,[hecho]    BIT DEFAULT 0)

    INSERT INTO @OBJETIVO ([ava_id], [activo], [variable], [unidad], [critico])
    SELECT ava.[ava_id], ava.[ava_activo], ava.[ava_variable_medicion]
          ,ava.[ava_unidad_medida], ava.[ava_valor_critico]
      FROM [dbo].[Activo_Variable] ava
      JOIN [dbo].[Activo]          act ON act.[act_id] = ava.[ava_activo]
     WHERE ava.[ava_cliente]      = @CLIENTE
       AND ava.[ava_habilitado]   = 1
       AND ava.[ava_valor_critico] IS NOT NULL
       AND act.[act_habilitado]   = 1
       AND (@INSTALACION IS NULL OR act.[act_cliente_instalacion] = @INSTALACION)
       AND (@ACTIVO      IS NULL OR act.[act_id] = @ACTIVO)

    DECLARE @EMITIDAS INT = 0, @OMITIDAS INT = 0

    DECLARE @AVA INT, @ACT INT, @VAR INT, @UME INT, @CRIT DECIMAL(18,6)

    WHILE EXISTS (SELECT 1 FROM @OBJETIVO WHERE [hecho] = 0)
    BEGIN

        SELECT TOP 1 @AVA = [ava_id], @ACT = [activo], @VAR = [variable]
                    ,@UME = [unidad], @CRIT = [critico]
          FROM @OBJETIVO WHERE [hecho] = 0 ORDER BY [ava_id]

        UPDATE @OBJETIVO SET [hecho] = 1 WHERE [ava_id] = @AVA

        /* ---- Las lecturas de la ventana ---- */
        DECLARE @LECTURAS TABLE ([x] DECIMAL(18,6), [y] DECIMAL(18,6))
        DELETE FROM @LECTURAS

        DECLARE @DESDE DATETIME = DATEADD(DAY, -@VENTANA, @HOY)

        INSERT INTO @LECTURAS ([x], [y])
        SELECT DATEDIFF(HOUR, @DESDE, amd.[amd_fecha_medicion_utc]) / 24.0
              ,amd.[amd_valor_canonico]
          FROM [dbo].[Activo_Medicion] amd
         WHERE amd.[amd_cliente]          = @CLIENTE
           AND amd.[amd_activo]           = @ACT
           AND amd.[amd_activo_variable]  = @AVA
           AND amd.[amd_medicion_calidad] = 1              -- solo lecturas validas
           AND amd.[amd_fecha_medicion_utc] >= @DESDE

        DECLARE @N INT = (SELECT COUNT(*) FROM @LECTURAS)

        IF @N < @MINIMO
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- Minimos cuadrados ----
           Sxx y Sxy son las sumas centradas; con ellas salen la pendiente, el
           intercepto, el R2 y el error estandar sin recorrer los datos otra
           vez. */
        DECLARE @SX DECIMAL(28,10), @SY DECIMAL(28,10)
               ,@SXX DECIMAL(28,10), @SXY DECIMAL(28,10), @SYY DECIMAL(28,10)
               ,@MX DECIMAL(28,10), @MY DECIMAL(28,10)

        SELECT @SX = SUM([x]), @SY = SUM([y])
              ,@SXX = SUM([x] * [x]), @SXY = SUM([x] * [y]), @SYY = SUM([y] * [y])
          FROM @LECTURAS

        SET @MX = @SX / @N
        SET @MY = @SY / @N

        DECLARE @CXX DECIMAL(28,10) = @SXX - @N * @MX * @MX
        DECLARE @CXY DECIMAL(28,10) = @SXY - @N * @MX * @MY
        DECLARE @CYY DECIMAL(28,10) = @SYY - @N * @MY * @MY

        /* Todas las lecturas el mismo dia: no hay tendencia que ajustar. */
        IF @CXX IS NULL OR @CXX <= 0.000001
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        DECLARE @PENDIENTE DECIMAL(28,10) = @CXY / @CXX
        DECLARE @INTERCEPTO DECIMAL(28,10) = @MY - @PENDIENTE * @MX
        DECLARE @R2 DECIMAL(28,10) =
            CASE WHEN @CYY <= 0.000001 THEN 0
                 ELSE (@CXY * @CXY) / (@CXX * @CYY) END

        /* La variable no sube, o sube sin patron: no hay nada que anunciar. */
        IF @PENDIENTE <= 0 OR @R2 < @R2_MINIMO
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- Donde esta hoy y cuando cruza ---- */
        DECLARE @HOY_X DECIMAL(28,10) = DATEDIFF(HOUR, @DESDE, @HOY) / 24.0
        DECLARE @ACTUAL DECIMAL(28,10) =
            (SELECT TOP 1 [y] FROM @LECTURAS ORDER BY [x] DESC)

        /* Ya paso el limite: eso no es una prediccion, es un hecho, y lo tiene
           que levantar la alerta de medicion fuera de rango -que existe y es
           de otro tipo-. Anunciar como «va a pasar» algo que ya paso le quita
           urgencia a lo que ya es urgente. */
        IF @ACTUAL >= @CRIT
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        DECLARE @X_CRUCE DECIMAL(28,10) = (@CRIT - @INTERCEPTO) / @PENDIENTE
        DECLARE @DIAS DECIMAL(28,10) = @X_CRUCE - @HOY_X

        IF @DIAS <= 0 OR @DIAS > @HORIZONTE
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- El intervalo, del error estandar de la pendiente ----
           s^2 = residuos / (n-2); se_pendiente = s / raiz(Sxx). Con n = 4 el
           divisor es 2 y el intervalo sale ancho, que es exactamente lo que
           corresponde: cuatro puntos no permiten afirmar mucho. */
        DECLARE @SSE DECIMAL(28,10) = @CYY - @PENDIENTE * @CXY
        IF @SSE < 0 SET @SSE = 0

        DECLARE @S DECIMAL(28,10) =
            CASE WHEN @N > 2 THEN SQRT(@SSE / (@N - 2)) ELSE 0 END
        DECLARE @SE_PEND DECIMAL(28,10) = @S / SQRT(@CXX)

        DECLARE @P_ALTA DECIMAL(28,10) = @PENDIENTE + 1.96 * @SE_PEND
        DECLARE @P_BAJA DECIMAL(28,10) = @PENDIENTE - 1.96 * @SE_PEND

        --  Sube mas rapido -> cruza antes. Por eso el limite inferior de dias
        --  sale de la pendiente ALTA.
        DECLARE @DIAS_MIN DECIMAL(28,10) =
            CASE WHEN @P_ALTA > 0 THEN (@CRIT - @ACTUAL) / @P_ALTA ELSE @DIAS END

        --  Si la pendiente baja no es positiva, la recta podria no cruzar
        --  nunca: el limite superior se corta en el horizonte en vez de irse
        --  al infinito.
        DECLARE @DIAS_MAX DECIMAL(28,10) =
            CASE WHEN @P_BAJA > 0
                 THEN (@CRIT - @ACTUAL) / @P_BAJA
                 ELSE CAST(@HORIZONTE AS DECIMAL(28,10)) * 4 END

        IF @DIAS_MIN < 0 SET @DIAS_MIN = 0
        IF @DIAS_MAX < @DIAS_MIN SET @DIAS_MAX = @DIAS_MIN

        /* ---- La probabilidad: cuanto del intervalo cae dentro del horizonte ---- */
        DECLARE @PROB DECIMAL(9,6)

        IF @DIAS_MAX <= @DIAS_MIN
            SET @PROB = CASE WHEN @DIAS <= @HORIZONTE THEN 1 ELSE 0 END
        ELSE
            SET @PROB = CAST(
                CASE
                    WHEN @DIAS_MIN >= @HORIZONTE THEN 0
                    WHEN @DIAS_MAX <= @HORIZONTE THEN 1
                    ELSE (@HORIZONTE - @DIAS_MIN) / (@DIAS_MAX - @DIAS_MIN)
                END AS DECIMAL(9,6))

        IF @PROB < 0 SET @PROB = 0
        IF @PROB > 1 SET @PROB = 1

        /* ---- La severidad sale de los umbrales DECLARADOS en el modelo ----
           No de una escala escrita aca: si el criterio vive en dos lugares,
           algun dia discrepan sobre el mismo equipo. */
        DECLARE @SEV INT =
            CASE WHEN @PROB >= @UMB_CRITICO THEN 5      -- CRITICA
                 WHEN @PROB >= @UMB_ALERTA  THEN 4      -- ALTA
                 ELSE 3 END                             -- ADVERTENCIA

        /* ---- Una prediccion por (activo, variable, dia) ---- */
        DECLARE @UUID UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER,
            HASHBYTES('MD5', CONCAT(N'TEND|', @CLIENTE, N'|', @ACT, N'|', @AVA,
                                    N'|', CONVERT(NVARCHAR(10), @HOY, 112))))

        IF EXISTS (SELECT 1 FROM [dbo].[Prediccion] WHERE [pre_uuid] = @UUID)
            CONTINUE

        DECLARE @FECHA_EVENTO DATETIME = DATEADD(HOUR, CAST(@DIAS * 24 AS INT), @HOY)

        BEGIN TRY
            BEGIN TRANSACTION

            INSERT INTO [dbo].[Prediccion]
                ([pre_uuid], [pre_cliente], [pre_modelo_predictivo_version]
                ,[pre_prediccion_estado], [pre_activo]
                ,[pre_valor], [pre_probabilidad], [pre_dia_restante]
                ,[pre_fecha_evento_estimada_utc], [pre_severidad], [pre_confianza]
                ,[pre_intervalo_inferior], [pre_intervalo_superior]
                ,[pre_fecha_calculo_utc], [pre_fecha_vigencia_hasta_utc]
                ,[pre_usuario_creacion], [pre_fecha_creacion], [pre_habilitado])
            VALUES
                (@UUID, @CLIENTE, @MPV
                ,1, @ACT                                   -- 1 = GENERADA
                ,CAST(@ACTUAL AS DECIMAL(18,6)), @PROB, CAST(@DIAS AS INT)
                ,@FECHA_EVENTO, @SEV, CAST(@R2 AS DECIMAL(9,6))
                ,CAST(@DIAS_MIN AS DECIMAL(18,6)), CAST(@DIAS_MAX AS DECIMAL(18,6))
                /* Vigente hasta que se vuelva a calcular: una prediccion vieja
                   colgada en la pantalla es peor que ninguna. */
                ,@HOY, DATEADD(DAY, 7, @HOY)
                ,@USUARIO, GETDATE(), 1)

            DECLARE @PRE INT = SCOPE_IDENTITY()

            /* ---- Lo que se uso para calcularla ---- */
            INSERT INTO [dbo].[Prediccion_Caracteristica]
                ([pcr_prediccion], [pcr_caracteristica_modelo], [pcr_valor]
                ,[pcr_imputado], [pcr_usuario_creacion], [pcr_fecha_creacion])
            SELECT @PRE, cmo.[cmo_id]
                  ,CASE cmo.[cmo_codigo]
                       WHEN N'VALOR_ACTUAL'   THEN CAST(@ACTUAL AS DECIMAL(18,6))
                       WHEN N'PENDIENTE_DIA'  THEN CAST(@PENDIENTE AS DECIMAL(18,6))
                       WHEN N'LECTURAS'       THEN @N
                       WHEN N'R2'             THEN CAST(@R2 AS DECIMAL(18,6))
                       WHEN N'UMBRAL_CRITICO' THEN @CRIT
                   END
                  ,0, @USUARIO, GETDATE()
              FROM [dbo].[Caracteristica_Modelo] cmo
              JOIN [dbo].[Modelo_Predictivo_Version] mv ON mv.[mpv_id] = @MPV
             WHERE cmo.[cmo_modelo_predictivo] = mv.[mpv_modelo_predictivo]
               AND cmo.[cmo_habilitado] = 1

            /* ---- Las tres razones ----
               Son frases sobre datos reales, no plantillas de marketing. Cada
               una nombra el numero del que sale, porque una razon que no se
               puede verificar no ayuda a decidir si desarmar una maquina. */
            DECLARE @SIMBOLO NVARCHAR(20) =
                ISNULL((SELECT [ume_simbolo] FROM [dbo].[Unidad_Medida] WHERE [ume_id] = @UME), N'')

            INSERT INTO [dbo].[Prediccion_Explicacion]
                ([pex_prediccion], [pex_caracteristica_modelo], [pex_orden], [pex_texto]
                ,[pex_contribucion], [pex_direccion]
                ,[pex_valor_observado], [pex_valor_referencia]
                ,[pex_usuario_creacion], [pex_fecha_creacion])
            VALUES
                 (@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'PENDIENTE_DIA')
                 ,1
                 ,CONCAT(N'Viene subiendo ',
                         FORMAT(@PENDIENTE, N'0.###', N'es-CL'), N' ', @SIMBOLO,
                         N' por dia, sostenido en los ultimos ',
                         CAST(CAST(@HOY_X AS INT) AS NVARCHAR(10)), N' dias.')
                 ,NULL, N'AUMENTA'
                 ,CAST(@PENDIENTE AS DECIMAL(18,6)), NULL
                 ,@USUARIO, GETDATE())

                ,(@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'VALOR_ACTUAL')
                 ,2
                 ,CONCAT(N'Hoy marca ', FORMAT(@ACTUAL, N'0.#', N'es-CL'), N' ', @SIMBOLO,
                         N' y el limite del equipo es ',
                         FORMAT(@CRIT, N'0.#', N'es-CL'), N' ', @SIMBOLO, N'.')
                 ,NULL, N'AUMENTA'
                 ,CAST(@ACTUAL AS DECIMAL(18,6)), @CRIT
                 ,@USUARIO, GETDATE())

                ,(@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'R2')
                 ,3
                 ,CONCAT(N'La subida es pareja: ', CAST(@N AS NVARCHAR(10)),
                         N' lecturas se ajustan a una recta con R2 ',
                         FORMAT(@R2, N'0.00', N'es-CL'), N'.')
                 ,NULL, NULL
                 ,CAST(@R2 AS DECIMAL(18,6)), @R2_MINIMO
                 ,@USUARIO, GETDATE())

            /* ---- La alerta, solo si pasa el umbral declarado ----
               Bajo 0,60 la prediccion queda registrada pero no interrumpe a
               nadie: se ve en el panel de SIGMA AI y no genera alerta. Alertar
               por todo es la forma mas rapida de que dejen de mirar las
               alertas. */
            IF @PROB >= @UMB_ALERTA
            BEGIN
                DECLARE @NOMBRE NVARCHAR(200) =
                    (SELECT CONCAT([act_codigo], N' ', [act_nombre]) FROM [dbo].[Activo] WHERE [act_id] = @ACT)
                DECLARE @VNOMBRE NVARCHAR(200) =
                    (SELECT [vme_nombre] FROM [dbo].[Variable_Medicion] WHERE [vme_id] = @VAR)
                DECLARE @INST INT =
                    (SELECT [act_cliente_instalacion] FROM [dbo].[Activo] WHERE [act_id] = @ACT)

                INSERT INTO [dbo].[Alerta]
                    ([ale_uuid], [ale_cliente], [ale_cliente_instalacion]
                    ,[ale_alerta_tipo], [ale_alerta_estado], [ale_severidad]
                    ,[ale_titulo], [ale_descripcion], [ale_fecha_deteccion_utc]
                    ,[ale_activo], [ale_prediccion]
                    ,[ale_valor_observado], [ale_valor_umbral], [ale_unidad_medida]
                    ,[ale_fecha_primera_ocurrencia_utc], [ale_fecha_ultima_ocurrencia_utc]
                    ,[ale_ocurrencias]
                    ,[ale_usuario_creacion], [ale_fecha_creacion], [ale_habilitado])
                VALUES
                    (NEWID(), @CLIENTE, @INST
                    ,4, 1, @SEV                            -- 4 = PREDICCION RIESGO, 1 = NUEVA
                    ,CONCAT(@VNOMBRE, N' en alza en ', @NOMBRE)
                    ,CONCAT(N'La ', LOWER(@VNOMBRE), N' viene subiendo y, de seguir asi, alcanza el limite del equipo en unos ',
                            CAST(CAST(@DIAS AS INT) AS NVARCHAR(10)), N' dias.')
                    ,@HOY
                    ,@ACT, @PRE
                    ,CAST(@ACTUAL AS DECIMAL(18,6)), @CRIT, @UME
                    ,@HOY, @HOY, 1
                    ,@USUARIO, GETDATE(), 1)

                UPDATE [dbo].[Prediccion]
                   SET [pre_alerta] = SCOPE_IDENTITY()
                 WHERE [pre_id] = @PRE
            END

            COMMIT TRANSACTION
            SET @EMITIDAS = @EMITIDAS + 1
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
            RAISERROR(@MSG, 16, 1)
            RETURN
        END CATCH

    END

    SELECT @EMITIDAS AS [EMITIDAS], @OMITIDAS AS [OMITIDAS]

END
GO
