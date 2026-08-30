USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     BLOQUE C.1 SPs DE ARCHIVO PARA EL COMPROBANTE DE PAGO.
-- =============================================
-- Va DESPUES de 41_SUSCRIPCION_SPS.
--
-- POR QUE ESTE BLOQUE EXISTE
--   INS_SUSCRIPCION_PAGO exige @ARCHIVO y valida que la fila exista en
--   Archivo: sin comprobante no hay pago (ANEXO F 5.3). Pero en la base
--   NO HAY ningun SP para crear esa fila. Los INS_ARCHIVO / SEL_ARCHIVO
--   heredados se eliminaron en 00_SANEAMIENTO porque escribian contra
--   Archivo_Binario, una tabla que el modelo de SIGMA ya no tiene.
--
--   Sin este bloque la pantalla de pagos no se puede construir: el pago
--   siempre fallaria en la validacion 2 del SP.
--
-- DONDE VIVE EL BINARIO
--   En Blob Storage, no en la base. Lo permitia el modelo (18_ARCHIVOS):
--   la fila guarda ruta, hash, tamano y mime, no el contenido. La base no
--   crece con fotos de terreno, que es lo que este sistema va a acumular
--   en cuanto entren las ordenes de trabajo.
--
--   arc_ruta guarda la RUTA DEL BLOB (contenedor/carpeta/nombre), no una
--   URL firmada ni una ruta de disco. Una URL con token caduca; una ruta
--   de disco ata el sistema a la maquina. La ruta relativa sobrevive a que
--   cambie la cuenta de almacenamiento o el dominio.
--
--   Quien sube y baja el binario NO es esta base ni la web directamente:
--   es la API de servicios Azure que se construye aparte, y que tambien
--   sirve a la app movil. La web le pide la subida y guarda aqui lo que
--   esa API devuelve.
--
--   Consecuencia que hay que tener presente: dar de baja la fila NO borra
--   el blob, y borrar el blob deja la fila apuntando a la nada. Por eso
--   DEL_ARCHIVO es baja logica.
--
-- EL ANTIVIRUS
--   arc_archivo_antivirus_estado nace en 1 = PENDIENTE. No hay antivirus
--   conectado todavia. Se deja en pendiente y no en LIMPIO a proposito:
--   marcar limpio algo que nadie reviso seria mentirle al dia en que si
--   haya un antivirus.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. CATEGORIA "COMPROBANTE PAGO"

      Existe la categoria 9 DOCUMENTO, que serviria. No se reutiliza: un
      comprobante de transferencia es lo unico que puede colgar de un pago,
      y con la categoria generica no habria como distinguirlo de cualquier
      otro adjunto del cliente al revisar la bandeja o al auditar. El
      catalogo esta hecho para esto -tiene aca_cliente NULL para las
      globales- y agregar un valor es la operacion barata.
   ======================================================================== */

SET IDENTITY_INSERT [dbo].[Archivo_Categoria] ON
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 12)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_cliente], [aca_codigo], [aca_nombre], [aca_icono], [aca_orden])
    VALUES (12, NULL, N'COMPROBANTE PAGO', N'Comprobante de pago', N'mdi mdi-receipt-text-outline', 12)
GO

SET IDENTITY_INSERT [dbo].[Archivo_Categoria] OFF
GO


