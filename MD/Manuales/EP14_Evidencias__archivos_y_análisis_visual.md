# EP-14 - Evidencias, archivos y análisis visual

> Que la fotografía tomada en terreno llegue al sistema y sirva de respaldo.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Componentes | Componentes | - | Ver los componentes de los activos |
| Escanear | Utilidades > Escanear | - | Ver existencias de bodega |
| Ver documento adjunto *(se abre desde otra pantalla)* | Cliente > Ver documento adjunto | - | Ver existencias de bodega |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver existencias de bodega**
- **Ver los componentes de los activos**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-140` - Adjuntar evidencias desde terreno

## 4. Paso a paso

### HU-140 - Adjuntar evidencias desde terreno

**Para que.** Como técnico de mantenimiento, tomar fotografías y adjuntarlas al trabajo que estoy haciendo, respaldar lo que hice sin depender de mi palabra.

*App y Web - Sprint 6*

**Donde se hace:** No tiene pantalla propia: se adjunta desde la orden de trabajo, la pauta o la falla en la que se esta trabajando.

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tomar fotografía | Cámara del dispositivo | No | JPG, máximo 4 MB por imagen |
| Adjuntar archivo | Selector de archivo | No | JPG, PNG, PDF, MP4. Máximo 20 MB |
| Título | Texto | No | Máximo 200 caracteres |
| Descripción | Texto multilinea con dictado | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Captura y adjunto** - Cuando tomo una fotografía desde la aplicación Entonces queda asociada al elemento desde el cual la tomé Y se registra la fecha, la hora y la ubicación de la captura
2. **Adjunto sin conexión** - Dado que estoy sin señal Entonces la fotografía queda en la cola de envío del dispositivo Y se indica cuántos archivos están pendientes de subir
3. **Archivo pendiente de revisión** - Cuando un archivo se sube al servidor Entonces queda en estado pendiente de revisión de seguridad Y no se muestra a otros usuarios hasta que la revisión concluye


### HU-141 - Cargar archivos con red intermitente

**Para que.** Como técnico de mantenimiento, que la subida de una fotografía se retome donde se cortó, no perder la evidencia por trabajar en un sector sin cobertura.

*App - Sprint 6*

**Donde se hace:** No tiene pantalla: la aplicacion reintenta la subida sola cuando vuelve la senal.

**Como saber que quedo bien:**

1. **Reanudación de la carga** - Dado que la carga de una fotografía se interrumpe al 60 por ciento Cuando se recupera la conexión Entonces la carga se retoma desde el 60 por ciento y no desde el inicio
2. **Cola de envío** - Cuando tengo varios archivos pendientes Entonces se suben en orden y veo el progreso de cada uno Y puedo cancelar uno sin afectar a los demás
3. **Verificación de integridad** - Cuando la carga finaliza Entonces el servidor verifica que el archivo recibido corresponde al enviado Y si no coincide la carga se reintenta automáticamente


### HU-142 - Consultar la galería de evidencias

**Para que.** Como usuario de mantenimiento, ver todas las fotografías asociadas a una orden o a un equipo, entender el estado del equipo antes de intervenirlo.

*Web y App - Sprint 5*

**Donde se hace:** Ver documento adjunto

**Como se llega:** Cliente > Ver documento adjunto

*Se abre al pulsar un adjunto, desde cualquier pantalla que los tenga.*

**Como saber que quedo bien:**

1. **Galería de una orden** - Cuando abro la galería de una orden Entonces veo sus fotografías agrupadas por paso y por momento Y puedo ampliarlas y descargarlas
2. **Galería de un equipo** - Cuando abro la galería de un activo Entonces veo las fotografías de todas sus órdenes ordenadas por fecha


### HU-143 - Definir imágenes de referencia

**Para que.** Como planificador, adjuntar la fotografía de como debe quedar un trabajo, que el técnico compare contra un estándar y no contra su criterio.

*Web - Sprint 5*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Como saber que quedo bien:**

1. **Imagen de referencia en una actividad** - Cuando adjunto una imagen de referencia a una actividad del plan Entonces el técnico la ve al ejecutar el paso correspondiente Y se presenta claramente identificada como referencia y no como evidencia
2. **Imagen de referencia en un ítem de checklist** - Cuando adjunto una imagen de referencia a un ítem Entonces se muestra junto a la pregunta durante la ejecución
3. **Distinción en la galería** - Cuando abro la galería Entonces las imágenes de referencia se muestran separadas de las evidencias de ejecución Sin esa distinción, la aplicación mezcla la fotografía modelo con la del terreno y el técnico no sabe cuál está mirando.


### HU-144 - Revisar las detecciones del análisis visual

**Para que.** Como planificador, revisar lo que el análisis automático encontró en las fotografías, aprovechar las imágenes que ya se capturan sin tener que mirarlas todas.

*Web - Sprint 6*

**Donde se hace:** Experimentos

**Como se llega:** SIGMA AI > Experimentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Resultado de la revisión | Botones de opción: Confirmada / Rechazada | Si | Una única selección |
| Observación | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Cola de análisis** - Cuando una fotografía se sube Entonces entra en la cola de análisis visual Y se procesa según la prioridad definida
2. **Detecciones sobre la imagen** - Cuando abro el resultado del análisis Entonces veo la imagen con las zonas detectadas marcadas y su etiqueta y confianza
3. **Confirmar o rechazar** - Cuando confirmo o rechazo una detección Entonces la decisión queda registrada con mi nombre y fecha Y esa decisión se incorpora al conjunto de datos de entrenamiento
4. **Detección no revisada** - Dado que nadie ha revisado una detección Entonces se presenta como pendiente y no como confirmada


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
