USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     FIRMAS Y VALIDACIONES DE UNA ORDEN (VISTA 6.7, HU-118).
-- =============================================
-- LA TABLA YA ESTABA, Y CALZA ENTERA
--
--   El traspaso decia «6.7 Firmas: no existe tabla ni ruta». La mitad era
--   cierta: no hay ruta. Pero `Orden_Trabajo_Validacion` existe desde el
--   modelo original y responde punto por punto a lo que pide la vista:
--
--     otv_validacion_tipo  -> aceptacion / ejecucion / validacion
--     otv_usuario          -> quien firma
--     otv_resultado        -> aceptada o rechazada
--     otv_fecha_utc        -> cuando
--     otv_observacion      -> el motivo del rechazo
--     otv_archivo_firma    -> la firma manuscrita, como Archivo
--
--   Y `Validacion_Tipo` ya trae los tres tipos cargados. Crear una tabla
--   nueva habria sido duplicar un modelo que alguien ya penso bien.
--
-- «NUEVA VALIDACION SIN ELIMINAR LA ANTERIOR»
--
--   Sale gratis: la tabla es de solo agregar. No hay UPDATE ni baja logica, y
--   este script no los agrega. Firmar dos veces deja dos filas, que es lo que
--   pide la vista y ademas lo unico defendible en una auditoria: una firma que
--   se puede reemplazar no prueba nada.
--
-- LO QUE SI FALTABA
--
--   0. NADA del vocabulario: `CK_OTV_RESULTADO` ya fija APROBADO/RECHAZADO y
--      este script NO lo toca. Se descubrio de la peor manera -inventando
--      ACEPTADA y viendo rebotar todos los INSERT- y quedo escrito abajo.
--   1. El `uuid`, para que la firma se pueda encolar. Toda captura de terreno
--      lleva uuid generado AL ENCOLAR, y el 409 se trata como exito: sin esa
--      columna, un tecnico que firma sin señal y reintenta firmaria dos veces.
--   2. Los dos SP.
--   3. El permiso VALIDAR ORDEN TRABAJO.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) El uuid que hace la firma reintentable
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Validacion]')
                  AND name = 'otv_uuid')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Validacion] ADD otv_uuid UNIQUEIDENTIFIER NULL
END
GO

-- Unico, pero FILTRADO: las filas que ya existan sin uuid -y las que escriba
-- la web, que no encola nada- no tienen por que inventarse uno.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UQ_OTV_UUID'
                  AND object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Validacion]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UQ_OTV_UUID]
        ON [dbo].[Orden_Trabajo_Validacion] (otv_uuid)
        WHERE otv_uuid IS NOT NULL
END
GO

-- ---------------------------------------------------------------------------
-- 2) El permiso
-- ---------------------------------------------------------------------------
--
-- Firmar no es ejecutar. Quien hace el trabajo puede dejar su firma de
-- EJECUCION, pero aceptar o validar es de quien responde por el resultado, y
-- eso ya lo separa el tipo de validacion. El permiso controla la puerta; el
-- tipo, que se firma.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VALIDAR ORDEN TRABAJO')
BEGIN
    /* El modulo y el ambito se copian de CERRAR OT: es el permiso hermano
       -quien cierra es quien valida- y dejarlo en otro modulo lo escondería
       de la pantalla de perfiles, donde se otorga. */
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
         prm_descripcion, prm_usuario_creacion, prm_fecha_creacion,
         prm_habilitado, prm_asignable_usuario)
    SELECT 'VALIDAR ORDEN TRABAJO',
           'Validar orden de trabajo',
           p.prm_modulo,
           p.prm_permiso_ambito,
           'Firmar la aceptación, la ejecución o la validación de una orden',
           p.prm_usuario_creacion,
           GETDATE(),
           1,
           p.prm_asignable_usuario
    FROM [dbo].[Permiso] p
    WHERE p.prm_codigo = 'CERRAR OT'
END
GO

-- Se otorga a los mismos perfiles que pueden CERRAR OT: quien responde por el
-- cierre es quien firma la validacion, y darselo a otros crearia una firma que
-- no significa nada.
DECLARE @PRM INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VALIDAR ORDEN TRABAJO')
DECLARE @CERRAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CERRAR OT')

