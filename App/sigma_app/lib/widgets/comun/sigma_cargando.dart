import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'sigma_v3.dart';

/// La pantalla de carga de SIGMA: el isotipo, y debajo una figura que cambia.
///
/// ## Por qué una figura que muta y no una rueda
///
/// Una rueda de progreso dice «espera» y nada más; a los tres segundos deja de
/// significar algo y se lee como que la app se colgó. Una figura que cambia de
/// forma —triángulo, cuadrado, pentágono, círculo— **avanza**: se ve que algo
/// pasa aunque la red esté lenta, y eso es lo que distingue «está trabajando»
/// de «se quedó pegado».
///
/// ## Por qué se dibuja y no se anima con un GIF
///
/// Porque tiene que verse igual en claro y en oscuro y tomar el color de la
/// marca del tema. Un GIF trae su fondo pegado y en modo claro se ve un
/// recuadro negro alrededor.
///
/// ## Por qué el número de lados no se interpola de golpe
///
/// Se interpolan los VÉRTICES: los puntos de un triángulo se mueven hasta
/// quedar donde están los de un cuadrado, en vez de desaparecer y aparecer.
/// Cambiar de golpe parpadea, y un parpadeo en una pantalla de carga se lee
/// como un error.
class SgCargando extends StatefulWidget {
  const SgCargando({super.key, this.mensaje, this.lado = 76});

  /// Qué está haciendo. Nulo deja solo la figura: en un arranque corto, un
  /// texto que aparece y desaparece molesta más de lo que informa.
  final String? mensaje;

  final double lado;

  @override
  State<SgCargando> createState() => _SgCargandoState();
}

class _SgCargandoState extends State<SgCargando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// Los cuatro pasos del ciclo. Se vuelve al triángulo, así que el ciclo
  /// cierra y no da el salto feo de círculo a triángulo.
  static const _lados = [3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // 900 ms por figura: más rápido marea, más lento parece detenido.
      duration: Duration(milliseconds: 900 * _lados.length),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SgIsotipo(alto: widget.lado * 0.62),
        const SizedBox(height: 22),
        SizedBox(
          width: widget.lado,
          height: widget.lado,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _PintorFigura(
                avance: _c.value,
                lados: _lados,
                color: sg.acentoTexto,
                colorTenue: sg.tinte(sg.primario),
              ),
            ),
          ),
        ),
        if ((widget.mensaje ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            widget.mensaje!,
            textAlign: TextAlign.center,
            style: sora(13, 500, color: sg.tinta3, alto: 1.45),
          ),
        ],
      ],
    );
  }
}

class _PintorFigura extends CustomPainter {
  _PintorFigura({
    required this.avance,
    required this.lados,
    required this.color,
    required this.colorTenue,
  });

  /// 0 → 1 sobre el ciclo completo.
  final double avance;
  final List<int> lados;
  final Color color;
  final Color colorTenue;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2 - 6;

    final tramo = 1 / lados.length;
    final i = (avance / tramo).floor().clamp(0, lados.length - 1);
    final t = (avance - i * tramo) / tramo;

    final desde = lados[i];
    final hasta = lados[(i + 1) % lados.length];

    /* La curva suaviza los extremos: la figura se queda un instante formada
       antes de empezar a mutar, que es lo que la hace legible. Sin esto muta
       todo el rato y no se reconoce ninguna forma. */
    final s = Curves.easeInOutCubic.transform(t);

    // Gira despacio mientras muta: dos movimientos a la vez se leen como una
    // sola cosa viva, y uno solo se lee como un bucle.
    final giro = avance * 2 * math.pi;

    final ruta = _figura(centro, radio, desde, hasta, s, giro);

    // La sombra tenue detrás da profundidad sin pedir atención.
    canvas.drawPath(
      ruta,
      Paint()
        ..color = colorTenue
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      ruta,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Interpola vértice a vértice entre dos polígonos.
  ///
  /// Los dos se muestrean con el MISMO número de puntos —el mínimo común que
  /// los describe a los dos: `desde * hasta`— así que cada punto tiene su
  /// pareja y el paso es continuo. Muestrear con distinto número obligaría a
  /// crear y destruir puntos, que es exactamente el parpadeo que se evita.
  Path _figura(
    Offset c,
    double r,
    int desde,
    int hasta,
    double t,
    double giro,
  ) {
    final puntos = desde * hasta;
    final ruta = Path();

    for (var k = 0; k < puntos; k++) {
      final u = k / puntos;

      final a = _radioDe(desde, u) * r;
      final b = _radioDe(hasta, u) * r;
      final radio = a + (b - a) * t;

      final ang = u * 2 * math.pi - math.pi / 2 + giro;
      final p = Offset(
        c.dx + radio * math.cos(ang),
        c.dy + radio * math.sin(ang),
      );

      if (k == 0) {
        ruta.moveTo(p.dx, p.dy);
      } else {
        ruta.lineTo(p.dx, p.dy);
      }
    }

    ruta.close();
    return ruta;
  }

  /// El radio de un polígono regular de `n` lados en el ángulo `u` (0→1),
  /// tomando 1 como el radio de sus vértices.
  ///
  /// Entre dos vértices el borde es recto, así que el radio baja hacia el
  /// centro del lado: eso es lo que hace que un triángulo se vea triángulo y
  /// no una circunferencia.
  double _radioDe(int n, double u) {
    final sector = 2 * math.pi / n;
    final ang = u * 2 * math.pi;
    final dentro = ang % sector;
    // Distancia angular al vértice más cercano.
    final d = math.min(dentro, sector - dentro);
    // cos(sector/2) es la apotema; dividir por cos(d) la proyecta al borde.
    return math.cos(sector / 2) / math.cos(d);
  }

  @override
  bool shouldRepaint(_PintorFigura otro) =>
      otro.avance != avance || otro.color != color;
}
