import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// En qué va el dictado.
enum EstadoVoz {
  /// Todavía no se pidió el permiso ni se comprobó el reconocedor.
  sinIniciar,

  /// El aparato no tiene reconocedor, o la persona negó el micrófono.
  noDisponible,

  listo,
  escuchando,

  /// Terminó de hablar y ya hay transcripción.
  transcrito,
}

/// El dictado — §2 del kit v3.
///
/// ## Por qué existe
///
/// Con guantes de nitrilo la pantalla capacitiva no responde bien, y en una
/// planta a −5 °C nadie se los saca para teclear. Escribir «8,4» en un campo
/// numérico es tolerable; escribir un número de serie de catorce caracteres es
/// donde de verdad se falla, y donde el técnico termina anotando en papel para
/// pasarlo después —que es exactamente lo que esta app existe para evitar—.
///
/// ## El audio no se guarda
///
/// `speech_to_text` entrega texto y **nunca un archivo**: el reconocimiento lo
/// hace el servicio del sistema y acá solo llega la transcripción. No es un
/// detalle técnico, es la promesa que el kit escribe al pie del panel —«el
/// audio se descarta al obtener la transcripción»— y la razón por la que esto
/// no necesita política de retención ni consentimiento de grabación.
///
/// ## El idioma
///
/// `es_CL` con respaldo a `es_ES`. Importa más de lo que parece: un reconocedor
/// en inglés escucha «ocho coma cuatro» y escribe cualquier cosa, y el punto
/// decimal chileno es coma.
class VozService {
  VozService._();
  static final VozService instance = VozService._();

  final _motor = SpeechToText();

  final ValueNotifier<EstadoVoz> estado =
      ValueNotifier<EstadoVoz>(EstadoVoz.sinIniciar);

  /// Lo que se lleva escuchado, incluido el tramo provisional.
  final ValueNotifier<String> texto = ValueNotifier<String>('');

  /// 0–1. Alimenta las barras del panel.
  final ValueNotifier<double> nivel = ValueNotifier<double>(0);

  /// Por qué no se puede dictar, cuando no se puede.
  String? motivo;

  bool _preparado = false;

  /// Pide permiso y comprueba que haya reconocedor. Es idempotente.
  Future<bool> preparar() async {
    if (_preparado) return estado.value != EstadoVoz.noDisponible;

    try {
      final ok = await _motor.initialize(
        onStatus: _alCambiarEstado,
        onError: (e) {
          // `error_no_match` es que no entendió, no que esté roto: se queda
          // listo para reintentar en vez de deshabilitarse.
          motivo = e.errorMsg;
          debugPrint('[Voz] ${e.errorMsg} (permanente: ${e.permanent})');
          if (e.permanent && e.errorMsg != 'error_no_match') {
            estado.value = EstadoVoz.noDisponible;
          } else if (estado.value == EstadoVoz.escuchando) {
            estado.value = EstadoVoz.listo;
          }
        },
      );

      _preparado = true;
      if (!ok) {
        motivo ??= 'Este teléfono no tiene reconocimiento de voz disponible.';
        estado.value = EstadoVoz.noDisponible;
        return false;
      }
      estado.value = EstadoVoz.listo;
      return true;
    } catch (e) {
      // Sin dictado se sigue trabajando: el teclado nunca deja de estar.
      motivo = 'No se pudo preparar el micrófono.';
      debugPrint('[Voz] $e');
      _preparado = true;
      estado.value = EstadoVoz.noDisponible;
      return false;
    }
  }

  Future<void> escuchar() async {
    if (!await preparar()) return;
    if (_motor.isListening) return;

    texto.value = '';
    nivel.value = 0;
    estado.value = EstadoVoz.escuchando;

    await _motor.listen(
      onResult: (r) {
        texto.value = r.recognizedWords;
        if (r.finalResult) estado.value = EstadoVoz.transcrito;
      },
      onSoundLevelChange: (v) {
        // El paquete entrega decibelios en un rango que varía por aparato; se
        // normaliza a 0–1 para que las barras se vean igual en todos.
        nivel.value = ((v + 40) / 50).clamp(0.0, 1.0);
      },
      listenOptions: SpeechListenOptions(
        localeId: await _idioma(),
        // Sin resultados parciales el panel se queda mudo hasta el final, y
        // ahí nadie sabe si lo está tomando.
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        // En terreno se dicta una frase, no un párrafo: si se corta a los tres
        // segundos de silencio, la persona no tiene que acordarse de parar.
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 45),
      ),
    );
  }

  Future<void> detener() async {
    await _motor.stop();
    nivel.value = 0;
    if (estado.value == EstadoVoz.escuchando) {
      estado.value =
          texto.value.trim().isEmpty ? EstadoVoz.listo : EstadoVoz.transcrito;
    }
  }

  Future<void> cancelar() async {
    await _motor.cancel();
    texto.value = '';
    nivel.value = 0;
    estado.value = EstadoVoz.listo;
  }

  void limpiar() {
    texto.value = '';
    nivel.value = 0;
    if (estado.value == EstadoVoz.transcrito) estado.value = EstadoVoz.listo;
  }

  void _alCambiarEstado(String s) {
    if (s == 'done' || s == 'notListening') {
      nivel.value = 0;
      if (estado.value == EstadoVoz.escuchando) {
        estado.value =
            texto.value.trim().isEmpty ? EstadoVoz.listo : EstadoVoz.transcrito;
      }
    }
  }

  Future<String> _idioma() async {
    try {
      final locales = await _motor.locales();
      for (final preferido in ['es_CL', 'es-CL', 'es_ES', 'es-ES']) {
        for (final l in locales) {
          if (l.localeId == preferido) return l.localeId;
        }
      }
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith('es')) return l.localeId;
      }
    } catch (e) {
      debugPrint('[Voz] Sin lista de idiomas: $e');
    }
    return 'es_CL';
  }
}

