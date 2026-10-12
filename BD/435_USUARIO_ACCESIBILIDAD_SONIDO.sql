/* ============================================================================
   SIGMA — Bloque 435
   OPCIONES DE SONIDO EN ACCESIBILIDAD (HU-162, T-5326)
   ----------------------------------------------------------------------------

   `Usuario_Accesibilidad` ya guarda las preferencias de interfaz de la PERSONA
   (texto grande, alto contraste, iconos grandes, voz, idioma), una fila por
   usuario (índice único UX_UAC_USUARIO). Para el criterio CA-4 —«ajusto el
   volumen o silencio las alertas sonoras; la preferencia se conserva entre
   sesiones»— faltan dos columnas:

     · uac_volumen           DECIMAL(18,2)  volumen de las alertas, 0.00 a 1.00
                                            (0 = mudo); por defecto 1.00.
     · uac_silenciar_alertas BIT            silenciar TODAS las alertas sonoras;
                                            por defecto 0. El equivalente VISUAL
                                            de cada alerta se muestra siempre, lo
                                            garantiza la interfaz, no un dato.

   El «movimiento reducido» (CA-3) no es una columna: lo pide el SISTEMA
   OPERATIVO (prefers-reduced-motion) y lo respeta el CSS; no se guarda.

   Nota: esta tabla es una fila POR USUARIO (UX_UAC_USUARIO). No tiene «código»
   ni unicidad por cliente: el punto de «código único por cliente» de la
   plantilla de tareas no aplica.

   Idempotente (sólo agrega las columnas si faltan).
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Accesibilidad]') AND name = N'uac_volumen')
BEGIN
    ALTER TABLE [dbo].[Usuario_Accesibilidad]
        ADD [uac_volumen] DECIMAL(18,2) NOT NULL CONSTRAINT DF_UAC_VOLUMEN DEFAULT 1.00
    PRINT '--- Usuario_Accesibilidad.uac_volumen agregada.'
END
ELSE PRINT '--- Usuario_Accesibilidad.uac_volumen ya existía.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Accesibilidad]') AND name = N'uac_silenciar_alertas')
BEGIN
    ALTER TABLE [dbo].[Usuario_Accesibilidad]
        ADD [uac_silenciar_alertas] BIT NOT NULL CONSTRAINT DF_UAC_SILENCIAR_ALERTAS DEFAULT 0
    PRINT '--- Usuario_Accesibilidad.uac_silenciar_alertas agregada.'
END
ELSE PRINT '--- Usuario_Accesibilidad.uac_silenciar_alertas ya existía.'
GO

PRINT '--- Modelo Usuario_Accesibilidad listo para las opciones de sonido (bloque 435).'
GO
