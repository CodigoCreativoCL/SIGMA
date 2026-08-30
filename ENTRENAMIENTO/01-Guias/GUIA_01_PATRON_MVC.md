# Guía 01 — Patrón MVC (WebForms con capa Model/Controller propia)

> Archivo original: [`../00-Patrones-Originales/PATRON_MVC.md`](../00-Patrones-Originales/PATRON_MVC.md)
> Código de ejemplo: [`../02-Ejemplo-Usuario/`](../02-Ejemplo-Usuario/)
> Duración estimada de la sesión: **45 min**

---

## 1. Lo primero que hay que desmontar

El proyecto **NO es ASP.NET MVC**. Es **Web Forms**.

Si alguien del equipo llega con la idea de ASP.NET MVC (rutas, `ActionResult`, Razor, `_ViewStart`), va a escribir código que no compila con el resto. Lo que tenemos es:

| ASP.NET MVC "de verdad" | Lo que usamos nosotros |
|---|---|
| Ruta → Controller → Action → View | URL → archivo `.aspx` físico |
| `ActionResult`, `return View(model)` | Postback + `ViewState` |
| Razor (`.cshtml`) | `.aspx` / `.ascx` con controles de servidor |
| `Controller` = punto de entrada HTTP | `Controller` = **capa de acceso a datos**, nada más |

**La idea clave para el equipo:** en este proyecto, "Controller" no significa "controlador HTTP". Significa **la clase que habla con la base de datos**. Es una separación manual, hecha a mano por el equipo, para que las páginas no tengan SQL adentro.

Analogía útil en la capacitación: es un **repositorio** disfrazado de controller.

---

## 2. Las 4 capas y quién puede hablar con quién

```
   .aspx (Página)
        │  setea permisos y propiedades
        ▼
   .ascx (UserControl: listado o formulario)
        │  arma el Model de filtros / lee los controles
        ▼
   Controller  (Sigma.Controller)
        │  abre conexión y ejecuta el Stored Procedure
        ▼
   Stored Procedure (SEL_ / INS_ / UPD_ / DEL_)
        │
        ▼
   Tabla SQL Server
```

**Regla de oro, y es la que más se rompe:** cada capa habla **solo con la de abajo**.

- Una página nunca abre un `SqlConnection`.
- Un `.ascx.cs` nunca escribe `SELECT`.
- Un Controller nunca sabe que existe un `RadGrid2`.
- Un Stored Procedure nunca sabe quién lo llamó.

El **Model** no es una capa: es el **sobre** en el que viajan los datos entre capas. Cruza todas.

---

## 3. Dónde va cada archivo

```
Web/Intranet/
├── App_Code/
│   └── MVC/
│       ├── Sigma/                       (el dominio de NUESTRO proyecto)
│       │   ├── Controller/  <Entidad>Controller.cs
│       │   └── Model/       <Entidad>.cs
│       └── SitioBase/                   (infraestructura común: Token, Session, Conexion...)
└── View/
    └── <Modulo>/                        (Seguridad, Comercial, Comun, ...)
        ├── <SubModulo>/
        │   ├── <Entidad>s.aspx(.cs)     página listado
        │   └── <Entidad>.aspx(.cs)      página formulario
        └── Controls/
            └── <Entidad>/
                ├── <Entidad>s.ascx(.cs) UserControl listado (grid)
                ├── <Entidad>.ascx(.cs)  UserControl formulario (tabs)
                └── <Tab>.ascx(.cs)      un UserControl por tab
```

Fíjate en el detalle de nombres que confunde a todos al principio:

- **`Usuarios`** (plural) = listado.
- **`Usuario`** (singular) = formulario.

Es la única diferencia entre los dos archivos, y está en todo el proyecto.

---

## 4. El Model — explicar con `Usuario.cs`

Abre [`../02-Ejemplo-Usuario/App_Code/MVC/Sigma/Model/Usuario.cs`](../02-Ejemplo-Usuario/App_Code/MVC/Sigma/Model/Usuario.cs).

**Qué es:** una clase POCO. Propiedades y nada más. Cero métodos, cero validaciones, cero lógica.

**Las 4 reglas que hay que memorizar:**

1. `[Serializable]` — porque el objeto viaja en `ViewState` y `Session`.
2. **Nombre de propiedad = nombre de columna en minúsculas.** Columna `USU_NOMBRES` → propiedad `usu_nombres`. Sin excepciones, sin `PascalCase`, sin nombres "bonitos".
3. **Prefijo de 3 letras de la tabla.** Tabla `USUARIO` → `usu_`. Esto hace que en un JOIN se sepa de qué tabla viene cada campo sin buscar.
4. Los campos que empiezan con **`filtro_`** NO existen en la base de datos. Son parámetros de búsqueda que el Controller lee para armar la llamada al SP.

