/* ============================================================================
   SIGMA — Bloque 101
   PROCEDIMIENTOS Y SUS PASOS                                 HU-061 · HU-062
   ----------------------------------------------------------------------------

   QUE ES UN PROCEDIMIENTO

     La receta de un trabajo: "cambio de rodamientos de un motor", con sus
     pasos en orden. Se escribe una vez y se reutiliza en cada plan y en cada
     orden que lo necesite, en vez de que cada técnico recuerde los pasos.

   TRES COSAS QUE EL MODELO YA DECIDIO Y HAY QUE RESPETAR

     1. EL CODIGO NO ES UNICO POR CLIENTE: LO ES POR CLIENTE **Y VERSION**

        `UX_PRC_CLIENTE_CODIGO` es (prc_cliente, prc_codigo, prc_version), y
        hay un segundo indice `UX_PRC_GLOBAL_CODIGO` (codigo, version) para
        los procedimientos globales —los de cliente NULL—.

        O sea que el mismo procedimiento existe varias veces, una por
        version. Y tiene sentido: una orden ejecutada el año pasado siguio la
        version 1, y reescribirla ahora falsearia lo que realmente se hizo.

        T-3201 pedia "confirmar el indice unico del codigo dentro del
        cliente". Confirmado, y es mas que eso: la version es parte de la
        llave.

     2. EL CODIGO NO SE GENERA SOLO, Y ES POR LA VERSION

        El bloque 77 genera `XXX-<id>` para los modulos con codigo. Aca no
        sirve: la version 2 de un procedimiento es OTRA fila con OTRO id,
        asi que el codigo automatico le daria un codigo distinto y dejarian
        de ser el mismo procedimiento.

        El codigo lo escribe quien crea el procedimiento —es como lo van a
        llamar— y al versionar se COPIA. `Procedimiento` no se agrega a
        `Modulo_Codigo` a proposito.

     3. UN PASO QUE MIDE TIENE QUE DECIR QUE MIDE

        `CK_PPA_MEDICION`: requiere_medicion = 0 OR variable_medicion IS NOT
        NULL. Es la misma forma que `CK_PTR_AUTORIZADO` en permisos de
        trabajo: la tabla impide guardar una afirmacion incompleta.

        Y `Variable_Medicion` estaba VACIA, asi que sin sembrarla ese camino
        no se puede ejercitar. Se siembran siete variables globales: es el
        mismo caso que los modelos de activo en HU-051.

   EL ORDEN DE LOS PASOS ES UNICO

     `UX_PPA_PROCEDIMIENTO_ORDEN` (procedimiento, orden) impide dos pasos con
     el mismo numero. Insertar uno en medio obliga a correr los de abajo, y
     eso lo resuelve `INS_PROCEDIMIENTO_PASO` sin que la pantalla tenga que
     saberlo.

   ORDEN: despues de 100_LOGO_Y_FOTO_A_BLOB.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. VARIABLES DE MEDICION                                    apoyo T-3288

      Sin ellas `ppa_requiere_medicion = 1` es imposible: el CHECK lo impide.
      Se crean GLOBALES (cliente NULL) porque temperatura y vibracion no son
      de una empresa.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Variable_Medicion] WHERE vme_cliente IS NULL)
BEGIN
    DECLARE @DEC INT, @ENT INT

    SELECT @DEC = tda_id FROM [dbo].[Tipo_Dato] WHERE tda_codigo = 'DECIMAL'
    SELECT @ENT = tda_id FROM [dbo].[Tipo_Dato] WHERE tda_codigo = 'ENTERO'

    INSERT INTO [dbo].[Variable_Medicion]
        (vme_cliente, vme_unidad_medida, vme_tipo_dato, vme_codigo, vme_nombre,
         vme_decimales, vme_relevante_ia, vme_permite_manual, vme_permite_sensor,
         vme_descripcion, vme_usuario_creacion, vme_fecha_creacion, vme_habilitado)
    SELECT NULL, u.ume_id, v.TDA, v.COD, v.NOM, v.DEC_, v.IA, 1, v.SENSOR, v.DESC_,
           1, GETDATE(), 1
    FROM (VALUES
        ('TEMPERATURA',  'Temperatura',        'CELSIUS', @DEC, 1, 1, 1, N'Temperatura de carcasa, aceite o devanado.'),
        ('VIBRACION',    'Vibración',          'UNIDAD',  @DEC, 2, 1, 1, N'Velocidad de vibración RMS. Unidad real mm/s.'),
        ('PRESION',      'Presión',            'UNIDAD',  @DEC, 2, 1, 1, N'Presión de trabajo. Unidad real bar.'),
        ('CORRIENTE',    'Corriente',          'UNIDAD',  @DEC, 2, 1, 1, N'Consumo en amperes.'),
        ('HORAS',        'Horas de marcha',    'HORA',    @ENT, 0, 1, 1, N'Lectura del horómetro.'),
        ('NIVEL ACEITE', 'Nivel de aceite',    'UNIDAD',  @DEC, 1, 0, 0, N'Nivel en la mirilla, como porcentaje.'),
        ('HOLGURA',      'Holgura',            'UNIDAD',  @DEC, 2, 1, 0, N'Juego medido con lainas o comparador.')
    ) AS v(COD, NOM, UNIDAD, TDA, DEC_, IA, SENSOR, DESC_)
    JOIN [dbo].[Unidad_Medida] u ON u.ume_codigo = v.UNIDAD

    PRINT '--- Variables de medicion globales creadas: ' + LTRIM(STR(@@ROWCOUNT))
END
ELSE PRINT '--- Ya hay variables de medicion globales.'
GO

IF OBJECT_ID('dbo.SEL_VARIABLE_MEDICION') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_VARIABLE_MEDICION]
GO

CREATE PROCEDURE [dbo].[SEL_VARIABLE_MEDICION]
    @CLIENTE    INT,
    @HABILITADO BIT = 1
AS
SET NOCOUNT ON

    /* Las globales y las del cliente juntas: filtrar solo por el cliente
       esconderia temperatura y vibracion, que son las que sirven siempre. */
    SELECT  v.vme_id                                  AS VME_ID,
            v.vme_cliente                             AS VME_CLIENTE,
            v.vme_codigo                              AS VME_CODIGO,
            v.vme_nombre                              AS VME_NOMBRE,
            v.vme_decimales                           AS VME_DECIMALES,
            ISNULL(u.ume_simbolo, '')                 AS UNIDAD,
            ISNULL(t.tda_nombre, '')                  AS TIPO_DATO,
            CAST(CASE WHEN v.vme_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            v.vme_nombre + ISNULL(' (' + NULLIF(u.ume_simbolo, '') + ')', '') AS ETIQUETA
    FROM    [dbo].[Variable_Medicion] v
    LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = v.vme_unidad_medida
    LEFT JOIN [dbo].[Tipo_Dato] t     ON t.tda_id  = v.vme_tipo_dato
    WHERE   (v.vme_cliente IS NULL OR v.vme_cliente = @CLIENTE)
      AND   (@HABILITADO IS NULL OR v.vme_habilitado = @HABILITADO)
    ORDER BY v.vme_nombre
GO

PRINT '--- SEL_VARIABLE_MEDICION creado.'
GO


/* ========================================================================
   2. INDICES DE APOYO                                  T-3201 · T-3283
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_PRC_CLIENTE_HABILITADO'
                  AND object_id = OBJECT_ID('dbo.Procedimiento'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PRC_CLIENTE_HABILITADO
        ON [dbo].[Procedimiento] ([prc_cliente], [prc_habilitado])
        INCLUDE ([prc_codigo], [prc_nombre], [prc_version], [prc_activo_tipo])

    PRINT '--- IX_PRC_CLIENTE_HABILITADO creado.'
END
ELSE PRINT '--- IX_PRC_CLIENTE_HABILITADO ya existe.'
GO


/* ========================================================================
   3. SEL_PROCEDIMIENTO                                             T-3202
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROCEDIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROCEDIMIENTO]
GO

CREATE PROCEDURE [dbo].[SEL_PROCEDIMIENTO]
    @CLIENTE      INT,
    @ID           INT = NULL,
    @FILTRO       VARCHAR(200) = NULL,
    @HABILITADO   BIT = NULL,
    @ACTIVO_TIPO  INT = NULL,
    @SOLO_ULTIMA  BIT = 0
AS
SET NOCOUNT ON

    ;WITH BASE AS (
        SELECT  p.prc_id,
                p.prc_cliente,
                p.prc_codigo,
                p.prc_nombre,
                p.prc_version,
                p.prc_activo_tipo,
                ISNULL(p.prc_descripcion, '')            AS prc_descripcion,
                p.prc_duracion_estimada_minuto,
                p.prc_requiere_permiso,
                p.prc_permiso_trabajo_tipo,
                p.prc_habilitado,
                p.prc_usuario_creacion,
                p.prc_fecha_creacion,
                p.prc_usuario_actualizacion,
                p.prc_fecha_actualizacion,

                ISNULL(at.ati_nombre, '')                AS ACTIVO_TIPO_NOMBRE,
                ISNULL(pt.ptt_nombre, '')                AS PERMISO_TIPO_NOMBRE,
                CAST(CASE WHEN p.prc_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,

                ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
                ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,

                (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s
                  WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1) AS PASOS,

                /* La ultima version de ESE codigo, para poder marcar cual es
                   la vigente sin que la pantalla tenga que compararlas. */
                MAX(p.prc_version) OVER (PARTITION BY ISNULL(p.prc_cliente, 0), p.prc_codigo) AS VERSION_MAXIMA
        FROM    [dbo].[Procedimiento] p
        LEFT JOIN [dbo].[Activo_Tipo] at          ON at.ati_id  = p.prc_activo_tipo
        LEFT JOIN [dbo].[Permiso_Trabajo_Tipo] pt ON pt.ptt_id  = p.prc_permiso_trabajo_tipo
        LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.prc_usuario_creacion
        LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.prc_usuario_actualizacion
        /* Los globales -cliente NULL- valen para todos. */
        WHERE   (p.prc_cliente IS NULL OR p.prc_cliente = @CLIENTE)
          AND   (@ID          IS NULL OR p.prc_id          = @ID)
          AND   (@HABILITADO  IS NULL OR p.prc_habilitado  = @HABILITADO)
          AND   (@ACTIVO_TIPO IS NULL OR p.prc_activo_tipo = @ACTIVO_TIPO)
          AND   (@FILTRO IS NULL
                 OR p.prc_codigo      LIKE '%' + @FILTRO + '%'
                 OR p.prc_nombre      LIKE '%' + @FILTRO + '%'
                 OR p.prc_descripcion LIKE '%' + @FILTRO + '%')
    )
    SELECT  b.*,
            CAST(CASE WHEN b.prc_version = b.VERSION_MAXIMA THEN 1 ELSE 0 END AS BIT) AS ES_ULTIMA
    FROM    BASE b
    /* Con @SOLO_ULTIMA se ve el catalogo vigente; sin el, todas las
       versiones, que es lo que hace falta para auditar que se ejecuto. */
    WHERE   (@SOLO_ULTIMA = 0 OR b.prc_version = b.VERSION_MAXIMA)
    ORDER BY b.prc_codigo, b.prc_version DESC
