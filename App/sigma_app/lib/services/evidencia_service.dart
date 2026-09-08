import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'outbox_service.dart';

/// Qué clase de evidencia es. Decide el ícono, el tope de peso en el servidor
/// y con qué se abre en el teléfono.
enum ClaseEvidencia { foto, audio, video }

/// Una evidencia capturada en terreno, todavía sin enviar.
///
/// Se sigue llamando `FotoTomada` porque es el nombre que usan las cinco
/// pantallas que la reciben, y renombrarlo tocaría todas para no ganar nada;
/// pero ya no es solo una foto: también una nota de voz o un video.
class FotoTomada {
  const FotoTomada({
    required this.uuid,
    required this.archivo,
    required this.bytes,
    this.ancho,
    this.alto,
    this.clase = ClaseEvidencia.foto,
    this.mime = 'image/jpeg',
    this.segundos,
  });

  /// Generado al **sacar** la foto, no al enviarla. Una foto tomada sin señal
  /// se reintenta varias veces; si el uuid naciera en el envío, la tarea
  /// quedaría con la misma foto cuatro veces y nadie sabría cuál mirar.
  final String uuid;

  final File archivo;
  final int bytes;
  final int? ancho;
  final int? alto;

  final ClaseEvidencia clase;

  /// El mime real. Antes se mandaba `image/jpeg` en duro: para un .m4a eso
  /// significa que el servidor le pone extensión .jpg y después no lo abre
  /// nada.
  final String mime;

  /// Cuánto dura, si es audio o video. Para pintarlo en la miniatura: una nota
  /// de voz sin duración obliga a abrirla para saber si son diez segundos o
  /// tres minutos.
  final int? segundos;

  bool get esFoto => clase == ClaseEvidencia.foto;
}

/// Sacar fotos de evidencia.
///
/// ## Por qué se achica al tomarla y no al enviarla
///
/// Una foto de 12 megapíxeles pesa cuatro megas y no muestra nada que no
/// muestre una de 1600 píxeles de ancho: lo que se fotografía es un filtro
/// sucio o una fuga, no un detalle forense. Achicarla en el momento significa
/// que lo que queda en la cola de salida ya es pequeño —importante, porque esa
/// cola espera en el teléfono hasta que haya señal, a veces horas—.
///
/// ## El audio del DICTADO no se guarda; la nota de voz sí
///
/// Son dos cosas distintas y la diferencia importa. Cuando alguien **dicta**
/// para llenar un campo, la voz se transcribe y se descarta: el texto sirve
/// igual y guardar la grabación sería una carga de privacidad sin uso.
///
/// Una **nota de voz** adjuntada a propósito a una entrada de bitácora o a una
/// tarea es lo contrario: es evidencia, la persona decidió dejarla, y a veces
/// dice lo que un texto no —el ruido del rodamiento, por ejemplo—. Esa se
/// sube y se conserva, igual que la foto.
///
/// El límite es quién decide: el dictado lo descarta la app, la nota la guarda
/// porque se la pidieron.
class EvidenciaService {
  EvidenciaService._();

  static final EvidenciaService instance = EvidenciaService._();

  final ImagePicker _selector = ImagePicker();

  /// 1600 de ancho y calidad 82: un filtro sucio se distingue perfectamente y
  /// el archivo baja de ~4 MB a unos 300 KB.
  static const double _anchoMaximo = 1600;
  static const int _calidad = 82;

  /// Saca una foto con la cámara. Devuelve null si la persona canceló.
  Future<FotoTomada?> tomar() => _obtener(ImageSource.camera);

  /// Elige una de la galería. Existe porque en una sala de máquinas a veces la
  /// foto ya está sacada —con la cámara de la planta, o antes de abrir la
  /// app— y obligar a repetirla es pedirle a alguien que vuelva a subir.
  Future<FotoTomada?> elegir() => _obtener(ImageSource.gallery);

