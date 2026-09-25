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

/// Registrar una falla desde el equipo — HU-123.
///
/// ## Por qué se registra acá
///
/// La falla la ve el que está frente a la máquina, y lo que se pierde si se
/// anota después es lo que no se reconstruye: qué ruido hacía, a qué hora
/// paró, si detuvo la línea. La OT correctiva puede nacer de la falla
/// después (desde su ficha), no al revés.
///
/// ## El estado del equipo cambia al guardar
///
/// «Detenido» o «fuera de servicio» no es un rótulo de la falla: el servidor
/// cambia el estado del activo con `ACTIVO_CAMBIAR_ESTADO` y queda en su
/// historial con la falla como motivo. Por eso se elige acá y no se puede
/// editar después.
///
/// ## Se encola, y el uuid nace al abrir
///
/// `INS_FALLA` corta por `fal_uuid` antes de validar: un reintento no
/// registra la misma falla dos veces ni cambia el estado del equipo dos veces.
class NuevaFallaScreen extends ConsumerStatefulWidget {
  const NuevaFallaScreen({super.key, this.activoId, this.activoNombre});

  /// Desde la ficha de un activo la falla ya cuelga de él.
  final int? activoId;
  final String? activoNombre;

  @override
  ConsumerState<NuevaFallaScreen> createState() => _NuevaFallaScreenState();
}

class _NuevaFallaScreenState extends ConsumerState<NuevaFallaScreen> {
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _consecuencia = TextEditingController();
  final String _uuid = OutboxService.nuevoUuid();

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  /// Criticidad_Nivel y Activo_Estado son catálogos fijos del sistema (no
  /// por cliente), los mismos que usa la web.
  static const List<(int, String)> _criticidades = [
    (1, 'Baja'),
    (2, 'Media'),
    (3, 'Alta'),
    (4, 'Crítica'),
  ];
  static const List<(int?, String)> _estados = [
    (null, 'No cambia'),
    (2, 'Operativo con observación'),
    (3, 'Detenido'),
    (5, 'Fuera de servicio'),
  ];

