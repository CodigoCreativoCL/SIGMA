USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-086) Reprogramar una ocurrencia indicando el motivo.
--                  T-4168/4169 PLAN_OCURRENCIA_REPROGRAMAR (proceso en una
--                              transaccion, XACT_ABORT ON, reglas en el SP).
--                  T-4170       SEL_PLAN_OCURRENCIA_REPROGRAMAR (consultar el
--                              resultado / la ficha de una ocurrencia).
--                  T-4171       datos de prueba (una ocurrencia reprogramada).
--
-- EL MODELO: NO SE PISA LA FECHA, SE DEJA CONSTANCIA
--   Reprogramar no es un UPDATE de la fecha encima de la vieja -eso borraria
--   que alguna vez se movio y por que-. La ocurrencia original pasa a
--   REPROGRAMADA (estado 7) con su motivo, y NACE una nueva en PENDIENTE con
--   la fecha nueva, ligada a la vieja por pmo_ocurrencia_origen. Asi el
--   historial queda: quien la movio, cuando, de que fecha a que fecha y por que.
--   pmo_fecha_programada_original_utc guarda SIEMPRE la primera fecha, aunque
--   se reprograme varias veces.
--
-- SOLO SE REPROGRAMA LO QUE TODAVIA NO OCURRIO
--   PENDIENTE (1) o DISPONIBLE (2). Una que ya esta EN EJECUCION, COMPLETADA,
--   OMITIDA, CANCELADA o ya REPROGRAMADA no se toca: mover una orden que ya
--   arranco o un hecho ya cerrado no tiene sentido.
--
-- LA COLISION LA DECIDE EL INDICE
--   UX_PMO_HITO_ACTIVO_FECHA y UX_PMO_PROGRAMACION_ACTIVO_FECHA impiden dos
--   ocurrencias del mismo hito/activo en la misma fecha. Si la fecha nueva ya
--   esta ocupada, se rechaza con mensaje claro en vez de un choque de indice.
--
-- REAPLICABLE (CREATE OR ALTER; demo idempotente por pmo_ocurrencia_origen).
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- T-4168/4169) PLAN_OCURRENCIA_REPROGRAMAR
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[PLAN_OCURRENCIA_REPROGRAMAR]
    @ID          INT,
    @CLIENTE     INT,
    @NUEVA_FECHA DATETIME,
    @MOTIVO      NVARCHAR(500),
    @USUARIO     INT,
    @NUEVO_ID    INT = NULL OUTPUT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

-- Datos de la ocurrencia a mover (y validaciones antes de abrir transaccion).
DECLARE @ESTADO INT, @HITO INT, @PROG INT, @ACTIVO INT, @COMPONENTE INT,
        @FECHA_ACT DATETIME, @FECHA_LIMITE DATETIME, @FECHA_DISP DATETIME,
        @FECHA_ORIG DATETIME, @VALOR DECIMAL(18,4)

SELECT  @ESTADO = pmo_plan_ocurrencia_estado,
        @HITO = pmo_plan_mantenimiento_hito,
        @PROG = pmo_programacion,
        @ACTIVO = pmo_activo,
        @COMPONENTE = pmo_activo_componente,
        @FECHA_ACT = pmo_fecha_programada_utc,
        @FECHA_LIMITE = pmo_fecha_limite_utc,
        @FECHA_DISP = pmo_fecha_disponible_utc,
        @FECHA_ORIG = pmo_fecha_programada_original_utc,
        @VALOR = pmo_valor_medidor_objetivo
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia]
WHERE   pmo_id = @ID AND pmo_cliente = @CLIENTE AND pmo_habilitado = 1

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA OCURRENCIA NO EXISTE.', 16, 1)
    RETURN -1
END

IF @ESTADO NOT IN (1, 2)   -- PENDIENTE o DISPONIBLE
BEGIN
    RAISERROR('2.- SOLO SE REPROGRAMA UNA OCURRENCIA PENDIENTE O DISPONIBLE.', 16, 1)
    RETURN -1
