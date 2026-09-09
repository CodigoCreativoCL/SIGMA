import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash/splash_screen.dart';
import 'services/accesibilidad_service.dart';
import 'services/preferencias_service.dart';
import 'services/sesion_service.dart';
import 'services/tema_service.dart';
import 'theme/app_theme.dart';
import 'widgets/comun/sigma_al_retomar.dart';

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

  bool haySesion = false;
  try {
    haySesion = await SesionService.instance.cargarDesdeDisco();
  } catch (e) {
    debugPrint('[main] No se pudo preparar la sesión: $e');
  }

  // Después de la sesión, no antes: los ajustes de accesibilidad son **de la
  // persona**, no del aparato, y hasta acá no se sabe quién es. Sin sesión se
  // leen los del usuario 0, que son los de fábrica.
  await AccesibilidadService.instance.cargar(
    SesionService.instance.sesion.usuario,
  );

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
      builder: (_, modo, _) => ValueListenableBuilder<bool>(
        valueListenable: AccesibilidadService.instance.altoContraste,
        builder: (_, contraste, _) => MaterialApp(
          title: 'SIGMA',
          debugShowCheckedModeBanner: false,
          // **El oscuro es el de fábrica**, y no es capricho: es la superficie
          // que se mira en una planta, con contraluz y detrás de una funda. El
          // claro existe porque la misma app se abre en la oficina.
          themeMode: modo,
          theme: AppTheme.claro(contraste: contraste),
          darkTheme: AppTheme.oscuro(contraste: contraste),
          /* EL TAMANO DEL TEXTO SE APLICA ACA, UNA VEZ

             Envolver el `home` y no cada pantalla: si cada una escalara por su
             cuenta, la que se olvidara se veria distinta al resto. `builder`
             se aplica tambien a lo que abre `Navigator`, que es lo que hace
             que valga para toda la app y no solo para la primera pantalla.

             Se ignora el ajuste del sistema a proposito: Android ya escala, y
             multiplicar los dos factores lleva a texto cortado sin que nadie
             entienda de donde salio. Manda el de SIGMA. */
          builder: (contexto, hijo) => ValueListenableBuilder<double>(
            valueListenable: AccesibilidadService.instance.escalaTexto,
            builder: (contexto, escala, _) => ValueListenableBuilder<bool>(
              valueListenable: AccesibilidadService.instance.movimientoReducido,
              /* MOVIMIENTO REDUCIDO VIAJA EN `disableAnimations`

                 Es la bandera que Flutter ya tiene para esto —la que enciende
                 el ajuste del sistema— y la miran tanto los widgets propios
                 como los del framework. Inventar un provider nuestro habria
                 obligado a que cada animacion se acordara de consultarlo, y la
                 que se olvidara seguiria girando. */
              builder: (_, quieto, _) => MediaQuery(
                data: MediaQuery.of(contexto).copyWith(
                  textScaler: TextScaler.linear(escala),
                  disableAnimations: quieto,
                ),
                child: hijo ?? const SizedBox.shrink(),
              ),
            ),
          ),
          /* AL VOLVER DEL SEGUNDO PLANO, SE PONE AL DIA

             Android mata las apps en segundo plano sin avisar. Al volver,
             SIGMA se reconstruia con la sesion pero con los datos de hace
             horas: se veian listas viejas sin nada que dijera que lo eran. */
          home: SgAlRetomar(child: SplashScreen(haySesion: haySesion)),
        ),
      ),
    );
  }
}
