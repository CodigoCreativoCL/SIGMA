import 'package:flutter/material.dart';

import '../../services/cronometro_service.dart';
import '../../theme/app_theme.dart';
import 'sigma_v3.dart';

/// El cronómetro de una gestión en curso.
///
/// ## Qué muestra y por qué así
///
/// La cifra va en **tabular** y grande: se mira de reojo, con el teléfono en
/// una mano y una llave en la otra. El punto que late dice que corre —un
/// número quieto y uno corriendo se ven igual en una foto de un segundo—, y
/// al pausar se apaga en vez de cambiar de color: pausado no es un error.
///
/// ## Por qué el botón dice «Pausar» y no «Detener»
///
/// Detener suena a terminar, y terminar es cerrar la gestión. Lo que hace este
/// botón es dejar de contar mientras se espera una pieza o un permiso: el
/// trabajo sigue abierto y el tiempo se retoma donde iba.
class SgCronometro extends StatelessWidget {
  const SgCronometro({
    super.key,
    required this.entidad,
    required this.entidadId,
    this.compacto = false,
  });

  /// TAREA · CHECKLIST · ORDEN
  final String entidad;
  final int entidadId;

  /// En una lista o una barra: solo la cifra, sin los botones.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final servicio = CronometroService.instance;

    return ValueListenableBuilder<Cronometro>(
      valueListenable: servicio.estado(entidad, entidadId),
      builder: (_, c, _) {
        if (compacto) {
          if (!c.empezado) return const SizedBox.shrink();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pulso(activo: c.corriendo),
              const SizedBox(width: 6),
              Text(c.texto,
                  style: sora(13, 600, color: sg.tinta2, tabular: true)),
            ],
          );
        }

        return SgCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Pulso(activo: c.corriendo),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.corriendo ? 'En curso' : 'En pausa',
                      style: sora(12, 600,
                          color: c.corriendo ? sg.acentoTexto : sg.tinta3),
                    ),
                    const SizedBox(height: 2),
                    Text(c.texto,
                        style: sora(26, 700,
                            color: sg.tinta, tabular: true, espaciado: -0.5)),
                    if (c.tramos > 1) ...[
                      const SizedBox(height: 2),
                      // Un trabajo interrumpido cuatro veces cuenta una
                      // historia distinta de uno hecho de corrido.
                      Text('${c.tramos} tramos',
                          style: sora(11, 500, color: sg.tinta3)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 132,
                child: SgBoton(
                  c.corriendo ? 'Pausar' : 'Continuar',
                  icono: c.corriendo ? Icons.pause : Icons.play_arrow,
                  alto: 44,
                  tamanoTexto: 14,
                  primario: !c.corriendo,
                  color: c.corriendo ? sg.up : null,
                  colorTexto: c.corriendo ? sg.tinta : null,
                  colorIcono: c.corriendo ? sg.tinta : null,
                  onTap: () => c.corriendo
                      ? servicio.pausar(entidad, entidadId)
                      : servicio.iniciar(entidad, entidadId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// El punto que late mientras corre.
class _Pulso extends StatefulWidget {
  const _Pulso({required this.activo});
  final bool activo;

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Pulso anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activo == anterior.activo) return;
    // Detener la animación al pausar no es un adorno: una animación en bucle
    // impide que Flutter deje la pantalla quieta y gasta batería en un turno
    // de ocho horas.
    widget.activo ? _c.repeat(reverse: true) : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final color = widget.activo ? sg.acentoTexto : sg.tinta3;

    return FadeTransition(
      opacity: widget.activo
          ? Tween<double>(begin: 0.35, end: 1).animate(_c)
          : const AlwaysStoppedAnimation(0.5),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
