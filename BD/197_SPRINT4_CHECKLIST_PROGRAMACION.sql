USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 - HU-094 PROGRAMAR UN CHECKLIST RECURRENTE. SEL/INS/UPD.
-- =============================================
-- Una programacion enlaza una PAUTA (su version publicada) con una RECURRENCIA
-- (Programacion) sobre un OBJETIVO (activo o area) y opcionalmente un grupo y un
-- responsable. Reglas en el SP (para que web y API coincidan):
--   T-4199  Modelo Checklist_Programacion: FK a version, programacion, activo,
--           area, grupo y responsable. PK cpr_id; no hay unico natural (una
--           misma version puede programarse en varios activos/areas).
--   T-4200  INS_CHECKLIST_PROGRAMACION: alta transaccional. Resuelve la version
--           PUBLICADA de la pauta; exige activo O area (CA3); sella FNC_PAIS_HORA.
--   T-4201  SEL_CHECKLIST_PROGRAMACION: patron dinamico, un solo SP grilla+ficha.
--   T-4202  UPD_CHECKLIST_PROGRAMACION: edicion con ISNULL(@X, columna).
--   T-4203  Datos de prueba.
--
-- CA1/CA2 (generar una ocurrencia por dia sobre el activo/area) es trabajo del
-- generador de ocurrencias (proceso servidor), no de este CRUD.
--
-- Sigue PATRONES/ASP/BaseDatos/PATRON_SP.md. ES IDEMPOTENTE (CREATE OR ALTER).
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-4200 - INS_CHECKLIST_PROGRAMACION
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_PROGRAMACION]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CHECKLIST_PLANTILLA    INT,                 -- la pauta; se resuelve su version publicada
@PROGRAMACION           INT,                 -- la recurrencia (Programacion)
@ACTIVO                 INT = NULL,
@INSTALACION_AREA       INT = NULL,
@GRUPO_TRABAJO          INT = NULL,
@USUARIO_RESPONSABLE    INT = NULL,
@NOMBRE                 NVARCHAR(200),
@USUARIO                INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @VERSION INT

SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

-- CA3: sin objetivo (ni activo ni area) se rechaza.
IF @ACTIVO IS NULL AND @INSTALACION_AREA IS NULL
BEGIN RAISERROR('1.- INDIQUE UN OBJETIVO: UN ACTIVO O UN AREA.', 16, 1) RETURN -1 END

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN RAISERROR('2.- INDIQUE EL NOMBRE DE LA PROGRAMACION.', 16, 1) RETURN -1 END

-- La pauta tiene que existir en el cliente y tener una version PUBLICADA.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @CHECKLIST_PLANTILLA AND cpl_cliente = @CLIENTE)
BEGIN RAISERROR('3.- LA PAUTA NO EXISTE EN ESTE CLIENTE.', 16, 1) RETURN -1 END

SELECT TOP 1 @VERSION = cpv_id FROM [dbo].[Checklist_Plantilla_Version]
WHERE  cpv_checklist_plantilla = @CHECKLIST_PLANTILLA AND cpv_checklist_version_estado = 2  -- PUBLICADO
ORDER BY cpv_numero DESC
IF @VERSION IS NULL
BEGIN RAISERROR('4.- LA PAUTA NO TIENE UNA VERSION PUBLICADA. PUBLIQUELA ANTES DE PROGRAMARLA.', 16, 1) RETURN -1 END

-- El objetivo, si se indica, es del mismo cliente.
IF @ACTIVO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN RAISERROR('5.- EL ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END
IF @INSTALACION_AREA IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM [dbo].[Instalacion_Area] ia
        JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ia.iar_cliente_instalacion
        WHERE ia.iar_id = @INSTALACION_AREA AND ci.cin_cliente = @CLIENTE)
