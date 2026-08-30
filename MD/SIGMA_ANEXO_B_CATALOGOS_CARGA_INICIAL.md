# SIGMA — Anexo B (normativo): catálogos y valores de carga inicial

Complementa el modelo v2 y los anexos A, C y D.
**Este anexo es la fuente única de los valores de catálogo. Donde difiera de cualquier otro documento, manda este.**

Base: `db_acd593_sigma` · **79 catálogos · 482 filas** · script: `04_CATALOGOS_SIGMA.sql`

---

## 1. Regla de escritura de los datos

> **Ningún valor que llegue al front lleva guion bajo.**

| Columna | Para quién | Formato | Ejemplo |
|---|---|---|---|
| `<pfx>_codigo` | para quien lee la base | MAYÚSCULAS, **espacios**, sin tildes, sin guion bajo | `PLANIFICADOR MANTENIMIENTO` |
| `<pfx>_nombre` | **para el usuario, en pantalla** | como se escribe en español, con tildes | `Planificador de mantenimiento` |

**0 guiones bajos** en las 482 filas de los 79 catálogos, verificado por script.

### Por qué se conservan las dos columnas

Podría parecer redundante tener `codigo` y `nombre` cuando ninguno de los dos se compara (siempre se compara por `id`).
La diferencia es que **`nombre` va a cambiar y `codigo` no**:

- El día que Operaciones pida que "Crítica" se llame "Prioridad 1", se hace `UPDATE` de `nombre` y el front cambia solo.
- `codigo` es lo que el equipo lee al abrir la tabla en SSMS a las 2 de la mañana. Si cambia, se pierde la referencia.
- `nombre` es traducible; `codigo` no.

Regla que no cambia: **ni `codigo` ni `nombre` se comparan nunca en un SP ni en C#. Siempre por `id`.**

### Formato de `nombre` en pantalla

Se escribe en formato de frase (`En ejecución`), no en mayúsculas sostenidas. Si prefieres mayúsculas en el front,
se resuelve con CSS (`text-transform: uppercase`) sin tocar el dato.

---

## 2. Dos clases de catálogo

Como SIGMA es multicliente y multiindustria, la pregunta obligada es qué puede ampliar cada cliente.
**El criterio es uno solo: si el código bifurca por el valor, el catálogo es fijo.**

| | **FIJO** | **AMPLIABLE por cliente** |
|---|---|---|
| Cuántos | 69 | 10 |
| Regla | Algún `IF` o `CASE` en un SP o en C# depende de estos ids | Nadie bifurca por su valor: solo se muestran, filtran y agrupan |
| Ejemplos | estados, tipos de dato, frecuencias, operadores, políticas de cumplimiento | especialidad, tipo y posición de componente, método de diagnóstico |
| Columnas extra | ninguna | `<pfx>_cliente INT NULL` + bloque de auditoría |
| Unicidad | `UX_<PFX>_CODIGO` | `UX_<PFX>_CLIENTE_CODIGO` |
| Quién los edita | solo un script de despliegue | el planificador desde la web |

En los ampliables, **`<pfx>_cliente NULL` es la fila global de SIGMA**, válida para todos. Un cliente que
necesita `MECANICO EQUIPO PESADO` agrega su propia fila con su `cliente` y nadie más la ve.

### Los ampliables

| Catálogo | pfx | Por qué un cliente querría ampliarlo |
|---|:--:|---|
| `Archivo_Categoria` | `aca` | Cada cliente organiza sus evidencias a su manera |
| `Componente_Posicion` | `cpn` | «Lado A» sirve para un rodamiento, no para un tablero de 12 celdas |
| `Componente_Tipo` | `cto` | Los componentes mantenibles cambian por completo entre industrias |
| `Diagnostico_Metodo` | `dme` | Una planta con termografía y otra sin ella |
| `Especialidad` | `esp` | Una minera necesita «mecánico de equipo pesado»; una panificadora no |
| `Indisponibilidad_Motivo` | `inm` | Las causas de parada son propias de cada planta |
| `Permiso_Trabajo_Tipo` | `ptt` | La matriz de permisos la define Prevención de cada empresa |
| `Repuesto_Estado_Final` | `ref` | La escala de desgaste depende del tipo de pieza |
| `Repuesto_Retiro_Motivo` | `rrm` | Cada operación nombra distinto sus motivos — **con la restricción de §2.1** |
| `Servicio_Tipo` | `sti` | Los servicios contratados varían según el rubro |

### 2.1 La excepción: `Repuesto_Retiro_Motivo`

Es el único ampliable del que **sí** depende el código: separa una falla de un reemplazo preventivo, y con eso
decide si el caso entra al dataset de entrenamiento como evento o como dato censurado. Si un cliente agrega
«desmontaje por traslado» y nadie sabe a qué equivale, el modelo aprende basura.

Por eso toda fila de cliente **debe declarar a qué motivo global equivale**:

```sql
[rrm_motivo_base] INT NULL   -- FK a si misma
CONSTRAINT CK_RRM_BASE CHECK ([rrm_cliente] IS NULL OR [rrm_motivo_base] IS NOT NULL)
```

La vista de ML lee siempre `rrm_motivo_base`, nunca el motivo del cliente. Así cada empresa nombra sus
motivos como quiera sin tocar el entrenamiento.

---

## 3. Estructura

```sql
-- FIJO
[<pfx>_id]          INT             NOT NULL IDENTITY(1,1)
[<pfx>_codigo]      NVARCHAR(50)    NOT NULL      -- UX_<PFX>_CODIGO
[<pfx>_nombre]      NVARCHAR(100)   NOT NULL
[<pfx>_orden]       INT             NULL
[<pfx>_habilitado]  BIT             NOT NULL DEFAULT 1

-- AMPLIABLE: lo anterior mas
[<pfx>_cliente]     INT             NULL          -- NULL = global SIGMA
                    + bloque de auditoria completo
                    + UX_<PFX>_CLIENTE_CODIGO en vez de UX_<PFX>_CODIGO
```

Los fijos no llevan auditoría: son configuración del producto, se cargan con el script y se cambian con un script.
Los ampliables sí, porque los edita un usuario desde la aplicación.

---

## 4. Los catálogos

### 4.1 Transversales

#### `Dia_Semana` (`dse`)

Dias de la semana ISO (1 lunes).

