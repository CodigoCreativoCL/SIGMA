/* ============================================================================
   SIGMA — Bloque 96
   EL PERMISO DE TRABAJO SE PUEDE REINTENTAR                           HU-063
   ----------------------------------------------------------------------------

   POR QUE

     T-3222 pide `POST /api/permisos-trabajo` **idempotente por uuid**, "para
     que un reintento del teléfono no cree dos registros".

     `Permiso_Trabajo` **no tenía columna uuid**. Sin ella la idempotencia no
     es implementable: la única forma de saber si una petición ya pasó es que
     el cliente traiga un identificador que él generó, porque el servidor no
     puede distinguir un reintento de dos permisos legítimamente iguales.

   POR QUE IMPORTA EN ESTE MODULO MAS QUE EN OTROS

     El permiso se registra **en terreno**, desde el teléfono, con la red de
     una planta. La app manda, se corta, y no sabe si llegó. Si reintenta y
     no hay idempotencia, quedan dos permisos para la misma faena: el
     prevencionista ve duplicados y no sabe cuál firmó.

     Y peor: si el segundo intento fallara por una regla —el estado ya no lo
     permite— la app mostraría un error por algo que en realidad **sí** se
     guardó.

   EL CORTOCIRCUITO VA ANTES DE TODAS LAS VALIDACIONES

     Un reintento no tiene por qué volver a pasar por reglas que ya pasó, y
     si entre medio algo cambió, la segunda llamada fallaría por algo que ya
     estaba hecho. Es el mismo criterio que `INS_INVENTARIO_MOVIMIENTO`
     (bloque 72).

   ORDEN: despues de 95_ARCHIVO_VER.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA COLUMNA
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Permiso_Trabajo') AND name = 'ptr_uuid')
BEGIN
    ALTER TABLE [dbo].[Permiso_Trabajo] ADD [ptr_uuid] UNIQUEIDENTIFIER NULL

    PRINT '--- Columna ptr_uuid agregada.'
END
ELSE PRINT '--- ptr_uuid ya existe.'
GO

/* El indice es UNICO y FILTRADO.

   Unico porque es lo que de verdad impide el duplicado: sin el, dos
   peticiones simultaneas con el mismo uuid pueden pasar las dos por el
   SELECT del cortocircuito antes de que ninguna haya insertado. El SP
   reduce la ventana; el indice la cierra.

   Filtrado porque las filas existentes tienen uuid NULL, y en un indice
   unico de SQL Server los NULL se comparan como iguales entre si: sin el
   WHERE, la segunda fila sin uuid lo violaria. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_PTR_UUID' AND object_id = OBJECT_ID('dbo.Permiso_Trabajo'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_PTR_UUID
        ON [dbo].[Permiso_Trabajo] ([ptr_uuid])
        WHERE [ptr_uuid] IS NOT NULL

    PRINT '--- Indice UX_PTR_UUID creado.'
END
ELSE PRINT '--- UX_PTR_UUID ya existe.'
GO


/* ========================================================================
   2. INS_PERMISO_TRABAJO — con el cortocircuito por uuid
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
    @UUID            UNIQUEIDENTIFIER = NULL,
    @USUARIO         INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME

/* ---- El reintento se responde y se sale ----
   VA ANTES DE TODA VALIDACION. Ver el encabezado del bloque. */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODO permiso con uuid responderia "ya
       estaba registrado" y no se guardaria nada. Es el error que ya se
       cometio una vez en INS_INVENTARIO_MOVIMIENTO. */
    SET @ID = NULL

    SELECT @ID = ptr_id FROM [dbo].[Permiso_Trabajo]
     WHERE ptr_uuid = @UUID AND ptr_cliente = @CLIENTE

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID AS ID, 200 AS CODE, 'El permiso ya estaba registrado.' AS MENSAJE
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

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

/* Una vigencia al reves no es un error de dedo que se pueda dejar pasar: el
   permiso quedaria vencido el dia que nace y nadie entenderia por que. */
IF (@VIGENCIA_INICIO IS NOT NULL AND @VIGENCIA_FIN IS NOT NULL
    AND @VIGENCIA_FIN < @VIGENCIA_INICIO)
BEGIN
    RAISERROR('5.- LA VIGENCIA TERMINA ANTES DE EMPEZAR.', 16, 1)
    RETURN -1
END

