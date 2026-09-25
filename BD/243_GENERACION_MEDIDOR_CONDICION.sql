/* ============================================================================
   SIGMA — Bloque 243
   GENERACION POR MEDIDOR Y POR CONDICION                        HU-073 · HU-074
   ----------------------------------------------------------------------------

   GEN_PLAN_OCURRENCIAS (bloque 141) proyecta por FECHA. Las programaciones
   por medidor y por condicion no tienen fecha: se disparan cuando el dato
   llega. Por eso la generacion vive en los SP de captura:

     API_INS_ACTIVO_MEDIDOR_LECTURA -> GEN_PLAN_OCURRENCIAS_MEDIDOR
     API_INS_ACTIVO_MEDICION        -> GEN_PLAN_OCURRENCIAS_CONDICION

   Los dos generadores corren DESPUES del commit y con su propio TRY: lo
   que se capturo en terreno nunca se pierde por un error del plan.

   HU-073  #1 el horometro alcanza el proximo valor -> ocurrencia con ese
              valor objetivo (pmo_valor_medidor_objetivo).
           #2 entra en la anticipacion -> alerta MEDIDOR PROXIMO
              MANTENIMIENTO, sin orden; se cierra sola al generar.
           #3 el medidor es el de cada equipo del plan (FNC_PLAN_MEDIDOR_
              ESTADO), asi que un plan sobre cuatro blowers dispara cuatro
              veces, cada uno con su propio horometro.
   HU-074  #1 la ultima medicion cumple el umbral -> ocurrencia.
           #2 con duracion minima, cuenta solo si la racha de mediciones
              que cumplen lleva esos minutos: una aislada no dispara.
           #3 politica TODOS: todas las condiciones a la vez; UNO/MINIMO:
              cualquiera.

   GEN_ALERTA_OPERACION (bloque 238) pasa a leer la misma funcion para la
   alerta de aviso, asi el detector periodico y el disparo en linea dicen
   lo mismo.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
   1. FNC_PLAN_MEDIDOR_ESTADO                                        HU-073
      Una fila por hito x equipo de las programaciones POR MEDIDOR de los
      planes publicados: que medidor manda en ese equipo, en cuanto va y a
      que valor dispara la proxima ocurrencia.

      EL MEDIDOR ES DEL EQUIPO (#3): si la programacion no nombra uno
      (pme_activo_medidor NULL), lo aporta el plan (pac_activo_medidor) o,
      si tampoco, el primer horometro habilitado del activo. Asi un plan
      sobre cuatro blowers dispara con el horometro de cada uno.

      EL PROXIMO SE CUENTA DESDE LA ULTIMA OCURRENCIA GENERADA para ese hito
      y ese equipo (su valor objetivo); si no hay ninguna, desde el valor
      inicial de la programacion.
   ======================================================================== */
CREATE OR ALTER FUNCTION [dbo].[FNC_PLAN_MEDIDOR_ESTADO] (@CLIENTE INT)
RETURNS TABLE
AS
RETURN
(
    SELECT  h.pmh_id                AS HITO,
            h.pmh_nombre            AS HITO_NOMBRE,
            h.pmh_programacion      AS PROGRAMACION,
            p.pro_nombre            AS PROGRAMACION_NOMBRE,
            a.pac_activo            AS ACTIVO,
            a.pac_activo_componente AS COMPONENTE,
            med.ame_id              AS MEDIDOR,
            med.ame_nombre          AS MEDIDOR_NOMBRE,
            med.ame_valor_actual    AS VALOR_ACTUAL,
            med.ame_unidad_medida   AS UNIDAD,
            pm.pme_valor_inicial    AS VALOR_INICIAL,
            pm.pme_cada_cantidad    AS CADA,
            ISNULL(pm.pme_aviso_anticipacion, 0) AS AVISO,
            ult.OBJETIVO            AS ULTIMO_OBJETIVO,
            ISNULL(ult.OBJETIVO, pm.pme_valor_inicial) + pm.pme_cada_cantidad AS PROXIMO,
            ISNULL(p.pro_tolerancia_antes_minuto, 0)   AS TOL_ANTES,
            ISNULL(p.pro_tolerancia_despues_minuto, 0) AS TOL_DESPUES
    FROM    [dbo].[Plan_Mantenimiento]         pma
    JOIN    [dbo].[Plan_Mantenimiento_Version] v   ON v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1
    JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1
    JOIN    [dbo].[Programacion]               p   ON p.pro_id = h.pmh_programacion AND p.pro_habilitado = 1
    JOIN    [dbo].[Programacion_Tipo]          pt  ON pt.pti_id = p.pro_programacion_tipo AND pt.pti_codigo = 'MEDIDOR'
    JOIN    [dbo].[Programacion_Medidor]       pm  ON pm.pme_programacion = p.pro_id AND pm.pme_habilitado = 1
    JOIN    [dbo].[Plan_Mantenimiento_Activo]  a   ON a.pac_plan_mantenimiento_version = v.pmv_id
    JOIN    [dbo].[Activo]                     act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
    OUTER APPLY (SELECT TOP 1 m.ame_id, m.ame_nombre, m.ame_valor_actual, m.ame_unidad_medida
                   FROM [dbo].[Activo_Medidor] m
                  WHERE m.ame_habilitado = 1
                    AND m.ame_id = COALESCE(pm.pme_activo_medidor, a.pac_activo_medidor, m.ame_id)
                    AND m.ame_activo = a.pac_activo
                  ORDER BY CASE WHEN m.ame_id = pm.pme_activo_medidor THEN 0 WHEN m.ame_id = a.pac_activo_medidor THEN 1 ELSE 2 END, m.ame_id) med
    OUTER APPLY (SELECT MAX(o.pmo_valor_medidor_objetivo) AS OBJETIVO
                   FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                  WHERE o.pmo_plan_mantenimiento_hito = h.pmh_id AND o.pmo_activo = a.pac_activo AND o.pmo_habilitado = 1) ult
    WHERE   pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1
      AND   pm.pme_cada_cantidad > 0
      AND   med.ame_id IS NOT NULL
      /* Si la programacion nombra un medidor concreto, solo aplica al equipo
         de ese medidor. */
      AND   (pm.pme_activo_medidor IS NULL OR med.ame_id = pm.pme_activo_medidor)
)
GO

PRINT '--- FNC_PLAN_MEDIDOR_ESTADO creada.'
GO


/* ========================================================================
   2. GEN_PLAN_OCURRENCIAS_MEDIDOR                          HU-073 #1 y #2
      Se llama al registrar una lectura. Genera la ocurrencia cuando el
      horometro alcanzo el proximo valor de disparo, y abre la alerta de
      aviso cuando entro en la anticipacion (sin generar orden).
   ======================================================================== */
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  17-09-2026
-- DESCRIPTION:     GENERA LAS OCURRENCIAS POR MEDIDOR DE UN HOROMETRO Y LA
--                  ALERTA DE AVISO ANTICIPADO
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GEN_PLAN_OCURRENCIAS_MEDIDOR]
    @CLIENTE        INT,
    @ACTIVO_MEDIDOR INT,
    @USUARIO        INT,
    @GENERADAS      INT = NULL OUTPUT
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @HOY   DATETIME = [dbo].[FNC_AHORA]()
DECLARE @T_PROXIMO INT, @NUEVA INT, @RESUELTA INT, @DESCARTADA INT, @SEV_ADV INT, @SEV_ALTA INT
SELECT @T_PROXIMO = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDIDOR PROXIMO MANTENIMIENTO'
SELECT @NUEVA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'
SELECT @RESUELTA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA'
SELECT @DESCARTADA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'
SELECT @SEV_ADV = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ADVERTENCIA'
SELECT @SEV_ALTA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'
SET @GENERADAS = 0

DECLARE @HITO INT, @PROG INT, @ACTIVO INT, @COMP INT, @VALOR DECIMAL(18,4), @CADA DECIMAL(18,4), @AVISO DECIMAL(18,4)
DECLARE @PROXIMO DECIMAL(18,4), @ANTES INT, @DESPUES INT, @HITO_NOMBRE NVARCHAR(200), @MED_NOMBRE NVARCHAR(200)
DECLARE @VUELTAS INT, @ACT_COD NVARCHAR(100), @ACT_NOM NVARCHAR(200), @UNI INT, @SIMB NVARCHAR(20)

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT HITO, PROGRAMACION, ACTIVO, COMPONENTE, VALOR_ACTUAL, CADA, AVISO, PROXIMO, TOL_ANTES, TOL_DESPUES, HITO_NOMBRE, MEDIDOR_NOMBRE, UNIDAD
      FROM [dbo].[FNC_PLAN_MEDIDOR_ESTADO](@CLIENTE)
     WHERE MEDIDOR = @ACTIVO_MEDIDOR AND VALOR_ACTUAL IS NOT NULL
