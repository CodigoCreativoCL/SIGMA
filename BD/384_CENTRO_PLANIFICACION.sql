USE [db_acd593_sigma]
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  08-10-2026
-- DESCRIPTION:     384 · CENTRO DE PLANIFICACIÓN (BLOQUE A). ESQUEMA, MIGRACIÓN
--                  DE PROGRAMACIONES PRIVADAS, SP NUEVOS Y SP MODIFICADOS.
--                  CONTRATO: MD/CENTRO_PLANIFICACION_ALCANCE.md (§19.3, §21.2, §26).
--                  TODO IDEMPOTENTE.
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
   1. ESQUEMA (§19.3)
   ======================================================================== */

/* La frecuencia privada de una intervención (RP-01) vs el calendario
   compartido de la Biblioteca. Las existentes nacen compartidas. */
IF COL_LENGTH('dbo.Programacion', 'pro_es_privada') IS NULL
    ALTER TABLE [dbo].[Programacion] ADD pro_es_privada BIT NOT NULL
        CONSTRAINT DF_PRO_ES_PRIVADA DEFAULT (0)
GO

/* El «quién» de la intervención (RP-09). */
IF COL_LENGTH('dbo.Plan_Mantenimiento_Hito', 'pmh_usuario_responsable') IS NULL
    ALTER TABLE [dbo].[Plan_Mantenimiento_Hito] ADD pmh_usuario_responsable INT NULL
        CONSTRAINT FK_PMH_USUARIO_RESPONSABLE REFERENCES [dbo].[Usuario](usu_id)
GO
IF COL_LENGTH('dbo.Plan_Mantenimiento_Hito', 'pmh_grupo_trabajo') IS NULL
    ALTER TABLE [dbo].[Plan_Mantenimiento_Hito] ADD pmh_grupo_trabajo INT NULL
        CONSTRAINT FK_PMH_GRUPO_TRABAJO REFERENCES [dbo].[Grupo_Trabajo](gtr_id)
GO

/* El motivo de desactivar un plan (RP-08). */
IF COL_LENGTH('dbo.Plan_Mantenimiento_Version', 'pmv_motivo_retiro') IS NULL
    ALTER TABLE [dbo].[Plan_Mantenimiento_Version] ADD pmv_motivo_retiro NVARCHAR(400) NULL
GO

/* ========================================================================
   2. MIGRACIÓN DE PROGRAMACIONES PRIVADAS (§26.5)
      Privada solo si TODOS sus usos son hitos de UN mismo plan con UN mismo
      código de hito (las versiones copian la referencia) y no la usa ninguna
      tarea ni pauta. El resto queda compartido: nada que ya genera cambia.
   ======================================================================== */
;WITH usos AS (
    SELECT  h.pmh_programacion AS pro, v.pmv_plan_mantenimiento AS pla, h.pmh_codigo AS cod
    FROM    [dbo].[Plan_Mantenimiento_Hito] h
    JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
)
UPDATE p SET pro_es_privada = 1
FROM   [dbo].[Programacion] p
WHERE  p.pro_es_privada = 0
  AND  EXISTS (SELECT 1 FROM usos u WHERE u.pro = p.pro_id)
  AND  (SELECT COUNT(DISTINCT CAST(u.pla AS NVARCHAR(20)) + N'|' + u.cod) FROM usos u WHERE u.pro = p.pro_id) = 1
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Programacion] t WHERE t.tpr_programacion = p.pro_id)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] c WHERE c.cpr_programacion = p.pro_id)
GO


/* ========================================================================
   3. INS_PROGRAMACION_COPIA
      Copia una programación con todo su detalle como PRIVADA. La usan la
      frecuencia de la intervención (copia al escribir, RP-03) y el duplicado
      de planes (RP-13). Las copias nunca generan por sí solas: las genera
      el hito que las apunta.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_PROGRAMACION_COPIA]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @ORIGEN  INT,
    @NOMBRE  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @ORIGEN AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACIÓN DE ORIGEN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* El nombre es único entre las habilitadas del cliente (INS_PROGRAMACION
   lo exige): si choca, se numera. Las privadas no se muestran en ningún
   listado, así que el sufijo no lo ve nadie. */
DECLARE @BASE NVARCHAR(380) = LEFT(LTRIM(RTRIM(ISNULL(@NOMBRE, N'Frecuencia'))), 380), @N INT = 1
SET @NOMBRE = @BASE
WHILE EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = @NOMBRE AND pro_habilitado = 1)
BEGIN
    SET @N = @N + 1
    SET @NOMBRE = @BASE + N' (' + CAST(@N AS NVARCHAR(10)) + N')'
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Programacion]
        (pro_cliente, pro_programacion_tipo, pro_zona_horaria, pro_nombre, pro_fecha_inicio, pro_fecha_fin,
         pro_tolerancia_antes_minuto, pro_tolerancia_despues_minuto, pro_permite_anticipada, pro_permite_atrasada,
         pro_cumplimiento_politica, pro_genera_automaticamente,
         pro_usuario_creacion, pro_fecha_creacion, pro_usuario_actualizacion, pro_fecha_actualizacion,
         pro_habilitado, pro_es_privada)
    SELECT  pro_cliente, pro_programacion_tipo, pro_zona_horaria, @NOMBRE, pro_fecha_inicio, pro_fecha_fin,
            pro_tolerancia_antes_minuto, pro_tolerancia_despues_minuto, pro_permite_anticipada, pro_permite_atrasada,
            pro_cumplimiento_politica, 1,
            @USUARIO, @AHORA, @USUARIO, @AHORA,
            1, 1
    FROM    [dbo].[Programacion]
    WHERE   pro_id = @ORIGEN

    SET @ID = SCOPE_IDENTITY()

    DECLARE @MAPA TABLE (viejo INT, nuevo INT)

    MERGE [dbo].[Programacion_Calendario] AS d
    USING (SELECT * FROM [dbo].[Programacion_Calendario] WHERE pca_programacion = @ORIGEN AND pca_habilitado = 1) AS s
       ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (pca_programacion, pca_frecuencia_tipo, pca_intervalo, pca_semana_ordinal, pca_dia_mes, pca_mes, pca_hora_local,
                pca_usuario_creacion, pca_fecha_creacion, pca_usuario_actualizacion, pca_fecha_actualizacion, pca_habilitado)
        VALUES (@ID, s.pca_frecuencia_tipo, s.pca_intervalo, s.pca_semana_ordinal, s.pca_dia_mes, s.pca_mes, s.pca_hora_local,
                @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
    OUTPUT s.pca_id, inserted.pca_id INTO @MAPA (viejo, nuevo);

    INSERT INTO [dbo].[Programacion_Calendario_Dia] (pcd_programacion_calendario, pcd_dia_semana)
    SELECT m.nuevo, d.pcd_dia_semana
    FROM   [dbo].[Programacion_Calendario_Dia] d JOIN @MAPA m ON m.viejo = d.pcd_programacion_calendario

    INSERT INTO [dbo].[Programacion_Intervalo]
        (pin_programacion, pin_unidad_tiempo, pin_fecha_ancla_utc, pin_cantidad, pin_desde_ejecucion,
         pin_usuario_creacion, pin_fecha_creacion, pin_usuario_actualizacion, pin_fecha_actualizacion, pin_habilitado)
    SELECT @ID, pin_unidad_tiempo, pin_fecha_ancla_utc, pin_cantidad, pin_desde_ejecucion,
           @USUARIO, @AHORA, @USUARIO, @AHORA, 1
    FROM   [dbo].[Programacion_Intervalo] WHERE pin_programacion = @ORIGEN AND pin_habilitado = 1

    INSERT INTO [dbo].[Programacion_Medidor]
        (pme_programacion, pme_activo_medidor, pme_valor_inicial, pme_cada_cantidad, pme_aviso_anticipacion,
         pme_usuario_creacion, pme_fecha_creacion, pme_usuario_actualizacion, pme_fecha_actualizacion, pme_habilitado)
    SELECT @ID, pme_activo_medidor, pme_valor_inicial, pme_cada_cantidad, pme_aviso_anticipacion,
           @USUARIO, @AHORA, @USUARIO, @AHORA, 1
    FROM   [dbo].[Programacion_Medidor] WHERE pme_programacion = @ORIGEN AND pme_habilitado = 1

    INSERT INTO [dbo].[Programacion_Fecha] (pfe_programacion, pfe_fecha, pfe_hora, pfe_incluida)
    SELECT @ID, pfe_fecha, pfe_hora, pfe_incluida
    FROM   [dbo].[Programacion_Fecha] WHERE pfe_programacion = @ORIGEN

    INSERT INTO [dbo].[Programacion_Condicion]
        (pco_programacion, pco_activo_variable, pco_operador_comparacion, pco_umbral, pco_umbral_hasta,
         pco_duracion_minima_minuto, pco_severidad, pco_usuario_creacion, pco_fecha_creacion,
         pco_usuario_actualizacion, pco_fecha_actualizacion, pco_habilitado)
    SELECT @ID, pco_activo_variable, pco_operador_comparacion, pco_umbral, pco_umbral_hasta,
           pco_duracion_minima_minuto, pco_severidad, @USUARIO, @AHORA, @USUARIO, @AHORA, 1
    FROM   [dbo].[Programacion_Condicion] WHERE pco_programacion = @ORIGEN AND pco_habilitado = 1

    INSERT INTO [dbo].[Programacion_Exclusion]
        (pxc_programacion, pxc_fecha_inicio_utc, pxc_fecha_fin_utc, pxc_motivo, pxc_desplaza,
         pxc_usuario_creacion, pxc_fecha_creacion, pxc_usuario_actualizacion, pxc_fecha_actualizacion, pxc_habilitado)
    SELECT @ID, pxc_fecha_inicio_utc, pxc_fecha_fin_utc, pxc_motivo, pxc_desplaza,
           @USUARIO, @AHORA, @USUARIO, @AHORA, 1
    FROM   [dbo].[Programacion_Exclusion] WHERE pxc_programacion = @ORIGEN AND pxc_habilitado = 1

    INSERT INTO [dbo].[Programacion_Generacion]
        (pge_programacion, pge_horizonte_dia, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
    VALUES (@ID, 90, 0, @USUARIO, @AHORA)

COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   4. INS_PROGRAMACION_PRIVADA
      La frecuencia vacía de una intervención nueva: tipo ABIERTA, que no
      genera nada. Para el Centro, ABIERTA = «falta la frecuencia»
      (bloqueante de Activar).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_PROGRAMACION_PRIVADA]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @TIPO INT = (SELECT pti_id FROM [dbo].[Programacion_Tipo] WHERE pti_codigo = 'ABIERTA')

DECLARE @BASE NVARCHAR(380) = LEFT(LTRIM(RTRIM(ISNULL(@NOMBRE, N'Frecuencia'))), 380), @N INT = 1
SET @NOMBRE = @BASE
WHILE EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = @NOMBRE AND pro_habilitado = 1)
BEGIN
    SET @N = @N + 1
    SET @NOMBRE = @BASE + N' (' + CAST(@N AS NVARCHAR(10)) + N')'
END

BEGIN TRANSACTION
    INSERT INTO [dbo].[Programacion]
        (pro_cliente, pro_programacion_tipo, pro_nombre, pro_fecha_inicio,
         pro_tolerancia_antes_minuto, pro_tolerancia_despues_minuto, pro_permite_anticipada, pro_permite_atrasada,
         pro_genera_automaticamente, pro_usuario_creacion, pro_fecha_creacion, pro_usuario_actualizacion, pro_fecha_actualizacion,
         pro_habilitado, pro_es_privada)
    VALUES
        (@CLIENTE, @TIPO, @NOMBRE, CAST(@AHORA AS DATE),
         0, 0, 1, 1,
         1, @USUARIO, @AHORA, @USUARIO, @AHORA,
         1, 1)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Programacion_Generacion]
        (pge_programacion, pge_horizonte_dia, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
    VALUES (@ID, 90, 0, @USUARIO, @AHORA)
COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   5. SEL_PLAN_CENTRO (§26.2)
      La lista del workspace en UNA consulta: estado derivado (§8.3),
      conteos, próxima ejecución (o proyección en un borrador), vencidas y
      atrasadas, frecuencias y responsable. Reemplaza el N+1 de
      WsPlanificacion360.Planes().
      La «versión de edición» es el borrador si hay; si no, la publicada;
      si no, la última retirada.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CENTRO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @PLAN        INT = NULL
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = GETUTCDATE()

SELECT  pma.pma_id, pma.pma_codigo, pma.pma_nombre, pma.pma_habilitado, pma.pma_cliente_instalacion,
        pma.pma_activo_tipo, pma.pma_activo_modelo,
        pub.pmv_id AS PUB_ID, pub.pmv_numero AS PUB_NUM, pub.pmv_fecha_publicacion AS PUB_FECHA,
        bor.pmv_id AS BOR_ID, bor.pmv_numero AS BOR_NUM,
        ret.pmv_id AS RET_ID, ret.pmv_numero AS RET_NUM,
        CAST(NULL AS INT) AS VER_ID
INTO    #p
FROM    [dbo].[Plan_Mantenimiento] pma
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero, v.pmv_fecha_publicacion FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) pub
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 1 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) bor
OUTER APPLY (SELECT TOP 1 v.pmv_id, v.pmv_numero FROM [dbo].[Plan_Mantenimiento_Version] v
              WHERE v.pmv_plan_mantenimiento = pma.pma_id AND v.pmv_plan_version_estado = 3 AND v.pmv_habilitado = 1 ORDER BY v.pmv_numero DESC) ret
WHERE   pma.pma_cliente = @CLIENTE
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)

/* Fuera: los eliminados (deshabilitados sin versión publicada ni retirada). */
DELETE FROM #p WHERE pma_habilitado = 0 AND PUB_ID IS NULL AND RET_ID IS NULL
DELETE FROM #p WHERE pma_habilitado = 1 AND PUB_ID IS NULL AND BOR_ID IS NULL

UPDATE #p SET VER_ID = COALESCE(BOR_ID, PUB_ID, RET_ID)

/* Planta: la del plan o, si el plan no tiene, la de alguno de sus activos. */
IF @INSTALACION IS NOT NULL
    DELETE p FROM #p p
    WHERE ISNULL(p.pma_cliente_instalacion, 0) <> @INSTALACION
      AND NOT (p.pma_cliente_instalacion IS NULL AND EXISTS (
               SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a JOIN [dbo].[Activo] x ON x.act_id = a.pac_activo
               WHERE a.pac_plan_mantenimiento_version = p.VER_ID AND x.act_cliente_instalacion = @INSTALACION))

SELECT  p.pma_id                                   AS PLAN_ID,
        p.pma_codigo                               AS CODIGO,
        p.pma_nombre                               AS NOMBRE,
        CASE WHEN p.pma_habilitado = 0 THEN 'INACTIVO'
             WHEN p.PUB_ID IS NULL     THEN 'BORRADOR'
             WHEN p.BOR_ID IS NOT NULL THEN 'CAMBIOS'
             ELSE 'ACTIVO' END                    AS ESTADO,
        p.pma_cliente_instalacion                  AS PLANTA_ID,
        cin.cin_nombre                             AS PLANTA,
        ati.ati_nombre                             AS TIPO,
        amo.amo_nombre                             AS MODELO,
        p.PUB_NUM                                  AS VERSION_VIGENTE,
        p.PUB_FECHA         AS VERSION_DESDE,
        p.VER_ID                                   AS VERSION_EDICION,
        ISNULL(ac.n, 0)                            AS ACTIVOS,
        ISNULL(hi.n, 0)                            AS INTERVENCIONES,
        ISNULL(hi.sin_frecuencia, 0)               AS SIN_FRECUENCIA,
        ISNULL(oc.vencidas, 0)                     AS VENCIDAS,
        ISNULL(oc.atrasadas, 0)                    AS ATRASADAS,
        px.fecha            AS PROXIMA_FECHA,
        px.activo                                  AS PROXIMA_ACTIVO,
        CAST(0 AS BIT)                             AS PROXIMA_PROYECCION,
        fr.texto                                   AS FRECUENCIAS,
        rs.nombre                                  AS RESPONSABLE
INTO    #r
FROM    #p p
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = p.pma_cliente_instalacion
LEFT JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = p.pma_activo_tipo
LEFT JOIN [dbo].[Activo_Modelo]       amo ON amo.amo_id = p.pma_activo_modelo
OUTER APPLY (SELECT COUNT(*) AS n FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = p.VER_ID) ac
OUTER APPLY (SELECT COUNT(*) AS n,
                    SUM(CASE WHEN t.pti_codigo = 'ABIERTA' THEN 1 ELSE 0 END) AS sin_frecuencia
               FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
               JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
              WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1) hi
OUTER APPLY (SELECT SUM(CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 1 ELSE 0 END) AS vencidas,
                    SUM(CASE WHEN (o.pmo_fecha_limite_utc IS NULL OR o.pmo_fecha_limite_utc >= @UTC) AND o.pmo_fecha_programada_utc < @UTC THEN 1 ELSE 0 END) AS atrasadas
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
               JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
              WHERE v.pmv_plan_mantenimiento = p.pma_id AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)) oc
OUTER APPLY (SELECT TOP 1 o.pmo_fecha_programada_utc AS fecha, act.act_codigo + N' · ' + act.act_nombre AS activo
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
               JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
               JOIN [dbo].[Activo] act ON act.act_id = o.pmo_activo
              WHERE v.pmv_plan_mantenimiento = p.pma_id AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2)
                AND o.pmo_fecha_programada_utc >= CAST(CAST(@UTC AS DATE) AS DATETIME)
              ORDER BY o.pmo_fecha_programada_utc) px
OUTER APPLY (SELECT STRING_AGG(x.nombre, N' · ') AS texto
               FROM (SELECT DISTINCT TOP 3 t.pti_nombre AS nombre
                       FROM [dbo].[Plan_Mantenimiento_Hito] h
                       JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
                       JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
                      WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1 AND t.pti_codigo <> 'ABIERTA') x) fr
OUTER APPLY (SELECT TOP 1 LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS nombre
               FROM [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
              WHERE h.pmh_plan_mantenimiento_version = p.VER_ID AND h.pmh_habilitado = 1
              ORDER BY h.pmh_orden) rs

/* Un plan sin ejecuciones futuras (borrador o activo recién editado):
   la próxima fecha es la PROYECCIÓN de su versión de edición. */
UPDATE r SET PROXIMA_FECHA = pr.fecha, PROXIMA_ACTIVO = pr.activo, PROXIMA_PROYECCION = 1
FROM   #r r
CROSS APPLY (SELECT TOP 1 f.FECHA AS fecha, act.act_codigo + N' · ' + act.act_nombre AS activo
               FROM [dbo].[Plan_Mantenimiento_Hito] h
               JOIN [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
               JOIN [dbo].[Activo] act ON act.act_id = a.pac_activo
               CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, CAST(@UTC AS DATE), DATEADD(DAY, 400, CAST(@UTC AS DATE))) f
              WHERE h.pmh_plan_mantenimiento_version = r.VERSION_EDICION AND h.pmh_habilitado = 1 AND f.DESCARTADA = 0
              ORDER BY f.FECHA) pr
WHERE  r.PROXIMA_FECHA IS NULL AND r.ESTADO IN ('BORRADOR', 'CAMBIOS')

SELECT  r.*,
        CAST(CASE WHEN r.ACTIVOS > 0 AND r.INTERVENCIONES > 0 AND r.SIN_FRECUENCIA = 0 THEN 1 ELSE 0 END AS BIT) AS LISTO
FROM    #r r
ORDER BY CASE WHEN r.VENCIDAS + r.ATRASADAS > 0 THEN 0 ELSE 1 END,
         CASE WHEN r.PROXIMA_FECHA IS NULL THEN 1 ELSE 0 END,
         r.PROXIMA_FECHA, r.NOMBRE
GO

/* ========================================================================
   6. SEL_PLAN_HITO_PROYECCION
      Las próximas fechas de UNA intervención, con las excluidas marcadas y
      su motivo (vista previa del editor de frecuencia, §15.4).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_HITO_PROYECCION]
    @CLIENTE INT,
    @HITO    INT,
    @TOPE    INT = 6
AS
SET NOCOUNT ON

DECLARE @PRO INT, @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

SELECT @PRO = h.pmh_programacion
FROM   [dbo].[Plan_Mantenimiento_Hito] h
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
WHERE  h.pmh_id = @HITO AND p.pma_cliente = @CLIENTE

IF @PRO IS NULL
BEGIN
    RAISERROR('1.- LA INTERVENCIÓN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT TOP (ISNULL(@TOPE, 6) + 6)
       f.FECHA, f.FECHA_ORIGINAL, f.DESPLAZADA, f.DESCARTADA, f.MOTIVO
FROM   [dbo].[FNC_PROGRAMACION_FECHAS](@PRO, @HOY, DATEADD(DAY, 800, @HOY)) f
ORDER BY f.FECHA

RETURN(0)
GO

/* ========================================================================
   7. SEL_PLAN_FICHA (§26.2)
      Todo lo que pinta la ficha, en varios result sets (en este orden):
       0 plan · 1 intervenciones · 2 calendario · 3 intervalo · 4 medidor ·
       5 fechas · 6 exclusiones · 7 condiciones · 8 actividades ·
       9 repuestos · 10 activos · 11 próximas ejecuciones · 12 OT ·
       13 versiones · 14 proyección (versión de edición) ·
       15 próximas fechas por intervención
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_FICHA]
    @CLIENTE INT,
    @PLAN    INT
AS
SET NOCOUNT ON

DECLARE @UTC DATETIME = GETUTCDATE()
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @PUB INT, @BOR INT, @RET INT, @VER INT
SELECT TOP 1 @PUB = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 2 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SELECT TOP 1 @BOR = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SELECT TOP 1 @RET = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 3 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC
SET @VER = COALESCE(@BOR, @PUB, @RET)

/* Cambios del borrador frente a la vigente, comparando el contenido:
   intervenciones, actividades, activos y repuestos distintos, nuevos o
   quitados (cada diferencia cuenta una vez por lado). */
DECLARE @CAMBIOS INT = 0
IF @BOR IS NOT NULL AND @PUB IS NOT NULL
BEGIN
    SET @CAMBIOS =
          (SELECT COUNT(*) FROM (
               SELECT pmh_codigo, pmh_nombre, pmh_programacion, pmh_duracion_estimada_minuto, pmh_requiere_parada, pmh_es_overhaul,
                      pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, ISNULL(pmh_descripcion, N'') AS d, pmh_habilitado,
                      pmh_usuario_responsable, pmh_grupo_trabajo, pmh_orden
                 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @BOR
               EXCEPT
               SELECT pmh_codigo, pmh_nombre, pmh_programacion, pmh_duracion_estimada_minuto, pmh_requiere_parada, pmh_es_overhaul,
                      pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, ISNULL(pmh_descripcion, N''), pmh_habilitado,
                      pmh_usuario_responsable, pmh_grupo_trabajo, pmh_orden
                 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @PUB) x)
        + (SELECT COUNT(*) FROM (
               SELECT pmh_codigo FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @PUB
               EXCEPT
               SELECT pmh_codigo FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @BOR) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo, a.paa_nombre, ISNULL(a.paa_descripcion, N'') AS d, a.paa_procedimiento, a.paa_duracion_estimada_minuto,
                      a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo, a.paa_orden
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo, a.paa_nombre, ISNULL(a.paa_descripcion, N''), a.paa_procedimiento, a.paa_duracion_estimada_minuto,
                      a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo, a.paa_orden
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo
                 FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1) x)
        + (SELECT COUNT(*) FROM (
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) AS c FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @BOR
               EXCEPT
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @PUB) x)
        + (SELECT COUNT(*) FROM (
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) AS c FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @PUB
               EXCEPT
               SELECT pac_activo, ISNULL(pac_activo_componente, 0) FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @BOR) x)
        + (SELECT COUNT(*) FROM (
               SELECT h.pmh_codigo, a.paa_codigo, r.pra_repuesto, r.pra_cantidad
                 FROM [dbo].[Plan_Actividad_Repuesto] r JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
                 JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @BOR AND a.paa_habilitado = 1
               EXCEPT
               SELECT h.pmh_codigo, a.paa_codigo, r.pra_repuesto, r.pra_cantidad
                 FROM [dbo].[Plan_Actividad_Repuesto] r JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
                 JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @PUB AND a.paa_habilitado = 1) x)
