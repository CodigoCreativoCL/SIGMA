import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_firma.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import 'hojas_recursos.dart';

/// El bloque de firmas de una orden — vista 6.7 (HU-118).
///
/// ## Por qué va en el Resumen y no en una pestaña propia
///
/// Porque se mira junto al estado de la orden: la pregunta «¿quién validó
/// esto?» aparece cuando se está decidiendo si cerrarla, no como un capítulo
/// aparte. Una cuarta pestaña además dejaría las cuatro apretadas en un
/// teléfono de 5 pulgadas.
class BloqueFirmas extends ConsumerWidget {
  const BloqueFirmas({super.key, required this.ordenId});

  final int ordenId;

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final firmas = ref.watch(validacionesProvider(ordenId));
    final puedeFirmar = ref.watch(
      tienePermisoProvider('VALIDAR ORDEN TRABAJO'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sin el permiso no se ofrece la acción. Esconderla no autoriza nada
        // -el servidor vuelve a exigir VALIDAR ORDEN TRABAJO-, solo evita
        // ofrecer un camino que termina en un 403 que nadie puede corregir
        // desde el teléfono.
        if (puedeFirmar)
          SgRotuloConAccion(
            'Firmas',
            accion: 'Firmar',
            onTap: () => HojaFirma.abrir(context, ordenId: ordenId),
          )
        else
          const SgRotulo('Firmas'),
        const SizedBox(height: 10),
        firmas.when(
          loading: () => SgCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Buscando las firmas…',
              style: sora(13, 500, color: sg.tinta3),
            ),
          ),
          error: (_, _) => SgAviso(
            'No se pudieron traer las firmas.',
            icono: Icons.cloud_off,
            color: sg.tinta2,
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return SgAviso(
                puedeFirmar
                    ? 'Nadie ha firmado esta orden todavía.'
                    : 'Nadie ha firmado esta orden todavía. Firmar es de '
                          'quien responde por el cierre.',
                icono: Icons.draw_outlined,
                color: sg.tinta2,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lista.length; i++) ...[
                  _Firma(
                    validacion: lista[i],
                    // La primera es la vigente: el SP las devuelve de la más
                    // nueva a la más vieja, y cuando hay dos del mismo tipo la
                    // que manda es la última. Las anteriores se ven atenuadas,
                    // porque siguen siendo parte del expediente pero ya no son
                    // la que vale.
                    vigente: i == 0,
                    formato: _fecha,
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Firma extends StatelessWidget {
  const _Firma({
    required this.validacion,
    required this.vigente,
    required this.formato,
  });

  final Validacion validacion;
  final bool vigente;
  final DateFormat formato;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final v = validacion;
    final color = v.aprobada ? sg.verdeTexto : sg.rojoTexto;

    return Opacity(
      opacity: vigente ? 1 : 0.55,
      child: SgCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SgIconoCuadro(
                  v.aprobada ? Icons.verified_outlined : Icons.gpp_bad_outlined,
                  color: color,
                  lado: 42,
                  tamanoIcono: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.TIPO_NOMBRE ?? 'Validación',
                        style: sora(14, 600, color: sg.tinta),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          v.USUARIO_NOMBRE ?? '',
                          if ((v.USUARIO_IDENTIFICADOR ?? '').isNotEmpty)
                            v.USUARIO_IDENTIFICADOR!,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: sora(11, 500, color: sg.tinta3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SgBadge(
                  v.aprobada ? 'Aprobada' : 'Rechazada',
                  color: color,
                  chico: true,
                ),
              ],
            ),
            if ((v.FIRMA_RUTA ?? '').isNotEmpty) ...[
              const SizedBox(height: 11),
              /* LA FIRMA SOBRE FONDO CLARO, SIEMPRE

                 El PNG es un trazo negro sobre transparente. En modo oscuro,
                 puesto sobre la tarjeta, no se vería nada. El recuadro claro
                 no es decoración: es el papel. */
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(SgRadius.campo),
                ),
                child: SigmaImagen(
                  ruta: v.FIRMA_RUTA,
                  alto: 90,
                  ajuste: BoxFit.contain,
                  radio: SgRadius.campo,
                ),
              ),
            ],
            if ((v.OTV_OBSERVACION ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                v.OTV_OBSERVACION!.trim(),
                style: sora(12, 500, color: sg.tinta2, alto: 1.45),
              ),
            ],
            if (v.OTV_FECHA_UTC != null) ...[
              const SizedBox(height: 8),
              Text(
                formato.format(v.OTV_FECHA_UTC!.toLocal()),
                style: sora(11, 500, color: sg.tinta3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La hoja de firma.
///
/// ## Por qué el rechazo exige motivo
///
/// Un rechazo sin motivo obliga a ir a preguntarle a quien firmó, y en un
/// turno de noche esa persona ya se fue. **La regla la hace cumplir el SP**
/// —`API_INS_ORDEN_TRABAJO_VALIDACION` devuelve 400 sin observación—; acá se
/// pide antes solo para no encolar algo que va a rebotar.
///
/// ## Por qué el dibujo es opcional
///
/// Lo que siempre queda registrado es **quién** firmó y **cuándo**, y eso sale
/// del token y del reloj del servidor, no de la pantalla. El dibujo es prueba
/// adicional. Exigirlo dejaría sin firmar a quien esté con guantes gruesos, que
/// es la mitad de la planta.
class HojaFirma extends ConsumerStatefulWidget {
  const HojaFirma({super.key, required this.ordenId});

  final int ordenId;

  static Future<void> abrir(BuildContext context, {required int ordenId}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HojaFirma(ordenId: ordenId),
      );

  @override
  ConsumerState<HojaFirma> createState() => _HojaFirmaState();
}

class _HojaFirmaState extends ConsumerState<HojaFirma> {
  final _firma = ControladorFirma();
  final _observacion = TextEditingController();

  int? _tipo;
  bool _aprobada = true;
  bool _guardando = false;
  String? _error;

  /// El tamaño del recuadro, para exportar el PNG con la misma forma que se
  /// dibujó. Con otra proporción la firma saldría estirada.
  static const _tamanoFirma = Size(320, 190);

  @override
  void dispose() {
    _firma.dispose();
    _observacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tipos = ref.watch(tiposValidacionProvider);

    return HojaRecurso(
      titulo: 'Firmar la orden',
      detalle: 'Queda registrado quién firma y cuándo',
      children: [
        const SgRotuloCampo('Tipo de validación', obligatorio: true),
        const SizedBox(height: 8),
        tipos.when(
          loading: () =>
              Text('Cargando…', style: sora(12, 500, color: sg.tinta3)),
          error: (_, _) => SgAviso(
            'No se pudo traer el catálogo. Hace falta señal para firmar.',
            icono: Icons.cloud_off,
            color: sg.ambarTexto,
          ),
          data: (lista) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in lista)
                SgChip(
                  t.nombre,
                  elegido: _tipo == t.id,
                  onTap: () => setState(() => _tipo = t.id),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const SgRotuloCampo('Resultado', obligatorio: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SgChip(
                'Aprobada',
                elegido: _aprobada,
                onTap: () => setState(() => _aprobada = true),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SgChip(
                'Rechazada',
                elegido: !_aprobada,
                onTap: () => setState(() => _aprobada = false),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        SgRotuloCampo(
          _aprobada ? 'Observación' : 'Motivo del rechazo',
          obligatorio: !_aprobada,
        ),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _observacion,
          hint: _aprobada
              ? 'Opcional'
              : 'Por qué se rechaza. Sin esto no se puede firmar.',
          lineas: 3,
        ),

        const SizedBox(height: 16),
        const SgRotuloCampo('Firma'),
        const SizedBox(height: 8),
        SgFirma(controlador: _firma, alto: _tamanoFirma.height),

        if (_error != null) ...[
          const SizedBox(height: 12),
          SgAviso(_error!, icono: Icons.error_outline, color: sg.rojoTexto),
        ],

        const SizedBox(height: 16),
        SgBoton(
          'Firmar',
          icono: Icons.draw_outlined,
          cargando: _guardando,
          onTap: _guardar,
        ),
        const SizedBox(height: 10),
        Text(
          'La firma se guarda en el teléfono y se envía cuando haya señal.',
          textAlign: TextAlign.center,
          style: sora(11, 500, color: sg.tinta3),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _guardar() async {
    final observacion = _observacion.text.trim();

    if (_tipo == null) {
      setState(() => _error = 'Elige el tipo de validación.');
      return;
    }

    // La misma regla que el SP, pedida antes: encolar algo que va a rebotar
    // deja al técnico creyendo que firmó.
    if (!_aprobada && observacion.isEmpty) {
      setState(() => _error = 'Un rechazo tiene que decir por qué.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final png = await _firma.aPng(_tamanoFirma);

    await SigmaRepository.instance.firmarOrden(
      widget.ordenId,
      tipo: _tipo!,
      aprobada: _aprobada,
      observacion: observacion.isEmpty ? null : observacion,
      firmaBase64: png == null ? null : base64Encode(png),
    );

    if (!mounted) return;

    ref.invalidate(validacionesProvider(widget.ordenId));
    Navigator.pop(context);
  }
}
