# Funcionalidad: Material de Apoyo

Guía para portar el módulo **Material de Apoyo** a cualquier proyecto WebForms
del grupo (`FacilityGes`, `SGF`, `Workges`, `Trabajaya`, `Agendamientos`...).

Implementación original: **FacilityGes**. Port verificado: **FacilityGes → SGF**
(de ahí salen las trampas de §6).

> Antes de escribir código, completa la **§3 (Evaluación previa)**. El módulo
> depende de una decena de piezas de infraestructura que no todos los proyectos
> tienen, y la mitad de los problemas del port salieron de ahí.

Patrones base que aplica este módulo:
[`../BaseDatos/PATRON_TABLAS.md`](../BaseDatos/PATRON_TABLAS.md) ·
[`../BaseDatos/PATRON_SP.md`](../BaseDatos/PATRON_SP.md) ·
[`../Desarrollo/PATRON_MVC.md`](../Desarrollo/PATRON_MVC.md) ·
[`../Desarrollo/PATRON_CONTROLES.md`](../Desarrollo/PATRON_CONTROLES.md) ·
[`../Desarrollo/PATRON_WEBSERVICE_AJAX.md`](../Desarrollo/PATRON_WEBSERVICE_AJAX.md) ·
[`../Desarrollo/PATRON_SEGURIDAD_MENUS.md`](../Desarrollo/PATRON_SEGURIDAD_MENUS.md)

---

## 1. Qué es y cómo funciona

Permite adjuntar archivos de ayuda (video, imagen, PDF, Word, Excel) **a un
menú del sistema**, y mostrarlos automáticamente en la barra superior cuando el
usuario está parado en la página de ese menú.

### 1.1 Flujo

```text
Usuario entra a ~/View/<Modulo>/<SubModulo>/<Pagina>.aspx
        │
        ▼
Default.master.cs → Page_PreRender → CargarMaterialApoyo()
        │  calcula pathUrl = "~/View/<Modulo>/<SubModulo>/<Pagina>.aspx"
        ▼
SEL_MENU_MATERIAL_APOYO @RUTA = pathUrl
        │  INNER JOIN MENUS ON MNU_ID = MMA_MENU
        │  WHERE MNU_LINK = @RUTA          ← la unión es por el LINK del menú
        ▼
¿Hay material?  NO → capsulasMenuContainer.Visible = false (ícono oculto)
                SÍ → arma el HTML de la lista y lo inyecta en ltlCapsulas
        │
        ▼
Clic en un ítem
   ├── Descargable (xls/doc/csv) → DescargarArchivo.aspx (TransmitFile)
   └── Reproducible              → popup Reproductor.aspx (video/audio/img/PDF inline)
        │
        └── En ambos casos: EstadoMaterial(..., 3) → registra "visto"
```

**Punto clave**: la relación material ↔ página **no** se guarda como ruta de
página. `mma_ruta` es la ruta física del archivo subido; la página se resuelve
por `MENUS.MNU_LINK`. Por eso el material solo aparece en menús con link real
(los contenedores con `link = '#'` no admiten material).

### 1.2 Estadísticas

| `mae_tipo` | Significado | Comportamiento |
|---|---|---|
| 1 | Me gusta | Toggle. Si el usuario ya tenía 2, hace UPDATE a 1 |
| 2 | No me gusta | Toggle. Si el usuario ya tenía 1, hace UPDATE a 2 |
| 3 | Visto | Siempre inserta una fila nueva (no es toggle) |

La lógica de toggle vive **en el SP** `INS_MENU_MATERIAL_APOYO_ESTADISTICAS`,
no en C#. El JS solo actualiza el contador en pantalla de forma optimista.

---

## 2. Inventario de archivos