### El punto que hay que subrayar: por qué `bool?` y no `bool`

```csharp
public bool? filtro_habilitado { get; set; }
```

Con `bool` normal solo tendrías `true` o `false`. Con `bool?` tienes **tres** estados:

| Valor | Significado |
|---|---|
| `null` | "no me importa" → no filtrar, traer todos |
| `true` | traer solo habilitados |
| `false` | traer solo deshabilitados |

Sin el `?` sería imposible expresar "traer todos". Esa es la razón, y es la pregunta que siempre sale en clase.

---

## 5. El Controller — explicar con `UsuarioController.cs`

Abre [`../02-Ejemplo-Usuario/App_Code/MVC/Sigma/Controller/UsuarioController.cs`](../02-Ejemplo-Usuario/App_Code/MVC/Sigma/Controller/UsuarioController.cs).

**Qué es:** la única clase del sistema autorizada a tocar la base de datos.

### 5.1 Los 5 métodos estándar

Toda entidad tiene exactamente estos, con estos nombres:

| Método | SP que llama | Devuelve |
|---|---|---|
| `GetUsuarios(Usuario filtro)` | `SEL_USUARIO` | `List<Usuario>` |
| `GetUsuario(Usuario u)` | `SEL_USUARIO` (con `@ID`) | `Usuario` |
| `InsertUsuario(Usuario u)` | `INS_USUARIO` | `Respuesta` |
| `UpdateUsuario(Usuario u)` | `UPD_USUARIO` | `Respuesta` |
| `DeleteUsuario(Usuario u)` | `DEL_USUARIO` | `Respuesta` |

Nota que `GetUsuarios` y `GetUsuario` llaman **al mismo SP**. No se crea un `SEL_USUARIO_BY_ID`. Si viene `@ID`, el SP filtra por id y devuelve una fila.

### 5.2 `Token.TokenSeguridad()` — la primera línea de todo

```csharp
if (Token.TokenSeguridad())
{
    // ... solo aquí se toca la BD
}
```

Si la sesión expiró o el token no es válido, el bloque no se ejecuta y el método devuelve una lista vacía o una `Respuesta` sin tocar. Es un cortafuegos, no una validación de permisos.

**Pregunta para el equipo:** ¿qué pasa si se te olvida? Respuesta: la pantalla funciona igual… hasta que alguien llame al endpoint con la sesión caída y lea datos que no debería.

### 5.3 Filtros condicionales — el patrón que más se copia mal

```csharp
if (!string.IsNullOrEmpty(usuario.filtro))
    cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);
```

**Nunca** se agrega un parámetro incondicionalmente. Si el filtro no viene, el parámetro **no se agrega**, llega al SP como `NULL`, y el `IF (@FILTRO IS NOT NULL)` del `WHERE` no concatena nada.

Es un contrato de dos puntas: el C# decide qué mandar, el SQL decide qué filtrar. Si rompes un lado, el otro deja de tener sentido.

### 5.4 `Respuesta` — el objeto de retorno de toda escritura

```csharp
public class Respuesta
{
    public int    codigo  { get; set; }  // id generado, o -1 si hubo error
    public string detalle { get; set; }  // mensaje para el usuario final
    public bool   error   { get; set; }  // true / false
}
```

Un método de escritura **nunca** devuelve `void` ni `bool`. Siempre `Respuesta`. Así la pantalla siempre tiene un mensaje que mostrar.

Y el detalle fino: en el `catch`, `respuesta.detalle = ex.Message`. Ese `ex.Message` es literalmente el texto del `RAISERROR` que escribió el SP. **Por eso los mensajes del SP se escriben pensando en el usuario final**, no en el desarrollador.

Cadena completa:

```
RAISERROR('1.- Ya existe un usuario con el email "x".')   ← SQL
        ↓ (SqlException)
respuesta.detalle = ex.Message                             ← Controller
        ↓
Tools.tools.ClientAlert(respuesta.detalle, "alerta")       ← Pantalla
        ↓
El usuario ve el mensaje en un SweetAlert
```

### 5.5 Auditoría: `Session.UsuarioId()`

```csharp
cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
```

El id del usuario que hace la operación **jamás** viene de la pantalla. Se toma de la sesión del servidor. Si viniera de un campo oculto, cualquiera podría falsificar la auditoría.

---

## 6. La página `.aspx` — dónde vive la seguridad

