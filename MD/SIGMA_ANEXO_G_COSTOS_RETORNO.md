# SIGMA — Anexo G (normativo): costo de operación y retorno

Sobre qué infraestructura corre SIGMA de verdad, dónde se rompe, cuánto cuesta cada cliente y con qué margen.

Complementa el Anexo F. Base: `db_acd593_sigma` · sin datos.

---

## 1. Las dos brechas que este anexo cierra

El Anexo F puso precios — UF 9, 22 y 45 — **sin un modelo de costos detrás**. Afirmé que «la voz tiene costo variable real» sin cuantificarlo. Un precio sin costo no es un modelo de negocio, es un número.

La segunda brecha es más de fondo:

> **«Usamos versiones gratis» no es un modelo de negocio. Es una pista de despegue.**

Lo gratuito sirve para desarrollar, para la demo del capstone y para el piloto. Lo que un proyecto comercial tiene que poder responder es **en qué momento exacto se acaba** y **si el precio lo cubre cuando eso pase**.

---

## 2. La infraestructura real

Este es el punto que corrige la versión anterior de este anexo, que asumía Azure App Service y Azure SQL. **Ninguno de los dos es la infraestructura de SIGMA.**

| Qué | Dónde corre | Cuánto cuesta hoy |
|---|---|---|
| **SQL Server** | SmarterASP.NET · plan .NET PREMIUM | incluido |
| **Web (WebForms)** | SmarterASP.NET · sitio propio | incluido |
| **API** | SmarterASP.NET · sitio propio, app pool separado | incluido |
| **Fotos y adjuntos** | Azure Blob Storage · free tier | **USD 0** |
| **Voz (dictado y lectura)** | Motor del propio teléfono · **nada en la nube** | **USD 0** |
| **Análisis visual** | Azure AI Vision F0 | **USD 0** |
| **Entrenamiento de modelos** | Azure ML con crédito de estudiante | crédito, no free tier |
| **Distribución de la app** | Google Play | USD 25 por única vez |
| | **Total recurrente** | **USD 12,50 al mes** |

**USD 12,50 al mes. Para todos los clientes, no por cliente.** Ése es el costo real de operación de SIGMA, y conviene decirlo así en la reunión antes de que alguien pregunte.

> **Por qué PREMIUM y no el plan más barato.** Los USD 9,55 de diferencia mensual contra el BASIC compran exactamente las dos cosas que eran los mayores riesgos técnicos del proyecto: **3 GB de app pool** en vez de 256 MB — lo que saca de la mesa la duda de si ONNX Runtime cabe — y **10 GB de base** en vez de 1 GB, que convierte el límite más peligroso en uno que tarda doce años en llegar. Es, con diferencia, el mejor dinero del proyecto.

### 2.1 Qué da cada plan, y por qué el Premium

| Recurso | BASIC | ADVANCE | **PREMIUM** ✅ |
|---|:--:|:--:|:--:|
| Precio anunciado (compromiso largo) | USD 2,95 | USD 4,95 | USD 7,95 |
| **Precio real a 3 meses** | USD 5,50 | USD 8,50 | **USD 12,50** |
| Bases de datos | 1 | 6 | **20** |
| **Tamaño máximo por base** | 1 GB | 3 GB | **10 GB** |
| Sitios web | 1 | 6 | **ilimitados** |
| **Memoria del app pool** | 256 MB | 512 MB | **3 GB** |
| Disco y transferencia | ilimitados | ilimitados | ilimitados |

> **Los precios publicados no son los del carrito.** La página de planes anuncia USD 2,95 / 4,95 / 7,95, que corresponden a compromisos largos. En el término de 3 meses el precio real es USD 5,50 / 8,50 / 12,50. **Conviene revisar el desplegable de términos antes de pagar**: un compromiso anual puede bajar el Premium hasta un 36 %, a costa de amarrarse antes de saber si el proyecto continúa comercialmente. Para el capstone, los 3 meses (USD 37,50) cubren hasta el 19 de noviembre — la defensa queda dentro con cuatro días de margen.

Hay además un trial de 60 días sin costo, con 1 GB de base y 800 MB de app pool.

### 2.2 Qué da Azure gratis, y qué no

Dos clases muy distintas, y confundirlas es el error clásico:

| Servicio | Free tier | ¿Vence? |
|---|---|:--:|
| **Blob Storage** | 5 GB LRS caliente + 20.000 lecturas + 10.000 escrituras al mes | **de por vida** |
| ~~AI Speech F0 · voz a texto~~ | 5 h de audio/mes, concurrencia **1** — **no se usa** | de por vida |
| ~~AI Speech F0 · texto a voz~~ | 500.000 caracteres/mes — **no se usa** | de por vida |
| **AI Vision F0** | 5.000 transacciones al mes, 20 por minuto | **de por vida** |
| Blob adicional | +5 GB | 12 meses |
| Crédito inicial | USD 200 | 30 días |
| **Azure ML · cómputo** | **no hay free tier** — se paga la VM | — |

> **El crédito de estudiante no es free tier.** Son USD 100 al año, renovables mientras seas alumno activo, y sin tarjeta de crédito. Alcanzan de sobra para entrenar los modelos del capstone. Pero es **crédito con vencimiento y condicionado a tu matrícula**: un producto comercial no puede depender de que su fundador siga siendo estudiante. Cuando eso termine, el entrenamiento se muda a tu propio equipo (costo cero, es esporádico) o se presupuesta.

---

## 3. Dónde se rompe, en orden

Esta tabla cambió tres veces. Primero, al descubrir que la infraestructura no era Azure sino SmarterASP. Después, al comprar el plan Premium. Y por último, al decidir que **toda la voz corre en el teléfono** — lo que borró de un plumazo los dos límites que la encabezaban.

| # | Límite | Se agota cuando… | Qué pasa | ¿Duro? |
|:--:|---|---|---|:--:|
| **1** | **Blob de 5 GB** | ~14 meses con un cliente mediano | Aquí sí se cobra: USD 0,018 por GB-mes. **Es el único límite que SIGMA puede tocar de verdad** | no |
| 2 | Vision F0 · 5.000 tx/mes | el análisis visual se usa en volumen | Se rechaza. No está en el alcance de la demo | **sí** |
| 3 | Base de 10 GB | ~12 años con diez clientes | El motor deja de aceptar escrituras | **sí** |
| 4 | App pool de 3 GB | muy lejos del uso previsto | El sitio recicla | **sí** |
| — | ~~Speech TTS · 500.000 car/mes~~ | ~~3,8 técnicos leyendo checklists~~ | **Ya no aplica: no se usa voz en la nube** | — |
| — | ~~Speech STT · concurrencia 1~~ | ~~dos técnicos dictando a la vez~~ | **Ya no aplica** | — |

**El único límite que la operación normal puede llegar a tocar es el de Blob, y es blando: se paga el excedente a USD 0,018 por GB-mes.** Los dos que encabezaban esta tabla eran de voz, y desaparecieron al decidir que toda la voz corre en el teléfono. Los otros dos se resolvieron comprando Premium. La lista de riesgos operativos quedó vacía.

Nótese que los que quedan siguen diciendo **sí** en la última columna. En Azure pagado, pasarse de la cuota significa que te cobran de más. **En free tier y en hosting compartido, pasarse significa que se rechaza o se detiene.** Por eso el modelo distingue las dos cosas con `snt_limite_duro`: un aviso de «vas al 90 %» no quiere decir lo mismo en un caso que en el otro.

### 3.1 Lo que compró el Premium

Vale la pena dejar escrito qué se resolvió con USD 9,55 más al mes, porque es el tipo de decisión que después nadie recuerda por qué se tomó:

| Riesgo que existía con BASIC | Estado con PREMIUM |
|---|---|
| **¿Cabe ONNX Runtime en 256 MB?** Riesgo alto. Obligaba a medirlo antes de vender un plan FULL, con la inferencia por lote como plan B | **Resuelto.** 3 GB de app pool. La inferencia en línea dentro de la API deja de estar en duda |
| **La base de 1 GB se llena a los ~10 clientes en poco más de un año**, y es límite duro: el sistema se detiene | **Resuelto.** 10 GB — unos 12 años con diez clientes. Se sigue vigilando, porque duro es duro, pero deja de ser riesgo de proyecto |
| **Un solo sitio**: web y API comparten app pool, y si la API consume la memoria se cae también la web | **Resuelto.** Sitios ilimitados: cada una con su app pool |
| **Una sola base**: no hay dónde poner un ambiente de pruebas | **Resuelto.** 20 bases. Desarrollo y producción separados, sin costo extra |

