import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_client.dart';
import '../../services/imagen_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_v3.dart';

/// Escuchar una nota de voz o ver un video de evidencia.
///
/// ## Por qué se transmite y no se descarga primero
///
/// Un video de treinta segundos son veinte megas. Bajarlo entero antes de
/// mostrar nada deja a la persona mirando una rueda con la pieza en la mano;
/// transmitido, empieza a los dos segundos. Los dos reproductores aceptan
/// cabeceras, así que el blob se pide con el mismo token que todo lo demás —
/// `/archivo/ver` valida que la ruta sea del cliente del token, y esa
/// comprobación no se puede saltar.
///
/// ## Por qué no se usa `chewie` ni un paquete de controles
///
/// Los controles que hacen falta son dos: reproducir/pausar y una barra que
/// diga por dónde va. Un paquete de controles trae pantalla completa,
/// velocidad, subtítulos y su propio tema, y lo primero que habría que hacer
/// es apagar la mitad y repintar la otra.
///
/// ## Por qué la nota de voz muestra el tiempo y no una onda
///
/// La forma de onda se ve bien y no dice nada útil: para saber si vale la pena
/// escuchar los cincuenta segundos, lo que sirve es saber que son cincuenta.
class SgReproductor extends StatelessWidget {
  const SgReproductor._({
    required this.ruta,
    required this.esVideo,
    this.titulo,
  });

  final String ruta;
  final bool esVideo;
  final String? titulo;

  /// Abre el reproductor que corresponda al [mime].
  ///
  /// Devuelve `false` si el archivo no es audio ni video, para que quien llama
  /// decida qué hacer en vez de abrir una pantalla vacía.
  static Future<bool> abrir(
    BuildContext context, {
    required String ruta,
    required String? mime,
    String? titulo,
  }) async {
    final m = (mime ?? '').toLowerCase();
    final esVideo = m.startsWith('video/');
    final esAudio = m.startsWith('audio/');

    if (!esVideo && !esAudio) return false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SgReproductor._(ruta: ruta, esVideo: esVideo, titulo: titulo),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      decoration: BoxDecoration(
        color: sg.fondo,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SgRadius.hoja),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: sg.div,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if ((titulo ?? '').isNotEmpty) ...[
            Text(titulo!, style: sora(15, 600, color: sg.tinta)),
            const SizedBox(height: 14),
          ],
          esVideo ? _Video(ruta: ruta) : _Audio(ruta: ruta),
        ],
      ),
    );
  }
}

/// Las cabeceras con que se pide un blob. El token es el mismo de la sesión.
Map<String, String> _cabeceras() => {
  if (ApiClient.instance.token != null)
    HttpHeaders.authorizationHeader: 'Bearer ${ApiClient.instance.token}',
};

class _Audio extends StatefulWidget {
  const _Audio({required this.ruta});
  final String ruta;

  @override
  State<_Audio> createState() => _AudioState();
}

class _AudioState extends State<_Audio> {
  final _reproductor = AudioPlayer();
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _reproductor.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      await _reproductor.setAudioSource(
        AudioSource.uri(
          Uri.parse(ImagenService.instance.urlDe(widget.ruta)),
          headers: _cabeceras(),
        ),
      );
      // Arranca solo: quien abre una nota de voz quiere oírla, y un botón de
      // play de más es un toque que no aporta.
      await _reproductor.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _reloj(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    if (_error != null) {
      return SgAviso(
        'No se pudo reproducir la nota de voz.',
        icono: Icons.error_outline,
        color: sg.rojoTexto,
      );
    }

    return StreamBuilder<Duration>(
      stream: _reproductor.positionStream,
      builder: (_, snap) {
        final va = snap.data ?? Duration.zero;
        final total = _reproductor.duration ?? Duration.zero;
        final avance = total.inMilliseconds == 0
            ? 0.0
            : (va.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _reproductor.playerStateStream,
                  builder: (_, e) {
                    final sonando = e.data?.playing ?? false;
                    final terminado =
                        e.data?.processingState == ProcessingState.completed;

                    return SgBotonIcono(
                      terminado
                          ? Icons.replay
                          : sonando
                          ? Icons.pause
                          : Icons.play_arrow,
                      fondo: sg.tinte(sg.primario),
                      color: sg.primarioTexto,
                      lado: 52,
                      tamano: 26,
                      onTap: () async {
                        if (terminado) {
                          await _reproductor.seek(Duration.zero);
                          await _reproductor.play();
                        } else if (sonando) {
                          await _reproductor.pause();
                        } else {
                          await _reproductor.play();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: avance,
                          minHeight: 5,
                          backgroundColor: sg.up,
                          valueColor: AlwaysStoppedAnimation(sg.primario),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _reloj(va),
                            style: sora(
                              12,
                              600,
                              color: sg.tinta2,
                              tabular: true,
                            ),
                          ),
                          Text(
                            _reloj(total),
                            style: sora(
                              12,
                              500,
                              color: sg.tinta3,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Video extends StatefulWidget {
  const _Video({required this.ruta});
  final String ruta;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  VideoPlayerController? _control;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _control?.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(ImagenService.instance.urlDe(widget.ruta)),
        httpHeaders: _cabeceras(),
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _control = c);
      await c.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    if (_error != null) {
      return SgAviso(
        'No se pudo reproducir el video.',
        icono: Icons.error_outline,
        color: sg.rojoTexto,
      );
    }

    final c = _control;

    if (c == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(SgRadius.card),
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                // El toque sobre el video pausa y sigue: es el gesto que todo
                // el mundo ya conoce, y evita un botón encima de la imagen.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(
                      () => c.value.isPlaying ? c.pause() : c.play(),
                    ),
                  ),
                ),
                if (!c.value.isPlaying)
                  const IgnorePointer(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 58,
                      color: Color(0xCCF8FAFC),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: sg.primario,
            bufferedColor: sg.up,
            backgroundColor: sg.up,
          ),
        ),
      ],
    );
  }
}
