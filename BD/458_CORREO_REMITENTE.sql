/* ============================================================================
   SIGMA — Bloque 458
   REMITENTE DE LOS CORREOS, CONFIGURABLE SIN PUBLICAR
   ----------------------------------------------------------------------------
   SitioBase.Correo lee aquí el «de» de todos los correos del Centro Comercial
   (aviso de lead, credenciales, propuesta, contrato, reunión). Vacío = usa
   appSettings CorreoRemitente / CorreoRemitenteNombre del Web.config.

   PARA CAMBIARLO (por ejemplo a noreply@codigocreativo.tech):
     UPDATE Sys_Parametros SET par_valor = 'noreply@codigocreativo.tech' WHERE par_codigo = 'CORREO_REMITENTE'
   y que la cuenta SMTP del Web.config (system.net/mailSettings) pueda enviar
   como esa dirección: casi todos los servidores rechazan un «de» ajeno.
   ============================================================================ */
SET NOCOUNT ON
MERGE [dbo].[Sys_Parametros] AS D
USING (VALUES
  ('CORREO_REMITENTE',        'Correo remitente',            'Dirección que aparece como remitente en los correos de SIGMA. Vacío = la del Web.config.', ''),
  ('CORREO_REMITENTE_NOMBRE', 'Nombre del remitente',        'Nombre que acompaña al remitente. Vacío = el del Web.config.', 'SIGMA · Código Creativo')
) AS O (codigo, nombre, descripcion, valor)
   ON D.par_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (par_codigo, par_nombre, par_descripcion, par_valor) VALUES (O.codigo, O.nombre, O.descripcion, O.valor);
PRINT '458_CORREO_REMITENTE aplicado.'
GO
