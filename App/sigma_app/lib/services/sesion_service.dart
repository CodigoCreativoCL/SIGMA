import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../models/sesion_model.dart';
import 'api_client.dart';

/// El almacén de la sesión: en memoria, y respaldado en disco.
///
/// La UI **nunca** lee esto directo: lee `sesionProvider`.
///
/// El JWT se persiste a propósito. Dura ocho horas, y volver a pedir la clave
/// en cada arranque es inaceptable en planta —un técnico con guantes no
/// escribe una contraseña entre dos tareas—. El riesgo es distinto al de un
/// computador olvidado en una oficina.
class SesionService {
  SesionService._();
  static final SesionService instance = SesionService._();

  static const _clave = 'sigma_sesion';

  SesionModel sesion = const SesionModel();

  /// "Android 14 - SM-A536E". Lo llena `main()`.
  String dispositivo = '';

  static const _claveLogin = 'sigma_ultimo_login';
  static const _claveInstalacion = 'sigma_instalacion';

  /// El correo con el que se entro la ultima vez, para rellenarlo solo.
  ///
  /// **Solo el correo, nunca la contrasena.** Eso es todo lo que significa
  /// «Recordarme» en el kit: un telefono de planta se comparte entre turnos y
  /// guardar la clave convertiria el aparato en la credencial. El correo, en
  /// cambio, no abre nada por si mismo y ahorra el campo mas largo de
  /// escribir con guantes.
  String? ultimoLogin;

  /// La planta con la que se estaba trabajando.
  ///
  /// ## Por que SI se persiste, si antes no
  ///
  /// El comentario de `instalacionProvider` decia que perderla al reiniciar
  /// era «un inconveniente menor». No lo es: la sabana se descarga POR PLANTA
  /// y media app filtra por ella, asi que sin planta los listados bajan
  /// vacios. Al retomar la app despues de que Android la matara —lo normal si
  /// se deja en segundo plano un rato— la persona veia todo vacio sin
  /// entender por que, o peor, volvia a elegir sin darse cuenta de que habia
  /// estado mirando una pantalla sin contexto.
  ///
  /// ## Por que solo el id
  ///
  /// El nombre y la direccion los trae `plantas()`, que ya viaja en la sabana.
  /// Guardar el objeto entero seria una segunda copia que envejece: si desde
  /// la web renombran la planta, la del telefono seguiria diciendo el nombre
  /// viejo hasta que alguien la vuelva a elegir.
  int? instalacionRecordada;

  Future<void> recordarInstalacion(int? id) async {
    instalacionRecordada = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_claveInstalacion);
      } else {
        await prefs.setInt(_claveInstalacion, id);
      }
    } catch (e) {
      debugPrint('[SesionService] No se pudo recordar la planta: $e');
    }
  }

  Future<void> recordarLogin(String? login) async {
    ultimoLogin = login;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (login == null || login.isEmpty) {
        await prefs.remove(_claveLogin);
      } else {
        await prefs.setString(_claveLogin, login);
      }
    } catch (e) {
      debugPrint('[SesionService] No se pudo recordar el login: $e');
    }
  }

  bool get autenticado => sesion.autenticado;

  Future<bool> cargarDesdeDisco() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ultimoLogin = prefs.getString(_claveLogin);
      instalacionRecordada = prefs.getInt(_claveInstalacion);

      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return false;

      sesion = SesionModel.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      ApiClient.instance.token = sesion.token;
      // El cliente viaja con el token y se restaura con él: si no, al retomar
      // la sesión el cliente HTTP creería que no hay ninguno elegido.
      ApiClient.instance.cliente = sesion.cliente;
      return sesion.autenticado;
    } catch (e) {
      debugPrint('[SesionService] No se pudo leer la sesión: $e');
      return false;
    }
  }

  Future<void> guardar(SesionModel nueva) async {
    sesion = nueva;
    ApiClient.instance.token = nueva.token;
    ApiClient.instance.cliente = nueva.cliente;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode(nueva.toJson()));
    } catch (e) {
      debugPrint('[SesionService] No se pudo guardar la sesión: $e');
    }
  }

  Future<void> limpiar() async {
    sesion = const SesionModel();
    ApiClient.instance.limpiarToken();
    ApiClient.instance.cliente = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (e) {
      debugPrint('[SesionService] No se pudo limpiar la sesión: $e');
    }
  }
}

