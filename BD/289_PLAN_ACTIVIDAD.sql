USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     ACTIVIDADES DE UN HITO: SP, MENU Y PERMISOS (HU-082).
-- =============================================
-- T-4050 · EL MODELO, REVISADO
--
--   `Plan_Mantenimiento_Actividad` ya existe y esta completa: sus tres FK
--   -FK_PAA_HITO, FK_PAA_PROCEDIMIENTO, FK_PAA_PERMISO_TIPO- y el indice
--   unico `UX_PAA_HITO_CODIGO` sobre (hito, codigo). No hay nada que crear.
--
--   El codigo de la actividad es unico DENTRO DEL HITO, no dentro de la
--   version ni del cliente: dos hitos del mismo plan van a tener su
--   actividad «01» cada uno, y eso es correcto. El SP valida contra ese
--   indice y dice con palabras cual codigo choco.
--
-- SOLO SE ESCRIBE SOBRE UN BORRADOR
--
--   La actividad cuelga del hito, el hito de la version, y una version
--   publicada ya esta generando mantenciones: cambiarle una actividad por
--   debajo es cambiar lo que se comprometio. INS, UPD y DEL rechazan si la
--   version no esta en BORRADOR. Es la misma regla del bloque 213 y por el
--   mismo motivo.
--
-- LA ACTIVIDAD PUEDE APUNTAR A UN PROCEDIMIENTO
--
--   Si lo hace, INS_ORDEN_TRABAJO_OCURRENCIA copia los pasos de ese
--   procedimiento a la orden que genera el plan -eso ya funciona-. Por eso
--   el procedimiento se valida contra el cliente: una actividad que apunta
--   al procedimiento de otra empresa le copiaria esos pasos a la orden.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_ACTIVIDAD — la grilla y la ficha con un solo SP (T-4051)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_ACTIVIDAD]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@PLAN        INT = NULL,
@VERSION     INT = NULL,
@HITO        INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT paa.paa_id                           AS PAA_ID
                                  ,paa.paa_plan_mantenimiento_hito      AS PAA_PLAN_MANTENIMIENTO_HITO
                                  ,paa.paa_procedimiento                AS PAA_PROCEDIMIENTO
                                  ,paa.paa_codigo                       AS PAA_CODIGO
                                  ,paa.paa_nombre                       AS PAA_NOMBRE
                                  ,paa.paa_descripcion                  AS PAA_DESCRIPCION
                                  ,paa.paa_orden                        AS PAA_ORDEN
                                  ,paa.paa_duracion_estimada_minuto     AS PAA_DURACION_ESTIMADA_MINUTO
                                  ,paa.paa_obligatoria                  AS PAA_OBLIGATORIA
                                  ,paa.paa_requiere_parada               AS PAA_REQUIERE_PARADA
                                  ,paa.paa_requiere_permiso             AS PAA_REQUIERE_PERMISO
                                  ,paa.paa_permiso_trabajo_tipo         AS PAA_PERMISO_TRABAJO_TIPO
                                  ,paa.paa_usuario_creacion             AS PAA_USUARIO_CREACION
                                  ,paa.paa_fecha_creacion               AS PAA_FECHA_CREACION
                                  ,paa.paa_usuario_actualizacion        AS PAA_USUARIO_ACTUALIZACION
                                  ,paa.paa_fecha_actualizacion          AS PAA_FECHA_ACTUALIZACION
                                  ,paa.paa_habilitado                   AS PAA_HABILITADO
                                  ,pmh.pmh_codigo                       AS HITO_CODIGO
                                  ,pmh.pmh_nombre                       AS HITO_NOMBRE
                                  ,pmh.pmh_orden                        AS HITO_ORDEN
                                  ,pmv.pmv_id                           AS VERSION_ID
                                  ,pmv.pmv_numero                       AS VERSION_NUMERO
                                  ,pve.pve_codigo                       AS VERSION_ESTADO_CODIGO
                                  ,pve.pve_nombre                       AS VERSION_ESTADO_NOMBRE
                                  ,pma.pma_id                           AS PLAN_ID
                                  ,pma.pma_cliente                      AS PLAN_CLIENTE
                                  ,pma.pma_codigo                       AS PLAN_CODIGO
                                  ,pma.pma_nombre                       AS PLAN_NOMBRE
                                  ,prc.prc_codigo                       AS PROCEDIMIENTO_CODIGO
                                  ,prc.prc_nombre                       AS PROCEDIMIENTO_NOMBRE
                                  ,ISNULL(pas.cuantos, 0)               AS PROCEDIMIENTO_PASOS
                                  ,ptt.ptt_nombre                       AS PERMISO_TIPO_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Plan_Mantenimiento_Actividad] paa
                  INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = paa.paa_plan_mantenimiento_hito
                  INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
                  INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
                  LEFT  JOIN [dbo].[Plan_Version_Estado]        pve ON pve.pve_id = pmv.pmv_plan_version_estado
                  LEFT  JOIN [dbo].[Procedimiento]              prc ON prc.prc_id = paa.paa_procedimiento
                  LEFT  JOIN [dbo].[Permiso_Trabajo_Tipo]       ptt ON ptt.ptt_id = paa.paa_permiso_trabajo_tipo
                  LEFT  JOIN [dbo].[Usuario]                    uc  ON uc.usu_id  = paa.paa_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]                    ua  ON ua.usu_id  = paa.paa_usuario_actualizacion
                  OUTER APPLY (SELECT COUNT(*) AS cuantos FROM [dbo].[Procedimiento_Paso] p
                               WHERE  p.ppa_procedimiento = paa.paa_procedimiento AND ISNULL(p.ppa_habilitado, 1) = 1) pas
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)         SET @WHERE = @WHERE + ' AND paa.paa_id = ' + LTRIM(@ID)
    -- El cliente se filtra a traves del plan: la actividad esta tres tablas
    -- mas abajo y no lleva cliente, que es lo correcto.
    IF (@CLIENTE IS NOT NULL)    SET @WHERE = @WHERE + ' AND pma.pma_cliente = ' + LTRIM(@CLIENTE)
    IF (@PLAN IS NOT NULL)       SET @WHERE = @WHERE + ' AND pma.pma_id = ' + LTRIM(@PLAN)
    IF (@VERSION IS NOT NULL)    SET @WHERE = @WHERE + ' AND pmv.pmv_id = ' + LTRIM(@VERSION)
    IF (@HITO IS NOT NULL)       SET @WHERE = @WHERE + ' AND pmh.pmh_id = ' + LTRIM(@HITO)
    IF (@HABILITADO IS NOT NULL) SET @WHERE = @WHERE + ' AND paa.paa_habilitado = ' + LTRIM(@HABILITADO)

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (paa.paa_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR paa.paa_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pmh.pmh_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR pmh.pmh_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR prc.prc_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    /* Por plan, version, hito y ORDEN: el orden de la actividad es la
       secuencia en que hay que hacerla, y una grilla alfabetica obliga a
       leer la columna para reconstruirla. */
    SET @WHERE = @WHERE + ' ORDER BY pma.pma_codigo, pmv.pmv_numero DESC, pmh.pmh_orden, paa.paa_orden, paa.paa_codigo '
END

EXEC(@SELECT + @FROM + @WHERE)
GO
PRINT '--- SEL_PLAN_ACTIVIDAD creado.'
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_ACTIVIDAD (T-4052)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_ACTIVIDAD]
@ID                       INT = NULL OUTPUT,
@CLIENTE                  INT,
@HITO                     INT,
@CODIGO                   NVARCHAR(100),
@NOMBRE                   NVARCHAR(400),
@DESCRIPCION              NVARCHAR(1000) = NULL,
@ORDEN                    INT = NULL,
@PROCEDIMIENTO            INT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@OBLIGATORIA              BIT = 1,
@REQUIERE_PARADA          BIT = 0,
@REQUIERE_PERMISO         BIT = 0,
@PERMISO_TRABAJO_TIPO     INT = NULL,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT, @ESTADO INT, @CLIENTE_HITO INT

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    SELECT @VERSION = pmh.pmh_plan_mantenimiento_version,
           @ESTADO  = pmv.pmv_plan_version_estado,
           @CLIENTE_HITO = pma.pma_cliente
    FROM   [dbo].[Plan_Mantenimiento_Hito] pmh
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
    WHERE  pmh.pmh_id = @HITO

    IF @VERSION IS NULL
    BEGIN
        RAISERROR('1.- EL HITO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE_HITO <> @CLIENTE
    BEGIN
        RAISERROR('2.- EL HITO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* La version publicada ya genero mantenciones: agregarle una actividad
       por debajo cambia lo que se comprometio sin dejar rastro. */
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('3.- LA VERSIÓN DEL PLAN YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA AGREGARLE ACTIVIDADES.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR @CODIGO = N'')
    BEGIN
        RAISERROR('4.- INDIQUE EL CÓDIGO DE LA ACTIVIDAD.', 16, 1)
        RETURN -1
    END

    IF (@NOMBRE IS NULL OR @NOMBRE = N'')
    BEGIN
        RAISERROR('5.- INDIQUE EL NOMBRE DE LA ACTIVIDAD.', 16, 1)
        RETURN -1
    END

    -- Unico dentro del hito: lo garantiza UX_PAA_HITO_CODIGO, y aca se dice
    -- con palabras cual codigo choco.
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                WHERE paa_plan_mantenimiento_hito = @HITO AND paa_codigo = @CODIGO)
    BEGIN
        RAISERROR('6.- YA EXISTE UNA ACTIVIDAD CON EL CÓDIGO "%s" EN ESTE HITO.', 16, 1, @CODIGO)
        RETURN -1
    END

    /* El procedimiento se valida contra el cliente porque sus pasos se COPIAN
       a la orden que genera el plan: uno de otra empresa le copiaria esos
       pasos a la orden. */
    IF (@PROCEDIMIENTO IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM [dbo].[Procedimiento]
             WHERE prc_id = @PROCEDIMIENTO AND prc_cliente = @CLIENTE AND ISNULL(prc_habilitado, 1) = 1))
    BEGIN
        RAISERROR('7.- EL PROCEDIMIENTO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('8.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    /* Pedir permiso de trabajo sin decir de que tipo deja la orden sin saber
       que permiso emitir. */
    IF (ISNULL(@REQUIERE_PERMISO, 0) = 1 AND @PERMISO_TRABAJO_TIPO IS NULL)
    BEGIN
        RAISERROR('9.- SI LA ACTIVIDAD REQUIERE PERMISO DE TRABAJO, INDIQUE DE QUÉ TIPO.', 16, 1)
        RETURN -1
    END

    -- Sin orden, va al final del hito.
    IF (@ORDEN IS NULL OR @ORDEN < 1)
        SELECT @ORDEN = ISNULL(MAX(paa_orden), 0) + 1
        FROM   [dbo].[Plan_Mantenimiento_Actividad]
        WHERE  paa_plan_mantenimiento_hito = @HITO

    SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
    SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Mantenimiento_Actividad]
        (
            paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion,
            paa_orden, paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada,
            paa_requiere_permiso, paa_permiso_trabajo_tipo,
            paa_usuario_creacion, paa_fecha_creacion, paa_usuario_actualizacion, paa_fecha_actualizacion,
            paa_habilitado
        )
    VALUES
        (
            @HITO, @PROCEDIMIENTO, @CODIGO, @NOMBRE, @DESCRIPCION,
            @ORDEN, @DURACION_ESTIMADA_MINUTO, ISNULL(@OBLIGATORIA, 1), ISNULL(@REQUIERE_PARADA, 0),
            ISNULL(@REQUIERE_PERMISO, 0), @PERMISO_TRABAJO_TIPO,
            @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW,
            1
        )

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_ACTIVIDAD @HITO = ' + LTRIM(STR(@HITO)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '10.- NO FUE POSIBLE INSERTAR LA ACTIVIDAD.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- INS_PLAN_ACTIVIDAD creado.'
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_PLAN_ACTIVIDAD (T-4053)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_ACTIVIDAD]
@ID                       INT,
@CODIGO                   NVARCHAR(100) = NULL,
@NOMBRE                   NVARCHAR(400) = NULL,
@DESCRIPCION              NVARCHAR(1000) = NULL,
@ORDEN                    INT = NULL,
@PROCEDIMIENTO            INT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@OBLIGATORIA              BIT = NULL,
@REQUIERE_PARADA          BIT = NULL,
@REQUIERE_PERMISO         BIT = NULL,
@PERMISO_TRABAJO_TIPO     INT = NULL,
@HABILITADO               BIT = NULL,
@QUITA_PROCEDIMIENTO      BIT = 0,
@QUITA_PERMISO_TIPO       BIT = 0,
@QUITA_DURACION           BIT = 0,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @HITO INT, @ESTADO INT, @CLIENTE INT

