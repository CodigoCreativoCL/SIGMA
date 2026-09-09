import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/outbox_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'pendientes_screen.dart' show colaProvider;

/// Conflicto de sincronización — vista 15.2 del diseño v3.
///
/// ## Qué es un conflicto en SIGMA, y qué no
///
/// La especificación pide comparar «versión local» contra «versión del
/// servidor». **SIGMA no versiona registros**: no hay columna de versión ni
/// bloqueo optimista, así que una comparación campo a campo entre dos
/// versiones del mismo registro no se puede hacer sin mentir. Decirlo importa
/// más que dibujar una pantalla bonita sobre datos que no existen.
///
/// Lo que sí existe, y es el conflicto real que se ve en terreno:
///
/// **El servidor se movió mientras el teléfono estaba sin señal.** Se capturó
/// una lectura, una bitácora o un movimiento; al enviarlo, el servidor lo
/// rechaza porque su estado ya no admite eso: la orden la cerró otro, el
/// contador ya pasó ese valor, el permiso venció. El ítem queda **rechazado**
/// —no pendiente— porque reintentarlo no lo arregla.
///
/// Esta pantalla pone lo capturado frente a lo que contestó el servidor, y
/// deja decidir.
///
/// ## Por qué el 409 no llega acá
///
/// Porque no es un conflicto: es el reintento que llegó dos veces. El servidor
/// ya tenía exactamente eso, con el mismo `uuid`, así que la cola lo marca
/// como enviado. Es literalmente el «no mostrar conflicto si los datos son
/// equivalentes» que pide la especificación, resuelto antes de que nadie tenga
/// que mirarlo.
///
/// ## Las opciones, y por qué son dos
///
/// **Reintentar** sirve cuando lo que bloqueaba se arregló —alguien reabrió la
/// orden, se renovó el permiso—. **Descartar** sirve cuando el trabajo ya no
/// aplica. No hay «editar y reenviar»: cambiar acá el valor de una lectura
/// capturada en terreno convertiría el registro en algo que nadie midió, y ese
/// registro es el que después se audita.
class ConflictoScreen extends ConsumerStatefulWidget {
  const ConflictoScreen({super.key, required this.item});

  final ItemCola item;

  @override
  ConsumerState<ConflictoScreen> createState() => _ConflictoScreenState();
}

