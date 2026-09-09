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

/// Los movimientos de inventario que no son el ajuste — vistas 10.9 a 10.12.
///
/// ## Por qué los cuatro en una hoja y no en cuatro pantallas
///
/// El diseño los separa —ingreso, entrega, devolución, traslado— y en la web
/// tiene sentido, porque cada uno tiene su formulario y su papeleo. En el
/// teléfono los cuatro preguntan **lo mismo**: qué pieza, cuánta, de dónde y
/// por qué. Lo único que cambia es la palabra y, en el traslado, una bodega de
/// destino.
///
/// Cuatro pantallas idénticas serían cuatro sitios donde arreglar el mismo
/// defecto. Acá el tipo entra por parámetro y la hoja se adapta.
///
/// ## Por qué el ajuste sigue aparte
///
/// Porque su pregunta **no** es «cuánta»: es «cuántas hay». Se escribe lo
/// contado y la app deduce la diferencia y el signo. Meterlo aquí obligaría a
/// que el campo significara dos cosas según el tipo, que es exactamente cómo
/// se registra un movimiento al revés.
enum TipoMovimiento {
  ingreso,
  entrega,
  devolucion,
  traslado;

  /// El id de `Inventario_Movimiento_Tipo`, como lo nombra
  /// `InventarioMovimientosController`.
  int get id => switch (this) {
    TipoMovimiento.ingreso => 1,
    TipoMovimiento.entrega => 2,
    TipoMovimiento.devolucion => 3,
    TipoMovimiento.traslado => 6,
  };

  String get titulo => switch (this) {
    TipoMovimiento.ingreso => 'Ingresar repuesto',
    TipoMovimiento.entrega => 'Entregar repuesto',
    TipoMovimiento.devolucion => 'Devolver repuesto',
    TipoMovimiento.traslado => 'Trasladar a otra bodega',
  };

  String get detalle => switch (this) {
    TipoMovimiento.ingreso =>
      'Entra a la bodega lo que llegó de compra. Suma al saldo.',
    TipoMovimiento.entrega =>
      'Sale de la bodega para un trabajo. Resta del saldo.',
    TipoMovimiento.devolucion =>
      'Vuelve a la bodega lo que sobró. Suma al saldo.',
    TipoMovimiento.traslado =>
      'Cambia de bodega sin salir del inventario. El saldo total no cambia.',
  };

  /// El permiso que la API exige para este tipo. Se comprueba **antes** de
  /// ofrecer el botón: llevar a alguien hasta el final de un formulario para
  /// responderle 403 es el peor momento para decírselo.
  String get permiso => switch (this) {
    TipoMovimiento.ingreso => 'REGISTRAR INGRESO REPUESTO',
    TipoMovimiento.entrega || TipoMovimiento.devolucion => 'ENTREGAR REPUESTO',
    TipoMovimiento.traslado => 'AJUSTAR INVENTARIO',
  };

  /// ¿Este movimiento resta del saldo de la bodega de origen?
  bool get resta =>
      this == TipoMovimiento.entrega || this == TipoMovimiento.traslado;

  IconData get icono => switch (this) {
    TipoMovimiento.ingreso => Icons.south_west,
    TipoMovimiento.entrega => Icons.north_east,
    TipoMovimiento.devolucion => Icons.undo,
    TipoMovimiento.traslado => Icons.swap_horiz,
  };
}

class HojaMovimiento extends ConsumerStatefulWidget {
  const HojaMovimiento({super.key, required this.saldo, required this.tipo});

  final InventarioSaldo saldo;
  final TipoMovimiento tipo;

  /// Abre la hoja. Devuelve `true` si el movimiento quedó encolado.
  static Future<bool> abrir(
    BuildContext context, {
    required InventarioSaldo saldo,
    required TipoMovimiento tipo,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaMovimiento(saldo: saldo, tipo: tipo),
    );
    return r ?? false;
  }

