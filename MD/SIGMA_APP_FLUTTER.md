# SIGMA — La aplicación móvil: qué construir y cómo tiene que verse

**Para qué sirve este documento.** Es el punto de partida del desarrollo en
Flutter. Reúne, en un solo lugar, las historias de los Sprints 1, 2 y 3 que
tienen superficie móvil, el contrato de la API que ya está publicada, y el
sistema de diseño con los tokens de marca traducidos a Dart para que la app no
se parezca a la web: **sea** la misma cosa en otra pantalla.

Fecha: 03-09-2026 · Código Creativo · Bryan Chávez

> **Este documento dice QUÉ construir.** El cómo se reparte en cinco
> documentos que nacieron el 04-09-2026 y que hay que leer antes de empezar:
> [`SIGMA_APP_ESTADO.md`](SIGMA_APP_ESTADO.md) (dónde está todo y por dónde
> empezar) · [`SIGMA_APP_ARQUITECTURA.md`](SIGMA_APP_ARQUITECTURA.md) ·
> [`SIGMA_APP_DISENO.md`](SIGMA_APP_DISENO.md) ·
> [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md) ·
> [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md) ·
> [`SIGMA_APP_README.md`](SIGMA_APP_README.md).
>
> Donde la §5 de acá y `SIGMA_APP_DISENO.md` difieran, **manda el documento de
> diseño**: es posterior y explica el motivo del cambio (§3 de ese archivo).

**De dónde sale cada cosa.** Nada de acá está escrito de memoria:

| Qué | Fuente leída |
|---|---|
| Las 20 historias con App | `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx`, hojas Sprint 1–3 |
| Perfiles, ámbito y reglas de alcance | `MD/SIGMA_ALCANCE_APP.md` (normativo) |
| Los 52 endpoints | `Solucion/SIGMA/API/Controllers/*.cs`, leídos uno por uno |
| Los tokens | `Web/Intranet/Css/LookAndFeel/sigma-brand.css` |

Lo que **no** verifiqué está marcado como tal en la §10. No hay ninguna
afirmación de "esto funciona" sin haberlo comprobado.

---

## 1. Quién abre esta app

Seis perfiles, y el criterio no es "los usuarios del cliente":

| Perfil | Qué hace en el teléfono |
|---|---|
| **Técnico de Mantenimiento** | ejecuta: su bandeja, los pasos de la OT, lecturas, mediciones, evidencias, bitácora, consumo de repuestos, descubrimiento en terreno |
| **Supervisor de Mantenimiento** | valida en planta: firmas, estado de activos, fallas, indisponibilidad, reasignar una OT |
| **Jefe de Mantenimiento** | acepta OT, autoriza permisos de trabajo, mira el panel |
| **Planificador** | consulta y alertas; **su planificación es de escritorio** |
| **Bodeguero** | ingreso, entrega, existencia y ajuste, en el pasillo |
| **Prevencionista** | permisos de trabajo: los registra y los verifica en el frente |

**El Administrador del Cliente no entra a la app.** Configura desde la web
—usuarios, perfiles, plantas, áreas, centros de costo, catálogos— para que los
seis de arriba puedan operar. Root, Soporte y Gerente Comercial tampoco: son
cuentas de plataforma.

Y al revés: **el técnico no usa la web**. No es una recomendación, es una
restricción del servidor. `Perfiles.per_ambito` vale APP para su perfil y
`SEL_LOGIN` rechaza con 403 a quien entra por la superficie equivocada.

> El mensaje del 403 dice *dónde sí* puede entrar: «Tu perfil trabaja desde la
> aplicación móvil de SIGMA, no desde la web». Un "acceso denegado" a secas
> manda al técnico a llamar al administrador por algo que no es un problema.
> **La app tiene que hacer lo mismo en el caso espejo.**

---

## 2. Tres reglas que ya se aplicaron al backlog

No hay que volver a discutirlas; explican por qué el alcance móvil es el que es.

| | Regla |
|---|---|
| **R1** | Una historia **sin App** no lleva endpoints. La web es WebForms y llama a los SP directo: un endpoint para una historia solo web no lo consume nadie |
| **R2** | Una historia **solo App** no lleva pantalla web |
| **R3** | El técnico no usa la web: si su único actor es el técnico, la historia es App |

