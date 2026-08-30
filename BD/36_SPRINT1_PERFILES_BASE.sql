USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     PERFILES BASE DEL SISTEMA Y SUS PERMISOS.
-- =============================================
-- Va DESPUES de 35_SPRINT1_ICONOS_VALIDOS.
--
-- DE DONDE SALEN ESTOS PERFILES
--   No estan inventados. Son los roles que nombran los documentos del
--   proyecto:
--
--     ANEXO A §554  "Perfiles debe contener, como minimo,
--                    PLANIFICADOR_MANTENCION y TECNICO"
--     ANEXO A §655  planificaba un 05_PERFILES_BASE.sql que nunca se
--                   llego a escribir. Esto lo salda.
--     ANEXO H §281  "Perfil nuevo: Bodeguero - define minimo y maximo de
--                    stock; no compra"
--     ANEXO H §278  "UPD_ORDEN_TRABAJO_FINALIZAR (tecnico) ·
--                    UPD_ORDEN_TRABAJO_CERRAR (jefatura)"
--     HU-015 esc.3  cerrar una orden "corresponde a jefatura, supervision
--                    o planificacion"
--
-- DOS ROLES QUE NO SE CREAN, A PROPOSITO
--   PREVENCIONISTA. El ANEXO H §291 lo deja explicitamente abierto:
--   "Firma permisos pero no aparece en ningun otro flujo. Es un perfil con
--   acceso, o un nombre y una fecha que transcribe el jefe desde el papel?".
--   Crear el perfil seria responder por el equipo una pregunta que el
--   equipo dejo anotada para resolver en reunion.
--
--   CONTRATISTA. No es un usuario del sistema: es un Proveedor con
--   prv_es_contratista = 1. Un perfil aqui seria modelar dos veces la misma
--   cosa.
--
-- POR QUE per_cliente ES NULL
--   Son PLANTILLAS: perfiles del sistema que todo cliente ve y puede usar
--   tal cual. Un cliente que necesite algo distinto crea el suyo, que
--   nacera con su per_cliente y no molestara a los demas.
--
-- SE REUTILIZA LO QUE YA ESTABA
--   CONVENCIONES §6 manda buscar antes de crear. "4. Bodega" y
--   "5. Jefe de Mantenimiento" ya existian, sin usuarios y sin permisos: se
--   reutilizan y se les quita el prefijo numerico para que la lista que ve
--   el administrador de un cliente se lea pareja.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. UN PERMISO QUE FALTABA

      El ANEXO H §280 enumera cinco permisos del modulo de terreno. Cuatro
      estan en la base desde el bloque 06; AUTORIZAR PERMISO TRABAJO no
      llego a crearse. Es justamente el que necesita la jefatura para
      firmar un permiso de trabajo, asi que sin el, el perfil de Jefe de
      Mantenimiento quedaria incompleto.
   ======================================================================== */

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT N'AUTORIZAR PERMISO TRABAJO',
       N'Autorizar un permiso de trabajo',
       N'PERMISO TRABAJO',
       (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'AMBOS'),
       N'Firmar la autorización de un permiso de trabajo en terreno.',
       1, GETDATE(), 1, GETDATE(), 1, 1
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'AUTORIZAR PERMISO TRABAJO')
GO


/* ========================================================================
   2. NOMBRE DE MODULO EN MAYUSCULAS

      Los permisos del bloque 06 quedaron con el modulo en formato titulo
      ('Activos', 'Seguridad') y los posteriores en mayusculas
      ('ORGANIZACION', 'SEGURIDAD'). La pantalla de permisos agrupa por este
      campo, asi que 'Seguridad' y 'SEGURIDAD' salian como dos grupos
      distintos con el mismo nombre.
   ======================================================================== */

UPDATE [dbo].[Permiso]
   SET prm_modulo = UPPER(prm_modulo)
 WHERE prm_modulo <> UPPER(prm_modulo) COLLATE Latin1_General_BIN
GO


/* ========================================================================
   3. LOS PERFILES

      per_tipo 1 = Sistema (gente de SIGMA), 2 = Cliente (gente de la
      planta). Los tres de plataforma ya existen y no se tocan.
   ======================================================================== */

-- 3.1 Se reutilizan los dos que ya estaban, quitandoles el prefijo numerico.
UPDATE [dbo].[Perfiles]
   SET per_nombre      = N'Bodeguero',
       per_descripcion = N'Define mínimo y máximo de stock de repuestos. No compra.'
 WHERE per_id = 4 AND per_nombre = N'4. Bodega'
GO

