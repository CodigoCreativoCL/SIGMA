/// Lo que devuelve `POST /sesion`.
///
/// Los campos se llaman igual que en el `SesionDto` de la API, que a su vez
/// se llama igual que la columna de SQL Server. Traducir a camelCase obliga a
/// mantener un diccionario en la cabeza de quien depura.
class SesionModel {
  const SesionModel({
    this.usuario = 0,
    this.login = '',
    this.nombre,
    this.cliente = 0,
    this.clienteNombre = '',
    this.token = '',
    this.expiraMinutos = 0,
    this.expiraEn,
    this.debeElegirCliente = false,
  });

  final int usuario;
  final String login;

  /// Puede venir null: `SEL_CLIENTE_USUARIO` excluye Root y Soporte, que son
  /// cuentas de plataforma. La fuente autoritativa es `GET /mi-perfil`.
  final String? nombre;

  final int cliente;
  final String clienteNombre;
  final String token;
  final int expiraMinutos;

  /// El instante en que el token deja de valer, en absoluto.
  ///
  /// `expiraMinutos` es **relativo** —«dura ocho horas»— y no sirve para saber
  /// si un token guardado en disco hace rato sigue vivo: al leerlo no hay con
  /// qué compararlo. El JWT sí caduca en el servidor (`JWT_EXPIRE_MINUTES`), y
  /// su `TokenValidationHandler` responde 401 «La sesión expiró» a todo lo que
  /// llegue con un token vencido —incluido, si se adjuntara, el propio login—.
  ///
  /// Se sella al recibir la sesión del servidor (`now + expiraMinutos`) y se
  /// persiste, para que al retomar la app se sepa **sin viaje de red** que la
  /// sesión ya no vale y se mande a la persona a entrar de nuevo, en vez de
  /// abrir un Home que va a responder 401 en cada pantalla.
  final DateTime? expiraEn;

  /// True cuando la persona pertenece a más de un cliente y todavía no
  /// eligió (HU-002): hay que mandarla a elegir antes de dejarla operar.
  final bool debeElegirCliente;

  /// Vencida según el reloj del teléfono. Sin `expiraEn` —sesión vieja
  /// guardada antes de que existiera este campo— se responde `false`: el 401
  /// del servidor sigue siendo el respaldo, y no se echa a nadie por una duda.
  bool get expirado =>
      expiraEn != null && !DateTime.now().isBefore(expiraEn!);

  bool get autenticado => usuario > 0 && token.isNotEmpty && !expirado;
  bool get tieneCliente => cliente > 0;

  /// Para saludar. Si el servidor no mandó nombre, el login sirve.
  String get saludo {
    final n = (nombre ?? '').trim();
    if (n.isNotEmpty) return n.split(' ').first;
    return login.split('@').first;
  }

  factory SesionModel.fromJson(Map<String, dynamic> j) {
    final token = j['token'] as String? ?? '';
    final minutos = (j['expira_minutos'] as num?)?.toInt() ?? 0;

    /* DE DÓNDE SALE `expiraEn`

       · Del disco: viaja `expira_en` (ISO) y se usa tal cual — es el instante
         real, calculado cuando el servidor emitió el token.
       · Del servidor: NO viaja `expira_en`, sólo `expira_minutos` relativo. El
         token acaba de emitirse, así que su vencimiento es `ahora + minutos`.
         Sellarlo acá deja el instante absoluto listo para persistir. */
    DateTime? expira;
    final crudo = j['expira_en'];
    if (crudo is String && crudo.isNotEmpty) {
      expira = DateTime.tryParse(crudo);
    } else if (token.isNotEmpty && minutos > 0) {
      expira = DateTime.now().add(Duration(minutes: minutos));
    }

    return SesionModel(
      usuario: (j['usuario'] as num?)?.toInt() ?? 0,
      login: j['login'] as String? ?? '',
      nombre: j['nombre'] as String?,
      cliente: (j['cliente'] as num?)?.toInt() ?? 0,
      clienteNombre: j['cliente_nombre'] as String? ?? '',
      token: token,
      expiraMinutos: minutos,
      expiraEn: expira,
      debeElegirCliente: j['debe_elegir_cliente'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'usuario': usuario,
    'login': login,
    'nombre': nombre,
    'cliente': cliente,
    'cliente_nombre': clienteNombre,
    'token': token,
    'expira_minutos': expiraMinutos,
    'expira_en': expiraEn?.toIso8601String(),
    'debe_elegir_cliente': debeElegirCliente,
  };

  SesionModel copyWith({
    int? usuario,
    String? login,
    String? nombre,
    int? cliente,
    String? clienteNombre,
    String? token,
    int? expiraMinutos,
    DateTime? expiraEn,
    bool? debeElegirCliente,
  }) => SesionModel(
    usuario: usuario ?? this.usuario,
    login: login ?? this.login,
    nombre: nombre ?? this.nombre,
    cliente: cliente ?? this.cliente,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    token: token ?? this.token,
    expiraMinutos: expiraMinutos ?? this.expiraMinutos,
    expiraEn: expiraEn ?? this.expiraEn,
    debeElegirCliente: debeElegirCliente ?? this.debeElegirCliente,
  );
}

/// Un cliente al que pertenece la persona (HU-002).
class ClienteElegibleModel {
  const ClienteElegibleModel({
    required this.id,
    required this.nombre,
    this.logoRuta,
  });

  final int id;
  final String nombre;

  /// La ruta de blob del logo de la empresa. Nula mientras nadie lo haya
  /// cargado desde la web: la tarjeta muestra entonces la inicial.
  final String? logoRuta;

  factory ClienteElegibleModel.fromJson(Map<String, dynamic> j) =>
      ClienteElegibleModel(
        id: (j['cli_id'] as num?)?.toInt() ?? 0,
        nombre: j['cli_nombre'] as String? ?? '',
        logoRuta: (j['LOGO_RUTA'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['LOGO_RUTA'] as String?,
      );
}
