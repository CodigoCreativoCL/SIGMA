/* ============================================================================
   SIGMA — Bloque 432
   DETALLE DE UNA RECTIFICACIÓN DE BITÁCORA (HU-131, T-5318)
   ----------------------------------------------------------------------------

   El listado de las rectificaciones de una entrada ya lo da API_SEL_BITACORA
   con @TIPO = 4. Falta leer UNA sola por su id, para GET
   /bitacora/rectificaciones/{bre}. Se hace con un SP chico dedicado en vez de
   sumar otro modo al SEL grande: es una consulta de una fila, autocontenida, y
   mantenerla aparte deja el SEL de la sábana sin tocar.

   EL CLIENTE NO ES OPCIONAL
     Se filtra por @CLIENTE uniendo a Bitacora: un bre_id escrito a mano en la
     URL no alcanza para leer la rectificación de otra empresa. Mismas columnas
     que el modo 4, para que el DTO sea el mismo (BitacoraRectificacionDto).

   Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_BITACORA_RECTIFICACION]
     @BRE      INT
    ,@USUARIO  INT
    ,@CLIENTE  INT
AS
SET NOCOUNT ON

BEGIN
    SELECT
         bre.[bre_id]
        ,bre.[bre_texto_rectificado]
        ,bre.[bre_motivo]
        ,bre.[bre_usuario_creacion]        AS [USUARIO_ID]
        ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                           AS [USUARIO_NOMBRE]
        ,bre.[bre_fecha_creacion]

      FROM [dbo].[Bitacora_Rectificacion] bre
      JOIN [dbo].[Bitacora]              bit ON bit.[bit_id] = bre.[bre_bitacora]
 LEFT JOIN [dbo].[Usuario]               usr ON usr.[usu_id] = bre.[bre_usuario_creacion]

     WHERE bre.[bre_id]      = @BRE
       AND bit.[bit_cliente] = @CLIENTE
END
GO

PRINT '--- API_SEL_BITACORA_RECTIFICACION (detalle) creado (bloque 432).'
GO
