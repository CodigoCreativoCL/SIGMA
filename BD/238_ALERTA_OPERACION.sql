/* ============================================================================
   SIGMA — Bloque 238
   LOS DETECTORES DE LOS OTROS MODULOS                    HU-077 · T-3957
   ----------------------------------------------------------------------------

   El bloque 81 dejo el motor de alertas —tipos, bandeja, campana, freno
   atomico— con UN detector: el de inventario. Los tipos de los demas
   modulos estaban declarados desde el principio y nadie los abria:

     OCURRENCIA VENCIDA           el plan dijo "hoy" y no hay orden
     PERMISO VENCIDO              el permiso caduco y sigue solicitado/autorizado
     MEDIDOR SIN LECTURA          la variable tenia frecuencia y nadie la midio
     HALLAZGO CRITICO             un checklist encontro algo critico y no hay OT
     DESCUBRIMIENTO TERRENO       un registro creado en terreno sin revisar
     MEDIDOR PROXIMO MANTENIMIENTO el horometro se acerca al valor del plan

   MISMO PATRON QUE GEN_ALERTA_INVENTARIO

     Lo que hoy esta mal se calcula UNA vez en #HALLAZGO; se abre lo que no
     tiene alerta viva (NOT EXISTS sobre la llave funcional) y se cierra como
     RESUELTA lo que dejo de pasar. Idempotente: correrlo dos veces seguidas
     no duplica. La repeticion (bloque 112) sigue corriendo despues, desde
     la web, como hasta ahora.

   LA LLAVE FUNCIONAL NECESITA TRES COLUMNAS MAS

     Alerta ya cuelga de activo, medidor, ocurrencia, respuesta de checklist
     y orden. Le faltaban el permiso de trabajo, la variable de condicion y
     el hallazgo: sin ellas, dos permisos vencidos de la misma orden serian
     "la misma alerta". Se agregan nullable, con su FK, y el cierre las usa.

   TODO SE ACOTA POR CLIENTE, Y LA SEVERIDAD DICE CUANTO URGE

     Ocurrencia con mas de siete dias de atraso es ALTA; el resto ADVERTENCIA.
     Un permiso vencido es ALTA siempre: hay gente trabajando sin papel.
     Un hallazgo critico hereda la severidad del hallazgo.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. LAS COLUMNAS QUE FALTABAN EN Alerta
   ======================================================================== */
IF COL_LENGTH('dbo.Alerta', 'ale_permiso_trabajo') IS NULL
BEGIN
    ALTER TABLE [dbo].[Alerta] ADD [ale_permiso_trabajo] INT NULL
        CONSTRAINT FK_ALE_PERMISO_TRABAJO FOREIGN KEY REFERENCES [dbo].[Permiso_Trabajo] ([ptr_id])
    PRINT '--- Alerta.ale_permiso_trabajo agregada'
END
IF COL_LENGTH('dbo.Alerta', 'ale_activo_variable') IS NULL
BEGIN
    ALTER TABLE [dbo].[Alerta] ADD [ale_activo_variable] INT NULL
        CONSTRAINT FK_ALE_ACTIVO_VARIABLE FOREIGN KEY REFERENCES [dbo].[Activo_Variable] ([ava_id])
    PRINT '--- Alerta.ale_activo_variable agregada'
END
IF COL_LENGTH('dbo.Alerta', 'ale_checklist_hallazgo') IS NULL
BEGIN
    ALTER TABLE [dbo].[Alerta] ADD [ale_checklist_hallazgo] INT NULL
        CONSTRAINT FK_ALE_CHECKLIST_HALLAZGO FOREIGN KEY REFERENCES [dbo].[Checklist_Hallazgo] ([cha_id])
    PRINT '--- Alerta.ale_checklist_hallazgo agregada'
END
GO


/* ========================================================================
   2. GEN_ALERTA_OPERACION
   ======================================================================== */
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  16-09-2026
-- DESCRIPTION:     DETECTA Y CIERRA LAS ALERTAS DE PLANES, PERMISOS,
--                  MEDICIONES, CHECKLISTS Y DESCUBRIMIENTOS DE UN CLIENTE
-- =============================================
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
   Proximo = inicial + cada * (los ciclos ya cumplidos + 1). Se avisa cuando
   el valor actual entra en la anticipacion configurada. */
INSERT INTO #HALLAZGO (TIPO, INSTALACION, ACTIVO, MEDIDOR, TITULO, DESCRIPCION, OBSERVADO, UMBRAL, UNIDAD, SEVERIDAD)
SELECT  @T_PROXIMO, a.act_cliente_instalacion, m.ame_activo, m.ame_id,
        N'Se acerca el mantenimiento por ' + m.ame_nombre + N' en ' + a.act_codigo,
        N'Va en ' + LTRIM(STR(CAST(m.ame_valor_actual AS DECIMAL(18,2)), 18, 2)) + N' ' + ISNULL(um.ume_simbolo, N'') +
        N' y el plan «' + pr.pro_nombre + N'» dispara a los ' + LTRIM(STR(CAST(x.PROXIMO AS DECIMAL(18,2)), 18, 2)) + N'.',
        m.ame_valor_actual, x.PROXIMO, m.ame_unidad_medida,
        CASE WHEN m.ame_valor_actual >= x.PROXIMO THEN @SEV_ALTA ELSE @SEV_ADV END
