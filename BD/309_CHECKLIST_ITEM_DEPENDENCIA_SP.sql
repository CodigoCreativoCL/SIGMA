USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           29-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-092) SP del mantenedor de DEPENDENCIAS entre
--                  items (Checklist_Item_Dependencia): SEL/INS/UPD/DEL.
--
--   Una dependencia: un item (el dependiente) se MUESTRA/OCULTA/REQUIERE/BLOQUEA
--   segun como se respondio OTRO item (la condicion) con un operador y un valor.
--   Ambos items tienen que ser de la MISMA pauta. Un item no puede depender de si
--   mismo (CA2). El mostrar/ocultar en terreno lo hace la app al ejecutar.
-- =============================================
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_CHECKLIST_ITEM_DEPENDENCIA - listado y ficha (por @ID)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_DEPENDENCIA]
@CLIENTE    INT,
@ID         INT = NULL,
@PLANTILLA  INT = NULL,
@FILTRO     NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  d.cid_id                          AS CID_ID,
        d.cid_checklist_plantilla_item    AS ITEM_ID,
        i.cpi_texto                       AS ITEM_TEXTO,
        d.cid_item_condicion              AS CONDICION_ID,
        ic.cpi_texto                      AS CONDICION_TEXTO,
        d.cid_operador_comparacion        AS OPERADOR_ID,
        op.opc_nombre                     AS OPERADOR_NOMBRE,
        ISNULL(d.cid_valor_comparacion,'')AS VALOR,
        d.cid_checklist_item_opcion       AS OPCION_ID,
        ISNULL(o.cio_texto,'')            AS OPCION_TEXTO,
        d.cid_dependencia_accion          AS ACCION_ID,
        ac.dac_codigo                     AS ACCION_CODIGO,
        ac.dac_nombre                     AS ACCION_NOMBRE,
        pl.cpl_id                         AS PLANTILLA_ID,
        pl.cpl_nombre                     AS PLANTILLA_NOMBRE,
        d.cid_habilitado                  AS HABILITADO
FROM    [dbo].[Checklist_Item_Dependencia]   d
JOIN    [dbo].[Checklist_Plantilla_Item]     i   ON i.cpi_id  = d.cid_checklist_plantilla_item
JOIN    [dbo].[Checklist_Plantilla_Item]     ic  ON ic.cpi_id = d.cid_item_condicion
JOIN    [dbo].[Operador_Comparacion]         op  ON op.opc_id = d.cid_operador_comparacion
JOIN    [dbo].[Dependencia_Accion]           ac  ON ac.dac_id = d.cid_dependencia_accion
JOIN    [dbo].[Checklist_Plantilla_Version]  ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]          pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Item_Opcion]      o   ON o.cio_id   = d.cid_checklist_item_opcion
WHERE   pl.cpl_cliente = @CLIENTE
  AND   (@ID IS NULL OR d.cid_id = @ID)
  AND   (@PLANTILLA IS NULL OR pl.cpl_id = @PLANTILLA)
  AND   (@ID IS NOT NULL OR d.cid_habilitado = 1)
  AND   (@FILTRO IS NULL OR @FILTRO = '' OR i.cpi_texto LIKE '%' + @FILTRO + '%' OR ic.cpi_texto LIKE '%' + @FILTRO + '%')
ORDER BY pl.cpl_nombre, i.cpi_orden, d.cid_id
GO


-- ---------------------------------------------------------------------------
-- 2) INS_CHECKLIST_ITEM_DEPENDENCIA - alta (no circular, misma pauta)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_ITEM_DEPENDENCIA]
@ID          INT = NULL OUTPUT,
@CLIENTE     INT,
@ITEM        INT,
@CONDICION   INT,
@OPERADOR    INT,
@VALOR       NVARCHAR(400) = NULL,
@OPCION      INT = NULL,
@ACCION      INT,
@USUARIO     INT
AS
SET NOCOUNT ON

-- CA-2: un item no puede depender de si mismo (circular directa).
IF @ITEM = @CONDICION
BEGIN RAISERROR('1.- UN ITEM NO PUEDE DEPENDER DE SI MISMO.', 16, 1) RETURN -1 END

DECLARE @PL_ITEM INT, @PL_COND INT
SELECT @PL_ITEM = ver.cpv_checklist_plantilla
FROM [dbo].[Checklist_Plantilla_Item] i
JOIN [dbo].[Checklist_Plantilla_Version] ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = ver.cpv_checklist_plantilla
WHERE i.cpi_id = @ITEM AND p.cpl_cliente = @CLIENTE

