// ignore_for_file: non_constant_identifier_names
//
// El lint pide lowerCamelCase. Acá NO se aplica, y es deliberado: cada campo
// se llama igual que en el DTO de la API, que se llama igual que la columna de
// SQL Server. Renombrar a camelCase obliga a mantener un diccionario mental
// entre tres capas —Dart, C# y el SP— y es justo donde aparecen los errores
// que nadie encuentra leyendo. Decisión escrita en
// MD/SIGMA_APP_ARQUITECTURA.md §8.

// Los modelos de la app.
//
// REGLA: cada campo se llama **igual que en el DTO de la API**, que a su vez
// se llama igual que la columna de SQL Server. Traducir a camelCase obliga a
// mantener un diccionario mental entre tres capas, y es donde aparecen los
// errores que nadie encuentra leyendo.
//
// Y todos los `fromJson` son tolerantes al NULL. En el sitio web,
// `int.Parse()` sobre una columna anulable reventó la pantalla tres veces; el
// equivalente en Dart es `(j['x'] as num).toInt()` sobre un null.

int _i(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
int? _iN(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v, [double d = 0]) => (v as num?)?.toDouble() ?? d;
double? _dN(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v, [String d = '']) => (v as String?)?.trim() ?? d;
String? _sN(dynamic v) {
  final s = (v as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

bool _b(dynamic v, [bool d = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return d;
}

DateTime? _f(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// Una planta del cliente. `GET /cliente-instalaciones`
class ClienteInstalacion {
  const ClienteInstalacion({
    required this.cin_id,
    required this.cin_nombre,
    this.cin_codigo,
    this.cin_direccion,
    this.cin_habilitado = true,
  });

  final int cin_id;
  final String cin_nombre;
  final String? cin_codigo;
  final String? cin_direccion;
  final bool cin_habilitado;

  factory ClienteInstalacion.fromJson(Map<String, dynamic> j) =>
      ClienteInstalacion(
        cin_id: _i(j['cin_id']),
        cin_nombre: _s(j['cin_nombre']),
        cin_codigo: _sN(j['cin_codigo']),
        cin_direccion: _sN(j['cin_direccion']),
        cin_habilitado: _b(j['cin_habilitado'], true),
      );
}

/// Un área de una planta. `GET /instalacion-areas`
class InstalacionArea {
  const InstalacionArea({
    required this.iar_id,
    required this.iar_nombre,
    this.iar_codigo,
    this.RUTA,
    this.NIVEL = 0,
  });

  final int iar_id;
  final String iar_nombre;
  final String? iar_codigo;
  final String? RUTA;
  final int NIVEL;

  factory InstalacionArea.fromJson(Map<String, dynamic> j) => InstalacionArea(
        iar_id: _i(j['iar_id']),
        iar_nombre: _s(j['iar_nombre']),
        iar_codigo: _sN(j['iar_codigo']),
        RUTA: _sN(j['RUTA']),
        NIVEL: _i(j['NIVEL']),
      );
}

/// `GET /catalogos`
class Catalogo {
  const Catalogo({
    required this.ctl_id,
    required this.ctl_codigo,
    required this.ctl_nombre,
    this.ctl_modulo,
  });

  final int ctl_id;
  final String ctl_codigo;
  final String ctl_nombre;
  final String? ctl_modulo;

  factory Catalogo.fromJson(Map<String, dynamic> j) => Catalogo(
        ctl_id: _i(j['ctl_id']),
        ctl_codigo: _s(j['ctl_codigo']),
        ctl_nombre: _s(j['ctl_nombre']),
        ctl_modulo: _sN(j['ctl_modulo']),
      );
}


/// `GET /mi-perfil`
class MiPerfil {
  const MiPerfil({
    required this.usu_id,
    required this.usu_login,
    required this.usu_nombre,
    this.usu_apellido_paterno,
    this.usu_apellido_materno,
    this.usu_correo,
    this.usu_telefono,
    this.PERFILES,
  });

  final int usu_id;
  final String usu_login;
  final String usu_nombre;
  final String? usu_apellido_paterno;
  final String? usu_apellido_materno;
  final String? usu_correo;
  final String? usu_telefono;
  final String? PERFILES;

  String get nombreCompleto =>
      [usu_nombre, usu_apellido_paterno].where((s) => (s ?? '').isNotEmpty).join(' ');

  /// Las iniciales del avatar de la barra superior.
  String get iniciales {
    final n = usu_nombre.isNotEmpty ? usu_nombre[0] : '';
    final a = (usu_apellido_paterno ?? '').isNotEmpty
        ? usu_apellido_paterno![0]
        : '';
    final r = '$n$a'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  factory MiPerfil.fromJson(Map<String, dynamic> j) => MiPerfil(
        usu_id: _i(j['usu_id']),
        usu_login: _s(j['usu_login']),
        usu_nombre: _s(j['usu_nombre']),
        usu_apellido_paterno: _sN(j['usu_apellido_paterno']),
        usu_apellido_materno: _sN(j['usu_apellido_materno']),
        usu_correo: _sN(j['usu_correo']),
        usu_telefono: _sN(j['usu_telefono']),
        PERFILES: _sN(j['PERFILES']),
      );
}

/// Un nodo del menú. `GET /menus`
///
/// El árbol lo resuelve el servidor: solo filas con `mnu_ambito` APP o AMBOS,
/// comparadas contra los permisos vigentes con la misma función que usa la
/// web. Acá no se filtra nada, y por eso no hay dos modelos de permisos.
class MenuNodo {
  const MenuNodo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.ruta,
    this.icono,
    this.hijos = const [],
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final String? ruta; // "app://inicio"
  final String? icono; // "mdi mdi-home-outline"
  final List<MenuNodo> hijos;

  factory MenuNodo.fromJson(Map<String, dynamic> j) => MenuNodo(
        id: _i(j['id']),
        nombre: _s(j['nombre']),
        descripcion: _sN(j['descripcion']),
        ruta: _sN(j['ruta']),
        icono: _sN(j['icono']),
        hijos: ((j['hijos'] as List?) ?? const [])
            .map((e) => MenuNodo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Cuánto hay de un repuesto y dónde. `GET /existencias`
class InventarioSaldo {
  const InventarioSaldo({
    required this.isa_id,
    required this.isa_repuesto,
    required this.isa_bodega,
    required this.CANTIDAD_DISPONIBLE,
    required this.REPUESTO_CODIGO,
    required this.REPUESTO_NOMBRE,
    this.UNIDAD_SIMBOLO,
    this.BODEGA_NOMBRE,
    this.PLANTA_NOMBRE,
    this.UBICACION_CODIGO,
    this.rbs_stock_minimo,
    this.rbs_stock_maximo,
    this.BAJO_MINIMO = 0,
    this.SOBRE_MAXIMO = 0,
    this.isa_fecha_ultimo_movimiento,
  });

  final int isa_id;
  final int isa_repuesto;
  final int isa_bodega;
  final double CANTIDAD_DISPONIBLE;
  final String REPUESTO_CODIGO;
  final String REPUESTO_NOMBRE;
  final String? UNIDAD_SIMBOLO;
  final String? BODEGA_NOMBRE;
  final String? PLANTA_NOMBRE;
  final String? UBICACION_CODIGO;
  final double? rbs_stock_minimo;
  final double? rbs_stock_maximo;
  final int BAJO_MINIMO;
  final int SOBRE_MAXIMO;

  /// Con esto la app puede decir **de cuándo** es lo que muestra cuando no
  /// hay señal (HU-056 CA2).
  final DateTime? isa_fecha_ultimo_movimiento;

  bool get bajoMinimo => BAJO_MINIMO == 1;
  bool get sobreMaximo => SOBRE_MAXIMO == 1;

  /// Dónde está, armado con lo que venga: bodega, pasillo/estante y planta.
  String get ubicacion => [
        BODEGA_NOMBRE,
        UBICACION_CODIGO,
        PLANTA_NOMBRE,
      ].where((s) => (s ?? '').isNotEmpty).join(' · ');

  factory InventarioSaldo.fromJson(Map<String, dynamic> j) => InventarioSaldo(
        isa_id: _i(j['isa_id']),
        isa_repuesto: _i(j['isa_repuesto']),
        isa_bodega: _i(j['isa_bodega']),
        CANTIDAD_DISPONIBLE: _d(j['CANTIDAD_DISPONIBLE']),
        REPUESTO_CODIGO: _s(j['REPUESTO_CODIGO']),
        REPUESTO_NOMBRE: _s(j['REPUESTO_NOMBRE']),
        UNIDAD_SIMBOLO: _sN(j['UNIDAD_SIMBOLO']),
        BODEGA_NOMBRE: _sN(j['BODEGA_NOMBRE']),
        PLANTA_NOMBRE: _sN(j['PLANTA_NOMBRE']),
        UBICACION_CODIGO: _sN(j['UBICACION_CODIGO']),
        rbs_stock_minimo: _dN(j['rbs_stock_minimo']),
        rbs_stock_maximo: _dN(j['rbs_stock_maximo']),
        BAJO_MINIMO: _i(j['BAJO_MINIMO']),
        SOBRE_MAXIMO: _i(j['SOBRE_MAXIMO']),
        isa_fecha_ultimo_movimiento: _f(j['isa_fecha_ultimo_movimiento']),
      );
}

/// `GET /repuestos`
class Repuesto {
  const Repuesto({
    required this.rep_id,
    required this.rep_codigo,
    required this.rep_nombre,
    this.rep_fabricante,
    this.rep_modelo,
    this.UNIDAD_SIMBOLO,
    this.EXISTENCIA_TOTAL = 0,
    this.rep_controla_lote = false,
  });

  final int rep_id;
  final String rep_codigo;
  final String rep_nombre;
  final String? rep_fabricante;
  final String? rep_modelo;
  final String? UNIDAD_SIMBOLO;
  final double EXISTENCIA_TOTAL;
  final bool rep_controla_lote;

  String get descripcionCorta =>
      [rep_fabricante, rep_modelo].where((s) => (s ?? '').isNotEmpty).join(' ');

  factory Repuesto.fromJson(Map<String, dynamic> j) => Repuesto(
        rep_id: _i(j['rep_id']),
        rep_codigo: _s(j['rep_codigo']),
        rep_nombre: _s(j['rep_nombre']),
        rep_fabricante: _sN(j['rep_fabricante']),
        rep_modelo: _sN(j['rep_modelo']),
        UNIDAD_SIMBOLO: _sN(j['UNIDAD_SIMBOLO']),
        EXISTENCIA_TOTAL: _d(j['EXISTENCIA_TOTAL']),
        rep_controla_lote: _b(j['rep_controla_lote']),
      );
}

/// `GET /repuestos/{id}/lotes`
class RepuestoLote {
  const RepuestoLote({
    required this.rlo_id,
    required this.rlo_codigo,
    this.rlo_fecha_ingreso,
    this.rlo_fecha_vencimiento,
    this.VENCIDO = 0,
  });

  final int rlo_id;
  final String rlo_codigo;
  final DateTime? rlo_fecha_ingreso;
  final DateTime? rlo_fecha_vencimiento;
  final int VENCIDO;

  bool get vencido => VENCIDO == 1;

  factory RepuestoLote.fromJson(Map<String, dynamic> j) => RepuestoLote(
        rlo_id: _i(j['rlo_id']),
        rlo_codigo: _s(j['rlo_codigo']),
        rlo_fecha_ingreso: _f(j['rlo_fecha_ingreso']),
        rlo_fecha_vencimiento: _f(j['rlo_fecha_vencimiento']),
        VENCIDO: _i(j['VENCIDO']),
      );
}

/// `GET /bodegas`
class Bodega {
  const Bodega({
    required this.bod_id,
    required this.bod_codigo,
    required this.bod_nombre,
    this.PLANTA_NOMBRE,
  });

  final int bod_id;
  final String bod_codigo;
  final String bod_nombre;
  final String? PLANTA_NOMBRE;

  factory Bodega.fromJson(Map<String, dynamic> j) => Bodega(
        bod_id: _i(j['bod_id']),
        bod_codigo: _s(j['bod_codigo']),
        bod_nombre: _s(j['bod_nombre']),
        PLANTA_NOMBRE: _sN(j['PLANTA_NOMBRE']),
      );
}

/// `GET /inventario-movimientos`
class InventarioMovimiento {
  const InventarioMovimiento({
    required this.imo_id,
    required this.imo_cantidad,
    required this.TIPO_NOMBRE,
    required this.REPUESTO_NOMBRE,
    this.TIPO_CODIGO,
    this.FAMILIA,
    this.SIGNO = 0,
    this.REPUESTO_CODIGO,
    this.UNIDAD_SIMBOLO,
    this.BODEGA_CODIGO,
    this.LOTE_CODIGO,
    this.USUARIO_NOMBRE,
    this.imo_fecha_movimiento_utc,
    this.imo_observacion,
  });

  final int imo_id;
  final double imo_cantidad;
  final String TIPO_NOMBRE;
  final String REPUESTO_NOMBRE;
  final String? TIPO_CODIGO;
  final String? FAMILIA;

  /// El SP lo resuelve porque `imo_cantidad` siempre es positiva.
  final int SIGNO;

  final String? REPUESTO_CODIGO;
  final String? UNIDAD_SIMBOLO;
  final String? BODEGA_CODIGO;
  final String? LOTE_CODIGO;
  final String? USUARIO_NOMBRE;
  final DateTime? imo_fecha_movimiento_utc;
  final String? imo_observacion;

  factory InventarioMovimiento.fromJson(Map<String, dynamic> j) =>
      InventarioMovimiento(
        imo_id: _i(j['imo_id']),
        imo_cantidad: _d(j['imo_cantidad']),
        TIPO_NOMBRE: _s(j['TIPO_NOMBRE']),
        REPUESTO_NOMBRE: _s(j['REPUESTO_NOMBRE']),
        TIPO_CODIGO: _sN(j['TIPO_CODIGO']),
        FAMILIA: _sN(j['FAMILIA']),
        SIGNO: _i(j['SIGNO']),
        REPUESTO_CODIGO: _sN(j['REPUESTO_CODIGO']),
        UNIDAD_SIMBOLO: _sN(j['UNIDAD_SIMBOLO']),
        BODEGA_CODIGO: _sN(j['BODEGA_CODIGO']),
        LOTE_CODIGO: _sN(j['LOTE_CODIGO']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
        imo_fecha_movimiento_utc: _f(j['imo_fecha_movimiento_utc']),
        imo_observacion: _sN(j['imo_observacion']),
      );
}

/// `GET /permisos-trabajo` y `/vigentes`
class PermisoTrabajo {
  const PermisoTrabajo({
    required this.ptr_id,
    required this.ptr_numero,
    required this.TIPO_NOMBRE,
    required this.ESTADO_NOMBRE,
    this.ESTADO_CODIGO,
    this.SITUACION,
    this.DIAS_RESTANTES,
    this.SOLICITANTE_NOMBRE,
    this.ORDEN_CORRELATIVO,
    this.ORDEN_TITULO,
    this.ptr_observacion,
    this.ptr_fecha_vigencia_inicio_utc,
    this.ptr_fecha_vigencia_fin_utc,
    this.TIENE_DOCUMENTO = false,
  });

  final int ptr_id;
  final String ptr_numero;
  final String TIPO_NOMBRE;
  final String ESTADO_NOMBRE;
  final String? ESTADO_CODIGO;

  /// VIGENTE · POR VENCER · VENCIDO. Lo decide el SP, no la pantalla.
  final String? SITUACION;

  final int? DIAS_RESTANTES;
  final String? SOLICITANTE_NOMBRE;
  final String? ORDEN_CORRELATIVO;
  final String? ORDEN_TITULO;
  final String? ptr_observacion;
  final DateTime? ptr_fecha_vigencia_inicio_utc;
  final DateTime? ptr_fecha_vigencia_fin_utc;
  final bool TIENE_DOCUMENTO;

  factory PermisoTrabajo.fromJson(Map<String, dynamic> j) => PermisoTrabajo(
        ptr_id: _i(j['ptr_id']),
        ptr_numero: _s(j['ptr_numero']),
        TIPO_NOMBRE: _s(j['TIPO_NOMBRE']),
        ESTADO_NOMBRE: _s(j['ESTADO_NOMBRE']),
        ESTADO_CODIGO: _sN(j['ESTADO_CODIGO']),
        SITUACION: _sN(j['SITUACION']),
        DIAS_RESTANTES: _iN(j['DIAS_RESTANTES']),
        SOLICITANTE_NOMBRE: _sN(j['SOLICITANTE_NOMBRE']),
        ORDEN_CORRELATIVO: _sN(j['ORDEN_CORRELATIVO']),
        ORDEN_TITULO: _sN(j['ORDEN_TITULO']),
        ptr_observacion: _sN(j['ptr_observacion']),
        ptr_fecha_vigencia_inicio_utc: _f(j['ptr_fecha_vigencia_inicio_utc']),
        ptr_fecha_vigencia_fin_utc: _f(j['ptr_fecha_vigencia_fin_utc']),
        TIENE_DOCUMENTO: _b(j['TIENE_DOCUMENTO']),
      );
}

/// `GET /permisos-trabajo/tipos` y `/estados`
class ItemCatalogo {
  const ItemCatalogo({required this.id, required this.codigo, required this.nombre});

  final int id;
  final String codigo;
  final String nombre;

  /// Los SP de permisos devuelven las columnas en MAYÚSCULAS con prefijo.
  factory ItemCatalogo.desde(Map<String, dynamic> j, String pfx) => ItemCatalogo(
        id: _i(j['${pfx}_ID']),
        codigo: _s(j['${pfx}_CODIGO']),
        nombre: _s(j['${pfx}_NOMBRE']),
      );
}

/// `GET /alertas`
class Alerta {
  const Alerta({
    required this.ale_id,
    required this.ale_titulo,
    required this.sev_codigo,
    this.ale_descripcion,
    this.alt_nombre,
    this.FICHA_LINK,
    this.FICHA_ID = 0,
    this.LEIDA = 0,
    this.MINUTOS = 0,
    this.ale_fecha_deteccion_utc,
  });

  final int ale_id;
  final String ale_titulo;
  final String? ale_descripcion;
  final String? alt_nombre;

  /// NORMAL · BAJA · ADVERTENCIA · ALTA · CRÍTICA.
  /// El SP guarda cuán grave es; la pantalla decide de qué color se ve.
  final String sev_codigo;

  final String? FICHA_LINK;
  final int FICHA_ID;
  final int LEIDA;
  final int MINUTOS;
  final DateTime? ale_fecha_deteccion_utc;

  bool get leida => LEIDA == 1;

  /// "hace 12 min", "hace 3 h", "ayer".
  String get hace {
    if (MINUTOS < 1) return 'recién';
    if (MINUTOS < 60) return 'hace $MINUTOS min';
    final h = MINUTOS ~/ 60;
    if (h < 24) return 'hace $h h';
    final d = h ~/ 24;
    return d == 1 ? 'ayer' : 'hace $d días';
  }

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        ale_id: _i(j['ale_id']),
        ale_titulo: _s(j['ale_titulo']),
        ale_descripcion: _sN(j['ale_descripcion']),
        alt_nombre: _sN(j['alt_nombre']),
        sev_codigo: _s(j['sev_codigo'], 'NORMAL'),
        FICHA_LINK: _sN(j['FICHA_LINK']),
        FICHA_ID: _i(j['FICHA_ID']),
        LEIDA: _i(j['LEIDA']),
        MINUTOS: _i(j['MINUTOS']),
        ale_fecha_deteccion_utc: _f(j['ale_fecha_deteccion_utc']),
      );
}

/// `GET /alertas/resumen`
class AlertaResumen {
  const AlertaResumen({this.ABIERTAS = 0, this.NO_LEIDAS = 0});

  final int ABIERTAS;
  final int NO_LEIDAS;

  factory AlertaResumen.fromJson(Map<String, dynamic> j) => AlertaResumen(
        ABIERTAS: _i(j['ABIERTAS']),
        NO_LEIDAS: _i(j['NO_LEIDAS']),
      );
}


/// Un evento del historial de un activo. `GET /activos/{id}/ficha`
class ActivoFichaEvento {
  const ActivoFichaEvento({
    required this.TITULO,
    this.FECHA,
    this.TIPO_EVENTO,
    this.DETALLE,
    this.USUARIO_NOMBRE,
  });

  final String TITULO;
  final DateTime? FECHA;
  final String? TIPO_EVENTO;
  final String? DETALLE;
  final String? USUARIO_NOMBRE;

  factory ActivoFichaEvento.fromJson(Map<String, dynamic> j) =>
      ActivoFichaEvento(
        TITULO: _s(j['TITULO']),
        FECHA: _f(j['FECHA']),
        TIPO_EVENTO: _sN(j['TIPO_EVENTO']),
        DETALLE: _sN(j['DETALLE']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
      );
}

/// Lo que resuelve un código escaneado. `GET /escaneo?c=…`
class Escaneo {
  const Escaneo({
    required this.tipo,
    required this.id,
    this.cabecera,
    this.lineas = const [],
  });

  /// REPUESTO · UBICACION · BODEGA · ACTIVO.
  final String tipo;
  final int id;
  final EscaneoCabecera? cabecera;
  final List<EscaneoLinea> lineas;

  factory Escaneo.fromJson(Map<String, dynamic> j) => Escaneo(
        tipo: _s(j['tipo']),
        id: _i(j['id']),
        cabecera: j['cabecera'] is Map<String, dynamic>
            ? EscaneoCabecera.fromJson(j['cabecera'] as Map<String, dynamic>)
            : null,
        lineas: ((j['lineas'] as List?) ?? const [])
            .map((e) => EscaneoLinea.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class EscaneoCabecera {
  const EscaneoCabecera({
    this.rep_codigo,
    this.rep_nombre,
    this.bod_nombre,
    this.bub_codigo,
    this.bub_nombre,
    this.PLANTA,
    this.UNIDAD,
    this.TOTAL,
  });

  final String? rep_codigo;
  final String? rep_nombre;
  final String? bod_nombre;
  final String? bub_codigo;
  final String? bub_nombre;
  final String? PLANTA;
  final String? UNIDAD;
  final double? TOTAL;

  factory EscaneoCabecera.fromJson(Map<String, dynamic> j) => EscaneoCabecera(
        rep_codigo: _sN(j['rep_codigo']),
        rep_nombre: _sN(j['rep_nombre']),
        bod_nombre: _sN(j['bod_nombre']),
        bub_codigo: _sN(j['bub_codigo']),
        bub_nombre: _sN(j['bub_nombre']),
        PLANTA: _sN(j['PLANTA']),
        UNIDAD: _sN(j['UNIDAD']),
        TOTAL: _dN(j['TOTAL']),
      );
}

class EscaneoLinea {
  const EscaneoLinea({
    required this.rep_codigo,
    required this.rep_nombre,
    required this.CANTIDAD,
    this.BODEGA,
    this.UBICACION,
    this.UNIDAD,
    this.LOTE_CODIGO,
    this.DIAS_PARA_VENCER,
    this.ULTIMO_USUARIO,
    this.ULTIMO_MOVIMIENTO,
  });

  final String rep_codigo;
  final String rep_nombre;
  final double CANTIDAD;
  final String? BODEGA;
  final String? UBICACION;
  final String? UNIDAD;
  final String? LOTE_CODIGO;
  final int? DIAS_PARA_VENCER;
  final String? ULTIMO_USUARIO;
  final DateTime? ULTIMO_MOVIMIENTO;

  factory EscaneoLinea.fromJson(Map<String, dynamic> j) => EscaneoLinea(
        rep_codigo: _s(j['rep_codigo']),
        rep_nombre: _s(j['rep_nombre']),
        CANTIDAD: _d(j['CANTIDAD']),
        BODEGA: _sN(j['BODEGA']),
        UBICACION: _sN(j['UBICACION']),
        UNIDAD: _sN(j['UNIDAD']),
        LOTE_CODIGO: _sN(j['LOTE_CODIGO']),
        DIAS_PARA_VENCER: _iN(j['DIAS_PARA_VENCER']),
        ULTIMO_USUARIO: _sN(j['ULTIMO_USUARIO']),
        ULTIMO_MOVIMIENTO: _f(j['ULTIMO_MOVIMIENTO']),
      );
}




// ═══════════════════════════════════════════════ ORDENES DE TRABAJO ══

/// Una orden de trabajo. `GET /ordenes-trabajo`
///
/// ## Lo que ya viene resuelto del servidor
///
/// `SITUACION` —VENCIDA, VENCE HOY, EN PLAZO— y el avance de pasos los
/// calcula el SP. **La app no resta fechas ni cuenta filas**: si lo hiciera,
/// dos telefonos con distinta hora darian veredictos distintos sobre la misma
/// orden, y el que va atrasado creeria que esta en plazo.
class OrdenTrabajo {
  const OrdenTrabajo({
    required this.otr_id,
    required this.otr_correlativo,
    required this.OT_NUMERO,
    required this.otr_titulo,
    this.otr_uuid,
    this.otr_descripcion,
    this.otr_notas,
    this.otr_resultado,
    this.otr_fecha_evento_utc,
    this.otr_fecha_programada_utc,
    this.otr_fecha_inicio_real_utc,
    this.otr_fecha_fin_real_utc,
    this.otr_duracion_estimada_minuto,
    this.otr_requiere_permiso = false,
    this.ESTADO_ID = 1,
    this.ESTADO_CODIGO,
    this.ESTADO_NOMBRE,
    this.PRIORIDAD_ID = 2,
    this.PRIORIDAD_CODIGO,
    this.PRIORIDAD_NOMBRE,
    this.TIPO_NOMBRE,
    this.ESTRATEGIA_NOMBRE,
    this.ACTIVO_ID,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.ACTIVO_FOTO,
    this.POSICION_CODIGO,
    this.ES_FAVORITO = false,
    this.PLANTA_NOMBRE,
    this.AREA_NOMBRE,
    this.RESPONSABLE_ID,
    this.RESPONSABLE_NOMBRE,
    this.PASOS_TOTAL = 0,
    this.PASOS_LISTOS = 0,
    this.SITUACION,
    this.DIAS_RESTANTES,
    this.ES_MIA = false,
    this.PERMISO_NUMERO,
  });

  final int otr_id;
  final String? otr_uuid;
  final int otr_correlativo;

  /// «OT-1176». Lo arma el SP para que la web y la app lo escriban igual.
  final String OT_NUMERO;

  final String otr_titulo;
  final String? otr_descripcion;
  final String? otr_notas;
  final String? otr_resultado;

  final DateTime? otr_fecha_evento_utc;
  final DateTime? otr_fecha_programada_utc;
  final DateTime? otr_fecha_inicio_real_utc;
  final DateTime? otr_fecha_fin_real_utc;
  final int? otr_duracion_estimada_minuto;
  final bool otr_requiere_permiso;

  /// 1 ABIERTA, 2 EN EJECUCION, 3 EN ESPERA DE CIERRE, 4 CERRADA.
  final int ESTADO_ID;
  final String? ESTADO_CODIGO;
  final String? ESTADO_NOMBRE;

  /// 1 BAJA, 2 MEDIA, 3 ALTA, 4 CRITICA.
  final int PRIORIDAD_ID;
  final String? PRIORIDAD_CODIGO;
  final String? PRIORIDAD_NOMBRE;

  final String? TIPO_NOMBRE;
  final String? ESTRATEGIA_NOMBRE;

  final int? ACTIVO_ID;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;

  /// «MOT-001 · Motor principal línea 3». Vacío si la orden no cuelga de un
  /// activo —una limpieza general, por ejemplo—, y ahí la tarjeta lo dice.
  String get activo => [ACTIVO_CODIGO, ACTIVO_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  /// La foto del activo y la línea donde está montado.
  ///
  /// En una bandeja de doce órdenes el nombre no basta: puede haber cinco
  /// motores iguales y solo uno está en la Línea 3. La foto llega como **ruta
  /// de blob**, así que tres órdenes del mismo equipo comparten una sola
  /// descarga —`ImagenService` deduplica por ruta y la guarda en disco—.
  final String? ACTIVO_FOTO;
  final String? POSICION_CODIGO;

  /// Si esta persona lo fijó arriba de su bandeja.
  ///
  /// Viaja **dentro** del listado y no en una consulta aparte: pedirlo por
  /// separado haría que las estrellas se encendieran de a una sobre una lista
  /// ya dibujada.
  final bool ES_FAVORITO;
  final String? PLANTA_NOMBRE;
  final String? AREA_NOMBRE;

  final int? RESPONSABLE_ID;
  final String? RESPONSABLE_NOMBRE;

  final int PASOS_TOTAL;
  final int PASOS_LISTOS;

  /// VENCIDA · VENCE HOY · EN PLAZO · SIN PLAZO. Lo decide el SP.
  final String? SITUACION;
  final int? DIAS_RESTANTES;

  final bool ES_MIA;
  final String? PERMISO_NUMERO;

  bool get abierta => ESTADO_ID == 1;
  bool get enEjecucion => ESTADO_ID == 2;
  bool get vencida => (SITUACION ?? '').toUpperCase() == 'VENCIDA';
  bool get sinResponsable => RESPONSABLE_ID == null;

  /// 0–1. Cero pasos es cero avance, no división por cero.
  double get avance =>
      PASOS_TOTAL == 0 ? 0 : (PASOS_LISTOS / PASOS_TOTAL).clamp(0, 1);

  /// «MOT-001 · Envasado» con lo que venga.
  /// «Quilicura › Envasado › L3-P02». La **línea** entra acá porque es lo que
  /// distingue dos equipos iguales; el código del activo ya no, porque ahora
  /// se muestra en su propia fila junto al nombre.
  String get ubicacion => [PLANTA_NOMBRE, AREA_NOMBRE, POSICION_CODIGO]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  factory OrdenTrabajo.fromJson(Map<String, dynamic> j) => OrdenTrabajo(
        otr_id: _i(j['otr_id']),
        otr_uuid: _sN(j['otr_uuid']),
        otr_correlativo: _i(j['otr_correlativo']),
        OT_NUMERO: _s(j['OT_NUMERO']),
        otr_titulo: _s(j['otr_titulo']),
        otr_descripcion: _sN(j['otr_descripcion']),
        otr_notas: _sN(j['otr_notas']),
        otr_resultado: _sN(j['otr_resultado']),
        otr_fecha_evento_utc: _f(j['otr_fecha_evento_utc']),
        otr_fecha_programada_utc: _f(j['otr_fecha_programada_utc']),
        otr_fecha_inicio_real_utc: _f(j['otr_fecha_inicio_real_utc']),
        otr_fecha_fin_real_utc: _f(j['otr_fecha_fin_real_utc']),
        otr_duracion_estimada_minuto:
            j['otr_duracion_estimada_minuto'] == null
                ? null
                : _i(j['otr_duracion_estimada_minuto']),
        otr_requiere_permiso: _b(j['otr_requiere_permiso']),
        ESTADO_ID: _i(j['ESTADO_ID'], 1),
        ESTADO_CODIGO: _sN(j['ESTADO_CODIGO']),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        PRIORIDAD_ID: _i(j['PRIORIDAD_ID'], 2),
        PRIORIDAD_CODIGO: _sN(j['PRIORIDAD_CODIGO']),
        PRIORIDAD_NOMBRE: _sN(j['PRIORIDAD_NOMBRE']),
        TIPO_NOMBRE: _sN(j['TIPO_NOMBRE']),
        ESTRATEGIA_NOMBRE: _sN(j['ESTRATEGIA_NOMBRE']),
        ACTIVO_ID: j['ACTIVO_ID'] == null ? null : _i(j['ACTIVO_ID']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        ACTIVO_FOTO: _sN(j['ACTIVO_FOTO']),
        POSICION_CODIGO: _sN(j['POSICION_CODIGO']),
        ES_FAVORITO: _b(j['ES_FAVORITO']),
        PLANTA_NOMBRE: _sN(j['PLANTA_NOMBRE']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        RESPONSABLE_ID:
            j['RESPONSABLE_ID'] == null ? null : _i(j['RESPONSABLE_ID']),
        RESPONSABLE_NOMBRE: _sN(j['RESPONSABLE_NOMBRE']),
        PASOS_TOTAL: _i(j['PASOS_TOTAL']),
        PASOS_LISTOS: _i(j['PASOS_LISTOS']),
        SITUACION: _sN(j['SITUACION']),
        DIAS_RESTANTES:
            j['DIAS_RESTANTES'] == null ? null : _i(j['DIAS_RESTANTES']),
        ES_MIA: _b(j['ES_MIA']),
        PERMISO_NUMERO: _sN(j['PERMISO_NUMERO']),
      );
}

/// Un paso de la orden.
class OrdenTrabajoPaso {
  const OrdenTrabajoPaso({
    required this.otp_id,
    required this.otp_orden,
    required this.otp_nombre,
    this.otp_descripcion,
    this.otp_obligatorio = true,
    this.RESULTADO_ID = 4,
    this.RESULTADO_CODIGO,
    this.RESULTADO_NOMBRE,
    this.OBSERVACION,
    this.EJECUTOR_NOMBRE,
    this.otp_fecha_ejecucion_utc,
  });

  final int otp_id;
  final int otp_orden;
  final String otp_nombre;
  final String? otp_descripcion;
  final bool otp_obligatorio;

  /// 1 CONFORME, 2 NO CONFORME, 3 NO APLICA, 4 PENDIENTE.
  final int RESULTADO_ID;
  final String? RESULTADO_CODIGO;
  final String? RESULTADO_NOMBRE;

  final String? OBSERVACION;
  final String? EJECUTOR_NOMBRE;
  final DateTime? otp_fecha_ejecucion_utc;

  bool get pendiente => RESULTADO_ID == 4;
  bool get conforme => RESULTADO_ID == 1;
  bool get noConforme => RESULTADO_ID == 2;

  factory OrdenTrabajoPaso.fromJson(Map<String, dynamic> j) =>
      OrdenTrabajoPaso(
        otp_id: _i(j['otp_id']),
        otp_orden: _i(j['otp_orden']),
        otp_nombre: _s(j['otp_nombre']),
        otp_descripcion: _sN(j['otp_descripcion']),
        otp_obligatorio: _b(j['otp_obligatorio'], true),
        RESULTADO_ID: _i(j['RESULTADO_ID'], 4),
        RESULTADO_CODIGO: _sN(j['RESULTADO_CODIGO']),
        RESULTADO_NOMBRE: _sN(j['RESULTADO_NOMBRE']),
        OBSERVACION: _sN(j['OBSERVACION']),
        EJECUTOR_NOMBRE: _sN(j['EJECUTOR_NOMBRE']),
        otp_fecha_ejecucion_utc: _f(j['otp_fecha_ejecucion_utc']),
      );
}

class OrdenTrabajoAsignado {
  const OrdenTrabajoAsignado({
    required this.ota_id,
    this.USUARIO_NOMBRE,
    this.ota_es_responsable = false,
    this.ROL_NOMBRE,
  });

  final int ota_id;
  final String? USUARIO_NOMBRE;
  final bool ota_es_responsable;
  final String? ROL_NOMBRE;

  factory OrdenTrabajoAsignado.fromJson(Map<String, dynamic> j) =>
      OrdenTrabajoAsignado(
        ota_id: _i(j['ota_id']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
        ota_es_responsable: _b(j['ota_es_responsable']),
        ROL_NOMBRE: _sN(j['ROL_NOMBRE']),
      );
}

/// La ficha completa: cabecera, pasos y asignados en **una** respuesta.
///
/// Son tres consultas para el servidor y un solo viaje de red para el
/// telefono, que es lo que importa con senal de bodega.
class OrdenTrabajoFicha {
  const OrdenTrabajoFicha({
    required this.orden,
    this.pasos = const [],
    this.asignados = const [],
  });

  final OrdenTrabajo orden;
  final List<OrdenTrabajoPaso> pasos;
  final List<OrdenTrabajoAsignado> asignados;

  int get pendientes => pasos.where((p) => p.pendiente).length;

  /// Los obligatorios que faltan. Es lo que impide finalizar.
  int get obligatoriosPendientes =>
      pasos.where((p) => p.pendiente && p.otp_obligatorio).length;

  factory OrdenTrabajoFicha.fromJson(Map<String, dynamic> j) =>
      OrdenTrabajoFicha(
        orden: OrdenTrabajo.fromJson(
            (j['orden'] as Map).cast<String, dynamic>()),
        pasos: ((j['pasos'] as List?) ?? const [])
            .map((e) => OrdenTrabajoPaso.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
        asignados: ((j['asignados'] as List?) ?? const [])
            .map((e) => OrdenTrabajoAsignado.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );
}


/// Un tramo de mano de obra en la orden. `GET /ordenes-trabajo/{id}/recursos`
///
/// **Es append-only**: la tabla no tiene baja lógica y la API no expone
/// edición. Un tramo de trabajo es un hecho —alguien estuvo dos horas frente a
/// la máquina—, y los hechos no se editan: se corrigen agregando otro tramo.
class ManoObra {
  const ManoObra({
    required this.omo_id,
    required this.omo_minuto,
    required this.omo_fecha_inicio_utc,
    this.USUARIO_NOMBRE,
    this.ESPECIALIDAD_NOMBRE,
    this.PROVEEDOR_NOMBRE,
    this.omo_fecha_fin_utc,
    this.omo_es_hora_extra = false,
    this.omo_observacion,
    this.ORIGEN,
  });

  final int omo_id;
  final int omo_minuto;
  final DateTime omo_fecha_inicio_utc;
  final String? USUARIO_NOMBRE;
  final String? ESPECIALIDAD_NOMBRE;
  final String? PROVEEDOR_NOMBRE;
  final DateTime? omo_fecha_fin_utc;
  final bool omo_es_hora_extra;
  final String? omo_observacion;

  /// INTERNA o EXTERNA. Lo decide de dónde viene la persona, no un campo
  /// aparte que se puede desalinear.
  final String? ORIGEN;

  bool get externa => (ORIGEN ?? '').toUpperCase() == 'EXTERNA';

  /// «1 h 50». En terreno nadie piensa en 110 minutos.
  String get duracion {
    final h = omo_minuto ~/ 60;
    final m = omo_minuto % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m';
  }

  factory ManoObra.fromJson(Map<String, dynamic> j) => ManoObra(
        omo_id: _i(j['omo_id']),
        omo_minuto: _i(j['omo_minuto']),
        omo_fecha_inicio_utc:
            _f(j['omo_fecha_inicio_utc']) ?? DateTime.now().toUtc(),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
        ESPECIALIDAD_NOMBRE: _sN(j['ESPECIALIDAD_NOMBRE']),
        PROVEEDOR_NOMBRE: _sN(j['PROVEEDOR_NOMBRE']),
        omo_fecha_fin_utc: _f(j['omo_fecha_fin_utc']),
        omo_es_hora_extra: _b(j['omo_es_hora_extra']),
        omo_observacion: _sN(j['omo_observacion']),
        ORIGEN: _sN(j['ORIGEN']),
      );
}

/// Un repuesto consumido en la orden.
class OrdenTrabajoRepuesto {
  const OrdenTrabajoRepuesto({
    required this.ore_id,
    required this.REPUESTO_ID,
    required this.REPUESTO_CODIGO,
    required this.REPUESTO_NOMBRE,
    this.UNIDAD_SIMBOLO,
    this.LOTE_CODIGO,
    this.ore_cantidad_planificada,
    this.ore_cantidad_consumida,
    this.ore_cantidad_devuelta,
    this.ore_costo_unitario,
    this.ore_observacion,
  });

  final int ore_id;
  final int REPUESTO_ID;
  final String REPUESTO_CODIGO;
  final String REPUESTO_NOMBRE;
  final String? UNIDAD_SIMBOLO;
  final String? LOTE_CODIGO;
  final double? ore_cantidad_planificada;
  final double? ore_cantidad_consumida;
  final double? ore_cantidad_devuelta;
  final double? ore_costo_unitario;
  final String? ore_observacion;

  /// Lo que de verdad se gastó: lo sacado menos lo que volvió al estante.
  double get neto =>
      (ore_cantidad_consumida ?? 0) - (ore_cantidad_devuelta ?? 0);

  factory OrdenTrabajoRepuesto.fromJson(Map<String, dynamic> j) =>
      OrdenTrabajoRepuesto(
        ore_id: _i(j['ore_id']),
        REPUESTO_ID: _i(j['REPUESTO_ID']),
        REPUESTO_CODIGO: _s(j['REPUESTO_CODIGO']),
        REPUESTO_NOMBRE: _s(j['REPUESTO_NOMBRE']),
        UNIDAD_SIMBOLO: _sN(j['UNIDAD_SIMBOLO']),
        LOTE_CODIGO: _sN(j['LOTE_CODIGO']),
        ore_cantidad_planificada: j['ore_cantidad_planificada'] == null
            ? null
            : _d(j['ore_cantidad_planificada']),
        ore_cantidad_consumida: j['ore_cantidad_consumida'] == null
            ? null
            : _d(j['ore_cantidad_consumida']),
        ore_cantidad_devuelta: j['ore_cantidad_devuelta'] == null
            ? null
            : _d(j['ore_cantidad_devuelta']),
        ore_costo_unitario: j['ore_costo_unitario'] == null
            ? null
            : _d(j['ore_costo_unitario']),
        ore_observacion: _sN(j['ore_observacion']),
      );
}

/// Mano de obra y repuestos juntos: en la ficha se miran juntos —cuánto se
/// trabajó y qué se usó— y separarlos serían dos viajes de red para pintar una
/// sola pestaña.
class RecursosOrden {
  const RecursosOrden({this.manoObra = const [], this.repuestos = const []});

  final List<ManoObra> manoObra;
  final List<OrdenTrabajoRepuesto> repuestos;

  int get minutosTotales =>
      manoObra.fold<int>(0, (a, m) => a + m.omo_minuto);

  factory RecursosOrden.fromJson(Map<String, dynamic> j) => RecursosOrden(
        manoObra: ((j['mano_obra'] as List?) ?? const [])
            .map((e) => ManoObra.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        repuestos: ((j['repuestos'] as List?) ?? const [])
            .map((e) => OrdenTrabajoRepuesto.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );
}


// ═════════════════════════════════════════════════════════ CHECKLIST ══

/// Una pauta pendiente. `GET /checklist/pendientes`
class ChecklistPendiente {
  const ChecklistPendiente({
    required this.coc_id,
    required this.VERSION_ID,
    required this.PLANTILLA_NOMBRE,
    this.PLANTILLA_CODIGO,
    this.PLANTILLA_DESCRIPCION,
    this.VERSION_NUMERO = 1,
    this.ACTIVO_ID,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.AREA_NOMBRE,
    this.ESTADO_NOMBRE,
    this.coc_fecha_limite_utc,
    this.SITUACION,
    this.ITEM_TOTAL = 0,
    this.EJECUCION_BORRADOR,
  });

  final int coc_id;
  final int VERSION_ID;
  final String PLANTILLA_NOMBRE;
  final String? PLANTILLA_CODIGO;
  final String? PLANTILLA_DESCRIPCION;
  final int VERSION_NUMERO;
  final int? ACTIVO_ID;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;
  final String? AREA_NOMBRE;
  final String? ESTADO_NOMBRE;
  final DateTime? coc_fecha_limite_utc;

  /// VENCIDA · VENCE HOY · EN PLAZO · SIN PLAZO. Lo decide el SP.
  final String? SITUACION;

  final int ITEM_TOTAL;

  /// Si ya hay un borrador propio, la app **lo retoma** en vez de empezar
  /// otro: una pauta a medias que se rehace pierde lo caminado, y en terreno
  /// eso significa volver a recorrer la planta.
  final int? EJECUCION_BORRADOR;

  bool get vencida => (SITUACION ?? '').toUpperCase() == 'VENCIDA';
  bool get empezada => EJECUCION_BORRADOR != null;

  String get donde => [ACTIVO_CODIGO, ACTIVO_NOMBRE, AREA_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  factory ChecklistPendiente.fromJson(Map<String, dynamic> j) =>
      ChecklistPendiente(
        coc_id: _i(j['coc_id']),
        VERSION_ID: _i(j['VERSION_ID']),
        PLANTILLA_NOMBRE: _s(j['PLANTILLA_NOMBRE']),
        PLANTILLA_CODIGO: _sN(j['PLANTILLA_CODIGO']),
        PLANTILLA_DESCRIPCION: _sN(j['PLANTILLA_DESCRIPCION']),
        VERSION_NUMERO: _i(j['VERSION_NUMERO'], 1),
        ACTIVO_ID: j['ACTIVO_ID'] == null ? null : _i(j['ACTIVO_ID']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        coc_fecha_limite_utc: _f(j['coc_fecha_limite_utc']),
        SITUACION: _sN(j['SITUACION']),
        ITEM_TOTAL: _i(j['ITEM_TOTAL']),
        EJECUCION_BORRADOR: j['EJECUCION_BORRADOR'] == null
            ? null
            : _i(j['EJECUCION_BORRADOR']),
      );
}

/// Un ítem de la pauta.
class ChecklistItem {
  const ChecklistItem({
    required this.cpi_id,
    required this.cpi_texto,
    required this.TIPO_ID,
    this.cpi_codigo,
    this.cpi_ayuda,
    this.cpi_orden = 0,
    this.cpi_obligatorio = false,
    this.cpi_permite_comentario = true,
    this.cpi_requiere_evidencia = false,
    this.cpi_pregunta_voz,
    this.TIPO_CODIGO,
    this.UNIDAD_SIMBOLO,
    this.SECCION_ID,
    this.SECCION_NOMBRE,
    this.civ_valor_minimo,
    this.civ_valor_maximo,
    this.civ_mensaje,
    this.civ_requiere_comentario_fuera_rango = false,
  });

  final int cpi_id;
  final String cpi_texto;

  /// Del catálogo `Checklist_Item_Tipo`. 5 = SÍ/NO, 4 = decimal,
  /// 9 = selección, 2 = texto largo, 12 = fotografía.
  final int TIPO_ID;

  final String? cpi_codigo;
  final String? cpi_ayuda;
  final int cpi_orden;
  final bool cpi_obligatorio;
  final bool cpi_permite_comentario;
  final bool cpi_requiere_evidencia;

  /// Cómo se lee la pregunta en voz alta (§2 del kit).
  final String? cpi_pregunta_voz;

  final String? TIPO_CODIGO;
  final String? UNIDAD_SIMBOLO;
  final int? SECCION_ID;
  final String? SECCION_NOMBRE;

  /// El rango viaja con el ítem para que la app **avise en el momento**,
  /// aunque el veredicto que queda grabado lo ponga el servidor.
  final double? civ_valor_minimo;
  final double? civ_valor_maximo;
  final String? civ_mensaje;
  final bool civ_requiere_comentario_fuera_rango;

  bool get esSiNo => TIPO_ID == 5;
  bool get esNumero => TIPO_ID == 3 || TIPO_ID == 4 || TIPO_ID == 11;
  bool get esSeleccion => TIPO_ID == 9 || TIPO_ID == 10;
  bool get esTexto => TIPO_ID == 1 || TIPO_ID == 2;
  bool get hayRango => civ_valor_minimo != null || civ_valor_maximo != null;

  /// Si el valor cae fuera del rango declarado. **Solo para avisar**: el
  /// veredicto que se guarda lo decide el servidor.
  bool fueraDeRango(double? v) {
    if (v == null) return false;
    if (civ_valor_minimo != null && v < civ_valor_minimo!) return true;
    if (civ_valor_maximo != null && v > civ_valor_maximo!) return true;
    return false;
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        cpi_id: _i(j['cpi_id']),
        cpi_texto: _s(j['cpi_texto']),
        TIPO_ID: _i(j['TIPO_ID'], 1),
        cpi_codigo: _sN(j['cpi_codigo']),
        cpi_ayuda: _sN(j['cpi_ayuda']),
        cpi_orden: _i(j['cpi_orden']),
        cpi_obligatorio: _b(j['cpi_obligatorio']),
        cpi_permite_comentario: _b(j['cpi_permite_comentario'], true),
        cpi_requiere_evidencia: _b(j['cpi_requiere_evidencia']),
        cpi_pregunta_voz: _sN(j['cpi_pregunta_voz']),
        TIPO_CODIGO: _sN(j['TIPO_CODIGO']),
        UNIDAD_SIMBOLO: _sN(j['UNIDAD_SIMBOLO']),
        SECCION_ID: j['SECCION_ID'] == null ? null : _i(j['SECCION_ID']),
        SECCION_NOMBRE: _sN(j['SECCION_NOMBRE']),
        civ_valor_minimo:
            j['civ_valor_minimo'] == null ? null : _d(j['civ_valor_minimo']),
        civ_valor_maximo:
            j['civ_valor_maximo'] == null ? null : _d(j['civ_valor_maximo']),
        civ_mensaje: _sN(j['civ_mensaje']),
        civ_requiere_comentario_fuera_rango:
            _b(j['civ_requiere_comentario_fuera_rango']),
      );
}

/// Una opción de un ítem.
///
/// **Acá vive el significado de un SÍ/NO**: a «¿Hay fugas visibles?» la
/// respuesta conforme es NO; a «¿Opera sin ruidos?» es SÍ. Misma estructura,
/// criterio opuesto — lo sabe quien redactó la pregunta, no el código.
class ChecklistOpcion {
  const ChecklistOpcion({
    required this.cio_id,
    required this.ITEM_ID,
    required this.cio_codigo,
    required this.cio_texto,
    this.cio_orden = 0,
    this.cio_es_conforme = true,
    this.cio_requiere_comentario = false,
  });

  final int cio_id;
  final int ITEM_ID;
  final String cio_codigo;
  final String cio_texto;
  final int cio_orden;
  final bool cio_es_conforme;
  final bool cio_requiere_comentario;

  factory ChecklistOpcion.fromJson(Map<String, dynamic> j) => ChecklistOpcion(
        cio_id: _i(j['cio_id']),
        ITEM_ID: _i(j['ITEM_ID']),
        cio_codigo: _s(j['cio_codigo']),
        cio_texto: _s(j['cio_texto']),
        cio_orden: _i(j['cio_orden']),
        cio_es_conforme: _b(j['cio_es_conforme'], true),
        cio_requiere_comentario: _b(j['cio_requiere_comentario']),
      );
}

/// La pauta completa: ítems y opciones en una respuesta.
///
/// Van juntos porque **la app no puede pintar un ítem de selección sin sus
/// opciones**, y pedirlas aparte serían dos viajes de red para dibujar una
/// sola pantalla.
class ChecklistPlantilla {
  const ChecklistPlantilla({this.items = const [], this.opciones = const []});

  final List<ChecklistItem> items;
  final List<ChecklistOpcion> opciones;

  List<ChecklistOpcion> opcionesDe(int itemId) =>
      opciones.where((o) => o.ITEM_ID == itemId).toList()
        ..sort((a, b) => a.cio_orden.compareTo(b.cio_orden));

  factory ChecklistPlantilla.fromJson(Map<String, dynamic> j) =>
      ChecklistPlantilla(
        items: ((j['items'] as List?) ?? const [])
            .map((e) =>
                ChecklistItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        opciones: ((j['opciones'] as List?) ?? const [])
            .map((e) =>
                ChecklistOpcion.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Una respuesta ya grabada.
class ChecklistRespuesta {
  const ChecklistRespuesta({
    required this.cer_id,
    required this.ITEM_ID,
    this.cer_valor_texto,
    this.cer_valor_numero,
    this.cer_valor_booleano,
    this.cer_fuera_rango = false,
    this.cer_no_aplica = false,
    this.cer_comentario,
    this.cer_entrada_modo,
  });

  final int cer_id;
  final int ITEM_ID;
  final String? cer_valor_texto;
  final double? cer_valor_numero;
  final bool? cer_valor_booleano;
  final bool cer_fuera_rango;
  final bool cer_no_aplica;
  final String? cer_comentario;

  /// 1 teclado, 2 voz. Una cifra dictada y una tecleada no se auditan igual.
  final int? cer_entrada_modo;

  bool get porVoz => cer_entrada_modo == 2;

  factory ChecklistRespuesta.fromJson(Map<String, dynamic> j) =>
      ChecklistRespuesta(
        cer_id: _i(j['cer_id']),
        ITEM_ID: _i(j['ITEM_ID']),
        cer_valor_texto: _sN(j['cer_valor_texto']),
        cer_valor_numero:
            j['cer_valor_numero'] == null ? null : _d(j['cer_valor_numero']),
        cer_valor_booleano: j['cer_valor_booleano'] == null
            ? null
            : _b(j['cer_valor_booleano']),
        cer_fuera_rango: _b(j['cer_fuera_rango']),
        cer_no_aplica: _b(j['cer_no_aplica']),
        cer_comentario: _sN(j['cer_comentario']),
        cer_entrada_modo:
            j['cer_entrada_modo'] == null ? null : _i(j['cer_entrada_modo']),
      );
}

/// Una ejecución de pauta con sus respuestas.
class ChecklistEjecucion {
  const ChecklistEjecucion({
    required this.cej_id,
    required this.VERSION_ID,
    this.PLANTILLA_NOMBRE,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.ESTADO_ID = 1,
    this.ESTADO_NOMBRE,
    this.cej_item_total = 0,
    this.cej_item_respondido = 0,
    this.cej_item_no_conforme = 0,
    this.cej_observacion,
    this.respuestas = const [],
  });

  final int cej_id;
  final int VERSION_ID;
  final String? PLANTILLA_NOMBRE;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;

  /// 1 BORRADOR, 3 ENVIADA. Solo el borrador se puede seguir llenando.
  final int ESTADO_ID;
  final String? ESTADO_NOMBRE;

  final int cej_item_total;
  final int cej_item_respondido;
  final int cej_item_no_conforme;
  final String? cej_observacion;
  final List<ChecklistRespuesta> respuestas;

  bool get esBorrador => ESTADO_ID == 1;

  double get avance => cej_item_total == 0
      ? 0
      : (cej_item_respondido / cej_item_total).clamp(0, 1);

  ChecklistRespuesta? respuestaDe(int itemId) {
    for (final r in respuestas) {
      if (r.ITEM_ID == itemId) return r;
    }
    return null;
  }

  factory ChecklistEjecucion.fromJson(Map<String, dynamic> j) =>
      ChecklistEjecucion(
        cej_id: _i(j['cej_id']),
        VERSION_ID: _i(j['VERSION_ID']),
        PLANTILLA_NOMBRE: _sN(j['PLANTILLA_NOMBRE']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        ESTADO_ID: _i(j['ESTADO_ID'], 1),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        cej_item_total: _i(j['cej_item_total']),
        cej_item_respondido: _i(j['cej_item_respondido']),
        cej_item_no_conforme: _i(j['cej_item_no_conforme']),
        cej_observacion: _sN(j['cej_observacion']),
        respuestas: ((j['respuestas'] as List?) ?? const [])
            .map((e) =>
                ChecklistRespuesta.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}






/// La cabecera de un activo. `GET /activos/{id}`
///
/// Existe aparte de `/ficha`, que devuelve los EVENTOS: sin esta, la pantalla
/// de ficha tenia que recibir el nombre y el tipo por parametro desde donde la
/// abrieran, y el mismo activo se veia distinto abierto desde el escaneo que
/// desde un listado.
class Activo {
  const Activo({
    required this.act_id,
    required this.act_codigo,
    required this.act_nombre,
    this.act_numero_serie,
    this.act_fabricante,
    this.act_modelo,
    this.act_activo_estado = 0,
    this.PLANTA_NOMBRE,
    this.AREA_NOMBRE,
    this.POSICION_CODIGO,
    this.TIPO_NOMBRE,
    this.ESTADO_NOMBRE,
    this.ESTADO_CODIGO,
    this.CRITICIDAD_NOMBRE,
    this.PADRE_CODIGO,
    this.FOTO_RUTA,
    this.FOTOS = const [],
  });

  final int act_id;
  final String act_codigo;
  final String act_nombre;
  final String? act_numero_serie;
  final String? act_fabricante;
  final String? act_modelo;
  final int act_activo_estado;

  /// Resueltos por el SP. Hacer que el telefono cruce cinco catalogos para
  /// pintar una pantalla es trabajo que el servidor ya hizo.
  final String? PLANTA_NOMBRE;
  final String? AREA_NOMBRE;
  final String? POSICION_CODIGO;
  final String? TIPO_NOMBRE;
  final String? ESTADO_NOMBRE;
  final String? ESTADO_CODIGO;
  final String? CRITICIDAD_NOMBRE;
  final String? PADRE_CODIGO;

  /// La ruta del blob de la portada, y la galeria.
  ///
  /// **Rutas, no bytes.** Las fotos se suben desde la web y viven en Azure
  /// Blob Storage; la app las pide por `GET /archivo/ver?ruta=` cuando va a
  /// dibujarlas. Un catalogo con las fotos dentro del APK seria un APK que
  /// hay que republicar cada vez que alguien cambia una foto.
  final String? FOTO_RUTA;
  final List<String> FOTOS;

  /// La marca y el modelo en una linea: «WEG W22 · 75 kW».
  String get marcaModelo =>
      [act_fabricante, act_modelo].where((s) => (s ?? '').isNotEmpty).join(' ');

  /// «Quilicura › Envasado › Linea 3», con lo que venga.
  String get ruta => [PLANTA_NOMBRE, AREA_NOMBRE, POSICION_CODIGO]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' \u203a ');

  factory Activo.fromJson(Map<String, dynamic> j) => Activo(
        act_id: _i(j['act_id']),
        act_codigo: _s(j['act_codigo']),
        act_nombre: _s(j['act_nombre']),
        act_numero_serie: _sN(j['act_numero_serie']),
        act_fabricante: _sN(j['act_fabricante']),
        act_modelo: _sN(j['act_modelo']),
        act_activo_estado: _i(j['act_activo_estado']),
        PLANTA_NOMBRE: _sN(j['PLANTA_NOMBRE']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        POSICION_CODIGO: _sN(j['POSICION_CODIGO']),
        TIPO_NOMBRE: _sN(j['TIPO_NOMBRE']),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        ESTADO_CODIGO: _sN(j['ESTADO_CODIGO']),
        CRITICIDAD_NOMBRE: _sN(j['CRITICIDAD_NOMBRE']),
        PADRE_CODIGO: _sN(j['PADRE_CODIGO']),
        FOTO_RUTA: _sN(j['FOTO_RUTA']),
        FOTOS: ((j['FOTOS'] as List?) ?? const [])
            .map((e) => e is Map ? _s(e['ruta']) : _s(e))
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

/// Un medidor del activo: horometro, contador de ciclos, odometro.
///
/// **No hay sensores.** El valor lo toma una persona con la app delante del
/// equipo; por eso importa `DIAS_SIN_LECTURA`, que es lo que dice si la ruta
/// de medicion se esta cumpliendo.
class ActivoMedidor {
  const ActivoMedidor({
    required this.ame_id,
    required this.ame_nombre,
    this.UNIDAD,
    this.ame_valor_actual = 0,
    this.DIAS_SIN_LECTURA,
    this.ame_permite_reinicio = false,
  });

  final int ame_id;
  final String ame_nombre;
  final String? UNIDAD;
  final double ame_valor_actual;
  final int? DIAS_SIN_LECTURA;

  /// Un horometro que se cambia por uno nuevo vuelve a cero, y eso no es un
  /// error de captura. El SP lo acepta solo si el medidor lo permite.
  final bool ame_permite_reinicio;

  factory ActivoMedidor.fromJson(Map<String, dynamic> j) => ActivoMedidor(
        ame_id: _i(j['ame_id']),
        ame_nombre: _s(j['ame_nombre']),
        UNIDAD: _sN(j['UNIDAD']),
        ame_valor_actual: _d(j['ame_valor_actual']),
        DIAS_SIN_LECTURA: j['DIAS_SIN_LECTURA'] == null
            ? null
            : _i(j['DIAS_SIN_LECTURA']),
        ame_permite_reinicio: _b(j['ame_permite_reinicio']),
      );
}

/// Un valor de catalogo. `GET /catalogo-valores?codigo=`
class CatalogoValor {
  const CatalogoValor({
    required this.ctv_id,
    required this.ctv_nombre,
    this.ctv_codigo,
    this.ctv_orden = 0,
  });

  final int ctv_id;
  final String ctv_nombre;
  final String? ctv_codigo;
  final int ctv_orden;

  factory CatalogoValor.fromJson(Map<String, dynamic> j) => CatalogoValor(
        ctv_id: _i(j['ctv_id']),
        ctv_nombre: _s(j['ctv_nombre']),
        ctv_codigo: _sN(j['ctv_codigo']),
        ctv_orden: _i(j['ctv_orden']),
      );
}

/// paginas, datos}`.
class Paginado<T> {
  const Paginado({
    required this.datos,
    this.pagina = 1,
    this.tamano = 50,
    this.total = 0,
    this.paginas = 0,
  });

  final List<T> datos;
  final int pagina;
  final int tamano;
  final int total;
  final int paginas;

  bool get vacio => datos.isEmpty;

  /// Acepta las dos formas: el objeto paginado y la lista pelada, porque hay
  /// endpoints —`/menus`, `/repuestos/{id}/lotes`— que devuelven un array.
  factory Paginado.desde(dynamic j, T Function(Map<String, dynamic>) mapa) {
    if (j is List) {
      final l = j.map((e) => mapa(e as Map<String, dynamic>)).toList();
      return Paginado(datos: l, total: l.length, paginas: l.isEmpty ? 0 : 1);
    }
    if (j is Map<String, dynamic>) {
      final l = ((j['datos'] as List?) ?? const [])
          .map((e) => mapa(e as Map<String, dynamic>))
          .toList();
      return Paginado(
        datos: l,
        pagina: _i(j['pagina'], 1),
        tamano: _i(j['tamano'], 50),
        total: _i(j['total'], l.length),
        paginas: _i(j['paginas']),
      );
    }
    return const Paginado(datos: []);
  }
}

/// Una entrada de la bitácora de planta (HU-130, HU-131).
///
/// ## Por qué hay dos textos
///
/// `bit_texto` es lo que se escribió la primera vez y **no cambia jamás**;
/// `TEXTO_VIGENTE` es lo que vale hoy —la última rectificación, o el original
/// si no hubo—. Una bitácora que se puede editar en su sitio deja de servir
/// como registro: lo que se corrige se apila encima, no borra lo anterior.
class BitacoraEntrada {
  const BitacoraEntrada({
    required this.bit_id,
    required this.bit_titulo,
    required this.TEXTO_VIGENTE,
    required this.bit_fecha_evento_utc,
    this.bit_turno,
    this.bit_requiere_atencion = false,
    this.TIPO_NOMBRE,
    this.SEVERIDAD_CODIGO,
    this.SEVERIDAD_NOMBRE,
    this.ACTIVO_ID,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.AREA_NOMBRE,
    this.USUARIO_NOMBRE,
    this.POR_VOZ = false,
    this.COMENTARIOS = 0,
    this.RECTIFICACIONES = 0,
    this.EVIDENCIAS = 0,
  });

  final int bit_id;
  final String bit_titulo;
  final String TEXTO_VIGENTE;

  /// La fecha del **evento**, no la de creación: una entrada escrita sin señal
  /// a las tres de la mañana y subida a las nueve pertenece a la noche.
  final DateTime bit_fecha_evento_utc;

  final String? bit_turno;
  final bool bit_requiere_atencion;
  final String? TIPO_NOMBRE;
  final String? SEVERIDAD_CODIGO;
  final String? SEVERIDAD_NOMBRE;
  final int? ACTIVO_ID;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;
  final String? AREA_NOMBRE;
  final String? USUARIO_NOMBRE;
  final bool POR_VOZ;
  final int COMENTARIOS;

  /// Cuántas veces se corrigió. La pantalla lo usa para marcarla
  /// «rectificada» sin pedir la lista completa.
  final int RECTIFICACIONES;

  final int EVIDENCIAS;

  bool get rectificada => RECTIFICACIONES > 0;

  String get activo => [ACTIVO_CODIGO, ACTIVO_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  factory BitacoraEntrada.fromJson(Map<String, dynamic> j) => BitacoraEntrada(
        bit_id: _i(j['bit_id']),
        bit_titulo: _s(j['bit_titulo']),
        TEXTO_VIGENTE: _s(j['TEXTO_VIGENTE']).isEmpty
            ? _s(j['bit_texto'])
            : _s(j['TEXTO_VIGENTE']),
        bit_fecha_evento_utc:
            _f(j['bit_fecha_evento_utc']) ?? DateTime.now().toUtc(),
        bit_turno: _sN(j['bit_turno']),
        bit_requiere_atencion: _b(j['bit_requiere_atencion']),
        TIPO_NOMBRE: _sN(j['TIPO_NOMBRE']),
        SEVERIDAD_CODIGO: _sN(j['SEVERIDAD_CODIGO']),
        SEVERIDAD_NOMBRE: _sN(j['SEVERIDAD_NOMBRE']),
        ACTIVO_ID: (j['ACTIVO_ID'] as num?)?.toInt(),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
        POR_VOZ: _b(j['POR_VOZ']),
        COMENTARIOS: _i(j['COMENTARIOS']),
        RECTIFICACIONES: _i(j['RECTIFICACIONES']),
        EVIDENCIAS: _i(j['EVIDENCIAS']),
      );
}

/// Alguien de la misma instalación con quien se puede compartir un trabajo.
///
/// La lista sale de `Cliente_Instalacion_Usuario`, la misma regla que las
/// plantas y el contexto: compartir con quien no trabaja en esa planta es
/// mandarle un aviso sobre un equipo que no puede tocar.
class Companero {
  const Companero({
    required this.usu_id,
    required this.NOMBRE,
    this.LOGIN,
    this.PERFIL_NOMBRE,
  });

  final int usu_id;
  final String NOMBRE;
  final String? LOGIN;
  final String? PERFIL_NOMBRE;

  /// Las iniciales, para el avatar cuando no hay foto.
  String get iniciales {
    final p = NOMBRE.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) {
      return p.first.substring(0, p.first.length < 2 ? 1 : 2).toUpperCase();
    }
    return (p.first[0] + p[1][0]).toUpperCase();
  }

  factory Companero.fromJson(Map<String, dynamic> j) => Companero(
        usu_id: _i(j['usu_id']),
        NOMBRE: _s(j['NOMBRE']),
        LOGIN: _sN(j['LOGIN']),
        PERFIL_NOMBRE: _sN(j['PERFIL_NOMBRE']),
      );
}

/// Una foto ya guardada.
///
/// Trae la **ruta** del blob y no los bytes: la pantalla la pide después por
/// `/archivo/ver` y `ImagenService` la cachea en disco. Mandar las imágenes
/// dentro de la ficha haría que abrir una tarea con seis fotos costara seis
/// megas en terreno.
class Evidencia {
  const Evidencia({
    required this.arc_id,
    required this.arc_ruta,
    this.arc_nombre_original,
    this.arc_mime,
    this.arc_byte = 0,
    this.arc_ancho_pixel,
    this.arc_alto_pixel,
    this.arc_fecha_captura_utc,
    this.CATEGORIA_CODIGO,
    this.CATEGORIA_NOMBRE,
    this.avi_titulo,
    this.USUARIO_NOMBRE,
    required this.arc_fecha_creacion,
  });

  final int arc_id;
  final String arc_ruta;
  final String? arc_nombre_original;
  final String? arc_mime;
  final int arc_byte;
  final int? arc_ancho_pixel;
  final int? arc_alto_pixel;
  final DateTime? arc_fecha_captura_utc;
  final String? CATEGORIA_CODIGO;
  final String? CATEGORIA_NOMBRE;
  final String? avi_titulo;
  final String? USUARIO_NOMBRE;
  final DateTime arc_fecha_creacion;

  /// Cuándo se sacó, no cuándo llegó. Con captura sin señal pueden separarlas
  /// horas, y lo que importa para el historial del activo es la primera.
  DateTime get cuando =>
      (arc_fecha_captura_utc ?? arc_fecha_creacion).toLocal();

  factory Evidencia.fromJson(Map<String, dynamic> j) => Evidencia(
        arc_id: _i(j['arc_id']),
        arc_ruta: _s(j['arc_ruta']),
        arc_nombre_original: _sN(j['arc_nombre_original']),
        arc_mime: _sN(j['arc_mime']),
        arc_byte: _i(j['arc_byte']),
        arc_ancho_pixel:
            j['arc_ancho_pixel'] == null ? null : _i(j['arc_ancho_pixel']),
        arc_alto_pixel:
            j['arc_alto_pixel'] == null ? null : _i(j['arc_alto_pixel']),
        arc_fecha_captura_utc: _f(j['arc_fecha_captura_utc']),
        CATEGORIA_CODIGO: _sN(j['CATEGORIA_CODIGO']),
        CATEGORIA_NOMBRE: _sN(j['CATEGORIA_NOMBRE']),
        avi_titulo: _sN(j['avi_titulo']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
        arc_fecha_creacion: _f(j['arc_fecha_creacion']) ?? DateTime.now(),
      );
}

// ===========================================================================
//  SIGMA AI                                               HU-173 y HU-175
// ===========================================================================

/// Una predicción vigente.
///
/// ## Qué significa cada número, y qué no
///
/// `pre_probabilidad` **no es «probabilidad de falla»**. El modelo no ha visto
/// ninguna falla y no puede afirmar nada sobre fallas. Es la parte del
/// intervalo de cruce que cae dentro del horizonte: qué tan seguro está de que
/// la variable llegue al límite dentro de la ventana que mira.
///
/// Lo que sí es un número directo y verificable es `pre_dia_restante`: los días
/// que faltan para que la recta ajustada alcance el valor crítico declarado del
/// equipo. Por eso la pantalla muestra los días como titular y no el
/// porcentaje —y siempre con el condicional, porque es lo que pasa **si la
/// tendencia se mantiene**—.
class Prediccion {
  const Prediccion({
    required this.pre_id,
    required this.ACTIVO_ID,
    required this.ACTIVO_NOMBRE,
    this.ACTIVO_CODIGO,
    this.AREA_NOMBRE,
    this.INSTALACION_NOMBRE,
    this.ACTIVO_FOTO,
    this.VARIABLE_NOMBRE,
    this.UNIDAD,
    this.VALOR_ACTUAL,
    this.VALOR_CRITICO,
    this.VALOR_ADVERTENCIA,
    this.pre_dia_restante,
    this.pre_fecha_evento_estimada_utc,
    this.pre_probabilidad,
    this.pre_confianza,
    this.DIA_MINIMO,
    this.DIA_MAXIMO,
    this.SEVERIDAD_CODIGO,
    this.SEVERIDAD_NOMBRE,
    this.ESTADO_ID = 1,
    this.ESTADO_NOMBRE,
    required this.pre_fecha_calculo_utc,
    this.MODELO_NOMBRE,
    this.MODELO_VERSION,
    this.ALERTA_ID,
    this.ORDEN_TRABAJO_ID,
    this.ORDEN_CORRELATIVO,
  });

  final int pre_id;
  final int ACTIVO_ID;
  final String ACTIVO_NOMBRE;
  final String? ACTIVO_CODIGO;
  final String? AREA_NOMBRE;
  final String? INSTALACION_NOMBRE;
  final String? ACTIVO_FOTO;
  final String? VARIABLE_NOMBRE;
  final String? UNIDAD;
  final double? VALOR_ACTUAL;
  final double? VALOR_CRITICO;
  final double? VALOR_ADVERTENCIA;
  final int? pre_dia_restante;
  final DateTime? pre_fecha_evento_estimada_utc;
  final double? pre_probabilidad;

  /// El R² del ajuste: qué tan bien la recta describe las lecturas.
  final double? pre_confianza;

  final double? DIA_MINIMO;
  final double? DIA_MAXIMO;
  final String? SEVERIDAD_CODIGO;
  final String? SEVERIDAD_NOMBRE;
  final int ESTADO_ID;
  final String? ESTADO_NOMBRE;
  final DateTime pre_fecha_calculo_utc;
  final String? MODELO_NOMBRE;
  final int? MODELO_VERSION;

  /// Sin alerta no se puede abrir una OT predictiva: la predicción no llegó al
  /// umbral en que el modelo pide que se le crea.
  final int? ALERTA_ID;

  final int? ORDEN_TRABAJO_ID;
  final int? ORDEN_CORRELATIVO;

  bool get critica => (SEVERIDAD_CODIGO ?? '') == 'CRITICA';
  bool get alta => (SEVERIDAD_CODIGO ?? '') == 'ALTA';
  bool get revisada => ESTADO_ID >= 3;
  bool get descartada => ESTADO_ID == 4;
  bool get tieneOrden => ORDEN_TRABAJO_ID != null;

  String get donde => [ACTIVO_CODIGO, AREA_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  /// El margen del intervalo, en días. Se muestra como «±4 d» porque un plazo
  /// sin margen se lee como una fecha comprometida, y esto es una estimación.
  int? get margenDias {
    if (DIA_MINIMO == null || DIA_MAXIMO == null) return null;
    return ((DIA_MAXIMO! - DIA_MINIMO!) / 2).round();
  }

  factory Prediccion.fromJson(Map<String, dynamic> j) => Prediccion(
        pre_id: _i(j['pre_id']),
        ACTIVO_ID: _i(j['ACTIVO_ID']),
        ACTIVO_NOMBRE: _s(j['ACTIVO_NOMBRE']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        INSTALACION_NOMBRE: _sN(j['INSTALACION_NOMBRE']),
        ACTIVO_FOTO: _sN(j['ACTIVO_FOTO']),
        VARIABLE_NOMBRE: _sN(j['VARIABLE_NOMBRE']),
        UNIDAD: _sN(j['UNIDAD']),
        VALOR_ACTUAL: _dN(j['VALOR_ACTUAL']),
        VALOR_CRITICO: _dN(j['VALOR_CRITICO']),
        VALOR_ADVERTENCIA: _dN(j['VALOR_ADVERTENCIA']),
        pre_dia_restante:
            j['pre_dia_restante'] == null ? null : _i(j['pre_dia_restante']),
        pre_fecha_evento_estimada_utc: _f(j['pre_fecha_evento_estimada_utc']),
        pre_probabilidad: _dN(j['pre_probabilidad']),
        pre_confianza: _dN(j['pre_confianza']),
        DIA_MINIMO: _dN(j['DIA_MINIMO']),
        DIA_MAXIMO: _dN(j['DIA_MAXIMO']),
        SEVERIDAD_CODIGO: _sN(j['SEVERIDAD_CODIGO']),
        SEVERIDAD_NOMBRE: _sN(j['SEVERIDAD_NOMBRE']),
        ESTADO_ID: _i(j['ESTADO_ID'], 1),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        pre_fecha_calculo_utc: _f(j['pre_fecha_calculo_utc']) ?? DateTime.now(),
        MODELO_NOMBRE: _sN(j['MODELO_NOMBRE']),
        MODELO_VERSION:
            j['MODELO_VERSION'] == null ? null : _i(j['MODELO_VERSION']),
        ALERTA_ID: j['ALERTA_ID'] == null ? null : _i(j['ALERTA_ID']),
        ORDEN_TRABAJO_ID:
            j['ORDEN_TRABAJO_ID'] == null ? null : _i(j['ORDEN_TRABAJO_ID']),
        ORDEN_CORRELATIVO:
            j['ORDEN_CORRELATIVO'] == null ? null : _i(j['ORDEN_CORRELATIVO']),
      );
}

/// Una de las tres razones. Cada una nombra el número del que sale: una razón
/// que no se puede verificar no ayuda a decidir si desarmar una máquina.
class PrediccionRazon {
  const PrediccionRazon({
    required this.pex_orden,
    required this.pex_texto,
    this.pex_direccion,
    this.pex_valor_observado,
    this.pex_valor_referencia,
    this.CARACTERISTICA,
  });

  final int pex_orden;
  final String pex_texto;
  final String? pex_direccion;
  final double? pex_valor_observado;
  final double? pex_valor_referencia;
  final String? CARACTERISTICA;

  bool get sube => (pex_direccion ?? '') == 'AUMENTA';

  factory PrediccionRazon.fromJson(Map<String, dynamic> j) => PrediccionRazon(
        pex_orden: _i(j['pex_orden']),
        pex_texto: _s(j['pex_texto']),
        pex_direccion: _sN(j['pex_direccion']),
        pex_valor_observado: _dN(j['pex_valor_observado']),
        pex_valor_referencia: _dN(j['pex_valor_referencia']),
        CARACTERISTICA: _sN(j['CARACTERISTICA']),
      );
}

/// Un dato que entró en el cálculo.
class PrediccionDato {
  const PrediccionDato({
    required this.cmo_codigo,
    required this.cmo_etiqueta,
    this.cmo_descripcion,
    this.pcr_valor,
    this.pcr_valor_texto,
    this.pcr_imputado = false,
  });

  final String cmo_codigo;
  final String cmo_etiqueta;
  final String? cmo_descripcion;
  final double? pcr_valor;
  final String? pcr_valor_texto;

  /// No se midió: se rellenó. Se marca distinto porque una predicción sobre
  /// datos imputados vale menos, y quien la lee tiene que saberlo.
  final bool pcr_imputado;

  factory PrediccionDato.fromJson(Map<String, dynamic> j) => PrediccionDato(
        cmo_codigo: _s(j['cmo_codigo']),
        cmo_etiqueta: _s(j['cmo_etiqueta']),
        cmo_descripcion: _sN(j['cmo_descripcion']),
        pcr_valor: _dN(j['pcr_valor']),
        pcr_valor_texto: _sN(j['pcr_valor_texto']),
        pcr_imputado: j['pcr_imputado'] == true,
      );
}

/// Un punto de la serie medida.
class PrediccionPunto {
  const PrediccionPunto({required this.FECHA, required this.VALOR});

  final DateTime FECHA;
  final double VALOR;

  factory PrediccionPunto.fromJson(Map<String, dynamic> j) => PrediccionPunto(
        FECHA: _f(j['FECHA']) ?? DateTime.now(),
        VALOR: _dN(j['VALOR']) ?? 0,
      );
}

/// La ficha completa — la vista 14.2.
class PrediccionFicha extends Prediccion {
  const PrediccionFicha({
    required super.pre_id,
    required super.ACTIVO_ID,
    required super.ACTIVO_NOMBRE,
    super.ACTIVO_CODIGO,
    super.AREA_NOMBRE,
    super.INSTALACION_NOMBRE,
    super.ACTIVO_FOTO,
    super.VARIABLE_NOMBRE,
    super.UNIDAD,
    super.VALOR_ACTUAL,
    super.VALOR_CRITICO,
    super.VALOR_ADVERTENCIA,
    super.pre_dia_restante,
    super.pre_fecha_evento_estimada_utc,
    super.pre_probabilidad,
    super.pre_confianza,
    super.DIA_MINIMO,
    super.DIA_MAXIMO,
    super.SEVERIDAD_CODIGO,
    super.SEVERIDAD_NOMBRE,
    super.ESTADO_ID,
    super.ESTADO_NOMBRE,
    required super.pre_fecha_calculo_utc,
    super.MODELO_NOMBRE,
    super.MODELO_VERSION,
    super.ALERTA_ID,
    super.ORDEN_TRABAJO_ID,
    super.ORDEN_CORRELATIVO,
    this.MODELO_DESCRIPCION,
    this.MODELO_ALGORITMO,
    this.MODELO_FORMATO,
    this.MODELO_OBJETIVO,
    this.MODELO_HORIZONTE,
    this.pre_fecha_vigencia_hasta_utc,
    this.pre_motivo_descarte,
    this.REVISADA_POR,
    this.pre_fecha_revision_utc,
    this.EVIDENCIAS = 0,
    this.razones = const [],
    this.datos = const [],
    this.serie = const [],
  });

  final String? MODELO_DESCRIPCION;
  final String? MODELO_ALGORITMO;
  final String? MODELO_FORMATO;
  final String? MODELO_OBJETIVO;
  final int? MODELO_HORIZONTE;
  final DateTime? pre_fecha_vigencia_hasta_utc;
  final String? pre_motivo_descarte;
  final String? REVISADA_POR;
  final DateTime? pre_fecha_revision_utc;
  final int EVIDENCIAS;

  final List<PrediccionRazon> razones;
  final List<PrediccionDato> datos;
  final List<PrediccionPunto> serie;

  /// Una serie de un punto no cuenta ninguna historia: la pantalla no dibuja
  /// la curva y muestra solo el número.
  bool get hayCurva => serie.length > 1;

  factory PrediccionFicha.fromJson(Map<String, dynamic> j) => PrediccionFicha(
        pre_id: _i(j['pre_id']),
        ACTIVO_ID: _i(j['ACTIVO_ID']),
        ACTIVO_NOMBRE: _s(j['ACTIVO_NOMBRE']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        INSTALACION_NOMBRE: _sN(j['INSTALACION_NOMBRE']),
        ACTIVO_FOTO: _sN(j['ACTIVO_FOTO']),
        VARIABLE_NOMBRE: _sN(j['VARIABLE_NOMBRE']),
        UNIDAD: _sN(j['UNIDAD']),
        VALOR_ACTUAL: _dN(j['VALOR_ACTUAL']),
        VALOR_CRITICO: _dN(j['VALOR_CRITICO']),
        VALOR_ADVERTENCIA: _dN(j['VALOR_ADVERTENCIA']),
        pre_dia_restante:
            j['pre_dia_restante'] == null ? null : _i(j['pre_dia_restante']),
        pre_fecha_evento_estimada_utc: _f(j['pre_fecha_evento_estimada_utc']),
        pre_probabilidad: _dN(j['pre_probabilidad']),
        pre_confianza: _dN(j['pre_confianza']),
        DIA_MINIMO: _dN(j['DIA_MINIMO']),
        DIA_MAXIMO: _dN(j['DIA_MAXIMO']),
        SEVERIDAD_CODIGO: _sN(j['SEVERIDAD_CODIGO']),
        SEVERIDAD_NOMBRE: _sN(j['SEVERIDAD_NOMBRE']),
        ESTADO_ID: _i(j['ESTADO_ID'], 1),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        pre_fecha_calculo_utc: _f(j['pre_fecha_calculo_utc']) ?? DateTime.now(),
        MODELO_NOMBRE: _sN(j['MODELO_NOMBRE']),
        MODELO_VERSION:
            j['MODELO_VERSION'] == null ? null : _i(j['MODELO_VERSION']),
        ALERTA_ID: j['ALERTA_ID'] == null ? null : _i(j['ALERTA_ID']),
        ORDEN_TRABAJO_ID:
            j['ORDEN_TRABAJO_ID'] == null ? null : _i(j['ORDEN_TRABAJO_ID']),
        ORDEN_CORRELATIVO:
            j['ORDEN_CORRELATIVO'] == null ? null : _i(j['ORDEN_CORRELATIVO']),
        MODELO_DESCRIPCION: _sN(j['MODELO_DESCRIPCION']),
        MODELO_ALGORITMO: _sN(j['MODELO_ALGORITMO']),
        MODELO_FORMATO: _sN(j['MODELO_FORMATO']),
        MODELO_OBJETIVO: _sN(j['MODELO_OBJETIVO']),
        MODELO_HORIZONTE:
            j['MODELO_HORIZONTE'] == null ? null : _i(j['MODELO_HORIZONTE']),
        pre_fecha_vigencia_hasta_utc: _f(j['pre_fecha_vigencia_hasta_utc']),
        pre_motivo_descarte: _sN(j['pre_motivo_descarte']),
        REVISADA_POR: _sN(j['REVISADA_POR']),
        pre_fecha_revision_utc: _f(j['pre_fecha_revision_utc']),
        EVIDENCIAS: _i(j['EVIDENCIAS']),
        razones: _lista(j['razones'], PrediccionRazon.fromJson),
        datos: _lista(j['datos'], PrediccionDato.fromJson),
        serie: _lista(j['serie'], PrediccionPunto.fromJson),
      );
}

/// Un equipo vigilado que no produjo predicción, y por qué.
///
/// El vacío es información: un panel sin nada no distingue «nadie mide este
/// equipo» de «se mide y está tranquilo», y son cosas muy distintas para quien
/// tiene que decidir dónde mirar.
class Vigilado {
  const Vigilado({
    required this.ava_id,
    required this.ACTIVO_ID,
    required this.ACTIVO_NOMBRE,
    this.ACTIVO_CODIGO,
    this.AREA_NOMBRE,
    this.VARIABLE_NOMBRE,
    this.UNIDAD,
    this.VALOR_ADVERTENCIA,
    this.VALOR_CRITICO,
    this.CADA_HORAS,
    this.LECTURAS = 0,
    this.ULTIMA_UTC,
    this.ULTIMO_VALOR,
    this.HORAS_SIN_LECTURA,
    this.ATRASADA = false,
    this.MOTIVO,
  });

  final int ava_id;
  final int ACTIVO_ID;
  final String ACTIVO_NOMBRE;
  final String? ACTIVO_CODIGO;
  final String? AREA_NOMBRE;
  final String? VARIABLE_NOMBRE;
  final String? UNIDAD;
  final double? VALOR_ADVERTENCIA;
  final double? VALOR_CRITICO;
  final int? CADA_HORAS;
  final int LECTURAS;
  final DateTime? ULTIMA_UTC;
  final double? ULTIMO_VALOR;
  final int? HORAS_SIN_LECTURA;

  /// Lleva más tiempo sin medirse del que declara su frecuencia esperada. No
  /// está vigilado: está abandonado, y decirlo es más útil que callarlo.
  final bool ATRASADA;

  /// SIN LECTURAS · FALTAN LECTURAS · SIN SENALES
  final String? MOTIVO;

  bool get sinLecturas => MOTIVO == 'SIN LECTURAS';
  bool get faltanLecturas => MOTIVO == 'FALTAN LECTURAS';
  bool get tranquilo => MOTIVO == 'SIN SENALES';

  String get explicacion => switch (MOTIVO) {
        'SIN LECTURAS' => 'Nadie lo ha medido todavía.',
        'FALTAN LECTURAS' =>
          'Van $LECTURAS lecturas. Con menos de cuatro no se puede ver una tendencia.',
        _ => 'Se mide y no muestra señales de alza.',
      };

  factory Vigilado.fromJson(Map<String, dynamic> j) => Vigilado(
        ava_id: _i(j['ava_id']),
        ACTIVO_ID: _i(j['ACTIVO_ID']),
        ACTIVO_NOMBRE: _s(j['ACTIVO_NOMBRE']),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        VARIABLE_NOMBRE: _sN(j['VARIABLE_NOMBRE']),
        UNIDAD: _sN(j['UNIDAD']),
        VALOR_ADVERTENCIA: _dN(j['VALOR_ADVERTENCIA']),
        VALOR_CRITICO: _dN(j['VALOR_CRITICO']),
        CADA_HORAS: j['CADA_HORAS'] == null ? null : _i(j['CADA_HORAS']),
        LECTURAS: _i(j['LECTURAS']),
        ULTIMA_UTC: _f(j['ULTIMA_UTC']),
        ULTIMO_VALOR: _dN(j['ULTIMO_VALOR']),
        HORAS_SIN_LECTURA: j['HORAS_SIN_LECTURA'] == null
            ? null
            : _i(j['HORAS_SIN_LECTURA']),
        ATRASADA: j['ATRASADA'] == true,
        MOTIVO: _sN(j['MOTIVO']),
      );
}

/// Convierte una lista JSON con el mapeador que se le pase.
List<T> _lista<T>(dynamic v, T Function(Map<String, dynamic>) mapear) =>
    (v is List)
        ? v.map((e) => mapear((e as Map).cast<String, dynamic>())).toList()
        : const [];

// ===========================================================================
//  TAREAS EN TERRENO                                       HU-103 y HU-104
// ===========================================================================

/// Una tarea pendiente en la bandeja.
///
/// La tarea es el trabajo breve que hoy no deja registro —revisar un nivel,
/// limpiar un filtro—. No tiene pasos ni permiso de trabajo: tiene una
/// ocurrencia, alguien que la ejecuta y un resultado.
class TareaPendiente {
  const TareaPendiente({
    required this.toc_id,
    required this.tar_titulo,
    this.TAREA_CODIGO,
    this.tar_descripcion,
    this.tar_duracion_estimada_minuto,
    this.tar_requiere_evidencia = false,
    this.PRIORIDAD_CODIGO,
    this.PRIORIDAD_NOMBRE,
    this.PRIORIDAD_ID = 2,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.ACTIVO_FOTO,
    this.POSICION_CODIGO,
    this.ES_FAVORITO = false,
    this.AREA_NOMBRE,
    this.ESTADO_NOMBRE,
    this.toc_fecha_limite_utc,
    this.SITUACION,
    this.COMENTARIOS = 0,
    this.EJECUCION_ABIERTA,
  });

  final int toc_id;
  final String tar_titulo;
  final String? TAREA_CODIGO;
  final String? tar_descripcion;
  final int? tar_duracion_estimada_minuto;
  final bool tar_requiere_evidencia;
  final String? PRIORIDAD_CODIGO;
  final String? PRIORIDAD_NOMBRE;
  final int PRIORIDAD_ID;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;

  /// «MOT-001 · Motor principal línea 3». Vacío si la orden no cuelga de un
  /// activo —una limpieza general, por ejemplo—, y ahí la tarjeta lo dice.
  String get activo => [ACTIVO_CODIGO, ACTIVO_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  /// La foto del activo y la línea donde está montado.
  ///
  /// En una bandeja de doce órdenes el nombre no basta: puede haber cinco
  /// motores iguales y solo uno está en la Línea 3. La foto llega como **ruta
  /// de blob**, así que tres órdenes del mismo equipo comparten una sola
  /// descarga —`ImagenService` deduplica por ruta y la guarda en disco—.
  final String? ACTIVO_FOTO;
  final String? POSICION_CODIGO;

  /// Si esta persona lo fijó arriba de su bandeja.
  ///
  /// Viaja **dentro** del listado y no en una consulta aparte: pedirlo por
  /// separado haría que las estrellas se encendieran de a una sobre una lista
  /// ya dibujada.
  final bool ES_FAVORITO;
  final String? AREA_NOMBRE;
  final String? ESTADO_NOMBRE;
  final DateTime? toc_fecha_limite_utc;

  /// VENCIDA · VENCE HOY · EN PLAZO · SIN PLAZO. Lo decide el SP: si lo
  /// calculara la app, dos teléfonos con distinta hora dirían cosas distintas.
  final String? SITUACION;

  final int COMENTARIOS;

  /// Si viene, esta persona dejó la tarea a medio hacer y hay que retomar
  /// **esa** ejecución en vez de abrir otra.
  final int? EJECUCION_ABIERTA;

  bool get vencida => (SITUACION ?? '').toUpperCase() == 'VENCIDA';
  bool get venceHoy => (SITUACION ?? '').toUpperCase() == 'VENCE HOY';
  bool get empezada => EJECUCION_ABIERTA != null;
  bool get critica => PRIORIDAD_ID >= 4;

  /// Dónde está: área y **línea**. El equipo ya no entra acá porque se
  /// muestra identificado en su propia fila.
  String get donde => [AREA_NOMBRE, POSICION_CODIGO]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  factory TareaPendiente.fromJson(Map<String, dynamic> j) => TareaPendiente(
        toc_id: _i(j['toc_id']),
        tar_titulo: _s(j['tar_titulo']),
        TAREA_CODIGO: _sN(j['TAREA_CODIGO']),
        tar_descripcion: _sN(j['tar_descripcion']),
        tar_duracion_estimada_minuto: j['tar_duracion_estimada_minuto'] == null
            ? null
            : _i(j['tar_duracion_estimada_minuto']),
        tar_requiere_evidencia: j['tar_requiere_evidencia'] == true,
        PRIORIDAD_CODIGO: _sN(j['PRIORIDAD_CODIGO']),
        PRIORIDAD_NOMBRE: _sN(j['PRIORIDAD_NOMBRE']),
        PRIORIDAD_ID: _i(j['PRIORIDAD_ID'], 2),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        ACTIVO_FOTO: _sN(j['ACTIVO_FOTO']),
        POSICION_CODIGO: _sN(j['POSICION_CODIGO']),
        ES_FAVORITO: _b(j['ES_FAVORITO']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        toc_fecha_limite_utc: _f(j['toc_fecha_limite_utc']),
        SITUACION: _sN(j['SITUACION']),
        COMENTARIOS: _i(j['COMENTARIOS']),
        EJECUCION_ABIERTA:
            j['EJECUCION_ABIERTA'] == null ? null : _i(j['EJECUCION_ABIERTA']),
      );
}

/// Un comentario del hilo.
///
/// No se edita ni se borra: se responde. La tabla lo dice —no tiene
/// `habilitado` ni auditoría de actualización, y sí tiene comentario padre—.
class TareaComentario {
  const TareaComentario({
    required this.tco_id,
    required this.tco_texto,
    required this.tco_fecha_creacion,
    this.PADRE_ID,
    this.POR_VOZ = false,
    this.TEXTO_DICTADO,
    this.DICTADO_CONFIANZA,
    this.DICTADO_CORREGIDO = false,
    this.USUARIO_ID = 0,
    this.USUARIO_NOMBRE,
  });

  final int tco_id;
  final String tco_texto;
  final DateTime tco_fecha_creacion;
  final int? PADRE_ID;
  final bool POR_VOZ;

  /// Lo que entendió el teléfono antes de que la persona lo corrigiera.
  /// Guardarlo es lo único que después permite saber si dictar sirve en una
  /// sala de máquinas.
  final String? TEXTO_DICTADO;

  final double? DICTADO_CONFIANZA;
  final bool DICTADO_CORREGIDO;
  final int USUARIO_ID;
  final String? USUARIO_NOMBRE;

  bool get esRespuesta => PADRE_ID != null;

  factory TareaComentario.fromJson(Map<String, dynamic> j) => TareaComentario(
        tco_id: _i(j['tco_id']),
        tco_texto: _s(j['tco_texto']),
        tco_fecha_creacion: _f(j['tco_fecha_creacion']) ?? DateTime.now(),
        PADRE_ID: j['PADRE_ID'] == null ? null : _i(j['PADRE_ID']),
        POR_VOZ: j['POR_VOZ'] == true,
        TEXTO_DICTADO: _sN(j['TEXTO_DICTADO']),
        DICTADO_CONFIANZA: j['DICTADO_CONFIANZA'] == null
            ? null
            : (j['DICTADO_CONFIANZA'] as num).toDouble(),
        DICTADO_CORREGIDO: j['DICTADO_CORREGIDO'] == true,
        USUARIO_ID: _i(j['USUARIO_ID']),
        USUARIO_NOMBRE: _sN(j['USUARIO_NOMBRE']),
      );
}

/// La tarea abierta, con su ejecución y su hilo.
class Tarea {
  const Tarea({
    required this.toc_id,
    required this.tar_titulo,
    this.TAREA_CODIGO,
    this.tar_descripcion,
    this.tar_requiere_evidencia = false,
    this.tar_duracion_estimada_minuto,
    this.PRIORIDAD_NOMBRE,
    this.PRIORIDAD_ID = 2,
    this.ACTIVO_CODIGO,
    this.ACTIVO_NOMBRE,
    this.ACTIVO_FOTO,
    this.POSICION_CODIGO,
    this.ES_FAVORITO = false,
    this.AREA_NOMBRE,
    this.ESTADO_ID = 1,
    this.ESTADO_NOMBRE,
    this.toc_fecha_limite_utc,
    this.EJECUCION_ID,
    this.tej_fecha_inicio_utc,
    this.tej_fecha_fin_utc,
    this.tej_duracion_minuto,
    this.tej_resultado,
    this.tej_conforme,
    this.EVIDENCIAS = 0,
    this.comentarios = const [],
  });

  final int toc_id;
  final String tar_titulo;
  final String? TAREA_CODIGO;
  final String? tar_descripcion;
  final bool tar_requiere_evidencia;
  final int? tar_duracion_estimada_minuto;
  final String? PRIORIDAD_NOMBRE;
  final int PRIORIDAD_ID;
  final String? ACTIVO_CODIGO;
  final String? ACTIVO_NOMBRE;

  /// «MOT-001 · Motor principal línea 3». Vacío si la orden no cuelga de un
  /// activo —una limpieza general, por ejemplo—, y ahí la tarjeta lo dice.
  String get activo => [ACTIVO_CODIGO, ACTIVO_NOMBRE]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  /// La foto del activo y la línea donde está montado.
  ///
  /// En una bandeja de doce órdenes el nombre no basta: puede haber cinco
  /// motores iguales y solo uno está en la Línea 3. La foto llega como **ruta
  /// de blob**, así que tres órdenes del mismo equipo comparten una sola
  /// descarga —`ImagenService` deduplica por ruta y la guarda en disco—.
  final String? ACTIVO_FOTO;
  final String? POSICION_CODIGO;

  /// Si esta persona lo fijó arriba de su bandeja.
  ///
  /// Viaja **dentro** del listado y no en una consulta aparte: pedirlo por
  /// separado haría que las estrellas se encendieran de a una sobre una lista
  /// ya dibujada.
  final bool ES_FAVORITO;
  final String? AREA_NOMBRE;
  final int ESTADO_ID;
  final String? ESTADO_NOMBRE;
  final DateTime? toc_fecha_limite_utc;
  final int? EJECUCION_ID;
  final DateTime? tej_fecha_inicio_utc;
  final DateTime? tej_fecha_fin_utc;
  final int? tej_duracion_minuto;
  final String? tej_resultado;
  final bool? tej_conforme;

  /// Cuántas fotos lleva. Sin esto la app no puede saber si ya hay evidencia y
  /// «Listo» mandaría un envío que va a rebotar: rebotar está bien como última
  /// defensa, como única defensa es hacerle perder el viaje a alguien que está
  /// parado frente a la máquina.
  final int EVIDENCIAS;

  final List<TareaComentario> comentarios;

  bool get cerrada => ESTADO_ID >= 4;
  bool get enEjecucion => EJECUCION_ID != null && tej_fecha_fin_utc == null;

  /// Falta la foto obligatoria. El veredicto que cuenta lo pone el servidor;
  /// esto solo evita ofrecer un botón que va a rebotar.
  bool get faltaEvidencia => tar_requiere_evidencia && EVIDENCIAS == 0;
  bool get critica => PRIORIDAD_ID >= 4;

  /// Dónde está: área y **línea**. El equipo ya no entra acá porque se
  /// muestra identificado en su propia fila.
  String get donde => [AREA_NOMBRE, POSICION_CODIGO]
      .where((s) => (s ?? '').isNotEmpty)
      .join(' · ');

  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(
        toc_id: _i(j['toc_id']),
        tar_titulo: _s(j['tar_titulo']),
        TAREA_CODIGO: _sN(j['TAREA_CODIGO']),
        tar_descripcion: _sN(j['tar_descripcion']),
        tar_requiere_evidencia: j['tar_requiere_evidencia'] == true,
        tar_duracion_estimada_minuto: j['tar_duracion_estimada_minuto'] == null
            ? null
            : _i(j['tar_duracion_estimada_minuto']),
        PRIORIDAD_NOMBRE: _sN(j['PRIORIDAD_NOMBRE']),
        PRIORIDAD_ID: _i(j['PRIORIDAD_ID'], 2),
        ACTIVO_CODIGO: _sN(j['ACTIVO_CODIGO']),
        ACTIVO_NOMBRE: _sN(j['ACTIVO_NOMBRE']),
        ACTIVO_FOTO: _sN(j['ACTIVO_FOTO']),
        POSICION_CODIGO: _sN(j['POSICION_CODIGO']),
        ES_FAVORITO: _b(j['ES_FAVORITO']),
        AREA_NOMBRE: _sN(j['AREA_NOMBRE']),
        ESTADO_ID: _i(j['ESTADO_ID'], 1),
        ESTADO_NOMBRE: _sN(j['ESTADO_NOMBRE']),
        toc_fecha_limite_utc: _f(j['toc_fecha_limite_utc']),
        EJECUCION_ID: j['EJECUCION_ID'] == null ? null : _i(j['EJECUCION_ID']),
        tej_fecha_inicio_utc: _f(j['tej_fecha_inicio_utc']),
        tej_fecha_fin_utc: _f(j['tej_fecha_fin_utc']),
        tej_duracion_minuto: j['tej_duracion_minuto'] == null
            ? null
            : _i(j['tej_duracion_minuto']),
        tej_resultado: _sN(j['tej_resultado']),
        tej_conforme: j['tej_conforme'] as bool?,
        EVIDENCIAS: _i(j['EVIDENCIAS']),
        comentarios: (j['comentarios'] is List)
            ? (j['comentarios'] as List)
                .map((e) => TareaComentario.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList()
            : const [],
      );
}
