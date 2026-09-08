import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../models/sesion_model.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/sincronizacion_provider.dart';
import '../../services/api_client.dart';
import '../../services/sesion_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/estado_async.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Los clientes a los que pertenece quien entró.
final misClientesProvider = FutureProvider<List<ClienteElegibleModel>>(
    (ref) => AuthService.instance.misClientes());

/// El texto del buscador de contexto.
final busquedaContextoProvider = StateProvider<String>((ref) => '');

/// 4.4 · Cliente e instalación — HU-002, HU-006.
///
/// Layout del artboard: barra 64 «Contexto de trabajo»; título 26/700 a dos
/// líneas; buscador de 52 en píldora; bloque CLIENTE con tarjetas de 22 y
/// avatar 48/16; bloque INSTALACIÓN con ícono 25 y badge de estado de datos;
/// al pie, «Continuar».
///
/// ## Se eligen las dos cosas, y no son lo mismo
///
/// **El cliente emite un token nuevo**: el servidor revalida la pertenencia
/// contra la base sin confiar en el id que llega. La instalación, en cambio,
/// es un filtro de consulta que se queda en la app — la barrera de seguridad
/// la pone el SP con las plantas que la persona tiene autorizadas.
///
/// Por eso el anillo de la tarjeta elegida es **morado en cliente y teal en
/// instalación**: son dos decisiones de distinto peso y el kit las distingue
/// con el color.
class SeleccionContextoScreen extends ConsumerStatefulWidget {
  const SeleccionContextoScreen({super.key, this.puedeVolver = true});

  final bool puedeVolver;

  @override
  ConsumerState<SeleccionContextoScreen> createState() =>
      _SeleccionContextoScreenState();
}

