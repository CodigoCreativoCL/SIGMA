# PATRONES / ASP — Estándar de programación WebForms (Website)

Patrones **genéricos** de programación para los proyectos ASP.NET **WebForms
(Web Site Project)** del grupo: `FacilityGes`, `SGF`, `Workges`, `Trabajaya` /
`TrabajaYaV2`, `Agendamientos`, `Psol`, `Correos`...

Objetivo: que cualquier desarrollador **o agente de IA** que trabaje en uno de
estos proyectos escriba el mismo código, con la misma estructura, nombres y
manejo de errores que el resto del código existente — y que portar una
funcionalidad de un proyecto a otro sea copiar + renombrar, no rediseñar.

> Estos documentos son **el estándar**. Si el proyecto destino ya tiene un
> `MD/` propio (ej. `FacilityGes/MD/`), ese hereda de aquí: ante diferencias,
> gana lo que ya existe **en el proyecto destino** (ver §3 Adaptación), pero
> todo lo nuevo se escribe según estos patrones.

---

## 1. Cómo usar esta carpeta

### 1.1 Si eres un agente (Claude Code u otro)

Antes de escribir **una sola línea** de C# o SQL en un proyecto WebForms del
grupo:

1. Lee [`CONVENCIONES.md`](CONVENCIONES.md) — reglas duras (naming, encoding,
   prohibiciones). Es corto y es obligatorio.
2. Lee el patrón que aplique a la tarea (tabla de abajo).
3. Abre **un archivo real ya existente del proyecto destino** del mismo tipo
   (un Controller, un `.ascx` de grilla, un SP) y confirma que las convenciones
   coinciden. Los proyectos comparten patrón, pero **no** siempre las mismas
   clases CSS, rutas de librerías ni infraestructura de BD (§3).
4. Recién ahí, escribe el código usando las plantillas de estos documentos,
   sustituyendo los marcadores `<...>` (§2).

### 1.2 Índice

| Documento | Cuándo leerlo |
|---|---|
| [`CONVENCIONES.md`](CONVENCIONES.md) | **Siempre.** Naming, encoding UTF-8 BOM, TFS, prohibiciones |
| [`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md) | Crear/alterar tablas, índices, constraints, triggers de auditoría |
| [`BaseDatos/PATRON_SP.md`](BaseDatos/PATRON_SP.md) | Crear/editar Stored Procedures (`SEL_`/`INS_`/`UPD_`/`DEL_`) |
| [`Desarrollo/PATRON_MVC.md`](Desarrollo/PATRON_MVC.md) | Crear Model, Controller, UserControls y páginas de una entidad |
| [`Desarrollo/PATRON_CONTROLES.md`](Desarrollo/PATRON_CONTROLES.md) | Usar controles de UI (`Rad*2`, `WebControls:*`, validators, chips) |
| [`Desarrollo/PATRON_GRID_EVENTS.md`](Desarrollo/PATRON_GRID_EVENTS.md) | Acciones por fila en una grilla (`ItemCreated`/`ItemDataBound`/`Command`) |
| [`Desarrollo/PATRON_WEBSERVICE_AJAX.md`](Desarrollo/PATRON_WEBSERVICE_AJAX.md) | Endpoints AJAX (ASMX ScriptService) llamados desde JS |
| [`Desarrollo/PATRON_SEGURIDAD_MENUS.md`](Desarrollo/PATRON_SEGURIDAD_MENUS.md) | Menús, permisos por perfil, `Paginas.cs`, querystring cifrado |
| [`CHECKLIST_ENTIDAD_NUEVA.md`](CHECKLIST_ENTIDAD_NUEVA.md) | Guion end-to-end: de la tabla hasta el menú, sin saltarse pasos |
| [`Funcionalidades/`](Funcionalidades/) | Guías para **portar** un módulo completo entre proyectos |

---

## 2. Marcadores genéricos usados en todos los documentos

Los ejemplos están escritos con marcadores. Sustituirlos **siempre** por los
valores reales del proyecto/entidad antes de escribir el archivo final.

| Marcador | Significa | Ejemplo real |
|---|---|---|
| `<Proyecto>` | Nombre del proyecto / namespace raíz del `App_Code/MVC` | `Facilityges`, `Sgf`, `Workges` |
| `<BaseDatos>` | Nombre de la BD SQL Server | `FacilityGes`, `SGF`, `Agendamientos` |
| `<RaizWeb>` | Carpeta raíz del sitio web | `Web/Intranet`, `Web`, `Sitio` |
| `<Entidad>` | Entidad en PascalCase (clase C#) | `Cliente`, `ClienteTarea`, `MenuMaterialApoyo` |
| `<Tabla>` | Tabla en `Pascal_Snake_Case` | `Cliente`, `Cliente_Tarea`, `Menu_Material_Apoyo` |
| `<TABLA>` | La misma tabla en MAYÚSCULAS (nombres de SP) | `CLIENTE_TAREA` |
| `<pfx>` | Prefijo de 3 letras de la tabla (minúsculas) | `cli`, `cta`, `mma` |
| `<PFX>` | El mismo prefijo en MAYÚSCULAS | `CLI`, `CTA`, `MMA` |
| `<Modulo>` | Carpeta de módulo dentro de `View/` | `Comercial`, `Comun`, `Clientes`, `Sistema` |
| `<N>` | Id numérico de menú/función de seguridad | `73`, `77` |

La regla de derivación de `<Tabla>` y `<pfx>` está en
[`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md) §1.

