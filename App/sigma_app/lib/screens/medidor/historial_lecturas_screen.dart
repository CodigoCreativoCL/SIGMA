import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

/// El historial de lecturas de un medidor — vista 9.2 del diseño v3.
///
/// ## Qué se grafica, y por qué no lo obvio
///
/// El medidor guarda el **acumulado**: 7.500 h. Graficarlo da una recta que
/// sube y no dice nada, porque siempre sube. Lo que responde la pregunta real
/// —«¿esta máquina está trabajando más de lo normal?»— es el **incremento**
/// entre lecturas: «580 h este mes contra 90 el anterior» dice que estuvo
/// parada, y «1.480» dice que alguien le metió turnos extra.
///
/// El incremento **lo calcula el SP**, no esta pantalla. Si lo restara acá, la
/// primera fila de cada página saldría mal —no tiene contra qué restarse— y
/// la web tendría que repetir la misma cuenta.
///
/// ## Los umbrales
///
/// No salen de una tabla de umbrales, que no existe, sino de la programación
/// de mantención: «cada 500 h desde 0» con el medidor en 7.500 pone el
/// próximo hito en 8.000. Es el umbral real del negocio.
///
/// Lo normal es que un medidor **no tenga ninguna** programación, y entonces
/// la pantalla no dibuja líneas inventadas: dice que no hay ninguna
/// configurada, que es distinto de decir que todo va bien.
class HistorialLecturasScreen extends ConsumerWidget {
  const HistorialLecturasScreen({super.key, required this.medidorId});

  final int medidorId;

  static final _fecha = DateFormat('dd-MM-yyyy', 'es');
  static final _mes = DateFormat('MMM', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final medidor = ref.watch(medidorProvider(medidorId));
    final lecturas = ref.watch(lecturasProvider(medidorId));
    final rango = ref.watch(rangoLecturasProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        medidor.valueOrNull?.AME_NOMBRE ?? 'Lecturas',
        tamanoTitulo: 19,
      ),
      body: SafeArea(
        bottom: false,
        child: EstadoAsync<Medidor>(
          valor: medidor,
          onReintentar: () => ref.invalidate(medidorProvider(medidorId)),
          child: (m) => ListView(
            padding: context.conBarraSistema(
              const EdgeInsets.fromLTRB(16, 14, 16, 16),
            ),
            children: [
              _Cabecera(medidor: m),

              const SizedBox(height: 16),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final r in RangoLecturas.values) ...[
                      SgChip(
                        r.rotulo,
                        elegido: rango == r,
                        onTap: () =>
                            ref.read(rangoLecturasProvider.notifier).state = r,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),
              EstadoAsync<List<Lectura>>(
                valor: lecturas,
                onReintentar: () => ref.invalidate(lecturasProvider(medidorId)),
                child: (l) => _Cuerpo(
                  medidor: m,
                  lecturas: l,
                  formatoFecha: _fecha,
                  formatoMes: _mes,
                ),
              ),
              const SgBarraGestos(),
            ],
          ),
        ),
      ),
    );
  }
}

