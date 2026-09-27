-- =============================================
-- PROPUESTA — NO APLICADA. HU-094 es de Emilio Fuentes (27-09-2026).
-- Bryan la escribió y probó en una transacción revertida al cerrar el
-- Sprint 4, y se retiró de la base para que el dueño de la historia
-- decida. Si se usa, renumerar como BD/3xx y aplicar con -I
-- (índice filtrado). Sin este generador, los criterios #1 y #2 de
-- HU-094 no se pueden cumplir: nada convierte la programación en rondas.
-- =============================================
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     GENERAR LAS OCURRENCIAS DE LAS PAUTAS PROGRAMADAS (HU-094).
-- =============================================
-- POR QUE ESTA AQUI
--
--   HU-094 quedó construida (22-09) hasta la programación: la ficha guarda
--   pauta + recurrencia + objetivo + responsable, pero NADA convertía esa
--   regla en trabajo. Sus criterios 1 y 2 hablan de lo que se GENERA («cada
--   día se genera una ocurrencia asignada al responsable», «la ocurrencia se
--   genera para el área»), así que no se podían probar: escribir un caso de
--   prueba sobre algo que no existe no lo hace existir.
--
-- QUE HACE
--
--   Lo mismo que GEN_TAREA_OCURRENCIAS (BD/222), sobre Checklist_Programacion:
--   por cada programación de pauta habilitada pide las fechas de su
--   recurrencia entre hoy y hoy + horizonte (FNC_PROGRAMACION_FECHAS, las
--   descartadas por exclusión no se crean) y crea la ocurrencia PENDIENTE que
--   falte, sobre el activo O el área de la programación, con la versión de
--   la pauta que la programación fijó. Fecha disponible y límite salen de
--   las tolerancias de la recurrencia.
--
--   La ASIGNACIÓN nace con la ocurrencia: el responsable indicado queda como
--   responsable (coa_es_responsable = 1) y el grupo, si hay, también se
--   asigna; si no hay persona, el grupo es el responsable.
--
-- IDEMPOTENTE Y SIN DUPLICAR
--
--   Se pregunta antes de insertar por (programación de pauta, fecha), y un
--   índice único filtrado lo garantiza aunque dos corran a la vez. Correr dos
--   veces no crea nada nuevo. El rastro por recurrencia queda en
--   Programacion_Generacion, igual que planes y tareas.
-- =============================================

-- Garantía en la base, no solo en el NOT EXISTS: dos ejecuciones simultáneas
-- no pueden crear la misma ronda dos veces.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_COC_PROGRAMACION_FECHA' AND object_id = OBJECT_ID('dbo.Checklist_Ocurrencia'))
    CREATE UNIQUE INDEX [UX_COC_PROGRAMACION_FECHA]
        ON [dbo].[Checklist_Ocurrencia] ([coc_checklist_programacion], [coc_fecha_programada_utc])
        WHERE [coc_checklist_programacion] IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[GEN_CHECKLIST_OCURRENCIAS]
@CLIENTE                INT,
@CHECKLIST_PROGRAMACION INT = NULL,
@HORIZONTE_DIA          INT = 90,
@SOLO_AUTOMATICAS       BIT = 0,
@USUARIO                INT,
@GENERADAS              INT = NULL OUTPUT

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

IF @CHECKLIST_PROGRAMACION IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion]
                                                        WHERE cpr_id = @CHECKLIST_PROGRAMACION AND cpr_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION DE PAUTA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @CHECKLIST_PROGRAMACION IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion]
                                                    WHERE cpr_id = @CHECKLIST_PROGRAMACION AND cpr_habilitado = 0)
BEGIN
    RAISERROR('2.- LA PROGRAMACION ESTA DESHABILITADA: HABILITELA ANTES DE GENERAR.', 16, 1)
    RETURN -1
END

