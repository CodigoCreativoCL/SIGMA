import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sigma_repository.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// Escribir en la bitácora de planta — HU-130.
///
/// ## Por qué se escribe desde el terreno
///
/// Una bitácora que solo se puede llenar desde la oficina se llena tarde, de
/// memoria, o no se llena. Lo que hay que registrar —una fuga, un ruido raro,
/// un equipo que se detuvo— se ve delante de la máquina, y una hora después ya
/// se cuenta distinto.
///
/// ## Por qué la fecha del evento se puede mover hacia atrás
///
/// «Cuándo pasó» no es «cuándo lo escribí». Una entrada tecleada al terminar
/// la ronda puede ser de dos horas antes, y ponerla en la hora del envío
/// descoloca el relato del turno para quien lo lea mañana.
///
/// ## Por qué se encola
///
/// Como toda captura de terreno: se guarda en el teléfono y la pantalla
/// confirma con eso. El `uuid` nace **al abrir la pantalla**, no al enviar, así
/// que un reintento sin señal no deja el turno contado dos veces.
class NuevaEntradaScreen extends ConsumerStatefulWidget {
  const NuevaEntradaScreen({super.key, this.activoId, this.activoNombre});

  /// Cuando se entra desde la ficha de un equipo, la entrada ya cuelga de él.
  final int? activoId;
  final String? activoNombre;

  @override
  ConsumerState<NuevaEntradaScreen> createState() => _NuevaEntradaScreenState();
}

class _NuevaEntradaScreenState extends ConsumerState<NuevaEntradaScreen> {
  final _titulo = TextEditingController();
  final _texto = TextEditingController();

  /// Nace al abrir, no al enviar: un reintento de la cola no puede dejar el
  /// turno contado dos veces.
  final String _uuid = OutboxService.nuevoUuid();

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  int? _tipo;
  int? _severidad;
  DateTime _cuando = DateTime.now();
  bool _requiereAtencion = false;
  bool _porVoz = false;
  bool _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    super.dispose();
  }

  /// El turno se deduce de la hora del evento y no se pregunta: en una planta
  /// de tres turnos, quien escribe a las 23:40 sabe perfectamente en cuál está
  /// y teclearlo es un paso que solo sirve para equivocarse.
  String get _turno {
    final h = _cuando.hour;
    if (h >= 6 && h < 14) return 'A';
    if (h >= 14 && h < 22) return 'B';
    return 'C';
  }

  bool get _completo =>
      _tipo != null &&
      _titulo.text.trim().isNotEmpty &&
      _texto.text.trim().isNotEmpty;

  Future<void> _guardar() async {
    if (!_completo || _guardando) return;

    final instalacion = ref.read(instalacionProvider);
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    if (instalacion == null) {
      mensajero.showSnackBar(const SnackBar(
          content: Text('Elige una planta antes de escribir.')));
      return;
    }

    setState(() => _guardando = true);

    try {
      await SigmaRepository.instance.escribirBitacora({
        'uuid': _uuid,
        'instalacion': instalacion.cin_id,
        'tipo': _tipo,
        'titulo': _titulo.text.trim(),
        'texto': _texto.text.trim(),
        'activo': widget.activoId,
        // La fecha del EVENTO, no la del envío.
        'fecha_evento': _cuando.toUtc().toIso8601String(),
        'turno': _turno,
        'requiere_atencion': _requiereAtencion,
        'severidad': _severidad,
        'offline': !SyncService.instance.enLinea.value,
        // Queda el rastro de cómo se escribió: un texto dictado y uno tecleado
        // no se auditan igual.
        if (_porVoz) 'texto_dictado': _texto.text.trim(),
      });

      SyncService.instance.despacharAhora();
      ref.invalidate(bitacoraProvider);

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(SnackBar(
        content: Text(SyncService.instance.enLinea.value
            ? 'Anotado en la bitácora.'
            : 'Guardado en el teléfono. Se envía al volver la señal.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tipos = ref.watch(tiposBitacoraProvider);
    final severidades = ref.watch(valoresCatalogoProvider('SEVERIDAD'));

    final tipoElegido = tipos.valueOrNull
        ?.where((t) => t.bti_id == _tipo)
        .firstOrNull;

    // La severidad solo se pide para un incidente. En una observación de
    // rutina, obligar a graduarla inventa una escala donde no hay ninguna.
    final pideSeveridad = tipoElegido?.esIncidente ?? false;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Anotar en la bitácora',
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => enLinea
                  ? const SizedBox.shrink()
                  : SgBadge('Sin conexión',
                      color: sg.tinta2, icono: Icons.cloud_off_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SgPie(
        child: SgBoton(
          'Guardar en la bitácora',
          icono: Icons.check,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ),
      body: ListView(
        padding:
            context.conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 12)),
        children: [
          if (widget.activoNombre != null) ...[
            SgCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(Icons.view_in_ar_outlined, size: 19, color: sg.tinta2),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(widget.activoNombre!,
                        style: sora(14, 600, color: sg.tinta),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          const SgRotulo('Qué tipo de anotación'),
          const SizedBox(height: 9),
          tipos.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SgAviso(
              'No se pudieron cargar los tipos. Sin ellos no se puede anotar.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (lista) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in lista)
                  SgChip(t.bti_nombre,
                      elegido: _tipo == t.bti_id,
                      onTap: () => setState(() => _tipo = t.bti_id)),
              ],
            ),
          ),

          if (pideSeveridad) ...[
            const SizedBox(height: 16),
            const SgRotulo('Qué tan grave'),
            const SizedBox(height: 4),
            Text(
              'Es lo que decide qué mira primero el turno siguiente.',
              style: sora(12, 500, color: sg.tinta3, alto: 1.45),
            ),
            const SizedBox(height: 9),
            severidades.when(
              loading: () => const SizedBox(height: 34),
              error: (_, _) => const SizedBox.shrink(),
              data: (lista) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in lista)
                    SgChip(v.ctv_nombre,
                        elegido: _severidad == v.ctv_id,
                        onTap: () => setState(() => _severidad = v.ctv_id)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const SgRotuloCampo('En una línea'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _titulo,
            icono: Icons.short_text,
            hint: 'Fuga en la brida del cabezal',
            onCambio: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),
          const SgRotuloCampo('Qué pasó'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _texto,
            icono: Icons.notes,
            hint: 'Lo que viste, oíste o tocaste',
            lineas: 4,
            conVoz: true,
            onCambio: (_) => setState(() {}),
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Qué pasó',
                interpretar: (t) => [
                  CampoDictado(
                      clave: 'texto',
                      rotulo: 'Qué pasó',
                      valor: InterpreteVoz.normalizar(t)),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() {
                escribirDictado(_texto, campos.first.valor);
                _porVoz = true;
              });
            },
          ),

          const SizedBox(height: 14),
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                SgFila(
                  icono: Icons.schedule,
                  texto: 'Cuándo pasó',
                  detalle: 'Turno $_turno',
                  valor: _fecha.format(_cuando),
                  onTap: _elegirCuando,
                ),
                Divider(height: 1, color: sg.div),
                SgFila(
                  icono: Icons.priority_high,
                  texto: 'Requiere atención',
                  detalle: 'Lo marca para el turno siguiente',
                  derecha: Switch(
                    value: _requiereAtencion,
                    onChanged: (v) => setState(() => _requiereAtencion = v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _elegirCuando() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _cuando,
      // Nunca hacia adelante: una entrada de bitácora es de algo que YA pasó.
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_cuando),
    );
    if (hora == null || !mounted) return;

    setState(() => _cuando =
        DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute));
  }
}
