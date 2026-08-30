# SIGMA — Anexo F (normativo): modelo comercial, suscripción y renovación

Planes, precios en UF, clave de suscripción, bloqueo por vencimiento y renovación con comprobante.

Complementa el modelo v2 y los anexos A a E. Base: `db_acd593_sigma` · sin datos.

---

## 1. Qué resuelve este anexo

Hasta aquí SIGMA era un producto. Este anexo lo convierte en un **negocio**: quién paga, cuánto, cada cuánto, qué recibe a cambio, y qué pasa cuando deja de pagar.

Cinco requisitos, y cada uno tiene una trampa:

| Requisito | La trampa |
|---|---|
| Cobrar en UF, con precios que yo ajusto | Si cambio el precio hoy, **no puede cambiar retroactivamente** lo que ya se facturó |
| Clave única por cliente, que no cambia al renovar | Una clave permanente es una credencial permanente: **hay que poder revocarla** si se filtra |
| Bloquear web y app al vencer | El técnico trabaja sin señal. **Bloquear mal le hace perder el trabajo del día** |
| Renovar con comprobante de transferencia | Las transferencias llegan con montos que no calzan exactamente |
| La API valida la clave en cada llamada | Consultar la base en cada request no escala |

---

## 2. Los tres planes

### 2.1 La lógica del corte

Los planes no cortan features al azar. Siguen **la curva de madurez de los datos del cliente**, que es lo que hace que el upgrade se venda solo:

```text
Mes 1        El cliente no tiene NADA cargado.
             Necesita: activos, checklist, tareas, OT, calendario.
             -> BASICO

Mes 3-6      Ya tiene tecnicos en terreno y se da cuenta de que
             teclear con guantes no funciona. Empieza a llevar
             horometros. Quiere subir su Excel historico.
             -> MEDIO

Mes 12+      Tiene 12 meses de mediciones, fallas y cambios de
             repuesto. Recien AHORA se puede entrenar algo.
             -> FULL
```

> **Por qué el predictivo va en FULL y no antes.** Un modelo necesita historial: series de medición, fallas confirmadas y vidas útiles reales. Vender predicción a un cliente del mes uno es vender humo — no hay con qué entrenar. Ponerlo en el plan alto no es una barrera artificial, es **honestidad sobre cuándo funciona**, y de paso convierte el segundo año en una renovación al alza natural.

### 2.2 La propuesta

Precios de partida en UF mensual. **Son parámetros**: viven en `Plan_Comercial_Precio` y se ajustan cuando quieras sin tocar código ni afectar lo ya facturado (§4).

| | **BASICO** | **MEDIO** | **FULL** |
|---|:--:|:--:|:--:|
| **UF / mes** | **9** | **22** | **45** |
| Trimestral (−5 %) | 25,7 | 62,7 | 128,3 |
| Anual (−17 %, 2 meses libres) | 90 | 220 | 450 |
| Plantas | 1 | 3 | ilimitadas |
| Usuarios | 5 | 25 | ilimitados |
| Activos | 150 | 750 | ilimitados |
| Almacenamiento | 5 GB | 50 GB | 500 GB |
| | | | |
| Gestión de activos y componentes | ● | ● | ● |
| Checklist dinámico | ● | ● | ● |
| Tareas | ● | ● | ● |
| Órdenes de trabajo | ● | ● | ● |
| Planes de mantenimiento | ● | ● | ● |
| Programación por calendario | ● | ● | ● |
| Evidencia fotográfica | ● | ● | ● |
| **Programación por horómetro** | — | ● | ● |
| **Bitácora del técnico** | — | ● | ● |
| **Registro de maestros en terreno** | — | ● | ● |
| **Creación y dictado por voz** | — | ● | ● |
| **Lectura por voz e inclusión** | — | ● | ● |
| **Importación desde Excel** | — | ● | ● |
| **Inventario de repuestos** | — | ● | ● |
| **Proveedores y servicios externos** | — | ● | ● |
| **Permisos de trabajo** | — | ● | ● |
| **Análisis visual de fotografías** | — | — | ● |
| **Predicción de fallas** | — | — | ● |
| **Vida útil restante** | — | — | ● |
| **API para integración** | — | — | ● |
| **Indicadores avanzados** | — | — | ● |

