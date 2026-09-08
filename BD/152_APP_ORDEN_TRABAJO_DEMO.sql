USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     LO QUE FALTABA PARA QUE LA BANDEJA DE LA APP DEVUELVA ALGO.
-- =============================================
-- EL HALLAZGO QUE MOTIVA ESTE BLOQUE
--
--   Cliente_Instalacion_Usuario estaba VACIA. Nadie estaba asignado a ninguna
--   planta, y toda la seguridad de la app se apoya en esa tabla: la sabana
--   (bloque 140) y la bandeja de ordenes (bloque 150) resuelven las plantas
--   autorizadas ahi.
--
--   Con la tabla vacia, cualquier tecnico que entrara a la app veria CERO de
--   todo, y el sintoma seria indistinguible de "la API esta rota".
--
-- LOS DATOS SE CREAN EJERCITANDO EL PROPIO INS
--
--   Las ordenes no se insertan a mano: se llama a API_INS_ORDEN_TRABAJO. Asi
--   la siembra prueba el procedimiento -correlativo, idempotencia, pasos,
--   historial de estado- en vez de dejar filas que el codigo real nunca
--   habria producido.
--
-- ES REEJECUTABLE
--
--   Todo va con su comprobacion previa. Correr el bloque dos veces no duplica
--   nada: las altas repiten el mismo uuid y el SP responde la orden que ya
--   existe, que es exactamente la proteccion que se quiere probar.
-- =============================================

SET NOCOUNT ON

DECLARE @CLIENTE     INT = 1
DECLARE @INSTALACION INT = (SELECT TOP 1 [cin_id] FROM [dbo].[Cliente_Instalacion]
                             WHERE [cin_cliente] = @CLIENTE AND [cin_habilitado] = 1
                             ORDER BY [cin_id])
DECLARE @ADMIN       INT = 1

IF @INSTALACION IS NULL
BEGIN
    RAISERROR('No hay instalacion habilitada para el cliente 1. Revisa el bloque de plantas.', 16, 1)
    RETURN
END


-- ---------------------------------------------------------------------------
-- 1 - LA ASIGNACION QUE FALTABA: personas <-> planta
-- ---------------------------------------------------------------------------
--   Se afilian los usuarios del cliente que hoy existen. Sin esto la app no
--   muestra nada, por correcta que este la API.
-- ---------------------------------------------------------------------------
INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
    ([ciu_id_instalacion], [ciu_id_usuario], [ciu_usuario_creacion]
    ,[ciu_fecha_creacion], [ciu_habilitado], [ciu_fecha_inicio])
SELECT @INSTALACION, u.[usu_id], @ADMIN, GETDATE(), 1, CAST(GETDATE() AS DATE)
  FROM [dbo].[Usuario] u
 WHERE u.[usu_habilitado] = 1
   AND u.[usu_login] LIKE '%@hamburgo.cl'
   AND NOT EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Instalacion_Usuario] x
                    WHERE x.[ciu_id_instalacion] = @INSTALACION
                      AND x.[ciu_id_usuario]     = u.[usu_id])

PRINT CONCAT('Personas afiliadas a la planta: ',
             (SELECT COUNT(*) FROM [dbo].[Cliente_Instalacion_Usuario]
               WHERE [ciu_id_instalacion] = @INSTALACION AND [ciu_habilitado] = 1))


-- ---------------------------------------------------------------------------
-- 2 - TRES ORDENES, EJERCITANDO API_INS_ORDEN_TRABAJO
-- ---------------------------------------------------------------------------
DECLARE @TECNICO INT = (SELECT TOP 1 [ciu_id_usuario]
                          FROM [dbo].[Cliente_Instalacion_Usuario]
                         WHERE [ciu_id_instalacion] = @INSTALACION
                           AND [ciu_habilitado] = 1
                         ORDER BY [ciu_id_usuario])

DECLARE @ACT1 INT = (SELECT TOP 1 [act_id] FROM [dbo].[Activo]
                      WHERE [act_cliente_instalacion] = @INSTALACION AND [act_habilitado] = 1
                      ORDER BY [act_id])
DECLARE @ACT2 INT = (SELECT TOP 1 [act_id] FROM [dbo].[Activo]
                      WHERE [act_cliente_instalacion] = @INSTALACION AND [act_habilitado] = 1
                        AND [act_id] <> @ACT1
                      ORDER BY [act_id])

/* Los uuid son fijos a proposito: hacen el bloque reejecutable y, de paso,
   prueban la idempotencia en la segunda corrida. */
