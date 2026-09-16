USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  15-09-2026
-- DESCRIPTION:     POSICIONES FUNCIONALES: EL LUGAR ESTABLE DENTRO DE UN AREA
--                  AL QUE SE LE PEGA UN QR Y POR EL QUE PASAN LAS MAQUINAS.
--                  HU-033 (mantenedor e historial), HU-034 (etiqueta QR),
--                  HU-154 (escaneo desde la app).
-- =============================================
-- LO QUE HABIA
--   Activo_Posicion, Activo_Posicion_Historial y Activo_Posicion_Motivo
--   existen desde el bloque 11 y Activo.act_activo_posicion apunta a la
--   posicion que ocupa cada equipo, pero no habia SP, pantalla ni etiqueta:
--   las tres tablas estaban vacias.
--
-- LO QUE HACE ESTE BLOQUE
--   · SEL/INS/UPD/DEL_ACTIVO_POSICION con el estandar del sitio (codigo
--     POS-<id> automatico via Modulo_Codigo, unico por cliente, area de la
--     misma planta, baja logica si ya tiene historia).
--   · UPD_ACTIVO_POSICION_OCUPAR / LIBERAR: la ocupacion se registra como
--     periodos en el historial (inicio, fin, motivo) y se refleja en
--     Activo.act_activo_posicion. El periodo vigente no tiene fin (HU-033 #2).
--     Un equipo ocupa a lo mas una posicion y una posicion la ocupa a lo mas
--     un equipo: cambiar de lugar cierra el periodo anterior de ambos.
--   · SEL_ACTIVO_POSICION_HISTORIAL: los periodos, con equipo, motivo y OT.
--   · SEL_ETIQUETA gana el origen POSICION (token POS-<id>) y Etiqueta_Origen
--     la tarjeta en el centro de etiquetas (HU-034).
--   · Permisos VER POSICIONES / CREAR EDITAR POSICIONES, menus, funcion.
-- =============================================

/* ---------- 1. Codigo automatico ---------- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Activo_Posicion')
    INSERT [dbo].[Modulo_Codigo] (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento, mco_habilitado)
    VALUES ('Activo_Posicion', 'POS', 'apo_codigo', 'apo_id', 'INS_ACTIVO_POSICION', 1)
GO

/* Codigo unico por cliente (HU-033 #1): el mismo CB01 puede existir en dos
   empresas distintas, nunca dos veces en la misma. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_APO_CLIENTE_CODIGO')
    CREATE UNIQUE INDEX UX_APO_CLIENTE_CODIGO ON [dbo].[Activo_Posicion] (apo_cliente, apo_codigo)
GO


/* La app encola la asignacion con uuid (patron 209/226): el reintento del
   telefono no crea un segundo periodo. */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Activo_Posicion_Historial]') AND name = 'aph_uuid')
    ALTER TABLE [dbo].[Activo_Posicion_Historial] ADD aph_uuid UNIQUEIDENTIFIER NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('[dbo].[Activo_Posicion_Historial]') AND name = 'UQ_APH_UUID')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_APH_UUID ON [dbo].[Activo_Posicion_Historial](aph_uuid) WHERE aph_uuid IS NOT NULL
GO


