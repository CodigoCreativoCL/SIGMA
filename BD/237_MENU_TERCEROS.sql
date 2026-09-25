/* ============================================================================
   SIGMA — Bloque 237
   ORDEN DEL MENU TERCEROS
   ----------------------------------------------------------------------------

   Terceros tenia sus cuatro pantallas sueltas, y al agregar «Historial de
   servicios» (bloque 236) quedaba una lista plana donde no se ve que el
   historial es de los PROVEEDORES y «Vigentes y por vencer» es de los
   PERMISOS DE TRABAJO. Se ordena como Inventario: una carpeta por tema y
   las pantallas dentro.

     Terceros
       Proveedores
         Maestro de proveedores       (era «Proveedores»)
         Historial de servicios
         Proveedor (detalle)          oculta
       Permisos de trabajo
         Registro de permisos         (era «Permisos de trabajo»)
         Vigentes y por vencer
         Permiso de trabajo (detalle) oculta

   Las carpetas llevan el permiso de VER de su tema, igual que las de
   Inventario llevan el suyo: quien no ve proveedores no ve la carpeta.
   Idempotente: se reconoce por el link de cada fila.
   ============================================================================ */
USE [db_acd593_sigma]
GO

DECLARE @TERCEROS INT, @PROV INT, @PERM INT
SELECT @TERCEROS = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Terceros' AND mnu_nivel = 2

/* ---- las dos carpetas ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_link = N'#' AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Proveedores')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Proveedores', N'Contratistas y proveedores de repuestos, y lo que se les ha contratado', 3, @TERCEROS, 1, N'#', 1, N'mdi mdi-domain',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PROVEEDORES'), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_link = N'#' AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Permisos de trabajo')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Permisos de trabajo', N'Los permisos que habilitan un trabajo y cuáles están por vencer', 3, @TERCEROS, 2, N'#', 1, N'mdi mdi-shield-check-outline',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PERMISOS TRABAJO'), 3)

SELECT @PROV = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_link = N'#' AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Proveedores'
SELECT @PERM = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_link = N'#' AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Permisos de trabajo'

/* ---- las pantallas, cada una bajo su carpeta ---- */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Maestro de proveedores', mnu_padre = @PROV, mnu_nivel = 4, mnu_orden = 1, mnu_icon = N'mdi mdi-domain'
 WHERE mnu_link = N'~/View/Terceros/Proveedores/Proveedores.aspx'
UPDATE [dbo].[Menus] SET mnu_padre = @PROV, mnu_nivel = 4, mnu_orden = 2
 WHERE mnu_link = N'~/View/Terceros/Proveedores/ProveedorHistorial.aspx'
UPDATE [dbo].[Menus] SET mnu_padre = @PROV, mnu_nivel = 4, mnu_orden = 99
 WHERE mnu_link = N'~/View/Terceros/Proveedores/Proveedor.aspx'

UPDATE [dbo].[Menus] SET mnu_nombre = N'Registro de permisos', mnu_padre = @PERM, mnu_nivel = 4, mnu_orden = 1, mnu_icon = N'mdi mdi-clipboard-check-outline'
 WHERE mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx'
UPDATE [dbo].[Menus] SET mnu_padre = @PERM, mnu_nivel = 4, mnu_orden = 2, mnu_icon = N'mdi mdi-clock-alert-outline'
 WHERE mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajoVigentes.aspx'
UPDATE [dbo].[Menus] SET mnu_padre = @PERM, mnu_nivel = 4, mnu_orden = 99
 WHERE mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx'

PRINT '--- Menu Terceros ordenado en dos carpetas (bloque 237).'
GO
