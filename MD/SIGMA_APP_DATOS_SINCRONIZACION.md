# SIGMA App — Datos, carga inicial y sincronización

> **Normativo.** Define cómo bajan los datos al teléfono, cómo se guardan, cómo
> se capturan las escrituras sin señal y cómo suben al servidor. Es el
> documento que hay que cerrar **antes** de la primera pantalla del Sprint 2:
> condiciona el modelo local del que dependen todas las demás.
>
> Cubre **HU-150** (sincronizar los datos hacia el dispositivo) y **HU-151**
> (trabajar sin conexión).

Fecha: 04-09-2026 · Código Creativo · Bryan Chávez

---

## 1. El patrón que se hereda, y en qué se aparta SIGMA

FacilityGes resuelve esto con un solo SP —`API_2_SEL_USUARIO_SABANA_DATOS`—
que recibe `@USUARIO` y `@TIPO` y devuelve, en un `SELECT` distinto por tipo,
**todo lo que el dispositivo necesita para operar**: clientes, instalaciones,
zonas, checklists, programaciones, tipos de orden de trabajo, categorías,
prioridades, configuración y tipos de evento.

Eso está bien y se copia. Tres cosas de ese diseño son las que importan:

| Del patrón | Por qué se conserva |
|---|---|
| **Un solo SP con `@TIPO`** | La app pide bloque por bloque. Si el bloque 5 falla, los cuatro primeros ya están en disco y sirven |
| **El SP hace los `JOIN` de seguridad** | El filtro por cliente, instalación, perfil y habilitado vive en SQL, no en Dart. Un filtro en el teléfono es un filtro que se puede saltar |
| **`ORDER BY` en el SP** | FacilityGes tuvo que agregarlo el 27-10-2025 porque SQLite no conserva el orden de inserción. El orden se define donde se define el dato |

Y tres en las que **SIGMA se aparta**, con el motivo:

| FacilityGes | SIGMA | Por qué |
|---|---|---|
| Responde `HTTP 200` siempre y pone el veredicto en `Status` dentro de un JSON serializado en `jsonRespuesta` | **Códigos HTTP reales** (`ErrorSql` traduce el `RAISERROR`) | La app no tiene que parsear un JSON dentro de otro para saber si el registro entró. Ver `SIGMA_APP_ARQUITECTURA.md` §6 |
| Una marca `enviado` por cada tabla local | **Una cola de salida única** (`outbox`) | SIGMA captura seis tipos de escritura distintos. Seis mecanismos de reintento son seis lugares donde falla distinto |
| Envía la carga completa cada vez | **Carga completa en v1, incremental con `@DESDE` en v2** | Las tablas de SIGMA tienen auditoría (`*_fecha_act`). Bajar cuarenta mil activos cada vez que se abre la app es gastar el plan de datos del técnico |

---

## 2. La carga descendente — HU-150

### 2.1 Qué baja

| # | Bloque | Tablas de origen | Cambia |
|---:|---|---|---|
| 1 | Identidad y organización | `Cliente`, `Cliente_Instalacion`, `Instalacion_Area`, `Centro_Costo` | casi nunca |
| 2 | Navegación y permisos | `Menus`, `Permiso` (vía `SEL_MENU_APP` y `SEL_USUARIO_PERMISOS`) | poco |
| 3 | Catálogos | `Catalogo` y sus valores | poco |
| 4 | Activos | `Activo`, `Activo_Tipo`, `Activo_Modelo`, `Activo_Posicion`, `Atributo_Tecnico` | a diario |
| 5 | Medición | `Activo_Medidor`, `Activo_Variable`, `Variable_Medicion`, `Unidad_Medida`, `Magnitud` | poco |
| 6 | Inventario | `Repuesto`, `Repuesto_Lote`, `Bodega`, `Bodega_Ubicacion`, `Inventario_Movimiento_Tipo` | a diario |
| 7 | Existencias | `Inventario_Saldo` | **constantemente** |
| 8 | Permisos de trabajo | `Permiso_Trabajo_Tipo`, `Permiso_Trabajo_Estado` | casi nunca |
| 9 | Alertas | `Alerta` abiertas + `Alerta_Tipo` + `Severidad` | constantemente |

**El bloque 7 no se cachea con la misma lógica que los demás.** Es el dato que
no puede estar viejo: un técnico que baja a buscar una pieza que ya no está
perdió el viaje. Lo que sí baja y se guarda es
`isa_fecha_ultimo_movimiento`, con el que la app puede decir **de cuándo** es
lo que muestra cuando no hay señal (HU-056 CA2).

