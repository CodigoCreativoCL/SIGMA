USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     GENERAR LAS OCURRENCIAS DE PLANES Y TAREAS (HU-076).
-- =============================================
-- POR QUE ESTA AQUI
--
--   HU-076 quedo «bloqueada» en el Sprint 3 porque no existian los hitos
--   (HU-081). Ya existen, y sin generador nada de lo construido produce
--   trabajo: el calendario (HU-085), la bandeja (HU-087), la orden desde la
--   ocurrencia (HU-111) y la tarea programada (HU-102) miran una tabla que
--   solo llenaba la semilla. El bloque 106 dejo el calculo dificil hecho
--   -FNC_PROGRAMACION_FECHAS-; esto es la otra mitad: QUE se crea.
--
-- QUE HACE
--
--   GEN_PLAN_OCURRENCIAS: por cada version PUBLICADA (la que manda), por
--   cada hito habilitado y cada equipo de esa version, pide las fechas de
--   la programacion del hito entre hoy y hoy + horizonte, y crea la
--   ocurrencia PENDIENTE que falte. Las fechas DESCARTADAS por exclusion no
--   se crean. Fecha disponible y limite salen de las tolerancias de la
--   programacion.
--
--   GEN_TAREA_OCURRENCIAS: lo mismo para Tarea_Programacion habilitadas de
--   tareas habilitadas.
--
--   MEDIDOR y CONDICION no generan por fecha (bloque 106): sus ocurrencias
--   nacen al registrar la lectura, no aqui.
--
-- IDEMPOTENTE Y SIN DUPLICAR
--
--   Se pregunta antes de insertar por (hito, activo, fecha) y por
--   (programacion, activo, fecha) -los dos indices unicos-; correr dos
--   veces no crea nada nuevo. Una programacion que ya genero hasta una
--   fecha queda anotada en Programacion_Generacion (hasta cuando, cuantas,
--   ultimo error) para que se sepa que paso sin leer la tabla grande.
--
-- SE DISPARA A MANO Y PODRA DISPARARSE SOLO
--
--   El boton del centro llama con el plan (o la tarea). Un job nocturno
--   llamara sin plan y con @SOLO_AUTOMATICAS = 1, que respeta
--   pro_genera_automaticamente. Es el mismo SP: no hay dos generadores.
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) GEN_PLAN_OCURRENCIAS
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[GEN_PLAN_OCURRENCIAS]
@CLIENTE          INT,
@PLAN             INT = NULL,
@HORIZONTE_DIA    INT = 90,
@SOLO_AUTOMATICAS BIT = 0,
@USUARIO          INT,
@GENERADAS        INT = NULL OUTPUT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@HORIZONTE_DIA IS NULL OR @HORIZONTE_DIA < 1) SET @HORIZONTE_DIA = 90
IF (@HORIZONTE_DIA > 730) SET @HORIZONTE_DIA = 730

DECLARE @DESDE DATE = CAST(GETUTCDATE() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, @HORIZONTE_DIA, @DESDE)

IF @PLAN IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @PLAN IS NOT NULL AND [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN) IS NULL
BEGIN
    RAISERROR('2.- EL PLAN NO TIENE UNA VERSIÓN PUBLICADA: PUBLIQUE EL BORRADOR ANTES DE GENERAR.', 16, 1)
    RETURN -1
END

-- Lo que toca: hito x equipo x fecha, solo de versiones publicadas
DECLARE @NUEVAS TABLE (hito INT, programacion INT, activo INT, componente INT, fecha DATETIME, antes INT, despues INT, plan_codigo NVARCHAR(100), hito_codigo NVARCHAR(100), activo_codigo NVARCHAR(100))

INSERT INTO @NUEVAS (hito, programacion, activo, componente, fecha, antes, despues, plan_codigo, hito_codigo, activo_codigo)
SELECT  h.pmh_id, h.pmh_programacion, a.pac_activo, a.pac_activo_componente, f.FECHA,
        ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0),
        pma.pma_codigo, h.pmh_codigo, act.act_codigo