END

IF @MOTIVO IS NULL OR LTRIM(RTRIM(@MOTIVO)) = ''
BEGIN
    RAISERROR('3.- INDIQUE EL MOTIVO DE LA REPROGRAMACION.', 16, 1)
    RETURN -1
END

IF @NUEVA_FECHA IS NULL
BEGIN
    RAISERROR('4.- INDIQUE LA NUEVA FECHA.', 16, 1)
    RETURN -1
END

IF CONVERT(DATE, @NUEVA_FECHA) = CONVERT(DATE, @FECHA_ACT)
BEGIN
    RAISERROR('5.- LA NUEVA FECHA ES LA MISMA QUE LA ACTUAL.', 16, 1)
    RETURN -1
END

-- La fecha nueva no puede chocar con otra ocurrencia del mismo hito y activo.
IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia]
            WHERE pmo_plan_mantenimiento_hito = @HITO
              AND pmo_activo = @ACTIVO
              AND pmo_fecha_programada_utc = @NUEVA_FECHA)
BEGIN
    RAISERROR('6.- YA HAY UNA OCURRENCIA DE ESTE HITO Y EQUIPO EN ESA FECHA.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    -- 1) La vieja pasa a REPROGRAMADA con el motivo. La carrera se decide aqui:
    --    si otro ya la movio o genero su orden, @@ROWCOUNT sera 0.
    UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
       SET pmo_plan_ocurrencia_estado = 7,               -- REPROGRAMADA
           pmo_observacion            = @MOTIVO,
           pmo_usuario_actualizacion  = @USUARIO,
           pmo_fecha_actualizacion    = [dbo].[FNC_AHORA]()
     WHERE pmo_id = @ID
       AND pmo_plan_ocurrencia_estado IN (1, 2)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('7.- LA OCURRENCIA YA NO ESTABA PENDIENTE. OTRO USUARIO LA MOVIO O GENERO SU ORDEN.', 16, 1)
        RETURN -1
    END

    -- 2) Nace la nueva en PENDIENTE, con la fecha nueva y ligada al origen.
    --    La fecha original se conserva (la primera de la cadena).
    INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
        (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion,
         pmo_activo, pmo_activo_componente, pmo_fecha_programada_utc,
         pmo_fecha_limite_utc, pmo_fecha_disponible_utc,
         pmo_fecha_programada_original_utc, pmo_ocurrencia_origen,
         pmo_valor_medidor_objetivo, pmo_plan_ocurrencia_estado, pmo_observacion,
         pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
    VALUES
        (NEWID(), @CLIENTE, @HITO, @PROG,
         @ACTIVO, @COMPONENTE, @NUEVA_FECHA,
         @FECHA_LIMITE, @FECHA_DISP,
         ISNULL(@FECHA_ORIG, @FECHA_ACT), @ID,
         @VALOR, 1, @MOTIVO,
         @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @NUEVO_ID = SCOPE_IDENTITY()

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    RAISERROR('8.- %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- T-4170) SEL_PLAN_OCURRENCIA_REPROGRAMAR - la ficha de una ocurrencia: sirve
--         para cargar la pantalla y para mostrar el resultado del proceso.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_OCURRENCIA_REPROGRAMAR]
    @ID      INT,
    @CLIENTE INT
AS
SET NOCOUNT ON

SELECT  o.pmo_id                              AS PMO_ID,
        o.pmo_cliente                         AS PMO_CLIENTE,
        o.pmo_plan_ocurrencia_estado          AS PMO_ESTADO,
        poe.poe_nombre                        AS ESTADO_NOMBRE,
        o.pmo_fecha_programada_utc            AS PMO_FECHA_PROGRAMADA,
        o.pmo_fecha_programada_original_utc   AS PMO_FECHA_ORIGINAL,
        o.pmo_ocurrencia_origen               AS PMO_OCURRENCIA_ORIGEN,
        o.pmo_observacion                     AS PMO_OBSERVACION,
        o.pmo_orden_trabajo                   AS PMO_ORDEN_TRABAJO,
        o.pmo_activo                          AS PMO_ACTIVO,
        a.act_codigo                          AS ACTIVO_CODIGO,
        a.act_nombre                          AS ACTIVO_NOMBRE,
        h.pmh_codigo                          AS HITO_CODIGO,
        h.pmh_nombre                          AS HITO_NOMBRE,
        pma.pma_codigo                        AS PLAN_CODIGO,
        pma.pma_nombre                        AS PLAN_NOMBRE,
        o.pmo_fecha_actualizacion             AS PMO_FECHA_ACTUALIZACION,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
        -- Si esta ocurrencia fue reprogramada, a que fecha se movio (la de su hija).
        (SELECT TOP 1 hija.pmo_fecha_programada_utc
           FROM [dbo].[Plan_Mantenimiento_Ocurrencia] hija
          WHERE hija.pmo_ocurrencia_origen = o.pmo_id
          ORDER BY hija.pmo_id DESC)          AS PMO_FECHA_NUEVA,
        (SELECT TOP 1 hija.pmo_id
           FROM [dbo].[Plan_Mantenimiento_Ocurrencia] hija
          WHERE hija.pmo_ocurrencia_origen = o.pmo_id
          ORDER BY hija.pmo_id DESC)          AS PMO_OCURRENCIA_NUEVA
FROM    [dbo].[Plan_Mantenimiento_Ocurrencia] o
LEFT JOIN [dbo].[Plan_Ocurrencia_Estado]      poe ON poe.poe_id = o.pmo_plan_ocurrencia_estado
LEFT JOIN [dbo].[Activo]                      a   ON a.act_id = o.pmo_activo
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito]     h   ON h.pmh_id = o.pmo_plan_mantenimiento_hito
LEFT JOIN [dbo].[Plan_Mantenimiento_Version]  pmv ON pmv.pmv_id = h.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Plan_Mantenimiento]          pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Usuario]                     u   ON u.usu_id = o.pmo_usuario_actualizacion
WHERE   o.pmo_id = @ID
  AND   o.pmo_cliente = @CLIENTE
