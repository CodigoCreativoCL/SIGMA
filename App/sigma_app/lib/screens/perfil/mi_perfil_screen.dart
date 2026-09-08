import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/sincronizacion_provider.dart';
import '../../services/api_client.dart';
import '../../services/preferencias_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../services/tema_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../login/login_screen.dart';
import '../seleccion/seleccion_contexto_screen.dart';

/// Mi perfil — HU-005.
///
/// Layout v3: cabecera con avatar 76 y el badge **sólido** del perfil; tarjeta
/// de contexto con la píldora «Cambiar»; bloques MIS DATOS y APLICACIÓN en
/// filas de 54 separadas por el divisor; pie con la versión y «Cerrar sesión».
///
/// ## Qué se puede cambiar y qué no
///
/// El **nombre y el correo identifican a la persona dentro del cliente**:
/// cambiarlos es una operación administrativa que se hace en la web, con
/// permiso y con rastro. Acá se cambia lo que es de la persona —su teléfono,
/// su contraseña— y lo que es del aparato —el tema, los avisos—.
class MiPerfilScreen extends ConsumerWidget {
  const MiPerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final perfil = ref.watch(miPerfilProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra(
        'Mi perfil',
        tamanoTitulo: 23,
        acciones: [
          Padding(padding: EdgeInsets.only(right: 6), child: _BadgeConexion()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(miPerfilProvider),
        child: ListView(
          padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 20, 16, 16)),
          children: [
            EstadoAsync<MiPerfil>(
              valor: perfil,
              onReintentar: () => ref.invalidate(miPerfilProvider),
              child: (p) => Column(
                children: [
                  _Cabecera(p),
                  const SizedBox(height: 13),
                  const _Contexto(),
                  const SizedBox(height: 13),
                  _MisDatos(p),
                ],
              ),
            ),
            const SizedBox(height: 13),
            const _Aplicacion(),
            const SizedBox(height: 22),
            const _Version(),
            const SizedBox(height: 9),
            SgBoton('Cerrar sesión',
                icono: Icons.logout,
                primario: false,
                colorTexto: sg.rojoTexto,
                colorIcono: sg.rojoTexto,
                onTap: () => _salir(context, ref)),
            const SizedBox(height: 4),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }

  Future<void> _salir(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(sesionProvider.notifier);
    final nav = Navigator.of(context);
    await notifier.cerrar();

    for (final p in [
      miPerfilProvider,
      menuProvider,
      permisosProvider,
      resumenAlertasProvider,
    ]) {
      ref.invalidate(p);
    }
    ref.read(instalacionProvider.notifier).state = null;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _BadgeConexion extends StatelessWidget {
  const _BadgeConexion();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.enLinea,
      builder: (_, enLinea, _) => SgBadge(
        enLinea ? 'En línea' : 'Sin señal',
        color: enLinea ? sg.acentoTexto : sg.tinta3,
        punto: true,
      ),
    );
  }
}

/// La cabecera.
///
/// El badge del perfil es la variante **sólida** del kit —relleno teal, texto
/// oscuro—, la única del sistema que no está teñida: dice qué puede hacer la
/// persona, y eso no es un estado que cambie de un día a otro.
class _Cabecera extends StatelessWidget {
  const _Cabecera(this.p);
  final MiPerfil p;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Row(
      children: [
        SgAvatar(p.iniciales, id: p.usu_id, lado: 76),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombreCompleto,
                  style: sora(22, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis),
              if ((p.PERFILES ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                SgBadge(p.PERFILES!,
                    color: SgColor.tealSolido,
                    icono: Icons.engineering,
                    solido: true),
              ],
              const SizedBox(height: 6),
              Text(p.usu_correo ?? p.usu_login,
                  style: sora(13, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Contexto extends ConsumerWidget {
  const _Contexto();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final sesion = ref.watch(sesionProvider);
    final instalacion = ref.watch(instalacionProvider);

    return SgCard(
      child: Row(
        children: [
          SgIconoCuadro(Icons.swap_horiz,
              color: sg.primario, lado: 44, tamanoIcono: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sesion.clienteNombre.isEmpty
                      ? 'Sin cliente elegido'
                      : sesion.clienteNombre,
                  style: sora(16, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(instalacion?.cin_nombre ?? 'Sin instalación',
                    style: sora(13, 500, color: sg.tinta2),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Pildora('Cambiar',
              onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SeleccionContextoScreen()),
                  )),
        ],
      ),
    );
  }
}

/// La píldora de 34 en `up`.
class _Pildora extends StatelessWidget {
  const _Pildora(this.texto, {required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Material(
      color: sg.up,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(texto, style: sora(14, 600, color: sg.tinta)),
        ),
      ),
    );
  }
}

class _MisDatos extends ConsumerWidget {
  const _MisDatos(this.p);
  final MiPerfil p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;

    return SgBloque(
      rotulo: 'Mis datos',
      filas: [
        SgFila(
          icono: Icons.phone_outlined,
          texto: 'Teléfono',
          colorTexto: sg.tinta2,
          valor: (p.usu_telefono ?? '').isEmpty
              ? 'Sin registrar'
              : p.usu_telefono!,
          chevron: true,
          onTap: () => _editarTelefono(context, ref, p.usu_telefono ?? ''),
        ),
        SgFila(
          icono: Icons.email_outlined,
          texto: 'Correo',
          colorTexto: sg.tinta2,
          derecha:
              SgBadge('Solo lectura', color: sg.tinta3, icono: Icons.lock_outline),
        ),
        SgFila(
          icono: Icons.badge_outlined,
          texto: 'Perfil',
          colorTexto: sg.tinta2,
          derecha:
              SgBadge('Solo lectura', color: sg.tinta3, icono: Icons.lock_outline),
        ),
      ],
    );
  }
}

/// HU-005 · cambiar el teléfono.
///
/// **Es el único dato de contacto que la persona controla**, y no es un
/// capricho: es por donde se le avisa cuando algo se cae en su turno. Un
/// teléfono viejo en la ficha significa que el aviso no llega.
Future<void> _editarTelefono(
    BuildContext context, WidgetRef ref, String actual) async {
  final control = TextEditingController(text: actual);
  final formulario = GlobalKey<FormState>();

  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _HojaFormulario(
      titulo: 'Mi teléfono',
      formulario: formulario,
      textoBoton: 'Guardar',
      campos: [
        SgCampo(
          controlador: control,
          rotulo: 'Teléfono',
          icono: Icons.phone_outlined,
          hint: '+56 9 1234 5678',
          teclado: TextInputType.phone,
          validador: (v) => (v == null || v.trim().length < 8)
              ? 'Escribe un teléfono con el que te puedan ubicar'
              : null,
        ),
      ],
      alGuardar: () => SigmaRepository.instance
          .actualizarPerfil(telefono: control.text.trim()),
    ),
  );

  control.dispose();
  if (guardado == true) ref.invalidate(miPerfilProvider);
}

class _Aplicacion extends StatelessWidget {
  const _Aplicacion();

  @override
  Widget build(BuildContext context) => SgBloque(
        rotulo: 'Aplicación',
        filas: [
          SgFila(
            icono: Icons.shield_outlined,
            texto: 'Cambiar contraseña',
            chevron: true,
            onTap: () => _cambiarPassword(context),
          ),
          const SgFila(
            icono: Icons.notifications_none,
            texto: 'Notificaciones',
            derecha: _SwitchAvisos(),
          ),
          const SgFila(
            icono: Icons.dark_mode_outlined,
            texto: 'Tema',
            derecha: _SelectorTema(),
          ),
        ],
      );
}

/// HU-005 · cambiar la contraseña.
///
/// La actual se pide **siempre**, incluso con la sesión abierta: el teléfono
/// desbloqueado y sin dueño encima de una mesa es el caso normal en una
/// planta, y sin ese campo cualquiera que lo levante se queda con la cuenta.
Future<void> _cambiarPassword(BuildContext context) async {
  final actual = TextEditingController();
  final nueva = TextEditingController();
  final repetir = TextEditingController();
  final formulario = GlobalKey<FormState>();
  final mensajero = ScaffoldMessenger.of(context);

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _HojaFormulario(
      titulo: 'Cambiar contraseña',
      formulario: formulario,
      textoBoton: 'Cambiar',
      campos: [
        SgCampo(
          controlador: actual,
          rotulo: 'Contraseña actual',
          icono: Icons.lock_outline,
          oculto: true,
          espaciadoTexto: 3,
          tamanoTexto: 19,
          pesoTexto: 600,
          validador: (v) =>
              (v == null || v.isEmpty) ? 'Escribe tu contraseña actual' : null,
        ),
        const SizedBox(height: 16),
        SgCampo(
          controlador: nueva,
          rotulo: 'Contraseña nueva',
          icono: Icons.lock_reset,
          oculto: true,
          espaciadoTexto: 3,
          tamanoTexto: 19,
          pesoTexto: 600,
          // El largo mínimo lo valida el SP, que es donde vive la política.
          // Acá solo se atajan los casos obvios para no hacer viajar un
          // rechazo seguro.
          validador: (v) =>
              (v == null || v.length < 6) ? 'Al menos 6 caracteres' : null,
        ),
        const SizedBox(height: 16),
        SgCampo(
          controlador: repetir,
          rotulo: 'Repetir la nueva',
          icono: Icons.lock_reset,
          oculto: true,
          espaciadoTexto: 3,
          tamanoTexto: 19,
          pesoTexto: 600,
          validador: (v) => v != nueva.text ? 'Las dos no coinciden' : null,
        ),
      ],
      alGuardar: () =>
          SigmaRepository.instance.cambiarPassword(actual.text, nueva.text),
    ),
  );

  actual.dispose();
  nueva.dispose();
  repetir.dispose();

  if (ok == true) {
    mensajero
        .showSnackBar(const SnackBar(content: Text('Contraseña cambiada.')));
  }
}

/// La hoja que envuelve un formulario corto.
///
/// Una sola: el teléfono y la contraseña son el mismo gesto —abrir, escribir,
/// guardar— y tener dos hojas parecidas garantiza que se separen con el
/// tiempo.
class _HojaFormulario extends StatefulWidget {
  const _HojaFormulario({
    required this.titulo,
    required this.formulario,
    required this.campos,
    required this.textoBoton,
    required this.alGuardar,
  });

  final String titulo;
  final GlobalKey<FormState> formulario;
  final List<Widget> campos;
  final String textoBoton;
  final Future<void> Function() alGuardar;

  @override
  State<_HojaFormulario> createState() => _HojaFormularioState();
}

class _HojaFormularioState extends State<_HojaFormulario> {
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    if (!(widget.formulario.currentState?.validate() ?? false)) return;
    final nav = Navigator.of(context);

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.alGuardar();
      nav.pop(true);
    } on ApiException catch (e) {
      // El mensaje del servidor se muestra tal cual: el SP dice si la actual
      // no coincide o si la nueva no cumple la política, y eso es accionable.
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sg.card,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SgRadius.hoja)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sg.indicador,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.titulo,
                            style: sora(20, 600, color: sg.tinta)),
                      ),
                      SgBotonIcono(Icons.close,
                          fondo: sg.up,
                          color: sg.tinta,
                          onTap: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: widget.formulario,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.campos,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: SgAviso(_error!,
                        icono: Icons.error_outline,
                        color: sg.rojoTexto,
                        tenido: true),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SgBoton(widget.textoBoton,
                      icono: Icons.check,
                      cargando: _guardando,
                      onTap: _guardar),
                ),
                const SgBarraGestos(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchAvisos extends StatelessWidget {
  const _SwitchAvisos();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<bool>(
      valueListenable: PreferenciasService.instance.avisos,
      builder: (_, activo, _) => Switch.adaptive(
        value: activo,
        activeThumbColor: Colors.white,
        activeTrackColor: sg.primario,
        inactiveTrackColor: sg.up2,
        onChanged: PreferenciasService.instance.cambiarAvisos,
      ),
    );
  }
}

/// El selector de modo, en la píldora segmentada del kit.
///
/// Tres opciones y no dos: **Auto** existe porque quien tiene el teléfono en
/// cambio automático espera que la app lo siga. Pero el de fábrica es
/// **Oscuro**: la app se usa en planta, y dejar que Android decida haría que
/// el técnico entre en claro solo porque nunca tocó ese ajuste.
class _SelectorTema extends StatelessWidget {
  const _SelectorTema();

  static const _opciones = [
    (modo: ThemeMode.dark, texto: 'Oscuro', icono: Icons.dark_mode_outlined),
    (modo: ThemeMode.light, texto: 'Claro', icono: Icons.light_mode_outlined),
    (modo: ThemeMode.system, texto: 'Auto', icono: Icons.brightness_auto),
  ];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaService.instance.modo,
      builder: (_, actual, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sg.up,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in _opciones)
              InkWell(
                onTap: () => TemaService.instance.cambiar(o.modo),
                borderRadius: BorderRadius.circular(SgRadius.pill),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: actual == o.modo ? sg.primario : null,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(o.icono,
                          size: 14,
                          color: actual == o.modo ? Colors.white : sg.tinta2),
                      const SizedBox(width: 5),
                      Text(o.texto,
                          style: sora(12, 600,
                              color:
                                  actual == o.modo ? Colors.white : sg.tinta2)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La línea de versión, con **cuándo se sincronizó por última vez**.
///
/// No es adorno: si algo no aparece en el teléfono, lo primero que hay que
/// saber es si los datos son de hace cinco minutos o de anteayer.
class _Version extends ConsumerWidget {
  const _Version();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final corte = ref.watch(sincronizacionProvider).fechaCorte;

    final cuando = corte == null
        ? 'sin sincronizar en esta sesión'
        : 'sincronizado ${_hace(DateTime.now().difference(corte.toLocal()))}';

    return Center(
      child: Text('v1.0.0 (24) · $cuando',
          style: sora(12, 500, color: sg.tinta3), textAlign: TextAlign.center),
    );
  }

  static String _hace(Duration d) {
    if (d.inMinutes < 1) return 'recién';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} ${d.inDays == 1 ? "día" : "días"}';
  }
}
