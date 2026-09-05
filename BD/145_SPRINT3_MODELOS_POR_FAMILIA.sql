USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - MODELOS (MARCAS) A NIVEL DE FAMILIA PRINCIPAL.
-- =============================================
-- Decision de Emilio: el "Tipo" de un modelo debe ser la FAMILIA principal
-- (Panificacion, Refrigeracion, Dosificacion, Envasado), no el equipo puntual
-- (Modeladora, Horno...). Una marca sirve a toda un area.
--
-- QUE HACE:
--   1) SEL_ACTIVO_MODELO: al filtrar por un tipo, ahora incluye los modelos de
--      ese tipo Y de sus tipos-padre (ancestros). Asi, un modelo cargado en la
--      familia "Panificacion" aparece al crear cualquier equipo de esa familia
--      (Modeladora, Amasadora, Horno). Sin esto, un modelo de familia no
--      apareceria para un equipo hoja.
--   2) Promueve "Envasado" a familia principal (padre NULL).
--   3) Re-mapea las marcas a su familia:
--        Fritsch, Diosna, Escher, Alitech -> Panificacion (26)
--        ASA                              -> Envasado (familia)
--        Tecnopool                        -> Refrigeracion (27)  [una sola fila]
--        Zeppelin, Lesaffre               -> Dosificacion (28)   [ya estaban]
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

-- ---------- 1) SP con filtro por tipo + ancestros ----------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MODELO]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @ACTIVO_TIPO INT = NULL,
    @HABILITADO  BIT = NULL,
    @FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    -- Ancestros del tipo pedido (el tipo + sus padres hasta la raiz). Permite
    -- que un modelo cargado en la FAMILIA aparezca para los equipos hoja.
    DECLARE @ANC TABLE (id INT);
    IF @ACTIVO_TIPO IS NOT NULL
    BEGIN
        ;WITH anc AS (
            SELECT ati_id, ati_activo_tipo_padre
            FROM   [dbo].[Activo_Tipo] WHERE ati_id = @ACTIVO_TIPO
            UNION ALL
            SELECT p.ati_id, p.ati_activo_tipo_padre
            FROM   [dbo].[Activo_Tipo] p
            INNER JOIN anc ON p.ati_id = anc.ati_activo_tipo_padre
        )
        INSERT INTO @ANC (id) SELECT ati_id FROM anc;
    END

    SELECT  m.amo_id                                       AS AMO_ID,
            m.amo_cliente                                  AS AMO_CLIENTE,
            m.amo_activo_tipo                              AS AMO_ACTIVO_TIPO,
            ISNULL(m.amo_fabricante, '')                   AS AMO_FABRICANTE,
            m.amo_nombre                                   AS AMO_NOMBRE,
            ISNULL(m.amo_descripcion, '')                  AS AMO_DESCRIPCION,
            m.amo_habilitado                               AS AMO_HABILITADO,
            CAST(CASE WHEN m.amo_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(t.ati_nombre, '')                       AS TIPO_NOMBRE,
            LTRIM(ISNULL(m.amo_fabricante + ' ', '') + m.amo_nombre) AS ETIQUETA,
            m.amo_fecha_creacion                           AS AMO_FECHA_CREACION,
            m.amo_fecha_actualizacion                      AS AMO_FECHA_ACTUALIZACION,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE
    FROM    [dbo].[Activo_Modelo] m
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = m.amo_activo_tipo
    LEFT JOIN [dbo].[Usuario]     uc ON uc.usu_id = m.amo_usuario_creacion
    LEFT JOIN [dbo].[Usuario]     ua ON ua.usu_id = m.amo_usuario_actualizacion
    WHERE   (m.amo_cliente IS NULL OR m.amo_cliente = @CLIENTE)
      AND   (@ID          IS NULL OR m.amo_id          = @ID)
      AND   (@ACTIVO_TIPO IS NULL OR m.amo_activo_tipo IN (SELECT id FROM @ANC))
      AND   (@HABILITADO  IS NULL OR m.amo_habilitado  = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR m.amo_nombre     LIKE '%' + @FILTRO + '%'
             OR m.amo_fabricante LIKE '%' + @FILTRO + '%')
    ORDER BY m.amo_fabricante, m.amo_nombre, m.amo_id
GO

-- ---------- 2) Envasado pasa a familia principal ----------
DECLARE @CLIENTE INT = 1, @ENV INT;
SELECT @ENV = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_nombre = N'Envasado';
IF @ENV IS NOT NULL
    UPDATE [dbo].[Activo_Tipo] SET ati_activo_tipo_padre = NULL WHERE ati_id = @ENV;

-- ---------- 3) Re-mapear marcas a su familia ----------
UPDATE [dbo].[Activo_Modelo] SET amo_activo_tipo = 26   -- Panificacion
WHERE  amo_cliente = @CLIENTE AND amo_fabricante IN (N'Fritsch', N'Diosna', N'Escher', N'Alitech');

IF @ENV IS NOT NULL
    UPDATE [dbo].[Activo_Modelo] SET amo_activo_tipo = @ENV
    WHERE  amo_cliente = @CLIENTE AND amo_fabricante = N'ASA';

-- Tecnopool: dejar UNA fila en Refrigeracion (27); quitar la duplicada.
UPDATE [dbo].[Activo_Modelo] SET amo_activo_tipo = 27
WHERE  amo_cliente = @CLIENTE AND amo_fabricante = N'Tecnopool'
  AND  amo_id = (SELECT MIN(amo_id) FROM [dbo].[Activo_Modelo]
                 WHERE amo_cliente = @CLIENTE AND amo_fabricante = N'Tecnopool');
DELETE FROM [dbo].[Activo_Modelo]
WHERE  amo_cliente = @CLIENTE AND amo_fabricante = N'Tecnopool' AND amo_activo_tipo <> 27;

-- Zeppelin / Lesaffre ya estan en Dosificacion (28): sin cambio.
PRINT '--- Modelos re-mapeados a familia principal.';
GO

/* ========================================================================
   COMPROBACION - modelos por familia
   ======================================================================== */
SELECT t.ati_nombre AS familia_del_modelo,
       LTRIM(ISNULL(m.amo_fabricante + ' ', '') + m.amo_nombre) AS marca
FROM   [dbo].[Activo_Modelo] m
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = m.amo_activo_tipo
WHERE  m.amo_cliente = 1 AND m.amo_habilitado = 1
ORDER  BY t.ati_nombre, m.amo_fabricante;
GO

PRINT '145_SPRINT3_MODELOS_POR_FAMILIA aplicado.';
GO