UPDATE [dbo].[Perfiles]
   SET per_nombre      = N'Jefe de Mantenimiento',
       per_descripcion = N'Jefatura del área. Cierra órdenes de trabajo y autoriza permisos de trabajo.'
 WHERE per_id = 5 AND per_nombre = N'5. Jefe de Mantenimiento'
GO

-- 3.2 Los que faltaban.
DECLARE @P TABLE
(
    nombre         NVARCHAR(200),
    descripcion    NVARCHAR(2000),
    solo_ejecucion BIT
)

INSERT INTO @P VALUES
 (N'Administrador del Cliente',
  N'Administra la organización de su empresa: plantas, áreas, centros de costo, grupos, usuarios, perfiles y catálogos propios.',
  0),
 (N'Planificador de Mantenimiento',
  N'Planifica y programa el trabajo. Cierra órdenes de trabajo.',
  0),
 (N'Supervisor de Mantenimiento',
  N'Supervisa la ejecución en terreno. Cierra órdenes de trabajo.',
  0),
 (N'Técnico de Mantenimiento',
  N'Ejecuta el trabajo en terreno y lo finaliza. El cierre corresponde a jefatura, supervisión o planificación.',
  1)

/* COLLATE DATABASE_DEFAULT en las dos comparaciones por nombre.

   Perfiles.per_nombre es VARCHAR heredado de FacilityGes y quedo con
   SQL_Latin1_General_CP1_CI_AS, mientras que la base es Modern_Spanish_CI_AS
   y las variables de tabla nacen con la intercalacion de la base. Comparar
   una con otra sin forzar da "Cannot resolve the collation conflict". */
INSERT INTO [dbo].[Perfiles]
    (per_nombre, per_descripcion, per_tipo, per_cliente, per_solo_ejecucion,
     per_habilitado, per_usuario_creacion, per_fecha_creacion, per_usuario_act, per_fecha_act)
SELECT p.nombre, p.descripcion, 2, NULL, p.solo_ejecucion,
       1, 1, GETDATE(), 1, GETDATE()
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] x
                   WHERE x.per_nombre COLLATE DATABASE_DEFAULT = p.nombre COLLATE DATABASE_DEFAULT
                     AND x.per_cliente IS NULL)
GO

PRINT 'Perfiles base creados.'
GO


/* ========================================================================
   4. LA MATRIZ DE PERMISOS

      Se declara por NOMBRE de perfil y CODIGO de permiso, no por ids: los
      ids cambian entre ambientes y esto tiene que poder correrse en
      cualquiera.

      El criterio que separa un perfil de otro es quien puede CERRAR una
      orden. HU-015 escenario 3 lo fija: jefatura, supervision y
      planificacion si; el tecnico no. El tecnico ademas queda marcado
      per_solo_ejecucion = 1, de modo que UPS_PERFIL_PERMISO rechaza que
      alguien se lo otorgue por descuido desde la pantalla de accesos.
   ======================================================================== */

DECLARE @M TABLE (perfil NVARCHAR(200), permiso NVARCHAR(200))

/* ---- Administrador del Cliente ----
   Configura la empresa. No cierra ordenes: no es un rol operativo. */
INSERT INTO @M VALUES
 (N'Administrador del Cliente', N'VER PLANTAS'),
 (N'Administrador del Cliente', N'CREAR EDITAR PLANTAS'),
 (N'Administrador del Cliente', N'VER AREAS'),
 (N'Administrador del Cliente', N'CREAR EDITAR AREAS'),
 (N'Administrador del Cliente', N'VER CENTROS COSTO'),
 (N'Administrador del Cliente', N'CREAR EDITAR CENTROS COSTO'),
 (N'Administrador del Cliente', N'VER GRUPOS TRABAJO'),
 (N'Administrador del Cliente', N'CREAR EDITAR GRUPOS TRABAJO'),
 (N'Administrador del Cliente', N'VER ESPECIALIDADES USUARIO'),
 (N'Administrador del Cliente', N'CREAR EDITAR ESPECIALIDADES USUARIO'),
 (N'Administrador del Cliente', N'VER CATALOGOS'),
 (N'Administrador del Cliente', N'CREAR EDITAR CATALOGOS'),
 (N'Administrador del Cliente', N'VER PERFILES'),
 (N'Administrador del Cliente', N'VER USUARIOS'),
 (N'Administrador del Cliente', N'VER ACCESOS'),
 (N'Administrador del Cliente', N'VER PERMISOS USUARIO'),
 (N'Administrador del Cliente', N'ASIGNAR PERMISO TERRENO'),
 (N'Administrador del Cliente', N'VER CLIENTE IDENTIDAD'),
 (N'Administrador del Cliente', N'VER CLIENTE USUARIOS'),
 (N'Administrador del Cliente', N'CREAR EDITAR CLIENTE USUARIOS')

