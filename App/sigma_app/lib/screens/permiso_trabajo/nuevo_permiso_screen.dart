import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../providers/datos_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// Registrar un permiso de trabajo — HU-063.
///
/// ## Por qué se registra desde el terreno
///
/// El permiso se pide donde está el riesgo. Un trabajo en caliente sobre una
/// línea de proceso se decide frente a la línea, no en la oficina: quien mira
/// la brida es quien sabe si hace falta bloqueo, si hay que vaciar antes, y a
/// qué hora se puede. Obligar a volver al escritorio para pedirlo hace que el
/// papel se llene después de trabajar, que es exactamente lo que un permiso
/// existe para impedir.
///
/// ## Por qué nace SOLICITADO y no AUTORIZADO
///
/// La constancia de un permiso autorizado **es el documento firmado**, no la
/// fila en la tabla: `CK_PTR_AUTORIZADO` no deja que exista uno AUTORIZADO sin
/// su adjunto. Desde el teléfono se registra la solicitud; autorizarlo es un
/// acto de quien firma, con el papel a la vista, y se hace desde la ficha.
///
/// Dejar elegir «AUTORIZADO» aquí sería ofrecer un camino que la base rechaza
/// —error 10 del SP— después de haber llenado todo el formulario.
///
/// ## Por qué se encola
///
/// Como toda captura de terreno. El `uuid` nace **al abrir la pantalla**, no
/// al enviar: `INS_PERMISO_TRABAJO` corta por él antes de sus reglas, así que
/// un reintento sin señal no deja el mismo permiso pedido dos veces.
class NuevoPermisoScreen extends ConsumerStatefulWidget {
  const NuevoPermisoScreen({super.key, this.ordenId, this.ordenNumero});

  /// Cuando se entra desde una OT, el permiso ya cuelga de ella y no hay que
  /// buscarla en una lista.
  final int? ordenId;
  final String? ordenNumero;

  @override
  ConsumerState<NuevoPermisoScreen> createState() => _NuevoPermisoScreenState();
}

class _NuevoPermisoScreenState extends ConsumerState<NuevoPermisoScreen> {
  final _numero = TextEditingController();
  final _observacion = TextEditingController();

  /// Nace al abrir, no al enviar.
  final String _uuid = OutboxService.nuevoUuid();

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  int? _tipo;

  /// La vigencia arranca ahora y dura el turno. Es lo que pasa en la práctica
  /// —el permiso se pide para el trabajo que empieza—, y quien necesite otra
  /// cosa la mueve; quien no, no tiene que tocar nada.
  DateTime _desde = DateTime.now();
  DateTime _hasta = DateTime.now().add(const Duration(hours: 8));

  bool _guardando = false;

  @override
  void dispose() {
    _numero.dispose();
    _observacion.dispose();
    super.dispose();
  }

  bool get _vigenciaAlReves => _hasta.isBefore(_desde);

  bool get _completo => _tipo != null && !_vigenciaAlReves;

  Future<void> _guardar() async {
    if (!_completo || _guardando) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);

