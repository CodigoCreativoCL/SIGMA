USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-032 DEFINIR LOS ATRIBUTOS TECNICOS DE UN TIPO DE ACTIVO.
-- =============================================
-- Va DESPUES de 106_SPRINT2_ACTIVO_MODELO_MENU.
--
-- QUE CUBRE
--   T-2295  Revision del modelo Atributo_Tecnico.
--   T-2296  SEL_ATRIBUTO_TECNICO con filtros y ORDER BY estable.
--   T-2297  INS_ATRIBUTO_TECNICO (transaccion, FNC_PAIS_HORA). El codigo es
--           AUTOMATICO (ATR-<id>): lo inyecta el bloque 108, no se teclea.
--   T-2298  UPD_ATRIBUTO_TECNICO (ISNULL en lo que la ficha no toca).
--   T-2299  DEL_ATRIBUTO_TECNICO (baja logica, rechaza si esta en uso).
--   Ademas: SEL_TIPO_DATO para el combo de tipo de dato de la ficha.
--
-- T-2295 - REVISION DEL MODELO
--   Atributo_Tecnico define QUE datos tecnicos describe un tipo de activo
--   (p. ej. "Potencia" decimal en kW, "Voltaje" entero en V). Tiene codigo
--   con indice unico POR CLIENTE (UX_ATE_CLIENTE_CODIGO = cliente + codigo);
--   ese codigo se AUTOMATIZA (ATR-<id>) segun la decision de Emilio, asi la
--   unicidad la garantiza el id y nadie teclea codigos.
--
--   ate_cliente y ate_activo_tipo son NULLABLE: hay atributos GLOBALES de la
--   plataforma (que el cliente ve pero no edita) y atributos que aplican a
--   TODOS los tipos (activo_tipo NULL) o a uno concreto. INS/UPD/DEL validan
--   que el cliente solo toque LOS SUYOS.
--
--   DEPENDIENTE (para el DEL): Activo_Atributo (aat_atributo_tecnico) -> el
--   valor concreto que un activo le da al atributo. No se da de baja un
--   atributo que ya tiene valores capturados.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   SEL_TIPO_DATO - catalogo para el combo "tipo de dato" de la ficha
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_TIPO_DATO]
@ID INT = NULL, @HABILITADO BIT = NULL
AS
SET NOCOUNT ON
    SELECT tda_id AS TDA_ID, tda_codigo AS TDA_CODIGO, tda_nombre AS TDA_NOMBRE,
           tda_habilitado AS TDA_HABILITADO
    FROM   [dbo].[Tipo_Dato]
    WHERE  (@ID IS NULL OR tda_id = @ID)
      AND  (@HABILITADO IS NULL OR tda_habilitado = @HABILITADO)
    ORDER BY tda_orden, tda_nombre
GO


