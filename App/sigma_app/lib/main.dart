import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash/splash_screen.dart';
import 'services/preferencias_service.dart';
import 'services/sesion_service.dart';
import 'services/tema_service.dart';
import 'theme/app_theme.dart';

/// El orden de este arranque importa, y cada paso está donde está por una
/// razón. Ver `MD/SIGMA_APP_ARQUITECTURA.md` §9.
///
/// Lo esencial: el arranque **lee del disco**; la red viene después y en
/// segundo plano. Un `await` de red acá deja al técnico mirando una pantalla
/// en blanco hasta que expire el timeout, y en una planta eso pasa a diario.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es_CL');
  await _describirDispositivo();

  // Solo disco, y todo tolerante a fallo: quedarse sin la preferencia de tema
  // es molesto; quedarse sin pantalla, no se puede.
  await TemaService.instance.cargar();
  await PreferenciasService.instance.cargar();
  await PreferenciasService.instance.cargar();

  bool haySesion = false;
  try {
    haySesion = await SesionService.instance.cargarDesdeDisco();
  } catch (e) {
    debugPrint('[main] No se pudo preparar la sesión: $e');
  }

  runApp(ProviderScope(child: SigmaApp(haySesion: haySesion)));
}

Future<void> _describirDispositivo() async {
  try {
    if (!Platform.isAndroid) return;
    final info = await DeviceInfoPlugin().androidInfo;
    SesionService.instance.dispositivo =
        'Android ${info.version.release} - ${info.model}';
  } catch (e) {
    debugPrint('[main] Sin info del dispositivo: $e');
  }
}

class SigmaApp extends StatelessWidget {
  const SigmaApp({super.key, required this.haySesion});

  final bool haySesion;

  @override
  Widget build(BuildContext context) {
    // El modo se escucha con un `ValueListenableBuilder` y no con un provider:
    // cambiarlo repinta la app entera sin tocar el árbol de Riverpod, así que
    // ninguna consulta en curso se cancela por cambiar de tema.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaService.instance.modo,
      builder: (_, modo, _) => MaterialApp(
        title: 'SIGMA',
        debugShowCheckedModeBanner: false,
        // **El oscuro es el de fábrica**, y no es capricho: es la superficie
        // que se mira en una planta, con contraluz y detrás de una funda. El
        // claro existe porque la misma app se abre en la oficina.
        themeMode: modo,
        theme: AppTheme.claro(),
        darkTheme: AppTheme.oscuro(),
        home: SplashScreen(haySesion: haySesion),
      ),
    );
  }
}
