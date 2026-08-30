# SIGMA — Anexo E (normativo): voz e inclusión

Cómo el técnico opera la app **sin escribir y sin leer**: con las manos sucias, con guantes, o sin saber leer.

Complementa el modelo v2 y los anexos A a D. Base: `db_acd593_sigma` · sin datos.

---

## 1. Son dos problemas distintos

Se parecen y se resuelven con tecnología parecida, pero no son lo mismo, y confundirlos deja a la mitad de la gente fuera.

| | **Manos ocupadas** | **No sabe leer ni escribir** |
|---|---|---|
| Quién | Cualquier técnico con aceite, guantes o una llave en la mano | Un porcentaje real de la mano de obra de mantenimiento en planta |
| Puede leer la pantalla | Sí | **No** |
| Qué necesita | Dictar en vez de teclear | Dictar **y que le lean** |
| Si solo damos dictado | Resuelto | **Sigue sin poder responder un checklist ni confirmar lo que el sistema entendió** |

Por eso el alcance es **voz completa en los dos sentidos**: entrada por dictado y salida por lectura en voz alta, más íconos en todo lo que el técnico elige.

> **Una decisión de lenguaje.** No existe ninguna columna que diga que una persona no sabe leer. Lo que se guarda son **preferencias de interfaz**: «leer en voz alta», «texto grande», «confirmar hablando». Describen lo que hace la aplicación, no lo que le falta a la persona. Además sirven a alguien con presbicia, a alguien con guantes gruesos y a alguien en una sala con 95 dB — que son muchos más casos que el original.

---

## 2. Decisión tomada: no se guarda el audio

El audio del técnico **no se almacena**. Se transcribe y se descarta.

Eso tiene una consecuencia que manda sobre todo el diseño del flujo:

> **Si no hay audio guardado, la única oportunidad de corregir es antes de descartarlo.** No se puede volver a escuchar después. Entonces la confirmación tiene que ocurrir en el dispositivo, en el momento, y tiene que funcionar para alguien que no puede leer lo transcrito.

De ahí sale el **ciclo cerrado de confirmación hablada**:

```text
1. El tecnico habla        "hay un ruido metalico en el rodamiento del lado A"
2. El dispositivo transcribe
3. SIGMA LE LEE lo que entendio, en voz alta
                           "Entendi: ruido metalico, rodamiento lado A,
                            blower CB01. Confirma?"
4. El tecnico responde     "si"    -> se guarda
                           "no"    -> se descarta y vuelve al paso 1
5. El audio se descarta. Queda la transcripcion confirmada.
```

El paso 3 no es un adorno de accesibilidad: **es el control de calidad del dato**. Sin él, una transcripción errada entra al historial y nadie se entera nunca.

---

## 3. `Dictado_Voz` (`dvo`)

Una fila por dictado confirmado. Reemplaza a `Archivo_Transcripcion` (`atr`), que se elimina: tenía sentido cuando el audio se guardaba como archivo, y ahora no hay archivo.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `dvo_uuid` | `UNIQUEIDENTIFIER` | NO | DF `NEWID()`, UX — idempotencia del reintento offline |
| `dvo_cliente` | `INT` | NO | FK `Cliente` |
| `dvo_usuario` | `INT` | NO | quién dictó |
| `dvo_fecha_utc` | `DATETIME` | NO | instante del dictado, no de la sincronización |
| `dvo_archivo` | `INT` | SÍ | **normalmente NULL** — solo si el cliente decide conservar el audio |
| `dvo_motor` | `NVARCHAR(100)` | NO | identificador del motor del dispositivo, p. ej. `android-speech-recognizer` |
| `dvo_voz_motor` | `INT` | NO | FK `Voz_Motor`, DF **DISPOSITIVO** — dónde se procesó |
| `dvo_modelo_version` | `NVARCHAR(100)` | SÍ | qué versión transcribió |
| `dvo_idioma` | `INT` | NO | FK `Idioma` — `es-CL` |
| `dvo_texto` | `NVARCHAR(MAX)` | NO | **lo que el técnico confirmó**, no el primer intento |
| `dvo_confianza` | `DECIMAL(18,6)` | SÍ | confianza del motor |
| `dvo_duracion_segundo` | `INT` | SÍ | |
| `dvo_intentos` | `INT` | NO | DF 1 — cuántas veces tuvo que repetir |
| `dvo_confirmado` | `BIT` | NO | DF 0 — **nada se guarda sin esto en 1** |
| `dvo_confirmado_por_voz` | `BIT` | NO | DF 0 — confirmó hablando, no tocando |
| `dvo_fecha_confirmacion_utc` | `DATETIME` | SÍ | |
| `dvo_dispositivo_uuid` | `UNIQUEIDENTIFIER` | SÍ | |
| `dvo_proceso_estado` | `INT` | NO | FK `Proceso_Estado` |
| AUD-A | | | append-only |

