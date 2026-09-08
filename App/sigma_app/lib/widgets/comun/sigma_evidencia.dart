import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/evidencia_service.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_imagen.dart';
import 'sigma_v3.dart';

/// Las fotos de evidencia de algo.
///
/// Sirve para cualquier destino —tarea, orden, paso, respuesta de pauta,
/// hallazgo— porque `Archivo_Vinculo` es polimórfica a propósito: el modelo ya
/// decidió que la evidencia es una sola idea con muchos dueños, y un widget
/// por pantalla sería repetir seis veces la misma cuadrícula.
///
/// ## Lo que se ve mientras sube
///
/// La foto aparece en la tira **apenas se saca**, con su indicador encima, y
/// no cuando el servidor responde. En terreno la respuesta puede tardar o no
/// llegar, y una tira que se queda vacía después de apretar el obturador hace
/// que la persona vuelva a sacar la misma foto.
class SgEvidencias extends ConsumerStatefulWidget {
  const SgEvidencias({
    super.key,
    required this.destino,
    required this.destinoId,
    this.obligatoria = false,
    this.puedeAgregar = true,
    this.onCambio,
  });

  /// TAREA · ORDEN · PASO · RESPUESTA · FALLA · HALLAZGO · ACTIVO
  final String destino;

  final int destinoId;

  /// Solo cambia el texto de ayuda. **El veredicto lo pone el servidor**: un
  /// teléfono con la versión vieja cerraría sin foto en silencio si esto fuera
  /// la única comprobación.
  final bool obligatoria;

  final bool puedeAgregar;
  final VoidCallback? onCambio;

  @override
  ConsumerState<SgEvidencias> createState() => _SgEvidenciasState();
}

class _SgEvidenciasState extends ConsumerState<SgEvidencias> {
  /// Las que están viajando ahora. Se muestran junto a las guardadas para que
  /// la tira no parpadee ni se vacíe entre el obturador y la respuesta.
  final List<FotoTomada> _subiendo = [];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final clave = (widget.destino, widget.destinoId);
    final guardadas = ref.watch(evidenciasProvider(clave));

    final fotos = guardadas.valueOrNull ?? const <Evidencia>[];
    final vacio = fotos.isEmpty && _subiendo.isEmpty;

    return SgCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgRotulo(widget.obligatoria ? 'FOTO OBLIGATORIA' : 'FOTOS'),
              const Spacer(),
              if (!vacio)
                Text('${fotos.length + _subiendo.length}',
                    style: sora(12, 600, color: sg.tinta3)),
            ],
          ),
          const SizedBox(height: 10),

          if (vacio)
            Text(
              widget.obligatoria
                  ? 'Esta tarea pide una foto antes de cerrarla.'
                  : 'Una foto ahorra tener que explicar después qué se encontró.',
              style: sora(13, 500,
                  color: widget.obligatoria ? sg.ambarTexto : sg.tinta3,
                  alto: 1.45),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length + _subiendo.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, i) => i < fotos.length
                    ? _Miniatura(ruta: fotos[i].arc_ruta)
                    : _Subiendo(foto: _subiendo[i - fotos.length]),
              ),
            ),

          if (widget.puedeAgregar) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: SgBoton(
                    'Sacar foto',
                    icono: Icons.photo_camera_outlined,
                    alto: 44,
                    tamanoTexto: 14,
                    onTap: () => _agregar(desdeCamara: true),
                  ),
                ),
                const SizedBox(width: 9),
                SgBotonIcono(
                  Icons.photo_library_outlined,
                  lado: 44,
                  onTap: () => _agregar(desdeCamara: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _agregar({required bool desdeCamara}) async {
    final mensajero = ScaffoldMessenger.of(context);
    final servicio = EvidenciaService.instance;

    final foto = desdeCamara ? await servicio.tomar() : await servicio.elegir();
    if (foto == null || !mounted) return;

    setState(() => _subiendo.add(foto));

    try {
      final cuerpo = await servicio.cuerpo(
        foto,
        destino: widget.destino,
        destinoId: widget.destinoId,
      );
      await SigmaRepository.instance.subirEvidencia(cuerpo);

      if (!mounted) return;
      setState(() => _subiendo.remove(foto));
      ref.invalidate(evidenciasProvider((widget.destino, widget.destinoId)));
      widget.onCambio?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _subiendo.remove(foto));
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 92,
        height: 92,
        child: SigmaImagen(
          ruta: ruta,
          ancho: 92,
          alto: 92,
          radio: SgRadius.campo,
        ),
      );
}

/// La que todavía va en camino: se ve la foto real del teléfono con un velo y
/// el indicador encima. Mostrar un recuadro gris en su lugar haría dudar de si
/// se sacó la que se quería.
class _Subiendo extends StatelessWidget {
  const _Subiendo({required this.foto});

  final FotoTomada foto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SgRadius.campo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(foto.archivo.path), fit: BoxFit.cover),
            Container(color: sg.scrim),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: sg.primarioTexto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
