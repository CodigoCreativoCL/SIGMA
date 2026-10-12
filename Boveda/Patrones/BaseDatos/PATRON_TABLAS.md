# Patrón de creación de tablas — SQL Server

Cómo se nombran, crean y modifican las tablas en los proyectos del grupo.
Complementa [`PATRON_SP.md`](PATRON_SP.md) (Stored Procedures) y aplica a
cualquier base de datos del grupo (`FacilityGes`, `SGF`, `Agendamientos`,
`Workges`...): lo único que cambia entre proyectos es el `USE [<BaseDatos>]`.

---

## 1. Nomenclatura

### 1.1 Nombre de la tabla — `Pascal_Snake_Case`

**Primera letra en mayúscula y mayúscula después de cada `_`.** El resto en
minúsculas. Palabras en español, en **singular**.

```text
Cliente
Cliente_Tarea
Cliente_Tarea_Detalle
Menu_Material_Apoyo
Usuario_App_Dispositivo
Checklist_Detalle
```

| ✔ Correcto | ❌ Incorrecto |
|---|---|
| `Cliente_Tarea` | `cliente_tarea`, `CLIENTE_TAREA`, `ClienteTarea`, `Cliente_tarea` |
| `Menu_Material_Apoyo` | `MenuMaterialApoyo`, `Menu_material_apoyo` |
| `Usuario_App_Dispositivo` | `USUARIO_APP_DISPOSITIVO`, `UsuarioAppDispositivo` |

Composición del nombre:

- **Tabla maestro**: el sustantivo de la entidad → `Cliente`, `Tarea`, `Pais`.
- **Tabla hija / detalle**: `<Padre>_<Hijo>` → `Cliente_Tarea` (tareas de un
  cliente), `Cliente_Tarea_Detalle` (líneas de esa tarea).
- **Tabla de relación N:N**: `<TablaA>_<TablaB>` → `Cliente_Instalacion`,
  `Usuario_Paises`.
- **Tabla de catálogo**: `<Entidad>_Tipo`, `<Entidad>_Estado` →
  `Checklist_Tipo`, `Cliente_Tarea_Estado`.
- **Tabla de log/bitácora**: `<Entidad>_Log` → `Carga_Masiva_Log`.

> En bases antiguas conviven tablas heredadas en MAYÚSCULAS (`CLIENTE`,
> `MENUS`, `USUARIO`). **No se renombran**; se referencian tal cual existen.
> Todas las tablas **nuevas** usan `Pascal_Snake_Case`.

### 1.2 Prefijo de columnas — 3 letras

Todas las columnas de una tabla llevan un prefijo de **3 letras** común,
seguido de `_` y el nombre descriptivo.

Regla de derivación:

| Caso | Regla | Ejemplo |
|---|---|---|
| Tabla de **una** palabra | Primeras 3 letras significativas | `Cliente` → `cli`, `Usuario` → `usu`, `Pais` → `pai`, `Tarea` → `tar` |
| Tabla de **dos** palabras | 1ª letra de la primera + 2 primeras de la segunda | `Cliente_Tarea` → `cta`, `Checklist_Detalle` → `chd` |
| Tabla de **tres o más** palabras | Iniciales de cada palabra | `Menu_Material_Apoyo` → `mma`, `Usuario_App_Dispositivo` → `uad` |
| Colisión con un prefijo ya usado | Ajustar una letra hasta que sea único | `Cliente_Tarea` = `cta` ocupado → `ctr` |

**El prefijo debe ser único en la base.** Verificar antes de crear la tabla:

```sql
-- ¿Alguna tabla ya usa el prefijo <pfx>_ ?
SELECT DISTINCT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '<pfx>[_]%'
ORDER BY TABLE_NAME;
```

### 1.3 Nombre de las columnas

- Minúsculas en el DDL (`cta_nombre`), MAYÚSCULAS al referenciarlas dentro de
  los SPs (`CTA_NOMBRE`). SQL Server no distingue mayúsculas; ambos estilos
  conviven y así está el código existente.
- PK: siempre `<pfx>_id`.
- FK: `<pfx>_<entidad_referida>` → en `Cliente_Tarea`, la FK a `Cliente` es
  `cta_cliente` (no `cta_cliente_id`).
- Booleanos: `<pfx>_<adjetivo>` con tipo `BIT` → `cta_habilitado`, `cta_visible`.
- Fechas: `<pfx>_fecha_<algo>` → `cta_fecha_inicio`.
- Nunca abreviar de forma no evidente: `cta_descripcion`, no `cta_desc`.

---

## 2. Columnas de auditoría estándar

Toda tabla transaccional o maestro lleva este bloque al final:

