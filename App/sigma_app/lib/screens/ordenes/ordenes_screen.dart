import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'orden_ficha_screen.dart';

final busquedaOrdenProvider = StateProvider<String>((ref) => '');

/// 6.1 · Mi trabajo — HU-121.
///
/// Layout del artboard: título 23/700 con el badge de conexión; buscador de 52
/// en píldora **con micrófono**; chips de 34 donde el activo va relleno de
/// morado y su contador en blanco al 24 %; tarjetas de 22 con miniatura
/// 60/17, chips de 24, barra de avance de 6 y fila de acciones.
///
/// ## Los tres ámbitos son tres preguntas distintas
///
/// **Hoy** es lo que vence hoy o está vencido: lo que no puede esperar.
/// **Mías** es todo lo que tengo asignado.
/// **Disponibles** son las abiertas sin dueño — y esa existe para que un
/// técnico que terminó antes tome trabajo en vez de irse, que es la diferencia
/// entre una bandeja y una lista.
class OrdenesScreen extends ConsumerStatefulWidget {
  const OrdenesScreen({super.key});

  @override
  ConsumerState<OrdenesScreen> createState() => _OrdenesScreenState();
}

class _OrdenesScreenState extends ConsumerState<OrdenesScreen> {
  final _buscar = TextEditingController();

  /// 0 = hoy, 1 = mías, 2 = disponibles.
  int _pestana = 0;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    // Hoy y Mías salen de la misma consulta (ámbito 1) y se filtran acá: son
    // el mismo conjunto visto de dos formas, y pedirlo dos veces sería un
    // viaje de red de más con señal de planta.
    final mias = ref.watch(ordenesTrabajoProvider);
    final disponibles = ref.watch(ordenesDisponiblesProvider);

    final filtro = ref.watch(busquedaOrdenProvider).trim().toLowerCase();
    final listaMias = mias.valueOrNull ?? const <OrdenTrabajo>[];
    final hoy = listaMias.where(_apremia).toList();

    var visibles = switch (_pestana) {
      0 => hoy,
      1 => listaMias,
      _ => disponibles.valueOrNull ?? const <OrdenTrabajo>[],
    };
    if (filtro.isNotEmpty) {
      visibles = visibles.where((o) => _coincide(o, filtro)).toList();
    }

    final fuente = _pestana == 2 ? disponibles : mias;

    return Scaffold(
      backgroundColor: sg.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Cabecera(),
            _Filtros(
              buscar: _buscar,
              pestana: _pestana,
              hoy: hoy.length,
              mias: listaMias.length,
              disponibles: (disponibles.valueOrNull ?? const []).length,
              onPestana: (i) => setState(() => _pestana = i),
              onBuscar: (v) =>
                  ref.read(busquedaOrdenProvider.notifier).state = v,
            ),
            Expanded(
              child: EstadoAsync<List<OrdenTrabajo>>(
                valor: fuente,
                onReintentar: () {
                  ref.invalidate(ordenesTrabajoProvider);
                  ref.invalidate(ordenesDisponiblesProvider);
                },
                estaVacio: (_) => visibles.isEmpty,
                vacio: EstadoVacio(
                  icono: filtro.isNotEmpty
                      ? Icons.search_off
                      : Icons.assignment_turned_in_outlined,
                  titulo: switch (_pestana) {
                    _ when filtro.isNotEmpty => 'Nada coincide',
                    0 => 'Nada apremia hoy',
                    1 => 'No tienes órdenes asignadas',
                    _ => 'No hay trabajo disponible',
                  },
                  detalle: switch (_pestana) {
                    0 => 'Lo que vence hoy o está vencido aparece acá. Mira '
                        '«Mías» para el resto de tu carga.',
                    1 => 'Cuando el planificador te asigne una orden, o tomes '
                        'una de las disponibles, aparece acá.',
                    _ => 'Todas las órdenes abiertas ya tienen responsable.',
                  },
                ),
                child: (_) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordenesTrabajoProvider);
                    ref.invalidate(ordenesDisponiblesProvider);
                  },
                  child: ListView.separated(
                    padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 0, 16, 24)),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 11),
                    itemBuilder: (_, i) => _Tarjeta(
                      orden: visibles[i],
                      destacada: i == 0 && visibles[i].vencida,
                      onAbrir: () => _abrir(visibles[i]),
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

  Future<void> _abrir(OrdenTrabajo o) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrdenFichaScreen(ordenId: o.otr_id)),
    );
    if (!mounted) return;
    ref.invalidate(ordenesTrabajoProvider);
    ref.invalidate(ordenesDisponiblesProvider);
  }

  /// Lo que no puede esperar: vencido o vence hoy.
  static bool _apremia(OrdenTrabajo o) {
    final s = (o.SITUACION ?? '').toUpperCase();
    return s == 'VENCIDA' || s == 'VENCE HOY';
  }

  static bool _coincide(OrdenTrabajo o, String f) => [
        o.OT_NUMERO,
        o.otr_titulo,
        o.ACTIVO_CODIGO ?? '',
        o.ACTIVO_NOMBRE ?? '',
        o.AREA_NOMBRE ?? '',
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

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.buscar,
    required this.pestana,
    required this.hoy,
    required this.mias,
    required this.disponibles,
    required this.onPestana,
    required this.onBuscar,
  });

  final TextEditingController buscar;
  final int pestana;
  final int hoy;
  final int mias;
  final int disponibles;
  final ValueChanged<int> onPestana;
  final ValueChanged<String> onBuscar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      controller: buscar,
                      onChanged: onBuscar,
                      style: sora(16, 500, color: sg.tinta),
                      cursorColor: sg.primario,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'OT, activo, código o ubicación',
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
                                    'El dictado en la búsqueda llega más adelante.')),
                          )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _Chip('Hoy',
                  contador: hoy,
                  colorContador: SgColor.rojo,
                  elegido: pestana == 0,
                  onTap: () => onPestana(0)),
              const SizedBox(width: 8),
              _Chip('Mías',
                  contador: mias,
                  elegido: pestana == 1,
                  onTap: () => onPestana(1)),
              const SizedBox(width: 8),
              _Chip('Disponibles',
                  contador: disponibles,
                  colorContador: SgColor.verde,
                  elegido: pestana == 2,
                  onTap: () => onPestana(2)),
            ],
          ),
        ],
      ),
    );
  }
}

