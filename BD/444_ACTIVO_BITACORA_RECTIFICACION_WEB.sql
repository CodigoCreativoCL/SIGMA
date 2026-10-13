/* ============================================================================
   SIGMA — Bloque 444
   RECTIFICACIONES DE LA BITÁCORA PARA LA FICHA DEL ACTIVO (HU-131, T-5321)
   ----------------------------------------------------------------------------

   La ficha del activo muestra su bitácora (SEL_ACTIVO_BITACORA). Para cumplir
   el criterio «la interfaz muestra el texto original tachado con la
   rectificación junto a él», necesita además las rectificaciones de esas
   entradas, en una sola consulta por activo (no una por nota).

   Trae TODAS las rectificaciones de las entradas del activo, de la más vieja a
   la más nueva dentro de cada entrada, con quién y cuándo. La ficha las agrupa
   por `bre_bitacora` y pinta, bajo cada entrada rectificada, el original
   tachado y encima la última versión con su motivo.

   EL CLIENTE NO ES OPCIONAL: se une a Bitacora y se filtra por @CLIENTE, igual
   que SEL_ACTIVO_BITACORA. Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_BITACORA_RECTIFICACION]
    @CLIENTE  INT,
    @ACTIVO   INT
AS
SET NOCOUNT ON

    SELECT  bre.[bre_bitacora]                 AS BITACORA,
            bre.[bre_id]                       AS BRE_ID,
            ISNULL(bre.[bre_texto_rectificado], '') AS TEXTO,
            ISNULL(bre.[bre_motivo], '')       AS MOTIVO,
            ISNULL(usr.[usu_nombre] + ' ' + ISNULL(usr.[usu_apellido_paterno], ''), '') AS USUARIO_NOMBRE,
            bre.[bre_fecha_creacion]           AS FECHA

    FROM    [dbo].[Bitacora_Rectificacion] bre
    JOIN    [dbo].[Bitacora]               bit ON bit.[bit_id] = bre.[bre_bitacora]
    LEFT JOIN [dbo].[Usuario]              usr ON usr.[usu_id] = bre.[bre_usuario_creacion]

    WHERE   bit.[bit_cliente] = @CLIENTE
      AND   bit.[bit_activo]  = @ACTIVO

    ORDER BY bre.[bre_bitacora], bre.[bre_id]
GO

PRINT '--- SEL_ACTIVO_BITACORA_RECTIFICACION creado (bloque 444).'
GO
