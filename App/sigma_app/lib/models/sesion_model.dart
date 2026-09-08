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

  /// True cuando la persona pertenece a más de un cliente y todavía no
  /// eligió (HU-002): hay que mandarla a elegir antes de dejarla operar.
  final bool debeElegirCliente;

  bool get autenticado => usuario > 0 && token.isNotEmpty;
  bool get tieneCliente => cliente > 0;

  /// Para saludar. Si el servidor no mandó nombre, el login sirve.
  String get saludo {
    final n = (nombre ?? '').trim();
    if (n.isNotEmpty) return n.split(' ').first;
    return login.split('@').first;
  }

  factory SesionModel.fromJson(Map<String, dynamic> j) => SesionModel(
        usuario: (j['usuario'] as num?)?.toInt() ?? 0,
        login: j['login'] as String? ?? '',
        nombre: j['nombre'] as String?,
        cliente: (j['cliente'] as num?)?.toInt() ?? 0,
        clienteNombre: j['cliente_nombre'] as String? ?? '',
        token: j['token'] as String? ?? '',
        expiraMinutos: (j['expira_minutos'] as num?)?.toInt() ?? 0,
        debeElegirCliente: j['debe_elegir_cliente'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'usuario': usuario,
        'login': login,
        'nombre': nombre,
        'cliente': cliente,
        'cliente_nombre': clienteNombre,
        'token': token,
        'expira_minutos': expiraMinutos,
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
    bool? debeElegirCliente,
  }) =>
      SesionModel(
        usuario: usuario ?? this.usuario,
        login: login ?? this.login,
        nombre: nombre ?? this.nombre,
        cliente: cliente ?? this.cliente,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        token: token ?? this.token,
        expiraMinutos: expiraMinutos ?? this.expiraMinutos,
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
