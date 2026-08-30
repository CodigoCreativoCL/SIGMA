USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[SEL_USUARIO]    Fecha de script: 14-08-2026 10:00:00 ******/
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
    @ID         INT             = NULL,
    @FILTRO     VARCHAR(MAX)    = NULL,
    @HABILITADO BIT             = NULL,
    @PERFIL     INT             = NULL,
    @PAIS       INT             = NULL,
    @PAISES     VARCHAR(MAX)    = NULL

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- REGLAS DEL PATRON (ver PATRON_SP.md seccion 4):
--
--  1. UN SOLO SP para listar y para traer un registro: si viene @ID, filtra.
--     No se crea un SEL_USUARIO_BY_ID aparte.
--  2. TODOS los parametros de filtro son "= NULL" (opcionales).
--     Solo los obligatorios de negocio van sin default.
--  3. Query dinamica en 3 bloques: @SELECT / @FROM / @WHERE, y un unico EXEC.
--  4. El WHERE arranca SIEMPRE con "1=1" para poder concatenar ANDs sin
--     preguntar si es el primero.
--  5. Cada filtro se agrega dentro de IF (@PARAM IS NOT NULL).
--     Si el C# no mando el parametro, llega NULL y ese AND no se concatena.
--  6. Se deja un --print comentado para depurar la query armada.
--  7. NUNCA se devuelve USU_PASSWORD en el listado.
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
                  INNER JOIN PAISES ON USU_PAIS   = PAI_ID
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

    IF (@PAIS IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND USU_PAIS = ' + LTRIM(@PAIS)
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
        SET @WHERE = @WHERE + ' AND (USU_NOMBRES   LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_APELLIDOS LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_RUT       LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR USU_EMAIL     LIKE ''%' + LTRIM(@FILTRO) + '%''
                                )'
    END

    SET @WHERE = @WHERE + ' ORDER BY USU_APELLIDOS, USU_NOMBRES '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
