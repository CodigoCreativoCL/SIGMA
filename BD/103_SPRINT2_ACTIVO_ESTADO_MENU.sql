USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2155 REGISTRA LA PANTALLA ACTIVO_ESTADO EN MENUS, CON PERMISO.
-- =============================================
-- Va DESPUES de 102_SPRINT2_ACTIVO_ESTADO_DEMO.
--
-- Cambiar el estado de un activo es una ACCION, no un mantenedor: una sola
-- pantalla (sin ficha modal aparte) donde se elige el activo, el estado
-- nuevo y el motivo. Cuelga del nodo Activos. La seguridad la hace el
-- permiso CAMBIAR ESTADO ACTIVO y el filtro por cliente en el SP.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT, ambito INT)
INSERT INTO @P VALUES
    (N'CAMBIAR ESTADO ACTIVO', N'Cambiar el estado de un activo indicando el motivo', N'ACTIVOS', 3)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM   @P p
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

PRINT '--- Permiso CAMBIAR ESTADO ACTIVO registrado.'
GO


DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Activos' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Activos. Ejecute antes el bloque 76.', 16, 1)
    RETURN
END

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  N'Cambiar estado', N'Cambiar el estado de un activo con motivo', 3, @RAIZ, 6,
        N'~/View/Activos/Estado/ActivoEstado.aspx', 1, N'mdi mdi-sync',
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'CAMBIAR ESTADO ACTIVO'), 1
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                   WHERE x.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Estado/ActivoEstado.aspx')
GO


DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @PP VALUES
    (1, N'CAMBIAR ESTADO ACTIVO'),
    (10,N'CAMBIAR ESTADO ACTIVO'),
    (5, N'CAMBIAR ESTADO ACTIVO'),
    (11,N'CAMBIAR ESTADO ACTIVO'),
    (12,N'CAMBIAR ESTADO ACTIVO')   -- el supervisor tambien detiene un equipo

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.perfil, p.prm_id, 1, GETDATE()
FROM   @PP pp JOIN [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil=pp.perfil AND x.ppe_permiso=p.prm_id)
GO


SELECT 'permiso cambiar estado' AS control, COUNT(*) AS valor, 1 AS esperado
FROM   [dbo].[Permiso] WHERE prm_codigo = N'CAMBIAR ESTADO ACTIVO'
UNION ALL
SELECT 'pantalla cambiar estado', COUNT(*), 1
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Estado/ActivoEstado.aspx'
GO

PRINT '103_SPRINT2_ACTIVO_ESTADO_MENU aplicado.'
GO
