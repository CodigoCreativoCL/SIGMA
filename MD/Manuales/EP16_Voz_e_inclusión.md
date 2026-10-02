# EP-16 - Voz e inclusión

> Permitir registrar información hablando, sin conexión y sin costo por uso.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Mis tareas | Mis tareas | - | Ejecutar tarea en terreno |
| Pautas de inspección | Pautas de inspección | - | Ejecutar checklist en terreno |
| Bitácora de planta | Bitácora de planta | - | Ver la bitacora de planta |
| Fallas | Fallas | - | Ver ordenes de trabajo |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ejecutar checklist en terreno**
- **Ejecutar tarea en terreno**
- **Ver la bitacora de planta**
- **Ver ordenes de trabajo**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-160` - Dictar texto en cualquier campo

## 4. Paso a paso

### HU-160 - Dictar texto en cualquier campo

**Para que.** Como técnico de mantenimiento con las manos ocupadas, dictar en lugar de escribir, registrar lo que observo sin sacarme los guantes.

*App - Sprint 6*

**Donde se hace:** No es una pantalla: el microfono aparece en los campos de texto de toda la aplicacion.

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Dictar | Botón de mantener pulsado con indicador de nivel de audio | No | Requiere permiso de micrófono |
| Texto reconocido | Texto multilinea editable | Si | El usuario puede corregirlo antes de confirmar |

**Como saber que quedo bien:**

1. **Dictado sin conexión** - Dado que estoy sin conexión Cuando mantengo pulsado el botón de dictado y hablo Entonces la transcripción aparece en pantalla usando el motor del teléfono Y no se realiza ninguna llamada a un servicio externo
2. **Confirmación antes de guardar** - Cuando término de dictar Entonces se muestra el texto transcrito para revisarlo y corregirlo Y puedo repetir el dictado o editar el texto manualmente
3. **El audio no se conserva** - Cuando confirmo la transcripción Entonces el audio se descarta del dispositivo Y solo se conserva el texto
4. **Registro del modo de ingreso** - Cuando un texto se ingresa por dictado Entonces queda registrado que el ingreso fue por voz Y esa marca se conserva junto al dato


### HU-161 - Escuchar el contenido en voz alta

**Para que.** Como técnico de mantenimiento, que el teléfono me lea las preguntas y las instrucciones, poder avanzar sin mirar la pantalla mientras trabajo con las manos.

*App - Sprint 6*

**Donde se hace:** No es una pantalla: la lectura en voz alta se activa desde las opciones de accesibilidad.

**Como saber que quedo bien:**

1. **Lectura de un ítem de checklist** - Cuando activo la lectura en voz alta Entonces el teléfono lee la pregunta y sus opciones Y la lectura funciona sin conexión
2. **Texto alternativo para la lectura** - Dado un ítem con un texto alternativo definido para voz Entonces se lee ese texto en lugar del texto escrito Y eso permite corregir abreviaturas y unidades que se leen mal
3. **Control de la lectura** - Cuando la lectura está en curso Entonces puedo pausarla, repetirla o detenerla


### HU-162 - Configurar las opciones de accesibilidad

**Para que.** Como usuario de SIGMA, ajustar tamaño de texto, contraste, voz y sonidos, poder usar el sistema según mis condiciones de trabajo y mis capacidades.

*App y Web - Sprint 5*

**Donde se hace:** Mi perfil

**Como se llega:** aplicacion movil

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tamaño del texto | Control deslizante: Normal / Grande / Muy grande | No | Normal por defecto |
| Alto contraste | Interruptor | No | Desactivado por defecto |
| Lectura en voz alta | Interruptor | No | Desactivado por defecto |
| Velocidad de la voz | Control deslizante | No | Velocidad normal por defecto |
| Alertas sonoras | Interruptor | No | Activado por defecto |
| Volumen de las alertas | Control deslizante | No | 60 por ciento por defecto |

**Como saber que quedo bien:**

1. **Ajuste del tamaño del texto** - Cuando aumento el tamaño del texto Entonces todas las pantallas lo respetan sin cortar contenido
2. **Modo de alto contraste** - Cuando activo el alto contraste Entonces la interfaz aplica una paleta de mayor contraste
3. **Movimiento reducido** - Cuando el sistema operativo solicita movimiento reducido Entonces las animaciones se reemplazan por transiciones simples Y ningún elemento presenta movimiento continuo
4. **Preferencias de sonido** - Cuando ajusto el volumen o silencio las alertas sonoras Entonces la preferencia se conserva entre sesiones Y toda alerta sonora conserva su equivalente visual


## 5. Lo que el sistema no deja hacer

No hay reglas de rechazo declaradas en los criterios de este modulo.

## 6. Si algo no funciona

| Sintoma | Causa mas probable |
|---|---|
| No aparece la opcion en el menu | Falta el permiso de la seccion 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el boton no hace nada | Falta el permiso de la funcion: ver no es lo mismo que crear y editar |
| Dice que no se puede guardar, sin mas detalle | Alguna regla de la seccion 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacios | Falta construir lo de la seccion 3 |
| Estoy en la pantalla correcta y no veo el formulario | Falta pulsar la pestana que indica cada operacion en la seccion 4 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx`, la tabla `Menus` y las pestanas declaradas en los .aspx. Para actualizarlo: `python _scratch/gen_manuales.py`.*
