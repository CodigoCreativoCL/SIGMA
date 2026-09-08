import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../providers/ia_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/sincronizacion_provider.dart';
import '../../services/outbox_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_ia.dart';
import '../../widgets/comun/sigma_imagen.dart';
import '../../widgets/comun/sigma_v3.dart';
import '../sigma_ai/analisis_screen.dart';
import '../sigma_ai/sigma_ai_screen.dart';
import '../alertas/alertas_screen.dart';
import '../escaneo/escaneo_screen.dart';
import '../mas/mas_screen.dart';
import '../trabajo/mi_trabajo_screen.dart';
import '../pendientes/pendientes_screen.dart';
import '../permiso_trabajo/permisos_trabajo_screen.dart';
import '../seleccion/seleccion_contexto_screen.dart';

/// Navega empujando una pantalla sobre la actual.
Future<T?> irA<T>(BuildContext c, Widget p) =>
    Navigator.push<T>(c, MaterialPageRoute(builder: (_) => p));

/// 5.1 · Inicio operativo — HU-121, HU-151, HU-156, HU-173.
///
/// Layout del artboard: cabecera con avatar 46, saludo 19/700 y el contexto
/// con el `unfold-more` que lo abre; tira de chips de estado; tarjeta JORNADA
/// DE HOY con la cifra 44/700 y la barra en degradado; «Siguiente sugerido»;
/// la tarjeta de SIGMA AI con su velo; el resumen de alertas; y la barra
/// inferior de cinco con **Escanear al centro**.
///
/// ## De dónde sale cada número
///
/// Ninguno está escrito acá. La jornada y el siguiente sugerido salen de los
/// permisos de trabajo vigentes, que es lo que el servidor sabe hoy; las
/// alertas, de `/alertas/resumen`; la cola, del `OutboxService`; la hora de
/// corte, de la última sincronización.
///
/// **Lo que todavía no tiene endpoint no se rellena con un número inventado.**
/// SIGMA AI (HU-175) y las órdenes de trabajo son los dos casos: la tarjeta
/// existe, es fiel al kit, y muestra su estado vacío hasta que la API los
/// exponga.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Si la sesión venía del disco y todavía no se eligió instalación, se
    // pide antes de dejar operar: sin ella, todo lo que se vea abajo mezcla
    // las plantas del cliente.
    WidgetsBinding.instance.addPostFrameCallback((_) => _asegurarContexto());
  }

  Future<void> _asegurarContexto() async {
    if (!mounted) return;
    if (ref.read(instalacionProvider) != null) return;
    if (!ref.read(sesionProvider).tieneCliente) return;

    final plantas = await ref.read(plantasProvider.future).catchError(
          (_) => const Paginado<ClienteInstalacion>(datos: []),
        );
    if (!mounted) return;

    // Con una sola instalación no se pregunta: preguntar por algo que no tiene
    // alternativa es un trámite, no una decisión.
    if (plantas.datos.length == 1) {
      ref.read(instalacionProvider.notifier).state = plantas.datos.first;
      return;
    }
    if (plantas.datos.isEmpty) return;

    await irA(context, const SeleccionContextoScreen());
  }

  Future<void> _recargar() async {
    for (final p in [
      miPerfilProvider,
      menuProvider,
      resumenAlertasProvider,
      existenciasEnAlertaProvider,
      permisosVigentesProvider,
    ]) {
      ref.invalidate(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final resumen = ref.watch(resumenAlertasProvider).valueOrNull;

    return Scaffold(
      backgroundColor: sg.fondo,
      bottomNavigationBar: SgBarraInferior(
        activo: 0,
        centro: SgDestino(
          icono: Icons.qr_code_scanner,
          texto: 'Escanear',
          onTap: () => irA(context, const EscaneoScreen()),
        ),
        destinos: [
          const SgDestino(icono: Icons.home_filled, texto: 'Inicio'),
          SgDestino(
            icono: Icons.assignment_outlined,
            texto: 'Mi trabajo',
            contador: ref.watch(ordenesTrabajoProvider).valueOrNull?.length ?? 0,
            // La bandeja única en vez de la lista de órdenes: tareas,
            // pautas y bitácora dejan de estar escondidas en «Más».
            onTap: () => irA(context, const MiTrabajoScreen()),
          ),
          SgDestino(
            icono: Icons.notifications_outlined,
            texto: 'Alertas',
            punto: (resumen?.NO_LEIDAS ?? 0) > 0,
            onTap: () => irA(context, const AlertasScreen()),
          ),
          SgDestino(
            icono: Icons.grid_view_outlined,
            texto: 'Más',
            onTap: () => irA(context, const MasScreen()),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Cabecera(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: ListView(
                  padding: context.conBarraSistema(const EdgeInsets.fromLTRB(16, 14, 16, 12)),
                  children: const [
                    _ChipsEstado(),
                    SizedBox(height: 14),
                    _Jornada(),
                    SizedBox(height: 14),
                    _Siguiente(),
                    SizedBox(height: 14),
                    _BloqueIa(),
                    SizedBox(height: 14),
                    _ResumenAlertas(),
                    SizedBox(height: 14),
                    _Cola(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── CABECERA ──

class _Cabecera extends ConsumerWidget {
  const _Cabecera();

  /// El saludo cambia con la hora del teléfono, que es la que la persona ve en
  /// su propia pantalla. Acá no importa que el reloj esté corrido: nada se
  /// guarda con esta hora.
  static String _franja() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final perfil = ref.watch(miPerfilProvider).valueOrNull;
    final sesion = ref.watch(sesionProvider);
    final instalacion = ref.watch(instalacionProvider);
    final resumen = ref.watch(resumenAlertasProvider).valueOrNull;

    final nombre = (perfil?.usu_nombre ?? sesion.saludo).trim();
    final primero = nombre.isEmpty ? '' : nombre.split(' ').first;

    final contexto = [
      if (sesion.clienteNombre.isNotEmpty) sesion.clienteNombre,
      if (instalacion != null) instalacion.cin_nombre,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
      child: Row(
        children: [
          SgAvatar(
            perfil?.iniciales ?? (primero.isEmpty ? '?' : primero[0]),
            id: sesion.usuario,
            lado: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primero.isEmpty ? _franja() : '${_franja()}, $primero',
                  style: sora(19, 700, color: sg.tinta, espaciado: -0.38),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // El contexto es tocable: cambiar de planta a media jornada es
                // normal, y esconderlo en Perfil obligaría a cuatro toques.
                InkWell(
                  onTap: () => irA(context, const SeleccionContextoScreen()),
                  borderRadius: BorderRadius.circular(SgRadius.unidad),
                  child: Row(
                    children: [
                      Icon(Icons.factory, size: 14, color: sg.acentoTexto),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          contexto.isEmpty ? 'Elegir contexto' : contexto,
                          style: sora(13, 500, color: sg.tinta2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more, size: 15, color: sg.tinta3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SgBotonNotificacion(
            Icons.notifications_outlined,
            contador: resumen?.NO_LEIDAS ?? 0,
            onTap: () => irA(context, const AlertasScreen()),
          ),
        ],
      ),
    );
  }
}

/// La tira de estado: conexión, cola y hora del último corte.
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final corte = ref.watch(sincronizacionProvider).fechaCorte;

    return Row(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SyncService.instance.enLinea,
          builder: (_, enLinea, _) => SgBadge(
            enLinea ? 'En línea' : 'Sin señal',
            color: enLinea ? sg.acentoTexto : sg.tinta3,
            punto: true,
            chico: false,
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: OutboxService.instance.pendientes,
          builder: (_, n, _) => n == 0
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => irA(context, const PendientesScreen()),
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                    child: SgBadge('$n en cola',
                        color: sg.ambarTexto,
                        icono: Icons.cloud_upload_outlined),
                  ),
                ),
        ),
        if (corte != null)
          SgBadge(DateFormat('HH:mm').format(corte.toLocal()),
              color: sg.tinta2, icono: Icons.check_circle_outline),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────── JORNADA ──

/// «Jornada de hoy».
///
/// El kit la dibuja con órdenes de trabajo. **SIGMA todavía no expone
/// órdenes**, así que la jornada se mide con los permisos de trabajo
/// vigentes, que es el otro dato que condiciona si el técnico puede intervenir
/// un equipo hoy: sin permiso al día no se abre la máquina. Cuando exista
/// `GET /ordenes`, cambia el provider y no la pantalla.
class _Jornada extends ConsumerWidget {
  const _Jornada();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final permisos = ref.watch(permisosVigentesProvider);
    final lista = permisos.valueOrNull?.datos ?? const <PermisoTrabajo>[];
    final total = permisos.valueOrNull?.total ?? 0;

    int contar(String situacion) => lista
        .where((p) => (p.SITUACION ?? '').toUpperCase() == situacion)
        .length;

    final vencidos = contar('VENCIDO');
    final porVencer = contar('POR VENCER');
    final vigentes = contar('VIGENTE');
    final avance = total == 0 ? 0.0 : (vigentes / total).clamp(0.0, 1.0);

    return SgCard(
      elevada: true,
      onTap: () => irA(context, const PermisosTrabajoScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SgRotulo('Jornada de hoy', color: sg.tinta2)),
              Text('Mi trabajo', style: sora(13, 600, color: sg.primarioTexto)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(permisos.hasValue ? '$vigentes' : '—',
                      style: sora(44, 700,
                          color: sg.tinta,
                          alto: 1,
                          espaciado: -1.32,
                          tabular: true)),
                  const SizedBox(width: 8),
                  Text('/ $total',
                      style: sora(20, 600, color: sg.tinta3, alto: 1)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('permisos al día',
                          style: sora(13, 500, color: sg.tinta2)),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SgRadius.pill),
                        child: Stack(
                          children: [
                            Container(height: 8, color: sg.up),
                            FractionallySizedBox(
                              widthFactor: avance,
                              child: Container(
                                height: 8,
                                decoration: const BoxDecoration(
                                    gradient: SgColor.gradiente),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (permisos.hasValue && total > 0) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (vencidos > 0)
                  SgBadge('$vencidos ${vencidos == 1 ? "vencido" : "vencidos"}',
                      color: sg.rojoTexto, icono: Icons.error_outline),
                if (porVencer > 0)
                  SgBadge('$porVencer por vencer',
                      color: sg.ambarTexto, icono: Icons.schedule),
                if (vigentes > 0)
                  SgBadge('$vigentes vigentes', color: sg.azulTexto),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// «Siguiente sugerido».
///
/// El kit lo sugiere por cercanía —«a 40 m de ti»—; sin geolocalización de
/// activos, acá se sugiere **el permiso que vence antes**, que es el criterio
/// que de verdad ordena el turno: lo que caduca primero es lo que hay que
/// hacer primero.
class _Siguiente extends ConsumerWidget {
  const _Siguiente();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final lista =
        ref.watch(permisosVigentesProvider).valueOrNull?.datos ?? const [];
    if (lista.isEmpty) return const SizedBox.shrink();

    final ordenados = [...lista]..sort((a, b) =>
        (a.DIAS_RESTANTES ?? 9999).compareTo(b.DIAS_RESTANTES ?? 9999));
    final p = ordenados.first;

    return SgCard(
      padding: const EdgeInsets.all(14),
      onTap: () => irA(context, const PermisosTrabajoScreen()),
      child: Row(
        children: [
          const SgFoto(lado: 56, radio: 16, icono: Icons.assignment_outlined),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SgBadge('Siguiente sugerido',
                    color: sg.primarioTexto,
                    icono: Icons.arrow_forward,
                    chico: true),
                const SizedBox(height: 5),
                Text(
                  [p.ptr_numero, p.ORDEN_TITULO ?? p.TIPO_NOMBRE]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: sora(16, 600, color: sg.tinta),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    p.ESTADO_NOMBRE,
                    if (p.DIAS_RESTANTES != null)
                      p.DIAS_RESTANTES! <= 0
                          ? 'vencido'
                          : 'vence en ${p.DIAS_RESTANTES} ${p.DIAS_RESTANTES == 1 ? "día" : "días"}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: sora(12, 500, color: sg.tinta3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: sg.primario, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, size: 22, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// El bloque de SIGMA AI — HU-173.
///
/// ## Las dos cifras son días, no porcentajes
///
/// «32 d» sale de resolver una ecuación sobre lecturas reales y se puede
/// verificar. Un porcentaje necesita una frase entera para explicar de qué es
/// —y aquí no es probabilidad de falla, es cuánta certeza tiene el modelo de
/// que el cruce caiga dentro de su horizonte—; esa frase cabe en la ficha, no
/// en una tarjeta. Poner el número sin la frase es exactamente cómo un «87 %»
/// termina repitiéndose en una reunión como si significara otra cosa.
///
/// El «± 4 d» del margen va al lado a propósito: un plazo sin margen se lee
/// como una fecha comprometida, y esto es una estimación.
class _BloqueIa extends ConsumerWidget {
  const _BloqueIa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final p = ref.watch(prediccionDestacadaProvider);

    if (p == null) {
      final sinDatos = ref.watch(vigiladosSinDatosProvider);

      // «No hay análisis» no significa lo mismo si además nadie mide nada: lo
      // primero es una buena noticia, lo segundo es un problema de operación.
      return SgIaSinDatos(
        motivo: sinDatos == 0
            ? null
            : sinDatos == 1
                ? 'Hay un equipo vigilado que nadie ha medido todavía.'
                : 'Hay $sinDatos equipos vigilados que nadie ha medido '
                    'todavía.',
      );
    }

    final variable = (p.VARIABLE_NOMBRE ?? 'La variable').toLowerCase();

    return SgTarjetaIa(
      simbolo: SgIconoIa.prediccion,
      titulo: p.ACTIVO_NOMBRE,
      detalle: p.pre_dia_restante == null
          ? 'La $variable viene en alza.'
          : 'La $variable llega al límite del equipo en unos '
              '${p.pre_dia_restante} días, si la tendencia se mantiene.',
      badge: p.SEVERIDAD_NOMBRE,
      colorBadge: p.critica
          ? sg.rojoTexto
          : p.alta
              ? sg.ambarTexto
              : sg.acentoTexto,
      cifras: [
        if (p.pre_dia_restante != null)
          ('${p.pre_dia_restante} d', 'faltan'),
        if (p.margenDias != null) ('± ${p.margenDias} d', 'margen'),
      ],
      miniatura: p.ACTIVO_FOTO == null
          ? const SgFoto(lado: 52, radio: 15)
          : SigmaImagen(
              ruta: p.ACTIVO_FOTO!, ancho: 52, alto: 52, radio: 15),
      accion: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnalisisScreen(prediccionId: p.pre_id),
      )),
      textoAccionSecundaria: 'Ver todo',
      accionSecundaria: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const SigmaAiScreen(),
      )),
    );
  }
}

class _ResumenAlertas extends ConsumerWidget {
  const _ResumenAlertas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final r = ref.watch(resumenAlertasProvider).valueOrNull;
    final abiertas = r?.ABIERTAS ?? 0;
    final noLeidas = r?.NO_LEIDAS ?? 0;

    return SgCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => irA(context, const AlertasScreen()),
      child: Row(
        children: [
          SgIconoCuadro(
            abiertas > 0
                ? Icons.notifications_active_outlined
                : Icons.notifications_none,
            color: abiertas > 0 ? sg.rojoTexto : sg.verdeTexto,
            lado: 42,
            tamanoIcono: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  abiertas == 0
                      ? 'Sin alertas activas'
                      : '$abiertas ${abiertas == 1 ? "alerta activa" : "alertas activas"}',
                  style: sora(16, 600, color: sg.tinta),
                ),
                const SizedBox(height: 2),
                Text(
                  noLeidas == 0
                      ? 'Todo revisado'
                      : '$noLeidas sin leer',
                  style: sora(12, 500, color: sg.tinta3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
        ],
      ),
    );
  }
}

/// La cola, solo cuando hay algo esperando.
///
/// Una tarjeta permanente que casi siempre dice «0 pendientes» se deja de
/// mirar, y el día que diga 3 tampoco se va a mirar.
class _Cola extends StatelessWidget {
  const _Cola();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<int>(
      valueListenable: OutboxService.instance.pendientes,
      builder: (_, n, _) => n == 0
          ? const SizedBox.shrink()
          : SgCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              onTap: () => irA(context, const PendientesScreen()),
              child: Row(
                children: [
                  SgIconoCuadro(Icons.cloud_upload_outlined,
                      color: sg.ambarTexto, lado: 42, tamanoIcono: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pendientes de envío',
                            style: sora(16, 600, color: sg.tinta)),
                        const SizedBox(height: 2),
                        Text(
                          n == 1
                              ? '1 registro esperando señal'
                              : '$n registros esperando señal',
                          style: sora(12, 500, color: sg.tinta3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 22, color: sg.tinta3),
                ],
              ),
            ),
    );
  }
}
