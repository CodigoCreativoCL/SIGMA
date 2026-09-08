import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'evidencia_service.dart';
import 'outbox_service.dart';

/// Grabar una nota de voz para adjuntarla a una entrada o a una tarea.
///
/// ## Por qué existe, si ya hay dictado
///
/// El dictado convierte voz en texto y **descarta el audio**: para llenar un
/// campo eso es lo correcto, y guardar la grabación sería una carga de
/// privacidad sin uso.
///
/// Una nota de voz es otra cosa. La persona la adjunta a propósito porque hay
/// algo que el texto no lleva: el ruido de un rodamiento, un golpeteo, el tono
/// de un motor forzado. «Se escucha un roce metálico» escrito no sirve para
/// comparar con la semana siguiente; treinta segundos de audio sí.
///
/// ## Por qué m4a y no wav
///
/// Un wav de un minuto pesa unos diez megas y un m4a a 64 kbps pesa medio. Eso
/// que espera en la cola de salida del teléfono, a veces horas, hasta que hay
/// señal. Para voz, AAC a 64 kbps se entiende perfectamente: no es música.
///
/// ## Por qué el archivo vive en la caché y no en documentos
///
/// Una vez enviado no hace falta: la evidencia queda en el Blob Storage, y la
/// copia local solo tiene que sobrevivir hasta que el outbox la despache. En la
/// caché el sistema puede recuperar el espacio si aprieta, que es lo correcto
/// para un archivo temporal.
class NotaVozService {
  NotaVozService._();

  static final NotaVozService instance = NotaVozService._();

  final AudioRecorder _grabador = AudioRecorder();

  DateTime? _comenzo;
  String? _ruta;

  bool get grabando => _comenzo != null;

  /// Cuánto lleva grabando. Cero si no está grabando.
  Duration get transcurrido =>
      _comenzo == null ? Duration.zero : DateTime.now().difference(_comenzo!);

  /// ¿Dio permiso el micrófono?
  ///
  /// Se pregunta antes de mostrar el botón de grabar, no al apretarlo: ofrecer
  /// algo que va a fallar es peor que no ofrecerlo.
  Future<bool> puede() async {
    try {
      return await _grabador.hasPermission();
    } catch (e) {
      debugPrint('[NotaVoz] No se pudo consultar el permiso: $e');
      return false;
    }
  }

  /// Empieza a grabar. Devuelve `false` si no se pudo.
  Future<bool> iniciar() async {
    if (grabando) return true;

    try {
      if (!await _grabador.hasPermission()) return false;

      final dir = await getTemporaryDirectory();
      final ruta = '${dir.path}/nota_${OutboxService.nuevoUuid()}.m4a';

      await _grabador.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          // 22 kHz alcanza de sobra para voz y para un ruido mecánico; 44 kHz
          // duplicaría el peso sin que se distinga nada más.
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: ruta,
      );

      _ruta = ruta;
      _comenzo = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('[NotaVoz] No se pudo iniciar la grabación: $e');
      await _limpiar();
      return false;
    }
  }

  /// Cierra la grabación y devuelve la nota, o null si no quedó nada usable.
  Future<FotoTomada?> detener() async {
    if (!grabando) return null;

    final segundos = transcurrido.inSeconds;

    try {
      final ruta = await _grabador.stop() ?? _ruta;
      _comenzo = null;
      _ruta = null;

      if (ruta == null) return null;

      final archivo = File(ruta);
      if (!await archivo.exists()) return null;

      final bytes = await archivo.length();

      /* UN ARCHIVO DE CERO BYTES NO SE SUBE

         Pasa cuando alguien toca grabar y suelta al instante, o cuando el
         sistema corta la grabación. Subirlo dejaría una nota de voz que no se
         puede escuchar colgada de la entrada, y nadie sabría si es un fallo o
         si el audio estaba en silencio. */
      if (bytes < 512) {
        await _borrar(archivo);
        return null;
      }

      return FotoTomada(
        uuid: OutboxService.nuevoUuid(),
        archivo: archivo,
        bytes: bytes,
        clase: ClaseEvidencia.audio,
        mime: 'audio/m4a',
        segundos: segundos,
      );
    } catch (e) {
      debugPrint('[NotaVoz] No se pudo cerrar la grabación: $e');
      await _limpiar();
      return null;
    }
  }

  /// Corta y tira lo grabado. Para cuando la persona cancela.
  Future<void> cancelar() async {
    if (!grabando) return;

    final ruta = _ruta;

    try {
      await _grabador.stop();
    } catch (e) {
      debugPrint('[NotaVoz] No se pudo detener al cancelar: $e');
    }

    _comenzo = null;
    _ruta = null;

    if (ruta != null) await _borrar(File(ruta));
  }

  Future<void> _limpiar() async {
    final ruta = _ruta;
    _comenzo = null;
    _ruta = null;
    if (ruta != null) await _borrar(File(ruta));
  }

  Future<void> _borrar(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      // Un temporal que no se pudo borrar no es motivo para nada: lo recoge el
      // sistema cuando necesite el espacio.
      debugPrint('[NotaVoz] No se pudo borrar el temporal: $e');
    }
  }
}
