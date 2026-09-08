import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/sync_service.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'tarea_ficha_screen.dart';

/// Tareas en terreno · la bandeja — HU-103.
///
/// ## Una tarea no es una orden chica
///
/// Es el trabajo breve que hoy no deja registro: revisar un nivel, limpiar un
/// filtro, apretar un prensaestopas. Abrir una OT para eso es tanto papeleo
/// que nadie lo hace, y lo que no se registra no existe —ni para el historial
/// del activo ni para dimensionar la carga real del equipo—.
///
/// ## Lo vencido arriba, y el orden lo decide el servidor
///
/// La situación (`VENCIDA`, `VENCE HOY`, `EN PLAZO`) viene calculada del SP.
/// Si la calculara la app, dos teléfonos con distinta hora dirían cosas
/// distintas sobre la misma tarea.
class TareasScreen extends ConsumerWidget {
  const TareasScreen({super.key, this.embebida = false});

  /// Dibujada DENTRO de «Mi trabajo», sin su propio `Scaffold` ni su barra.
  ///
  /// La misma lista sirve en los dos sitios —la bandeja y su acceso directo—
  /// y por eso no se duplica: dos copias de la tarjeta serían dos sitios donde
  /// arreglar el mismo defecto.
  final bool embebida;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final pendientes = ref.watch(tareasPendientesProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      // Embebida en «Mi trabajo» no lleva barra propia: la bandeja ya
      // puso el título y las pestañas, y dos cabeceras seguidas se comen
      // media pantalla en un teléfono.
      appBar: embebida
          ? null
          : SgBarra(
        'Mis tareas',
        tamanoTitulo: 23,
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => enLinea
                  ? const SizedBox.shrink()
                  : SgBadge('Sin conexión',
                      color: sg.tinta2, icono: Icons.cloud_off_outlined),
            ),
          ),
        ],
      ),
      body: EstadoAsync<List<TareaPendiente>>(
        valor: pendientes,
        onReintentar: () => ref.invalidate(tareasPendientesProvider),
        estaVacio: (l) => l.isEmpty,
        vacio: const EstadoVacio(
          icono: Icons.task_alt,
          titulo: 'No tienes tareas pendientes',
          detalle: 'Las tareas se programan desde la web. Cuando te toque una, '
              'aparece acá y se puede hacer sin señal.',
        ),
        child: (sinOrdenar) {
          /* LO FIJADO VA ARRIBA

             Es lo que hace útil a la estrella: si el favorito solo se viera
             dentro de su propio filtro habría que ir a buscarlo, y entonces
             marcarlo no ahorra nada.

             `sort` sobre una copia y estable: el orden que trae el servidor
             —lo más urgente primero— se conserva dentro de cada grupo. */
          final lista = [...sinOrdenar]..sort((a, b) {
              if (a.ES_FAVORITO == b.ES_FAVORITO) return 0;
              return a.ES_FAVORITO ? -1 : 1;
            });

          return RefreshIndicator(
          onRefresh: () async => ref.invalidate(tareasPendientesProvider),
          child: ListView.separated(
            padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 11),
            itemBuilder: (_, i) => _Tarjeta(
              tarea: lista[i],
              onAbrir: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TareaFichaScreen(ocurrenciaId: lista[i].toc_id),
                ));
                ref.invalidate(tareasPendientesProvider);
              },
            ),
          ),
        );
        },
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.tarea, required this.onAbrir});

  final TareaPendiente tarea;
  final VoidCallback onAbrir;

  static final _hora = DateFormat('HH:mm');
  static final _dia = DateFormat('d MMM', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final limite = tarea.toc_fecha_limite_utc?.toLocal();

    // La crítica y la vencida son las dos que no pueden pasar desapercibidas,
    // y por eso son las únicas elevadas: si se elevaran todas, elevar dejaría
    // de significar algo.
    final urgente = tarea.vencida || tarea.critica;

    final colorPlazo = tarea.vencida
        ? sg.rojoTexto
        : tarea.venceHoy
            ? sg.ambarTexto
            : sg.tinta3;

    return SgCard(
      padding: const EdgeInsets.all(14),
      elevada: urgente,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La foto del equipo cuando la hay; el ícono de la tarea
              // cuando no. Sin activo asociado —una ronda de limpieza— el
              // ícono es lo correcto: no hay equipo que reconocer.
              if ((tarea.ACTIVO_FOTO ?? '').isNotEmpty)
                SigmaImagen(
                  ruta: tarea.ACTIVO_FOTO,
                  ancho: 44,
                  alto: 44,
                  radio: SgRadius.icono48,
                  titulo: tarea.activo,
                )
              else
                SgIconoCuadro(
                  tarea.tar_requiere_evidencia
                      ? Icons.photo_camera_outlined
                      : Icons.task_alt,
                  color: tarea.vencida ? sg.rojoTexto : sg.acentoTexto,
                  lado: 44,
                  tamanoIcono: 22,
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
                        if (tarea.vencida)
                          SgBadge('Vencida', color: sg.rojoTexto, chico: true),
                        if (tarea.critica)
                          SgBadge(tarea.PRIORIDAD_NOMBRE ?? 'Crítica',
                              color: sg.rojoTexto,
                              icono: Icons.priority_high,
                              chico: true),
                        if (tarea.empezada)
                          SgBadge('Empezada',
                              color: sg.ambarTexto,
                              icono: Icons.play_arrow,
                              chico: true),
                        if (tarea.COMENTARIOS > 0)
                          SgBadge('${tarea.COMENTARIOS}',
                              color: sg.tinta2,
                              icono: Icons.chat_bubble_outline,
                              chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(tarea.tar_titulo,
                              style: sora(16, 600,
                                  color: sg.tinta, alto: 1.35)),
                        ),
                        const SizedBox(width: 6),
                        // El mismo gesto que en las órdenes: una estrella que
                        // significa lo mismo en las dos bandejas, y no dos
                        // formas de fijar según dónde se esté.
                        _Estrella(
                          // La clave es del REGISTRO, no de la posición: la
                          // lista se reordena —los favoritos suben— y sin ella
                          // Flutter reutiliza el estado de la fila que estaba
                          // ahí antes, así que la estrella encendida se queda
                          // en el sitio en vez de seguir a su orden.
                          key: ValueKey(tarea.toc_id),
                          tarea: tarea,
                        ),
                      ],
                    ),
                    // Qué equipo, y después dónde está.
                    if (tarea.activo.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _Renglon(
                        icono: Icons.view_in_ar_outlined,
                        texto: tarea.activo,
                        color: sg.tinta2,
                      ),
                    ],
                    if (tarea.donde.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _Renglon(
                        icono: Icons.place_outlined,
                        texto: tarea.donde,
                        color: sg.tinta3,
                      ),
                    ],
                    if (limite != null) ...[
                      const SizedBox(height: 4),
                      _Renglon(
                        icono: Icons.schedule,
                        texto: _plazo(limite),
                        color: colorPlazo,
                      ),
                    ],
                    if (tarea.tar_duracion_estimada_minuto != null) ...[
                      const SizedBox(height: 4),
                      _Renglon(
                        icono: Icons.timer_outlined,
                        texto: 'Toma unos ${tarea.tar_duracion_estimada_minuto} min',
                        color: sg.tinta3,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SgBoton(
            tarea.empezada ? 'Continuar' : 'Empezar',
            icono: tarea.empezada ? Icons.play_arrow : Icons.arrow_forward,
            iconoAlFinal: !tarea.empezada,
            alto: 44,
            tamanoTexto: 14,
            onTap: onAbrir,
          ),
        ],
      ),
    );
  }

  String _plazo(DateTime limite) {
    final hoy = DateTime.now();
    final mismoDia = limite.year == hoy.year &&
        limite.month == hoy.month &&
        limite.day == hoy.day;

    if (tarea.vencida) return 'Venció el ${_dia.format(limite)}';
    if (mismoDia) return 'Hasta las ${_hora.format(limite)}';
    return 'Hasta el ${_dia.format(limite)}';
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(texto,
                style: sora(12, 500, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}


/// La estrella de una tarea. Ver `_Estrella` de la bandeja de órdenes: mismo
/// comportamiento —se pinta al instante y se corrige si el servidor discrepa—
/// porque es el mismo gesto.
class _Estrella extends ConsumerStatefulWidget {
  const _Estrella({super.key, required this.tarea});

  final TareaPendiente tarea;

  @override
  ConsumerState<_Estrella> createState() => _EstrellaState();
}

class _EstrellaState extends ConsumerState<_Estrella> {
  bool? _local;
  bool _ocupado = false;

  bool get _marcada => _local ?? widget.tarea.ES_FAVORITO;

  Future<void> _alternar() async {
    if (_ocupado) return;
    final mensajero = ScaffoldMessenger.of(context);
    final antes = _marcada;

    setState(() {
      _local = !antes;
      _ocupado = true;
    });

    try {
      final ahora = await SigmaRepository.instance
          .alternarFavorito('TAREA', widget.tarea.toc_id);
      if (!mounted) return;
      setState(() => _local = ahora);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _local = antes);
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgBotonIcono(
      _marcada ? Icons.star : Icons.star_border,
      color: _marcada ? sg.ambarTexto : sg.tinta3,
      lado: 34,
      tamano: 20,
      onTap: _alternar,
    );
  }
}
