# Patrón de SQL Server – FacilityGes (Tablas y Stored Procedures)

Este documento describe cómo el equipo crea **tablas** y **Stored Procedures**
(SP) en la base de datos `FacilityGes`, para que cualquier script nuevo siga
el mismo formato/encabezado y estilo.

---

## 1. Encabezado estándar de un script de SP

Todo script de creación/alteración de un SP empieza así:

```sql
USE [FacilityGes]
GO
/****** Objeto:  StoredProcedure [dbo].[<NOMBRE_SP>]    Fecha de script: <DD-MM-AAAA HH:MM:SS> ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:		   <NOMBRE AUTOR o "CRUD">
-- FECHA CREACIÓN: <DD-MM-AAAA>
-- DESCRIPTION:	   <QUÉ HACE EL SP, EN MAYÚSCULAS>
-- =============================================
ALTER PROCEDURE [dbo].[<NOMBRE_SP>]
    @PARAM1 TIPO,
    @PARAM2 TIPO = NULL,
    ...
AS
SET NOCOUNT ON
```

- Se usa `ALTER PROCEDURE` cuando el SP ya existe (lo más común al editar uno
  existente). Si es un SP **nuevo**, generar primero el `CREATE PROCEDURE`
  (o usar `CREATE OR ALTER PROCEDURE` como en los SP nuevos de
  `BD/SEL_USUARIO_APP_DISPOSITIVO.sql`).
- El comentario `/****** Objeto: ... ******/` es el que genera SSMS al hacer
  "Script Stored Procedure as ALTER" — se mantiene tal cual aunque la fecha no
  se actualice manualmente.
- El bloque `-- AUTHOR / FECHA CREACIÓN / DESCRIPTION` siempre va, con
  `DESCRIPTION` corta y en mayúsculas describiendo la acción (INSERTA, SELECT
  REGISTRO, ACTUALIZA, ELIMINA, etc.).

---

## 2. Convención de nombres

- **SPs**: `<ACCION>_<TABLA>` en mayúsculas:
  - `SEL_<TABLA>` – consulta/listado (también sirve para "get by id" pasando `@ID`).
  - `INS_<TABLA>` – inserción.
  - `UPD_<TABLA>` – actualización.
  - `DEL_<TABLA>` – eliminación (física, salvo que se pida lógica).
  - Prefijos especiales: `API_...` para SPs usados desde la API (FacilityGesApi),
    `FNC_...` para funciones (ej. `FNC_PAIS_HORA`).
- **Tablas**: nombre en mayúsculas (o PascalCase para tablas nuevas tipo
  `Usuario_App_Dispositivo`, ambos estilos conviven en la BD).
- **Columnas**: prefijo de 3 letras de la tabla + `_` + nombre descriptivo,
  todo en mayúsculas (ej. tabla `PAISES` → `PAI_ID`, `PAI_NOMBRE`; tabla
  `CHECKLIST` → `CHK_ID`, `CHK_NOMBRE`; tabla `USUARIO_APP_DISPOSITIVO` →
  `UAD_ID`, `UAD_FCM_TOKEN`).
- **Columnas de auditoría** presentes casi siempre:
  - `<PFX>_USUARIO_CREACION INT`, `<PFX>_FECHA_CREACION DATETIME`
  - `<PFX>_USUARIO_ACTUALIZACION` / `<PFX>_USUARIO_ACT`,
    `<PFX>_FECHA_ACTUALIZACION` / `<PFX>_FECHA_ACT`
  - `<PFX>_HABILITADO BIT` (estado activo/inactivo, casi nunca se borra físico
    en tablas "maestro"; las tablas de detalle/relación sí permiten `DEL_`).

---

## 3. SP de INSERT (`INS_<TABLA>`)

Patrón:

