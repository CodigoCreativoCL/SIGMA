import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import 'api_client.dart';

/// Las imágenes de activos, repuestos y componentes **no viven en la app**.
///
/// Se suben desde la web y quedan en **Azure Blob Storage**; la app las pide
/// por su `ruta` de blob —`contenedor/cliente/carpeta/nombre`— y nunca las
/// trae empaquetadas. Un catálogo de repuestos con fotos dentro del APK sería
/// un APK que hay que republicar cada vez que alguien cambia una foto.
///
/// ## Cómo se traen, y por qué así
///
/// Hoy la única puerta es `GET /archivo/ver?ruta=…`, que **descarga los bytes
/// a través de la API**. Funciona y respeta el permiso, pero cada foto viaja
/// dos veces: Azure → API → teléfono.
///
/// Lo eficiente es que el teléfono baje **directo de Azure** con una URL
/// firmada de corta vida (SAS por blob, solo lectura). Eso todavía no existe:
/// `BlobService` de la API guarda **un SAS de contenedor** en `Web.config`, y
/// entregárselo al teléfono sería darle la llave de todo el contenedor.
/// Queda anotado en `MD/SIGMA_APP_DATOS_SINCRONIZACION.md` §8.
///
/// Por eso [urlDe] es un punto único: el día que exista `GET /archivo/url`,
/// cambia esta función y **ninguna pantalla se entera**.
///
/// ## Lo que hace que esto sea eficiente hoy
///
///   1. **Caché en disco por ruta.** Una foto se baja una vez por dispositivo.
///      En terreno sin señal, la que ya se vio sigue viéndose.
///   2. **Caché en memoria** de los bytes recién usados, para que hacer scroll
///      en una lista no vuelva a tocar el disco.
///   3. **Deduplicación de peticiones**: dos tarjetas que piden la misma foto
///      al mismo tiempo disparan una sola descarga.
///   4. **Nada se pide hasta que se va a dibujar** — lo resuelve `SigmaImagen`
///      al entrar en pantalla.
class ImagenService {
  ImagenService._();
  static final ImagenService instance = ImagenService._();

  static const _maxEnMemoria = 40;

  final Map<String, Uint8List> _memoria = {};
  final Map<String, Future<Uint8List?>> _enVuelo = {};

  /// Las rutas que el servidor dijo que no existen o que no son de este
  /// cliente (404 y 401/403).
  ///
  /// **No entra la falla de red.** Un 404 no cambia por reintentar y volver a
  /// pedirlo en cada scroll es gastar batería para recibir el mismo no; la
  /// falta de señal, en cambio, se arregla sola al salir de la sala de
  /// máquinas, y ahí la foto tiene que aparecer sin reabrir la pantalla.
  final Set<String> _sinFoto = {};

  Directory? _carpeta;

  /// La URL de la que se baja una imagen.
  ///
  /// **El único lugar** que sabe cómo se sirve un blob. Cuando la API exponga
  /// URLs firmadas, se cambia acá.
  String urlDe(String ruta) =>
      '${ApiConstants.baseUrl}${ApiConstants.archivoVer}'
      '?ruta=${Uri.encodeQueryComponent(ruta)}';

  /// Los bytes de la imagen, del primer lugar donde estén: memoria, disco, red.
  Future<Uint8List?> bytes(String ruta) {
    final enMemoria = _memoria[ruta];
    if (enMemoria != null) return Future.value(enMemoria);

    if (_sinFoto.contains(ruta)) return Future.value(null);

    // Si ya hay una descarga de esta misma ruta, se espera esa.
    final yaVa = _enVuelo[ruta];
    if (yaVa != null) return yaVa;

    final futuro = _resolver(ruta);
    _enVuelo[ruta] = futuro;
    return futuro.whenComplete(() => _enVuelo.remove(ruta));
  }

  Future<Uint8List?> _resolver(String ruta) async {
    final archivo = await _archivoDe(ruta);

    if (archivo != null && await archivo.exists()) {
      try {
        final b = await archivo.readAsBytes();
        _recordar(ruta, b);
        return b;
      } catch (e) {
        debugPrint('[ImagenService] Caché ilegible para $ruta: $e');
      }
    }

    try {
      final r = await http.get(
        Uri.parse(urlDe(ruta)),
        headers: {
          if (ApiClient.instance.token != null)
            HttpHeaders.authorizationHeader: 'Bearer ${ApiClient.instance.token}',
        },
      ).timeout(const Duration(seconds: 20));

      if (r.statusCode != 200 || r.bodyBytes.isEmpty) {
        debugPrint('[ImagenService] $ruta -> ${r.statusCode}');

        // 404: no está. 401/403: no es de este cliente. Ninguno mejora
        // reintentando, y el 401 se veía en cada foto de la app mientras
        // `/archivo/ver` solo aceptaba la clave de servicio.
        if (r.statusCode == 404 || r.statusCode == 401 || r.statusCode == 403) {
          _sinFoto.add(ruta);
        }
        return null;
      }

      _recordar(ruta, r.bodyBytes);
      if (archivo != null) {
        // Sin await: que la pantalla no espere a que el disco termine.
        unawaited(archivo.writeAsBytes(r.bodyBytes).catchError(
              (Object e) {
                debugPrint('[ImagenService] No se pudo cachear $ruta: $e');
                return archivo;
              },
            ));
      }
      return r.bodyBytes;
    } catch (e) {
      // Sin señal. No es un error: es el caso normal en una planta.
      debugPrint('[ImagenService] Sin imagen para $ruta: $e');
      return null;
    }
  }

  void _recordar(String ruta, Uint8List b) {
    if (_memoria.length >= _maxEnMemoria) {
      _memoria.remove(_memoria.keys.first);
    }
    _memoria[ruta] = b;
  }

  Future<File?> _archivoDe(String ruta) async {
    try {
      _carpeta ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/imagenes',
      );
      if (!await _carpeta!.exists()) await _carpeta!.create(recursive: true);

      // La ruta del blob lleva '/' y ':' que no sirven como nombre de archivo.
      final nombre = ruta.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      return File('${_carpeta!.path}/$nombre');
    } catch (e) {
      debugPrint('[ImagenService] Sin carpeta de caché: $e');
      return null;
    }
  }

  /// Al cerrar sesión: las fotos son del cliente, no del teléfono.
  Future<void> limpiar() async {
    _memoria.clear();
    _sinFoto.clear();
    try {
      final c = _carpeta;
      if (c != null && await c.exists()) await c.delete(recursive: true);
    } catch (e) {
      debugPrint('[ImagenService] No se pudo limpiar la caché: $e');
    }
  }
}
