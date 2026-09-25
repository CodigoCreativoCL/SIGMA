USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LA ALERTA DE TRABAJO COMPARTIDO TIENE QUE ABRIR LA OT.
-- =============================================
-- Compartir un trabajo ya funcionaba y dejaba el aviso dentro de la app, pero
-- el aviso no llevaba a ninguna parte: el tipo COMPARTIDO tiene
-- `alt_ficha_id_columna` en NULL, asi que `FICHA_ID` salia nulo y la tarjeta de
-- la alerta se dibujaba SIN BOTON. El companero recibia «Rodrigo te compartio
-- OT-1176» y no tenia desde donde abrirla ni sumarse — que es justo lo que
-- POST /compartir/unirme existe para hacer.
--
-- Es un arreglo de DATOS, no de codigo: el vinculo entre un tipo de alerta y la
-- ficha que abre vive en Alerta_Tipo, igual que el de STOCK MINIMO apunta a
-- `ale_repuesto`. Es la misma idea de que la seguridad y la navegacion de SIGMA
-- son por datos.
--
-- POR QUE alt_ficha_link SE QUEDA EN NULL
--   Esa columna es la ruta de la INTRANET, y la pagina web de la orden de
--   trabajo no existe todavia (View/Mantenimiento solo tiene Procedimientos y
--   Programaciones). Ponerle una ruta inventada le daria a la web un enlace
--   roto para arreglarle la navegacion a la app. La app no la necesita:
--   distingue por `alt_codigo`, que el SEL ya devuelve.
-- =============================================
SET NOCOUNT ON
GO

IF EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo]
            WHERE [alt_codigo] = 'COMPARTIDO'
              AND ISNULL([alt_ficha_id_columna], '') <> 'ale_orden_trabajo')
BEGIN
    UPDATE [dbo].[Alerta_Tipo]
       SET [alt_ficha_id_columna] = 'ale_orden_trabajo'
     WHERE [alt_codigo] = 'COMPARTIDO'

    PRINT 'Alerta_Tipo COMPARTIDO: alt_ficha_id_columna = ale_orden_trabajo'
END
ELSE
    PRINT 'Alerta_Tipo COMPARTIDO: ya estaba, no se toca'
GO

/* Comprobacion: la alerta de trabajo compartido tiene que traer FICHA_ID. */
SELECT [alt_id], [alt_codigo], [alt_ficha_id_columna], [alt_ficha_link]
  FROM [dbo].[Alerta_Tipo]
 WHERE [alt_codigo] = 'COMPARTIDO'
GO
