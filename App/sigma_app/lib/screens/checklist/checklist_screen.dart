import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'ejecucion_checklist_screen.dart';

/// Checklist en terreno · la bandeja — HU-095.
///
/// ## Retomar, no reempezar
///
/// Si la pauta ya tiene un borrador de esta persona, la tarjeta dice
/// **«Continuar»** y abre esa ejecución. Empezar otra perdería lo caminado, y
/// en una ronda eso significa volver a recorrer la planta.
class ChecklistScreen extends ConsumerWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final pendientes = ref.watch(checklistPendientesProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Pautas de hoy',
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
      body: EstadoAsync<List<ChecklistPendiente>>(
        valor: pendientes,
        onReintentar: () => ref.invalidate(checklistPendientesProvider),
        estaVacio: (l) => l.isEmpty,
        vacio: const EstadoVacio(
          icono: Icons.fact_check_outlined,
          titulo: 'No tienes pautas pendientes',
          detalle: 'Las rondas se programan desde la web. Cuando te toque una, '
              'aparece acá y se puede llenar sin señal.',
        ),
        child: (lista) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(checklistPendientesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 11),
            itemBuilder: (_, i) => _Tarjeta(
              pauta: lista[i],
              onAbrir: () => _abrir(context, ref, lista[i]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(
      BuildContext context, WidgetRef ref, ChecklistPendiente p) async {
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    try {
      // El uuid se genera acá, **antes** de llamar: si se generara al enviar,
      // un reintento traería uno nuevo y abriría una segunda ejecución de la
      // misma ronda. Es el mismo generador de la cola de salida —con
      // `Random.secure()` y no con el reloj— porque dos teléfonos que abren la
      // ronda en el mismo microsegundo no pueden producir el mismo id.
      final id = await SigmaRepository.instance.abrirChecklist({
        'uuid': OutboxService.nuevoUuid(),
        'ocurrencia': p.coc_id,
        'version': p.VERSION_ID,
        'activo': p.ACTIVO_ID,
        'offline': !SyncService.instance.enLinea.value,
      });

      if (id == 0) {
        mensajero.showSnackBar(
            const SnackBar(content: Text('No se pudo abrir la pauta.')));
        return;
      }

      await navegador.push(MaterialPageRoute(
        builder: (_) => EjecucionChecklistScreen(
          ejecucionId: id,
          versionId: p.VERSION_ID,
        ),
      ));
      ref.invalidate(checklistPendientesProvider);
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.pauta, required this.onAbrir});

  final ChecklistPendiente pauta;
  final VoidCallback onAbrir;

  static final _hora = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final limite = pauta.coc_fecha_limite_utc?.toLocal();

    return SgCard(
      padding: const EdgeInsets.all(14),
      elevada: pauta.vencida,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SgIconoCuadro(Icons.fact_check_outlined,
                  color: pauta.vencida ? sg.rojoTexto : sg.acentoTexto,
                  lado: 44,
                  tamanoIcono: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (pauta.vencida)
                          SgBadge('Vencida',
                              color: sg.rojoTexto, chico: true),
                        if (pauta.empezada)
                          SgBadge('Empezada',
                              color: sg.ambarTexto,
                              icono: Icons.edit_note,
                              chico: true),
                        SgBadge('${pauta.ITEM_TOTAL} ítems',
                            color: sg.tinta2, chico: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(pauta.PLANTILLA_NOMBRE,
                        style: sora(16, 600, color: sg.tinta, alto: 1.35)),
                    if (pauta.donde.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: sg.tinta3),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(pauta.donde,
                                style: sora(12, 500, color: sg.tinta3),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (limite != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14,
                              color:
                                  pauta.vencida ? sg.rojoTexto : sg.tinta3),
                          const SizedBox(width: 5),
                          Text('Hasta las ${_hora.format(limite)}',
                              style: sora(12, 500,
                                  color: pauta.vencida
                                      ? sg.rojoTexto
                                      : sg.tinta3)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SgBoton(
            pauta.empezada ? 'Continuar' : 'Empezar ronda',
            icono: pauta.empezada ? Icons.play_arrow : Icons.arrow_forward,
            iconoAlFinal: !pauta.empezada,
            alto: 44,
            tamanoTexto: 14,
            onTap: onAbrir,
          ),
        ],
      ),
    );
  }
}