/* ---------- 2. SEL ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_POSICION]
@ID           INT = NULL,
@CLIENTE      INT = NULL,
@INSTALACION  INT = NULL,
@AREA         INT = NULL,
@ACTIVO_TIPO  INT = NULL,
@HABILITADO   BIT = NULL,
@LIBRE        BIT = NULL,
@FILTRO       NVARCHAR(200) = NULL

AS
SET NOCOUNT ON

    SELECT  p.apo_id                        AS APO_ID
           ,p.apo_cliente                   AS APO_CLIENTE
           ,p.apo_cliente_instalacion       AS APO_CLIENTE_INSTALACION
           ,p.apo_instalacion_area          AS APO_INSTALACION_AREA
           ,p.apo_activo_tipo               AS APO_ACTIVO_TIPO
           ,p.apo_codigo                    AS APO_CODIGO
           ,p.apo_nombre                    AS APO_NOMBRE
           ,p.apo_critica                   AS APO_CRITICA
           ,p.apo_descripcion               AS APO_DESCRIPCION
           ,p.apo_usuario_creacion          AS APO_USUARIO_CREACION
           ,p.apo_fecha_creacion            AS APO_FECHA_CREACION
           ,p.apo_usuario_actualizacion     AS APO_USUARIO_ACTUALIZACION
           ,p.apo_fecha_actualizacion       AS APO_FECHA_ACTUALIZACION
           ,p.apo_habilitado                AS APO_HABILITADO
           ,ci.cin_nombre                   AS PLANTA_NOMBRE
           ,ar.iar_codigo                   AS AREA_CODIGO
           ,ar.iar_nombre                   AS AREA_NOMBRE
           ,t.ati_nombre                    AS TIPO_NOMBRE
           ,a.act_id                        AS ACTIVO_ID
           ,a.act_codigo                    AS ACTIVO_CODIGO
           ,a.act_nombre                    AS ACTIVO_NOMBRE
           ,h.aph_fecha_inicio_utc          AS OCUPADA_DESDE_UTC
           ,CAST(h.aph_fecha_inicio_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS OCUPADA_DESDE
           ,(SELECT COUNT(*) FROM [dbo].[Activo_Posicion_Historial] x WHERE x.aph_activo_posicion = p.apo_id) AS PERIODOS
           ,uc.usu_nombre + ' ' + ISNULL(uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE
           ,ua.usu_nombre + ' ' + ISNULL(ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Activo_Posicion] p
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = p.apo_cliente_instalacion
    LEFT JOIN [dbo].[Instalacion_Area]    ar ON ar.iar_id = p.apo_instalacion_area
    LEFT JOIN [dbo].[Activo_Tipo]         t  ON t.ati_id  = p.apo_activo_tipo
    LEFT JOIN [dbo].[Activo]              a  ON a.act_activo_posicion = p.apo_id
                                             AND a.act_habilitado = 1 AND a.act_fusionado_en IS NULL
    LEFT JOIN [dbo].[Activo_Posicion_Historial] h ON h.aph_activo_posicion = p.apo_id
                                             AND h.aph_activo = a.act_id AND h.aph_fecha_fin_utc IS NULL
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.apo_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.apo_usuario_actualizacion
    WHERE   (@ID IS NULL          OR p.apo_id = @ID)
      AND   (@CLIENTE IS NULL     OR p.apo_cliente = @CLIENTE)
      AND   (@INSTALACION IS NULL OR p.apo_cliente_instalacion = @INSTALACION)
      AND   (@AREA IS NULL        OR p.apo_instalacion_area = @AREA)
      AND   (@ACTIVO_TIPO IS NULL OR p.apo_activo_tipo = @ACTIVO_TIPO)
      AND   (@HABILITADO IS NULL  OR p.apo_habilitado = @HABILITADO)
      AND   (@LIBRE IS NULL       OR (@LIBRE = 1 AND a.act_id IS NULL) OR (@LIBRE = 0 AND a.act_id IS NOT NULL))
      AND   (@FILTRO IS NULL      OR p.apo_codigo LIKE '%' + @FILTRO + '%'
                                  OR p.apo_nombre LIKE '%' + @FILTRO + '%'
                                  OR ar.iar_nombre LIKE '%' + @FILTRO + '%'
                                  OR a.act_codigo LIKE '%' + @FILTRO + '%'
                                  OR a.act_nombre LIKE '%' + @FILTRO + '%')
    ORDER BY ci.cin_nombre, ar.iar_codigo, p.apo_codigo

RETURN(0)
GO


/* ---------- 3. INS ---------- */
CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_POSICION]
@ID           INT = NULL OUTPUT,
@CLIENTE      INT,
@INSTALACION  INT,
@AREA         INT,
@ACTIVO_TIPO  INT = NULL,
@CODIGO       NVARCHAR(50),
@NOMBRE       NVARCHAR(200),
@CRITICA      BIT = 0,
@DESCRIPCION  NVARCHAR(500) = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF (@CODIGO IS NULL OR LEN(@CODIGO) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CÓDIGO DE LA POSICIÓN.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                    WHERE iar_id = @AREA AND iar_cliente_instalacion = @INSTALACION)
    BEGIN
        RAISERROR('3.- EL ÁREA NO PERTENECE A ESA PLANTA.', 16, 1)
        RETURN -1
    END

    -- HU-033 #1: codigo unico dentro del cliente
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion]
                WHERE apo_cliente = @CLIENTE AND apo_codigo = @CODIGO)
    BEGIN
        RAISERROR('4.- YA EXISTE UNA POSICIÓN CON EL CÓDIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @ACTIVO_TIPO IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                        WHERE ati_id = @ACTIVO_TIPO AND (ati_cliente = @CLIENTE OR ati_cliente IS NULL))
    BEGIN
        RAISERROR('5.- EL TIPO DE ACTIVO NO EXISTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo_Posicion]
        (apo_cliente, apo_cliente_instalacion, apo_instalacion_area, apo_activo_tipo,
         apo_codigo, apo_nombre, apo_critica, apo_descripcion,
         apo_usuario_creacion, apo_fecha_creacion, apo_usuario_actualizacion, apo_fecha_actualizacion, apo_habilitado)
    VALUES
        (@CLIENTE, @INSTALACION, @AREA, @ACTIVO_TIPO,
         @CODIGO, LTRIM(RTRIM(@NOMBRE)), ISNULL(@CRITICA, 0), @DESCRIPCION,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    /* ---- CODIGO AUTOMATICO (bloque 77): la ficha manda AUTO y el codigo
       nace del ID, que no existe hasta esta linea. */
    IF (UPPER(@CODIGO) = 'AUTO')
        UPDATE [dbo].[Activo_Posicion]
        SET    apo_codigo = [dbo].[FNC_CODIGO_AUTOMATICO]('POS', @ID)
        WHERE  apo_id = @ID

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO_POSICION @CLIENTE = ' + LTRIM(STR(@CLIENTE)) + ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '6.- NO FUE POSIBLE INSERTAR LA POSICIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ---------- 4. UPD ---------- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_POSICION]
@ID           INT,
@AREA         INT = NULL,
@ACTIVO_TIPO  INT = NULL,
@QUITA_TIPO   BIT = 0,
@NOMBRE       NVARCHAR(200) = NULL,
@CRITICA      BIT = NULL,
@DESCRIPCION  NVARCHAR(500) = NULL,
@HABILITADO   BIT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @INSTALACION INT

SELECT @CLIENTE = apo_cliente, @INSTALACION = apo_cliente_instalacion
FROM   [dbo].[Activo_Posicion] WHERE apo_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA POSICIÓN NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El codigo NO se edita: esta impreso en la etiqueta pegada en la sala. */
IF @AREA IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                    WHERE iar_id = @AREA AND iar_cliente_instalacion = @INSTALACION)
BEGIN
    RAISERROR('2.- EL ÁREA NO PERTENECE A LA PLANTA DE LA POSICIÓN.', 16, 1)
    RETURN -1
END

/* Deshabilitar una posicion ocupada dejaria al equipo apuntando a un lugar
   que ya no existe: primero se libera. */
IF @HABILITADO = 0
   AND EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_activo_posicion = @ID AND act_habilitado = 1)
