USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     T-2023 DATOS DE PRUEBA DE ACTIVO_MEDIDOR PARA EJERCITAR HU-042.
-- =============================================
-- Va DESPUES de 77_SPRINT2_ACTIVO_MEDIDOR.
--
-- QUE HACE
--   1. Siembra las unidades de medida que un MEDIDOR necesita -horas, ciclos,
--      kilometros-, que no existian: las sembradas hasta ahora eran de
--      inventario (unidad, kg, litro). Sin una unidad de tiempo no se puede
--      configurar un horometro.
--   2. Crea medidores de ejemplo sobre los activos demo de Hamburgo.
--
-- POR QUE RESUELVE LOS IDS EN TIEMPO DE EJECUCION
--   Los activos y las unidades son IDENTITY. La demo los busca por su codigo
--   y solo inserta si existen; si los activos demo no estan (bloque 75 sin
--   ejecutar), avisa y no hace nada en vez de fallar.
--
-- ES IDEMPOTENTE
--   Unidades por su codigo (unico global); medidores por (activo, codigo).
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. UNIDADES DE MEDIDA PARA MEDIDORES
      Magnitudes del bloque 04: 9 TIEMPO, 10 CONTEO, 11 LONGITUD.

      Un indice filtrado -UX_UME_MAGNITUD_BASE ON (ume_magnitud) WHERE
      ume_unidad_base IS NULL- deja UNA sola unidad base por magnitud. Asi
      que cada unidad nueva cuelga de la base que ya exista para su magnitud;
      solo cuando la magnitud no tiene ninguna base, la nueva pasa a serlo.
      TIEMPO no tiene unidad todavia -> HORA es su base. CONTEO ya tiene
      (UNIDAD) y LONGITUD tambien (METRO) -> CICLO y KILOMETRO cuelgan de
      ellas, con su factor de conversion (1 km = 1000 m).
   ======================================================================== */

DECLARE @BASE_TIEMPO INT, @BASE_CONTEO INT, @BASE_LONGITUD INT

SELECT @BASE_TIEMPO   = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_magnitud = 9  AND ume_unidad_base IS NULL
SELECT @BASE_CONTEO   = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_magnitud = 10 AND ume_unidad_base IS NULL
SELECT @BASE_LONGITUD = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_magnitud = 11 AND ume_unidad_base IS NULL

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'HORA')
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES (9, @BASE_TIEMPO, N'HORA', N'Hora', N'h', 1, 0, 1, GETDATE(), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'CICLO')
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES (10, @BASE_CONTEO, N'CICLO', N'Ciclo', N'cic', 1, 0, 1, GETDATE(), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'KILOMETRO')
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES (11, @BASE_LONGITUD, N'KILOMETRO', N'Kilómetro', N'km', 1000, 0, 1, GETDATE(), 1)
GO


/* ========================================================================
   2. MEDIDORES DE EJEMPLO SOBRE LOS ACTIVOS DE HAMBURGO
   ======================================================================== */

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1
DECLARE @UME_HORA INT, @UME_CICLO INT

SELECT @UME_HORA  = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'HORA'
SELECT @UME_CICLO = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'CICLO'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = N'MOT-001')
BEGIN
    PRINT '--- No estan los activos demo de Hamburgo (falta el bloque 75). No se cargan medidores.'
    RETURN
END

DECLARE @M TABLE
(
    activo_codigo NVARCHAR(50),
    codigo        NVARCHAR(50),
    nombre        NVARCHAR(200),
    unidad        INT,
    valor         DECIMAL(18,2),
    permite_rein  BIT
)

INSERT INTO @M VALUES
    (N'MOT-001', N'HOROMETRO', N'Horómetro principal',        @UME_HORA,  12500.50, 0),
    (N'BMB-001', N'HOROMETRO', N'Horómetro de la bomba',      @UME_HORA,   8300.00, 0),
    (N'BMB-001', N'ARRANQUES', N'Contador de arranques',      @UME_CICLO,  1450.00, 1),
    (N'MOT-002', N'HOROMETRO', N'Horómetro del ventilador',   @UME_HORA,    500.00, 0)

INSERT INTO [dbo].[Activo_Medidor]
    (ame_cliente, ame_activo, ame_unidad_medida, ame_codigo, ame_nombre,
     ame_valor_actual, ame_fecha_valor_actual_utc, ame_permite_reinicio,
     ame_usuario_creacion, ame_fecha_creacion, ame_usuario_actualizacion,
     ame_fecha_actualizacion, ame_habilitado)
SELECT  @CLIENTE, a.act_id, m.unidad, m.codigo, m.nombre,
        m.valor, GETUTCDATE(), m.permite_rein,
        @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1
FROM    @M m
JOIN    [dbo].[Activo] a ON a.act_cliente = @CLIENTE AND a.act_codigo = m.activo_codigo
WHERE   m.unidad IS NOT NULL
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                     WHERE ame_activo = a.act_id AND ame_codigo = m.codigo)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'unidades de medidor' AS control, COUNT(*) AS valor
FROM   [dbo].[Unidad_Medida] WHERE ume_codigo IN (N'HORA', N'CICLO', N'KILOMETRO')
UNION ALL
SELECT 'medidores demo', COUNT(*)
FROM   [dbo].[Activo_Medidor] WHERE ame_cliente = 1
GO

PRINT '78_SPRINT2_ACTIVO_MEDIDOR_DEMO aplicado.'
GO
