import 'package:flutter/material.dart';

import 'sigma_tokens.dart';

/// El juego de colores del modo activo.
///
/// **Las pantallas leen de acá, nunca de `SgColor` directo.** Un widget que
/// use `SgColor.oscuroCard` se ve bien en oscuro y roto en claro, y es
/// exactamente lo que esta capa existe para impedir: los dos modos comparten
/// el mismo código de pantalla porque el color siempre sale de `context.sg`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.esOscuro,
    required this.fondo,
    required this.card,
    required this.up,
    required this.up2,
    required this.campo,
    required this.div,
    required this.linea,
    required this.tinta,
    required this.tinta2,
    required this.tinta3,
    required this.primario,
    required this.primarioTexto,
    required this.acentoTexto,
    required this.rojoTexto,
    required this.ambarTexto,
    required this.verdeTexto,
    required this.azulTexto,
    required this.indicador,
    required this.esqueleto,
    required this.esqueleto2,
    required this.foto,
    required this.scrim,
  });

  final bool esOscuro;

  /// El lienzo de la pantalla.
  final Color fondo;

  /// La tarjeta. **Sin borde**: se separa del fondo por color y sombra.
  final Color card;

  /// Un nivel sobre la tarjeta: chip en reposo, botón secundario, riel de una
  /// barra de progreso.
  final Color up;

  /// Dos niveles: la píldora de unidad, el cuadro de ícono neutro.
  final Color up2;

  final Color campo;

  /// El divisor entre filas de una misma tarjeta. **No es un borde**: es una
  /// raya tenue que solo aparece entre hermanos.
  final Color div;

  /// La única línea con contorno, para lo que de verdad la necesita.
  final Color linea;

  /// Texto principal.
  final Color tinta;

  /// Subtítulos y ayuda.
  final Color tinta2;

  /// Metadatos y rótulos.
  final Color tinta3;

  /// El relleno del primario —botón, anillo de foco, punto de no leída—.
  final Color primario;

  /// Y el primario **como texto**, que en oscuro se aclara para leerse sobre
  /// la tarjeta y en claro se oscurece para leerse sobre blanco.
  final Color primarioTexto;

  /// El **texto** de cada estado. El relleno vive en `SgColor` y no cambia
  /// entre modos; lo que cambia es el color con que se escribe encima.
  final Color acentoTexto;
  final Color rojoTexto;
  final Color ambarTexto;
  final Color verdeTexto;
  final Color azulTexto;

  final Color indicador;
  final Color esqueleto;
  final Color esqueleto2;

  /// El fondo de una foto que todavía no bajó del Blob Storage.
  final Color foto;

  /// El velo detrás de una hoja inferior.
  final Color scrim;

  /// El tinte de fondo de un estado: el mismo color al 18 % en oscuro y al
  /// 11 % en claro. Sobre blanco, un 18 % ya se ve sucio.
  Color tinte(Color relleno) =>
      relleno.withValues(alpha: esOscuro ? 0.18 : 0.11);

  /// La sombra de nivel 1: la tarjeta corriente.
  ///
  /// Sin bordes, **la sombra es lo único que apoya la tarjeta sobre el
  /// lienzo**. En oscuro casi no se ve —ahí separa el color— y en claro hace
  /// todo el trabajo.
  List<BoxShadow> get e1 => esOscuro
      ? const [
          BoxShadow(
              color: Color(0xB3000000), blurRadius: 10, offset: Offset(0, 2)),
        ]
      : const [
          BoxShadow(
              color: Color(0x120B0F1A), blurRadius: 3, offset: Offset(0, 1)),
        ];

  /// La sombra de nivel 2: lo que tiene que despegarse —el hero, la tarjeta
  /// elegida, la que pide una decisión—.
  List<BoxShadow> get e2 => esOscuro
      ? const [
          BoxShadow(
              color: Color(0xBF000000), blurRadius: 30, offset: Offset(0, 12)),
        ]
      : const [
          BoxShadow(
              color: Color(0x380B0F1A), blurRadius: 26, offset: Offset(0, 12)),
        ];

  static const oscuro = AppColors(
    esOscuro: true,
    fondo: SgColor.oscuroFondo,
    card: SgColor.oscuroCard,
    up: SgColor.oscuroUp,
    up2: SgColor.oscuroUp2,
    campo: SgColor.oscuroCampo,
    div: SgColor.oscuroDiv,
    linea: SgColor.oscuroLinea,
    tinta: SgColor.oscuroTinta,
    tinta2: SgColor.oscuroTinta2,
    tinta3: SgColor.oscuroTinta3,
    primario: SgColor.oscuroPrimario,
    primarioTexto: SgColor.oscuroPrimarioTexto,
    acentoTexto: SgColor.oscuroAcentoTexto,
    rojoTexto: SgColor.oscuroRojoTexto,
    ambarTexto: SgColor.oscuroAmbarTexto,
    verdeTexto: SgColor.oscuroVerdeTexto,
    azulTexto: SgColor.oscuroAzulTexto,
    indicador: SgColor.oscuroIndicador,
    esqueleto: SgColor.oscuroEsqueleto,
    esqueleto2: SgColor.oscuroEsqueleto2,
    foto: SgColor.oscuroFoto,
    scrim: SgColor.oscuroScrim,
  );

  static const claro = AppColors(
    esOscuro: false,
    fondo: SgColor.claroFondo,
    card: SgColor.claroCard,
    up: SgColor.claroUp,
    up2: SgColor.claroUp2,
    campo: SgColor.claroCampo,
    div: SgColor.claroDiv,
    linea: SgColor.claroLinea,
    tinta: SgColor.claroTinta,
    tinta2: SgColor.claroTinta2,
    tinta3: SgColor.claroTinta3,
    primario: SgColor.claroPrimario,
    primarioTexto: SgColor.claroPrimarioTexto,
    acentoTexto: SgColor.claroAcentoTexto,
    rojoTexto: SgColor.claroRojoTexto,
    ambarTexto: SgColor.claroAmbarTexto,
    verdeTexto: SgColor.claroVerdeTexto,
    azulTexto: SgColor.claroAzulTexto,
    indicador: SgColor.claroIndicador,
    esqueleto: SgColor.claroEsqueleto,
    esqueleto2: SgColor.claroEsqueleto2,
    foto: SgColor.claroFoto,
    scrim: SgColor.claroScrim,
  );

  /// Doce tonos para el avatar, elegidos por `id % 12`.
  ///
  /// La misma paleta y el mismo criterio que `SitioBase.Avatar` en la web: si
  /// el color saliera de un hash del nombre, la misma persona sería de un
  /// color en la web y de otro en el teléfono, y el color dejaría de servir
  /// para reconocerla de un vistazo.
  static const avatarFondos = <Color>[
    Color(0xFF4A3AAF),
    Color(0xFF0F766E),
    Color(0xFF9D174D),
    Color(0xFF1D4ED8),
    Color(0xFF7C2D12),
    Color(0xFF166534),
    Color(0xFF6B21A8),
    Color(0xFF9A3412),
    Color(0xFF115E59),
    Color(0xFF1E40AF),
    Color(0xFF831843),
    Color(0xFF3F3F46),
  ];

  static Color avatarDe(int id) => avatarFondos[id.abs() % avatarFondos.length];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? otro, double t) {
    // Los dos modos no se interpolan: el cambio de tema es un corte, no una
    // transición. Interpolarlos daría un fotograma con tarjetas grises sobre
    // fondo gris donde no se lee nada.
    if (otro is! AppColors) return this;
    return t < 0.5 ? this : otro;
  }
}