/* ---- Jefe de Mantenimiento ----
   Jefatura: cierra, autoriza permisos de trabajo y concede excepciones. */
INSERT INTO @M VALUES
 (N'Jefe de Mantenimiento', N'VER PLANTAS'),
 (N'Jefe de Mantenimiento', N'VER AREAS'),
 (N'Jefe de Mantenimiento', N'VER CENTROS COSTO'),
 (N'Jefe de Mantenimiento', N'VER GRUPOS TRABAJO'),
 (N'Jefe de Mantenimiento', N'CREAR EDITAR GRUPOS TRABAJO'),
 (N'Jefe de Mantenimiento', N'VER ESPECIALIDADES USUARIO'),
 (N'Jefe de Mantenimiento', N'CREAR EDITAR ESPECIALIDADES USUARIO'),
 (N'Jefe de Mantenimiento', N'VER CATALOGOS'),
 (N'Jefe de Mantenimiento', N'VER CLIENTE USUARIOS'),
 (N'Jefe de Mantenimiento', N'CERRAR OT'),
 (N'Jefe de Mantenimiento', N'ADJUNTAR OT EXTERNA'),
 (N'Jefe de Mantenimiento', N'AGREGAR COMPANERO ACTIVIDAD'),
 (N'Jefe de Mantenimiento', N'AUTORIZAR PERMISO TRABAJO'),
 (N'Jefe de Mantenimiento', N'GESTIONAR STOCK'),
 (N'Jefe de Mantenimiento', N'ASIGNAR PERMISO TERRENO'),
 (N'Jefe de Mantenimiento', N'VER PERMISOS USUARIO'),
 (N'Jefe de Mantenimiento', N'CREAR ACTIVO TERRENO'),
 (N'Jefe de Mantenimiento', N'CREAR COMPONENTE TERRENO'),
 (N'Jefe de Mantenimiento', N'CREAR REPUESTO TERRENO')

/* ---- Planificador de Mantenimiento ----
   Arma el plan y arma las cuadrillas. Cierra, por jerarquia. */
INSERT INTO @M VALUES
 (N'Planificador de Mantenimiento', N'VER PLANTAS'),
 (N'Planificador de Mantenimiento', N'VER AREAS'),
 (N'Planificador de Mantenimiento', N'VER CENTROS COSTO'),
 (N'Planificador de Mantenimiento', N'VER GRUPOS TRABAJO'),
 (N'Planificador de Mantenimiento', N'CREAR EDITAR GRUPOS TRABAJO'),
 (N'Planificador de Mantenimiento', N'VER ESPECIALIDADES USUARIO'),
 (N'Planificador de Mantenimiento', N'VER CATALOGOS'),
 (N'Planificador de Mantenimiento', N'CERRAR OT'),
 (N'Planificador de Mantenimiento', N'ADJUNTAR OT EXTERNA'),
 (N'Planificador de Mantenimiento', N'AGREGAR COMPANERO ACTIVIDAD'),
 (N'Planificador de Mantenimiento', N'CREAR ACTIVO TERRENO'),
 (N'Planificador de Mantenimiento', N'CREAR COMPONENTE TERRENO'),
 (N'Planificador de Mantenimiento', N'CREAR REPUESTO TERRENO')

/* ---- Supervisor de Mantenimiento ----
   Esta en terreno con el equipo. Cierra, pero no planifica ni compra. */
INSERT INTO @M VALUES
 (N'Supervisor de Mantenimiento', N'VER PLANTAS'),
 (N'Supervisor de Mantenimiento', N'VER AREAS'),
 (N'Supervisor de Mantenimiento', N'VER GRUPOS TRABAJO'),
 (N'Supervisor de Mantenimiento', N'VER ESPECIALIDADES USUARIO'),
 (N'Supervisor de Mantenimiento', N'VER CATALOGOS'),
 (N'Supervisor de Mantenimiento', N'CERRAR OT'),
 (N'Supervisor de Mantenimiento', N'AGREGAR COMPANERO ACTIVIDAD'),
 (N'Supervisor de Mantenimiento', N'AUTORIZAR PERMISO TRABAJO'),
 (N'Supervisor de Mantenimiento', N'CREAR ACTIVO TERRENO'),
 (N'Supervisor de Mantenimiento', N'CREAR COMPONENTE TERRENO'),
 (N'Supervisor de Mantenimiento', N'CREAR REPUESTO TERRENO')

