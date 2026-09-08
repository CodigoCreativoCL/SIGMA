import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelos.dart';
import 'datos_provider.dart';

/// La predicción destacada de la planta en contexto — HU-173.
///
/// ## Ya no devuelve `null`
///
/// Durante varios bloques este provider devolvió `null` a propósito: la
/// tarjeta de SIGMA AI existía y era fiel al kit, pero **la API no exponía
/// predicciones**, y mostrar un «78 % de probabilidad de falla de rodamiento»
/// que nadie calculó habría sido peor que no mostrar nada. Un jefe de
/// mantenimiento se lo cree y para una línea.
///
/// Ahora sí hay endpoint, hay modelo registrado y hay predicciones calculadas
/// sobre lecturas reales. La tarjeta muestra la más urgente de las vigentes.
///
/// ## Y cuando no hay, tampoco inventa
///
/// Devuelve `null` si la lista viene vacía, y la pantalla muestra el estado
/// vacío. Eso sigue siendo lo correcto: el modelo callando es una respuesta,
/// no un hueco que haya que rellenar.
final prediccionDestacadaProvider = Provider<Prediccion?>((ref) {
  final lista = ref.watch(prediccionesProvider).valueOrNull;
  if (lista == null || lista.isEmpty) return null;

  // Ya vienen ordenadas por severidad y luego por días: la primera es la que
  // hay que mirar. El orden lo decide el SP —si lo decidiera la app, dos
  // pantallas del mismo sistema podrían priorizar distinto sobre los mismos
  // datos—.
  return lista.first;
});

/// Cuántos equipos se vigilan sin que nadie los mida.
///
/// Alimenta el motivo del estado vacío: «no hay análisis» no significa lo
/// mismo si además nadie está midiendo nada. La diferencia es entre una buena
/// noticia y un problema de operación.
final vigiladosSinDatosProvider = Provider<int>((ref) {
  final lista = ref.watch(vigiladosProvider).valueOrNull;
  if (lista == null) return 0;
  return lista.where((v) => v.sinLecturas || v.faltanLecturas).length;
});
