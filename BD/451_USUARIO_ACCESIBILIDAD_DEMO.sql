/* ============================================================================
   SIGMA — Bloque 451
   DATOS DE PRUEBA DE ACCESIBILIDAD (HU-162, T-5331)
   ----------------------------------------------------------------------------

   Deja una fila de preferencias para un usuario afiliado, con texto grande y
   alto contraste activos y el volumen a la mitad, para ejercitar los criterios
   (la interfaz debe respetar texto grande, alto contraste y la preferencia de
   sonido). Elige un usuario afiliado a un cliente que todavía no tenga fila, así
   el índice único UX_UAC_USUARIO no choca y no se pisan preferencias reales.

   Idempotente: sólo inserta si ese usuario aún no tiene fila.
   ============================================================================ */
DECLARE @U INT, @CRE INT

SELECT TOP 1 @U = cu.[ucl_id_usuario]
  FROM [dbo].[Cliente_Usuario] cu
 WHERE ISNULL(cu.[ucl_habilitado], 0) = 1
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Accesibilidad] uac WHERE uac.[uac_usuario] = cu.[ucl_id_usuario])
 ORDER BY cu.[ucl_id_usuario]

IF @U IS NULL
BEGIN
    PRINT '--- Seed T-5331: todos los usuarios afiliados ya tienen fila; no se hizo nada.'
END
ELSE
BEGIN
    SET @CRE = @U
    INSERT INTO [dbo].[Usuario_Accesibilidad]
        ([uac_usuario], [uac_entrada_voz], [uac_lectura_voz], [uac_confirmacion_hablada]
        ,[uac_velocidad_voz], [uac_texto_grande], [uac_alto_contraste], [uac_iconos_grandes]
        ,[uac_idioma], [uac_volumen], [uac_silenciar_alertas]
        ,[uac_usuario_creacion], [uac_fecha_creacion], [uac_habilitado])
    VALUES
        (@U, 0, 0, 0, 1.00, 1, 1, 1, NULL, 0.50, 0, @CRE, GETDATE(), 1)

    PRINT '--- Seed T-5331: preferencias de demo para el usuario ' + CAST(@U AS VARCHAR(10)) + ' (texto grande, alto contraste, volumen 0.50; bloque 451).'
END
GO
