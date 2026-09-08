import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../../providers/sincronizacion_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sesion_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';

/// 4.1 · Splash.
///
/// Layout del artboard: dos halos radiales —morado arriba a la izquierda, teal
/// abajo a la derecha—, isotipo 112, wordmark 30, la bajada en 15/500, una
/// barra de 180×4 con el degradado de marca y una línea de estado; al pie, la
/// versión.
///
/// ## Por qué esta pantalla hace trabajo de verdad
///
/// Un splash que solo espera dos segundos es una mentira cortés. Este abre la
/// base local, cuenta lo que quedó en la cola y arranca el vigilante de red,
/// y **dice qué está haciendo** —«Revisando 2 registros pendientes…»—. Si el
/// técnico cerró la app ayer con tres lecturas sin enviar, se entera acá y no
/// tres pantallas más adentro.
///
/// La línea de estado va con `Semantics(liveRegion: true)`: es el equivalente
/// del `role="status"` que el kit escribe en el HTML, y hace que el lector de
/// pantalla anuncie el cambio sin que la persona tenga que ir a buscarlo.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.haySesion});

  final bool haySesion;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _estado = 'Preparando el espacio de trabajo…';
  double _avance = 0.15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());
  }

  Future<void> _arrancar() async {
    final desde = DateTime.now();

    try {
      _decir('Abriendo los datos de este teléfono…', 0.45);
      await SyncService.instance.init();

      final enCola = OutboxService.instance.pendientes.value;
      _decir(
        enCola == 0
            ? 'Todo lo capturado ya está enviado'
            : 'Revisando $enCola ${enCola == 1 ? "registro pendiente" : "registros pendientes"}…',
        0.85,
      );
    } catch (e) {
      // Un arranque que falla **no bloquea la entrada**: la app tiene que
      // abrir aunque la base local esté corrupta o el permiso falte, porque
      // desde adentro la persona todavía puede cerrar sesión y reintentar.
      debugPrint('[Splash] Arranque incompleto: $e');
      _decir('Se entrará con lo que haya en el teléfono', 0.85);
    }

    if (widget.haySesion) {
      ref.read(sesionProvider.notifier).refrescar();
      await _prepararSesion();
    }

    // Un mínimo en pantalla: si la base abre en 40 ms, el splash aparece y
    // desaparece como un parpadeo, que se lee como un fallo gráfico.
    final resto =
        const Duration(milliseconds: 900) - DateTime.now().difference(desde);
    if (resto > Duration.zero) await Future<void>.delayed(resto);

    if (!mounted) return;
    _decir('Listo', 1);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) =>
            widget.haySesion ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (_, animacion, _, hijo) =>
            FadeTransition(opacity: animacion, child: hijo),
      ),
    );
  }

  /// Deja la sesión retomada lista para pedir datos, y **baja la sábana**.
  ///
  /// ## Por qué acá y no en la primera pantalla
  ///
  /// Al retomar una sesión guardada pasaban dos cosas y ninguna se veía:
  ///
  ///   1. Si el token no traía cliente, todo endpoint respondía 400 y el Home
  ///      se llenaba de errores con la señal perfecta.
  ///   2. **La sábana no se bajaba nunca.** `cache_datos` solo se llenaba si
  ///      alguien abría a mano la pantalla de Sincronización, así que la app
  ///      se quedaba sin datos locales y sin conexión no mostraba nada.
  ///
  /// Va en el splash porque es el único sitio por el que se pasa siempre,
  /// tanto al entrar como al retomar.
  ///
  /// **No bloquea la entrada.** La descarga se dispara y la app sigue: hacer
  /// esperar a la persona a que bajen nueve bloques para ver el Home es la
  /// diferencia entre abrir en un segundo y abrir en veinte.
  Future<void> _prepararSesion() async {
    try {
      _decir('Comprobando tu sesión…', 0.9);
      final listo = await AuthService.instance.asegurarCliente();
      if (!listo) return; // pertenece a varias empresas: elige en el Home

      // Sin `await`: baja en segundo plano mientras la app ya se usa.
      unawaited(ref.read(sincronizacionProvider.notifier).asegurar());
    } catch (e) {
      // Sin red se entra igual, con lo que haya en el teléfono.
      debugPrint('[Splash] Sesión sin preparar: $e');
    }
  }

  void _decir(String texto, double avance) {
    if (!mounted) return;
    setState(() {
      _estado = texto;
      _avance = avance;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Scaffold(
      backgroundColor: sg.fondo,
      body: Stack(
        children: [
          const SgHalo(arriba: true, abajo: true),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SgIsotipo(alto: 112),
                      const SizedBox(height: 20),
                      const SgWordmark(alto: 30),
                      const SizedBox(height: 20),
                      Text('Gestión de mantenimiento industrial',
                          style: sora(15, 500, color: sg.tinta2)),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(SgRadius.pill),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: _avance),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOut,
                            builder: (_, v, _) => Stack(
                              children: [
                                Container(height: 4, color: sg.up),
                                FractionallySizedBox(
                                  widthFactor: v.clamp(0, 1),
                                  child: Container(
                                    height: 4,
                                    decoration: const BoxDecoration(
                                        gradient: SgColor.gradiente),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(_estado,
                            textAlign: TextAlign.center,
                            style: sora(13, 500, color: sg.tinta3)),
                      ),
                    ],
                  ),
                ),
                Text('v1.0.0 (24) · Código Creativo',
                    style: sora(12, 500, color: sg.tinta3)),
                const SizedBox(height: 14),
                const SgBarraGestos(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
