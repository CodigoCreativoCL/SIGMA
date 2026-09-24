USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     QUE SE DIAGNOSTICO Y QUE SE HIZO, POR FALLA DEL ACTIVO.
-- =============================================
-- POR QUE
--   La lista de fallas del centro mostraba titulo, sintoma y estado. Le
--   faltaban las dos columnas que contestan la pregunta de fondo: que se
--   concluyo y que se hizo al respecto. Existen -Falla_Diagnostico y
--   Falla_Accion- y se leian de a una por falla con SEL_FALLA_DIAGNOSTICO,
--   que es una consulta por fila.
--
--   Se devuelve el DEFINITIVO cuando existe, y el ultimo cuando no: una
--   falla en diagnostico tiene hipotesis, y decir la ultima es mas honesto
--   que dejar la celda vacia como si nadie la hubiera mirado.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_FALLA_CIERRE]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

    SELECT  f.fal_id                                  AS FALLA_ID,

            ISNULL(dia.fdi_descripcion, '')           AS DIAGNOSTICO,
            ISNULL(dia.fdi_es_definitivo, 0)          AS DIAGNOSTICO_DEFINITIVO,
            ISNULL(dia.MODO, '')                      AS MODO,
            ISNULL(dia.CAUSA, '')                     AS CAUSA,

            ISNULL(acc.fac_descripcion, '')           AS ACCION,
            ISNULL(acc.fac_es_definitiva, 0)          AS ACCION_DEFINITIVA,
            acc.fac_orden_trabajo                     AS ACCION_ORDEN

    FROM    [dbo].[Falla] f

            /* El definitivo manda; si no hay, el ultimo que alguien escribio.
               Una falla en diagnostico tiene hipotesis, y decir la ultima es
               mas honesto que dejar la celda vacia. */
            OUTER APPLY (
                SELECT  TOP 1 d.fdi_descripcion, d.fdi_es_definitivo,
                        ISNULL(fmo.fmo_nombre, '') AS MODO,
                        ISNULL(fca.fca_nombre, '') AS CAUSA
                  FROM  [dbo].[Falla_Diagnostico] d
                        LEFT JOIN [dbo].[Falla_Modo] fmo  ON fmo.fmo_id = d.fdi_falla_modo
                        LEFT JOIN [dbo].[Falla_Causa] fca ON fca.fca_id = d.fdi_falla_causa
                 WHERE  d.fdi_falla = f.fal_id
                   AND  ISNULL(d.fdi_habilitado, 1) = 1
                 ORDER  BY ISNULL(d.fdi_es_definitivo, 0) DESC,
                           d.fdi_fecha_diagnostico_utc DESC, d.fdi_id DESC
            ) dia

            OUTER APPLY (
                SELECT  TOP 1 x.fac_descripcion, x.fac_es_definitiva, x.fac_orden_trabajo
                  FROM  [dbo].[Falla_Accion] x
                 WHERE  x.fac_falla = f.fal_id
                   AND  ISNULL(x.fac_habilitado, 1) = 1
                 ORDER  BY ISNULL(x.fac_es_definitiva, 0) DESC,
                           x.fac_fecha_accion_utc DESC, x.fac_id DESC
            ) acc

    WHERE   f.fal_activo = @ACTIVO
      AND   ISNULL(f.fal_habilitado, 1) = 1
GO
PRINT '--- SEL_ACTIVO_FALLA_CIERRE creado.'
GO

PRINT '285_FALLA_CIERRE aplicado.'
GO
