USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA EL CALENDARIO DE UN PLAN (T-4215).
-- =============================================
-- ESTO NO ES UNA MIGRACION. Corre despues de _SEMILLA_PLAN_ACTIVOS.
--
--   El calendario lee Plan_Mantenimiento_Ocurrencia, y esa tabla la llena el
--   generador de HU-076, que no existe todavia. Esta semilla hace a mano lo
--   que el generador hara: publica la v1 del plan de hornos -no se genera
--   desde un borrador- y por cada hito x equipo de la version pide a
--   FNC_PROGRAMACION_FECHAS las fechas del año y las inserta como
--   PENDIENTE. Las que ya pasaron se dejan unas COMPLETADA y una OMITIDA,
--   para que la grilla tenga de todo.
--
--   Idempotente: los indices unicos (hito, activo, fecha) rechazan el
--   duplicado y aca se pregunta antes. Publicar la version es un paso sin
--   vuelta: despues los hitos y equipos de PMA-HORNOS-L1 quedan de solo
--   lectura, que es justamente el comportamiento a probar. PMA-2 sigue en
--   borrador para seguir probando la edicion.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @PLAN    INT = (SELECT pma_id FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-HORNOS-L1')
DECLARE @VERSION INT = (SELECT TOP 1 pmv_id FROM [dbo].[Plan_Mantenimiento_Version]
                        WHERE pmv_plan_mantenimiento = @PLAN AND pmv_habilitado = 1 ORDER BY pmv_numero DESC)
DECLARE @ANIO    INT = YEAR(GETUTCDATE())
DECLARE @DESDE   DATE = DATEFROMPARTS(@ANIO, 1, 1)
DECLARE @HASTA   DATE = DATEFROMPARTS(@ANIO, 12, 31)

IF (@PLAN IS NULL OR @VERSION IS NULL OR @USUARIO IS NULL)
BEGIN
    RAISERROR('1.- CORRA _SEMILLA_PLANES_MANTENIMIENTO, _SEMILLA_PLAN_HITOS Y _SEMILLA_PLAN_ACTIVOS ANTES.', 16, 1)
    RETURN
END

-- 1) La version tiene que estar publicada: no se genera desde un borrador.
IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @VERSION AND pmv_plan_version_estado = 1)
    EXEC [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR] @PMV_ID = @VERSION, @USUARIO = @USUARIO

-- 2) Hito x equipo x fecha proyectada
INSERT INTO [dbo].[Plan_Mantenimiento_Ocurrencia]
    (pmo_uuid, pmo_cliente, pmo_plan_mantenimiento_hito, pmo_programacion, pmo_activo, pmo_activo_componente,
     pmo_fecha_programada_utc, pmo_fecha_limite_utc, pmo_fecha_disponible_utc,
     pmo_plan_ocurrencia_estado, pmo_usuario_creacion, pmo_fecha_creacion, pmo_habilitado)
SELECT  NEWID(), @CLIENTE, h.pmh_id, h.pmh_programacion, a.pac_activo, a.pac_activo_componente,
        f.FECHA,
        DATEADD(MINUTE, ISNULL(p.pro_tolerancia_despues_minuto, 0), f.FECHA),
        DATEADD(MINUTE, -ISNULL(p.pro_tolerancia_antes_minuto, 0), f.FECHA),
        1, @USUARIO, GETDATE(), 1
FROM    [dbo].[Plan_Mantenimiento_Hito]   h
JOIN    [dbo].[Programacion]              p ON p.pro_id = h.pmh_programacion
JOIN    [dbo].[Plan_Mantenimiento_Activo] a ON a.pac_plan_mantenimiento_version = h.pmh_plan_mantenimiento_version
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](h.pmh_programacion, @DESDE, @HASTA) f
WHERE   h.pmh_plan_mantenimiento_version = @VERSION
  AND   h.pmh_habilitado = 1
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    WHERE o.pmo_plan_mantenimiento_hito = h.pmh_id AND o.pmo_activo = a.pac_activo
                      AND o.pmo_fecha_programada_utc = f.FECHA)

-- 3) Las que ya pasaron: la mayoria se hizo, una se saltó (solo la primera vez)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
               JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
               WHERE h.pmh_plan_mantenimiento_version = @VERSION AND o.pmo_plan_ocurrencia_estado <> 1)
BEGIN
    UPDATE o SET pmo_plan_ocurrencia_estado = 4, pmo_observacion = 'Semilla: ejecutada en fecha',
                 pmo_usuario_actualizacion = @USUARIO, pmo_fecha_actualizacion = GETDATE()
    FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
    JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
    WHERE h.pmh_plan_mantenimiento_version = @VERSION
      AND o.pmo_fecha_programada_utc < DATEADD(MONTH, -1, GETUTCDATE())

    -- La mas antigua de un equipo se omitio
    ;WITH u AS (SELECT TOP 1 o.pmo_id FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
                JOIN [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
                WHERE h.pmh_plan_mantenimiento_version = @VERSION AND o.pmo_plan_ocurrencia_estado = 4
                ORDER BY o.pmo_fecha_programada_utc, o.pmo_activo)
    UPDATE o SET pmo_plan_ocurrencia_estado = 5, pmo_observacion = 'Semilla: equipo detenido por producción'
    FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o JOIN u ON u.pmo_id = o.pmo_id
END
GO

SELECT MES, ESTADO_NOMBRE, SITUACION, COUNT(*) AS N
FROM   (SELECT FORMAT(o.pmo_fecha_programada_utc, 'yyyy-MM') AS MES, e.poe_nombre AS ESTADO_NOMBRE,
               CASE WHEN e.poe_id IN (4,5,6,7) THEN 'CERRADA'
                    WHEN o.pmo_fecha_limite_utc < GETUTCDATE() THEN 'VENCIDA'
                    WHEN o.pmo_fecha_programada_utc < GETUTCDATE() THEN 'ATRASADA'
                    WHEN o.pmo_fecha_disponible_utc <= GETUTCDATE() THEN 'DISPONIBLE' ELSE 'FUTURA' END AS SITUACION
        FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
        JOIN [dbo].[Plan_Ocurrencia_Estado] e ON e.poe_id = o.pmo_plan_ocurrencia_estado
        WHERE o.pmo_cliente = 1) x
GROUP BY MES, ESTADO_NOMBRE, SITUACION
ORDER BY MES
GO