SELECT @PL_COND = ver.cpv_checklist_plantilla
FROM [dbo].[Checklist_Plantilla_Item] i
JOIN [dbo].[Checklist_Plantilla_Version] ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
WHERE i.cpi_id = @CONDICION

IF @PL_ITEM IS NULL
BEGIN RAISERROR('2.- EL ITEM NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1) RETURN -1 END
IF @PL_COND IS NULL
BEGIN RAISERROR('3.- EL ITEM DE CONDICION NO EXISTE.', 16, 1) RETURN -1 END
IF @PL_ITEM <> @PL_COND
BEGIN RAISERROR('4.- LOS DOS ITEMS TIENEN QUE SER DE LA MISMA PAUTA.', 16, 1) RETURN -1 END

-- Evita la reciproca directa: si la condicion ya depende del item, seria un ciclo.
IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Dependencia]
           WHERE cid_checklist_plantilla_item = @CONDICION AND cid_item_condicion = @ITEM AND cid_habilitado = 1)
BEGIN RAISERROR('5.- YA EXISTE LA DEPENDENCIA INVERSA: SE FORMARIA UN CICLO.', 16, 1) RETURN -1 END

BEGIN TRANSACTION
    INSERT INTO [dbo].[Checklist_Item_Dependencia]
        (cid_checklist_plantilla_item, cid_item_condicion, cid_operador_comparacion,
         cid_valor_comparacion, cid_checklist_item_opcion, cid_dependencia_accion,
         cid_usuario_creacion, cid_fecha_creacion, cid_habilitado)
    VALUES
        (@ITEM, @CONDICION, @OPERADOR, @VALOR, @OPCION, @ACCION, @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()
    IF @@ROWCOUNT = 0
    BEGIN ROLLBACK TRANSACTION RAISERROR('6.- NO FUE POSIBLE CREAR LA DEPENDENCIA.', 16, 1) RETURN -1 END
COMMIT TRANSACTION
RETURN 0
GO


-- ---------------------------------------------------------------------------
-- 3) UPD_CHECKLIST_ITEM_DEPENDENCIA - edicion (la ficha manda el estado completo)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_ITEM_DEPENDENCIA]
@ID          INT,
@CONDICION   INT,
@OPERADOR    INT,
@VALOR       NVARCHAR(400) = NULL,
@OPCION      INT = NULL,
@ACCION      INT,
@HABILITADO  BIT = 1,
@USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @ITEM INT
SELECT @ITEM = cid_checklist_plantilla_item FROM [dbo].[Checklist_Item_Dependencia] WHERE cid_id = @ID
IF @ITEM IS NULL
BEGIN RAISERROR('1.- LA DEPENDENCIA NO EXISTE.', 16, 1) RETURN -1 END

-- CA-2 tambien al editar: no puede quedar dependiendo de si mismo.
IF @ITEM = @CONDICION
BEGIN RAISERROR('2.- UN ITEM NO PUEDE DEPENDER DE SI MISMO.', 16, 1) RETURN -1 END

UPDATE [dbo].[Checklist_Item_Dependencia]
SET cid_item_condicion          = @CONDICION,
    cid_operador_comparacion    = @OPERADOR,
    cid_valor_comparacion       = @VALOR,
    cid_checklist_item_opcion   = @OPCION,
    cid_dependencia_accion      = @ACCION,
    cid_habilitado              = ISNULL(@HABILITADO,1),
    cid_usuario_actualizacion   = @USUARIO,
    cid_fecha_actualizacion     = GETDATE()
WHERE cid_id = @ID

RETURN 0
GO


-- ---------------------------------------------------------------------------
-- 4) DEL_CHECKLIST_ITEM_DEPENDENCIA - baja logica
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_CHECKLIST_ITEM_DEPENDENCIA]
@ID       INT,
@USUARIO  INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Dependencia] WHERE cid_id = @ID)
BEGIN RAISERROR('1.- LA DEPENDENCIA NO EXISTE.', 16, 1) RETURN -1 END

UPDATE [dbo].[Checklist_Item_Dependencia]
SET cid_habilitado = 0, cid_usuario_actualizacion = @USUARIO, cid_fecha_actualizacion = GETDATE()
WHERE cid_id = @ID

RETURN 0
GO

PRINT '309_CHECKLIST_ITEM_DEPENDENCIA_SP aplicado.'
GO
