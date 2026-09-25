USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     EL PLAN DE MANTENIMIENTO COMO CENTRO DE OPERACIONES (HU-080/081/083).
-- =============================================
-- Hitos y equipos dejan de ser entradas de menu propias: viven como pestañas
-- dentro de la ficha del plan (PlanMantenimiento.aspx, en Default.master).
-- Un solo menu «Planes de mantenimiento»; desde el listado se ENTRA al plan.
--
--   1) Se quitan los menus de PlanHitos.aspx y PlanActivos.aspx (y sus
--      funciones). Los detalles PlanHito.aspx / PlanActivo.aspx se quedan
--      (orden 99, invisibles): siguen siendo paginas y necesitan su fila.
--   2) La ficha del plan pasa a tener funciones «Crear y editar» y
--      «Eliminar»: Token.PuedeFuncion mira la pagina ACTUAL, y ahora los
--      botones de las grillas de hitos y equipos estan en ella.
--   3) Se compacta el orden del menu padre.
--
-- Idempotente: se puede correr dos veces sin efecto.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @EDITAR INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PLANES MANTENIMIENTO')
DECLARE @FICHA  INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimiento.aspx')
DECLARE @PADRE  INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')

IF (@EDITAR IS NULL OR @FICHA IS NULL OR @PADRE IS NULL)
BEGIN
    RAISERROR('CORRA BD/212 ANTES QUE ESTE.', 16, 1)
    RETURN
END

BEGIN TRANSACTION

-- 1) Fuera los listados sueltos (sus funciones y perfiles primero, por las FK)
DECLARE @SUELTOS TABLE (mnu_id INT)
INSERT INTO @SUELTOS
SELECT mnu_id FROM [dbo].[Menus]
WHERE  mnu_link IN ('~/View/Mantenimiento/Planes/PlanHitos.aspx',
                    '~/View/Mantenimiento/Planes/PlanActivos.aspx')

DELETE mfp FROM [dbo].[Menu_Funcion_Perfil] mfp
JOIN   [dbo].[Menu_Funcion] mf ON mf.mfu_id = mfp.mfp_menu_funcion
WHERE  mf.mfu_menu IN (SELECT mnu_id FROM @SUELTOS)

DELETE FROM [dbo].[Menu_Funcion] WHERE mfu_menu IN (SELECT mnu_id FROM @SUELTOS)
DELETE FROM [dbo].[Menu_Perfil]  WHERE mpe_menu IN (SELECT mnu_id FROM @SUELTOS)
DELETE FROM [dbo].[Menus]        WHERE mnu_id   IN (SELECT mnu_id FROM @SUELTOS)

-- 2) Las funciones en la ficha, que es donde ahora estan los botones
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @FICHA AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @FICHA, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @FICHA AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Eliminar', @FICHA, @EDITAR)

-- La descripcion del menu dice lo que hay adentro
UPDATE [dbo].[Menus]
SET    mnu_descripcion = 'Planes de mantenimiento: ficha, hitos y equipos de cada plan'
WHERE  mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx'

-- 3) Orden compacto de los visibles del padre (los 99 no se tocan)
;WITH o AS (
    SELECT mnu_orden, ROW_NUMBER() OVER (ORDER BY mnu_orden, mnu_id) AS n
    FROM   [dbo].[Menus]
    WHERE  mnu_padre = @PADRE AND mnu_orden < 99
)
UPDATE o SET mnu_orden = n

COMMIT TRANSACTION
GO

SELECT 'Menus sueltos = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus]
        WHERE mnu_link IN ('~/View/Mantenimiento/Planes/PlanHitos.aspx','~/View/Mantenimiento/Planes/PlanActivos.aspx')) AS VARCHAR) + ' de 0' AS RESULTADO
UNION ALL
SELECT 'Funciones ficha = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
        WHERE m.mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimiento.aspx') AS VARCHAR) + ' de 2'
UNION ALL
SELECT 'Detalles = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus]
        WHERE mnu_link IN ('~/View/Mantenimiento/Planes/PlanHito.aspx','~/View/Mantenimiento/Planes/PlanActivo.aspx')) AS VARCHAR) + ' de 2'
GO
