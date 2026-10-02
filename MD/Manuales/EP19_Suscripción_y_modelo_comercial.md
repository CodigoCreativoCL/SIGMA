# EP-19 · Suscripción y modelo comercial

> Sostener SIGMA como producto comercializable con múltiples clientes.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Planes | Comercial › Planes | Consultar los planes y sus precios vigentes |
| Suscripción | Comercial › Suscripción | Ver la suscripción del cliente |
| Períodos | Comercial › Períodos | Ver la suscripción del cliente |
| Pagos | Comercial › Pagos | Ver los pagos declarados y su estado |
| Suscripción (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Suscripción (detalle) | Ver la suscripción del cliente |
| Período (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Período (detalle) | Ver la suscripción del cliente |
| Pago (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Pago (detalle) | Declarar una transferencia con su comprobante |
| Plan (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Plan (detalle) | Consultar los planes y sus precios vigentes |
| Mi suscripcion *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Mi suscripcion | Ver y renovar la suscripcion de su empresa |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Consultar los planes y sus precios vigentes**
- **Declarar una transferencia con su comprobante**
- **Ver la suscripción del cliente**
- **Ver los pagos declarados y su estado**
- **Ver y renovar la suscripcion de su empresa**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-190` — Administrar planes comerciales
- `HU-191` — Contratar o renovar una suscripción
- `HU-193` — Bloquear el acceso por suscripción vencida


## 4. Paso a paso


### HU-193 · Bloquear el acceso por suscripción vencida

**Para qué.** Como administrador de SIGMA, que el sistema restrinja el acceso cuando la suscripción vence, sostener el modelo comercial sin intervenir manualmente cada cliente.

*Web y App · Sprint 2*

**Cómo saber que quedó bien:**

1. **Aviso anticipado** — Dado que faltan 15 días para el vencimiento Cuando cualquier usuario ingresa Entonces se muestra un aviso permanente con los días restantes Y el sistema funciona con normalidad
2. **Periodo de gracia** — Dado que la suscripción venció y el periodo de gracia sigue vigente Entonces el sistema funciona con normalidad y el aviso se intensifica
3. **Bloqueo** — Dado que vencieron la suscripción y el periodo de gracia Cuando un usuario ingresa Entonces solo puede acceder a la pantalla de renovación Y ningún dato del cliente se elimina
4. **Trabajo en curso en terreno** — Dado que la suscripción se bloquea mientras un técnico está en terreno Entonces puede terminar y sincronizar el trabajo ya iniciado Y no puede tomar trabajo nuevo Que la aplicación permita terminar lo comenzado evita que un técnico a mitad de un trabajo en altura quede sin poder registrar lo que hizo por una situación administrativa.


### HU-191 · Contratar o renovar una suscripción

**Para qué.** Como administrador de SIGMA, registrar la contratación o renovación de un cliente, mantener vigente el servicio y su historial comercial.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Cliente | Lista desplegable | Sí | Clientes de la plataforma |
| Plan comercial | Lista desplegable | Sí | Planes vigentes |
| Vigente desde | Selector de fecha | Sí | Sin restricción |
| Vigente hasta | Selector de fecha | Sí | Posterior a la fecha desde |
| Días de gracia | Numérico entero | No | Mayor o igual a cero |
| Precio acordado | Numérico decimal | Sí | Se propone el del plan y puede ajustarse |

**Cómo saber que quedó bien:**

1. **Contratación** — Cuando registro una suscripción con su plan y vigencia Entonces el cliente queda habilitado por ese periodo Y el precio del plan queda congelado en la suscripción
2. **Renovación** — Cuando renuevo una suscripción vigente Entonces el periodo nuevo comienza al terminar el anterior Y no se generan periodos superpuestos


### HU-190 · Administrar planes comerciales

**Para qué.** Como administrador de SIGMA, definir los planes que se ofrecen y que incluye cada uno, poder vender el producto con condiciones claras.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código | Texto | Sí | Único en la plataforma |
| Nombre | Texto | Sí | Máximo 200 caracteres |
| Precio | Numérico decimal | Sí | Mayor o igual a cero |
| Moneda | Lista desplegable | Sí | Del catálogo de monedas |
| Periodicidad de cobro | Lista desplegable: Mensual / Trimestral / Anual | Sí | Del catálogo de periodicidades |
| Funcionalidades incluidas | Grilla: funcionalidad, tipo, incluida, límite | Sí | El límite es obligatorio cuando el tipo declara límite |

**Cómo saber que quedó bien:**

1. **Alta de plan comercial** — Cuando creo un plan indicando su precio y su periodicidad Entonces queda disponible para contratarse
2. **Funcionalidades del plan** — Cuando defino que funcionalidades incluye Entonces cada una se declara como incluida o con un límite numérico Y cuando declara un límite el valor del límite es obligatorio
3. **Cambio de precio** — Cuando modifico el precio de un plan Entonces las suscripciones vigentes conservan el precio con que se contrataron


### HU-194 · Registrar el pago de una suscripción

**Para qué.** Como administrador del cliente, informar el pago adjuntando el comprobante, recuperar el servicio sin depender de una gestión telefonica.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Monto pagado | Numérico decimal | Sí | Mayor que cero |
| Moneda | Lista desplegable | Sí | Del catálogo de monedas |
| Fecha del pago | Selector de fecha | Sí | No puede ser futura |
| Número de referencia | Texto | No | Número de transferencia o documento |
| Comprobante | Carga de archivo | Sí | PDF o imagen, máximo 10 MB |
| Observación | Texto multilinea | No | Máximo 500 caracteres |

**Cómo saber que quedó bien:**

1. **Registro del pago** — Cuando registro un pago con su comprobante Entonces queda pendiente de validación Y el comprobante es obligatorio
2. **Validación del pago** — Cuando el administrador de SIGMA valida el pago Entonces la suscripción se reactiva y el bloqueo se levanta Y queda registrado quién validó y cuándo
3. **Pago rechazado** — Cuando el pago se rechaza Entonces se exige un motivo Y el cliente puede registrar un pago nuevo


### HU-192 · Consultar el estado de mi suscripción

**Para qué.** Como administrador del cliente, ver hasta cuando tengo servicio y que incluye mi plan, gestionar la renovación antes de que el servicio se interrumpa.

*Web · Sprint 2*

**Cómo saber que quedó bien:**

1. **Estado de la suscripción** — Cuando consulto mi suscripción Entonces veo el plan contratado, la vigencia, los días restantes y las funcionalidades incluidas
2. **Consumo frente a los límites** — Dado un plan con límite de activos Entonces veo cuántos activos tengo registrados respecto del límite Y se advierte cuando supero el 80 por ciento del límite


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-193 · Trabajo en curso en terreno** — Dado que la suscripción se bloquea mientras un técnico está en terreno Entonces puede terminar y sincronizar el trabajo ya iniciado Y no puede tomar trabajo nuevo Que la aplicación permita terminar lo comenzado evita que un técnico a mitad de un trabajo en altura quede sin poder registrar lo que hizo por una situación administrativa.
- **HU-190 · Funcionalidades del plan** — Cuando defino que funcionalidades incluye Entonces cada una se declara como incluida o con un límite numérico Y cuando declara un límite el valor del límite es obligatorio
- **HU-194 · Registro del pago** — Cuando registro un pago con su comprobante Entonces queda pendiente de validación Y el comprobante es obligatorio
- **HU-194 · Pago rechazado** — Cuando el pago se rechaza Entonces se exige un motivo Y el cliente puede registrar un pago nuevo
- **HU-192 · Consumo frente a los límites** — Dado un plan con límite de activos Entonces veo cuántos activos tengo registrados respecto del límite Y se advierte cuando supero el 80 por ciento del límite


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
