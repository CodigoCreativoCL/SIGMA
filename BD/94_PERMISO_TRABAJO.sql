/* ============================================================================
   SIGMA — Bloque 94
   PERMISOS DE TRABAJO                                                 HU-063
   ----------------------------------------------------------------------------

   QUE PIDE LA HISTORIA

     "Adjuntar el permiso firmado que habilita el trabajo, para dejar
     constancia de que se ejecutó con la autorización correspondiente."

     Un permiso de trabajo es el papel que autoriza una faena de riesgo
     —altura, espacio confinado, trabajo caliente— y lo firma prevención de
     riesgos. Lo que importa no es el registro: es **el documento firmado**.

   LA EVIDENCIA NO SE PUEDE SUBIR TODAVIA, Y NO ES UN DESCUIDO

     `Almacenamiento` está detrás de una API .NET aparte que todavía no
     existe (decisión del 29-08, ver el MD de estado). `Disponible` devuelve
     falso mientras `AlmacenamientoApiUrl` conserve el texto `PENDIENTE`.

     Este bloque deja **el hueco listo y conectado**: `ptr_archivo` ya apunta
     a `Archivo` desde las fundaciones, el SEL_ devuelve el nombre y el peso
     del adjunto, y la pantalla pregunta por `Disponible` y dice por qué no
     se puede en vez de ofrecer un botón que va a fallar. El día que la API
     exista, se cambia el Web.config y funciona sin tocar código.

     **Sin adjunto el permiso se guarda igual.** Un permiso registrado sin su
     papel sirve —está la vigencia, el tipo, quién lo pidió— y bloquear el
     alta hasta que exista la subida dejaría el módulo inservible por algo
     que no depende de quien lo usa.

   EL NUMERO ES EL DEL PAPEL, NO UN CODIGO NUESTRO

     `ptr_numero` guarda el folio que trae el formulario de prevención. **No
     lleva código automático** (bloque 77): meter un `PTR-12` en esa columna
     lo haría indistinguible del folio oficial, que es justo el dato por el
     que alguien va a buscar. Es opcional: hay plantas que no numeran.

   LA VIGENCIA SE CALCULA, NO SE GUARDA

     `Permiso_Trabajo_Estado` tiene VENCIDO, pero un estado guardado envejece
     solo: un permiso que venció anoche seguiría diciendo AUTORIZADO hasta
     que alguien corriera un proceso. El SEL_ devuelve `SITUACION` calculada
     contra la fecha de hoy —VIGENTE, POR VENCER, VENCIDO—, que es lo que
     HU-064 necesita y no puede quedar desactualizado.

   ORDEN: despues de 93_ALCANCE_COMBOS.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA CATEGORIA DEL ADJUNTO

      Existe "DOCUMENTO" (9) y serviría, pero las categorías son con lo que
      después se filtran los archivos de un cliente. Un permiso de trabajo
      mezclado entre todos los documentos no se puede volver a encontrar.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE aca_codigo = 'PERMISO TRABAJO')
BEGIN
    SET IDENTITY_INSERT [dbo].[Archivo_Categoria] ON

    INSERT INTO [dbo].[Archivo_Categoria]
        (aca_id, aca_cliente, aca_codigo, aca_nombre, aca_icono, aca_archivo,
         aca_orden, aca_usuario_creacion, aca_fecha_creacion, aca_habilitado)
    VALUES (13, NULL, 'PERMISO TRABAJO', 'Permiso de trabajo',
            'mdi mdi-shield-check-outline', 1, 13, 1, GETDATE(), 1)

    SET IDENTITY_INSERT [dbo].[Archivo_Categoria] OFF

    PRINT '--- Categoria de archivo PERMISO TRABAJO creada (13).'
END
ELSE PRINT '--- Categoria PERMISO TRABAJO ya existe.'
GO


/* ========================================================================
   2. INDICES DE APOYO                                              T-3217

      IX_PTR_CLIENTE_VIGENCIA ya existe desde las fundaciones y cubre la
      consulta por vencimiento, que es la de HU-064. Falta la del listado
      normal: por cliente y estado, ordenando por vigencia.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_PTR_CLIENTE_ESTADO'
                  AND object_id = OBJECT_ID('dbo.Permiso_Trabajo'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PTR_CLIENTE_ESTADO
        ON [dbo].[Permiso_Trabajo] ([ptr_cliente], [ptr_permiso_trabajo_estado])
        INCLUDE ([ptr_permiso_trabajo_tipo], [ptr_numero],
                 [ptr_fecha_vigencia_inicio_utc], [ptr_fecha_vigencia_fin_utc])

    PRINT '--- Indice IX_PTR_CLIENTE_ESTADO creado.'
END
ELSE PRINT '--- Indice IX_PTR_CLIENTE_ESTADO ya existe.'
GO

/* La orden de trabajo: para abrir un permiso desde la orden. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_PTR_ORDEN'
                  AND object_id = OBJECT_ID('dbo.Permiso_Trabajo'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PTR_ORDEN
        ON [dbo].[Permiso_Trabajo] ([ptr_orden_trabajo])
        WHERE [ptr_orden_trabajo] IS NOT NULL

    PRINT '--- Indice IX_PTR_ORDEN creado.'
END
ELSE PRINT '--- Indice IX_PTR_ORDEN ya existe.'
GO


/* ========================================================================
   3. LOS DOS CATALOGOS, PARA LOS COMBOS

      No tenían consulta: las tablas están desde las fundaciones y nunca se
      leyeron desde la aplicación.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PERMISO_TRABAJO_TIPO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_TIPO]
GO

CREATE PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_TIPO]
    @CLIENTE    INT,
    @HABILITADO BIT = 1
AS
SET NOCOUNT ON

    /* Los de cliente NULL son del sistema y valen para todos: los seis tipos
       base salen del reglamento, no los inventa cada empresa. */
    SELECT  ptt_id      AS PTT_ID,
            ptt_codigo  AS PTT_CODIGO,
            ptt_nombre  AS PTT_NOMBRE,
            ptt_orden   AS PTT_ORDEN
    FROM    [dbo].[Permiso_Trabajo_Tipo]
    WHERE   (ptt_cliente IS NULL OR ptt_cliente = @CLIENTE)
      AND   (@HABILITADO IS NULL OR ptt_habilitado = @HABILITADO)
    ORDER BY ptt_orden, ptt_nombre
