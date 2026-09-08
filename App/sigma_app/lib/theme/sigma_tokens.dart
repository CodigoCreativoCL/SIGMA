import 'package:flutter/material.dart';

/// Los tokens del kit **v3**.
///
/// ## Qué cambió respecto del v2, y por qué importa
///
/// El v3 es Material Design 3 sobre Sora, y su decisión de fondo es una sola:
/// **la jerarquía se construye con superficie, espacio y divisores puntuales,
/// no con bordes**. En el v2 cada tarjeta llevaba un borde de 1 px; con doce
/// tarjetas en pantalla eso son doce líneas compitiendo con el contenido. El
/// v3 las quita y las reemplaza por tres niveles de superficie —`card`, `up`,
/// `up2`— más dos sombras de elevación.
///
/// De ahí salen los otros cambios:
///
///   * la tarjeta pasa de radio 18 a **22**, y el campo de 52/14 a **56/18**;
///   * **el foco y la selección son un anillo**, no un borde: `0 0 0 2px` por
///     fuera, que no mueve el contenido de sitio al aparecer;
///   * el secundario deja de ser contorno y pasa a **relleno `up`**;
///   * `ink3` sube de `#64748B` a `#7A879E` — sin bordes, el texto terciario
///     tenía que ganar contraste para seguir separando bloques.
///
/// ## La regla que no cambió
///
/// **Los tokens no se usan sueltos desde las pantallas.** Se usan a través de
/// `context.sg`, que entrega el juego del modo activo. Una pantalla que lea
/// `SgColor.oscuroFondo` directo se rompe en claro, y es exactamente lo que el
/// tema está montado para impedir.
///
/// El relleno de cada estado —rojo, ámbar, verde, azul— **es el mismo en los
/// dos modos**; lo que cambia es el texto con que se escribe encima y el
/// tinte de fondo. Esa separación es la que hace que un badge sea legible en
/// oscuro y en claro con el mismo código de pantalla.
abstract final class SgColor {
  // ─────────────────────────────────────────────────────────── MARCA ──
  // No cambian entre modos: son identidad.

  static const navy = Color(0xFF0B0F1A);
  static const teal = Color(0xFF00E0C2);
  static const tealSolido = Color(0xFF00BFAE);
  static const pink = Color(0xFFFF4D9D);

  // ──────────────────────────────────────────────────── MODO OSCURO ──
  static const oscuroFondo = Color(0xFF080C17);
  static const oscuroCard = Color(0xFF111827);

  /// La superficie que sube un nivel sobre la tarjeta: chips en reposo,
  /// botones secundarios, barras de progreso.
  static const oscuroUp = Color(0xFF182235);

  /// Y la que sube dos: la píldora de unidad, los cuadros neutros.
  static const oscuroUp2 = Color(0xFF1E2A40);

  static const oscuroCampo = Color(0xFF0F1524);

  /// El divisor del v3: **no es una línea de borde**, es una raya tenue entre
  /// filas de una misma tarjeta.
  static const oscuroDiv = Color(0x1FA8B2C3);

  /// La única línea que queda, para lo que de verdad necesita contorno.
  static const oscuroLinea = Color(0xFF2A3548);

  static const oscuroTinta = Color(0xFFF8FAFC);
  static const oscuroTinta2 = Color(0xFFA8B2C3);
  static const oscuroTinta3 = Color(0xFF7A879E);

  static const oscuroPrimario = Color(0xFF6C5CFF);
  static const oscuroPrimarioTexto = Color(0xFFA99DFF);

  static const oscuroAcentoTexto = Color(0xFF00E0C2);
  static const oscuroRojoTexto = Color(0xFFFB7185);
  static const oscuroAmbarTexto = Color(0xFFFBBF24);
  static const oscuroVerdeTexto = Color(0xFF4ADE80);
  static const oscuroAzulTexto = Color(0xFF7CA6FF);

  static const oscuroIndicador = Color(0xFF2A3548);
  static const oscuroEsqueleto = Color(0xFF1B2740);
  static const oscuroEsqueleto2 = Color(0xFF141E2F);

  /// El fondo de una foto que todavía no bajó.
  static const oscuroFoto = Color(0xFF141E2F);

  static const oscuroScrim = Color(0xBD05070E);

  // ───────────────────────────────────────────────────── MODO CLARO ──
  //
  // No es el oscuro invertido a ojo: el fondo es un gris azulado (#EFF3F9),
  // no blanco, para que las tarjetas blancas se separen sin necesitar borde.
  // Sin bordes eso deja de ser una preferencia y pasa a ser la condición para
  // que el modo claro funcione.
  static const claroFondo = Color(0xFFEFF3F9);
  static const claroCard = Color(0xFFFFFFFF);
  static const claroUp = Color(0xFFF5F7FB);
  static const claroUp2 = Color(0xFFEAEFF7);
  static const claroCampo = Color(0xFFFFFFFF);
  static const claroDiv = Color(0x170B0F1A);
  static const claroLinea = Color(0xFFDCE3EF);