Y una excepción que importa para la sincronización:

> **E2** — Plantas, áreas y catálogos son historias de administración (web),
> pero la app necesita *leerlos*. Se conserva el `GET`; la escritura es de la
> web. Son los datos que bajan al dispositivo en HU-150.

---

## 3. Lo que hay que construir, sprint por sprint

**20 historias con superficie móvil.** Los estados son los del backlog al
03-09-2026.

### Sprint 1 — Fundaciones · 5 historias

Las cinco están **En revisión** en web y API. En móvil no existe ninguna.

| HU | Historia | Qué es en la app |
|---|---|---|
| HU-001 | Iniciar sesión | Correo y contraseña. El servidor decide el ámbito |
| HU-002 | Seleccionar cliente | Solo si la persona pertenece a más de uno |
| HU-003 | Cerrar sesión y expirar la inactiva | Incluye el vencimiento del token |
| HU-005 | Editar mi perfil y cambiar contraseña | |
| HU-006 | Aplicar mis permisos en la interfaz | El menú y las acciones salen de datos, no de código |

Y una promovida a App el 30-08 que **el backlog todavía muestra como Web** —ver
§10:

| HU-004 | Recuperar mi contraseña | El técnico no tiene web donde pedirla |

### Sprint 2 — Activos y captura en terreno · 7 historias

Todas **Por hacer**.

| HU | Historia | Qué es en la app |
|---|---|---|
| **HU-150** | **Sincronizar los datos hacia el dispositivo** | La base de la operación en terreno. Ver §7 |
| HU-037 | Consultar la ficha y el historial de un activo | Lectura |
| HU-043 | Registrar una lectura de medidor | Captura. Solo App + su consulta web |
| HU-044 | Registrar una medición de condición | Captura |
| HU-038 | Cambiar el estado de un activo con su motivo | El motivo es obligatorio |
| **HU-154** | **Escanear el QR de una posición** | Cámara. Ver §8 |
| HU-193 | Bloquear el acceso por suscripción vencida | La app respeta el mismo corte que la web |

### Sprint 3 — Inventario, permisos y alertas · 8 historias

Cinco **Por hacer**, tres **En curso** en web.

| HU | Historia | Qué es en la app |
|---|---|---|
| **HU-151** | **Trabajar sin conexión** | Cola de operaciones y reconciliación. Ver §7 |
| HU-054 | Registrar el ingreso de repuestos a bodega | Bodeguero, en el pasillo |
| HU-055 | Entregar repuestos contra una OT | Bodeguero |
| HU-056 | Consultar la existencia de un repuesto | |
| HU-059 | En qué estante y de qué lote está cada repuesto | Ubicación y lote |
| HU-063 | Registrar un permiso de trabajo con su evidencia | Prevencionista, con foto |
| HU-067 | Consultar escaneando una etiqueta | Reusa el escáner de HU-154 |
| HU-077 | Que el sistema avise lo que encuentra | Alertas |

Más dos promovidas que el backlog aún muestra como Web (§10): **HU-057**
(ajuste de inventario, el bodeguero cuenta en el pasillo) y **HU-064**
(permisos vigentes y por vencer, el prevencionista verifica en el frente).

---

## 4. El menú no se escribe en Dart

En la web, una pantalla sin fila en `Menus` no se abre. Si la app trajera sus
opciones escritas en el código habría **dos modelos de permisos** que mantener,
y el día que se revoque uno la web lo escondería y el teléfono no.

`GET /menus` devuelve el árbol ya resuelto para quien entró:

- solo filas con `mnu_ambito` APP o AMBOS;
- comparadas contra los permisos vigentes —perfil, concesión, revocación,
  vigencia y planta— con la misma función que usa la web;
- los grupos suben solos: un nodo padre aparece porque tiene hijos visibles,
  nunca vacío;
- `mnu_link` usa el esquema `app://` para que se vea de un vistazo que esa fila
  no apunta a ningún `.aspx`.

**Hoy devuelve dos opciones**: `app://inicio` y `app://mi-perfil`. Porque hoy la
app tiene dos pantallas. Las de órdenes, repuestos, checklists y permisos son
filas nuevas en `Menus` y **nacen en el sprint donde se construye la pantalla**.
Sembrarlas antes da un menú que navega a la nada.

