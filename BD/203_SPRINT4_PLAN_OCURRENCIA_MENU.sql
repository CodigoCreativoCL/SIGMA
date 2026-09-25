USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-086) T-4174/T-4175 REGISTRA la pantalla
--                  PlanOcurrenciaReprogramar.aspx en Menus (reprogramar una
--                  ocurrencia del plan). Va oculta (mnu_orden 99, mnu_visible
--                  0): se abre en modal desde el calendario / listado de
--                  ocurrencias. Sin fila en Menus el servidor no la sirve
--                  (seguridad de pagina, no esconder el boton). Reusa los
--                  permisos del modulo de planes: ver con VER PLANES
--                  MANTENIMIENTO (116) y reprogramar con CREAR EDITAR PLANES
--                  MANTENIMIENTO (117), via Menu_Funcion 'Crear y editar'. El
--                  filtro por cliente lo hace el SP. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN RAISERROR('No existe el nodo Mantenimiento.', 16, 1) RETURN END

DECLARE @LINK NVARCHAR(500) = N'~/View/Mantenimiento/Planes/PlanOcurrenciaReprogramar.aspx'

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT N'Reprogramar ocurrencia (detalle)', N'Reprogramar ocurrencia (detalle)', 3, @RAIZ, 99, @LINK, 0, NULL,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PLANES MANTENIMIENTO'), 1
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = @LINK)

-- Reprogramar = accion de escritura: Token.Puede('CREAR EDITAR PLANES MANTENIMIENTO').
INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, N'Crear y editar', p.prm_id
FROM   [dbo].[Menus] m
JOIN   [dbo].[Permiso] p ON p.prm_codigo = N'CREAR EDITAR PLANES MANTENIMIENTO'
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = @LINK
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=N'Crear y editar')
GO

SELECT 'pantalla PlanOcurrenciaReprogramar' AS control, COUNT(*) AS valor, 1 AS esperado
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Planes/PlanOcurrenciaReprogramar.aspx'
GO

PRINT '203_SPRINT4_PLAN_OCURRENCIA_MENU aplicado.'
GO
