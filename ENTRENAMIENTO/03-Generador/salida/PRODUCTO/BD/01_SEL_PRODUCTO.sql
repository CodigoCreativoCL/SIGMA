USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[SEL_PRODUCTO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     SELECT DE PRODUCTOS. SIRVE PARA LISTADO Y PARA GET BY ID.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_PRODUCTO]
    @ID         INT          = NULL,
    @FILTRO     VARCHAR(MAX) = NULL,
    @HABILITADO BIT          = NULL,
    @CATEGORIA  INT          = NULL,
    @PROVEEDOR  INT          = NULL

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
    SET @SELECT = 'SELECT DISTINCT  PRO_ID
                                   ,PRO_CODIGO
                                   ,PRO_NOMBRE
                                   ,ISNULL(PRO_DESCRIPCION, '''') AS PRO_DESCRIPCION
                                   ,PRO_CATEGORIA
                                   ,ISNULL(PRO_PROVEEDOR, 0) AS PRO_PROVEEDOR
                                   ,PRO_PRECIO
                                   ,ISNULL(PRO_STOCK, 0) AS PRO_STOCK
                                   ,PRO_VENCIMIENTO
                                   ,CAT_NOMBRE
                                   ,PRV_NOMBRE
                                   ,PRO_USUARIO_CREACION
                                   ,PRO_FECHA_CREACION
                                   ,PRO_USUARIO_ACT
                                   ,PRO_FECHA_ACT
                                   ,PRO_HABILITADO
                                   '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM PRODUCTO
                  INNER JOIN CATEGORIA ON PRO_CATEGORIA = CAT_ID
                  LEFT JOIN  PROVEEDOR ON PRO_PROVEEDOR = PRV_ID
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1
                 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND PRO_ID = ' + LTRIM(@ID)
    END

    IF (@CATEGORIA IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND PRO_CATEGORIA = ' + LTRIM(@CATEGORIA)
    END

    IF (@PROVEEDOR IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND PRO_PROVEEDOR = ' + LTRIM(@PROVEEDOR)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND PRO_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    -- Busqueda libre de la barra de filtros: se aplica sobre varias columnas.
    IF (@FILTRO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (PRO_CODIGO LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR PRO_NOMBRE LIKE ''%' + LTRIM(@FILTRO) + '%''
                                )'
    END

    SET @WHERE = @WHERE + ' ORDER BY PRO_NOMBRE '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
