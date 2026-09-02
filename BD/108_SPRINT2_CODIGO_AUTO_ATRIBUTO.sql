USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SUMA Atributo_Tecnico AL CODIGO AUTOMATICO (HU-032).
-- =============================================
-- Va DESPUES de 107_SPRINT2_ATRIBUTO_TECNICO (necesita INS_ATRIBUTO_TECNICO).
--
-- Mismo patron que el bloque 100: registra Atributo_Tecnico en Modulo_Codigo
-- con prefijo ATR y parchea INS_ATRIBUTO_TECNICO para que el codigo se genere
-- solo (ATR-<id>) justo despues de SET @ID = SCOPE_IDENTITY(). La ficha manda
-- 'AUTO' y el INSERT lo reemplaza por el definitivo apenas conoce el @ID.
--
-- Reutiliza la infraestructura de Bryan (Modulo_Codigo + FNC_CODIGO_AUTOMATICO).
-- ES IDEMPOTENTE: el MERGE no duplica; el parche salta el INS ya parcheado.
-- =============================================

SET NOCOUNT ON
GO

IF OBJECT_ID('dbo.Modulo_Codigo') IS NULL OR OBJECT_ID('dbo.FNC_CODIGO_AUTOMATICO') IS NULL
BEGIN
    RAISERROR('Falta el sistema de codigo automatico (Modulo_Codigo / FNC_CODIGO_AUTOMATICO). Ejecute antes el bloque 77_CODIGO_AUTOMATICO.', 16, 1)
    RETURN
END
GO


/* ========================================================================
   1. REGISTRAR Atributo_Tecnico EN EL CATALOGO DE PREFIJOS
   ======================================================================== */
MERGE [dbo].[Modulo_Codigo] AS d
USING (VALUES
    ('Atributo_Tecnico', 'ATR', 'ate_codigo', 'ate_id', 'INS_ATRIBUTO_TECNICO')
) AS o (tab, pre, col, cid, spr)
    ON d.mco_tabla = o.tab
WHEN MATCHED THEN UPDATE SET
    d.mco_prefijo = o.pre, d.mco_columna_codigo = o.col,
    d.mco_columna_id = o.cid, d.mco_procedimiento = o.spr
WHEN NOT MATCHED THEN
    INSERT (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento)
    VALUES (o.tab, o.pre, o.col, o.cid, o.spr);
PRINT '--- Atributo_Tecnico en Modulo_Codigo: ' + LTRIM(STR(@@ROWCOUNT))
GO


/* ========================================================================
   2. PARCHEAR INS_ATRIBUTO_TECNICO (mismo patron del bloque 100/77)
   ======================================================================== */
DECLARE @tab NVARCHAR(128), @pre NVARCHAR(6), @col NVARCHAR(128),
        @cid NVARCHAR(128), @spr NVARCHAR(128)
DECLARE @def NVARCHAR(MAX), @nuevo NVARCHAR(MAX), @snippet NVARCHAR(MAX)
DECLARE @drop NVARCHAR(400), @hechos INT = 0, @saltados INT = 0

DECLARE cur CURSOR FOR
    SELECT mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento
    FROM   [dbo].[Modulo_Codigo]
    WHERE  mco_habilitado = 1 AND mco_tabla = 'Atributo_Tecnico'

OPEN cur
FETCH NEXT FROM cur INTO @tab, @pre, @col, @cid, @spr

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID('dbo.' + @spr))

    IF @def IS NULL
    BEGIN
        PRINT '*** ' + @spr + ': no existe'
        SET @saltados = @saltados + 1
    END
    ELSE IF @def LIKE '%CODIGO AUTOMATICO%'
    BEGIN
        PRINT '--- ' + @spr + ': ya estaba'
        SET @saltados = @saltados + 1
    END
    ELSE IF CHARINDEX('SET @ID = SCOPE_IDENTITY()', @def) = 0
    BEGIN
        PRINT '*** ' + @spr + ': no tiene el punto de insercion esperado'
        SET @saltados = @saltados + 1
    END
    ELSE
    BEGIN
        SET @snippet =
            CHAR(13) + CHAR(10) +
            '    /* ---- CODIGO AUTOMATICO ----' + CHAR(13) + CHAR(10) +
            '       El codigo depende del ID, y el ID no existe hasta esta linea.' + CHAR(13) + CHAR(10) +
            '       La ficha manda ''AUTO'': ese valor satisface el NOT NULL, pasa' + CHAR(13) + CHAR(10) +
            '       por el INSERT y nunca queda guardado. */' + CHAR(13) + CHAR(10) +
            '    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = ''AUTO'')' + CHAR(13) + CHAR(10) +
            '        UPDATE [dbo].[' + @tab + ']' + CHAR(13) + CHAR(10) +
            '        SET    [' + @col + '] = [dbo].[FNC_CODIGO_AUTOMATICO](''' + @pre + ''', @ID)' + CHAR(13) + CHAR(10) +
            '        WHERE  [' + @cid + '] = @ID' + CHAR(13) + CHAR(10)

        SET @nuevo = REPLACE(@def, 'SET @ID = SCOPE_IDENTITY()',
                                   'SET @ID = SCOPE_IDENTITY()' + @snippet)

        SET @drop = 'DROP PROCEDURE [dbo].[' + @spr + ']'

        BEGIN TRY
            BEGIN TRANSACTION
                EXEC sp_executesql @drop
                EXEC sp_executesql @nuevo
            COMMIT TRANSACTION
            PRINT '--- ' + @spr + ': ' + @pre + '-<id>'
            SET @hechos = @hechos + 1
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            PRINT '*** ' + @spr + ': ' + ERROR_MESSAGE()
            SET @saltados = @saltados + 1
        END CATCH
    END

    FETCH NEXT FROM cur INTO @tab, @pre, @col, @cid, @spr
END

CLOSE cur
DEALLOCATE cur

PRINT '=== Parcheados ahora: ' + LTRIM(STR(@hechos)) + '  |  Omitidos: ' + LTRIM(STR(@saltados))
GO


/* ========================================================================
   3. VERIFICACION
   ======================================================================== */
SELECT  m.mco_procedimiento AS PROCEDIMIENTO, m.mco_prefijo AS PREFIJO,
        CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.' + m.mco_procedimiento)) LIKE '%CODIGO AUTOMATICO%'
             THEN 'OK' ELSE '*** FALTA' END AS ESTADO
FROM    [dbo].[Modulo_Codigo] m
WHERE   m.mco_tabla = 'Atributo_Tecnico'
GO

PRINT '108_SPRINT2_CODIGO_AUTO_ATRIBUTO aplicado.'
GO
