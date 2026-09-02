/* ============================================================================
   SIGMA — Bloque 97
   PERMISOS VIGENTES Y POR VENCER                                      HU-064
   ----------------------------------------------------------------------------

   "Ver qué permisos están vigentes y cuáles están por vencer, para no
   descubrir en terreno que el permiso caducó."

   LA REGLA DE LA SITUACION SE EXTRAE A UNA FUNCION

     El bloque 94 la escribió dentro de `SEL_PERMISO_TRABAJO`, en un CASE
     repetido dos veces —una para devolverla, otra para poder filtrar por
     ella—. Ahora hace falta otra vez en `SEL_PERMISO_TRABAJO_VIGENTE`.

     Copiada quedaría en cuatro sitios, y el día que alguien cambie el umbral
     de aviso o agregue un estado, tres de los cuatro se van a actualizar. Es
     exactamente la clase de error que no da síntoma: la pantalla de alertas
     diría una cosa y la ficha otra, y las dos parecerían correctas.

     `FNC_PERMISO_SITUACION` la tiene una vez. En SQL Server 2019 en adelante
     las funciones escalares se **incorporan al plan** (inlining), así que no
     cuesta la llamada fila por fila que costaría en una versión vieja.

   EL ESTADO MANDA SOBRE EL CALENDARIO

     Un permiso RECHAZADO o CERRADO no está "vigente" aunque su fecha no haya
     pasado: ya terminó su historia. Un permiso sin fecha de fin no está
     vencido ni vigente —está SIN VIGENCIA— y aparece aparte, porque es un
     dato incompleto y no una situación.

   NO HAY PAGINACION EN EL SP, Y ES A PROPOSITO

     T-3310 la pide, pero el proyecto pagina en C# con `Paginado<T>.Armar`:
     todos los listados de la API funcionan así. Un SP que pagine por su
     cuenta obligaría a mantener dos mecanismos y a que el llamador supiera
     cuál le toca. Se devuelve el conjunto filtrado y ordenado, que es lo que
     `Paginado<T>` espera.

   ORDEN: despues de 96_PERMISO_TRABAJO_UUID.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. FNC_PERMISO_SITUACION                                         T-3310

      Una sola definicion de que significa vigente, por vencer y vencido.
   ======================================================================== */
IF OBJECT_ID('dbo.FNC_PERMISO_SITUACION') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_PERMISO_SITUACION]
GO

