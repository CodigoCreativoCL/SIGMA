import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/buscador.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'ficha_componente_screen.dart';

/// Los componentes de un equipo — vista 8.1 del diseño v3.
///
/// ## Para qué sirve, si ya está la ficha del activo
///
/// La ficha del activo dice qué es el equipo. Esta dice **de qué está hecho**,
/// que es la pregunta que aparece cuando algo falla: no se cambia «la
/// modeladora», se cambia el rodamiento del lado motor. Y es donde se ve, de
/// un vistazo, cuál de las piezas está degradada.
///
/// ## Por qué no sale de la sábana
///
/// A diferencia de los activos, los componentes **no bajan al teléfono**. No
/// es un olvido: la sábana carga lo que hace falta delante del equipo y sin
/// señal —la orden, la pauta, el activo—, y esta lista se mira antes de bajar
/// a la planta. Meterla en la sábana engordaría la descarga de todos para un
/// caso que no la necesita.
///
/// La consecuencia se dice en vez de esconderse: sin señal, esta pantalla
/// avisa que no pudo traerlos, en vez de mostrar una lista vacía que se lee
/// como «este equipo no tiene componentes».
class ComponentesScreen extends ConsumerStatefulWidget {
  const ComponentesScreen({super.key, this.activoId, this.activoNombre});

  /// El equipo del que se listan las piezas. Nulo = búsqueda global, que es
  /// la otra puerta que pide 8.1.
  final int? activoId;
  final String? activoNombre;

  @override
  ConsumerState<ComponentesScreen> createState() => _ComponentesScreenState();
}

class _ComponentesScreenState extends ConsumerState<ComponentesScreen> {
  final _buscar = TextEditingController();
  String _filtro = '';

  /// Solo los que piden atención.
  ///
  /// Un equipo de veinte piezas tiene dos con problema, y son las que importan
  /// cuando se baja con una falla en la mano.
  bool _soloAtencion = false;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final datos = ref.watch(componentesProvider(widget.activoId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        widget.activoNombre ?? 'Componentes',
        tamanoTitulo: widget.activoNombre == null ? 23 : 19,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SgCampo(
                controlador: _buscar,
                icono: Icons.search,
                hint: 'Código, nombre o tipo',
                onCambio: (v) => setState(() => _filtro = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: EstadoAsync<Paginado<Componente>>(
                valor: datos,
                onReintentar: () =>
                    ref.invalidate(componentesProvider(widget.activoId)),
                child: (p) {
                  if (p.datos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SgAviso(
                          widget.activoId == null
                              ? 'No hay componentes registrados.'
                              : 'Este equipo no tiene componentes '
                                    'registrados todavía. Se cargan desde la '
                                    'web.',
                          icono: Icons.category_outlined,
                          color: sg.tinta2,
                        ),
                      ),
                    );
                  }

                  final conAtencion = p.datos
                      .where((c) => c.enObservacion)
                      .length;
                  final visibles = _visibles(p.datos);

                  return Column(
                    children: [
                      if (conAtencion > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SgChip(
                              conAtencion == 1
                                  ? '1 pide atención'
                                  : '$conAtencion piden atención',
                              elegido: _soloAtencion,
                              onTap: () => setState(
                                () => _soloAtencion = !_soloAtencion,
                              ),
                            ),
                          ),
                        ),
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
                                    _Tarjeta(componente: visibles[i]),
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

  List<Componente> _visibles(List<Componente> todos) {
    var l = todos;

    if (_soloAtencion) l = l.where((c) => c.enObservacion).toList();

    if (_filtro.trim().isEmpty) return l;

    // La misma tolerancia del resto de la app: «cmp 33 1» encuentra CMP-33-01.
    return l
        .where(
          (c) => coincideBusqueda(_filtro, [
            c.ACO_CODIGO,
            c.ACO_NOMBRE,
            c.TIPO_NOMBRE,
            c.POSICION_NOMBRE,
            c.ACTIVO_CODIGO,
          ]),
        )
        .toList();
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.componente});

  final Componente componente;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final c = componente;

    /* LA CRITICIDAD Y EL ESTADO DICEN COSAS DISTINTAS

       La criticidad es lo que pasa SI falla —y no cambia—; el estado es cómo
       está HOY. Un rodamiento «Media» degradado y un motor «Crítica»
       operativo no piden lo mismo, y mezclarlos en un solo color haría que la
       lista no sirviera para decidir por dónde empezar. Por eso el estado
       manda el color de la tarjeta y la criticidad va como su propia
       píldora. */
    final atencion = c.enObservacion;

    return SgCard(
      padding: const EdgeInsets.all(14),
      elegida: atencion,
      colorAnillo: atencion ? sg.ambarTexto : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FichaComponenteScreen(componenteId: c.ACO_ID),
        ),
      ),
      child: Row(
        children: [
          if ((c.FOTO_RUTA ?? '').isEmpty)
            SgIconoCuadro(
              Icons.settings_outlined,
              color: atencion ? sg.ambarTexto : sg.primarioTexto,
              lado: 48,
              tamanoIcono: 23,
            )
          else
            SigmaImagen(
              ruta: c.FOTO_RUTA,
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
                  c.ACO_NOMBRE,
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    c.ACO_CODIGO,
                    c.TIPO_NOMBRE ?? '',
                    c.POSICION_NOMBRE ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(12, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((c.PADRE_NOMBRE ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right,
                        size: 13,
                        color: sg.tinta3,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Va en ${c.PADRE_NOMBRE}',
                          style: sora(11, 500, color: sg.tinta3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if ((c.ESTADO_NOMBRE ?? '').isNotEmpty)
                SgBadge(
                  c.ESTADO_NOMBRE!,
                  color: atencion ? sg.ambarTexto : sg.verdeTexto,
                  chico: true,
                ),
              if ((c.CRITICIDAD_NOMBRE ?? '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  c.CRITICIDAD_NOMBRE!,
                  style: sora(10, 600, color: sg.tinta3),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
