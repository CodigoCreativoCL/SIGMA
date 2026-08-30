# Generador de mantenedores

Genera un mantenedor CRUD completo a partir de un JSON con la tabla y sus columnas,
siguiendo al pie de la letra los patrones de [`00-Patrones-Originales/`](../00-Patrones-Originales/).

**Un mantenedor básico pasa de ~2 días a ~10 minutos**: se define el JSON, se ejecuta
el generador, se corren los `.sql`, se copian los archivos y se registra el menú.

---

## Qué genera (18 archivos por entidad)

| Capa | Archivos |
|---|---|
| **Base de datos** | `00_TBL_<TABLA>.sql`, `01_SEL_`, `02_INS_`, `03_UPD_`, `04_DEL_` |
| **Model** | `<Entidad>.cs` — POCO `[Serializable]` con columnas, auditoría, campos del JOIN y `filtro_*` |
| **Controller** | `<Entidad>Controller.cs` — `Get<Plural>`, `Get<Singular>`, `Insert`, `Update`, `Delete`, `Deshabilitar` |
| **UserControls** | `<Plural>.ascx(.cs)` listado, `<Singular>.ascx(.cs)` tabs, `Identidad.ascx(.cs)` formulario |
| **Páginas** | `<Plural>.aspx(.cs)` listado, `<Singular>.aspx(.cs)` ficha |
| **Documentación** | `_LEEME_<TABLA>.md` con el checklist de puesta en marcha |

Todo sale en **UTF-8 con BOM y CRLF**, como exige el patrón.

---

## Uso

### Opción A — interfaz gráfica (recomendada)

Doble clic en **`GENERADOR.bat`**, o bien:

```bash
pythonw interfaz.py
```

Aplicación de escritorio con cuatro pestañas:

| Pestaña | Qué se hace ahí |
|---|---|
| **1. Proyecto** | Base de datos, namespace, autor, rutas y los tags de los controles |
| **2. Entidad** | Nombre de la tabla — el resto se autocompleta solo — módulo, menú, tipo de tabla, auditoría, HABILITADO, seguridad por país |
| **3. Columnas** | Grilla de columnas con Agregar / Editar / Duplicar / Eliminar / Subir / Bajar. Doble clic edita |
| **4. Qué generar** | Un check por pieza: cada artefacto se genera de forma independiente |

Abajo: carpeta de salida, check *Sobreescribir*, botón **GENERAR** y una consola con el
resultado archivo por archivo.

- **Menú Ejemplos** carga una definición de referencia para ver cómo queda todo.
- **Archivo > Guardar definición** deja el `.json` para regenerar cuando cambie la tabla.
- Escribiendo la tabla se autocompletan prefijo, singular, plural, submódulo y títulos.
  Si renombrás la tabla de una definición ya cargada, el botón **Recalcular nombres**
  vuelve a derivarlos.

No requiere instalar nada: usa Tkinter, que viene con Python.

### Opción B — desde un JSON por consola

```bash
python generar.py --definicion ejemplos/producto.json
```

### Opción C — asistente por consola

```bash
python generar.py --asistente
```

Pregunta base de datos, namespace, tabla, prefijo, módulo, menú y luego cada columna.
Guarda la definición en `definiciones/<tabla>.json` y genera.

### Crear una definición en blanco para editar

```bash
python generar.py --ejemplo mi_entidad.json
```

### Otros comandos

```bash
python generar.py --validar mi.json
```

```bash
python generar.py --tipos
```

| Opción | Qué hace |
|---|---|
| `-d, --definicion` | JSON de la entidad |
| `-p, --proyecto` | JSON con la config común (base de datos, namespaces, rutas) |
| `-s, --salida` | Carpeta destino (por defecto `salida/<TABLA>`) |
| `-f, --forzar` | Sobreescribe lo que ya exista. **Sin este flag no se pisa nada** |
| `-i, --incluir` | Genera **solo** estas piezas |
| `-x, --excluir` | Genera todo **menos** estas piezas |
| `--piezas` | Lista las piezas y alias disponibles |
| `-a, --asistente` | Modo interactivo por consola |
| `-e, --ejemplo` | Escribe una definición de ejemplo |
| `-v, --validar` | Valida sin generar |
| `-t, --tipos` | Lista los tipos SQL soportados |

