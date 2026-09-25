/* ============================================================================
   SIGMA — Bloque 258
   EL MENÚ LATERAL DE LA WEB NO MUESTRA LO DE LA APP
   ----------------------------------------------------------------------------

   Menus.mnu_ambito dice dónde vive cada opción: 1 WEB, 2 APP, 3 AMBOS. La app
   ya lo respeta (SEL_MENU_APP), pero el menú lateral de la web no: SEL_MENUS
   traía las 164 filas y por eso la barra mostraba una sección «APP» con Mis
   tareas, Pautas de inspección, Mis órdenes de trabajo, Existencias de bodega,
   Permisos de trabajo y Bitácora de planta —dieciséis opciones pensadas para
   el teléfono, varias de ellas sin página web que abrir—.

   SEL_MENUS recibe @AMBITO y devuelve lo de ese ámbito más lo de AMBOS. Sin
   el parámetro se comporta como antes, así que nada que lo llame hoy se
   rompe; la web pasa 1.

   DE PASO SE VA EL SQL ARMADO CON CONCATENACIÓN
     El cuerpo venía de 2015 y construía la consulta en un VARCHAR para
     ejecutarla con EXEC. PATRON_SP lo prohíbe —todo por parámetros— y acá no
     aportaba nada: son tres filtros opcionales que se resuelven con ISNULL en
     el WHERE. Mismas columnas, mismo orden.

   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS]
     @TIPO   INT = NULL
    ,@NIVEL  INT = NULL
    ,@PADRE  INT = NULL
    ,@AMBITO INT = NULL
AS
SET NOCOUNT ON

    SELECT  m.mnu_id            AS MNU_ID
           ,m.mnu_nombre        AS MNU_NOMBRE
           ,m.mnu_descripcion   AS MNU_DESCRIPCION
           ,m.mnu_nivel         AS MNU_NIVEL
           ,m.mnu_padre         AS MNU_PADRE
           ,m.mnu_orden         AS MNU_ORDEN
           ,m.mnu_link          AS MNU_LINK
           ,m.mnu_visible       AS MNU_VISIBLE
           ,m.mnu_icon          AS MNU_ICON
    FROM    [dbo].[Menus] m
    WHERE   m.mnu_visible = 1
      AND   (@NIVEL  IS NULL OR m.mnu_nivel = @NIVEL)
      AND   (@PADRE  IS NULL OR m.mnu_padre = @PADRE)
      /* Lo del ámbito pedido y lo que sirve en los dos. Una fila sin ámbito
         se trata como del ámbito pedido: es dato viejo, y esconderla sacaría
         del menú una opción que hoy se usa. */
      AND   (@AMBITO IS NULL OR ISNULL(m.mnu_ambito, @AMBITO) IN (@AMBITO, 3))
    ORDER BY m.mnu_orden
GO

PRINT '--- SEL_MENUS filtra por ámbito (bloque 258).'
GO