END

/* 0 · plan */
SELECT  pma.pma_id AS PLAN_ID, pma.pma_codigo AS CODIGO, pma.pma_nombre AS NOMBRE, pma.pma_descripcion AS DESCRIPCION,
        CASE WHEN pma.pma_habilitado = 0 THEN 'INACTIVO' WHEN @PUB IS NULL THEN 'BORRADOR' WHEN @BOR IS NOT NULL THEN 'CAMBIOS' ELSE 'ACTIVO' END AS ESTADO,
        pma.pma_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        pma.pma_activo_tipo AS TIPO_ID, ati.ati_nombre AS TIPO,
        pma.pma_activo_modelo AS MODELO_ID, amo.amo_nombre AS MODELO,
        pma.pma_usuario_planificador AS PLANIFICADOR_ID,
        @VER AS VERSION_EDICION, @BOR AS BORRADOR_ID, @PUB AS PUBLICADA_ID,
        vp.pmv_numero AS VERSION_VIGENTE, vp.pmv_fecha_publicacion AS VERSION_DESDE,
        vb.pmv_numero AS VERSION_BORRADOR,
        vr.pmv_numero AS VERSION_RETIRADA, vr.pmv_fecha_retiro AS RETIRO_FECHA, vr.pmv_motivo_retiro AS RETIRO_MOTIVO,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre, N'') + N' ' + ISNULL(ur.usu_apellido_paterno, N''))) AS RETIRO_USUARIO,
        @CAMBIOS AS CAMBIOS,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                                JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
                                JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
                               WHERE v.pmv_plan_mantenimiento = @PLAN) THEN 1 ELSE 0 END AS BIT) AS GENERO,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre, N'') + N' ' + ISNULL(uc.usu_apellido_paterno, N''))) AS CREADO_POR,
        pma.pma_fecha_creacion AS CREADO_EL,
        LTRIM(RTRIM(ISNULL(ua.usu_nombre, N'') + N' ' + ISNULL(ua.usu_apellido_paterno, N''))) AS MODIFICADO_POR,
        pma.pma_fecha_actualizacion AS MODIFICADO_EL
FROM    [dbo].[Plan_Mantenimiento] pma
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = pma.pma_cliente_instalacion
LEFT JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = pma.pma_activo_tipo
LEFT JOIN [dbo].[Activo_Modelo]       amo ON amo.amo_id = pma.pma_activo_modelo
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vp ON vp.pmv_id = @PUB
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vb ON vb.pmv_id = @BOR
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] vr ON vr.pmv_id = @RET
LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = vr.pmv_usuario_actualizacion
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = pma.pma_usuario_creacion
LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = pma.pma_usuario_actualizacion
WHERE   pma.pma_id = @PLAN

/* 1 · intervenciones de la versión de edición */
SELECT  h.pmh_id AS HITO_ID, h.pmh_codigo AS CODIGO, h.pmh_nombre AS NOMBRE, h.pmh_orden AS ORDEN,
        h.pmh_descripcion AS DESCRIPCION, h.pmh_habilitado AS HABILITADO,
        h.pmh_duracion_estimada_minuto AS DURACION, h.pmh_requiere_parada AS PARADA, h.pmh_es_overhaul AS OVERHAUL,
        h.pmh_orden_trabajo_tipo AS OT_TIPO_ID, ott.ott_nombre AS OT_TIPO,
        h.pmh_orden_trabajo_prioridad AS OT_PRIORIDAD_ID, opr.opr_nombre AS OT_PRIORIDAD,
        h.pmh_usuario_responsable AS RESPONSABLE_ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        h.pmh_grupo_trabajo AS GRUPO_ID, gtr.gtr_nombre AS GRUPO,
        g.pro_id AS PROGRAMACION_ID, g.pro_nombre AS PROGRAMACION, g.pro_es_privada AS PRIVADA,
        t.pti_codigo AS TIPO_CODIGO, t.pti_nombre AS TIPO_NOMBRE,
        g.pro_fecha_inicio AS VIGENCIA_DESDE, g.pro_fecha_fin AS VIGENCIA_HASTA,
        g.pro_tolerancia_antes_minuto AS TOL_ANTES, g.pro_tolerancia_despues_minuto AS TOL_DESPUES,
        g.pro_cumplimiento_politica AS POLITICA_ID,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] x WHERE x.pmh_programacion = g.pro_id AND x.pmh_id <> h.pmh_id AND x.pmh_habilitado = 1)
          + (SELECT COUNT(*) FROM [dbo].[Tarea_Programacion] x WHERE x.tpr_programacion = g.pro_id AND x.tpr_habilitado = 1)
          + (SELECT COUNT(*) FROM [dbo].[Checklist_Programacion] x WHERE x.cpr_programacion = g.pro_id AND x.cpr_habilitado = 1) AS OTROS_USOS,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                                JOIN [dbo].[Plan_Mantenimiento_Hito] x ON x.pmh_id = o.pmo_plan_mantenimiento_hito
                                JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = x.pmh_plan_mantenimiento_version
                               WHERE v.pmv_plan_mantenimiento = @PLAN AND (x.pmh_id = h.pmh_id OR x.pmh_codigo = h.pmh_codigo))
             THEN 1 ELSE 0 END AS BIT) AS GENERO
FROM    [dbo].[Plan_Mantenimiento_Hito] h
JOIN    [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
JOIN    [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Tipo] ott ON ott.ott_id = h.pmh_orden_trabajo_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Prioridad] opr ON opr.opr_id = h.pmh_orden_trabajo_prioridad
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = h.pmh_usuario_responsable
LEFT JOIN [dbo].[Grupo_Trabajo] gtr ON gtr.gtr_id = h.pmh_grupo_trabajo
WHERE   h.pmh_plan_mantenimiento_version = @VER
ORDER BY h.pmh_orden, h.pmh_id

SELECT DISTINCT h.pmh_programacion AS pro INTO #pro FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_plan_mantenimiento_version = @VER

/* 2 · calendario (días como lista 1..7, lunes = 1) */
SELECT  c.pca_programacion AS PROGRAMACION_ID, c.pca_frecuencia_tipo AS FRECUENCIA_ID, f.fre_codigo AS FRECUENCIA,
        c.pca_intervalo AS INTERVALO, c.pca_semana_ordinal AS ORDINAL, c.pca_dia_mes AS DIA_MES, c.pca_mes AS MES,
        CONVERT(VARCHAR(5), c.pca_hora_local, 108) AS HORA,
        (SELECT STRING_AGG(CAST(d.pcd_dia_semana AS VARCHAR(2)), ',') FROM [dbo].[Programacion_Calendario_Dia] d WHERE d.pcd_programacion_calendario = c.pca_id) AS DIAS
FROM    [dbo].[Programacion_Calendario] c
JOIN    [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
WHERE   c.pca_programacion IN (SELECT pro FROM #pro) AND c.pca_habilitado = 1

/* 3 · intervalo */
SELECT  i.pin_programacion AS PROGRAMACION_ID, i.pin_cantidad AS CANTIDAD, i.pin_unidad_tiempo AS UNIDAD_ID, u.uti_codigo AS UNIDAD,
        i.pin_fecha_ancla_utc AS ANCLA
FROM    [dbo].[Programacion_Intervalo] i
JOIN    [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
WHERE   i.pin_programacion IN (SELECT pro FROM #pro) AND i.pin_habilitado = 1

/* 4 · medidor */
SELECT  m.pme_programacion AS PROGRAMACION_ID, m.pme_activo_medidor AS MEDIDOR_ID, m.pme_valor_inicial AS VALOR_INICIAL,
        m.pme_cada_cantidad AS CADA, m.pme_aviso_anticipacion AS AVISO
FROM    [dbo].[Programacion_Medidor] m
WHERE   m.pme_programacion IN (SELECT pro FROM #pro) AND m.pme_habilitado = 1

/* 5 · fechas puntuales */
SELECT  f.pfe_id AS ID, f.pfe_programacion AS PROGRAMACION_ID, f.pfe_fecha AS FECHA, CONVERT(VARCHAR(5), f.pfe_hora, 108) AS HORA
FROM    [dbo].[Programacion_Fecha] f
WHERE   f.pfe_programacion IN (SELECT pro FROM #pro) AND f.pfe_incluida = 1
ORDER BY f.pfe_fecha

/* 6 · exclusiones */
SELECT  e.pxc_id AS ID, e.pxc_programacion AS PROGRAMACION_ID,
        e.pxc_fecha_inicio_utc AS DESDE, e.pxc_fecha_fin_utc AS HASTA,
        e.pxc_motivo AS MOTIVO, e.pxc_desplaza AS DESPLAZA
FROM    [dbo].[Programacion_Exclusion] e
WHERE   e.pxc_programacion IN (SELECT pro FROM #pro) AND e.pxc_habilitado = 1
ORDER BY e.pxc_fecha_inicio_utc

/* 7 · condiciones (texto listo para leer) */
SELECT  c.pco_programacion AS PROGRAMACION_ID,
        ISNULL(vme.vme_nombre, N'Variable') + N' ' + ISNULL(op.opc_nombre, N'') + N' ' + CAST(CAST(c.pco_umbral AS DECIMAL(18,2)) AS NVARCHAR(30))
          + ISNULL(N' y ' + CAST(CAST(c.pco_umbral_hasta AS DECIMAL(18,2)) AS NVARCHAR(30)), N'')
          + ISNULL(N' por ' + CAST(c.pco_duracion_minima_minuto AS NVARCHAR(10)) + N' min', N'') AS TEXTO
FROM    [dbo].[Programacion_Condicion] c
LEFT JOIN [dbo].[Activo_Variable] av ON av.ava_id = c.pco_activo_variable
LEFT JOIN [dbo].[Variable_Medicion] vme ON vme.vme_id = av.ava_variable_medicion
LEFT JOIN [dbo].[Operador_Comparacion] op ON op.opc_id = c.pco_operador_comparacion
WHERE   c.pco_programacion IN (SELECT pro FROM #pro) AND c.pco_habilitado = 1

/* 8 · actividades (las dadas de baja no se muestran) */
SELECT  a.paa_id AS ACTIVIDAD_ID, a.paa_plan_mantenimiento_hito AS HITO_ID, a.paa_codigo AS CODIGO, a.paa_nombre AS NOMBRE,
        a.paa_descripcion AS DESCRIPCION, a.paa_orden AS ORDEN, a.paa_duracion_estimada_minuto AS DURACION,
        a.paa_obligatoria AS OBLIGATORIA, a.paa_requiere_parada AS PARADA, a.paa_requiere_permiso AS PERMISO,
        a.paa_permiso_trabajo_tipo AS PERMISO_TIPO_ID, ptt.ptt_nombre AS PERMISO_TIPO,
        a.paa_procedimiento AS PROCEDIMIENTO_ID, prc.prc_codigo AS PROCEDIMIENTO_CODIGO, prc.prc_nombre AS PROCEDIMIENTO,
        prc.prc_version AS PROCEDIMIENTO_VERSION,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] pp WHERE pp.ppa_procedimiento = prc.prc_id AND pp.ppa_habilitado = 1) AS PASOS
FROM    [dbo].[Plan_Mantenimiento_Actividad] a
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
LEFT JOIN [dbo].[Procedimiento] prc ON prc.prc_id = a.paa_procedimiento
LEFT JOIN [dbo].[Permiso_Trabajo_Tipo] ptt ON ptt.ptt_id = a.paa_permiso_trabajo_tipo
WHERE   h.pmh_plan_mantenimiento_version = @VER AND a.paa_habilitado = 1
ORDER BY a.paa_plan_mantenimiento_hito, a.paa_orden, a.paa_id

/* 9 · repuestos planificados */
SELECT  r.pra_id AS ID, r.pra_plan_mantenimiento_actividad AS ACTIVIDAD_ID, r.pra_repuesto AS REPUESTO_ID,
        rep.rep_codigo AS CODIGO, rep.rep_nombre AS NOMBRE, r.pra_cantidad AS CANTIDAD,
        ume.ume_simbolo AS UNIDAD, r.pra_obligatorio AS OBLIGATORIO
FROM    [dbo].[Plan_Actividad_Repuesto] r
JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
JOIN    [dbo].[Repuesto] rep ON rep.rep_id = r.pra_repuesto
LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = r.pra_unidad_medida
WHERE   h.pmh_plan_mantenimiento_version = @VER AND a.paa_habilitado = 1

/* 10 · activos, con su medidor, cobertura y si calzan con el alcance */
SELECT  pac.pac_id AS VINCULO_ID, act.act_id AS ACTIVO_ID, act.act_codigo AS CODIGO, act.act_nombre AS NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA, iar.iar_nombre AS AREA,
        act.act_activo_tipo AS TIPO_ID, ati.ati_nombre AS TIPO, act.act_activo_modelo AS MODELO_ID,
        pac.pac_activo_componente AS COMPONENTE_ID, aco.aco_nombre AS COMPONENTE,
        med.ame_id AS MEDIDOR_ID, med.ame_nombre AS MEDIDOR, med.ame_valor_actual AS MEDIDOR_VALOR, ume.ume_simbolo AS MEDIDOR_UNIDAD,
        (SELECT STRING_AGG(x.pma_codigo, N', ') FROM (
             SELECT DISTINCT p2.pma_codigo FROM [dbo].[Plan_Mantenimiento_Activo] a2
             JOIN [dbo].[Plan_Mantenimiento_Version] v2 ON v2.pmv_id = a2.pac_plan_mantenimiento_version AND v2.pmv_plan_version_estado = 2
             JOIN [dbo].[Plan_Mantenimiento] p2 ON p2.pma_id = v2.pmv_plan_mantenimiento AND p2.pma_habilitado = 1
             WHERE a2.pac_activo = act.act_id AND p2.pma_id <> @PLAN) x) AS OTROS_PLANES,
        CASE WHEN act.act_habilitado = 0 OR act.act_fecha_baja IS NOT NULL THEN N'Dado de baja'
             WHEN pma.pma_cliente_instalacion IS NOT NULL AND act.act_cliente_instalacion <> pma.pma_cliente_instalacion THEN N'Otra planta'
             WHEN pma.pma_activo_tipo IS NOT NULL AND ISNULL(act.act_activo_tipo, 0) <> pma.pma_activo_tipo THEN N'Otro tipo'
             WHEN pma.pma_activo_modelo IS NOT NULL AND ISNULL(act.act_activo_modelo, 0) <> pma.pma_activo_modelo THEN N'Otro modelo'
             ELSE NULL END AS FUERA_ALCANCE
FROM    [dbo].[Plan_Mantenimiento_Activo] pac
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pac.pac_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo] act ON act.act_id = pac.pac_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Tipo] ati ON ati.ati_id = act.act_activo_tipo
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = pac.pac_activo_componente
OUTER APPLY (SELECT TOP 1 m.ame_id, m.ame_nombre, m.ame_valor_actual, m.ame_unidad_medida FROM [dbo].[Activo_Medidor] m
              WHERE m.ame_activo = act.act_id AND m.ame_habilitado = 1
              ORDER BY CASE WHEN m.ame_id = pac.pac_activo_medidor THEN 0 ELSE 1 END, m.ame_id) med
LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = med.ame_unidad_medida
WHERE   pac.pac_plan_mantenimiento_version = @VER
ORDER BY act.act_codigo

/* 11 · próximas ejecuciones (las 10 siguientes, de cualquier versión) */
SELECT TOP 10
        o.pmo_id AS OCURRENCIA_ID, o.pmo_fecha_programada_utc AS FECHA,
        o.pmo_fecha_limite_utc AS LIMITE,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO,
        CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 'VENCIDA'
             WHEN o.pmo_fecha_programada_utc < @UTC THEN 'ATRASADA'
             WHEN o.pmo_fecha_disponible_utc IS NOT NULL AND o.pmo_fecha_disponible_utc <= @UTC THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        o.pmo_orden_trabajo AS OT_ID, ot.otr_correlativo AS OT_NUMERO, ot.otr_orden_trabajo_estado AS OT_ESTADO_ID
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Activo] act ON act.act_id = o.pmo_activo
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE   v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2, 3)
ORDER BY CASE WHEN o.pmo_fecha_limite_utc IS NOT NULL AND o.pmo_fecha_limite_utc < @UTC THEN 0
              WHEN o.pmo_fecha_programada_utc < @UTC THEN 1 ELSE 2 END,
         o.pmo_fecha_programada_utc

/* 12 · OT generadas por el plan */
SELECT TOP 100
        ot.otr_id AS OT_ID, ot.otr_correlativo AS NUMERO, ot.otr_titulo AS TITULO,
        ot.otr_orden_trabajo_estado AS ESTADO_ID, ote.ote_codigo AS ESTADO_CODIGO, ote.ote_nombre AS ESTADO,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_nombre AS HITO,
        ot.otr_fecha_programada_utc AS FECHA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    [dbo].[Orden_Trabajo] ot
JOIN    [dbo].[Plan_Mantenimiento_Ocurrencia] o ON o.pmo_id = ot.otr_plan_mantenimiento_ocurrencia
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Activo] act ON act.act_id = ot.otr_activo
LEFT JOIN [dbo].[Orden_Trabajo_Estado] ote ON ote.ote_id = ot.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo_Asignacion] ota ON ota.ota_orden_trabajo = ot.otr_id AND ota.ota_es_responsable = 1 AND ota.ota_habilitado = 1
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = ota.ota_usuario
WHERE   v.pmv_plan_mantenimiento = @PLAN AND ot.otr_habilitado = 1
ORDER BY ot.otr_fecha_creacion DESC

/* 13 · versiones */
SELECT  v.pmv_id AS VERSION_ID, v.pmv_numero AS NUMERO, pve.pve_codigo AS ESTADO_CODIGO, pve.pve_nombre AS ESTADO,
        v.pmv_fecha_publicacion AS PUBLICADA, LTRIM(RTRIM(ISNULL(up.usu_nombre, N'') + N' ' + ISNULL(up.usu_apellido_paterno, N''))) AS PUBLICADA_POR,
        v.pmv_fecha_retiro AS RETIRADA, v.pmv_motivo_retiro AS MOTIVO_RETIRO, v.pmv_observacion AS OBSERVACION,
        v.pmv_fecha_creacion AS CREADA, LTRIM(RTRIM(ISNULL(uc.usu_nombre, N'') + N' ' + ISNULL(uc.usu_apellido_paterno, N''))) AS CREADA_POR,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_plan_mantenimiento_version = v.pmv_id AND h.pmh_habilitado = 1) AS INTERVENCIONES,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = v.pmv_id) AS ACTIVOS,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          WHERE h.pmh_plan_mantenimiento_version = v.pmv_id) AS EJECUCIONES
