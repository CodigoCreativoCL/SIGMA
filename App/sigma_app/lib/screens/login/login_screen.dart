import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sesion_provider.dart';
import '../../services/api_client.dart';
import '../../services/outbox_service.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../home/home_screen.dart';
import '../pendientes/pendientes_screen.dart';
import '../perfil/recuperar_clave_screen.dart';

/// 4.2 · Inicio de sesión — HU-001, HU-003, HU-004, HU-193.
///
/// Layout del artboard: halo morado arriba a la izquierda; marca centrada con
/// isotipo 66 y wordmark 24; campos de 56 con rótulo 13/600 que se tiñe al
/// enfocar; fila de «Recordarme» y «¿Olvidaste tu contraseña?»; botón
/// primario con su sombra proyectada y el secundario de huella en `up`.
///
/// ## La 4.2e no es otra pantalla
///
/// El kit dibuja los cuatro mensajes de acceso en un artboard aparte, pero son
/// **estados de esta misma pantalla** y así están implementados: el error de
/// credenciales tiñe el campo y escribe debajo; el bloqueo, la cuenta
/// deshabilitada y la suscripción vencida aparecen como tarjeta bajo el
/// formulario. Tenerlos en una pantalla propia habría significado navegar para
/// mostrar un error, y con eso se pierde lo que la persona ya había escrito.
///
/// ## Por qué la suscripción vencida ofrece ver la cola
///
/// Es el único de los cuatro donde el técnico **tiene algo que perder**: sus
/// registros locales siguen en el teléfono y la empresa dejó de pagar. El
/// botón le prueba que no se borraron.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _oculta = true;
  bool _recordarme = true;
  bool _cargando = false;

  String? _error;
  _Falla _falla = _Falla.credenciales;

  @override
  void initState() {
    super.initState();
    _login.text = SesionService.instance.ultimoLogin ?? '';
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // El notifier se captura ANTES del await: vive en el contenedor, no en
    // este widget, que puede desmontarse mientras la red responde.
    final sesion = ref.read(sesionProvider.notifier);

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await AuthService.instance
          .iniciar(_login.text, _password.text, recordar: _recordarme);
      sesion.refrescar();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      // El mensaje del servidor se muestra tal cual: está redactado para
      // leerse y dice qué hacer. Lo único que decide la app es **de qué
      // forma** mostrarlo, porque un 401 se arregla escribiendo bien y un 423
      // se arregla esperando.
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _falla = switch (e.codigo) {
            423 => _Falla.bloqueada,
            403 => _Falla.deshabilitada,
            402 || 409 => _Falla.suscripcion,
            _ => _Falla.credenciales,
          };
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final malCredencial = _error != null && _falla == _Falla.credenciales;

    return Scaffold(
      backgroundColor: sg.fondo,
      body: Stack(
        children: [
          const SgHalo(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          const SgIsotipo(alto: 66),
                          const SizedBox(height: 12),
                          const SgWordmark(alto: 24),
                          const SizedBox(height: 24),
                          _formulario(sg, malCredencial),
                          if (_error != null &&
                              _falla != _Falla.credenciales) ...[
                            const SizedBox(height: 24),
                            _TarjetaFalla(falla: _falla, mensaje: _error!),
                          ],
                          const SizedBox(height: 24),
                          const _AvisoCola(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                Text('v1.0.0 (24)', style: sora(12, 500, color: sg.tinta3)),
                const SizedBox(height: 12),
                const SgBarraGestos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario(AppColors sg, bool malCredencial) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SgCampo(
            controlador: _login,
            rotulo: 'Correo',
            icono: Icons.email_outlined,
            hint: 'nombre@empresa.cl',
            teclado: TextInputType.emailAddress,
            validador: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe tu correo' : null,
          ),
          const SizedBox(height: 16),
          SgCampo(
            controlador: _password,
            rotulo: 'Contraseña',
            // Con error de credenciales el candado se abre: es el mismo gesto
            // que hace el kit al cambiar el ícono a `lock-alert`.
            icono: malCredencial ? Icons.lock_open_outlined : Icons.lock_outline,
            oculto: _oculta,
            espaciadoTexto: _oculta ? 3 : null,
            tamanoTexto: _oculta ? 19 : 16,
            pesoTexto: _oculta ? 600 : 500,
            onSubmit: (_) => _entrar(),
            sufijo: SgBotonIcono(
              _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: sg.tinta2,
              onTap: () => setState(() => _oculta = !_oculta),
            ),
            validador: (v) {
              if (v == null || v.isEmpty) return 'Escribe tu contraseña';
              return malCredencial ? _error : null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SgCasilla('Recordarme',
                  marcada: _recordarme,
                  onCambio: (v) => setState(() => _recordarme = v)),
              SgEnlace('¿Olvidaste tu contraseña?',
                  onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RecuperarClaveScreen()),
                      )),
            ],
          ),
          const SizedBox(height: 16),
          SgBoton('Ingresar',
              icono: Icons.arrow_forward,
              iconoAlFinal: true,
              cargando: _cargando,
              onTap: _entrar),
          const SizedBox(height: 16),
          SgBoton('Ingresar con huella',
              icono: Icons.fingerprint,
              primario: false,
              colorIcono: sg.acentoTexto,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('El acceso biométrico llega más adelante.')),
                  )),
        ],
      );
}

