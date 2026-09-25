import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los ajustes de accesibilidad — vista 16.2 del diseño v3 (HU-161, HU-162).
///
/// ## Por qué son por usuario y no del aparato
///
/// El teléfono de planta se comparte entre turnos. Si el tamaño del texto
/// fuera del aparato, el técnico del segundo turno heredaría la letra grande
/// del primero y creería que la app se descompuso. La preferencia acompaña a
/// la persona, así que la clave lleva su id: `sigma_acc_<usuario>_<campo>`.
///
/// Antes de entrar —pantalla de login— se lee el juego del usuario `0`, que
/// son los valores de fábrica. No hay a quién preguntarle todavía.
///
/// ## Por qué no viaja al servidor
///
/// Porque no la usa nadie más. El idioma y el teléfono viven en `Usuarios`
/// porque la web también los lee; el tamaño de la letra en **este** aparato,
/// no. Subirla obligaría a una tabla, un SP y una ruta para algo que solo
/// sirve del lado de acá.
class AccesibilidadService {
  AccesibilidadService._();
  static final AccesibilidadService instance = AccesibilidadService._();

  int _usuario = 0;

  /// Cuánto se agranda el texto: 1.0, 1.15, 1.3 o 1.5.
  ///
  /// El tope es 1.5 y no 2.0 a propósito. Más allá, las tarjetas del v3
  /// —hechas con altos fijos para que la lista no baile— empiezan a cortar
  /// texto, y un ajuste de accesibilidad que esconde información no acomoda a
  /// nadie. Se acota acá, en un solo lugar, y no en cada pantalla.
  final ValueNotifier<double> escalaTexto = ValueNotifier<double>(1.0);

  /// Alto contraste: extremos en el fondo, metadatos que dejan de ser grises
  /// y contorno en las tarjetas.
  final ValueNotifier<bool> altoContraste = ValueNotifier<bool>(false);

  /// Movimiento reducido: nada gira, late ni barre solo.
  ///
  /// No es capricho de diseño. Para quien tiene trastorno vestibular, una
  /// animación que se repite sin parar —el barrido del esqueleto, el carrusel
  /// que avanza solo— produce mareo real. Y en una planta con vibración de
  /// fondo, es peor.
  final ValueNotifier<bool> movimientoReducido = ValueNotifier<bool>(false);

  /// La confirmación háptica de `SgPulso`.
  ///
  /// De fábrica encendida: con guantes y ruido, el toquecito es a veces la
  /// única señal de que el botón se apretó de verdad. Se apaga porque con el
  /// teléfono en un bolsillo del overol, la vibración constante molesta.
  final ValueNotifier<bool> haptica = ValueNotifier<bool>(true);

  /// El horario de silencio, en minutos desde medianoche.
  ///
  /// Nulo = sin horario. Puede **cruzar la medianoche** (22:00 a 07:00), que
  /// es justamente el caso normal, y por eso [enSilencio] no compara con un
  /// simple `>=` y `<=`.
  final ValueNotifier<int?> silencioDesde = ValueNotifier<int?>(null);
  final ValueNotifier<int?> silencioHasta = ValueNotifier<int?>(null);

  /// ¿Hay que callar el aviso que llega en este instante?
  ///
  /// Lo consulta quien vaya a sonar. Hoy no suena nada —el push es HU-077—,
  /// pero la regla se decide una vez y acá: repartida por los llamadores,
  /// alguno se olvidaría del tramo que cruza la medianoche.
  bool enSilencio([DateTime? cuando]) {
    final desde = silencioDesde.value;
    final hasta = silencioHasta.value;
    if (desde == null || hasta == null || desde == hasta) return false;

    final ahora = cuando ?? DateTime.now();
    final minuto = ahora.hour * 60 + ahora.minute;

    // Tramo normal (13:00 a 15:00): dentro es estar entre los dos.
    if (desde < hasta) return minuto >= desde && minuto < hasta;

    // Tramo que cruza la medianoche (22:00 a 07:00): dentro es estar
    // después del inicio **o** antes del fin.
    return minuto >= desde || minuto < hasta;
  }

  /// Lee los ajustes de una persona. Se llama al arrancar y al entrar.
  Future<void> cargar(int usuario) async {
    _usuario = usuario;
    try {
      final prefs = await SharedPreferences.getInstance();
      escalaTexto.value = prefs.getDouble(_k('escala')) ?? 1.0;
      altoContraste.value = prefs.getBool(_k('contraste')) ?? false;
      movimientoReducido.value = prefs.getBool(_k('movimiento')) ?? false;
      haptica.value = prefs.getBool(_k('haptica')) ?? true;
      silencioDesde.value = prefs.getInt(_k('silencio_desde'));
      silencioHasta.value = prefs.getInt(_k('silencio_hasta'));
    } catch (e) {
      // Quedarse sin la preferencia es molesto; quedarse sin pantalla, no se
      // puede. Mismo criterio que `TemaService`.
      debugPrint('[Accesibilidad] No se pudieron leer: $e');
    }
  }

  Future<void> cambiarEscala(double v) async {
    escalaTexto.value = v;
    await _guardar((p) => p.setDouble(_k('escala'), v));
  }

  Future<void> cambiarContraste(bool v) async {
    altoContraste.value = v;
    await _guardar((p) => p.setBool(_k('contraste'), v));
  }

  Future<void> cambiarMovimiento(bool v) async {
    movimientoReducido.value = v;
    await _guardar((p) => p.setBool(_k('movimiento'), v));
  }

  Future<void> cambiarHaptica(bool v) async {
    haptica.value = v;
    await _guardar((p) => p.setBool(_k('haptica'), v));
  }

  /// Fija el horario, o lo quita si se pasan nulos.
  Future<void> cambiarSilencio(int? desde, int? hasta) async {
    silencioDesde.value = desde;
    silencioHasta.value = hasta;
    await _guardar((p) async {
      if (desde == null || hasta == null) {
        await p.remove(_k('silencio_desde'));
        await p.remove(_k('silencio_hasta'));
      } else {
        await p.setInt(_k('silencio_desde'), desde);
        await p.setInt(_k('silencio_hasta'), hasta);
      }
    });
  }

  String _k(String campo) => 'sigma_acc_${_usuario}_$campo';

  Future<void> _guardar(
    Future<void> Function(SharedPreferences) escribir,
  ) async {
    try {
      await escribir(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('[Accesibilidad] No se pudo guardar: $e');
    }
  }
}
