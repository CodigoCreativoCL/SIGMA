# EP-19 - Suscripción y modelo comercial

> Sostener SIGMA como producto comercializable con múltiples clientes.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Planes | Comercial > Planes | - | Consultar los planes y sus precios vigentes |
| Suscripción | Comercial > Suscripción | - | Ver la suscripción del cliente |
| Períodos | Comercial > Períodos | - | Ver la suscripción del cliente |
| Pagos | Comercial > Pagos | - | Ver los pagos declarados y su estado |
| Suscripción (detalle) *(se abre desde otra pantalla)* | Comercial > Suscripción (detalle) | - | Ver la suscripción del cliente |
| Período (detalle) *(se abre desde otra pantalla)* | Comercial > Período (detalle) | - | Ver la suscripción del cliente |
| Pago (detalle) *(se abre desde otra pantalla)* | Comercial > Pago (detalle) | - | Declarar una transferencia con su comprobante |
| Plan (detalle) *(se abre desde otra pantalla)* | Comercial > Plan (detalle) | - | Consultar los planes y sus precios vigentes |
| Mi suscripcion *(se abre desde otra pantalla)* | Comercial > Mi suscripcion | - | Ver y renovar la suscripcion de su empresa |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Consultar los planes y sus precios vigentes**
- **Declarar una transferencia con su comprobante**
- **Ver la suscripción del cliente**
- **Ver los pagos declarados y su estado**
- **Ver y renovar la suscripcion de su empresa**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-190` - Administrar planes comerciales
- [ ] `HU-191` - Contratar o renovar una suscripción
- [ ] `HU-193` - Bloquear el acceso por suscripción vencida

## 4. Paso a paso

### HU-193 - Bloquear el acceso por suscripción vencida

**Para que.** Como administrador de SIGMA, que el sistema restrinja el acceso cuando la suscripción vence, sostener el modelo comercial sin intervenir manualmente cada cliente.

*Web y App - Sprint 2*

**Donde se hace:** Mi suscripcion

**Como se llega:** Comercial > Mi suscripcion

*La pantalla aparece sola cuando la suscripcion vence, y no deja pasar a ninguna otra.*

**Como saber que quedo bien:**

1. **Aviso anticipado** - Dado que faltan 15 días para el vencimiento Cuando cualquier usuario ingresa Entonces se muestra un aviso permanente con los días restantes Y el sistema funciona con normalidad
2. **Periodo de gracia** - Dado que la suscripción venció y el periodo de gracia sigue vigente Entonces el sistema funciona con normalidad y el aviso se intensifica
3. **Bloqueo** - Dado que vencieron la suscripción y el periodo de gracia Cuando un usuario ingresa Entonces solo puede acceder a la pantalla de renovación Y ningún dato del cliente se elimina
4. **Trabajo en curso en terreno** - Dado que la suscripción se bloquea mientras un técnico está en terreno Entonces puede terminar y sincronizar el trabajo ya iniciado Y no puede tomar trabajo nuevo Que la aplicación permita terminar lo comenzado evita que un técnico a mitad de un trabajo en altura quede sin poder registrar lo que hizo por una situación administrativa.


### HU-191 - Contratar o renovar una suscripción

**Para que.** Como administrador de SIGMA, registrar la contratación o renovación de un cliente, mantener vigente el servicio y su historial comercial.

*Web - Sprint 2*

**Donde se hace:** Mi suscripcion

**Como se llega:** Comercial > Mi suscripcion

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Cliente | Lista desplegable | Si | Clientes de la plataforma |
| Plan comercial | Lista desplegable | Si | Planes vigentes |
| Vigente desde | Selector de fecha | Si | Sin restricción |
| Vigente hasta | Selector de fecha | Si | Posterior a la fecha desde |
| Días de gracia | Numérico entero | No | Mayor o igual a cero |
| Precio acordado | Numérico decimal | Si | Se propone el del plan y puede ajustarse |

**Como saber que quedo bien:**

1. **Contratación** - Cuando registro una suscripción con su plan y vigencia Entonces el cliente queda habilitado por ese periodo Y el precio del plan queda congelado en la suscripción
2. **Renovación** - Cuando renuevo una suscripción vigente Entonces el periodo nuevo comienza al terminar el anterior Y no se generan periodos superpuestos


### HU-190 - Administrar planes comerciales

**Para que.** Como administrador de SIGMA, definir los planes que se ofrecen y que incluye cada uno, poder vender el producto con condiciones claras.

*Web - Sprint 2*

**Donde se hace:** Plan (detalle)

**Como se llega:** Comercial > Planes > se abre Plan (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único en la plataforma |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Precio | Numérico decimal | Si | Mayor o igual a cero |
| Moneda | Lista desplegable | Si | Del catálogo de monedas |
| Periodicidad de cobro | Lista desplegable: Mensual / Trimestral / Anual | Si | Del catálogo de periodicidades |
| Funcionalidades incluidas | Grilla: funcionalidad, tipo, incluida, límite | Si | El límite es obligatorio cuando el tipo declara límite |

**Como saber que quedo bien:**

1. **Alta de plan comercial** - Cuando creo un plan indicando su precio y su periodicidad Entonces queda disponible para contratarse
2. **Funcionalidades del plan** - Cuando defino que funcionalidades incluye Entonces cada una se declara como incluida o con un límite numérico Y cuando declara un límite el valor del límite es obligatorio
3. **Cambio de precio** - Cuando modifico el precio de un plan Entonces las suscripciones vigentes conservan el precio con que se contrataron


### HU-194 - Registrar el pago de una suscripción

**Para que.** Como administrador del cliente, informar el pago adjuntando el comprobante, recuperar el servicio sin depender de una gestión telefonica.

*Web - Sprint 2*

**Donde se hace:** Pago (detalle)

**Como se llega:** Comercial > Pagos > se abre Pago (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Monto pagado | Numérico decimal | Si | Mayor que cero |
| Moneda | Lista desplegable | Si | Del catálogo de monedas |
| Fecha del pago | Selector de fecha | Si | No puede ser futura |
| Número de referencia | Texto | No | Número de transferencia o documento |
| Comprobante | Carga de archivo | Si | PDF o imagen, máximo 10 MB |
| Observación | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Registro del pago** - Cuando registro un pago con su comprobante Entonces queda pendiente de validación Y el comprobante es obligatorio
2. **Validación del pago** - Cuando el administrador de SIGMA valida el pago Entonces la suscripción se reactiva y el bloqueo se levanta Y queda registrado quién validó y cuándo
3. **Pago rechazado** - Cuando el pago se rechaza Entonces se exige un motivo Y el cliente puede registrar un pago nuevo


### HU-192 - Consultar el estado de mi suscripción

**Para que.** Como administrador del cliente, ver hasta cuando tengo servicio y que incluye mi plan, gestionar la renovación antes de que el servicio se interrumpa.

*Web - Sprint 2*

**Donde se hace:** Suscripción (detalle)

**Como se llega:** Comercial > Suscripción > se abre Suscripción (detalle)

**Como saber que quedo bien:**

1. **Estado de la suscripción** - Cuando consulto mi suscripción Entonces veo el plan contratado, la vigencia, los días restantes y las funcionalidades incluidas
2. **Consumo frente a los límites** - Dado un plan con límite de activos Entonces veo cuántos activos tengo registrados respecto del límite Y se advierte cuando supero el 80 por ciento del límite


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-193 - Trabajo en curso en terreno** - Dado que la suscripción se bloquea mientras un técnico está en terreno Entonces puede terminar y sincronizar el trabajo ya iniciado Y no puede tomar trabajo nuevo Que la aplicación permita terminar lo comenzado evita que un técnico a mitad de un trabajo en altura quede sin poder registrar lo que hizo por una situación administrativa.
- **HU-190 - Funcionalidades del plan** - Cuando defino que funcionalidades incluye Entonces cada una se declara como incluida o con un límite numérico Y cuando declara un límite el valor del límite es obligatorio
- **HU-194 - Registro del pago** - Cuando registro un pago con su comprobante Entonces queda pendiente de validación Y el comprobante es obligatorio
- **HU-194 - Pago rechazado** - Cuando el pago se rechaza Entonces se exige un motivo Y el cliente puede registrar un pago nuevo
- **HU-192 - Consumo frente a los límites** - Dado un plan con límite de activos Entonces veo cuántos activos tengo registrados respecto del límite Y se advierte cuando supero el 80 por ciento del límite

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