/* ---- Tecnico de Mantenimiento ----
   Ejecuta y FINALIZA. No cierra: esa es la regla de HU-015 escenario 3.
   Los tres permisos de terreno estan porque el tecnico es quien descubre
   equipos y repuestos que no estaban en el sistema mientras trabaja. */
INSERT INTO @M VALUES
 (N'Técnico de Mantenimiento', N'VER PLANTAS'),
 (N'Técnico de Mantenimiento', N'VER AREAS'),
 (N'Técnico de Mantenimiento', N'VER GRUPOS TRABAJO'),
 (N'Técnico de Mantenimiento', N'VER CATALOGOS'),
 (N'Técnico de Mantenimiento', N'AGREGAR COMPANERO ACTIVIDAD'),
 (N'Técnico de Mantenimiento', N'CREAR ACTIVO TERRENO'),
 (N'Técnico de Mantenimiento', N'CREAR COMPONENTE TERRENO'),
 (N'Técnico de Mantenimiento', N'CREAR REPUESTO TERRENO')

/* ---- Bodeguero ----
   "Define minimo y maximo de stock. No compra." (ANEXO H §281) */
INSERT INTO @M VALUES
 (N'Bodeguero', N'VER PLANTAS'),
 (N'Bodeguero', N'VER AREAS'),
 (N'Bodeguero', N'VER CATALOGOS'),
 (N'Bodeguero', N'GESTIONAR STOCK'),
 (N'Bodeguero', N'CREAR REPUESTO TERRENO')


-- Mismo motivo que arriba para el COLLATE en el JOIN por nombre de perfil.
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  per.per_id, prm.prm_id, 1
FROM    @M m
INNER JOIN [dbo].[Perfiles] per ON per.per_nombre COLLATE DATABASE_DEFAULT = m.perfil COLLATE DATABASE_DEFAULT
                               AND per.per_cliente IS NULL
INNER JOIN [dbo].[Permiso]  prm ON prm.prm_codigo COLLATE DATABASE_DEFAULT = m.permiso COLLATE DATABASE_DEFAULT
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = per.per_id AND pp.ppe_permiso = prm.prm_id)
GO

PRINT 'Matriz de permisos aplicada.'
GO


/* ========================================================================
   5. ROOT SIGUE TENIENDOLO TODO
      Incluye el permiso nuevo de este bloque.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   COMPROBACION

   Un permiso de la matriz que no encuentre su perfil o su permiso NO
   inserta nada y no avisa. Por eso se cuenta: si algun perfil aparece con
   menos permisos de los declarados, hay un nombre mal escrito.
   ======================================================================== */

SELECT  p.per_id,
        p.per_nombre                                        AS perfil,
        CASE p.per_tipo WHEN 1 THEN 'Sistema' ELSE 'Cliente' END AS tipo,
        CASE WHEN p.per_cliente IS NULL THEN 'Plantilla' ELSE 'Propio' END AS alcance,
        p.per_solo_ejecucion                                AS solo_ejecuta,
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = p.per_id) AS permisos,
        CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                          INNER JOIN [dbo].[Permiso] pr ON pr.prm_id = pp.ppe_permiso
                          WHERE pp.ppe_perfil = p.per_id AND pr.prm_codigo = N'CERRAR OT')
             THEN 'SI' ELSE 'no' END                        AS cierra_ot
FROM    [dbo].[Perfiles] p
ORDER BY p.per_tipo, p.per_id
GO

SELECT 'perfiles base'    AS control, COUNT(*) AS valor, 6 AS esperado
FROM   [dbo].[Perfiles]
WHERE  per_tipo = 2 AND per_cliente IS NULL
UNION ALL
SELECT 'perfiles sin permisos (deben ser 0)', COUNT(*), 0
FROM   [dbo].[Perfiles] p
WHERE  p.per_tipo = 2
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = p.per_id)
UNION ALL
SELECT 'el técnico NO cierra OT', COUNT(*), 0
FROM   [dbo].[Perfil_Permiso] pp
INNER JOIN [dbo].[Perfiles] p ON p.per_id = pp.ppe_perfil
INNER JOIN [dbo].[Permiso]  r ON r.prm_id = pp.ppe_permiso
WHERE  p.per_nombre COLLATE DATABASE_DEFAULT = N'Técnico de Mantenimiento' COLLATE DATABASE_DEFAULT
  AND  r.prm_codigo = N'CERRAR OT'
UNION ALL
SELECT 'modulos de permiso en mayúsculas', COUNT(*), 0
FROM   [dbo].[Permiso]
WHERE  prm_modulo <> UPPER(prm_modulo) COLLATE Latin1_General_BIN
GO
