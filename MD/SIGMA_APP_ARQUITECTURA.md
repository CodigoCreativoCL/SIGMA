# SIGMA App — Arquitectura

> **Normativo.** Define cómo se estructura el código de la aplicación móvil de
> SIGMA. Se lee **antes** de la primera línea de Dart, igual que
> `PATRONES/ASP/CONVENCIONES.md` se lee antes de la primera línea de C#.
>
> Lo que hay que construir está en
> [`SIGMA_APP_FLUTTER.md`](SIGMA_APP_FLUTTER.md). Cómo se ve, en
> [`SIGMA_APP_DISENO.md`](SIGMA_APP_DISENO.md). Cómo bajan y suben los datos,
> en [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md).
> El estado del desarrollo, en [`SIGMA_APP_ESTADO.md`](SIGMA_APP_ESTADO.md).

Fecha: 04-09-2026 · Código Creativo · Bryan Chávez

---

## 1. De dónde sale este estándar, y qué se copia

La arquitectura **no se inventa acá**. Es la de las dos apps del grupo que ya
están en producción —**FacilityGes** y **AgendamientosControlGate**— y que
resuelven el mismo problema: gente de terreno, con guantes, sin señal,
capturando datos contra una API ASP.NET Web API 2 y unos SPs de SQL Server.

Copiar una arquitectura probada tiene un valor concreto: los errores que ya
costaron tiempo allá **no se vuelven a pagar acá**. Este documento nombra esos
errores donde corresponde.

| Se copia | No se copia |
|---|---|
| Riverpod + Repository Pattern, y el orden de las capas | El dominio: bitácoras, marcaciones, checklists de aseo. SIGMA es mantenimiento industrial |
| Servicios singleton (`ClassName._()` + `static final instance`) | Los nombres de tablas y endpoints de FacilityGes |
| Offline-first: SQLite primero, cola de envío después | La respuesta `HTTP 200 + Status por ítem`. **La API de SIGMA usa códigos HTTP reales** (§6) |
| `SyncService` reactivo a la conectividad, con debounce | El inbox de notificaciones solo local: SIGMA ya tiene alertas en el servidor |
| El tema con `ThemeExtension` y roles M3 | Los colores. SIGMA tiene su propia marca |
| Compresión de imágenes y **rutas locales, nunca base64 en SQLite** | — |

---

## 2. Estructura de carpetas

```
lib/
├── main.dart                        arranque: Firebase, tema, sesión, ProviderScope
├── firebase_options.dart            generado por FlutterFire CLI — no editar a mano
├── routes.dart                      transiciones + resolución de rutas app://
│
├── constants/
│   └── api_constants.dart           baseUrl (dart-define) + todos los endpoints
│
├── models/                          clases de datos puras. Sin lógica, sin red
│   ├── sesion_model.dart
│   ├── menu_model.dart
│   ├── permiso_model.dart
│   ├── alerta_model.dart
│   ├── activo_model.dart
│   ├── ...
│   ├── outbox_item_model.dart       la unidad de la cola de salida
│   └── sync_estado.dart             pendiente | enviado | rechazado
│
├── services/                        singletons: red, disco, GPS, cámara, push
│   ├── api_client.dart              HTTP + JWT + traducción de códigos
│   ├── sesion_service.dart          almacén en memoria + SharedPreferences
│   ├── auth_service.dart            login / seleccionar cliente / logout
│   ├── local_database_service.dart  SQLite: esquema, migraciones, CRUD
│   ├── sincronizacion_service.dart  carga descendente (HU-150)
│   ├── sync_service.dart            cola ascendente + reactividad de red
│   ├── sync_state.dart              contador global de operaciones en vuelo
│   ├── notificacion_service.dart    FCM + notificaciones locales + deep link
│   ├── menu_service.dart            GET /menus → árbol de navegación
│   ├── permisos_service.dart        GET /usuario-permisos, caché corta
│   ├── media_picker_service.dart    cámara, galería, archivos, permisos
│   ├── image_compress_service.dart  EXIF + resize + calidad
│   ├── escaneo_service.dart         QR: resuelve contra servidor o local
│   ├── ubicacion_service.dart       GPS
│   └── tema_service.dart            ThemeMode persistido
│
├── repositories/                    offline-first: SQLite → API si hay red
│   ├── outbox_repository.dart       el corazón: encolar, enviar, reintentar
│   ├── lectura_repository.dart
│   ├── medicion_repository.dart
│   ├── inventario_movimiento_repository.dart
│   ├── permiso_trabajo_repository.dart
│   ├── activo_estado_repository.dart
│   └── alerta_repository.dart
│
├── providers/                       ÚNICA fuente de verdad para la UI
│   ├── sesion_provider.dart
│   ├── cliente_provider.dart        cliente e instalación en contexto
│   ├── menu_provider.dart
│   ├── permisos_provider.dart
│   ├── conectividad_provider.dart
│   ├── alertas_provider.dart
│   └── ...                          uno por pantalla con estado propio
│
├── screens/
│   ├── login/            login_screen.dart · recuperar_clave_screen.dart
│   ├── seleccion/        seleccion_cliente_screen.dart
│   ├── home/             home_screen.dart (shell) + tabs/
│   ├── perfil/           mi_perfil_screen.dart
│   ├── activo/           activo_ficha_screen.dart · activo_estado_screen.dart
│   ├── lectura/          lectura_form_screen.dart
│   ├── medicion/         medicion_form_screen.dart
│   ├── inventario/       existencias_screen.dart · movimiento_form_screen.dart
│   ├── permiso_trabajo/  permisos_screen.dart · permiso_form_screen.dart
│   ├── escaneo/          escaneo_screen.dart      (HU-154 y HU-067, una sola)
│   ├── alertas/          alertas_screen.dart
│   ├── sincronizacion/   sincronizacion_screen.dart · pendientes_screen.dart
│   └── configuracion/    configuracion_screen.dart
│
├── widgets/
│   ├── comun/            topbar_app · campana_alertas · badge_conectividad ·
│   │                     dialogo_exito · boton_expresivo · chip_adjunto ·
│   │                     visor_media · etiqueta_seccion · campo_busqueda
│   └── <modulo>/         los propios de cada módulo
│
└── theme/
    ├── sigma_tokens.dart            SgColor / SgRadius / SgElevation / SgMotion
    └── app_theme.dart               AppTheme.oscuro() + AppColors ThemeExtension
```