| Columna | Tipo | Null | Nota |
|---|---|---|---|
| `<pfx>_usuario_creacion` | `INT` | NO | `Session.UsuarioId()` |
| `<pfx>_fecha_creacion` | `DATETIME` | NO | `DEFAULT GETDATE()` |
| `<pfx>_usuario_actualizacion` | `INT` | SÍ | también se ve como `<pfx>_usuario_act` |
| `<pfx>_fecha_actualizacion` | `DATETIME` | SÍ | también se ve como `<pfx>_fecha_act` |
| `<pfx>_habilitado` | `BIT` | NO | `DEFAULT 1` — baja lógica |

Reglas:

- Usar **un solo estilo** por tabla: o `_actualizacion` o `_act`. Mirar las
  tablas vecinas del mismo módulo y seguir ese estilo.
- El `INSERT` inicial escribe **los cuatro** campos (creación y actualización
  con el mismo valor), ver [`PATRON_SP.md`](PATRON_SP.md) §3.
- Tablas **append-only** (log, bitácora, estadísticas, historial): solo
  `<pfx>_usuario_creacion` + `<pfx>_fecha_creacion`. **Sin** `_act` ni
  `_habilitado` (nada se actualiza ni se deshabilita).
- Tablas de **relación pura** N:N: pueden omitir `_habilitado` si la baja es
  física (`DEL_`).

---

## 3. Plantilla — tabla maestro

Script idempotente: se puede re-ejecutar sin error.

```sql
USE [<BaseDatos>]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          <NOMBRE AUTOR>
-- FECHA CREACIÓN:  <DD-MM-AAAA>
-- DESCRIPTION:     CREA LA TABLA <TABLA>.
-- =============================================
IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[<Tabla>]')
      AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[<Tabla>]
    (
        [<pfx>_id]                      INT             NOT NULL IDENTITY(1,1),
        [<pfx>_<fk_padre>]              INT             NOT NULL,
        [<pfx>_nombre]                  NVARCHAR(200)   NOT NULL,
        [<pfx>_descripcion]             NVARCHAR(500)   NULL,
        [<pfx>_fecha_inicio]            DATETIME        NULL,
        [<pfx>_monto]                   DECIMAL(18,2)   NULL,
        [<pfx>_usuario_creacion]        INT             NOT NULL,
        [<pfx>_fecha_creacion]          DATETIME        NOT NULL CONSTRAINT DF_<PFX>_FECHA_CREACION DEFAULT GETDATE(),
        [<pfx>_usuario_actualizacion]   INT             NULL,
        [<pfx>_fecha_actualizacion]     DATETIME        NULL,
        [<pfx>_habilitado]              BIT             NOT NULL CONSTRAINT DF_<PFX>_HABILITADO DEFAULT 1,

        CONSTRAINT PK_<TABLA> PRIMARY KEY CLUSTERED ([<pfx>_id] ASC),
        CONSTRAINT FK_<PFX>_<TABLA_PADRE> FOREIGN KEY ([<pfx>_<fk_padre>])
            REFERENCES [dbo].[<Tabla_Padre>] ([<pfx_padre>_id])
    )

    -- Índices de apoyo a las búsquedas frecuentes (las del WHERE del SEL_)
    CREATE NONCLUSTERED INDEX IX_<PFX>_<FK_PADRE>
        ON [dbo].[<Tabla>] ([<pfx>_<fk_padre>])

    PRINT 'Tabla <Tabla> creada correctamente.'
END
ELSE
    PRINT 'Tabla <Tabla> ya existe.'
GO
```

### 3.1 Tipos de dato a usar

| Necesito | Tipo |
|---|---|
| Id / FK | `INT` (`BIGINT` solo si se esperan > 2.000 millones de filas) |
| Texto corto | `NVARCHAR(n)` con `n` real (50/100/200/500) |
| Texto libre / observaciones | `NVARCHAR(MAX)` |
| Booleano | `BIT NOT NULL DEFAULT 0` (o `1`) |
| Fecha y hora | `DATETIME` |
| Solo fecha | `DATE` |
| Dinero / cantidades con decimales | `DECIMAL(18,2)` (nunca `FLOAT` ni `MONEY`) |
| Correlativo visible al usuario | `INT` + índice único |
| Archivo binario | `VARBINARY(MAX)`, en **tabla aparte** (`<Entidad>_Binario`) |

> Las tablas antiguas usan `VARCHAR`; para tablas nuevas preferir `NVARCHAR`
> salvo que la tabla se relacione por texto con tablas `VARCHAR` existentes
> (para evitar conversiones implícitas que rompen índices).

---

## 4. Plantilla — tabla de detalle / relación N:N

