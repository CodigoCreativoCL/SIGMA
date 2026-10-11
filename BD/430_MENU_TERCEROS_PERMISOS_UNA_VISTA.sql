/* ============================================================================
   SIGMA — Bloque 430
   PERMISOS DE TRABAJO EN UNA SOLA VISTA
   ----------------------------------------------------------------------------

   El Registro de permisos y «Vigentes y por vencer» eran dos pantallas sueltas
   bajo la carpeta «Permisos de trabajo» de Terceros. Como se hizo con
   Proveedores (bloque 429), se unifican en UNA pantalla con pestañas
   (View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx): «Registro de permisos»
   y «Vigentes y por vencer». Con esto Terceros queda con sus dos ítems:

     Terceros
       Proveedores            -> Proveedores.aspx      (bloque 429)
       Permisos de trabajo    -> PermisoTrabajos.aspx  (las dos pestañas)

   NADA SE BORRA, SE ESCONDE
     La carpeta «Permisos de trabajo» deja de ser contenedor (mnu_link '#') y
     pasa a enlazar directo la vista unificada; el renderer, al ver un link
     distinto de '#', la muestra como ítem y no recorre sus hijos. Las dos
     pantallas que eran ítems se dejan con mnu_visible = 0: siguen resolviendo
     su permiso por el link y los enlaces guardados a PermisoTrabajoVigentes.aspx
     siguen abriendo.

   Idempotente: se reconoce por el nombre de la carpeta y por el link de cada
   fila.
   ============================================================================ */
DECLARE @TERCEROS INT, @PERM INT
SELECT @TERCEROS = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Terceros' AND mnu_nivel = 2
SELECT @PERM = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @TERCEROS AND mnu_nivel = 3 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Permisos de trabajo'

/* ---- la carpeta «Permisos de trabajo» pasa a ser el enlace directo a la vista ---- */
UPDATE [dbo].[Menus]
   SET mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx',
       mnu_descripcion = N'El registro de permisos y los que están vigentes o por vencer',
       mnu_icon = N'mdi mdi-shield-check-outline'
 WHERE mnu_id = @PERM

/* ---- las dos pantallas pasan a ser pestañas: se ocultan, no se borran ---- */
UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx' AND mnu_id <> @PERM   -- era «Registro de permisos»
UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link = N'~/View/Terceros/PermisosTrabajo/PermisoTrabajoVigentes.aspx'                -- era «Vigentes y por vencer»
/* PermisoTrabajo.aspx (detalle/modal) ya estaba oculto. */

PRINT '--- Terceros: Permisos de trabajo unificado en una sola vista con pestañas (bloque 430).'
GO
