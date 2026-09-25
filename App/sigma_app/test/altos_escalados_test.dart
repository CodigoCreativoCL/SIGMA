import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/theme/app_theme.dart';
import 'package:sigma_app/theme/sigma_tokens.dart';
import 'package:sigma_app/widgets/comun/sigma_v3.dart';

/// El kit con la letra en «Máximo» — vista 16.2.
///
/// ## Qué se prueba, y por qué NO con el error de desbordamiento
///
/// El primer intento de esta prueba miraba `tester.takeException()`, como la
/// de la tarjeta de SIGMA AI. **No servía.** Ahí el desbordamiento era de un
/// `Column` dentro de una caja fija, y eso Flutter lo denuncia. Un
/// `Container(height: 28)` con un texto de 30 no denuncia nada: recorta en
/// silencio.
///
/// Se comprobó devolviendo el `SgChip` a su alto en duro: la prueba seguía en
/// verde. Es la peor clase de prueba —la que tranquiliza sin mirar nada—.
///
/// Lo que sí distingue una cosa de la otra es **medir**: un alto que envuelve
/// texto tiene que crecer cuando el texto crece. Si no crece, es que sigue
/// siendo un número en duro.
///
/// ## Por qué 1.5 y no 2.0
///
/// Porque 1.5 es el tope del ajuste, decidido en `AccesibilidadService`.
/// Probar más sería probar un caso que la app no permite.
void main() {
  /// El alto real de lo construido, pintado con el factor de texto dado.
  Future<double> altoCon(
    WidgetTester tester,
    double escala,
    Widget Function() construir, {
    bool anchoLibre = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final clave = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: Scaffold(
            /* EL ANCHO NO PUEDE SER LO QUE FALLE

               Lo que se mide es el ALTO. Un chip con texto largo a 1,5x mide
               344 de ancho y no cabe en una pantalla de 360: la prueba fallaba
               por el costado, que es otro asunto.

               Y no es un asunto real en la app: estos widgets viven dentro de
               un riel horizontal, que da ancho ilimitado y hace scroll. Se
               reproduce esa condición, no una que no existe.

               `anchoLibre: false` para lo que necesita un ancho de verdad: el
               botón ocupa el ancho entero por definición, y un riel que
               scrollea no puede vivir dentro de otro scroll. */
            body: Align(
              alignment: Alignment.topLeft,
              child: anchoLibre
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: KeyedSubtree(key: clave, child: construir()),
                    )
                  : KeyedSubtree(key: clave, child: construir()),
            ),
          ),
        ),
      ),
    );

    final caja = clave.currentContext!.findRenderObject() as RenderBox;
    return caja.size.height;
  }

  /// Crece con la letra. No en proporción exacta —los rellenos internos no
  /// escalan—, pero sí de verdad: lo que se rechaza es que **no se mueva**,
  /// que es justo lo que hace un número en duro.
  Future<void> creceConElTexto(
    WidgetTester tester,
    Widget Function() construir, {
    bool anchoLibre = true,
  }) async {
    final normal = await altoCon(
      tester,
      1.0,
      construir,
      anchoLibre: anchoLibre,
    );
    final maximo = await altoCon(
      tester,
      1.5,
      construir,
      anchoLibre: anchoLibre,
    );

    expect(
      maximo,
      greaterThan(normal),
      reason: 'el alto no se movió: sigue siendo un número en duro',
    );
    expect(
      maximo,
      greaterThanOrEqualTo(normal * 1.4),
      reason: 'creció, pero bastante menos de lo que creció la letra',
    );
  }

  testWidgets('el chip crece con el texto', (tester) async {
    await creceConElTexto(
      tester,
      () => const SgChip('Cualquier estado', elegido: true, contador: 12),
    );
  });

  testWidgets('la píldora de estado crece con el texto', (tester) async {
    await creceConElTexto(
      tester,
      () => const SgBadge('Esperando cierre', color: Colors.orange),
    );
  });

  testWidgets('la píldora chica también', (tester) async {
    await creceConElTexto(
      tester,
      () => const SgBadge('Vencido', color: Colors.red, chico: true),
    );
  });

  testWidgets('el botón de pie crece con el texto', (tester) async {
    await creceConElTexto(
      tester,
      () => SgBoton('Registrar condición', icono: Icons.speed, onTap: () {}),
      anchoLibre: false,
    );
  });

  testWidgets('el botón de dentro de una tarjeta también', (tester) async {
    // El de 44 es el más apretado del kit.
    await creceConElTexto(
      tester,
      () => SgBoton('Ver análisis', alto: 44, tamanoTexto: 14, onTap: () {}),
      anchoLibre: false,
    );
  });

  testWidgets('el contador crece con su cifra', (tester) async {
    await creceConElTexto(
      tester,
      () => const SgContador(99, color: Colors.red),
    );
  });

  testWidgets('un riel de chips crece al paso del chip', (tester) async {
    // El caso que se repetía en siete pantallas: un `SizedBox` de alto fijo
    // con una fila de chips dentro. Si el riel no crece al mismo paso que el
    // chip, el chip crecido se recorta contra el borde del riel —y lo hace en
    // silencio, sin que nadie se entere hasta que un técnico no puede leer un
    // filtro—.
    await creceConElTexto(
      tester,
      () => Builder(
        builder: (context) => SizedBox(
          height: context.alto(36),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              SgChip('Todas', elegido: true),
              SizedBox(width: 8),
              SgChip('Línea de amasado', elegido: false),
            ],
          ),
        ),
      ),
      anchoLibre: false,
    );
  });

  test('el atajo escala, y no inventa', () {
    // `context.alto` no se puede probar sin un árbol, pero sí la cuenta que
    // hace: es el factor del usuario, no uno propio.
    const escala = TextScaler.linear(1.5);
    expect(escala.scale(SgMedida.chip), 42);
    expect(escala.scale(SgMedida.boton), 78);
  });
}