DECLARE @NUEVAS TABLE (uuid UNIQUEIDENTIFIER, cprog INT, programacion INT, version INT, activo INT, area INT,
                       grupo INT, responsable INT, fecha DATETIME, antes INT, despues INT, nombre NVARCHAR(200))

INSERT INTO @NUEVAS
SELECT  NEWID(), c.cpr_id, c.cpr_programacion, c.cpr_checklist_plantilla_version, c.cpr_activo, c.cpr_instalacion_area,
        c.cpr_grupo_trabajo, c.cpr_usuario_responsable, f.FECHA,
        ISNULL(p.pro_tolerancia_antes_minuto, 0), ISNULL(p.pro_tolerancia_despues_minuto, 0), c.cpr_nombre
FROM    [dbo].[Checklist_Programacion] c
JOIN    [dbo].[Programacion]           p ON p.pro_id = c.cpr_programacion AND p.pro_habilitado = 1
CROSS APPLY [dbo].[FNC_PROGRAMACION_FECHAS](c.cpr_programacion, @DESDE, @HASTA) f
WHERE   c.cpr_cliente = @CLIENTE AND c.cpr_habilitado = 1
  AND   (c.cpr_activo IS NOT NULL OR c.cpr_instalacion_area IS NOT NULL)
  AND   (@CHECKLIST_PROGRAMACION IS NULL OR c.cpr_id = @CHECKLIST_PROGRAMACION)
  AND   (@SOLO_AUTOMATICAS = 0 OR p.pro_genera_automaticamente = 1)
  AND   f.DESCARTADA = 0
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia] o
                    WHERE o.coc_checklist_programacion = c.cpr_id AND o.coc_fecha_programada_utc = f.FECHA)

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Checklist_Ocurrencia]
        (coc_uuid, coc_cliente, coc_checklist_programacion, coc_checklist_plantilla_version, coc_activo, coc_instalacion_area,
         coc_checklist_ocurrencia_estado, coc_fecha_programada_utc, coc_fecha_disponible_utc, coc_fecha_limite_utc,
         coc_usuario_creacion, coc_fecha_creacion, coc_habilitado)
    SELECT  uuid, @CLIENTE, cprog, version, activo, area,
            1, fecha, DATEADD(MINUTE, -antes, fecha), DATEADD(MINUTE, despues, fecha),
            @USUARIO, @DATE_NOW, 1
    FROM    @NUEVAS

    SET @GENERADAS = @@ROWCOUNT

    -- Quien la ejecuta: la persona indicada es la responsable; el grupo se
    -- asigna también y es el responsable cuando no hay persona.
    INSERT INTO [dbo].[Checklist_Ocurrencia_Asignacion]
        (coa_checklist_ocurrencia, coa_usuario, coa_grupo_trabajo, coa_es_responsable, coa_fecha_asignacion_utc, coa_usuario_creacion, coa_fecha_creacion)
    SELECT  o.coc_id, n.responsable, NULL, 1, GETUTCDATE(), @USUARIO, @DATE_NOW
    FROM    @NUEVAS n JOIN [dbo].[Checklist_Ocurrencia] o ON o.coc_uuid = n.uuid
    WHERE   n.responsable IS NOT NULL
    UNION ALL
    SELECT  o.coc_id, NULL, n.grupo, CASE WHEN n.responsable IS NULL THEN 1 ELSE 0 END, GETUTCDATE(), @USUARIO, @DATE_NOW
    FROM    @NUEVAS n JOIN [dbo].[Checklist_Ocurrencia] o ON o.coc_uuid = n.uuid
    WHERE   n.grupo IS NOT NULL

    MERGE [dbo].[Programacion_Generacion] AS g
    USING (SELECT programacion, COUNT(*) n FROM @NUEVAS GROUP BY programacion) AS s
       ON g.pge_programacion = s.programacion
    WHEN MATCHED THEN UPDATE SET
         pge_horizonte_dia = @HORIZONTE_DIA, pge_fecha_generada_hasta_utc = @HASTA, pge_ultima_ejecucion_utc = GETUTCDATE(),
         pge_ocurrencias_generadas = g.pge_ocurrencias_generadas + s.n, pge_ultimo_error = NULL,
         pge_usuario_actualizacion = @USUARIO, pge_fecha_actualizacion = @DATE_NOW
    WHEN NOT MATCHED THEN INSERT
         (pge_programacion, pge_horizonte_dia, pge_fecha_generada_hasta_utc, pge_ultima_ejecucion_utc, pge_ocurrencias_generadas, pge_usuario_creacion, pge_fecha_creacion)
         VALUES (s.programacion, @HORIZONTE_DIA, @HASTA, GETUTCDATE(), s.n, @USUARIO, @DATE_NOW);

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GEN_CHECKLIST_OCURRENCIAS', @MSG = @MSG
    RAISERROR('3.- NO FUE POSIBLE GENERAR LAS OCURRENCIAS: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT nombre AS PROGRAMACION_NOMBRE, COUNT(*) AS GENERADAS, MIN(fecha) AS PRIMERA, MAX(fecha) AS ULTIMA
FROM   @NUEVAS
GROUP BY nombre
ORDER BY nombre

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- Las ocurrencias de UNA programación de pauta, para la ficha: qué se generó,
-- sobre qué objetivo y a quién quedó asignada.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_PROGRAMACION_OCURRENCIA]
@CLIENTE                INT,
@CHECKLIST_PROGRAMACION INT,
@TOP                    INT = 15