FROM    [dbo].[Plan_Mantenimiento_Version] v
JOIN    [dbo].[Plan_Version_Estado] pve ON pve.pve_id = v.pmv_plan_version_estado
LEFT JOIN [dbo].[Usuario] up ON up.usu_id = v.pmv_usuario_publicacion
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = v.pmv_usuario_creacion
WHERE   v.pmv_plan_mantenimiento = @PLAN AND v.pmv_habilitado = 1
ORDER BY v.pmv_numero DESC

/* 14 · proyección de la versión de edición (10 primeras fechas × activo) */
SELECT TOP 10 f.FECHA, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, h.pmh_codigo AS HITO_CODIGO, h.pmh_nombre AS HITO
FROM    [dbo].[Plan_Mantenimiento_Hito] h
JOIN    [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Activo] act ON act.act_id = a.pac_activo
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @HOY, DATEADD(DAY, 400, @HOY)) f
WHERE   h.pmh_plan_mantenimiento_version = @VER AND h.pmh_habilitado = 1 AND f.DESCARTADA = 0
ORDER BY f.FECHA, act.act_codigo

/* 15 · próximas fechas de cada intervención (cabecera y vista previa) */
SELECT  x.HITO_ID, x.FECHA, x.FECHA_ORIGINAL, x.DESPLAZADA, x.DESCARTADA, x.MOTIVO
FROM (
    SELECT h.pmh_id AS HITO_ID, f.FECHA, f.FECHA_ORIGINAL, f.DESPLAZADA, f.DESCARTADA, f.MOTIVO,
           ROW_NUMBER() OVER (PARTITION BY h.pmh_id ORDER BY f.FECHA) AS rn
    FROM   [dbo].[Plan_Mantenimiento_Hito] h
    CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @HOY, DATEADD(DAY, 800, @HOY)) f
    WHERE  h.pmh_plan_mantenimiento_version = @VER
) x
WHERE x.rn <= 10
ORDER BY x.HITO_ID, x.FECHA

RETURN(0)
GO

/* ========================================================================
   8. UPS_PLAN_HITO_FRECUENCIA (§26.2 · RP-01, RP-03, RP-19)
      La cabecera de la frecuencia de UNA intervención del borrador. El
      detalle (calendario, intervalo, medidor, fechas, exclusiones) lo
      escriben después los SP de siempre sobre la programación que devuelve.
      COPIA AL ESCRIBIR: si la programación la usa otro hito (la versión
      publicada, otra intervención), una tarea, una pauta, o es compartida,
      se copia como privada y el hito pasa a apuntar la copia. La versión
      activa nunca cambia de calendario sin «Aplicar cambios».
      @COMPARTIDA: «Usar calendario compartido» (solo lectura en el Centro).
      @COPIAR = 1: «Convertir en propia».
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_HITO_FRECUENCIA]
    @PROGRAMACION  INT = NULL OUTPUT,
    @CLIENTE       INT,
    @HITO          INT,
    @TIPO_CODIGO   NVARCHAR(30) = NULL,
    @FECHA_INICIO  DATE = NULL,
    @FECHA_FIN     DATE = NULL,
    @QUITA_FIN     BIT = 0,
    @TOL_ANTES     INT = NULL,
    @TOL_DESPUES   INT = NULL,
    @POLITICA      INT = NULL,
    @COMPARTIDA    INT = NULL,
    @COPIAR        BIT = 0,
    @USUARIO       INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @ESTADO INT, @P INT, @PLAN_COD NVARCHAR(100), @HITO_COD NVARCHAR(100)

SELECT  @ESTADO = v.pmv_plan_version_estado, @P = h.pmh_programacion, @PLAN_COD = p.pma_codigo, @HITO_COD = h.pmh_codigo
FROM    [dbo].[Plan_Mantenimiento_Hito] h
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
WHERE   h.pmh_id = @HITO AND p.pma_cliente = @CLIENTE

IF @P IS NULL
BEGIN
    RAISERROR('1.- LA INTERVENCIÓN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ESTADO <> 1
BEGIN
    RAISERROR('2.- LA INTERVENCIÓN NO ESTÁ EN UN BORRADOR: EDITE EL PLAN PARA ABRIR LOS CAMBIOS.', 16, 1)
    RETURN -1
END

/* ---- Usar un calendario compartido ---- */
IF @COMPARTIDA IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @COMPARTIDA AND pro_cliente = @CLIENTE AND pro_habilitado = 1 AND pro_es_privada = 0)
    BEGIN
        RAISERROR('3.- EL CALENDARIO COMPARTIDO NO EXISTE O NO ESTÁ DISPONIBLE.', 16, 1)
        RETURN -1
    END
    UPDATE [dbo].[Plan_Mantenimiento_Hito]
       SET pmh_programacion = @COMPARTIDA, pmh_usuario_actualizacion = @USUARIO, pmh_fecha_actualizacion = @AHORA
     WHERE pmh_id = @HITO
    SET @PROGRAMACION = @COMPARTIDA
    SELECT @PROGRAMACION AS PROGRAMACION, CAST(0 AS BIT) AS COPIADA
    RETURN 0
END

DECLARE @TIPO INT = NULL, @TIPO_ACTUAL NVARCHAR(30)
IF @TIPO_CODIGO IS NOT NULL
BEGIN
    SELECT @TIPO = pti_id FROM [dbo].[Programacion_Tipo] WHERE pti_codigo = @TIPO_CODIGO AND pti_habilitado = 1
    IF @TIPO IS NULL
    BEGIN
        RAISERROR('4.- EL TIPO DE FRECUENCIA NO EXISTE.', 16, 1)
        RETURN -1
    END
END

IF (ISNULL(@TOL_ANTES, 0) < 0 OR ISNULL(@TOL_DESPUES, 0) < 0)
BEGIN
    RAISERROR('5.- LAS TOLERANCIAS NO PUEDEN SER NEGATIVAS.', 16, 1)
    RETURN -1
END

/* ---- Copia al escribir ---- */
DECLARE @COPIADA BIT = 0
IF @COPIAR = 1
   OR NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @P AND pro_es_privada = 1)
   OR EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_programacion = @P AND pmh_id <> @HITO)
   OR EXISTS (SELECT 1 FROM [dbo].[Tarea_Programacion] WHERE tpr_programacion = @P)
   OR EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] WHERE cpr_programacion = @P)
BEGIN
    DECLARE @NUEVA INT, @NOMBRE NVARCHAR(400) = @PLAN_COD + N' · ' + @HITO_COD, @R INT
    EXEC @R = [dbo].[INS_PROGRAMACION_COPIA] @ID = @NUEVA OUTPUT, @CLIENTE = @CLIENTE, @ORIGEN = @P, @NOMBRE = @NOMBRE, @USUARIO = @USUARIO
    IF @R <> 0 OR @NUEVA IS NULL RETURN -1
    UPDATE [dbo].[Plan_Mantenimiento_Hito]
       SET pmh_programacion = @NUEVA, pmh_usuario_actualizacion = @USUARIO, pmh_fecha_actualizacion = @AHORA
     WHERE pmh_id = @HITO
    SET @P = @NUEVA
    SET @COPIADA = 1
END

SELECT @TIPO_ACTUAL = t.pti_codigo FROM [dbo].[Programacion] g JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo WHERE g.pro_id = @P

IF (ISNULL(@TIPO_CODIGO, @TIPO_ACTUAL) = 'CONDICION'
    AND @POLITICA IS NULL AND (SELECT pro_cumplimiento_politica FROM [dbo].[Programacion] WHERE pro_id = @P) IS NULL)
    SET @POLITICA = (SELECT TOP 1 cpo_id FROM [dbo].[Cumplimiento_Politica] WHERE cpo_codigo = 'UNO')

DECLARE @INI DATE = ISNULL(@FECHA_INICIO, (SELECT pro_fecha_inicio FROM [dbo].[Programacion] WHERE pro_id = @P))
DECLARE @FIN DATE = CASE WHEN @QUITA_FIN = 1 THEN NULL ELSE ISNULL(@FECHA_FIN, (SELECT pro_fecha_fin FROM [dbo].[Programacion] WHERE pro_id = @P)) END
IF (@FIN IS NOT NULL AND @FIN < @INI)
BEGIN
    RAISERROR('6.- LA VIGENCIA NO PUEDE TERMINAR ANTES DE EMPEZAR.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion]
       SET pro_programacion_tipo         = ISNULL(@TIPO, pro_programacion_tipo),
           pro_fecha_inicio              = @INI,
           pro_fecha_fin                 = @FIN,
           pro_tolerancia_antes_minuto   = ISNULL(@TOL_ANTES, pro_tolerancia_antes_minuto),
           pro_tolerancia_despues_minuto = ISNULL(@TOL_DESPUES, pro_tolerancia_despues_minuto),
           pro_cumplimiento_politica     = ISNULL(@POLITICA, pro_cumplimiento_politica),
           pro_genera_automaticamente    = 1,
           pro_usuario_actualizacion     = @USUARIO,
           pro_fecha_actualizacion       = @AHORA
     WHERE pro_id = @P

    /* Cambió el tipo: el detalle del tipo anterior deja de aplicar. Las
       exclusiones son comunes a todos los tipos y se conservan. */
    IF @TIPO_CODIGO IS NOT NULL AND @TIPO_CODIGO <> ISNULL(@TIPO_ACTUAL, N'')
    BEGIN
        UPDATE [dbo].[Programacion_Calendario] SET pca_habilitado = 0, pca_usuario_actualizacion = @USUARIO, pca_fecha_actualizacion = @AHORA WHERE pca_programacion = @P AND pca_habilitado = 1
        UPDATE [dbo].[Programacion_Intervalo]  SET pin_habilitado = 0, pin_usuario_actualizacion = @USUARIO, pin_fecha_actualizacion = @AHORA WHERE pin_programacion = @P AND pin_habilitado = 1
        UPDATE [dbo].[Programacion_Medidor]    SET pme_habilitado = 0, pme_usuario_actualizacion = @USUARIO, pme_fecha_actualizacion = @AHORA WHERE pme_programacion = @P AND pme_habilitado = 1
        UPDATE [dbo].[Programacion_Condicion]  SET pco_habilitado = 0, pco_usuario_actualizacion = @USUARIO, pco_fecha_actualizacion = @AHORA WHERE pco_programacion = @P AND pco_habilitado = 1
        DELETE FROM [dbo].[Programacion_Fecha] WHERE pfe_programacion = @P
    END

    UPDATE [dbo].[Plan_Mantenimiento_Hito]
       SET pmh_usuario_actualizacion = @USUARIO, pmh_fecha_actualizacion = @AHORA
     WHERE pmh_id = @HITO

COMMIT TRANSACTION

SET @PROGRAMACION = @P
SELECT @PROGRAMACION AS PROGRAMACION, @COPIADA AS COPIADA
RETURN(0)
GO

/* ========================================================================
   9. SEL_PLAN_IMPACTO (§26.2)
      Los conteos de la confirmación, sin escribir nada:
       Activar / Aplicar cambios (RP-05, RP-07): traspasan, se reabren,
       se cancelan, se crean, con OT. Desactivar (RP-08): se cancelan.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_IMPACTO]
    @CLIENTE   INT,
    @PLAN      INT,
    @HORIZONTE INT = 90
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @HOY DATETIME = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME)
DECLARE @D INT = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)
IF @HORIZONTE IS NULL OR @HORIZONTE < 1 SET @HORIZONTE = 90

/* Las candidatas: futuras sin OT de otras versiones del plan, abiertas o
   canceladas por el sistema (reemplazo o desactivación). */
SELECT  o.pmo_id, o.pmo_plan_ocurrencia_estado AS estado, o.pmo_programacion, o.pmo_activo, o.pmo_activo_componente,
        CASE WHEN o.pmo_plan_ocurrencia_estado = 6 THEN 1 ELSE 0 END AS cancelada,
        (SELECT TOP 1 h2.pmh_id FROM [dbo].[Plan_Mantenimiento_Hito] h2
          WHERE h2.pmh_plan_mantenimiento_version = @D AND h2.pmh_habilitado = 1 AND h2.pmh_programacion = o.pmo_programacion
            AND EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = @D
                         AND a.pac_activo = o.pmo_activo AND ISNULL(a.pac_activo_componente, 0) = ISNULL(o.pmo_activo_componente, 0))
          ORDER BY CASE WHEN h2.pmh_codigo = h.pmh_codigo THEN 0 ELSE 1 END) AS destino
INTO    #c
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
WHERE   v.pmv_plan_mantenimiento = @PLAN AND v.pmv_id <> ISNULL(@D, 0)
  AND   o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NULL AND o.pmo_fecha_programada_utc >= @HOY
  AND   (o.pmo_plan_ocurrencia_estado IN (1, 2)
         OR (o.pmo_plan_ocurrencia_estado = 6 AND EXISTS (
                SELECT 1 FROM [dbo].[Plan_Ocurrencia_Historial] x
                 WHERE x.poh_plan_mantenimiento_ocurrencia = o.pmo_id AND x.poh_estado_nuevo = 6
                   AND (x.poh_motivo LIKE N'Reemplazada por la versión%' OR x.poh_motivo LIKE N'Plan desactivado%'))))

/* Lo que generaría la versión de edición en el horizonte y aún no existe. */
DECLARE @CREAN INT = 0, @PRIMERA DATETIME = NULL
IF @D IS NOT NULL
    SELECT @CREAN = COUNT(*), @PRIMERA = MIN(f.FECHA)
    FROM   [dbo].[Plan_Mantenimiento_Hito] h
    JOIN   [dbo].[Programacion] p ON p.pro_id = h.pmh_programacion AND p.pro_habilitado = 1
    JOIN   [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
    JOIN   [dbo].[Activo] act ON act.act_id = a.pac_activo AND act.act_habilitado = 1
    CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion,
                CAST([dbo].[FNC_INSTALACION_HORA](act.act_cliente_instalacion) AS DATE),
                DATEADD(DAY, @HORIZONTE, CAST([dbo].[FNC_INSTALACION_HORA](act.act_cliente_instalacion) AS DATE))) f
    WHERE  h.pmh_plan_mantenimiento_version = @D AND h.pmh_habilitado = 1 AND f.DESCARTADA = 0
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                        WHERE o.pmo_programacion = h.pmh_programacion AND o.pmo_activo = a.pac_activo AND o.pmo_fecha_programada_utc = f.FECHA)

SELECT  ISNULL(SUM(CASE WHEN destino IS NOT NULL AND cancelada = 0 THEN 1 ELSE 0 END), 0) AS TRASPASAN,
        ISNULL(SUM(CASE WHEN destino IS NOT NULL AND cancelada = 1 THEN 1 ELSE 0 END), 0) AS REABREN,
        ISNULL(SUM(CASE WHEN destino IS NULL AND cancelada = 0 THEN 1 ELSE 0 END), 0) AS CANCELAN,
        @CREAN AS CREAN,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
          JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
         WHERE v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NOT NULL
           AND o.pmo_plan_ocurrencia_estado = 3) AS CON_OT,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
          JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
         WHERE v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NULL
           AND o.pmo_plan_ocurrencia_estado IN (1, 2) AND o.pmo_fecha_programada_utc >= @HOY) AS DESACTIVAR_CANCELAN,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = @D) AS ACTIVOS,
        CAST([dbo].[FNC_AHORA]() AS DATE) AS DESDE,
        DATEADD(DAY, @HORIZONTE, CAST([dbo].[FNC_AHORA]() AS DATE)) AS HASTA,
        @PRIMERA AS PRIMERA
FROM    #c

RETURN(0)
GO

