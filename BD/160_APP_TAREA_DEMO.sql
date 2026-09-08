USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     TAREAS DE PRUEBA EN LA PLANTA HAMBURGO (cin_id = 3).
-- =============================================
-- POR QUE ESTAS CINCO
--
--   Son las que hoy no se registran en ninguna parte: revisar un nivel,
--   limpiar un filtro, apretar una tapa. Duran entre cinco y veinte minutos y
--   por eso nadie abre una OT para ellas -y por eso el historial del activo no
--   las tiene-. Si el bloque cargara tareas de media jornada estaria probando
--   una orden de trabajo disfrazada.
--
--   Las tareas y sus ocurrencias se insertan directo porque se crean desde la
--   web, que aun no existe. La ejecucion y el comentario NO: esos se prueban
--   llamando a los SP reales del bloque 159, que es lo unico que demuestra que
--   el telefono va a poder hacerlo.
-- =============================================

SET XACT_ABORT ON
GO

DECLARE @CLI INT = 1
DECLARE @CIN INT = 3
DECLARE @ADM INT = 7                       -- marcela.aravena, planificadora
DECLARE @HOY DATETIME = CAST(GETUTCDATE() AS DATE)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE [tar_codigo] = N'TAR-001')
BEGIN
    /* -------------------------------------------------------- TAREAS ---- */
    INSERT INTO [dbo].[Tarea]
        ([tar_cliente], [tar_cliente_instalacion], [tar_instalacion_area]
        ,[tar_activo], [tar_codigo], [tar_titulo], [tar_descripcion]
        ,[tar_tarea_prioridad], [tar_duracion_estimada_minuto]
        ,[tar_requiere_evidencia]
        ,[tar_usuario_creacion], [tar_fecha_creacion], [tar_habilitado])
    VALUES
         (@CLI, @CIN, 4, 34, N'TAR-001'
         ,N'Revisar nivel de aceite del reductor'
         ,N'Verificar por la mirilla que el nivel quede entre las marcas. Si esta bajo la marca inferior, no rellenar: avisar y dejar comentario.'
         ,2, 10, 0, @ADM, GETDATE(), 1)

        ,(@CLI, @CIN, 4, 33, N'TAR-002'
         ,N'Limpiar filtro de aire de la modeladora'
         ,N'Soplar el filtro con aire a baja presion desde adentro hacia afuera. Si esta saturado de harina, cambiarlo.'
         ,2, 15, 1, @ADM, GETDATE(), 1)

        ,(@CLI, @CIN, 5, NULL, N'TAR-003'
         ,N'Revisar temperatura de camara de fermentacion'
         ,N'Anotar la temperatura que marca el controlador y compararla con la receta del turno.'
         ,3, 5, 0, @ADM, GETDATE(), 1)

        ,(@CLI, @CIN, 6, 38, N'TAR-004'
         ,N'Apretar prensaestopas de la bomba de masa'
         ,N'Ajustar hasta que el goteo sea de unas pocas gotas por minuto. Apretar de mas quema la empaquetadura.'
         ,3, 20, 0, @ADM, GETDATE(), 1)

        ,(@CLI, @CIN, 7, 41, N'TAR-005'
         ,N'Purgar condensado de la linea de vapor'
         ,N'Abrir la purga del cabezal hasta que salga vapor limpio. Ojo con la quemadura: usar guante largo.'
         ,4, 10, 0, @ADM, GETDATE(), 1)


    /* --------------------------------------------------- OCURRENCIAS ---- */
    --  Una vencida, una que vence hoy y tres en plazo: la bandeja tiene que
    --  poder ordenarlas y pintarlas distinto, y con todo en plazo eso no se
    --  ve.
    INSERT INTO [dbo].[Tarea_Ocurrencia]
        ([toc_uuid], [toc_cliente], [toc_tarea], [toc_tarea_ocurrencia_estado]
        ,[toc_fecha_programada_utc], [toc_fecha_limite_utc]
        ,[toc_usuario_creacion], [toc_fecha_creacion], [toc_habilitado])
    SELECT
         NEWID(), @CLI, t.[tar_id], 1
        ,DATEADD(HOUR, v.[prog], @HOY)
        ,DATEADD(HOUR, v.[lim],  @HOY)
        ,@ADM, GETDATE(), 1
      FROM [dbo].[Tarea] t
      JOIN (VALUES
             (N'TAR-001',  6, 10)          -- vencida si ya paso la manana
            ,(N'TAR-002',  8, 23)          -- vence hoy
            ,(N'TAR-003',  8, 32)          -- manana
            ,(N'TAR-004', 24, 48)
            ,(N'TAR-005', 24, 56)
           ) AS v([cod], [prog], [lim]) ON v.[cod] = t.[tar_codigo]

    PRINT '  tareas y ocurrencias creadas'
END
ELSE
    PRINT '  las tareas ya estaban'
GO


-- ---------------------------------------------------------------------------
-- PRUEBA: EJECUTAR Y COMENTAR COMO LO HARIA EL TELEFONO
-- ---------------------------------------------------------------------------
DECLARE @CLI INT = 1
DECLARE @USR INT = 11                      -- cristian.munoz, mantenedor
DECLARE @OC1 INT, @OC2 INT

SELECT @OC1 = toc.[toc_id] FROM [dbo].[Tarea_Ocurrencia] toc
  JOIN [dbo].[Tarea] t ON t.[tar_id] = toc.[toc_tarea] WHERE t.[tar_codigo] = N'TAR-001'
