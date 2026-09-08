import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../activo/activo_ficha_screen.dart';
import '../inventario/existencias_screen.dart';

/// El código que se está resolviendo. Vacío = todavía no se leyó nada.
final codigoEscaneadoProvider = StateProvider<String>((ref) => '');

/// Escáner QR — HU-154 y HU-067.
///
/// Una sola pantalla de cámara para las dos historias: lo que cambia es qué se
/// hace con el código, no cómo se lee. **Lo resuelve el servidor**, con
/// `GET /escaneo?c=`, que devuelve el tipo —activo, repuesto, ubicación,
/// bodega— y su desglose.
///
/// ## Esta pantalla es oscura en los dos modos
///
/// No es un olvido del tema: **detrás hay vídeo**. Una hoja blanca sobre la
/// imagen de la cámara la vuelve ilegible y encandila en una bodega a oscuras,
/// así que los colores acá son los del artboard, fijos.
///
/// ## Por qué `noDuplicates`
///
/// La cámara entrega el mismo código treinta veces por segundo mientras esté
/// encuadrado. Sin esto, cada fotograma dispararía una consulta al servidor
/// por el mismo activo.
class EscaneoScreen extends ConsumerStatefulWidget {
  const EscaneoScreen({super.key});

  @override
  ConsumerState<EscaneoScreen> createState() => _EscaneoScreenState();
}

class _EscaneoScreenState extends ConsumerState<EscaneoScreen> {
  static const _tinta = Color(0xFFF8FAFC);
  static const _tinta3 = Color(0xFF64748B);
  static const _panel = Color(0xFF111827);
  static const _linea = Color(0xFF2A3548);

  final _control = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.ean13,
    ],
  );

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    // Ya hay uno resuelto en pantalla: no se pisa mientras la persona lo mira.
    if (ref.read(codigoEscaneadoProvider).isNotEmpty) return;

    final valor = captura.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (valor.isEmpty) return;

    ref.read(codigoEscaneadoProvider.notifier).state = valor;
  }

  @override
  Widget build(BuildContext context) {
    final codigo = ref.watch(codigoEscaneadoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _control,
            onDetect: _alDetectar,
            errorBuilder: (_, e) => _SinCamara(mensaje: e.errorDetails?.message),
          ),
          // El velo del artboard: la cámara se ve, pero la interfaz encima se
          // lee. Sin él, un texto blanco sobre una pared blanca desaparece.
          const ColoredBox(color: Color(0xA805070E)),
          SafeArea(
            child: Column(
              children: [
                _BarraCamara(control: _control),
                if (codigo.isEmpty) ...[
                  const SizedBox(height: 6),
                  const _PildoraAyuda(),
                  const SizedBox(height: 20),
                  const Expanded(child: Center(child: _Marco())),
                ] else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _Resultado(
                        codigo: codigo,
                        onOtro: () =>
                            ref.read(codigoEscaneadoProvider.notifier).state =
                                '',
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _BotonVidrio(
                    texto: 'Ingresar código a mano',
                    icono: Icons.keyboard_outlined,
                    onTap: _ingresarAMano,
                  ),
                ),
                const SgBarraGestos(color: _linea),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// El ingreso manual **no es un plan B**: una etiqueta rayada o con grasa es
  /// común en planta, y sin esto el técnico se queda sin poder hacer nada.
  Future<void> _ingresarAMano() async {
    final control = TextEditingController();

    final codigo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xCC05070E),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: _panel,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _linea,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Escribe el código', style: sora(20, 600, color: _tinta)),
              const SizedBox(height: 6),
              Text(
                'El que está impreso en la etiqueta: MOT-001, UBI-17, REP-1205…',
                style: sora(14, 500, color: _tinta3, alto: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: control,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                style: sora(16, 600, color: _tinta),
                cursorColor: SgColor.oscuroPrimario,
                onSubmitted: (v) => Navigator.pop(c, v.trim()),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F1524),
                  hintText: 'Por ejemplo MOT-001',
                  hintStyle: sora(16, 500, color: _tinta3),
                  prefixIcon: const Icon(Icons.tag, size: 19, color: _tinta3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SgRadius.campo),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SgRadius.campo),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SgRadius.campo),
                    borderSide: const BorderSide(
                        color: SgColor.oscuroPrimario, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SgBoton('Buscar',
                  icono: Icons.search,
                  onTap: () => Navigator.pop(c, control.text.trim())),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    control.dispose();
    if (!mounted) return;
    if (codigo != null && codigo.isNotEmpty) {
      ref.read(codigoEscaneadoProvider.notifier).state = codigo;
    }
  }
}

/// La barra de la cámara: botones de 44 sobre vidrio, sin fondo de barra.
class _BarraCamara extends StatelessWidget {
  const _BarraCamara({required this.control});
  final MobileScannerController control;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: SgMedida.barraSuperior,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _BotonVidrioRedondo(Icons.close,
                  onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: control,
                builder: (_, estado, _) {
                  final encendida = estado.torchState == TorchState.on;
                  final hay = estado.torchState != TorchState.unavailable;
                  return _BotonVidrioRedondo(
                    encendida ? Icons.flashlight_on : Icons.flashlight_off,
                    color: encendida ? SgColor.teal : const Color(0xFFF8FAFC),
                    onTap: hay ? () => control.toggleTorch() : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              _BotonVidrioRedondo(Icons.cameraswitch_outlined,
                  onTap: () => control.switchCamera()),
            ],
          ),
        ),
      );
}

class _BotonVidrioRedondo extends StatelessWidget {
  const _BotonVidrioRedondo(this.icono,
      {this.onTap, this.color = const Color(0xFFF8FAFC)});

  final IconData icono;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: const Color(0xD1111827),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icono,
                size: 21,
                color: onTap == null ? color.withValues(alpha: 0.35) : color),
          ),
        ),
      );
}