/* ========================================================================
   2. INS_ARCHIVO

      Registra un archivo YA SUBIDO al Blob Storage. El SP no maneja
      binarios: recibe la ruta del blob y los metadatos. El orden importa
      -primero el blob, despues la fila- porque una fila sin blob es un
      enlace roto silencioso, y un blob sin fila es basura recuperable.

      @HASH permite deduplicar. NO se deduplica aqui: dos pagos distintos
      pueden adjuntar la misma cartola y cada uno necesita su propia fila
      para que dar de baja uno no deje al otro sin comprobante. El hash
      queda para que un dia se pueda limpiar el contenedor sabiendo que
      copias apuntan al mismo contenido.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ARCHIVO]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@CATEGORIA         INT,
@NOMBRE_ORIGINAL   NVARCHAR(255),
@NOMBRE_ALMACENADO NVARCHAR(255),
@RUTA              NVARCHAR(500),   -- ruta del blob: contenedor/carpeta/nombre
@MIME              NVARCHAR(100) = NULL,
@EXTENSION         NVARCHAR(20) = NULL,
@BYTE              BIGINT,
@HASH              NVARCHAR(64) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* La categoria puede ser global (aca_cliente NULL) o propia del
       cliente. Una categoria de OTRO cliente no sirve. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria]
                    WHERE aca_id = @CATEGORIA
                      AND aca_habilitado = 1
                      AND (aca_cliente IS NULL OR aca_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- LA CATEGORÍA DE ARCHIVO NO EXISTE O NO PERTENECE AL CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @BYTE IS NULL OR @BYTE <= 0
    BEGIN
        RAISERROR('3.- EL ARCHIVO ESTÁ VACÍO.', 16, 1)
        RETURN -1
    END

    IF @RUTA IS NULL OR LEN(LTRIM(@RUTA)) = 0
    BEGIN
        RAISERROR('4.- FALTA LA RUTA DEL BLOB.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Archivo]
        (arc_cliente, arc_archivo_categoria, arc_nombre_original, arc_nombre_almacenado,
         arc_ruta, arc_mime, arc_extension, arc_byte, arc_hash,
         arc_archivo_antivirus_estado,
         arc_usuario_creacion, arc_fecha_creacion,
         arc_usuario_actualizacion, arc_fecha_actualizacion, arc_habilitado)
    VALUES
        (@CLIENTE, @CATEGORIA, @NOMBRE_ORIGINAL, @NOMBRE_ALMACENADO,
         @RUTA, @MIME, @EXTENSION, @BYTE, @HASH,
         1,                                  -- 1 = PENDIENTE de antivirus
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ARCHIVO @CLIENTE = ' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '5.- NO FUE POSIBLE REGISTRAR EL ARCHIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. SEL_ARCHIVO

      Devuelve los metadatos, no el contenido. Quien tenga que servir el
      archivo lee arc_ruta y pide el blob a la API de almacenamiento.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ARCHIVO]
@ID         INT = NULL,
@UUID       UNIQUEIDENTIFIER = NULL,
@CLIENTE    INT = NULL,
@CATEGORIA  INT = NULL,
@HABILITADO BIT = NULL

AS
SET NOCOUNT ON

    SELECT  a.arc_id                       AS ARC_ID,
            a.arc_uuid                     AS ARC_UUID,
            a.arc_cliente                  AS ARC_CLIENTE,
            a.arc_archivo_categoria        AS ARC_ARCHIVO_CATEGORIA,
            ca.aca_nombre                  AS ACA_NOMBRE,
            a.arc_nombre_original          AS ARC_NOMBRE_ORIGINAL,
            a.arc_nombre_almacenado        AS ARC_NOMBRE_ALMACENADO,
            a.arc_ruta                     AS ARC_RUTA,
            a.arc_mime                     AS ARC_MIME,
            a.arc_extension                AS ARC_EXTENSION,
            a.arc_byte                     AS ARC_BYTE,
            a.arc_hash                     AS ARC_HASH,
            a.arc_archivo_antivirus_estado AS ARC_ANTIVIRUS_ESTADO,
            av.aae_nombre                  AS AAE_NOMBRE,
            a.arc_fecha_creacion           AS ARC_FECHA_CREACION,
            a.arc_habilitado               AS ARC_HABILITADO
    FROM    [dbo].[Archivo] a
    INNER JOIN [dbo].[Archivo_Categoria] ca        ON ca.aca_id = a.arc_archivo_categoria
    INNER JOIN [dbo].[Archivo_Antivirus_Estado] av ON av.aae_id = a.arc_archivo_antivirus_estado
    WHERE   (@ID IS NULL OR a.arc_id = @ID)
      AND   (@UUID IS NULL OR a.arc_uuid = @UUID)
      AND   (@CLIENTE IS NULL OR a.arc_cliente = @CLIENTE)
      AND   (@CATEGORIA IS NULL OR a.arc_archivo_categoria = @CATEGORIA)
      AND   (@HABILITADO IS NULL OR a.arc_habilitado = @HABILITADO)
    ORDER BY a.arc_fecha_creacion DESC

RETURN(0)
GO


/* ========================================================================
   4. DEL_ARCHIVO

      Baja LOGICA. El blob no se toca: puede estar referenciado
      desde un comprobante de pago de hace dos anos, y esos no se borran.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ARCHIVO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Archivo]
    SET     arc_habilitado            = 0,
            arc_usuario_actualizacion = @USUARIO,
            arc_fecha_actualizacion   = GETDATE()
    WHERE   arc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_ARCHIVO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE ELIMINAR EL ARCHIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs de archivo' AS control, COUNT(*) AS valor, 3 AS esperado
FROM   sys.procedures
WHERE  name IN ('INS_ARCHIVO','SEL_ARCHIVO','DEL_ARCHIVO')
UNION ALL
SELECT 'Categoría COMPROBANTE PAGO', COUNT(*), 1
FROM   [dbo].[Archivo_Categoria] WHERE aca_codigo = N'COMPROBANTE PAGO'
GO