**Implantación:** UF 25 por única vez — carga inicial de activos, configuración de catálogos del cliente y capacitación. Se cobra como un período aparte y es lo que financia el trabajo real de poner en marcha a un cliente nuevo.

### 2.3 Por qué la voz está en MEDIO

Tres razones que conviene tener a mano al vender:

1. **Tiene costo variable real.** Azure Speech se paga por minuto reconocido. Regalarlo en el plan de entrada convierte al cliente más barato en el más caro.
2. **Es el diferenciador que justifica el salto.** Un cliente con cuadrillas en planta lo pide apenas ve la demo. Es la razón concreta para pasar de 9 a 22 UF.
3. **No es imprescindible para operar.** El BASICO funciona completo sin voz. No se está mutilando el plan de entrada, se está reservando la comodidad.

>  **Decisión tomada (ver Anexo E §9.3 y Anexo G §4.3): `LECTURA POR VOZ` está incluida en TODOS los planes, incluido el BÁSICO.**
>
> Cuando la voz corría en la nube había un argumento de costo para dejarla fuera del plan barato. Al pasar toda la voz al motor del teléfono, ese argumento desapareció: leer en voz alta no cuesta nada. Lo único que quedaría es cobrarle el acceso a alguien que no sabe leer, y eso no se sostiene.
>
> Lo que sí sigue siendo de MEDIO en adelante es `CREACION POR VOZ` — dictar con las manos ocupadas es productividad, y la productividad se cobra.

---

## 3. Cómo se modela el plan

### 3.1 `Plan_Comercial` (`plc`)

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `plc_codigo` | `NVARCHAR(50)` | NO | `BASICO` · `MEDIO` · `FULL` — UX |
| `plc_nombre` | `NVARCHAR(100)` | NO | lo que ve el cliente |
| `plc_descripcion` | `NVARCHAR(500)` | SÍ | |
| `plc_orden` | `INT` | NO | 1, 2, 3 — para ordenar la comparativa y saber qué es upgrade |
| `plc_dias_gracia` | `INT` | NO | DF 5 — días que sigue funcionando después de vencer |
| `plc_publico` | `BIT` | NO | DF 1 — un plan a medida para un cliente grande se marca 0 |
| AUD-M | | | |

`plc_orden` no es cosmético: es lo que permite que el sistema sepa que pasar de MEDIO a FULL es **upgrade** (cobro inmediato prorrateado) y de FULL a MEDIO es **downgrade** (efectivo al cierre del período).

### 3.2 `Plan_Comercial_Funcionalidad` (`pcf`)

Qué incluye cada plan, y con qué tope.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `pcf_plan_comercial` | `INT` | NO | |
| `pcf_funcionalidad` | `INT` | NO | FK `Funcionalidad` — 25 valores, ver Anexo B |
| `pcf_incluida` | `BIT` | NO | DF 1 |
| `pcf_limite` | `DECIMAL(18,2)` | SÍ | **NULL = sin tope**. Solo aplica si la funcionalidad es de tipo `LIMITE` |
| `pcf_cliente` | `INT` | SÍ | **NULL = regla del plan. Con valor = excepción para ese cliente** |
| AUD-M | | | `UX_PCF_PLAN_FUNCIONALIDAD_CLIENTE` |

**`pcf_cliente` es la columna que hace vendible el modelo.** Sin ella, cada trato especial obliga a crear un plan nuevo, y a los seis meses hay catorce planes casi iguales. Con ella:

- un cliente del BASICO que necesita `CREACION POR VOZ` sin cambiar de plan → una fila de excepción;
- un cliente del MEDIO que negoció 40 usuarios en vez de 25 → una fila con `pcf_limite = 40`;
- una prueba de `ANALISIS PREDICTIVO` por dos meses → una fila que después se deshabilita.

La resolución es: **la excepción del cliente gana sobre la regla del plan**. Mismo patrón que los permisos por usuario del Anexo D, y por la misma razón.

### 3.3 `Plan_Comercial_Precio` (`pcp`) — el precio es versionado