GO

PRINT '--- SEL_PROCEDIMIENTO creado.'
GO


/* ========================================================================
   4. INS_PROCEDIMIENTO                                             T-3203
   ======================================================================== */
IF OBJECT_ID('dbo.INS_PROCEDIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROCEDIMIENTO]
GO

CREATE PROCEDURE [dbo].[INS_PROCEDIMIENTO]
    @ID              INT OUTPUT,
    @CLIENTE         INT,
    @CODIGO          NVARCHAR(100),
    @NOMBRE          NVARCHAR(400),
    @VERSION         INT = 1,
    @ACTIVO_TIPO     INT = NULL,
    @DESCRIPCION     NVARCHAR(MAX) = NULL,
    @DURACION        INT = NULL,
    @REQUIERE_PERMISO BIT = 0,
    @PERMISO_TIPO    INT = NULL,
    @USUARIO         INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))
SET @VERSION = ISNULL(@VERSION, 1)

IF (@CODIGO IS NULL OR LEN(@CODIGO) = 0)
BEGIN
    RAISERROR('1.- INDIQUE EL CODIGO DEL PROCEDIMIENTO.', 16, 1)
    RETURN -1
END

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN
    RAISERROR('2.- INDIQUE EL NOMBRE DEL PROCEDIMIENTO.', 16, 1)
    RETURN -1
