/* ============================================================================
   SIGMA — Bloque 461
   JOBS PROGRAMADOS EN LA BASE (HostChile)
   ----------------------------------------------------------------------------
   SQL Server Express no trae Agent y SIGMA no tenía programador: el
   JOB_SIGMA_NOCTURNO (bloque 386) nunca se había ejecutado y la UF se cargaba
   «colgada» de la primera visita del día.

   DESDE AQUÍ LOS JOBS VIVEN EN LA BASE
     Job              catálogo: qué corre, cada cuánto y cuándo toca.
     Job_Ejecucion    (bloque 386) cada corrida, con su resultado o error.
   Un único ejecutor (Jobs.aspx) se llama cada 5–15 minutos desde la tarea
   programada de Plesk; pide a SEL_JOB_PENDIENTES los que tocan, los ejecuta y
   cierra cada uno con UPD_JOB_FIN. Cambiar un horario, pausar un job o ver por
   qué falló es una consulta a la base, no un despliegue.

   TIPOS
     SQL  el ejecutor hace EXEC del SP indicado en job_sp.
     WEB  lo ejecuta el sitio (necesita C#: correos, Webpay, la API de la UF);
          job_sp queda vacío y el código se elige por job_codigo.

   CANDADO
     SEL_JOB_PENDIENTES marca el job «en ejecución» en la misma sentencia que lo
     elige, así dos llamadas simultáneas no corren el mismo job dos veces. Un
     candado de más de 2 horas se considera abandonado.

   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Job]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Job]
    (
        [job_id]                INT             NOT NULL IDENTITY(1,1),
        [job_codigo]            VARCHAR(60)     NOT NULL,
        [job_nombre]            NVARCHAR(150)   NOT NULL,
        [job_descripcion]       NVARCHAR(500)   NULL,
        [job_tipo]              VARCHAR(5)      NOT NULL,          -- SQL | WEB
        [job_sp]                VARCHAR(128)    NULL,
        [job_frecuencia]        VARCHAR(10)     NOT NULL,          -- DIARIO | MINUTOS
        [job_hora]              TIME(0)         NULL,              -- para DIARIO (hora de Chile)
        [job_minutos]           INT             NULL,              -- para MINUTOS
        [job_activo]            BIT             NOT NULL CONSTRAINT DF_JOB_ACTIVO DEFAULT 1,
        [job_proxima]           DATETIME        NULL,              -- hora de Chile
        [job_ultima_inicio]     DATETIME        NULL,
        [job_ultima_fin]        DATETIME        NULL,
        [job_ultimo_ok]         BIT             NULL,
        [job_ultimo_detalle]    NVARCHAR(2000)  NULL,
        [job_en_ejecucion]      BIT             NOT NULL CONSTRAINT DF_JOB_EN_EJECUCION DEFAULT 0,
        [job_usuario_creacion]  INT             NOT NULL CONSTRAINT DF_JOB_USUARIO_CREACION DEFAULT 1,
        [job_fecha_creacion]    DATETIME        NOT NULL CONSTRAINT DF_JOB_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_JOB PRIMARY KEY CLUSTERED ([job_id] ASC),
        CONSTRAINT CK_JOB_TIPO CHECK ([job_tipo] IN ('SQL', 'WEB')),
        CONSTRAINT CK_JOB_FRECUENCIA CHECK ([job_frecuencia] IN ('DIARIO', 'MINUTOS')),
        CONSTRAINT CK_JOB_PROGRAMA CHECK (([job_frecuencia] = 'DIARIO' AND [job_hora] IS NOT NULL) OR ([job_frecuencia] = 'MINUTOS' AND [job_minutos] > 0))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_JOB_CODIGO ON [dbo].[Job] ([job_codigo])
    PRINT 'Tabla Job creada.'
END
GO

/* La próxima ejecución de un job a partir de un momento dado. */
CREATE OR ALTER FUNCTION [dbo].[FNC_JOB_PROXIMA] (@FRECUENCIA VARCHAR(10), @HORA TIME(0), @MINUTOS INT, @DESDE DATETIME)
RETURNS DATETIME
AS
BEGIN
    IF @FRECUENCIA = 'MINUTOS' RETURN DATEADD(MINUTE, @MINUTOS, @DESDE)
    DECLARE @HOY DATETIME = CAST(CAST(@DESDE AS DATE) AS DATETIME) + CAST(@HORA AS DATETIME)
    RETURN CASE WHEN @HOY > @DESDE THEN @HOY ELSE DATEADD(DAY, 1, @HOY) END