  /// Recupera la foto que Android se quedó a medio camino.
  ///
  /// ## Por qué hace falta
  ///
  /// Mientras la cámara está en primer plano, Android puede **matar la app**
  /// para liberar memoria —un teléfono de terreno con la cámara abierta es
  /// justo cuando más apretado va—. Al volver, la app arranca de nuevo, el
  /// `Future` de `pickImage` que estaba esperando ya no existe y la foto se
  /// pierde: se ve como que se sacó y desapareció del panel.
  ///
  /// No es un caso raro ni un defecto de esta app: `image_picker` lo documenta
  /// y expone `retrieveLostData` justamente para esto. La foto **sí quedó** en
  /// el disco del sistema; lo único que se perdió fue quién la estaba
  /// esperando.
  ///
  /// Devuelve `null` cuando no hay nada que recuperar, que es lo normal.
  Future<FotoTomada?> recuperarPerdida() async {
    try {
      final LostDataResponse perdida = await _selector.retrieveLostData();

      if (perdida.isEmpty) return null;

      final x = perdida.file;
      if (x == null) {
        // Hubo un error del sistema, no una foto a medias.
        debugPrint(
          '[Evidencia] Dato perdido sin archivo: ${perdida.exception}',
        );
        return null;
      }

      final archivo = File(x.path);
      if (!await archivo.exists()) return null;

      return FotoTomada(
        uuid: OutboxService.nuevoUuid(),
        archivo: archivo,
        bytes: await archivo.length(),
      );
    } catch (e) {
      debugPrint('[Evidencia] No se pudo recuperar la foto perdida: $e');
      return null;
    }
  }

  Future<FotoTomada?> _obtener(ImageSource origen) async {
    final XFile? x = await _selector.pickImage(
      source: origen,
      maxWidth: _anchoMaximo,
      imageQuality: _calidad,
    );

    if (x == null) return null;

    final archivo = File(x.path);
    final bytes = await archivo.length();

    return FotoTomada(
      uuid: OutboxService.nuevoUuid(),
      archivo: archivo,
      bytes: bytes,
    );
  }

  /// Graba un video con la cámara.
  ///
  /// Un minuto de tope: no es un documental, es «mira cómo suena esto girando».
  /// Y el tope del servidor son 48 MB, que un video largo pasa sin esfuerzo.
  Future<FotoTomada?> grabarVideo() => _video(ImageSource.camera);

  /// Elige un video de la galería.
  Future<FotoTomada?> elegirVideo() => _video(ImageSource.gallery);

  Future<FotoTomada?> _video(ImageSource origen) async {
    final XFile? x = await _selector.pickVideo(
      source: origen,
      maxDuration: const Duration(minutes: 1),
    );

    if (x == null) return null;

    final archivo = File(x.path);

    return FotoTomada(
      uuid: OutboxService.nuevoUuid(),
      archivo: archivo,
      bytes: await archivo.length(),
      clase: ClaseEvidencia.video,
      // Lo que graban Android y iOS por omisión. La galería puede traer otra
      // cosa, y para eso está el mapa de extensiones del servidor.
      mime: x.path.toLowerCase().endsWith('.mov') ? 'video/quicktime' : 'video/mp4',
    );
  }

  /// El cuerpo que espera `POST /evidencias`.
  ///
  /// Va en base64 y no como multipart porque la cola de salida guarda cuerpos
  /// JSON en SQLite: un multipart no se puede encolar sin inventarle un
  /// almacenamiento aparte, y una foto que no se puede encolar es una foto que
  /// se pierde cuando no hay señal.
  Future<Map<String, dynamic>> cuerpo(
    FotoTomada foto, {
    required String destino,
    required int destinoId,
    int categoria = 5, // 5 = DURANTE
    String? titulo,
    String? dispositivo,
  }) async {
    final datos = await foto.archivo.readAsBytes();

    return {
      'uuid': foto.uuid,
      'destino': destino,
      'destino_id': destinoId,
      'categoria': categoria,
      'nombre': foto.archivo.uri.pathSegments.last,
      // El mime REAL. En duro era 'image/jpeg', asi que un .m4a llegaba al
      // servidor como foto, se guardaba con extension .jpg y no lo abria nada.
      'mime': foto.mime,
      'contenido_base64': base64Encode(datos),
      'captura_utc': DateTime.now().toUtc().toIso8601String(),
      'titulo': ?titulo,
      'dispositivo': ?dispositivo,
    };
  }
}
