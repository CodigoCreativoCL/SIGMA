USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     SPRINT 2 - HU-042 CONFIGURAR EL MEDIDOR DE UN ACTIVO. SEL/INS/UPD/DEL_ACTIVO_MEDIDOR.
-- =============================================
-- Va DESPUES de 76_SPRINT2_ACTIVO_MENUS.
--
-- QUE CUBRE ESTE BLOQUE (tareas del Sprint 2)
--   T-2018  Revision del modelo Activo_Medidor: columnas, FK e indices.
--   T-2019  SEL_ACTIVO_MEDIDOR: listado con filtros opcionales y ORDER BY estable.
--   T-2020  INS_ACTIVO_MEDIDOR: alta en transaccion, codigo unico, fecha con FNC_PAIS_HORA.
--   T-2021  UPD_ACTIVO_MEDIDOR: edicion con ISNULL(@X, columna).
--   T-2022  DEL_ACTIVO_MEDIDOR: baja logica que rechaza si hay lecturas.
--
-- T-2018 - REVISION DEL MODELO Activo_Medidor
--   La tabla se creo en el bloque 11 (11_ACTIVOS_MEDICIONES). Aqui NO se
--   recrea: solo se confirma lo que HU-042 necesita.
--
--     - PK             PK_ACTIVO_MEDIDOR (ame_id)
--     - Codigo unico   UX_AME_ACTIVO_CODIGO (ame_activo, ame_codigo)
--     - FK a Cliente, Activo (compuesta ame_cliente+ame_activo),
--       Activo_Componente, Unidad_Medida.
--     - Auditoria: ame_usuario_creacion / ame_fecha_creacion /
--       ame_usuario_actualizacion / ame_fecha_actualizacion / ame_habilitado.
--
--   OJO: el codigo del medidor es unico POR ACTIVO, no por cliente. Es lo
--   correcto: un mismo activo no puede tener dos medidores "HOROMETRO", pero
--   dos activos distintos SI pueden llamar asi al suyo. La plantilla de la
--   tarea dice "dentro del cliente" por herencia de HU-035; para el medidor
--   el alcance real es el activo, y asi lo valida INS_/UPD_. El indice ya
--   existe; se garantiza de forma idempotente por si faltara.
--
--   ame_fecha_valor_actual_utc lleva sufijo _utc: se sella con GETUTCDATE(),
--   no con la hora del pais. Es la marca de tiempo del valor del medidor, que
--   la app compara entre lecturas de husos distintos; guardarla en hora local
--   la haria incomparable. Las fechas de AUDITORIA si van con FNC_PAIS_HORA,
--   como pide la tarea y como el resto del sitio.
--
-- ES IDEMPOTENTE: CREATE OR ALTER en los SP; el indice se crea solo si falta.
-- =============================================

