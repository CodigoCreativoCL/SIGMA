USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-02. GRUPOS DE TRABAJO Y ESPECIALIDADES DE LOS USUARIOS.
-- =============================================
-- Va DESPUES de 27_SPRINT1_ORGANIZACION.
--
-- QUE CUBRE
--   HU-016  Grupos de trabajo (cuadrillas y turnos) y sus integrantes.
--   HU-017  Especialidades y certificaciones de un usuario.
--
-- DOS DECISIONES QUE VIENEN DE LAS HISTORIAS
--
--   1. UN SOLO LIDER VIGENTE POR GRUPO (HU-016 escenario 2). "Vigente" es
--      la palabra que importa: puede haber varios lideres en el historial,
--      pero no dos a la vez. Por eso la validacion compara ventanas de
--      fechas y no cuenta filas.
--
--   2. LA CERTIFICACION VENCIDA NO BLOQUEA (HU-017 escenario 2). El texto
--      es explicito: "la asignacion se permite y la advertencia queda
--      registrada". Bloquear detendria el trabajo cuando una certificacion
--      caduca fuera de horario administrativo. Por eso SEL_USUARIO_ESPECIALIDAD
--      devuelve el ESTADO de la certificacion y los dias que faltan, pero
--      ningun SP impide asignar.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ########################################################################
   HU-017 - ESPECIALIDAD (catalogo ampliable del cliente)
   ######################################################################## */

/* ========================================================================
   INS_ESPECIALIDAD

   esp_cliente NULL = especialidad del sistema, visible para todos.
   esp_cliente informado = especialidad propia de ese cliente.
   Es el mismo mecanismo de HU-021 para los catalogos ampliables.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_ESPECIALIDAD]
@ID       INT = NULL OUTPUT,
@CLIENTE  INT = NULL,
@CODIGO   NVARCHAR(100),
@NOMBRE   NVARCHAR(200),
@ORDEN    INT = NULL,
@USUARIO  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    /* Unico por cliente. El indice UX_ESP_CLIENTE_CODIGO ya lo garantiza,
       pero se comprueba aqui para devolver un mensaje legible en vez del
       error 2601 de SQL Server. */
    IF EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                WHERE esp_codigo = @CODIGO
                  AND ISNULL(esp_cliente, 0) = ISNULL(@CLIENTE, 0))
    BEGIN
        RAISERROR('1.- YA EXISTE UNA ESPECIALIDAD CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* Tampoco puede chocar con una del sistema: el usuario final las ve
       juntas en la misma lista y dos "MEC" serian indistinguibles. */
    IF @CLIENTE IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                    WHERE esp_codigo = @CODIGO AND esp_cliente IS NULL)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA ESPECIALIDAD DEL SISTEMA CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Especialidad]
        (
            esp_cliente,
            esp_codigo,
            esp_nombre,
            esp_orden,
            esp_usuario_creacion,
            esp_fecha_creacion,
            esp_usuario_actualizacion,
            esp_fecha_actualizacion,
            esp_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CODIGO,
            @NOMBRE,
            @ORDEN,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ESPECIALIDAD @CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR LA ESPECIALIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   SEL_ESPECIALIDAD

   @CLIENTE trae las del sistema MAS las propias de ese cliente, que es lo
   que espera ver el usuario en un combo. Para mantener solo las propias se
   usa @SOLO_CLIENTE = 1.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ESPECIALIDAD]