END
GO

/* ---------------------------------------------------------------- catálogo */
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
MERGE [dbo].[Job] AS D
USING (VALUES
  ('OCURRENCIAS_NOCTURNO', N'Ocurrencias de planes, tareas y rondas', N'Genera las ocurrencias de los próximos 90 días y sus asignaciones (JOB_SIGMA_NOCTURNO, bloque 386).', 'SQL', 'JOB_SIGMA_NOCTURNO', 'DIARIO', CAST('02:00' AS TIME(0)), NULL),
  ('UF_DIARIA',            N'Valor de la UF del día',                N'Trae la UF desde la fuente pública y la deja en Valor_Uf. Las pantallas siguen llamándolo como respaldo.', 'WEB', NULL, 'DIARIO', CAST('06:00' AS TIME(0)), NULL),
  ('DEMOS_VENCER',         N'Vencer demos',                          N'Marca VENCIDA cada demo cuyo plazo terminó y lo deja en la línea de tiempo del lead.', 'SQL', 'UPD_LEAD_DEMO_VENCER', 'DIARIO', CAST('00:15' AS TIME(0)), NULL),
  ('COBROS_EMITIR',        N'Emitir cobros de suscripciones',        N'Emite el período siguiente de cada suscripción vigente unos días antes de que empiece y envía el correo de cobro con el enlace de pago.', 'WEB', NULL, 'DIARIO', CAST('07:00' AS TIME(0)), NULL),
  ('COBROS_RECORDATORIOS', N'Recordatorios de pago',                 N'Recuerda los cobros pendientes: 3 días antes del vencimiento, el día que vence y al entrar en mora. Con copia al ejecutivo.', 'WEB', NULL, 'DIARIO', CAST('09:00' AS TIME(0)), NULL),
  ('REUNIONES_RETENCION',  N'Retención de notas de reuniones',       N'Borra las notas y transcripciones pegadas de reuniones más antiguas que COMERCIAL_RETENCION_MESES. El resumen y los acuerdos se conservan.', 'SQL', 'UPD_REUNION_RETENCION', 'DIARIO', CAST('03:00' AS TIME(0)), NULL)
) AS O (codigo, nombre, descripcion, tipo, sp, frecuencia, hora, minutos)
   ON D.job_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (job_codigo, job_nombre, job_descripcion, job_tipo, job_sp, job_frecuencia, job_hora, job_minutos, job_activo, job_proxima)
    VALUES (O.codigo, O.nombre, O.descripcion, O.tipo, O.sp, O.frecuencia, O.hora, O.minutos, 1, [dbo].[FNC_JOB_PROXIMA](O.frecuencia, O.hora, O.minutos, @AHORA))
WHEN MATCHED THEN
    UPDATE SET D.job_nombre = O.nombre, D.job_descripcion = O.descripcion, D.job_tipo = O.tipo, D.job_sp = O.sp;
PRINT 'Catálogo de jobs registrado.'
GO

/* ---------------------------------------------------------------- ejecutor */

/* Los jobs que tocan, ya marcados «en ejecución». @CODIGO fuerza uno (para
   probarlo a mano) aunque no le toque. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_JOB_PENDIENTES]
@CODIGO VARCHAR(60) = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @T TABLE (id INT, codigo VARCHAR(60), tipo VARCHAR(5), sp VARCHAR(128), nombre NVARCHAR(150))
UPDATE [dbo].[Job]
   SET job_en_ejecucion = 1, job_ultima_inicio = @AHORA
OUTPUT inserted.job_id, inserted.job_codigo, inserted.job_tipo, inserted.job_sp, inserted.job_nombre INTO @T
 WHERE job_activo = 1
   AND (job_en_ejecucion = 0 OR job_ultima_inicio < DATEADD(HOUR, -2, @AHORA))
   AND ((@CODIGO IS NULL AND job_proxima <= @AHORA) OR job_codigo = @CODIGO)
SELECT id AS ID, codigo AS CODIGO, tipo AS TIPO, sp AS SP, nombre AS NOMBRE FROM @T ORDER BY id
GO

/* Ejecuta un job de tipo SQL. El nombre del SP sale del catálogo, nunca de
   quien llama, y se valida que exista antes de ejecutarlo. */
