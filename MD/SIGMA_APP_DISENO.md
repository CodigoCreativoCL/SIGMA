# SIGMA App — Sistema de diseño

> **Normativo.** Define los tokens, su semántica y las reglas de uso de la
> interfaz móvil. Fuente de verdad en código: `lib/theme/sigma_tokens.dart` y
> `lib/theme/app_theme.dart`. Fuente de verdad de la **marca**:
> `Web/Intranet/Css/LookAndFeel/sigma-brand.css`.
>
> Si un valor cambia en el CSS, cambia acá. **Son la misma marca, no dos.**

Fecha: 04-09-2026 · Código Creativo · Bryan Chávez
**Estándar vigente: v2** — `SIGMA App v2.dc.html` (Claude Design)

---

## 0. El estándar v2, y qué cambió

Lo que sigue vale desde el 04-09-2026 y **sustituye** a la versión anterior de
este documento donde difieran. Sale de `SIGMA App v2.dc.html`, importado del
proyecto de Claude Design con el MCP.

### 0.1 Los dos modos, y por qué el texto de estado tiene su propio token

El kit define **oscuro y claro** con el mismo juego de nombres. La decisión que
lo hace funcionar: **cada estado operativo tiene tres tokens, no uno**.

| | Relleno | Tinte de fondo | Texto |
|---|---|---|---|
| Peligro | `#DC2626` | mismo al 16 % / 10 % | `#F87171` oscuro · `#B91C1C` claro |
| Advertencia | `#F59E0B` | ídem | `#F59E0B` · `#B45309` |
| Éxito | `#16A34A` | ídem | `#34D399` · `#15803D` |
| Informativo | `#2563EB` | ídem | `#60A5FA` · `#1D4ED8` |

**El relleno no cambia entre modos; el texto sí.** Sobre blanco, escribir con
el `#DC2626` de relleno queda al límite de contraste; sobre casi negro, el
`#B91C1C` no se lee. Un solo token por estado obliga a elegir cuál de los dos
modos se ve mal.

Lo mismo con el morado: `#6C5CFF` en oscuro, `#5847E8` en claro, porque el
primero sobre blanco pierde contraste en el texto del botón.

Y el fondo claro **no es blanco**: es `#EFF3F9`. Así las tarjetas blancas se
separan sin necesitar borde.

### 0.2 Cómo se consumen

**Ninguna pantalla pregunta por el modo.** Todas leen `context.sg`, que
entrega el juego activo, y los roles del `ColorScheme`. Un `if (esOscuro)`
dentro de un widget rompe la propiedad que hace posible tener los dos modos
con un solo juego de pantallas.

```dart
final sg = context.sg;
Container(color: sg.card)                    // no SgColor.oscuroCard
Text('...', style: sora(15, 600, color: sg.tinta))
Icon(Icons.warning, color: sg.ambarTexto)    // el texto, no el relleno
Container(color: sg.tinte(SgColor.rojo))     // el tinte, con su opacidad por modo
```

`SgColor.*` solo se usa para lo que **no** depende del modo: la marca (navy,
teal, pink) y el relleno de los estados.

### 0.3 El modo de fábrica es oscuro, no «Sistema»

La app se usa en planta. Dejar que Android decida haría que el técnico entre
en claro solo porque nunca tocó ese ajuste. **Sistema** existe como tercera
opción —quien tiene el teléfono en automático espera que la app lo siga— pero
no es el valor inicial.

Se cambia en **Mi perfil → Tema** y queda guardado (`TemaService`).

### 0.4 Formas y medidas v2

| Token | v1 | **v2** | Nota |
|---|---:|---:|---|
| Radio de tarjeta | 12 | **18** | y **sin franja de color a la izquierda** |
| Radio de bloque interno | 12 | **14** | |
| Radio de chip / código | 8 | **6** | |
| Radio de hoja inferior | 22 | **24** | |
| Fila de lista | 64 | **44** | altura *visual*; ver abajo |
| Fila que ES el objetivo táctil | 52 | **52** | opción de menú, ítem de lista |
| Botón principal | 56 | **52** | píldora, ancho completo, al pie |
| Chip de filtro | — | **34** | |
| Badge | — | **26** | |
| Barra inferior | 72 | **76** | |

