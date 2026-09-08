USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     PERMISOS DE BITACORA (HU-130 y HU-131).
-- =============================================
-- DOS, Y LA LINEA VA EN OTRA PARTE
--
--   En las tareas la division fue ejecutar / comentar. Aca es **leer /
--   escribir**, y la diferencia importa: la bitacora es el relato de la planta
--   y hay mucha gente que necesita leerlo sin tener nada que anotar -el
--   planificador que arma la semana, el jefe que revisa el turno de anoche-.
--
--   La leen los seis perfiles de mantenimiento y el prevencionista, porque un
--   incidente de seguridad se entera por aca antes que por ningun informe. La
--   escriben los que estan en planta.
--
-- RECTIFICAR NO ES UN PERMISO
--
--   Es una condicion: **solo quien escribio puede rectificar**, y eso lo
--   resuelve el SP mirando `bit_usuario_creacion`. Un permiso de «rectificar
--   cualquier entrada» seria la llave para reescribir el relato ajeno, que es
--   justo lo que este modulo existe para impedir.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('VER BITACORA', 'Ver la bitacora de planta',
       'MANTENIMIENTO', 2,
       'Permite leer la linea de tiempo de la planta, sus entradas, comentarios y rectificaciones.')

     ,('REGISTRAR BITACORA', 'Escribir en la bitacora',
       'MANTENIMIENTO', 2,
       'Permite escribir entradas y comentarios en la bitacora, dictando o tecleando. Las entradas no se editan ni se borran: se rectifican, y solo por quien las escribio.')
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


DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

DECLARE @ASIGNAR TABLE ([permiso] NVARCHAR(60), [perfil] NVARCHAR(120))

INSERT INTO @ASIGNAR VALUES
     ('VER BITACORA', 'Tecnico de Mantenimiento')
    ,('VER BITACORA', 'Técnico de Mantenimiento')
    ,('VER BITACORA', 'Supervisor de Mantenimiento')
    ,('VER BITACORA', 'Jefe de Mantenimiento')
    ,('VER BITACORA', 'Planificador de Mantenimiento')
    ,('VER BITACORA', 'Prevencionista de Riesgos')

    ,('REGISTRAR BITACORA', 'Tecnico de Mantenimiento')
    ,('REGISTRAR BITACORA', 'Técnico de Mantenimiento')
    ,('REGISTRAR BITACORA', 'Supervisor de Mantenimiento')
    ,('REGISTRAR BITACORA', 'Jefe de Mantenimiento')
    ,('REGISTRAR BITACORA', 'Prevencionista de Riesgos')

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    @ASIGNAR              A
JOIN    [dbo].[Perfiles] PER ON PER.per_nombre COLLATE DATABASE_DEFAULT = A.[perfil]
JOIN    [dbo].[Permiso]  PRM ON PRM.prm_codigo COLLATE DATABASE_DEFAULT = A.[permiso]
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permisos de bitacora asignados.'
GO


-- ---------------------------------------------------------------------------
-- LA PANTALLA EN EL MENU
-- ---------------------------------------------------------------------------
DECLARE @APP INT = (SELECT [mnu_id] FROM [dbo].[Menus]
                     WHERE [mnu_link] = N'#' AND [mnu_nombre] = N'App'
                       AND [mnu_nivel] = 1)

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT
     N'Bitácora de planta', N'Lo que pasa en cada turno', 2, @APP, 9
    ,N'app://bitacora', 1, N'mdi mdi-notebook-outline', p.[prm_id], 2
  FROM [dbo].[Permiso] p
 WHERE p.[prm_codigo] = N'VER BITACORA'
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m
                    WHERE m.[mnu_link] = N'app://bitacora')

PRINT '  Menu de bitacora registrado.'
GO

SELECT   PRM.prm_codigo AS PERMISO, PER.per_nombre AS PERFIL
FROM     [dbo].[Perfil_Permiso] PP
JOIN     [dbo].[Permiso]  PRM ON PRM.prm_id = PP.ppe_permiso
JOIN     [dbo].[Perfiles] PER ON PER.per_id = PP.ppe_perfil
WHERE    PRM.prm_codigo IN ('VER BITACORA', 'REGISTRAR BITACORA')
ORDER BY PRM.prm_codigo, PER.per_nombre
GO