BEGIN
    RAISERROR('3.- LA POSICIÓN ESTÁ OCUPADA. LIBERE EL EQUIPO ANTES DE DESHABILITARLA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Posicion]
    SET     apo_instalacion_area      = ISNULL(@AREA, apo_instalacion_area)
           ,apo_activo_tipo           = CASE WHEN @QUITA_TIPO = 1 THEN NULL ELSE ISNULL(@ACTIVO_TIPO, apo_activo_tipo) END
           ,apo_nombre                = ISNULL(LTRIM(RTRIM(@NOMBRE)), apo_nombre)
           ,apo_critica               = ISNULL(@CRITICA, apo_critica)
           ,apo_descripcion           = ISNULL(@DESCRIPCION, apo_descripcion)
           ,apo_habilitado            = ISNULL(@HABILITADO, apo_habilitado)
           ,apo_usuario_actualizacion = @USUARIO
           ,apo_fecha_actualizacion   = @DATE_NOW
    WHERE   apo_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ACTIVO_POSICION @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA POSICIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ---------- 5. DEL ---------- */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_POSICION]
@ID INT

AS
SET NOCOUNT ON

/* Con historia no se borra: la etiqueta pudo imprimirse y los periodos son
   trazabilidad. Se deshabilita. */
IF EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Historial] WHERE aph_activo_posicion = @ID)
   OR EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_activo_posicion = @ID)