**La franja de color de la tarjeta se fue.** Una franja de 4 px es difícil de
ver con el teléfono en la mano y a contraluz, y además obligaba a que toda
tarjeta tuviera estado. Ahora el estado se lee en el chip y en el ícono.

> **La fila de 44 está por debajo de los 48 dp de Material**, y es una tensión
> real con §5: en una planta se toca con guantes. Se resuelve así: **44 es la
> altura visual** de una fila dentro de una tarjeta mayor; donde la fila
> entera es el objetivo táctil se usa **52** (`SgMedida.filaTocable`). Si en
> pruebas de terreno el 44 falla, sube a 48 y se anota acá.

### 0.5 Iconografía: Material Design Icons

El kit usa **MDI** (`mdi mdi-home-outline`), la misma familia que la columna
`Menus.mnu_icon` de la base y que el sidebar de la web. Es lo que permitiría
que el ícono de cada opción del menú **venga del servidor** en vez de estar
mapeado en Dart.

Hoy la app usa los `Icons.*` de Flutter. **Pendiente**: agregar
`material_design_icons_flutter` y resolver `mnu_icon` directo, para que
registrar una pantalla siga siendo un `INSERT` en `Menus` —ícono incluido— y
no un `INSERT` más una edición de código.


## 1. Las cuatro reglas de marca

No son preferencias: ya están aplicadas en la web y una app que las rompa se
va a ver como otro producto.

1. **Navy, Purple, Teal y Pink son identidad.** Verde, amarillo y rojo quedan
   reservados a **estados operativos** y no se usan para decorar. Un chip
   verde tiene que significar algo.
2. **El degradado es acento, nunca fondo** de una superficie de trabajo. Una
   franja, un borde, un ícono. Nunca detrás de un formulario.
3. **La web prioriza el tema claro; la app hereda el oscuro.** En la web el
   oscuro gobierna el sidebar; en la app gobierna todo. Es la superficie que
   se mira en una planta, con contraluz y a veces detrás de una funda.
4. **El teal lleva tinta navy, no blanca.** Blanco sobre `#00BFAE` da
   **2.32:1** y es ilegible; navy da **8.26:1**. El teal es un color claro:
   pide tinta oscura encima.

---

## 2. Tokens

**Los valores viven en `lib/theme/sigma_tokens.dart`**, no acá: un bloque de
código en un documento se desactualiza sin que nadie se entere, y ya pasó —
esta sección traía la paleta v1 después de que el kit pasó a v2.

Lo que hay que saber está en §0.1 (los tres tokens por estado y por qué), §0.4
(las formas) y el propio archivo, que lleva el motivo de cada decisión al lado
del valor.

La regla de consumo, que sí es normativa: **`context.sg` para todo lo que
depende del modo; `SgColor.*` solo para lo que no** —la marca y el relleno de
los estados—.

---

## 3. Cómo se construye el tema

```dart
ThemeData sigmaOscuro() {
  final base = ColorScheme.fromSeed(
    seedColor: SgColor.purple,        // el morado genera la familia armónica
    brightness: Brightness.dark,
  );

  final esquema = base.copyWith(
    // -- Marca --
    primary:     SgColor.purple,
    onPrimary:   Colors.white,
    secondary:   SgColor.tealAccessible,
    onSecondary: SgColor.navy,        // navy, no blanco: regla 4 de §1
    // -- Superficies: se fijan a los tokens de SIGMA, ver el recuadro --
    surface:     SgColor.darkSurface,
    onSurface:   SgColor.darkTextPrimary,
    onSurfaceVariant: SgColor.darkTextSecondary,
    outlineVariant:   SgColor.darkBorder,
    error:       SgColor.danger,
  );
  ...
}
```

> **Por qué acá SÍ se sobreescriben las superficies.**
>
> El estándar de FacilityGes dice, con razón, que nunca se toquen los roles de
> superficie: los genera `fromSeed` y sobreescribirlos tiñe la app. En SIGMA
> hay un motivo que pesa más: **los tres tonos oscuros ya existen y son
> públicos** (`#080C17`, `#111827`, `#182235`), están en `sigma-brand.css` y
> son los que el usuario ve todos los días en el sidebar de la web. Una
> superficie generada por `fromSeed` desde el morado sería morada, y el
> teléfono no se parecería al escritorio.
>
> Se sobreescriben **exactamente seis roles** —`primary`, `onPrimary`,
> `secondary`, `onSecondary`, `surface`, `onSurface`— más `onSurfaceVariant`,
> `outlineVariant` y `error`. **Todo el resto** —los `*Container`, `inverse*`,
> `shadow`, `scrim`, los `surfaceContainer*`— viene de `fromSeed` y se usa vía
> `Theme.of(context).colorScheme`. Ampliar esa lista sin dejarlo escrito acá
> es cómo empieza una app teñida a mano.

