/* ============================================================================
   SIGMA - Bloque 338
   GRUPOS DE TRABAJO: DISPONIBILIDAD AL SUMAR Y CARAS DE LOS INTEGRANTES
   ----------------------------------------------------------------------------
   1. SEL_USUARIO_CLIENTE_LISTA agrega GRUPOS: los otros grupos vigentes de
      cada persona, para que el combo "¿Quién se suma al grupo?" diga si esta
      disponible o ya pertenece a otro.
   2. SEL_GRUPO_TRABAJO agrega INTEGRANTES_NOMBRES (separados por |, lider
      primero), para dibujar los avatares en la grilla en vez del numero.
   Nada mas cambia: mismas columnas, filtros y orden.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_CLIENTE_LISTA]
    @CLIENTE INT,
    @FILTRO VARCHAR(200) = NULL,
    @GRUPO_TRABAJO INT = NULL
AS
SET NOCOUNT ON

/* Mismo criterio que arriba: quien ya esta vigente en el grupo no vuelve a
   ofrecerse, y "vigente" se mide con la hora del pais del cliente. */
DECLARE @HOY DATE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)) AS DATE)

SELECT  u.usu_id AS USU_ID,
        u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE,
        u.usu_correo AS USU_CORREO,
        u.usu_identificador AS USU_IDENTIFICADOR,
        ISNULL(u.usu_archivo_foto, 0) AS USU_ARCHIVO_FOTO,
        cu.ucl_id AS UCL_ID,
        ISNULL(pf.PERFILES, '') AS PERFILES,
        ISNULL(es.ESPECIALIDADES, '') AS ESPECIALIDADES,
        ISNULL(gr.GRUPOS, '') AS GRUPOS
