# Patrón de seguridad, menús y permisos

Cómo se registra una pantalla nueva en el menú del sistema, cómo se declaran
sus permisos y cómo se aplican en páginas, UserControls y Controllers.

---

## 1. Modelo de seguridad

```text
MENUS  ──< Menu_Funcion (funciones por menú: Ver, Crear_Editar, Ver_Todo, ...)
  │
  └──< Menu_Perfil (qué perfil tiene qué menú/función)
                  │
              PERFILES ──< Usuario_Perfil ──> USUARIO
```

- Un **menú** es una entrada del árbol de navegación. Los menús contenedores
  tienen `mnu_link = '#'`; las pantallas reales tienen la ruta
  `~/View/<Modulo>/<SubModulo>/<Pagina>.aspx`.
- Una **función** es un permiso dentro de ese menú (`Ver`, `Crear_Editar`,
  `Eliminar`, `Ver_Todo`, `Ver_Todo_Paises`, `Descargar`...). Cada función
  tiene un **id numérico** propio.
- `Paginas.cs` expone esos ids como `enum` para no hardcodearlos.

---

## 2. Registrar los menús (SQL)

```sql
USE [<BaseDatos>]
GO

DECLARE @PADRE INT = <id_menu_padre>;             -- ej. el menú "Sistema"
DECLARE @ID    INT = (SELECT MAX(mnu_id) + 1 FROM MENUS);

-- Solo si MNU_ID no es IDENTITY en esta base:
SET IDENTITY_INSERT MENUS ON;

-- Menú contenedor (no navega)
INSERT INTO MENUS (mnu_id, mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon)
VALUES (@ID, '<Nombre Módulo>', '<Descripción>', 3, @PADRE, 5, '#', 1, 'fas fa-<icono>');

-- Pantalla real
INSERT INTO MENUS (mnu_id, mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon)
VALUES (@ID + 1, '<Nombre Pantalla>', '<Descripción>', 4, @ID, 1,
        '~/View/<Modulo>/<SubModulo>/<Entidad>s.aspx', 1, NULL);

SET IDENTITY_INSERT MENUS OFF;
GO
```

Antes de insertar, verificar la numeración y si la PK es identity:

```sql
SELECT MAX(mnu_id) AS ULTIMO,
       COLUMNPROPERTY(OBJECT_ID('MENUS'),'MNU_ID','IsIdentity') AS ES_IDENTITY
FROM MENUS;
```

Y el formato real de los links del proyecto (algunos módulos dependen de él):

```sql
SELECT TOP 20 mnu_id, mnu_nombre, mnu_link FROM MENUS WHERE mnu_link <> '#';
```

Debe verse como `~/View/Carpeta/Pagina.aspx`. Si el proyecto guarda otro
formato, respetarlo.

> Las **páginas de formulario** (`<Entidad>.aspx`) normalmente **no** llevan
> menú propio: se abren desde el listado con querystring cifrado y heredan el
> permiso del listado.

---

## 3. Declarar los permisos en `Paginas.cs`

`App_Code/SitioBase/Paginas.cs` — un `enum` por menú, con el id del menú como
`Ver` y un id distinto por función adicional:

```csharp
//<Nombre Módulo>
public enum menu_<N>
{
    Ver = <N>,
}

//<Nombre Pantalla>
public enum menu_<N+1>
{
    Ver = <N+1>,
    Crear_Editar = <id_funcion>,
    Ver_Todo = <id_funcion>,
}
```

- El nombre del enum es `menu_<id_del_menu>`; el comentario encima indica de
  qué pantalla se trata.
- Los ids de las funciones (`Crear_Editar`, `Ver_Todo`...) salen de la tabla de
  funciones del proyecto; no inventarlos.

---

## 4. Aplicar la seguridad

### 4.1 Página (`.aspx.cs`) — acceso a la pantalla

```csharp
protected void Page_Load(object sender, EventArgs e)
{
    #region SeguridadPagina
    MenuPerfil ver = new MenuPerfil();
    ver.mpe_menu = (int)SitioBase.Paginas.menu_<N>.Ver;
    SitioBase.Token.SecurityManagerVer(ver);
    #endregion

    // Propagar permisos finos al UserControl
    wuc<Entidad>s.Ver_Todo      = (int)SitioBase.Paginas.menu_<N>.Ver_Todo;
    wuc<Entidad>s.Crear_Editar  = (int)SitioBase.Paginas.menu_<N>.Crear_Editar;
}
```

