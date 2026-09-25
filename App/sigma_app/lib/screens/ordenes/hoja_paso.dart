import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import 'hojas_recursos.dart';

/// Anotar lo que se hizo en una orden — HU-114.
///
/// ## El hueco que tapa
///
/// Una correctiva abierta en terreno **nace sin pasos**: no todo trabajo
/// correctivo viene con una pauta. Hasta ahora eso dejaba al técnico sin ningún
/// sitio donde registrar el trabajo salvo el cuadro de «Resultado» del cierre
/// —una sola caja, al final, cuando ya se olvidó la mitad—.
///
/// Y lo que se pierde ahí no es un trámite: es lo que el turno siguiente
/// necesita para no repetir el diagnóstico, y lo que hace que el historial del
/// activo sirva de algo dentro de un año.
///
/// ## Por qué es un paso y no una nota
///
/// El modelo ya tiene el concepto: una acción con su resultado, su ejecutor y
/// su hora, y `Archivo_Vinculo` sabe colgarle evidencia con destino PASO. Un
/// campo de texto libre en la cabecera sería decir lo mismo sin ejecutor, sin
/// hora y sin fotos.
///
/// ## Nace hecho, no pendiente
///
/// No se está planificando: se está anotando lo que **ya** se hizo, y por eso
/// el resultado viene elegido de entrada. Quien quiera dejar un recordatorio de
/// lo que falta suelta el chip y el paso queda pendiente.
class HojaPaso extends ConsumerStatefulWidget {
  const HojaPaso({super.key, required this.ordenId, required this.ordenNumero});

  final int ordenId;
  final String ordenNumero;

  /// Abre la hoja. Devuelve `true` si quedó anotado.
  static Future<bool> abrir(
    BuildContext context,
    int ordenId,
    String ordenNumero,
  ) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaPaso(ordenId: ordenId, ordenNumero: ordenNumero),
    );
    return r ?? false;
  }

  @override
  ConsumerState<HojaPaso> createState() => _HojaPasoState();
}

class _HojaPasoState extends ConsumerState<HojaPaso> {
  /// 1 CONFORME · 2 NO CONFORME · 3 NO APLICA, como los pasos de pauta.
  static const _resultados = <int, String>{
    1: 'Quedó conforme',
    2: 'No conforme',
    3: 'No aplica',
  };

  final _que = TextEditingController();
  final _detalle = TextEditingController();

  /// Nace al abrir la hoja, no al enviar.
  final String _uuid = OutboxService.nuevoUuid();

  /// Conforme por omisión: lo normal es anotar algo que se hizo y quedó bien.
  int? _resultado = 1;
  bool _guardando = false;

  @override
  void dispose() {
    _que.dispose();
    _detalle.dispose();
    super.dispose();
  }

  bool get _completo => _que.text.trim().isNotEmpty && !_guardando;

  Future<void> _guardar() async {
    if (!_completo) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final texto = _que.text.trim();

    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'PASO',
        titulo: 'Trabajo en ${widget.ordenNumero}',
        detalle: texto,
        endpoint: '${ApiConstants.ordenesTrabajo}/${widget.ordenId}/pasos',
        uuid: _uuid,
        cuerpo: {
          'nombre': texto,
          'resultado': _resultado,
          'observacion': _detalle.text.trim().isEmpty
              ? null
              : _detalle.text.trim(),
        },
      );

      SyncService.instance.despacharAhora();
      ref.invalidate(ordenTrabajoProvider(widget.ordenId));

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Anotado en la orden.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo anotar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return HojaRecurso(
      titulo: 'Qué hiciste',
      detalle:
          'Queda en ${widget.ordenNumero} con tu nombre y la hora. Puedes '
          'anotar varias veces mientras trabajas.',
      children: [
        const SgRotuloCampo('El trabajo'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _que,
          icono: Icons.build_outlined,
          hint: 'Cambié el retén del eje de salida',
          autoenfoque: true,
          lineas: 2,
          conVoz: true,
          onCambio: (_) => setState(() {}),
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Qué hiciste',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'que',
                  rotulo: 'Trabajo',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_que, campos.first.valor));
          },
        ),

        const SizedBox(height: 15),
        const SgRotulo('Cómo quedó'),
        const SizedBox(height: 9),

        /* SE PUEDE SOLTAR, Y ESO SIGNIFICA ALGO

           Sin ninguno elegido el paso queda **pendiente**: sirve para anotar lo
           que falta —«hay que pedir el rodamiento»— sin decir que ya se hizo.
           Por eso volver a tocar el chip elegido lo suelta en vez de no hacer
           nada. */
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _resultados.entries)
              SgChip(
                e.value,
                elegido: _resultado == e.key,
                onTap: () => setState(
                  () => _resultado = _resultado == e.key ? null : e.key,
                ),
              ),
          ],
        ),

        if (_resultado == null) ...[
          const SizedBox(height: 11),
          SgAviso(
            'Sin marcar cómo quedó, se anota como pendiente.',
            icono: Icons.schedule,
            color: sg.tinta2,
          ),
        ],

        const SizedBox(height: 15),
        const SgRotuloCampo('Detalle'),
        const SizedBox(height: 4),
        Text(
          'Opcional. Lo que el turno siguiente necesitaría saber.',
          style: sora(12, 500, color: sg.tinta3, alto: 1.45),
        ),
        const SizedBox(height: 9),
        SgCampo(
          controlador: _detalle,
          icono: Icons.notes,
          hint: 'Vino con la pista rayada, se pidió repuesto',
          lineas: 3,
          conVoz: true,
          onVoz: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: 'Detalle',
              interpretar: (t) => [
                CampoDictado(
                  clave: 'detalle',
                  rotulo: 'Detalle',
                  valor: InterpreteVoz.normalizar(t),
                ),
              ],
            );
            if (campos == null || campos.isEmpty) return;
            setState(() => escribirDictado(_detalle, campos.first.valor));
          },
        ),

        const SizedBox(height: 16),
        SgBoton(
          'Anotar en la orden',
          icono: Icons.check,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ],
    );
  }
}