> **Una decisión que conviene revisar ahora que cambió la restricción.** Con el plan BASIC la API tenía que ir como sub-aplicación de la web, porque solo había un sitio disponible. **Con Premium eso ya no es necesario.** Separarlas da app pools independientes — si la API falla, la web sigue en pie — y permite desplegar cada una sin tocar la otra, que con tres personas trabajando en paralelo importa. El costo es configurar dos sitios en vez de uno. Al modelo de datos le da lo mismo; es una decisión de despliegue, y ahora hay con qué tomarla bien.

### 3.2 Cuándo se llena la base

Estimación con el perfil de Hamburgo — 350 OT al mes, 270 ejecuciones de checklist, mediciones y bitácora — y con **las fotos fuera de la base**, en Blob:

| Clientes | Con 1 GB (BASIC) | **Con 10 GB (PREMIUM)** |
|:--:|---|---|
| 1 | ~11 años | ~125 años |
| 3 | ~3,8 años | ~42 años |
| 10 | ~1,2 años | **~12 años** |
| 25 | ~6 meses | ~5 años |
| 50 | ~3 meses | ~2,5 años |

Son unas 14.000 filas al mes por cliente, ~250 bytes por fila, duplicado por los índices: **cerca de 7 MB al mes por cliente**. Es una estimación con supuestos declarados, no una medición.

Las dos consecuencias operativas siguen valiendo, porque son buenas prácticas y no parches a una limitación:

1. **Las fotos jamás van en la base.** Van a Blob, y por eso el modelo guarda solo metadatos y la URL. Con 10 GB ya no es cuestión de vida o muerte, pero meter binarios en la base sigue siendo una mala idea: infla los respaldos y degrada las consultas.
2. **Los logs necesitan política de retención.** Son la tabla que crece sin que nadie mire. Con 10 GB hay margen para descubrirlo tarde, pero no hay razón para hacerlo.

### 3.3 No hay SQL Agent

Consecuencia de estar en hosting compartido que la versión anterior de este anexo ignoraba: **hay derechos DBO pero no SQL Agent**, y el app pool se recicla cuando no hay tráfico. No existe «el job corre a medianoche».

Por eso todos los SP de cierre son **idempotentes y se disparan con la primera petición del día**: si nadie entra por tres días, corren al cuarto y producen exactamente el mismo resultado.

> Es la misma razón por la que en el modelo lógico se decidió que **un estado derivable no es un estado**. VENCIDA, ATRASADA y EN GRACIA se calculan al consultar, nunca se guardan. Aquella decisión se tomó por higiene de modelado; en esta infraestructura resulta que además era la única que funciona, porque no hay ningún scheduler confiable que pudiera mantenerlos al día.

---

## 4. La voz: por qué corre entera en el teléfono

Esta sección explica una decisión ya tomada. **SIGMA no usa voz en la nube: ni como opción, ni como escalamiento, ni para el plan más caro.** Toda la síntesis y todo el reconocimiento corren en el motor del propio dispositivo, con `flutter_tts` y `speech_to_text` sobre lo que Android e iOS ya traen.

Los números que llevaron ahí, con el perfil real de Hamburgo — 3 plantas, 25 usuarios, ~350 OT/mes, 270 ejecuciones de checklist/mes:

| | Volumen mensual | Free tier | Costo si se pagara |
|---|---|---|---|
| **Texto a voz** (leer el checklist) | 1.320.000 caracteres | 500.000 | **USD 21,12** |
| **Voz a texto** (dictar) | 1,46 horas de audio | 5 horas | USD 1,46 |

**Leer en voz alta cuesta 14 veces más que dictar.** Es contraintuitivo — uno asume que el reconocimiento es lo caro — pero leer un checklist de 20 ítems genera ~2.000 caracteres, y un técnico hace 66 checklists al mes. Dictar genera 30 segundos de audio por vez. Con **un solo cliente** de 10 técnicos en modo lectura ya se consumiría 2,6 veces el free tier de TTS, y en el nivel F0 el exceso **no se cobra: se rechaza**.

Pero el dinero no es lo que decidió:

| | Motor del teléfono | Voz en la nube |
|---|---|---|
| **Sin señal** | **funciona** | no funciona |
| Concurrencia | **ilimitada** | 1 en el nivel gratuito |
| Costo | **0** | USD 16 por millón de caracteres |
| Cuota que se agota | **ninguna** | 500.000 caracteres al mes |
| Calidad de voz | buena | mejor |
| Vocabulario técnico | genérico | entrenable |

> **El caso que decide es la sala de blowers sin señal.** Ahí es exactamente donde el técnico tiene las manos con aceite y necesita dictar, y ahí es donde la nube no llega. Una funcionalidad de accesibilidad que se cae justo en el lugar donde se necesita no es una funcionalidad, es una demostración.

### 4.1 Lo que la decisión elimina del modelo

Todo esto es trabajo que no hay que construir ni mantener — y en un proyecto de 88 días, eso cuenta:

- **La cuota mensual de voz.** `Funcionalidad` vuelve de 27 a **25** valores: se van `LIMITE TTS CARACTERES` y `LIMITE STT MINUTOS`. `Plan_Comercial_Funcionalidad` vuelve de 81 a **75** filas.
- **`FNC_CLIENTE_VOZ_MOTOR`**, la función que elegía motor. Si solo hay un motor, no hay decisión que tomar.
- **`VW_CUOTA_VOZ_CLIENTE`** y el parámetro `CUOTA_VOZ_AVISO_PORCENTAJE`. No hay cuota que vigilar.
- **La consulta al servidor antes de dictar.** Ésta importa más de lo que parece: preguntarle al servidor «¿qué motor uso?» es *en sí misma* una dependencia de red, justo en el camino que tiene que funcionar sin red. La simplificación no solo quita código: **quita una llamada que podía fallar en el peor momento posible**.

### 4.2 Lo que se conserva, y por qué

`Dictado_Voz.dvo_voz_motor` se queda, y no «por si acaso». La columna registra **un hecho sobre cómo se produjo ese texto**: una transcripción hecha por el motor de un teléfono tiene un perfil de error distinto al de un motor de nube, y cuando ese texto termina alimentando al modelo predictivo, saber de dónde salió es parte de poder auditarlo. Hoy todas las filas dicen `DISPOSITIVO` — y eso también es información.

Las dos tarifas de Azure Speech **quedan cargadas en `Servicio_Nube_Tarifa` con su costo real, aunque el servicio no se use.** Un consumo de cero contra una tarifa conocida es un argumento; borrar la tarifa sería perder el argumento.

### 4.3 La consecuencia comercial

Si la voz no cuesta nada, cobrar por ella pasa a ser una decisión distinta:

| Funcionalidad | Plan | Por qué |
|---|---|---|
| **`LECTURA POR VOZ`** | **todos, incluido BÁSICO** | Es lo que permite trabajar a quien no sabe leer. **Es acceso, no comodidad.** No cuesta nada cobrarla, y negarla no ahorra nada |
| `CREACION POR VOZ` | MEDIO y FULL | Dictar con las manos ocupadas es productividad, y la productividad sí se cobra |

> Antes había un argumento de costo para dejar la lectura fuera del plan básico. **Ese argumento desapareció.** Lo único que quedaría es cobrar por el acceso de alguien que no sabe leer, y eso no se sostiene.

---

## 5. Costo por cliente y margen

Supuestos declarados: 1 UF = 39.500 CLP, USD 1 = 950 CLP → **1 UF ≈ USD 41,6**. Son parámetros del modelo, no verdades: se recalcula con `Valor_Uf`.

El costo de infraestructura **no crece por cliente**: es una cuenta que llega una sola vez y se reparte. Y con Premium el mismo plan aguanta hasta bastante más allá de donde llega este proyecto.

| Clientes | Plan de hosting | Costo total/mes | Asignado por cliente |
|:--:|---|---:|---:|
| 1 | PREMIUM | USD 12,50 | USD 12,50 |
| 3 | PREMIUM · el mismo | USD 12,50 | USD 4,17 |
| 10 | PREMIUM · el mismo | USD 12,50 | USD 1,25 |
| 25 | PREMIUM · el mismo | USD 12,50 | USD 0,50 |
| 50 | Azure SQL serverless + App Service B1 | ~USD 28 | USD 0,56 |

Contra los ingresos, con **un solo cliente** — el caso más desfavorable, porque no hay entre quiénes repartir:

| Plan | UF/mes | Ingreso USD | Infra por cliente | Margen |
|---|---:|---:|---:|---:|
| **BÁSICO** | 9 | 374 | 12,50 | **96,7 %** |
| **MEDIO** | 22 | 915 | 12,50 | **98,6 %** |
| **FULL** | 45 | 1.871 | 12,50 | **99,3 %** |

Con tres clientes el margen del MEDIO sube a 99,5 %, y con diez a 99,9 %.

**El margen sobre infraestructura roza el 100 %, y por eso es la métrica equivocada.** Un margen del 99 % no significa que el negocio sea nueve veces mejor que uno del 90 %: significa que la infraestructura **no es la variable relevante**. Decirlo así en la reunión es más creíble que presentarlo como un logro.

Lo que sí es relevante:

1. **El techo, no el costo.** Con Premium el techo se fue tan lejos que dejó de ser una preocupación de este proyecto: la base aguanta doce años con diez clientes y el app pool sobra. La pregunta «¿cuándo se rompe?» ahora tiene una respuesta cómoda, que es exactamente lo que se compró.
2. **El costo real del negocio es el trabajo humano.** Desarrollo, implantación, soporte. Por eso los **UF 25 de implantación por única vez** no son un extra: son lo que financia cargar los activos de un cliente nuevo y capacitarlo, que es donde de verdad se van las horas.

> **La comparación que cierra el caso:** el hosting completo cuesta **USD 37,50 por tres meses**. Un solo cliente en plan BÁSICO paga **USD 374 al mes**. La infraestructura de un trimestre entero se financia con **tres días** de un cliente.

### 5.1 El camino de migración, con precio

Que exista el camino es tan importante como que hoy sea barato:

| Disparador | Movimiento | Costo nuevo |
|---|---|---:|
| Blob sobre 5 GB | se paga el excedente | USD 0,018 / GB-mes |
| Voz en la nube sobre la cuota | ya resuelto: degrada al motor del teléfono | USD 0 |
| Fin del crédito de estudiante | entrenar en el equipo propio | USD 0 |
| Base sobre 8 GB | migrar a Semi Dedicado o a Azure SQL | desde ~USD 31,50/mes |
| Necesidad de SLA, dominio propio con SSL y escalado | SmarterASP → Azure SQL serverless + App Service B1 | ~USD 28/mes |
| Compromiso anual en vez de trimestral | mismo plan, término más largo | **baja hasta ~USD 7,95/mes** |

Con Premium ya no hay saltos forzados por límites: los que quedan son decisiones de negocio, no de capacidad. **Un solo cliente BÁSICO financia cualquiera de ellos treinta veces.**

---

## 6. Qué mide el modelo

Sin medición, todo lo anterior es una planilla que envejece.

### 6.1 `Proveedor_Nube` (`pvn`) — quién presta cada servicio

| id | Código | |
|---:|---|---|
| 1 | `SMARTERASP` | hosting, base de datos |
| 2 | `AZURE` | Blob, Speech, Vision, ML |
| 3 | `GOOGLE PLAY` | distribución de la app |
| 4 | `EQUIPO PROPIO` | sin costo de nube |

**El proveedor va en la tarifa, no en el servicio.** «Base de datos» es lo mismo la preste SmarterASP o Azure; lo que cambia es cuánto cuesta y cuánto regala. Modelarlo así permite migrar un servicio sin perder comparabilidad histórica: se cierra una fila, se abre otra, y el costo de enero sigue siendo el de enero.

### 6.2 `Servicio_Nube_Tarifa` (`snt`) — el límite como dato, no como constante

Si el free tier va escrito en el código, el día que cambie hay que recompilar y lo ya calculado queda inconsistente. Va en una tabla versionada, igual que el precio de los planes.

| Columna | Tipo | Nota |
|---|---|---|
| `snt_servicio_nube` | `INT` | FK `Servicio_Nube` |
| `snt_proveedor_nube` | `INT` | FK `Proveedor_Nube` |
| `snt_unidad_consumo` | `INT` | FK `Unidad_Consumo` |
| `snt_costo_unitario_usd` | `DECIMAL(18,8)` | 8 decimales porque un carácter de TTS cuesta 0,000016 |
| `snt_free_tier_cantidad` | `DECIMAL(18,4)` | cuánto viene incluido |
| `snt_free_tier_vitalicio` | `BIT` | de por vida o temporal |
| **`snt_limite_duro`** | `BIT` | **0 = te cobran el exceso · 1 = el servicio se detiene** |
| **`snt_costo_compartido`** | `BIT` | **0 = por consumo · 1 = cuenta única repartida** |
| `snt_vigencia_desde` / `_hasta` | `DATE` | `hasta` en `NULL` = tarifa vigente |
| AUD-M | | |

