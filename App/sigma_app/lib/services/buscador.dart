/// Buscar como busca la gente, no como compara una máquina.
///
/// ## El problema
///
/// Quien dicta «ot cuatro» produce `ot4`. La orden se llama `OT-04`. Con un
/// `contains` no calzan, y la app responde «nada coincide» sobre un registro
/// que está ahí. Lo mismo tecleando: nadie escribe el guion ni los ceros a la
/// izquierda cuando tiene prisa y guantes.
///
/// ## Qué se normaliza, y por qué cada cosa
///
/// - **Tildes.** «Sepúlveda» y «Sepulveda» son la misma persona, y el teclado
///   de terreno rara vez las pone.
/// - **Mayúsculas.** Obvio, pero hay que hacerlo antes de lo demás.
/// - **Separadores** —guion, barra, punto, guion bajo, espacios—. `OT-04`,
///   `OT 04` y `OT/04` son lo mismo escrito por tres personas distintas.
/// - **Ceros a la izquierda dentro de cada número.** `ot04` → `ot4`. Es lo que
///   hace que dictar «ot cuatro» encuentre `OT-04`.
///
/// ## Por qué se parte la búsqueda en términos
///
/// «horno linea 4» encuentra «Horno L4 — Línea de panificación» aunque las
/// palabras estén separadas y en otro orden. Se exige que **todos** los
/// términos aparezcan: buscar dos cosas y que valga con una devolvería medio
/// listado y sería peor que no filtrar.
///
/// ## Lo que NO hace, a propósito
///
/// No corrige erratas ni busca por parecido fonético. «rodamento» no encuentra
/// «rodamiento»: adivinar lo que alguien quiso escribir devuelve resultados que
/// no se pidieron, y en una lista de trabajo eso es peor que no encontrar nada
/// —se actúa sobre el registro equivocado—.
library;

/// Deja un texto en su forma comparable.
String normalizarBusqueda(String crudo) {
  if (crudo.isEmpty) return '';

  final sinTilde = _quitarTildes(crudo.toLowerCase());

  // Fuera todo lo que no sea letra o número: separadores, signos y espacios.
  final compacto = sinTilde.replaceAll(RegExp(r'[^a-z0-9ñ]'), '');

  // Y los ceros a la izquierda de cada grupo de dígitos: «ot04» → «ot4».
  return compacto.replaceAllMapped(RegExp(r'0+(\d)'), (m) => m.group(1)!);
}

/// ¿Coincide [texto] con lo que se buscó?
///
/// [campos] son los sitios donde tiene sentido buscar de ese registro: su
/// número, su título, el equipo, el área. Se juntan y se comparan contra cada
/// término.
bool coincideBusqueda(String buscado, Iterable<String?> campos) {
  final terminos = _terminos(buscado);
  if (terminos.isEmpty) return true;

  final heno = campos
      .where((c) => (c ?? '').isNotEmpty)
      .map((c) => normalizarBusqueda(c!))
      .join(' ');

  if (heno.isEmpty) return false;

  // TODOS los términos, no cualquiera: ver la nota de arriba.
  for (final t in terminos) {
    if (!heno.contains(t)) return false;
  }
  return true;
}

/// Los términos de la búsqueda, ya normalizados y sin los vacíos.
List<String> _terminos(String buscado) {
  final partes = buscado.trim().split(RegExp(r'\s+'));
  final salida = <String>[];

  for (final p in partes) {
    final n = normalizarBusqueda(p);
    if (n.isNotEmpty) salida.add(n);
  }

  return salida;
}

/// Quita las marcas diacríticas sin depender de `intl`.
///
/// Se hace con un mapa y no con `Normalize(FormD)` porque Dart no trae
/// normalización Unicode en el núcleo, y traer un paquete entero para cinco
/// vocales sería desproporcionado. La `ñ` **se conserva**: en castellano no es
/// una `n` con adorno, es otra letra, y «caña» y «cana» son cosas distintas.
String _quitarTildes(String t) {
  const mapa = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ç': 'c',
  };

  final sb = StringBuffer();
  for (final c in t.split('')) {
    sb.write(mapa[c] ?? c);
  }
  return sb.toString();
}
