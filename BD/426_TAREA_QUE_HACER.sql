/* ============================================================================
   426 · Tarea recurrente: categoría nueva, qué hacer con procedimiento o pasos, fotos (09-10-2026)
   Pedido del cliente al probar «Nueva tarea»:
     · Categoría: crearla desde el mismo combo (UPS_TAREA_CATEGORIA_NOMBRE: la existente o una nueva).
     · «Dónde»: ver la foto del activo, subactivo o componente → SEL_PLAN_PROGRAMA_CATALOGO trae FOTO
       (Archivo_Vinculo de imagen, la de referencia primero) y TIPO_ID del activo.
     · «Qué hacer»: adjuntar un procedimiento ya creado (sugiere los del tipo del activo) o escribir pasos.
       Tarea.tar_procedimiento, Tarea_Paso, UPS_TAREA_QUE_HACER, SEL_TAREA_QUE_HACER.
       SEL_PLAN_PROGRAMA_CATALOGO + conjunto 6: procedimientos.
   Aplicar DESPUÉS de 408. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF COL_LENGTH('dbo.Tarea', 'tar_procedimiento') IS NULL ALTER TABLE [dbo].[Tarea] ADD tar_procedimiento INT NULL
GO
IF OBJECT_ID('dbo.Tarea_Paso') IS NULL
CREATE TABLE [dbo].[Tarea_Paso] (
    tpa_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TAREA_PASO PRIMARY KEY,
    tpa_tarea INT NOT NULL CONSTRAINT FK_TPA_TAREA REFERENCES [dbo].[Tarea](tar_id),
    tpa_orden INT NOT NULL,
    tpa_nombre NVARCHAR(300) NOT NULL,
    tpa_usuario_creacion INT NULL, tpa_fecha_creacion DATETIME NULL,
    tpa_habilitado BIT NOT NULL CONSTRAINT DF_TPA_HAB DEFAULT 1)
GO
CREATE OR ALTER PROCEDURE [dbo].[UPS_TAREA_CATEGORIA_NOMBRE]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(200),
    @USUARIO INT
AS
SET NOCOUNT ON
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
IF LEN(@NOMBRE) < 3 BEGIN RAISERROR('1.- LA CATEGORÍA NECESITA UN NOMBRE DE AL MENOS 3 LETRAS.', 16, 1) RETURN -1 END
SELECT TOP 1 @ID = tca_id FROM [dbo].[Tarea_Categoria] WHERE (tca_cliente = @CLIENTE OR tca_cliente IS NULL) AND tca_nombre = @NOMBRE COLLATE Latin1_General_CI_AI ORDER BY tca_habilitado DESC
IF @ID IS NOT NULL
BEGIN
    UPDATE [dbo].[Tarea_Categoria] SET tca_habilitado = 1 WHERE tca_id = @ID AND tca_habilitado = 0
    SELECT @ID AS ID RETURN 0
END
EXEC [dbo].[UPS_RECURSOS_AJUSTE] @CLIENTE = @CLIENTE, @TIPO = 'CAT', @ACCION = 'ADD', @ID = NULL, @NOMBRE = @NOMBRE, @USUARIO = @USUARIO
SELECT TOP 1 @ID = tca_id FROM [dbo].[Tarea_Categoria] WHERE tca_cliente = @CLIENTE AND tca_nombre = @NOMBRE COLLATE Latin1_General_CI_AI
SELECT @ID AS ID
RETURN 0
GO
CREATE OR ALTER PROCEDURE [dbo].[UPS_TAREA_QUE_HACER]
    @CLIENTE       INT,
    @TAREA         INT,
    @PROCEDIMIENTO INT = NULL,
    @PASOS         NVARCHAR(MAX) = NULL,   -- JSON: ["Revisar presión", "Limpiar filtro"]
    @USUARIO       INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_id = @TAREA AND tar_cliente = @CLIENTE)
BEGIN RAISERROR('1.- LA TAREA NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END
IF @PROCEDIMIENTO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Procedimiento] WHERE prc_id = @PROCEDIMIENTO AND (prc_cliente = @CLIENTE OR prc_cliente IS NULL) AND prc_habilitado = 1)
BEGIN RAISERROR('2.- EL PROCEDIMIENTO NO EXISTE.', 16, 1) RETURN -1 END
BEGIN TRANSACTION
    UPDATE [dbo].[Tarea] SET tar_procedimiento = @PROCEDIMIENTO, tar_usuario_actualizacion = @USUARIO, tar_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE tar_id = @TAREA
    UPDATE [dbo].[Tarea_Paso] SET tpa_habilitado = 0 WHERE tpa_tarea = @TAREA AND tpa_habilitado = 1
    IF ISJSON(@PASOS) = 1
        INSERT [dbo].[Tarea_Paso] (tpa_tarea, tpa_orden, tpa_nombre, tpa_usuario_creacion, tpa_fecha_creacion, tpa_habilitado)
        SELECT @TAREA, CAST(j.[key] AS INT) + 1, LEFT(LTRIM(RTRIM(j.value)), 300), @USUARIO, [dbo].[FNC_AHORA](), 1
        FROM OPENJSON(@PASOS) j WHERE LTRIM(RTRIM(ISNULL(j.value, N''))) <> N''
COMMIT TRANSACTION
RETURN 0
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_QUE_HACER]
    @CLIENTE INT,
    @TAREA   INT
AS
SET NOCOUNT ON
SELECT  p.prc_id AS ID, p.prc_codigo AS CODIGO, p.prc_nombre AS NOMBRE, p.prc_version AS VERSION,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1) AS PASOS
FROM    [dbo].[Tarea] t JOIN [dbo].[Procedimiento] p ON p.prc_id = t.tar_procedimiento
WHERE   t.tar_id = @TAREA AND t.tar_cliente = @CLIENTE
SELECT  tpa_orden AS ORDEN, tpa_nombre AS NOMBRE FROM [dbo].[Tarea_Paso] WHERE tpa_tarea = @TAREA AND tpa_habilitado = 1 ORDER BY tpa_orden
RETURN 0
GO

/* Combos de los cajones. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_PROGRAMA_CATALOGO]
    @CLIENTE INT
AS
SET NOCOUNT ON
/* 0 · activos (con su área desglosada y su padre: un activo con padre es un subactivo) */
SELECT  a.act_id AS ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, a.act_cliente_instalacion AS PLANTA_ID,
        a.act_instalacion_area AS AREA_ID, ISNULL(ISNULL(ap.iar_nombre + N' › ', N'') + ia.iar_nombre, N'Sin área') AS AREA,
        ISNULL(t.ati_nombre, N'') AS TIPO, a.act_activo_padre AS PADRE_ID, ISNULL(a.act_criticidad_nivel, 0) AS CRITICIDAD,
        a.act_activo_tipo AS TIPO_ID, (SELECT TOP 1 av.avi_archivo FROM [dbo].[Archivo_Vinculo] av JOIN [dbo].[Archivo] ar ON ar.arc_id = av.avi_archivo
          WHERE av.avi_activo = a.act_id AND av.avi_activo_componente IS NULL AND av.avi_habilitado = 1 AND ar.arc_mime LIKE 'image/%'
          ORDER BY av.avi_es_referencia DESC, av.avi_id DESC) AS FOTO
