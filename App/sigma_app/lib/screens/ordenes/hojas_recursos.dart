import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_compartir.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Lo que devuelve la hoja de compañero.
typedef TramoCompanero = ({Companero quien, DateTime desde, DateTime hasta});

/// Lo que devuelve la hoja de repuesto.
typedef ConsumoRepuesto = ({
  int repuesto,
  int bodega,
  double cantidad,
  String nombre
});

/// Elegir a quién se suma al trabajo y cuánto estuvo — HU-115.
///
/// ## Por qué el tramo es de OTRA persona
///
/// Un motor pesado no lo saca uno solo. Hoy el que registra es el único que
/// aparece, así que la orden termina firmada por uno aunque la hicieron dos, y
/// las horas de la planta salen a la mitad de lo que fueron.
///
/// `@USUARIO_TRAMO` ya existía en el SP: era la pieza que faltaba usar.
///
/// ## Por qué no reasigna la orden
///
/// El responsable no cambia: quien se suma **participa**. Reasignarla le
/// quitaría el trabajo a quien lo pidió.
class HojaCompanero extends ConsumerStatefulWidget {
  const HojaCompanero({super.key, required this.instalacionId});

  final int instalacionId;

  @override
  ConsumerState<HojaCompanero> createState() => _HojaCompaneroState();
}

class _HojaCompaneroState extends ConsumerState<HojaCompanero> {
  Companero? _elegido;
  int _minutos = 60;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final companeros = ref.watch(companerosProvider(widget.instalacionId));

