# SIGMA — Anexo H (normativo): refinamientos de terreno

Lo que cambió en el modelo después de la reunión con el equipo y de lo que contó Emilio, planificador de Hamburgo.

Base: `db_acd593_sigma` · sin datos. Script: `10_REFINAMIENTOS_TERRENO.sql`.

---

## 1. Por qué este anexo vale más que los anteriores

Los anexos A a G describen decisiones de diseño. Éste describe **el proceso real**, contado por quien lo opera. La diferencia importa: hasta aquí el modelo era una hipótesis bien argumentada sobre cómo debería funcionar el mantenimiento; ahora hay una parte que es un hecho verificado sobre cómo funciona en Hamburgo.

Y el hallazgo principal **corrige algo que habíamos cerrado mal**.

---

## 2. La corrección: la OT tiene un ciclo de vida, y no lo habíamos visto

En su momento se eliminaron los códigos de estado 54 a 64 porque nadie sabía de dónde salían y porque la información disponible decía que solo existían ABIERTA y CERRADA. Ese diagnóstico era correcto **sobre los datos que teníamos**, pero incompleto sobre el proceso.

Emilio lo describe sin ambigüedad:

> «La OT se crea a petición del técnico, se realiza y se le da finalizado, pero queda como en status **en espera** hasta que el planner o jefatura le dé el cierre.»
>
> «Ahí es donde el planner o la persona a cargo de cerrar las OT tiene la pega de cerrarlas todas.»

Hay cuatro estados, no dos:

```text
ABIERTA  ->  EN EJECUCION  ->  EN ESPERA DE CIERRE  ->  CERRADA
                                ^^^^^^^^^^^^^^^^^^^      ^^^^^^^
                                hasta aqui el tecnico    planificador,
                                                         supervisor o jefe
```

**La frontera entre los dos últimos estados no es un tecnicismo: es la definición del trabajo del planificador.** Contar cuántas OT están en `EN ESPERA DE CIERRE` es medir su carga pendiente, y es la pantalla más útil que puede tener.

### 2.1 Los cinco estados que se cayeron, y por qué

El catálogo tenía nueve valores. Quedan cuatro. Los otros cinco se eliminaron aplicando una regla que ya estaba en el modelo:

| Estado eliminado | Por qué no es un estado |
|---|---|
| `BORRADOR` | Nada en el proceso lo produce. Una OT o existe o no existe |
| `ASIGNADA` | Es «hay fila en `Orden_Trabajo_Asignacion`». **Derivable** |
| `EJECUTADA` | Es lo mismo que `EN ESPERA DE CIERRE`, con otro nombre |
| `VALIDADA` | Es «hay fila en `Orden_Trabajo_Validacion`». **Derivable** |
| `ANULADA` | Anular **es** cerrar. Va en el motivo de cierre, no en el estado |

> **Un estado derivable no es un estado.** Era la regla que justificó no guardar VENCIDA ni ATRASADA. Aplicada aquí, corta el catálogo a menos de la mitad — y lo que queda es exactamente lo que Emilio describe.

### 2.2 `Orden_Trabajo_Cierre_Motivo` (`ocm`), el catálogo que rescata a ANULADA

Eliminar `ANULADA` dejaba un problema real: una OT creada por error tiene que poder salir del sistema sin contaminar la estadística de trabajo hecho. La solución no es un estado más, es decir **por qué** se cerró:

| id | Código |
|---:|---|
| 1 | `TRABAJO REALIZADO` |
| 2 | `SIN HALLAZGO` |
| 3 | `RESUELTA EN OTRA OT` |
| 4 | `DUPLICADA` |
| 5 | `ANULADA POR ERROR` |
| 6 | `NO APLICA` |

Una OT cerrada **obliga** a declarar motivo, quién cerró y cuándo — lo garantiza `CK_OTR_CIERRE_COMPLETO` en el motor, no la pantalla. Y el indicador de «OT cerradas» pasa a poder filtrar las que se cerraron porque el trabajo se hizo, que es la única cifra que significa algo.

---

## 3. «Al final todo termina siendo una OT»

Emilio describe el caso completo:

> «Revisaron un eje con una OT establecida y te das cuenta que hay que cambiarlo. El técnico, en la misma OT de trabajo, pide otra OT para cambiar el eje. Y en caso de que se tenga que cambiar de forma correctiva, en la misma OT de trabajo se retroalimenta con la información: *se cambia eje de forma correctiva por emergencia*.»

