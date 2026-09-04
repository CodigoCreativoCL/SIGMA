/* ============================================================================
   SIGMA - Bloque 136
   LOS TIPOS DE REPUESTO LOS DEFINE EL CLIENTE
   ----------------------------------------------------------------------------

   QUE RESUELVE

     El listado de repuestos era una sola lista plana. Con diez repuestos se
     recorre; con trescientos -que es lo normal en una planta- encontrar un
     rodamiento entre correas, filtros y fusibles obliga a buscar por codigo,
     o sea a saberselo de memoria.

     Con tipos, el listado se puede recorrer por categoria: rodamientos,
     correas, filtros, electrico, lo que cada planta necesite.

   POR QUE NO VIENEN SEMBRADOS

     Ninguna lista de tipos sirve para dos plantas distintas. Una papelera y
     una minera no comparten categorias, y una lista "estandar" termina
     siendo la de quien la escribio mas una fila "Otros" donde cae todo.

     `rti_cliente` es NOT NULL: no existen tipos globales. Es la misma
     decision que se acaba de tomar con `Activo_Tipo`, donde se borraron los
     cuatro que venian sembrados.

   EL TIPO ES OPCIONAL EN EL REPUESTO

     `rep_repuesto_tipo` admite nulo. Obligarlo dejaria fuera a los diez
     repuestos que ya existen y forzaria a inventar una categoria antes de
     poder cargar el primero. Sin tipo, el repuesto aparece en "Sin
     clasificar", que es cierto y no estorba.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

/* ============================================================== LA TABLA */
IF NOT EXISTS (SELECT 1 FROM sys.objects
                WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Tipo]
    (
        [rti_id]                        INT             NOT NULL IDENTITY(1,1),
        [rti_cliente]                   INT             NOT NULL,
        [rti_codigo]                    NVARCHAR(50)    NOT NULL,
        [rti_nombre]                    NVARCHAR(200)   NOT NULL,
        [rti_descripcion]               NVARCHAR(500)   NULL,

        /* Para ordenar las pestañas del listado. Sin esto quedarian
           alfabeticas, y la categoria que mas se usa terminaria al final
           solo por empezar con T. */
        [rti_orden]                     INT             NOT NULL CONSTRAINT DF_RTI_ORDEN DEFAULT 0,

        [rti_usuario_creacion]          INT             NOT NULL,
        [rti_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_RTI_FECHA_CREACION DEFAULT GETDATE(),
        [rti_usuario_actualizacion]     INT             NULL,
        [rti_fecha_actualizacion]       DATETIME        NULL,
        [rti_habilitado]                BIT             NOT NULL CONSTRAINT DF_RTI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO_TIPO PRIMARY KEY CLUSTERED ([rti_id] ASC),
        CONSTRAINT FK_RTI_CLIENTE FOREIGN KEY ([rti_cliente])
            REFERENCES [dbo].[Cliente] ([cli_id])
    )

    CREATE NONCLUSTERED INDEX IX_RTI_CLIENTE ON [dbo].[Repuesto_Tipo] ([rti_cliente])

    /* El codigo identifica al tipo dentro del cliente. Dos clientes pueden
       tener ambos "ROD" sin pisarse. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_RTI_CLIENTE_CODIGO
        ON [dbo].[Repuesto_Tipo] ([rti_cliente], [rti_codigo])

    PRINT 'Tabla Repuesto_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Repuesto_Tipo ya existe.'
GO

/* ================================================ LA COLUMNA EN REPUESTO */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Repuesto') AND name = 'rep_repuesto_tipo')
BEGIN
    ALTER TABLE [dbo].[Repuesto] ADD [rep_repuesto_tipo] INT NULL
    PRINT 'Columna rep_repuesto_tipo agregada.'
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_REP_REPUESTO_TIPO')
BEGIN
    ALTER TABLE [dbo].[Repuesto] WITH CHECK
        ADD CONSTRAINT FK_REP_REPUESTO_TIPO FOREIGN KEY ([rep_repuesto_tipo])
            REFERENCES [dbo].[Repuesto_Tipo] ([rti_id])
    PRINT 'FK_REP_REPUESTO_TIPO creada.'
END
GO

/* ====================================== EL PREFIJO DEL CODIGO AUTOMATICO */
IF OBJECT_ID('dbo.Modulo_Codigo') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Modulo_Codigo] WHERE mco_tabla = 'Repuesto_Tipo')
BEGIN
    INSERT INTO [dbo].[Modulo_Codigo]
        (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento, mco_habilitado)
    VALUES
        ('Repuesto_Tipo', 'RTI', 'rti_codigo', 'rti_id', 'INS_REPUESTO_TIPO', 1)

    PRINT 'Prefijo RTI registrado.'
END
GO

/* ============================================================ SEL_ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_TIPO]
    @ID         INT = NULL,
    @CLIENTE    INT,
    @HABILITADO BIT = NULL,
    @FILTRO     VARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  t.rti_id                    AS RTI_ID,
        t.rti_cliente               AS RTI_CLIENTE,
        t.rti_codigo                AS RTI_CODIGO,
        t.rti_nombre                AS RTI_NOMBRE,
        ISNULL(t.rti_descripcion,'') AS RTI_DESCRIPCION,
        t.rti_orden                 AS RTI_ORDEN,
        t.rti_habilitado            AS RTI_HABILITADO,
        t.rti_fecha_creacion        AS RTI_FECHA_CREACION,

        /* Cuantos repuestos cuelgan del tipo. La pantalla lo muestra en la
           pestaña y ademas lo necesita para no dejar borrar un tipo en uso:
           una consulta en vez de dos. */
        (SELECT COUNT(*) FROM [dbo].[Repuesto] r
          WHERE r.rep_repuesto_tipo = t.rti_id AND r.rep_habilitado = 1) AS REPUESTOS