@ID            INT = NULL,
@CLIENTE       INT = NULL,
@SOLO_CLIENTE  BIT = NULL,
@SOLO_SISTEMA  BIT = NULL,
@HABILITADO    BIT = NULL,
@FILTRO        VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT esp.esp_id           AS ESP_ID
                                 ,esp.esp_cliente       AS ESP_CLIENTE
                                 ,esp.esp_codigo        AS ESP_CODIGO
                                 ,esp.esp_nombre        AS ESP_NOMBRE
                                 ,esp.esp_orden         AS ESP_ORDEN
                                 ,esp.esp_habilitado    AS ESP_HABILITADO
                                 ,esp.esp_usuario_creacion      AS ESP_USUARIO_CREACION
                                 ,esp.esp_fecha_creacion        AS ESP_FECHA_CREACION
                                 ,esp.esp_usuario_actualizacion AS ESP_USUARIO_ACTUALIZACION
                                 ,esp.esp_fecha_actualizacion   AS ESP_FECHA_ACTUALIZACION
                                 ,CASE WHEN esp.esp_cliente IS NULL THEN ''Sistema''
                                       ELSE ''Propia'' END      AS ORIGEN
                                 /* Con SELECT DISTINCT, el ORDER BY solo
                                    admite columnas de la lista: por eso el
                                    ISNULL viaja como columna y no en el
                                    ORDER BY. Las especialidades sin orden
                                    van al final y no al principio. */
                                 ,ISNULL(esp.esp_orden, 9999)   AS ORDEN_VISUAL
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Especialidad esp '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND esp.esp_id = ' + LTRIM(@ID)
    END

    IF (@SOLO_SISTEMA = 1) BEGIN
        SET @WHERE = @WHERE + ' AND esp.esp_cliente IS NULL '
    END
    ELSE IF (@CLIENTE IS NOT NULL) BEGIN
        IF (@SOLO_CLIENTE = 1)
            SET @WHERE = @WHERE + ' AND esp.esp_cliente = ' + LTRIM(@CLIENTE)
        ELSE
            SET @WHERE = @WHERE + ' AND (esp.esp_cliente IS NULL OR esp.esp_cliente = ' + LTRIM(@CLIENTE) + ') '
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND esp.esp_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (esp.esp_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR esp.esp_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY ORDEN_VISUAL, esp.esp_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


CREATE OR ALTER PROCEDURE [dbo].[UPD_ESPECIALIDAD]
@ID          INT,
@CODIGO      NVARCHAR(100) = NULL,
@NOMBRE      NVARCHAR(200) = NULL,
@ORDEN       INT = NULL,
@HABILITADO  BIT = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @EXISTE BIT = 0

SELECT @CLIENTE = esp_cliente, @EXISTE = 1 FROM [dbo].[Especialidad] WHERE esp_id = @ID

IF @EXISTE = 0
BEGIN
    RAISERROR('1.- LA ESPECIALIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
BEGIN
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

    IF EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                WHERE esp_codigo = @CODIGO
                  AND ISNULL(esp_cliente, 0) = ISNULL(@CLIENTE, 0)
                  AND esp_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA ESPECIALIDAD CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Especialidad]
    SET     esp_codigo                = ISNULL(@CODIGO, esp_codigo)
           ,esp_nombre                = ISNULL(@NOMBRE, esp_nombre)
           /* ISNULL y no asignacion directa: todos los parametros son
              opcionales y una llamada que solo cambie el nombre dejaria la
              especialidad sin orden, al principio de todos los combos. */
           ,esp_orden                 = ISNULL(@ORDEN, esp_orden)
           ,esp_habilitado            = ISNULL(@HABILITADO, esp_habilitado)
           ,esp_usuario_actualizacion = @USUARIO
           ,esp_fecha_actualizacion   = @DATE_NOW
    WHERE   esp_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ESPECIALIDAD @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR LA ESPECIALIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ########################################################################
   HU-017 - USUARIO_ESPECIALIDAD
   ######################################################################## */

CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO_ESPECIALIDAD]
@ID                  INT = NULL OUTPUT,
@USUARIO_DESTINO     INT,
@CLIENTE             INT,
@ESPECIALIDAD        INT,
@ESPECIALIDAD_NIVEL  INT = NULL,
@CERTIFICACION       NVARCHAR(400) = NULL,
@FECHA_VENCIMIENTO   DATE = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    -- 1. El usuario debe estar afiliado al cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_DESTINO
                      AND ucl_id_cliente = @CLIENTE
                      AND ISNULL(ucl_habilitado, 0) = 1)
    BEGIN
        RAISERROR('1.- EL USUARIO NO ESTÁ AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 2. La especialidad debe ser del sistema o de este cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                    WHERE esp_id = @ESPECIALIDAD
                      AND esp_habilitado = 1
                      AND (esp_cliente IS NULL OR esp_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- LA ESPECIALIDAD NO ESTÁ DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 3. No repetir la misma especialidad para la misma persona
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Especialidad]
                WHERE ues_usuario = @USUARIO_DESTINO
                  AND ues_cliente = @CLIENTE
                  AND ues_especialidad = @ESPECIALIDAD
                  AND ues_habilitado = 1)
    BEGIN
        RAISERROR('3.- EL USUARIO YA TIENE ESA ESPECIALIDAD REGISTRADA.', 16, 1)
        RETURN -1
    END

    /* Deliberadamente NO se valida que la fecha de vencimiento sea futura.
       Registrar una certificacion ya vencida es un caso real: se carga el
       historico de una persona que hay que recertificar. */
