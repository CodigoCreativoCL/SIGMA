USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     TAREAS RECURRENTES DESDE LA WEB: TAREA, SU PROGRAMACION Y SUS
--                  COMENTARIOS (HU-102, HU-104).
-- =============================================
-- T-4283 · EL MODELO, REVISADO
--
--   `Tarea` es el trabajo breve (revisar un nivel, apretar un prensaestopas)
--   que hoy no deja registro. Tiene codigo unico por cliente
--   (UX_TAR_CLIENTE_CODIGO), prioridad obligatoria, y opcionalmente planta,
--   area, equipo y categoria. Hasta hoy solo la leia la app (API_SEL_TAREA):
--   no habia forma de CREAR una tarea desde la web, asi que HU-102 arranca
--   por ahi. Sin tarea no hay que programar.
--
--   `Tarea_Programacion` = «esta tarea, con esta programacion, la hace este
--   responsable o este grupo». Unica por (tarea, programacion):
--   UX_TPR_TAREA_PROGRAMACION. Responsable y grupo son opcionales en el
--   modelo y aca no se inventa una regla que la tabla no tiene.
--
--   `Tarea_Comentario` es append-only por diseño (sin habilitado ni
--   actualizacion, con padre): se responde, no se edita. La web sigue eso:
--   INS y SEL, nada mas. El API_INS_TAREA_COMENTARIO exige que el usuario
--   este asignado a la planta -correcto para el tecnico-; desde la web
--   comenta quien supervisa, y lo que se exige es el permiso COMENTAR TAREA
--   y que la ocurrencia sea del cliente.
--
-- UNA TAREA PROGRAMADA NO ES UNA OCURRENCIA
--
--   La programacion dice cada cuanto; las ocurrencias las genera HU-076 con
--   FNC_PROGRAMACION_FECHAS, igual que para los planes. Aqui se deja la
--   relacion lista y contada (OCURRENCIAS en el SEL) para que la pantalla
--   diga si ya genero algo.
-- =============================================