GO

IF OBJECT_ID('dbo.SEL_PERMISO_TRABAJO_ESTADO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_ESTADO]
GO

CREATE PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_ESTADO]
    @HABILITADO BIT = 1
AS
SET NOCOUNT ON

    SELECT  pte_id     AS PTE_ID,
            pte_codigo AS PTE_CODIGO,
            pte_nombre AS PTE_NOMBRE,
            pte_orden  AS PTE_ORDEN
    FROM    [dbo].[Permiso_Trabajo_Estado]
    WHERE   (@HABILITADO IS NULL OR pte_habilitado = @HABILITADO)
    ORDER BY pte_orden, pte_nombre
GO

PRINT '--- Catalogos de permiso de trabajo listos.'
GO


/* ========================================================================
   4. SEL_PERMISO_TRABAJO                                           T-3219

      Sirve a la ficha (@ID) y al listado (filtros). Devuelve SITUACION
      calculada, no guardada: ver el encabezado.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PERMISO_TRABAJO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PERMISO_TRABAJO]
GO

CREATE PROCEDURE [dbo].[SEL_PERMISO_TRABAJO]
    @CLIENTE       INT,
    @ID            INT = NULL,
    @ORDEN_TRABAJO INT = NULL,
    @TIPO          INT = NULL,
    @ESTADO        INT = NULL,
    @SITUACION     VARCHAR(20) = NULL,
    @HABILITADO    BIT = NULL,
    @FILTRO        VARCHAR(200) = NULL,
    @DIAS_AVISO    INT = 7
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME
SET @HOY = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))

    ;WITH BASE AS (
        SELECT  p.ptr_id,
                p.ptr_cliente,
                p.ptr_orden_trabajo,
                p.ptr_permiso_trabajo_tipo,
                p.ptr_permiso_trabajo_estado,
                ISNULL(p.ptr_numero, '')            AS ptr_numero,
                p.ptr_usuario_solicitante,
                p.ptr_fecha_solicitud_utc,
                p.ptr_fecha_vigencia_inicio_utc,
                p.ptr_fecha_vigencia_fin_utc,
                ISNULL(p.ptr_observacion, '')       AS ptr_observacion,
                p.ptr_archivo,
                p.ptr_habilitado,
                p.ptr_usuario_creacion,
                p.ptr_fecha_creacion,
                p.ptr_usuario_actualizacion,
                p.ptr_fecha_actualizacion,

                ti.ptt_nombre                       AS TIPO_NOMBRE,
                ti.ptt_codigo                       AS TIPO_CODIGO,
                es.pte_nombre                       AS ESTADO_NOMBRE,
                es.pte_codigo                       AS ESTADO_CODIGO,

                ISNULL(so.usu_nombre + ' ' + so.usu_apellido_paterno, '') AS SOLICITANTE_NOMBRE,
                ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
                ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,

                ISNULL(ot.otr_correlativo, '')      AS ORDEN_CORRELATIVO,
                ISNULL(ot.otr_titulo, '')           AS ORDEN_TITULO,

                ISNULL(ar.arc_nombre_original, '')  AS ARCHIVO_NOMBRE,
                ISNULL(ar.arc_byte, 0)              AS ARCHIVO_BYTE,
                ISNULL(ar.arc_extension, '')        AS ARCHIVO_EXTENSION,

                /* Cuántos días le quedan. Negativo = ya venció. NULL cuando
                   el permiso no tiene fin declarado. */
                CASE WHEN p.ptr_fecha_vigencia_fin_utc IS NULL THEN NULL
                     ELSE DATEDIFF(DAY, @HOY, p.ptr_fecha_vigencia_fin_utc) END AS DIAS_RESTANTES
        FROM    [dbo].[Permiso_Trabajo] p
        JOIN    [dbo].[Permiso_Trabajo_Tipo] ti   ON ti.ptt_id = p.ptr_permiso_trabajo_tipo
        JOIN    [dbo].[Permiso_Trabajo_Estado] es ON es.pte_id = p.ptr_permiso_trabajo_estado
        LEFT JOIN [dbo].[Usuario] so ON so.usu_id = p.ptr_usuario_solicitante
        LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.ptr_usuario_creacion
        LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.ptr_usuario_actualizacion
        LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = p.ptr_orden_trabajo
        LEFT JOIN [dbo].[Archivo] ar ON ar.arc_id = p.ptr_archivo
        WHERE   p.ptr_cliente = @CLIENTE
          AND   (@ID            IS NULL OR p.ptr_id                     = @ID)
          AND   (@ORDEN_TRABAJO IS NULL OR p.ptr_orden_trabajo          = @ORDEN_TRABAJO)
          AND   (@TIPO          IS NULL OR p.ptr_permiso_trabajo_tipo   = @TIPO)
          AND   (@ESTADO        IS NULL OR p.ptr_permiso_trabajo_estado = @ESTADO)
          AND   (@HABILITADO    IS NULL OR p.ptr_habilitado             = @HABILITADO)
          AND   (@FILTRO IS NULL
                 OR p.ptr_numero      LIKE '%' + @FILTRO + '%'
                 OR p.ptr_observacion LIKE '%' + @FILTRO + '%'
                 OR ti.ptt_nombre     LIKE '%' + @FILTRO + '%'
                 OR ot.otr_correlativo LIKE '%' + @FILTRO + '%')
    )
    SELECT  b.*,
            /* La situación real, contra la fecha de hoy. Un permiso
               RECHAZADO o CERRADO no está "vigente" aunque su fecha no haya
               pasado: el estado manda sobre el calendario. */
            CASE WHEN b.ESTADO_CODIGO IN ('RECHAZADO', 'CERRADO') THEN 'CERRADO'
                 WHEN b.DIAS_RESTANTES IS NULL                    THEN 'SIN VIGENCIA'
                 WHEN b.DIAS_RESTANTES < 0                        THEN 'VENCIDO'
                 WHEN b.DIAS_RESTANTES <= @DIAS_AVISO             THEN 'POR VENCER'
                 ELSE 'VIGENTE' END AS SITUACION
    FROM    BASE b
    WHERE   (@SITUACION IS NULL
             OR @SITUACION = CASE WHEN b.ESTADO_CODIGO IN ('RECHAZADO', 'CERRADO') THEN 'CERRADO'
                                  WHEN b.DIAS_RESTANTES IS NULL        THEN 'SIN VIGENCIA'
                                  WHEN b.DIAS_RESTANTES < 0            THEN 'VENCIDO'
                                  WHEN b.DIAS_RESTANTES <= @DIAS_AVISO THEN 'POR VENCER'
                                  ELSE 'VIGENTE' END)
    /* El que vence antes, primero: es el que hay que mirar. */
    ORDER BY CASE WHEN b.DIAS_RESTANTES IS NULL THEN 1 ELSE 0 END,
             b.DIAS_RESTANTES,
             b.ptr_id DESC