**`dvo_intentos` es la métrica que importa.** Si el promedio sube, el reconocimiento está fallando en esa planta — ruido, acento, vocabulario técnico — y hay que ajustar el modelo o entrenar vocabulario. Sin esa columna, el problema es invisible: el técnico simplemente deja de usar la voz y nadie sabe por qué.

### Dónde se engancha

Cuatro FK anulables, una por entidad que puede nacer de un dictado. Mismo criterio que en `Registro_Descubrimiento` y en `Orden_Trabajo`: FK explícitas, no un par `tipo/id`.

| Tabla | Columna | Qué se dicta |
|---|---|---|
| `Orden_Trabajo` | `otr_dictado_voz` | la descripción de una OT correctiva creada en planta |
| `Checklist_Ejecucion_Respuesta` | `cer_dictado_voz` | la observación de una respuesta |
| `Bitacora` | `bit_dictado_voz` | el registro libre completo |
| `Falla` | `fal_dictado_voz` | la descripción del síntoma observado |

---

## 4. Lo que **no** es dictado: elegir con la voz

Buena parte de lo que el técnico hace no es texto libre: es **elegir de un catálogo** o **decir un número**. Eso no necesita transcripción guardada, necesita saber que el valor entró hablando.

```text
SIGMA lee:      "Que tipo de componente?"
                "Uno: rodamiento. Dos: correa. Tres: reten. Cuatro: polea."
El tecnico:     "rodamiento"
SIGMA:          "Rodamiento. En que posicion?"
```

Para eso basta una columna, no una tabla:

**`Entrada_Modo` (`emo`)** — catálogo: `TECLADO` · `VOZ` · `SELECCION` · `ESCANEO QR` · `SENSOR` · `IMPORTACION`

Se agrega `<pfx>_entrada_modo INT NULL` en las cinco tablas donde el modo de captura afecta la confianza del dato:

| Tabla | Por qué importa |
|---|---|
| `Activo_Medicion` | «setenta y ocho coma cuatro» → 78,4. Un dato dictado que alimenta modelos de ML **tiene que ser auditable por su modo de entrada** |
| `Activo_Medidor_Lectura` | ídem, y una lectura de horómetro mal entendida dispara una mantención que no toca |
| `Checklist_Ejecucion_Respuesta` | permite medir en qué ítems la voz falla más |
| `Orden_Trabajo` | saber cuántas OT nacen dictadas mide la adopción real |
| `Bitacora` | ídem |

### La regla de los números

Un número dictado **siempre se lee de vuelta antes de guardarse**, dígito por dígito si hace falta:

```text
Tecnico:   "setenta y ocho coma cuatro"
SIGMA:     "Setenta y ocho coma cuatro grados. Siete, ocho, coma, cuatro. Correcto?"
```

Es más lento y vale la pena: una medición es un dato que después entra a una serie temporal y a un entrenamiento. Un `784` en vez de `78,4` no lo detecta nadie tres meses después.

---

## 5. `Usuario_Accesibilidad` (`uac`)

Preferencias de interfaz, una fila por persona. Son de la **persona**, no del cliente: alguien que trabaja para dos empresas las lleva a las dos.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `uac_usuario` | `INT` | NO | **UX** — una fila por usuario |
| `uac_entrada_voz` | `BIT` | NO | DF 0 — el botón de dictar aparece primero |
| `uac_lectura_voz` | `BIT` | NO | DF 0 — la app lee preguntas, opciones y confirmaciones |
| `uac_confirmacion_hablada` | `BIT` | NO | DF 0 — confirma diciendo «sí», no tocando |
| `uac_velocidad_voz` | `DECIMAL(18,2)` | NO | DF 1.00 — 0,8 más lento, 1,2 más rápido |
| `uac_texto_grande` | `BIT` | NO | DF 0 |
| `uac_alto_contraste` | `BIT` | NO | DF 0 |
| `uac_iconos_grandes` | `BIT` | NO | DF 0 — listas con ícono grande y texto mínimo |
| `uac_idioma` | `INT` | SÍ | FK `Idioma` |
| AUD-M | | | |

Las tres primeras juntas dan el modo completo: **dictar, escuchar, confirmar hablando**. Un técnico que no lee marca las tres y no vuelve a ver un campo de texto.

---

## 6. Íconos: lo que hace posible elegir sin leer

Un catálogo que el técnico usa en terreno necesita **imagen**, no solo nombre. Se agregan dos columnas a los catálogos que se muestran en la app:

```sql
[<pfx>_icono]   NVARCHAR(50)  NULL   -- nombre del icono del set de la app
[<pfx>_archivo] INT           NULL   -- FK Archivo: foto real, para filas de cliente
```

`_icono` sirve para los valores globales, que la app trae dibujados. `_archivo` sirve para lo que cada cliente agrega: una minera que crea el componente `CHANCADOR` sube una foto y sus técnicos la reconocen aunque no puedan leer la palabra.

Catálogos que las llevan: `Componente_Tipo`, `Componente_Posicion`, `Repuesto_Retiro_Motivo`, `Repuesto_Estado_Final`, `Severidad`, `Criticidad_Nivel`, `Bitacora_Tipo`, `Activo_Estado`, `Activo_Componente_Estado`, `Resultado_Paso`, `Indisponibilidad_Motivo`, `Archivo_Categoria`.

> **Una foto real gana a un ícono abstracto.** Para alguien que no lee, la fotografía de un rodamiento desgastado es más reconocible que cualquier pictograma. Por eso `_archivo` no es un lujo: es el mecanismo principal para los valores propios de cada cliente.

### Lo que ya estaba resuelto sin saberlo

La decisión de escribir `<pfx>_nombre` en formato de frase con tildes correctas — que tomamos por el front — **es exactamente lo que necesita la síntesis de voz**. `En ejecución` se lee bien; `EN_EJECUCION` se lee como deletreo. No hay que agregar una columna «texto para leer»: el nombre ya sirve.

La única excepción es el checklist, donde una pregunta escrita puede traer abreviaturas o unidades que se leen mal:

```sql
[cpi_pregunta_voz] NVARCHAR(500) NULL   -- opcional; si es NULL se lee cpi_pregunta
```

Ejemplo: `cpi_pregunta` = «Temp. rodamiento ldo A (°C)» · `cpi_pregunta_voz` = «Temperatura del rodamiento lado A, en grados Celsius».

---

## 7. Lo que no se puede hacer por voz

Vale la pena tenerlo escrito para que nadie prometa de más:

| No | Por qué | Qué se hace |
|---|---|---|
| Firmar | La firma es un acto deliberado y personal | Botón grande, con confirmación hablada previa |
| Tomar la foto | Necesita apuntar la cámara | El **obturador** sí se activa por voz: «foto» |
| Autorizar un permiso de trabajo | Requiere leer y entender el contenido | Queda en la web, con el supervisor |
| Aprobar una predicción | Decisión de planificación, no de terreno | Queda en la web |

---

## 8. El flujo completo, con el caso real

```text
Juan no sabe leer. Tiene marcadas entrada_voz, lectura_voz y confirmacion_hablada.
Esta frente al blower CB01, con las manos con aceite.

1. Escanea el QR con la camara.
   SIGMA lee:  "Blower CB01, sala de blowers. Que quieres hacer?"
               "Uno: ver mi trabajo. Dos: crear orden de trabajo. Tres: bitacora."

2. Juan:       "crear orden de trabajo"
   SIGMA lee:  "Orden de trabajo para el blower CB01. Cuentame que pasa."

3. Juan:       "hay un ruido metalico fuerte en el lado del motor y esta
                calentando mas de lo normal"

4. SIGMA lee:  "Entendi: ruido metalico fuerte en el lado del motor,
                calentando mas de lo normal. Es correcto?"
   Juan:       "si"
                                    -> Dictado_Voz confirmado, audio descartado
                                    -> Orden_Trabajo con otr_dictado_voz
                                       otr_entrada_modo = VOZ
                                       origen = MANUAL

5. SIGMA lee:  "Que componente? Uno: motor. Dos: rodamiento. Tres: correa."
   Juan:       "rodamiento"
   SIGMA lee:  "Rodamiento. Que posicion? Uno: lado A. Dos: lado B.
                Tres: lado motor."
   Juan:       "lado motor"
                                    -> componente elegido, sin escribir nada

6. SIGMA lee:  "Puedes medir la temperatura?"
   Juan:       "setenta y ocho coma cuatro"
   SIGMA lee:  "Setenta y ocho coma cuatro grados. Siete, ocho, coma, cuatro.
                Correcto?"
   Juan:       "si"
                                    -> Activo_Medicion con amd_entrada_modo = VOZ
                                       valor 78,4 y valor canonico

7. SIGMA lee:  "Toma una foto del rodamiento y di foto cuando estes listo."
   Juan:       "foto"               -> evidencia

8. SIGMA lee:  "Orden de trabajo dos mil trescientos cuarenta creada.
                Prioridad alta por la temperatura. Algo mas?"
   Juan:       "no"
```

Juan acaba de generar una OT con componente, medición canónica, severidad y evidencia. **Sin leer ni escribir una palabra.** Y el dato que quedó en la base tiene la misma calidad que el de un técnico que tecleó.