/// Lo que el dictado logró entender de una frase.
class CampoDictado {
  const CampoDictado({
    required this.clave,
    required this.rotulo,
    required this.valor,
    this.unidad,
    this.confirmar = false,
  });

  final String clave;
  final String rotulo;
  final String valor;
  final String? unidad;

  /// Cuando el reconocimiento es dudoso —una unidad que no coincide con la
  /// esperada, un número fuera de lo normal—, el kit lo marca «Confirmar» en
  /// vez de descartarlo. Descartar en silencio hace que la persona repita la
  /// frase entera sin saber qué falló.
  final bool confirmar;
}

/// El intérprete: de «vibración 8 coma 4 milímetros por segundo» a `8.4`.
///
/// **Es la mitad que hace útil al micrófono.** Un dictado que solo pega texto
/// en una caja obliga a leerlo y transcribirlo a mano a los campos, que es el
/// trabajo que se quería ahorrar.
///
/// Se resuelve acá y no en el servidor a propósito: la interpretación tiene
/// que funcionar **sin señal**, que es cuando más se dicta.
abstract final class InterpreteVoz {
  /// «ocho coma cuatro» → «8,4». El español dicta el decimal como «coma» y a
  /// veces como «punto»; los dos significan lo mismo acá.
  static final _decimal =
      RegExp(r'(\d+)\s*(?:coma|punto)\s*(\d+)', caseSensitive: false);

  /// `1.234.567` → `1234567`. **Solo** cuando los puntos vienen en grupos de
  /// tres repetidos: eso es un separador de miles y nunca un decimal.
  static final _miles = RegExp(r'\b(\d{1,3})((?:\.\d{3})+)\b');

  /// `8.4` → `8,4`. El reconocedor de Android devuelve el decimal con punto
  /// aunque se haya dictado «coma», y `numero()` buscaba solo la coma: de
  /// «ocho coma cuatro» guardaba **8**. Una medición de vibración de 8,4
  /// mm/s registrada como 8 no se ve mal en pantalla y está mal en la base.
  static final _puntoDecimal = RegExp(r'(\d),?\.(\d)');

  /// Los números dictados en palabras.
  ///
  /// El reconocedor devuelve cifras casi siempre, pero no siempre: con ruido
  /// de planta, «ocho» sale como palabra más veces de las que uno esperaría.
  /// Y una palabra que no se convierte hace que `numero()` devuelva `null` y
  /// el campo quede vacío — que es exactamente el síntoma de «dicté y no puso
  /// nada».
  static const _palabras = <String, int>{
    // «un» y «una» NO están: en «un ruido en el acople» son artículos, y
    // convertirlos metería un 1 en la observación de casi toda frase.
    'cero': 0, 'uno': 1, 'dos': 2, 'tres': 3,
    'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
    'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14,
    'quince': 15, 'dieciseis': 16, 'dieciséis': 16, 'diecisiete': 17,
    'dieciocho': 18, 'diecinueve': 19, 'veinte': 20, 'veintiuno': 21,
    'veintiun': 21, 'veintiún': 21, 'veintidos': 22, 'veintidós': 22,
    'veintitres': 23, 'veintitrés': 23, 'veinticuatro': 24,
    'veinticinco': 25, 'veintiseis': 26, 'veintiséis': 26,
    'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
    'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60,
    'setenta': 70, 'ochenta': 80, 'noventa': 90,
    'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300,
    'cuatrocientos': 400, 'quinientos': 500, 'seiscientos': 600,
    'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
  };

  /// Convierte las palabras de número que encuentre, dejando el resto igual.
  ///
  /// Combina como se dicta en español: «treinta y cinco» → 35, «ciento
  /// veinte» → 120, «dos mil quinientos» → 2500. Lo que no sea número no se
  /// toca, porque la misma frase lleva la observación.
  static String _numerosEnPalabras(String texto) {
    final piezas = texto.split(' ');
    final salida = <String>[];

    int acumulado = 0;
    int total = 0;
    bool hay = false;

    void cerrar() {
      if (!hay) return;
      salida.add('${total + acumulado}');
      acumulado = 0;
      total = 0;
      hay = false;
    }

    for (final pieza in piezas) {
      final limpia = pieza.toLowerCase().replaceAll(RegExp(r'[.,;:]'), '');
      final valor = _palabras[limpia];

      if (valor != null) {
        // «ciento veinte»: las centenas y las decenas se suman entre sí.
        acumulado += valor;
        hay = true;
        continue;
      }

      // «mil» multiplica lo que se lleva acumulado y arrastra el resto.
      if (limpia == 'mil' && hay) {
        total += (acumulado == 0 ? 1 : acumulado) * 1000;
        acumulado = 0;
        continue;
      }

      // La «y» de «treinta y cinco» une; la «y» suelta separa frases.
      if (limpia == 'y' && hay) continue;

      cerrar();
      salida.add(pieza);
    }

    cerrar();
    return salida.join(' ');
  }

