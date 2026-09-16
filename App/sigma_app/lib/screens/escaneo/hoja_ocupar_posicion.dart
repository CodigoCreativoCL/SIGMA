import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../ordenes/hojas_recursos.dart';

/// Poner un equipo en una posición vacía — HU-154 #3.
///
/// Se llega escaneando el QR de una posición que no tiene equipo. La lista
/// sale de la sábana (los activos ya bajados de la planta), así que
/// funciona sin señal; el envío queda encolado con uuid y el SP no duplica
/// el periodo si el teléfono reintenta.
class HojaOcuparPosicion extends ConsumerStatefulWidget {
  const HojaOcuparPosicion({super.key, required this.cabecera});

  final EscaneoCabecera cabecera;

  /// Devuelve el activo elegido si la asignación quedó registrada o
  /// encolada; null si se cerró sin hacer nada.
  static Future<Activo?> abrir(
    BuildContext context,
    EscaneoCabecera cabecera,
  ) => showModalBottomSheet<Activo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HojaOcuparPosicion(cabecera: cabecera),
  );

  @override
  ConsumerState<HojaOcuparPosicion> createState() =>
      _HojaOcuparPosicionState();
}

class _HojaOcuparPosicionState extends ConsumerState<HojaOcuparPosicion> {
  final _filtro = TextEditingController();
  final _observacion = TextEditingController();

  List<Activo>? _lista;
  Object? _error;
  Activo? _elegido;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _filtro.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final l = await SigmaRepository.instance.activos();
      // Solo los de la planta de la posición: el SP rechaza los de otra.
      final planta = widget.cabecera.PLANTA;
      final filtrados = l
          .where((a) => planta == null || (a.PLANTA_NOMBRE ?? planta) == planta)
          .toList();
      if (mounted) setState(() => _lista = filtrados);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _ocupar() async {
    final a = _elegido;
    final posId = widget.cabecera.pos_id;
    if (a == null || posId == null || _guardando) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);

    try {
      await SigmaRepository.instance.ocuparPosicion(
        posicion: posId,
        activo: a.act_id,
        posicionCodigo: widget.cabecera.pos_codigo ?? '$posId',
        activoCodigo: a.act_codigo,
        observacion: _observacion.text.trim(),
      );
      SyncService.instance.despacharAhora();
      if (!mounted) return;
      navegador.pop(a);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? '${a.act_codigo} quedó en la posición ${widget.cabecera.pos_codigo ?? ''}.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo asignar el equipo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final filtro = _filtro.text.trim().toLowerCase();
    final visibles = (_lista ?? const <Activo>[])
        .where(
          (a) =>
              filtro.isEmpty ||
              a.act_codigo.toLowerCase().contains(filtro) ||
              a.act_nombre.toLowerCase().contains(filtro),
        )
        .toList();

    return HojaRecurso(
      titulo: 'Poner un equipo en esta posición',
      detalle:
          '${widget.cabecera.pos_codigo ?? ''} · ${widget.cabecera.pos_nombre ?? ''}',
      children: [
        SgAviso(
          'La posición está vacía. Elige el equipo que está instalado aquí; '
          'si venía de otra posición, se cierra su periodo allá.',
          icono: Icons.info_outline,
          color: sg.tinta2,
        ),
        const SizedBox(height: 14),
        const SgRotuloCampo('Equipo'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _filtro,
          icono: Icons.search,
          hint: 'Buscar por código o nombre',
          onCambio: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          SgAviso(
            'No se pudieron leer los equipos: $_error',
            icono: Icons.cloud_off_outlined,
            color: sg.rojoTexto,
          )
        else if (_lista == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visibles.isEmpty)
          SgAviso(
            _lista!.isEmpty
                ? 'No hay equipos bajados al teléfono. Sincroniza la planta primero.'
                : 'Ningún equipo con ese texto.',
            icono: Icons.search_off,
            color: sg.tinta2,
          )
        else
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (final a in visibles.take(30))
                  SgFila(
                    icono: _elegido?.act_id == a.act_id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    colorIcono: _elegido?.act_id == a.act_id
                        ? sg.primarioTexto
                        : null,
                    texto: '${a.act_codigo} · ${a.act_nombre}',
                    detalle: a.PLANTA_NOMBRE ?? '',
                    onTap: () => setState(() => _elegido = a),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const SgRotuloCampo('Observación'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _observacion,
          icono: Icons.notes,
          hint: 'Opcional: por qué se instala aquí',
          lineas: 2,
        ),
        const SizedBox(height: 16),
        SgBoton(
          'Asignar a la posición',
          icono: Icons.place_outlined,
          cargando: _guardando,
          onTap: (_elegido != null && !_guardando) ? _ocupar : null,
        ),
      ],
    );
  }
}