FROM    [dbo].[Programacion_Medidor] pm
JOIN    [dbo].[Programacion] pr ON pr.pro_id = pm.pme_programacion
JOIN    [dbo].[Activo_Medidor] m ON m.ame_id = pm.pme_activo_medidor
JOIN    [dbo].[Activo] a ON a.act_id = m.ame_activo
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = m.ame_unidad_medida
CROSS APPLY (SELECT pm.pme_valor_inicial + pm.pme_cada_cantidad *
                    (FLOOR((ISNULL(m.ame_valor_actual, 0) - pm.pme_valor_inicial) / NULLIF(pm.pme_cada_cantidad, 0)) + 1) AS PROXIMO) x
WHERE   pr.pro_cliente = @CLIENTE
  AND   pr.pro_habilitado = 1
  AND   pm.pme_habilitado = 1
  AND   m.ame_habilitado = 1
  AND   pm.pme_cada_cantidad > 0
  AND   m.ame_valor_actual IS NOT NULL
  AND   m.ame_valor_actual >= x.PROXIMO - ISNULL(pm.pme_aviso_anticipacion, 0)


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

PRINT '--- GEN_ALERTA_OPERACION creado.'
GO


/* ========================================================================
   3. GEN_ALERTA_DETECTAR corre los DOS detectores en el mismo turno
      (el freno atomico del bloque 85 no cambia).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[GEN_ALERTA_DETECTAR]
    @CLIENTE INT,
    @USUARIO INT,
    /* Cinco minutos: un repuesto no baja de su minimo dos veces en ese rato,
       y es corto para que quien acaba de registrar una salida vea el aviso
       antes de irse de la pantalla. */
    @MINUTOS INT = 5,
    /* El boton "Revisar ahora" pasa por aca igual, pero saltandose el freno:
       si alguien lo aprieta es porque quiere saber AHORA. */
    @FORZAR  BIT = 0
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @TOCA BIT = 0

/* Se reclama el turno con un UPDATE condicional. Es atomico: de dos usuarios
   que entren en el mismo segundo, solo uno ve @@ROWCOUNT = 1. El otro sigue
   de largo sin esperar ni fallar. */
UPDATE [dbo].[Alerta_Deteccion]
SET    ade_fecha_utc = @AHORA
WHERE  ade_cliente = @CLIENTE
  AND  (@FORZAR = 1 OR DATEDIFF(MINUTE, ade_fecha_utc, @AHORA) >= @MINUTOS)

IF (@@ROWCOUNT = 1) SET @TOCA = 1

/* Primera vez para este cliente. El INSERT puede chocar si dos entran a la
   vez; el que pierde simplemente no ejecuta. */
IF (@TOCA = 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Deteccion] WHERE ade_cliente = @CLIENTE))
BEGIN
    BEGIN TRY
        INSERT INTO [dbo].[Alerta_Deteccion] (ade_cliente, ade_fecha_utc)
        VALUES (@CLIENTE, @AHORA)

        SET @TOCA = 1
    END TRY
    BEGIN CATCH
        SET @TOCA = 0
    END CATCH
END

IF (@TOCA = 1)
BEGIN
    DECLARE @R TABLE (ABIERTAS INT, CERRADAS INT)

    INSERT INTO @R
    EXEC [dbo].[GEN_ALERTA_INVENTARIO] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO

    /* Los otros modulos (bloque 238): planes, permisos, mediciones,
       checklists y descubrimientos. Mismo turno, misma cuenta. */
    INSERT INTO @R
    EXEC [dbo].[GEN_ALERTA_OPERACION] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO

    UPDATE  d
    SET     d.ade_abiertas = r.ABIERTAS,
            d.ade_cerradas = r.CERRADAS
    FROM    [dbo].[Alerta_Deteccion] d
    CROSS JOIN (SELECT SUM(ABIERTAS) AS ABIERTAS, SUM(CERRADAS) AS CERRADAS FROM @R) r
    WHERE   d.ade_cliente = @CLIENTE
END

/* Se devuelve el resumen SIEMPRE, corriera o no el detector: el navegador
   pregunta para refrescar sus numeros, y hacerle dar dos viajes -uno para
   detectar y otro para contar- seria el doble de trafico para lo mismo. */
EXEC [dbo].[SEL_ALERTA_RESUMEN] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO

RETURN 0
GO

PRINT '--- GEN_ALERTA_DETECTAR corre inventario + operacion.'
GO


/* ========================================================================
   4. VERIFICACION: dos pasadas seguidas, la segunda no abre nada nuevo.
   ======================================================================== */
EXEC [dbo].[GEN_ALERTA_OPERACION] @CLIENTE = 1, @USUARIO = 1
EXEC [dbo].[GEN_ALERTA_OPERACION] @CLIENTE = 1, @USUARIO = 1
GO
