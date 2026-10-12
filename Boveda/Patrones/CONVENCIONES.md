# Convenciones obligatorias — WebForms (Website)

Reglas transversales a **todos** los proyectos WebForms del grupo. Se leen
antes de cualquier otro patrón. Desviarse de esto produce errores de
compilación, de runtime, o código que el equipo tiene que reescribir.

---

## 1. Nomenclatura

### 1.1 Base de datos

| Objeto | Convención | Ejemplo |
|---|---|---|
| **Tabla** | `Pascal_Snake_Case`: primera letra mayúscula y **mayúscula después de cada `_`** | `Cliente`, `Cliente_Tarea`, `Menu_Material_Apoyo`, `Usuario_App_Dispositivo` |
| **Columna** | `<pfx>_<nombre_descriptivo>` en minúsculas al declarar (DDL) | `cta_id`, `cta_nombre`, `cta_fecha_creacion` |
| **Columna (en SPs)** | El mismo nombre en MAYÚSCULAS | `CTA_ID`, `CTA_NOMBRE` |
| **Prefijo** | 3 letras derivadas del nombre de la tabla, único en la BD | `Cliente` → `cli`, `Cliente_Tarea` → `cta`, `Menu_Material_Apoyo` → `mma` |
| **Stored Procedure** | `<ACCION>_<TABLA>` en MAYÚSCULAS | `SEL_CLIENTE_TAREA`, `INS_CLIENTE_TAREA` |
| **Función** | `FNC_<NOMBRE>` | `FNC_PAIS_HORA` |
| **SP de API móvil** | `API_<NOMBRE>` | `API_SEL_TAREAS` |
| **Trigger** | `TRG_LOG_<Tabla>` | `TRG_LOG_Cliente_Tarea` |
| **PK / FK / Default / Índice** | `PK_<TABLA>`, `FK_<PFX>_<TABLA_REF>`, `DF_<PFX>_<COLUMNA>`, `IX_<PFX>_<COLUMNA>`, `UX_<PFX>_<COLUMNA>` | `PK_CLIENTE_TAREA`, `FK_CTA_CLIENTE` |

