USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  11-09-2026
-- DESCRIPTION:     SPRINT 4 - HU-090+ ESTRUCTURA DE LA PAUTA: VERSION BORRADOR, SECCIONES, ITEMS Y RANGOS.
-- =============================================
-- Permite armar el checklist "por dentro" desde la ficha de la pauta: agregar
-- secciones (Silos, Blowers...) y campos/items (presion, T C, nivel aceite...)
-- con su tipo, unidad y rangos min/max. Todo cuelga de la VERSION BORRADOR de la
-- plantilla (Checklist_Plantilla_Version, estado 1 = BORRADOR): mientras es
-- borrador se puede reescribir; al publicar se congela (otra HU).
--
-- El guardado usa estrategia REEMPLAZO: la ficha manda toda la estructura y el
-- controller limpia el borrador y re-inserta. Es simple y correcto para un
-- borrador (nada publicado depende de el).
--
-- Sigue PATRONES/ASP/BaseDatos/PATRON_SP.md. ES IDEMPOTENTE (CREATE OR ALTER).
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_CHECKLIST_ITEM_TIPO  (combo de tipos de campo)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_TIPO]
@ID          INT = NULL,
@HABILITADO  BIT = NULL
AS
SET NOCOUNT ON
    SELECT  cit.cit_id         AS CIT_ID
           ,cit.cit_codigo     AS CIT_CODIGO
           ,cit.cit_nombre     AS CIT_NOMBRE
           ,cit.cit_habilitado AS CIT_HABILITADO
    FROM    [dbo].[Checklist_Item_Tipo] cit
    WHERE   (@ID IS NULL OR cit.cit_id = @ID)
      AND   (@HABILITADO IS NULL OR cit.cit_habilitado = @HABILITADO)
    ORDER BY cit.cit_id
GO


