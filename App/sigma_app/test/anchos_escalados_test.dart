import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/theme/app_theme.dart';
import 'package:sigma_app/theme/sigma_tokens.dart';
import 'package:sigma_app/widgets/comun/sigma_v3.dart';

/// Las filas de la app con la letra en «Máximo» — la otra mitad de la 16.2.
///
/// ## Por qué esta prueba SÍ mira el desbordamiento, y la de altos no
///
/// `altos_escalados_test.dart` no podía: un `Container(height: 28)` con un
/// texto de 30 **recorta en silencio**, sin lanzar nada, así que allí hubo que
/// medir.
///
/// Aquí es al revés. Un `Row` que no cabe **sí** lanza el error —es la franja
/// amarilla y negra de la pantalla—, así que `takeException()` alcanza y además
/// es exactamente lo que se quiere impedir. Pasó de verdad: los cuatro chips de
/// la bandeja se desbordaban 81 px y el cuarto **no recibía toques**. No era
/// feo: el filtro no se podía usar.
///
/// ## El ancho de aquí es el estrecho de verdad
///
/// 360 dp es el teléfono común, y a 1,5x un chip de texto largo mide 344. Por
/// eso estas filas viven en rieles horizontales o ceden con `Flexible`: la
/// prueba reproduce el teléfono angosto, que es donde duele.
void main() {
  /// Pinta `construir` en un ancho de teléfono con el factor de texto dado y
  /// devuelve lo que Flutter haya tenido que denunciar.
  Future<Object?> desbordeCon(
    WidgetTester tester,
    double escala,
    Widget Function() construir,
  ) async {
    // 360 x 800 dp, el Android angosto de siempre.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: Scaffold(
            body: Padding(
              // El mismo margen lateral que usan las pantallas reales: sin él
              // la prueba sería más indulgente que la app.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: construir(),
            ),
          ),
        ),
      ),
    );

    return tester.takeException();
  }

  /// Los tres chips de la bandeja de alertas, tal como quedaron.
  Widget rielDeFiltros(BuildContext context) => SizedBox(
        height: context.alto(36),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          children: [
            const SgChip('Todas', elegido: true),
            const SizedBox(width: 8),
            const SgChip('No leídas', elegido: false, contador: 12),
            const SizedBox(width: 8),
            const SgChip('Críticas', elegido: false, contador: 3),
          ],
        ),
      );

  group('Una fila de filtros no se desborda con la letra al máximo', () {
    testWidgets('el riel aguanta 1,0x', (tester) async {
      final e = await desbordeCon(
        tester,
        1.0,
        () => Builder(builder: rielDeFiltros),
      );
      expect(e, isNull);
    });

    testWidgets('y aguanta 1,5x, que es el tope del ajuste', (tester) async {
      final e = await desbordeCon(
        tester,
        1.5,
        () => Builder(builder: rielDeFiltros),
      );
      expect(e, isNull);
    });
  });

  group('La prueba tiene dientes', () {
    /* ESTO ES LO QUE FALTÓ LA PRIMERA VEZ

       La prueba de altos estuvo en verde un rato sin mirar nada. Así que aquí
       se comprueba al revés: se arma la MISMA fila como estaba ANTES —un `Row`
       pelado— y se exige que falle. Si esto pasara a verde, la prueba de arriba
       dejaría de significar algo. */
    testWidgets('un Row pelado con los mismos chips SÍ se desborda a 1,5x',
        (tester) async {
      final e = await desbordeCon(
        tester,
        1.5,
        () => const Row(
          children: [
            SgChip('Todas', elegido: true),
            SizedBox(width: 8),
            SgChip('No leídas', elegido: false, contador: 12),
            SizedBox(width: 8),
            SgChip('Críticas', elegido: false, contador: 3),
          ],
        ),
      );
      expect(e, isA<FlutterError>());
      expect('$e', contains('overflowed'));
    });
  });

  group('Lo que cede es lo accesorio, no la acción', () {
    testWidgets('un chip con un resumen al lado: cede el resumen',
        (tester) async {
      final e = await desbordeCon(
        tester,
        1.5,
        () => Row(
          children: [
            const SgChip('Con saldo', elegido: true),
            const Spacer(),
            Flexible(
              child: Text(
                '148 repuestos · 12 bajo mínimo',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: sora(12, 600),
              ),
            ),
          ],
        ),
      );
      expect(e, isNull);
    });

    testWidgets('sin Flexible, esa misma fila se desborda', (tester) async {
      final e = await desbordeCon(
        tester,
        1.5,
        () => Row(
          children: [
            const SgChip('Con saldo', elegido: true),
            const Spacer(),
            Text('148 repuestos · 12 bajo mínimo', style: sora(12, 600)),
          ],
        ),
      );
      expect(e, isA<FlutterError>());
    });
  });

  group('Dos insignias de estado caben bajando de línea', () {
    testWidgets('el Wrap de la cabecera del Inicio aguanta 1,5x',
        (tester) async {
      final e = await desbordeCon(
        tester,
        1.5,
        () => Wrap(
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SgBadge('Sin señal', color: SgColor.teal, punto: true),
            const SizedBox(width: 8),
            SgBadge(
              '3 en cola',
              color: SgColor.ambar,
              icono: Icons.cloud_upload_outlined,
            ),
          ],
        ),
      );
      expect(e, isNull);
    });
  });
}
