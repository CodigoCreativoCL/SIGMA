/* ============================================================================
   SIGMA - Bloque 334
   CENTRO DE CARGA DE DATOS (Utilidades > Carga de datos)
   ----------------------------------------------------------------------------

   Un cliente que parte con SIGMA llega con su operacion en planillas: miles de
   repuestos, sus bodegas y racks, el stock con que arranca, sus equipos, sus
   pautas y planes. Las cargas sueltas que habia (una por modulo, dentro de
   cada mantenedor) procesaban fila por fila desde la aplicacion: cada fila
   era un viaje a la base, y con miles de filas contra una base remota eso son
   minutos de espera sin saber en que va.

   EL MOTOR
     1. La aplicacion lee la planilla y la sube COMPLETA en un solo envio
        (SqlBulkCopy) a Carga_Masiva_Fila: una fila de Excel = una fila con
        sus datos en JSON.
     2. Un procedimiento por modulo (PRC_CARGA_<MODULO>) valida todo de una
        vez con consultas de conjunto -obligatorios, formatos, referencias,
        duplicados- y despues crea o actualiza fila por fila llamando a LOS
        MISMOS procedimientos que usan las fichas. Lo que se puede crear a
        mano es exactamente lo que se puede cargar, y el ciclo corre dentro de
        la base: sin viajes por fila.
     3. El avance queda en Carga_Masiva (procesadas, creadas, errores, fase),
        y la pantalla lo consulta cada segundo mientras el proceso corre en
        segundo plano.

   MODOS
     VALIDAR  revisa y anticipa que pasara con cada fila (crear, actualizar,
              omitir o error) sin escribir nada en el modulo.
     CARGAR   valida y escribe. Una fila mala no detiene la carga: queda en
              Carga_Masiva_Error con hoja, fila, columna y motivo.

   EXISTENTES (mismo codigo)
     ACTUALIZAR  las celdas con dato reemplazan; las vacias conservan lo que
                 habia. Volver a cargar la misma planilla no duplica nada.
     OMITIR      se dejan como estan.

   ACCESO
     Permiso GESTIONAR CARGAS MASIVAS: lo tiene el Administrador del Cliente
     y es ASIGNABLE A UN USUARIO (prm_asignable_usuario = 1), para que el
     administrador delegue la carga sin darle su perfil completo.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================== tablas
IF OBJECT_ID('dbo.Carga_Masiva') IS NULL
BEGIN
    CREATE TABLE [dbo].[Carga_Masiva] (
        cma_id              INT IDENTITY(1,1) NOT NULL,
        cma_cliente         INT            NOT NULL,
        cma_usuario         INT            NOT NULL,
        cma_modulo          VARCHAR(30)    NOT NULL,
        cma_archivo         NVARCHAR(260)  NULL,
        cma_modo            VARCHAR(10)    NOT NULL,      -- VALIDAR | CARGAR
        cma_existentes      VARCHAR(12)    NOT NULL,      -- ACTUALIZAR | OMITIR
        cma_estado          VARCHAR(20)    NOT NULL,      -- LEYENDO, EN_COLA, PROCESANDO, TERMINADA, CON_ERRORES, FALLIDA
        cma_fase            NVARCHAR(200)  NULL,
        cma_total           INT            NOT NULL CONSTRAINT DF_CMA_TOTAL DEFAULT (0),
        cma_procesadas      INT            NOT NULL CONSTRAINT DF_CMA_PROC DEFAULT (0),
        cma_creadas         INT            NOT NULL CONSTRAINT DF_CMA_CRE DEFAULT (0),
        cma_actualizadas    INT            NOT NULL CONSTRAINT DF_CMA_ACT DEFAULT (0),
        cma_omitidas        INT            NOT NULL CONSTRAINT DF_CMA_OMI DEFAULT (0),
        cma_errores         INT            NOT NULL CONSTRAINT DF_CMA_ERR DEFAULT (0),
        cma_inicio          DATETIME       NOT NULL CONSTRAINT DF_CMA_INICIO DEFAULT ([dbo].[FNC_AHORA]()),
        cma_fin             DATETIME       NULL,
        cma_mensaje         NVARCHAR(1000) NULL,
        CONSTRAINT PK_CARGA_MASIVA PRIMARY KEY CLUSTERED (cma_id),
        CONSTRAINT CK_CMA_MODO CHECK (cma_modo IN ('VALIDAR', 'CARGAR')),
        CONSTRAINT CK_CMA_EXISTENTES CHECK (cma_existentes IN ('ACTUALIZAR', 'OMITIR'))
    )
    CREATE NONCLUSTERED INDEX IX_CMA_CLIENTE ON [dbo].[Carga_Masiva] (cma_cliente, cma_id DESC)
END
GO

IF OBJECT_ID('dbo.Carga_Masiva_Fila') IS NULL
BEGIN
    CREATE TABLE [dbo].[Carga_Masiva_Fila] (
        cmf_carga       INT            NOT NULL,
        cmf_hoja        VARCHAR(40)    NOT NULL,
        cmf_fila        INT            NOT NULL,
        cmf_datos       NVARCHAR(MAX)  NOT NULL,
        cmf_resultado   CHAR(1)        NULL,     -- C creada, A actualizada, O omitida, E error
        cmf_id          INT            NULL,     -- el registro que creo o actualizo
        CONSTRAINT PK_CARGA_MASIVA_FILA PRIMARY KEY CLUSTERED (cmf_carga, cmf_hoja, cmf_fila)
    )
END
GO

IF OBJECT_ID('dbo.Carga_Masiva_Error') IS NULL
BEGIN
    CREATE TABLE [dbo].[Carga_Masiva_Error] (
        cme_id          INT IDENTITY(1,1) NOT NULL,
        cme_carga       INT            NOT NULL,
        cme_hoja        VARCHAR(40)    NOT NULL,
        cme_fila        INT            NOT NULL,
        cme_columna     NVARCHAR(80)   NULL,
        cme_valor       NVARCHAR(400)  NULL,
        cme_mensaje     NVARCHAR(800)  NOT NULL,
        CONSTRAINT PK_CARGA_MASIVA_ERROR PRIMARY KEY CLUSTERED (cme_id)
    )
    CREATE NONCLUSTERED INDEX IX_CME_CARGA ON [dbo].[Carga_Masiva_Error] (cme_carga, cme_hoja, cme_fila)
END
GO

/* "Alertar un problema": lo que vio quien cargaba, con el contexto de la
   carga en ese momento (fase, avance, tiempo, navegador). */