  static const claroTinta = Color(0xFF0B0F1A);
  static const claroTinta2 = Color(0xFF4C5A72);
  static const claroTinta3 = Color(0xFF7A879E);

  /// El morado baja de luminosidad en claro: el `#6C5CFF` del oscuro sobre
  /// blanco pierde contraste en el texto de los botones.
  static const claroPrimario = Color(0xFF5847E8);
  static const claroPrimarioTexto = Color(0xFF4536CE);

  static const claroAcentoTexto = Color(0xFF00736A);
  static const claroRojoTexto = Color(0xFFB91C1C);
  static const claroAmbarTexto = Color(0xFF96450B);
  static const claroVerdeTexto = Color(0xFF15803D);
  static const claroAzulTexto = Color(0xFF1D4ED8);

  static const claroIndicador = Color(0xFFC6CFDE);
  static const claroEsqueleto = Color(0xFFE6EBF3);
  static const claroEsqueleto2 = Color(0xFFEFF3F9);
  static const claroFoto = Color(0xFFE6EBF3);

  static const claroScrim = Color(0x700B0F1A);

  // ──────────────────────────── ESTADOS: el relleno, igual en los dos ──
  static const rojo = Color(0xFFDC2626);
  static const ambar = Color(0xFFF59E0B);
  static const verde = Color(0xFF16A34A);
  static const azul = Color(0xFF2563EB);

  // ────────────────────────────────────────── EL LIENZO DEL CATÁLOGO ──
  // Solo para la lámina de artboards; ninguna pantalla de la app los usa.
  static const lienzo = Color(0xFF05070E);

  /// El degradado de marca. **Solo como acento**: una franja, un halo, la
  /// barra de progreso, el velo de una tarjeta de IA. Nunca de fondo de una
  /// superficie donde haya que leer o trabajar.
  static const gradiente = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [teal, oscuroPrimario],
  );

  /// El velo de la tarjeta de SIGMA AI: 120°, morado → azul → rosa.
  static const veloIa = LinearGradient(
    begin: Alignment(-1, -0.5),
    end: Alignment(1, 0.5),
    colors: [Color(0x336C5CFF), Color(0x1F2563EB), Color(0x1AFF4D9D)],
    stops: [0.0, 0.48, 1.0],
  );
}

/// Los radios del v3.
///
/// El salto respecto del v2: **la tarjeta pasó de 18 a 22 y perdió el borde**.
/// Un radio mayor sin contorno lee como una superficie apoyada; con contorno
/// habría leído como una caja dibujada.
abstract final class SgRadius {
  /// La píldora de unidad y los chips diminutos.
  static const unidad = 7.0;

  static const chip = 12.0;

  /// El bloque interno de una tarjeta: la caja de un dato, un aviso.
  static const bloque = 14.0;

  /// El cuadro de ícono, en sus tres tamaños del kit.
  static const icono42 = 14.0;
  static const icono44 = 15.0;
  static const icono48 = 16.0;

  /// El campo de texto.
  static const campo = 18.0;

  /// La tarjeta. **El radio del v3.**
  static const card = 22.0;

  /// La hoja inferior.
  static const hoja = 28.0;

  /// El marco del teléfono en el catálogo.
  static const marco = 36.0;

  static const pill = 999.0;
}

/// Las medidas del v3.
///
/// Retícula de 4 dp con ritmo 8, margen 16, controles 52 y objetivo tocable
/// 48. Las que están acá son las que se repiten; una medida que aparece una
/// sola vez se escribe en su pantalla.
abstract final class SgMedida {
  static const margen = 16.0;
  static const separacion = 12.0;

  /// El objetivo tocable mínimo. Con guantes, menos que esto no se acierta.
  static const tocable = 48.0;

  /// La fila de una lista dentro de una tarjeta.
  static const fila = 54.0;

  /// La fila alta: la que lleva dos líneas de texto.
  static const filaAlta = 60.0;

  /// El botón y el campo. **56 el campo, 52 el botón**: el campo es más alto
  /// porque tiene que caber un ícono, el texto y el micrófono.
  static const boton = 52.0;
  static const campo = 56.0;

  static const chip = 28.0;
  static const badge = 26.0;
  static const badgeChico = 24.0;

  static const barraSuperior = 64.0;
  static const barraInferior = 76.0;

  /// La barra de gestos de Android que el kit dibuja al pie.
  static const barraGestos = 34.0;
}