class _PildoraAyuda extends StatelessWidget {
  const _PildoraAyuda();

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xD1111827),
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed, size: 17, color: SgColor.teal),
            const SizedBox(width: 7),
            Text('Apunta al código de la posición',
                style: sora(14, 500, color: const Color(0xFFF8FAFC))),
          ],
        ),
      );
}

/// El marco de 256 con las cuatro esquinas y la línea que barre.
///
/// La línea se anima de verdad: **un marco quieto se lee como una app
/// colgada**, y con guantes y a contraluz la única señal de que la cámara está
/// viva es que algo se mueva.
class _Marco extends StatefulWidget {
  const _Marco();

  @override
  State<_Marco> createState() => _MarcoState();
}

class _MarcoState extends State<_Marco> with SingleTickerProviderStateMixin {
  late final AnimationController _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 256,
        height: 256,
        child: Stack(
          children: [
            const _Esquina(Alignment.topLeft),
            const _Esquina(Alignment.topRight),
            const _Esquina(Alignment.bottomLeft),
            const _Esquina(Alignment.bottomRight),
            AnimatedBuilder(
              animation: _ciclo,
              builder: (_, _) => Align(
                alignment: Alignment(0, _ciclo.value * 1.6 - 0.8),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0x0000E0C2),
                      SgColor.teal,
                      Color(0x0000E0C2),
                    ]),
                    boxShadow: [
                      BoxShadow(color: Color(0x8C00E0C2), blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Esquina extends StatelessWidget {
  const _Esquina(this.donde);
  final Alignment donde;

  @override
  Widget build(BuildContext context) {
    const g = BorderSide(color: SgColor.teal, width: 4);
    final arriba = donde.y < 0;
    final izq = donde.x < 0;
    const r = Radius.circular(14);

    return Align(
      alignment: donde,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          border: Border(
            top: arriba ? g : BorderSide.none,
            bottom: arriba ? BorderSide.none : g,
            left: izq ? g : BorderSide.none,
            right: izq ? BorderSide.none : g,
          ),
          borderRadius: BorderRadius.only(
            topLeft: arriba && izq ? r : Radius.zero,
            topRight: arriba && !izq ? r : Radius.zero,
            bottomLeft: !arriba && izq ? r : Radius.zero,
            bottomRight: !arriba && !izq ? r : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _Resultado extends ConsumerWidget {
  const _Resultado({required this.codigo, required this.onOtro});

  final String codigo;
  final VoidCallback onOtro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = ref.watch(escaneoProvider(codigo));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(SgRadius.hoja),
        boxShadow: const [
          BoxShadow(
              color: Color(0xB3000000), blurRadius: 44, offset: Offset(0, 20)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: resultado.when(
        loading: () => _Buscando(codigo: codigo),
        error: (e, _) => _NoEncontrado(
          codigo: codigo,
          mensaje: '$e'.replaceFirst('ApiException: ', ''),
          onOtro: onOtro,
        ),
        data: (e) => _Encontrado(escaneo: e, codigo: codigo, onOtro: onOtro),
      ),
    );
  }
}

class _Buscando extends StatelessWidget {
  const _Buscando({required this.codigo});
  final String codigo;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: SgColor.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Buscando $codigo…',
                style: sora(16, 600, color: const Color(0xFFF8FAFC))),
          ),
        ],
      );
}

class _NoEncontrado extends StatelessWidget {
  const _NoEncontrado({
    required this.codigo,
    required this.mensaje,
    required this.onOtro,
  });

  final String codigo;
  final String mensaje;
  final VoidCallback onOtro;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SgColor.rojo.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(SgRadius.icono44),
                ),
                child: const Icon(Icons.search_off,
                    size: 22, color: SgColor.oscuroRojoTexto),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(codigo,
                        style: sora(17, 600, color: const Color(0xFFF8FAFC))),
                    const SizedBox(height: 3),
                    // El motivo del servidor, tal cual: puede ser que el
                    // código no exista o que sea de otro cliente, y son dos
                    // problemas distintos.
                    Text(mensaje,
                        style: sora(13, 500,
                            color: const Color(0xFF64748B), alto: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SgBoton('Escanear otro', icono: Icons.qr_code_scanner, onTap: onOtro),
        ],
      );
}

class _Encontrado extends StatelessWidget {
  const _Encontrado({
    required this.escaneo,
    required this.codigo,
    required this.onOtro,
  });

  final Escaneo escaneo;
  final String codigo;
  final VoidCallback onOtro;

  static const _tinta = Color(0xFFF8FAFC);
  static const _tinta3 = Color(0xFF64748B);

  String get _titulo {
    final c = escaneo.cabecera;
    return c?.rep_nombre ?? c?.bub_nombre ?? c?.bod_nombre ?? codigo;
  }

  String get _ruta {
    final c = escaneo.cabecera;
    return [c?.PLANTA, c?.bod_nombre, c?.bub_nombre]
        .where((s) => (s ?? '').isNotEmpty)
        .join(' › ');
  }

  IconData get _icono => switch (escaneo.tipo.toUpperCase()) {
        'ACTIVO' => Icons.view_in_ar_outlined,
        'REPUESTO' => Icons.inventory_2_outlined,
        'BODEGA' => Icons.warehouse_outlined,
        'UBICACION' => Icons.place_outlined,
        _ => Icons.qr_code_2,
      };

  Widget? _destino() => switch (escaneo.tipo.toUpperCase()) {
        'ACTIVO' => ActivoFichaScreen(activoId: escaneo.id),
        'REPUESTO' || 'BODEGA' || 'UBICACION' => const ExistenciasScreen(),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final destino = _destino();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // El recuadro de la foto. **La imagen la sirve el Blob Storage a
            // través de la API**; mientras el endpoint del escaneo no devuelva
            // la ruta del blob, queda el ícono del tipo y no una foto ajena.
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF182235),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_icono, size: 24, color: _tinta3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ChipOscuro(
                          escaneo.cabecera?.rep_codigo ??
                              escaneo.cabecera?.bub_codigo ??
                              codigo,
                          color: SgColor.teal),
                      const SizedBox(width: 7),
                      Flexible(
                        child: _ChipOscuro(escaneo.tipo,
                            color: SgColor.oscuroVerdeTexto,
                            icono: Icons.check_circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_titulo,
                      style: sora(20, 700,
                          color: _tinta, espaciado: -0.5, tabular: true),
                      overflow: TextOverflow.ellipsis),
                  if (_ruta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_ruta,
                        style: sora(13, 500, color: _tinta3),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (destino != null)
          SgBoton('Abrir ficha',
              icono: Icons.arrow_forward,
              iconoAlFinal: true,
              onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => destino),
                  ))
        else
          SgBoton('Escanear otro',
              icono: Icons.qr_code_scanner, primario: false, onTap: onOtro),
      ],
    );
  }
}