### El flujo de dependencias

```
models ←── services ←── repositories
  ↑            ↑             ↑
  └────── providers ─────────┘
              ↑
      screens / widgets
```

| Carpeta | Puede importar de | **Nunca** importa de |
|---|---|---|
| `models/` | nada | todo lo demás |
| `services/` | `models/`, `constants/` | `providers/`, `screens/`, `widgets/` |
| `repositories/` | `models/`, `services/` | `providers/`, `screens/`, `widgets/` |
| `providers/` | `models/`, `services/`, `repositories/` | `screens/`, `widgets/` |
| `widgets/` | `models/`, `providers/`, `theme/` | `screens/`, `repositories/` |
| `screens/` | todo lo anterior | — |

> **La regla que sostiene todo:** la UI **solo lee datos de providers**. Los
> providers leen de servicios y repositorios. Los servicios y repositorios no
> saben que Riverpod existe.
>
> Cuando se rompe, el síntoma no aparece de inmediato: aparece el día que dos
> pantallas muestran números distintos del mismo dato porque cada una lo leyó
> por su cuenta.

---

## 3. Riverpod, para quien viene de .NET

En SIGMA web el estado vive en `Session` y en variables del code-behind:
cualquiera lo cambia y **nadie se entera**; hay que refrescar la pantalla a
mano. Riverpod cambia una sola cosa:

> El estado vive en un **provider**. La UI observa el provider. Cuando el
> estado cambia, Flutter reconstruye **solo** los widgets que lo observan.

### `ProviderScope` — el contenedor de dependencias

Se declara una vez, en `main.dart`, envolviendo la app. Es el equivalente de
`builder.Build()`: sin él, tocar un provider lanza excepción en runtime.

```dart
runApp(const ProviderScope(child: SigmaApp()));
```

### Los cuatro tipos que se usan, y cuándo

| Tipo | Usar cuando | Equivalente mental |
|---|---|---|
| `NotifierProvider` | Estado sincrónico con acciones (la sesión, el cliente en contexto) | ViewModel con `INotifyPropertyChanged` |
| `AsyncNotifierProvider` | Estado que se carga: lista de alertas, existencias, ficha de activo | ViewModel con `IsBusy` + `Error` + `Items`, pero resuelto por el framework |
| `StateProvider<T>` | Un valor suelto que la UI cambia directo (filtro, pestaña activa) | Propiedad con setter |
| `Provider<T>` | Valor derivado o dependencia sin estado | Servicio calculado |