Esta es la tabla que resuelve la primera trampa.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `pcp_plan_comercial` | `INT` | NO | |
| `pcp_periodicidad_cobro` | `INT` | NO | MENSUAL / TRIMESTRAL / ANUAL |
| `pcp_valor_uf` | `DECIMAL(18,4)` | NO | precio del período completo, en UF |
| `pcp_vigencia_desde` | `DATE` | NO | |
| `pcp_vigencia_hasta` | `DATE` | SÍ | NULL = vigente |
| `pcp_descuento_porcentaje` | `DECIMAL(18,2)` | SÍ | informativo, para mostrar «ahorra 17 %» |
| AUD-M | | | |

Reglas:

1. **Nunca se hace `UPDATE` de un precio.** Subir el valor es cerrar la fila vigente con `vigencia_hasta` e insertar una nueva. El histórico queda intacto.
2. **Si no existe fila para (plan, periodicidad), esa combinación no se vende.** No hace falta una columna «permite anual»: la ausencia de precio es la regla. Un plan BASICO que solo se venda mensual simplemente no tiene fila trimestral ni anual.
3. El precio que se aplica a un período es el vigente **el día de emisión**, y queda congelado ahí (§5.2).

```sql
-- Subir el MEDIO de 22 a 24 UF a partir del 1 de enero
UPDATE Plan_Comercial_Precio
   SET pcp_vigencia_hasta = '2026-12-31'
 WHERE pcp_plan_comercial = 2 AND pcp_periodicidad_cobro = 1 AND pcp_vigencia_hasta IS NULL

INSERT Plan_Comercial_Precio (..., pcp_valor_uf, pcp_vigencia_desde) VALUES (..., 24, '2027-01-01')
```

Los clientes con período ya emitido siguen pagando 22 hasta que ese período cierre. Es lo correcto contable y comercialmente.

---

## 4. La UF: por qué va en SQL y no en JavaScript

Me pediste analizarlo. La respuesta corta es **almacenada en SQL, alimentada por un job del servidor**. Nunca calculada en el navegador.

### 4.1 Por qué el JS del navegador es el lugar equivocado

| Problema | Consecuencia |
|---|---|
| **El cliente controla el navegador** | Si el monto en pesos se calcula con un valor de UF que llega desde el front, se puede alterar antes de enviarlo. El monto a cobrar no puede depender de datos que envía quien paga |
| **Flutter no tiene navegador** | La app necesita saber si la suscripción está vigente. No puede depender de un `fetch` de una página |
| **Sin conexión no hay UF** | El técnico trabaja sin señal; y si la API externa se cae un martes, no se puede emitir ni cobrar nada |
| **No queda rastro** | Una consulta desde el navegador no deja constancia de con qué valor se cobró |

### 4.2 `Valor_Uf` (`vuf`)

Una fila por día. Append-only.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `vuf_fecha` | `DATE` | NO | **UX** — una sola fila por día |
| `vuf_valor` | `DECIMAL(18,4)` | NO | pesos por UF |
| `vuf_uf_origen` | `INT` | NO | SII / API EXTERNA / MANUAL / **ARRASTRE** |
| `vuf_fecha_obtencion_utc` | `DATETIME` | NO | cuándo se consultó |
| `vuf_respuesta_cruda` | `NVARCHAR(500)` | SÍ | lo que devolvió la fuente, para auditar |
| AUD-A | | | |

**El job diario** corre en el servidor, consulta la fuente y escribe. Detalle que importa: en Chile la UF se publica **con anticipación** — el valor de cada día entre el 10 de un mes y el 9 del siguiente se conoce al comienzo de esa ventana. Así que el job puede traer el mes completo por adelantado, y una renovación programada se puede cotizar antes de que llegue el día.

**Si la fuente falla**, el job no bloquea nada: escribe el último valor conocido con `vuf_uf_origen = ARRASTRE`. Queda marcado, se puede corregir después, y nadie se queda sin poder renovar porque un servicio externo estaba caído. Una alerta avisa que se está arrastrando.

### 4.3 La regla que no se puede romper

> **El valor de UF usado en una transacción se congela en la transacción.**

`Suscripcion_Periodo` guarda `spe_valor_uf` como número, **no** una FK a `Valor_Uf`. Si guardáramos la referencia, abrir un comprobante de hace dos años recalcularía con la UF de hoy y mostraría un monto que nadie pagó nunca.

Es exactamente el mismo principio que ya aplicamos tres veces en este modelo: el valor canónico de una medición, la versión publicada de un plan y la versión congelada de un checklist. **Lo que se usó para decidir algo se guarda tal como estaba.**

