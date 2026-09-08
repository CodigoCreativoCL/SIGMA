import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Qué se está mirando en la bandeja.
enum FiltroTrabajo { hoy, prioritarios, todos }

final filtroTrabajoProvider =
    StateProvider<FiltroTrabajo>((ref) => FiltroTrabajo.hoy);
final busquedaTrabajoProvider = StateProvider<String>((ref) => '');

/// 6.1 · Mi trabajo — HU-112, HU-113, HU-121.
///
/// Layout del artboard: título 23/700 con el badge de conexión a la derecha;
/// buscador de 52 en píldora **con micrófono**; tira de chips de 34 donde el
/// activo va relleno de morado y su contador en blanco al 24 %; tarjetas de 22
/// con miniatura 60/17, chips de 24, barra de avance de 6 y fila de acciones.
///
/// ## Qué muestra hoy
///
/// El kit la dibuja con **órdenes de trabajo**, que SIGMA todavía no expone.
/// Lo que sí existe y ocupa el mismo lugar en la jornada son los **permisos de
/// trabajo**: sin permiso vigente no se interviene un equipo, así que son lo
/// que de verdad ordena y bloquea el turno.
///
/// La estructura es la del kit tal cual —chips, tarjeta, prioridad, avance,
/// acciones—, y el día que exista `GET /ordenes` se cambia el provider y las
/// tarjetas sin tocar el andamiaje.
class PermisosTrabajoScreen extends ConsumerWidget {
  const PermisosTrabajoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final datos = ref.watch(permisosTrabajoProvider);
    final filtro = ref.watch(filtroTrabajoProvider);
    final busqueda = ref.watch(busquedaTrabajoProvider).trim().toLowerCase();

    final todos = datos.valueOrNull?.datos ?? const <PermisoTrabajo>[];
    final hoy = todos.where(_venceHoy).toList();
    final prioritarios = todos.where(_esPrioritario).toList();

    var visibles = switch (filtro) {
      FiltroTrabajo.hoy => hoy,
      FiltroTrabajo.prioritarios => prioritarios,
      FiltroTrabajo.todos => todos,
    };
    if (busqueda.isNotEmpty) {
      visibles = visibles.where((p) => _coincide(p, busqueda)).toList();
    }

    return Scaffold(
      backgroundColor: sg.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Cabecera(),
            _Filtros(
              hoy: hoy.length,
              prioritarios: prioritarios.length,
              onBuscar: (v) =>
                  ref.read(busquedaTrabajoProvider.notifier).state = v,
            ),
            Expanded(
              child: EstadoAsync<Paginado<PermisoTrabajo>>(
                valor: datos,
                onReintentar: () => ref.invalidate(permisosTrabajoProvider),
                estaVacio: (_) => visibles.isEmpty,
                vacio: EstadoVacio(
                  icono: busqueda.isNotEmpty
                      ? Icons.search_off
                      : Icons.assignment_turned_in_outlined,
                  titulo: switch (filtro) {
                    _ when busqueda.isNotEmpty => 'Nada coincide',
                    FiltroTrabajo.hoy => 'Nada vence hoy',
                    FiltroTrabajo.prioritarios => 'Nada urgente',
                    FiltroTrabajo.todos => 'Sin permisos de trabajo',
                  },
                  detalle:
                      'Los permisos los emite el supervisor desde la web. Acá '
                      'aparecen los que te tocan y cuánto les queda.',
                ),
                child: (_) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(permisosTrabajoProvider);
                    ref.invalidate(permisosVigentesProvider);
                  },
                  child: ListView.separated(
                    padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 0, 16, 24)),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 11),
                    itemBuilder: (_, i) => _Tarjeta(
                      permiso: visibles[i],
                      destacada: i == 0 && _esPrioritario(visibles[i]),
                    ),
                  ),
                ),
              ),
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }

  static bool _venceHoy(PermisoTrabajo p) =>
      (p.DIAS_RESTANTES ?? 99) <= 0 || (p.DIAS_RESTANTES ?? 99) == 1;

  static bool _esPrioritario(PermisoTrabajo p) {
    final s = (p.SITUACION ?? '').toUpperCase();
    return s == 'VENCIDO' || s == 'POR VENCER';
  }

  static bool _coincide(PermisoTrabajo p, String f) => [
        p.ptr_numero,
        p.TIPO_NOMBRE,
        p.ESTADO_NOMBRE,
        p.ORDEN_CORRELATIVO ?? '',
        p.ORDEN_TITULO ?? '',
        p.SOLICITANTE_NOMBRE ?? '',
      ].any((s) => s.toLowerCase().contains(f));
}

