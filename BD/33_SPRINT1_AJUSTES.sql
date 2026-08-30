USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     AJUSTES A SPs EXISTENTES QUE PIDIO EL ARMADO DE LA WEB.
-- =============================================
-- Va DESPUES de 32_SPRINT1_MENUS_PERMISOS.
--
-- QUE ES ESTE BLOQUE
--   Cambios chicos sobre SPs que ya existian y que aparecieron al conectar
--   las pantallas. Van aparte para que el historial muestre por que se
--   tocaron, en vez de mezclarse con los bloques de sus modulos.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_PERMISO                                                   HU-007

      La pantalla de permisos por usuario necesita ofrecer SOLO los permisos
      que pueden concederse a una persona. Hay permisos que solo tienen
      sentido por perfil -entrar a una pantalla, por ejemplo- y ofrecerlos
      en ese combo llevaria a crear excepciones que INS_CLIENTE_USUARIO_PERMISO
      va a rechazar por su validacion 2.

      Se agregan los dos filtros que faltaban. Los dos son opcionales, asi
      que los llamadores actuales siguen funcionando igual.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PERMISO]
    @ID                 INT = NULL,
    @MODULO             NVARCHAR(100) = NULL,
    @ASIGNABLE_USUARIO  BIT = NULL,
    @HABILITADO         BIT = NULL
AS
SET NOCOUNT ON

    SELECT prm_id, prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
           prm_descripcion, prm_habilitado, prm_asignable_usuario
    FROM   [dbo].[Permiso]
    WHERE  (@ID                IS NULL OR prm_id                = @ID)
      AND  (@MODULO            IS NULL OR prm_modulo            = @MODULO)
      AND  (@ASIGNABLE_USUARIO IS NULL OR prm_asignable_usuario = @ASIGNABLE_USUARIO)
      AND  (@HABILITADO        IS NULL OR prm_habilitado        = @HABILITADO)
    ORDER BY prm_modulo, prm_codigo
GO