/// El chip de 34 de la bandeja.
///
/// A diferencia del de 28 del resto de la app, **el elegido va relleno de
/// morado** y su contador en blanco translúcido. Es el único filtro del kit
/// que manda sobre una lista entera, y por eso pesa más.
class _Chip extends StatelessWidget {
  const _Chip(
    this.texto, {
    required this.elegido,
    required this.onTap,
    this.contador = 0,
    this.colorContador,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;
  final int contador;
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
            if (contador > 0) ...[
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
                child: Text('$contador',
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
  const _Tarjeta({
    required this.orden,
    required this.destacada,
    required this.onAbrir,
  });

  final OrdenTrabajo orden;
  final bool destacada;
  final VoidCallback onAbrir;

  /// El color de la prioridad. Lo decide el catálogo del servidor, no la
  /// pantalla: acá solo se pinta.
  Color _prioridad(AppColors sg) => switch (orden.PRIORIDAD_ID) {
        4 => sg.rojoTexto,
        3 => sg.ambarTexto,
        2 => sg.azulTexto,
        _ => sg.tinta2,
      };

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final colorPrioridad = _prioridad(sg);

    return SgCard(
      padding: const EdgeInsets.all(14),
      elevada: destacada,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La foto del equipo, que es lo que hace reconocer el trabajo
              // sin abrirlo. Tres órdenes del mismo activo comparten una sola
              // descarga: `ImagenService` deduplica por ruta y la deja en
              // disco. Sin foto cargada queda el hueco del kit, no un error.
              if ((orden.ACTIVO_FOTO ?? '').isEmpty)
                const SgFoto(
                    lado: 60, radio: 17, icono: Icons.build_circle_outlined)
              else
                SigmaImagen(
                  ruta: orden.ACTIVO_FOTO,
                  ancho: 60,
                  alto: 60,
                  radio: 17,
                  titulo: orden.activo,
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
                        if ((orden.PRIORIDAD_NOMBRE ?? '').isNotEmpty)
                          SgBadge(orden.PRIORIDAD_NOMBRE!,
                              color: colorPrioridad,
                              icono: orden.PRIORIDAD_ID >= 3
                                  ? Icons.arrow_upward
                                  : null,
                              chico: true),
                        if ((orden.TIPO_NOMBRE ?? '').isNotEmpty)
                          SgBadge(orden.TIPO_NOMBRE!,
                              color: sg.tinta2, chico: true),
                        if (orden.vencida)
                          SgBadge('Vencida',
                              color: sg.rojoTexto, chico: true),
                        if (orden.enEjecucion)
                          SgBadge('En ejecución',
                              color: sg.ambarTexto,
                              icono: Icons.build,
                              chico: true),
                        if (orden.abierta && orden.sinResponsable)
                          SgBadge('Disponible',
                              color: sg.acentoTexto,
                              icono: Icons.pan_tool_outlined,
                              chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${orden.OT_NUMERO} · ${orden.otr_titulo}',
                        style: sora(16, 600, color: sg.tinta, alto: 1.35)),
                    // Qué equipo es, antes de dónde está: en una bandeja
                    // de doce órdenes eso es lo que se busca primero.
                    if (orden.activo.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.view_in_ar_outlined,
                              size: 14, color: sg.tinta2),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              orden.activo,
                              style: sora(12, 600, color: sg.tinta2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 14, color: sg.tinta3),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            orden.ubicacion.isEmpty
                                ? 'Sin activo asociado'
                                : orden.ubicacion,
                            style: sora(12, 500, color: sg.tinta3),
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

          // La barra de pasos solo aparece si ya empezó: en una orden abierta
          // «0 / 5» no informa nada y ocupa una línea.
          if (orden.enEjecucion && orden.PASOS_TOTAL > 0) ...[
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
                          widthFactor: orden.avance,
                          child: Container(height: 6, color: SgColor.ambar),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${orden.PASOS_LISTOS} / ${orden.PASOS_TOTAL} pasos',
                    style: sora(12, 600, color: sg.tinta2, tabular: true)),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SgBoton(
                  orden.enEjecucion
                      ? 'Continuar'
                      : (orden.sinResponsable ? 'Tomar trabajo' : 'Abrir'),
                  icono: orden.enEjecucion
                      ? Icons.play_arrow
                      : (orden.sinResponsable
                          ? Icons.pan_tool_outlined
                          : Icons.chevron_right),
                  primario: orden.enEjecucion,
                  alto: 44,
                  tamanoTexto: 14,
                  colorIcono: orden.sinResponsable && !orden.enEjecucion
                      ? sg.acentoTexto
                      : null,
                  onTap: onAbrir,
                ),
              ),
              if (orden.otr_requiere_permiso) ...[
                const SizedBox(width: 9),
                Tooltip(
                  message: 'Requiere permiso de trabajo',
                  child: SgBotonIcono(Icons.engineering,
                      fondo: sg.tinte(sg.ambarTexto),
                      color: sg.ambarTexto,
                      onTap: onAbrir),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
