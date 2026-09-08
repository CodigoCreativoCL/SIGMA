import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// Ejecutar un checklist en terreno — HU-095.
///
/// Toma el patrón de 6.4 del kit: un ítem grande a la vez, con su captura, el
/// aviso de rango y el paso al siguiente. Los ya respondidos quedan como
/// filas compactas.
///
/// ## Un ítem a la vez, y no la lista entera
///
/// Con treinta ítems en pantalla, encontrar cuál toca es el trabajo. Acá el
/// pendiente actual ocupa la tarjeta elevada y el resto se colapsa: es la
/// misma decisión que en los pasos de la orden.
///
/// ## Se responde contra el servidor, ítem por ítem
///
/// Cada respuesta es un UPSERT por (ejecución, ítem): reenviarla actualiza en
/// vez de duplicar. Eso es lo que permite responder, corregirse y reintentar
/// sin que la pauta quede con dos versiones del mismo dato.
///
/// ## Fuera de rango se avisa, no se bloquea
///
/// El valor fuera de norma **es** el hallazgo. Bloquear su captura obligaría
/// al técnico a anotarlo en papel, que es justo lo que esta app evita. La app
/// avisa con el rango que trae la pauta; el veredicto que queda grabado lo
/// pone el servidor.
class EjecucionChecklistScreen extends ConsumerStatefulWidget {
  const EjecucionChecklistScreen({
    super.key,
    required this.ejecucionId,
    required this.versionId,
  });

  final int ejecucionId;
  final int versionId;

  @override
  ConsumerState<EjecucionChecklistScreen> createState() =>
      _EjecucionChecklistScreenState();
}