FROM    [dbo].[Activo] a
LEFT JOIN [dbo].[Instalacion_Area] ia ON ia.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Instalacion_Area] ap ON ap.iar_id = ia.iar_area_padre
LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
WHERE   a.act_cliente = @CLIENTE AND a.act_habilitado = 1
ORDER BY AREA, a.act_codigo
/* 1 · componentes */
SELECT  c.aco_id AS ID, c.aco_activo AS ACTIVO_ID, c.aco_nombre AS NOMBRE, c.aco_componente_padre AS PADRE_ID,
        (SELECT TOP 1 av.avi_archivo FROM [dbo].[Archivo_Vinculo] av JOIN [dbo].[Archivo] ar ON ar.arc_id = av.avi_archivo
          WHERE av.avi_activo_componente = c.aco_id AND av.avi_habilitado = 1 AND ar.arc_mime LIKE 'image/%' ORDER BY av.avi_es_referencia DESC, av.avi_id DESC) AS FOTO
FROM    [dbo].[Activo_Componente] c JOIN [dbo].[Activo] a ON a.act_id = c.aco_activo
WHERE   a.act_cliente = @CLIENTE AND c.aco_habilitado = 1 AND c.aco_fusionado_en IS NULL
ORDER BY c.aco_activo, c.aco_nombre
/* 2 · pautas publicadas */
SELECT  p.cpl_id AS ID, p.cpl_codigo AS CODIGO, p.cpl_nombre AS NOMBRE, v.cpv_numero AS VERSION,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i WHERE i.cpi_checklist_plantilla_version = v.cpv_id AND i.cpi_habilitado = 1) AS ITEMS
FROM    [dbo].[Checklist_Plantilla] p
CROSS APPLY (SELECT TOP 1 cpv_id, cpv_numero FROM [dbo].[Checklist_Plantilla_Version] x WHERE x.cpv_checklist_plantilla = p.cpl_id AND x.cpv_checklist_version_estado = 2 AND x.cpv_habilitado = 1 ORDER BY x.cpv_numero DESC) v
WHERE   p.cpl_cliente = @CLIENTE AND p.cpl_habilitado = 1
ORDER BY p.cpl_codigo
/* 3 · categorías de tarea */
SELECT  tca_id AS ID, tca_nombre AS NOMBRE, ISNULL(tca_color, N'#68738A') AS COLOR
FROM    [dbo].[Tarea_Categoria] WHERE (tca_cliente = @CLIENTE OR tca_cliente IS NULL) AND tca_habilitado = 1
ORDER BY ISNULL(tca_orden, 999), tca_nombre
/* 4 · calendarios compartidos (programaciones no privadas por fechas) */
SELECT  p.pro_id AS ID, p.pro_nombre AS NOMBRE, t.pti_nombre AS TIPO
FROM    [dbo].[Programacion] p JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
WHERE   p.pro_cliente = @CLIENTE AND p.pro_habilitado = 1 AND ISNULL(p.pro_es_privada, 0) = 0 AND t.pti_codigo IN ('CALENDARIO', 'INTERVALO TIEMPO', 'FECHA UNICA')
ORDER BY p.pro_nombre
/* 5 · en qué inspecciones está cada activo (el selector avisa «En INS-00x», como el mockup) */
SELECT DISTINCT cp.cpr_activo AS ACTIVO_ID, cp.cpr_inspeccion AS INSPECCION, N'INS-' + RIGHT(N'000' + CAST(cp.cpr_inspeccion AS NVARCHAR(10)), 3) AS CODIGO, cp.cpr_nombre AS NOMBRE
FROM    [dbo].[Checklist_Programacion] cp
WHERE   cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1 AND cp.cpr_activo IS NOT NULL
/* 6 · 426 · procedimientos para «Qué hacer» de la tarea (con su tipo de activo, para sugerir los del activo elegido) */
SELECT  p.prc_id AS ID, p.prc_codigo AS CODIGO, p.prc_nombre AS NOMBRE, p.prc_version AS VERSION, p.prc_activo_tipo AS ACTIVO_TIPO_ID,
        ISNULL(ti.ati_nombre, N'') AS TIPO, p.prc_duracion_estimada_minuto AS DURACION,
        (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1) AS PASOS
FROM    [dbo].[Procedimiento] p
LEFT JOIN [dbo].[Activo_Tipo] ti ON ti.ati_id = p.prc_activo_tipo
WHERE   (p.prc_cliente = @CLIENTE OR p.prc_cliente IS NULL) AND p.prc_habilitado = 1
ORDER BY p.prc_codigo
GO
PRINT '426_TAREA_QUE_HACER aplicado.'
GO