### 2.2 Lo que falta construir en el servidor

> **Hoy no existe ningún endpoint de carga masiva.** Los 52 endpoints de la
> API son por recurso y paginados. Bajar el catálogo completo con
> `GET /repuestos?pagina=1..N` funciona, pero son N viajes por bloque y la app
> queda sincronizando cinco minutos en la puerta de la planta.

Lo que hay que crear, en este orden:

**1. El SP.** `API_SEL_APP_SABANA_DATOS`, siguiendo `PATRON_SP.md` y el
prefijo `API_` que `CONVENCIONES.md` §1.1 reserva para los SPs de la API
móvil.

```sql
CREATE PROCEDURE API_SEL_APP_SABANA_DATOS
     @USUARIO       INT
    ,@CLIENTE       INT
    ,@INSTALACION   INT           = NULL   -- NULL = todas las autorizadas
    ,@TIPO          INT           = 1
    ,@DESDE         DATETIME      = NULL   -- NULL = carga completa
AS
BEGIN
    -- 1 IDENTIDAD Y ORGANIZACION
    IF (@TIPO = 1) BEGIN ... END
    -- 4 ACTIVOS
    IF (@TIPO = 4) BEGIN
        SELECT  ACT_ID, ACT_CODIGO, ACT_NOMBRE, ACT_TIPO, ACT_MODELO,
                ACT_AREA, ACT_POSICION, ACT_ESTADO, ACT_CRITICIDAD,
                ACT_FECHA_ACT
        FROM    Activo ACT
        INNER JOIN Cliente_Instalacion CIN ON ...
        WHERE   ACT.act_habilitado = 1
        AND     (@DESDE IS NULL OR ACT.act_fecha_act > @DESDE)
        ORDER BY ACT_CODIGO
    END
    ...
END
```

Reglas del SP, no negociables:

- **Los `JOIN` de autorización van adentro.** El mismo encadenado
  `Cliente_Usuario` → `Cliente_Instalacion_Usuario` → perfil → habilitado que
  usa FacilityGes, resuelto contra las tablas de SIGMA. Nunca `WHERE cliente =
  @CLIENTE` a secas confiando en que el token ya filtró.
- **`ORDER BY` explícito** en todo bloque que la app muestre en lista.
- **`@DESDE` compara contra `*_fecha_act`**, que ya existe por el patrón de
  auditoría de `PATRON_TABLAS.md`.
- **Solo las columnas que la app usa.** Cada columna de más es plan de datos
  del técnico y espacio en un teléfono de gama baja.

**2. El endpoint.** `GET /sincronizacion?tipo={n}&desde={iso8601}`

- Responde `200` con `{ tipo, servidor_fecha_utc, desde, total, filas: [...] }`.
- Sin `tipo`, devuelve el **manifiesto**: qué bloques hay, cuántas filas tiene
  cada uno y cuál es su fecha de corte. Con eso la app decide qué pedir y puede
  mostrar una barra de progreso real en vez de una animación indefinida.
- `servidor_fecha_utc` es lo que la app guarda como `desde` de la próxima vez.
  **Nunca usa su propio reloj para eso**: un teléfono desajustado se saltaría
  registros para siempre.
- Exige permiso, como todo endpoint (`ApiBase.ExigirPermiso`).

**3. El orden de descarga.** Bloques 1, 2 y 3 primero: sin ellos la app no
sabe ni qué menú dibujar. Después 4 a 8. El 9 va aparte y se refresca solo.

### 2.3 Cuándo se sincroniza

| Momento | Qué baja |
|---|---|
| Después del login y de elegir cliente | Todo, con pantalla de progreso |
| Al recuperar la red | Lo incremental, en silencio |
| `pull-to-refresh` en una lista | Solo el bloque de esa lista |
| Al abrir la app con sesión guardada | **Nada de red.** Se lee lo local y el sync corre después del primer frame |

---

## 3. La base local

`sigma_local.db`, SQLite vía `sqflite`.

### 3.1 Reglas del esquema

1. **Las columnas se llaman igual que en SQL Server.** `act_codigo`, no
   `codigo`. Traducir nombres obliga a mantener un diccionario mental entre
   tres capas y es donde aparecen los errores que nadie encuentra leyendo.
2. **Toda tabla que se descarga lleva `sync_fecha`** (cuándo se bajó): es lo
   que permite decir «existencias al 04-09 14:32» sin conexión.
