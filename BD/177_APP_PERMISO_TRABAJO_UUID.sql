USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     IDEMPOTENCIA POR UUID EN EL ALTA DE PERMISO DE TRABAJO.
-- =============================================
-- El controller ya mandaba @UUID y el SP no lo declaraba, asi que CADA alta
-- de permiso desde la app fallaba. La columna ptr_uuid ya estaba en la tabla;
-- faltaban el parametro y el corte por reintento.
--
-- Se detecto cruzando los 71 `Datos.Ejecutar` de los controllers contra
-- sys.parameters: era uno de los tres desajustes de nombre que quedaban.
-- =============================================
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_PERMISO_TRABAJO]
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
    /* IDEMPOTENCIA (07-09-2026). La app encola cada escritura con un uuid
       generado AL ENCOLAR y reintenta hasta que el servidor da un veredicto;
       sin este parametro un reintento creaba un permiso duplicado. El
       controller ya lo mandaba —y por eso TODA alta fallaba con "no existe el
       parametro @UUID"—, y la columna ptr_uuid ya estaba en la tabla: solo
       faltaba aca. Es opcional, asi que la web sigue llamando igual. */
    @UUID            UNIQUEIDENTIFIER = NULL,
    @USUARIO         INT
AS
SET NOCOUNT ON

/* ---- Idempotencia: si el uuid ya paso, no se repite ----
   Va ANTES de cualquier validacion, igual que en INS_INVENTARIO_MOVIMIENTO:
   un reintento no tiene por que volver a pasar reglas que ya paso, y si
   entretanto la vigencia quedo vencida, la segunda llamada fallaria por algo
   que ya estaba hecho. */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODO permiso con uuid responderia "ya
       estaba registrado" y no se guardaria ninguno. */
    SET @ID = NULL

    SELECT @ID = ptr_id FROM [dbo].[Permiso_Trabajo] WHERE ptr_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'El permiso ya estaba registrado.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

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

/* Una vigencia al rev�s no es un error de dedo que se pueda dejar pasar: el
   permiso quedar�a vencido el d�a que nace y nadie entender�a por qu�. */
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

SELECT @ID AS ID, 200 AS CODE, 'Permiso de trabajo registrado con �xito.' AS MENSAJE
GO
