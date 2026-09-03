/* ============================================================================
   SIGMA — Bloque 100
   ESPECIALIDAD PREDOMINANTE CALCULADA PARA GRUPOS DE TRABAJO
   ----------------------------------------------------------------------------
   La especialidad del grupo deja de ser una elección manual. Se obtiene de
   las especialidades habilitadas de sus integrantes vigentes: gana la más
   frecuente; un empate o la ausencia de datos deja el valor en NULL.
   ============================================================================ */

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[REC_GRUPO_TRABAJO_ESPECIALIDAD]
    @GRUPO INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT,
        @HOY DATE,
        @MAXIMO INT,
        @CANTIDAD_GANADORES INT,
        @GANADOR INT

SELECT  @CLIENTE = gtr.gtr_cliente,
        @HOY = CAST([dbo].[FNC_PAIS_HORA](cli.cli_pais) AS DATE)
FROM    [dbo].[Grupo_Trabajo] gtr
JOIN    [dbo].[Cliente] cli ON cli.cli_id = gtr.gtr_cliente
WHERE   gtr.gtr_id = @GRUPO

IF @CLIENTE IS NULL RETURN

;WITH CONTEO AS
(
    SELECT  ues.ues_especialidad AS ESPECIALIDAD,
            COUNT(DISTINCT gtu.gtu_usuario) AS CANTIDAD
    FROM    [dbo].[Grupo_Trabajo_Usuario] gtu
    JOIN    [dbo].[Usuario_Especialidad] ues
            ON  ues.ues_usuario = gtu.gtu_usuario
            AND ues.ues_cliente = @CLIENTE
            AND ues.ues_habilitado = 1
    JOIN    [dbo].[Especialidad] esp
            ON  esp.esp_id = ues.ues_especialidad
            AND esp.esp_habilitado = 1
    WHERE   gtu.gtu_grupo_trabajo = @GRUPO
      AND   gtu.gtu_fecha_inicio <= @HOY
      AND  (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= @HOY)
    GROUP BY ues.ues_especialidad
)
SELECT @MAXIMO = MAX(CANTIDAD) FROM CONTEO

;WITH CONTEO AS
(
    SELECT  ues.ues_especialidad AS ESPECIALIDAD,
            COUNT(DISTINCT gtu.gtu_usuario) AS CANTIDAD
    FROM    [dbo].[Grupo_Trabajo_Usuario] gtu
    JOIN    [dbo].[Usuario_Especialidad] ues
            ON  ues.ues_usuario = gtu.gtu_usuario
            AND ues.ues_cliente = @CLIENTE
            AND ues.ues_habilitado = 1
    JOIN    [dbo].[Especialidad] esp
            ON  esp.esp_id = ues.ues_especialidad
            AND esp.esp_habilitado = 1
    WHERE   gtu.gtu_grupo_trabajo = @GRUPO
      AND   gtu.gtu_fecha_inicio <= @HOY
      AND  (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= @HOY)
    GROUP BY ues.ues_especialidad
)
SELECT  @CANTIDAD_GANADORES = COUNT(*),
        @GANADOR = MAX(ESPECIALIDAD)
FROM    CONTEO
WHERE   CANTIDAD = @MAXIMO

UPDATE [dbo].[Grupo_Trabajo]
SET    gtr_especialidad = CASE WHEN @CANTIDAD_GANADORES = 1 THEN @GANADOR ELSE NULL END
WHERE  gtr_id = @GRUPO
  AND  ISNULL(gtr_especialidad, -1) <>
       ISNULL(CASE WHEN @CANTIDAD_GANADORES = 1 THEN @GANADOR ELSE NULL END, -1)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO_ESPECIALIDAD_RESUMEN]
    @GRUPO INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @HOY DATE

SELECT  @CLIENTE = gtr.gtr_cliente,
        @HOY = CAST([dbo].[FNC_PAIS_HORA](cli.cli_pais) AS DATE)
FROM    [dbo].[Grupo_Trabajo] gtr
JOIN    [dbo].[Cliente] cli ON cli.cli_id = gtr.gtr_cliente
WHERE   gtr.gtr_id = @GRUPO