```sql
IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[<TablaA>_<TablaB>]') AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[<TablaA>_<TablaB>]
    (
        [<pfx>_id]                  INT         NOT NULL IDENTITY(1,1),
        [<pfx>_<tabla_a>]           INT         NOT NULL,
        [<pfx>_<tabla_b>]           INT         NOT NULL,
        [<pfx>_orden]               INT         NULL,
        [<pfx>_usuario_creacion]    INT         NOT NULL,
        [<pfx>_fecha_creacion]      DATETIME    NOT NULL CONSTRAINT DF_<PFX>_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_<TABLA_A>_<TABLA_B> PRIMARY KEY CLUSTERED ([<pfx>_id] ASC),
        CONSTRAINT FK_<PFX>_<TABLA_A> FOREIGN KEY ([<pfx>_<tabla_a>])
            REFERENCES [dbo].[<TablaA>] ([<pfx_a>_id]),
        CONSTRAINT FK_<PFX>_<TABLA_B> FOREIGN KEY ([<pfx>_<tabla_b>])
            REFERENCES [dbo].[<TablaB>] ([<pfx_b>_id]),
        CONSTRAINT UX_<PFX>_<TABLA_A>_<TABLA_B> UNIQUE ([<pfx>_<tabla_a>], [<pfx>_<tabla_b>])
    )

    PRINT 'Tabla <TablaA>_<TablaB> creada correctamente.'
END
ELSE
    PRINT 'Tabla <TablaA>_<TablaB> ya existe.'
GO
```

- `UX_` sobre el par de FKs evita duplicar la relación.
- En estas tablas la baja es **física** (`DEL_<TABLA_A>_<TABLA_B>`), por eso no
  llevan `_habilitado`.

---

## 5. Plantilla — tabla de catálogo

Catálogos pequeños y estables (tipos, estados, categorías). Se crean con ids
**fijos** e `IDENTITY_INSERT`, porque el código y los SPs los referencian.

```sql
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[<Entidad>_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[<Entidad>_Estado]
    (
        [<pfx>_id]          INT             NOT NULL IDENTITY(1,1),
        [<pfx>_nombre]      NVARCHAR(100)   NOT NULL,
        [<pfx>_orden]       INT             NULL,
        [<pfx>_habilitado]  BIT             NOT NULL CONSTRAINT DF_<PFX>_HABILITADO DEFAULT 1,

        CONSTRAINT PK_<ENTIDAD>_ESTADO PRIMARY KEY CLUSTERED ([<pfx>_id] ASC),
        CONSTRAINT UX_<PFX>_NOMBRE UNIQUE ([<pfx>_nombre])
    )
    PRINT 'Tabla <Entidad>_Estado creada correctamente.'
END
GO

-- Carga inicial idempotente (ids fijos)
SET IDENTITY_INSERT [dbo].[<Entidad>_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [<Entidad>_Estado] WHERE <pfx>_id = 1)
    INSERT INTO [<Entidad>_Estado] (<pfx>_id, <pfx>_nombre, <pfx>_orden) VALUES (1, 'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [<Entidad>_Estado] WHERE <pfx>_id = 2)
    INSERT INTO [<Entidad>_Estado] (<pfx>_id, <pfx>_nombre, <pfx>_orden) VALUES (2, 'Finalizado', 2)
SET IDENTITY_INSERT [dbo].[<Entidad>_Estado] OFF
GO
```

- **Antes de crear un catálogo nuevo, revisar si ya existe uno equivalente**
  (`SELECT * FROM <Catalogo>`): el estándar del grupo es reutilizar el registro
  existente antes que insertar uno "parecido".
- En C# y en los SPs, **nunca** hardcodear el texto del estado: hacer JOIN al
  catálogo y comparar por id.

---

## 6. Plantilla — tabla de log / bitácora (append-only)

```sql
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[<Entidad>_Log]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[<Entidad>_Log]
    (
        [<pfx>_id]                  INT             NOT NULL IDENTITY(1,1),
        [<pfx>_<entidad>]           INT             NULL,       -- id del registro afectado
        [<pfx>_accion]              NVARCHAR(50)    NOT NULL,   -- INSERT / UPDATE / DELETE / CARGA
        [<pfx>_detalle]             NVARCHAR(MAX)   NULL,
        [<pfx>_usuario_creacion]    INT             NOT NULL,
        [<pfx>_fecha_creacion]      DATETIME        NOT NULL CONSTRAINT DF_<PFX>_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_<ENTIDAD>_LOG PRIMARY KEY CLUSTERED ([<pfx>_id] ASC)
    )

    CREATE NONCLUSTERED INDEX IX_<PFX>_FECHA_CREACION
        ON [dbo].[<Entidad>_Log] ([<pfx>_fecha_creacion] DESC)

    PRINT 'Tabla <Entidad>_Log creada correctamente.'
END
GO
```

- Sin `_act` ni `_habilitado`: nada se actualiza ni se borra.
- Si el log tiene cabecera + detalle (ej. una carga masiva y sus filas), son
  **dos** tablas: `<Entidad>_Log` y `<Entidad>_Log_Detalle`, con FK del detalle
  a la cabecera y borrado en cascada lógico desde el SP.