END

BEGIN TRANSACTION

    INSERT [dbo].[Usuario_Especialidad]
        (
            ues_usuario,
            ues_cliente,
            ues_especialidad,
            ues_especialidad_nivel,
            ues_certificacion,
            ues_fecha_vencimiento,
            ues_usuario_creacion,
            ues_fecha_creacion,
            ues_usuario_actualizacion,
            ues_fecha_actualizacion,
            ues_habilitado
        )
    VALUES
        (
            @USUARIO_DESTINO,
            @CLIENTE,
            @ESPECIALIDAD,
            @ESPECIALIDAD_NIVEL,
            @CERTIFICACION,
            @FECHA_VENCIMIENTO,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_USUARIO_ESPECIALIDAD @USUARIO_DESTINO = ' +
                                          LTRIM(STR(@USUARIO_DESTINO)) + ',@ESPECIALIDAD = ' + LTRIM(STR(@ESPECIALIDAD))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE REGISTRAR LA ESPECIALIDAD DEL USUARIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   SEL_USUARIO_ESPECIALIDAD

   Devuelve ESTADO y DIAS_PARA_VENCER porque de ahi salen los tres
   escenarios de HU-017 sin que la pantalla tenga que calcular fechas:

     VIGENTE      certificacion al dia, o sin vencimiento
     POR_VENCER   vence en menos de 30 dias  -> panel de alertas (escenario 3)
     VENCIDA      ya vencio                  -> advertencia (escenario 2)
     SIN_CERTIFICACION  la especialidad no exige certificado

   @SOLO_VENCIDAS y @SOLO_POR_VENCER alimentan directamente ese panel.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_ESPECIALIDAD]
@ID                INT = NULL,
@USUARIO_DESTINO   INT = NULL,
@CLIENTE           INT = NULL,
@ESPECIALIDAD      INT = NULL,
@SOLO_VENCIDAS     BIT = NULL,
@SOLO_POR_VENCER   BIT = NULL,
@HABILITADO        BIT = NULL,
@FILTRO            VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

