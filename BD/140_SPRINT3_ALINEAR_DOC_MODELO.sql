USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - ALINEA LOS DATOS DEL EQUIPO CON LA DOCUMENTACION.
-- =============================================
-- Va DESPUES de 139_SPRINT3_TIPOS_EQUIPO_LIMPIEZA.
--
-- Segun la doc canonica (SIGMA_MODELO_LOGICO_v2, linea 1016 y ANEXO_A):
--   * Activo_Modelo = fabricante + modelo de una MAQUINA (atado a un
--     Activo_Tipo). Ej: para el tipo Modeladora, un modelo Fritsch.
--   * Un MOTOR es una PIEZA (Componente_Tipo 1 MOTOR), NO un Activo_Modelo.
--
-- En 136 se habia creado, por el encuadre equivocado, un Activo_Modelo
-- "SEW W30 DT71D4/TH" (como si el motor fuera una maquina). Eso contradice la
-- doc: el motor ya vive como COMPONENTE de la Modeladora, con su marca/modelo
-- en el propio componente (aco_nombre + aco_descripcion). Aqui se da de baja
-- ese modelo sobrante. Sin dependientes (0 activos / planes / repuestos).
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* Baja logica del Activo_Modelo SEW (no es un modelo de maquina). */
UPDATE [dbo].[Activo_Modelo] SET amo_habilitado = 0
WHERE  amo_fabricante = N'SEW-Eurodrive' AND amo_nombre = N'W30 DT71D4/TH' AND amo_habilitado = 1;
PRINT '--- Activo_Modelo SEW dado de baja (un motor no es modelo de maquina; es pieza).';
GO

/* ========================================================================
   COMPROBACION - el equipo, tal como lo describe la doc.
   ======================================================================== */
PRINT '=== EQUIPO: Modeladora (tipo de maquina + ubicacion) ===';
SELECT a.act_codigo, a.act_nombre, t.ati_nombre AS tipo_maquina, a.act_fabricante,
       ci.cin_nombre AS planta, ia.iar_nombre AS area
FROM   [dbo].[Activo] a
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
JOIN   [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.act_cliente_instalacion
LEFT  JOIN [dbo].[Instalacion_Area] ia ON ia.iar_id = a.act_instalacion_area
WHERE  a.act_codigo = 'ACT-33';

PRINT '=== PIEZAS (Componente_Tipo): el despiece de la Modeladora ===';
SELECT ac.aco_codigo, ct.cto_nombre AS tipo_pieza, ac.aco_nombre
FROM   [dbo].[Activo_Componente] ac
JOIN   [dbo].[Componente_Tipo] ct ON ct.cto_id = ac.aco_componente_tipo
WHERE  ac.aco_activo = (SELECT act_id FROM Activo WHERE act_codigo='ACT-33')
ORDER  BY ac.aco_id;

PRINT '=== MODELOS DE MAQUINA vigentes (Activo_Modelo habilitado) ===';
SELECT amo_id, amo_activo_tipo, amo_fabricante, amo_nombre
FROM   [dbo].[Activo_Modelo] WHERE amo_habilitado = 1 AND amo_cliente = 1;
GO

PRINT '140_SPRINT3_ALINEAR_DOC_MODELO aplicado.';
GO
