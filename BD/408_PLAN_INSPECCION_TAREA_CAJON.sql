/* ============================================================================
   408 · Planificación › cajones «Inspección» y «Tarea recurrente» (mockup PANELS.rone / PANELS.tare)
   09-10-2026. Reemplazan el modal ChecklistProgramacion.aspx y la página Tarea.aspx.

   UNA INSPECCIÓN = UN GRUPO DE FILAS
     Checklist_Programacion es «un activo por fila». Una inspección que recorre N activos son N filas
     con el mismo cpr_inspeccion (el id de la primera) y su orden de recorrido (cpr_orden). Cada fila
     puede apuntar a un objeto mantenible: el activo completo, un subactivo (otro activo con
     act_activo_padre: va en cpr_activo) o un componente (cpr_activo_componente).
   TAREA: tar_activo_componente para el componente (el subactivo va en tar_activo).

   FRECUENCIA: propia (programación privada de tipo CALENDARIO, semanal o mensual, como el mockup)
     o un calendario compartido de Recursos (programación no privada).
   AL CAMBIAR LA FRECUENCIA: las ocurrencias futuras pendientes que ya no calzan con la regla nueva se
     cancelan (estado 6) y GEN_*_OCURRENCIAS agrega las que faltan. Lo hecho y lo en curso no se toca.
   QUIÉN LA EJECUTA (Programa_Asignacion): «Disponible» (nadie asignado: desde la app cualquiera la
     toma), una o varias personas, un grupo de trabajo o una empresa externa. La primera persona y el
     grupo siguen en cpr_/tpr_usuario_responsable y cpr_/tpr_grupo_trabajo (los lee el generador).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.Checklist_Programacion', 'cpr_inspeccion') IS NULL ALTER TABLE [dbo].[Checklist_Programacion] ADD cpr_inspeccion INT NULL
IF COL_LENGTH('dbo.Checklist_Programacion', 'cpr_orden') IS NULL ALTER TABLE [dbo].[Checklist_Programacion] ADD cpr_orden INT NULL
IF COL_LENGTH('dbo.Checklist_Programacion', 'cpr_activo_componente') IS NULL ALTER TABLE [dbo].[Checklist_Programacion] ADD cpr_activo_componente INT NULL
IF COL_LENGTH('dbo.Checklist_Programacion', 'cpr_duracion_minuto') IS NULL ALTER TABLE [dbo].[Checklist_Programacion] ADD cpr_duracion_minuto INT NULL
IF COL_LENGTH('dbo.Tarea', 'tar_activo_componente') IS NULL ALTER TABLE [dbo].[Tarea] ADD tar_activo_componente INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CPR_ACTIVO_COMPONENTE')
    ALTER TABLE [dbo].[Checklist_Programacion] ADD CONSTRAINT FK_CPR_ACTIVO_COMPONENTE FOREIGN KEY (cpr_activo_componente) REFERENCES [dbo].[Activo_Componente] (aco_id)
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_TAR_ACTIVO_COMPONENTE')
    ALTER TABLE [dbo].[Tarea] ADD CONSTRAINT FK_TAR_ACTIVO_COMPONENTE FOREIGN KEY (tar_activo_componente) REFERENCES [dbo].[Activo_Componente] (aco_id)
GO
UPDATE [dbo].[Checklist_Programacion] SET cpr_inspeccion = cpr_id WHERE cpr_inspeccion IS NULL
UPDATE [dbo].[Checklist_Programacion] SET cpr_orden = 1 WHERE cpr_orden IS NULL
GO

IF OBJECT_ID('dbo.Programa_Asignacion', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Programa_Asignacion]
    (
        pas_id               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PROGRAMA_ASIGNACION PRIMARY KEY,
        pas_cliente          INT NOT NULL,
        pas_tipo             VARCHAR(3) NOT NULL,     -- INS (grupo de inspección) · TAR (tarea)
        pas_ref              INT NOT NULL,            -- cpr_inspeccion o tar_id
        pas_usuario          INT NULL,
        pas_grupo_trabajo    INT NULL,
        pas_proveedor        INT NULL,
        pas_orden            INT NOT NULL CONSTRAINT DF_PAS_ORDEN DEFAULT (1),
        pas_usuario_creacion INT NULL,
        pas_fecha_creacion   DATETIME NULL,
        CONSTRAINT FK_PAS_USUARIO FOREIGN KEY (pas_usuario) REFERENCES [dbo].[Usuario] (usu_id),
        CONSTRAINT FK_PAS_GRUPO FOREIGN KEY (pas_grupo_trabajo) REFERENCES [dbo].[Grupo_Trabajo] (gtr_id),
        CONSTRAINT CK_PAS_UNO CHECK ((CASE WHEN pas_usuario IS NULL THEN 0 ELSE 1 END) + (CASE WHEN pas_grupo_trabajo IS NULL THEN 0 ELSE 1 END) + (CASE WHEN pas_proveedor IS NULL THEN 0 ELSE 1 END) = 1)
    )
    CREATE INDEX IX_PAS_REF ON [dbo].[Programa_Asignacion] (pas_tipo, pas_ref)
END
GO

/* La asignación como código para el cajón: «D» disponible · «P:1,5» personas · «G:3» grupo · «E:7» empresa. */
CREATE OR ALTER FUNCTION [dbo].[FNC_PROGRAMA_ASIGNACION](@TIPO VARCHAR(3), @REF INT)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @R NVARCHAR(400)
    SELECT TOP 1 @R = N'E:' + CAST(pas_proveedor AS NVARCHAR(12)) FROM [dbo].[Programa_Asignacion] WHERE pas_tipo = @TIPO AND pas_ref = @REF AND pas_proveedor IS NOT NULL
    IF @R IS NULL SELECT TOP 1 @R = N'G:' + CAST(pas_grupo_trabajo AS NVARCHAR(12)) FROM [dbo].[Programa_Asignacion] WHERE pas_tipo = @TIPO AND pas_ref = @REF AND pas_grupo_trabajo IS NOT NULL
    IF @R IS NULL SELECT @R = N'P:' + STUFF((SELECT N',' + CAST(pas_usuario AS NVARCHAR(12)) FROM [dbo].[Programa_Asignacion] WHERE pas_tipo = @TIPO AND pas_ref = @REF AND pas_usuario IS NOT NULL ORDER BY pas_orden FOR XML PATH('')), 1, 1, N'')
    RETURN ISNULL(@R, N'D')
