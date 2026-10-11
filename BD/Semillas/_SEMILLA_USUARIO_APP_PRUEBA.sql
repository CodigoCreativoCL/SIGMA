/* ============================================================================
   Semilla · Usuario de prueba de la APP en Hamburgo · 11-10-2026 · Catalina Pescio
   Solo para la base de DESARROLLO (db71936). No va a producción.

   Para qué: probar con una sesión real los endpoints de la API que exigen cliente,
   como GET /api/archivo-vinculos (HU-142). Root no sirve: la API solo deja elegir
   los clientes a los que el usuario está asociado, y Root no tiene ninguno.

   Qué crea (con INS_CLIENTE_USUARIO, el mismo SP del alta en la web, que guarda la
   clave con hash y sal):
     · Login:  prueba.app@hamburgo.test   (dominio .test: no es un correo real)
     · Clave:  SigmaPrueba-HU142
     · RUT 11.111.111-1: INS_CLIENTE_USUARIO valida el identificador según el país
       del cliente (Chile), así que tiene que ser un RUT válido.
     · Cliente 1 (Hamburgo), perfil 25 «Técnico de Mantenimiento» (solo app, con
       VER ORDENES TRABAJO y VER ACTIVOS), igual que los técnicos reales.
   Idempotente: si el login ya existe, no hace nada.
   Para quitarlo: deshabilitarlo desde Cliente › Usuarios (nunca borrar).
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO
IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = 'prueba.app@hamburgo.test')
BEGIN
    PRINT 'El usuario de prueba de la app ya existe: no se hace nada.'
    RETURN
END

DECLARE @ID INT
EXEC [dbo].[INS_CLIENTE_USUARIO]
     @ID               = @ID OUTPUT,
     @IDENTIFICADOR    = '11.111.111-1',     -- RUT de prueba clásico (válido, no es de nadie)
     @CLIENTE          = 1,
     @LOGIN            = 'prueba.app@hamburgo.test',
     @PASSWORD         = 'SigmaPrueba-HU142',
     @NOMBRES          = 'Prueba',
     @APELLIDO_PATERNO = 'App',
     @APELLIDO_MATERNO = 'HU142',
     @FONO1            = '',
     @CORREO           = 'prueba.app@hamburgo.test',
     @PERFILES         = '25',
     @USUARIO          = 3
PRINT 'Usuario de prueba de la app creado: usu_id = ' + ISNULL(CAST(@ID AS VARCHAR(20)), 'NULL')
GO