Eso admitía dos modelados. Uno con una entidad `Solicitud_Ot` que el planificador aprueba y que después se convierte en OT. Otro sin ella.

**Se eligió el segundo, y la razón la puso Bryan en una frase: «al final todo termina siendo una OT».**

Es la decisión correcta y conviene entender por qué:

| Con entidad `Solicitud` | Sin ella |
|---|---|
| Dos tablas, dos ciclos de vida, dos bandejas | Una tabla, un ciclo, una bandeja |
| Hay que decidir qué pasa con las solicitudes rechazadas | No existe el problema |
| El historial de un activo se arma de dos fuentes | Se arma de una |
| «¿Cuántos trabajos hay pendientes?» se responde sumando dos cosas | Se responde con un `WHERE` |

Los dos caminos del relato de Emilio se resuelven **sin inventar nada**:

- **Se resuelve en el momento** → se retroalimenta la misma OT. El trabajo adicional queda como pasos, repuestos y falla dentro de la OT que ya estaba abierta.
- **Queda para después** → nace otra OT, con origen `HALLAZGO EN OT` y `otr_ot_origen` apuntando a la que la detectó.

Esa FK recursiva es pequeña y hace algo que ninguna otra columna puede hacer: **permite reconstruir por qué se cambió el eje.** Sin ella, dentro de un año hay una OT de cambio de eje sin causa aparente, y el historial que alimenta al predictivo pierde justamente la parte causal.

---

## 4. La emergencia de las tres de la mañana

Éste es el punto donde SIGMA puede mejorar el proceso en vez de solo digitalizarlo. Emilio:

> «Debe haber una OT sí o sí, digital o física. Por lo general en esos casos se crea la OT al día siguiente — **que no es legalmente bien hecho** — pero sirve para documentar que sí hay una OT establecida.»

Él mismo marca el problema. Y la causa no es desidia: **crear una OT a las tres de la mañana, desde el piso de planta, con las manos sucias y sin computador, era imposible.** El registro al día siguiente es la consecuencia de una limitación de herramienta, no de una mala práctica.

La app cambia eso: el técnico abre la OT en el momento, desde el teléfono, **sin señal**, y se sincroniza cuando haya cobertura. La fecha real queda registrada porque el dispositivo la capturó cuando ocurrió.

Para los casos en que igual se registre después, el modelo guarda **dos fechas y no una**:

| Columna | Qué guarda |
|---|---|
| `otr_fecha_ocurrencia` | Cuándo ocurrió el trabajo, declarado |
| `otr_fecha_creacion` | Cuándo se registró en el sistema |
| `otr_registro_posterior` | Marca que las dos no coinciden |

Guardar solo la fecha de creación sería mentir sobre cuándo pasó. Guardar solo la declarada sería no poder auditarlo. **Guardar las dos convierte una debilidad del proceso en un dato medible**: cuántas OT se registran a destiempo, y en qué turno.

---

## 5. El trabajo externo

### 5.1 Qué se pidió

- El flujo de OT externas es **solo para tener registro de la tarea realizada**. Hasta ahí.
- Al asignar una OT hay que poder indicar **si es externa y qué empresa**.
- En las tareas programadas puede haber **técnico de planta junto a un externo**, porque el técnico de planta puede ser ayudante del externo.
- El **jefe de mantenimiento adjunta la OT externa** del trabajo realizado, porque las empresas externas la envían por correo.

### 5.2 Por qué lo externo va en la asignación y no en la OT

Podría parecer que la OT necesita una bandera `otr_es_externo`. No la lleva, por dos razones:

1. **En la misma OT conviven ambos.** El externo ejecuta y el técnico de planta apoya. Una bandera a nivel de OT no puede expresar eso; la asignación sí, con `Rol_Ejecucion`.
2. **Sería un dato derivable.** «Esta OT tiene trabajo externo» es «existe alguna asignación con proveedor». Guardarlo aparte es garantizar que algún día esté desincronizado.

`Orden_Trabajo_Asignacion` gana `ota_proveedor` (FK nullable a `Proveedor`) y un `CHECK` que obliga a que cada fila apunte **a una persona o a una empresa, nunca a las dos ni a ninguna**.

