import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Un error de la API, con su código y **el mensaje que dio el servidor**.
///
/// La API de SIGMA responde `{ codigo, mensaje, esDeNegocio }` y usa códigos
/// HTTP reales: el `RAISERROR` del SP lo traduce `Utils/ErrorSql.cs`. Este
/// cliente NO reescribe esos mensajes — están redactados para leerse.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.codigo, this.esDeNegocio = true});

  final String mensaje;
  final int? codigo;
  final bool esDeNegocio;

  /// Sin red, sin host, timeout. Se reintenta; nunca se descarta el trabajo.
  bool get esDeRed => codigo == null;

  /// 401: el token no sirve. La app renueva sesión.
  bool get sesionInvalida => codigo == 401;

  /// 403: el token está bien; quien lo trae, no.
  ///
  /// **Nunca cierra sesión.** Reintentar con otro login no cambia nada, y
  /// hacerlo le hace perder al técnico el trabajo en curso.
  bool get sinPermiso => codigo == 403;

  /// 402: la suscripción del cliente no está vigente (HU-193).
  bool get suscripcionVencida => codigo == 402;

  /// 423: cuenta bloqueada por intentos fallidos.
  bool get cuentaBloqueada => codigo == 423;

  /// 409: el servidor ya tenía este registro. Con `uuid`, es el reintento
  /// que llegó dos veces: se trata como enviado, no como error.
  bool get duplicado => codigo == 409;

  /// El token es válido pero **no lleva cliente**, así que casi todo endpoint
  /// responde 400 «No hay cliente seleccionado».
  ///
  /// Es un estado de la sesión, no un fallo: se arregla eligiendo cliente, no
  /// reintentando ni volviendo a entrar. Mostrarlo como un error cualquiera
  /// dejaba a la persona mirando «400» en cada pantalla sin saber qué hacer.
  bool get faltaCliente =>
      codigo == 400 && mensaje.toLowerCase().contains('cliente seleccionado');

  @override
  String toString() => 'ApiException($codigo): $mensaje';
}

