import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';
import 'package:sigma_app/services/cache_datos.dart';

/// Lo que sostiene el modo sin conexión (HU-151).
///
/// La sábana guarda las columnas en MAYÚSCULAS —`ACT_ID`— y los `fromJson` de
/// la app están escritos contra el DTO del endpoint, que va en minúsculas
/// —`act_id`—. Si esa traducción falla, la app sin señal no muestra nada: no
/// revienta, que es peor, porque parece que no hay datos.
void main() {
  group('Claves tolerantes', () {
    test('el mismo valor se lee en los dos casos', () {
      final f = CacheDatos.conClavesTolerantes({'ACT_ID': 7, 'act_codigo': 'MOT-001'});

      expect(f['ACT_ID'], 7);
      expect(f['act_id'], 7);
      expect(f['act_codigo'], 'MOT-001');
      expect(f['ACT_CODIGO'], 'MOT-001');
    });

    test('lo que ya venía en la fila manda sobre lo derivado', () {
      final f = CacheDatos.conClavesTolerantes({'ID': 1, 'id': 2});

      expect(f['ID'], 1);
      expect(f['id'], 2);
    });

    test('un nulo guardado sigue siendo nulo, no desaparece', () {
      // Si el valor nulo se perdiera, `putIfAbsent` volvería a escribirlo y un
      // campo opcional vacío se vería como ausente.
      final f = CacheDatos.conClavesTolerantes({'AREA_NOMBRE': null});

      expect(f.containsKey('area_nombre'), isTrue);
      expect(f['area_nombre'], isNull);
    });
  });

  group('Una fila de la sábana se mapea con el mismo fromJson', () {
    test('Activo', () {
      // Tal como lo devuelve `API_SEL_APP_SABANA_DATOS` con @TIPO = 4.
      final activo = Activo.fromJson(CacheDatos.conClavesTolerantes({
        'ACT_ID': 33,
        'ACT_CODIGO': 'MOT-001',
        'ACT_NOMBRE': 'Motor principal linea 3',
        'ACT_NUMERO_SERIE': 'WEG-99812',
        'ACT_FABRICANTE': 'WEG',
        'ACT_ACTIVO_ESTADO': 2,
        'PLANTA_NOMBRE': 'Quilicura',
        'AREA_NOMBRE': 'Envasado',
        'POSICION_CODIGO': 'L3-P02',
        'TIPO_NOMBRE': 'Motor electrico',
        'ESTADO_NOMBRE': 'Operativo',
        'ESTADO_CODIGO': 'OPERATIVO',
        'CRITICIDAD_NOMBRE': 'Alta',
      }));

      expect(activo.act_id, 33);
      expect(activo.act_codigo, 'MOT-001');
      expect(activo.act_nombre, 'Motor principal linea 3');
      expect(activo.act_fabricante, 'WEG');
      expect(activo.act_activo_estado, 2);

      // Los que ya venían en mayúsculas por contrato no se rompen.
      expect(activo.PLANTA_NOMBRE, 'Quilicura');
      expect(activo.ESTADO_CODIGO, 'OPERATIVO');
      expect(activo.ruta, 'Quilicura › Envasado › L3-P02');
    });

    test('ClienteInstalacion', () {
      final planta = ClienteInstalacion.fromJson(CacheDatos.conClavesTolerantes({
        'CIN_ID': 4,
        'CIN_NOMBRE': 'Planta Quilicura',
        'CIN_CODIGO': 'QUI',
      }));

      expect(planta.cin_id, 4);
      expect(planta.cin_nombre, 'Planta Quilicura');
      expect(planta.cin_codigo, 'QUI');
    });

    test('la respuesta del endpoint, en minúsculas, sigue funcionando', () {
      // La misma función tiene que servir para la red: si no, habría dos
      // modelos del mismo dato y se desincronizarían.
      final planta = ClienteInstalacion.fromJson(CacheDatos.conClavesTolerantes({
        'cin_id': 4,
        'cin_nombre': 'Planta Quilicura',
      }));

      expect(planta.cin_id, 4);
      expect(planta.cin_nombre, 'Planta Quilicura');
    });
  });
}
