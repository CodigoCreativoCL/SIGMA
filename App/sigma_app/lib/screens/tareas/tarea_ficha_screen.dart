import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/cronometro_service.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_cronometro.dart';
import '../../widgets/comun/sigma_evidencia.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// La tarea abierta — HU-103 (ejecutar) y HU-104 (comentar).
///
/// ## Empezar y cerrar en la misma pantalla
///
/// Porque en terreno son un solo acto, muchas veces de diez minutos. Se
/// empieza al entrar —el `uuid` se genera **ahí**, no al enviar— y se cierra
/// con «Listo» o con «No se pudo». Si fueran dos pantallas, la persona tendría
/// que volver a buscar la tarea para cerrarla.
///
/// ## «No se pudo» pide motivo, y no es burocracia
///
/// Una tarea que no se hizo y no dice por qué es indistinguible de una que se
/// olvidó, y el historial del activo queda con un hueco que nadie puede
/// interpretar después. El servidor lo exige; acá el botón simplemente no se
/// habilita hasta que haya texto, para no mandar un envío que va a rebotar.
class TareaFichaScreen extends ConsumerStatefulWidget {
  const TareaFichaScreen({super.key, required this.ocurrenciaId});

  final int ocurrenciaId;

  @override
  ConsumerState<TareaFichaScreen> createState() => _TareaFichaScreenState();
}

class _TareaFichaScreenState extends ConsumerState<TareaFichaScreen> {
  /// Generado una vez al entrar y reusado en el cierre. Si se generara al
  /// enviar, un reintento de la cola traería uno nuevo y abriría una segunda
  /// ejecución de algo que se hizo una sola vez.
  final String _uuid = OutboxService.nuevoUuid();

