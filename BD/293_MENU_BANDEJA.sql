USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     LA BANDEJA DE MANTENCIONES EN EL MENU (HU-087).
-- =============================================
-- EN SIGMA UNA PANTALLA EXISTE PORQUE TIENE FILA EN Menus
--   No hay Paginas.cs: el master resuelve el acceso con Token.ExigirPagina()
--   contra esta tabla. Un .aspx sin su fila aca no se puede abrir.
--
-- ESTA SI VA VISIBLE
--   Al reves que las fichas de plan, hito y actividad -que son detalles a
--   los que se entra desde su padre-, la bandeja es una pantalla de entrada:
--   es lo primero que abre un planificador en la mañana para ver que tiene
--   encima. Esconderla detras de un plan seria obligar a elegir un plan para
--   preguntar justamente por todos.
--
--   Va tercera bajo Planificacion, despues de Programaciones y Planes: se
--   configura el cada cuanto, se arma el plan, y despues se trabaja la
--   bandeja que esos dos producen.
--
-- PERMISO 116 Y NO UNO NUEVO
--   116 es VER PLANES MANTENIMIENTO, el que ya gobierna el modulo. La
--   bandeja no muestra nada que no este en el calendario del plan: lo
--   muestra junto. Quien puede ver los planes puede ver lo que toca.
--
--   Generar la orden es otra cosa y por eso NO se resuelve aca: la pantalla
--   pregunta en el servidor por "CREAR ORDEN TRABAJO" antes de generar
--   nada, que es el permiso de quien crea trabajo. Por eso tampoco lleva
--   filas en Menu_Funcion: no usa PuedeFuncion.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Bandeja de mantenciones',
         'Lo que esta por vencer o ya vencio, de todos los planes',
         4, 2222, 3, '~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx', 1, NULL, 116, 1)

    PRINT '--- Menu de la bandeja creado.'
END
ELSE
BEGIN
    UPDATE [dbo].[Menus]
       SET mnu_padre = 2222, mnu_nivel = 4, mnu_orden = 3, mnu_visible = 1,
           mnu_permiso = 116, mnu_ambito = 1
     WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx'

    PRINT '--- Menu de la bandeja ya existia: verificado.'
END
GO

SELECT  mnu_id, mnu_padre, mnu_orden, mnu_visible, mnu_permiso, mnu_nombre, mnu_link
  FROM  [dbo].[Menus]
 WHERE  mnu_padre = 2222 AND mnu_visible = 1
 ORDER  BY mnu_orden
GO

PRINT '293_MENU_BANDEJA aplicado.'
GO