BEGIN
    SELECT @HITO = paa.paa_plan_mantenimiento_hito,
           @ESTADO = pmv.pmv_plan_version_estado,
           @CLIENTE = pma.pma_cliente
    FROM   [dbo].[Plan_Mantenimiento_Actividad] paa
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = paa.paa_plan_mantenimiento_hito
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
    WHERE  paa.paa_id = @ID

    IF @HITO IS NULL
    BEGIN
        RAISERROR('1.- LA ACTIVIDAD NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTA ACTIVIDAD YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLA.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NOT NULL)
    BEGIN
        SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

        IF (@CODIGO = N'')
        BEGIN
            RAISERROR('3.- INDIQUE EL CÓDIGO DE LA ACTIVIDAD.', 16, 1)
            RETURN -1
        END

        IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                    WHERE paa_plan_mantenimiento_hito = @HITO AND paa_codigo = @CODIGO AND paa_id <> @ID)
        BEGIN
            RAISERROR('4.- YA EXISTE OTRA ACTIVIDAD CON EL CÓDIGO "%s" EN ESTE HITO.', 16, 1, @CODIGO)
            RETURN -1
        END
    END

    IF (@PROCEDIMIENTO IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM [dbo].[Procedimiento]
             WHERE prc_id = @PROCEDIMIENTO AND prc_cliente = @CLIENTE AND ISNULL(prc_habilitado, 1) = 1))
    BEGIN
        RAISERROR('5.- EL PROCEDIMIENTO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0)
    BEGIN
        RAISERROR('6.- LA DURACIÓN ESTIMADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    /* ISNULL(@X, columna) en lo que la ficha podria no traer, y un
       @QUITA_ explicito para lo que SI se puede dejar vacio: sin el, no hay
       forma de distinguir "no me lo mandaron" de "quiero borrarlo". */
    UPDATE  [dbo].[Plan_Mantenimiento_Actividad]
    SET     paa_codigo                   = ISNULL(@CODIGO, paa_codigo)
           ,paa_nombre                    = ISNULL(@NOMBRE, paa_nombre)
           /* Cadena vacia es "borrala": el que vacio el campo y guardo
              espera que quede vacio, no que reaparezca lo de antes. */
           ,paa_descripcion               = CASE WHEN @DESCRIPCION = N'' THEN NULL
                                                 ELSE ISNULL(@DESCRIPCION, paa_descripcion) END
           ,paa_orden                     = ISNULL(@ORDEN, paa_orden)
           ,paa_procedimiento             = CASE WHEN ISNULL(@QUITA_PROCEDIMIENTO, 0) = 1 THEN NULL
                                                 ELSE ISNULL(@PROCEDIMIENTO, paa_procedimiento) END
           ,paa_duracion_estimada_minuto  = CASE WHEN ISNULL(@QUITA_DURACION, 0) = 1 THEN NULL
                                                 ELSE ISNULL(@DURACION_ESTIMADA_MINUTO, paa_duracion_estimada_minuto) END
           ,paa_obligatoria               = ISNULL(@OBLIGATORIA, paa_obligatoria)
           ,paa_requiere_parada           = ISNULL(@REQUIERE_PARADA, paa_requiere_parada)
           ,paa_requiere_permiso          = ISNULL(@REQUIERE_PERMISO, paa_requiere_permiso)
           ,paa_permiso_trabajo_tipo      = CASE WHEN ISNULL(@QUITA_PERMISO_TIPO, 0) = 1 THEN NULL
                                                 ELSE ISNULL(@PERMISO_TRABAJO_TIPO, paa_permiso_trabajo_tipo) END
           ,paa_habilitado                = ISNULL(@HABILITADO, paa_habilitado)
           ,paa_usuario_actualizacion     = @USUARIO
           ,paa_fecha_actualizacion       = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))
    WHERE   paa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_ACTIVIDAD ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '7.- NO FUE POSIBLE ACTUALIZAR LA ACTIVIDAD.'
        RETURN -1
    END

    /* Quedarse pidiendo permiso sin tipo es el mismo hueco que valida el INS:
       si se apago el permiso, el tipo se va con el. */
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad]
                WHERE paa_id = @ID AND paa_requiere_permiso = 0 AND paa_permiso_trabajo_tipo IS NOT NULL)
        UPDATE [dbo].[Plan_Mantenimiento_Actividad] SET paa_permiso_trabajo_tipo = NULL WHERE paa_id = @ID

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- UPD_PLAN_ACTIVIDAD creado.'
GO

