import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'sigma_v3.dart';

/// El radar de SIGMA AI: el símbolo con un barrido que no para.
///
/// ## Qué comunica, y por qué se mueve
///
/// SIGMA AI no es una pantalla que se consulta: es algo que **está mirando
/// todo el rato** —las lecturas que entran, las tendencias que se cruzan— y
/// avisa cuando encuentra algo. Un logotipo quieto dice «acá hay una función»;
/// un barrido dice «esto está trabajando ahora», que es exactamente lo que
/// hace y lo que justifica que la tarjeta ocupe el sitio que ocupa en el
/// Inicio.
///
/// ## Por qué un barrido y no un destello
///
/// Un destello pide atención y se acabó; un barrido **describe un proceso**.
/// Es la misma razón por la que un radar de verdad gira: lo que se ve no es
/// adorno, es la forma que tiene la búsqueda.
///
/// ## Lo que deliberadamente NO hace
///
/// No parpadea, no cambia de color y no acelera cuando hay algo crítico. La
/// severidad la dice el distintivo con palabras —«Crítica»—, y que además se
/// moviera distinto obligaría a aprender un segundo idioma para leer lo mismo.
/// Un movimiento que grita compite con el dato.
///
/// El barrido tarda 3,2 s y va a opacidad baja: en una pantalla que se mira
/// treinta veces al día, una animación rápida cansa antes del mediodía.
class SgRadarIa extends StatefulWidget {
  const SgRadarIa({
    super.key,
    this.simbolo = SgIconoIa.prediccion,
    this.lado = 46,
    this.activo = true,
  });

  /// Cuál de los cuatro símbolos de estado va en el centro. El barrido es el
  /// mismo; lo que cambia es qué está haciendo.
  final SgIconoIa simbolo;

  final double lado;

  /// Con `false` queda quieto. Lo usa la tarjeta cuando no hay nada que
  /// analizar: un radar barriendo sobre «nada que anunciar» promete una
  /// actividad que no está ocurriendo.
  final bool activo;

  @override
  State<SgRadarIa> createState() => _SgRadarIaState();
}

class _SgRadarIaState extends State<SgRadarIa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _c.repeat();
  }

  @override
  void didUpdateWidget(SgRadarIa anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activo == anterior.activo) return;
    // Detenerlo no es un detalle: una animación en bucle impide que Flutter
    // deje la pantalla quieta, y el Inicio se mira muchas veces en un turno de
    // ocho horas.
    widget.activo ? _c.repeat() : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: widget.lado,
      height: widget.lado,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // El barrido va DEBAJO del símbolo: la marca no se toca, se la
          // rodea. Encima, el degradado la ensuciaría.
          if (widget.activo)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => CustomPaint(
                    painter: _PintorRadar(
                      avance: _c.value,
                      color: sg.acentoTexto,
                    ),
                  ),
                ),
              ),
            ),
          SgSimboloIa(widget.simbolo, lado: widget.lado * 0.62),
        ],
      ),
    );
  }
}

/// Dibuja los anillos y el sector que barre.
class _PintorRadar extends CustomPainter {
  const _PintorRadar({required this.avance, required this.color});

  /// 0 a 1, una vuelta completa.
  final double avance;
  final Color color;

  @override
  void paint(Canvas lienzo, Size medida) {
    final centro = Offset(medida.width / 2, medida.height / 2);
    final radio = medida.shortestSide / 2;

    // Dos anillos finos: dan la referencia de que hay un espacio que se está
    // recorriendo. Sin ellos el sector parece un reflejo.
    final anillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.16);

    lienzo.drawCircle(centro, radio - 0.5, anillo);
    lienzo.drawCircle(centro, radio * 0.62, anillo);

    // El sector que barre: un degradado que se apaga hacia atrás, para que se
    // lea de dónde viene y hacia dónde va. Un sector de color plano giraría
    // sin dirección.
    final angulo = avance * 2 * math.pi;
    const arco = math.pi / 3;

    final barrido = Paint()
      ..shader = SweepGradient(
        startAngle: angulo - arco,
        endAngle: angulo,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.30),
        ],
        transform: GradientRotation(angulo - arco),
      ).createShader(Rect.fromCircle(center: centro, radius: radio));

    lienzo.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      angulo - arco,
      arco,
      true,
      barrido,
    );

    // El filo delantero, marcado: es lo que hace que el ojo siga el giro.
    final filo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);

    lienzo.drawLine(
      centro,
      centro + Offset(math.cos(angulo), math.sin(angulo)) * radio,
      filo,
    );
  }

  @override
  bool shouldRepaint(_PintorRadar anterior) =>
      anterior.avance != avance || anterior.color != color;
}
