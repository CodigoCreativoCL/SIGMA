USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-040 ADMINISTRAR UNIDADES DE MEDIDA. SEL/INS/UPD/DEL_UNIDAD_MEDIDA.
-- =============================================
-- Va DESPUES de 92_SPRINT2_ACTIVO_FICHA_MENU.
--
-- QUE CUBRE
--   T-2279  Revision del modelo Unidad_Medida.
--   T-2280  SEL_UNIDAD_MEDIDA ampliado: filtros (id, magnitud, texto,
--           habilitado) y ORDER BY estable.
--   T-2281  INS_UNIDAD_MEDIDA.
--   T-2282  UPD_UNIDAD_MEDIDA (ISNULL).
--   T-2283  DEL_UNIDAD_MEDIDA: baja logica que rechaza si hay dependientes.
--
-- T-2279 - REVISION DEL MODELO
--   Unidad_Medida se creo en el bloque 11. Es un catalogo GLOBAL de
--   plataforma: NO tiene cliente. Por eso:
--     - El codigo es unico GLOBAL (UX_UME_CODIGO), no por cliente. La
--       plantilla de la tarea dice "por cliente" por herencia; aqui el
--       ambito real es el catalogo entero.
--     - Un indice filtrado UX_UME_MAGNITUD_BASE (ume_magnitud WHERE
--       ume_unidad_base IS NULL) deja UNA sola unidad base por magnitud.
--     - Las fechas se sellan con GETDATE(), no con FNC_PAIS_HORA: al no
--       haber cliente no hay pais del que tomar la hora.
--   ume_factor y ume_offset convierten a la unidad base de su magnitud
--   (1 km = factor 1000 sobre el metro; grados C -> K usan offset).
--
-- ES IDEMPOTENTE: CREATE OR ALTER; el indice se garantiza si falta.
-- =============================================

SET NOCOUNT ON
GO


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_UME_CODIGO' AND object_id = OBJECT_ID(N'[dbo].[Unidad_Medida]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_UME_CODIGO ON [dbo].[Unidad_Medida] ([ume_codigo])
    PRINT '--- Indice unico UX_UME_CODIGO creado.'
END
ELSE
    PRINT '--- Indice unico UX_UME_CODIGO ya existe (bloque 11). OK.'
GO


