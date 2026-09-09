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
import '../activo/activos_screen.dart';
import '../inventario/bodegas_screen.dart';
import '../inventario/repuestos_screen.dart';
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
  // El CATALOGO —una fila por pieza— frente a las existencias —una fila por
  // bodega—. Responden preguntas distintas: «existe esto y con que codigo»
  // frente a «que esta bajo minimo».
  'app://repuestos': (_) => const RepuestosScreen(),
  'app://bodegas': (_) => const BodegasScreen(),
  // Los equipos por nombre o por area: lo que el escaner no resuelve, porque
  // el escaner sirve estando DELANTE del equipo.
  'app://activos': (_) => const ActivosScreen(),
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
      /* LA MARCA EN LA CABECERA, NO SOLO EL TITULO

         «Mas» es la pantalla donde alguien mira quien es, para que empresa
         trabaja y en que planta esta. Con el isotipo al lado del titulo la
         pantalla se lee como parte de un producto y no como un cajon de
         ajustes, y es el unico sitio de la app donde eso aporta: en la bandeja
         de trabajo el espacio es para el trabajo. */
      appBar: SgBarra(
        'Más',
        tamanoTitulo: 23,
        acciones: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SgIsotipo(alto: 26),
          ),
        ],
      ),
      body: ListView(
        padding: context.conBarraSistema(
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          /* ---- QUIEN SOY, Y SOBRE TODO DONDE ESTOY ----

             SIGMA es multi-cliente y multi-planta, y una persona puede estar
             asignada a varias. Si registra una lectura, consume un repuesto o
             cierra una OT con la planta equivocada seleccionada, el dato queda
             mal en un sistema que despues se audita, y arreglarlo es un
             movimiento manual de alguien en la web.

             Por eso el contexto sube de una linea de texto gris a lo primero
             que se ve, con el perfil a la vista —lo que puede hacer depende de
             el— y con el cambio a un toque. Antes «Cambiar de contexto» era la
             tercera fila de «Este telefono», al mismo nivel que los pendientes
             de envio: enterrado para lo que cuesta equivocarse. */
          SgCard(
            padding: const EdgeInsets.all(15),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MiPerfilScreen()),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                          if ((perfil?.PERFILES ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // El perfil decide que puede hacer: verlo aca evita
                            // la pregunta «por que no me aparece tal boton».
                            SgBadge(
                              perfil!.PERFILES!.trim(),
                              color: sg.acentoTexto,
                              chico: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- Donde esta trabajando, y como cambiarlo ----
          _Contexto(
            cliente: sesion.clienteNombre,
            planta: instalacion?.cin_nombre,
            onCambiar: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SeleccionContextoScreen(),
              ),
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
              // «Cambiar de contexto» ya no va aca: subio a la tarjeta de
              // contexto, arriba. Dos caminos al mismo sitio es justo lo que se
              // quito de esta pantalla.
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

/// Dónde está trabajando: la empresa y la planta, y cómo cambiarlas.
///
/// ## Por qué tiene tarjeta propia y no una línea de texto
///
/// SIGMA es multi-cliente y multi-planta. Registrar una lectura, consumir un
/// repuesto o cerrar una OT con la planta equivocada seleccionada deja el dato
/// mal en un sistema que después se audita, y arreglarlo es trabajo manual de
/// alguien en la web. El contexto no es un ajuste: es la condición de que todo
/// lo demás quede bien.
///
/// ## Por qué el aviso cuando no hay planta
///
/// Sin instalación elegida, la mitad de la app no tiene de dónde leer —la
/// sábana baja por planta— y la persona ve listas vacías sin saber por qué.
/// Decirlo aquí, donde está el botón que lo arregla, es más útil que un vacío
/// en cada pantalla.
class _Contexto extends StatelessWidget {
  const _Contexto({
    required this.cliente,
    required this.planta,
    required this.onCambiar,
  });

  final String cliente;
  final String? planta;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final sinPlanta = (planta ?? '').trim().isEmpty;

    return SgCard(
      padding: const EdgeInsets.all(15),
      onTap: onCambiar,
      // Anillo solo cuando falta la planta: es lo único de esta tarjeta que
      // pide una decisión.
      elegida: sinPlanta,
      colorAnillo: sinPlanta ? sg.ambarTexto : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgIconoCuadro(
                Icons.business_outlined,
                color: sg.primarioTexto,
                lado: 40,
                tamanoIcono: 20,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DÓNDE ESTÁS TRABAJANDO',
                      style: sora(10, 700, color: sg.tinta3, espaciado: 0.7),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cliente.trim().isEmpty ? 'Sin empresa' : cliente,
                      style: sora(16, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.factory_outlined,
                          size: 13,
                          color: sinPlanta ? sg.ambarTexto : sg.tinta3,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            sinPlanta ? 'Sin planta elegida' : planta!,
                            style: sora(
                              13,
                              600,
                              color: sinPlanta ? sg.ambarTexto : sg.tinta2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // «Cambiar» escrito, no un chevrón: el chevrón dice «hay más
              // adentro» y acá lo que hay es una acción.
              SgBadge('Cambiar', color: sg.acentoTexto, chico: true),
            ],
          ),
          if (sinPlanta) ...[
            const SizedBox(height: 11),
            SgAviso(
              'Sin planta elegida, los listados bajan vacíos: la sábana de '
              'datos se descarga por planta.',
              icono: Icons.warning_amber,
              color: sg.ambarTexto,
              tenido: true,
            ),
          ],
        ],
      ),
    );
  }
}