DECLARE @DIAS_AVISO INT = 30

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ues.ues_id                AS UES_ID
                                 ,ues.ues_usuario            AS UES_USUARIO
                                 ,ues.ues_cliente            AS UES_CLIENTE
                                 ,ues.ues_especialidad       AS UES_ESPECIALIDAD
                                 ,ues.ues_especialidad_nivel AS UES_ESPECIALIDAD_NIVEL
                                 ,ues.ues_certificacion      AS UES_CERTIFICACION
                                 ,ues.ues_fecha_vencimiento  AS UES_FECHA_VENCIMIENTO
                                 ,ues.ues_habilitado         AS UES_HABILITADO
                                 ,ues.ues_usuario_creacion   AS UES_USUARIO_CREACION
                                 ,ues.ues_fecha_creacion     AS UES_FECHA_CREACION
                                 ,esp.esp_codigo             AS ESP_CODIGO
                                 ,esp.esp_nombre             AS ESP_NOMBRE
                                 ,enl.enl_nombre             AS ENL_NOMBRE
                                 ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE
                                 ,u.usu_correo               AS USU_CORREO
                                 ,CASE WHEN ues.ues_fecha_vencimiento IS NULL THEN NULL
                                       ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), ues.ues_fecha_vencimiento)
                                  END                        AS DIAS_PARA_VENCER
                                 ,CASE WHEN ues.ues_certificacion IS NULL
                                        AND ues.ues_fecha_vencimiento IS NULL THEN ''SIN_CERTIFICACION''
                                       WHEN ues.ues_fecha_vencimiento IS NULL THEN ''VIGENTE''
                                       WHEN ues.ues_fecha_vencimiento < CAST(GETDATE() AS DATE) THEN ''VENCIDA''
                                       WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), ues.ues_fecha_vencimiento) <= '
                                       + LTRIM(STR(@DIAS_AVISO)) + ' THEN ''POR_VENCER''
                                       ELSE ''VIGENTE'' END  AS ESTADO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Usuario_Especialidad ues
                       INNER JOIN Especialidad esp      ON esp.esp_id = ues.ues_especialidad
                       INNER JOIN Usuario u             ON u.usu_id = ues.ues_usuario
                       LEFT  JOIN Especialidad_Nivel enl ON enl.enl_id = ues.ues_especialidad_nivel
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_id = ' + LTRIM(@ID)
    END

    IF (@USUARIO_DESTINO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_usuario = ' + LTRIM(@USUARIO_DESTINO)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@ESPECIALIDAD IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_especialidad = ' + LTRIM(@ESPECIALIDAD)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@SOLO_VENCIDAS = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_fecha_vencimiento IS NOT NULL
                                AND ues.ues_fecha_vencimiento < CAST(GETDATE() AS DATE) '
    END

    IF (@SOLO_POR_VENCER = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_fecha_vencimiento IS NOT NULL
                                AND ues.ues_fecha_vencimiento >= CAST(GETDATE() AS DATE)
                                AND DATEDIFF(DAY, CAST(GETDATE() AS DATE), ues.ues_fecha_vencimiento) <= '
                                + LTRIM(STR(@DIAS_AVISO)) + ' '
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (esp.esp_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ues.ues_certificacion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_apellido_paterno LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY esp.esp_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_ESPECIALIDAD]
@ID                  INT,
@ESPECIALIDAD_NIVEL  INT = NULL,
@CERTIFICACION       NVARCHAR(400) = NULL,
@FECHA_VENCIMIENTO   DATE = NULL,
@HABILITADO          BIT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = ues_cliente FROM [dbo].[Usuario_Especialidad] WHERE ues_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL REGISTRO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario_Especialidad]
    SET     ues_especialidad_nivel    = @ESPECIALIDAD_NIVEL
           ,ues_certificacion         = @CERTIFICACION
           ,ues_fecha_vencimiento     = @FECHA_VENCIMIENTO
           ,ues_habilitado            = ISNULL(@HABILITADO, ues_habilitado)
           ,ues_usuario_actualizacion = @USUARIO
           ,ues_fecha_actualizacion   = @DATE_NOW
    WHERE   ues_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_ESPECIALIDAD @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '2.- NO FUE POSIBLE ACTUALIZAR LA ESPECIALIDAD DEL USUARIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO_ESPECIALIDAD]
@ID INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

    DELETE  [dbo].[Usuario_Especialidad]
    WHERE   ues_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_USUARIO_ESPECIALIDAD ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ELIMINAR LA ESPECIALIDAD DEL USUARIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ########################################################################
   HU-016 - GRUPO_TRABAJO
   ######################################################################## */

CREATE OR ALTER PROCEDURE [dbo].[INS_GRUPO_TRABAJO]
@ID                   INT = NULL OUTPUT,
@CLIENTE              INT,
@CLIENTE_INSTALACION  INT = NULL,
@CODIGO               NVARCHAR(100),
@NOMBRE               NVARCHAR(400),
@ESPECIALIDAD         INT = NULL,
@DESCRIPCION          NVARCHAR(1000) = NULL,
@USUARIO              INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo]
                WHERE gtr_cliente = @CLIENTE AND gtr_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN GRUPO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* La planta es opcional: vacia significa grupo transversal al cliente.
       Pero si viene, tiene que ser del cliente. */
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @ESPECIALIDAD IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                        WHERE esp_id = @ESPECIALIDAD
                          AND (esp_cliente IS NULL OR esp_cliente = @CLIENTE))
    BEGIN
        RAISERROR('3.- LA ESPECIALIDAD NO ESTÁ DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Grupo_Trabajo]
        (
            gtr_cliente,
            gtr_cliente_instalacion,
            gtr_codigo,
            gtr_nombre,
            gtr_especialidad,
            gtr_descripcion,
            gtr_usuario_creacion,
            gtr_fecha_creacion,
            gtr_usuario_actualizacion,
            gtr_fecha_actualizacion,
            gtr_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @CODIGO,
            @NOMBRE,
            @ESPECIALIDAD,
            @DESCRIPCION,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_GRUPO_TRABAJO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL GRUPO DE TRABAJO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   SEL_GRUPO_TRABAJO

   Trae el lider vigente y cuantos integrantes vigentes tiene el grupo: son
   las dos columnas que la grilla necesita y evitan una consulta por fila.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO]
@ID                   INT = NULL,
@CLIENTE              INT = NULL,
@CLIENTE_INSTALACION  INT = NULL,
@ESPECIALIDAD         INT = NULL,
@HABILITADO           BIT = NULL,
@FILTRO               VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT gtr.gtr_id                  AS GTR_ID
                                 ,gtr.gtr_cliente              AS GTR_CLIENTE
                                 ,gtr.gtr_cliente_instalacion  AS GTR_CLIENTE_INSTALACION
                                 ,gtr.gtr_codigo               AS GTR_CODIGO
                                 ,gtr.gtr_nombre               AS GTR_NOMBRE
                                 ,gtr.gtr_especialidad         AS GTR_ESPECIALIDAD
                                 ,gtr.gtr_descripcion          AS GTR_DESCRIPCION
                                 ,gtr.gtr_habilitado           AS GTR_HABILITADO
                                 ,gtr.gtr_usuario_creacion     AS GTR_USUARIO_CREACION
                                 ,gtr.gtr_fecha_creacion       AS GTR_FECHA_CREACION
                                 ,gtr.gtr_usuario_actualizacion AS GTR_USUARIO_ACTUALIZACION
                                 ,gtr.gtr_fecha_actualizacion  AS GTR_FECHA_ACTUALIZACION
                                 ,ISNULL(cin.cin_nombre, ''Todas las plantas'') AS CIN_NOMBRE
                                 ,esp.esp_nombre               AS ESP_NOMBRE
                                 ,(SELECT COUNT(*) FROM Grupo_Trabajo_Usuario gtu
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_fecha_inicio <= CAST(GETDATE() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST(GETDATE() AS DATE))
                                  )                            AS INTEGRANTES
                                 ,(SELECT TOP 1 ul.usu_nombre + SPACE(1) + ul.usu_apellido_paterno
                                     FROM Grupo_Trabajo_Usuario gtu
                                     INNER JOIN Usuario ul ON ul.usu_id = gtu.gtu_usuario
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_es_lider = 1
                                      AND gtu.gtu_fecha_inicio <= CAST(GETDATE() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST(GETDATE() AS DATE))
                                  )                            AS LIDER
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Grupo_Trabajo gtr
                       LEFT JOIN Cliente_Instalacion cin ON cin.cin_id = gtr.gtr_cliente_instalacion
                       LEFT JOIN Especialidad esp        ON esp.esp_id = gtr.gtr_especialidad
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_cliente = ' + LTRIM(@CLIENTE)
    END

    /* Un grupo transversal (sin planta) aparece tambien cuando se filtra
       por una planta: es asignable en todas. */
    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (gtr.gtr_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION) +
                                  ' OR gtr.gtr_cliente_instalacion IS NULL) '
    END

    IF (@ESPECIALIDAD IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_especialidad = ' + LTRIM(@ESPECIALIDAD)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (gtr.gtr_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_descripcion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY gtr.gtr_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


CREATE OR ALTER PROCEDURE [dbo].[UPD_GRUPO_TRABAJO]
@ID                   INT,
@CLIENTE_INSTALACION  INT = NULL,
@CODIGO               NVARCHAR(100) = NULL,
@NOMBRE               NVARCHAR(400) = NULL,
@ESPECIALIDAD         INT = NULL,
@DESCRIPCION          NVARCHAR(1000) = NULL,
@HABILITADO           BIT = NULL,
@QUITA_PLANTA         BIT = 0,
@USUARIO              INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = gtr_cliente FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL GRUPO DE TRABAJO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
BEGIN
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

    IF EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo]
                WHERE gtr_cliente = @CLIENTE AND gtr_codigo = @CODIGO AND gtr_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN GRUPO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Grupo_Trabajo]
    SET     gtr_cliente_instalacion   = CASE WHEN @QUITA_PLANTA = 1 THEN NULL
                                             ELSE ISNULL(@CLIENTE_INSTALACION, gtr_cliente_instalacion) END
           ,gtr_codigo                = ISNULL(@CODIGO, gtr_codigo)
           ,gtr_nombre                = ISNULL(@NOMBRE, gtr_nombre)
           ,gtr_especialidad          = @ESPECIALIDAD
           ,gtr_descripcion           = @DESCRIPCION
           ,gtr_habilitado            = ISNULL(@HABILITADO, gtr_habilitado)
           ,gtr_usuario_actualizacion = @USUARIO
           ,gtr_fecha_actualizacion   = @DATE_NOW
    WHERE   gtr_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_GRUPO_TRABAJO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL GRUPO DE TRABAJO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ########################################################################
   HU-016 - GRUPO_TRABAJO_USUARIO (integrantes)
   ######################################################################## */

