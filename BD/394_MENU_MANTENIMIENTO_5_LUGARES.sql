SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   394 · Menú Mantenimiento en cinco lugares · 09-10-2026  (parte a)

   Queda, en este orden:
     1 Operación             → Operacion/Operacion.aspx          (nueva)
     2 Órdenes de trabajo    → Ordenes/OrdenTrabajos.aspx         (2224, ya no es grupo)
     3 Avisos                → Avisos/Avisos.aspx                 (nueva)
     4 Planificación         → Planificacion.aspx                 (2222, antes «Centro de Planificación»)
     5 Biblioteca            → Biblioteca/Biblioteca.aspx         (nueva)

   Se OCULTAN, nunca se borran (mnu_visible = 0): Inspección (2238) con
   Pautas de inspección (2180) y Hallazgos de inspección (2193); Tareas (2223)
   con Tareas recurrentes (2190) y Categorías de tarea (2218); Listado de
   órdenes (2196) y Fallas (2199). Sus páginas siguen existiendo: redirigen al
   lugar nuevo y «?legacy=1» abre la de antes hasta que la pestaña nueva la
   reemplace. Permisos: Operación y Biblioteca heredan los del menú padre;
   Avisos y Órdenes de trabajo usan el de Fallas/OT (101).
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO
DECLARE @PADRE INT = 2154
DECLARE @PERM_PADRE INT = (SELECT mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = @PADRE)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_link = N'~/View/Mantenimiento/Operacion/Operacion.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Operación', N'Qué pasa hoy y qué está atrasado: monitoreo, ejecuciones y cumplimiento.', 3, @PADRE, 1,
            N'~/View/Mantenimiento/Operacion/Operacion.aspx', 1, 'mdi mdi-view-dashboard-outline', @PERM_PADRE, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_link = N'~/View/Mantenimiento/Avisos/Avisos.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Avisos', N'Lo que se detectó y todavía no es trabajo: fallas, hallazgos, predicciones y alertas.', 3, @PADRE, 3,
            N'~/View/Mantenimiento/Avisos/Avisos.aspx', 1, 'mdi mdi-bell-alert-outline', 101, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_link = N'~/View/Mantenimiento/Biblioteca/Biblioteca.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Biblioteca', N'Lo que se reutiliza: procedimientos, pautas de inspección, calendarios y ajustes.', 3, @PADRE, 5,
            N'~/View/Mantenimiento/Biblioteca/Biblioteca.aspx', 1, 'mdi mdi-bookshelf', @PERM_PADRE, 1)

-- Órdenes de trabajo: de grupo a entrada directa a la lista
UPDATE [dbo].[Menus]
   SET mnu_link = N'~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx', mnu_orden = 2, mnu_permiso = 101, mnu_visible = 1
 WHERE mnu_id = 2224

-- Planificación (antes Centro de Planificación)
UPDATE [dbo].[Menus]
   SET mnu_nombre = N'Planificación', mnu_descripcion = N'Planes, inspecciones, tareas y cobertura: qué se hace, cada cuánto y quién.', mnu_orden = 4
 WHERE mnu_id = 2222

-- Se ocultan (nunca se borran)
UPDATE [dbo].[Menus] SET mnu_visible = 0 WHERE mnu_id IN (2238, 2180, 2193, 2223, 2190, 2218, 2196, 2199)
GO
PRINT '394_MENU_MANTENIMIENTO_5_LUGARES aplicado.'
GO
