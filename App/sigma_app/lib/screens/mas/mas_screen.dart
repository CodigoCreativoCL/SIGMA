import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../services/outbox_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../alertas/alertas_screen.dart';
import '../escaneo/escaneo_screen.dart';
import '../inventario/existencias_screen.dart';
import '../pendientes/pendientes_screen.dart';
import '../checklist/checklist_screen.dart';
import '../sigma_ai/sigma_ai_screen.dart';
import '../tareas/tareas_screen.dart';
import '../ordenes/ordenes_screen.dart';
import '../perfil/mi_perfil_screen.dart';
import '../permiso_trabajo/permisos_trabajo_screen.dart';
import '../seleccion/seleccion_contexto_screen.dart';
import '../sincronizacion/sincronizacion_screen.dart';

/// El mapa de `app://…` a pantalla.
///
/// **La navegación se arma desde `GET /menus`, no desde esta lista.** El mapa
/// solo dice qué pantalla corresponde a cada ruta que el servidor manda: una
/// lista de opciones escrita en Dart crearía dos modelos de permisos, y el día
/// que se revoque uno la web lo escondería y el teléfono no.
///
/// Una ruta que llega del servidor y no está acá **no navega** y lo dice: es
/// preferible avisar que una pantalla falta a abrir una en blanco.
final rutasApp = <String, WidgetBuilder>{
  'app://mi-perfil': (_) => const MiPerfilScreen(),
  'app://escaneo': (_) => const EscaneoScreen(),
  'app://existencias': (_) => const ExistenciasScreen(),
  'app://permisos-trabajo': (_) => const PermisosTrabajoScreen(),
  'app://ordenes-trabajo': (_) => const OrdenesScreen(),
  'app://checklist': (_) => const ChecklistScreen(),
  'app://tareas': (_) => const TareasScreen(),
  'app://sigma-ai': (_) => const SigmaAiScreen(),
  'app://alertas': (_) => const AlertasScreen(),
  'app://sincronizacion': (_) => const SincronizacionScreen(),
  'app://pendientes': (_) => const PendientesScreen(),
  'app://contexto': (_) => const SeleccionContextoScreen(),
};

/// El quinto destino de la barra: todo lo que no cabe en los otros cuatro.
///
/// ## Por qué existe
///
/// La barra del v3 tiene cinco huecos y uno se lo lleva Escanear. «Más» es lo
/// que impide que esa restricción recorte la app: **cualquier pantalla que el
/// administrador registre en `Menus` aparece acá sin recompilar**, aunque no
/// tenga sitio en la barra.
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final perfil = ref.watch(miPerfilProvider).valueOrNull;
    final sesion = ref.watch(sesionProvider);
    final instalacion = ref.watch(instalacionProvider);
    final menu = ref.watch(menuProvider).valueOrNull ?? const <MenuNodo>[];

    // Lo que ya tiene su sitio en la barra o en la rejilla no se repite acá.
    const yaVisible = {
      'app://inicio',
      'app://escaneo',
      'app://alertas',
      'app://permisos-trabajo',
    };

    final extra = <MenuNodo>[
      for (final n in menu)
        ...(n.hijos.isEmpty ? [n] : n.hijos)
            .where((h) => h.ruta != null && !yaVisible.contains(h.ruta)),
    ];

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Más', tamanoTitulo: 23),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ---- Quién soy y dónde estoy ----
          SgCard(
            padding: const EdgeInsets.all(15),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MiPerfilScreen())),
            child: Row(
              children: [
                SgAvatar(perfil?.iniciales ?? '?',
                    id: sesion.usuario, lado: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(perfil?.nombreCompleto ?? sesion.saludo,
                          style: sora(17, 600, color: sg.tinta),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        [
                          sesion.clienteNombre,
                          instalacion?.cin_nombre,
                        ].where((s) => (s ?? '').isNotEmpty).join(' · '),
                        style: sora(13, 500, color: sg.tinta3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---- Lo que la app hace sola ----
          const SgRotulo('Trabajo'),
          const SizedBox(height: 10),
          SgBloque(
            filas: [
              SgFila(
                icono: Icons.assignment_outlined,
                texto: 'Mis órdenes de trabajo',
                chevron: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrdenesScreen())),
              ),
              SgFila(
                icono: Icons.fact_check_outlined,
                texto: 'Pautas de inspección',
                chevron: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChecklistScreen())),
              ),
              SgFila(
                icono: Icons.task_alt,
                texto: 'Mis tareas',
                chevron: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TareasScreen())),
              ),
              SgFila(
                icono: Icons.auto_awesome_outlined,
                texto: 'Análisis de SIGMA AI',
                chevron: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SigmaAiScreen())),
              ),
              SgFila(
                icono: Icons.warehouse_outlined,
                texto: 'Existencias de bodega',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExistenciasScreen())),
              ),
              SgFila(
                icono: Icons.assignment_turned_in_outlined,
                texto: 'Permisos de trabajo',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PermisosTrabajoScreen())),
              ),
              SgFila(
                icono: Icons.qr_code_scanner,
                texto: 'Escanear un código',
                chevron: true,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EscaneoScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- Los datos de este teléfono ----
          const SgRotulo('Este teléfono'),
          const SizedBox(height: 10),
          SgBloque(
            filas: [
              SgFila(
                icono: Icons.sync,
                texto: 'Sincronización',
                detalle: 'Bajar los datos de la instalación',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SincronizacionScreen())),
              ),
              ValueListenableBuilder<int>(
                valueListenable: OutboxService.instance.pendientes,
                builder: (_, n, _) => SgFila(
                  icono: Icons.cloud_upload_outlined,
                  texto: 'Pendientes de envío',
                  colorIcono: n > 0 ? sg.ambarTexto : null,
                  derecha: n == 0
                      ? null
                      : SgContador(n, color: SgColor.ambar),
                  chevron: true,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PendientesScreen())),
                ),
              ),
              SgFila(
                icono: Icons.swap_horiz,
                texto: 'Cambiar de contexto',
                detalle: 'Cliente e instalación',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SeleccionContextoScreen())),
              ),
            ],
          ),

          // ---- Lo que el servidor agregue ----
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SgRotulo('Mi menú'),
            const SizedBox(height: 10),
            SgBloque(
              filas: [
                for (final h in extra)
                  SgFila(
                    icono: _icono(h.ruta),
                    texto: h.nombre,
                    detalle: h.descripcion,
                    colorTexto:
                        rutasApp[h.ruta] == null ? sg.tinta3 : null,
                    chevron: true,
                    onTap: () {
                      final destino = rutasApp[h.ruta];
                      if (destino == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('«${h.nombre}» todavía no tiene '
                                'pantalla en la app.')));
                        return;
                      }
                      Navigator.push(
                          context, MaterialPageRoute(builder: destino));
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const SgBarraGestos(),
        ],
      ),
    );
  }

  static IconData _icono(String? ruta) => switch (ruta) {
        'app://mi-perfil' => Icons.person_outline,
        'app://existencias' => Icons.warehouse_outlined,
        'app://permisos-trabajo' => Icons.assignment_turned_in_outlined,
        'app://sincronizacion' => Icons.sync,
        'app://pendientes' => Icons.cloud_upload_outlined,
        _ => Icons.widgets_outlined,
      };
}
