import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';

/// Lo que se prueba acá es el mapeo y las decisiones que la app **no** toma.
///
/// La situación de plazo, la conformidad y el estado los decide el servidor;
/// estas pruebas fijan que la app los lea tal cual y no los recalcule. Si
/// mañana alguien mete un `DateTime.now()` en un getter de estos, se cae acá.
void main() {
  group('TareaPendiente', () {
    Map<String, dynamic> base() => {
          'toc_id': 5,
          'tar_titulo': 'Revisar nivel de aceite del reductor',
          'TAREA_CODIGO': 'TAR-001',
          'PRIORIDAD_ID': 2,
          'SITUACION': 'EN PLAZO',
        };

    test('la situación viene del SP y la app no la recalcula', () {
      // Una fecha límite futura con SITUACION VENCIDA tiene que salir vencida:
      // manda el servidor. Dos teléfonos con distinta hora dirían cosas
      // distintas sobre la misma tarea si esto lo calculara la app.
      final t = TareaPendiente.fromJson({
        ...base(),
        'SITUACION': 'VENCIDA',
        'toc_fecha_limite_utc':
            DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
      });

      expect(t.vencida, isTrue);
      expect(t.venceHoy, isFalse);
    });

    test('sin ejecución abierta no está empezada', () {
      expect(TareaPendiente.fromJson(base()).empezada, isFalse);
      expect(
        TareaPendiente.fromJson({...base(), 'EJECUCION_ABIERTA': 12}).empezada,
        isTrue,
      );
    });

    test('crítica es 4, y alta no lo es', () {
      expect(TareaPendiente.fromJson({...base(), 'PRIORIDAD_ID': 3}).critica,
          isFalse);
      expect(TareaPendiente.fromJson({...base(), 'PRIORIDAD_ID': 4}).critica,
          isTrue);
    });

    test('el dónde junta lo que hay y no deja separadores sueltos', () {
      final t = TareaPendiente.fromJson(
          {...base(), 'ACTIVO_CODIGO': 'ACT-34', 'AREA_NOMBRE': 'Linea 1'});

      expect(t.donde, 'ACT-34 · Linea 1');
      expect(TareaPendiente.fromJson(base()).donde, '');
    });
  });

  group('Tarea', () {
    Map<String, dynamic> base() => {
          'toc_id': 5,
          'tar_titulo': 'Purgar condensado',
          'ESTADO_ID': 3,
        };

    test('en ejecución es tener una abierta, no solo haberla tenido', () {
      final abierta = Tarea.fromJson({...base(), 'EJECUCION_ID': 9});
      final cerrada = Tarea.fromJson({
        ...base(),
        'EJECUCION_ID': 9,
        'tej_fecha_fin_utc': '2026-09-06T12:00:00',
      });

      expect(abierta.enEjecucion, isTrue);
      expect(cerrada.enEjecucion, isFalse);
    });

    test('no realizada también está cerrada', () {
      // Estado 5 es NO REALIZADA. Es un desenlace distinto de COMPLETADA, pero
      // la tarea igual se acabó: la pantalla no puede volver a ofrecer cerrarla.
      final t = Tarea.fromJson(
          {...base(), 'ESTADO_ID': 5, 'tej_conforme': false});

      expect(t.cerrada, isTrue);
      expect(t.tej_conforme, isFalse);
    });

    test('sin comentarios la lista es vacía, no nula', () {
      expect(Tarea.fromJson(base()).comentarios, isEmpty);
    });
  });

  group('TareaComentario', () {
    test('lo corregido lo marca el servidor comparando los dos textos', () {
      final c = TareaComentario.fromJson({
        'tco_id': 5,
        'tco_texto': 'El nivel está justo en la marca inferior. No relleno.',
        'tco_fecha_creacion': '2026-09-07T06:24:54',
        'POR_VOZ': true,
        'TEXTO_DICTADO': 'el nivel esta justo en la marca inferior no relleno',
        'DICTADO_CONFIANZA': 0.871,
        'DICTADO_CORREGIDO': true,
      });

      expect(c.POR_VOZ, isTrue);
      expect(c.DICTADO_CORREGIDO, isTrue);
      expect(c.DICTADO_CONFIANZA, closeTo(0.871, 0.0001));

      // Los dos textos se conservan: es lo único que después permite saber si
      // dictar sirve en una sala de máquinas.
      expect(c.TEXTO_DICTADO, isNot(c.tco_texto));
    });

    test('un comentario tecleado no trae dictado', () {
      final c = TareaComentario.fromJson({
        'tco_id': 6,
        'tco_texto': 'Bien avisado.',
        'tco_fecha_creacion': '2026-09-07T06:25:00',
        'POR_VOZ': false,
      });

      expect(c.POR_VOZ, isFalse);
      expect(c.TEXTO_DICTADO, isNull);
      expect(c.DICTADO_CORREGIDO, isFalse);
    });

    test('la respuesta se reconoce por el padre', () {
      final raiz = TareaComentario.fromJson({
        'tco_id': 5,
        'tco_texto': 'a',
        'tco_fecha_creacion': '2026-09-07T06:24:54',
      });
      final hija = TareaComentario.fromJson({
        'tco_id': 6,
        'PADRE_ID': 5,
        'tco_texto': 'b',
        'tco_fecha_creacion': '2026-09-07T06:25:00',
      });

      expect(raiz.esRespuesta, isFalse);
      expect(hija.esRespuesta, isTrue);
      expect(hija.PADRE_ID, 5);
    });
  });
}
