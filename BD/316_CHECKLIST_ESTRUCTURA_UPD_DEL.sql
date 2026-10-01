/* ============================================================================
   316 - Guardado NO destructivo de la estructura del borrador
   ----------------------------------------------------------------------------
   Antes, guardar la estructura hacia LIMPIAR_CHECKLIST_BORRADOR (borra todo) y
   reinsertaba: se perdian opciones, umbrales (validaciones) y dependencias.

   Ahora el controller reconcilia por ID usando estos SPs:
     - UPD_CHECKLIST_SECCION / UPD_CHECKLIST_ITEM  -> actualizan lo existente
     - DEL_CHECKLIST_SECCION / DEL_CHECKLIST_ITEM  -> baja logica (habilitado=0)
       con cascada a opciones, validaciones y dependencias del/los item(s).
   Los INS_* existentes se siguen usando para lo nuevo.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ---- UPD_CHECKLIST_SECCION ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_SECCION]
@ID       INT,
@NOMBRE   NVARCHAR(200),
@ORDEN    INT = 1,
@USUARIO  INT
AS
SET NOCOUNT ON
    UPDATE [dbo].[Checklist_Plantilla_Seccion]
    SET    cps_nombre = @NOMBRE,
           cps_orden  = @ORDEN,
           cps_usuario_actualizacion = @USUARIO,
           cps_fecha_actualizacion   = GETDATE()
    WHERE  cps_id = @ID
RETURN(0)
GO

/* ---- UPD_CHECKLIST_ITEM  (no toca permite_comentario/requiere_evidencia) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CHECKLIST_ITEM]
@ID           INT,
@SECCION      INT = NULL,
@TEXTO        NVARCHAR(500),
@TIPO         INT,
@ORDEN        INT = 1,
@OBLIGATORIO  BIT = 1,
@UNIDAD       INT = NULL,
@USUARIO      INT
AS
SET NOCOUNT ON
    UPDATE [dbo].[Checklist_Plantilla_Item]
    SET    cpi_checklist_plantilla_seccion = @SECCION,
           cpi_texto                       = @TEXTO,
           cpi_checklist_item_tipo         = @TIPO,
           cpi_orden                       = @ORDEN,
           cpi_obligatorio                 = @OBLIGATORIO,
           cpi_unidad_medida               = @UNIDAD,
           cpi_usuario_actualizacion       = @USUARIO,
           cpi_fecha_actualizacion         = GETDATE()
    WHERE  cpi_id = @ID
RETURN(0)
GO

/* ---- DEL_CHECKLIST_ITEM  (baja logica + cascada) ---- */
CREATE OR ALTER PROCEDURE [dbo].[DEL_CHECKLIST_ITEM]
@ID       INT,
@USUARIO  INT
AS
SET NOCOUNT ON
DECLARE @N DATETIME = GETDATE()

    -- dependencias donde el item participa (como objetivo o como condicion)
    UPDATE [dbo].[Checklist_Item_Dependencia]
    SET    cid_habilitado = 0, cid_usuario_actualizacion = @USUARIO, cid_fecha_actualizacion = @N
    WHERE  (cid_checklist_plantilla_item = @ID OR cid_item_condicion = @ID) AND cid_habilitado = 1

    UPDATE [dbo].[Checklist_Item_Opcion]
    SET    cio_habilitado = 0, cio_usuario_actualizacion = @USUARIO, cio_fecha_actualizacion = @N
    WHERE  cio_checklist_plantilla_item = @ID AND cio_habilitado = 1

    UPDATE [dbo].[Checklist_Item_Validacion]
    SET    civ_habilitado = 0, civ_usuario_actualizacion = @USUARIO, civ_fecha_actualizacion = @N
    WHERE  civ_checklist_plantilla_item = @ID AND civ_habilitado = 1

    UPDATE [dbo].[Checklist_Plantilla_Item]
    SET    cpi_habilitado = 0, cpi_usuario_actualizacion = @USUARIO, cpi_fecha_actualizacion = @N
    WHERE  cpi_id = @ID
RETURN(0)
GO

/* ---- DEL_CHECKLIST_SECCION  (baja logica de la seccion, sus items y todo lo colgado) ---- */
CREATE OR ALTER PROCEDURE [dbo].[DEL_CHECKLIST_SECCION]
@ID       INT,
@USUARIO  INT
AS
SET NOCOUNT ON
DECLARE @N DATETIME = GETDATE()

    DECLARE @items TABLE (id INT PRIMARY KEY)
    INSERT @items (id)
    SELECT cpi_id FROM [dbo].[Checklist_Plantilla_Item]
    WHERE  cpi_checklist_plantilla_seccion = @ID AND cpi_habilitado = 1

    UPDATE d
    SET    cid_habilitado = 0, cid_usuario_actualizacion = @USUARIO, cid_fecha_actualizacion = @N
    FROM   [dbo].[Checklist_Item_Dependencia] d
    WHERE  (d.cid_checklist_plantilla_item IN (SELECT id FROM @items)
        OR  d.cid_item_condicion           IN (SELECT id FROM @items)) AND d.cid_habilitado = 1

    UPDATE o
    SET    cio_habilitado = 0, cio_usuario_actualizacion = @USUARIO, cio_fecha_actualizacion = @N
    FROM   [dbo].[Checklist_Item_Opcion] o
    WHERE  o.cio_checklist_plantilla_item IN (SELECT id FROM @items) AND o.cio_habilitado = 1

    UPDATE v
    SET    civ_habilitado = 0, civ_usuario_actualizacion = @USUARIO, civ_fecha_actualizacion = @N
    FROM   [dbo].[Checklist_Item_Validacion] v
    WHERE  v.civ_checklist_plantilla_item IN (SELECT id FROM @items) AND v.civ_habilitado = 1

    UPDATE [dbo].[Checklist_Plantilla_Item]
    SET    cpi_habilitado = 0, cpi_usuario_actualizacion = @USUARIO, cpi_fecha_actualizacion = @N
    WHERE  cpi_checklist_plantilla_seccion = @ID AND cpi_habilitado = 1

    UPDATE [dbo].[Checklist_Plantilla_Seccion]
    SET    cps_habilitado = 0, cps_usuario_actualizacion = @USUARIO, cps_fecha_actualizacion = @N
    WHERE  cps_id = @ID
RETURN(0)
GO
