/* ============================================================================
   SIGMA - Bloque 349
   LA FOTO DE CADA ACTIVO Y CADA COMPONENTE, DE UNA VEZ
   ----------------------------------------------------------------------------
   La pestaña Componentes del modulo muestra la portada del activo en cada
   grupo y la foto de cada componente. Pedirlas de a una (SEL_ACTIVO_IMAGEN /
   SEL_ACTIVO_COMPONENTE_IMAGEN) es una consulta por fila; este SP las trae
   todas en una: la misma regla de esos dos SP (referencia habilitada, del
   cliente), una por activo o componente.
     TIPO = 'A' activo, 'C' componente.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_IMAGENES_LISTA]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH r AS (
        SELECT CASE WHEN v.avi_activo IS NOT NULL THEN 'A' ELSE 'C' END AS TIPO,
               ISNULL(v.avi_activo, v.avi_activo_componente) AS ID,
               a.arc_id AS ARC_ID,
               ROW_NUMBER() OVER (PARTITION BY v.avi_activo, v.avi_activo_componente
                                  ORDER BY ISNULL(v.avi_orden, 0), v.avi_id DESC) AS n
        FROM   [dbo].[Archivo_Vinculo] v
        JOIN   [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
        WHERE  (v.avi_activo IS NOT NULL OR v.avi_activo_componente IS NOT NULL)
          AND  v.avi_es_referencia = 1
          AND  ISNULL(v.avi_habilitado, 1) = 1
          AND  ISNULL(a.arc_habilitado, 1) = 1
          AND  a.arc_cliente = @CLIENTE)
    SELECT TIPO, ID, ARC_ID FROM r WHERE n = 1;
END
GO