---

## 5. Suscripción, clave y períodos

### 5.1 `Suscripcion` (`sus`) — una por cliente, para siempre

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `sus_cliente` | `INT` | NO | **UX** — una suscripción por cliente |
| `sus_key_prefijo` | `NVARCHAR(20)` | NO | `SIGMA-K7M2Q` — la parte visible, para soporte |
| `sus_key_hash` | `VARBINARY(32)` | NO | **UX** — SHA-256 de la clave completa |
| `sus_suscripcion_estado` | `INT` | NO | ACTIVA / SUSPENDIDA / CANCELADA |
| `sus_plan_comercial` | `INT` | SÍ | plan vigente, denormalizado del período actual |
| `sus_fecha_inicio` | `DATE` | NO | |
| `sus_fecha_fin` | `DATE` | SÍ | **se mueve con cada renovación** |
| `sus_dias_gracia` | `INT` | NO | DF 5 — copiado del plan, ajustable por cliente |
| `sus_fecha_emision_key_utc` | `DATETIME` | NO | |
| `sus_contacto_nombre` / `_email` / `_telefono` | | SÍ | a quién se le avisa del vencimiento |
| AUD-M | | | |

**La clave se guarda con hash, como una contraseña.** No se puede recuperar, solo reemitir. Eso es deliberado: es una credencial que da acceso a todos los datos del cliente, y una tabla con claves en texto plano es una filtración esperando ocurrir.

Formato: `SIGMA-XXXXX-XXXXX-XXXXX-XXXXX`, 20 caracteres del alfabeto Crockford base32 (sin `I`, `L`, `O`, `U` para que no se confundan al dictarla por teléfono). ≈ 100 bits de entropía.

**Se muestra una sola vez**, al emitirla, con un aviso de guardarla. Renovar **no** la cambia. Solo cambia si se revoca por filtración o pérdida, que es un acto administrativo explícito y queda en `Suscripcion_Key_Historial` (`skh`) con motivo, usuario y fecha.

### 5.2 `Suscripcion_Periodo` (`spe`) — lo que se cobra

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `spe_suscripcion` | `INT` | NO | |
| `spe_plan_comercial` | `INT` | NO | qué plan se contrató **en este período** |
| `spe_periodicidad_cobro` | `INT` | NO | |
| `spe_fecha_inicio` / `spe_fecha_fin` | `DATE` | NO | |
| `spe_valor_uf_plan` | `DECIMAL(18,4)` | NO | precio en UF, **congelado** |
| `spe_valor_uf_dia` | `DECIMAL(18,4)` | NO | **valor de la UF del día de emisión, congelado** |
| `spe_fecha_valor_uf` | `DATE` | NO | de qué día se tomó |
| `spe_monto_clp` | `DECIMAL(18,2)` | NO | `spe_valor_uf_plan × spe_valor_uf_dia`, redondeado |
| `spe_monto_pagado_clp` | `DECIMAL(18,2)` | NO | DF 0 — suma de abonos verificados |
| `spe_suscripcion_periodo_estado` | `INT` | NO | |
| `spe_es_implantacion` | `BIT` | NO | DF 0 — el cobro por única vez |
| `spe_observacion` | `NVARCHAR(500)` | SÍ | |
| AUD-M | | | |

Cinco columnas para el monto puede parecer mucho. No lo es: **cada una responde una pregunta distinta que alguien va a hacer.** ¿Qué plan tenía? ¿Cuánto costaba en UF? ¿A cuánto estaba la UF? ¿De qué día? ¿Cuánto terminó pagando en pesos? Sin ellas, reconstruir un cobro de hace un año es imposible.

### 5.3 `Suscripcion_Pago` (`spa`) — el abono con comprobante

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `spa_suscripcion_periodo` | `INT` | NO | |
| `spa_monto_declarado_clp` | `DECIMAL(18,2)` | NO | **lo que el cliente dice que transfirió** |
| `spa_monto_verificado_clp` | `DECIMAL(18,2)` | SÍ | lo que se confirmó contra la cartola |
| `spa_fecha_transferencia` | `DATE` | NO | |
| `spa_banco` | `NVARCHAR(100)` | SÍ | |
| `spa_numero_operacion` | `NVARCHAR(50)` | SÍ | |
| `spa_archivo` | `INT` | NO | FK `Archivo` — el comprobante en Blob |
| `spa_suscripcion_pago_estado` | `INT` | NO | DECLARADO / EN REVISION / VERIFICADO / RECHAZADO |
| `spa_usuario_verificador` | `INT` | SÍ | |
| `spa_fecha_verificacion_utc` | `DATETIME` | SÍ | |
| `spa_motivo_rechazo` | `NVARCHAR(500)` | SÍ | |
| AUD-M | | | |

