/* ============================================================================
   472 · Ocurrencias, OT automáticas y cobros: jobs frecuentes (cada hora)
   - JOB_OT_AUTOMATICAS: genera la OT de cada ocurrencia de plan que ya está disponible, de
     programaciones con «genera automáticamente», usando el SP de siempre
     (INS_ORDEN_TRABAJO_OCURRENCIA, idempotente: una ocurrencia con OT no se duplica).
     Parámetros (Sys_Parametros): OT_AUTO_DIAS_ANTES (0 = cuando abre su ventana; N = N días
     antes de la fecha programada) y OT_AUTO_ATRASO_DIAS (30: no genera OT de ocurrencias
     más atrasadas que eso).
   - JOB_OCURRENCIAS_Y_OT: ocurrencias de los próximos 90 días + asignaciones + OT.
   - OCURRENCIAS_NOCTURNO pasa a correr cada 60 min; COBROS_EMITIR y COBROS_RECORDATORIOS
     también (ambos son idempotentes). Se cambian desde la pantalla de Jobs.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

MERGE [dbo].[Sys_Parametros] AS D
USING (VALUES
  ('OT_AUTO_DIAS_ANTES',   N'OT automáticas · días de anticipación', N'0 = la OT se genera cuando la ocurrencia queda disponible; N = N días antes de su fecha programada.', '0'),
  ('OT_AUTO_ATRASO_DIAS',  N'OT automáticas · atraso máximo',        N'No se generan OT automáticas de ocurrencias más atrasadas que estos días.', '30')
) AS O (codigo, nombre, descripcion, valor)
   ON D.par_codigo = O.codigo
WHEN NOT MATCHED THEN INSERT (par_codigo, par_nombre, par_descripcion, par_valor) VALUES (O.codigo, O.nombre, O.descripcion, O.valor);
GO

CREATE OR ALTER PROCEDURE [dbo].[JOB_OT_AUTOMATICAS]
    @USUARIO INT = 1
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @ANTES INT = ISNULL(TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'OT_AUTO_DIAS_ANTES') AS INT), 0)
DECLARE @ATRASO INT = ISNULL(TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'OT_AUTO_ATRASO_DIAS') AS INT), 30)
DECLARE @CLIENTE INT, @OCU INT, @GENERADAS INT = 0, @FALLAS INT = 0, @MSG NVARCHAR(2000), @R INT

DECLARE C CURSOR LOCAL FAST_FORWARD FOR
    SELECT o.pmo_cliente, o.pmo_id
      FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
      JOIN [dbo].[Programacion] p ON p.pro_id = o.pmo_programacion
     WHERE o.pmo_habilitado = 1 AND o.pmo_orden_trabajo IS NULL
       AND o.pmo_plan_ocurrencia_estado IN (1, 2)
       AND p.pro_genera_automaticamente = 1
       AND DATEADD(DAY, -@ANTES, ISNULL(o.pmo_fecha_disponible_utc, o.pmo_fecha_programada_utc)) <= @AHORA
       AND o.pmo_fecha_programada_utc >= DATEADD(DAY, -@ATRASO, @AHORA)
     ORDER BY o.pmo_fecha_programada_utc, o.pmo_id
OPEN C
FETCH NEXT FROM C INTO @CLIENTE, @OCU
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC @R = [dbo].[INS_ORDEN_TRABAJO_OCURRENCIA] @ID = NULL, @CLIENTE = @CLIENTE, @OCURRENCIA = @OCU, @USUARIO = @USUARIO
        SET @GENERADAS = @GENERADAS + 1
    END TRY
    BEGIN CATCH
        SET @FALLAS = @FALLAS + 1
        SET @MSG = N'OT automática de la ocurrencia ' + CAST(@OCU AS NVARCHAR(20)) + N': ' + ERROR_MESSAGE()
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'JOB_OT_AUTOMATICAS', @MSG = @MSG
    END CATCH
    FETCH NEXT FROM C INTO @CLIENTE, @OCU
END
CLOSE C DEALLOCATE C
SELECT @GENERADAS AS OT_GENERADAS, @FALLAS AS FALLAS
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[JOB_OCURRENCIAS_Y_OT]
AS
SET NOCOUNT ON
EXEC [dbo].[JOB_SIGMA_NOCTURNO]
EXEC [dbo].[JOB_OT_AUTOMATICAS]
RETURN 0
GO

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
UPDATE [dbo].[Job]
   SET job_nombre = N'Ocurrencias y OT automáticas', job_sp = 'JOB_OCURRENCIAS_Y_OT',
       job_descripcion = N'Genera las ocurrencias de los próximos 90 días de lo que se genera automáticamente, las asigna y crea la OT de cada ocurrencia que ya está disponible (OT_AUTO_DIAS_ANTES, OT_AUTO_ATRASO_DIAS). Corre cada hora; no duplica nada.',
       job_frecuencia = 'MINUTOS', job_hora = NULL, job_minutos = 60,
       job_proxima = [dbo].[FNC_JOB_PROXIMA]('MINUTOS', NULL, 60, @AHORA)
 WHERE job_codigo = 'OCURRENCIAS_NOCTURNO' AND job_frecuencia = 'DIARIO'

UPDATE [dbo].[Job]
   SET job_frecuencia = 'MINUTOS', job_hora = NULL, job_minutos = 60,
       job_proxima = [dbo].[FNC_JOB_PROXIMA]('MINUTOS', NULL, 60, @AHORA)
 WHERE job_codigo IN ('COBROS_EMITIR', 'COBROS_RECORDATORIOS') AND job_frecuencia = 'DIARIO'
GO

PRINT '472_JOBS_FRECUENTES_OT_AUTOMATICA aplicado.'