OPEN cur
FETCH NEXT FROM cur INTO @HITO, @PROG, @ACTIVO, @COMP, @VALOR, @CADA, @AVISO, @PROXIMO, @ANTES, @DESPUES, @HITO_NOMBRE, @MED_NOMBRE, @UNI
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @ACT_COD = act_codigo, @ACT_NOM = act_nombre FROM [dbo].[Activo] WHERE act_id = @ACTIVO
    SELECT @SIMB = ISNULL(ume_simbolo, '') FROM [dbo].[Unidad_Medida] WHERE ume_id = @UNI

    /* #1: cada vez que el horometro alcanza el proximo valor, una
       ocurrencia con ese valor objetivo. Tope de cinco por lectura: si el
       contador saltó lejos, el resto sale con las lecturas siguientes. */
    SET @VUELTAS = 0
    WHILE (@VALOR >= @PROXIMO AND @VUELTAS < 5)
    BEGIN
        INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
            (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
             pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc, pmo_valor_medidor_objetivo,
             pmo_plan_ocurrencia_estado, pmo_observacion, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
        VALUES
            (NEWID(), @CLIENTE, @HITO, @PROG, @ACTIVO, @COMP,
             @AHORA, DATEADD(MINUTE, @DESPUES, @AHORA), DATEADD(MINUTE, -@ANTES, @AHORA), @PROXIMO,
             1, N'Disparada por ' + @MED_NOMBRE + N': ' + LTRIM(STR(@VALOR, 18, 1)) + N' ' + @SIMB + N' (objetivo ' + LTRIM(STR(@PROXIMO, 18, 1)) + N').',
             @USUARIO, @HOY, 1)
        SET @GENERADAS = @GENERADAS + 1
        SET @PROXIMO = @PROXIMO + @CADA
        SET @VUELTAS = @VUELTAS + 1
    END

    /* #2: dentro de la anticipacion -> alerta, sin orden. Una sola alerta
       viva por medidor. Se cierra sola cuando la ocurrencia se genera. */
    IF (@AVISO > 0 AND @VALOR >= @PROXIMO - @AVISO AND @VALOR < @PROXIMO)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] a
                        WHERE a.ale_cliente = @CLIENTE AND a.ale_alerta_tipo = @T_PROXIMO AND a.ale_habilitado = 1
                          AND a.ale_activo_medidor = @ACTIVO_MEDIDOR AND a.ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA))
            INSERT INTO [dbo].[Alerta]
                (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
                 ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo, ale_activo_medidor,
                 ale_valor_observado, ale_valor_umbral, ale_unidad_medida, ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
            SELECT NEWID(), @CLIENTE, act_cliente_instalacion, @T_PROXIMO, @NUEVA, @SEV_ADV,
                   N'Se acerca el mantenimiento por ' + @MED_NOMBRE + N' en ' + @ACT_COD,
                   N'Va en ' + LTRIM(STR(@VALOR, 18, 1)) + N' ' + @SIMB + N' y el hito «' + @HITO_NOMBRE + N'» dispara a los ' + LTRIM(STR(@PROXIMO, 18, 1)) + N' ' + @SIMB + N'. Solo aviso: la orden nace con la ocurrencia.',
                   @AHORA, act_id, @ACTIVO_MEDIDOR, @VALOR, @PROXIMO, @UNI, @USUARIO, @HOY, 1
              FROM [dbo].[Activo] WHERE act_id = @ACTIVO
    END
    ELSE
        /* Fuera de la anticipacion (porque se genero la ocurrencia o porque
           aun falta): la alerta de aviso ya no corresponde. */
        UPDATE [dbo].[Alerta]
           SET ale_alerta_estado = @RESUELTA, ale_fecha_atencion_utc = @AHORA, ale_usuario_atencion = ISNULL(ale_usuario_atencion, @USUARIO),
               ale_motivo_resolucion = ISNULL(ale_motivo_resolucion, N'La ocurrencia se generó o el medidor salió de la anticipación.'),
               ale_usuario_actualizacion = @USUARIO, ale_fecha_actualizacion = @HOY
         WHERE ale_cliente = @CLIENTE AND ale_alerta_tipo = @T_PROXIMO AND ale_habilitado = 1
           AND ale_activo_medidor = @ACTIVO_MEDIDOR AND ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA)

    FETCH NEXT FROM cur INTO @HITO, @PROG, @ACTIVO, @COMP, @VALOR, @CADA, @AVISO, @PROXIMO, @ANTES, @DESPUES, @HITO_NOMBRE, @MED_NOMBRE, @UNI
END
CLOSE cur
DEALLOCATE cur

IF (@GENERADAS > 0)
    UPDATE [dbo].[Programacion_Generacion]
       SET pge_ultimo_valor_medidor = @VALOR, pge_ultima_ejecucion_utc = @AHORA,
           pge_ocurrencias_generadas = pge_ocurrencias_generadas + @GENERADAS,
           pge_usuario_actualizacion = @USUARIO, pge_fecha_actualizacion = @HOY
     WHERE pge_programacion = @PROG
RETURN 0
GO

PRINT '--- GEN_PLAN_OCURRENCIAS_MEDIDOR creado.'
GO


/* ========================================================================
   3. GEN_PLAN_OCURRENCIAS_CONDICION                        HU-074 #1 #2 #3
      Se llama al registrar una medicion. Evalua las condiciones de cada
      programacion POR CONDICION que mire esa variable y, segun la politica
      (TODOS = todas a la vez; UNO/MINIMO = cualquiera), genera la
      ocurrencia del hito para el equipo de la variable.

      DURACION MINIMA (#2): la condicion cuenta solo si se ha sostenido: la
      ultima medicion la cumple Y la racha de mediciones que la cumplen
      (desde la ultima que no) lleva al menos esos minutos. Una medicion
      aislada tiene racha de cero minutos.
   ======================================================================== */
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  17-09-2026
-- DESCRIPTION:     GENERA LAS OCURRENCIAS POR CONDICION AL REGISTRAR UNA
--                  MEDICION DE UNA VARIABLE
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GEN_PLAN_OCURRENCIAS_CONDICION]
    @CLIENTE         INT,
    @ACTIVO_VARIABLE INT,
    @USUARIO         INT,
    @GENERADAS       INT = NULL OUTPUT
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @HOY   DATETIME = [dbo].[FNC_AHORA]()
SET @GENERADAS = 0

DECLARE @ACTIVO INT
SELECT @ACTIVO = ava_activo FROM [dbo].[Activo_Variable] WHERE ava_id = @ACTIVO_VARIABLE AND ava_cliente = @CLIENTE
IF (@ACTIVO IS NULL) RETURN 0

/* Las programaciones por condicion que miran esta variable, con su hito de
   un plan publicado que incluye al equipo. */