CREATE FUNCTION [dbo].[FNC_PERMISO_SITUACION]
(
    @ESTADO_CODIGO  VARCHAR(30),
    @DIAS_RESTANTES INT,
    @DIAS_AVISO     INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    /* El estado manda sobre el calendario: un permiso rechazado o cerrado no
       esta vigente aunque su fecha no haya pasado. */
    IF (@ESTADO_CODIGO IN ('RECHAZADO', 'CERRADO')) RETURN 'CERRADO'

    /* Sin fecha de fin no es vencido ni vigente: es un dato incompleto, y
       decir "VIGENTE" seria afirmar algo que nadie declaro. */
    IF (@DIAS_RESTANTES IS NULL) RETURN 'SIN VIGENCIA'

    IF (@DIAS_RESTANTES < 0) RETURN 'VENCIDO'
    IF (@DIAS_RESTANTES <= ISNULL(@DIAS_AVISO, 7)) RETURN 'POR VENCER'

    RETURN 'VIGENTE'
END
GO

PRINT '--- FNC_PERMISO_SITUACION creada.'
GO


/* ========================================================================
   2. SEL_PERMISO_TRABAJO usa la funcion en vez de su propio CASE
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
                p.ptr_uuid,
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
            /* Una sola definicion, la de la funcion. */
            [dbo].[FNC_PERMISO_SITUACION](b.ESTADO_CODIGO, b.DIAS_RESTANTES, @DIAS_AVISO) AS SITUACION
    FROM    BASE b
    WHERE   (@SITUACION IS NULL
             OR @SITUACION = [dbo].[FNC_PERMISO_SITUACION](b.ESTADO_CODIGO, b.DIAS_RESTANTES, @DIAS_AVISO))
    /* El que vence antes, primero: es el que hay que mirar. */
    ORDER BY CASE WHEN b.DIAS_RESTANTES IS NULL THEN 1 ELSE 0 END,
             b.DIAS_RESTANTES,
             b.ptr_id DESC
GO

PRINT '--- SEL_PERMISO_TRABAJO ahora usa FNC_PERMISO_SITUACION.'
GO


/* ========================================================================
   3. SEL_PERMISO_TRABAJO_VIGENTE                                   T-3310

      La consulta de la pantalla de alerta: lo que esta vigente y lo que
      esta por vencer.

      DEVUELVE MENOS COLUMNAS QUE EL SEL_ COMPLETO, A PROPOSITO
        Esta pantalla es para mirar de un vistazo, no para abrir cada fila.
        Traer las 32 columnas del detalle para pintar seis es pagar el viaje
        completo por cada permiso de la planta.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PERMISO_TRABAJO_VIGENTE') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_VIGENTE]
GO

CREATE PROCEDURE [dbo].[SEL_PERMISO_TRABAJO_VIGENTE]
    @CLIENTE           INT,
    @DIAS_AVISO        INT = 7,
    @TIPO              INT = NULL,
    @INCLUIR_VENCIDOS  BIT = 1,
    @SOLO_POR_VENCER   BIT = 0,
    @FILTRO            VARCHAR(200) = NULL
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME
SET @HOY = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))

    ;WITH BASE AS (
        SELECT  p.ptr_id,
                p.ptr_permiso_trabajo_tipo,
                ISNULL(p.ptr_numero, '')            AS ptr_numero,
                p.ptr_fecha_vigencia_inicio_utc,
                p.ptr_fecha_vigencia_fin_utc,
                p.ptr_archivo,
                ti.ptt_nombre                       AS TIPO_NOMBRE,
                es.pte_nombre                       AS ESTADO_NOMBRE,
                es.pte_codigo                       AS ESTADO_CODIGO,
                ISNULL(so.usu_nombre + ' ' + so.usu_apellido_paterno, '') AS SOLICITANTE_NOMBRE,
                ISNULL(ot.otr_correlativo, '')      AS ORDEN_CORRELATIVO,
                CAST(CASE WHEN p.ptr_archivo IS NULL THEN 0 ELSE 1 END AS BIT) AS TIENE_DOCUMENTO,
                CASE WHEN p.ptr_fecha_vigencia_fin_utc IS NULL THEN NULL
                     ELSE DATEDIFF(DAY, @HOY, p.ptr_fecha_vigencia_fin_utc) END AS DIAS_RESTANTES
        FROM    [dbo].[Permiso_Trabajo] p
        JOIN    [dbo].[Permiso_Trabajo_Tipo] ti   ON ti.ptt_id = p.ptr_permiso_trabajo_tipo
        JOIN    [dbo].[Permiso_Trabajo_Estado] es ON es.pte_id = p.ptr_permiso_trabajo_estado
        LEFT JOIN [dbo].[Usuario] so ON so.usu_id = p.ptr_usuario_solicitante
        LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = p.ptr_orden_trabajo
        WHERE   p.ptr_cliente     = @CLIENTE
          AND   p.ptr_habilitado  = 1
          AND   (@TIPO IS NULL OR p.ptr_permiso_trabajo_tipo = @TIPO)
          AND   (@FILTRO IS NULL
                 OR p.ptr_numero      LIKE '%' + @FILTRO + '%'
                 OR ti.ptt_nombre     LIKE '%' + @FILTRO + '%'
                 OR ot.otr_correlativo LIKE '%' + @FILTRO + '%')
    ),
    CON_SITUACION AS (
        SELECT  b.*,
                [dbo].[FNC_PERMISO_SITUACION](b.ESTADO_CODIGO, b.DIAS_RESTANTES, @DIAS_AVISO) AS SITUACION
        FROM    BASE b
    )
    SELECT  s.*
    FROM    CON_SITUACION s
    /* Lo cerrado y lo que no tiene vigencia declarada NO son parte de esta
       pregunta: la pantalla es "que esta vigente y que esta por vencer". */
    WHERE   s.SITUACION IN ('VIGENTE', 'POR VENCER', 'VENCIDO')
      AND   (@INCLUIR_VENCIDOS = 1 OR s.SITUACION <> 'VENCIDO')
      AND   (@SOLO_POR_VENCER = 0 OR s.SITUACION = 'POR VENCER')
    /* Lo vencido primero y despues lo que menos dias le queda: es el orden
       en que hay que atenderlos, no el orden del calendario. */
    ORDER BY CASE s.SITUACION WHEN 'VENCIDO' THEN 0
                              WHEN 'POR VENCER' THEN 1
                              ELSE 2 END,
             s.DIAS_RESTANTES,
             s.ptr_id DESC
GO

PRINT '--- SEL_PERMISO_TRABAJO_VIGENTE creado.'
GO


/* ========================================================================
   4. EL INDICE                                                     T-3311

      `IX_PTR_CLIENTE_VIGENCIA` ya existe desde las fundaciones y es la
      llave correcta: (cliente, fecha_vigencia_fin). Le faltaba el INCLUDE:
      sin el, el motor encuentra las filas por el indice y despues va a la
      tabla a buscar tipo, estado y numero, una vez por fila.
   ======================================================================== */
IF EXISTS (SELECT 1 FROM sys.indexes
            WHERE name = 'IX_PTR_CLIENTE_VIGENCIA' AND object_id = OBJECT_ID('dbo.Permiso_Trabajo'))
   AND NOT EXISTS (SELECT 1 FROM sys.index_columns ic
                    JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
                    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                   WHERE i.name = 'IX_PTR_CLIENTE_VIGENCIA'
                     AND i.object_id = OBJECT_ID('dbo.Permiso_Trabajo')
                     AND ic.is_included_column = 1
                     AND c.name = 'ptr_permiso_trabajo_tipo')
BEGIN
    DROP INDEX IX_PTR_CLIENTE_VIGENCIA ON [dbo].[Permiso_Trabajo]

    CREATE NONCLUSTERED INDEX IX_PTR_CLIENTE_VIGENCIA
        ON [dbo].[Permiso_Trabajo] ([ptr_cliente], [ptr_fecha_vigencia_fin_utc])
        INCLUDE ([ptr_permiso_trabajo_tipo], [ptr_permiso_trabajo_estado],
                 [ptr_numero], [ptr_archivo], [ptr_habilitado],
                 [ptr_usuario_solicitante], [ptr_orden_trabajo])

    PRINT '--- IX_PTR_CLIENTE_VIGENCIA recreado con INCLUDE.'
END
ELSE PRINT '--- IX_PTR_CLIENTE_VIGENCIA ya esta como corresponde.'
GO


/* ========================================================================
   5. DATOS DE PRUEBA                                               T-3312

      El bloque 94 dejo tres permisos: uno vigente, uno por vencer y uno
      vencido. Faltan dos casos que esta pantalla tiene que saber excluir:
      un CERRADO y uno SIN VIGENCIA. Sin ellos no se puede comprobar que
      NO aparecen, que es la mitad del criterio de aceptacion.
   ======================================================================== */
DECLARE @ID INT, @CER INT, @SOL INT, @HOY DATETIME
DECLARE @INI DATETIME, @FIN DATETIME

SET @HOY = [dbo].[FNC_PAIS_HORA](1)

SELECT @CER = pte_id FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_codigo = 'CERRADO'
SELECT @SOL = pte_id FROM [dbo].[Permiso_Trabajo_Estado] WHERE pte_codigo = 'SOLICITADO'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo]
                WHERE ptr_cliente = 1 AND ptr_numero = 'PT-2026-0388')
