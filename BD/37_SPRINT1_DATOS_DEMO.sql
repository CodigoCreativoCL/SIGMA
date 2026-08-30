USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     DATOS MINIMOS PARA QUE EL SISTEMA SE PUEDA USAR Y MOSTRAR.
-- =============================================
-- Va DESPUES de 36_SPRINT1_PERFILES_BASE.
--
-- POR QUE EXISTE ESTE BLOQUE
--   Casi todo lo que se construyo en el Sprint 1 se filtra por el CLIENTE
--   EN SESION: plantas, areas, centros de costo, grupos, especialidades,
--   catalogos propios y permisos puntuales. Y el cliente en sesion sale de
--   Cliente_Usuario.
--
--   Si una persona no esta afiliada a ningun cliente, entra igual -es una
--   cuenta de plataforma- pero todas esas pantallas le dicen "Seleccione un
--   cliente" y no hay ninguno que seleccionar. El sistema parece roto
--   estando sano.
--
--   Las tareas T-1007, T-1021, T-1035, T-1042 y T-1048 del Sprint Backlog
--   piden justamente esto: "Datos de demostracion y documentacion de la
--   funcionalidad".
--
-- QUE HACE
--   1. Completa la ficha de Hamburgo SA con lo que agrego HU-010.
--   2. Le pone nombre real a la planta que quedo de las pruebas.
--   3. Afilia al equipo al cliente, con perfil y planta.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA FICHA DEL CLIENTE

      cli_zona_horaria, cli_idioma y cli_moneda existen desde el bloque 25
      pero nadie los habia llenado. La zona horaria del cliente no es
      decorativa: es la que hereda una planta que no declara la suya, y con
      ella se calculan sus programaciones.
   ======================================================================== */

UPDATE  c
   SET  c.cli_nombre_fantasia = ISNULL(c.cli_nombre_fantasia, N'Hamburgo'),
        c.cli_zona_horaria    = ISNULL(c.cli_zona_horaria,
                                       (SELECT zho_id FROM [dbo].[Zona_Horaria]
                                         WHERE zho_codigo = N'AMERICA_SANTIAGO')),
        c.cli_idioma          = ISNULL(c.cli_idioma,
                                       (SELECT idi_id FROM [dbo].[Idioma] WHERE idi_codigo = N'es-CL')),
        c.cli_moneda          = ISNULL(c.cli_moneda,
                                       (SELECT mon_id FROM [dbo].[Moneda] WHERE mon_codigo = N'CLP'))
FROM    [dbo].[Cliente] c
WHERE   c.cli_id = 1
GO


/* ========================================================================
   2. LA PLANTA

      Quedo como 'PLANTA PRUEBA SIGMA' / 'PP-TEST' de las pruebas de los
      SP de areas. Se le pone el nombre que corresponde en vez de dejar
      texto de prueba a la vista en una demo.
   ======================================================================== */

UPDATE [dbo].[Cliente_Instalacion]
   SET cin_codigo    = N'PLANTA1',
       cin_nombre    = N'Planta Santiago',
       cin_direccion = ISNULL(cin_direccion, N'Camino a Melipilla 12.000, Maipú'),
       cin_zona_horaria = ISNULL(cin_zona_horaria,
                                 (SELECT zho_id FROM [dbo].[Zona_Horaria]
                                   WHERE zho_codigo = N'AMERICA_SANTIAGO')),
       cin_habilitado = 1,
       cin_usuario_actualizacion = 1,
       cin_fecha_actualizacion   = GETDATE()
 WHERE cin_id = 1
   AND cin_nombre = 'PLANTA PRUEBA SIGMA'
GO


/* ========================================================================
   3. EL EQUIPO, AFILIADO AL CLIENTE

      Sin esto no hay cliente en sesion y las pantallas del sprint quedan
      todas en "Seleccione un cliente".
   ======================================================================== */

/* Se empareja por usu_id y NO por login.

   El login de estas tres cuentas ya cambio una vez -pasaron de 'Root',
   'emilio' y 'cata' a sus correos corporativos- y un script de datos que
   depende del login deja de funcionar en silencio: no falla, simplemente
   no afilia a nadie y las pantallas siguen sin cliente. El id no cambia. */
