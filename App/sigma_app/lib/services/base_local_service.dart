import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// La base local: `sigma_local.db`.
///
/// Hace dos cosas, y las dos son la razón de que esta app sirva en una planta:
///
///   1. **Guarda lo que bajó** para poder mirarlo sin señal, con la fecha en
///      que se bajó — porque sin conexión lo único que distingue un dato útil
///      de uno viejo es saber de cuándo es.
///   2. **Guarda la cola de salida** (`outbox`): todo lo que la persona
///      registra se escribe acá **antes** de intentar enviarlo. Nunca al
///      revés. Si la app enviara primero y el envío fallara, el trabajo se
///      perdió y nadie se entera hasta que alguien reclama.
///
/// ## Reglas del esquema
///
///   · Las columnas se llaman **igual que en SQL Server**. Traducir nombres
///     obliga a mantener un diccionario mental entre tres capas.
///   · **Nada de base64 en una columna.** Se guarda la ruta del archivo. Una
///     imagen en base64 pesa ~400 KB de texto y el `CursorWindow` de Android
///     revienta a los 2 MB — y revienta al *leer*, mucho después de haber
///     guardado, que es la peor forma de fallar.
///   · Las migraciones son escalones acumulativos y **no se editan una vez
///     publicadas**: hay teléfonos con esa versión.
/// Fuera de la clase porque `compute` solo acepta funciones de nivel superior:
/// lo que cruza a otro isolate no puede arrastrar un `this`.
List<Map<String, dynamic>> _decodificar(List<String> filas) =>
    [for (final f in filas) jsonDecode(f) as Map<String, dynamic>];

List<String> _codificar(List<Map<String, dynamic>> filas) =>
    [for (final f in filas) jsonEncode(f)];

class BaseLocalService {
  BaseLocalService._();
  static final BaseLocalService instance = BaseLocalService._();

  static const _version = 2;
  static const _archivo = 'sigma_local.db';

  Database? _db;

