/* ============================================================================
   SIGMA — Bloque 123
   VARIOS RESPONSABLES SIN TENER QUE CREAR UNA CUADRILLA
   ----------------------------------------------------------------------------

   EL PROBLEMA

     `pro_usuario_responsable` es UNA columna: guarda una persona. Para
     asignarle una programacion a tres tecnicos habia que crear un grupo de
     trabajo, y eso obliga a inventar una cuadrilla permanente para resolver
     un encargo puntual. Terminan naciendo grupos de un solo uso que despues
     nadie mantiene, y el catalogo de cuadrillas deja de significar nada.

   LA FORMA CORRECTA

     Una tabla puente. La programacion puede tener N responsables, y sigue
     pudiendo tener en cambio UN grupo cuando la cuadrilla si existe de
     verdad. Son dos maneras legitimas de asignar y ninguna es un rodeo de la
     otra.

   POR QUE SE VA LA COLUMNA VIEJA

     Dejarla seria tener el responsable en dos lugares: la columna diria una
     cosa y la tabla otra, y ninguna consulta sabria cual manda. La columna
     nacio hoy —bloque 118— y no tiene datos: se migra lo que haya y se va.

   LA REGLA "PERSONAS O GRUPO" YA NO PUEDE SER UN CHECK

     Un CHECK no puede mirar otra tabla. La exclusion entre "tiene personas" y
     "tiene grupo" pasa a los procedimientos, que es donde igual habia que
     validarla: la pantalla no es la unica puerta de entrada.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. LA TABLA PUENTE
   ======================================================================== */
IF OBJECT_ID('dbo.Programacion_Responsable') IS NULL
BEGIN
    CREATE TABLE [dbo].[Programacion_Responsable] (
        prr_id              INT IDENTITY(1,1) NOT NULL,
        prr_programacion    INT NOT NULL,
        prr_usuario         INT NOT NULL,
        prr_usuario_creacion INT NOT NULL,
        prr_fecha_creacion  DATETIME NOT NULL CONSTRAINT DF_PRR_FECHA DEFAULT (GETDATE()),

        CONSTRAINT PK_PROGRAMACION_RESPONSABLE PRIMARY KEY (prr_id),

        CONSTRAINT FK_PRR_PROGRAMACION FOREIGN KEY (prr_programacion)
            REFERENCES [dbo].[Programacion] (pro_id),

        CONSTRAINT FK_PRR_USUARIO FOREIGN KEY (prr_usuario)
            REFERENCES [dbo].[Usuario] (usu_id),

        /* La misma persona dos veces en la misma programacion no significa
           nada, y hace que cualquier conteo mienta. */
        CONSTRAINT UQ_PRR_UNICO UNIQUE (prr_programacion, prr_usuario)
    )

    PRINT '--- Programacion_Responsable creada.'
END
ELSE
    PRINT '--- Programacion_Responsable ya existia.'
GO


/* ========================================================================
   2. SE MIGRA LO QUE HAYA Y SE VA LA COLUMNA
   ======================================================================== */
IF COL_LENGTH('dbo.Programacion', 'pro_usuario_responsable') IS NOT NULL
BEGIN
    INSERT INTO [dbo].[Programacion_Responsable]
        (prr_programacion, prr_usuario, prr_usuario_creacion)
    SELECT  p.pro_id, p.pro_usuario_responsable, ISNULL(p.pro_usuario_creacion, 1)
    FROM    [dbo].[Programacion] p
    WHERE   p.pro_usuario_responsable IS NOT NULL
      AND   NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Responsable] r
                         WHERE r.prr_programacion = p.pro_id
                           AND r.prr_usuario = p.pro_usuario_responsable)

    PRINT '--- Migrados: ' + CAST(@@ROWCOUNT AS VARCHAR(10))

    IF OBJECT_ID('dbo.CK_PRO_RESPONSABLE_UNICO') IS NOT NULL
        ALTER TABLE [dbo].[Programacion] DROP CONSTRAINT CK_PRO_RESPONSABLE_UNICO

    IF OBJECT_ID('dbo.FK_PRO_RESPONSABLE') IS NOT NULL
        ALTER TABLE [dbo].[Programacion] DROP CONSTRAINT FK_PRO_RESPONSABLE

    ALTER TABLE [dbo].[Programacion] DROP COLUMN pro_usuario_responsable

    PRINT '--- Columna pro_usuario_responsable eliminada.'
END
ELSE
    PRINT '--- La columna ya no existia.'
GO


