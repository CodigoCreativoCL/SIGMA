import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'hoja_ajuste.dart';

/// 10.3 · Ficha del repuesto.
///
/// ## La pregunta que responde
///
/// El listado de existencias es **una fila por bodega**: el mismo rodamiento
/// aparece tres veces si está en tres bodegas, y para saber cuántos hay en la
/// planta había que sumarlos a ojo. Esta pantalla da vuelta la pregunta: un
/// repuesto, **dónde está y cuánto hay en cada sitio**.
///
/// Por eso `GET /existencias/repuesto/{id}` no viene paginado —un repuesto no
/// vive en doscientas bodegas— y la ficha puede sumar el total sin juntar
/// páginas.
///
/// ## Los lotes solo si el repuesto los controla
///
/// `rep_controla_lote` decide si la sección existe. Un perno no tiene lote y
/// mostrar «sin lotes» para él enseña a ignorar la sección; un aceite sí, y ahí
/// **la fecha de vencimiento es la que importa**: entregar de un lote vencido
/// es el error que esta pantalla tiene que hacer difícil, así que el vencido va
/// marcado en rojo y arriba, no escondido al final de la lista.
class FichaRepuestoScreen extends ConsumerWidget {
  const FichaRepuestoScreen({
    super.key,
    required this.repuestoId,
    this.nombreConocido,
  });

  final int repuestoId;

  /// El nombre que ya traía la fila desde donde se abrió. Se pinta en la barra
  /// mientras baja la ficha: un título vacío durante un segundo hace dudar de
  /// si se abrió lo que se tocó.
  final String? nombreConocido;