GO

PRINT '--- SEL_PERMISO_TRABAJO creado.'
GO


/* ========================================================================
   5. INS_PERMISO_TRABAJO                                           T-3218
   ======================================================================== */
IF OBJECT_ID('dbo.INS_PERMISO_TRABAJO') IS NOT NULL
    DROP PROCEDURE [dbo].[INS_PERMISO_TRABAJO]
GO

CREATE PROCEDURE [dbo].[INS_PERMISO_TRABAJO]
    @ID              INT OUTPUT,
    @CLIENTE         INT,
    @TIPO            INT,
    @ESTADO          INT = NULL,
    @NUMERO          NVARCHAR(100) = NULL,
    @ORDEN_TRABAJO   INT = NULL,
    @SOLICITANTE     INT = NULL,
    @VIGENCIA_INICIO DATETIME = NULL,
    @VIGENCIA_FIN    DATETIME = NULL,
    @OBSERVACION     NVARCHAR(1000) = NULL,
    @ARCHIVO         INT = NULL,
    @USUARIO         INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Nace SOLICITADO salvo que digan otra cosa: quien adjunta un permiso ya
   firmado lo registra directamente como AUTORIZADO. */
IF (@ESTADO IS NULL)
    SELECT @ESTADO = pte_id FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_codigo = 'SOLICITADO'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo]
                WHERE ptt_id = @TIPO AND (ptt_cliente IS NULL OR ptt_cliente = @CLIENTE))
