# EP-13 · Bitácora de turno

> Conservar lo que el turno observó, escrito por quien lo vio y en el momento en que lo vio.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Bitácora de planta | Bitácora de planta | Ver la bitacora de planta |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver la bitacora de planta**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-121` — Consultar mi bandeja de trabajo
- `HU-130` — Registrar una entrada de bitácora


## 4. Paso a paso


### HU-130 · Registrar una entrada de bitácora

**Para qué.** Como técnico de mantenimiento, anotar lo que observe durante el turno, que quede constancia de lo que vi aunque en ese momento no parezca importante.

*App y Web · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Tipo de entrada | Lista desplegable | Sí | Del catálogo de tipos de bitácora |
| Planta | Lista desplegable | Sí | Plantas del usuario |
| Área | Lista desplegable dependiente | No | Áreas de la planta |
| Activo | Lista desplegable con buscador y escaneo QR | No | Activos de la planta |
| Orden de trabajo | Lista desplegable con buscador | No | Órdenes de la planta |
| Título | Texto | No | Máximo 200 caracteres |
| Texto de la entrada | Texto multilinea con dictado por voz | Sí | Mínimo 10 caracteres |
| Fecha y hora del evento | Selector de fecha y hora | Sí | Por defecto el momento actual. No puede ser futura |
| Turno | Texto | No | Máximo 50 caracteres |
| Requiere atención | Interruptor | No | Desactivado por defecto |
| Severidad | Lista desplegable | No | Del catálogo de severidades |
| Evidencias | Cámara, hasta 5 imágenes | No | JPG, máximo 4 MB por imagen |

**Cómo saber que quedó bien:**

1. **Registro de la entrada** — Cuando registro una entrada indicando tipo y texto Entonces queda con mi nombre, la fecha del evento y el turno Y no puede editarse ni eliminarse después
2. **Registro por voz** — Cuando dicto la entrada Entonces el texto transcrito se muestra para confirmar antes de guardar Y queda registrado que el ingreso fue por voz
3. **Marca de atención** — Cuando marco la entrada como que requiere atención Entonces aparece en la bandeja del supervisor Y puede generar una alerta según el tipo de bitácora
4. **Registro sin conexión** — Dado que estoy sin señal Entonces la entrada se guarda localmente con la fecha real del evento Y se sincroniza al recuperar conexión


### HU-131 · Comentar y rectificar una entrada de bitácora

**Para qué.** Como usuario de mantenimiento, comentar una entrada o corregirla sin borrar lo escrito, que la corrección sea visible y no un reemplazo silencioso.

*Web y App · Sprint 5*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Comentario | Texto multilinea con dictado | No | Mínimo 3 caracteres |
| Texto rectificado | Texto multilinea | No | Mínimo 10 caracteres |
| Motivo de la rectificación | Texto multilinea | No | Mínimo 10 caracteres |

**Cómo saber que quedó bien:**

1. **Comentario** — Cuando comento una entrada Entonces el comentario queda con mi nombre y fecha Y no puede editarse ni eliminarse
2. **Rectificación** — Cuando rectifico una entrada indicando el texto correcto y el motivo Entonces la entrada original se conserva Y la interfaz muestra el texto original tachado con la rectificación junto a él
3. **Motivo obligatorio** — Cuando intento rectificar sin indicar el motivo Entonces la operación es rechazada


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-130 · Registro de la entrada** — Cuando registro una entrada indicando tipo y texto Entonces queda con mi nombre, la fecha del evento y el turno Y no puede editarse ni eliminarse después
- **HU-131 · Comentario** — Cuando comento una entrada Entonces el comentario queda con mi nombre y fecha Y no puede editarse ni eliminarse
- **HU-131 · Motivo obligatorio** — Cuando intento rectificar sin indicar el motivo Entonces la operación es rechazada


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
