import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import '../ordenes/hoja_indisponibilidad.dart';
import '../ordenes/hojas_recursos.dart';
import '../ordenes/orden_ficha_screen.dart';
import 'fallas_screen.dart';

/// La falla como centro — HU-123 · HU-124.
///
/// ## Tres hilos y una acción
///
/// La ficha muestra qué falló; debajo, **qué se encontró** (diagnósticos) y
/// **qué se hizo** (acciones), que se agregan y no se editan: son historia.
/// El SP decide cuál diagnóstico es el definitivo y cuándo la falla queda
/// resuelta (la primera acción definitiva). La única acción grande es abrir
/// la correctiva de emergencia, y desaparece cuando la falla está resuelta.
///
/// ## Indisponibilidad
///
/// Cuánto estuvo detenido el equipo por esta falla va acá y no en una
/// pantalla aparte: la pregunta aparece mirando la falla.
class FallaFichaScreen extends ConsumerStatefulWidget {
  const FallaFichaScreen({super.key, required this.fallaId});

  final int fallaId;

  @override
  ConsumerState<FallaFichaScreen> createState() => _FallaFichaScreenState();
}

class _FallaFichaScreenState extends ConsumerState<FallaFichaScreen> {
  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');
  bool _ocupado = false;

  void _recargar() {
    ref.invalidate(fallaProvider(widget.fallaId));
    ref.invalidate(diagnosticosProvider(widget.fallaId));
    ref.invalidate(accionesFallaProvider(widget.fallaId));
    ref.invalidate(indisponibilidadesProvider(('FALLA', widget.fallaId)));
    ref.invalidate(fallasProvider);
  }

