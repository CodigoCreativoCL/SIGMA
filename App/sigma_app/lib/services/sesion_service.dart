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

  /// El correo con el que se entro la ultima vez, para rellenarlo solo.
  ///
  /// **Solo el correo, nunca la contrasena.** Eso es todo lo que significa
  /// «Recordarme» en el kit: un telefono de planta se comparte entre turnos y
  /// guardar la clave convertiria el aparato en la credencial. El correo, en
  /// cambio, no abre nada por si mismo y ahorra el campo mas largo de
  /// escribir con guantes.
  String? ultimoLogin;

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

      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return false;

      sesion = SesionModel.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      ApiClient.instance.token = sesion.token;
      return sesion.autenticado;
    } catch (e) {
      debugPrint('[SesionService] No se pudo leer la sesión: $e');
      return false;
    }
  }

  Future<void> guardar(SesionModel nueva) async {
    sesion = nueva;
    ApiClient.instance.token = nueva.token;
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
    final j = await ApiClient.instance
        .post(ApiConstants.seleccionarCliente, {'cliente': clienteId});

    final sesion = SesionModel.fromJson(j as Map<String, dynamic>);
    await SesionService.instance.guardar(sesion);
    return sesion;
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