IF OBJECT_ID('dbo.Carga_Masiva_Incidencia') IS NULL
BEGIN
    CREATE TABLE [dbo].[Carga_Masiva_Incidencia] (
        cmi_id          INT IDENTITY(1,1) NOT NULL,
        cmi_cliente     INT            NOT NULL,
        cmi_carga       INT            NULL,
        cmi_usuario     INT            NOT NULL,
        cmi_fecha       DATETIME       NOT NULL CONSTRAINT DF_CMI_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        cmi_comentario  NVARCHAR(2000) NOT NULL,
        cmi_contexto    NVARCHAR(MAX)  NULL,
        cmi_estado      VARCHAR(12)    NOT NULL CONSTRAINT DF_CMI_ESTADO DEFAULT ('ABIERTA'),
        CONSTRAINT PK_CARGA_MASIVA_INCIDENCIA PRIMARY KEY CLUSTERED (cmi_id)
    )
END
GO

-- ============================================================== permiso y menu
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'GESTIONAR CARGAS MASIVAS')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES (N'GESTIONAR CARGAS MASIVAS', N'Cargar datos desde planillas', N'UTILIDADES', 1,
            N'Carga masiva de bodegas, repuestos, stock, activos y planes desde planillas. Se puede delegar a un usuario.',
            1, GETDATE(), 1, 1)
GO

DECLARE @UTIL INT = (SELECT TOP 1 mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Utilidades' AND mnu_nivel = 2)
IF @UTIL IS NULL BEGIN RAISERROR('No existe el menu Utilidades.', 16, 1) RETURN END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Comun/CargaDatos/CentroCargaDatos.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Carga de datos', N'Centro de carga de datos: deja cada modulo listo para operar desde planillas.',
            3, @UTIL, (SELECT ISNULL(MAX(mnu_orden), 0) + 1 FROM [dbo].[Menus] WHERE mnu_padre = @UTIL),
            N'~/View/Comun/CargaDatos/CentroCargaDatos.aspx', 1, N'mdi mdi-database-import-outline',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'GESTIONAR CARGAS MASIVAS'), 1)
