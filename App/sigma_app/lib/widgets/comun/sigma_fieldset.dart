import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// Un grupo con su título montado sobre el canto, como un `fieldset`.
///
/// ## Por qué un fieldset y no un rótulo suelto
///
/// Un rótulo encima de una lista dice dónde EMPIEZA el grupo pero no dónde
/// termina: al bajar tres tarjetas ya no se sabe si siguen siendo de ese grupo
/// o del siguiente. El fieldset cierra: lo de dentro es del grupo y lo de
/// fuera no, sin tener que recordar nada.
///
/// En una bandeja partida por tiempo —«últimas 24 horas», «antes»— esa
/// diferencia importa: es lo que evita leer una entrada de anteayer creyendo
/// que es de esta mañana.
///
/// ## Qué lo hace moderno y no un formulario de 2005
///
/// El `fieldset` del navegador es un marco de un píxel con el texto encajado.
/// Acá el marco es **una superficie tenue**, no una línea: el v3 construye la
/// jerarquía con superficies y no con bordes, y esta pieza respeta esa regla.
/// El título va en versalitas pequeñas sobre el canto superior, con el fondo
/// de la pantalla detrás para que parezca que interrumpe el borde.
///
/// El contador a la derecha responde «cuántas» sin abrir: en una bandeja eso
/// es la mitad de la información.
class SgFieldset extends StatelessWidget {
  const SgFieldset({
    super.key,
    required this.titulo,
    required this.children,
    this.cuantas,
    this.color,
    this.detalle,
  });

  final String titulo;
  final List<Widget> children;

  /// Cuántos elementos hay dentro. Nulo lo esconde.
  final int? cuantas;

  /// El acento del grupo. Nulo usa el neutro: **el color se reserva para lo
  /// que lo necesita** —lo vencido, lo crítico— y usarlo en todos los grupos
  /// lo gastaría.
  final Color? color;

  /// Una línea que explica el criterio del grupo, si no es evidente.
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final acento = color ?? sg.tinta3;

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // El marco: superficie tenue, sin línea.
          Container(
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.fromLTRB(11, 20, 11, 12),
            decoration: BoxDecoration(
              color: sg.up,
              borderRadius: BorderRadius.circular(SgRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((detalle ?? '').isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      detalle!,
                      style: sora(12, 500, color: sg.tinta3, alto: 1.4),
                    ),
                  ),
                ],
                ...children,
              ],
            ),
          ),

          // El título, montado sobre el canto y con el fondo detrás para que
          // se lea como si interrumpiera el marco.
          Positioned(
            left: 14,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: sg.fondo,
                borderRadius: BorderRadius.circular(SgRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo.toUpperCase(),
                    style: sora(10, 700, color: acento, espaciado: 0.8),
                  ),
                  if (cuantas != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: sg.up,
                        borderRadius: BorderRadius.circular(SgRadius.pill),
                      ),
                      child: Text(
                        '$cuantas',
                        style: sora(10, 700, color: sg.tinta2, tabular: true),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El tramo de tiempo al que pertenece un registro, con la ventana **móvil**
/// que pidió Bryan: no «desde medianoche», sino las últimas 24 horas.
///
/// ## Por qué móvil y no el día del calendario
///
/// Un turno de noche empieza a las 22:00 y termina a las 06:00. Con el día del
/// calendario, a las 00:01 lo trabajado hace veinte minutos pasa a «ayer» y
/// desaparece de la vista de quien lo está haciendo. La ventana móvil sigue a
/// la persona: a las 21:50 «hoy» es desde las 21:50 de ayer.
enum TramoTiempo {
  ultimas24,
  anteriores;

  static TramoTiempo de(DateTime cuando, {DateTime? ahora}) {
    final n = ahora ?? DateTime.now();
    return n.difference(cuando) < const Duration(hours: 24)
        ? TramoTiempo.ultimas24
        : TramoTiempo.anteriores;
  }

  String get titulo => switch (this) {
    TramoTiempo.ultimas24 => 'Últimas 24 horas',
    TramoTiempo.anteriores => 'Antes',
  };
}