| Capa | Archivo |
|---|---|
| Modelo | `App_Code/MVC/SitioBase/Model/MenuMaterialApoyo.cs` |
| Modelo | `App_Code/MVC/SitioBase/Model/MenuMaterialApoyoEstadistica.cs` |
| Controller | `App_Code/MVC/SitioBase/Controller/MenuMaterialApoyoController.cs` |
| Controller | `App_Code/MVC/SitioBase/Controller/MenuMaterialApoyoEstadisticaController.cs` |
| Endpoint AJAX | `App_Code/WebService/WsMenuMaterialApoyos.cs` + `WebService/WsMenuMaterialApoyos.asmx` |
| Navbar | `Master/Default.master` (panel `capsulasMenuContainer`) |
| Navbar | `Master/Default.master.cs` (método `CargarMaterialApoyo()`) |
| Helper archivos | `App_Code/SitioBase/SitioBase.cs` → `MaterialApoyo(...)` |
| Menús | `App_Code/SitioBase/Paginas.cs` → enums nuevos |
| Front | `Js/MaterialApoyo/materialApoyo.js` |
| Front | `Css/MaterialApoyo/materialApoyo.css` |
| Mantenedor | `View/MaterialApoyo/Mantenedores/MenuMaterialApoyos.aspx(.cs)` — TreeView de menús + grilla |
| Mantenedor | `View/MaterialApoyo/Mantenedores/MenuMaterialApoyo.aspx(.cs)` — form de carga |
| Estadísticas | `View/MaterialApoyo/Mantenedores/MenuMaterialApoyoEstadistica.aspx(.cs)` |
| Entrega | `View/MaterialApoyo/Mantenedores/Reproductor.aspx(.cs)` |
| Entrega | `View/MaterialApoyo/Mantenedores/DescargarArchivo.aspx(.cs)` |
| Config | `Web.config` → `<add key="MaterialApoyo" value="~/MaterialApoyo/"/>` |
| Storage | Carpeta física `~/MaterialApoyo/` |

El módulo va en `MVC/SitioBase/` (no en `MVC/<Proyecto>/`): es transversal, no
pertenece al dominio de negocio del proyecto.

---

## 3. Evaluación previa (hacer ANTES de copiar nada)

Marca cada punto. Si alguno falla, resuélvelo primero o el port no compila / no
corre.

### 3.1 Infraestructura de código

| # | Verificar | Cómo |
|---|---|---|
| 1 | Wrappers Telerik `RadGrid2`, `RadWindow2`, `RadNumericBox2`, `RadTreeView`, `RadSplitter` | `Lib*/Library/Web/UI/Telerik/*.cs` |
| 2 | `RadGrid2.AddColumn` acepta named params `Wrap:` y `Width:` | Abrir `RadGrid2.cs`. Si difiere, reescribir los `ConfigurarGrid()` |
| 3 | `RadGrid2.AddCheckboxColumn` y `AddSelectColumn` existen | ídem |
| 4 | Clase `Respuesta` con `codigo`, `detalle`, `error`, `table`, `cantidaCargada`, `cantidaError` | `Lib*/Library/Tools/Respuesta.cs` |
| 5 | `Tools.Crypto.Encrypt/Decrypt` | `Lib*/Library/Tools/Crypto.cs` |
| 6 | `Tools.tools.ClientAlert` y `RegisterPostBackScript` | `Lib*/Library/Tools/ClientScript.cs` |
| 7 | `Session.UsuarioId()` devuelve el id numérico del usuario | `App_Code/SitioBase/Session.cs` |
| 8 | `AccesoController.GetMenusAdministracion()` devuelve el árbol completo de menús | `App_Code/MVC/SitioBase/Controller/AccesoController.cs` |
| 9 | Modelo `Menus` con `mnu_id, mnu_nombre, mnu_nivel, mnu_padre, mnu_orden, mnu_link` | `App_Code/MVC/SitioBase/Model/Menus.cs` |
| 10 | Control `View/Comun/Controls/FiltroAvanzado.ascx` (lo usa la pantalla de estadísticas) | — |
| 11 | `EPPlus.dll` en `bin/` (exportación a Excel) | `ls bin/ \| grep -i epplus` |
| 12 | `popup(url, w, h, name, winprops)` en `Js/Library.js` | lo usa `abrirCapsula()` |
| 13 | `ConfirSweetAlert(btn, titulo, mensaje)` en `Js/Library.js` | confirmación del botón Eliminar |
| 14 | jQuery se carga **antes** del `<body>` (vía `ScriptReference` del ScriptManager) | `materialApoyo.js` usa `$` a nivel raíz |
| 15 | El master tiene `<ul class="list-unstyled topnav-menu float-right">` en la topbar | ahí se inserta el ícono |
| 16 | El master tiene code-behind con `Page_PreRender` | ahí va `CargarMaterialApoyo()` |