GO

-- Root y Administrador del Cliente
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pf.per_id, p.prm_id, 1, GETDATE()
FROM   [dbo].[Permiso] p
JOIN   [dbo].[Perfiles] pf ON pf.per_id IN (1, 10)
WHERE  p.prm_codigo = N'GESTIONAR CARGAS MASIVAS'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pf.per_id AND x.ppe_permiso = p.prm_id)
GO

-- ============================================================== funciones comunes
/* SI / NO como lo escribe la gente: 1 si, 0 no, NULL vacio, 2 no se entiende. */
CREATE OR ALTER FUNCTION [dbo].[FNC_CM_BOOL] (@T NVARCHAR(40))
RETURNS INT
AS
BEGIN
    SET @T = UPPER(LTRIM(RTRIM(ISNULL(@T, N''))))
    IF @T = N'' RETURN NULL
    IF @T IN (N'SI', N'SÍ', N'S', N'1', N'X', N'TRUE', N'VERDADERO', N'YES', N'Y') RETURN 1
    IF @T IN (N'NO', N'N', N'0', N'FALSE', N'FALSO') RETURN 0
    RETURN 2
END
GO

/* Los RAISERROR de los SP vienen como "7.- ESTE REPUESTO CONTROLA LOTE...":
   sin el numero y en minusculas, para leerlo en un informe. */
CREATE OR ALTER FUNCTION [dbo].[FNC_CM_MENSAJE] (@M NVARCHAR(2000))
RETURNS NVARCHAR(800)
AS
BEGIN
    SET @M = LTRIM(RTRIM(ISNULL(@M, N'')))
    IF @M LIKE N'[0-9].- %' SET @M = SUBSTRING(@M, 5, 2000)
    ELSE IF @M LIKE N'[0-9][0-9].- %' SET @M = SUBSTRING(@M, 6, 2000)
    IF @M = UPPER(@M) COLLATE Latin1_General_CS_AS AND LEN(@M) > 1
        SET @M = UPPER(LEFT(@M, 1)) + LOWER(SUBSTRING(@M, 2, 2000))
    RETURN LEFT(@M, 800)
END
GO

/* Convencion de racks del mapa 3D: <prefijo>-<pasillo>-R<nn>. El prefijo es
   lo que va antes del pasillo en un rack existente; sin racks, el codigo de
   la bodega (prefijoBodega en Js/sigma-bodega3d.js). */
CREATE OR ALTER FUNCTION [dbo].[FNC_BODEGA_PREFIJO_RACK] (@BODEGA INT)
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @C NVARCHAR(200) = (
        SELECT TOP 1 bub_codigo FROM [dbo].[Bodega_Ubicacion]
        WHERE  bub_bodega = @BODEGA AND LEN(bub_codigo) - LEN(REPLACE(bub_codigo, N'-', N'')) >= 2
        ORDER BY bub_id)
    IF @C IS NULL RETURN (SELECT REPLACE(bod_codigo, N' ', N'') FROM [dbo].[Bodega] WHERE bod_id = @BODEGA)
    DECLARE @U INT = LEN(@C) - CHARINDEX(N'-', REVERSE(@C)) + 1           -- ultimo guion
    DECLARE @A NVARCHAR(200) = LEFT(@C, @U - 1)
    DECLARE @P INT = LEN(@A) - CHARINDEX(N'-', REVERSE(@A)) + 1           -- penultimo
    RETURN LEFT(@A, @P - 1)
END
GO

/* Pasillo y numero de un codigo de rack, como los lee el mapa (leerUbicacion):
   la penultima parte de 1 a 3 letras y los digitos de la ultima. */
