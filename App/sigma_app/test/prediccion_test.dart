import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';

/// Lo que se fija acá es que la app **no reinterprete** lo que dice el modelo.
///
/// La severidad, el orden y los días los decide el servidor. Estas pruebas
/// existen para que nadie los recalcule en el teléfono más adelante: dos
/// pantallas del mismo sistema priorizando distinto sobre los mismos datos es
/// exactamente el problema que la sábana del SP evita.
void main() {
  Map<String, dynamic> base() => {
        'pre_id': 17,
        'ACTIVO_ID': 42,
        'ACTIVO_NOMBRE': 'Horno L4',
        'ACTIVO_CODIGO': 'ACT-42',
        'VARIABLE_NOMBRE': 'Temperatura',
        'UNIDAD': '°C',
        'pre_fecha_calculo_utc': '2026-09-07T09:00:00',
      };

  group('Prediccion', () {
    test('la severidad la declara el servidor, no los días', () {
      // Un día restante con severidad ADVERTENCIA tiene que salir advertencia.
      // Si la app dedujera la severidad de los días, este caso se pintaría
      // rojo y discreparía con la web sobre el mismo equipo.
      final p = Prediccion.fromJson({
        ...base(),
        'pre_dia_restante': 1,
        'SEVERIDAD_CODIGO': 'ADVERTENCIA',
      });

      expect(p.critica, isFalse);
      expect(p.alta, isFalse);
    });

    test('el margen es la mitad del intervalo, redondeado', () {
      final p = Prediccion.fromJson({
        ...base(),
        'DIA_MINIMO': 28.849321,
        'DIA_MAXIMO': 36.787302,
      });

      // (36,79 - 28,85) / 2 = 3,97 -> 4
      expect(p.margenDias, 4);
    });

    test('sin intervalo no hay margen que mostrar', () {
      expect(Prediccion.fromJson(base()).margenDias, isNull);
    });

    test('sin alerta no se puede abrir una orden', () {
      // Bajo el umbral el modelo no pide que se le crea todavía: la pantalla
      // no debe ofrecer un botón que el servidor va a rechazar.
      final baja = Prediccion.fromJson(base());
      final creible = Prediccion.fromJson({...base(), 'ALERTA_ID': 9});

      expect(baja.ALERTA_ID, isNull);
      expect(creible.ALERTA_ID, 9);
    });

    test('descartada es un estado distinto de revisada', () {
      final aceptada = Prediccion.fromJson({...base(), 'ESTADO_ID': 3});
      final descartada = Prediccion.fromJson({...base(), 'ESTADO_ID': 4});

      expect(aceptada.revisada, isTrue);
      expect(aceptada.descartada, isFalse);
      expect(descartada.revisada, isTrue);
      expect(descartada.descartada, isTrue);
    });
  });

  group('PrediccionFicha', () {
    test('una serie de un punto no dibuja curva', () {
      // Una línea de un solo punto no cuenta ninguna historia.
      final uno = PrediccionFicha.fromJson({
        ...base(),
        'serie': [
          {'FECHA': '2026-09-07T09:00:00', 'VALOR': 89.5}
        ],
      });
      final varios = PrediccionFicha.fromJson({
        ...base(),
        'serie': [
          {'FECHA': '2026-09-01T09:00:00', 'VALOR': 88.0},
          {'FECHA': '2026-09-07T09:00:00', 'VALOR': 89.5},
        ],
      });

      expect(uno.hayCurva, isFalse);
      expect(varios.hayCurva, isTrue);
    });

    test('razones, datos y serie llegan en la misma respuesta', () {
      final f = PrediccionFicha.fromJson({
        ...base(),
        'razones': [
          {'pex_orden': 1, 'pex_texto': 'Viene subiendo.', 'pex_direccion': 'AUMENTA'}
        ],
        'datos': [
          {'cmo_codigo': 'R2', 'cmo_etiqueta': 'Qué tan recta', 'pcr_valor': 0.98}
        ],
        'serie': [
          {'FECHA': '2026-09-07T09:00:00', 'VALOR': 89.5}
        ],
      });

      expect(f.razones.single.sube, isTrue);
      expect(f.datos.single.pcr_imputado, isFalse);
      expect(f.serie.single.VALOR, closeTo(89.5, 0.001));
    });

    test('sin listas, las colecciones son vacías y no nulas', () {
      final f = PrediccionFicha.fromJson(base());
      expect(f.razones, isEmpty);
      expect(f.datos, isEmpty);
      expect(f.serie, isEmpty);
    });
  });

  group('Vigilado', () {
    Map<String, dynamic> v(String motivo, {int lecturas = 0}) => {
          'ava_id': 11,
          'ACTIVO_ID': 40,
          'ACTIVO_NOMBRE': 'Horno L2',
          'LECTURAS': lecturas,
          'MOTIVO': motivo,
        };

    test('el silencio se explica en palabras, y cada motivo dice algo distinto',
        () {
      // Los tres estados no son matices del mismo vacío: «nadie lo mide» pide
      // una acción, «se mide y está tranquilo» es una buena noticia.
      expect(Vigilado.fromJson(v('SIN LECTURAS')).explicacion,
          'Nadie lo ha medido todavía.');
      expect(Vigilado.fromJson(v('FALTAN LECTURAS', lecturas: 2)).explicacion,
          contains('2 lecturas'));
      expect(Vigilado.fromJson(v('SIN SENALES', lecturas: 13)).explicacion,
          contains('no muestra señales'));
    });

    test('los tres motivos son mutuamente excluyentes', () {
      final sin = Vigilado.fromJson(v('SIN LECTURAS'));
      final tranquilo = Vigilado.fromJson(v('SIN SENALES', lecturas: 13));

      expect(sin.sinLecturas, isTrue);
      expect(sin.tranquilo, isFalse);
      expect(tranquilo.tranquilo, isTrue);
      expect(tranquilo.faltanLecturas, isFalse);
    });

    test('atrasada lo decide el servidor contra la frecuencia declarada', () {
      final a = Vigilado.fromJson(
          {...v('SIN SENALES', lecturas: 13), 'ATRASADA': true});

      expect(a.ATRASADA, isTrue);
    });
  });
}
