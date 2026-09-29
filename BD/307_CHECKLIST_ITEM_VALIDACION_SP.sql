USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           29-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-091) SP del mantenedor de UMBRALES Y ACCIONES
--                  de un item (Checklist_Item_Validacion): SEL/INS/UPD/DEL.
--
--   Define, por item de una pauta, que valores son normales y que ocurre cuando
--   no lo son: umbrales (minimo/advertencia/critico/maximo), largo y expresion
--   para texto, y las acciones fuera de rango (exigir comentario, exigir
--   evidencia, generar alerta, generar hallazgo) con un mensaje.
--   Hay UNA validacion por item (indice unico UX_CIV_ITEM).
--   La clasificacion en terreno la hace FNC_CHECKLIST_SEVERIDAD con estos valores.
-- =============================================
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_CHECKLIST_ITEM_VALIDACION - listado y ficha (por @ID)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_VALIDACION]
@CLIENTE    INT,
@ID         INT = NULL,
@PLANTILLA  INT = NULL,
@FILTRO     NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  v.civ_id                                   AS CIV_ID,
        v.civ_checklist_plantilla_item             AS ITEM_ID,
        i.cpi_codigo                               AS ITEM_CODIGO,
        i.cpi_texto                                AS ITEM_TEXTO,
        t.cit_codigo                               AS TIPO_CODIGO,
        t.cit_nombre                               AS TIPO_NOMBRE,
        ISNULL(s.cps_nombre, '')                   AS SECCION_NOMBRE,
        pl.cpl_id                                  AS PLANTILLA_ID,
        pl.cpl_nombre                              AS PLANTILLA_NOMBRE,
        ver.cpv_numero                             AS VERSION_NUMERO,
        v.civ_valor_minimo                         AS VALOR_MINIMO,
        v.civ_valor_maximo                         AS VALOR_MAXIMO,
        v.civ_valor_advertencia                    AS VALOR_ADVERTENCIA,
        v.civ_valor_critico                        AS VALOR_CRITICO,
        v.civ_largo_minimo                         AS LARGO_MINIMO,
        v.civ_largo_maximo                         AS LARGO_MAXIMO,
        v.civ_expresion_regular                    AS EXPRESION_REGULAR,
        v.civ_unidad_medida                        AS UNIDAD_MEDIDA,
        v.civ_requiere_comentario_fuera_rango      AS REQUIERE_COMENTARIO,
        v.civ_requiere_evidencia_fuera_rango       AS REQUIERE_EVIDENCIA,
        v.civ_genera_alerta                        AS GENERA_ALERTA,
        v.civ_genera_hallazgo                      AS GENERA_HALLAZGO,
        ISNULL(v.civ_mensaje, '')                  AS MENSAJE,
        v.civ_habilitado                           AS HABILITADO
FROM    [dbo].[Checklist_Item_Validacion]     v
JOIN    [dbo].[Checklist_Plantilla_Item]      i   ON i.cpi_id  = v.civ_checklist_plantilla_item
JOIN    [dbo].[Checklist_Item_Tipo]           t   ON t.cit_id  = i.cpi_checklist_item_tipo
JOIN    [dbo].[Checklist_Plantilla_Version]   ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]           pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s   ON s.cps_id   = i.cpi_checklist_plantilla_seccion
WHERE   pl.cpl_cliente = @CLIENTE
  AND   (@ID IS NULL OR v.civ_id = @ID)
  AND   (@PLANTILLA IS NULL OR pl.cpl_id = @PLANTILLA)
  -- El listado muestra solo habilitadas; la ficha (por @ID) trae aunque este de baja.
  AND   (@ID IS NOT NULL OR v.civ_habilitado = 1)
  AND   (@FILTRO IS NULL OR @FILTRO = '' OR i.cpi_texto LIKE '%' + @FILTRO + '%' OR i.cpi_codigo LIKE '%' + @FILTRO + '%')
ORDER BY pl.cpl_nombre, s.cps_orden, i.cpi_orden, i.cpi_id
GO