FROM    [dbo].[Plan_Mantenimiento]         pma
JOIN    [dbo].[Plan_Mantenimiento_Version] v   ON v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1
JOIN    [dbo].[Programacion]               p   ON p.pro_id = h.pmh_programacion AND p.pro_habilitado = 1
JOIN    [dbo].[Plan_Mantenimiento_Activo]  a   ON a.pac_plan_mantenimiento_version = v.pmv_id
JOIN    [dbo].[Activo]                     act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @DESDE, @HASTA) f
WHERE   pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)
  AND   (@SOLO_AUTOMATICAS = 0 OR p.pro_genera_automaticamente = 1)
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    WHERE o.pmo_plan_mantenimiento_hito = h.pmh_id AND o.pmo_activo = a.pac_activo AND o.pmo_fecha_programada_utc = f.FECHA)
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    WHERE o.pmo_programacion = h.pmh_programacion AND o.pmo_activo = a.pac_activo AND o.pmo_fecha_programada_utc = f.FECHA)

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
        (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
         pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc,
         pmo_plan_ocurrencia_estado, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
    SELECT  NEWID(), @CLIENTE, hito, programacion, activo, componente,
            fecha, DATEADD(MINUTE, despues, fecha), DATEADD(MINUTE, -antes, fecha),
            1, @USUARIO, @DATE_NOW, 1
    FROM    @NUEVAS

    SET @GENERADAS = @@ROWCOUNT

    -- El rastro por programacion: hasta cuando se genero y cuantas
    MERGE [dbo].[Programacion_Generacion] AS g
    USING (SELECT programacion, COUNT(*) n FROM @NUEVAS GROUP BY programacion) AS s
       ON g.pge_programacion = s.programacion
    WHEN MATCHED THEN UPDATE SET
         pge_horizonte_dia = @HORIZONTE_DIA, pge_fecha_generada_hasta_utc = @HASTA, pge_ultima_ejecucion_utc = GETUTCDATE(),
         pge_ocurrencias_generadas = g.pge_ocurrencias_generadas + s.n, pge_ultimo_error = NULL,
         pge_usuario_actualizacion = @USUARIO, pge_fecha_actualizacion = @DATE_NOW
    WHEN NOT MATCHED THEN INSERT
         (pge_programacion, pge_horizonte_dia, pge_fecha_generada_hasta_utc, pge_ultima_ejecucion_utc, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
         VALUES (s.programacion, @HORIZONTE_DIA, @HASTA, GETUTCDATE(), s.n, @USUARIO, @DATE_NOW);

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GEN_PLAN_OCURRENCIAS', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE GENERAR LAS OCURRENCIAS: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

-- Resumen para la pantalla: que se genero, por plan e hito
SELECT plan_codigo AS PLAN_CODIGO, hito_codigo AS HITO_CODIGO, COUNT(DISTINCT activo) AS EQUIPOS, COUNT(*) AS GENERADAS,
       MIN(fecha) AS PRIMERA, MAX(fecha) AS ULTIMA
FROM   @NUEVAS
GROUP BY plan_codigo, hito_codigo
ORDER BY plan_codigo, hito_codigo

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 2) GEN_TAREA_OCURRENCIAS
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[GEN_TAREA_OCURRENCIAS]
@CLIENTE          INT,
@TAREA            INT = NULL,
@HORIZONTE_DIA    INT = 90,
@SOLO_AUTOMATICAS BIT = 0,
@USUARIO          INT,
@GENERADAS        INT = NULL OUTPUT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@HORIZONTE_DIA IS NULL OR @HORIZONTE_DIA < 1) SET @HORIZONTE_DIA = 90
IF (@HORIZONTE_DIA > 730) SET @HORIZONTE_DIA = 730

