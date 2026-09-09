import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/evidencia_service.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_imagen.dart';
import 'sigma_v3.dart';
import 'dart:async';
import '../../services/nota_voz_service.dart';
import 'sigma_reproductor.dart';

/// Las fotos de evidencia de algo.
///
/// Sirve para cualquier destino —tarea, orden, paso, respuesta de pauta,
/// hallazgo— porque `Archivo_Vinculo` es polimórfica a propósito: el modelo ya
/// decidió que la evidencia es una sola idea con muchos dueños, y un widget
/// por pantalla sería repetir seis veces la misma cuadrícula.
///
/// ## Lo que se ve mientras sube
///
/// La foto aparece en la tira **apenas se saca**, con su indicador encima, y
/// no cuando el servidor responde. En terreno la respuesta puede tardar o no
/// llegar, y una tira que se queda vacía después de apretar el obturador hace
/// que la persona vuelva a sacar la misma foto.
class SgEvidencias extends ConsumerStatefulWidget {
  const SgEvidencias({
    super.key,
    required this.destino,
    required this.destinoId,
    this.conAudio = false,
    this.conVideo = false,
    this.obligatoria = false,
    this.puedeAgregar = true,
    this.onCambio,
  });

  /// TAREA · ORDEN · PASO · RESPUESTA · FALLA · HALLAZGO · ACTIVO
  final String destino;

  final int destinoId;

  /// Ofrece grabar una nota de voz.
  ///
  /// No se enciende en todas partes: en un paso de checklist lo que hace falta
  /// es la foto del estado, y un botón de más obliga a decidir algo que no
  /// aporta. Se enciende donde alguien relata —bitácora y tarea—, que es donde
  /// el ruido de un rodamiento dice lo que el texto no.
  final bool conAudio;

  /// Ofrece grabar o adjuntar un video. Mismo criterio.
  final bool conVideo;

  /// Solo cambia el texto de ayuda. **El veredicto lo pone el servidor**: un
  /// teléfono con la versión vieja cerraría sin foto en silencio si esto fuera
  /// la única comprobación.
  final bool obligatoria;

  final bool puedeAgregar;
  final VoidCallback? onCambio;

  @override
  ConsumerState<SgEvidencias> createState() => _SgEvidenciasState();
}