```dart
class SesionNotifier extends Notifier<SesionState> {
  @override
  SesionState build() => SesionState.desdeServicio(SesionService.instance);

  void refrescar() => state = SesionState.desdeServicio(SesionService.instance);

  void limpiar() {
    ApiClient.instance.limpiarToken();
    SesionService.instance.limpiar();
    state = const SesionState();
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, SesionState>(SesionNotifier.new);
```

### `ref` — los cuatro verbos

| Verbo | Dónde | Qué hace |
|---|---|---|
| `ref.watch(p)` | **solo** dentro de `build()` | Se suscribe: si `p` cambia, el widget se reconstruye |
| `ref.read(p)` | callbacks, `initState`, métodos async | Lee una vez, sin suscripción. También `ref.read(p.notifier).accion()` |
| `ref.listen(p, cb)` | dentro de `build()` | Efecto lateral al cambiar, sin usar el valor para pintar |
| `ref.invalidate(p)` | al cerrar sesión | Destruye el estado; el próximo `watch` vuelve a llamar `build()` |

`ref.watch` fuera de `build()` es el error más común y no falla de inmediato:
falla el día que el valor cambia y la pantalla no se entera.

### `AsyncValue<T>` y el patrón que la app usa

```dart
final asyncAlertas = ref.watch(alertasProvider);
final datos     = asyncAlertas.valueOrNull ?? const AlertasState();
final cargando  = asyncAlertas.isLoading;
```

**Se prefiere `valueOrNull` sobre `when(...)` en las listas.** En terreno, una
recarga que borra la pantalla y muestra un spinner deja al técnico sin los
datos que ya tenía —que probablemente le servían— por diez segundos de red
mala. Con `valueOrNull` los datos anteriores siguen visibles y el skeleton o
la barra de progreso indican que se está actualizando.

### Inmutabilidad

Riverpod compara por referencia. Mutar el objeto existente **no** dispara la
reconstrucción:

```dart
// MAL — el Set se muta en el lugar; Riverpod no ve el cambio
state.leidas.add(id);

// BIEN — objeto nuevo
state = AsyncData(actual.copyWith(leidas: {...actual.leidas, id}));
```

Todo estado de provider lleva `copyWith`, y todas sus colecciones se publican
con `List.unmodifiable`.

### `ConsumerWidget` y `ConsumerStatefulWidget`

Son `StatelessWidget` y `StatefulWidget` con acceso a `ref`. Se usa el
stateful **solo** cuando hay estado local real: `TextEditingController`,
`AnimationController`, un `bool _guardando`.

**La trampa que ya costó un crash en FacilityGes:** en un
`ConsumerStatefulWidget`, un `ref.read(...)` **después** de un `await` puede
ejecutarse cuando el widget ya se desmontó. La solución es capturar los
notifiers **antes** del `await` —viven en el contenedor, no en el widget— o
comprobar `mounted`.

```dart
final sesion = ref.read(sesionProvider.notifier);   // capturado ANTES
await AuthService.instance.seleccionarCliente(id);  // acá el widget puede morir
sesion.refrescar();                                 // seguro
```

---

## 4. Servicios: singletons que no saben de Riverpod

```dart
class SesionService {
  SesionService._();
  static final SesionService instance = SesionService._();
}
```

### `ApiClient` — el único que habla HTTP

Responsabilidades, y ninguna más:

1. Adjuntar `Authorization: Bearer <jwt>` en cada llamada.
2. Serializar el cuerpo y deserializar la respuesta.
3. Aplicar el timeout y **un** reintento en caso de timeout.
4. **Traducir el código HTTP a una excepción tipada** — §6.

Lo que **no** hace: decidir qué hacer con un 403, guardar en SQLite, mostrar
un mensaje. Eso es de las capas de arriba.

```dart
class ApiException implements Exception {
  final int? statusCode;
  final String mensaje;   // el del servidor, si vino; si no, uno propio
  const ApiException(this.mensaje, {this.statusCode});
}
```

> **La ruta de SIGMA no lleva `/api/`.** La aplicación está publicada bajo
> `.../Servicio/API`; el `baseUrl` termina ahí y los endpoints empiezan en
> `/sesion`, `/menus`, `/alertas`. Ver `SIGMA_ESTADO_DESARROLLO_API.md` §2.

### `SesionService` — el almacén en memoria

Guarda usuario, cliente e instalación en contexto, el JWT y el `dispositivo`
(`"Android 14 - SM-A536E"`). Persiste en `SharedPreferences` lo mínimo para
reabrir la app sin volver a pedir clave; **el JWT también**, porque dura ocho
horas y volver a pedir la clave en cada arranque es inaceptable en planta.

