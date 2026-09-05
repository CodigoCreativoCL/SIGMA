# SIGMA App — Alertas y notificaciones push (Firebase)

> **Normativo.** Define cómo el sistema avisa al teléfono. Complementa
> `PATRONES/ASP/NOTIFICACIONES.md`, que es el documento del **dato** (la tabla
> `Alerta`); este es el del **transporte** y el de la app.
>
> Cubre **HU-077** (que el sistema avise lo que encuentra) en su superficie
> móvil.

Fecha: 04-09-2026 · Código Creativo · Bryan Chávez

---

## 1. Dos cosas distintas que se confunden todo el tiempo

| | Qué es | Dónde vive |
|---|---|---|
| **La alerta** | El hallazgo: «este repuesto está bajo su mínimo» | `Alerta`, en la base. Es del **cliente**, no de una persona |
| **La lectura** | «yo ya la vi» | `Alerta_Lectura`. Es de **cada persona** |
| **La notificación push** | El aviso que suena en un teléfono | No se guarda como dato propio: es el **transporte** |

> **No se crea una tabla de notificaciones para la app.** La tabla `Alerta`
> venía en el diseño con diez tipos y cinco estados, y estaba vacía porque
> nadie la llenaba, no porque estuviera mal. Una tabla paralela «para móvil»
> es el lugar exacto donde algún día alguien pregunta *«¿cuántos problemas
> abiertos hay?»* y hay dos respuestas distintas.

Y una distinción que decide el badge:

> **Abierta y no leída no son lo mismo.** El punto rojo cuenta **lo no visto**.
> La bandeja muestra **lo abierto**, visto o no. Si el badge contara lo
> abierto, no bajaría nunca — y un badge que nunca baja deja de significar
> «mira esto».

---

## 2. Lo que ya existe

### En la base

| Objeto | Qué hace |
|---|---|
| `Alerta`, `Alerta_Tipo`, `Alerta_Estado`, `Alerta_Lectura`, `Alerta_Historial` | El dato |
| `Alerta_Tipo.alt_permiso` | Quién puede ver ese tipo de alerta. **No hay lista de destinatarios**: se resuelve por permiso con `FNC_USUARIO_TIENE_PERMISO` |
| `alt_icono`, `alt_menu_link`, `alt_ficha_link`, `alt_ficha_id_columna` | Cómo se ve y a qué registro abre |
| `GEN_ALERTA_INVENTARIO`, `GEN_ALERTA_DETECTAR` | Los detectores. Idempotentes: no duplican lo abierto y **cierran solo** lo que dejó de pasar |
| `SEL_ALERTA`, `SEL_ALERTA_RESUMEN`, `UPD_ALERTA_LEER` | Las consultas y el marcado |
| `Alerta_Deteccion` | El freno: un `UPDATE` atómico decide quién corre el detector, por cliente |

Bloques SQL: `81_NOTIFICACIONES.sql`, `82_NOTIFICACIONES_CONSULTA.sql`,
`83_NOTIFICACION_ABRE_FICHA.sql`.

### En la API

```
GET  /alertas?soloAbiertas=true&pagina=1&tamano=50
GET  /alertas/resumen                    → dos enteros: abiertas y no leídas
POST /alertas/{id}/leer
```

Ya reusan `SEL_ALERTA` y `SEL_ALERTA_RESUMEN` **tal como los usa la web**. No
hay SP «para móvil», y eso es deliberado: sería el lugar donde una alerta
aparece en la web y en el teléfono no, y nadie se entera hasta que alguien
reclama.

**No hay endpoint para crear una alerta**, y tampoco debe haberlo: las detecta
el servidor. Un `POST` abierto permitiría que un dispositivo inventara
hallazgos que nadie detectó.

---

## 3. Lo que falta: el push

Hoy la app tendría que **preguntar** por alertas. Preguntar cada minuto gasta
batería y plan de datos del técnico, y con la app cerrada no pregunta nada.
Falta el empujón desde el servidor.

El patrón está resuelto en `FacilityGesApi2.0` y se porta:
`Services/Fcm/FcmService.cs` + `IFcmService`, FCM **HTTP v1** con cuenta de
servicio, token OAuth2 cacheado con cinco minutos de margen y `HttpClient`
estático.

### 3.1 La tabla

Siguiendo `PATRON_TABLAS.md` y la nomenclatura de `CONVENCIONES.md` §1.1
—que ya usa `Usuario_App_Dispositivo` como ejemplo de tabla bien nombrada—:

```sql
CREATE TABLE [dbo].[Usuario_App_Dispositivo] (
     uad_id                 INT IDENTITY(1,1) NOT NULL
    ,uad_usuario            INT           NOT NULL
    ,uad_token              VARCHAR(255)  NOT NULL   -- token FCM del dispositivo
    ,uad_dispositivo        VARCHAR(200)  NULL       -- "Android 14 - SM-A536E"
    ,uad_app_version        VARCHAR(20)   NULL
    ,uad_plataforma         VARCHAR(10)   NOT NULL   -- ANDROID | IOS
    ,uad_fecha_ultimo_uso   DATETIME      NULL
    ,uad_habilitado         BIT           NOT NULL
    ,uad_usuario_creacion   INT           NOT NULL
    ,uad_fecha_creacion     DATETIME      NOT NULL
    ,uad_usuario_act        INT           NOT NULL
    ,uad_fecha_act          DATETIME      NOT NULL
    ,CONSTRAINT PK_USUARIO_APP_DISPOSITIVO PRIMARY KEY (uad_id)
    ,CONSTRAINT FK_UAD_USUARIO FOREIGN KEY (uad_usuario) REFERENCES Usuario(usu_id)
    ,CONSTRAINT UX_UAD_TOKEN UNIQUE (uad_token)
)
```

**`uad_token` es único en toda la tabla, no por usuario.** Un token identifica
un *dispositivo*, y si el técnico y el supervisor usan el mismo teléfono, el
token tiene que pasar del uno al otro, no quedar en los dos. Sin ese único, el
segundo en entrar recibe las alertas del primero.

### 3.2 Los SPs

| SP | Qué hace |
|---|---|
| `UPS_USUARIO_APP_DISPOSITIVO` | `MERGE` por `uad_token`: si el token ya existe, **lo reasigna** al usuario que entró y actualiza dispositivo y versión |
| `DEL_USUARIO_APP_DISPOSITIVO` | Baja lógica. Con `@TOKEN` NULL, baja todos los del usuario |
| `SEL_USUARIO_APP_DISPOSITIVO_ALERTA` | Dado un `@ALERTA`, devuelve los tokens de quienes **pueden verla** — el mismo `alt_permiso` y `FNC_USUARIO_TIENE_PERMISO` que usa la web |

El tercero es el que hace que esto no se convierta en un sistema de
destinatarios. Guardar a quién avisar en el momento de detectar obliga a
decidirlo cuando el organigrama todavía no cambió; con el permiso, quien entre
mañana al perfil de bodeguero recibe las alertas de bodega sin que nadie
reasigne nada.

### 3.3 Los endpoints

```
POST   /dispositivos      { token, dispositivo, app_version, plataforma }
DELETE /dispositivos      { token }        ← al cerrar sesión
```

Dos notas de diseño:

- **`POST /dispositivos` no exige permiso**, igual que
  `GET /cliente-usuarios/mis-clientes`: es parte de iniciar sesión. Sí exige
  usuario: el token se asocia a quien trae el JWT, **nunca a un `?usuario=` de
  la URL**.
- **`DELETE` al cerrar sesión no es opcional.** Sin él, el próximo que use ese
  teléfono recibe las alertas del anterior. Es una fuga de información del
  cliente, no una molestia.

### 3.4 El servicio

`API/Services/Fcm/FcmService.cs`, portado de FacilityGes:

- `FcmProjectId` en `appSettings` de `Web.config`.
- Credenciales de cuenta de servicio en `~/Firebase/firebase-credentials.json`,
  **fuera del control de versiones** —igual que la cadena de conexión debería
  estarlo—. Se descargan de Firebase Console → Configuración → Cuentas de
  servicio.
- Token OAuth2 cacheado en memoria (~60 min, se renueva con 5 de margen).
- `HttpClient` **estático**: uno por instancia de aplicación, no uno por envío.

---

## 4. Cuándo se envía un push

**Al detectar**, no al consultar.

```
GEN_ALERTA_DETECTAR  (lo dispara el ping del navegador, con freno por cliente)
      │
      ├── inserta las alertas nuevas          ← y solo las NUEVAS
      │
      └── por cada alerta nueva:
            SEL_USUARIO_APP_DISPOSITIVO_ALERTA  → tokens de quien puede verla
                  │
            FcmService.Enviar(...)  por cada token
```

Reglas:

1. **Solo alertas nuevas.** El detector es idempotente y no vuelve a abrir lo
   ya abierto; el push cuelga de esa misma condición. Una alerta que sigue
   abierta desde ayer no vuelve a sonar.
2. **Nada de push por cada consulta.** La campanita se refresca seguido; el
   push es un evento del servidor, no una respuesta a una lectura.
3. **Severidad CRÍTICA y ALTA suenan; el resto llega silencioso.** Lo que
   ordena la bandeja es la gravedad, y lo que decide si el teléfono vibra a las
   tres de la mañana también.
