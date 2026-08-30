# Guía 04 — Patrón de SQL Server (Tablas y Stored Procedures)

> Archivo original: [`../00-Patrones-Originales/PATRON_SP.md`](../00-Patrones-Originales/PATRON_SP.md)
> Código de ejemplo: [`../02-Ejemplo-Usuario/BD/`](../02-Ejemplo-Usuario/BD/)
> Duración estimada: **50 min**

---

## 1. La regla de oro

> **Nada de SQL en C#. Todo el acceso a datos pasa por un Stored Procedure.**

Tres razones, y conviene que el equipo las tenga claras porque es una decisión que hoy se discute:

1. **Seguridad.** Los parámetros van tipados; no hay concatenación de strings del usuario en el C#.
2. **Mantenimiento.** Cambiar una consulta = ejecutar un script en la BD. No hay que recompilar ni desplegar la aplicación.
3. **Trazabilidad.** El equipo de BD puede auditar y optimizar en un solo lugar.

**Contrapunto honesto**, porque en el CAPSTONE alguien lo va a plantear: este patrón tiene costos reales. La lógica queda partida entre dos repositorios, es más difícil de testear unitariamente, y hoy la industria se ha movido bastante hacia ORMs (Entity Framework, Dapper). Es una arquitectura de los 2000s que sigue siendo perfectamente válida en sistemas empresariales grandes con equipos de BD dedicados — que es exactamente el caso de FacilityGes. Para SIGMA lo adoptamos por consistencia con lo que el equipo ya sabe.

---

## 2. Nomenclatura — hay que memorizarla

### Stored Procedures: `<ACCION>_<TABLA>`

| Prefijo | Acción |
|---|---|
| `SEL_` | Consulta (listado **y** get by id) |
| `INS_` | Inserción |
| `UPD_` | Actualización |
| `DEL_` | Eliminación física |
| `API_` | SP consumido desde la API |
| `FNC_` | Función escalar |

### Columnas: prefijo de 3 letras + `_` + nombre

| Tabla | Prefijo | Ejemplos |
|---|---|---|
| `USUARIO` | `USU_` | `USU_ID`, `USU_NOMBRES` |
| `PERFIL` | `PER_` | `PER_ID`, `PER_NOMBRE` |
| `PAISES` | `PAI_` | `PAI_ID`, `PAI_NOMBRE` |

En SQL van en **MAYÚSCULAS**; en el Model C# la misma columna va en **minúsculas** (`usu_nombres`). Es la única transformación de nombres en todo el sistema.

**Por qué el prefijo:** en un `SELECT` con tres `JOIN`, `USU_NOMBRES` te dice de inmediato de qué tabla viene. Con `NOMBRES` a secas necesitas alias por todos lados.

### Auditoría — en toda tabla, sin excepción

```sql
USU_USUARIO_CREACION  INT
USU_FECHA_CREACION    DATETIME
USU_USUARIO_ACT       INT
USU_FECHA_ACT         DATETIME
USU_HABILITADO        BIT
```

`USU_HABILITADO` es la **baja lógica**. En tablas maestro nunca se borra físicamente: se pone en 0. Se conserva la historia y no se rompen las FK.

> Ojo: en FacilityGes conviven dos estilos, `_ACT` y `_ACTUALIZACION`. Para SIGMA **elegimos `_ACT`** y lo usamos siempre. Definirlo ahora evita el desorden después.

---

## 3. El encabezado estándar

Todo script empieza igual. Abre [`01_SEL_USUARIO.sql`](../02-Ejemplo-Usuario/BD/01_SEL_USUARIO.sql):

```sql
USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[SEL_USUARIO]    Fecha de script: 14-08-2026 10:00:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     SELECT DE USUARIOS. SIRVE PARA LISTADO Y PARA GET BY ID.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO]
```

- El comentario `/****** Objeto: ... ******/` lo genera SSMS al hacer "Script Stored Procedure as". Se conserva tal cual.
- El bloque AUTHOR/FECHA/DESCRIPTION va **siempre**. `DESCRIPTION` corta y en mayúsculas.
- `CREATE OR ALTER PROCEDURE` para SP nuevos (funciona las dos veces: la primera crea, las siguientes modifican). En FacilityGes verás mucho `ALTER PROCEDURE` a secas porque los SP ya existían.

---

## 4. `SEL_` — la query dinámica