/* ========================================================================
   3. LEER Y ESCRIBIR LOS RESPONSABLES
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_RESPONSABLE') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROGRAMACION_RESPONSABLE]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_RESPONSABLE]
    @PROGRAMACION   INT,
    @CLIENTE        INT
AS
SET NOCOUNT ON

    /* El cliente se comprueba por la programacion padre: la fila puente sola
       no sabe de quien es. */
    SELECT  r.prr_id,
            r.prr_usuario,
            NOMBRE = u.usu_nombre + N' ' + u.usu_apellido_paterno
    FROM    [dbo].[Programacion_Responsable] r
    JOIN    [dbo].[Programacion] p ON p.pro_id = r.prr_programacion
    JOIN    [dbo].[Usuario] u      ON u.usu_id = r.prr_usuario
    WHERE   r.prr_programacion = @PROGRAMACION
      AND   p.pro_cliente = @CLIENTE
    ORDER BY u.usu_nombre, u.usu_apellido_paterno
GO

PRINT '--- SEL_PROGRAMACION_RESPONSABLE creado.'
GO


IF OBJECT_ID('dbo.UPS_PROGRAMACION_RESPONSABLE') IS NOT NULL
    DROP PROCEDURE [dbo].[UPS_PROGRAMACION_RESPONSABLE]
GO

/* Reemplaza la lista completa. La pantalla siempre manda el estado final, y
   un "agregar uno / quitar uno" obligaria a que el cliente supiera el
   diferencial: mas viajes y mas formas de quedar desincronizado. */
CREATE PROCEDURE [dbo].[UPS_PROGRAMACION_RESPONSABLE]
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @USUARIOS       VARCHAR(MAX) = NULL,   -- ids separados por coma
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @LISTA TABLE (ID INT PRIMARY KEY)

/* STRING_SPLIT descarta los vacios y el DISTINCT evita que la misma persona
   repetida en la lista reviente contra UQ_PRR_UNICO. */
INSERT INTO @LISTA (ID)
SELECT DISTINCT CAST(LTRIM(RTRIM(value)) AS INT)
FROM   STRING_SPLIT(ISNULL(@USUARIOS, ''), ',')
WHERE  LTRIM(RTRIM(value)) <> ''
  AND  ISNUMERIC(LTRIM(RTRIM(value))) = 1

/* Solo personas de este cliente. Sin esto se podria asignar la programacion
   a alguien de otra empresa mandando su id a mano. */
DELETE FROM @LISTA
WHERE  ID NOT IN (SELECT cu.ucl_id_usuario FROM [dbo].[Cliente_Usuario] cu
                   WHERE cu.ucl_id_cliente = @CLIENTE AND cu.ucl_habilitado = 1)

/* Personas O cuadrilla, no las dos: es la forma mas comun de que al final no
   responda nadie, porque cada parte supone que contestaba la otra. Como un
   CHECK no puede mirar otra tabla, la regla vive aca. */
IF EXISTS (SELECT 1 FROM @LISTA)
   AND EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_grupo_trabajo IS NOT NULL)
BEGIN
    RAISERROR('2.- LA PROGRAMACION YA TIENE UN GRUPO DE TRABAJO: QUITELO ANTES DE ASIGNAR PERSONAS.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    DELETE  r
    FROM    [dbo].[Programacion_Responsable] r
    WHERE   r.prr_programacion = @PROGRAMACION
      AND   r.prr_usuario NOT IN (SELECT ID FROM @LISTA)

    INSERT INTO [dbo].[Programacion_Responsable]
        (prr_programacion, prr_usuario, prr_usuario_creacion)
    SELECT  @PROGRAMACION, l.ID, @USUARIO
    FROM    @LISTA l
    WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Responsable] r
                         WHERE r.prr_programacion = @PROGRAMACION
                           AND r.prr_usuario = l.ID)

COMMIT TRANSACTION

SELECT  CUANTOS = (SELECT COUNT(*) FROM [dbo].[Programacion_Responsable]
                    WHERE prr_programacion = @PROGRAMACION),
        200 AS CODE,
        'Responsables actualizados.' AS MENSAJE
GO

PRINT '--- UPS_PROGRAMACION_RESPONSABLE creado.'
GO


/* ========================================================================
   4. SEL_PROGRAMACION deja de mirar la columna que ya no existe
   ======================================================================== */
PRINT '--- RECORDATORIO: el bloque 103 se vuelve a aplicar despues de este.'
GO

PRINT '123_PROGRAMACION_RESPONSABLES aplicado.'
GO