SELECT @OC2 = toc.[toc_id] FROM [dbo].[Tarea_Ocurrencia] toc
  JOIN [dbo].[Tarea] t ON t.[tar_id] = toc.[toc_tarea] WHERE t.[tar_codigo] = N'TAR-004'

/* -- 1. La bandeja antes de tocar nada -- */
PRINT ''
PRINT '== PENDIENTES DE CRISTIAN =='
EXEC [dbo].[API_SEL_TAREA] @USUARIO = @USR, @CLIENTE = @CLI, @TIPO = 1

/* -- 2. Empezar TAR-001 -- */
DECLARE @U1 UNIQUEIDENTIFIER = '9E1C3A70-0001-4A00-9000-000000000001'
PRINT ''
PRINT '== EMPEZAR TAR-001 =='
EXEC [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID = @U1, @USUARIO = @USR, @CLIENTE = @CLI
    ,@OCURRENCIA = @OC1, @FINALIZAR = 0, @DISPOSITIVO = N'Moto G84 - demo'

/* -- 3. El mismo envio otra vez: la cola reintentando -- */
PRINT '== REINTENTO DEL MISMO UUID (no debe abrir otra) =='
EXEC [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID = @U1, @USUARIO = @USR, @CLIENTE = @CLI
    ,@OCURRENCIA = @OC1, @FINALIZAR = 0

/* -- 4. Comentar, y responder el comentario -- */
PRINT ''
PRINT '== COMENTARIOS =='
EXEC [dbo].[API_INS_TAREA_COMENTARIO]
     @OCURRENCIA = @OC1, @USUARIO = @USR, @CLIENTE = @CLI
    ,@TEXTO = N'El nivel esta justo en la marca inferior. No relleno, aviso.'
    ,@POR_VOZ = 1

DECLARE @PADRE INT = (SELECT TOP 1 [tco_id] FROM [dbo].[Tarea_Comentario]
                       WHERE [tco_tarea_ocurrencia] = @OC1 ORDER BY [tco_id] DESC)

EXEC [dbo].[API_INS_TAREA_COMENTARIO]
     @OCURRENCIA = @OC1, @USUARIO = 7, @CLIENTE = @CLI
    ,@TEXTO = N'Bien avisado. Queda OT para rellenar en el cambio de turno.'
    ,@PADRE = @PADRE

PRINT '== COMENTARIO REPETIDO (no debe duplicar) =='
EXEC [dbo].[API_INS_TAREA_COMENTARIO]
     @OCURRENCIA = @OC1, @USUARIO = @USR, @CLIENTE = @CLI
    ,@TEXTO = N'El nivel esta justo en la marca inferior. No relleno, aviso.'
    ,@POR_VOZ = 1

/* -- 5. Cerrar TAR-001 conforme -- */
PRINT ''
PRINT '== CERRAR TAR-001 =='
EXEC [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID = @U1, @USUARIO = @USR, @CLIENTE = @CLI
    ,@OCURRENCIA = @OC1, @FINALIZAR = 1, @CONFORME = 1
    ,@RESULTADO = N'Nivel en el limite. Se deja avisado, no se rellena.'
    ,@MINUTOS = 8

/* -- 6. TAR-004 no se pudo hacer, y sin motivo debe rebotar -- */
DECLARE @U2 UNIQUEIDENTIFIER = '9E1C3A70-0001-4A00-9000-000000000002'
PRINT ''
PRINT '== TAR-004 NO CONFORME SIN MOTIVO (debe fallar) =='
BEGIN TRY
    EXEC [dbo].[API_UPS_TAREA_EJECUCION]
         @UUID = @U2, @USUARIO = @USR, @CLIENTE = @CLI
        ,@OCURRENCIA = @OC2, @FINALIZAR = 1, @CONFORME = 0
END TRY
BEGIN CATCH
    PRINT '  rechazado: ' + ERROR_MESSAGE()
END CATCH

PRINT '== TAR-004 NO CONFORME CON MOTIVO =='
EXEC [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID = @U2, @USUARIO = @USR, @CLIENTE = @CLI
    ,@OCURRENCIA = @OC2, @FINALIZAR = 1, @CONFORME = 0
    ,@RESULTADO = N'La bomba estaba en produccion, no se pudo detener. Queda para el turno de noche.'

/* -- 7. Como quedo todo -- */
PRINT ''
PRINT '== RESULTADO =='
SELECT t.[tar_codigo], toe.[toe_nombre] AS [ESTADO]
      ,tej.[tej_conforme], tej.[tej_duracion_minuto], tej.[tej_resultado]
  FROM [dbo].[Tarea_Ocurrencia]        toc
  JOIN [dbo].[Tarea]                   t   ON t.[tar_id]   = toc.[toc_tarea]
  JOIN [dbo].[Tarea_Ocurrencia_Estado] toe ON toe.[toe_id] = toc.[toc_tarea_ocurrencia_estado]
  LEFT JOIN [dbo].[Tarea_Ejecucion]    tej ON tej.[tej_tarea_ocurrencia] = toc.[toc_id]
 ORDER BY t.[tar_codigo]

PRINT ''
PRINT '== HILO DE TAR-001 =='
EXEC [dbo].[API_SEL_TAREA] @USUARIO = @USR, @CLIENTE = @CLI, @TIPO = 3, @ID = @OC1
GO