/* ========================================================================
   10. UPD_PLAN_ACTIVAR (§26.2 · RP-05, RP-07)
       Activar un borrador o aplicar los cambios de un plan activo:
        a) valida los bloqueantes de «Listo para activar»;
        b) publica (UPD_PLAN_VERSION_PUBLICAR, que retira la anterior);
        c) TRASPASA a la versión nueva las futuras sin OT que conservan
           programación y activo (y reabre las que el sistema canceló),
           CANCELA las demás;
        d) genera el horizonte (GEN_PLAN_OCURRENCIAS).
       El traspaso no es optativo: UX_PMO_PROGRAMACION_ACTIVO_FECHA no deja
       regenerar una fecha cancelada con la misma programación.
       Si la generación falla, el plan queda publicado y el error vuelve en
       ERROR_GENERACION (la ficha ofrece «Reintentar»).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_ACTIVAR]
    @CLIENTE     INT,
    @PLAN        INT,
    @OBSERVACION NVARCHAR(1000) = NULL,
    @HORIZONTE   INT = 90,
    @SOLO_GENERAR BIT = 0,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATETIME = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME)
DECLARE @HAB BIT, @D INT, @NUM INT, @R INT, @GEN INT = 0, @ERR NVARCHAR(4000) = NULL
DECLARE @TRASPASADAS INT = 0, @REABIERTAS INT = 0, @CANCELADAS INT = 0

IF @HORIZONTE IS NULL OR @HORIZONTE < 1 SET @HORIZONTE = 90

SELECT @HAB = pma_habilitado FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE
IF @HAB IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @HAB = 0
BEGIN
    RAISERROR('2.- EL PLAN ESTÁ INACTIVO: REACTÍVELO PARA VOLVER A GENERAR.', 16, 1)
    RETURN -1
END

/* «Reintentar»: solo la generación, sobre lo ya publicado. */
IF @SOLO_GENERAR = 0
BEGIN
    SELECT TOP 1 @D = pmv_id, @NUM = pmv_numero FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC

    IF @D IS NULL
    BEGIN
        RAISERROR('3.- EL PLAN NO TIENE CAMBIOS QUE APLICAR.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @D)
    BEGIN
        RAISERROR('4.- LA PLANIFICACIÓN NECESITA AL MENOS UN ACTIVO.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @D AND pmh_habilitado = 1)
    BEGIN
        RAISERROR('5.- LA PLANIFICACIÓN NECESITA AL MENOS UNA INTERVENCIÓN HABILITADA.', 16, 1)
        RETURN -1
    END

    DECLARE @SIN NVARCHAR(400) = (SELECT TOP 1 h.pmh_nombre FROM [dbo].[Plan_Mantenimiento_Hito] h
                                   JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
                                   JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = g.pro_programacion_tipo
                                  WHERE h.pmh_plan_mantenimiento_version = @D AND h.pmh_habilitado = 1 AND t.pti_codigo = 'ABIERTA'
                                  ORDER BY h.pmh_orden)
    IF @SIN IS NOT NULL
    BEGIN
        RAISERROR('6.- LA INTERVENCIÓN "%s" NECESITA UNA FRECUENCIA PARA PODER ACTIVARSE.', 16, 1, @SIN)
        RETURN -1
    END

    DECLARE @ACT NVARCHAR(400) = (SELECT TOP 1 a.paa_nombre FROM [dbo].[Plan_Mantenimiento_Actividad] a
                                   JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
                                  WHERE h.pmh_plan_mantenimiento_version = @D AND a.paa_habilitado = 1
                                    AND a.paa_requiere_permiso = 1 AND a.paa_permiso_trabajo_tipo IS NULL)
    IF @ACT IS NOT NULL
    BEGIN
        RAISERROR('7.- INDIQUE EL TIPO DE PERMISO DE LA ACTIVIDAD "%s": LA OT LO EXIGIRÁ ANTES DE EMPEZAR.', 16, 1, @ACT)
        RETURN -1
    END

    /* b) publicar */
    EXEC @R = [dbo].[UPD_PLAN_VERSION_PUBLICAR] @ID = @D, @CLIENTE = @CLIENTE, @OBSERVACION = @OBSERVACION, @USUARIO = @USUARIO
    IF ISNULL(@R, -1) <> 0 RETURN -1

    /* c) traspasar, reabrir, cancelar */
    SELECT  o.pmo_id, o.pmo_plan_ocurrencia_estado AS estado,
            (SELECT TOP 1 h2.pmh_id FROM [dbo].[Plan_Mantenimiento_Hito] h2
              WHERE h2.pmh_plan_mantenimiento_version = @D AND h2.pmh_habilitado = 1 AND h2.pmh_programacion = o.pmo_programacion
                AND EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a WHERE a.pac_plan_mantenimiento_version = @D
                             AND a.pac_activo = o.pmo_activo AND ISNULL(a.pac_activo_componente, 0) = ISNULL(o.pmo_activo_componente, 0))
              ORDER BY CASE WHEN h2.pmh_codigo = h.pmh_codigo THEN 0 ELSE 1 END) AS destino
    INTO    #c
    FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
    JOIN    [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
    JOIN    [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
    WHERE   v.pmv_plan_mantenimiento = @PLAN AND v.pmv_id <> @D
      AND   o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NULL AND o.pmo_fecha_programada_utc >= @HOY
      AND   (o.pmo_plan_ocurrencia_estado IN (1, 2)
             OR (o.pmo_plan_ocurrencia_estado = 6 AND EXISTS (
                    SELECT 1 FROM [dbo].[Plan_Ocurrencia_Historial] x
                     WHERE x.poh_plan_mantenimiento_ocurrencia = o.pmo_id AND x.poh_estado_nuevo = 6
                       AND (x.poh_motivo LIKE N'Reemplazada por la versión%' OR x.poh_motivo LIKE N'Plan desactivado%'))))

    SELECT @TRASPASADAS = SUM(CASE WHEN destino IS NOT NULL AND estado <> 6 THEN 1 ELSE 0 END),
           @REABIERTAS  = SUM(CASE WHEN destino IS NOT NULL AND estado = 6 THEN 1 ELSE 0 END),
           @CANCELADAS  = SUM(CASE WHEN destino IS NULL AND estado <> 6 THEN 1 ELSE 0 END)
    FROM   #c

    BEGIN TRY
        BEGIN TRANSACTION

        INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
            (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
        SELECT c.pmo_id, c.estado,
               CASE WHEN c.destino IS NULL THEN 6 WHEN c.estado = 6 THEN 1 ELSE c.estado END,
               CASE WHEN c.destino IS NULL THEN N'Reemplazada por la versión ' + CAST(@NUM AS NVARCHAR(10))
                    WHEN c.estado = 6 THEN N'Reabierta en la versión ' + CAST(@NUM AS NVARCHAR(10))
                    ELSE N'Pasa a la versión ' + CAST(@NUM AS NVARCHAR(10)) END,
               @USUARIO, @AHORA
        FROM   #c c
        WHERE  NOT (c.destino IS NULL AND c.estado = 6)

        UPDATE o
           SET pmo_plan_mantenimiento_hito = c.destino,
               pmo_plan_ocurrencia_estado  = CASE WHEN c.estado = 6 THEN 1 ELSE c.estado END,
               pmo_usuario_actualizacion   = @USUARIO,
               pmo_fecha_actualizacion     = @AHORA
        FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN #c c ON c.pmo_id = o.pmo_id
        WHERE  c.destino IS NOT NULL

        UPDATE o
           SET pmo_plan_ocurrencia_estado = 6,
               pmo_usuario_actualizacion  = @USUARIO,
               pmo_fecha_actualizacion    = @AHORA
        FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN #c c ON c.pmo_id = o.pmo_id
        WHERE  c.destino IS NULL AND c.estado <> 6

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        SET @ERR = ERROR_MESSAGE()
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_PLAN_ACTIVAR traspaso', @MSG = @ERR
    END CATCH
END

/* d) generar el horizonte */
BEGIN TRY
    EXEC [dbo].[GEN_PLAN_OCURRENCIAS] @CLIENTE = @CLIENTE, @PLAN = @PLAN, @HORIZONTE_DIA = @HORIZONTE,
         @SOLO_AUTOMATICAS = 0, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT
END TRY
BEGIN CATCH
    SET @ERR = ISNULL(@ERR + N' ', N'') + ERROR_MESSAGE()
END CATCH

SELECT  ISNULL(@NUM, (SELECT TOP 1 pmv_numero FROM [dbo].[Plan_Mantenimiento_Version]
                      WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 2 ORDER BY pmv_numero DESC)) AS VERSION,
        ISNULL(@TRASPASADAS, 0) AS TRASPASADAS,
        ISNULL(@REABIERTAS, 0)  AS REABIERTAS,
        ISNULL(@CANCELADAS, 0)  AS CANCELADAS,
        ISNULL(@GEN, 0)         AS GENERADAS,
        (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
          JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
          JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
         WHERE v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado IN (1, 2)
           AND o.pmo_fecha_programada_utc >= @HOY) AS EJECUCIONES_FUTURAS,
        @ERR AS ERROR_GENERACION

RETURN(0)
GO

/* ========================================================================
   11. DEL_PLAN_VERSION_BORRADOR (§26.2 · RP-04)
       «Descartar cambios»: elimina el borrador de un plan que tiene otra
       versión. El borrador nunca generó nada: se borra físicamente, y sus
       frecuencias privadas que ya nadie usa se deshabilitan.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_VERSION_BORRADOR]
    @CLIENTE INT,
    @PLAN    INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @D INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT TOP 1 @D = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC

IF @D IS NULL
BEGIN
    RAISERROR('2.- EL PLAN NO TIENE CAMBIOS SIN APLICAR.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version]
                WHERE pmv_plan_mantenimiento = @PLAN AND pmv_id <> @D AND pmv_plan_version_estado IN (2, 3) AND pmv_habilitado = 1)
BEGIN
    RAISERROR('3.- EL PLAN NO TIENE OTRA VERSIÓN: ELIMÍNELO EN VEZ DE DESCARTAR LOS CAMBIOS.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
            WHERE h.pmh_plan_mantenimiento_version = @D)
BEGIN
    RAISERROR('4.- EL BORRADOR YA TIENE EJECUCIONES Y NO SE PUEDE DESCARTAR.', 16, 1)
    RETURN -1
END

DECLARE @PROS TABLE (pro INT)
INSERT @PROS SELECT DISTINCT pmh_programacion FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @D

BEGIN TRANSACTION
    DELETE r FROM [dbo].[Plan_Actividad_Repuesto] r
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE x FROM [dbo].[Plan_Actividad_Checklist] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pck_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE x FROM [dbo].[Plan_Actividad_Especialidad] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pae_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE a FROM [dbo].[Plan_Mantenimiento_Actividad] a
      JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
     WHERE h.pmh_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Hito]   WHERE pmh_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @D
    DELETE FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @D

    UPDATE g SET pro_habilitado = 0, pro_usuario_actualizacion = @USUARIO, pro_fecha_actualizacion = [dbo].[FNC_AHORA]()
    FROM   [dbo].[Programacion] g JOIN @PROS p ON p.pro = g.pro_id
    WHERE  g.pro_es_privada = 1
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_programacion = g.pro_id)
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o WHERE o.pmo_programacion = g.pro_id)
COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   12. DEL_PLAN_HITO_BORRADOR
       Quitar una intervención del borrador. Se borra físicamente (con sus
       actividades y repuestos) porque en el borrador nunca generó: la baja
       lógica de DEL_PLAN_HITO la dejaría como «inactiva», que en el Centro
       significa otra cosa (el interruptor Habilitada).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_HITO_BORRADOR]
    @CLIENTE INT,
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @ESTADO INT, @PRO INT

SELECT @ESTADO = v.pmv_plan_version_estado, @PRO = h.pmh_programacion
FROM   [dbo].[Plan_Mantenimiento_Hito] h
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
WHERE  h.pmh_id = @ID AND p.pma_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA INTERVENCIÓN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ESTADO <> 1
BEGIN
    RAISERROR('2.- LA INTERVENCIÓN NO ESTÁ EN UN BORRADOR.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_plan_mantenimiento_hito = @ID)
BEGIN
    RAISERROR('3.- LA INTERVENCIÓN YA GENERÓ EJECUCIONES: DESHABILÍTELA EN VEZ DE QUITARLA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    DELETE r FROM [dbo].[Plan_Actividad_Repuesto] r
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    DELETE x FROM [dbo].[Plan_Actividad_Checklist] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pck_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    DELETE x FROM [dbo].[Plan_Actividad_Especialidad] x
      JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = x.pae_plan_mantenimiento_actividad
     WHERE a.paa_plan_mantenimiento_hito = @ID
    IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso] s JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = s.otp_plan_mantenimiento_actividad
                WHERE a.paa_plan_mantenimiento_hito = @ID)
        UPDATE [dbo].[Plan_Mantenimiento_Actividad] SET paa_habilitado = 0 WHERE paa_plan_mantenimiento_hito = @ID
    ELSE
        DELETE FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @ID

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @ID)
        UPDATE [dbo].[Plan_Mantenimiento_Hito] SET pmh_habilitado = 0, pmh_usuario_actualizacion = @USUARIO, pmh_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE pmh_id = @ID
    ELSE
        DELETE FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @ID

    UPDATE [dbo].[Programacion] SET pro_habilitado = 0, pro_usuario_actualizacion = @USUARIO, pro_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE pro_id = @PRO AND pro_es_privada = 1
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h WHERE h.pmh_programacion = @PRO AND h.pmh_habilitado = 1)
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o WHERE o.pmo_programacion = @PRO)
COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   13. UPD_PLAN_DESACTIVAR (§26.2 · RP-08)
       Motivo obligatorio. Descarta el borrador si hay, retira la versión
       publicada con el motivo, deja el plan inactivo y cancela las futuras
       sin OT (las que tienen OT siguen su curso).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_DESACTIVAR]
    @CLIENTE INT,
    @PLAN    INT,
    @MOTIVO  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATETIME = CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME)
DECLARE @PUB INT, @R INT, @CANCELADAS INT = 0

SET @MOTIVO = LTRIM(RTRIM(@MOTIVO))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@MOTIVO IS NULL OR LEN(@MOTIVO) < 5)
BEGIN
    RAISERROR('2.- INDIQUE EL MOTIVO DE LA DESACTIVACIÓN (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END

SELECT TOP 1 @PUB = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 2 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC

IF @PUB IS NULL
BEGIN
    RAISERROR('3.- EL PLAN NO ESTÁ ACTIVO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1)
BEGIN
    EXEC @R = [dbo].[DEL_PLAN_VERSION_BORRADOR] @CLIENTE = @CLIENTE, @PLAN = @PLAN, @USUARIO = @USUARIO
    IF ISNULL(@R, -1) <> 0 RETURN -1
END

DECLARE @C TABLE (pmo INT, estado INT)
INSERT @C
SELECT o.pmo_id, o.pmo_plan_ocurrencia_estado
FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
WHERE  v.pmv_plan_mantenimiento = @PLAN AND o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NULL
  AND  o.pmo_plan_ocurrencia_estado IN (1, 2) AND o.pmo_fecha_programada_utc >= @HOY
SET @CANCELADAS = @@ROWCOUNT

BEGIN TRANSACTION
    UPDATE [dbo].[Plan_Mantenimiento_Version]
       SET pmv_plan_version_estado = 3, pmv_fecha_retiro = @AHORA, pmv_motivo_retiro = @MOTIVO,
           pmv_usuario_actualizacion = @USUARIO, pmv_fecha_actualizacion = @AHORA
     WHERE pmv_id = @PUB

    UPDATE [dbo].[Plan_Mantenimiento]
       SET pma_habilitado = 0, pma_usuario_actualizacion = @USUARIO, pma_fecha_actualizacion = @AHORA
     WHERE pma_id = @PLAN

    INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
        (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
    SELECT pmo, estado, 6, LEFT(N'Plan desactivado: ' + @MOTIVO, 400), @USUARIO, @AHORA FROM @C

    UPDATE o SET pmo_plan_ocurrencia_estado = 6, pmo_usuario_actualizacion = @USUARIO, pmo_fecha_actualizacion = @AHORA
    FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN @C c ON c.pmo = o.pmo_id
COMMIT TRANSACTION

SELECT @CANCELADAS AS CANCELADAS
RETURN(0)
GO

/* ========================================================================
   14. UPD_PLAN_REACTIVAR (§26.2 · RP-08)
       Abre un borrador copiado de la última versión y lo activa: las futuras
       que canceló la desactivación vuelven a PENDIENTE (UPD_PLAN_ACTIVAR las
       reabre por su historial) y se genera lo que falte.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_REACTIVAR]
    @CLIENTE   INT,
    @PLAN      INT,
    @HORIZONTE INT = 90,
    @USUARIO   INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @NUEVA INT, @R INT

SELECT @HAB = pma_habilitado FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE
IF @HAB IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @HAB = 1
BEGIN
    RAISERROR('2.- EL PLAN YA ESTÁ ACTIVO.', 16, 1)
    RETURN -1
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado IN (2, 3) AND pmv_habilitado = 1)
BEGIN
    RAISERROR('3.- EL PLAN NUNCA ESTUVO ACTIVO: ACTÍVELO DESDE SU BORRADOR.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Plan_Mantenimiento]
   SET pma_habilitado = 1, pma_usuario_actualizacion = @USUARIO, pma_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE pma_id = @PLAN

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1)
BEGIN
    EXEC @R = [dbo].[INS_PLAN_VERSION_NUEVA] @ID = @NUEVA OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN,
         @OBSERVACION = N'Reactivación', @USUARIO = @USUARIO
    IF ISNULL(@R, -1) <> 0
    BEGIN
        UPDATE [dbo].[Plan_Mantenimiento] SET pma_habilitado = 0 WHERE pma_id = @PLAN
        RETURN -1
    END
END

EXEC @R = [dbo].[UPD_PLAN_ACTIVAR] @CLIENTE = @CLIENTE, @PLAN = @PLAN, @OBSERVACION = N'Reactivación',
     @HORIZONTE = @HORIZONTE, @USUARIO = @USUARIO
IF ISNULL(@R, -1) <> 0
BEGIN
    UPDATE [dbo].[Plan_Mantenimiento] SET pma_habilitado = 0 WHERE pma_id = @PLAN
    RETURN -1
END

RETURN(0)
GO

/* ========================================================================
   15. INS_PLAN_DUPLICAR (§26.2 · RP-13)
       Un plan nuevo en borrador, copia de la versión vigente (o del
       borrador, o de la última): intervenciones con su quién, actividades,
       repuestos y, si se pide, los activos. Las frecuencias privadas se
       copian como programaciones nuevas; las compartidas se mantienen.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_DUPLICAR]
    @ID          INT = NULL OUTPUT,
    @CLIENTE     INT,
    @PLAN        INT,
    @NOMBRE      NVARCHAR(400) = NULL,
    @CON_ACTIVOS BIT = 0,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @ORIGEN INT, @R INT, @VNUEVA INT, @CODIGO NVARCHAR(100)
DECLARE @PLANTA INT, @DESC NVARCHAR(MAX), @PLANIF INT, @TIPO INT, @MODELO INT, @NOMBRE_ORIG NVARCHAR(400)

SELECT @PLANTA = pma_cliente_instalacion, @DESC = pma_descripcion, @PLANIF = pma_usuario_planificador,
       @TIPO = pma_activo_tipo, @MODELO = pma_activo_modelo, @NOMBRE_ORIG = pma_nombre
FROM   [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE

IF @NOMBRE_ORIG IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SET @ORIGEN = [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN)
IF @ORIGEN IS NULL
    SELECT TOP 1 @ORIGEN = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY CASE WHEN pmv_plan_version_estado = 1 THEN 0 ELSE 1 END, pmv_numero DESC

SET @NOMBRE = LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(@NOMBRE)), N''), LEFT(N'Copia de ' + @NOMBRE_ORIG, 400))))

EXEC @R = [dbo].[INS_PLAN_MANTENIMIENTO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
     @CODIGO = 'AUTO', @NOMBRE = @NOMBRE, @DESCRIPCION = @DESC, @USUARIO_PLANIFICADOR = @PLANIF,
     @ACTIVO_TIPO = @TIPO, @ACTIVO_MODELO = @MODELO, @USUARIO = @USUARIO
IF ISNULL(@R, -1) <> 0 OR @ID IS NULL RETURN -1

SELECT @CODIGO = pma_codigo FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @ID
SELECT TOP 1 @VNUEVA = pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @ID ORDER BY pmv_numero

IF @ORIGEN IS NOT NULL
BEGIN
    DECLARE @MAPA TABLE (viejo INT, nuevo INT)
    DECLARE @H INT, @PRO INT, @PRIV BIT, @HCOD NVARCHAR(100), @NPRO INT, @NH INT, @NOMPRO NVARCHAR(400)

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT h.pmh_id, h.pmh_programacion, g.pro_es_privada, h.pmh_codigo
        FROM   [dbo].[Plan_Mantenimiento_Hito] h JOIN [dbo].[Programacion] g ON g.pro_id = h.pmh_programacion
        WHERE  h.pmh_plan_mantenimiento_version = @ORIGEN AND h.pmh_habilitado = 1
        ORDER BY h.pmh_orden
    OPEN cur
    FETCH NEXT FROM cur INTO @H, @PRO, @PRIV, @HCOD
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NPRO = @PRO
        IF @PRIV = 1
        BEGIN
            SET @NOMPRO = @CODIGO + N' · ' + @HCOD
            EXEC @R = [dbo].[INS_PROGRAMACION_COPIA] @ID = @NPRO OUTPUT, @CLIENTE = @CLIENTE, @ORIGEN = @PRO, @NOMBRE = @NOMPRO, @USUARIO = @USUARIO
        END

        INSERT INTO [dbo].[Plan_Mantenimiento_Hito]
            (pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
             pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
             pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion, pmh_usuario_responsable, pmh_grupo_trabajo,
             pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion, pmh_habilitado)
        SELECT @VNUEVA, @NPRO, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
               pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
               pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion, pmh_usuario_responsable, pmh_grupo_trabajo,
               @USUARIO, @AHORA, @USUARIO, @AHORA, 1
        FROM   [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @H
        SET @NH = SCOPE_IDENTITY()
        INSERT @MAPA VALUES (@H, @NH)

        FETCH NEXT FROM cur INTO @H, @PRO, @PRIV, @HCOD
    END
    CLOSE cur
    DEALLOCATE cur

    DECLARE @MAPA_ACT TABLE (viejo INT, nuevo INT)
    MERGE [dbo].[Plan_Mantenimiento_Actividad] AS d
    USING (SELECT a.*, m.nuevo AS hito_nuevo FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN @MAPA m ON m.viejo = a.paa_plan_mantenimiento_hito
            WHERE a.paa_habilitado = 1) AS s
       ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion, paa_orden,
                paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada, paa_requiere_permiso, paa_permiso_trabajo_tipo,
                paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion, paa_habilitado)
        VALUES (s.hito_nuevo, s.paa_procedimiento, s.paa_codigo, s.paa_nombre, s.paa_descripcion, s.paa_orden,
                s.paa_duracion_estimada_minuto, s.paa_obligatoria, s.paa_requiere_parada, s.paa_requiere_permiso, s.paa_permiso_trabajo_tipo,
                @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
    OUTPUT s.paa_id, inserted.paa_id INTO @MAPA_ACT (viejo, nuevo);

    INSERT INTO [dbo].[Plan_Actividad_Repuesto]
        (pra_plan_mantenimiento_actividad, pra_repuesto, pra_cantidad, pra_unidad_medida, pra_obligatorio, pra_observacion, pra_usuario_creacion, pra_fecha_creacion)
    SELECT m.nuevo, r.pra_repuesto, r.pra_cantidad, r.pra_unidad_medida, r.pra_obligatorio, r.pra_observacion, @USUARIO, @AHORA
    FROM   [dbo].[Plan_Actividad_Repuesto] r JOIN @MAPA_ACT m ON m.viejo = r.pra_plan_mantenimiento_actividad

    IF @CON_ACTIVOS = 1
        INSERT INTO [dbo].[Plan_Mantenimiento_Activo]
            (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor, pac_usuario_creacion, pac_fecha_creacion)
        SELECT @VNUEVA, a.pac_activo, a.pac_activo_componente, a.pac_activo_medidor, @USUARIO, @AHORA
        FROM   [dbo].[Plan_Mantenimiento_Activo] a JOIN [dbo].[Activo] x ON x.act_id = a.pac_activo AND x.act_habilitado = 1
        WHERE  a.pac_plan_mantenimiento_version = @ORIGEN
END

SELECT @ID AS PLAN_ID, @CODIGO AS CODIGO, @NOMBRE AS NOMBRE
RETURN(0)
GO

/* ========================================================================
   16. INS_PLAN_HITO (384: código automático, frecuencia privada, responsable y grupo)
   ======================================================================== */
-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_HITO — sobre el borrador del plan
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_HITO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@PLAN                INT,
@PROGRAMACION        INT = NULL,
@CODIGO              NVARCHAR(100) = NULL,
@NOMBRE              NVARCHAR(400),
@ORDEN               INT = NULL,
@VALOR_MEDIDOR       DECIMAL(18,4) = NULL,
@UNIDAD_MEDIDA       INT = NULL,
@ES_OVERHAUL         BIT = 0,
@REQUIERE_PARADA     BIT = 0,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@ORDEN_TRABAJO_TIPO  INT = NULL,
@ORDEN_TRABAJO_PRIORIDAD INT = NULL,
@DESCRIPCION         NVARCHAR(1000) = NULL,
@USUARIO_RESPONSABLE INT = NULL,
@GRUPO_TRABAJO       INT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento]
                    WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL PLAN NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* LA VERSION EN BORRADOR, O NADA

       La mas nueva en estado 1. Si el plan no tiene ninguna -esta publicado
       y no se abrio version nueva- no hay donde escribir, y el mensaje dice
       que hacer. */
    SELECT TOP 1 @VERSION = pmv_id
    FROM   [dbo].[Plan_Mantenimiento_Version]
    WHERE  pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1
    ORDER BY pmv_numero DESC

    IF @VERSION IS NULL
    BEGIN
        RAISERROR('2.- EL PLAN NO TIENE UNA VERSIÓN EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICAR SUS HITOS.', 16, 1)
        RETURN -1
    END

    /* 384 · RP-16: sin código se propone INT-nn (el Centro no lo pide). */
    IF (@CODIGO IS NULL OR @CODIGO = N'')
    BEGIN
        DECLARE @NC INT = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @VERSION) + 1
        SET @CODIGO = N'INT-' + CASE WHEN @NC < 10 THEN N'0' ELSE N'' END + CAST(@NC AS NVARCHAR(10))
        WHILE EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @CODIGO)
        BEGIN
            SET @NC = @NC + 1
            SET @CODIGO = N'INT-' + CASE WHEN @NC < 10 THEN N'0' ELSE N'' END + CAST(@NC AS NVARCHAR(10))
        END
    END

    IF (@NOMBRE IS NULL OR @NOMBRE = N'')
    BEGIN
        RAISERROR('4.- INDIQUE EL NOMBRE DEL HITO.', 16, 1)
        RETURN -1
    END

    -- Unico dentro de la version: lo garantiza UX_PMH_VERSION_CODIGO, y
    -- aca se dice con palabras que codigo choco.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @CODIGO)
    BEGIN
        RAISERROR('5.- YA EXISTE UN HITO CON EL CÓDIGO "%s" EN ESTA VERSIÓN DEL PLAN.', 16, 1, @CODIGO)
        RETURN -1
    END

    /* 384 · RP-01: sin programación, la intervención nace con su frecuencia
       privada vacía (ABIERTA = «falta la frecuencia»). */
    IF @PROGRAMACION IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                    WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
    BEGIN
        RAISERROR('6.- LA PROGRAMACIÓN NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- Las reglas de los CHECK, dichas con palabras antes de que rebote la tabla.
    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('7.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    IF @USUARIO_RESPONSABLE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_RESPONSABLE AND ucl_id_cliente = @CLIENTE AND ucl_habilitado = 1)
    BEGIN
        RAISERROR('9.- EL RESPONSABLE NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @GRUPO_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo]
                    WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE)
    BEGIN
        RAISERROR('10.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- Sin orden, va al final: el planificador rara vez lo escribe a mano.
    IF (@ORDEN IS NULL OR @ORDEN < 1)
        SELECT @ORDEN = ISNULL(MAX(pmh_orden), 0) + 1
        FROM   [dbo].[Plan_Mantenimiento_Hito]
        WHERE  pmh_plan_mantenimiento_version = @VERSION
END

IF @PROGRAMACION IS NULL
BEGIN
    DECLARE @NOMPRO NVARCHAR(400) = (SELECT pma_codigo FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN) + N' · ' + @CODIGO, @RP INT
    EXEC @RP = [dbo].[INS_PROGRAMACION_PRIVADA] @ID = @PROGRAMACION OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @NOMPRO, @USUARIO = @USUARIO
    IF ISNULL(@RP, -1) <> 0 OR @PROGRAMACION IS NULL RETURN -1
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Hito]
        (
            pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden,
            pmh_valor_medidor, pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada,
            pmh_duracion_estimada_minuto, pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad,
            pmh_descripcion, pmh_usuario_responsable, pmh_grupo_trabajo,
            pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion,
            pmh_habilitado
        )
    VALUES
        (
            @VERSION, @PROGRAMACION, @CODIGO, @NOMBRE, @ORDEN,
            @VALOR_MEDIDOR, @UNIDAD_MEDIDA, ISNULL(@ES_OVERHAUL, 0), ISNULL(@REQUIERE_PARADA, 0),
            @DURACION_ESTIMADA_MINUTO, @ORDEN_TRABAJO_TIPO, @ORDEN_TRABAJO_PRIORIDAD,
            @DESCRIPCION, @USUARIO_RESPONSABLE, @GRUPO_TRABAJO,
            @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW,
            1
        )

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_HITO @PLAN = ' + LTRIM(STR(@PLAN)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '8.- NO FUE POSIBLE INSERTAR EL HITO.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   17. UPD_PLAN_HITO (384: responsable y grupo)
   ======================================================================== */
-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_HITO
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_HITO]
@ID                  INT,
@PROGRAMACION        INT = NULL,
@CODIGO              NVARCHAR(100) = NULL,
@NOMBRE              NVARCHAR(400) = NULL,
@ORDEN               INT = NULL,
@VALOR_MEDIDOR       DECIMAL(18,4) = NULL,
@UNIDAD_MEDIDA       INT = NULL,
@ES_OVERHAUL         BIT = NULL,
@REQUIERE_PARADA     BIT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@ORDEN_TRABAJO_TIPO  INT = NULL,
@ORDEN_TRABAJO_PRIORIDAD INT = NULL,
@DESCRIPCION         NVARCHAR(1000) = NULL,
@HABILITADO          BIT = NULL,
@QUITA_MEDIDOR       BIT = 0,
@QUITA_OT_TIPO       BIT = 0,
@QUITA_OT_PRIORIDAD  BIT = 0,
@QUITA_DURACION      BIT = 0,
@USUARIO_RESPONSABLE INT = NULL,
@GRUPO_TRABAJO       INT = NULL,
@QUITA_RESPONSABLE   BIT = 0,
@QUITA_GRUPO         BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @VERSION INT, @ESTADO INT

SELECT @VERSION = pmh_plan_mantenimiento_version FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_id = @ID

IF @VERSION IS NULL
BEGIN
    RAISERROR('1.- EL HITO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @CLIENTE = pma.pma_cliente, @ESTADO = pmv.pmv_plan_version_estado
FROM   [dbo].[Plan_Mantenimiento_Version] pmv
INNER JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
WHERE  pmv.pmv_id = @VERSION

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
IF @NOMBRE IS NOT NULL SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTE HITO YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLO.', 16, 1)
        RETURN -1
    END

    IF @NOMBRE IS NOT NULL AND @NOMBRE = N''
    BEGIN
        RAISERROR('3.- INDIQUE EL NOMBRE DEL HITO.', 16, 1)
        RETURN -1
    END

    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                    WHERE pmh_plan_mantenimiento_version = @VERSION AND pmh_codigo = @CODIGO AND pmh_id <> @ID)
    BEGIN
        RAISERROR('4.- YA EXISTE UN HITO CON EL CÓDIGO "%s" EN ESTA VERSIÓN DEL PLAN.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @PROGRAMACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                        WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
    BEGIN
        RAISERROR('5.- LA PROGRAMACIÓN NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('6.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    IF @USUARIO_RESPONSABLE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_RESPONSABLE AND ucl_id_cliente = @CLIENTE AND ucl_habilitado = 1)
    BEGIN
        RAISERROR('9.- EL RESPONSABLE NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @GRUPO_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo]
                    WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE)
    BEGIN
        RAISERROR('10.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@ORDEN IS NOT NULL AND @ORDEN < 1)
    BEGIN
        RAISERROR('7.- EL ORDEN DEBE SER 1 O MAYOR.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento_Hito]
    SET     pmh_programacion             = ISNULL(@PROGRAMACION, pmh_programacion)
           ,pmh_codigo                   = ISNULL(@CODIGO, pmh_codigo)
           ,pmh_nombre                   = ISNULL(@NOMBRE, pmh_nombre)
           ,pmh_orden                    = ISNULL(@ORDEN, pmh_orden)
           ,pmh_valor_medidor            = CASE WHEN @QUITA_MEDIDOR = 1 THEN NULL ELSE ISNULL(@VALOR_MEDIDOR, pmh_valor_medidor) END
           ,pmh_unidad_medida            = CASE WHEN @QUITA_MEDIDOR = 1 THEN NULL ELSE ISNULL(@UNIDAD_MEDIDA, pmh_unidad_medida) END
           ,pmh_es_overhaul              = ISNULL(@ES_OVERHAUL, pmh_es_overhaul)
           ,pmh_requiere_parada          = ISNULL(@REQUIERE_PARADA, pmh_requiere_parada)
           ,pmh_duracion_estimada_minuto = CASE WHEN @QUITA_DURACION = 1 THEN NULL ELSE ISNULL(@DURACION_ESTIMADA_MINUTO, pmh_duracion_estimada_minuto) END
           ,pmh_orden_trabajo_tipo       = CASE WHEN @QUITA_OT_TIPO = 1 THEN NULL ELSE ISNULL(@ORDEN_TRABAJO_TIPO, pmh_orden_trabajo_tipo) END
           ,pmh_orden_trabajo_prioridad  = CASE WHEN @QUITA_OT_PRIORIDAD = 1 THEN NULL ELSE ISNULL(@ORDEN_TRABAJO_PRIORIDAD, pmh_orden_trabajo_prioridad) END
           ,pmh_descripcion              = ISNULL(@DESCRIPCION, pmh_descripcion)
           ,pmh_habilitado               = ISNULL(@HABILITADO, pmh_habilitado)
           ,pmh_usuario_responsable      = CASE WHEN @QUITA_RESPONSABLE = 1 THEN NULL ELSE ISNULL(@USUARIO_RESPONSABLE, pmh_usuario_responsable) END
           ,pmh_grupo_trabajo            = CASE WHEN @QUITA_GRUPO = 1 THEN NULL ELSE ISNULL(@GRUPO_TRABAJO, pmh_grupo_trabajo) END
           ,pmh_usuario_actualizacion    = @USUARIO
           ,pmh_fecha_actualizacion      = @DATE_NOW
    WHERE   pmh_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_HITO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '8.- NO FUE POSIBLE ACTUALIZAR EL HITO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   18. INS_PLAN_ACTIVIDAD (384: código automático)
   ======================================================================== */
-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_ACTIVIDAD (T-4052)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_ACTIVIDAD]
@ID                       INT = NULL OUTPUT,
@CLIENTE                  INT,
@HITO                     INT,
@CODIGO                   NVARCHAR(100) = NULL,
@NOMBRE                   NVARCHAR(400),
@DESCRIPCION              NVARCHAR(1000) = NULL,
@ORDEN                    INT = NULL,
@PROCEDIMIENTO            INT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@OBLIGATORIA              BIT = 1,
@REQUIERE_PARADA          BIT = 0,
@REQUIERE_PERMISO         BIT = 0,
@PERMISO_TRABAJO_TIPO     INT = NULL,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT, @ESTADO INT, @CLIENTE_HITO INT

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    SELECT @VERSION = pmh.pmh_plan_mantenimiento_version,
           @ESTADO  = pmv.pmv_plan_version_estado,
           @CLIENTE_HITO = pma.pma_cliente
    FROM   [dbo].[Plan_Mantenimiento_Hito] pmh
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
    WHERE  pmh.pmh_id = @HITO

    IF @VERSION IS NULL
    BEGIN
        RAISERROR('1.- EL HITO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE_HITO <> @CLIENTE
    BEGIN
        RAISERROR('2.- EL HITO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* La version publicada ya genero mantenciones: agregarle una actividad
       por debajo cambia lo que se comprometio sin dejar rastro. */
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('3.- LA VERSIÓN DEL PLAN YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA AGREGARLE ACTIVIDADES.', 16, 1)
        RETURN -1
    END

    /* 384 · RP-16: sin código se propone ACT-nn. */
    IF (@CODIGO IS NULL OR @CODIGO = N'')
    BEGIN
        DECLARE @NC INT = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @HITO) + 1
        SET @CODIGO = N'ACT-' + CASE WHEN @NC < 10 THEN N'0' ELSE N'' END + CAST(@NC AS NVARCHAR(10))
        WHILE EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_plan_mantenimiento_hito = @HITO AND paa_codigo = @CODIGO)
        BEGIN
            SET @NC = @NC + 1
            SET @CODIGO = N'ACT-' + CASE WHEN @NC < 10 THEN N'0' ELSE N'' END + CAST(@NC AS NVARCHAR(10))
        END
    END

    IF (@NOMBRE IS NULL OR @NOMBRE = N'')
    BEGIN
        RAISERROR('5.- INDIQUE EL NOMBRE DE LA ACTIVIDAD.', 16, 1)
        RETURN -1
    END

    -- Unico dentro del hito: lo garantiza UX_PAA_HITO_CODIGO, y aca se dice
    -- con palabras cual codigo choco.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                WHERE paa_plan_mantenimiento_hito = @HITO AND paa_codigo = @CODIGO)
    BEGIN
        RAISERROR('6.- YA EXISTE UNA ACTIVIDAD CON EL CÓDIGO "%s" EN ESTE HITO.', 16, 1, @CODIGO)
        RETURN -1
    END

    /* El procedimiento se valida contra el cliente porque sus pasos se COPIAN
       a la orden que genera el plan: uno de otra empresa le copiaria esos
       pasos a la orden. */
    IF (@PROCEDIMIENTO IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM [dbo].[Procedimiento]
             WHERE prc_id = @PROCEDIMIENTO AND prc_cliente = @CLIENTE AND ISNULL(prc_habilitado, 1) = 1))
    BEGIN
        RAISERROR('7.- EL PROCEDIMIENTO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('8.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    /* Pedir permiso de trabajo sin decir de que tipo deja la orden sin saber
       que permiso emitir. */
    IF (ISNULL(@REQUIERE_PERMISO, 0) = 1 AND @PERMISO_TRABAJO_TIPO IS NULL)
    BEGIN
        RAISERROR('9.- SI LA ACTIVIDAD REQUIERE PERMISO DE TRABAJO, INDIQUE DE QUÉ TIPO.', 16, 1)
        RETURN -1
    END

    -- Sin orden, va al final del hito.
    IF (@ORDEN IS NULL OR @ORDEN < 1)
        SELECT @ORDEN = ISNULL(MAX(paa_orden), 0) + 1
        FROM   [dbo].[Plan_Mantenimiento_Actividad]
        WHERE  paa_plan_mantenimiento_hito = @HITO

    SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
    SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Actividad]
        (
            paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion,
            paa_orden, paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada,
            paa_requiere_permiso, paa_permiso_trabajo_tipo,
            paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion,
            paa_habilitado
        )
    VALUES
        (
            @HITO, @PROCEDIMIENTO, @CODIGO, @NOMBRE, @DESCRIPCION,
            @ORDEN, @DURACION_ESTIMADA_MINUTO, ISNULL(@OBLIGATORIA, 1), ISNULL(@REQUIERE_PARADA, 0),
            ISNULL(@REQUIERE_PERMISO, 0), @PERMISO_TRABAJO_TIPO,
            @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW,
            1
        )

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_ACTIVIDAD @HITO = ' + LTRIM(STR(@HITO)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '10.- NO FUE POSIBLE INSERTAR LA ACTIVIDAD.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   19. INS_ORDEN_TRABAJO_OCURRENCIA (384: asignación desde la intervención)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_OCURRENCIA]
@ID         INT = NULL OUTPUT,
@CLIENTE    INT,
@OCURRENCIA INT,
@USUARIO    INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @ESTADO INT, @OT_EXISTE INT, @HITO INT, @ACTIVO INT, @COMPONENTE INT, @FECHA DATETIME,
        @PLAN_CODIGO NVARCHAR(100), @PLAN_NOMBRE NVARCHAR(400), @VERSION INT,
        @HITO_CODIGO NVARCHAR(100), @HITO_NOMBRE NVARCHAR(400), @HITO_DESC NVARCHAR(MAX),
        @OT_TIPO INT, @OT_PRIORIDAD INT, @PARADA BIT, @OVERHAUL BIT, @DURACION INT,
        @INST INT, @AREA INT, @ACT_CODIGO NVARCHAR(100), @ACT_NOMBRE NVARCHAR(400),
        @RESP INT, @GRUPO INT

