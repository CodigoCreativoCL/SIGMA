import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_v3.dart';

/// Un lector de códigos que **solo devuelve el código**.
///
/// ## Por qué existe aparte de la pantalla de escaneo
///
/// `EscaneoScreen` hace dos cosas: leer el código y resolverlo contra el
/// servidor para mostrar qué es. Eso es lo correcto cuando escanear ES la
/// tarea —se apunta a una etiqueta para ver qué hay ahí—.
///
/// Pero dentro de un formulario la pregunta es otra: ya se sabe qué se está
/// buscando y el código es solo una forma de **escribirlo sin teclado**. Con
/// guantes de nitrilo, un `REP-6205` tecleado es donde más se falla, y abrir
/// la pantalla completa de escaneo para volver con un dato obligaría a salir
/// del formulario y perder lo que se llevaba escrito.
///
/// Devuelve el texto leído, o `null` si se cerró sin leer.
class SgLector extends StatefulWidget {
  const SgLector({super.key, required this.titulo, this.ayuda});

  final String titulo;

  /// Qué se espera leer. En terreno hay etiquetas de todo tipo pegadas juntas.
  final String? ayuda;

  /// Abre el lector como hoja y devuelve el código.
  static Future<String?> abrir(
    BuildContext context, {
    required String titulo,
    String? ayuda,
  }) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SgLector(titulo: titulo, ayuda: ayuda),
      );

  @override
  State<SgLector> createState() => _SgLectorState();
}

class _SgLectorState extends State<SgLector> {
  final _control = MobileScannerController(
    // `noDuplicates` evita que un código quieto delante de la cámara se lea
    // veinte veces por segundo.
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.ean13,
    ],
  );

  bool _yaLeido = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    // Una sola vez: el `pop` con la hoja ya cerrándose lanza, y la cámara
    // sigue entregando fotogramas mientras la animación de cierre corre.
    if (_yaLeido) return;

    final valor = captura.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (valor.isEmpty) return;

    _yaLeido = true;
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      decoration: BoxDecoration(
        color: sg.fondo,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.titulo,
                            style: sora(17, 600, color: sg.tinta)),
                        if ((widget.ayuda ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.ayuda!,
                              style: sora(12, 500, color: sg.tinta3)),
                        ],
                      ],
                    ),
                  ),
                  SgBotonIcono(Icons.close,
                      fondo: sg.up,
                      color: sg.tinta,
                      tamano: 20,
                      onTap: () => Navigator.of(context).maybePop()),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Un rectángulo y no la pantalla entera: la hoja deja ver el
            // formulario debajo, así se entiende que se vuelve a él.
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _control,
                    onDetect: _alDetectar,
                    errorBuilder: (_, e) => ColoredBox(
                      color: sg.up,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            e.errorDetails?.message ??
                                'No se pudo abrir la cámara. Escribe el código '
                                    'a mano.',
                            textAlign: TextAlign.center,
                            style: sora(13, 500, color: sg.tinta2, alto: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // La mira: sin ella nadie sabe a qué distancia poner la
                  // etiqueta, y se acerca hasta que la cámara no enfoca.
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 210,
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: sg.primario, width: 2),
                          borderRadius: BorderRadius.circular(SgRadius.card),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }
}