### 5.3 Lo que enseña el informe de Vixon

El PDF que se adjuntó — *HAMBURGO 004-26, Soporte Correctivo Zeppelin silo 1* — es la evidencia real de una OT externa, y confirma varias cosas del modelo:

| Lo que trae el documento | Dónde cae en SIGMA |
|---|---|
| Relato de la falla: síntoma, método de diagnóstico, causa raíz, acción, resultado | `Falla` con `Falla_Sintoma`, `Falla_Diagnostico`, `Falla_Causa`, `Falla_Accion` |
| «Se validó con personal técnico de turno» | `Orden_Trabajo_Validacion` |
| **2,4 UF/hora**, total 420.000 + IVA | `Orden_Trabajo_Servicio` con moneda UF — **el catálogo `Moneda` ya la incluía** |
| N° de cotización, plazo, validez de la oferta, garantía | Atributos del servicio contratado |
| El PDF mismo | `Archivo` enlazado a la OT, adjuntado por el jefe |

Dos observaciones que salen de mirarlo con cuidado:

- **El archivo se llama «HAMBURGO 00526» y por dentro dice «HAMBURGO 004-26».** Es exactamente el tipo de inconsistencia que hace imposible cruzar información entre el correo y la carpeta. Cuando SIGMA guarda el documento **dentro de la OT**, el número de la OT es la referencia y el nombre del archivo deja de importar.
- **El documento lleva cláusula de confidencialidad.** Guardar informes de terceros implica que el control de acceso a `Archivo` no es un detalle: el permiso de ver adjuntos de una OT tiene que ser explícito.

> **Y un hallazgo de negocio, de regalo:** el externo cobra **2,4 UF/hora**. El plan MEDIO de SIGMA cuesta 22 UF al mes. **Una sola emergencia de nueve horas cuesta más que un año de suscripción.** Ése es el argumento de venta más fuerte que ha aparecido en todo el proyecto, y no lo inventamos nosotros: está en la cotización del proveedor.

---

## 6. Permisos de trabajo: evidencia y dos firmas

Lo pedido: si la OT requiere permiso, hay que **adjuntar evidencia**; puede haber **más de un permiso** para el mismo trabajo; y llevan **fecha y firma del prevencionista y del jefe de mantenimiento**.

`Permiso_Trabajo` gana cinco columnas:

| Columna | Para qué |
|---|---|
| `ptr_archivo` | La evidencia escaneada o fotografiada |
| `ptr_usuario_prevencionista` · `ptr_fecha_prevencionista` | Primera firma |
| `ptr_usuario_jefe` · `ptr_fecha_jefe` | Segunda firma |

No es un booleano `firmado`: son cuatro columnas porque son cuatro hechos, y porque el día que falte una hay que poder saber **cuál**.

`CK_PTR_AUTORIZADO` obliga a que un permiso en estado `AUTORIZADO` tenga las dos firmas y la evidencia. Y `UPD_ORDEN_TRABAJO_CERRAR` **rechaza cerrar una OT con permisos sin autorizar**: cerrarla sería documentar que el trabajo se hizo con un permiso que nadie firmó.

La condición de «más de un permiso» ya estaba resuelta: la relación es 1:N desde la OT.

---

## 7. Horómetro en los repuestos

Lo pedido: registrar horómetro **al retirar** y **al instalar**, y que sea **opcional**.

Opcional en la captura, decisivo en el modelo:

> La vida útil real de un repuesto es `horometro_retiro` menos `horometro_instalacion` de la vez anterior. **Sin esos dos números, el predictivo estima vida útil en días calendario**, que para una máquina que trabaja por turnos variables no significa nada.

Es la diferencia entre decir «el rodamiento duró 8 meses» y decir «duró 2.900 horas». Lo primero no sirve para predecir; lo segundo sí.

Se agregan `ore_horometro_retiro`, `ore_horometro_instalacion` y `ore_activo_medidor`, con un `CHECK` que exige declarar **de qué medidor** salió la lectura. Un número sin medidor no se puede comparar con nada.

---

## 8. El bodeguero

> «El bodeguero es quien va a registrar los repuestos en cuanto a mínimo y máximo de stock. **Él no compra ni nada.**»

Ese «no compra ni nada» es la definición del perfil, y tiene una consecuencia de modelado que vale la pena explicar.