3. **Toda tabla que se captura lleva `uuid` y `sync_estado`.**
4. **Nada de base64 en una columna.** Se guarda la **ruta** del archivo
   comprimido. Una imagen en base64 pesa ~400 KB de texto y el `CursorWindow`
   de Android revienta a los 2 MB — y revienta al *leer*, mucho después de
   haber guardado, que es la peor forma de fallar.
5. **Los archivos van al directorio de documentos de la app**, no al temporal:
   algunos fabricantes limpian el temporal y la evidencia desaparece antes de
   poder enviarla.

### 3.2 Migraciones

`version: N` con `onUpgrade` en escalones acumulativos, uno por versión, y
`CREATE TABLE IF NOT EXISTS`:

```dart
Future<void> _onUpgrade(Database db, int anterior, int nueva) async {
  if (anterior < 2) { /* solo lo que cambió entre 1 y 2 */ }
  if (anterior < 3) { /* ... */ }
}
```

- **Nunca se edita un escalón ya publicado**: hay teléfonos con esa versión.
- Un escalón que reordena una tabla **la recrea y la deja vacía**; se repuebla
  en la siguiente sincronización. Eso vale para datos que bajan; **jamás** para
  la tabla `outbox`, que contiene trabajo que todavía no llegó al servidor.
- Cada escalón lleva un comentario con **por qué** cambió, no con qué cambió.

### 3.3 La tabla que sostiene todo: `outbox`

```sql
CREATE TABLE outbox (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid            TEXT    NOT NULL UNIQUE,   -- se genera al ENCOLAR
  tipo            TEXT    NOT NULL,          -- lectura | medicion | movimiento | ...
  entidad_local   INTEGER,                   -- fila local que originó esto
  endpoint        TEXT    NOT NULL,          -- '/inventario-movimientos'
  metodo          TEXT    NOT NULL DEFAULT 'POST',
  cuerpo_json     TEXT    NOT NULL,          -- listo para enviar, sin adjuntos
  adjuntos_json   TEXT,                      -- rutas locales; base64 al enviar
  orden           INTEGER NOT NULL,          -- FIFO dentro del mismo agrupador
  agrupador       TEXT,                      -- ej. 'ot:4821' — ver §4.2
  estado          TEXT    NOT NULL DEFAULT 'pendiente',
  intentos        INTEGER NOT NULL DEFAULT 0,
  ultimo_error    TEXT,
  ultimo_codigo   INTEGER,                   -- el HTTP del último intento
  fecha_captura   TEXT    NOT NULL,          -- ISO 8601 CON offset
  fecha_envio     TEXT
);
```

**Por qué una cola única y no una marca `enviado` por tabla.** SIGMA captura
lecturas, mediciones, movimientos de inventario, cambios de estado de activo,
permisos de trabajo y evidencias. Con una marca por tabla, cada módulo termina
con su propio reintento, su propio orden y su propia forma de fallar; con una
cola, el reintento, el orden, la idempotencia y **la pantalla que muestra lo
pendiente** se escriben una vez.

El costo es que el cuerpo viaja serializado y hay que mantener el `endpoint` al
día. Es un costo conocido y acotado; el otro se descubre en producción.

---

## 4. La cola de salida — HU-151

### 4.1 El ciclo

```
Acción del técnico
   │
   ▼
Repositorio: INSERT en la tabla de la entidad     ← el trabajo ya está a salvo
   │
   ▼
Repositorio: INSERT en outbox (estado=pendiente, uuid generado ACÁ)
   │
   ▼
La pantalla confirma. No espera la red.
   │
   ▼
SyncService: ¿hay red?
   ├─ sí → envía ahora
   └─ no → queda pendiente
             │
        Connectivity: offline → online (debounce 2 s)
             │
        envía en orden, un ítem a la vez dentro de cada agrupador
```

### 4.2 El orden importa donde importa

Los ítems de **agrupadores distintos** se envían en paralelo; dentro del mismo
agrupador, **en orden estricto de captura**. Una entrega de repuestos contra la
orden 4821 y el cierre del paso de esa misma orden no se pueden cruzar; una
lectura de medidor en otra planta no tiene nada que ver con ninguna de las dos.

### 4.3 Idempotencia: el `uuid` se genera al encolar

Ya es una decisión tomada en la API para `POST /inventario-movimientos`, y
está probada: dos llamadas con el mismo `uuid` devuelven el mismo id y el saldo
se mueve una sola vez.

