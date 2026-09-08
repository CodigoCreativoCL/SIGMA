import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generador de los recursos de marca de Android.
///
/// ## Por qué es un test y no un script
///
/// Los logotipos oficiales de SIGMA son **SVG** y Android necesita PNG por
/// densidad. Rasterizar un SVG requiere un motor gráfico, y el único que el
/// proyecto ya tiene —y que dibuja **exactamente igual** que la app— es el de
/// Flutter. Un rasterizador externo sería una herramienta más que instalar en
/// cada equipo del grupo, y una que puede interpretar un degradado distinto.
///
/// ## Por qué NO se dibuja con `SvgPicture` en un widget
///
/// El primer intento montaba `SvgPicture.asset` en un árbol y capturaba un
/// `RepaintBoundary`. Se colgaba: la decodificación del SVG es asíncrona y
/// `pumpAndSettle` se queda esperando un frame que no llega.
///
/// Acá se va directo al grano: se lee el archivo del disco —sin `AssetBundle`,
/// que en un test es otra fuente de bloqueos—, se convierte a `PictureInfo` y
/// se pinta en un lienzo del tamaño exacto. Sin árbol de widgets no hay nada
/// que asentar.
///
/// ## Cómo se ejecuta
///
/// No corre con la suite normal: `flutter test` sin argumentos solo recorre
/// `test/`, y esto vive en `tool/`. Se lanza a mano cuando cambia la marca:
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

  /// El SVG del disco, pintado en un cuadrado de `lado` píxeles.
  ///
  /// El dibujo se centra y se escala por el lado menor, así un logotipo que no
  /// es cuadrado —el wordmark, el isotipo— no sale deformado.
  Future<Uint8List> rasterizar(String svg, int lado, {double ocupa = 1}) async {
    final info = await vg.loadPicture(
      SvgStringLoader(File(svg).readAsStringSync()),
      null,
    );

    final grabador = ui.PictureRecorder();
    final lienzo = ui.Canvas(grabador);

    final escala =
        (lado * ocupa) / (info.size.width > info.size.height
            ? info.size.width
            : info.size.height);

    lienzo.translate(
      (lado - info.size.width * escala) / 2,
      (lado - info.size.height * escala) / 2,
    );
    lienzo.scale(escala);
    lienzo.drawPicture(info.picture);

    final imagen = await grabador.endRecording().toImage(lado, lado);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);

    info.picture.dispose();
    imagen.dispose();

    return datos!.buffer.asUint8List();
  }

  void escribir(String ruta, Uint8List bytes) {
    final f = File(ruta);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('  ${(bytes.length / 1024).toStringAsFixed(1)} KB  $ruta');
  }

  test('ic_launcher — el icono completo, por densidad', () async {
    // 48 dp es el tamaño canónico del icono de lanzador en mdpi. El SVG ya
    // trae su propio fondo redondeado de marca, así que ocupa el lienzo entero.
    for (final d in densidades.entries) {
      final lado = (48 * d.value).round();
      escribir('$res/mipmap-${d.key}/ic_launcher.png',
          await rasterizar('assets/images/sigma-app-icon-dark.svg', lado));
    }
  });

  test('ic_launcher_foreground — la capa del icono adaptativo', () async {
    // El adaptativo se dibuja en 108 dp de los que el sistema recorta la
    // forma: solo los 72 dp centrales son zona segura. Por eso el isotipo
    // ocupa el 42 % — más grande y la máscara circular le corta las puntas.
    for (final d in densidades.entries) {
      final lado = (108 * d.value).round();
      escribir(
          '$res/mipmap-${d.key}/ic_launcher_foreground.png',
          await rasterizar('assets/images/sigma-isotipo-white.svg', lado,
              ocupa: 0.42));
    }
  });

  test('splash — el isotipo de la pantalla de arranque', () async {
    // Fondo transparente: el color lo pone el XML, y así el mismo PNG sirve
    // en claro y en oscuro.
    for (final d in densidades.entries) {
      final lado = (160 * d.value).round();
      escribir(
          '$res/drawable-${d.key}/splash_sigma.png',
          await rasterizar('assets/images/sigma-isotipo-gradient.svg', lado,
              ocupa: 0.8));
    }
  });
}
