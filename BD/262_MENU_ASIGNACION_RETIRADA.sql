USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     SE RETIRA LA VENTANA DE ASIGNACION DE ORDEN (HU-112).
-- =============================================
-- Asignar dejo de ser una ventana aparte: el equipo de trabajo se arma en la
-- pestaña Asignacion de la propia orden, al lado del responsable actual, que
-- es lo que hay que mirar para decidir. OrdenTrabajoAsignacion.aspx salio del
-- repositorio y su fila de Menus se va con ella: una fila que apunta a una
-- pagina inexistente es un acceso roto para quien tenga el enlace guardado.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DELETE FROM [dbo].[Menu_Funcion] WHERE mfu_menu = 2198
DELETE FROM [dbo].[Menu_Perfil]  WHERE mpe_menu = 2198
DELETE FROM [dbo].[Menus]        WHERE mnu_id   = 2198

IF EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link LIKE '%OrdenTrabajoAsignacion%')
    PRINT '*** ATENCION: quedan filas de Menus apuntando a OrdenTrabajoAsignacion.aspx'
ELSE
    PRINT '--- Sin accesos rotos: la ventana de asignacion quedo retirada.'
GO

PRINT '262_MENU_ASIGNACION_RETIRADA aplicado.'
GO
