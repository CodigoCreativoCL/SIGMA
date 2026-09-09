import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sincronizacion_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../theme/app_theme.dart';
import 'sigma_cargando.dart';

/// Envuelve la app y **recarga al volver del segundo plano**.
///
/// ## Qué problema resuelve
///
/// Android mata las apps en segundo plano sin avisar. Al volver, SIGMA se
/// reconstruía con la sesión —que sí se persiste— pero con los datos de hace
/// horas y, hasta esta sesión, sin la planta elegida. La persona veía listas
/// viejas o vacías y no tenía cómo saber que estaba mirando algo caducado.
///
/// Peor en una planta: se retoma la app justo al recuperar señal después de un
/// rato en una nave sin cobertura, que es exactamente cuando hay más cosas
/// nuevas que bajar.
///
/// ## Por qué se tapa la pantalla mientras carga
///
/// Porque durante esos segundos lo que se ve **no es cierto todavía**. Dejar la
/// lista vieja a la vista invita a tocarla, y tocar una orden que ya se cerró
/// desde la web es el tipo de error que después nadie sabe explicar. La capa
/// dice «espera, estoy poniéndome al día» y desaparece sola.
///
/// ## Por qué no en cada `resumed`
///
/// `asegurar()` ya tiene su propio freno de tres minutos: pasar de SIGMA a la
/// cámara y volver no dispara nada. La capa solo aparece cuando de verdad hay
/// una descarga, y para eso se mira `corriendo`, no el ciclo de vida.
class SgAlRetomar extends ConsumerStatefulWidget {
  const SgAlRetomar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SgAlRetomar> createState() => _SgAlRetomarState();
}

class _SgAlRetomarState extends ConsumerState<SgAlRetomar>
    with WidgetsBindingObserver {
  /// Solo se tapa la pantalla si la descarga la disparó el retomar. Una
  /// sincronización que la persona pidió a mano tiene su propia pantalla y
  /// taparla encima sería absurdo.
  bool _porRetomar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) return;

    // Sin sesión no hay nada que bajar: la pantalla de login no necesita
    // ponerse al día.
    if (!ref.read(sesionProvider).autenticado) return;

    _alVolver();
  }

  Future<void> _alVolver() async {
    final sincro = ref.read(sincronizacionProvider.notifier);

    setState(() => _porRetomar = true);
    try {
      await sincro.asegurar();
    } finally {
      if (mounted) setState(() => _porRetomar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final corriendo = ref.watch(sincronizacionProvider).corriendo;
    final tapar = _porRetomar && corriendo;

    return Stack(
      children: [
        widget.child,
        if (tapar)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 180),
              child: ColoredBox(
                // Opaco, no traslúcido: si se transparenta se sigue leyendo la
                // lista vieja debajo, que es justo lo que hay que dejar de
                // mostrar.
                color: sg.fondo,
                child: Center(
                  child: SgCargando(
                    mensaje: 'Poniendo al día los datos de la planta…',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
