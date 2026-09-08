import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// Dibuja los tres estados que puede tener cualquier dato que venga de la API,
/// para que las diez pantallas los resuelvan igual.
///
/// ## Por qué esqueletos y no un spinner
///
/// Una recarga que borra la pantalla y muestra un spinner deja al técnico sin
/// los datos que ya tenía —que probablemente le servían— por diez segundos de
/// red mala. Con `valueOrNull` los datos anteriores siguen visibles.
///
/// ## Por qué el error no siempre es rojo
///
/// **Sin conexión no es un error.** La app es offline-first: trabajar sin
/// señal es el caso normal en una planta. Pintarlo de rojo entrena al técnico
/// a ignorar el rojo, y el día que aparezca uno de verdad tampoco lo va a
/// mirar. Por eso un fallo de red se muestra en neutro y solo un error del
/// servidor va en rojo.
class EstadoAsync<T> extends StatelessWidget {
  const EstadoAsync({
    super.key,
    required this.valor,
    required this.child,
    this.vacio,
    this.estaVacio,
    this.alturaCarga = 180,
    this.onReintentar,
  });

  final AsyncValue<T> valor;
  final Widget Function(T datos) child;

  /// Qué mostrar cuando la consulta responde pero no trae nada.
  final Widget? vacio;
  final bool Function(T datos)? estaVacio;

  final double alturaCarga;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      loading: () => _Cargando(alto: alturaCarga),
      error: (e, _) => _Error(e, onReintentar: onReintentar),
      data: (datos) {
        if (vacio != null && (estaVacio?.call(datos) ?? false)) return vacio!;
        return child(datos);
      },
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando({required this.alto});
  final double alto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: alto / 3.4,
            decoration: BoxDecoration(
              color: sg.card,
              borderRadius: BorderRadius.circular(SgRadius.card),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.e, {this.onReintentar});
  final Object e;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final api = e is ApiException ? e as ApiException : null;
    final esRed = api?.esDeRed ?? false;
    final sinPermiso = api?.sinPermiso ?? false;

    final color = esRed ? sg.tinta2 : SgColor.rojo;
    final icono = esRed
        ? Icons.cloud_off_outlined
        : (sinPermiso ? Icons.lock_outline : Icons.error_outline);

    // El mensaje del servidor va tal cual: está redactado para leerse y dice
    // qué hacer. Reescribirlo acá sería perder esa información.
    final mensaje = api?.mensaje ?? 'No se pudieron cargar los datos.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: sg.card,
        borderRadius: BorderRadius.circular(SgRadius.card),
      ),
      child: Column(
        children: [
          Icon(icono, size: 30, color: color),
          const SizedBox(height: 12),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: sora(14, 500, color: color, alto: 1.5)),
          if (esRed) ...[
            const SizedBox(height: 6),
            Text('Se muestra lo último que se descargó.',
                textAlign: TextAlign.center,
                style: sora(12.5, 400, color: sg.tinta3)),
          ],
          // Ante un 403 no se ofrece reintentar: el permiso no va a aparecer
          // solo, y un botón que siempre falla es un botón roto.
          if (onReintentar != null && !sinPermiso) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Reintentar', style: sora(14, 600)),
            ),
          ],
        ],
      ),
    );
  }
}

/// El estado vacío: ícono, frase y —cuando aplica— la acción que lo llenaría.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.titulo,
    this.detalle,
    this.icono = Icons.inbox_outlined,
    this.accion,
  });

  final String titulo;
  final String? detalle;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: sg.card,
        borderRadius: BorderRadius.circular(SgRadius.card),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: sg.up,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 28, color: sg.tinta3),
          ),
          const SizedBox(height: 16),
          Text(titulo,
              textAlign: TextAlign.center,
              style: sora(16, 700, color: sg.tinta)),
          if (detalle != null) ...[
            const SizedBox(height: 8),
            Text(detalle!,
                textAlign: TextAlign.center,
                style: sora(13.5, 400, color: sg.tinta2, alto: 1.5)),
          ],
          if (accion != null) ...[const SizedBox(height: 20), accion!],
        ],
      ),
    );
  }
}