Este es el patrón más particular del proyecto. Abre [`01_SEL_USUARIO.sql`](../02-Ejemplo-Usuario/BD/01_SEL_USUARIO.sql).

### La estructura: tres variables y un `EXEC`

```sql
--SELECT
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET @SELECT = 'SELECT DISTINCT USU_ID, USU_RUT, ... '
END

--FROM
BEGIN
   DECLARE @FROM VARCHAR(MAX)
   SET @FROM = ' FROM USUARIO
                 INNER JOIN PERFIL ON USU_PERFIL = PER_ID '
END

--WHERE
BEGIN
   DECLARE @WHERE VARCHAR(MAX)
   SET @WHERE = ' WHERE 1=1 '

   IF (@ID IS NOT NULL) BEGIN
       SET @WHERE = @WHERE + ' AND USU_ID = ' + LTRIM(@ID)
   END
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
```

### `WHERE 1=1` — el truco

`1=1` es siempre verdadero, así que no cambia el resultado. Su función es puramente sintáctica: permite concatenar `AND ...` sin preguntar nunca "¿es el primer filtro?".

Sin `1=1` tendrías que llevar una bandera y decidir entre `WHERE` y `AND` en cada bloque. Con `1=1`, todos los bloques son idénticos y copiables.

### El contrato C# ↔ SQL

Este es el concepto que hay que dejar amarrado, y hay que enseñarlo **mirando los dos archivos al mismo tiempo**:

```csharp
// UsuarioController.cs
if (!string.IsNullOrEmpty(usuario.filtro))
    cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);
```

```sql
-- SEL_USUARIO.sql
IF (@FILTRO IS NOT NULL) BEGIN
    SET @WHERE = @WHERE + ' AND (USU_NOMBRES LIKE ''%' + LTRIM(@FILTRO) + '%'' ...)'
END
```

Las dos mitades del mismo mecanismo:

- El C# **no manda** el parámetro cuando no hay filtro.
- El SP lo recibe como `NULL` (por el `= NULL` en la firma).
- El `IF` no se cumple y ese `AND` no se concatena.

**Por eso todos los parámetros de filtro llevan `= NULL`.** Si a uno se le olvida el `= NULL` y el C# no lo manda, el SP falla con "Procedure expects parameter which was not supplied".

### Comillas dentro de comillas

```sql
' AND USU_NOMBRES LIKE ''%' + LTRIM(@FILTRO) + '%'' '
```

En T-SQL, dentro de un string una comilla simple se escribe **doblada**: `''`. Como estamos construyendo SQL dentro de un string, hay que doblarlas. Se lee horrible; es el precio de la query dinámica.

### El `--print` comentado

```sql
--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
```

Se deja siempre. Cuando algo falla, descomentas el `print`, comentas el `EXEC`, y ves la query armada tal cual. Es **la** herramienta de depuración de este patrón.

### Un SP para dos usos

`SEL_USUARIO` sirve para el listado (sin `@ID`) y para traer un registro (con `@ID`). No se crea un `SEL_USUARIO_BY_ID`. Menos objetos que mantener.

---

## 5. `INS_` — insertar y devolver el id

Abre [`02_INS_USUARIO.sql`](../02-Ejemplo-Usuario/BD/02_INS_USUARIO.sql).

### Estructura

```sql
CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO]
    @ID INT = NULL OUTPUT,      -- SIEMPRE primero
    @RUT NVARCHAR(12),
    ...
    @USUARIO INT                -- SIEMPRE último
AS
SET NOCOUNT ON

-- 1. Validaciones (FUERA de la transacción)
BEGIN
    IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_EMAIL = @EMAIL)
    BEGIN
        RAISERROR('1.- Ya existe un usuario con el email "%s".', 16, 1, @EMAIL)
        RETURN -1
    END
END

-- 2. Transacción
BEGIN TRANSACTION
    INSERT USUARIO (...) VALUES (...)
    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        ...
        EXEC INS_EXCEPCION @MSG = '...', @VARIABLES = @VARIABLES
        RETURN -1
    END
COMMIT TRANSACTION

RETURN(0)
```

### `@ID OUTPUT` + `SCOPE_IDENTITY()`

El id lo genera SQL Server (`IDENTITY`), así que el C# no lo sabe hasta que el SP se lo devuelve:

```sql
SET @ID = SCOPE_IDENTITY()
```

