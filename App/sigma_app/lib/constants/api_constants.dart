/// Configuración de la API y las rutas de sus 52 endpoints.
///
/// El host NO está en el código: entra por `--dart-define-from-file`.
/// Ver `MD/SIGMA_APP_README.md` §3.
abstract final class ApiConstants {
  /// Termina en `.../Servicio/API`, **sin** `/api/`: la aplicación ya está
  /// publicada bajo ese segmento y repetirlo daría `.../API/api/sesion`.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static const int timeoutSegundos =
      int.fromEnvironment('TIMEOUT_SEGUNDOS', defaultValue: 15);

  static const bool logHttp =
      bool.fromEnvironment('LOG_HTTP', defaultValue: true);

  /// Un baseUrl vacío tiene que **fallar temprano y con un mensaje claro**, no
  /// producir peticiones sin host que se ven como un error de red.
  static bool get configurada => baseUrl.isNotEmpty;

  // ---- Sesión e identidad (Sprint 1) ----
  static const String sesion = '/sesion';
  static const String misClientes = '/cliente-usuarios/mis-clientes';
  static const String seleccionarCliente = '/cliente-usuarios/seleccionar';
  static const String menus = '/menus';
  static const String permisos = '/usuario-permisos';
  static const String miPerfil = '/mi-perfil';
  static const String miPassword = '/mi-perfil/password';
  static const String recuperacion = '/usuario-recuperaciones';
  static const String restablecer = '/usuario-recuperaciones/restablecer';

  // ---- Lo que baja al dispositivo (HU-150) ----
  static const String clienteInstalaciones = '/cliente-instalaciones';
  static const String instalacionAreas = '/instalacion-areas';
  static const String catalogos = '/catalogos';
  static const String catalogoValores = '/catalogo-valores';

  // ---- Activos (Sprint 2) ----
  static const String activos = '/activos';
  static const String activoEstados = '/activo-estados';

  /// Los valores de un catálogo: `/catalogos/{codigo}/valores`.
  /// El de estados de activo es `ACTIVO_ESTADO`.
  static String valoresDeCatalogo(String codigo) => '/catalogos/$codigo/valores';

  // ---- Inventario (Sprint 3) ----
  static const String existencias = '/existencias';
  static const String repuestos = '/repuestos';
  static const String bodegas = '/bodegas';
  static const String inventarioMovimientos = '/inventario-movimientos';

  /// La sábana de datos (HU-150). Sin tipo, el manifiesto.
  static const String sincronizacion = '/sincronizacion';

  // ---- Captura en terreno: lo único que solo se puede tomar en la planta ----
  static const String capturaLecturas = '/captura/lecturas';
  static const String capturaMediciones = '/captura/mediciones';

  // ---- Permisos de trabajo, alertas y escaneo ----
  static const String permisosTrabajo = '/permisos-trabajo';
  static const String alertas = '/alertas';
  static const String alertasResumen = '/alertas/resumen';
  static const String escaneo = '/escaneo';

  // ---- Carga descendente: la sabana de datos (HU-150) ----

  /// El manifiesto: que bloques hay, cuantas filas trae cada uno y la hora
  /// del servidor. Sin el, la barra de progreso seria una animacion.

  // ---- Captura en terreno ----
  //
  // Las rutas reales son las de `CapturaTerrenoController`, con prefijo
  // `captura`. No son `/activo-medidor-lecturas`: eso era una suposicion, y
  // una ruta inventada falla en produccion con un 404 que parece un problema
  // de red.
  static const String lecturas = '/captura/lecturas';
  static const String mediciones = '/captura/mediciones';

  // ---- Ordenes de trabajo (HU-110, 113, 114, 119, 121) ----
  static const String ordenesTrabajo = '/ordenes-trabajo';

  /// `POST /ordenes-trabajo/pasos/{id}` completa un paso.
  static const String ordenesTrabajoPasos = '/ordenes-trabajo/pasos';

  // ---- Checklist en terreno (HU-095) ----
  static const String checklistPendientes = '/checklist/pendientes';
  static const String checklistPlantillas = '/checklist/plantillas';
  static const String checklistEjecuciones = '/checklist/ejecuciones';

  /// Los bytes de un archivo del Blob Storage.
  ///
  /// Hoy la API hace de intermediaria: Azure → API → teléfono. Lo eficiente
  /// sería que el teléfono bajara directo con una URL firmada de corta vida,
  /// y eso todavía no existe. Ver `ImagenService` y
  /// `MD/SIGMA_APP_DATOS_SINCRONIZACION.md` §8.
  static const String archivoVer = '/archivo/ver';

  // ---- Tareas en terreno (HU-103, HU-104) ----
  static const String tareas = '/tareas';

  /// `POST /tareas/ejecuciones` empieza **y** cierra. Son un solo acto en
  /// terreno: en dos envios la cola podria entregar el cierre antes que su
  /// apertura, y eso no tiene arreglo.
  static const String tareasEjecuciones = '/tareas/ejecuciones';

  // ---- Evidencia fotografica ----

  /// `POST` sube la foto y la cuelga de algo; `GET ?destino=&destino_id=`
  /// devuelve las rutas, no los bytes: el telefono pide cada imagen por
  /// `archivoVer` y la cachea.
  static const String evidencias = '/evidencias';

  /// El interruptor de la estrella. **No hay un listado**: el favorito viaja
  /// como `ES_FAVORITO` dentro del listado que la persona ya está mirando.
  static const String favoritos = '/favoritos';

  // ---- SIGMA AI (HU-173, HU-175) ----

  /// `GET` el panel de predicciones vigentes; `/vigilados` los equipos que se
  /// miran y no dijeron nada, con el motivo de su silencio.
  static const String predicciones = '/predicciones';

  // ---- Bitacora de planta (HU-130, HU-131) ----

  /// `POST /bitacora/{id}/rectificaciones` corrige **sin borrar**: la entrada
  /// original queda y encima se apila la version corregida con su motivo.
  static const String bitacora = '/bitacora';
}
