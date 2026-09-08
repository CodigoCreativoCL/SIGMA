import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/api_constants.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../../widgets/comun/sigma_voz.dart';

/// 6.2 · Abrir una OT correctiva desde terreno — HU-110.
///
/// ## Por qué se abre aquí y no en la oficina
///
/// La correctiva nace cuando algo se rompe, y quien lo ve es el que está al
/// lado de la máquina. Obligarlo a avisar por radio y que otro la registre
/// pierde por el camino lo único que no se puede reconstruir después: qué se
/// vio, a qué hora paró y con qué síntoma. Esta pantalla la abre donde ocurrió.
///
/// ## La fecha del evento no es la del registro
///
/// `fecha_evento_utc` es **cuándo pasó**, no cuándo se escribió. Una OT
/// registrada tres horas después de la falla no puede mentir sobre cuándo paró
/// la máquina: de esa diferencia salen el MTTR y el tiempo de detención, y si
/// se toma la hora del formulario los dos quedan cortos para siempre.
///
/// ## Se encola, y el uuid nace al abrir
///
/// Es la captura de terreno más típica de todas: se llena delante del equipo
/// averiado, que es donde no hay señal. `API_INS_ORDEN_TRABAJO` corta por
/// `uuid` antes de sus reglas, así que un reintento no abre la misma OT dos
/// veces — y dos OT para la misma falla es trabajo duplicado y un MTTR que no
/// significa nada.
class NuevaOrdenScreen extends ConsumerStatefulWidget {
  const NuevaOrdenScreen({super.key, this.activoId, this.activoNombre});

  /// Cuando se entra desde la ficha de un activo, la OT ya cuelga de él y no
  /// hay que buscarlo.
  final int? activoId;
  final String? activoNombre;

  @override
  ConsumerState<NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends ConsumerState<NuevaOrdenScreen> {
  /// 2 = CORRECTIVA. Esta pantalla abre correctivas y solo correctivas: una
  /// preventiva nace de un plan y una predictiva de una medición, no de que
  /// alguien la escriba en el pasillo.
  static const int _correctiva = 2;

  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _pasos = TextEditingController();

  /// Nace al abrir, no al enviar.
  final String _uuid = OutboxService.nuevoUuid();

  static final _fecha = DateFormat('dd-MM-yyyy · HH:mm', 'es');

  int? _prioridad;
  DateTime _cuando = DateTime.now();
  bool _requierePermiso = false;
  bool _guardando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _pasos.dispose();
    super.dispose();
  }

  bool get _completo => _titulo.text.trim().isNotEmpty && !_guardando;

  Future<void> _guardar(int instalacion) async {
    if (!_completo) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);

    final pasos = _pasos.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');