FROM    [dbo].[Repuesto_Tipo] t
WHERE   t.rti_cliente = @CLIENTE
  AND  (@ID IS NULL OR t.rti_id = @ID)
  AND  (@HABILITADO IS NULL OR t.rti_habilitado = @HABILITADO)
  AND  (@FILTRO IS NULL
        OR t.rti_codigo LIKE '%' + @FILTRO + '%'
        OR t.rti_nombre LIKE '%' + @FILTRO + '%')
ORDER BY t.rti_orden, t.rti_nombre
GO

/* ============================================================ INS_ */
CREATE OR ALTER PROCEDURE [dbo].[INS_REPUESTO_TIPO]
    @ID          INT = NULL OUTPUT,
    @CLIENTE     INT,
    @CODIGO      NVARCHAR(50),
    @NOMBRE      NVARCHAR(200),
    @DESCRIPCION NVARCHAR(500) = NULL,
    @ORDEN       INT = 0,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))
SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

IF @NOMBRE = ''
BEGIN
    RAISERROR('1.- INDIQUE EL NOMBRE DEL TIPO DE REPUESTO.', 16, 1)
    RETURN -1
END

IF @CODIGO = ''
BEGIN
    RAISERROR('2.- INDIQUE EL CODIGO DEL TIPO DE REPUESTO.', 16, 1)
    RETURN -1
END

/* 'AUTO' es la señal de que lo genere el sistema; nunca queda guardado. */
IF @CODIGO <> 'AUTO' AND EXISTS (SELECT 1 FROM [dbo].[Repuesto_Tipo]
                                  WHERE rti_cliente = @CLIENTE AND rti_codigo = @CODIGO)
BEGIN
    RAISERROR('3.- YA EXISTE UN TIPO DE REPUESTO CON EL CODIGO "%s".', 16, 1, @CODIGO)
    RETURN -1
END

BEGIN TRANSACTION

BEGIN TRY

    INSERT INTO [dbo].[Repuesto_Tipo]
        (rti_cliente, rti_codigo, rti_nombre, rti_descripcion, rti_orden,
         rti_usuario_creacion, rti_fecha_creacion, rti_habilitado)
    VALUES
        (@CLIENTE, @CODIGO, @NOMBRE, @DESCRIPCION, ISNULL(@ORDEN, 0),
         @USUARIO, @AHORA, 1)

    SET @ID = SCOPE_IDENTITY()

    /* El codigo automatico solo se puede armar cuando ya se conoce el id. */
    IF @CODIGO = 'AUTO'
        UPDATE [dbo].[Repuesto_Tipo]
        SET    rti_codigo = [dbo].[FNC_CODIGO_AUTOMATICO]('RTI', @ID)
        WHERE  rti_id = @ID

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @M NVARCHAR(2000) = ERROR_MESSAGE()
    RAISERROR(@M, 16, 1)
    RETURN -1
END CATCH
GO

/* ============================================================ UPD_ */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO_TIPO]
    @ID          INT,
    @CLIENTE     INT,
    @CODIGO      NVARCHAR(50) = NULL,
    @NOMBRE      NVARCHAR(200) = NULL,
    @DESCRIPCION NVARCHAR(500) = NULL,
    @ORDEN       INT = NULL,
    @HABILITADO  BIT = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Tipo]
                WHERE rti_id = @ID AND rti_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL TIPO DE REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(ISNULL(@CODIGO, ''))), ' ', ''))

IF @CODIGO <> '' AND EXISTS (SELECT 1 FROM [dbo].[Repuesto_Tipo]
                              WHERE rti_cliente = @CLIENTE AND rti_codigo = @CODIGO AND rti_id <> @ID)
BEGIN
    RAISERROR('2.- YA EXISTE OTRO TIPO DE REPUESTO CON EL CODIGO "%s".', 16, 1, @CODIGO)
    RETURN -1
END

/* No se puede deshabilitar un tipo que tenga repuestos activos: dejaria una
   pestaña con contenido que ya no se puede elegir al crear. */
IF @HABILITADO = 0 AND EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                                WHERE rep_repuesto_tipo = @ID AND rep_habilitado = 1)
BEGIN
    RAISERROR('3.- NO SE PUEDE DESHABILITAR: HAY REPUESTOS ACTIVOS DE ESTE TIPO.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Repuesto_Tipo]
SET     rti_codigo                = CASE WHEN @CODIGO = '' THEN rti_codigo ELSE @CODIGO END,
        rti_nombre                = ISNULL(@NOMBRE, rti_nombre),
        rti_descripcion           = @DESCRIPCION,
        rti_orden                 = ISNULL(@ORDEN, rti_orden),
        rti_habilitado            = ISNULL(@HABILITADO, rti_habilitado),
        rti_usuario_actualizacion = @USUARIO,
        rti_fecha_actualizacion   = @AHORA
WHERE   rti_id = @ID AND rti_cliente = @CLIENTE
GO

/* ============================================================ DEL_ */
CREATE OR ALTER PROCEDURE [dbo].[DEL_REPUESTO_TIPO]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

/* Baja logica, no borrado: los repuestos que alguna vez tuvieron este tipo
   siguen apuntandolo, y borrar la fila dejaria la referencia colgando. */
IF EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_repuesto_tipo = @ID)
BEGIN
    RAISERROR('1.- NO SE PUEDE ELIMINAR: HAY REPUESTOS DE ESTE TIPO. DESHABILITELO EN SU LUGAR.', 16, 1)
    RETURN -1
END

DELETE FROM [dbo].[Repuesto_Tipo] WHERE rti_id = @ID AND rti_cliente = @CLIENTE
GO

PRINT '136_REPUESTO_TIPO aplicado.'
GO
