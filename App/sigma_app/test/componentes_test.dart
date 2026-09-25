import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';

/// Las tres decisiones que las vistas 8.x, 9.2 y 6.7 toman **en el teléfono**.
///
/// Todo lo demás lo decide la base —el incremento entre lecturas, el próximo
/// umbral, si un resultado es válido— y por eso no se prueba acá: probar en
/// Dart una regla que hace cumplir un SP es escribir la regla dos veces.
void main() {
  Componente conEstado(String estado) => Componente(
    ACO_ID: 1,
    ACO_ACTIVO: 1,
    ACO_CODIGO: 'CMP-1',
    ACO_NOMBRE: 'Motor',
    ESTADO_NOMBRE: estado,
  );

  group('Componente', () {
    test('el estado que pide atención sale del nombre, no de un id', () {
      // Los estados son catálogo y cada cliente puede tener los suyos: un id
      // fijo en el teléfono se rompería con el primer cliente que los cambie.
      expect(conEstado('Degradado').enObservacion, isTrue);
      expect(conEstado('Con observación').enObservacion, isTrue);
      expect(conEstado('Fuera de servicio').enObservacion, isTrue);
      expect(conEstado('Dado de baja').enObservacion, isTrue);
    });

    test('operativo no pide atención', () {
      expect(conEstado('Operativo').enObservacion, isFalse);
      expect(conEstado('').enObservacion, isFalse);
    });

    test('un JSON sin medidores ni fotos no revienta', () {
      final c = Componente.fromJson({
        'ACO_ID': 7,
        'ACO_ACTIVO': 33,
        'ACO_CODIGO': 'CMP-33-01',
        'ACO_NOMBRE': 'Motor principal',
      });
      expect(c.FOTOS, isEmpty);
      expect(c.MEDIDORES, isEmpty);
      expect(c.PADRE_NOMBRE, isNull);
    });
  });

  group('Umbral del medidor', () {
    test('avisa cuando el valor ya entró en la franja', () {
      const u = MedidorUmbral(
        PME_ID: 1,
        VALOR_ACTUAL: 7900,
        AVISO_DESDE: 7800,
        PROXIMO_UMBRAL: 8000,
      );
      expect(u.avisando, isTrue);
    });

    test('no avisa antes de la franja', () {
      const u = MedidorUmbral(
        PME_ID: 1,
        VALOR_ACTUAL: 7500,
        AVISO_DESDE: 7800,
        PROXIMO_UMBRAL: 8000,
      );
      expect(u.avisando, isFalse);
    });

    test('sin programación configurada no avisa nada', () {
      // Es el caso normal: la mayoría de los medidores no tiene programación.
      // Un `true` acá pintaría de ámbar todos los medidores de la planta.
      const u = MedidorUmbral(PME_ID: 1, VALOR_ACTUAL: 7500);
      expect(u.avisando, isFalse);
    });
  });

  group('Validación', () {
    test('las palabras del resultado son las de la base', () {
      // `CK_OTV_RESULTADO` solo admite APROBADO y RECHAZADO. La app las lee,
      // no las inventa: inventarlas fue lo que hizo rebotar todos los INSERT
      // la primera vez.
      const aprobada = Validacion(
        OTV_ID: 1,
        OTV_ORDEN_TRABAJO: 14,
        OTV_VALIDACION_TIPO: 3,
        OTV_RESULTADO: 'APROBADO',
      );
      const rechazada = Validacion(
        OTV_ID: 2,
        OTV_ORDEN_TRABAJO: 14,
        OTV_VALIDACION_TIPO: 2,
        OTV_RESULTADO: 'RECHAZADO',
      );

      expect(aprobada.aprobada, isTrue);
      expect(rechazada.aprobada, isFalse);
    });
  });
}