/// El atajo de toda pantalla: `context.sg`.
extension SgContexto on BuildContext {
  AppColors get sg =>
      Theme.of(this).extension<AppColors>() ?? AppColors.oscuro;
}

/// Un estilo de Sora.
///
/// **`fontVariations` y no solo `fontWeight`.** Sora entra como fuente
/// variable —un archivo con el eje `wght`—, y sin declarar la variación
/// Flutter dibuja el peso base y sintetiza el resto: el 600 del kit termina
/// idéntico al 500 y la jerarquía de la pantalla desaparece.
TextStyle sora(
  double tamano,
  int peso, {
  Color? color,
  double? alto,
  double? espaciado,
  bool tabular = false,
  TextDecoration? decoracion,
}) =>
    TextStyle(
      fontFamily: 'Sora',
      fontSize: tamano,
      fontWeight: FontWeight.values[(peso ~/ 100) - 1],
      fontVariations: [FontVariation('wght', peso.toDouble())],
      color: color,
      height: alto,
      letterSpacing: espaciado,
      decoration: decoracion,
      // Cifras de ancho fijo. Sin esto, un contador que sube de 46 a 47 mueve
      // todo lo que tiene al lado cada vez que cambia.
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );

/// El tema de SIGMA, en sus dos modos.
///
/// **El oscuro es el de fábrica**, y no es capricho: es la superficie que se
/// mira en una planta, con contraluz y a veces detrás de una funda.
///
/// **El claro existe porque la misma app se usa en la oficina.** El
/// planificador y el jefe la abren sentados, con luz de ventana, y ahí el
/// oscuro cansa. No es el oscuro invertido: son los tokens claros del kit,
/// donde el fondo es un gris azulado —no blanco— para que las tarjetas
/// blancas se separen **sin borde**, que es la regla del v3.
abstract final class AppTheme {
  static ThemeData oscuro() => _construir(AppColors.oscuro);
  static ThemeData claro() => _construir(AppColors.claro);

  static ThemeData _construir(AppColors sg) {
    final base = sg.esOscuro ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: sg.fondo,
      canvasColor: sg.fondo,
      extensions: [sg],
      colorScheme: base.colorScheme.copyWith(
        primary: sg.primario,
        secondary: SgColor.tealSolido,
        surface: sg.card,
        error: SgColor.rojo,
        onPrimary: Colors.white,
        // Sobre el teal va tinta navy, no blanca: blanco sobre #00BFAE da
        // 2,32:1 y no se lee. Es el mismo criterio del badge solido.
        onSecondary: SgColor.navy,
        onSurface: sg.tinta,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Sora',
        bodyColor: sg.tinta,
        displayColor: sg.tinta,
      ),
      dividerTheme: DividerThemeData(color: sg.div, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: sg.primario,
        linearTrackColor: sg.up,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: sg.up2,
        contentTextStyle: sora(14, 500, color: sg.tinta),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SgRadius.bloque),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sg.card,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: sg.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sg.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SgRadius.hoja),
        ),
      ),
    );
  }
}
