import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';

/// 4.3 · Recuperar contraseña — HU-004.
///
/// Layout del artboard: barra 64 con «Recuperar acceso»; título 26/700 a dos
/// líneas; campo de correo; botón primario; bloque «ESTADO DEL ENLACE» con
/// tres filas de 60 separadas por el divisor; al pie, «Volver al acceso» en
/// secundario.
///
/// ## Por qué está en la app y no solo en la web
///
/// El técnico **no tiene web**: su perfil tiene `per_ambito` APP y `SEL_LOGIN`
/// lo rechaza en el sitio. Si la recuperación viviera solo allá, quedaría
/// llamando al administrador por algo que puede resolver solo.
///
/// ## Dos cosas que parecen defectos y no lo son
///
/// **Responde lo mismo exista o no el correo.** Siempre el mismo mensaje. Si
/// la respuesta cambiara, este formulario sería una forma de averiguar qué
/// correos están registrados probándolos de a uno, sin credenciales y sin
/// límite.
///
/// **El token no vuelve en la respuesta.** Viaja por correo y solo por correo:
/// devolverlo convertiría «pedir recuperación» en «obtener acceso».
class RecuperarClaveScreen extends StatefulWidget {
  const RecuperarClaveScreen({super.key});

  @override
  State<RecuperarClaveScreen> createState() => _RecuperarClaveScreenState();
}

class _RecuperarClaveScreenState extends State<RecuperarClaveScreen> {
  final _formPedir = GlobalKey<FormState>();
  final _formCambiar = GlobalKey<FormState>();

  final _correo = TextEditingController();
  final _token = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  static final _hora = DateFormat('HH:mm');

  DateTime? _enviadoA;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _token.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _pedir() async {
    if (!(_formPedir.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await SigmaRepository.instance.pedirRecuperacion(_correo.text);
      if (mounted) setState(() => _enviadoA = DateTime.now());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _restablecer() async {
    if (!(_formCambiar.currentState?.validate() ?? false)) return;
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await SigmaRepository.instance.restablecer(_token.text, _nueva.text);
      mensajero.showSnackBar(const SnackBar(
          content: Text('Contraseña cambiada. Ya puedes entrar.')));
      navegador.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final enviado = _enviadoA != null;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Recuperar acceso'),
      bottomNavigationBar: SgPie(
        child: SgBoton('Volver al acceso',
            primario: false, onTap: () => Navigator.maybePop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: [
          SgTitulo(enviado
              ? 'Te enviamos un enlace\nal correo registrado'
              : '¿No puedes entrar?\nTe mandamos un enlace'),
          const SizedBox(height: 8),
          Text('El enlace sirve una sola vez y vence en 30 minutos.',
              style: sora(15, 500, color: sg.tinta2, alto: 1.55)),
          const SizedBox(height: 24),
          Form(
            key: _formPedir,
            child: SgCampo(
              controlador: _correo,
              rotulo: 'Correo registrado',
              icono: Icons.email_outlined,
              hint: 'nombre@empresa.cl',
              teclado: TextInputType.emailAddress,
              habilitado: !enviado || !_cargando,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe tu correo' : null,
            ),
          ),
          const SizedBox(height: 24),
          SgBoton(enviado ? 'Volver a enviar' : 'Enviar enlace',
              cargando: _cargando && !enviado,
              primario: !enviado,
              onTap: _pedir),
          const SizedBox(height: 24),
          const SgRotulo('Estado del enlace'),
          const SizedBox(height: 10),
          _EstadoEnlace(enviadoA: _enviadoA, hora: _hora),
          if (enviado) ...[
            const SizedBox(height: 24),
            const SgRotulo('Ya tengo el código'),
            const SizedBox(height: 10),
            _formularioCambio(sg),
          ],
          if (_error != null) ...[
            const SizedBox(height: 20),
            SgAviso(_error!,
                icono: Icons.error_outline, color: sg.rojoTexto, tenido: true),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _formularioCambio(AppColors sg) => Form(
        key: _formCambiar,
        child: SgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SgCampo(
                controlador: _token,
                rotulo: 'Código del correo',
                icono: Icons.vpn_key_outlined,
                hint: 'Pega el código',
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'Pega el código que llegó al correo'
                    : null,
              ),
              const SizedBox(height: 16),
              SgCampo(
                controlador: _nueva,
                rotulo: 'Contraseña nueva',
                icono: Icons.lock_outline,
                oculto: true,
                espaciadoTexto: 3,
                tamanoTexto: 19,
                pesoTexto: 600,
                // El largo mínimo lo valida el SP, que es donde vive la
                // política. Acá solo se atajan los casos obvios para no hacer
                // viajar un rechazo seguro.
                validador: (v) =>
                    (v == null || v.length < 6) ? 'Al menos 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              SgCampo(
                controlador: _repetir,
                rotulo: 'Repetir la contraseña',
                icono: Icons.lock_outline,
                oculto: true,
                espaciadoTexto: 3,
                tamanoTexto: 19,
                pesoTexto: 600,
                validador: (v) =>
                    v != _nueva.text ? 'Las dos no coinciden' : null,
              ),
              const SizedBox(height: 20),
              SgBoton('Cambiar la contraseña',
                  icono: Icons.check,
                  cargando: _cargando && _enviadoA != null,
                  onTap: _restablecer),
            ],
          ),
        ),
      );
}

/// Los tres estados por los que pasa el enlace.
///
/// El kit los dibuja como una lista, y así se quedan: **son el ciclo de vida
/// completo**, no tres errores sueltos. La fila que corresponde al momento
/// actual va en tinta plena; las otras dos quedan atenuadas, para que se lean
/// como lo que puede pasar y no como lo que pasó.
class _EstadoEnlace extends StatelessWidget {
  const _EstadoEnlace({required this.enviadoA, required this.hora});

  final DateTime? enviadoA;
  final DateFormat hora;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final enviado = enviadoA != null;

    final vence = enviadoA?.add(const Duration(minutes: 30));
    final vencido = vence != null && DateTime.now().isAfter(vence);

    return SgBloque(
      filas: [
        _Fila(
          icono: Icons.check_circle,
          color: sg.verdeTexto,
          titulo: 'Solicitud enviada',
          detalle: enviado
              ? 'Hoy ${hora.format(enviadoA!)} · vence ${hora.format(vence!)}'
              : 'Todavía no has pedido ninguno',
          activa: enviado && !vencido,
        ),
        _Fila(
          icono: Icons.link_off,
          color: sg.tinta3,
          titulo: 'Enlace ya utilizado',
          detalle: 'Pide uno nuevo',
          activa: false,
        ),
        _Fila(
          icono: Icons.timer_off_outlined,
          color: sg.ambarTexto,
          titulo: 'Enlace vencido',
          detalle: 'Pasaron más de 30 minutos',
          activa: vencido,
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    required this.activa,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Opacity(
      opacity: activa ? 1 : 0.55,
      child: SizedBox(
        height: SgMedidaFila.alto,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icono, size: 21, color: activa ? color : sg.tinta3),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: sora(15, activa ? 600 : 500,
                            color: activa ? sg.tinta : sg.tinta2)),
                    const SizedBox(height: 2),
                    Text(detalle,
                        style: sora(12, 500, color: sg.tinta3),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El alto de fila del bloque de estado, que el kit fija en 60.
abstract final class SgMedidaFila {
  static const alto = 60.0;
}