Abre [`../02-Ejemplo-Usuario/View/Seguridad/Usuarios/Usuarios.aspx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Usuarios/Usuarios.aspx.cs).

La página tiene **una sola responsabilidad importante**: validar que el usuario tenga permiso de entrar, y traducir los permisos del menú a propiedades del UserControl.

```csharp
#region SeguridadPagina
MenuPerfil ver = new MenuPerfil();
ver.mpe_menu = (int)SitioBase.Paginas.menu_5.Ver;
SitioBase.Token.SecurityManagerVer(ver);
#endregion

wucUsuarios.Ver_Todo      = (int)SitioBase.Paginas.menu_5.Ver_Todo;
wucUsuarios.VerTodoPaises = (int)SitioBase.Paginas.menu_5.Ver_Todo_Paises;
wucUsuarios.Crear_Editar  = (int)SitioBase.Paginas.menu_5.Crear_Editar;
```

Dos matices que hay que explicar:

- `SecurityManagerVer` **corta la ejecución** si no hay permiso. Es el portero.
- El UserControl **no sabe de menús**. Recibe números de función y luego pregunta con `Token.SecurityManager(...)`. Así el mismo UserControl sirve en dos menús distintos.

La región `#region SeguridadPagina` se escribe siempre con ese nombre exacto. Es una convención de búsqueda: permite hacer Ctrl+F en todo el proyecto y auditar la seguridad de todas las páginas.

---

## 7. Querystring cifrado — el detalle que más gusta explicar

En el grid, al armar el link Editar:

```csharp
string query = Server.UrlEncode(
    Tools.Crypto.Encrypt("IdUsuario=" + id + "&ReadOnly=" + ReadOnly));
```

En la página del formulario, al recibirlo:

```csharp
string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);
```

**Por qué:** si la URL fuera `Usuario.aspx?IdUsuario=5`, cualquiera cambia el 5 por un 1 y abre la ficha de otra persona. Cifrado, el parámetro es opaco.

Es un buen momento para una pregunta al equipo: *¿esto reemplaza a validar permisos en el servidor?* **No.** Es una capa más. Por eso `Usuario.aspx.cs` **igual** vuelve a chequear `Crear_Editar` después de descifrar. Defensa en profundidad.

---

## 8. Checklist: crear una entidad nueva "Xxx"

Este es el entregable práctico de la sesión. En orden:

1. `App_Code/MVC/Sigma/Model/Xxx.cs` — propiedades + campos `filtro_*`
2. `App_Code/MVC/Sigma/Controller/XxxController.cs` — `GetXxxs`, `GetXxx`, `InsertXxx`, `UpdateXxx`, `DeleteXxx`
3. `View/<Modulo>/Controls/Xxx/Xxxs.ascx(.cs)` — grid
4. `View/<Modulo>/Controls/Xxx/Xxx.ascx(.cs)` — formulario contenedor de tabs
5. `View/<Modulo>/Controls/Xxx/<Tab>.ascx(.cs)` — un archivo por tab
6. `View/<Modulo>/<SubModulo>/Xxxs.aspx(.cs)` — página listado
7. `View/<Modulo>/<SubModulo>/Xxx.aspx(.cs)` — página formulario
8. Registrar permisos en `SitioBase.Paginas` (`menu_<N>`)
9. **Guardar todo en UTF-8 con BOM y CRLF**

El punto 9 no es cosmético: si el archivo se guarda en UTF-8 sin BOM, las tildes y las ñ se rompen al compilar en el servidor.

---

## 9. Errores típicos que vas a ver en el equipo

| Error | Por qué pasa | Cómo corregirlo |
|---|---|---|
| SQL escrito directo en el `.ascx.cs` | Viene de tutoriales de internet | Todo SQL vive en un SP; el `.ascx.cs` llama al Controller |
| Propiedades del Model en `PascalCase` | Costumbre de C# | El nombre lo manda la columna: `usu_nombres` |
| Guardar en `Page_Load` en vez de `Page_PreRender` | No conocen el ciclo de vida | Cargar en `PreRender`, guardar en el evento del botón |
| Campos privados en vez de `ViewState` | No entienden el postback | Toda propiedad pública del control va en `ViewState` |
| Método de escritura que devuelve `bool` | Simplificar de más | Siempre `Respuesta` |
| Agregar el parámetro del filtro siempre | Copiar sin leer | Solo si viene informado (`if`) |

---

## 10. Ejercicio propuesto para cerrar

Que cada integrante cree, siguiendo el ejemplo `Usuario`, la entidad **`Perfil`** completa:

- `Perfil.cs` con `per_id`, `per_nombre`, `per_descripcion`, `per_habilitado`, auditoría y `filtro`, `filtro_habilitado`
- `PerfilController.cs` con los 5 métodos
- Los 4 SP
- Grid + formulario + páginas

Es la entidad más simple del sistema y toca las 4 capas. Si sale sin ayuda, el patrón quedó.