```csharp
cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;
// ...
id = (int)cmdExecute.Parameters["@ID"].Value;
respuesta.codigo = id;
```

**Por qué `SCOPE_IDENTITY()` y no `@@IDENTITY`:** `@@IDENTITY` devuelve el último identity generado en la sesión, **incluyendo los que generen los triggers**. Si mañana alguien agrega un trigger de auditoría a `USUARIO`, `@@IDENTITY` te devolvería el id de la tabla de log en vez del usuario. `SCOPE_IDENTITY()` se limita al ámbito actual. Es un bug real y difícil de encontrar.

### Validaciones ANTES de la transacción

```sql
-- ✓ correcto: validar y salir sin abrir transacción
IF EXISTS (...) BEGIN RAISERROR(...); RETURN -1 END
BEGIN TRANSACTION
```

No tiene sentido abrir una transacción para cerrarla inmediatamente. Validas, y si falla te vas.

### `RAISERROR` — el mensaje llega al usuario final

```sql
RAISERROR('1.- Ya existe un usuario con el email "%s".', 16, 1, @EMAIL)
```

- `%s` es un marcador de sustitución, como `String.Format`. El valor va al final.
- `16` es la severidad: nivel de "error corregible por el usuario". Es el que hace que .NET lance una `SqlException`.
- `1` es el estado (para distinguir de dónde vino, si el mismo mensaje aparece varias veces).

Y aquí lo importante: **este texto es el que ve el usuario final en pantalla**, porque el `catch` del Controller hace `respuesta.detalle = ex.Message` y la pantalla lo muestra en un `ClientAlert`.

Consecuencia práctica: escribe estos mensajes en español, claros, sin jerga técnica. Nada de "FK violation on USU_PERFIL".

Los mensajes se **numeran** (`1.-`, `2.-`) para poder identificar cuál validación falló cuando hay varias.

### `INS_EXCEPCION` — la bitácora de errores

```sql
IF @@ROWCOUNT = 0 BEGIN
    ROLLBACK TRANSACTION
    DECLARE @VARIABLES VARCHAR(MAX)
    SET @VARIABLES = 'INS_USUARIO @RUT = ' + @RUT + ',@EMAIL = ' + @EMAIL

    EXEC INS_EXCEPCION @MSG = '3.- NO FUE POSIBLE INSERTAR EL USUARIO.',
                       @VARIABLES = @VARIABLES
    RETURN -1
END
```

`INS_EXCEPCION` escribe en una tabla de log. La regla de `@VARIABLES`: **tiene que permitir reproducir la llamada**. Si el log dice solo "no se pudo insertar", no sirve para nada. Si dice qué parámetros llegaron, puedes reproducir el error en desarrollo.

---

## 6. `UPD_` — el truco de `ISNULL`

Abre [`03_UPD_USUARIO.sql`](../02-Ejemplo-Usuario/BD/03_UPD_USUARIO.sql).

```sql
UPDATE  USUARIO
SET      USU_RUT        = ISNULL(@RUT,      USU_RUT)
        ,USU_NOMBRES    = ISNULL(@NOMBRES,  USU_NOMBRES)
        ,USU_PASSWORD   = ISNULL(@PASSWORD, USU_PASSWORD)
        ,USU_USUARIO_ACT = @USUARIO
        ,USU_FECHA_ACT   = GETDATE()
WHERE   USU_ID = @ID
```

`ISNULL(@PARAM, columna_actual)` significa: *"si me mandaron el parámetro, úsalo; si no, deja el valor que ya tenía"*.

Esto permite **updates parciales con un solo SP**. El botón "Deshabilitar" del grid manda solo `@ID`, `@HABILITADO` y `@USUARIO` — el resto de columnas queda intacto. No hace falta un `UPD_USUARIO_HABILITADO` aparte.

El caso más elegante es la contraseña:

```csharp
if (!string.IsNullOrEmpty(usuario.usu_password))
    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
```

Si el usuario no escribió contraseña nueva, el parámetro no se manda, llega `NULL`, y `ISNULL` conserva la actual. Sin `ISNULL` habría que traer la contraseña actual, mandarla de vuelta y guardarla otra vez — con el riesgo de exponerla en el camino.

### `@ID` y `@USUARIO` son obligatorios