AS
SET NOCOUNT ON

SELECT TOP (@TOP)
       o.coc_id                                       AS ID,
       o.coc_fecha_programada_utc                     AS FECHA,
       e.coe_nombre                                   AS ESTADO,
       CASE WHEN o.coc_activo IS NOT NULL THEN 'EQUIPO' ELSE 'AREA' END AS OBJETIVO_TIPO,
       COALESCE(a.act_codigo + ' · ' + a.act_nombre, ar.iar_nombre, '')   AS OBJETIVO,
       ISNULL((SELECT TOP 1 LTRIM(RTRIM(u.usu_nombre + ' ' + ISNULL(u.usu_apellido_paterno, '')))
                 FROM [dbo].[Checklist_Ocurrencia_Asignacion] x JOIN [dbo].[Usuario] u ON u.usu_id = x.coa_usuario
                WHERE x.coa_checklist_ocurrencia = o.coc_id AND x.coa_es_responsable = 1), '') AS RESPONSABLE,
       ISNULL((SELECT TOP 1 g.gtr_nombre
                 FROM [dbo].[Checklist_Ocurrencia_Asignacion] x JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = x.coa_grupo_trabajo
                WHERE x.coa_checklist_ocurrencia = o.coc_id), '') AS GRUPO
FROM   [dbo].[Checklist_Ocurrencia] o
JOIN   [dbo].[Checklist_Programacion] c ON c.cpr_id = o.coc_checklist_programacion AND c.cpr_cliente = @CLIENTE
JOIN   [dbo].[Checklist_Ocurrencia_Estado] e ON e.coe_id = o.coc_checklist_ocurrencia_estado
LEFT JOIN [dbo].[Activo] a ON a.act_id = o.coc_activo
LEFT JOIN [dbo].[Instalacion_Area] ar ON ar.iar_id = o.coc_instalacion_area
WHERE  o.coc_checklist_programacion = @CHECKLIST_PROGRAMACION AND o.coc_habilitado = 1
ORDER BY o.coc_fecha_programada_utc

SELECT COUNT(*) AS TOTAL FROM [dbo].[Checklist_Ocurrencia]
WHERE coc_checklist_programacion = @CHECKLIST_PROGRAMACION AND coc_habilitado = 1 AND coc_cliente = @CLIENTE
GO

PRINT '302_GEN_CHECKLIST_OCURRENCIAS aplicado.'
GO
