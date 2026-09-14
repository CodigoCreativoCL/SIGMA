import '../constants/api_constants.dart';
import '../models/modelos.dart';
import 'api_client.dart';
import 'cache_datos.dart';
import 'outbox_service.dart';
import 'sync_service.dart';

/// El único sitio que sabe qué endpoint corresponde a cada cosa.
///
/// No decide nada: pide, mapea y devuelve. Qué hacer con un 403 —mostrarlo,
/// esconder un botón, encolar— es de las capas de arriba, y qué se dibuja es
/// de la pantalla. Ver `MD/SIGMA_APP_ARQUITECTURA.md` §5.
///
/// ## Lo que sí decide: de dónde sale el dato (HU-151)
///
/// Para lo que la sincronización dejó en el teléfono, este repositorio elige
/// entre la red y el disco con una regla que no admite excepciones:
///
///   · **Sin señal se va directo al disco.** No se intenta la red «por si
///     acaso»: son quince segundos de espera por pantalla para terminar en el
///     mismo sitio, y en una sala de máquinas eso pasa todo el día.
///   · **Con señal manda el servidor**, y si la red falla se cae al disco.
///   · **Un error de negocio no se tapa con la caché.** Un 403 es un 403
///     también sin señal: mostrar datos viejos a quien perdió el permiso es
///     peor que no mostrar nada.
class SigmaRepository {
  SigmaRepository._();
  static final SigmaRepository instance = SigmaRepository._();

  final _api = ApiClient.instance;

  /// Lee de la red o del disco, según lo de arriba.
  ///
  /// [entidad] es la clave con que la sincronización guardó el bloque; [desde]
  /// es el mismo `fromJson` que usa la respuesta del endpoint.
  Future<List<T>> _conRespaldo<T>({
    required String entidad,
    required T Function(Map<String, dynamic>) desde,
    required Future<List<T>> Function() red,
  }) async {
    if (!SyncService.instance.enLinea.value) {
      return CacheDatos.lista<T>(entidad, desde);
    }

    try {
      return await red();
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;

      // La red se cayó entre el chequeo y la petición —o el servidor no
      // responde—. Lo guardado sigue sirviendo; si no hay nada guardado, el
      // error original es más honesto que una lista vacía.
      final local = await CacheDatos.lista<T>(entidad, desde);
      if (local.isEmpty) rethrow;
      return local;
    }
  }

  /// Igual que [_conRespaldo], pero conservando el **total del servidor**.
  ///
  /// Importa: los listados vienen paginados de a 50 y `total` es cuántos hay
  /// en total, no cuántos llegaron. Armar el `Paginado` con el largo de la
  /// página hacía que el contador de la pantalla dijera «50» en una bodega con
  /// trescientos repuestos. Del disco sí vale el largo: ahí está todo.
  Future<Paginado<T>> _paginadoConRespaldo<T>({
    required String entidad,
    required T Function(Map<String, dynamic>) desde,
    required Future<Paginado<T>> Function() red,
  }) async {
    if (!SyncService.instance.enLinea.value) {
      return _deCache<T>(entidad, desde);
    }

    try {
      return await red();
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;
      final local = await _deCache<T>(entidad, desde);
      if (local.vacio) rethrow;
      return local;
    }
  }

  Future<Paginado<T>> _deCache<T>(
    String entidad,
    T Function(Map<String, dynamic>) desde,
  ) async {
    final l = await CacheDatos.lista<T>(entidad, desde);
    return Paginado(datos: l, total: l.length, paginas: l.isEmpty ? 0 : 1);
  }

  /// Igual que [_conRespaldo] para un registro suelto, buscado por su columna
  /// de identidad dentro del bloque guardado.
  Future<T> _unoConRespaldo<T>({
    required String entidad,
    required T Function(Map<String, dynamic>) desde,
    required String columna,
    required Object valor,
    required Future<T> Function() red,
  }) async {
    if (!SyncService.instance.enLinea.value) {
      final local = await CacheDatos.uno<T>(entidad, desde, columna, valor);
      if (local != null) return local;
      throw const ApiException(
        'Sin conexión y sin este dato descargado. Sincroniza cuando tengas '
        'señal.',
        esDeNegocio: false,
      );
    }

    try {
      return await red();
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;
      final local = await CacheDatos.uno<T>(entidad, desde, columna, valor);
      if (local != null) return local;
      rethrow;
    }
  }

  // ---- Identidad y navegación (Sprint 1) ----

  Future<MiPerfil> miPerfil() async {
    final j = await _api.get(ApiConstants.miPerfil);
    return MiPerfil.fromJson(j as Map<String, dynamic>);
  }

  Future<List<MenuNodo>> menus() async {
    final j = await _api.get(ApiConstants.menus);
    return Paginado.desde(j, MenuNodo.fromJson).datos;
  }

  /// Los códigos de permiso de quien entró.
  ///
  /// La app esconde lo que la persona no puede hacer —un botón que siempre
  /// responde 403 es un botón roto—, pero **la comprobación de verdad está en
  /// el servidor**, no acá.
  Future<Set<String>> permisos() async {
    final j = await _api.get(ApiConstants.permisos, query: {'tamano': 200});
    final p = Paginado.desde(j, (m) => (m['prm_codigo'] as String?) ?? '');
    return p.datos.where((s) => s.isNotEmpty).toSet();
  }

  // ---- Lo que baja al dispositivo (HU-150) ----