-- ---------------------------------------------------------------------------
-- 4) DEL_PLAN_ACTIVIDAD — baja logica (T-4054)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_ACTIVIDAD]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @ESTADO INT, @EXISTE INT

BEGIN
    SELECT @EXISTE = paa.paa_id,
           @ESTADO = pmv.pmv_plan_version_estado,
           @CLIENTE = pma.pma_cliente
    FROM   [dbo].[Plan_Mantenimiento_Actividad] paa
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    pmh ON pmh.pmh_id = paa.paa_plan_mantenimiento_hito
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento]         pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
    WHERE  paa.paa_id = @ID

    IF @EXISTE IS NULL
    BEGIN
        RAISERROR('1.- LA ACTIVIDAD NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTA ACTIVIDAD YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLA.', 16, 1)
        RETURN -1
    END

    /* La actividad que ya quedo pegada a una orden de trabajo no se borra: esa
       orden dice que se mando a hacer ese dia, y sacarla la deja hablando de
       algo que no existe. */
    IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Paso]
                WHERE otp_plan_mantenimiento_actividad = @ID)
    BEGIN
        RAISERROR('3.- LA ACTIVIDAD YA SE COPIÓ A UNA ORDEN DE TRABAJO Y NO SE PUEDE ELIMINAR. DESHABILÍTELA.', 16, 1)
        RETURN -1
    END

    SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
    SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Mantenimiento_Actividad]
    SET     paa_habilitado            = 0
           ,paa_usuario_actualizacion = @USUARIO
           ,paa_fecha_actualizacion   = @DATE_NOW
    WHERE   paa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_ACTIVIDAD ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE ELIMINAR LA ACTIVIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- DEL_PLAN_ACTIVIDAD creado.'
GO

PRINT '289_PLAN_ACTIVIDAD aplicado.'
GO