-- ---------------------------------------------------------------------------
-- 2) INS_CHECKLIST_ITEM_VALIDACION - alta (una por item, umbrales coherentes)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_ITEM_VALIDACION]
@ID                   INT = NULL OUTPUT,
@CLIENTE              INT,
@ITEM                 INT,
@VALOR_MINIMO         DECIMAL(18,6) = NULL,
@VALOR_MAXIMO         DECIMAL(18,6) = NULL,
@VALOR_ADVERTENCIA    DECIMAL(18,6) = NULL,
@VALOR_CRITICO        DECIMAL(18,6) = NULL,
@LARGO_MINIMO         INT = NULL,
@LARGO_MAXIMO         INT = NULL,
@EXPRESION_REGULAR    NVARCHAR(400) = NULL,
@UNIDAD_MEDIDA        INT = NULL,
@REQUIERE_COMENTARIO  BIT = 0,
@REQUIERE_EVIDENCIA   BIT = 0,
@GENERA_ALERTA        BIT = 0,
@GENERA_HALLAZGO      BIT = 0,
@MENSAJE              NVARCHAR(400) = NULL,
@USUARIO              INT
AS
SET NOCOUNT ON

-- El item tiene que existir y ser de una pauta de este cliente.
IF NOT EXISTS (SELECT 1
               FROM [dbo].[Checklist_Plantilla_Item] i
               JOIN [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = i.cpi_checklist_plantilla_version
               JOIN [dbo].[Checklist_Plantilla] p ON p.cpl_id = v.cpv_checklist_plantilla
               WHERE i.cpi_id = @ITEM AND p.cpl_cliente = @CLIENTE)
BEGIN RAISERROR('1.- EL ITEM NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1) RETURN -1 END

-- Una validacion por item.
IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] WHERE civ_checklist_plantilla_item = @ITEM AND civ_habilitado = 1)
BEGIN RAISERROR('2.- EL ITEM YA TIENE UNA VALIDACION. EDITE LA EXISTENTE.', 16, 1) RETURN -1 END

-- Umbrales coherentes: minimo <= advertencia <= critico <= maximo (los que vengan).
IF (@VALOR_MINIMO IS NOT NULL AND @VALOR_MAXIMO IS NOT NULL AND @VALOR_MINIMO > @VALOR_MAXIMO)
BEGIN RAISERROR('3.- EL MINIMO NO PUEDE SER MAYOR QUE EL MAXIMO.', 16, 1) RETURN -1 END
IF (@VALOR_ADVERTENCIA IS NOT NULL AND @VALOR_CRITICO IS NOT NULL AND @VALOR_ADVERTENCIA > @VALOR_CRITICO)
BEGIN RAISERROR('4.- LA ADVERTENCIA NO PUEDE SER MAYOR QUE EL CRITICO.', 16, 1) RETURN -1 END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Checklist_Item_Validacion]
        (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_valor_advertencia, civ_valor_critico,
         civ_largo_minimo, civ_largo_maximo, civ_expresion_regular, civ_unidad_medida,
         civ_requiere_comentario_fuera_rango, civ_requiere_evidencia_fuera_rango, civ_genera_alerta, civ_genera_hallazgo,
         civ_mensaje, civ_usuario_creacion, civ_fecha_creacion, civ_habilitado)
    VALUES
        (@ITEM, @VALOR_MINIMO, @VALOR_MAXIMO, @VALOR_ADVERTENCIA, @VALOR_CRITICO,
         @LARGO_MINIMO, @LARGO_MAXIMO, @EXPRESION_REGULAR, @UNIDAD_MEDIDA,
         ISNULL(@REQUIERE_COMENTARIO,0), ISNULL(@REQUIERE_EVIDENCIA,0), ISNULL(@GENERA_ALERTA,0), ISNULL(@GENERA_HALLAZGO,0),
         @MENSAJE, @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN ROLLBACK TRANSACTION RAISERROR('5.- NO FUE POSIBLE CREAR LA VALIDACION.', 16, 1) RETURN -1 END

COMMIT TRANSACTION
RETURN 0
GO


-- ---------------------------------------------------------------------------
-- 3) UPD_CHECKLIST_ITEM_VALIDACION - edicion (la ficha manda el estado completo)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_ITEM_VALIDACION]
@ID                   INT,
@VALOR_MINIMO         DECIMAL(18,6) = NULL,
@VALOR_MAXIMO         DECIMAL(18,6) = NULL,
@VALOR_ADVERTENCIA    DECIMAL(18,6) = NULL,
@VALOR_CRITICO        DECIMAL(18,6) = NULL,
@LARGO_MINIMO         INT = NULL,
@LARGO_MAXIMO         INT = NULL,
@EXPRESION_REGULAR    NVARCHAR(400) = NULL,
@UNIDAD_MEDIDA        INT = NULL,
@REQUIERE_COMENTARIO  BIT = 0,
@REQUIERE_EVIDENCIA   BIT = 0,
@GENERA_ALERTA        BIT = 0,
@GENERA_HALLAZGO      BIT = 0,
@MENSAJE              NVARCHAR(400) = NULL,
@HABILITADO           BIT = 1,
@USUARIO              INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] WHERE civ_id = @ID)
BEGIN RAISERROR('1.- LA VALIDACION NO EXISTE.', 16, 1) RETURN -1 END

