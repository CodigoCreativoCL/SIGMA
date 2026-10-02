# EP-17 - SIGMA AI

> Anticipar la falla de un equipo y presentar esa anticipación de forma que provoque una decisión.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Análisis de SIGMA AI | Análisis de SIGMA AI | - | Ver el analisis de SIGMA AI |
| Experimentos | SIGMA AI > Experimentos | - | Ver el analisis de SIGMA AI |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver el analisis de SIGMA AI**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-110` - Crear una orden de trabajo correctiva
- [ ] `HU-162` - Configurar las opciones de accesibilidad
- [ ] `HU-170` - Definir un modelo predictivo y sus características
- [ ] `HU-171` - Preparar el conjunto de datos de entrenamiento
- [ ] `HU-172` - Entrenar y publicar una versión del modelo
- [ ] `HU-173` - Ver el panel SIGMA AI al ingresar
- [ ] `HU-175` - Ver por qué el modelo predice lo que predice
- [ ] `HU-176` - Generar una orden de trabajo desde una predicción
- [ ] `HU-177` - Registrar si la predicción se cumplió

## 4. Paso a paso

### HU-173 - Ver el panel SIGMA AI al ingresar

**Para que.** Como planificador o jefe de mantenimiento, ver las predicciones activas apenas entro al sistema, enterarme de un problema mientras todavía puedo evitarlo.

*Web y App - Sprint 6*

**Donde se hace:** Análisis de SIGMA AI

**Como se llega:** aplicacion movil

**Como saber que quedo bien:**

1. **Predicciones activas** - Cuando ingreso a la pantalla de inicio Entonces veo las predicciones vigentes ordenadas por nivel y luego por fecha Y cada tarjeta muestra el equipo, la probabilidad, los días restantes y las tres razones principales
2. **Sin predicciones** - Cuando no hay predicciones vigentes Entonces el panel indica cuántos equipos están siendo vigilados Y no se muestra un espacio vacío ni un mensaje de error
3. **Datos insuficientes** - Dado un equipo sin mediciones suficientes para predecir Entonces la tarjeta indica que faltan datos y cuántas lecturas se requieren
4. **Aislamiento entre clientes** - Dado que pertenezco a dos clientes Entonces solo veo las predicciones del cliente con el que inicie sesión
5. **Panel en la aplicación móvil** - Cuando abro la aplicación Entonces el panel aparece en la parte superior de la pantalla de inicio en formato compacto y deslizable Y mi bandeja de trabajo permanece accesible sin desplazarme En la aplicación el panel es compacto porque el técnico entra a hacer su trabajo. Una lista larga de predicciones lo obligaría a desplazarse cada vez, y a los pocos días dejaría de mirarlas.


### HU-176 - Generar una orden de trabajo desde una predicción

**Para que.** Como planificador, convertir una predicción en trabajo concreto, que la anticipación sirva para evitar la falla y no solo para saber qué venia.

*Web - Sprint 6*

**Donde se hace:** Orden de trabajo (detalle)

**Como se llega:** aplicacion movil > se abre Orden de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Título | Texto, precargado | Si | Máximo 200 caracteres |
| Prioridad | Lista desplegable, precargada según el nivel | Si | Del catálogo de prioridades |
| Fecha programada | Selector de fecha, precargada | Si | Anterior a la fecha estimada del evento |
| Descripción | Texto multilinea, precargado con las razones | Si | Editable |
| Motivo del descarte | Texto multilinea | No | Mínimo 10 caracteres |

**Como saber que quedo bien:**

1. **Generación de la orden** - Cuando genero una orden desde una predicción Entonces la orden se crea con origen predicción Y la descripción viene precargada con las razones de la predicción Y la predicción queda enlazada a esa orden
2. **Fecha propuesta** - Cuando se genera la orden Entonces se propone una fecha programada anterior a la fecha estimada del evento Y esa fecha puede modificarse
3. **Tarjeta atendida** - Cuando la orden queda creada Entonces la tarjeta muestra el número de orden generada Y deja de destacarse y de sonar
4. **Descartar la predicción** - Cuando descarto una predicción Entonces se exige un motivo de al menos 10 caracteres Y la predicción sale del panel pero sigue contando para las métricas del modelo


### HU-175 - Ver por qué el modelo predice lo que predice

**Para que.** Como jefe de mantenimiento, entender en qué se basa una predicción, poder decidir con fundamento y responder cuando me pregunten de dónde salió.

*Web y App - Sprint 6*

**Donde se hace:** Análisis de SIGMA AI

**Como se llega:** aplicacion movil

**Como saber que quedo bien:**

1. **Detalle de la predicción** - Cuando abro una predicción Entonces veo todas las razones ordenadas por su peso, con su valor observado y su valor de referencia Y cada razón está redactada en lenguaje comprensible
2. **Serie de la variable determinante** - Cuando abro el detalle Entonces se muestra la serie histórica de la variable que más contribuyó Y la banda de valores normales aparece sombreada
3. **Intervalo de la estimación** - Cuando la predicción indica días restantes Entonces se muestra el rango estimado y su nivel de confianza Y no solo un valor único
4. **Versión del modelo** - Cuando abro el detalle Entonces veo qué modelo y qué versión produjeron la predicción, con sus métricas Y si el modelo fue entrenado con datos sintéticos se indica explícitamente Presentar el rango en lugar de un valor único es lo que permite que la predicción resista el escrutinio. Un valor único invita a declarar equivocado al modelo por un día de diferencia.


### HU-174 - Recibir el aviso de una predicción crítica

**Para que.** Como planificador, que una predicción crítica me llame la atención cuando aparece, no descubrirla tres días después revisando un listado.

*Web y App - Sprint 6*

**Donde se hace:** Alerta (detalle)

**Como se llega:** Alertas > se abre Alerta (detalle)

**Como saber que quedo bien:**

1. **Aviso visual** - Cuando aparece una predicción crítica que no había visto Entonces la tarjeta entra con una animación de aparición Y el contador del menú se incrementa
2. **Primera activación del sonido en la web** - Dado que nunca active las alertas sonoras en este navegador Cuando aparece una predicción crítica Entonces se muestra la opción Activar alertas sonoras Y no se intenta reproducir audio antes de esa activación
3. **Aviso sonoro** - Dado que las alertas sonoras están activadas Cuando aparece una predicción crítica nueva Entonces suena una única vez Y no vuelve a sonar por esa misma predicción aunque actualice la página
4. **Notificación en la aplicación móvil** - Dado que la aplicación está en segundo plano Cuando aparece una predicción crítica Entonces llega una notificación con vibración Y al tocarla se abre directamente esa predicción
5. **Horario de silencio** - Dado que son las 23:40 en la hora local de la planta Cuando aparece una predicción crítica Entonces la notificación llega sin sonido Y queda marcada como no vista para la mañana siguiente
6. **Equivalente visual del sonido** - Dado que las alertas sonoras están silenciadas Entonces la predicción crítica sigue destacándose visualmente Y la información transmitida es la misma
7. **Movimiento reducido** - Dado que el sistema operativo solicita movimiento reducido Entonces no se aplica animación continua Y el sonido conserva su comportamiento El sonido dura alrededor de un segundo, es un aviso atento y no una alarma de emergencia, y no se repite. Un sonido que se repite se silencia, y con él se silencian los avisos que sí importaban.


### HU-177 - Registrar si la predicción se cumplió

**Para que.** Como planificador, registrar qué ocurrió realmente después de una predicción, que el modelo aprenda de sus aciertos y de sus errores.

*Web - Sprint 6*

**Donde se hace:** Análisis de SIGMA AI

**Como se llega:** aplicacion movil

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| El evento previsto ocurrió | Botones de opción: Sí / No | Si | Una única selección |
| Fecha en que ocurrió | Selector de fecha y hora | No | No puede ser futura |
| Falla registrada | Lista desplegable | No | Fallas del activo |
| Se intervino el equipo antes de la fecha prevista | Interruptor | Si | Determina la clasificación del resultado |
| Observación | Texto multilinea | No | Sin límite |

**Como saber que quedo bien:**

1. **Registro del resultado** - Cuando registro si el evento ocurrió y en qué fecha Entonces la predicción queda evaluada Y el error respecto de la fecha estimada se calcula automáticamente
2. **Acierto con intervención** - Dado una predicción de falla en seis días Y una orden preventiva ejecutada al cuarto día Y ninguna falla ocurrida Cuando registro que el evento no ocurrió pero sí hubo intervención previa Entonces se clasifica como acierto con intervención Y no se contabiliza como falso positivo
3. **Evaluación pendiente** - Dado una predicción cuyo horizonte ya venció y no fue evaluada Entonces aparece en la lista de predicciones pendientes de evaluar


### HU-170 - Definir un modelo predictivo y sus características

**Para que.** Como administrador de SIGMA, configurar qué se predice, sobre qué equipos y con qué variables, poder ajustar el modelo sin reescribir el sistema.

*Web - Sprint 6*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Ejemplo: Falla de rodamiento en blowers |
| Objetivo | Lista desplegable: Falla / Vida útil restante / Anomalía / Consumo | Si | Del catálogo de objetivos de modelo |
| Tipo de activo | Lista desplegable | No | Del árbol de tipos |
| Horizonte de predicción (días) | Numérico entero | No | Mayor que cero |
| Umbral de aviso | Numérico decimal | No | Entre 0 y 1 |
| Umbral crítico | Numérico decimal | No | Entre 0 y 1, mayor que el umbral de aviso |
| Etiqueta de la característica | Texto | No | Es el texto que lee el usuario |
| Tipo de característica | Lista desplegable: Numérica / Categorica / Binaria / Temporal / Derivada | No | Del catálogo de tipos de característica |
| Variable de origen | Lista desplegable | No | Variables de condición definidas |
| Ventana (días) | Numérico entero | No | Mayor que cero |
| Agregación | Lista desplegable: Media / Máximo / Mínimo / Suma / Conteo / Pendiente / Desviación / Último | No | Determina cómo se resume la ventana |

**Como saber que quedo bien:**

1. **Alta de modelo** - Cuando defino un modelo indicando su objetivo, el tipo de activo y su horizonte Entonces queda disponible para asociarle características y entrenarlo
2. **Características de entrada** - Cuando defino una característica con su etiqueta legible, su ventana y su agregación Entonces esa etiqueta es la que se muestra al usuario en la explicación de una predicción
3. **Modelo global y modelo por cliente** - Dado un modelo definido para todos los clientes Entonces un cliente sin historial recibe predicciones desde el primer día Y a medida que acumula datos puede entrenarse un modelo propio


### HU-172 - Entrenar y publicar una versión del modelo

**Para que.** Como administrador de SIGMA, entrenar el modelo y dejar publicada la versión que se usará, poder comparar versiones y volver atrás cuando una resulta peor.

*Web - Sprint 6*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Conjunto de entrenamiento | Lista desplegable | Si | Conjuntos del modelo |
| Algoritmo | Texto | No | Máximo 100 caracteres |
| Hiperparametros | Texto multilinea | No | Formato estructurado |
| Número de versión | Numérico entero | Si | Único por modelo |

**Como saber que quedo bien:**

1. **Ejecución de entrenamiento** - Cuando ejecuto un entrenamiento Entonces queda registrado su inicio, su término y sus métricas Y los entrenamientos fallidos también quedan registrados con su error
2. **Publicación de la versión** - Cuando publico una versión Entonces pasa a ser la versión vigente Y la versión anterior queda retirada y disponible para consulta
3. **Comparación de versiones** - Cuando comparo dos versiones Entonces veo sus métricas lado a lado Y puedo volver a publicar una versión anterior


### HU-171 - Preparar el conjunto de datos de entrenamiento

**Para que.** Como administrador de SIGMA, construir el conjunto de datos con el que se entrena el modelo, poder reproducir y auditar después cualquier entrenamiento.

*Web - Sprint 6*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Modelo predictivo | Lista desplegable | Si | Modelos definidos |
| Código del conjunto | Texto | Si | Único por modelo |
| Fecha desde | Selector de fecha | Si | Sin restricción |
| Fecha hasta | Selector de fecha | Si | Posterior a la fecha desde |
| Partición de entrenamiento (por ciento) | Numérico entero | Si | Las tres particiones deben sumar 100 |
| Partición de validación (por ciento) | Numérico entero | Si | Las tres particiones deben sumar 100 |
| Partición de prueba (por ciento) | Numérico entero | Si | Las tres particiones deben sumar 100 |
| Conjunto sintético | Interruptor | Si | Debe marcarse cuando los datos son generados |

**Como saber que quedo bien:**

1. **Definición del conjunto** - Cuando defino el rango de fechas y el modelo Entonces se construye el conjunto y se registra la cantidad de filas totales y positivas
2. **Reproducibilidad** - Cuando consulto un conjunto usado en un entrenamiento anterior Entonces veo el rango, los conteos y la partición entre entrenamiento, validación y prueba
3. **Datos sintéticos** - Dado que aún no existe historial suficiente Cuando genero un conjunto sintético de curvas de degradación que terminan en falla Entonces el conjunto queda marcado como sintético Y esa condición se muestra en toda predicción producida por un modelo entrenado con el


### HU-178 - Monitorear la salud del modelo en producción

**Para que.** Como administrador de SIGMA, seguir el desempeno del modelo mes a mes, saber cuándo hay que reentrenarlo antes de que pierda credibilidad.

*Web - Sprint 6*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Como saber que quedo bien:**

1. **Panel de desempeno** - Cuando consulto el desempeno de una versión Entonces veo por mes la cantidad de predicciones, cuántas fueron evaluadas y su clasificación Y los aciertos con intervención se contabilizan por separado
2. **Deterioro del desempeno** - Cuando la métrica actual cae por debajo de la de referencia Entonces la versión se marca como candidata a reentrenamiento
3. **Desviación de los datos** - Cuando la distribución de los datos de entrada se aleja de la del entrenamiento Entonces se informa la desviación detectada


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-173 - Sin predicciones** - Cuando no hay predicciones vigentes Entonces el panel indica cuántos equipos están siendo vigilados Y no se muestra un espacio vacío ni un mensaje de error
- **HU-177 - Registro del resultado** - Cuando registro si el evento ocurrió y en qué fecha Entonces la predicción queda evaluada Y el error respecto de la fecha estimada se calcula automáticamente
- **HU-172 - Ejecución de entrenamiento** - Cuando ejecuto un entrenamiento Entonces queda registrado su inicio, su término y sus métricas Y los entrenamientos fallidos también quedan registrados con su error

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
