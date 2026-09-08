import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'analisis_screen.dart';

/// El panel de SIGMA AI — HU-173.
///
/// ## Las dos mitades, y por qué las dos importan
///
/// Arriba, lo que el modelo tiene que decir. Abajo, **los equipos sobre los
/// que no dijo nada, con el motivo**. La especificación pide las dos en la
/// misma pantalla y tiene razón: un panel vacío puede significar que no hay
/// equipos vigilados, que hay pero nadie los mide, o que se miden y están
/// tranquilos. Son tres situaciones muy distintas y quien mira necesita saber
/// cuál es —la segunda es un problema de operación, la tercera es una buena
/// noticia—.
class SigmaAiScreen extends ConsumerWidget {
  const SigmaAiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final predicciones = ref.watch(prediccionesProvider);
    final vigilados = ref.watch(vigiladosProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'SIGMA AI',
        tamanoTitulo: 23,
        acciones: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: SgBadgeIa(alto: 20)),
          ),
        ],
      ),
      body: EstadoAsync<List<Prediccion>>(
        valor: predicciones,
        onReintentar: () {
          ref.invalidate(prediccionesProvider);
          ref.invalidate(vigiladosProvider);
        },
        child: (lista) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(prediccionesProvider);
            ref.invalidate(vigiladosProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (lista.isEmpty)
                const _SinPredicciones()
              else ...[
                SgRotuloConAccion(
                  'LO QUE HAY QUE MIRAR',
                  accion: '${lista.length}',
                ),
                const SizedBox(height: 10),
                for (final p in lista) ...[
                  _Tarjeta(
                    p: p,
                    onAbrir: () => _abrir(context, p),
                  ),
                  const SizedBox(height: 11),
                ],
              ],
              const SizedBox(height: 10),

              // El silencio, con su motivo.
              vigilados.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (v) =>
                    v.isEmpty ? const SizedBox.shrink() : _Vigilados(lista: v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Prediccion p) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalisisScreen(prediccionId: p.pre_id),
      ));
}

// ============================================================================