END
GO

/* En palabras para la lista: «Disponible», «Grupo Mecánicos», «Externa · Frío Sur», «Ana Pérez +2». */
CREATE OR ALTER FUNCTION [dbo].[FNC_PROGRAMA_ASIGNACION_TEXTO](@TIPO VARCHAR(3), @REF INT)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @R NVARCHAR(400), @N INT
    SELECT TOP 1 @R = N'Externa · ' + ISNULL(pr.prv_razon_social, N'') FROM [dbo].[Programa_Asignacion] a LEFT JOIN [dbo].[Proveedor] pr ON pr.prv_id = a.pas_proveedor WHERE a.pas_tipo = @TIPO AND a.pas_ref = @REF AND a.pas_proveedor IS NOT NULL
    IF @R IS NULL SELECT TOP 1 @R = N'Grupo · ' + ISNULL(g.gtr_nombre, N'') FROM [dbo].[Programa_Asignacion] a LEFT JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = a.pas_grupo_trabajo WHERE a.pas_tipo = @TIPO AND a.pas_ref = @REF AND a.pas_grupo_trabajo IS NOT NULL
    IF @R IS NULL
    BEGIN
        SELECT @N = COUNT(*) FROM [dbo].[Programa_Asignacion] WHERE pas_tipo = @TIPO AND pas_ref = @REF AND pas_usuario IS NOT NULL
        IF @N > 0 SELECT TOP 1 @R = LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) + CASE WHEN @N > 1 THEN N' +' + CAST(@N - 1 AS NVARCHAR(5)) ELSE N'' END
                      FROM [dbo].[Programa_Asignacion] a JOIN [dbo].[Usuario] u ON u.usu_id = a.pas_usuario WHERE a.pas_tipo = @TIPO AND a.pas_ref = @REF AND a.pas_usuario IS NOT NULL ORDER BY a.pas_orden
    END
    RETURN ISNULL(@R, N'Disponible')
END
GO

/* Reemplaza la asignación de una inspección o tarea y deja la primera persona y el grupo en sus columnas. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMA_ASIGNACION]
    @CLIENTE    INT,
    @TIPO       VARCHAR(3),
    @REF        INT,
    @ASIGNACION NVARCHAR(400),
    @USUARIO    INT
AS
SET NOCOUNT ON
DECLARE @M CHAR(1) = LEFT(LTRIM(ISNULL(@ASIGNACION, N'D')), 1), @L NVARCHAR(400) = SUBSTRING(ISNULL(@ASIGNACION, N''), 3, 400), @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF @M NOT IN ('D', 'P', 'G', 'E') SET @M = 'D'
DECLARE @IDS TABLE (orden INT IDENTITY(1,1), id INT)
INSERT @IDS (id) SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@L, ',') WHERE TRY_CAST(value AS INT) > 0
IF @M <> 'D' AND NOT EXISTS (SELECT 1 FROM @IDS) BEGIN RAISERROR('1.- ELIGE A QUIEN SE ASIGNA O DEJALA DISPONIBLE.', 16, 1) RETURN -1 END
IF @M = 'P' AND EXISTS (SELECT 1 FROM @IDS i LEFT JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = i.id AND cu.ucl_id_cliente = @CLIENTE WHERE cu.ucl_id_usuario IS NULL)
BEGIN RAISERROR('2.- UNA PERSONA NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END
IF @M = 'G' AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo] g JOIN @IDS i ON i.id = g.gtr_id WHERE g.gtr_cliente = @CLIENTE)
BEGIN RAISERROR('3.- EL GRUPO NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END

DELETE FROM [dbo].[Programa_Asignacion] WHERE pas_tipo = @TIPO AND pas_ref = @REF AND pas_cliente = @CLIENTE
INSERT [dbo].[Programa_Asignacion] (pas_cliente, pas_tipo, pas_ref, pas_usuario, pas_grupo_trabajo, pas_proveedor, pas_orden, pas_usuario_creacion, pas_fecha_creacion)
SELECT @CLIENTE, @TIPO, @REF, CASE WHEN @M = 'P' THEN i.id END, CASE WHEN @M = 'G' THEN i.id END, CASE WHEN @M = 'E' THEN i.id END, i.orden, @USUARIO, @AHORA
FROM @IDS i WHERE @M <> 'D' AND (@M = 'P' OR i.orden = 1)

DECLARE @RESP INT = CASE WHEN @M = 'P' THEN (SELECT id FROM @IDS WHERE orden = 1) END, @GRP INT = CASE WHEN @M = 'G' THEN (SELECT id FROM @IDS WHERE orden = 1) END
IF @TIPO = 'INS'
    UPDATE [dbo].[Checklist_Programacion] SET cpr_usuario_responsable = @RESP, cpr_grupo_trabajo = @GRP, cpr_usuario_actualizacion = @USUARIO, cpr_fecha_actualizacion = @AHORA
    WHERE cpr_inspeccion = @REF AND cpr_cliente = @CLIENTE
ELSE
    UPDATE [dbo].[Tarea_Programacion] SET tpr_usuario_responsable = @RESP, tpr_grupo_trabajo = @GRP, tpr_usuario_actualizacion = @USUARIO, tpr_fecha_actualizacion = @AHORA
    WHERE tpr_tarea = @REF AND tpr_habilitado = 1
GO

/* La frecuencia en palabras, como el mockup: «Semanal · lun, jue · 08:00», «Mensual · día 5 · 08:00»;
   un calendario compartido se nombra por su nombre. */
