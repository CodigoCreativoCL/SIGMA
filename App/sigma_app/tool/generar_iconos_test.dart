import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generador de los recursos de marca de Android.
///
/// ## Por qué es un test y no un script
///
/// Los logotipos oficiales de SIGMA son **SVG**, y Android necesita PNG por
/// densidad. Rasterizar un SVG requiere un motor gráfico, y el único que este
/// proyecto ya tiene —y que dibuja **exactamente igual** que la app— es el de
/// Flutter. Un rasterizador externo (Inkscape, ImageMagick, cairo) sería una
/// herramienta más que instalar en cada equipo del grupo, y una que puede
/// interpretar un degradado distinto que la app.
///
/// No corre con la suite normal: `flutter test` sin argumentos solo recorre
/// `test/`, y esto vive en `tool/`. Se ejecuta a mano cuando cambia la marca:
///
/// ```bash
/// flutter test tool/generar_iconos_test.dart
/// ```
void main() {
  const res = 'android/app/src/main/res';

  /// Las cinco densidades de Android y su factor sobre `mdpi`.
  const densidades = <String, double>{
    'mdpi': 1,
    'hdpi': 1.5,
    'xhdpi': 2,
    'xxhdpi': 3,
    'xxxhdpi': 4,
  };

  /// Rasteriza un widget a PNG del tamaño pedido.
  Future<Uint8List> aPng(WidgetTester tester, Widget contenido, int lado) async {
    final clave = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: clave,
              child: SizedBox(
                width: lado.toDouble(),
                height: lado.toDouble(),
                child: contenido,
              ),
            ),
          ),
        ),
      ),
    );

    // El SVG se decodifica de forma asíncrona: sin esto se captura el hueco
    // vacío de antes de que termine de cargar, y salen PNG transparentes.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    final limite =
        clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage(pixelRatio: 1);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);

    return datos!.buffer.asUint8List();
  }

  void escribir(String ruta, Uint8List bytes) {
    final f = File(ruta);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    debugPrint('  ${bytes.length ~/ 1024} KB  $ruta');
  }

  testWidgets('ic_launcher — el icono completo, por densidad', (tester) async {
    // 48 dp es el tamaño canónico del icono de lanzador en mdpi.
    for (final d in densidades.entries) {
      final lado = (48 * d.value).round();
      final png = await aPng(
        tester,
        SvgPicture.asset('assets/images/sigma-app-icon-dark.svg',
            width: lado.toDouble(), height: lado.toDouble()),
        lado,
      );
      escribir('$res/mipmap-${d.key}/ic_launcher.png', png);
    }
  });

  testWidgets('ic_launcher_foreground — la capa del icono adaptativo',
      (tester) async {
    // El icono adaptativo se dibuja sobre un lienzo de 108 dp del que el
    // sistema recorta la forma; solo los 72 dp centrales son zona segura. Por
    // eso el isotipo va al 60 %: más grande y el launcher le corta las puntas
    // al aplicar su máscara circular.
    for (final d in densidades.entries) {
      final lado = (108 * d.value).round();
      final png = await aPng(
        tester,
        Center(
          child: SvgPicture.asset('assets/images/sigma-isotipo-white.svg',
              height: lado * 0.42),
        ),
        lado,
      );
      escribir('$res/mipmap-${d.key}/ic_launcher_foreground.png', png);
    }
  });

  testWidgets('splash — el isotipo de la pantalla de arranque', (tester) async {
    // Se dibuja centrado sobre el fondo de marca, que lo pone el XML: el PNG
    // va con fondo transparente para que sirva en claro y en oscuro.
    for (final d in densidades.entries) {
      final lado = (160 * d.value).round();
      final png = await aPng(
        tester,
        Center(
          child: SvgPicture.asset('assets/images/sigma-isotipo-gradient.svg',
              height: lado * 0.8),
        ),
        lado,
      );
      escribir('$res/drawable-${d.key}/splash_sigma.png', png);
    }
  });
}