IF (@VALOR_MINIMO IS NOT NULL AND @VALOR_MAXIMO IS NOT NULL AND @VALOR_MINIMO > @VALOR_MAXIMO)
BEGIN RAISERROR('2.- EL MINIMO NO PUEDE SER MAYOR QUE EL MAXIMO.', 16, 1) RETURN -1 END
IF (@VALOR_ADVERTENCIA IS NOT NULL AND @VALOR_CRITICO IS NOT NULL AND @VALOR_ADVERTENCIA > @VALOR_CRITICO)
BEGIN RAISERROR('3.- LA ADVERTENCIA NO PUEDE SER MAYOR QUE EL CRITICO.', 16, 1) RETURN -1 END

-- La ficha refleja el estado completo: se sobrescriben todos los campos.
UPDATE [dbo].[Checklist_Item_Validacion]
SET civ_valor_minimo                     = @VALOR_MINIMO,
    civ_valor_maximo                     = @VALOR_MAXIMO,
    civ_valor_advertencia                = @VALOR_ADVERTENCIA,
    civ_valor_critico                    = @VALOR_CRITICO,
    civ_largo_minimo                     = @LARGO_MINIMO,
    civ_largo_maximo                     = @LARGO_MAXIMO,
    civ_expresion_regular                = @EXPRESION_REGULAR,
    civ_unidad_medida                    = @UNIDAD_MEDIDA,
    civ_requiere_comentario_fuera_rango  = ISNULL(@REQUIERE_COMENTARIO,0),
    civ_requiere_evidencia_fuera_rango   = ISNULL(@REQUIERE_EVIDENCIA,0),
    civ_genera_alerta                    = ISNULL(@GENERA_ALERTA,0),
    civ_genera_hallazgo                  = ISNULL(@GENERA_HALLAZGO,0),
    civ_mensaje                          = @MENSAJE,
    civ_habilitado                       = ISNULL(@HABILITADO,1),
    civ_usuario_actualizacion            = @USUARIO,
    civ_fecha_actualizacion              = GETDATE()
WHERE civ_id = @ID

RETURN 0
GO


-- ---------------------------------------------------------------------------
-- 4) DEL_CHECKLIST_ITEM_VALIDACION - baja logica
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_CHECKLIST_ITEM_VALIDACION]
@ID       INT,
@USUARIO  INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] WHERE civ_id = @ID)
BEGIN RAISERROR('1.- LA VALIDACION NO EXISTE.', 16, 1) RETURN -1 END

UPDATE [dbo].[Checklist_Item_Validacion]
SET civ_habilitado = 0, civ_usuario_actualizacion = @USUARIO, civ_fecha_actualizacion = GETDATE()
WHERE civ_id = @ID

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 5) SEL_CHECKLIST_ITEM_LISTA - items del cliente para el combo de la ficha
--    (con su pauta y si ya tienen validacion, para no ofrecer duplicados).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_ITEM_LISTA]
@CLIENTE INT
AS
SET NOCOUNT ON

SELECT  i.cpi_id                 AS ITEM_ID,
        i.cpi_codigo             AS ITEM_CODIGO,
        i.cpi_texto              AS ITEM_TEXTO,
        t.cit_codigo             AS TIPO_CODIGO,
        t.cit_nombre             AS TIPO_NOMBRE,
        pl.cpl_nombre            AS PLANTILLA_NOMBRE,
        ISNULL(s.cps_nombre, '') AS SECCION_NOMBRE,
        CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Validacion] v
                          WHERE v.civ_checklist_plantilla_item = i.cpi_id AND v.civ_habilitado = 1)
             THEN 1 ELSE 0 END   AS TIENE_VALIDACION
FROM    [dbo].[Checklist_Plantilla_Item]      i
JOIN    [dbo].[Checklist_Item_Tipo]           t   ON t.cit_id   = i.cpi_checklist_item_tipo
JOIN    [dbo].[Checklist_Plantilla_Version]   ver ON ver.cpv_id = i.cpi_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]           pl  ON pl.cpl_id  = ver.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s   ON s.cps_id   = i.cpi_checklist_plantilla_seccion
WHERE   pl.cpl_cliente = @CLIENTE AND i.cpi_habilitado = 1
ORDER BY pl.cpl_nombre, s.cps_orden, i.cpi_orden, i.cpi_id
GO

PRINT '307_CHECKLIST_ITEM_VALIDACION_SP aplicado.'
GO
