USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA EL CUMPLIMIENTO (HU-086 #2).
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   El indicador de cumplimiento ya funciona, pero sobre los datos que hay
--   marca 0%: las 17 ocurrencias "completadas" de la demo se marcaron todas
--   de una vez el 12-09, meses despues de sus fechas de enero a mayo. Contra
--   cualquier vara que se elija, eso es incumplimiento; medido asi, el
--   indicador es correcto y no dice nada.
--
--   Para verificar el criterio 2 -"se mide contra la fecha programada
--   original y no contra la nueva"- hace falta exactamente un caso: una
--   ocurrencia REPROGRAMADA y despues cumplida DENTRO de la fecha nueva pero
--   FUERA de la original. Es el unico caso donde las dos varas dan distinto,
--   y por lo tanto el unico que prueba cual se esta usando.
--
-- QUE HACE
--
--   1. Reprograma una ocurrencia por el SP -con su motivo, como lo haria
--      una persona-, corriendola tres semanas.
--   2. Da por cumplida la hija en una fecha que cae dentro de la ventana
--      nueva y fuera de la vieja.
--   3. Y da por cumplidas a tiempo otras dos, para que el indicador tenga
--      con que compararse y no sea una sola fila.
--
--   Los cierres se escriben directo, como el resto de las completadas de la
--   demo: cerrar por el camino real exige una orden ejecutada en terreno, que
--   es justamente lo que no hay en una base de pruebas.
--
-- TODO IDEMPOTENTE: se reconoce por el motivo que deja escrito.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'emilio.fuentes@hamburgo.cl')
DECLARE @MOTIVO NVARCHAR(200) = N'Semilla HU-086: se corre por disponibilidad del equipo.'

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_observacion LIKE '%Semilla HU-086%')
BEGIN
    PRINT '--- La semilla de cumplimiento ya estaba aplicada: no se toca nada.'
END
ELSE
BEGIN
    DECLARE @ID INT, @HIJA INT, @ORIGINAL DATETIME, @NUEVA DATETIME

    /* Una pendiente cuya fecha ya paso: reprogramarla hacia adelante y
       cumplirla dentro de la ventana nueva es el caso del criterio. */
    SELECT TOP 1 @ID = pmo.pmo_id, @ORIGINAL = pmo.pmo_fecha_programada_utc
      FROM [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
     WHERE pmo.pmo_cliente = @CLIENTE
       AND pmo.pmo_habilitado = 1
       AND pmo.pmo_plan_ocurrencia_estado IN (1, 2)
       AND pmo.pmo_orden_trabajo IS NULL
       AND pmo.pmo_fecha_programada_utc < GETUTCDATE()
     ORDER BY pmo.pmo_fecha_programada_utc

    IF @ID IS NULL
    BEGIN
        RAISERROR('1.- NO HAY UNA OCURRENCIA PENDIENTE VENCIDA QUE REPROGRAMAR.', 16, 1)
        RETURN
    END

    SET @NUEVA = DATEADD(DAY, 21, @ORIGINAL)

    EXEC [dbo].[PLAN_OCURRENCIA_REPROGRAMAR]
         @ID = @ID, @CLIENTE = @CLIENTE, @NUEVA_FECHA = @NUEVA,
         @MOTIVO = @MOTIVO, @USUARIO = @USUARIO

    /* La hija: la que nacio con la fecha nueva y la original heredada. */
    SELECT TOP 1 @HIJA = pmo_id
      FROM [dbo].[Plan_Mantenimiento_Ocurrencia]
     WHERE pmo_ocurrencia_origen = @ID
     ORDER BY pmo_id DESC

    IF @HIJA IS NULL
    BEGIN
        RAISERROR('2.- LA REPROGRAMACION NO DEJO OCURRENCIA HIJA.', 16, 1)
        RETURN
    END

    /* Cumplida el dia de la fecha nueva: dentro de su ventana, y tres
       semanas despues de la vieja. Contra la original NO cumple; contra la
       vigente SI. Esa es toda la prueba. */
    UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
       SET pmo_plan_ocurrencia_estado = 4,
           pmo_fecha_actualizacion    = @NUEVA,
           pmo_usuario_actualizacion  = @USUARIO,
           pmo_observacion = LTRIM(RTRIM(ISNULL(pmo_observacion, '') + ' Semilla HU-086: cumplida dentro de la fecha nueva.'))
     WHERE pmo_id = @HIJA

    PRINT '--- Ocurrencia ' + LTRIM(STR(@ID)) + ' reprogramada a ' + CONVERT(VARCHAR(10), @NUEVA, 103) +
          ' y su hija ' + LTRIM(STR(@HIJA)) + ' dada por cumplida en esa fecha.'

    /* Y dos cumplidas a tiempo de verdad, para que el indicador no sea una
       sola fila contra cero. */
    ;WITH aTiempo AS (
        SELECT TOP 2 pmo_id, pmo_fecha_programada_utc
          FROM [dbo].[Plan_Mantenimiento_Ocurrencia]
         WHERE pmo_cliente = @CLIENTE
           AND pmo_habilitado = 1
           AND pmo_plan_ocurrencia_estado IN (1, 2)
           AND pmo_orden_trabajo IS NULL
           AND pmo_fecha_programada_utc < GETUTCDATE()
           AND pmo_id <> @HIJA
         ORDER BY pmo_fecha_programada_utc
    )
    UPDATE p
       SET pmo_plan_ocurrencia_estado = 4,
           pmo_fecha_actualizacion    = a.pmo_fecha_programada_utc,
           pmo_usuario_actualizacion  = @USUARIO,
           pmo_observacion = LTRIM(RTRIM(ISNULL(p.pmo_observacion, '') + ' Semilla HU-086: cumplida en fecha.'))
      FROM [dbo].[Plan_Mantenimiento_Ocurrencia] p
      JOIN aTiempo a ON a.pmo_id = p.pmo_id

    PRINT '--- ' + LTRIM(STR(@@ROWCOUNT)) + ' ocurrencia(s) dadas por cumplidas en fecha.'
END
GO

PRINT '=== cumplimiento despues de la semilla ==='
EXEC [dbo].[SEL_PLAN_CUMPLIMIENTO] @CLIENTE = 1
GO

PRINT '_SEMILLA_CUMPLIMIENTO aplicada.'
GO
