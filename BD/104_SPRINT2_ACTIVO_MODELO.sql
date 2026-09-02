USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-031 ADMINISTRAR MODELOS DE ACTIVO.
-- =============================================
-- Va DESPUES de 103_SPRINT2_ACTIVO_ESTADO_MENU.
--
-- QUE CUBRE
--   T-2263  Revision del modelo Activo_Modelo.
--   T-2265  INS_ACTIVO_MODELO (transaccion, no duplica, FNC_PAIS_HORA).
--   T-2266  UPD_ACTIVO_MODELO (ISNULL en lo que la ficha no toca).
--   T-2267  DEL_ACTIVO_MODELO (baja logica, rechaza si tiene dependientes).
--   (El SEL_ACTIVO_MODELO ya existia; no se toca.)
--
-- T-2263 - REVISION DEL MODELO
--   Activo_Modelo NO tiene columna codigo: un modelo se identifica por su
--   fabricante y nombre dentro de un tipo de activo ("WEG W22 132S"). La
--   plantilla de la tarea habla de "codigo unico por cliente" por herencia;
--   aqui el codigo no existe y no aplica. La clave de negocio que SI se
--   cuida es que no se repita (cliente, tipo, fabricante, nombre).
--
--   amo_cliente ES NULLABLE: hay modelos GLOBALES (amo_cliente NULL, que ve
--   todo el mundo, sembrados por la plataforma) y modelos propios del
--   cliente. Desde esta pantalla el cliente crea y edita LOS SUYOS; los
--   globales se muestran para elegirlos pero no se editan ni se dan de baja
--   aqui (INS/UPD/DEL lo validan con un mensaje claro).
--
--   DEPENDIENTES (para el DEL): Activo (act_activo_modelo),
--   Plan_Mantenimiento (pma_activo_modelo) y Repuesto_Compatibilidad
--   (rco_activo_modelo). No se deja huerfano un activo apuntando a un modelo
--   dado de baja.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-2265 - INS_ACTIVO_MODELO
      Crea un modelo PROPIO del cliente (amo_cliente = @CLIENTE). No permite
      dos modelos iguales (mismo tipo, fabricante y nombre) en el cliente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_MODELO]
@ID             INT = NULL OUTPUT,
@CLIENTE        INT,
@ACTIVO_TIPO    INT,
@FABRICANTE     NVARCHAR(200) = NULL,
@NOMBRE         NVARCHAR(200),
@DESCRIPCION    NVARCHAR(500) = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SET @NOMBRE     = LTRIM(RTRIM(@NOMBRE))
SET @FABRICANTE = NULLIF(LTRIM(RTRIM(ISNULL(@FABRICANTE, N''))), N'')

BEGIN
    -- 1) El tipo de activo tiene que existir y ser global o del cliente.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                   WHERE ati_id = @ACTIVO_TIPO
                     AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE))
    BEGIN
        RAISERROR('1.- EL TIPO DE ACTIVO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 2) No repetir el mismo modelo (tipo + fabricante + nombre) en el cliente.
    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo]
                WHERE amo_cliente = @CLIENTE
                  AND amo_activo_tipo = @ACTIVO_TIPO
                  AND amo_nombre = @NOMBRE
                  AND ISNULL(amo_fabricante, N'') = ISNULL(@FABRICANTE, N''))
    BEGIN
        RAISERROR('2.- YA EXISTE ESE MODELO PARA ESTE TIPO DE ACTIVO.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    INSERT [dbo].[Activo_Modelo]
        (amo_cliente, amo_activo_tipo, amo_fabricante, amo_nombre, amo_descripcion,
         amo_usuario_creacion, amo_fecha_creacion,
         amo_usuario_actualizacion, amo_fecha_actualizacion, amo_habilitado)
    VALUES
        (@CLIENTE, @ACTIVO_TIPO, @FABRICANTE, @NOMBRE, @DESCRIPCION,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'INS_ACTIVO_MODELO @CLIENTE=' + LTRIM(STR(@CLIENTE)) + ',@NOMBRE=' + ISNULL(@NOMBRE,'')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='3.- NO FUE POSIBLE CREAR EL MODELO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2266 - UPD_ACTIVO_MODELO
      Edita un modelo PROPIO. Un modelo global no se edita desde aqui. Lo que
      la ficha no manda se conserva con ISNULL(@X, columna).
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_MODELO]
@ID             INT,
@ACTIVO_TIPO    INT = NULL,
@FABRICANTE     NVARCHAR(200) = NULL,
@NOMBRE         NVARCHAR(200) = NULL,
@DESCRIPCION    NVARCHAR(500) = NULL,
@HABILITADO     BIT = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @TIPO INT

SELECT @CLIENTE = amo_cliente, @TIPO = amo_activo_tipo
FROM   [dbo].[Activo_Modelo] WHERE amo_id = @ID

IF @TIPO IS NULL
BEGIN
    RAISERROR('1.- EL MODELO NO EXISTE.', 16, 1)
    RETURN -1
END

-- Un modelo global (sin cliente) es de la plataforma: no se toca desde aqui.
IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ES UN MODELO GLOBAL DE LA PLATAFORMA Y NO SE EDITA DESDE AQUI.', 16, 1)
    RETURN -1
END

IF @NOMBRE IS NOT NULL SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))
SET @FABRICANTE = NULLIF(LTRIM(RTRIM(ISNULL(@FABRICANTE, N''))), N'')

