# EP-10 - Checklist dinámico

> Que la planta diseñe sus propias pautas de inspección y que lo registrado sirva para algo más que archivar.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Pautas de inspección | Centro de Mantenimiento > Inspección > Pautas de inspección | Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos | Ver las pautas de inspeccion (plantillas de checklist) |
| Hallazgos de inspección | Centro de Mantenimiento > Inspección > Hallazgos de inspección | - | Ver hallazgos de checklist |
| Programación de pautas *(se abre desde otra pantalla)* | Centro de Mantenimiento > Programación de pautas | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Umbrales de ítems *(se abre desde otra pantalla)* | Centro de Mantenimiento > Umbrales de ítems | - | Ver los umbrales y acciones de los items de las pautas |
| Dependencias de ítems *(se abre desde otra pantalla)* | Centro de Mantenimiento > Dependencias de ítems | - | Ver las dependencias entre items de las pautas |
| Historial de ejecuciones *(se abre desde otra pantalla)* | Centro de Mantenimiento > Historial de ejecuciones | - | Ver el historial de ejecuciones de las pautas de inspeccion |
| Pauta de inspección (listado antiguo) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Pauta de inspección (listado antiguo) | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Pauta de inspección (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Pauta de inspección (detalle) | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Pauta de inspección (vista) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Pauta de inspección (vista) | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Versiones de la pauta *(se abre desde otra pantalla)* | Centro de Mantenimiento > Versiones de la pauta | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Programación de pauta (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Programación de pauta (detalle) | - | Ver las pautas de inspeccion (plantillas de checklist) |
| Validación de ítem (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Validación de ítem (detalle) | - | Ver los umbrales y acciones de los items de las pautas |
| Dependencia de ítem (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Dependencia de ítem (detalle) | - | Ver las dependencias entre items de las pautas |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver el historial de ejecuciones de las pautas de inspeccion**
- **Ver hallazgos de checklist**
- **Ver las dependencias entre items de las pautas**
- **Ver las pautas de inspeccion (plantillas de checklist)**
- **Ver los umbrales y acciones de los items de las pautas**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-041` - Administrar variables de condición
- [ ] `HU-071` - Crear una programación de calendario
- [ ] `HU-090` - Diseñar una plantilla de checklist
- [ ] `HU-091` - Definir los umbrales y las acciones de un ítem
- [ ] `HU-093` - Publicar una versión de checklist
- [ ] `HU-094` - Programar un checklist recurrente
- [ ] `HU-095` - Ejecutar un checklist en terreno

## 4. Paso a paso

### HU-095 - Ejecutar un checklist en terreno

**Para que.** Como técnico de mantenimiento, completar la pauta de inspección desde el teléfono, registrar lo que veo en el momento en que lo veo.

*App - Sprint 6*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Activo | Solo lectura, proviene de la ocurrencia o del código QR | No | No editable |
| Respuesta Sí-No | Dos botones amplios diferenciados por color | No | Una única selección |
| Respuesta numérica | Teclado numérico ampliado con botón de dictado | No | Validada contra los umbrales del ítem |
| Respuesta de texto | Texto multilinea con dictado por voz | No | Largo mínimo y máximo del ítem |
| Respuesta de lista | Lista de opciones táctiles | No | Según la definición del ítem |
| Respuesta de fecha | Selector de fecha | No | Sin restricción |
| Fotografía | Cámara, hasta 5 imágenes | No | JPG, máximo 4 MB por imagen |
| Comentario | Texto multilinea con dictado | No | Máximo 1000 caracteres |
| No aplica | Casilla de verificación | No | Exige comentario cuando se marca |

**Como saber que quedo bien:**

1. **Ejecución completa** - Cuando respondo todos los ítems obligatorios y finalizo Entonces la ejecución queda registrada con su fecha de inicio y de término Y se calcula la cantidad de ítems respondidos y no conformes
2. **Ítem obligatorio sin responder** - Cuando intento finalizar con un ítem obligatorio sin responder Entonces se indica cuál falta y no se permite finalizar
3. **Valor fuera de rango** - Dado un ítem con umbral crítico en 80 y fotografía obligatoria fuera de rango Cuando ingreso 84 Entonces el campo se marca en rojo con el mensaje configurado Y no puedo avanzar sin adjuntar una fotografía
4. **Unidad distinta a la esperada** - Dado un ítem que espera bar y registro el valor en PSI Entonces se guarda el valor y la unidad ingresados Y la comparación contra el umbral se realiza sobre el valor convertido Y la pantalla sigue mostrando el valor tal como lo escribí
5. **Ejecución sin conexión** - Dado que estoy sin señal Cuando completo el checklist entero Entonces queda guardado en el dispositivo Y los umbrales se evaluan localmente con la definición sincronizada Y al recuperar señal se sincroniza y el servidor revalida la severidad


### HU-090 - Diseñar una plantilla de checklist

**Para que.** Como planificador, construir la pauta de inspección con mis propias preguntas, que el checklist refleje lo que esta planta necesita revisar.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Ejemplo: Ronda diaria sala de blowers |
| Aplica al tipo de activo | Lista desplegable | No | Del árbol de tipos |
| Nombre de la sección | Texto | No | Máximo 200 caracteres |
| Código del ítem | Texto | No | Único dentro de la versión |
| Pregunta | Texto | No | Máximo 500 caracteres |
| Texto de ayuda | Texto | No | Máximo 500 caracteres |
| Tipo de respuesta | Lista desplegable: Sí-No / Numérico / Texto / Lista / Fecha / Fotografía | No | Del catálogo de tipos de ítem |
| Obligatorio | Interruptor | No | Activado por defecto |
| Exige fotografía | Interruptor | No | Desactivado por defecto |
| Unidad esperada | Lista desplegable | No | Del catálogo de unidades |
| Alimenta la serie del activo | Interruptor | No | Desactivado por defecto |
| Variable del activo | Lista desplegable | No | Variables del activo |
| Opciones de la lista | Grilla: código, texto, es conforme, severidad | No | Al menos dos opciones |

**Como saber que quedo bien:**

1. **Alta de plantilla** - Cuando creo una plantilla con código y nombre Entonces se crea su versión 1 en estado borrador Y su código es único dentro del cliente
2. **Secciones** - Cuando agrupo los ítems en secciones Entonces en la aplicación móvil aparecen agrupados y colapsables
3. **Tipos de respuesta** - Cuando defino un ítem de tipo lista Entonces debo definir al menos dos opciones Y cada opción indica si representa una condición conforme
4. **Reordenar** - Cuando reordeno los ítems arrastrándolos Entonces el orden se refleja en la ejecución


### HU-096 - Revisar los hallazgos generados por un checklist

**Para que.** Como planificador, decidir qué hacer con lo que encontró la inspección, que un hallazgo termine en una acción y no en un archivo que nadie abre.

*Web - Sprint 4*

**Donde se hace:** Pautas de inspección > pestana **Hallazgos**

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Motivo del descarte | Texto multilinea | No | Mínimo 10 caracteres |

**Como saber que quedo bien:**

1. **Bandeja de hallazgos** - Cuando abro la bandeja Entonces veo los hallazgos pendientes con su activo, severidad, fotografía y días de espera Y están ordenados por severidad y antigüedad
2. **Convertir en orden** - Cuando genero una orden desde un hallazgo Entonces la orden se crea con origen hallazgo de checklist Y el hallazgo queda enlazado a esa orden y sale de la bandeja
3. **Descartar con motivo** - Cuando descarto un hallazgo Entonces se exige un motivo de al menos 10 caracteres Y queda registrado quién lo descartó y cuándo


### HU-091 - Definir los umbrales y las acciones de un ítem

**Para que.** Como planificador, establecer que valores son normales y que ocurre cuando no lo son, que una lectura fuera de rango produzca una consecuencia y no solo un número anotado.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Mínimo aceptable | Numérico decimal | No | Menor o igual al máximo |
| Umbral de advertencia | Numérico decimal | No | Numérico |
| Umbral crítico | Numérico decimal | No | Numérico |
| Máximo aceptable | Numérico decimal | No | Mayor o igual al mínimo |
| Largo mínimo | Numérico entero | No | Solo en ítems de texto |
| Largo máximo | Numérico entero | No | Mayor o igual al largo mínimo |
| Pedir comentario fuera de rango | Interruptor | No | Desactivado por defecto |
| Pedir fotografía fuera de rango | Interruptor | No | Desactivado por defecto |
| Generar alerta | Interruptor | No | Desactivado por defecto |
| Generar hallazgo | Interruptor | No | Desactivado por defecto |
| Mensaje al técnico | Texto | No | Se muestra cuando el valor sale de rango |

**Como saber que quedo bien:**

1. **Umbrales y severidad** - Dado un ítem con mínimo 60, advertencia 70, crítico 80 y máximo 90 Cuando el técnico ingresa 84 Entonces la respuesta se clasifica como crítica
2. **Comentario obligatorio** - Dado que el ítem exige comentario cuando el valor sale de rango Cuando el valor sale de rango Entonces no se puede continuar sin ingresar un comentario
3. **Fotografía obligatoria** - Dado que el ítem exige fotografía cuando el valor sale de rango Cuando el valor sale de rango Entonces no se puede continuar sin adjuntar una fotografía
4. **Genera hallazgo** - Dado que el ítem genera hallazgo Cuando la respuesta resulta crítica Entonces se crea un hallazgo pendiente de revisión Y el hallazgo no crea una orden de trabajo por sí solo


### HU-093 - Publicar una versión de checklist

**Para que.** Como planificador, publicar la plantilla para que se pueda ejecutar, que las ejecuciones históricas conserven las preguntas que realmente se aplicaron.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Como saber que quedo bien:**

1. **Publicación** - Cuando publico una versión en borrador Entonces la versión publicada anterior pasa a retirada Y queda registrado quién publicó y en qué fecha
2. **Plantilla sin ítems** - Cuando intento publicar una versión sin ítems Entonces la operación es rechazada
3. **Reconstrucción histórica** - Dado un checklist ejecutado hace un año con la versión 1 Cuando lo consulto hoy con la versión 3 publicada Entonces veo las preguntas, el orden, las unidades y los umbrales de la versión 1


### HU-094 - Programar un checklist recurrente

**Para que.** Como planificador, programar la ejecución periódica de un checklist, que la ronda diaria aparezca sola en la bandeja del técnico.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Plantilla de checklist | Lista desplegable de versiones publicadas | Si | Solo versiones publicadas |
| Recurrencia | Abre el asistente de programación | Si | Obligatoria |
| Activo | Lista desplegable con buscador | No | Activos del cliente |
| Área | Lista desplegable | No | Áreas del cliente |
| Responsable | Lista desplegable de usuarios | No | Usuarios habilitados |
| Grupo de trabajo | Lista desplegable | No | Grupos del cliente |

**Como saber que quedo bien:**

1. **Programación sobre un activo** - Cuando programo un checklist diario sobre un activo Entonces cada día se genera una ocurrencia asignada al responsable indicado
2. **Programación sobre un área** - Cuando programo un checklist sobre un área en lugar de un activo Entonces la ocurrencia se genera para el área
3. **Sin objetivo** - Cuando intento programar sin indicar activo ni área Entonces la operación es rechazada


### HU-092 - Definir dependencias entre ítems

**Para que.** Como planificador, mostrar u ocultar preguntas según lo que se respondió antes, que el técnico solo conteste lo que corresponde a la situación real.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Si la respuesta de | Lista desplegable de ítems anteriores | Si | Solo ítems que preceden al actual |
| Es | Lista desplegable: Igual a / Distinto de / Mayor que / Menor que | Si | Del catálogo de operadores |
| El valor | Texto o lista según el tipo del ítem condicionante | Si | Coherente con el tipo del ítem |
| Entonces | Lista desplegable: Mostrar / Ocultar / Requerir / Bloquear | Si | Del catálogo de acciones de dependencia |

**Como saber que quedo bien:**

1. **Ocultar según respuesta** - Dado que definí que la temperatura se pregunta solo si el equipo está operativo Cuando el técnico responde que el equipo no está operativo Entonces la pregunta de temperatura no se muestra
2. **Dependencia circular** - Cuando intento que un ítem dependa de si mismo Entonces la operación es rechazada
3. **Ítem oculto y obligatorio** - Dado un ítem obligatorio que queda oculto por una dependencia Entonces no bloquea el cierre del checklist Y queda registrado como no aplicable


### HU-097 - Consultar el historial de ejecuciones de un checklist

**Para que.** Como jefe de mantenimiento, revisar cómo se ha respondido una pauta a lo largo del tiempo, detectar un ítem que se responde siempre igual sin que nadie lo mire.

*Web - Sprint 4*

**Pestanas de Pautas de inspección:** Resumen / Configuración / Estructura / Versiones / Programaciones / Ocurrencias y ejecuciones / Hallazgos

**Como saber que quedo bien:**

1. **Historial por plantilla** - Cuando consulto una plantilla Entonces veo sus ejecuciones con fecha, ejecutor, activo y cantidad de no conformidades
2. **Detalle de una ejecución** - Cuando abro una ejecución Entonces veo cada pregunta con la respuesta registrada, su severidad y sus fotografías Y las preguntas corresponden a la versión con que se ejecutó


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-095 - Ejecución completa** - Cuando respondo todos los ítems obligatorios y finalizo Entonces la ejecución queda registrada con su fecha de inicio y de término Y se calcula la cantidad de ítems respondidos y no conformes
- **HU-095 - Ítem obligatorio sin responder** - Cuando intento finalizar con un ítem obligatorio sin responder Entonces se indica cuál falta y no se permite finalizar
- **HU-093 - Plantilla sin ítems** - Cuando intento publicar una versión sin ítems Entonces la operación es rechazada
- **HU-094 - Sin objetivo** - Cuando intento programar sin indicar activo ni área Entonces la operación es rechazada
- **HU-092 - Dependencia circular** - Cuando intento que un ítem dependa de si mismo Entonces la operación es rechazada
- **HU-092 - Ítem oculto y obligatorio** - Dado un ítem obligatorio que queda oculto por una dependencia Entonces no bloquea el cierre del checklist Y queda registrado como no aplicable

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