-- ---------------------------------------------------------------------------
-- 0) Codigo automatico TAR-<id>
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Tarea')
    INSERT INTO [dbo].[Modulo_Codigo]
        (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento, mco_habilitado)
    VALUES
        ('Tarea', 'TAR', 'tar_codigo', 'tar_id', 'INS_TAREA', 1)
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_TAREA — la grilla y la ficha con un solo SP
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@INSTALACION INT = NULL,
@ACTIVO      INT = NULL,
@PRIORIDAD   INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT tar.tar_id                       AS TAR_ID
                                  ,tar.tar_cliente                  AS TAR_CLIENTE
                                  ,tar.tar_cliente_instalacion      AS TAR_CLIENTE_INSTALACION
                                  ,tar.tar_instalacion_area         AS TAR_INSTALACION_AREA
                                  ,tar.tar_tarea_categoria          AS TAR_TAREA_CATEGORIA
                                  ,tar.tar_activo                   AS TAR_ACTIVO
                                  ,tar.tar_codigo                   AS TAR_CODIGO
                                  ,tar.tar_titulo                   AS TAR_TITULO
                                  ,tar.tar_descripcion              AS TAR_DESCRIPCION
                                  ,tar.tar_tarea_prioridad          AS TAR_TAREA_PRIORIDAD
                                  ,tar.tar_duracion_estimada_minuto AS TAR_DURACION_ESTIMADA_MINUTO
                                  ,tar.tar_requiere_evidencia       AS TAR_REQUIERE_EVIDENCIA
                                  ,tar.tar_usuario_creacion         AS TAR_USUARIO_CREACION
                                  ,tar.tar_fecha_creacion           AS TAR_FECHA_CREACION
                                  ,tar.tar_usuario_actualizacion    AS TAR_USUARIO_ACTUALIZACION
                                  ,tar.tar_fecha_actualizacion      AS TAR_FECHA_ACTUALIZACION
                                  ,tar.tar_habilitado               AS TAR_HABILITADO
                                  ,cin.cin_nombre                   AS PLANTA_NOMBRE
                                  ,iar.iar_nombre                   AS AREA_NOMBRE
                                  ,act.act_codigo                   AS ACTIVO_CODIGO
                                  ,act.act_nombre                   AS ACTIVO_NOMBRE
                                  ,tca.tca_nombre                   AS CATEGORIA_NOMBRE
                                  ,tpa.tpa_codigo                   AS PRIORIDAD_CODIGO
                                  ,tpa.tpa_nombre                   AS PRIORIDAD_NOMBRE
                                  ,tpa.tpa_orden                    AS PRIORIDAD_ORDEN
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                                  ,(SELECT COUNT(*) FROM [dbo].[Tarea_Programacion] p WHERE p.tpr_tarea = tar.tar_id AND p.tpr_habilitado = 1) AS PROGRAMACIONES
                                  ,(SELECT COUNT(*) FROM [dbo].[Tarea_Ocurrencia] o WHERE o.toc_tarea = tar.tar_id AND o.toc_habilitado = 1) AS OCURRENCIAS
                                  ,(SELECT COUNT(*) FROM [dbo].[Tarea_Ocurrencia] o WHERE o.toc_tarea = tar.tar_id AND o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado IN (1,2,3)) AS PENDIENTES '

    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Tarea] tar
                  JOIN      [dbo].[Tarea_Prioridad]     tpa ON tpa.tpa_id = tar.tar_tarea_prioridad
                  LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = tar.tar_cliente_instalacion
                  LEFT JOIN [dbo].[Instalacion_Area]    iar ON iar.iar_id = tar.tar_instalacion_area
                  LEFT JOIN [dbo].[Activo]              act ON act.act_id = tar.tar_activo
                  LEFT JOIN [dbo].[Tarea_Categoria]     tca ON tca.tca_id = tar.tar_tarea_categoria
                  LEFT JOIN [dbo].[Usuario]             uc  ON uc.usu_id  = tar.tar_usuario_creacion
                  LEFT JOIN [dbo].[Usuario]             ua  ON ua.usu_id  = tar.tar_usuario_actualizacion '

    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL)          SET @WHERE = @WHERE + ' AND tar.tar_id = ' + LTRIM(STR(@ID))
    IF (@CLIENTE IS NOT NULL)     SET @WHERE = @WHERE + ' AND tar.tar_cliente = ' + LTRIM(STR(@CLIENTE))
    IF (@INSTALACION IS NOT NULL) SET @WHERE = @WHERE + ' AND tar.tar_cliente_instalacion = ' + LTRIM(STR(@INSTALACION))
    IF (@ACTIVO IS NOT NULL)      SET @WHERE = @WHERE + ' AND tar.tar_activo = ' + LTRIM(STR(@ACTIVO))
    IF (@PRIORIDAD IS NOT NULL)   SET @WHERE = @WHERE + ' AND tar.tar_tarea_prioridad = ' + LTRIM(STR(@PRIORIDAD))
    IF (@HABILITADO IS NOT NULL)  SET @WHERE = @WHERE + ' AND tar.tar_habilitado = ' + LTRIM(STR(@HABILITADO))

    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (tar.tar_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR tar.tar_titulo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cin.cin_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY tar.tar_codigo '
END

EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------------------------------------------------------------------------
-- 2) INS_TAREA
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_TAREA]
@ID                       INT = NULL OUTPUT,
@CLIENTE                  INT,
@CODIGO                   NVARCHAR(100),
@TITULO                   NVARCHAR(400),
@DESCRIPCION              NVARCHAR(MAX) = NULL,
@TAREA_PRIORIDAD          INT,
@CLIENTE_INSTALACION      INT = NULL,
@INSTALACION_AREA         INT = NULL,
@ACTIVO                   INT = NULL,
@TAREA_CATEGORIA          INT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@REQUIERE_EVIDENCIA       BIT = 0,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @TITULO = LTRIM(RTRIM(@TITULO))

