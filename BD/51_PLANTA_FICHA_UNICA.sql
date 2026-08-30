/* ============================================================================
   SIGMA — Bloque 51
   UNA SOLA FICHA DE PLANTA
   ----------------------------------------------------------------------------

   Habia dos pantallas para editar la misma planta:

     ~/View/Organizacion/Plantas/Planta.aspx        completa
     ~/View/Comun/Clientes/NuevaInstalacion.aspx    parcial

   La parcial mostraba cuatro campos pero guardaba la fila entera, asi que
   borraba la zona horaria y las coordenadas de la planta cada vez que
   alguien la usaba. Se retiro del sitio; lo util que tenia -configuracion de
   la app y responsables- se mudo a Planta.aspx como secciones que aparecen
   cuando la planta ya existe.

   Aqui solo queda sacar su fila de Menus. Sin esto, el mapa de URLs
   seguiria ofreciendo un permiso para una pagina que ya no existe, y quien
   entrara por un enlace viejo veria un 404 en vez de la ficha buena.
   ============================================================================ */

DELETE FROM [dbo].[Menu_Funcion]
WHERE  mfu_menu IN (SELECT mnu_id FROM [dbo].[Menus]
                     WHERE LOWER(mnu_link) = N'~/view/comun/clientes/nuevainstalacion.aspx' COLLATE DATABASE_DEFAULT)
GO

DELETE FROM [dbo].[Menus]
WHERE  LOWER(mnu_link) = N'~/view/comun/clientes/nuevainstalacion.aspx' COLLATE DATABASE_DEFAULT
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'la ficha retirada ya no esta en Menus' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Menus]
          WHERE LOWER(mnu_link) = N'~/view/comun/clientes/nuevainstalacion.aspx' COLLATE DATABASE_DEFAULT) AS HAY,
        0 AS ESPERADO
UNION ALL
SELECT  'la ficha de planta sigue registrada',
        (SELECT COUNT(*) FROM [dbo].[Menus]
          WHERE LOWER(mnu_link) = N'~/view/organizacion/plantas/planta.aspx' COLLATE DATABASE_DEFAULT), 1
UNION ALL
SELECT  'menus que apuntan a paginas de Comun/Clientes',
        (SELECT COUNT(*) FROM [dbo].[Menus]
          WHERE LOWER(mnu_link) LIKE N'~/view/comun/clientes/%' COLLATE DATABASE_DEFAULT), 4
GO
