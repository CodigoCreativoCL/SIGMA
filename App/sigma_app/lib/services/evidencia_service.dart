import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'outbox_service.dart';

/// Una foto sacada en terreno, todavía sin enviar.
class FotoTomada {
  const FotoTomada({
    required this.uuid,
    required this.archivo,
    required this.bytes,
    this.ancho,
    this.alto,
  });

  /// Generado al **sacar** la foto, no al enviarla. Una foto tomada sin señal
  /// se reintenta varias veces; si el uuid naciera en el envío, la tarea
  /// quedaría con la misma foto cuatro veces y nadie sabría cuál mirar.
  final String uuid;

  final File archivo;
  final int bytes;
  final int? ancho;
  final int? alto;
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
/// ## El audio no se guarda, la foto sí
///
/// Son cosas distintas y conviene decirlo: la voz se transcribe y se descarta
/// porque el texto sirve igual y grabar a la gente trabajando es una carga de
/// privacidad innecesaria. La foto **es** la evidencia; sin ella no queda nada
/// que mirar después.
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
        debugPrint('[Evidencia] Dato perdido sin archivo: ${perdida.exception}');
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
      'mime': 'image/jpeg',
      'contenido_base64': base64Encode(datos),
      'captura_utc': DateTime.now().toUtc().toIso8601String(),
      'titulo': ?titulo,
      'dispositivo': ?dispositivo,
    };
  }
}
