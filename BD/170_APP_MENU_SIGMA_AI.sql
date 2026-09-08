USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     REGISTRA EL ANALISIS DE SIGMA AI EN EL MENU.
-- =============================================
-- VA PRIMERO EN LA LISTA
--
--   El orden 1 lo tiene Inicio, que no es una opcion de menu sino el destino
--   de la barra. Entre las opciones, SIGMA AI abre la lista porque responde la
--   pregunta que se hace antes que las otras: donde hay que mirar hoy. Las
--   tareas y las pautas dicen que hacer; esto dice que se esta poniendo feo.
--
--   El permiso es `VER PREDICCIONES`, creado en el bloque 169. Sin el, la fila
--   no aparece: la seguridad de SIGMA es por datos y una pantalla existe para
--   alguien cuando hay una fila apuntada a un permiso que su perfil tiene.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @APP INT = (SELECT [mnu_id] FROM [dbo].[Menus]
                     WHERE [mnu_link] = N'#' AND [mnu_nombre] = N'App'
                       AND [mnu_nivel] = 1)

IF @APP IS NULL
BEGIN
    RAISERROR('No existe el nodo App del menu.', 16, 1)
    RETURN
END

/* Las que ya estaban corren un lugar: SIGMA AI toma el 2. */
UPDATE [dbo].[Menus]
   SET [mnu_orden] = [mnu_orden] + 1
 WHERE [mnu_padre] = @APP
   AND [mnu_orden] BETWEEN 2 AND 90
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m2
                    WHERE m2.[mnu_link] = N'app://sigma-ai')

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT
     N'Análisis de SIGMA AI', N'Predicciones y equipos vigilados', 2, @APP, 2
    ,N'app://sigma-ai', 1, N'mdi mdi-chart-line', p.[prm_id], 2
  FROM [dbo].[Permiso] p
 WHERE p.[prm_codigo] = N'VER PREDICCIONES'
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m
                    WHERE m.[mnu_link] = N'app://sigma-ai')

PRINT '  Menu de SIGMA AI registrado.'
GO

SELECT   m.[mnu_orden], m.[mnu_nombre], m.[mnu_link]
        ,ISNULL(p.[prm_codigo], N'(sin permiso)') AS [PERMISO]
FROM     [dbo].[Menus]    m
LEFT JOIN [dbo].[Permiso] p ON p.[prm_id] = m.[mnu_permiso]
WHERE    m.[mnu_link] LIKE N'app://%'
ORDER BY m.[mnu_orden]
GO
