/* ============================================================================
   SIGMA - Bloque 356
   «CON OBSERVACION»: CUAL ES LA OBSERVACION
   ----------------------------------------------------------------------------
   El motivo de cada cambio de estado de un componente se guarda en
   Activo_Componente_Estado_Historial.ceh_motivo (bloque 253). Ninguna
   lectura lo traia: la planta mostraba la descripcion y el centro un campo
   vacio. Ahora:
     - SEL_COMPONENTE_ULTIMO_MOTIVO: el motivo del ultimo cambio de estado de
       cada componente del cliente (pestaña Componentes y estructura del centro);
     - SEL_ACTIVO_PLANTA devuelve ese motivo como MOTIVO (explorador y lista).
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COMPONENTE_ULTIMO_MOTIVO]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON;
    /* El motivo del ultimo cambio de estado; si nunca se registro uno (datos
       cargados antes del bloque 253), la descripcion del componente. */
    SELECT k.aco_id AS COMPONENTE,
           COALESCE(NULLIF(LTRIM(RTRIM((SELECT TOP 1 h.ceh_motivo FROM [dbo].[Activo_Componente_Estado_Historial] h
                                        WHERE h.ceh_activo_componente = k.aco_id ORDER BY h.ceh_id DESC))), N''),
                    NULLIF(LTRIM(RTRIM(k.aco_descripcion)), N'')) AS MOTIVO
    FROM   [dbo].[Activo_Componente] k
    WHERE  k.aco_cliente = @CLIENTE AND k.aco_habilitado = 1
      AND  COALESCE(NULLIF(LTRIM(RTRIM((SELECT TOP 1 h.ceh_motivo FROM [dbo].[Activo_Componente_Estado_Historial] h
                                        WHERE h.ceh_activo_componente = k.aco_id ORDER BY h.ceh_id DESC))), N''),
                    NULLIF(LTRIM(RTRIM(k.aco_descripcion)), N'')) IS NOT NULL;
END
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA'))
IF @sql LIKE N'%k.aco_descripcion AS MOTIVO%' OR @sql LIKE N'%ORDER BY h.ceh_id DESC), N'''') AS MOTIVO%'
BEGIN
    SET @sql = REPLACE(@sql, N'ORDER BY h.ceh_id DESC), N'''') AS MOTIVO', N'ORDER BY h.ceh_id DESC), N''''), k.aco_descripcion) AS MOTIVO')
    SET @sql = REPLACE(@sql, N'ISNULL((SELECT TOP 1 h.ceh_motivo', N'COALESCE(NULLIF((SELECT TOP 1 h.ceh_motivo')
    SET @sql = REPLACE(@sql, N'k.aco_descripcion AS MOTIVO',
        N'COALESCE(NULLIF((SELECT TOP 1 h.ceh_motivo FROM [dbo].[Activo_Componente_Estado_Historial] h
                    WHERE h.ceh_activo_componente = k.aco_id ORDER BY h.ceh_id DESC), N''''), k.aco_descripcion) AS MOTIVO')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA')) LIKE N'%h.ceh_motivo%' THEN 'OK' ELSE 'FALTA' END AS PLANTA
GO
