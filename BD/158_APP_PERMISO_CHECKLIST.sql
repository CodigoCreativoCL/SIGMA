USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     EL PERMISO DE EJECUTAR CHECKLIST EN TERRENO (HU-095).
-- =============================================
-- ES UNO SOLO, Y NO CUATRO
--
--   A diferencia de las ordenes -donde ver, crear, tomar y ejecutar las hacen
--   personas distintas-, la pauta la llena quien la recorre. No hay un rol que
--   pueda ver una ejecucion pero no responderla: mirar la pauta de otro sin
--   poder llenarla no es un caso de uso, es un informe, y eso vive en la web.
--
--   Disenar el catalogo de permisos «por si acaso» agranda lo que hay que
--   revisar el dia que alguien audite quien puede hacer que.
--
-- QUIEN RECORRE
--
--   Tecnico, supervisor y jefe. El planificador arma las pautas en la web pero
--   no las camina; el bodeguero y el prevencionista no hacen rondas de
--   condicion.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('EJECUTAR CHECKLIST', 'Ejecutar checklist en terreno',
       'MANTENIMIENTO', 2,
       'Permite abrir una pauta de inspeccion desde la aplicacion movil, responder sus items y enviarla. La pauta se llena sin senal y se sincroniza despues.')
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


/* Los perfiles se resuelven POR NOMBRE: los ids de Perfiles tienen saltos y un
   id escrito a mano es lo que le da el permiso al perfil equivocado el dia que
   alguien reordene el catalogo. */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo = 'EJECUTAR CHECKLIST'
AND     PER.per_nombre IN ('Tecnico de Mantenimiento',
                           'Técnico de Mantenimiento',
                           'Supervisor de Mantenimiento',
                           'Jefe de Mantenimiento')
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permiso de checklist asignado.'
GO

SELECT   PRM.prm_codigo AS PERMISO, PER.per_nombre AS PERFIL
FROM     [dbo].[Perfil_Permiso] PP
JOIN     [dbo].[Permiso]  PRM ON PRM.prm_id = PP.ppe_permiso
JOIN     [dbo].[Perfiles] PER ON PER.per_id = PP.ppe_perfil
WHERE    PRM.prm_codigo = 'EJECUTAR CHECKLIST'
ORDER BY PER.per_nombre
GO