BEGIN
    IF (@TITULO IS NULL OR @TITULO = N'')
    BEGIN
        RAISERROR('1.- INDIQUE EL TÍTULO DE LA TAREA.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA TAREA CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE tpa_id = @TAREA_PRIORIDAD AND tpa_habilitado = 1)
    BEGIN
        RAISERROR('3.- INDIQUE LA PRIORIDAD DE LA TAREA.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- El area es de la planta indicada; sin planta, la planta es la del area.
    IF @INSTALACION_AREA IS NOT NULL
    BEGIN
        DECLARE @PLANTA_AREA INT = (SELECT iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_id = @INSTALACION_AREA AND iar_cliente = @CLIENTE)
        IF @PLANTA_AREA IS NULL
        BEGIN
            RAISERROR('5.- EL ÁREA NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END
        IF @CLIENTE_INSTALACION IS NULL SET @CLIENTE_INSTALACION = @PLANTA_AREA
        ELSE IF @CLIENTE_INSTALACION <> @PLANTA_AREA
        BEGIN
            RAISERROR('6.- EL ÁREA NO ES DE LA PLANTA INDICADA.', 16, 1)
            RETURN -1
        END
    END

    -- El equipo es del cliente; si hay planta, tiene que estar en ella.
    IF @ACTIVO IS NOT NULL
    BEGIN
        DECLARE @PLANTA_ACTIVO INT = (SELECT act_cliente_instalacion FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
        IF @PLANTA_ACTIVO IS NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
        BEGIN
            RAISERROR('7.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END
        IF @CLIENTE_INSTALACION IS NOT NULL AND @PLANTA_ACTIVO IS NOT NULL AND @CLIENTE_INSTALACION <> @PLANTA_ACTIVO
        BEGIN
            RAISERROR('8.- EL EQUIPO NO ESTÁ EN LA PLANTA INDICADA.', 16, 1)
            RETURN -1
        END
    END

    IF @TAREA_CATEGORIA IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @TAREA_CATEGORIA AND ISNULL(tca_cliente, @CLIENTE) = @CLIENTE)
    BEGIN
        RAISERROR('9.- LA CATEGORÍA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0
    BEGIN
        RAISERROR('10.- LA DURACIÓN ESTIMADA TIENE QUE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Tarea]
        (tar_cliente, tar_cliente_instalacion, tar_instalacion_area, tar_tarea_categoria, tar_activo,
         tar_codigo, tar_titulo, tar_descripcion, tar_tarea_prioridad, tar_duracion_estimada_minuto,
         tar_requiere_evidencia, tar_usuario_creacion, tar_fecha_creacion,
         tar_usuario_actualizacion, tar_fecha_actualizacion, tar_habilitado)
    VALUES
        (@CLIENTE, @CLIENTE_INSTALACION, @INSTALACION_AREA, @TAREA_CATEGORIA, @ACTIVO,
         @CODIGO, @TITULO, @DESCRIPCION, @TAREA_PRIORIDAD, @DURACION_ESTIMADA_MINUTO,
         ISNULL(@REQUIERE_EVIDENCIA, 0), @USUARIO, @DATE_NOW,
         @USUARIO, @DATE_NOW, 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR @CODIGO = 'AUTO')
        UPDATE [dbo].[Tarea] SET tar_codigo = [dbo].[FNC_CODIGO_AUTOMATICO]('TAR', @ID) WHERE tar_id = @ID

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_TAREA @CLIENTE = ' + LTRIM(STR(@CLIENTE)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '11.- NO FUE POSIBLE INSERTAR LA TAREA.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_TAREA — lo que la ficha no manda, se conserva; QUITA_* para vaciar
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_TAREA]
@ID                       INT,
@TITULO                   NVARCHAR(400) = NULL,
@DESCRIPCION              NVARCHAR(MAX) = NULL,
@TAREA_PRIORIDAD          INT = NULL,
@CLIENTE_INSTALACION      INT = NULL,
@INSTALACION_AREA         INT = NULL,
@ACTIVO                   INT = NULL,
@TAREA_CATEGORIA          INT = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@REQUIERE_EVIDENCIA       BIT = NULL,
@HABILITADO               BIT = NULL,
@QUITA_INSTALACION        BIT = 0,
@QUITA_AREA               BIT = 0,
@QUITA_ACTIVO             BIT = 0,
@QUITA_CATEGORIA          BIT = 0,
@QUITA_DURACION           BIT = 0,
@QUITA_DESCRIPCION        BIT = 0,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @CLIENTE = tar_cliente FROM [dbo].[Tarea] WHERE tar_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA TAREA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @TITULO = LTRIM(RTRIM(@TITULO))

BEGIN
    IF (@TITULO IS NOT NULL AND @TITULO = N'')
    BEGIN
        RAISERROR('2.- INDIQUE EL TÍTULO DE LA TAREA.', 16, 1)
        RETURN -1
    END

    IF @TAREA_PRIORIDAD IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE tpa_id = @TAREA_PRIORIDAD AND tpa_habilitado = 1)
    BEGIN
        RAISERROR('3.- LA PRIORIDAD NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- La planta que va a quedar, para cruzarla con area y equipo
    DECLARE @PLANTA_FINAL INT = CASE WHEN @QUITA_INSTALACION = 1 THEN NULL
                                     ELSE ISNULL(@CLIENTE_INSTALACION, (SELECT tar_cliente_instalacion FROM [dbo].[Tarea] WHERE tar_id = @ID)) END

    IF @INSTALACION_AREA IS NOT NULL
    BEGIN
        DECLARE @PLANTA_AREA INT = (SELECT iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_id = @INSTALACION_AREA AND iar_cliente = @CLIENTE)
        IF @PLANTA_AREA IS NULL
        BEGIN
            RAISERROR('5.- EL ÁREA NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END
        IF @PLANTA_FINAL IS NOT NULL AND @PLANTA_FINAL <> @PLANTA_AREA
        BEGIN
            RAISERROR('6.- EL ÁREA NO ES DE LA PLANTA INDICADA.', 16, 1)
            RETURN -1
        END
    END

    IF @ACTIVO IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
        BEGIN
            RAISERROR('7.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
            RETURN -1
        END
        DECLARE @PLANTA_ACTIVO INT = (SELECT act_cliente_instalacion FROM [dbo].[Activo] WHERE act_id = @ACTIVO)
        IF @PLANTA_FINAL IS NOT NULL AND @PLANTA_ACTIVO IS NOT NULL AND @PLANTA_FINAL <> @PLANTA_ACTIVO
        BEGIN
            RAISERROR('8.- EL EQUIPO NO ESTÁ EN LA PLANTA INDICADA.', 16, 1)
            RETURN -1
        END
    END

    IF @TAREA_CATEGORIA IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @TAREA_CATEGORIA AND ISNULL(tca_cliente, @CLIENTE) = @CLIENTE)
    BEGIN
        RAISERROR('9.- LA CATEGORÍA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @DURACION_ESTIMADA_MINUTO IS NOT NULL AND @DURACION_ESTIMADA_MINUTO <= 0
    BEGIN
        RAISERROR('10.- LA DURACIÓN ESTIMADA TIENE QUE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE [dbo].[Tarea]
    SET tar_titulo                   = ISNULL(@TITULO, tar_titulo),
        tar_descripcion              = CASE WHEN @QUITA_DESCRIPCION = 1 THEN NULL ELSE ISNULL(@DESCRIPCION, tar_descripcion) END,
        tar_tarea_prioridad          = ISNULL(@TAREA_PRIORIDAD, tar_tarea_prioridad),
        tar_cliente_instalacion      = CASE WHEN @QUITA_INSTALACION = 1 THEN NULL ELSE ISNULL(@CLIENTE_INSTALACION, tar_cliente_instalacion) END,
        tar_instalacion_area         = CASE WHEN @QUITA_AREA = 1 THEN NULL ELSE ISNULL(@INSTALACION_AREA, tar_instalacion_area) END,
        tar_activo                   = CASE WHEN @QUITA_ACTIVO = 1 THEN NULL ELSE ISNULL(@ACTIVO, tar_activo) END,
        tar_tarea_categoria          = CASE WHEN @QUITA_CATEGORIA = 1 THEN NULL ELSE ISNULL(@TAREA_CATEGORIA, tar_tarea_categoria) END,
        tar_duracion_estimada_minuto = CASE WHEN @QUITA_DURACION = 1 THEN NULL ELSE ISNULL(@DURACION_ESTIMADA_MINUTO, tar_duracion_estimada_minuto) END,
        tar_requiere_evidencia       = ISNULL(@REQUIERE_EVIDENCIA, tar_requiere_evidencia),
        tar_habilitado               = ISNULL(@HABILITADO, tar_habilitado),
        tar_usuario_actualizacion    = @USUARIO,
        tar_fecha_actualizacion      = @DATE_NOW
    WHERE tar_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_TAREA @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '11.- NO FUE POSIBLE ACTUALIZAR LA TAREA.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 4) DEL_TAREA — logico; con ocurrencias abiertas no se apaga
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_TAREA]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @CLIENTE = tar_cliente FROM [dbo].[Tarea] WHERE tar_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA TAREA NO EXISTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia] WHERE toc_tarea = @ID AND toc_habilitado = 1 AND toc_tarea_ocurrencia_estado IN (1,2,3))
BEGIN
    RAISERROR('2.- LA TAREA TIENE OCURRENCIAS PENDIENTES O EN EJECUCIÓN; CIÉRRELAS O CANCÉLELAS ANTES.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    -- Sus programaciones se apagan con ella: una tarea apagada no genera.
    UPDATE [dbo].[Tarea_Programacion]
    SET tpr_habilitado = 0, tpr_usuario_actualizacion = @USUARIO, tpr_fecha_actualizacion = @DATE_NOW
    WHERE tpr_tarea = @ID AND tpr_habilitado = 1

    UPDATE [dbo].[Tarea]
    SET tar_habilitado = 0, tar_usuario_actualizacion = @USUARIO, tar_fecha_actualizacion = @DATE_NOW
    WHERE tar_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'DEL_TAREA', @MSG = '3.- NO FUE POSIBLE ELIMINAR LA TAREA.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 5) SEL_TAREA_PROGRAMACION
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_PROGRAMACION]
@ID         INT = NULL,
@CLIENTE    INT = NULL,
@TAREA      INT = NULL,
@HABILITADO BIT = NULL

AS
SET NOCOUNT ON

SELECT  tpr.tpr_id                    AS TPR_ID,
        tpr.tpr_tarea                 AS TPR_TAREA,
        tpr.tpr_programacion          AS TPR_PROGRAMACION,
        tpr.tpr_usuario_responsable   AS TPR_USUARIO_RESPONSABLE,
        tpr.tpr_grupo_trabajo         AS TPR_GRUPO_TRABAJO,
        tpr.tpr_usuario_creacion      AS TPR_USUARIO_CREACION,
        tpr.tpr_fecha_creacion        AS TPR_FECHA_CREACION,
        tpr.tpr_usuario_actualizacion AS TPR_USUARIO_ACTUALIZACION,
        tpr.tpr_fecha_actualizacion   AS TPR_FECHA_ACTUALIZACION,
        tpr.tpr_habilitado            AS TPR_HABILITADO,
        tar.tar_cliente               AS TAREA_CLIENTE,
        tar.tar_codigo                AS TAREA_CODIGO,
        tar.tar_titulo                AS TAREA_TITULO,
        pro.pro_nombre                AS PROGRAMACION_NOMBRE,
        pti.pti_nombre                AS PROGRAMACION_TIPO_NOMBRE,
        pro.pro_fecha_inicio          AS PROGRAMACION_FECHA_INICIO,
        pro.pro_fecha_fin             AS PROGRAMACION_FECHA_FIN,
        pro.pro_habilitado            AS PROGRAMACION_HABILITADO,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre,'') + ' ' + ISNULL(ur.usu_apellido_paterno,''))) AS RESPONSABLE_NOMBRE,
        gtr.gtr_nombre                AS GRUPO_NOMBRE,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
        LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Tarea_Ocurrencia] o WHERE o.toc_tarea_programacion = tpr.tpr_id AND o.toc_habilitado = 1) AS OCURRENCIAS
