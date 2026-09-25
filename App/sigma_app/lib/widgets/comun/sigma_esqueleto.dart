import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// El esqueleto de carga: la forma de lo que viene, con un brillo que barre.
///
/// ## Por qué una silueta y no un bloque gris
///
/// Tres rectángulos iguales dicen «espera» y nada más. Una silueta con la
/// forma real —el cuadro del icono, el título largo, el subtítulo corto, la
/// cifra a la derecha— dice **qué va a aparecer y dónde**, así que cuando
/// llegan los datos la vista no salta: lo que había ya ocupaba ese sitio.
///
/// Eso es lo que hace que una carga se sienta rápida aunque tarde lo mismo.
///
/// ## Por qué el brillo barre y no parpadea
///
/// Un parpadeo se confunde con un error de pintado. Un barrido tiene
/// dirección: se lee como «esto está en camino». Va lento —1400 ms— y con muy
/// poco contraste: un esqueleto que llama la atención compite con el contenido
/// que está a punto de sustituirlo.
///
/// ## Por qué no se usa un paquete
///
/// `shimmer` y `skeletonizer` traen su propio sistema de temas, y acá los
/// colores tienen que salir de los tokens del v3 para verse igual en claro y
/// en oscuro. Son treinta líneas: el paquete costaría más de integrar que de
/// escribir.
class SgEsqueleto extends StatefulWidget {
  const SgEsqueleto({
    super.key,
    this.filas = 3,
    this.alto = 78,
    this.conIcono = true,
    this.conCifra = false,
  });

  /// Cuántas siluetas. Tres llenan la parte visible de casi cualquier lista
  /// sin dar la sensación de una lista larga que después resulta ser corta.
  final int filas;

  final double alto;

  /// El cuadro del icono a la izquierda, como las tarjetas de verdad.
  final bool conIcono;

  /// El bloque de la cifra a la derecha: existencias, contadores.
  final bool conCifra;

  @override
  State<SgEsqueleto> createState() => _SgEsqueletoState();
}

class _SgEsqueletoState extends State<SgEsqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    /* CON MOVIMIENTO REDUCIDO, EL ESQUELETO NO BARRE

       Y sigue sirviendo: lo que dice «esto todavía no llegó» es la silueta
       —la forma de la fila sin contenido—, no el brillo que la cruza. El
       barrido solo agrega vida, y para quien tiene trastorno vestibular una
       banda que cruza la pantalla cada 1,4 s no es vida, es mareo. */
    final quieto = MediaQuery.disableAnimationsOf(context);
    if (quieto && _c.isAnimating) _c.stop();
    if (!quieto && !_c.isAnimating) _c.repeat();

    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.filas; i++) ...[
            _Silueta(
              alto: widget.alto,
              avance: _c.value,
              // Cada fila entra desfasada: un barrido simultáneo en las tres
              // se lee como un flash de pantalla, no como un movimiento.
              desfase: i * 0.12,
              conIcono: widget.conIcono,
              conCifra: widget.conCifra,
              fondo: sg.card,
              brillo: sg.up,
              hueso: sg.up,
              conBarrido: !quieto,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Silueta extends StatelessWidget {
  const _Silueta({
    required this.alto,
    required this.avance,
    required this.desfase,
    required this.conIcono,
    required this.conCifra,
    required this.fondo,
    required this.brillo,
    required this.hueso,
    this.conBarrido = true,
  });

  final double alto;
  final double avance;
  final double desfase;
  final bool conIcono;
  final bool conCifra;
  final Color fondo;
  final Color brillo;
  final Color hueso;

  /// Falso con movimiento reducido: quedan las siluetas quietas.
  final bool conBarrido;

  @override
  Widget build(BuildContext context) {
    final t = (avance + desfase) % 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(SgRadius.card),
      child: Stack(
        children: [
          Container(
            height: alto,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(SgRadius.card),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (conIcono) ...[
                  _Hueso(ancho: 44, alto: 44, radio: 13, color: hueso),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Anchos distintos: dos líneas iguales se leen como una
                      // tabla, no como un título y su detalle.
                      _Hueso(ancho: 168, alto: 12, radio: 6, color: hueso),
                      const SizedBox(height: 9),
                      _Hueso(ancho: 104, alto: 10, radio: 5, color: hueso),
                    ],
                  ),
                ),
                if (conCifra) ...[
                  const SizedBox(width: 10),
                  _Hueso(ancho: 42, alto: 20, radio: 7, color: hueso),
                ],
              ],
            ),
          ),

          /* EL BARRIDO

             Una banda diagonal que cruza de izquierda a derecha. Se pinta
             ENCIMA con IgnorePointer para que no coma toques —el esqueleto no
             es interactivo, pero la fila que lo sustituye sí, y dejar un
             widget capturando gestos ahí sería un toque perdido justo cuando
             llegan los datos—. */
          if (conBarrido)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + t * 3, -0.4),
                      end: Alignment(-0.4 + t * 3, 0.4),
                      colors: [
                        brillo.withValues(alpha: 0),
                        brillo.withValues(alpha: 0.55),
                        brillo.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hueso extends StatelessWidget {
  const _Hueso({
    required this.ancho,
    required this.alto,
    required this.radio,
    required this.color,
  });

  final double ancho;
  final double alto;
  final double radio;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radio),
    ),
  );
}
