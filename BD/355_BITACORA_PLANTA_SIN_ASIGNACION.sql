/* ============================================================================
   SIGMA - Bloque 355
   ESCRIBIR EN LA BITACORA: LA MISMA REGLA DE PLANTAS QUE EL MODULO
   ----------------------------------------------------------------------------
   API_INS_BITACORA rechazaba («No estas afiliado a esa planta») a toda
   persona sin fila en Cliente_Instalacion_Usuario para esa planta, incluido
   quien no tiene NINGUNA planta asignada (el administrador), que en el
   modulo de activos ve todas.
   La regla queda igual que en WsActivos (PlantasPermitidas):
     - con plantas asignadas en este cliente: solo en las suyas (un bodeguero
       de Renca no escribe en otra planta);
     - sin ninguna asignada en el cliente: en cualquiera de sus plantas.
   La app movil no cambia: sus usuarios siempre tienen planta asignada.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.API_INS_BITACORA'))
IF @sql NOT LIKE N'%sin ninguna planta asignada en el cliente%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]',
        N'/* sin ninguna planta asignada en el cliente: puede escribir en cualquiera (bloque 355) */
        IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] xu
                    JOIN [dbo].[Cliente_Instalacion] xi ON xi.cin_id = xu.ciu_id_instalacion
                    WHERE xu.ciu_id_usuario = @USUARIO AND xi.cin_cliente = @CLIENTE AND ISNULL(xu.ciu_habilitado, 0) = 1)
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.API_INS_BITACORA')) LIKE N'%sin ninguna planta asignada en el cliente%' THEN 'OK' ELSE 'FALTA' END AS REGLA
GO
