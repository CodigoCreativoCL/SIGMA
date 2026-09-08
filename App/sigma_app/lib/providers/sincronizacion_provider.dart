import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/base_local_service.dart';
import '../services/sync_service.dart';
import '../services/sigma_repository.dart';

/// En qué va cada bloque de la carga descendente.
enum EstadoBloque { enCola, enCurso, listo, fallido }

/// Un bloque de datos que baja al dispositivo (HU-150).
class Bloque {
  const Bloque({
    required this.numero,
    required this.codigo,
    required this.nombre,
    required this.icono,
    this.estado = EstadoBloque.enCola,
    this.filas = 0,
    this.total = 0,
    this.error,
  });

  /// El `@TIPO` del SP.
  final int numero;

  /// ORGANIZACION, AREAS, CATALOGOS… Es la clave con la que se guarda en la
  /// base local.
  final String codigo;

  final String nombre;
  final String icono;
  final EstadoBloque estado;

  /// Filas guardadas y el total que declaró el manifiesto.
  final int filas;
  final int total;

  final String? error;

  double get avance => total == 0 ? 0 : (filas / total).clamp(0, 1);

  Bloque copyWith({
    EstadoBloque? estado,
    int? filas,
    int? total,
    String? error,
  }) =>
      Bloque(
        numero: numero,
        codigo: codigo,
        nombre: nombre,
        icono: icono,
        estado: estado ?? this.estado,
        filas: filas ?? this.filas,
        total: total ?? this.total,
        error: error ?? this.error,
      );
}

class SincronizacionEstado {
  const SincronizacionEstado({
    this.bloques = const [],
    this.corriendo = false,
    this.termino = false,
    this.fechaCorte,
  });

  final List<Bloque> bloques;
  final bool corriendo;
  final bool termino;

  /// La hora **del servidor** en que se armó el paquete. Es la que se manda
  /// como `desde` la próxima vez.
  final DateTime? fechaCorte;

  int get listos => bloques.where((b) => b.estado == EstadoBloque.listo).length;
  int get fallidos =>
      bloques.where((b) => b.estado == EstadoBloque.fallido).length;

  /// El avance global es el promedio de los bloques, no el de las filas: un
  /// bloque de 3.000 activos no puede hacer que los otros siete parezcan no
  /// existir.
  double get avance => bloques.isEmpty
      ? 0
      : bloques
              .map((b) => b.estado == EstadoBloque.listo ? 1.0 : b.avance)
              .reduce((a, b) => a + b) /
          bloques.length;

  int get porcentaje => (avance * 100).round();
  int get filasTotales => bloques.fold<int>(0, (a, b) => a + b.filas);

  SincronizacionEstado copyWith({
    List<Bloque>? bloques,
    bool? corriendo,
    bool? termino,
    DateTime? fechaCorte,
  }) =>
      SincronizacionEstado(
        bloques: bloques ?? this.bloques,
        corriendo: corriendo ?? this.corriendo,
        termino: termino ?? this.termino,
        fechaCorte: fechaCorte ?? this.fechaCorte,
      );
}

/// La carga descendente (HU-150): baja el paquete y **lo guarda en SQLite**.
///
/// ## Cómo funciona
///
/// 1. Pide el **manifiesto** (`GET /sincronizacion`): qué bloques hay, cuántas
///    filas trae cada uno y la hora del servidor. Con eso la barra de progreso
///    es real, no una animación.
/// 2. Baja cada bloque (`GET /sincronizacion/{tipo}`) y **vuelca cada
///    resultado a `cache_datos`** con su fecha. Eso es lo que la app lee
///    cuando no hay señal.
/// 3. Guarda la **fecha de corte del servidor**, que se manda como `desde` la
///    próxima vez.
///
/// ## Tres decisiones
///
/// **La fecha de corte es la del servidor, nunca la del teléfono.** Un aparato
/// con el reloj corrido se saltaría registros para siempre.
///
/// **Un bloque que falla no detiene la cola.** Que no haya permiso de bodegas
/// no puede dejar al técnico sin sus activos: se marca, se sigue, y el motivo
/// que dijo el servidor queda visible.
///
/// **El orden importa.** Los tres primeros bloques son los que la app necesita
/// para dibujar algo; si el cuarto falla, con esos tres ya se puede trabajar.
class SincronizacionNotifier extends Notifier<SincronizacionEstado> {
  final _repo = SigmaRepository.instance;
  final _base = BaseLocalService.instance;