| id | `dse_codigo` | `dse_nombre` |
|---:|---|---|
| 1 | `LUNES` | Lunes |
| 2 | `MARTES` | Martes |
| 3 | `MIERCOLES` | Miércoles |
| 4 | `JUEVES` | Jueves |
| 5 | `VIERNES` | Viernes |
| 6 | `SABADO` | Sábado |
| 7 | `DOMINGO` | Domingo |

#### `Frecuencia_Tipo` (`fre`)

Frecuencia de una programacion por calendario.

| id | `fre_codigo` | `fre_nombre` |
|---:|---|---|
| 1 | `DIARIA` | Diaria |
| 2 | `SEMANAL` | Semanal |
| 3 | `MENSUAL` | Mensual |
| 4 | `ANUAL` | Anual |

#### `Unidad_Tiempo` (`uti`)

Unidad de tiempo para intervalos.

| id | `uti_codigo` | `uti_nombre` |
|---:|---|---|
| 1 | `MINUTO` | Minuto |
| 2 | `HORA` | Hora |
| 3 | `DIA` | Día |
| 4 | `SEMANA` | Semana |
| 5 | `MES` | Mes |
| 6 | `ANIO` | Año |

#### `Operador_Comparacion` (`opc`)

Operadores de condicion y dependencia.

| id | `opc_codigo` | `opc_nombre` |
|---:|---|---|
| 1 | `IGUAL` | Igual a |
| 2 | `DISTINTO` | Distinto de |
| 3 | `MAYOR` | Mayor que |
| 4 | `MAYOR IGUAL` | Mayor o igual que |
| 5 | `MENOR` | Menor que |
| 6 | `MENOR IGUAL` | Menor o igual que |
| 7 | `ENTRE` | Entre |
| 8 | `CONTIENE` | Contiene |

#### `Severidad` (`sev`)

Escala unica de severidad.

| id | `sev_codigo` | `sev_nombre` |
|---:|---|---|
| 1 | `NORMAL` | Normal |
| 2 | `BAJA` | Baja |
| 3 | `ADVERTENCIA` | Advertencia |
| 4 | `ALTA` | Alta |
| 5 | `CRITICA` | Crítica |

#### `Tipo_Dato` (`tda`)

Tipo de dato de un atributo, variable o item.

| id | `tda_codigo` | `tda_nombre` |
|---:|---|---|
| 1 | `TEXTO` | Texto |
| 2 | `ENTERO` | Entero |
| 3 | `DECIMAL` | Decimal |
| 4 | `BIT` | Sí / No |
| 5 | `FECHA` | Fecha |
| 6 | `FECHA HORA` | Fecha y hora |
| 7 | `HORA` | Hora |

#### `Magnitud` (`mag`)

Magnitud fisica de una unidad de medida.

| id | `mag_codigo` | `mag_nombre` |
|---:|---|---|
| 1 | `TEMPERATURA` | Temperatura |
| 2 | `VIBRACION` | Vibración |
| 3 | `PRESION` | Presión |
| 4 | `VELOCIDAD ROTACION` | Velocidad de rotación |
| 5 | `CORRIENTE` | Corriente |
| 6 | `VOLTAJE` | Voltaje |
| 7 | `CAUDAL` | Caudal |
| 8 | `HUMEDAD` | Humedad |
| 9 | `TIEMPO` | Tiempo |
| 10 | `CONTEO` | Conteo |
| 11 | `LONGITUD` | Longitud |
| 12 | `MASA` | Masa |
| 13 | `VOLUMEN` | Volumen |
| 14 | `POTENCIA` | Potencia |
| 15 | `ADIMENSIONAL` | Adimensional |

#### `Moneda` (`mon`)

Monedas admitidas.

| id | `mon_codigo` | `mon_nombre` |
|---:|---|---|
| 1 | `CLP` | Peso chileno |
| 2 | `USD` | Dólar estadounidense |
| 3 | `EUR` | Euro |
| 4 | `UF` | Unidad de fomento |

#### `Criticidad_Nivel` (`crn`)

Criticidad de activo o componente.

| id | `crn_codigo` | `crn_nombre` |
|---:|---|---|
| 1 | `BAJA` | Baja |
| 2 | `MEDIA` | Media |
| 3 | `ALTA` | Alta |
| 4 | `CRITICA` | Crítica |

#### `Momento_Ejecucion` (`moe`)

Momento en que se ejecuta un checklist dentro de un trabajo.

| id | `moe_codigo` | `moe_nombre` |
|---:|---|---|
| 1 | `ANTES` | Antes |
| 2 | `DURANTE` | Durante |
| 3 | `DESPUES` | Después |

#### `Proceso_Estado` (`pes`)

Estado de un proceso asincrono (transcripcion, vision, entrenamiento, importacion).

| id | `pes_codigo` | `pes_nombre` |
|---:|---|---|
| 1 | `PENDIENTE` | Pendiente |
| 2 | `EN PROCESO` | En proceso |
| 3 | `PROCESADO` | Procesado |
| 4 | `ERROR` | Error |
| 5 | `CANCELADO` | Cancelado |


### 4.2 Organización y seguridad

#### `Instalacion_Area_Tipo` (`iat`)

Tipo de area dentro de una planta.

| id | `iat_codigo` | `iat_nombre` |
|---:|---|---|
| 1 | `AREA` | Área |
| 2 | `SUBAREA` | Subárea |
| 3 | `LINEA PRODUCCION` | Línea de producción |
| 4 | `SALA` | Sala |
| 5 | `ZONA EXTERIOR` | Zona exterior |

#### `Especialidad_Nivel` (`enl`)

Nivel de dominio de una especialidad.

| id | `enl_codigo` | `enl_nombre` |
|---:|---|---|
| 1 | `BASICO` | Básico |
| 2 | `INTERMEDIO` | Intermedio |
| 3 | `EXPERTO` | Experto |

#### `Especialidad` (`esp`) · **ampliable por cliente**

Especialidades tecnicas (globales; el cliente puede agregar).