> En Flutter: el router se arma desde ese árbol. Un `Map<String, WidgetBuilder>`
> de `app://...` a pantalla, y lo que el servidor no manda, no se dibuja.
> Nunca una lista de items en el código.

---

## 5. El sistema de diseño

### 5.1 Reglas de marca

Estas cuatro no son preferencias, son identidad y ya están aplicadas en la web:

1. **Navy, Purple, Teal y Pink son identidad.** Verde, amarillo y rojo quedan
   reservados a **estados operativos** y no se usan para decorar.
2. **El degradado es acento, nunca fondo** de una superficie de trabajo.
3. **La web prioriza tema claro.** La app hereda el **tema oscuro**, que en la
   web gobierna el sidebar: es la superficie que se mira en una planta, muchas
   veces con guantes y contraluz.
4. **El teal lleva tinta navy, no blanca.** Blanco sobre `#00BFAE` da **2.32:1**
   y es ilegible; navy da **8.26:1**. El teal es un color claro: pide tinta
   oscura encima.

### 5.2 Tokens

Copiados de `sigma-brand.css`. **Son los mismos números**, no una
reinterpretación.

```dart
/// SIGMA · tokens de marca 2026.1
/// Espejo exacto de Web/Intranet/Css/LookAndFeel/sigma-brand.css.
/// Si un valor cambia allá, cambia acá: son la misma marca, no dos.
abstract final class SgColor {
  // ---- Marca ----
  static const navy            = Color(0xFF0B0F1A);
  static const purple          = Color(0xFF6C5CFF);
  static const purpleHover     = Color(0xFF5847E8);
  static const teal            = Color(0xFF00E0C2);
  /// El teal de identidad no alcanza contraste sobre blanco.
  /// Este es el que se usa cuando hay que leer algo encima.
  static const tealAccessible  = Color(0xFF00BFAE);
  static const blue            = Color(0xFF2563EB);
  static const pink            = Color(0xFFFF4D9D);

  // ---- Tema claro ----
  static const background      = Color(0xFFF8FAFC);
  static const surface         = Color(0xFFFFFFFF);
  static const surfaceSubtle   = Color(0xFFF3F5F8);
  static const textPrimary     = Color(0xFF0B0F1A);
  static const textSecondary   = Color(0xFF475569);
  static const textMuted       = Color(0xFF64748B);
  static const border          = Color(0xFFE2E8F0);
  static const borderStrong    = Color(0xFFCBD5E1);

  // ---- Tema oscuro: el de la app ----
  static const darkBackground      = Color(0xFF080C17);
  static const darkSurface         = Color(0xFF111827);
  static const darkSurfaceElevated = Color(0xFF182235);
  static const darkTextPrimary     = Color(0xFFF8FAFC);
  static const darkTextSecondary   = Color(0xFFA8B2C3);
  static const darkBorder          = Color(0xFF2A3548);

  // ---- Estados operativos: NO son identidad ----
  static const success       = Color(0xFF16A34A);
  static const successSubtle = Color(0xFFDCFCE7);
  static const info          = Color(0xFF2563EB);
  static const infoSubtle    = Color(0xFFDBEAFE);
  static const warning       = Color(0xFFF59E0B);
  static const warningSubtle = Color(0xFFFEF3C7);
  static const danger        = Color(0xFFDC2626);
  static const dangerSubtle  = Color(0xFFFEE2E2);

  /// Solo como acento: una franja, un borde, un icono.
  /// Nunca de fondo de una superficie donde haya que leer o trabajar.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, blue, purple, pink],
    stops: [0.0, 0.42, 0.72, 1.0],
  );
}

abstract final class SgRadius {
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 22.0;
  static const pill = 999.0;
}

abstract final class SgElevation {
  /// 0 4px 16px rgba(11,15,26,.08)
  static const card = [BoxShadow(
    color: Color(0x140B0F1A), blurRadius: 16, offset: Offset(0, 4))];

  /// 0 12px 32px -8px rgba(11,15,26,.12)
  static const elevated = [BoxShadow(
    color: Color(0x1F0B0F1A), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 12))];
}

abstract final class SgMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  /// cubic-bezier(0.2, 0, 0, 1)
  static const easing = Cubic(0.2, 0, 0, 1);
}
```

