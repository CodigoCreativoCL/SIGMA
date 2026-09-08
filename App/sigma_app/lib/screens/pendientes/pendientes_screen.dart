import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

final colaProvider =
    FutureProvider<List<ItemCola>>((ref) => OutboxService.instance.listar());

/// Pendientes de envío — HU-151.
///
/// **No es una pantalla opcional.** Una cola que reintenta en silencio y
/// descarta al tercer intento pierde trabajo sin avisar; sin esta pantalla la
/// cola es una caja negra y el técnico se entera de que perdió una lectura
/// cuando alguien se la reclama una semana después.
///
/// Layout v3: barra con el badge de conexión; aviso de sin señal solo cuando
/// la hay; badges de conteo con el botón «Reintentar» de 36; tarjetas de 22
/// donde **la rechazada lleva el anillo rojo** —no borde— y abre el motivo del
/// servidor en su propio bloque teñido.
class PendientesScreen extends ConsumerWidget {
  const PendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final cola = ref.watch(colaProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra(
        'Pendientes',
        tamanoTitulo: 20,
        acciones: [
          Padding(padding: EdgeInsets.only(right: 4), child: _BadgeConexion()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await OutboxService.instance.despachar();
          ref.invalidate(colaProvider);
        },
        child: EstadoAsync<List<ItemCola>>(
          valor: cola,
          onReintentar: () => ref.invalidate(colaProvider),
          estaVacio: (l) => l.isEmpty,
          vacio: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 40),
              EstadoVacio(
                icono: Icons.cloud_done_outlined,
                titulo: 'No hay nada esperando',
                detalle:
                    'Todo lo que registraste llegó al servidor. Lo que captures '
                    'sin señal va a aparecer acá hasta que se envíe.',
              ),
            ],
          ),
          child: (items) {
            final pend =
                items.where((i) => i.estado == EstadoItem.pendiente).length;
            final rech =
                items.where((i) => i.estado == EstadoItem.rechazado).length;

            return ListView(
              padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
              children: [
                const _AvisoSinSenal(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (pend > 0)
                              SgBadge('$pend pendiente${pend == 1 ? "" : "s"}',
                                  color: sg.ambarTexto),
                            if (rech > 0)
                              SgBadge('$rech rechazado${rech == 1 ? "" : "s"}',
                                  color: sg.rojoTexto),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _BotonReintentar(onTap: () async {
                        await OutboxService.instance.despachar();
                        ref.invalidate(colaProvider);
                      }),
                    ],
                  ),
                ),
                for (final i in items) ...[
                  _Fila(
                    item: i,
                    onReintentar: () async {
                      await OutboxService.instance.reintentar(i.id);
                      await OutboxService.instance.despachar();
                      ref.invalidate(colaProvider);
                    },
                    onDescartar: () async {
                      await OutboxService.instance.descartar(i.id);
                      ref.invalidate(colaProvider);
                    },
                  ),
                  const SizedBox(height: 11),
                ],
                const SizedBox(height: 4),
                Text(
                  'Nada se descarta por cantidad de intentos. Un registro sale '
                  'de la cola cuando el servidor lo acepta o cuando tú lo '
                  'corriges.',
                  style: sora(13, 500, color: sg.tinta3, alto: 1.55),
                ),
                const SizedBox(height: 12),
                const SgBarraGestos(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BadgeConexion extends StatelessWidget {
  const _BadgeConexion();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.enLinea,
      builder: (_, enLinea, _) => SgBadge(
        enLinea ? 'En línea' : 'Sin conexión',
        color: enLinea ? sg.acentoTexto : sg.tinta2,
        icono: enLinea ? Icons.wifi : Icons.wifi_off,
      ),
    );
  }
}

/// La nota de «sin conexión». **Solo aparece cuando no hay señal**: dejarla
/// siempre la convierte en decorado y el día que importe nadie la va a leer.
class _AvisoSinSenal extends StatelessWidget {
  const _AvisoSinSenal();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: SyncService.instance.enLinea,
        builder: (_, enLinea, _) => enLinea
            ? const SizedBox.shrink()
            : const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: SgAviso(
                  'Sin conexión. Puedes seguir trabajando; lo enviaremos solo '
                  'cuando vuelva la señal.',
                  icono: Icons.cloud_off_outlined,
                ),
              ),
      );
}

