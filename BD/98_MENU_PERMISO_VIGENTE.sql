/* ============================================================================
   SIGMA — Bloque 98
   LA PANTALLA DE PERMISOS VIGENTES EN EL MENU                         HU-064
   ----------------------------------------------------------------------------

   La seguridad de SIGMA es por datos: sin fila en Menus la pantalla no abre,
   aunque el archivo exista y el usuario sea Root.

   SE REUTILIZA `VER PERMISOS TRABAJO`

     La pantalla es de solo lectura sobre los mismos datos que ya se ven en
     el listado completo. Un permiso propio obligaria a asignarlo a mano a
     todos los perfiles que ya tienen el otro, y el primer dia que alguien se
     olvide, la pantalla queda invisible sin explicacion.

   T-3316 pide que la accion se valide en el SERVIDOR

     `Token.ExigirPagina()` lo hace en el master, contra esta fila. Y la
     exportacion vuelve a comprobar con `Token.Puede` en su handler: esconder
     el boton no es seguridad, quien manda el postback a mano se lo salta.

   ORDEN: despues de 97_PERMISO_TRABAJO_VIGENTE.sql
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @VER INT, @PADRE INT

SELECT @VER = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PERMISOS TRABAJO'
SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = 'Terceros' AND mnu_nivel = 2

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Terceros/PermisosTrabajo/PermisoTrabajoVigentes.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Vigentes y por vencer', 'Los permisos que caducan pronto',
            3, @PADRE, 3, '~/View/Terceros/PermisosTrabajo/PermisoTrabajoVigentes.aspx',
            1, NULL, @VER, 3)

PRINT '--- Menu de permisos vigentes listo.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  m.mnu_id, m.mnu_nivel, m.mnu_orden, m.mnu_nombre, m.mnu_link,
        m.mnu_visible, m.mnu_permiso, m.mnu_ambito
FROM    [dbo].[Menus] m
WHERE   m.mnu_nombre = 'Terceros'
   OR   m.mnu_link LIKE '~/View/Terceros/%'
ORDER BY m.mnu_nivel, m.mnu_orden
GO

PRINT '98_MENU_PERMISO_VIGENTE aplicado.'
GO
