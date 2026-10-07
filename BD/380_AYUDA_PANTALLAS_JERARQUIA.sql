USE [db_acd593_sigma]
GO
/* =============================================
   380 — Pantallas de la ayuda contextual y de las campanas: toda pagina del menu
   La sincronizacion (359) solo leia paginas de nivel 3 y 4 bajo un nivel 2 directo, y
   dejaba fuera paginas de nivel 2 (Alertas, SIGMA AI) y las de jerarquias irregulares
   (Perfiles, Programaciones). Ahora sube por el arbol de cada pagina: Modulo = su
   ancestro de nivel 2, Submodulo = su ancestro de nivel 3 (o ella misma).
   TODO IDEMPOTENTE.
   ============================================= */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AYUDA_PANTALLA_SINCRONIZAR]
AS
SET NOCOUNT ON
    ;WITH up AS (
        SELECT  m.mnu_id AS raiz, m.mnu_padre, m.mnu_nivel, m.mnu_nombre, 0 AS salto
        FROM    [dbo].[Menus] m WHERE m.mnu_link LIKE N'~/View/%'
        UNION ALL
        SELECT  u.raiz, p.mnu_padre, p.mnu_nivel, p.mnu_nombre, u.salto + 1
        FROM    up u JOIN [dbo].[Menus] p ON p.mnu_id = u.mnu_padre
        WHERE   u.salto < 8
    ), P AS (
        SELECT  m.mnu_id, m.mnu_link, m.mnu_nombre AS pantalla, m.mnu_visible AS visible,
                ISNULL((SELECT TOP 1 u.mnu_nombre FROM up u WHERE u.raiz = m.mnu_id AND u.mnu_nivel = 2 ORDER BY u.salto), m.mnu_nombre) AS modulo,
                ISNULL((SELECT TOP 1 u.mnu_nombre FROM up u WHERE u.raiz = m.mnu_id AND u.mnu_nivel = 3 ORDER BY u.salto), m.mnu_nombre) AS submodulo
        FROM    [dbo].[Menus] m WHERE m.mnu_link LIKE N'~/View/%'
    )
    MERGE [dbo].[Ayuda_Pantalla] AS t
    USING P AS s ON t.apa_menu = s.mnu_id
    WHEN MATCHED THEN UPDATE SET apa_link = s.mnu_link, apa_modulo = s.modulo, apa_submodulo = s.submodulo,
                                 apa_pantalla = s.pantalla, apa_visible = s.visible, apa_habilitado = 1
    WHEN NOT MATCHED BY TARGET THEN INSERT (apa_menu, apa_link, apa_modulo, apa_submodulo, apa_pantalla, apa_visible)
                                    VALUES (s.mnu_id, s.mnu_link, s.modulo, s.submodulo, s.pantalla, s.visible)
    WHEN NOT MATCHED BY SOURCE THEN UPDATE SET apa_habilitado = 0;
GO
EXEC [dbo].[UPS_AYUDA_PANTALLA_SINCRONIZAR]
GO