BEGIN
    RAISERROR('1.- EL TIPO DE PERMISO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_id = @ESTADO)
BEGIN
    RAISERROR('2.- EL ESTADO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@ORDEN_TRABAJO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                     WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE))
BEGIN
    RAISERROR('3.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE))
BEGIN
    RAISERROR('4.- EL ARCHIVO ADJUNTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Una vigencia al revés no es un error de dedo que se pueda dejar pasar: el
   permiso quedaría vencido el día que nace y nadie entendería por qué. */
IF (@VIGENCIA_INICIO IS NOT NULL AND @VIGENCIA_FIN IS NOT NULL
    AND @VIGENCIA_FIN < @VIGENCIA_INICIO)
BEGIN
    RAISERROR('5.- LA VIGENCIA TERMINA ANTES DE EMPEZAR.', 16, 1)
    RETURN -1
END

/* AUTORIZADO EXIGE EL DOCUMENTO. LO DICE LA TABLA.

   CK_PTR_AUTORIZADO impide que un permiso este AUTORIZADO sin ptr_archivo, y
   es exactamente lo que pide la historia: la constancia ES el papel firmado,
   no la fila. Sin el adjunto, autorizar seria afirmar algo que no se puede
   respaldar.

   Se comprueba ACA para poder explicarlo. Dejar que salte el CHECK devuelve
   "The INSERT statement conflicted with the CHECK constraint
   CK_PTR_AUTORIZADO", que no le dice nada a quien esta llenando el
   formulario. */
IF (@ARCHIVO IS NULL
    AND EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado]
                 WHERE pte_id = @ESTADO AND pte_codigo = 'AUTORIZADO'))
BEGIN
    RAISERROR('10.- UN PERMISO AUTORIZADO NECESITA EL DOCUMENTO FIRMADO ADJUNTO. REGISTRELO COMO SOLICITADO Y AUTORICELO CUANDO PUEDA ADJUNTARLO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Permiso_Trabajo]
        (ptr_cliente, ptr_orden_trabajo, ptr_permiso_trabajo_tipo, ptr_permiso_trabajo_estado,
         ptr_numero, ptr_usuario_solicitante, ptr_fecha_solicitud_utc,
         ptr_fecha_vigencia_inicio_utc, ptr_fecha_vigencia_fin_utc,
         ptr_observacion, ptr_archivo,
         ptr_usuario_creacion, ptr_fecha_creacion,
         ptr_usuario_actualizacion, ptr_fecha_actualizacion, ptr_habilitado)
    VALUES
        (@CLIENTE, @ORDEN_TRABAJO, @TIPO, @ESTADO,
         NULLIF(LTRIM(RTRIM(@NUMERO)), ''), ISNULL(@SOLICITANTE, @USUARIO), @AHORA,
         @VIGENCIA_INICIO, @VIGENCIA_FIN,
         @OBSERVACION, @ARCHIVO,
         @USUARIO, @AHORA, NULL, NULL, 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT

    SET @ID = SCOPE_IDENTITY()

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('6.- NO FUE POSIBLE REGISTRAR EL PERMISO DE TRABAJO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Permiso de trabajo registrado con éxito.' AS MENSAJE
GO

PRINT '--- INS_PERMISO_TRABAJO creado.'
GO


/* ========================================================================
   6. UPD_PERMISO_TRABAJO                                           T-3220

      "Corrección del registro mientras esté en un estado que lo permita."

      SOLICITADO y AUTORIZADO se corrigen. RECHAZADO, VENCIDO y CERRADO no:
      son el final de la historia de ese permiso, y editarlos reescribiría lo
      que ya quedó como constancia —que es exactamente para lo que la
      historia dice que sirve el módulo—.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_PERMISO_TRABAJO') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_PERMISO_TRABAJO]
GO

CREATE PROCEDURE [dbo].[UPD_PERMISO_TRABAJO]
    @ID              INT,
    @CLIENTE         INT,
    @TIPO            INT = NULL,
    @ESTADO          INT = NULL,
    @NUMERO          NVARCHAR(100) = NULL,
    @ORDEN_TRABAJO   INT = NULL,
    @SOLICITANTE     INT = NULL,
    @VIGENCIA_INICIO DATETIME = NULL,
    @VIGENCIA_FIN    DATETIME = NULL,
    @OBSERVACION     NVARCHAR(1000) = NULL,
    @ARCHIVO         INT = NULL,
    @HABILITADO      BIT = NULL,
    @QUITA_ORDEN     BIT = 0,
    @USUARIO         INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @ESTADO_ACTUAL VARCHAR(30)

SELECT  @ESTADO_ACTUAL = es.pte_codigo
FROM    [dbo].[Permiso_Trabajo] p
JOIN    [dbo].[Permiso_Trabajo_Estado] es ON es.pte_id = p.ptr_permiso_trabajo_estado
WHERE   p.ptr_id = @ID AND p.ptr_cliente = @CLIENTE

IF (@ESTADO_ACTUAL IS NULL)
BEGIN
    RAISERROR('7.- EL PERMISO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ESTADO_ACTUAL IN ('RECHAZADO', 'VENCIDO', 'CERRADO'))
BEGIN
    DECLARE @MSG NVARCHAR(300)
    SET @MSG = '8.- EL PERMISO ESTA ' + @ESTADO_ACTUAL +
               ' Y YA NO SE PUEDE CORREGIR. REGISTRE UNO NUEVO SI HACE FALTA.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@TIPO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo]
                     WHERE ptt_id = @TIPO AND (ptt_cliente IS NULL OR ptt_cliente = @CLIENTE)))
BEGIN
    RAISERROR('1.- EL TIPO DE PERMISO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ORDEN_TRABAJO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                     WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE))
BEGIN
    RAISERROR('3.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE))
BEGIN
    RAISERROR('4.- EL ARCHIVO ADJUNTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Se comprueba contra lo que va a QUEDAR, no contra lo que llega: se puede
   estar cambiando solo una de las dos fechas. */
DECLARE @INI DATETIME, @FIN DATETIME

SELECT  @INI = ISNULL(@VIGENCIA_INICIO, ptr_fecha_vigencia_inicio_utc),
        @FIN = ISNULL(@VIGENCIA_FIN,    ptr_fecha_vigencia_fin_utc)
FROM    [dbo].[Permiso_Trabajo] WHERE ptr_id = @ID

IF (@INI IS NOT NULL AND @FIN IS NOT NULL AND @FIN < @INI)
BEGIN
    RAISERROR('5.- LA VIGENCIA TERMINA ANTES DE EMPEZAR.', 16, 1)
    RETURN -1
END

/* Igual que en el alta, pero contra lo que va a quedar: se puede estar
   pasando a AUTORIZADO un permiso que no tiene adjunto, o quitandole el
   adjunto a uno que ya lo estaba. */
DECLARE @ARC_FINAL INT, @EST_FINAL INT

SELECT  @ARC_FINAL = ISNULL(@ARCHIVO, ptr_archivo),
        @EST_FINAL = ISNULL(@ESTADO, ptr_permiso_trabajo_estado)
FROM    [dbo].[Permiso_Trabajo] WHERE ptr_id = @ID

IF (@ARC_FINAL IS NULL
    AND EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado]
                 WHERE pte_id = @EST_FINAL AND pte_codigo = 'AUTORIZADO'))
BEGIN
    RAISERROR('10.- UN PERMISO AUTORIZADO NECESITA EL DOCUMENTO FIRMADO ADJUNTO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Permiso_Trabajo]
    SET     ptr_permiso_trabajo_tipo    = ISNULL(@TIPO, ptr_permiso_trabajo_tipo)
           ,ptr_permiso_trabajo_estado   = ISNULL(@ESTADO, ptr_permiso_trabajo_estado)
           ,ptr_numero                   = ISNULL(NULLIF(LTRIM(RTRIM(@NUMERO)), ''), ptr_numero)
           /* QUITA_ORDEN distingue "no me toques la orden" de "déjalo sin
              orden": sin la bandera no habría forma de desasociarlo. */
           ,ptr_orden_trabajo            = CASE WHEN @QUITA_ORDEN = 1 THEN NULL
                                                ELSE ISNULL(@ORDEN_TRABAJO, ptr_orden_trabajo) END
           ,ptr_usuario_solicitante      = ISNULL(@SOLICITANTE, ptr_usuario_solicitante)
           ,ptr_fecha_vigencia_inicio_utc = ISNULL(@VIGENCIA_INICIO, ptr_fecha_vigencia_inicio_utc)
           ,ptr_fecha_vigencia_fin_utc    = ISNULL(@VIGENCIA_FIN, ptr_fecha_vigencia_fin_utc)
           ,ptr_observacion              = ISNULL(@OBSERVACION, ptr_observacion)
           ,ptr_archivo                  = ISNULL(@ARCHIVO, ptr_archivo)
           ,ptr_habilitado               = ISNULL(@HABILITADO, ptr_habilitado)
           ,ptr_usuario_actualizacion    = @USUARIO
           ,ptr_fecha_actualizacion      = @AHORA
    WHERE   ptr_id = @ID

    DECLARE @FILAS_UPD INT = @@ROWCOUNT

    IF @FILAS_UPD = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('9.- NO FUE POSIBLE ACTUALIZAR EL PERMISO DE TRABAJO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Permiso de trabajo actualizado con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PERMISO_TRABAJO creado.'
GO


/* ========================================================================
   7. PERMISOS Y MENU                                               T-3228
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT, @PADRE INT, @MNU INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PERMISOS TRABAJO')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('VER PERMISOS TRABAJO', 'Ver permisos de trabajo', 'TERCEROS', 3,
            'Consultar los permisos que habilitan faenas de riesgo', 1, GETDATE(), 1, 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR PERMISO TRABAJO')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('REGISTRAR PERMISO TRABAJO', 'Registrar permisos de trabajo', 'TERCEROS', 3,
            'Dar de alta un permiso y adjuntar el documento firmado', 1, GETDATE(), 1, 0)

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PERMISOS TRABAJO'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR PERMISO TRABAJO'

/* Cuelga de Terceros, que se creó en el bloque 91 para esto. */
SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = 'Terceros' AND mnu_nivel = 2

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Permisos de trabajo', 'Los permisos que habilitan faenas de riesgo',
            3, @PADRE, 2, '~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx',
            1, NULL, @VER, 3)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Permiso de trabajo (detalle)', 'Ficha del permiso',
            3, @PADRE, 99, '~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx',
            0, NULL, @VER, 3)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Terceros/PermisosTrabajo/PermisoTrabajo.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

/* Los perfiles: el prevencionista AUTORIZA permisos y es el dueño natural
   del módulo; jefatura, supervisión y planificación los registran y los
   consultan; el técnico los ve porque es quien tiene que saber si su faena
   está habilitada. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT p.per_id, x.prm, 1, GETDATE()
FROM   (VALUES (16), (5), (11), (12)) AS p(per_id)
CROSS JOIN (VALUES (@VER), (@EDITAR)) AS x(prm)
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = p.per_id AND ppe_permiso = x.prm)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT 13, @VER, 1, GETDATE()
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = 13 AND ppe_permiso = @VER)

PRINT '--- Permisos, menu y perfiles de permisos de trabajo listos.'
GO


/* ========================================================================
   8. DATOS DE PRUEBA                                               T-3221

      Tres permisos que cubren las tres situaciones que la pantalla tiene que
      saber pintar: uno vigente, uno por vencer y uno vencido. Sin los tres,
      HU-064 no tiene contra qué probarse.

      NINGUNO LLEVA ADJUNTO, y no es un olvido: no se puede subir un archivo
      todavía. Ver el encabezado.
   ======================================================================== */
DECLARE @ID INT, @AUT INT, @SOL INT, @HOY DATETIME, @N INT = 0
DECLARE @INI DATETIME, @FIN DATETIME

SET @HOY = [dbo].[FNC_PAIS_HORA](1)

SELECT @AUT = pte_id FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_codigo = 'AUTORIZADO'
SELECT @SOL = pte_id FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_codigo = 'SOLICITADO'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo] WHERE ptr_cliente = 1)
BEGIN
    /* VIGENTE: quedan tres semanas. */
    SET @INI = @HOY
    SET @FIN = DATEADD(DAY, 21, @HOY)
    EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 1, @SOL, N'PT-2026-0417', NULL, 8,
         @INI, @FIN,
         N'Cambio de correas en el ventilador de extracción, plataforma a 4,5 m.', NULL, 1
    SET @N = @N + 1

    /* POR VENCER: quedan tres días. */
    SET @INI = DATEADD(DAY, -4, @HOY)
    SET @FIN = DATEADD(DAY, 3, @HOY)
    EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 3, @SOL, N'PT-2026-0431', NULL, 10,
         @INI, @FIN,
         N'Soldadura de soporte en línea 1. Extintor y vigía en el punto.', NULL, 1
    SET @N = @N + 1

    /* VENCIDO: terminó hace cinco días. */
    SET @INI = DATEADD(DAY, -20, @HOY)
    SET @FIN = DATEADD(DAY, -5, @HOY)
    EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 2, @SOL, N'PT-2026-0402', NULL, 12,
         @INI, @FIN,
         N'Inspección interior del estanque de almacenamiento.', NULL, 1
    SET @N = @N + 1

    /* Se cuenta lo que QUEDO, no lo que se intento: el contador decia "3"
       cuando dos habian rebotado contra el CHECK. */
    SET @N = (SELECT COUNT(*) FROM [dbo].[Permiso_Trabajo] WHERE ptr_cliente = 1)
    PRINT '--- Permisos de trabajo de prueba en la base: ' + LTRIM(STR(@N))
END
ELSE PRINT '--- El cliente ya tiene permisos de trabajo.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_PERMISO_TRABAJO] @CLIENTE = 1
GO

PRINT '94_PERMISO_TRABAJO aplicado.'
GO
