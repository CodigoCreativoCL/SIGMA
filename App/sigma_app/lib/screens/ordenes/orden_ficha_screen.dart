import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import 'recursos_orden.dart';

/// 6.3 · Ficha de OT y 6.4 · Ejecución de pasos — HU-113, HU-114, HU-119.
///
/// Layout del artboard: hero de 200 con los chips sobre la foto; pestañas
/// Resumen / Pasos; tarjeta de progreso con la barra en degradado; descripción
/// y responsable en un bloque de filas; el permiso requerido como tarjeta
/// aparte; y el pie que cambia según el estado.
///
/// ## Las dos pantallas del kit son una sola acá
///
/// El kit dibuja 6.3 (ficha) y 6.4 (pasos) por separado, pero en el teléfono
/// son la misma orden vista de dos formas, y navegar entre ellas perdería el
/// desplazamiento cada vez que se completa un paso. Son dos pestañas: el
/// contenido es idéntico al de los dos artboards.
///
/// ## El pie dice lo único que se puede hacer ahora
///
/// Abierta sin dueño → **Tomar**. En ejecución → **Continuar pasos**, y con
/// todos los obligatorios listos → **Finalizar**. Mostrar los tres siempre
/// obligaría a leer cuál está habilitado.
class OrdenFichaScreen extends ConsumerStatefulWidget {
  const OrdenFichaScreen({super.key, required this.ordenId});

  final int ordenId;

  @override
  ConsumerState<OrdenFichaScreen> createState() => _OrdenFichaScreenState();
}

class _OrdenFichaScreenState extends ConsumerState<OrdenFichaScreen> {
  int _pestana = 0;
  bool _ocupado = false;

  Future<void> _accion(Future<void> Function() que, String exito) async {
    if (_ocupado) return;
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);

