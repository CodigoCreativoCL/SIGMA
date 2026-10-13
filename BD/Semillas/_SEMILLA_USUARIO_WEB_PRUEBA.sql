/* ============================================================================
   Semilla · Usuario de prueba WEB en Hamburgo · 12-10-2026 · Catalina Pescio
   Solo para la base de DESARROLLO (db71936). No va a producción.

   Para qué: probar en el navegador lo que exige facultades de planificación y de
   pautas (HU-143: imágenes de referencia en la actividad del plan, en el ítem de la
   pauta y al ejecutar la inspección), sin usar la cuenta de una persona real.

   Qué crea (con INS_CLIENTE_USUARIO, el mismo SP del alta en la web, que guarda la
   clave con hash y sal):
     · Login:  prueba.web@hamburgo.test   (dominio .test: no es un correo real)
     · Clave: NO va en el repo. Se pasa al aplicar, como variable de sqlcmd:
         python -I Dev/sql_aplicar.py BD/Semillas/_SEMILLA_USUARIO_WEB_PRUEBA.sql -v CLAVE_PRUEBA_WEB="<clave>"
       Pídela a Catalina o cámbiala con UPD_USUARIO_PASSWORD (@EXIGE_ACTUAL = 0).
     · RUT 22.222.222-2 (válido, de prueba).
     · Cliente 1 (Hamburgo), perfil 19 «Jefe de Mantenimiento» (planes, pautas y
       ejecución de inspecciones).
   Idempotente: si el login ya existe, no hace nada.
   Para quitarlo: deshabilitarlo desde Cliente › Usuarios (nunca borrar).
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO
IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = 'prueba.web@hamburgo.test')
BEGIN
    PRINT 'El usuario de prueba web ya existe: no se hace nada.'
    RETURN
END

DECLARE @ID INT
EXEC [dbo].[INS_CLIENTE_USUARIO]
     @ID               = @ID OUTPUT,
     @IDENTIFICADOR    = '22.222.222-2',
     @CLIENTE          = 1,
     @LOGIN            = 'prueba.web@hamburgo.test',
     @PASSWORD         = '$(CLAVE_PRUEBA_WEB)',
     @NOMBRES          = 'Prueba',
     @APELLIDO_PATERNO = 'Web',
     @APELLIDO_MATERNO = 'HU143',
     @FONO1            = '',
     @CORREO           = 'prueba.web@hamburgo.test',
     @PERFILES         = '19',
     @USUARIO          = 3
PRINT 'Usuario de prueba web creado: usu_id = ' + ISNULL(CAST(@ID AS VARCHAR(20)), 'NULL')
GO