-- Nuevo tipo de activo, si se cambia: existe y es del cliente o global.
IF @ACTIVO_TIPO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                   WHERE ati_id = @ACTIVO_TIPO AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE))
BEGIN
    RAISERROR('3.- EL TIPO DE ACTIVO NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- No dejar dos modelos iguales en el cliente (excluyendo el propio registro).
IF EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo]
            WHERE amo_cliente = @CLIENTE
              AND amo_id <> @ID
              AND amo_activo_tipo = ISNULL(@ACTIVO_TIPO, @TIPO)
              AND amo_nombre = ISNULL(@NOMBRE, amo_nombre)
              AND ISNULL(amo_fabricante, N'') = ISNULL(@FABRICANTE, ISNULL(amo_fabricante, N'')))
BEGIN
    RAISERROR('4.- YA EXISTE ESE MODELO PARA ESTE TIPO DE ACTIVO.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo_Modelo]
    SET     amo_activo_tipo           = ISNULL(@ACTIVO_TIPO, amo_activo_tipo)
           ,amo_fabricante            = @FABRICANTE        -- editable/limpiable
           ,amo_nombre                = ISNULL(@NOMBRE, amo_nombre)
           ,amo_descripcion           = @DESCRIPCION       -- editable/limpiable
           ,amo_habilitado            = ISNULL(@HABILITADO, amo_habilitado)
           ,amo_usuario_actualizacion = @USUARIO
           ,amo_fecha_actualizacion   = @DATE_NOW
    WHERE   amo_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'UPD_ACTIVO_MODELO @ID=' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='5.- NO FUE POSIBLE ACTUALIZAR EL MODELO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2267 - DEL_ACTIVO_MODELO
      Baja logica. Rechaza si algun activo, plan o repuesto lo usa: no se
      deja un dependiente apuntando a un modelo dado de baja.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_MODELO]
@ID INT, @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @EXISTE INT

SELECT @CLIENTE = amo_cliente, @EXISTE = 1
FROM   [dbo].[Activo_Modelo] WHERE amo_id = @ID

IF @EXISTE IS NULL
BEGIN
    RAISERROR('1.- EL MODELO NO EXISTE.', 16, 1)
    RETURN -1
END

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('2.- ES UN MODELO GLOBAL DE LA PLATAFORMA Y NO SE DA DE BAJA DESDE AQUI.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_activo_modelo = @ID AND act_habilitado = 1)
BEGIN
    RAISERROR('3.- HAY ACTIVOS QUE USAN ESTE MODELO. CAMBIELES EL MODELO ANTES DE DARLO DE BAJA.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_activo_modelo = @ID AND pma_habilitado = 1)
BEGIN
    RAISERROR('4.- HAY PLANES DE MANTENIMIENTO ASOCIADOS A ESTE MODELO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] WHERE rco_activo_modelo = @ID)
BEGIN
    RAISERROR('5.- HAY REPUESTOS DECLARADOS COMPATIBLES CON ESTE MODELO.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE [dbo].[Activo_Modelo]
    SET    amo_habilitado = 0, amo_usuario_actualizacion = @USUARIO, amo_fecha_actualizacion = @DATE_NOW
    WHERE  amo_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'DEL_ACTIVO_MODELO ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES=@V, @MSG='6.- NO FUE POSIBLE DAR DE BAJA EL MODELO.'
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO


/* ========================================================================
   T-2263 - AMPLIACION ADITIVA DEL SEL_ACTIVO_MODELO
      El SEL (T-2264) ya existia y sirve a la grilla y a los combos. Aqui se
      re-crea AGREGANDO auditoria (fechas y usuarios) para que la ficha la
      muestre, sin cambiar los parametros ni las columnas que ya devolvia:
      quien lea de mas, ignora las columnas nuevas.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MODELO]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @ACTIVO_TIPO INT = NULL,
    @HABILITADO  BIT = NULL,
    @FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  m.amo_id                                       AS AMO_ID,
            m.amo_cliente                                  AS AMO_CLIENTE,
            m.amo_activo_tipo                              AS AMO_ACTIVO_TIPO,
            ISNULL(m.amo_fabricante, '')                   AS AMO_FABRICANTE,
            m.amo_nombre                                   AS AMO_NOMBRE,
            ISNULL(m.amo_descripcion, '')                  AS AMO_DESCRIPCION,
            m.amo_habilitado                               AS AMO_HABILITADO,
            CAST(CASE WHEN m.amo_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(t.ati_nombre, '')                       AS TIPO_NOMBRE,
            /* Lo que se lee en el combo: el fabricante delante, porque
               "W22 132S" sin "WEG" no le dice nada a nadie. */
            LTRIM(ISNULL(m.amo_fabricante + ' ', '') + m.amo_nombre) AS ETIQUETA,
            m.amo_fecha_creacion                           AS AMO_FECHA_CREACION,
            m.amo_fecha_actualizacion                      AS AMO_FECHA_ACTUALIZACION,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Activo_Modelo] m
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = m.amo_activo_tipo
    LEFT JOIN [dbo].[Usuario]     uc ON uc.usu_id = m.amo_usuario_creacion
    LEFT JOIN [dbo].[Usuario]     ua ON ua.usu_id = m.amo_usuario_actualizacion
    WHERE   (m.amo_cliente IS NULL OR m.amo_cliente = @CLIENTE)
      AND   (@ID          IS NULL OR m.amo_id          = @ID)
      AND   (@ACTIVO_TIPO IS NULL OR m.amo_activo_tipo = @ACTIVO_TIPO)
      AND   (@HABILITADO  IS NULL OR m.amo_habilitado  = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR m.amo_nombre     LIKE '%' + @FILTRO + '%'
             OR m.amo_fabricante LIKE '%' + @FILTRO + '%')
    ORDER BY m.amo_fabricante, m.amo_nombre, m.amo_id
GO


PRINT '104_SPRINT2_ACTIVO_MODELO aplicado: INS/UPD/DEL_ACTIVO_MODELO y SEL ampliado.'
GO
