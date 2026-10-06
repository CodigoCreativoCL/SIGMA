/* ============================================================================
   SIGMA - Bloque 358
   MOVER UN COMPONENTE A OTRO ACTIVO O SUBACTIVO (arrastrar en el explorador)
   ----------------------------------------------------------------------------
   En el explorador de la planta un componente se arrastra a un subactivo (o
   de vuelta al activo). UPD_ACTIVO_COMPONENTE nunca cambia aco_activo, asi
   que hace falta este SP:
     - mueve la pieza y TODO lo que cuelga de ella (sus partes internas): un
       hijo debe estar en el mismo activo que su padre;
     - la pieza queda directo en el destino (sin componente padre);
     - lo que DESCRIBE a la pieza la sigue: sus variables, medidores, fotos
       y planes asignados (filas que apuntaban al activo de origen);
     - lo HISTORICO no se toca: OT, fallas, bitacora, mediciones, alertas,
       hallazgos, predicciones y ocurrencias quedan en el activo donde
       ocurrieron;
     - valida las mismas reglas de UPD_ACTIVO_COMPONENTE en el destino:
       codigo unico por activo y un tipo por posicion.
   Mover dentro del mismo activo solo saca a la pieza de su componente padre.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_COMPONENTE_MOVER]
    @ID       INT,
    @ACTIVO   INT,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @ORIGEN INT, @PADRE INT, @PAIS INT, @DATE_NOW DATETIME, @CODIGO NVARCHAR(100)

SELECT @CLIENTE = aco_cliente, @ORIGEN = aco_activo, @PADRE = aco_componente_padre
FROM   [dbo].[Activo_Componente]
WHERE  aco_id = @ID AND aco_habilitado = 1

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE AND act_habilitado = 1)
BEGIN
    RAISERROR('2.- EL ACTIVO DE DESTINO NO EXISTE.', 16, 1)
    RETURN -1
END

-- ya esta ahi, directo en el activo: nada que hacer
IF @ORIGEN = @ACTIVO AND @PADRE IS NULL RETURN 0

-- la pieza y todo lo que cuelga de ella
DECLARE @MOVER TABLE (id INT PRIMARY KEY)
;WITH arbol AS (
    SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_id = @ID
    UNION ALL
    SELECT k.aco_id FROM [dbo].[Activo_Componente] k JOIN arbol a ON k.aco_componente_padre = a.aco_id
)
INSERT INTO @MOVER (id) SELECT aco_id FROM arbol OPTION (MAXRECURSION 100)

IF @ORIGEN <> @ACTIVO
BEGIN
    SELECT TOP 1 @CODIGO = m.aco_codigo
    FROM   [dbo].[Activo_Componente] m
    JOIN   [dbo].[Activo_Componente] d ON d.aco_activo = @ACTIVO AND d.aco_codigo = m.aco_codigo
    WHERE  m.aco_id IN (SELECT id FROM @MOVER) AND d.aco_id NOT IN (SELECT id FROM @MOVER)
    IF @CODIGO IS NOT NULL
    BEGIN
        RAISERROR('3.- EL DESTINO YA TIENE UN COMPONENTE CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    -- un tipo por posicion (la regla 4 de UPD_ACTIVO_COMPONENTE)
    IF EXISTS (SELECT 1
               FROM   [dbo].[Activo_Componente] m
               JOIN   [dbo].[Activo_Componente] d ON d.aco_activo = @ACTIVO AND d.aco_habilitado = 1
                      AND d.aco_componente_tipo = m.aco_componente_tipo
                      AND ISNULL(d.aco_componente_posicion, 0) = ISNULL(m.aco_componente_posicion, 0)
               WHERE  m.aco_id IN (SELECT id FROM @MOVER) AND d.aco_id NOT IN (SELECT id FROM @MOVER))
    BEGIN
        RAISERROR('4.- EL DESTINO YA TIENE UN COMPONENTE DE ESE TIPO EN ESA POSICION.', 16, 1)
        RETURN -1
    END
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE [dbo].[Activo_Componente]
    SET    aco_activo = @ACTIVO, aco_usuario_actualizacion = @USUARIO, aco_fecha_actualizacion = @DATE_NOW
    WHERE  aco_id IN (SELECT id FROM @MOVER)

    UPDATE [dbo].[Activo_Componente] SET aco_componente_padre = NULL WHERE aco_id = @ID

    IF @ORIGEN <> @ACTIVO
    BEGIN
        UPDATE [dbo].[Activo_Variable]            SET ava_activo = @ACTIVO WHERE ava_activo = @ORIGEN AND ava_activo_componente IN (SELECT id FROM @MOVER)
        UPDATE [dbo].[Activo_Medidor]             SET ame_activo = @ACTIVO WHERE ame_activo = @ORIGEN AND ame_activo_componente IN (SELECT id FROM @MOVER)
        UPDATE [dbo].[Archivo_Vinculo]            SET avi_activo = @ACTIVO WHERE avi_activo = @ORIGEN AND avi_activo_componente IN (SELECT id FROM @MOVER)
        UPDATE [dbo].[Repuesto_Compatibilidad]    SET rco_activo = @ACTIVO WHERE rco_activo = @ORIGEN AND rco_activo_componente IN (SELECT id FROM @MOVER)
        UPDATE [dbo].[Plan_Mantenimiento_Activo]  SET pac_activo = @ACTIVO WHERE pac_activo = @ORIGEN AND pac_activo_componente IN (SELECT id FROM @MOVER)
    END

COMMIT TRANSACTION

RETURN(0)
GO

SELECT CASE WHEN OBJECT_ID(N'dbo.UPD_ACTIVO_COMPONENTE_MOVER') IS NOT NULL THEN 'OK' ELSE 'FALTA' END AS MOVER
GO