Detalle completo (derivación del prefijo, plantillas DDL, auditoría) en
[`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md).

### 1.2 C#

| Elemento | Convención | Ejemplo |
|---|---|---|
| Clase Model | PascalCase = nombre de la tabla **sin** guiones bajos | tabla `Cliente_Tarea` → clase `ClienteTarea` |
| Propiedades del Model | **igual al nombre de la columna**, minúsculas con prefijo | `cta_id`, `cta_nombre` |
| Campos de filtro del Model | `filtro`, `filtro_habilitado`, `filtro_<algo>` | `filtro_cliente` |
| Clase Controller | `<Entidad>Controller` | `ClienteTareaController` |
| Métodos del Controller | `Get<Entidad>s`, `Get<Entidad>`, `Insert<Entidad>`, `Update<Entidad>`, `Delete<Entidad>` | `GetClienteTareas` |
| Code-behind de UserControl | `partial class View_<Ruta_Con_Guiones_Bajos>` | `View_Comun_Controls_Cliente_Clientes` |
| Métodos de UI | `CargarGrid()`, `CargarDatos()`, `Bloqueo()`, `LoadControls()` | — |

> Las propiedades del Model **no** se traducen a PascalCase: se llaman igual
> que la columna (`cta_nombre`, no `CtaNombre`). Eso permite bindear el grid y
> los combos directamente con `DataValueField`/`DataTextField`/`DataKeyNames`.

### 1.3 IDs de controles en `.ascx` / `.aspx`

| Prefijo | Control |
|---|---|
| `txt` | `TextBox2`, `TextArea2`, `RadNumericBox2` (`txtNombre`, `txtMonto`) |
| `cbo` | `RadComboBox2`, `ComboBox2` (`cboPais`) |
| `chk` | `CheckBox`, `CheckBox2` (`chkHabilitado`) |
| `cal` / `dtp` | `Calendar` / selector de fecha |
| `btn` | `PushButton` (`btnGuardar`, `btnCerrar`) |
| `lnk` | `LinkButton` / `HyperLink` (`lnkNuevo`, `lnkEliminar`, `lnkEditar`) |
| `rgr` / `Grid` | `RadGrid2` (`Grid` cuando hay uno solo; `rgr<Entidad>` si hay varios) |
| `udPanel` | `asp:UpdatePanel` |
| `wuc` | UserControl registrado (`wucFiltro`, `wucClientes`) |
| `pnl` | `asp:Panel` |
| `lbl` / `ltl` | `asp:Label` / `asp:Literal` |
| `rwi` | `RadWindow2` |

### 1.4 Archivos y carpetas del sitio

```
<RaizWeb>/
├── App_Code/
│   ├── MVC/
│   │   ├── <Proyecto>/
│   │   │   ├── Controller/   <Entidad>Controller.cs
│   │   │   └── Model/        <Entidad>.cs
│   │   └── SitioBase/        Controller/Model transversales (Token, Menús, Usuario...)
│   ├── SitioBase/            Session.cs, Paginas.cs, SitioBase.cs
│   └── WebService/           Ws<Nombre>.cs  (código de los endpoints AJAX)
├── WebService/               Ws<Nombre>.asmx  (una línea, apunta al App_Code)
├── Css/, Js/, Master/
└── View/
    └── <Modulo>/
        ├── <SubModulo>/
        │   ├── <Entidad>s.aspx(.cs)   página listado
        │   └── <Entidad>.aspx(.cs)    página formulario
        └── Controls/
            └── <Entidad>/
                ├── <Entidad>s.ascx(.cs)   UserControl listado (grid)
                ├── <Entidad>.ascx(.cs)    UserControl formulario (tabs)
                └── <Tab>.ascx(.cs)        UserControl de cada tab
```

Regla: **el plural es el listado, el singular es el formulario**
(`Clientes.ascx` = grid, `Cliente.ascx` = ficha).

### 1.5 Idioma

- Nombres de columnas, propiedades, métodos de negocio: **español**.
- Textos de UI y mensajes al usuario: **español**, con tildes correctas.
- Mensajes de éxito del Controller: `"<Entidad> creado con éxito."` /
  `"<Entidad> actualizado con éxito."` / `"<Entidad> eliminado con éxito."`.
- Mensajes de error de `INS_EXCEPCION` (SQL): MAYÚSCULAS, numerados y
  terminados en punto: `'1.- NO FUE POSIBLE INSERTAR EL REGISTRO.'`.

---

## 2. Codificación de archivos (crítico)

Todos los archivos `.cs`, `.aspx`, `.ascx`, `.asmx`, `.sql`, `.css`, `.js` y
`.md` del proyecto están en **UTF-8 con BOM** (`EF BB BF`) y terminadores
**CRLF**. Sin BOM, las tildes y la `ñ` se corrompen al abrir en Visual Studio.

- Editar un archivo existente con `Edit` preserva el BOM.
- **Crear** un archivo nuevo con `Write` NO agrega BOM → hay que forzarlo:

```powershell
$p = 'C:\ruta\Archivo.cs'
$txt = [System.IO.File]::ReadAllText($p)
[System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($true)))
```

Verificar:

```powershell
Get-Content 'C:\ruta\Archivo.cs' -Encoding Byte -TotalCount 3
# debe devolver 239 187 191
```

---

## 3. TFS / TFVC

Los archivos bajo control de código fuente llegan **read-only**. Antes de
editar cualquier archivo:

```powershell
Set-ItemProperty -Path 'C:\ruta\Archivo.cs' -Name IsReadOnly -Value $false
```

Para varios archivos a la vez:

```powershell
Get-ChildItem -Path 'C:\ruta\Carpeta' -Recurse -File | Set-ItemProperty -Name IsReadOnly -Value $false
```

---

## 4. Prohibiciones (reglas duras)

| ❌ No hacer | ✔ En su lugar |
|---|---|
| SQL embebido / `CommandType.Text` en C# | Stored Procedures (`SEL_`/`INS_`/`UPD_`/`DEL_`) vía `Conexion.GetCommand(...)` |
| `.ashx` (WebHandler) para AJAX | ASMX ScriptService — ver [`Desarrollo/PATRON_WEBSERVICE_AJAX.md`](Desarrollo/PATRON_WEBSERVICE_AJAX.md) |
| Agregar un `ScriptManager` dentro de un UserControl | El master ya lo declara; usar `ScriptManager.GetCurrent(Page)` |
| Patterns de C# 7+ (`is Type x`, `??=`, expresiones switch) | Sintaxis clásica; el sitio compila con el compilador del Website (C# 5/6) |
| `ViewState["k"] as int` / null-conditional | `ViewState["k"] != null ? (int)ViewState["k"] : 0` |
| `TextBox2 ReadOnly="true"` en campos de contraseña | `Enabled="false"` (el `ReadOnly` renderiza un `<span>` con el texto plano) |
| Crear columnas/perfiles/catálogos "parecidos" a algo existente | Buscar primero si ya hay algo reutilizable y preguntar (§6) |
| Hardcodear ids de catálogos en SQL o C# | JOIN a la tabla de catálogo por su nombre/id documentado |
| Borrado físico en tablas maestro | Baja lógica: `UPD_` con `<pfx>_habilitado = 0` |
| `OnClientClick="cerrar()"` sin `return false;` | `OnClientClick="cerrar(); return false;"` (si no, dispara postback igual) |

---

## 5. Seguridad (siempre)

- **Controller**: toda operación empieza con `if (Token.TokenSeguridad())`.
- **Página**: `Page_Load` comienza con el bloque `#region SeguridadPagina` que
  llama a `SitioBase.Token.SecurityManagerVer(ver)`.
