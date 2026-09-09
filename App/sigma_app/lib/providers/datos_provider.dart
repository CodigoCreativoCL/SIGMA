import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelos.dart';
import '../services/sigma_repository.dart';
import 'sesion_provider.dart';

/// Los providers de datos.
///
/// Son delgados a propósito: cada uno es una llamada al repositorio. La UI
/// observa **estos**, nunca el repositorio ni el `ApiClient` — así dos
/// pantallas que muestran el mismo dato no pueden mostrar números distintos.
///
/// Todos son `FutureProvider`, que da los tres estados de golpe: `AsyncLoading`
/// mientras baja, `AsyncData` con los datos y `AsyncError` con la excepción
/// —que trae el mensaje del servidor tal como lo redactó el SP—.
///
/// Para recargar: `ref.invalidate(elProvider)`.

final _repo = SigmaRepository.instance;

// ---- Identidad ----

final miPerfilProvider = FutureProvider<MiPerfil>((ref) => _repo.miPerfil());

final menuProvider = FutureProvider<List<MenuNodo>>((ref) => _repo.menus());

final permisosProvider = FutureProvider<Set<String>>((ref) => _repo.permisos());

/// ¿Tengo este permiso? Se resuelve contra el conjunto ya cargado, sin otra
/// llamada por cada botón.
final tienePermisoProvider = Provider.family<bool, String>((ref, codigo) {
  final p = ref.watch(permisosProvider);
  return p.valueOrNull?.contains(codigo) ?? false;
});

// ---- Lo que baja al dispositivo ----

final plantasProvider = FutureProvider<Paginado<ClienteInstalacion>>(
  (ref) => _repo.plantas(),
);

/// Los valores de un catálogo, por su código.
final valoresCatalogoProvider =
    FutureProvider.family<List<CatalogoValor>, String>(
      (ref, codigo) => _repo.valoresDe(codigo),
    );

/// Los estados a los que se puede mover un activo (HU-038).
final estadosActivoProvider = FutureProvider<List<CatalogoValor>>(
  (ref) => _repo.valoresDe('ACTIVO_ESTADO'),
);

/// La cabecera de un activo (HU-037).
final activoProvider = FutureProvider.family<Activo, int>(
  (ref, id) => _repo.activo(id),
);

// ---- Activos ----

final fichaActivoProvider =
    FutureProvider.family<Paginado<ActivoFichaEvento>, int>(
      (ref, id) => _repo.fichaActivo(id),
    );

// ---- Componentes y medidores (vistas 8.x y 9.2) ----

/// Los componentes de un equipo — vista 8.1.
///
/// `.family` sobre el id del activo: la lista de un equipo no sirve para
/// otro, y compartir un solo provider haría que abrir el segundo mostrara
/// por un instante las piezas del primero.
final componentesProvider = FutureProvider.family<Paginado<Componente>, int?>(
  (ref, activo) => _repo.componentes(activo: activo),
);

/// La ficha de un componente — vista 8.2.
final componenteProvider = FutureProvider.family<Componente, int>(
  (ref, id) => _repo.componente(id),
);

/// Su línea de tiempo — vista 8.3.
final fichaComponenteProvider =
    FutureProvider.family<Paginado<ComponenteEvento>, int>(
      (ref, id) => _repo.fichaComponente(id),
    );

/// Las tres galerías — vistas 7.4, 8.4 y 10.4.
///
/// Tres providers y no uno con un discriminador: el id 12 de un activo y el
/// id 12 de un repuesto son cosas distintas, y un `.family` sobre un solo
/// entero las confundiría en la caché de Riverpod.
final galeriaComponenteProvider = FutureProvider.family<List<GaleriaFoto>, int>(
  (ref, id) => _repo.galeriaComponente(id),
);

final galeriaActivoProvider = FutureProvider.family<List<GaleriaFoto>, int>(
  (ref, id) => _repo.galeriaActivo(id),
);

final galeriaRepuestoProvider = FutureProvider.family<List<GaleriaFoto>, int>(
  (ref, id) => _repo.galeriaRepuesto(id),
);

/// Los medidores de un equipo — la puerta de 9.2.
final medidoresProvider = FutureProvider.family<List<Medidor>, int>(
  (ref, activo) => _repo.medidoresDe(activo),
);

/// Un medidor con sus umbrales.
final medidorProvider = FutureProvider.family<Medidor, int>(
  (ref, id) => _repo.medidor(id),
);

/// El tramo que se está mirando en el historial de lecturas.
///
/// Vive fuera de la pantalla porque el provider de lecturas lo observa: al
/// cambiar el rango se vuelve a pedir la serie, en vez de bajarla entera y
/// recortarla en el teléfono.
enum RangoLecturas {
  tresMeses('3 meses', 90),
  seisMeses('6 meses', 180),
  unAno('1 año', 365),
  todo('Todo', 0);

