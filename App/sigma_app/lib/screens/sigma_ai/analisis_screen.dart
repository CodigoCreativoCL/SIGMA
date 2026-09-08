import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';

/// El análisis de SIGMA AI — HU-175, vista 14.2.
///
/// ## Lo que esta pantalla no hace
///
/// No dice que el equipo va a fallar. Dice que una variable medida va a cruzar
/// un límite declarado **si la tendencia se mantiene**, en cuántos días y con
/// qué margen. El condicional no es prudencia retórica: el modelo no ha visto
/// ninguna falla y no puede afirmar nada sobre fallas.
///
/// ## Por qué muestra el modelo y el algoritmo
///
/// La especificación lo pide y tiene razón. Quien decide desarmar una máquina
/// por esto tiene derecho a saber que se lo dijo una regresión lineal sobre
/// trece lecturas, y no un oráculo. Un análisis que no se puede auditar se
/// obedece o se ignora; ninguna de las dos es decidir.
class AnalisisScreen extends ConsumerWidget {
  const AnalisisScreen({super.key, required this.prediccionId});

  final int prediccionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final ficha = ref.watch(prediccionProvider(prediccionId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra('Análisis', acciones: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Center(child: SgBadgeIa(alto: 20)),
        ),
      ]),
      body: EstadoAsync<PrediccionFicha>(
        valor: ficha,
        onReintentar: () => ref.invalidate(prediccionProvider(prediccionId)),
        child: (p) => ListView(
          padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 28)),
          children: [
            _Titular(p: p),
            const SizedBox(height: 12),
            if (p.razones.isNotEmpty) ...[
              _Razones(razones: p.razones),
              const SizedBox(height: 12),
            ],
            if (p.hayCurva) ...[
              _Curva(p: p),
              const SizedBox(height: 12),
            ],
            _Datos(p: p),
            const SizedBox(height: 12),
            _Modelo(p: p),
            const SizedBox(height: 16),
            _Acciones(
              p: p,
              onRevisar: (aceptar, motivo) =>
                  _revisar(context, ref, p, aceptar, motivo),
              onOrden: () => _generarOrden(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revisar(BuildContext context, WidgetRef ref, PrediccionFicha p,
      bool aceptar, String? motivo) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await SigmaRepository.instance
          .revisarPrediccion(p.pre_id, aceptar: aceptar, motivo: motivo);
      ref.invalidate(prediccionProvider(prediccionId));
      ref.invalidate(prediccionesProvider);
      mensajero.showSnackBar(SnackBar(
          content: Text(aceptar
              ? 'Reconocida. Queda registrada como aceptada.'
              : 'Descartada, con tu motivo.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _generarOrden(
      BuildContext context, WidgetRef ref, PrediccionFicha p) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final id = await SigmaRepository.instance.ordenDesdePrediccion(p.pre_id);
      ref.invalidate(prediccionProvider(prediccionId));
      ref.invalidate(prediccionesProvider);
      mensajero.showSnackBar(SnackBar(
          content: Text(id > 0
              ? 'Orden de trabajo abierta desde este análisis.'
              : 'No se pudo abrir la orden.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }
}

// ============================================================================

/// El titular: los días, que es el número directo y verificable.
///
/// Los días van primero y grandes; la probabilidad va abajo y **con su
/// significado escrito**, porque «87 %» sin decir de qué es la cifra que
/// después se repite en una reunión como si fuera probabilidad de falla.
class _Titular extends StatelessWidget {
  const _Titular({required this.p});

  final PrediccionFicha p;

  static final _fecha = DateFormat("d 'de' MMMM", 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final color = p.critica
        ? sg.rojoTexto
        : p.alta
            ? sg.ambarTexto
            : sg.acentoTexto;

    return SgCard(
      padding: const EdgeInsets.all(16),
      elevada: p.critica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.ACTIVO_FOTO != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SigmaImagen(
                      ruta: p.ACTIVO_FOTO!,
                      ancho: 56,
                      alto: 56,
                      radio: SgRadius.campo),
                ),
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
                        if (p.revisada && p.ESTADO_NOMBRE != null)
                          SgBadge(p.ESTADO_NOMBRE!,
                              color: p.descartada ? sg.tinta2 : sg.verdeTexto,
                              chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(p.ACTIVO_NOMBRE,
                        style: sora(18, 600, color: sg.tinta, alto: 1.3)),
                    if (p.donde.isNotEmpty)
                      Text(p.donde, style: sora(12, 500, color: sg.tinta3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // El titular en palabras, no en jerga.
          Text(
            p.pre_dia_restante == null
                ? 'Sin plazo estimado'
                : 'La ${(p.VARIABLE_NOMBRE ?? 'variable').toLowerCase()} llega al '
                    'límite en unos ${p.pre_dia_restante} días',
            style: sora(21, 600, color: sg.tinta, alto: 1.28),
          ),
          const SizedBox(height: 5),
          Text('si la tendencia de los últimos días se mantiene',
              style: sora(13, 500, color: sg.tinta3, alto: 1.4)),

          const SizedBox(height: 14),
          Row(
            children: [
              if (p.pre_dia_restante != null)
                _Cifra(
                  valor: '${p.pre_dia_restante}',
                  unidad: 'd',
                  rotulo: p.margenDias == null ? 'faltan' : '± ${p.margenDias} d',
                  color: color,
                ),
              if (p.VALOR_ACTUAL != null) ...[
                const SizedBox(width: 20),
                _Cifra(
                  valor: _num(p.VALOR_ACTUAL!),
                  unidad: p.UNIDAD ?? '',
                  rotulo: p.VALOR_CRITICO == null
                      ? 'hoy'
                      : 'de ${_num(p.VALOR_CRITICO!)}',
                  color: sg.tinta,
                ),
              ],
            ],
          ),

          if (p.pre_fecha_evento_estimada_utc != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 15, color: sg.tinta3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Alrededor del '
                    '${_fecha.format(p.pre_fecha_evento_estimada_utc!.toLocal())}',
                    style: sora(13, 500, color: sg.tinta2),
                  ),
                ),
              ],
            ),
          ],

          if (p.pre_probabilidad != null) ...[
            const SizedBox(height: 10),
            SgAviso(
              'El modelo le da ${(p.pre_probabilidad! * 100).round()} % de '
              'certeza a que el cruce ocurra dentro de los '
              '${p.MODELO_HORIZONTE ?? 90} días que alcanza a mirar. '
              'No es probabilidad de falla: el modelo no ha visto ninguna.',
              icono: Icons.info_outline,
              color: sg.tinta2,
              tenido: true,
            ),
          ],
        ],
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

class _Cifra extends StatelessWidget {
  const _Cifra(
      {required this.valor,
      required this.unidad,
      required this.rotulo,
      required this.color});

  final String valor;
  final String unidad;
  final String rotulo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(valor, style: sora(28, 600, color: color, tabular: true)),
            if (unidad.isNotEmpty) ...[
              const SizedBox(width: 4),
              SgUnidad(unidad),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(rotulo, style: sora(11, 500, color: sg.tinta3)),
      ],
    );
  }
}

// ============================================================================

class _Razones extends StatelessWidget {
  const _Razones({required this.razones});

  final List<PrediccionRazon> razones;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SgRotulo('POR QUÉ LO DICE'),
          const SizedBox(height: 12),
          for (final r in razones)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SgIconoCuadro(
                    r.sube ? Icons.trending_up : Icons.insights_outlined,
                    color: r.sube ? sg.ambarTexto : sg.acentoTexto,
                    lado: 30,
                    tamanoIcono: 16,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(r.pex_texto,
                        style: sora(14, 500, color: sg.tinta2, alto: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================

/// La curva de la variable medida.
///
/// Se dibuja con `CustomPaint` y no con una librería: son trece puntos y dos
/// líneas de umbral. Traer un paquete de gráficos para esto sería agregar una
/// dependencia nativa más al build de Android a cambio de nada.
class _Curva extends StatelessWidget {
  const _Curva({required this.p});

  final PrediccionFicha p;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgRotulo((p.VARIABLE_NOMBRE ?? 'VARIABLE').toUpperCase()),
              const Spacer(),
              Text('${p.serie.length} lecturas',
                  style: sora(11, 500, color: sg.tinta3)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _PintorCurva(
                puntos: p.serie,
                advertencia: p.VALOR_ADVERTENCIA,
                critico: p.VALOR_CRITICO,
                linea: sg.acentoTexto,
                ambar: sg.ambarTexto,
                rojo: sg.rojoTexto,
                rejilla: sg.div,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Leyenda(color: sg.acentoTexto, texto: 'Medido'),
              const SizedBox(width: 14),
              if (p.VALOR_ADVERTENCIA != null)
                _Leyenda(color: sg.ambarTexto, texto: 'Advertencia'),
              const SizedBox(width: 14),
              if (p.VALOR_CRITICO != null)
                _Leyenda(color: sg.rojoTexto, texto: 'Límite'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14,
              height: 2.5,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(texto, style: sora(11, 500, color: context.sg.tinta3)),
        ],
      );
}

class _PintorCurva extends CustomPainter {
  _PintorCurva({
    required this.puntos,
    required this.advertencia,
    required this.critico,
    required this.linea,
    required this.ambar,
    required this.rojo,
    required this.rejilla,
  });

  final List<PrediccionPunto> puntos;
  final double? advertencia;
  final double? critico;
  final Color linea;
  final Color ambar;
  final Color rojo;
  final Color rejilla;

  @override
  void paint(Canvas lienzo, Size medida) {
    if (puntos.length < 2) return;

    // La escala incluye el umbral crítico aunque las lecturas no lleguen: sin
    // eso el gráfico se ve alarmante siempre, porque la serie llena la altura
    // completa sea cual sea su distancia al límite.
    final valores = puntos.map((e) => e.VALOR).toList();
    var minimo = valores.reduce(min);
    var maximo = valores.reduce(max);
    if (critico != null) maximo = max(maximo, critico!);
    if (advertencia != null) minimo = min(minimo, advertencia!);

    final rango = (maximo - minimo).abs() < 0.0001 ? 1.0 : maximo - minimo;
    final holgura = rango * 0.12;
    final alto = maximo + holgura;
    final bajo = minimo - holgura;

    double y(double v) =>
        medida.height - ((v - bajo) / (alto - bajo)) * medida.height;
    double x(int i) => (i / (puntos.length - 1)) * medida.width;

    void umbral(double? v, Color c) {
      if (v == null) return;
      final trazo = Paint()
        ..color = c.withValues(alpha: 0.55)
        ..strokeWidth = 1.4;
      final yy = y(v);
      // Punteada a mano: una línea llena compite con la serie.
      for (double px = 0; px < medida.width; px += 7) {
        lienzo.drawLine(Offset(px, yy), Offset(px + 4, yy), trazo);
      }
    }

    lienzo.drawLine(Offset(0, medida.height),
        Offset(medida.width, medida.height), Paint()..color = rejilla);

    umbral(advertencia, ambar);
    umbral(critico, rojo);

    final ruta = Path()..moveTo(x(0), y(puntos[0].VALOR));
    for (var i = 1; i < puntos.length; i++) {
      ruta.lineTo(x(i), y(puntos[i].VALOR));
    }

    lienzo.drawPath(
        ruta,
        Paint()
          ..color = linea
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);

    // El último punto marcado: es el valor de hoy, el que la gente busca.
    lienzo.drawCircle(
        Offset(x(puntos.length - 1), y(puntos.last.VALOR)),
        4,
        Paint()..color = linea);
  }

  @override
  bool shouldRepaint(_PintorCurva otro) => otro.puntos != puntos;
}

// ============================================================================

class _Datos extends StatelessWidget {
  const _Datos({required this.p});

  final PrediccionFicha p;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SgRotulo('DATOS QUE USÓ'),
          const SizedBox(height: 10),
          for (final d in p.datos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.cmo_etiqueta,
                        style: sora(13, 500, color: sg.tinta2)),
                  ),
                  if (d.pcr_imputado)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: SgBadge('estimado',
                          color: sg.ambarTexto, chico: true),
                    ),
                  Text(
                    d.pcr_valor_texto ??
                        (d.pcr_valor == null ? '—' : _num(d.pcr_valor!)),
                    style: sora(13, 600, color: sg.tinta, tabular: true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _num(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    if (v.abs() < 1) return v.toStringAsFixed(3);
    return v.toStringAsFixed(2);
  }
}

// ============================================================================

/// Quién lo dijo. La especificación pide modelo y versión, y es lo mínimo:
/// un análisis que no se puede auditar se obedece o se ignora, y ninguna de
/// las dos es decidir.
class _Modelo extends StatelessWidget {
  const _Modelo({required this.p});

  final PrediccionFicha p;

  static final _fecha = DateFormat('d MMM yyyy, HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(16),
      color: sg.up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SgSimboloIa(SgIconoIa.analizando, lado: 26),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${p.MODELO_NOMBRE ?? 'Modelo'} '
                  'v${p.MODELO_VERSION ?? 1}',
                  style: sora(14, 600, color: sg.tinta),
                ),
              ),
            ],
          ),
          if (p.MODELO_ALGORITMO != null) ...[
            const SizedBox(height: 9),
            Text(p.MODELO_ALGORITMO!,
                style: sora(12, 500, color: sg.tinta2, alto: 1.5)),
          ],
          const SizedBox(height: 10),
          Text('Calculado el ${_fecha.format(p.pre_fecha_calculo_utc.toLocal())}',
              style: sora(11, 500, color: sg.tinta3)),
          if (p.REVISADA_POR != null) ...[
            const SizedBox(height: 3),
            Text('Revisada por ${p.REVISADA_POR}',
                style: sora(11, 500, color: sg.tinta3)),
          ],
          if (p.pre_motivo_descarte != null) ...[
            const SizedBox(height: 9),
            Text('«${p.pre_motivo_descarte}»',
                style: sora(12, 500, color: sg.tinta2, alto: 1.45)),
          ],
        ],
      ),
    );
  }
}

// ============================================================================

class _Acciones extends StatefulWidget {
  const _Acciones({
    required this.p,
    required this.onRevisar,
    required this.onOrden,
  });

  final PrediccionFicha p;
  final void Function(bool aceptar, String? motivo) onRevisar;
  final VoidCallback onOrden;

  @override
  State<_Acciones> createState() => _AccionesState();
}

class _AccionesState extends State<_Acciones> {
  final _motivo = TextEditingController();
  bool _descartando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final p = widget.p;

    if (p.tieneOrden) {
      return SgAviso(
        'Ya se abrió la orden ${p.ORDEN_CORRELATIVO} desde este análisis.',
        icono: Icons.assignment_turned_in_outlined,
        color: sg.verdeTexto,
        tenido: true,
      );
    }

    if (p.descartada) {
      return SgAviso(
        'Descartada. Queda en el historial con tu motivo, que es lo que '
        'después permite saber si el modelo sirve.',
        icono: Icons.do_not_disturb_on_outlined,
        color: sg.tinta2,
        tenido: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_descartando) ...[
          const SgRotuloCampo('¿Por qué la descartas?'),
          const SizedBox(height: 7),
          SgCampo(
            controlador: _motivo,
            lineas: 3,
            autoenfoque: true,
            hint: 'El reductor se cambia completo el 20…',
            onCambio: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Sin motivo no se puede aprender: quien revise si el modelo sirve '
            'necesita saber si fue un falso positivo o si la decisión fue otra.',
            style: sora(11, 500, color: sg.tinta3, alto: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SgBoton('Cancelar',
                    primario: false,
                    alto: 46,
                    tamanoTexto: 14,
                    onTap: () => setState(() => _descartando = false)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SgBoton(
                  'Descartar',
                  alto: 46,
                  tamanoTexto: 14,
                  color: sg.tinta2,
                  onTap: _motivo.text.trim().isEmpty
                      ? null
                      : () => widget.onRevisar(false, _motivo.text.trim()),
                ),
              ),
            ],
          ),
        ] else ...[
          if (p.ALERTA_ID != null)
            SgBoton('Abrir orden de trabajo',
                icono: Icons.build_outlined, onTap: widget.onOrden)
          else
            SgAviso(
              'Todavía no llega al umbral en que el modelo pide que se le crea, '
              'así que no ofrece abrir una orden. Sigue midiendo.',
              icono: Icons.schedule,
              color: sg.tinta2,
              tenido: true,
            ),
          const SizedBox(height: 9),
          Row(
            children: [
              if (!p.revisada)
                Expanded(
                  child: SgBoton('Reconocer',
                      primario: false,
                      icono: Icons.check,
                      alto: 46,
                      tamanoTexto: 14,
                      onTap: () => widget.onRevisar(true, null)),
                ),
              if (!p.revisada) const SizedBox(width: 9),
              Expanded(
                child: SgBoton('Descartar',
                    primario: false,
                    icono: Icons.close,
                    alto: 46,
                    tamanoTexto: 14,
                    onTap: () => setState(() => _descartando = true)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
