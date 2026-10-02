# EP-08 · Motor de programación

> Definir una sola vez cómo se repite el trabajo y qué planes, tareas y checklists lo reutilicen.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Programaciones | Centro de Mantenimiento › Programaciones | Ver programaciones |
| Programación (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Programación (detalle) | Ver programaciones |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver programaciones**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-041` — Administrar variables de condición
- `HU-042` — Configurar el medidor de un activo
- `HU-071` — Crear una programación de calendario
- `HU-073` — Crear una programación por medidor


## 4. Paso a paso


### HU-073 · Crear una programación por medidor

**Para qué.** Como planificador, programar un trabajo cada cierta cantidad de horas o ciclos, que el mantenimiento se dispare por uso real y no por calendario.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Nombre de la programación | Texto | Sí | Máximo 200 caracteres |
| Cada | Numérico decimal | Sí | Mayor que cero. Ejemplo: 500 |
| Unidad | Lista desplegable | Sí | Horas o ciclos |
| Avisar con anticipación de | Numérico decimal | No | Menor que la cantidad del intervalo |
| Contar desde la lectura | Numérico decimal | No | Vacío usa la lectura actual del medidor |

**Cómo saber que quedó bien:**

1. **Disparo por horas** — Dado un plan cada 500 horas y un horómetro en 8.200 al cierre del hito anterior Cuando se registra una lectura de 8.700 horas Entonces se genera la ocurrencia correspondiente
2. **Aviso anticipado** — Dado un plan cada 500 horas con aviso 50 horas antes Cuando se registra una lectura de 8.655 horas Entonces se genera una alerta de medidor próximo a mantenimiento Y la alerta no genera una orden de trabajo por si sola
3. **Un horómetro por equipo** — Dado un plan aplicado a cuatro blowers identicos Entonces cada equipo dispara según su propio horómetro Y no se requiere crear cuatro planes


### HU-076 · Generar las ocurrencias de forma automática

**Para qué.** Como planificador, que el sistema genere solo las ocurrencias futuras, no tener que crear a mano cada mantención del año.

*Servidor · Sprint 3*

**Cómo saber que quedó bien:**

1. **Generación por horizonte** — Cuando el proceso automático se ejecuta Entonces genera las ocurrencias de los próximos 90 días Y avanza la marca de agua hasta la fecha generada
2. **Ejecución repetida** — Cuando el proceso automático se ejecuta dos veces seguidas Entonces la segunda ejecución no genera ocurrencias duplicadas
3. **Generación manual** — Cuando solicito generar ocurrencias de una programación específica Entonces se generan de inmediato sin esperar al proceso automático
4. **Programación deshabilitada** — Dado que deshabilito una programación Entonces deja de generar ocurrencias nuevas Y las ya generadas se conservan La marca de agua es lo que hace idempotente la generación. Sin ella, dos ejecuciones del proceso crean la misma ocurrencia dos veces y el técnico ve trabajo duplicado.


### HU-071 · Crear una programación de calendario

**Para qué.** Como planificador, programar un trabajo que se repite según el calendario, cubrir rutinas diarias, semanales, mensuales y anuales.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Nombre de la programación | Texto | Sí | Máximo 200 caracteres |
| Frecuencia | Lista desplegable: Diaria / Semanal / Mensual / Anual | Sí | Del catálogo de tipos de frecuencia |
| Cada | Numérico entero | Sí | Mayor o igual a 1. Ejemplo: cada 2 semanas |
| Días de la semana | Casillas múltiples | No | Al menos un día |
| Día del mes | Numérico entero | No | Entre 1 y 31, o -1 para el último día |
| Semana del mes | Lista desplegable: Primera a Quinta / Última | No | Alternativa al día del mes |
| Mes | Lista desplegable | No | Entre 1 y 12 |
| Hora local | Selector de hora | Sí | Formato de 24 horas |
| Vigente desde | Selector de fecha | Sí | Sin restricción |
| Vigente hasta | Selector de fecha | No | Vacío indica vigencia indefinida |

**Cómo saber que quedó bien:**

1. **Recurrencia semanal** — Cuando defino repetición semanal los martes y jueves Entonces se generan ocurrencias en cada martes y jueves del periodo de vigencia
2. **Último día del mes** — Cuando defino repetición mensual el último día del mes Entonces la ocurrencia de febrero cae el 28 o el 29 según corresponda Y la de enero cae el 31
3. **Ordinal de semana** — Cuando defino el último viernes de cada mes Entonces la ocurrencia cae en el último viernes real de cada mes


### HU-075 · Definir tolerancias y exclusiones de una programación

**Para qué.** Como planificador, indicar cuánto se puede adelantar o atrasar un trabajo y que días no aplica, que el indicador de cumplimiento refleje la realidad de la planta.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Se puede adelantar (días) | Numérico entero | Sí | Mayor o igual a cero. Cero por defecto |
| Se puede atrasar (días) | Numérico entero | Sí | Mayor o igual a cero. Cero por defecto |
| Generar automáticamente | Interruptor | Sí | Activado por defecto |
| Periodos excluidos | Grilla de rangos de fecha | No | La fecha de término debe ser posterior al inicio |
| Excluir feriados | Interruptor | No | Desactivado por defecto |

**Cómo saber que quedó bien:**

1. **Ventana de ejecución** — Cuando defino una tolerancia de 2 días antes y 3 días después Entonces una ejecución dentro de esa ventana se considera cumplida en fecha
2. **Exclusión por feriado** — Cuando excluyo los feriados Entonces una ocurrencia que caería en feriado se desplaza al siguiente día hábil Y la fecha original queda registrada
3. **Exclusión por parada de planta** — Cuando defino un periodo de exclusión Entonces no se generan ocurrencias dentro de ese periodo


### HU-070 · Crear una programación de fecha única

**Para qué.** Como planificador, programar un trabajo para una o varias fechas puntuales, cubrir el caso de una intervención planificada que no se repite periódicamente.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Nombre de la programación | Texto | Sí | Máximo 200 caracteres |
| Fechas | Grilla de fechas con hora | Sí | Al menos una fecha |
| Zona horaria | Lista desplegable | No | Vacío hereda la de la planta |

**Cómo saber que quedó bien:**

1. **Fechas puntuales** — Cuando defino cuatro fechas específicas Entonces se generan cuatro ocurrencias independientes Y cada una tiene su propia ejecución, estado y evidencias
2. **Fecha en el pasado** — Cuando ingreso una fecha anterior a hoy Entonces se advierte y se permite continuar para registrar trabajo ya realizado


### HU-072 · Crear una programación por intervalo de tiempo

**Para qué.** Como planificador, programar un trabajo cada cierta cantidad de días desde la última ejecución, cubrir rutinas que dependen de cuando se hizo la anterior y no del calendario.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Nombre de la programación | Texto | Sí | Máximo 200 caracteres |
| Cada | Numérico entero | Sí | Mayor que cero |
| Unidad | Lista desplegable: Días / Semanas / Meses | Sí | Del catálogo de unidades de tiempo |
| Contado desde | Botones de opción: Última ejecución / Fecha programada | Sí | Última ejecución por defecto |

**Cómo saber que quedó bien:**

1. **Intervalo desde la última ejecución** — Cuando defino un intervalo de 90 días desde la última ejecución Y la ejecución anterior ocurrió el día 10 Entonces la siguiente ocurrencia se programa 90 días después del día 10
2. **Intervalo desde la fecha programada** — Cuando defino que el intervalo se cuenta desde la fecha programada Entonces un atraso en la ejecución no desplaza las ocurrencias siguientes


### HU-074 · Crear una programación por condición

**Para qué.** Como planificador, programar un trabajo que se dispara cuando una variable cruza un umbral, reaccionar al estado real del equipo y no a una frecuencia fija.

*Web · Sprint 3*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Nombre de la programación | Texto | Sí | Máximo 200 caracteres |
| Variable | Lista desplegable | Sí | Variables del activo |
| Operador | Lista desplegable: Mayor que / Menor que / Entre / Igual a | Sí | Del catálogo de operadores de comparación |
| Umbral | Numérico decimal | Sí | Numérico |
| Umbral superior | Numérico decimal | No | Mayor que el umbral inferior |
| Duración mínima (minutos) | Numérico entero | No | Evita el disparo por un valor aislado |
| Con varias condiciones | Lista desplegable: Una / Todas / Mínimo N | Sí | Del catálogo de políticas de cumplimiento |

**Cómo saber que quedó bien:**

1. **Disparo por umbral** — Cuando defino que la temperatura mayor a 80 grados genera una ocurrencia Y se registra una medición de 84 grados Entonces se genera la ocurrencia
2. **Duración mínima** — Dado que definí una duración mínima de 30 minutos sobre el umbral Cuando una medición aislada supera el umbral y la siguiente vuelve a la normalidad Entonces no se genera la ocurrencia
3. **Varias condiciones** — Cuando defino dos condiciones y la política Todas Entonces la ocurrencia se genera solo si ambas se cumplen simultáneamente


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-070 · Fecha en el pasado** — Cuando ingreso una fecha anterior a hoy Entonces se advierte y se permite continuar para registrar trabajo ya realizado


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
