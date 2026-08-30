USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[SEL_USUARIO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     SELECT DE USUARIOS. SIRVE PARA LISTADO Y PARA GET BY ID.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO]
    @ID         INT          = NULL,
    @FILTRO     VARCHAR(MAX) = NULL,
    @HABILITADO BIT          = NULL,
    @PERFIL     INT          = NULL,
    @PAISES     VARCHAR(MAX) = NULL

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
    SET @SELECT = 'SELECT DISTINCT  USU_ID
                                   ,USU_RUT
                                   ,USU_NOMBRES
                                   ,USU_APELLIDOS
                                   ,USU_EMAIL
                                   ,ISNULL(USU_TELEFONO, '''') AS USU_TELEFONO
                                   ,USU_PERFIL
                                   ,USU_PAIS
                                   ,PER_NOMBRE
                                   ,PAI_NOMBRE
                                   ,USU_USUARIO_CREACION
                                   ,USU_FECHA_CREACION
                                   ,USU_USUARIO_ACT
                                   ,USU_FECHA_ACT
                                   ,USU_HABILITADO
                                   '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM USUARIO
                  INNER JOIN PERFIL ON USU_PERFIL = PER_ID
                  INNER JOIN PAISES ON USU_PAIS = PAI_ID
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1
                 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND USU_ID = ' + LTRIM(@ID)
    END

    IF (@PERFIL IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND USU_PERFIL = ' + LTRIM(@PERFIL)
    END

    -- Seguridad por pais: @PAISES llega como CSV ("1,3,7") desde
    -- Session.UsuarioIdPaises() cuando el perfil no tiene "Ver todo paises".
    IF (@PAISES IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND USU_PAIS IN (' + @PAISES + ')'
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND USU_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    -- Busqueda libre de la barra de filtros: se aplica sobre varias columnas.
    IF (@FILTRO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (USU_RUT       LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_NOMBRES   LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_APELLIDOS LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_EMAIL     LIKE ''%' + LTRIM(@FILTRO) + '%''
                                )'
    END

    SET @WHERE = @WHERE + ' ORDER BY USU_APELLIDOS, USU_NOMBRES '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