CREATE OR ALTER FUNCTION [dbo].[FNC_PROGRAMACION_TEXTO](@PRO INT)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @R NVARCHAR(400), @PRIV BIT, @NOM NVARCHAR(400), @TIPO NVARCHAR(50), @FRE NVARCHAR(50), @INT INT, @DM INT, @ORD INT, @HORA TIME, @DIAS NVARCHAR(100)
    SELECT @PRIV = p.pro_es_privada, @NOM = p.pro_nombre, @TIPO = t.pti_codigo FROM [dbo].[Programacion] p JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo WHERE p.pro_id = @PRO
    IF @NOM IS NULL RETURN NULL
    IF @PRIV = 0 RETURN N'Calendario · ' + @NOM
    IF @TIPO <> 'CALENDARIO' RETURN NULL
    SELECT TOP 1 @FRE = f.fre_codigo, @INT = ISNULL(c.pca_intervalo, 1), @DM = c.pca_dia_mes, @ORD = c.pca_semana_ordinal, @HORA = c.pca_hora_local,
           @DIAS = STUFF((SELECT N', ' + CHOOSE(d.pcd_dia_semana, N'lun', N'mar', N'mié', N'jue', N'vie', N'sáb', N'dom') FROM [dbo].[Programacion_Calendario_Dia] d
                          WHERE d.pcd_programacion_calendario = c.pca_id ORDER BY d.pcd_dia_semana FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(100)'), 1, 2, N'')
    FROM [dbo].[Programacion_Calendario] c JOIN [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
    WHERE c.pca_programacion = @PRO AND c.pca_habilitado = 1 ORDER BY c.pca_id DESC
    SET @R = CASE @FRE WHEN 'DIARIA' THEN N'Diaria' WHEN 'SEMANAL' THEN N'Semanal' + ISNULL(N' · ' + @DIAS, N'')
                       WHEN 'MENSUAL' THEN N'Mensual' + CASE WHEN @DM > 0 THEN N' · día ' + CAST(@DM AS NVARCHAR(3)) ELSE N'' END
                       WHEN 'ANUAL' THEN N'Anual' ELSE NULL END
    IF @INT > 1 AND @R IS NOT NULL SET @R = @R + N' · cada ' + CAST(@INT AS NVARCHAR(5))
    IF @HORA IS NOT NULL AND @R IS NOT NULL SET @R = @R + N' · ' + LEFT(CONVERT(NVARCHAR(8), @HORA, 108), 5)
    RETURN @R
END
GO

/* Combos de los cajones. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_PROGRAMA_CATALOGO]
    @CLIENTE INT
AS
SET NOCOUNT ON
/* 0 · activos (con su área desglosada y su padre: un activo con padre es un subactivo) */
SELECT  a.act_id AS ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, a.act_cliente_instalacion AS PLANTA_ID,
        a.act_instalacion_area AS AREA_ID, ISNULL(ISNULL(ap.iar_nombre + N' › ', N'') + ia.iar_nombre, N'Sin área') AS AREA,
        ISNULL(t.ati_nombre, N'') AS TIPO, a.act_activo_padre AS PADRE_ID, ISNULL(a.act_criticidad_nivel, 0) AS CRITICIDAD
FROM    [dbo].[Activo] a
LEFT JOIN [dbo].[Instalacion_Area] ia ON ia.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Instalacion_Area] ap ON ap.iar_id = ia.iar_area_padre
LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
WHERE   a.act_cliente = @CLIENTE AND a.act_habilitado = 1
ORDER BY AREA, a.act_codigo
/* 1 · componentes */
SELECT  c.aco_id AS ID, c.aco_activo AS ACTIVO_ID, c.aco_nombre AS NOMBRE, c.aco_componente_padre AS PADRE_ID
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
GO

/* Frecuencia propia (semanal o mensual): crea la programación privada si no viene y la deja como CALENDARIO. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMACION_SIMPLE]
    @ID       INT = NULL OUTPUT,
    @CLIENTE  INT,
    @NOMBRE   NVARCHAR(400),
    @MODO     CHAR(1),            -- 'w' semanal · 'm' mensual
    @DIAS     NVARCHAR(50) = NULL, -- '1,4' (lunes = 1)
    @DIA_MES  INT = NULL,
    @HORA     TIME = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
IF @MODO NOT IN ('w', 'm') BEGIN RAISERROR('1.- ELIGE SEMANAL O MENSUAL.', 16, 1) RETURN -1 END
IF @MODO = 'w' AND ISNULL(@DIAS, N'') = N'' BEGIN RAISERROR('2.- ELIGE AL MENOS UN DIA DE LA SEMANA.', 16, 1) RETURN -1 END
IF @MODO = 'm' AND (@DIA_MES IS NULL OR @DIA_MES < 1 OR @DIA_MES > 31) BEGIN RAISERROR('3.- EL DIA DEL MES VA DEL 1 AL 31.', 16, 1) RETURN -1 END
IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @ID AND pro_cliente = @CLIENTE AND pro_es_privada = 1)
    SET @ID = NULL   -- era un calendario compartido: la frecuencia propia nace aparte, el compartido no se toca
IF @ID IS NULL
BEGIN
    DECLARE @T TABLE (ID INT)
    INSERT @T EXEC [dbo].[INS_PROGRAMACION_PRIVADA] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @NOMBRE = @NOMBRE, @USUARIO = @USUARIO
    IF @ID IS NULL SELECT TOP 1 @ID = ID FROM @T
END
UPDATE [dbo].[Programacion]
SET    pro_programacion_tipo = (SELECT pti_id FROM [dbo].[Programacion_Tipo] WHERE pti_codigo = 'CALENDARIO'),
       pro_fecha_inicio = ISNULL(pro_fecha_inicio, CAST([dbo].[FNC_AHORA]() AS DATE)), pro_habilitado = 1,
       pro_usuario_actualizacion = @USUARIO, pro_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  pro_id = @ID
DECLARE @FRE INT = (SELECT fre_id FROM [dbo].[Frecuencia_Tipo] WHERE fre_codigo = CASE @MODO WHEN 'w' THEN 'SEMANAL' ELSE 'MENSUAL' END)
DECLARE @H TIME = ISNULL(@HORA, '08:00'), @DD NVARCHAR(50) = CASE WHEN @MODO = 'w' THEN @DIAS ELSE NULL END, @DMX INT = CASE WHEN @MODO = 'm' THEN @DIA_MES ELSE NULL END
EXEC [dbo].[UPS_PROGRAMACION_CALENDARIO] @PROGRAMACION = @ID, @CLIENTE = @CLIENTE, @FRECUENCIA = @FRE, @INTERVALO = 1,
     @SEMANA_ORDINAL = NULL, @DIA_MES = @DMX, @MES = NULL, @HORA_LOCAL = @H, @DIAS = @DD, @USUARIO = @USUARIO
SELECT @ID AS ID
GO

/* La frecuencia de una programación para el cajón: privada (modo, días, día del mes, hora) o compartida. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROGRAMACION_SIMPLE]
    @CLIENTE INT,
    @PRO     INT
AS
SET NOCOUNT ON
SELECT  p.pro_id AS ID, CAST(ISNULL(p.pro_es_privada, 0) AS BIT) AS PRIVADA, f.fre_codigo AS FRECUENCIA, c.pca_dia_mes AS DIA_MES,
        LEFT(CONVERT(NVARCHAR(8), c.pca_hora_local, 108), 5) AS HORA,
        STUFF((SELECT N',' + CAST(d.pcd_dia_semana AS NVARCHAR(2)) FROM [dbo].[Programacion_Calendario_Dia] d WHERE d.pcd_programacion_calendario = c.pca_id ORDER BY d.pcd_dia_semana FOR XML PATH('')), 1, 1, N'') AS DIAS
FROM    [dbo].[Programacion] p
OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Programacion_Calendario] x WHERE x.pca_programacion = p.pro_id AND x.pca_habilitado = 1 ORDER BY x.pca_id DESC) c
LEFT JOIN [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
WHERE   p.pro_id = @PRO AND p.pro_cliente = @CLIENTE
GO

/* Cancela las ocurrencias futuras pendientes que ya no calzan con la regla (o de filas dadas de baja)
   y genera las que faltan. @TIPO: INS (grupo de inspección) · TAR (tarea). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_REALINEAR_OCURRENCIAS]
    @CLIENTE INT,
    @TIPO    VARCHAR(3),
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST(GETUTCDATE() AS DATE), @HASTA DATE = DATEADD(DAY, 90, CAST(GETUTCDATE() AS DATE)), @AHORA DATETIME = [dbo].[FNC_AHORA](), @X INT
IF @TIPO = 'INS'
BEGIN
    UPDATE o SET coc_checklist_ocurrencia_estado = 6, coc_usuario_actualizacion = @USUARIO, coc_fecha_actualizacion = @AHORA
    FROM   [dbo].[Checklist_Ocurrencia] o JOIN [dbo].[Checklist_Programacion] cp ON cp.cpr_id = o.coc_checklist_programacion
    WHERE  cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE AND o.coc_checklist_ocurrencia_estado IN (1, 2) AND o.coc_fecha_programada_utc >= @HOY
      AND  (cp.cpr_habilitado = 0 OR NOT EXISTS (SELECT 1 FROM [dbo].[FNC_PROGRAMACION_FECHAS](cp.cpr_programacion, @HOY, @HASTA) f WHERE f.DESCARTADA = 0 AND f.FECHA = o.coc_fecha_programada_utc))
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT cpr_id FROM [dbo].[Checklist_Programacion] WHERE cpr_inspeccion = @ID AND cpr_cliente = @CLIENTE AND cpr_habilitado = 1
    OPEN c FETCH NEXT FROM c INTO @X
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[GEN_CHECKLIST_OCURRENCIAS] @CLIENTE = @CLIENTE, @CHECKLIST_PROGRAMACION = @X, @USUARIO = @USUARIO
        FETCH NEXT FROM c INTO @X
    END
    CLOSE c DEALLOCATE c
END
ELSE
BEGIN
    UPDATE o SET toc_tarea_ocurrencia_estado = 6, toc_usuario_actualizacion = @USUARIO, toc_fecha_actualizacion = @AHORA
    FROM   [dbo].[Tarea_Ocurrencia] o JOIN [dbo].[Tarea_Programacion] tp ON tp.tpr_id = o.toc_tarea_programacion
    WHERE  o.toc_tarea = @ID AND o.toc_cliente = @CLIENTE AND o.toc_tarea_ocurrencia_estado IN (1, 2) AND o.toc_fecha_programada_utc >= @HOY AND o.toc_orden_trabajo IS NULL
      AND  (tp.tpr_habilitado = 0 OR NOT EXISTS (SELECT 1 FROM [dbo].[FNC_PROGRAMACION_FECHAS](tp.tpr_programacion, @HOY, @HASTA) f WHERE f.DESCARTADA = 0 AND f.FECHA = o.toc_fecha_programada_utc))
    EXEC [dbo].[GEN_TAREA_OCURRENCIAS] @CLIENTE = @CLIENTE, @TAREA = @ID, @USUARIO = @USUARIO
END
/* La asignación de la inspección o tarea a sus ocurrencias (BD/410; misma definición aquí y allá). */
IF OBJECT_ID('dbo.UPS_PROGRAMA_ASIGNAR_OCURRENCIAS', 'P') IS NOT NULL
    EXEC [dbo].[UPS_PROGRAMA_ASIGNAR_OCURRENCIAS] @CLIENTE = @CLIENTE, @TIPO = @TIPO, @REF = @ID, @USUARIO = @USUARIO
GO

/* Crea o edita una inspección (grupo de filas). @ACTIVOS = 'activo:componente,…' en el orden del recorrido
   (componente 0 = el activo completo; un subactivo es su propio id de activo). */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_INSPECCION]
    @ID           INT = NULL OUTPUT,
    @CLIENTE      INT,
    @NOMBRE       NVARCHAR(200),
    @PLANTILLA    INT,
    @PROGRAMACION INT,
    @RESPONSABLE  INT = NULL,
    @DURACION     INT = NULL,
    @ACTIVOS      NVARCHAR(MAX),
    @ASIGNACION   NVARCHAR(400) = NULL,
    @USUARIO      INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @VERSION INT, @AHORA DATETIME = [dbo].[FNC_AHORA]()
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
IF LEN(@NOMBRE) = 0 BEGIN RAISERROR('1.- LA INSPECCION NECESITA UN NOMBRE.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla] WHERE cpl_id = @PLANTILLA AND cpl_cliente = @CLIENTE)
BEGIN RAISERROR('2.- ELIGE LA PAUTA DE INSPECCION.', 16, 1) RETURN -1 END
SELECT TOP 1 @VERSION = cpv_id FROM [dbo].[Checklist_Plantilla_Version] WHERE cpv_checklist_plantilla = @PLANTILLA AND cpv_checklist_version_estado = 2 ORDER BY cpv_numero DESC
IF @VERSION IS NULL BEGIN RAISERROR('3.- LA PAUTA NO TIENE UNA VERSION PUBLICADA: PUBLICALA EN RECURSOS.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
BEGIN RAISERROR('4.- ELIGE CADA CUANTO SE HACE.', 16, 1) RETURN -1 END

DECLARE @A TABLE (orden INT IDENTITY(1,1), act INT, comp INT)
INSERT @A (act, comp)
SELECT CAST(LEFT(v.value, CHARINDEX(':', v.value + ':') - 1) AS INT),
       NULLIF(CAST(ISNULL(NULLIF(SUBSTRING(v.value, CHARINDEX(':', v.value + ':') + 1, 20), N''), N'0') AS INT), 0)
FROM STRING_SPLIT(@ACTIVOS, ',') v WHERE LTRIM(v.value) <> N''
IF NOT EXISTS (SELECT 1 FROM @A) BEGIN RAISERROR('5.- ELIGE AL MENOS UN ACTIVO.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM @A x LEFT JOIN [dbo].[Activo] a ON a.act_id = x.act AND a.act_cliente = @CLIENTE WHERE a.act_id IS NULL)
BEGIN RAISERROR('6.- UN ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM @A x LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = x.comp AND c.aco_activo = x.act WHERE x.comp IS NOT NULL AND c.aco_id IS NULL)
BEGIN RAISERROR('7.- EL COMPONENTE NO ES DE ESE ACTIVO.', 16, 1) RETURN -1 END
IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] WHERE cpr_inspeccion = @ID AND cpr_cliente = @CLIENTE)
BEGIN RAISERROR('8.- LA INSPECCION NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END

BEGIN TRANSACTION
    /* filas que siguen: se actualizan */
    UPDATE cp SET cpr_nombre = @NOMBRE, cpr_checklist_plantilla_version = @VERSION, cpr_programacion = @PROGRAMACION, cpr_usuario_responsable = @RESPONSABLE,
                  cpr_duracion_minuto = @DURACION, cpr_orden = x.orden, cpr_habilitado = 1, cpr_usuario_actualizacion = @USUARIO, cpr_fecha_actualizacion = @AHORA
    FROM [dbo].[Checklist_Programacion] cp JOIN @A x ON x.act = cp.cpr_activo AND ISNULL(x.comp, 0) = ISNULL(cp.cpr_activo_componente, 0)
    WHERE cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE
    /* filas que ya no están: baja */
    UPDATE cp SET cpr_habilitado = 0, cpr_usuario_actualizacion = @USUARIO, cpr_fecha_actualizacion = @AHORA
    FROM [dbo].[Checklist_Programacion] cp
    WHERE cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1
      AND NOT EXISTS (SELECT 1 FROM @A x WHERE x.act = cp.cpr_activo AND ISNULL(x.comp, 0) = ISNULL(cp.cpr_activo_componente, 0))
    /* filas nuevas */
    DECLARE @N TABLE (id INT, orden INT)
    INSERT [dbo].[Checklist_Programacion] (cpr_cliente, cpr_checklist_plantilla_version, cpr_programacion, cpr_activo, cpr_activo_componente, cpr_usuario_responsable,
           cpr_nombre, cpr_inspeccion, cpr_orden, cpr_duracion_minuto, cpr_usuario_creacion, cpr_fecha_creacion, cpr_usuario_actualizacion, cpr_fecha_actualizacion, cpr_habilitado)
    OUTPUT INSERTED.cpr_id, INSERTED.cpr_orden INTO @N (id, orden)
    SELECT @CLIENTE, @VERSION, @PROGRAMACION, x.act, x.comp, @RESPONSABLE, @NOMBRE, @ID, x.orden, @DURACION, @USUARIO, @AHORA, @USUARIO, @AHORA, 1
    FROM @A x
    WHERE @ID IS NULL OR NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Programacion] cp WHERE cp.cpr_inspeccion = @ID AND cp.cpr_activo = x.act AND ISNULL(cp.cpr_activo_componente, 0) = ISNULL(x.comp, 0))
    ORDER BY x.orden
    IF @ID IS NULL
    BEGIN
        SELECT TOP 1 @ID = id FROM @N ORDER BY orden
        UPDATE [dbo].[Checklist_Programacion] SET cpr_inspeccion = @ID WHERE cpr_id IN (SELECT id FROM @N)
    END
COMMIT TRANSACTION

IF @ASIGNACION IS NOT NULL EXEC [dbo].[UPS_PROGRAMA_ASIGNACION] @CLIENTE = @CLIENTE, @TIPO = 'INS', @REF = @ID, @ASIGNACION = @ASIGNACION, @USUARIO = @USUARIO
EXEC [dbo].[UPD_PLAN_REALINEAR_OCURRENCIAS] @CLIENTE = @CLIENTE, @TIPO = 'INS', @ID = @ID, @USUARIO = @USUARIO
SELECT @ID AS ID
GO

/* Crea o edita una tarea recurrente con su programación (una por tarea). */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_TAREA]
    @ID           INT = NULL OUTPUT,
    @CLIENTE      INT,
    @NOMBRE       NVARCHAR(400),
    @CATEGORIA    INT = NULL,
    @ACTIVO       INT,
    @COMPONENTE   INT = NULL,
    @DESCRIPCION  NVARCHAR(MAX) = NULL,
    @PROGRAMACION INT,
    @RESPONSABLE  INT = NULL,
    @DURACION     INT = NULL,
    @ASIGNACION   NVARCHAR(400) = NULL,
    @USUARIO      INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @PLANTA INT, @AREA INT
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
IF LEN(@NOMBRE) = 0 BEGIN RAISERROR('1.- LA TAREA NECESITA UN NOMBRE.', 16, 1) RETURN -1 END
SELECT @PLANTA = act_cliente_instalacion, @AREA = act_instalacion_area FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE
IF @PLANTA IS NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN RAISERROR('2.- ELIGE DONDE SE HACE LA TAREA.', 16, 1) RETURN -1 END
IF @COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @COMPONENTE AND aco_activo = @ACTIVO)
BEGIN RAISERROR('3.- EL COMPONENTE NO ES DE ESE ACTIVO.', 16, 1) RETURN -1 END
IF @CATEGORIA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @CATEGORIA AND (tca_cliente = @CLIENTE OR tca_cliente IS NULL))
BEGIN RAISERROR('4.- LA CATEGORIA NO EXISTE.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion] WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE AND pro_habilitado = 1)
BEGIN RAISERROR('5.- ELIGE CADA CUANTO SE HACE.', 16, 1) RETURN -1 END
IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_id = @ID AND tar_cliente = @CLIENTE)
BEGIN RAISERROR('6.- LA TAREA NO EXISTE PARA ESTE CLIENTE.', 16, 1) RETURN -1 END