### Claro y oscuro

La app es **oscura**. No es una preferencia del usuario: es la decisión de
§1.3, y todas las pantallas se diseñan para ella.

Aun así, el tema se construye **solo con roles** —nada de `if (esOscuro)`
repartido por las pantallas— de modo que agregar `AppTheme.claro()` más
adelante sea una función nueva y ninguna pantalla tocada. Hasta que exista,
`themeMode` queda fijo en `ThemeMode.dark`.

---

## 4. `AppColors` — los neutros que M3 no cubre

`ThemeExtension` accesible con `context.appColors`. Para tonos que el
`ColorScheme` no tiene y que se repiten en toda la app.

| Token | Oscuro | Uso |
|---|---|---|
| `pageBg` | `#080C17` | Fondo de pantalla (`scaffoldBackgroundColor`) |
| `cardBg` | `#111827` | Tarjetas y formularios |
| `cardElevado` | `#182235` | Tarjeta sobre tarjeta, bottom sheet, menú |
| `cardBorde` | `#2A3548` | Borde de cards, chips y campos |
| `chipBg` | `#182235` | Chips de adjunto y de filtro |
| `areaAdjuntosBg` | `#0F1524` | Zona de adjuntos en formularios |
| `toolbarBg` | `#111827` | Barra inferior de acciones |
| `textoPrimario` | `#F8FAFC` | Texto de alto contraste |
| `textoSecundario` | `#A8B2C3` | Subtítulos, ayuda |
| `textoTenue` | `#64748B` | Metadatos, etiquetas |
| `heroBg` | `#182235` | Cabeceras de módulo y círculos de ícono |
| `heroFg` | `#00E0C2` | Ícono/texto sobre `heroBg` |
| `avatarFondos` | 12 tonos | Paleta del avatar — §8 |

---

## 5. Espaciado y tamaños táctiles

> **Las medidas vigentes son las de §0.4 (v2).** Lo de abajo es la v1 y se
> conserva solo para entender de dónde venían los números.


La web trabaja con controles de 42 px porque se usa con mouse. **En el
teléfono eso no alcanza:** el mínimo de un objetivo táctil es 48 dp, y en una
planta se toca con guantes, de pie y sin apoyar la mano.

| Token | Web | App | Por qué |
|---|---:|---:|---|
| Alto de control | 42 px | **52 dp** | guantes, movimiento |
| Separación entre acciones | 8 px | **12 dp** | evita el toque equivocado |
| Margen de pantalla | 16 px | **16 dp** | igual |
| Alto de fila de lista | ~40 px | **64 dp** | dos líneas: el dato y su contexto |
| Botón principal de formulario | — | **56 dp**, ancho completo, fijo abajo | el pulgar llega abajo, no arriba |

Los radios y los colores **no** cambian entre web y app: cambia lo que el dedo
necesita, no la identidad.

**El espaciado es múltiplo de 8** (padding estándar 16, separación 12).

---

## 6. Semántica del color

Qué significa cada color. Se respeta o el color deja de comunicar.

| Significado | Rol |
|---|---|
| Acción principal | `primary` (morado) |
| Acción secundaria / identidad | `secondary` (teal accesible) **con tinta navy** |
| Éxito, confirmación, "al día" | `SgColor.success` |
| Advertencia, "por vencer", stock bajo | `SgColor.warning` |
| Error, vencido, rechazado | `error` |
| Informativo | `SgColor.info` |
| **Sin conexión** | **neutro** (`onSurfaceVariant`), **nunca error** |
| Seleccionado / activo | `secondaryContainer` |
| Deshabilitado / no disponible | `Opacity(0.45)` sobre el widget completo |

