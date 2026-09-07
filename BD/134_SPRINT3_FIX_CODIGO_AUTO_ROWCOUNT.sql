USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     ARREGLA EL BUG DEL CODIGO AUTOMATICO CON CODIGO MANUAL.
-- =============================================
-- EL SINTOMA
--   Al crear un registro (tipo de activo, atributo, etc.) ESCRIBIENDO el
--   codigo a mano, sale "NO FUE POSIBLE INSERTAR..." aunque el INSERT fue
--   correcto. Con el codigo VACIO (automatico) funciona.
--
-- LA CAUSA
--   El parche de codigo automatico inyecta, justo despues de
--   SET @ID = SCOPE_IDENTITY(), un:
--       IF (@CODIGO es AUTO/vacio)  UPDATE ... FNC_CODIGO_AUTOMATICO ...
--   Cuando el codigo es MANUAL, ese IF no ejecuta el UPDATE y deja
--   @@ROWCOUNT en 0. La linea siguiente, "IF @@ROWCOUNT = 0", cree que el
--   INSERT fallo y hace ROLLBACK. Con codigo automatico el UPDATE si corre,
--   deja @@ROWCOUNT = 1 y no se nota.
--
-- LA CORRECCION
--   Cambiar el chequeo de "IF @@ROWCOUNT = 0" por "IF @ID IS NULL": el @ID
--   (SCOPE_IDENTITY) solo es NULL si el INSERT realmente fallo, y no depende
--   de si el UPDATE de codigo corrio o no. Se aplica a TODOS los INS_ parchados
--   (los registrados en Modulo_Codigo).
--
-- ES IDEMPOTENTE: si un SP ya no tiene el patron, se salta.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @spr NVARCHAR(128), @def NVARCHAR(MAX), @nuevo NVARCHAR(MAX)
DECLARE @hechos INT = 0, @saltados INT = 0

DECLARE cur CURSOR FOR
    SELECT DISTINCT mco_procedimiento FROM [dbo].[Modulo_Codigo] WHERE mco_habilitado = 1

OPEN cur
FETCH NEXT FROM cur INTO @spr

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID('dbo.' + @spr))

    IF @def IS NULL
    BEGIN
        PRINT '*** ' + @spr + ': no existe'
        SET @saltados = @saltados + 1
    END
    ELSE IF @def NOT LIKE '%CODIGO AUTOMATICO%' OR @def NOT LIKE '%IF @@ROWCOUNT = 0%'
    BEGIN
        PRINT '--- ' + @spr + ': sin el patron (ya arreglado o distinto)'
        SET @saltados = @saltados + 1
    END
    ELSE
    BEGIN
        -- Solo el chequeo post-insert. Los INS_ de mantenedor tienen UN solo
        -- "IF @@ROWCOUNT = 0" (el de la insercion), asi que el reemplazo es seguro.
        SET @nuevo = REPLACE(@def, 'IF @@ROWCOUNT = 0', 'IF @ID IS NULL')
        SET @nuevo = REPLACE(@nuevo, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
        SET @nuevo = REPLACE(@nuevo, 'CREATE   PROCEDURE', 'ALTER   PROCEDURE')

        BEGIN TRY
            EXEC sp_executesql @nuevo
            PRINT '--- ' + @spr + ': arreglado (IF @ID IS NULL)'
            SET @hechos = @hechos + 1
        END TRY
        BEGIN CATCH
            PRINT '*** ' + @spr + ': ' + ERROR_MESSAGE()
            SET @saltados = @saltados + 1
        END CATCH
    END

    FETCH NEXT FROM cur INTO @spr
END

CLOSE cur
DEALLOCATE cur

PRINT '=== Arreglados: ' + LTRIM(STR(@hechos)) + '  |  Saltados: ' + LTRIM(STR(@saltados))
GO

PRINT '134_SPRINT3_FIX_CODIGO_AUTO_ROWCOUNT aplicado.'
GO