IF (@PRM IS NOT NULL AND @CERRAR IS NOT NULL)
BEGIN
    INSERT INTO [dbo].[Perfil_Permiso]
        (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
    SELECT pp.ppe_perfil, @PRM, pp.ppe_usuario_creacion, GETDATE()
    FROM [dbo].[Perfil_Permiso] pp
    WHERE pp.ppe_permiso = @CERRAR
      AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x
                       WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @PRM)
END
GO

-- ---------------------------------------------------------------------------
-- 3) API_SEL_ORDEN_TRABAJO_VALIDACION — las firmas de una orden
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ORDEN_TRABAJO_VALIDACION]
@ORDEN      INT,
@CLIENTE    INT
AS
SET NOCOUNT ON

-- Barrera multicliente: la orden tiene que ser del cliente en sesion.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA ORDEN NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  otv.otv_id                  AS OTV_ID,
            otv.otv_orden_trabajo       AS OTV_ORDEN_TRABAJO,
            otv.otv_validacion_tipo     AS OTV_VALIDACION_TIPO,
            vat.vat_codigo              AS TIPO_CODIGO,
            vat.vat_nombre              AS TIPO_NOMBRE,
            otv.otv_usuario             AS OTV_USUARIO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' +
                        ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO_NOMBRE,
            /* El identificador, no el RUT: la columna se llama
               `usu_identificador` porque SIGMA es multi-pais y no todos los
               clientes firman con un RUT. Es el dato que hace que una firma
               identifique a una persona y no a un nombre repetido. */
            u.usu_identificador         AS USUARIO_IDENTIFICADOR,
            otv.otv_resultado           AS OTV_RESULTADO,
            otv.otv_fecha_utc           AS OTV_FECHA_UTC,
            otv.otv_observacion         AS OTV_OBSERVACION,
            arc.arc_ruta                AS FIRMA_RUTA
    FROM    [dbo].[Orden_Trabajo_Validacion] otv
    LEFT JOIN [dbo].[Validacion_Tipo] vat ON vat.vat_id = otv.otv_validacion_tipo
    LEFT JOIN [dbo].[Usuario]         u   ON u.usu_id   = otv.otv_usuario
    LEFT JOIN [dbo].[Archivo]         arc ON arc.arc_id = otv.otv_archivo_firma
    WHERE   otv.otv_orden_trabajo = @ORDEN
    /* De la mas nueva a la mas vieja: cuando hay dos validaciones del mismo
       tipo -una rechazada y despues una aceptada- la que manda es la ultima,
       y tiene que ser la primera que se ve. La anterior sigue ahi, debajo. */
    ORDER BY otv.otv_fecha_utc DESC, otv.otv_id DESC
GO

-- ---------------------------------------------------------------------------
-- 4) API_INS_ORDEN_TRABAJO_VALIDACION — firmar
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_VALIDACION]
@ID             INT = NULL OUTPUT,
@UUID           UNIQUEIDENTIFIER,
@ORDEN          INT,
@VALIDACION_TIPO INT,
@RESULTADO      NVARCHAR(40),
@OBSERVACION    NVARCHAR(MAX) = NULL,
@ARCHIVO_FIRMA  INT = NULL,
@USUARIO        INT,
@CLIENTE        INT
AS
SET NOCOUNT ON