  bool _empezando = false;
  bool _empezada = false;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tarea = ref.watch(tareaProvider(widget.ocurrenciaId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Tarea'),
      body: EstadoAsync<Tarea>(
        valor: tarea,
        onReintentar: () => ref.invalidate(tareaProvider(widget.ocurrenciaId)),
        child: (t) => ListView(
          padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 28)),
          children: [
            _Cabecera(tarea: t),
            const SizedBox(height: 12),
            if (t.tar_descripcion != null && t.tar_descripcion!.isNotEmpty) ...[
              _ComoSeHace(texto: t.tar_descripcion!),
              const SizedBox(height: 12),
            ],
            _Ejecucion(
              tarea: t,
              empezando: _empezando,
              empezada: _empezada || t.enEjecucion,
              onEmpezar: () => _empezar(t),
              onCerrar: (conforme, resultado, minutos) =>
                  _cerrar(t, conforme, resultado, minutos),
            ),

            // Las fotos cuelgan de la **ejecución**, no de la ocurrencia: la
            // evidencia es de lo que se hizo, no de lo que estaba programado.
            // Por eso no aparecen hasta que la tarea se empieza.
            if (t.EJECUCION_ID != null) ...[
              const SizedBox(height: 12),
              SgEvidencias(
                destino: 'TAREA',
                destinoId: t.EJECUCION_ID!,
                obligatoria: t.tar_requiere_evidencia,
                puedeAgregar: !t.cerrada,
                onCambio: () =>
                    ref.invalidate(tareaProvider(widget.ocurrenciaId)),
              ),
            ],

            const SizedBox(height: 16),
            _Hilo(
              comentarios: t.comentarios,
              onComentar: (cuerpo) => _comentar(cuerpo),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ acciones

  Future<void> _empezar(Tarea t) async {
    setState(() => _empezando = true);
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await SigmaRepository.instance.guardarEjecucionTarea({
        'uuid': _uuid,
        'ocurrencia': t.toc_id,
        'finalizar': false,
        'offline': !SyncService.instance.enLinea.value,
      });
      // El cronómetro arranca con la tarea, no con la pantalla: lo que se
      // quiere medir es el trabajo, y la ficha se abre muchas veces antes.
      await CronometroService.instance.iniciar('TAREA', t.toc_id);

      if (!mounted) return;
      setState(() => _empezada = true);
      ref.invalidate(tareaProvider(widget.ocurrenciaId));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _empezando = false);
    }
  }

  Future<void> _cerrar(
      Tarea t, bool conforme, String resultado, int? minutos) async {
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    // El cronómetro se detiene ANTES de mandar: si sigue corriendo mientras
    // viaja el cierre, el tiempo que suma es el de la red, no el del trabajo.
    final medidos = await CronometroService.instance.detener('TAREA', t.toc_id);

    try {
      await SigmaRepository.instance.guardarEjecucionTarea({
        'uuid': _uuid,
        'ocurrencia': t.toc_id,
        'finalizar': true,
        'conforme': conforme,
        'resultado': resultado.trim().isEmpty ? null : resultado.trim(),
        'minutos': medidos > 0 ? medidos : minutos,
        'offline': !SyncService.instance.enLinea.value,
      });

      // Los tramos ya viajaron dentro del cierre: dejarlos haría que reabrir
      // la ficha mostrara un cronómetro con el tiempo de la tarea anterior.
      await CronometroService.instance.limpiar('TAREA', t.toc_id);

      if (!mounted) return;
      ref.invalidate(tareasPendientesProvider);
      navegador.pop();
      mensajero.showSnackBar(SnackBar(
          content: Text(conforme ? 'Tarea cerrada.' : 'Quedó registrada como no realizada.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _comentar(Map<String, dynamic> cuerpo) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await SigmaRepository.instance.comentarTarea(widget.ocurrenciaId, cuerpo);
      if (!mounted) return;
      ref.invalidate(tareaProvider(widget.ocurrenciaId));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }
}

// ============================================================================

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.tarea});

  final Tarea tarea;

  static final _fecha = DateFormat("d 'de' MMMM, HH:mm", 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final limite = tarea.toc_fecha_limite_utc?.toLocal();

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (tarea.TAREA_CODIGO != null)
                SgBadge(tarea.TAREA_CODIGO!, color: sg.tinta2, chico: true),
              if (tarea.critica)
                SgBadge(tarea.PRIORIDAD_NOMBRE ?? 'Crítica',
                    color: sg.rojoTexto, icono: Icons.priority_high, chico: true),
              if (tarea.cerrada)
                SgBadge(tarea.ESTADO_NOMBRE ?? 'Cerrada',
                    color: tarea.tej_conforme == false
                        ? sg.ambarTexto
                        : sg.verdeTexto,
                    chico: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(tarea.tar_titulo,
              style: sora(20, 600, color: sg.tinta, alto: 1.3)),
          if (tarea.donde.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: sg.tinta3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tarea.donde, style: sora(13, 500, color: sg.tinta2)),
                ),
              ],
            ),
          ],
          if (limite != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: sg.tinta3),
                const SizedBox(width: 6),
                Text('Hasta el ${_fecha.format(limite)}',
                    style: sora(13, 500, color: sg.tinta2)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Las instrucciones. Se muestran enteras y no plegadas: son tres líneas, y
/// una tarea que se hace mal por no haber leído el detalle cuesta más que el
/// espacio que ocupa mostrarlo.
class _ComoSeHace extends StatelessWidget {
  const _ComoSeHace({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SgRotulo('CÓMO SE HACE'),
          const SizedBox(height: 8),
          Text(texto, style: sora(14, 500, color: sg.tinta2, alto: 1.55)),
        ],
      ),
    );
  }
}

// ============================================================================

class _Ejecucion extends StatefulWidget {
  const _Ejecucion({
    required this.tarea,
    required this.empezando,
    required this.empezada,
    required this.onEmpezar,
    required this.onCerrar,
  });

  final Tarea tarea;
  final bool empezando;
  final bool empezada;
  final VoidCallback onEmpezar;
  final void Function(bool conforme, String resultado, int? minutos) onCerrar;

  @override
  State<_Ejecucion> createState() => _EjecucionState();
}

class _EjecucionState extends State<_Ejecucion> {
  final _resultado = TextEditingController();

  /// null = todavía no eligió; true = se hizo; false = no se pudo.
  bool? _conforme;