### 3.2 Base de datos

```sql
-- ¿Existen los objetos base que el módulo asume?
SELECT 'INS_EXCEPCION' AS OBJETO, OBJECT_ID('INS_EXCEPCION')       AS ID
UNION ALL SELECT 'LOG',            OBJECT_ID('LOG')
UNION ALL SELECT 'MENUS',          OBJECT_ID('MENUS')
UNION ALL SELECT 'USUARIO',        OBJECT_ID('USUARIO')
UNION ALL SELECT 'Usuario_Paises', OBJECT_ID('Usuario_Paises')
UNION ALL SELECT 'FNC_PAIS_HORA',  OBJECT_ID('FNC_PAIS_HORA');
```

| Resultado | Acción |
|---|---|
| `INS_EXCEPCION` NULL | Quitar los `EXEC INS_EXCEPCION` de los SPs o crear el SP |
| `LOG` NULL | Quitar el trigger de auditoría, o crearlo |
| `Usuario_Paises` / `FNC_PAIS_HORA` NULL | **El proyecto no maneja países** → usar `GETDATE()` (ver §6.4) |

Verificar el formato de `MNU_LINK`, que es la clave de todo el módulo:

```sql
SELECT TOP 20 mnu_id, mnu_nombre, mnu_link FROM MENUS WHERE mnu_link <> '#';
```

Debe verse como `~/View/Carpeta/Pagina.aspx`. Si el proyecto guarda los links
en otro formato (sin `~/`, con querystring, en minúsculas), hay que ajustar el
cálculo de `pathUrl` en `CargarMaterialApoyo()` o el `WHERE` del SP.

Y el id disponible para los menús nuevos:

```sql
SELECT MAX(mnu_id) AS ULTIMO,
       COLUMNPROPERTY(OBJECT_ID('MENUS'),'MNU_ID','IsIdentity') AS ES_IDENTITY
FROM MENUS;
```

### 3.3 Infraestructura de servidor

| # | Verificar |
|---|---|
| 1 | La carpeta `~/MaterialApoyo/` existe y el usuario del **App Pool de IIS** tiene permiso de escritura |
| 2 | `maxRequestLength` / `maxAllowedContentLength` admiten el peso de los videos a subir |
| 3 | La carpeta no está excluida del despliegue ni se borra en cada publicación (los archivos viven en disco, no en BD) |
| 4 | Si hay más de un servidor web, la carpeta debe ser compartida o replicada |

### 3.4 Convenciones visuales del proyecto destino

**No asumir que las clases CSS del proyecto origen existen en el destino.**

```bash
grep -rn "^\.btn_\|^\.icono_" Css/UI/Telerik/Bootstrap/Grid.css
```

| Proyecto | Botón "Nuevo" en `CommandItemTemplate` |
|---|---|
| FacilityGes | `CssClass="icono_guardar"` con `Text="Nuevo"` |
| SGF | `CssClass="btn_dinamico btn_nuevo"` + `span.text` / `span.icon` dentro de `div.contenedor-botones` |

Lo mismo con `RadWindow2`: en SGF se declara con skin explícito y en
FacilityGes no.

```aspx
<!-- SGF -->
<rad:RadWindow2 ID="rwiDetalle" runat="server" Title=" " EnableEmbeddedSkins="true" Skin="MetroTouch" />
```

Revisar el patrón real del destino en una pantalla ya existente antes de copiar.

---

## 4. Modelo de datos

### 4.1 Tablas

**`Menu_Material_Apoyo`**