/* ========================================================================
   T-2297 - INS_ATRIBUTO_TECNICO
      Crea un atributo PROPIO del cliente. El codigo llega como 'AUTO' desde
      la ficha y el bloque 108 lo reemplaza por ATR-<id> tras el SCOPE_IDENTITY.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ATRIBUTO_TECNICO]
@ID             INT = NULL OUTPUT,
@CLIENTE        INT,
@ACTIVO_TIPO    INT = NULL,
@TIPO_DATO      INT,
@UNIDAD_MEDIDA  INT = NULL,
@CODIGO         NVARCHAR(100),
@NOMBRE         NVARCHAR(200),
@ORDEN          INT = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

BEGIN
    -- 1) El tipo de dato tiene que existir y estar habilitado.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE tda_id = @TIPO_DATO AND tda_habilitado = 1)
    BEGIN
        RAISERROR('1.- EL TIPO DE DATO NO EXISTE.', 16, 1)
        RETURN -1
    END

    -- 2) Si se indica tipo de activo: existe y es global o del cliente.
    IF @ACTIVO_TIPO IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                       WHERE ati_id = @ACTIVO_TIPO AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- EL TIPO DE ACTIVO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 3) Si se indica unidad de medida: existe.
    IF @UNIDAD_MEDIDA IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD_MEDIDA)
    BEGIN
        RAISERROR('3.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    INSERT [dbo].[Atributo_Tecnico]
        (ate_cliente, ate_activo_tipo, ate_tipo_dato, ate_unidad_medida,
         ate_codigo, ate_nombre, ate_orden,
         ate_usuario_creacion, ate_fecha_creacion,
         ate_usuario_actualizacion, ate_fecha_actualizacion, ate_habilitado)
    VALUES
        (@CLIENTE, @ACTIVO_TIPO, @TIPO_DATO, @UNIDAD_MEDIDA,
         @CODIGO, @NOMBRE, @ORDEN,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'INS_ATRIBUTO_TECNICO @CLIENTE=' + LTRIM(STR(@CLIENTE)) + ',@NOMBRE=' + ISNULL(@NOMBRE,'')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='4.- NO FUE POSIBLE CREAR EL ATRIBUTO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2296 - SEL_ATRIBUTO_TECNICO
      Un solo SP para la grilla y la ficha. Trae los del cliente MAS los
      globales, con el nombre del tipo de dato, del tipo de activo y de la
      unidad, la marca de global y la auditoria.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ATRIBUTO_TECNICO]
@CLIENTE     INT,
@ID          INT = NULL,
@ACTIVO_TIPO INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(200) = NULL

AS
SET NOCOUNT ON

    SELECT  a.ate_id                                       AS ATE_ID,
            a.ate_cliente                                  AS ATE_CLIENTE,
            a.ate_activo_tipo                              AS ATE_ACTIVO_TIPO,
            a.ate_tipo_dato                                AS ATE_TIPO_DATO,
            a.ate_unidad_medida                            AS ATE_UNIDAD_MEDIDA,
            a.ate_codigo                                   AS ATE_CODIGO,
            a.ate_nombre                                   AS ATE_NOMBRE,
            a.ate_orden                                    AS ATE_ORDEN,
            a.ate_habilitado                               AS ATE_HABILITADO,
            CAST(CASE WHEN a.ate_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(t.ati_nombre, 'Todos los tipos')        AS TIPO_NOMBRE,
            td.tda_nombre                                  AS TIPO_DATO_NOMBRE,
            ISNULL(u.ume_nombre, '')                       AS UNIDAD_NOMBRE,
            a.ate_fecha_creacion                           AS ATE_FECHA_CREACION,
            a.ate_fecha_actualizacion                      AS ATE_FECHA_ACTUALIZACION,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Atributo_Tecnico] a
    INNER JOIN [dbo].[Tipo_Dato]     td ON td.tda_id = a.ate_tipo_dato
    LEFT  JOIN [dbo].[Activo_Tipo]   t  ON t.ati_id  = a.ate_activo_tipo
    LEFT  JOIN [dbo].[Unidad_Medida] u  ON u.ume_id  = a.ate_unidad_medida
    LEFT  JOIN [dbo].[Usuario]       uc ON uc.usu_id = a.ate_usuario_creacion
    LEFT  JOIN [dbo].[Usuario]       ua ON ua.usu_id = a.ate_usuario_actualizacion
    WHERE   (a.ate_cliente IS NULL OR a.ate_cliente = @CLIENTE)
      AND   (@ID          IS NULL OR a.ate_id          = @ID)
      AND   (@ACTIVO_TIPO IS NULL OR a.ate_activo_tipo = @ACTIVO_TIPO)
      AND   (@HABILITADO  IS NULL OR a.ate_habilitado  = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR a.ate_codigo LIKE '%' + @FILTRO + '%'
             OR a.ate_nombre LIKE '%' + @FILTRO + '%')
    ORDER BY a.ate_orden, a.ate_nombre, a.ate_id
GO


/* ========================================================================
   T-2298 - UPD_ATRIBUTO_TECNICO
      El codigo NO se edita (es automatico). Un atributo global no se toca
      desde aqui. Lo que la ficha no manda se conserva con ISNULL.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ATRIBUTO_TECNICO]
@ID             INT,
@ACTIVO_TIPO    INT = NULL,
@TIPO_DATO      INT = NULL,
@UNIDAD_MEDIDA  INT = NULL,
@NOMBRE         NVARCHAR(200) = NULL,
@ORDEN          INT = NULL,
@HABILITADO     BIT = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @EXISTE INT

SELECT @CLIENTE = ate_cliente, @EXISTE = 1
FROM   [dbo].[Atributo_Tecnico] WHERE ate_id = @ID

IF @EXISTE IS NULL
BEGIN
    RAISERROR('1.- EL ATRIBUTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ES UN ATRIBUTO GLOBAL DE LA PLATAFORMA Y NO SE EDITA DESDE AQUI.', 16, 1)
    RETURN -1
END

IF @NOMBRE IS NOT NULL SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

IF @TIPO_DATO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE tda_id = @TIPO_DATO AND tda_habilitado = 1)
BEGIN
    RAISERROR('3.- EL TIPO DE DATO NO EXISTE.', 16, 1)
    RETURN -1
END

IF @ACTIVO_TIPO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_id = @ACTIVO_TIPO AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE))
BEGIN
    RAISERROR('4.- EL TIPO DE ACTIVO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @UNIDAD_MEDIDA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD_MEDIDA)
BEGIN
    RAISERROR('5.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Atributo_Tecnico]
    SET     ate_activo_tipo           = @ACTIVO_TIPO      -- editable/limpiable (NULL = todos los tipos)
           ,ate_tipo_dato             = ISNULL(@TIPO_DATO, ate_tipo_dato)
           ,ate_unidad_medida         = @UNIDAD_MEDIDA    -- editable/limpiable
           ,ate_nombre                = ISNULL(@NOMBRE, ate_nombre)
           ,ate_orden                 = @ORDEN            -- editable/limpiable
           ,ate_habilitado            = ISNULL(@HABILITADO, ate_habilitado)
           ,ate_usuario_actualizacion = @USUARIO
           ,ate_fecha_actualizacion   = @DATE_NOW
    WHERE   ate_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'UPD_ATRIBUTO_TECNICO @ID=' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='6.- NO FUE POSIBLE ACTUALIZAR EL ATRIBUTO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2299 - DEL_ATRIBUTO_TECNICO
      Baja logica. Rechaza si algun activo ya capturo un valor para el
      atributo (Activo_Atributo): no se deja ese valor huerfano.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ATRIBUTO_TECNICO]
@ID INT, @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @EXISTE INT

SELECT @CLIENTE = ate_cliente, @EXISTE = 1
FROM   [dbo].[Atributo_Tecnico] WHERE ate_id = @ID

IF @EXISTE IS NULL
BEGIN
    RAISERROR('1.- EL ATRIBUTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ES UN ATRIBUTO GLOBAL DE LA PLATAFORMA Y NO SE DA DE BAJA DESDE AQUI.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Atributo] WHERE aat_atributo_tecnico = @ID AND aat_habilitado = 1)
BEGIN
    RAISERROR('3.- HAY ACTIVOS CON VALORES CAPTURADOS PARA ESTE ATRIBUTO. NO SE PUEDE DAR DE BAJA.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE [dbo].[Atributo_Tecnico]
    SET    ate_habilitado = 0, ate_usuario_actualizacion = @USUARIO, ate_fecha_actualizacion = @DATE_NOW
    WHERE  ate_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'DEL_ATRIBUTO_TECNICO ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='4.- NO FUE POSIBLE DAR DE BAJA EL ATRIBUTO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


PRINT '107_SPRINT2_ATRIBUTO_TECNICO aplicado: SEL_TIPO_DATO, SEL/INS/UPD/DEL_ATRIBUTO_TECNICO.'
GO
