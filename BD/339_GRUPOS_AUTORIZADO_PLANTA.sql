/* ============================================================================
   SIGMA - Bloque 339
   COMBO DE INTEGRANTES: QUIEN ESTA AUTORIZADO EN LA PLANTA DEL GRUPO
   ----------------------------------------------------------------------------
   INS_GRUPO_TRABAJO_USUARIO rechaza a quien no esta autorizado en la planta
   del grupo ("3.- EL USUARIO NO ESTA AUTORIZADO..."), pero el combo lo
   ofrecia igual: se elegia, se pulsaba Agregar y recien ahi aparecia el
   rechazo. SEL_USUARIO_CLIENTE_LISTA agrega AUTORIZADO para que la ficha lo
   muestre deshabilitado y diga por que, antes de elegirlo.
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

/* La planta del grupo, si tiene: solo pueden integrarlo quienes estan
   autorizados en ella (regla 3 de INS_GRUPO_TRABAJO_USUARIO). */
DECLARE @INSTALACION INT
SELECT @INSTALACION = gtr_cliente_instalacion FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO

SELECT  u.usu_id AS USU_ID,
        u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE,
        u.usu_correo AS USU_CORREO,
        u.usu_identificador AS USU_IDENTIFICADOR,
        ISNULL(u.usu_archivo_foto, 0) AS USU_ARCHIVO_FOTO,
        cu.ucl_id AS UCL_ID,
        ISNULL(pf.PERFILES, '') AS PERFILES,
        ISNULL(es.ESPECIALIDADES, '') AS ESPECIALIDADES,
        ISNULL(gr.GRUPOS, '') AS GRUPOS,
        CAST(CASE WHEN @INSTALACION IS NULL
                    OR EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                                WHERE ciu.ciu_id_usuario = u.usu_id
                                  AND ciu.ciu_id_instalacion = @INSTALACION
                                  AND ciu.ciu_habilitado = 1)
                  THEN 1 ELSE 0 END AS BIT) AS AUTORIZADO
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
