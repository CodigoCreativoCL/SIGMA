import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../../providers/sincronizacion_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Sincronización inicial — HU-150.
///
/// Es lo primero que se corre después de elegir dónde se trabaja, y tiene que
/// dar la sensación de que el trabajo se está preparando, no de que la app se
/// colgó. Por eso el progreso es **real y por bloque**: cada barra avanza
/// porque un endpoint respondió, y el contador dice cuántas filas bajaron.
///
/// ## Por qué se puede salir a mitad de camino
///
/// El botón del pie no cancela nada: la descarga sigue en el notifier, que
/// vive en el contenedor de Riverpod y no en esta pantalla. Obligar a mirar
/// una barra durante cuatro minutos con señal de bodega no protege ningún
/// dato — los tres primeros bloques ya alcanzan para dibujar el inicio.
class SincronizacionScreen extends ConsumerStatefulWidget {
  const SincronizacionScreen({super.key});

  @override
  ConsumerState<SincronizacionScreen> createState() =>
      _SincronizacionScreenState();
}

class _SincronizacionScreenState extends ConsumerState<SincronizacionScreen> {
  @override
  void initState() {
    super.initState();
    // Después del primer frame: la pantalla se dibuja y **después** arranca la
    // red. Un await antes de pintar deja al técnico mirando una pantalla en
    // blanco hasta que expire el timeout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(sincronizacionProvider).corriendo) {
        ref.read(sincronizacionProvider.notifier).sincronizar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final e = ref.watch(sincronizacionProvider);
    final sesion = ref.watch(sesionProvider);
    final instalacion = ref.watch(instalacionProvider);

    final contexto = [
      if (sesion.clienteNombre.isNotEmpty) sesion.clienteNombre,
      if (instalacion != null) instalacion.cin_nombre,
    ].join(' · ');

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Sincronización'),
      bottomNavigationBar: SgPie(
        child: SgBoton(
          e.termino ? 'Continuar' : 'Continuar en segundo plano',
          primario: e.termino,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 8)),
        children: [
          _Cabecera(termino: e.termino, fallidos: e.fallidos),
          const SizedBox(height: 20),
          _Avance(estado: e, contexto: contexto),
          const SizedBox(height: 20),
          if (e.bloques.isNotEmpty) ...[
            SgBloque(
              filas: [
                for (final b in e.bloques) _FilaBloque(bloque: b),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Text(
            e.fallidos > 0
                ? 'Los bloques que fallaron se vuelven a pedir la próxima vez. '
                    'Lo que sí bajó ya se puede usar sin señal.'
                : 'La primera carga puede tardar unos minutos con señal débil. '
                    'Después solo se descargan los cambios.',
            style: sora(13, 500,
                color: e.fallidos > 0 ? sg.ambarTexto : sg.tinta3, alto: 1.55),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.termino, required this.fallidos});

  final bool termino;
  final int fallidos;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final color = fallidos > 0
        ? sg.ambarTexto
        : termino
            ? sg.verdeTexto
            : sg.acentoTexto;

    return Row(
      children: [
        SgIconoCuadro(
          termino
              ? (fallidos > 0 ? Icons.sync_problem : Icons.cloud_done_outlined)
              : Icons.sync,
          color: color,
          lado: 56,
          radio: 18,
          tamanoIcono: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(termino ? 'Tus datos están listos' : 'Preparando tus datos',
                  style: sora(22, 700, color: sg.tinta, espaciado: -0.44)),
              const SizedBox(height: 4),
              Text(
                termino
                    ? (fallidos > 0
                        ? '$fallidos ${fallidos == 1 ? "bloque quedó pendiente" : "bloques quedaron pendientes"}.'
                        : 'Ya puedes trabajar sin señal.')
                    : 'Podrás trabajar sin señal al terminar.',
                style: sora(14, 500, color: sg.tinta2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La tarjeta del porcentaje.
///
/// El número es **tabular**: sin eso, al pasar de 46 a 47 cambia el ancho del
/// dígito y el bloque entero salta de posición cada décima de segundo.
class _Avance extends StatelessWidget {
  const _Avance({required this.estado, required this.contexto});

  final SincronizacionEstado estado;
  final String contexto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final n = estado.bloques.length;

    return SgCard(
      elevada: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${estado.porcentaje}',
                  style: sora(44, 700,
                      color: sg.tinta,
                      alto: 1,
                      espaciado: -1.32,
                      tabular: true)),
              const SizedBox(width: 6),
              Text('%', style: sora(20, 600, color: sg.tinta3)),
              const Spacer(),
              Text(
                n == 0
                    ? 'Consultando el paquete…'
                    : '${estado.listos} de $n bloques',
                style: sora(14, 500, color: sg.tinta2),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(SgRadius.pill),
            child: Stack(
              children: [
                Container(height: 8, color: sg.up),
                if (n > 0)
                  FractionallySizedBox(
                    widthFactor: estado.avance.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration:
                          const BoxDecoration(gradient: SgColor.gradiente),
                    ),
                  )
                else
                  const SizedBox(
                      height: 8, child: LinearProgressIndicator(minHeight: 8)),
              ],
            ),
          ),
          if (contexto.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(contexto,
                style: sora(13, 500, color: sg.tinta3),
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _FilaBloque extends StatelessWidget {
  const _FilaBloque({required this.bloque});

  final Bloque bloque;

  /// 3180 → 3.180. El punto es el separador de miles en Chile.
  static String _mil(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    // El bloque en curso se hunde en `up` y muestra su propia barra de filas.
    if (bloque.estado == EstadoBloque.enCurso) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: sg.up,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.sync, size: 21, color: sg.acentoTexto),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(bloque.nombre,
                      style: sora(16, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(
                  bloque.total > 0
                      ? '${_mil(bloque.filas)} / ${_mil(bloque.total)}'
                      : 'Descargando…',
                  style: sora(13, 600, color: sg.acentoTexto, tabular: true),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(left: 33),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SgRadius.pill),
                child: LinearProgressIndicator(
                  value: bloque.total > 0 ? bloque.avance : null,
                  minHeight: 4,
                  backgroundColor: sg.fondo,
                  valueColor:
                      const AlwaysStoppedAnimation(SgColor.tealSolido),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final (IconData icono, Color color, String detalle, double opacidad) =
        switch (bloque.estado) {
      EstadoBloque.listo => (
          Icons.check_circle,
          sg.verdeTexto,
          bloque.filas > 0 ? _mil(bloque.filas) : 'Listo',
          1.0
        ),
      EstadoBloque.fallido => (
          Icons.error_outline,
          sg.rojoTexto,
          'No bajó',
          1.0
        ),
      _ => (Icons.donut_large, sg.tinta3, 'En espera', 0.45),
    };

    return Opacity(
      opacity: opacidad,
      child: SgFila(
        icono: icono,
        colorIcono: color,
        texto: bloque.nombre,
        // El motivo del servidor se conserva: un 403 dice qué permiso falta, y
        // eso se puede pedir. «Error de sincronización» no se puede pedir.
        detalle: bloque.error,
        valor: detalle,
      ),
    );
  }
}
