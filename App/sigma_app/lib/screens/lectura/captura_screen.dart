import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_evidencia.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// Qué se está capturando.
enum TipoCaptura {
  /// La lectura de un medidor acumulativo: horómetro, contador de ciclos.
  lectura,

  /// Una medición de condición: vibración, temperatura, espesor.
  medicion,
}

/// Captura en terreno — HU-044 y la lectura de medidor.
///
/// Toma el layout de **6.4 «Ejecución de pasos»** del kit, que es exactamente
/// esta interacción: un valor grande con su unidad, el aviso de rango, la
/// observación dictable, las fotos y un botón de cierre.
///
/// ## No hay sensores
///
/// **El valor lo toma una persona delante del equipo.** No hay telemetría en
/// SIGMA: por eso la pantalla se diseña para el pulgar y el guante —campo de
/// 64, teclado numérico, micrófono— y no para recibir un dato que llega solo.
///
/// ## Se guarda primero y se envía después
///
/// El botón confirma contra **lo que ya está en disco**, no contra la
/// respuesta del servidor. Hacer esperar al técnico a que responda la red para
/// decirle «guardado» convierte una app offline-first en una online que a
/// veces funciona — y en una sala de máquinas no hay señal casi nunca.
///
/// El `uuid` se genera **al encolar**, no al enviar: generado al enviar, cada
/// reintento traería uno nuevo y el servidor grabaría la misma lectura dos
/// veces justo en el caso del timeout, que es donde más pasa.
class CapturaScreen extends ConsumerStatefulWidget {
  const CapturaScreen({
    super.key,
    required this.tipo,
    required this.activoId,
    required this.activoNombre,
    this.activoCodigo,
    this.ubicacion,
    this.medidorId,
    this.medidorNombre,
    this.unidad,
    this.valorAnterior,
    this.permiteReinicio = false,
    this.minimoEsperado,
    this.maximoEsperado,
  });

  final TipoCaptura tipo;
  final int activoId;
  final String activoNombre;
  final String? activoCodigo;
  final String? ubicacion;

  final int? medidorId;
  final String? medidorNombre;
  final String? unidad;

  /// El último valor conocido. En un medidor acumulativo, **la lectura nueva
  /// no puede ser menor** salvo que el medidor se haya reiniciado.
  final double? valorAnterior;
  final bool permiteReinicio;

  /// El rango esperado de una medición de condición.
  final double? minimoEsperado;
  final double? maximoEsperado;

  @override
  ConsumerState<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends ConsumerState<CapturaScreen> {
  final _valor = TextEditingController();
  final _observacion = TextEditingController();

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  DateTime _cuando = DateTime.now();
  bool _esReinicio = false;
  bool _guardando = false;
  bool _porVoz = false;

  @override
  void dispose() {
    _valor.dispose();
    _observacion.dispose();
    super.dispose();
  }

  double? get _numero =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.'));

  /// Lo que hay que decirle a la persona **antes** de que guarde.
  ///
  /// Se separa en dos: lo que impide guardar y lo que solo advierte. Un valor
  /// fuera de rango es justamente lo que hay que poder registrar —es el
  /// hallazgo—; una lectura menor que la anterior sin reinicio, en cambio, es
  /// casi siempre un error de tecleo.
  String? get _bloqueo {
    final n = _numero;
    if (n == null) return null;
    if (widget.tipo == TipoCaptura.lectura &&
        widget.valorAnterior != null &&
        n < widget.valorAnterior! &&
        !_esReinicio) {
      final ant = NumberFormat.decimalPattern('es_CL').format(widget.valorAnterior);
      return 'La lectura anterior era $ant. Un medidor acumulativo no baja: '
          'revisa el número o marca que el medidor se reinició.';
    }
    return null;
  }

  String? get _aviso {
    final n = _numero;
    if (n == null || widget.tipo != TipoCaptura.medicion) return null;
    final min = widget.minimoEsperado;
    final max = widget.maximoEsperado;
    if (min == null && max == null) return null;
    if ((min != null && n < min) || (max != null && n > max)) {
      final f = NumberFormat.decimalPattern('es_CL');
      return 'Fuera de rango. Esperado ${f.format(min ?? 0)} – ${f.format(max ?? 0)}'
          '${widget.unidad == null ? '' : ' ${widget.unidad}'}.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final n = _numero;
    if (n == null || _bloqueo != null || _guardando) return;

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);

    final esLectura = widget.tipo == TipoCaptura.lectura;
    final que = esLectura
        ? (widget.medidorNombre ?? 'Lectura de medidor')
        : 'Medición de condición';

    try {
      await OutboxService.instance.encolar(
        tipo: esLectura ? 'LECTURA' : 'MEDICION',
        titulo: '$que · ${widget.activoCodigo ?? widget.activoNombre}',
        detalle: '${_valor.text.trim()}${widget.unidad == null ? '' : ' ${widget.unidad}'}',
        endpoint: esLectura ? ApiConstants.lecturas : ApiConstants.mediciones,
        cuerpo: {
          'act_id': widget.activoId,
          if (esLectura) 'ame_id': widget.medidorId,
          'valor': n,
          // La fecha del evento la elige la persona: puede estar registrando
          // una lectura que tomó hace dos horas, cuando no tenía el teléfono.
          'fecha_evento': _cuando.toUtc().toIso8601String(),
          if (esLectura) 'es_reinicio': _esReinicio,
          if (_observacion.text.trim().isNotEmpty)
            'observacion': _observacion.text.trim(),
          // Queda el rastro de cómo se ingresó: una cifra dictada y una
          // tecleada no se auditan igual.
          'origen': _porVoz ? 'VOZ' : 'MANUAL',
        },
      );

      // Se intenta enviar sin que la pantalla espere.
      SyncService.instance.despacharAhora();

      mensajero.showSnackBar(SnackBar(
        content: Text(SyncService.instance.enLinea.value
            ? 'Guardado y enviado.'
            : 'Guardado en el teléfono. Se envía al volver la señal.'),
      ));
      navegador.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
          SnackBar(content: Text('No se pudo guardar en el teléfono: $e')));
    }
  }

