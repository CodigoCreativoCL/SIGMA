USE [db_acd593_sigma]
GO
/* 383 — Abrir de nuevo la campana desde su aviso del panel de alertas (como modal).
   Devuelve la campana de una alerta dirigida a la persona, sin mirar la frecuencia. IDEMPOTENTE. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_DE_ALERTA]
    @ALERTA  INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    SELECT  k.cam_id, k.cam_tipo, k.cam_titulo, k.cam_descripcion, k.cam_medio, k.cam_tema, k.cam_archivo, k.cam_formatos, k.cam_presentacion,
            k.cam_cerrable, k.cam_confirmar, k.cam_cta_accion, k.cam_cta_texto, k.cam_cta_destino,
            k.cam_contenido, a.ayc_titulo AS CONTENIDO_TITULO, a.ayc_tipo AS CONTENIDO_TIPO, k.cam_frecuencia
    FROM    [dbo].[Alerta] al
    JOIN    [dbo].[Campana] k ON k.cam_id = al.ale_campana
    LEFT JOIN [dbo].[Ayuda_Contenido] a ON a.ayc_id = k.cam_contenido AND a.ayc_estado = 'Publicado'
    WHERE   al.ale_id = @ALERTA AND al.ale_usuario_destinatario = @USUARIO AND al.ale_habilitado = 1
GO