4. **Un token que FCM rechaza con `UNREGISTERED` o `INVALID_ARGUMENT` se da de
   baja** (`uad_habilitado = 0`). Una tabla de tokens que solo crece termina
   gastando la mitad de los envíos en teléfonos que ya no existen.

---

## 5. El mensaje

```json
{
  "message": {
    "token": "<uad_token>",
    "notification": { "title": "Repuesto bajo mínimo", "body": "Rodamiento 6205 · Bodega Central" },
    "data": {
      "referencia_tipo": "alerta",
      "referencia_id":   "1842",
      "ficha_ruta":      "app://existencias/repuesto/311",
      "severidad":       "ALTA"
    },
    "android": { "priority": "high", "notification": { "channel_id": "sigma_alertas" } }
  }
}
```

- **`ficha_ruta` usa el mismo esquema `app://` que el menú.** Así el destino de
  una notificación se resuelve con el mismo mapa de rutas que ya existe, en vez
  de con un `switch` paralelo que algún día diverge. Sale de
  `alt_ficha_link` + `alt_ficha_id_columna`, que ya resuelve `SEL_ALERTA`.
- **Al tocar la notificación se abre el registro, no el listado.** Llevar al
  listado es avisar y después hacer buscar: la persona tendría que volver a
  encontrar el repuesto que la notificación acaba de nombrarle.
- **El cuerpo no lleva datos sensibles.** «Repuesto bajo mínimo» está bien; un
  nombre de persona, un RUT o un monto, no: la notificación se muestra en la
  pantalla bloqueada, a la vista de cualquiera que pase.
- Tope de FCM: **4 KB** de payload. El `data` lleva identificadores, no
  contenido.

---

## 6. El lado de la app

### 6.1 Montaje

| Paso | Qué |
|---|---|
| 1 | Proyecto Firebase + app Android con el `applicationId` de SIGMA |
| 2 | `google-services.json` en `android/app/`. **No va al repositorio** |
| 3 | Plugin `com.google.gms.google-services` en `android/app/build.gradle.kts` |
| 4 | `firebase_core` + `firebase_messaging` en `pubspec.yaml` |
| 5 | `flutterfire configure` genera `lib/firebase_options.dart` |
| 6 | `Firebase.initializeApp()` **antes** de cualquier uso de FCM, en `main()` |
| 7 | Canal Android `sigma_alertas`, creado en Dart y declarado en el manifest como `default_notification_channel_id`. **Los dos nombres tienen que coincidir** o Android usa un canal por defecto sin sonido |
| 8 | Ícono monocromático `res/drawable/ic_stat_sigma.xml`. Android solo usa el canal alfa: un ícono a color se ve como un cuadrado blanco |
| 9 | Permiso `POST_NOTIFICATIONS` (Android 13+), pedido **en contexto**, no en el arranque |

### 6.2 El ciclo del token

```
login correcto
   └── FirebaseMessaging.instance.getToken()
         └── POST /dispositivos

FirebaseMessaging.instance.onTokenRefresh.listen(...)
   └── POST /dispositivos          ← el token cambia solo: reinstalación,
                                     limpieza de datos, restauración

logout
   └── DELETE /dispositivos  +  deleteToken()
```

Si el `POST /dispositivos` falla, **se encola en el `outbox`** como cualquier
otra escritura. Un token que no llegó al servidor es un teléfono que no va a
recibir nada, en silencio.

### 6.3 Los tres estados de recepción

| Estado de la app | Quién muestra la notificación | Qué hace la app |
|---|---|---|
| **Primer plano** | Android **no** la muestra sola | `onMessage` → `flutter_local_notifications` la muestra, y se refresca el badge |
| **Segundo plano** | Android la muestra | `onMessageOpenedApp` al tocarla → navega a `ficha_ruta` |
| **Cerrada** | Android la muestra | `getInitialMessage()` al arrancar → misma navegación |

El handler de segundo plano es una **función de nivel superior** anotada con
`@pragma('vm:entry-point')`: se ejecuta en un isolate propio, sin acceso al
estado de la app. Ahí solo se hace lo mínimo —refrescar un contador local—;
todo lo demás espera a que la app abra.

### 6.4 La bandeja

**La bandeja de SIGMA no es local.** Sale de `GET /alertas`, y la copia local
es solo caché para verla sin señal.

Esto se aparta de FacilityGes, donde la bandeja vive únicamente en SQLite —y
tiene que ser así allá, porque las notificaciones de FacilityGes son
recordatorios locales que el servidor no conoce—. En SIGMA el servidor ya
tiene el hallazgo; una bandeja local sería una segunda verdad.