| id | `esp_codigo` | `esp_nombre` |
|---:|---|---|
| 1 | `MECANICO` | Mecánico |
| 2 | `ELECTRICO` | Eléctrico |
| 3 | `ELECTROMECANICO` | Electromecánico |
| 4 | `INSTRUMENTISTA` | Instrumentista |
| 5 | `REFRIGERACION` | Refrigeración |
| 6 | `LIMPIEZA` | Limpieza |
| 7 | `INFRAESTRUCTURA` | Infraestructura |
| 8 | `SOLDADURA` | Soldadura |
| 9 | `AUTOMATIZACION` | Automatización |

#### `Responsabilidad_Tipo` (`rst`)

Rol de una persona en una asignacion.

| id | `rst_codigo` | `rst_nombre` |
|---:|---|---|
| 1 | `RESPONSABLE` | Responsable |
| 2 | `EJECUTOR` | Ejecutor |
| 3 | `CANDIDATO` | Candidato |
| 4 | `APOYO` | Apoyo |
| 5 | `SUPERVISOR` | Supervisor |

#### `Permiso_Ambito` (`pam`)

Donde aplica un permiso.

| id | `pam_codigo` | `pam_nombre` |
|---:|---|---|
| 1 | `WEB` | Web administrativo |
| 2 | `APP` | Aplicación móvil |
| 3 | `AMBOS` | Web y móvil |


### 4.3 Activos y mediciones

#### `Activo_Estado` (`aes`)

Estado operacional de una maquina.

| id | `aes_codigo` | `aes_nombre` |
|---:|---|---|
| 1 | `OPERATIVO` | Operativo |
| 2 | `OPERATIVO CON OBSERVACION` | Operativo con observación |
| 3 | `DETENIDO` | Detenido |
| 4 | `EN MANTENIMIENTO` | En mantenimiento |
| 5 | `FUERA DE SERVICIO` | Fuera de servicio |
| 6 | `DADO DE BAJA` | Dado de baja |

#### `Activo_Componente_Estado` (`ace`)

Estado de un componente.

| id | `ace_codigo` | `ace_nombre` |
|---:|---|---|
| 1 | `OPERATIVO` | Operativo |
| 2 | `CON OBSERVACION` | Con observación |
| 3 | `DEGRADADO` | Degradado |
| 4 | `FUERA DE SERVICIO` | Fuera de servicio |
| 5 | `RETIRADO` | Retirado |

#### `Componente_Tipo` (`cto`) · **ampliable por cliente**

Tipo de componente mantenible.

| id | `cto_codigo` | `cto_nombre` |
|---:|---|---|
| 1 | `MOTOR` | Motor |
| 2 | `REDUCTOR` | Reductor |
| 3 | `RODAMIENTO` | Rodamiento |
| 4 | `ACOPLE` | Acople |
| 5 | `CORREA` | Correa |
| 6 | `CADENA` | Cadena |
| 7 | `BOMBA` | Bomba |
| 8 | `VALVULA` | Válvula |
| 9 | `SENSOR` | Sensor |
| 10 | `TABLERO` | Tablero |
| 11 | `FILTRO` | Filtro |
| 12 | `RETEN` | Retén |
| 13 | `POLEA` | Polea |
| 14 | `OTRO` | Otro |

#### `Componente_Posicion` (`cpn`) · **ampliable por cliente**

Posicion fisica del componente dentro del activo.

| id | `cpn_codigo` | `cpn_nombre` |
|---:|---|---|
| 1 | `LADO A` | Lado A |
| 2 | `LADO B` | Lado B |
| 3 | `LADO MOTOR` | Lado motor |
| 4 | `LADO ACOPLE` | Lado acople |
| 5 | `ENTRADA` | Entrada |
| 6 | `SALIDA` | Salida |
| 7 | `SUPERIOR` | Superior |
| 8 | `INFERIOR` | Inferior |
| 9 | `IZQUIERDA` | Izquierda |
| 10 | `DERECHA` | Derecha |
| 11 | `DELANTERO` | Delantero |
| 12 | `TRASERO` | Trasero |
| 13 | `CENTRAL` | Central |
| 14 | `UNICO` | Único |

#### `Activo_Posicion_Motivo` (`apm`)

Motivo de ocupacion o liberacion de una posicion funcional.

| id | `apm_codigo` | `apm_nombre` |
|---:|---|---|
| 1 | `INSTALACION INICIAL` | Instalación inicial |
| 2 | `REEMPLAZO` | Reemplazo |
| 3 | `RESPALDO TEMPORAL` | Respaldo temporal |
| 4 | `OVERHAUL` | Overhaul |
| 5 | `BAJA` | Baja |
| 6 | `TRASLADO` | Traslado |

#### `Medicion_Calidad` (`mca`)

Calidad de una medicion.

| id | `mca_codigo` | `mca_nombre` |
|---:|---|---|
| 1 | `VALIDA` | Válida |
| 2 | `ESTIMADA` | Estimada |
| 3 | `CORREGIDA` | Corregida |
| 4 | `INVALIDA` | Inválida |

#### `Dato_Origen` (`dor`)

De donde proviene un dato capturado.

| id | `dor_codigo` | `dor_nombre` |
|---:|---|---|
| 1 | `CHECKLIST` | Checklist |
| 2 | `SENSOR` | Sensor |
| 3 | `MANUAL` | Ingreso manual |
| 4 | `ORDEN TRABAJO` | Orden de trabajo |
| 5 | `IMPORTACION` | Importación |
| 6 | `IA` | Inteligencia artificial |
| 7 | `BITACORA` | Bitácora |


### 4.4 Repuestos e inventario

#### `Repuesto_Retiro_Motivo` (`rrm`) · **ampliable por cliente**

Por que se retiro un repuesto (define el label de ML).

| id | `rrm_codigo` | `rrm_nombre` |
|---:|---|---|
| 1 | `FALLA` | Falla |
| 2 | `DESGASTE` | Desgaste |
| 3 | `PREVENTIVO` | Reemplazo preventivo |
| 4 | `MEJORA` | Mejora |
| 5 | `DANO EXTERNO` | Daño externo |
| 6 | `OBSOLESCENCIA` | Obsolescencia |
| 7 | `OTRO` | Otro |

#### `Repuesto_Estado_Final` (`ref`) · **ampliable por cliente**

Condicion observada del repuesto al retirarlo.