**El mínimo y el máximo NO van en `Inventario_Saldo`.** El saldo es un **hecho** que resulta de los movimientos; el mínimo y el máximo son una **decisión de una persona**. Mezclarlos haría que un ajuste de inventario y una decisión de reposición se vieran iguales en la auditoría, y son cosas distintas con responsables distintos.

Va en `Repuesto_Bodega_Stock` (`rbs`), con auditoría propia: quién fijó ese mínimo y cuándo.

Se suman dos tipos de alerta: `MEDIDOR PROXIMO MANTENIMIENTO` y `STOCK MAXIMO` — porque el exceso de stock también es plata inmovilizada, y hasta ahora solo se alertaba el faltante.

---

## 9. Alertas antes de la hora de mantenimiento

> «Acá necesitamos que me genere alertas de próximas a las horas de mantenimiento.»

`Programacion_Medidor` gana `pme_aviso_anticipacion`. Un detalle que parece menor y no lo es: **el aviso se configura en unidades del medidor, no en días.**

«Avisar 50 horas antes» es una regla que funciona. «Avisar 3 días antes» no, porque cuántas horas trabaje la máquina en tres días es precisamente lo que no se sabe de antemano — y si esa semana la planta produce el doble, la alerta llega tarde.

---

## 10. Quién cierra, y cómo se hace cumplir

| Perfil | Abre OT | Ejecuta | Finaliza | **Cierra** |
|---|:--:|:--:|:--:|:--:|
| Técnico | sí (correctiva) | sí | sí | **no** |
| Supervisor de mantenimiento | sí | sí | sí | **sí** |
| Jefe de mantenimiento | sí | — | — | **sí** |
| Planificador | sí | — | — | **sí** |
| Bodeguero | no | — | — | no |

La regla vive en `UPD_ORDEN_TRABAJO_CERRAR`, que consulta `FNC_USUARIO_PUEDE_CERRAR_OT`, que a su vez pregunta por el **permiso** `CERRAR OT` y no por el nombre del perfil. El día que otro cliente llame distinto a sus cargos, esto sigue funcionando sin tocar código.

Permisos nuevos: `CERRAR OT` · `ADJUNTAR OT EXTERNA` · `GESTIONAR STOCK` · `AUTORIZAR PERMISO TRABAJO` · `AGREGAR COMPANERO ACTIVIDAD`.

### 10.1 La actividad abierta, con compañeros

Ya estaba resuelto que si un técnico toma una actividad abierta, otro no puede tomarla — con `UPDATE ... WHERE estado` y `@@ROWCOUNT`, sin `ROWVERSION`.

Lo nuevo: **quien la tomó puede registrar con quiénes la realizó.** Se resuelve agregando filas a `Orden_Trabajo_Asignacion` con rol `APOYO`, y `ota_asignado_por` deja constancia de que los sumó el técnico y no el planificador. La exclusividad se mantiene sobre quien *toma*; la compañía es un agregado posterior.

---

## 11. La pregunta sobre la IA y el hallazgo

> «Acá debemos incluir que la IA debe ser capaz de generarnos el hallazgo cuando la estemos alimentando. ¿Eso está incluido?»

La respuesta honesta es **en parte, y conviene separar tres cosas que suenan igual**:

| Qué | ¿Está? | Cuándo sirve |
|---|:--:|---|
| **1. Regla: respuesta fuera de rango genera hallazgo** | **Sí, modelado** | Desde el día uno. `Checklist_Item_Validacion` define el rango y `Checklist_Hallazgo` recibe el resultado |
| **2. Texto libre → hallazgo estructurado** | Parcial | Cuando haya dictados o informes que procesar |
| **3. Predecir el hallazgo antes de que ocurra** | Sí, es el módulo predictivo | Después de un año de historial |

**Lo primero no es IA, es una regla — y es lo que va a generar el 90 % de los hallazgos reales.** Conviene decirlo así en la reunión: presentar como «inteligencia artificial» algo que es una comparación numérica debilita el resto del argumento cuando alguien lo note.

### 11.1 Lo segundo y lo cuarto son el mismo problema

Extraer un hallazgo estructurado del dictado de un técnico («ruido metálico fuerte en el lado del motor») y extraerlo del informe de Vixon («se revisan señales con multímetro… se encontró que normalizaron un cable negativo fuera del equipo… se normaliza cable de entrada del negativo») **son la misma tarea**: texto libre → `Falla_Sintoma` + `Falla_Diagnostico` + `Falla_Causa` + `Falla_Accion`.