    try {
      await OutboxService.instance.encolar(
        tipo: 'PERMISO_TRABAJO',
        titulo: 'Permiso de trabajo',
        detalle: _numero.text.trim().isEmpty
            ? 'Solicitud registrada en terreno'
            : 'N° ${_numero.text.trim()}',
        endpoint: ApiConstants.permisosTrabajo,
        uuid: _uuid,
        cuerpo: {
          'tipo': _tipo,
          // El estado va sin decir: el SP lo resuelve a SOLICITADO, que es el
          // único que se puede afirmar sin el documento firmado delante.
          'numero': _numero.text.trim().isEmpty ? null : _numero.text.trim(),
          'orden_trabajo': widget.ordenId,
          'vigencia_inicio': _desde.toUtc().toIso8601String(),
          'vigencia_fin': _hasta.toUtc().toIso8601String(),
          'observacion': _observacion.text.trim().isEmpty
              ? null
              : _observacion.text.trim(),
        },
      );

      SyncService.instance.despacharAhora();
      ref.invalidate(permisosTrabajoProvider);
      ref.invalidate(permisosVigentesProvider);

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(SnackBar(
        content: Text(SyncService.instance.enLinea.value
            ? 'Permiso solicitado.'
            : 'Guardado en el teléfono. Se envía al volver la señal.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero
          .showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tipos = ref.watch(tiposPermisoProvider);

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Solicitar permiso',
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
          'Registrar la solicitud',
          icono: Icons.assignment_turned_in_outlined,
          cargando: _guardando,
          onTap: _completo ? _guardar : null,
        ),
      ),
      body: ListView(
        padding:
            context.conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 12)),
        children: [
          if (widget.ordenNumero != null) ...[
            SgCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined, size: 19, color: sg.tinta2),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text('OT ${widget.ordenNumero}',
                        style: sora(14, 600, color: sg.tinta),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          const SgRotulo('Qué tipo de permiso'),
          const SizedBox(height: 9),
          tipos.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SgAviso(
              'No se pudieron cargar los tipos. Sin ellos no se puede pedir '
              'un permiso.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (lista) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in lista)
                  SgChip(t.nombre,
                      elegido: _tipo == t.id,
                      onTap: () => setState(() => _tipo = t.id)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SgRotuloCampo('Número del formulario (si ya lo tiene)'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _numero,
            icono: Icons.tag,
            hint: 'PT-2026-0413',
            mayusculas: true,
            conVoz: true,
            onCambio: (_) => setState(() {}),
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Número del permiso',
                interpretar: (t) => [
                  CampoDictado(
                      clave: 'numero',
                      rotulo: 'Número',
                      valor: InterpreteVoz.normalizar(t).toUpperCase()),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_numero, campos.first.valor));
            },
          ),

          const SizedBox(height: 14),
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                SgFila(
                  icono: Icons.play_circle_outline,
                  texto: 'Desde',
                  valor: _fecha.format(_desde),
                  onTap: () => _elegir(inicio: true),
                ),
                Divider(height: 1, color: sg.div),
                SgFila(
                  icono: Icons.stop_circle_outlined,
                  texto: 'Hasta',
                  valor: _fecha.format(_hasta),
                  onTap: () => _elegir(inicio: false),
                ),
              ],
            ),
          ),

          /* Se avisa ACA y no al enviar. La base lo rechaza igual —regla 5 del
             SP—, pero descubrirlo después de llenar el formulario es una
             pérdida de tiempo evitable, y en terreno el tiempo del formulario
             se le resta al trabajo. */
          if (_vigenciaAlReves) ...[
            const SizedBox(height: 12),
            SgAviso(
              'La vigencia termina antes de empezar. Un permiso así nace '
              'vencido.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
          ],

          const SizedBox(height: 14),
          const SgRotuloCampo('Observación'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _observacion,
            icono: Icons.notes,
            hint: 'Bloqueo aguas arriba, línea vaciada y purgada',
            lineas: 3,
            conVoz: true,
            onCambio: (_) => setState(() {}),
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Observación',
                interpretar: (t) => [
                  CampoDictado(
                      clave: 'observacion',
                      rotulo: 'Observación',
                      valor: InterpreteVoz.normalizar(t)),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_observacion, campos.first.valor));
            },
          ),

          const SizedBox(height: 16),
          SgAviso(
            'Queda como SOLICITADO. Para autorizarlo hay que adjuntar el '
            'documento firmado: la constancia es el papel, no el registro.',
            icono: Icons.info_outline,
            color: sg.tinta2,
          ),
        ],
      ),
    );
  }

  Future<void> _elegir({required bool inicio}) async {
    final actual = inicio ? _desde : _hasta;

    final dia = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null || !mounted) return;

    final elegido =
        DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);

    setState(() {
      if (inicio) {
        _desde = elegido;
        /* Mover el inicio arrastra el fin si lo dejó atrás. Sin esto, correr
           el permiso a mañana deja un «hasta» de ayer y el aviso rojo sale
           por algo que el usuario no hizo. */
        if (_hasta.isBefore(_desde)) {
          _hasta = _desde.add(const Duration(hours: 8));
        }
      } else {
        _hasta = elegido;
      }
    });
  }
}