FROM    [dbo].[Tarea_Programacion] tpr
JOIN    [dbo].[Tarea]              tar ON tar.tar_id = tpr.tpr_tarea
JOIN    [dbo].[Programacion]       pro ON pro.pro_id = tpr.tpr_programacion
LEFT JOIN [dbo].[Programacion_Tipo] pti ON pti.pti_id = pro.pro_programacion_tipo
LEFT JOIN [dbo].[Usuario]          ur  ON ur.usu_id  = tpr.tpr_usuario_responsable
LEFT JOIN [dbo].[Grupo_Trabajo]    gtr ON gtr.gtr_id = tpr.tpr_grupo_trabajo
LEFT JOIN [dbo].[Usuario]          uc  ON uc.usu_id  = tpr.tpr_usuario_creacion
LEFT JOIN [dbo].[Usuario]          ua  ON ua.usu_id  = tpr.tpr_usuario_actualizacion
WHERE   (@ID IS NULL OR tpr.tpr_id = @ID)
  AND   (@CLIENTE IS NULL OR tar.tar_cliente = @CLIENTE)
  AND   (@TAREA IS NULL OR tpr.tpr_tarea = @TAREA)
  AND   (@HABILITADO IS NULL OR tpr.tpr_habilitado = @HABILITADO)
