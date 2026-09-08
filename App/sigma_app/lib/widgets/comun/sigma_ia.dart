import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_radar.dart';
import 'sigma_v3.dart';

/// La tarjeta de SIGMA AI.
///
/// Es la única superficie del sistema con **velo de degradado**: 120°, morado
/// al 20 % → azul al 12 % → rosa al 10 %, encima de `card`. El resto de la app
/// usa el degradado solo en franjas de 4 u 8 px, y esa diferencia es
/// deliberada: la tarjeta de IA tiene que reconocerse antes de leerla, porque
/// lo que dice **no es un hecho registrado sino una estimación**, y quien la
/// mira necesita saberlo de un vistazo.
///
/// Por lo mismo las dos cifras van siempre juntas —probabilidad y horizonte—.
/// «Falla probable de rodamiento» sin el 78 % y sin los 14 días no es
/// accionable: no distingue entre parar la línea hoy o programarlo para la
/// próxima parada.
class SgTarjetaIa extends StatelessWidget {
  const SgTarjetaIa({
    super.key,
    required this.simbolo,
    required this.titulo,
    required this.detalle,
    this.badge,
    this.colorBadge,
    this.cifras = const [],
    this.miniatura,
    this.accion,
    this.textoAccion = 'Ver análisis',
    this.accionSecundaria,
    this.textoAccionSecundaria = 'Tomar',
  });

  final SgIconoIa simbolo;
  final String titulo;
  final String detalle;

  /// «Riesgo alto», «Recomendación», «Analizando».
  final String? badge;
  final Color? colorBadge;

  /// Los recuadros de cifra: `(valor, rótulo)`. El kit dibuja dos.
  final List<(String, String)> cifras;

  final Widget? miniatura;

  final VoidCallback? accion;
  final String textoAccion;
  final VoidCallback? accionSecundaria;
  final String textoAccionSecundaria;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SgRadius.card),
        boxShadow: sg.e2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SgRadius.card),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: sg.card)),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: SgColor.veloIa),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: accion,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /* UNA SOLA MARCA, Y QUE SE MUEVA

                         Acá iban DOS: el símbolo de estado y, al lado, el
                         distintivo de SIGMA AI. Son la misma marca dicha dos
                         veces en cuatro centímetros — se leía como si fueran
                         dos productos.

                         Queda el radar: el mismo símbolo con un barrido
                         debajo. SIGMA AI no es una pantalla que se consulta,
                         es algo que está mirando todo el rato y avisa cuando
                         encuentra algo; un logotipo quieto dice «acá hay una
                         función», un barrido dice «esto está trabajando
                         ahora», que es lo que justifica el sitio que ocupa
                         esta tarjeta en el Inicio. */
                      Row(
                        children: [
                          SgRadarIa(simbolo: simbolo, lado: 46, activo: accion != null),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('SIGMA AI',
                                    style: sora(13, 700,
                                        color: sg.acentoTexto,
                                        espaciado: 0.6)),
                                const SizedBox(height: 2),
                                Text(
                                  // Lo que está haciendo, no lo que es: la
                                  // diferencia entre una etiqueta y una señal
                                  // de vida.
                                  accion == null
                                      ? 'Sin datos que analizar'
                                      : 'Analizando tendencias',
                                  style: sora(11, 500, color: sg.tinta3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            SgBadge(badge!,
                                color: colorBadge ?? sg.rojoTexto,
                                chico: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (miniatura != null) ...[
                            miniatura!,
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titulo,
                                    style: sora(16, 600, color: sg.tinta)),
                                const SizedBox(height: 3),
                                Text(detalle,
                                    style: sora(12, 500, color: sg.tinta2),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (cifras.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 0; i < cifras.length; i++) ...[
                              if (i > 0) const SizedBox(width: 9),
                              Expanded(child: _Cifra(cifras[i])),
                            ],
                          ],
                        ),
                      ],
                      if (accion != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SgBoton(textoAccion,
                                  alto: 44, tamanoTexto: 14, onTap: accion),
                            ),
                            if (accionSecundaria != null) ...[
                              const SizedBox(width: 8),
                              _BotonVidrio(
                                  texto: textoAccionSecundaria,
                                  onTap: accionSecundaria!),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El recuadro de una cifra, sobre vidrio.
///
/// El fondo es blanco al 5 % y no un token de superficie: va **encima del
/// velo**, y una superficie opaca ahí taparía el degradado justo en el centro
/// de la tarjeta.
class _Cifra extends StatelessWidget {
  const _Cifra(this.dato);
  final (String, String) dato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: sg.esOscuro ? 0.05 : 0.55),
        borderRadius: BorderRadius.circular(SgRadius.bloque),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dato.$1,
              style: sora(20, 700, color: sg.tinta, alto: 1, tabular: true)),
          const SizedBox(height: 2),
          Text(dato.$2, style: sora(11, 500, color: sg.tinta2)),
        ],
      ),
    );
  }
}

class _BotonVidrio extends StatelessWidget {
  const _BotonVidrio({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Material(
      color: Colors.white.withValues(alpha: sg.esOscuro ? 0.08 : 0.60),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(texto, style: sora(14, 600, color: sg.tinta)),
        ),
      ),
    );
  }
}

/// El hueco de SIGMA AI cuando el servidor todavía no tiene un análisis.
///
/// **No se inventa una predicción para llenar el espacio.** La tarjeta de IA
/// existe y es fiel al kit; lo que no existe todavía es el endpoint que la
/// alimenta, y decirlo es preferible a mostrar un 78 % que nadie calculó.
class SgIaSinDatos extends StatelessWidget {
  const SgIaSinDatos({super.key, this.motivo});

  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sg.card,
        borderRadius: BorderRadius.circular(SgRadius.card),
        boxShadow: sg.e1,
      ),
      child: Row(
        children: [
          Opacity(
            opacity: 0.45,
            child: SgSimboloIa(SgIconoIa.analizando, lado: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIGMA AI sin análisis para esta planta',
                    style: sora(15, 600, color: sg.tinta2)),
                const SizedBox(height: 3),
                Text(
                  motivo ??
                      'Aparecerá acá cuando haya lecturas suficientes para '
                          'estimar una falla.',
                  style: sora(12, 500, color: sg.tinta3, alto: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
