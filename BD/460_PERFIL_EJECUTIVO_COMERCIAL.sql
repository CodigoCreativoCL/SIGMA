/* ============================================================================
   SIGMA — Bloque 460
   PERFIL «EJECUTIVO COMERCIAL» Y QUIÉN ES EJECUTIVO EN EL CENTRO COMERCIAL
   ----------------------------------------------------------------------------
   Los ejecutivos que se asignan a un lead son las personas con perfil
   «Gerente Comercial» o «Ejecutivo Comercial» (pedido de Bryan, 16-10-2026).
   Antes era cualquiera con la facultad GESTIONAR LEADS, y por eso aparecía
   Root en la lista.

   El perfil nuevo es de plataforma (per_tipo 1, sin cliente), como el de
   Gerente Comercial. Vende: ve el Centro, gestiona leads, demos, propuestas y
   contratos, y consulta suscripciones, planes y pagos. No edita planes ni
   verifica pagos: eso queda en Gerente Comercial.

   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()
IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_nombre = 'Ejecutivo Comercial' AND per_cliente IS NULL)
BEGIN
    INSERT [dbo].[Perfiles] (per_nombre, per_descripcion, per_tipo, per_habilitado, per_usuario_creacion, per_fecha_creacion,
                             per_usuario_act, per_fecha_act, per_cliente, per_solo_ejecucion, per_ambito)
    VALUES ('Ejecutivo Comercial', 'Vende SIGMA desde el Centro Comercial: leads, demos, propuestas y contratos.', 1, 1,
            @ROOT, @AHORA, @ROOT, @AHORA, NULL, 0, 1)
    PRINT 'Perfil Ejecutivo Comercial creado.'
END

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PER.per_nombre = 'Ejecutivo Comercial' AND PER.per_cliente IS NULL
  AND   PRM.prm_codigo IN ('VER CENTRO COMERCIAL', 'GESTIONAR LEADS', 'GESTIONAR DEMOS', 'GESTIONAR PROPUESTAS',
                           'VER CLIENTES', 'VER SUSCRIPCIONES', 'VER PLANES COMERCIALES', 'VER PAGOS SUSCRIPCION',
                           'AYUDA VER', 'SOPORTE REPORTAR', 'CONFIGURAR ACCESIBILIDAD')
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)
PRINT 'Permisos del Ejecutivo Comercial asignados.'
GO

/* Ejecutivos = perfiles comerciales, no «cualquiera que pueda gestionar leads». */
CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_EJECUTIVOS]
AS
SET NOCOUNT ON
SELECT DISTINCT U.usu_id AS ID,
       LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS NOMBRE,
       U.usu_correo AS CORREO
  FROM [dbo].[Usuario] U
  JOIN [dbo].[Usuario_Perfil] UP ON UP.upe_usuario = U.usu_id
  JOIN [dbo].[Perfiles] P ON P.per_id = UP.upe_perfil
 WHERE U.usu_habilitado = 1
   AND P.per_cliente IS NULL AND P.per_habilitado = 1
   AND P.per_nombre IN ('Gerente Comercial', 'Ejecutivo Comercial')
 ORDER BY NOMBRE
GO

PRINT '460_PERFIL_EJECUTIVO_COMERCIAL aplicado.'
GO
