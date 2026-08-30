# Patrón de Stored Procedures — SQL Server

Cómo se escriben los Stored Procedures en los proyectos del grupo. Aplica a
cualquier base (`FacilityGes`, `SGF`, `Agendamientos`, `Workges`...): lo único
que cambia es el `USE [<BaseDatos>]`.

Complementa [`PATRON_TABLAS.md`](PATRON_TABLAS.md) (DDL de tablas).

> **Regla base del stack**: el C# nunca ejecuta SQL embebido. Todo acceso a
> datos pasa por un SP. Por eso cada entidad nueva nace con sus 4 SPs.

---

## 1. Encabezado estándar

Todo script de creación/modificación de un SP empieza así:

```sql
USE [<BaseDatos>]
GO
/****** Objeto:  StoredProcedure [dbo].[<NOMBRE_SP>]    Fecha de script: <DD-MM-AAAA HH:MM:SS> ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          <NOMBRE AUTOR o "CRUD">
-- FECHA CREACIÓN:  <DD-MM-AAAA>
-- DESCRIPTION:     <QUÉ HACE EL SP, EN MAYÚSCULAS>
-- =============================================
ALTER PROCEDURE [dbo].[<NOMBRE_SP>]
    @PARAM1 TIPO,
    @PARAM2 TIPO = NULL
AS
SET NOCOUNT ON
```

Reglas:

- `ALTER PROCEDURE` cuando el SP **ya existe** (lo más común al editar).
  `CREATE OR ALTER PROCEDURE` para SPs **nuevos**.
- El comentario `/****** Objeto: ... ******/` es el que genera SSMS con
  "Script Stored Procedure as → ALTER". Se mantiene tal cual.
- El bloque `AUTHOR / FECHA CREACIÓN / DESCRIPTION` va **siempre**, con
  `DESCRIPTION` corta y en MAYÚSCULAS describiendo la acción (INSERTA,
  SELECT REGISTRO, ACTUALIZA, ELIMINA...).
- Cada SP en su propio script, con su propio encabezado. Si un archivo `.sql`
  agrupa varios SPs, cada uno repite el bloque completo separado por `GO`.

---

## 2. Convención de nombres

| Prefijo | Uso |
|---|---|
| `SEL_<TABLA>` | Consulta/listado. También sirve de "get by id" pasando `@ID` |
| `INS_<TABLA>` | Inserción |
| `UPD_<TABLA>` | Actualización |
| `DEL_<TABLA>` | Eliminación física |
| `API_<NOMBRE>` | SPs consumidos por la API/app móvil |
| `FNC_<NOMBRE>` | Funciones escalares o de tabla |

`<TABLA>` es el nombre de la tabla en MAYÚSCULAS con `_`:
`Cliente_Tarea` → `SEL_CLIENTE_TAREA`, `INS_CLIENTE_TAREA`...

Variantes puntuales: cuando hace falta actualizar **un solo campo** desde la
UI (orden en grilla, estado, flag), se crea un SP acotado en vez de sobrecargar
el `UPD_` general: `UPD_<TABLA>_<CAMPO>` (ej. `UPD_CLIENTE_TAREA_ORDEN`).

---

## 3. SP de INSERT — `INS_<TABLA>`

```sql
ALTER PROCEDURE [dbo].[INS_<TABLA>]
@ID INT = NULL OUTPUT,
@<FK_PADRE> INT,
@NOMBRE VARCHAR(200),
@DESCRIPCION VARCHAR(500) = NULL,
@USUARIO INT

AS
SET NOCOUNT ON

-- Validaciones de negocio (opcional, ANTES de la transacción)
BEGIN
    IF EXISTS (SELECT 1 FROM <Tabla> WHERE <PFX>_NOMBRE = @NOMBRE AND <PFX>_<FK_PADRE> = @<FK_PADRE>)
    BEGIN
        RAISERROR('1. Ya existe un registro con "%s".', 16, 1, @NOMBRE)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT <Tabla>
        (
            <PFX>_<FK_PADRE>,
            <PFX>_NOMBRE,
            <PFX>_DESCRIPCION,
            <PFX>_HABILITADO,
            <PFX>_USUARIO_CREACION,
            <PFX>_FECHA_CREACION,
            <PFX>_USUARIO_ACTUALIZACION,
            <PFX>_FECHA_ACTUALIZACION
        )
    VALUES
        (
            @<FK_PADRE>,
            @NOMBRE,
            @DESCRIPCION,
            1,
            @USUARIO,
            GETDATE(),
            @USUARIO,
            GETDATE()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_<TABLA> ' + LTRIM(STR(ISNULL(@ID, 0)))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE INSERTAR EL REGISTRO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
```

Reglas:

- `@ID INT = NULL OUTPUT` **siempre primero**, para devolver el id generado
  con `SCOPE_IDENTITY()`. El Controller lo lee como `ParameterDirection.Output`.
- Validaciones de negocio (duplicados, cupos, solapamientos) **antes** de
  `BEGIN TRANSACTION`, con `RAISERROR(...)` + `RETURN -1`.
- `BEGIN TRANSACTION` … `COMMIT TRANSACTION`, con `ROLLBACK` +
  `EXEC INS_EXCEPCION` si `@@ROWCOUNT = 0`.
- El insert escribe **los cuatro** campos de auditoría: creación y
  actualización con el mismo valor inicial.
- `RETURN(0)` al final si todo salió bien; `RETURN -1` en errores controlados.

---

## 4. SP de SELECT — `SEL_<TABLA>`

Patrón dinámico con `@SELECT` / `@FROM` / `@WHERE` concatenados y ejecutados
con un único `EXEC(...)`. Todos los filtros son `= NULL` (opcionales), salvo
los obligatorios del negocio.

```sql
ALTER PROCEDURE [dbo].[SEL_<TABLA>]
@ID INT = NULL,
@<FK_PADRE> INT = NULL,
@NOMBRE VARCHAR(200) = NULL,
@HABILITADO BIT = NULL,
@FILTRO VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET @SELECT = 'SELECT DISTINCT <PFX>_ID
                                 ,<PFX>_<FK_PADRE>
                                 ,<PFX>_NOMBRE
                                 ,<PFX>_DESCRIPCION
                                 ,<PFX_PADRE>_NOMBRE AS <PADRE>_NOMBRE
                                 ,<PFX>_USUARIO_CREACION
                                 ,<PFX>_FECHA_CREACION
                                 ,<PFX>_USUARIO_ACTUALIZACION
                                 ,<PFX>_FECHA_ACTUALIZACION
                                 ,<PFX>_HABILITADO
                 '
END

--FROM
BEGIN
   DECLARE @FROM VARCHAR(MAX)
   SET @FROM = ' FROM <Tabla>
                 INNER JOIN <Tabla_Padre> ON <PFX>_<FK_PADRE> = <PFX_PADRE>_ID
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

    IF (@<FK_PADRE> IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_<FK_PADRE> = ' + LTRIM(@<FK_PADRE>)
    END

    IF (@NOMBRE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_NOMBRE = ''' + LTRIM(REPLACE(@NOMBRE, '''', '''''')) + ''''
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND <PFX>_HABILITADO = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (<PFX>_NOMBRE LIKE ''%' + LTRIM(@FILTRO) + '%''
                                 OR <PFX>_DESCRIPCION LIKE ''%' + LTRIM(@FILTRO) + '%''
                               )'
    END

    SET @WHERE = @WHERE + ' ORDER BY <PFX>_NOMBRE '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
```

Reglas:

- `WHERE 1=1` siempre como base, para concatenar `AND` sin condicionales.
- Un bloque `IF (@PARAM IS NOT NULL) BEGIN ... END` por filtro.
- Parámetros **numéricos**: concatenar con `LTRIM(@PARAM)`.
- Parámetros **de texto**: escapar la comilla simple con
  `REPLACE(@PARAM, '''', '''''')` antes de concatenar. Esto es obligatorio:
  sin el escape, un apóstrofo en el filtro rompe el SP (y abre inyección).
- Dejar comentado un `--print(@SELECT + @FROM + @WHERE)` para depurar.
- Un único `EXEC(@SELECT + @FROM + @WHERE)` al final.
- El mismo SP sirve para el listado, para el "get by id" (`@ID`) y para poblar
  combos (`@HABILITADO = 1`). No crear un SP aparte por cada caso.
- Si el listado alimenta también un informe Excel, usar un parámetro
  `@EXCEL BIT = 0` que cambie el `@SELECT` (columnas técnicas vs. encabezados
  en español), en vez de duplicar el SP.

---

## 5. SP de UPDATE — `UPD_<TABLA>`

