/* ============================================================================
   386 · Job nocturno de SIGMA (08-10-2026)

   Qué es
     Un solo procedimiento, JOB_SIGMA_NOCTURNO, que hace por cada cliente
     habilitado lo que antes quedaba «para cuando haya SQL Agent»:
        1. GEN_PLAN_OCURRENCIAS      (planes, solo programaciones automáticas)
        2. GEN_TAREA_OCURRENCIAS     (tareas recurrentes, solo automáticas)
        3. GEN_CHECKLIST_OCURRENCIAS (rondas de las pautas)

     Las ALERTAS no están aquí a propósito: deben aparecer a medida que
     ocurren, no a la noche. Ya funcionan así: el navegador consulta
     WsAlertas cada pocos segundos y GEN_ALERTA_DETECTAR (freno de 5 minutos
     en la base) abre y cierra las alertas; los movimientos de inventario las
     disparan en el momento.
   Por qué un solo procedimiento
     Azure SQL Database no tiene SQL Agent. Lo que programa la hora (Elastic
     Jobs, Azure Functions, Logic Apps o Automation) solo tiene que ejecutar
     «EXEC dbo.JOB_SIGMA_NOCTURNO»: la lógica vive aquí, versionada, y es la
     misma sea cual sea el programador.

   Es seguro correrlo dos veces
     Las ocurrencias tienen índice único por programación, activo y fecha, y
     las alertas se resuelven solas: repetir el job no duplica nada. Cada paso
     va en su propio TRY/CATCH: si uno falla, los demás siguen y el fallo queda
     en Job_Ejecucion y en Excepcion.

   Lo que NO hace
     El valor de la UF no puede salir de la base (hay que consultar una API
     HTTP): sigue alimentándolo UfController.AsegurarValorDeHoy() desde la web.
   ============================================================================ */

IF OBJECT_ID(N'[dbo].[Job_Ejecucion]') IS NULL
BEGIN
    CREATE TABLE [dbo].[Job_Ejecucion]
    (
        [jex_id]        INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Job_Ejecucion] PRIMARY KEY,
        [jex_job]       VARCHAR(60)   NOT NULL,
        [jex_paso]      VARCHAR(60)   NOT NULL,
        [jex_cliente]   INT           NULL,
        [jex_inicio]    DATETIME      NOT NULL CONSTRAINT [DF_JEX_INICIO] DEFAULT (GETUTCDATE()),
        [jex_fin]       DATETIME      NULL,
        [jex_generadas] INT           NULL,
        [jex_error]     NVARCHAR(2000) NULL
    )
    CREATE INDEX [IX_JEX_JOB_INICIO] ON [dbo].[Job_Ejecucion] ([jex_job], [jex_inicio] DESC)
END
GO

CREATE OR ALTER PROCEDURE [dbo].[JOB_SIGMA_NOCTURNO]
    @HORIZONTE_DIA INT = 90,
    @USUARIO       INT = 1
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @GEN INT, @ID INT, @MSG NVARCHAR(2000)

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT cli_id FROM [dbo].[Cliente] WHERE cli_habilitado = 1 ORDER BY cli_id
OPEN c
FETCH NEXT FROM c INTO @CLIENTE
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @PASO VARCHAR(60), @N INT = 1
    WHILE @N <= 3
    BEGIN
        SET @PASO = CHOOSE(@N, 'PLANES', 'TAREAS', 'RONDAS')
        SET @GEN = NULL
        INSERT [dbo].[Job_Ejecucion] (jex_job, jex_paso, jex_cliente) VALUES ('JOB_SIGMA_NOCTURNO', @PASO, @CLIENTE)
        SET @ID = SCOPE_IDENTITY()
        BEGIN TRY
            IF @PASO = 'PLANES'
                EXEC [dbo].[GEN_PLAN_OCURRENCIAS] @CLIENTE = @CLIENTE, @PLAN = NULL, @HORIZONTE_DIA = @HORIZONTE_DIA, @SOLO_AUTOMATICAS = 1, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT
            ELSE IF @PASO = 'TAREAS'
                EXEC [dbo].[GEN_TAREA_OCURRENCIAS] @CLIENTE = @CLIENTE, @TAREA = NULL, @HORIZONTE_DIA = @HORIZONTE_DIA, @SOLO_AUTOMATICAS = 1, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT
            ELSE IF @PASO = 'RONDAS'
                EXEC [dbo].[GEN_CHECKLIST_OCURRENCIAS] @CLIENTE = @CLIENTE, @CHECKLIST_PROGRAMACION = NULL, @HORIZONTE_DIA = @HORIZONTE_DIA, @USUARIO = @USUARIO, @GENERADAS = @GEN OUTPUT

            UPDATE [dbo].[Job_Ejecucion] SET jex_fin = GETUTCDATE(), jex_generadas = @GEN WHERE jex_id = @ID
        END TRY
        BEGIN CATCH
            SET @MSG = LEFT(ERROR_MESSAGE(), 1900)
            UPDATE [dbo].[Job_Ejecucion] SET jex_fin = GETUTCDATE(), jex_error = @MSG WHERE jex_id = @ID
            BEGIN TRY
                EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'JOB_SIGMA_NOCTURNO', @MSG = @MSG
            END TRY
            BEGIN CATCH
            END CATCH
        END CATCH
        SET @N = @N + 1
    END
    FETCH NEXT FROM c INTO @CLIENTE
END
CLOSE c
DEALLOCATE c

-- El resumen de lo que acaba de pasar: lo que ve quien programa el job.
SELECT jex_paso AS PASO, jex_cliente AS CLIENTE, jex_generadas AS GENERADAS, jex_error AS ERROR_PASO
FROM   [dbo].[Job_Ejecucion]
WHERE  jex_job = 'JOB_SIGMA_NOCTURNO' AND jex_inicio >= DATEADD(MINUTE, -30, GETUTCDATE())
ORDER BY jex_id
RETURN 0
GO

PRINT '386_JOB_NOCTURNO aplicado.'
GO

/* ============================================================================
   PROGRAMARLO EN AZURE (no se ejecuta aquí: requiere el recurso en el portal)

   Opción recomendada · Elastic Jobs
     1. Portal → crear «Agente de trabajos elásticos» (Elastic Job agent) y su
        base de datos de trabajos (Basic/S0) en el mismo servidor.
     2. En la base de trabajos, con credenciales de la base SIGMA:

        EXEC jobs.sp_add_target_group @target_group_name = N'SIGMA';
        EXEC jobs.sp_add_target_group_member @target_group_name = N'SIGMA',
             @target_type = N'SqlDatabase', @server_name = N'codigocreativo.database.windows.net',
             @database_name = N'SIGMA';
        EXEC jobs.sp_add_job @job_name = N'SIGMA nocturno', @description = N'Ocurrencias y rondas',
             @enabled = 1, @schedule_interval_type = N'Days', @schedule_interval_count = 1,
             @schedule_start_time = N'2026-10-09T05:00:00';   -- UTC: 02:00 en Chile (verano) / 01:00 (invierno)
        EXEC jobs.sp_add_jobstep @job_name = N'SIGMA nocturno', @step_name = N'Ejecutar',
             @command = N'EXEC dbo.JOB_SIGMA_NOCTURNO;', @target_group_name = N'SIGMA';

   Alternativa sin recurso extra de SQL: Azure Functions (timer) o Logic App
   (Recurrence) que ejecuten «EXEC dbo.JOB_SIGMA_NOCTURNO» con la cadena de
   conexión de Azure.
   ============================================================================ */
