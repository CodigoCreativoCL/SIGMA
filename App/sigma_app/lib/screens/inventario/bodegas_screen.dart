import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'ficha_bodega_screen.dart';

/// Las bodegas de la planta — vista 10.5 del diseño v3.
///
/// ## Para qué sirve una lista de bodegas
///
/// Para llegar a un estante. Nadie abre esta pantalla por curiosidad: la abre
/// quien va a buscar una pieza y necesita saber en qué bodega está y en qué
/// pasillo, o quien acaba de recibir algo y tiene que decidir dónde lo guarda.
///
/// Por eso la fila lleva a la ficha con sus ubicaciones, y no a un formulario:
/// crear y editar bodegas es del administrativo web, no de quien está en el
/// pasillo.
class BodegasScreen extends ConsumerWidget {
  const BodegasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final datos = ref.watch(bodegasProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Bodegas', tamanoTitulo: 23),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: EstadoAsync<Paginado<Bodega>>(
                valor: datos,
                onReintentar: () => ref.invalidate(bodegasProvider),
                child: (p) {
                  if (p.datos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SgAviso(
                          'Esta planta no tiene bodegas registradas. Se dan '
                          'de alta desde la web.',
                          icono: Icons.warehouse_outlined,
                          color: sg.tinta2,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(bodegasProvider),
                    child: ListView.separated(
                      padding: context.conBarraSistema(
                        const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      ),
                      itemCount: p.datos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _Fila(bodega: p.datos[i]),
                    ),
                  );
                },
              ),
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.bodega});

  final Bodega bodega;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;

    /* CUANTOS ESTANTES TIENE, SIN ABRIRLA

       Es la diferencia entre una bodega de un hueco y una nave con cuarenta
       posiciones, y decide si al consumir hay que indicar de cual sale. Se
       observa el mismo provider que usa la hoja de consumo, asi que la lista
       no dispara una consulta extra: cuando ya se leyeron, estan en memoria. */
    final estantes = ref.watch(ubicacionesBodegaProvider(bodega.bod_id));

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FichaBodegaScreen(
            bodegaId: bodega.bod_id,
            nombreConocido: bodega.bod_nombre,
          ),
        ),
      ),
      child: Row(
        children: [
          SgIconoCuadro(
            Icons.warehouse_outlined,
            color: sg.primarioTexto,
            lado: 44,
            tamanoIcono: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bodega.bod_nombre,
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    bodega.bod_codigo,
                    bodega.PLANTA_NOMBRE ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(12, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          estantes.when(
            // Sin numero mientras carga o si falla: un «0» que en realidad es
            // «no se pudo preguntar» dice algo falso sobre la bodega.
            loading: () => const SizedBox(width: 18),
            error: (_, _) =>
                Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
            data: (l) => l.isEmpty
                ? SgBadge('Sin estantes', color: sg.tinta3, chico: true)
                : SgBadge(
                    '${l.length} ${l.length == 1 ? 'estante' : 'estantes'}',
                    color: sg.acentoTexto,
                    chico: true,
                  ),
          ),
        ],
      ),
    );
  }
}