class _ChipOscuro extends StatelessWidget {
  const _ChipOscuro(this.texto, {required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(texto,
                  style: sora(12, 600, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _BotonVidrio extends StatelessWidget {
  const _BotonVidrio({
    required this.texto,
    required this.icono,
    required this.onTap,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: SgMedida.boton,
        width: double.infinity,
        child: Material(
          color: const Color(0xD1111827),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 20, color: const Color(0xFFF8FAFC)),
                  const SizedBox(width: 8),
                  Text(texto,
                      style: sora(16, 600, color: const Color(0xFFF8FAFC))),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Sin cámara —permiso denegado, aparato sin ella, emulador—.
///
/// **No es una pantalla de error**: el ingreso manual del pie sigue ahí abajo,
/// así que el técnico puede seguir trabajando igual. Solo se explica por qué
/// no hay vídeo.
class _SinCamara extends StatelessWidget {
  const _SinCamara({this.mensaje});
  final String? mensaje;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF0C121F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined,
                    size: 46, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                Text('No se puede usar la cámara',
                    textAlign: TextAlign.center,
                    style: sora(17, 600, color: const Color(0xFFF8FAFC))),
                const SizedBox(height: 8),
                Text(
                  mensaje?.isNotEmpty == true
                      ? mensaje!
                      : 'Revisa el permiso de cámara de SIGMA en los ajustes '
                          'del teléfono. Mientras tanto puedes escribir el '
                          'código a mano.',
                  textAlign: TextAlign.center,
                  style:
                      sora(14, 500, color: const Color(0xFF64748B), alto: 1.55),
                ),
              ],
            ),
          ),
        ),
      );
}
