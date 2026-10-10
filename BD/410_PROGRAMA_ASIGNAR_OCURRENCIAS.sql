/* ============================================================================
   410 · La asignación de inspecciones y tareas llega a sus ocurrencias (09-10-2026)

   Programa_Asignacion (BD/408) dice quién ejecuta una inspección o tarea: Disponible, una o
   varias personas, un grupo o una empresa externa. Los generadores solo copiaban la primera
   persona o el grupo (inspección) o nada (tarea). Desde aquí:
     · coa_proveedor / toa_proveedor: la empresa externa en la asignación de la ocurrencia.
     · UPS_PROGRAMA_ASIGNAR_OCURRENCIAS: rehace la asignación de las ocurrencias FUTURAS y
       PENDIENTES (estado 1 o 2) que nadie aceptó todavía: 1.ª persona responsable, las demás
       apoyo; el grupo o la empresa como responsable; Disponible = sin filas (en la app la toma
       quien llegue primero). Lo aceptado en la app no se toca.
     · UPD_PLAN_REALINEAR_OCURRENCIAS la llama al guardar; JOB_SIGMA_NOCTURNO la llama después de
       generar (paso «ASIGNACIONES»), para las fechas nuevas de cada noche.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF COL_LENGTH('dbo.Checklist_Ocurrencia_Asignacion', 'coa_proveedor') IS NULL ALTER TABLE [dbo].[Checklist_Ocurrencia_Asignacion] ADD coa_proveedor INT NULL
IF COL_LENGTH('dbo.Tarea_Ocurrencia_Asignacion', 'toa_proveedor') IS NULL ALTER TABLE [dbo].[Tarea_Ocurrencia_Asignacion] ADD toa_proveedor INT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMA_ASIGNAR_OCURRENCIAS]
    @CLIENTE INT,
    @TIPO    VARCHAR(3) = NULL,   -- INS · TAR · NULL = las dos
    @REF     INT = NULL,          -- cpr_inspeccion o tar_id; NULL = todas las del cliente
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @HOY DATE = CAST(GETUTCDATE() AS DATE), @AHORA DATETIME = [dbo].[FNC_AHORA]()

BEGIN TRANSACTION
IF @TIPO IS NULL OR @TIPO = 'INS'
BEGIN
    DECLARE @OC TABLE (coc INT PRIMARY KEY, grp INT)
    INSERT @OC (coc, grp)
    SELECT o.coc_id, cp.cpr_inspeccion
    FROM   [dbo].[Checklist_Ocurrencia] o
    JOIN   [dbo].[Checklist_Programacion] cp ON cp.cpr_id = o.coc_checklist_programacion
    WHERE  cp.cpr_cliente = @CLIENTE AND (@REF IS NULL OR cp.cpr_inspeccion = @REF)
      AND  o.coc_habilitado = 1 AND o.coc_checklist_ocurrencia_estado IN (1, 2) AND o.coc_fecha_programada_utc >= @HOY
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Asignacion] a WHERE a.coa_checklist_ocurrencia = o.coc_id AND a.coa_fecha_aceptacion_utc IS NOT NULL)
    DELETE a FROM [dbo].[Checklist_Ocurrencia_Asignacion] a JOIN @OC x ON x.coc = a.coa_checklist_ocurrencia
    INSERT [dbo].[Checklist_Ocurrencia_Asignacion] (coa_checklist_ocurrencia, coa_usuario, coa_grupo_trabajo, coa_proveedor, coa_es_responsable, coa_fecha_asignacion_utc, coa_usuario_creacion, coa_fecha_creacion)
    SELECT x.coc, p.pas_usuario, p.pas_grupo_trabajo, p.pas_proveedor, CASE WHEN p.pas_orden = 1 THEN 1 ELSE 0 END, GETUTCDATE(), @USUARIO, @AHORA
    FROM   @OC x JOIN [dbo].[Programa_Asignacion] p ON p.pas_tipo = 'INS' AND p.pas_ref = x.grp AND p.pas_cliente = @CLIENTE
END
IF @TIPO IS NULL OR @TIPO = 'TAR'
BEGIN
    DECLARE @OT TABLE (toc INT PRIMARY KEY, tar INT)
    INSERT @OT (toc, tar)
    SELECT o.toc_id, o.toc_tarea
    FROM   [dbo].[Tarea_Ocurrencia] o
    WHERE  o.toc_cliente = @CLIENTE AND (@REF IS NULL OR o.toc_tarea = @REF)
      AND  o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado IN (1, 2) AND o.toc_fecha_programada_utc >= @HOY AND o.toc_orden_trabajo IS NULL
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Asignacion] a WHERE a.toa_tarea_ocurrencia = o.toc_id AND a.toa_fecha_aceptacion_utc IS NOT NULL)
    DELETE a FROM [dbo].[Tarea_Ocurrencia_Asignacion] a JOIN @OT x ON x.toc = a.toa_tarea_ocurrencia
    INSERT [dbo].[Tarea_Ocurrencia_Asignacion] (toa_tarea_ocurrencia, toa_usuario, toa_grupo_trabajo, toa_proveedor, toa_es_responsable, toa_fecha_asignacion_utc, toa_usuario_creacion, toa_fecha_creacion)
    SELECT x.toc, p.pas_usuario, p.pas_grupo_trabajo, p.pas_proveedor, CASE WHEN p.pas_orden = 1 THEN 1 ELSE 0 END, GETUTCDATE(), @USUARIO, @AHORA
    FROM   @OT x JOIN [dbo].[Programa_Asignacion] p ON p.pas_tipo = 'TAR' AND p.pas_ref = x.tar AND p.pas_cliente = @CLIENTE
END
COMMIT TRANSACTION
GO

/* 408 + la asignación de las ocurrencias al final. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_REALINEAR_OCURRENCIAS]
    @CLIENTE INT,
    @TIPO    VARCHAR(3),
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST(GETUTCDATE() AS DATE), @HASTA DATE = DATEADD(DAY, 90, CAST(GETUTCDATE() AS DATE)), @AHORA DATETIME = [dbo].[FNC_AHORA](), @X INT
IF @TIPO = 'INS'
BEGIN
    UPDATE o SET coc_checklist_ocurrencia_estado = 6, coc_usuario_actualizacion = @USUARIO, coc_fecha_actualizacion = @AHORA
    FROM   [dbo].[Checklist_Ocurrencia] o JOIN [dbo].[Checklist_Programacion] cp ON cp.cpr_id = o.coc_checklist_programacion
    WHERE  cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE AND o.coc_checklist_ocurrencia_estado IN (1, 2) AND o.coc_fecha_programada_utc >= @HOY
      AND  (cp.cpr_habilitado = 0 OR NOT EXISTS (SELECT 1 FROM [dbo].[FNC_PROGRAMACION_FECHAS](cp.cpr_programacion, @HOY, @HASTA) f WHERE f.DESCARTADA = 0 AND f.FECHA = o.coc_fecha_programada_utc))
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT cpr_id FROM [dbo].[Checklist_Programacion] WHERE cpr_inspeccion = @ID AND cpr_cliente = @CLIENTE AND cpr_habilitado = 1
    OPEN c FETCH NEXT FROM c INTO @X
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[GEN_CHECKLIST_OCURRENCIAS] @CLIENTE = @CLIENTE, @CHECKLIST_PROGRAMACION = @X, @USUARIO = @USUARIO
        FETCH NEXT FROM c INTO @X
    END
    CLOSE c DEALLOCATE c
END
ELSE
BEGIN
    UPDATE o SET toc_tarea_ocurrencia_estado = 6, toc_usuario_actualizacion = @USUARIO, toc_fecha_actualizacion = @AHORA
    FROM   [dbo].[Tarea_Ocurrencia] o JOIN [dbo].[Tarea_Programacion] tp ON tp.tpr_id = o.toc_tarea_programacion
    WHERE  o.toc_tarea = @ID AND o.toc_cliente = @CLIENTE AND o.toc_tarea_ocurrencia_estado IN (1, 2) AND o.toc_fecha_programada_utc >= @HOY AND o.toc_orden_trabajo IS NULL
      AND  (tp.tpr_habilitado = 0 OR NOT EXISTS (SELECT 1 FROM [dbo].[FNC_PROGRAMACION_FECHAS](tp.tpr_programacion, @HOY, @HASTA) f WHERE f.DESCARTADA = 0 AND f.FECHA = o.toc_fecha_programada_utc))
    EXEC [dbo].[GEN_TAREA_OCURRENCIAS] @CLIENTE = @CLIENTE, @TAREA = @ID, @USUARIO = @USUARIO
END
EXEC [dbo].[UPS_PROGRAMA_ASIGNAR_OCURRENCIAS] @CLIENTE = @CLIENTE, @TIPO = @TIPO, @REF = @ID, @USUARIO = @USUARIO
GO

/* 386 + paso «ASIGNACIONES» después de generar. */
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
    WHILE @N <= 4
    BEGIN
        SET @PASO = CHOOSE(@N, 'PLANES', 'TAREAS', 'RONDAS', 'ASIGNACIONES')
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
            ELSE IF @PASO = 'ASIGNACIONES'
                EXEC [dbo].[UPS_PROGRAMA_ASIGNAR_OCURRENCIAS] @CLIENTE = @CLIENTE, @TIPO = NULL, @REF = NULL, @USUARIO = @USUARIO

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
GO

/* Lo ya programado queda alineado de una vez. */
DECLARE @C INT
DECLARE cc CURSOR LOCAL FAST_FORWARD FOR SELECT DISTINCT pas_cliente FROM [dbo].[Programa_Asignacion]
OPEN cc FETCH NEXT FROM cc INTO @C
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [dbo].[UPS_PROGRAMA_ASIGNAR_OCURRENCIAS] @CLIENTE = @C, @USUARIO = 1
    FETCH NEXT FROM cc INTO @C
END
CLOSE cc DEALLOCATE cc
GO
PRINT '410_PROGRAMA_ASIGNAR_OCURRENCIAS aplicado.'
GO