GO

-- ---------------------------------------------------------------------------
-- T-4171) Datos de prueba: reprograma una ocurrencia pendiente lejana (2027) a
--         una semana despues. Idempotente: solo si no se ha reprogramado ya.
-- ---------------------------------------------------------------------------
-- Siembra una sola vez: si ya hay alguna reprogramada, no agrega mas (asi
-- reaplicar el script no acumula ocurrencias reprogramadas de prueba).
DECLARE @DEMO INT =
    (SELECT TOP 1 pmo_id FROM [dbo].[Plan_Mantenimiento_Ocurrencia]
      WHERE pmo_cliente = 1 AND pmo_plan_ocurrencia_estado = 1
        AND pmo_fecha_programada_utc >= '2027-06-01'
      ORDER BY pmo_fecha_programada_utc DESC)

IF @DEMO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_plan_ocurrencia_estado = 7)
BEGIN
    DECLARE @NUEVA DATETIME, @FP DATETIME
    SELECT @FP = pmo_fecha_programada_utc FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_id = @DEMO
    SET @NUEVA = DATEADD(DAY, 7, @FP)
    DECLARE @NID INT
    EXEC [dbo].[PLAN_OCURRENCIA_REPROGRAMAR]
        @ID = @DEMO, @CLIENTE = 1, @NUEVA_FECHA = @NUEVA,
        @MOTIVO = N'Reprogramada por prueba (HU-086): se corre una semana por disponibilidad del equipo.',
        @USUARIO = 1, @NUEVO_ID = @NID OUTPUT
END
GO

SELECT 'ocurrencias reprogramadas' AS control, COUNT(*) AS valor
FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_plan_ocurrencia_estado = 7
GO

PRINT '202_SPRINT4_PLAN_OCURRENCIA_REPROGRAMAR aplicado.'
GO
