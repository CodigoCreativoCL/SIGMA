import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// El recuadro donde se firma con el dedo — vista 6.7 (HU-118).
///
/// ## Por qué se dibuja y no se usa un paquete
///
/// Una firma son trazos: puntos que se unen mientras el dedo se mueve, y una
/// imagen al final. `CustomPainter` y `PictureRecorder` ya traen las dos cosas.
/// Un paquete de firma agregaría una dependencia, su tema propio y sus colores
/// fijos a una app donde **todo color sale de `context.sg`**, para no ahorrar
/// ni cien líneas.
///
/// ## Por qué la firma sale en PNG y con fondo transparente
///
/// PNG porque el trazo es una línea sobre nada: en JPEG cada curva sale con
/// halo. Transparente porque la misma firma se mira sobre la tarjeta clara de
/// la web y sobre la oscura del teléfono, y un fondo blanco pegado se ve como
/// un parche en modo oscuro.
///
/// El trazo se dibuja en **negro** aunque la app esté en oscuro: es el color
/// con el que se firma en papel y el que espera cualquiera que abra el archivo
/// después, incluso fuera de SIGMA.
class SgFirma extends StatefulWidget {
  const SgFirma({super.key, required this.controlador, this.alto = 190});

  final ControladorFirma controlador;
  final double alto;

  @override
  State<SgFirma> createState() => _SgFirmaState();
}

/// Guarda los trazos y sabe convertirlos en PNG.
///
/// Vive fuera del widget para que la hoja que lo contiene pueda preguntarle si
/// hay algo firmado y pedirle los bytes sin tener que buscar un `State`.
class ControladorFirma extends ChangeNotifier {
  /// Cada trazo es una lista de puntos: levantar el dedo empieza uno nuevo.
  /// Sin esa separación, dos trazos sueltos se unirían con una raya recta que
  /// nadie dibujó.
  final List<List<Offset>> trazos = [];

  bool get vacio => trazos.every((t) => t.length < 2);

  void empezar(Offset p) {
    trazos.add([p]);
    notifyListeners();
  }

  void seguir(Offset p) {
    if (trazos.isEmpty) return;
    trazos.last.add(p);
    notifyListeners();
  }

  void limpiar() {
    trazos.clear();
    notifyListeners();
  }

  /// El PNG, o null si no se firmó nada.
  ///
  /// `tamano` es el del recuadro en pantalla; se dibuja al triple para que la
  /// firma no salga pixelada cuando se mire ampliada o se imprima. Un PNG de
  /// una firma a esa escala sigue pesando decenas de kilobytes.
  Future<Uint8List?> aPng(Size tamano) async {
    if (vacio) return null;

    const escala = 3.0;
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    lienzo.scale(escala);

    final pincel = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length < 2) continue;
      final camino = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (var i = 1; i < trazo.length; i++) {
        camino.lineTo(trazo[i].dx, trazo[i].dy);
      }
      lienzo.drawPath(camino, pincel);
    }

    final imagen = await grabadora.endRecording().toImage(
      (tamano.width * escala).round(),
      (tamano.height * escala).round(),
    );
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();

    return datos?.buffer.asUint8List();
  }
}

class _SgFirmaState extends State<SgFirma> {
  final _clave = GlobalKey();

  /// El punto del gesto en coordenadas del recuadro.
  ///
  /// Sin esta conversión los trazos quedarían desplazados por todo lo que haya
  /// encima —la barra, el título de la hoja—, y la firma saldría cortada.
  Offset? _local(Offset global) {
    final caja = _clave.currentContext?.findRenderObject() as RenderBox?;
    return caja?.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: _clave,
          height: widget.alto,
          decoration: BoxDecoration(
            color: sg.campo,
            borderRadius: BorderRadius.circular(SgRadius.campo),
            // El único borde de la app, y con motivo: hay que ver dónde
            // termina el papel antes de empezar a firmar.
            border: Border.all(color: sg.linea),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SgRadius.campo),
            child: GestureDetector(
              onPanStart: (d) {
                final p = _local(d.globalPosition);
                if (p != null) widget.controlador.empezar(p);
              },
              onPanUpdate: (d) {
                final p = _local(d.globalPosition);
                if (p != null) widget.controlador.seguir(p);
              },
              child: AnimatedBuilder(
                animation: widget.controlador,
                builder: (_, _) => CustomPaint(
                  painter: _PintorFirma(
                    trazos: widget.controlador.trazos,
                    color: sg.tinta,
                  ),
                  child: widget.controlador.vacio
                      ? Center(
                          child: Text(
                            'Firma acá con el dedo',
                            style: sora(13, 500, color: sg.tinta3),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.controlador.limpiar,
            icon: Icon(Icons.backspace_outlined, size: 15, color: sg.tinta3),
            label: Text('Borrar', style: sora(12, 600, color: sg.tinta3)),
          ),
        ),
      ],
    );
  }
}

/// En pantalla el trazo va en tinta del tema —en oscuro, uno negro sería
/// invisible—. El PNG que se guarda sí va en negro: son dos cosas distintas y
/// por eso el color no se comparte.
class _PintorFirma extends CustomPainter {
  _PintorFirma({required this.trazos, required this.color});

  final List<List<Offset>> trazos;
  final Color color;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length < 2) continue;
      final camino = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (var i = 1; i < trazo.length; i++) {
        camino.lineTo(trazo[i].dx, trazo[i].dy);
      }
      lienzo.drawPath(camino, pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorFirma anterior) => true;
}
