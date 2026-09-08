import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import '../ordenes/hojas_recursos.dart';

/// Ajustar la existencia de un repuesto — HU-057.
///
/// ## Se cuenta, no se calcula
///
/// El bodeguero cuenta en el pasillo y lo que sabe es **cuántos hay**, no
/// cuántos sobran respecto del sistema. Pedirle «+3» le obliga a hacer una
/// resta mental contra un número que tiene que ir a buscar, y esa resta es
/// donde se equivoca. Aquí escribe lo que contó y la app deduce el
/// movimiento: positivo si encontró de más, negativo si faltaba.
///
/// ## El motivo es obligatorio
///
/// Un ajuste sin explicación es un saldo que cambió sin que nadie pueda decir
/// por qué, y eso es exactamente lo que un inventario auditado no puede tener.
/// La diferencia se puede ver en el movimiento; la razón, no.
///
/// ## Se encola
///
/// La bodega de una planta suele ser el peor punto de señal del sitio: nave
/// metálica, sin ventanas. El `uuid` nace al abrir la hoja, e
/// `INS_INVENTARIO_MOVIMIENTO` corta por él antes de tocar el saldo, así que
/// un reintento no descuadra lo que se acaba de cuadrar.
class HojaAjuste extends ConsumerStatefulWidget {
  const HojaAjuste({super.key, required this.saldo});

  final InventarioSaldo saldo;

  /// Abre la hoja. Devuelve `true` si el ajuste quedó encolado.
  static Future<bool> abrir(BuildContext context, InventarioSaldo saldo) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaAjuste(saldo: saldo),
    );
    return r ?? false;
  }

  @override
  ConsumerState<HojaAjuste> createState() => _HojaAjusteState();
}

class _HojaAjusteState extends ConsumerState<HojaAjuste> {
  /// Los tipos de movimiento, como los nombra `InventarioMovimientosController`.
  static const int _ajustePositivo = 4;
  static const int _ajusteNegativo = 5;

  static final _n = NumberFormat.decimalPattern('es_CL');

  final _contado = TextEditingController();
  final _motivo = TextEditingController();

  final String _uuid = OutboxService.nuevoUuid();

  bool _guardando = false;

  @override
  void dispose() {
    _contado.dispose();
    _motivo.dispose();
    super.dispose();
  }

  double get _sistema => widget.saldo.CANTIDAD_DISPONIBLE;

  /// Lo contado, o `null` mientras no sea un número. Se acepta la coma: en un
  /// teclado numérico de Android el separador decimal es coma, y quien escribe
  /// «2,5 litros» no tiene por qué saber que el sistema quiere punto.
  double? get _cuenta {
    final t = _contado.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double? get _diferencia {
    final c = _cuenta;
    return c == null ? null : c - _sistema;
  }

  bool get _completo {
    final d = _diferencia;
    return d != null && d != 0 && _motivo.text.trim().isNotEmpty && !_guardando;
  }

  String _fmt(double v) => _n.format(v);

  Future<void> _guardar() async {
    final d = _diferencia;
    if (d == null || d == 0 || !_completo) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);

    try {
      /* El SP recibe SIEMPRE una cantidad positiva; el signo lo lleva el tipo
         de movimiento. Mandar -3 con tipo AJUSTE_NEGATIVO restaria dos veces. */
      await OutboxService.instance.encolar(
        tipo: 'MOVIMIENTO',
        titulo: 'Ajuste de ${widget.saldo.REPUESTO_CODIGO}',
        detalle:
            '${d > 0 ? '+' : '−'}${_fmt(d.abs())} · ${_motivo.text.trim()}',
        endpoint: ApiConstants.inventarioMovimientos,
        uuid: _uuid,
        cuerpo: {
          'repuesto': widget.saldo.isa_repuesto,
          'bodega': widget.saldo.isa_bodega,
          'tipo': d > 0 ? _ajustePositivo : _ajusteNegativo,
          'cantidad': d.abs(),
          'observacion': _motivo.text.trim(),
        },
      );

      SyncService.instance.despacharAhora();
      ref.invalidate(existenciasProvider);

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Existencia ajustada.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo ajustar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final d = _diferencia;
    final unidad = widget.saldo.UNIDAD_SIMBOLO ?? '';

    return HojaRecurso(
      titulo: 'Ajustar existencia',
      detalle:
          'Escribe cuántos contaste. La diferencia contra el sistema la '
          'calcula la app.',
      children: [
        SgCard(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.saldo.REPUESTO_NOMBRE,
                style: sora(14, 600, color: sg.tinta),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  widget.saldo.REPUESTO_CODIGO,
                  widget.saldo.BODEGA_NOMBRE ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
                style: sora(12, 500, color: sg.tinta3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const SgRotuloCampo('Cuántos hay'),
        const SizedBox(height: 4),
        Text(
          'El sistema dice ${_fmt(_sistema)}${unidad.isEmpty ? '' : ' $unidad'}. '
          'Escribe lo que contaste.',
          style: sora(12, 500, color: sg.tinta3, alto: 1.45),
        ),
        const SizedBox(height: 9),
        SgCampo(
          controlador: _contado,
          icono: Icons.pin_outlined,
          hint: _fmt(_sistema),
          autoenfoque: true,
          teclado: const TextInputType.numberWithOptions(decimal: true),
          onCambio: (_) => setState(() {}),
          conVoz: true,
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Cuántos contaste',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'contado',
                  rotulo: 'Contados',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_contado, campos.first.valor));
          },
        ),

        /* LA DIFERENCIA SE MUESTRA, NO SE PIDE

               Es la comprobación de que lo escrito es lo que se quiso
               escribir: quien contó 47 donde el sistema dice 4 ve "+43" y se
               da cuenta antes de enviar de que tecleó un dígito de más. */
        if (d != null) ...[
          const SizedBox(height: 12),
          _Diferencia(diferencia: d, unidad: unidad, formato: _fmt),
        ],

        const SizedBox(height: 14),
        const SgRotuloCampo('Por qué'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _motivo,
          icono: Icons.notes,
          hint: 'Conteo cíclico del pasillo 3',
          lineas: 2,
          conVoz: true,
          onCambio: (_) => setState(() {}),
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Por qué se ajusta',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'motivo',
                  rotulo: 'Motivo',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_motivo, campos.first.valor));
          },
        ),

        const SizedBox(height: 16),
        SgBoton(
          'Registrar el ajuste',
          icono: Icons.check,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ],
    );
  }
}

/// La diferencia entre lo contado y lo que dice el sistema.
class _Diferencia extends StatelessWidget {
  const _Diferencia({
    required this.diferencia,
    required this.unidad,
    required this.formato,
  });

  final double diferencia;
  final String unidad;
  final String Function(double) formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    if (diferencia == 0) {
      return SgAviso(
        'Coincide con el sistema. No hay nada que ajustar.',
        icono: Icons.check_circle_outline,
        color: sg.verdeTexto,
      );
    }

    final sobra = diferencia > 0;
    final color = sobra ? sg.verdeTexto : sg.rojoTexto;

    return SgCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          SgIconoCuadro(
            sobra ? Icons.trending_up : Icons.trending_down,
            color: color,
            lado: 38,
            tamanoIcono: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sobra ? '+' : '−'}${formato(diferencia.abs())}'
                  '${unidad.isEmpty ? '' : ' $unidad'}',
                  style: sora(17, 700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  sobra
                      ? 'Hay más de lo que dice el sistema'
                      : 'Falta respecto de lo que dice el sistema',
                  style: sora(12, 500, color: sg.tinta3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