Van **sin** `= NULL`. Si un `UPDATE` no supiera a quién actualizar, o quién lo hizo, la auditoría no sirve. Hacerlos obligatorios convierte ese error en un error de compilación de la llamada, no en un dato corrupto.

### La validación de unicidad cambia

```sql
IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_EMAIL = @EMAIL AND USU_ID <> @ID)
```

El `AND USU_ID <> @ID` es imprescindible: al editar sin cambiar el email, el propio registro haría match y el SP diría "ya existe". Se excluye a sí mismo.

---

## 7. `DEL_` — el que casi no se usa

Abre [`04_DEL_USUARIO.sql`](../02-Ejemplo-Usuario/BD/04_DEL_USUARIO.sql). Es el más simple: recibe `@ID` y borra.

**Pero la regla del proyecto es no usarlo en tablas maestro.** En `USUARIO`, `PERFIL`, `CLIENTE` se hace **baja lógica** con `UPD_ ... @HABILITADO = 0`.

| Tipo de tabla | Baja |
|---|---|
| Maestro (`USUARIO`, `PERFIL`, `CLIENTE`) | Lógica: `UPD_` con `HABILITADO = 0` |
| Detalle / relación (`USUARIO_INSTALACION`) | Física: `DEL_` |

Razones: conservar la historia, no romper FK de registros que referencian al usuario, y poder reactivar.

Por eso el `UsuarioController` expone `DeshabilitarUsuario()` y es ése el que llama el botón del grid — no `DeleteUsuario()`.

---

## 8. Crear una tabla nueva

Abre [`00_TBL_USUARIO.sql`](../02-Ejemplo-Usuario/BD/00_TBL_USUARIO.sql).

```sql
IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[USUARIO]') AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[USUARIO] (...)
    PRINT 'Tabla USUARIO creada correctamente.'
END
ELSE
    PRINT 'Tabla USUARIO ya existe.'
GO
```

**Idempotente**: se puede ejecutar N veces sin error. En un CAPSTONE con varios integrantes ejecutando scripts en distintos momentos, esto evita muchos problemas.

### Constraints con nombre explícito

| Prefijo | Tipo |
|---|---|
| `PK_` | Primary key |
| `FK_` | Foreign key |
| `DF_` | Default |
| `IX_` | Índice |
| `UX_` | Índice único |

Si no le pones nombre, SQL Server genera algo como `PK__USUARIO__3213E83F...`. Cuando necesites hacer un `DROP CONSTRAINT` no vas a saber cuál es, y el nombre autogenerado es distinto en cada base — el script de desarrollo no funciona en producción.

---

## 9. Checklist para una entidad nueva

1. `00_TBL_<TABLA>.sql` — tabla idempotente, prefijo de 3 letras, auditoría, constraints con nombre
2. `01_SEL_<TABLA>.sql` — `@ID`, `@FILTRO`, `@HABILITADO` y FKs, todos `= NULL`; `@SELECT`/`@FROM`/`@WHERE` + `EXEC`
3. `02_INS_<TABLA>.sql` — `@ID OUTPUT` primero, validaciones antes de la transacción, `SCOPE_IDENTITY()`
4. `03_UPD_<TABLA>.sql` — `@ID` y `@USUARIO` obligatorios, resto con `ISNULL`
5. `04_DEL_<TABLA>.sql` — solo si es tabla de detalle
6. Encabezado estándar en los cuatro
7. `INS_EXCEPCION` en los tres de escritura
8. **Guardar en UTF-8 con BOM**

---

## 10. Errores frecuentes

| Error | Causa | Solución |
|---|---|---|
| "Procedure expects parameter @X" | Falta el `= NULL` en la firma | Agregar `= NULL` a todo filtro |
| El filtro no filtra | Falta el `IF (@X IS NOT NULL)` | Envolver el `AND` en su `IF` |
| Sintaxis incorrecta en la query dinámica | Comillas mal escapadas | Descomentar el `--print` y leer la query |
| `@ID` vuelve en 0 | Falta `Direction = Output` en C# | Agregarlo en el `AddWithValue` |
| El update borra campos | Se asignó `@PARAM` directo | Usar `ISNULL(@PARAM, columna)` |
| "Ya existe" al editar sin cambiar nada | Falta `AND ID <> @ID` | Excluir el propio registro |
| Id equivocado tras un trigger | Se usó `@@IDENTITY` | Usar `SCOPE_IDENTITY()` |