  Future<Database> get db async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), _archivo);
    return openDatabase(
      ruta,
      version: _version,
      onCreate: (d, _) async => _v1(d),
      onUpgrade: (d, anterior, _) async {
        // Escalones acumulativos, uno por versión. El comentario de cada uno
        // dice POR QUÉ cambió, no qué cambió: el qué ya lo dice el SQL.
        if (anterior < 1) await _v1(d);
        if (anterior < 2) await _v2(d);
      },
    );
  }

  Future<void> _v1(Database d) async {
    // ---- La cola de salida ----
    //
    // Una tabla única, no una marca `enviado` por tabla: SIGMA captura seis
    // tipos de escritura, y con una marca por tabla cada módulo termina con
    // su propio reintento, su propio orden y su propia forma de fallar.
    await d.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid           TEXT    NOT NULL UNIQUE,
        tipo           TEXT    NOT NULL,
        titulo         TEXT    NOT NULL,
        detalle        TEXT,
        endpoint       TEXT    NOT NULL,
        metodo         TEXT    NOT NULL DEFAULT 'POST',
        cuerpo_json    TEXT    NOT NULL,
        adjuntos_json  TEXT,
        agrupador      TEXT,
        estado         TEXT    NOT NULL DEFAULT 'pendiente',
        intentos       INTEGER NOT NULL DEFAULT 0,
        ultimo_error   TEXT,
        ultimo_codigo  INTEGER,
        id_servidor    INTEGER,
        fecha_captura  TEXT    NOT NULL,
        fecha_envio    TEXT
      )
    ''');

    // El orden de despacho: primero lo pendiente, y dentro de eso lo más
    // antiguo. Una entrega registrada antes que su corrección tiene que
    // llegar antes.
    await d.execute(
        'CREATE INDEX IF NOT EXISTS ix_outbox_cola ON outbox (estado, agrupador, id)');

    // ---- Lo que baja al dispositivo ----
    //
    // Una sola tabla genérica en vez de una por entidad. El JSON del servidor
    // se guarda tal cual y se mapea con el mismo `fromJson` que ya existe: así
    // agregar una entidad al paquete offline no es una migración.
    await d.execute('''
      CREATE TABLE IF NOT EXISTS cache_datos (
        entidad     TEXT    NOT NULL,
        clave       TEXT    NOT NULL,
        json        TEXT    NOT NULL,
        sync_fecha  TEXT    NOT NULL,
        PRIMARY KEY (entidad, clave)
      )
    ''');

    await d.execute('''
      CREATE TABLE IF NOT EXISTS cache_meta (
        entidad     TEXT PRIMARY KEY,
        sync_fecha  TEXT NOT NULL,
        total       INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// v2 — los tramos del cronómetro.
  ///
  /// ## Por qué en disco y no en memoria
  ///
  /// Un turno dura ocho horas y el teléfono se bloquea, se queda sin batería,
  /// se cierra la app o suena una llamada. Un cronómetro en memoria pierde el
  /// tiempo trabajado en cualquiera de esas cuatro, y el técnico se entera al
  /// final, cuando ya no puede reconstruirlo.
  ///
  /// ## Por qué TRAMOS y no un contador
  ///
  /// Guardar «llevo 43 minutos» obliga a escribir en disco todo el rato y aun
  /// así pierde el tramo en curso si el proceso muere. Un tramo con su inicio
  /// —y su fin cuando se pausa— se escribe **dos veces por tramo** y el tiempo
  /// se calcula al leer: si la app muere con el cronómetro corriendo, al
  /// volver sigue contando desde el inicio real, que es lo que de verdad pasó.
  ///
  /// Y son los mismos tramos que después alimentan la mano de obra de una OT:
  /// no hay que inventar un segundo registro del mismo hecho.
  Future<void> _v2(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS cronometro (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entidad     TEXT    NOT NULL,
        entidad_id  INTEGER NOT NULL,
        inicio      TEXT    NOT NULL,
        fin         TEXT
      )
    ''');

    // Se consulta siempre por entidad, y el tramo abierto es el ultimo.
    await d.execute('CREATE INDEX IF NOT EXISTS ix_cronometro_entidad '
        'ON cronometro (entidad, entidad_id, id)');
  }

  // ----------------------------------------------------------- cronómetro --

  /// Los tramos de algo, en orden.
  Future<List<Map<String, dynamic>>> tramos(String entidad, int id) async {
    final d = await db;
    return d.query('cronometro',
        where: 'entidad = ? AND entidad_id = ?',
        whereArgs: [entidad, id],
        orderBy: 'id ASC');
  }

  Future<void> abrirTramo(String entidad, int id) async {
    final d = await db;
    await d.insert('cronometro', {
      'entidad': entidad,
      'entidad_id': id,
      'inicio': DateTime.now().toIso8601String(),
    });
  }

  /// Cierra el tramo abierto, si lo hay. Es idempotente: pausar dos veces no
  /// puede restar tiempo ni dejar dos tramos abiertos.
  Future<void> cerrarTramo(String entidad, int id) async {
    final d = await db;
    await d.update(
      'cronometro',
      {'fin': DateTime.now().toIso8601String()},
      where: 'entidad = ? AND entidad_id = ? AND fin IS NULL',
      whereArgs: [entidad, id],
    );
  }

  /// Al cerrar la gestión: los tramos ya se enviaron dentro de ella.
  Future<void> borrarTramos(String entidad, int id) async {
    final d = await db;
    await d.delete('cronometro',
        where: 'entidad = ? AND entidad_id = ?', whereArgs: [entidad, id]);
  }

  // ---------------------------------------------------------------- caché --

  /// Reemplaza lo guardado de una entidad por lo que acaba de bajar.
  ///
  /// En una transacción: si el borrado ocurre y la inserción falla, la app se
  /// queda sin los datos que sí tenía, que es peor que tenerlos viejos.
  Future<void> guardarLista(
    String entidad,
    List<Map<String, dynamic>> filas,
    String Function(Map<String, dynamic>) claveDe,
  ) async {
    final d = await db;
    final ahora = DateTime.now().toIso8601String();

    // Serializar ANTES de abrir la transacción, y fuera del hilo de la
    // interfaz cuando el bloque es grande: `jsonEncode` de tres mil activos
    // dentro de la transacción la mantiene abierta mientras se congela el
    // dibujo, que es exactamente el momento en que la barra de progreso de la
    // sincronización tiene que moverse.
    final codificadas = filas.length >= _umbralIsolate
        ? await compute(_codificar, filas)
        : _codificar(filas);

    await d.transaction((t) async {
      await t.delete('cache_datos', where: 'entidad = ?', whereArgs: [entidad]);
      final lote = t.batch();
      for (var i = 0; i < filas.length; i++) {
        lote.insert(
          'cache_datos',
          {
            'entidad': entidad,
            'clave': claveDe(filas[i]),
            'json': codificadas[i],
            'sync_fecha': ahora,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await lote.commit(noResult: true);
      await t.insert(
        'cache_meta',
        {'entidad': entidad, 'sync_fecha': ahora, 'total': filas.length},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// A partir de esta cantidad de filas, decodificar en el hilo de la interfaz
  /// se nota: `jsonDecode` es sincrónico y mientras corre la app no dibuja.
  /// Con menos filas, saltar a otro isolate cuesta más de lo que ahorra.
  static const _umbralIsolate = 300;

  Future<List<Map<String, dynamic>>> leerLista(String entidad) async {
    final d = await db;
    final filas = await d.query('cache_datos',
        columns: ['json'], where: 'entidad = ?', whereArgs: [entidad]);

    final crudo = [for (final f in filas) f['json'] as String];

    // El listado de activos de una planta son miles de filas, y abrir la
    // pantalla sin señal las decodifica TODAS. Hacerlo en el hilo de la
    // interfaz congelaba el scroll justo al entrar.
    return crudo.length >= _umbralIsolate
        ? await compute(_decodificar, crudo)
        : _decodificar(crudo);
  }

  /// De cuándo es lo que hay guardado. Es lo que la pantalla muestra al pie
  /// cuando no hay señal.
  Future<DateTime?> fechaDe(String entidad) async {
    final d = await db;
    final f = await d.query('cache_meta',
        where: 'entidad = ?', whereArgs: [entidad], limit: 1);
    if (f.isEmpty) return null;
    return DateTime.tryParse(f.first['sync_fecha'] as String);
  }

  // ----------------------------------------------------------------- cola --

  Future<int> encolar(Map<String, dynamic> item) async {
    final d = await db;
    return d.insert('outbox', item,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Lo pendiente, en orden de captura.
  Future<List<Map<String, dynamic>>> pendientes() async {
    final d = await db;
    return d.query('outbox',
        where: 'estado = ?', whereArgs: ['pendiente'], orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> todosLosItems() async {
    final d = await db;
    return d.query('outbox', orderBy: 'id DESC', limit: 200);
  }

  Future<void> actualizarItem(int id, Map<String, dynamic> cambios) async {
    final d = await db;
    await d.update('outbox', cambios, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarPendientes() async {
    final d = await db;
    final r = await d.rawQuery(
        "SELECT COUNT(*) c FROM outbox WHERE estado IN ('pendiente','rechazado')");
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Borra lo ya enviado. Se llama de vez en cuando: la cola es un registro de
  /// trabajo en tránsito, no un historial.
  Future<void> purgarEnviados() async {
    final d = await db;
    await d.delete('outbox', where: 'estado = ?', whereArgs: ['enviado']);
  }

  /// Al cerrar sesión.
  ///
  /// **La cola NO se borra.** Contiene trabajo que todavía no llegó al
  /// servidor; borrarla es perder trabajo hecho. Se conserva y se reenvía
  /// cuando esa misma persona vuelva a entrar.
  Future<void> limpiarCache() async {
    try {
      final d = await db;
      await d.delete('cache_datos');
      await d.delete('cache_meta');
    } catch (e) {
      debugPrint('[BaseLocal] No se pudo limpiar la caché: $e');
    }
  }
}