La UI **nunca** lee `SesionService` directo: lee `sesionProvider`.

### `SyncState` — el contador, no un booleano

Un `bool sincronizando` se apaga cuando termina la primera de dos operaciones
en paralelo y el badge miente. `SyncState` cuenta: emite `true` al empezar la
primera y `false` cuando termina la última.

---

## 5. Repositorios: el patrón offline-first

Regla de oro, sin excepciones:

> **Toda escritura se guarda en SQLite primero y se envía después.** Nunca al
> revés. Si la app envía primero y el envío falla, el trabajo se perdió y la
> persona no lo sabe hasta que alguien reclama.

```dart
Future<LecturaModel> registrar(LecturaModel lectura) async {
  final guardada = await _db.insertLectura(lectura);        // 1. disco
  await _outbox.encolar(TipoOperacion.lectura, guardada);   // 2. cola
  unawaited(SyncService.instance.sincronizarAhora());       // 3. intento
  return guardada;
}
```

El paso 3 **no se espera**: la pantalla confirma con lo que ya está en disco.
Hacer esperar al técnico a que la red responda para decirle "guardado" es
convertir una app offline-first en una online que a veces funciona.

El detalle de la cola —tabla, idempotencia, reintentos, qué se muestra— está
en [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md) §4.

---

## 6. Los códigos de la API, y qué hace la app con cada uno

**Acá SIGMA se separa de FacilityGes a propósito.** FacilityGes responde
siempre `HTTP 200` y pone el veredicto en un campo `Status` dentro del cuerpo;
la app tiene que parsear un JSON dentro de otro JSON para saber si el registro
entró. La API de SIGMA usa **códigos HTTP reales**, traducidos desde el
`RAISERROR` del SP por `Utils/ErrorSql.cs`. La app se escribe para eso.

| Código | Qué significa | Qué hace la app |
|---:|---|---|
| **200 / 201** | Correcto | Marca el ítem como `enviado`. El 201 trae el `id` del servidor |
| **400** | Regla de negocio | Muestra **el mensaje del servidor**, tal cual. Marca `rechazado`: reintentar no lo va a arreglar |
| **401** | Token vencido o inválido | Un reintento; si vuelve 401, **cierra sesión** y va a Login |
| **402** | Suscripción vencida (HU-193) | Pantalla de bloqueo con el mensaje del servidor. **No** cierra sesión |
| **403** | Sin permiso | **Nunca cierra sesión.** Mensaje y vuelta atrás. Además, esconder el botón que lo provocó |
| **404** | No existe | Mensaje; si era un ítem de la cola, `rechazado` |
| **409** | Ya existe / duplicado | Si el ítem lleva `uuid` y el servidor lo reconoce, se trata como **enviado** — es el reintento que llegó dos veces |
| **423** | Cuenta bloqueada | Mensaje con el tiempo restante que devuelve `SEL_LOGIN` |
| **5xx / timeout / sin red** | Falla transitoria | **Deja el ítem `pendiente`.** Reintenta después. Nunca lo descarta |

**401 y 403 no se tratan igual, y esa es la distinción más importante de esta
tabla.** Ante un 401, el token no sirve y hay que renovarlo. Ante un 403, el
token está perfecto: quien lo trae no tiene el permiso. Cerrar sesión ante un
403 le hace perder al técnico el trabajo en curso para volver a entrar con
exactamente el mismo resultado.

---

## 7. Navegación

### El menú sale de la base, no del código

`GET /menus` devuelve el árbol ya resuelto para quien entró: solo filas con
`mnu_ambito` APP o AMBOS, comparadas contra los permisos vigentes con la misma
función que usa la web, y con `mnu_link` en esquema `app://`.

```dart
// Un mapa de app://... a pantalla. Lo que el servidor no manda, no se dibuja.
final rutasApp = <String, WidgetBuilder>{
  'app://inicio':    (_) => const HomeScreen(),
  'app://mi-perfil': (_) => const MiPerfilScreen(),
};
```

Una lista de opciones escrita en Dart crearía **dos modelos de permisos**: el
día que se revoque uno, la web lo esconde y el teléfono no. Registrar una
pantalla es un `INSERT` en `Menus`, igual que en la web.

> Una ruta `app://` que llega del servidor y no está en el mapa **no se
> muestra** y se registra en el log. Es preferible una opción que falta a una
> opción que navega a una pantalla en blanco.

### Entre pantallas