| id | `ref_codigo` | `ref_nombre` |
|---:|---|---|
| 1 | `BUENO` | Bueno |
| 2 | `DESGASTE LEVE` | Desgaste leve |
| 3 | `DESGASTE MODERADO` | Desgaste moderado |
| 4 | `DESGASTE SEVERO` | Desgaste severo |
| 5 | `ROTO` | Roto |
| 6 | `CORROIDO` | Corroído |
| 7 | `NO EVALUADO` | No evaluado |

#### `Inventario_Movimiento_Tipo` (`imt`)

Tipo de movimiento de inventario.

| id | `imt_codigo` | `imt_nombre` |
|---:|---|---|
| 1 | `INGRESO COMPRA` | Ingreso por compra |
| 2 | `SALIDA CONSUMO` | Salida por consumo |
| 3 | `DEVOLUCION` | Devolución |
| 4 | `AJUSTE POSITIVO` | Ajuste positivo |
| 5 | `AJUSTE NEGATIVO` | Ajuste negativo |
| 6 | `TRASLADO SALIDA` | Traslado de salida |
| 7 | `TRASLADO INGRESO` | Traslado de ingreso |
| 8 | `MERMA` | Merma |


### 4.5 Motor de programación

#### `Programacion_Tipo` (`pti`)

Como se calcula la recurrencia.

| id | `pti_codigo` | `pti_nombre` |
|---:|---|---|
| 1 | `ABIERTA` | Abierta |
| 2 | `FECHA UNICA` | Fecha única |
| 3 | `CALENDARIO` | Calendario |
| 4 | `INTERVALO TIEMPO` | Intervalo de tiempo |
| 5 | `MEDIDOR` | Por medidor |
| 6 | `CONDICION` | Por condición |


### 4.6 Planes de mantenimiento

#### `Plan_Version_Estado` (`pve`)

Ciclo de vida de una version de plan.

| id | `pve_codigo` | `pve_nombre` |
|---:|---|---|
| 1 | `BORRADOR` | Borrador |
| 2 | `PUBLICADO` | Publicado |
| 3 | `RETIRADO` | Retirado |

#### `Plan_Ocurrencia_Estado` (`poe`)

Ciclo de vida de una ocurrencia de plan (VENCIDA se calcula).

| id | `poe_codigo` | `poe_nombre` |
|---:|---|---|
| 1 | `PENDIENTE` | Pendiente |
| 2 | `DISPONIBLE` | Disponible |
| 3 | `EN EJECUCION` | En ejecución |
| 4 | `COMPLETADA` | Completada |
| 5 | `OMITIDA` | Omitida |
| 6 | `CANCELADA` | Cancelada |
| 7 | `REPROGRAMADA` | Reprogramada |


### 4.7 Checklist

#### `Checklist_Version_Estado` (`cve`)

Ciclo de vida de una version de plantilla.

| id | `cve_codigo` | `cve_nombre` |
|---:|---|---|
| 1 | `BORRADOR` | Borrador |
| 2 | `PUBLICADO` | Publicado |
| 3 | `RETIRADO` | Retirado |

#### `Checklist_Item_Tipo` (`cit`)

Tipo de item de un checklist.

| id | `cit_codigo` | `cit_nombre` |
|---:|---|---|
| 1 | `TEXTO CORTO` | Texto corto |
| 2 | `TEXTO LARGO` | Texto largo |
| 3 | `ENTERO` | Número entero |
| 4 | `DECIMAL` | Número decimal |
| 5 | `SI NO` | Sí / No |
| 6 | `FECHA` | Fecha |
| 7 | `FECHA HORA` | Fecha y hora |
| 8 | `HORA` | Hora |
| 9 | `SELECCION SIMPLE` | Selección simple |
| 10 | `SELECCION MULTIPLE` | Selección múltiple |
| 11 | `MEDICION` | Medición |
| 12 | `FOTOGRAFIA` | Fotografía |
| 13 | `AUDIO` | Audio |
| 14 | `ARCHIVO` | Archivo |
| 15 | `FIRMA` | Firma |
| 16 | `CODIGO QR` | Código QR |
| 17 | `ACTIVO` | Activo |
| 18 | `COMPONENTE` | Componente |
| 19 | `REPUESTO` | Repuesto |

#### `Checklist_Asignacion_Tipo` (`cat`)

A quien se asigna una ocurrencia.

| id | `cat_codigo` | `cat_nombre` |
|---:|---|---|
| 1 | `TECNICO` | Técnico específico |
| 2 | `VARIOS TECNICOS` | Varios técnicos |
| 3 | `CUALQUIERA PLANTA` | Cualquier técnico de la planta |
| 4 | `GRUPO` | Grupo de trabajo |

#### `Cumplimiento_Politica` (`cpo`)

Cuando se considera cumplida una ocurrencia.

| id | `cpo_codigo` | `cpo_nombre` |
|---:|---|---|
| 1 | `UNO` | La completa uno |
| 2 | `TODOS` | La completan todos |
| 3 | `MINIMO` | Cantidad mínima |

#### `Checklist_Ocurrencia_Estado` (`coe`)

Ciclo de vida de una ocurrencia de checklist (VENCIDA se calcula).

| id | `coe_codigo` | `coe_nombre` |
|---:|---|---|
| 1 | `PENDIENTE` | Pendiente |
| 2 | `DISPONIBLE` | Disponible |
| 3 | `EN EJECUCION` | En ejecución |
| 4 | `COMPLETADA` | Completada |
| 5 | `OMITIDA` | Omitida |
| 6 | `CANCELADA` | Cancelada |
| 7 | `REPROGRAMADA` | Reprogramada |

#### `Checklist_Ejecucion_Estado` (`cee`)

Ciclo de vida de una ejecucion.

| id | `cee_codigo` | `cee_nombre` |
|---:|---|---|
| 1 | `BORRADOR` | Borrador |
| 2 | `SINCRONIZANDO` | Sincronizando |
| 3 | `ENVIADA` | Enviada |
| 4 | `VALIDADA` | Validada |
| 5 | `RECHAZADA` | Rechazada |
| 6 | `ANULADA` | Anulada |

#### `Checklist_Respuesta_Estado` (`cre`)

Estado de una respuesta individual.

| id | `cre_codigo` | `cre_nombre` |
|---:|---|---|
| 1 | `RESPONDIDA` | Respondida |
| 2 | `NO APLICA` | No aplica |
| 3 | `OMITIDA` | Omitida |

#### `Dependencia_Accion` (`dac`)