ORDER BY tar.tar_codigo, pro.pro_nombre
GO

-- ---------------------------------------------------------------------------
-- 6) INS_TAREA_PROGRAMACION
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_TAREA_PROGRAMACION]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@TAREA               INT,
@PROGRAMACION        INT,
@USUARIO_RESPONSABLE INT = NULL,
@GRUPO_TRABAJO       INT = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_id = @TAREA AND tar_cliente = @CLIENTE AND tar_habilitado = 1)
    BEGIN
        RAISERROR('1.- LA TAREA NO EXISTE O ESTÁ DESHABILITADA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
    BEGIN
        RAISERROR('2.- LA PROGRAMACIÓN NO EXISTE O ESTÁ DESHABILITADA.', 16, 1)
        RETURN -1
    END

    -- Unica por (tarea, programacion): UX_TPR_TAREA_PROGRAMACION. Si existe
    -- apagada, se vuelve a encender en vez de chocar con el indice.
    DECLARE @APAGADA INT = (SELECT tpr_id FROM [dbo].[Tarea_Programacion] WHERE tpr_tarea = @TAREA AND tpr_programacion = @PROGRAMACION)
    IF @APAGADA IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Tarea_Programacion] WHERE tpr_id = @APAGADA AND tpr_habilitado = 1)
    BEGIN
        RAISERROR('3.- ESTA TAREA YA TIENE ESA PROGRAMACIÓN.', 16, 1)
        RETURN -1
    END

    IF @USUARIO_RESPONSABLE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO_RESPONSABLE AND ucl_id_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- EL RESPONSABLE NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @GRUPO_TRABAJO IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE AND gtr_habilitado = 1)
    BEGIN
        RAISERROR('5.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    IF @APAGADA IS NOT NULL
    BEGIN
        UPDATE [dbo].[Tarea_Programacion]
        SET tpr_usuario_responsable = @USUARIO_RESPONSABLE, tpr_grupo_trabajo = @GRUPO_TRABAJO,
            tpr_habilitado = 1, tpr_usuario_actualizacion = @USUARIO, tpr_fecha_actualizacion = @DATE_NOW
        WHERE tpr_id = @APAGADA
        SET @ID = @APAGADA
    END
    ELSE
    BEGIN
        INSERT [dbo].[Tarea_Programacion]
            (tpr_tarea, tpr_programacion, tpr_usuario_responsable, tpr_grupo_trabajo,
             tpr_usuario_creacion, tpr_fecha_creacion, tpr_usuario_actualizacion, tpr_fecha_actualizacion, tpr_habilitado)
        VALUES
            (@TAREA, @PROGRAMACION, @USUARIO_RESPONSABLE, @GRUPO_TRABAJO,
             @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        SET @ID = SCOPE_IDENTITY()
    END

    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_TAREA_PROGRAMACION', @MSG = '6.- NO FUE POSIBLE PROGRAMAR LA TAREA.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 7) UPD_TAREA_PROGRAMACION — se cambia quien la hace; la programacion no
--    (cambiarla es quitar una y poner otra, a la vista)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_TAREA_PROGRAMACION]
@ID                  INT,
@USUARIO_RESPONSABLE INT = NULL,
@GRUPO_TRABAJO       INT = NULL,
@HABILITADO          BIT = NULL,
@QUITA_RESPONSABLE   BIT = 0,
@QUITA_GRUPO         BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @CLIENTE = tar.tar_cliente FROM [dbo].[Tarea_Programacion] tpr JOIN [dbo].[Tarea] tar ON tar.tar_id = tpr.tpr_tarea WHERE tpr.tpr_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA PROGRAMACIÓN DE LA TAREA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @USUARIO_RESPONSABLE IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO_RESPONSABLE AND ucl_id_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- EL RESPONSABLE NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @GRUPO_TRABAJO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE AND gtr_habilitado = 1)
BEGIN
    RAISERROR('3.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Tarea_Programacion]
    SET tpr_usuario_responsable   = CASE WHEN @QUITA_RESPONSABLE = 1 THEN NULL ELSE ISNULL(@USUARIO_RESPONSABLE, tpr_usuario_responsable) END,
        tpr_grupo_trabajo         = CASE WHEN @QUITA_GRUPO = 1 THEN NULL ELSE ISNULL(@GRUPO_TRABAJO, tpr_grupo_trabajo) END,
        tpr_habilitado            = ISNULL(@HABILITADO, tpr_habilitado),
        tpr_usuario_actualizacion = @USUARIO,
        tpr_fecha_actualizacion   = @DATE_NOW
    WHERE tpr_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_TAREA_PROGRAMACION', @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA PROGRAMACIÓN DE LA TAREA.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 8) DEL_TAREA_PROGRAMACION — logico
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_TAREA_PROGRAMACION]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @CLIENTE = tar.tar_cliente FROM [dbo].[Tarea_Programacion] tpr JOIN [dbo].[Tarea] tar ON tar.tar_id = tpr.tpr_tarea WHERE tpr.tpr_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA PROGRAMACIÓN DE LA TAREA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