---

## Generación selectiva

Cada artefacto es una **pieza independiente**. Sirve para el caso habitual de "la tabla
y los SP ya existen, solo quiero las vistas", o "cambié una columna, regenerá únicamente
el Model y el Controller".

En la interfaz gráfica es la pestaña **4. Qué generar** (un check por pieza, más botones
*Todo* / *Nada* / *Solo base de datos* / *Solo Model + Controller* / *Solo vistas y páginas*).

Por consola:

```bash
python generar.py -d mi.json --incluir bd
```

```bash
python generar.py -d mi.json --incluir model,controller
```

```bash
python generar.py -d mi.json --excluir bd,leeme
```

| Pieza | Genera |
|---|---|
| `tabla` | `00_TBL_<TABLA>.sql` |
| `sel` `ins` `upd` `del` | los cuatro SP, por separado |
| `model` | `<Entidad>.cs` |
| `controller` | `<Entidad>Controller.cs` |
| `listado` | `<Plural>.ascx` + `.cs` |
| `formulario` | `<Singular>.ascx` + `.cs` (contenedor de tabs) |
| `tab` | `<Tab>.ascx` + `.cs` (campos y guardado) |
| `pagina_listado` | `<Plural>.aspx` + `.cs` |
| `pagina_formulario` | `<Singular>.aspx` + `.cs` |
| `leeme` | `_LEEME_<TABLA>.md` |

Alias de grupo: `bd`, `sp`, `mvc`, `crud`, `vistas`, `paginas`, `ui`, `doc`, `todo`.

Si una pieza seleccionada depende de otra que quedó fuera (por ejemplo, la página de
listado sin el UserControl de listado), el generador **avisa pero no bloquea**: lo normal
es que esa pieza ya exista en el proyecto.

---

## El archivo de definición

Mínimo viable:

```json
{
  "entidad": { "tabla": "BODEGA", "modulo": "Inventario" },
  "columnas": [
    { "nombre": "NOMBRE", "tipo": "NVARCHAR(200)", "requerido": true, "unico": true }
  ]
}
```

Con eso ya sale un mantenedor entero: el generador infiere prefijo (`BOD`), singular
(`Bodega`), plural (`Bodegas`), género (femenino → *"Bodega creada con éxito."*),
control de pantalla, anchos de grid, filtros y columnas de auditoría.

### Bloque `proyecto` — configurable al 100 %

```json
"proyecto": {
  "baseDatos": "SIGMA",
  "namespace": "Sigma",
  "autor": "EQUIPO CODIGO CREATIVO",
  "master": "~/Master/Default.master",
  "rutaAppCode": "App_Code/MVC/Sigma",
  "rutaView": "View",
  "controles": {
    "fecha": "rad:RadDatePicker2",
    "texto": "WebControls:TextBox2"
  }
}
```

`namespace: "Sigma"` genera `Sigma.Model` y `Sigma.Controller`. Para FacilityGes se pone
`"Facilityges"` y sale `Facilityges.Model` / `Facilityges.Controller`.

`controles` permite apuntar a los wrappers de cada proyecto sin tocar el generador.

> Si todos tus mantenedores comparten esta configuración, ponela en un `proyecto.json`
> y pasala con `--proyecto proyecto.json`. Lo que esté en la definición de la entidad
> tiene prioridad.

### Bloque `entidad`