- Índice descendente por fecha: el listado siempre ordena por más reciente.

---

## 7. Modificar una tabla existente (`ALTER TABLE`)

Siempre idempotente, una columna por bloque:

```sql
USE [<BaseDatos>]
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[dbo].[<Tabla>]')
      AND name = '<pfx>_nueva_columna'
)
BEGIN
    ALTER TABLE [dbo].[<Tabla>]
        ADD [<pfx>_nueva_columna] NVARCHAR(200) NULL
    PRINT 'Columna <pfx>_nueva_columna agregada a <Tabla>.'
END
ELSE
    PRINT 'Columna <pfx>_nueva_columna ya existe en <Tabla>.'
GO
```

Reglas:

- Las columnas nuevas se agregan **NULL** (o con `DEFAULT`), nunca `NOT NULL`
  sin default en una tabla con datos.
- Si la columna nueva reemplaza a otra, **no borrar la antigua**: dejarla y
  documentarla como deprecada (el código viejo puede seguir leyéndola).
- Antes de agregar: verificar que no exista ya una columna equivalente en la
  misma tabla o en la tabla padre/hija (ver
  [`../CONVENCIONES.md`](../CONVENCIONES.md) §6).
- Después de un `ALTER`, actualizar en el mismo cambio: el SP `SEL_`, `INS_`,
  `UPD_`, el Model C# y el/los `.ascx` que usan la entidad.

---

## 8. Trigger de auditoría (`LOG`) — opcional

Solo si el proyecto tiene la tabla `LOG` (verificar, ver
[`../README.md`](../README.md) §3.2). Escribe una fila por **columna
modificada**.

```sql
USE [<BaseDatos>]
GO
CREATE OR ALTER TRIGGER [dbo].[TRG_LOG_<Tabla>]
ON [dbo].[<Tabla>]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @USUARIO  INT
    DECLARE @DATE_NOW DATETIME
    DECLARE @ACCION   VARCHAR(10)

    SELECT @USUARIO = ISNULL((SELECT TOP 1 <pfx>_usuario_actualizacion FROM inserted), 0)

    -- Proyecto multi-país: hora local del país del usuario.
    -- Proyecto mono-país: SET @DATE_NOW = GETDATE()
    SET @DATE_NOW = GETDATE()

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @ACCION = 'UPDATE'
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @ACCION = 'INSERT'
    ELSE
        SET @ACCION = 'DELETE'

    -- ... insertar en LOG una fila por columna modificada,
    --     usando el id de módulo que corresponda en esta BD ...
END
GO
```

Puntos críticos:

- El **id de módulo** que se escribe en `LOG` es propio de cada base:
  verificar la numeración existente antes de copiar un trigger de otro proyecto.
- Si el proyecto **no** es multi-país, quitar `Usuario_Paises` /
  `FNC_PAIS_HORA` y usar `GETDATE()`. Ese error no aparece al consultar, solo
  al insertar/actualizar/eliminar.
- Comprobar dependencias rotas después de copiar un trigger:

```sql
SELECT o.name AS OBJETO, d.referenced_entity_name AS DEPENDE_DE,
       CASE WHEN OBJECT_ID(d.referenced_entity_name) IS NULL THEN 'NO EXISTE' ELSE 'ok' END AS ESTADO
FROM sys.sql_expression_dependencies d
INNER JOIN sys.objects o ON o.object_id = d.referencing_id
WHERE o.name LIKE '%<TABLA>%';
```

---

## 9. Checklist al crear una tabla nueva

1. Nombre en `Pascal_Snake_Case`, singular, en español (§1.1).
2. Prefijo de 3 letras derivado y **verificado como único** en la BD (§1.2).
3. `<pfx>_id INT IDENTITY(1,1)` como PK, con `CONSTRAINT PK_<TABLA>`.
4. FKs con `CONSTRAINT FK_<PFX>_<TABLA_REF>` explícito.
5. Bloque de auditoría según el tipo de tabla (§2).
6. `DEFAULT` con nombre (`DF_<PFX>_<COLUMNA>`) para `fecha_creacion` y
   `habilitado`.
7. Índices `IX_` sobre las columnas que filtra el `SEL_` (FKs, fechas).
8. Script envuelto en `IF NOT EXISTS (sys.objects) ... ELSE PRINT` (idempotente).
9. Crear en el mismo cambio los SPs `SEL_`/`INS_`/`UPD_`/`DEL_`
   ([`PATRON_SP.md`](PATRON_SP.md)).
10. Guardar el `.sql` en **UTF-8 con BOM** (ver [`../CONVENCIONES.md`](../CONVENCIONES.md) §2).