/// Los tres estados que no son «escribiste mal».
enum _Falla { credenciales, bloqueada, deshabilitada, suscripcion }

class _TarjetaFalla extends StatelessWidget {
  const _TarjetaFalla({required this.falla, required this.mensaje});

  final _Falla falla;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final (IconData icono, Color color, String titulo) = switch (falla) {
      _Falla.bloqueada => (
          Icons.lock_clock,
          sg.rojoTexto,
          'Cuenta bloqueada temporalmente'
        ),
      _Falla.deshabilitada => (
          Icons.person_off_outlined,
          sg.tinta2,
          'Cuenta deshabilitada'
        ),
      _Falla.suscripcion => (
          Icons.credit_card_off_outlined,
          sg.ambarTexto,
          'Suscripción vencida'
        ),
      _Falla.credenciales => (Icons.error_outline, sg.rojoTexto, 'No se pudo entrar'),
    };

    return SgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SgIconoCuadro(icono,
                  color: color,
                  lado: 44,
                  tamanoIcono: 22,
                  // La deshabilitada no es una alarma: es un hecho
                  // administrativo, y pintarla de rojo la haría parecer un
                  // fallo del teléfono.
                  fondo: falla == _Falla.deshabilitada ? sg.up2 : null),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: sora(17, 600, color: sg.tinta)),
                    const SizedBox(height: 7),
                    Text(mensaje,
                        style: sora(13, 500, color: sg.tinta2, alto: 1.55)),
                  ],
                ),
              ),
            ],
          ),
          // Lo único accionable de los tres: probar que los registros locales
          // siguen ahí aunque la empresa haya dejado de pagar.
          if (falla == _Falla.suscripcion) ...[
            const SizedBox(height: 13),
            ValueListenableBuilder<int>(
              valueListenable: OutboxService.instance.pendientes,
              builder: (_, n, _) => n == 0
                  ? const SizedBox.shrink()
                  : SgBoton(
                      'Ver $n ${n == 1 ? "registro" : "registros"} en cola',
                      icono: Icons.inbox_outlined,
                      primario: false,
                      tamanoTexto: 15,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PendientesScreen()),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «Tienes N registros guardados en este teléfono.»
///
/// Solo aparece cuando los hay. Es lo que evita que alguien que no pudo entrar
/// crea que perdió el trabajo del turno: **la cola sobrevive al cierre de
/// sesión y a la app cerrada**, y decirlo acá vale más que decirlo adentro.
class _AvisoCola extends StatelessWidget {
  const _AvisoCola();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: OutboxService.instance.pendientes,
        builder: (_, n, _) => n == 0
            ? const SizedBox.shrink()
            : SgAviso(
                'Tienes $n ${n == 1 ? "registro guardado" : "registros guardados"} '
                'en este teléfono. Se conservan y se enviarán cuando vuelvas a '
                'entrar con conexión.',
                icono: Icons.cloud_sync_outlined,
                color: context.sg.acentoTexto,
              ),
      );
}
