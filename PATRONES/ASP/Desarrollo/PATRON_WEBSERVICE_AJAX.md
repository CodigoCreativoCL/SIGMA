# Patrón de endpoints AJAX — ASMX ScriptService

Cómo se implementan las llamadas asíncronas desde JavaScript al servidor
(guardar un orden desde la grilla, marcar un flag, cargar un combo dependiente,
registrar una estadística) sin postback ni recarga de página.

> **Regla dura**: NUNCA `.ashx` (WebHandler) ni Web API. El patrón del proyecto
> es **ASMX con `[ScriptService]`**, en dos archivos.

---

## 1. Estructura (dos archivos)

| Archivo | Contenido |
|---|---|
| `App_Code/WebService/Ws<Nombre>.cs` | La clase con la lógica y los `[WebMethod]` |
| `WebService/Ws<Nombre>.asmx` | Una sola línea que apunta al `App_Code` |

Nombre: `Ws` + entidad/acción en plural o singular según el caso —
`WsMenuMaterialApoyos`, `WsOrdenChecklist`, `WsTransporteEstado`.

### 1.1 `WebService/Ws<Nombre>.asmx`

Una única línea, sin más contenido:

```aspx
<%@ WebService Language="C#" CodeBehind="~/App_Code/WebService/Ws<Nombre>.cs" Class="Ws<Nombre>" %>
```

### 1.2 `App_Code/WebService/Ws<Nombre>.cs`

```csharp
using System;
using System.Collections.Generic;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;
using <Proyecto>.Controller;
using <Proyecto>.Model;
using SitioBase;

/// <summary>
/// Endpoints AJAX de <Entidad>.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class Ws<Nombre> : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Guardar<Algo>(string datos)
    {
        Respuesta respuesta = new Respuesta();

        try
        {
            // 1. Descifrar los parámetros que vienen del cliente
            string plano = Tools.Crypto.Decrypt(datos);
            string[] partes = plano.Split(';');

            int id = int.Parse(partes[0].Split('=')[1]);
            int valor = int.Parse(partes[1].Split('=')[1]);

            // 2. Ejecutar la acción vía Controller (nunca SQL aquí)
            <Entidad> entidad = new <Entidad>();
            entidad.<pfx>_id = id;
            entidad.<pfx>_orden = valor;

            <Entidad>Controller controller = new <Entidad>Controller();
            respuesta = controller.Update<Entidad>Orden(entidad);
        }
        catch (Exception ex)
        {
            respuesta.error = true;
            respuesta.detalle = ex.Message;
        }

        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(respuesta);
    }
}
```

Reglas:

- Atributos obligatorios en la clase: `[WebService]`, `[WebServiceBinding]`,
  `[ScriptService]`. Sin `[ScriptService]` el método no se puede llamar por
  JSON desde jQuery.
- `[WebMethod(EnableSession = true)]` **siempre**: sin sesión, `Token` y
  `Session.UsuarioId()` fallan y el Controller no autoriza la operación.
- `[ScriptMethod(ResponseFormat = ResponseFormat.Json)]` en cada método.
- El método **no** accede a la BD directamente: llama al Controller, igual que
  un code-behind.
- Devolver `string` (JSON serializado) o un tipo simple. Evitar devolver
  objetos complejos con referencias circulares.
- Todo dentro de `try/catch`: una excepción no capturada devuelve un HTML de
  error que rompe el `$.ajax` del cliente.
- Los parámetros sensibles (ids) viajan **cifrados** con
  `Tools.Crypto.Encrypt/Decrypt`, igual que los querystring.

---

## 2. Llamada desde el cliente

```javascript
function registraOrden(clientId, id) {
    var valor = document.getElementById(clientId).value;

    $.ajax({
        type: "POST",
        url: "<%=ResolveUrl("~/WebService/Ws<Nombre>.asmx/Guardar<Algo>") %>",
        data: JSON.stringify({ datos: cadenaCifrada, valor: valor }),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        success: function (result) {
            var respuesta = JSON.parse(result.d);   // ← la respuesta viene en .d

            if (respuesta.error) {
                Swal.fire("", respuesta.detalle, "warning");
            } else {
                refresh();                          // refresca el grid vía __doPostBack
            }
        },
        error: function (xhr, status, error) {
            Swal.fire("", "Error al procesar la solicitud.", "error");
        }
    });
}
```

Reglas del lado cliente:

- `contentType: 'application/json; charset=utf-8'` es obligatorio; sin eso
  ASP.NET no enruta al `ScriptMethod`.
- `data: JSON.stringify({...})` con **los nombres exactos** de los parámetros
  del `[WebMethod]`.
- La respuesta llega envuelta: `result.d`. Es el error más común al portar.
- La URL se resuelve con `<%=ResolveUrl("~/WebService/...") %>` para que
  funcione en cualquier virtual directory.
- Tras una operación exitosa que cambia datos de una grilla, llamar `refresh()`
  (requiere `Tools.tools.RegisterPostBackScript(Grid)` en el code-behind).

---

## 3. Cuándo usar este patrón (y cuándo no)

| Situación | Solución |
|---|---|
| Guardar un valor suelto desde una celda de grilla (orden, cantidad) | ASMX (este patrón) |
| Marcar/desmarcar un checkbox de una matriz de permisos | ASMX |
| Registrar una estadística ("visto", "me gusta") | ASMX |
| Cargar un combo dependiente de otro | `AutoPostBack` + `UpdatePanel` (más simple) |
| Guardar un formulario completo | `PushButton` + `OnClick` + Controller |
| Descargar un archivo | `LinkButton` + `Command` + `Response.BinaryWrite` (ver [`PATRON_GRID_EVENTS.md`](PATRON_GRID_EVENTS.md) §3) |

Criterio: el AJAX es para **microacciones** que no justifican un postback
completo. Un formulario con validaciones va siempre por el ciclo normal.

---

## 4. Alternativa: `PageMethods` (solo en `.aspx`)

Si la acción es exclusiva de **una** página y no se reutiliza, se puede usar un
`[WebMethod]` estático en el code-behind de la `.aspx`, llamado con
`PageMethods.<Metodo>(...)`. Requiere
`<asp:ScriptManager EnablePageMethods="true">` en el master o la página.

```csharp
[System.Web.Services.WebMethod(EnableSession = true)]
public static string GuardaPermisos(string cadena, string fila, string control)
{
    // ... misma estructura: descifrar, Controller, devolver JSON
}
```

Preferir el ASMX cuando el endpoint se usa desde más de una página o desde un
UserControl reutilizable.

---

## 5. Checklist

1. `App_Code/WebService/Ws<Nombre>.cs` con `[WebService]` +
   `[WebServiceBinding]` + `[ScriptService]`.
2. `WebService/Ws<Nombre>.asmx` de una línea apuntando al `.cs`.
3. Cada método: `[WebMethod(EnableSession = true)]` +
   `[ScriptMethod(ResponseFormat = ResponseFormat.Json)]` + `try/catch`.
4. La lógica de datos vive en el Controller, no en el WebService.
5. Parámetros sensibles cifrados con `Tools.Crypto`.
6. Cliente: `POST`, `contentType` JSON, `JSON.stringify`, leer `result.d`.
7. Ambos archivos en **UTF-8 con BOM**.
8. Probar el endpoint navegando a `~/WebService/Ws<Nombre>.asmx` (debe listar
   los métodos) antes de depurar el JS.