class _SeleccionContextoScreenState
    extends ConsumerState<SeleccionContextoScreen> {
  final _buscar = TextEditingController();
  int? _eligiendo;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _elegirCliente(ClienteElegibleModel c) async {
    // Los notifiers se capturan ANTES del await: viven en el contenedor, no
    // en este widget, que puede desmontarse mientras la red responde.
    final sesion = ref.read(sesionProvider.notifier);
    final instalacion = ref.read(instalacionProvider.notifier);
    final mensajero = ScaffoldMessenger.of(context);

    setState(() => _eligiendo = c.id);
    try {
      await AuthService.instance.seleccionarCliente(c.id);
      sesion.refrescar();

      // El token cambió: todo lo acotado por cliente hay que volver a pedirlo,
      // y la instalación anterior es de otra empresa.
      instalacion.state = null;
      for (final p in [
        plantasProvider,
        existenciasProvider,
        alertasProvider,
        resumenAlertasProvider,
        menuProvider,
        permisosProvider,
      ]) {
        ref.invalidate(p);
      }
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _eligiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final clientes = ref.watch(misClientesProvider);
    final plantas = ref.watch(plantasProvider);
    final sesion = ref.watch(sesionProvider);
    final elegida = ref.watch(instalacionProvider);
    final filtro = ref.watch(busquedaContextoProvider).trim().toLowerCase();

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: SgBarra('Contexto de trabajo', conVolver: widget.puedeVolver),
      bottomNavigationBar: SgPie(
        child: SgBoton(
          'Continuar',
          icono: Icons.arrow_forward,
          iconoAlFinal: true,
          // Sin instalación elegida no se continúa: entrar «a todas» dejaría
          // al técnico con las tres plantas mezcladas, filtrando de memoria.
          onTap: elegida == null
              ? null
              : () => Navigator.of(context).maybePop(true),
        ),
      ),
      body: ListView(
        padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 10, 16, 8)),
        children: [
          const SgTitulo('¿Dónde vas a\ntrabajar hoy?'),
          const SizedBox(height: 20),
          _Buscador(
            controlador: _buscar,
            onCambio: (v) =>
                ref.read(busquedaContextoProvider.notifier).state = v,
          ),
          const SizedBox(height: 20),

          // ---------------------------------------------------- CLIENTE ----
          const SgRotulo('Cliente'),
          const SizedBox(height: 12),
          EstadoAsync<List<ClienteElegibleModel>>(
            valor: clientes,
            onReintentar: () => ref.invalidate(misClientesProvider),
            estaVacio: (l) => _filtrarClientes(l, filtro).isEmpty,
            vacio: EstadoVacio(
              icono: filtro.isEmpty
                  ? Icons.domain_disabled_outlined
                  : Icons.search_off,
              titulo: filtro.isEmpty
                  ? 'No perteneces a ningún cliente'
                  : 'Ningún cliente coincide',
              detalle: filtro.isEmpty
                  ? 'El Administrador del Cliente te tiene que afiliar antes '
                      'de que puedas operar en terreno.'
                  : 'Prueba con otra parte del nombre.',
            ),
            child: (lista) => Column(
              children: [
                for (final c in _filtrarClientes(lista, filtro)) ...[
                  _FilaCliente(
                    cliente: c,
                    elegido: c.id == sesion.cliente,
                    cargando: _eligiendo == c.id,
                    instalaciones: c.id == sesion.cliente
                        ? plantas.valueOrNull?.total
                        : null,
                    onTap: () => _elegirCliente(c),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ----------------------------------------------- INSTALACIÓN ----
          const SgRotulo('Instalación'),
          const SizedBox(height: 12),
          if (!sesion.tieneCliente)
            SgAviso('Elige primero el cliente.',
                icono: Icons.arrow_upward, color: sg.tinta2)
          else
            EstadoAsync<Paginado<ClienteInstalacion>>(
              valor: plantas,
              onReintentar: () => ref.invalidate(plantasProvider),
              estaVacio: (p) => _filtrarPlantas(p.datos, filtro).isEmpty,
              vacio: EstadoVacio(
                icono: filtro.isEmpty
                    ? Icons.factory_outlined
                    : Icons.search_off,
                titulo: filtro.isEmpty
                    ? 'Sin instalaciones autorizadas'
                    : 'Ninguna instalación coincide',
                detalle: filtro.isEmpty
                    ? 'Tu perfil no tiene plantas asignadas en este cliente. '
                        'Pídeselo al administrador de tu empresa.'
                    : 'Prueba con otra parte del nombre.',
              ),
              child: (p) => Column(
                children: [
                  for (final i in _filtrarPlantas(p.datos, filtro)) ...[
                    _FilaInstalacion(
                      instalacion: i,
                      elegida: i.cin_id == elegida?.cin_id,
                      onTap: () =>
                          ref.read(instalacionProvider.notifier).state = i,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<ClienteElegibleModel> _filtrarClientes(
          List<ClienteElegibleModel> l, String f) =>
      f.isEmpty
          ? l
          : l.where((c) => c.nombre.toLowerCase().contains(f)).toList();

  List<ClienteInstalacion> _filtrarPlantas(
          List<ClienteInstalacion> l, String f) =>
      f.isEmpty
          ? l
          : l
              .where((i) =>
                  i.cin_nombre.toLowerCase().contains(f) ||
                  (i.cin_direccion ?? '').toLowerCase().contains(f))
              .toList();
}

/// El buscador de 52 en píldora. Es el único campo del kit con radio 999, y
/// solo aparece cuando lo que hay debajo es una lista que puede ser larga.
class _Buscador extends StatelessWidget {
  const _Buscador({required this.controlador, required this.onCambio});

  final TextEditingController controlador;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SgRadius.pill),
        boxShadow: sg.e1,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: sg.campo,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 21, color: sg.tinta3),
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                controller: controlador,
                onChanged: onCambio,
                style: sora(16, 500, color: sg.tinta),
                cursorColor: sg.primario,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Buscar cliente o instalación',
                  hintStyle: sora(16, 500, color: sg.tinta3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaCliente extends StatelessWidget {
  const _FilaCliente({
    required this.cliente,
    required this.elegido,
    required this.cargando,
    required this.onTap,
    this.instalaciones,
  });

  final ClienteElegibleModel cliente;
  final bool elegido;
  final bool cargando;
  final VoidCallback onTap;
  final int? instalaciones;

  /// Las iniciales salen del nombre que devuelve el servidor.
  String get _iniciales {
    final partes = cliente.nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.length > 2)
        .toList();
    if (partes.isEmpty) {
      return cliente.nombre.characters.take(2).toString().toUpperCase();
    }
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.all(15),
      elegida: elegido,
      onTap: cargando ? null : onTap,
      child: Row(
        children: [
          // El logo de la empresa cuando lo hay, y las iniciales cuando no.
          // La inicial no es un respaldo pobre: es lo que se ve mientras nadie
          // haya subido el logo desde la web, y una empresa recién dada de
          // alta no tiene por qué verse rota.
          if (cliente.logoRuta != null)
            SigmaImagen(
              ruta: cliente.logoRuta,
              ancho: 48,
              alto: 48,
              radio: SgRadius.icono48,
              ajuste: BoxFit.contain,
              iconoVacio: Icons.business_outlined,
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: elegido ? sg.tinte(sg.acentoTexto) : sg.up,
                borderRadius: BorderRadius.circular(SgRadius.icono48),
              ),
              alignment: Alignment.center,
              child: Text(_iniciales,
                  style: sora(16, 700,
                      color: elegido ? sg.acentoTexto : sg.tinta2)),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente.nombre,
                    style: sora(17, 600, color: sg.tinta),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  instalaciones == null
                      ? 'Toca para entrar'
                      : '$instalaciones ${instalaciones == 1 ? "instalación" : "instalaciones"}',
                  style: sora(13, 500, color: sg.tinta3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (cargando)
            const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(strokeWidth: 2.4))
          else if (elegido)
            Icon(Icons.check_circle, size: 23, color: sg.primario)
          else
            Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
        ],
      ),
    );
  }
}

class _FilaInstalacion extends ConsumerWidget {
  const _FilaInstalacion({
    required this.instalacion,
    required this.elegida,
    required this.onTap,
  });

  final ClienteInstalacion instalacion;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;

    // El badge dice si los datos de esta instalación ya están en el teléfono.
    // **Sale de la sincronización real**, no de una suposición: si el
    // manifiesto todavía no bajó, no se afirma nada.
    final sinc = ref.watch(sincronizacionProvider);
    final alDia = sinc.termino && sinc.fallidos == 0;

    return SgCard(
      padding: const EdgeInsets.all(15),
      elegida: elegida,
      colorAnillo: SgColor.tealSolido,
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.factory,
              size: 25, color: elegida ? sg.acentoTexto : sg.tinta3),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instalacion.cin_nombre,
                    style: sora(16, 600, color: sg.tinta),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (elegida && alDia)
                  SgBadge('Datos al día',
                      color: sg.verdeTexto,
                      icono: Icons.cloud_done_outlined,
                      chico: true)
                else if ((instalacion.cin_direccion ?? '').isNotEmpty)
                  Text(instalacion.cin_direccion!,
                      style: sora(13, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis)
                else
                  Text('Toca para elegirla',
                      style: sora(13, 500, color: sg.tinta3)),
              ],
            ),
          ),
          if (elegida) ...[
            const SizedBox(width: 10),
            const Icon(Icons.check_circle,
                size: 21, color: SgColor.tealSolido),
          ],
        ],
      ),
    );
  }
}
