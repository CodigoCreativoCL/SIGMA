import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'base_local_service.dart';

/// En qué estado está una operación encolada.
enum EstadoItem {
  /// Todavía no llegó al servidor. Se reintenta.
  pendiente,

  /// El servidor la aceptó.
  enviado,

  /// El servidor la rechazó con una razón. **No se reintenta**: reintentar no
  /// la va a arreglar. La persona tiene que corregir o descartar.
  rechazado,
}

/// Una operación esperando en la cola.
class ItemCola {
  const ItemCola({
    required this.id,
    required this.uuid,
    required this.tipo,
    required this.titulo,
    required this.estado,
    required this.fechaCaptura,
    this.detalle,
    this.intentos = 0,
    this.ultimoError,
    this.ultimoCodigo,
    this.idServidor,
  });

  final int id;
  final String uuid;
  final String tipo;
  final String titulo;
  final String? detalle;
  final EstadoItem estado;
  final DateTime fechaCaptura;
  final int intentos;
  final String? ultimoError;
  final int? ultimoCodigo;
  final int? idServidor;

  factory ItemCola.desde(Map<String, dynamic> f) => ItemCola(
        id: (f['id'] as num).toInt(),
        uuid: f['uuid'] as String,
        tipo: f['tipo'] as String,
        titulo: f['titulo'] as String,
        detalle: f['detalle'] as String?,
        estado: switch (f['estado'] as String?) {
          'enviado' => EstadoItem.enviado,
          'rechazado' => EstadoItem.rechazado,
          _ => EstadoItem.pendiente,
        },
        fechaCaptura:
            DateTime.tryParse(f['fecha_captura'] as String? ?? '') ??
                DateTime.now(),
        intentos: (f['intentos'] as num?)?.toInt() ?? 0,
        ultimoError: f['ultimo_error'] as String?,
        ultimoCodigo: (f['ultimo_codigo'] as num?)?.toInt(),
        idServidor: (f['id_servidor'] as num?)?.toInt(),
      );
}

/// La cola de salida (HU-151).
///
/// ## La regla, sin excepciones
///
/// **Toda escritura se guarda en disco primero y se envía después.** La
/// pantalla confirma con lo que ya está guardado, no esperando la red: hacer
/// esperar al técnico a que responda el servidor para decirle "guardado"
/// convierte una app offline-first en una online que a veces funciona.
///
/// ## Idempotencia
///
/// El `uuid` se genera **al encolar**, no al enviar. Generado al enviar, cada
/// reintento traería uno nuevo y la idempotencia no serviría de nada — que es
/// justo el caso del timeout, donde el servidor sí grabó pero la respuesta no
/// llegó. Por eso el **409 se trata como éxito**: es el duplicado del
/// reintento, no un error.
///
/// ## Nada se descarta
///
/// Un ítem que falla cinco veces por red pasa a `pendiente` con su motivo
/// visible, no a la basura. Lo único que lo saca de la cola es un veredicto
/// del servidor.
class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  final _base = BaseLocalService.instance;

  /// Cuántas operaciones esperan. Lo mira el badge de la barra superior.
  final ValueNotifier<int> pendientes = ValueNotifier<int>(0);

  bool _despachando = false;

  /// UUID v4 con `Random.secure()`.
  ///
  /// No con `Random()`, que se siembra con el reloj: dos teléfonos que encolan
  /// en el mismo milisegundo generarían el mismo identificador y el servidor
  /// descartaría uno de los dos movimientos como duplicado.
  static String nuevoUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Encola una operación. **Devuelve apenas está en disco**, sin esperar red.
  Future<String> encolar({
    required String tipo,
    required String titulo,
    required String endpoint,
    required Map<String, dynamic> cuerpo,
    String? uuid,
    String? detalle,
    String? agrupador,
    String metodo = 'POST',
  }) async {
    final id = uuid ?? nuevoUuid();

    await _base.encolar({
      'uuid': id,
      'tipo': tipo,
      'titulo': titulo,
      'detalle': detalle,
      'endpoint': endpoint,
      'metodo': metodo,
      // El uuid viaja DENTRO del cuerpo: es lo que el servidor usa para
      // reconocer el reintento.
      'cuerpo_json': jsonEncode({...cuerpo, 'uuid': id}),
      'agrupador': agrupador,
      'estado': 'pendiente',
      'fecha_captura': DateTime.now().toIso8601String(),
    });

    await _refrescarContador();
    return id;
  }

  Future<List<ItemCola>> listar() async {
    final filas = await _base.todosLosItems();
    return filas.map(ItemCola.desde).toList();
  }

  /// Intenta despachar todo lo pendiente.
  ///
  /// Reentrante seguro: si ya hay un despacho corriendo, este llamado no hace
  /// nada. Dos despachos en paralelo enviarían el mismo ítem dos veces.
  Future<void> despachar() async {
    if (_despachando) return;
    _despachando = true;

    try {
      final pend = await _base.pendientes();
      for (final f in pend) {
        await _enviarUno(f);
      }
    } finally {
      _despachando = false;
      await _refrescarContador();
    }
  }

  Future<void> _enviarUno(Map<String, dynamic> f) async {
    final id = (f['id'] as num).toInt();
    final intentos = ((f['intentos'] as num?)?.toInt() ?? 0) + 1;
    final cuerpo = jsonDecode(f['cuerpo_json'] as String) as Map<String, dynamic>;

    try {
      final r = await ApiClient.instance
          .post(f['endpoint'] as String, cuerpo);

      await _base.actualizarItem(id, {
        'estado': 'enviado',
        'intentos': intentos,
        'ultimo_codigo': 200,
        'ultimo_error': null,
        'id_servidor': (r is Map ? (r['id'] as num?)?.toInt() : null),
        'fecha_envio': DateTime.now().toIso8601String(),
      });
    } on ApiException catch (e) {
      // El 409 cierra el círculo de la idempotencia: el servidor ya lo tenía.
      // Sin esto, un ítem que SÍ entró queda para siempre en la cola mostrando
      // un error que no existe.
      if (e.duplicado) {
        await _base.actualizarItem(id, {
          'estado': 'enviado',
          'intentos': intentos,
          'ultimo_codigo': 409,
          'fecha_envio': DateTime.now().toIso8601String(),
        });
        return;
      }

      // Regla de negocio, sin permiso o no existe: reintentar no lo arregla.
      final definitivo = e.codigo != null &&
          const [400, 403, 404, 422].contains(e.codigo);

      await _base.actualizarItem(id, {
        'estado': definitivo ? 'rechazado' : 'pendiente',
        'intentos': intentos,
        'ultimo_codigo': e.codigo,
        // El mensaje del servidor se guarda tal cual: dice qué corregir.
        'ultimo_error': e.mensaje,
      });
    } catch (e) {
      await _base.actualizarItem(id, {
        'estado': 'pendiente',
        'intentos': intentos,
        'ultimo_error': '$e',
      });
    }
  }

  /// Vuelve a poner en cola un ítem rechazado, después de que la persona
  /// corrigió lo que el servidor reclamaba.
  Future<void> reintentar(int id) async {
    await _base.actualizarItem(id, {
      'estado': 'pendiente',
      'ultimo_error': null,
      'ultimo_codigo': null,
    });
    await _refrescarContador();
    await despachar();
  }

  Future<void> descartar(int id) async {
    await _base.actualizarItem(id, {'estado': 'enviado'});
    await _refrescarContador();
  }

  Future<void> _refrescarContador() async {
    pendientes.value = await _base.contarPendientes();
  }

  Future<void> init() => _refrescarContador();
}