class _SinPredicciones extends StatelessWidget {
  const _SinPredicciones();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SgSimboloIa(SgIconoIa.analizando, lado: 32),
              const SizedBox(width: 11),
              Expanded(
                child: Text('Nada que anunciar hoy',
                    style: sora(16, 600, color: sg.tinta)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Ninguna de las variables que se miden va camino a su límite. '
            'Más abajo está la lista de lo que se está mirando.',
            style: sora(13, 500, color: sg.tinta2, alto: 1.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================================

/// La tarjeta de una predicción.
///
/// El titular son **los días**, no el porcentaje: los días salen de resolver
/// una ecuación sobre lecturas reales y se pueden verificar; el porcentaje
/// necesita una frase entera para explicar de qué es, y una tarjeta no tiene
/// espacio para esa frase. El porcentaje vive en la ficha, con su explicación
/// al lado.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.p, required this.onAbrir});

  final Prediccion p;
  final VoidCallback onAbrir;

  static final _fecha = DateFormat('d MMM', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final color = p.critica
        ? sg.rojoTexto
        : p.alta
            ? sg.ambarTexto
            : sg.acentoTexto;

    return SgCard(
      padding: const EdgeInsets.all(14),
      elevada: p.critica,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.ACTIVO_FOTO != null)
                SigmaImagen(
                    ruta: p.ACTIVO_FOTO!,
                    ancho: 52,
                    alto: 52,
                    radio: SgRadius.campo)
              else
                SgIconoCuadro(Icons.precision_manufacturing_outlined,
                    color: color, lado: 52, tamanoIcono: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (p.SEVERIDAD_NOMBRE != null)
                          SgBadge(p.SEVERIDAD_NOMBRE!,
                              color: color, chico: true),
                        if (p.tieneOrden)
                          SgBadge('OT ${p.ORDEN_CORRELATIVO}',
                              color: sg.verdeTexto,
                              icono: Icons.assignment_turned_in_outlined,
                              chico: true),
                        if (p.revisada && !p.tieneOrden)
                          SgBadge(p.ESTADO_NOMBRE ?? 'Revisada',
                              color: sg.tinta2, chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(p.ACTIVO_NOMBRE,
                        style: sora(15, 600, color: sg.tinta, alto: 1.3)),
                    if (p.donde.isNotEmpty)
                      Text(p.donde, style: sora(11, 500, color: sg.tinta3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            p.pre_dia_restante == null
                ? '${p.VARIABLE_NOMBRE ?? 'La variable'} en alza'
                : '${p.VARIABLE_NOMBRE ?? 'La variable'} llega al límite '
                    'en ${p.pre_dia_restante} días',
            style: sora(14, 600, color: sg.tinta2, alto: 1.4),
          ),
          const SizedBox(height: 3),
          Text('si la tendencia se mantiene',
              style: sora(11, 500, color: sg.tinta3)),

          const SizedBox(height: 11),
          Row(
            children: [
              if (p.VALOR_ACTUAL != null && p.VALOR_CRITICO != null)
                Expanded(
                  child: _Barra(
                    actual: p.VALOR_ACTUAL!,
                    advertencia: p.VALOR_ADVERTENCIA,
                    critico: p.VALOR_CRITICO!,
                    unidad: p.UNIDAD ?? '',
                    color: color,
                  ),
                ),
              const SizedBox(width: 12),
              if (p.pre_fecha_evento_estimada_utc != null)
                Text(
                  _fecha.format(p.pre_fecha_evento_estimada_utc!.toLocal()),
                  style: sora(12, 600, color: color, tabular: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dónde está hoy la variable respecto de sus dos límites.
///
/// Se dibuja la escala completa desde el umbral de advertencia hasta el
/// crítico —no desde cero— porque lo que importa es cuánto falta para el
/// límite, no cuánto se lleva recorrido desde el origen.
class _Barra extends StatelessWidget {
  const _Barra({
    required this.actual,
    required this.advertencia,
    required this.critico,
    required this.unidad,
    required this.color,
  });

  final double actual;
  final double? advertencia;
  final double critico;
  final String unidad;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    // La base de la escala: el umbral de advertencia si existe, y si no un
    // 80 % del crítico —lo bastante cerca para que el avance se note—.
    final base = advertencia ?? critico * 0.8;
    final rango = (critico - base).abs() < 0.0001 ? 1.0 : critico - base;
    final avance = ((actual - base) / rango).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_num(actual),
                style: sora(17, 600, color: sg.tinta, tabular: true)),
            if (unidad.isNotEmpty) ...[
              const SizedBox(width: 3),
              SgUnidad(unidad),
            ],
            const SizedBox(width: 6),
            Text('de ${_num(critico)}',
                style: sora(11, 500, color: sg.tinta3)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: avance,
            minHeight: 5,
            backgroundColor: sg.up2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

// ============================================================================

/// Los equipos vigilados que no dijeron nada.
///
/// Agrupados por motivo, y **los que nadie mide van primero**: son los únicos
/// que exigen una acción. «Se mide y está tranquilo» es una buena noticia y va
/// al final, plegado.
class _Vigilados extends StatelessWidget {
  const _Vigilados({required this.lista});

  final List<Vigilado> lista;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final sinDatos =
        lista.where((v) => v.sinLecturas || v.faltanLecturas).toList();
    final tranquilos = lista.where((v) => v.tranquilo).toList();
    final atrasados = tranquilos.where((v) => v.ATRASADA).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sinDatos.isNotEmpty) ...[
          const SgRotulo('SIN DATOS PARA ANALIZAR'),
          const SizedBox(height: 9),
          SgCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final v in sinDatos) _Fila(v: v, alerta: true),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Sin lecturas SIGMA AI no puede decir nada de estos equipos. '
            'No es que estén bien: es que nadie los ha medido.',
            style: sora(12, 500, color: sg.tinta3, alto: 1.5),
          ),
          const SizedBox(height: 18),
        ],
        if (tranquilos.isNotEmpty) ...[
          SgRotuloConAccion(
            'SE MIDEN Y ESTÁN TRANQUILOS',
            accion: '${tranquilos.length}',
          ),
          const SizedBox(height: 9),
          SgCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final v in tranquilos) _Fila(v: v, alerta: v.ATRASADA),
              ],
            ),
          ),
          if (atrasados.isNotEmpty) ...[
            const SizedBox(height: 9),
            SgAviso(
              atrasados.length == 1
                  ? 'Uno de ellos lleva más tiempo sin medirse del que debería.'
                  : '${atrasados.length} de ellos llevan más tiempo sin '
                      'medirse del que deberían.',
              icono: Icons.schedule,
              color: sg.ambarTexto,
              tenido: true,
            ),
          ],
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.v, required this.alerta});

  final Vigilado v;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alerta ? Icons.visibility_off_outlined : Icons.check_circle_outline,
            size: 17,
            color: alerta ? sg.ambarTexto : sg.verdeTexto,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(v.ACTIVO_NOMBRE,
                          style: sora(13, 600, color: sg.tinta),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (v.VARIABLE_NOMBRE != null) ...[
                      const SizedBox(width: 6),
                      Text('· ${v.VARIABLE_NOMBRE}',
                          style: sora(11, 500, color: sg.tinta3)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(v.explicacion,
                    style: sora(11, 500, color: sg.tinta3, alto: 1.4)),
              ],
            ),
          ),
          if (v.ULTIMO_VALOR != null) ...[
            const SizedBox(width: 10),
            Text(
              '${_num(v.ULTIMO_VALOR!)}${v.UNIDAD == null ? '' : ' ${v.UNIDAD}'}',
              style: sora(12, 600, color: sg.tinta2, tabular: true),
            ),
          ],
        ],
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
