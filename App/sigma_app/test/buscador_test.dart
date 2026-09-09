import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/services/buscador.dart';

void main() {
  group('Buscador', () {
    test('«ot4» encuentra OT-04, OT-4 y OT 04', () {
      for (final numero in ['OT-04', 'OT-4', 'OT 04', 'ot/4']) {
        expect(
          coincideBusqueda('ot4', [numero]),
          isTrue,
          reason: 'debería encontrar $numero',
        );
      }
    });

    test('el cero a la izquierda no separa: OT-04 se busca como ot04', () {
      expect(coincideBusqueda('ot04', ['OT-4']), isTrue);
    });

    test('una parte del nombre basta', () {
      expect(
        coincideBusqueda('modeladora', ['ACT-33', 'Modeladora L1']),
        isTrue,
      );
    });

    test('varias palabras: todas tienen que estar', () {
      const campos = ['OT-12', 'Cambio de rodamiento', 'Horno L4'];

      expect(coincideBusqueda('rodamiento horno', campos), isTrue);
      // «bomba» no está: no debe colar por traer una palabra que sí.
      expect(coincideBusqueda('rodamiento bomba', campos), isFalse);
    });

    test('las tildes no separan, y la ñ sí es otra letra', () {
      expect(coincideBusqueda('sepulveda', ['Jonathan Sepúlveda']), isTrue);
      expect(coincideBusqueda('cana', ['Caña de nivel']), isFalse);
    });

    test('buscar nada no filtra nada', () {
      expect(coincideBusqueda('   ', ['lo que sea']), isTrue);
    });

    test('un campo vacío no hace calzar', () {
      expect(coincideBusqueda('horno', [null, '']), isFalse);
    });
  });
}
