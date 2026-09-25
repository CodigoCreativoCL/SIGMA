import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/widgets/comun/sigma_fieldset.dart';

void main() {
  group('TramoTiempo — la ventana es móvil, no el día del calendario', () {
    // 21:50 de hoy, que es el ejemplo que puso Bryan.
    final ahora = DateTime(2026, 9, 8, 21, 50);

    test('lo de hace un rato entra en las últimas 24 h', () {
      expect(
        TramoTiempo.de(ahora.subtract(const Duration(hours: 3)), ahora: ahora),
        TramoTiempo.ultimas24,
      );
    });

    test('las 21:50 de AYER todavía entran: es el borde exacto', () {
      final justoDentro = ahora.subtract(
        const Duration(hours: 24) - const Duration(minutes: 1),
      );
      expect(TramoTiempo.de(justoDentro, ahora: ahora), TramoTiempo.ultimas24);
    });

    test('las 21:40 de ayer ya no', () {
      final fuera = ahora.subtract(const Duration(hours: 24, minutes: 10));
      expect(TramoTiempo.de(fuera, ahora: ahora), TramoTiempo.anteriores);
    });

    test('a las 00:30, lo de las 23:00 sigue siendo de las últimas 24 h', () {
      // El caso que rompe el día del calendario: turno de noche.
      final medianoche = DateTime(2026, 9, 9, 0, 30);
      final anoche = DateTime(2026, 9, 8, 23, 0);

      expect(TramoTiempo.de(anoche, ahora: medianoche), TramoTiempo.ultimas24);
    });
  });
}
