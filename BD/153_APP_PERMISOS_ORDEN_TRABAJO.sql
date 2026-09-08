USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     LOS CUATRO PERMISOS DE ORDENES DE TRABAJO EN TERRENO.
--                  HU-110, HU-113, HU-114, HU-119, HU-121.
-- =============================================
-- POR QUE SON CUATRO Y NO UNO
--
--   Ver, crear, tomar y ejecutar son decisiones distintas sobre la misma
--   entidad, y en una planta las toman personas distintas:
--
--     VER      lo tiene todo el que trabaja en mantenimiento, incluido el
--              bodeguero: necesita saber para que OT le piden un repuesto.
--
--     CREAR    abre trabajo. Un tecnico que ve una falla tiene que poder
--              levantarla en el momento -si no, la anota en papel y se
--              pierde-, asi que tambien lo tiene.
--
--     TOMAR    se hace cargo. Es del que ejecuta, no del que planifica.
--
--     EJECUTAR completa pasos y finaliza. Es el mismo grupo que TOMAR, pero
--              se separa porque el dia que exista un rol de "apoyo" que
--              acompana sin poder cerrar pasos, la distincion ya esta hecha.
--
--   Un permiso unico habria obligado a elegir entre darle al bodeguero la
--   posibilidad de cerrar pasos o quitarle la de ver la OT.
--
-- EL CIERRE NO ESTA AQUI
--
--   Cerrar la OT es del planificador o el supervisor, y su regla ya vive en
--   UPD_ORDEN_TRABAJO_CERRAR. La app de terreno FINALIZA -deja la orden en
--   espera de cierre-, que es otra cosa: esa separacion es la que hace que el
--   registro sirva como respaldo.
--
-- LOS PERFILES SE RESUELVEN POR NOMBRE
--
--   Los ids de Perfiles no son correlativos -hay saltos del 5 al 10- y un id
--   escrito a mano es lo que hace que el bloque le de el permiso al perfil
--   equivocado el dia que alguien reordene el catalogo.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ROOT  INT      = 1
DECLARE @AHORA DATETIME = GETDATE()

/* ---- 1. Los permisos ---- */
MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('VER ORDENES TRABAJO', 'Ver ordenes de trabajo',
       'MANTENIMIENTO', 2,
       'Permite consultar la bandeja de ordenes de trabajo y la ficha de cada una desde la aplicacion movil.')
     ,('CREAR ORDEN TRABAJO', 'Crear orden de trabajo',
       'MANTENIMIENTO', 2,
       'Permite levantar una orden correctiva desde terreno, en el momento en que se detecta la falla.')
     ,('TOMAR ORDEN TRABAJO', 'Tomar orden de trabajo',
       'MANTENIMIENTO', 2,
       'Permite hacerse cargo de una orden abierta sin responsable. Quien la toma queda como ejecutor.')
     ,('EJECUTAR ORDEN TRABAJO', 'Ejecutar orden de trabajo',
       'MANTENIMIENTO', 2,
       'Permite completar los pasos de una orden y finalizarla, dejandola en espera de cierre.')
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

PRINT '  Permisos de orden de trabajo registrados.'
GO


/* ---- 2. VER: todo el que trabaja en mantenimiento ---- */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo = 'VER ORDENES TRABAJO'
AND     PER.per_nombre IN ('Tecnico de Mantenimiento',
                           'Técnico de Mantenimiento',
                           'Supervisor de Mantenimiento',
                           'Jefe de Mantenimiento',
                           'Planificador de Mantenimiento',
                           'Bodeguero',
                           'Prevencionista de Riesgos')
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)
GO


/* ---- 3. CREAR, TOMAR y EJECUTAR: los que estan frente a la maquina ----

   El Bodeguero no entra: trabaja en el pasillo, no frente al equipo. El
   Prevencionista tampoco: autoriza permisos de trabajo, no los ejecuta.
   Darles un permiso que nunca van a usar solo agranda lo que hay que revisar
   el dia que alguien audite quien puede hacer que. */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo IN ('CREAR ORDEN TRABAJO', 'TOMAR ORDEN TRABAJO', 'EJECUTAR ORDEN TRABAJO')
AND     PER.per_nombre IN ('Tecnico de Mantenimiento',
                           'Técnico de Mantenimiento',
                           'Supervisor de Mantenimiento',
                           'Jefe de Mantenimiento')
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)
GO


/* ---- 4. El planificador crea, pero no ejecuta ---- */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo = 'CREAR ORDEN TRABAJO'
AND     PER.per_nombre = 'Planificador de Mantenimiento'
AND     NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Asignados a los perfiles.'
GO


/* ---- 5. Verificacion ---- */
SELECT   PRM.prm_codigo AS PERMISO
        ,PER.per_nombre AS PERFIL
FROM     [dbo].[Perfil_Permiso] PP
JOIN     [dbo].[Permiso]  PRM ON PRM.prm_id  = PP.ppe_permiso
JOIN     [dbo].[Perfiles] PER ON PER.per_id  = PP.ppe_perfil
WHERE    PRM.prm_codigo LIKE '%ORDEN%TRABAJO%'
ORDER BY PRM.prm_codigo, PER.per_nombre
GO