SELECT  @ESTADO      = o.pmo_plan_ocurrencia_estado,
        @OT_EXISTE   = o.pmo_orden_trabajo,
        @HITO        = o.pmo_plan_mantenimiento_hito,
        @ACTIVO      = o.pmo_activo,
        @COMPONENTE  = o.pmo_activo_componente,
        @FECHA       = o.pmo_fecha_programada_utc,
        @PLAN_CODIGO = pma.pma_codigo,
        @PLAN_NOMBRE = pma.pma_nombre,
        @VERSION     = pmv.pmv_numero,
        @HITO_CODIGO = h.pmh_codigo,
        @HITO_NOMBRE = h.pmh_nombre,
        @HITO_DESC   = h.pmh_descripcion,
        @OT_TIPO     = ISNULL(h.pmh_orden_trabajo_tipo, 1),          -- PREVENTIVA
        @OT_PRIORIDAD= ISNULL(h.pmh_orden_trabajo_prioridad, 2),     -- MEDIA
        @PARADA      = h.pmh_requiere_parada,
        @OVERHAUL    = h.pmh_es_overhaul,
        @DURACION    = h.pmh_duracion_estimada_minuto,
        @INST        = act.act_cliente_instalacion,
        @AREA        = act.act_instalacion_area,
        @ACT_CODIGO  = act.act_codigo,
        @ACT_NOMBRE  = act.act_nombre,
        @RESP        = h.pmh_usuario_responsable,
        @GRUPO       = h.pmh_grupo_trabajo
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN    [dbo].[Plan_Mantenimiento_Hito]    h   ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = h.pmh_plan_mantenimiento_version
JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
WHERE   o.pmo_id = @OCURRENCIA AND o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1

IF @HITO IS NULL
BEGIN
    RAISERROR('1.- LA OCURRENCIA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- Idempotente: la que ya tiene orden devuelve esa.
IF @OT_EXISTE IS NOT NULL
BEGIN
    SET @ID = @OT_EXISTE
    SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(1 AS BIT) AS YA_EXISTIA
    FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @OT_EXISTE
    RETURN 0
END

IF @ESTADO NOT IN (1, 2)
BEGIN
    RAISERROR('2.- SOLO SE GENERA ORDEN DESDE UNA OCURRENCIA PENDIENTE O DISPONIBLE.', 16, 1)
    RETURN -1
END

IF @INST IS NULL
BEGIN
    RAISERROR('3.- EL EQUIPO %s NO TIENE PLANTA: NO SE PUEDE GENERAR LA ORDEN.', 16, 1, @ACT_CODIGO)
    RETURN -1
END

DECLARE @TITULO NVARCHAR(400) = LEFT(@HITO_NOMBRE + N' · ' + @ACT_CODIGO + N' ' + @ACT_NOMBRE, 400)
DECLARE @CUERPO NVARCHAR(MAX) = ISNULL(@HITO_DESC, N'')
    + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + N'Generada desde el plan ' + @PLAN_CODIGO + N' «' + @PLAN_NOMBRE + N'» v' + CAST(@VERSION AS NVARCHAR(10))
    + N', hito ' + @HITO_CODIGO + N', programada para el ' + CONVERT(NVARCHAR(10), @FECHA, 103) + N'.'
    + CASE WHEN @PARADA = 1 THEN CHAR(13) + CHAR(10) + N'REQUIERE PARADA DEL EQUIPO.' ELSE N'' END

DECLARE @REQUIERE_PERMISO BIT = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                                                   WHERE paa_plan_mantenimiento_hito = @HITO AND paa_habilitado = 1 AND paa_requiere_permiso = 1)
                                     THEN 1 ELSE 0 END

