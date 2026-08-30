# Entrenamiento — Patrones de Desarrollo .NET

**Equipo Código Creativo · CAPSTONE · Proyecto SIGMA**

Material de capacitación sobre los patrones de programación que usaremos en SIGMA, tomados del sistema **FacilityGes** (Grupo EXPRO).

> El código de esta carpeta es **material de entrenamiento**. No compila por sí solo: depende de librerías del proyecto real (`SitioBase`, `WebControls`, wrappers de Telerik). Está pensado para leerse y explicarse, no para ejecutarse.

---

## 🚀 Cómo empezar

Abre **[`capacitacion.html`](capacitacion.html)** en el navegador — es la versión navegable de todo este material, con el código resaltado y los diagramas de flujo. Es lo que se proyecta en la sesión.

Para leer en VS Code, empieza por [`01-Guias/GUIA_01_PATRON_MVC.md`](01-Guias/GUIA_01_PATRON_MVC.md).

---

## 📁 Contenido

```
ENTRENAMIENTO/
├── capacitacion.html            ← versión navegable (empezar aquí)
├── README.md                    ← este archivo
│
├── 00-Patrones-Originales/      copia textual de FacilityGes/MD (referencia)
│   ├── PATRON_MVC.md
│   ├── PATRON_CONTROLES.md
│   ├── PATRON_GRID_EVENTS.md
│   └── PATRON_SP.md
│
├── 01-Guias/                    explicación didáctica de cada patrón
│   ├── GUIA_01_PATRON_MVC.md
│   ├── GUIA_02_PATRON_CONTROLES.md
│   ├── GUIA_03_PATRON_GRID_EVENTS.md
│   ├── GUIA_04_PATRON_SP.md
│   └── GUIA_05_FLUJO_END_TO_END.md
│
└── 02-Ejemplo-Usuario/          vertical completa comentada línea a línea
    ├── App_Code/MVC/Sigma/
    │   ├── Model/Usuario.cs
    │   └── Controller/UsuarioController.cs
    ├── View/Seguridad/
    │   ├── Controls/Usuario/
    │   │   ├── Usuarios.ascx(.cs)     grid
    │   │   ├── Usuario.ascx(.cs)      formulario (tabs)
    │   │   └── Identidad.ascx(.cs)    tab con el CRUD
    │   └── Usuarios/
    │       ├── Usuarios.aspx(.cs)     página listado
    │       └── Usuario.aspx(.cs)      página formulario
    └── BD/
        ├── 00_TBL_USUARIO.sql
        ├── 01_SEL_USUARIO.sql
        ├── 02_INS_USUARIO.sql
        ├── 03_UPD_USUARIO.sql
        └── 04_DEL_USUARIO.sql
```

---

## 📚 Agenda sugerida (4 sesiones)

| # | Sesión | Guía | Ejemplo en pantalla | Tiempo |
|---|---|---|---|---|
| 1 | Arquitectura y capas | [GUIA_01](01-Guias/GUIA_01_PATRON_MVC.md) | `Usuario.cs`, `UsuarioController.cs` | 45 min |
| 2 | Base de datos y SP | [GUIA_04](01-Guias/GUIA_04_PATRON_SP.md) | los 5 `.sql` | 50 min |
| 3 | Controles de UI | [GUIA_02](01-Guias/GUIA_02_PATRON_CONTROLES.md) | `Usuarios.ascx`, `Identidad.ascx` | 50 min |
| 4 | Eventos de grilla + cierre | [GUIA_03](01-Guias/GUIA_03_PATRON_GRID_EVENTS.md) + [GUIA_05](01-Guias/GUIA_05_FLUJO_END_TO_END.md) | recorrido completo | 75 min |

**Recomendación:** hacer la sesión 2 (base de datos) antes que las de UI. Cuando el equipo entiende el `WHERE 1=1` y el contrato de parámetros, el código del Controller deja de parecer arbitrario.

---

## 🎯 Las 10 reglas del patrón

1. **No es ASP.NET MVC.** Es WebForms; "Controller" = capa de acceso a datos.
2. **Cada capa habla solo con la de abajo.** `.aspx` → `.ascx` → Controller → SP → tabla.
3. **El Model es solo datos.** POCO `[Serializable]`, propiedades `<pfx>_<columna>` en minúsculas. Los `filtro_*` no existen en la BD.
4. **Cero SQL en C#.** Todo pasa por `SEL_` / `INS_` / `UPD_` / `DEL_`.
5. **`Token.TokenSeguridad()`** abre todo método del Controller.
6. **Los parámetros de filtro se agregan solo si vienen informados.** Es el contrato con el `WHERE 1=1` del SP.
7. **Se carga en `Page_PreRender`, se guarda en el evento del botón.**
8. **Las propiedades públicas de un UserControl van en `ViewState`**, nunca en campos privados.
9. **Toda operación de escritura devuelve `Respuesta`** (`codigo`, `detalle`, `error`), y ese `detalle` llega al usuario final.
10. **UTF-8 con BOM y CRLF** en todos los `.cs`, `.ascx`, `.aspx` y `.sql`.

---

## ✅ Checklist: entidad nueva "Xxx"

**Base de datos**

- [ ] `00_TBL_XXX.sql` — idempotente, prefijo de 3 letras, auditoría, constraints con nombre
- [ ] `01_SEL_XXX.sql` — `@SELECT`/`@FROM`/`@WHERE` + `EXEC`, filtros `= NULL`
- [ ] `02_INS_XXX.sql` — `@ID OUTPUT`, validaciones antes de la transacción, `SCOPE_IDENTITY()`
- [ ] `03_UPD_XXX.sql` — `@ID`/`@USUARIO` obligatorios, `ISNULL(@PARAM, columna)`
- [ ] `04_DEL_XXX.sql` — solo si es tabla de detalle

**App_Code**

- [ ] `Model/Xxx.cs` — propiedades + `filtro_*`
- [ ] `Controller/XxxController.cs` — `GetXxxs`, `GetXxx`, `InsertXxx`, `UpdateXxx`, `DeleteXxx`

**View**

- [ ] `Controls/Xxx/Xxxs.ascx(.cs)` — grid
- [ ] `Controls/Xxx/Xxx.ascx(.cs)` — formulario contenedor
- [ ] `Controls/Xxx/<Tab>.ascx(.cs)` — un archivo por tab
- [ ] `<SubModulo>/Xxxs.aspx(.cs)` — página listado
- [ ] `<SubModulo>/Xxx.aspx(.cs)` — página formulario

**Cierre**

- [ ] Permisos registrados en `SitioBase.Paginas` (`menu_<N>`)
- [ ] Todos los archivos en UTF-8 con BOM

---

## 🐛 Errores frecuentes (tabla de diagnóstico)

| Síntoma | Causa | Solución |
|---|---|---|
| Columnas duplicadas en el grid | Falta `if (!IsPostBack)` al agregar columnas | Envolver en `!IsPostBack` |
| `GetDataKeyValue` lanza excepción | Columna ausente en `DataKeyNames` | Agregarla al `MasterTableView` |
| El combo pierde la selección | Falta `if (!IsPostBack)` en `LoadControls` | Agregarlo |
| Desaparece el item "Seleccione..." | Falta `AppendDataBoundItems = true` | Agregarlo antes del `DataBind()` |
| El botón Guardar no hace nada | Falta `RegisterPostBackControl(btnGuardar)` | Agregarlo en `Page_PreRender` |
| Guarda sin validar | `ValidationGroup` distinto entre validators y botón | Unificar el nombre |
| El botón de la fila no dispara evento | Se creó en `ItemDataBound` | Crearlo en `ItemCreated` |
| El handler se ejecuta dos veces | `Command +=` suscrito en dos eventos | Suscribir solo en `ItemCreated` |
| "Procedure expects parameter @X" | Falta `= NULL` en la firma del SP | Agregarlo |
| El update borra campos | Se asignó `@PARAM` directo | Usar `ISNULL(@PARAM, columna)` |
| "Ya existe" al editar sin cambiar nada | Falta `AND ID <> @ID` en la validación | Excluir el propio registro |
| Se crea un registro nuevo en cada Guardar | Falta `IdUsuario = respuesta.codigo` tras el alta | Guardar el id devuelto |

---

## 🔗 Fuente

Los archivos de `00-Patrones-Originales/` son copia textual de:

```
C:\Desarrollo\TFS\DevOps\GrupoExpro-TFVC\FacilityGes\MD\Desarrollo\
C:\Desarrollo\TFS\DevOps\GrupoExpro-TFVC\FacilityGes\MD\BaseDatos\
```

Si el patrón cambia en FacilityGes, hay que volver a copiarlos y revisar si las guías siguen vigentes.

> Los archivos de `00-Patrones-Originales/` son copia **textual**, sin editar. Por eso `PATRON_SP.md` y `PATRON_GRID_EVENTS.md` enlazan a un `../../CLAUDE.md` que solo existe en el repositorio de FacilityGes. Es esperable: no hay que corregirlo.

---

## 📌 Diferencias entre FacilityGes y SIGMA

| | FacilityGes | SIGMA (nuestro) |
|---|---|---|
| Namespace Model | `Facilityges.Model` | `Sigma.Model` |
| Namespace Controller | `Facilityges.Controller` | `Sigma.Controller` |
| Base de datos | `FacilityGes` | `SIGMA` |
| Columnas de actualización | `_ACT` y `_ACTUALIZACION` (conviven) | **solo `_ACT`** |
| Ruta | `C:\Desarrollo\TFS\...\FacilityGes` | `C:\Capstone\SIGMA` |

Todo lo demás es idéntico.