  static final _n = NumberFormat.decimalPattern('es_CL');
  static final _fecha = DateFormat('dd-MM-yyyy', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final ficha = ref.watch(repuestoProvider(repuestoId));
    final saldos = ref.watch(saldosRepuestoProvider(repuestoId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: AppBar(
        backgroundColor: sg.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text(
          ficha.valueOrNull?.rep_nombre ?? nombreConocido ?? 'Repuesto',
          style: sora(17, 600, color: sg.tinta),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(repuestoProvider(repuestoId));
            ref.invalidate(saldosRepuestoProvider(repuestoId));
            ref.invalidate(lotesProvider(repuestoId));
          },
          child: EstadoAsync<Repuesto>(
            valor: ficha,
            onReintentar: () => ref.invalidate(repuestoProvider(repuestoId)),
            child: (r) => ListView(
              padding: context.conBarraSistema(
                const EdgeInsets.fromLTRB(16, 4, 16, 24),
              ),
              children: [
                _Cabecera(repuesto: r),
                const SizedBox(height: 16),

                const SgRotulo('Dónde está'),
                const SizedBox(height: 9),
                EstadoAsync<List<InventarioSaldo>>(
                  valor: saldos,
                  alturaCarga: 120,
                  onReintentar: () =>
                      ref.invalidate(saldosRepuestoProvider(repuestoId)),
                  estaVacio: (l) => l.isEmpty,
                  /* SIN EXISTENCIA NO ES UN ERROR

                     Que un repuesto no esté en ninguna bodega significa que no
                     queda ninguno, que es justo lo que se vino a averiguar. Un
                     estado de error acá haría pensar que la consulta falló. */
                  vacio: const EstadoVacio(
                    icono: Icons.inventory_2_outlined,
                    titulo: 'Sin existencia',
                    detalle: 'No queda ninguno en las bodegas de tus plantas.',
                  ),
                  child: (lista) => Column(
                    children: [
                      for (final s in lista) ...[
                        _FilaBodega(saldo: s, formato: _n.format),
                        const SizedBox(height: 9),
                      ],
                    ],
                  ),
                ),

                /* LOS LOTES, SOLO SI LOS CONTROLA

                   Sin este `if`, un perno mostraría una sección vacía y la
                   siguiente vez nadie la miraría — incluido el aceite, donde sí
                   importa. */
                if (r.rep_controla_lote) ...[
                  const SizedBox(height: 8),
                  const SgRotulo('Lotes'),
                  const SizedBox(height: 9),
                  _Lotes(repuestoId: repuestoId, fecha: _fecha),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El encabezado: qué es y cuánto hay en total.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.repuesto});

  final Repuesto repuesto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final detalle = repuesto.descripcionCorta;

    return SgCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SgIconoCuadro(
            Icons.inventory_2_outlined,
            color: sg.acentoTexto,
            lado: 48,
            tamanoIcono: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repuesto.rep_codigo,
                  style: sora(12, 600, color: sg.acentoTexto),
                ),
                const SizedBox(height: 3),
                Text(
                  repuesto.rep_nombre,
                  style: sora(17, 600, color: sg.tinta, alto: 1.3),
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(detalle, style: sora(13, 500, color: sg.tinta3)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // El total de la planta, que es lo que el listado por bodega no
          // podía responder sin sumar filas a ojo.
          SgCifra(
            NumberFormat.decimalPattern(
              'es_CL',
            ).format(repuesto.EXISTENCIA_TOTAL),
            unidad: repuesto.UNIDAD_SIMBOLO,
            tamano: 22,
            color: sg.tinta,
          ),
        ],
      ),
    );
  }
}

/// Una bodega donde hay existencia de este repuesto.
class _FilaBodega extends ConsumerWidget {
  const _FilaBodega({required this.saldo, required this.formato});

  final InventarioSaldo saldo;
  final String Function(num) formato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final puedeAjustar = ref.watch(tienePermisoProvider('AJUSTAR INVENTARIO'));

    final (Color color, String? etiqueta) = saldo.bajoMinimo
        ? (sg.rojoTexto, 'Bajo mínimo')
        : saldo.sobreMaximo
        ? (sg.ambarTexto, 'Sobre máximo')
        : (sg.verdeTexto, null);

    return SgCard(
      padding: const EdgeInsets.all(13),
      /* AJUSTAR TAMBIEN SE PUEDE DESDE ACA

         Es la misma regla del listado: el bodeguero cuenta con la pantalla
         abierta y el ajuste sale de la fila que está mirando. Si llegó a la
         ficha buscando dónde estaba la pieza, obligarlo a volver al listado
         para corregir el saldo sería un viaje de ida y vuelta por nada. */
      onTap: !puedeAjustar ? null : () => HojaAjuste.abrir(context, saldo),
      child: Row(
        children: [
          SgIconoCuadro(
            Icons.warehouse_outlined,
            color: color,
            lado: 40,
            tamanoIcono: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saldo.BODEGA_NOMBRE ?? 'Bodega',
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                if (saldo.ubicacion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    saldo.ubicacion,
                    style: sora(12, 500, color: sg.tinta3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (etiqueta != null) ...[
                  const SizedBox(height: 7),
                  SgBadge(
                    etiqueta,
                    color: color,
                    icono: Icons.error_outline,
                    chico: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SgCifra(
            formato(saldo.CANTIDAD_DISPONIBLE),
            unidad: saldo.UNIDAD_SIMBOLO,
            tamano: 18,
            color: saldo.bajoMinimo ? color : sg.tinta,
          ),
        ],
      ),
    );
  }
}

/// Los lotes del repuesto, con el vencido primero.
class _Lotes extends ConsumerWidget {
  const _Lotes({required this.repuestoId, required this.fecha});

  final int repuestoId;
  final DateFormat fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final lotes = ref.watch(lotesProvider(repuestoId));

    return EstadoAsync<List<RepuestoLote>>(
      valor: lotes,
      alturaCarga: 100,
      onReintentar: () => ref.invalidate(lotesProvider(repuestoId)),
      estaVacio: (l) => l.isEmpty,
      vacio: const EstadoVacio(
        icono: Icons.inventory_outlined,
        titulo: 'Sin lotes cargados',
        detalle:
            'El repuesto controla lote, pero todavía no hay ninguno '
            'registrado.',
      ),
      child: (lista) {
        /* EL VENCIDO VA ARRIBA

           Es el que no se puede entregar, así que es el único que cambia lo
           que la persona va a hacer. Al final de una lista larga se lee
           después de haber decidido. */
        final ordenados = [...lista]
          ..sort((a, b) {
            if (a.vencido != b.vencido) return a.vencido ? -1 : 1;
            final fa = a.rlo_fecha_vencimiento;
            final fb = b.rlo_fecha_vencimiento;
            if (fa == null && fb == null) return 0;
            if (fa == null) return 1;
            if (fb == null) return -1;
            return fa.compareTo(fb);
          });

        return Column(
          children: [
            for (final l in ordenados) ...[
              SgCard(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    SgIconoCuadro(
                      l.vencido
                          ? Icons.event_busy_outlined
                          : Icons.event_available_outlined,
                      color: l.vencido ? sg.rojoTexto : sg.verdeTexto,
                      lado: 40,
                      tamanoIcono: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.rlo_codigo,
                            style: sora(15, 600, color: sg.tinta),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.rlo_fecha_vencimiento == null
                                ? 'Sin fecha de vencimiento'
                                : '${l.vencido ? "Venció" : "Vence"} el '
                                      '${fecha.format(l.rlo_fecha_vencimiento!.toLocal())}',
                            style: sora(
                              12,
                              500,
                              color: l.vencido ? sg.rojoTexto : sg.tinta3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (l.vencido)
                      SgBadge(
                        'Vencido',
                        color: sg.rojoTexto,
                        icono: Icons.block,
                        chico: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    );
  }
}