```sql
ALTER PROCEDURE [dbo].[UPD_<TABLA>]
@ID INT,
@NOMBRE VARCHAR(200) = NULL,
@DESCRIPCION VARCHAR(500) = NULL,
@USUARIO INT,
@HABILITADO BIT = NULL

AS
SET NOCOUNT ON

BEGIN TRANSACTION

   UPDATE  <Tabla>
   SET     <PFX>_NOMBRE      = ISNULL(@NOMBRE, <PFX>_NOMBRE)
          ,<PFX>_DESCRIPCION = @DESCRIPCION
          ,<PFX>_USUARIO_ACTUALIZACION = @USUARIO
          ,<PFX>_FECHA_ACTUALIZACION   = GETDATE()
          ,<PFX>_HABILITADO  = ISNULL(@HABILITADO, <PFX>_HABILITADO)
   WHERE   <PFX>_ID = @ID

   IF @@ROWCOUNT = 0 BEGIN
       ROLLBACK TRANSACTION
       DECLARE @VARIABLES VARCHAR(MAX)
       SET @VARIABLES = 'UPD_<TABLA> ' +
                        '@ID = ' + LTRIM(STR(@ID)) + ',' +
                        '@NOMBRE = ' + ISNULL(@NOMBRE, '')

       EXEC INS_EXCEPCION
           @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL REGISTRO.',
           @VARIABLES = @VARIABLES
       RETURN -1
   END

COMMIT TRANSACTION
RETURN(0)
```

Reglas:

- `@ID` y `@USUARIO` obligatorios (sin `= NULL`); el resto opcionales.
- Campos que se actualizan **parcialmente** → `ISNULL(@PARAM, columna_actual)`
  (patrón obligatorio para `@HABILITADO`, que se usa para la baja lógica).
- Campos que sí deben poder quedar en blanco → asignar el parámetro directo
  (`@DESCRIPCION`), no `ISNULL`.
- En proyectos **multi-país**, la fecha se calcula con la hora local del país
  de la entidad en vez de `GETDATE()`:

```sql
DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = <PFX_PADRE>_PAIS FROM <Tabla_Padre> WHERE <PFX_PADRE>_ID = @<FK_PADRE>
SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
```

  En proyectos mono-país: `GETDATE()`.

---

## 6. SP de DELETE — `DEL_<TABLA>`

```sql
ALTER PROCEDURE [dbo].[DEL_<TABLA>]
@ID INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

	DELETE	<Tabla>
	WHERE	<PFX>_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'DEL_<TABLA> ' + LTRIM(STR(@ID))

		EXEC INS_EXCEPCION
			@MSG = '1.- NO FUE POSIBLE ELIMINAR EL REGISTRO.',
			@VARIABLES = @VARIABLES
		RETURN -1
	END

COMMIT TRANSACTION

RETURN(0)
```

Reglas:

- Solo recibe `@ID` (y `@USUARIO` si la BD audita el borrado por trigger).
- Borrado **físico** solo en tablas de detalle/relación.
- En tablas **maestro** no se crea `DEL_`: la baja es lógica con
  `UPD_<TABLA>` y `@HABILITADO = 0`.
- Si la entidad tiene hijos, borrar primero el detalle dentro de la misma
  transacción (o dejar que la FK falle y devolver el error controlado).

---

## 7. Manejo de errores — `INS_EXCEPCION`

Todos los `IF @@ROWCOUNT = 0` de los SPs de escritura siguen el mismo patrón:

```sql
ROLLBACK TRANSACTION
DECLARE @VARIABLES VARCHAR(MAX)
SET @VARIABLES = '<NOMBRE_SP> ' + <parámetros concatenados con LTRIM/STR>

EXEC INS_EXCEPCION
    @MSG = '<N>.- <MENSAJE EN MAYÚSCULAS TERMINADO EN PUNTO>',
    @VARIABLES = @VARIABLES
RETURN -1
```

- `@VARIABLES` debe permitir **reproducir la llamada**: nombre del SP + valores
  recibidos.
- Numerar los mensajes (`'1.- ...'`, `'2.- ...'`) cuando el SP tiene más de una
  validación.
- Si la BD destino no tiene `INS_EXCEPCION`, crearlo o quitar los `EXEC`
  (ver [`../README.md`](../README.md) §3.2) — pero mantener el `ROLLBACK` y el
  `RETURN -1`.

---

## 8. Checklist al crear los SPs de una entidad nueva

1. `INS_<TABLA>` — `@ID OUTPUT` primero, validaciones previas, transacción,
   las 4 columnas de auditoría.
2. `SEL_<TABLA>` — `@ID`, FKs, `@HABILITADO`, `@FILTRO`; patrón
   `@SELECT`/`@FROM`/`@WHERE` + `EXEC`; escape de comillas en los textos.
3. `UPD_<TABLA>` — `@ID` y `@USUARIO` obligatorios, resto con `ISNULL`.
4. `DEL_<TABLA>` — solo si corresponde borrado físico.
5. Encabezado estándar completo en cada SP (§1).
6. `INS_EXCEPCION` en los 3 SPs de escritura.
7. Probar cada SP en SSMS antes de tocar el C#:
   `EXEC SEL_<TABLA> @ID = 1` / `EXEC INS_<TABLA> ...`.
8. Guardar el `.sql` en **UTF-8 con BOM**
   (ver [`../CONVENCIONES.md`](../CONVENCIONES.md) §2).
