import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'hojas_recursos.dart';

/// 6.5–6.6 · Recursos de la orden — HU-115 y HU-116.
///
/// Layout del artboard: rótulo MANO DE OBRA con el total a la derecha en
/// 14/700 tabular; tarjetas de 22 con avatar 42, nombre 15/600, origen 12/500
/// y la duración alineada a la derecha con su rango horario debajo. Debajo,
/// el mismo patrón para repuestos.
///
/// ## Por qué esto no es opcional
///
/// Una OT sin recursos dice **qué** se hizo pero no **cuánto costó**. Sin mano
/// de obra no hay MTTR ni carga por persona; sin consumo no hay costo de
/// mantenimiento por activo, que es la cifra con la que se decide reparar o
/// reemplazar un equipo.
class RecursosOrdenVista extends ConsumerWidget {
  const RecursosOrdenVista({
    super.key,
    required this.ordenId,
    required this.puedeEditar,
  });

  final int ordenId;

  /// Solo con la orden en ejecución y siendo del equipo. Lo vuelve a
  /// comprobar el servidor: esto solo evita ofrecer un botón que va a fallar.
  final bool puedeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final recursos = ref.watch(recursosOrdenProvider(ordenId));

    return EstadoAsync<RecursosOrden>(
      valor: recursos,
      onReintentar: () => ref.invalidate(recursosOrdenProvider(ordenId)),
      child: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SgRotuloConAccion(
            'Mano de obra',
            accion: _horas(r.minutosTotales),
          ),
          const SizedBox(height: 10),
          if (r.manoObra.isEmpty)
            SgAviso(
              'Todavía no hay tramos registrados. Sin esto no se puede saber '
              'cuánto tomó el trabajo.',
              icono: Icons.timer_outlined,
              color: sg.tinta2,
            )
          else
            for (final m in r.manoObra) ...[
              _FilaManoObra(tramo: m),
              const SizedBox(height: 11),
            ],
          if (puedeEditar) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: SgBoton('Registrar mi tiempo',
                      icono: Icons.more_time,
                      primario: false,
                      alto: 44,
                      tamanoTexto: 14,
                      onTap: () => _registrarTiempo(context, ref)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: SgBoton('Sumar compañero',
                      icono: Icons.person_add_alt,
                      primario: false,
                      alto: 44,
                      tamanoTexto: 14,
                      onTap: () => _sumarCompanero(context, ref)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 22),
          SgRotuloConAccion(
            'Repuestos',
            accion: '${r.repuestos.length}',
          ),
          const SizedBox(height: 10),
          if (r.repuestos.isEmpty)
            SgAviso(
              'No se ha consumido ningún repuesto en esta orden.',
              icono: Icons.inventory_2_outlined,
              color: sg.tinta2,
            )
          else
            for (final p in r.repuestos) ...[
              _FilaRepuesto(linea: p),
              const SizedBox(height: 11),
            ],
          if (puedeEditar) ...[
            const SizedBox(height: 3),
            SgBoton('Consumir un repuesto',
                icono: Icons.inventory_2_outlined,
                primario: false,
                alto: 44,
                tamanoTexto: 14,
                onTap: () => _consumirRepuesto(context, ref)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _horas(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (minutos == 0) return '—';
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m';
  }

  /// El registro del tramo.
  ///
  /// Sumar a un compañero que participó — HU-115.
  ///
  /// ## Por qué el tramo es de OTRA persona
  ///
  /// Un motor pesado no lo saca uno solo. Hoy el que registra el trabajo es el
  /// único que aparece, así que la orden termina firmada por uno aunque la
  /// hicieron dos, y las horas de la planta salen a la mitad de lo que fueron.
  ///
  /// `@USUARIO_TRAMO` ya existía en el SP: era la pieza que faltaba usar.
  ///
  /// ## Por qué no reasigna la orden
  ///
  /// El responsable no cambia: quien se suma **participa**. Reasignarla le
  /// quitaría el trabajo a quien lo pidió.
  Future<void> _sumarCompanero(BuildContext context, WidgetRef ref) async {
    final instalacion = ref.read(instalacionProvider);
    final mensajero = ScaffoldMessenger.of(context);

    if (instalacion == null) {
      mensajero.showSnackBar(const SnackBar(
          content: Text('Elige una planta antes de sumar a alguien.')));
      return;
    }

    final elegido = await showModalBottomSheet<TramoCompanero>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaCompanero(instalacionId: instalacion.cin_id),
    );

    if (elegido == null || !context.mounted) return;

    try {
      await SigmaRepository.instance.registrarManoObra(ordenId, {
        'fecha_inicio_utc': elegido.desde.toUtc().toIso8601String(),
        'fecha_fin_utc': elegido.hasta.toUtc().toIso8601String(),
        'usuario_tramo': elegido.quien.usu_id,
        'observacion': 'Participó en el trabajo.',
      });
      ref.invalidate(recursosOrdenProvider(ordenId));
      mensajero.showSnackBar(SnackBar(
          content: Text('${elegido.quien.NOMBRE} quedó como participante.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  /// Consumir un repuesto contra la orden — HU-116.
  ///
  /// **Mueve el inventario**: el SP hace las dos escrituras en una
  /// transacción, así que la bodega y la orden no pueden discrepar. Por eso no
  /// se encola: un consumo que sale de la cola horas después descontaría un
  /// saldo que ya cambió, y el técnico que fue a buscar la pieza se encuentra
  /// con que no está.
  Future<void> _consumirRepuesto(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);

    final elegido = await showModalBottomSheet<ConsumoRepuesto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HojaRepuesto(),
    );

    if (elegido == null || !context.mounted) return;

    try {
      await SigmaRepository.instance.moverRepuestoOrden(ordenId, {
        'repuesto': elegido.repuesto,
        'bodega': elegido.bodega,
        'cantidad': elegido.cantidad,
        'es_devolucion': false,
      });
      ref.invalidate(recursosOrdenProvider(ordenId));
      mensajero.showSnackBar(
          SnackBar(content: Text('${elegido.nombre} consumido.')));
    } on ApiException catch (e) {
      // «No hay saldo suficiente» lo dice el SP y es accionable.
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  /// Se propone **desde el inicio real de la orden hasta ahora**, que es el
  /// caso normal: el técnico registra al terminar. Escribir dos horas a mano
  /// con guantes es donde más se falla.
  Future<void> _registrarTiempo(BuildContext context, WidgetRef ref) async {
    final ahora = DateTime.now();
    var inicio = ahora.subtract(const Duration(hours: 1));
    var fin = ahora;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _HojaTiempo(
        inicio: inicio,
        fin: fin,
        onCambio: (i, f) {
          inicio = i;
          fin = f;
        },
      ),
    );

    if (ok != true || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await SigmaRepository.instance.registrarManoObra(ordenId, {
        'fecha_inicio_utc': inicio.toUtc().toIso8601String(),
        'fecha_fin_utc': fin.toUtc().toIso8601String(),
      });
      ref.invalidate(recursosOrdenProvider(ordenId));
      ref.invalidate(ordenTrabajoProvider(ordenId));
      mensajero.showSnackBar(const SnackBar(content: Text('Tiempo registrado.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }
}

class _FilaManoObra extends StatelessWidget {
  const _FilaManoObra({required this.tramo});
  final ManoObra tramo;

  static final _hora = DateFormat('HH:mm');

  String get _iniciales {
    final n = (tramo.USUARIO_NOMBRE ?? '').trim();
    if (n.isEmpty) return '?';
    final partes = n.split(RegExp(r'\s+'));
    return partes.length == 1
        ? partes.first[0].toUpperCase()
        : (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final fin = tramo.omo_fecha_fin_utc?.toLocal();
    final ini = tramo.omo_fecha_inicio_utc.toLocal();

    return SgCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SgAvatar(_iniciales, id: tramo.omo_id, lado: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tramo.USUARIO_NOMBRE ?? tramo.PROVEEDOR_NOMBRE ?? 'Sin nombre',
                    style: sora(15, 600, color: sg.tinta),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        [
                          tramo.externa ? 'Externa' : 'Interna',
                          if ((tramo.ESPECIALIDAD_NOMBRE ?? '').isNotEmpty)
                            tramo.ESPECIALIDAD_NOMBRE!,
                        ].join(' · '),
                        style: sora(12, 500, color: sg.tinta3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tramo.omo_es_hora_extra) ...[
                      const SizedBox(width: 6),
                      SgBadge('Extra', color: sg.ambarTexto, chico: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tramo.duracion,
                  style: sora(16, 700, color: sg.tinta, alto: 1, tabular: true)),
              const SizedBox(height: 3),
              Text(
                fin == null
                    ? 'desde ${_hora.format(ini)}'
                    : '${_hora.format(ini)} – ${_hora.format(fin)}',
                style: sora(12, 500, color: sg.tinta3, tabular: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaRepuesto extends StatelessWidget {
  const _FilaRepuesto({required this.linea});
  final OrdenTrabajoRepuesto linea;

  static final _n = NumberFormat.decimalPattern('es_CL');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final devuelto = (linea.ore_cantidad_devuelta ?? 0) > 0;

    return SgCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SgIconoCuadro(Icons.inventory_2_outlined,
              color: sg.acentoTexto, lado: 42, tamanoIcono: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(linea.REPUESTO_NOMBRE,
                    style: sora(15, 600, color: sg.tinta),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(linea.REPUESTO_CODIGO,
                        style: sora(12, 600, color: sg.acentoTexto)),
                    if ((linea.LOTE_CODIGO ?? '').isNotEmpty) ...[
                      Text(' · ', style: sora(12, 500, color: sg.tinta3)),
                      Flexible(
                        child: Text('Lote ${linea.LOTE_CODIGO}',
                            style: sora(12, 500, color: sg.tinta3),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                // Lo devuelto se muestra aparte: el neto solo no explica por
                // qué el técnico sacó tres del estante.
                if (devuelto) ...[
                  const SizedBox(height: 6),
                  SgBadge(
                      '${_n.format(linea.ore_cantidad_devuelta)} devuelto'
                      '${(linea.ore_cantidad_devuelta ?? 0) == 1 ? "" : "s"}',
                      color: sg.azulTexto,
                      icono: Icons.undo,
                      chico: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SgCifra(_n.format(linea.neto),
              unidad: linea.UNIDAD_SIMBOLO, tamano: 18),
        ],
      ),
    );
  }
}

/// La hoja para registrar un tramo de tiempo.
class _HojaTiempo extends StatefulWidget {
  const _HojaTiempo({
    required this.inicio,
    required this.fin,
    required this.onCambio,
  });

  final DateTime inicio;
  final DateTime fin;
  final void Function(DateTime inicio, DateTime fin) onCambio;

  @override
  State<_HojaTiempo> createState() => _HojaTiempoState();
}

class _HojaTiempoState extends State<_HojaTiempo> {
  late DateTime _inicio = widget.inicio;
  late DateTime _fin = widget.fin;

  static final _hora = DateFormat('HH:mm');

  int get _minutos => _fin.difference(_inicio).inMinutes;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final valido = _minutos > 0 && _minutos <= 1440;

    return Container(
      decoration: BoxDecoration(
        color: sg.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sg.indicador,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Mi tiempo en esta orden',
                  style: sora(20, 600, color: sg.tinta)),
              const SizedBox(height: 6),
              Text(
                'El tramo queda registrado como un hecho. Si te equivocas, se '
                'corrige agregando otro, no editando este.',
                style: sora(13, 500, color: sg.tinta3, alto: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Reloj(
                      rotulo: 'Desde',
                      valor: _hora.format(_inicio),
                      onTap: () => _elegir(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Reloj(
                      rotulo: 'Hasta',
                      valor: _hora.format(_fin),
                      onTap: () => _elegir(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: valido ? sg.up : sg.tinte(sg.rojoTexto),
                  borderRadius: BorderRadius.circular(SgRadius.bloque),
                ),
                child: Row(
                  children: [
                    Icon(valido ? Icons.timer_outlined : Icons.error_outline,
                        size: 19,
                        color: valido ? sg.acentoTexto : sg.rojoTexto),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _minutos <= 0
                            ? 'El término tiene que ser posterior al inicio.'
                            : _minutos > 1440
                                ? 'El tramo supera las 24 horas. Revisa las horas.'
                                : 'Se registrarán ${_texto(_minutos)}.',
                        style: sora(13, 600,
                            color: valido ? sg.tinta : sg.rojoTexto),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SgBoton('Registrar',
                  icono: Icons.check,
                  onTap: valido ? () => Navigator.pop(context, true) : null),
              const SgBarraGestos(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegir(bool esInicio) async {
    final base = esInicio ? _inicio : _fin;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;

    setState(() {
      final nuevo =
          DateTime(base.year, base.month, base.day, t.hour, t.minute);
      if (esInicio) {
        _inicio = nuevo;
      } else {
        _fin = nuevo;
      }
      widget.onCambio(_inicio, _fin);
    });
  }

  static String _texto(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '$m minutos';
    return m == 0 ? '$h ${h == 1 ? "hora" : "horas"}' : '$h h $m min';
  }
}

class _Reloj extends StatelessWidget {
  const _Reloj({
    required this.rotulo,
    required this.valor,
    required this.onTap,
  });

  final String rotulo;
  final String valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SgRotuloCampo(rotulo),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SgRadius.campo),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.campo),
              boxShadow: sg.e1,
            ),
            child: Container(
              height: SgMedida.campo,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sg.campo,
                borderRadius: BorderRadius.circular(SgRadius.campo),
              ),
              child: Text(valor,
                  style: sora(22, 700, color: sg.tinta, tabular: true)),
            ),
          ),
        ),
      ],
    );
  }
}
