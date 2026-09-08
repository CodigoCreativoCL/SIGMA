import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Existencias de bodega — HU-067 y siguientes.
///
/// Layout v3: título 23/700; buscador de 52 en píldora con micrófono; chips de
/// 28 con contador; tarjetas de 22 con la cifra tabular y **la unidad en la
/// píldora `.u`**, que es lo que impide leer «12 UN» como si fuera un número
/// de cuatro cifras.
///
/// ## El semáforo no lo decide la pantalla
///
/// `BAJO_MINIMO` y `SOBRE_MAXIMO` los calcula el SP contra el stock mínimo y
/// máximo de cada repuesto **en esa bodega**. La app no recalcula el umbral:
/// si lo hiciera, dos pantallas podrían discrepar sobre si un repuesto está en
/// alerta, y el bodeguero terminaría creyéndole a la que le conviene.
class ExistenciasScreen extends ConsumerStatefulWidget {
  const ExistenciasScreen({super.key});

  @override
  ConsumerState<ExistenciasScreen> createState() => _ExistenciasScreenState();
}

class _ExistenciasScreenState extends ConsumerState<ExistenciasScreen> {
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final datos = ref.watch(existenciasProvider);
    final soloAlerta = ref.watch(filtroExistenciasProvider);
    final total = ref.watch(existenciasTotalProvider).valueOrNull;
    final enAlerta = ref.watch(existenciasEnAlertaProvider).valueOrNull;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Existencias', tamanoTitulo: 23),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              children: [
                _Buscador(
                  controlador: _buscar,
                  onCambio: (v) => ref
                      .read(busquedaExistenciasProvider.notifier)
                      .state = v,
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    SgChip('Todas',
                        elegido: !soloAlerta,
                        contador: total,
                        colorContador: sg.tinta3,
                        onTap: () => ref
                            .read(filtroExistenciasProvider.notifier)
                            .state = false),
                    const SizedBox(width: 8),
                    SgChip('Bajo mínimo',
                        elegido: soloAlerta,
                        contador: enAlerta,
                        colorContador: SgColor.rojo,
                        onTap: () => ref
                            .read(filtroExistenciasProvider.notifier)
                            .state = true),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: EstadoAsync<Paginado<InventarioSaldo>>(
              valor: datos,
              onReintentar: () => ref.invalidate(existenciasProvider),
              estaVacio: (p) => p.vacio,
              vacio: EstadoVacio(
                icono: soloAlerta
                    ? Icons.check_circle_outline
                    : Icons.inventory_2_outlined,
                titulo: soloAlerta
                    ? 'Nada bajo mínimo'
                    : 'Sin existencias registradas',
                detalle: soloAlerta
                    ? 'Todos los repuestos de esta instalación están sobre su '
                        'stock mínimo.'
                    : 'Las existencias se cargan desde la web al recibir un '
                        'repuesto en bodega.',
              ),
              child: (p) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(existenciasProvider);
                  ref.invalidate(existenciasTotalProvider);
                  ref.invalidate(existenciasEnAlertaProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: p.datos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (_, i) => _Tarjeta(saldo: p.datos[i]),
                ),
              ),
            ),
          ),
          const SgBarraGestos(),
        ],
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controlador, required this.onCambio});

  final TextEditingController controlador;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SgRadius.pill),
        boxShadow: sg.e1,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 18, right: 8),
        decoration: BoxDecoration(
          color: sg.campo,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 21, color: sg.tinta3),
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                controller: controlador,
                onChanged: onCambio,
                style: sora(16, 500, color: sg.tinta),
                cursorColor: sg.primario,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Repuesto, código o bodega',
                  hintStyle: sora(16, 500, color: sg.tinta3),
                ),
              ),
            ),
            SgBotonIcono(Icons.mic_none,
                color: sg.primarioTexto,
                tamano: 20,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('El dictado por voz llega más adelante.')),
                    )),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.saldo});

  final InventarioSaldo saldo;

  static final _n = NumberFormat.decimalPattern('es_CL');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final (Color color, String? etiqueta) = saldo.bajoMinimo
        ? (sg.rojoTexto, 'Bajo mínimo')
        : saldo.sobreMaximo
            ? (sg.ambarTexto, 'Sobre máximo')
            : (sg.verdeTexto, null);

    return SgCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SgIconoCuadro(Icons.inventory_2_outlined,
              color: color, lado: 44, tamanoIcono: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saldo.REPUESTO_NOMBRE,
                    style: sora(16, 600, color: sg.tinta, alto: 1.35),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(saldo.REPUESTO_CODIGO,
                        style: sora(12, 600, color: sg.acentoTexto)),
                    if (saldo.ubicacion.isNotEmpty) ...[
                      Text(' · ', style: sora(12, 500, color: sg.tinta3)),
                      Expanded(
                        child: Text(saldo.ubicacion,
                            style: sora(12, 500, color: sg.tinta3),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                if (etiqueta != null) ...[
                  const SizedBox(height: 8),
                  SgBadge(etiqueta,
                      color: color,
                      icono: Icons.error_outline,
                      chico: true,
                      unidad: saldo.rbs_stock_minimo == null
                          ? null
                          : 'min ${_n.format(saldo.rbs_stock_minimo)}'),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // La cifra tabular con la unidad en su propia píldora: «12» y «UN»
          // no se comparan igual, y juntarlas hace que el ojo lea un número
          // más largo del que hay.
          SgCifra(
            _n.format(saldo.CANTIDAD_DISPONIBLE),
            unidad: saldo.UNIDAD_SIMBOLO,
            tamano: 20,
            color: saldo.bajoMinimo ? color : sg.tinta,
          ),
        ],
      ),
    );
  }
}
