# SIGMA App — Puesta en marcha

> Cómo levantar, compilar y publicar la aplicación móvil de SIGMA. Todo lo que
> alguien nuevo necesita para pasar de un repositorio recién clonado a la app
> corriendo en un teléfono.
>
> Qué construir: [`SIGMA_APP_FLUTTER.md`](SIGMA_APP_FLUTTER.md) ·
> Cómo estructurar el código: [`SIGMA_APP_ARQUITECTURA.md`](SIGMA_APP_ARQUITECTURA.md) ·
> Cómo se ve: [`SIGMA_APP_DISENO.md`](SIGMA_APP_DISENO.md) ·
> Datos y sincronización: [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md) ·
> Alertas y push: [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md)

Fecha: 04-09-2026 · Código Creativo

---

## 1. Requisitos

| Herramienta | Versión | Verificado en este equipo |
|---|---|---|
| Flutter | 3.41.x stable | **3.41.7** ✔ |
| Dart | 3.11.x | **3.11.5** ✔ |
| Android SDK | mínimo API 24 · target API 35 | |
| JDK | 17 | |

```bash
flutter --version
```

> **`minSdk` 24, no 21.** FacilityGes usa 21 por compatibilidad heredada.
> SIGMA nace hoy: 24 (Android 7) cubre prácticamente todo el parque real,
> evita varios `desugaring` y quita limitaciones de `sqflite` y de las
> notificaciones. Subirlo después es fácil; bajarlo, no.

---

## 2. Dónde vive

| | |
|---|---|
| **Proyecto Flutter** | `C:\Capstone\SIGMA\App\sigma_app` *(a crear)* |
| **Paquete Dart** | `sigma_app` |
| **Application ID** | `cl.codigocreativo.sigma` |
| **API** | `http://localhost/SIGMA/Servicio/API` en desarrollo |

Crear el proyecto:

```bash
flutter create --org cl.codigocreativo --project-name sigma_app --platforms android C:\Capstone\SIGMA\App\sigma_app
```

> **Solo Android en esta fase.** Agregar iOS más adelante no obliga a rehacer
> nada: la arquitectura no tiene código de plataforma propio salvo el manifest
> y los servicios de notificación.

---

## 3. Variables de entorno

Las credenciales **no van al repositorio**. Se inyectan en compilación con
`--dart-define-from-file`, igual que en FacilityGes.

```bash
cp .env.example.json .env.dev.json
```

```json
{
  "API_BASE_URL": "http://10.0.2.2/SIGMA/Servicio/API",
  "TIMEOUT_SEGUNDOS": "15",
  "LOG_HTTP": "true"
}
```

En `.gitignore`:

```
.env.dev.json
.env.qa.json
.env.prod.json
android/app/google-services.json
android/local.properties
```

> **En el emulador Android, `localhost` es el emulador.** El host es
> `10.0.2.2`. Es el primer tropiezo de todos los que prueban una API local
> desde el emulador y se ve como «sin conexión al servidor».

**No hay `API_AUTH_USERNAME` ni `API_AUTH_PASSWORD`.** FacilityGes los usa
para una cuenta de servicio máquina-a-máquina; en SIGMA el token sale de
`POST /sesion` con las credenciales de la persona. La cuenta de servicio del
`AuthController` heredado es deuda conocida de la API y la app **no la usa**.

Lectura en código:

```dart
class ApiConstants {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');
  static const int timeoutSegundos =
      int.fromEnvironment('TIMEOUT_SEGUNDOS', defaultValue: 15);
}
```

> Un `baseUrl` vacío tiene que **fallar al arrancar con un mensaje claro**, no
> producir peticiones a `/sesion` sin host que se ven como un error de red.

---

## 4. Firebase

Ver [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md) §6.1 para el
detalle. En corto:

1. Proyecto en Firebase Console, app Android con `cl.codigocreativo.sigma`.
2. `google-services.json` → `android/app/`. **Ignorado por git.**
3. Plugin `com.google.gms.google-services` en `android/app/build.gradle.kts`.
4. `flutterfire configure` → genera `lib/firebase_options.dart`.
5. Del lado servidor: `firebase-credentials.json` en `~/Firebase/` de la API y
   `FcmProjectId` en `Web.config`. **Ninguno de los dos va al repositorio.**

---

## 5. Firma para release

`android/local.properties` (ignorado por git):

```properties
sdk.dir=C:\\Users\\TU_USUARIO\\AppData\\Local\\Android\\sdk
flutter.sdk=C:\\src\\flutter

KEY_STORE_FILE=C:\\ruta\\al\\sigma.keystore
KEY_STORE_PASSWORD=...
KEY_ALIAS=sigma
KEY_PASSWORD=...
```