UPDATE [dbo].[Tarea_Programacion]
SET tpr_habilitado = 0, tpr_usuario_actualizacion = @USUARIO, tpr_fecha_actualizacion = @DATE_NOW
WHERE tpr_id = @ID

IF @@ROWCOUNT = 0
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'DEL_TAREA_PROGRAMACION', @MSG = '2.- NO FUE POSIBLE QUITAR LA PROGRAMACIÓN.'
    RETURN -1
END

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 9) SEL_TAREA_COMENTARIO — el hilo, por tarea o por ocurrencia (HU-104)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_COMENTARIO]
@ID         INT = NULL,
@CLIENTE    INT = NULL,
@TAREA      INT = NULL,
@OCURRENCIA INT = NULL

AS
SET NOCOUNT ON

SELECT  tco.tco_id                    AS TCO_ID,
        tco.tco_tarea_ocurrencia      AS TCO_TAREA_OCURRENCIA,
        tco.tco_comentario_padre      AS TCO_COMENTARIO_PADRE,
        tco.tco_texto                 AS TCO_TEXTO,
        tco.tco_dictado_voz           AS TCO_DICTADO_VOZ,
        tco.tco_usuario_creacion      AS TCO_USUARIO_CREACION,
        tco.tco_fecha_creacion        AS TCO_FECHA_CREACION,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS USUARIO_NOMBRE,
        toc.toc_tarea                 AS TAREA_ID,
        tar.tar_codigo                AS TAREA_CODIGO,
        tar.tar_titulo                AS TAREA_TITULO,
        toc.toc_fecha_programada_utc  AS OCURRENCIA_FECHA,
        toe.toe_codigo                AS OCURRENCIA_ESTADO_CODIGO,
        toe.toe_nombre                AS OCURRENCIA_ESTADO_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Tarea_Comentario] r WHERE r.tco_comentario_padre = tco.tco_id) AS RESPUESTAS
