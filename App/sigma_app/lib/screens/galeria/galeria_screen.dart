import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../ordenes/hojas_recursos.dart';

/// De qué es la galería que se está mirando.
///
/// ## Por qué no es un simple `int`
///
/// Porque el id 12 de un activo y el id 12 de un repuesto son cosas
/// distintas. Con un entero pelado, abrir uno después del otro mostraría por
/// un instante las fotos del anterior, que en una galería —donde lo único
/// que se ve son imágenes— es indistinguible de un error de datos.
enum TipoGaleria { activo, componente, repuesto }

class OrigenGaleria {
  const OrigenGaleria._(this.tipo, this.id);

  const OrigenGaleria.activo(int id) : this._(TipoGaleria.activo, id);
  const OrigenGaleria.componente(int id) : this._(TipoGaleria.componente, id);
  const OrigenGaleria.repuesto(int id) : this._(TipoGaleria.repuesto, id);

  final TipoGaleria tipo;
  final int id;
}

/// La galería — vistas 7.4 (activo), 8.4 (componente) y 10.4 (repuesto).
///
/// ## Una pantalla y no tres
///
/// Las tres especificaciones piden lo mismo con otras palabras: cuadrícula
/// cronológica, fecha, autor, observación y vista completa con zoom. Lo único
/// que cambia es de dónde salen las fotos. Tres pantallas casi iguales serían
/// tres sitios donde arreglar el mismo detalle, y en la práctica dos se
/// quedarían atrás.
///
/// ## Por qué agrupa por mes
///
/// «Cronológica» sin cortes es una cuadrícula donde no se distingue la foto
/// de ayer de la de hace dos años. El mes es el corte que sirve para la
/// pregunta real —cómo estaba esto antes de la última intervención— sin
/// llenar la pantalla de encabezados como haría el día.
///
/// ## Lo que todavía no hace
///
/// **No se toman fotos desde acá.** Capturar evidencia ya existe y vive donde
/// se captura: en la orden, en la tarea, en la bitácora, con su cola offline.
/// Un segundo camino que suba fotos sueltas sin decir a qué trabajo
/// pertenecen llenaría la galería de imágenes que nadie puede explicar.
class GaleriaScreen extends ConsumerWidget {
  const GaleriaScreen({super.key, required this.titulo, required this.origen});

  final String titulo;
  final OrigenGaleria origen;

  static final _mes = DateFormat('MMMM yyyy', 'es');
  static final _dia = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final datos = ref.watch(_provider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(titulo, tamanoTitulo: 19),
      body: SafeArea(
        bottom: false,
        child: EstadoAsync<List<GaleriaFoto>>(
          valor: datos,
          onReintentar: () => ref.invalidate(_provider),
          child: (fotos) {
            if (fotos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SgAviso(
                    'Todavía no hay fotos. Se suben desde la web, o quedan '
                    'al registrar una evidencia en terreno.',
                    icono: Icons.photo_library_outlined,
                    color: sg.tinta2,
                  ),
                ),
              );
            }

            final grupos = _porMes(fotos);

            return ListView(
              padding: context.conBarraSistema(
                const EdgeInsets.fromLTRB(16, 14, 16, 16),
              ),
              children: [
                for (final g in grupos) ...[
                  SgRotulo(g.rotulo),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: g.fotos.length,
                    itemBuilder: (_, i) => _Miniatura(
                      foto: g.fotos[i],
                      onTap: () => _abrirFicha(context, g.fotos[i]),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const SgBarraGestos(),
              ],
            );
          },
        ),
      ),
    );
  }

  ProviderBase<AsyncValue<List<GaleriaFoto>>> get _provider =>
      switch (origen.tipo) {
        TipoGaleria.activo => galeriaActivoProvider(origen.id),
        TipoGaleria.componente => galeriaComponenteProvider(origen.id),
        TipoGaleria.repuesto => galeriaRepuestoProvider(origen.id),
      };

  /// La ficha de una foto: quién, cuándo y qué dijo.
  ///
  /// Va como hoja y no como pantalla porque se mira un segundo y se cierra:
  /// llevar a otra pantalla obligaría a volver, y con una galería abierta eso
  /// significa perder el sitio donde se estaba mirando.
  Future<void> _abrirFicha(BuildContext context, GaleriaFoto f) {
    final sg = context.sg;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HojaRecurso(
        titulo: f.ARC_NOMBRE ?? 'Foto',
        detalle: f.ES_PORTADA ? 'Portada' : 'Foto de la galería',
        children: [
          SigmaImagen(ruta: f.ARC_RUTA, alto: 220, radio: SgRadius.card),
          const SizedBox(height: 14),
          SgBloque(
            filas: [
              if (f.FECHA_CAPTURA_UTC != null)
                SgFila(
                  icono: Icons.schedule,
                  texto: 'Tomada',
                  valor: _dia.format(f.FECHA_CAPTURA_UTC!.toLocal()),
                  colorTexto: sg.tinta2,
                ),
              if ((f.AUTOR_NOMBRE ?? '').isNotEmpty)
                SgFila(
                  icono: Icons.person_outline,
                  texto: 'Quién',
                  valor: f.AUTOR_NOMBRE!,
                  colorTexto: sg.tinta2,
                ),
              if (f.ES_PORTADA)
                SgFila(
                  icono: Icons.star_outline,
                  texto: 'Es la portada',
                  colorTexto: sg.tinta2,
                ),
            ],
          ),
          if ((f.DESCRIPCION ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SgCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                f.DESCRIPCION!.trim(),
                style: sora(13, 500, color: sg.tinta2, alto: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Las fotos agrupadas por mes, de la más reciente a la más vieja.
  ///
  /// Las que no traen fecha van al final en su propio grupo, y **no** se
  /// mezclan con las del mes actual: una foto sin fecha no es una foto de
  /// hoy, y ponerla ahí sería inventarle una.
  List<_Grupo> _porMes(List<GaleriaFoto> fotos) {
    final conFecha = fotos.where((f) => f.FECHA_CAPTURA_UTC != null).toList()
      ..sort((a, b) => b.FECHA_CAPTURA_UTC!.compareTo(a.FECHA_CAPTURA_UTC!));
    final sinFecha = fotos.where((f) => f.FECHA_CAPTURA_UTC == null).toList();

    final grupos = <_Grupo>[];
    String? actual;

    for (final f in conFecha) {
      final r = _mes.format(f.FECHA_CAPTURA_UTC!.toLocal());
      if (r != actual) {
        grupos.add(_Grupo(r, []));
        actual = r;
      }
      grupos.last.fotos.add(f);
    }

    if (sinFecha.isNotEmpty) grupos.add(_Grupo('Sin fecha', sinFecha));

    return grupos;
  }
}

class _Grupo {
  _Grupo(this.rotulo, this.fotos);

  final String rotulo;
  final List<GaleriaFoto> fotos;
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.foto, required this.onTap});

  final GaleriaFoto foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SgRadius.card),
            // `ampliable: false` a propósito: el toque abre la ficha, que es
            // lo que distingue una galería de un montón de fotos. Desde ahí
            // se amplía, con el dato al lado.
            child: SigmaImagen(
              ruta: foto.ARC_RUTA,
              ajuste: BoxFit.cover,
              ampliable: false,
              radio: SgRadius.card,
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(SgRadius.card),
            ),
          ),
        ),
        if (foto.ES_PORTADA)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: sg.scrim,
                borderRadius: BorderRadius.circular(SgRadius.pill),
              ),
              child: const Icon(Icons.star, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
