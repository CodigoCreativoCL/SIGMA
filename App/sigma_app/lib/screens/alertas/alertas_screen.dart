import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../constants/api_constants.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../activo/activo_ficha_screen.dart';
import '../inventario/existencias_screen.dart';
import '../ordenes/orden_ficha_screen.dart';
import '../permiso_trabajo/permisos_trabajo_screen.dart';

enum FiltroAlerta { todas, noLeidas, criticas }

final filtroAlertaProvider = StateProvider<FiltroAlerta>(
  (ref) => FiltroAlerta.todas,
);

/// Alertas — HU-077.
///
/// **La bandeja sale del servidor, no del teléfono.** SIGMA ya detecta los
/// hallazgos con los `GEN_ALERTA_*`: una bandeja construida localmente sería
/// una segunda verdad que se desalinea con la web el primer día.
///
/// Layout v3: barra con el título 23/700 y el botón de marcar todo; chips de
/// 28 con contador; tarjetas de 22 **sin borde** donde la leída pierde la
/// superficie y se queda en el lienzo.
class AlertasScreen extends ConsumerStatefulWidget {
  const AlertasScreen({super.key});

  @override
  ConsumerState<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends ConsumerState<AlertasScreen> {
  bool _marcando = false;

  /// La alerta cuyo «Sumarme» está en curso. Es el id y no un bool porque en
  /// pantalla hay varias tarjetas y el spinner tiene que ir en la que se tocó.
  int? _sumandose;

  /// Sumarse al trabajo que un compañero compartió — HU-115.
  ///
  /// ## Se intenta primero y se encola si falla la red
  ///
  /// Es el mismo trato que reciben las fotos en `sigma_evidencia.dart`, y por
  /// la misma razón: con señal, el compañero necesita saber **ahora** que
  /// quedó sumado —va a caminar hasta la máquina—, y una confirmación que
  /// llega del servidor es la única que no miente. Sin señal la captura no se
  /// pierde: entra a la cola.
  ///
  /// Un error que **no** es de red no se encola. Un 403 —sin `EJECUTAR ORDEN
  /// TRABAJO`— o un 400 —la orden ya se cerró— no mejoran reintentando, y
  /// guardarlos sería dejar en la cola algo que va a fallar para siempre.
  ///
  /// El `uuid` nace acá y se reusa al encolar: `API_INS_ORDEN_TRABAJO_MANO_OBRA`
  /// corta por él (BD/188), así que el reintento del timeout no deja al
  /// compañero dos veces en la mano de obra de la orden.
  Future<void> _sumarme(Alerta alerta) async {
    if (_sumandose != null) return;

    final mensajero = ScaffoldMessenger.of(context);
    final uuid = OutboxService.nuevoUuid();

    setState(() => _sumandose = alerta.ale_id);

    try {
      await SigmaRepository.instance.unirmeAOrden(alerta.FICHA_ID, uuid: uuid);

      await _marcarLeida(alerta.ale_id);
      if (!mounted) return;
      ref.invalidate(ordenTrabajoProvider(alerta.FICHA_ID));
      ref.invalidate(recursosOrdenProvider(alerta.FICHA_ID));
      ref.invalidate(ordenesTrabajoProvider);

      if (!mounted) return;
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Te sumaste al trabajo. Queda tu tramo abierto.'),
        ),
      );
    } on ApiException catch (e) {
      if (!e.esDeRed) {
        if (!mounted) return;
        setState(() => _sumandose = null);
        mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
        return;
      }

      await OutboxService.instance.encolar(
        tipo: 'UNIRME',
        titulo: 'Sumarse a un trabajo',
        detalle: alerta.ale_titulo,
        endpoint: '${ApiConstants.compartir}/unirme',
        uuid: uuid,
        cuerpo: {'orden_trabajo': alerta.FICHA_ID},
      );
      SyncService.instance.despacharAhora();

      if (!mounted) return;
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'Guardado en el teléfono. Se envía al volver la '
            'señal.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sumandose = null);
    }
  }

  Future<void> _marcarLeida(int id) async {
    try {
      await SigmaRepository.instance.marcarAlertaLeida(id);
      if (!mounted) return;
      ref.invalidate(alertasProvider);
      ref.invalidate(resumenAlertasProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// Marca las que están **en pantalla**, no «todas las del servidor».
  ///
  /// No hay un endpoint que lo haga de una vez, así que son N llamadas; que
  /// sean las cargadas acota el N a lo que la persona efectivamente vio.
  Future<void> _marcarTodas(List<Alerta> lista) async {
    final noLeidas = lista.where((a) => !a.leida).toList();
    if (noLeidas.isEmpty || _marcando) return;

    setState(() => _marcando = true);
    var fallo = 0;
    for (final a in noLeidas) {
      try {
        await SigmaRepository.instance.marcarAlertaLeida(a.ale_id);
      } on ApiException {
        fallo++;
      }
    }
    if (!mounted) return;
    ref.invalidate(alertasProvider);
    ref.invalidate(resumenAlertasProvider);

    if (!mounted) return;
    setState(() => _marcando = false);
    if (fallo > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fallo ${fallo == 1 ? "alerta" : "alertas"} no se '
            'pudo marcar. Se reintenta al recargar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final alertas = ref.watch(alertasProvider);
    final filtro = ref.watch(filtroAlertaProvider);

    // Esconder el botón no autoriza nada —el endpoint vuelve a exigirlo— pero
    // evita ofrecer una acción que terminaría en un 403 que quien la tocó no
    // puede corregir desde el teléfono.
    final puedeEjecutar = ref.watch(
      tienePermisoProvider('EJECUTAR ORDEN TRABAJO'),
    );

    final todas = alertas.valueOrNull?.datos ?? const <Alerta>[];
    final noLeidas = todas.where((a) => !a.leida).length;
    final criticas = todas.where((a) => _grave(a.sev_codigo)).length;

    final visibles = switch (filtro) {
      FiltroAlerta.todas => todas,
      FiltroAlerta.noLeidas => todas.where((a) => !a.leida).toList(),
      FiltroAlerta.criticas =>
        todas.where((a) => _grave(a.sev_codigo)).toList(),
    };

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Alertas',
        tamanoTitulo: 23,
        acciones: [
          if (_marcando)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else if (noLeidas > 0)
            SgBotonIcono(
              Icons.done_all,
              fondo: sg.up,
              color: sg.tinta,
              onTap: () => _marcarTodas(todas),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                SgChip(
                  'Todas',
                  elegido: filtro == FiltroAlerta.todas,
                  onTap: () => _filtrar(FiltroAlerta.todas),
                ),
                const SizedBox(width: 8),
                SgChip(
                  'No leídas',
                  elegido: filtro == FiltroAlerta.noLeidas,
                  contador: noLeidas,
                  onTap: () => _filtrar(FiltroAlerta.noLeidas),
                ),
                const SizedBox(width: 8),
                SgChip(
                  'Críticas',
                  elegido: filtro == FiltroAlerta.criticas,
                  contador: criticas,
                  colorContador: SgColor.rojo,
                  onTap: () => _filtrar(FiltroAlerta.criticas),
                ),
              ],
            ),
          ),
          Expanded(
            child: EstadoAsync<Paginado<Alerta>>(
              valor: alertas,
              onReintentar: () => ref.invalidate(alertasProvider),
              estaVacio: (_) => visibles.isEmpty,
              vacio: EstadoVacio(
                icono: filtro == FiltroAlerta.todas
                    ? Icons.notifications_none
                    : Icons.filter_alt_off_outlined,
                titulo: switch (filtro) {
                  FiltroAlerta.todas => 'Sin alertas abiertas',
                  FiltroAlerta.noLeidas => 'Ya leíste todas',
                  FiltroAlerta.criticas => 'Ninguna crítica',
                },
                detalle:
                    'Las alertas las genera el servidor cuando detecta un '
                    'hallazgo: stock bajo mínimo, permiso por vencer o medidor '
                    'sin lectura.',
              ),
              child: (_) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(alertasProvider);
                  ref.invalidate(resumenAlertasProvider);
                },
                child: ListView.separated(
                  padding: context.conBarraSistema(
                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  ),
                  itemCount: visibles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (_, i) {
                    final a = visibles[i];

                    /* LA COMPARTIDA SIEMPRE TRAE SUS ACCIONES

                       El resto de las alertas muestra los botones solo en la
                       primera sin leer, para no dejar una pared de botones.
                       En un trabajo compartido eso deja sin salida a la que
                       quedó tercera: en las demás la acción es MIRAR y la
                       tarjeta entera ya es tocable, pero acá la acción es
                       sumarse, y esa no está en ningún otro sitio. */
                    return _Tarjeta(
                      alerta: a,
                      conAcciones:
                          a.esCompartida ||
                          (i == 0 && !a.leida && _destino(a) != null),
                      onLeer: () => _marcarLeida(a.ale_id),
                      onSumarme: a.esCompartida && puedeEjecutar
                          ? () => _sumarme(a)
                          : null,
                      sumandose: _sumandose == a.ale_id,
                    );
                  },
                ),
              ),
            ),
          ),
          const SgBarraGestos(),
        ],
      ),
    );
  }

  void _filtrar(FiltroAlerta f) =>
      ref.read(filtroAlertaProvider.notifier).state = f;

  static bool _grave(String sev) {
    final s = sev.toUpperCase();
    return s == 'CRITICA' || s == 'CRÍTICA' || s == 'ALTA';
  }
}