  const RangoLecturas(this.rotulo, this.dias);

  final String rotulo;

  /// 0 = sin límite.
  final int dias;

  DateTime? get desde =>
      dias == 0 ? null : DateTime.now().subtract(Duration(days: dias));
}

final rangoLecturasProvider = StateProvider<RangoLecturas>(
  (ref) => RangoLecturas.seisMeses,
);

/// El historial de lecturas — vista 9.2.
final lecturasProvider = FutureProvider.family<List<Lectura>, int>((ref, id) {
  final rango = ref.watch(rangoLecturasProvider);
  return _repo.lecturasDe(id, desde: rango.desde);
});

/// Las firmas de una orden — vista 6.7.
final validacionesProvider = FutureProvider.family<List<Validacion>, int>(
  (ref, id) => _repo.validaciones(id),
);

final tiposValidacionProvider = FutureProvider<List<ItemCatalogo>>(
  (ref) => _repo.tiposValidacion(),
);

/// Lo que subí yo — vista 13.2.
final misEvidenciasProvider = FutureProvider<List<EvidenciaMia>>(
  (ref) => _repo.misEvidencias(),
);

// ---- Inventario ----

/// El filtro de la pantalla de existencias: `null` = todas, `true` = solo lo
/// que está fuera de umbral.
final filtroExistenciasProvider = StateProvider<bool>((ref) => false);
final busquedaExistenciasProvider = StateProvider<String>((ref) => '');

/// Lo que se busca en la bandeja «Mi trabajo». **Uno solo para las cuatro
/// pestañas** —órdenes, tareas, pautas y bitácora— y también para la de
/// «Todo».
///
/// Vive acá y no dentro de la bandeja por dos razones: las cuatro listas que
/// lo leen son pantallas distintas, y ponerlo en una de ellas obligaría a las
/// otras tres a importarla —un ciclo—; y porque la pregunta es la misma en las
/// cuatro, así que cuatro estados sueltos habría que mantenerlos en fase o
/// explicar por qué lo escrito se pierde al cambiar de pestaña.
final busquedaBandejaProvider = StateProvider<String>((ref) => '');

final existenciasProvider = FutureProvider<Paginado<InventarioSaldo>>((ref) {
  final soloAlerta = ref.watch(filtroExistenciasProvider);
  final filtro = ref.watch(busquedaExistenciasProvider);
  return _repo.existencias(soloAlerta: soloAlerta, filtro: filtro);
});

/// El total sin filtrar, para el contador del chip "Todas".
///
/// **Reusa el listado cuando puede.** Con la pantalla recién abierta —sin
/// búsqueda y sin el chip de alerta— este provider pedía `/existencias` con
/// exactamente los mismos parámetros que [existenciasProvider]: dos viajes de
/// red idénticos para pintar una pantalla, y el contador tardando en aparecer
/// aunque la lista ya estuviera abajo.
final existenciasTotalProvider = FutureProvider<int>((ref) async {
  final filtro = ref.watch(busquedaExistenciasProvider);
  final soloAlerta = ref.watch(filtroExistenciasProvider);

  if (filtro.isEmpty && !soloAlerta) {
    return (await ref.watch(existenciasProvider.future)).total;
  }
  return (await _repo.existencias()).total;
});

/// Cuántas están bajo mínimo, para el contador del chip rojo.
final existenciasEnAlertaProvider = FutureProvider<int>((ref) async {
  final filtro = ref.watch(busquedaExistenciasProvider);
  final soloAlerta = ref.watch(filtroExistenciasProvider);

  // Con el chip de alerta puesto, el listado YA es la consulta de este
  // contador.
  if (filtro.isEmpty && soloAlerta) {
    return (await ref.watch(existenciasProvider.future)).total;
  }
  return (await _repo.existencias(soloAlerta: true)).total;
});

/// Los activos de la planta — vista 7.2. Salen de la sábana: no hay endpoint
/// de listado, y no hace falta.
final activosProvider = FutureProvider<List<Activo>>((ref) {
  // Se rehace al cambiar de planta: los activos de Renca no son los de Maipú.
  ref.watch(instalacionProvider);
  return _repo.activos();
});

/// El catálogo de repuestos — vista 10.2.
///
/// Con respaldo en disco, como todo catálogo: cambia una vez al mes y se
/// consulta delante del estante, donde no hay señal.
final repuestosProvider = FutureProvider<Paginado<Repuesto>>(
  (ref) => _repo.repuestos(),
);

/// Las bodegas de la planta — vista 10.5.
final bodegasProvider = FutureProvider<Paginado<Bodega>>(
  (ref) => _repo.bodegas(),
);