CREATE OR ALTER PROCEDURE [dbo].[EXE_JOB_SQL]
@JOB INT
AS
SET NOCOUNT ON
DECLARE @SP SYSNAME = (SELECT job_sp FROM [dbo].[Job] WHERE job_id = @JOB AND job_tipo = 'SQL')
IF @SP IS NULL OR OBJECT_ID(N'[dbo].' + QUOTENAME(@SP), 'P') IS NULL
BEGIN RAISERROR('1.- EL JOB NO TIENE UN PROCEDIMIENTO VÁLIDO.', 16, 1) RETURN -1 END
DECLARE @SQL NVARCHAR(300) = N'EXEC [dbo].' + QUOTENAME(@SP)
EXEC sp_executesql @SQL
RETURN 0
GO

/* Cierra una corrida: deja el resultado en el catálogo y en Job_Ejecucion, y
   calcula la próxima. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_JOB_FIN]
@JOB INT, @OK BIT, @DETALLE NVARCHAR(2000) = NULL, @GENERADAS INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @COD VARCHAR(60), @INI DATETIME
SELECT @COD = job_codigo, @INI = job_ultima_inicio FROM [dbo].[Job] WHERE job_id = @JOB
UPDATE [dbo].[Job]
   SET job_en_ejecucion = 0, job_ultima_fin = @AHORA, job_ultimo_ok = @OK, job_ultimo_detalle = LEFT(@DETALLE, 2000),
       job_proxima = [dbo].[FNC_JOB_PROXIMA](job_frecuencia, job_hora, job_minutos, @AHORA)
 WHERE job_id = @JOB
INSERT [dbo].[Job_Ejecucion] (jex_job, jex_paso, jex_cliente, jex_inicio, jex_fin, jex_generadas, jex_error)
VALUES (@COD, 'EJECUTOR', NULL, ISNULL(@INI, @AHORA), @AHORA, @GENERADAS, CASE WHEN @OK = 1 THEN NULL ELSE LEFT(@DETALLE, 2000) END)
RETURN 0
GO

/* Estado de todos los jobs (para revisar a mano o mostrar en pantalla). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_JOB]
AS
SET NOCOUNT ON
SELECT job_codigo AS CODIGO, job_nombre AS NOMBRE, job_tipo AS TIPO, job_frecuencia AS FRECUENCIA,
       CONVERT(VARCHAR(5), job_hora, 108) AS HORA, job_minutos AS MINUTOS, job_activo AS ACTIVO,
       CONVERT(VARCHAR(16), job_proxima, 120) AS PROXIMA, CONVERT(VARCHAR(16), job_ultima_inicio, 120) AS ULTIMA_INICIO,
       CONVERT(VARCHAR(16), job_ultima_fin, 120) AS ULTIMA_FIN, job_ultimo_ok AS ULTIMO_OK, job_ultimo_detalle AS ULTIMO_DETALLE,
       job_en_ejecucion AS EN_EJECUCION
  FROM [dbo].[Job] ORDER BY job_hora, job_codigo
GO

/* ---------------------------------------------------------------- jobs SQL nuevos */

/* Retención de notas de reuniones (Config: COMERCIAL_RETENCION_MESES). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REUNION_RETENCION]
AS
SET NOCOUNT ON
DECLARE @MESES INT = ISNULL(TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'COMERCIAL_RETENCION_MESES') AS INT), 12)
UPDATE [dbo].[Reunion] SET reu_notas = NULL, reu_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE reu_notas IS NOT NULL AND reu_fecha_inicio < DATEADD(MONTH, -@MESES, [dbo].[FNC_AHORA]())
SELECT @@ROWCOUNT AS BORRADAS
GO

PRINT '461_JOBS_PROGRAMADOS aplicado.'
GO
