import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'hojas_recursos.dart';

/// Registrar cuánto estuvo detenido un equipo — HU-124.
///
/// ## Se abre desde la orden, desde la falla, o desde el equipo
///
/// Un corte de energía no tiene orden ni falla; una parada por correctiva
/// tiene las dos. Por eso `orden` y `falla` son opcionales y la hoja no
/// pregunta por ellos: vienen de donde se abrió.
///
/// ## Los minutos no se escriben
///
/// Se eligen inicio y término y el servidor calcula. Sin término el periodo
/// queda **abierto** —el equipo sigue detenido— y los minutos corren hasta
/// que alguien lo cierre desde la web o desde acá.
///
/// ## Planificada o no
///
/// Es la marca que separa una parada de mantenimiento programado (no
/// penaliza la disponibilidad) de una falla (sí). Desde una falla nace
/// «no planificada» y no se pregunta.
///
/// ## El motivo
///
/// Catálogo `Indisponibilidad_Motivo` (seis filas fijas, las mismas de la
/// web) o texto libre; uno de los dos es obligatorio y lo exige el SP.
class HojaIndisponibilidad extends ConsumerStatefulWidget {
  const HojaIndisponibilidad({
    super.key,
    required this.activoId,
    required this.activoNombre,
    this.ordenId,
    this.fallaId,
    this.origenFalla = false,
  });

  final int activoId;
  final String activoNombre;
  final int? ordenId;
  final int? fallaId;

  /// Desde una falla la parada es no planificada y el motivo es «Falla».
  final bool origenFalla;

  static Future<bool> abrir(
    BuildContext context, {
    required int activoId,
    required String activoNombre,
    int? ordenId,
    int? fallaId,
    bool origenFalla = false,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaIndisponibilidad(
        activoId: activoId,
        activoNombre: activoNombre,
        ordenId: ordenId,
        fallaId: fallaId,
        origenFalla: origenFalla,
      ),
    );
    return r ?? false;
  }

  /// Indisponibilidad_Motivo, bloque 19 de la base. Fijo en las dos puntas.
  static const List<(int, String)> motivos = [
    (1, 'Mantenimiento planificado'),
    (2, 'Falla'),
    (3, 'Espera de repuesto'),
    (4, 'Espera de técnico'),
    (5, 'Causa externa'),
    (6, 'Parada de producción'),
  ];

  @override
  ConsumerState<HojaIndisponibilidad> createState() =>
      _HojaIndisponibilidadState();
}

class _HojaIndisponibilidadState extends ConsumerState<HojaIndisponibilidad> {
  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  final _detalle = TextEditingController();
  final String _uuid = OutboxService.nuevoUuid();

  late DateTime _inicio = DateTime.now();
  DateTime? _fin;
  late bool _planificada = !widget.origenFalla && widget.fallaId == null
      ? true
      : false;
  bool _detuvoProduccion = false;
  late int? _motivo = widget.origenFalla || widget.fallaId != null
      ? 2
      : (widget.ordenId != null ? 1 : null);
  bool _guardando = false;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  bool get _completo =>
      !_guardando && (_motivo != null || _detalle.text.trim().isNotEmpty);

  Future<void> _elegir({required bool inicio}) async {
    final base = inicio ? _inicio : (_fin ?? DateTime.now());
    final dia = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (hora == null || !mounted) return;
    var elegido = DateTime(
      dia.year,
      dia.month,
      dia.day,
      hora.hour,
      hora.minute,
    );
    if (elegido.isAfter(DateTime.now())) elegido = DateTime.now();
    setState(() {
      if (inicio) {
        _inicio = elegido;
        if (_fin != null && _fin!.isBefore(_inicio)) _fin = null;
      } else {
        _fin = elegido.isBefore(_inicio) ? _inicio : elegido;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_completo) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final texto = _detalle.text.trim();
    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'INDISPONIBILIDAD',
        titulo: 'Parada de ${widget.activoNombre}',
        detalle: _fin == null
            ? 'Desde ${_fecha.format(_inicio)} · sigue detenido'
            : '${_fecha.format(_inicio)} → ${_fecha.format(_fin!)}',
        endpoint: ApiConstants.indisponibilidades,
        uuid: _uuid,
        cuerpo: {
          'uuid': _uuid,
          'activo': widget.activoId,
          'orden_trabajo': widget.ordenId,
          'falla': widget.fallaId,
          'fecha_inicio_utc': _inicio.toUtc().toIso8601String(),
          'fecha_fin_utc': _fin?.toUtc().toIso8601String(),
          'planificada': _planificada,
          'detuvo_produccion': _detuvoProduccion,
          'motivo_catalogo': _motivo,
          'motivo': texto.isEmpty ? null : texto,
        },
      );

      SyncService.instance.despacharAhora();
      if (!mounted) return;
      if (widget.ordenId != null) {
        ref.invalidate(indisponibilidadesProvider(('ORDEN', widget.ordenId!)));
      }
      if (widget.fallaId != null) {
        ref.invalidate(indisponibilidadesProvider(('FALLA', widget.fallaId!)));
        ref.invalidate(fallaProvider(widget.fallaId!));
      }
      ref.invalidate(indisponibilidadesProvider(('ACTIVO', widget.activoId)));

      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Parada registrada.'
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

    return HojaRecurso(
      titulo: 'Registrar parada del equipo',
      detalle: widget.activoNombre,
      children: [
        SgCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              SgFila(
                icono: Icons.play_circle_outline,
                texto: 'Desde',
                valor: _fecha.format(_inicio),
                onTap: () => _elegir(inicio: true),
              ),
              Divider(height: 1, color: sg.div),
              SgFila(
                icono: Icons.stop_circle_outlined,
                texto: 'Hasta',
                detalle: _fin == null ? 'Vacío: sigue detenido' : null,
                valor: _fin == null ? 'Sigue detenido' : _fecha.format(_fin!),
                onTap: () => _elegir(inicio: false),
                derecha: _fin == null
                    ? null
                    : SgBotonIcono(
                        Icons.close,
                        fondo: sg.up,
                        color: sg.tinta2,
                        lado: 36,
                        tamano: 17,
                        onTap: () => setState(() => _fin = null),
                      ),
              ),
              Divider(height: 1, color: sg.div),
              SgFila(
                icono: Icons.event_available_outlined,
                texto: 'Planificada',
                detalle: 'Una parada programada no penaliza la disponibilidad',
                derecha: Switch(
                  value: _planificada,
                  onChanged: widget.origenFalla
                      ? null
                      : (v) => setState(() => _planificada = v),
                ),
              ),
              Divider(height: 1, color: sg.div),
              SgFila(
                icono: Icons.factory_outlined,
                texto: 'Detuvo la producción',
                derecha: Switch(
                  value: _detuvoProduccion,
                  onChanged: (v) => setState(() => _detuvoProduccion = v),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const SgRotuloCampo('Motivo'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, nombre) in HojaIndisponibilidad.motivos)
              SgChip(
                nombre,
                elegido: _motivo == id,
                onTap: () =>
                    setState(() => _motivo = _motivo == id ? null : id),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SgCampo(
          controlador: _detalle,
          icono: Icons.notes,
          hint: _motivo == null
              ? 'Obligatorio si no eliges un motivo de la lista'
              : 'Detalle, opcional',
          lineas: 2,
          onCambio: (_) => setState(() {}),
        ),

        const SizedBox(height: 16),
        SgBoton(
          'Registrar parada',
          icono: Icons.power_off_outlined,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ],
    );
  }
}
