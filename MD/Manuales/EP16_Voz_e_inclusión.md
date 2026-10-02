# EP-16 · Voz e inclusión

> Permitir registrar información hablando, sin conexión y sin costo por uso.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Mis tareas | Mis tareas | Ejecutar tarea en terreno |
| Pautas de inspección | Pautas de inspección | Ejecutar checklist en terreno |
| Bitácora de planta | Bitácora de planta | Ver la bitacora de planta |
| Fallas | Fallas | Ver ordenes de trabajo |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ejecutar checklist en terreno**
- **Ejecutar tarea en terreno**
- **Ver la bitacora de planta**
- **Ver ordenes de trabajo**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-160` — Dictar texto en cualquier campo


## 4. Paso a paso


### HU-160 · Dictar texto en cualquier campo

**Para qué.** Como técnico de mantenimiento con las manos ocupadas, dictar en lugar de escribir, registrar lo que observo sin sacarme los guantes.

*App · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Dictar | Botón de mantener pulsado con indicador de nivel de audio | No | Requiere permiso de micrófono |
| Texto reconocido | Texto multilinea editable | Sí | El usuario puede corregirlo antes de confirmar |

**Cómo saber que quedó bien:**

1. **Dictado sin conexión** — Dado que estoy sin conexión Cuando mantengo pulsado el botón de dictado y hablo Entonces la transcripción aparece en pantalla usando el motor del teléfono Y no se realiza ninguna llamada a un servicio externo
2. **Confirmación antes de guardar** — Cuando término de dictar Entonces se muestra el texto transcrito para revisarlo y corregirlo Y puedo repetir el dictado o editar el texto manualmente
3. **El audio no se conserva** — Cuando confirmo la transcripción Entonces el audio se descarta del dispositivo Y solo se conserva el texto
4. **Registro del modo de ingreso** — Cuando un texto se ingresa por dictado Entonces queda registrado que el ingreso fue por voz Y esa marca se conserva junto al dato


### HU-161 · Escuchar el contenido en voz alta

**Para qué.** Como técnico de mantenimiento, que el teléfono me lea las preguntas y las instrucciones, poder avanzar sin mirar la pantalla mientras trabajo con las manos.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Lectura de un ítem de checklist** — Cuando activo la lectura en voz alta Entonces el teléfono lee la pregunta y sus opciones Y la lectura funciona sin conexión
2. **Texto alternativo para la lectura** — Dado un ítem con un texto alternativo definido para voz Entonces se lee ese texto en lugar del texto escrito Y eso permite corregir abreviaturas y unidades que se leen mal
3. **Control de la lectura** — Cuando la lectura está en curso Entonces puedo pausarla, repetirla o detenerla


### HU-162 · Configurar las opciones de accesibilidad

**Para qué.** Como usuario de SIGMA, ajustar tamaño de texto, contraste, voz y sonidos, poder usar el sistema según mis condiciones de trabajo y mis capacidades.

*App y Web · Sprint 5*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Tamaño del texto | Control deslizante: Normal / Grande / Muy grande | No | Normal por defecto |
| Alto contraste | Interruptor | No | Desactivado por defecto |
| Lectura en voz alta | Interruptor | No | Desactivado por defecto |
| Velocidad de la voz | Control deslizante | No | Velocidad normal por defecto |
| Alertas sonoras | Interruptor | No | Activado por defecto |
| Volumen de las alertas | Control deslizante | No | 60 por ciento por defecto |

**Cómo saber que quedó bien:**

1. **Ajuste del tamaño del texto** — Cuando aumento el tamaño del texto Entonces todas las pantallas lo respetan sin cortar contenido
2. **Modo de alto contraste** — Cuando activo el alto contraste Entonces la interfaz aplica una paleta de mayor contraste
3. **Movimiento reducido** — Cuando el sistema operativo solicita movimiento reducido Entonces las animaciones se reemplazan por transiciones simples Y ningún elemento presenta movimiento continuo
4. **Preferencias de sonido** — Cuando ajusto el volumen o silencio las alertas sonoras Entonces la preferencia se conserva entre sesiones Y toda alerta sonora conserva su equivalente visual


## 5. Lo que el sistema no deja hacer

No hay reglas de rechazo declaradas en los criterios de este módulo.


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