  Future<Paginado<ClienteInstalacion>> plantas({int pagina = 1}) =>
      _paginadoConRespaldo<ClienteInstalacion>(
        entidad: CacheDatos.organizacion,
        desde: ClienteInstalacion.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.clienteInstalaciones,
            query: {'pagina': pagina, 'tamano': 50},
          );
          return Paginado.desde(j, ClienteInstalacion.fromJson);
        },
      );

  Future<Paginado<InstalacionArea>> areas({int pagina = 1}) =>
      _paginadoConRespaldo<InstalacionArea>(
        entidad: CacheDatos.areas,
        desde: InstalacionArea.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.instalacionAreas,
            query: {'pagina': pagina, 'tamano': 50},
          );
          return Paginado.desde(j, InstalacionArea.fromJson);
        },
      );

  Future<Paginado<Catalogo>> catalogos({int pagina = 1}) =>
      _paginadoConRespaldo<Catalogo>(
        entidad: CacheDatos.catalogos,
        desde: Catalogo.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.catalogos,
            query: {'pagina': pagina, 'tamano': 50},
          );
          return Paginado.desde(j, Catalogo.fromJson);
        },
      );

  // ---- Activos (Sprint 2) ----

  Future<Paginado<ActivoFichaEvento>> fichaActivo(int id) async {
    final j = await _api.get('${ApiConstants.activos}/$id/ficha');
    return Paginado.desde(j, ActivoFichaEvento.fromJson);
  }

  // ---- Componentes y medidores (vistas 8.x y 9.2) ----

  /// Los componentes de un equipo, o de toda la planta si `activo` es nulo.
  ///
  /// **No sale de la sábana y no tiene respaldo en disco**, a diferencia de
  /// los activos. No es un olvido: la sábana baja lo que se necesita
  /// *delante del equipo y sin señal* —la orden, la pauta, el activo— y la
  /// lista de componentes se mira antes de bajar, con señal. Meterla en la
  /// sábana engordaría la descarga de todos para un caso que no la necesita.
  ///
  /// La consecuencia se dice en la pantalla en vez de esconderse: sin señal,
  /// la lista no está.
  Future<Paginado<Componente>> componentes({
    int? activo,
    String? filtro,
    int pagina = 1,
  }) async {
    final j = await _api.get(
      ApiConstants.componentes,
      query: {
        'pagina': pagina,
        'tamano': 50,
        'activo': ?activo,
        if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
      },
    );
    return Paginado.desde(j, Componente.fromJson);
  }

  /// La ficha de un componente — vista 8.2. Trae fotos y medidores.
  Future<Componente> componente(int id) async {
    final j = await _api.get('${ApiConstants.componentes}/$id');
    return Componente.fromJson(j as Map<String, dynamic>);
  }

  /// La línea de tiempo del componente — vista 8.3.
  Future<Paginado<ComponenteEvento>> fichaComponente(
    int id, {
    String? tipo,
  }) async {
    final j = await _api.get(
      '${ApiConstants.componentes}/$id/ficha',
      query: {if (tipo != null && tipo.isNotEmpty) 'tipo': tipo},
    );
    return Paginado.desde(j, ComponenteEvento.fromJson);
  }

  /// Las fotos del componente con su ficha — vista 8.4.
  Future<List<GaleriaFoto>> galeriaComponente(int id) =>
      _galeria('${ApiConstants.componentes}/$id/galeria');

  /// Las fotos de un activo con su ficha — vista 7.4.
  Future<List<GaleriaFoto>> galeriaActivo(int id) =>
      _galeria('${ApiConstants.activos}/$id/galeria');

  /// Las fotos de un repuesto — vista 10.4.
  Future<List<GaleriaFoto>> galeriaRepuesto(int id) =>
      _galeria('${ApiConstants.repuestos}/$id/galeria');

  /// Las tres galerías devuelven la misma forma, así que se leen igual.
  /// Repetir el `map` tres veces sería tres sitios donde equivocarse.
  Future<List<GaleriaFoto>> _galeria(String ruta) async {
    final j = await _api.get(ruta);
    final datos = (j is List) ? j : const [];
    return datos
        .map((e) => GaleriaFoto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Los medidores de un equipo — la puerta de entrada de 9.2.
  Future<List<Medidor>> medidoresDe(int activo) async {
    final j = await _api.get(
      ApiConstants.medidores,
      query: {'activo': activo, 'tamano': 50},
    );
    return Paginado.desde(j, Medidor.fromJson).datos;
  }

  /// Un medidor con sus umbrales.
  Future<Medidor> medidor(int id) async {
    final j = await _api.get('${ApiConstants.medidores}/$id');
    return Medidor.fromJson(j as Map<String, dynamic>);
  }

  /// El historial de lecturas — vista 9.2.
  ///
  /// Vienen **ascendentes y con el incremento ya calculado**: es una serie
  /// para un gráfico, y la resta la hace el SP. Que la hiciera el teléfono
  /// daría un incremento equivocado en la primera fila de cada página —no
  /// tiene contra qué restarse— y obligaría a la web a repetir la misma
  /// cuenta.
  Future<List<Lectura>> lecturasDe(
    int medidor, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    String d(DateTime f) =>
        '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';

    final j = await _api.get(
      '${ApiConstants.medidores}/$medidor/lecturas',
      query: {
        'tamano': 500,
        if (desde != null) 'desde': d(desde),
        if (hasta != null) 'hasta': d(hasta),
      },
    );
    return Paginado.desde(j, Lectura.fromJson).datos;
  }

  // ---- Inventario (Sprint 3) ----

  /// `?alerta=true` trae solo lo que está fuera de umbral.
  ///
  /// **Este listado no se cachea en el servidor, a propósito**: es el dato que
  /// no puede estar viejo. Un técnico que baja a buscar una pieza que ya no
  /// está perdió el viaje.
  Future<Paginado<InventarioSaldo>> existencias({
    int pagina = 1,
    String? filtro,
    bool soloAlerta = false,
  }) async {
    final p = await _paginadoConRespaldo<InventarioSaldo>(
      entidad: CacheDatos.existencias,
      desde: InventarioSaldo.fromJson,
      red: () async {
        final j = await _api.get(
          ApiConstants.existencias,
          query: {
            'pagina': pagina,
            'tamano': 50,
            if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
            if (soloAlerta) 'alerta': true,
          },
        );
        return Paginado.desde(j, InventarioSaldo.fromJson);
      },
    );

    // El filtro y la búsqueda los resuelve el servidor cuando hay señal. Sin
    // señal los aplica la app sobre lo guardado: una pantalla de existencias
    // que ignora el filtro que la persona acaba de tocar se lee como que la
    // app dejó de responder.
    if (SyncService.instance.enLinea.value) return p;

    final filtrada = p.datos
        .where((s) => _calzaExistencia(s, filtro, soloAlerta))
        .toList();

    return Paginado(
      datos: filtrada,
      total: filtrada.length,
      paginas: filtrada.isEmpty ? 0 : 1,
    );
  }

  bool _calzaExistencia(InventarioSaldo s, String? filtro, bool soloAlerta) {
    if (soloAlerta && !s.bajoMinimo) return false;
    if (filtro == null || filtro.trim().isEmpty) return true;

    final t = filtro.trim().toLowerCase();
    return '${s.REPUESTO_CODIGO} ${s.REPUESTO_NOMBRE}'.toLowerCase().contains(
      t,
    );
  }

  Future<Paginado<Repuesto>> repuestos({int pagina = 1, String? filtro}) =>
      _paginadoConRespaldo<Repuesto>(
        entidad: CacheDatos.repuestos,
        desde: Repuesto.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.repuestos,
            query: {
              'pagina': pagina,
              'tamano': 50,
              if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
            },
          );
          return Paginado.desde(j, Repuesto.fromJson);
        },
      );

  Future<Repuesto> repuesto(int id) async {
    final j = await _api.get('${ApiConstants.repuestos}/$id');
    return Repuesto.fromJson(j as Map<String, dynamic>);
  }

  /// Una bodega — vista 10.6.
  Future<Bodega> bodega(int id) async {
    final j = await _api.get('${ApiConstants.bodegas}/$id');
    return Bodega.fromJson(j as Map<String, dynamic>);
  }

  /// Los lotes de un repuesto, para la ficha (vista 10.3).
  ///
  /// El vencido **viene marcado por el servidor** (`VENCIDO`) y no se deduce
  /// comparando fechas en el teléfono: dos aparatos con distinta hora darían
  /// veredictos distintos sobre el mismo lote, y entregar de uno vencido es el
  /// error que la ficha tiene que hacer difícil.
  Future<List<RepuestoLote>> lotesDe(int repuesto) async {
    final j = await _api.get('${ApiConstants.repuestos}/$repuesto/lotes');
    return Paginado.desde(j, RepuestoLote.fromJson).datos;
  }

  /// Todas las bodegas donde hay este repuesto — `GET /existencias/repuesto/{id}`.
  ///
  /// Sin paginar, como lo entrega la API: un repuesto no vive en doscientas
  /// bodegas, y paginarlo obligaría a la ficha a juntar páginas para mostrar
  /// una sola pantalla.
  Future<List<InventarioSaldo>> saldosDeRepuesto(int repuesto) async {
    final j = await _api.get('${ApiConstants.existencias}/repuesto/$repuesto');
    return Paginado.desde(j, InventarioSaldo.fromJson).datos;
  }

  Future<Paginado<Bodega>> bodegas({int pagina = 1}) =>
      _paginadoConRespaldo<Bodega>(
        entidad: CacheDatos.bodegas,
        desde: Bodega.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.bodegas,
            query: {'pagina': pagina, 'tamano': 50},
          );
          return Paginado.desde(j, Bodega.fromJson);
        },
      );

  Future<Paginado<InventarioMovimiento>> movimientos({int pagina = 1}) async {
    final j = await _api.get(
      ApiConstants.inventarioMovimientos,
      query: {'pagina': pagina, 'tamano': 50},
    );
    return Paginado.desde(j, InventarioMovimiento.fromJson);
  }

  // ---- Permisos de trabajo ----

  Future<Paginado<PermisoTrabajo>> permisosTrabajo({int pagina = 1}) async {
    final j = await _api.get(
      ApiConstants.permisosTrabajo,
      query: {'pagina': pagina, 'tamano': 50},
    );
    return Paginado.desde(j, PermisoTrabajo.fromJson);
  }

  Future<Paginado<PermisoTrabajo>> permisosVigentes({int pagina = 1}) async {
    final j = await _api.get(
      '${ApiConstants.permisosTrabajo}/vigentes',
      query: {'pagina': pagina, 'tamano': 50},
    );
    return Paginado.desde(j, PermisoTrabajo.fromJson);
  }

  /// Un permiso — vista 11.2.
  ///
  /// Sin respaldo en disco a proposito: lo que se mira aca es si HABILITA a
  /// trabajar, y esa respuesta cambia con la hora. Un permiso vigente guardado
  /// ayer puede estar vencido hoy, y responder que si con dato viejo es la
  /// clase de error que este endpoint existe para evitar.
  Future<PermisoTrabajo> permiso(int id) async {
    final j = await _api.get('${ApiConstants.permisosTrabajo}/$id');
    return PermisoTrabajo.fromJson(j as Map<String, dynamic>);
  }

  /// Los tipos y estados son **catálogo**, no movimiento: cambian una vez al
  /// año y sin ellos los chips de la pantalla de permisos quedan vacíos. Son
  /// justo lo que tiene sentido leer del disco sin señal.
  Future<List<ItemCatalogo>> tiposPermiso() => _conRespaldo<ItemCatalogo>(
    entidad: CacheDatos.permisosTipos,
    desde: (m) => ItemCatalogo.desde(m, 'PTT'),
    red: () async {
      final j = await _api.get('${ApiConstants.permisosTrabajo}/tipos');
      return Paginado.desde(j, (m) => ItemCatalogo.desde(m, 'PTT')).datos;
    },
  );

  /// Los estados de un permiso de trabajo, para el filtro de la bandeja.
  ///
  /// Bajan en la sábana (bloque 8), así que los chips también salen sin señal.
  Future<List<ItemCatalogo>> estadosPermiso() => _conRespaldo<ItemCatalogo>(
    entidad: CacheDatos.permisosEstados,
    desde: (m) => ItemCatalogo.desde(m, 'PTE'),
    red: () async {
      final j = await _api.get('${ApiConstants.permisosTrabajo}/estados');
      return Paginado.desde(j, (m) => ItemCatalogo.desde(m, 'PTE')).datos;
    },
  );

  // ---- Alertas (HU-077) ----

  /// La bandeja **sale del servidor**, no del teléfono: SIGMA ya detecta los
  /// hallazgos con `GEN_ALERTA_*`. Una bandeja local sería una segunda verdad.
  Future<Paginado<Alerta>> alertas({
    int pagina = 1,
    bool soloAbiertas = true,
  }) async {
    final j = await _api.get(
      ApiConstants.alertas,
      query: {'pagina': pagina, 'tamano': 50, 'soloAbiertas': soloAbiertas},
    );
    return Paginado.desde(j, Alerta.fromJson);
  }

  /// Dos enteros. La campanita se refresca seguido: traer la lista completa
  /// para contar cuántas hay sería bajar decenas de filas por cada refresco,
  /// con los datos del teléfono del técnico.
  Future<AlertaResumen> resumenAlertas() async {
    final j = await _api.get(ApiConstants.alertasResumen);
    if (j is List && j.isNotEmpty) {
      return AlertaResumen.fromJson(j.first as Map<String, dynamic>);
    }
    return AlertaResumen.fromJson((j as Map<String, dynamic>?) ?? {});
  }

  Future<void> marcarAlertaLeida(int id) =>
      _api.post('${ApiConstants.alertas}/$id/leer', null);

  // ---- Mi perfil: lo que la persona SÍ puede cambiar (HU-005) ----

  // ---- Recuperar contraseña (HU-004) ----

  // ---- Cambiar el estado de un activo (HU-038) ----

  // ---- Sincronizacion descendente (HU-150) ----

  // ---- Captura en terreno (HU-043, HU-044) ----
  //
  // No se llaman directo desde la pantalla: van por la cola de salida, que
  // guarda en disco antes de intentar la red. Estas rutas son las que el
  // `outbox` despacha.

  static const rutaLecturas = ApiConstants.capturaLecturas;
  static const rutaMediciones = ApiConstants.capturaMediciones;

  // ---- Escaneo (HU-154 y HU-067) ----

  Future<Escaneo> escanear(String codigo) async {
    final j = await _api.get(ApiConstants.escaneo, query: {'c': codigo});
    return Escaneo.fromJson(j as Map<String, dynamic>);
  }

  // ---- Activos: la cabecera y el cambio de estado (HU-037, HU-038) ----

  /// Los activos de la planta — vista 7.2.
  ///
  /// ## Por que sale SOLO del telefono
  ///
  /// **No hay `GET /activos`**: `ActivosController` expone la ficha y su
  /// historial, no un listado. Y no hace falta inventarlo: los activos ya
  /// bajan enteros en la sabana, que es como la app trabaja sin señal.
  ///
  /// Eso tiene una consecuencia que la pantalla dice en vez de esconder: **si
  /// la sabana no se ha bajado, la lista sale vacia**. Callarlo dejaria a
  /// alguien creyendo que la planta no tiene equipos.
  Future<List<Activo>> activos() =>
      CacheDatos.lista<Activo>(CacheDatos.activos, Activo.fromJson);

  /// La cabecera de un activo.
  ///
  /// Existe aparte de `/ficha` porque esa devuelve los EVENTOS: sin este
  /// endpoint la pantalla tenia que recibir el nombre y el tipo por parametro
  /// desde donde la abrieran, y el mismo activo se veia distinto abierto desde
  /// el escaneo que desde un listado.
  ///
  /// Sin señal sale de la sábana. Lo que **no** trae la sábana son las fotos:
  /// el bloque de activos guarda la ficha, no las rutas de blob. Es correcto
  /// —una foto que no se bajó no está en el teléfono aunque se conozca su
  /// ruta— y por eso la ficha offline muestra el activo completo sin imagen,
  /// en vez de un hueco esperando una descarga que no puede ocurrir.
  Future<Activo> activo(int id) => _unoConRespaldo<Activo>(
    entidad: CacheDatos.activos,
    desde: Activo.fromJson,
    columna: 'act_id',
    valor: id,
    red: () async {
      final j = await _api.get('${ApiConstants.activos}/$id');
      return Activo.fromJson(j as Map<String, dynamic>);
    },
  );

  /// Los valores de un catalogo, por su codigo.
  /// Los valores de un catálogo, **con respaldo en disco**.
  ///
  /// ## Por qué no basta con pedirlos
  ///
  /// Sin señal, una hoja de chips de catálogo se quedaba sin ninguna opción, y
  /// hay dos donde eso **bloquea**: cambiar el estado de un activo (HU-038) y
  /// la severidad de la bitácora. Las dos capturas se hacen delante del equipo,
  /// que es justo donde no hay señal.
  ///
  /// ## Por qué se filtra acá y no en la consulta
  ///
  /// El endpoint devuelve un catálogo; la sábana baja **todos** en una sola
  /// entidad, porque son cientos de filas y ochenta consultas para guardarlas
  /// por separado no valen la pena. `CATALOGO_CODIGO` viaja en cada fila y es
  /// lo que las separa al leerlas.
  Future<List<CatalogoValor>> valoresDe(String codigo) async {
    Future<List<CatalogoValor>> deDisco() async {
      final todos = await CacheDatos.lista<CatalogoValor>(
        CacheDatos.catalogoValores,
        CatalogoValor.fromJson,
      );
      return todos
          .where(
            (v) =>
                (v.CATALOGO_CODIGO ?? '').toUpperCase() == codigo.toUpperCase(),
          )
          .toList();
    }

    if (!SyncService.instance.enLinea.value) return deDisco();

    try {
      final j = await _api.get(
        ApiConstants.catalogoValores,
        query: {'codigo': codigo, 'tamano': 200},
      );
      final datos = (j is Map && j['datos'] is List)
          ? j['datos'] as List
          : (j as List?) ?? const [];
      return datos
          .map((e) => CatalogoValor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      // Un 403 sigue siendo un 403: no se tapa con datos viejos.
      if (!e.esDeRed) rethrow;
      final local = await deDisco();
      if (local.isEmpty) rethrow;
      return local;
    }
  }

  // ---- Mi perfil: lo que la persona SI puede cambiar (HU-005) ----

  /// Telefono e idioma, nada mas. El nombre y el correo identifican a la
  /// persona dentro del cliente y se cambian en la web, con permiso.
  ///
  /// LOS NOMBRES SON LOS DEL DTO, NO LOS DE LA TABLA
  ///   `MiPerfilEdicionDto` recibe `telefono` e `idioma`. Se mandaba
  ///   `usu_telefono`, que es como se llama la COLUMNA: el binder no
  ///   encontraba la propiedad, la dejaba en null, y `UPD_USUARIO_MI_PERFIL`
  ///   asigna `usu_telefono = @TELEFONO` sin ISNULL. Es decir que guardar el
  ///   telefono lo BORRABA, y la pantalla decia "guardado".
  Future<void> actualizarPerfil({String? telefono, int? idioma}) => _api.put(
    ApiConstants.miPerfil,
    {'telefono': ?telefono, 'idioma': ?idioma},
  );

  /// La actual se pide **siempre**, incluso con la sesion abierta: el telefono
  /// desbloqueado y sin dueno encima de una mesa es el caso normal en planta.
  ///
  /// Va por POST: la ruta esta declarada `[HttpPost]`. Con PUT la peticion
  /// moria en 405 y nadie podia cambiar su clave desde la app.
  Future<void> cambiarPassword(String actual, String nueva) => _api.post(
    ApiConstants.miPassword,
    {'password_actual': actual, 'password_nuevo': nueva},
  );

  /// Responde lo mismo exista o no el correo: si la respuesta cambiara, este
  /// formulario seria una forma de averiguar que correos estan registrados
  /// probandolos de a uno, sin credenciales y sin limite.
  Future<void> pedirRecuperacion(String correo) =>
      _api.post(ApiConstants.recuperacion, {'correo': correo});

  Future<void> restablecer(String token, String passwordNuevo) => _api.post(
    ApiConstants.restablecer,
    {'token': token, 'password_nuevo': passwordNuevo},
  );

  // ---- La sabana de datos (HU-150) ----

  /// El manifiesto: `@TIPO = 0`.
  ///
  /// Trae que bloques hay, cuantas filas tiene cada uno y **la hora del
  /// servidor**, que es la que se guarda como corte para el proximo
  /// incremental. La del telefono no sirve: un reloj corrido se saltaria
  /// registros para siempre.
  Future<Map<String, dynamic>> manifiesto() async {
    final j = await _api.get(ApiConstants.sincronizacion);
    return (j as Map).cast<String, dynamic>();
  }

  /// Un bloque de la sabana. Devuelve **una lista por resultado**: el bloque
  /// de inventario trae repuestos, bodegas, ubicaciones y tipos en cuatro
  /// conjuntos, y mezclarlos los volveria inseparables al leerlos.
  Future<List<List<Map<String, dynamic>>>> bloque(
    int tipo, {
    DateTime? desde,
  }) async {
    final j = await _api.get(
      '${ApiConstants.sincronizacion}/$tipo',
      query: {if (desde != null) 'desde': desde.toUtc().toIso8601String()},
    );

    List<Map<String, dynamic>> filas(List cruda) =>
        cruda.map((e) => (e as Map).cast<String, dynamic>()).toList();

    if (j is List) {
      // Puede venir una lista de listas o una lista de filas.
      if (j.isNotEmpty && j.first is List) {
        return j.map((c) => filas(c as List)).toList();
      }
      return [filas(j)];
    }
    if (j is Map && j['datos'] is List) return [filas(j['datos'] as List)];
    return const [];
  }

  // ---- Tareas en terreno (HU-103, HU-104) ----

  /// Las tareas asignadas, **con respaldo en disco**.
  ///
  /// Bajan en el bloque 10 de la sábana. Sin esto, sin señal la bandeja salía
  /// vacía: responder una tarea ya se encolaba, pero encolar no sirve de nada
  /// si no se puede llegar a la pantalla.
  /// Las **cerradas**: completadas y no realizadas.
  ///
  /// Va por red y sin respaldo en disco, a diferencia de las pendientes: es
  /// historial, se mira de vez en cuando y no se captura nada sobre ellas. La
  /// sábana baja lo que hace falta para TRABAJAR sin señal, y llenar el
  /// teléfono con lo ya terminado gasta espacio en lo que no se va a usar.
  Future<List<TareaPendiente>> tareasCerradas({int? instalacion}) async {
    final j = await _api.get(
      ApiConstants.tareas,
      query: {'instalacion': ?instalacion, 'cerradas': true},
    );
    if (j is! List) return const [];
    return j
        .map((e) => TareaPendiente.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TareaPendiente>> tareasPendientes({int? instalacion}) =>
      _conRespaldo<TareaPendiente>(
        entidad: CacheDatos.tareas,
        desde: TareaPendiente.fromJson,
        red: () async {
          final j = await _api.get(
            ApiConstants.tareas,
            query: {'instalacion': ?instalacion},
          );
          if (j is! List) return const [];
          return j
              .map(
                (e) =>
                    TareaPendiente.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList();
        },
      );

  /// La ficha trae el hilo en la misma respuesta: la pantalla no se puede
  /// dibujar sin el, y pedirlo aparte serian dos viajes para una sola vista.
  Future<Tarea> tarea(int id) async {
    final j = await _api.get('${ApiConstants.tareas}/$id');
    return Tarea.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Empieza o cierra, segun `finalizar`. Idempotente por `uuid`, que se
  /// genera al **empezar** y no al enviar: si se generara al enviar, un
  /// reintento traeria uno nuevo y abriria una segunda ejecucion de algo que
  /// se hizo una sola vez.
  /// **Se encola**, como toda captura de terreno.
  ///
  /// Empezar y cerrar una tarea se hacen delante del equipo, que es donde no
  /// hay señal. El `uuid` lo genera la ficha **al empezar** y el mismo viaja en
  /// el cierre, así que el SP corta por él: un reintento no abre una segunda
  /// ejecución de algo que se hizo una sola vez.
  ///
  /// No devuelve el id del servidor —cuando se encola todavía no existe— y la
  /// ficha no lo usaba: solo invalida sus providers.
  Future<void> guardarEjecucionTarea(Map<String, dynamic> cuerpo) {
    final cerrar = cuerpo['finalizar'] == true;
    return OutboxService.instance.encolar(
      tipo: 'TAREA',
      titulo: cerrar ? 'Cierre de tarea' : 'Inicio de tarea',
      detalle: cerrar
          ? (cuerpo['conforme'] == false ? 'No realizada' : 'Realizada')
          : null,
      endpoint: ApiConstants.tareasEjecuciones,
      uuid: '${cuerpo['uuid']}',
      cuerpo: cuerpo,
      // Empezar y cerrar comparten uuid a propósito, así que se distinguen por
      // el agrupador: sin él, el segundo pisaría al primero en la cola.
      agrupador: cerrar ? 'tarea-cierre-${cuerpo['ocurrencia']}' : null,
    );
  }

  /// El dictado, si lo hubo, viaja en el mismo cuerpo: un comentario y su
  /// dictado son un solo acto, y en dos envios la cola podria dejar uno sin
  /// el otro.
  /// **Se encola.** Un comentario se escribe junto al equipo igual que el
  /// cierre, y perderlo por falta de señal es perder lo único que explica por
  /// qué la tarea quedó como quedó.
  Future<void> comentarTarea(int ocurrencia, Map<String, dynamic> cuerpo) =>
      OutboxService.instance.encolar(
        tipo: 'COMENTARIO_TAREA',
        titulo: 'Comentario de tarea',
        detalle: '${cuerpo['texto'] ?? ''}',
        endpoint: '${ApiConstants.tareas}/$ocurrencia/comentarios',
        cuerpo: cuerpo,
      );

  // ---- Evidencia fotografica ----

  Future<List<Evidencia>> evidencias(String destino, int destinoId) async {
    final j = await _api.get(
      ApiConstants.evidencias,
      query: {'destino': destino, 'destino_id': '$destinoId'},
    );
    if (j is! List) return const [];
    return j
        .map((e) => Evidencia.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Sube una foto. Idempotente por el uuid que el telefono genero al sacarla.
  Future<int> subirEvidencia(Map<String, dynamic> cuerpo) async {
    final j = await _api.post(ApiConstants.evidencias, cuerpo);
    return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
  }

  /// Todo lo que subió el usuario — vista 13.2.
  ///
  /// La vuelta al revés de [evidencias], que responde «qué fotos tiene esta
  /// tarea». Esta responde «se subieron mis fotos», que es la pregunta que se
  /// hace al terminar un turno sin señal.
  Future<List<EvidenciaMia>> misEvidencias({int dias = 30}) async {
    final j = await _api.get(
      '${ApiConstants.evidencias}/mias',
      query: {'dias': dias, 'tamano': 100},
    );
    return Paginado.desde(j, EvidenciaMia.fromJson).datos;
  }

  // ---- Firmas y validaciones de una orden (vista 6.7, HU-118) ----

  /// Las firmas de una orden, de la más nueva a la más vieja.
  ///
  /// El orden lo pone el SP y no la pantalla: cuando hay dos validaciones del
  /// mismo tipo —una rechazada y después una aprobada— la que manda es la
  /// última, y tiene que ser la primera que se ve. La anterior sigue ahí.
  Future<List<Validacion>> validaciones(int orden) async {
    final j = await _api.get(
      '${ApiConstants.ordenesTrabajo}/$orden/validaciones',
    );
    final datos = (j is List) ? j : const [];
    return datos
        .map((e) => Validacion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ItemCatalogo>> tiposValidacion() async {
    final j = await _api.get('${ApiConstants.ordenesTrabajo}/tipos-validacion');
    final datos = (j is List) ? j : const [];
    return datos
        .map(
          (e) => ItemCatalogo.desde((e as Map).cast<String, dynamic>(), 'VAT'),
        )
        .toList();
  }

  /// Firmar. **Se encola**, como toda captura de terreno.
  ///
  /// ## Por qué la firma viaja dentro del mismo envío
  ///
  /// Se podría subir el PNG por `/evidencias` y después mandar su id, pero eso
  /// son **dos** peticiones que la cola no puede encolar juntas: sin señal, la
  /// primera entraría y la segunda no, y quedaría una firma huérfana sin
  /// validación. Un solo envío, un solo `uuid`, un solo reintento.
  ///
  /// ## Por qué el dibujo es opcional
  ///
  /// Lo que siempre queda es **quién** validó y **cuándo**, y eso sale del
  /// token y del reloj del servidor. El dibujo es prueba adicional, no la
  /// validación misma.
  Future<void> firmarOrden(
    int orden, {
    required int tipo,
    required bool aprobada,
    String? observacion,
    String? firmaBase64,
  }) => OutboxService.instance.encolar(
    tipo: 'VALIDACION',
    titulo: 'Firma de la orden $orden',
    detalle: aprobada ? 'Aprobada' : 'Rechazada',
    endpoint: '${ApiConstants.ordenesTrabajo}/$orden/validaciones',
    cuerpo: {
      'tipo': tipo,
      // Las palabras son las de la base: `CK_OTV_RESULTADO` solo admite
      // APROBADO y RECHAZADO, y traducir acá evitaría que el SP rebote.
      'resultado': aprobada ? 'APROBADO' : 'RECHAZADO',
      'observacion': observacion,
      'firma_base64': firmaBase64,
    },
  );

  // ---- Bitácora de planta (HU-130, HU-131) ----

  /// La línea de tiempo de la planta.
  ///
  /// Ordenada por la fecha del **evento** y no la de creación: una entrada
  /// escrita sin señal a las tres de la mañana y subida a las nueve pertenece
  /// a la noche, y ponerla a las nueve descoloca el relato del turno.
  Future<List<BitacoraEntrada>> bitacora({
    int? instalacion,
    bool soloAtencion = false,
    int pagina = 1,
  }) async {
    final j = await _api.get(
      ApiConstants.bitacora,
      query: {
        'pagina': pagina,
        'tamano': 30,
        'instalacion': ?instalacion,
        if (soloAtencion) 'atencion': true,
      },
    );
    return Paginado.desde(j, BitacoraEntrada.fromJson).datos;
  }

  /// Los tipos de entrada de bitácora, **con respaldo en disco**.
  ///
  /// Sin señal la hoja no mostraba ningún tipo y el tipo es obligatorio: se
  /// podía escribir el texto y no se podía guardar. Escribir en la bitácora ya
  /// se encolaba; faltaba poder llenar el formulario.
  ///
  /// El respaldo sale de `BITACORA_TIPO`, que es un catálogo del sistema y baja
  /// en el bloque 3 de la sábana desde `BD/192`. No hace falta bloque propio.
  Future<List<BitacoraTipo>> tiposBitacora() async {
    Future<List<BitacoraTipo>> deDisco() async {
      final todos = await CacheDatos.lista<CatalogoValor>(
        CacheDatos.catalogoValores,
        CatalogoValor.fromJson,
      );
      return todos
          .where(
            (v) => (v.CATALOGO_CODIGO ?? '').toUpperCase() == 'BITACORA_TIPO',
          )
          .map(
            (v) => BitacoraTipo(
              bti_id: v.ctv_id,
              bti_nombre: v.ctv_nombre,
              bti_codigo: v.ctv_codigo,
            ),
          )
          .toList();
    }

    if (!SyncService.instance.enLinea.value) return deDisco();

    try {
      final j = await _api.get('${ApiConstants.bitacora}/tipos');
      return Paginado.desde(j, BitacoraTipo.fromJson).datos;
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;
      final local = await deDisco();
      if (local.isEmpty) rethrow;
      return local;
    }
  }

  Future<BitacoraFicha> entradaBitacora(int id) async {
    final j = await _api.get('${ApiConstants.bitacora}/$id');
    return BitacoraFicha.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Escribir en la bitácora. **Se encola**, como toda captura de terreno: se
  /// escribe delante del equipo y ahí casi nunca hay señal.
  Future<void> escribirBitacora(Map<String, dynamic> cuerpo) =>
      OutboxService.instance.encolar(
        tipo: 'BITACORA',
        titulo: 'Bitácora: ${cuerpo['titulo']}',
        detalle: '${cuerpo['texto']}',
        endpoint: ApiConstants.bitacora,
        cuerpo: cuerpo,
        uuid: '${cuerpo['uuid']}',
      );

  /// Corregir una entrada. **No reemplaza el texto**: se apila encima, y el
  /// original sigue guardado. El motivo es obligatorio.
  Future<void> rectificarBitacora(int id, String texto, String motivo) =>
      _api.post('${ApiConstants.bitacora}/$id/rectificaciones', {
        'texto': texto,
        'motivo': motivo,
      });

  Future<void> comentarBitacora(int id, Map<String, dynamic> cuerpo) =>
      _api.post('${ApiConstants.bitacora}/$id/comentarios', cuerpo);

  // ---- Compartir un trabajo ----

  /// Con quién se puede compartir: los asignados a esa instalación.
  /// Quienes pueden estar en un trabajo, en esta instalacion.
  ///
  /// [perfiles] son los ids de perfil que se aceptan. Sin ellos el SP devuelve
  /// a TODOS los usuarios de la planta —el gerente comercial y el
  /// administrador incluidos, que no van a estar delante de la maquina—, asi
  /// que las dos hojas pasan siempre [perfilesDeTerreno].
  Future<List<Companero>> companeros(
    int instalacion, {
    String? filtro,
    List<int>? perfiles,
  }) async {
    final j = await _api.get(
      '${ApiConstants.compartir}/companeros',
      query: {
        'instalacion': instalacion,
        if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
        if (perfiles != null && perfiles.isNotEmpty)
          'perfiles': perfiles.join(','),
      },
    );
    return Paginado.desde(j, Companero.fromJson).datos;
  }

  /// Los perfiles que pisan la planta, decididos con Bryan el 08-09-2026:
  /// Tecnico (13), Bodeguero (4), Planificador (11) y Supervisor (12).
  ///
  /// Valen para las DOS hojas —sumar compañero y compartir—, asi que viven acá
  /// y no repetidos en cada pantalla.
  static const List<int> perfilesDeTerreno = [13, 4, 11, 12];

  /// Deja el aviso en la bandeja del compañero. El **título lo arma el SP**:
  /// «Ramiro te compartió OT-1» tiene que decir lo mismo venga del teléfono
  /// de quien sea.
  /// **Intenta, y si falla la red encola.**
  ///
  /// Con señal el compañero tiene que enterarse ahora —va a caminar hasta la
  /// máquina— y una confirmación del servidor es la única que no miente. Sin
  /// señal no se pierde: entra a la cola y sale sola al volver la señal.
  ///
  /// Un error que **no** es de red no se encola: «esa persona no está asignada
  /// a la instalación» no mejora reintentando, y guardarlo sería dejar en la
  /// cola algo que va a fallar para siempre.
  ///
  /// El `uuid` nace **acá** y se reusa al encolar: `INS_APP_COMPARTIR` corta
  /// por él, así que el reintento no manda el aviso dos veces.
  Future<void> compartir({
    required int destinatario,
    required String entidad,
    required int entidadId,
    String? mensaje,
  }) async {
    final uuid = OutboxService.nuevoUuid();
    final cuerpo = {
      'destinatario': destinatario,
      'entidad': entidad,
      'entidad_id': entidadId,
      'mensaje': mensaje,
      'uuid': uuid,
    };

    Future<void> encolar() => OutboxService.instance.encolar(
      tipo: 'COMPARTIR',
      titulo: 'Compartir un trabajo',
      detalle: mensaje,
      endpoint: ApiConstants.compartir,
      uuid: uuid,
      cuerpo: cuerpo,
    );

    if (!SyncService.instance.enLinea.value) return encolar();

    try {
      await _api.post(ApiConstants.compartir, cuerpo);
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;
      await encolar();
    }
  }

  /// Sumarse a una orden como participante. Abre un tramo de mano de obra en
  /// cero: unirse es decir «voy para allá», no «ya trabajé veinte minutos».
  /// Sumarse a una orden que alguien compartió — la otra mitad de HU-115.
  ///
  /// Abre un tramo de mano de obra **en cero**: unirse es decir «voy para
  /// allá», no «ya trabajé veinte minutos». El tiempo lo pone después el
  /// cronómetro.
  ///
  /// **El `uuid` entra por parámetro y no se genera acá.** La pantalla lo crea
  /// una vez y lo reusa si tiene que encolar: generado adentro, cada reintento
  /// traería uno nuevo y el compañero aparecería dos veces en la mano de obra
  /// de la orden — que es justo el caso del timeout.
  Future<int> unirmeAOrden(int ordenId, {required String uuid}) async {
    final j = await _api.post('${ApiConstants.compartir}/unirme', {
      'orden_trabajo': ordenId,
      'uuid': uuid,
    });
    return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
  }

  // ---- Favoritos ----

  /// Marca o desmarca, y devuelve **cómo quedó**.
  ///
  /// Un solo endpoint que alterna, y no un alta y una baja: la estrella es un
  /// interruptor y la app no sabe si el favorito ya estaba. Con dos endpoints,
  /// dos toques rápidos pueden cruzarse y dejar el estado invertido respecto
  /// de lo que muestra la pantalla.
  Future<bool> alternarFavorito(String entidad, int id) async {
    final j = await _api.post(ApiConstants.favoritos, {
      'entidad': entidad,
      'entidad_id': id,
    });
    return (j is Map && j['es_favorito'] == true);
  }

  // ---- SIGMA AI (HU-173, HU-175) ----

  Future<List<Prediccion>> predicciones({int? instalacion}) async {
    final j = await _api.get(
      ApiConstants.predicciones,
      query: {'instalacion': ?instalacion},
    );
    if (j is! List) return const [];
    return j
        .map((e) => Prediccion.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Los equipos vigilados que no produjeron prediccion. **No es una lista de
  /// relleno**: un panel vacio no distingue «nadie mide este equipo» de «se
  /// mide y esta tranquilo», y son cosas muy distintas.
  Future<List<Vigilado>> vigilados({int? instalacion}) async {
    final j = await _api.get(
      '${ApiConstants.predicciones}/vigilados',
      query: {'instalacion': ?instalacion},
    );
    if (j is! List) return const [];
    return j
        .map((e) => Vigilado.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Razones, datos usados y serie vienen en la misma respuesta: cuatro viajes
  /// de red para una vista en terreno es una vista que no se abre.
  Future<PrediccionFicha> prediccion(int id) async {
    final j = await _api.get('${ApiConstants.predicciones}/$id');
    return PrediccionFicha.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Reconocer o descartar. Descartar **exige motivo**: sin el, nadie puede
  /// aprender despues si el modelo se equivoco o si la decision fue otra.
  Future<void> revisarPrediccion(
    int id, {
    required bool aceptar,
    String? motivo,
  }) => _api.post('${ApiConstants.predicciones}/$id/revision', {
    'aceptar': aceptar,
    'motivo': motivo,
  });

  /// Abre la OT predictiva. Solo si la prediccion genero alerta: bajo el
  /// umbral el modelo no pide que se le crea todavia.
  Future<int> ordenDesdePrediccion(int id) async {
    final j = await _api.post(
      '${ApiConstants.predicciones}/$id/orden-trabajo',
      {},
    );
    return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
  }

  /// Mano de obra y repuestos de una orden, en un solo viaje.
  Future<RecursosOrden> recursosOrden(int id) async {
    final j = await _api.get('${ApiConstants.ordenesTrabajo}/$id/recursos');
    return RecursosOrden.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Un tramo de mano de obra (HU-115). No hay edicion: la tabla es
  /// append-only y una correccion se hace agregando otro tramo.
  Future<int> registrarManoObra(
    int ordenId,
    Map<String, dynamic> cuerpo,
  ) async {
    final j = await _api.post(
      '${ApiConstants.ordenesTrabajo}/$ordenId/mano-obra',
      cuerpo,
    );
    return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
  }

  /// Lo que se puede consumir contra esta orden, **con la compatibilidad
  /// marcada**.
  ///
  /// No se reusa `/existencias`: aquel listado es de la planta y no sabe nada
  /// de esta orden. La pregunta acá es «de lo que hay en bodega, qué le calza
  /// a ESTE equipo».
  Future<List<RepuestoOrden>> repuestosDeOrden(
    int ordenId, {
    String? filtro,
  }) async {
    final j = await _api.get(
      '${ApiConstants.ordenesTrabajo}/$ordenId/repuestos-disponibles',
      query: {if (filtro != null && filtro.isNotEmpty) 'filtro': filtro},
    );
    return Paginado.desde(j, RepuestoOrden.fromJson).datos;
  }

  /// Los estantes de una bodega — `GET /bodegas/{id}/ubicaciones`.
  ///
  /// Sin paginar a proposito: una bodega tiene decenas de ubicaciones, no
  /// miles, y llenan un selector de una sola vez.
  Future<List<BodegaUbicacion>> ubicacionesDeBodega(int bodegaId) async {
    final j = await _api.get('${ApiConstants.bodegas}/$bodegaId/ubicaciones');
    final datos = (j is List)
        ? j
        : ((j is Map && j['datos'] is List) ? j['datos'] as List : const []);
    return datos
        .map(
          (e) => BodegaUbicacion.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// Consumo o devolucion de repuesto (HU-116). **Mueve el inventario**: el SP
  /// hace las dos escrituras en una transaccion, asi que la bodega y la orden
  /// no pueden discrepar.
  Future<void> moverRepuestoOrden(int ordenId, Map<String, dynamic> cuerpo) =>
      _api.post('${ApiConstants.ordenesTrabajo}/$ordenId/repuestos', cuerpo);

  // ---- Checklist en terreno (HU-095) ----

  Future<List<ChecklistPendiente>> checklistPendientes({
    int? instalacion,
  }) async {
    final j = await _api.get(
      ApiConstants.checklistPendientes,
      query: {'instalacion': ?instalacion},
    );
    if (j is! List) return const [];
    return j
        .map(
          (e) =>
              ChecklistPendiente.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// Items y opciones juntos: la app no puede pintar una seleccion sin sus
  /// opciones, y pedirlas aparte serian dos viajes para una sola pantalla.
  Future<ChecklistPlantilla> checklistPlantilla(int version) async {
    final j = await _api.get('${ApiConstants.checklistPlantillas}/$version');
    return ChecklistPlantilla.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Abre o **retoma**: si ya hay un borrador propio de esa ocurrencia, el
  /// servidor devuelve ese en vez de empezar otro.
  Future<int> abrirChecklist(Map<String, dynamic> cuerpo) async {
    final j = await _api.post(ApiConstants.checklistEjecuciones, cuerpo);
    return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
  }

  Future<ChecklistEjecucion> checklistEjecucion(int id) async {
    final j = await _api.get('${ApiConstants.checklistEjecuciones}/$id');
    return ChecklistEjecucion.fromJson((j as Map).cast<String, dynamic>());
  }

  /// Responder es un UPSERT por (ejecucion, item): volver a responder
  /// actualiza. Devuelve si quedo fuera de rango y el mensaje de la pauta.
  Future<Map<String, dynamic>> responderChecklist(
    int ejecucionId,
    Map<String, dynamic> cuerpo,
  ) async {
    final j = await _api.post(
      '${ApiConstants.checklistEjecuciones}/$ejecucionId/respuestas',
      cuerpo,
    );
    return (j is Map) ? j.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// Cierra la pauta. Los `minutos` son los que **midió el cronómetro**, con
  /// las pausas descontadas; sin ellos el servidor calcula la diferencia
  /// contra la hora de inicio, que cuenta como trabajo el rato que se esperó.
  Future<void> cerrarChecklist(
    int ejecucionId, {
    String? observacion,
    int? minutos,
  }) => _api.post('${ApiConstants.checklistEjecuciones}/$ejecucionId/cerrar', {
    'observacion': observacion,
    'minutos': minutos,
  });

  // ---- Ordenes de trabajo (HU-110, 113, 114, 119, 121) ----

  /// La bandeja.
  ///
  /// `ambito`: 1 mias, 2 disponibles para tomar, 3 todas mis plantas. Son
  /// dos preguntas distintas y la segunda es la que permite que un tecnico
  /// que termino antes tome trabajo en vez de irse.
  Future<List<OrdenTrabajo>> ordenesTrabajo({
    int ambito = 1,
    int? instalacion,
    DateTime? desde,
  }) async {
    final j = await _api.get(
      ApiConstants.ordenesTrabajo,
      query: {
        'ambito': ambito,
        'instalacion': ?instalacion,
        if (desde != null) 'desde': desde.toUtc().toIso8601String(),
      },
    );
    if (j is! List) return const [];
    return j
        .map((e) => OrdenTrabajo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// La ficha con sus pasos, en un solo viaje de red.
  Future<OrdenTrabajoFicha> ordenTrabajo(int id) async {
    final j = await _api.get('${ApiConstants.ordenesTrabajo}/$id');
    return OrdenTrabajoFicha.fromJson((j as Map).cast<String, dynamic>());
  }

  /// El alta desde terreno. **Idempotente por uuid**, que la app genera al
  /// encolar y no al enviar.
  /// Hacerse cargo. Un 409 significa que otro llego primero, no un fallo.
  Future<void> tomarOrdenTrabajo(int id) =>
      _api.post('${ApiConstants.ordenesTrabajo}/$id/tomar', null);

  /// Completar un paso. Idempotente: reenviar el mismo resultado responde lo
  /// mismo en vez de fallar.
  Future<void> completarPaso(
    int pasoId, {
    required int resultado,
    String? observacion,
    int entradaModo = 1,
  }) => _api.post('${ApiConstants.ordenesTrabajoPasos}/$pasoId', {
    'resultado': resultado,
    'observacion': observacion,
    'entrada_modo': entradaModo,
  });

  /// Finalizar deja la orden EN ESPERA DE CIERRE, no cerrada: el cierre es
  /// del planificador, y esa separacion es la que hace que el registro sirva
  /// como respaldo.
  ///
  /// Devuelve la **advertencia** del servidor (HU-119 #3: finalizada sin
  /// mano de obra) o null. Los obligatorios pendientes los rechaza el SP con
  /// sus nombres; la pantalla apaga el botón, pero la regla vive allá.
  Future<String?> finalizarOrdenTrabajo(int id, {String? resultado}) async {
    final j = await _api.post('${ApiConstants.ordenesTrabajo}/$id/finalizar', {
      'resultado': resultado,
    });
    final a = (j is Map) ? j['advertencia'] : null;
    return (a is String && a.trim().isNotEmpty) ? a : null;
  }

  /// Los motivos con que se puede cerrar una OT (HU-120).
  ///
  /// **Con respaldo en disco.** El cierre es una acción de terreno: el
  /// supervisor la cierra donde esté, y ahí puede no haber señal. Pedidos solo
  /// por red, sin conexión la hoja no mostraba ningún chip y no se podía
  /// cerrar — el encolado sí funcionaba offline, pero no se llegaba a él.
  /// Bajan en el bloque 9 de la sábana, como los tipos de permiso en el 8.
  Future<List<CierreMotivo>> motivosCierre() => _conRespaldo<CierreMotivo>(
    entidad: CacheDatos.motivosCierre,
    desde: CierreMotivo.fromJson,
    red: () async {
      final j = await _api.get('${ApiConstants.ordenesTrabajo}/motivos-cierre');
      return Paginado.desde(j, CierreMotivo.fromJson).datos;
    },
  );

  // ---- Fallas, indisponibilidad y asignación (Sprint 5) ----

  /// Las fallas de la planta. `abiertas`: true sin solución, false resueltas,
  /// null todas. Sin respaldo en disco: la falla es de hoy, no un catálogo.
  Future<List<Falla>> fallas({
    int? instalacion,
    int? activo,
    bool? abiertas,
    String? filtro,
  }) async {
    final j = await _api.get(
      ApiConstants.fallas,
      query: {
        'instalacion': ?instalacion,
        'activo': ?activo,
        'abiertas': ?abiertas,
        if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
      },
    );
    return Paginado.desde(j, Falla.fromJson).datos;
  }

  Future<Falla> falla(int id) async {
    final j = await _api.get('${ApiConstants.fallas}/$id');
    return Falla.fromJson((j as Map).cast<String, dynamic>());
  }

  Future<List<FallaDiagnostico>> diagnosticosDe(int falla) async {
    final j = await _api.get('${ApiConstants.fallas}/$falla/diagnosticos');
    return Paginado.desde(j, FallaDiagnostico.fromJson).datos;
  }

  Future<List<FallaAccion>> accionesDe(int falla) async {
    final j = await _api.get('${ApiConstants.fallas}/$falla/acciones');
    return Paginado.desde(j, FallaAccion.fromJson).datos;
  }

  /// La correctiva de emergencia de la falla. **Intenta, y si falla la red
  /// encola**: con señal el técnico quiere abrir la orden ahora y verla; sin
  /// señal queda en la cola y la orden aparece al volver.
  ///
  /// No es idempotente por uuid del lado del SP (`INS_ORDEN_TRABAJO` es el de
  /// la web), así que con señal se hace **una** llamada directa: si el
  /// servidor respondió, la orden existe. Devuelve el id, o 0 si quedó encolada.
  Future<int> ordenDesdeFalla(Falla f) async {
    final ruta = '${ApiConstants.fallas}/${f.FAL_ID}/orden';
    Future<void> encolar() => OutboxService.instance.encolar(
      tipo: 'ORDEN_TRABAJO',
      titulo: 'Orden correctiva de ${f.codigo}',
      detalle: f.FAL_TITULO,
      endpoint: ruta,
      uuid: OutboxService.nuevoUuid(),
      cuerpo: const {},
    );

    if (!SyncService.instance.enLinea.value) {
      await encolar();
      return 0;
    }
    try {
      final j = await _api.post(ruta, const {});
      return (j is Map && j['id'] is num) ? (j['id'] as num).toInt() : 0;
    } on ApiException catch (e) {
      if (!e.esDeRed) rethrow;
      await encolar();
      return 0;
    }
  }

  /// Los periodos de detención de un equipo, una orden o una falla.
  Future<List<Indisponibilidad>> indisponibilidades({
    int? activo,
    int? orden,
    int? falla,
  }) async {
    final j = await _api.get(
      ApiConstants.indisponibilidades,
      query: {'activo': ?activo, 'orden': ?orden, 'falla': ?falla},
    );
    return Paginado.desde(j, Indisponibilidad.fromJson).datos;
  }

  /// Quién ejecuta la orden: responsable y apoyos (HU-112).
  Future<List<AsignacionOrden>> asignacionesDe(int orden) async {
    final j = await _api.get(
      '${ApiConstants.ordenesTrabajo}/$orden/asignaciones',
    );
    return Paginado.desde(j, AsignacionOrden.fromJson).datos;
  }
}
