USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - SEL_ACTIVO: filtro por AREA (arbol de ubicacion).
-- =============================================
-- Agrega el parametro @INSTALACION_AREA al listado de activos, para poder
-- filtrar desde el arbol de ubicacion (planta -> area -> linea). Cuando se
-- indica un area, trae los activos de ESA area Y de todas sus sub-areas
-- (recursivo por iar_area_padre): asi, elegir "Panaderia" muestra todo lo de
-- Panaderia, y elegir "Linea 1" solo lo de Linea 1.
--
-- Es CREATE OR ALTER: reemplaza el SEL_ACTIVO existente (mismo cuerpo + el
-- nuevo filtro). El resto de parametros no cambia.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO]
@ID                     INT = NULL,
@CLIENTE                INT = NULL,
@CLIENTE_INSTALACION    INT = NULL,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT = NULL,
@ACTIVO_ESTADO          INT = NULL,
@ACTIVO_PADRE           INT = NULL,
@HABILITADO             BIT = NULL,
@FILTRO                 VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT act.act_id                    AS ACT_ID
                                  ,act.act_cliente                AS ACT_CLIENTE
                                  ,act.act_cliente_instalacion    AS ACT_CLIENTE_INSTALACION
                                  ,act.act_instalacion_area       AS ACT_INSTALACION_AREA
                                  ,act.act_activo_tipo            AS ACT_ACTIVO_TIPO
                                  ,act.act_activo_modelo          AS ACT_ACTIVO_MODELO
                                  ,act.act_activo_estado          AS ACT_ACTIVO_ESTADO
                                  ,act.act_activo_padre           AS ACT_ACTIVO_PADRE
                                  ,act.act_centro_costo           AS ACT_CENTRO_COSTO
                                  ,act.act_criticidad_nivel       AS ACT_CRITICIDAD_NIVEL
                                  ,act.act_codigo                 AS ACT_CODIGO
                                  ,act.act_nombre                 AS ACT_NOMBRE
                                  ,act.act_numero_serie           AS ACT_NUMERO_SERIE
                                  ,act.act_fabricante             AS ACT_FABRICANTE
                                  ,act.act_anio_fabricacion       AS ACT_ANIO_FABRICACION
                                  ,act.act_fecha_puesta_marcha    AS ACT_FECHA_PUESTA_MARCHA
                                  ,act.act_fecha_baja             AS ACT_FECHA_BAJA
                                  ,act.act_descripcion            AS ACT_DESCRIPCION
                                  ,act.act_registro_origen        AS ACT_REGISTRO_ORIGEN
                                  ,act.act_usuario_creacion       AS ACT_USUARIO_CREACION
                                  ,act.act_fecha_creacion         AS ACT_FECHA_CREACION
                                  ,act.act_usuario_actualizacion  AS ACT_USUARIO_ACTUALIZACION
                                  ,act.act_fecha_actualizacion    AS ACT_FECHA_ACTUALIZACION
                                  ,act.act_habilitado             AS ACT_HABILITADO
                                  ,cin.cin_nombre                 AS PLANTA_NOMBRE
                                  ,iar.iar_nombre                 AS AREA_NOMBRE
                                  ,ati.ati_nombre                 AS TIPO_NOMBRE
                                  ,aes.aes_nombre                 AS ESTADO_NOMBRE
                                  ,crn.crn_nombre                 AS CRITICIDAD_NOMBRE
                                  ,cco.cco_nombre                 AS CENTRO_COSTO_NOMBRE
                                  ,pad.act_codigo                 AS PADRE_CODIGO
                                  ,pad.act_nombre                 AS PADRE_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(uc.usu_nombre, '''') + '' '' + ISNULL(uc.usu_apellido_paterno, ''''))) AS USUARIO_CREACION_NOMBRE
                                  ,LTRIM(RTRIM(ISNULL(ua.usu_nombre, '''') + '' '' + ISNULL(ua.usu_apellido_paterno, ''''))) AS USUARIO_ACTUALIZACION_NOMBRE
                 '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM [dbo].[Activo] act
                  INNER JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
                  INNER JOIN [dbo].[Activo_Tipo]         ati ON ati.ati_id = act.act_activo_tipo
                  INNER JOIN [dbo].[Activo_Estado]       aes ON aes.aes_id = act.act_activo_estado
                  INNER JOIN [dbo].[Criticidad_Nivel]    crn ON crn.crn_id = act.act_criticidad_nivel
                  LEFT  JOIN [dbo].[Instalacion_Area]    iar ON iar.iar_id = act.act_instalacion_area
                  LEFT  JOIN [dbo].[Centro_Costo]        cco ON cco.cco_id = act.act_centro_costo
                  LEFT  JOIN [dbo].[Activo]              pad ON pad.act_id = act.act_activo_padre
                  LEFT  JOIN [dbo].[Usuario]             uc  ON uc.usu_id  = act.act_usuario_creacion
                  LEFT  JOIN [dbo].[Usuario]             ua  ON ua.usu_id  = act.act_usuario_actualizacion
                '
END

--AREA + SUB-AREAS (para el filtro por arbol de ubicacion)
DECLARE @AREAS VARCHAR(MAX) = NULL
IF (@INSTALACION_AREA IS NOT NULL)
BEGIN
    DECLARE @arb TABLE (id INT);
    ;WITH arb AS (
        SELECT iar_id FROM [dbo].[Instalacion_Area] WHERE iar_id = @INSTALACION_AREA
        UNION ALL
        SELECT h.iar_id FROM [dbo].[Instalacion_Area] h
        INNER JOIN arb ON h.iar_area_padre = arb.iar_id
    )
    INSERT INTO @arb (id) SELECT iar_id FROM arb;

    SELECT @AREAS = STUFF((SELECT ',' + CAST(id AS VARCHAR(10)) FROM @arb FOR XML PATH('')), 1, 1, '');
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@AREAS IS NOT NULL AND @AREAS <> '') BEGIN
        SET @WHERE = @WHERE + ' AND act.act_instalacion_area IN (' + @AREAS + ') '
    END

    IF (@ACTIVO_TIPO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_tipo = ' + LTRIM(@ACTIVO_TIPO)
    END

    IF (@ACTIVO_ESTADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_estado = ' + LTRIM(@ACTIVO_ESTADO)
    END

    IF (@ACTIVO_PADRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_activo_padre = ' + LTRIM(@ACTIVO_PADRE)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND act.act_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (act.act_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_numero_serie LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR act.act_fabricante LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY act.act_codigo '
END

EXEC(@SELECT + @FROM + @WHERE)
GO

PRINT '142_SPRINT3_SEL_ACTIVO_FILTRO_AREA aplicado.';
GO