class _SgEvidenciasState extends ConsumerState<SgEvidencias>
    with WidgetsBindingObserver {
  /// Las que están viajando ahora. Se muestran junto a las guardadas para que
  /// la tira no parpadee ni se vacíe entre el obturador y la respuesta.
  final List<FotoTomada> _subiendo = [];

  /// Las que esperan señal en la cola de salida. Se siguen viendo en la tira:
  /// una foto que se saca y desaparece de la pantalla se lee como que no se
  /// guardó, y el técnico la vuelve a sacar.
  final List<FotoTomada> _enCola = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // También al montar: si la app murió con la cámara abierta, vuelve por
    // este camino y no por el de `resumed`.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recuperarPerdida());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _recuperarPerdida();
  }

  /// La foto que Android se quedó a medio camino.
  ///
  /// Mientras la cámara está en primer plano el sistema puede **matar la app**
  /// para liberar memoria. Al volver, el `Future` que esperaba la foto ya no
  /// existe y se veía como que la foto se sacó y desapareció del panel — que
  /// es exactamente lo que se reportó desde terreno.
  ///
  /// La foto sí quedó en disco: lo único que se perdió fue quién la esperaba.
  Future<void> _recuperarPerdida() async {
    final foto = await EvidenciaService.instance.recuperarPerdida();
    if (foto == null || !mounted) return;

    await _subir(foto);
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final clave = (widget.destino, widget.destinoId);
    final guardadas = ref.watch(evidenciasProvider(clave));

    final fotos = guardadas.valueOrNull ?? const <Evidencia>[];
    final vacio = fotos.isEmpty && _subiendo.isEmpty && _enCola.isEmpty;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgRotulo(
                widget.obligatoria
                    ? 'FOTO OBLIGATORIA'
                    : (widget.conAudio || widget.conVideo)
                    ? 'EVIDENCIA'
                    : 'FOTOS',
              ),
              const Spacer(),
              if (!vacio)
                Text(
                  '${fotos.length + _subiendo.length + _enCola.length}',
                  style: sora(12, 600, color: sg.tinta3),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (vacio)
            Text(
              widget.obligatoria
                  ? 'Esta tarea pide una foto antes de cerrarla.'
                  : 'Una foto ahorra tener que explicar después qué se encontró.',
              style: sora(
                13,
                500,
                color: widget.obligatoria ? sg.ambarTexto : sg.tinta3,
                alto: 1.45,
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length + _subiendo.length + _enCola.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, i) {
                  if (i < fotos.length) {
                    return _Miniatura(evidencia: fotos[i]);
                  }
                  final j = i - fotos.length;
                  return j < _subiendo.length
                      ? _Subiendo(foto: _subiendo[j])
                      : _EnCola(foto: _enCola[j - _subiendo.length]);
                },
              ),
            ),

          if (widget.puedeAgregar) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: SgBoton(
                    'Sacar foto',
                    icono: Icons.photo_camera_outlined,
                    alto: 44,
                    tamanoTexto: 14,
                    onTap: () => _agregar(desdeCamara: true),
                  ),
                ),
                const SizedBox(width: 9),
                SgBotonIcono(
                  Icons.photo_library_outlined,
                  lado: 44,
                  onTap: () => _agregar(desdeCamara: false),
                ),
                if (widget.conVideo) ...[
                  const SizedBox(width: 9),
                  SgBotonIcono(
                    Icons.videocam_outlined,
                    lado: 44,
                    onTap: _grabarVideo,
                  ),
                ],
              ],
            ),
            /* LA NOTA DE VOZ VA EN SU PROPIA FILA

               Mientras se graba hay que ver cuánto va y poder cortar, y eso no
               cabe en un botón de 44 al lado de otros tres. */
            if (widget.conAudio) ...[
              const SizedBox(height: 9),
              _BotonNotaVoz(onGrabada: _subir),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _grabarVideo() async {
    final video = await EvidenciaService.instance.grabarVideo();
    if (video == null || !mounted) return;
    await _subir(video);
  }

  Future<void> _agregar({required bool desdeCamara}) async {
    final servicio = EvidenciaService.instance;

    final foto = desdeCamara ? await servicio.tomar() : await servicio.elegir();
    if (foto == null || !mounted) return;

    await _subir(foto);
  }

  /// Sube la foto, o la encola si no hay señal.
  ///
  /// Está separado de [_agregar] porque hay **dos formas de llegar acá**: la
  /// normal —se sacó la foto y el `Future` volvió— y la recuperada, cuando
  /// Android mató la app con la cámara abierta. Las dos terminan igual, y
  /// duplicar este camino sería duplicar también el encolado sin señal.
  Future<void> _subir(FotoTomada foto) async {
    final mensajero = ScaffoldMessenger.of(context);
    final servicio = EvidenciaService.instance;

    setState(() => _subiendo.add(foto));

    final cuerpo = await servicio.cuerpo(
      foto,
      destino: widget.destino,
      destinoId: widget.destinoId,
    );

    try {
      await SigmaRepository.instance.subirEvidencia(cuerpo);

      if (!mounted) return;
      setState(() => _subiendo.remove(foto));
      ref.invalidate(evidenciasProvider((widget.destino, widget.destinoId)));
      widget.onCambio?.call();
    } on ApiException catch (e) {
      if (!mounted) return;

      /* SIN SEÑAL LA FOTO NO SE PIERDE: SE ENCOLA

         Antes se mostraba «Sin conexión al servidor» y la foto se descartaba.
         En una sala de máquinas eso es el caso NORMAL, no el excepcional, y
         significaba pedirle al técnico que volviera a bajar a sacarla.

         El cuerpo ya viaja en base64 justamente para esto —lo dice
         `EvidenciaService`: un multipart no se puede encolar—, y la foto lleva
         su `uuid` desde que se saca, asi que el reintento no la duplica.

         Solo la falla de RED se encola. Un 403 —no tienes permiso sobre este
         destino— no mejora reintentando, y guardarlo en la cola seria dejar
         algo que va a fallar para siempre. */
      if (!e.esDeRed) {
        setState(() => _subiendo.remove(foto));
        mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
        return;
      }

      await OutboxService.instance.encolar(
        tipo: 'EVIDENCIA',
        titulo: 'Foto de ${widget.destino.toLowerCase()}',
        detalle: '${(foto.bytes / 1024).round()} KB',
        endpoint: ApiConstants.evidencias,
        cuerpo: cuerpo,
        uuid: foto.uuid,
      );

      if (!mounted) return;
      setState(() {
        _subiendo.remove(foto);
        _enCola.add(foto);
      });
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Sin señal: la foto queda guardada y se envía sola.'),
        ),
      );
    }
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.evidencia});

  final Evidencia evidencia;

  @override
  Widget build(BuildContext context) {
    final mime = (evidencia.arc_mime ?? '').toLowerCase();

    /* UN AUDIO NO SE PUEDE PINTAR

       `SigmaImagen` baja los bytes y los decodifica como imagen: con un .m4a
       eso es un hueco roto en la fila. Una nota de voz se representa con lo
       unico que se puede saber de ella sin abrirla —que es audio— y por eso
       importa que el servidor guarde el mime de verdad. */
    if (mime.startsWith('audio/') || mime.startsWith('video/')) {
      final esVideo = mime.startsWith('video/');

      return _Tarjeta(
        icono: esVideo ? Icons.play_circle_outline : Icons.graphic_eq,
        texto: esVideo ? 'Video' : 'Nota de voz',
        // Se toca y suena. Antes era una tarjeta muerta: decia que habia una
        // nota de voz y no habia forma de escucharla, que es peor que no
        // mostrarla.
        onTap: () => SgReproductor.abrir(
          context,
          ruta: evidencia.arc_ruta,
          mime: evidencia.arc_mime,
          titulo: evidencia.arc_nombre_original,
        ),
      );
    }

    return SizedBox(
      width: 92,
      height: 92,
      child: SigmaImagen(
        ruta: evidencia.arc_ruta,
        ancho: 92,
        alto: 92,
        radio: SgRadius.campo,
      ),
    );
  }
}