**Dos columnas de monto, no una.** `declarado` es lo que dice el cliente; `verificado` es lo que se comprobó. Cuando difieren, esa diferencia es el dato que hay que gestionar — y si hubiera una sola columna, se perdería en el momento de corregirla.

### 5.4 Cómo se analiza el comprobante

El período pasa a `VIGENTE` cuando la suma de abonos **verificados** cubre el monto. En tres niveles, y el primero funciona desde el día uno:

| Nivel | Cómo | Cuándo |
|---|---|---|
| **1. Manual** | Un operador abre el comprobante, lo compara con la cartola y marca `VERIFICADO` | Desde el inicio |
| **2. Asistido** | OCR sobre el comprobante extrae monto, fecha y N° de operación; el sistema los precarga y marca discrepancias. El operador confirma | Fase 2, reusando la infraestructura de `Archivo_Analisis_Visual` |
| **3. Conciliación** | Cruce automático contra la cartola bancaria por N° de operación | Cuando exista integración bancaria |

**La tolerancia importa.** Una transferencia rara vez llega por el monto exacto: comisiones, redondeos, el cliente que transfiere `450.000` en vez de `449.870`. Regla:

```sql
-- Parametro en Sys_Parametros
SUSCRIPCION_TOLERANCIA_CLP = 2000
SUSCRIPCION_TOLERANCIA_PORCENTAJE = 1.0

-- El periodo se activa si:
spe_monto_pagado_clp >= spe_monto_clp - MAX(tolerancia_clp, spe_monto_clp * tolerancia_pct / 100)
```

Un pago **de más** no se rechaza: queda como saldo a favor y se descuenta del período siguiente (`spe_observacion` y un abono negativo). Rechazar un pago por exceso es la forma más rápida de perder a un cliente.

---

## 6. Vencimiento y bloqueo

### 6.1 El estado no se guarda: se calcula

Coherente con la regla del Anexo A §3.3, que ya aplicamos a las ocurrencias:

| Estado | ¿Se guarda? | Cómo se determina |
|---|:--:|---|
| `ACTIVA` | **sí** | alguien la activó |
| `SUSPENDIDA` | **sí** | alguien la suspendió (mora, incumplimiento) |
| `CANCELADA` | **sí** | alguien la canceló |
| **`VENCIDA`** | **no** | `sus_fecha_fin < hoy` |
| **`EN GRACIA`** | **no** | `hoy` entre `sus_fecha_fin` y `sus_fecha_fin + sus_dias_gracia` |
| **`POR VENCER`** | **no** | quedan ≤ 10 días |

Si `VENCIDA` fuera un estado guardado, haría falta un job que recorra las suscripciones cada noche. El día que ese job no corre, clientes vencidos siguen operando o clientes al día quedan bloqueados. Calculado, no puede desincronizarse.

### 6.2 La función que decide

Una sola, usada por la API, por la web y por el armado del token:

