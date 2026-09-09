import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/theme/app_theme.dart';
import 'package:sigma_app/widgets/comun/sigma_ia.dart';
import 'package:sigma_app/widgets/comun/sigma_v3.dart';

/// La tarjeta de SIGMA AI del Inicio, contra el caso que la reventó.
///
/// El 09-09-2026 se desbordó por 59 px en un teléfono de 411 dp. Eran dos
/// cosas a la vez: la tercera cifra —«6,35 mm/s»— no cabía a tamaño 20 en un
/// tercio del ancho y se iba a dos líneas, y **el alto del carrusel estaba mal
/// desde el principio**: decía 254 cuando la tarjeta ocupa 297.
///
/// Esta prueba existe para que el segundo error no vuelva. Si alguien agrega
/// una línea a la tarjeta, falla acá y no en el teléfono de un técnico.
///
/// Se prueba con el alto real del carrusel porque **el desbordamiento solo
/// existe dentro de esa caja**: medida suelta, la tarjeta crece y nada falla.
void main() {
  Future<void> montar(
    WidgetTester tester,
    List<(String, String)> cifras, {
    double escalaTexto = 1.0,
    double anchoDp = 411,
    String titulo = 'Revolvedora 2',
  }) async {
    tester.view.physicalSize = Size(anchoDp * 3, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escalaTexto)),
          child: Scaffold(
            body: SizedBox(
              // El mismo alto que usa el carrusel, escalado igual que allá.
              height: 297 * escalaTexto,
              child: SgTarjetaIa(
                simbolo: SgIconoIa.prediccion,
                titulo: titulo,
                detalle:
                    'La vibración llega al límite del equipo en unos 24 días, '
                    'si la tendencia se mantiene.',
                badge: 'Alta',
                pie: 'ACT-43 · Linea 3',
                cifras: cifras,
                accion: () {},
                textoAccionSecundaria: 'Ver todo',
                accionSecundaria: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tres cifras con unidad no desbordan la tarjeta', (tester) async {
    await montar(tester, const [
      ('24 d', 'faltan'),
      ('± 3 d', 'margen'),
      ('6,35 mm/s', 'de 7,1 mm/s'),
    ]);

    // `takeException` devuelve el error de overflow que Flutter lanza al
    // pintar. Nulo = la tarjeta cupo.
    expect(tester.takeException(), isNull);
  });

  testWidgets('una cifra larguísima se encoge en vez de partirse', (
    tester,
  ) async {
    await montar(tester, const [
      ('24 d', 'faltan'),
      ('± 3 d', 'margen'),
      ('1.234.567,89 mm/s', 'de 9.999.999 mm/s'),
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('un nombre largo en un teléfono angosto no empuja el alto', (
    tester,
  ) async {
    // El caso que hacía crecer la tarjeta 23 px **solo** en los aparatos
    // chicos: el título se partía en dos líneas. Un alto que depende del ancho
    // es un desbordamiento esperando al teléfono más barato de la planta.
    await montar(
      tester,
      const [
        ('24 d', 'faltan'),
        ('± 3 d', 'margen'),
        ('6,35 mm/s', 'de 7,1 mm/s'),
      ],
      anchoDp: 320,
      titulo: 'Revolvedora 2 de la línea de amasado',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('con el texto en Máximo tampoco desborda', (tester) async {
    // El tope del ajuste de accesibilidad (vista 16.2). Es el caso que iba a
    // romper el Inicio en cuanto alguien subiera el tamaño de la letra.
    await montar(tester, const [
      ('24 d', 'faltan'),
      ('± 3 d', 'margen'),
      ('6,35 mm/s', 'de 7,1 mm/s'),
    ], escalaTexto: 1.5);

    expect(tester.takeException(), isNull);
  });
}