BEGIN TRY

    /* IDEMPOTENTE POR EL UUID

       El telefono lo genera AL ENCOLAR, no al enviar. Una firma capturada sin
       señal se reintenta varias veces; sin esto quedarian tres firmas de la
       misma persona con tres segundos de diferencia, y la orden pareceria
       validada por triplicado. Se devuelve la que ya estaba. */
    DECLARE @YA INT = (SELECT otv_id FROM [dbo].[Orden_Trabajo_Validacion]
                        WHERE otv_uuid = @UUID)

    IF (@YA IS NOT NULL)
    BEGIN
        SET @ID = @YA
        SELECT @YA AS OTV_ID, 1 AS YA_ESTABA
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                    WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA ORDEN NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Validacion_Tipo]
                    WHERE vat_id = @VALIDACION_TIPO AND vat_habilitado = 1)
    BEGIN
        RAISERROR('2.- ESE TIPO DE VALIDACION NO EXISTE.', 16, 1)
        RETURN
    END

    /* EL VOCABULARIO LO PONE LA BASE, NO ESTE SP

       La tabla ya trae `CK_OTV_RESULTADO`, que solo admite APROBADO y
       RECHAZADO. La primera version de este SP validaba «ACEPTADA» y
       «RECHAZADA» -las palabras de la especificacion de la vista- y **todo
       INSERT rebotaba contra el CHECK**: el SP decia que si y la tabla decia
       que no.

       La regla vive en un solo sitio, y ese sitio es el CHECK. Aca solo se
       normaliza y se traduce un mensaje entendible, porque el error crudo del
       constraint no le dice nada a quien firma. */
    SET @RESULTADO = UPPER(LTRIM(RTRIM(ISNULL(@RESULTADO, N''))))

    -- Se acepta lo que dice la vista y se guarda lo que dice la base.
    IF (@RESULTADO IN (N'ACEPTADA', N'ACEPTADO', N'APROBADA')) SET @RESULTADO = N'APROBADO'
    IF (@RESULTADO = N'RECHAZADA') SET @RESULTADO = N'RECHAZADO'

    IF (@RESULTADO NOT IN (N'APROBADO', N'RECHAZADO'))
    BEGIN
        RAISERROR('3.- EL RESULTADO DEBE SER APROBADO O RECHAZADO.', 16, 1)
        RETURN
    END

    /* EL MOTIVO ES OBLIGATORIO AL RECHAZAR

       Un rechazo sin motivo obliga a ir a preguntarle a quien firmo, y en un
       turno de noche esa persona ya se fue. Es la misma regla que el cambio de
       estado de un activo, y se hace cumplir ACA para que valga tambien para
       la web. */
    IF (@RESULTADO = N'RECHAZADO' AND LTRIM(RTRIM(ISNULL(@OBSERVACION, N''))) = N'')
    BEGIN
        RAISERROR('4.- INDIQUE EL MOTIVO DEL RECHAZO.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Validacion]
        (otv_uuid, otv_orden_trabajo, otv_validacion_tipo, otv_usuario,
         otv_resultado, otv_fecha_utc, otv_observacion, otv_archivo_firma,
         otv_usuario_creacion, otv_fecha_creacion)
    VALUES
        (@UUID, @ORDEN, @VALIDACION_TIPO, @USUARIO,
         @RESULTADO, GETUTCDATE(), @OBSERVACION, @ARCHIVO_FIRMA,
         @USUARIO, GETDATE())

    SET @ID = SCOPE_IDENTITY()

    SELECT @ID AS OTV_ID, 0 AS YA_ESTABA

END TRY
BEGIN CATCH
    DECLARE @MSG NVARCHAR(2000) = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
END CATCH
GO

-- ---------------------------------------------------------------------------
-- 5) SEL_VALIDACION_TIPO — el catalogo para la hoja de firma
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_VALIDACION_TIPO]
@ID         INT = NULL,
@HABILITADO BIT = NULL
AS
SET NOCOUNT ON

    SELECT  vat_id          AS VAT_ID,
            vat_codigo      AS VAT_CODIGO,
            vat_nombre      AS VAT_NOMBRE,
            vat_orden       AS VAT_ORDEN,
            vat_habilitado  AS VAT_HABILITADO
    FROM    [dbo].[Validacion_Tipo]
    WHERE   (@ID IS NULL OR vat_id = @ID)
      AND   (@HABILITADO IS NULL OR vat_habilitado = @HABILITADO)
    ORDER BY ISNULL(vat_orden, 0), vat_id
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'otv_uuid = ' +
       CASE WHEN EXISTS (SELECT 1 FROM sys.columns
                          WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo_Validacion]')
                            AND name = 'otv_uuid') THEN 'OK' ELSE 'FALTA' END AS RESULTADO
UNION ALL
SELECT 'API_SEL_ORDEN_TRABAJO_VALIDACION = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_SEL_ORDEN_TRABAJO_VALIDACION]') IS NULL THEN 'FALTA' ELSE 'OK' END
UNION ALL
SELECT 'API_INS_ORDEN_TRABAJO_VALIDACION = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_INS_ORDEN_TRABAJO_VALIDACION]') IS NULL THEN 'FALTA' ELSE 'OK' END
UNION ALL
SELECT 'SEL_VALIDACION_TIPO = ' +
       CASE WHEN OBJECT_ID('[dbo].[SEL_VALIDACION_TIPO]') IS NULL THEN 'FALTA' ELSE 'OK' END
UNION ALL
SELECT 'Perfiles con VALIDAR ORDEN TRABAJO = ' +
       CAST((SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
             JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
             WHERE p.prm_codigo = 'VALIDAR ORDEN TRABAJO') AS VARCHAR)
GO
