import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import '../../services/voz_service.dart';

/// La ficha de una entrada de bitácora — HU-131.
///
/// ## Lo que hace distinta a esta pantalla
///
/// Una bitácora **no se edita**. Cuando algo se corrige, la corrección se
/// apila encima y el texto original sigue a la vista. Por eso esta ficha
/// muestra las dos cosas: lo que vale hoy arriba, y debajo el historial con lo
/// que se escribió primero y por qué cambió.
///
/// Esconder el original convertiría la rectificación en una edición, y una
/// bitácora que se puede editar deja de servir como registro — que es su único
/// motivo de existir.
class EntradaBitacoraScreen extends ConsumerStatefulWidget {
  const EntradaBitacoraScreen({super.key, required this.entradaId});

  final int entradaId;

  @override
  ConsumerState<EntradaBitacoraScreen> createState() =>
      _EntradaBitacoraScreenState();
}

class _EntradaBitacoraScreenState
    extends ConsumerState<EntradaBitacoraScreen> {
  final _comentario = TextEditingController();
  bool _enviando = false;

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _comentar() async {
    final texto = _comentario.text.trim();
    if (texto.isEmpty || _enviando) return;

    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);

    try {
      await SigmaRepository.instance
          .comentarBitacora(widget.entradaId, {'texto': texto});
      _comentario.clear();
      ref.invalidate(entradaBitacoraProvider(widget.entradaId));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _rectificar(BitacoraFicha f) async {
    final texto = TextEditingController(text: f.entrada.TEXTO_VIGENTE);
    final motivo = TextEditingController();
    final sg = context.sg;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, refrescar) => Container(
          decoration: BoxDecoration(
            color: sg.fondo,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SgRadius.hoja)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.viewInsetsOf(c).bottom,
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
                    Text('Rectificar la anotación',
                        style: sora(17, 600, color: sg.tinta)),
                    const SizedBox(height: 4),
                    Text(
                      'El texto original NO se borra: queda debajo con esta '
                      'corrección encima, y ambos con su autor.',
                      style: sora(13, 500, color: sg.tinta3, alto: 1.45),
                    ),
                    const SizedBox(height: 15),
                    const SgRotuloCampo('Cómo queda'),
                    const SizedBox(height: 8),
                    SgCampo(
                      controlador: texto,
                      icono: Icons.notes,
                      lineas: 4,
                      onCambio: (_) => refrescar(() {}),
                    ),
                    const SizedBox(height: 14),
                    const SgRotuloCampo('Por qué se corrige'),
                    const SizedBox(height: 8),
                    SgCampo(
                      controlador: motivo,
                      icono: Icons.help_outline,
                      hint: 'Se confundió el equipo, faltó un dato…',
                      lineas: 2,
                      onCambio: (_) => refrescar(() {}),
                    ),
                    const SizedBox(height: 14),
                    SgBoton(
                      'Guardar la corrección',
                      icono: Icons.history_edu,
                      // El motivo es obligatorio: sin él nadie puede saber
                      // después si el texto cambió porque estaba mal escrito,
                      // porque se supo algo nuevo, o porque a alguien no le
                      // gustó cómo sonaba.
                      onTap: (texto.text.trim().isEmpty ||
                              motivo.text.trim().isEmpty)
                          ? null
                          : () => Navigator.of(c).pop(true),
                    ),
                    const SgBarraGestos(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final t = texto.text.trim();
    final m = motivo.text.trim();
    texto.dispose();
    motivo.dispose();

    if (ok != true || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await SigmaRepository.instance.rectificarBitacora(widget.entradaId, t, m);
      ref.invalidate(entradaBitacoraProvider(widget.entradaId));
      ref.invalidate(bitacoraProvider);
      mensajero.showSnackBar(
          const SnackBar(content: Text('Corrección guardada.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final ficha = ref.watch(entradaBitacoraProvider(widget.entradaId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Anotación'),
      body: EstadoAsync<BitacoraFicha>(
        valor: ficha,
        onReintentar: () =>
            ref.invalidate(entradaBitacoraProvider(widget.entradaId)),
        child: (f) {
          final e = f.entrada;
          final corregida = f.rectificaciones.isNotEmpty;

          return ListView(
            padding: context
                .conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 24)),
            children: [
              SgCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if ((e.TIPO_NOMBRE ?? '').isNotEmpty)
                          SgBadge(e.TIPO_NOMBRE!, color: sg.tinta2, chico: true),
                        if ((e.SEVERIDAD_NOMBRE ?? '').isNotEmpty)
                          SgBadge(e.SEVERIDAD_NOMBRE!,
                              color: sg.ambarTexto, chico: true),
                        if (e.bit_requiere_atencion)
                          SgBadge('Requiere atención',
                              color: sg.rojoTexto,
                              icono: Icons.priority_high,
                              chico: true),
                        if (e.POR_VOZ)
                          SgBadge('Dictada',
                              color: sg.tinta3, icono: Icons.mic, chico: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(e.bit_titulo,
                        style: sora(19, 700, color: sg.tinta, alto: 1.3)),
                    const SizedBox(height: 8),
                    Text(e.TEXTO_VIGENTE,
                        style: sora(14, 500, color: sg.tinta2, alto: 1.55)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: sg.tinta3),
                        const SizedBox(width: 5),
                        Text(_fecha.format(e.bit_fecha_evento_utc.toLocal()),
                            style: sora(12, 500, color: sg.tinta3)),
                        if ((e.bit_turno ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('· turno ${e.bit_turno}',
                              style: sora(12, 500, color: sg.tinta3)),
                        ],
                      ],
                    ),
                    if ((e.USUARIO_NOMBRE ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: sg.tinta3),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(e.USUARIO_NOMBRE!,
                                style: sora(12, 500, color: sg.tinta3),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    SgBoton('Rectificar',
                        icono: Icons.history_edu,
                        primario: false,
                        alto: 44,
                        tamanoTexto: 14,
                        onTap: () => _rectificar(f)),
                  ],
                ),
              ),

              /* EL ORIGINAL SIGUE A LA VISTA

                 Es lo que separa una bitácora de un documento editable: la
                 corrección se apila, no reemplaza. Quien lea esto mañana tiene
                 que poder ver qué se dijo primero y por qué cambió. */
              if (corregida) ...[
                const SizedBox(height: 18),
                const SgRotulo('Cómo se escribió primero'),
                const SizedBox(height: 10),
                SgCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(f.TEXTO_ORIGINAL,
                      style: sora(13, 500, color: sg.tinta3, alto: 1.5)),
                ),
                const SizedBox(height: 14),
                SgRotuloConAccion('Correcciones',
                    accion: '${f.rectificaciones.length}'),
                const SizedBox(height: 10),
                for (final r in f.rectificaciones) ...[
                  SgCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.bre_texto_rectificado,
                            style: sora(13, 500, color: sg.tinta2, alto: 1.5)),
                        const SizedBox(height: 8),
                        Text('Motivo: ${r.bre_motivo}',
                            style: sora(12, 600, color: sg.ambarTexto)),
                        const SizedBox(height: 5),
                        Text(
                          '${r.USUARIO_NOMBRE ?? ''} · '
                          '${_fecha.format(r.bre_fecha_creacion.toLocal())}',
                          style: sora(11, 500, color: sg.tinta3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],

              const SizedBox(height: 18),
              SgRotuloConAccion('Comentarios',
                  accion: '${f.comentarios.length}'),
              const SizedBox(height: 10),
              if (f.comentarios.isEmpty)
                SgAviso(
                  'Nadie ha comentado todavía. Un comentario sirve para sumar '
                  'lo que se supo después sin tocar lo que se escribió.',
                  icono: Icons.chat_bubble_outline,
                  color: sg.tinta2,
                )
              else
                for (final c in f.comentarios) ...[
                  SgCard(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.bco_texto,
                            style: sora(13, 500, color: sg.tinta, alto: 1.5)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${c.USUARIO_NOMBRE ?? ''} · '
                                '${_fecha.format(c.bco_fecha_creacion.toLocal())}',
                                style: sora(11, 500, color: sg.tinta3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.POR_VOZ)
                              Icon(Icons.mic, size: 13, color: sg.tinta3),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

              const SizedBox(height: 6),
              SgCampo(
                controlador: _comentario,
                icono: Icons.add_comment_outlined,
                hint: 'Sumar algo que se supo después',
                lineas: 2,
                conVoz: true,
                onCambio: (_) => setState(() {}),
                onVoz: () async {
                  final campos = await mostrarPanelVoz(
                    context,
                    titulo: 'Comentario',
                    interpretar: (t) => [
                      CampoDictado(
                          clave: 'texto',
                          rotulo: 'Comentario',
                          valor: InterpreteVoz.normalizar(t)),
                    ],
                  );
                  if (campos == null || campos.isEmpty) return;
                  setState(() =>
                      escribirDictado(_comentario, campos.first.valor));
                },
              ),
              const SizedBox(height: 10),
              SgBoton('Comentar',
                  icono: Icons.send,
                  alto: 46,
                  cargando: _enviando,
                  onTap:
                      _comentario.text.trim().isEmpty ? null : _comentar),
            ],
          );
        },
      ),
    );
  }
}
