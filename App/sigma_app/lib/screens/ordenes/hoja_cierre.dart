import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/api_constants.dart';
import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';
import 'hojas_recursos.dart';

/// Cerrar una orden de trabajo — HU-120.
///
/// ## Finalizar y cerrar no son lo mismo
///
/// El técnico **finaliza** y la orden queda en espera de cierre. **Cerrarla**
/// es del jefe de mantenimiento, el supervisor o el planificador: que el que
/// ejecuta no sea el que certifica es lo que hace que el registro valga como
/// respaldo. Por eso esta hoja solo se abre desde el botón que aparece con
/// `CERRAR OT`, y por eso el servidor lo vuelve a comprobar —esconder un botón
/// no impide llamar al endpoint—.
///
/// ## El motivo es un chip, no un texto libre
///
/// «Trabajo realizado» escrito de cinco formas distintas no agrupa en ningún
/// informe, y la pregunta que la planta le hace al sistema —de cien órdenes,
/// cuántas cerraron sin hallazgo— deja de tener respuesta. Los motivos bajan
/// del servidor: son un dato de la empresa y se habilitan desde la web, así
/// que una lista escrita acá obligaría a publicar una versión nueva de la app
/// cada vez que cambie.
///
/// ## La observación es libre y opcional
///
/// El motivo dice de qué tipo fue el cierre; la observación dice **qué pasó**,
/// y eso no cabe en un catálogo. Opcional porque exigirla en los casos obvios
/// —cerrar una duplicada— enseña a escribir «ok» para pasar el trámite, que es
/// peor que no escribir nada.
///
/// ## Se encola
///
/// Un supervisor cierra donde esté, y donde esté puede no haber señal. El
/// `uuid` nace **al abrir la hoja** y `UPD_ORDEN_TRABAJO_CERRAR` corta por él
/// antes de validar, así que el reintento de un cierre que sí entró responde
/// lo mismo en vez de fallar con «la OT no está en espera de cierre» — es
/// decir, en vez de fallar por haber funcionado.
class HojaCierre extends ConsumerStatefulWidget {
  const HojaCierre({super.key, required this.orden});

  final OrdenTrabajo orden;

  /// Abre la hoja. Devuelve `true` si el cierre quedó encolado.
  static Future<bool> abrir(BuildContext context, OrdenTrabajo orden) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaCierre(orden: orden),
    );
    return r ?? false;
  }

  @override
  ConsumerState<HojaCierre> createState() => _HojaCierreState();
}

class _HojaCierreState extends ConsumerState<HojaCierre> {
  final _observacion = TextEditingController();

  /// Nace **al abrir la hoja**, no al enviar. Generado al enviar, cada
  /// reintento traería uno nuevo y la idempotencia no serviría de nada — que
  /// es justo el caso del timeout, donde el servidor sí cerró pero la
  /// respuesta no llegó.
  final String _uuid = OutboxService.nuevoUuid();

  int? _motivo;
  bool _guardando = false;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool get _completo => _motivo != null && !_guardando;

  Future<void> _cerrar(List<CierreMotivo> motivos) async {
    if (!_completo) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final nombre = motivos
        .firstWhere(
          (m) => m.ocm_id == _motivo,
          orElse: () => const CierreMotivo(ocm_id: 0, ocm_nombre: ''),
        )
        .ocm_nombre;
    final texto = _observacion.text.trim();

    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'CIERRE_OT',
        titulo: 'Cierre de ${widget.orden.OT_NUMERO}',
        detalle: [nombre, texto].where((s) => s.isNotEmpty).join(' · '),
        endpoint:
            '${ApiConstants.ordenesTrabajo}/${widget.orden.otr_id}/cerrar',
        uuid: _uuid,
        cuerpo: {
          'motivo': _motivo,
          'observacion': texto.isEmpty ? null : texto,
        },
      );

      SyncService.instance.despacharAhora();
      if (!mounted) return;
      ref.invalidate(ordenTrabajoProvider(widget.orden.otr_id));
      ref.invalidate(ordenesTrabajoProvider);

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Orden cerrada.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo cerrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final motivos = ref.watch(motivosCierreProvider);

    return HojaRecurso(
      titulo: 'Cerrar la orden',
      detalle: '${widget.orden.OT_NUMERO} · ${widget.orden.otr_titulo}',
      children: [
        const SgRotuloCampo('Por qué se cierra'),
        const SizedBox(height: 8),

        /* LOS MOTIVOS BAJAN DEL SERVIDOR

           Si no se pudieron traer, la hoja lo dice y no ofrece cerrar: elegir
           un motivo de una lista quemada en el teléfono terminaría en un
           rechazo del SP —«el motivo de cierre no existe»— que el supervisor
           no sabría cómo corregir. */
        EstadoAsync<List<CierreMotivo>>(
          valor: motivos,
          onReintentar: () => ref.invalidate(motivosCierreProvider),
          child: (lista) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in lista)
                    SgChip(
                      m.ocm_nombre,
                      elegido: _motivo == m.ocm_id,
                      onTap: () => setState(() => _motivo = m.ocm_id),
                    ),
                ],
              ),

              const SizedBox(height: 15),
              const SgRotuloCampo('Observación'),
              const SizedBox(height: 4),
              Text(
                'Opcional. El motivo dice de qué tipo fue el cierre; acá va '
                'qué pasó.',
                style: sora(12, 500, color: sg.tinta3, alto: 1.45),
              ),
              const SizedBox(height: 9),
              SgCampo(
                controlador: _observacion,
                icono: Icons.notes,
                hint: 'Se cambió el rodamiento y quedó operativo',
                lineas: 3,
                conVoz: true,
                onVoz: () async {
                  final campos = await mostrarPanelVoz(
                    context,
                    titulo: 'Observación del cierre',
                    interpretar: (t) => [
                      CampoDictado(
                        clave: 'observacion',
                        rotulo: 'Observación',
                        valor: InterpreteVoz.normalizar(t),
                      ),
                    ],
                  );
                  if (campos == null || campos.isEmpty) return;
                  setState(
                    () => escribirDictado(_observacion, campos.first.valor),
                  );
                },
              ),

              /* EL CIERRE NO SE DESHACE

                 Volver una OT cerrada a ejecución no existe en SIGMA, así que
                 conviene decirlo antes y no después. */
              const SizedBox(height: 14),
              SgAviso(
                'Una vez cerrada, la orden no vuelve a ejecución.',
                icono: Icons.lock_outline,
                color: sg.ambarTexto,
              ),

              const SizedBox(height: 16),
              SgBoton(
                'Cerrar la orden',
                icono: Icons.check_circle_outline,
                cargando: _guardando,
                onTap: _completo ? () => _cerrar(lista) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