> **Se genera al *encolar*, no al *enviar*.** Generado al enviar, cada
> reintento traería un `uuid` nuevo y la idempotencia no serviría de nada: es
> exactamente el reintento por timeout —donde el servidor sí grabó pero la
> respuesta no llegó— el caso que hay que cubrir.

**Esto tiene que extenderse a todo endpoint de escritura de la app**, no solo
al de inventario: lecturas, mediciones, cambios de estado y permisos de
trabajo. Está anotado en §8 como pendiente del servidor.

### 4.4 Reintentos

| Intento | Espera |
|---:|---|
| 1 | inmediato |
| 2 | 30 s |
| 3 | 2 min |
| 4 | 10 min |
| 5+ | 30 min, con tope |

**Nada se descarta nunca por cantidad de intentos.** Un ítem que falla cinco
veces por red pasa a `pendiente` con `ultimo_error` visible, no a la basura.
Lo único que lo saca de la cola es un veredicto del servidor: `2xx` →
`enviado`; `400`, `404`, `409`, `422` → `rechazado` con el mensaje del
servidor guardado.

### 4.5 Lo que falló tiene que verse

Una cola que reintenta en silencio y descarta al tercer intento **pierde
trabajo sin avisar**. Es obligatorio:

- Un **badge de pendientes** en la barra superior, junto al de conectividad.
- Una **pantalla de pendientes** que liste lo encolado y lo rechazado, con el
  motivo tal como lo dijo el servidor, la fecha de captura y un botón de
  reintentar.
- Que un ítem `rechazado` sea **navegable a su registro**: si el servidor dijo
  «la cantidad excede el saldo», el bodeguero tiene que poder abrir ese
  movimiento y corregirlo.

---

## 5. Los estados, y qué hace la app con cada uno

| HTTP | Estado del ítem | Además |
|---:|---|---|
| 200 / 201 | `enviado` | Guarda el `id` del servidor en la fila local |
| 400 | `rechazado` | Muestra el mensaje del servidor, sin traducir |
| 401 | queda `pendiente` | Renueva sesión; si vuelve 401, cierra sesión |
| 402 | queda `pendiente` | Pantalla de suscripción vencida. **No** cierra sesión |
| 403 | `rechazado` | No reintentar: el permiso no va a aparecer solo |
| 404 | `rechazado` | El registro de destino ya no existe |
| 409 | **`enviado`** | Es el duplicado del reintento: el servidor ya lo tenía |
| 423 | queda `pendiente` | Cuenta bloqueada; se avisa con el tiempo restante |
| 5xx, timeout, sin red | queda `pendiente` | Reintento con espera creciente |

El **409 tratado como éxito** es lo que cierra el círculo de la idempotencia:
sin eso, un ítem que sí entró queda para siempre en la cola mostrando un error
que no existe.

---

## 6. Fechas: el error que ya se pagó una vez

Tres reglas, y las tres vienen de un bug real.

1. **La fecha es la de captura, no la del envío.** Una lectura tomada a las
   09:00 y enviada a las 18:00 es de las 09:00. El servidor guarda **ambas**:
   la local del dispositivo y la suya.
2. **Siempre con offset.** La app manda ISO 8601 completo
   (`2026-09-04T09:12:33-03:00`), nunca un `DateTime` suelto. El servidor corre
   en **UTC−07:00** y la planta está en Chile: en el bloque 134 un tramo «desde
   hoy» aparecía como PENDIENTE por exactamente esto, y se corrigió con
   `AT TIME ZONE`.
3. **`GETUTCDATE()` para las columnas `_utc`, `FNC_PAIS_HORA` para la
   auditoría.** Ya es la convención de la base —`ame_fecha_valor_actual_utc` se
   sella en UTC porque la app compara lecturas de husos distintos— y la app la
   respeta: manda su hora con zona y deja que el SP decida qué guarda dónde.

El SP recibe la fecha local en un parámetro propio (`@FECHA_LOCAL` en el
patrón de FacilityGes) y calcula la del servidor por su cuenta. La app **nunca**
manda la hora del servidor.

---

## 7. Evidencias y archivos

| Paso | Qué pasa |
|---|---|
| 1. Captura | `media_picker_service`: cámara, galería o archivo |
| 2. Compresión | Imágenes: EXIF corregido, 720×1280, calidad 25. Es lo que ya usan las apps del grupo y da archivos de 40–90 KB |
| 3. Guardado | El **archivo** en el directorio de documentos; en SQLite, **la ruta** |
| 4. Envío | Se lee el archivo y se codifica base64 **en el momento del envío** |
| 5. Confirmación | Solo cuando el servidor responde 2xx se marca enviado. El archivo local se conserva hasta ese momento |

