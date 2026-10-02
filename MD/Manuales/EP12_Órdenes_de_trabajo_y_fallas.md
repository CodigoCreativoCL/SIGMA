# EP-12 - Órdenes de trabajo y fallas

> Gestionar el trabajo de mantenimiento desde que se detecta la necesidad hasta que se cierra.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Listado de órdenes | Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes | - | Ver ordenes de trabajo |
| Fallas | Centro de Mantenimiento > Órdenes de trabajo > Fallas | - | Ver ordenes de trabajo |
| Orden de trabajo (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Órdenes de trabajo > Orden de trabajo (detalle) | - | Ver ordenes de trabajo |
| Falla (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Órdenes de trabajo > Falla (detalle) | Ficha / Diagnósticos / Acciones / Indisponibilidad | Ver ordenes de trabajo |
| Indisponibilidad (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Órdenes de trabajo > Indisponibilidad (detalle) | - | Ver ordenes de trabajo |
| Firma de la orden (detalle) *(se abre desde otra pantalla)* | Centro de Mantenimiento > Órdenes de trabajo > Firma de la orden (detalle) | - | Validar orden de trabajo |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Validar orden de trabajo**
- **Ver ordenes de trabajo**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-035` - Registrar un activo
- [ ] `HU-055` - Entregar repuestos contra una orden de trabajo
- [ ] `HU-060` - Administrar proveedores
- [ ] `HU-087` - Consultar la bandeja de ocurrencias pendientes
- [ ] `HU-110` - Crear una orden de trabajo correctiva
- [ ] `HU-112` - Asignar una orden de trabajo
- [ ] `HU-113` - Tomar una orden de trabajo
- [ ] `HU-114` - Ejecutar los pasos de una orden en terreno
- [ ] `HU-119` - Finalizar una orden de trabajo
- [ ] `HU-120` - Cerrar una orden de trabajo
- [ ] `HU-121` - Consultar mi bandeja de trabajo

## 4. Paso a paso

### HU-110 - Crear una orden de trabajo correctiva

**Para que.** Como técnico, supervisor, jefe o planificador, registrar una necesidad de intervención, que el trabajo quede en el sistema desde el momento en que se detecta.

*Web y App - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Número | Solo lectura, asignado al guardar | No | Único por cliente |
| Título | Texto | Si | Máximo 200 caracteres |
| Planta | Lista desplegable | Si | Plantas del cliente |
| Área | Lista desplegable dependiente | No | Áreas de la planta |
| Activo | Lista desplegable con buscador y botón de escaneo QR | No | Activos de la planta |
| Componente | Lista desplegable dependiente del activo | No | Componentes del activo |
| Tipo | Lista desplegable: Preventiva / Correctiva / Predictiva | Si | Del catálogo de tipos de orden |
| Estrategia | Lista desplegable: Rutinario / Programado / Emergencia / Inspección / Overhaul / Mejora | Si | Del catálogo de estrategias |
| Prioridad | Lista desplegable: Baja / Media / Alta / Crítica | Si | Del catálogo de prioridades |
| Solicitado por | Lista desplegable de usuarios | No | Usuarios habilitados del cliente |
| Número de solicitud | Texto | No | Máximo 50 caracteres |
| Fecha del evento | Selector de fecha y hora | No | No puede ser futura |
| Descripción | Texto multilinea con dictado por voz | No | Sin límite |
| Centro de costo | Lista desplegable | No | Centros de costo del cliente |
| Requiere permiso de trabajo | Interruptor | No | Desactivado por defecto |
| Es un registro posterior | Interruptor | No | Habilita la fecha de ocurrencia |
| Fecha de ocurrencia | Selector de fecha y hora | No | Anterior a la fecha actual |

**Como saber que quedo bien:**

1. **Alta de orden** - Cuando creo una orden con título, tipo, estrategia y prioridad Entonces se crea en estado abierta con un correlativo único dentro del cliente Y queda registrado quién la generó
2. **El técnico puede abrir pero no cerrar** - Dado que mi perfil es técnico de mantenimiento Cuando creo una orden correctiva Entonces se crea correctamente Y la acción de cerrar la orden no está disponible para mi en ningún momento
3. **Registro posterior** - Dado que el trabajo ocurrió ayer a las 22:00 y lo registro hoy a las 09:00 Cuando marco la orden como registro posterior e indico la fecha de ocurrencia Entonces se conservan ambas fechas por separado Y la ficha muestra las dos
4. **Orden sin activo** - Cuando creo una orden sobre un área sin indicar activo Entonces la orden se crea correctamente Y no se contabiliza en los indicadores por equipo


### HU-114 - Ejecutar los pasos de una orden en terreno

**Para que.** Como técnico de mantenimiento, ir completando los pasos del trabajo desde el teléfono, registrar lo hecho en el momento y no de memoria al final del turno.

*App - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Resultado del paso | Botones de opción: Conforme / No conforme / No aplica | Si | Del catálogo de resultados de paso |
| Observación del paso | Texto multilinea con dictado | No | Mínimo 10 caracteres |
| Fotografía del paso | Cámara | No | JPG, máximo 4 MB |
| Valor medido | Teclado numérico con dictado | No | Validado contra los umbrales de la variable |

**Como saber que quedo bien:**

1. **Completar un paso** - Cuando marco un paso como conforme Entonces se registra quién lo ejecutó y en qué momento
2. **Paso no aplicable** - Dado un paso definido como no obligatorio Cuando lo marco como no aplica Entonces se solicita un comentario Y el paso no bloquea la finalización
3. **Paso obligatorio pendiente** - Cuando intento finalizar con un paso obligatorio sin resolver Entonces se indica cuál falta y no se permite finalizar
4. **Paso con medición** - Dado un paso que requiere medición Cuando registro el valor Entonces queda en la serie histórica del activo
5. **Ejecución sin conexión** - Dado que estoy sin señal Entonces puedo completar todos los pasos, dictar observaciones y tomar fotografías Y todo se sincroniza al recuperar conexión


### HU-111 - Generar una orden desde la ocurrencia de un plan

**Para que.** Como planificador, materializar en una orden la mantención que corresponde ejecutar, que el plan se traduzca en trabajo concreto sin volver a escribirlo.

*Web - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Como saber que quedo bien:**

1. **Generación desde la ocurrencia** - Cuando genero la orden desde una ocurrencia Entonces la orden se crea con origen plan de mantenimiento Y contiene un paso por cada actividad del hito Y los repuestos planificados quedan cargados
2. **Texto congelado** - Cuando se genera la orden Entonces el texto de cada paso se copia desde la actividad Y una modificación posterior del plan no altera la orden ya generada
3. **Generación masiva** - Cuando selecciono varias ocurrencias de la misma semana Entonces se genera una orden por cada una Y se informa el resultado de cada generación


### HU-120 - Cerrar una orden de trabajo

**Para que.** Como planificador, supervisor o jefe de mantenimiento, cerrar formalmente la orden, que el trabajo quede contabilizado y el equipo vuelva a su estado operativo.

*Web - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Motivo de cierre | Lista desplegable | Si | Del catálogo de motivos de cierre |
| Trabajo realizado | Texto multilinea con dictado | Si | Mínimo 20 caracteres |
| Tiempo de detención del equipo (minutos) | Numérico entero | No | Mayor o igual a cero |
| Estado en que queda el equipo | Lista desplegable | No | Del catálogo de estados de activo |
| Observación | Texto multilinea | No | Sin límite |

**Como saber que quedo bien:**

1. **Cierre normal** - Cuando cierro una orden en espera de cierre Entonces pasa a estado cerrada con fecha, responsable y motivo Y sus costos se contabilizan en los indicadores del periodo
2. **El técnico no puede cerrar** - Dado que mi perfil es técnico de mantenimiento Cuando se invoca la operación de cierre Entonces es rechazada con "Su perfil no tiene la facultad de cerrar órdenes de trabajo"
3. **Anular una orden** - Dado una orden creada por error Cuando la cierro con el motivo Anulada por error Entonces queda cerrada y el correlativo se conserva Y la orden sigue siendo consultable
4. **Resultado obligatorio** - Cuando intento cerrar sin describir el trabajo realizado Entonces la operación es rechazada


### HU-121 - Consultar mi bandeja de trabajo

**Para que.** Como técnico de mantenimiento, ver lo que tengo asignado para hoy, saber qué hacer al llegar a la planta sin preguntarle a nadie.

*App y Web - Sprint 6*

**Donde se hace:** Mis órdenes de trabajo

**Como se llega:** aplicacion movil

**Como saber que quedo bien:**

1. **Bandeja del día** - Cuando abro la bandeja Entonces veo mis órdenes, tareas y checklists del día ordenados por prioridad y hora Y se distingue lo asignado a mi de lo asignado a mi grupo
2. **Bandeja sin conexión** - Dado que estoy sin señal Entonces veo la bandeja de la última sincronización Y un indicador permanente muestra los cambios pendientes de enviar
3. **Trabajo disponible para tomar** - Cuando reviso el trabajo disponible Entonces veo las órdenes abiertas de mi planta que aún nadie ha tomado


### HU-112 - Asignar una orden de trabajo

**Para que.** Como planificador o supervisor, asignar la orden a un técnico, a un grupo o a una empresa externa, que quede claro quién es responsable de ejecutarla.

*Web - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Ejecuta | Botones de opción: Técnico / Grupo de trabajo / Empresa externa | Si | Una única selección |
| Técnico | Lista desplegable con buscador | No | Usuarios habilitados de la planta |
| Grupo de trabajo | Lista desplegable | No | Grupos de la planta |
| Empresa | Lista desplegable | No | Proveedores marcados como contratistas |
| Es el responsable | Interruptor | No | Un único responsable por orden |
| Rol | Lista desplegable: Ejecutor principal / Apoyo / Supervisor / Observador | No | Del catálogo de roles de ejecución |
| Especialidades requeridas | Grilla: especialidad, cantidad de personas | No | Cantidad mayor o igual a 1 |

**Como saber que quedo bien:**

1. **Asignación a un técnico** - Cuando asigno la orden a un técnico Entonces la orden aparece en su bandeja de trabajo Y recibe una notificación
2. **Asignación a una empresa externa** - Cuando indico que la ejecuta una empresa externa Entonces se selecciona el proveedor desde el registro de contratistas Y no se requiere crear un usuario para esa empresa
3. **Un solo responsable** - Cuando marco a un segundo participante como responsable Entonces el responsable anterior pasa a apoyo Y la orden mantiene un único responsable
4. **Especialidad requerida** - Dado que la orden requiere una especialidad Cuando selecciono a un técnico que no la tiene Entonces se advierte y se permite continuar registrando la advertencia


### HU-113 - Tomar una orden de trabajo

**Para que.** Como técnico de mantenimiento, tomar una orden disponible desde el teléfono, que quede claro que yo la estoy ejecutando y nadie más llegue a la misma máquina.

*App - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Como saber que quedo bien:**

1. **Toma de la orden** - Cuando tomo una orden abierta Entonces pasa a estado en ejecución Y quedo registrado como responsable con la fecha de inicio
2. **Dos técnicos simultaneos** - Dado una orden en estado abierta Cuando dos técnicos la toman en el mismo momento Entonces uno la toma correctamente Y el otro recibe "La orden ya fue tomada por otro usuario" Y no se registran dos responsables
3. **Sumar un compañero** - Dado que tomé la orden y soy el responsable Cuando agrego a otro técnico como apoyo Entonces ambos ven la orden en su bandeja Y el responsable sigue siendo uno solo


### HU-116 - Registrar el consumo de repuestos en una orden

**Para que.** Como técnico de mantenimiento, anotar qué repuestos se usaron y en qué componente, conocer el costo real de la intervención y la vida útil de cada pieza.

*App y Web - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Repuesto | Lista desplegable con buscador y lectura de código | Si | Repuestos compatibles con el activo |
| Cantidad consumida | Numérico decimal | Si | Mayor que cero |
| Bodega | Lista desplegable | Si | Bodegas con existencia del repuesto |
| Lote | Lista desplegable | No | Lotes con existencia |
| Se instaló en | Lista desplegable de componentes del activo | No | Componentes del activo |
| Horómetro al retirar | Numérico decimal | No | Mayor o igual a cero |
| Horómetro al instalar | Numérico decimal | No | Mayor o igual a cero |
| Cantidad devuelta | Numérico decimal | No | Menor o igual a la consumida |

**Como saber que quedo bien:**

1. **Consumo con descuento de existencia** - Cuando registro el consumo de un repuesto Entonces la existencia de la bodega disminuye Y el costo del repuesto se suma al costo de la orden
2. **Horómetro de la pieza** - Cuando registro el horómetro al retirar y al instalar una pieza Entonces se calcula la vida útil real de la pieza retirada Y ambos campos son opcionales
3. **Devolución de sobrante** - Cuando devuelvo un repuesto no utilizado Entonces la existencia aumenta y la cantidad consumida se reduce


### HU-119 - Finalizar una orden de trabajo

**Para que.** Como técnico de mantenimiento, dar por terminado el trabajo que ejecute, entregar la orden a quien corresponde cerrarla.

*App y Web - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Como saber que quedo bien:**

1. **Finalización** - Cuando finalizo el trabajo Entonces la orden pasa a estado en espera de cierre Y aparece en la bandeja del planificador Y ya no puedo modificarla
2. **Pasos pendientes** - Cuando intento finalizar con pasos obligatorios sin resolver Entonces se indica cuáles faltan y no se permite finalizar
3. **Mano de obra sin registrar** - Cuando intento finalizar sin ningún bloque de mano de obra Entonces se advierte y se permite continuar registrando la advertencia


### HU-122 - Consultar la bandeja de órdenes en espera de cierre

**Para que.** Como planificador, ver el trabajo terminado que todavía no he cerrado, tener a la vista mi propio pendiente y no dejar órdenes abiertas por meses.

*Web - Sprint 5*

**Donde se hace:** Listado de órdenes

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes

**Como saber que quedo bien:**

1. **Bandeja de cierre** - Cuando abro la bandeja Entonces veo las órdenes en espera de cierre con los días que llevan esperando Y están ordenadas por antigüedad
2. **Cierre desde la bandeja** - Cuando selecciono varias órdenes del mismo tipo Entonces puedo cerrarlas indicando un motivo común Y cada cierre queda registrado individualmente


### HU-115 - Registrar la mano de obra de una orden

**Para que.** Como técnico de mantenimiento, registrar las horas trabajadas por cada persona, saber cuánto esfuerzo costó realmente la intervención.

*Web y App - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Ejecutado por | Botones de opción: Usuario interno / Empresa externa | Si | Una única selección |
| Usuario | Lista desplegable | No | Usuarios asignados a la orden |
| Empresa | Lista desplegable | No | Proveedores contratistas |
| Desde | Selector de fecha y hora | Si | No puede ser futura |
| Hasta | Selector de fecha y hora | No | Posterior a la hora de inicio |
| Minutos | Numérico entero, calculado automáticamente | Si | Mayor que cero |
| Especialidad | Lista desplegable | No | Del catálogo de especialidades |
| Hora extraordinaria | Interruptor | No | Desactivado por defecto |
| Valor por hora | Numérico decimal | No | Mayor o igual a cero |
| Moneda | Lista desplegable | No | Por defecto la moneda del cliente |
| Observación | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Registro de un bloque de trabajo** - Cuando registro un bloque con hora de inicio y de término Entonces los minutos se calculan automáticamente Y la duración real de la orden es la suma de todos los bloques
2. **Mano de obra externa** - Cuando registro horas de una empresa externa Entonces se indica el proveedor en lugar del usuario Y puede registrarse el valor por hora y su moneda
3. **Ejecutante obligatorio** - Cuando intento registrar un bloque sin indicar usuario ni proveedor Entonces la operación es rechazada


### HU-117 - Registrar los servicios contratados en una orden

**Para que.** Como jefe de mantenimiento, registrar lo que se le pagó a un tercero por esta intervención, poder sumar el gasto en contratistas al cierre del periodo.

*Web - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Empresa | Lista desplegable | Si | Proveedores del cliente |
| Tipo de servicio | Lista desplegable: Servicio técnico / Arriendo de equipo / Montaje / Desmontaje / Mano de obra externa / Repuesto / Transporte / Calibración | Si | Del catálogo de tipos de servicio |
| Descripción | Texto | Si | Máximo 500 caracteres |
| Cantidad | Numérico decimal | No | Mayor que cero |
| Valor unitario | Numérico decimal | No | Mayor o igual a cero |
| Monto total | Numérico decimal | Si | Mayor o igual a cero |
| Moneda | Lista desplegable: Peso chileno / Unidad de fomento / Dólar | Si | Del catálogo de monedas |
| Número de orden de compra o factura | Texto | No | Máximo 100 caracteres |
| Fecha del servicio | Selector de fecha | No | No puede ser futura |
| Informe del trabajo realizado | Carga de archivo o cámara | Si | PDF o imagen, máximo 10 MB |

**Como saber que quedo bien:**

1. **Registro de un servicio** - Cuando registro un servicio con proveedor, tipo, descripción y monto Entonces el monto se suma al costo de terceros de la orden
2. **Adjuntar el informe del trabajo** - Cuando adjunto el informe entregado por el proveedor Entonces queda asociado a la orden y disponible para consulta Y el informe es obligatorio para cerrar una orden con servicios de terceros
3. **Montos en distintas monedas** - Dado que registro un servicio en unidades de fomento y otro en pesos Entonces el total se presenta separado por moneda


### HU-123 - Registrar una falla y su diagnóstico

**Para que.** Como técnico o supervisor de mantenimiento, registrar qué se rompió, cómo falló y por qué, poder analizar después las causas que más repiten y atacarlas.

*Web y App - Sprint 5*

**Donde se hace:** Falla (detalle) > pestana **Diagnósticos**

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Fallas > se abre Falla (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Activo | Lista desplegable con buscador y escaneo QR | Si | Activos del cliente |
| Componente | Lista desplegable dependiente | No | Componentes del activo |
| Síntoma observado | Lista desplegable | No | Del catálogo de síntomas |
| Título | Texto | Si | Máximo 200 caracteres |
| Descripción | Texto multilinea con dictado | No | Sin límite |
| Consecuencia | Texto | No | Máximo 500 caracteres |
| Criticidad | Lista desplegable | Si | Del catálogo de niveles de criticidad |
| Detuvo la producción | Interruptor | No | Desactivado por defecto |
| Fecha de detección | Selector de fecha y hora | Si | No puede ser futura |
| Estado en que queda el equipo | Lista desplegable | No | Del catálogo de estados de activo |
| Modo de falla | Lista desplegable | No | Del catálogo de modos de falla |
| Causa | Selector de árbol de causas | No | Del catálogo jerárquico de causas |
| Método de diagnóstico | Lista desplegable | No | Del catálogo de métodos de diagnóstico |
| La acción es definitiva | Interruptor | No | Desactivado por defecto |

**Como saber que quedo bien:**

1. **Registro de la falla** - Cuando registro una falla indicando activo, síntoma y criticidad Entonces queda disponible para asociarle diagnóstico, acciones y una orden
2. **Diagnóstico posterior** - Cuando registro un diagnóstico después de desarmar el equipo Entonces puedo indicar modo de falla, causa y método de diagnóstico Y pueden registrarse varios diagnósticos sucesivos sobre la misma falla
3. **Acción definitiva o provisoria** - Cuando registro una acción Entonces indico si es definitiva o provisoria Y esa distinción permite detectar equipos reparados de forma provisoria repetidas veces
4. **Estado posterior del equipo** - Cuando indico el estado en que queda el equipo tras la falla Entonces se registra el cambio de estado del activo


### HU-124 - Registrar la indisponibilidad de un equipo

**Para que.** Como supervisor de mantenimiento, registrar el tiempo en que un equipo no estuvo disponible, poder calcular la disponibilidad real y no un promedio sin sustento.

*Web y App - Sprint 5*

**Donde se hace:** Indisponibilidad (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Fallas > se abre Indisponibilidad (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Activo | Lista desplegable con buscador | Si | Activos del cliente |
| Orden de trabajo | Lista desplegable con buscador | No | Órdenes del activo |
| Motivo | Lista desplegable: Mantenimiento planificado / Falla / Espera de repuesto / Espera de técnico / Causa externa / Parada de producción | Si | Del catálogo de motivos de indisponibilidad |
| Desde | Selector de fecha y hora | Si | No puede ser futura |
| Hasta | Selector de fecha y hora | No | Posterior al inicio |
| Fue planificada | Interruptor | Si | Desactivado por defecto |
| Detuvo la producción | Interruptor | No | Desactivado por defecto |
| Detalle | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Registro de indisponibilidad** - Cuando registro un periodo de indisponibilidad Entonces los minutos se calculan a partir del inicio y del término
2. **Planificada o no planificada** - Cuando marco la indisponibilidad como planificada Entonces no penaliza el indicador de disponibilidad Y una parada no planificada si lo penaliza
3. **Indisponibilidad sin orden** - Cuando registro una parada por corte de energía sin orden asociada Entonces el registro se acepta correctamente


### HU-118 - Registrar las firmas de aceptación, ejecución y validación

**Para que.** Como supervisor o jefe de mantenimiento, dejar constancia de quién recibió, ejecutó y aprobó el trabajo, que la orden tenga el mismo respaldo que el formulario en papel que reemplaza.

*Web y App - Sprint 5*

**Donde se hace:** Firma de la orden (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Firma de la orden (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tipo de firma | Lista desplegable: Aceptación / Ejecución / Validación | Si | Del catálogo de tipos de validación |
| Resultado | Botones de opción: Aprobado / Rechazado | Si | Una única selección |
| Observación | Texto multilinea | No | Mínimo 10 caracteres |
| Firma | Captura de firma en pantalla táctil | No | Imagen PNG |

**Como saber que quedo bien:**

1. **Registro de una firma** - Cuando registro una firma indicando su tipo y resultado Entonces queda con fecha, usuario y observación
2. **Rechazo y nueva validación** - Cuando una validación se registra como rechazada Entonces puede registrarse una validación posterior Y ambas quedan visibles en el historial
3. **Estado derivado** - Dado que existe una validación aprobada Entonces la orden se presenta como validada Y esa condición se calcula al consultar, no se almacena como estado


### HU-125 - Imprimir una orden de trabajo

**Para que.** Como jefe de mantenimiento, imprimir la orden en el formato que usa la planta, entregarla en papel cuando el trabajo lo requiere.

*Web - Sprint 5*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** Centro de Mantenimiento > Órdenes de trabajo > Listado de órdenes > se abre Orden de trabajo (detalle)

**Como saber que quedo bien:**

1. **Documento imprimible** - Cuando solicito imprimir una orden Entonces se genera un documento con el encabezado del cliente, los datos de la orden, sus pasos, repuestos, mano de obra y espacios de firma
2. **Orden cerrada** - Cuando imprimo una orden cerrada Entonces el documento incluye el resultado, el motivo de cierre y las firmas registradas


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-114 - Paso no aplicable** - Dado un paso definido como no obligatorio Cuando lo marco como no aplica Entonces se solicita un comentario Y el paso no bloquea la finalización
- **HU-114 - Paso obligatorio pendiente** - Cuando intento finalizar con un paso obligatorio sin resolver Entonces se indica cuál falta y no se permite finalizar
- **HU-120 - El técnico no puede cerrar** - Dado que mi perfil es técnico de mantenimiento Cuando se invoca la operación de cierre Entonces es rechazada con "Su perfil no tiene la facultad de cerrar órdenes de trabajo"
- **HU-120 - Anular una orden** - Dado una orden creada por error Cuando la cierro con el motivo Anulada por error Entonces queda cerrada y el correlativo se conserva Y la orden sigue siendo consultable
- **HU-120 - Resultado obligatorio** - Cuando intento cerrar sin describir el trabajo realizado Entonces la operación es rechazada
- **HU-112 - Especialidad requerida** - Dado que la orden requiere una especialidad Cuando selecciono a un técnico que no la tiene Entonces se advierte y se permite continuar registrando la advertencia
- **HU-119 - Pasos pendientes** - Cuando intento finalizar con pasos obligatorios sin resolver Entonces se indica cuáles faltan y no se permite finalizar
- **HU-119 - Mano de obra sin registrar** - Cuando intento finalizar sin ningún bloque de mano de obra Entonces se advierte y se permite continuar registrando la advertencia
- **HU-115 - Ejecutante obligatorio** - Cuando intento registrar un bloque sin indicar usuario ni proveedor Entonces la operación es rechazada
- **HU-117 - Adjuntar el informe del trabajo** - Cuando adjunto el informe entregado por el proveedor Entonces queda asociado a la orden y disponible para consulta Y el informe es obligatorio para cerrar una orden con servicios de terceros
- **HU-118 - Rechazo y nueva validación** - Cuando una validación se registra como rechazada Entonces puede registrarse una validación posterior Y ambas quedan visibles en el historial

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