  /// Qué clave identifica cada fila dentro de su bloque. Sin esto no se puede
  /// reemplazar una fila sin duplicarla.
  static const _claves = <String, String>{
    'ORGANIZACION': 'CIN_ID',
    'AREAS': 'IAR_ID',
    'CATALOGOS': 'CTL_ID',
    'ACTIVOS': 'ACT_ID',
    'MEDICION': 'AME_ID',
    'INVENTARIO': 'REP_ID',
    'EXISTENCIAS': 'ISA_ID',
    'PERMISOS_TRABAJO': 'PTT_ID',
  };

  static const _iconos = <String, String>{
    'ORGANIZACION': 'badge',
    'AREAS': 'map',
    'CATALOGOS': 'category',
    'ACTIVOS': 'activo',
    'MEDICION': 'medidor',
    'INVENTARIO': 'inventory',
    'EXISTENCIAS': 'stock',
    'PERMISOS_TRABAJO': 'assignment',
  };

  /// Cuándo terminó la última sincronización automática.
  ///
  /// No se persiste a propósito: es memoria de *esta* ejecución de la app. La
  /// fecha de corte que sí importa —la que decide qué se pide— vive en
  /// `cache_meta`, en disco.
  DateTime? _ultimaAutomatica;

  /// Cada cuánto puede repetirse la sincronización automática.
  ///
  /// Entrar a un menú tiene que traer datos frescos, pero un técnico que pasa
  /// de Órdenes a Activos y vuelve en diez segundos no puede disparar tres
  /// descargas completas: gasta datos, batería y deja las pantallas
  /// recargándose bajo el dedo.
  static const _cadaCuanto = Duration(minutes: 3);

  @override
  SincronizacionEstado build() => const SincronizacionEstado();

  /// Sincroniza **si hace falta**, sin que la pantalla espere.
  ///
  /// Es la que se llama al entrar a la app y al abrir cada menú. Se distingue
  /// de [sincronizar] en tres cosas, y las tres son la diferencia entre algo
  /// que ayuda y algo que estorba:
  ///
  ///   · **No corre sin señal.** Sin red, lo que hay en disco es lo que hay.
  ///   · **No corre si ya corrió hace poco** ([_cadaCuanto]).
  ///   · **Es incremental**: pide lo que cambió desde el último corte, no la
  ///     sábana entera.
  ///
  /// [forzar] la usa el ingreso: recién iniciada la sesión hay que bajar todo
  /// una vez, aunque la app llevara abierta un rato en la pantalla de login.
  Future<void> asegurar({bool forzar = false}) async {
    if (state.corriendo) return;
    if (!SyncService.instance.enLinea.value) return;

    if (!forzar) {
      final ultima = _ultimaAutomatica;
      if (ultima != null && DateTime.now().difference(ultima) < _cadaCuanto) {
        return;
      }
    }

    _ultimaAutomatica = DateTime.now();
    await sincronizar();
  }