CREATE OR ALTER FUNCTION [dbo].[FNC_RACK_PASILLO] (@C NVARCHAR(200))
RETURNS NVARCHAR(3)
AS
BEGIN
    SET @C = UPPER(ISNULL(@C, N''))
    IF CHARINDEX(N'-', @C) = 0 RETURN NULL
    DECLARE @U INT = LEN(@C) - CHARINDEX(N'-', REVERSE(@C)) + 1
    DECLARE @A NVARCHAR(200) = LEFT(@C, @U - 1)
    DECLARE @P NVARCHAR(200) = CASE WHEN CHARINDEX(N'-', @A) = 0 THEN @A ELSE RIGHT(@A, CHARINDEX(N'-', REVERSE(@A)) - 1) END
    IF LEN(@P) BETWEEN 1 AND 3 AND @P NOT LIKE N'%[^A-Z]%' RETURN @P
    RETURN NULL
END
GO

CREATE OR ALTER FUNCTION [dbo].[FNC_RACK_NUMERO] (@C NVARCHAR(200))
RETURNS INT
AS
BEGIN
    SET @C = ISNULL(@C, N'')
    IF CHARINDEX(N'-', @C) = 0 RETURN NULL
    DECLARE @U NVARCHAR(200) = RIGHT(@C, CHARINDEX(N'-', REVERSE(@C)) - 1), @D NVARCHAR(200) = N'', @I INT = 1
    WHILE @I <= LEN(@U)
    BEGIN
        IF SUBSTRING(@U, @I, 1) LIKE N'[0-9]' SET @D = @D + SUBSTRING(@U, @I, 1)
        SET @I = @I + 1
    END
    RETURN TRY_CONVERT(INT, NULLIF(@D, N''))
END
GO

-- ============================================================== SP del motor
CREATE OR ALTER PROCEDURE [dbo].[INS_CARGA_MASIVA]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @USUARIO     INT,
    @MODULO      VARCHAR(30),
    @ARCHIVO     NVARCHAR(260),
    @MODO        VARCHAR(10),
    @EXISTENTES  VARCHAR(12)
AS
SET NOCOUNT ON
/* Una carga a la vez por cliente: dos procesos escribiendo los mismos
   catalogos se pisarian los codigos automaticos. */
IF EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva] WHERE cma_cliente = @CLIENTE AND cma_estado IN ('LEYENDO', 'EN_COLA', 'PROCESANDO')
           AND cma_inicio > DATEADD(HOUR, -2, [dbo].[FNC_AHORA]()))
BEGIN
    RAISERROR('1.- YA HAY UNA CARGA EN CURSO PARA ESTA EMPRESA: ESPERE A QUE TERMINE.', 16, 1)
    RETURN -1
END

-- lo que quedo colgado (un reinicio del sitio a mitad de proceso) se cierra como fallido
UPDATE [dbo].[Carga_Masiva]
SET    cma_estado = 'FALLIDA', cma_fin = [dbo].[FNC_AHORA](), cma_mensaje = N'El proceso se interrumpio (el sitio se reinicio).'
WHERE  cma_cliente = @CLIENTE AND cma_estado IN ('LEYENDO', 'EN_COLA', 'PROCESANDO')

-- las filas en JSON de cargas viejas no hacen falta: los errores y el resumen se conservan
DELETE f FROM [dbo].[Carga_Masiva_Fila] f
JOIN   [dbo].[Carga_Masiva] c ON c.cma_id = f.cmf_carga
WHERE  c.cma_cliente = @CLIENTE AND c.cma_inicio < DATEADD(DAY, -30, [dbo].[FNC_AHORA]())

INSERT INTO [dbo].[Carga_Masiva] (cma_cliente, cma_usuario, cma_modulo, cma_archivo, cma_modo, cma_existentes, cma_estado, cma_fase)
VALUES (@CLIENTE, @USUARIO, UPPER(@MODULO), @ARCHIVO, UPPER(@MODO), UPPER(ISNULL(@EXISTENTES, 'ACTUALIZAR')), 'LEYENDO', N'Leyendo la planilla')
SET @ID = SCOPE_IDENTITY()
SELECT @ID [ID], '200' [CODE], 'Carga creada.' [MENSAJE]
GO

