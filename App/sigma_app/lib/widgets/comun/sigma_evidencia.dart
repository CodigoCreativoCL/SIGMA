import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../services/evidencia_service.dart';
import '../../services/outbox_service.dart';
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

class _SgEvidenciasState extends ConsumerState<SgEvidencias>
    with WidgetsBindingObserver {
  /// Las que están viajando ahora. Se muestran junto a las guardadas para que
  /// la tira no parpadee ni se vacíe entre el obturador y la respuesta.
  final List<FotoTomada> _subiendo = [];

  /// Las que esperan señal en la cola de salida. Se siguen viendo en la tira:
  /// una foto que se saca y desaparece de la pantalla se lee como que no se
  /// guardó, y el técnico la vuelve a sacar.
  final List<FotoTomada> _enCola = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // También al montar: si la app murió con la cámara abierta, vuelve por
    // este camino y no por el de `resumed`.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recuperarPerdida());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _recuperarPerdida();
  }

  /// La foto que Android se quedó a medio camino.
  ///
  /// Mientras la cámara está en primer plano el sistema puede **matar la app**
  /// para liberar memoria. Al volver, el `Future` que esperaba la foto ya no
  /// existe y se veía como que la foto se sacó y desapareció del panel — que
  /// es exactamente lo que se reportó desde terreno.
  ///
  /// La foto sí quedó en disco: lo único que se perdió fue quién la esperaba.
  Future<void> _recuperarPerdida() async {
    final foto = await EvidenciaService.instance.recuperarPerdida();
    if (foto == null || !mounted) return;

    await _subir(foto);
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final clave = (widget.destino, widget.destinoId);
    final guardadas = ref.watch(evidenciasProvider(clave));

    final fotos = guardadas.valueOrNull ?? const <Evidencia>[];
    final vacio = fotos.isEmpty && _subiendo.isEmpty && _enCola.isEmpty;

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
                Text('${fotos.length + _subiendo.length + _enCola.length}',
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
                itemCount: fotos.length + _subiendo.length + _enCola.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, i) {
                  if (i < fotos.length) {
                    return _Miniatura(ruta: fotos[i].arc_ruta);
                  }
                  final j = i - fotos.length;
                  return j < _subiendo.length
                      ? _Subiendo(foto: _subiendo[j])
                      : _EnCola(foto: _enCola[j - _subiendo.length]);
                },
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
    final servicio = EvidenciaService.instance;

    final foto = desdeCamara ? await servicio.tomar() : await servicio.elegir();
    if (foto == null || !mounted) return;

    await _subir(foto);
  }

  /// Sube la foto, o la encola si no hay señal.
  ///
  /// Está separado de [_agregar] porque hay **dos formas de llegar acá**: la
  /// normal —se sacó la foto y el `Future` volvió— y la recuperada, cuando
  /// Android mató la app con la cámara abierta. Las dos terminan igual, y
  /// duplicar este camino sería duplicar también el encolado sin señal.
  Future<void> _subir(FotoTomada foto) async {
    final mensajero = ScaffoldMessenger.of(context);
    final servicio = EvidenciaService.instance;

    setState(() => _subiendo.add(foto));

    final cuerpo = await servicio.cuerpo(
      foto,
      destino: widget.destino,
      destinoId: widget.destinoId,
    );

    try {
      await SigmaRepository.instance.subirEvidencia(cuerpo);

      if (!mounted) return;
      setState(() => _subiendo.remove(foto));
      ref.invalidate(evidenciasProvider((widget.destino, widget.destinoId)));
      widget.onCambio?.call();
    } on ApiException catch (e) {
      if (!mounted) return;

      /* SIN SEÑAL LA FOTO NO SE PIERDE: SE ENCOLA

         Antes se mostraba «Sin conexión al servidor» y la foto se descartaba.
         En una sala de máquinas eso es el caso NORMAL, no el excepcional, y
         significaba pedirle al técnico que volviera a bajar a sacarla.

         El cuerpo ya viaja en base64 justamente para esto —lo dice
         `EvidenciaService`: un multipart no se puede encolar—, y la foto lleva
         su `uuid` desde que se saca, asi que el reintento no la duplica.

         Solo la falla de RED se encola. Un 403 —no tienes permiso sobre este
         destino— no mejora reintentando, y guardarlo en la cola seria dejar
         algo que va a fallar para siempre. */
      if (!e.esDeRed) {
        setState(() => _subiendo.remove(foto));
        mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
        return;
      }

      await OutboxService.instance.encolar(
        tipo: 'EVIDENCIA',
        titulo: 'Foto de ${widget.destino.toLowerCase()}',
        detalle: '${(foto.bytes / 1024).round()} KB',
        endpoint: ApiConstants.evidencias,
        cuerpo: cuerpo,
        uuid: foto.uuid,
      );

      if (!mounted) return;
      setState(() {
        _subiendo.remove(foto);
        _enCola.add(foto);
      });
      mensajero.showSnackBar(const SnackBar(
          content: Text('Sin señal: la foto queda guardada y se envía sola.')));
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
/// Una foto que ya está en el teléfono y espera señal para salir.
///
/// Se ve **la foto**, no un marcador: lo que hay que poder comprobar en
/// terreno es que la foto salió bien, y eso no se puede con un ícono. El
/// distintivo de la esquina dice que todavía no llegó al servidor, sin
/// pintarla de rojo: quedarse sin señal no es un error de quien la sacó.
class _EnCola extends StatelessWidget {
  const _EnCola({required this.foto});

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
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sg.scrim,
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 12, color: sg.tinta2),
                    const SizedBox(width: 4),
                    Text('En cola', style: sora(10, 600, color: sg.tinta2)),
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