Del lado del servidor, el patrón ya está: el SP recibe un JSON con
`arc_nombre_archivo`, `arc_extension`, `arc_tamano` y `arc_archivo_binario`
(base64 → `VARBINARY(MAX)`), lo desarma con `OPENJSON` y llama a
`INS_ARCHIVO`. SIGMA ya tiene `INS_ARCHIVO`, `SEL_ARCHIVO`, `DEL_ARCHIVO`,
la tabla `Archivo` con sus categorías y `Archivo_Vinculo` (bloque 42), más el
`ArchivoController` publicado.

> **Tope por envío.** Un permiso de trabajo con seis fotos son ~500 KB en
> base64, que es aceptable; treinta fotos no lo son. La app limita a **8
> adjuntos por registro** y **5 MB por envío**, y si se pasa, parte el envío.
> Sin tope, el primer técnico con buena cámara descubre el límite del servidor
> por nosotros.

---

## 8. Qué falta construir para que esto funcione

Ordenado por lo que bloquea a más cosas.

### En la base de datos

- [ ] `API_SEL_APP_SABANA_DATOS` con los nueve bloques de §2.1 (bloque SQL nuevo).
- [ ] Columna `uuid` (`UNIQUEIDENTIFIER` o `VARCHAR(36)`) con índice único en
      las tablas de captura que aún no la tienen: `Activo_Medidor_Lectura`,
      `Activo_Medicion`, `Activo_Estado_Historial`, `Permiso_Trabajo`.
      `Inventario_Movimiento` ya la tiene y funciona.
- [ ] `Usuario_App_Dispositivo` y sus SPs — ver
      [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md) §3.

### En la API

- [ ] `GET /sincronizacion` (manifiesto y por bloque).
- [ ] `uuid` en el cuerpo de **todos** los POST de captura, con el mismo
      tratamiento que ya tiene `POST /inventario-movimientos`: repetido →
      mismo id, sin volver a aplicar el efecto.
- [ ] Que los POST devuelvan **201 con `Location`** y el id, para que la app
      pueda cerrar la fila local.
- [ ] Los dos defectos abiertos de `SIGMA_ESTADO_DESARROLLO_API.md` §6
      —los *backing fields* del `SesionDto` y el 401 que pierde su mensaje—
      **bloquean el login de la app**, no solo lo afean.

### En la app

- [ ] `local_database_service` con el esquema v1 y la tabla `outbox`.
- [ ] `outbox_repository` con reintento, orden por agrupador y estados.
- [ ] `sincronizacion_service` con manifiesto, progreso real y reanudación.
- [ ] Pantalla de pendientes (§4.5). **No es opcional**: sin ella, la cola es
      una caja negra.

---

## 9. Preguntas abiertas

Anotadas en vez de decididas en silencio:

1. **Geolocalización de la captura.** El patrón de FacilityGes acompaña cada
   inserción con un JSON de geolocalizaciones y un `EVENTO` por cada una, lo
   que permite auditar dónde se registró cada cosa. SIGMA **no tiene hoy** una
   tabla equivalente. Hay que decidir si se agrega —tiene sentido para permisos
   de trabajo y para el descubrimiento en terreno del Anexo C— o si se deja
   fuera del alcance. Mientras no se decida, la app **no pide permiso de
   ubicación**: pedirlo sin usarlo cuesta confianza y una revisión de Play.
2. **Cuánto historial baja.** ¿La ficha de un activo trae su historial completo
   o los últimos N movimientos? Afecta el tamaño de la base local en un
   teléfono de gama baja.
3. **Qué pasa con lo pendiente al cambiar de cliente o cerrar sesión.**
   Propuesta: **no se puede cerrar sesión con la cola no vacía** sin una
   confirmación explícita que diga cuántos registros se van a quedar
   esperando, y la cola **no se borra** en el logout: se conserva y se reenvía
   cuando esa misma persona vuelva a entrar. Borrarla es perder trabajo hecho.

---

## 10. Bitácora

| Fecha | Qué |
|---|---|
| 04-09-2026 | Nace este documento. Patrón de sábana de datos tomado de `API_2_SEL_USUARIO_SABANA_DATOS`; tablas de destino verificadas contra los scripts de `SIGMA/BD`. Se define la cola única `outbox`, la idempotencia por `uuid` al encolar, el manejo de estados HTTP y las reglas de fecha con zona. Queda listado lo que falta en base, API y app (§8) y tres preguntas abiertas (§9) |
