/* ============================================================================
   SIGMA — Bloque 240
   UN ACTIVO NO PUEDE SER SU PROPIO ASCENDIENTE                    HU-035 #4
   ----------------------------------------------------------------------------

   UPD_ACTIVO solo rechazaba padre = id. Al probar el criterio 4 el 17-09-2026
   se pudo colgar el blower ACT-55 de su propio motor ACT-56: dos activos
   que se apuntan mutuamente, y cualquier recorrido de la jerarquia entra en
   bucle. Se agrega el recorrido de la rama hacia abajo desde el activo que
   se edita; si el padre elegido esta en ella, se rechaza.

   Es el SP completo con la regla nueva, tomado de la definicion vigente.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO]
@ID                     INT,
@CLIENTE_INSTALACION    INT = NULL,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT = NULL,
@ACTIVO_MODELO          INT = NULL,
@ACTIVO_ESTADO          INT = NULL,
@ACTIVO_PADRE           INT = NULL,
@CENTRO_COSTO           INT = NULL,
@CRITICIDAD_NIVEL       INT = NULL,
@CODIGO                 NVARCHAR(50) = NULL,
@NOMBRE                 NVARCHAR(200) = NULL,
@NUMERO_SERIE           NVARCHAR(100) = NULL,
@FABRICANTE             NVARCHAR(200) = NULL,
@ANIO_FABRICACION       INT = NULL,
@FECHA_PUESTA_MARCHA    DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@HABILITADO             BIT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente, excluyendo el propio registro.
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Activo]
                    WHERE act_cliente = @CLIENTE AND act_codigo = @CODIGO AND act_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UN ACTIVO CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Un activo no puede ser su propio padre.
    IF @ACTIVO_PADRE IS NOT NULL AND @ACTIVO_PADRE = @ID
    BEGIN
        RAISERROR('3.- UN ACTIVO NO PUEDE DEPENDER DE SI MISMO.', 16, 1)
        RETURN -1
    END

    /* HU-035 #4: tampoco puede depender de uno de sus propios descendientes
       (el blower no puede colgar de su motor). Se recorre la rama hacia
       abajo desde @ID; si @ACTIVO_PADRE aparece, es un ciclo. */
    IF @ACTIVO_PADRE IS NOT NULL
    BEGIN
        DECLARE @ES_DESCENDIENTE BIT = 0
        ;WITH RAMA AS (
            SELECT act_id FROM [dbo].[Activo] WHERE act_activo_padre = @ID
            UNION ALL
            SELECT h.act_id FROM [dbo].[Activo] h INNER JOIN RAMA r ON h.act_activo_padre = r.act_id
        )
        SELECT @ES_DESCENDIENTE = 1 FROM RAMA WHERE act_id = @ACTIVO_PADRE

        IF @ES_DESCENDIENTE = 1
        BEGIN
            RAISERROR('3.- UN ACTIVO NO PUEDE DEPENDER DE UNO DE SUS PROPIOS SUBACTIVOS.', 16, 1)
            RETURN -1
        END
    END

    IF @ACTIVO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                        WHERE act_id = @ACTIVO_PADRE AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('4.- EL ACTIVO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Activo]
    SET     act_cliente_instalacion   = ISNULL(@CLIENTE_INSTALACION, act_cliente_instalacion)
           ,act_instalacion_area      = @INSTALACION_AREA
           ,act_activo_tipo           = ISNULL(@ACTIVO_TIPO, act_activo_tipo)
           ,act_activo_modelo         = @ACTIVO_MODELO
           ,act_activo_estado         = ISNULL(@ACTIVO_ESTADO, act_activo_estado)
           ,act_activo_padre          = @ACTIVO_PADRE
           ,act_centro_costo          = @CENTRO_COSTO
           ,act_criticidad_nivel      = ISNULL(@CRITICIDAD_NIVEL, act_criticidad_nivel)
           ,act_codigo                = ISNULL(@CODIGO, act_codigo)
           ,act_nombre                = ISNULL(@NOMBRE, act_nombre)
           ,act_numero_serie          = @NUMERO_SERIE
           ,act_fabricante            = @FABRICANTE
           ,act_anio_fabricacion      = @ANIO_FABRICACION
           ,act_fecha_puesta_marcha   = @FECHA_PUESTA_MARCHA
           ,act_descripcion           = @DESCRIPCION
           ,act_habilitado            = ISNULL(@HABILITADO, act_habilitado)
           ,act_usuario_actualizacion = @USUARIO
           ,act_fecha_actualizacion   = @DATE_NOW
    WHERE   act_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_ACTIVO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- UPD_ACTIVO rechaza los ciclos de la jerarquia (bloque 240).'
GO
