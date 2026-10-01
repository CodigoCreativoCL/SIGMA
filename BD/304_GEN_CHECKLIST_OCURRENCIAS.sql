USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           28-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-094) GEN_CHECKLIST_OCURRENCIAS.
--
--   Genera las ocurrencias de checklist a partir de sus programaciones
--   (Checklist_Programacion), igual que GEN_TAREA_OCURRENCIAS para tareas.
--   Faltaba: la programacion se podia crear, pero nada generaba ocurrencias.
--
--   Reutiliza FNC_PROGRAMACION_FECHAS para el calculo de fechas por recurrencia.
--   El objetivo (activo o area) y el responsable salen de la programacion:
--     CA-1: cada fecha de la recurrencia -> una ocurrencia asignada al responsable.
--     CA-2: si la programacion apunta a un area, la ocurrencia se genera para el area.
--   Idempotente: no duplica ocurrencias ya generadas (misma programacion + fecha).
-- =============================================
GO

CREATE OR ALTER PROCEDURE [dbo].[GEN_CHECKLIST_OCURRENCIAS]
@CLIENTE                 INT,
@CHECKLIST_PROGRAMACION  INT = NULL,
@HORIZONTE_DIA           INT = 90,
@USUARIO                 INT,
@GENERADAS               INT = NULL OUTPUT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@HORIZONTE_DIA IS NULL OR @HORIZONTE_DIA < 1) SET @HORIZONTE_DIA = 90
IF (@HORIZONTE_DIA > 730) SET @HORIZONTE_DIA = 730

DECLARE @DESDE DATE = CAST(GETUTCDATE() AS DATE)
DECLARE @HASTA DATE = DATEADD(DAY, @HORIZONTE_DIA, @DESDE)

IF @CHECKLIST_PROGRAMACION IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] WHERE cpr_id = @CHECKLIST_PROGRAMACION AND cpr_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION DE CHECKLIST NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @NUEVAS TABLE (cprog INT, programacion INT, plantilla_version INT, activo INT, area INT,
                       responsable INT, grupo INT, fecha DATETIME, antes INT, despues INT,
                       programacion_nombre NVARCHAR(400))

INSERT INTO @NUEVAS
SELECT  cp.cpr_id, cp.cpr_programacion, cp.cpr_checklist_plantilla_version,
        cp.cpr_activo, cp.cpr_instalacion_area, cp.cpr_usuario_responsable, cp.cpr_grupo_trabajo,
        f.FECHA, ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0), cp.cpr_nombre
FROM    [dbo].[Checklist_Programacion] cp
JOIN    [dbo].[Programacion]           p ON p.pro_id = cp.cpr_programacion AND p.pro_habilitado = 1
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](cp.cpr_programacion, @DESDE, @HASTA) f
WHERE   cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1
  AND   (@CHECKLIST_PROGRAMACION IS NULL OR cp.cpr_id = @CHECKLIST_PROGRAMACION)
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia] o
                    WHERE o.coc_checklist_programacion = cp.cpr_id AND o.coc_fecha_programada_utc = f.FECHA)

DECLARE @INS TABLE (coc_id INT, cprog INT, fecha DATETIME)

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Checklist_Ocurrencia]
        (coc_uuid, coc_cliente, coc_checklist_programacion, coc_checklist_plantilla_version,
         coc_activo, coc_instalacion_area, coc_checklist_ocurrencia_estado,
         coc_fecha_programada_utc, coc_fecha_disponible_utc, coc_fecha_limite_utc,
         coc_usuario_creacion, coc_fecha_creacion, coc_habilitado)
    OUTPUT INSERTED.coc_id, INSERTED.coc_checklist_programacion, INSERTED.coc_fecha_programada_utc
        INTO @INS (coc_id, cprog, fecha)
    SELECT  NEWID(), @CLIENTE, cprog, plantilla_version,
            activo, area, 1,
            fecha, DATEADD(MINUTE, -antes, fecha), DATEADD(MINUTE, despues, fecha),
            @USUARIO, @DATE_NOW, 1
    FROM    @NUEVAS

    SET @GENERADAS = @@ROWCOUNT

    -- CA-1: cada ocurrencia queda asignada al responsable (o al grupo) de la
    -- programacion. Solo se asigna cuando la programacion define uno.
    INSERT INTO [dbo].[Checklist_Ocurrencia_Asignacion]
        (coa_checklist_ocurrencia, coa_usuario, coa_grupo_trabajo, coa_es_responsable,
         coa_fecha_asignacion_utc, coa_usuario_creacion, coa_fecha_creacion)
    SELECT  i.coc_id, n.responsable, n.grupo, 1, @DATE_NOW, @USUARIO, @DATE_NOW
    FROM    @INS i
    JOIN    @NUEVAS n ON n.cprog = i.cprog AND n.fecha = i.fecha
    WHERE   n.responsable IS NOT NULL OR n.grupo IS NOT NULL

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GEN_CHECKLIST_OCURRENCIAS', @MSG = @MSG
    RAISERROR('2.- NO FUE POSIBLE GENERAR LAS OCURRENCIAS DE CHECKLIST: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT  programacion_nombre AS PROGRAMACION_NOMBRE, COUNT(*) AS GENERADAS,
        MIN(fecha) AS PRIMERA, MAX(fecha) AS ULTIMA
FROM    @NUEVAS
GROUP BY programacion_nombre
ORDER BY programacion_nombre

RETURN 0
GO

PRINT '304_GEN_CHECKLIST_OCURRENCIAS aplicado.'
GO