`snt_costo_compartido` corrige un error real del diseño anterior. El hosting es una cuenta fija: son USD 12,50 con un cliente y USD 12,50 con veinte. Sin esa distinción, tres clientes harían figurar el hosting como USD 37,50 al mes — **multiplicando una cuenta que llega una sola vez**. Con ella, el cierre usa dos fórmulas:

```text
Por consumo (0)     costo = (cantidad - free_prorrateado) x unitario
Fijo compartido (1) costo = unitario x (cantidad / total_del_mes)
```

**Un servicio puede tener dos filas con unidades distintas, y no es un error del modelo.** El free tier y el precio pagado a veces no se miden igual. Que no coincidan *es* la razón por la que un cambio de plan es un salto y no una pendiente.

### 6.3 `Consumo_Servicio_Nube` (`csn`) — el medidor

Una fila por cliente, servicio y mes. Durante el mes **acumula**; al cerrarlo congela la tarifa, calcula el costo y queda cerrada para siempre.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `csn_cliente` | `INT` | NO | |
| `csn_servicio_nube` | `INT` | NO | FK `Servicio_Nube` |
| `csn_unidad_consumo` | `INT` | NO | FK `Unidad_Consumo` |
| `csn_periodo_anio` / `csn_periodo_mes` | `INT` | NO | |
| `csn_cantidad` | `DECIMAL(18,4)` | NO | lo consumido, se va sumando |
| `csn_cantidad_free_tier` | `DECIMAL(18,4)` | SÍ | cuánto cayó dentro de lo incluido |
| `csn_costo_unitario_usd` | `DECIMAL(18,8)` | SÍ | **congelado** al cerrar |
| `csn_costo_estimado_usd` | `DECIMAL(18,2)` | SÍ | según la fórmula que corresponda |
| `csn_servicio_nube_tarifa` | `INT` | SÍ | qué tarifa se usó, para auditarlo |
| `csn_cerrado` | `BIT` | NO | 1 = mes cerrado, no se toca más |

`UX_CSN_CLIENTE_SERVICIO_PERIODO (cliente, servicio, año, mes)` — un solo medidor por cliente y mes.

**Por qué acumula en vez de ser append puro.** La cuota de voz se consulta *en cada dictado*: hay que saber cuánto lleva gastado el cliente antes de decidir si va a Azure o al teléfono. Leer una fila por un índice es instantáneo; sumar un millón de filas de detalle, no. El detalle igual no se pierde: cada dictado queda en `Dictado_Voz` con su motor y su duración. El `UPDATE ... SET csn_cantidad += @X` es atómico bajo el lock de la fila.

> **Convención que hay que declarar:** lo incluido se reparte entre los clientes a prorrata de lo que consumió cada uno. El proveedor no regala nada «por cliente» — se lo regala a la cuenta. El reparto es una manera razonable de asignar el costo, no una factura. Queda escrito en el SP de cierre para que nadie lo lea después como si fuera plata real.

### 6.4 `VW_SALUD_INFRAESTRUCTURA` — el gigabyte, vigilado

El riesgo número uno es que la base llegue a 1 GB y SIGMA se detenga. Un riesgo que no se mide no se gestiona, así que la vista lo mide contra `sys.database_files` y devuelve un semáforo:

| Umbral | Estado |
|---|---|
| ≥ 100 % | `AGOTADO. El sistema se detiene.` |
| ≥ 90 % | `CRITICO. Subir de plan o depurar ahora.` |
| ≥ 75 % | `Atención. Planificar el cambio de plan.` |
| menor | `Normal` |

La base es un recurso **global**, no por cliente: el tope lo comparten todos. Por eso la vista no lleva columna de cliente.

### 6.5 Columnas y cuotas nuevas