SET NOCOUNT ON
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_AME_ACTIVO_CODIGO'
                  AND object_id = OBJECT_ID(N'[dbo].[Activo_Medidor]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_AME_ACTIVO_CODIGO
        ON [dbo].[Activo_Medidor] ([ame_activo], [ame_codigo])
    PRINT '--- Indice unico UX_AME_ACTIVO_CODIGO creado.'
END
ELSE
    PRINT '--- Indice unico UX_AME_ACTIVO_CODIGO ya existe (creado en el bloque 11). OK.'
GO


/* ========================================================================
   T-2020 - INS_ACTIVO_MEDIDOR
      Alta de un medidor dentro de transaccion. Valida el codigo unico por
      ACTIVO y que el activo sea del cliente. Sella la auditoria con la hora
      local del pais (FNC_PAIS_HORA) y la marca del valor con GETUTCDATE().
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_MEDIDOR]
@ID                 INT = NULL OUTPUT,
@CLIENTE            INT,
@ACTIVO             INT,
@UNIDAD_MEDIDA      INT,
@CODIGO             NVARCHAR(50),
@NOMBRE             NVARCHAR(200),
@VALOR_ACTUAL       DECIMAL(18,2) = 0,
@VALOR_REINICIO     DECIMAL(18,2) = NULL,
@PERMITE_REINICIO   BIT = 0,
@USUARIO            INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @NOW_UTC DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @NOW_UTC  = GETUTCDATE()

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @VALOR_ACTUAL = ISNULL(@VALOR_ACTUAL, 0)

BEGIN
    -- El activo tiene que ser del cliente: un medidor no cuelga de la
    -- maquina de otra empresa.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                    WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- Codigo unico por activo (HU-042).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                WHERE ame_activo = @ACTIVO AND ame_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UN MEDIDOR CON EL CODIGO "%s" EN ESTE ACTIVO.', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo_Medidor]
        (
            ame_cliente,
            ame_activo,
            ame_unidad_medida,
            ame_codigo,
            ame_nombre,
            ame_valor_actual,
            ame_fecha_valor_actual_utc,
            ame_valor_reinicio,
            ame_permite_reinicio,
            ame_usuario_creacion,
            ame_fecha_creacion,
            ame_usuario_actualizacion,
            ame_fecha_actualizacion,
            ame_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @ACTIVO,
            @UNIDAD_MEDIDA,
            @CODIGO,
            @NOMBRE,
            @VALOR_ACTUAL,
            @NOW_UTC,
            @VALOR_REINICIO,
            ISNULL(@PERMITE_REINICIO, 0),
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
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO_MEDIDOR @ACTIVO = ' + LTRIM(STR(@ACTIVO)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL MEDIDOR.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2019 - SEL_ACTIVO_MEDIDOR
      Listado con filtros opcionales (id, cliente, activo, habilitado, texto)
      y ORDER BY estable. Un solo SP sirve la grilla y la ficha (@ID).
      Devuelve el codigo/nombre del activo, la unidad con su simbolo y la
      auditoria con el nombre del usuario. Patron dinamico @SELECT/@FROM/
      @WHERE con @FILTRO escapado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MEDIDOR]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@ACTIVO      INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ame.ame_id                     AS AME_ID
                                  ,ame.ame_cliente                AS AME_CLIENTE
                                  ,ame.ame_activo                 AS AME_ACTIVO
                                  ,ame.ame_activo_componente      AS AME_ACTIVO_COMPONENTE
                                  ,ame.ame_unidad_medida          AS AME_UNIDAD_MEDIDA
                                  ,ame.ame_codigo                 AS AME_CODIGO
                                  ,ame.ame_nombre                 AS AME_NOMBRE
                                  ,ame.ame_valor_actual           AS AME_VALOR_ACTUAL
                                  ,ame.ame_fecha_valor_actual_utc AS AME_FECHA_VALOR_ACTUAL_UTC
                                  ,ame.ame_valor_reinicio         AS AME_VALOR_REINICIO
                                  ,ame.ame_permite_reinicio       AS AME_PERMITE_REINICIO
                                  ,ame.ame_usuario_creacion       AS AME_USUARIO_CREACION
                                  ,ame.ame_fecha_creacion         AS AME_FECHA_CREACION
                                  ,ame.ame_usuario_actualizacion  AS AME_USUARIO_ACTUALIZACION
                                  ,ame.ame_fecha_actualizacion    AS AME_FECHA_ACTUALIZACION
                                  ,ame.ame_habilitado             AS AME_HABILITADO
                                  ,act.act_codigo                 AS ACTIVO_CODIGO
                                  ,act.act_nombre                 AS ACTIVO_NOMBRE
                                  ,ume.ume_nombre                 AS UNIDAD_NOMBRE
                                  ,ume.ume_simbolo                AS UNIDAD_SIMBOLO
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Activo_Medidor] ame
                  INNER JOIN [dbo].[Activo]        act ON act.act_id = ame.ame_activo
                  INNER JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = ame.ame_unidad_medida
                  LEFT  JOIN [dbo].[Usuario]       uc  ON uc.usu_id  = ame.ame_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]       ua  ON ua.usu_id  = ame.ame_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ame.ame_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ame.ame_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@ACTIVO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ame.ame_activo = ' + LTRIM(@ACTIVO)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ame.ame_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (ame.ame_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ame.ame_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    -- ORDER BY estable: por activo y, dentro de cada activo, por codigo
    -- -unico ahi-, asi dos filas nunca empatan.
    SET @WHERE = @WHERE + ' ORDER BY act.act_codigo, ame.ame_codigo '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   T-2021 - UPD_ACTIVO_MEDIDOR
      Edicion. @ID y @USUARIO obligatorios; el resto opcional con
      ISNULL(@X, columna). El activo NO se cambia -un medidor pertenece a su
      maquina-. ame_activo_componente no viaja: al no estar en el SET se
      conserva. La marca del valor se resella (GETUTCDATE) solo si el valor
      cambia.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_MEDIDOR]
@ID                 INT,
@UNIDAD_MEDIDA      INT = NULL,
@CODIGO             NVARCHAR(50) = NULL,
@NOMBRE             NVARCHAR(200) = NULL,
@VALOR_ACTUAL       DECIMAL(18,2) = NULL,
@VALOR_REINICIO     DECIMAL(18,2) = NULL,
@PERMITE_REINICIO   BIT = NULL,
@HABILITADO         BIT = NULL,
@USUARIO            INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @ACTIVO INT

SELECT @CLIENTE = ame_cliente, @ACTIVO = ame_activo
FROM   [dbo].[Activo_Medidor] WHERE ame_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL MEDIDOR NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por activo, excluyendo el propio registro.
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                    WHERE ame_activo = @ACTIVO AND ame_codigo = @CODIGO AND ame_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN MEDIDOR CON EL CODIGO "%s" EN ESTE ACTIVO.', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Medidor]
    SET     ame_unidad_medida          = ISNULL(@UNIDAD_MEDIDA, ame_unidad_medida)
           ,ame_codigo                 = ISNULL(@CODIGO, ame_codigo)
           ,ame_nombre                 = ISNULL(@NOMBRE, ame_nombre)
           ,ame_valor_actual           = ISNULL(@VALOR_ACTUAL, ame_valor_actual)
           ,ame_fecha_valor_actual_utc = CASE WHEN @VALOR_ACTUAL IS NOT NULL
                                              THEN GETUTCDATE()
                                              ELSE ame_fecha_valor_actual_utc END
           ,ame_valor_reinicio         = @VALOR_REINICIO
           ,ame_permite_reinicio       = ISNULL(@PERMITE_REINICIO, ame_permite_reinicio)
           ,ame_habilitado             = ISNULL(@HABILITADO, ame_habilitado)
           ,ame_usuario_actualizacion  = @USUARIO
           ,ame_fecha_actualizacion    = @DATE_NOW
    WHERE   ame_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ACTIVO_MEDIDOR @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL MEDIDOR.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2022 - DEL_ACTIVO_MEDIDOR
      Baja LOGICA. Un medidor con lecturas registradas no se borra: sus
      lecturas son la historia de horas/ciclos de la maquina. Rechaza si
      tiene lecturas en vez de dejarlas huerfanas; si no, marca
      ame_habilitado = 0.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_MEDIDOR]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = ame_cliente FROM [dbo].[Activo_Medidor] WHERE ame_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL MEDIDOR NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN
    -- Lecturas registradas: son los dependientes. Sin ellas el medidor se
    -- puede dar de baja; con ellas, no se deja huerfana la historia.
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor_Lectura]
                WHERE aml_activo_medidor = @ID)
    BEGIN
        RAISERROR('2.- EL MEDIDOR TIENE LECTURAS REGISTRADAS. DESHABILITELO EN VEZ DE ELIMINARLO.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Medidor]
    SET     ame_habilitado            = 0
           ,ame_usuario_actualizacion = @USUARIO
           ,ame_fecha_actualizacion   = @DATE_NOW
    WHERE   ame_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_ACTIVO_MEDIDOR ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE DAR DE BAJA EL MEDIDOR.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


PRINT '77_SPRINT2_ACTIVO_MEDIDOR aplicado: modelo revisado y SEL/INS/UPD/DEL_ACTIVO_MEDIDOR.'
GO