class _Cabecera extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text('Mi trabajo',
                  style: sora(23, 700, color: sg.tinta, espaciado: -0.46)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => enLinea
                  ? const SizedBox.shrink()
                  : SgBadge('Sin conexión',
                      color: sg.tinta2, icono: Icons.cloud_off_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filtros extends ConsumerStatefulWidget {
  const _Filtros({
    required this.hoy,
    required this.prioritarios,
    required this.onBuscar,
  });

  final int hoy;
  final int prioritarios;
  final ValueChanged<String> onBuscar;

  @override
  ConsumerState<_Filtros> createState() => _FiltrosState();
}

class _FiltrosState extends ConsumerState<_Filtros> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final filtro = ref.watch(filtroTrabajoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El buscador lleva micrófono: §2 del kit pide dictado por campo, y
          // buscar «OT mil ciento ochenta» con guantes es más rápido que
          // teclearlo.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.pill),
              boxShadow: sg.e1,
            ),
            child: Container(
              height: 52,
              padding: const EdgeInsets.only(left: 18, right: 8),
              decoration: BoxDecoration(
                color: sg.campo,
                borderRadius: BorderRadius.circular(SgRadius.pill),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 21, color: sg.tinta3),
                  const SizedBox(width: 11),
                  Expanded(
                    child: TextField(
                      controller: _buscar,
                      onChanged: widget.onBuscar,
                      style: sora(16, 500, color: sg.tinta),
                      cursorColor: sg.primario,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Permiso, activo o código',
                        hintStyle: sora(16, 500, color: sg.tinta3),
                      ),
                    ),
                  ),
                  SgBotonIcono(Icons.mic_none,
                      color: sg.primarioTexto,
                      tamano: 20,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'El dictado por voz llega más adelante.')),
                          )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _ChipFiltro(
                texto: 'Hoy',
                contador: widget.hoy,
                elegido: filtro == FiltroTrabajo.hoy,
                onTap: () => _cambiar(FiltroTrabajo.hoy),
              ),
              const SizedBox(width: 8),
              _ChipFiltro(
                texto: 'Prioritarios',
                contador: widget.prioritarios,
                colorContador: SgColor.rojo,
                elegido: filtro == FiltroTrabajo.prioritarios,
                onTap: () => _cambiar(FiltroTrabajo.prioritarios),
              ),
              const SizedBox(width: 8),
              _ChipFiltro(
                texto: 'Todos',
                elegido: filtro == FiltroTrabajo.todos,
                onTap: () => _cambiar(FiltroTrabajo.todos),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cambiar(FiltroTrabajo f) =>
      ref.read(filtroTrabajoProvider.notifier).state = f;
}

/// El chip de 34 de la bandeja.
///
/// A diferencia del chip de 28 del resto de la app, **el elegido va relleno de
/// morado** y su contador en blanco translúcido. Es el único filtro del kit
/// que manda sobre una lista entera, y por eso pesa más.
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.texto,
    required this.elegido,
    required this.onTap,
    this.contador,
    this.colorContador,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;
  final int? contador;
  final Color? colorContador;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tinta = elegido ? Colors.white : sg.tinta2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.pill),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: elegido ? sg.primario : sg.up,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, style: sora(13, 600, color: tinta)),
            if (contador != null && contador! > 0) ...[
              const SizedBox(width: 7),
              Container(
                height: 19,
                constraints: const BoxConstraints(minWidth: 19),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: elegido
                      ? Colors.white.withValues(alpha: 0.24)
                      : (colorContador ?? sg.primario),
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text('${contador!}',
                    style: sora(11, 700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.permiso, required this.destacada});

  final PermisoTrabajo permiso;
  final bool destacada;

  static final _fecha = DateFormat('d MMM HH:mm', 'es');

  /// El color de la situación lo decide el SP, no la pantalla: `SITUACION`
  /// viene calculada y acá solo se pinta.
  (Color, String) _situacion(AppColors sg) =>
      switch ((permiso.SITUACION ?? '').toUpperCase()) {
        'VENCIDO' => (sg.rojoTexto, 'Vencido'),
        'POR VENCER' => (sg.ambarTexto, 'Por vencer'),
        'VIGENTE' => (sg.verdeTexto, 'Vigente'),
        _ => (sg.tinta2, permiso.ESTADO_NOMBRE),
      };

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final (color, situacion) = _situacion(sg);
    final fin = permiso.ptr_fecha_vigencia_fin_utc?.toLocal();

    return SgCard(
      padding: const EdgeInsets.all(14),
      elevada: destacada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SgFoto(
                lado: 60,
                radio: 17,
                icono: permiso.TIENE_DOCUMENTO
                    ? Icons.description_outlined
                    : Icons.assignment_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SgBadge(situacion, color: color, chico: true),
                        if (permiso.TIPO_NOMBRE.isNotEmpty)
                          SgBadge(permiso.TIPO_NOMBRE,
                              color: sg.tinta2, chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [permiso.ptr_numero, permiso.ORDEN_TITULO]
                          .where((s) => (s ?? '').isNotEmpty)
                          .join(' · '),
                      style: sora(16, 600, color: sg.tinta, alto: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                            fin == null
                                ? Icons.place_outlined
                                : Icons.schedule,
                            size: 14,
                            color: fin == null ? sg.tinta3 : color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            [
                              if (fin != null) 'Vence ${_fecha.format(fin)}',
                              if (permiso.SOLICITANTE_NOMBRE != null)
                                permiso.SOLICITANTE_NOMBRE!,
                            ].join(' · '),
                            style: sora(12, 500,
                                color: fin == null ? sg.tinta3 : color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // La barra de días es la del kit, con el dato que sí existe: cuánto
          // le queda de vigencia respecto de los siete días que dura un
          // permiso corriente.
          if (permiso.DIAS_RESTANTES != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                    child: Stack(
                      children: [
                        Container(height: 6, color: sg.up),
                        FractionallySizedBox(
                          widthFactor:
                              (permiso.DIAS_RESTANTES! / 7).clamp(0.0, 1.0),
                          child: Container(height: 6, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  permiso.DIAS_RESTANTES! <= 0
                      ? 'vencido'
                      : '${permiso.DIAS_RESTANTES} ${permiso.DIAS_RESTANTES == 1 ? "día" : "días"}',
                  style: sora(12, 600, color: sg.tinta2, tabular: true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
