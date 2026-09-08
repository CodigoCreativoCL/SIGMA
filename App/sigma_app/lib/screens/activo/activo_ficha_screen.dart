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
import '../lectura/captura_screen.dart';

/// Ficha de activo — HU-037.
///
/// Layout v3: **hero fotográfico de 274** con dos velos —uno arriba para que
/// se lean los botones, otro abajo para que se lea el título—, chips de estado
/// sobre la foto, tira de miniaturas de 52, pestañas, rejilla de tres cifras,
/// bloque de datos y pie con «Registrar lectura».
///
/// ## Las fotos vienen del Blob Storage
///
/// **No están en el APK.** Se suben desde la web, viven en Azure y la app las
/// pide por `GET /archivo/ver?ruta=` cuando va a dibujarlas. Un catálogo con
/// las fotos dentro sería un APK que hay que republicar cada vez que alguien
/// cambia una imagen — y las de un activo cambian cada intervención.
class ActivoFichaScreen extends ConsumerStatefulWidget {
  const ActivoFichaScreen({super.key, required this.activoId});

  final int activoId;

  @override
  ConsumerState<ActivoFichaScreen> createState() => _ActivoFichaScreenState();
}

class _ActivoFichaScreenState extends ConsumerState<ActivoFichaScreen> {
  int _foto = 0;
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final activo = ref.watch(activoProvider(widget.activoId));

    return Scaffold(
      backgroundColor: sg.fondo,
      bottomNavigationBar: SgPie(
        child: Row(
          children: [
            Expanded(
              child: SgBoton('Registrar condición',
                  icono: Icons.speed_outlined,
                  // Medicion y no lectura: una lectura necesita saber **de que
                  // medidor** es, y los medidores bajan en el bloque MEDICION
                  // de la sabana, no por un endpoint propio. Desde la ficha se
                  // registra la condicion del activo; la lectura se abre desde
                  // el medidor, que es donde su identidad esta.
                  onTap: () => _capturar(activo.valueOrNull)),
            ),
            const SizedBox(width: 9),
            SgBotonIcono(Icons.photo_camera_outlined,
                fondo: sg.up, color: sg.tinta, lado: 52, tamano: 21),
            const SizedBox(width: 9),
            SgBotonIcono(Icons.swap_vert,
                fondo: sg.up, color: sg.tinta, lado: 52, tamano: 21),
          ],
        ),
      ),
      body: EstadoAsync<Activo>(
        valor: activo,
        onReintentar: () => ref.invalidate(activoProvider(widget.activoId)),
        child: (a) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                activo: a,
                indice: _foto,
                onFoto: (i) => setState(() => _foto = i),
              ),
            ),
            SliverToBoxAdapter(
              child: _Pestanas(
                activa: _pestana,
                onCambio: (i) => setState(() => _pestana = i),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: SliverList.list(
                children: _pestana == 0
                    ? _ficha(a)
                    : [_Historial(activoId: widget.activoId)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturar(Activo? a) async {
    if (a == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaScreen(
          tipo: TipoCaptura.medicion,
          activoId: a.act_id,
          activoNombre: a.act_nombre,
          activoCodigo: a.act_codigo,
          ubicacion: a.ruta,
        ),
      ),
    );
    if (mounted) ref.invalidate(fichaActivoProvider(widget.activoId));
  }

  List<Widget> _ficha(Activo a) => [
        _Cifras(activo: a),
        const SizedBox(height: 13),
        SgBloque(
          filas: [
            if ((a.TIPO_NOMBRE ?? '').isNotEmpty)
              SgFila(texto: 'Tipo', valor: a.TIPO_NOMBRE!, alto: 50),
            if (a.marcaModelo.isNotEmpty)
              SgFila(texto: 'Marca y modelo', valor: a.marcaModelo, alto: 50),
            if ((a.act_numero_serie ?? '').isNotEmpty)
              SgFila(
                  texto: 'N.º de serie', valor: a.act_numero_serie!, alto: 50),
            if ((a.PADRE_CODIGO ?? '').isNotEmpty)
              SgFila(texto: 'Depende de', valor: a.PADRE_CODIGO!, alto: 50),
          ],
        ),
      ];
}

/// El hero de 274 con la foto, los velos y las miniaturas.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.activo,
    required this.indice,
    required this.onFoto,
  });

