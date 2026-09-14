import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'hojas_recursos.dart';

/// Asignar o reasignar una orden desde la planta — HU-112.
///
/// ## Para el supervisor que está en la nave
///
/// La asignación nace en la web, pero el que ve que el técnico de turno se
/// fue a otra emergencia es el supervisor que está al lado de la máquina.
/// Reasignar desde el teléfono evita el viaje a la oficina —y la orden
/// huérfana mientras tanto—.
///
/// ## Un único responsable
///
/// «Responsable» y «apoyo» son dos botones y no una casilla porque la regla
/// la decide el SP: al nombrar otro responsable el anterior pasa a apoyo, y
/// eso hay que decirlo antes de tocar. La lista es la de compañeros de la
/// planta con perfil de terreno, la misma que usa «compartir».
///
/// ## Se encola con uuid
///
/// `INS_ORDEN_TRABAJO_ASIGNACION` corta por `ota_uuid` antes de validar, así
/// que un reintento no deja al mismo técnico dos veces en la orden.
class HojaAsignar extends ConsumerStatefulWidget {
  const HojaAsignar({super.key, required this.orden});

  final OrdenTrabajo orden;

  /// Abre la hoja. Devuelve `true` si la asignación quedó encolada.
  static Future<bool> abrir(BuildContext context, OrdenTrabajo orden) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaAsignar(orden: orden),
    );
    return r ?? false;
  }

  @override
  ConsumerState<HojaAsignar> createState() => _HojaAsignarState();
}

class _HojaAsignarState extends ConsumerState<HojaAsignar> {
  final _filtro = TextEditingController();
  final _observacion = TextEditingController();
  final String _uuid = OutboxService.nuevoUuid();

  List<Companero>? _lista;
  Object? _error;
  Companero? _elegido;
  bool _responsable = true;
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
    final planta = ref.read(instalacionProvider);
    if (planta == null) {
      setState(() => _error = 'Elige una planta para ver a su gente.');
      return;
    }
    try {
      final l = await SigmaRepository.instance.companeros(
        planta.cin_id,
        perfiles: SigmaRepository.perfilesDeTerreno,
      );
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _completo => _elegido != null && !_guardando;

  Future<void> _asignar() async {
    final quien = _elegido;
    if (quien == null || _guardando) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final texto = _observacion.text.trim();
    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'ASIGNACION_OT',
        titulo: 'Asignar ${widget.orden.OT_NUMERO}',
        detalle: '${quien.NOMBRE} · ${_responsable ? 'responsable' : 'apoyo'}',
        endpoint:
            '${ApiConstants.ordenesTrabajo}/${widget.orden.otr_id}/asignaciones',
        uuid: _uuid,
        cuerpo: {
          'uuid': _uuid,
          'usuario': quien.usu_id,
          'es_responsable': _responsable,
          'observacion': texto.isEmpty ? null : texto,
        },
      );

      SyncService.instance.despacharAhora();
      if (!mounted) return;
      ref.invalidate(asignacionesProvider(widget.orden.otr_id));
      ref.invalidate(ordenTrabajoProvider(widget.orden.otr_id));
      ref.invalidate(ordenesTrabajoProvider);

      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Orden asignada a ${quien.NOMBRE}.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo asignar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final filtro = _filtro.text.trim().toLowerCase();
    final visibles = (_lista ?? const <Companero>[])
        .where((c) => filtro.isEmpty || c.NOMBRE.toLowerCase().contains(filtro))
        .toList();

    return HojaRecurso(
      titulo: 'Asignar la orden',
      detalle: '${widget.orden.OT_NUMERO} · ${widget.orden.otr_titulo}',
      children: [
        Row(
          children: [
            Expanded(
              child: SgChip(
                'Responsable',
                icono: Icons.person,
                elegido: _responsable,
                onTap: () => setState(() => _responsable = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SgChip(
                'Apoyo',
                icono: Icons.person_outline,
                elegido: !_responsable,
                onTap: () => setState(() => _responsable = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _responsable
              ? 'Un solo responsable por orden: si ya había otro, pasa a apoyo.'
              : 'Se suma al trabajo; el responsable sigue siendo el mismo.',
          style: sora(12, 500, color: sg.tinta3, alto: 1.45),
        ),

        const SizedBox(height: 14),
        const SgRotuloCampo('Quién'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _filtro,
          icono: Icons.search,
          hint: 'Buscar por nombre',
          onCambio: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),

        if (_error != null)
          SgAviso(
            'No se pudo traer la gente de la planta: $_error',
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
            'Nadie con ese nombre en esta planta.',
            icono: Icons.person_search_outlined,
            color: sg.tinta2,
          )
        else
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (final c in visibles.take(30))
                  SgFila(
                    icono: _elegido?.usu_id == c.usu_id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    colorIcono: _elegido?.usu_id == c.usu_id
                        ? sg.primarioTexto
                        : null,
                    texto: c.NOMBRE,
                    detalle: [
                      c.PERFIL_NOMBRE,
                      c.ESPECIALIDADES,
                    ].where((s) => (s ?? '').isNotEmpty).join(' · '),
                    onTap: () => setState(() => _elegido = c),
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
          hint: 'Opcional: por qué se reasigna',
          lineas: 2,
        ),

        const SizedBox(height: 12),
        SgAviso(
          'Si la orden pide una especialidad que la persona no tiene, se '
          'asigna igual y queda una advertencia en la asignación.',
          icono: Icons.info_outline,
          color: sg.tinta2,
        ),

        const SizedBox(height: 16),
        SgBoton(
          'Asignar',
          icono: Icons.person_add_alt,
          cargando: _guardando,
          onTap: _completo ? _asignar : null,
        ),
      ],
    );
  }
}