- `Dictado_Voz.dvo_voz_motor` — FK `Voz_Motor`, default **DISPOSITIVO**. Hoy todas las filas son DISPOSITIVO.
- `Suscripcion_Consumo` suma `sco_tts_caracteres`, `sco_stt_segundos` y `sco_costo_azure_usd`. Los tres quedan en cero mientras la voz corra en el teléfono, y ésa es justamente la evidencia.
- `Funcionalidad` se queda en **25** valores. Las dos cuotas de voz que llegó a tener se eliminaron al decidir que no hay voz en la nube (§4.1).

---

## 7. Qué pasa al llegar al tope: degradar, no cortar

| Cuota superada | ❌ Lo que **no** se hace | ✅ Lo que se hace |
|---|---|---|
| **Almacenamiento** | Rechazar la foto | Aceptarla, avisar, y ofrecer subir de plan o depurar |
| **Activos / usuarios** | Borrar los que sobran | Bloquear la creación de nuevos, conservar todo lo existente |
| ~~Voz~~ | — | **Ya no aplica: la voz no tiene cuota que superar** |

> **La accesibilidad no se degrada, porque no depende de nada que se pueda agotar.** Ésta era la regla más importante del diseño anterior, y la decisión de correr toda la voz en el teléfono la volvió innecesaria: **ya no existe el escenario del que había que proteger al usuario**.
>
> Antes había que garantizar que a nadie se le cortara la lectura en voz alta por una cuota comercial. Ahora no hay cuota, no hay motor alternativo, no hay degradación y no hay función que decida. Si alguien depende de la lectura en voz alta para trabajar, funciona siempre — sin señal, sin límite mensual y sin importar qué plan tenga contratado.

**Una regla que se puede borrar porque el diseño la volvió imposible de violar es mejor que una regla bien implementada.**

---

## 8. El relato comercial del proyecto

Cómo contarlo sin exagerar ni quedarse corto:

**1. El costo de operación es USD 12,50 al mes, y es una decisión, no una suerte.** SIGMA corre sobre hosting compartido y free tiers *de por vida*, no sobre créditos de 30 días. La única partida con vencimiento es el crédito de estudiante del entrenamiento, y está identificada.

**2. La arquitectura está diseñada para que siga siendo bajo.** **Toda** la voz corre en el dispositivo: gratis, sin señal y sin cuota. La inferencia predictiva corre con ONNX dentro de la propia API, no en un servicio de inferencia facturado. Las fotos van a Blob y no a la base.

**3. Sabemos exactamente dónde se rompe, y ya no se rompe en ninguna parte cercana.** Los dos límites de voz desaparecieron al sacar la nube de la ecuación; los dos de hosting se resolvieron pasando a Premium por USD 9,55 más al mes. **El único límite que la operación normal puede tocar es el de Blob, y es blando**: se paga el excedente a USD 0,018 por GB-mes.

**4. Cuando se rompa, el precio ya lo cubre.** Un cliente MEDIO paga USD 915 al mes contra USD 12,50 de infraestructura. El salto más caro del camino de migración cuesta USD 28 al mes: **un solo cliente BÁSICO lo financia treinta veces**.

**5. El margen alto no es el argumento.** Un 99 % de margen sobre infraestructura significa que la infraestructura no es la variable relevante. El argumento es que **conocemos el techo, lo movimos a propósito, y tenemos el camino de salida con precio puesto**.

**6. Lo medimos, no lo suponemos.** `Consumo_Servicio_Nube` registra mes a mes cuánto consume cada cliente, `VW_RENTABILIDAD_CLIENTE_MES` lo cruza con lo que paga, y `VW_SALUD_INFRAESTRUCTURA` vigila el límite que puede detener el sistema.

**7. Lo que sí cuesta es el trabajo humano.** Desarrollo, implantación y soporte. Por eso hay UF 25 de implantación por única vez.

---

## 9. Riesgos y qué hacer

