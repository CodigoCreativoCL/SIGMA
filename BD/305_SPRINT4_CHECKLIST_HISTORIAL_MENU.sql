USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA CREACION:  29-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-097) T-4303 REGISTRA LA PANTALLA DE HISTORIAL DE
--                  EJECUCIONES DE CHECKLIST EN MENUS, CON SU PERMISO.
-- =============================================
-- Pantalla de SOLO LECTURA: no hay Menu_Funcion (no tiene botones de escritura).
-- Cuelga del mismo nodo que las demas pantallas de checklist (Centro de
-- Mantenimiento). Sin fila en Menus no se abre (Token.ExigirPagina niega por
-- omision). ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO


DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES
    (N'VER HISTORIAL CHECKLIST', N'Ver el historial de ejecuciones de las pautas de inspeccion', N'MANTENIMIENTO', 3)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)
GO


-- El nodo padre es el mismo de las otras pantallas de checklist. Se resuelve por
-- el padre de una pagina ya registrada, sin depender del nombre del nodo.
DECLARE @RAIZ INT
SELECT TOP 1 @RAIZ = mnu_padre FROM [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx'
IF @RAIZ IS NULL
    SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Centro de Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo padre de checklist.', 16, 1)
    RETURN
END

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT N'Historial de ejecuciones', N'Historial de ejecuciones de pautas', 3, @RAIZ, 8,
       N'~/View/Mantenimiento/Checklist/ChecklistHistorial.aspx', 1, N'mdi mdi-clipboard-text-clock-outline',
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER HISTORIAL CHECKLIST'), 1
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistHistorial.aspx')
GO


DECLARE @PP TABLE (perfil INT)
INSERT INTO @PP VALUES (1),(4),(5),(10),(11),(12),(13)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
FROM   @PP pp CROSS JOIN [dbo].[Permiso] p
WHERE  p.prm_codigo = N'VER HISTORIAL CHECKLIST'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil=pp.perfil AND x.ppe_permiso=p.prm_id)
GO


SELECT 'permiso historial'  AS control, COUNT(*) AS valor, 1 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo = N'VER HISTORIAL CHECKLIST'
UNION ALL
SELECT 'pantalla historial', COUNT(*), 1
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistHistorial.aspx'
GO

PRINT '305_SPRINT4_CHECKLIST_HISTORIAL_MENU aplicado.'
GO
