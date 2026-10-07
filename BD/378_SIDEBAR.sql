USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     SIDEBAR PROPUESTO (GRUPOS CON TITULO, NOMBRES CORTOS, CONTADORES) Y BUSQUEDA «IR A…».
-- =============================================
-- POR QUE
--   El menu lateral agrupa los modulos por titulo (Configuracion, Gestion, Operacion, Centro de Ayuda, Inteligencia) y
--   dice cada nombre en una linea. Todo sale de la tabla de menus, nada queda fijo en el HTML:
--
--   Menus.mnu_grupo ......... el grupo del modulo. Una opcion de cualquier nivel con grupo se dibuja como
--                             modulo propio (SIGMA Twin sigue colgando de Inventario para los permisos,
--                             pero se muestra en Inteligencia). '~' = no va en el sidebar (Alertas: vive en la campana).
--   Menus.mnu_nombre_corto .. el nombre de una linea del sidebar (el completo queda en el submenu y en «Ir a…»).
--   Menus.mnu_contador ...... que contador lleva: ot (vencidas) · stock (fuera de umbral) · ai (predicciones nuevas) · soporte (tickets abiertos).
--   SEL_MENUS_SIDEBAR ....... esas tres columnas. SEL_MENU_CONTADORES ... los numeros.
-- TODO IDEMPOTENTE.
-- =============================================

IF COL_LENGTH('dbo.Menus', 'mnu_grupo') IS NULL ALTER TABLE [dbo].[Menus] ADD mnu_grupo NVARCHAR(30) NULL
GO
IF COL_LENGTH('dbo.Menus', 'mnu_nombre_corto') IS NULL ALTER TABLE [dbo].[Menus] ADD mnu_nombre_corto NVARCHAR(40) NULL
GO
IF COL_LENGTH('dbo.Menus', 'mnu_contador') IS NULL ALTER TABLE [dbo].[Menus] ADD mnu_contador NVARCHAR(20) NULL
GO

/* Operacion */
UPDATE [dbo].[Menus] SET mnu_grupo = N'Operación', mnu_nombre_corto = N'Mantenimiento', mnu_contador = N'ot'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'Centro de Mantenimiento'
UPDATE [dbo].[Menus] SET mnu_grupo = N'Operación', mnu_nombre_corto = N'Activos'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'Control de activos'
UPDATE [dbo].[Menus] SET mnu_grupo = N'Operación', mnu_contador = N'stock'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'Inventario'
/* Inteligencia */
UPDATE [dbo].[Menus] SET mnu_grupo = N'Inteligencia', mnu_contador = N'ai'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'SIGMA AI'
UPDATE [dbo].[Menus] SET mnu_grupo = N'Inteligencia'
 WHERE mnu_link COLLATE Latin1_General_CI_AI LIKE N'%BodegaMapa3D.aspx'
/* Gestion */
UPDATE [dbo].[Menus] SET mnu_grupo = N'Centro de Ayuda', mnu_contador = N'soporte'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'Soporte'
UPDATE [dbo].[Menus] SET mnu_grupo = N'Gestión'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI IN (N'Terceros', N'Cliente')
/* Configuracion (la de root: Sistema y Comercial) va primero; Utilidades es del cliente y va con Soporte en Centro de Ayuda */
UPDATE [dbo].[Menus] SET mnu_grupo = N'Configuración'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI IN (N'Sistema', N'Comercial')
UPDATE [dbo].[Menus] SET mnu_grupo = N'Centro de Ayuda'
 WHERE mnu_nivel = 2 AND mnu_nombre COLLATE Latin1_General_CI_AI = N'Utilidades'
/* Alertas vive en la campana */
UPDATE [dbo].[Menus] SET mnu_grupo = N'~'
 WHERE mnu_link COLLATE Latin1_General_CI_AI LIKE N'%Comun/Notificaciones/Notificaciones.aspx'
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_MENUS_SIDEBAR]
AS
SET NOCOUNT ON
SELECT mnu_id AS ID, mnu_grupo AS GRUPO, mnu_nombre_corto AS CORTO, mnu_contador AS CONTADOR
FROM   [dbo].[Menus]
WHERE  mnu_grupo IS NOT NULL OR mnu_nombre_corto IS NOT NULL OR mnu_contador IS NOT NULL
GO

/* Los numeros de los contadores del sidebar. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_MENU_CONTADORES]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
SELECT
    OT      = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_fecha_programada_utc < @UTC),
    STOCK   = (SELECT COUNT(*) FROM [dbo].[Alerta] a JOIN [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
                WHERE a.ale_cliente = @CLIENTE AND a.ale_habilitado = 1 AND t.alt_codigo IN (N'STOCK MINIMO', N'STOCK MAXIMO') AND a.ale_alerta_estado IN (1, 2, 3)),
    AI      = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL AND pre_fecha_calculo_utc >= DATEADD(HOUR, -24, @UTC)),
    SOPORTE = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado
                WHERE t.stk_cliente = @CLIENTE AND t.stk_usuario = @USUARIO AND t.stk_habilitado = 1 AND e.ses_abierto = 1)
GO

/* «Ir a…»: activos, ordenes de trabajo y repuestos que calzan con lo escrito (la web filtra por permiso). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BUSCAR_GLOBAL]
    @CLIENTE   INT,
    @Q         NVARCHAR(100),
    @ACTIVOS   BIT = 1,
    @ORDENES   BIT = 1,
    @REPUESTOS BIT = 1,
    @LIMITE    INT = 12
AS
SET NOCOUNT ON
SET @Q = LTRIM(RTRIM(ISNULL(@Q, N'')))
IF LEN(@Q) < 2 RETURN
DECLARE @L NVARCHAR(120) = N'%' + REPLACE(REPLACE(@Q, N'[', N'[[]'), N'%', N'[%]') + N'%'
SELECT TOP (@LIMITE) * FROM (
    SELECT N'Activo' AS TIPO, a.act_id AS ID, a.act_nombre AS TITULO, a.act_codigo AS SUBTITULO, 1 AS ORDEN
    FROM   [dbo].[Activo] a
    WHERE  @ACTIVOS = 1 AND a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND (a.act_nombre LIKE @L OR a.act_codigo LIKE @L)
    UNION ALL
    SELECT N'Orden de trabajo', o.otr_id, N'OT ' + CAST(o.otr_correlativo AS NVARCHAR(20)) + N' · ' + ISNULL(o.otr_titulo, N''), ISNULL(ac.act_nombre, N''), 2
    FROM   [dbo].[Orden_Trabajo] o LEFT JOIN [dbo].[Activo] ac ON ac.act_id = o.otr_activo
    WHERE  @ORDENES = 1 AND o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND (o.otr_titulo LIKE @L OR CAST(o.otr_correlativo AS NVARCHAR(20)) LIKE @L)
    UNION ALL
    SELECT N'Repuesto', r.rep_id, r.rep_codigo + N' · ' + r.rep_nombre, ISNULL(r.rep_fabricante, N''), 3
    FROM   [dbo].[Repuesto] r
    WHERE  @REPUESTOS = 1 AND r.rep_cliente = @CLIENTE AND (r.rep_nombre LIKE @L OR r.rep_codigo LIKE @L OR r.rep_fabricante LIKE @L)
) x ORDER BY ORDEN, TITULO
GO

PRINT '378_SIDEBAR aplicado.'
GO
