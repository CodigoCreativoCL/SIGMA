import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../bitacora/entrada_bitacora_screen.dart';
import '../bitacora/nueva_entrada_screen.dart';
import '../checklist/checklist_screen.dart';
import '../ordenes/ordenes_screen.dart';
import '../tareas/tareas_screen.dart';

/// Qué se está mirando en la bandeja.
enum TipoTrabajo { todo, ordenes, tareas, pautas, bitacora }

extension _Rotulo on TipoTrabajo {
  String get texto => switch (this) {
        TipoTrabajo.todo => 'Todo',
        TipoTrabajo.ordenes => 'Órdenes',
        TipoTrabajo.tareas => 'Tareas',
        TipoTrabajo.pautas => 'Pautas',
        TipoTrabajo.bitacora => 'Bitácora',
      };

  IconData get icono => switch (this) {
        TipoTrabajo.todo => Icons.inbox_outlined,
        TipoTrabajo.ordenes => Icons.build_circle_outlined,
        TipoTrabajo.tareas => Icons.task_alt,
        TipoTrabajo.pautas => Icons.checklist_rtl,
        TipoTrabajo.bitacora => Icons.menu_book_outlined,
      };
}

/// **Mi trabajo**: todo lo que hay que hacer, en un solo sitio.
///
/// ## Por qué una bandeja y no cuatro pantallas
///
/// Antes cada tipo vivía en su propia pantalla y solo dos de ellas tenían
/// sitio en la barra inferior: órdenes y —a través de «Más»— el resto. El
/// resultado es que la mitad del trabajo del día quedaba a tres toques de
/// distancia y detrás de un menú que hay que recordar que existe.
///
/// En terreno nadie piensa «voy a mirar mis checklists»: piensa «qué me toca
/// ahora». Una bandeja con pestañas responde a esa pregunta; cuatro pantallas
/// obligan a hacérsela cuatro veces.
///
/// ## Por qué las pestañas son por TIPO y los chips por ESTADO
///
/// Son dos preguntas distintas y cruzarlas en un solo control las mezcla. El
/// tipo dice **qué clase de trabajo**; el chip, **en qué estado** está —hoy,
/// míos, disponibles—. Un chip de estado sirve igual dentro de cualquier tipo,
/// y por eso vive dentro de cada pestaña y no al lado de ellas.
class MiTrabajoScreen extends ConsumerStatefulWidget {
  const MiTrabajoScreen({super.key, this.inicial = TipoTrabajo.todo});

  /// Con qué pestaña abre. La usa el Home para llevar directo a lo que se tocó.
  final TipoTrabajo inicial;

  @override
  ConsumerState<MiTrabajoScreen> createState() => _MiTrabajoScreenState();
}

