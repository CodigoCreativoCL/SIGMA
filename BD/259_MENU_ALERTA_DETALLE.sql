/* ============================================================================
   SIGMA — Bloque 259
   LA FICHA DE UNA ALERTA SE REGISTRA EN MENUS
   ----------------------------------------------------------------------------

   Tocar una notificación llevaba a la ficha del registro relacionado y, de
   los quince tipos de alerta, solo unos pocos la tienen configurada: el
   resto terminaba en «esta notificación no tiene un registro relacionado
   configurado». Ahora abre AlertaDetalle.aspx, que cuenta la alerta —lo
   medido contra el umbral, cuándo se detectó, cuántas veces se repitió, su
   línea de tiempo y las fotos del equipo— y deja actuar sin salir.

   Como cualquier pantalla de SIGMA, existe porque tiene su fila en Menus: sin
   ella el framework no la abre. Va OCULTA (mnu_visible = 0) porque no es una
   opción del menú sino una ficha, igual que «... (detalle)» del resto de los
   módulos, y con el mismo permiso que la bandeja de alertas (68 VER ALERTAS).

   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = N'~/View/Comun/Notificaciones/AlertaDetalle.aspx')
BEGIN
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    SELECT  N'Alerta (detalle)'
           ,N'Ficha de una alerta: qué se detectó, su historia y qué hacer con ella.'
           ,m.mnu_nivel
           ,m.mnu_padre
           ,m.mnu_orden + 1
           ,N'~/View/Comun/Notificaciones/AlertaDetalle.aspx'
           ,0
           ,m.mnu_icon
           ,m.mnu_permiso
           ,m.mnu_ambito
    FROM   [dbo].[Menus] m
    WHERE  m.mnu_link = N'~/View/Comun/Notificaciones/Notificaciones.aspx'

    PRINT '--- Alerta (detalle) registrada en Menus (bloque 259).'
END
ELSE
    PRINT '--- Alerta (detalle) ya estaba registrada.'
GO