BEGIN
    RAISERROR('1.- LA POSICIÓN YA FUE OCUPADA POR ALGÚN EQUIPO. DESHABILÍTELA EN VEZ DE ELIMINARLA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    DELETE [dbo].[Activo_Posicion] WHERE apo_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('2.- LA POSICIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ---------- 6. Historial de ocupacion (HU-033 #2) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_POSICION_HISTORIAL]
@POSICION  INT = NULL,
@ACTIVO    INT = NULL,
@CLIENTE   INT = NULL

AS
SET NOCOUNT ON

    SELECT  h.aph_id                     AS APH_ID
           ,h.aph_activo_posicion        AS APH_ACTIVO_POSICION
           ,h.aph_activo                 AS APH_ACTIVO
           ,h.aph_fecha_inicio_utc       AS APH_FECHA_INICIO_UTC
           ,h.aph_fecha_fin_utc          AS APH_FECHA_FIN_UTC
           /* Las mismas fechas en la hora de la plataforma (Santiago), para
              mostrarlas: el registro es UTC, la pantalla es de personas. */
           ,CAST(h.aph_fecha_inicio_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS APH_FECHA_INICIO
           ,CAST(h.aph_fecha_fin_utc    AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS APH_FECHA_FIN
           ,h.aph_activo_posicion_motivo AS APH_ACTIVO_POSICION_MOTIVO
           ,h.aph_orden_trabajo          AS APH_ORDEN_TRABAJO
           ,h.aph_observacion            AS APH_OBSERVACION
           ,h.aph_usuario_creacion       AS APH_USUARIO_CREACION
           ,h.aph_fecha_creacion         AS APH_FECHA_CREACION
           ,p.apo_codigo                 AS POSICION_CODIGO
           ,p.apo_nombre                 AS POSICION_NOMBRE
           ,a.act_codigo                 AS ACTIVO_CODIGO
           ,a.act_nombre                 AS ACTIVO_NOMBRE
           ,m.apm_nombre                 AS MOTIVO_NOMBRE
           ,ot.otr_correlativo           AS OT_CORRELATIVO
           ,u.usu_nombre + ' ' + ISNULL(u.usu_apellido_paterno, '') AS USUARIO_NOMBRE
           ,CASE WHEN h.aph_fecha_fin_utc IS NULL THEN 1 ELSE 0 END AS VIGENTE
           ,DATEDIFF(DAY, h.aph_fecha_inicio_utc, ISNULL(h.aph_fecha_fin_utc, GETUTCDATE())) AS DIAS
    FROM    [dbo].[Activo_Posicion_Historial] h
    JOIN    [dbo].[Activo_Posicion] p ON p.apo_id = h.aph_activo_posicion
    JOIN    [dbo].[Activo]          a ON a.act_id = h.aph_activo
    LEFT JOIN [dbo].[Activo_Posicion_Motivo] m ON m.apm_id = h.aph_activo_posicion_motivo
    LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = h.aph_orden_trabajo
    LEFT JOIN [dbo].[Usuario]       u  ON u.usu_id = h.aph_usuario_creacion
    WHERE   (@POSICION IS NULL OR h.aph_activo_posicion = @POSICION)
      AND   (@ACTIVO IS NULL   OR h.aph_activo = @ACTIVO)
      AND   (@CLIENTE IS NULL  OR h.aph_cliente = @CLIENTE)
    ORDER BY h.aph_fecha_inicio_utc DESC

RETURN(0)
GO


/* ---------- 7. Ocupar una posicion ---------- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_POSICION_OCUPAR]
@POSICION       INT,
@ACTIVO         INT,
@MOTIVO         INT = NULL,
@OBSERVACION    NVARCHAR(500) = NULL,
@ORDEN_TRABAJO  INT = NULL,
@USUARIO        INT,
@UUID           UNIQUEIDENTIFIER = NULL

AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @INSTALACION INT, @TIPO_POS INT, @TIPO_ACT INT, @ACT_INST INT, @ACT_POS INT
       ,@OCUPANTE INT, @AHORA DATETIME = GETUTCDATE(), @TIPO_NOMBRE NVARCHAR(200)

-- Idempotencia: ANTES de toda validacion (patron 209). El reintento del telefono responde lo mismo.
IF @UUID IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Historial] WHERE aph_uuid = @UUID)
BEGIN
    SELECT h.aph_id AS APH_ID, h.aph_activo_posicion AS POSICION, h.aph_activo AS ACTIVO
    FROM   [dbo].[Activo_Posicion_Historial] h WHERE h.aph_uuid = @UUID
    RETURN 0
END

SELECT @CLIENTE = apo_cliente, @INSTALACION = apo_cliente_instalacion, @TIPO_POS = apo_activo_tipo
FROM   [dbo].[Activo_Posicion] WHERE apo_id = @POSICION AND apo_habilitado = 1

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA POSICIÓN NO EXISTE O ESTÁ DESHABILITADA.', 16, 1)
    RETURN -1
END

SELECT @ACT_INST = act_cliente_instalacion, @TIPO_ACT = act_activo_tipo, @ACT_POS = act_activo_posicion
FROM   [dbo].[Activo]
WHERE  act_id = @ACTIVO AND act_cliente = @CLIENTE AND act_habilitado = 1 AND act_fusionado_en IS NULL

IF @ACT_INST IS NULL
BEGIN
    RAISERROR('2.- EL EQUIPO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ACT_INST <> @INSTALACION
BEGIN
    RAISERROR('3.- EL EQUIPO ES DE OTRA PLANTA. UNA POSICIÓN SOLO RECIBE EQUIPOS DE SU PLANTA.', 16, 1)
    RETURN -1
END

/* La posicion puede declarar que tipo de maquina admite: un QR en la sala
   de blowers no deberia terminar apuntando a un horno. */
IF @TIPO_POS IS NOT NULL AND @TIPO_ACT <> @TIPO_POS
BEGIN
    SELECT @TIPO_NOMBRE = ati_nombre FROM [dbo].[Activo_Tipo] WHERE ati_id = @TIPO_POS
    RAISERROR('4.- ESTA POSICIÓN ADMITE EQUIPOS DEL TIPO "%s".', 16, 1, @TIPO_NOMBRE)
    RETURN -1
END

IF @ACT_POS = @POSICION
BEGIN
    RAISERROR('5.- EL EQUIPO YA OCUPA ESTA POSICIÓN.', 16, 1)
    RETURN -1
END

IF @MOTIVO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE apm_id = @MOTIVO AND apm_habilitado = 1)
BEGIN
    RAISERROR('6.- EL MOTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

/* Sin motivo explicito: la primera vez es instalacion inicial; despues,
   reemplazo. */
IF @MOTIVO IS NULL
    SET @MOTIVO = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Historial] WHERE aph_activo_posicion = @POSICION)
                       THEN 2 ELSE 1 END

BEGIN TRANSACTION

    /* Quien estaba en la posicion, sale: se cierra su periodo. */
    SELECT @OCUPANTE = act_id FROM [dbo].[Activo]
    WHERE  act_activo_posicion = @POSICION AND act_id <> @ACTIVO

    IF @OCUPANTE IS NOT NULL
    BEGIN
        UPDATE [dbo].[Activo_Posicion_Historial]
        SET    aph_fecha_fin_utc = @AHORA
        WHERE  aph_activo_posicion = @POSICION AND aph_activo = @OCUPANTE AND aph_fecha_fin_utc IS NULL

        UPDATE [dbo].[Activo] SET act_activo_posicion = NULL WHERE act_id = @OCUPANTE
    END

    /* Y si el equipo venia de otra posicion, tambien se cierra ese periodo. */
    IF @ACT_POS IS NOT NULL
        UPDATE [dbo].[Activo_Posicion_Historial]
        SET    aph_fecha_fin_utc = @AHORA
        WHERE  aph_activo = @ACTIVO AND aph_fecha_fin_utc IS NULL

    INSERT [dbo].[Activo_Posicion_Historial]
        (aph_uuid, aph_cliente, aph_activo_posicion, aph_activo, aph_fecha_inicio_utc, aph_fecha_fin_utc,
         aph_activo_posicion_motivo, aph_orden_trabajo, aph_observacion, aph_usuario_creacion, aph_fecha_creacion)
    VALUES
        (@UUID, @CLIENTE, @POSICION, @ACTIVO, @AHORA, NULL,
         @MOTIVO, @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

    DECLARE @APH INT = SCOPE_IDENTITY()

    UPDATE [dbo].[Activo]
    SET    act_activo_posicion = @POSICION
          ,act_usuario_actualizacion = @USUARIO
          ,act_fecha_actualizacion = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))
    WHERE  act_id = @ACTIVO

COMMIT TRANSACTION

/* La API devuelve el periodo creado: el telefono lo guarda como acuse. */
SELECT @APH AS APH_ID, @POSICION AS POSICION, @ACTIVO AS ACTIVO

RETURN(0)
GO


/* ---------- 8. Liberar una posicion ---------- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_POSICION_LIBERAR]
@POSICION     INT,
@MOTIVO       INT = NULL,
@OBSERVACION  NVARCHAR(500) = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @OCUPANTE INT, @CLIENTE INT, @AHORA DATETIME = GETUTCDATE()

SELECT @CLIENTE = apo_cliente FROM [dbo].[Activo_Posicion] WHERE apo_id = @POSICION
IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA POSICIÓN NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @OCUPANTE = act_id FROM [dbo].[Activo] WHERE act_activo_posicion = @POSICION
IF @OCUPANTE IS NULL
BEGIN
    RAISERROR('2.- LA POSICIÓN YA ESTÁ LIBRE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Activo_Posicion_Historial]
    SET    aph_fecha_fin_utc = @AHORA
          ,aph_observacion = CASE WHEN @OBSERVACION IS NULL THEN aph_observacion
                                  ELSE ISNULL(aph_observacion + ' · ', '') + 'Salida: ' + @OBSERVACION END
          ,aph_activo_posicion_motivo = ISNULL(@MOTIVO, aph_activo_posicion_motivo)
    WHERE  aph_activo_posicion = @POSICION AND aph_activo = @OCUPANTE AND aph_fecha_fin_utc IS NULL

    UPDATE [dbo].[Activo]
    SET    act_activo_posicion = NULL
          ,act_usuario_actualizacion = @USUARIO
          ,act_fecha_actualizacion = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))
    WHERE  act_id = @OCUPANTE

COMMIT TRANSACTION

RETURN(0)
GO


/* ---------- 8b. Motivos de ocupacion (catalogo del bloque 11) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_POSICION_MOTIVO]
@HABILITADO BIT = NULL
AS
SET NOCOUNT ON
    SELECT apm_id AS APM_ID, apm_codigo AS APM_CODIGO, apm_nombre AS APM_NOMBRE, apm_orden AS APM_ORDEN, apm_habilitado AS APM_HABILITADO
    FROM   [dbo].[Activo_Posicion_Motivo]
    WHERE  (@HABILITADO IS NULL OR apm_habilitado = @HABILITADO)
    ORDER BY apm_orden
RETURN(0)
GO


/* ---------- 9. Etiqueta QR (HU-034) ----------
   Mismo mecanismo que el bloque 76: se parchea la definicion vigente de
   SEL_ETIQUETA con la rama nueva, sin reescribir el SP entero. Idempotente:
   si ya conoce POS-, no hace nada. */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_ETIQUETA'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%POS-%'
BEGIN
    SET @SQL = REPLACE(@SQL,
'ELSE
BEGIN
    RAISERROR(''1.- ORIGEN DE ETIQUETA DESCONOCIDO.'', 16, 1)',
'/* ---- Una posicion funcional (HU-034) ----
   La etiqueta va pegada en la sala, no en la maquina: el QR codifica la
   POSICION (POS-<id>), que sigue siendo la misma aunque se cambie el equipo.
   El activo que la ocupa hoy va como detalle informativo. */
ELSE IF (@ORIGEN = ''POSICION'')
    SELECT  ''POS-'' + LTRIM(STR(p.apo_id))    AS TOKEN,
            p.apo_id                          AS ID,
            p.apo_codigo                      AS CODIGO,
            p.apo_nombre                      AS TITULO,
            ISNULL(ar.iar_codigo + '' · '' + ar.iar_nombre, '''') AS SUBTITULO,
            ISNULL(a.act_codigo + '' · '' + a.act_nombre, ''Sin equipo asignado'') AS DETALLE,
            ISNULL(ci.cin_nombre, ''Posición'') AS PIE
    FROM    [dbo].[Activo_Posicion] p
    LEFT JOIN [dbo].[Instalacion_Area]     ar ON ar.iar_id = p.apo_instalacion_area
    LEFT JOIN [dbo].[Cliente_Instalacion]  ci ON ci.cin_id = p.apo_cliente_instalacion
    LEFT JOIN [dbo].[Activo]               a  ON a.act_activo_posicion = p.apo_id AND a.act_habilitado = 1 AND a.act_fusionado_en IS NULL
    WHERE   p.apo_cliente = @CLIENTE
      AND   p.apo_habilitado = 1
      AND   (@HAY = 0 OR p.apo_id IN (SELECT ID FROM @LISTA))
    ORDER BY p.apo_codigo

ELSE
BEGIN
    RAISERROR(''1.- ORIGEN DE ETIQUETA DESCONOCIDO.'', 16, 1)')

    IF @SQL LIKE '%CREATE OR ALTER PROCEDURE%'
        SET @SQL = REPLACE(@SQL, 'CREATE OR ALTER PROCEDURE', 'ALTER PROCEDURE')
    ELSE
        SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_ETIQUETA aprende el origen POSICION'
END
ELSE PRINT '--- SEL_ETIQUETA ya conocia POSICION'
GO


/* ---------- 10. Permisos, menus, funcion, perfiles (patron del bloque 76) ---------- */
DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT, nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES
    (N'VER POSICIONES',          N'Ver las posiciones funcionales',  N'ACTIVOS', 3),
    (N'CREAR EDITAR POSICIONES', N'Crear y editar posiciones y asignarles equipos', N'ACTIVOS', 1)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, [dbo].[FNC_AHORA](), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Activos' AND mnu_nivel = 2

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Posiciones',          N'~/View/Activos/Posiciones/Posiciones.aspx', 4,  1, N'mdi mdi-map-marker-radius-outline', N'VER POSICIONES'),
    (N'Posición (detalle)',  N'~/View/Activos/Posiciones/Posicion.aspx',   99, 0, NULL,                                 N'VER POSICIONES')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, N'Lugares fijos de cada área por los que pasan los equipos', 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)
GO

DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES
    (N'~/View/Activos/Posiciones/Posiciones.aspx', N'Crear y editar', N'CREAR EDITAR POSICIONES')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT  m.mnu_id, f.funcion, p.prm_id
FROM    @F f
JOIN    [dbo].[Menus]   m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN    [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu = m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT = f.funcion)
GO

DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (1,  N'VER POSICIONES'), (1,  N'CREAR EDITAR POSICIONES'),
    (10, N'VER POSICIONES'), (10, N'CREAR EDITAR POSICIONES'),
    (5,  N'VER POSICIONES'), (5,  N'CREAR EDITAR POSICIONES'),
    (11, N'VER POSICIONES'), (11, N'CREAR EDITAR POSICIONES'),
    (12, N'VER POSICIONES'),
    (13, N'VER POSICIONES'),
    (4,  N'VER POSICIONES')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  pp.perfil, p.prm_id, 1, [dbo].[FNC_AHORA]()
FROM    @PP pp
JOIN    [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.perfil AND x.ppe_permiso = p.prm_id)
GO

/* La tarjeta en el centro de etiquetas. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Etiqueta_Origen] WHERE eto_codigo = 'POSICION')
    INSERT [dbo].[Etiqueta_Origen] (eto_codigo, eto_nombre, eto_descripcion, eto_icono, eto_permiso, eto_orden, eto_por_bodega, eto_habilitado)
    VALUES ('POSICION', 'Posiciones', 'Una por posición, para pegar en la sala: el QR codifica el lugar, no la máquina, así que sigue sirviendo cuando el equipo cambia.',
            'mdi mdi-map-marker-radius-outline', (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER POSICIONES'), 6, 0, 1)
GO

PRINT '--- Posiciones funcionales: SP, etiqueta, permisos y menus listos'
GO