| Riesgo | Probabilidad | Qué se hace |
|---|:--:|---|
| ~~ONNX Runtime no cabe en 256 MB~~ | **Resuelto** | Se compró el plan Premium: 3 GB de app pool. Se mide igual la primera semana, pero dejó de ser un riesgo de proyecto |
| ~~La base llega a 1 GB y todo se detiene~~ | **Resuelto** | 10 GB con Premium: ~12 años con diez clientes. `VW_SALUD_INFRAESTRUCTURA` lo vigila igual, porque un límite duro se vigila aunque esté lejos |
| La web se cae porque la API consumió la memoria | **Resuelto** | Premium da sitios ilimitados: web y API con app pool propio cada una. Requiere separarlas al desplegar |
| Google Play retrasa el lanzamiento | **Alta** | Cuenta personal creada después del 13-11-2023 exige **12 testers activos durante 14 días seguidos**. Es plazo de calendario, no plata: hay que empezarlo con más de un mes de anticipación |
| El crédito de estudiante vence | Alta | Está identificado y aislado en una sola línea de costo. El entrenamiento se muda al equipo propio: es esporádico |
| Los proveedores cambian límites o precios | Alta | El costo unitario se congela por mes; el free tier es un dato versionado, no una constante en el código |
| Un cliente crece y desbalancea el costo | Media | Cuotas por plan y medición mensual. El upgrade se propone con datos |
| ~~Speech F0 con concurrencia 1 bloquea a dos técnicos~~ | **Eliminado** | No hay voz en la nube. El riesgo no se mitigó: dejó de existir |
| **El reconocimiento del teléfono no alcanza para vocabulario técnico** | Media | **Sin escape a la nube, éste es ahora un riesgo asumido.** `dvo_intentos` mide si está pasando; la mitigación es de interfaz — listas para elegir en vez de dictado libre en los campos difíciles — y siempre queda el teclado |

---

## 10. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Tablas nuevas (2)** | `Servicio_Nube_Tarifa` (`snt`) · `Consumo_Servicio_Nube` (`csn`) |
| **Catálogos nuevos (4)** | `Proveedor_Nube` (4) · `Servicio_Nube` (10) · `Unidad_Consumo` (10) · `Voz_Motor` (2) |
| **Funcionalidad** | se mantiene en **25** valores: las cuotas de voz se eliminaron |
| **Columnas nuevas** | `dvo_voz_motor` · `sco_tts_caracteres` · `sco_stt_segundos` · `sco_costo_azure_usd` |
| **Funciones (2)** | `FNC_TARIFA_NUBE` · `FNC_CLIENTE_CONSUMO_NUBE` |
| **Procedimientos (2)** | `INS_CONSUMO_SERVICIO_NUBE` · `UPD_CONSUMO_SERVICIO_NUBE_CIERRE` (idempotente, sin SQL Agent) |
| **Vistas (2)** | `VW_RENTABILIDAD_CLIENTE_MES` · **`VW_SALUD_INFRAESTRUCTURA`** |
| **Parámetros (3)** | `COSTO_USD_CLP` · `VOZ_MOTOR_PREDETERMINADO` · `AZURE_FREE_TIER_ACTIVO` |
| **Cuotas por plan** | `Plan_Comercial_Funcionalidad` se mantiene en **75** filas |
| **Decisión de arquitectura** | **Toda la voz en el dispositivo.** Nada en la nube, ni como opción ni como escalamiento |
| **Decisión de producto** | **`LECTURA POR VOZ` pasa a estar en todos los planes.** Si no cuesta nada, cobrar por el acceso de quien no sabe leer no se sostiene |
| **Infraestructura** | **SmarterASP .NET PREMIUM** — 3 GB de app pool, 10 GB por base, 20 bases, sitios ilimitados · USD 12,50/mes |
| **Registro de prefijos** | 244 → **250**, cero colisiones |
| **Script** | `09_COSTOS_NUBE.sql` |

---

*Planes y límites de SmarterASP.NET, cuotas del free tier de Azure, condiciones de Azure for Students y requisitos de Google Play verificados en agosto de 2026 contra la documentación oficial de cada proveedor. Los **precios unitarios** de los servicios pagados son valores de referencia y se ajustan sin tocar código: manda la tarifa congelada en el cierre de cada mes. La proyección de crecimiento de la base es una estimación con supuestos declarados, no una medición. Los valores de UF y tipo de cambio son parámetros del modelo, no constantes.*

**Fuentes:** [SmarterASP.NET · planes de hosting](https://www.smarterasp.net/hosting_plans) · [Azure for Students](https://learn.microsoft.com/en-us/azure/education-hub/about-azure-for-students) · [Google Play · registro de desarrollador](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en) · [Google Play · requisitos de prueba cerrada](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) · [Azure AI Speech · cuotas y límites](https://docs.azure.cn/en-us/ai-services/speech-service/speech-services-quotas-and-limits)