class _ConflictoScreenState extends ConsumerState<ConflictoScreen> {
  late final Future<Map<String, dynamic>?> _datos = OutboxService.instance
      .datosDe(widget.item.id);

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  bool _trabajando = false;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final i = widget.item;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('No se pudo guardar', tamanoTitulo: 20),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: context.conBarraSistema(
            const EdgeInsets.fromLTRB(16, 14, 16, 16),
          ),
          children: [
            SgCard(
              padding: const EdgeInsets.all(15),
              elegida: true,
              colorAnillo: sg.rojoTexto,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SgIconoCuadro(
                    Icons.sync_problem,
                    color: sg.rojoTexto,
                    lado: 46,
                    tamanoIcono: 23,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.titulo, style: sora(15, 600, color: sg.tinta)),
                        const SizedBox(height: 4),
                        Text(
                          'Capturado el ${_fecha.format(i.fechaCaptura)}',
                          style: sora(12, 500, color: sg.tinta3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const SgRotulo('Lo que dice el servidor'),
            const SizedBox(height: 10),
            SgCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sg.tinte(SgColor.rojo),
                      borderRadius: BorderRadius.circular(SgRadius.campo),
                    ),
                    /* EL MENSAJE DEL SERVIDOR, TEXTUAL Y COMPLETO

                       Es lo único que dice si esto se arregla solo, si hay que
                       hablar con alguien o si ya no aplica. Resumirlo o
                       traducirlo a «hubo un problema» borra justamente el dato
                       por el que se abre esta pantalla. */
                    child: Text(
                      (i.ultimoError ?? '').trim().isEmpty
                          ? 'El servidor rechazó el envío sin dar un motivo.'
                          : i.ultimoError!.trim(),
                      style: sora(13, 500, color: sg.rojoTexto, alto: 1.45),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SgBloque(
                    filas: [
                      if (i.ultimoCodigo != null)
                        SgFila(
                          icono: Icons.tag,
                          texto: 'Código',
                          valor: '${i.ultimoCodigo}',
                          detalle: _queSignifica(i.ultimoCodigo!),
                          colorTexto: sg.tinta2,
                        ),
                      SgFila(
                        icono: Icons.replay,
                        texto: 'Intentos',
                        valor: '${i.intentos}',
                        colorTexto: sg.tinta2,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const SgRotulo('Lo que capturaste'),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>?>(
              future: _datos,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return SgCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Leyendo lo guardado…',
                      style: sora(13, 500, color: sg.tinta3),
                    ),
                  );
                }

                final datos = snap.data;
                if (datos == null || datos.isEmpty) {
                  return SgAviso(
                    'No se pudo leer lo capturado. El envío sigue guardado.',
                    icono: Icons.help_outline,
                    color: sg.tinta2,
                  );
                }

                final filas = _filas(datos);
                if (filas.isEmpty) {
                  return SgAviso(
                    'El envío no trae campos que se puedan mostrar.',
                    icono: Icons.help_outline,
                    color: sg.tinta2,
                  );
                }

                return SgBloque(filas: filas);
              },
            ),

            const SizedBox(height: 20),
            SgBoton(
              'Reintentar el envío',
              icono: Icons.refresh,
              cargando: _trabajando,
              onTap: _reintentar,
            ),
            const SizedBox(height: 10),
            SgBoton(
              'Descartar',
              icono: Icons.delete_outline,
              primario: false,
              colorTexto: sg.rojoTexto,
              colorIcono: sg.rojoTexto,
              onTap: _descartar,
            ),
            const SizedBox(height: 12),
            SgAviso(
              'Descartar borra el envío del teléfono. Lo capturado no se '
              'recupera: si sigue haciendo falta, hay que registrarlo de '
              'nuevo.',
              icono: Icons.info_outline,
              color: sg.tinta3,
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }

  /// Qué significa el código, en palabras de quien está mirando.
  ///
  /// No es decoración: el número solo le dice algo a quien programó la API, y
  /// lo que cambia la decisión —«esto se arregla solo» contra «esto ya no va a
  /// entrar nunca»— es exactamente esto.
  String _queSignifica(int codigo) => switch (codigo) {
    400 => 'Faltaba un dato o no era válido',
    403 => 'Tu perfil no puede hacer esto',
    404 => 'El registro ya no existe en el servidor',
    409 => 'El servidor ya lo tenía',
    422 => 'Una regla del negocio lo impide',
    _ => 'Rechazado por el servidor',
  };

  /// Los campos del envío, con nombres que se entiendan.
  ///
  /// Se muestran solo los que significan algo para una persona: el `uuid` y
  /// los ids internos son la fontanería de la cola y llenarían la pantalla de
  /// números que no ayudan a decidir nada.
  List<SgFila> _filas(Map<String, dynamic> datos) {
    const rotulos = {
      'valor_acumulado': 'Valor',
      'fecha_lectura_utc': 'Fecha de la lectura',
      'observacion': 'Observación',
      'titulo': 'Título',
      'texto': 'Texto',
      'cantidad': 'Cantidad',
      'motivo': 'Motivo',
      'numero': 'Número',
      'resultado': 'Resultado',
      'destino': 'Cuelga de',
      'nombre': 'Archivo',
      'mime': 'Tipo',
      'captura_utc': 'Capturado',
      '_bytes_archivo': 'Tamaño',
    };

    final sg = context.sg;
    final filas = <SgFila>[];

    for (final entrada in rotulos.entries) {
      final v = datos[entrada.key];
      if (v == null) continue;

      final texto = entrada.key == '_bytes_archivo'
          ? _peso(v is num ? v.toInt() : 0)
          : '$v'.trim();
      if (texto.isEmpty) continue;

      filas.add(
        SgFila(texto: entrada.value, valor: texto, colorTexto: sg.tinta2),
      );
    }

    return filas;
  }

  static String _peso(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _reintentar() async {
    setState(() => _trabajando = true);
    await OutboxService.instance.reintentar(widget.item.id);
    if (!mounted) return;
    ref.invalidate(colaProvider);
    Navigator.pop(context);
  }

  Future<void> _descartar() async {
    final sg = context.sg;

    final si = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        backgroundColor: sg.card,
        title: Text(
          '¿Descartar el envío?',
          style: sora(16, 600, color: sg.tinta),
        ),
        content: Text(
          'Lo capturado se borra del teléfono y no se vuelve a intentar.',
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

    if (si != true || !mounted) return;

    await OutboxService.instance.descartar(widget.item.id);
    if (!mounted) return;
    ref.invalidate(colaProvider);
    Navigator.pop(context);
  }
}
