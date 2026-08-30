# Mantenedor generado: Cliente (CLIENTE)

Generado el 14-08-2026 por `03-Generador` a partir de la definicion de la entidad.

- Base de datos: **SIGMA**
- Namespaces: `Sigma.Model` / `Sigma.Controller`
- Modulo / submodulo: `Comun` / `Clientes`
- Menu de permisos: `SitioBase.Paginas.menu_1`
- Tipo de tabla: **maestro** (baja logica con HABILITADO = 0)

---

## Archivos generados

- `App_Code/MVC/Sigma/Controller/ClienteController.cs`
- `App_Code/MVC/Sigma/Model/Cliente.cs`
- `BD/00_TBL_CLIENTE.sql`
- `BD/01_SEL_CLIENTE.sql`
- `BD/02_INS_CLIENTE.sql`
- `BD/03_UPD_CLIENTE.sql`
- `BD/04_DEL_CLIENTE.sql`
- `View/Comun/Clientes/Cliente.aspx`
- `View/Comun/Clientes/Cliente.aspx.cs`
- `View/Comun/Clientes/Clientes.aspx`
- `View/Comun/Clientes/Clientes.aspx.cs`
- `View/Comun/Controls/Cliente/Cliente.ascx`
- `View/Comun/Controls/Cliente/Cliente.ascx.cs`
- `View/Comun/Controls/Cliente/Clientes.ascx`
- `View/Comun/Controls/Cliente/Clientes.ascx.cs`
- `View/Comun/Controls/Cliente/Identidad.ascx`
- `View/Comun/Controls/Cliente/Identidad.ascx.cs`

---

## Pasos para dejarlo funcionando

### 1. Base de datos

Ejecutar en **este orden** sobre `SIGMA`:

```
BD/00_TBL_CLIENTE.sql
BD/01_SEL_CLIENTE.sql
BD/02_INS_CLIENTE.sql
BD/03_UPD_CLIENTE.sql
BD/04_DEL_CLIENTE.sql
```

Los scripts son idempotentes (`IF NOT EXISTS` / `CREATE OR ALTER`): se pueden
re-ejecutar sin romper nada.

### 2. Copiar los archivos al proyecto Web

Copiar respetando la estructura de carpetas:

```
App_Code/MVC/Sigma/Model/Cliente.cs
App_Code/MVC/Sigma/Controller/ClienteController.cs
View/Comun/Controls/Cliente/
View/Comun/Clientes/
```

> Todos los archivos salen en **UTF-8 con BOM** y **CRLF**, como pide el patron.
> No los abras/guardes con un editor que cambie la codificacion.

### 4. Combos de la barra de filtros

El listado busca estos controles dentro de `FiltroAvanzado.ascx` con
`FindControl`. Si alguno no existe, el filtro simplemente no se aplica
(el codigo generado valida `!= null`), pero conviene agregarlos:

| Control | Contenido | Nota |
|---|---|---|
| `cboHabilitado` | Todos / Habilitados / Deshabilitados | ya existe en la mayoria de los proyectos |

### 5. Registrar el menu y los permisos

1. Agregar el enum `menu_1` en `SitioBase.Paginas` con, al menos:
   `Ver`, `Crear_Editar`, `Ver_Todo`.
2. Dar de alta el menu en la tabla de menus/funciones y asignar los permisos
   a los perfiles que correspondan.
3. Apuntar el item del menu a `~/View/Comun/Clientes/Clientes.aspx`.

### 6. Probar

| Accion | Que deberia pasar |
|---|---|
| Entrar al listado | Grid con los datos y la barra Nuevo / Deshabilitar |
| Click en Nuevo | Abre `Cliente.aspx` sin querystring (alta) |
| Guardar | Mensaje "Cliente creado con exito." |
| Click en el lapiz de una fila | Abre la ficha con los datos cargados |
| Guardar de nuevo | Mensaje "Cliente actualizado con exito." |
| Seleccionar filas + Deshabilitar | Confirmacion SweetAlert y luego el mensaje del Controller |
| Perfil sin Crear/Editar | El formulario se abre en modo consulta (ReadOnly) |

---

## Que NO genera el generador

- El enum de `SitioBase.Paginas` (paso 5).
- Los combos nuevos dentro de `FiltroAvanzado.ascx` (paso 4).
- Tabs adicionales del formulario: el generado trae solo `Identidad`.
  Para agregar otro, crear el `.ascx` hermano y registrarlo en
  `Cliente.ascx` + propagar `ReadOnly`/`IdCliente` en su `Page_PreRender`.
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