/// El botón de 36 del kit: relleno `up`, píldora, ícono 17 y texto 14/600.
class _BotonReintentar extends StatelessWidget {
  const _BotonReintentar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Material(
      color: sg.up,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 17, color: sg.tinta),
              const SizedBox(width: 7),
              Text('Reintentar', style: sora(14, 600, color: sg.tinta)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.item,
    required this.onReintentar,
    required this.onDescartar,
  });

  final ItemCola item;
  final VoidCallback onReintentar;
  final VoidCallback onDescartar;

  static final _hora = DateFormat('HH:mm');
  static final _dia = DateFormat('d MMM', 'es');

  /// «hoy 09:12» · «3 sep 08:55». Se muestra en la hora del teléfono, que es
  /// la que el técnico tenía cuando capturó.
  String get _cuando {
    final f = item.fechaCaptura.toLocal();
    final hoy = DateTime.now();
    final esHoy =
        f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    final base =
        esHoy ? 'hoy ${_hora.format(f)}' : '${_dia.format(f)} ${_hora.format(f)}';
    return item.intentos > 1 ? '$base · ${item.intentos} intentos' : base;
  }

  IconData get _icono => switch (item.tipo) {
        'LECTURA' => Icons.speed_outlined,
        'MEDICION' => Icons.straighten,
        'MOVIMIENTO' => Icons.archive_outlined,
        'ESTADO_ACTIVO' => Icons.published_with_changes,
        _ => Icons.upload_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final rechazado = item.estado == EstadoItem.rechazado;
    final color = rechazado ? sg.rojoTexto : sg.ambarTexto;

    // El rechazado lleva **anillo rojo**: es la única tarjeta de la lista que
    // exige una decisión, y tiene que distinguirse de un vistazo entre diez
    // que solo esperan.
    return SgCard(
      padding: const EdgeInsets.all(14),
      elegida: rechazado,
      colorAnillo: SgColor.rojo,
      child: Column(
        children: [
          Row(
            children: [
              SgIconoCuadro(rechazado ? Icons.error_outline : _icono,
                  color: color, lado: 44, tamanoIcono: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                        style: sora(16, 600, color: sg.tinta),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if ((item.detalle ?? '').isNotEmpty) item.detalle!,
                        _cuando,
                      ].join(' · '),
                      style: sora(13, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SgBadge(rechazado ? 'Rechazado' : 'En cola',
                  color: color, icono: rechazado ? null : Icons.schedule),
            ],
          ),
          if (rechazado) ...[
            const SizedBox(height: 12),
            // El motivo tal como lo dijo el servidor. Un «error al enviar»
            // genérico no le dice al bodeguero qué corregir; «la cantidad
            // excede el saldo disponible» sí.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: sg.tinte(sg.rojoTexto),
                borderRadius: BorderRadius.circular(SgRadius.bloque),
              ),
              child: Text(
                item.ultimoError ?? 'El servidor lo rechazó sin dar un motivo.',
                style: sora(14, 500, color: sg.tinta, alto: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SgBoton('Corregir y reenviar',
                      icono: Icons.edit_outlined,
                      alto: 44,
                      tamanoTexto: 15,
                      onTap: onReintentar),
                ),
                const SizedBox(width: 9),
                SgBotonIcono(Icons.delete_outline,
                    fondo: sg.up,
                    color: sg.tinta2,
                    onTap: () => _confirmarDescarte(context)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Descartar borra trabajo capturado en terreno y no se puede deshacer, así
  /// que se pregunta. Es lo único de esta pantalla que sí destruye algo.
  Future<void> _confirmarDescarte(BuildContext context) async {
    final sg = context.sg;
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Descartar el registro?',
            style: sora(18, 600, color: sg.tinta)),
        content: Text(
          'Se borra del teléfono y no se envía. Lo que capturaste en terreno '
          'se pierde.',
          style: sora(14, 500, color: sg.tinta2, alto: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Conservar', style: sora(15, 600, color: sg.tinta2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Descartar', style: sora(15, 600, color: sg.rojoTexto)),
          ),
        ],
      ),
    );
    if (si == true) onDescartar();
  }
}
