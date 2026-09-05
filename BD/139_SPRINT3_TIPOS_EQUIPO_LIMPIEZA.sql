USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - ORDENA EL CATALOGO DE TIPOS DE ACTIVO (EQUIPOS).
-- =============================================
-- Va DESPUES de 138_SPRINT3_FIX_UBICACION.
--
-- PROBLEMA: la casilla "Tipo" al crear un activo mostraba piezas
-- (Motorreductor, Servomotor, Sensores) y no las familias de equipo reales
-- (Panificacion, Refrigeracion, Dosificacion), que estaban deshabilitadas.
-- "Tipo de activo" = la CLASE del EQUIPO (Modeladora, Horno...), no la pieza.
-- Las piezas ya viven en el catalogo Componente_Tipo (Motor, Sensor...).
--
-- QUE HACE:
--   1) Habilita las familias de equipo: Panificacion, Refrigeracion, Dosificacion.
--   2) Crea el tipo "Modeladora" bajo Panificacion (codigo automatico).
--   3) Asigna ese tipo a la Modeladora (ACT-33).
--   4) Saca del dropdown (baja logica, habilitado=0) los tipos que son PIEZAS:
--      Motorreductor, Servomotor, Sensor inductivo, Sensor capacitivo.
--
-- El modelo SEW (Activo_Modelo id 7) se conserva como hogar de la
-- documentacion del motor; queda bajo un tipo deshabilitado, sin molestar.
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @MODELADORA_TIPO INT = NULL, @NEW INT = NULL;

/* 1) Habilitar las familias de equipo. */
UPDATE [dbo].[Activo_Tipo] SET ati_habilitado = 1
WHERE  ati_cliente = @CLIENTE AND ati_id IN (26, 27, 28);   -- Panificacion, Refrigeracion, Dosificacion
PRINT '--- Familias de equipo habilitadas (Panificacion, Refrigeracion, Dosificacion).';

/* 2) Crear el tipo "Modeladora" bajo Panificacion (26), si no existe. */
SELECT @MODELADORA_TIPO = ati_id FROM [dbo].[Activo_Tipo]
WHERE  ati_cliente = @CLIENTE AND ati_nombre = N'Modeladora';

IF @MODELADORA_TIPO IS NULL
BEGIN
    EXEC [dbo].[INS_ACTIVO_TIPO]
         @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO_PADRE = 26,
         @CODIGO = N'AUTO', @NOMBRE = N'Modeladora',
         @DESCRIPCION = N'Modeladora de masa (equipo de panificacion).',
         @ORDEN = 1, @USUARIO = @USUARIO;
    SET @MODELADORA_TIPO = @NEW;
    PRINT '--- Tipo de equipo "Modeladora" creado bajo Panificacion (id ' + LTRIM(STR(@MODELADORA_TIPO)) + ').';
END
ELSE
    PRINT '--- El tipo "Modeladora" ya existia (id ' + LTRIM(STR(@MODELADORA_TIPO)) + ').';

/* 3) La Modeladora (ACT-33) toma su tipo correcto. */
UPDATE [dbo].[Activo]
SET    act_activo_tipo = @MODELADORA_TIPO,
       act_usuario_actualizacion = @USUARIO,
       act_fecha_actualizacion   = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM Cliente WHERE cli_id = @CLIENTE))
WHERE  act_codigo = 'ACT-33' AND act_cliente = @CLIENTE;
PRINT '--- ACT-33 (Modeladora) asignada al tipo Modeladora.';

/* 4) Sacar del dropdown los tipos que son PIEZAS (baja logica). */
UPDATE [dbo].[Activo_Tipo] SET ati_habilitado = 0
WHERE  ati_cliente = @CLIENTE AND ati_id IN (30, 31, 32, 33);  -- Motorreductor, Servomotor, Sensores
PRINT '--- Motorreductor/Servomotor/Sensores deshabilitados como tipo de equipo (son piezas).';
GO

/* ========================================================================
   COMPROBACION - tipos de equipo que veras en el dropdown (habilitado=1)
   ======================================================================== */
PRINT '=== TIPOS DE ACTIVO HABILITADOS (los que apareceran en "Tipo") ===';
SELECT ati_id, ati_codigo, ati_nombre, ISNULL(ati_activo_tipo_padre,0) padre
FROM   [dbo].[Activo_Tipo]
WHERE  ati_cliente = 1 AND ati_habilitado = 1
ORDER  BY ISNULL(ati_activo_tipo_padre,0), ati_id;

PRINT '=== LA MODELADORA CON SU TIPO ===';
SELECT a.act_codigo, a.act_nombre, t.ati_nombre AS tipo
FROM   [dbo].[Activo] a JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
WHERE  a.act_codigo = 'ACT-33';
GO

PRINT '139_SPRINT3_TIPOS_EQUIPO_LIMPIEZA aplicado.';
GO
