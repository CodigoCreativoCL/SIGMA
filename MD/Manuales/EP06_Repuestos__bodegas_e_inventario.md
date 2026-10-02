# EP-06 - Repuestos, bodegas e inventario

> Saber qué repuestos hay, dónde están, cuántos quedan y cuánto duran.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Bodegas | Inventario > Bodegas | - | Ver bodegas y ubicaciones |
| Tipos de repuesto | Inventario > Tipos de repuesto | - | Ver el maestro de repuestos |
| Centro de repuestos | Inventario > Centro de repuestos | Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos | Ver el maestro de repuestos |
| Repuestos *(se abre desde otra pantalla)* | Inventario > Repuestos | - | Ver el maestro de repuestos |
| Existencias *(se abre desde otra pantalla)* | Inventario > Existencias | - | Ver existencias de bodega |
| Movimientos *(se abre desde otra pantalla)* | Inventario > Movimientos | - | Definir mínimo y máximo de stock |
| Repuesto (detalle) *(se abre desde otra pantalla)* | Inventario > Repuesto (detalle) | Datos / Stock mín. y máx. / Lotes | Ver el maestro de repuestos |
| Bodega (detalle) *(se abre desde otra pantalla)* | Inventario > Bodega (detalle) | Datos / Ubicaciones | Ver bodegas y ubicaciones |
| Existencia (detalle) *(se abre desde otra pantalla)* | Inventario > Existencia (detalle) | Dónde está / Por estante y lote / Últimos movimientos | Ver existencias de bodega |
| Movimiento (detalle) *(se abre desde otra pantalla)* | Inventario > Movimiento (detalle) | - | Definir mínimo y máximo de stock |
| Carga masiva de repuestos *(se abre desde otra pantalla)* | Inventario > Carga masiva de repuestos | - | Crear y editar repuestos |
| Compatibilidades *(se abre desde otra pantalla)* | Inventario > Compatibilidades | - | Ver el maestro de repuestos |
| Compatibilidad (detalle) *(se abre desde otra pantalla)* | Inventario > Compatibilidad (detalle) | - | Ver el maestro de repuestos |
| Tipo de repuesto (detalle) *(se abre desde otra pantalla)* | Inventario > Tipo de repuesto (detalle) | - | Crear y editar repuestos |
| Vida útil de repuestos *(se abre desde otra pantalla)* | Inventario > Vida útil de repuestos | - | Ver el maestro de repuestos |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Crear y editar repuestos**
- **Definir mínimo y máximo de stock**
- **Ver bodegas y ubicaciones**
- **Ver el maestro de repuestos**
- **Ver existencias de bodega**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-011` - Administrar las plantas del cliente
- [ ] `HU-050` - Administrar el maestro de repuestos
- [ ] `HU-052` - Administrar bodegas y ubicaciones
- [ ] `HU-053` - Definir el stock mínimo y máximo de un repuesto
- [ ] `HU-054` - Registrar el ingreso de repuestos a bodega
- [ ] `HU-055` - Entregar repuestos contra una orden de trabajo
- [ ] `HU-056` - Consultar la existencia de un repuesto
- [ ] `HU-059` - Saber en qué estante y de qué lote está cada repuesto
- [ ] `HU-066` - Identificar bodegas, ubicaciones y repuestos con etiquetas QR

## 4. Paso a paso

### HU-053 - Definir el stock mínimo y máximo de un repuesto

**Para que.** Como bodeguero, establecer los umbrales de existencia de cada repuesto por bodega, que el sistema avise antes de quedarme sin una pieza crítica.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Repuesto | Lista desplegable con buscador | Si | Repuestos del cliente |
| Bodega | Lista desplegable | Si | Bodegas del cliente |
| Stock mínimo | Numérico decimal | Si | Mayor o igual a cero |
| Stock máximo | Numérico decimal | Si | Mayor o igual al mínimo |
| Punto de pedido | Numérico decimal | No | Entre el mínimo y el máximo |

**Como saber que quedo bien:**

1. **Definición de umbrales** - Cuando defino mínimo 4 y máximo 12 para un repuesto en una bodega Entonces esos umbrales se aplican solo a esa bodega Y el máximo no puede ser menor que el mínimo
2. **Alerta de stock mínimo** - Dado un repuesto con mínimo 4 y existencia 5 Cuando una orden consume 2 unidades Entonces la existencia queda en 3 y se genera una alerta de stock mínimo Y la alerta no genera una orden de compra por si sola
3. **Alerta de stock máximo** - Cuando la existencia supera el máximo definido Entonces se genera una alerta de stock máximo


### HU-055 - Entregar repuestos contra una orden de trabajo

**Para que.** Como bodeguero, entregar repuestos asociándolos a la orden que los consume, saber cuánto costo de repuestos tuvo cada intervención.

*Web y App - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Orden de trabajo | Lista desplegable con buscador por correlativo | Si | Órdenes abiertas o en ejecución |
| Repuesto | Lista desplegable con buscador | Si | Repuestos con existencia disponible |
| Bodega de origen | Lista desplegable | Si | Bodegas con existencia del repuesto |
| Cantidad entregada | Numérico decimal | Si | Mayor que cero y menor o igual a la existencia |
| Lote | Lista desplegable dependiente del repuesto | No | Lotes con existencia |
| Retira | Lista desplegable de usuarios | Si | Usuarios habilitados del cliente |

**Como saber que quedo bien:**

1. **Entrega asociada a una orden** - Cuando entrego un repuesto indicando la orden de trabajo Entonces la existencia disminuye Y el consumo queda registrado en la orden con su costo
2. **Existencia insuficiente** - Cuando intento entregar más unidades de las disponibles Entonces la operación es rechazada indicando la existencia actual Y se ofrece registrar una entrega parcial
3. **Devolución** - Cuando registro la devolución de un repuesto no utilizado Entonces la existencia aumenta Y la cantidad consumida de la orden se reduce en la misma cifra


### HU-050 - Administrar el maestro de repuestos

**Para que.** Como bodeguero, mantener el catálogo de repuestos de la planta, que todos nombren la misma pieza de la misma forma.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código interno | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Código del fabricante | Texto | No | Máximo 100 caracteres |
| Fabricante | Texto | No | Máximo 200 caracteres |
| Unidad de medida | Lista desplegable | Si | Unidad, litro, metro, kilogramo |
| Categoría | Lista desplegable | No | Del catálogo de categorías de repuesto |
| Criticidad | Lista desplegable | No | Del catálogo de niveles de criticidad |
| Costo de referencia | Numérico decimal | No | Mayor o igual a cero |
| Moneda | Lista desplegable | No | Por defecto la moneda del cliente |
| Controla lote | Interruptor | No | Desactivado por defecto |
| Fotografía | Carga de imagen | No | JPG o PNG, máximo 2 MB |

**Como saber que quedo bien:**

1. **Alta de repuesto** - Cuando registro un repuesto con código, nombre y unidad de medida Entonces queda disponible para planes, órdenes e inventario Y su código es único dentro del cliente
2. **Código de fabricante** - Cuando registro el código del fabricante Entonces puedo buscar el repuesto tanto por el código interno como por el del fabricante


### HU-056 - Consultar la existencia de un repuesto

**Para que.** Como usuario de mantenimiento, saber cuántas unidades hay y dónde están, no detener un trabajo por ir a buscar una pieza que no está.

*Web y App - Sprint 3*

**Donde se hace:** Centro de repuestos > pestana **Existencias**

**Como saber que quedo bien:**

1. **Consulta por repuesto** - Cuando consulto un repuesto Entonces veo la existencia por bodega, su ubicación y sus umbrales Y se destaca la bodega cuya existencia está bajo el mínimo
2. **Consulta sin conexión** - Dado que estoy en la aplicación móvil sin señal Entonces veo la existencia de la última sincronización Y se indica que el dato puede no estar actualizado


### HU-054 - Registrar el ingreso de repuestos a bodega

**Para que.** Como bodeguero, registrar la recepción de repuestos con su lote y documento, que la existencia del sistema coincida con la de la estantería.

*Web y App - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Bodega | Lista desplegable | Si | Bodegas del cliente |
| Ubicación | Lista desplegable dependiente de la bodega | No | Ubicaciones de la bodega |
| Repuesto | Lista desplegable con buscador y lectura de código | Si | Repuestos del cliente |
| Cantidad | Numérico decimal | Si | Mayor que cero |
| Número de lote | Texto | No | Máximo 100 caracteres |
| Vencimiento del lote | Selector de fecha | No | Posterior a la fecha actual |
| Proveedor | Lista desplegable | No | Proveedores del cliente |
| Documento de referencia | Texto | No | Número de guía, factura u orden de compra |
| Costo unitario | Numérico decimal | No | Mayor o igual a cero |
| Fecha de ingreso | Selector de fecha y hora | Si | Por defecto el momento actual |

**Como saber que quedo bien:**

1. **Ingreso simple** - Cuando registro el ingreso de 10 unidades de un repuesto Entonces la existencia de esa bodega aumenta en 10 Y se genera un movimiento de inventario de tipo ingreso
2. **Ingreso con lote** - Dado un repuesto que controla lote Cuando registro el ingreso Entonces se exige el número de lote Y el consumo posterior descuenta del lote indicado


### HU-051 - Definir la compatibilidad de un repuesto

**Para que.** Como planificador, indicar en qué equipos o modelos aplica cada repuesto, que el técnico no monte una pieza que no corresponde.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Repuesto | Lista desplegable con buscador | Si | Repuestos del cliente |
| Aplica a | Botones de opción: Tipo de activo / Modelo / Activo específico | Si | Determina el nivel de compatibilidad |
| Objetivo | Lista desplegable dependiente del alcance | Si | Tipo, modelo o activo según corresponda |
| Cantidad habitual | Numérico decimal | No | Mayor que cero |
| Observación | Texto | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Compatibilidad por modelo** - Cuando declaro que un filtro es compatible con el modelo GM10S Entonces al consumir repuestos en un blower de ese modelo aparece entre los sugeridos
2. **Repuesto no compatible** - Cuando selecciono un repuesto no declarado como compatible con el activo Entonces se advierte y se permite continuar registrando el motivo


### HU-052 - Administrar bodegas y ubicaciones

**Para que.** Como bodeguero, definir las bodegas y sus ubicaciones internas, saber en qué estante está el repuesto y no solo que existe.

*Web - Sprint 3*

**Donde se hace:** Bodega (detalle) > pestana **Ubicaciones**

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Planta | Lista desplegable | Si | Plantas del cliente |
| Código de bodega | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Bodeguero responsable | Lista desplegable | No | Usuarios habilitados del cliente |
| Código de ubicación | Texto | Si | Único por bodega |
| Descripción de la ubicación | Texto | No | Ejemplo: Pasillo A - Estante 3 - Nivel 2 |

**Como saber que quedo bien:**

1. **Alta de bodega** - Cuando registro una bodega en una planta Entonces puedo definir sus ubicaciones y registrar existencias
2. **Ubicaciones internas** - Cuando defino la ubicación Pasillo A - Estante 3 - Nivel 2 Entonces al consultar un repuesto se indica su ubicación exacta


### HU-058 - Consultar la vida útil real de un repuesto instalado

**Para que.** Como planificador, saber cuánto duró efectivamente una pieza en una posición, ajustar la frecuencia del plan con datos y no con supuestos.

*Web - Sprint 3*

**Donde se hace:** Centro de repuestos > pestana **Vida útil**

**Como saber que quedo bien:**

1. **Vida útil de una instalación** - Dado un rodamiento instalado con horómetro 300 y retirado con horómetro 8.712 Cuando consulto su historial Entonces se muestra una vida útil de 8.412 horas Y además se muestra la vida útil en días calendario
2. **Horómetro no registrado** - Dado que la instalación no registro horómetro Entonces se muestra solo la vida útil en días Y se indica que el dato de horas no está disponible
3. **Comparación entre instalaciones** - Cuando consulto todas las instalaciones de un mismo repuesto Entonces se muestra la duración promedio, la mínima y la máxima


### HU-057 - Registrar un ajuste de inventario

**Para que.** Como bodeguero, corregir la existencia cuando el conteo físico no coincide, que el sistema refleje lo que hay realmente en la estantería.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Repuesto | Lista desplegable con buscador | Si | Repuestos del cliente |
| Bodega | Lista desplegable | Si | Bodegas del cliente |
| Existencia según el sistema | Solo lectura | No | Calculada |
| Existencia contada | Numérico decimal | Si | Mayor o igual a cero |
| Motivo del ajuste | Texto multilinea | Si | Mínimo 10 caracteres |

**Como saber que quedo bien:**

1. **Ajuste con motivo** - Cuando registro un ajuste Entonces se exige un motivo Y queda un movimiento de inventario con la diferencia, el motivo y el responsable
2. **Trazabilidad del ajuste** - Cuando consulto los movimientos de un repuesto Entonces los ajustes se distinguen de los ingresos y de los consumos


### HU-059 - Saber en qué estante y de qué lote está cada repuesto

**Para que.** Como bodeguero, que la existencia se lleve por ubicación y por lote, no solo por bodega, poder ir directo al estante y saber qué lote tomar antes de que venza.

*Web y App - Sprint 3*

**Donde se hace:** Repuesto (detalle) > pestana **Lotes**

**Como saber que quedo bien:**

1. **Ingreso con estante y lote** - Dado que la bodega tiene ubicaciones Cuando registro un ingreso sin indicar en qué estante queda Entonces se rechaza; con estante y lote, la existencia queda en ese cubo (bodega, ubicación, lote)
2. **Existencias por estante y lote** - Cuando consulto las existencias Entonces veo la cantidad desglosada por bodega, ubicación y lote, y el umbral mínimo se evalúa por bodega
3. **Reubicación dentro de la bodega** - Cuando muevo un repuesto de un estante a otro de la misma bodega Entonces la existencia cambia de ubicación con un solo movimiento (sin salida ni entrada) y queda el historial de ubicaciones
4. **Trazabilidad del lote** - Cuando consulto un lote Entonces veo cuánto ingresó, cuánto se consumió y cuánto queda, con su vencimiento


### HU-066 - Identificar bodegas, ubicaciones y repuestos con etiquetas QR

**Para que.** Como bodeguero, imprimir etiquetas con código y QR para pegar en estantes y repuestos, rotular la bodega una vez y no volver a buscar a mano lo que hay en cada sitio.

*Web - Sprint 3*

**Donde se hace:** Bodega (detalle) > pestana **Ubicaciones**

**Como saber que quedo bien:**

1. **Etiquetas de una bodega** - Cuando elijo una bodega en el centro de etiquetas e imprimo sus ubicaciones Entonces obtengo una hoja con una etiqueta por ubicación, cada una con su código y su QR
2. **Formato de papel** - Cuando cambio el formato de papel Entonces la hoja se reacomoda al formato elegido y el código se lee completo, sin recortarse
3. **Sin permiso** - Dado que no tengo el permiso IMPRIMIR ETIQUETAS Cuando entro al centro de etiquetas Entonces no se me ofrece nada para imprimir


### HU-067 - Consultar escaneando una etiqueta

**Para que.** Como bodeguero, apuntar la cámara del teléfono a una etiqueta y ver qué hay en ese lugar, consultar de pie frente al estante sin volver a la oficina.

*Web y App - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Como saber que quedo bien:**

1. **Consulta de una ubicación** - Cuando escaneo o escribo el código de una ubicación Entonces veo qué repuestos hay en ese estante, con cantidad y lote
2. **Bodega y repuesto** - Cuando el código es de una bodega o de un repuesto Entonces la misma pantalla muestra su desglose (por ubicación o por bodega)
3. **Código no reconocido** - Cuando el código no corresponde a nada del cliente Entonces se informa con claridad y no se muestra información de otro cliente


### HU-068 - Cargar y descargar el maestro de repuestos en planilla

**Para que.** Como administrador de cliente, dar de alta muchos repuestos desde un Excel y bajar los que ya existen, poner en marcha el inventario sin teclear quinientas fichas una por una.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Como saber que quedo bien:**

1. **Carga desde la plantilla** - Cuando descargo la plantilla, la completo y la cargo Entonces las filas válidas se crean; una fila mala no detiene el resto y se informa cuál falló y por qué
2. **Descarga a Excel** - Cuando descargo a Excel desde el listado Entonces bajan los repuestos que coinciden con la búsqueda


### HU-069 - Generar los códigos automáticamente

**Para que.** Como administrador de cliente, que el código de cada registro se genere solo con el prefijo de su módulo, no depender de que cada persona invente un formato distinto.

*Web - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Como saber que quedo bien:**

1. **Código generado** - Cuando creo un registro sin escribir el código Entonces el sistema lo genera con el prefijo de su módulo y el id (por ejemplo REP-44)
2. **Códigos propios y antiguos** - Dado un registro con código escrito a mano Cuando se guarda o se edita Entonces el código se conserva tal cual


### HU-077 - Que el sistema avise lo que encuentra

**Para que.** Como jefe de mantenimiento, que el sistema detecte solo los problemas de operación y me los notifique, enterarme de un quiebre de stock cuando ocurre y no cuando alguien lo reporta.

*Web y App - Sprint 3*

**Pestanas de Centro de repuestos:** Resumen / Compatibilidades / Existencias / Posiciones / Movimientos / Vida útil / Evidencia y documentos

**Como saber que quedo bien:**

1. **Quiebre de stock detectado** - Dado un repuesto con existencia bajo el mínimo Cuando corre el detector de inventario Entonces se abre una alerta de stock mínimo con su severidad (sin existencia es crítica)
2. **Sin duplicados y cierre automático** - Cuando el detector vuelve a correr sin cambios Entonces no duplica; cuando la existencia se repone Entonces la alerta se cierra sola como resuelta
3. **Aviso en la web** - Cuando hay alertas sin leer Entonces la campana muestra el contador y la bandeja las agrupa por categoría y gravedad
4. **La app recibe lo mismo** - Cuando la app consulta GET /alertas y /alertas/resumen Entonces recibe las mismas alertas y el mismo contador que la web


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-053 - Definición de umbrales** - Cuando defino mínimo 4 y máximo 12 para un repuesto en una bodega Entonces esos umbrales se aplican solo a esa bodega Y el máximo no puede ser menor que el mínimo
- **HU-055 - Existencia insuficiente** - Cuando intento entregar más unidades de las disponibles Entonces la operación es rechazada indicando la existencia actual Y se ofrece registrar una entrega parcial
- **HU-051 - Repuesto no compatible** - Cuando selecciono un repuesto no declarado como compatible con el activo Entonces se advierte y se permite continuar registrando el motivo
- **HU-059 - Ingreso con estante y lote** - Dado que la bodega tiene ubicaciones Cuando registro un ingreso sin indicar en qué estante queda Entonces se rechaza; con estante y lote, la existencia queda en ese cubo (bodega, ubicación, lote)

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
