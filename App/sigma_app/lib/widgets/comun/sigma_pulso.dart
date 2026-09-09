import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve un icono para que **responda** al tocarlo: rebota y vibra.
///
/// ## Por qué hace falta
///
/// Marcar un favorito o compartir un trabajo cambian algo que la persona **no
/// ve confirmado en el momento**: la estrella se rellena y ya está, y compartir
/// abre una hoja que tapa la pantalla. En terreno, con guantes y a contraluz,
/// un cambio de icono de veinte píxeles se pierde, y quien no está seguro de
/// haber tocado vuelve a tocar. En un favorito eso lo desmarca; en compartir
/// abre la hoja dos veces.
///
/// Un rebote corto resuelve eso mejor que cualquier mensaje: dice «te leí»
/// antes de que termine la petición, y no ocupa sitio en pantalla.
///
/// ## Por qué también vibra
///
/// Porque el guante tapa la vista pero no el tacto. `HapticFeedback.selectionClick`
/// es el toque más corto que existe —el de un selector—: se nota y no molesta
/// al décimo uso, que es lo que descarta una vibración larga.
///
/// ## Por qué encoge y no crece
///
/// Encoger se lee como «se hundió el botón», que es lo que pasa físicamente al
/// apretar algo. Crecer se lee como un globo y llama más la atención de lo que
/// el gesto merece.
class SgPulso extends StatefulWidget {
  const SgPulso({
    super.key,
    required this.child,
    this.onTap,
    this.escala = 0.82,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Cuánto encoge al apretar. 0.82 se nota sin parecer que algo se rompió.
  final double escala;

  @override
  State<SgPulso> createState() => _SgPulsoState();
}

class _SgPulsoState extends State<SgPulso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // 110 ms al hundir y 220 al soltar: el rebote de vuelta es más lento
    // porque es el que se ve, y a la misma velocidad se percibe como un
    // parpadeo en vez de como un rebote.
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 220),
    lowerBound: 0,
    upperBound: 1,
  );

  late final Animation<double> _escala =
      Tween<double>(begin: 1, end: widget.escala).animate(
        CurvedAnimation(
          parent: _c,
          curve: Curves.easeOut,
          reverseCurve: Curves.elasticOut,
        ),
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tocar() async {
    if (widget.onTap == null) return;

    // La vibración va ANTES de la petición: confirma el gesto, no el
    // resultado. Si esperara a la respuesta llegaría medio segundo tarde y ya
    // no serviría de acuse.
    unawaited(HapticFeedback.selectionClick());

    await _c.forward();
    if (!mounted) return;
    unawaited(_c.reverse());

    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tocar,
      child: ScaleTransition(scale: _escala, child: widget.child),
    );
  }
}
