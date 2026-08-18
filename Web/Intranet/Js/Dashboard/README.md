# Dashboard de Cumplimiento de Checklists — Guía técnica

Documentación de **cómo funciona completo** el Dashboard de Cumplimiento:
base de datos, capa C#, JavaScript modularizado, layouts, builder y modo
presentación.

> **Documento único.** Es la ÚNICA documentación vigente del dashboard y vive
> junto al código, por decisión del equipo. Reemplaza al antiguo
> `MD/DASHBOARD.md` (eliminado), que estaba desactualizado: describea un "gauge
> por tipo" que no existe con esa forma y una tabla `UserDashboardConfiguration`
> que nunca se llamó así.
> Nota: `CLAUDE.md` §1 indica que la documentación del proyecto vive en `MD/`;
> este archivo es una excepción deliberada.

---

## 1. Mapa de archivos

```text
Web/Intranet/
├── Js/Dashboard/Cumplimiento/          ← JS modularizado (8 archivos)
│   ├── 01-Core.js        config, storage, cfg por nivel, registro, dclInit
│   ├── 02-Presentacion.js modo presentación y rotación entre dashboards
│   ├── 03-CardConfig.js   panel de configuración de un widget
│   ├── 04-Layout.js       dclApplySectionState, tablas, columnas, KPIs
│   ├── 05-Builder.js      "Armar Dashboard"
│   ├── 06-Layouts.js      layouts guardados
│   ├── 07-Onboarding.js   tour guiado
│   └── 08-Datos.js        AJAX, auto-refresh y ARRANQUE (va último)
│
├── Css/LookAndFeel/v2/09-DashboardChecklist.css    ← todo el CSS del dashboard
│
├── View/Comun/Controls/Cliente/Informes/
│   ├── DashboardChecklist.ascx(.cs)                ← página/control anfitrión
│   └── DashboardChecklist/Widgets/*.ascx(.cs)      ← un UserControl por widget
│
├── App_Code/MVC/Facilityges/Controller/
│   ├── DashboardChecklistController.cs             ← lee los SP
│   └── DashboardChecklist/*Renderer.cs             ← HTML de cada widget
│
├── App_Code/WebService/WsDashboardChecklist.cs     ← AJAX (refresh y drill-down)
│
BD/
├── RPT_DASHBOARD_CHECKLIST.sql        ← SP principal (7 result sets)
└── RPT_DASHBOARD_CHECKLIST_ZONA.sql   ← SP del nivel Zona (4 result sets)
```

---

## 2. Los tres niveles (drill-down)

El dashboard tiene **tres niveles**, cada uno con su propio set de widgets y su
propio layout guardado:

| Nivel | Cuándo | Responde |
|---|---|---|
| `general` | sin instalación seleccionada | ¿cómo va el cliente completo? |
| `instalacion` | al entrar a una instalación | ¿cómo van las zonas de esta instalación? |
| `zona` | al entrar a una zona | ¿qué se respondió, a qué hora y con qué hallazgos? |

El nivel activo se publica en el hidden `hfNivel` y lo lee
`dclNivelActual()` (`01-Core.js`). **Es la fuente de verdad del nivel en el
cliente**: casi todo (clave de config, módulo del WebService, widgets
disponibles, categoría de layout) se deriva de ahí.

La navegación entre niveles es **AJAX pura, sin postback**: los combos de la
barra de filtros tienen `AutoPostBack="false"` y la cascada se resuelve en el
cliente.

---

## 3. Flujo de datos

```text
SQL Server ──► DashboardChecklistController ──► Models
                                                 │
                    ┌────────────────────────────┴───────────────┐
                    ▼                                            ▼
        DashboardChecklist.ascx.cs                   WsDashboardChecklist.cs
        (carga inicial, server-side)                 (auto-refresh + drill-down)
                    │                                            │
                    └──────────► *Renderer.cs ◄──────────────────┘
                                  (HTML único)
```

### Los Renderers son fuente única de verdad

Cada widget se dibuja en **una sola** clase `*Renderer.cs` con la forma
`RenderCard(StringBuilder, ...)`. La usan **tanto** el code-behind (carga
inicial) **como** el WebService (refresh AJAX y modo presentación).

> **Regla:** nunca duplicar HTML de un widget en el `.ascx` o en el WebService.
> Si el HTML de un widget se escribe en dos lugares, la carga inicial y el
> refresh empiezan a divergir — que es exactamente el tipo de bug más difícil de
> ver, porque solo aparece después del primer refresco.

El orden de las llamadas `RenderCard(...)` en `WsDashboardChecklist.cs` debe
coincidir con el de los `wucXxx.Cargar(...)` del code-behind y con el de los
`<wuc:*>` del `.ascx`. **Los tres se mantienen sincronizados a mano.**

### Widgets por nivel

Tanto el code-behind como el WebService bifurcan por nivel: el servidor
**solo renderiza los widgets del nivel actual**. Estando en General, los nodos
de `dcl-zonas` o `dcl-resp-dia` sencillamente **no existen en la página**. Esto
tiene consecuencias directas en el builder (ver §6).

---

## 4. Base de datos

### `RPT_DASHBOARD_CHECKLIST` (7 result sets)

Alimenta los tres niveles (recibe `@CLIENTE`, `@INSTALACION`, `@ZONA`).

- **RS1** KPIs globales · **RS2** por instalación · **RS3** por tipo de revisión
- **RS4** detalle por instalación+checklist · **RS5** meses · **RS6** supervisores
- **RS7** top pendientes

Puntos de diseño que conviene entender antes de tocarlo:

- **El cumplimiento solo considera `czt_control_hora = 1`.** Un checklist sin
  control de horario no tiene horario que cumplir, así que no entra al %.
- Se exige `CCR_ID_PROGRAMACION IS NOT NULL`: cumplimiento significa "se hizo lo
  agendado". Una respuesta espontánea no tiene horario contra el cual medirse.
- **`#SinHorario`** cuenta los "SIN CONTROL" desde las tablas de **definición**
  (`CZC`/`CZT`), no desde `CCR`, porque esos checklists todavía no generaron
  instancias. El JOIN con `CZT` es **INNER a propósito**: solo cuenta si existe
  un tipo de revisión configurado. Con `LEFT JOIN`, un checklist sin ningún tipo
  daba `czt_control_hora = NULL`, el `ISNULL(...,0)=0` lo colaba en "SIN
  CONTROL" e inflaba la card con checklists que en realidad están sin configurar.
- **"SIN CONTROL" y el total son poblaciones distintas y mutuamente
  excluyentes.** Para porcentajes hay que dividir por `CklTotal + CklSinEstado`,
  no por `CklTotal` (esto ya produjo un "600%" en producción).

### `RPT_DASHBOARD_CHECKLIST_ZONA` (4 result sets)

Nivel Zona: KPIs con control horario, sin control horario, respuestas del día y
cumplimiento por zona. Recibe `@FECHA_DESDE`/`@FECHA_HASTA`.

> **Trampa de SQL Server:** no se puede sumar `DATE + TIME`. Para combinar
> `CCR_FECHA` con `ZCR_HORA` hay que usar
> `DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME), CAST(ZCR.ZCR_HORA AS TIME)), CAST(CCR.CCR_FECHA AS DATETIME))`.
> La forma directa lanza *"El tipo de datos date del operando no es válido para
> el operador add"*.

Ambos SP siguen `MD/BaseDatos/PATRON_SP.md` (dinámico `@SELECT/@FROM/@WHERE` +
`EXEC`).

---

## 5. JavaScript: por qué está así

### Modularizado, pero en scope global

Los 8 archivos se cargan con `<script>` en orden desde el `.ascx`. **No son ES
modules**, y es deliberado: hay **~30 funciones invocadas desde `onclick` /
`onchange` inline** en el propio JS, más otras desde el `.ascx` y desde el HTML
que emiten los Renderers de C#. El scope de módulo rompería todos esos
handlers.

> Si agregas un archivo nuevo, súmalo al `.ascx` **antes** de `08-Datos.js`, que
> es el que cierra con el bloque de arranque (`dclInit()` +
> `dclStartAutoRefresh()`).

### Convenciones

- Todo prefijado `dcl` / `_dcl`.
- Los ids de sección son `data-section="dcl-*"` y son la llave de todo el
  sistema de layouts.
- Íconos: **Material Design Icons v3.0.39**. Es una versión vieja — muchos
  íconos comunes no existen (`mdi-timetable` sí, `mdi-view-dashboard-edit` no).
  **Verifica siempre** contra `Css/Adminto/assets/css/materialdesignicons.min.css`
  antes de usar uno nuevo.

---

## 6. Sistema de layouts

### Modelo de configuración (v2)

```js
{
  rows: [ { cols: 2, slots: ['dcl-kpi', {sec:'dcl-sla', span:2}, null] } ],
  sectionHeights: { 'dcl-kpi': '1' },
  _vista: 'zona'
}
```

- Un **slot** puede ser `string`, `null` (columna vacía como separador) u
  **objeto `{sec, span}`**. Usa siempre `dclSlotSec()` / `dclSlotSpan()` para
  leerlos; tratarlos como string genera selectores
  `[data-section="[object Object]"]` que no encuentran nada y dejan columnas
  vacías en silencio.
- **`_vista` es el NIVEL** (`general` | `instalacion` | `zona`). Debe marcarse
  con `dclNivelActual()`, nunca derivarse de si hay instalación seleccionada:
  en nivel Zona el hidden de instalación también viene poblado, y ese error
  hacía que un layout de Instalación quedara congelado en Zona.

### Almacenamiento

| Clave | Contenido |
|---|---|
| `dcl_cfg_<usuario>_<nivel>` | layout activo de ese nivel |
| `dcl_cfgver_<usuario>` | versión del default aplicada |
| `dcl_saved_checklists_<nivel>` | layouts guardados de esa categoría |
| `dcl_active_name_checklists_<nivel>` | nombre del layout activo |
| `dcl_theme`, `dcl_refresh_ms` | preferencias |
| `dcl_onb_visto`, `dcl_onb_bld_visto` | onboarding ya visto |

Además se persiste en la base vía `WsDashboardConfig.asmx`
(`USUARIO_DASHBOARD_CONFIGURACION`), con el módulo `checklists_<nivel>`.

### Versionado del layout por defecto

`_DCL_DEFAULT_VER` en `01-Core.js`. **Subilo cada vez que cambies
`dclDefaultCfg()`**: sin eso, el cfg que el usuario ya tiene guardado gana
siempre y nunca ve la estructura nueva.

`dclResetCfgSiVersionVieja()` corre **fuera** de `_isFirstRender` a propósito:
esa bandera vive en `sessionStorage` y sobrevive a las recargas, así que la
migración no se ejecutaba si ya habías abierto el dashboard en esa sesión.

---

## 7. Builder ("Armar Dashboard")

**Trabaja con placeholders, no con los widgets reales.**

Originalmente movía las secciones DOM reales al canvas del modal. Eso lo ataba
al nivel actual: como el servidor solo renderiza los widgets de ese nivel, no
había forma de armar el layout de otra categoría (el pool salía vacío).

Hoy:

- El **pool** se arma desde `_DCL_SECTION_REGISTRY` + `_DCL_SECTIONS_POR_NIVEL`,
  no desde el DOM. Por eso el registro incluye `nom` e `ico` de cada widget:
  son obligatorios y deben coincidir con el `BeginCard(...)` del Renderer.
- Cada celda contiene un **placeholder** que conserva `class="dcl-section"` y
  `data-section`, porque `dclBldCollectCfg()` y el DnD leen por ese selector.
- El placeholder muestra una **miniatura real** del widget (`zoom: .55`) clonando
  el nodo si existe en la página; si es de otra categoría, se pide el HTML al
  WebService (`dclBldCargarPreviews`) y se cachea.
- Un combo permite elegir la **categoría destino**; al guardar, el layout se
  persiste en `dcl_cfg_<usuario>_<categoría>` y **no** se aplica a la vista
  actual si son distintas (dejaría todos los slots vacíos).
- `_bldLayoutId` recuerda qué layout guardado se está editando, para volcar
  ahí el resultado en vez de crear duplicados.

> Usa **`zoom`**, no `transform: scale()`, para las miniaturas: el transform es
> puramente visual y el clon sigue reservando su alto original, dejando un hueco
> enorme bajo cada tarjeta.

---

## 8. Modo presentación

- **Sin scroll por defecto**: los widgets se reparten el alto con flex
  (`min-height: 0` es imprescindible en toda la cadena). La primera fila (KPIs)
  nunca se encoge.
- Con **más de 3 filas** se habilita scroll y aparece el botón "Desplazamiento".
- El botón *play* recorre el contenido **dentro** de cada widget con `rAF`.
- Permite **rotar entre varios dashboards** (General / Instalación / Zona) con
  cascada Cliente → Instalación → Zona; cada entrada lleva su propio `cli`,
  `cin`, `ciz`.
- Una **barra de progreso** en el encabezado marca cuánto falta para el cambio.
  Se reinicia al arrancar el turno (no al llegar la respuesta del XHR) para no
  desincronizarse del `setInterval`, y necesita un reflow forzado entre el reset
  y el arranque o el navegador colapsa ambos cambios de `width` en uno.
- En reposo se ocultan **solo los controles** (`.dcl-pres-acts`). El título y la
  barra deben permanecer visibles: en una TV el mouse está quieto casi siempre.

---

## 9. Auto-refresh

`dclAutoRefreshAjax()` reemplaza `#dcl-content` con el HTML del WebService y
vuelve a llamar a `dclInit()`.

**Nunca corre si hay un overlay abierto** (`dclHayOverlayAbierto()`): si no,
cierra de golpe el dropdown o modal que el usuario está usando. La lista de
overlays está en `_DCL_OVERLAY_SELS`; los paneles comparten el shell
`.dcl-layouts-panel`, así que agregar uno nuevo con ese shell ya queda cubierto.

---

## 10. Antes de tocar este módulo

- [ ] Archivos en **UTF-8 con BOM + CRLF** (`CLAUDE.md` §9). Sin excepción.
- [ ] Los `.js` marcados solo-lectura por TFVC: limpiar `IsReadOnly` antes de
      editar.
- [ ] Validar sintaxis: `node --check <archivo>`.
      **Ojo:** solo detecta errores de *parseo*. Una variable inexistente es un
      `ReferenceError` de ejecución y el check pasa igual — hay que abrir el
      dashboard en el navegador y mirar la consola.
- [ ] Íconos MDI verificados contra la v3.0.39.
- [ ] Si cambiaste `dclDefaultCfg()`, subí `_DCL_DEFAULT_VER`.
- [ ] Si agregaste un widget: Renderer + UserControl + `_DCL_SECTION_REGISTRY`
      (con `nom` e `ico`) + `_DCL_SECTIONS_POR_NIVEL` + code-behind + WebService,
      **en el mismo orden en los tres últimos**.
- [ ] Compilar en Visual Studio si tocaste C#.

---

## 11. Errores ya cometidos en este módulo

Vale la pena leerlos: son los que más caro salieron.

| Síntoma | Causa real |
|---|---|
| "600%" en Sin Horario | dividir por `CklTotal`, que excluye a los Sin Control |
| Widgets no cargan al hacer drill-down, sin error visible | los combos tenían `AutoPostBack="true"` y el postback abortaba el AJAX; además un `if (!d.ok) return` se tragaba el error del servidor |
| El layout de Zona mostraba widgets de Instalación | `_vista` derivado de "¿hay instalación?" en vez del nivel |
| Widgets que solo aparecían tras refrescar | consecuencia del punto anterior: el refresh sí reinicializaba el cfg |
| Canvas del builder vacío al editar un layout | slot `{sec, span}` usado como string |
| Íconos que no se ven | MDI v3.0.39 no tiene el ícono; falla en silencio |
| Dropdowns que se cierran solos | el auto-refresh no conocía ese overlay |
| Onboarding que nunca aparecía | dependía de `_isFirstRender`, bandera de `sessionStorage` que sobrevive a las recargas |

---

## 12. Roadmap

Heredado del antiguo `MD/DASHBOARD.md` y actualizado al estado real.

### Ya implementado

- **Persistencia de layouts en base de datos.** El doc anterior lo listaba como
  pendiente y proponía una tabla `UserDashboardConfiguration` con SPs
  `INS_/SEL_/UPD_/DEL_UDC`. Nada de eso llegó a existir con esos nombres: la
  tabla real es **`USUARIO_DASHBOARD_CONFIGURACION`** (FK a `Usuario.usu_id`) y
  el acceso va por **`WsDashboardConfig.asmx`** (`GetConfig` / `SaveConfig`),
  con el módulo `checklists_<nivel>`. Si encontrás código o scripts que
  referencien `UserDashboardConfiguration`, están rotos.

### Pendiente

1. **Módulos adicionales** — replicar esta arquitectura para Órdenes de Trabajo
   (`RPT_DASHBOARD_OT.sql`), Tareas (`RPT_DASHBOARD_TAREAS.sql`) y Bitácora
   (`RPT_DASHBOARD_BITACORA.sql`), cada uno con su `.ascx`, CSS y WebService.
2. **Selector dinámico de módulo** — dropdown en la topbar para cambiar de
   dashboard vía AJAX sin recargar.
3. **Resize estilo Figma** — handles en las esquinas de cada sección para
   ajustar el alto arrastrando.
4. **Constructor visual de gráficos** — wizard módulo → fuente → columnas →
   tipo de gráfico.

### Deuda técnica conocida

- **Nombres de módulo corridos:** `07-Onboarding.js` arranca con
  `dclSaveCurrentLayout` (cola de layouts) y `08-Datos.js` con
  `dclOnbPosicionarPop` (cola del onboarding). Los cortes del split cayeron en
  frontera de función válida, pero unas funciones antes del cambio de dominio.
- **`dcl-sec-pooled`**: quedan referencias residuales del builder anterior. Hoy
  nadie marca esa clase; los `:not(.dcl-sec-pooled)` se cumplen siempre.
- **El builder no restituye el `span`** de columnas al cargar un layout: un
  widget que ocupa 2 columnas se carga ocupando 1 y ese ajuste se pierde al
  guardar (ver `dclBldPintarFilas`, que usa `dclSlotSec` pero no `dclSlotSpan`).
