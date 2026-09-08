import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelos.dart';
import '../models/sesion_model.dart';
import '../services/sesion_service.dart';

/// El estado de la sesión, para la UI.
///
/// La UI observa esto; nunca `SesionService`. Cuando cambia, se reconstruyen
/// solos los widgets que lo miran — no hay que refrescar nada a mano.
class SesionNotifier extends Notifier<SesionModel> {
  @override
  SesionModel build() => SesionService.instance.sesion;

  /// Después de un login, de elegir cliente, o de leer el disco al arrancar.
  void refrescar() => state = SesionService.instance.sesion;

  Future<void> cerrar() async {
    await AuthService.instance.cerrar();
    state = const SesionModel();
  }
}

final sesionProvider =
    NotifierProvider<SesionNotifier, SesionModel>(SesionNotifier.new);

/// La instalación en contexto.
///
/// **El v3 elige cliente E instalación**, no solo cliente: un técnico de
/// Hamburgo trabaja en Quilicura o en Maipú, y las existencias, las bodegas y
/// los activos de una no son los de la otra. Sin esto, la app le mostraría las
/// tres plantas mezcladas y tendría que filtrar de memoria.
///
/// A diferencia del cliente, **no viaja en el token**: es un filtro de
/// consulta, no una barrera de seguridad —esa la pone el SP con las plantas
/// que la persona tiene autorizadas—. Por eso vive en un `StateProvider` y no
/// en `SesionService`: perderla al reiniciar es un inconveniente menor;
/// perder el token sería volver a pedir la contraseña.
final instalacionProvider = StateProvider<ClienteInstalacion?>((ref) => null);