    try {
      await OutboxService.instance.encolar(
        tipo: 'ORDEN_TRABAJO',
        titulo: 'Nueva OT correctiva',
        detalle: _titulo.text.trim(),
        endpoint: ApiConstants.ordenesTrabajo,
        uuid: _uuid,
        cuerpo: {
          'instalacion': instalacion,
          'titulo': _titulo.text.trim(),
          'descripcion': _descripcion.text.trim().isEmpty
              ? null
              : _descripcion.text.trim(),
          'activo': widget.activoId,
          'tipo': _correctiva,
          'prioridad': _prioridad,
          // En UTC, como todas las fechas que viajan: el servidor no puede
          // adivinar en qué huso estaba el teléfono.
          'fecha_evento_utc': _cuando.toUtc().toIso8601String(),
          'requiere_permiso': _requierePermiso,
          'pasos': pasos.isEmpty ? null : pasos,
          // 1 = escrito a mano. El dictado lo marca el panel de voz.
          'entrada_modo': 1,
        },
      );

      SyncService.instance.despacharAhora();
      if (!mounted) return;
      ref.invalidate(ordenesTrabajoProvider);
      ref.invalidate(ordenesDisponiblesProvider);

      if (!mounted) return;
      navegador.pop(true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            SyncService.instance.enLinea.value
                ? 'Orden creada.'
                : 'Guardado en el teléfono. Se envía al volver la señal.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo crear: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final instalacion = ref.watch(instalacionProvider);
    final prioridades = ref.watch(
      valoresCatalogoProvider('ORDEN_TRABAJO_PRIORIDAD'),
    );

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra(
        'Nueva orden correctiva',
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ValueListenableBuilder<bool>(
              valueListenable: SyncService.instance.enLinea,
              builder: (_, enLinea, _) => enLinea
                  ? const SizedBox.shrink()
                  : SgBadge(
                      'Sin conexión',
                      color: sg.tinta2,
                      icono: Icons.cloud_off_outlined,
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SgPie(
        child: SgBoton(
          'Abrir la orden',
          icono: Icons.build_outlined,
          cargando: _guardando,
          onTap: _completo && instalacion != null
              ? () => _guardar(instalacion.cin_id)
              : null,
        ),
      ),
      body: ListView(
        padding: context.conBarraSistema(
          const EdgeInsets.fromLTRB(16, 14, 16, 12),
        ),
        children: [
          /* SIN PLANTA NO SE PUEDE ABRIR

             `instalacion` es obligatoria en el DTO y el SP comprueba que sea
             una de las autorizadas. Avisar acá, y no dejar que se llene el
             formulario para morir en un 400, es la misma razón por la que la
             vigencia al revés se avisa antes de enviar. */
          if (instalacion == null) ...[
            SgAviso(
              'Elige una planta antes de abrir una orden. La orden pertenece a '
              'una planta, y el servidor comprueba que sea de las tuyas.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            const SizedBox(height: 14),
          ],

          if (widget.activoNombre != null) ...[
            SgCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(Icons.view_in_ar_outlined, size: 19, color: sg.tinta2),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      widget.activoNombre!,
                      style: sora(14, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          const SgRotuloCampo('Qué pasa'),
          const SizedBox(height: 4),
          Text(
            'Una línea. Es lo que se lee en la bandeja, así que tiene que '
            'distinguirse de las otras doce.',
            style: sora(12, 500, color: sg.tinta3, alto: 1.45),
          ),
          const SizedBox(height: 9),
          SgCampo(
            controlador: _titulo,
            icono: Icons.title,
            hint: 'Fuga de aceite en reductor de la línea 3',
            autoenfoque: true,
            conVoz: true,
            onCambio: (_) => setState(() {}),
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Qué pasa',
                interpretar: (t) => [
                  CampoDictado(
                    clave: 'titulo',
                    rotulo: 'Título',
                    valor: InterpreteVoz.normalizar(t),
                  ),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_titulo, campos.first.valor));
            },
          ),

          const SizedBox(height: 14),
          const SgRotuloCampo('Detalle'),
          const SizedBox(height: 8),
          SgCampo(
            controlador: _descripcion,
            icono: Icons.notes,
            hint: 'Gotea por el retén del eje de salida, charco de unos 20 cm',
            lineas: 3,
            conVoz: true,
            onVoz: () async {
              final campos = await mostrarPanelVoz(
                context,
                titulo: 'Detalle de la falla',
                interpretar: (t) => [
                  CampoDictado(
                    clave: 'detalle',
                    rotulo: 'Detalle',
                    valor: InterpreteVoz.normalizar(t),
                  ),
                ],
              );
              if (campos == null || campos.isEmpty) return;
              setState(() => escribirDictado(_descripcion, campos.first.valor));
            },
          ),

          const SizedBox(height: 16),
          const SgRotulo('Prioridad'),
          const SizedBox(height: 9),

          /* LA PRIORIDAD SALE DEL CATALOGO, Y ES OPCIONAL

             Sale de `ORDEN_TRABAJO_PRIORIDAD` y no de cuatro chips escritos
             acá, porque los niveles los define la empresa.

             Sin señal el catálogo no baja —los VALORES de catálogo todavía no
             viajan en la sábana, solo sus cabeceras—, así que la fila
             desaparece en vez de bloquear el formulario: `prioridad` es
             opcional en el DTO y el SP le pone la suya. Perder el nivel es
             malo; no poder abrir la OT de una máquina parada porque en la nave
             no hay señal es peor. */
          prioridades.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SgAviso(
              'Sin conexión no se pueden traer los niveles de prioridad. La '
              'orden se abre igual y se prioriza al revisarla.',
              icono: Icons.cloud_off_outlined,
              color: sg.tinta2,
            ),
            data: (lista) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in lista)
                  SgChip(
                    p.ctv_nombre,
                    elegido: _prioridad == p.ctv_id,
                    onTap: () => setState(
                      () =>
                          _prioridad = _prioridad == p.ctv_id ? null : p.ctv_id,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          SgCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                SgFila(
                  icono: Icons.schedule,
                  texto: 'Cuándo pasó',
                  detalle: 'No cuándo lo estás escribiendo',
                  valor: _fecha.format(_cuando),
                  onTap: _elegirCuando,
                ),
                Divider(height: 1, color: sg.div),
                SgFila(
                  icono: Icons.gpp_maybe_outlined,
                  texto: 'Necesita permiso de trabajo',
                  detalle: 'Altura, caliente, espacio confinado, eléctrico',
                  derecha: Switch(
                    value: _requierePermiso,
                    onChanged: (v) => setState(() => _requierePermiso = v),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SgRotuloCampo('Pasos, uno por línea'),
          const SizedBox(height: 4),
          Text(
            'Opcional. Los que escribas acá entran con la orden y el técnico '
            'los va marcando.',
            style: sora(12, 500, color: sg.tinta3, alto: 1.45),
          ),
          const SizedBox(height: 9),
          SgCampo(
            controlador: _pasos,
            icono: Icons.checklist,
            hint: 'Bloquear y drenar\nRetirar tapa\nCambiar retén',
            lineas: 4,
          ),

          const SizedBox(height: 16),
          SgAviso(
            'Nace ABIERTA y sin responsable: la toma quien la va a trabajar, '
            'desde la bandeja.',
            icono: Icons.info_outline,
            color: sg.tinta2,
          ),
        ],
      ),
    );
  }

  Future<void> _elegirCuando() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _cuando,
      // Nunca hacia adelante: una correctiva es de algo que YA se rompió, y
      // una fecha futura descuadra el tiempo de detención del activo.
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_cuando),
    );
    if (hora == null || !mounted) return;

    final elegido = DateTime(
      dia.year,
      dia.month,
      dia.day,
      hora.hour,
      hora.minute,
    );

    setState(() {
      // Elegir hoy y una hora que todavía no llegó dejaría la falla en el
      // futuro; se acota a ahora en vez de rechazarlo con un error.
      _cuando = elegido.isAfter(DateTime.now()) ? DateTime.now() : elegido;
    });
  }
}