/* Despues del SqlBulkCopy: cuantas filas hay y queda en cola. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CARGA_MASIVA_LEIDA]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Carga_Masiva]
SET    cma_total = (SELECT COUNT(*) FROM [dbo].[Carga_Masiva_Fila] WHERE cmf_carga = @ID),
       cma_estado = 'EN_COLA', cma_fase = N'En cola'
WHERE  cma_id = @ID AND cma_cliente = @CLIENTE
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CARGA_MASIVA_FALLA]
    @ID      INT,
    @MENSAJE NVARCHAR(1000)
AS
SET NOCOUNT ON
UPDATE [dbo].[Carga_Masiva]
SET    cma_estado = 'FALLIDA', cma_fin = [dbo].[FNC_AHORA](), cma_mensaje = LEFT(@MENSAJE, 1000)
WHERE  cma_id = @ID AND cma_estado NOT IN ('TERMINADA', 'CON_ERRORES')
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
    SELECT  c.cma_id AS ID, c.cma_modulo AS MODULO, c.cma_archivo AS ARCHIVO, c.cma_modo AS MODO, c.cma_existentes AS EXISTENTES,
            c.cma_estado AS ESTADO, c.cma_fase AS FASE, c.cma_total AS TOTAL, c.cma_procesadas AS PROCESADAS,
            c.cma_creadas AS CREADAS, c.cma_actualizadas AS ACTUALIZADAS, c.cma_omitidas AS OMITIDAS, c.cma_errores AS ERRORES,
            c.cma_inicio AS INICIO, c.cma_fin AS FIN, c.cma_mensaje AS MENSAJE,
            DATEDIFF(SECOND, c.cma_inicio, ISNULL(c.cma_fin, [dbo].[FNC_AHORA]())) AS SEGUNDOS,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO
    FROM    [dbo].[Carga_Masiva] c
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = c.cma_usuario
    WHERE   c.cma_id = @ID AND c.cma_cliente = @CLIENTE

    -- resumen por hoja
    SELECT  f.cmf_hoja AS HOJA, COUNT(*) AS FILAS,
            SUM(CASE WHEN f.cmf_resultado = 'C' THEN 1 ELSE 0 END) AS CREADAS,
            SUM(CASE WHEN f.cmf_resultado = 'A' THEN 1 ELSE 0 END) AS ACTUALIZADAS,
            SUM(CASE WHEN f.cmf_resultado = 'O' THEN 1 ELSE 0 END) AS OMITIDAS,
            SUM(CASE WHEN f.cmf_resultado = 'E' THEN 1 ELSE 0 END) AS ERRORES
    FROM    [dbo].[Carga_Masiva_Fila] f
    JOIN    [dbo].[Carga_Masiva] c ON c.cma_id = f.cmf_carga AND c.cma_cliente = @CLIENTE
    WHERE   f.cmf_carga = @ID
    GROUP BY f.cmf_hoja
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_HISTORIAL]
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT TOP 60
            c.cma_id AS ID, c.cma_modulo AS MODULO, c.cma_archivo AS ARCHIVO, c.cma_modo AS MODO, c.cma_estado AS ESTADO,
            c.cma_total AS TOTAL, c.cma_creadas AS CREADAS, c.cma_actualizadas AS ACTUALIZADAS, c.cma_omitidas AS OMITIDAS,
            c.cma_errores AS ERRORES, c.cma_inicio AS INICIO,
            DATEDIFF(SECOND, c.cma_inicio, ISNULL(c.cma_fin, [dbo].[FNC_AHORA]())) AS SEGUNDOS,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO
    FROM    [dbo].[Carga_Masiva] c
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = c.cma_usuario
    WHERE   c.cma_cliente = @CLIENTE
    ORDER BY c.cma_id DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_ERRORES]
    @CLIENTE INT,
    @ID      INT
AS
SET NOCOUNT ON
    SELECT TOP 20000 e.cme_hoja AS HOJA, e.cme_fila AS FILA, ISNULL(e.cme_columna, N'') AS COLUMNA,
           ISNULL(e.cme_valor, N'') AS VALOR, e.cme_mensaje AS MENSAJE
    FROM   [dbo].[Carga_Masiva_Error] e
    JOIN   [dbo].[Carga_Masiva] c ON c.cma_id = e.cme_carga AND c.cma_cliente = @CLIENTE
    WHERE  e.cme_carga = @ID
    ORDER BY e.cme_hoja, e.cme_fila, e.cme_id
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_CARGA_MASIVA_INCIDENCIA]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @USUARIO     INT,
    @CARGA       INT = NULL,
    @COMENTARIO  NVARCHAR(2000),
    @CONTEXTO    NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
IF LEN(LTRIM(RTRIM(ISNULL(@COMENTARIO, N'')))) = 0
BEGIN
    RAISERROR('1.- CUENTE QUE PASO: ESCRIBA UN COMENTARIO.', 16, 1)
    RETURN -1
END
IF @CARGA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva] WHERE cma_id = @CARGA AND cma_cliente = @CLIENTE)
    SET @CARGA = NULL
INSERT INTO [dbo].[Carga_Masiva_Incidencia] (cmi_cliente, cmi_carga, cmi_usuario, cmi_comentario, cmi_contexto)
VALUES (@CLIENTE, @CARGA, @USUARIO, LTRIM(RTRIM(@COMENTARIO)), @CONTEXTO)
SET @ID = SCOPE_IDENTITY()
SELECT @ID [ID], '200' [CODE], 'Gracias: el problema quedó registrado con el N° ' + LTRIM(STR(@ID)) + '.' [MENSAJE]
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_INCIDENCIAS]
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT TOP 50 i.cmi_id AS ID, i.cmi_carga AS CARGA, c.cma_modulo AS MODULO, i.cmi_fecha AS FECHA, i.cmi_comentario AS COMENTARIO,
           i.cmi_estado AS ESTADO, LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO
    FROM   [dbo].[Carga_Masiva_Incidencia] i
    LEFT JOIN [dbo].[Carga_Masiva] c ON c.cma_id = i.cmi_carga
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = i.cmi_usuario
    WHERE  i.cmi_cliente = @CLIENTE
    ORDER BY i.cmi_id DESC
GO

/* Los contadores salen de las filas: un solo lugar donde se cuentan. */
CREATE OR ALTER PROCEDURE [dbo].[PRC_CM_CONTAR]
    @CARGA INT,
    @FASE  NVARCHAR(200) = NULL
