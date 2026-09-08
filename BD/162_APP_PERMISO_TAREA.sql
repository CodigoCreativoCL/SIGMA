USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     PERMISOS DE TAREA EN TERRENO (HU-103 y HU-104).
-- =============================================
-- ACA SI SON DOS
--
--   En el checklist basto uno porque la pauta la llena quien la camina y
--   nadie mas. Con las tareas no: comentar y ejecutar son cosas distintas que
--   hacen personas distintas, y la prueba esta en el bloque 161 -Cristian
--   ejecuta, Marcela responde el hilo sin tocar la tarea-.
--
--   Si fuera un permiso solo habria que elegir entre dejar que el planificador
--   cierre tareas que no camino, o que no pueda contestarle a quien las
--   camina. Las dos opciones son peores que tener dos filas.
--
-- QUIEN EJECUTA Y QUIEN COMENTA
--
--   Ejecutar: tecnico, supervisor y jefe -los que estan en planta-.
--   Comentar: esos tres mas el planificador, que programa las tareas y es
--   quien tiene que responder cuando alguien avisa que algo no se pudo hacer.
--   El bodeguero y el prevencionista no entran: ni caminan tareas ni las
--   coordinan.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('EJECUTAR TAREA', 'Ejecutar tarea en terreno',
       'MANTENIMIENTO', 2,
       'Permite empezar y cerrar una tarea desde la aplicacion movil, indicando si se pudo hacer y con que resultado. Funciona sin senal y se sincroniza despues.')

     ,('COMENTAR TAREA', 'Comentar una tarea',
       'MANTENIMIENTO', 2,
       'Permite escribir y responder comentarios en el hilo de una tarea, dictando o tecleando. Los comentarios no se editan ni se borran.')
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


/* Por nombre y no por id: los ids de Perfiles tienen saltos, y un id escrito a
   mano es lo que le da el permiso al perfil equivocado el dia que alguien
   reordene el catalogo. */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

DECLARE @ASIGNAR TABLE ([permiso] NVARCHAR(60), [perfil] NVARCHAR(120))

INSERT INTO @ASIGNAR VALUES
     ('EJECUTAR TAREA', 'Tecnico de Mantenimiento')
    ,('EJECUTAR TAREA', 'Técnico de Mantenimiento')
    ,('EJECUTAR TAREA', 'Supervisor de Mantenimiento')
    ,('EJECUTAR TAREA', 'Jefe de Mantenimiento')

    ,('COMENTAR TAREA', 'Tecnico de Mantenimiento')
    ,('COMENTAR TAREA', 'Técnico de Mantenimiento')
    ,('COMENTAR TAREA', 'Supervisor de Mantenimiento')
    ,('COMENTAR TAREA', 'Jefe de Mantenimiento')
    ,('COMENTAR TAREA', 'Planificador de Mantenimiento')

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    @ASIGNAR              A
JOIN    [dbo].[Perfiles] PER ON PER.per_nombre = A.[perfil]
JOIN    [dbo].[Permiso]  PRM ON PRM.prm_codigo = A.[permiso]
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permisos de tarea asignados.'
GO

SELECT   PRM.prm_codigo AS PERMISO, PER.per_nombre AS PERFIL
FROM     [dbo].[Perfil_Permiso] PP
JOIN     [dbo].[Permiso]  PRM ON PRM.prm_id = PP.ppe_permiso
JOIN     [dbo].[Perfiles] PER ON PER.per_id = PP.ppe_perfil
WHERE    PRM.prm_codigo IN ('EJECUTAR TAREA', 'COMENTAR TAREA')
ORDER BY PRM.prm_codigo, PER.per_nombre
GO