```sql
CREATE OR ALTER FUNCTION [dbo].[FNC_SUSCRIPCION_VIGENTE] (@KEY_HASH VARBINARY(32))
RETURNS @R TABLE (
    CLIENTE INT, SUSCRIPCION INT, PLAN_COMERCIAL INT,
    ESTADO NVARCHAR(20),        -- VIGENTE | EN GRACIA | VENCIDA | SUSPENDIDA | CANCELADA | NO EXISTE
    FECHA_FIN DATE, DIAS_RESTANTES INT, PUEDE_OPERAR BIT
)
AS
BEGIN
    DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

    INSERT @R
    SELECT  s.sus_cliente, s.sus_id, s.sus_plan_comercial,
            CASE
                WHEN s.sus_suscripcion_estado = 3 THEN N'CANCELADA'
                WHEN s.sus_suscripcion_estado = 2 THEN N'SUSPENDIDA'
                WHEN s.sus_fecha_fin IS NULL      THEN N'VENCIDA'
                WHEN s.sus_fecha_fin >= @HOY      THEN N'VIGENTE'
                WHEN DATEADD(DAY, s.sus_dias_gracia, s.sus_fecha_fin) >= @HOY THEN N'EN GRACIA'
                ELSE N'VENCIDA'
            END,
            s.sus_fecha_fin,
            DATEDIFF(DAY, @HOY, s.sus_fecha_fin),
            CASE WHEN s.sus_suscripcion_estado = 1
                  AND DATEADD(DAY, s.sus_dias_gracia, ISNULL(s.sus_fecha_fin, '1900-01-01')) >= @HOY
                 THEN 1 ELSE 0 END
    FROM    [dbo].[Suscripcion] s
    WHERE   s.sus_key_hash = @KEY_HASH

    RETURN
END
```

Si no devuelve filas, la clave no existe — y la respuesta al cliente debe ser **la misma** que para una clave vencida, sin decir cuál de las dos es. Una API que distingue «clave inválida» de «clave vencida» le está confirmando a un atacante cuándo acertó una clave.

### 6.3 Qué responde la API

**HTTP 402 Payment Required.** Es el código que existe exactamente para esto y casi nadie usa.

```json
{
  "error": "SUSCRIPCION_VENCIDA",
  "mensaje": "Suscripción vencida. Ir a renovar.",
  "fecha_fin": "2026-08-31",
  "url_renovacion": "https://sigma.cl/renovar/SIGMA-K7M2Q"
}
```

### 6.4 Sin consultar la base en cada llamada

Validar contra SQL en cada request no escala. El esquema:

1. **Al autenticar**, se valida la clave contra la base una vez y se emite un token que lleva dentro `cliente`, `plan`, las funcionalidades y una expiración.
2. **La expiración del token es** `MIN(8 horas, fin de suscripción + gracia)`. Así el bloqueo llega solo, sin consultar nada.
3. **La API cachea** el resultado de `FNC_SUSCRIPCION_VIGENTE` por 10 minutos, para no golpear la base en ráfagas.
4. **Las operaciones de escritura** revalidan contra la base. Leer con un token de 8 horas vencido es tolerable; escribir, no.

### 6.5 El bloqueo en la app: la parte delicada

Aquí hay una decisión que separa un producto usable de uno que hace perder trabajo.

El técnico está sin señal desde las 8 de la mañana. La suscripción venció a medianoche. A las 4 de la tarde recupera señal con seis horas de trabajo capturado en el teléfono.

> **La sincronización de trabajo ya capturado se acepta siempre.** Aunque la suscripción esté vencida. Lo que se bloquea es **crear trabajo nuevo**, no recibir el que ya se hizo.

```text
Al sincronizar, la API acepta todo registro cuya fecha_utc sea
<= sus_fecha_fin + dias_gracia, aunque hoy la suscripcion este vencida.
Despues de aceptarlo, responde 402 para las operaciones nuevas.
```

Rechazar esa sincronización significa que el técnico pierde el día. El cliente no renueva enojado: se va. Y el dato ya era del cliente, no nuestro.

La app además guarda localmente `fecha_fin` y `dias_gracia`, así que sabe cuándo bloquearse sin necesidad de conexión, y avisa con anticipación: «tu suscripción vence en 3 días».

### 6.6 Qué se bloquea exactamente

| Estado | Web | App | Sincronizar lo pendiente |
|---|---|---|---|
| `VIGENTE` | todo | todo | sí |
| `POR VENCER` | todo + aviso | todo + aviso | sí |
| `EN GRACIA` | todo + aviso destacado | todo + aviso destacado | sí |
| `VENCIDA` | **solo la página de renovación** | **solo la pantalla de renovación** | **sí** |
| `SUSPENDIDA` | solo renovación + contacto | bloqueada | sí |
| `CANCELADA` | solo exportar sus datos | bloqueada | no |

**Los datos nunca se borran por falta de pago.** Vencida, la información sigue ahí y se recupera íntegra al renovar. Borrar datos de un cliente moroso es, además de mala práctica, un problema legal.

### 6.7 `Suscripcion_Bloqueo_Log` (`sbl`)

