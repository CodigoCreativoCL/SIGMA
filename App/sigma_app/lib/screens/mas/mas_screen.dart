import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/sincronizacion_provider.dart';
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
import '../sigma_ai/sigma_ai_screen.dart';
import '../perfil/mi_perfil_screen.dart';
import '../permiso_trabajo/permisos_trabajo_screen.dart';
import '../seleccion/seleccion_contexto_screen.dart';
import '../trabajo/mi_trabajo_screen.dart';
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
  // Los cuatro tipos abren la MISMA bandeja, cada uno en su pestaña. Así una
  // ruta que el administrador registre en `Menus` sigue funcionando, y no
  // aterriza en una pantalla distinta de la que se ve desde la barra.
  'app://ordenes-trabajo': (_) =>
      const MiTrabajoScreen(inicial: TipoTrabajo.ordenes),
  'app://checklist': (_) => const MiTrabajoScreen(inicial: TipoTrabajo.pautas),
  'app://tareas': (_) => const MiTrabajoScreen(inicial: TipoTrabajo.tareas),
  'app://bitacora': (_) => const MiTrabajoScreen(inicial: TipoTrabajo.bitacora),
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
    /* Lo que ya tiene sitio propio no se repite acá.

       A la barra inferior y a la rejilla se suman ahora los cuatro tipos de
       la bandeja «Mi trabajo»: ordenes, tareas, pautas y bitacora. Volver a
       listarlos en «Más» daria dos caminos al mismo sitio, y el segundo enseña
       que el primero no era el bueno. */
    const yaVisible = {
      // En la barra inferior y en la rejilla del inicio.
      'app://inicio',
      'app://escaneo',
      'app://alertas',
      // En la bandeja «Mi trabajo», con sus pestañas.
      'app://permisos-trabajo',
      'app://ordenes-trabajo',
      'app://tareas',
      'app://checklist',
      'app://bitacora',
      /* Y en ESTA misma pantalla: «Mi perfil» es la tarjeta de arriba y
         «Sincronización» es la primera fila de «Este teléfono». Listarlas otra
         vez mas abajo era pedirle a la persona que eligiera entre dos filas
         que llevan al mismo sitio. */
      'app://mi-perfil',
      'app://sincronizacion',
    };

    /* Solo lo que se puede abrir de verdad.

       Antes entraba todo lo que el servidor mandara y las rutas sin pantalla
       se dibujaban en gris con un aviso al tocarlas. La intencion era buena
       —«avisar que falta una pantalla es mejor que abrir una en blanco»— pero
       en la practica el menu se llenaba de filas muertas que solo sirven para
       decir que no sirven, y la persona las toca una vez, lee el aviso y
       vuelve a tocarlas la semana siguiente.

       Que una ruta registrada en `Menus` no tenga pantalla es un asunto de
       quien construye la app, no de quien la usa: se ve en el log de la ruta
       que no resolvio, no en la cara del tecnico. */
    final extra = <MenuNodo>[
      for (final n in menu)
        ...(n.hijos.isEmpty ? [n] : n.hijos).where(
          (h) =>
              h.ruta != null &&
              !yaVisible.contains(h.ruta) &&
              rutasApp[h.ruta] != null,
        ),
    ];

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Más', tamanoTitulo: 23),
      body: ListView(
        padding: context.conBarraSistema(
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          // ---- Quién soy y dónde estoy ----
          SgCard(
            padding: const EdgeInsets.all(15),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MiPerfilScreen()),
            ),
            child: Row(
              children: [
                SgAvatar(
                  perfil?.iniciales ?? '?',
                  id: sesion.usuario,
                  lado: 48,
                  ruta: perfil?.FOTO_RUTA,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perfil?.nombreCompleto ?? sesion.saludo,
                        style: sora(17, 600, color: sg.tinta),
                        overflow: TextOverflow.ellipsis,
                      ),
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

          /* ---- Trabajo: LO QUE EL SERVIDOR AUTORIZA, NO UNA LISTA EN DART

             Estas filas estaban escritas a mano y se dibujaban para todos:
             un bodeguero veía «Mis órdenes de trabajo» y un técnico veía
             «Existencias», tuvieran o no el permiso. Al tocarlas, el servidor
             respondía 403 — un botón que siempre falla es un botón roto.

             Y es exactamente lo que la arquitectura prohíbe: «el menú se arma
             desde `GET /menus`, jamás una lista en Dart» (Arquitectura §7).
             Con dos modelos de permisos, el día que se revoque uno la web lo
             esconde y el teléfono no.

             Ahora el rótulo de cada fila y su ícono siguen siendo de la app
             —el servidor manda rutas, no diseño— pero **qué filas existen lo
             decide el menú de esta persona**. ---- */
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
                    builder: (_) => const SincronizacionScreen(),
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: OutboxService.instance.pendientes,
                builder: (_, n, _) => SgFila(
                  icono: Icons.cloud_upload_outlined,
                  texto: 'Pendientes de envío',
                  colorIcono: n > 0 ? sg.ambarTexto : null,
                  derecha: n == 0 ? null : SgContador(n, color: SgColor.ambar),
                  chevron: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendientesScreen()),
                  ),
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
                    builder: (_) => const SeleccionContextoScreen(),
                  ),
                ),
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
                    chevron: true,
                    onTap: () {
                      // No puede ser nulo: la lista ya filtro lo que no abre.
                      final destino = rutasApp[h.ruta]!;
                      /* Entrar a un menu refresca la sabana.

                         `asegurar` no hace nada si no hay señal o si ya
                         corrio hace menos de tres minutos, asi que pasar de
                         Ordenes a Activos y volver no dispara tres descargas.
                         Y no se espera: la pantalla abre ahora y los datos se
                         actualizan debajo. */
                      unawaited(
                        ref.read(sincronizacionProvider.notifier).asegurar(),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: destino),
                      );
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
