/* ============================================================================
   SIGMA — Bloque 434
   DATOS DE PRUEBA DE RECTIFICACIÓN DE BITÁCORA (HU-131, T-5316)
   ----------------------------------------------------------------------------

   Deja una entrada de bitácora con dos rectificaciones encadenadas, para poder
   ejercitar los criterios de la HU en la ficha del activo: el original tachado
   y, encima, la cadena de correcciones con su motivo (la última = vigente).

   Se escribe DIRECTO en la tabla —no por el SP— porque es un seed: el SP exige
   que el autor esté afiliado a la planta, que en el piloto no siempre se cumple;
   un seed no debe depender de eso. Elige una entrada que YA tenga activo y que
   no esté rectificada, así el dato aparece en una ficha y no pisa un caso real.

   Idempotente: las dos filas llevan uuid fijo y el índice único (UX_BRE_UUID)
   impide duplicarlas; re-aplicar no agrega nada.
   ============================================================================ */
DECLARE @BIT INT, @AUT INT

SELECT TOP 1 @BIT = b.bit_id, @AUT = b.bit_usuario_creacion
  FROM [dbo].[Bitacora] b
 WHERE b.bit_activo IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Rectificacion] r WHERE r.bre_bitacora = b.bit_id)
 ORDER BY b.bit_id DESC

IF @BIT IS NULL
BEGIN
    PRINT '--- Seed T-5316: no hay entrada con activo y sin rectificar; no se hizo nada.'
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Rectificacion] WHERE [bre_uuid] = 'A1111111-1111-1111-1111-111111111111')
        INSERT INTO [dbo].[Bitacora_Rectificacion]
            ([bre_bitacora], [bre_texto_rectificado], [bre_motivo], [bre_usuario_creacion], [bre_fecha_creacion], [bre_uuid])
        VALUES
            (@BIT, N'(Demo) Texto corregido: la bomba estaba en la línea 2, no en la 1.',
                   N'Corrijo un dato mal escrito en el apuro del turno.',
                   @AUT, DATEADD(MINUTE, 5, GETDATE()), 'A1111111-1111-1111-1111-111111111111')

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Rectificacion] WHERE [bre_uuid] = 'A2222222-2222-2222-2222-222222222222')
        INSERT INTO [dbo].[Bitacora_Rectificacion]
            ([bre_bitacora], [bre_texto_rectificado], [bre_motivo], [bre_usuario_creacion], [bre_fecha_creacion], [bre_uuid])
        VALUES
            (@BIT, N'(Demo) Texto corregido (vigente): la bomba de la línea 2 quedó operativa tras cambiar el sello.',
                   N'Se supo algo nuevo: el turno siguiente confirmó la reparación.',
                   @AUT, DATEADD(MINUTE, 10, GETDATE()), 'A2222222-2222-2222-2222-222222222222')

    PRINT '--- Seed T-5316: 2 rectificaciones de demo en bit_id ' + CAST(@BIT AS VARCHAR(10)) + ' (bloque 434).'
END
GO
