USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA LA BANDEJA (T-4181).
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   La base ya tiene con que ejercitar tres de las cuatro situaciones:
--   vencidas, atrasadas y futuras salen solas de las ocurrencias generadas.
--   La que no aparece nunca es DISPONIBLE, y no por casualidad: una
--   ocurrencia esta disponible durante la ventana de tolerancia -entre
--   "ya se puede adelantar" y la fecha programada-, que dura dias, y las
--   generadas en las pruebas caen fuera de esa ventana.
--
--   Sin una sola DISPONIBLE, el criterio 1 de HU-087 -"cada una indica si
--   esta futura, disponible, atrasada o vencida"- se verifica con tres de
--   cuatro, que es no verificarlo.
--
-- QUE HACE, EXACTAMENTE
--
--   Abre la ventana de tolerancia de dos ocurrencias futuras: les adelanta
--   pmo_fecha_disponible_utc a hoy. No inventa ocurrencias ni les cambia la
--   fecha programada, porque eso si seria mentir: la mantencion sigue siendo
--   el dia que dice el plan, lo unico que cambia es desde cuando se puede
--   adelantar. Es exactamente lo que hace una tolerancia mas amplia.
--
-- TODO IDEMPOTENTE: si ya hay alguna disponible, no toca nada.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @HOY DATETIME = GETUTCDATE()
DECLARE @DISPONIBLES INT

SELECT @DISPONIBLES = COUNT(*)
  FROM [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
 WHERE pmo.pmo_cliente = @CLIENTE
   AND pmo.pmo_habilitado = 1
   AND pmo.pmo_plan_ocurrencia_estado IN (1, 2, 3)
   AND pmo.pmo_fecha_programada_utc >= @HOY
   AND (pmo.pmo_fecha_limite_utc IS NULL OR pmo.pmo_fecha_limite_utc >= @HOY)
   AND pmo.pmo_fecha_disponible_utc IS NOT NULL
   AND pmo.pmo_fecha_disponible_utc <= @HOY
   /* Y SIN ORDEN TODAVIA. Una disponible que ya genero su orden alcanza
      para ver la situacion en la lista, pero no para ejercitar el criterio
      3 -generar la orden desde la bandeja-, que es justamente lo que hay
      que poder repetir al correr las pruebas otra vez. */
   AND pmo.pmo_orden_trabajo IS NULL

IF @DISPONIBLES > 0
BEGIN
    PRINT '--- Ya hay ' + LTRIM(STR(@DISPONIBLES)) + ' ocurrencia(s) disponible(s) sin orden: no se toca nada.'
END
ELSE
BEGIN
    /* Las dos futuras mas proximas: son las que de verdad estarian por
       entrar en tolerancia, no dos cualquiera del año que viene. */
    ;WITH proximas AS (
        SELECT TOP 2 pmo.pmo_id
          FROM [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
         WHERE pmo.pmo_cliente = @CLIENTE
           AND pmo.pmo_habilitado = 1
           AND pmo.pmo_plan_ocurrencia_estado IN (1, 2)
           AND pmo.pmo_fecha_programada_utc > @HOY
           AND (pmo.pmo_fecha_limite_utc IS NULL OR pmo.pmo_fecha_limite_utc > @HOY)
           AND pmo.pmo_orden_trabajo IS NULL
         ORDER BY pmo.pmo_fecha_programada_utc
    )
    UPDATE  pmo
       SET  pmo_fecha_disponible_utc = @HOY,
            pmo_observacion = LTRIM(RTRIM(ISNULL(pmo_observacion, '') +
                              ' Ventana de tolerancia abierta para las pruebas de HU-087.'))
      FROM  [dbo].[Plan_Mantenimiento_Ocurrencia] pmo
      JOIN  proximas p ON p.pmo_id = pmo.pmo_id

    PRINT '--- Ventana de tolerancia abierta en ' + LTRIM(STR(@@ROWCOUNT)) + ' ocurrencia(s).'
END
GO

EXEC [dbo].[SEL_PLAN_OCURRENCIA_BANDEJA] @CLIENTE = 1, @SITUACION = 'DISPONIBLE'
GO

PRINT '_SEMILLA_BANDEJA_DISPONIBLES aplicada.'
GO