/// Una bodega — vista 10.6.
final bodegaProvider = FutureProvider.family<Bodega, int>(
  (ref, id) => _repo.bodega(id),
);

/// La cabecera de la ficha del repuesto (vista 10.3).
final repuestoProvider = FutureProvider.family<Repuesto, int>(
  (ref, id) => _repo.repuesto(id),
);

/// Dónde está un repuesto y cuánto hay en cada bodega.
///
/// Va aparte de [existenciasProvider]: aquel es **una fila por bodega** de toda
/// la planta y responde «qué está bajo mínimo»; éste es un repuesto y responde
/// «dónde lo encuentro». Sin paginar, porque un repuesto no vive en doscientas
/// bodegas.
final saldosRepuestoProvider =
    FutureProvider.family<List<InventarioSaldo>, int>(
      (ref, id) => _repo.saldosDeRepuesto(id),
    );

/// Los lotes de un repuesto, para la ficha. Solo se piden si el repuesto
/// controla lote.
final lotesProvider = FutureProvider.family<List<RepuestoLote>, int>(
  (ref, repuesto) => _repo.lotesDe(repuesto),
);

// ---- Checklist ----

final checklistPendientesProvider = FutureProvider<List<ChecklistPendiente>>((
  ref,
) {
  final instalacion = ref.watch(instalacionProvider);
  return _repo.checklistPendientes(instalacion: instalacion?.cin_id);
});

final checklistPlantillaProvider =
    FutureProvider.family<ChecklistPlantilla, int>(
      (ref, version) => _repo.checklistPlantilla(version),
    );

final checklistEjecucionProvider =
    FutureProvider.family<ChecklistEjecucion, int>(
      (ref, id) => _repo.checklistEjecucion(id),
    );

// ---- Ordenes de trabajo ----

/// Que se esta mirando en la bandeja: 1 mias, 2 disponibles, 3 todas.
final ambitoOrdenesProvider = StateProvider<int>((ref) => 1);

final ordenesTrabajoProvider = FutureProvider<List<OrdenTrabajo>>((ref) {
  final ambito = ref.watch(ambitoOrdenesProvider);
  final instalacion = ref.watch(instalacionProvider);
  return _repo.ordenesTrabajo(ambito: ambito, instalacion: instalacion?.cin_id);
});

/// Las disponibles para tomar. Va aparte de la bandeja porque el chip
/// "Disponibles" muestra su contador aunque se este mirando otra pestana.
final ordenesDisponiblesProvider = FutureProvider<List<OrdenTrabajo>>(
  (ref) => _repo.ordenesTrabajo(ambito: 2),
);

final ordenTrabajoProvider = FutureProvider.family<OrdenTrabajoFicha, int>(
  (ref, id) => _repo.ordenTrabajo(id),
);

/// La mano de obra y los repuestos de una orden. Van juntos porque la pantalla
/// de recursos los muestra en la misma vista: pedirlos aparte serian dos
/// viajes de red para dibujar una sola pantalla.
final recursosOrdenProvider = FutureProvider.family<RecursosOrden, int>(
  (ref, id) => _repo.recursosOrden(id),
);

/// Los motivos con que se puede cerrar una OT (HU-120).
///
/// Se pide al abrir la hoja de cierre y no al arrancar la app: son seis filas
/// que solo mira quien tiene `CERRAR OT`, y bajarlas para todos seria trafico
/// que la mayoria nunca usa.
final motivosCierreProvider = FutureProvider<List<CierreMotivo>>(
  (ref) => _repo.motivosCierre(),
);

/// Lo que se puede consumir contra una orden, con la compatibilidad marcada.
final repuestosOrdenProvider = FutureProvider.family<List<RepuestoOrden>, int>(
  (ref, ordenId) => _repo.repuestosDeOrden(ordenId),
);

// ---- Permisos de trabajo ----

final permisosTrabajoProvider = FutureProvider<Paginado<PermisoTrabajo>>(
  (ref) => _repo.permisosTrabajo(),
);

final permisosVigentesProvider = FutureProvider<Paginado<PermisoTrabajo>>(
  (ref) => _repo.permisosVigentes(),
);

/// La ficha de un permiso — vista 11.2.
final permisoProvider = FutureProvider.family<PermisoTrabajo, int>(
  (ref, id) => _repo.permiso(id),
);

final tiposPermisoProvider = FutureProvider<List<ItemCatalogo>>(
  (ref) => _repo.tiposPermiso(),
);

/// Los estados por los que se puede filtrar la bandeja de permisos.
///
/// Bajan en la sábana, así que los chips aparecen también sin señal — que es
/// cuando más se usa la bandeja.
final estadosPermisoProvider = FutureProvider<List<ItemCatalogo>>(
  (ref) => _repo.estadosPermiso(),
);