> **Sin conexión no es un error.** La app es offline-first: trabajar sin señal
> es el caso normal en una planta, no una falla. Pintarlo de rojo entrena al
> técnico a ignorar el rojo, y el día que aparezca un rojo de verdad tampoco lo
> va a mirar.

### La severidad de una alerta

`Alerta.ale_severidad` usa el catálogo `Severidad`. **El SP guarda cuán grave
es; la pantalla decide de qué color se ve** — y la app puede pintarlo distinto
que la web sin que eso sea una inconsistencia.

| Severidad | Color | Dónde |
|---|---|---|
| CRÍTICA | `danger` | Franja izquierda de la tarjeta + ícono |
| ALTA | `danger` al 70% | Ídem |
| ADVERTENCIA | `warning` | Ídem |
| BAJA / NORMAL | `info` / `textoTenue` | Solo el ícono |

Lo que ordena la bandeja es **la severidad**, no el módulo.

---

## 7. Tipografía

**Sora**, variable 100–800. Está versionada en
`Web/Intranet/Css/LookAndFeel/Fonts/Sora/Sora-Variable.woff2`.

> **Flutter no lee `woff2`.** Hay que poner los `.ttf` de Sora en
> `assets/fonts/` —de Google Fonts, misma familia y mismos pesos— y declararlos
> en `pubspec.yaml`. Convertir el woff2 también sirve; lo que **no** sirve es
> apuntar al archivo de la web.

Se declaran como asset y **no** se usa `google_fonts` con descarga en runtime:
una app de terreno no puede depender de que haya red para tener tipografía.

| Estilo | Tamaño | Peso | Uso |
|---|---:|---:|---|
| `headlineMedium` | 30 | 600 | Título de pantalla |
| `headlineSmall` | 26 | 600 | Título de sección grande |
| `titleLarge` | 22 | 700 | Título de tarjeta |
| `titleMedium` | 17 | 600 | Encabezado de fila |
| `bodyLarge` | 16 | 500 | Texto principal — **el mínimo legible en planta** |
| `bodyMedium` | 15 | 500 | Texto secundario |
| `bodySmall` | 13 | 500 | Metadatos |
| `labelLarge` | 14 | 600 | Botones |
| `labelSmall` | 12 | 600 | Etiquetas en mayúscula, `letterSpacing: 1.2` |

El text theme se aplica con `.apply(bodyColor: cs.onSurface, displayColor:
cs.onSurface)`.

**Nada de datos por debajo de 13.** Un número de medidor a 11 px no se lee con
el teléfono a un brazo de distancia y con casco.

---

## 8. El avatar

Ya está resuelto en la web, en `SitioBase.Avatar`: **doce tonos, elegidos por
`id % 12`**.

La app usa **la misma paleta y el mismo criterio**. Si el color saliera de un
hash del nombre, la misma persona sería de un color en la web y de otro en el
teléfono, y el color dejaría de servir para reconocerla. (Además, con los siete
usuarios reales de Hamburgo el hash del nombre daba solo cuatro colores
distintos.)

---

## 9. Componentes: de la web a la app

| Web | App | Nota |
|---|---|---|
| `.sigma-accion.is-primaria` | `FilledButton` morado | mismo `purple` / `purpleHover` |
| `.sigma-accion` | `OutlinedButton` | borde `cardBorde` |
| `.grid-estado-chip` | `Chip` compacto, radio 8 | el color sale del **estado**, no de la marca |
| `.sg-avatar` | `CircleAvatar` | color por `id % 12` — §8 |
| `.sg-rep-thumb` | `ClipRRect` + `BoxFit.cover` | recortar, no deformar |
| Grilla Telerik | `ListView` de tarjetas | una tabla no cabe en 390 dp |
| `.sigma-modal` | `showModalBottomSheet(isScrollControlled: true)` | `DraggableScrollableSheet(initialChildSize: 0.9)`, asa 36×4 |
| Pestañas de categoría | `TabBar` desplazable | la vacía se apaga, no se esconde |
| Panel de notificaciones | Campana en la TopBar + `AlertasScreen` | badge = **no leídas**, no abiertas |
| Filtro `wucFiltro` | `SearchBarField` + hoja de filtros | |

Convenciones fijas de componente:

| Componente | Regla |
|---|---|
| Inputs | `OutlineInputBorder` radio 12, `filled`, alto 52 |
| Cards | Elevación 0, radio 16, borde `cardBorde`, color `cardBg` |
| AppBar | `TopBarApp` con blur σ6, `surface` al 80%, borde inferior al 30% |
| Progreso | `strokeCap: round`, grosor 3.5 |
| `NavigationBar` | `indicatorColor: secondaryContainer` |
| FAB | Siempre con `heroTag` único: varios tabs conviven en un `IndexedStack` |
| Diálogo de éxito | `mostrarDialogoExito`: ícono con `easeOutBack`, texto en cascada |
| Listas cargando | `skeletonizer` sobre los datos anteriores, **no** un spinner en pantalla vacía |

---

## 10. Reglas para pintar una pantalla nueva

1. Los colores salen **solo** de `Theme.of(context).colorScheme` y
   `context.appColors`. Un hex suelto en una pantalla es un defecto, no un
   atajo.
2. Nada de `Colors.orange / green / red` para semántica: se mapea a la tabla de
   §6.
3. Todo objetivo tocable mide al menos 48 dp; los de acción principal, 52.
4. Toda lista larga es virtual (`ListView.builder`), y toda lista vacía tiene
   estado vacío con ícono, frase y —si aplica— la acción que la llenaría.
5. Todo formulario confirma **con lo que ya está en disco**, no esperando la
   red. Ver `SIGMA_APP_ARQUITECTURA.md` §5.
6. Todo texto que la persona no puede resolver sola —un 403, un 402— dice
   **qué hacer**, no solo qué pasó. El 403 de la web dice «Tu perfil trabaja
   desde la aplicación móvil de SIGMA»; el caso espejo en la app tiene que
   decir lo suyo igual de claro.
7. Ante la duda, se copia el patrón equivalente de la web SIGMA y se traduce a
   estos tokens. Si la web no lo tiene, se copia de FacilityGes y se
   repintan los colores.

---

## 11. Accesibilidad, y por qué acá pesa más que en la web

Quien usa esta app está de pie, con casco, con guantes, con ruido, a veces con
contraluz y a veces con una linterna.

- Contraste mínimo **4.5:1** para texto; **3:1** para íconos y bordes. El teal
  sobre navy da 8.26:1; el teal con tinta blanca, 2.32:1 — por eso la regla 4.
- **Nunca solo color** para comunicar estado: siempre color **más** ícono o
  texto. Un 8% de los hombres no distingue rojo de verde, y en una planta eso
  no es un caso raro.
- Objetivos táctiles de 48 dp mínimo y separados 12 dp.
- Soporte de `textScaleFactor` hasta 1.3 sin que se corte texto: se prueba con
  la escala grande de Android antes de dar una pantalla por terminada.
- Nada de gestos finos como única vía: si algo se hace deslizando, también se
  puede hacer con un botón.

---

## 12. Bitácora

| Fecha | Qué |
|---|---|
| 04-09-2026 | Nace este documento. Tokens copiados de `sigma-brand.css`; medidas táctiles y semántica de color de `SIGMA_APP_FLUTTER.md` §5. Decisión propia y documentada: **se sobreescriben nueve roles** del `ColorScheme` para que las superficies oscuras coincidan con el sidebar de la web, apartándose del estándar de FacilityGes con el motivo escrito (§3) |
| 04-09-2026 | **Estándar v2, con los dos modos.** Importado `SIGMA App v2.dc.html` del proyecto de Claude Design con el MCP. Los tokens pasan a nombrarse por modo y **cada estado gana su color de texto propio** (§0.1): el relleno no cambia entre oscuro y claro, el texto sí, y eso es lo que hace legibles los dos con el mismo código. `AppTheme.claro()` y `AppTheme.oscuro()` se construyen con la misma función parametrizada por `AppColors`, y **ninguna pantalla pregunta por el brillo**. Nace `TemaService` con persistencia y el selector de tres opciones en Mi perfil. Cambios de forma: tarjeta a radio 18 y **sin la franja de color a la izquierda**, fila de 44 con la tensión de los 48 dp anotada (§0.4). Hallazgo: el kit usa **MDI**, la misma familia que `Menus.mnu_icon` — con eso el ícono del menú podría venir del servidor (§0.5) |