/* ========================================================================
   2. SEL_CLIENTE_USUARIO_ELEGIBLE                                  HU-002

      Los clientes a los que pertenece una persona, para el selector.

      Devuelve solo afiliaciones VIGENTES a clientes HABILITADOS: si el
      administrador deshabilita un cliente, deja de aparecer en el selector
      de todos, que es la otra mitad de HU-010 escenario 2.

      Se necesita un SP propio y no SEL_CLIENTE con @USUARIO porque ese
      exige @TIPO_PERFIL y arrastra JOINs de instalaciones que aqui sobran.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_ELEGIBLE]
@USUARIO INT
AS
SET NOCOUNT ON

    SELECT  c.cli_id                              AS CLI_ID,
            c.cli_nombre                          AS CLI_NOMBRE,
            c.cli_razon_social                    AS CLI_RAZON_SOCIAL,
            c.cli_identificador                   AS CLI_IDENTIFICADOR,
            ISNULL(c.cli_nombre_fantasia, c.cli_nombre) AS CLI_ETIQUETA
    FROM    [dbo].[Cliente_Usuario] cu
    INNER JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
    WHERE   cu.ucl_id_usuario = @USUARIO
      AND   ISNULL(cu.ucl_habilitado, 0) = 1
      AND   ISNULL(c.cli_habilitado, 0)  = 1
    ORDER BY c.cli_nombre
GO


/* ========================================================================
   3. SEL_CLIENTE_USUARIO_ID                                        HU-007

      Traduce (usuario, cliente) al id de la fila de Cliente_Usuario.

      La pantalla de permisos puntuales conoce a la PERSONA y al CLIENTE,
      pero Cliente_Usuario_Permiso apunta a la AFILIACION. Sin esta
      traduccion, el formulario tendria que ir a buscarla con SQL suelto,
      que es justo lo que las convenciones prohiben.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_ID]
@USUARIO INT,
@CLIENTE INT
AS
SET NOCOUNT ON

    SELECT  cu.ucl_id            AS UCL_ID,
            cu.ucl_id_usuario    AS USU_ID,
            cu.ucl_id_cliente    AS CLI_ID,
            u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE,
            u.usu_correo         AS USU_CORREO
    FROM    [dbo].[Cliente_Usuario] cu
    INNER JOIN [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
    WHERE   cu.ucl_id_usuario = @USUARIO
      AND   cu.ucl_id_cliente = @CLIENTE
GO


/* ========================================================================
   4. SEL_USUARIO_CLIENTE_LISTA                                     HU-007

      Las personas afiliadas y vigentes en un cliente, para los combos de
      usuario de las pantallas del cliente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_CLIENTE_LISTA]
@CLIENTE INT,
@FILTRO  VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  u.usu_id                                          AS USU_ID,
            u.usu_nombre + SPACE(1) + u.usu_apellido_paterno  AS USU_NOMBRE,
            u.usu_correo                                      AS USU_CORREO,
            u.usu_identificador                               AS USU_IDENTIFICADOR,
            cu.ucl_id                                         AS UCL_ID
    FROM    [dbo].[Cliente_Usuario] cu
    INNER JOIN [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
    WHERE   cu.ucl_id_cliente = @CLIENTE
      AND   ISNULL(cu.ucl_habilitado, 0) = 1
      AND   u.usu_habilitado = 1
      AND   (@FILTRO IS NULL
             OR u.usu_nombre LIKE '%' + @FILTRO + '%'
             OR u.usu_apellido_paterno LIKE '%' + @FILTRO + '%'
             OR u.usu_correo LIKE '%' + @FILTRO + '%')
    ORDER BY u.usu_apellido_paterno, u.usu_nombre
GO


/* ========================================================================
   5. Zona_Horaria entra al registro de catalogos                  HU-011

      La ficha de planta necesita un combo de zonas horarias. Todos los
      demas combos de catalogo del sitio se llenan con
      CatalogoController.GetValoresPorCodigo(), que exige que la tabla tenga
      <pfx>_codigo. Zona_Horaria era la unica que no lo tenia, asi que
      quedaba fuera del registro y habria obligado a escribir un Model y un
      Controller propios para dos columnas.

      Se le agrega el codigo, tomado del identificador IANA -que ya es un
      codigo estable y reconocible: America/Santiago- y con eso entra al
      mismo mecanismo que las otras 80.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Zona_Horaria]') AND name = 'zho_codigo')
BEGIN
    ALTER TABLE [dbo].[Zona_Horaria] ADD [zho_codigo] NVARCHAR(100) NULL
    PRINT 'Columna zho_codigo agregada a Zona_Horaria.'
END
ELSE PRINT 'Columna zho_codigo ya existe en Zona_Horaria.'
GO

UPDATE [dbo].[Zona_Horaria]
   SET zho_codigo = UPPER(REPLACE(zho_identificador_iana, '/', '_'))
 WHERE zho_codigo IS NULL
   AND zho_identificador_iana IS NOT NULL
GO

/* Las zonas horarias no tienen columna de orden, asi que no entran por el
   criterio general del bloque 25: se registran a mano. No son ampliables,
   una zona horaria no la inventa un cliente. */
INSERT INTO [dbo].[Catalogo]
    (ctl_codigo, ctl_nombre, ctl_descripcion, ctl_tabla, ctl_prefijo, ctl_modulo, ctl_ampliable, ctl_orden)
SELECT N'ZONA_HORARIA', N'Zona Horaria',
       N'Zonas horarias disponibles para clientes y plantas.',
       N'Zona_Horaria', N'zho', N'Sistema', 0, 0
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Catalogo] WHERE ctl_tabla = N'Zona_Horaria')
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs de apoyo' AS control, COUNT(*) AS valor, 4 AS esperado
FROM   sys.procedures
WHERE  name IN ('SEL_PERMISO','SEL_CLIENTE_USUARIO_ELEGIBLE',
                'SEL_CLIENTE_USUARIO_ID','SEL_USUARIO_CLIENTE_LISTA')
UNION ALL
SELECT 'zonas horarias con codigo', COUNT(*), 2
FROM   [dbo].[Zona_Horaria] WHERE zho_codigo IS NOT NULL
UNION ALL
SELECT 'Zona_Horaria en el registro', COUNT(*), 1
FROM   [dbo].[Catalogo] WHERE ctl_tabla = N'Zona_Horaria'
GO

-- El combo de la ficha de planta tiene que devolver las dos zonas.
EXEC [dbo].[SEL_CATALOGO_VALOR] @CODIGO = N'ZONA_HORARIA'
GO