FROM    [dbo].[Tarea_Comentario]        tco
JOIN    [dbo].[Tarea_Ocurrencia]        toc ON toc.toc_id = tco.tco_tarea_ocurrencia
JOIN    [dbo].[Tarea]                   tar ON tar.tar_id = toc.toc_tarea
LEFT JOIN [dbo].[Tarea_Ocurrencia_Estado] toe ON toe.toe_id = toc.toc_tarea_ocurrencia_estado
LEFT JOIN [dbo].[Usuario]               u   ON u.usu_id = tco.tco_usuario_creacion
WHERE   (@ID IS NULL OR tco.tco_id = @ID)
  AND   (@CLIENTE IS NULL OR toc.toc_cliente = @CLIENTE)
  AND   (@TAREA IS NULL OR toc.toc_tarea = @TAREA)
  AND   (@OCURRENCIA IS NULL OR tco.tco_tarea_ocurrencia = @OCURRENCIA)
ORDER BY toc.toc_fecha_programada_utc DESC, tco.tco_id
GO

-- ---------------------------------------------------------------------------
-- 10) INS_TAREA_COMENTARIO — desde la web: quien supervisa responde
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_TAREA_COMENTARIO]
@ID         INT = NULL OUTPUT,
@CLIENTE    INT,
@OCURRENCIA INT,
@TEXTO      NVARCHAR(MAX),
@PADRE      INT = NULL,
@USUARIO    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @TEXTO = LTRIM(RTRIM(@TEXTO))

IF (@TEXTO IS NULL OR @TEXTO = N'')
BEGIN
    RAISERROR('1.- ESCRIBA EL COMENTARIO.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = @OCURRENCIA AND toc_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- LA OCURRENCIA DE LA TAREA NO EXISTE.', 16, 1)
    RETURN -1
END

IF @PADRE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Comentario] WHERE tco_id = @PADRE AND tco_tarea_ocurrencia = @OCURRENCIA)
BEGIN
    RAISERROR('3.- EL COMENTARIO AL QUE RESPONDE NO ES DE ESTA TAREA.', 16, 1)
    RETURN -1
END

-- Mismo reintento tolerado que el API: el mismo texto del mismo usuario en 5 minutos es uno solo.
SELECT TOP 1 @ID = tco_id FROM [dbo].[Tarea_Comentario]
WHERE tco_tarea_ocurrencia = @OCURRENCIA AND tco_usuario_creacion = @USUARIO AND tco_texto = @TEXTO
  AND tco_fecha_creacion >= DATEADD(MINUTE, -5, @DATE_NOW)
ORDER BY tco_id DESC
IF @ID IS NOT NULL RETURN(0)

