import 'package:flutter/foundation.dart';

import 'base_local_service.dart';

/// Leer lo que bajó la sincronización (HU-150, HU-151).
///
/// ## Por qué existe
///
/// La sábana de datos ya se bajaba y se guardaba en `cache_datos` desde el
/// primer día, y **nadie la leía**: cada pantalla pedía su endpoint. El efecto
/// era el peor posible —la app descargaba todo lo necesario para trabajar sin
/// señal y, sin señal, no mostraba nada—. Este archivo es la otra mitad.
///
/// ## Las dos formas del mismo dato
///
/// El SP de la sábana devuelve las columnas en MAYÚSCULAS —`ACT_ID`,
/// `ACT_CODIGO`— porque es la convención de los `SEL_` del grupo. Los endpoints
/// devuelven el DTO de C#, cuyas propiedades van en minúscula —`act_id`—, y los
/// `fromJson` de la app están escritos contra esa segunda forma.
///
/// Traducir columna por columna sería un diccionario de trescientas entradas
/// que hay que mantener cada vez que alguien agrega un campo. En vez de eso,
/// [conClavesTolerantes] deja cada valor accesible por su nombre en los dos
/// casos, y **el mismo `fromJson` sirve para la red y para el disco**. Es la
/// diferencia entre tener un modelo o tener dos que se desincronizan.
abstract final class CacheDatos {
  /// Los nombres con que la sincronización guarda cada bloque.
  ///
  /// Salen de `Bloque.codigo`, y los bloques que traen varios resultados se
  /// guardan con sufijo `_0`, `_1`… Están acá y no repetidos en el repositorio
  /// para que cambiar uno no deje al otro leyendo una entidad que ya no se
  /// escribe — un error que no falla, solo devuelve vacío.
  static const organizacion = 'ORGANIZACION';
  static const areas = 'AREAS';

  /// Las cabeceras de los catálogos.
  ///
  /// **Con sufijo `_0` desde que el bloque 3 trae también los valores.** La
  /// sincronización numera los resultados solo cuando hay más de uno, así que
  /// el día que se agregó el segundo, esta entidad cambió de nombre. Dejarla
  /// como `CATALOGOS` no habría fallado: habría devuelto vacío.
  static const catalogos = 'CATALOGOS_0';

  /// Los valores de TODOS los catálogos, con el código de su catálogo en cada
  /// fila. Es lo que hace que los chips de catálogo existan sin señal.
  static const catalogoValores = 'CATALOGOS_1';
  static const activos = 'ACTIVOS';
  static const medidores = 'MEDICION_0';
  static const repuestos = 'INVENTARIO_0';
  static const bodegas = 'INVENTARIO_1';
  static const existencias = 'EXISTENCIAS';
  static const permisosTipos = 'PERMISOS_TRABAJO_0';
  static const permisosEstados = 'PERMISOS_TRABAJO_1';

  /// Los motivos de cierre de OT (HU-120). Bajan con la sábana porque el
  /// cierre es una acción de terreno: pedidos por red, sin señal la hoja no
  /// muestra ningún chip y no se puede cerrar.
  /// Sin sufijo `_0`: la sincronización solo numera los bloques que traen
  /// VARIOS resultados, y éste trae uno. Con el sufijo la lectura no falla,
  /// devuelve vacío — y la hoja de cierre se quedaría sin chips sin decir
  /// por qué.
  static const motivosCierre = 'ORDENES_TRABAJO';

  static final _base = BaseLocalService.instance;

  /// Lo guardado de una entidad, ya mapeado.
  ///
  /// Nunca lanza: si la base local no se puede abrir o una fila está corrupta,
  /// se devuelve lo que sí se pudo leer. Una pantalla vacía es mala; una
  /// pantalla que revienta sin señal deja al técnico sin nada que hacer.
  static Future<List<T>> lista<T>(
    String entidad,
    T Function(Map<String, dynamic>) desde,
  ) async {
    try {
      final filas = await _base.leerLista(entidad);
      final salida = <T>[];

      for (final f in filas) {
        try {
          salida.add(desde(conClavesTolerantes(f)));
        } catch (e) {
          debugPrint('[CacheDatos] Fila ilegible en $entidad: $e');
        }
      }

      return salida;
    } catch (e) {
      debugPrint('[CacheDatos] No se pudo leer $entidad: $e');
      return const [];
    }
  }

  /// Una sola fila, buscada por el valor de una columna.
  ///
  /// Se filtra en Dart y no con un `WHERE` sobre `cache_datos` porque el JSON
  /// se guarda como texto: consultar dentro de él obligaría a un índice por
  /// entidad, y los volúmenes de un teléfono —miles de filas, no millones— no
  /// lo justifican.
  static Future<T?> uno<T>(
    String entidad,
    T Function(Map<String, dynamic>) desde,
    String columna,
    Object valor,
  ) async {
    try {
      final filas = await _base.leerLista(entidad);
      final buscado = '$valor';

      for (final f in filas) {
        final tolerante = conClavesTolerantes(f);
        if ('${tolerante[columna]}' != buscado) continue;
        return desde(tolerante);
      }
    } catch (e) {
      debugPrint('[CacheDatos] No se pudo leer $entidad/$columna: $e');
    }
    return null;
  }

  /// De cuándo es lo guardado. Es lo que la pantalla muestra al pie cuando no
  /// hay señal: sin la fecha, un dato viejo y uno recién bajado se ven igual.
  static Future<DateTime?> fechaDe(String entidad) => _base.fechaDe(entidad);

  /// El mismo valor accesible por `ACT_ID` y por `act_id`.
  ///
  /// No se elige una de las dos formas a propósito. Bajarlo todo a minúsculas
  /// rompería los campos que el servidor ya manda en mayúsculas por contrato
  /// —`PLANTA_NOMBRE`, `ESTADO_CODIGO`—, y subirlo todo a mayúsculas rompería
  /// los `act_id`. Con las dos presentes, cualquier `fromJson` encuentra lo
  /// suyo sin que haya que tocarlo.
  @visibleForTesting
  static Map<String, dynamic> conClavesTolerantes(Map<String, dynamic> fila) {
    final salida = <String, dynamic>{};

    for (final e in fila.entries) {
      salida[e.key] = e.value;

      final minuscula = e.key.toLowerCase();
      final mayuscula = e.key.toUpperCase();

      // `putIfAbsent`: si la fila ya trae las dos formas —no debería, pero un
      // SP puede— manda la original y no la que se derivó.
      salida.putIfAbsent(minuscula, () => e.value);
      salida.putIfAbsent(mayuscula, () => e.value);
    }

    return salida;
  }
}
