import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import 'ficha_repuesto_screen.dart';

/// El catálogo de repuestos — vista 10.2 del diseño v3.
///
/// ## En qué se diferencia de Existencias
///
/// Existencias es **una fila por bodega** y responde «qué está bajo mínimo»:
/// es la pantalla del bodeguero que reparte. Ésta es **una fila por pieza** y
/// responde «existe esto en el sistema, y con qué código». Es la que se abre
/// cuando alguien tiene una pieza en la mano y no sabe cómo se llama acá.
///
/// Por eso el buscador manda: se llega con un número de fabricante grabado en
/// el metal —«6205 2RS»— y hay que encontrar la ficha.
///
/// ## Por qué se lee del teléfono
///
/// El catálogo cambia una vez al mes y se consulta delante del estante, donde
/// no hay señal. El repositorio ya elige el origen: con señal manda el
/// servidor, sin señal el disco, y un 403 sigue siendo un 403.
class RepuestosScreen extends ConsumerStatefulWidget {
  const RepuestosScreen({super.key});

  @override
  ConsumerState<RepuestosScreen> createState() => _RepuestosScreenState();
}

class _RepuestosScreenState extends ConsumerState<RepuestosScreen> {
  final _buscar = TextEditingController();
  String _filtro = '';

  /// Solo los que tienen saldo. Apagado por omisión: el catálogo es el
  /// catálogo, y una pieza con cero sigue existiendo —hay que poder abrir su
  /// ficha para pedirla—.
  bool _soloConSaldo = false;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final datos = ref.watch(repuestosProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Repuestos', tamanoTitulo: 23),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  SgCampo(
                    controlador: _buscar,
                    icono: Icons.search,
                    hint: 'Código, nombre, fabricante o modelo',
                    conVoz: true,
                    onCambio: (v) =>
                        setState(() => _filtro = v.trim().toLowerCase()),
                    onVoz: () async {
                      final campos = await mostrarPanelVoz(
                        context,
                        titulo: 'Buscar un repuesto',
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
                        _filtro = texto.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SgChip(
                        'Con saldo',
                        elegido: _soloConSaldo,
                        onTap: () =>
                            setState(() => _soloConSaldo = !_soloConSaldo),
                      ),
                      const Spacer(),
                      Text(
                        _resumen(datos.valueOrNull?.datos),
                        style: sora(12, 600, color: sg.tinta3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: EstadoAsync<Paginado<Repuesto>>(
                valor: datos,
                onReintentar: () => ref.invalidate(repuestosProvider),
                child: (p) {
                  final visibles = _visibles(p.datos);

                  if (visibles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SgAviso(
                          p.datos.isEmpty
                              ? 'No hay repuestos en el catálogo. Se dan de '
                                    'alta desde la web.'
                              : _soloConSaldo && _filtro.isEmpty
                              ? 'Ninguna pieza del catálogo tiene saldo en '
                                    'esta planta.'
                              : 'Nada coincide con esa búsqueda.',
                          icono: Icons.inventory_2_outlined,
                          color: sg.tinta2,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(repuestosProvider),
                    child: ListView.separated(
                      padding: context.conBarraSistema(
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      ),
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _Tarjeta(repuesto: visibles[i]),
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

  List<Repuesto> _visibles(List<Repuesto> todos) {
    var l = todos;

    if (_soloConSaldo) {
      l = l.where((r) => r.EXISTENCIA_TOTAL > 0).toList();
    }

    if (_filtro.isEmpty) return l;

    /* Se busca en los cuatro campos con que alguien puede llegar: el codigo de
       SIGMA, el nombre, y el fabricante y modelo grabados en la pieza. Quien
       tiene el rodamiento en la mano lee «SKF 6205» del metal, no «REP-6205»
       de una etiqueta que puede estar rayada. */
    return l.where((r) {
      final t = [
        r.rep_codigo,
        r.rep_nombre,
        r.rep_fabricante ?? '',
        r.rep_modelo ?? '',
      ].join(' ').toLowerCase();
      return t.contains(_filtro);
    }).toList();
  }

  String _resumen(List<Repuesto>? todos) {
    if (todos == null) return '';
    final v = _visibles(todos).length;
    return v == todos.length ? '$v piezas' : '$v de ${todos.length}';
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.repuesto});

  final Repuesto repuesto;

  static final _n = NumberFormat.decimalPattern('es_CL');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final hay = repuesto.EXISTENCIA_TOTAL > 0;
    final descripcion = repuesto.descripcionCorta;

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FichaRepuestoScreen(
            repuestoId: repuesto.rep_id,
            nombreConocido: repuesto.rep_nombre,
          ),
        ),
      ),
      child: Row(
        children: [
          SgIconoCuadro(
            Icons.inventory_2_outlined,
            // Verde o gris, no rojo: cero saldo en el CATALOGO no es una
            // alarma. Que algo este bajo minimo lo dice Existencias, que es la
            // pantalla que vigila el saldo.
            color: hay ? sg.verdeTexto : sg.tinta3,
            lado: 44,
            tamanoIcono: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repuesto.rep_nombre,
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    repuesto.rep_codigo,
                    if (descripcion.isNotEmpty) descripcion,
                  ].join(' · '),
                  style: sora(12, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis,
                ),
                if (repuesto.rep_controla_lote) ...[
                  const SizedBox(height: 6),
                  SgBadge(
                    'Controla lote',
                    color: sg.ambarTexto,
                    icono: Icons.event_outlined,
                    chico: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SgCifra(
            hay ? _n.format(repuesto.EXISTENCIA_TOTAL) : '0',
            unidad: repuesto.UNIDAD_SIMBOLO,
            color: hay ? sg.tinta : sg.tinta3,
          ),
        ],
      ),
    );
  }
}
