USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-03. CATALOGOS DEL SISTEMA. HU-020 Y HU-021.
-- =============================================
-- Va DESPUES de 30_SPRINT1_USUARIOS_PERFILES.
--
-- QUE CUBRE
--   HU-020  Consultar cualquier catalogo y buscar de forma transversal.
--   HU-021  Agregar valores propios en los catalogos que lo permiten,
--           incluida la advertencia de cuantos registros usan un valor
--           antes de deshabilitarlo.
--
-- POR QUE ESTO NO SON OCHENTA PANTALLAS
--   El bloque 25 dejo registrados 80 catalogos en la tabla Catalogo, con su
--   tabla, su prefijo y si admite valores propios. Estos SP leen ESE
--   registro y arman la consulta sobre la tabla que corresponda. Una sola
--   pantalla los recorre todos y sumar un catalogo nuevo es un INSERT.
--
-- SOBRE EL SQL DINAMICO
--   Aqui SI hay SQL dinamico sobre nombres de objeto, que es lo que estos
--   SP necesitan para ser genericos. Se hace de forma segura:
--
--     1. El nombre de tabla y el prefijo NUNCA vienen del usuario: salen de
--        la tabla Catalogo, que es un registro controlado.
--     2. Aun asi pasan por QUOTENAME, de modo que un nombre con caracteres
--        raros no pueda cerrar el identificador.
--     3. Se comprueba contra sys.tables y sys.columns que el objeto exista
--        antes de armar nada.
--     4. Los VALORES que escribe el usuario (codigo, nombre, descripcion)
--        viajan como PARAMETROS de sp_executesql, no concatenados.
--
--   Es lo contrario de lo que hacia SEGURIDAD_SEL_MENUS_PERMISO, el SP que
--   se dio de baja en el bloque 06 por concatenar un parametro dentro de
--   un IN(...).
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_CATALOGO                                                  HU-020

      El listado de catalogos disponibles. Es lo que llena el combo de la
      pantalla y la lista de la izquierda.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CATALOGO]