/* ========================================================================
   2. GET_CHECKLIST_BORRADOR
      Devuelve la version BORRADOR editable de la plantilla; si no existe la
      crea (numero = ultimo + 1). Sella la fecha con FNC_PAIS_HORA.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[GET_CHECKLIST_BORRADOR]
@PLANTILLA  INT,
@USUARIO    INT,
@CREAR      BIT = 1,               -- 0 = solo lectura (no crea el borrador al abrir)
@VERSION    INT = NULL OUTPUT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @PLANTILLA
IF @CLIENTE IS NULL
BEGIN RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT TOP 1 @VERSION = cpv_id
FROM   [dbo].[Checklist_Plantilla_Version]
WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 1  -- BORRADOR
ORDER BY cpv_numero DESC

IF @VERSION IS NULL AND @CREAR = 1
BEGIN
    DECLARE @NUM INT
    SELECT @NUM = ISNULL(MAX(cpv_numero), 0) + 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @PLANTILLA

    INSERT [dbo].[Checklist_Plantilla_Version]
        (cpv_checklist_plantilla, cpv_numero, cpv_checklist_version_estado,
         cpv_usuario_creacion, cpv_fecha_creacion, cpv_usuario_actualizacion, cpv_fecha_actualizacion, cpv_habilitado)
    VALUES
        (@PLANTILLA, @NUM, 1, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
    SET @VERSION = SCOPE_IDENTITY()
END

SELECT @VERSION AS VERSION
GO


/* ========================================================================
   3. LIMPIAR_CHECKLIST_BORRADOR
      Borra secciones, items, opciones y rangos de una version BORRADOR, para
      re-armarla desde la ficha. Solo actua si la version es BORRADOR.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[LIMPIAR_CHECKLIST_BORRADOR]
@VERSION  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version]
                WHERE cpv_id = @VERSION AND cpv_checklist_version_estado = 1)
BEGIN RAISERROR('1.- LA VERSION NO EXISTE O NO ES BORRADOR.', 16, 1) RETURN -1 END

BEGIN TRAN
    DELETE civ FROM [dbo].[Checklist_Item_Validacion] civ
        JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = civ.civ_checklist_plantilla_item
        WHERE i.cpi_checklist_plantilla_version = @VERSION
    DELETE cio FROM [dbo].[Checklist_Item_Opcion] cio
        JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = cio.cio_checklist_plantilla_item
        WHERE i.cpi_checklist_plantilla_version = @VERSION
    DELETE FROM [dbo].[Checklist_Plantilla_Item]    WHERE cpi_checklist_plantilla_version = @VERSION
    DELETE FROM [dbo].[Checklist_Plantilla_Seccion] WHERE cps_checklist_plantilla_version = @VERSION
COMMIT
GO


/* ========================================================================
   4. INS_CHECKLIST_SECCION
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_SECCION]
@ID         INT = NULL OUTPUT,
@VERSION    INT,
@CODIGO     NVARCHAR(50),
@NOMBRE     NVARCHAR(200),
@ORDEN      INT = 1,
@USUARIO    INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Plantilla_Seccion]
        (cps_checklist_plantilla_version, cps_codigo, cps_nombre, cps_orden,
         cps_usuario_creacion, cps_fecha_creacion, cps_usuario_actualizacion, cps_fecha_actualizacion, cps_habilitado)
    VALUES
        (@VERSION, @CODIGO, @NOMBRE, @ORDEN, @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_SECCION', @MSG = '1.- NO FUE POSIBLE INSERTAR LA SECCION.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   5. INS_CHECKLIST_ITEM
      Un campo del checklist. genera_medicion se deja en 0 aqui: mandar el
      valor a la serie del activo exige la variable de UN activo concreto, que
      se resuelve al ejecutar la pauta, no al disenarla. Los rangos van en la
      validacion (SP 6).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_ITEM]
@ID                 INT = NULL OUTPUT,
@VERSION            INT,
@SECCION            INT = NULL,
@CODIGO             NVARCHAR(50),
@TEXTO              NVARCHAR(500),
@TIPO               INT,
@ORDEN              INT = 1,
@OBLIGATORIO        BIT = 1,
@PERMITE_COMENTARIO BIT = 1,
@REQUIERE_EVIDENCIA BIT = 0,
@UNIDAD             INT = NULL,
@USUARIO            INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Plantilla_Item]
        (cpi_checklist_plantilla_version, cpi_checklist_plantilla_seccion, cpi_codigo, cpi_texto,
         cpi_checklist_item_tipo, cpi_orden, cpi_obligatorio, cpi_permite_comentario, cpi_requiere_evidencia,
         cpi_unidad_medida, cpi_genera_medicion,
         cpi_usuario_creacion, cpi_fecha_creacion, cpi_usuario_actualizacion, cpi_fecha_actualizacion, cpi_habilitado)
    VALUES
        (@VERSION, @SECCION, @CODIGO, @TEXTO,
         @TIPO, @ORDEN, @OBLIGATORIO, @PERMITE_COMENTARIO, @REQUIERE_EVIDENCIA,
         @UNIDAD, 0,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_ITEM', @MSG = '1.- NO FUE POSIBLE INSERTAR EL CAMPO.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   6. INS_CHECKLIST_VALIDACION  (los rangos min/max/advertencia/critico)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_VALIDACION]
@ITEM           INT,
@MINIMO         DECIMAL(18,6) = NULL,
@MAXIMO         DECIMAL(18,6) = NULL,
@ADVERTENCIA    DECIMAL(18,6) = NULL,
@CRITICO        DECIMAL(18,6) = NULL,
@GENERA_ALERTA  BIT = 1,
@USUARIO        INT
AS
SET NOCOUNT ON

-- Sin ningun umbral no hay validacion que guardar.
IF (@MINIMO IS NULL AND @MAXIMO IS NULL AND @ADVERTENCIA IS NULL AND @CRITICO IS NULL)
    RETURN(0)

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Item_Validacion]
        (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_valor_advertencia, civ_valor_critico,
         civ_genera_alerta, civ_requiere_comentario_fuera_rango,
         civ_usuario_creacion, civ_fecha_creacion, civ_usuario_actualizacion, civ_fecha_actualizacion, civ_habilitado)
    VALUES
        (@ITEM, @MINIMO, @MAXIMO, @ADVERTENCIA, @CRITICO,
         @GENERA_ALERTA, 1,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_VALIDACION', @MSG = '1.- NO FUE POSIBLE INSERTAR EL RANGO.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   7. SEL_CHECKLIST_SECCION  (secciones de una version)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_SECCION]
@VERSION  INT
AS
SET NOCOUNT ON
    SELECT  cps.cps_id       AS CPS_ID
           ,cps.cps_codigo   AS CPS_CODIGO
           ,cps.cps_nombre   AS CPS_NOMBRE
           ,cps.cps_orden    AS CPS_ORDEN
    FROM    [dbo].[Checklist_Plantilla_Seccion] cps
    WHERE   cps.cps_checklist_plantilla_version = @VERSION
    ORDER BY cps.cps_orden, cps.cps_id
GO


/* ========================================================================
   8. SEL_CHECKLIST_ITEM  (campos de una version, con su tipo, unidad y rangos)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM]
@VERSION  INT
AS
SET NOCOUNT ON
    SELECT  cpi.cpi_id                          AS CPI_ID
           ,cpi.cpi_checklist_plantilla_seccion AS CPI_SECCION
           ,cpi.cpi_codigo                      AS CPI_CODIGO
           ,cpi.cpi_texto                       AS CPI_TEXTO
           ,cpi.cpi_checklist_item_tipo         AS CPI_TIPO
           ,cit.cit_nombre                      AS TIPO_NOMBRE
           ,cpi.cpi_orden                       AS CPI_ORDEN
           ,cpi.cpi_obligatorio                 AS CPI_OBLIGATORIO
           ,cpi.cpi_permite_comentario          AS CPI_PERMITE_COMENTARIO
           ,cpi.cpi_requiere_evidencia          AS CPI_REQUIERE_EVIDENCIA
           ,cpi.cpi_unidad_medida               AS CPI_UNIDAD
           ,ISNULL(ume.ume_simbolo, '')         AS UNIDAD_SIMBOLO
           ,civ.civ_valor_minimo                AS RANGO_MINIMO
           ,civ.civ_valor_maximo                AS RANGO_MAXIMO
           ,civ.civ_valor_advertencia           AS RANGO_ADVERTENCIA
           ,civ.civ_valor_critico               AS RANGO_CRITICO
    FROM    [dbo].[Checklist_Plantilla_Item] cpi
    JOIN    [dbo].[Checklist_Item_Tipo] cit ON cit.cit_id = cpi.cpi_checklist_item_tipo
    LEFT JOIN [dbo].[Unidad_Medida] ume       ON ume.ume_id = cpi.cpi_unidad_medida
    LEFT JOIN [dbo].[Checklist_Item_Validacion] civ ON civ.civ_checklist_plantilla_item = cpi.cpi_id
    WHERE   cpi.cpi_checklist_plantilla_version = @VERSION
    ORDER BY cpi.cpi_orden, cpi.cpi_id
GO


PRINT '192_SPRINT4_CHECKLIST_ESTRUCTURA aplicado: SP de version borrador, secciones, items y rangos.'
GO
