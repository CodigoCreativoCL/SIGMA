# EP-04 - Maestro de activos y ubicación técnica

> Saber qué equipos existen, dónde están y de qué están compuestos.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Activos | Control de activos > Activos | Resumen / Ficha / Historial / Órdenes de trabajo / Mantenimiento / Inspecciones y tareas / Más | Ver los activos del cliente |
| Tipos de activo | Control de activos > Configuración de activos > Tipos de activo | - | Ver los tipos de activo |
| Modelos de activo | Control de activos > Configuración de activos > Modelos de activo | - | Ver los modelos de activo |
| Atributos técnicos | Control de activos > Configuración de activos > Atributos técnicos | - | Ver los atributos técnicos |
| Posiciones | Control de activos > Configuración de activos > Posiciones | - | Ver las posiciones funcionales |
| Activos *(se abre desde otra pantalla)* | Control de activos > Activos | - | Ver los activos del cliente |
| Componentes *(se abre desde otra pantalla)* | Control de activos > Componentes | - | Ver los componentes de los activos |
| Cambiar estado *(se abre desde otra pantalla)* | Control de activos > Cambiar estado | - | Cambiar el estado de un activo indicando el motivo |
| Activo (detalle) *(se abre desde otra pantalla)* | Control de activos > Activo (detalle) | - | Ver los activos del cliente |
| Componente (detalle) *(se abre desde otra pantalla)* | Control de activos > Componente (detalle) | - | Ver los componentes de los activos |
| Registrar lectura *(se abre desde otra pantalla)* | Control de activos > Registrar lectura | - | Registrar medicion de condicion |
| Carga masiva de activos *(se abre desde otra pantalla)* | Control de activos > Carga masiva de activos | - | Crear y editar activos |
| Tipo de activo (detalle) *(se abre desde otra pantalla)* | Control de activos > Configuración de activos > Tipo de activo (detalle) | - | Ver los tipos de activo |
| Modelo (detalle) *(se abre desde otra pantalla)* | Control de activos > Configuración de activos > Modelo (detalle) | - | Ver los modelos de activo |
| Atributo (detalle) *(se abre desde otra pantalla)* | Control de activos > Configuración de activos > Atributo (detalle) | - | Ver los atributos técnicos |
| Posición (detalle) *(se abre desde otra pantalla)* | Control de activos > Configuración de activos > Posición (detalle) | Datos / Ocupación | Ver las posiciones funcionales |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Cambiar el estado de un activo indicando el motivo**
- **Crear y editar activos**
- **Registrar medicion de condicion**
- **Ver las posiciones funcionales**
- **Ver los activos del cliente**
- **Ver los atributos técnicos**
- **Ver los componentes de los activos**
- **Ver los modelos de activo**
- **Ver los tipos de activo**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-012` - Administrar las áreas de una planta
- [ ] `HU-030` - Administrar tipos de activo
- [ ] `HU-032` - Definir los atributos técnicos de un tipo de activo
- [ ] `HU-033` - Registrar una posición funcional
- [ ] `HU-035` - Registrar un activo

## 4. Paso a paso

### HU-035 - Registrar un activo

**Para que.** Como planificador, dar de alta un equipo con su ficha técnica completa, tener el inventario de máquinas sobre el cual se planifica todo el mantenimiento.

*Web - Sprint 2*

**Donde se hace:** Activo (detalle)

**Como se llega:** Control de activos > Activos > se abre Activo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Planta | Lista desplegable | Si | Plantas del cliente |
| Área | Lista desplegable dependiente | No | Áreas de la planta seleccionada |
| Posición funcional | Lista desplegable dependiente del área | No | Solicita confirmación si está ocupada |
| Tipo | Selector de árbol | Si | Del árbol de tipos |
| Modelo | Lista desplegable dependiente del tipo | No | Modelos del tipo seleccionado |
| Activo superior | Lista desplegable con buscador | No | No puede ser el mismo activo ni un descendiente |
| Estado | Lista desplegable | Si | Operativo por defecto |
| Criticidad | Lista desplegable | Si | Del catálogo de niveles de criticidad |
| Centro de costo | Lista desplegable | No | Centros de costo del cliente |
| Número de serie | Texto | No | Máximo 100 caracteres |
| Fabricante | Texto | No | Se propone el del modelo |
| Fecha de puesta en marcha | Selector de fecha | No | No puede ser futura |
| Ficha técnica | Grilla dinámica según el tipo | No | Cada atributo aplica su propia validación |

**Como saber que quedo bien:**

1. **Alta de activo** - Cuando registro un activo con código, nombre, tipo y estado Entonces queda disponible para planes, órdenes, checklists y mediciones Y su código es único dentro del cliente
2. **Posición ocupada** - Dado que la posición elegida está ocupada por otro activo Cuando la asigno a este activo Entonces se solicita confirmación indicando que activo la ocupa Y al confirmar se cierra el periodo del activo anterior y se abre el del nuevo
3. **Ficha técnica dinámica** - Dado un activo de tipo Blower con atributos definidos Cuando abro la pestaña Datos técnicos Entonces se muestran los campos definidos para ese tipo
4. **Subactivo** - Cuando asigno un activo superior Entonces el activo aparece anidado bajo el equipo principal Y no puede ser su propio ascendiente


### HU-037 - Consultar la ficha y el historial de un activo

**Para que.** Como usuario de mantenimiento, ver toda la vida de un equipo en una sola pantalla, entender qué le ha pasado antes de intervenirlo.

*Web y App - Sprint 2*

**Donde se hace:** Activo (detalle)

**Como se llega:** Control de activos > Activos > se abre Activo (detalle)

**Como saber que quedo bien:**

1. **Contenido de la ficha** - Cuando abro la ficha de un activo Entonces veo identificación, ubicación, estado, criticidad, componentes y datos técnicos
2. **Línea de tiempo** - Cuando abro la pestaña Historial Entonces veo en orden cronológico las órdenes, fallas, cambios de estado, cambios de posición y mediciones Y puedo filtrar por tipo de evento y por rango de fechas
3. **Consulta sin conexión** - Dado que estoy en la aplicación móvil sin señal Cuando abro la ficha de un activo sincronizado Entonces se muestra la información local Y se indica la fecha de la última sincronización


### HU-033 - Registrar una posición funcional

**Para que.** Como planificador, definir posiciones funcionales estables dentro de cada área, que el código QR pegado en la sala siga sirviendo aunque se cambie la máquina.

*Web - Sprint 2*

**Donde se hace:** Posición (detalle)

**Como se llega:** Control de activos > Configuración de activos > Posiciones > se abre Posición (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Planta | Lista desplegable | Si | Plantas del cliente |
| Área | Lista desplegable dependiente de la planta | Si | Áreas de la planta seleccionada |
| Código de posición | Texto | Si | Único por cliente. Es el contenido del código QR |
| Nombre | Texto | Si | Ejemplo: Blower 1 sala de blowers |
| Tipo de activo admitido | Lista desplegable | No | Restringe que equipos pueden ocuparla |
| Posición crítica | Interruptor | No | Desactivado por defecto |

**Como saber que quedo bien:**

1. **Alta de posición** - Cuando registro la posición CB01 en el área Sala de blowers Entonces queda disponible para asignarle un activo Y su código es único dentro del cliente
2. **Historial de ocupación** - Dado que la posición CB01 fue ocupada por el activo A y después por el activo B Cuando consulto su historial Entonces veo ambos periodos con su fecha de inicio y de término Y el periodo vigente no tiene fecha de término


### HU-036 - Registrar los componentes de un activo

**Para que.** Como planificador, desglosar el equipo en sus componentes, saber qué pieza falló y cuánto duró, no solo que falló la máquina.

*Web - Sprint 2*

**Donde se hace:** Componente (detalle)

**Como se llega:** Control de activos > Activos > se abre Componente (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Componente superior | Selector de árbol del activo | No | Vacío indica primer nivel |
| Código | Texto | Si | Único por activo |
| Nombre | Texto | Si | Ejemplo: Rodamiento lado acople |
| Tipo de componente | Lista desplegable | No | Del catálogo de tipos de componente |
| Posición física | Texto | No | Ejemplo: lado A, lado B |
| Criticidad | Lista desplegable | Si | Del catálogo de niveles de criticidad |
| Estado | Lista desplegable | Si | Del catálogo de estados de componente |
| Fecha de instalación | Selector de fecha | No | No puede ser futura |

**Como saber que quedo bien:**

1. **Alta de componente** - Cuando agrego el componente Rodamiento lado acople al activo Entonces puedo asociarle fallas, repuestos y mediciones propias Y su código es único dentro del activo
2. **Jerarquía de componentes** - Cuando defino un componente dentro de otro Entonces se muestra anidado en el árbol del activo
3. **Estado del componente** - Cuando cambio el estado de un componente Entonces el cambio queda registrado con fecha, motivo y responsable


### HU-038 - Cambiar el estado de un activo indicando el motivo

**Para que.** Como supervisor de mantenimiento, registrar cuando un equipo sale o vuelve a operación, que la disponibilidad calculada corresponda a lo que realmente paso.

*Web y App - Sprint 2*

**Donde se hace:** Cambiar estado

**Como se llega:** Control de activos > Activos > se abre Cambiar estado

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Estado nuevo | Lista desplegable | Si | Distinto del estado actual |
| Fecha del cambio | Selector de fecha y hora | Si | Por defecto la fecha actual. No puede ser futura |
| Motivo | Texto multilinea con dictado por voz | Si | Mínimo 10 caracteres |

**Como saber que quedo bien:**

1. **Cambio de estado** - Cuando cambio el estado de un activo Entonces se exige un motivo Y el cambio queda registrado con fecha, usuario y motivo
2. **Cierre del periodo anterior** - Cuando registro un estado nuevo Entonces el periodo del estado anterior se cierra con la misma fecha Y no quedan dos periodos vigentes simultaneos


### HU-034 - Generar e imprimir el código QR de una posición

**Para que.** Como planificador, imprimir el código QR de una posición, que el técnico llegue a la máquina y acceda a su ficha escaneándolo.

*Web - Sprint 2*

**Donde se hace:** Etiquetas

**Como se llega:** Control de activos > Configuración de activos > Posiciones > se abre Etiquetas

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Posiciones | Selección múltiple con filtro por área | Si | Al menos una posición |
| Formato de etiqueta | Lista desplegable: 50x50 mm / 70x70 mm / 100x100 mm | Si | Formato de 70x70 mm por defecto |

**Como saber que quedo bien:**

1. **Impresión individual** - Cuando solicito el código QR de una posición Entonces se genera un documento imprimible con el código, el código de posición y el nombre Y el contenido codificado es el código de posición
2. **Impresión masiva** - Cuando selecciono varias posiciones de un área Entonces se genera un único documento con una etiqueta por posición


### HU-030 - Administrar tipos de activo

**Para que.** Como planificador, clasificar los equipos en una jerarquía de tipos, poder definir planes y procedimientos aplicables a toda una familia de máquinas.

*Web - Sprint 2*

**Donde se hace:** Tipo de activo (detalle)

**Como se llega:** Control de activos > Configuración de activos > Tipos de activo > se abre Tipo de activo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tipo superior | Selector de árbol | No | Vacío indica primer nivel |
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Orden | Numérico entero | No | Define la posición en las listas |

**Como saber que quedo bien:**

1. **Jerarquía de tipos** - Cuando creo el tipo Blower dentro del tipo Equipo rotatorio Entonces al filtrar por Equipo rotatorio se incluyen los activos de tipo Blower
2. **Tipo global y tipo propio** - Dado un tipo definido por SIGMA para todos los clientes Entonces puedo usarlo pero no modificarlo Y puedo crear tipos propios de mi cliente


### HU-031 - Administrar modelos de activo

**Para que.** Como planificador, registrar fabricante y modelo de los equipos, reutilizar planes y repuestos entre máquinas identicas.

*Web - Sprint 2*

**Donde se hace:** Modelo (detalle)

**Como se llega:** Control de activos > Configuración de activos > Modelos de activo > se abre Modelo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tipo de activo | Lista desplegable | Si | Del árbol de tipos |
| Fabricante | Texto | Si | Máximo 200 caracteres |
| Modelo | Texto | Si | Ejemplo: GM10S |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |
| Ficha técnica | Carga de archivo | No | PDF, máximo 20 MB |

**Como saber que quedo bien:**

1. **Alta de modelo** - Cuando registro el modelo GM10S del fabricante Aerzen para el tipo Blower Entonces puedo asociarlo a cada uno de los blowers de ese modelo Y los repuestos compatibles con el modelo aplican a todos ellos


### HU-032 - Definir los atributos técnicos de un tipo de activo

**Para que.** Como planificador, definir qué datos técnicos se registran para cada tipo de equipo, que la ficha de un blower pida potencia y caudal, y la de un motor pida otra cosa.

*Web - Sprint 2*

**Donde se hace:** Atributo (detalle)

**Como se llega:** Control de activos > Configuración de activos > Atributos técnicos > se abre Atributo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tipo de activo | Lista desplegable | Si | Del árbol de tipos |
| Código | Texto | Si | Único por tipo de activo |
| Nombre visible | Texto | Si | Ejemplo: Potencia nominal |
| Tipo de dato | Lista desplegable: Texto / Numérico / Fecha / Sí-No / Lista | Si | Determina el control en la ficha |
| Unidad de medida | Lista desplegable | No | Solo para atributos numéricos |
| Obligatorio | Interruptor | No | Desactivado por defecto |

**Como saber que quedo bien:**

1. **Atributos por tipo** - Cuando defino los atributos Potencia y Caudal para el tipo Blower Entonces la ficha de cualquier blower muestra esos campos Y no los muestra en equipos de otro tipo
2. **Atributo con unidad** - Cuando defino un atributo numérico con unidad kW Entonces el campo en la ficha muestra la unidad junto al valor


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-035 - Subactivo** - Cuando asigno un activo superior Entonces el activo aparece anidado bajo el equipo principal Y no puede ser su propio ascendiente

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
