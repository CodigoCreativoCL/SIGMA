USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  21-09-2026
-- DESCRIPTION:     SPRINT 4 - HU-093 PUBLICAR UNA VERSION DE CHECKLIST. PROCESO Y CONSULTA.
-- =============================================
-- Publica el BORRADOR de una pauta: lo pasa a PUBLICADO, retira la version
-- publicada anterior y sella quien publico y cuando. Las reglas viven en el SP
-- (T-4190) para que web y API den el mismo resultado.
--
--   T-4188  Revision del modelo Checklist_Plantilla_Version: el unico por
--           (plantilla, numero) es UX_CPV_PLANTILLA_NUMERO (garantizado abajo).
--   T-4189  PUBLICAR_CHECKLIST_VERSION: proceso completo en transaccion con
--           SET XACT_ABORT ON.
--   T-4190  Reglas de negocio en el SP: retira la publicada anterior (CA1) y
--           rechaza publicar sin items (CA2).
--   T-4191  SEL_CHECKLIST_VERSION: consultar el resultado (historial de versiones).
--
-- La reconstruccion historica (CA3) ya la da el modelo: al publicar se CONGELA
-- la version (sus secciones, items, unidades y umbrales), asi que una ejecucion
-- vieja sigue apuntando a su version y muestra lo de entonces.
--
-- Sigue PATRONES/ASP/BaseDatos/PATRON_SP.md. ES IDEMPOTENTE (CREATE OR ALTER).
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-4188 - REVISION DEL MODELO Checklist_Plantilla_Version
      Unico por (plantilla, numero). Se garantiza idempotente por si faltara.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_CPV_PLANTILLA_NUMERO'
                  AND object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla_Version]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_CPV_PLANTILLA_NUMERO
        ON [dbo].[Checklist_Plantilla_Version] ([cpv_checklist_plantilla], [cpv_numero])
    PRINT '--- Indice unico UX_CPV_PLANTILLA_NUMERO creado.'
END
ELSE
    PRINT '--- Indice unico UX_CPV_PLANTILLA_NUMERO ya existe (bloque 15). OK.'
GO


/* ========================================================================
   T-4189 / T-4190 - PUBLICAR_CHECKLIST_VERSION
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[PUBLICAR_CHECKLIST_VERSION]
@PLANTILLA      INT,
@CLIENTE        INT,
@OBSERVACION    NVARCHAR(MAX) = NULL,
@USUARIO        INT,
@VERSION        INT = NULL OUTPUT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @PRC_CLIENTE INT, @BORRADOR INT, @ITEMS INT

-- Validaciones de negocio ANTES de la transaccion.
SELECT @PRC_CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @PLANTILLA
IF @PRC_CLIENTE IS NULL
BEGIN RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1) RETURN -1 END
IF @PRC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('2.- LA PLANTILLA PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

-- La version en borrador (la mas nueva si hubiera mas de una).
SELECT TOP 1 @BORRADOR = cpv_id
FROM   [dbo].[Checklist_Plantilla_Version]
WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 1  -- BORRADOR
ORDER BY cpv_numero DESC

IF @BORRADOR IS NULL
BEGIN RAISERROR('3.- NO HAY UNA VERSION EN BORRADOR PARA PUBLICAR.', 16, 1) RETURN -1 END

-- CA2: no se publica una version sin items.
SELECT @ITEMS = COUNT(*) FROM [dbo].[Checklist_Plantilla_Item]
WHERE  cpi_checklist_plantilla_version = @BORRADOR AND cpi_habilitado = 1
IF @ITEMS = 0
BEGIN RAISERROR('4.- NO SE PUEDE PUBLICAR UNA VERSION SIN ITEMS.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    -- CA1: la version publicada anterior pasa a RETIRADA.
    UPDATE [dbo].[Checklist_Plantilla_Version]
    SET    cpv_checklist_version_estado = 3,   -- RETIRADO
           cpv_fecha_retiro = @DATE_NOW,
           cpv_usuario_actualizacion = @USUARIO, cpv_fecha_actualizacion = @DATE_NOW
    WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 2  -- PUBLICADO

    -- El borrador pasa a PUBLICADO, con quien publico y cuando (CA1).
    UPDATE [dbo].[Checklist_Plantilla_Version]
    SET    cpv_checklist_version_estado = 2,   -- PUBLICADO
           cpv_fecha_publicacion = @DATE_NOW,
           cpv_usuario_publicacion = @USUARIO,
           cpv_observacion = ISNULL(@OBSERVACION, cpv_observacion),
           cpv_usuario_actualizacion = @USUARIO, cpv_fecha_actualizacion = @DATE_NOW
    WHERE  cpv_id = @BORRADOR

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'PUBLICAR_CHECKLIST_VERSION @PLANTILLA = ' + LTRIM(STR(@PLANTILLA))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '5.- NO FUE POSIBLE PUBLICAR LA VERSION.'
        RETURN -1
    END

    SET @VERSION = @BORRADOR

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- PUBLICAR_CHECKLIST_VERSION creado.'
GO


/* ========================================================================
   T-4191 - SEL_CHECKLIST_VERSION  (historial de versiones de una pauta)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_VERSION]
@ID          INT = NULL,
@PLANTILLA   INT = NULL,
@CLIENTE     INT = NULL

AS
SET NOCOUNT ON

    SELECT  cpv.cpv_id                          AS CPV_ID
           ,cpv.cpv_checklist_plantilla         AS CPV_CHECKLIST_PLANTILLA
           ,cpv.cpv_numero                      AS CPV_NUMERO
           ,cpv.cpv_checklist_version_estado    AS CPV_ESTADO
           ,cve.cve_nombre                      AS ESTADO_NOMBRE
           ,cpv.cpv_fecha_publicacion           AS CPV_FECHA_PUBLICACION
           ,cpv.cpv_fecha_retiro                AS CPV_FECHA_RETIRO
           ,ISNULL(cpv.cpv_observacion, '')     AS CPV_OBSERVACION
           ,cpl.cpl_codigo                      AS PLANTILLA_CODIGO
           ,cpl.cpl_nombre                      AS PLANTILLA_NOMBRE
           ,(SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i
              WHERE i.cpi_checklist_plantilla_version = cpv.cpv_id AND i.cpi_habilitado = 1) AS ITEMS
           ,(SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Seccion] s
              WHERE s.cps_checklist_plantilla_version = cpv.cpv_id) AS SECCIONES
           ,LTRIM(RTRIM(ISNULL(up.usu_nombre, '') + ' ' + ISNULL(up.usu_apellido_paterno, ''))) AS USUARIO_PUBLICACION_NOMBRE
    FROM    [dbo].[Checklist_Plantilla_Version] cpv
    JOIN    [dbo].[Checklist_Plantilla] cpl        ON cpl.cpl_id = cpv.cpv_checklist_plantilla
    JOIN    [dbo].[Checklist_Version_Estado] cve   ON cve.cve_id = cpv.cpv_checklist_version_estado
    LEFT JOIN [dbo].[Usuario] up                   ON up.usu_id  = cpv.cpv_usuario_publicacion
    WHERE   (@ID IS NULL OR cpv.cpv_id = @ID)
      AND   (@PLANTILLA IS NULL OR cpv.cpv_checklist_plantilla = @PLANTILLA)
      AND   (@CLIENTE IS NULL OR cpl.cpl_cliente = @CLIENTE)
    ORDER BY cpv.cpv_numero DESC
GO
PRINT '--- SEL_CHECKLIST_VERSION creado.'
GO

PRINT '195_SPRINT4_CHECKLIST_VERSION aplicado.'
GO