;WITH CONTEO AS
(
    SELECT  esp.esp_id AS ESP_ID,
            esp.esp_nombre AS ESP_NOMBRE,
            COUNT(DISTINCT gtu.gtu_usuario) AS CANTIDAD
    FROM    [dbo].[Grupo_Trabajo_Usuario] gtu
    JOIN    [dbo].[Usuario_Especialidad] ues
            ON  ues.ues_usuario = gtu.gtu_usuario
            AND ues.ues_cliente = @CLIENTE
            AND ues.ues_habilitado = 1
    JOIN    [dbo].[Especialidad] esp
            ON  esp.esp_id = ues.ues_especialidad
            AND esp.esp_habilitado = 1
    WHERE   gtu.gtu_grupo_trabajo = @GRUPO
      AND   gtu.gtu_fecha_inicio <= @HOY
      AND  (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= @HOY)
    GROUP BY esp.esp_id, esp.esp_nombre
), MARCADO AS
(
    SELECT  *, MAX(CANTIDAD) OVER () AS MAXIMO
    FROM CONTEO
), RESULTADO AS
(
    SELECT *, SUM(CASE WHEN CANTIDAD = MAXIMO THEN 1 ELSE 0 END) OVER () AS GANADORES
    FROM MARCADO
)
SELECT  ESP_ID,
        ESP_NOMBRE,
        CANTIDAD,
        CAST(CASE WHEN CANTIDAD = MAXIMO AND GANADORES = 1 THEN 1 ELSE 0 END AS BIT) AS ES_PREDOMINANTE,
        CAST(CASE WHEN CANTIDAD = MAXIMO AND GANADORES > 1 THEN 1 ELSE 0 END AS BIT) AS ES_EMPATE
FROM    RESULTADO
ORDER BY CANTIDAD DESC, ESP_NOMBRE
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO_USUARIO]
    @ID              INT = NULL,
    @GRUPO_TRABAJO   INT = NULL,
    @USUARIO_DESTINO INT = NULL,
    @SOLO_VIGENTES   BIT = NULL,
    @FILTRO          VARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  gtu.gtu_id               AS GTU_ID,
        gtu.gtu_grupo_trabajo    AS GTU_GRUPO_TRABAJO,
        gtu.gtu_usuario          AS GTU_USUARIO,
        gtu.gtu_es_lider         AS GTU_ES_LIDER,
        gtu.gtu_fecha_inicio     AS GTU_FECHA_INICIO,
        gtu.gtu_fecha_fin        AS GTU_FECHA_FIN,
        gtu.gtu_usuario_creacion AS GTU_USUARIO_CREACION,
        gtu.gtu_fecha_creacion   AS GTU_FECHA_CREACION,
        u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE,
        u.usu_apellido_paterno   AS USU_APELLIDO_PATERNO,
        u.usu_correo             AS USU_CORREO,
        u.usu_identificador      AS USU_IDENTIFICADOR,

        /* La lista dibuja la cara de cada integrante. Necesita la foto si la
           subio; si no, las iniciales sobre el color que le toca por id. Ver
           `SitioBase.Avatar`. */
        ISNULL(u.usu_archivo_foto, 0) AS USU_ARCHIVO_FOTO,
        gtr.gtr_nombre           AS GTR_NOMBRE,
        ISNULL(esp.ESPECIALIDADES, '') AS ESPECIALIDADES,
        CASE WHEN gtu.gtu_fecha_inicio > h.HOY THEN 'PENDIENTE'
             WHEN gtu.gtu_fecha_fin IS NOT NULL
              AND gtu.gtu_fecha_fin < h.HOY THEN 'TERMINADO'
             ELSE 'VIGENTE' END AS ESTADO
FROM    [dbo].[Grupo_Trabajo_Usuario] gtu
JOIN    [dbo].[Usuario] u ON u.usu_id = gtu.gtu_usuario
JOIN    [dbo].[Grupo_Trabajo] gtr ON gtr.gtr_id = gtu.gtu_grupo_trabajo
JOIN    [dbo].[Cliente] cli ON cli.cli_id = gtr.gtr_cliente
/* ----------------------------------------------------------------------
   EL "HOY" ES EL DEL CLIENTE, NO EL DEL SERVIDOR

   El servidor de base de datos esta alojado fuera del pais del cliente:
   su reloj va casi tres horas atras. Con GETDATE(), alguien que en Chile
   agregaba a un integrante "desde hoy" a las 00:30 lo veia PENDIENTE,
   porque para el servidor todavia era ayer. El resumen decia "Sin lider
   vigente" mientras la fila mostraba el chip LIDER: la pantalla se
   contradecia sola.

   La fecha que elige la persona es del calendario de SU pantalla, asi que
   contra esa hay que compararla. FNC_PAIS_HORA hace justo eso, y es lo
   que ya usaban REC_GRUPO_TRABAJO_ESPECIALIDAD y el resto del bloque; la
   vigencia se habia quedado fuera.
   ---------------------------------------------------------------------- */