    try {
      await que();
      ref.invalidate(ordenTrabajoProvider(widget.ordenId));
      ref.invalidate(ordenesTrabajoProvider);
      ref.invalidate(ordenesDisponiblesProvider);
      mensajero.showSnackBar(SnackBar(content: Text(exito)));
    } on ApiException catch (e) {
      // El mensaje del servidor se muestra tal cual: «la orden ya fue tomada
      // por otro» dice qué pasó y qué hacer; «error 409» no.
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final ficha = ref.watch(ordenTrabajoProvider(widget.ordenId));

    return Scaffold(
      backgroundColor: sg.fondo,
      body: EstadoAsync<OrdenTrabajoFicha>(
        valor: ficha,
        onReintentar: () => ref.invalidate(ordenTrabajoProvider(widget.ordenId)),
        child: (f) => Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Hero(orden: f.orden)),
                  SliverToBoxAdapter(
                    child: _Pestanas(
                      activa: _pestana,
                      pendientes: f.pendientes,
                      onCambio: (i) => setState(() => _pestana = i),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    sliver: SliverList.list(
                      children: switch (_pestana) {
                        0 => _resumen(f),
                        1 => _pasos(f),
                        _ => [
                              RecursosOrdenVista(
                                ordenId: widget.ordenId,
                                puedeEditar: f.orden.enEjecucion,
                              ),
                            ],
                      },
                    ),
                  ),
                ],
              ),
            ),
            _Pie(
              ficha: f,
              ocupado: _ocupado,
              onTomar: () => _accion(
                  () => SigmaRepository.instance
                      .tomarOrdenTrabajo(widget.ordenId),
                  'Orden tomada. Queda a tu nombre.'),
              onPasos: () => setState(() => _pestana = 1),
              onFinalizar: () => _confirmarFin(f),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ RESUMEN ----

  List<Widget> _resumen(OrdenTrabajoFicha f) {
    final sg = context.sg;
    final o = f.orden;

    return [
      _Progreso(ficha: f),
      const SizedBox(height: 13),
      if ((o.otr_descripcion ?? '').isNotEmpty) ...[
        SgCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(15, 13, 15, 9),
                child: SgRotulo('Descripción'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
                child: Text(o.otr_descripcion!,
                    style: sora(14, 500, color: sg.tinta, alto: 1.55)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
      ],
      SgBloque(
        filas: [
          SgFila(
            icono: Icons.engineering,
            texto: 'Responsable',
            colorTexto: sg.tinta2,
            valor: o.RESPONSABLE_NOMBRE ?? 'Sin asignar',
            alto: 52,
          ),
          if (o.otr_fecha_evento_utc != null)
            SgFila(
              icono: Icons.event_outlined,
              texto: 'Evento real',
              colorTexto: sg.tinta2,
              valor: _fecha.format(o.otr_fecha_evento_utc!.toLocal()),
              alto: 52,
            ),
          if (o.otr_fecha_programada_utc != null)
            SgFila(
              icono: Icons.schedule,
              texto: 'Programada',
              colorTexto: sg.tinta2,
              valor: _fecha.format(o.otr_fecha_programada_utc!.toLocal()),
              alto: 52,
            ),
          if ((o.ESTRATEGIA_NOMBRE ?? '').isNotEmpty)
            SgFila(
              icono: Icons.category_outlined,
              texto: 'Estrategia',
              colorTexto: sg.tinta2,
              valor: o.ESTRATEGIA_NOMBRE!,
              alto: 52,
            ),
        ],
      ),

      // El permiso va en tarjeta propia y no como una fila más: sin él no se
      // abre la máquina, así que no es un dato de consulta sino una condición
      // para empezar.
      if (o.otr_requiere_permiso) ...[
        const SizedBox(height: 13),
        SgCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SgIconoCuadro(Icons.engineering,
                  color: sg.ambarTexto, lado: 44, tamanoIcono: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permiso requerido',
                        style: sora(15, 600, color: sg.tinta)),
                    const SizedBox(height: 4),
                    SgBadge(
                      o.PERMISO_NUMERO ?? 'Sin permiso emitido',
                      color: o.PERMISO_NUMERO == null
                          ? sg.rojoTexto
                          : sg.ambarTexto,
                      chico: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],

      if (f.asignados.isNotEmpty) ...[
        const SizedBox(height: 13),
        SgBloque(
          rotulo: 'Equipo',
          filas: [
            for (final a in f.asignados)
              SgFila(
                icono: a.ota_es_responsable
                    ? Icons.person
                    : Icons.person_outline,
                colorIcono: a.ota_es_responsable ? sg.acentoTexto : null,
                texto: a.USUARIO_NOMBRE ?? 'Sin nombre',
                detalle: a.ROL_NOMBRE,
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
    ];
  }

  // -------------------------------------------------------------- PASOS ----

  List<Widget> _pasos(OrdenTrabajoFicha f) {
    if (f.pasos.isEmpty) {
      return const [
        EstadoVacio(
          icono: Icons.checklist,
          titulo: 'Esta orden no tiene pasos',
          detalle: 'Se puede finalizar igual: no todo trabajo correctivo '
              'viene con una pauta.',
        ),
      ];
    }

    // El siguiente pendiente va abierto y elevado; los demás, colapsados. Con
    // cinco pasos en pantalla, todos abiertos obligan a buscar cuál toca.
    final siguiente = f.pasos.where((p) => p.pendiente).firstOrNull;

    return [
      _Progreso(ficha: f),
      const SizedBox(height: 13),
      for (final p in f.pasos) ...[
        _Paso(
          paso: p,
          activo: p.otp_id == siguiente?.otp_id,
          habilitado: f.orden.enEjecucion,
          onCompletar: (resultado, observacion, porVoz) => _accion(
            () => SigmaRepository.instance.completarPaso(
              p.otp_id,
              resultado: resultado,
              observacion: observacion,
              entradaModo: porVoz ? 2 : 1,
            ),
            'Paso registrado.',
          ),
        ),
        const SizedBox(height: 11),
      ],
      const SizedBox(height: 4),
    ];
  }

  Future<void> _confirmarFin(OrdenTrabajoFicha f) async {
    final sg = context.sg;
    final control = TextEditingController();

    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Finalizar la orden?',
            style: sora(18, 600, color: sg.tinta)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Queda en espera de cierre. El cierre lo hace el planificador '
              'o el supervisor, no tú.',
              style: sora(14, 500, color: sg.tinta2, alto: 1.5),
            ),
            const SizedBox(height: 16),
            SgCampo(
              controlador: control,
              rotulo: 'Resultado',
              icono: Icons.notes,
              hint: 'Qué quedó hecho',
              lineas: 2,
              conVoz: true,
              // Sin este `onVoz` el micrófono se dibujaba y no hacía nada:
              // `SgCampo` lo pasa tal cual al `onTap` del botón, y un `onTap`
              // nulo es un botón muerto que igual se ve habilitado.
              onVoz: () async {
                final campos = await mostrarPanelVoz(
                  c,
                  titulo: 'Resultado',
                  interpretar: (t) => [
                    CampoDictado(
                        clave: 'texto',
                        rotulo: 'Resultado',
                        valor: InterpreteVoz.normalizar(t)),
                  ],
                );
                if (campos == null || campos.isEmpty) return;
                escribirDictado(control, campos.first.valor);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancelar', style: sora(15, 600, color: sg.tinta2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Finalizar', style: sora(15, 600, color: sg.primarioTexto)),
          ),
        ],
      ),
    );

    final texto = control.text.trim();
    control.dispose();
    if (si != true || !mounted) return;

    await _accion(
      () => SigmaRepository.instance.finalizarOrdenTrabajo(widget.ordenId,
          resultado: texto.isEmpty ? null : texto),
      'Orden finalizada. Queda en espera de cierre.',
    );
  }

  static final _fecha = DateFormat('dd-MM HH:mm', 'es');
}

// ─────────────────────────────────────────────────────────────── HERO ──

class _Hero extends StatelessWidget {
  const _Hero({required this.orden});
  final OrdenTrabajo orden;

  static const _tinta = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    /* EL ALTO DEL ARTBOARD ES DE CONTENIDO, NO DE PANTALLA

       El `SafeArea` de adentro aparta la barra de estado, pero la apartaba
       DENTRO de un alto fijo: en un teléfono con barra alta —o con la fuente
       del sistema agrandada— al contenido le quedaban 274 menos el inset y
       la columna desbordaba, con la franja amarilla de overflow encima de la
       foto del activo.

       Sumar el inset al alto conserva los 200 dp que pide el kit por debajo de
       la barra, que es donde el diseño los midió. */
    return SizedBox(
      height: 200 + MediaQuery.paddingOf(context).top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF141E2F), Color(0xFF0C121F)],
              ),
            ),
          ),
          // Un solo velo de arriba abajo: el hero de la OT es más bajo que el
          // del activo y dos velos lo dejarían casi negro entero.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD605070E), Color(0x3305070E), Color(0xF205070E)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _Vidrio(Icons.arrow_back,
                            onTap: () => Navigator.maybePop(context)),
                        const Spacer(),
                        _Vidrio(Icons.share_outlined),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if ((orden.PRIORIDAD_NOMBRE ?? '').isNotEmpty)
                            _ChipHero(orden.PRIORIDAD_NOMBRE!,
                                color: orden.PRIORIDAD_ID >= 4
                                    ? SgColor.oscuroRojoTexto
                                    : SgColor.oscuroAmbarTexto),
                          if ((orden.TIPO_NOMBRE ?? '').isNotEmpty)
                            _ChipHero(orden.TIPO_NOMBRE!, color: _tinta),
                          if ((orden.ESTADO_NOMBRE ?? '').isNotEmpty)
                            _ChipHero(orden.ESTADO_NOMBRE!,
                                color: orden.enEjecucion
                                    ? SgColor.oscuroAmbarTexto
                                    : SgColor.teal,
                                icono: orden.enEjecucion
                                    ? Icons.build
                                    : Icons.folder_open),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${orden.OT_NUMERO} · ${orden.otr_titulo}',
                          style: sora(21, 700,
                              color: _tinta, alto: 1.25, espaciado: -0.42),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (orden.ubicacion.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(orden.ubicacion,
                            style: sora(13, 500,
                                color: const Color(0xFFA8B2C3)),
                            overflow: TextOverflow.ellipsis),
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

class _Vidrio extends StatelessWidget {
  const _Vidrio(this.icono, {this.onTap});
  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: const Color(0xCC111827),
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
          color: color.withValues(alpha: 0.22),
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

class _Pestanas extends StatelessWidget {
  const _Pestanas({
    required this.activa,
    required this.pendientes,
    required this.onCambio,
  });

  final int activa;
  final int pendientes;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final titulos = ['Resumen', 'Pasos', 'Recursos'];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sg.card,
        border: Border(bottom: BorderSide(color: sg.div)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < titulos.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onCambio(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == activa ? sg.primario : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(titulos[i],
                          style: sora(13, i == activa ? 600 : 500,
                              color: i == activa ? sg.tinta : sg.tinta2)),
                      if (i == 1 && pendientes > 0) ...[
                        const SizedBox(width: 7),
                        SgContador(pendientes, color: sg.primario),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.ficha});
  final OrdenTrabajoFicha ficha;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final o = ficha.orden;
    final listos = o.PASOS_LISTOS;
    final total = o.PASOS_TOTAL;

    return SgCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SgRotulo('Progreso general')),
              Text('${(o.avance * 100).round()} %',
                  style: sora(15, 700, color: sg.tinta, tabular: true)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SgRadius.pill),
            child: Stack(
              children: [
                Container(height: 8, color: sg.up),
                FractionallySizedBox(
                  widthFactor: o.avance,
                  child: Container(
                    height: 8,
                    decoration:
                        const BoxDecoration(gradient: SgColor.gradiente),
                  ),
                ),
              ],
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (listos > 0)
                  SgBadge('$listos ${listos == 1 ? "paso listo" : "pasos listos"}',
                      color: sg.verdeTexto),
                if (ficha.pendientes > 0)
                  SgBadge('${ficha.pendientes} pendiente'
                      '${ficha.pendientes == 1 ? "" : "s"}',
                      color: sg.ambarTexto),
                if (o.otr_duracion_estimada_minuto != null)
                  SgBadge(_duracion(o.otr_duracion_estimada_minuto!),
                      color: sg.tinta2, icono: Icons.timer_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _duracion(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m';
  }
}

/// Un paso, con su captura cuando toca ejecutarlo.
class _Paso extends StatefulWidget {
  const _Paso({
    required this.paso,
    required this.activo,
    required this.habilitado,
    required this.onCompletar,
  });

  final OrdenTrabajoPaso paso;
  final bool activo;
  final bool habilitado;
  final void Function(int resultado, String? observacion, bool porVoz)
      onCompletar;

  @override
  State<_Paso> createState() => _PasoState();
}

class _PasoState extends State<_Paso> {
  final _observacion = TextEditingController();
  bool _porVoz = false;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final p = widget.paso;

    // Ya resuelto: fila compacta con su marca. Un paso hecho no necesita
    // ocupar media pantalla.
    if (!p.pendiente) {
      final (color, icono) = p.conforme
          ? (sg.verdeTexto, Icons.check_circle)
          : p.noConforme
              ? (sg.rojoTexto, Icons.cancel)
              : (sg.tinta3, Icons.remove_circle_outline);

      return SgCard(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        sinSombra: true,
        color: sg.fondo,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.otp_orden} · ${p.otp_nombre}',
                      style: sora(14, 500, color: sg.tinta2)),
                  if ((p.OBSERVACION ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(p.OBSERVACION!,
                        style: sora(13, 500, color: sg.tinta3, alto: 1.4)),
                  ],
                ],
              ),
            ),
            if (p.otp_fecha_ejecucion_utc != null) ...[
              const SizedBox(width: 8),
              Text(
                DateFormat('HH:mm').format(p.otp_fecha_ejecucion_utc!.toLocal()),
                style: sora(12, 500, color: sg.tinta3, tabular: true),
              ),
            ],
          ],
        ),
      );
    }

    // Pendiente y no es el siguiente: solo el enunciado.
    if (!widget.activo) {
      return SgCard(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.radio_button_unchecked, size: 20, color: sg.tinta3),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${p.otp_orden} · ${p.otp_nombre}',
                  style: sora(14, 500, color: sg.tinta2)),
            ),
            if (p.otp_obligatorio)
              Icon(Icons.star, size: 14, color: sg.rojoTexto),
          ],
        ),
      );
    }

    // El siguiente: abierto, elevado y con la captura.
    return SgCard(
      padding: const EdgeInsets.all(16),
      elevada: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.otp_obligatorio)
                SgBadge('Obligatorio',
                    color: sg.rojoTexto, icono: Icons.star_outline),
              SgBadge('Paso ${p.otp_orden}', color: sg.azulTexto),
            ],
          ),
          const SizedBox(height: 14),
          Text(p.otp_nombre,
              style: sora(20, 700, color: sg.tinta, alto: 1.35,
                  espaciado: -0.4)),
          if ((p.otp_descripcion ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.otp_descripcion!,
                style: sora(14, 500, color: sg.tinta2, alto: 1.5)),
          ],
          const SizedBox(height: 14),
          SgCampo(
            controlador: _observacion,
            rotulo: 'Observación',
            icono: Icons.notes,
            hint: 'Lo que viste, oíste o tocaste',
            lineas: 2,
            conVoz: true,
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Observación',
                interpretar: (t) => [
                  CampoDictado(
                      clave: 'texto',
                      rotulo: 'Observación',
                      valor: InterpreteVoz.normalizar(t)),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() {
                escribirDictado(_observacion, campos.first.valor);
                _porVoz = true;
              });
            },
          ),
          const SizedBox(height: 14),
          if (!widget.habilitado)
            SgAviso(
              'Toma la orden antes de completar pasos.',
              icono: Icons.lock_outline,
              color: sg.ambarTexto,
              tenido: true,
            )
          else
            Row(
              children: [
                Expanded(
                  child: SgBoton('Conforme',
                      icono: Icons.check,
                      alto: 44,
                      tamanoTexto: 14,
                      onTap: () => _completar(1)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: SgBoton('No conforme',
                      icono: Icons.close,
                      alto: 44,
                      tamanoTexto: 14,
                      color: sg.tinte(sg.rojoTexto),
                      colorTexto: sg.rojoTexto,
                      colorIcono: sg.rojoTexto,
                      onTap: () => _completar(2)),
                ),
                const SizedBox(width: 9),
                SgBotonIcono(Icons.block,
                    fondo: sg.up,
                    color: sg.tinta2,
                    onTap: () => _completar(3)),
              ],
            ),
        ],
      ),
    );
  }

  void _completar(int resultado) {
    final obs = _observacion.text.trim();
    widget.onCompletar(resultado, obs.isEmpty ? null : obs, _porVoz);
  }
}