Que hace una dependencia entre items.

| id | `dac_codigo` | `dac_nombre` |
|---:|---|---|
| 1 | `MOSTRAR` | Mostrar |
| 2 | `OCULTAR` | Ocultar |
| 3 | `REQUERIR` | Requerir |
| 4 | `BLOQUEAR` | Bloquear |


### 4.8 Tareas

#### `Tarea_Prioridad` (`tpa`)

Prioridad de una tarea.

| id | `tpa_codigo` | `tpa_nombre` |
|---:|---|---|
| 1 | `BAJA` | Baja |
| 2 | `MEDIA` | Media |
| 3 | `ALTA` | Alta |
| 4 | `CRITICA` | Crítica |

#### `Tarea_Ocurrencia_Estado` (`toe`)

Ciclo de vida de una ocurrencia de tarea (VENCIDA se calcula).

| id | `toe_codigo` | `toe_nombre` |
|---:|---|---|
| 1 | `PENDIENTE` | Pendiente |
| 2 | `ACEPTADA` | Aceptada |
| 3 | `EN EJECUCION` | En ejecución |
| 4 | `COMPLETADA` | Completada |
| 5 | `NO REALIZADA` | No realizada |
| 6 | `CANCELADA` | Cancelada |
| 7 | `REPROGRAMADA` | Reprogramada |


### 4.9 Órdenes de trabajo y fallas

#### `Orden_Trabajo_Tipo` (`ott`)

Tipo de mantenimiento.

| id | `ott_codigo` | `ott_nombre` |
|---:|---|---|
| 1 | `PREVENTIVA` | Preventiva |
| 2 | `CORRECTIVA` | Correctiva |
| 3 | `PREDICTIVA` | Predictiva |

#### `Orden_Trabajo_Estrategia` (`oet`)

Estrategia dentro del tipo.

| id | `oet_codigo` | `oet_nombre` |
|---:|---|---|
| 1 | `RUTINARIO` | Rutinario |
| 2 | `PROGRAMADO` | Programado |
| 3 | `EMERGENCIA` | Emergencia |
| 4 | `INSPECCION` | Inspección |
| 5 | `OVERHAUL` | Overhaul |
| 6 | `MEJORA` | Mejora |

#### `Orden_Trabajo_Origen` (`oto`)

Que activo la OT.

| id | `oto_codigo` | `oto_nombre` |
|---:|---|---|
| 1 | `MANUAL` | Manual |
| 2 | `PLAN` | Plan de mantenimiento |
| 3 | `TAREA` | Tarea |
| 4 | `HALLAZGO CHECKLIST` | Hallazgo de checklist |
| 5 | `PREDICCION` | Predicción |
| 6 | `ALERTA` | Alerta |
| 7 | `FALLA` | Falla |
| 8 | `BITACORA` | Bitácora |
| 9 | `HALLAZGO EN OT` | Hallazgo durante otra orden de trabajo |

#### `Orden_Trabajo_Estado` (`ote`)

Ciclo de vida de la OT. Solo cuatro..

| id | `ote_codigo` | `ote_nombre` |
|---:|---|---|
| 1 | `ABIERTA` | Abierta |
| 2 | `EN EJECUCION` | En ejecución |
| 3 | `EN ESPERA DE CIERRE` | En espera de cierre |
| 4 | `CERRADA` | Cerrada |

#### `Orden_Trabajo_Cierre_Motivo` (`ocm`)

Por que se cerro la OT.

| id | `ocm_codigo` | `ocm_nombre` |
|---:|---|---|
| 1 | `TRABAJO REALIZADO` | Trabajo realizado |
| 2 | `SIN HALLAZGO` | Sin hallazgo, no requirió intervención |
| 3 | `RESUELTA EN OTRA OT` | Resuelta en otra orden de trabajo |
| 4 | `DUPLICADA` | Duplicada |
| 5 | `ANULADA POR ERROR` | Anulada por error de registro |
| 6 | `NO APLICA` | No aplica |

#### `Orden_Trabajo_Prioridad` (`opr`)

Prioridad de la OT.

| id | `opr_codigo` | `opr_nombre` |
|---:|---|---|
| 1 | `BAJA` | Baja |
| 2 | `MEDIA` | Media |
| 3 | `ALTA` | Alta |
| 4 | `CRITICA` | Crítica |

#### `Rol_Ejecucion` (`rej`)

Rol de un asignado en la ejecucion.

| id | `rej_codigo` | `rej_nombre` |
|---:|---|---|
| 1 | `EJECUTOR PRINCIPAL` | Ejecutor principal |
| 2 | `APOYO` | Apoyo |
| 3 | `SUPERVISOR` | Supervisor |
| 4 | `OBSERVADOR` | Observador |

#### `Validacion_Tipo` (`vat`)

Las tres firmas del formato de OT.

| id | `vat_codigo` | `vat_nombre` |
|---:|---|---|
| 1 | `ACEPTACION` | Aceptación |
| 2 | `VALIDACION` | Validación |
| 3 | `EJECUCION` | Ejecución |

#### `Resultado_Paso` (`rpa`)

Resultado de un paso de OT.

| id | `rpa_codigo` | `rpa_nombre` |
|---:|---|---|
| 1 | `CONFORME` | Conforme |
| 2 | `NO CONFORME` | No conforme |
| 3 | `NO APLICA` | No aplica |
| 4 | `PENDIENTE` | Pendiente |

#### `Servicio_Tipo` (`sti`) · **ampliable por cliente**

Tipo de servicio contratado a un proveedor.

| id | `sti_codigo` | `sti_nombre` |
|---:|---|---|
| 1 | `SERVICIO TECNICO` | Servicio técnico |
| 2 | `ARRIENDO EQUIPO` | Arriendo de equipo |
| 3 | `MONTAJE` | Montaje |
| 4 | `DESMONTAJE` | Desmontaje |
| 5 | `MANO OBRA EXTERNA` | Mano de obra externa |
| 6 | `REPUESTO` | Repuesto |
| 7 | `TRANSPORTE` | Transporte |
| 8 | `CALIBRACION` | Calibración |

#### `Indisponibilidad_Motivo` (`inm`) · **ampliable por cliente**

Por que el activo estuvo detenido.