@ID          INT = NULL,
@CODIGO      NVARCHAR(100) = NULL,
@MODULO      NVARCHAR(100) = NULL,
@AMPLIABLE   BIT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ctl.ctl_id          AS CTL_ID
                                 ,ctl.ctl_codigo       AS CTL_CODIGO
                                 ,ctl.ctl_nombre       AS CTL_NOMBRE
                                 ,ctl.ctl_descripcion  AS CTL_DESCRIPCION
                                 ,ctl.ctl_tabla        AS CTL_TABLA
                                 ,ctl.ctl_prefijo      AS CTL_PREFIJO
                                 ,ctl.ctl_modulo       AS CTL_MODULO
                                 ,ctl.ctl_ampliable    AS CTL_AMPLIABLE
                                 ,ctl.ctl_orden        AS CTL_ORDEN
                                 ,ctl.ctl_habilitado   AS CTL_HABILITADO
                                 ,CASE WHEN ctl.ctl_ampliable = 1 THEN ''Ampliable''
                                       ELSE ''Sólo lectura'' END AS TIPO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Catalogo ctl '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ctl.ctl_id = ' + LTRIM(@ID)
    END

    IF (@CODIGO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ctl.ctl_codigo = ''' + REPLACE(@CODIGO, '''', '''''') + ''''
    END

    IF (@MODULO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ctl.ctl_modulo = ''' + REPLACE(@MODULO, '''', '''''') + ''''
    END

    IF (@AMPLIABLE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ctl.ctl_ampliable = ' + LTRIM(@AMPLIABLE)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ctl.ctl_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (ctl.ctl_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ctl.ctl_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ctl.ctl_modulo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY ctl.ctl_modulo, ctl.ctl_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   2. SEL_CATALOGO_VALOR                                            HU-020

      Los valores de UN catalogo. La forma de salida es siempre la misma
      -ID, CODIGO, NOMBRE, DESCRIPCION, ORDEN, HABILITADO, ORIGEN- sin
      importar que tabla haya detras, para que la pantalla sea una sola.

      Las columnas opcionales (descripcion, orden, cliente) se resuelven
      mirando sys.columns: si el catalogo no las tiene, se devuelve NULL en
      su lugar en vez de fallar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CATALOGO_VALOR]
@CATALOGO    INT = NULL,
@CODIGO      NVARCHAR(100) = NULL,
@CLIENTE     INT = NULL,
@VALOR_ID    INT = NULL,
@HABILITADO  BIT = NULL,
@FILTRO      NVARCHAR(400) = NULL

AS
SET NOCOUNT ON

DECLARE @TABLA   NVARCHAR(128)
       ,@PFX     NVARCHAR(10)
       ,@SQL     NVARCHAR(MAX)
       ,@OBJETO  INT

SELECT  @TABLA = ctl_tabla, @PFX = ctl_prefijo
FROM    [dbo].[Catalogo]
WHERE   (@CATALOGO IS NOT NULL AND ctl_id = @CATALOGO)
   OR   (@CATALOGO IS NULL AND @CODIGO IS NOT NULL AND ctl_codigo = @CODIGO)

IF @TABLA IS NULL
BEGIN
    RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
    RETURN -1
END

-- La tabla del registro tiene que existir de verdad
SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
IF @OBJETO IS NULL
BEGIN
    RAISERROR('2.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
    RETURN -1
END

/* Cada columna opcional se resuelve a su nombre real o al literal NULL.
   Asi el SELECT final siempre tiene las mismas siete columnas. */
DECLARE @COL_DESC   NVARCHAR(200) = 'CAST(NULL AS NVARCHAR(1000))'
DECLARE @COL_ORDEN  NVARCHAR(200) = 'CAST(NULL AS INT)'
DECLARE @COL_CLI    NVARCHAR(200) = 'CAST(NULL AS INT)'
DECLARE @TIENE_CLI  BIT = 0

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_descripcion')
    SET @COL_DESC = QUOTENAME(@PFX + '_descripcion')

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_orden')
    SET @COL_ORDEN = QUOTENAME(@PFX + '_orden')

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_cliente')
BEGIN
    SET @COL_CLI   = QUOTENAME(@PFX + '_cliente')
    SET @TIENE_CLI = 1
END

SET @SQL = N'
SELECT  ' + QUOTENAME(@PFX + '_id')     + N' AS VALOR_ID
       ,' + QUOTENAME(@PFX + '_codigo') + N' AS VALOR_CODIGO
       ,' + QUOTENAME(@PFX + '_nombre') + N' AS VALOR_NOMBRE
       ,' + @COL_DESC                   + N' AS VALOR_DESCRIPCION
       ,' + @COL_ORDEN                  + N' AS VALOR_ORDEN
       ,' + QUOTENAME(@PFX + '_habilitado') + N' AS VALOR_HABILITADO
       ,' + @COL_CLI                    + N' AS VALOR_CLIENTE
       ,CASE WHEN ' + @COL_CLI + N' IS NULL THEN N''Sistema'' ELSE N''Propio'' END AS ORIGEN
FROM    [dbo].' + QUOTENAME(@TABLA) + N'
WHERE   1 = 1 '

IF @VALOR_ID IS NOT NULL
    SET @SQL = @SQL + N' AND ' + QUOTENAME(@PFX + '_id') + N' = @P_VALOR_ID '

IF @HABILITADO IS NOT NULL
    SET @SQL = @SQL + N' AND ' + QUOTENAME(@PFX + '_habilitado') + N' = @P_HABILITADO '

/* Con cliente informado se ven los del sistema MAS los propios de ese
   cliente, que es lo que HU-021 escenario 1 describe: "aparece en las
   listas junto a los valores del sistema". */
IF @TIENE_CLI = 1 AND @CLIENTE IS NOT NULL
    SET @SQL = @SQL + N' AND (' + @COL_CLI + N' IS NULL OR ' + @COL_CLI + N' = @P_CLIENTE) '

IF @FILTRO IS NOT NULL
    SET @SQL = @SQL + N' AND (' + QUOTENAME(@PFX + '_nombre') + N' LIKE N''%'' + @P_FILTRO + N''%''
                            OR ' + QUOTENAME(@PFX + '_codigo') + N' LIKE N''%'' + @P_FILTRO + N''%'') '

/* ISNULL(...,9999): los valores sin orden van al final, no al principio. */
SET @SQL = @SQL + N' ORDER BY ISNULL(' + @COL_ORDEN + N', 9999), ' + QUOTENAME(@PFX + '_nombre')

--PRINT @SQL
EXEC sp_executesql @SQL,
     N'@P_VALOR_ID INT, @P_HABILITADO BIT, @P_CLIENTE INT, @P_FILTRO NVARCHAR(400)',
     @P_VALOR_ID = @VALOR_ID, @P_HABILITADO = @HABILITADO,
     @P_CLIENTE = @CLIENTE, @P_FILTRO = @FILTRO

RETURN(0)
GO


/* ========================================================================
   3. SEL_CATALOGO_BUSQUEDA                                         HU-020

      Escenario 2: "cuando busco un texto en el buscador de catalogos,
      entonces se listan todos los catalogos que contienen ese valor".

      Recorre los 80 catalogos y devuelve en que catalogo aparece cada
      coincidencia. Es un cursor a proposito: son consultas contra tablas
      distintas y no hay forma de unirlas sin recorrerlas.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CATALOGO_BUSQUEDA]
@TEXTO    NVARCHAR(400),
@CLIENTE  INT = NULL,
@TOPE     INT = 200

AS
SET NOCOUNT ON

IF @TEXTO IS NULL OR LEN(LTRIM(RTRIM(@TEXTO))) < 2
BEGIN
    RAISERROR('1.- INDIQUE AL MENOS DOS CARACTERES PARA BUSCAR.', 16, 1)
    RETURN -1
END

DECLARE @RESULTADO TABLE
(
    CTL_ID        INT,
    CTL_CODIGO    NVARCHAR(100),
    CTL_NOMBRE    NVARCHAR(200),
    CTL_MODULO    NVARCHAR(100),
    CTL_AMPLIABLE BIT,
    VALOR_ID      INT,
    VALOR_CODIGO  NVARCHAR(200),
    VALOR_NOMBRE  NVARCHAR(400)
)

DECLARE @ID INT, @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @SQL NVARCHAR(MAX), @OBJETO INT

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT ctl_id, ctl_tabla, ctl_prefijo
    FROM   [dbo].[Catalogo]
    WHERE  ctl_habilitado = 1
    ORDER BY ctl_modulo, ctl_nombre

OPEN cur
FETCH NEXT FROM cur INTO @ID, @TABLA, @PFX

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))

    /* Un catalogo registrado cuya tabla ya no existe no debe voltear la
       busqueda completa: se salta. */
    IF @OBJETO IS NOT NULL
       AND EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_codigo')
       AND EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_nombre')
    BEGIN
        SET @SQL = N'
            SELECT TOP (@P_TOPE)
                   @P_ID,
                   CAST(' + QUOTENAME(@PFX + '_id')     + N' AS INT),
                   CAST(' + QUOTENAME(@PFX + '_codigo') + N' AS NVARCHAR(200)),
                   CAST(' + QUOTENAME(@PFX + '_nombre') + N' AS NVARCHAR(400))
            FROM   [dbo].' + QUOTENAME(@TABLA) + N'
            WHERE  (' + QUOTENAME(@PFX + '_nombre') + N' LIKE N''%'' + @P_TEXTO + N''%''
                OR  ' + QUOTENAME(@PFX + '_codigo') + N' LIKE N''%'' + @P_TEXTO + N''%'') '

        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_cliente')
           AND @CLIENTE IS NOT NULL
            SET @SQL = @SQL + N' AND (' + QUOTENAME(@PFX + '_cliente') + N' IS NULL OR '
                                        + QUOTENAME(@PFX + '_cliente') + N' = @P_CLIENTE) '

        INSERT INTO @RESULTADO (CTL_ID, VALOR_ID, VALOR_CODIGO, VALOR_NOMBRE)
        EXEC sp_executesql @SQL,
             N'@P_ID INT, @P_TEXTO NVARCHAR(400), @P_CLIENTE INT, @P_TOPE INT',
             @P_ID = @ID, @P_TEXTO = @TEXTO, @P_CLIENTE = @CLIENTE, @P_TOPE = @TOPE
    END

    FETCH NEXT FROM cur INTO @ID, @TABLA, @PFX
END

CLOSE cur
DEALLOCATE cur

SELECT  r.CTL_ID,
        c.ctl_codigo    AS CTL_CODIGO,
        c.ctl_nombre    AS CTL_NOMBRE,
        c.ctl_modulo    AS CTL_MODULO,
        c.ctl_ampliable AS CTL_AMPLIABLE,
        r.VALOR_ID,
        r.VALOR_CODIGO,
        r.VALOR_NOMBRE
FROM    @RESULTADO r
INNER JOIN [dbo].[Catalogo] c ON c.ctl_id = r.CTL_ID
ORDER BY c.ctl_modulo, c.ctl_nombre, r.VALOR_NOMBRE

RETURN(0)
GO


/* ========================================================================
   4. INS_CATALOGO_VALOR                                            HU-021

      Agrega un valor PROPIO del cliente. Nunca del sistema: el escenario 1
      dice "queda disponible solo para mi cliente", y por eso @CLIENTE es
      obligatorio y siempre se escribe.

      El INSERT se arma segun las columnas que tenga esa tabla en concreto.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CATALOGO_VALOR]
@ID           INT = NULL OUTPUT,
@CATALOGO     INT,
@CLIENTE      INT,
@CODIGO       NVARCHAR(200),
@NOMBRE       NVARCHAR(400),
@DESCRIPCION  NVARCHAR(1000) = NULL,
@ORDEN        INT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @AMPLIABLE BIT
DECLARE @OBJETO INT, @SQL NVARCHAR(MAX)
DECLARE @COLS NVARCHAR(MAX) = '', @VALS NVARCHAR(MAX) = ''
DECLARE @EXISTE INT

SELECT  @TABLA = ctl_tabla, @PFX = ctl_prefijo, @AMPLIABLE = ctl_ampliable
FROM    [dbo].[Catalogo] WHERE ctl_id = @CATALOGO

BEGIN
    IF @TABLA IS NULL
    BEGIN
        RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
        RETURN -1
    END

    -- Escenario 2: en un catalogo no ampliable la accion no existe
    IF @AMPLIABLE = 0
    BEGIN
        RAISERROR('2.- ESTE CATÁLOGO NO ADMITE VALORES PROPIOS.', 16, 1)
        RETURN -1
    END

    SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
    IF @OBJETO IS NULL
    BEGIN
        RAISERROR('3.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_cliente')
    BEGIN
        RAISERROR('4.- ESTE CATÁLOGO ESTÁ MARCADO COMO AMPLIABLE PERO SU TABLA NO TIENE COLUMNA DE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('5.- DEBE INDICAR EL CLIENTE DUEÑO DEL VALOR.', 16, 1)
        RETURN -1
    END
END

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

/* Codigo unico por cliente y catalogo, contando tambien los del sistema:
   el usuario final ve unos y otros en la misma lista. */
SET @SQL = N'SELECT @P_OUT = COUNT(*) FROM [dbo].' + QUOTENAME(@TABLA) + N'
             WHERE ' + QUOTENAME(@PFX + '_codigo') + N' = @P_CODIGO
               AND (' + QUOTENAME(@PFX + '_cliente') + N' IS NULL
                    OR ' + QUOTENAME(@PFX + '_cliente') + N' = @P_CLIENTE)'

EXEC sp_executesql @SQL,
     N'@P_CODIGO NVARCHAR(200), @P_CLIENTE INT, @P_OUT INT OUTPUT',
     @P_CODIGO = @CODIGO, @P_CLIENTE = @CLIENTE, @P_OUT = @EXISTE OUTPUT

IF @EXISTE > 0
BEGIN
    RAISERROR('6.- YA EXISTE UN VALOR CON EL CÓDIGO "%s" EN ESTE CATÁLOGO.', 16, 1, @CODIGO)
    RETURN -1
END

-- Columnas obligatorias en todo catalogo
SET @COLS = QUOTENAME(@PFX + '_codigo') + N',' + QUOTENAME(@PFX + '_nombre') + N','
          + QUOTENAME(@PFX + '_cliente') + N',' + QUOTENAME(@PFX + '_habilitado')
SET @VALS = N'@P_CODIGO,@P_NOMBRE,@P_CLIENTE,1'

-- Columnas que solo tienen algunos catalogos
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_descripcion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_descripcion')
    SET @VALS = @VALS + N',@P_DESCRIPCION'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_orden')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_orden')
    SET @VALS = @VALS + N',@P_ORDEN'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_creacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_usuario_creacion')
    SET @VALS = @VALS + N',@P_USUARIO'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_creacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_fecha_creacion')
    SET @VALS = @VALS + N',GETDATE()'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_actualizacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_usuario_actualizacion')
    SET @VALS = @VALS + N',@P_USUARIO'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_actualizacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_fecha_actualizacion')
    SET @VALS = @VALS + N',GETDATE()'
END

SET @SQL = N'INSERT INTO [dbo].' + QUOTENAME(@TABLA) + N' (' + @COLS + N')
             VALUES (' + @VALS + N');
             SELECT @P_ID = CAST(SCOPE_IDENTITY() AS INT);'

--PRINT @SQL

BEGIN TRANSACTION

    EXEC sp_executesql @SQL,
         N'@P_CODIGO NVARCHAR(200), @P_NOMBRE NVARCHAR(400), @P_CLIENTE INT,
           @P_DESCRIPCION NVARCHAR(1000), @P_ORDEN INT, @P_USUARIO INT, @P_ID INT OUTPUT',
         @P_CODIGO = @CODIGO, @P_NOMBRE = @NOMBRE, @P_CLIENTE = @CLIENTE,
         @P_DESCRIPCION = @DESCRIPCION, @P_ORDEN = @ORDEN, @P_USUARIO = @USUARIO,
         @P_ID = @ID OUTPUT

    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CATALOGO_VALOR @CATALOGO = ' + LTRIM(STR(@CATALOGO)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '7.- NO FUE POSIBLE INSERTAR EL VALOR DEL CATÁLOGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   5. SEL_CATALOGO_VALOR_USO                                        HU-021

      Escenario 3: "se advierte cuantos registros lo usan".

      No hay una lista escrita a mano de que tablas apuntan a que catalogo:
      se deduce de las claves foraneas declaradas en la base. Cualquier
      tabla que en el futuro referencie ese catalogo entra sola en la
      cuenta, sin tocar este SP.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CATALOGO_VALOR_USO]