/// El único que habla HTTP.
///
/// Hace cuatro cosas y ninguna más: adjunta el token, serializa, aplica el
/// timeout y traduce el código a una excepción tipada. Qué hacer con un 403
/// —mostrarlo, esconder un botón, encolar— es de las capas de arriba.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// El JWT de la sesión. Lo pone `SesionService`; nadie más lo escribe.
  String? token;

  /// El cliente que lleva **ese** token. Lo pone `SesionService` junto con él.
  ///
  /// Se guarda acá, y no se consulta a `SesionService`, para no invertir la
  /// dependencia: el servicio de sesión usa este cliente HTTP, y al revés
  /// serían dos archivos importándose entre sí.
  int cliente = 0;

  /// Los endpoints que **no** necesitan cliente en contexto.
  ///
  /// Son los de entrar y los de elegir a quién se entra. Todo lo demás está
  /// acotado por cliente en el SP y responde 400 sin él.
  static const _sinCliente = <String>[
    '/sesion',
    '/cliente-usuarios',
    '/usuario-recuperaciones',
    '/mi-perfil',
  ];

  /// **Un solo cliente HTTP para toda la app**, y no uno por petición.
  ///
  /// Las funciones sueltas de `package:http` —`http.get(...)`— crean un
  /// cliente, lo usan y lo cierran. Eso significa **una conexión TCP nueva
  /// por cada llamada**: sin `keep-alive`, sin reutilizar nada. Una pantalla
  /// que observa seis providers abría seis conexiones simultáneas al mismo
  /// servidor, y con IIS al otro lado —o un wifi de planta— una de las seis
  /// se cae y la pantalla dice «Sin conexión al servidor» mientras las otras
  /// cinco cargaron bien. Es exactamente el fallo intermitente que se veía.
  ///
  /// Con un cliente compartido las peticiones viajan por la misma conexión
  /// reutilizada: menos handshakes, menos latencia y muchísimo menos margen
  /// para que una de ellas falle sola.
  final http.Client _cliente = http.Client();

  void limpiarToken() => token = null;

  /// Al cerrar la app. No se llama al cerrar sesión: el cliente no guarda
  /// nada de la persona, solo conexiones.
  void cerrar() => _cliente.close();

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.acceptHeader: 'application/json',
        // "Bearer" es el estándar. La API acepta además "Base" por herencia
        // de FacilityGes, pero acá se usa el correcto.
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      };

  /// Las lecturas se reintentan una vez ante un fallo de red.
  ///
  /// Un GET no cambia nada en el servidor, así que repetirlo es gratis. Y el
  /// fallo que se veía en planta —una conexión que se cae, un wifi que salta
  /// de punto de acceso— se arregla solo al segundo intento; sin reintento,
  /// esa pantalla se quedaba en «Sin conexión al servidor» hasta que la
  /// persona la recargaba a mano.
  ///
  /// **Solo GET.** Reintentar un POST duplicaría un movimiento de bodega: para
  /// las escrituras existe la cola, con su `uuid` y su 409 tratado como éxito.
  Future<dynamic> get(String ruta, {Map<String, dynamic>? query}) async {
    try {
      return await _enviar('GET', ruta, query: query);
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;

      // Una pausa corta: reintentar al instante suele encontrar la red en el
      // mismo estado en que estaba.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return _enviar('GET', ruta, query: query);
    }
  }

  Future<dynamic> post(String ruta, Object? cuerpo) =>
      _enviar('POST', ruta, cuerpo: cuerpo);

  Future<dynamic> put(String ruta, Object? cuerpo) =>
      _enviar('PUT', ruta, cuerpo: cuerpo);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(String metodo, String ruta,
      {Object? cuerpo, Map<String, dynamic>? query}) async {
    if (!ApiConstants.configurada) {
      throw const ApiException(
        'La app no tiene configurado el servidor. Falta API_BASE_URL '
        '(--dart-define-from-file).',
        esDeNegocio: false,
      );
    }

    /* EL TOKEN SE COMPRUEBA ACA, UNA VEZ, Y NO EN CADA ENDPOINT

       Con la sesión iniciada pero sin cliente elegido —al entrar teniendo
       varias empresas, o al retomar una sesión guardada— el token es válido y
       el servidor contesta 400 «No hay cliente seleccionado» a todo. La
       pantalla mostraba ese 400 como si fuera un fallo del servidor, y encima
       gastaba un viaje de red por cada provider para recibir el mismo no.

       Cortarlo acá es una sola comprobación para los 52 endpoints, y deja a
       la app en condiciones de mandar a elegir cliente en vez de mostrar un
       número. */
    if (token != null && cliente <= 0 && !_noNecesitaCliente(ruta)) {
      throw const ApiException(
        'No hay cliente seleccionado. Use POST /cliente-usuarios/seleccionar.',
        codigo: 400,
      );
    }

    var uri = Uri.parse('${ApiConstants.baseUrl}$ruta');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: query.map((k, v) => MapEntry(k, '$v')),
      );
    }

    if (ApiConstants.logHttp) debugPrint('[ApiClient] $metodo $uri');

    try {
      final tiempo = Duration(seconds: ApiConstants.timeoutSegundos);
      final cabeceras = _headers();
      final cuerpoJson = cuerpo == null ? null : jsonEncode(cuerpo);

      final http.Response r = switch (metodo) {
        'GET' => await _cliente.get(uri, headers: cabeceras).timeout(tiempo),
        'POST' => await _cliente
            .post(uri, headers: cabeceras, body: cuerpoJson)
            .timeout(tiempo),
        'PUT' => await _cliente
            .put(uri, headers: cabeceras, body: cuerpoJson)
            .timeout(tiempo),
        'DELETE' =>
          await _cliente.delete(uri, headers: cabeceras).timeout(tiempo),
        _ => throw ApiException('Método no soportado: $metodo',
            esDeNegocio: false),
      };

      if (ApiConstants.logHttp) debugPrint('[ApiClient] ${r.statusCode}');

      return await _interpretar(r);
    } on SocketException {
      throw const ApiException('Sin conexión al servidor.', esDeNegocio: false);
    } on HttpException {
      throw const ApiException('Sin conexión al servidor.', esDeNegocio: false);
    } on ApiException {
      rethrow;
    } catch (e) {
      // Timeout entra por acá. Es transitorio: quien llame decide reintentar.
      throw ApiException('No se pudo contactar al servidor.',
          esDeNegocio: false);
    }
  }

  bool _noNecesitaCliente(String ruta) =>
      _sinCliente.any((r) => ruta == r || ruta.startsWith('$r/'));

  /// A partir de este tamaño, decodificar en el hilo de la interfaz se nota.
  ///
  /// Un bloque de la sábana con tres mil activos son cientos de KB de JSON, y
  /// `jsonDecode` es sincrónico: mientras corre, **la app no dibuja**. Se ve
  /// como que la barra de progreso de la sincronización se congela justo
  /// cuando está trabajando. Por debajo de este umbral el salto a otro isolate
  /// cuesta más que el trabajo que ahorra.
  static const _umbralIsolate = 64 * 1024;

  Future<dynamic> _interpretar(http.Response r) async {
    // utf8.decode explícito: sin esto los acentos del servidor llegan rotos.
    final texto = r.bodyBytes.isEmpty ? '' : utf8.decode(r.bodyBytes);

    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (texto.isEmpty) return null;
      return texto.length >= _umbralIsolate
          ? await compute(jsonDecode, texto)
          : jsonDecode(texto);
    }

    throw ApiException(
      _mensajeDe(texto, r.statusCode),
      codigo: r.statusCode,
      esDeNegocio: r.statusCode < 500,
    );
  }

  /// Saca el mensaje del cuerpo de error.
  ///
  /// La forma normal es `{ codigo, mensaje, esDeNegocio }` (ApiBase.Error).
  /// Algunos endpoints heredados responden `{ "Message": ... }`, y de un 500
  /// puede no venir nada: por eso hay respaldo.
  String _mensajeDe(String texto, int codigo) {
    if (texto.isNotEmpty) {
      try {
        final j = jsonDecode(texto);
        if (j is Map) {
          final m = j['mensaje'] ?? j['Message'] ?? j['message'];
          if (m is String && m.trim().isNotEmpty) return m.trim();
        }
      } catch (_) {
        // Cuerpo que no es JSON: se ignora y se usa el respaldo.
      }
    }

    return switch (codigo) {
      401 => 'La sesión expiró. Vuelve a iniciar sesión.',
      403 => 'No tienes permiso para hacer esto.',
      404 => 'No se encontró lo que buscabas.',
      _ => 'Ocurrió un error en el servidor.',
    };
  }
}
