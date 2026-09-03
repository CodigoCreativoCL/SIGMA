/* ============================================================================
   SIGMA — Bloque 128
   LAS ALERTAS DE ACTIVOS ABREN SU FICHA
   ----------------------------------------------------------------------------

   La campana ya abre la ficha declarada por Alerta_Tipo. Sin embargo, los
   avisos de activos —incluida PREDICCION RIESGO— no tenían destino ni columna
   de ID. El postback marcaba la alerta como leída y después no tenía nada que
   mostrar: para la persona parecía que el clic no funcionaba.

   El destino sigue viviendo en el catálogo. Default.master, la bandeja y la
   app consumen la misma regla y no necesitan reconocer tipos por nombre.
   ============================================================================ */

SET NOCOUNT ON
GO

UPDATE t
SET    t.alt_ficha_link       = '~/View/Activos/Activos/Activo.aspx',
       t.alt_ficha_id_columna = 'ale_activo',
       t.alt_menu_link        = '~/View/Activos/Activos/Activos.aspx'
FROM   dbo.Alerta_Tipo t
WHERE  t.alt_codigo IN (
           'MEDICION FUERA RANGO',
           'HALLAZGO CRITICO',
           'PREDICCION RIESGO',
           'MEDIDOR SIN LECTURA',
           'DESCUBRIMIENTO TERRENO',
           'MEDIDOR PROXIMO MANTENIMIENTO'
       )

PRINT '--- Destino de ficha configurado para alertas de activos: ' +
      LTRIM(STR(@@ROWCOUNT))
GO

PRINT '128_ALERTA_DESTINO_ACTIVO aplicado.'
GO