/// La casilla de una evidencia que no es una imagen.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.icono, required this.texto, this.onTap});

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: sg.campo,
          borderRadius: BorderRadius.circular(SgRadius.campo),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 26, color: sg.tinta2),
            const SizedBox(height: 6),
            Text(texto, style: sora(11, 600, color: sg.tinta3)),
            if (onTap != null) ...[
              const SizedBox(height: 3),
              Text('tocar', style: sora(9, 600, color: sg.tinta3)),
            ],
          ],
        ),
      ),
    );
  }
}

/// La que todavía va en camino: se ve la foto real del teléfono con un velo y
/// el indicador encima. Mostrar un recuadro gris en su lugar haría dudar de si
/// se sacó la que se quería.
/// Una foto que ya está en el teléfono y espera señal para salir.
///
/// Se ve **la foto**, no un marcador: lo que hay que poder comprobar en
/// terreno es que la foto salió bien, y eso no se puede con un ícono. El
/// distintivo de la esquina dice que todavía no llegó al servidor, sin
/// pintarla de rojo: quedarse sin señal no es un error de quien la sacó.
class _EnCola extends StatelessWidget {
  const _EnCola({required this.foto});

  final FotoTomada foto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SgRadius.campo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(foto.archivo.path), fit: BoxFit.cover),
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sg.scrim,
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 12, color: sg.tinta2),
                    const SizedBox(width: 4),
                    Text('En cola', style: sora(10, 600, color: sg.tinta2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Subiendo extends StatelessWidget {
  const _Subiendo({required this.foto});

  final FotoTomada foto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SgRadius.campo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(foto.archivo.path), fit: BoxFit.cover),
            Container(color: sg.scrim),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: sg.primarioTexto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grabar una nota de voz, con el tiempo a la vista y sin sorpresas.
///
/// ## Por qué se ve el tiempo mientras graba
///
/// Sin contador nadie sabe si el micrófono está tomando algo. La duda hace que
/// se grabe dos veces «por si acaso», y en la cola de salida quedan dos notas
/// de las que hay que escuchar las dos para saber cuál sirve.
///
/// ## Por qué cancelar está al lado de detener
///
/// Detener sube la nota; cancelar la tira. Con guantes y a contraluz eso hay
/// que poder distinguirlo, así que uno lleva el color de acción y el otro no,
/// y el que destruye no es el que queda bajo el pulgar por omisión.
class _BotonNotaVoz extends StatefulWidget {
  const _BotonNotaVoz({required this.onGrabada});

  final Future<void> Function(FotoTomada) onGrabada;

  @override
  State<_BotonNotaVoz> createState() => _BotonNotaVozState();
}

class _BotonNotaVozState extends State<_BotonNotaVoz> {
  Timer? _reloj;
  Duration _va = Duration.zero;
  bool _ocupado = false;

  bool get _grabando => _reloj != null;

  @override
  void dispose() {
    _reloj?.cancel();
    // No se cancela la grabación acá: si la pantalla se cerró mientras grababa,
    // `NotaVozService` es un singleton y la próxima llamada a iniciar() la
    // reemplaza. Cortarla desde un dispose puede correr después de que el
    // servicio ya empezó otra.
    super.dispose();
  }

  String get _tiempo {
    final m = _va.inMinutes.toString().padLeft(2, '0');
    final s = (_va.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _empezar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);

    final ok = await NotaVozService.instance.iniciar();

    if (!mounted) return;

    if (!ok) {
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SIGMA necesita permiso del micrófono para grabar una nota. '
            'Se cambia en los ajustes del teléfono.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _ocupado = false;
      _va = Duration.zero;
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _va = NotaVozService.instance.transcurrido);
      });
    });
  }

  Future<void> _detener() async {
    _reloj?.cancel();
    setState(() {
      _reloj = null;
      _ocupado = true;
    });

    final nota = await NotaVozService.instance.detener();

    if (!mounted) return;
    setState(() => _ocupado = false);

    if (nota == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No quedó nada grabado.')));
      return;
    }

    await widget.onGrabada(nota);
  }

  Future<void> _cancelar() async {
    _reloj?.cancel();
    setState(() => _reloj = null);
    await NotaVozService.instance.cancelar();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    if (!_grabando) {
      return SgBoton(
        'Grabar nota de voz',
        icono: Icons.mic_none,
        primario: false,
        alto: 44,
        tamanoTexto: 14,
        cargando: _ocupado,
        onTap: _empezar,
      );
    }

    return Row(
      children: [
        // El punto rojo y el contador: la única forma de saber que el micrófono
        // está tomando algo.
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: SgColor.rojo,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Text(_tiempo, style: sora(15, 700, color: sg.tinta, tabular: true)),
        const Spacer(),
        SgBotonIcono(Icons.close, lado: 40, onTap: _cancelar),
        const SizedBox(width: 8),
        // 108 de ancho: cabe «Listo» con su icono y no se estira a media
        // pantalla, que dejaria el cancelar perdido a la izquierda.
        SizedBox(
          width: 108,
          child: SgBoton(
            'Listo',
            icono: Icons.check,
            alto: 40,
            tamanoTexto: 14,
            cargando: _ocupado,
            onTap: _detener,
          ),
        ),
      ],
    );
  }
}
