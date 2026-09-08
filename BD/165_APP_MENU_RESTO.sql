USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     TERMINA DE REGISTRAR LAS PANTALLAS DE LA APP EN Menus.
-- =============================================
-- LA OMISION ERA LA MISMA EN TODAS
--
--   Cada bloque de pantalla creo su permiso y escribio su pantalla, pero
--   ninguno registro la fila en `Menus`. La lista de «Mas» las mostraba igual
--   porque estaba escrita en Dart, o sea que la app enseñaba opciones a gente
--   que no tenia el permiso para usarlas: al tocarlas la API respondia 403 y
--   quedaba pareciendo una falla del sistema en vez de lo que era.
--
--   Este bloque cierra las cuatro que faltan. Escanear, alertas y pendientes
--   NO entran: son destinos de la barra inferior y de la propia app -escanear
--   es el boton central-, no opciones de un menu administrable. Registrarlas
--   las duplicaria en «Mas».
--
-- Y UN PERMISO QUE NO EXISTIA
--
--   `ExistenciasController` y `EscaneoController` exigen `VER EXISTENCIAS` y
--   ese permiso **nunca se creo**. La pantalla de existencias no la podia
--   abrir nadie: `ExigirPermiso` no encuentra el codigo y niega. Es el mismo
--   descuido visto desde el otro lado -el codigo pide una llave que no se
--   fabrico- y se arregla aca porque es el bloque que registra esa pantalla.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1 - EL PERMISO QUE FALTABA
-- ---------------------------------------------------------------------------
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('VER EXISTENCIAS', 'Ver existencias de bodega',
       'INVENTARIO', 2,
       'Permite consultar el saldo de repuestos por bodega desde la aplicacion movil, incluyendo lo que esta bajo el minimo.')
) AS O (codigo, nombre, modulo, ambito, descripcion)
   ON D.prm_codigo = O.codigo

WHEN NOT MATCHED THEN
    INSERT (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
            prm_descripcion, prm_usuario_creacion, prm_fecha_creacion)
    VALUES (O.codigo, O.nombre, O.modulo, O.ambito,
            O.descripcion, @ROOT, @AHORA)

WHEN MATCHED THEN
    UPDATE SET  D.prm_nombre      = O.nombre
               ,D.prm_modulo      = O.modulo
               ,D.prm_descripcion = O.descripcion;
GO


/* Quien mira el saldo: los que estan en planta y el bodeguero, que es su
   trabajo. El planificador tambien, porque programar sin saber si hay
   repuesto es programar a ciegas. */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

DECLARE @ASIGNAR TABLE ([permiso] NVARCHAR(60), [perfil] NVARCHAR(120))

INSERT INTO @ASIGNAR VALUES
     ('VER EXISTENCIAS', 'Tecnico de Mantenimiento')
    ,('VER EXISTENCIAS', 'Técnico de Mantenimiento')
    ,('VER EXISTENCIAS', 'Supervisor de Mantenimiento')
    ,('VER EXISTENCIAS', 'Jefe de Mantenimiento')
    ,('VER EXISTENCIAS', 'Planificador de Mantenimiento')
    ,('VER EXISTENCIAS', 'Bodeguero')

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    @ASIGNAR              A
JOIN    [dbo].[Perfiles] PER ON PER.per_nombre COLLATE DATABASE_DEFAULT = A.[perfil]
JOIN    [dbo].[Permiso]  PRM ON PRM.prm_codigo COLLATE DATABASE_DEFAULT = A.[permiso]
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permiso VER EXISTENCIAS asignado.'
GO


-- ---------------------------------------------------------------------------
-- 2 - LAS PANTALLAS QUE FALTABAN
-- ---------------------------------------------------------------------------
DECLARE @APP INT = (SELECT [mnu_id] FROM [dbo].[Menus]
                     WHERE [mnu_link] = N'#' AND [mnu_nombre] = N'App'
                       AND [mnu_nivel] = 1)

DECLARE @NUEVOS TABLE
    ([nombre]      NVARCHAR(100)
    ,[descripcion] NVARCHAR(200)
    ,[orden]       INT
    ,[link]        NVARCHAR(200)
    ,[icono]       NVARCHAR(100)
    ,[permiso]     NVARCHAR(60))

INSERT INTO @NUEVOS VALUES
     (N'Mis órdenes de trabajo', N'Ordenes de trabajo en terreno', 4,
      N'app://ordenes-trabajo', N'mdi mdi-clipboard-text-outline', N'VER ORDENES TRABAJO')

    ,(N'Existencias de bodega', N'Saldo de repuestos', 5,
      N'app://existencias', N'mdi mdi-warehouse', N'VER EXISTENCIAS')

    ,(N'Permisos de trabajo', N'Permisos de trabajo de contratistas', 6,
      N'app://permisos-trabajo', N'mdi mdi-shield-check-outline', N'VER PERMISOS TRABAJO')

/* Sincronizacion va SIN permiso, como Inicio y Mi perfil: no muestra datos de
   nadie, muestra el estado del propio telefono. Pedir una llave para ver si la
   cola esta vacia seria poder dejar a alguien sin manera de entender por que
   no le llegan sus cosas. */
    ,(N'Sincronización', N'Estado de la cola de salida', 7,
      N'app://sincronizacion', N'mdi mdi-sync', NULL)

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT
     n.[nombre], n.[descripcion], 2, @APP, n.[orden]
    ,n.[link], 1, n.[icono], p.[prm_id], 2                  -- ambito 2 = movil
  FROM @NUEVOS             n
  LEFT JOIN [dbo].[Permiso] p ON p.[prm_codigo] COLLATE DATABASE_DEFAULT = n.[permiso]
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m
                    WHERE m.[mnu_link] COLLATE DATABASE_DEFAULT = n.[link])
   /* Un permiso escrito que no existe seria una pantalla que nadie puede
      abrir: mejor no registrarla y que se note, a registrarla muerta. */
   AND (n.[permiso] IS NULL OR p.[prm_id] IS NOT NULL)

PRINT '  Menus restantes registrados.'
GO

SELECT   m.[mnu_orden], m.[mnu_nombre], m.[mnu_link]
        ,ISNULL(p.[prm_codigo], N'(sin permiso)') AS [PERMISO]
FROM     [dbo].[Menus]    m
LEFT JOIN [dbo].[Permiso] p ON p.[prm_id] = m.[mnu_permiso]
WHERE    m.[mnu_link] LIKE N'app://%'
ORDER BY m.[mnu_orden]
GO
