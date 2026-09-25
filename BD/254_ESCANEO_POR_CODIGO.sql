/* ============================================================================
   SIGMA — Bloque 254
   EL CÓDIGO IMPRESO TAMBIÉN SE PUEDE TECLEAR                          HU-067 #2
   ----------------------------------------------------------------------------

   El QR de la etiqueta lleva el TOKEN (BOD-<id>, UBI-<id>, REP-<id>, ACT-<id>,
   POS-<id>) y eso siempre resuelve. Pero la etiqueta imprime en grande el
   CÓDIGO del registro, que es lo que una persona teclea cuando el QR está
   rayado; y ese código no siempre es el token: hay bodegas «BOD-1» con id 12
   y repuestos «REP-6205» anteriores a los códigos automáticos. Tecleados,
   respondían «no corresponde a ninguna bodega de su empresa».

   SEL_ETIQUETA_RESOLVER hace las dos cosas dentro del cliente:
     · con @TIPO y @ID (lo que salió del token) confirma que ese registro es
       del cliente y devuelve su código;
     · con @CODIGO busca el código impreso en bodegas, ubicaciones,
       repuestos, activos y posiciones del cliente, en ese orden.
   Devuelve TIPO, ID, CODIGO; ninguna fila si no hay nada. IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ETIQUETA_RESOLVER]
     @CLIENTE INT
    ,@CODIGO  NVARCHAR(100) = NULL
    ,@TIPO    NVARCHAR(3)   = NULL
    ,@ID      INT           = NULL
AS
SET NOCOUNT ON
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
    SET @TIPO   = UPPER(LTRIM(RTRIM(@TIPO)))

    ;WITH T AS (
        SELECT 1 AS ORDEN, 'BOD' AS TIPO, b.bod_id AS ID, b.bod_codigo AS CODIGO
          FROM [dbo].[Bodega] b WHERE b.bod_cliente = @CLIENTE
        UNION ALL
        SELECT 2, 'UBI', u.bub_id, u.bub_codigo
          FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
         WHERE b.bod_cliente = @CLIENTE
        UNION ALL
        SELECT 3, 'REP', r.rep_id, r.rep_codigo
          FROM [dbo].[Repuesto] r WHERE r.rep_cliente = @CLIENTE
        UNION ALL
        SELECT 4, 'ACT', a.act_id, a.act_codigo
          FROM [dbo].[Activo] a WHERE a.act_cliente = @CLIENTE
        UNION ALL
        SELECT 5, 'POS', p.apo_id, p.apo_codigo
          FROM [dbo].[Activo_Posicion] p WHERE p.apo_cliente = @CLIENTE
    )
    SELECT TOP 1 TIPO, ID, CODIGO
      FROM T
     WHERE (@TIPO IS NOT NULL AND @ID IS NOT NULL AND TIPO = @TIPO AND ID = @ID)
        OR (@TIPO IS NULL AND @CODIGO IS NOT NULL AND UPPER(CODIGO) = @CODIGO)
     ORDER BY ORDEN
GO

PRINT '--- SEL_ETIQUETA_RESOLVER creado (bloque 254).'
GO
