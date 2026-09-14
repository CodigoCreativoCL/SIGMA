import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'falla_ficha_screen.dart';
import 'nueva_falla_screen.dart';

/// Las fallas de la planta — HU-123.
///
/// ## Qué muestra
///
/// Por defecto las que aún no tienen solución: en terreno la pregunta es «qué
/// está roto», no «qué se rompió en marzo». El chip «Resueltas» está para la
/// otra pregunta.
///
/// ## El equipo que pide atención
///
/// Una falla reparada de forma provisoria varias veces es un equipo al que
/// hay que hacerle un diagnóstico de fondo y no otro parche. El servidor
/// cuenta las provisorias del equipo y la tarjeta lo dice con un aviso.
class FallasScreen extends ConsumerWidget {
  const FallasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final fallas = ref.watch(fallasProvider);
    final filtro = ref.watch(filtroFallasProvider);
    final puedeRegistrar = ref.watch(tienePermisoProvider('REGISTRAR FALLA'));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Fallas'),
      floatingActionButton: !puedeRegistrar
          ? null
          : FloatingActionButton.extended(
              heroTag: 'nuevaFalla',
              backgroundColor: sg.primario,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                'Registrar falla',
                style: sora(14, 600, color: Colors.white),
              ),
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const NuevaFallaScreen()),
                );
                if (ok == true) ref.invalidate(fallasProvider);
              },
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                SgChip(
                  'Sin solución',
                  elegido: filtro == true,
                  onTap: () =>
                      ref.read(filtroFallasProvider.notifier).state = true,
                ),
                const SizedBox(width: 8),
                SgChip(
                  'Resueltas',
                  elegido: filtro == false,
                  onTap: () =>
                      ref.read(filtroFallasProvider.notifier).state = false,
                ),
                const SizedBox(width: 8),
                SgChip(
                  'Todas',
                  elegido: filtro == null,
                  onTap: () =>
                      ref.read(filtroFallasProvider.notifier).state = null,
                ),
              ],
            ),
          ),
          Expanded(
            child: EstadoAsync<List<Falla>>(
              valor: fallas,
              onReintentar: () => ref.invalidate(fallasProvider),
              estaVacio: (l) => l.isEmpty,
              vacio: const EstadoVacio(
                icono: Icons.build_circle_outlined,
                titulo: 'Sin fallas',
                detalle: 'Ninguna falla en esta planta con ese filtro.',
              ),
              child: (lista) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(fallasProvider),
                child: ListView.separated(
                  padding: context.conBarraSistema(
                    const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  ),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => TarjetaFalla(
                    falla: lista[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FallaFichaScreen(fallaId: lista[i].FAL_ID),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una falla en la lista: qué, en qué equipo, cómo va.
class TarjetaFalla extends StatelessWidget {
  const TarjetaFalla({super.key, required this.falla, this.onTap});

  final Falla falla;
  final VoidCallback? onTap;

  static final _fecha = DateFormat('dd-MM · HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final f = falla;

    return SgCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.codigo, style: sora(12, 700, color: sg.tinta3)),
              const SizedBox(width: 8),
              SgBadge(
                f.CRITICIDAD_NOMBRE ?? '',
                color: colorCriticidad(sg, f.FAL_CRITICIDAD_NIVEL),
                chico: true,
              ),
              const Spacer(),
              SgBadge(f.situacion, color: colorSituacion(sg, f), chico: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            f.FAL_TITULO,
            style: sora(15, 600, color: sg.tinta),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [
              f.activo,
              if (f.FAL_FECHA_DETECCION_UTC != null)
                _fecha.format(f.FAL_FECHA_DETECCION_UTC!.toLocal()),
              if (f.ORDENES > 0) 'OT-${f.ULTIMA_OT_CORRELATIVO}',
            ].join(' · '),
            style: sora(12, 500, color: sg.tinta2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (f.FAL_DETUVO_PRODUCCION || f.equipoConHistorial) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (f.FAL_DETUVO_PRODUCCION)
                  SgBadge(
                    'Detuvo producción',
                    color: sg.rojoTexto,
                    icono: Icons.factory_outlined,
                    chico: true,
                  ),
                if (f.equipoConHistorial)
                  SgBadge(
                    '${f.PROVISORIAS_DEL_EQUIPO} reparaciones provisorias',
                    color: sg.ambarTexto,
                    icono: Icons.repeat,
                    chico: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color colorCriticidad(AppColors sg, int nivel) => switch (nivel) {
    4 || 3 => sg.rojoTexto,
    2 => sg.ambarTexto,
    _ => sg.tinta2,
  };

  static Color colorSituacion(AppColors sg, Falla f) => f.resuelta
      ? sg.verdeTexto
      : f.ACCIONES_PROVISORIAS > 0
      ? sg.ambarTexto
      : f.DIAGNOSTICOS > 0
      ? sg.primarioTexto
      : sg.rojoTexto;
}
