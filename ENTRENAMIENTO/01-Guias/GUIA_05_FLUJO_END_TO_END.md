# Guía 05 — Flujo end-to-end: seguir un dato desde el click hasta la tabla

> Esta es la sesión de cierre. Se hace **con los archivos abiertos en pantalla**, siguiendo un dato real.
> Duración estimada: **40 min**

---

## Por qué esta sesión

Las guías 01–04 explican cada capa por separado. El problema típico es que el equipo entiende cada pieza pero no ve cómo encajan.

Aquí seguimos **dos recorridos completos**, archivo por archivo:

- **Recorrido A**: abrir el listado de usuarios.
- **Recorrido B**: guardar un usuario nuevo.

---

## Recorrido A — El usuario abre `Usuarios.aspx`

### Paso 1 — La página valida el permiso

📄 [`Usuarios.aspx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Usuarios/Usuarios.aspx.cs) → `Page_Load`

```csharp
MenuPerfil ver = new MenuPerfil();
ver.mpe_menu = (int)SitioBase.Paginas.menu_5.Ver;
SitioBase.Token.SecurityManagerVer(ver);
```

Si el perfil no tiene el permiso, aquí termina todo. **Nada más se ejecuta.**

Luego traduce los permisos a propiedades del control:

```csharp
wucUsuarios.VerTodoPaises = (int)SitioBase.Paginas.menu_5.Ver_Todo_Paises;
```

### Paso 2 — El UserControl arma las columnas

📄 [`Usuarios.ascx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuarios.ascx.cs) → `Page_PreRender`

```csharp
if (!IsPostBack)
{
    Grid.AddSelectColumn();
    Grid.AddColumn("usu_rut", "RUT", Width: "12%");
    ...
}
```

Solo la primera vez. En los postbacks las columnas ya existen.

### Paso 3 — Se arma el Model de filtros

📄 Mismo archivo → `CargarGrid()`

```csharp
Usuario filtro = new Usuario();

// Seguridad por país
MenuFuncion verTodoPaises = new MenuFuncion();
verTodoPaises.mfu_funcion = VerTodoPaises;
if (!SitioBase.Token.SecurityManager(verTodoPaises))
    filtro.filtro_paises = SitioBase.Session.UsuarioIdPaises();

// Filtros de pantalla
filtro.filtro = wucFiltro.Filtro();
```

Fíjate: **la seguridad se convierte en un filtro de datos**. Si no puedes ver todos los países, el CSV de tus países entra como filtro y el SP nunca te devolverá usuarios de otros países. La seguridad se aplica en la consulta, no ocultando filas después.

### Paso 4 — Se llama al Controller

```csharp
Grid.DataSource = usuarioController.GetUsuarios(filtro);
```

Única línea de acceso a datos de todo el archivo.

### Paso 5 — El Controller traduce a parámetros

📄 [`UsuarioController.cs`](../02-Ejemplo-Usuario/App_Code/MVC/Sigma/Controller/UsuarioController.cs) → `GetUsuarios`

```csharp
if (Token.TokenSeguridad())          // cortafuegos de sesión
{
    cmd.CommandText = "SEL_USUARIO";

    if (!string.IsNullOrEmpty(usuario.filtro))
        cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);

    if (!string.IsNullOrEmpty(usuario.filtro_paises))
        cmd.Parameters.AddWithValue("@PAISES", usuario.filtro_paises);
```

Solo se agregan los parámetros informados.

### Paso 6 — El SP arma el WHERE

📄 [`01_SEL_USUARIO.sql`](../02-Ejemplo-Usuario/BD/01_SEL_USUARIO.sql)

```sql
SET @WHERE = ' WHERE 1=1 '

IF (@PAISES IS NOT NULL) BEGIN
    SET @WHERE = @WHERE + ' AND USU_PAIS IN (' + @PAISES + ')'
END

IF (@FILTRO IS NOT NULL) BEGIN
    SET @WHERE = @WHERE + ' AND (USU_NOMBRES LIKE ''%' + LTRIM(@FILTRO) + '%'' ...)'
END

EXEC(@SELECT + @FROM + @WHERE)
```

Los parámetros que el C# no mandó llegaron `NULL` y sus `IF` no se cumplieron.

### Paso 7 — El Controller vuelve a llenar Models

```csharp
while (dr.Read())
{
    Usuario item = new Usuario();
    item.usu_id      = int.Parse(dr["USU_ID"].ToString());
    item.usu_nombres = dr["USU_NOMBRES"].ToString();
    item.per_nombre  = dr["PER_NOMBRE"].ToString();   // ← viene del JOIN
    usuarios.Add(item);
}
```

