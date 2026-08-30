USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     SOPORTE DEL MANTENEDOR DE MENUS Y FUNCIONES.
-- =============================================
-- Va DESPUES de 02_MENUS_PERMISOS.
--
-- SEL_MENUS se dejo intacto: lo consume el menu lateral y no necesita el
-- permiso. El mantenedor usa SEL_MENUS_MANTENEDOR, que ademas trae el
-- codigo del permiso y el nombre del padre para mostrarlos en la grilla.
--
-- Tambien registra la pagina del mantenedor en el propio arbol de menus,
-- que es la prueba de que el circuito cierra: el mantenedor se da de alta
-- a si mismo por datos, sin recompilar nada.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS_MANTENEDOR]
    @ID     INT = NULL,
    @PADRE  INT = NULL,
    @FILTRO VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT m.mnu_id           AS MNU_ID,
           m.mnu_nombre       AS MNU_NOMBRE,
           m.mnu_descripcion  AS MNU_DESCRIPCION,
           m.mnu_nivel        AS MNU_NIVEL,
           m.mnu_padre        AS MNU_PADRE,
           m.mnu_orden        AS MNU_ORDEN,
           m.mnu_link         AS MNU_LINK,
           m.mnu_visible      AS MNU_VISIBLE,
           ISNULL(m.mnu_icon, '')        AS MNU_ICON,
           ISNULL(m.mnu_permiso, 0)      AS MNU_PERMISO,
           ISNULL(p.prm_codigo, '')      AS PRM_CODIGO,
           ISNULL(pa.mnu_nombre, '')     AS PADRE_NOMBRE,
           CASE WHEN m.mnu_link = '#' THEN 'Contenedor' ELSE 'Pagina' END AS MNU_TIPO
    FROM   [dbo].[Menus] m
    LEFT   JOIN [dbo].[Permiso] p  ON p.prm_id  = m.mnu_permiso
    LEFT   JOIN [dbo].[Menus]   pa ON pa.mnu_id = m.mnu_padre
    WHERE  (@ID     IS NULL OR m.mnu_id    = @ID)
      AND  (@PADRE  IS NULL OR m.mnu_padre = @PADRE)
      AND  (@FILTRO IS NULL OR m.mnu_nombre LIKE '%' + @FILTRO + '%'
                            OR m.mnu_link   LIKE '%' + @FILTRO + '%')
    ORDER BY m.mnu_nivel, m.mnu_padre, m.mnu_orden
GO


/* ========================================================================
   EL MANTENEDOR SE DA DE ALTA A SI MISMO
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'VER MANTENEDOR MENUS')
    INSERT INTO [dbo].[Permiso] ([prm_codigo],[prm_nombre],[prm_modulo],[prm_permiso_ambito],[prm_usuario_creacion])
    VALUES (N'VER MANTENEDOR MENUS', N'Ver el mantenedor de menus y funciones', N'SEGURIDAD', 1, 1)
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = N'~/View/Root/Mantenedores/Menus/Menus.aspx')
    INSERT INTO [dbo].[Menus] ([mnu_nombre],[mnu_descripcion],[mnu_nivel],[mnu_padre],
                               [mnu_orden],[mnu_link],[mnu_visible],[mnu_icon],[mnu_permiso])
    SELECT N'Mantenedor de Menus', N'Menus, funciones y su permiso', 4, 3, 4,
           N'~/View/Root/Mantenedores/Menus/Menus.aspx', 1, N'',
           (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER MANTENEDOR MENUS')
GO

-- Root recibe el permiso nuevo
INSERT INTO [dbo].[Perfil_Permiso] ([ppe_perfil],[ppe_permiso],[ppe_usuario_creacion])
SELECT 1, p.prm_id, 1
FROM   [dbo].[Permiso] p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1 AND ppe_permiso = p.prm_id)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'menus hoja sin permiso'  AS control, COUNT(*) AS valor FROM [dbo].[Menus] WHERE mnu_link <> '#' AND mnu_permiso IS NULL
UNION ALL SELECT 'menus totales',            COUNT(*) FROM [dbo].[Menus]
UNION ALL SELECT 'permisos en catalogo',     COUNT(*) FROM [dbo].[Permiso]
UNION ALL SELECT 'permisos del perfil Root', COUNT(*) FROM [dbo].[Perfil_Permiso] WHERE ppe_perfil = 1
GO