class _MiTrabajoScreenState extends ConsumerState<MiTrabajoScreen> {
  late TipoTrabajo _tipo = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Scaffold(
      backgroundColor: sg.fondo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Cabecera(
              tipo: _tipo,
              onTipo: (t) => setState(() => _tipo = t),
            ),
            Expanded(
              child: switch (_tipo) {
                // Cada tipo reusa su propia lista: la bandeja los reúne, no
                // los reimplementa. Duplicar la tarjeta de una orden acá sería
                // dos sitios donde arreglar el mismo defecto.
                TipoTrabajo.ordenes => const OrdenesScreen(embebida: true),
                TipoTrabajo.tareas => const TareasScreen(embebida: true),
                TipoTrabajo.pautas => const ChecklistScreen(embebida: true),
                TipoTrabajo.bitacora => const _Bitacora(),
                TipoTrabajo.todo => const _Todo(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// La cabecera con el título y las pestañas por tipo.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.tipo, required this.onTipo});

  final TipoTrabajo tipo;
  final ValueChanged<TipoTrabajo> onTipo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Text('Mi trabajo',
              style: sora(23, 700, color: sg.tinta, espaciado: -0.46)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: TipoTrabajo.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = TipoTrabajo.values[i];
              return _Pestana(
                texto: t.texto,
                icono: t.icono,
                elegida: t == tipo,
                onTap: () => onTipo(t),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: sg.div),
      ],
    );
  }
}

/// Una pestaña de tipo. Se desplaza en horizontal a propósito: caben cinco sin
/// apretarlas, y el día que entre un sexto tipo no hay que rehacer la fila.
class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.icono,
    required this.elegida,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Material(
      color: elegida ? sg.primario : sg.up,
      borderRadius: BorderRadius.circular(SgRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono,
                  size: 17, color: elegida ? Colors.white : sg.tinta2),
              const SizedBox(width: 7),
              Text(texto,
                  style: sora(14, 600,
                      color: elegida ? Colors.white : sg.tinta2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Todo»: lo que apremia de cada tipo, junto.
///
/// No es la suma de las cuatro listas —eso sería una lista de cien— sino **lo
/// que vence hoy o está vencido**, que es la pregunta que se hace alguien al
/// llegar a la planta. Para ver el resto de un tipo está su pestaña.
class _Todo extends ConsumerWidget {
  const _Todo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final ordenes = ref.watch(ordenesTrabajoProvider).valueOrNull ?? const [];
    final tareas = ref.watch(tareasPendientesProvider).valueOrNull ?? const [];
    final pautas =
        ref.watch(checklistPendientesProvider).valueOrNull ?? const [];

    // VENCIDA y VENCE HOY los decide el SP, no la pantalla: si lo calculara
    // la app, dos teléfonos con distinta hora darían veredictos distintos
    // sobre la misma orden.
    final ordenesHoy = ordenes
        .where((o) => const {'VENCIDA', 'VENCE HOY'}
            .contains((o.SITUACION ?? '').toUpperCase()))
        .toList();
    final tareasHoy = tareas.where((t) => t.vencida).toList();

    final vacio =
        ordenesHoy.isEmpty && tareasHoy.isEmpty && pautas.isEmpty;

    if (vacio) {
      return const EstadoVacio(
        icono: Icons.check_circle_outline,
        titulo: 'Nada apremia ahora',
        detalle: 'Lo que vence hoy o está vencido aparece acá. Mira las '
            'pestañas para el resto de tu carga.',
      );
    }

    return ListView(
      padding:
          context.conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 24)),
      children: [
        if (ordenesHoy.isNotEmpty) ...[
          _Grupo(
              texto: 'Órdenes que apremian', cuantas: ordenesHoy.length),
          for (final o in ordenesHoy) ...[
            _Resumen(
              icono: Icons.build_circle_outlined,
              color: o.vencida ? sg.rojoTexto : sg.ambarTexto,
              titulo: '${o.OT_NUMERO} · ${o.otr_titulo}',
              detalle: o.activo.isEmpty ? o.ubicacion : o.activo,
              foto: o.ACTIVO_FOTO,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
        if (tareasHoy.isNotEmpty) ...[
          _Grupo(texto: 'Tareas vencidas', cuantas: tareasHoy.length),
          for (final t in tareasHoy) ...[
            _Resumen(
              icono: Icons.task_alt,
              color: sg.rojoTexto,
              titulo: t.tar_titulo,
              detalle: t.activo.isEmpty ? t.donde : t.activo,
              foto: t.ACTIVO_FOTO,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
        if (pautas.isNotEmpty) ...[
          _Grupo(texto: 'Pautas pendientes', cuantas: pautas.length),
          for (final p in pautas) ...[
            _Resumen(
              icono: Icons.checklist_rtl,
              color: sg.acentoTexto,
              titulo: p.PLANTILLA_NOMBRE,
              detalle: p.donde,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.texto, required this.cuantas});

  final String texto;
  final int cuantas;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SgRotuloConAccion(texto, accion: '$cuantas'),
      );
}

/// Una fila de «Todo»: lo justo para decidir si se abre.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    this.foto,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final String? foto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          SgIconoCuadro(icono, color: color, lado: 42, tamanoIcono: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: sora(15, 600, color: sg.tinta),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(detalle,
                      style: sora(12, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La bitácora de planta — HU-130.
///
/// Es una línea de tiempo, no una lista de pendientes: acá no hay nada que
/// cerrar. Sirve para saber **qué pasó en el turno anterior** antes de bajar a
/// la planta, que es lo que hoy se pregunta de palabra en el cambio de turno.
class _Bitacora extends ConsumerWidget {
  const _Bitacora();

  static final _fecha = DateFormat('dd-MM · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final entradas = ref.watch(bitacoraProvider);

    /* EL BOTON DE ESCRIBIR VA FLOTANDO, NO AL FINAL DE LA LISTA

       La bitácora crece hacia abajo y lo último es lo más viejo: un botón al
       final de la lista se aleja un poco más cada día. Flotando queda a la
       misma distancia del pulgar siempre, que es lo que hace que se use. */
    return Stack(
      children: [
        Positioned.fill(child: _linea(context, ref, sg, entradas)),
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton.extended(
            heroTag: 'bitacora',
            backgroundColor: sg.primario,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_note),
            label: Text('Anotar', style: sora(14, 600, color: Colors.white)),
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => const NuevaEntradaScreen()),
              );
              if (ok == true) ref.invalidate(bitacoraProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _linea(BuildContext context, WidgetRef ref, dynamic sg,
      AsyncValue<List<BitacoraEntrada>> entradas) {
    return EstadoAsync<List<BitacoraEntrada>>(
      valor: entradas,
      onReintentar: () => ref.invalidate(bitacoraProvider),
      estaVacio: (l) => l.isEmpty,
      vacio: const EstadoVacio(
        icono: Icons.menu_book_outlined,
        titulo: 'La bitácora está en blanco',
        detalle: 'Acá queda lo que pasó en la planta: una fuga, un ruido '
            'raro, un equipo que se detuvo. Se escribe desde el terreno.',
      ),
      child: (lista) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(bitacoraProvider),
        child: ListView.separated(
          padding: context
              .conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 24)),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (_, i) {
            final e = lista[i];
            final grave = (e.SEVERIDAD_CODIGO ?? '').toUpperCase() == 'ALTA' ||
                (e.SEVERIDAD_CODIGO ?? '').toUpperCase() == 'CRITICA';

            return SgCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EntradaBitacoraScreen(entradaId: e.bit_id),
              )),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((e.TIPO_NOMBRE ?? '').isNotEmpty)
                        SgBadge(e.TIPO_NOMBRE!, color: sg.tinta2, chico: true),
                      if ((e.SEVERIDAD_NOMBRE ?? '').isNotEmpty)
                        SgBadge(e.SEVERIDAD_NOMBRE!,
                            color: grave ? sg.rojoTexto : sg.ambarTexto,
                            chico: true),
                      if (e.bit_requiere_atencion)
                        SgBadge('Requiere atención',
                            color: sg.rojoTexto,
                            icono: Icons.priority_high,
                            chico: true),
                      // Rectificada, no editada: el texto original sigue
                      // guardado debajo. Marcarlo es lo que hace que la
                      // bitácora sirva como registro.
                      if (e.rectificada)
                        SgBadge('Rectificada',
                            color: sg.azulTexto,
                            icono: Icons.history_edu,
                            chico: true),
                      if (e.POR_VOZ)
                        SgBadge('Dictada',
                            color: sg.tinta3, icono: Icons.mic, chico: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(e.bit_titulo,
                      style: sora(16, 600, color: sg.tinta, alto: 1.35)),
                  const SizedBox(height: 5),
                  Text(e.TEXTO_VIGENTE,
                      style: sora(13, 500, color: sg.tinta2, alto: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: sg.tinta3),
                      const SizedBox(width: 5),
                      Text(_fecha.format(e.bit_fecha_evento_utc.toLocal()),
                          style: sora(12, 500, color: sg.tinta3)),
                      if ((e.bit_turno ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('· turno ${e.bit_turno}',
                            style: sora(12, 500, color: sg.tinta3)),
                      ],
                      const Spacer(),
                      if ((e.USUARIO_NOMBRE ?? '').isNotEmpty)
                        Flexible(
                          child: Text(e.USUARIO_NOMBRE!,
                              style: sora(12, 500, color: sg.tinta3),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                  if (e.activo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.view_in_ar_outlined,
                            size: 13, color: sg.tinta3),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(e.activo,
                              style: sora(12, 500, color: sg.tinta3),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