Nota `per_nombre`: no es columna de `USUARIO`, viene del `INNER JOIN PERFIL`. Existe en el Model solo para que el grid muestre "Administrador" en vez de "3".

### Paso 8 — Render y link Editar por fila

📄 `Usuarios.ascx.cs` → `rgrUsuarios_ItemDataBound`

```csharp
string query = Server.UrlEncode(
    Tools.Crypto.Encrypt("IdUsuario=" + id + "&ReadOnly=" + ReadOnly));

HyperLink Editar = new HyperLink();
Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");
item["usu_id"].Controls.Add(Editar);
```

### Resumen del recorrido A

```
Usuarios.aspx.cs      valida permiso, pasa funciones de menú
      ↓
Usuarios.ascx.cs      arma columnas + Model de filtros
      ↓
UsuarioController     TokenSeguridad → parámetros condicionales
      ↓
SEL_USUARIO           WHERE 1=1 + IFs → EXEC
      ↓
Tabla USUARIO
      ↑
DataReader → List<Usuario> → Grid.DataSource → ItemDataBound → HTML
```

---

## Recorrido B — Guardar un usuario nuevo

### Paso 1 — Click en "Nuevo"

📄 [`Usuarios.ascx`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuarios.ascx)

```aspx
<asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo"
    CssClass="icono_guardar" OnClientClick="abrirUsuario(0)" />
```

```js
function abrirUsuario(query) {
    window.location = ('<%=ResolveUrl(URLNuevoUsuario) %>?query=' + query);
}
```

Sin query cifrado → `IdUsuario` queda en 0 → modo alta.

### Paso 2 — La página del formulario descifra

📄 [`Usuario.aspx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Usuarios/Usuario.aspx.cs)

```csharp
string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);
// "IdUsuario=5&ReadOnly=False"

foreach (string par in parametros.Split('&')) { ... wucUsuario.IdUsuario = id; }

// Refuerzo: si no tiene Crear/Editar, modo consulta forzado
if (!SitioBase.Token.SecurityManager(crearEditar))
    wucUsuario.ReadOnly = true;
```

Segunda validación de seguridad, ya del lado del servidor. El cifrado del querystring **no reemplaza** esto.

### Paso 3 — El contenedor propaga a los tabs

📄 [`Usuario.ascx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuario.ascx.cs)

```csharp
wucIdentidad.ReadOnly  = ReadOnly;
wucIdentidad.IdUsuario = IdUsuario;
```

El archivo entero tiene ~50 líneas. **Es intencional**: el contenedor no hace lógica de negocio.

### Paso 4 — El tab carga combos y datos

📄 [`Identidad.ascx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Identidad.ascx.cs)

`LoadControls` puebla `cboPerfil` y `cboPais` (solo en `!IsPostBack`).

`CargarDatos()`:

```csharp
if (IdUsuario > 0)  { /* trae el registro y llena controles */ }
else                { /* limpia todo */ }
```

`Bloqueo()` aplica `ReadOnly` a cada control.

### Paso 5 — El usuario llena y hace click en Guardar

Antes del postback, el navegador ejecuta `validaControl` en cada `CustomValidator` del grupo `"Usuario"`. Si alguno falla, **no hay postback**.

### Paso 6 — `btnGuardar_Click`

```csharp
// 1. Armar Model
Usuario usuario = new Usuario();
usuario.usu_id     = IdUsuario;
usuario.usu_rut    = txtRut.Text.Trim();
usuario.usu_perfil = int.Parse(cboPerfil.SelectedValue);

// 2. Validaciones de negocio
if (IdUsuario == 0 && string.IsNullOrEmpty(usuario.usu_password))
{
    Tools.tools.ClientAlert("Debe ingresar una contrasena...", "alerta");
    return;
}

// 3. Insert o Update
Respuesta respuesta = IdUsuario > 0
    ? usuarioController.UpdateUsuario(usuario)
    : usuarioController.InsertUsuario(usuario);

// 4. Avisar
if (!respuesta.error)
{
    IdUsuario = respuesta.codigo;   // ← clave
    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
}
```

**El paso 4 merece énfasis.** Tras un alta exitosa se guarda el id devuelto en `IdUsuario`. Si el usuario vuelve a hacer click en Guardar, ahora `IdUsuario > 0` y se ejecuta un **Update**, no un segundo Insert. Sin esta línea, cada click crea un registro nuevo.

### Paso 7 — El Controller ejecuta el INSERT

```csharp
cmdExecute = Conexion.GetCommand("INS_USUARIO");
cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;
cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());  // ← de la sesión
cmdExecute.ExecuteNonQuery();