/* ========================================================================
   SEL_MAGNITUD - para poblar el combo de magnitud de la ficha.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_MAGNITUD]
@ID          INT = NULL,
@HABILITADO  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  mag.mag_id         AS MAG_ID
           ,mag.mag_codigo     AS MAG_CODIGO
           ,mag.mag_nombre     AS MAG_NOMBRE
           ,mag.mag_orden      AS MAG_ORDEN
           ,mag.mag_habilitado AS MAG_HABILITADO
    FROM    [dbo].[Magnitud] mag
    WHERE   (@ID IS NULL OR mag.mag_id = @ID)
      AND   (@HABILITADO IS NULL OR mag.mag_habilitado = @HABILITADO)
    ORDER BY mag.mag_orden, mag.mag_nombre
GO


/* ========================================================================
   T-2280 - SEL_UNIDAD_MEDIDA (reescrito con filtros y auditoria)
      @HABILITADO por defecto NULL (todos); los combos que solo quieren las
      habilitadas pasan 1. @FILTRO va parametrizado con LIKE, no concatenado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_UNIDAD_MEDIDA]
@ID          INT = NULL,
@MAGNITUD    INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      NVARCHAR(200) = NULL

AS
SET NOCOUNT ON

    SELECT  ume.ume_id              AS UME_ID
           ,ume.ume_magnitud        AS UME_MAGNITUD
           ,ume.ume_unidad_base     AS UME_UNIDAD_BASE
           ,ume.ume_codigo          AS UME_CODIGO
           ,ume.ume_nombre          AS UME_NOMBRE
           ,ume.ume_simbolo         AS UME_SIMBOLO
           ,ume.ume_factor          AS UME_FACTOR
           ,ume.ume_offset          AS UME_OFFSET
           ,ume.ume_fecha_creacion       AS UME_FECHA_CREACION
           ,ume.ume_fecha_actualizacion  AS UME_FECHA_ACTUALIZACION
           ,ume.ume_habilitado      AS UME_HABILITADO
           ,mag.mag_nombre          AS MAGNITUD_NOMBRE
           ,base.ume_nombre         AS UNIDAD_BASE_NOMBRE
           ,ume.ume_nombre + N' (' + ume.ume_simbolo + N')' AS ETIQUETA
           ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, N'') + N' ' + ISNULL(uc.usu_apellido_paterno, N''))) AS USUARIO_CREACION_NOMBRE
           ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, N'') + N' ' + ISNULL(ua.usu_apellido_paterno, N''))) AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Unidad_Medida] ume
    INNER JOIN [dbo].[Magnitud]      mag  ON mag.mag_id  = ume.ume_magnitud
    LEFT  JOIN [dbo].[Unidad_Medida] base ON base.ume_id = ume.ume_unidad_base
    LEFT  JOIN [dbo].[Usuario]       uc   ON uc.usu_id   = ume.ume_usuario_creacion
    LEFT  JOIN [dbo].[Usuario]       ua   ON ua.usu_id   = ume.ume_usuario_actualizacion
    WHERE   (@ID IS NULL OR ume.ume_id = @ID)
      AND   (@MAGNITUD IS NULL OR ume.ume_magnitud = @MAGNITUD)
      AND   (@HABILITADO IS NULL OR ume.ume_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL OR ume.ume_codigo LIKE '%' + @FILTRO + '%'
                             OR ume.ume_nombre LIKE '%' + @FILTRO + '%'
                             OR ume.ume_simbolo LIKE '%' + @FILTRO + '%')
    ORDER BY mag.mag_orden, ume.ume_codigo
GO


/* ========================================================================
   T-2281 - INS_UNIDAD_MEDIDA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_UNIDAD_MEDIDA]
@ID             INT = NULL OUTPUT,
@MAGNITUD       INT,
@UNIDAD_BASE    INT = NULL,
@CODIGO         NVARCHAR(20),
@NOMBRE         NVARCHAR(100),
@SIMBOLO        NVARCHAR(20),
@FACTOR         DECIMAL(18,6) = 1,
@OFFSET         DECIMAL(18,6) = 0,
@USUARIO        INT

AS
SET NOCOUNT ON

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @FACTOR = ISNULL(@FACTOR, 1)
SET @OFFSET = ISNULL(@OFFSET, 0)

BEGIN
    -- Codigo unico global.
    IF EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA UNIDAD CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Una sola unidad base por magnitud (indice UX_UME_MAGNITUD_BASE).
    IF @UNIDAD_BASE IS NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                    WHERE ume_magnitud = @MAGNITUD AND ume_unidad_base IS NULL)
    BEGIN
        RAISERROR('2.- ESA MAGNITUD YA TIENE UNA UNIDAD BASE. ELIJA UNA UNIDAD BASE PARA LA NUEVA.', 16, 1)
        RETURN -1
    END

    -- La unidad base, si se indica, tiene que ser de la misma magnitud.
    IF @UNIDAD_BASE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                        WHERE ume_id = @UNIDAD_BASE AND ume_magnitud = @MAGNITUD)
    BEGIN
        RAISERROR('3.- LA UNIDAD BASE DEBE SER DE LA MISMA MAGNITUD.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion,
         ume_usuario_actualizacion, ume_fecha_actualizacion, ume_habilitado)
    VALUES
        (@MAGNITUD, @UNIDAD_BASE, @CODIGO, @NOMBRE, @SIMBOLO,
         @FACTOR, @OFFSET, @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_UNIDAD_MEDIDA @CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE INSERTAR LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2282 - UPD_UNIDAD_MEDIDA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_UNIDAD_MEDIDA]
@ID             INT,
@MAGNITUD       INT = NULL,
@UNIDAD_BASE    INT = NULL,
@CODIGO         NVARCHAR(20) = NULL,
@NOMBRE         NVARCHAR(100) = NULL,
@SIMBOLO        NVARCHAR(20) = NULL,
@FACTOR         DECIMAL(18,6) = NULL,
@OFFSET         DECIMAL(18,6) = NULL,
@HABILITADO     BIT = NULL,
@QUITA_BASE     BIT = 0,
@USUARIO        INT

AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @ID)
BEGIN
    RAISERROR('1.- LA UNIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @CODIGO AND ume_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA UNIDAD CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @UNIDAD_BASE IS NOT NULL AND @UNIDAD_BASE = @ID
    BEGIN
        RAISERROR('3.- UNA UNIDAD NO PUEDE SER SU PROPIA BASE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Unidad_Medida]
    SET     ume_magnitud              = ISNULL(@MAGNITUD, ume_magnitud)
           ,ume_unidad_base           = CASE WHEN @QUITA_BASE = 1 THEN NULL
                                             ELSE ISNULL(@UNIDAD_BASE, ume_unidad_base) END
           ,ume_codigo                = ISNULL(@CODIGO, ume_codigo)
           ,ume_nombre                = ISNULL(@NOMBRE, ume_nombre)
           ,ume_simbolo               = ISNULL(@SIMBOLO, ume_simbolo)
           ,ume_factor                = ISNULL(@FACTOR, ume_factor)
           ,ume_offset                = ISNULL(@OFFSET, ume_offset)
           ,ume_habilitado            = ISNULL(@HABILITADO, ume_habilitado)
           ,ume_usuario_actualizacion = @USUARIO
           ,ume_fecha_actualizacion   = GETDATE()
    WHERE   ume_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_UNIDAD_MEDIDA @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   T-2283 - DEL_UNIDAD_MEDIDA
      Baja logica. Rechaza si la unidad esta en uso -medidores, repuestos,
      variables, atributos- o si otra unidad la usa como base, en vez de
      dejar esas filas apuntando a una unidad dada de baja.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_UNIDAD_MEDIDA]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @ID)
BEGIN
    RAISERROR('1.- LA UNIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_unidad_base = @ID)
    BEGIN
        RAISERROR('2.- OTRAS UNIDADES LA USAN COMO BASE. NO SE PUEDE DAR DE BAJA.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor] WHERE ame_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Repuesto]       WHERE rep_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] WHERE ava_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico] WHERE ate_unidad_medida = @ID)
    BEGIN
        RAISERROR('3.- LA UNIDAD ESTA EN USO (MEDIDORES, REPUESTOS, VARIABLES O ATRIBUTOS). DESHABILITELA EN VEZ DE ELIMINARLA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Unidad_Medida]
    SET     ume_habilitado            = 0
           ,ume_usuario_actualizacion = @USUARIO
           ,ume_fecha_actualizacion   = GETDATE()
    WHERE   ume_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_UNIDAD_MEDIDA ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE DAR DE BAJA LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


PRINT '93_SPRINT2_UNIDAD_MEDIDA aplicado: SEL_MAGNITUD y SEL/INS/UPD/DEL_UNIDAD_MEDIDA.'
GO