### 5.3 Tipografía

**Sora**, variable 100–800. Está versionada en
`Web/Intranet/Css/LookAndFeel/Fonts/Sora/Sora-Variable.woff2`.

> Flutter **no lee `woff2`**. Hay que agregar los `.ttf` de Sora a
> `assets/fonts/` —de Google Fonts, misma familia y mismos pesos— y declararlos
> en `pubspec.yaml`. Convertir el woff2 también sirve; lo que no sirve es
> apuntar al archivo de la web.

Fallback: `Inter`, luego la del sistema. Es la misma cadena que la web.

### 5.4 Espaciado y tamaños táctiles

La web trabaja con alturas de 42 px porque se usa con mouse. **En el teléfono
eso no alcanza**: el mínimo de un objetivo táctil es **48 dp** (Material) y en
una planta se toca con guantes.

| Token | Web | App | Por qué |
|---|---:|---:|---|
| Alto de control | 42 px | **52 dp** | guantes, movimiento, sin apoyar la mano |
| Separación entre acciones | 8 px | **12 dp** | evita el toque equivocado |
| Margen de pantalla | 16 px | **16 dp** | igual |
| Alto de fila de lista | ~40 px | **64 dp** | dos líneas: el dato y su contexto |

Los radios y los colores **no** cambian: cambia lo que el dedo necesita, no la
identidad.

### 5.5 El tema

```dart
/// El tema OSCURO es el de la app, no una opción.
/// En la web el oscuro gobierna el sidebar; acá gobierna todo: es la
/// superficie que se mira en una planta, con contraluz y a veces con el
/// teléfono dentro de una funda.
ThemeData sigmaOscuro() {
  const esquema = ColorScheme.dark(
    primary:   SgColor.purple,
    onPrimary: Colors.white,
    secondary: SgColor.tealAccessible,
    onSecondary: SgColor.navy,          // navy, no blanco: ver §5.1 regla 4
    surface:   SgColor.darkSurface,
    onSurface: SgColor.darkTextPrimary,
    error:     SgColor.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: SgColor.darkBackground,
    fontFamily: 'Sora',
    // ...
  );
}
```

### 5.6 Componentes: de la web a Flutter

| Web | App | Nota |
|---|---|---|
| `.sigma-accion.is-primaria` | `FilledButton` morado | mismo `purple` y `purpleHover` |
| `.sigma-accion` | `OutlinedButton` | borde `darkBorder` |
| `.grid-estado-chip` | `Chip` compacto | los colores salen de **estado**, no de marca |
| `.sg-avatar` | `CircleAvatar` | **el color sale del id, nunca de un hash del nombre**: con siete usuarios reales, el hash del nombre daba solo cuatro colores |
| `.sg-rep-thumb` | `ClipRRect` + `BoxFit.cover` | recortar, no deformar: estirar una pieza la hace irreconocible |
| Grilla Telerik | `ListView` de tarjetas | una tabla no cabe en 390 dp; se lee como lista |
| `.sigma-modal` | `showModalBottomSheet` | el pulgar llega abajo, no arriba |
| Pestañas de categoría | `TabBar` desplazable | mismo criterio: la vacía se apaga, no se esconde |

**El avatar y sus colores** ya están resueltos en `SitioBase.Avatar`: doce tonos,
elegidos por `id % 12`. La app tiene que usar **la misma paleta y el mismo
criterio**, o la misma persona saldrá de un color en la web y de otro en el
teléfono, y el color deja de servir para reconocerla.

---

## 6. La API que ya está publicada

**52 endpoints en 20 controllers**, contados leyendo los archivos hoy. Base:
`/API`.

### 6.1 Sesión e identidad — Sprint 1