class _EjecucionChecklistScreenState
    extends ConsumerState<EjecucionChecklistScreen> {
  bool _ocupado = false;

  Future<void> _responder(
    ChecklistItem item, {
    String? texto,
    double? numero,
    bool? booleano,
    bool noAplica = false,
    String? comentario,
    bool porVoz = false,
  }) async {
    if (_ocupado) return;
    final mensajero = ScaffoldMessenger.of(context);
    // El color se toma ANTES del await: el `context` no puede cruzar un hueco
    // asincrono, y este widget puede desmontarse mientras la red responde.
    final ambar = context.sg.ambarTexto;
    final tinteAmbar = context.sg.tinte(ambar);
    setState(() => _ocupado = true);

    try {
      final r = await SigmaRepository.instance
          .responderChecklist(widget.ejecucionId, {
        'item': item.cpi_id,
        'valor_texto': texto,
        'valor_numero': numero,
        'valor_booleano': booleano,
        'no_aplica': noAplica,
        'comentario': comentario,
        'entrada_modo': porVoz ? 2 : 1,
      });

      ref.invalidate(checklistEjecucionProvider(widget.ejecucionId));

      // El servidor dice si quedó fuera de rango y por qué. Se muestra su
      // mensaje, no uno inventado por la app: la norma la escribió quien armó
      // la pauta.
      if (r['fuera_rango'] == true) {
        final msg = '${r['mensaje'] ?? ''}'.trim();
        mensajero.showSnackBar(SnackBar(
          backgroundColor: tinteAmbar,
          content: Text(
            msg.isEmpty ? 'Queda registrado como hallazgo.' : msg,
            style: sora(14, 600, color: ambar),
          ),
        ));
      }
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cerrar(ChecklistEjecucion e) async {
    final sg = context.sg;
    final control = TextEditingController();

    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Enviar la pauta?', style: sora(18, 600, color: sg.tinta)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              e.cej_item_no_conforme > 0
                  ? 'Quedan ${e.cej_item_no_conforme} respuestas fuera de norma. '
                      'Se envían igual: eso es el hallazgo.'
                  : 'Todo conforme. Una vez enviada no se puede modificar.',
              style: sora(14, 500, color: sg.tinta2, alto: 1.5),
            ),
            const SizedBox(height: 16),
            SgCampo(
              controlador: control,
              rotulo: 'Observación de la ronda',
              icono: Icons.notes,
              hint: 'Opcional',
              lineas: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Seguir', style: sora(15, 600, color: sg.tinta2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child:
                Text('Enviar', style: sora(15, 600, color: sg.primarioTexto)),
          ),
        ],
      ),
    );

    final obs = control.text.trim();
    control.dispose();
    if (si != true || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _ocupado = true);

    try {
      await SigmaRepository.instance.cerrarChecklist(widget.ejecucionId,
          observacion: obs.isEmpty ? null : obs);
      ref.invalidate(checklistPendientesProvider);
      mensajero.showSnackBar(const SnackBar(content: Text('Pauta enviada.')));
      navegador.pop(true);
    } on ApiException catch (e) {
      // «Faltan 3 items obligatorios» viene del SP y dice qué hacer.
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final ejecucion = ref.watch(checklistEjecucionProvider(widget.ejecucionId));
    final plantilla = ref.watch(checklistPlantillaProvider(widget.versionId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(ejecucion.valueOrNull?.PLANTILLA_NOMBRE ?? 'Pauta'),
      body: EstadoAsync<ChecklistEjecucion>(
        valor: ejecucion,
        onReintentar: () =>
            ref.invalidate(checklistEjecucionProvider(widget.ejecucionId)),
        child: (e) => EstadoAsync<ChecklistPlantilla>(
          valor: plantilla,
          onReintentar: () =>
              ref.invalidate(checklistPlantillaProvider(widget.versionId)),
          child: (p) => _Cuerpo(
            ejecucion: e,
            plantilla: p,
            ocupado: _ocupado,
            onResponder: _responder,
            onCerrar: () => _cerrar(e),
          ),
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.ejecucion,
    required this.plantilla,
    required this.ocupado,
    required this.onResponder,
    required this.onCerrar,
  });

  final ChecklistEjecucion ejecucion;
  final ChecklistPlantilla plantilla;
  final bool ocupado;
  final void Function(
    ChecklistItem item, {
    String? texto,
    double? numero,
    bool? booleano,
    bool noAplica,
    String? comentario,
    bool porVoz,
  }) onResponder;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final items = plantilla.items;

    // El siguiente sin responder: el que ocupa la tarjeta grande.
    ChecklistItem? actual;
    for (final i in items) {
      if (ejecucion.respuestaDe(i.cpi_id) == null) {
        actual = i;
        break;
      }
    }

    final faltanObligatorios = items
        .where((i) => i.cpi_obligatorio && ejecucion.respuestaDe(i.cpi_id) == null)
        .length;

    String? seccionPrevia;

    return Column(
      children: [
        _Progreso(ejecucion: ejecucion),
        Expanded(
          child: ListView(
            padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 8)),
            children: [
              for (final i in items) ...[
                if (i.SECCION_NOMBRE != null &&
                    i.SECCION_NOMBRE != seccionPrevia) ...[
                  if (seccionPrevia != null) const SizedBox(height: 8),
                  Builder(builder: (_) {
                    seccionPrevia = i.SECCION_NOMBRE;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SgRotulo(i.SECCION_NOMBRE!),
                    );
                  }),
                ],
                _Item(
                  item: i,
                  opciones: plantilla.opcionesDe(i.cpi_id),
                  respuesta: ejecucion.respuestaDe(i.cpi_id),
                  activo: i.cpi_id == actual?.cpi_id,
                  habilitado: ejecucion.esBorrador && !ocupado,
                  onResponder: onResponder,
                ),
                const SizedBox(height: 11),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
        if (ejecucion.esBorrador)
          SgPie(
            child: SgBoton(
              faltanObligatorios == 0
                  ? 'Enviar pauta'
                  : 'Faltan $faltanObligatorios obligatorios',
              icono: faltanObligatorios == 0 ? Icons.check : Icons.edit_note,
              cargando: ocupado,
              onTap: faltanObligatorios == 0 ? onCerrar : null,
            ),
          )
        else
          SgPie(
            child: SgBoton('Pauta enviada',
                icono: Icons.lock_outline, primario: false, onTap: null),
          ),
      ],
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.ejecucion});
  final ChecklistEjecucion ejecucion;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${ejecucion.cej_item_respondido} de ${ejecucion.cej_item_total}',
                style: sora(13, 600, color: sg.tinta2, tabular: true),
              ),
              const Spacer(),
              if (ejecucion.cej_item_no_conforme > 0)
                SgBadge(
                    '${ejecucion.cej_item_no_conforme} fuera de norma',
                    color: sg.ambarTexto, chico: true),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(SgRadius.pill),
            child: Stack(
              children: [
                Container(height: 6, color: sg.up),
                FractionallySizedBox(
                  widthFactor: ejecucion.avance,
                  child: Container(
                    height: 6,
                    decoration:
                        const BoxDecoration(gradient: SgColor.gradiente),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.item,
    required this.opciones,
    required this.respuesta,
    required this.activo,
    required this.habilitado,
    required this.onResponder,
  });

  final ChecklistItem item;
  final List<ChecklistOpcion> opciones;
  final ChecklistRespuesta? respuesta;
  final bool activo;
  final bool habilitado;
  final void Function(
    ChecklistItem item, {
    String? texto,
    double? numero,
    bool? booleano,
    bool noAplica,
    String? comentario,
    bool porVoz,
  }) onResponder;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  final _valor = TextEditingController();
  final _comentario = TextEditingController();
  bool _porVoz = false;

  @override
  void dispose() {
    _valor.dispose();
    _comentario.dispose();
    super.dispose();
  }

  double? get _numero =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final r = widget.respuesta;

    // Ya respondido: fila compacta con su marca.
    if (r != null) {
      final color = r.cer_no_aplica
          ? sg.tinta3
          : (r.cer_fuera_rango ? sg.ambarTexto : sg.verdeTexto);
      final icono = r.cer_no_aplica
          ? Icons.remove_circle_outline
          : (r.cer_fuera_rango ? Icons.warning_amber : Icons.check_circle);

      return SgCard(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        color: sg.fondo,
        sinSombra: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.cpi_texto,
                      style: sora(14, 500, color: sg.tinta2)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(_resumen(r),
                            style: sora(14, 600, color: sg.tinta)),
                      ),
                      if (r.porVoz) ...[
                        const SizedBox(width: 7),
                        Icon(Icons.mic, size: 13, color: sg.primarioTexto),
                      ],
                    ],
                  ),
                  if ((r.cer_comentario ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(r.cer_comentario!,
                        style: sora(13, 500, color: sg.tinta3, alto: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pendiente pero no es el siguiente: solo el enunciado.
    if (!widget.activo) {
      return SgCard(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.radio_button_unchecked, size: 20, color: sg.tinta3),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.item.cpi_texto,
                  style: sora(14, 500, color: sg.tinta2)),
            ),
            if (widget.item.cpi_obligatorio)
              Icon(Icons.star, size: 14, color: sg.rojoTexto),
          ],
        ),
      );
    }

    // El siguiente: abierto y con la captura que corresponde a su tipo.
    return SgCard(
      padding: const EdgeInsets.all(16),
      elevada: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.item.cpi_obligatorio)
                SgBadge('Obligatorio',
                    color: sg.rojoTexto, icono: Icons.star_outline),
              if (widget.item.hayRango)
                SgBadge(_rango(), color: sg.azulTexto, chico: true),
            ],
          ),
          const SizedBox(height: 14),
          Text(widget.item.cpi_texto,
              style: sora(19, 700, color: sg.tinta, alto: 1.35,
                  espaciado: -0.38)),
          if ((widget.item.cpi_ayuda ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.item.cpi_ayuda!,
                style: sora(13, 500, color: sg.tinta3, alto: 1.5)),
          ],
          const SizedBox(height: 16),
          _captura(sg),
          if (widget.item.cpi_permite_comentario) ...[
            const SizedBox(height: 14),
            SgCampo(
              controlador: _comentario,
              rotulo: 'Comentario',
              icono: Icons.notes,
              hint: 'Opcional',
              lineas: 2,
              conVoz: true,
              habilitado: widget.habilitado,
              onVoz: () => _dictar(_comentario),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (!widget.item.cpi_obligatorio) ...[
                _Secundario(
                  'No aplica',
                  onTap: widget.habilitado
                      ? () => widget.onResponder(widget.item,
                          noAplica: true,
                          comentario: _texto(_comentario))
                      : null,
                ),
                const SizedBox(width: 9),
              ],
              if (widget.item.esNumero || widget.item.esTexto)
                Expanded(
                  child: SgBoton('Guardar',
                      icono: Icons.check,
                      alto: 44,
                      tamanoTexto: 14,
                      onTap: widget.habilitado ? _guardar : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _captura(AppColors sg) {
    final i = widget.item;

    // SÍ/NO: las dos opciones vienen de la pauta, con su conformidad. La app
    // no decide cuál es la buena — solo la pinta cuando la sabe.
    if (i.esSiNo) {
      final si = widget.opciones.where((o) => o.cio_codigo == 'SI').firstOrNull;
      final no = widget.opciones.where((o) => o.cio_codigo == 'NO').firstOrNull;

      return Row(
        children: [
          Expanded(
            child: SgBoton('Sí',
                icono: Icons.check,
                alto: 52,
                tamanoTexto: 16,
                color: si?.cio_es_conforme == false
                    ? sg.tinte(sg.ambarTexto)
                    : null,
                colorTexto: si?.cio_es_conforme == false ? sg.ambarTexto : null,
                colorIcono: si?.cio_es_conforme == false ? sg.ambarTexto : null,
                onTap: widget.habilitado
                    ? () => widget.onResponder(widget.item,
                        booleano: true, comentario: _texto(_comentario))
                    : null),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SgBoton('No',
                icono: Icons.close,
                alto: 52,
                tamanoTexto: 16,
                primario: no?.cio_es_conforme == true,
                color: no?.cio_es_conforme == false
                    ? sg.tinte(sg.ambarTexto)
                    : null,
                colorTexto: no?.cio_es_conforme == false ? sg.ambarTexto : null,
                colorIcono: no?.cio_es_conforme == false ? sg.ambarTexto : null,
                onTap: widget.habilitado
                    ? () => widget.onResponder(widget.item,
                        booleano: false, comentario: _texto(_comentario))
                    : null),
          ),
        ],
      );
    }

    if (i.esSeleccion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in widget.opciones) ...[
            SgBoton(o.cio_texto,
                icono: o.cio_es_conforme
                    ? Icons.check_circle_outline
                    : Icons.warning_amber,
                alto: 48,
                tamanoTexto: 15,
                primario: false,
                colorIcono: o.cio_es_conforme ? sg.verdeTexto : sg.ambarTexto,
                onTap: widget.habilitado
                    ? () => widget.onResponder(widget.item,
                        texto: o.cio_codigo, comentario: _texto(_comentario))
                    : null),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    if (i.esNumero) {
      final fuera = i.fueraDeRango(_numero);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.campo),
              boxShadow: fuera
                  ? anillo(SgColor.ambar, ancho: 1.5)
                  : sg.e1,
            ),
            child: Container(
              height: 64,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                color: sg.campo,
                borderRadius: BorderRadius.circular(SgRadius.campo),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valor,
                      enabled: widget.habilitado,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                      ],
                      style: sora(28, 700,
                          color: sg.tinta, espaciado: -0.56, tabular: true),
                      cursorColor: sg.primario,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0,0',
                        hintStyle:
                            sora(28, 700, color: sg.tinta3, tabular: true),
                      ),
                    ),
                  ),
                  if (i.UNIDAD_SIMBOLO != null) ...[
                    SgUnidad(i.UNIDAD_SIMBOLO!, grande: true),
                    const SizedBox(width: 10),
                  ],
                  SgMicrofonoCampo(
                    rotulo: i.cpi_texto,
                    unidadEsperada: i.UNIDAD_SIMBOLO,
                    onValor: (v) => setState(() {
                      escribirDictado(_valor, v);
                      _porVoz = true;
                    }),
                  ),
                ],
              ),
            ),
          ),
          // El aviso es de la app y solo orienta: el veredicto que se guarda lo
          // pone el servidor con la validación de la pauta.
          if (fuera) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 17, color: sg.ambarTexto),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i.civ_mensaje ?? 'Fuera del rango esperado. ${_rango()}',
                    style: sora(13, 500, color: sg.ambarTexto, alto: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Texto y todo lo demás.
    return SgCampo(
      controlador: _valor,
      icono: Icons.edit_outlined,
      hint: 'Escribe la respuesta',
      lineas: i.TIPO_ID == 2 ? 3 : 1,
      conVoz: true,
      habilitado: widget.habilitado,
      onVoz: () => _dictar(_valor),
    );
  }

  Future<void> _dictar(TextEditingController destino) async {
    final campos = await mostrarPanelVoz(
      context,
      titulo: widget.item.cpi_pregunta_voz ?? widget.item.cpi_texto,
      interpretar: (t) => [
        CampoDictado(
            clave: 'texto',
            rotulo: widget.item.cpi_texto,
            valor: InterpreteVoz.normalizar(t)),
      ],
    );
    if (campos == null || campos.isEmpty) return;
    setState(() {
      escribirDictado(destino, campos.first.valor);
      _porVoz = true;
    });
  }

  void _guardar() {
    if (widget.item.esNumero) {
      final n = _numero;
      if (n == null) return;
      widget.onResponder(widget.item,
          numero: n, comentario: _texto(_comentario), porVoz: _porVoz);
      return;
    }
    final t = _valor.text.trim();
    if (t.isEmpty) return;
    widget.onResponder(widget.item,
        texto: t, comentario: _texto(_comentario), porVoz: _porVoz);
  }

  String? _texto(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  String _rango() {
    final i = widget.item;
    final u = i.UNIDAD_SIMBOLO == null ? '' : ' ${i.UNIDAD_SIMBOLO}';
    if (i.civ_valor_minimo != null && i.civ_valor_maximo != null) {
      return 'Esperado ${_n(i.civ_valor_minimo!)} – ${_n(i.civ_valor_maximo!)}$u';
    }
    if (i.civ_valor_maximo != null) return 'Máximo ${_n(i.civ_valor_maximo!)}$u';
    return 'Mínimo ${_n(i.civ_valor_minimo!)}$u';
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toString().replaceAll('.', ',');

  String _resumen(ChecklistRespuesta r) {
    if (r.cer_no_aplica) return 'No aplica';
    if (r.cer_valor_booleano != null) {
      return r.cer_valor_booleano! ? 'Sí' : 'No';
    }
    if (r.cer_valor_numero != null) {
      final u = widget.item.UNIDAD_SIMBOLO == null
          ? ''
          : ' ${widget.item.UNIDAD_SIMBOLO}';
      return '${_n(r.cer_valor_numero!)}$u';
    }
    // Una selección se guarda por código; se muestra su texto.
    final o = widget.opciones
        .where((x) => x.cio_codigo == r.cer_valor_texto)
        .firstOrNull;
    return o?.cio_texto ?? (r.cer_valor_texto ?? '—');
  }
}

class _Secundario extends StatelessWidget {
  const _Secundario(this.texto, {this.onTap});

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Material(
      color: sg.up,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(texto, style: sora(14, 600, color: sg.tinta2)),
        ),
      ),
    );
  }
}
