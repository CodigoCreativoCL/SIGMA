/* ============================================================================
   315 - GET_CHECKLIST_BORRADOR: al crear el borrador, CLONAR la version publicada
   ----------------------------------------------------------------------------
   Problema: al abrir "Crear/editar borrador" en una pauta ya publicada, el
   borrador nacia VACIO (el SP solo insertaba la fila de version). El usuario
   esperaba editar lo existente, no rearmar desde cero.

   Solucion: cuando se crea un borrador nuevo (@CREAR=1 y no hay borrador), si
   existe una version PUBLICADA (estado 2), se copian a la nueva version sus
   secciones, items, opciones, umbrales (validaciones) y dependencias, mapeando
   los IDs viejos a los nuevos con MERGE ... OUTPUT.

   Idempotente: si ya existe un borrador, lo devuelve tal cual (no reclona).
   Si no hay version publicada (pauta nueva), el borrador queda vacio.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[GET_CHECKLIST_BORRADOR]
@PLANTILLA  INT,
@USUARIO    INT,
@CREAR      BIT = 1,               -- 0 = solo lectura (no crea el borrador al abrir)
@VERSION    INT = NULL OUTPUT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT

SELECT @CLIENTE = cpl_cliente FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @PLANTILLA
IF @CLIENTE IS NULL
BEGIN RAISERROR('1.- LA PLANTILLA NO EXISTE.', 16, 1) RETURN -1 END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

-- Ya existe un borrador? Se devuelve ese (no se reclona).
SELECT TOP 1 @VERSION = cpv_id
FROM   [dbo].[Checklist_Plantilla_Version]
WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 1  -- BORRADOR
ORDER BY cpv_numero DESC

IF @VERSION IS NOT NULL OR @CREAR = 0
BEGIN
    SELECT @VERSION AS VERSION
    RETURN
END

BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @NUM INT
    SELECT @NUM = ISNULL(MAX(cpv_numero), 0) + 1 FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @PLANTILLA

    INSERT [dbo].[Checklist_Plantilla_Version]
        (cpv_checklist_plantilla, cpv_numero, cpv_checklist_version_estado,
         cpv_usuario_creacion, cpv_fecha_creacion, cpv_usuario_actualizacion, cpv_fecha_actualizacion, cpv_habilitado)
    VALUES
        (@PLANTILLA, @NUM, 1, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
    SET @VERSION = SCOPE_IDENTITY()

    -- Version publicada mas reciente a clonar.
    DECLARE @PUB INT
    SELECT TOP 1 @PUB = cpv_id
    FROM   [dbo].[Checklist_Plantilla_Version]
    WHERE  cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 2  -- PUBLICADA
    ORDER BY cpv_numero DESC

    IF @PUB IS NOT NULL
    BEGIN
        -- 1) SECCIONES  (mapeo old -> new)
        DECLARE @mapSec TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Plantilla_Seccion] AS T
        USING (SELECT cps_id, cps_codigo, cps_nombre, cps_orden
               FROM   [dbo].[Checklist_Plantilla_Seccion]
               WHERE  cps_checklist_plantilla_version = @PUB AND cps_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cps_checklist_plantilla_version, cps_codigo, cps_nombre, cps_orden,
                    cps_usuario_creacion, cps_fecha_creacion, cps_usuario_actualizacion, cps_fecha_actualizacion, cps_habilitado)
            VALUES (@VERSION, S.cps_codigo, S.cps_nombre, S.cps_orden,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cps_id, inserted.cps_id INTO @mapSec (old, new);

        -- 2) ITEMS  (remapea seccion; mapeo old -> new)
        DECLARE @mapItem TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Plantilla_Item] AS T
        USING (SELECT i.cpi_id, ms.new AS new_sec, i.cpi_codigo, i.cpi_texto, i.cpi_ayuda,
                      i.cpi_checklist_item_tipo, i.cpi_orden, i.cpi_obligatorio, i.cpi_permite_comentario,
                      i.cpi_requiere_evidencia, i.cpi_unidad_medida, i.cpi_genera_medicion, i.cpi_activo_variable
               FROM   [dbo].[Checklist_Plantilla_Item] i
               LEFT JOIN @mapSec ms ON ms.old = i.cpi_checklist_plantilla_seccion
               WHERE  i.cpi_checklist_plantilla_version = @PUB AND i.cpi_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cpi_checklist_plantilla_version, cpi_checklist_plantilla_seccion, cpi_codigo, cpi_texto, cpi_ayuda,
                    cpi_checklist_item_tipo, cpi_orden, cpi_obligatorio, cpi_permite_comentario, cpi_requiere_evidencia,
                    cpi_unidad_medida, cpi_genera_medicion, cpi_activo_variable,
                    cpi_usuario_creacion, cpi_fecha_creacion, cpi_usuario_actualizacion, cpi_fecha_actualizacion, cpi_habilitado)
            VALUES (@VERSION, S.new_sec, S.cpi_codigo, S.cpi_texto, S.cpi_ayuda,
                    S.cpi_checklist_item_tipo, S.cpi_orden, S.cpi_obligatorio, S.cpi_permite_comentario, S.cpi_requiere_evidencia,
                    S.cpi_unidad_medida, S.cpi_genera_medicion, S.cpi_activo_variable,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cpi_id, inserted.cpi_id INTO @mapItem (old, new);

        -- 3) OPCIONES  (mapeo old -> new, necesario para dependencias por opcion)
        DECLARE @mapOp TABLE (old INT PRIMARY KEY, new INT)
        MERGE [dbo].[Checklist_Item_Opcion] AS T
        USING (SELECT o.cio_id, mi.new AS new_item, o.cio_codigo, o.cio_texto, o.cio_valor, o.cio_orden,
                      o.cio_es_conforme, o.cio_severidad, o.cio_requiere_comentario, o.cio_requiere_evidencia
               FROM   [dbo].[Checklist_Item_Opcion] o
               JOIN   @mapItem mi ON mi.old = o.cio_checklist_plantilla_item
               WHERE  o.cio_habilitado = 1) AS S
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (cio_checklist_plantilla_item, cio_codigo, cio_texto, cio_valor, cio_orden,
                    cio_es_conforme, cio_severidad, cio_requiere_comentario, cio_requiere_evidencia,
                    cio_usuario_creacion, cio_fecha_creacion, cio_usuario_actualizacion, cio_fecha_actualizacion, cio_habilitado)
            VALUES (S.new_item, S.cio_codigo, S.cio_texto, S.cio_valor, S.cio_orden,
                    S.cio_es_conforme, S.cio_severidad, S.cio_requiere_comentario, S.cio_requiere_evidencia,
                    @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)
        OUTPUT S.cio_id, inserted.cio_id INTO @mapOp (old, new);

        -- 4) UMBRALES / VALIDACIONES  (1:1 por item)
        INSERT [dbo].[Checklist_Item_Validacion]
            (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_valor_advertencia, civ_valor_critico,
             civ_largo_minimo, civ_largo_maximo, civ_expresion_regular, civ_unidad_medida,
             civ_requiere_comentario_fuera_rango, civ_requiere_evidencia_fuera_rango, civ_genera_alerta, civ_genera_hallazgo, civ_mensaje,
             civ_usuario_creacion, civ_fecha_creacion, civ_usuario_actualizacion, civ_fecha_actualizacion, civ_habilitado)
        SELECT mi.new, v.civ_valor_minimo, v.civ_valor_maximo, v.civ_valor_advertencia, v.civ_valor_critico,
               v.civ_largo_minimo, v.civ_largo_maximo, v.civ_expresion_regular, v.civ_unidad_medida,
               v.civ_requiere_comentario_fuera_rango, v.civ_requiere_evidencia_fuera_rango, v.civ_genera_alerta, v.civ_genera_hallazgo, v.civ_mensaje,
               @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Checklist_Item_Validacion] v
        JOIN   @mapItem mi ON mi.old = v.civ_checklist_plantilla_item
        WHERE  v.civ_habilitado = 1;

        -- 5) DEPENDENCIAS  (remapea item, condicion y opcion)
        INSERT [dbo].[Checklist_Item_Dependencia]
            (cid_checklist_plantilla_item, cid_item_condicion, cid_operador_comparacion, cid_valor_comparacion,
             cid_checklist_item_opcion, cid_dependencia_accion,
             cid_usuario_creacion, cid_fecha_creacion, cid_usuario_actualizacion, cid_fecha_actualizacion, cid_habilitado)
        SELECT mi.new, mc.new, d.cid_operador_comparacion, d.cid_valor_comparacion,
               mo.new, d.cid_dependencia_accion,
               @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1
        FROM   [dbo].[Checklist_Item_Dependencia] d
        JOIN   @mapItem mi ON mi.old = d.cid_checklist_plantilla_item
        JOIN   @mapItem mc ON mc.old = d.cid_item_condicion
        LEFT JOIN @mapOp mo ON mo.old = d.cid_checklist_item_opcion
        WHERE  d.cid_habilitado = 1;
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(2000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'GET_CHECKLIST_BORRADOR', @MSG = @MSG
    SET @VERSION = NULL
    RETURN -1
END CATCH

SELECT @VERSION AS VERSION
GO