  /// Reparte por `clave` lo que devolvió el panel de voz.
  ///
  /// El micrófono del pie captura la frase entera —«vibración 8 coma 4, ruido
  /// en el acople»— y de ahí salen **dos** campos. Repartirlos acá y no en el
  /// widget es lo que permite que la misma frase llene el valor y la
  /// observación de una vez, que es como se habla delante del equipo.
  void _aplicarDictado(List<CampoDictado> campos) {
    setState(() {
      for (final c in campos) {
        switch (c.clave) {
          case 'valor':
            escribirDictado(_valor, c.valor);
            _porVoz = true;
          case 'observacion':
            // No se pisa una observación ya escrita: lo tecleado a mano vale
            // más que lo que entendió el reconocedor.
            if (_observacion.text.trim().isEmpty) {
              escribirDictado(_observacion, c.valor);
              _porVoz = true;
            }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final esLectura = widget.tipo == TipoCaptura.lectura;
    final bloqueo = _bloqueo;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        esLectura ? 'Registrar lectura' : 'Registrar condición',
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => SgBadge(
                enLinea ? 'En línea' : 'Sin conexión',
                color: enLinea ? sg.acentoTexto : sg.tinta2,
                icono: enLinea ? Icons.wifi : Icons.cloud_off_outlined,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SgPie(
        child: Row(
          children: [
            // El micrófono grande del pie: dicta la frase entera —cifra,
            // unidad y observación— de una vez, que es como se habla en
            // terreno: «vibración 8 coma 4, ruido en el acople».
            SgMicrofonoCampo(
              rotulo: esLectura ? 'Lectura' : 'Medición',
              unidadEsperada: widget.unidad,
              lado: 52,
              onCampos: _aplicarDictado,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SgBoton(
                esLectura ? 'Guardar lectura' : 'Guardar medición',
                icono: Icons.check,
                cargando: _guardando,
                onTap: (_numero != null && bloqueo == null) ? _guardar : null,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 12, 16, 8)),
        children: [
          _Activo(
            nombre: widget.activoNombre,
            codigo: widget.activoCodigo,
            ubicacion: widget.ubicacion,
          ),
          const SizedBox(height: 14),
          SgCard(
            elevada: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SgBadge('Obligatorio',
                        color: sg.rojoTexto, icono: Icons.star_outline),
                    if (widget.medidorNombre != null)
                      SgBadge(widget.medidorNombre!,
                          color: sg.azulTexto, icono: Icons.speed_outlined),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  esLectura
                      ? 'Lectura de ${widget.medidorNombre ?? "medidor"}'
                      : 'Medición de condición',
                  style: sora(20, 700, color: sg.tinta, alto: 1.35,
                      espaciado: -0.4),
                ),
                const SizedBox(height: 14),
                const SgRotuloCampo('Valor medido'),
                const SizedBox(height: 8),
                _CampoValor(
                  controlador: _valor,
                  unidad: widget.unidad,
                  hayError: bloqueo != null,
                  rotuloVoz: esLectura ? 'Lectura' : 'Medición',
                  onCambio: () => setState(() {}),
                  onVoz: (v) => setState(() {
                    escribirDictado(_valor, v);
                    _porVoz = true;
                  }),
                ),
                if (bloqueo != null) ...[
                  const SizedBox(height: 10),
                  _Nota(bloqueo, color: sg.rojoTexto),
                ] else if (_aviso != null) ...[
                  const SizedBox(height: 10),
                  // Fuera de rango **no impide guardar**: es el hallazgo.
                  _Nota(_aviso!, color: sg.ambarTexto),
                ],
                if (esLectura && widget.valorAnterior != null) ...[
                  const SizedBox(height: 12),
                  _Anterior(
                    valor: widget.valorAnterior!,
                    unidad: widget.unidad,
                    nuevo: _numero,
                  ),
                ],
                if (esLectura && widget.permiteReinicio) ...[
                  const SizedBox(height: 4),
                  SgCasilla('El medidor se reinició',
                      marcada: _esReinicio,
                      onCambio: (v) => setState(() => _esReinicio = v)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 13),
          _FechaEvento(
            cuando: _cuando,
            texto: _fecha.format(_cuando),
            onCambio: (d) => setState(() => _cuando = d),
          ),
          const SizedBox(height: 13),
          _Observacion(
            controlador: _observacion,
            onVoz: (v) => setState(() {
              escribirDictado(_observacion, v);
              _porVoz = true;
            }),
          ),
          const SizedBox(height: 13),
          _Fotos(activoId: widget.activoId),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Activo extends StatelessWidget {
  const _Activo({required this.nombre, this.codigo, this.ubicacion});

  final String nombre;
  final String? codigo;
  final String? ubicacion;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const SgFoto(lado: 48, radio: 15, icono: Icons.view_in_ar_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [codigo, nombre].where((s) => (s ?? '').isNotEmpty).join(' · '),
                  style: sora(15, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((ubicacion ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(ubicacion!,
                      style: sora(12, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El campo de 64 del artboard: cifra 28/700 tabular y la unidad en `.u u-lg`.
///
/// Es el único campo de la app con esa altura, y se la gana: **es el dato**.
/// Todo lo demás de la pantalla existe para acompañarlo.
class _CampoValor extends StatefulWidget {
  const _CampoValor({
    required this.controlador,
    required this.onCambio,
    required this.onVoz,
    required this.rotuloVoz,
    this.unidad,
    this.hayError = false,
  });

  final TextEditingController controlador;
  final VoidCallback onCambio;
  final ValueChanged<String> onVoz;
  final String rotuloVoz;
  final String? unidad;
  final bool hayError;

  @override
  State<_CampoValor> createState() => _CampoValorState();
}

class _CampoValorState extends State<_CampoValor> {
  final _foco = FocusNode();
  bool _enfocado = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() => _enfocado = _foco.hasFocus));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SgRadius.campo),
        boxShadow: [
          if (widget.hayError)
            ...anillo(SgColor.rojo, ancho: 1.5)
          else if (_enfocado)
            ...anillo(sg.primario)
          else
            ...sg.e1,
        ],
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: BoxDecoration(
          color: sg.campo,
          borderRadius: BorderRadius.circular(SgRadius.campo),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controlador,
                focusNode: _foco,
                autofocus: true,
                onChanged: (_) => widget.onCambio(),
                // Teclado numérico con coma: en Chile el decimal es coma y el
                // teclado de texto obligaría a buscarla entre los símbolos.
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: sora(28, 700,
                    color: sg.tinta, espaciado: -0.56, tabular: true),
                cursorColor: sg.primario,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '0,0',
                  hintStyle: sora(28, 700, color: sg.tinta3, tabular: true),
                ),
              ),
            ),
            if (widget.unidad != null) ...[
              SgUnidad(widget.unidad!, grande: true),
              const SizedBox(width: 10),
            ],
            SgMicrofonoCampo(
              rotulo: widget.rotuloVoz,
              unidadEsperada: widget.unidad,
              onValor: widget.onVoz,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto subió respecto de la última lectura.
///
/// Es la comprobación que hace un técnico de memoria —«¿son 40 horas en dos
/// días? va bien»— y la que detecta el dedo gordo: un horómetro que salta
/// 12.000 horas en una semana es un cero de más.
class _Anterior extends StatelessWidget {
  const _Anterior({required this.valor, this.unidad, this.nuevo});

  final double valor;
  final String? unidad;
  final double? nuevo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final f = NumberFormat.decimalPattern('es_CL');
    final delta = nuevo == null ? null : nuevo! - valor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: sg.up,
        borderRadius: BorderRadius.circular(SgRadius.bloque),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 17, color: sg.tinta3),
          const SizedBox(width: 9),
          Expanded(
            child: Text('Lectura anterior',
                style: sora(13, 500, color: sg.tinta2)),
          ),
          Text('${f.format(valor)}${unidad == null ? '' : ' $unidad'}',
              style: sora(13, 600, color: sg.tinta2, tabular: true)),
          if (delta != null && delta > 0) ...[
            const SizedBox(width: 8),
            SgBadge('+${f.format(delta)}',
                color: sg.verdeTexto, chico: true),
          ],
        ],
      ),
    );
  }
}

class _FechaEvento extends StatelessWidget {
  const _FechaEvento({
    required this.cuando,
    required this.texto,
    required this.onCambio,
  });

  final DateTime cuando;
  final String texto;
  final ValueChanged<DateTime> onCambio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SgRotuloCampo('Fecha real del evento'),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: cuando,
              // Hacia atrás un mes y nunca hacia adelante: se registra lo que
              // ya pasó, y una fecha futura solo entra por error.
              firstDate: DateTime.now().subtract(const Duration(days: 31)),
              lastDate: DateTime.now(),
            );
            if (d == null) return;
            onCambio(DateTime(
                d.year, d.month, d.day, cuando.hour, cuando.minute));
          },
          borderRadius: BorderRadius.circular(SgRadius.bloque),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.bloque),
              boxShadow: sg.e1,
            ),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sg.campo,
                borderRadius: BorderRadius.circular(SgRadius.bloque),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 20, color: sg.tinta3),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(texto,
                        style: sora(15, 500, color: sg.tinta, tabular: true)),
                  ),
                  Icon(Icons.expand_more, size: 20, color: sg.tinta3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Observacion extends StatelessWidget {
  const _Observacion({required this.controlador, required this.onVoz});

  final TextEditingController controlador;
  final ValueChanged<String> onVoz;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SgRotuloCampo('Observación'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SgRadius.campo),
            boxShadow: sg.e1,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
            decoration: BoxDecoration(
              color: sg.campo,
              borderRadius: BorderRadius.circular(SgRadius.campo),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controlador,
                    maxLines: null,
                    minLines: 2,
                    style: sora(14, 500, color: sg.tinta, alto: 1.5),
                    cursorColor: sg.primario,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Lo que viste, oíste o tocaste',
                      hintStyle: sora(14, 500, color: sg.tinta3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SgMicrofonoCampo(
                  rotulo: 'Observación',
                  soloTexto: true,
                  lado: 40,
                  onValor: onVoz,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// La tira de fotografías del artboard.
///
/// **Todavía no captura.** `image_picker` no está en el proyecto y añadirlo a
/// medias —un botón que abre la cámara pero cuya foto no se encola ni se
/// sube— sería peor que no tenerlo: el técnico creería que la evidencia quedó
/// registrada. La tira está y dice qué falta.
class _Fotos extends StatelessWidget {
  const _Fotos({required this.activoId});

  final int activoId;

  @override
  Widget build(BuildContext context) {
    /* LA FOTO SE CUELGA DEL ACTIVO, NO DE LA LECTURA

       Los dos cuadros de acá mostraban «la evidencia fotográfica llega en el
       siguiente bloque»: eran botones que se veían habilitados y no hacían
       nada.

       No pueden colgarse de la lectura porque **todavía no existe**: se
       encola y el servidor le pone id al recibirla. Se cuelgan del activo,
       que sí tiene id y es lo correcto de todos modos — una foto tomada al
       registrar una vibración documenta el equipo, y sirve la próxima vez que
       alguien lo mire, no solo para esta lectura. */
    return SgEvidencias(destino: 'ACTIVO', destinoId: activoId);
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto, {required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: sora(13, 500, color: color, alto: 1.45)),
          ),
        ],
      );
}
