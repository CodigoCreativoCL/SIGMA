USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     REGISTRA TAREAS Y CHECKLIST EN EL MENU DE LA APP.
-- =============================================
-- REGISTRAR UNA PANTALLA ES UN INSERT, NO CODIGO
--
--   La seguridad de SIGMA es por datos: una pantalla existe para alguien
--   cuando hay una fila en `Menus` apuntada a un permiso que su perfil tiene.
--   La app resuelve el destino contra `rutasApp`, y una ruta que llega del
--   servidor y no esta en ese mapa no navega y lo dice —es preferible avisar
--   que una pantalla falta a abrir una en blanco—.
--
--   El checklist entra aca junto con tareas porque su bloque (156-158) creo el
--   permiso pero nunca registro la pantalla: quedaba accesible solo por la
--   lista fija de «Mas», o sea visible para quien no tenia el permiso. Es la
--   misma omision, y se cierra en el mismo lugar.
--
--   Faltan por registrar las pantallas anteriores -ordenes, existencias,
--   permisos de trabajo, escaneo, alertas-. No se tocan aca para no mezclar
--   con lo de este bloque; van en uno propio.
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
    RAISERROR('No existe el nodo App del menu. Revisar el bloque que lo creo.', 16, 1)
    RETURN
END

DECLARE @NUEVOS TABLE
    ([nombre]      NVARCHAR(100)
    ,[descripcion] NVARCHAR(200)
    ,[orden]       INT
    ,[link]        NVARCHAR(200)
    ,[icono]       NVARCHAR(100)
    ,[permiso]     NVARCHAR(60))

INSERT INTO @NUEVOS VALUES
     (N'Mis tareas', N'Tareas breves en terreno', 2,
      N'app://tareas', N'mdi mdi-check-circle-outline', N'EJECUTAR TAREA')

    ,(N'Pautas de inspección', N'Checklist en terreno', 3,
      N'app://checklist', N'mdi mdi-clipboard-check-outline', N'EJECUTAR CHECKLIST')

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT
     n.[nombre], n.[descripcion], 2, @APP, n.[orden]
    ,n.[link], 1, n.[icono], p.[prm_id], 2                  -- ambito 2 = movil
  FROM @NUEVOS            n
  JOIN [dbo].[Permiso] p ON p.[prm_codigo] COLLATE DATABASE_DEFAULT = n.[permiso]
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m
                    WHERE m.[mnu_link] COLLATE DATABASE_DEFAULT = n.[link])

PRINT '  Menus de la app registrados.'
GO

SELECT   m.[mnu_id], m.[mnu_nombre], m.[mnu_orden], m.[mnu_link], p.[prm_codigo]
FROM     [dbo].[Menus]   m
LEFT JOIN [dbo].[Permiso] p ON p.[prm_id] = m.[mnu_permiso]
WHERE    m.[mnu_link] LIKE N'app://%'
ORDER BY m.[mnu_orden]
GO