/// Iniciar y cerrar sesión (HU-001, HU-002, HU-003).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// HU-001. El servidor decide el ámbito: `SEL_LOGIN` recibe `@AMBITO = 2`
  /// desde la API y rechaza con 403 al perfil que solo opera en la web.
  Future<SesionModel> iniciar(
    String login,
    String password, {
    bool recordar = true,
  }) async {
    final correo = login.trim();

    final j = await ApiClient.instance.post(ApiConstants.sesion, {
      'login': correo,
      'password': password,
    });

    final sesion = SesionModel.fromJson(j as Map<String, dynamic>);
    await SesionService.instance.guardar(sesion);
    // Se recuerda **despues** de que el servidor acepto: guardar un correo que
    // resulto no existir solo sirve para rellenarlo mal la proxima vez.
    await SesionService.instance.recordarLogin(recordar ? correo : null);
    return sesion;
  }

  /// HU-002. Cambiar de cliente exige un token nuevo: el servidor revalida la
  /// pertenencia contra la base sin confiar en el id que llega.
  Future<SesionModel> seleccionarCliente(int clienteId) async {
    final j = await ApiClient.instance.post(ApiConstants.seleccionarCliente, {
      'cliente': clienteId,
    });

    final sesion = SesionModel.fromJson(j as Map<String, dynamic>);
    await SesionService.instance.guardar(sesion);
    return sesion;
  }

  /// Deja la sesión **en condiciones de operar**: con cliente en el token.
  ///
  /// ## Por qué hace falta
  ///
  /// El token de `POST /sesion` no siempre trae cliente. Sin él, todo endpoint
  /// acotado por cliente responde 400 y la app se veía «conectada» mostrando
  /// errores en cada pantalla: el síntoma era «hay señal y no carga nada».
  ///
  /// Pasa en dos momentos y los dos son normales:
  ///
  ///   · al **entrar**, si la persona pertenece a varias empresas;
  ///   · al **retomar** una sesión guardada que se cerró antes de elegir.
  ///
  /// ## Qué hace
  ///
  /// Si hay un solo cliente posible, **lo elige solo**: obligar a tocar un
  /// botón para confirmar la única opción que existe no protege de nada. Con
  /// varios, devuelve `false` y quien llama manda a la pantalla de selección.
  ///
  /// Devuelve `true` cuando la sesión ya puede pedir datos.
  Future<bool> asegurarCliente() async {
    if (SesionService.instance.sesion.tieneCliente) return true;

    final clientes = await misClientes();
    if (clientes.length != 1) return false;

    await seleccionarCliente(clientes.first.id);
    return SesionService.instance.sesion.tieneCliente;
  }

  Future<List<ClienteElegibleModel>> misClientes() async {
    final j = await ApiClient.instance.get(ApiConstants.misClientes);
    if (j is! List) return const [];
    return j
        .map((e) => ClienteElegibleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// HU-003. El JWT no se guarda en el servidor: cerrar sesión es que el
  /// cliente deje de mandarlo. El endpoint existe igual —deja la acción
  /// registrada, y el día que haya lista de revocación se implementa ahí sin
  /// que la app cambie una línea—, así que si falla, no importa.
  Future<void> cerrar() async {
    try {
      await ApiClient.instance.delete(ApiConstants.sesion);
    } catch (e) {
      debugPrint('[AuthService] El servidor no confirmó el cierre: $e');
    }
    await SesionService.instance.limpiar();
  }
}