```sql
ALTER PROCEDURE [dbo].[INS_<TABLA>]
@ID INT = NULL OUTPUT,
@CAMPO1 VARCHAR(200),
@CAMPO2 ...,
@USUARIO INT

AS
SET NOCOUNT ON

-- Validaciones (opcional)
BEGIN
    IF EXISTS (SELECT 1 FROM <TABLA> WHERE <CAMPO_UNICO> = @CAMPO1)
    BEGIN
        RAISERROR('1. Ya existe un registro con "%s".', 16, 1, @CAMPO1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT <TABLA>
        (
            <PFX>_CAMPO1,
            <PFX>_CAMPO2,
            <PFX>_HABILITADO,
            <PFX>_USUARIO_CREACION,
            <PFX>_FECHA_CREACION,
            <PFX>_USUARIO_ACTUALIZACION,
            <PFX>_FECHA_ACTUALIZACION
        )
    VALUES
        (
            @CAMPO1,
            @CAMPO2,
            @HABILITADO,
            @USUARIO,
            GETDATE(),
            @USUARIO,
            GETDATE()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_<TABLA> ' + LTRIM(STR(@ID))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE INSERTAR EL REGISTRO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
```

Reglas:
- `@ID INT = NULL OUTPUT` siempre primero, para devolver el id generado
  (`SCOPE_IDENTITY()`).
- Validaciones de negocio (duplicados, etc.) **antes** de `BEGIN TRANSACTION`,
  con `RAISERROR(...)` + `RETURN -1`.
- `BEGIN TRANSACTION` ... `COMMIT TRANSACTION`, con `ROLLBACK` + `EXEC INS_EXCEPCION`
  si `@@ROWCOUNT = 0`.
- Mensaje de error de `INS_EXCEPCION` siempre en mayúsculas terminando en punto:
  `'1.- NO FUE POSIBLE INSERTAR EL <ENTIDAD>.'`.
- `RETURN(0)` al final si todo OK, `RETURN -1` en los errores controlados.

---

## 4. SP de SELECT (`SEL_<TABLA>`)

Patrón dinámico con `@SELECT` / `@FROM` / `@WHERE` concatenados y ejecutados
con `EXEC(...)`. Todos los parámetros de filtro son `= NULL` (opcionales),
salvo los obligatorios del negocio.

```sql
ALTER PROCEDURE [dbo].[SEL_<TABLA>]
@ID INT = NULL,
@NOMBRE VARCHAR(200) = NULL,
@HABILITADO BIT = NULL,
@FILTRO VARCHAR(MAX) = NULL,
@<FK_OBLIGATORIA> INT     -- ej. @CLIENTE INT, sin = NULL si es obligatorio

AS
SET NOCOUNT ON

--SELECT
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET @SELECT = 'SELECT DISTINCT <PFX>_ID
                                  ,<PFX>_CAMPO1
                                  ,<PFX>_CAMPO2
                                  ,<PFX>_USUARIO_CREACION
                                  ,<PFX>_FECHA_CREACION
                                  ,<PFX>_USUARIO_ACT
                                  ,<PFX>_FECHA_ACT
                                  ,<PFX>_HABILITADO
                  '
END

--FROM
BEGIN
   DECLARE @FROM VARCHAR(MAX)
   SET @FROM = ' FROM <TABLA>
                 INNER JOIN <TABLA_RELACIONADA> ON <FK> = <PK_RELACIONADA>
               '
END

--WHERE
BEGIN
   DECLARE @WHERE VARCHAR(MAX)
   SET @WHERE = ' WHERE 1=1
                '
    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_ID = ' + LTRIM(@ID)
    END

    IF (@<FK_OBLIGATORIA> IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_<FK> = ' + LTRIM(@<FK_OBLIGATORIA>)
    END

    IF (@NOMBRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_NOMBRE = ' + @NOMBRE
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (<PFX>_NOMBRE LIKE ''%' + LTRIM(@FILTRO) + '%''
                                 OR <PFX>_DESCRIPCION LIKE ''%' + LTRIM(@FILTRO) + '%''
                               )'
    END
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
```

Reglas:
- `WHERE 1=1` siempre como base, para poder concatenar `AND` libremente.
- Cada filtro: `IF (@PARAM IS NOT NULL) BEGIN ... END` agregando al `@WHERE`.
- Strings que van directo a la condición (`@NOMBRE`, `@FILTRO`) **no** llevan
  comillas adicionales si el parámetro ya las trae desde el código C# (revisar
  caso a caso); para `LIKE` se usa `''%' + LTRIM(@FILTRO) + '%'''`.
