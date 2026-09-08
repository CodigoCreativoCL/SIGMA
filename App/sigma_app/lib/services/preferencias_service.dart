import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las preferencias del aparato, no las del usuario en el servidor.
///
/// La diferencia importa: el idioma y el teléfono viven en `Usuarios` porque
/// la web también los usa; **el aviso en el teléfono es del teléfono**. La
/// misma persona puede querer que le suene el celular de trabajo y no la
/// tablet de la oficina, y eso no cabe en una columna del usuario.
class PreferenciasService {
  PreferenciasService._();
  static final PreferenciasService instance = PreferenciasService._();

  static const _claveAvisos = 'sigma_avisos';

  /// ¿Este aparato recibe avisos?
  ///
  /// De fábrica sí: quien no quiera, lo apaga. Al revés, un técnico que nunca
  /// entra a los ajustes no se enteraría de una alerta crítica.
  ///
  /// Hoy la preferencia se guarda y se respeta; **la suscripción al tema de
  /// Firebase se conecta acá** cuando el proyecto tenga su
  /// `google-services.json`, y ese es el único cambio pendiente.
  final ValueNotifier<bool> avisos = ValueNotifier<bool>(true);

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      avisos.value = prefs.getBool(_claveAvisos) ?? true;
    } catch (e) {
      debugPrint('[Preferencias] No se pudieron leer: $e');
    }
  }

  Future<void> cambiarAvisos(bool valor) async {
    avisos.value = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveAvisos, valor);
    } catch (e) {
      debugPrint('[Preferencias] No se pudo guardar el aviso: $e');
    }
  }
}