  @override
  ConsumerState<HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends ConsumerState<HojaMovimiento> {
  static final _n = NumberFormat.decimalPattern('es_CL');

  final _cantidad = TextEditingController();
  final _observacion = TextEditingController();

  final String _uuid = OutboxService.nuevoUuid();

  int? _ubicacion;
  int? _bodegaDestino;
  bool _guardando = false;
  bool _intento = false;

  @override
  void dispose() {
    _cantidad.dispose();
    _observacion.dispose();
    super.dispose();
  }

  double? get _cuanto {
    final t = _cantidad.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return (v == null || v <= 0) ? null : v;
  }

  /// Solo importa en los que RESTAN: no se puede sacar más de lo que hay. En
  /// un ingreso o una devolución, el saldo actual no limita nada.
  bool get _sobrepasa =>
      widget.tipo.resta &&
      _cuanto != null &&
      _cuanto! > widget.saldo.CANTIDAD_DISPONIBLE;

  String? _validarCantidad(String? v) {
    if (!_intento) return null;
    if ((v ?? '').trim().isEmpty) return 'Escribe cuánta.';
    if (_cuanto == null) return 'Tiene que ser un número mayor que cero.';
    return null;
  }

  bool get _completo =>
      _cuanto != null &&
      !_sobrepasa &&
      (widget.tipo != TipoMovimiento.traslado || _bodegaDestino != null);

  Future<void> _guardar() async {
    if (_guardando) return;

    if (!_completo) {
      setState(() => _intento = true);
      return;
    }

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'MOVIMIENTO',
        titulo: '${widget.tipo.titulo}: ${widget.saldo.REPUESTO_CODIGO}',
        detalle:
            '${_n.format(_cuanto)} '
                    '${widget.saldo.UNIDAD_SIMBOLO ?? ''}'
                .trim(),
        endpoint: ApiConstants.inventarioMovimientos,
        uuid: _uuid,
        cuerpo: {
          'repuesto': widget.saldo.isa_repuesto,
          'bodega': widget.saldo.isa_bodega,
          'tipo': widget.tipo.id,
          // Siempre positiva: el signo lo lleva el TIPO. Mandar -3 con un tipo
          // que ya resta descontaría dos veces.
          'cantidad': _cuanto,
          'ubicacion': _ubicacion,
          'bodega_destino': _bodegaDestino,
          'observacion': _observacion.text.trim().isEmpty
              ? null
              : _observacion.text.trim(),
        },
      );

      SyncService.instance.despacharAhora();
      ref.invalidate(existenciasProvider);
      ref.invalidate(saldosRepuestoProvider(widget.saldo.isa_repuesto));

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Movimiento registrado.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo registrar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final unidad = widget.saldo.UNIDAD_SIMBOLO ?? '';

    return HojaRecurso(
      titulo: widget.tipo.titulo,
      detalle: widget.tipo.detalle,
      children: [
        SgCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              SgIconoCuadro(
                widget.tipo.icono,
                color: sg.primarioTexto,
                lado: 40,
                tamanoIcono: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.saldo.REPUESTO_NOMBRE,
                      style: sora(14, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        widget.saldo.REPUESTO_CODIGO,
                        widget.saldo.BODEGA_NOMBRE ?? '',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: sora(12, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SgCifra(
                _n.format(widget.saldo.CANTIDAD_DISPONIBLE),
                unidad: unidad,
                tamano: 16,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const SgRotuloCampo('Cuánta', obligatorio: true),
        const SizedBox(height: 9),
        SgCampo(
          controlador: _cantidad,
          icono: Icons.pin_outlined,
          hint: '1',
          autoenfoque: true,
          teclado: const TextInputType.numberWithOptions(decimal: true),
          validador: _validarCantidad,
          onCambio: (_) => setState(() {}),
          conVoz: true,
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Cuánta',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'cantidad',
                  rotulo: 'Cantidad',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_cantidad, campos.first.valor));
          },
        ),

        if (_sobrepasa) ...[
          const SizedBox(height: 10),
          SgAviso(
            'Solo hay ${_n.format(widget.saldo.CANTIDAD_DISPONIBLE)} '
            '$unidad en esta bodega.',
            icono: Icons.warning_amber,
            color: sg.rojoTexto,
          ),
        ],

        // El estante, cuando la bodega los tiene. Misma pieza que el consumo:
        // el SP rechaza el movimiento sin él.
        SelectorEstante(
          bodegaId: widget.saldo.isa_bodega,
          elegida: _ubicacion,
          onElegir: (v) => setState(() => _ubicacion = v),
        ),

        if (widget.tipo == TipoMovimiento.traslado) ...[
          const SizedBox(height: 14),
          const SgRotuloCampo('A qué bodega', obligatorio: true),
          const SizedBox(height: 9),
          _BodegaDestino(
            excluida: widget.saldo.isa_bodega,
            elegida: _bodegaDestino,
            onElegir: (v) => setState(() => _bodegaDestino = v),
          ),
          if (_intento && _bodegaDestino == null) ...[
            const SizedBox(height: 10),
            SgAviso(
              'Elige a qué bodega se traslada.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
          ],
        ],

        const SizedBox(height: 14),
        const SgRotuloCampo('Observación'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _observacion,
          icono: Icons.notes,
          hint: widget.tipo == TipoMovimiento.ingreso
              ? 'Guía de despacho, proveedor'
              : 'Para qué, o de dónde vuelve',
          lineas: 2,
          conVoz: true,
          onCambio: (_) => setState(() {}),
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Observación',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'observacion',
                  rotulo: 'Observación',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_observacion, campos.first.valor));
          },
        ),

        const SizedBox(height: 16),
        SgBoton(
          widget.tipo.titulo,
          icono: Icons.check,
          cargando: _guardando,
          onTap: _guardar,
        ),
      ],
    );
  }
}

/// La bodega a la que se traslada. No se ofrece la de origen: trasladar algo a
/// donde ya está no es un movimiento, es un error de dedo.
class _BodegaDestino extends ConsumerWidget {
  const _BodegaDestino({
    required this.excluida,
    required this.elegida,
    required this.onElegir,
  });

  final int excluida;
  final int? elegida;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final bodegas = ref.watch(bodegasProvider);

    return bodegas.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => SgAviso(
        'No se pudieron cargar las bodegas. Sin ellas no se puede trasladar.',
        icono: Icons.error_outline,
        color: sg.rojoTexto,
      ),
      data: (p) {
        final otras = p.datos.where((b) => b.bod_id != excluida).toList();

        if (otras.isEmpty) {
          return SgAviso(
            'Esta planta tiene una sola bodega: no hay a dónde trasladar.',
            icono: Icons.info_outline,
            color: sg.tinta2,
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in otras)
              SgChip(
                b.bod_nombre,
                elegido: elegida == b.bod_id,
                onTap: () => onElegir(b.bod_id),
              ),
          ],
        );
      },
    );
  }
}