AS
SET NOCOUNT ON
UPDATE c
SET    cma_procesadas   = x.procs,
       cma_creadas      = x.cre,
       cma_actualizadas = x.act,
       cma_omitidas     = x.omi,
       cma_errores      = x.err,
       cma_fase         = ISNULL(@FASE, c.cma_fase)
FROM   [dbo].[Carga_Masiva] c
CROSS APPLY (
    SELECT SUM(CASE WHEN cmf_resultado IS NOT NULL THEN 1 ELSE 0 END) procs,
           SUM(CASE WHEN cmf_resultado = 'C' THEN 1 ELSE 0 END) cre,
           SUM(CASE WHEN cmf_resultado = 'A' THEN 1 ELSE 0 END) act,
           SUM(CASE WHEN cmf_resultado = 'O' THEN 1 ELSE 0 END) omi,
           SUM(CASE WHEN cmf_resultado = 'E' THEN 1 ELSE 0 END) err
    FROM   [dbo].[Carga_Masiva_Fila] WHERE cmf_carga = @CARGA) x
WHERE  c.cma_id = @CARGA
GO

/* "Cargar ahora" despues de revisar: una carga nueva con las mismas filas, sin
   volver a subir el archivo. */
CREATE OR ALTER PROCEDURE [dbo].[INS_CARGA_MASIVA_DESDE]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @USUARIO     INT,
    @ORIGEN      INT,
    @EXISTENTES  VARCHAR(12) = NULL
