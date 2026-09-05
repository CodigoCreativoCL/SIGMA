# SIGMA — Estado del desarrollo · App móvil

> **Documento vivo.** Es el traspaso de contexto de la aplicación móvil entre
> sesiones. Quien la retome debería poder leer solo esto y saber cómo está,
> qué se decidió y por qué, y qué falta.
>
> El estado de la web y la base vive en
> [`SIGMA_ESTADO_DESARROLLO.md`](SIGMA_ESTADO_DESARROLLO.md); el de la API, en
> [`SIGMA_ESTADO_DESARROLLO_API.md`](SIGMA_ESTADO_DESARROLLO_API.md). Este
> archivo no los repite: los complementa.
>
> **Regla: cada vez que se cierre un bloque de trabajo, se actualiza este
> archivo en el mismo cambio.**

**Última actualización:** 04-09-2026
**Estado:** bloques 0 a 7 hechos · **las 10 pantallas contra endpoints
reales, la base local y la cola de salida funcionando**, y la sábana de datos
construida y probada en el servidor · `flutter analyze` limpio, 12 tests verdes

---

## 1. Los documentos de la app

Siete, y cada uno responde una pregunta distinta. Leerlos en este orden:

| Documento | Responde |
|---|---|
| [`SIGMA_APP_FLUTTER.md`](SIGMA_APP_FLUTTER.md) | **Qué** hay que construir: las historias con superficie móvil y el contrato de la API |
| [`SIGMA_APP_ARQUITECTURA.md`](SIGMA_APP_ARQUITECTURA.md) | **Cómo** se estructura el código: capas, Riverpod, repositorios, códigos de error |
| [`SIGMA_APP_DISENO.md`](SIGMA_APP_DISENO.md) | **Cómo se ve**: tokens, tema, tamaños táctiles, semántica del color |
| [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md) | **Cómo bajan y suben los datos**: sábana, SQLite, cola, estados, fechas |
| [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md) | **Cómo avisa**: alertas, Firebase, la tabla de dispositivos |
| [`SIGMA_APP_README.md`](SIGMA_APP_README.md) | **Cómo se levanta**: versiones, entorno, firma, compilación |
| [`SIGMA_APP_MOCKUP_BRIEF.md`](SIGMA_APP_MOCKUP_BRIEF.md) | **Qué dibujar**: el brief autocontenido para los mockups (Claude Design) |