> El keystore de producción se genera **una vez** y se guarda en el repositorio
> seguro del equipo. Perderlo significa no poder volver a publicar una
> actualización de esa app en Google Play: hay que subir una app nueva y pedirle
> a cada usuario que la instale de cero.

---

## 6. Compilar y ejecutar

```bash
flutter pub get
```

```bash
flutter run --dart-define-from-file=.env.dev.json
```

```bash
flutter build apk --release --dart-define-from-file=.env.prod.json
```

```bash
flutter build appbundle --release --dart-define-from-file=.env.prod.json
```

Si los íconos no aparecen en el release, es el *tree shaking* de Material
Symbols:

```bash
flutter build appbundle --release --dart-define-from-file=.env.prod.json --no-tree-shake-icons
```

**Antes de dar cualquier cosa por terminada:**

```bash
flutter analyze
```

Tiene que decir `No issues found`. Es el equivalente del `exitcode=0` que exige
la API.

---

## 7. Dependencias

Cada paquete lleva el motivo por el que está. **Un paquete sin motivo escrito
acá no entra.**

| Paquete | Para qué |
|---|---|
| `flutter_riverpod` | Estado y dependencias (arquitectura §3) |
| `sqflite` + `path` + `path_provider` | Base local y rutas de archivos |
| `http` | Cliente HTTP. No hace falta Dio: `ApiClient` es una clase |
| `connectivity_plus` | Detectar la transición offline → online |
| `shared_preferences` | Sesión, tema, marcas simples |
| `firebase_core` + `firebase_messaging` | Push de alertas (HU-077) |
| `flutter_local_notifications` | Mostrar el push en primer plano; recordatorios más adelante |
| `mobile_scanner` | QR de posición y de etiqueta (HU-154, HU-067) |
| `image_picker` + `file_picker` | Evidencias: foto, galería, documento |
| `flutter_image_compress` | EXIF + resize antes de guardar. Sin esto, una foto son 4 MB |
| `permission_handler` | Cámara, notificaciones, almacenamiento |
| `device_info_plus` | Nombre del dispositivo y marca (guía OEM) |
| `package_info_plus` | Versión, para la pantalla de configuración y el log |
| `intl` | Fechas y números en `es_CL` |
| `skeletonizer` | Carga sin vaciar la pantalla (diseño §9) |
| `material_symbols_icons` | Mismos íconos que la web (MDI/Material Symbols) |
| `flutter_svg` | Logo y estados vacíos |
| `uuid` | El identificador de la cola de salida |

**Lo que no se agrega hasta que haga falta:** `geolocator` (mientras no se
decida la pregunta abierta de geolocalización — pedir el permiso sin usarlo
cuesta confianza y una revisión de Play), `camera` (basta `image_picker` salvo
que aparezca una captura guiada), `google_fonts` (Sora va como asset: la app no
puede depender de la red para tener tipografía).

---

## 8. Assets

```
assets/
├── fonts/Sora/     Sora-Light|Regular|Medium|SemiBold|Bold.ttf
├── images/         logo SIGMA (svg), estados vacíos
└── icono/          launcher + adaptativo + monocromático
```

> **Flutter no lee `woff2`.** El `Sora-Variable.woff2` de la web no sirve: hay
> que poner los `.ttf` de Google Fonts, misma familia y mismos pesos.

---

## 9. Estructura del repositorio

```
sigma_app/
├── android/
├── assets/
├── lib/                 ver SIGMA_APP_ARQUITECTURA.md §2
├── test/
├── .env.example.json    con las claves y valores de ejemplo, SIN secretos
├── analysis_options.yaml
└── pubspec.yaml
```

---

## 10. Antes del primer commit

- [ ] `.gitignore` con `.env.*.json`, `google-services.json`,
      `local.properties`, `*.keystore`.
- [ ] `.env.example.json` versionado, con las claves y **sin** valores reales.
- [ ] `flutter analyze` limpio.
- [ ] `POST /sesion` probado **por HTTP** contra la API — es la deuda de
      `SIGMA_APP_FLUTTER.md` §10.3 y bloquea todo lo demás.

---

## 11. Bitácora

| Fecha | Qué |
|---|---|
| 04-09-2026 | Nace este documento. Versiones verificadas en el equipo (Flutter 3.41.7 / Dart 3.11.5). Decisiones: `minSdk` 24, solo Android en esta fase, sin cuenta de servicio en la app, Sora como asset y no por `google_fonts` |