---

## 3. Adaptación al proyecto destino (verificar antes de copiar)

Todos los proyectos comparten el patrón, pero **no** todos tienen la misma
infraestructura. Antes de portar código entre proyectos, verificar:

### 3.1 Código

| # | Verificar | Dónde |
|---|---|---|
| 1 | Carpeta de librerías: `Librarias/Library/` vs `Librerias/Library/` (el nombre varía por proyecto) | raíz del proyecto |
| 2 | Wrappers Telerik `RadGrid2`, `RadComboBox2`, `RadNumericBox2`, `RadWindow2`, `RadTabStrip2` | `Lib*/Library/Web/UI/Telerik/*.cs` |
| 3 | Firma de `RadGrid2.AddColumn` (named params `Width:`, `Wrap:`, `Align:`) y existencia de `AddSelectColumn` / `AddCheckboxColumn` / `AddTemplateColumn` | `RadGrid2.cs` |
| 4 | Controles propios `TextBox2`, `TextArea2`, `PushButton`, `ComboBox2`, `CheckBox2` | `Lib*/Library/Web/UI/WebControls/*.cs` |
| 5 | Clase `Respuesta` (`codigo`, `detalle`, `error`, `table`...) | `Lib*/Library/Tools/Respuesta.cs` |
| 6 | `Tools.Crypto.Encrypt/Decrypt`, `Tools.tools.ClientAlert`, `Tools.tools.RegisterPostBackScript`, `Tools.tools.ClientExecute` | `Lib*/Library/Tools/` |
| 7 | `SitioBase`: `Token.TokenSeguridad()`, `Token.SecurityManager(...)`, `Token.SecurityManagerVer(...)`, `Session.UsuarioId()`, `Conexion.GetCommand/GetDataReader`, `Paginas.menu_<N>` | `App_Code/SitioBase/`, `App_Code/MVC/SitioBase/` |
| 8 | Funciones JS globales: `validaControl`, `ConfirSweetAlert`, `popup`, `refresh` | `Js/Library.js` |
| 9 | Clases CSS de botones/íconos (`icono_guardar`, `icono_eliminar`, `icono_Editar`, `btn_dinamico`...) — **varían entre proyectos** | `Css/UI/...` |
| 10 | El master ya declara el `ScriptManager` (nunca agregar otro en un UserControl) | `Master/Default.master` |

### 3.2 Base de datos

```sql
-- ¿Existen los objetos base que asumen estos patrones?
SELECT 'INS_EXCEPCION' AS OBJETO, OBJECT_ID('INS_EXCEPCION')       AS ID
UNION ALL SELECT 'LOG',            OBJECT_ID('LOG')
UNION ALL SELECT 'MENUS',          OBJECT_ID('MENUS')
UNION ALL SELECT 'USUARIO',        OBJECT_ID('USUARIO')
UNION ALL SELECT 'Usuario_Paises', OBJECT_ID('Usuario_Paises')
UNION ALL SELECT 'FNC_PAIS_HORA',  OBJECT_ID('FNC_PAIS_HORA');
```

| Resultado | Acción |
|---|---|
| `INS_EXCEPCION` NULL | Crear el SP, o quitar los `EXEC INS_EXCEPCION` de las plantillas |
| `LOG` NULL | El proyecto no audita por trigger → omitir el trigger de auditoría |
| `Usuario_Paises` / `FNC_PAIS_HORA` NULL | Proyecto **mono-país** → usar `GETDATE()` en vez de `FNC_PAIS_HORA(@PAIS)` y no propagar `@PAIS` |

### 3.3 Diferencias conocidas entre proyectos

| Tema | FacilityGes | Otros proyectos (verificar) |
|---|---|---|
| Botón "Nuevo" en `CommandItemTemplate` | `CssClass="icono_guardar"` | SGF usa `btn_dinamico btn_nuevo` + `span.text` / `span.icon` dentro de `div.contenedor-botones` |
| `RadWindow2` | sin skin explícito | SGF requiere `EnableEmbeddedSkins="true" Skin="MetroTouch"` |
| Multi-país | sí (`Usuario_Paises`, `FNC_PAIS_HORA`, filtros por país) | normalmente no |
| Carpeta de librerías | `Librarias/` | `Librerias/` |

---

## 4. Stack asumido

- ASP.NET **WebForms – Web Site Project** (no MVC, no Web Application), .NET Framework 4.x.
- Capa de datos propia en `App_Code/MVC/` (carpetas `Model` y `Controller`) —
  un "MVC manual", **no** ASP.NET MVC.
- Acceso a datos **solo** por Stored Procedures (nunca SQL embebido en C#).
- Telerik UI for ASP.NET AJAX envuelto en wrappers propios (`Rad*2`).
- Bootstrap para el layout (grid de 12 columnas).
- SQL Server.
- Control de código fuente **TFS/TFVC** (archivos read-only hasta hacer checkout).

---

## 5. Mantención de estos patrones

- Si al implementar algo descubres una regla nueva que el equipo aplica de
  forma consistente, **agrégala aquí**, no solo en el proyecto donde la
  descubriste.
- Si un patrón deja de aplicarse, márcalo como obsoleto con la fecha y el
  motivo en vez de borrarlo en silencio.
- Los documentos de `Funcionalidades/` describen módulos completos portables:
  al portar uno a un proyecto nuevo, actualizar la guía con las trampas nuevas
  que aparezcan (sección "Trampas conocidas").