BEGIN TRY
    BEGIN TRANSACTION

    -- Correlativo con el candado puesto: dos generaciones a la vez no sacan el mismo numero.
    DECLARE @CORR INT
    SELECT  @CORR = ISNULL(MAX(otr_correlativo), 0) + 1
    FROM    [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
    WHERE   otr_cliente = @CLIENTE

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo,
         otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen,
         otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion,
         otr_fecha_programada_utc, otr_duracion_estimada_minuto,
         otr_minuto_parada_activo, otr_requiere_permiso,
         otr_plan_mantenimiento_ocurrencia, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @INST, @AREA, @CORR,
         @ACTIVO, @COMPONENTE,
         @OT_TIPO, CASE WHEN @OVERHAUL = 1 THEN 5 ELSE 2 END, 2,
         1, @OT_PRIORIDAD,
         @USUARIO, @TITULO, @CUERPO,
         @FECHA, @DURACION,
         CASE WHEN @PARADA = 1 THEN @DURACION ELSE NULL END, @REQUIERE_PERMISO,
         @OCURRENCIA, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES
        (@ID, NULL, 1, N'Generada desde la ocurrencia del plan ' + @PLAN_CODIGO, GETUTCDATE(), @USUARIO, @DATE_NOW)

    -- Un paso por actividad, con el texto COPIADO (criterio 2)
    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        (otp_orden_trabajo, otp_procedimiento_paso, otp_plan_mantenimiento_actividad, otp_orden, otp_nombre, otp_descripcion,
         otp_obligatorio, otp_resultado_paso, otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
    /* HU-062 #1 / HU-061 #2: si la actividad referencia un procedimiento,
       la orden trae un paso por cada paso del procedimiento, con el nombre
       y la instruccion COPIADOS en ese momento. Asi la orden conserva el
       texto que tenia al ejecutarse aunque el procedimiento cambie despues.
       Una actividad sin procedimiento sigue siendo un solo paso. */
    SELECT  @ID, pp.ppa_id, a.paa_id,
            ROW_NUMBER() OVER (ORDER BY a.paa_orden, a.paa_id, pp.ppa_orden),
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_nombre
                 ELSE a.paa_nombre + N' · ' + CAST(pp.ppa_orden AS NVARCHAR(10)) + N'. ' + pp.ppa_nombre END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_descripcion ELSE ISNULL(pp.ppa_instruccion, a.paa_descripcion) END,
            CASE WHEN pp.ppa_id IS NULL THEN a.paa_obligatoria
                 WHEN pp.ppa_es_punto_control = 1 THEN 1 ELSE a.paa_obligatoria END,
            4, @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Mantenimiento_Actividad] a
    LEFT JOIN [dbo].[Procedimiento_Paso] pp
           ON pp.ppa_procedimiento = a.paa_procedimiento AND pp.ppa_habilitado = 1
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1

    -- Sin actividades cargadas: el hito es el unico paso, para que la orden sea ejecutable.
    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[Orden_Trabajo_Paso]
            (otp_orden_trabajo, otp_orden, otp_nombre, otp_descripcion, otp_obligatorio, otp_resultado_paso,
             otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
        VALUES
            (@ID, 1, @HITO_NOMBRE, @HITO_DESC, 1, 4, @USUARIO, @DATE_NOW, 1)

    -- Repuestos planificados de esas actividades
    INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
        (ore_orden_trabajo, ore_repuesto, ore_cantidad_planificada, ore_observacion, ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
    SELECT  @ID, r.pra_repuesto, SUM(r.pra_cantidad),
            CASE WHEN MAX(CAST(r.pra_obligatorio AS INT)) = 1 THEN N'Planificado por el plan (obligatorio)' ELSE N'Planificado por el plan' END,
            @USUARIO, @DATE_NOW, 1
    FROM    [dbo].[Plan_Actividad_Repuesto] r
    JOIN    [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
    WHERE   a.paa_plan_mantenimiento_hito = @HITO AND a.paa_habilitado = 1
    GROUP BY r.pra_repuesto

    /* 384 · RP-09: la OT nace asignada al responsable de la intervención o,
       si solo tiene grupo, a su líder vigente (como INS_ORDEN_TRABAJO_ASIGNACION). */
    DECLARE @ASIGNADO INT = @RESP
    IF @ASIGNADO IS NULL AND @GRUPO IS NOT NULL
        SELECT TOP 1 @ASIGNADO = gtu_usuario
          FROM [dbo].[Grupo_Trabajo_Usuario]
         WHERE gtu_grupo_trabajo = @GRUPO AND gtu_es_lider = 1
           AND gtu_fecha_inicio <= CAST(@DATE_NOW AS DATE) AND (gtu_fecha_fin IS NULL OR gtu_fecha_fin >= CAST(@DATE_NOW AS DATE))
         ORDER BY gtu_fecha_inicio DESC

    IF @ASIGNADO IS NOT NULL
    BEGIN
        INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
            (ota_orden_trabajo, ota_usuario, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_asignado_por,
             ota_observacion, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
        VALUES
            (@ID, @ASIGNADO, @GRUPO, 1, 1, @USUARIO,
             N'Asignada por el plan ' + @PLAN_CODIGO, @USUARIO, @DATE_NOW, 1)

        UPDATE [dbo].[Orden_Trabajo] SET otr_usuario_responsable = @ASIGNADO WHERE otr_id = @ID
    END

    -- La ocurrencia queda enlazada y en ejecucion, con su rastro
    UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
    SET    pmo_orden_trabajo = @ID,
           pmo_plan_ocurrencia_estado = 3,
           pmo_usuario_actualizacion = @USUARIO,
           pmo_fecha_actualizacion = @DATE_NOW
    WHERE  pmo_id = @OCURRENCIA

    INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
        (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
    VALUES
        (@OCURRENCIA, @ESTADO, 3, N'Se generó la orden de trabajo OT-' + CAST(@CORR AS NVARCHAR(10)), @USUARIO, @DATE_NOW)

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_OCURRENCIA', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE GENERAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(0 AS BIT) AS YA_EXISTIA
FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @ID

RETURN 0
GO

/* ========================================================================
   20. UPD_ORDEN_TRABAJO_CERRAR (384: sincroniza la ejecución del plan)
   ======================================================================== */
-- ---------- UPD_ORDEN_TRABAJO_CERRAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ORDEN_TRABAJO_CERRAR (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   UPD_ORDEN_TRABAJO_CERRAR
      Lo que hace el planificador, el supervisor o el jefe. Nadie mas.
      Ahora idempotente por uuid, para poder encolarse desde el telefono.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_CERRAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @CIERRE_MOTIVO  INT,
    @OBSERVACION    NVARCHAR(500) = NULL,
    /* Nace en el telefono AL ENCOLAR. Opcional: la web no lo manda. */
    @UUID           UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON

    /* ---- Idempotencia: si el uuid ya cerro una OT, se responde lo mismo ----
       Va ANTES de toda validacion. Sin esto, el reintento de un cierre que ya
       entro respondia "La OT no esta en espera de cierre" -porque este mismo
       uuid la dejo en 4-, y la cola marcaba rechazado un cierre correcto. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [otr_id] FROM [dbo].[Orden_Trabajo]
         WHERE [otr_cierre_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SELECT @YA AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
            RETURN
        END
    END

    DECLARE @CLIENTE INT
    SELECT @CLIENTE = otr_cliente FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('La orden de trabajo no existe.', 16, 1)
        RETURN
    END

    -- La regla de jerarquia. El tecnico finaliza; cerrar es de otros.
    IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
    BEGIN
        RAISERROR('Este usuario no puede cerrar ordenes de trabajo. El cierre es del planificador, el supervisor o el jefe de mantenimiento.', 16, 1)
        RETURN
    END

    /* El texto NO dice "no existe" a proposito: `ErrorSql` traduce a 404 todo
       mensaje que contenga esa frase, y un 404 sobre /ordenes-trabajo/{id}/cerrar
       le dice a la app que la ORDEN no existe cuando lo que no sirve es un campo
       del cuerpo. Redactado asi cae en el 400 que le corresponde a un valor
       invalido. Arreglarlo en ErrorSql habria cambiado el codigo de los ~150 SP
       que comparten ese traductor. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO AND ocm_habilitado = 1)
    BEGIN
        RAISERROR('El motivo de cierre no es valido o fue deshabilitado.', 16, 1)
        RETURN
    END

    -- Un permiso de trabajo exigido y no autorizado bloquea el cierre.
    -- Cerrar una OT cuyo permiso nunca se firmo es documentar una mentira.
    IF EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo]
                WHERE ptr_orden_trabajo = @ORDEN_TRABAJO
                  AND ptr_permiso_trabajo_estado NOT IN (2, 5))   -- AUTORIZADO o CERRADO
    BEGIN
        RAISERROR('Hay permisos de trabajo sin autorizar. No se puede cerrar la OT.', 16, 1)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 4,      -- CERRADA
           otr_cierre_motivo         = @CIERRE_MOTIVO,
           otr_usuario_cierre        = @USUARIO,
           otr_fecha_cierre          = [dbo].[FNC_AHORA](),
           otr_cierre_uuid           = @UUID,
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = [dbo].[FNC_AHORA]()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado = 3        -- solo desde EN ESPERA DE CIERRE

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La OT no esta en espera de cierre. El tecnico tiene que finalizarla primero.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 4, @OBSERVACION, @USUARIO)

    /* 384 · RP-12: la ejecución del plan se completa (u omite) igual que en
       el cierre web (UPD_ORDEN_TRABAJO_CERRAR_WEB): motivos 1 y 2 completan,
       el resto omite. */
    DECLARE @OCURRENCIA INT = (SELECT otr_plan_mantenimiento_ocurrencia FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO)
    IF @OCURRENCIA IS NOT NULL
    BEGIN
        DECLARE @NUEVO INT = CASE WHEN @CIERRE_MOTIVO IN (1, 2) THEN 4 ELSE 5 END, @ANT INT
        DECLARE @CORR INT = (SELECT otr_correlativo FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO)
        SELECT @ANT = pmo_plan_ocurrencia_estado FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_id = @OCURRENCIA
        UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
           SET pmo_plan_ocurrencia_estado = @NUEVO, pmo_usuario_actualizacion = @USUARIO, pmo_fecha_actualizacion = [dbo].[FNC_AHORA]()
         WHERE pmo_id = @OCURRENCIA AND pmo_plan_ocurrencia_estado NOT IN (4, 5, 6)
        IF @@ROWCOUNT > 0
            INSERT INTO [dbo].[Plan_Ocurrencia_Historial]
                (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
            VALUES (@OCURRENCIA, @ANT, @NUEVO, N'Cierre de la OT-' + CAST(@CORR AS NVARCHAR(10)) + N' desde la app', @USUARIO, [dbo].[FNC_AHORA]())
    END

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
END
GO

/* ========================================================================
   21. SEL_ORDEN_TRABAJO (384: filtro por plan, OT-3)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO]
@ID          INT = NULL,
@CLIENTE     INT,
@INSTALACION INT = NULL,
@ESTADO      INT = NULL,
@TIPO        INT = NULL,
@ORIGEN      INT = NULL,
@ACTIVO      INT = NULL,
@FALLA       INT = NULL,
@PLAN        INT = NULL,
@DESDE       DATE = NULL,
@HASTA       DATE = NULL,
@FILTRO      NVARCHAR(200) = NULL,
@PAGINA      INT = NULL,
@TAMANO      INT = NULL

AS
SET NOCOUNT ON

IF (@PAGINA IS NULL OR @PAGINA < 1) SET @PAGINA = 1
IF (@TAMANO IS NULL OR @TAMANO < 1) SET @TAMANO = 1000000

SELECT  o.otr_id, o.otr_uuid, o.otr_cliente, o.otr_cliente_instalacion, o.otr_correlativo, o.otr_instalacion_area,
        o.otr_activo, o.otr_activo_componente, o.otr_orden_trabajo_tipo, o.otr_orden_trabajo_estrategia,
        o.otr_orden_trabajo_origen, o.otr_orden_trabajo_estado, o.otr_orden_trabajo_prioridad,
        o.otr_usuario_generador, o.otr_titulo, o.otr_descripcion, o.otr_notas, o.otr_resultado,
        o.otr_fecha_evento_utc, o.otr_fecha_programada_utc, o.otr_fecha_inicio_real_utc, o.otr_fecha_fin_real_utc,
        o.otr_duracion_estimada_minuto, o.otr_duracion_real_minuto, o.otr_minuto_parada_activo, o.otr_requiere_permiso,
        o.otr_plan_mantenimiento_ocurrencia, o.otr_tarea_ocurrencia, o.otr_checklist_hallazgo, o.otr_prediccion, o.otr_falla,
        o.otr_registro_posterior, o.otr_fecha_ocurrencia, o.otr_cierre_motivo, o.otr_usuario_cierre, o.otr_fecha_cierre,
        o.otr_usuario_creacion, o.otr_fecha_creacion, o.otr_usuario_actualizacion, o.otr_fecha_actualizacion, o.otr_habilitado,
        cin.cin_nombre                  AS PLANTA_NOMBRE,
        iar.iar_nombre                  AS AREA_NOMBRE,
        act.act_codigo                  AS ACTIVO_CODIGO,
        act.act_nombre                  AS ACTIVO_NOMBRE,
        aco.aco_nombre                  AS COMPONENTE_NOMBRE,
        oty.ott_codigo                  AS TIPO_CODIGO,
        oty.ott_nombre                  AS TIPO_NOMBRE,
        oes.oet_codigo                  AS ESTRATEGIA_CODIGO,
        oes.oet_nombre                  AS ESTRATEGIA_NOMBRE,
        oto.oto_codigo                  AS ORIGEN_CODIGO,
        oto.oto_nombre                  AS ORIGEN_NOMBRE,
        ote.ote_codigo                  AS ESTADO_CODIGO,
        ote.ote_nombre                  AS ESTADO_NOMBRE,
        opr.opr_codigo                  AS PRIORIDAD_CODIGO,
        opr.opr_nombre                  AS PRIORIDAD_NOMBRE,
        ocm.ocm_nombre                  AS CIERRE_MOTIVO_NOMBRE,
        LTRIM(RTRIM(ISNULL(ug.usu_nombre,'') + ' ' + ISNULL(ug.usu_apellido_paterno,''))) AS GENERADOR_NOMBRE,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS CIERRE_USUARIO_NOMBRE,
        LTRIM(RTRIM(ISNULL(ucr.usu_nombre,'') + ' ' + ISNULL(ucr.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
        LTRIM(RTRIM(ISNULL(uac.usu_nombre,'') + ' ' + ISNULL(uac.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
        -- El responsable: una persona o una empresa externa
        ISNULL(LTRIM(RTRIM(ISNULL(ur.usu_nombre,'') + ' ' + ISNULL(ur.usu_apellido_paterno,''))), '') AS RESPONSABLE_NOMBRE,
        prv.prv_razon_social            AS RESPONSABLE_PROVEEDOR,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Asignacion] x WHERE x.ota_orden_trabajo = o.otr_id AND x.ota_habilitado = 1) AS ASIGNADOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p WHERE p.otp_orden_trabajo = o.otr_id AND p.otp_habilitado = 1) AS PASOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p WHERE p.otp_orden_trabajo = o.otr_id AND p.otp_habilitado = 1 AND p.otp_resultado_paso = 4) AS PASOS_PENDIENTES,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Repuesto] r WHERE r.ore_orden_trabajo = o.otr_id AND r.ore_habilitado = 1) AS REPUESTOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] s WHERE s.ots_orden_trabajo = o.otr_id AND s.ots_habilitado = 1) AS SERVICIOS,
        (SELECT COUNT(*) FROM [dbo].[Activo_Indisponibilidad] i WHERE i.ain_orden_trabajo = o.otr_id AND i.ain_habilitado = 1) AS INDISPONIBILIDADES,
        (SELECT COUNT(*) FROM [dbo].[Permiso_Trabajo] pt WHERE pt.ptr_orden_trabajo = o.otr_id AND pt.ptr_permiso_trabajo_estado NOT IN (2, 5)) AS PERMISOS_PENDIENTES,
        CASE WHEN o.otr_orden_trabajo_estado = 3 THEN DATEDIFF(DAY, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion), GETUTCDATE()) ELSE NULL END AS DIAS_ESPERA_CIERRE,
        fal.fal_titulo                  AS FALLA_TITULO,
        pma.pma_codigo                  AS PLAN_CODIGO,
        COUNT(*) OVER ()                AS TOTAL
FROM    [dbo].[Orden_Trabajo] o
LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = o.otr_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area]         iar ON iar.iar_id = o.otr_instalacion_area
LEFT JOIN [dbo].[Activo]                   act ON act.act_id = o.otr_activo
LEFT JOIN [dbo].[Activo_Componente]        aco ON aco.aco_id = o.otr_activo_componente
LEFT JOIN [dbo].[Orden_Trabajo_Tipo]       oty ON oty.ott_id = o.otr_orden_trabajo_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Estrategia] oes ON oes.oet_id = o.otr_orden_trabajo_estrategia
LEFT JOIN [dbo].[Orden_Trabajo_Origen]     oto ON oto.oto_id = o.otr_orden_trabajo_origen
LEFT JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.ote_id = o.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo_Prioridad]  opr ON opr.opr_id = o.otr_orden_trabajo_prioridad
LEFT JOIN [dbo].[Orden_Trabajo_Cierre_Motivo] ocm ON ocm.ocm_id = o.otr_cierre_motivo
LEFT JOIN [dbo].[Usuario] ug  ON ug.usu_id  = o.otr_usuario_generador
LEFT JOIN [dbo].[Usuario] uc  ON uc.usu_id  = o.otr_usuario_cierre
LEFT JOIN [dbo].[Usuario] ucr ON ucr.usu_id = o.otr_usuario_creacion
LEFT JOIN [dbo].[Usuario] uac ON uac.usu_id = o.otr_usuario_actualizacion
LEFT JOIN [dbo].[Orden_Trabajo_Asignacion] ota ON ota.ota_orden_trabajo = o.otr_id AND ota.ota_es_responsable = 1 AND ota.ota_habilitado = 1
LEFT JOIN [dbo].[Usuario]   ur  ON ur.usu_id  = ota.ota_usuario
LEFT JOIN [dbo].[Proveedor] prv ON prv.prv_id = ota.ota_proveedor
LEFT JOIN [dbo].[Falla]     fal ON fal.fal_id = o.otr_falla
LEFT JOIN [dbo].[Plan_Mantenimiento_Ocurrencia] pmo ON pmo.pmo_id = o.otr_plan_mantenimiento_ocurrencia
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] pmh ON pmh.pmh_id = pmo.pmo_plan_mantenimiento_hito
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
  AND   (@ID IS NULL OR o.otr_id = @ID)
  AND   (@INSTALACION IS NULL OR o.otr_cliente_instalacion = @INSTALACION)
  AND   (@ESTADO IS NULL OR o.otr_orden_trabajo_estado = @ESTADO)
  AND   (@TIPO IS NULL OR o.otr_orden_trabajo_tipo = @TIPO)
  AND   (@ORIGEN IS NULL OR o.otr_orden_trabajo_origen = @ORIGEN)
  AND   (@ACTIVO IS NULL OR o.otr_activo = @ACTIVO)
  AND   (@FALLA IS NULL OR o.otr_falla = @FALLA)
  AND   (@PLAN IS NULL OR pma.pma_id = @PLAN)
  AND   (@DESDE IS NULL OR o.otr_fecha_creacion >= CAST(@DESDE AS DATETIME))
  AND   (@HASTA IS NULL OR o.otr_fecha_creacion <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
  AND   (@FILTRO IS NULL OR o.otr_titulo LIKE '%' + @FILTRO + '%' OR CAST(o.otr_correlativo AS NVARCHAR(20)) = @FILTRO
                         OR act.act_codigo LIKE '%' + @FILTRO + '%' OR act.act_nombre LIKE '%' + @FILTRO + '%')
-- La bandeja de cierre pide antiguedad primero; el listado, lo mas nuevo primero.
ORDER BY CASE WHEN @ESTADO = 3 THEN o.otr_fecha_actualizacion END ASC,
         o.otr_correlativo DESC
OFFSET (@PAGINA - 1) * @TAMANO ROWS
FETCH NEXT @TAMANO ROWS ONLY
GO

/* ========================================================================
   22. SEL_PROGRAMACION (384: sin las privadas)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROGRAMACION]
    @CLIENTE        INT,
    @ID             INT = NULL,
    @TIPO           INT = NULL,
    @FILTRO         VARCHAR(200) = NULL,
    @HABILITADO     BIT = NULL,
    @VIGENTE        BIT = NULL
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @HOY DATE

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA](@PAIS) AS DATE)

    SELECT  p.pro_id,
            p.pro_cliente,
            p.pro_programacion_tipo,
            t.pti_codigo                        AS TIPO_CODIGO,
            t.pti_nombre                        AS TIPO_NOMBRE,
            p.pro_zona_horaria,
            ISNULL(z.zho_nombre, '')            AS ZONA_HORARIA_NOMBRE,
            p.pro_nombre,
            p.pro_fecha_inicio,
            p.pro_fecha_fin,
            p.pro_tolerancia_antes_minuto,
            p.pro_tolerancia_despues_minuto,
            p.pro_permite_anticipada,
            p.pro_permite_atrasada,
            p.pro_cumplimiento_politica,
            ISNULL(c.cpo_nombre, '')            AS CUMPLIMIENTO_POLITICA_NOMBRE,
            p.pro_genera_automaticamente,

            /* ---- Alcance: donde se hace ----
               Los tres niveles viajan juntos con su nombre resuelto, para que
               la ficha no tenga que consultar tres catalogos solo para
               escribir un encabezado. */
            p.pro_cliente_instalacion,
            ISNULL(ins.cin_nombre, '')          AS INSTALACION_NOMBRE,
            p.pro_instalacion_area,
            ISNULL(ar.iar_nombre, '')           AS AREA_NOMBRE,
            p.pro_activo,
            ISNULL(ac.act_codigo, '')           AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')           AS ACTIVO_NOMBRE,

            /* ---- Asignacion: quien responde ---- */
            /* Los responsables ya no son UNA columna: una programacion puede
               tener varias personas sin que haya que inventarles una cuadrilla.
               Se entregan armados —nombres para mostrar, ids para volver a
               marcar en la ficha— y no con una segunda consulta por fila. */
            RESPONSABLES = ISNULL(STUFF((
                SELECT N', ' + u2.usu_nombre + N' ' + u2.usu_apellido_paterno
                FROM   [dbo].[Programacion_Responsable] r2
                JOIN   [dbo].[Usuario] u2 ON u2.usu_id = r2.prr_usuario
                WHERE  r2.prr_programacion = p.pro_id
                ORDER BY u2.usu_nombre, u2.usu_apellido_paterno
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), N''),

            /* MISMO ORDEN que RESPONSABLES, y por eso el JOIN: el listado
               empareja nombre e id por posicion para pintar cada avatar de su
               color. Sin este ORDER BY, el tercer nombre podia salir con el
               color del primero. */
            RESPONSABLES_IDS = ISNULL(STUFF((
                SELECT N',' + CAST(r3.prr_usuario AS NVARCHAR(10))
                FROM   [dbo].[Programacion_Responsable] r3
                JOIN   [dbo].[Usuario] u3 ON u3.usu_id = r3.prr_usuario
                WHERE  r3.prr_programacion = p.pro_id
                ORDER BY u3.usu_nombre, u3.usu_apellido_paterno
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N''),
            p.pro_grupo_trabajo,
            ISNULL(gt.gtr_nombre, '')          AS GRUPO_NOMBRE,

            p.pro_habilitado,
            p.pro_usuario_creacion,
            p.pro_fecha_creacion,
            p.pro_usuario_actualizacion,
            p.pro_fecha_actualizacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,

            /* Vigente = hoy cae dentro de la ventana. Se calcula, no se
               guarda: un estado guardado queda viejo al dia siguiente. */
            CAST(CASE WHEN p.pro_fecha_inicio <= @HOY
                       AND (p.pro_fecha_fin IS NULL OR p.pro_fecha_fin >= @HOY)
                      THEN 1 ELSE 0 END AS BIT)  AS VIGENTE,

            /* La descripcion del detalle segun el tipo. Un CASE aca y no
               cinco consultas desde el C#. */
            CASE t.pti_codigo
                WHEN 'FECHA UNICA' THEN
                    CAST((SELECT COUNT(*) FROM [dbo].[Programacion_Fecha] f
                           WHERE f.pfe_programacion = p.pro_id AND f.pfe_incluida = 1) AS VARCHAR(10))
                    + ' fecha(s)'
                WHEN 'CALENDARIO' THEN
                    ISNULL((SELECT TOP 1 fr.fre_nombre + ' cada ' + CAST(ca.pca_intervalo AS VARCHAR(10))
                            FROM [dbo].[Programacion_Calendario] ca
                            JOIN [dbo].[Frecuencia_Tipo] fr ON fr.fre_id = ca.pca_frecuencia_tipo
                            WHERE ca.pca_programacion = p.pro_id AND ca.pca_habilitado = 1), '')
                WHEN 'INTERVALO TIEMPO' THEN
                    ISNULL((SELECT TOP 1 'Cada ' + CAST(i.pin_cantidad AS VARCHAR(10)) + ' ' + u.uti_nombre
                            FROM [dbo].[Programacion_Intervalo] i
                            JOIN [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
                            WHERE i.pin_programacion = p.pro_id AND i.pin_habilitado = 1), '')
                WHEN 'MEDIDOR' THEN
                    ISNULL((SELECT TOP 1 'Cada ' + CAST(CAST(m.pme_cada_cantidad AS DECIMAL(18,2)) AS VARCHAR(20))
                                   + ' (' + am.ame_nombre + ')'
                            FROM [dbo].[Programacion_Medidor] m
                            JOIN [dbo].[Activo_Medidor] am ON am.ame_id = m.pme_activo_medidor
                            WHERE m.pme_programacion = p.pro_id AND m.pme_habilitado = 1), '')
                WHEN 'CONDICION' THEN
                    CAST((SELECT COUNT(*) FROM [dbo].[Programacion_Condicion] cc
                           WHERE cc.pco_programacion = p.pro_id AND cc.pco_habilitado = 1) AS VARCHAR(10))
                    + ' condicion(es)'
                ELSE ''
            END                                 AS DETALLE,

            (SELECT COUNT(*) FROM [dbo].[Programacion_Exclusion] e
              WHERE e.pxc_programacion = p.pro_id AND e.pxc_habilitado = 1) AS EXCLUSIONES,

            /* Cuantas ocurrencias colgaron de esta programacion. Es lo que
               HU-076 #4 exige conservar al deshabilitarla. */
            (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
              WHERE o.pmo_programacion = p.pro_id)                          AS OCURRENCIAS

    FROM    [dbo].[Programacion] p
    JOIN    [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
    LEFT JOIN [dbo].[Zona_Horaria] z ON z.zho_id = p.pro_zona_horaria
    LEFT JOIN [dbo].[Cliente_Instalacion] ins ON ins.cin_id = p.pro_cliente_instalacion
    LEFT JOIN [dbo].[Instalacion_Area] ar     ON ar.iar_id  = p.pro_instalacion_area
    LEFT JOIN [dbo].[Activo] ac               ON ac.act_id  = p.pro_activo
    LEFT JOIN [dbo].[Grupo_Trabajo] gt        ON gt.gtr_id  = p.pro_grupo_trabajo
    LEFT JOIN [dbo].[Cumplimiento_Politica] c ON c.cpo_id = p.pro_cumplimiento_politica
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.pro_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.pro_usuario_actualizacion
    WHERE   p.pro_cliente = @CLIENTE
      AND   (@ID IS NULL OR p.pro_id = @ID)
      /* 384 · RP-02: las frecuencias privadas de una intervención no se listan;
         por id sí (el editor de condición la abre en un panel). */
      AND   (@ID IS NOT NULL OR p.pro_es_privada = 0)
      AND   (@TIPO IS NULL OR p.pro_programacion_tipo = @TIPO)
      AND   (@HABILITADO IS NULL OR p.pro_habilitado = @HABILITADO)
      AND   (@VIGENTE IS NULL
             OR (@VIGENTE = 1 AND p.pro_fecha_inicio <= @HOY
                             AND (p.pro_fecha_fin IS NULL OR p.pro_fecha_fin >= @HOY))
             OR (@VIGENTE = 0 AND (p.pro_fecha_inicio > @HOY
                                   OR (p.pro_fecha_fin IS NOT NULL AND p.pro_fecha_fin < @HOY))))
      AND   (@FILTRO IS NULL OR p.pro_nombre LIKE '%' + @FILTRO + '%')
    /* Desempate por id: dos programaciones pueden llamarse parecido y sin
       esto la paginacion repite filas y se salta otras. */
    ORDER BY p.pro_nombre, p.pro_id
GO

/* ========================================================================
   23. SEL_PLAN_OCURRENCIA_BANDEJA (384: estado de la OT y responsable, OT-4)
   ======================================================================== */
-- ---------------------------------------------------------------------------
-- 2) SEL_PLAN_OCURRENCIA_BANDEJA (T-4179)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_OCURRENCIA_BANDEJA]
    @CLIENTE        INT,
    @SITUACION      VARCHAR(20)   = NULL,   -- VENCIDA / ATRASADA / DISPONIBLE / FUTURA / CERRADA
    @PLAN           INT           = NULL,
    @ACTIVO         INT           = NULL,
    @INSTALACION    INT           = NULL,
    @ESTADO         INT           = NULL,
    @DESDE          DATE          = NULL,
    @HASTA          DATE          = NULL,
    @SOLO_ABIERTAS  BIT           = 1,
    @SOLO_PARADA    BIT           = NULL,
    @FILTRO         NVARCHAR(200) = NULL,
    @PAGINA         INT           = NULL,
    @TAMANO         INT           = NULL
AS
BEGIN
    SET NOCOUNT ON

    IF (@PAGINA IS NULL OR @PAGINA < 1)  SET @PAGINA = 1
    IF (@TAMANO IS NULL OR @TAMANO < 1)  SET @TAMANO = 1000000

    SET @SITUACION = NULLIF(LTRIM(RTRIM(UPPER(ISNULL(@SITUACION, '')))), '')

    DECLARE @HOY DATETIME = GETUTCDATE()

    /* El CTE existe para poder FILTRAR por la situacion. Calcularla en el
       SELECT y repetir el CASE entero en el WHERE es la otra forma, y es la
       que se desincroniza: alguien corrige una de las dos copias. */
    ;WITH ocu AS (
        SELECT  pmo.pmo_id,
                pmo.pmo_uuid,
                pmo.pmo_fecha_programada_utc,
                pmo.pmo_fecha_limite_utc,
                pmo.pmo_fecha_disponible_utc,
                pmo.pmo_fecha_programada_original_utc,
                pmo.pmo_ocurrencia_origen,
                pmo.pmo_valor_medidor_objetivo,
                pmo.pmo_observacion,
                pmo.pmo_orden_trabajo,
                pmo.pmo_plan_mantenimiento_hito,
                pmo.pmo_activo,
                pmo.pmo_activo_componente,
                pmo.pmo_plan_ocurrencia_estado,
                CASE
                    WHEN pmo.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7)                                    THEN 'CERRADA'
                    WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY          THEN 'VENCIDA'
                    WHEN pmo.pmo_fecha_programada_utc < @HOY                                               THEN 'ATRASADA'
                    WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                    ELSE 'FUTURA'
                END AS SITUACION
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          /* La bandeja es de lo que hay que hacer. Las cerradas se piden a
             proposito, con @SOLO_ABIERTAS = 0, y entonces se ven todas. */
          AND   (ISNULL(@SOLO_ABIERTAS, 1) = 0 OR pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3))
          AND   (@ESTADO IS NULL OR pmo.pmo_plan_ocurrencia_estado = @ESTADO)
          AND   (@DESDE  IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA  IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
    ),
    filtrada AS (
        SELECT  o.*,
                pma.pma_id      AS PLAN_ID,
                pma.pma_codigo  AS PLAN_CODIGO,
                pma.pma_nombre  AS PLAN_NOMBRE,
                pmv.pmv_numero  AS VERSION_NUMERO,
                pmh.pmh_id      AS HITO_ID,
                pmh.pmh_codigo  AS HITO_CODIGO,
                pmh.pmh_nombre  AS HITO_NOMBRE,
                pmh.pmh_es_overhaul               AS ES_OVERHAUL,
                pmh.pmh_requiere_parada           AS REQUIERE_PARADA,
                pmh.pmh_duracion_estimada_minuto  AS DURACION_ESTIMADA_MINUTO,
                act.act_id      AS ACTIVO_ID,
                act.act_codigo  AS ACTIVO_CODIGO,
                act.act_nombre  AS ACTIVO_NOMBRE,
                act.act_cliente_instalacion AS INSTALACION_ID,
                cin.cin_nombre  AS PLANTA_NOMBRE,
                aco.aco_nombre  AS COMPONENTE_NOMBRE,
                poe.poe_id      AS ESTADO_ID,
                poe.poe_codigo  AS ESTADO_CODIGO,
                poe.poe_nombre  AS ESTADO_NOMBRE,
                otr.otr_id          AS ORDEN_TRABAJO_ID,
                otr.otr_correlativo AS ORDEN_TRABAJO_CORRELATIVO,
                otr.otr_titulo      AS ORDEN_TRABAJO_TITULO,
                otr.otr_orden_trabajo_estado AS ORDEN_TRABAJO_ESTADO_ID,
                ote.ote_nombre      AS ORDEN_TRABAJO_ESTADO,
                pmh.pmh_usuario_responsable AS RESPONSABLE_ID,
                LTRIM(RTRIM(ISNULL(urs.usu_nombre, N'') + N' ' + ISNULL(urs.usu_apellido_paterno, N''))) AS RESPONSABLE_NOMBRE,
                /* Cuantas actividades trae el hito: una ocurrencia cuyo hito
                   no tiene ninguna genera una orden con un solo paso -el
                   hito- y conviene saberlo antes de generarla. */
                ISNULL(actv.cuantas, 0) AS ACTIVIDADES
        FROM    ocu o
        JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = o.pmo_plan_mantenimiento_hito
        JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
        JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
        JOIN    [dbo].[Activo]                     act ON act.act_id = o.pmo_activo
        JOIN    [dbo].[Plan_Ocurrencia_Estado]     poe ON poe.poe_id = o.pmo_plan_ocurrencia_estado
        LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = act.act_cliente_instalacion
        LEFT JOIN [dbo].[Activo_Componente]        aco ON aco.aco_id = o.pmo_activo_componente
        LEFT JOIN [dbo].[Orden_Trabajo]            otr ON otr.otr_id = o.pmo_orden_trabajo
        LEFT JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.ote_id = otr.otr_orden_trabajo_estado
        LEFT JOIN [dbo].[Usuario]                  urs ON urs.usu_id = pmh.pmh_usuario_responsable
        OUTER APPLY (SELECT COUNT(*) AS cuantas FROM [dbo].[Plan_Mantenimiento_Actividad] a
                      WHERE a.paa_plan_mantenimiento_hito = pmh.pmh_id AND a.paa_habilitado = 1) actv
        WHERE   (@SITUACION   IS NULL OR o.SITUACION = @SITUACION)
          AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
          AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
          AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
          AND   (@SOLO_PARADA IS NULL OR pmh.pmh_requiere_parada = @SOLO_PARADA)
          AND   (@FILTRO      IS NULL OR act.act_codigo LIKE '%' + @FILTRO + '%'
                                      OR act.act_nombre LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_codigo LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_nombre LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_codigo LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_nombre LIKE '%' + @FILTRO + '%'
                                      OR cin.cin_nombre LIKE '%' + @FILTRO + '%')
    )
    SELECT  f.pmo_id                                AS PMO_ID,
            f.pmo_uuid                              AS PMO_UUID,
            f.pmo_fecha_programada_utc              AS FECHA_PROGRAMADA,
            f.pmo_fecha_limite_utc                  AS FECHA_LIMITE,
            f.pmo_fecha_disponible_utc              AS FECHA_DISPONIBLE,
            f.pmo_fecha_programada_original_utc     AS FECHA_ORIGINAL,
            f.PLAN_ID, f.PLAN_CODIGO, f.PLAN_NOMBRE, f.VERSION_NUMERO,
            f.HITO_ID, f.HITO_CODIGO, f.HITO_NOMBRE,
            f.ES_OVERHAUL, f.REQUIERE_PARADA, f.DURACION_ESTIMADA_MINUTO,
            f.ACTIVO_ID, f.ACTIVO_CODIGO, f.ACTIVO_NOMBRE, f.INSTALACION_ID,
            f.PLANTA_NOMBRE, f.COMPONENTE_NOMBRE,
            f.pmo_valor_medidor_objetivo            AS VALOR_MEDIDOR_OBJETIVO,
            f.ESTADO_ID, f.ESTADO_CODIGO, f.ESTADO_NOMBRE,
            f.SITUACION,
            f.ACTIVIDADES,
            /* Negativo = ya paso. La pantalla lo lee como "hace N dias" sin
               volver a comparar fechas, que es donde se cuelan los off-by-one. */
            DATEDIFF(DAY, @HOY, f.pmo_fecha_programada_utc) AS DIAS_RESTANTES,
            CASE WHEN f.pmo_fecha_limite_utc IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, @HOY, f.pmo_fecha_limite_utc) END AS DIAS_PARA_LIMITE,
            CASE WHEN f.pmo_ocurrencia_origen IS NULL THEN 0 ELSE 1 END AS FUE_REPROGRAMADA,
            f.ORDEN_TRABAJO_ID, f.ORDEN_TRABAJO_CORRELATIVO, f.ORDEN_TRABAJO_TITULO,
            f.ORDEN_TRABAJO_ESTADO_ID, f.ORDEN_TRABAJO_ESTADO, f.RESPONSABLE_ID, f.RESPONSABLE_NOMBRE,
            f.pmo_observacion                       AS OBSERVACION,
            COUNT(*) OVER ()                        AS TOTAL

    FROM    filtrada f

    /* Lo mas urgente primero, y dentro del mismo dia lo que tiene fecha
       limite mas cerca: dos ocurrencias del mismo dia no son igual de
       urgentes si una vence mañana. */
    ORDER BY CASE f.SITUACION
                WHEN 'VENCIDA'    THEN 1
                WHEN 'ATRASADA'   THEN 2
                WHEN 'DISPONIBLE' THEN 3
                WHEN 'FUTURA'     THEN 4
                ELSE 5
             END,
             f.pmo_fecha_programada_utc,
             f.pmo_fecha_limite_utc,
             f.ACTIVO_CODIGO
    OFFSET (@PAGINA - 1) * @TAMANO ROWS
    FETCH NEXT @TAMANO ROWS ONLY

    /* ------------------------------------------------------------------
       Segundo result set: el resumen.

       Cuenta TODO lo que cumple el filtro, no la pagina. Por eso no se puede
       armar contando filas en la pantalla, y por eso no se pide con una
       segunda llamada: seria repetir la misma consulta pesada dos veces.

       El @SITUACION NO se aplica aca a proposito: los contadores son la
       botonera con la que se cambia de situacion, y si se filtraran a si
       mismos, al entrar en "vencidas" el resto marcaria cero y no habria
       como salir.
       ------------------------------------------------------------------ */
    ;WITH ocu2 AS (
        SELECT  CASE
                    WHEN pmo.pmo_plan_ocurrencia_estado IN (4, 5, 6, 7)                                    THEN 'CERRADA'
                    WHEN pmo.pmo_fecha_limite_utc IS NOT NULL AND pmo.pmo_fecha_limite_utc < @HOY          THEN 'VENCIDA'
                    WHEN pmo.pmo_fecha_programada_utc < @HOY                                               THEN 'ATRASADA'
                    WHEN pmo.pmo_fecha_disponible_utc IS NOT NULL AND pmo.pmo_fecha_disponible_utc <= @HOY THEN 'DISPONIBLE'
                    ELSE 'FUTURA'
                END AS SITUACION,
                pmh.pmh_requiere_parada AS REQUIERE_PARADA
        FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
        JOIN    [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = pmo.pmo_plan_mantenimiento_hito
        JOIN    [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
        JOIN    [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
        JOIN    [dbo].[Activo]                     act ON act.act_id = pmo.pmo_activo
        LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = act.act_cliente_instalacion
        WHERE   pmo.pmo_cliente    = @CLIENTE
          AND   pmo.pmo_habilitado = 1
          AND   (ISNULL(@SOLO_ABIERTAS, 1) = 0 OR pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3))
          AND   (@ESTADO      IS NULL OR pmo.pmo_plan_ocurrencia_estado = @ESTADO)
          AND   (@DESDE       IS NULL OR pmo.pmo_fecha_programada_utc >= CAST(@DESDE AS DATETIME))
          AND   (@HASTA       IS NULL OR pmo.pmo_fecha_programada_utc <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
          AND   (@PLAN        IS NULL OR pma.pma_id = @PLAN)
          AND   (@ACTIVO      IS NULL OR act.act_id = @ACTIVO)
          AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
          AND   (@SOLO_PARADA IS NULL OR pmh.pmh_requiere_parada = @SOLO_PARADA)
          AND   (@FILTRO      IS NULL OR act.act_codigo LIKE '%' + @FILTRO + '%'
                                      OR act.act_nombre LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_codigo LIKE '%' + @FILTRO + '%'
                                      OR pmh.pmh_nombre LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_codigo LIKE '%' + @FILTRO + '%'
                                      OR pma.pma_nombre LIKE '%' + @FILTRO + '%'
                                      OR cin.cin_nombre LIKE '%' + @FILTRO + '%')
    )
    SELECT  SUM(CASE WHEN SITUACION = 'VENCIDA'    THEN 1 ELSE 0 END) AS VENCIDAS,
            SUM(CASE WHEN SITUACION = 'ATRASADA'   THEN 1 ELSE 0 END) AS ATRASADAS,
            SUM(CASE WHEN SITUACION = 'DISPONIBLE' THEN 1 ELSE 0 END) AS DISPONIBLES,
            SUM(CASE WHEN SITUACION = 'FUTURA'     THEN 1 ELSE 0 END) AS FUTURAS,
            SUM(CASE WHEN SITUACION = 'CERRADA'    THEN 1 ELSE 0 END) AS CERRADAS,
            SUM(CASE WHEN REQUIERE_PARADA = 1 AND SITUACION IN ('VENCIDA','ATRASADA','DISPONIBLE') THEN 1 ELSE 0 END) AS CON_PARADA,
            COUNT(*) AS TOTAL
    FROM    ocu2
END
GO

/* ========================================================================
   24. DEL_PLAN_MANTENIMIENTO (384: deshabilita sus versiones)
   ======================================================================== */
-- ---------------------------------------------------------------------------
-- 4) DEL_PLAN_MANTENIMIENTO — baja logica
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_MANTENIMIENTO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = pma_cliente FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    /* Con ocurrencias generadas el plan es historia de mantencion: hay
       ordenes de trabajo que nacieron de el. Se rechaza, y el mensaje dice
       que hacer en vez de solo decir que no. */
    IF EXISTS (SELECT 1
               FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
               INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    h ON h.pmh_id  = o.pmo_plan_mantenimiento_hito
               INNER JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id  = h.pmh_plan_mantenimiento_version
               WHERE  v.pmv_plan_mantenimiento = @ID)
    BEGIN
        RAISERROR('2.- EL PLAN YA GENERÓ MANTENCIONES Y NO SE PUEDE ELIMINAR. RETIRE SU VERSIÓN PUBLICADA Y DESHABILÍTELO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version]
                WHERE pmv_plan_mantenimiento = @ID AND pmv_plan_version_estado = 2)
    BEGIN
        RAISERROR('3.- EL PLAN TIENE UNA VERSIÓN PUBLICADA. RETÍRELA ANTES DE ELIMINARLO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento]
    SET     pma_habilitado            = 0
           ,pma_usuario_actualizacion = @USUARIO
           ,pma_fecha_actualizacion   = @DATE_NOW
    WHERE   pma_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_MANTENIMIENTO ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
             @MSG = '4.- NO FUE POSIBLE ELIMINAR EL PLAN.'
        RETURN -1
    END

    /* 384: el plan eliminado deja de listarse en el Centro aunque tenga
       versiones retiradas (inactivo distinto de eliminado). */
    UPDATE [dbo].[Plan_Mantenimiento_Version]
    SET    pmv_habilitado = 0, pmv_usuario_actualizacion = @USUARIO, pmv_fecha_actualizacion = @DATE_NOW
    WHERE  pmv_plan_mantenimiento = @ID

COMMIT TRANSACTION

RETURN(0)
GO

/* ========================================================================
   25. INS_PLAN_VERSION_NUEVA (384)
       El borrador siguiente, copia de la vigente. Ahora copia también el
       responsable y el grupo de cada hito y los REPUESTOS planificados de las
       actividades (antes se perdían al abrir una versión nueva). Es el
       borrador implícito del Centro (RP-04).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_VERSION_NUEVA]
@ID          INT = NULL OUTPUT,
@CLIENTE     INT,
@PLAN        INT,
@OBSERVACION NVARCHAR(1000) = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE AND pma_habilitado = 1)
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE O ESTÁ DESHABILITADO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1)
BEGIN
    RAISERROR('2.- EL PLAN YA TIENE UNA VERSIÓN EN BORRADOR; EDÍTELA O PUBLÍQUELA ANTES DE ABRIR OTRA.', 16, 1)
    RETURN -1
END

-- La version que manda: la publicada; si no hay, la ultima que exista.
DECLARE @ORIGEN INT = [dbo].[FNC_PLAN_VERSION_VIGENTE](@PLAN)
IF @ORIGEN IS NULL
    SET @ORIGEN = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)

DECLARE @NUMERO INT = ISNULL((SELECT MAX(pmv_numero) FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_plan_mantenimiento = @PLAN), 0) + 1

BEGIN TRY
    BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Version]
        (pmv_plan_mantenimiento, pmv_numero, pmv_plan_version_estado, pmv_observacion,
         pmv_usuario_creacion, pmv_fecha_creacion, pmv_usuario_actualizacion, pmv_fecha_actualizacion, pmv_habilitado)
    VALUES
        (@PLAN, @NUMERO, 1, @OBSERVACION, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @ORIGEN IS NOT NULL
    BEGIN
        -- Hitos (384: tambien los deshabilitados: en el Centro, deshabilitar
        -- una intervencion es un estado, no una baja), con su mapa
        DECLARE @MAPA TABLE (viejo INT, nuevo INT)

        MERGE [dbo].[Plan_Mantenimiento_Hito] AS destino
        USING (SELECT * FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @ORIGEN) AS h
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (pmh_plan_mantenimiento_version, pmh_programacion, pmh_codigo, pmh_nombre, pmh_orden, pmh_valor_medidor,
                    pmh_unidad_medida, pmh_es_overhaul, pmh_requiere_parada, pmh_duracion_estimada_minuto,
                    pmh_orden_trabajo_tipo, pmh_orden_trabajo_prioridad, pmh_descripcion,
                    pmh_usuario_responsable, pmh_grupo_trabajo,
                    pmh_usuario_creacion, pmh_fecha_creacion, pmh_usuario_actualizacion, pmh_fecha_actualizacion, pmh_habilitado)
            VALUES (@ID, h.pmh_programacion, h.pmh_codigo, h.pmh_nombre, h.pmh_orden, h.pmh_valor_medidor,
                    h.pmh_unidad_medida, h.pmh_es_overhaul, h.pmh_requiere_parada, h.pmh_duracion_estimada_minuto,
                    h.pmh_orden_trabajo_tipo, h.pmh_orden_trabajo_prioridad, h.pmh_descripcion,
                    h.pmh_usuario_responsable, h.pmh_grupo_trabajo,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, h.pmh_habilitado)
        OUTPUT h.pmh_id, inserted.pmh_id INTO @MAPA (viejo, nuevo);

        -- Actividades de cada hito (HU-082), con su mapa para los repuestos
        DECLARE @MAPA_ACT TABLE (viejo INT, nuevo INT)

        MERGE [dbo].[Plan_Mantenimiento_Actividad] AS d
        USING (SELECT a.*, m.nuevo AS hito_nuevo FROM [dbo].[Plan_Mantenimiento_Actividad] a JOIN @MAPA m ON m.viejo = a.paa_plan_mantenimiento_hito
                WHERE a.paa_habilitado = 1) AS a
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion, paa_orden,
                    paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada, paa_requiere_permiso, paa_permiso_trabajo_tipo,
                    paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion, paa_habilitado)
            VALUES (a.hito_nuevo, a.paa_procedimiento, a.paa_codigo, a.paa_nombre, a.paa_descripcion, a.paa_orden,
                    a.paa_duracion_estimada_minuto, a.paa_obligatoria, a.paa_requiere_parada, a.paa_requiere_permiso, a.paa_permiso_trabajo_tipo,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT a.paa_id, inserted.paa_id INTO @MAPA_ACT (viejo, nuevo);

        -- 384: los repuestos planificados viajan con su actividad
        INSERT [dbo].[Plan_Actividad_Repuesto]
            (pra_plan_mantenimiento_actividad, pra_repuesto, pra_cantidad, pra_unidad_medida, pra_obligatorio, pra_observacion,
             pra_usuario_creacion, pra_fecha_creacion)
        SELECT m.nuevo, r.pra_repuesto, r.pra_cantidad, r.pra_unidad_medida, r.pra_obligatorio, r.pra_observacion, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Actividad_Repuesto] r JOIN @MAPA_ACT m ON m.viejo = r.pra_plan_mantenimiento_actividad

        -- Equipos
        INSERT [dbo].[Plan_Mantenimiento_Activo]
            (pac_plan_mantenimiento_version, pac_activo, pac_activo_componente, pac_activo_medidor, pac_usuario_creacion, pac_fecha_creacion)
        SELECT @ID, pac_activo, pac_activo_componente, pac_activo_medidor, @USUARIO, @DATE_NOW
        FROM   [dbo].[Plan_Mantenimiento_Activo]
        WHERE  pac_plan_mantenimiento_version = @ORIGEN
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_PLAN_VERSION_NUEVA', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE ABRIR LA VERSIÓN NUEVA: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

/* ========================================================================
   26. UPS_PLAN_BORRADOR_ASEGURAR (RP-04 · borrador implícito)
       Toda escritura del Centro sobre la estructura de un plan (activos,
       intervenciones, actividades, repuestos) pasa antes por aquí:
        - valida que el plan sea del cliente y esté habilitado;
        - si está publicado sin borrador, abre el borrador (copia);
        - traduce los ids que trae la pantalla (que pueden ser de la versión
          publicada) a sus equivalentes en el borrador: hito por código,
          actividad por código dentro del hito, vínculo por activo y
          componente, repuesto por actividad y repuesto.
       CREADO = 1 avisa a la pantalla que debe volver a pintar la ficha.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_BORRADOR_ASEGURAR]
    @CLIENTE   INT,
    @PLAN      INT,
    @HITO      INT = NULL,
    @ACTIVIDAD INT = NULL,
    @VINCULO   INT = NULL,
    @REPUESTO  INT = NULL,
    @USUARIO   INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @D INT, @R INT, @CREADO BIT = 0

SELECT @HAB = pma_habilitado FROM [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE
IF @HAB IS NULL
BEGIN
    RAISERROR('1.- EL PLAN NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @HAB = 0
BEGIN
    RAISERROR('2.- EL PLAN ESTÁ INACTIVO: REACTÍVELO PARA EDITARLO.', 16, 1)
    RETURN -1
END

/* Los ids que llegan tienen que ser de ESTE plan (de cualquier versión). */
IF @HITO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] h
            JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
            WHERE h.pmh_id = @HITO AND v.pmv_plan_mantenimiento = @PLAN)
BEGIN
    RAISERROR('3.- LA INTERVENCIÓN NO ES DE ESTE PLAN.', 16, 1)
    RETURN -1
END
IF @ACTIVIDAD IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] a
            JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
            JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
            WHERE a.paa_id = @ACTIVIDAD AND v.pmv_plan_mantenimiento = @PLAN)
BEGIN
    RAISERROR('4.- LA ACTIVIDAD NO ES DE ESTE PLAN.', 16, 1)
    RETURN -1
END
IF @VINCULO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] a
            JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = a.pac_plan_mantenimiento_version
            WHERE a.pac_id = @VINCULO AND v.pmv_plan_mantenimiento = @PLAN)
BEGIN
    RAISERROR('5.- EL ACTIVO NO ES DE ESTE PLAN.', 16, 1)
    RETURN -1
END
IF @REPUESTO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Actividad_Repuesto] r
            JOIN [dbo].[Plan_Mantenimiento_Actividad] a ON a.paa_id = r.pra_plan_mantenimiento_actividad
            JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = a.paa_plan_mantenimiento_hito
            JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
            WHERE r.pra_id = @REPUESTO AND v.pmv_plan_mantenimiento = @PLAN)
BEGIN
    RAISERROR('6.- EL REPUESTO NO ES DE ESTE PLAN.', 16, 1)
    RETURN -1
END

SELECT TOP 1 @D = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_plan_version_estado = 1 AND pmv_habilitado = 1 ORDER BY pmv_numero DESC

IF @D IS NULL
BEGIN
    EXEC @R = [dbo].[INS_PLAN_VERSION_NUEVA] @ID = @D OUTPUT, @CLIENTE = @CLIENTE, @PLAN = @PLAN, @USUARIO = @USUARIO
    IF ISNULL(@R, -1) <> 0 OR @D IS NULL RETURN -1
    SET @CREADO = 1
END

DECLARE @H INT = NULL, @A INT = NULL, @V INT = NULL, @P INT = NULL

IF @HITO IS NOT NULL
    SELECT TOP 1 @H = d.pmh_id FROM [dbo].[Plan_Mantenimiento_Hito] o
      JOIN [dbo].[Plan_Mantenimiento_Hito] d ON d.pmh_plan_mantenimiento_version = @D AND d.pmh_codigo = o.pmh_codigo
     WHERE o.pmh_id = @HITO

IF @ACTIVIDAD IS NOT NULL
    SELECT TOP 1 @A = da.paa_id
      FROM [dbo].[Plan_Mantenimiento_Actividad] oa
      JOIN [dbo].[Plan_Mantenimiento_Hito] oh ON oh.pmh_id = oa.paa_plan_mantenimiento_hito
      JOIN [dbo].[Plan_Mantenimiento_Hito] dh ON dh.pmh_plan_mantenimiento_version = @D AND dh.pmh_codigo = oh.pmh_codigo
      JOIN [dbo].[Plan_Mantenimiento_Actividad] da ON da.paa_plan_mantenimiento_hito = dh.pmh_id AND da.paa_codigo = oa.paa_codigo AND da.paa_habilitado = 1
     WHERE oa.paa_id = @ACTIVIDAD

IF @VINCULO IS NOT NULL
    SELECT TOP 1 @V = d.pac_id FROM [dbo].[Plan_Mantenimiento_Activo] o
      JOIN [dbo].[Plan_Mantenimiento_Activo] d ON d.pac_plan_mantenimiento_version = @D AND d.pac_activo = o.pac_activo
           AND ISNULL(d.pac_activo_componente, 0) = ISNULL(o.pac_activo_componente, 0)
     WHERE o.pac_id = @VINCULO

IF @REPUESTO IS NOT NULL
    SELECT TOP 1 @P = dr.pra_id
      FROM [dbo].[Plan_Actividad_Repuesto] orp
      JOIN [dbo].[Plan_Mantenimiento_Actividad] oa ON oa.paa_id = orp.pra_plan_mantenimiento_actividad
      JOIN [dbo].[Plan_Mantenimiento_Hito] oh ON oh.pmh_id = oa.paa_plan_mantenimiento_hito
      JOIN [dbo].[Plan_Mantenimiento_Hito] dh ON dh.pmh_plan_mantenimiento_version = @D AND dh.pmh_codigo = oh.pmh_codigo
      JOIN [dbo].[Plan_Mantenimiento_Actividad] da ON da.paa_plan_mantenimiento_hito = dh.pmh_id AND da.paa_codigo = oa.paa_codigo AND da.paa_habilitado = 1
      JOIN [dbo].[Plan_Actividad_Repuesto] dr ON dr.pra_plan_mantenimiento_actividad = da.paa_id AND dr.pra_repuesto = orp.pra_repuesto
     WHERE orp.pra_id = @REPUESTO

SELECT @D AS BORRADOR, @CREADO AS CREADO, @H AS HITO, @A AS ACTIVIDAD, @V AS VINCULO, @P AS REPUESTO
RETURN(0)
GO

/* ========================================================================
   27. SEL_PLAN_ACTIVO_CANDIDATO (§11.3 · CA-07)
       Los activos que se pueden agregar al plan: el motivo de los que no
       calzan con el alcance (van al final, deshabilitados), cuántos planes
       activos los cubren y si ya están en la versión de edición.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_ACTIVO_CANDIDATO]
    @CLIENTE INT,
    @PLAN    INT = NULL,
    @FILTRO  NVARCHAR(200) = NULL
AS
SET NOCOUNT ON

DECLARE @PLANTA INT, @TIPO INT, @MODELO INT, @VER INT
SELECT @PLANTA = pma_cliente_instalacion, @TIPO = pma_activo_tipo, @MODELO = pma_activo_modelo
FROM   [dbo].[Plan_Mantenimiento] WHERE pma_id = @PLAN AND pma_cliente = @CLIENTE

SELECT TOP 1 @VER = pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
 WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 AND pmv_plan_version_estado IN (1, 2, 3)
 ORDER BY CASE pmv_plan_version_estado WHEN 1 THEN 0 WHEN 2 THEN 1 ELSE 2 END, pmv_numero DESC

SET @FILTRO = NULLIF(LTRIM(RTRIM(@FILTRO)), N'')

SELECT  act.act_id AS ACTIVO_ID, act.act_codigo AS CODIGO, act.act_nombre AS NOMBRE,
        act.act_cliente_instalacion AS PLANTA_ID, cin.cin_nombre AS PLANTA,
        act.act_instalacion_area AS AREA_ID, iar.iar_nombre AS AREA,
        act.act_activo_tipo AS TIPO_ID, ati.ati_nombre AS TIPO,
        act.act_activo_modelo AS MODELO_ID, amo.amo_nombre AS MODELO,
        CASE WHEN @PLANTA IS NOT NULL AND act.act_cliente_instalacion <> @PLANTA THEN N'Otra planta'
             WHEN @TIPO IS NOT NULL AND ISNULL(act.act_activo_tipo, 0) <> @TIPO THEN N'Otro tipo'
             WHEN @MODELO IS NOT NULL AND ISNULL(act.act_activo_modelo, 0) <> @MODELO THEN N'Otro modelo'
             ELSE NULL END AS MOTIVO,
        ISNULL(cob.n, 0) AS PLANES,
        cob.codigos AS PLANES_CODIGOS,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] x WHERE x.pac_plan_mantenimiento_version = @VER AND x.pac_activo = act.act_id AND x.pac_activo_componente IS NULL)
             THEN 1 ELSE 0 END AS BIT) AS YA_EN_PLAN,
        (SELECT COUNT(*) FROM [dbo].[Activo_Componente] c WHERE c.aco_activo = act.act_id AND c.aco_habilitado = 1) AS COMPONENTES,
        (SELECT COUNT(*) FROM [dbo].[Activo_Medidor] m WHERE m.ame_activo = act.act_id AND m.ame_habilitado = 1) AS MEDIDORES
FROM    [dbo].[Activo] act
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
LEFT JOIN [dbo].[Activo_Tipo] ati ON ati.ati_id = act.act_activo_tipo
LEFT JOIN [dbo].[Activo_Modelo] amo ON amo.amo_id = act.act_activo_modelo
OUTER APPLY (SELECT COUNT(DISTINCT p.pma_id) AS n, STRING_AGG(p.pma_codigo, N', ') AS codigos
               FROM [dbo].[Plan_Mantenimiento_Activo] a
               JOIN [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = a.pac_plan_mantenimiento_version AND v.pmv_plan_version_estado = 2 AND v.pmv_habilitado = 1
               JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento AND p.pma_habilitado = 1
              WHERE a.pac_activo = act.act_id AND p.pma_id <> ISNULL(@PLAN, 0)) cob
WHERE   act.act_cliente = @CLIENTE AND act.act_habilitado = 1 AND act.act_fecha_baja IS NULL
  AND   (@FILTRO IS NULL OR act.act_codigo LIKE N'%' + @FILTRO + N'%' OR act.act_nombre LIKE N'%' + @FILTRO + N'%'
         OR iar.iar_nombre LIKE N'%' + @FILTRO + N'%' OR ati.ati_nombre LIKE N'%' + @FILTRO + N'%')
ORDER BY CASE WHEN (@PLANTA IS NOT NULL AND act.act_cliente_instalacion <> @PLANTA)
                OR (@TIPO IS NOT NULL AND ISNULL(act.act_activo_tipo, 0) <> @TIPO)
                OR (@MODELO IS NOT NULL AND ISNULL(act.act_activo_modelo, 0) <> @MODELO) THEN 1 ELSE 0 END,
         act.act_codigo

/* Componentes y medidores de todos los activos, para editarlos antes de confirmar. */
SELECT  c.aco_activo AS ACTIVO_ID, c.aco_id AS ID, c.aco_nombre AS NOMBRE
FROM    [dbo].[Activo_Componente] c JOIN [dbo].[Activo] a ON a.act_id = c.aco_activo
WHERE   a.act_cliente = @CLIENTE AND c.aco_habilitado = 1
ORDER BY c.aco_activo, c.aco_nombre

SELECT  m.ame_activo AS ACTIVO_ID, m.ame_id AS ID, m.ame_nombre AS NOMBRE, m.ame_valor_actual AS VALOR, u.ume_simbolo AS UNIDAD
FROM    [dbo].[Activo_Medidor] m JOIN [dbo].[Activo] a ON a.act_id = m.ame_activo
LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = m.ame_unidad_medida
WHERE   a.act_cliente = @CLIENTE AND m.ame_habilitado = 1
ORDER BY m.ame_activo, m.ame_nombre

RETURN(0)
GO

/* ========================================================================
   28. SEL_PLAN_CENTRO_CATALOGO
       Los combos del Centro en una sola llamada:
        0 plantas · 1 tipos de activo · 2 modelos · 3 personas · 4 grupos ·
        5 tipos de OT · 6 prioridades · 7 tipos de permiso · 8 frecuencias ·
        9 unidades de tiempo · 10 días · 11 calendarios compartidos
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_CENTRO_CATALOGO]
    @CLIENTE INT
AS
SET NOCOUNT ON

SELECT cin_id AS ID, cin_nombre AS NOMBRE FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1 ORDER BY cin_nombre
SELECT ati_id AS ID, ati_nombre AS NOMBRE FROM [dbo].[Activo_Tipo] WHERE (ati_cliente = @CLIENTE OR ati_cliente IS NULL) AND ati_habilitado = 1 ORDER BY ati_nombre
SELECT amo_id AS ID, amo_nombre AS NOMBRE, amo_activo_tipo AS TIPO_ID FROM [dbo].[Activo_Modelo] WHERE (amo_cliente = @CLIENTE OR amo_cliente IS NULL) AND amo_habilitado = 1 ORDER BY amo_nombre
SELECT u.usu_id AS ID, LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS NOMBRE
FROM   [dbo].[Cliente_Usuario] cu JOIN [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
WHERE  cu.ucl_id_cliente = @CLIENTE AND cu.ucl_habilitado = 1 AND u.usu_habilitado = 1
ORDER BY 2
SELECT gtr_id AS ID, gtr_nombre AS NOMBRE FROM [dbo].[Grupo_Trabajo] WHERE gtr_cliente = @CLIENTE AND gtr_habilitado = 1 ORDER BY gtr_nombre
SELECT ott_id AS ID, ott_nombre AS NOMBRE FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_habilitado = 1 ORDER BY ott_orden
SELECT opr_id AS ID, opr_nombre AS NOMBRE FROM [dbo].[Orden_Trabajo_Prioridad] WHERE opr_habilitado = 1 ORDER BY opr_orden
SELECT ptt_id AS ID, ptt_nombre AS NOMBRE FROM [dbo].[Permiso_Trabajo_Tipo] WHERE (ptt_cliente = @CLIENTE OR ptt_cliente IS NULL) AND ptt_habilitado = 1 ORDER BY ptt_orden, ptt_nombre
SELECT fre_id AS ID, fre_codigo AS CODIGO, fre_nombre AS NOMBRE FROM [dbo].[Frecuencia_Tipo] ORDER BY fre_id
SELECT uti_id AS ID, uti_codigo AS CODIGO, uti_nombre AS NOMBRE FROM [dbo].[Unidad_Tiempo] ORDER BY uti_id
SELECT dse_id AS ID, dse_codigo AS CODIGO, dse_nombre AS NOMBRE FROM [dbo].[Dia_Semana] WHERE dse_habilitado = 1 ORDER BY dse_orden
SELECT p.pro_id AS ID, p.pro_nombre AS NOMBRE, t.pti_codigo AS TIPO_CODIGO, t.pti_nombre AS TIPO
FROM   [dbo].[Programacion] p JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
WHERE  p.pro_cliente = @CLIENTE AND p.pro_habilitado = 1 AND p.pro_es_privada = 0 AND t.pti_codigo <> 'ABIERTA'
ORDER BY p.pro_nombre

RETURN(0)
GO

PRINT '384_CENTRO_PLANIFICACION aplicado.'
GO