/// El estado por el que se está filtrando. `null` = cualquiera.
///
/// Guarda el **código** —`AUTORIZADO`— y no el nombre: el nombre es el texto
/// que se muestra y alguien puede reescribirlo desde la web, con o sin acento,
/// y ahí la comparación deja de calzar. El código es la identidad de la fila, y
/// por eso el SP lo devuelve aparte del nombre. Tampoco es el id, porque
/// `GET /permisos-trabajo` no lo trae.
final estadoPermisoProvider = StateProvider<String?>((ref) => null);

// ---- Alertas ----

final alertasProvider = FutureProvider<Paginado<Alerta>>(
  (ref) => _repo.alertas(),
);

/// El badge de la campana. Cuenta **no leídas**, no abiertas: un badge que
/// nunca baja deja de significar "mira esto".
final resumenAlertasProvider = FutureProvider<AlertaResumen>(
  (ref) => _repo.resumenAlertas(),
);

// ---- Escaneo ----

final escaneoProvider = FutureProvider.family<Escaneo, String>(
  (ref, codigo) => _repo.escanear(codigo),
);

// ---- Tareas en terreno (HU-103, HU-104) ----

final tareasPendientesProvider = FutureProvider<List<TareaPendiente>>((ref) {
  final instalacion = ref.watch(instalacionProvider);
  return _repo.tareasPendientes(instalacion: instalacion?.cin_id);
});

final tareaProvider = FutureProvider.family<Tarea, int>(
  (ref, id) => _repo.tarea(id),
);

/// Las fotos de algo. La familia es `destino|id` porque Riverpod necesita una
/// clave con igualdad por valor y un record de dos campos la da gratis.
final evidenciasProvider =
    FutureProvider.family<List<Evidencia>, (String, int)>(
      (ref, k) => _repo.evidencias(k.$1, k.$2),
    );

// ---- Bitácora de planta (HU-130, HU-131) ----

final bitacoraProvider = FutureProvider<List<BitacoraEntrada>>((ref) {
  final instalacion = ref.watch(instalacionProvider);
  return _repo.bitacora(instalacion: instalacion?.cin_id);
});

final tiposBitacoraProvider = FutureProvider<List<BitacoraTipo>>(
  (ref) => _repo.tiposBitacora(),
);

final entradaBitacoraProvider = FutureProvider.family<BitacoraFicha, int>(
  (ref, id) => _repo.entradaBitacora(id),
);

// ---- SIGMA AI (HU-173, HU-175) ----

final prediccionesProvider = FutureProvider<List<Prediccion>>((ref) {
  final instalacion = ref.watch(instalacionProvider);
  return _repo.predicciones(instalacion: instalacion?.cin_id);
});

final vigiladosProvider = FutureProvider<List<Vigilado>>((ref) {
  final instalacion = ref.watch(instalacionProvider);
  return _repo.vigilados(instalacion: instalacion?.cin_id);
});

final prediccionProvider = FutureProvider.family<PrediccionFicha, int>(
  (ref, id) => _repo.prediccion(id),
);

/// Los estantes de una bodega. `family` por bodega: la hoja de consumo solo
/// pregunta por la que tiene el repuesto delante.
final ubicacionesBodegaProvider =
    FutureProvider.family<List<BodegaUbicacion>, int>(
      (ref, bodegaId) => _repo.ubicacionesDeBodega(bodegaId),
    );

// ---- Favoritos marcados en esta sesión ----

/// Lo que la persona acaba de marcar o desmarcar, por entidad.
///
/// ## Por qué existe en vez de invalidar la lista
///
/// `ref.invalidate(ordenesTrabajoProvider)` volvería a pedir la bandeja y la
/// reordenaría **bajo el dedo**: la orden recién marcada saltaría a la primera
/// posición y la siguiente que se quiere marcar ya no está donde estaba.
///
/// Pero sin nada, el contador del chip «★ Míos» y su filtro se quedaban con el
/// `ES_FAVORITO` que trajo el servidor, así que la estrella se encendía y no
/// servía para nada hasta recargar a mano.
///
/// Esta capa resuelve las dos: la lista **no se vuelve a pedir** —el orden no
/// se mueve— y el contador y el filtro sí ven el cambio, porque consultan
/// [esFavorito] en vez del campo crudo.
class FavoritosLocales extends Notifier<Map<(String, int), bool>> {
  @override
  Map<(String, int), bool> build() => const {};

  void marcar(String entidad, int id, bool valor) {
    state = {...state, (entidad, id): valor};
  }

  /// El valor de la sesión si lo hay; si no, el que trajo el servidor.
  bool resuelto(String entidad, int id, bool delServidor) =>
      state[(entidad, id)] ?? delServidor;
}

final favoritosLocalesProvider =
    NotifierProvider<FavoritosLocales, Map<(String, int), bool>>(
      FavoritosLocales.new,
    );