| id | `inm_codigo` | `inm_nombre` |
|---:|---|---|
| 1 | `MANTENIMIENTO PLANIFICADO` | Mantenimiento planificado |
| 2 | `FALLA` | Falla |
| 3 | `ESPERA REPUESTO` | Espera de repuesto |
| 4 | `ESPERA TECNICO` | Espera de técnico |
| 5 | `CAUSA EXTERNA` | Causa externa |
| 6 | `PARADA PRODUCCION` | Parada de producción |

#### `Permiso_Trabajo_Tipo` (`ptt`) · **ampliable por cliente**

Tipo de permiso de trabajo.

| id | `ptt_codigo` | `ptt_nombre` |
|---:|---|---|
| 1 | `ALTURA` | Trabajo en altura |
| 2 | `ESPACIO CONFINADO` | Espacio confinado |
| 3 | `TRABAJO CALIENTE` | Trabajo caliente |
| 4 | `ELECTRICO` | Trabajo eléctrico |
| 5 | `IZAJE` | Izaje |
| 6 | `BLOQUEO ENERGIA` | Bloqueo de energía |

#### `Permiso_Trabajo_Estado` (`pte`)

Ciclo de vida del permiso.

| id | `pte_codigo` | `pte_nombre` |
|---:|---|---|
| 1 | `SOLICITADO` | Solicitado |
| 2 | `AUTORIZADO` | Autorizado |
| 3 | `RECHAZADO` | Rechazado |
| 4 | `VENCIDO` | Vencido |
| 5 | `CERRADO` | Cerrado |

#### `Diagnostico_Metodo` (`dme`) · **ampliable por cliente**

Como se diagnostico la falla.

| id | `dme_codigo` | `dme_nombre` |
|---:|---|---|
| 1 | `INSPECCION VISUAL` | Inspección visual |
| 2 | `MEDICION` | Medición |
| 3 | `ANALISIS VIBRACION` | Análisis de vibración |
| 4 | `TERMOGRAFIA` | Termografía |
| 5 | `ANALISIS ACEITE` | Análisis de aceite |
| 6 | `ULTRASONIDO` | Ultrasonido |
| 7 | `DESARME` | Desarme |
| 8 | `HISTORIAL` | Historial |
| 9 | `ANALISIS IA` | Análisis con IA |


### 4.10 Bitácora

#### `Bitacora_Tipo` (`bti`)

Tipo de registro libre del tecnico.

| id | `bti_codigo` | `bti_nombre` |
|---:|---|---|
| 1 | `OBSERVACION` | Observación |
| 2 | `NOVEDAD` | Novedad |
| 3 | `INCIDENTE` | Incidente |
| 4 | `CAMBIO TURNO` | Cambio de turno |
| 5 | `HALLAZGO` | Hallazgo |


### 4.11 Archivos y análisis visual

#### `Archivo_Categoria` (`aca`) · **ampliable por cliente**

Para que sirve el archivo.

| id | `aca_codigo` | `aca_nombre` |
|---:|---|---|
| 1 | `ESTADO MAQUINA` | Estado de la máquina |
| 2 | `FALLA` | Falla |
| 3 | `REPUESTO DETERIORADO` | Repuesto deteriorado |
| 4 | `ANTES` | Antes |
| 5 | `DURANTE` | Durante |
| 6 | `DESPUES` | Después |
| 7 | `BITACORA` | Bitácora |
| 8 | `FIRMA` | Firma |
| 9 | `DOCUMENTO` | Documento |
| 10 | `REFERENCIA` | Imagen de referencia |
| 11 | `AUDIO` | Audio |

#### `Archivo_Antivirus_Estado` (`aae`)

Resultado del escaneo del archivo.

| id | `aae_codigo` | `aae_nombre` |
|---:|---|---|
| 1 | `PENDIENTE` | Pendiente |
| 2 | `LIMPIO` | Limpio |
| 3 | `INFECTADO` | Infectado |
| 4 | `ERROR` | Error |

#### `Archivo_Carga_Estado` (`acs`)

Estado de una carga reanudable desde la app.

| id | `acs_codigo` | `acs_nombre` |
|---:|---|---|
| 1 | `INICIADA` | Iniciada |
| 2 | `EN CURSO` | En curso |
| 3 | `COMPLETADA` | Completada |
| 4 | `EXPIRADA` | Expirada |
| 5 | `CANCELADA` | Cancelada |


### 4.12 Alertas

#### `Alerta_Tipo` (`alt`)

Que origino la alerta.

| id | `alt_codigo` | `alt_nombre` |
|---:|---|---|
| 1 | `MEDICION FUERA RANGO` | Medición fuera de rango |
| 2 | `HALLAZGO CRITICO` | Hallazgo crítico |
| 3 | `OCURRENCIA VENCIDA` | Ocurrencia vencida |
| 4 | `PREDICCION RIESGO` | Predicción de riesgo |
| 5 | `STOCK MINIMO` | Stock bajo el mínimo |
| 6 | `PERMISO VENCIDO` | Permiso vencido |
| 7 | `MEDIDOR SIN LECTURA` | Medidor sin lectura |
| 9 | `MEDIDOR PROXIMO MANTENIMIENTO` | Se acerca la hora de mantenimiento |
| 10 | `STOCK MAXIMO` | Stock sobre el máximo |
| 8 | `DESCUBRIMIENTO TERRENO` | Registro creado en terreno sin revisar |

#### `Alerta_Estado` (`aet`)

Ciclo de vida de la alerta.

| id | `aet_codigo` | `aet_nombre` |
|---:|---|---|
| 1 | `NUEVA` | Nueva |
| 2 | `RECONOCIDA` | Reconocida |
| 3 | `EN GESTION` | En gestión |
| 4 | `RESUELTA` | Resuelta |
| 5 | `DESCARTADA` | Descartada |


### 4.13 Machine learning

#### `Modelo_Objetivo` (`mob`)

Que predice el modelo.

| id | `mob_codigo` | `mob_nombre` |
|---:|---|---|
| 1 | `PROBABILIDAD FALLA` | Probabilidad de falla |
| 2 | `VIDA UTIL RESTANTE` | Vida útil restante |
| 3 | `DETECCION ANOMALIA` | Detección de anomalía |
| 4 | `CLASIFICACION VISUAL` | Clasificación visual |

#### `Modelo_Formato` (`mfo`)

Formato del artefacto del modelo.

