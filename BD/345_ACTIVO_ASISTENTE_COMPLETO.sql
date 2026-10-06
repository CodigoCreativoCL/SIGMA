/* ============================================================================
   SIGMA - Bloque 345
   EL ASISTENTE DEL ACTIVO CREA TODO LO QUE ESCRIBES
   ----------------------------------------------------------------------------
   Revisión de Bryan sobre el rediseño (04-10-2026):

     1. Menús: «Tipos de activo» se habilita de nuevo (con su nodo
        «Configuración de activos»). «Componentes» NO va al menú lateral: vive
        dentro del Centro de activos (vista «Componentes» del listado y menú
        «Crear»), por pedido de Bryan. Los demás de configuración siguen ocultos.
        Nunca se borra un menú: solo mnu_visible.
     2. UPS_COMPONENTE_POSICION_NOMBRE: «Dónde va» de un componente se elige o
        se escribe; si no existe se crea como propio de la empresa.
     3. UPS_VARIABLE_MEDICION_NOMBRE: el paso «Qué se mide» del asistente
        escribe la variable («Temperatura de la cámara»); si no existe se crea
        como propia de la empresa, decimal y con la unidad elegida.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

-- ---------------------------------------------------------------------------
-- 1) Menús
-- ---------------------------------------------------------------------------
UPDATE m SET mnu_visible = 0, mnu_orden = 21
FROM   [dbo].[Menus] m
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Componentes/ActivoComponentes.aspx'

UPDATE m SET mnu_visible = 1
FROM   [dbo].[Menus] m
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Tipos/ActivoTipos.aspx'

UPDATE p SET mnu_visible = 1
FROM   [dbo].[Menus] p
WHERE  p.mnu_id IN (SELECT m.mnu_padre FROM [dbo].[Menus] m
                    WHERE m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Tipos/ActivoTipos.aspx')
GO

-- ---------------------------------------------------------------------------
-- 2) «Dónde va» escrito en la ficha: buscar o crear (propio del cliente)
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     BUSCA LA POSICION DE COMPONENTE POR NOMBRE (COMUN O DEL
--                  CLIENTE) Y SI NO EXISTE LA CREA COMO PROPIA DEL CLIENTE
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_COMPONENTE_POSICION_NOMBRE]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(100),
    @USUARIO INT
AS
SET NOCOUNT ON
    SET @ID = NULL
    SET @NOMBRE = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@NOMBRE), N'')
    IF @NOMBRE IS NULL BEGIN RAISERROR('1.- ESCRIBA DONDE VA EL COMPONENTE.', 16, 1) RETURN -1 END

    SELECT TOP 1 @ID = cpn_id FROM [dbo].[Componente_Posicion]
    WHERE  (cpn_cliente IS NULL OR cpn_cliente = @CLIENTE)
      AND  cpn_nombre COLLATE Latin1_General_CI_AI = @NOMBRE COLLATE Latin1_General_CI_AI
    ORDER BY CASE WHEN cpn_cliente IS NULL THEN 0 ELSE 1 END, cpn_habilitado DESC

    IF @ID IS NOT NULL RETURN 0

    DECLARE @CODIGO NVARCHAR(50) = LEFT(UPPER(@NOMBRE), 45), @N INT = 1
    WHILE EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE cpn_cliente = @CLIENTE AND cpn_codigo = @CODIGO)
    BEGIN SET @N += 1; SET @CODIGO = LEFT(UPPER(@NOMBRE), 42) + N'-' + LTRIM(@N) END

    INSERT INTO [dbo].[Componente_Posicion] (cpn_cliente, cpn_codigo, cpn_nombre, cpn_orden, cpn_usuario_creacion, cpn_fecha_creacion,
                                             cpn_usuario_actualizacion, cpn_fecha_actualizacion, cpn_habilitado)
    VALUES (@CLIENTE, @CODIGO, [dbo].[FNC_NOMBRE_PROPIO](@NOMBRE), 100, @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 3) Variable de medición escrita en el asistente: buscar o crear
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     BUSCA LA VARIABLE DE MEDICION POR NOMBRE (COMUN O DEL
--                  CLIENTE) Y SI NO EXISTE LA CREA COMO PROPIA DEL CLIENTE
--                  (DECIMAL, CON LA UNIDAD INDICADA)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_VARIABLE_MEDICION_NOMBRE]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(200),
    @UNIDAD  INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    SET @ID = NULL
    SET @NOMBRE = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@NOMBRE), N'')
    IF @NOMBRE IS NULL BEGIN RAISERROR('1.- ESCRIBA QUE SE MIDE.', 16, 1) RETURN -1 END

    SELECT TOP 1 @ID = vme_id FROM [dbo].[Variable_Medicion]
    WHERE  (vme_cliente IS NULL OR vme_cliente = @CLIENTE)
      AND  vme_nombre COLLATE Latin1_General_CI_AI = @NOMBRE COLLATE Latin1_General_CI_AI
    ORDER BY CASE WHEN vme_cliente IS NULL THEN 0 ELSE 1 END, vme_habilitado DESC

    IF @ID IS NOT NULL RETURN 0
    IF @UNIDAD IS NULL OR NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD)
    BEGIN RAISERROR('2.- ELIJA LA UNIDAD DE LO QUE SE MIDE.', 16, 1) RETURN -1 END

    DECLARE @CODIGO NVARCHAR(50) = LEFT(UPPER(@NOMBRE), 45), @N INT = 1
    WHILE EXISTS (SELECT 1 FROM [dbo].[Variable_Medicion] WHERE vme_cliente = @CLIENTE AND vme_codigo = @CODIGO)
    BEGIN SET @N += 1; SET @CODIGO = LEFT(UPPER(@NOMBRE), 42) + N'-' + LTRIM(@N) END

    INSERT INTO [dbo].[Variable_Medicion] (vme_cliente, vme_unidad_medida, vme_tipo_dato, vme_codigo, vme_nombre,
                                           vme_usuario_creacion, vme_fecha_creacion, vme_usuario_actualizacion, vme_fecha_actualizacion, vme_habilitado)
    VALUES (@CLIENTE, @UNIDAD, 3, @CODIGO, [dbo].[FNC_NOMBRE_PROPIO](@NOMBRE), @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

SELECT mnu_nombre, mnu_link, mnu_orden, mnu_visible FROM [dbo].[Menus]
WHERE  mnu_link IN (N'~/View/Activos/Componentes/ActivoComponentes.aspx', N'~/View/Activos/Tipos/ActivoTipos.aspx')
GO