END

IF (@VERSION < 1)
BEGIN
    RAISERROR('3.- LA VERSION EMPIEZA EN 1.', 16, 1)
    RETURN -1
END

/* La llave es (cliente, codigo, VERSION): el mismo codigo puede repetirse en
   otra version, y eso es lo que permite conservar lo que se ejecuto. */
IF EXISTS (SELECT 1 FROM [dbo].[Procedimiento]
            WHERE prc_cliente = @CLIENTE AND prc_codigo = @CODIGO AND prc_version = @VERSION)
BEGIN
    RAISERROR('4.- YA EXISTE LA VERSION %d DEL PROCEDIMIENTO "%s".', 16, 1, @VERSION, @CODIGO)
    RETURN -1
END

IF (@ACTIVO_TIPO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                     WHERE ati_id = @ACTIVO_TIPO
                       AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE)))
BEGIN
    RAISERROR('5.- EL TIPO DE ACTIVO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Decir que exige permiso y no decir cual deja al tecnico sin saber que
   pedir. La tabla no lo impide; la regla si. */
IF (@REQUIERE_PERMISO = 1 AND @PERMISO_TIPO IS NULL)
BEGIN
    RAISERROR('6.- SI EL PROCEDIMIENTO EXIGE PERMISO DE TRABAJO, INDIQUE DE QUE TIPO.', 16, 1)
    RETURN -1
END

IF (@PERMISO_TIPO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo]
                     WHERE ptt_id = @PERMISO_TIPO
                       AND (ptt_cliente IS NULL OR ptt_cliente = @CLIENTE)))
