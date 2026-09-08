import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'outbox_service.dart';

/// Dispara la cola cuando vuelve la señal.
///
/// ## Los tres momentos, y ninguno más
///
/// Android no permite un servicio de fondo persistente de forma confiable, así
/// que la sincronización se dispara en tres momentos:
///
///   1. Al abrir la app, **después del primer frame**.
///   2. Al recuperar la red — solo en la transición `offline → online`.
///   3. Inmediatamente después de cada acción, si hay red.
///
/// ## Por qué el debounce
///
/// La conectividad de Android parpadea: al entrar a una bodega el teléfono
/// puede reportar seis cambios en dos segundos. Sin el debounce, cada uno
/// dispararía un despacho.
///
/// ## Por qué solo la transición
///
/// Reaccionar a *cualquier* cambio dispararía también al pasar de wifi a datos
/// estando ya en línea, que no es un momento en que haya nada nuevo que
/// mandar.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _debounce = Duration(seconds: 2);

  StreamSubscription<List<ConnectivityResult>>? _suscripcion;
  Timer? _temporizador;
  bool _online = false;

  /// Para el badge de conexión de la barra superior.
  final ValueNotifier<bool> enLinea = ValueNotifier<bool>(true);

  Future<void> init() async {
    await OutboxService.instance.init();

    try {
      _online = _hayRed(await Connectivity().checkConnectivity());
      enLinea.value = _online;

      _suscripcion =
          Connectivity().onConnectivityChanged.listen(_alCambiar);

      if (_online) unawaited(OutboxService.instance.despachar());
    } catch (e) {
      // Sin conectividad detectable la app tiene que funcionar igual: se
      // asume que hay red y que el error lo dirá el propio envío.
      debugPrint('[SyncService] Sin detección de red: $e');
    }
  }

  void _alCambiar(List<ConnectivityResult> estados) {
    final ahora = _hayRed(estados);
    final volvio = !_online && ahora;
    _online = ahora;
    enLinea.value = ahora;

    if (!volvio) return;

    _temporizador?.cancel();
    _temporizador = Timer(_debounce, () {
      debugPrint('[SyncService] Volvió la red: despachando la cola');
      unawaited(OutboxService.instance.despachar());
    });
  }

  bool _hayRed(List<ConnectivityResult> e) =>
      e.isNotEmpty && !e.every((r) => r == ConnectivityResult.none);

  /// Después de guardar algo: se intenta enviar sin que la pantalla espere.
  void despacharAhora() {
    if (_online) unawaited(OutboxService.instance.despachar());
  }

  void dispose() {
    _temporizador?.cancel();
    _suscripcion?.cancel();
  }
}