    return HojaRecurso(
      titulo: 'Sumar a un compañero',
      detalle: 'Queda como participante del trabajo. El responsable no cambia.',
      children: [
        const SgRotulo('Quién participó'),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
          child: companeros.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SgAviso(
              e is ApiException
                  ? e.mensaje
                  : 'No se pudo cargar la lista de compañeros.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (lista) => lista.isEmpty
                ? SgAviso(
                    'No hay nadie más asignado a esta planta. Las asignaciones '
                    'se hacen desde la web.',
                    icono: Icons.person_off_outlined,
                    color: sg.tinta2,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = lista[i];
                      final elegido = _elegido?.usu_id == c.usu_id;
                      return SgFila(
                        texto: c.NOMBRE,
                        // El perfil importa: para un acople eléctrico se suma
                        // al eléctrico, no al primero de la lista.
                        detalle: c.PERFIL_NOMBRE,
                        icono: elegido
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        colorIcono: elegido ? sg.primarioTexto : sg.tinta3,
                        onTap: () => setState(() => _elegido = c),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        const SgRotulo('Cuánto estuvo'),
        const SizedBox(height: 9),
        // Cuatro tramos redondos en vez de dos relojes: nadie recuerda el
        // minuto exacto en que llegó un compañero, y pedirlo obliga a inventar
        // una precisión que no existe.
        Row(
          children: [
            for (final m in const [30, 60, 120, 240]) ...[
              Expanded(
                child: SgChip(
                  m < 60 ? '$m min' : '${m ~/ 60} h',
                  elegido: _minutos == m,
                  onTap: () => setState(() => _minutos = m),
                ),
              ),
              if (m != 240) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SgBoton(
          'Sumar al trabajo',
          icono: Icons.person_add_alt,
          onTap: _elegido == null
              ? null
              : () {
                  final ahora = DateTime.now();
                  Navigator.of(context).pop((
                    quien: _elegido!,
                    desde: ahora.subtract(Duration(minutes: _minutos)),
                    hasta: ahora,
                  ));
                },
        ),
      ],
    );
  }
}

/// Elegir qué repuesto se consumió y cuánto — HU-116.
///
/// ## Por qué la lista sale de las existencias y no del catálogo
///
/// Lo que importa es **qué hay en la bodega de esta planta y cuánto queda**.
/// Ofrecer una pieza que el catálogo conoce pero la bodega no tiene manda al
/// técnico a buscar algo que no está, y ese viaje perdido es exactamente lo
/// que la app existe para evitar.
class HojaRepuesto extends ConsumerStatefulWidget {
  const HojaRepuesto({super.key});

  @override
  ConsumerState<HojaRepuesto> createState() => _HojaRepuestoState();
}

class _HojaRepuestoState extends ConsumerState<HojaRepuesto> {
  final _buscar = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  InventarioSaldo? _elegido;
  String _filtro = '';

  @override
  void dispose() {
    _buscar.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  double? get _cuanto {
    final v = double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toString();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final existencias = ref.watch(existenciasProvider);

    // Pasarse del saldo lo rechaza el SP igual, pero avisar antes ahorra el
    // viaje de red y explica por qué: el número está a la vista.
    final sobrepasa = _elegido != null &&
        _cuanto != null &&
        _cuanto! > _elegido!.CANTIDAD_DISPONIBLE;

    return HojaRecurso(
      titulo: 'Consumir un repuesto',
      detalle: 'Descuenta de la bodega y queda anotado en la orden, en una '
          'sola operación.',
      children: [
        SgCampo(
          controlador: _buscar,
          icono: Icons.search,
          hint: 'Buscar por código o nombre',
          onCambio: (v) => setState(() => _filtro = v.toLowerCase().trim()),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.28),
          child: existencias.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SgAviso(
              e is ApiException
                  ? e.mensaje
                  : 'No se pudieron cargar las existencias.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (p) {
              // Solo lo que tiene saldo: una fila en cero es una pieza que no
              // se puede consumir, y ofrecerla solo sirve para fallar.
              final visibles = p.datos
                  .where((x) =>
                      x.CANTIDAD_DISPONIBLE > 0 &&
                      (_filtro.isEmpty ||
                          '${x.REPUESTO_CODIGO} ${x.REPUESTO_NOMBRE}'
                              .toLowerCase()
                              .contains(_filtro)))
                  .toList();

              if (visibles.isEmpty) {
                return SgAviso(
                  _filtro.isEmpty
                      ? 'No hay existencias con saldo en esta planta.'
                      : 'Nada coincide con esa búsqueda.',
                  icono: Icons.inventory_2_outlined,
                  color: sg.tinta2,
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: visibles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = visibles[i];
                  final elegido = _elegido?.isa_id == x.isa_id;
                  return SgFila(
                    texto: '${x.REPUESTO_CODIGO} · ${x.REPUESTO_NOMBRE}',
                    detalle: '${_num(x.CANTIDAD_DISPONIBLE)} '
                        '${x.UNIDAD_SIMBOLO ?? ''} · '
                        '${x.BODEGA_NOMBRE ?? 'bodega'}',
                    icono: elegido
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    colorIcono: elegido ? sg.primarioTexto : sg.tinta3,
                    onTap: () => setState(() => _elegido = x),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const SgRotuloCampo('Cantidad'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _cantidad,
          icono: Icons.tag,
          hint: '1',
          onCambio: (_) => setState(() {}),
        ),
        if (sobrepasa) ...[
          const SizedBox(height: 10),
          SgAviso(
            'Solo hay ${_num(_elegido!.CANTIDAD_DISPONIBLE)} '
            '${_elegido!.UNIDAD_SIMBOLO ?? ''} disponibles.',
            icono: Icons.warning_amber,
            color: sg.rojoTexto,
          ),
        ],
        const SizedBox(height: 14),
        SgBoton(
          'Consumir',
          icono: Icons.check,
          onTap: (_elegido == null || _cuanto == null || sobrepasa)
              ? null
              : () => Navigator.of(context).pop((
                    repuesto: _elegido!.isa_repuesto,
                    bodega: _elegido!.isa_bodega,
                    cantidad: _cuanto!,
                    nombre: _elegido!.REPUESTO_NOMBRE,
                  )),
        ),
      ],
    );
  }
}

/// El envoltorio de las dos hojas: agarradera, título y el hueco del teclado.
class HojaRecurso extends StatelessWidget {
  const HojaRecurso({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.children,
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      decoration: BoxDecoration(
        color: sg.fondo,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            // La hoja sube con el teclado: sin esto tapa el botón justo al
            // escribir la cantidad.
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sg.indicador,
                      borderRadius: BorderRadius.circular(SgRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(titulo, style: sora(17, 600, color: sg.tinta)),
                const SizedBox(height: 4),
                Text(detalle,
                    style: sora(13, 500, color: sg.tinta3, alto: 1.45)),
                const SizedBox(height: 15),
                ...children,
                const SgBarraGestos(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
