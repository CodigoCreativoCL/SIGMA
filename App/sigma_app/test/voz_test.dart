import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/services/voz_service.dart';

/// El intérprete de voz es la mitad que hace útil al micrófono: sin él, dictar
/// solo pega texto en una caja y el técnico tiene que transcribirlo a mano a
/// los campos, que es justo el trabajo que se quería ahorrar.
///
/// Por eso se prueba con **frases como las que se dicen en planta**, no con
/// cadenas de laboratorio.
void main() {
  group('Normalizar', () {
    test('«coma» y «punto» son el mismo decimal', () {
      // El reconocedor entrega la palabra, no el símbolo, y en Chile el
      // decimal se dice «coma» pero mucha gente dicta «punto».
      expect(InterpreteVoz.normalizar('8 coma 4'), '8,4');
      expect(InterpreteVoz.normalizar('8 punto 4'), '8,4');
      expect(InterpreteVoz.normalizar('12   coma   50'), '12,50');
    });

    test('las palabras de número se vuelven cifras', () {
      // Antes esto devolvía «ocho coma cuatro» tal cual y `numero()` no
      // encontraba ningún dígito: el campo quedaba vacío después de dictar.
      expect(InterpreteVoz.normalizar('ocho coma cuatro'), '8,4');
      expect(InterpreteVoz.normalizar('treinta y cinco'), '35');
      expect(InterpreteVoz.normalizar('ciento veinte'), '120');
      expect(InterpreteVoz.normalizar('dos mil quinientos'), '2500');
    });

    test('el punto del reconocedor es decimal, y el de millar no', () {
      // Android devuelve «8.4» aunque se haya dictado «coma». Tomarlo como
      // entero guardaba 8 donde el técnico midió 8,4.
      expect(InterpreteVoz.normalizar('8.4'), '8,4');
      expect(InterpreteVoz.normalizar('12.480 horas'), '12480 horas');
      expect(InterpreteVoz.normalizar('1.234.567'), '1234567');
    });
  });

  group('Número', () {
    test('saca la cifra de una frase corriente', () {
      expect(InterpreteVoz.numero('vibración 8 coma 4 milímetros por segundo'),
          '8,4');
      expect(InterpreteVoz.numero('temperatura 68 grados'), '68');
      expect(InterpreteVoz.numero('12480 horas'), '12480');
    });

    test('la cifra dictada en palabras también llega al campo', () {
      expect(InterpreteVoz.numero('vibración ocho coma cuatro'), '8,4');
      expect(InterpreteVoz.numero('temperatura sesenta y ocho grados'), '68');
    });

    test('sin número devuelve nulo, no cero', () {
      // Un cero de relleno es peor que un campo vacío: alguien lo toma después
      // por una medición real.
      expect(InterpreteVoz.numero('ruido en el acople'), isNull);
      expect(InterpreteVoz.numero(''), isNull);
    });
  });

  group('Unidad', () {
    test('reconoce las unidades dictadas', () {
      expect(InterpreteVoz.unidad('8 coma 4 milímetros por segundo'), 'mm/s');
      expect(InterpreteVoz.unidad('68 grados'), '°C');
      expect(InterpreteVoz.unidad('12480 horas'), 'h');
    });

    test('la más larga gana a la más corta', () {
      // «grados celsius» contiene «grados»: sin ordenar por largo, el primero
      // que coincidiera decidiría, y sería el equivocado.
      expect(InterpreteVoz.unidad('68 grados celsius'), '°C');
    });

    test('sin unidad, nulo', () {
      expect(InterpreteVoz.unidad('8 coma 4'), isNull);
    });
  });

  group('Observación', () {
    test('«observación …» manda sobre todo lo demás', () {
      final o = InterpreteVoz.observacion(
          'vibración 8 coma 4, observación ruido intermitente en lado acople');
      expect(o, 'Ruido intermitente en lado acople');
    });

    test('sin la palabra clave, saca cifras y unidades', () {
      final o = InterpreteVoz.observacion(
          'vibración 8 coma 4 milímetros por segundo ruido en el acople');
      expect(o.toLowerCase(), contains('ruido'));
      expect(o, isNot(contains('8,4')));
      expect(o.toLowerCase(), isNot(contains('milímetros')));
    });

    test('un resto demasiado corto no es una observación', () {
      // «68 grados» sin nada más deja dos letras sueltas; devolverlas como
      // observación llenaría la ficha de basura.
      expect(InterpreteVoz.observacion('68 grados'), '');
    });
  });

  group('Medición completa', () {
    test('una frase de terreno se parte en valor y observación', () {
      final campos = InterpreteVoz.paraMedicion(
        'vibración 8 coma 4 milímetros por segundo, observación ruido '
        'intermitente en lado acople',
        rotulo: 'Vibración RMS',
        unidadEsperada: 'mm/s',
      );

      expect(campos.length, 2);
      expect(campos.first.clave, 'valor');
      expect(campos.first.valor, '8,4');
      expect(campos.first.unidad, 'mm/s');
      expect(campos.first.confirmar, isFalse);

      expect(campos.last.clave, 'observacion');
      expect(campos.last.valor, 'Ruido intermitente en lado acople');
    });

    test('una unidad que no cuadra se marca para confirmar, no se descarta', () {
      // Decir «grados» en un campo de vibración casi siempre significa que la
      // frase mezcló dos medidas. Descartarlo en silencio haría repetir todo.
      final campos = InterpreteVoz.paraMedicion(
        'vibración 68 grados',
        rotulo: 'Vibración RMS',
        unidadEsperada: 'mm/s',
      );

      expect(campos.first.valor, '68');
      expect(campos.first.confirmar, isTrue);
    });

    test('sin unidad dictada se asume la esperada y no se marca', () {
      final campos = InterpreteVoz.paraMedicion(
        '8 coma 4',
        rotulo: 'Vibración RMS',
        unidadEsperada: 'mm/s',
      );

      expect(campos.first.unidad, 'mm/s');
      expect(campos.first.confirmar, isFalse);
    });

    test('una frase sin cifra no inventa un valor', () {
      final campos = InterpreteVoz.paraMedicion(
        'se escucha un ruido raro en el acople',
        rotulo: 'Vibración RMS',
        unidadEsperada: 'mm/s',
      );

      expect(campos.any((c) => c.clave == 'valor'), isFalse);
      expect(campos.single.clave, 'observacion');
    });
  });
}