id = (int)cmdExecute.Parameters["@ID"].Value;
respuesta.codigo  = id;
respuesta.detalle = "Usuario creado con exito.";
```

### Paso 8 — El SP valida, inserta y devuelve el id

```sql
IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_EMAIL = @EMAIL)
BEGIN
    RAISERROR('1.- Ya existe un usuario con el email "%s".', 16, 1, @EMAIL)
    RETURN -1
END

BEGIN TRANSACTION
    INSERT USUARIO (...) VALUES (...)
    SET @ID = SCOPE_IDENTITY()
    IF @@ROWCOUNT = 0 BEGIN ROLLBACK ... EXEC INS_EXCEPCION ... END
COMMIT TRANSACTION
```

### Paso 9 — El camino del error

Si el email estaba duplicado:

```
RAISERROR en SQL
      ↓  SqlException
catch (Exception ex) { respuesta.detalle = ex.Message; respuesta.error = true; }
      ↓
Tools.tools.ClientAlert(respuesta.detalle, "alerta")
      ↓
SweetAlert: "1.- Ya existe un usuario con el email juan@x.cl."
```

**Un mensaje escrito en SQL termina, sin intermediarios, frente al usuario final.** Por eso se escriben en español y sin jerga.

### Resumen del recorrido B

```
Click Nuevo → JS → Usuario.aspx?query=<cifrado>
      ↓
Usuario.aspx.cs        descifra + valida permiso
      ↓
Usuario.ascx.cs        propaga a los tabs
      ↓
Identidad.ascx.cs      LoadControls + CargarDatos + Bloqueo
      ↓
[usuario llena y guarda] → validaControl (navegador)
      ↓
btnGuardar_Click       arma Model → valida negocio → Insert/Update
      ↓
UsuarioController      INS_USUARIO + @ID OUTPUT + Session.UsuarioId()
      ↓
INS_USUARIO            valida → TRANSACTION → SCOPE_IDENTITY
      ↓
Tabla USUARIO
      ↑
Respuesta → IdUsuario = codigo → ClientAlert
```

---

## Las 10 ideas que deben quedar

1. **No es ASP.NET MVC.** "Controller" = capa de acceso a datos.
2. **Cada capa habla solo con la de abajo.** Sin atajos.
3. **El Model es solo datos.** Los `filtro_*` no existen en la BD.
4. **Todo SQL vive en un SP.** Cero SQL en C#.
5. **`Token.TokenSeguridad()`** abre todo método del Controller.
6. **Los parámetros de filtro se agregan solo si vienen.** Contrato con el `WHERE 1=1`.
7. **Se carga en `PreRender`, se guarda en el evento del botón.**
8. **Las propiedades públicas van en `ViewState`.**
9. **Toda escritura devuelve `Respuesta`**, y su `detalle` llega al usuario.
10. **UTF-8 con BOM y CRLF** en todos los archivos.

---

## Ejercicio final de la capacitación

Implementar la entidad **`Perfil`** completa, en parejas, sin mirar el ejemplo salvo para dudas puntuales:

- `Perfil.cs` — `per_id`, `per_nombre`, `per_descripcion`, `per_habilitado`, auditoría, `filtro`, `filtro_habilitado`
- `PerfilController.cs` — `GetPerfiles`, `GetPerfil`, `InsertPerfil`, `UpdatePerfil`, `DeshabilitarPerfil`
- 4 scripts SQL
- `Perfiles.ascx(.cs)`, `Perfil.ascx(.cs)`, `Identidad.ascx(.cs)`
- `Perfiles.aspx(.cs)`, `Perfil.aspx(.cs)`

### Criterios de revisión

- [ ] El Model no tiene métodos
- [ ] Las propiedades siguen `per_<columna>` en minúsculas
- [ ] Todo método del Controller abre con `Token.TokenSeguridad()`
- [ ] Los `Get` devuelven `List<T>`/`T`; las escrituras devuelven `Respuesta`
- [ ] Los parámetros de filtro se agregan condicionalmente
- [ ] Los SP tienen encabezado estándar y `= NULL` en los filtros
- [ ] `INS_` usa `@ID OUTPUT` + `SCOPE_IDENTITY()`
- [ ] `UPD_` usa `ISNULL(@PARAM, columna)`
- [ ] Las columnas del grid se agregan dentro de `!IsPostBack`
- [ ] La columna clave está en `DataKeyNames`
- [ ] El `ValidationGroup` coincide entre validators y botón
- [ ] Hay un único método `Bloqueo()`
- [ ] Todos los archivos en UTF-8 con BOM
