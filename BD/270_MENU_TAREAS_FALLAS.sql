USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     MANTENIMIENTO SE ORDENA POR MODULOS: TAREAS Y CORRECTIVO.
-- =============================================
-- La rama tenia nueve entradas sueltas al mismo nivel. Se agrupan por modulo,
-- como ya se hizo con Planificacion (bloque 269).
--
-- Queda:
--     Mantenimiento
--       - Planificacion            (bloque 269)
--       - Procedimientos
--       - ... inspeccion           (la agrupa Emilio Fuentes)
--       - Tareas
--           - Tareas recurrentes
--           - Categorias de tarea
--       - Ordenes de trabajo y fallas
--           - Ordenes de trabajo
--           - Fallas
--
-- POR QUE FALLAS VA CON ORDENES Y NO APARTE
--   Porque es la misma epica del backlog: EP-12 se llama "Ordenes de trabajo
--   y fallas". Y porque es el mismo recorrido: se registra la falla, se
--   diagnostica, sale la orden correctiva, se cierra, y la indisponibilidad
--   que dejo alimenta los indicadores. Separarlas en dos menus parte en dos
--   un trabajo que nadie hace en dos partes.
--
--   La ficha de indisponibilidad no tiene entrada propia a proposito: no
--   existe una pantalla que las liste. Se registran desde la falla y desde el
--   centro del activo, que es donde se miran.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @MANTENIMIENTO INT = 2154
DECLARE @TAREAS INT, @CORRECTIVO INT

/* ========================== 1. TAREAS ========================== */
SELECT @TAREAS = [mnu_id] FROM [dbo].[Menus]
 WHERE [mnu_padre] = @MANTENIMIENTO AND [mnu_nombre] = N'Tareas'

IF @TAREAS IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden],
         [mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
    VALUES
        (N'Tareas', N'El trabajo programable que no interviene una máquina.', 3, @MANTENIMIENTO, 6,
         '#', 1, 'mdi mdi-checkbox-marked-circle-outline', NULL, 1)

    SELECT @TAREAS = [mnu_id] FROM [dbo].[Menus]
     WHERE [mnu_padre] = @MANTENIMIENTO AND [mnu_nombre] = N'Tareas'

    PRINT '--- menu Tareas creado.'
END
ELSE
    PRINT '--- menu Tareas ya existia.'

/* ================= 2. ORDENES DE TRABAJO Y FALLAS ================= */
SELECT @CORRECTIVO = [mnu_id] FROM [dbo].[Menus]
 WHERE [mnu_padre] = @MANTENIMIENTO AND [mnu_nombre] = N'Órdenes de trabajo y fallas'

IF @CORRECTIVO IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden],
         [mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
    VALUES
        (N'Órdenes de trabajo y fallas', N'Desde que se detecta la necesidad hasta que se cierra.', 3, @MANTENIMIENTO, 8,
         '#', 1, 'mdi mdi-clipboard-text-outline', NULL, 1)

    SELECT @CORRECTIVO = [mnu_id] FROM [dbo].[Menus]
     WHERE [mnu_padre] = @MANTENIMIENTO AND [mnu_nombre] = N'Órdenes de trabajo y fallas'

    PRINT '--- menu Ordenes de trabajo y fallas creado.'
END
ELSE
    PRINT '--- menu Ordenes de trabajo y fallas ya existia.'

IF @TAREAS IS NULL OR @CORRECTIVO IS NULL
BEGIN
    RAISERROR('No se pudieron crear ni encontrar los menus de modulo.', 16, 1)
    RETURN
END

/* ---- las pantallas que se ven ---- */
UPDATE [dbo].[Menus] SET [mnu_padre] = @TAREAS, [mnu_nivel] = 4, [mnu_orden] = 1 WHERE [mnu_id] = 2190  -- Tareas recurrentes
UPDATE [dbo].[Menus] SET [mnu_padre] = @TAREAS, [mnu_nivel] = 4, [mnu_orden] = 2 WHERE [mnu_id] = 2218  -- Categorias de tarea

UPDATE [dbo].[Menus] SET [mnu_padre] = @CORRECTIVO, [mnu_nivel] = 4, [mnu_orden] = 1 WHERE [mnu_id] = 2196  -- Ordenes de trabajo
UPDATE [dbo].[Menus] SET [mnu_padre] = @CORRECTIVO, [mnu_nivel] = 4, [mnu_orden] = 2 WHERE [mnu_id] = 2199  -- Fallas

/* ---- y sus fichas, que son modales: invisibles, pero su permiso cuelga de aqui ---- */
UPDATE [dbo].[Menus] SET [mnu_padre] = @TAREAS, [mnu_nivel] = 4
 WHERE [mnu_id] IN (2191, 2192, 2219)   -- Tarea, Programacion de tarea, Categoria de tarea

UPDATE [dbo].[Menus] SET [mnu_padre] = @CORRECTIVO, [mnu_nivel] = 4
 WHERE [mnu_id] IN (2197, 2200, 2201)   -- Orden de trabajo, Falla, Indisponibilidad
GO

PRINT '270_MENU_TAREAS_FALLAS aplicado.'
GO
