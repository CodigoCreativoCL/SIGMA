USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - SEL_ATRIBUTO_TECNICO: unidad como "Nombre (simbolo)".
-- =============================================
-- La columna UNIDAD del listado muestra ahora el nombre con su simbolo entre
-- parentesis: "Kilogramo (kg)", "Metro cubico (m3)", "Grado Celsius (C)".
-- Es el mismo SP; solo cambia la expresion de UNIDAD_NOMBRE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ATRIBUTO_TECNICO]
@CLIENTE     INT,
@ID          INT = NULL,
@ACTIVO_TIPO INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(200) = NULL

AS
SET NOCOUNT ON

    SELECT  a.ate_id                                       AS ATE_ID,
            a.ate_cliente                                  AS ATE_CLIENTE,
            a.ate_activo_tipo                              AS ATE_ACTIVO_TIPO,
            a.ate_tipo_dato                                AS ATE_TIPO_DATO,
            a.ate_unidad_medida                            AS ATE_UNIDAD_MEDIDA,
            a.ate_codigo                                   AS ATE_CODIGO,
            a.ate_nombre                                   AS ATE_NOMBRE,
            a.ate_orden                                    AS ATE_ORDEN,
            a.ate_habilitado                               AS ATE_HABILITADO,
            CAST(CASE WHEN a.ate_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(t.ati_nombre, 'Todos los tipos')        AS TIPO_NOMBRE,
            td.tda_nombre                                  AS TIPO_DATO_NOMBRE,
            ISNULL(u.ume_nombre + ISNULL(' (' + NULLIF(u.ume_simbolo, '') + ')', ''), '') AS UNIDAD_NOMBRE,
            a.ate_fecha_creacion                           AS ATE_FECHA_CREACION,
            a.ate_fecha_actualizacion                      AS ATE_FECHA_ACTUALIZACION,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Atributo_Tecnico] a
    INNER JOIN [dbo].[Tipo_Dato]     td ON td.tda_id = a.ate_tipo_dato
    LEFT  JOIN [dbo].[Activo_Tipo]   t  ON t.ati_id  = a.ate_activo_tipo
    LEFT  JOIN [dbo].[Unidad_Medida] u  ON u.ume_id  = a.ate_unidad_medida
    LEFT  JOIN [dbo].[Usuario]       uc ON uc.usu_id = a.ate_usuario_creacion
    LEFT  JOIN [dbo].[Usuario]       ua ON ua.usu_id = a.ate_usuario_actualizacion
    WHERE   (a.ate_cliente IS NULL OR a.ate_cliente = @CLIENTE)
      AND   (@ID          IS NULL OR a.ate_id          = @ID)
      AND   (@ACTIVO_TIPO IS NULL OR a.ate_activo_tipo = @ACTIVO_TIPO)
      AND   (@HABILITADO  IS NULL OR a.ate_habilitado  = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR a.ate_codigo LIKE '%' + @FILTRO + '%'
             OR a.ate_nombre LIKE '%' + @FILTRO + '%')
    ORDER BY a.ate_orden, a.ate_nombre, a.ate_id
GO

PRINT '149_SPRINT3_SEL_ATRIBUTO_UNIDAD_SIMBOLO aplicado.';
GO