/* AUTORIZADO EXIGE EL DOCUMENTO. LO DICE LA TABLA.

   CK_PTR_AUTORIZADO impide que un permiso este AUTORIZADO sin ptr_archivo, y
   es exactamente lo que pide la historia: la constancia ES el papel firmado,
   no la fila.

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
         ptr_observacion, ptr_archivo, ptr_uuid,
         ptr_usuario_creacion, ptr_fecha_creacion,
         ptr_usuario_actualizacion, ptr_fecha_actualizacion, ptr_habilitado)
    VALUES
        (@CLIENTE, @ORDEN_TRABAJO, @TIPO, @ESTADO,
         NULLIF(LTRIM(RTRIM(@NUMERO)), ''), ISNULL(@SOLICITANTE, @USUARIO), @AHORA,
         @VIGENCIA_INICIO, @VIGENCIA_FIN,
         @OBSERVACION, @ARCHIVO, @UUID,
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

PRINT '--- INS_PERMISO_TRABAJO recreado con @UUID.'
GO


/* ========================================================================
   3. SEL_PERMISO_TRABAJO devuelve el uuid

      La app lo necesita para reconocer lo que ella misma mando: sin el, no
      puede saber si el permiso que ve en la lista es el que tenia pendiente
      de confirmar.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PERMISO_TRABAJO') IS NOT NULL
BEGIN
    DECLARE @SQL NVARCHAR(MAX)

    SELECT @SQL = REPLACE(m.definition,
                          'SELECT  p.ptr_id,' + CHAR(13) + CHAR(10) + '                p.ptr_cliente,',
                          'SELECT  p.ptr_id,' + CHAR(13) + CHAR(10) +
                          '                p.ptr_uuid,' + CHAR(13) + CHAR(10) +
                          '                p.ptr_cliente,')
    FROM   sys.sql_modules m
    WHERE  m.object_id = OBJECT_ID('dbo.SEL_PERMISO_TRABAJO')

    /* Si el reemplazo no entro, NO se ejecuta nada: un sp_executesql con el
       texto sin cambiar recrearia el SP igual que estaba y el bloque diria
       que todo salio bien. Es el fallo silencioso del bloque 77. */
    IF (@SQL IS NULL OR CHARINDEX('p.ptr_uuid', @SQL) = 0)
    BEGIN
        PRINT '*** NO se pudo agregar ptr_uuid a SEL_PERMISO_TRABAJO: revisar a mano.'
    END
    ELSE
    BEGIN
        SET @SQL = STUFF(@SQL, 1, CHARINDEX('CREATE', @SQL) + 5, 'ALTER')
        EXEC sp_executesql @SQL
        PRINT '--- SEL_PERMISO_TRABAJO ahora devuelve ptr_uuid.'
    END
END
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
/* La variable de tabla va en su propio DECLARE: mezclarla con escalares da
   "Incorrect syntax near the keyword 'TABLE'". */
DECLARE @R TABLE (PASO NVARCHAR(40), RES NVARCHAR(200))
DECLARE @ID INT
DECLARE @U UNIQUEIDENTIFIER = NEWID()

/* Primera llamada: crea. */
EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 1, NULL, N'PT-IDEMP', NULL, NULL,
     NULL, NULL, N'Prueba de idempotencia.', NULL, @U, 1

INSERT @R VALUES ('primera llamada', 'id = ' + LTRIM(STR(@ID)))

DECLARE @PRIMERO INT = @ID

/* Segunda con el MISMO uuid: no crea, devuelve el mismo id. */
EXEC [dbo].[INS_PERMISO_TRABAJO] @ID OUTPUT, 1, 1, NULL, N'PT-IDEMP', NULL, NULL,
     NULL, NULL, N'Prueba de idempotencia.', NULL, @U, 1

INSERT @R VALUES ('reintento mismo uuid',
                  CASE WHEN @ID = @PRIMERO THEN 'mismo id ' + LTRIM(STR(@ID)) + ' (correcto)'
                       ELSE 'CREO OTRO: ' + LTRIM(STR(@ID)) + ' (mal)' END)

INSERT @R SELECT 'filas con ese numero', LTRIM(STR(COUNT(*)))
FROM [dbo].[Permiso_Trabajo] WHERE ptr_numero = 'PT-IDEMP'

SELECT * FROM @R

/* Se limpia la prueba. */
DELETE FROM [dbo].[Permiso_Trabajo] WHERE ptr_numero = 'PT-IDEMP'
GO

PRINT '96_PERMISO_TRABAJO_UUID aplicado.'
GO