/// El pie: **una sola acción**, la que corresponde al estado.
class _Pie extends StatelessWidget {
  const _Pie({
    required this.ficha,
    required this.ocupado,
    required this.onTomar,
    required this.onPasos,
    required this.onFinalizar,
  });

  final OrdenTrabajoFicha ficha;
  final bool ocupado;
  final VoidCallback onTomar;
  final VoidCallback onPasos;
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    final o = ficha.orden;

    if (o.ESTADO_ID >= 3) {
      return SgPie(
        child: SgBoton(
          o.ESTADO_ID == 3 ? 'En espera de cierre' : 'Cerrada',
          icono: Icons.lock_outline,
          primario: false,
          onTap: null,
        ),
      );
    }

    if (o.abierta) {
      return SgPie(
        child: SgBoton(
          o.sinResponsable ? 'Tomar trabajo' : 'Tomar y empezar',
          icono: Icons.pan_tool_outlined,
          cargando: ocupado,
          onTap: onTomar,
        ),
      );
    }

    // En ejecución: continuar mientras falten obligatorios, finalizar cuando
    // no falte ninguno. Los pasos opcionales no bloquean el cierre.
    final puedeFinalizar = ficha.obligatoriosPendientes == 0;

    return SgPie(
      child: Row(
        children: [
          Expanded(
            child: SgBoton(
              puedeFinalizar ? 'Finalizar' : 'Continuar pasos',
              icono: puedeFinalizar ? Icons.check : Icons.play_arrow,
              cargando: ocupado,
              onTap: puedeFinalizar ? onFinalizar : onPasos,
            ),
          ),
          if (!puedeFinalizar) ...[
            const SizedBox(width: 9),
            // Con `Tooltip` solo, el mensaje pedía mantener pulsado: en un
            // teléfono nadie lo descubre, y el botón se sentía muerto. Ahora
            // responde al toque, que es lo que se intenta primero.
            Builder(
              builder: (c) => SgBotonIcono(
                Icons.info_outline,
                fondo: context.sg.up,
                color: context.sg.tinta2,
                lado: 52,
                tamano: 21,
                onTap: () => ScaffoldMessenger.of(c).showSnackBar(
                  SnackBar(
                    content: Text('Faltan ${ficha.obligatoriosPendientes} '
                        'pasos obligatorios para poder finalizar.'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