| Elemento | De dónde sale |
|---|---|
| Badge de la campana | `GET /alertas/resumen` → **no leídas** |
| Lista | `GET /alertas?soloAbiertas=true`, ordenada por severidad |
| Marcar leída | `POST /alertas/{id}/leer`; sin red, va al `outbox` |
| Sin señal | Se muestra la copia local con la fecha de corte visible |

### 6.5 Fiabilidad en Android

Lo que se aprendió en FacilityGes y qué aplica acá:

| Problema | ¿Aplica a SIGMA? |
|---|---|
| `flutter_local_notifications` v21 no declara sus receivers → las notificaciones **programadas** no llegan con la app cerrada | **Solo si se programan recordatorios locales.** Con FCM el sistema entrega igual. Se pospone hasta que existan las programaciones (S3+) |
| Alarmas inexactas casi no llegan con Doze en Xiaomi/Samsung | Ídem: aplica a recordatorios locales, no al push |
| Autostart y ahorro de batería de los OEM matan procesos | **Sí aplica.** El push de prioridad alta suele pasar el Doze, pero Xiaomi, Huawei, Oppo y Vivo lo bloquean si la app no está en autostart. Hace falta la pantalla de guía por fabricante |
| Ícono monocromático en la barra de estado | **Sí aplica.** Ver §6.1 paso 8 |

**Se usa `SCHEDULE_EXACT_ALARM` solo si se programan recordatorios, y nunca
`USE_EXACT_ALARM` ni `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`**: los dos
últimos friccionan la revisión de Google Play.

---

## 7. Privacidad y seguridad

- El archivo de credenciales de Firebase **da acceso a enviar push a nombre del
  proyecto**. Fuera del repositorio, con permisos de lectura solo para la
  cuenta del App Pool.
- `google-services.json` tampoco va al repositorio, aunque sea menos sensible.
- El token se borra del servidor al cerrar sesión (§3.3).
- El cuerpo de la notificación se ve en la pantalla bloqueada: nada personal
  ahí (§5).
- El envío se registra —a quién, qué alerta, con qué resultado— para poder
  responder «¿por qué no me llegó?» con un dato en vez de una suposición.

---

## 8. Checklist de implementación

**Base de datos**
- [ ] `Usuario_App_Dispositivo` + índices (bloque SQL nuevo).
- [ ] `UPS_` / `DEL_` / `SEL_USUARIO_APP_DISPOSITIVO_ALERTA`.
- [ ] Enganche del envío en `GEN_ALERTA_DETECTAR` (o en el controller que lo
      encadena, que hoy es `AlertaController.Detectar()`).

**API**
- [ ] `Services/Fcm/FcmService.cs` + `IFcmService` (portados).
- [ ] `FcmProjectId` en `Web.config`; credenciales en `~/Firebase/`.
- [ ] `DispositivosController`: `POST` y `DELETE /dispositivos`.
- [ ] Agregar los archivos nuevos al `API.csproj`. **Un archivo que no esté
      listado no se compila y no avisa.**

**App**
- [ ] Montaje de §6.1, del 1 al 9.
- [ ] `notificacion_service.dart`: token, refresh, los tres estados de
      recepción, canal, deep link por `app://`.
- [ ] Campana con badge + `AlertasScreen` sobre `GET /alertas`.
- [ ] Pantalla de guía OEM (autostart / batería) con detección de marca.
- [ ] Probar en un Xiaomi o un Samsung real, con la app cerrada. En el
      emulador esto siempre funciona y no prueba nada.

---

## 9. Lo que queda fuera por ahora

- **Recordatorios locales programados** (una ocurrencia que vence, un permiso
  de trabajo por expirar). Necesitan `flutter_local_notifications` con alarmas
  exactas y toda la fiabilidad OEM asociada. Entran cuando existan las
  programaciones del Sprint 3 en adelante.
- **iOS.** SIGMA es Android en esta fase. Con FCM, agregar iOS es APNs y
  permisos, no un rediseño.
- **Notificaciones por correo.** Otro transporte para el mismo dato; el SMTP
  del proyecto sigue sin configurar y bloquea también HU-004.

---

## 10. Bitácora

| Fecha | Qué |
|---|---|
| 04-09-2026 | Nace este documento. Se decide **no crear una tabla de notificaciones para la app**: la bandeja sale de `Alerta`, que ya existe con sus detectores y consultas. El push se porta de `FacilityGesApi2.0` (FCM HTTP v1). Queda especificada `Usuario_App_Dispositivo` con `uad_token` único global —para que un teléfono compartido no filtre alertas entre usuarios— y el destinatario resuelto por `alt_permiso`, nunca por lista |
