# Mantenedor generado: Producto (PRODUCTO)

Generado el 14-08-2026 por `03-Generador` a partir de la definicion de la entidad.

- Base de datos: **SIGMA**
- Namespaces: `Sigma.Model` / `Sigma.Controller`
- Modulo / submodulo: `Inventario` / `Productos`
- Menu de permisos: `SitioBase.Paginas.menu_12`
- Tipo de tabla: **maestro** (baja logica con HABILITADO = 0)

---

## Archivos generados

- `App_Code/MVC/Sigma/Controller/ProductoController.cs`
- `App_Code/MVC/Sigma/Model/Producto.cs`
- `BD/00_TBL_PRODUCTO.sql`
- `BD/01_SEL_PRODUCTO.sql`
- `BD/02_INS_PRODUCTO.sql`
- `BD/03_UPD_PRODUCTO.sql`
- `BD/04_DEL_PRODUCTO.sql`
- `View/Inventario/Controls/Producto/Identidad.ascx`
- `View/Inventario/Controls/Producto/Identidad.ascx.cs`
- `View/Inventario/Controls/Producto/Producto.ascx`
- `View/Inventario/Controls/Producto/Producto.ascx.cs`
- `View/Inventario/Controls/Producto/Productos.ascx`
- `View/Inventario/Controls/Producto/Productos.ascx.cs`
- `View/Inventario/Productos/Producto.aspx`
- `View/Inventario/Productos/Producto.aspx.cs`
- `View/Inventario/Productos/Productos.aspx`
- `View/Inventario/Productos/Productos.aspx.cs`

---

## Pasos para dejarlo funcionando

### 1. Base de datos

Ejecutar en **este orden** sobre `SIGMA`:

```
BD/00_TBL_PRODUCTO.sql
BD/01_SEL_PRODUCTO.sql
BD/02_INS_PRODUCTO.sql
BD/03_UPD_PRODUCTO.sql
BD/04_DEL_PRODUCTO.sql
```

Los scripts son idempotentes (`IF NOT EXISTS` / `CREATE OR ALTER`): se pueden
re-ejecutar sin romper nada.

### 2. Copiar los archivos al proyecto Web

Copiar respetando la estructura de carpetas:

```
App_Code/MVC/Sigma/Model/Producto.cs
App_Code/MVC/Sigma/Controller/ProductoController.cs
View/Inventario/Controls/Producto/
View/Inventario/Productos/
```

> Todos los archivos salen en **UTF-8 con BOM** y **CRLF**, como pide el patron.
> No los abras/guardes con un editor que cambie la codificacion.

### 3. Dependencias (FK)

El codigo generado asume que estos Model/Controller **ya existen**
en `App_Code/MVC/Sigma`. Si alguno no existe, generalo primero.

| Columna | Tabla | Controller usado | Value / Text del combo |
|---|---|---|---|
| `PRO_CATEGORIA` | `CATEGORIA` | `CategoriaController.GetCategorias()` | `cat_id` / `cat_nombre` |
| `PRO_PROVEEDOR` | `PROVEEDOR` | `ProveedorController.GetProveedores()` | `prv_id` / `prv_nombre` |

### 4. Combos de la barra de filtros

El listado busca estos controles dentro de `FiltroAvanzado.ascx` con
`FindControl`. Si alguno no existe, el filtro simplemente no se aplica
(el codigo generado valida `!= null`), pero conviene agregarlos:

| Control | Contenido | Nota |
|---|---|---|
| `cboHabilitado` | Todos / Habilitados / Deshabilitados | ya existe en la mayoria de los proyectos |
| `cboCategoria` | Categoria | se carga desde `CategoriaController.GetCategorias` |
| `cboProveedor` | Proveedor | se carga desde `ProveedorController.GetProveedores` |

### 5. Registrar el menu y los permisos

1. Agregar el enum `menu_12` en `SitioBase.Paginas` con, al menos:
   `Ver`, `Crear_Editar`, `Ver_Todo`.
2. Dar de alta el menu en la tabla de menus/funciones y asignar los permisos
   a los perfiles que correspondan.
3. Apuntar el item del menu a `~/View/Inventario/Productos/Productos.aspx`.

### 6. Probar

| Accion | Que deberia pasar |
|---|---|
| Entrar al listado | Grid con los datos y la barra Nuevo / Deshabilitar |
| Click en Nuevo | Abre `Producto.aspx` sin querystring (alta) |
| Guardar | Mensaje "Producto creado con exito." |
| Click en el lapiz de una fila | Abre la ficha con los datos cargados |
| Guardar de nuevo | Mensaje "Producto actualizado con exito." |
| Seleccionar filas + Deshabilitar | Confirmacion SweetAlert y luego el mensaje del Controller |
| Perfil sin Crear/Editar | El formulario se abre en modo consulta (ReadOnly) |

---

## Que NO genera el generador

- El enum de `SitioBase.Paginas` (paso 5).
- Los combos nuevos dentro de `FiltroAvanzado.ascx` (paso 4).
- Tabs adicionales del formulario: el generado trae solo `Identidad`.
  Para agregar otro, crear el `.ascx` hermano y registrarlo en
  `Producto.ascx` + propagar `ReadOnly`/`IdProducto` en su `Page_PreRender`.
- Reglas de negocio propias: van en el SP (validaciones con `RAISERROR`)
  o en `btnGuardar_Click`.

---

## Regenerar

Si cambia la tabla, edita el JSON de definicion y volve a correr:

```
python generar.py --definicion <tu-definicion>.json --forzar
```

`--forzar` sobreescribe. Sin ese flag, los archivos que ya existen se respetan
(util cuando ya tocaste el codigo generado a mano).
