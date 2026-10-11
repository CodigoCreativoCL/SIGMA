SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     SEL_PROGRAMACION_MEDIDOR TAMBIEN DEVUELVE LA REGLA SIN
--                  MEDIDOR FIJO (pme_activo_medidor NULL, BD/224 y 243).
-- =============================================
-- POR QUE
--
--   Desde 243 una programación por medidor puede no nombrar un medidor:
--   cada equipo dispara con su propio horómetro (pac_activo_medidor). El
--   SELECT hacía JOIN al medidor y esas reglas no aparecían, así que el
--   cajón del calendario compartido no tenía qué mostrar y se cerraba con
--   «se edita en Programaciones». Ahora es LEFT JOIN: las columnas del
--   medidor vienen vacías y PROXIMO_VALOR queda NULL (depende de cada equipo).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROGRAMACION_MEDIDOR]
    @PROGRAMACION   INT,
    @CLIENTE        INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  m.pme_id,
            m.pme_programacion,
            m.pme_activo_medidor,
            am.ame_codigo               AS MEDIDOR_CODIGO,
            am.ame_nombre               AS MEDIDOR_NOMBRE,
            am.ame_valor_actual         AS MEDIDOR_VALOR_ACTUAL,
            am.ame_activo,
            a.act_nombre                AS ACTIVO_NOMBRE,
            m.pme_valor_inicial,
            m.pme_cada_cantidad,
            m.pme_aviso_anticipacion,
            m.pme_habilitado,
            CAST(m.pme_valor_inicial + m.pme_cada_cantidad
                 * (FLOOR((am.ame_valor_actual - m.pme_valor_inicial) / NULLIF(m.pme_cada_cantidad, 0)) + 1)
                 AS DECIMAL(18,2))      AS PROXIMO_VALOR
    FROM    [dbo].[Programacion_Medidor] m
    LEFT JOIN [dbo].[Activo_Medidor] am ON am.ame_id = m.pme_activo_medidor
    LEFT JOIN [dbo].[Activo] a ON a.act_id = am.ame_activo
    WHERE   m.pme_programacion = @PROGRAMACION
      AND   m.pme_habilitado = 1
GO