/// A dónde lleva una alerta.
///
/// **El destino sale de `FICHA_LINK`, que lo pone el servidor**, no de adivinar
/// por el título. El mismo `GEN_ALERTA_*` que la creó sabe de qué entidad
/// habla; la pantalla solo traduce ese enlace a una ruta de la app.
Widget? _destino(Alerta a) {
  final link = (a.FICHA_LINK ?? '').toLowerCase();
  if (link.isEmpty || a.FICHA_ID == 0) return null;

  if (link.contains('activo')) return ActivoFichaScreen(activoId: a.FICHA_ID);
  if (link.contains('existencia') ||
      link.contains('repuesto') ||
      link.contains('inventario')) {
    return const ExistenciasScreen();
  }
  if (link.contains('permiso')) return const PermisosTrabajoScreen();
  return null;
}

/// A dónde lleva la alerta de un trabajo compartido.
///
/// Va aparte de [_destino] porque **no se decide por `FICHA_LINK`**: esa
/// columna es la ruta de la intranet y la página web de la orden no existe
/// todavía, así que el tipo COMPARTIDO la tiene en NULL. Se distingue por el
/// código del tipo, que es la identidad de la fila y no un texto que alguien
/// pueda reescribir.
Widget? _destinoCompartida(Alerta a) =>
    a.esCompartida ? OrdenFichaScreen(ordenId: a.FICHA_ID) : null;

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.alerta,
    required this.conAcciones,
    required this.onLeer,
    required this.onSumarme,
    this.sumandose = false,
  });

  final Alerta alerta;
  final bool conAcciones;
  final VoidCallback onLeer;

  /// Sumarse al trabajo que un compañero compartió. Nulo si esta persona no
  /// tiene `EJECUTAR ORDEN TRABAJO`: sin ese permiso el endpoint responde 403
  /// y el botón sería una promesa que la app no puede cumplir.
  final VoidCallback? onSumarme;

  final bool sumandose;

  /// El color y el ícono los decide la severidad que guardó el SP. La pantalla
  /// no reinterpreta la gravedad: solo la pinta.
  (Color, IconData, String) _severidad(AppColors sg) => switch (alerta
      .sev_codigo
      .toUpperCase()) {
    'CRITICA' || 'CRÍTICA' => (sg.rojoTexto, Icons.error_outline, 'Crítica'),
    'ALTA' => (sg.rojoTexto, Icons.error_outline, 'Alta'),
    'ADVERTENCIA' => (sg.ambarTexto, Icons.warning_amber, 'Advertencia'),
    'BAJA' => (sg.azulTexto, Icons.info_outline, 'Baja'),
    _ => (sg.azulTexto, Icons.info_outline, 'Informativo'),
  };

  /// El icono de la LINEA de identidad: que clase de cosa es, no que le pasa.
  ///
  /// Se distingue del icono grande a proposito: aquel dice el tipo de alerta
  /// —y su color, la severidad—; este dice si hablamos de un equipo, de una
  /// pieza montada o de un repuesto de bodega.
  IconData get _iconoSujeto {
    if ((alerta.COMPONENTE_NOMBRE ?? '').trim().isNotEmpty) {
      return Icons.settings_outlined;
    }
    if ((alerta.ACTIVO_NOMBRE ?? '').trim().isNotEmpty) {
      return Icons.view_in_ar_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  IconData get _iconoTipo {
    final t = '${alerta.alt_nombre ?? ''} ${alerta.FICHA_LINK ?? ''}'
        .toLowerCase();
    if (t.contains('stock') ||
        t.contains('existencia') ||
        t.contains('repuesto')) {
      return Icons.inventory_2_outlined;
    }
    if (t.contains('permiso')) return Icons.assignment_turned_in_outlined;
    if (t.contains('medidor') || t.contains('lectura')) {
      return Icons.speed_outlined;
    }
    if (t.contains('activo')) return Icons.view_in_ar_outlined;
    if (alerta.esCompartida) return Icons.groups_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final (color, iconoSev, nombreSev) = _severidad(sg);
    final leida = alerta.leida;
    final destino = _destinoCompartida(alerta) ?? _destino(alerta);

    // Leída, la tarjeta **pierde la superficie**: se queda en el lienzo con el
    // texto un nivel más bajo. Es lo que separa «pendiente» de «ya visto» sin
    // sacarla de la lista, y sin recurrir a un borde.
    return SgCard(
      padding: const EdgeInsets.all(14),
      color: leida ? sg.fondo : null,
      sinSombra: leida,
      onTap: () {
        if (!leida) onLeer();
        if (destino != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => destino));
        }
      },
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* LA FOTO DE LO QUE PASA, Y SI NO HAY, EL ICONO

                 Diez filas con el mismo icono de campana no distinguen nada:
                 hay que leerlas todas para encontrar la del horno. Con la foto
                 del equipo se reconoce de un vistazo, que es para lo que sirve
                 una bandeja.

                 Cuando no hay foto NO se deja un marco vacio —eso se lee como
                 «no cargo» y hace dudar del resto—: se pinta el icono del tipo
                 de alerta, con su color de severidad, que es lo que habia
                 antes y sigue diciendo algo. */
              if ((alerta.FOTO_RUTA ?? '').isEmpty)
                SgIconoCuadro(
                  _iconoTipo,
                  color: color,
                  lado: 44,
                  tamanoIcono: 22,
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(SgRadius.icono48),
                  child: SigmaImagen(
                    ruta: alerta.FOTO_RUTA,
                    ancho: 44,
                    alto: 44,
                    radio: SgRadius.icono48,
                    // En la bandeja el toque es para abrir la alerta, no para
                    // mirar la foto en grande.
                    ampliable: false,
                    iconoVacio: _iconoTipo,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SgBadge(nombreSev, color: color, icono: iconoSev),
                        const Spacer(),
                        Text(
                          alerta.hace,
                          style: sora(13, 500, color: sg.tinta3),
                        ),
                        if (!leida) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: sg.primario,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alerta.ale_titulo,
                      style: sora(
                        17,
                        600,
                        color: leida ? sg.tinta2 : sg.tinta,
                        alto: 1.35,
                      ),
                    ),
                    /* DE QUE EQUIPO HABLA

                       El titulo dice QUE pasa —«Temperatura sobre el limite»—
                       y no DONDE. Sin esto habia que abrir la alerta para
                       saberlo, y con doce en la bandeja eso son doce toques
                       para encontrar la que importa. */
                    if (alerta.sobreQue.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(_iconoSujeto, size: 13, color: sg.tinta3),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              alerta.sobreQue,
                              style: sora(12, 600, color: sg.tinta3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((alerta.ale_descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        alerta.ale_descripcion!,
                        style: sora(
                          14,
                          500,
                          color: leida ? sg.tinta3 : sg.tinta2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (conAcciones && destino != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SgBoton(
                    _textoAccion(alerta),
                    icono: _iconoTipo,
                    alto: 44,
                    tamanoTexto: 14,
                    primario: !alerta.esCompartida,
                    onTap: () {
                      onLeer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => destino),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 9),

                /* SUMARSE ES LA ACCION DE ESTA ALERTA, NO ABRIRLA

                   En una alerta de stock la acción es mirar; en un trabajo
                   compartido es **ir**. El compañero comparte porque necesita
                   una mano, así que sumarse va de principal y abrir la orden
                   queda de secundaria. Sin este botón el aviso decía «Rodrigo
                   te compartió OT-1176» y no llevaba a ninguna parte. */
                if (alerta.esCompartida && onSumarme != null)
                  Expanded(
                    child: SgBoton(
                      'Sumarme',
                      icono: Icons.person_add_alt,
                      alto: 44,
                      tamanoTexto: 14,
                      cargando: sumandose,
                      onTap: onSumarme,
                    ),
                  )
                else
                  SgBotonIcono(
                    Icons.done,
                    fondo: sg.up,
                    color: sg.tinta,
                    onTap: onLeer,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _textoAccion(Alerta a) {
    if (a.esCompartida) return 'Abrir la orden';
    final link = (a.FICHA_LINK ?? '').toLowerCase();
    if (link.contains('activo')) return 'Ver el activo';
    if (link.contains('permiso')) return 'Ver el permiso';
    return 'Ver existencia';
  }
}
