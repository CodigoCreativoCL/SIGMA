import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../services/api_client.dart';
import '../../services/sigma_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_v3.dart';

/// Con quién se puede compartir, en esta instalación.
///
/// Se pide por instalación y no una vez por sesión: la persona puede cambiar
/// de planta en el día, y la lista de quién está ahí cambia con ella.
final companerosProvider =
    FutureProvider.family<List<Companero>, int>((ref, instalacion) =>
        SigmaRepository.instance.companeros(instalacion));

/// La hoja de compartir un trabajo con un compañero.
///
/// ## Qué resuelve
///
/// Un técnico abre un motor y ve que no lo saca solo: necesita al eléctrico, o
/// a alguien que sostenga mientras desmonta. Hoy eso se arregla por teléfono o
/// gritando en la planta, y no queda registrado en ninguna parte: la orden
/// termina firmada por uno solo aunque la hicieron dos.
///
/// ## Por qué no es el «compartir» del sistema
///
/// Mandar un enlace por WhatsApp saca el trabajo de SIGMA: el compañero recibe
/// un texto que no puede abrir y nada queda anotado. Acá el aviso entra por la
/// **bandeja de alertas**, que ya tiene badge, no leídas y pantalla — y desde
/// ahí el compañero puede sumarse al trabajo.
class HojaCompartir extends ConsumerStatefulWidget {
  const HojaCompartir({
    super.key,
    required this.instalacionId,
    required this.entidad,
    required this.entidadId,
    required this.que,
  });

  final int instalacionId;

  /// ORDEN · TAREA · ACTIVO
  final String entidad;
  final int entidadId;

  /// Lo que se está compartiendo, para que la hoja diga de qué se trata.
  final String que;

  @override
  ConsumerState<HojaCompartir> createState() => _HojaCompartirState();
}

class _HojaCompartirState extends ConsumerState<HojaCompartir> {
  final _mensaje = TextEditingController();
  final _buscar = TextEditingController();
  String _filtro = '';
  int? _enviando;

  @override
  void dispose() {
    _mensaje.dispose();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _compartirCon(Companero c) async {
    if (_enviando != null) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    setState(() => _enviando = c.usu_id);

    try {
      await SigmaRepository.instance.compartir(
        destinatario: c.usu_id,
        entidad: widget.entidad,
        entidadId: widget.entidadId,
        mensaje: _mensaje.text.trim().isEmpty ? null : _mensaje.text.trim(),
      );
      navegador.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = null);
      // El mensaje del servidor va tal cual: «esa persona no está asignada a
      // la instalación del trabajo» dice qué pasó y qué hacer.
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final companeros = ref.watch(companerosProvider(widget.instalacionId));

    return Container(
      decoration: BoxDecoration(
        color: sg.fondo,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SgRadius.hoja)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            // El teclado sube la hoja: sin esto tapa la lista justo cuando se
            // está escribiendo a quién buscar.
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sg.indicador,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text('Compartir con un compañero',
                  style: sora(17, 600, color: sg.tinta)),
              const SizedBox(height: 4),
              Text(widget.que,
                  style: sora(13, 500, color: sg.tinta3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),

              SgCampo(
                controlador: _mensaje,
                icono: Icons.notes,
                hint: 'Para qué lo necesitas (opcional)',
                lineas: 2,
              ),
              const SizedBox(height: 12),

              // Solo hace falta buscar cuando la planta tiene mucha gente.
              companeros.maybeWhen(
                data: (l) => l.length > 6
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SgCampo(
                          controlador: _buscar,
                          icono: Icons.search,
                          hint: 'Buscar por nombre',
                          onCambio: (v) =>
                              setState(() => _filtro = v.toLowerCase().trim()),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),

              const SgRotulo('En esta planta'),
              const SizedBox(height: 9),

              ConstrainedBox(
                // La hoja no puede comerse la pantalla: con quince personas la
                // lista se desplaza dentro de la hoja, no la hoja entera.
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.38,
                ),
                child: companeros.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SgAviso(
                    e is ApiException
                        ? e.mensaje
                        : 'No se pudo cargar la lista de compañeros.',
                    icono: Icons.error_outline,
                    color: sg.rojoTexto,
                  ),
                  data: (lista) {
                    final visibles = _filtro.isEmpty
                        ? lista
                        : lista
                            .where((c) =>
                                c.NOMBRE.toLowerCase().contains(_filtro))
                            .toList();

                    if (visibles.isEmpty) {
                      return SgAviso(
                        lista.isEmpty
                            ? 'No hay nadie más asignado a esta planta. '
                                'Las asignaciones se hacen desde la web.'
                            : 'Nadie coincide con esa búsqueda.',
                        icono: Icons.person_off_outlined,
                        color: sg.tinta2,
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _FilaCompanero(
                        companero: visibles[i],
                        enviando: _enviando == visibles[i].usu_id,
                        bloqueado: _enviando != null,
                        onTap: () => _compartirCon(visibles[i]),
                      ),
                    );
                  },
                ),
              ),
              const SgBarraGestos(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaCompanero extends StatelessWidget {
  const _FilaCompanero({
    required this.companero,
    required this.enviando,
    required this.bloqueado,
    required this.onTap,
  });

  final Companero companero;
  final bool enviando;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(12),
      onTap: bloqueado ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: sg.tinte(sg.primario),
              borderRadius: BorderRadius.circular(SgRadius.icono48),
            ),
            alignment: Alignment.center,
            child: Text(companero.iniciales,
                style: sora(15, 700, color: sg.primarioTexto)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(companero.NOMBRE,
                    style: sora(15, 600, color: sg.tinta),
                    overflow: TextOverflow.ellipsis),
                if ((companero.PERFIL_NOMBRE ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  // El perfil importa: para un acople eléctrico se busca al
                  // eléctrico, no al primero de la lista.
                  Text(companero.PERFIL_NOMBRE!,
                      style: sora(12, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (enviando)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: sg.primarioTexto),
            )
          else
            Icon(Icons.send_outlined, size: 20, color: sg.primarioTexto),
        ],
      ),
    );
  }
}
