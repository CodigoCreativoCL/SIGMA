/* =============================================================================
   HU-090 · CA1 — "Cuando creo una plantilla con codigo y nombre, entonces se
   crea su version 1 en estado borrador".

   DEFECTO QUE CORRIGE
     INS_CHECKLIST_PLANTILLA insertaba solo la fila de Checklist_Plantilla. Ni
     el procedimiento ni ChecklistPlantillaController creaban la version 1, asi
     que una plantilla recien creada quedaba sin ninguna version: no se le
     podian agregar secciones ni items (ambos cuelgan de la version) y al
     intentar publicarla PUBLICAR_CHECKLIST_VERSION respondia "3.- NO HAY UNA
     VERSION EN BORRADOR PARA PUBLICAR".

     Lo detecto la prueba de HU-090 CA1 al cerrar el Sprint 4 (01-10-2026): la
     historia estaba construida pero su tarea de pruebas seguia pendiente.

   POR QUE EN EL PROCEDIMIENTO Y NO EN EL CONTROLLER
     La plantilla y su version 1 son un solo hecho de negocio: una plantilla
     sin version no sirve para nada. Si la version la creara la web, la API y
     cualquier carga masiva tendrian que acordarse de hacerlo tambien, y el dia
     que una no lo haga el dato queda a medias. Va dentro de la misma
     transaccion que ya tiene el procedimiento: o quedan las dos filas, o no
     queda ninguna.
   ============================================================================= */

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_PLANTILLA]
@ID                         INT = NULL OUTPUT,
@CLIENTE                    INT,
@CLIENTE_INSTALACION        INT = NULL,
@CHECKLIST_ASIGNACION_TIPO  INT = NULL,
@ACTIVO_TIPO                INT = NULL,
@CODIGO                     NVARCHAR(50),
@NOMBRE                     NVARCHAR(200),
@DESCRIPCION                NVARCHAR(MAX) = NULL,
@USUARIO                    INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El codigo es unico dentro del cliente, no a nivel global: dos empresas
   distintas pueden llamar SOP-01 a su propia pauta. */
IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla]
           WHERE cpl_cliente = @CLIENTE AND cpl_codigo = @CODIGO AND cpl_habilitado = 1)
BEGIN
    RAISERROR('1.- YA EXISTE UNA PLANTILLA CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
    RETURN -1
END

IF @CLIENTE_INSTALACION IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                   WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Checklist_Plantilla]
    (
         cpl_cliente
        ,cpl_cliente_instalacion
        ,cpl_checklist_asignacion_tipo
        ,cpl_activo_tipo
        ,cpl_codigo
        ,cpl_nombre
        ,cpl_descripcion
        ,cpl_usuario_creacion
        ,cpl_fecha_creacion
        ,cpl_usuario_actualizacion
        ,cpl_fecha_actualizacion
        ,cpl_habilitado
    )
    VALUES
    (
         @CLIENTE
        ,@CLIENTE_INSTALACION
        ,@CHECKLIST_ASIGNACION_TIPO
        ,@ACTIVO_TIPO
        ,@CODIGO
        ,@NOMBRE
        ,@DESCRIPCION
        ,@USUARIO
        ,@DATE_NOW
        ,@USUARIO
        ,@DATE_NOW
        ,1
    )

    SET @ID = SCOPE_IDENTITY()

    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CHECKLIST_PLANTILLA @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR LA PLANTILLA.'
        RETURN -1
    END

    /* CA1: la plantilla nace con su version 1 en borrador. Es lo que permite
       empezar a agregarle secciones e items, que cuelgan de la version. */
    INSERT INTO [dbo].[Checklist_Plantilla_Version]
    (
         cpv_checklist_plantilla
        ,cpv_numero
        ,cpv_checklist_version_estado      /* 1 = BORRADOR */
        ,cpv_usuario_creacion
        ,cpv_fecha_creacion
        ,cpv_usuario_actualizacion
        ,cpv_fecha_actualizacion
        ,cpv_habilitado
    )
    VALUES
    (
         @ID
        ,1
        ,1
        ,@USUARIO
        ,@DATE_NOW
        ,@USUARIO
        ,@DATE_NOW
        ,1
    )

COMMIT TRANSACTION

RETURN(0)
GO

/* -----------------------------------------------------------------------------
   Reparacion de lo ya creado: las plantillas que quedaron sin ninguna version
   por este defecto reciben su version 1 en borrador. Es idempotente: una
   plantilla que ya tiene versiones no se toca.
   ----------------------------------------------------------------------------- */
INSERT INTO [dbo].[Checklist_Plantilla_Version]
(
     cpv_checklist_plantilla, cpv_numero, cpv_checklist_version_estado
    ,cpv_usuario_creacion, cpv_fecha_creacion
    ,cpv_usuario_actualizacion, cpv_fecha_actualizacion, cpv_habilitado
)
SELECT p.cpl_id, 1, 1,
       p.cpl_usuario_creacion, p.cpl_fecha_creacion,
       p.cpl_usuario_creacion, p.cpl_fecha_creacion, 1
FROM   [dbo].[Checklist_Plantilla] p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version] v
                   WHERE v.cpv_checklist_plantilla = p.cpl_id)
GO