  Future<void> sincronizar({bool incremental = true}) async {
    if (state.corriendo) return;
    state = state.copyWith(corriendo: true, termino: false);

    // 1 · El manifiesto. Sin él no se sabe qué pedir ni cuánto es "todo".
    List<Bloque> bloques;
    DateTime? corte;

    try {
      final m = await _repo.manifiesto();
      corte = DateTime.tryParse('${m['servidor_fecha_utc']}');

      bloques = ((m['bloques'] as List?) ?? const []).map((e) {
        final b = (e as Map).cast<String, dynamic>();
        final codigo = '${b['CODIGO']}';
        return Bloque(
          numero: (b['BLOQUE'] as num?)?.toInt() ?? 0,
          codigo: codigo,
          nombre: '${b['NOMBRE']}',
          icono: _iconos[codigo] ?? 'category',
          total: (b['FILAS'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      state = state.copyWith(bloques: bloques, fechaCorte: corte);
    } on ApiException catch (e) {
      // Sin manifiesto no hay nada que hacer, pero lo que ya está en disco
      // sigue sirviendo: la app no queda inutilizable.
      state = state.copyWith(
        corriendo: false,
        termino: true,
        bloques: [
          Bloque(
            numero: 0,
            codigo: 'MANIFIESTO',
            nombre: 'No se pudo consultar el paquete',
            icono: 'category',
            estado: EstadoBloque.fallido,
            error: e.mensaje,
          ),
        ],
      );
      return;
    }

    // 2 · Bloque por bloque, a disco.
    final desde = incremental ? await _base.fechaDe('_corte') : null;

    for (var i = 0; i < bloques.length; i++) {
      _marcar(i, (b) => b.copyWith(estado: EstadoBloque.enCurso));

      try {
        final resultados = await _repo.bloque(bloques[i].numero, desde: desde);

        var guardadas = 0;
        for (var r = 0; r < resultados.length; r++) {
          final filas = resultados[r];
          if (filas.isEmpty) continue;

          // Cada resultado se guarda con su propia entidad: el bloque 6 trae
          // repuestos, bodegas, ubicaciones y tipos, y mezclarlos en una sola
          // clave los volvería inseparables al leerlos.
          final entidad = resultados.length == 1
              ? bloques[i].codigo
              : '${bloques[i].codigo}_$r';

          await _base.guardarLista(
            entidad,
            filas,
            (f) => _claveDe(f, bloques[i].codigo),
          );
          guardadas += filas.length;
        }

        _marcar(
            i,
            (b) => b.copyWith(
                estado: EstadoBloque.listo,
                filas: guardadas,
                total: b.total == 0 ? (guardadas == 0 ? 1 : guardadas) : b.total));
      } on ApiException catch (e) {
        // El mensaje del servidor se conserva: un 403 dice qué permiso falta,
        // y eso es accionable. "Error de sincronización" no lo es.
        _marcar(i,
            (b) => b.copyWith(estado: EstadoBloque.fallido, error: e.mensaje));
      } catch (e) {
        debugPrint('[Sincronizacion] Bloque ${bloques[i].codigo}: $e');
        _marcar(
            i, (b) => b.copyWith(estado: EstadoBloque.fallido, error: '$e'));
      }
    }

    // 3 · La fecha de corte, para el próximo incremental.
    //
    // Solo se guarda si TODO llegó: guardarla con un bloque fallido haría que
    // la próxima sincronización pidiera "lo que cambió desde entonces" y ese
    // bloque nunca se completara.
    if (corte != null && state.fallidos == 0) {
      await _base.guardarLista('_corte', [
        {'fecha': corte.toIso8601String()}
      ], (_) => 'corte');
    }

    state = state.copyWith(corriendo: false, termino: true);
  }

  /// La clave de una fila. Si el bloque no la declara o la fila no la trae,
  /// se usa el JSON entero: es peor guardar dos veces la misma fila que
  /// guardar una clave fea.
  String _claveDe(Map<String, dynamic> fila, String codigo) {
    final col = _claves[codigo];
    final v = col == null ? null : fila[col];
    return v?.toString() ?? fila.values.join('|');
  }

  void _marcar(int i, Bloque Function(Bloque) cambio) {
    final lista = [...state.bloques];
    if (i >= lista.length) return;
    lista[i] = cambio(lista[i]);
    state = state.copyWith(bloques: lista);
  }
}

final sincronizacionProvider =
    NotifierProvider<SincronizacionNotifier, SincronizacionEstado>(
        SincronizacionNotifier.new);