CROSS APPLY (SELECT CAST([dbo].[FNC_PAIS_HORA](cli.cli_pais) AS DATE) AS HOY) h
OUTER APPLY
(
    SELECT STRING_AGG(e.esp_nombre, ', ') WITHIN GROUP (ORDER BY e.esp_nombre) AS ESPECIALIDADES
    FROM
    (
        SELECT DISTINCT e2.esp_nombre
        FROM   [dbo].[Usuario_Especialidad] ue
        JOIN   [dbo].[Especialidad] e2 ON e2.esp_id = ue.ues_especialidad
        WHERE  ue.ues_usuario = gtu.gtu_usuario
          AND  ue.ues_cliente = gtr.gtr_cliente
          AND  ue.ues_habilitado = 1
          AND  e2.esp_habilitado = 1
    ) e
) esp
WHERE  (@ID IS NULL OR gtu.gtu_id = @ID)
  AND  (@GRUPO_TRABAJO IS NULL OR gtu.gtu_grupo_trabajo = @GRUPO_TRABAJO)
  AND  (@USUARIO_DESTINO IS NULL OR gtu.gtu_usuario = @USUARIO_DESTINO)
  AND  (@SOLO_VIGENTES IS NULL OR @SOLO_VIGENTES = 0
        OR (gtu.gtu_fecha_inicio <= h.HOY
            AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= h.HOY)))
  AND  (@FILTRO IS NULL
        OR u.usu_nombre LIKE '%' + @FILTRO + '%'
        OR u.usu_apellido_paterno LIKE '%' + @FILTRO + '%'
        OR u.usu_identificador LIKE '%' + @FILTRO + '%'
        OR EXISTS
           (
               SELECT 1
               FROM   [dbo].[Usuario_Especialidad] uf
               JOIN   [dbo].[Especialidad] ef ON ef.esp_id = uf.ues_especialidad
               WHERE  uf.ues_usuario = gtu.gtu_usuario
                 AND  uf.ues_cliente = gtr.gtr_cliente
                 AND  uf.ues_habilitado = 1
                 AND  ef.esp_nombre LIKE '%' + @FILTRO + '%'
           ))
ORDER BY gtu.gtu_es_lider DESC, u.usu_apellido_paterno, u.usu_nombre
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
        ISNULL(es.ESPECIALIDADES, '') AS ESPECIALIDADES
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

CREATE OR ALTER TRIGGER [dbo].[TR_GRUPO_TRABAJO_USUARIO_ESPECIALIDAD]
ON [dbo].[Grupo_Trabajo_Usuario]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @GRUPO INT
    DECLARE GRUPOS CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT gtu_grupo_trabajo FROM inserted
        UNION
        SELECT DISTINCT gtu_grupo_trabajo FROM deleted

    OPEN GRUPOS
    FETCH NEXT FROM GRUPOS INTO @GRUPO
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[REC_GRUPO_TRABAJO_ESPECIALIDAD] @GRUPO = @GRUPO
        FETCH NEXT FROM GRUPOS INTO @GRUPO
    END
    CLOSE GRUPOS
    DEALLOCATE GRUPOS
END
GO

CREATE OR ALTER TRIGGER [dbo].[TR_USUARIO_ESPECIALIDAD_GRUPO]
ON [dbo].[Usuario_Especialidad]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @GRUPO INT
    DECLARE GRUPOS CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT gtu.gtu_grupo_trabajo
        FROM [dbo].[Grupo_Trabajo_Usuario] gtu
        JOIN
        (
            SELECT ues_usuario FROM inserted
            UNION
            SELECT ues_usuario FROM deleted
        ) u ON u.ues_usuario = gtu.gtu_usuario

    OPEN GRUPOS
    FETCH NEXT FROM GRUPOS INTO @GRUPO
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[REC_GRUPO_TRABAJO_ESPECIALIDAD] @GRUPO = @GRUPO
        FETCH NEXT FROM GRUPOS INTO @GRUPO
    END
    CLOSE GRUPOS
    DEALLOCATE GRUPOS
END
GO

DECLARE @GRUPO INT
DECLARE GRUPOS CURSOR LOCAL FAST_FORWARD FOR
    SELECT gtr_id FROM [dbo].[Grupo_Trabajo]

OPEN GRUPOS
FETCH NEXT FROM GRUPOS INTO @GRUPO
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [dbo].[REC_GRUPO_TRABAJO_ESPECIALIDAD] @GRUPO = @GRUPO
    FETCH NEXT FROM GRUPOS INTO @GRUPO
END
CLOSE GRUPOS
DEALLOCATE GRUPOS
GO

PRINT '100_GRUPO_ESPECIALIDAD_PREDOMINANTE aplicado.'
GO
