import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

/// La ficha de una bodega y sus estantes — vistas 10.6, 10.7 y 10.8 del v3.
///
/// ## Por qué las tres vistas en una pantalla
///
/// El diseño las separa —ficha de bodega, listado de ubicaciones, ficha de
/// ubicación— y en un escritorio eso tiene sentido. En el teléfono son tres
/// toques para responder una sola pregunta: «¿qué hay en este estante?».
///
/// Acá la bodega abre con sus estantes debajo, y tocar un estante despliega lo
/// que tiene dentro sin cambiar de pantalla. Se lee de arriba abajo como se
/// camina un pasillo, que es lo que está haciendo quien la abre.
///
/// ## De dónde sale el contenido de un estante
///
/// De `GET /escaneo?c=UBI-<id>`, el mismo desglose que devuelve leer su
/// etiqueta con la cámara. **Es a propósito:** escanear el estante y tocarlo en
/// la lista tienen que dar exactamente lo mismo, y con dos consultas distintas
/// terminarían discrepando el día que una cambie.
class FichaBodegaScreen extends ConsumerWidget {
  const FichaBodegaScreen({
    super.key,
    required this.bodegaId,
    this.nombreConocido,
  });

  final int bodegaId;

  /// El nombre que ya traía la fila desde donde se abrió. Se pinta en la barra
  /// mientras baja la ficha: un título vacío durante un segundo hace dudar de
  /// si se abrió lo que se tocó.
  final String? nombreConocido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final bodega = ref.watch(bodegaProvider(bodegaId));
    final estantes = ref.watch(ubicacionesBodegaProvider(bodegaId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        bodega.valueOrNull?.bod_nombre ?? nombreConocido ?? 'Bodega',
        tamanoTitulo: 20,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bodegaProvider(bodegaId));
            ref.invalidate(ubicacionesBodegaProvider(bodegaId));
          },
          child: ListView(
            padding: context.conBarraSistema(
              const EdgeInsets.fromLTRB(16, 12, 16, 16),
            ),
            children: [
              EstadoAsync<Bodega>(
                valor: bodega,
                onReintentar: () => ref.invalidate(bodegaProvider(bodegaId)),
                alturaCarga: 110,
                child: (b) => _Cabecera(bodega: b),
              ),

              const SizedBox(height: 18),
              const SgRotulo('Estantes'),
              const SizedBox(height: 10),

              EstadoAsync<List<BodegaUbicacion>>(
                valor: estantes,
                onReintentar: () =>
                    ref.invalidate(ubicacionesBodegaProvider(bodegaId)),
                alturaCarga: 140,
                child: (lista) {
                  if (lista.isEmpty) {
                    return SgAviso(
                      'Esta bodega no tiene estantes: lo que entra y sale no '
                      'necesita decir de cuál.',
                      icono: Icons.shelves,
                      color: sg.tinta2,
                    );
                  }

                  return Column(
                    children: [
                      for (final u in lista) ...[
                        _Estante(ubicacion: u),
                        const SizedBox(height: 9),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.bodega});

  final Bodega bodega;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          SgIconoCuadro(
            Icons.warehouse_outlined,
            color: sg.primarioTexto,
            lado: 48,
            tamanoIcono: 24,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bodega.bod_nombre, style: sora(17, 600, color: sg.tinta)),
                const SizedBox(height: 4),
                Text(
                  [
                    bodega.bod_codigo,
                    bodega.PLANTA_NOMBRE ?? '',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(13, 500, color: sg.tinta3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un estante, y lo que tiene dentro cuando se toca.
///
/// El contenido se pide **solo al desplegarlo**: una bodega con cuarenta
/// posiciones haría cuarenta consultas al abrir la pantalla, y quien la abre
/// va a mirar una.
class _Estante extends ConsumerStatefulWidget {
  const _Estante({required this.ubicacion});

  final BodegaUbicacion ubicacion;

  @override
  ConsumerState<_Estante> createState() => _EstanteState();
}

class _EstanteState extends ConsumerState<_Estante> {
  bool _abierto = false;

  static final _n = NumberFormat.decimalPattern('es_CL');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => setState(() => _abierto = !_abierto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 19, color: sg.tinta2),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.ubicacion.etiqueta,
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _abierto ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: sg.tinta3,
              ),
            ],
          ),
          if (_abierto) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: sg.div),
            const SizedBox(height: 12),
            _Contenido(ubicacionId: widget.ubicacion.bub_id, formato: _n),
          ],
        ],
      ),
    );
  }
}

/// Lo que hay dentro de un estante — vista 10.8.
class _Contenido extends ConsumerWidget {
  const _Contenido({required this.ubicacionId, required this.formato});

  final int ubicacionId;
  final NumberFormat formato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;

    // El MISMO desglose que devuelve escanear su etiqueta.
    final desglose = ref.watch(escaneoProvider('UBI-$ubicacionId'));

    return EstadoAsync<Escaneo>(
      valor: desglose,
      alturaCarga: 90,
      onReintentar: () => ref.invalidate(escaneoProvider('UBI-$ubicacionId')),
      child: (e) {
        if (e.lineas.isEmpty) {
          return Text(
            'El estante está vacío.',
            style: sora(13, 500, color: sg.tinta3),
          );
        }

        /* LAS LINEAS NO NAVEGAN, Y ES A PROPOSITO

           El desglose devuelve el CODIGO del repuesto, no su id, y la ficha se
           abre por id. Resolverlo aca seria adivinar, y abrir la ficha
           equivocada es peor que no abrir ninguna: quien busca una pieza en un
           estante y termina en otra descuenta de la que no era. */
        return Column(
          children: [
            for (final l in e.lineas)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.rep_nombre,
                            style: sora(14, 600, color: sg.tinta),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.rep_codigo,
                            style: sora(12, 500, color: sg.tinta3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SgCifra(formato.format(l.CANTIDAD), tamano: 16),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