EXEC [dbo].[API_INS_ORDEN_TRABAJO]
     @UUID             = 'A1B2C3D4-0001-4000-8000-000000000001'
    ,@USUARIO          = @TECNICO
    ,@CLIENTE          = @CLIENTE
    ,@INSTALACION      = @INSTALACION
    ,@TITULO           = N'Vibracion alta en descanso lado acople'
    ,@DESCRIPCION      = N'Vibracion por sobre 8 mm/s en descanso lado acople. Detener equipo, verificar rodamiento y sustituir si presenta desgaste.'
    ,@ACTIVO           = @ACT1
    ,@TIPO             = 2      -- CORRECTIVA
    ,@ESTRATEGIA       = 3      -- EMERGENCIA
    ,@PRIORIDAD        = 4      -- CRITICA
    ,@REQUIERE_PERMISO = 1
    ,@PASOS            = N'Bloqueo electrico aplicado
Medir vibracion RMS en descanso lado acople
Inspeccionar rodamiento
Sustituir rodamiento si presenta desgaste
Prueba de marcha y registro de vibracion final'

EXEC [dbo].[API_INS_ORDEN_TRABAJO]
     @UUID        = 'A1B2C3D4-0002-4000-8000-000000000002'
    ,@USUARIO     = @TECNICO
    ,@CLIENTE     = @CLIENTE
    ,@INSTALACION = @INSTALACION
    ,@TITULO      = N'Cambio de sello mecanico'
    ,@DESCRIPCION = N'Sello con filtracion visible. Reemplazo programado.'
    ,@ACTIVO      = @ACT2
    ,@TIPO        = 1           -- PREVENTIVA
    ,@ESTRATEGIA  = 2           -- PROGRAMADO
    ,@PRIORIDAD   = 3           -- ALTA
    ,@PASOS       = N'Bloqueo y drenaje
Retirar sello antiguo
Instalar sello nuevo
Prueba de estanqueidad'

EXEC [dbo].[API_INS_ORDEN_TRABAJO]
     @UUID        = 'A1B2C3D4-0003-4000-8000-000000000003'
    ,@USUARIO     = @TECNICO
    ,@CLIENTE     = @CLIENTE
    ,@INSTALACION = @INSTALACION
    ,@TITULO      = N'Inspeccion de correas'
    ,@ACTIVO      = @ACT1
    ,@TIPO        = 1
    ,@ESTRATEGIA  = 4           -- INSPECCION
    ,@PRIORIDAD   = 2           -- MEDIA
    ,@PASOS       = N'Revisar tension
Revisar desgaste
Registrar hallazgo'


-- ---------------------------------------------------------------------------
-- 3 - PLAZOS, para que la bandeja tenga las tres situaciones del kit
-- ---------------------------------------------------------------------------
--   VENCIDA, VENCE HOY y EN PLAZO. Sin esto las tres salen "SIN PLAZO" y no
--   se puede ver si el orden de la bandeja funciona.
-- ---------------------------------------------------------------------------
UPDATE [dbo].[Orden_Trabajo]
   SET [otr_fecha_programada_utc] = DATEADD(DAY, -2, GETUTCDATE())
 WHERE [otr_uuid] = 'A1B2C3D4-0001-4000-8000-000000000001'

UPDATE [dbo].[Orden_Trabajo]
   SET [otr_fecha_programada_utc] = GETUTCDATE()
 WHERE [otr_uuid] = 'A1B2C3D4-0002-4000-8000-000000000002'

UPDATE [dbo].[Orden_Trabajo]
   SET [otr_fecha_programada_utc] = DATEADD(DAY, 5, GETUTCDATE())
 WHERE [otr_uuid] = 'A1B2C3D4-0003-4000-8000-000000000003'


-- ---------------------------------------------------------------------------
-- 4 - VERIFICACION
-- ---------------------------------------------------------------------------
PRINT '--- Bandeja: disponibles (ambito 2) ---'
EXEC [dbo].[API_SEL_ORDEN_TRABAJO]
     @USUARIO = @TECNICO, @CLIENTE = @CLIENTE, @TIPO = 1, @AMBITO = 2

PRINT '--- Pasos de la primera ---'
DECLARE @OTR1 INT = (SELECT [otr_id] FROM [dbo].[Orden_Trabajo]
                      WHERE [otr_uuid] = 'A1B2C3D4-0001-4000-8000-000000000001')
EXEC [dbo].[API_SEL_ORDEN_TRABAJO]
     @USUARIO = @TECNICO, @CLIENTE = @CLIENTE, @TIPO = 3, @OTR_ID = @OTR1
GO
