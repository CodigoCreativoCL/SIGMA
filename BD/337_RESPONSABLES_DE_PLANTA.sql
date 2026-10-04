/* ============================================================================
   SIGMA - Bloque 337
   RESPONSABLES DE PLANTA: UNA MARCA PROPIA, SEPARADA DE LA AUTORIZACION
   ----------------------------------------------------------------------------
   Cliente_Instalacion_Usuario dice quien esta AUTORIZADO a trabajar en una
   planta (ver activos, tomar ordenes, firmarlas). En Renca lo estan los 24
   del equipo. La ficha de planta usaba esa misma tabla para "responsables",
   asi que al entrar aparecian todos como responsables y no habia forma de
   distinguir a los dos o tres que estan a cargo.

   ciu_responsable es esa distincion. Ser responsable implica estar
   autorizado: si se marca a alguien que no lo esta, se lo autoriza tambien.
   Desmarcarlo NO le quita la autorizacion.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.Cliente_Instalacion_Usuario', 'ciu_responsable') IS NULL
    ALTER TABLE [dbo].[Cliente_Instalacion_Usuario]
      ADD ciu_responsable BIT NOT NULL
          CONSTRAINT DF_CIU_RESPONSABLE DEFAULT (0)
GO


/* Los usu_id responsables de una planta. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_INSTALACION_RESPONSABLE]
@CLIENTE     INT,
@INSTALACION INT
AS
SET NOCOUNT ON

SELECT  ciu.ciu_id_usuario AS USU_ID
FROM    [dbo].[Cliente_Instalacion_Usuario] ciu
        JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ciu.ciu_id_instalacion
WHERE   ci.cin_cliente          = @CLIENTE
  AND   ciu.ciu_id_instalacion  = @INSTALACION
  AND   ciu.ciu_responsable     = 1
  AND   ciu.ciu_habilitado      = 1
GO


/* Sincroniza los responsables de una planta.
   @MARCAR / @DESMARCAR: listas de usu_id separadas por coma. Solo se
   tocan las personas listadas: la grilla puede venir filtrada y quien no
   aparecio en pantalla no debe cambiar. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_CLIENTE_INSTALACION_RESPONSABLE]
@CLIENTE     INT,
@INSTALACION INT,
@MARCAR      VARCHAR(MAX) = NULL,
@DESMARCAR   VARCHAR(MAX) = NULL,
@USUARIO     INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @M TABLE (ID INT PRIMARY KEY)
DECLARE @D TABLE (ID INT PRIMARY KEY)

INSERT INTO @M SELECT DISTINCT TRY_CAST(value AS INT) FROM STRING_SPLIT(ISNULL(@MARCAR, ''), ',')
                WHERE TRY_CAST(value AS INT) IS NOT NULL
INSERT INTO @D SELECT DISTINCT TRY_CAST(value AS INT) FROM STRING_SPLIT(ISNULL(@DESMARCAR, ''), ',')
                WHERE TRY_CAST(value AS INT) IS NOT NULL

/* Solo gente del cliente. */
DELETE @M WHERE ID NOT IN (SELECT ucl_id_usuario FROM [dbo].[Cliente_Usuario] WHERE ucl_id_cliente = @CLIENTE)

BEGIN TRY
    BEGIN TRANSACTION

    UPDATE ciu
       SET ciu_responsable = 0
      FROM [dbo].[Cliente_Instalacion_Usuario] ciu
      JOIN @D d ON d.ID = ciu.ciu_id_usuario
     WHERE ciu.ciu_id_instalacion = @INSTALACION

    UPDATE ciu
       SET ciu_responsable = 1,
           ciu_habilitado  = 1
      FROM [dbo].[Cliente_Instalacion_Usuario] ciu
      JOIN @M m ON m.ID = ciu.ciu_id_usuario
     WHERE ciu.ciu_id_instalacion = @INSTALACION

    /* Responsable sin autorizacion previa: se lo autoriza. */
    INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
        (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
         ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin, ciu_responsable)
    SELECT @INSTALACION, m.ID, @USUARIO, @DATE_NOW, 1, CAST(@DATE_NOW AS DATE), NULL, 1
      FROM @M m
     WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] x
                        WHERE x.ciu_id_instalacion = @INSTALACION AND x.ciu_id_usuario = m.ID)

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_CLIENTE_INSTALACION_RESPONSABLE @INSTALACION = ' + LTRIM(STR(@INSTALACION))
    EXEC [dbo].[INS_EXCEPCION] @MSG = '2.- NO FUE POSIBLE GUARDAR LOS RESPONSABLES DE LA PLANTA.', @VARIABLES = @VARIABLES
    RAISERROR('2.- NO FUE POSIBLE GUARDAR LOS RESPONSABLES DE LA PLANTA.', 16, 1)
    RETURN -1
END CATCH

RETURN 0
GO