BEGIN
    /* CERRADO con fecha futura: no tiene que aparecer aunque no haya vencido. */
    SET @INI = DATEADD(DAY, -10, @HOY)
    SET @FIN = DATEADD(DAY, 30, @HOY)

    EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 4, @CER, N'PT-2026-0388', NULL, 8,
         @INI, @FIN, N'Faena terminada y cerrada antes de la fecha de vencimiento.',
         NULL, NULL, 1

    /* SIN VIGENCIA: solicitado y sin fecha de fin declarada. */
    EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 5, @SOL, N'PT-2026-0390', NULL, 10,
         NULL, NULL, N'Izaje pendiente de programar: todavia sin fechas.',
         NULL, NULL, 1

    PRINT '--- Dos casos de borde agregados (CERRADO y SIN VIGENCIA).'
END
ELSE PRINT '--- Los casos de borde ya existen.'
GO


/* ========================================================================
   VERIFICACION

   Los cinco permisos, y cuales pasan el filtro de la pantalla.
   ======================================================================== */
SELECT  ptr_numero, TIPO_NOMBRE, ESTADO_NOMBRE, DIAS_RESTANTES, SITUACION
FROM    (SELECT p.ptr_numero, ti.ptt_nombre AS TIPO_NOMBRE, es.pte_nombre AS ESTADO_NOMBRE,
                CASE WHEN p.ptr_fecha_vigencia_fin_utc IS NULL THEN NULL
                     ELSE DATEDIFF(DAY, [dbo].[FNC_PAIS_HORA](1), p.ptr_fecha_vigencia_fin_utc) END AS DIAS_RESTANTES,
                [dbo].[FNC_PERMISO_SITUACION](es.pte_codigo,
                    CASE WHEN p.ptr_fecha_vigencia_fin_utc IS NULL THEN NULL
                         ELSE DATEDIFF(DAY, [dbo].[FNC_PAIS_HORA](1), p.ptr_fecha_vigencia_fin_utc) END,
                    7) AS SITUACION
         FROM [dbo].[Permiso_Trabajo] p
         JOIN [dbo].[Permiso_Trabajo_Tipo] ti ON ti.ptt_id = p.ptr_permiso_trabajo_tipo
         JOIN [dbo].[Permiso_Trabajo_Estado] es ON es.pte_id = p.ptr_permiso_trabajo_estado
         WHERE p.ptr_cliente = 1) x
ORDER BY SITUACION, ptr_numero
GO

PRINT '--- Lo que devuelve la pantalla de HU-064:'
GO

EXEC [dbo].[SEL_PERMISO_TRABAJO_VIGENTE] @CLIENTE = 1
GO

PRINT '97_PERMISO_TRABAJO_VIGENTE aplicado.'
GO