Navegación imperativa con `Navigator` y tres transiciones en `routes.dart`:
`slideRoute` (avanzar), `fadeRoute` (reemplazo de stack: logout), y
`sharedAxisRoute` (flujo lineal: login → home). No hay GoRouter: el árbol de
la app es poco profundo y el enrutador ya lo decide el servidor.

---

## 8. Convenciones de código

| Tema | Regla |
|---|---|
| **Idioma** | Código, clases y variables en **español**, igual que el resto de SIGMA. `existenciasProvider`, no `stockProvider` |
| **Nombres de campos de modelo** | **Iguales a la columna de SQL Server**: `isa_cantidad`, `act_codigo`. Traducir a camelCase obliga a mantener un diccionario en la cabeza de quien depura |
| **Archivos** | `snake_case.dart`, sufijo por capa: `_model`, `_service`, `_repository`, `_provider`, `_screen` |
| **Comentarios** | Explican **por qué**, no qué. El qué ya lo dice el código |
| **Colores** | Solo vía `Theme.of(context).colorScheme` y `context.appColors`. Prohibido el hex suelto (ver `SIGMA_APP_DISENO.md`) |
| **Strings de UI** | En el widget por ahora. Si aparece un segundo idioma, se centralizan; anticiparlo hoy es costo sin beneficio |
| **`print`** | Prohibido. `debugPrint('[Componente] mensaje')` |
| **Análisis** | `flutter analyze` debe terminar en **`No issues found`** antes de dar algo por terminado. Es el equivalente del `exitcode=0` de la API |

### El bloqueante que se hereda de la web

En SIGMA web, `int.Parse()` sobre una columna que admite NULL reventó la
pantalla **tres veces**. En Dart el equivalente es
`(json['col'] as num).toInt()` sobre un `null`. Todos los `fromJson` usan la
forma tolerante:

```dart
id     : (j['act_id'] as num?)?.toInt() ?? 0,
nombre :  j['act_nombre'] as String?    ?? '',
fecha  : DateTime.tryParse(j['act_fecha'] as String? ?? ''),
```

---

## 9. Arranque de la app (`main.dart`)

El orden importa, y cada paso está donde está por una razón:

```
1. WidgetsFlutterBinding.ensureInitialized()
2. Firebase.initializeApp()                     antes que cualquier uso de FCM
3. PackageInfo → versión, para el encabezado y la pantalla de configuración
4. initializeDateFormatting('es')
5. Info del dispositivo → SesionService.dispositivo
6. TemaService.cargar()
7. NotificacionService.init()                   canal Android + permisos
8. ¿Hay sesión guardada?
     sí → abrir SQLite, cargar lo local (NO la red), ir a Home
     no → Login
9. runApp(ProviderScope(...))
10. addPostFrameCallback → SyncService.init()    la red arranca DESPUÉS del primer frame
```

**Los pasos 8 y 10 son la diferencia entre una app que abre en medio segundo y
una que se queda en blanco cuando la planta no tiene señal.** El arranque lee
del disco; la red viene después y en segundo plano. Un `await` de red en
`main()` deja al técnico mirando una pantalla blanca hasta que expire el
timeout.

Y el paso 8 va dentro de un `try`: un fallo de base local o de datos no puede
dejar la app sin pantalla. Se entra igual y se reintenta con el sync.

---

## 10. Qué NO se hace

- **No** se guarda base64 en SQLite. Se guarda la **ruta** del archivo
  comprimido; el base64 se genera al momento de enviar. Una imagen en base64
  en una columna `TEXT` revienta el `CursorWindow` de Android a los 2 MB, y el
  error aparece al *leer*, mucho después de haber guardado.
- **No** se replica en Dart una regla de negocio que ya vive en un SP. La app
  esconde lo que no corresponde; **el servidor es el que decide**.
- **No** se crean endpoints "para móvil" que dupliquen un `SEL_` que la web ya
  usa. Ese es el lugar donde algún día un dato aparece en un lado y en el otro
  no.
- **No** hay background service persistente. Android no lo permite de forma
  confiable. La sincronización se dispara al abrir la app, al recuperar la red
  y después de cada acción.
- **No** se agrega un paquete sin anotarlo en
  [`SIGMA_APP_README.md`](SIGMA_APP_README.md) con el motivo.

---

## 11. Bitácora

| Fecha | Qué |
|---|---|
| 04-09-2026 | Nace este documento. Arquitectura tomada de FacilityGes y AgendamientosControlGate, con dos divergencias explícitas: **códigos HTTP reales** en vez de `Status` en el cuerpo (§6), y **cola de salida única** en vez de una marca `enviado` por tabla (ver documento de sincronización) |