- **Permisos finos** (Ver Todo, Crear/Editar, Ver Todo Países...):
  `Token.SecurityManager(new MenuFuncion { mfu_id = (int)SitioBase.Paginas.menu_<N>.<Funcion> })`.
- **Querystring**: siempre cifrado con
  `Server.UrlEncode(Tools.Crypto.Encrypt("Param=" + valor + "&..."))` y leído
  con `Tools.Crypto.Decrypt(...)`. Nunca ids en claro en la URL.
- **Usuario que audita**: `Session.UsuarioId()` — nunca un id fijo ni tomado
  del cliente.

Detalle en [`Desarrollo/PATRON_SEGURIDAD_MENUS.md`](Desarrollo/PATRON_SEGURIDAD_MENUS.md).

---

## 6. Antes de crear algo nuevo en BD

Antes de un `ALTER TABLE ADD`, de un `INSERT` en una tabla de catálogo
(`Perfiles`, `Estados`, `Tipos`...) o de proponer una columna nueva:

1. Buscar si ya existe algo con la misma semántica, aunque el nombre sugiera
   otro flujo o etapa:

```sql
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%<palabra_clave>%'
ORDER BY TABLE_NAME;
```

2. Si existe pero con otra granularidad (cabecera vs. detalle, planificado vs.
   real), **preguntar** si se reutiliza antes de crear estructura paralela.
3. Precedente del grupo: se prefiere reutilizar el mismo campo/registro para
   dos usos cercanos antes que duplicar.

---

## 7. Manejo de errores y mensajes

| Capa | Patrón |
|---|---|
| SP | `IF @@ROWCOUNT = 0` → `ROLLBACK TRANSACTION` + `EXEC INS_EXCEPCION @MSG, @VARIABLES` + `RETURN -1` |
| Controller | `try/catch`; en `catch` cerrar conexión y devolver `respuesta.error = true`, `respuesta.detalle = ex.Message` |
| UI | `try/catch` + `Tools.tools.ClientAlert(mensaje, "ok" \| "alerta" \| "error", cerrarModal)` |

Nunca dejar un `catch` vacío que oculte el error sin avisar al usuario.

---

## 8. Verificación antes de dar por terminado

```bash
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe" -v "/Check" -p "C:\ruta\<RaizWeb>" "C:\temp\salida" -f
```

Debe terminar en `exitcode=0`. Los `warning CS0168` (variable de excepción no
usada) son preexistentes y normales en estos proyectos.


---

## Parámetros `OUTPUT` que deciden "existe o no existe"

**Se inicializan en `NULL` dentro del procedimiento. Siempre.**

```sql
SET @ID = NULL                      -- <- esta línea
SELECT @ID = rbs_id FROM ... WHERE ...
IF (@ID IS NULL) ... INSERT ... ELSE ... UPDATE ...
```

En SQL Server, un `SELECT @var = col FROM ... WHERE <sin filas>` **no toca la
variable**: conserva lo que ya tenía. Y los controllers de la web crean el
parámetro así:

```csharp
int id = 0;
cmd.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;
```

O sea que `@ID` **entra valiendo 0, no NULL**. Sin la línea de arriba, un
UPSERT se va por la rama del `UPDATE ... WHERE id = 0`, afecta cero filas y
**no da ningún error**: la pantalla dice que guardó y no guardó nada.

Pasó en `UPS_REPUESTO_BODEGA_STOCK`, `INS_REPUESTO_LOTE` e
`INS_INVENTARIO_MOVIMIENTO` (bloque **65**). En el tercero habría hecho que
todo movimiento con `uuid` se descartara en silencio, que es justo la
idempotencia de la que depende la app.

Se detectó **sembrando datos de prueba**, no leyendo el código: ocho llamadas
dejaron una sola fila.