@CATALOGO  INT,
@VALOR_ID  INT

AS
SET NOCOUNT ON

DECLARE @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @OBJETO INT

SELECT @TABLA = ctl_tabla, @PFX = ctl_prefijo
FROM   [dbo].[Catalogo] WHERE ctl_id = @CATALOGO

IF @TABLA IS NULL
BEGIN
    RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
    RETURN -1
END

SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
IF @OBJETO IS NULL
BEGIN
    RAISERROR('2.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
    RETURN -1
END

DECLARE @USO TABLE (TABLA NVARCHAR(128), COLUMNA NVARCHAR(128), REGISTROS INT)

DECLARE @T NVARCHAR(128), @C NVARCHAR(128), @SQL NVARCHAR(MAX), @N INT

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT  th.name, ch.name
    FROM    sys.foreign_keys fk
    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.tables  th ON th.object_id = fk.parent_object_id
    INNER JOIN sys.columns ch ON ch.object_id = fk.parent_object_id
                             AND ch.column_id = fkc.parent_column_id
    WHERE   fk.referenced_object_id = @OBJETO

OPEN cur
FETCH NEXT FROM cur INTO @T, @C

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'SELECT @P_OUT = COUNT(*) FROM [dbo].' + QUOTENAME(@T) +
               N' WHERE ' + QUOTENAME(@C) + N' = @P_VALOR'

    EXEC sp_executesql @SQL, N'@P_VALOR INT, @P_OUT INT OUTPUT',
         @P_VALOR = @VALOR_ID, @P_OUT = @N OUTPUT

    IF @N > 0
        INSERT INTO @USO (TABLA, COLUMNA, REGISTROS) VALUES (@T, @C, @N)

    FETCH NEXT FROM cur INTO @T, @C
END

CLOSE cur
DEALLOCATE cur

-- Detalle por tabla
SELECT TABLA, COLUMNA, REGISTROS FROM @USO ORDER BY REGISTROS DESC

-- Total, que es lo que se muestra en la advertencia
SELECT ISNULL(SUM(REGISTROS), 0) AS TOTAL_REGISTROS FROM @USO

RETURN(0)
GO


/* ========================================================================
   6. UPD_CATALOGO_VALOR                                            HU-021

      Solo toca valores PROPIOS del cliente. Los del sistema son de solo
      lectura (HU-020 escenario 1: "no puedo modificar ni eliminar sus
      valores"), y esa regla se hace cumplir aqui y no solo escondiendo un
      boton en la pantalla.

      Deshabilitar y no borrar es lo que pide el escenario 3: "el valor deja
      de ofrecerse pero los registros existentes lo conservan". Un DELETE
      dejaria esos registros sin poder resolver su propio valor.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CATALOGO_VALOR]
@CATALOGO     INT,
@VALOR_ID     INT,
@CLIENTE      INT,
@NOMBRE       NVARCHAR(400) = NULL,
@DESCRIPCION  NVARCHAR(1000) = NULL,
@ORDEN        INT = NULL,
@HABILITADO   BIT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @AMPLIABLE BIT
DECLARE @OBJETO INT, @SQL NVARCHAR(MAX), @SETS NVARCHAR(MAX) = '', @DUENO INT

SELECT  @TABLA = ctl_tabla, @PFX = ctl_prefijo, @AMPLIABLE = ctl_ampliable
FROM    [dbo].[Catalogo] WHERE ctl_id = @CATALOGO

BEGIN
    IF @TABLA IS NULL
    BEGIN
        RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
        RETURN -1
    END

    IF @AMPLIABLE = 0
    BEGIN
        RAISERROR('2.- ESTE CATÁLOGO ES DE SÓLO LECTURA.', 16, 1)
        RETURN -1
    END

    SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
    IF @OBJETO IS NULL
    BEGIN
        RAISERROR('3.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
        RETURN -1
    END

    -- De quien es el valor
    SET @SQL = N'SELECT @P_OUT = ' + QUOTENAME(@PFX + '_cliente') +
               N' FROM [dbo].' + QUOTENAME(@TABLA) +
               N' WHERE ' + QUOTENAME(@PFX + '_id') + N' = @P_VALOR'

    EXEC sp_executesql @SQL, N'@P_VALOR INT, @P_OUT INT OUTPUT',
         @P_VALOR = @VALOR_ID, @P_OUT = @DUENO OUTPUT

    IF @DUENO IS NULL
    BEGIN
        RAISERROR('4.- ES UN VALOR DEL SISTEMA Y NO PUEDE MODIFICARSE.', 16, 1)
        RETURN -1
    END

    IF @DUENO <> @CLIENTE
    BEGIN
        RAISERROR('5.- ESE VALOR PERTENECE A OTRO CLIENTE.', 16, 1)
        RETURN -1
    END
END

SET @SETS = QUOTENAME(@PFX + '_nombre') + N' = ISNULL(@P_NOMBRE, ' + QUOTENAME(@PFX + '_nombre') + N')'
SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_habilitado') + N' = ISNULL(@P_HABILITADO, ' + QUOTENAME(@PFX + '_habilitado') + N')'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_descripcion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_descripcion') + N' = @P_DESCRIPCION'

/* El orden va con ISNULL y no por asignacion directa. Todos los parametros
   de este SP son opcionales, asi que una llamada que solo cambie el nombre
   dejaria el orden en NULL y el valor se iria al principio de todas las
   listas donde aparece. La descripcion si va directa: es un campo que el
   usuario tiene derecho a dejar en blanco (PATRON_SP §5). */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_orden')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_orden') + N' = ISNULL(@P_ORDEN, ' + QUOTENAME(@PFX + '_orden') + N')'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_actualizacion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_usuario_actualizacion') + N' = @P_USUARIO'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_actualizacion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_fecha_actualizacion') + N' = GETDATE()'

