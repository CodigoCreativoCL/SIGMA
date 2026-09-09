import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/services/accesibilidad_service.dart';

/// El horario de silencio — vista 16.2 (HU-162).
///
/// Se prueba **el tramo que cruza la medianoche**, que es el caso normal
/// —22:00 a 07:00— y el que una comparación ingenua (`>=` y `<=`) deja
/// exactamente al revés: callaría de día y sonaría de noche.
void main() {
  final acc = AccesibilidadService.instance;

  DateTime alas(int hora, [int minuto = 0]) =>
      DateTime(2026, 9, 9, hora, minuto);

  group('Horario de silencio', () {
    test('sin horario, nunca calla', () {
      acc.silencioDesde.value = null;
      acc.silencioHasta.value = null;
      expect(acc.enSilencio(alas(3)), isFalse);
      expect(acc.enSilencio(alas(14)), isFalse);
    });

    test('tramo del mismo día: 13:00 a 15:00', () {
      acc.silencioDesde.value = 13 * 60;
      acc.silencioHasta.value = 15 * 60;

      expect(acc.enSilencio(alas(12, 59)), isFalse);
      expect(acc.enSilencio(alas(13)), isTrue, reason: 'el inicio entra');
      expect(acc.enSilencio(alas(14, 30)), isTrue);
      expect(acc.enSilencio(alas(15)), isFalse, reason: 'el fin no entra');
      expect(acc.enSilencio(alas(23)), isFalse);
    });

    test('tramo que cruza la medianoche: 22:00 a 07:00', () {
      acc.silencioDesde.value = 22 * 60;
      acc.silencioHasta.value = 7 * 60;

      expect(acc.enSilencio(alas(21, 59)), isFalse);
      expect(acc.enSilencio(alas(22)), isTrue);
      expect(acc.enSilencio(alas(23, 30)), isTrue);
      expect(acc.enSilencio(alas(0, 1)), isTrue, reason: 'pasada la medianoche');
      expect(acc.enSilencio(alas(6, 59)), isTrue);
      expect(acc.enSilencio(alas(7)), isFalse);
      expect(acc.enSilencio(alas(13)), isFalse, reason: 'de día no calla');
    });

    test('las dos puntas iguales no son «todo el día»', () {
      // 08:00 a 08:00 es un horario vacío, no uno de veinticuatro horas.
      // Interpretarlo al revés dejaría el teléfono mudo para siempre por un
      // toque de más en el reloj.
      acc.silencioDesde.value = 8 * 60;
      acc.silencioHasta.value = 8 * 60;
      expect(acc.enSilencio(alas(8)), isFalse);
      expect(acc.enSilencio(alas(20)), isFalse);
    });
  });
}
