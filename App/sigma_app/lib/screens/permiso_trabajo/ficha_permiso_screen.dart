import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_v3.dart';

/// La ficha de un permiso de trabajo — vista 11.2 del diseño v3.
///
/// ## Para qué se abre
///
/// Para responder una sola pregunta antes de empezar: **¿puedo trabajar?**.
/// Un permiso solicitado y no autorizado significa que no, aunque el equipo
/// esté ahí y la orden asignada. Por eso el estado y la vigencia van arriba y
/// grandes, y lo demás debajo.
///
/// ## Por qué no se edita desde acá
///
/// Autorizar es un acto de quien firma, con el documento a la vista, y el SP
/// no deja que un permiso esté AUTORIZADO sin su adjunto —`CK_PTR_AUTORIZADO`—.
/// Ofrecer el botón en el teléfono sería ofrecer un camino que la base rechaza.
///
/// Lo que **sí** se puede hacer desde el terreno es pedirlo, y eso ya está en
/// `NuevoPermisoScreen`.
class FichaPermisoScreen extends ConsumerWidget {
  const FichaPermisoScreen({
    super.key,
    required this.permisoId,
    this.numeroConocido,
  });

  final int permisoId;

  /// El número que ya traía la tarjeta desde donde se abrió. Se pinta en la
  /// barra mientras baja la ficha.
  final String? numeroConocido;

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final ficha = ref.watch(permisoProvider(permisoId));

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        ficha.valueOrNull?.ptr_numero ?? numeroConocido ?? 'Permiso',
        tamanoTitulo: 20,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(permisoProvider(permisoId)),
          child: ListView(
            padding: context.conBarraSistema(
              const EdgeInsets.fromLTRB(16, 14, 16, 16),
            ),
            children: [
              EstadoAsync<PermisoTrabajo>(
                valor: ficha,
                onReintentar: () => ref.invalidate(permisoProvider(permisoId)),
                child: (p) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Cabecera(permiso: p),
                    const SizedBox(height: 16),
                    _Vigencia(permiso: p, formato: _fecha),

                    /* «0» NO ES UNA ORDEN

                       Un permiso sin OT trae el correlativo en 0, y el bloque
                       se dibujaba igual mostrando un «0» suelto bajo el rótulo
                       «Para qué trabajo». No decía nada y hacía dudar del
                       resto de la ficha. */
                    if (p.tieneOrden) ...[
                      const SizedBox(height: 16),
                      const SgRotulo('Para qué trabajo'),
                      const SizedBox(height: 10),
                      SgCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            SgIconoCuadro(
                              Icons.assignment_outlined,
                              color: sg.primarioTexto,
                              lado: 40,
                              tamanoIcono: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.ORDEN_CORRELATIVO!,
                                    style: sora(15, 600, color: sg.tinta),
                                  ),
                                  if ((p.ORDEN_TITULO ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      p.ORDEN_TITULO!,
                                      style: sora(12, 500, color: sg.tinta3),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SgBloque(
                      rotulo: 'Datos',
                      filas: [
                        SgFila(
                          icono: Icons.category_outlined,
                          texto: 'Tipo',
                          valor: p.TIPO_NOMBRE,
                          colorTexto: sg.tinta2,
                        ),
                        if ((p.SOLICITANTE_NOMBRE ?? '').isNotEmpty)
                          SgFila(
                            icono: Icons.person_outline,
                            texto: 'Lo pidió',
                            valor: p.SOLICITANTE_NOMBRE!,
                            colorTexto: sg.tinta2,
                          ),
                        SgFila(
                          icono: Icons.attach_file,
                          texto: 'Documento firmado',
                          colorTexto: sg.tinta2,
                          /* EL PAPEL ES LA CONSTANCIA, NO LA FILA

                             `CK_PTR_AUTORIZADO` impide que un permiso esté
                             autorizado sin su adjunto, así que decir si está o
                             no es decir si el permiso vale. */
                          derecha: p.TIENE_DOCUMENTO
                              ? SgBadge(
                                  'Adjunto',
                                  color: sg.verdeTexto,
                                  icono: Icons.check,
                                  chico: true,
                                )
                              : SgBadge(
                                  'Sin adjuntar',
                                  color: sg.ambarTexto,
                                  chico: true,
                                ),
                        ),
                      ],
                    ),

                    if ((p.ptr_observacion ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const SgRotulo('Observación'),
                      const SizedBox(height: 10),
                      SgCard(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          p.ptr_observacion!.trim(),
                          style: sora(13, 500, color: sg.tinta2, alto: 1.5),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SgAviso(
                      'Autorizar un permiso se hace con el documento firmado a '
                      'la vista, desde la web.',
                      icono: Icons.info_outline,
                      color: sg.tinta2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El estado, que es lo primero que hay que saber.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.permiso});

  final PermisoTrabajo permiso;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    /* EL COLOR LO DECIDE LA SITUACION, NO EL ESTADO

       Un permiso AUTORIZADO pero VENCIDO no sirve, y pintarlo de verde porque
       su estado dice «autorizado» invita a trabajar con él. `SITUACION` la
       calcula el SP cruzando estado y vigencia, que es donde tiene que
       calcularse. */
    final situacion = (permiso.SITUACION ?? '').toUpperCase();
    final autorizado =
        (permiso.ESTADO_CODIGO ?? '').toUpperCase() == 'AUTORIZADO';

    final (Color color, IconData icono, String frase) = switch (situacion) {
      'VENCIDO' => (
        sg.rojoTexto,
        Icons.block,
        'Este permiso ya venció. No habilita a trabajar.',
      ),
      'POR VENCER' => (
        sg.ambarTexto,
        Icons.schedule,
        'Vence pronto. Si el trabajo se alarga, hay que renovarlo.',
      ),
      _ when autorizado => (
        sg.verdeTexto,
        Icons.verified_outlined,
        'Autorizado y vigente: se puede trabajar.',
      ),
      _ => (
        sg.ambarTexto,
        Icons.hourglass_empty,
        'Todavía no está autorizado. Sin la firma no habilita a trabajar.',
      ),
    };

    return SgCard(
      padding: const EdgeInsets.all(15),
      elegida: true,
      colorAnillo: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgIconoCuadro(icono, color: color, lado: 46, tamanoIcono: 23),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permiso.ESTADO_NOMBRE,
                      style: sora(18, 700, color: color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      permiso.ptr_numero,
                      style: sora(13, 500, color: sg.tinta3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(frase, style: sora(13, 500, color: sg.tinta2, alto: 1.45)),
        ],
      ),
    );
  }
}

/// Desde cuándo y hasta cuándo, y cuánto queda.
class _Vigencia extends StatelessWidget {
  const _Vigencia({required this.permiso, required this.formato});

  final PermisoTrabajo permiso;
  final DateFormat formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final dias = permiso.DIAS_RESTANTES;

    return SgBloque(
      rotulo: 'Vigencia',
      filas: [
        SgFila(
          icono: Icons.play_circle_outline,
          texto: 'Desde',
          colorTexto: sg.tinta2,
          valor: permiso.ptr_fecha_vigencia_inicio_utc == null
              ? 'Sin fecha'
              : formato.format(
                  permiso.ptr_fecha_vigencia_inicio_utc!.toLocal(),
                ),
        ),
        SgFila(
          icono: Icons.stop_circle_outlined,
          texto: 'Hasta',
          colorTexto: sg.tinta2,
          valor: permiso.ptr_fecha_vigencia_fin_utc == null
              ? 'Sin fecha'
              : formato.format(permiso.ptr_fecha_vigencia_fin_utc!.toLocal()),
        ),
        if (dias != null)
          SgFila(
            icono: Icons.timelapse,
            texto: 'Queda',
            colorTexto: sg.tinta2,
            // «Venció hace» y no «-3 días»: un número negativo obliga a
            // interpretarlo, y esto se lee de un vistazo o no se lee.
            valor: dias < 0
                ? 'Venció hace ${-dias} ${-dias == 1 ? 'día' : 'días'}'
                : dias == 0
                ? 'Vence hoy'
                : '$dias ${dias == 1 ? 'día' : 'días'}',
          ),
      ],
    );
  }
}