Un solo mecanismo, dos fuentes. Y el informe de Vixon muestra que la fuente externa es **la mejor materia prima disponible**: su narrativa es de manual — síntoma, método, causa raíz, acción, validación. Si Hamburgo tiene una carpeta de estos informes, ahí hay un corpus de entrenamiento real que no hay que fabricar.

### 11.2 Recomendación

Para la defensa de noviembre: **construir la regla (1), demostrar el pipeline de (3) con datos sintéticos, y dejar (2) modelado y explicado.** El texto dictado ya se guarda estructurable en `Dictado_Voz`; extraer entidades de él es un incremento posterior, no un prerrequisito.

---

## 12. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Catálogo corregido** | `Orden_Trabajo_Estado` 9 → **4 valores** |
| **Catálogo nuevo** | `Orden_Trabajo_Cierre_Motivo` (`ocm`, 6 valores) |
| **Catálogos ampliados** | `Orden_Trabajo_Origen` +`HALLAZGO EN OT` · `Alerta_Tipo` +`MEDIDOR PROXIMO MANTENIMIENTO` +`STOCK MAXIMO` |
| **Tabla nueva** | `Repuesto_Bodega_Stock` (`rbs`) |
| **`Orden_Trabajo`** | `otr_ot_origen` · `otr_fecha_ocurrencia` · `otr_registro_posterior` · `otr_cierre_motivo` · `otr_usuario_cierre` · `otr_fecha_cierre` |
| **`Orden_Trabajo_Asignacion`** | `ota_proveedor` · `ota_asignado_por` + `CHECK` persona-o-empresa |
| **`Permiso_Trabajo`** | `ptr_archivo` + las cuatro columnas de las dos firmas + `CHECK` de autorización |
| **`Orden_Trabajo_Repuesto`** | `ore_horometro_retiro` · `ore_horometro_instalacion` · `ore_activo_medidor` |
| **`Programacion_Medidor`** | `pme_aviso_anticipacion` |
| **Función** | `FNC_USUARIO_PUEDE_CERRAR_OT` |
| **Procedimientos** | `UPD_ORDEN_TRABAJO_FINALIZAR` (técnico) · `UPD_ORDEN_TRABAJO_CERRAR` (jefatura) |
| **Vista** | `VW_PLANIFICADOR_PENDIENTE_CIERRE` — la bandeja de cierre del planificador |
| **Permisos (5)** | `CERRAR OT` · `ADJUNTAR OT EXTERNA` · `GESTIONAR STOCK` · `AUTORIZAR PERMISO TRABAJO` · `AGREGAR COMPANERO ACTIVIDAD` |
| **Perfil nuevo** | **Bodeguero** — define mínimo y máximo de stock; no compra |
| **Registro de prefijos** | 250 → **252**, cero colisiones |

---

## 13. Lo que queda abierto

Tres cosas que conviene resolver en la próxima reunión, no en noviembre:

1. **El flujo de OT externa es «solo registro».** Con eso alcanza para la defensa. Pero el informe de Vixon trae valor en UF, horas y condiciones comerciales — si algún día se quiere medir cuánto gasta Hamburgo en terceros, esos campos hay que capturarlos estructurados y no solo como PDF adjunto. El modelo lo soporta; es decisión de alcance.
2. **Quién es el prevencionista en SIGMA.** Firma permisos pero no aparece en ningún otro flujo. ¿Es un perfil con acceso, o un nombre y una fecha que transcribe el jefe desde el papel? Cambia si necesita usuario o no.
3. **Las evidencias de ejemplo que quedaron pendientes** («se adjuntarán ejemplos de las evidencias»). Con el informe de Vixon ya se pudo verificar el formato de una OT externa; faltan los ejemplos de permiso de trabajo firmado, que son los que confirmarían si dos firmas alcanzan o si hay una tercera.

---

*Fuentes de este anexo: reunión de equipo del 19-08-2026, notas del planificador Emilio (Hamburgo) del mismo día, y el informe `HAMBURGO 004-26 · Soporte Correctivo Zeppelin silo 1` de Vixon Solutions, fechado 15-08-2026.*