BEGIN TRANSACTION
    IF @ID IS NULL
    BEGIN
        DECLARE @N INT = (SELECT COUNT(*) FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE), @COD NVARCHAR(50)
        SET @COD = N'TAR-' + RIGHT(N'000' + CAST(@N + 1 AS NVARCHAR(10)), 3)
        WHILE EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_codigo = @COD)
        BEGIN SET @N = @N + 1 SET @COD = N'TAR-' + RIGHT(N'000' + CAST(@N + 1 AS NVARCHAR(10)), 3) END
        INSERT [dbo].[Tarea] (tar_cliente, tar_cliente_instalacion, tar_instalacion_area, tar_tarea_categoria, tar_activo, tar_activo_componente, tar_codigo, tar_titulo,
               tar_descripcion, tar_tarea_prioridad, tar_duracion_estimada_minuto, tar_requiere_evidencia, tar_usuario_creacion, tar_fecha_creacion, tar_usuario_actualizacion, tar_fecha_actualizacion, tar_habilitado)
        VALUES (@CLIENTE, @PLANTA, @AREA, @CATEGORIA, @ACTIVO, @COMPONENTE, @COD, @NOMBRE, NULLIF(@DESCRIPCION, N''),
               ISNULL((SELECT TOP 1 tpa_id FROM [dbo].[Tarea_Prioridad] ORDER BY CASE WHEN tpa_codigo = 'MEDIA' THEN 0 ELSE 1 END, tpa_id), 1),
               @DURACION, 0, @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
        SET @ID = SCOPE_IDENTITY()
        INSERT [dbo].[Tarea_Programacion] (tpr_tarea, tpr_programacion, tpr_usuario_responsable, tpr_usuario_creacion, tpr_fecha_creacion, tpr_usuario_actualizacion, tpr_fecha_actualizacion, tpr_habilitado)
        VALUES (@ID, @PROGRAMACION, @RESPONSABLE, @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
    END
    ELSE
    BEGIN
        UPDATE [dbo].[Tarea] SET tar_titulo = @NOMBRE, tar_tarea_categoria = @CATEGORIA, tar_activo = @ACTIVO, tar_activo_componente = @COMPONENTE,
               tar_cliente_instalacion = @PLANTA, tar_instalacion_area = @AREA, tar_descripcion = NULLIF(@DESCRIPCION, N''), tar_duracion_estimada_minuto = @DURACION,
               tar_usuario_actualizacion = @USUARIO, tar_fecha_actualizacion = @AHORA
        WHERE tar_id = @ID
        DECLARE @TP INT = (SELECT TOP 1 tpr_id FROM [dbo].[Tarea_Programacion] WHERE tpr_tarea = @ID AND tpr_habilitado = 1 ORDER BY tpr_id)
        IF @TP IS NULL
            INSERT [dbo].[Tarea_Programacion] (tpr_tarea, tpr_programacion, tpr_usuario_responsable, tpr_usuario_creacion, tpr_fecha_creacion, tpr_usuario_actualizacion, tpr_fecha_actualizacion, tpr_habilitado)
            VALUES (@ID, @PROGRAMACION, @RESPONSABLE, @USUARIO, @AHORA, @USUARIO, @AHORA, 1)
        ELSE
            UPDATE [dbo].[Tarea_Programacion] SET tpr_programacion = @PROGRAMACION, tpr_usuario_responsable = @RESPONSABLE, tpr_usuario_actualizacion = @USUARIO, tpr_fecha_actualizacion = @AHORA
            WHERE tpr_id = @TP
    END
COMMIT TRANSACTION

IF @ASIGNACION IS NOT NULL EXEC [dbo].[UPS_PROGRAMA_ASIGNACION] @CLIENTE = @CLIENTE, @TIPO = 'TAR', @REF = @ID, @ASIGNACION = @ASIGNACION, @USUARIO = @USUARIO
EXEC [dbo].[UPD_PLAN_REALINEAR_OCURRENCIAS] @CLIENTE = @CLIENTE, @TIPO = 'TAR', @ID = @ID, @USUARIO = @USUARIO
SELECT @ID AS ID
GO

/* Detalle para el cajón. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_INSPECCION]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
SELECT TOP 1 cp.cpr_inspeccion AS ID, cp.cpr_nombre AS NOMBRE, v.cpv_checklist_plantilla AS PLANTILLA, cp.cpr_programacion AS PROGRAMACION,
       cp.cpr_usuario_responsable AS RESPONSABLE, cp.cpr_duracion_minuto AS DURACION, a.act_cliente_instalacion AS PLANTA_ID,
       N'INS-' + RIGHT(N'000' + CAST(cp.cpr_inspeccion AS NVARCHAR(10)), 3) AS CODIGO, [dbo].[FNC_PROGRAMA_ASIGNACION]('INS', cp.cpr_inspeccion) AS ASIGNACION
FROM   [dbo].[Checklist_Programacion] cp
JOIN   [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = cp.cpr_checklist_plantilla_version
LEFT JOIN [dbo].[Activo] a ON a.act_id = cp.cpr_activo
WHERE  cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1
ORDER BY cp.cpr_orden
SELECT cp.cpr_activo AS ACTIVO, ISNULL(cp.cpr_activo_componente, 0) AS COMPONENTE
FROM   [dbo].[Checklist_Programacion] cp
WHERE  cp.cpr_inspeccion = @ID AND cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1 AND cp.cpr_activo IS NOT NULL
ORDER BY cp.cpr_orden
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_TAREA]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
SELECT t.tar_id AS ID, t.tar_codigo AS CODIGO, t.tar_titulo AS NOMBRE, t.tar_tarea_categoria AS CATEGORIA, t.tar_activo AS ACTIVO, ISNULL(t.tar_activo_componente, 0) AS COMPONENTE,
       ISNULL(t.tar_descripcion, N'') AS DESCRIPCION, t.tar_duracion_estimada_minuto AS DURACION, t.tar_cliente_instalacion AS PLANTA_ID,
       tp.tpr_programacion AS PROGRAMACION, tp.tpr_usuario_responsable AS RESPONSABLE, [dbo].[FNC_PROGRAMA_ASIGNACION]('TAR', t.tar_id) AS ASIGNACION,
       (SELECT COUNT(*) FROM [dbo].[Tarea_Ocurrencia] o WHERE o.toc_tarea = t.tar_id AND o.toc_orden_trabajo IS NOT NULL) AS ESCALADAS
FROM   [dbo].[Tarea] t
OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Tarea_Programacion] x WHERE x.tpr_tarea = t.tar_id AND x.tpr_habilitado = 1 ORDER BY x.tpr_id) tp
WHERE  t.tar_id = @ID AND t.tar_cliente = @CLIENTE
GO

/* Listas de las pestañas: una fila por INSPECCIÓN (grupo) con sus activos y la frecuencia en palabras. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_INSPECCIONES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @D30 DATETIME = DATEADD(DAY, -30, @AHORA)
;WITH G AS (
    SELECT cp.cpr_inspeccion AS GID, MIN(cp.cpr_id) AS PRIMERA FROM [dbo].[Checklist_Programacion] cp
    WHERE cp.cpr_cliente = @CLIENTE AND cp.cpr_habilitado = 1 GROUP BY cp.cpr_inspeccion
)
SELECT  g.GID AS ID, p.cpr_nombre AS NOMBRE,
        N'INS-' + RIGHT(N'000' + CAST(g.GID AS NVARCHAR(10)), 3) AS CODIGO,
        cin.cin_nombre AS PLANTA,
        pl.cpl_codigo + N' v' + CAST(ISNULL(v.cpv_numero, 1) AS NVARCHAR(5)) AS PAUTA,
        pl.cpl_nombre AS PAUTA_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i WHERE i.cpi_checklist_plantilla_version = v.cpv_id AND i.cpi_habilitado = 1) AS ITEMS,
        ISNULL(ar.AREAS, ISNULL(iar.iar_nombre, N'Sin ubicación')) AS DONDE,
        ISNULL(ar.CODIGOS, N'') AS DONDE_CODIGO, ISNULL(ar.N, 0) AS ACTIVOS,
        ISNULL([dbo].[FNC_PROGRAMACION_TEXTO](p.cpr_programacion), N'Sin frecuencia') AS FRECUENCIA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        [dbo].[FNC_PROGRAMA_ASIGNACION_TEXTO]('INS', g.GID) AS ASIGNA_TXT,
        px.fecha AS PROXIMA,
        ISNULL(h.hechas, 0) AS HECHAS, ISNULL(h.total, 0) AS TOTAL
FROM    G g
JOIN    [dbo].[Checklist_Programacion] p ON p.cpr_id = g.PRIMERA
JOIN    [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = p.cpr_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla] pl ON pl.cpl_id = v.cpv_checklist_plantilla
LEFT JOIN [dbo].[Activo] a ON a.act_id = p.cpr_activo
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = p.cpr_instalacion_area
LEFT JOIN [dbo].[Programacion] pg ON pg.pro_id = p.cpr_programacion
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ISNULL(a.act_cliente_instalacion, ISNULL(iar.iar_cliente_instalacion, pg.pro_cliente_instalacion))
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = p.cpr_usuario_responsable
OUTER APPLY (SELECT COUNT(*) AS N,
                    STUFF((SELECT DISTINCT N', ' + ISNULL(z.iar_nombre, N'Sin área') FROM [dbo].[Checklist_Programacion] y JOIN [dbo].[Activo] w ON w.act_id = y.cpr_activo LEFT JOIN [dbo].[Instalacion_Area] z ON z.iar_id = w.act_instalacion_area
                                  WHERE y.cpr_inspeccion = g.GID AND y.cpr_habilitado = 1 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS AREAS,
                    STUFF((SELECT N', ' + w.act_codigo + ISNULL(N' › ' + c.aco_nombre, N'') FROM [dbo].[Checklist_Programacion] y JOIN [dbo].[Activo] w ON w.act_id = y.cpr_activo LEFT JOIN [dbo].[Activo_Componente] c ON c.aco_id = y.cpr_activo_componente
                                  WHERE y.cpr_inspeccion = g.GID AND y.cpr_habilitado = 1 ORDER BY y.cpr_orden FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS CODIGOS
             FROM [dbo].[Checklist_Programacion] y WHERE y.cpr_inspeccion = g.GID AND y.cpr_habilitado = 1 AND y.cpr_activo IS NOT NULL) ar
OUTER APPLY (SELECT TOP 1 c.coc_fecha_programada_utc AS fecha FROM [dbo].[Checklist_Ocurrencia] c JOIN [dbo].[Checklist_Programacion] y ON y.cpr_id = c.coc_checklist_programacion
              WHERE y.cpr_inspeccion = g.GID AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado IN (1, 2, 3) AND c.coc_fecha_programada_utc >= CAST(@AHORA AS DATE)
              ORDER BY c.coc_fecha_programada_utc) px
OUTER APPLY (SELECT SUM(CASE WHEN c.coc_checklist_ocurrencia_estado = 4 THEN 1 ELSE 0 END) AS hechas, COUNT(*) AS total FROM [dbo].[Checklist_Ocurrencia] c JOIN [dbo].[Checklist_Programacion] y ON y.cpr_id = c.coc_checklist_programacion
              WHERE y.cpr_inspeccion = g.GID AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado NOT IN (6, 7)
                AND c.coc_fecha_programada_utc >= @D30 AND c.coc_fecha_programada_utc < @AHORA) h
WHERE   (@INSTALACION IS NULL OR cin.cin_id = @INSTALACION)
ORDER BY p.cpr_nombre
RETURN 0
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_TAREAS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @D30 DATETIME = DATEADD(DAY, -30, @AHORA)

SELECT  t.tar_id AS ID, t.tar_codigo AS CODIGO, t.tar_titulo AS NOMBRE,
        ISNULL(c.tca_nombre, N'Sin categoría') AS CATEGORIA, ISNULL(c.tca_color, N'#68738A') AS COLOR,
        cin.cin_nombre AS PLANTA,
        ISNULL(ia.iar_nombre, ISNULL(iar.iar_nombre, N'Sin ubicación')) AS DONDE,
        ISNULL(a.act_codigo + ISNULL(N' › ' + ac.aco_nombre, N''), N'') AS DONDE_CODIGO,
        ISNULL([dbo].[FNC_PROGRAMACION_TEXTO](r.pro), N'Sin frecuencia') AS FRECUENCIA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        [dbo].[FNC_PROGRAMA_ASIGNACION_TEXTO]('TAR', t.tar_id) AS ASIGNA_TXT,
        px.fecha AS PROXIMA,
        ISNULL(h.hechas, 0) AS HECHAS, ISNULL(h.total, 0) AS TOTAL,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o JOIN [dbo].[Tarea_Ocurrencia] x ON x.toc_id = o.otr_tarea_ocurrencia WHERE x.toc_tarea = t.tar_id AND o.otr_habilitado = 1) AS ESCALADAS
FROM    [dbo].[Tarea] t
LEFT JOIN [dbo].[Tarea_Categoria] c ON c.tca_id = t.tar_tarea_categoria
LEFT JOIN [dbo].[Activo] a ON a.act_id = t.tar_activo
LEFT JOIN [dbo].[Instalacion_Area] ia ON ia.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Activo_Componente] ac ON ac.aco_id = t.tar_activo_componente
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = t.tar_instalacion_area
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ISNULL(t.tar_cliente_instalacion, ISNULL(a.act_cliente_instalacion, iar.iar_cliente_instalacion))
OUTER APPLY (SELECT TOP 1 tp.tpr_usuario_responsable AS usu, tp.tpr_programacion AS pro FROM [dbo].[Tarea_Programacion] tp WHERE tp.tpr_tarea = t.tar_id AND tp.tpr_habilitado = 1 ORDER BY tp.tpr_id) r
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = r.usu
OUTER APPLY (SELECT TOP 1 o.toc_fecha_programada_utc AS fecha FROM [dbo].[Tarea_Ocurrencia] o
              WHERE o.toc_tarea = t.tar_id AND o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado IN (1, 2, 3) AND o.toc_fecha_programada_utc >= CAST(@AHORA AS DATE)
              ORDER BY o.toc_fecha_programada_utc) px
OUTER APPLY (SELECT SUM(CASE WHEN o.toc_tarea_ocurrencia_estado = 4 THEN 1 ELSE 0 END) AS hechas, COUNT(*) AS total FROM [dbo].[Tarea_Ocurrencia] o
              WHERE o.toc_tarea = t.tar_id AND o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado NOT IN (6, 7)
                AND o.toc_fecha_programada_utc >= @D30 AND o.toc_fecha_programada_utc < @AHORA) h
WHERE   t.tar_cliente = @CLIENTE AND t.tar_habilitado = 1
  AND   (@INSTALACION IS NULL OR cin.cin_id = @INSTALACION)
ORDER BY t.tar_titulo
RETURN 0
GO
INSERT [dbo].[Programa_Asignacion] (pas_cliente, pas_tipo, pas_ref, pas_usuario, pas_grupo_trabajo, pas_orden, pas_fecha_creacion)
SELECT cp.cpr_cliente, 'INS', cp.cpr_inspeccion, CASE WHEN cp.cpr_usuario_responsable IS NOT NULL THEN cp.cpr_usuario_responsable END,
       CASE WHEN cp.cpr_usuario_responsable IS NULL THEN cp.cpr_grupo_trabajo END, 1, GETDATE()
FROM   [dbo].[Checklist_Programacion] cp
WHERE  cp.cpr_id = cp.cpr_inspeccion AND (cp.cpr_usuario_responsable IS NOT NULL OR cp.cpr_grupo_trabajo IS NOT NULL)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Programa_Asignacion] x WHERE x.pas_tipo = 'INS' AND x.pas_ref = cp.cpr_inspeccion)
INSERT [dbo].[Programa_Asignacion] (pas_cliente, pas_tipo, pas_ref, pas_usuario, pas_grupo_trabajo, pas_orden, pas_fecha_creacion)
SELECT t.tar_cliente, 'TAR', t.tar_id, CASE WHEN tp.tpr_usuario_responsable IS NOT NULL THEN tp.tpr_usuario_responsable END,
       CASE WHEN tp.tpr_usuario_responsable IS NULL THEN tp.tpr_grupo_trabajo END, 1, GETDATE()
FROM   [dbo].[Tarea] t CROSS APPLY (SELECT TOP 1 * FROM [dbo].[Tarea_Programacion] x WHERE x.tpr_tarea = t.tar_id AND x.tpr_habilitado = 1 ORDER BY x.tpr_id) tp
WHERE  (tp.tpr_usuario_responsable IS NOT NULL OR tp.tpr_grupo_trabajo IS NOT NULL)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Programa_Asignacion] x WHERE x.pas_tipo = 'TAR' AND x.pas_ref = t.tar_id)
GO
PRINT '408_PLAN_INSPECCION_TAREA_CAJON aplicado.'
GO
