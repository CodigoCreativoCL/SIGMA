import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/buscador.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import 'activo_ficha_screen.dart';

/// Los equipos de la planta — vista 7.2 del diseño v3.
///
/// ## Por qué hace falta, si ya está el escáner
///
/// El escáner sirve cuando se está **delante** del equipo. Esta pantalla sirve
/// para lo contrario: encontrar un equipo del que solo se sabe el nombre, o
/// mirar qué hay en un área antes de bajar. También cuando la etiqueta está
/// rayada, que en una planta de diez años es la mitad.
///
/// ## De dónde salen
///
/// **De la sábana, no de la red.** No hay `GET /activos` —`ActivosController`
/// expone la ficha y su historial— y no hace falta: los activos ya bajan
/// enteros al teléfono, que es como la app trabaja sin señal.
///
/// La consecuencia se dice en vez de esconderse: si la sábana no se ha bajado,
/// la lista sale vacía, y la pantalla explica que se arregla sincronizando.
/// Callarlo dejaría a alguien creyendo que la planta no tiene equipos.
class ActivosScreen extends ConsumerStatefulWidget {
  const ActivosScreen({super.key});

  @override
  ConsumerState<ActivosScreen> createState() => _ActivosScreenState();
}

class _ActivosScreenState extends ConsumerState<ActivosScreen> {
  final _buscar = TextEditingController();
  String _filtro = '';

  /// El área por la que se filtra. Nula = todas.
  ///
  /// Se filtra por **nombre** y no por id porque el activo trae el nombre del
  /// área y no su id: es lo que hay, y forzar un id obligaría a cruzar dos
  /// listas en el teléfono para el mismo resultado.
  String? _area;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final datos = ref.watch(activosProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Equipos', tamanoTitulo: 23),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SgCampo(
                controlador: _buscar,
                icono: Icons.search,
                hint: 'Código, nombre, serie o marca',
                conVoz: true,
                onCambio: (v) => setState(() => _filtro = v),
                onVoz: () async {
                  final campos = await mostrarPanelVoz(
                    context,
                    titulo: 'Buscar un equipo',
                    interpretar: (t) => [
                      CampoDictado(
                        clave: 'busqueda',
                        rotulo: 'Buscar',
                        valor: InterpreteVoz.normalizar(t),
                      ),
                    ],
                  );
                  if (campos == null || campos.isEmpty) return;
                  final texto = campos.first.valor;
                  setState(() {
                    escribirDictado(_buscar, texto);
                    _filtro = texto;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: EstadoAsync<List<Activo>>(
                valor: datos,
                onReintentar: () => ref.invalidate(activosProvider),
                child: (todos) {
                  if (todos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SgAviso(
                          'No hay equipos en el teléfono. Se bajan con la '
                          'sincronización, junto con el resto de la planta.',
                          icono: Icons.cloud_download_outlined,
                          color: sg.ambarTexto,
                        ),
                      ),
                    );
                  }

                  final areas = _areasDe(todos);
                  final visibles = _visibles(todos);

                  return Column(
                    children: [
                      if (areas.length > 1) ...[
                        SizedBox(
                          // Al mismo paso que el chip que lleva dentro: si el riel no crece, el
                          //    chip crecido se recorta.
                          height: context.alto(36),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              SgChip(
                                'Todas',
                                elegido: _area == null,
                                onTap: () => setState(() => _area = null),
                              ),
                              for (final a in areas) ...[
                                const SizedBox(width: 8),
                                SgChip(
                                  a,
                                  elegido: _area == a,
                                  onTap: () => setState(() => _area = a),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: visibles.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: SgAviso(
                                    'Nada coincide con esa búsqueda.',
                                    icono: Icons.search_off,
                                    color: sg.tinta2,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: context.conBarraSistema(
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                ),
                                itemCount: visibles.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) =>
                                    _Tarjeta(activo: visibles[i]),
                              ),
                      ),
                    ],
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

  /// Las áreas que de verdad tienen equipos, ordenadas.
  ///
  /// Se sacan de los activos y no de `areasProvider`: un chip de un área vacía
  /// solo sirve para llevar a una lista vacía.
  List<String> _areasDe(List<Activo> todos) {
    final set = <String>{};
    for (final a in todos) {
      final n = (a.AREA_NOMBRE ?? '').trim();
      if (n.isNotEmpty) set.add(n);
    }
    final l = set.toList()..sort();
    return l;
  }

  List<Activo> _visibles(List<Activo> todos) {
    var l = todos;

    if (_area != null) {
      l = l.where((a) => (a.AREA_NOMBRE ?? '').trim() == _area).toList();
    }

    if (_filtro.trim().isEmpty) return l;

    // Misma tolerancia que la bandeja: «act33» encuentra `ACT-33`.
    return l
        .where(
          (a) => coincideBusqueda(_filtro, [
            a.act_codigo,
            a.act_nombre,
            a.act_numero_serie,
            a.act_fabricante,
            a.act_modelo,
            a.AREA_NOMBRE,
          ]),
        )
        .toList();
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.activo});

  final Activo activo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    /* EL ESTADO MANDA EL COLOR

       Un equipo detenido o fuera de servicio es lo que hay que ver de un
       vistazo en una lista de treinta: es donde está el trabajo. El código de
       estado lo decide la base, no la pantalla. */
    final estado = (activo.ESTADO_CODIGO ?? '').toUpperCase();
    final parado =
        estado.contains('DETEN') ||
        estado.contains('FUERA') ||
        estado.contains('BAJA');

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivoFichaScreen(activoId: activo.act_id),
        ),
      ),
      child: Row(
        children: [
          // La foto si la hay; si no, el icono del equipo. Nunca un marco
          // vacío, que se lee como «esto no cargó».
          if ((activo.FOTO_RUTA ?? '').isEmpty)
            SgIconoCuadro(
              Icons.view_in_ar_outlined,
              color: parado ? sg.ambarTexto : sg.primarioTexto,
              lado: 48,
              tamanoIcono: 23,
            )
          else
            SigmaImagen(
              ruta: activo.FOTO_RUTA,
              ancho: 48,
              alto: 48,
              radio: 14,
              ampliable: false,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activo.act_nombre,
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    activo.act_codigo,
                    activo.AREA_NOMBRE ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(12, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if ((activo.ESTADO_NOMBRE ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            SgBadge(
              activo.ESTADO_NOMBRE!,
              color: parado ? sg.ambarTexto : sg.verdeTexto,
              chico: true,
            ),
          ],
        ],
      ),
    );
  }
}