SET @SQL = N'UPDATE [dbo].' + QUOTENAME(@TABLA) + N' SET ' + @SETS +
           N' WHERE ' + QUOTENAME(@PFX + '_id') + N' = @P_VALOR'

BEGIN TRANSACTION

    EXEC sp_executesql @SQL,
         N'@P_NOMBRE NVARCHAR(400), @P_DESCRIPCION NVARCHAR(1000), @P_ORDEN INT,
           @P_HABILITADO BIT, @P_USUARIO INT, @P_VALOR INT',
         @P_NOMBRE = @NOMBRE, @P_DESCRIPCION = @DESCRIPCION, @P_ORDEN = @ORDEN,
         @P_HABILITADO = @HABILITADO, @P_USUARIO = @USUARIO, @P_VALOR = @VALOR_ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CATALOGO_VALOR @CATALOGO = ' + LTRIM(STR(@CATALOGO)) +
                                          ',@VALOR_ID = ' + LTRIM(STR(@VALOR_ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE ACTUALIZAR EL VALOR DEL CATÁLOGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs EP-03' AS control, COUNT(*) AS valor, 6 AS esperado
FROM   sys.procedures
WHERE  name IN ('SEL_CATALOGO','SEL_CATALOGO_VALOR','SEL_CATALOGO_BUSQUEDA',
                'INS_CATALOGO_VALOR','SEL_CATALOGO_VALOR_USO','UPD_CATALOGO_VALOR')
GO
