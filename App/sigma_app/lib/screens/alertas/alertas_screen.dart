import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../activo/activo_ficha_screen.dart';
import '../inventario/existencias_screen.dart';
import '../permiso_trabajo/permisos_trabajo_screen.dart';

enum FiltroAlerta { todas, noLeidas, criticas }

final filtroAlertaProvider =
    StateProvider<FiltroAlerta>((ref) => FiltroAlerta.todas);

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

  Future<void> _marcarLeida(int id) async {
    try {
      await SigmaRepository.instance.marcarAlertaLeida(id);
      ref.invalidate(alertasProvider);
      ref.invalidate(resumenAlertasProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensaje)));
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
    ref.invalidate(alertasProvider);
    ref.invalidate(resumenAlertasProvider);

    if (!mounted) return;
    setState(() => _marcando = false);
    if (fallo > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$fallo ${fallo == 1 ? "alerta" : "alertas"} no se '
              'pudo marcar. Se reintenta al recargar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final alertas = ref.watch(alertasProvider);
    final filtro = ref.watch(filtroAlertaProvider);

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
                  child: CircularProgressIndicator(strokeWidth: 2.2)),
            )
          else if (noLeidas > 0)
            SgBotonIcono(Icons.done_all,
                fondo: sg.up, color: sg.tinta,
                onTap: () => _marcarTodas(todas)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                SgChip('Todas',
                    elegido: filtro == FiltroAlerta.todas,
                    onTap: () => _filtrar(FiltroAlerta.todas)),
                const SizedBox(width: 8),
                SgChip('No leídas',
                    elegido: filtro == FiltroAlerta.noLeidas,
                    contador: noLeidas,
                    onTap: () => _filtrar(FiltroAlerta.noLeidas)),
                const SizedBox(width: 8),
                SgChip('Críticas',
                    elegido: filtro == FiltroAlerta.criticas,
                    contador: criticas,
                    colorContador: SgColor.rojo,
                    onTap: () => _filtrar(FiltroAlerta.criticas)),
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
                detalle: 'Las alertas las genera el servidor cuando detecta un '
                    'hallazgo: stock bajo mínimo, permiso por vencer o medidor '
                    'sin lectura.',
              ),
              child: (_) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(alertasProvider);
                  ref.invalidate(resumenAlertasProvider);
                },
                child: ListView.separated(
                  padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 0, 16, 24)),
                  itemCount: visibles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (_, i) => _Tarjeta(
                    alerta: visibles[i],
                    conAcciones: i == 0 &&
                        !visibles[i].leida &&
                        _destino(visibles[i]) != null,
                    onLeer: () => _marcarLeida(visibles[i].ale_id),
                  ),
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

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.alerta,
    required this.conAcciones,
    required this.onLeer,
  });

  final Alerta alerta;
  final bool conAcciones;
  final VoidCallback onLeer;

  /// El color y el ícono los decide la severidad que guardó el SP. La pantalla
  /// no reinterpreta la gravedad: solo la pinta.
  (Color, IconData, String) _severidad(AppColors sg) =>
      switch (alerta.sev_codigo.toUpperCase()) {
        'CRITICA' || 'CRÍTICA' => (sg.rojoTexto, Icons.error_outline, 'Crítica'),
        'ALTA' => (sg.rojoTexto, Icons.error_outline, 'Alta'),
        'ADVERTENCIA' => (sg.ambarTexto, Icons.warning_amber, 'Advertencia'),
        'BAJA' => (sg.azulTexto, Icons.info_outline, 'Baja'),
        _ => (sg.azulTexto, Icons.info_outline, 'Informativo'),
      };

  IconData get _iconoTipo {
    final t =
        '${alerta.alt_nombre ?? ''} ${alerta.FICHA_LINK ?? ''}'.toLowerCase();
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
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final (color, iconoSev, nombreSev) = _severidad(sg);
    final leida = alerta.leida;
    final destino = _destino(alerta);

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
              SgIconoCuadro(_iconoTipo,
                  color: color, lado: 44, tamanoIcono: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SgBadge(nombreSev, color: color, icono: iconoSev),
                        const Spacer(),
                        Text(alerta.hace,
                            style: sora(13, 500, color: sg.tinta3)),
                        if (!leida) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: sg.primario, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(alerta.ale_titulo,
                        style: sora(17, 600,
                            color: leida ? sg.tinta2 : sg.tinta, alto: 1.35)),
                    if ((alerta.ale_descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(alerta.ale_descripcion!,
                          style: sora(14, 500,
                              color: leida ? sg.tinta3 : sg.tinta2)),
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
                    onTap: () {
                      onLeer();
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => destino));
                    },
                  ),
                ),
                const SizedBox(width: 9),
                SgBotonIcono(Icons.done,
                    fondo: sg.up, color: sg.tinta, onTap: onLeer),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _textoAccion(Alerta a) {
    final link = (a.FICHA_LINK ?? '').toLowerCase();
    if (link.contains('activo')) return 'Ver el activo';
    if (link.contains('permiso')) return 'Ver el permiso';
    return 'Ver existencia';
  }
}
