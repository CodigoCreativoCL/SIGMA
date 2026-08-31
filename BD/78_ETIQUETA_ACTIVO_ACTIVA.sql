/* ============================================================================
   SIGMA — Bloque 78
   SE ENCIENDE LA ETIQUETA DE ACTIVO
   ----------------------------------------------------------------------------

   POR QUE ESTABA APAGADA

     Cuando se creo el catalogo de origenes imprimibles, la tabla Activo tenia
     datos pero no habia modulo: ni listado, ni ficha, ni menu. Una etiqueta
     que se escanea y no lleva a ninguna parte es peor que no tenerla, porque
     se pega en una maquina y ahi se queda. Se dejo registrada con el motivo
     escrito, para que se viera que el sistema la contemplaba.

   POR QUE SE ENCIENDE AHORA

     El modulo de activos existe: View/Activos/Activos/Activo.aspx abre la
     ficha con la misma convencion que el resto del sitio. El escaneo de una
     etiqueta ACT-<id> ya tiene donde aterrizar, asi que la etiqueta cumple su
     promesa.

   ES UN UPDATE DE UNA FILA

     Que era exactamente el punto de haber dejado el catalogo en una tabla en
     vez de en una lista dentro de una pantalla.
   ============================================================================ */

SET NOCOUNT ON
GO

UPDATE [dbo].[Etiqueta_Origen]
SET    eto_habilitado  = 1,
       eto_motivo_baja = NULL,
       eto_descripcion = 'Una por equipo, para pegar en la máquina. Al escanearla se abre su ficha.'
WHERE  eto_codigo = 'ACTIVO'

PRINT '--- Etiqueta de activo habilitada: ' + LTRIM(STR(@@ROWCOUNT)) + ' fila(s)'
GO

SELECT  eto_codigo, eto_nombre, eto_habilitado,
        ISNULL(eto_motivo_baja, '') AS MOTIVO
FROM    [dbo].[Etiqueta_Origen]
ORDER BY eto_orden
GO
