/* ============================================================================
   SIGMA — Bloque 95
   VER Y DESCARGAR UN DOCUMENTO
   ----------------------------------------------------------------------------

   QUE SE AGREGA

     `~/View/Comun/Archivos/VerArchivo.aspx`, la pantalla que entrega un
     archivo para verlo en el navegador o para bajarlo. La usan todos los
     modulos que adjuntan algo, a traves del control `wuc:Adjunto`.

   POR QUE TIENE FILA EN MENUS SI NO ES UNA PANTALLA

     Porque la seguridad de SIGMA es por datos y la regla no admite
     excepciones "porque esta no cuenta". Va invisible —no se llega por el
     menu, se llega desde la ficha que tiene el adjunto— pero con su fila,
     su permiso y su ambito.

     Ademas la pagina comprueba por su cuenta: sesion valida, que el archivo
     exista, y que sea del cliente en sesion. Esa ultima es la que importa:
     adivinar un id correlativo es barato, y es la misma clase de agujero que
     tenia Pago.aspx y se corrigio en el bloque 52.

   EL PERMISO ES VER EXISTENCIAS Y NO UNO NUEVO

     Un permiso propio obligaria a asignarlo a mano a todos los perfiles que
     ya pueden ver los modulos que adjuntan cosas, y el primer dia que
     alguien se olvide, un usuario vera la ficha con su adjunto y un enlace
     que le dice que no. Se usa el que ya tienen: lo que decide si puede ver
     ESE archivo es la comprobacion de cliente, no el permiso de pantalla.

   AMBITO 3 (AMBOS)

     La app tambien va a mostrar adjuntos.

   ORDEN: despues de 94_PERMISO_TRABAJO.sql
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @VER INT, @PADRE INT

SELECT @VER = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER EXISTENCIAS'

/* Cuelga del nodo Cliente, que es donde viven las pantallas comunes. */
SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_id = 32

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Comun/Archivos/VerArchivo.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Ver documento adjunto', 'Entrega un archivo para verlo o descargarlo',
            3, @PADRE, 99, '~/View/Comun/Archivos/VerArchivo.aspx',
            0, NULL, @VER, 3)

PRINT '--- Menu de VerArchivo.aspx listo.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  mnu_id, mnu_nombre, mnu_link, mnu_visible, mnu_permiso, mnu_ambito
FROM    [dbo].[Menus]
WHERE   mnu_link = '~/View/Comun/Archivos/VerArchivo.aspx'
GO

PRINT '95_ARCHIVO_VER aplicado.'
GO
