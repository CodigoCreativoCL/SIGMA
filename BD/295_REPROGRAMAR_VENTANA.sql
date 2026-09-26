USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     AL REPROGRAMAR, LA VENTANA SE MUEVE CON LA FECHA (HU-086).
-- =============================================
-- EL DEFECTO
--
--   `PLAN_OCURRENCIA_REPROGRAMAR` (bloque 202) mueve la fecha programada y
--   le copia a la ocurrencia nueva la fecha limite y la fecha disponible de
--   la vieja, sin tocarlas. Esas tres fechas no son independientes: la
--   disponible es "desde cuando se puede adelantar" y la limite es "hasta
--   cuando se puede atrasar", las dos medidas desde la programada. Copiarlas
--   tal cual deja la ventana donde estaba y la fecha adentro de otro lugar.
--
--   Sale de dos formas, las dos malas:
--
--     - Si la fecha nueva pasa la limite vieja, el INSERT choca contra
--       CK_PMO_LIMITE y el SP devuelve "8.- The INSERT statement conflicted
--       with the CHECK constraint...", el mensaje de SQL crudo. O sea: correr
--       una mantencion mas alla de su tolerancia -el motivo mas comun para
--       reprogramar- simplemente no se podia.
--
--     - Si la fecha nueva no la pasa, es peor, porque funciona: la ocurrencia
--       nace con una limite anterior a su propia fecha programada o pegada a
--       ella, o sea ya vencida o a punto. Reprogramar para darse aire
--       producia una ocurrencia con menos aire que antes, sin avisar.
--
-- EL ARREGLO
--
--   La ventana se corre junto con la fecha: la misma distancia que se movio
--   la programada se mueve la limite y la disponible. La tolerancia que dio
--   la programacion se respeta -son los dias que esa mantencion admite- y lo
--   unico que cambia es cuando.
--
--   Se conserva todo lo demas del bloque 202: la vieja pasa a REPROGRAMADA
--   con su motivo, nace la nueva ligada por pmo_ocurrencia_origen, y
--   pmo_fecha_programada_original_utc sigue guardando la primera fecha de la
--   cadena, que es contra la que mide el cumplimiento (HU-086 #2).
--
-- TODO IDEMPOTENTE (CREATE OR ALTER).
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[PLAN_OCURRENCIA_REPROGRAMAR]
    @ID          INT,
    @CLIENTE     INT,
    @NUEVA_FECHA DATETIME,
    @MOTIVO      NVARCHAR(500),
    @USUARIO     INT,
    @NUEVO_ID    INT = NULL OUTPUT
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON

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
    RAISERROR('3.- INDIQUE EL MOTIVO DE LA REPROGRAMACIÓN.', 16, 1)
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

/* LA VENTANA SE MUEVE CON LA FECHA.

   La distancia que se corre la programada se corre la limite y la
   disponible: son "hasta cuando" y "desde cuando" medidas contra ella, no
   fechas sueltas. Copiarlas tal cual dejaba la ocurrencia nueva ya vencida
   -o hacia reventar el INSERT contra CK_PMO_LIMITE cuando el movimiento
   pasaba la tolerancia, que es el caso normal-. */
DECLARE @DESPLAZAMIENTO INT = DATEDIFF(MINUTE, @FECHA_ACT, @NUEVA_FECHA)

DECLARE @NUEVA_LIMITE DATETIME =
        CASE WHEN @FECHA_LIMITE IS NULL THEN NULL
             ELSE DATEADD(MINUTE, @DESPLAZAMIENTO, @FECHA_LIMITE) END

DECLARE @NUEVA_DISP DATETIME =
        CASE WHEN @FECHA_DISP IS NULL THEN NULL
             ELSE DATEADD(MINUTE, @DESPLAZAMIENTO, @FECHA_DISP) END

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
        RAISERROR('7.- LA OCURRENCIA YA NO ESTABA PENDIENTE. OTRO USUARIO LA MOVIÓ O GENERÓ SU ORDEN.', 16, 1)
        RETURN -1
    END

    -- 2) Nace la nueva en PENDIENTE, con la fecha nueva, su ventana corrida
    --    y ligada al origen. La fecha original se conserva: es la primera de
    --    la cadena y contra ella mide el cumplimiento.
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
         @NUEVA_LIMITE, @NUEVA_DISP,
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

RETURN 0
END
GO
PRINT '--- PLAN_OCURRENCIA_REPROGRAMAR corregido: la ventana se mueve con la fecha.'
GO

PRINT '295_REPROGRAMAR_VENTANA aplicado.'
GO