DECLARE @A TABLE (usuario INT, perfil NVARCHAR(200))

INSERT INTO @A VALUES
 (1, N'Administrador del Cliente'),
 (2, N'Planificador de Mantenimiento'),
 (3, N'Jefe de Mantenimiento')

-- 3.1 Afiliacion al cliente
INSERT INTO [dbo].[Cliente_Usuario]
    (ucl_id_usuario, ucl_id_cliente, ucl_habilitado,
     ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
SELECT  u.usu_id, 1, 1, 1, GETDATE(), 1, GETDATE()
FROM    @A a
INNER JOIN [dbo].[Usuario] u ON u.usu_id = a.usuario
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = u.usu_id AND ucl_id_cliente = 1)

-- 3.2 Perfil dentro de ese cliente
INSERT INTO [dbo].[Cliente_Usuario_Perfil]
    (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
SELECT  cu.ucl_id, p.per_id, 1, GETDATE()
FROM    @A a
INNER JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = a.usuario AND cu.ucl_id_cliente = 1
INNER JOIN [dbo].[Perfiles] p ON p.per_nombre COLLATE DATABASE_DEFAULT = a.perfil COLLATE DATABASE_DEFAULT
                             AND p.per_cliente IS NULL
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario_Perfil]
                    WHERE cup_id_cliente_usuario = cu.ucl_id)

-- 3.3 Autorizacion en la planta
INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
    (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
     ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin)
SELECT  ci.cin_id, a.usuario, 1, GETDATE(), 1, CAST(GETDATE() AS DATE), NULL
FROM    @A a
CROSS JOIN [dbo].[Cliente_Instalacion] ci
WHERE   ci.cin_cliente = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                    WHERE ciu_id_usuario = a.usuario AND ciu_id_instalacion = ci.cin_id)
GO

PRINT 'Equipo afiliado al cliente 1.'
GO


/* ========================================================================
   COMPROBACION

      "personas con cliente" debe ser 3: si alguna queda en 0, esa persona
      entra al sistema pero no puede trabajar con ningun cliente.
   ======================================================================== */

SELECT  u.usu_id,
        u.usu_login,
        u.usu_correo,
        ISNULL(c.cli_nombre, '(sin cliente)')          AS cliente,
        ISNULL(p.per_nombre, '(sin perfil)')           AS perfil,
        (SELECT COUNT(*) FROM [dbo].[Cliente_Instalacion_Usuario]
          WHERE ciu_id_usuario = u.usu_id AND ciu_habilitado = 1) AS plantas
FROM    [dbo].[Usuario] u
LEFT JOIN [dbo].[Cliente_Usuario] cu        ON cu.ucl_id_usuario = u.usu_id
LEFT JOIN [dbo].[Cliente] c                 ON c.cli_id = cu.ucl_id_cliente
LEFT JOIN [dbo].[Cliente_Usuario_Perfil] cp ON cp.cup_id_cliente_usuario = cu.ucl_id
LEFT JOIN [dbo].[Perfiles] p                ON p.per_id = cp.cup_id_perfil
ORDER BY u.usu_id
GO

SELECT 'personas con cliente' AS control, COUNT(DISTINCT ucl_id_usuario) AS valor, 3 AS esperado
FROM   [dbo].[Cliente_Usuario] WHERE ucl_habilitado = 1
UNION ALL
SELECT 'personas con perfil', COUNT(*), 3
FROM   [dbo].[Cliente_Usuario_Perfil]
UNION ALL
SELECT 'personas con planta', COUNT(DISTINCT ciu_id_usuario), 3
FROM   [dbo].[Cliente_Instalacion_Usuario] WHERE ciu_habilitado = 1
UNION ALL
SELECT 'cliente con ficha completa', COUNT(*), 1
FROM   [dbo].[Cliente]
WHERE  cli_id = 1 AND cli_zona_horaria IS NOT NULL
   AND cli_idioma IS NOT NULL AND cli_moneda IS NOT NULL
GO