Y dos normativos que no son de la app pero la gobiernan:
[`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md) —qué entra y qué no— y
`PATRONES/ASP/CONVENCIONES.md` —cómo se nombra todo—.

---

## 2. Dónde está y qué es

| | |
|---|---|
| **Proyecto** | `C:\Capstone\SIGMA\App\sigma_app` — **creado el 04-09-2026** |
| **Tecnología** | Flutter 3.41.7 · Dart 3.11.5 (verificados en el equipo) · Android, `minSdk` 24 |
| **Arquitectura** | Riverpod + Repository Pattern, offline-first |
| **Application ID** | `cl.codigocreativo.sigma` |
| **API** | `http://localhost/SIGMA/Servicio/API` — 52 endpoints en 20 controllers |
| **Base local** | SQLite (`sqflite`), `sigma_local.db` |
| **Push** | Firebase Cloud Messaging HTTP v1 — **falta montar en los dos lados** |

Quién la abre: los **seis perfiles de terreno** —técnico, supervisor, jefe,
planificador, bodeguero y prevencionista—. El Administrador del Cliente no
entra a la app, y el técnico no entra a la web: `Perfiles.per_ambito` y
`SEL_LOGIN` lo hacen cumplir en el servidor, con 403.

---

## 3. El estándar del que se parte

La arquitectura y las convenciones salen de **FacilityGes** y
**AgendamientosControlGate**, las dos apps del grupo ya en producción, cuyo
código fuente se revisó completo para escribir estos documentos.

**Lo que se copia:** las capas y su orden, los servicios singleton, el
offline-first con SQLite antes que la red, el `SyncService` reactivo con
debounce de 2 s, la compresión de imágenes, el tema por `ThemeExtension`, y
—sobre todo— los errores que allá ya costaron tiempo: base64 en SQLite
reventando el `CursorWindow`, el `ref.read` después de un `await`, el ícono de
la barra de estado a color, el `ORDER BY` que faltaba en el SP.

**Lo que no se copia:** el dominio. FacilityGes es aseo y vigilancia de
instalaciones; SIGMA es mantenimiento industrial. Ni una tabla, ni un endpoint,
ni una pantalla se traen tal cual.

**Las tres divergencias deliberadas**, cada una con su motivo escrito en el
documento que corresponde:

| | FacilityGes | SIGMA |
|---|---|---|
| Resultado de una escritura | `HTTP 200` siempre + `Status` por ítem dentro del cuerpo | **Códigos HTTP reales**, traducidos del `RAISERROR` por `ErrorSql` |
| Cola de salida | Una marca `enviado` por tabla | **Una tabla `outbox` única** |
| Bandeja de avisos | Solo local, en SQLite | **Sale de `GET /alertas`**: SIGMA ya tiene el hallazgo en el servidor |

---

## 4. Qué hay que construir

**23 historias con superficie móvil** entre los Sprints 1, 2 y 3. Estados al
04-09-2026, leídos de los tres Sprint Backlogs.

### Sprint 1 — Fundaciones · 6 historias

Las seis están **En revisión** en web y API. En móvil **no existe ninguna**.

| HU | Historia | Estado backlog |
|---|---|---|
| HU-001 | Iniciar sesión | En revisión |
| HU-002 | Seleccionar cliente | En revisión |
| HU-003 | Cerrar sesión y expirar la inactiva | En revisión |
| HU-004 | Recuperar mi contraseña | **Bloqueada** — SMTP sin configurar |
| HU-005 | Editar mi perfil y cambiar contraseña | En revisión |
| HU-006 | Aplicar mis permisos en la interfaz | En revisión |

### Sprint 2 — Activos y captura en terreno · 7 historias

| HU | Historia | Estado |
|---|---|---|
| **HU-150** | **Sincronizar los datos hacia el dispositivo** (13 pts) | Por hacer |
| HU-037 | Consultar ficha e historial de un activo | En curso |
| HU-038 | Cambiar el estado de un activo con su motivo | En curso |
| HU-043 | Registrar una lectura de medidor | Por hacer |
| HU-044 | Registrar una medición de condición | Por hacer |
| **HU-154** | **Escanear el QR de una posición** | Por hacer |
| HU-193 | Bloquear el acceso por suscripción vencida | En revisión |

### Sprint 3 — Inventario, permisos y alertas · 10 historias

| HU | Historia | Estado |
|---|---|---|
| **HU-151** | **Trabajar sin conexión** (13 pts) | Por hacer |
| HU-054 | Ingreso de repuestos a bodega | En revisión |
| HU-055 | Entregar repuestos contra una OT | En revisión |
| HU-056 | Consultar la existencia de un repuesto | En revisión |
| HU-057 | Registrar un ajuste de inventario | En revisión |
| HU-059 | En qué estante y de qué lote está cada repuesto | En curso |
| HU-063 | Registrar un permiso de trabajo con su evidencia | Por hacer |
| HU-064 | Consultar permisos vigentes y por vencer | Por hacer |
| HU-067 | Consultar escaneando una etiqueta | En curso |
| HU-077 | Que el sistema avise lo que encuentra | En curso |

---

## 5. Estado por módulo

Se va llenando. ✅ hecho · 🟡 hecho a medias, con lo que falta anotado · ⬜ sin empezar.

| Módulo | Estado |
|---|---|
| Proyecto Flutter creado | ✅ `App/sigma_app`, Android, `analyze` limpio |
| Tema y tokens | ✅ `sigma_tokens.dart` + `app_theme.dart` + `AppColors` |
| `ApiClient` + manejo de códigos | ✅ con `ApiException` tipada (401 ≠ 403 ≠ 409) |
| Sesión y login (HU-001) | 🟡 pantalla funcionando contra la API real; falta 402/423 en pantalla |
| Selección de cliente (HU-002) | ✅ `GET /cliente-usuarios/mis-clientes` + `POST /seleccionar` |
| Cierre de sesión (HU-003) | ✅ `DELETE /sesion` |
| Recuperar contraseña (HU-004) | ⬜ bloqueada por SMTP |
| Mi perfil (HU-005) | 🟡 `GET /mi-perfil` alimenta avatar y saludo; falta la pantalla de edición |
| Menú y permisos por datos (HU-006) | ✅ el router se arma desde `GET /menus` |
| SQLite + migraciones | ✅ `sigma_local.db` v1: caché de lo que baja + `outbox` |
| Cola de salida (`outbox`) | ✅ con idempotencia por `uuid`, reintentos, y **nada se descarta** |
| Sincronización descendente (HU-150) | ✅ `API_SEL_APP_SABANA_DATOS` + `GET /sincronizacion`, 9 bloques probados |
| Escáner QR (HU-154 / HU-067) | 🟡 resuelve con `GET /escaneo`; falta `mobile_scanner` |
| Ficha de activo (HU-037) | 🟡 historial de `GET /activos/{id}/ficha`; **falta `GET /activos/{id}`** para la cabecera |
| Lectura de medidor (HU-043) | ✅ `POST /captura/lecturas` vía cola, con interruptor de reinicio |
| Existencias (HU-056/059) | ✅ `GET /existencias` con filtro, búsqueda y fecha de corte |
| Movimiento de bodega (HU-054/055/057) | ✅ `POST /inventario-movimientos` con `uuid` idempotente |
| Permisos de trabajo (HU-063/064) | ✅ vigentes, tipos y estados desde la API |
| Estados del sistema (offline/401/402/403) | ✅ y **verificables en vivo** contra la API |
| Imágenes de activos y repuestos | ✅ `SigmaImagen` + `ImagenService` desde Blob Storage, con caché |
| Logotipo de marca | ✅ los SVG oficiales de `Web/Intranet/Imagen`, variante *dark* |
| Pendientes de envío | ✅ pantalla + badge en el Home, con el motivo del rechazo |
| Conectividad reactiva | ✅ `SyncService` despacha en la transición offline→online, debounce 2 s |
| Alertas y push (HU-077) | 🟡 bandeja y badge desde `GET /alertas`; **falta la tabla y el servicio FCM** |

---

## 6. Bloqueantes

Cosas que impiden avanzar, no que lo hacen incómodo.

1. ~~**La API nunca se ha llamado por HTTP.**~~ **RESUELTO el 04-09-2026.**
   33 endpoints ejercitados con token real. Aparecieron **tres defectos más**
   que nadie podía ver sin llamarla, el mayor de ellos: `TokenValidationHandler`
   solo reconocía el prefijo `Base `, así que con el `Bearer` estándar **todo
   endpoint autenticado respondía 500**. Los cinco están corregidos y
   verificados: ver `SIGMA_ESTADO_DESARROLLO_API.md` §6.

2. ~~**Dos defectos abiertos de la API rompen el login desde la app.**~~
   **RESUELTOS el 04-09-2026**, y verificados: el login responde con `"token"`
   y el 401 con «Correo o contraseña incorrectos.» Eran:
   - `POST /sesion` (200) serializa los *backing fields*: la respuesta trae
     `<token>k__BackingField` en vez de `token`. **Un cliente no puede leer el
     token por su nombre.** Arreglo: quitar `[Serializable]` de `SesionDto`.
   - El 401 pierde el mensaje del controller: `WebApiCustomMessageHandler`
     reemplaza el cuerpo con el texto canónico en inglés. La app mostraría
     «Unauthorized indicates…» en vez de «Correo o contraseña incorrectos».

3. **No existe el endpoint de carga masiva.** HU-150 necesita
   `GET /sincronizacion` y el SP `API_SEL_APP_SABANA_DATOS`. Bajar los
   catálogos con los endpoints paginados actuales son decenas de viajes.

4. **No existe `Usuario_App_Dispositivo`.** Sin ella no hay push, y HU-077 en
   la app queda en consulta manual.

5. **SMTP sin configurar.** Bloquea HU-004 en la app igual que en la web.

6. **La base no tiene datos operativos.** `Cliente_Instalacion`,
   `Instalacion_Area`, `Activo`, `Repuesto`, `Bodega`, `Inventario_Saldo` y
   `Alerta` están en cero; sí hay 1 cliente, 11 usuarios, 82 catálogos y 9
   menús de ámbito APP. No bloquea construir pantallas —el login, el menú y los
   permisos sí traen datos reales— pero **sí bloquea probar HU-150 y todo el
   terreno**. El bloque `37_SPRINT1_DATOS_DEMO` *actualiza* una planta que
   espera encontrar en vez de insertarla, así que nunca creó ninguna.

---

## 7. Lo que apareció al cruzar los backlogs con el alcance

Cuatro cosas. Las dos primeras son buenas noticias; las dos últimas hay que
resolverlas con el Scrum Master.

### 7.1 Las promociones a App **ya están** en el xlsx

`SIGMA_APP_FLUTTER.md` §10.1 dice que HU-004, HU-057 y HU-064 siguen marcadas
«Web» en el backlog. **Ya no.** Leídos hoy, los tres archivos las muestran como
`Web y App`, y HU-057 y HU-064 tienen su tarea de Móvil creada (T-3901 y
T-3902). Esa desalineación está corregida y hay que darla por cerrada en aquel
documento.

### 7.2 El inventario de endpoints es correcto

52 endpoints en 20 controllers, contados hoy leyendo los `RoutePrefix` y
`Route` uno por uno. Coincide con `SIGMA_APP_FLUTTER.md` §6. Lo que sigue
vencido es `SIGMA_ALCANCE_APP.md` §6, que dice «de 64 a 21» al 31-08.

### 7.3 Dos historias marcadas «Web y App» no tienen ninguna tarea de Móvil

| HU | Tareas por tipo |
|---|---|
| **HU-059** — En qué estante y de qué lote está cada repuesto | 7 base de datos, 1 web, 1 pruebas, 1 documentación. **0 móvil** |
| **HU-077** — Que el sistema avise lo que encuentra | 6 base de datos, 5 web, 1 API, 1 pruebas, 1 documentación. **0 móvil** |

Las dos tienen superficie móvil real —el bodeguero necesita saber el estante en
el pasillo, y las alertas son justamente lo que la app debe avisar—. O se les
agrega la tarea, o se les corrige la plataforma. Dejarlas así significa que el
sprint se cierra «completo» con la mitad de dos historias sin hacer.

### 7.4 Las horas de Móvil no alcanzan, y no por poco

| Sprint | Tareas de Móvil | Horas |
|---|---:|---:|
| S1 | 7 | **3,75** |
| S2 | 11 | **5,75** |
| S3 | 10 | **7,50** |
| **Total** | **28** | **17,00** |

Diecisiete horas para construir una aplicación móvil completa —proyecto, tema,
cliente HTTP, base local con migraciones, cola de salida, router por datos,
escáner, seis historias de sesión y dieciséis de terreno—.

Solo la **base**, antes de la primera historia, es del orden de 35–45 h:
proyecto y assets (2), tema y tokens (4), `ApiClient` y manejo de códigos (4),
SQLite y migraciones (6), `outbox` y `SyncService` (10), router desde
`GET /menus` (4), pantalla de pendientes (4), y el montaje de Firebase (4).

La causa es visible en el propio texto de las tareas: la mayoría dice *«consumo
del endpoint desde la app cuando corresponda»*, con 0,25 o 0,75 h. Es la
estimación de **conectar un endpoint a una pantalla que ya existe** — y hoy no
existe ninguna pantalla.

**Esto no se corrige acá.** Es una conversación con Emilio (Scrum Master) y
Catalina (PO) sobre si la app entra en el Sprint 1 con una base de ~40 h o si
se reprograma. Lo que sí queda dicho es que las 17 h del backlog **no son una
estimación de este trabajo**.

---

## 8. Decisiones ya tomadas

Para no rediscutirlas. El detalle y el motivo están en el documento que se
indica.

| Decisión | Dónde |
|---|---|
| Riverpod + Repository, la UI solo lee de providers | Arquitectura §2 |
| **401 cierra sesión; 403 no.** Nunca al revés | Arquitectura §6 |
| Códigos HTTP reales, no `Status` dentro del cuerpo | Arquitectura §6 |
| El menú se arma desde `GET /menus`, jamás una lista en Dart | Arquitectura §7 |
| Nombres de campo iguales a la columna de SQL Server | Arquitectura §8 |
| La red arranca **después** del primer frame | Arquitectura §9 |
| Ruta local en SQLite, base64 solo al enviar | Arquitectura §10 |
| Tema oscuro, y se sobreescriben nueve roles del `ColorScheme` | Diseño §3 |
| Controles de 52 dp, filas de 64 dp, separación de 12 | Diseño §5 |
| Sin conexión es **neutro**, nunca rojo | Diseño §6 |
| Sora como asset `.ttf`, no por `google_fonts` | Diseño §7, README §7 |
| Una cola `outbox` única, no una marca por tabla | Sincronización §3.3 |
| El `uuid` se genera **al encolar**, no al enviar | Sincronización §4.3 |
| **Nada se descarta por cantidad de intentos** | Sincronización §4.4 |
| El 409 se trata como enviado | Sincronización §5 |
| Fecha de captura con offset, siempre | Sincronización §6 |
| No se crea tabla de notificaciones: la bandeja es `Alerta` | Notificaciones §1 |
| El destinatario del push se resuelve por permiso, no por lista | Notificaciones §3.2 |
| `uad_token` único global, y `DELETE` al cerrar sesión | Notificaciones §3.1 y §3.3 |
| `minSdk` 24, solo Android en esta fase | README §1 y §2 |

---

## 9. Por dónde empezar

En este orden, y no en otro. Cada bloque deja algo verificable.

| # | Bloque | Deja |
|---:|---|---|
| **0** | ✅ **HECHO 04-09.** ~~Arreglar los dos defectos de la API~~ — eran **cinco** (§6.2) y probar `POST /sesion` por HTTP con `cristian.munoz@hamburgo.cl`: ámbito WEB → 403, ámbito APP → 200 | La API ejercitada. Sin esto no vale la pena empezar |
| 1 | ✅ **HECHO 04-09.** Proyecto Flutter, `.gitignore`, `.env`, assets, `flutter analyze` limpio | `App/sigma_app`, `No issues found!` |
| 2 | ✅ **HECHO 04-09.** Tema y tokens (Diseño §2 y §3) | `sigma_tokens.dart`, `app_theme.dart`, `AppColors`; 3 tests que fallan si el CSS y la app dejan de ser la misma marca |
| 3 | ✅ **HECHO 04-09.** `ApiClient` + `ApiException` + la tabla de códigos (Arquitectura §6) | Login real contra la API: token, menú y permisos en pantalla |
| 4 | 🟡 **EN CURSO.** **HU-001** entra y sale contra la API real; faltan las pantallas de 402/423, HU-002 y HU-003 | La primera historia móvil cerrada |
| 5 | `GET /menus` y el router por datos (Arquitectura §7) | Navegación antes de la tercera pantalla, para no terminar con rutas a mano |
| 6 | **HU-005 y HU-006** — perfil y permisos | Sprint 1 móvil cerrado |
| 7 | SQLite + migraciones + `outbox` + pantalla de pendientes | La base de todo lo de terreno |
| 8 | `API_SEL_APP_SABANA_DATOS` + `GET /sincronizacion` + **HU-150** | Datos en el teléfono sin señal |
| 9 | `Usuario_App_Dispositivo` + `FcmService` + push + **HU-077** | El aviso que llega solo |
| 10 | Sprint 2 y 3 de terreno, sobre lo anterior | |

El bloque 7 va antes que cualquier pantalla de captura: define el modelo local
del que dependen todas.

---

## 10. Recetas

### Analizar (obligatorio antes de dar algo por terminado)

```bash
flutter analyze
```

Tiene que decir `No issues found`.

### Ejecutar en desarrollo

```bash
flutter run --dart-define-from-file=.env.dev.json
```

### Probar el login contra la API

```bash
curl -X POST http://localhost/SIGMA/Servicio/API/sesion -H "Content-Type: application/json" -d "{\"login\":\"root@codigocreativo.cl\",\"password\":\"1\",\"ambito\":2}"
```

### Pantalla nueva

1. Confirmar contra [`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md) que uno de
   los seis perfiles la va a abrir.
2. Fila en `Menus` con `mnu_ambito` APP o AMBOS y `mnu_link` en `app://`.
3. Entrada en el mapa de rutas de `routes.dart`.
4. Pantalla con `ConsumerWidget` o `ConsumerStatefulWidget`, colores solo por
   roles, objetivos de 52 dp.
5. Si escribe: repositorio → SQLite → `outbox`, y la pantalla confirma sin
   esperar la red.
6. `flutter analyze` limpio.

---

## 11. Bitácora

| Fecha | Qué se hizo |
|---|---|
| 03-09-2026 | Nace [`SIGMA_APP_FLUTTER.md`](SIGMA_APP_FLUTTER.md): las historias con superficie móvil, el contrato de la API y los tokens de marca traducidos a Dart |
| 04-09-2026 | **Brief de mockups.** [`SIGMA_APP_MOCKUP_BRIEF.md`](SIGMA_APP_MOCKUP_BRIEF.md): documento **autocontenido** para que una herramienta de diseño dibuje las pantallas sin abrir ningún otro archivo — marca, paleta, tipografía, medidas táctiles, componentes, y **catorce pantallas con su contenido real** (Hamburgo S.A., MOT-001, Rodamiento 6205), separadas en nivel 1 —las ocho del Sprint 1— y nivel 2. Incluye lo que **no** hay que dibujar |
| 04-09-2026 | **Documentación de arranque completa.** Cinco documentos nuevos —arquitectura, diseño, datos y sincronización, notificaciones, puesta en marcha— más este estado. La arquitectura se tomó de **FacilityGes** y **AgendamientosControlGate**, leyendo su código fuente completo (88 archivos Dart) y el de `FacilityGesApi2.0` (controllers, `FcmService`, modelos y el SP `API_2_SEL_USUARIO_SABANA_DATOS`). Tres divergencias deliberadas y documentadas (§3). Cuatro hallazgos del cruce con los backlogs, dos de ellos para el Scrum Master: **HU-059 y HU-077 no tienen tarea de Móvil** pese a estar marcadas «Web y App», y **las 17 h de Móvil de S1–S3 no cubren ni la base de la app** (§7). Sigue sin escribirse una línea de Dart, y a propósito: el bloque 0 es arreglar los dos defectos de la API que rompen el login |

| 04-09-2026 | **Bloque 0 y andamiaje de la app.** La API se ejercitó por HTTP por primera vez y aparecieron **tres defectos que nadie podía ver sin llamarla**, además de los dos ya anotados. El mayor: `TokenValidationHandler` solo reconocía el prefijo `Base `, así que con el `Bearer` estándar **todo endpoint autenticado respondía 500 con cuerpo vacío**. También: el handler de plantilla pisaba el cuerpo de 46 códigos —incluido el `{id}` de todo 201—, `Conexion` relanzaba sin encadenar la `SqlException` (por eso **ninguna regla de negocio de un `SEL_` se traducía**), y `EscaneoController.cs` no estaba en el `API.csproj`. Los cinco corregidos y verificados; detalle en `SIGMA_ESTADO_DESARROLLO_API.md` §6. **33 endpoints llamados con el token de un técnico real.** Con eso destrabado nació **`App/sigma_app`**: tokens de marca, tema oscuro, `ApiClient` con `ApiException` tipada (401 ≠ 403 ≠ 409 ≠ red), `SesionService` con el JWT persistido, `sesionProvider`, pantalla de login y un Home que **arma el menú desde `GET /menus`**. `flutter analyze` → `No issues found!` y 6 tests verdes. **Hallazgo**: la base tiene la estructura pero cero plantas, áreas, activos, repuestos, bodegas y alertas (§6.6) |
| 04-09-2026 | **Las 10 pantallas del brandkit, contra la API real.** Se rehízo el tema con la paleta exacta del kit (`#0F131E` de lienzo, `#48FCDD` de acento) y la tipografía **Sora variable** —un solo `.ttf` con el eje `wght`, pedido con `fontVariations`, no cuatro archivos—. Nacen `modelos.dart` (16 modelos calcados de los DTOs de la API), `sigma_repository.dart` (un método por endpoint) y `datos_provider.dart` (los `FutureProvider` que observa la UI). **Ningún texto de dato quedó en duro**: existencias, permisos de trabajo, alertas, menú, perfil, clientes, escaneo y ficha de activo salen de sus endpoints, con esqueleto de carga, estado vacío y el **mensaje del servidor** en el error. La sincronización (03) descarga los siete bloques de verdad y muestra el avance real. El movimiento de bodega (13) hace `POST /inventario-movimientos` con **`uuid` generado al abrir la pantalla** y trata el 409 como éxito. **Dos correcciones de dominio que pidió Bryan**: las fotos de activos, repuestos y componentes **no se empaquetan** —se piden a Blob Storage con `SigmaImagen`/`ImagenService`, con caché en disco y memoria y deduplicación—; y se quitaron los rótulos de telemetría IoT del mockup porque **no hay sensores**: las mediciones las toma una persona con la app, así que la ficha dice de cuándo es el dato y quién lo tomó. `flutter analyze` → `No issues found!`, 12 tests verdes |
| 04-09-2026 | **Lo que hace que la app sirva en una planta: no perder trabajo.** Nace la base local `sigma_local.db` —caché de lo que baja, con su fecha, y la tabla `outbox`— y sobre ella `OutboxService`: toda escritura se guarda **en disco antes** de intentar la red y la pantalla confirma con eso, no esperando al servidor. El `uuid` se genera **al encolar**; el **409 se trata como éxito** porque es el duplicado del reintento; y **nada se descarta por cantidad de intentos** — solo un veredicto del servidor saca un ítem de la cola. `SyncService` despacha al abrir la app y en la transición offline→online, con debounce de 2 s porque la conectividad de Android parpadea. La pantalla de **pendientes** muestra lo que espera y lo rechazado **con el motivo tal como lo dijo el servidor**, y deja reintentar o corregir: sin ella la cola es una caja negra. Del lado del servidor se construyó la **sábana de datos** (bloque 140) y los **INS de captura** (141) con sus permisos (142) — detalle en `SIGMA_ESTADO_DESARROLLO_API.md`. La pantalla de lectura ya escribe de verdad, con el interruptor de reinicio que el SP exige. Y el **logotipo pasó a ser el SVG oficial** de `Web/Intranet/Imagen` en variante *dark*, no una reinterpretación dibujada a mano |
### Cómo actualizar este documento

Al cerrar un bloque: agregar la fila en la bitácora, marcar el módulo en §5,
mover lo resuelto de §6 a §8, y anotar en §8 **toda decisión que un tercero no
podría deducir del código**. Esa sección es la que evita rehacer discusiones ya
cerradas.
