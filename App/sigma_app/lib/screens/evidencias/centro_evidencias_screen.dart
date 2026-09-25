import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_reproductor.dart';
import '../../widgets/comun/sigma_v3.dart';

/// La cola, filtrada a lo que es un archivo.
///
/// Se observa aparte de `colaProvider` —el de Pendientes— porque esta pantalla
/// solo mira evidencias, y compartir el provider haría que abrir una
/// invalidara la otra sin necesidad.
final colaEvidenciasProvider = FutureProvider<List<ItemCola>>((ref) async {
  final todo = await OutboxService.instance.listar();
  return todo
      .where((i) => i.tipo == 'EVIDENCIA' && i.estado != EstadoItem.enviado)
      .toList();
});

/// Centro de evidencias — vista 13.2 del diseño v3.
///
/// ## La pregunta que responde
///
/// **«¿Se subieron mis fotos?»**. Hoy la única forma de saberlo es abrir una
/// por una las órdenes, tareas y bitácoras donde se sacaron. Quien fotografió
/// veinte cosas en un turno sin señal no tiene manera de comprobar que
/// llegaron, y se entera de que faltó una cuando alguien se la reclama una
/// semana después.
///
/// ## Por qué las dos listas van juntas
///
/// Arriba lo que **falta por subir**, abajo lo que **ya está**. Separarlas en
/// dos pantallas obligaría a mirar en dos sitios para responder una sola
/// pregunta, y el estado de una foto —en el teléfono o en el servidor— es
/// justamente lo que se viene a averiguar.
///
/// ## Lo que no hace, y por qué
///
/// **No hay barra de progreso por archivo.** La evidencia se manda en un solo
/// POST con el contenido en base64: no hay carga por trozos que se pueda
/// medir, y dibujar una barra que avanza sola sería inventar información. Lo
/// que sí se dice es lo que se sabe de verdad: cuánto pesa, cuántos intentos
/// lleva y qué contestó el servidor la última vez.
///
/// **No se toman fotos desde acá.** Capturar evidencia vive donde se captura
/// —la orden, la tarea, la bitácora—, porque una foto tiene que colgar de algo.
/// Un botón de cámara suelto llenaría el servidor de imágenes que nadie puede
/// explicar.
class CentroEvidenciasScreen extends ConsumerWidget {
  const CentroEvidenciasScreen({super.key});

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final cola = ref.watch(colaEvidenciasProvider);
    final subidas = ref.watch(misEvidenciasProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Mis evidencias', tamanoTitulo: 21),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await OutboxService.instance.despachar();
            ref.invalidate(colaEvidenciasProvider);
            ref.invalidate(misEvidenciasProvider);
          },
          child: ListView(
            padding: context.conBarraSistema(
              const EdgeInsets.fromLTRB(16, 14, 16, 16),
            ),
            children: [
              cola.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SgRotulo(
                            items.length == 1
                                ? 'Falta subir 1'
                                : 'Faltan subir ${items.length}',
                          ),
                          const SizedBox(height: 10),
                          for (final i in items) ...[
                            _EnCola(item: i, formato: _fecha),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
              ),

              const SgRotulo('Ya en el servidor'),
              const SizedBox(height: 10),
              EstadoAsync<List<EvidenciaMia>>(
                valor: subidas,
                onReintentar: () => ref.invalidate(misEvidenciasProvider),
                child: (lista) {
                  if (lista.isEmpty) {
                    return SgAviso(
                      'No subiste evidencias en los últimos 30 días.',
                      icono: Icons.photo_camera_outlined,
                      color: sg.tinta2,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in lista) ...[
                        _Subida(evidencia: e, formato: _fecha),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const SgBarraGestos(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una evidencia que todavía está en el teléfono.
class _EnCola extends ConsumerWidget {
  const _EnCola({required this.item, required this.formato});

  final ItemCola item;
  final DateFormat formato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final rechazada = item.estado == EstadoItem.rechazado;

    return SgCard(
      padding: const EdgeInsets.all(13),
      elegida: rechazada,
      colorAnillo: rechazada ? sg.rojoTexto : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniaturaLocal(id: item.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      style: sora(14, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        formato.format(item.fechaCaptura),
                        if ((item.detalle ?? '').isNotEmpty) item.detalle!,
                      ].join(' · '),
                      style: sora(11, 500, color: sg.tinta3),
                    ),
                    const SizedBox(height: 6),
                    SgBadge(
                      rechazada ? 'Rechazada' : 'En cola',
                      color: rechazada ? sg.rojoTexto : sg.ambarTexto,
                      chico: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          /* EL MOTIVO DEL SERVIDOR, TEXTUAL

             Una evidencia rechazada sin motivo obliga a reintentarla a ciegas.
             El mensaje que devolvió la API es lo único que dice si se arregla
             sola con señal o si hay que hablar con alguien. */
          if (rechazada && (item.ultimoError ?? '').isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: sg.tinte(SgColor.rojo),
                borderRadius: BorderRadius.circular(SgRadius.campo),
              ),
              child: Text(
                item.ultimoError!,
                style: sora(12, 500, color: sg.rojoTexto, alto: 1.4),
              ),
            ),
          ],

          if (item.intentos > 0) ...[
            const SizedBox(height: 8),
            Text(
              item.intentos == 1 ? 'Un intento' : '${item.intentos} intentos',
              style: sora(11, 500, color: sg.tinta3),
            ),
          ],

          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: SgBoton(
                  'Reintentar',
                  icono: Icons.refresh,
                  primario: false,
                  alto: 40,
                  tamanoTexto: 13,
                  onTap: () async {
                    await OutboxService.instance.reintentar(item.id);
                    ref.invalidate(colaEvidenciasProvider);
                    ref.invalidate(misEvidenciasProvider);
                  },
                ),
              ),
              /* DESCARTAR SOLO LO RECHAZADO

                 Una evidencia pendiente se va sola en cuanto haya señal;
                 ofrecer descartarla sería ofrecer perder trabajo por
                 impaciencia. Una rechazada, en cambio, no va a irse nunca:
                 dejarla ahí es ruido que tapa las que sí importan. */
              if (rechazada) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: SgBoton(
                    'Descartar',
                    icono: Icons.delete_outline,
                    primario: false,
                    alto: 40,
                    tamanoTexto: 13,
                    colorTexto: sg.rojoTexto,
                    colorIcono: sg.rojoTexto,
                    onTap: () => _confirmarDescarte(context, ref),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarDescarte(BuildContext context, WidgetRef ref) async {
    final sg = context.sg;

    final si = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        backgroundColor: sg.card,
        title: Text(
          '¿Descartar la evidencia?',
          style: sora(16, 600, color: sg.tinta),
        ),
        content: Text(
          'El archivo se borra del teléfono y no se vuelve a intentar. '
          'Si hace falta, hay que sacarlo de nuevo.',
          style: sora(13, 500, color: sg.tinta2, alto: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: Text('Conservar', style: sora(13, 600, color: sg.tinta2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: Text('Descartar', style: sora(13, 600, color: sg.rojoTexto)),
          ),
        ],
      ),
    );

    if (si != true) return;
    await OutboxService.instance.descartar(item.id);
    ref.invalidate(colaEvidenciasProvider);
  }
}

/// La miniatura de un archivo que sigue en la cola.
///
/// Sale del cuerpo encolado, que trae el archivo en base64. Se pide una sola
/// vez por ítem —`FutureBuilder` sobre un `Future` guardado— porque leer un
/// cuerpo de varios megas en cada repintado dejaría la lista trabada.
class _MiniaturaLocal extends StatefulWidget {
  const _MiniaturaLocal({required this.id});

  final int id;

  @override
  State<_MiniaturaLocal> createState() => _MiniaturaLocalState();
}

class _MiniaturaLocalState extends State<_MiniaturaLocal> {
  late final Future<Uint8List?> _bytes = OutboxService.instance.archivoDe(
    widget.id,
  );

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (_, snap) {
        final datos = snap.data;

        if (datos == null) {
          return SgIconoCuadro(
            snap.connectionState == ConnectionState.waiting
                ? Icons.hourglass_empty
                : Icons.insert_drive_file_outlined,
            color: sg.tinta3,
            lado: 52,
            tamanoIcono: 22,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            datos,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            // Se decodifica al tamaño en que se dibuja: una foto de 4000 px
            // decodificada entera para un cuadro de 52 gasta memoria que en
            // un teléfono de planta hace falta para otra cosa.
            cacheWidth: 156,
            // Un audio o un video no se pueden dibujar: en vez de un cuadro
            // roto, su ícono.
            errorBuilder: (_, _, _) => SgIconoCuadro(
              Icons.mic_none,
              color: sg.tinta3,
              lado: 52,
              tamanoIcono: 22,
            ),
          ),
        );
      },
    );
  }
}

/// Una evidencia que ya está en el servidor.
class _Subida extends StatelessWidget {
  const _Subida({required this.evidencia, required this.formato});

  final EvidenciaMia evidencia;
  final DateFormat formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final e = evidencia;

    return SgCard(
      padding: const EdgeInsets.all(13),
      onTap: e.esImagen
          ? null
          : () => SgReproductor.abrir(
              context,
              ruta: e.ARC_RUTA,
              mime: e.ARC_MIME ?? '',
              titulo: e.ARC_NOMBRE ?? 'Evidencia',
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.esImagen)
            SigmaImagen(ruta: e.ARC_RUTA, ancho: 52, alto: 52, radio: 14)
          else
            SgIconoCuadro(
              e.esVideo
                  ? Icons.play_circle_outline
                  : e.esAudio
                  ? Icons.graphic_eq
                  : Icons.insert_drive_file_outlined,
              color: sg.acentoTexto,
              lado: 52,
              tamanoIcono: 23,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /* DE QUE CUELGA, PRIMERO

                   El nombre del archivo -«IMG_20260908.jpg»- no le dice nada
                   a nadie. Lo que se busca es «la foto de la OT-31», y por eso
                   el registro va arriba y en tinta principal. */
                Text(
                  [
                    e.DESTINO_TIPO ?? '',
                    if ((e.DESTINO_TEXTO ?? '').isNotEmpty) e.DESTINO_TEXTO!,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(14, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (e.FECHA_SUBIDA != null)
                      formato.format(e.FECHA_SUBIDA!.toLocal()),
                    _peso(e.ARC_BYTE),
                    if ((e.CATEGORIA_NOMBRE ?? '').isNotEmpty)
                      e.CATEGORIA_NOMBRE!,
                  ].join(' · '),
                  style: sora(11, 500, color: sg.tinta3),
                ),
                if ((e.DESCRIPCION ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    e.DESCRIPCION!.trim(),
                    style: sora(12, 500, color: sg.tinta2, alto: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.cloud_done_outlined, size: 18, color: sg.verdeTexto),
        ],
      ),
    );
  }

  static String _peso(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