FROM    [dbo].[Cliente_Usuario] cu
JOIN    [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
OUTER APPLY
(
    SELECT STRING_AGG(p.per_nombre, ', ') WITHIN GROUP (ORDER BY p.per_nombre) AS PERFILES
    FROM   [dbo].[Cliente_Usuario_Perfil] cup
    JOIN   [dbo].[Perfiles] p ON p.per_id = cup.cup_id_perfil
    WHERE  cup.cup_id_cliente_usuario = cu.ucl_id
      AND  p.per_habilitado = 1
) pf
OUTER APPLY
(
    SELECT STRING_AGG(e.esp_nombre, ', ') WITHIN GROUP (ORDER BY e.esp_nombre) AS ESPECIALIDADES
    FROM
    (
        SELECT DISTINCT e2.esp_nombre
        FROM   [dbo].[Usuario_Especialidad] ue
        JOIN   [dbo].[Especialidad] e2 ON e2.esp_id = ue.ues_especialidad
        WHERE  ue.ues_usuario = u.usu_id
          AND  ue.ues_cliente = @CLIENTE
          AND  ue.ues_habilitado = 1
          AND  e2.esp_habilitado = 1
    ) e
) es
OUTER APPLY
(
    /* Los OTROS grupos vigentes de la persona en este cliente: al sumarla
       a un grupo hay que saber si ya esta comprometida en otro turno. */
    SELECT STRING_AGG(g.gtr_nombre, ', ') WITHIN GROUP (ORDER BY g.gtr_nombre) AS GRUPOS
    FROM   [dbo].[Grupo_Trabajo_Usuario] gu
    JOIN   [dbo].[Grupo_Trabajo] g ON g.gtr_id = gu.gtu_grupo_trabajo
    WHERE  gu.gtu_usuario = u.usu_id
      AND  g.gtr_cliente = @CLIENTE
      AND  g.gtr_habilitado = 1
      AND  (@GRUPO_TRABAJO IS NULL OR g.gtr_id <> @GRUPO_TRABAJO)
      AND  gu.gtu_fecha_inicio <= @HOY
      AND (gu.gtu_fecha_fin IS NULL OR gu.gtu_fecha_fin >= @HOY)
) gr
WHERE   cu.ucl_id_cliente = @CLIENTE
  AND   ISNULL(cu.ucl_habilitado, 0) = 1
  AND   u.usu_habilitado = 1
  AND  (@GRUPO_TRABAJO IS NULL OR NOT EXISTS
       (
           SELECT 1
           FROM   [dbo].[Grupo_Trabajo_Usuario] gx
           WHERE  gx.gtu_grupo_trabajo = @GRUPO_TRABAJO
             AND  gx.gtu_usuario = u.usu_id
             AND  gx.gtu_fecha_inicio <= @HOY
             AND (gx.gtu_fecha_fin IS NULL OR gx.gtu_fecha_fin >= @HOY)
       ))
  AND  (@FILTRO IS NULL
        OR u.usu_nombre LIKE '%' + @FILTRO + '%'
        OR u.usu_apellido_paterno LIKE '%' + @FILTRO + '%'
        OR u.usu_identificador LIKE '%' + @FILTRO + '%'
        OR es.ESPECIALIDADES LIKE '%' + @FILTRO + '%')
ORDER BY u.usu_apellido_paterno, u.usu_nombre
GO


/* ========================================================================
   SEL_GRUPO_TRABAJO

   Trae el lider vigente y cuantos integrantes vigentes tiene el grupo: son
   las dos columnas que la grilla necesita y evitan una consulta por fila.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO]
@ID                   INT = NULL,
@CLIENTE              INT = NULL,
@CLIENTE_INSTALACION  INT = NULL,
@ESPECIALIDAD         INT = NULL,
@HABILITADO           BIT = NULL,
@FILTRO               VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT gtr.gtr_id                  AS GTR_ID
                                 ,gtr.gtr_cliente              AS GTR_CLIENTE
                                 ,gtr.gtr_cliente_instalacion  AS GTR_CLIENTE_INSTALACION
                                 ,gtr.gtr_codigo               AS GTR_CODIGO
                                 ,gtr.gtr_nombre               AS GTR_NOMBRE
                                 ,gtr.gtr_especialidad         AS GTR_ESPECIALIDAD
                                 ,gtr.gtr_descripcion          AS GTR_DESCRIPCION
                                 ,gtr.gtr_habilitado           AS GTR_HABILITADO
                                 ,gtr.gtr_usuario_creacion     AS GTR_USUARIO_CREACION
                                 ,gtr.gtr_fecha_creacion       AS GTR_FECHA_CREACION
                                 ,gtr.gtr_usuario_actualizacion AS GTR_USUARIO_ACTUALIZACION
                                 ,gtr.gtr_fecha_actualizacion  AS GTR_FECHA_ACTUALIZACION
                                 ,ISNULL(cin.cin_nombre, ''Todas las plantas'') AS CIN_NOMBRE
                                 ,esp.esp_nombre               AS ESP_NOMBRE
                                 ,(SELECT COUNT(*) FROM Grupo_Trabajo_Usuario gtu
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
                                  )                            AS INTEGRANTES
                                 ,(SELECT TOP 1 ul.usu_nombre + SPACE(1) + ul.usu_apellido_paterno
                                     FROM Grupo_Trabajo_Usuario gtu
                                     INNER JOIN Usuario ul ON ul.usu_id = gtu.gtu_usuario
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_es_lider = 1
                                      AND gtu.gtu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
                                  )                            AS LIDER
                                 ,(SELECT STRING_AGG(ui.usu_nombre + SPACE(1) + ui.usu_apellido_paterno, ''|'')
                                          WITHIN GROUP (ORDER BY gtu.gtu_es_lider DESC, ui.usu_nombre)
                                     FROM Grupo_Trabajo_Usuario gtu
                                     INNER JOIN Usuario ui ON ui.usu_id = gtu.gtu_usuario
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
                                  )                            AS INTEGRANTES_NOMBRES
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Grupo_Trabajo gtr
                       LEFT JOIN Cliente_Instalacion cin ON cin.cin_id = gtr.gtr_cliente_instalacion
                       LEFT JOIN Especialidad esp        ON esp.esp_id = gtr.gtr_especialidad
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_cliente = ' + LTRIM(@CLIENTE)
    END

    /* Un grupo transversal (sin planta) aparece tambien cuando se filtra
       por una planta: es asignable en todas. */
    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (gtr.gtr_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION) +
                                  ' OR gtr.gtr_cliente_instalacion IS NULL) '
    END

    IF (@ESPECIALIDAD IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_especialidad = ' + LTRIM(@ESPECIALIDAD)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (gtr.gtr_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_descripcion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY gtr.gtr_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO
