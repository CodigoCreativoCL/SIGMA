# EP-20 · Importación y carga inicial de datos

> Poner en marcha un cliente nuevo con la información que ya tiene en planillas.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Carga masiva de repuestos *(no aparece en el menú; se abre desde otra pantalla)* | Inventario › Carga masiva de repuestos | Crear y editar repuestos |
| Carga masiva de activos *(no aparece en el menú; se abre desde otra pantalla)* | Control de activos › Carga masiva de activos | Crear y editar activos |
| Carga masiva de planes *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Carga masiva de planes | Ver planes de mantenimiento |
| Carga masiva de usuarios *(no aparece en el menú; se abre desde otra pantalla)* | Cliente › Usuarios › Carga masiva de usuarios | Ver los usuarios del cliente |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Crear y editar activos**
- **Crear y editar repuestos**
- **Ver los usuarios del cliente**
- **Ver planes de mantenimiento**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-080` — Crear un plan de mantenimiento
- `HU-200` — Importar activos desde una planilla
- `HU-201` — Resolver las celdas ambiguas de una importación


## 4. Paso a paso


### HU-200 · Importar activos desde una planilla

**Para qué.** Como administrador del cliente, cargar el maestro de activos desde la planilla que ya tengo, poner en marcha el sistema sin digitar cientos de equipos.

*Web · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Archivo | Carga de archivo | Sí | XLSX o CSV, máximo 20 MB |
| Tipo de importación | Lista desplegable: Activos / Componentes / Repuestos / Plan anual / Órdenes históricas | Sí | Del catálogo de tipos de importación |
| Planta de destino | Lista desplegable | Sí | Plantas del cliente |
| Actualizar registros existentes | Interruptor | No | Desactivado por defecto |

**Cómo saber que quedó bien:**

1. **Carga de la planilla** — Cuando cargo una planilla de activos Entonces se muestra la vista previa con las filas leídas, válidas, ambiguas y rechazadas Y ningún registro se crea hasta que confirmo
2. **Planilla duplicada** — Cuando cargo una planilla ya procesada anteriormente Entonces se advierte que ese archivo ya fue cargado y en que fecha
3. **Confirmación de la carga** — Cuando confirmo la importación Entonces se crean los registros válidos Y se informa cuántos se crearon y cuántos quedaron pendientes de resolver
4. **Descarga de la plantilla** — Cuando descargo la plantilla de importación Entonces obtengo una planilla con las columnas esperadas y un ejemplo por columna


### HU-201 · Resolver las celdas ambiguas de una importación

**Para qué.** Como administrador del cliente, corregir solo lo que el sistema no pudo interpretar, no volver a digitar la fila completa por un dato mal escrito.

*Web · Sprint 6*

**Cómo saber que quedó bien:**

1. **Detalle por celda** — Cuando reviso una importación Entonces veo cada celda ambigua con su valor original, su interpretación propuesta y el motivo Y las celdas correctas de esa misma fila se conservan
2. **Corrección de una celda** — Cuando corrijo el valor de una celda ambigua Entonces la fila queda válida sin necesidad de reingresar el resto de los datos
3. **Aplicar una corrección a todas las coincidencias** — Cuando corrijo un valor que se repite en varias filas Entonces se ofrece aplicar la misma corrección a todas sus ocurrencias
4. **Rechazo de una fila** — Cuando rechazo una fila Entonces queda registrada como rechazada con su motivo Y no se crea ningún registro a partir de ella El detalle se guarda por celda y no por fila. Una planilla real trae el equipo correcto y la frecuencia escrita de forma ambigua en la misma línea; rechazar la fila completa obligaría a redigitar lo que venia bien.


### HU-202 · Importar el plan anual desde una planilla

**Para qué.** Como planificador, cargar el plan anual de mantenimiento desde la planilla que usa la planta, trasladar al sistema el trabajo de planificación ya realizado.

*Web · Sprint 6*

**Cómo saber que quedó bien:**

1. **Interpretación de la estructura** — Cuando cargo la planilla del plan anual Entonces se identifican los equipos, los hitos y las actividades Y se muestra la estructura interpretada para revisarla antes de confirmar
2. **Frecuencias ambiguas** — Cuando una frecuencia no puede interpretarse de forma única Entonces se marca como ambigua y se solicita elegir la interpretación correcta
3. **Resultado de la importación** — Cuando confirmo Entonces se crea el plan con su versión en borrador, sus hitos y sus actividades Y el plan queda listo para revisarse y publicarse


### HU-203 · Consultar el historial de importaciones

**Para qué.** Como administrador del cliente, revisar qué cargas se hicieron y con qué resultado, poder rastrear de dónde salió un registro cuando algo no cuadra.

*Web · Sprint 6*

**Cómo saber que quedó bien:**

1. **Historial de cargas** — Cuando consulto el historial Entonces veo cada importación con su archivo, fecha, usuario, tipo y resultado
2. **Detalle de una carga** — Cuando abro una importación Entonces veo las filas procesadas y los registros que se crearon a partir de ella


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-200 · Carga de la planilla** — Cuando cargo una planilla de activos Entonces se muestra la vista previa con las filas leídas, válidas, ambiguas y rechazadas Y ningún registro se crea hasta que confirmo
- **HU-200 · Planilla duplicada** — Cuando cargo una planilla ya procesada anteriormente Entonces se advierte que ese archivo ya fue cargado y en que fecha
- **HU-201 · Rechazo de una fila** — Cuando rechazo una fila Entonces queda registrada como rechazada con su motivo Y no se crea ningún registro a partir de ella El detalle se guarda por celda y no por fila. Una planilla real trae el equipo correcto y la frecuencia escrita de forma ambigua en la misma línea; rechazar la fila completa obligaría a redigitar lo que venia bien.
- **HU-202 · Frecuencias ambiguas** — Cuando una frecuencia no puede interpretarse de forma única Entonces se marca como ambigua y se solicita elegir la interpretación correcta


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