`SecurityManagerVer` redirige al usuario si su perfil no tiene el menú.
El bloque va **siempre** al inicio del `Page_Load`, dentro del `#region
SeguridadPagina`.

### 4.2 UserControl — permisos finos

Las propiedades llegan como el **id de la función**; el control pregunta si el
usuario la tiene:

```csharp
protected void CargarGrid()
{
    #region SeguridadPagina
    bool verTodo = SitioBase.Token.SecurityManager(new MenuFuncion { mfu_id = Ver_Todo });

    if (!verTodo)
        filtro.filtro_usuario = Session.UsuarioId();   // solo lo suyo

    bool crearEditar = SitioBase.Token.SecurityManager(new MenuFuncion { mfu_id = Crear_Editar });
    ReadOnly = !crearEditar;
    #endregion

    // ... resto de la carga
}
```

Usos típicos:

| Función | Efecto |
|---|---|
| `Ver` | Acceso a la pantalla (`SecurityManagerVer`) |
| `Crear_Editar` | Habilita el botón Nuevo y el guardar; si no, `ReadOnly = true` |
| `Ver_Todo` | Sin él, el listado se filtra por el usuario/cliente de la sesión |
| `Ver_Todo_Paises` | Solo multi-país: sin él, se filtra por `Session.UsuarioIdPaises()` |
| `Eliminar` / `Descargar` | Muestra u oculta el `LinkButton` correspondiente |

### 4.3 Controller

Toda operación empieza con:

```csharp
if (Token.TokenSeguridad())
{
    // ...
}
```

Y el usuario que audita sale **siempre** de `Session.UsuarioId()`.

---

## 5. Querystring cifrado entre pantallas

Nunca se pasan ids en claro por la URL.

**Generar** (en el listado, `ItemDataBound` o `OnClientClick`):

```csharp
string query = Server.UrlEncode(Tools.Crypto.Encrypt(
    "Id<Entidad>=" + id + "&Id<Padre>=" + idPadre + "&ReadOnly=" + ReadOnly));
```

```javascript
function abrir<Entidad>(query) {
    window.location = ('<%=ResolveUrl(URLNuevo<Entidad>) %>?query=' + query);
}
```

**Leer** (en el `Page_Load` de la página de formulario):

```csharp
if (Request.QueryString["query"] != null)
{
    string plano = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"]));
    NameValueCollection p = HttpUtility.ParseQueryString(plano);

    wuc<Entidad>.Id<Entidad> = Convert.ToInt32(p["Id<Entidad>"] ?? "0");
    wuc<Entidad>.ReadOnly    = Convert.ToBoolean(p["ReadOnly"] ?? "false");
}
```

Reglas:

- Separador `&` para querystrings de página; algunos módulos antiguos usan `;`
  (matriz de permisos, endpoints AJAX) — respetar el que ya usa el módulo.
- `ReadOnly` viaja en el querystring y se propaga a **todos** los sub-controles
  del formulario, que lo aplican en su `Bloqueo()`.
- El id que llega por querystring **no** es una autorización: el Controller
  igual valida `Token.TokenSeguridad()` y, si corresponde, la pertenencia del
  registro al cliente/usuario de la sesión.

---

## 6. Checklist al publicar una pantalla nueva

1. `INSERT` de los menús (contenedor + pantalla) con el `mnu_link` en el
   formato del proyecto.
2. `enum menu_<N>` en `Paginas.cs`, con `Ver` y las funciones que apliquen.
3. `#region SeguridadPagina` + `SecurityManagerVer` en el `Page_Load` de la
   página listado (y de la de formulario si tiene menú propio).
4. Propagar `Ver_Todo` / `Crear_Editar` al UserControl y aplicarlos con
   `Token.SecurityManager(...)`.
5. `Token.TokenSeguridad()` en todos los métodos del Controller.
6. Querystring cifrado entre listado y formulario.
7. Asignar el menú al perfil desde **Sistema › Acceso › Perfiles** y probar con
   un usuario **sin** el permiso: debe redirigir.
8. Archivos en **UTF-8 con BOM**.