---

## 9. La decisión de motor: todo en el teléfono

**SIGMA no usa voz en la nube. Ni como opción, ni como escalamiento, ni para el plan más caro.** Toda la síntesis y todo el reconocimiento corren en el motor del propio dispositivo, con `flutter_tts` y `speech_to_text` sobre lo que Android e iOS ya traen.

No es una decisión de ahorro. Es la que hace que la funcionalidad exista de verdad:

| | Motor del teléfono | Voz en la nube |
|---|---|---|
| **Sin señal** | **funciona** | no funciona |
| Concurrencia | **ilimitada** | 1 en el nivel gratuito |
| Costo | **0** | USD 16 por millón de caracteres |
| Latencia | inmediata | ida y vuelta por red |
| Cuota que se agota | **ninguna** | 500.000 caracteres al mes |
| Calidad de voz | buena | mejor |
| Vocabulario técnico | genérico | entrenable |

**El caso que decide es la sala de blowers sin señal.** Ahí es exactamente donde el técnico tiene las manos con aceite y necesita dictar, y ahí es donde la nube no llega. Una funcionalidad de accesibilidad que se cae justo en el lugar donde se necesita no es una funcionalidad, es una demostración.

### 9.1 Lo que esta decisión elimina

Vale la pena listarlo porque es todo trabajo que no hay que construir ni mantener:

- **La cuota mensual de voz.** No hay `LIMITE TTS CARACTERES` ni `LIMITE STT MINUTOS`; `Funcionalidad` vuelve de 27 a 25 valores.
- **La función que elegía motor.** Si solo hay un motor, no hay decisión que tomar.
- **La consulta al servidor antes de dictar.** Ésta importa más de lo que parece: preguntarle al servidor «¿qué motor uso?» es *en sí misma* una dependencia de red, justo en el camino que tiene que funcionar sin red. La simplificación no solo quita código, **quita una llamada que podía fallar en el peor momento**.
- **La degradación.** No hay de qué degradar a qué: el piso y el techo son el mismo motor.

### 9.2 Lo que se conserva, y por qué

`dvo_voz_motor` se queda, y no «por si acaso». La columna registra **un hecho sobre cómo se produjo ese texto**: una transcripción hecha por el motor de un teléfono tiene un perfil de error distinto al de un motor de nube. Cuando ese texto termina alimentando al modelo predictivo, saber de dónde salió es parte de poder auditarlo. Hoy todas las filas dicen `DISPOSITIVO`, y eso también es información.

Lo mismo con `dvo_intentos`: sigue siendo la métrica que avisa si el reconocimiento está fallando en una planta concreta.

### 9.3 La consecuencia comercial

Si la voz no cuesta nada, cobrar por ella se vuelve una decisión distinta. La separación que queda es:

| Funcionalidad | Plan | Por qué |
|---|---|---|
| **`LECTURA POR VOZ`** | **todos, incluido BÁSICO** | Es lo que permite trabajar a quien no sabe leer. **Es acceso, no comodidad.** No cuesta nada cobrarla, y negarla no ahorra nada |
| `CREACION POR VOZ` | MEDIO y FULL | Dictar con las manos ocupadas es productividad, y la productividad sí se cobra |

> Antes había un argumento de costo para dejar la lectura fuera del plan básico. **Ese argumento desapareció.** Lo único que quedaría es cobrar por el acceso de alguien que no sabe leer, y eso no se sostiene.

---

## 10. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Tablas nuevas (2)** | `Dictado_Voz` (`dvo`) · `Usuario_Accesibilidad` (`uac`) |
| **Tabla eliminada (1)** | `Archivo_Transcripcion` (`atr`) — la reemplaza `Dictado_Voz` |
| **Catálogo nuevo (1)** | `Entrada_Modo` (`emo`, 6 valores) |
| **Columnas nuevas** | `<pfx>_dictado_voz` en `Orden_Trabajo`, `Checklist_Ejecucion_Respuesta`, `Bitacora`, `Falla` · `<pfx>_entrada_modo` en `Activo_Medicion`, `Activo_Medidor_Lectura`, `Checklist_Ejecucion_Respuesta`, `Orden_Trabajo`, `Bitacora` · `cpi_pregunta_voz` · `<pfx>_icono` y `<pfx>_archivo` en 12 catálogos de terreno |
| **Motor** | **Solo el del teléfono.** Nada en la nube — ver §9 |
| **Funcionalidades comerciales** | `CREACION POR VOZ` en MEDIO y FULL · **`LECTURA POR VOZ` en todos los planes** — ver §9 |
| **Privacidad** | El audio no se almacena. La transcripción confirmada sí, como dato operacional |
