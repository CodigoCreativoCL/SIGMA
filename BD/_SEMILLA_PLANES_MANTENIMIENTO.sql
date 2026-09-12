USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA PLANES DE MANTENIMIENTO (T-4006).
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   Va con guion bajo y sin numero: no cambia la estructura, mete filas de
--   ejemplo para poder ejercitar los criterios de aceptacion de HU-080.
--   `Plan_Mantenimiento` estaba en CERO, y una grilla vacia se ve igual
--   estando bien que estando rota.
--
--   Pasa por INS_PLAN_MANTENIMIENTO y no por INSERT directo: asi cada plan
--   nace con su version 1 en borrador, como nacen los reales. Idempotente.
--
-- LOS TRES CASOS QUE HAY QUE VER
--
--   1. Un plan acotado a planta y tipo, con codigo escrito por la persona.
--   2. Un plan sin planta ni tipo -aplica a todo-, con codigo automatico.
--   3. Un plan deshabilitado, para que el filtro «Habilitado» tenga que
--      esconder algo.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @PLANTA  INT = (SELECT TOP 1 cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE ORDER BY cin_id)
DECLARE @TIPO    INT = (SELECT TOP 1 ati_id FROM [dbo].[Activo_Tipo] WHERE ISNULL(ati_cliente, @CLIENTE) = @CLIENTE AND ati_habilitado = 1 ORDER BY ati_id)
DECLARE @ID INT

IF (@USUARIO IS NULL OR @PLANTA IS NULL)
BEGIN
    RAISERROR('1.- FALTA EL USUARIO DE PRUEBA O UNA PLANTA DEL CLIENTE 1.', 16, 1)
    RETURN
END

-- 1) Acotado, con codigo escrito
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-HORNOS-L1')
    EXEC [dbo].[INS_PLAN_MANTENIMIENTO]
         @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
         @CODIGO = N'PMA-HORNOS-L1', @NOMBRE = N'Preventivo de hornos de línea 1',
         @DESCRIPCION = N'Lubricación, inspección de quemadores y calibración de termocuplas de los hornos de la línea 1.',
         @USUARIO_PLANIFICADOR = @USUARIO, @ACTIVO_TIPO = @TIPO, @ACTIVO_MODELO = NULL,
         @USUARIO = @USUARIO

-- 2) Sin alcance, codigo automatico
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_nombre = N'Inspección mensual de seguridad')
    EXEC [dbo].[INS_PLAN_MANTENIMIENTO]
         @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = NULL,
         @CODIGO = N'AUTO', @NOMBRE = N'Inspección mensual de seguridad',
         @DESCRIPCION = N'Recorrido mensual de guardas, paradas de emergencia y señalética de toda la planta.',
         @USUARIO_PLANIFICADOR = NULL, @ACTIVO_TIPO = NULL, @ACTIVO_MODELO = NULL,
         @USUARIO = @USUARIO

-- 3) Deshabilitado
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento] WHERE pma_cliente = @CLIENTE AND pma_codigo = 'PMA-ANTIGUO')
BEGIN
    EXEC [dbo].[INS_PLAN_MANTENIMIENTO]
         @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = NULL,
         @CODIGO = N'PMA-ANTIGUO', @NOMBRE = N'Plan 2024 (reemplazado)',
         @DESCRIPCION = N'El plan del año pasado. Se conserva deshabilitado por trazabilidad.',
         @USUARIO_PLANIFICADOR = NULL, @ACTIVO_TIPO = NULL, @ACTIVO_MODELO = NULL,
         @USUARIO = @USUARIO

    EXEC [dbo].[DEL_PLAN_MANTENIMIENTO] @ID = @ID, @USUARIO = @USUARIO
END
GO

-- ---------------------------------------------------------------------------
-- Verificacion: lo que va a mostrar la grilla
-- ---------------------------------------------------------------------------
EXEC [dbo].[SEL_PLAN_MANTENIMIENTO] @CLIENTE = 1
GO