DECLARE @DESDE DATE = CAST(GETUTCDATE() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, @HORIZONTE_DIA, @DESDE)

IF @TAREA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_id = @TAREA AND tar_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA TAREA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @NUEVAS TABLE (tarea INT, tprog INT, programacion INT, fecha DATETIME, antes INT, despues INT, tarea_codigo NVARCHAR(100), programacion_nombre NVARCHAR(400))

INSERT INTO @NUEVAS
SELECT  t.tar_id, tp.tpr_id, tp.tpr_programacion, f.FECHA,
        ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0), t.tar_codigo, p.pro_nombre
FROM    [dbo].[Tarea]              t
JOIN    [dbo].[Tarea_Programacion] tp ON tp.tpr_tarea = t.tar_id AND tp.tpr_habilitado = 1
JOIN    [dbo].[Programacion]       p  ON p.pro_id = tp.tpr_programacion AND p.pro_habilitado = 1
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](tp.tpr_programacion, @DESDE, @HASTA) f
WHERE   t.tar_cliente = @CLIENTE AND t.tar_habilitado = 1
  AND   (@TAREA IS NULL OR t.tar_id = @TAREA)
  AND   (@SOLO_AUTOMATICAS = 0 OR p.pro_genera_automaticamente = 1)
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia] o
                    WHERE o.toc_tarea = t.tar_id AND o.toc_tarea_programacion = tp.tpr_id AND o.toc_fecha_programada_utc = f.FECHA)

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Tarea_Ocurrencia]
        (toc_uuid, toc_cliente, toc_tarea, toc_tarea_programacion, toc_tarea_ocurrencia_estado,
         toc_fecha_programada_utc, toc_fecha_disponible_utc, toc_fecha_limite_utc,
         toc_usuario_creacion, toc_fecha_creacion, toc_habilitado)
    SELECT  NEWID(), @CLIENTE, tarea, tprog, 1,
            fecha, DATEADD(MINUTE, -antes, fecha), DATEADD(MINUTE, despues, fecha),
            @USUARIO, @DATE_NOW, 1
    FROM    @NUEVAS

    SET @GENERADAS = @@ROWCOUNT

    MERGE [dbo].[Programacion_Generacion] AS g
    USING (SELECT programacion, COUNT(*) n FROM @NUEVAS GROUP BY programacion) AS s
       ON g.pge_programacion = s.programacion
    WHEN MATCHED THEN UPDATE SET
         pge_horizonte_dia = @HORIZONTE_DIA, pge_fecha_generada_hasta_utc = @HASTA, pge_ultima_ejecucion_utc = GETUTCDATE(),
         pge_ocurrencias_generadas = g.pge_ocurrencias_generadas + s.n, pge_ultimo_error = NULL,
         pge_usuario_actualizacion = @USUARIO, pge_fecha_actualizacion = @DATE_NOW
    WHEN NOT MATCHED THEN INSERT
         (pge_programacion, pge_horizonte_dia, pge_fecha_generada_hasta_utc, pge_ultima_ejecucion_utc, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
         VALUES (s.programacion, @HORIZONTE_DIA, @HASTA, GETUTCDATE(), s.n, @USUARIO, @DATE_NOW);

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GEN_TAREA_OCURRENCIAS', @MSG = @MSG
    RAISERROR('2.- NO FUE POSIBLE GENERAR LAS OCURRENCIAS: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT tarea_codigo AS TAREA_CODIGO, programacion_nombre AS PROGRAMACION_NOMBRE, COUNT(*) AS GENERADAS, MIN(fecha) AS PRIMERA, MAX(fecha) AS ULTIMA
FROM   @NUEVAS
GROUP BY tarea_codigo, programacion_nombre
ORDER BY tarea_codigo

RETURN 0
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN ('GEN_PLAN_OCURRENCIAS','GEN_TAREA_OCURRENCIAS')) AS VARCHAR) + ' de 2' AS RESULTADO
GO