| Columna | Tipo | Null | Nota |
|---|---|---|---|
| `mma_id` | int | No | PK identity |
| `mma_menu` | int | No | FK → `MENUS.mnu_id` |
| `mma_nombre` | varchar | No | Nombre visible |
| `mma_contenedor` | varchar | Sí | Ruta jerárquica del menú (subcarpetas en disco) |
| `mma_ruta` | varchar | No | Ruta virtual del archivo |
| `mma_orden` | int | Sí | Orden en el listado |
| `mma_habilitado` | bit | Sí | |
| `mma_usuario_creacion` | int | No | |
| `mma_fecha_creacion` | datetime | No | |
| `mma_usuario_act` | int | No | |
| `mma_fecha_act` | datetime | No | |

**`Menu_Material_Apoyo_Estadistica`** (append-only)

| Columna | Tipo | Null |
|---|---|---|
| `mae_id` | int | No (PK identity) |
| `mae_menu_apoyo` | int | No (FK → `mma_id`) |
| `mae_tipo` | int | No (1/2/3) |
| `mae_usuario` | int | No (FK → `USUARIO`) |
| `mae_fecha` | datetime | No |

Ambas siguen el naming `Pascal_Snake_Case` con prefijo de 3 letras
(`mma`, `mae`) — ver [`../BaseDatos/PATRON_TABLAS.md`](../BaseDatos/PATRON_TABLAS.md) §1.

### 4.2 Stored Procedures

| SP | Parámetros |
|---|---|
| `SEL_MENU_MATERIAL_APOYO` | `@ID`, `@ID_MENU`, `@RUTA`, `@FILTRO_HABILITADO` |
| `INS_MENU_MATERIAL_APOYO` | `@ID` OUT, `@ID_MENU`, `@NOMBRE`, `@CONTENEDOR`, `@RUTA`, `@USUARIO` |
| `UPD_MENU_MATERIAL_APOYO` | `@ID`, `@ID_MENU`, `@NOMBRE`, `@CONTENEDOR`, `@RUTA`, `@USUARIO`, `@HABILITADO` |
| `UPD_MENU_MATERIAL_APOYO_ORDEN` | `@ID`, `@ORDEN` |
| `DEL_MENU_MATERIAL_APOYO` | `@ID`, `@USUARIO` *(en FacilityGes lleva además `@PAIS`)* |
| `SEL_MENU_MATERIAL_APOYO_ESTADISTICAS` | `@MENU`, `@USUARIO`, `@TIPO`, `@EXCEL`, `@FILTRO` |
| `INS_MENU_MATERIAL_APOYO_ESTADISTICAS` | `@ID` OUT, `@MENU_APOYO`, `@TIPO`, `@USUARIO` |

- `SEL_MENU_MATERIAL_APOYO` devuelve, además de las columnas de la tabla, los
  agregados `ME_GUSTA`, `NO_ME_GUSTA` y `VISTO` (subconsultas `COUNT(*)` sobre
  `Menu_Material_Apoyo_Estadistica`), y ordena por `MMA_ORDEN`.
- `SEL_MENU_MATERIAL_APOYO_ESTADISTICAS` tiene dos formas de `SELECT` según
  `@EXCEL`: en `0` devuelve columnas técnicas (`mae_id`, `tipo`,
  `NOMBRE_USUARIO`...) para la grilla; en `1`, encabezados en español para el
  informe.

### 4.3 Trigger de auditoría

`TRG_LOG_Menu_Material_Apoyo` sobre `Menu_Material_Apoyo`,
`FOR INSERT, UPDATE, DELETE`. Usa una tabla temporal global
`##Menu_Material_Apoyo_TEMP_LOG` y escribe una fila por columna modificada en
`LOG`, con un **id de módulo** (en SGF: `'25'`).

> Ese id de módulo es específico de cada base. Verificar qué numeración usa el
> proyecto destino antes de copiar el trigger.

---

## 5. Pasos de implementación

1. **Completar la §3.** No seguir si algo quedó sin verificar.
2. Copiar los archivos del inventario (§2) respetando rutas.
3. Crear la carpeta `~/MaterialApoyo/` y dar permisos de escritura al App Pool.
4. `Web.config` → `<add key="MaterialApoyo" value="~/MaterialApoyo/"/>`.
5. Portar `SitioBase.MaterialApoyo(...)` a `App_Code/SitioBase/SitioBase.cs`
   (requiere `using System.Configuration; System.IO; System.Web;`).
