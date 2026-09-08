import 'dart:async';

import 'package:flutter/foundation.dart';

import 'base_local_service.dart';

/// Cuánto se lleva en una gestión, y en qué estado está.
class Cronometro {
  const Cronometro({
    required this.transcurrido,
    required this.corriendo,
    required this.tramos,
  });

  final Duration transcurrido;

  /// True mientras haya un tramo abierto.
  final bool corriendo;

  /// Cuántas veces se retomó. Un trabajo interrumpido cuatro veces cuenta una
  /// historia distinta de uno hecho de corrido, aunque sumen lo mismo.
  final int tramos;

  bool get empezado => tramos > 0;

  int get minutos => transcurrido.inMinutes;

  /// «1:23:45» con horas solo cuando las hay: en una tarea de doce minutos,
  /// el «0:» de la izquierda es ruido que hay que saltarse para leer el dato.
  String get texto {
    final h = transcurrido.inHours;
    final m = transcurrido.inMinutes % 60;
    final s = transcurrido.inSeconds % 60;
    final dm = m.toString().padLeft(2, '0');
    final ds = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$dm:$ds' : '$dm:$ds';
  }

  static const cero = Cronometro(
      transcurrido: Duration.zero, corriendo: false, tramos: 0);
}

/// El cronómetro de una gestión en terreno: tarea, checklist u orden.
///
/// ## Por qué existe
///
/// «Cuánto tomó de verdad» es el dato que ninguna planificación tiene y todas
/// necesitan: sin él, la duración estimada de una tarea se copia del año
/// pasado para siempre. Pedirle a la persona que mire el reloj al empezar y al
/// terminar no funciona —nadie lo hace con guantes y a −5 °C—, así que lo
/// cuenta la app.
///
/// ## Por qué se puede pausar
///
/// Un trabajo de terreno se interrumpe: falta una pieza, hay que esperar un
/// permiso, se corta la energía. Contar ese tiempo como trabajo ensucia el
/// dato que se quería obtener, y no poder pausarlo obliga a cerrar la gestión
/// y abrir otra, que parte la historia en dos registros.
///
/// ## Lo que NO hace
///
/// No corre un temporizador en segundo plano ni pide permisos de fondo. El
/// tiempo sale de la diferencia entre las marcas guardadas, así que da igual
/// que la app esté cerrada: al volver, el tramo abierto sigue contando desde
/// su inicio real. El `Timer` de acá solo repinta la pantalla mientras se
/// mira.
class CronometroService {
  CronometroService._();
  static final CronometroService instance = CronometroService._();

  final _base = BaseLocalService.instance;

  static String _clave(String entidad, int id) => '$entidad:$id';

  /// Lo que observan las pantallas. Uno por gestión: dos pantallas del mismo
  /// trabajo tienen que ver el mismo número.
  final Map<String, ValueNotifier<Cronometro>> _estados = {};
  final Map<String, Timer> _relojes = {};

  ValueNotifier<Cronometro> estado(String entidad, int id) =>
      _estados.putIfAbsent(_clave(entidad, id), () {
        final n = ValueNotifier<Cronometro>(Cronometro.cero);
        // La primera lectura es asíncrona: se dispara y el notifier avisa.
        unawaited(_refrescar(entidad, id));
        return n;
      });

  Future<void> iniciar(String entidad, int id) async {
    final actual = await _leer(entidad, id);
    // Idempotente: tocar «empezar» dos veces no puede abrir dos tramos, y
    // dos tramos abiertos harían que el tiempo corriera al doble.
    if (actual.corriendo) return;

    await _base.abrirTramo(entidad, id);
    await _refrescar(entidad, id);
  }

  Future<void> pausar(String entidad, int id) async {
    await _base.cerrarTramo(entidad, id);
    await _refrescar(entidad, id);
  }

  /// Al cerrar la gestión: se detiene y se devuelven los minutos, que es lo
  /// que viaja al servidor dentro del cierre.
  Future<int> detener(String entidad, int id) async {
    await _base.cerrarTramo(entidad, id);
    final c = await _leer(entidad, id);
    await _refrescar(entidad, id);
    return c.minutos;
  }

  /// Después de que el cierre salió: los tramos ya viajaron dentro de él.
  Future<void> limpiar(String entidad, int id) async {
    await _base.borrarTramos(entidad, id);
    _relojes.remove(_clave(entidad, id))?.cancel();
    _estados[_clave(entidad, id)]?.value = Cronometro.cero;
  }

  Future<Cronometro> _leer(String entidad, int id) async {
    try {
      final filas = await _base.tramos(entidad, id);
      var total = Duration.zero;
      var corriendo = false;

      for (final f in filas) {
        final inicio = DateTime.tryParse('${f['inicio']}');
        if (inicio == null) continue;
        final fin = DateTime.tryParse('${f['fin']}');
        if (fin == null) {
          corriendo = true;
          total += DateTime.now().difference(inicio);
        } else {
          total += fin.difference(inicio);
        }
      }

      // Un reloj movido hacia atrás daría una duración negativa, y «-3 min»
      // en pantalla es peor que no mostrar nada.
      if (total.isNegative) total = Duration.zero;

      return Cronometro(
          transcurrido: total, corriendo: corriendo, tramos: filas.length);
    } catch (e) {
      debugPrint('[Cronometro] No se pudo leer $entidad/$id: $e');
      return Cronometro.cero;
    }
  }

  Future<void> _refrescar(String entidad, int id) async {
    final c = await _leer(entidad, id);
    final k = _clave(entidad, id);
    _estados.putIfAbsent(k, () => ValueNotifier<Cronometro>(Cronometro.cero))
        .value = c;

    // El reloj de un segundo solo existe mientras corre: dejarlo vivo con el
    // cronómetro pausado gasta batería para repintar el mismo número.
    _relojes.remove(k)?.cancel();
    if (!c.corriendo) return;

    _relojes[k] = Timer.periodic(const Duration(seconds: 1), (_) async {
      final n = _estados[k];
      if (n == null) return;
      n.value = await _leer(entidad, id);
    });
  }
}
