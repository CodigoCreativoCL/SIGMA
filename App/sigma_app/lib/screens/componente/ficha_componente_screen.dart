import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_evidencia.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../galeria/galeria_screen.dart';
import '../medidor/historial_lecturas_screen.dart';

/// La ficha de un componente — vistas 8.2 y 8.3 del diseño v3.
///
/// ## Las dos pestañas
///
/// **Ficha** responde «qué es esta pieza»; **Historial**, «qué le ha pasado».
/// Son las dos preguntas que se hacen delante de un equipo detenido, y en ese
/// orden: primero se identifica la pieza, después se mira si ya falló antes.
///
/// Es la misma división que la ficha del activo, a propósito: dos pantallas
/// hermanas que se comportan distinto obligan a aprender dos veces.
class FichaComponenteScreen extends ConsumerStatefulWidget {
  const FichaComponenteScreen({super.key, required this.componenteId});

  final int componenteId;

  @override
  ConsumerState<FichaComponenteScreen> createState() =>
      _FichaComponenteScreenState();
}

class _FichaComponenteScreenState extends ConsumerState<FichaComponenteScreen> {
  int _pestana = 0;

  static final _fecha = DateFormat('dd-MM-yyyy', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final ficha = ref.watch(componenteProvider(widget.componenteId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        ficha.valueOrNull?.ACO_CODIGO ?? 'Componente',
        tamanoTitulo: 20,
      ),
      body: SafeArea(
        bottom: false,
        child: EstadoAsync<Componente>(
          valor: ficha,
          onReintentar: () =>
              ref.invalidate(componenteProvider(widget.componenteId)),
          child: (c) => Column(
            children: [
              _Pestanas(
                activa: _pestana,
                onCambio: (i) => setState(() => _pestana = i),
              ),
              Expanded(
                child: _pestana == 0
                    ? _Ficha(componente: c, formato: _fecha)
                    : _Historial(componenteId: widget.componenteId),
              ),
              const SgBarraGestos(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.activa, required this.onCambio});

  final int activa;
  final ValueChanged<int> onCambio;

  static const _titulos = ['Ficha', 'Historial'];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sg.card,
        border: Border(bottom: BorderSide(color: sg.div)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _titulos.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onCambio(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == activa ? sg.primario : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _titulos[i],
                    textAlign: TextAlign.center,
                    style: sora(
                      14,
                      i == activa ? 600 : 500,
                      color: i == activa ? sg.tinta : sg.tinta2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.componente, required this.formato});

  final Componente componente;
  final DateFormat formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final c = componente;
    final atencion = c.enObservacion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        SgCard(
          padding: const EdgeInsets.all(15),
          elegida: atencion,
          colorAnillo: atencion ? sg.ambarTexto : null,
          child: Row(
            children: [
              if ((c.FOTO_RUTA ?? '').isEmpty)
                SgIconoCuadro(
                  Icons.settings_outlined,
                  color: atencion ? sg.ambarTexto : sg.primarioTexto,
                  lado: 56,
                  tamanoIcono: 27,
                )
              else
                SigmaImagen(ruta: c.FOTO_RUTA, ancho: 56, alto: 56, radio: 16),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.ACO_NOMBRE, style: sora(17, 700, color: sg.tinta)),
                    const SizedBox(height: 4),
                    Text(c.ACO_CODIGO, style: sora(12, 500, color: sg.tinta3)),
                    if ((c.ESTADO_NOMBRE ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SgBadge(
                        c.ESTADO_NOMBRE!,
                        color: atencion ? sg.ambarTexto : sg.verdeTexto,
                        chico: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        /* EL EQUIPO PADRE, COMO CAMINO DE VUELTA

           Una pieza sin su equipo es un código suelto. Y en terreno se llega
           a la pieza por el escáner tanto como por el equipo, así que la ruta
           de vuelta tiene que estar acá aunque se haya entrado desde el
           listado del propio activo. */
        const SizedBox(height: 16),
        SgBloque(
          rotulo: 'Dónde va',
          filas: [
            SgFila(
              icono: Icons.precision_manufacturing_outlined,
              texto: 'Equipo',
              valor: c.ACTIVO_NOMBRE ?? c.ACTIVO_CODIGO ?? '—',
              colorTexto: sg.tinta2,
            ),
            if ((c.PADRE_NOMBRE ?? '').isNotEmpty)
              SgFila(
                icono: Icons.subdirectory_arrow_right,
                texto: 'Va dentro de',
                valor: c.PADRE_NOMBRE!,
                colorTexto: sg.tinta2,
              ),
            if ((c.POSICION_NOMBRE ?? '').isNotEmpty)
              SgFila(
                icono: Icons.my_location,
                texto: 'Posición',
                valor: c.POSICION_NOMBRE!,
                colorTexto: sg.tinta2,
              ),
          ],
        ),

        const SizedBox(height: 16),
        SgBloque(
          rotulo: 'Datos',
          filas: [
            if ((c.TIPO_NOMBRE ?? '').isNotEmpty)
              SgFila(
                icono: Icons.category_outlined,
                texto: 'Tipo',
                valor: c.TIPO_NOMBRE!,
                colorTexto: sg.tinta2,
              ),
            if ((c.CRITICIDAD_NOMBRE ?? '').isNotEmpty)
              SgFila(
                icono: Icons.priority_high,
                texto: 'Criticidad',
                // La criticidad es lo que pasa SI falla, no cómo está hoy:
                // por eso va en Datos y no junto al estado.
                valor: c.CRITICIDAD_NOMBRE!,
                colorTexto: sg.tinta2,
              ),
            if (c.ACO_FECHA_INSTALACION != null)
              SgFila(
                icono: Icons.event_available_outlined,
                texto: 'Instalado',
                valor: formato.format(c.ACO_FECHA_INSTALACION!),
                detalle: _antiguedad(c.ACO_FECHA_INSTALACION!),
                colorTexto: sg.tinta2,
              ),
          ],
        ),

        if (c.MEDIDORES.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SgRotulo('Horas y ciclos'),
          const SizedBox(height: 10),
          for (final m in c.MEDIDORES) ...[
            _TarjetaMedidor(medidor: m),
            const SizedBox(height: 10),
          ],
        ],

        if ((c.ACO_DESCRIPCION ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          const SgRotulo('Descripción'),
          const SizedBox(height: 10),
          SgCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              c.ACO_DESCRIPCION!.trim(),
              style: sora(13, 500, color: sg.tinta2, alto: 1.5),
            ),
          ),
        ],

        const SizedBox(height: 16),
        SgBoton(
          c.FOTOS.isEmpty
              ? 'Galería (sin fotos)'
              : 'Galería · ${c.FOTOS.length}',
          icono: Icons.photo_library_outlined,
          primario: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GaleriaScreen(
                titulo: c.ACO_NOMBRE,
                origen: OrigenGaleria.componente(c.ACO_ID),
              ),
            ),
          ),
        ),

        /* SUBIR, NO SOLO MIRAR

           La galeria de arriba deja VER las fotos de la pieza y no habia forma
           de agregar ninguna: `avi_activo_componente` existe desde BD/202, los
           dos SP la contemplan desde BD/206 y el controller ya conoce el
           destino COMPONENTE. Lo unico que faltaba era este widget.

           Con audio y video como el resto: el ruido de un rodamiento es
           justamente lo que distingue una pieza gastada de una sana. */
        const SizedBox(height: 16),
        SgEvidencias(
          destino: 'COMPONENTE',
          destinoId: c.ACO_ID,
          conAudio: true,
          conVideo: true,
        ),
      ],
    );
  }

  /// «Hace 3 años», que es lo que se quiere saber de una pieza instalada.
  ///
  /// La fecha sola obliga a restar mentalmente, y con guantes y a contraluz
  /// nadie resta.
  String _antiguedad(DateTime desde) {
    final dias = DateTime.now().difference(desde).inDays;
    if (dias < 0) return 'programado';
    if (dias < 31) return 'hace $dias ${dias == 1 ? 'día' : 'días'}';
    if (dias < 365) {
      final m = dias ~/ 30;
      return 'hace $m ${m == 1 ? 'mes' : 'meses'}';
    }
    final a = dias ~/ 365;
    return 'hace $a ${a == 1 ? 'año' : 'años'}';
  }
}

/// Un medidor del componente, que lleva a su historial (9.2).
class _TarjetaMedidor extends StatelessWidget {
  const _TarjetaMedidor({required this.medidor});

  final Medidor medidor;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final m = medidor;
    final valor = m.AME_VALOR_ACTUAL;

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HistorialLecturasScreen(medidorId: m.AME_ID),
        ),
      ),
      child: Row(
        children: [
          SgIconoCuadro(
            Icons.speed_outlined,
            color: sg.acentoTexto,
            lado: 44,
            tamanoIcono: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.AME_NOMBRE, style: sora(14, 600, color: sg.tinta)),
                const SizedBox(height: 3),
                Text(
                  'Ver el historial',
                  style: sora(11, 500, color: sg.tinta3),
                ),
              ],
            ),
          ),
          if (valor != null)
            Text(
              '${_sinCeros(valor)} ${m.UNIDAD_SIMBOLO ?? ''}'.trim(),
              // Tabular: un valor que sube de 999 a 1.000 no puede mover lo
              // que tiene al lado.
              style: sora(16, 700, color: sg.tinta, tabular: true),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: sg.tinta3),
        ],
      ),
    );
  }

  static String _sinCeros(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// La línea de tiempo — vista 8.3.
class _Historial extends ConsumerWidget {
  const _Historial({required this.componenteId});

  final int componenteId;

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  /// Cada clase de evento con su ícono. El color sale del tema, no de acá.
  static const _iconos = {
    'INSTALACION': Icons.event_available_outlined,
    'LECTURA': Icons.speed_outlined,
    'FALLA': Icons.warning_amber_rounded,
    'OT': Icons.assignment_outlined,
    'REPUESTO': Icons.settings_backup_restore,
    'SUSTITUCION': Icons.swap_horiz,
    'BITACORA': Icons.sticky_note_2_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final datos = ref.watch(fichaComponenteProvider(componenteId));

    return EstadoAsync<Paginado<ComponenteEvento>>(
      valor: datos,
      onReintentar: () => ref.invalidate(fichaComponenteProvider(componenteId)),
      child: (p) {
        if (p.datos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SgAviso(
                'Todavía no hay nada registrado sobre esta pieza.',
                icono: Icons.history,
                color: sg.tinta2,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          itemCount: p.datos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = p.datos[i];
            final tipo = (e.TIPO_EVENTO ?? '').toUpperCase();

            /* LA FALLA SE DESTACA, EL RESTO NO

               Una línea de tiempo donde todo grita no destaca nada. De las
               siete clases de evento, la falla es la única que cambia lo que
               alguien hace a continuación. */
            final esFalla = tipo == 'FALLA';

            return SgCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SgIconoCuadro(
                    _iconos[tipo] ?? Icons.circle_outlined,
                    color: esFalla ? sg.rojoTexto : sg.tinta2,
                    lado: 40,
                    tamanoIcono: 19,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.TITULO,
                          style: sora(
                            14,
                            600,
                            color: esFalla ? sg.rojoTexto : sg.tinta,
                          ),
                        ),
                        if ((e.DETALLE ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.DETALLE!.trim(),
                            style: sora(12, 500, color: sg.tinta2, alto: 1.4),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (e.FECHA != null)
                              _fecha.format(e.FECHA!.toLocal()),
                            if ((e.USUARIO_NOMBRE ?? '').isNotEmpty)
                              e.USUARIO_NOMBRE!,
                            if ((e.REF_TEXTO ?? '').isNotEmpty) e.REF_TEXTO!,
                          ].join(' · '),
                          style: sora(11, 500, color: sg.tinta3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