6. Crear tablas, SPs y trigger en la BD, adaptados según §3.2.
7. Insertar los menús (§5.1) y ajustar `Paginas.cs`.
8. Actualizar `MenuMaterialApoyos.aspx.cs` → `Paginas.menu_<N>.Ver` con el id real.
9. Master: link al CSS, panel del navbar, `<script>` de `materialApoyo.js` +
   `abrirCapsula()`, y `CargarMaterialApoyo()` en `Page_PreRender`.
10. Adaptar botones y `RadWindow2` a las convenciones del destino (§3.4).
11. Compilar (§7) y asignar permisos de menú al perfil desde
    **Sistema › Acceso › Perfiles**.

### 5.1 Menús

Solo hacen falta **dos**: el contenedor y el mantenedor. La pantalla de
estadísticas se abre como popup desde el formulario, no necesita menú propio.

```sql
DECLARE @PADRE INT = <id_menu_sistema>;
DECLARE @ID    INT = <MAX(mnu_id) + 1>;

SET IDENTITY_INSERT MENUS ON;

INSERT INTO MENUS (mnu_id, mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon)
VALUES (@ID, 'Material de Apoyo', 'Material de Apoyo', 3, @PADRE, 5, '#', 1, 'fas fa-info-circle');

INSERT INTO MENUS (mnu_id, mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon)
VALUES (@ID + 1, 'Mantenedor', 'Mantenedor de Material de Apoyo', 4, @ID, 1,
        '~/View/MaterialApoyo/Mantenedores/MenuMaterialApoyos.aspx', 1, NULL);

SET IDENTITY_INSERT MENUS OFF;
```

Y en `Paginas.cs`:

```csharp
//Material de Apoyo
public enum menu_<N>
{
    Ver = <N>,
}

//Material de Apoyo - Mantenedor
public enum menu_<N+1>
{
    Ver = <N+1>,
}
```

---

## 6. Trampas conocidas

Todas detectadas en el port real FacilityGes → SGF.

### 6.1 Ruta incorrecta de `DescargarArchivo.aspx`

En `Default.master.cs` el original arma la URL como
`~/MaterialApoyo/Mantenedores/DescargarArchivo.aspx`, pero el archivo vive en
`~/View/MaterialApoyo/Mantenedores/`. Los Excel y Word dan **404**.

```csharp
// Correcto
string descargaUrl = ResolveUrl("~/View/MaterialApoyo/Mantenedores/DescargarArchivo.aspx?path=" + HttpUtility.UrlEncode(virtualPath));
```

### 6.2 AppSetting equivocado al eliminar

`MenuMaterialApoyos.aspx.cs`, en `lnkEliminar_Click`, lee
`ConfigurationManager.AppSettings["Capsulas"]` — nombre antiguo del módulo. Si
la clave no existe, `Server.MapPath(null)` lanza excepción al limpiar carpetas
vacías. Debe ser `AppSettings["MaterialApoyo"]`.

### 6.3 `DataKeyNames` vs `ClientDataKeyNames`

El grid del mantenedor declara solo `ClientDataKeyNames`, pero el code-behind
usa `item.GetDataKeyValue("MMA_ID")` y `MasterTableView.DataKeyValues[...]`,
que leen las **DataKeyNames de servidor**. Declarar ambas:

```aspx
<MasterTableView DataKeyNames="MMA_ID, MMA_MENU, MMA_RUTA, MMA_ORDEN"
                 ClientDataKeyNames="MMA_ID, MMA_MENU, MMA_RUTA, MMA_ORDEN"
                 CommandItemDisplay="Top">
```

### 6.4 Trigger y SP con lógica de países

> `El nombre de objeto Usuario_Paises no es válido.`

El trigger de FacilityGes calcula la fecha con la hora del país del usuario:

```sql
SELECT TOP 1 @PAIS_USUARIO = upa_id_pais FROM Usuario_Paises WHERE upa_id_usuario = @USUARIO
IF @PAIS_USUARIO IS NOT NULL SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
ELSE SET @DATE_NOW = GETDATE()
```

En proyectos de un solo país eso no existe. Reemplazar por:

```sql
DECLARE @DATE_NOW DATETIME
SET @DATE_NOW = GETDATE()
```

Aplica también a `DEL_MENU_MATERIAL_APOYO` (quitar el parámetro `@PAIS` y su
`FNC_PAIS_HORA`) **y al C#**, en
`MenuMaterialApoyoController.DeleteMenuMaterialApoyo`: borrar la línea
`cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());`.

> El error no aparece al consultar, solo al **insertar/actualizar/eliminar**
> material, porque quien falla es el trigger. Revisar dependencias con:
>
> ```sql
> SELECT o.name, d.referenced_entity_name,
>        CASE WHEN OBJECT_ID(d.referenced_entity_name) IS NULL THEN 'NO EXISTE' ELSE 'ok' END
> FROM sys.sql_expression_dependencies d
> INNER JOIN sys.objects o ON o.object_id = d.referencing_id
> WHERE o.name LIKE '%MATERIAL_APOYO%';
> ```

### 6.5 Clases CSS de botones inexistentes

`icono_guardar` no existe en SGF: el botón "Nuevo" se renderiza como texto
plano sin estilo (el de Eliminar sí funciona porque `icono_eliminar` sí
existe). Ver §3.4.

### 6.6 `RadWindow2` sin skin

En SGF el modal se ve sin estilo si no se pasa
`EnableEmbeddedSkins="true" Skin="MetroTouch"`.

### 6.7 Controles residuales del copy

`MenuMaterialApoyo.aspx` arrastra un `<rad:RadWindow2 ID="rwiUsuario" ... />`
que no se usa en ninguna parte. Eliminarlo.

### 6.8 `OnClientClick` sin `return false`

Varios botones portados quedan como `OnClientClick="closeWindow();"` o
`OnClientClick="abrir(0)"`, lo que dispara además el postback. Agregar
`return false;`.

---

## 7. Verificación

### 7.1 Compilación

```bash
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe" -v "/Check" -p "C:\ruta\<RaizWeb>" "C:\temp\salida" -f
```

Debe terminar en `exitcode=0`. Los `warning CS0168` preexistentes son normales.

### 7.2 Funcional

| # | Prueba | Esperado |
|---|---|---|
| 1 | Entrar a una página sin material | El ícono del navbar no aparece |
| 2 | Cargar un PDF al menú de esa página y recargar | Aparece el ícono con el ítem |
| 3 | Clic en el ítem | Abre el Reproductor y el contador de "visto" sube |
| 4 | Clic en "Me gusta" y recargar | El corazón queda activo y el contador persiste |
| 5 | Clic de nuevo en "Me gusta" | Se desmarca y el contador baja (toggle del SP) |
| 6 | Clic en "No me gusta" teniendo "Me gusta" | Se traspasa: baja uno, sube el otro |
| 7 | Cargar un `.xlsx` y hacer clic | Descarga el archivo (no abre Reproductor) |
| 8 | Cambiar el orden en la grilla y salir del campo | SweetAlert de confirmación y refresco |
| 9 | Eliminar un material | Borra fila, archivo físico y carpetas vacías |
| 10 | "Descargar Estadísticas" | Excel con encabezados en español |
| 11 | Entrar con un perfil sin permiso al mantenedor | Redirige (`SecurityManagerVer`) |

### 7.3 Rollback

```sql
DELETE FROM MENUS WHERE mnu_id IN (<N>, <N+1>);
DROP TRIGGER TRG_LOG_Menu_Material_Apoyo;
DROP TABLE Menu_Material_Apoyo_Estadistica;
DROP TABLE Menu_Material_Apoyo;
-- y los 7 SPs
```

En código: revertir `Master/Default.master(.cs)`, `Paginas.cs`, `SitioBase.cs`,
`Web.config` y borrar las carpetas del módulo.