DECLARE @PROGS TABLE (HITO INT, PROG INT, POLITICA NVARCHAR(20), HITO_NOMBRE NVARCHAR(200), TOL_ANTES INT, TOL_DESPUES INT, COMP INT)
INSERT INTO @PROGS
SELECT DISTINCT h.pmh_id, p.pro_id, cp.cpo_codigo, h.pmh_nombre,
       ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0), a.pac_activo_componente
  FROM [dbo].[Programacion_Condicion] c
  JOIN [dbo].[Programacion] p ON p.pro_id = c.pco_programacion AND p.pro_habilitado = 1
  JOIN [dbo].[Programacion_Tipo] pt ON pt.pti_id = p.pro_programacion_tipo AND pt.pti_codigo = 'CONDICION'
  LEFT JOIN [dbo].[Cumplimiento_Politica] cp ON cp.cpo_id = p.pro_cumplimiento_politica
  JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_programacion = p.pro_id AND h.pmh_habilitado = 1
  JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1
  JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento AND pma.pma_cliente = @CLIENTE AND pma.pma_habilitado = 1
  JOIN [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = v.pmv_id AND a.pac_activo = @ACTIVO
 WHERE c.pco_activo_variable = @ACTIVO_VARIABLE AND c.pco_habilitado = 1

IF NOT EXISTS (SELECT 1 FROM @PROGS) RETURN 0

/* ---- Evaluar cada condicion de esas programaciones (solo las del equipo) ---- */
DECLARE @EVAL TABLE (PROG INT, PCO INT, CUMPLE BIT, TEXTO NVARCHAR(300))

DECLARE @PCO INT, @PROG INT, @AVA INT, @OPER NVARCHAR(30), @UMBRAL DECIMAL(18,4), @HASTA DECIMAL(18,4), @DUR INT
DECLARE @VAR_NOMBRE NVARCHAR(200), @FACTOR DECIMAL(18,6), @OFFSET DECIMAL(18,6), @SIMB NVARCHAR(20)
DECLARE @ULT DECIMAL(18,4), @ULT_FECHA DATETIME, @INICIO_RACHA DATETIME, @CUMPLE BIT

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT c.pco_id, c.pco_programacion, c.pco_activo_variable, op.opc_codigo, c.pco_umbral, c.pco_umbral_hasta,
           ISNULL(c.pco_duracion_minima_minuto, 0), vm.vme_nombre, ISNULL(u.ume_factor, 1), ISNULL(u.ume_offset, 0), ISNULL(u.ume_simbolo, '')
      FROM [dbo].[Programacion_Condicion] c
      JOIN @PROGS pr ON pr.PROG = c.pco_programacion
      JOIN [dbo].[Activo_Variable] av ON av.ava_id = c.pco_activo_variable AND av.ava_activo = @ACTIVO
      JOIN [dbo].[Variable_Medicion] vm ON vm.vme_id = av.ava_variable_medicion
      JOIN [dbo].[Operador_Comparacion] op ON op.opc_id = c.pco_operador_comparacion
      LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = av.ava_unidad_medida
     WHERE c.pco_habilitado = 1
OPEN cur
FETCH NEXT FROM cur INTO @PCO, @PROG, @AVA, @OPER, @UMBRAL, @HASTA, @DUR, @VAR_NOMBRE, @FACTOR, @OFFSET, @SIMB
WHILE @@FETCH_STATUS = 0
BEGIN
    /* Las mediciones en la unidad de la variable, mas reciente primero. */
    DECLARE @M TABLE (N INT IDENTITY(1,1), FECHA DATETIME, VALOR DECIMAL(18,4), CUMPLE BIT)
    DELETE FROM @M
    INSERT INTO @M (FECHA, VALOR, CUMPLE)
    SELECT TOP 500 m.amd_fecha_medicion_utc,
           CASE WHEN m.amd_valor_canonico IS NOT NULL AND @FACTOR <> 0 THEN (m.amd_valor_canonico - @OFFSET) / @FACTOR ELSE m.amd_valor END,
           0
      FROM [dbo].[Activo_Medicion] m
     WHERE m.amd_activo_variable = @AVA
     ORDER BY m.amd_fecha_medicion_utc DESC, m.amd_id DESC

    UPDATE @M SET CUMPLE = CASE
        WHEN @OPER = 'MAYOR'       AND VALOR >  @UMBRAL THEN 1
        WHEN @OPER = 'MAYOR IGUAL' AND VALOR >= @UMBRAL THEN 1
        WHEN @OPER = 'MENOR'       AND VALOR <  @UMBRAL THEN 1
        WHEN @OPER = 'MENOR IGUAL' AND VALOR <= @UMBRAL THEN 1
        WHEN @OPER = 'IGUAL'       AND VALOR =  @UMBRAL THEN 1
        WHEN @OPER = 'DISTINTO'    AND VALOR <> @UMBRAL THEN 1
        WHEN @OPER = 'ENTRE'       AND VALOR BETWEEN @UMBRAL AND ISNULL(@HASTA, @UMBRAL) THEN 1
        ELSE 0 END

    SELECT @ULT = NULL, @ULT_FECHA = NULL, @INICIO_RACHA = NULL, @CUMPLE = 0
    SELECT TOP 1 @ULT = VALOR, @ULT_FECHA = FECHA, @CUMPLE = CUMPLE FROM @M ORDER BY N

    IF (@CUMPLE = 1 AND @DUR > 0)
    BEGIN
        /* La racha: desde la medicion siguiente a la ultima que NO cumple. */
        SELECT @INICIO_RACHA = MIN(FECHA) FROM @M
         WHERE N < ISNULL((SELECT MIN(N) FROM @M WHERE CUMPLE = 0), 999999)
        IF (@INICIO_RACHA IS NULL OR DATEDIFF(MINUTE, @INICIO_RACHA, @ULT_FECHA) < @DUR)
            SET @CUMPLE = 0
    END

    INSERT INTO @EVAL (PROG, PCO, CUMPLE, TEXTO)
    VALUES (@PROG, @PCO, @CUMPLE,
            @VAR_NOMBRE + N' ' + LOWER(@OPER) + N' ' + LTRIM(STR(@UMBRAL, 18, 1)) + N' ' + @SIMB
            + N' (última ' + ISNULL(LTRIM(STR(@ULT, 18, 1)), N'sin medición') + N' ' + @SIMB
            + CASE WHEN @DUR > 0 THEN N', sostenida ' + CAST(@DUR AS NVARCHAR(10)) + N' min' ELSE N'' END + N')')

    FETCH NEXT FROM cur INTO @PCO, @PROG, @AVA, @OPER, @UMBRAL, @HASTA, @DUR, @VAR_NOMBRE, @FACTOR, @OFFSET, @SIMB
END
CLOSE cur
DEALLOCATE cur

/* ---- Politica y generacion ---- */
DECLARE @HITO INT, @POL NVARCHAR(20), @HITO_NOMBRE NVARCHAR(200), @ANTES INT, @DESPUES INT, @COMP INT, @OK BIT, @DETALLE NVARCHAR(1000)
DECLARE cur2 CURSOR LOCAL FAST_FORWARD FOR SELECT HITO, PROG, POLITICA, HITO_NOMBRE, TOL_ANTES, TOL_DESPUES, COMP FROM @PROGS
OPEN cur2
FETCH NEXT FROM cur2 INTO @HITO, @PROG, @POL, @HITO_NOMBRE, @ANTES, @DESPUES, @COMP
WHILE @@FETCH_STATUS = 0
BEGIN
    IF (@POL = 'TODOS')
        SET @OK = CASE WHEN EXISTS (SELECT 1 FROM @EVAL WHERE PROG = @PROG) AND NOT EXISTS (SELECT 1 FROM @EVAL WHERE PROG = @PROG AND CUMPLE = 0) THEN 1 ELSE 0 END
    ELSE
        SET @OK = CASE WHEN EXISTS (SELECT 1 FROM @EVAL WHERE PROG = @PROG AND CUMPLE = 1) THEN 1 ELSE 0 END

    /* Una ocurrencia viva por hito y equipo: mientras no se ejecute, la
       misma condicion no abre otra. */
    IF (@OK = 1 AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                                 WHERE o.pmo_plan_mantenimiento_hito = @HITO AND o.pmo_activo = @ACTIVO AND o.pmo_habilitado = 1
                                   AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)))
    BEGIN
        SELECT @DETALLE = STRING_AGG(TEXTO, N' · ') FROM @EVAL WHERE PROG = @PROG
        INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
            (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
             pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc,
             pmo_plan_ocurrencia_estado, pmo_observacion, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
        VALUES
            (NEWID(), @CLIENTE, @HITO, @PROG, @ACTIVO, @COMP,
             @AHORA, DATEADD(MINUTE, @DESPUES, @AHORA), DATEADD(MINUTE, -@ANTES, @AHORA),
             1, LEFT(N'Disparada por condición (' + ISNULL(@POL, N'UNO') + N'): ' + ISNULL(@DETALLE, N''), 1000), @USUARIO, @HOY, 1)
        SET @GENERADAS = @GENERADAS + 1
    END
    FETCH NEXT FROM cur2 INTO @HITO, @PROG, @POL, @HITO_NOMBRE, @ANTES, @DESPUES, @COMP
END
CLOSE cur2
DEALLOCATE cur2
RETURN 0
GO

PRINT '--- GEN_PLAN_OCURRENCIAS_CONDICION creado.'
GO


/* ---- 4. Los SP de captura disparan los generadores ---- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ACTIVO_MEDIDOR_LECTURA]
     @ID                 INT OUTPUT
    ,@CLIENTE            INT
    ,@ACTIVO_MEDIDOR     INT
    ,@VALOR_ACUMULADO    DECIMAL(18,4)
    ,@FECHA_LECTURA_UTC  DATETIME       = NULL
    ,@ES_REINICIO        BIT            = 0
    ,@ORDEN_TRABAJO      INT            = NULL
    ,@OBSERVACION        NVARCHAR(1000) = NULL
    ,@ENTRADA_MODO       INT            = NULL
    ,@UUID               UNIQUEIDENTIFIER = NULL
    ,@USUARIO            INT
AS
SET NOCOUNT ON

DECLARE  @AHORA           DATETIME = GETUTCDATE()
        ,@VALOR_ACTUAL    DECIMAL(18,4)
        ,@PERMITE_REINICIO BIT
        ,@MSG             NVARCHAR(500)
        /* HU-043 #2: el maximo que el medidor puede avanzar por dia. Un salto
           mayor no se rechaza -la lectura es real- pero queda PENDIENTE DE
           REVISION y avisa. */
        ,@MAXIMO_DIARIO   DECIMAL(18,4)
        ,@FECHA_ACTUAL    DATETIME
        ,@ACTIVO          INT
        ,@CALIDAD         INT = 1
        ,@SALTO           DECIMAL(18,4)
        ,@DIAS            DECIMAL(18,4)
        ,@MENSAJE         NVARCHAR(500) = 'Lectura registrada.'

/* ---- Idempotencia ---- */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODA lectura con uuid responderia "ya
       estaba registrada" y no se guardaria nada. */
    SET @ID = NULL

    SELECT @ID = aml_id FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'La lectura ya estaba registrada.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

/* La fecha de captura la manda la app. Si no viene, es de ahora: pero eso
   solo pasa si la registro estando en linea. */
SET @FECHA_LECTURA_UTC = ISNULL(@FECHA_LECTURA_UTC, @AHORA)

/* ---- El medidor tiene que ser del cliente ---- */
SELECT   @VALOR_ACTUAL     = AME.ame_valor_actual
        ,@PERMITE_REINICIO = AME.ame_permite_reinicio
        ,@MAXIMO_DIARIO    = AME.ame_maximo_diario
        ,@FECHA_ACTUAL     = AME.ame_fecha_valor_actual_utc
        ,@ACTIVO           = AME.ame_activo
FROM     [dbo].[Activo_Medidor] AME
WHERE    AME.ame_id         = @ACTIVO_MEDIDOR
AND      AME.ame_cliente    = @CLIENTE
AND      AME.ame_habilitado = 1

IF (@VALOR_ACTUAL IS NULL AND NOT EXISTS (
        SELECT 1 FROM [dbo].[Activo_Medidor]
         WHERE ame_id = @ACTIVO_MEDIDOR AND ame_cliente = @CLIENTE AND ame_habilitado = 1))
BEGIN
    RAISERROR('1.- EL MEDIDOR NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* ---- El valor ---- */
IF (@VALOR_ACUMULADO IS NULL OR @VALOR_ACUMULADO < 0)
BEGIN
    RAISERROR('2.- LA LECTURA DEBE SER UN VALOR POSITIVO.', 16, 1)
    RETURN -1
END

/* Un horometro no retrocede. Si el valor es menor que el ultimo, o el
   medidor se reinicio —y hay que declararlo— o alguien tecleo mal.
   Rechazarlo en silencio perderia la lectura; aceptarlo sin marcar
   descuadraria el acumulado y todas las proyecciones de mantenimiento que
   dependen de el. */
IF (@ES_REINICIO = 0 AND @VALOR_ACTUAL IS NOT NULL AND @VALOR_ACUMULADO < @VALOR_ACTUAL)
BEGIN
    SET @MSG = '3.- LA LECTURA (' + LTRIM(STR(@VALOR_ACUMULADO, 18, 2)) +
               ') ES MENOR QUE LA ULTIMA REGISTRADA (' +
               LTRIM(STR(@VALOR_ACTUAL, 18, 2)) +
               '). SI EL MEDIDOR SE REINICIO, MARCALO COMO REINICIO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

IF (@ES_REINICIO = 1 AND ISNULL(@PERMITE_REINICIO, 0) = 0)
BEGIN
    RAISERROR('4.- ESTE MEDIDOR NO ADMITE REINICIO.', 16, 1)
    RETURN -1
END

/* Una lectura del futuro es un reloj mal puesto. Se tolera una hora de
   desfase: el telefono puede ir corrido unos minutos y eso no es un error. */
IF (@FECHA_LECTURA_UTC > DATEADD(HOUR, 1, @AHORA))
BEGIN
    RAISERROR('5.- LA FECHA DE LA LECTURA ESTA EN EL FUTURO. REVISA LA HORA DEL DISPOSITIVO.', 16, 1)
    RETURN -1
END

/* ---- Salto no razonable (HU-043 #2) ----
   Con un maximo diario definido, un avance mayor que maximo x dias desde la
   ultima lectura no se rechaza: la persona esta frente al medidor y lo que
   lee es real. Se guarda, queda PENDIENTE DE REVISION (Medicion_Calidad 5)
   y se abre una alerta LECTURA A REVISAR para el informe. Un dia como
   minimo: dos lecturas el mismo dia se comparan contra un dia entero. */
IF (@ES_REINICIO = 0 AND @MAXIMO_DIARIO IS NOT NULL AND @MAXIMO_DIARIO > 0
    AND @VALOR_ACTUAL IS NOT NULL)
BEGIN
    SET @SALTO = @VALOR_ACUMULADO - @VALOR_ACTUAL
    SET @DIAS  = CASE WHEN @FECHA_ACTUAL IS NULL THEN 1
                      ELSE CEILING(DATEDIFF(MINUTE, @FECHA_ACTUAL, @FECHA_LECTURA_UTC) / 1440.0) END
    IF (@DIAS < 1) SET @DIAS = 1

    IF (@SALTO > @MAXIMO_DIARIO * @DIAS)
    BEGIN
        SET @CALIDAD = 5
        SET @MENSAJE = 'Lectura registrada. El salto de ' + LTRIM(STR(@SALTO, 18, 1)) +
                       ' en ' + LTRIM(STR(@DIAS, 18, 0)) + ' dia(s) supera el maximo diario (' +
                       LTRIM(STR(@MAXIMO_DIARIO, 18, 1)) + '): queda pendiente de revision.'
    END
END

BEGIN TRY
    SET XACT_ABORT ON
    BEGIN TRANSACTION

        INSERT [dbo].[Activo_Medidor_Lectura]
            (aml_uuid, aml_cliente, aml_activo_medidor, aml_fecha_lectura_utc,
             aml_valor_acumulado, aml_es_reinicio, aml_dato_origen,
             aml_medicion_calidad, aml_entrada_modo, aml_orden_trabajo,
             aml_observacion, aml_usuario_creacion, aml_fecha_creacion)
        VALUES
            (@UUID, @CLIENTE, @ACTIVO_MEDIDOR, @FECHA_LECTURA_UTC,
             @VALOR_ACUMULADO, @ES_REINICIO,
             CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN 4 ELSE 3 END,   -- ORDEN TRABAJO o MANUAL
             @CALIDAD,   -- 1 VALIDA · 5 PENDIENTE REVISION (salto no razonable)
             ISNULL(@ENTRADA_MODO, 1),  -- TECLADO
             @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

        SET @ID = SCOPE_IDENTITY()

        /* El valor actual del medidor es una denormalizacion controlada: la
           ficha y las programaciones por medidor lo leen mil veces y buscar
           el maximo del historial en cada una seria caro.

           Solo se adelanta si esta lectura es mas nueva que la que hay: una
           lectura vieja que llega tarde —encolada sin señal— no puede
           retroceder el contador. */
        UPDATE  [dbo].[Activo_Medidor]
        SET     ame_valor_actual           = @VALOR_ACUMULADO
               ,ame_fecha_valor_actual_utc = @FECHA_LECTURA_UTC
               ,ame_usuario_actualizacion  = @USUARIO
               ,ame_fecha_actualizacion    = @AHORA
        WHERE   ame_id = @ACTIVO_MEDIDOR
        AND     (ame_fecha_valor_actual_utc IS NULL
                 OR ame_fecha_valor_actual_utc <= @FECHA_LECTURA_UTC)

        /* La alerta que alimenta el informe de lecturas a revisar. */
        IF (@CALIDAD = 5)
            INSERT INTO [dbo].[Alerta]
                (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
                 ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo, ale_activo_medidor,
                 ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
                 ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc, ale_ocurrencias,
                 ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
            SELECT  NEWID(), @CLIENTE, ACT.act_cliente_instalacion,
                    (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LECTURA A REVISAR'), 1, 3,
                    'Lectura a revisar en ' + AME.ame_nombre,
                    'El medidor ' + AME.ame_codigo + ' de ' + ACT.act_codigo + ' avanzo ' + LTRIM(STR(@SALTO, 18, 1)) +
                    ' en ' + LTRIM(STR(@DIAS, 18, 0)) + ' dia(s); el maximo diario es ' + LTRIM(STR(@MAXIMO_DIARIO, 18, 1)) + '.',
                    @AHORA, @ACTIVO, @ACTIVO_MEDIDOR,
                    @SALTO, @MAXIMO_DIARIO * @DIAS, AME.ame_unidad_medida,
                    @AHORA, @AHORA, 1,
                    @USUARIO, @AHORA, 1
            FROM    [dbo].[Activo_Medidor] AME
            JOIN    [dbo].[Activo] ACT ON ACT.act_id = AME.ame_activo
            WHERE   AME.ame_id = @ACTIVO_MEDIDOR

    COMMIT TRANSACTION

    /* HU-073: la lectura puede disparar la ocurrencia del plan por horas o
       la alerta de aviso. Va DESPUES del commit y con su propio TRY: un
       error del generador no puede perder la lectura que ya se guardo. */
    BEGIN TRY
        DECLARE @GEN INT
        EXEC [dbo].[GEN_PLAN_OCURRENCIAS_MEDIDOR] @CLIENTE = @CLIENTE, @ACTIVO_MEDIDOR = @ACTIVO_MEDIDOR, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT
        IF (@GEN > 0) SET @MENSAJE = @MENSAJE + ' Se genero ' + LTRIM(STR(@GEN)) + ' ocurrencia(s) del plan por horas.'
    END TRY
    BEGIN CATCH
        INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
        VALUES ('GEN_PLAN_OCURRENCIAS_MEDIDOR medidor ' + LTRIM(STR(@ACTIVO_MEDIDOR)), ERROR_MESSAGE(), [dbo].[FNC_AHORA]())
    END CATCH

    SELECT @ID [ID], '200' [CODE], @MENSAJE [MENSAJE]
    RETURN 0
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @MSG = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END CATCH
GO

CREATE OR ALTER PROCEDURE [dbo].[API_INS_ACTIVO_MEDICION]
     @ID                  INT OUTPUT
    ,@CLIENTE             INT
    ,@ACTIVO_VARIABLE     INT
    ,@VALOR               DECIMAL(18,4)
    ,@FECHA_MEDICION_UTC  DATETIME       = NULL
    ,@UNIDAD_MEDIDA       INT            = NULL
    ,@ACTIVO_COMPONENTE   INT            = NULL
    ,@ORDEN_TRABAJO       INT            = NULL
    ,@OBSERVACION         NVARCHAR(1000) = NULL
    ,@ENTRADA_MODO        INT            = NULL
    ,@UUID                UNIQUEIDENTIFIER = NULL
    ,@USUARIO             INT
AS
SET NOCOUNT ON

DECLARE  @AHORA            DATETIME = GETUTCDATE()
        ,@ACTIVO           INT
        ,@UNIDAD_VARIABLE  INT
        ,@FACTOR           DECIMAL(18,8)
        ,@OFFSET           DECIMAL(18,8)
        ,@UNIDAD_BASE      INT
        ,@VALOR_CANONICO   DECIMAL(18,4)
        /* HU-044 #1: el veredicto se toma sobre el equivalente en la unidad
           de la variable, que es la de los umbrales. */
        ,@FACTOR_VAR       DECIMAL(18,8)
        ,@OFFSET_VAR       DECIMAL(18,8)
        ,@VALOR_VAR        DECIMAL(18,4)
        ,@MIN              DECIMAL(18,4)
        ,@MAX              DECIMAL(18,4)
        ,@ADV              DECIMAL(18,4)
        ,@CRI              DECIMAL(18,4)
        ,@NIVEL            NVARCHAR(20) = 'NORMAL'
        ,@UMBRAL           DECIMAL(18,4)
        ,@SEVERIDAD        INT
        ,@MSG              NVARCHAR(500)

/* ---- Idempotencia ---- */
IF (@UUID IS NOT NULL)
BEGIN
    SET @ID = NULL

    SELECT @ID = amd_id FROM [dbo].[Activo_Medicion] WHERE amd_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'La medicion ya estaba registrada.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())
SET @FECHA_MEDICION_UTC = ISNULL(@FECHA_MEDICION_UTC, @AHORA)

/* ---- La variable tiene que ser del cliente ---- */
SELECT   @ACTIVO          = AVA.ava_activo
        ,@UNIDAD_VARIABLE = AVA.ava_unidad_medida
        ,@MIN = AVA.ava_valor_minimo, @MAX = AVA.ava_valor_maximo
        ,@ADV = AVA.ava_valor_advertencia, @CRI = AVA.ava_valor_critico
FROM     [dbo].[Activo_Variable] AVA
WHERE    AVA.ava_id         = @ACTIVO_VARIABLE
AND      AVA.ava_cliente    = @CLIENTE
AND      AVA.ava_habilitado = 1

IF (@ACTIVO IS NULL)
BEGIN
    RAISERROR('1.- LA VARIABLE NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@VALOR IS NULL)
BEGIN
    RAISERROR('2.- LA MEDICION NECESITA UN VALOR.', 16, 1)
    RETURN -1
END

IF (@FECHA_MEDICION_UTC > DATEADD(HOUR, 1, @AHORA))
BEGIN
    RAISERROR('3.- LA FECHA DE LA MEDICION ESTA EN EL FUTURO. REVISA LA HORA DEL DISPOSITIVO.', 16, 1)
    RETURN -1
END

/* La unidad en que se midio. Si la app no la manda, es la de la variable:
   es lo que la pantalla mostro al lado del campo. */
SET @UNIDAD_MEDIDA = ISNULL(@UNIDAD_MEDIDA, @UNIDAD_VARIABLE)

/* ---- El valor canonico ----
   Se guarda el valor tal como lo escribio la persona Y su equivalente en la
   unidad base de la magnitud. Sin el canonico, comparar una serie donde
   alguien midio en °C y otro en K obliga a convertir en cada consulta, y la
   conversion terminaria escrita en tres lugares distintos. */
SELECT   @FACTOR      = UME.ume_factor
        ,@OFFSET      = UME.ume_offset
        ,@UNIDAD_BASE = ISNULL(UME.ume_unidad_base, UME.ume_id)
FROM     [dbo].[Unidad_Medida] UME
WHERE    UME.ume_id = @UNIDAD_MEDIDA

IF (@FACTOR IS NULL)
BEGIN
    RAISERROR('4.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
    RETURN -1
END

SET @VALOR_CANONICO = (@VALOR * @FACTOR) + ISNULL(@OFFSET, 0)

/* ---- El equivalente en la unidad de la variable (HU-044 #1) ----
   Los umbrales estan en la unidad de la variable. Si se midio en otra (PSI
   con la variable en bar) se compara el equivalente, no el numero tecleado:
   45 PSI no son 45 bar. */
SELECT @FACTOR_VAR = ISNULL(ume_factor, 1), @OFFSET_VAR = ISNULL(ume_offset, 0)
FROM   [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD_VARIABLE
SET @VALOR_VAR = CASE WHEN @UNIDAD_MEDIDA = @UNIDAD_VARIABLE OR ISNULL(@FACTOR_VAR, 0) = 0 THEN @VALOR
                      ELSE (@VALOR_CANONICO - ISNULL(@OFFSET_VAR, 0)) / @FACTOR_VAR END

SET @NIVEL = CASE
    WHEN @CRI IS NOT NULL AND @VALOR_VAR >= @CRI THEN 'CRITICO'
    WHEN @ADV IS NOT NULL AND @VALOR_VAR >= @ADV THEN 'ADVERTENCIA'
    WHEN (@MIN IS NOT NULL AND @VALOR_VAR < @MIN) OR (@MAX IS NOT NULL AND @VALOR_VAR > @MAX) THEN 'FUERA_RANGO'
    ELSE 'NORMAL' END

/* ---- Fuera de umbral: se pide un comentario (HU-044 #2) ----
   Un valor critico sin una linea de contexto -que se vio, que se hizo- es
   un numero que despues nadie sabe interpretar. */
IF (@NIVEL <> 'NORMAL' AND (@OBSERVACION IS NULL OR LTRIM(RTRIM(@OBSERVACION)) = ''))
BEGIN
    SET @UMBRAL = CASE @NIVEL WHEN 'CRITICO' THEN @CRI WHEN 'ADVERTENCIA' THEN @ADV
                              WHEN 'FUERA_RANGO' THEN CASE WHEN @MIN IS NOT NULL AND @VALOR_VAR < @MIN THEN @MIN ELSE @MAX END END
    SET @MSG = '5.- EL VALOR (' + LTRIM(STR(@VALOR_VAR, 18, 2)) + ') ESTA FUERA DE UMBRAL (' +
               LTRIM(STR(@UMBRAL, 18, 2)) + '): INDIQUE UN COMENTARIO CON LO QUE OBSERVO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

BEGIN TRY
    SET XACT_ABORT ON
    BEGIN TRANSACTION

        INSERT [dbo].[Activo_Medicion]
            (amd_uuid, amd_cliente, amd_activo_variable, amd_activo,
             amd_activo_componente, amd_fecha_medicion_utc, amd_valor,
             amd_unidad_medida, amd_valor_canonico, amd_unidad_canonica,
             amd_medicion_calidad, amd_dato_origen, amd_entrada_modo,
             amd_orden_trabajo, amd_observacion,
             amd_usuario_creacion, amd_fecha_creacion)
        VALUES
            (@UUID, @CLIENTE, @ACTIVO_VARIABLE, @ACTIVO,
             @ACTIVO_COMPONENTE, @FECHA_MEDICION_UTC, @VALOR,
             @UNIDAD_MEDIDA, @VALOR_CANONICO, @UNIDAD_BASE,
             1,   -- VALIDA
             CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN 4 ELSE 3 END,   -- ORDEN TRABAJO o MANUAL
             ISNULL(@ENTRADA_MODO, 1),  -- TECLADO
             @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

        SET @ID = SCOPE_IDENTITY()

        /* ---- La alerta (HU-044 #2) ----
           MEDICION FUERA RANGO, con severidad segun el nivel: critico 4,
           advertencia 3, fuera del rango operativo 2. Va a la bandeja de
           alertas y a la ficha del activo. */
        IF (@NIVEL <> 'NORMAL')
        BEGIN
            SET @SEVERIDAD = CASE @NIVEL WHEN 'CRITICO' THEN 4 WHEN 'ADVERTENCIA' THEN 3 ELSE 2 END
            SET @UMBRAL = CASE @NIVEL WHEN 'CRITICO' THEN @CRI WHEN 'ADVERTENCIA' THEN @ADV
                                      ELSE CASE WHEN @MIN IS NOT NULL AND @VALOR_VAR < @MIN THEN @MIN ELSE @MAX END END
            INSERT INTO [dbo].[Alerta]
                (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
                 ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo, ale_activo_componente,
                 ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
                 ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc, ale_ocurrencias,
                 ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
            SELECT  NEWID(), @CLIENTE, ACT.act_cliente_instalacion,
                    (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDICION FUERA RANGO'), 1, @SEVERIDAD,
                    VME.vme_nombre + ' ' + CASE @NIVEL WHEN 'CRITICO' THEN 'en nivel critico' WHEN 'ADVERTENCIA' THEN 'en advertencia' ELSE 'fuera del rango operativo' END +
                    ' en ' + ACT.act_codigo,
                    'Se midio ' + LTRIM(STR(@VALOR_VAR, 18, 2)) + ' ' + ISNULL(UME.ume_simbolo, '') +
                    ' contra un umbral de ' + LTRIM(STR(@UMBRAL, 18, 2)) + ' ' + ISNULL(UME.ume_simbolo, '') +
                    '. ' + ISNULL(@OBSERVACION, ''),
                    @FECHA_MEDICION_UTC, @ACTIVO, @ACTIVO_COMPONENTE,
                    @VALOR_VAR, @UMBRAL, @UNIDAD_VARIABLE,
                    @FECHA_MEDICION_UTC, @FECHA_MEDICION_UTC, 1,
                    @USUARIO, @AHORA, 1
            FROM    [dbo].[Activo] ACT
            JOIN    [dbo].[Activo_Variable] AVA ON AVA.ava_id = @ACTIVO_VARIABLE
            JOIN    [dbo].[Variable_Medicion] VME ON VME.vme_id = AVA.ava_variable_medicion
       LEFT JOIN    [dbo].[Unidad_Medida] UME ON UME.ume_id = @UNIDAD_VARIABLE
            WHERE   ACT.act_id = @ACTIVO
        END

    COMMIT TRANSACTION

    /* HU-074: la medicion puede disparar la ocurrencia por condicion.
       Despues del commit y con su propio TRY, como en la lectura. */
    BEGIN TRY
        DECLARE @GEN INT
        EXEC [dbo].[GEN_PLAN_OCURRENCIAS_CONDICION] @CLIENTE = @CLIENTE, @ACTIVO_VARIABLE = @ACTIVO_VARIABLE, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT
    END TRY
    BEGIN CATCH
        INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
        VALUES ('GEN_PLAN_OCURRENCIAS_CONDICION variable ' + LTRIM(STR(@ACTIVO_VARIABLE)), ERROR_MESSAGE(), [dbo].[FNC_AHORA]())
    END CATCH

    /* El veredicto contra los umbrales lo devuelve el SP, no la pantalla:
       la web y el telefono tienen que decir lo mismo sobre si un valor esta
       fuera de rango. */
    SELECT   @ID [ID]
            ,'200' [CODE]
            ,CASE @NIVEL
                WHEN 'CRITICO'     THEN 'Medicion registrada. VALOR CRITICO: supera el umbral definido.'
                WHEN 'ADVERTENCIA' THEN 'Medicion registrada. Valor en advertencia.'
                WHEN 'FUERA_RANGO' THEN 'Medicion registrada. Valor fuera del rango operativo.'
                ELSE 'Medicion registrada.'
             END [MENSAJE]
    FROM     [dbo].[Activo_Variable] AVA
    WHERE    AVA.ava_id = @ACTIVO_VARIABLE

    RETURN 0
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @MSG = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END CATCH
GO

PRINT '--- API_INS_ACTIVO_MEDIDOR_LECTURA y API_INS_ACTIVO_MEDICION llaman a los generadores.'
GO

/* ---- 5. El detector periodico comparte la vista del medidor ---- */
CREATE OR ALTER PROCEDURE [dbo].[GEN_ALERTA_OPERACION]
    @CLIENTE INT,
    @USUARIO INT = 1,
    /* Con cuantos dias de atraso una ocurrencia pasa de advertencia a alta. */
    @DIAS_ATRASO_ALTA INT = 7
AS
SET NOCOUNT ON

DECLARE @T_OCURRENCIA INT, @T_PERMISO INT, @T_SIN_LECTURA INT, @T_HALLAZGO INT, @T_DESCUBRIMIENTO INT, @T_PROXIMO INT
DECLARE @NUEVA INT, @RESUELTA INT, @DESCARTADA INT
DECLARE @SEV_ALTA INT, @SEV_ADV INT, @SEV_CRITICA INT
DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

SELECT @T_OCURRENCIA    = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'OCURRENCIA VENCIDA'
SELECT @T_PERMISO       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'PERMISO VENCIDO'
SELECT @T_SIN_LECTURA   = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDIDOR SIN LECTURA'
SELECT @T_HALLAZGO      = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'HALLAZGO CRITICO'
SELECT @T_DESCUBRIMIENTO= alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'DESCUBRIMIENTO TERRENO'
SELECT @T_PROXIMO       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDIDOR PROXIMO MANTENIMIENTO'

SELECT @NUEVA      = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'
SELECT @RESUELTA   = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA'
SELECT @DESCARTADA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'

SELECT @SEV_ALTA    = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'
SELECT @SEV_ADV     = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ADVERTENCIA'
SELECT @SEV_CRITICA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'CRITICA'

IF OBJECT_ID('tempdb..#HALLAZGO') IS NOT NULL DROP TABLE #HALLAZGO

CREATE TABLE #HALLAZGO (
    TIPO INT, INSTALACION INT NULL,
    ACTIVO INT NULL, COMPONENTE INT NULL, MEDIDOR INT NULL, VARIABLE INT NULL,
    OCURRENCIA INT NULL, PERMISO INT NULL, HALLAZGO INT NULL, ORDEN INT NULL,
    TITULO NVARCHAR(400), DESCRIPCION NVARCHAR(1000),
    OBSERVADO DECIMAL(18,4) NULL, UMBRAL DECIMAL(18,4) NULL, UNIDAD INT NULL,
    SEVERIDAD INT)

/* ---- 1. Ocurrencias del plan vencidas y sin orden ----
   La fecha limite manda; si el hito no la tiene, la programada. Vencida es
   ANTES de hoy: la de hoy todavia esta a tiempo. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, OCURRENCIA, TITULO, DESCRIPCION, OBSERVADO, SEVERIDAD)
SELECT  @T_OCURRENCIA, a.act_cliente_instalacion, o.pmo_activo, o.pmo_activo_componente, o.pmo_id,
        N'Ocurrencia vencida: ' + ISNULL(h.pmh_nombre, N'hito del plan') + N' · ' + a.act_codigo,
        N'Estaba para el ' + CONVERT(NVARCHAR(10), CAST(ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc) AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        N' y lleva ' + LTRIM(STR(DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA))) +
        N' días sin orden de trabajo en ' + a.act_nombre + N'.',
        DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA),
        CASE WHEN DATEDIFF(DAY, ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc), @AHORA) > @DIAS_ATRASO_ALTA
             THEN @SEV_ALTA ELSE @SEV_ADV END
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Ocurrencia_Estado] e ON e.poe_id = o.pmo_plan_ocurrencia_estado
JOIN    [dbo].[Activo] a ON a.act_id = o.pmo_activo
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
WHERE   o.pmo_cliente = @CLIENTE
  AND   o.pmo_habilitado = 1
  AND   o.pmo_orden_trabajo IS NULL
  AND   e.poe_codigo IN ('PENDIENTE', 'DISPONIBLE')
  AND   CAST(ISNULL(o.pmo_fecha_limite_utc, o.pmo_fecha_programada_utc) AS DATE) < CAST(@AHORA AS DATE)

/* ---- 2. Permisos de trabajo vencidos que siguen solicitados o autorizados ----
   No se cambia el estado del permiso: eso es de su modulo. Aca solo se avisa. */
INSERT INTO #HALLAZGO (TIPO, ORDEN, PERMISO, TITULO, DESCRIPCION, OBSERVADO, SEVERIDAD)
SELECT  @T_PERMISO, p.ptr_orden_trabajo, p.ptr_id,
        N'Permiso vencido: ' + t.ptt_nombre + ISNULL(N' · folio ' + NULLIF(p.ptr_numero, N''), N''),
        N'Venció el ' + CONVERT(NVARCHAR(10), CAST(p.ptr_fecha_vigencia_fin_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        N' y sigue ' + LOWER(e.pte_nombre) + ISNULL(N' en la OT ' + LTRIM(STR(o.otr_correlativo)), N'') + N'.',
        DATEDIFF(DAY, p.ptr_fecha_vigencia_fin_utc, @AHORA),
        @SEV_ALTA
FROM    [dbo].[Permiso_Trabajo] p
JOIN    [dbo].[Permiso_Trabajo_Tipo] t ON t.ptt_id = p.ptr_permiso_trabajo_tipo
JOIN    [dbo].[Permiso_Trabajo_Estado] e ON e.pte_id = p.ptr_permiso_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = p.ptr_orden_trabajo
WHERE   p.ptr_cliente = @CLIENTE
  AND   p.ptr_habilitado = 1
  AND   e.pte_codigo IN ('SOLICITADO', 'AUTORIZADO')
  AND   p.ptr_fecha_vigencia_fin_utc IS NOT NULL
  AND   p.ptr_fecha_vigencia_fin_utc < @AHORA

/* ---- 3. Variables con frecuencia esperada y sin medicion en ese plazo ----
   "Sin lectura" es que la ultima medicion es mas vieja que la frecuencia; si
   nunca se midio, cuenta desde que se definio la variable. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, VARIABLE, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, SEVERIDAD)
SELECT  @T_SIN_LECTURA, a.act_cliente_instalacion, v.ava_activo, v.ava_activo_componente, v.ava_id,
        N'Sin medición de ' + vm.vme_nombre + N' en ' + a.act_codigo,
        N'Se esperaba cada ' + LTRIM(STR(v.ava_frecuencia_esperada_hora)) + N' h y ' +
        CASE WHEN u.ULTIMA IS NULL THEN N'nunca se ha medido desde que se definió'
             ELSE N'la última fue hace ' + LTRIM(STR(DATEDIFF(HOUR, u.ULTIMA, @AHORA))) + N' h' END + N'.',
        DATEDIFF(HOUR, ISNULL(u.ULTIMA, v.ava_fecha_creacion), @AHORA),
        v.ava_frecuencia_esperada_hora,
        @SEV_ADV
FROM    [dbo].[Activo_Variable] v
JOIN    [dbo].[Activo] a ON a.act_id = v.ava_activo
JOIN    [dbo].[Variable_Medicion] vm ON vm.vme_id = v.ava_variable_medicion
OUTER APPLY (SELECT MAX(m.amd_fecha_medicion_utc) AS ULTIMA
             FROM   [dbo].[Activo_Medicion] m
             WHERE  m.amd_activo_variable = v.ava_id) u
WHERE   v.ava_cliente = @CLIENTE
  AND   v.ava_habilitado = 1
  AND   a.act_habilitado = 1
  AND   v.ava_frecuencia_esperada_hora IS NOT NULL
  AND   v.ava_frecuencia_esperada_hora > 0
  AND   DATEDIFF(HOUR, ISNULL(u.ULTIMA, v.ava_fecha_creacion), @AHORA) > v.ava_frecuencia_esperada_hora

/* ---- 4. Hallazgos criticos o altos de checklist sin orden de trabajo ---- */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, COMPONENTE, HALLAZGO, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_HALLAZGO, a.act_cliente_instalacion, h.cha_activo, h.cha_activo_componente, h.cha_id,
        N'Hallazgo ' + CASE WHEN s.sev_codigo = 'CRITICA' THEN N'crítico' ELSE N'alto' END + N': ' + h.cha_titulo,
        ISNULL(LEFT(h.cha_descripcion, 800), N'') +
        CASE WHEN a.act_id IS NULL THEN N'' ELSE N' (' + a.act_codigo + N' ' + a.act_nombre + N')' END +
        N'. Sin orden de trabajo.',
        h.cha_severidad
FROM    [dbo].[Checklist_Hallazgo] h
JOIN    [dbo].[Severidad] s ON s.sev_id = h.cha_severidad
JOIN    [dbo].[Proceso_Estado] pe ON pe.pes_id = h.cha_proceso_estado
LEFT JOIN [dbo].[Activo] a ON a.act_id = h.cha_activo
WHERE   h.cha_cliente = @CLIENTE
  AND   h.cha_habilitado = 1
  AND   h.cha_orden_trabajo IS NULL
  AND   pe.pes_codigo IN ('PENDIENTE', 'EN PROCESO')
  AND   s.sev_codigo IN ('ALTA', 'CRITICA')

/* ---- 5. Registros creados en terreno que nadie ha revisado ----
   Activos y medidores nacidos en terreno (Anexo C): la alerta vive hasta que
   alguien revisa el descubrimiento desde la web. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_DESCUBRIMIENTO, a.act_cliente_instalacion, a.act_id,
        N'Equipo creado en terreno sin revisar: ' + a.act_codigo,
        a.act_nombre + N' se registró desde el teléfono el ' +
        CONVERT(NVARCHAR(10), CAST(d.rde_fecha_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) +
        ISNULL(N' por ' + u.usu_nombre + N' ' + u.usu_apellido_paterno, N'') + N'. Falta revisarlo.',
        @SEV_ADV
FROM    [dbo].[Activo] a
JOIN    [dbo].[Registro_Descubrimiento] d ON d.rde_id = a.act_registro_descubrimiento
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = d.rde_usuario
WHERE   a.act_cliente = @CLIENTE
  AND   a.act_habilitado = 1
  AND   a.act_fusionado_en IS NULL
  AND   d.rde_fecha_revision IS NULL

INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, MEDIDOR, TITULO, DESCRIPCION, SEVERIDAD)
SELECT  @T_DESCUBRIMIENTO, a.act_cliente_instalacion, m.ame_activo, m.ame_id,
        N'Medidor creado en terreno sin revisar: ' + m.ame_codigo,
        m.ame_nombre + N' de ' + a.act_codigo + N' se registró desde el teléfono el ' +
        CONVERT(NVARCHAR(10), CAST(d.rde_fecha_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME), 103) + N'. Falta revisarlo.',
        @SEV_ADV
FROM    [dbo].[Activo_Medidor] m
JOIN    [dbo].[Activo] a ON a.act_id = m.ame_activo
JOIN    [dbo].[Registro_Descubrimiento] d ON d.rde_id = m.ame_registro_descubrimiento
WHERE   m.ame_cliente = @CLIENTE
  AND   m.ame_habilitado = 1
  AND   d.rde_fecha_revision IS NULL

/* ---- 6. El horometro se acerca al valor de disparo del plan ----
   La misma vista que usa el generador (FNC_PLAN_MEDIDOR_ESTADO): medidor
   por equipo y proximo objetivo desde la ultima ocurrencia. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, MEDIDOR, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, UNIDAD, SEVERIDAD)
SELECT  @T_PROXIMO, a.act_cliente_instalacion, e.ACTIVO, e.MEDIDOR,
        N'Se acerca el mantenimiento por ' + e.MEDIDOR_NOMBRE + N' en ' + a.act_codigo,
        N'Va en ' + LTRIM(STR(e.VALOR_ACTUAL, 18, 1)) + N' ' + ISNULL(um.ume_simbolo, N'') +
        N' y el hito «' + e.HITO_NOMBRE + N'» dispara a los ' + LTRIM(STR(e.PROXIMO, 18, 1)) + N' ' + ISNULL(um.ume_simbolo, N'') + N'. Solo aviso: la orden nace con la ocurrencia.',
        e.VALOR_ACTUAL, e.PROXIMO, e.UNIDAD, @SEV_ADV
FROM    [dbo].[FNC_PLAN_MEDIDOR_ESTADO](@CLIENTE) e
JOIN    [dbo].[Activo] a ON a.act_id = e.ACTIVO
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = e.UNIDAD
WHERE   e.VALOR_ACTUAL IS NOT NULL AND e.AVISO > 0
  AND   e.VALOR_ACTUAL >= e.PROXIMO - e.AVISO AND e.VALOR_ACTUAL < e.PROXIMO


/* ---- Abrir lo que empezo a pasar ---- */
INSERT INTO [dbo].[Alerta]
    (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
     ale_titulo, ale_descripcion, ale_fecha_deteccion_utc,
     ale_activo, ale_activo_componente, ale_activo_medidor, ale_activo_variable,
     ale_plan_mantenimiento_ocurrencia, ale_permiso_trabajo, ale_checklist_hallazgo, ale_orden_trabajo,
     ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
     ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
SELECT  NEWID(), @CLIENTE, h.INSTALACION, h.TIPO, @NUEVA, h.SEVERIDAD,
        h.TITULO, h.DESCRIPCION, @AHORA,
        h.ACTIVO, h.COMPONENTE, h.MEDIDOR, h.VARIABLE,
        h.OCURRENCIA, h.PERMISO, h.HALLAZGO, h.ORDEN,
        h.OBSERVADO, h.UMBRAL, h.UNIDAD,
        @USUARIO, [dbo].[FNC_AHORA](), 1
FROM    #HALLAZGO h
WHERE   NOT EXISTS (
            SELECT 1 FROM [dbo].[Alerta] a
            WHERE  a.ale_cliente = @CLIENTE
              AND  a.ale_alerta_tipo = h.TIPO
              AND  a.ale_habilitado = 1
              AND  a.ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA)
              AND  ISNULL(a.ale_activo, -1)                       = ISNULL(h.ACTIVO, -1)
              AND  ISNULL(a.ale_activo_medidor, -1)               = ISNULL(h.MEDIDOR, -1)
              AND  ISNULL(a.ale_activo_variable, -1)              = ISNULL(h.VARIABLE, -1)
              AND  ISNULL(a.ale_plan_mantenimiento_ocurrencia, -1)= ISNULL(h.OCURRENCIA, -1)
              AND  ISNULL(a.ale_permiso_trabajo, -1)              = ISNULL(h.PERMISO, -1)
              AND  ISNULL(a.ale_checklist_hallazgo, -1)           = ISNULL(h.HALLAZGO, -1))

DECLARE @ABIERTAS_N INT = @@ROWCOUNT

/* ---- Cerrar lo que dejo de pasar ----
   Solo los tipos de ESTE detector: los de inventario los cierra el suyo. */
UPDATE  a
SET     a.ale_alerta_estado         = @RESUELTA,
        a.ale_fecha_atencion_utc    = @AHORA,
        /* CK_ALE_ATENCION: una fecha de atencion exige quien atendio. Lo
           atendio el detector, en nombre de quien lo disparo. */
        a.ale_usuario_atencion      = ISNULL(a.ale_usuario_atencion, @USUARIO),
        a.ale_motivo_resolucion     = ISNULL(a.ale_motivo_resolucion, N'La condición dejó de darse (detector automático).'),
        a.ale_usuario_actualizacion = @USUARIO,
        a.ale_fecha_actualizacion   = [dbo].[FNC_AHORA]()
FROM    [dbo].[Alerta] a
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   a.ale_alerta_tipo IN (@T_OCURRENCIA, @T_PERMISO, @T_SIN_LECTURA, @T_HALLAZGO, @T_DESCUBRIMIENTO, @T_PROXIMO)
  AND   a.ale_alerta_estado NOT IN (@RESUELTA, @DESCARTADA)
  AND   NOT EXISTS (
            SELECT 1 FROM #HALLAZGO h
            WHERE  h.TIPO = a.ale_alerta_tipo
              AND  ISNULL(h.ACTIVO, -1)     = ISNULL(a.ale_activo, -1)
              AND  ISNULL(h.MEDIDOR, -1)    = ISNULL(a.ale_activo_medidor, -1)
              AND  ISNULL(h.VARIABLE, -1)   = ISNULL(a.ale_activo_variable, -1)
              AND  ISNULL(h.OCURRENCIA, -1) = ISNULL(a.ale_plan_mantenimiento_ocurrencia, -1)
              AND  ISNULL(h.PERMISO, -1)    = ISNULL(a.ale_permiso_trabajo, -1)
              AND  ISNULL(h.HALLAZGO, -1)   = ISNULL(a.ale_checklist_hallazgo, -1))

SELECT  @ABIERTAS_N AS ABIERTAS, @@ROWCOUNT AS CERRADAS
RETURN 0
GO

PRINT '--- GEN_ALERTA_OPERACION usa FNC_PLAN_MEDIDOR_ESTADO (bloque 243).'
GO


/* ---- 6. UPS_PROGRAMACION_MEDIDOR acepta el medidor vacio (= el de cada equipo) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMACION_MEDIDOR]
    @ID                 INT = NULL OUTPUT,
    @PROGRAMACION       INT,
    @CLIENTE            INT,
    @ACTIVO_MEDIDOR     INT,
    @VALOR_INICIAL      DECIMAL(18,2) = NULL,
    @CADA_CANTIDAD      DECIMAL(18,2),
    @AVISO_ANTICIPACION DECIMAL(18,2) = NULL,
    @USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El medidor tiene que ser del mismo cliente: sin esta linea se puede atar
   una programacion propia al horometro de otra empresa. */
/* HU-073 #3: NULL significa «el horometro de cada equipo del plan»
   (FNC_PLAN_MEDIDOR_ESTADO lo resuelve por activo). Solo si viene uno
   concreto se exige que sea del cliente. */
IF @ACTIVO_MEDIDOR IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                WHERE ame_id = @ACTIVO_MEDIDOR AND ame_cliente = @CLIENTE AND ame_habilitado = 1)
BEGIN
    RAISERROR('2.- EL MEDIDOR NO EXISTE PARA ESTE CLIENTE O ESTA DESHABILITADO.', 16, 1)
    RETURN -1
END

IF (ISNULL(@CADA_CANTIDAD, 0) <= 0)
BEGIN
    RAISERROR('3.- EL INTERVALO DE MEDIDOR DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* HU-073 #2: el aviso anticipado tiene que caer DENTRO del intervalo. Un
   aviso de 600 horas sobre un ciclo de 500 estaria siempre activo y dejaria
   de significar nada. */
IF (@AVISO_ANTICIPACION IS NOT NULL AND @AVISO_ANTICIPACION >= @CADA_CANTIDAD)
BEGIN
    RAISERROR('4.- EL AVISO ANTICIPADO DEBE SER MENOR QUE EL INTERVALO.', 16, 1)
    RETURN -1
END

IF (@AVISO_ANTICIPACION IS NOT NULL AND @AVISO_ANTICIPACION < 0)
BEGIN
    RAISERROR('5.- EL AVISO ANTICIPADO NO PUEDE SER NEGATIVO.', 16, 1)
    RETURN -1
END

/* Sin valor inicial se toma la lectura actual del medidor: el ciclo empieza
   a contar desde donde esta el equipo hoy, no desde cero. */
IF (@VALOR_INICIAL IS NULL)
    SELECT @VALOR_INICIAL = ame_valor_actual FROM [dbo].[Activo_Medidor]
     WHERE ame_id = @ACTIVO_MEDIDOR

BEGIN TRANSACTION

    SET @ID = NULL

    SELECT @ID = pme_id FROM [dbo].[Programacion_Medidor]
     WHERE pme_programacion = @PROGRAMACION AND pme_habilitado = 1

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Programacion_Medidor]
            (pme_programacion, pme_activo_medidor, pme_valor_inicial,
             pme_cada_cantidad, pme_aviso_anticipacion,
             pme_usuario_creacion, pme_fecha_creacion,
             pme_usuario_actualizacion, pme_fecha_actualizacion, pme_habilitado)
        VALUES
            (@PROGRAMACION, @ACTIVO_MEDIDOR, @VALOR_INICIAL,
             @CADA_CANTIDAD, @AVISO_ANTICIPACION,
             @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

        DECLARE @FILAS INT = @@ROWCOUNT
        SET @ID = SCOPE_IDENTITY()

        IF @FILAS = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('6.- NO FUE POSIBLE GUARDAR LA REGLA DE MEDIDOR.', 16, 1)
            RETURN -1
        END
    END
    ELSE
    BEGIN
        UPDATE [dbo].[Programacion_Medidor]
           SET pme_activo_medidor        = @ACTIVO_MEDIDOR,
               pme_valor_inicial         = @VALOR_INICIAL,
               pme_cada_cantidad         = @CADA_CANTIDAD,
               pme_aviso_anticipacion    = @AVISO_ANTICIPACION,
               pme_usuario_actualizacion = @USUARIO,
               pme_fecha_actualizacion   = @AHORA
         WHERE pme_id = @ID
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de medidor guardada con éxito.' AS MENSAJE
GO

PRINT '--- UPS_PROGRAMACION_MEDIDOR acepta NULL como «el horometro de cada equipo» (bloque 243).'
GO