| Endpoint | HU |
|---|---|
| `POST /sesion` · `GET /sesion` · `DELETE /sesion` | HU-001, HU-003 |
| `GET /cliente-usuarios/mis-clientes` · `POST /cliente-usuarios/seleccionar` | HU-002 |
| `GET /usuario-permisos` · `GET /usuario-permisos/tengo/{codigo}` | HU-006 |
| `GET /menus` | HU-006 |
| `GET /mi-perfil` · `PUT /mi-perfil` · `POST /mi-perfil/password` | HU-005 |
| `POST /usuario-recuperaciones` · `POST /usuario-recuperaciones/restablecer` | HU-004 |

### 6.2 Datos que bajan al dispositivo — HU-150

`GET /cliente-instalaciones` · `GET /cliente-instalaciones/{id}` ·
`GET /instalacion-areas` · `GET /instalacion-areas/{id}` ·
`GET /catalogos` · `GET /catalogos/{codigo}/valores`

### 6.3 Activos — Sprint 2

`GET /activos/{id}/ficha` · `POST /activo-estados`

### 6.4 Inventario — Sprint 3

`GET /bodegas` · `GET /bodegas/{id}` · `GET /bodegas/{id}/ubicaciones` ·
`GET /repuestos` · `GET /repuestos/{id}` · `GET /repuestos/{id}/lotes` ·
`GET /existencias` · `GET /existencias/repuesto/{id}` ·
`GET /inventario-movimientos` · `GET /inventario-movimientos/{id}` ·
`POST /inventario-movimientos`

### 6.5 Permisos de trabajo, alertas, escaneo y archivos

`GET /permisos-trabajo` · `/vigentes` · `/{id}` · `/tipos` · `/estados` ·
`POST /permisos-trabajo` · `PUT /permisos-trabajo/{id}` ·
`GET /alertas` · `/resumen` · `POST /alertas/{id}/leer` ·
`GET /escaneo` ·
`POST|GET|PUT|DELETE /archivo` · `GET /archivo/ver` · `/propiedades` · `/estado`

### 6.6 Dos cosas que la app tiene que respetar

**403 no es 401.** El token está bien; quien lo trae, no. La distinción importa
porque ante un **401 la app borra la sesión** y vuelve a pedir credenciales, y
ante un **403 no debe hacerlo**: reintentar con otro login no cambia nada, y
haber cerrado la sesión hace perder el trabajo en curso.

**La API valida permisos, y no siempre lo hizo.** Hasta el 30-08 los controllers
solo comprobaban que el token fuera válido: el token de un técnico servía para
llamar `POST /clientes`. Hoy cada endpoint lleva su `ExigirPermiso`. La app
igual debe esconder lo que la persona no puede hacer —un botón que siempre
responde 403 es un botón roto— pero **la comprobación de verdad está en el
servidor**, no en el teléfono.

---

## 7. Sin conexión: HU-150 y HU-151

Son las dos historias que definen si la app sirve en una planta. Merecen
decidirse antes de escribir la primera pantalla, porque condicionan el modelo de
datos local.

**HU-150 — lo que baja.** Plantas, áreas, catálogos, activos, repuestos,
bodegas y ubicaciones. Es lectura y cambia poco: se guarda local y se refresca
cuando hay red.

**HU-151 — lo que sube.** Lecturas, mediciones, movimientos de inventario,
permisos, evidencias. Se encolan y se envían cuando vuelve la señal.

Tres decisiones que no conviene dejar para después:

1. **La cola tiene que ser idempotente.** Un movimiento de inventario enviado
   dos veces descuadra el stock. Cada operación local lleva un identificador
   propio que viaja al servidor, y el servidor rechaza el repetido. Sin eso, un
   reintento por timeout duplica el consumo.
2. **La fecha es la de captura, no la del envío.** Una lectura tomada a las
   09:00 y enviada a las 18:00 es de las 09:00. Y el servidor corre en
   **UTC−07:00** mientras la planta está en Chile: esto ya nos costó un bug
   —un tramo «desde hoy» aparecía como PENDIENTE— que se corrigió en el bloque
   134 con `AT TIME ZONE`. La app **manda la fecha con su zona**, no un
   `DateTime` suelto.
3. **Lo que falló tiene que verse.** Una cola que reintenta en silencio y
   descarta al tercer intento pierde trabajo sin avisar. Debe haber una pantalla
   que liste lo pendiente y lo rechazado, con el motivo.

---

## 8. El escáner: HU-154 y HU-067

