USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: la atencion por tickets es del PLAN del
--                  cliente y tiene consumo mensual. El centro de ayuda y las
--                  campanas siguen siendo para todos.
-- =============================================
-- Va DESPUES de 364. Generado por _scratch/gen_365.py.
--
--   1. Funcionalidad SOPORTE TICKETS (tipo LIMITE, tope = tickets al mes).
--      Valores iniciales, editables en la matriz de planes (bloque 46):
--        Basico: no incluida · Medio: 10 al mes · Full: 1000 al mes (CK_PCF_LIMITE exige tope).
--   2. FNC_CLIENTE_CONSUMO cuenta los tickets del mes en curso.
--   3. SEL_SOPORTE_PLAN: lo que la cabecera y el menu necesitan saber.
--      Sin plan NO hay ticketera (a diferencia de FNC_CLIENTE_PUEDE_CREAR,
--      que deja crear sin suscripcion para no trabar el alta).
--   4. El menu Soporte sube: queda despues de Cliente.
-- =============================================

SET NOCOUNT ON
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SOPORTE TICKETS')
BEGIN
    IF COLUMNPROPERTY(OBJECT_ID('dbo.Funcionalidad'), 'fun_id', 'IsIdentity') = 1
        INSERT INTO [dbo].[Funcionalidad] (fun_codigo, fun_nombre, fun_orden, fun_habilitado)
        VALUES (N'SOPORTE TICKETS', N'Atención por tickets de soporte (al mes)', 26, 1)
    ELSE
        INSERT INTO [dbo].[Funcionalidad] (fun_id, fun_codigo, fun_nombre, fun_orden, fun_habilitado)
        SELECT ISNULL(MAX(fun_id), 0) + 1, N'SOPORTE TICKETS', N'Atención por tickets de soporte (al mes)', 26, 1 FROM [dbo].[Funcionalidad]
END
GO

DECLARE @FUN INT = (SELECT fun_id FROM [dbo].[Funcionalidad] WHERE fun_codigo = N'SOPORTE TICKETS')
DECLARE @TIPO INT = (SELECT fnt_id FROM [dbo].[Funcionalidad_Tipo] WHERE fnt_codigo = 'LIMITE')
DECLARE @V TABLE (plan_codigo NVARCHAR(50) COLLATE DATABASE_DEFAULT, incluida BIT, limite DECIMAL(18,2))
INSERT INTO @V VALUES (N'BASICO', 0, 0), (N'MEDIO', 1, 10), (N'FULL', 1, 1000)

IF COLUMNPROPERTY(OBJECT_ID('dbo.Plan_Comercial_Funcionalidad'), 'pcf_id', 'IsIdentity') = 1
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] (pcf_plan_comercial, pcf_funcionalidad, pcf_funcionalidad_tipo, pcf_incluida, pcf_limite,
                                                      pcf_usuario_creacion, pcf_fecha_creacion, pcf_habilitado)
    SELECT p.plc_id, @FUN, @TIPO, v.incluida, v.limite, 1, [dbo].[FNC_AHORA](), 1
      FROM [dbo].[Plan_Comercial] p JOIN @V v ON v.plan_codigo = p.plc_codigo COLLATE DATABASE_DEFAULT
     WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] x WHERE x.pcf_plan_comercial = p.plc_id AND x.pcf_funcionalidad = @FUN AND x.pcf_cliente IS NULL)

DECLARE @N INT = (SELECT COUNT(*) FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE pcf_funcionalidad = @FUN)
PRINT '--- Planes con SOPORTE TICKETS: ' + LTRIM(STR(@N)) + ' (esperado 3)'
GO

/* ========================================================================
   2. FNC_CLIENTE_CONSUMO

      Cuanto lleva usado el cliente de una funcionalidad con tope.

      Se cuenta lo HABILITADO, no lo existente: una planta deshabilitada no
      ocupa cupo. Si contara todo, un cliente que da de baja una planta para
      crear otra seguiria bloqueado, y la unica salida seria borrar datos,
      que es justo lo que §8 prohibe.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_CONSUMO]
(
    @CLIENTE              INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @N DECIMAL(18,2) = 0

    IF @FUNCIONALIDAD_CODIGO = N'LIMITE PLANTAS'
        SELECT @N = COUNT(*) FROM [dbo].[Cliente_Instalacion]
         WHERE cin_cliente = @CLIENTE AND ISNULL(cin_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE USUARIOS'
        SELECT @N = COUNT(*) FROM [dbo].[Cliente_Usuario]
         WHERE ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE ACTIVOS'
        SELECT @N = COUNT(*) FROM [dbo].[Activo]
         WHERE act_cliente = @CLIENTE AND ISNULL(act_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE ALMACENAMIENTO'
        -- En GB, que es la unidad en que esta expresado el tope.
        SELECT @N = ISNULL(SUM(CAST(arc_byte AS DECIMAL(18,2))), 0) / 1073741824.0
          FROM [dbo].[Archivo]
         WHERE arc_cliente = @CLIENTE AND ISNULL(arc_habilitado, 0) = 1

    /* Bloque 365: tickets de soporte creados ESTE MES (el tope es mensual). */
    ELSE IF @FUNCIONALIDAD_CODIGO = N'SOPORTE TICKETS'
        SELECT @N = COUNT(*) FROM [dbo].[Soporte_Ticket]
         WHERE stk_cliente = @CLIENTE AND stk_habilitado = 1
           AND stk_fecha_creacion >= DATEFROMPARTS(YEAR([dbo].[FNC_AHORA]()), MONTH([dbo].[FNC_AHORA]()), 1)

    RETURN @N
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_PLAN]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    DECLARE @INCLUIDO BIT = CASE WHEN ISNULL(@CLIENTE, 0) = 0 THEN 0 ELSE [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](@CLIENTE, N'SOPORTE TICKETS') END
    DECLARE @LIMITE DECIMAL(18,2) = CASE WHEN @INCLUIDO = 1 THEN [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, N'SOPORTE TICKETS') END
    DECLARE @CONSUMO DECIMAL(18,2) = CASE WHEN @INCLUIDO = 1 THEN [dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, N'SOPORTE TICKETS') ELSE 0 END
    SELECT  INCLUIDO = @INCLUIDO,
            LIMITE = CAST(@LIMITE AS INT),
            CONSUMO = CAST(@CONSUMO AS INT),
            DISPONIBLE = CAST(CASE WHEN @INCLUIDO = 1 AND (@LIMITE IS NULL OR @CONSUMO < @LIMITE) THEN 1 ELSE 0 END AS BIT),
            AGENTE = [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO)
GO

/* El menu Soporte, despues de Cliente. */
DECLARE @RAIZ INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nivel = 1 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Menus')
DECLARE @CLI INT = (SELECT mnu_orden FROM [dbo].[Menus] WHERE mnu_padre = @RAIZ AND mnu_nivel = 2 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Cliente')
DECLARE @SOP INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @RAIZ AND mnu_nivel = 2 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Soporte')
IF @SOP IS NOT NULL AND (SELECT mnu_orden FROM [dbo].[Menus] WHERE mnu_id = @SOP) <> @CLI + 1
BEGIN
    UPDATE [dbo].[Menus] SET mnu_orden = mnu_orden + 1
     WHERE mnu_padre = @RAIZ AND mnu_nivel = 2 AND mnu_id <> @SOP AND mnu_orden > @CLI AND mnu_orden < 90
    UPDATE [dbo].[Menus] SET mnu_orden = @CLI + 1 WHERE mnu_id = @SOP
END
GO
