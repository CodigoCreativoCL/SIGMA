/* ============================================================================
   393 · «Hoy» en hora de la planta al activar, aplicar y desactivar · 09-10-2026

   Sigue a BD/392. Las fechas de las ejecuciones están en hora de la planta,
   pero estos SP tomaban «hoy» de GETUTCDATE(): de 21:00 a 24:00 en Chile, UTC
   ya es mañana y las ejecuciones de HOY sin OT quedaban fuera de «las de hoy
   en adelante»:
     UPD_PLAN_ACTIVAR    · al aplicar cambios no se traspasaban ni cancelaban;
     UPD_PLAN_DESACTIVAR · al desactivar no se cancelaban;
     SEL_PLAN_IMPACTO    · la confirmación las contaba mal.
   Ahora «hoy» sale de [dbo].[FNC_AHORA]() (hora de Santiago, la de la
   pantalla). Solo cambia esa declaración; el resto es el de BD/384.
   ============================================================================ */

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

DECLARE @HOY DATETIME = CAST(CAST([dbo].[FNC_AHORA]() AS DATE) AS DATETIME)   -- 393: hora de la planta, como las fechas
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
DECLARE @HOY DATETIME = CAST(CAST([dbo].[FNC_AHORA]() AS DATE) AS DATETIME)   -- 393: hora de la planta, como las fechas
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

CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_DESACTIVAR]
    @CLIENTE INT,
    @PLAN    INT,
    @MOTIVO  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @HOY DATETIME = CAST(CAST([dbo].[FNC_AHORA]() AS DATE) AS DATETIME)   -- 393: hora de la planta, como las fechas
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

PRINT '393_HOY_PLANTA_ACTIVAR aplicado.'
GO