| Campo | Efecto |
|---|---|
| `tabla` | **Único obligatorio.** Nombre en MAYÚSCULAS |
| `prefijo` | Prefijo de columnas. Por defecto las 3 primeras letras |
| `singular` / `plural` | Nombres en código. Se infieren de la tabla |
| `modulo` / `subModulo` | Rutas: `View/<modulo>/Controls/<Singular>/` y `View/<modulo>/<subModulo>/` |
| `menu` | Enum de `SitioBase.Paginas` para los permisos |
| `tipo` | `maestro` → botón **Deshabilitar** (baja lógica). `detalle` → **Eliminar** (DELETE físico) |
| `auditoria` | Agrega las 4 columnas de auditoría |
| `habilitado` | Agrega `HABILITADO` + su filtro |
| `seguridadPorPais` | Agrega `@PAISES` al SEL y el bloque `SeguridadPagina` al listado |
| `orden` | `ORDER BY` del SEL |

### Bloque `columnas`

**No declares `ID`, `HABILITADO` ni las de auditoría**: el generador las agrega y falla
si las declarás, para evitar duplicados.

```json
{
  "nombre": "CODIGO",
  "tipo": "NVARCHAR(20)",
  "requerido": true,
  "etiqueta": "Codigo",
  "unico": true,
  "upperCase": true
}
```

Lo que hace cada opción está en [`esquema/definicion.schema.json`](esquema/definicion.schema.json).
Si agregás `"$schema": "../esquema/definicion.schema.json"` arriba del JSON, VS Code
te autocompleta y valida mientras escribís.

Efectos que conviene conocer:

- **`unico: true`** → índice `UX_`, validación `RAISERROR` en `INS_` y en `UPD_`
  (excluyendo el propio registro).
- **`busqueda`** → la columna entra en el `LIKE` del `@FILTRO`. Por defecto **true**
  para textos cortos.
- **`filtro`** → parámetro propio en el SEL + lectura de un combo de la barra de
  filtros. Por defecto **true** para las FK.
- **`control: "password"`** → nunca se devuelve en el `SELECT`, en el `UPDATE` sólo
  viaja si el usuario la cambió, y se valida obligatoria sólo en el alta.
- **`gridAncho`** → si no lo ponés, los anchos se reparten automáticamente por peso
  según el tipo de columna.

### Foreign keys

```json
{
  "nombre": "CATEGORIA",
  "tipo": "INT",
  "requerido": true,
  "fk": {
    "tabla": "CATEGORIA",
    "prefijo": "CAT",
    "modelo": "Categoria",
    "controller": "CategoriaController",
    "metodoLista": "GetCategorias",
    "filtroHabilitado": "bool"
  }
}
```

Con eso el generador produce:

- constraint `FK_PRO_CATEGORIA` + índice `IX_PRO_CATEGORIA`
- `INNER JOIN CATEGORIA ON PRO_CATEGORIA = CAT_ID` en el SEL (`LEFT JOIN` si la columna
  es opcional)
- `CAT_NOMBRE` en el `SELECT` y propiedad `cat_nombre` en el Model
- columna del grid mostrando el **nombre**, no el id
- `RadComboBox2` con `OnLoad="LoadControls"` y su `case` en el `switch`
- parámetro `@CATEGORIA` de filtro + lectura del combo `cboCategoria` de la barra

Ojo con dos campos que se parecen pero son distintos:

| Campo | Es propiedad de | Se usa en |
|---|---|---|
| `propTexto` | el Model **referenciado** (`Paises.pai_nombres`) | `DataTextField` del combo |
| `propDenormalizada` | el Model de **esta** entidad (`Usuario.pai_nombre`) | columna del grid |

Si dos columnas apuntan a la misma tabla, el generador alias-ea el JOIN solo.

---

## Tipos soportados

`INT`, `BIGINT`, `TINYINT`, `SMALLINT`, `BIT`, `DECIMAL(p,e)`, `NUMERIC`, `MONEY`,
`FLOAT`, `REAL`, `CHAR`, `NCHAR`, `VARCHAR(n)`, `NVARCHAR(n)`, `NVARCHAR(MAX)`, `TEXT`,
`DATE`, `DATETIME`, `DATETIME2`, `TIME`, `UNIQUEIDENTIFIER`, `VARBINARY`, `IMAGE`, `XML`.