  @override
  void dispose() {
    _resultado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final t = widget.tarea;

    if (t.cerrada) return _Cerrada(tarea: t);

    if (!widget.empezada) {
      return SgCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cuando llegues al equipo, empieza la tarea.',
                style: sora(14, 500, color: sg.tinta2, alto: 1.5)),
            const SizedBox(height: 6),
            Text('Se registra la hora de inicio para saber cuánto toma de verdad.',
                style: sora(12, 500, color: sg.tinta3, alto: 1.5)),
            const SizedBox(height: 14),
            SgBoton('Empezar tarea',
                icono: Icons.play_arrow,
                cargando: widget.empezando,
                onTap: widget.onEmpezar),
          ],
        ),
      );
    }

    // Ya empezada: hay que decir cómo terminó.
    final faltaMotivo = _conforme == false && _resultado.text.trim().isEmpty;

    // La foto se exige solo cuando la tarea SÍ se hizo: si no se pudo hacer no
    // hay nada que fotografiar, y pedirla igual dejaría a la persona sin forma
    // de cerrar algo que honestamente no ocurrió.
    final faltaFoto = _conforme == true && t.faltaEvidencia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El tiempo va arriba de todo: es lo que se mira MIENTRAS se trabaja.
        // El cierre es lo que se mira al final, y ponerlo primero obligaba a
        // desplazar la pantalla para ver cuánto se lleva.
        SgCronometro(entidad: 'TAREA', entidadId: t.toc_id),
        const SizedBox(height: 12),
        SgCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SgRotulo('¿CÓMO TERMINÓ?'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SgChip('Se hizo',
                        elegido: _conforme == true,
                        icono: Icons.check,
                        onTap: () => setState(() => _conforme = true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SgChip('No se pudo',
                        elegido: _conforme == false,
                        icono: Icons.close,
                        onTap: () => setState(() => _conforme = false)),
                  ),
                ],
              ),
              if (_conforme != null) ...[
                const SizedBox(height: 14),
                SgRotuloCampo(_conforme == false
                    ? '¿Por qué no se pudo?'
                    : 'Observación (opcional)'),
                const SizedBox(height: 7),
                SgCampo(
                  controlador: _resultado,
                  lineas: 3,
                  hint: _conforme == false
                      ? 'La bomba estaba en producción, no se pudo detener…'
                      : 'Todo normal',
                  onCambio: (_) => setState(() {}),
                  sufijo: SgMicrofonoCampo(
                    rotulo: _conforme == false ? 'Motivo' : 'Observación',
                    soloTexto: true,
                    lado: 38,
                    onValor: (v) => setState(() => _resultado.text = v),
                  ),
                ),
                if (faltaMotivo) ...[
                  const SizedBox(height: 10),
                  SgAviso(
                    'Una tarea que no se hizo y no dice por qué es igual a una '
                    'olvidada. Escribe qué pasó, aunque sea corto.',
                    icono: Icons.edit_note,
                    color: sg.ambarTexto,
                    tenido: true,
                  ),
                ],
                if (faltaFoto) ...[
                  const SizedBox(height: 10),
                  SgAviso(
                    'Esta tarea pide una foto. Sácala más arriba y después cierra.',
                    icono: Icons.photo_camera_outlined,
                    color: sg.ambarTexto,
                    tenido: true,
                  ),
                ],
                const SizedBox(height: 14),
                SgBoton(
                  _conforme == false ? 'Registrar como no realizada' : 'Listo',
                  icono: _conforme == false ? Icons.report_outlined : Icons.check,
                  color: _conforme == false ? sg.ambarTexto : null,
                  onTap: (faltaMotivo || faltaFoto)
                      ? null
                      : () => widget.onCerrar(
                          _conforme!, _resultado.text, _minutos(t)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Los minutos que se ven en el teléfono. El servidor los recalcula si no
  /// vienen; mandarlos sirve para el caso sin señal, donde el reloj del envío
  /// no dice nada de cuándo se hizo el trabajo.
  ///
  /// **Manda el cronómetro cuando lo hay**, porque descuenta las pausas: si se
  /// esperó cuarenta minutos una pieza, esos cuarenta no son trabajo y contar
  /// desde la hora de inicio los sumaría. La diferencia contra el reloj queda
  /// de respaldo para la tarea empezada en otro teléfono, donde acá no hay
  /// tramos que leer.
  int? _minutos(Tarea t) {
    final c = CronometroService.instance.estado('TAREA', t.toc_id).value;
    if (c.empezado) return c.minutos;

    final inicio = t.tej_fecha_inicio_utc;
    if (inicio == null) return null;
    final m = DateTime.now().toUtc().difference(inicio).inMinutes;
    return m < 0 ? null : m;
  }
}

class _Cerrada extends StatelessWidget {
  const _Cerrada({required this.tarea});

  final Tarea tarea;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final ok = tarea.tej_conforme != false;
    final color = ok ? sg.verdeTexto : sg.ambarTexto;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SgIconoCuadro(ok ? Icons.check : Icons.report_outlined,
                  color: color, lado: 40, tamanoIcono: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ok ? 'Se hizo' : 'No se pudo hacer',
                        style: sora(15, 600, color: sg.tinta)),
                    if (tarea.tej_duracion_minuto != null)
                      Text('Tomó ${tarea.tej_duracion_minuto} min',
                          style: sora(12, 500, color: sg.tinta3)),
                  ],
                ),
              ),
            ],
          ),
          if ((tarea.tej_resultado ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tarea.tej_resultado!,
                style: sora(14, 500, color: sg.tinta2, alto: 1.5)),
          ],
        ],
      ),
    );
  }
}

