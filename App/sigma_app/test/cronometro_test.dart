import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/services/cronometro_service.dart';

/// El cronómetro mide **trabajo**, no tiempo de pantalla.
///
/// Lo que se prueba acá es el formato y la lectura del estado, que es lo que
/// ve la persona. Los tramos viven en SQLite y su lectura se prueba en el
/// teléfono: un `sqflite` en el escritorio necesita otro motor y probaría una
/// implementación que no es la que corre.
void main() {
  group('Cómo se lee el tiempo', () {
    test('bajo una hora no se muestra el 0 de las horas', () {
      // «0:07:12» obliga a saltarse un cero para leer el dato, y una tarea de
      // terreno dura minutos, no horas.
      const c = Cronometro(
          transcurrido: Duration(minutes: 7, seconds: 12),
          corriendo: true,
          tramos: 1);

      expect(c.texto, '07:12');
    });

    test('con horas, aparecen', () {
      const c = Cronometro(
          transcurrido: Duration(hours: 1, minutes: 23, seconds: 45),
          corriendo: true,
          tramos: 2);

      expect(c.texto, '1:23:45');
    });

    test('los segundos y minutos van con dos cifras', () {
      const c = Cronometro(
          transcurrido: Duration(hours: 2, minutes: 3, seconds: 4),
          corriendo: false,
          tramos: 1);

      expect(c.texto, '2:03:04');
    });

    test('recién abierto no muestra nada raro', () {
      expect(Cronometro.cero.texto, '00:00');
      expect(Cronometro.cero.empezado, isFalse);
      expect(Cronometro.cero.corriendo, isFalse);
    });
  });

  group('Los minutos que viajan al servidor', () {
    test('se truncan, no se redondean hacia arriba', () {
      // 59 segundos son cero minutos de trabajo. Redondear a 1 inflaría cada
      // tarea corta, y son las más frecuentes de una ronda.
      const c = Cronometro(
          transcurrido: Duration(seconds: 59), corriendo: false, tramos: 1);

      expect(c.minutos, 0);
    });

    test('una tarea de dos tramos suma los dos', () {
      const c = Cronometro(
          transcurrido: Duration(minutes: 18), corriendo: false, tramos: 2);

      expect(c.minutos, 18);
      // Y se sabe que se interrumpió: un trabajo partido en dos cuenta una
      // historia distinta de uno hecho de corrido, aunque sumen lo mismo.
      expect(c.tramos, 2);
    });
  });
}