  late int? _activoId = widget.activoId;
  late String? _activoNombre = widget.activoNombre;
  int _criticidad = 2;
  int? _estadoPosterior;
  bool _detuvoProduccion = false;
  DateTime _cuando = DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _consecuencia.dispose();
    super.dispose();
  }

  bool get _completo =>
      _activoId != null && _titulo.text.trim().isNotEmpty && !_guardando;

  Future<void> _guardar() async {
    if (!_completo) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'FALLA',
        titulo: 'Falla en ${_activoNombre ?? 'equipo'}',
        detalle: _titulo.text.trim(),
        endpoint: ApiConstants.fallas,
        uuid: _uuid,
        cuerpo: {
          'uuid': _uuid,
          'activo': _activoId,
          'criticidad': _criticidad,
          'titulo': _titulo.text.trim(),
          'descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
          'consecuencia': _consecuencia.text.trim().isEmpty
              ? null
              : _consecuencia.text.trim(),
          'estado_posterior': _estadoPosterior,
          'detuvo_produccion': _detuvoProduccion,
          'fecha_deteccion_utc': _cuando.toUtc().toIso8601String(),
        },
      );

      SyncService.instance.despacharAhora();
      if (!mounted) return;
      ref.invalidate(fallasProvider);
      if (_estadoPosterior != null && _activoId != null) {
        ref.invalidate(activoProvider(_activoId!));
      }

      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Falla registrada.'
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

  Future<void> _elegirActivo() async {
    final elegido = await showModalBottomSheet<Activo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SelectorActivo(),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _activoId = elegido.act_id;
      _activoNombre = '${elegido.act_codigo} · ${elegido.act_nombre}';
    });
  }

  Future<void> _elegirCuando() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _cuando,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_cuando),
    );
    if (hora == null || !mounted) return;
    final e = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    setState(() => _cuando = e.isAfter(DateTime.now()) ? DateTime.now() : e);
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Registrar una falla',
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => enLinea
                  ? const SizedBox.shrink()
                  : SgBadge(
                      'Sin conexión',
                      color: sg.tinta2,
                      icono: Icons.cloud_off_outlined,
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SgPie(
        child: SgBoton(
          'Registrar la falla',
          icono: Icons.report_problem_outlined,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ),
      body: ListView(
        padding: context.conBarraSistema(
          const EdgeInsets.fromLTRB(16, 14, 16, 12),
        ),
        children: [
          const SgRotuloCampo('Equipo'),
          const SizedBox(height: 8),
          SgCard(
            padding: const EdgeInsets.all(4),
            child: SgFila(
              icono: Icons.view_in_ar_outlined,
              texto: _activoNombre ?? 'Elegir el equipo',
              detalle: _activoNombre == null ? 'Obligatorio' : null,
              chevron: widget.activoId == null,
              onTap: widget.activoId == null ? _elegirActivo : null,
            ),
          ),

          const SizedBox(height: 14),
          const SgRotuloCampo('Qué falló'),
          const SizedBox(height: 4),
          Text(
            'Una línea: es lo que se lee en la lista.',
            style: sora(12, 500, color: sg.tinta3, alto: 1.45),
          ),
          const SizedBox(height: 9),
          SgCampo(
            controlador: _titulo,
            icono: Icons.title,
            hint: 'Correa de transmisión cortada',
            conVoz: true,
            onCambio: (_) => setState(() {}),
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Qué falló',
                interpretar: (t) => [
                  CampoDictado(
                    clave: 'titulo',
                    rotulo: 'Título',
                    valor: InterpreteVoz.normalizar(t),
                  ),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_titulo, campos.first.valor));
            },
          ),

          const SizedBox(height: 14),
          const SgRotuloCampo('Qué se vio'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _descripcion,
            icono: Icons.notes,
            hint: 'Ruido fuerte, olor a goma quemada y luego se detuvo',
            lineas: 3,
            conVoz: true,
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Qué se vio',
                interpretar: (t) => [
                  CampoDictado(
                    clave: 'descripcion',
                    rotulo: 'Descripción',
                    valor: InterpreteVoz.normalizar(t),
                  ),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_descripcion, campos.first.valor));
            },
          ),

          const SizedBox(height: 14),
          const SgRotuloCampo('Consecuencia'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _consecuencia,
            icono: Icons.warning_amber_outlined,
            hint: 'Opcional: línea 1 sin producir',
            lineas: 2,
          ),

          const SizedBox(height: 16),
          const SgRotulo('Criticidad'),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, nombre) in _criticidades)
                SgChip(
                  nombre,
                  elegido: _criticidad == id,
                  onTap: () => setState(() => _criticidad = id),
                ),
            ],
          ),

          const SizedBox(height: 16),
          const SgRotulo('Cómo queda el equipo'),
          const SizedBox(height: 4),
          Text(
            'Al guardar, el equipo cambia a este estado y queda en su '
            'historial. Después no se edita.',
            style: sora(12, 500, color: sg.tinta3, alto: 1.45),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, nombre) in _estados)
                SgChip(
                  nombre,
                  elegido: _estadoPosterior == id,
                  onTap: () => setState(() => _estadoPosterior = id),
                ),
            ],
          ),

          const SizedBox(height: 14),
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                SgFila(
                  icono: Icons.schedule,
                  texto: 'Cuándo se detectó',
                  detalle: 'No cuándo lo estás escribiendo',
                  valor: _fecha.format(_cuando),
                  onTap: _elegirCuando,
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

          const SizedBox(height: 16),
          SgAviso(
            'La orden correctiva se abre después, desde la ficha de la falla, '
            'con la criticidad como prioridad.',
            icono: Icons.info_outline,
            color: sg.tinta2,
          ),
        ],
      ),
    );
  }
}

/// Elegir un equipo de la planta. Salen de la sábana, así que funciona sin
/// señal: la falla se registra frente a la máquina, donde no la hay.
class _SelectorActivo extends ConsumerStatefulWidget {
  const _SelectorActivo();

  @override
  ConsumerState<_SelectorActivo> createState() => _SelectorActivoState();
}

class _SelectorActivoState extends ConsumerState<_SelectorActivo> {
  final _filtro = TextEditingController();

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final activos = ref.watch(activosProvider);
    final f = _filtro.text.trim().toLowerCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, control) => Container(
        decoration: BoxDecoration(
          color: sg.fondo,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            const SgRotuloCampo('Qué equipo falló'),
            const SizedBox(height: 8),
            SgCampo(
              controlador: _filtro,
              icono: Icons.search,
              hint: 'Código o nombre',
              autoenfoque: true,
              onCambio: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: activos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SgAviso(
                  'No se pudieron traer los equipos: $e',
                  icono: Icons.cloud_off_outlined,
                  color: sg.rojoTexto,
                ),
                data: (lista) {
                  final visibles = lista
                      .where(
                        (a) =>
                            f.isEmpty ||
                            a.act_codigo.toLowerCase().contains(f) ||
                            a.act_nombre.toLowerCase().contains(f),
                      )
                      .toList();
                  return ListView.builder(
                    controller: control,
                    padding: context.conBarraSistema(
                      const EdgeInsets.only(bottom: 12),
                    ),
                    itemCount: visibles.length,
                    itemBuilder: (_, i) => SgFila(
                      icono: Icons.view_in_ar_outlined,
                      texto: visibles[i].act_nombre,
                      detalle: visibles[i].act_codigo,
                      chevron: true,
                      onTap: () => Navigator.of(context).pop(visibles[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