BEGIN
    RAISERROR('7.- EL TIPO DE PERMISO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Procedimiento]
        (prc_cliente, prc_codigo, prc_nombre, prc_version, prc_activo_tipo,
         prc_descripcion, prc_duracion_estimada_minuto,
         prc_requiere_permiso, prc_permiso_trabajo_tipo,
         prc_usuario_creacion, prc_fecha_creacion,
         prc_usuario_actualizacion, prc_fecha_actualizacion, prc_habilitado)
    VALUES
        (@CLIENTE, @CODIGO, @NOMBRE, @VERSION, @ACTIVO_TIPO,
         @DESCRIPCION, @DURACION,
         @REQUIERE_PERMISO, @PERMISO_TIPO,
         @USUARIO, @AHORA, NULL, NULL, 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT

    SET @ID = SCOPE_IDENTITY()

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('8.- NO FUE POSIBLE CREAR EL PROCEDIMIENTO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Procedimiento creado con éxito.' AS MENSAJE
GO

PRINT '--- INS_PROCEDIMIENTO creado.'
GO


/* ========================================================================
   5. UPD_PROCEDIMIENTO                                             T-3204

      EL CODIGO Y LA VERSION NO SE EDITAN

        Los dos forman la llave y el codigo es como la gente llama al
        procedimiento. Cambiar la version de una fila existente reescribiria
        lo que una orden ya ejecutada dice haber seguido; para una revision
        se crea una version nueva.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_PROCEDIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_PROCEDIMIENTO]
GO

CREATE PROCEDURE [dbo].[UPD_PROCEDIMIENTO]
    @ID               INT,
    @CLIENTE          INT,
    @NOMBRE           NVARCHAR(400) = NULL,
    @ACTIVO_TIPO      INT = NULL,
    @DESCRIPCION      NVARCHAR(MAX) = NULL,
    @DURACION         INT = NULL,
    @REQUIERE_PERMISO BIT = NULL,
    @PERMISO_TIPO     INT = NULL,
    @HABILITADO       BIT = NULL,
    @QUITA_TIPO       BIT = 0,
    @USUARIO          INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @ES_GLOBAL BIT

SELECT @ES_GLOBAL = CASE WHEN prc_cliente IS NULL THEN 1 ELSE 0 END
FROM   [dbo].[Procedimiento]
WHERE  prc_id = @ID AND (prc_cliente = @CLIENTE OR prc_cliente IS NULL)

IF (@ES_GLOBAL IS NULL)
BEGIN
    RAISERROR('9.- EL PROCEDIMIENTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Un procedimiento global es del sistema: si un cliente pudiera editarlo, el
   cambio lo verian todos los demas. */
IF (@ES_GLOBAL = 1)
BEGIN
    RAISERROR('10.- ESTE PROCEDIMIENTO ES DEL SISTEMA Y NO SE EDITA. COPIELO PARA ADAPTARLO.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@ACTIVO_TIPO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                     WHERE ati_id = @ACTIVO_TIPO
                       AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE)))
BEGIN
    RAISERROR('5.- EL TIPO DE ACTIVO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@PERMISO_TIPO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo]
                     WHERE ptt_id = @PERMISO_TIPO
                       AND (ptt_cliente IS NULL OR ptt_cliente = @CLIENTE)))