/// El valor de hoy y, si la hay, cuánto falta para la próxima mantención.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.medidor});

  final Medidor medidor;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final m = medidor;
    final umbral = m.UMBRALES.isEmpty ? null : m.UMBRALES.first;

    /* EL COLOR LO DECIDE EL UMBRAL, NO EL VALOR

       Siete mil horas no son ni muchas ni pocas: dependen de cada cuánto toca
       la mantención de ESE equipo. Sin programación configurada no hay contra
       qué comparar, y entonces la cifra va en tinta normal en vez de
       inventarle un color que sugiera un juicio que nadie hizo. */
    final avisando = umbral?.avisando ?? false;

    return SgCard(
      padding: const EdgeInsets.all(16),
      elegida: avisando,
      colorAnillo: avisando ? sg.ambarTexto : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _n(m.AME_VALOR_ACTUAL),
                style: sora(
                  34,
                  700,
                  color: avisando ? sg.ambarTexto : sg.tinta,
                  tabular: true,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  m.UNIDAD_SIMBOLO ?? m.UNIDAD_NOMBRE ?? '',
                  style: sora(15, 600, color: sg.tinta3),
                ),
              ),
              const Spacer(),
              SgIconoCuadro(
                Icons.speed_outlined,
                color: avisando ? sg.ambarTexto : sg.acentoTexto,
                lado: 44,
                tamanoIcono: 21,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              m.ACTIVO_NOMBRE ?? '',
              m.AME_CODIGO,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: sora(12, 500, color: sg.tinta3),
          ),
          if (umbral != null && umbral.PROXIMO_UMBRAL != null) ...[
            const SizedBox(height: 14),
            Divider(color: sg.div, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  avisando ? Icons.warning_amber_rounded : Icons.flag_outlined,
                  size: 17,
                  color: avisando ? sg.ambarTexto : sg.tinta2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _frase(umbral, m.UNIDAD_SIMBOLO ?? ''),
                    style: sora(
                      12,
                      600,
                      color: avisando ? sg.ambarTexto : sg.tinta2,
                      alto: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// «Faltan 500 h para la mantención de las 8.000», o que ya se pasó.
  ///
  /// Se dice en palabras y no con dos cifras sueltas: quien mira esto está de
  /// pie frente a la máquina, no sentado interpretando una tabla.
  String _frase(MedidorUmbral u, String unidad) {
    final falta = u.FALTA;
    final proximo = _n(u.PROXIMO_UMBRAL);
    final nombre = (u.PROGRAMACION_NOMBRE ?? '').trim();
    final de = nombre.isEmpty ? 'la mantención' : nombre;

    if (falta == null) return '$de toca a las $proximo $unidad';
    if (falta < 0) {
      return '$de se pasó por ${_n(-falta)} $unidad '
          '(tocaba a las $proximo)';
    }
    return 'Faltan ${_n(falta)} $unidad para $de, a las $proximo';
  }

  static String _n(double? v) {
    if (v == null) return '—';
    final r = v.abs() < 1000
        ? (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1))
        : v.round().toString();
    // Separador de miles a la chilena: 7.500, no 7,500.
    if (r.length <= 3 || r.contains('.')) return r;
    final buf = StringBuffer();
    for (var i = 0; i < r.length; i++) {
      if (i > 0 && (r.length - i) % 3 == 0) buf.write('.');
      buf.write(r[i]);
    }
    return buf.toString();
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.medidor,
    required this.lecturas,
    required this.formatoFecha,
    required this.formatoMes,
  });

  final Medidor medidor;
  final List<Lectura> lecturas;
  final DateFormat formatoFecha;
  final DateFormat formatoMes;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    if (lecturas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SgAviso(
          'No hay lecturas en este tramo. Prueba con un rango más largo.',
          icono: Icons.show_chart,
          color: sg.tinta2,
        ),
      );
    }

    /* CON UNA SOLA LECTURA NO HAY GRAFICO

       Un incremento necesita dos puntos. Con uno, la barra unica que se
       podria dibujar se leeria como una tendencia cuando no hay ninguna. */
    final conIncremento = lecturas.where((l) => l.INCREMENTO != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conIncremento.length >= 2) ...[
          const SgRotulo('Cuánto corrió entre lecturas'),
          const SizedBox(height: 10),
          SgCard(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
            child: _Grafico(
              lecturas: conIncremento,
              unidad: medidor.UNIDAD_SIMBOLO ?? '',
              formatoMes: formatoMes,
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SgRotulo('Las lecturas'),
        const SizedBox(height: 10),
        // Al revés que el gráfico: la tabla se lee de lo más nuevo a lo más
        // viejo, porque lo que se busca en ella es la última.
        for (final l in lecturas.reversed) ...[
          _Fila(lectura: l, medidor: medidor, formato: formatoFecha),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

/// Las barras de incremento.
///
/// Se dibuja a mano y no con una librería de gráficos: son barras, un eje y
/// una línea de promedio. Traer un paquete entero —con su tema propio, sus
/// colores fijos y sus animaciones— para esto sería pegarle un cuerpo extraño
/// a una app que saca todos sus colores de `context.sg`.
class _Grafico extends StatelessWidget {
  const _Grafico({
    required this.lecturas,
    required this.unidad,
    required this.formatoMes,
  });

  final List<Lectura> lecturas;
  final String unidad;
  final DateFormat formatoMes;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final valores = lecturas.map((l) => l.INCREMENTO!).toList();
    final maximo = valores.reduce(math.max);
    final promedio = valores.reduce((a, b) => a + b) / valores.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 132,
          child: LayoutBuilder(
            builder: (_, cajas) {
              final ancho = cajas.maxWidth;
              // Como mucho 14 barras: más allá, cada una queda de dos píxeles
              // y el gráfico deja de leerse. Se muestran las últimas.
              final visibles = lecturas.length > 14
                  ? lecturas.sublist(lecturas.length - 14)
                  : lecturas;
              final espacio = ancho / visibles.length;

              return Stack(
                children: [
                  // La línea del promedio: es contra ella que una barra alta
                  // significa algo.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22 + (110 * (promedio / maximo)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: sg.div),
                      child: const SizedBox(height: 1),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final l in visibles)
                        SizedBox(
                          width: espacio,
                          child: _Barra(
                            alto: 110 * (l.INCREMENTO! / maximo),
                            // Sobre el doble del promedio es el «salto no
                            // razonable» de 9.1: se destaca acá porque es lo
                            // único de este gráfico que pide mirar dos veces.
                            destacada: l.INCREMENTO! > promedio * 2,
                            rotulo: l.FECHA_LECTURA_UTC == null
                                ? ''
                                : formatoMes.format(
                                    l.FECHA_LECTURA_UTC!.toLocal(),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Promedio ${promedio.round()} $unidad · '
          'máximo ${maximo.round()} $unidad',
          textAlign: TextAlign.center,
          style: sora(11, 500, color: sg.tinta3),
        ),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.alto,
    required this.destacada,
    required this.rotulo,
  });

  final double alto;
  final bool destacada;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: math.max(alto, 2),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: destacada ? sg.ambarTexto : sg.primario,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rotulo,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: sora(9, 500, color: sg.tinta3),
        ),
      ],
    );
  }
}

/// Una lectura de la tabla, con quién, cuándo y cómo se ingresó.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.lectura,
    required this.medidor,
    required this.formato,
  });

  final Lectura lectura;
  final Medidor medidor;
  final DateFormat formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final l = lectura;
    final u = medidor.UNIDAD_SIMBOLO ?? '';

    return SgCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_n(l.VALOR_ACUMULADO)} $u',
                      style: sora(15, 600, color: sg.tinta, tabular: true),
                    ),
                    if (l.ES_REINICIO) ...[
                      const SizedBox(width: 8),
                      SgBadge('Reinicio', color: sg.azulTexto, chico: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (l.FECHA_LECTURA_UTC != null)
                      formato.format(l.FECHA_LECTURA_UTC!.toLocal()),
                    if ((l.USUARIO_NOMBRE ?? '').isNotEmpty) l.USUARIO_NOMBRE!,
                    if ((l.MODO_NOMBRE ?? '').isNotEmpty) l.MODO_NOMBRE!,
                  ].join(' · '),
                  style: sora(11, 500, color: sg.tinta3),
                ),
                if ((l.OBSERVACION ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.OBSERVACION!.trim(),
                    style: sora(12, 500, color: sg.tinta2, alto: 1.4),
                  ),
                ],
                if ((l.ORDEN_CORRELATIVO ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 13,
                        color: sg.primarioTexto,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l.ORDEN_CORRELATIVO!,
                        style: sora(11, 600, color: sg.primarioTexto),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // El incremento a la derecha, que es lo que se compara al bajar la
          // lista. Un guion cuando no se sabe: en la primera lectura y en un
          // reinicio no hay contra qué restar, y un cero diría «no corrió».
          Text(
            l.INCREMENTO == null ? '—' : '+${_n(l.INCREMENTO!)}',
            style: sora(
              14,
              700,
              color: l.INCREMENTO == null ? sg.tinta3 : sg.acentoTexto,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