  /// Las unidades que la app entiende dictadas, con su símbolo canónico.
  static const _unidades = <String, String>{
    'milimetros por segundo': 'mm/s',
    'milímetros por segundo': 'mm/s',
    'grados': '°C',
    'grados celsius': '°C',
    'horas': 'h',
    'hora': 'h',
    'kilowatt': 'kW',
    'kilovatios': 'kW',
    'amperes': 'A',
    'amperios': 'A',
    'volt': 'V',
    'volts': 'V',
    'bar': 'bar',
    'psi': 'psi',
    'unidades': 'UN',
    'litros': 'L',
    'kilos': 'kg',
    'kilogramos': 'kg',
  };

  /// Normaliza el texto dictado: decimales en cifra y sin dobles espacios.
  ///
  /// El orden importa y no es intercambiable:
  ///
  ///   1. palabras a cifras —«ocho» → «8»—, porque los pasos siguientes solo
  ///      saben mirar dígitos;
  ///   2. los puntos de millar se quitan **antes** de tocar el punto decimal,
  ///      si no «1.234» se convertiría en «1,234»;
  ///   3. «coma»/«punto» dictados a coma;
  ///   4. el punto decimal que puso el reconocedor, a coma.
  static String normalizar(String crudo) {
    var t = crudo.trim().replaceAll(RegExp(r'\s+'), ' ');
    t = _numerosEnPalabras(t);
    t = t.replaceAllMapped(
        _miles, (m) => '${m[1]}${m[2]!.replaceAll('.', '')}');
    t = t.replaceAllMapped(_decimal, (m) => '${m[1]},${m[2]}');
    t = t.replaceAllMapped(_puntoDecimal, (m) => '${m[1]},${m[2]}');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// El primer número de la frase, en formato chileno.
  ///
  /// Devuelve `null` si no hay ninguno: es mejor dejar el campo vacío que
  /// meter un cero que después alguien toma por una medición real.
  static String? numero(String crudo) {
    final t = normalizar(crudo);
    final m = RegExp(r'-?\d+(?:,\d+)?').firstMatch(t);
    return m?.group(0);
  }

  /// La unidad mencionada, si la hay.
  static String? unidad(String crudo) {
    final t = normalizar(crudo).toLowerCase();
    // De la más larga a la más corta: «grados celsius» antes que «grados».
    final claves = _unidades.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in claves) {
      if (t.contains(k)) return _unidades[k];
    }
    return null;
  }

  /// Lo que queda después de sacar la cifra y la unidad: la observación.
  static String observacion(String crudo) {
    var t = normalizar(crudo);

    // Si la persona dijo «observación …», lo de después es la observación y
    // punto: es la señal más clara que puede dar.
    final marca = RegExp(r'observaci[oó]n\s*[:,]?\s*(.+)$', caseSensitive: false)
        .firstMatch(t);
    if (marca != null) return _mayuscula(marca.group(1)!.trim());

    t = t.replaceAll(RegExp(r'-?\d+(?:,\d+)?'), ' ');
    for (final k in _unidades.keys) {
      t = t.replaceAll(RegExp(k, caseSensitive: false), ' ');
    }
    t = t
        .replaceAll(
            RegExp(r'\b(vibraci[oó]n|temperatura|lectura|medici[oó]n|valor|rms)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return t.length < 4 ? '' : _mayuscula(t);
  }

  /// Interpreta una frase para un campo numérico con unidad conocida.
  ///
  /// Cuando la unidad dictada **no** coincide con la esperada, el valor se
  /// marca para confirmar en vez de aceptarse: decir «grados» en un campo de
  /// vibración casi siempre significa que la frase mezcló dos medidas.
  static List<CampoDictado> paraMedicion(
    String crudo, {
    required String rotulo,
    String? unidadEsperada,
  }) {
    final campos = <CampoDictado>[];

    final n = numero(crudo);
    final u = unidad(crudo);

    if (n != null) {
      campos.add(CampoDictado(
        clave: 'valor',
        rotulo: rotulo,
        valor: n,
        unidad: u ?? unidadEsperada,
        confirmar:
            u != null && unidadEsperada != null && u != unidadEsperada,
      ));
    }

    final obs = observacion(crudo);
    if (obs.isNotEmpty) {
      campos.add(CampoDictado(
          clave: 'observacion', rotulo: 'Observación', valor: obs));
    }

    return campos;
  }

  static String _mayuscula(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