- Dejar comentado un `--print(@SELECT + @FROM + @WHERE)` para debug.
- Al final, un único `EXEC(@SELECT + @FROM + @WHERE)`.

---

## 5. SP de UPDATE (`UPD_<TABLA>`)

```sql
ALTER PROCEDURE [dbo].[UPD_<TABLA>]
@ID INT,
@CAMPO1 VARCHAR(200) = NULL,
@CAMPO2 ... = NULL,
@USUARIO INT,
@HABILITADO BIT = NULL

AS
SET NOCOUNT ON

BEGIN TRANSACTION

   UPDATE  <TABLA>
   SET     <PFX>_CAMPO1 = @CAMPO1
          ,<PFX>_CAMPO2 = @CAMPO2
          ,<PFX>_USUARIO_ACT = @USUARIO
          ,<PFX>_FECHA_ACT = GETDATE()
          ,<PFX>_HABILITADO = ISNULL(@HABILITADO, <PFX>_HABILITADO)
   WHERE   <PFX>_ID = @ID

   IF @@ROWCOUNT = 0 BEGIN
       ROLLBACK TRANSACTION
       DECLARE @VARIABLES VARCHAR(MAX)
       SET @VARIABLES = 'UPD_<TABLA>' +
                           '@ID = ' + LTRIM(@ID) + ',' +
                           '@CAMPO1 = ' + LTRIM(@CAMPO1)

       EXEC INS_EXCEPCION
           @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL REGISTRO.',
           @VARIABLES = @VARIABLES
       RETURN -1
   END

COMMIT TRANSACTION
RETURN(0)
```

Reglas:
- `@ID` y `@USUARIO` obligatorios (sin `= NULL`); el resto de columnas
  editables suelen ser `= NULL` y se actualizan con `ISNULL(@PARAM, columna_actual)`
  cuando el campo es opcional/parcial (patrón muy usado para `HABILITADO`).
- Si la tabla maneja hora local por país (ver `UPD_CHECKLIST`), se obtiene el
  país desde la tabla relacionada y se calcula `@DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)`
  para usarlo en `<PFX>_FECHA_ACT` en vez de `GETDATE()`.
- Mismo patrón de `ROLLBACK` + `EXEC INS_EXCEPCION` con `@VARIABLES` armado
  concatenando los parámetros recibidos.

---

## 6. SP de DELETE (`DEL_<TABLA>`)

```sql
ALTER PROCEDURE [dbo].[DEL_<TABLA>]
@ID INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

	DELETE	<TABLA>
	WHERE	<PFX>_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'DEL_<TABLA> ' + LTRIM(STR(@ID))
		EXEC INS_EXCEPCION
			@MSG = '1.- No fue posible Eliminar el <TABLA>.',
			@VARIABLES = @VARIABLES
		RETURN -1
	END

COMMIT TRANSACTION

RETURN(0)
```

Reglas:
- Solo recibe `@ID`.
- Borrado físico (`DELETE`) en tablas de detalle/relación (ej.
  `CLIENTE_INSTALACION`). Para tablas "maestro" donde se prefiere baja lógica,
  usar `UPD_<TABLA>` con `<PFX>_HABILITADO = 0` en lugar de un `DEL_`.

---

## 7. Manejo de errores: `INS_EXCEPCION`

Todos los `IF @@ROWCOUNT = 0` (insert/update/delete) siguen el mismo patrón:

```sql
ROLLBACK TRANSACTION
DECLARE @VARIABLES VARCHAR(MAX)
SET @VARIABLES = '<NOMBRE_SP> ' + <parametros concatenados con LTRIM/STR>

EXEC INS_EXCEPCION
    @MSG = '<N>.- <MENSAJE EN MAYÚSCULAS TERMINADO EN PUNTO>',
    @VARIABLES = @VARIABLES
RETURN -1
```

