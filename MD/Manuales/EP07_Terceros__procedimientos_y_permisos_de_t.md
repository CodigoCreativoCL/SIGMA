# EP-07 - Terceros, procedimientos y permisos de trabajo

> Registrar el trabajo que ejecuta un externo y la documentación que lo habilita.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Maestro de proveedores | Terceros > Proveedores > Maestro de proveedores | - | Ver proveedores y contratistas |
| Registro de permisos | Terceros > Permisos de trabajo > Registro de permisos | - | Ver permisos de trabajo |
| Vigentes y por vencer | Terceros > Permisos de trabajo > Vigentes y por vencer | - | Ver permisos de trabajo |
| Historial de servicios | Terceros > Proveedores > Historial de servicios | - | Ver proveedores y contratistas |
| Proveedor (detalle) *(se abre desde otra pantalla)* | Terceros > Proveedores > Proveedor (detalle) | - | Ver proveedores y contratistas |
| Permiso de trabajo (detalle) *(se abre desde otra pantalla)* | Terceros > Permisos de trabajo > Permiso de trabajo (detalle) | - | Ver permisos de trabajo |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver permisos de trabajo**
- **Ver proveedores y contratistas**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-060` - Administrar proveedores
- [ ] `HU-061` - Administrar procedimientos reutilizables
- [ ] `HU-063` - Registrar un permiso de trabajo con su evidencia

## 4. Paso a paso

### HU-060 - Administrar proveedores

**Para que.** Como jefe de mantenimiento, mantener el registro de las empresas que prestan servicios, poder sumar al cierre del año cuánto se gastó en cada contratista.

*Web - Sprint 3*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| RUT | Texto con máscara | Si | Dígito verificador válido. Único por cliente |
| Razón social | Texto | Si | Máximo 200 caracteres |
| Nombre de fantasía | Texto | No | Máximo 200 caracteres |
| Giro | Texto | No | Máximo 200 caracteres |
| Persona de contacto | Texto | No | Máximo 200 caracteres |
| Correo electrónico | Texto (email) | No | Formato de correo válido |
| Teléfono | Texto | No | Máximo 50 caracteres |
| Ejecuta trabajos en planta | Interruptor | No | Habilita asignarle órdenes |
| Provee repuestos | Interruptor | No | Habilita asociarlo a ingresos de bodega |

**Como saber que quedo bien:**

1. **Alta de proveedor** - Cuando registro un proveedor con su RUT y razón social Entonces puedo asignarle órdenes de trabajo y registrar servicios a su nombre Y su RUT es único dentro del cliente
2. **Clasificación del proveedor** - Cuando marco un proveedor como contratista Entonces aparece como opción al asignar la ejecución de una orden Y si solo está marcado como proveedor de repuestos no aparece en esa lista


### HU-061 - Administrar procedimientos reutilizables

**Para que.** Como planificador, escribir una sola vez un procedimiento y usarlo en muchos planes, que al mejorar la instrucción mejore en todos los lugares donde se aplica.

*Web - Sprint 3*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único por cliente y versión |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Versión | Numérico entero | Si | Mayor o igual a 1 |
| Aplica al tipo de activo | Lista desplegable | No | Del árbol de tipos |
| Descripción | Texto enriquecido | No | Sin límite |
| Duración estimada (minutos) | Numérico entero | No | Mayor que cero |
| Requiere permiso de trabajo | Interruptor | No | Desactivado por defecto |
| Tipo de permiso | Lista desplegable | No | Del catálogo de tipos de permiso |

**Como saber que quedo bien:**

1. **Alta de procedimiento** - Cuando creo el procedimiento Cambio de aceite de blower Entonces puedo referenciarlo desde cualquier actividad de plan
2. **Versión del procedimiento** - Cuando publico una versión nueva de un procedimiento Entonces las actividades que lo referencian usan la versión vigente Y las órdenes ya ejecutadas conservan el texto que tenian al momento de ejecutarse


### HU-063 - Registrar un permiso de trabajo con su evidencia

**Para que.** Como técnico o jefe de mantenimiento, adjuntar el permiso firmado que habilita el trabajo, dejar constancia de que el trabajo se ejecuto con la autorización correspondiente.

*Web y App - Sprint 3*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Tipo de permiso | Lista desplegable | Si | Del catálogo de tipos de permiso de trabajo |
| Número de permiso | Texto | No | Folio emitido por prevención. Máximo 50 caracteres |
| Vigente desde | Selector de fecha y hora | No | Sin restricción |
| Vigente hasta | Selector de fecha y hora | No | Posterior a Vigente desde |
| Fotografía del permiso firmado | Cámara o carga de archivo | Si | JPG o PDF, máximo 10 MB |
| Observación | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Registro del permiso** - Cuando registro un permiso indicando tipo, número, vigencia y fotografía del documento firmado Entonces queda asociado a la orden de trabajo Y la fotografía es obligatoria
2. **Varios permisos en una orden** - Cuando una orden requiere permiso de altura y de trabajo caliente Entonces puedo registrar ambos por separado en la misma orden
3. **Permiso vencido** - Dado un permiso cuya vigencia ya venció Cuando se intenta iniciar la ejecución de la orden Entonces se advierte que el permiso venció y se solicita uno vigente


### HU-062 - Definir los pasos de un procedimiento

**Para que.** Como planificador, detallar el procedimiento paso a paso, que el técnico sepa exactamente qué hacer y en qué orden.

*Web - Sprint 3*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Orden | Numérico entero, reordenable arrastrando | Si | Único dentro del procedimiento |
| Nombre del paso | Texto | Si | Máximo 200 caracteres |
| Instrucción | Texto enriquecido | No | Sin límite |
| Es punto de control | Interruptor | No | Desactivado por defecto |
| Requiere fotografía | Interruptor | No | Desactivado por defecto |
| Requiere medición | Interruptor | No | Desactivado por defecto |
| Variable a medir | Lista desplegable | No | Del catálogo de variables |
| Duración estimada (minutos) | Numérico entero | No | Mayor que cero |

**Como saber que quedo bien:**

1. **Alta de pasos** - Cuando agrego pasos numerados a un procedimiento Entonces al generar una orden desde ese procedimiento se crea un paso por cada uno Y el orden dentro del procedimiento es único
2. **Paso que exige medición** - Cuando marco un paso como que requiere medición e indico la variable Entonces al ejecutarlo se solicita el valor Y ese valor queda registrado en la serie histórica del activo
3. **Punto de control** - Cuando marco un paso como punto de control Entonces no se puede avanzar al paso siguiente hasta resolverlo


### HU-065 - Consultar el historial de servicios de un proveedor

**Para que.** Como jefe de mantenimiento, ver todo lo que se le ha contratado a un proveedor, negociar con datos y saber cuánto representa cada contratista en el gasto.

*Web - Sprint 3*

**Como saber que quedo bien:**

1. **Historial del proveedor** - Cuando consulto un proveedor Entonces veo las órdenes en que participó, los servicios facturados y el monto acumulado Y puedo filtrar por rango de fechas
2. **Totales por moneda** - Dado que hay servicios registrados en pesos y en unidades de fomento Entonces el total se presenta separado por moneda Y no se suman montos de monedas distintas


### HU-064 - Consultar permisos vigentes y por vencer

**Para que.** Como jefe de mantenimiento, ver qué permisos están vigentes y cuáles están por vencer, no descubrir en terreno que el permiso caducó.

*Web - Sprint 3*

**Como saber que quedo bien:**

1. **Listado de permisos** - Cuando abro la consulta de permisos Entonces veo los permisos vigentes ordenados por fecha de vencimiento Y los que vencen dentro de 48 horas aparecen destacados
2. **Filtro por orden** - Cuando filtro por una orden de trabajo Entonces veo todos los permisos asociados a esa orden


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-063 - Permiso vencido** - Dado un permiso cuya vigencia ya venció Cuando se intenta iniciar la ejecución de la orden Entonces se advierte que el permiso venció y se solicita uno vigente

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
