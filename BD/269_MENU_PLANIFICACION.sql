USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     PROGRAMACIONES Y PLANES QUEDAN BAJO UN SOLO MENU.
-- =============================================
-- Las dos pantallas responden la misma pregunta desde distinto lado: la
-- programacion dice CADA CUANTO y el plan dice QUE se hace y a QUE equipos.
-- En el menu estaban separadas por cuatro entradas, y quien arma un plan
-- entra a las dos en la misma sesion.
--
-- Queda:
--     Mantenimiento
--       - Planificacion
--           - Programaciones
--           - Planes de mantenimiento
--
-- El menu padre va SIN permiso -mnu_permiso nulo, como todas las carpetas
-- del arbol-: es una carpeta, y quien no tenga permiso de sus hijas no vera
-- ninguna. Ponerle el permiso de una de las dos dejaria la carpeta invisible
-- para quien solo tiene la otra.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @MANTENIMIENTO INT = 2154
DECLARE @GRUPO INT

SELECT  @GRUPO = [mnu_id]
  FROM  [dbo].[Menus]
 WHERE  [mnu_padre] = @MANTENIMIENTO
   AND  [mnu_nombre] = N'Planificación'

IF @GRUPO IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden],
         [mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
    VALUES
        (N'Planificación', N'Cada cuánto se hace y a qué equipos.', 3, @MANTENIMIENTO, 1,
         '#', 1, 'mdi mdi-calendar-sync-outline', NULL, 1)

    /* Se relee por nombre en vez de confiar en SCOPE_IDENTITY: si manana
       alguien pone un trigger sobre Menus, la identidad que devuelve deja de
       ser la de esta fila y las dos pantallas se irian a otra rama. */
    SELECT  @GRUPO = [mnu_id]
      FROM  [dbo].[Menus]
     WHERE  [mnu_padre] = @MANTENIMIENTO
       AND  [mnu_nombre] = N'Planificación'

    PRINT '--- menu Planificacion creado.'
END
ELSE
    PRINT '--- menu Planificacion ya existia.'

IF @GRUPO IS NULL
BEGIN
    RAISERROR('No se pudo crear ni encontrar el menu Planificacion.', 16, 1)
    RETURN
END

/* ---- las dos pantallas que se ven ---- */
UPDATE  [dbo].[Menus] SET [mnu_padre] = @GRUPO, [mnu_nivel] = 4, [mnu_orden] = 1 WHERE [mnu_id] = 2155  -- Programaciones
UPDATE  [dbo].[Menus] SET [mnu_padre] = @GRUPO, [mnu_nivel] = 4, [mnu_orden] = 2 WHERE [mnu_id] = 2183  -- Planes de mantenimiento

/* ---- y sus detalles, que son modales y no se ven, pero cuelgan de aqui ----

   El permiso de una pantalla sale de SU fila en Menus: si el detalle se queda
   colgando de otra rama, la ficha sigue funcionando pero nadie entiende de
   donde salio al revisar permisos. */
UPDATE  [dbo].[Menus] SET [mnu_padre] = @GRUPO, [mnu_nivel] = 4
 WHERE  [mnu_id] IN (2156, 2184, 2186, 2188, 2189, 2215, 2216)
GO

PRINT '269_MENU_PLANIFICACION aplicado.'
GO