/* ========================================================================
   INS_GRUPO_TRABAJO_USUARIO

   AQUI VIVE LA REGLA DEL LIDER UNICO.

   "Solo puede haber un lider vigente por grupo" es una condicion sobre
   VENTANAS DE TIEMPO, no sobre filas. Dos integrantes se solapan cuando
   cada uno empieza antes de que el otro termine; con fecha de fin vacia
   (sin vencimiento) el tramo se trata como abierto hasta el infinito.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_GRUPO_TRABAJO_USUARIO]
@ID              INT = NULL OUTPUT,
@GRUPO_TRABAJO   INT,
@USUARIO_DESTINO INT,
@ES_LIDER        BIT = 0,
@FECHA_INICIO    DATE = NULL,
@FECHA_FIN       DATE = NULL,
@USUARIO         INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @INSTALACION INT
DECLARE @FIN_INFINITO DATE = '9999-12-31'

SELECT  @CLIENTE = gtr_cliente, @INSTALACION = gtr_cliente_instalacion
FROM    [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL GRUPO DE TRABAJO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @FECHA_INICIO = ISNULL(@FECHA_INICIO, CAST(@DATE_NOW AS DATE))

BEGIN
    -- 2. El integrante debe pertenecer al cliente del grupo
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_DESTINO
                      AND ucl_id_cliente = @CLIENTE
                      AND ISNULL(ucl_habilitado, 0) = 1)
    BEGIN
        RAISERROR('2.- EL USUARIO NO ESTÁ AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* 3. Si el grupo es de una planta, el integrante tiene que estar
          autorizado en ella. Un grupo transversal no exige esto. */
    IF @INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE ciu_id_usuario = @USUARIO_DESTINO
                          AND ciu_id_instalacion = @INSTALACION
                          AND ciu_habilitado = 1)
    BEGIN
        RAISERROR('3.- EL USUARIO NO ESTÁ AUTORIZADO EN LA PLANTA DEL GRUPO.', 16, 1)
        RETURN -1
    END

    -- 4. Fechas coherentes
    IF @FECHA_FIN IS NOT NULL AND @FECHA_FIN < @FECHA_INICIO
    BEGIN
        RAISERROR('4.- LA FECHA DE TÉRMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
        RETURN -1
    END

    -- 5. La misma persona no puede tener dos tramos solapados en el grupo
    IF EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo_Usuario]
                WHERE gtu_grupo_trabajo = @GRUPO_TRABAJO
                  AND gtu_usuario       = @USUARIO_DESTINO
                  AND gtu_fecha_inicio               <= ISNULL(@FECHA_FIN, @FIN_INFINITO)
                  AND ISNULL(gtu_fecha_fin, @FIN_INFINITO) >= @FECHA_INICIO)
    BEGIN
        RAISERROR('5.- EL USUARIO YA PERTENECE AL GRUPO EN ESE PERÍODO.', 16, 1)
        RETURN -1
    END

    -- 6. Un solo lider vigente a la vez
    IF @ES_LIDER = 1
       AND EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo_Usuario]
                    WHERE gtu_grupo_trabajo = @GRUPO_TRABAJO
                      AND gtu_es_lider      = 1
                      AND gtu_fecha_inicio               <= ISNULL(@FECHA_FIN, @FIN_INFINITO)
                      AND ISNULL(gtu_fecha_fin, @FIN_INFINITO) >= @FECHA_INICIO)
    BEGIN
        RAISERROR('6.- EL GRUPO YA TIENE UN LÍDER VIGENTE EN ESE PERÍODO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Grupo_Trabajo_Usuario]
        (
            gtu_grupo_trabajo,
            gtu_usuario,
            gtu_es_lider,
            gtu_fecha_inicio,
            gtu_fecha_fin,
            gtu_usuario_creacion,
            gtu_fecha_creacion
        )
    VALUES
        (
            @GRUPO_TRABAJO,
            @USUARIO_DESTINO,
            @ES_LIDER,
            @FECHA_INICIO,
            @FECHA_FIN,
            @USUARIO,
            @DATE_NOW
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_GRUPO_TRABAJO_USUARIO @GRUPO_TRABAJO = ' +
              LTRIM(STR(@GRUPO_TRABAJO)) + ',@USUARIO_DESTINO = ' + LTRIM(STR(@USUARIO_DESTINO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '7.- NO FUE POSIBLE AGREGAR EL INTEGRANTE.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO_USUARIO]
@ID              INT = NULL,
@GRUPO_TRABAJO   INT = NULL,
@USUARIO_DESTINO INT = NULL,
@SOLO_VIGENTES   BIT = NULL,
@FILTRO          VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT gtu.gtu_id             AS GTU_ID
                                 ,gtu.gtu_grupo_trabajo   AS GTU_GRUPO_TRABAJO
                                 ,gtu.gtu_usuario         AS GTU_USUARIO
                                 ,gtu.gtu_es_lider        AS GTU_ES_LIDER
                                 ,gtu.gtu_fecha_inicio    AS GTU_FECHA_INICIO
                                 ,gtu.gtu_fecha_fin       AS GTU_FECHA_FIN
                                 ,gtu.gtu_usuario_creacion AS GTU_USUARIO_CREACION
                                 ,gtu.gtu_fecha_creacion  AS GTU_FECHA_CREACION
                                 ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE
                                 ,u.usu_apellido_paterno  AS USU_APELLIDO_PATERNO
                                 ,u.usu_correo            AS USU_CORREO
                                 ,u.usu_identificador     AS USU_IDENTIFICADOR
                                 ,gtr.gtr_nombre          AS GTR_NOMBRE
                                 ,CASE WHEN gtu.gtu_fecha_inicio > CAST(GETDATE() AS DATE) THEN ''PENDIENTE''
                                       WHEN gtu.gtu_fecha_fin IS NOT NULL
                                        AND gtu.gtu_fecha_fin < CAST(GETDATE() AS DATE) THEN ''TERMINADO''
                                       ELSE ''VIGENTE'' END AS ESTADO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Grupo_Trabajo_Usuario gtu
                       INNER JOIN Usuario u        ON u.usu_id = gtu.gtu_usuario
                       INNER JOIN Grupo_Trabajo gtr ON gtr.gtr_id = gtu.gtu_grupo_trabajo
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtu.gtu_id = ' + LTRIM(@ID)
    END

    IF (@GRUPO_TRABAJO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtu.gtu_grupo_trabajo = ' + LTRIM(@GRUPO_TRABAJO)
    END

    IF (@USUARIO_DESTINO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtu.gtu_usuario = ' + LTRIM(@USUARIO_DESTINO)
    END

    IF (@SOLO_VIGENTES = 1) BEGIN
        SET @WHERE = @WHERE + ' AND gtu.gtu_fecha_inicio <= CAST(GETDATE() AS DATE)
                                AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST(GETDATE() AS DATE)) '
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (u.usu_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_apellido_paterno LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_correo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY gtu.gtu_es_lider DESC, u.usu_apellido_paterno '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   UPD_GRUPO_TRABAJO_USUARIO

   Sirve para cerrar la vigencia de un integrante y para pasar el liderazgo.
   Repite la comprobacion de lider unico excluyendose a si mismo.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_GRUPO_TRABAJO_USUARIO]
@ID            INT,
@ES_LIDER      BIT = NULL,
@FECHA_INICIO  DATE = NULL,
@FECHA_FIN     DATE = NULL,
@QUITA_FIN     BIT = 0,
@USUARIO       INT

AS
SET NOCOUNT ON

DECLARE @GRUPO INT, @INICIO DATE, @FIN DATE, @LIDER BIT
DECLARE @FIN_INFINITO DATE = '9999-12-31'

SELECT  @GRUPO = gtu_grupo_trabajo, @INICIO = gtu_fecha_inicio,
        @FIN = gtu_fecha_fin, @LIDER = gtu_es_lider
FROM    [dbo].[Grupo_Trabajo_Usuario] WHERE gtu_id = @ID

IF @GRUPO IS NULL
BEGIN
    RAISERROR('1.- EL INTEGRANTE NO EXISTE EN EL GRUPO.', 16, 1)
    RETURN -1
END

-- Valores finales tras la actualizacion
SET @INICIO = ISNULL(@FECHA_INICIO, @INICIO)
SET @FIN    = CASE WHEN @QUITA_FIN = 1 THEN NULL ELSE ISNULL(@FECHA_FIN, @FIN) END
SET @LIDER  = ISNULL(@ES_LIDER, @LIDER)

BEGIN
    IF @FIN IS NOT NULL AND @FIN < @INICIO
    BEGIN
        RAISERROR('2.- LA FECHA DE TÉRMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
        RETURN -1
    END

    IF @LIDER = 1
       AND EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo_Usuario]
                    WHERE gtu_grupo_trabajo = @GRUPO
                      AND gtu_es_lider      = 1
                      AND gtu_id           <> @ID
                      AND gtu_fecha_inicio               <= ISNULL(@FIN, @FIN_INFINITO)
                      AND ISNULL(gtu_fecha_fin, @FIN_INFINITO) >= @INICIO)
    BEGIN
        RAISERROR('3.- EL GRUPO YA TIENE UN LÍDER VIGENTE EN ESE PERÍODO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Grupo_Trabajo_Usuario]
    SET     gtu_es_lider      = @LIDER
           ,gtu_fecha_inicio  = @INICIO
           ,gtu_fecha_fin     = @FIN
    WHERE   gtu_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_GRUPO_TRABAJO_USUARIO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE ACTUALIZAR EL INTEGRANTE.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   DEL_GRUPO_TRABAJO_USUARIO
   Tabla de relacion: la baja es fisica (PATRON_TABLAS §4).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[DEL_GRUPO_TRABAJO_USUARIO]
@ID INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

    DELETE  [dbo].[Grupo_Trabajo_Usuario]
    WHERE   gtu_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_GRUPO_TRABAJO_USUARIO ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE QUITAR EL INTEGRANTE.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs EP-02 equipos' AS control, COUNT(*) AS valor, 13 AS esperado
FROM   sys.procedures
WHERE  name IN ('INS_ESPECIALIDAD','SEL_ESPECIALIDAD','UPD_ESPECIALIDAD',
                'INS_USUARIO_ESPECIALIDAD','SEL_USUARIO_ESPECIALIDAD',
                'UPD_USUARIO_ESPECIALIDAD','DEL_USUARIO_ESPECIALIDAD',
                'INS_GRUPO_TRABAJO','SEL_GRUPO_TRABAJO','UPD_GRUPO_TRABAJO',
                'INS_GRUPO_TRABAJO_USUARIO','SEL_GRUPO_TRABAJO_USUARIO',
                'UPD_GRUPO_TRABAJO_USUARIO')
UNION ALL
SELECT 'DEL_GRUPO_TRABAJO_USUARIO', COUNT(*), 1
FROM   sys.procedures WHERE name = 'DEL_GRUPO_TRABAJO_USUARIO'
GO