Una sola pantalla de cámara para las dos historias. Lo que cambia es qué se hace
con el código, no cómo se lee.

`GET /escaneo` resuelve el código contra el servidor. Con HU-151 hay que poder
resolverlo **también contra la copia local**, porque una bodega sin señal es el
caso normal, no la excepción.

---

## 9. Lo que NO va en la app

Escrito para que nadie lo construya de más:

- Administración de usuarios, perfiles y su matriz de permisos.
- Alta de clientes, plantas, áreas, centros de costo, catálogos, grupos de
  trabajo y especialidades. La app los **lee**; no los escribe.
- Planificación: programaciones, planes de mantenimiento, calendarios.
- El módulo comercial: planes, suscripciones, períodos y pagos.
- Informes y descargas a Excel.

Todo eso es web, y ya está construido o en curso. Un endpoint móvil para
cualquiera de esas cosas **no lo consumiría nadie** — es exactamente el error
que se corrigió el 31-08, cuando la API pasó de 64 a 21 endpoints retirando lo
que sobraba.

---

## 10. Lo que encontré desalineado, y no arreglé

Tres cosas que aparecieron al cruzar las fuentes. Las dejo anotadas en vez de
elegir una en silencio, porque son decisiones del equipo:

1. ~~**Tres historias promovidas a App siguen marcadas «Web» en el backlog.**~~
   **RESUELTO (04-09-2026).** Releídos los tres Sprint Backlogs, HU-004,
   HU-057 y HU-064 aparecen como `Web y App`, y las dos últimas ya tienen su
   tarea de Móvil creada (T-3901 y T-3902). El xlsx está corregido.

   En su lugar apareció otra, del mismo cruce: **HU-059 y HU-077 están
   marcadas «Web y App» y no tienen ninguna tarea de Móvil.** Ver
   [`SIGMA_APP_ESTADO.md`](SIGMA_APP_ESTADO.md) §7.3.

2. **El inventario de endpoints del ALCANCE está vencido.** Dice «de 64 a 21
   endpoints, en 9 controllers» al 31-08. Hoy hay **52 en 20 controllers**: el
   equipo construyó lo de los Sprints 2 y 3. La §6 de acá es el conteo real de
   hoy; conviene actualizar el otro documento para que no se contradigan.

3. **La API nunca se ha llamado por HTTP.** Compila y los SP están probados con
   SQL directo, pero ningún endpoint se ha ejercitado. **Antes de la primera
   pantalla Flutter hay que probar `POST /sesion`** con
   `cristian.munoz@hamburgo.cl`, que es justo el caso que distingue web de app:
   ámbito WEB debe dar 403 y ámbito APP, 200. Construir la app sobre una API sin
   ejercitar es apilar dos incógnitas.

---

## 11. Por dónde empezar

En este orden, y no en otro:

1. **Probar `POST /sesion` por HTTP.** Es la deuda de la §10.3 y bloquea todo
   lo demás.
2. **El tema y los tokens** (§5). Media hora, y evita que las primeras
   pantallas nazcan con colores a ojo que después hay que perseguir.
3. **HU-001, HU-002, HU-003** — entrar, elegir cliente, salir.
4. **`GET /menus` y el router por datos** (§4). Antes de la tercera pantalla,
   para no terminar con una lista de rutas escrita a mano.
5. **HU-005 y HU-006** — perfil y permisos. Cierra el Sprint 1 móvil.
6. **HU-150** (§7) antes de cualquier pantalla del Sprint 2: define el modelo
   local del que dependen las demás.

---

## 12. Bitácora

| Fecha | Qué |
|---|---|
| 03-09-2026 | Nace este documento. 20 historias con App en S1–S3 extraídas del backlog; 52 endpoints contados leyendo los controllers; tokens copiados de `sigma-brand.css`. Tres desalineaciones anotadas en §10 |
| 04-09-2026 | Nacen los cinco documentos operativos de la app (arquitectura, diseño, sincronización, notificaciones, puesta en marcha) más el de estado. **§10.1 queda resuelta**: el xlsx ya trae las tres promociones a App. Recuento con las promociones incluidas: **23 historias** con superficie móvil en S1–S3 (6 + 7 + 10) |