| id | `mfo_codigo` | `mfo_nombre` |
|---:|---|---|
| 1 | `ONNX` | ONNX |
| 2 | `PICKLE` | Pickle |
| 3 | `PMML` | PMML |
| 4 | `SAVEDMODEL` | SavedModel |

#### `Nivel_Riesgo` (`nri`)

Nivel de riesgo de una prediccion.

| id | `nri_codigo` | `nri_nombre` |
|---:|---|---|
| 1 | `BAJO` | Bajo |
| 2 | `MEDIO` | Medio |
| 3 | `ALTO` | Alto |
| 4 | `CRITICO` | Crítico |

#### `Prediccion_Estado` (`pde`)

Ciclo de vida de una prediccion.

| id | `pde_codigo` | `pde_nombre` |
|---:|---|---|
| 1 | `GENERADA` | Generada |
| 2 | `REVISADA` | Revisada |
| 3 | `ACEPTADA` | Aceptada |
| 4 | `DESCARTADA` | Descartada |
| 5 | `MATERIALIZADA` | Materializada |

#### `Caracteristica_Tipo` (`ctm`)

Tipo de feature del modelo.

| id | `ctm_codigo` | `ctm_nombre` |
|---:|---|---|
| 1 | `NUMERICA` | Numérica |
| 2 | `CATEGORICA` | Categórica |
| 3 | `BINARIA` | Binaria |
| 4 | `TEMPORAL` | Temporal |
| 5 | `DERIVADA` | Derivada |


### 4.14 Importación y descubrimiento

#### `Importacion_Tipo` (`iti`)

Que se esta importando.

| id | `iti_codigo` | `iti_nombre` |
|---:|---|---|
| 1 | `MATRIZ OT` | Matriz de OT |
| 2 | `PLAN ANUAL` | Plan anual |
| 3 | `ACTIVOS` | Activos |
| 4 | `REPUESTOS` | Repuestos |
| 5 | `LECTURAS MEDIDOR` | Lecturas de medidor |
| 6 | `MEDICIONES` | Mediciones |

#### `Importacion_Celda_Estado` (`ice`)

Como quedo cada celda leida.

| id | `ice_codigo` | `ice_nombre` |
|---:|---|---|
| 1 | `OK` | Correcta |
| 2 | `AMBIGUO` | Ambigua |
| 3 | `ERROR` | Con error |
| 4 | `IGNORADO` | Ignorada |

#### `Registro_Origen` (`ror`)

Como nacio un registro de maestro.

| id | `ror_codigo` | `ror_nombre` |
|---:|---|---|
| 1 | `CARGA INICIAL` | Carga inicial |
| 2 | `PLANIFICADOR WEB` | Planificador desde la web |
| 3 | `TERRENO ORDEN TRABAJO` | Terreno, durante una orden de trabajo |
| 4 | `TERRENO TAREA` | Terreno, durante una tarea |
| 5 | `TERRENO CHECKLIST` | Terreno, durante un checklist |
| 6 | `TERRENO BITACORA` | Terreno, desde la bitácora |
| 7 | `IMPORTACION EXCEL` | Importación desde Excel |
| 8 | `API EXTERNA` | API externa |


### 4.15 Voz e inclusión

#### `Entrada_Modo` (`emo`)

Como se ingreso un dato.

| id | `emo_codigo` | `emo_nombre` |
|---:|---|---|
| 1 | `TECLADO` | Teclado |
| 2 | `VOZ` | Dictado por voz |
| 3 | `SELECCION` | Selección de lista |
| 4 | `ESCANEO QR` | Escaneo de QR |
| 5 | `SENSOR` | Sensor |
| 6 | `IMPORTACION` | Importación |


### 4.16 Modelo comercial

#### `Funcionalidad_Tipo` (`fnt`)

Si la funcionalidad se incluye o se limita.

| id | `fnt_codigo` | `fnt_nombre` |
|---:|---|---|
| 1 | `INCLUSION` | Se incluye o no |
| 2 | `LIMITE` | Tiene un tope numérico |

#### `Funcionalidad` (`fun`)

Que puede hacer un cliente segun su plan.

| id | `fun_codigo` | `fun_nombre` |
|---:|---|---|
| 1 | `GESTION ACTIVOS` | Gestión de activos y componentes |
| 2 | `CHECKLIST DINAMICO` | Checklist dinámico |
| 3 | `TAREAS` | Tareas |
| 4 | `ORDEN TRABAJO` | Órdenes de trabajo |
| 5 | `PLAN MANTENIMIENTO` | Planes de mantenimiento |
| 6 | `PROGRAMACION CALENDARIO` | Programación por calendario |
| 7 | `PROGRAMACION MEDIDOR` | Programación por horómetro o ciclos |
| 8 | `BITACORA` | Bitácora del técnico |
| 9 | `EVIDENCIA FOTOGRAFICA` | Evidencia fotográfica |
| 10 | `REGISTRO TERRENO` | Registro de maestros desde terreno |
| 11 | `CREACION POR VOZ` | Creación y dictado por voz |
| 12 | `LECTURA POR VOZ` | Lectura en voz alta e inclusión |
| 13 | `IMPORTACION EXCEL` | Importación desde Excel |
| 14 | `INVENTARIO REPUESTOS` | Inventario de repuestos |
| 15 | `SERVICIOS EXTERNOS` | Proveedores y servicios contratados |
| 16 | `PERMISO TRABAJO` | Permisos de trabajo |
| 17 | `ANALISIS VISUAL` | Análisis visual de fotografías |
| 18 | `ANALISIS PREDICTIVO` | Predicción de fallas |
| 19 | `VIDA UTIL RESTANTE` | Estimación de vida útil restante |
| 20 | `API EXTERNA` | API para integrar con otros sistemas |
| 21 | `INDICADORES AVANZADOS` | Indicadores avanzados y exportación |
| 22 | `LIMITE PLANTAS` | Máximo de plantas |
| 23 | `LIMITE USUARIOS` | Máximo de usuarios |
| 24 | `LIMITE ACTIVOS` | Máximo de activos |
| 25 | `LIMITE ALMACENAMIENTO` | Máximo de almacenamiento en GB |

#### `Periodicidad_Cobro` (`pcb`)

Cada cuanto se renueva la suscripcion.

