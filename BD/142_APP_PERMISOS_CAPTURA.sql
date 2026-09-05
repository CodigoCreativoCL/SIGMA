USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     LOS DOS PERMISOS DE CAPTURA EN TERRENO (HU-043, HU-044).
-- =============================================
-- POR QUE EXISTE ESTE BLOQUE
--
--   El bloque 141 creo los SP de captura y la API expuso
--   POST /captura/lecturas y /captura/mediciones. Al probarlos por HTTP el
--   servidor respondio, correctamente:
--
--       403 · "Tu perfil no tiene el permiso 'REGISTRAR LECTURA'."
--
--   El endpoint estaba bien: el permiso no existia. Aca se crea y se asigna.
--
-- QUIEN CAPTURA, Y QUIEN NO
--
--   Registrar lecturas y mediciones es trabajo de terreno. Lo hacen quienes
--   estan frente al equipo: tecnico, supervisor, jefe y planificador.
--
--   NO lo hacen el Bodeguero —trabaja en el pasillo, no frente a la maquina—
--   ni el Prevencionista, que autoriza permisos de trabajo pero no ejecuta.
--   Darles un permiso que nunca van a usar solo agranda lo que hay que
--   revisar el dia que alguien audite quien puede hacer que.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ROOT INT = 1
DECLARE @AHORA DATETIME = GETDATE()

/* ---- 1. Los permisos ---- */
MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('REGISTRAR LECTURA',  'Registrar lectura de medidor',
       'ACTIVOS', 2,
       'Permite registrar la lectura de un medidor desde la aplicacion movil. En SIGMA no hay sensores: este valor lo captura una persona en su ronda.')
     ,('REGISTRAR MEDICION', 'Registrar medicion de condicion',
       'ACTIVOS', 2,
       'Permite registrar la medicion de una variable de condicion desde la aplicacion movil.')
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

PRINT '  Permisos de captura registrados.'
GO


/* ---- 2. Los perfiles que capturan ----

   Se resuelven POR NOMBRE y no por id: los ids de Perfiles no son
   correlativos —hay saltos del 5 al 10— y un id escrito a mano en un script
   es lo que hace que este bloque le de el permiso al perfil equivocado el
   dia que alguien reordene el catalogo. */
DECLARE @ROOT INT = 1
DECLARE @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo IN ('REGISTRAR LECTURA', 'REGISTRAR MEDICION')
AND     PER.per_nombre IN ('Tecnico de Mantenimiento',
                           'Técnico de Mantenimiento',
                           'Supervisor de Mantenimiento',
                           'Jefe de Mantenimiento',
                           'Planificador de Mantenimiento')
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil  = PER.per_id
                       AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Asignados a los perfiles de terreno.'
GO


/* ---- 3. Verificacion ---- */
SELECT   PRM.prm_codigo   AS PERMISO
        ,PER.per_nombre   AS PERFIL
FROM     [dbo].[Perfil_Permiso] PP
JOIN     [dbo].[Permiso] PRM  ON PRM.prm_id = PP.ppe_permiso
JOIN     [dbo].[Perfiles] PER ON PER.per_id = PP.ppe_perfil
WHERE    PRM.prm_codigo IN ('REGISTRAR LECTURA', 'REGISTRAR MEDICION')
ORDER BY PRM.prm_codigo, PER.per_nombre
GO