INSERT [dbo].[Tarea_Comentario]
    (tco_tarea_ocurrencia, tco_comentario_padre, tco_texto, tco_dictado_voz, tco_usuario_creacion, tco_fecha_creacion)
VALUES
    (@OCURRENCIA, @PADRE, @TEXTO, NULL, @USUARIO, @DATE_NOW)

SET @ID = SCOPE_IDENTITY()

IF @ID IS NULL
BEGIN
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_TAREA_COMENTARIO', @MSG = '4.- NO FUE POSIBLE GUARDAR EL COMENTARIO.'
    RETURN -1
END

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 11) Permisos, menu y funciones
-- ---------------------------------------------------------------------------
DECLARE @HOY DATETIME = GETDATE()

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER TAREAS')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'VER TAREAS', 'Ver tareas recurrentes', p.prm_modulo, p.prm_permiso_ambito,
           'Consultar las tareas recurrentes, sus programaciones y sus comentarios',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM   [dbo].[Permiso] p WHERE p.prm_codigo = 'VER PROGRAMACIONES'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR TAREAS')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'CREAR EDITAR TAREAS', 'Crear y editar tareas recurrentes', p.prm_modulo, p.prm_permiso_ambito,
           'Crear, editar, programar y deshabilitar tareas recurrentes',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario
    FROM   [dbo].[Permiso] p WHERE p.prm_codigo = 'CREAR EDITAR PROGRAMACIONES'

DECLARE @VER    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER TAREAS')
DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR TAREAS')
DECLARE @COMENTAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'COMENTAR TAREA')
DECLARE @VER_PROG    INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROGRAMACIONES')
DECLARE @EDITAR_PROG INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROGRAMACIONES')

-- A los mismos perfiles que manejan programaciones. COMENTAR TAREA ya existe
-- (ambito app) y se otorga tambien a los que editan tareas, para responder
-- desde la web.
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @VER, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @VER_PROG
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @VER)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @EDITAR, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @EDITAR_PROG
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @EDITAR)

IF @COMENTAR IS NOT NULL
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @COMENTAR, pp.ppe_usuario_creacion, @HOY
FROM   [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @EDITAR_PROG
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @COMENTAR)

-- Un solo menu: «Tareas recurrentes», despues de Planes; la ficha es el
-- centro de la tarea (Default.master con pestañas) y la programacion un modal.
DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')
IF (@PADRE IS NULL)
BEGIN
    RAISERROR('CORRA BD/212 ANTES QUE ESTE.', 16, 1)
    RETURN
END

DECLARE @ORDEN INT = ISNULL((SELECT MAX(mnu_orden) FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_orden < 99), 0) + 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Tareas/Tareas.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Tareas recurrentes', 'Trabajo breve que se repite: qué, cada cuánto y quién', 3, @PADRE, @ORDEN,
            '~/View/Mantenimiento/Tareas/Tareas.aspx', 1, 'mdi mdi-checkbox-marked-circle-outline', @VER, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Tareas/Tarea.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Tarea (detalle)', 'Ficha, programaciones y comentarios de una tarea', 3, @PADRE, 99,
            '~/View/Mantenimiento/Tareas/Tarea.aspx', 0, '', @VER, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Tareas/TareaProgramacion.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Programación de tarea (detalle)', 'Cada cuánto y quién hace una tarea', 3, @PADRE, 99,
            '~/View/Mantenimiento/Tareas/TareaProgramacion.aspx', 0, '', @VER, 1)

DECLARE @M INT
SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Tareas/Tareas.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @EDITAR)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @M, @EDITAR)

SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Tareas/Tarea.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @EDITAR)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @M, @EDITAR)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN
        ('SEL_TAREA','INS_TAREA','UPD_TAREA','DEL_TAREA','SEL_TAREA_PROGRAMACION','INS_TAREA_PROGRAMACION',
         'UPD_TAREA_PROGRAMACION','DEL_TAREA_PROGRAMACION','SEL_TAREA_COMENTARIO','INS_TAREA_COMENTARIO')) AS VARCHAR) + ' de 10' AS RESULTADO
UNION ALL SELECT 'Permisos = ' + CAST((SELECT COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN ('VER TAREAS','CREAR EDITAR TAREAS')) AS VARCHAR) + ' de 2'
UNION ALL SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Mantenimiento/Tareas/%') AS VARCHAR) + ' de 3'
UNION ALL SELECT 'Modulo_Codigo = ' + CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Tarea') THEN 'OK' ELSE 'FALTA' END
GO