// ============================================================================

/// El hilo — HU-104.
///
/// Los comentarios no se editan ni se borran: se responden. La tabla lo dice
/// —no tiene `habilitado` ni auditoría de actualización, y sí tiene comentario
/// padre—, y un hilo que se puede reescribir deja de servir como registro de
/// lo que se dijo y cuándo.
class _Hilo extends StatefulWidget {
  const _Hilo({required this.comentarios, required this.onComentar});

  final List<TareaComentario> comentarios;
  final Future<void> Function(Map<String, dynamic> cuerpo) onComentar;

  @override
  State<_Hilo> createState() => _HiloState();
}

class _HiloState extends State<_Hilo> {
  final _texto = TextEditingController();

  /// Si se dictó: lo crudo que entendió el teléfono, para mandarlo junto al
  /// texto que la persona dio por bueno. Se limpia en cuanto se envía o se
  /// borra el campo: si quedara pegado, un comentario tecleado viajaría con el
  /// dictado del anterior.
  String? _crudo;
  String? _uuidDictado;

  int? _respondiendoA;
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final raiz = widget.comentarios.where((c) => !c.esRespuesta).toList();

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SgRotulo('COMENTARIOS'),
              const Spacer(),
              if (widget.comentarios.isNotEmpty)
                Text('${widget.comentarios.length}',
                    style: sora(12, 600, color: sg.tinta3)),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.comentarios.isEmpty)
            Text('Nadie ha comentado todavía.',
                style: sora(13, 500, color: sg.tinta3))
          else
            for (final c in raiz) ...[
              _Comentario(
                comentario: c,
                onResponder: () => setState(() => _respondiendoA = c.tco_id),
              ),
              for (final r in widget.comentarios.where((x) => x.PADRE_ID == c.tco_id))
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: _Comentario(comentario: r),
                ),
            ],
          const SizedBox(height: 14),
          _Redactor(
            controlador: _texto,
            respondiendo: _respondiendoA != null,
            enviando: _enviando,
            dictado: _crudo != null,
            onCancelarRespuesta: () => setState(() => _respondiendoA = null),
            onDictar: (crudo, limpio) => setState(() {
              _crudo = crudo;
              _uuidDictado = OutboxService.nuevoUuid();
              _texto.text = limpio;
            }),
            onCambio: (v) {
              // Tecleó encima: lo que va a quedar ya no es el dictado tal cual,
              // pero el crudo sigue siendo el mismo audio. Solo se descarta si
              // vació el campo.
              if (v.trim().isEmpty) {
                setState(() {
                  _crudo = null;
                  _uuidDictado = null;
                });
              } else {
                setState(() {});
              }
            },
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);

    await widget.onComentar({
      'texto': texto,
      'padre': ?_respondiendoA,
      'dictado_uuid': ?_uuidDictado,
      'texto_dictado': ?_crudo,
    });

    if (!mounted) return;
    setState(() {
      _texto.clear();
      _crudo = null;
      _uuidDictado = null;
      _respondiendoA = null;
      _enviando = false;
    });
  }
}

