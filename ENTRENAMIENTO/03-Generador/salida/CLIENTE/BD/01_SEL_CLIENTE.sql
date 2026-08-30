USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[SEL_CLIENTE]    Fecha de script: 14-08-2026 19:47:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     SELECT DE CLIENTES. SIRVE PARA LISTADO Y PARA GET BY ID.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE]
    @ID         INT          = NULL,
    @FILTRO     VARCHAR(MAX) = NULL,
    @HABILITADO BIT          = NULL

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 4.
--  1. UN SOLO SP para listar y para traer un registro (si viene @ID, filtra).
--  2. Todos los parametros de filtro son "= NULL" (opcionales).
--  3. Query dinamica en 3 bloques: @SELECT / @FROM / @WHERE y un unico EXEC.
--  4. El WHERE arranca con 1=1 para concatenar ANDs sin preguntar.
--  5. NUNCA se devuelven columnas de password en el SELECT.
-- ---------------------------------------------------------------------------

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT  CLI_ID
                                   ,ISNULL(CLI_NOMBRE, '''') AS CLI_NOMBRE
                                   ,CLI_USUARIO_CREACION
                                   ,CLI_FECHA_CREACION
                                   ,CLI_USUARIO_ACT
                                   ,CLI_FECHA_ACT
                                   ,CLI_HABILITADO
                                   '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM CLIENTE
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1
                 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND CLI_ID = ' + LTRIM(@ID)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND CLI_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    -- Busqueda libre de la barra de filtros: se aplica sobre varias columnas.
    IF (@FILTRO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (CLI_NOMBRE LIKE ''%' + LTRIM(@FILTRO) + '%''
                                )'
    END

    SET @WHERE = @WHERE + ' ORDER BY CLI_ID '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