  final Activo activo;
  final int indice;
  final ValueChanged<int> onFoto;

  static const _tinta = Color(0xFFF8FAFC);

  /// La portada primero y la galería después, **sin repetir**.
  ///
  /// `FOTOS` incluye la portada: el servidor devuelve todas las imágenes del
  /// activo con la de referencia adelante. Concatenar sin deduplicar mostraba
  /// la misma foto dos veces en la tira de miniaturas, y al tocar la segunda
  /// «no pasaba nada».
  List<String> get _fotos {
    final vistas = <String>{};
    return [
      if ((activo.FOTO_RUTA ?? '').isNotEmpty) activo.FOTO_RUTA!,
      ...activo.FOTOS,
    ].where(vistas.add).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fotos = _fotos;

    /* EL ALTO DEL ARTBOARD ES DE CONTENIDO, NO DE PANTALLA

       El `SafeArea` de adentro aparta la barra de estado, pero la apartaba
       DENTRO de un alto fijo: en un teléfono con barra alta —o con la fuente
       del sistema agrandada— al contenido le quedaban 274 menos el inset y
       la columna desbordaba, con la franja amarilla de overflow encima de la
       foto del activo.

       Sumar el inset al alto conserva los 274 dp que pide el kit por debajo de
       la barra, que es donde el diseño los midió. */
    return SizedBox(
      height: 274 + MediaQuery.paddingOf(context).top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // El fondo cuando no hay foto: el degradado del kit, no un gris.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF141E2F), Color(0xFF0C121F)],
              ),
            ),
          ),
          if (fotos.isNotEmpty)
            SigmaImagen(
              ruta: fotos[indice.clamp(0, fotos.length - 1)],
              radio: 0,
              ajuste: BoxFit.cover,
              // Ampliada, una foto sin rótulo no dice de qué equipo es.
              titulo: [activo.act_codigo, activo.act_nombre]
                  .where((t) => t.isNotEmpty)
                  .join(' · '),
            ),
          // Dos velos: arriba para que se lean los botones, abajo para que se
          // lea el título. Sin ellos, una foto clara los borra a los dos.
          const _Velo(arriba: true),
          const _Velo(arriba: false),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _BotonVidrio(Icons.arrow_back,
                            onTap: () => Navigator.maybePop(context)),
                        const Spacer(),
                        _BotonVidrio(Icons.star_outline),
                        const SizedBox(width: 8),
                        _BotonVidrio(Icons.share_outlined),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _ChipHero(activo.act_codigo, color: SgColor.teal),
                          if ((activo.ESTADO_NOMBRE ?? '').isNotEmpty)
                            _ChipHero(activo.ESTADO_NOMBRE!,
                                color: SgColor.oscuroVerdeTexto,
                                icono: Icons.check_circle),
                          if ((activo.CRITICIDAD_NOMBRE ?? '').isNotEmpty)
                            _ChipHero(activo.CRITICIDAD_NOMBRE!,
                                color: SgColor.oscuroAmbarTexto,
                                icono: Icons.local_fire_department),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(activo.act_nombre,
                          style: sora(24, 700, color: _tinta, alto: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (activo.ruta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 16, color: Color(0xFFA8B2C3)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(activo.ruta,
                                  style: sora(13, 500,
                                      color: const Color(0xFFA8B2C3)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                      if (fotos.length > 1) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: fotos.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 7),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => onFoto(i),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow:
                                      i == indice ? anillo(SgColor.teal) : null,
                                ),
                                child: SigmaImagen(
                                  ruta: fotos[i],
                                  ancho: 52,
                                  alto: 52,
                                  radio: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Velo extends StatelessWidget {
  const _Velo({required this.arriba});
  final bool arriba;

  @override
  Widget build(BuildContext context) => Align(
        alignment: arriba ? Alignment.topCenter : Alignment.bottomCenter,
        child: IgnorePointer(
          child: Container(
            height: arriba ? 120 : 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: arriba ? Alignment.topCenter : Alignment.bottomCenter,
                end: arriba ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Color(arriba ? 0xD905070E : 0xEB05070E),
                  const Color(0x0005070E),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BotonVidrio extends StatelessWidget {
  const _BotonVidrio(this.icono, {this.onTap});
  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: const Color(0xD1111827),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icono, size: 21, color: const Color(0xFFF8FAFC)),
          ),
        ),
      );
}

class _ChipHero extends StatelessWidget {
  const _ChipHero(this.texto, {required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        height: SgMedida.badge,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 13, color: color),
              const SizedBox(width: 6),
            ],
            Text(texto, style: sora(12, 600, color: color)),
          ],
        ),
      );
}

/// Las pestañas del kit: subrayado de 2 en morado sobre `card`.
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
                    style: sora(14, i == activa ? 600 : 500,
                        color: i == activa ? sg.tinta : sg.tinta2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La rejilla de tres cifras.
///
/// Cada una sale de un dato que el servidor ya calcula. **Lo que no exista no
/// se rellena**: una tarjeta con un guion es más honesta que una con un número
/// que nadie midió.
class _Cifras extends ConsumerWidget {
  const _Cifras({required this.activo});
  final Activo activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventos =
        ref.watch(fichaActivoProvider(activo.act_id)).valueOrNull;

    return Row(
      children: [
        Expanded(
          child: _Cifra(
            icono: Icons.build_outlined,
            valor: eventos == null ? '—' : '${eventos.total}',
            rotulo: 'eventos',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _Cifra(
            icono: Icons.qr_code_2,
            valor: activo.act_codigo,
            rotulo: 'código',
            pequeno: true,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _Cifra(
            icono: Icons.shield_outlined,
            valor: activo.CRITICIDAD_NOMBRE ?? '—',
            rotulo: 'criticidad',
            pequeno: true,
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.icono,
    required this.valor,
    required this.rotulo,
    this.pequeno = false,
  });

  final IconData icono;
  final String valor;
  final String rotulo;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sg.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: sg.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: sg.acentoTexto),
          const SizedBox(height: 5),
          Text(valor,
              style: sora(pequeno ? 14 : 21, 700,
                  color: sg.tinta, alto: 1, tabular: true),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Text(rotulo, style: sora(11, 500, color: sg.tinta3)),
        ],
      ),
    );
  }
}

/// El historial de intervenciones, tal como lo devuelve `/activos/{id}/ficha`.
class _Historial extends ConsumerWidget {
  const _Historial({required this.activoId});
  final int activoId;

  static final _fecha = DateFormat('d MMM y', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final eventos = ref.watch(fichaActivoProvider(activoId));

    return EstadoAsync<Paginado<ActivoFichaEvento>>(
      valor: eventos,
      onReintentar: () => ref.invalidate(fichaActivoProvider(activoId)),
      estaVacio: (p) => p.vacio,
      vacio: const EstadoVacio(
        icono: Icons.history,
        titulo: 'Sin historial',
        detalle: 'Cuando este activo tenga intervenciones registradas, van a '
            'aparecer acá en orden.',
      ),
      child: (p) => SgBloque(
        filas: [
          for (final e in p.datos)
            SgFila(
              icono: Icons.circle,
              colorIcono: sg.acentoTexto,
              texto: e.TITULO,
              detalle: [
                if (e.FECHA != null) _fecha.format(e.FECHA!.toLocal()),
                if ((e.DETALLE ?? '').isNotEmpty) e.DETALLE!,
              ].join(' · '),
            ),
        ],
      ),
    );
  }
}
