/* ============================================================================
   SIGMA — Bloque 255
   EL ADMINISTRADOR DEL CLIENTE CREA Y EDITA REPUESTOS                HU-068 #1
   ----------------------------------------------------------------------------

   HU-068 la pide "como administrador de cliente": dar de alta muchos
   repuestos desde una planilla para poner en marcha el inventario. El perfil
   Administrador del Cliente solo tenía «Ver el maestro de repuestos», así
   que la carga masiva (registrada en Menus con el permiso 67) lo mandaba a
   la portada. Se le concede «Crear y editar repuestos». Es un INSERT en
   Perfil_Permiso, no código. IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pf.per_id, p.prm_id, 1, [dbo].[FNC_AHORA]()
FROM   [dbo].[Perfiles] pf
CROSS JOIN [dbo].[Permiso] p
WHERE  pf.per_nombre = 'Administrador del Cliente'
  AND  p.prm_nombre  = 'Crear y editar repuestos'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pf.per_id AND x.ppe_permiso = p.prm_id)
GO

PRINT '--- Administrador del Cliente: Crear y editar repuestos (bloque 255).'
GO