Control de pantalla inferido:

| Tipo SQL | Control |
|---|---|
| `NVARCHAR(n)` corto | `TextBox2` |
| `NVARCHAR(MAX)` o > 500 | `TextArea2` |
| `INT` / `DECIMAL` | `RadNumericBox2` |
| `INT` con `fk` | `RadComboBox2` |
| `BIT` | `CheckBox2` |
| `DATETIME` | `RadDatePicker` |
| nombre con `PASSWORD` / `CLAVE` | `TextBox2 TextMode="Password"` |

---

## Después de generar

El archivo `_LEEME_<TABLA>.md` que queda en la carpeta de salida trae el checklist
concreto. En resumen:

1. Ejecutar los 5 `.sql` en orden (son idempotentes, se pueden re-ejecutar).
2. Copiar los archivos al proyecto Web respetando las carpetas.
3. Verificar que existan los Model/Controller de las tablas referenciadas por FK.
4. Agregar los combos de filtro a `FiltroAvanzado.ascx` (opcional: si no están, el
   filtro simplemente no se aplica).
5. Declarar el enum `menu_N` en `SitioBase.Paginas` y dar de alta el menú y permisos.

---

## Lo que el generador NO hace

Y es a propósito, porque son decisiones de negocio:

- El enum de `SitioBase.Paginas` y el alta del menú en base de datos.
- Los combos nuevos dentro de `FiltroAvanzado.ascx`.
- Tabs adicionales del formulario: genera uno (`Identidad`). Para agregar otro se crea
  el `.ascx` hermano, se registra en `<Singular>.ascx` y se propagan `ReadOnly` /
  `Id<Singular>` en su `Page_PreRender`.
- Reglas de negocio propias: van en el SP (`RAISERROR`) o en `btnGuardar_Click`.

### Limitación heredada del patrón

El `UPD_` usa `ISNULL(@PARAM, columna_actual)` en todas las columnas. Eso permite
updates parciales con un solo SP, pero implica que **una columna opcional no se puede
volver a dejar en NULL desde la pantalla** (mandar `NULL` significa "no tocar"). Si una
entidad necesita limpiar un campo, hay que sacarle el `ISNULL` a esa columna a mano
en el `UPD_` generado. Es el mismo comportamiento que tiene hoy el código escrito a mano.

---

## Verificar contra el patrón

`ejemplos/usuario.json` reproduce el mantenedor de
[`02-Ejemplo-Usuario/`](../02-Ejemplo-Usuario/), que está escrito a mano. Sirve como
prueba de regresión: si tocás una plantilla, regenerá y compará.

```bash
python generar.py -d ejemplos/usuario.json -f
```

---

## Estructura del generador

```
03-Generador/
├── GENERADOR.bat               lanzador de la interfaz grafica  <-- empezar aca
├── interfaz.py                 aplicacion de escritorio (Tkinter)
├── generar.py                  CLI y motor de generacion
├── generar.bat                 lanzador de consola
├── nucleo/
│   ├── definicion.py           lee y valida el JSON, aplica los defaults
│   ├── piezas.py               catalogo de piezas generables y dependencias
│   ├── tipos.py                mapeo SQL <-> C# <-> control
│   ├── escritor.py             escritura UTF-8 BOM + CRLF
│   ├── asistente.py            modo interactivo de consola
│   └── util.py                 texto y motor de plantillas {{TOKEN}}
├── plantillas/
│   ├── sql.py                  tabla + SEL / INS / UPD / DEL
│   ├── modelo.py               Model
│   ├── controlador.py          Controller
│   ├── vistas.py               .ascx + .ascx.cs
│   ├── paginas.py              .aspx + .aspx.cs
│   └── documentacion.py        _LEEME_<TABLA>.md
├── ejemplos/                   definiciones de referencia
└── esquema/                    JSON Schema para el editor
```

Para cambiar cómo se ve el código generado se toca **una sola** plantilla y todos los
mantenedores futuros salen con el cambio.