  Future<void> _generarOrden(Falla f) async {
    if (_ocupado) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _ocupado = true);
    try {
      final id = await SigmaRepository.instance.ordenDesdeFalla(f);
      if (!mounted) return;
      _recargar();
      ref.invalidate(ordenesTrabajoProvider);
      ref.invalidate(ordenesDisponiblesProvider);
      if (id > 0) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('Orden correctiva abierta.')),
        );
        navegador.push(
          MaterialPageRoute(builder: (_) => OrdenFichaScreen(ordenId: id)),
        );
      } else {
        mensajero.showSnackBar(
          const SnackBar(
            content: Text(
              'Guardado en el teléfono. La orden se abre al volver la señal.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final falla = ref.watch(fallaProvider(widget.fallaId));
    final puedeRegistrar = ref.watch(tienePermisoProvider('REGISTRAR FALLA'));
    final puedeCrearOt = ref.watch(tienePermisoProvider('CREAR ORDEN TRABAJO'));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        falla.valueOrNull?.codigo ?? 'Falla',
        acciones: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _recargar,
          ),
        ],
      ),
      bottomNavigationBar: falla.valueOrNull == null
          ? null
          : _pie(falla.valueOrNull!, puedeCrearOt),
      body: EstadoAsync<Falla>(
        valor: falla,
        onReintentar: _recargar,
        child: (f) => ListView(
          padding: context.conBarraSistema(
            const EdgeInsets.fromLTRB(16, 14, 16, 12),
          ),
          children: [
            _cabecera(f),
            if (f.equipoConHistorial) ...[
              const SizedBox(height: 12),
              SgAviso(
                'Este equipo acumula ${f.PROVISORIAS_DEL_EQUIPO} reparaciones '
                'provisorias. Conviene un diagnóstico definitivo antes de otro '
                'parche.',
                icono: Icons.repeat,
                color: sg.ambarTexto,
              ),
            ],
            if (f.resuelta) ...[
              const SizedBox(height: 12),
              SgAviso(
                'Resuelta el ${_fecha.format(f.FAL_FECHA_SOLUCION_UTC!.toLocal())} '
                'con una acción definitiva.',
                icono: Icons.check_circle_outline,
                color: sg.verdeTexto,
              ),
            ],

            const SizedBox(height: 18),
            SgRotuloConAccion(
              'Qué se encontró',
              accion: puedeRegistrar ? 'Agregar' : '',
              onTap: puedeRegistrar
                  ? () async {
                      final ok = await _HojaDiagnostico.abrir(context, f);
                      if (ok) _recargar();
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            _Diagnosticos(fallaId: widget.fallaId),

            const SizedBox(height: 18),
            SgRotuloConAccion(
              'Qué se hizo',
              accion: puedeRegistrar && !f.resuelta ? 'Agregar' : '',
              onTap: puedeRegistrar && !f.resuelta
                  ? () async {
                      final ok = await _HojaAccion.abrir(context, f);
                      if (ok) _recargar();
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            _Acciones(fallaId: widget.fallaId),

            const SizedBox(height: 18),
            SgRotuloConAccion(
              'Cuánto estuvo detenido',
              accion: puedeRegistrar ? 'Registrar' : '',
              onTap: puedeRegistrar
                  ? () => HojaIndisponibilidad.abrir(
                      context,
                      activoId: f.FAL_ACTIVO,
                      activoNombre: f.activo,
                      fallaId: f.FAL_ID,
                      origenFalla: true,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            BloqueIndisponibilidad(clave: ('FALLA', widget.fallaId)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(Falla f) {
    final sg = context.sg;
    return SgCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SgBadge(
                f.CRITICIDAD_NOMBRE ?? '',
                color: TarjetaFalla.colorCriticidad(sg, f.FAL_CRITICIDAD_NIVEL),
                chico: true,
              ),
              const SizedBox(width: 6),
              SgBadge(
                f.situacion,
                color: TarjetaFalla.colorSituacion(sg, f),
                chico: true,
              ),
              if (f.FAL_DETUVO_PRODUCCION) ...[
                const SizedBox(width: 6),
                SgBadge(
                  'Detuvo producción',
                  color: sg.rojoTexto,
                  icono: Icons.factory_outlined,
                  chico: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(f.FAL_TITULO, style: sora(18, 700, color: sg.tinta)),
          const SizedBox(height: 10),
          SgFila(
            icono: Icons.view_in_ar_outlined,
            texto: f.activo,
            detalle: f.COMPONENTE_NOMBRE,
            alto: 44,
          ),
          if (f.FAL_FECHA_DETECCION_UTC != null)
            SgFila(
              icono: Icons.schedule,
              texto: 'Detectada',
              valor: _fecha.format(f.FAL_FECHA_DETECCION_UTC!.toLocal()),
              alto: 44,
            ),
          if ((f.REPORTA_NOMBRE ?? '').isNotEmpty)
            SgFila(
              icono: Icons.person_outline,
              texto: 'Reportó',
              valor: f.REPORTA_NOMBRE!,
              alto: 44,
            ),
          if ((f.ESTADO_POSTERIOR_NOMBRE ?? '').isNotEmpty)
            SgFila(
              icono: Icons.swap_vert,
              texto: 'Equipo quedó',
              valor: f.ESTADO_POSTERIOR_NOMBRE!,
              alto: 44,
            ),
          if (f.ORDENES > 0)
            SgFila(
              icono: Icons.build_outlined,
              texto: 'Órdenes',
              valor: '${f.ORDENES} · última OT-${f.ULTIMA_OT_CORRELATIVO}',
              alto: 44,
            ),
          if ((f.FAL_DESCRIPCION ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              f.FAL_DESCRIPCION!,
              style: sora(13, 500, color: sg.tinta2, alto: 1.45),
            ),
          ],
          if ((f.FAL_CONSECUENCIA ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Consecuencia: ${f.FAL_CONSECUENCIA!}',
              style: sora(13, 500, color: sg.tinta2, alto: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _pie(Falla f, bool puedeCrearOt) {
    if (f.resuelta || !puedeCrearOt) return null;
    return SgPie(
      child: SgBoton(
        'Abrir orden correctiva',
        icono: Icons.build_outlined,
        cargando: _ocupado,
        onTap: () => _generarOrden(f),
      ),
    );
  }
}

// -------------------------------------------------------------- BLOQUES ----

class _Diagnosticos extends ConsumerWidget {
  const _Diagnosticos({required this.fallaId});
  final int fallaId;

  static final _fecha = DateFormat('dd-MM · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    return EstadoAsync<List<FallaDiagnostico>>(
      valor: ref.watch(diagnosticosProvider(fallaId)),
      alturaCarga: 70,
      onReintentar: () => ref.invalidate(diagnosticosProvider(fallaId)),
      estaVacio: (l) => l.isEmpty,
      vacio: SgAviso(
        'Todavía no hay diagnósticos.',
        icono: Icons.search_outlined,
        color: sg.tinta2,
      ),
      child: (lista) => SgBloque(
        filas: [
          for (final d in lista)
            SgFila(
              icono: d.FDI_ES_DEFINITIVO ? Icons.star : Icons.star_outline,
              colorIcono: d.FDI_ES_DEFINITIVO ? sg.verdeTexto : sg.tinta3,
              texto: d.FDI_DESCRIPCION,
              detalle: [
                d.FDI_ES_DEFINITIVO ? 'Definitivo' : 'Hipótesis',
                d.METODO_NOMBRE,
                if (d.FDI_CONFIANZA != null)
                  'confianza ${d.FDI_CONFIANZA!.round()}%',
                d.DIAGNOSTICA_NOMBRE,
                if (d.FDI_FECHA_DIAGNOSTICO_UTC != null)
                  _fecha.format(d.FDI_FECHA_DIAGNOSTICO_UTC!.toLocal()),
              ].where((s) => (s ?? '').isNotEmpty).join(' · '),
              alto: 64,
            ),
        ],
      ),
    );
  }
}

class _Acciones extends ConsumerWidget {
  const _Acciones({required this.fallaId});
  final int fallaId;

  static final _fecha = DateFormat('dd-MM · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    return EstadoAsync<List<FallaAccion>>(
      valor: ref.watch(accionesFallaProvider(fallaId)),
      alturaCarga: 70,
      onReintentar: () => ref.invalidate(accionesFallaProvider(fallaId)),
      estaVacio: (l) => l.isEmpty,
      vacio: SgAviso(
        'Todavía no hay acciones.',
        icono: Icons.handyman_outlined,
        color: sg.tinta2,
      ),
      child: (lista) => SgBloque(
        filas: [
          for (final a in lista)
            SgFila(
              icono: a.FAC_ES_DEFINITIVA
                  ? Icons.check_circle
                  : Icons.build_circle_outlined,
              colorIcono: a.FAC_ES_DEFINITIVA ? sg.verdeTexto : sg.ambarTexto,
              texto: a.FAC_DESCRIPCION,
              detalle: [
                a.FAC_ES_DEFINITIVA ? 'Definitiva' : 'Provisoria',
                if (a.OT_CORRELATIVO != null) 'OT-${a.OT_CORRELATIVO}',
                a.EJECUTA_NOMBRE,
                if (a.FAC_FECHA_ACCION_UTC != null)
                  _fecha.format(a.FAC_FECHA_ACCION_UTC!.toLocal()),
              ].where((s) => (s ?? '').isNotEmpty).join(' · '),
              alto: 64,
            ),
        ],
      ),
    );
  }
}

/// Los periodos de detención, por orden o por falla. Lo usan las dos fichas.
class BloqueIndisponibilidad extends ConsumerWidget {
  const BloqueIndisponibilidad({super.key, required this.clave});

  /// `('ORDEN', id)` o `('FALLA', id)`.
  final (String, int) clave;

  static final _fecha = DateFormat('dd-MM · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    return EstadoAsync<List<Indisponibilidad>>(
      valor: ref.watch(indisponibilidadesProvider(clave)),
      alturaCarga: 70,
      onReintentar: () => ref.invalidate(indisponibilidadesProvider(clave)),
      estaVacio: (l) => l.isEmpty,
      vacio: SgAviso(
        'Sin paradas registradas.',
        icono: Icons.power_outlined,
        color: sg.tinta2,
      ),
      child: (lista) => SgBloque(
        filas: [
          for (final i in lista)
            SgFila(
              icono: i.abierta
                  ? Icons.power_off_outlined
                  : Icons.power_settings_new,
              colorIcono: i.abierta ? sg.rojoTexto : sg.tinta2,
              texto: i.abierta
                  ? 'Detenido desde ${_fecha.format(i.AIN_FECHA_INICIO_UTC.toLocal())}'
                  : '${_fecha.format(i.AIN_FECHA_INICIO_UTC.toLocal())} → '
                        '${_fecha.format(i.AIN_FECHA_FIN_UTC!.toLocal())}',
              detalle: [
                i.AIN_PLANIFICADA ? 'Planificada' : 'No planificada',
                if (i.AIN_DETUVO_PRODUCCION) 'detuvo producción',
                i.MOTIVO_NOMBRE ?? i.AIN_MOTIVO,
              ].where((s) => (s ?? '').isNotEmpty).join(' · '),
              valor: i.duracion,
              alto: 64,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- HOJAS ----

/// Agregar un diagnóstico. Definitivo desmarca los anteriores (lo hace el SP).
class _HojaDiagnostico extends ConsumerStatefulWidget {
  const _HojaDiagnostico({required this.falla});
  final Falla falla;

  static Future<bool> abrir(BuildContext context, Falla falla) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaDiagnostico(falla: falla),
    );
    return r ?? false;
  }

  /// Diagnostico_Metodo, catálogo fijo del sistema.
  static const List<(int, String)> metodos = [
    (1, 'Inspección visual'),
    (2, 'Medición'),
    (3, 'Vibración'),
    (4, 'Termografía'),
    (5, 'Aceite'),
    (6, 'Ultrasonido'),
    (7, 'Desarme'),
    (8, 'Historial'),
    (9, 'Análisis con IA'),
  ];

  @override
  ConsumerState<_HojaDiagnostico> createState() => _HojaDiagnosticoState();
}

class _HojaDiagnosticoState extends ConsumerState<_HojaDiagnostico> {
  final _texto = TextEditingController();
  final String _uuid = OutboxService.nuevoUuid();
  int? _metodo;
  bool _definitivo = false;
  double _confianza = 70;
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _guardando) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await OutboxService.instance.encolar(
        tipo: 'DIAGNOSTICO',
        titulo: 'Diagnóstico de ${widget.falla.codigo}',
        detalle: texto,
        endpoint: '${ApiConstants.fallas}/${widget.falla.FAL_ID}/diagnosticos',
        uuid: _uuid,
        cuerpo: {
          'uuid': _uuid,
          'metodo': _metodo,
          'descripcion': texto,
          'es_definitivo': _definitivo,
          'confianza': _confianza.round(),
        },
      );
      SyncService.instance.despacharAhora();
      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Diagnóstico registrado.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return HojaRecurso(
      titulo: 'Qué se encontró',
      detalle: '${widget.falla.codigo} · ${widget.falla.FAL_TITULO}',
      children: [
        SgCampo(
          controlador: _texto,
          icono: Icons.search_outlined,
          hint: 'Polea desalineada 4 mm; la correa roza la guarda',
          lineas: 3,
          autoenfoque: true,
          conVoz: true,
          onCambio: (_) => setState(() {}),
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Diagnóstico',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'diagnostico',
                  rotulo: 'Diagnóstico',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_texto, campos.first.valor));
          },
        ),
        const SizedBox(height: 14),
        const SgRotuloCampo('Cómo se llegó'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, nombre) in _HojaDiagnostico.metodos)
              SgChip(
                nombre,
                elegido: _metodo == id,
                onTap: () =>
                    setState(() => _metodo = _metodo == id ? null : id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SgCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              SgFila(
                icono: Icons.star_outline,
                texto: 'Es el diagnóstico definitivo',
                detalle: 'Los anteriores pasan a hipótesis',
                derecha: Switch(
                  value: _definitivo,
                  onChanged: (v) => setState(() => _definitivo = v),
                ),
              ),
              Divider(height: 1, color: sg.div),
              SgFila(
                icono: Icons.percent,
                texto: 'Confianza',
                valor: '${_confianza.round()}%',
              ),
              Slider(
                value: _confianza,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _confianza = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SgBoton(
          'Registrar diagnóstico',
          icono: Icons.check,
          cargando: _guardando,
          onTap: _texto.text.trim().isEmpty || _guardando ? null : _guardar,
        ),
      ],
    );
  }
}

/// Agregar una acción. Provisoria mantiene la falla abierta; definitiva la
/// resuelve (lo hace el SP).
class _HojaAccion extends ConsumerStatefulWidget {
  const _HojaAccion({required this.falla});
  final Falla falla;

  static Future<bool> abrir(BuildContext context, Falla falla) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaAccion(falla: falla),
    );
    return r ?? false;
  }

  @override
  ConsumerState<_HojaAccion> createState() => _HojaAccionState();
}

class _HojaAccionState extends ConsumerState<_HojaAccion> {
  final _texto = TextEditingController();
  final String _uuid = OutboxService.nuevoUuid();
  bool _definitiva = false;
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _guardando) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await OutboxService.instance.encolar(
        tipo: 'ACCION_FALLA',
        titulo:
            '${_definitiva ? 'Reparación' : 'Reparación provisoria'} de '
            '${widget.falla.codigo}',
        detalle: texto,
        endpoint: '${ApiConstants.fallas}/${widget.falla.FAL_ID}/acciones',
        uuid: _uuid,
        cuerpo: {
          'uuid': _uuid,
          'descripcion': texto,
          'es_definitiva': _definitiva,
          'fecha_accion_utc': DateTime.now().toUtc().toIso8601String(),
        },
      );
      SyncService.instance.despacharAhora();
      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? (_definitiva
                      ? 'Acción registrada. La falla queda resuelta.'
                      : 'Acción provisoria registrada.')
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return HojaRecurso(
      titulo: 'Qué se hizo',
      detalle: '${widget.falla.codigo} · ${widget.falla.FAL_TITULO}',
      children: [
        SgCampo(
          controlador: _texto,
          icono: Icons.handyman_outlined,
          hint: 'Se cambió la correa y se alineó la polea',
          lineas: 3,
          autoenfoque: true,
          conVoz: true,
          onCambio: (_) => setState(() {}),
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Qué se hizo',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'accion',
                  rotulo: 'Acción',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_texto, campos.first.valor));
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SgChip(
                'Provisoria',
                icono: Icons.build_circle_outlined,
                elegido: !_definitiva,
                onTap: () => setState(() => _definitiva = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SgChip(
                'Definitiva',
                icono: Icons.check_circle_outline,
                elegido: _definitiva,
                onTap: () => setState(() => _definitiva = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SgAviso(
          _definitiva
              ? 'La falla queda resuelta con la fecha de ahora.'
              : 'La falla sigue abierta: un parche para seguir produciendo '
                    'hasta la reparación de fondo.',
          icono: Icons.info_outline,
          color: _definitiva ? sg.verdeTexto : sg.ambarTexto,
        ),
        const SizedBox(height: 16),
        SgBoton(
          'Registrar acción',
          icono: Icons.check,
          cargando: _guardando,
          onTap: _texto.text.trim().isEmpty || _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
