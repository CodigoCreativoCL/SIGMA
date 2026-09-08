import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El modo de la app: oscuro, claro, o el del sistema.
///
/// **El de fábrica es oscuro, no `sistema`.** La app se usa en una planta, con
/// contraluz; dejar que el teléfono decida haría que el técnico entre en claro
/// solo porque no cambió el ajuste de Android. Quien la usa en oficina lo
/// cambia una vez y queda.
class TemaService {
  TemaService._();
  static final TemaService instance = TemaService._();

  static const _clave = 'sigma_tema';

  /// Lo escucha `MaterialApp` con un `ValueListenableBuilder`, así que cambiar
  /// el modo repinta la app entera sin tocar el árbol de providers.
  final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.dark);

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modo.value = _desde(prefs.getString(_clave));
    } catch (e) {
      // Sin preferencias se entra igual, en oscuro: quedarse sin la
      // preferencia es molesto; quedarse sin pantalla, no se puede.
      debugPrint('[TemaService] No se pudo leer el tema: $e');
    }
  }

  Future<void> cambiar(ThemeMode nuevo) async {
    modo.value = nuevo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, nuevo.name);
    } catch (e) {
      debugPrint('[TemaService] No se pudo guardar el tema: $e');
    }
  }

  static ThemeMode _desde(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}