class _Comentario extends StatelessWidget {
  const _Comentario({required this.comentario, this.onResponder});

  final TareaComentario comentario;
  final VoidCallback? onResponder;

  static final _cuando = DateFormat('d MMM, HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final quien = comentario.USUARIO_NOMBRE ?? 'Alguien';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SgAvatar(_iniciales(quien), id: comentario.USUARIO_ID, lado: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(quien,
                          style: sora(13, 600, color: sg.tinta),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 7),
                    Text(_cuando.format(comentario.tco_fecha_creacion.toLocal()),
                        style: sora(11, 500, color: sg.tinta3)),
                    if (comentario.POR_VOZ) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.mic, size: 12, color: sg.tinta3),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(comentario.tco_texto,
                    style: sora(14, 500, color: sg.tinta2, alto: 1.5)),
                if (onResponder != null) ...[
                  const SizedBox(height: 5),
                  SgEnlace('Responder', onTap: onResponder!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      return partes.first.characters.take(2).toString().toUpperCase();
    }
    return (partes.first.characters.first + partes[1].characters.first)
        .toUpperCase();
  }
}

class _Redactor extends StatelessWidget {
  const _Redactor({
    required this.controlador,
    required this.respondiendo,
    required this.enviando,
    required this.dictado,
    required this.onCancelarRespuesta,
    required this.onDictar,
    required this.onCambio,
    required this.onEnviar,
  });

  final TextEditingController controlador;
  final bool respondiendo;
  final bool enviando;
  final bool dictado;
  final VoidCallback onCancelarRespuesta;
  final void Function(String crudo, String limpio) onDictar;
  final ValueChanged<String> onCambio;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final hayTexto = controlador.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (respondiendo)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right, size: 15, color: sg.tinta3),
                const SizedBox(width: 6),
                Text('Respondiendo', style: sora(12, 600, color: sg.tinta3)),
                const Spacer(),
                SgEnlace('Cancelar', onTap: onCancelarRespuesta),
              ],
            ),
          ),
        SgCampo(
          controlador: controlador,
          lineas: 2,
          hint: 'Escribe o dicta un comentario…',
          onCambio: onCambio,
          sufijo: _MicroComentario(onDictar: onDictar),
        ),
        if (dictado) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.mic, size: 13, color: sg.tinta3),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Se guarda también lo que entendió el teléfono, para saber '
                  'después si dictar sirve acá.',
                  style: sora(11, 500, color: sg.tinta3, alto: 1.4),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SgBoton(
          respondiendo ? 'Responder' : 'Comentar',
          icono: Icons.send,
          alto: 46,
          tamanoTexto: 14,
          cargando: enviando,
          onTap: hayTexto ? onEnviar : null,
        ),
      ],
    );
  }
}

/// El micrófono del comentario.
///
/// No usa `SgMicrofonoCampo` porque ese devuelve solo el valor limpio, y acá
/// hacen falta **los dos textos**: el crudo que entendió el teléfono y el que
/// la persona dará por bueno. Guardar los dos es lo único que después permite
/// saber si dictar sirve en una sala de máquinas.
class _MicroComentario extends StatelessWidget {
  const _MicroComentario({required this.onDictar});

  final void Function(String crudo, String limpio) onDictar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 38,
      height: 38,
      child: Material(
        color: sg.tinte(sg.primario),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            String? crudo;

            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Comentario',
              interpretar: (t) {
                crudo = t;
                return [
                  CampoDictado(
                      clave: 'texto',
                      rotulo: 'Comentario',
                      valor: InterpreteVoz.normalizar(t)),
                ];
              },
            );

            if (campos == null || campos.isEmpty) return;
            onDictar(crudo ?? campos.first.valor, campos.first.valor);
          },
          child: Icon(Icons.mic, size: 18, color: sg.primarioTexto),
        ),
      ),
    );
  }
}