BEGIN RAISERROR('6.- EL AREA NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    INSERT [dbo].[Checklist_Programacion]
        (cpr_cliente, cpr_checklist_plantilla_version, cpr_programacion,
         cpr_activo, cpr_instalacion_area, cpr_grupo_trabajo, cpr_usuario_responsable, cpr_nombre,
         cpr_usuario_creacion, cpr_fecha_creacion, cpr_usuario_actualizacion, cpr_fecha_actualizacion, cpr_habilitado)
    VALUES
        (@CLIENTE, @VERSION, @PROGRAMACION,
         @ACTIVO, @INSTALACION_AREA, @GRUPO_TRABAJO, @USUARIO_RESPONSABLE, @NOMBRE,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CHECKLIST_PROGRAMACION @CLIENTE = ' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '7.- NO FUE POSIBLE INSERTAR LA PROGRAMACION.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- INS_CHECKLIST_PROGRAMACION creado.'
GO


/* ========================================================================
   T-4201 - SEL_CHECKLIST_PROGRAMACION
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_PROGRAMACION]
@ID                     INT = NULL,
@CLIENTE                INT = NULL,
@CHECKLIST_PLANTILLA    INT = NULL,
@ACTIVO                 INT = NULL,
@HABILITADO             BIT = NULL,
@FILTRO                 VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT cpr.cpr_id                        AS CPR_ID
                                  ,cpr.cpr_cliente                    AS CPR_CLIENTE
                                  ,cpr.cpr_checklist_plantilla_version AS CPR_VERSION
                                  ,cpv.cpv_checklist_plantilla        AS CPR_CHECKLIST_PLANTILLA
                                  ,cpv.cpv_numero                     AS VERSION_NUMERO
                                  ,cpr.cpr_programacion               AS CPR_PROGRAMACION
                                  ,cpr.cpr_activo                     AS CPR_ACTIVO
                                  ,cpr.cpr_instalacion_area           AS CPR_INSTALACION_AREA
                                  ,cpr.cpr_grupo_trabajo              AS CPR_GRUPO_TRABAJO
                                  ,cpr.cpr_usuario_responsable        AS CPR_USUARIO_RESPONSABLE
                                  ,cpr.cpr_nombre                     AS CPR_NOMBRE
                                  ,cpr.cpr_usuario_creacion           AS CPR_USUARIO_CREACION
                                  ,cpr.cpr_fecha_creacion             AS CPR_FECHA_CREACION
                                  ,cpr.cpr_usuario_actualizacion      AS CPR_USUARIO_ACTUALIZACION
                                  ,cpr.cpr_fecha_actualizacion        AS CPR_FECHA_ACTUALIZACION
                                  ,cpr.cpr_habilitado                 AS CPR_HABILITADO
                                  ,cpl.cpl_codigo                     AS PAUTA_CODIGO
                                  ,cpl.cpl_nombre                     AS PAUTA_NOMBRE
                                  ,ISNULL(pro.pro_nombre, '''')       AS PROGRAMACION_NOMBRE
                                  ,ISNULL(act.act_codigo, '''')       AS ACTIVO_CODIGO
                                  ,ISNULL(act.act_nombre, '''')       AS ACTIVO_NOMBRE
                                  ,ISNULL(iar.iar_nombre, '''')       AS AREA_NOMBRE
                                  ,ISNULL(gtr.gtr_nombre, '''')       AS GRUPO_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ur.usu_nombre, '''') + '' '' + ISNULL(ur.usu_apellido_paterno, ''''))) AS RESPONSABLE_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Checklist_Programacion] cpr
                  JOIN [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = cpr.cpr_checklist_plantilla_version
                  JOIN [dbo].[Checklist_Plantilla] cpl         ON cpl.cpl_id = cpv.cpv_checklist_plantilla
                  LEFT JOIN [dbo].[Programacion] pro           ON pro.pro_id = cpr.cpr_programacion
                  LEFT JOIN [dbo].[Activo] act                 ON act.act_id = cpr.cpr_activo
                  LEFT JOIN [dbo].[Instalacion_Area] iar       ON iar.iar_id = cpr.cpr_instalacion_area
                  LEFT JOIN [dbo].[Grupo_Trabajo] gtr          ON gtr.gtr_id = cpr.cpr_grupo_trabajo
                  LEFT JOIN [dbo].[Usuario] ur                 ON ur.usu_id  = cpr.cpr_usuario_responsable
                  LEFT JOIN [dbo].[Usuario] uc                 ON uc.usu_id  = cpr.cpr_usuario_creacion
                  LEFT JOIN [dbo].[Usuario] ua                 ON ua.usu_id  = cpr.cpr_usuario_actualizacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '
    IF (@ID IS NOT NULL) SET @WHERE = @WHERE + ' AND cpr.cpr_id = ' + LTRIM(@ID)
    IF (@CLIENTE IS NOT NULL) SET @WHERE = @WHERE + ' AND cpr.cpr_cliente = ' + LTRIM(@CLIENTE)
    IF (@CHECKLIST_PLANTILLA IS NOT NULL) SET @WHERE = @WHERE + ' AND cpv.cpv_checklist_plantilla = ' + LTRIM(@CHECKLIST_PLANTILLA)
    IF (@ACTIVO IS NOT NULL) SET @WHERE = @WHERE + ' AND cpr.cpr_activo = ' + LTRIM(@ACTIVO)
    IF (@HABILITADO IS NOT NULL) SET @WHERE = @WHERE + ' AND cpr.cpr_habilitado = ' + LTRIM(@HABILITADO)
    IF (@FILTRO IS NOT NULL)
    BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (cpr.cpr_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cpl.cpl_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR cpl.cpl_codigo LIKE ''%' + LTRIM(@FILTRO) + '%'') '
    END
    SET @WHERE = @WHERE + ' ORDER BY cpr.cpr_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
PRINT '--- SEL_CHECKLIST_PROGRAMACION creado.'
GO


/* ========================================================================
   T-4202 - UPD_CHECKLIST_PROGRAMACION
      @ID y @USUARIO obligatorios; el resto opcional. El objetivo se puede
      cambiar; se conserva la regla activo O area. La pauta (version) tambien
      se puede cambiar por @CHECKLIST_PLANTILLA (resuelve su version publicada).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_PROGRAMACION]
@ID                     INT,
@CHECKLIST_PLANTILLA    INT = NULL,
@PROGRAMACION           INT = NULL,
@ACTIVO                 INT = NULL,
@INSTALACION_AREA       INT = NULL,
@GRUPO_TRABAJO          INT = NULL,
@USUARIO_RESPONSABLE    INT = NULL,
@NOMBRE                 NVARCHAR(200) = NULL,
@HABILITADO             BIT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @VERSION INT

SELECT @CLIENTE = cpr_cliente FROM [dbo].[Checklist_Programacion] WHERE cpr_id = @ID
IF @CLIENTE IS NULL
BEGIN RAISERROR('1.- LA PROGRAMACION NO EXISTE.', 16, 1) RETURN -1 END

-- CA3: no dejar la programacion sin objetivo. Si se envian ambos NULL, se rechaza.
IF @ACTIVO IS NULL AND @INSTALACION_AREA IS NULL
BEGIN RAISERROR('2.- INDIQUE UN OBJETIVO: UN ACTIVO O UN AREA.', 16, 1) RETURN -1 END

-- Si cambia la pauta, resolver su version publicada.
IF @CHECKLIST_PLANTILLA IS NOT NULL
BEGIN
    SELECT TOP 1 @VERSION = cpv_id FROM [dbo].[Checklist_Plantilla_Version]
    WHERE  cpv_checklist_plantilla = @CHECKLIST_PLANTILLA AND cpv_checklist_version_estado = 2
    ORDER BY cpv_numero DESC
    IF @VERSION IS NULL
    BEGIN RAISERROR('3.- LA PAUTA NO TIENE UNA VERSION PUBLICADA.', 16, 1) RETURN -1 END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Checklist_Programacion]
    SET     cpr_checklist_plantilla_version = ISNULL(@VERSION, cpr_checklist_plantilla_version)
           ,cpr_programacion                = ISNULL(@PROGRAMACION, cpr_programacion)
           ,cpr_activo                      = @ACTIVO
           ,cpr_instalacion_area            = @INSTALACION_AREA
           ,cpr_grupo_trabajo               = @GRUPO_TRABAJO
           ,cpr_usuario_responsable         = @USUARIO_RESPONSABLE
           ,cpr_nombre                      = ISNULL(@NOMBRE, cpr_nombre)
           ,cpr_habilitado                  = ISNULL(@HABILITADO, cpr_habilitado)
           ,cpr_usuario_actualizacion       = @USUARIO
           ,cpr_fecha_actualizacion         = @DATE_NOW
    WHERE   cpr_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CHECKLIST_PROGRAMACION @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA PROGRAMACION.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- UPD_CHECKLIST_PROGRAMACION creado.'
GO


/* ========================================================================
   T-4203 - DATOS DE PRUEBA
      Deja una pauta PUBLICADA (SOP-09-R24) y una programacion diaria sobre un
      activo, para ejercitar los criterios. IDEMPOTENTE: solo si falta.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTILLA INT, @VER INT, @PROG INT, @ACT INT, @NEW INT

SELECT @PLANTILLA = cpl_id FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE AND cpl_codigo = N'SOP-09-R24'

-- Publicar SOP si aun tiene borrador (para que sea programable).
IF @PLANTILLA IS NOT NULL
   AND EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla=@PLANTILLA AND cpv_checklist_version_estado=1)
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla=@PLANTILLA AND cpv_checklist_version_estado=2)
BEGIN
    EXEC [dbo].[PUBLICAR_CHECKLIST_VERSION] @PLANTILLA=@PLANTILLA, @CLIENTE=@CLIENTE, @OBSERVACION=N'Publicacion de prueba (HU-094)', @USUARIO=@USUARIO, @VERSION=@VER OUTPUT
    PRINT '--- SOP-09-R24 publicada para poder programarla.'
END

SELECT TOP 1 @PROG = pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_habilitado = 1 ORDER BY pro_id
SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = N'ACT-35'   -- Revolvedora 1

IF @PLANTILLA IS NOT NULL AND @PROG IS NOT NULL AND @ACT IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] WHERE cpr_cliente=@CLIENTE AND cpr_nombre=N'Ronda diaria - Revolvedora 1')
BEGIN
    EXEC [dbo].[INS_CHECKLIST_PROGRAMACION] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
         @CHECKLIST_PLANTILLA=@PLANTILLA, @PROGRAMACION=@PROG, @ACTIVO=@ACT,
         @NOMBRE=N'Ronda diaria - Revolvedora 1', @USUARIO=@USUARIO
    PRINT '--- Programacion demo creada.'
END
ELSE
    PRINT '--- Demo omitida (ya existe, o falta Programacion/activo).'
GO

SELECT cpr_id, cpr_nombre, cpr_activo, cpr_instalacion_area, cpr_habilitado FROM [dbo].[Checklist_Programacion] WHERE cpr_cliente=1
GO

PRINT '197_SPRINT4_CHECKLIST_PROGRAMACION aplicado.'
GO
