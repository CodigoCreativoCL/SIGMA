import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelos.dart';
import '../models/sesion_model.dart';
import '../services/sesion_service.dart';
import 'dart:async';

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

final sesionProvider = NotifierProvider<SesionNotifier, SesionModel>(
  SesionNotifier.new,
);

/// La instalación en contexto.
///
/// **El v3 elige cliente E instalación**, no solo cliente: un técnico de
/// Hamburgo trabaja en Quilicura o en Maipú, y las existencias, las bodegas y
/// los activos de una no son los de la otra. Sin esto, la app le mostraría las
/// tres plantas mezcladas y tendría que filtrar de memoria.
///
/// A diferencia del cliente, **no viaja en el token**: es un filtro de
/// consulta, no una barrera de seguridad —esa la pone el SP con las plantas
/// que la persona tiene autorizadas—.
///
/// ## Se recuerda entre arranques
///
/// Antes no, y el comentario decía que perderla era «un inconveniente menor».
/// No lo era: la sábana se descarga **por planta** y media app filtra por
/// ella, así que al retomar la app —después de que Android la matara, lo
/// normal si se deja un rato en segundo plano— los listados bajaban vacíos sin
/// que nada explicara por qué.
///
/// El id se guarda en `SesionService` cada vez que cambia, y `restaurar()` lo
/// vuelve a poner al arrancar. Lo que **no** se guarda es el objeto: el nombre
/// lo trae `plantas()` fresco, y una copia guardada envejecería el día que
/// desde la web renombren la planta.
final instalacionProvider =
    NotifierProvider<InstalacionElegida, ClienteInstalacion?>(
      InstalacionElegida.new,
    );

class InstalacionElegida extends Notifier<ClienteInstalacion?> {
  @override
  ClienteInstalacion? build() => null;

  /// Elegir una planta. Se recuerda para el próximo arranque.
  void elegir(ClienteInstalacion? planta) {
    state = planta;
    // Sin await: que la pantalla no espere al disco para cambiar de planta.
    unawaited(SesionService.instance.recordarInstalacion(planta?.cin_id));
  }

  /// Vuelve a poner la planta recordada, si sigue estando entre las
  /// autorizadas.
  ///
  /// **Se comprueba contra la lista**, no se restaura a ciegas: a alguien le
  /// pueden haber quitado una planta desde la web mientras la app estaba
  /// cerrada, y devolverle esa sería dejarlo trabajando donde ya no le
  /// corresponde.
  bool restaurar(List<ClienteInstalacion> autorizadas) {
    final id = SesionService.instance.instalacionRecordada;
    if (id == null || autorizadas.isEmpty) return false;

    for (final p in autorizadas) {
      if (p.cin_id == id) {
        state = p;
        return true;
      }
    }

    // Ya no la tiene: se olvida, para no reintentarlo en cada arranque.
    unawaited(SesionService.instance.recordarInstalacion(null));
    return false;
  }
}