| id | `pcb_codigo` | `pcb_nombre` |
|---:|---|---|
| 1 | `MENSUAL` | Mensual |
| 2 | `TRIMESTRAL` | Trimestral |
| 3 | `ANUAL` | Anual |

#### `Suscripcion_Estado` (`sue`)

Estado administrativo de la suscripcion (VENCIDA se calcula).

| id | `sue_codigo` | `sue_nombre` |
|---:|---|---|
| 1 | `ACTIVA` | Activa |
| 2 | `SUSPENDIDA` | Suspendida |
| 3 | `CANCELADA` | Cancelada |

#### `Suscripcion_Periodo_Estado` (`spd`)

Ciclo de vida de un periodo de suscripcion.

| id | `spd_codigo` | `spd_nombre` |
|---:|---|---|
| 1 | `PENDIENTE PAGO` | Pendiente de pago |
| 2 | `PAGO PARCIAL` | Con abono parcial |
| 3 | `VIGENTE` | Vigente |
| 4 | `CERRADO` | Cerrado |
| 5 | `ANULADO` | Anulado |

#### `Suscripcion_Pago_Estado` (`spo`)

Ciclo de vida de un abono.

| id | `spo_codigo` | `spo_nombre` |
|---:|---|---|
| 1 | `DECLARADO` | Declarado por el cliente |
| 2 | `EN REVISION` | En revisión |
| 3 | `VERIFICADO` | Verificado |
| 4 | `RECHAZADO` | Rechazado |

#### `Uf_Origen` (`ufo`)

De donde se obtuvo el valor de la UF.

| id | `ufo_codigo` | `ufo_nombre` |
|---:|---|---|
| 1 | `SII` | Servicio de Impuestos Internos |
| 2 | `API EXTERNA` | API externa |
| 3 | `MANUAL` | Carga manual |
| 4 | `ARRASTRE` | Arrastre del último valor conocido |


### 4.17 Costo de operación

#### `Proveedor_Nube` (`pvn`)

Quien presta cada servicio de infraestructura.

| id | `pvn_codigo` | `pvn_nombre` |
|---:|---|---|
| 1 | `SMARTERASP` | SmarterASP.NET |
| 2 | `AZURE` | Microsoft Azure |
| 3 | `GOOGLE PLAY` | Google Play |
| 4 | `EQUIPO PROPIO` | Equipo propio, sin costo de nube |

#### `Servicio_Nube` (`snu`)

Servicio de infraestructura que genera costo.

| id | `snu_codigo` | `snu_nombre` |
|---:|---|---|
| 1 | `BASE DE DATOS` | Base de datos SQL Server |
| 2 | `ALMACENAMIENTO ARCHIVOS` | Almacenamiento de fotos y adjuntos |
| 3 | `HOSTING WEB` | Hosting del sitio web y la API |
| 4 | `SPEECH STT` | Voz a texto |
| 5 | `SPEECH TTS` | Texto a voz |
| 6 | `ML ENTRENAMIENTO` | Entrenamiento de modelos predictivos |
| 7 | `VISION` | Análisis visual de imágenes |
| 8 | `FUNCIONES PROGRAMADAS` | Trabajos automáticos programados |
| 9 | `ANCHO DE BANDA` | Transferencia de datos de salida |
| 10 | `DISTRIBUCION APP` | Publicación de la app en la tienda |

#### `Unidad_Consumo` (`ucn`)

En que se mide el consumo de cada servicio.

| id | `ucn_codigo` | `ucn_nombre` |
|---:|---|---|
| 1 | `VCORE SEGUNDO` | vCore-segundo |
| 2 | `GIGABYTE MES` | GB-mes |
| 3 | `HORA AUDIO` | Hora de audio |
| 4 | `CARACTER` | Carácter |
| 5 | `MINUTO CPU` | Minuto de CPU |
| 6 | `TRANSACCION` | Transacción |
| 7 | `HORA COMPUTO` | Hora de cómputo |
| 8 | `GIGABYTE` | GB transferido |
| 9 | `MES` | Mes de servicio |
| 10 | `PAGO UNICO` | Pago único |

#### `Voz_Motor` (`vmo`)

Donde se proceso la voz de cada dictado.

| id | `vmo_codigo` | `vmo_nombre` |
|---:|---|---|
| 1 | `DISPOSITIVO` | En el teléfono, sin costo y sin señal |
| 2 | `AZURE SPEECH` | En la nube. No se usa: queda para trazabilidad futura |


---

## 5. Perfiles — no es un catálogo nuevo

`Perfiles` (`per`) **ya existe** en la base. No se crea: se le agregan las filas que el modelo necesita,
reutilizando las que ya estén (`CONVENCIONES.md` §6).

| `per_nombre` sugerido | Habilita |
|---|---|
| Planificador de mantenimiento | planificación, publicación de planes, programaciones, asignaciones y asignar permisos de terreno |
| Técnico | bandeja y ejecución desde la app Flutter |
| Supervisor de mantenimiento | validación de OT |
| Jefe de mantenimiento | aceptación de OT y visión completa |

> Los tres permisos de terreno **no** se otorgan por perfil: van por usuario. Ver Anexo D.

---

## 6. Qué queda sustituido

| Documento | Sección | Estado |
|---|---|---|
| Anexo A | §2.3 (catálogos con su carga) | **Sustituida** por §4 de este anexo |
| Anexo A | §2.5, `aco_posicion` como texto | **Sustituida** por Anexo C §4: pasa a `Componente_Posicion` |
| Modelo v2 | §8.5 a §8.9 (catálogos citados en línea) | **Sustituidos** por §4 |
| Modelo v2 | `VENCIDA` en `poe`, `coe`, `toe` | **Eliminada** — se calcula (Anexo A §3.3) |

---

## 7. Verificación

| Comprobación | Resultado |
|---|---|
| Catálogos | 79 — 69 fijos, 10 ampliables |
| Filas de carga inicial | 482 |
| Guiones bajos en `codigo` o `nombre` | **0** |
| Tildes en `codigo` | **0** |
| Ids no correlativos desde 1 | **0** |
| Ampliables sin columna `_cliente` | **0** |
| Prefijos que no calzan con el registro | **0** |

---

*Generado junto con `04_CATALOGOS_SIGMA.sql` desde una única definición, para que documento y script no se separen.*