Append-only: cada vez que la API rechaza por suscripción, se registra cliente, endpoint, fecha, estado y origen (`WEB` / `APP` / `API`).

No es paranoia: es lo que permite responder «¿desde cuándo no puede entrar este cliente?» cuando llama enojado, y detectar que alguien está probando claves.

---

## 7. La renovación, de punta a punta

```text
 1. Faltan 10 dias.  Alerta POR VENCER en la web y en la app.
                     Correo al contacto de la suscripcion.

 2. Vence.           Empiezan los 5 dias de gracia. Todo sigue
                     funcionando con aviso destacado.

 3. Pasa la gracia.  Web y app solo muestran la pantalla de renovacion.
                     La sincronizacion de lo pendiente SIGUE aceptandose.

 4. El cliente entra a renovar.
                     Elige plan y periodicidad.
                     SIGMA calcula:
                       precio vigente hoy          22 UF
                       valor UF de hoy             39.412
                       monto                       867.064
                     -> Suscripcion_Periodo en PENDIENTE PAGO,
                        con los cuatro valores congelados.

 5. Transfiere y sube el comprobante.
                     -> Suscripcion_Pago en DECLARADO,
                        archivo en Blob, monto declarado 867.000

 6. El operador verifica contra la cartola.
                     867.000 vs 867.064 -> diferencia 64, dentro de tolerancia
                     -> VERIFICADO
                     -> spe_monto_pagado_clp = 867.000
                     -> periodo VIGENTE
                     -> sus_fecha_fin avanza un mes
                     -> LA KEY NO CAMBIA

 7. El cliente vuelve a entrar con la MISMA clave y todo esta como lo dejo.
```

El paso 7 es el requisito central: **la clave es la identidad del cliente, no su comprobante de pago.** Lo que expira es el derecho de uso, no la identidad.

---

## 8. Cambio de plan

| Movimiento | Cuándo aplica | Cómo se cobra |
|---|---|---|
| **Upgrade** (BASICO → MEDIO) | inmediato | Se cierra el período actual, se emite uno nuevo por los días restantes con la diferencia prorrateada. El cliente empieza a usar lo nuevo el mismo día |
| **Downgrade** (FULL → MEDIO) | al cierre del período | No hay devolución. Evita el ciclo de subir un mes, usar el predictivo y bajar |
| **Cambio de periodicidad** | al cierre | |

En un downgrade, lo que exceda los límites del plan nuevo **no se borra**: queda en solo lectura y se avisa. Un cliente que baja de 750 a 150 activos conserva los 750; simplemente no puede crear más hasta volver a subir de plan o dar de baja los que no usa.

---

## 9. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Tablas nuevas (10)** | `Plan_Comercial` (`plc`) · `Plan_Comercial_Precio` (`pcp`) · `Plan_Comercial_Funcionalidad` (`pcf`) · `Suscripcion` (`sus`) · `Suscripcion_Periodo` (`spe`) · `Suscripcion_Pago` (`spa`) · `Suscripcion_Consumo` (`sco`) · `Suscripcion_Key_Historial` (`skh`) · `Suscripcion_Bloqueo_Log` (`sbl`) · `Valor_Uf` (`vuf`) |
| **Catálogos nuevos (8)** | `Funcionalidad` (25 valores) · `Funcionalidad_Tipo` · `Periodicidad_Cobro` · `Suscripcion_Estado` · `Suscripcion_Periodo_Estado` · `Suscripcion_Pago_Estado` · `Uf_Origen` · (más `Entrada_Modo` del Anexo E) |
| **Funciones** | `FNC_SUSCRIPCION_VIGENTE` · `FNC_CLIENTE_TIENE_FUNCIONALIDAD` · `FNC_CLIENTE_LIMITE` |
| **Jobs** | UF diaria · aviso de vencimiento · snapshot mensual de consumo |
| **Parámetros** | `SUSCRIPCION_TOLERANCIA_CLP` · `SUSCRIPCION_TOLERANCIA_PORCENTAJE` · `SUSCRIPCION_DIAS_AVISO` · `UF_API_URL` |
| **Fuera de alcance** | Pasarela de pago. La renovación es por transferencia con comprobante, verificada por una persona |
| **Registro de prefijos** | 225 → **244**, cero colisiones |