BEGIN
    RAISERROR('7.- EL TIPO DE PERMISO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Se comprueba contra lo que va a QUEDAR: se puede estar encendiendo
   "requiere permiso" sin mandar el tipo. */
DECLARE @REQ_FINAL BIT, @TIPO_FINAL INT

SELECT  @REQ_FINAL  = ISNULL(@REQUIERE_PERMISO, prc_requiere_permiso),
        @TIPO_FINAL = ISNULL(@PERMISO_TIPO, prc_permiso_trabajo_tipo)
FROM    [dbo].[Procedimiento] WHERE prc_id = @ID

IF (@REQ_FINAL = 1 AND @TIPO_FINAL IS NULL)
BEGIN
    RAISERROR('6.- SI EL PROCEDIMIENTO EXIGE PERMISO DE TRABAJO, INDIQUE DE QUE TIPO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Procedimiento]
    SET     prc_nombre                   = ISNULL(NULLIF(LTRIM(RTRIM(@NOMBRE)), ''), prc_nombre)
           /* QUITA_TIPO distingue "no me toques el tipo" de "dejalo sin
              tipo": sin la bandera no habria forma de desasociarlo. */
           ,prc_activo_tipo               = CASE WHEN @QUITA_TIPO = 1 THEN NULL
                                                 ELSE ISNULL(@ACTIVO_TIPO, prc_activo_tipo) END
           ,prc_descripcion               = ISNULL(@DESCRIPCION, prc_descripcion)
           ,prc_duracion_estimada_minuto  = ISNULL(@DURACION, prc_duracion_estimada_minuto)
           ,prc_requiere_permiso          = @REQ_FINAL
           ,prc_permiso_trabajo_tipo      = CASE WHEN @REQ_FINAL = 0 THEN NULL ELSE @TIPO_FINAL END
           ,prc_habilitado                = ISNULL(@HABILITADO, prc_habilitado)
           ,prc_usuario_actualizacion     = @USUARIO
           ,prc_fecha_actualizacion       = @AHORA
    WHERE   prc_id = @ID

    DECLARE @FILAS_UPD INT = @@ROWCOUNT

    IF @FILAS_UPD = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('11.- NO FUE POSIBLE ACTUALIZAR EL PROCEDIMIENTO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Procedimiento actualizado con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PROCEDIMIENTO creado.'
GO


/* ========================================================================
   6. DEL_PROCEDIMIENTO                                             T-3205

      BAJA LOGICA, Y RECHAZO EXPLICADO

        Tres tablas dependen de un procedimiento: sus pasos,
        Plan_Mantenimiento_Actividad y Orden_Trabajo_Paso. Un procedimiento
        que una orden ejecutada referencia NO se borra: su nombre esta en el
        historial de lo que se hizo.

        Se deshabilita, que es lo que corresponde: deja de ofrecerse en los
        planes nuevos y conserva lo anterior.
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_PROCEDIMIENTO') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROCEDIMIENTO]
GO

CREATE PROCEDURE [dbo].[DEL_PROCEDIMIENTO]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @USOS INT, @MSG NVARCHAR(400), @ES_GLOBAL BIT

SELECT @ES_GLOBAL = CASE WHEN prc_cliente IS NULL THEN 1 ELSE 0 END
FROM   [dbo].[Procedimiento]
WHERE  prc_id = @ID AND (prc_cliente = @CLIENTE OR prc_cliente IS NULL)

IF (@ES_GLOBAL IS NULL)
BEGIN
    RAISERROR('9.- EL PROCEDIMIENTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ES_GLOBAL = 1)
BEGIN
    RAISERROR('10.- ESTE PROCEDIMIENTO ES DEL SISTEMA Y NO SE ELIMINA.', 16, 1)
    RETURN -1
END

SET @USOS = (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] WHERE paa_procedimiento = @ID)
          + (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] otp
              JOIN [dbo].[Procedimiento_Paso] s ON s.ppa_id = otp.otp_procedimiento_paso
             WHERE s.ppa_procedimiento = @ID)

IF (@USOS > 0)
BEGIN
    SET @MSG = '12.- EL PROCEDIMIENTO ESTA USADO EN ' + LTRIM(STR(@USOS)) +
               ' REGISTRO(S) Y NO SE PUEDE ELIMINAR. ' +
               'DESHABILITELO PARA QUE DEJE DE OFRECERSE SIN PERDER EL HISTORIAL.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    /* Los pasos se apagan con el procedimiento: un paso habilitado dentro de
       un procedimiento deshabilitado no significa nada. */
    UPDATE [dbo].[Procedimiento_Paso]
    SET    ppa_habilitado = 0, ppa_usuario_actualizacion = @USUARIO, ppa_fecha_actualizacion = @AHORA
    WHERE  ppa_procedimiento = @ID

    UPDATE  [dbo].[Procedimiento]
    SET     prc_habilitado            = 0
           ,prc_usuario_actualizacion = @USUARIO
           ,prc_fecha_actualizacion   = @AHORA
    WHERE   prc_id = @ID

    DECLARE @FILAS_DEL INT = @@ROWCOUNT

    IF @FILAS_DEL = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('13.- NO FUE POSIBLE ELIMINAR EL PROCEDIMIENTO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Procedimiento eliminado con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROCEDIMIENTO creado.'
GO


PRINT '101_PROCEDIMIENTO aplicado (parte 1: procedimiento).'
GO