- `@VARIABLES` debe permitir reproducir la llamada (nombre del SP + valores
  de los parámetros recibidos).
- Numerar los mensajes de validación/error (`'1.- ...'`, `'2.- ...'`) si el SP
  tiene más de una validación.

---

## 8. Creación de tablas nuevas

Para tablas nuevas, usar `IF NOT EXISTS (... sys.objects ...) BEGIN CREATE TABLE ... END`,
con índices y constraints con nombre explícito:

```sql
IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[<TABLA>]')
    AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[<TABLA>]
    (
        [<pfx>_id]                  INT            NOT NULL IDENTITY(1,1),
        [<pfx>_<fk_otra_tabla>]     INT            NOT NULL,
        [<pfx>_campo]               NVARCHAR(200)  NOT NULL,
        [<pfx>_campo_opcional]      NVARCHAR(200)  NULL,
        [<pfx>_usuario_creacion]    INT            NOT NULL,
        [<pfx>_fecha_creacion]      DATETIME       NOT NULL CONSTRAINT DF_<PFX>_FECHA_CREACION DEFAULT GETDATE(),
        [<pfx>_usuario_actualizacion] INT          NULL,
        [<pfx>_fecha_actualizacion] DATETIME       NULL,
        [<pfx>_habilitado]          BIT            NOT NULL CONSTRAINT DF_<PFX>_HABILITADO DEFAULT 1,

        CONSTRAINT PK_<TABLA> PRIMARY KEY CLUSTERED ([<pfx>_id] ASC),
        CONSTRAINT FK_<PFX>_<OTRA_TABLA> FOREIGN KEY ([<pfx>_<fk_otra_tabla>])
            REFERENCES [dbo].[<OTRA_TABLA>] ([<otra_pfx>_id])
    )

    -- Índices de apoyo a búsquedas frecuentes
    CREATE NONCLUSTERED INDEX IX_<PFX>_<COLUMNA>
        ON [dbo].[<TABLA>] ([<pfx>_<columna>])

    PRINT 'Tabla <TABLA> creada correctamente.'
END
ELSE
    PRINT 'Tabla <TABLA> ya existe.'
GO
```

Reglas:
- Verificar existencia con `sys.objects` antes de crear (idempotente, para
  poder re-ejecutar el script sin error).
- Constraints con nombre explícito y prefijo del tipo: `PK_`, `FK_`, `DF_`
  (default), `IX_` (índice normal), `UX_` (índice único).
- Mantener las columnas de auditoría (`usuario_creacion`, `fecha_creacion`,
  `usuario_actualizacion`/`_act`, `fecha_actualizacion`/`_act`, `habilitado`)
  igual que en el resto de tablas.
- Al final, `PRINT` indicando si se creó o ya existía.

---

## 9. Checklist al crear los SP de una nueva entidad "TABLA"

1. `INS_TABLA` – con `@ID OUTPUT`, validaciones previas, transacción,
   columnas de auditoría (`USUARIO_CREACION`/`FECHA_CREACION` y también
   `USUARIO_ACTUALIZACION`/`FECHA_ACTUALIZACION` con el mismo valor inicial).
2. `SEL_TABLA` – `@ID`, `@FILTRO`, `@HABILITADO` y FKs relevantes, todos
   `= NULL` salvo los obligatorios; patrón `@SELECT/@FROM/@WHERE` + `EXEC`.
3. `UPD_TABLA` – `@ID` y `@USUARIO` obligatorios, resto `= NULL` con
   `ISNULL(@PARAM, columna)`.
4. `DEL_TABLA` (si aplica borrado físico) – solo `@ID`.
5. Encabezado estándar (`USE`, `SET ANSI_NULLS/QUOTED_IDENTIFIER`, bloque
   `AUTHOR/FECHA CREACIÓN/DESCRIPTION`) en cada SP.
6. Manejo de errores con `INS_EXCEPCION` en los 3 SP de escritura.
7. Guardar el `.sql` en **UTF-8 con BOM** (ver regla general en
   [`CLAUDE.md`](../../CLAUDE.md)).