AS
SET NOCOUNT ON
DECLARE @MOD VARCHAR(30), @ARCH NVARCHAR(260), @EX VARCHAR(12)
SELECT @MOD = cma_modulo, @ARCH = cma_archivo, @EX = cma_existentes FROM [dbo].[Carga_Masiva] WHERE cma_id = @ORIGEN AND cma_cliente = @CLIENTE
IF @MOD IS NULL BEGIN RAISERROR('1.- LA REVISION NO EXISTE.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Carga_Masiva_Fila] WHERE cmf_carga = @ORIGEN)
BEGIN RAISERROR('2.- LA REVISION YA NO TIENE SUS FILAS: VUELVA A SUBIR LA PLANILLA.', 16, 1) RETURN -1 END
EXEC [dbo].[INS_CARGA_MASIVA] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @MODULO = @MOD, @ARCHIVO = @ARCH,
     @MODO = 'CARGAR', @EXISTENTES = @EXISTENTES
IF @EXISTENTES IS NULL UPDATE [dbo].[Carga_Masiva] SET cma_existentes = @EX WHERE cma_id = @ID
INSERT INTO [dbo].[Carga_Masiva_Fila] (cmf_carga, cmf_hoja, cmf_fila, cmf_datos)
SELECT @ID, cmf_hoja, cmf_fila, cmf_datos FROM [dbo].[Carga_Masiva_Fila] WHERE cmf_carga = @ORIGEN
EXEC [dbo].[UPD_CARGA_MASIVA_LEIDA] @CLIENTE = @CLIENTE, @ID = @ID
GO

/* Las hojas de ayuda de la plantilla: lo que hay que escribir, tal cual. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_AYUDA]
    @CLIENTE INT,
    @LISTA   VARCHAR(30)
AS
SET NOCOUNT ON
IF @LISTA = 'PLANTAS'
    SELECT cin_nombre AS [ESCRIBA ESTO EN PLANTA], ISNULL(cin_codigo, N'') AS [O SU CODIGO]
    FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1 ORDER BY cin_nombre
ELSE IF @LISTA = 'BODEGAS'
    SELECT b.bod_codigo AS [CODIGO], b.bod_nombre AS [NOMBRE], ci.cin_nombre AS [PLANTA], ISNULL(b.bod_metodo_salida, 'FEFO') AS [METODO SALIDA],
           (SELECT COUNT(*) FROM [dbo].[Bodega_Ubicacion] u WHERE u.bub_bodega = b.bod_id AND u.bub_habilitado = 1) AS [RACKS]
    FROM [dbo].[Bodega] b JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE b.bod_cliente = @CLIENTE AND b.bod_habilitado = 1 ORDER BY b.bod_nombre
ELSE IF @LISTA = 'RACKS'
    SELECT b.bod_codigo AS [BODEGA], u.bub_codigo AS [CODIGO], u.bub_nombre AS [NOMBRE]
    FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    WHERE b.bod_cliente = @CLIENTE AND u.bub_habilitado = 1 AND b.bod_habilitado = 1 ORDER BY b.bod_codigo, u.bub_codigo
ELSE IF @LISTA = 'UNIDADES'
    SELECT ume_codigo AS [ESCRIBA ESTO EN UNIDAD], ume_nombre AS [SIGNIFICA], ISNULL(ume_simbolo, N'') AS [SIMBOLO]
    FROM [dbo].[Unidad_Medida] WHERE ume_habilitado = 1 ORDER BY ume_nombre
ELSE IF @LISTA = 'TIPOS'
    SELECT rti_codigo AS [ESCRIBA ESTO EN TIPO], rti_nombre AS [SIGNIFICA], ISNULL(rti_descripcion, N'') AS [DESCRIPCION]
    FROM [dbo].[Repuesto_Tipo] WHERE rti_cliente = @CLIENTE AND rti_habilitado = 1 ORDER BY rti_orden, rti_nombre
ELSE IF @LISTA = 'FABRICANTES'
    SELECT fab_nombre AS [FABRICANTE] FROM [dbo].[Fabricante] WHERE fab_cliente = @CLIENTE ORDER BY fab_nombre
GO

/* Lo que ya tiene cada modulo: el estado que muestra la escena 3D. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_MODULOS]
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT 'INVENTARIO' AS MODULO, N'Bodegas' AS DATO, COUNT(*) AS CANTIDAD FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE AND bod_habilitado = 1
    UNION ALL SELECT 'INVENTARIO', N'Racks', COUNT(*) FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega WHERE b.bod_cliente = @CLIENTE AND u.bub_habilitado = 1
    UNION ALL SELECT 'INVENTARIO', N'Repuestos', COUNT(*) FROM [dbo].[Repuesto] WHERE rep_cliente = @CLIENTE AND rep_habilitado = 1
    UNION ALL SELECT 'INVENTARIO', N'Con stock', COUNT(DISTINCT isa_repuesto) FROM [dbo].[Inventario_Saldo] WHERE isa_cliente = @CLIENTE AND isa_cantidad > 0
    UNION ALL SELECT 'INVENTARIO', N'Umbrales', COUNT(*) FROM [dbo].[Repuesto_Bodega_Stock] WHERE rbs_cliente = @CLIENTE
GO
