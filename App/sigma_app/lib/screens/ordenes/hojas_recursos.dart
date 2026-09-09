import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/modelos.dart';
import '../../providers/datos_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_compartir.dart';
import '../../widgets/comun/sigma_lector.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Lo que devuelve la hoja de compañero.
typedef TramoCompanero = ({
  Companero quien,
  DateTime desde,
  DateTime hasta,
  int? especialidad,
});

/// Lo que devuelve la hoja de repuesto.
typedef ConsumoRepuesto = ({
  int repuesto,
  int bodega,
  double cantidad,

  /// El estante. Nulo solo cuando la bodega no tiene ninguno: si los tiene, la
  /// hoja no deja enviar sin elegirlo.
  int? ubicacion,
  String nombre,
});

/// Elegir a quién se suma al trabajo y cuánto estuvo — HU-115.
///
/// ## Por qué el tramo es de OTRA persona
///
/// Un motor pesado no lo saca uno solo. Hoy el que registra es el único que
/// aparece, así que la orden termina firmada por uno aunque la hicieron dos, y
/// las horas de la planta salen a la mitad de lo que fueron.
///
/// `@USUARIO_TRAMO` ya existía en el SP: era la pieza que faltaba usar.
///
/// ## Por qué no reasigna la orden
///
/// El responsable no cambia: quien se suma **participa**. Reasignarla le
/// quitaría el trabajo a quien lo pidió.
class HojaCompanero extends ConsumerStatefulWidget {
  const HojaCompanero({super.key, required this.instalacionId});

  final int instalacionId;

  @override
  ConsumerState<HojaCompanero> createState() => _HojaCompaneroState();
}

class _HojaCompaneroState extends ConsumerState<HojaCompanero> {
  Companero? _elegido;
  int _minutos = 60;

  /// Lo escrito en el campo de minutos. Arranca en 60, que es el atajo del
  /// medio y el caso mas comun.
  final _minutosTexto = TextEditingController(text: '60');

  /// La especialidad por la que se está filtrando. Nula = todas.
  ///
  /// Se filtra por id y no por texto: un acento o una mayúscula rompen la
  /// comparación, y «Eléctrico» se escribe de dos formas según el teclado.
  int? _especialidad;

  @override
  void dispose() {
    _minutosTexto.dispose();
    super.dispose();
  }

  /// Que le pasa a los minutos escritos, en castellano, o nulo si estan bien.
  ///
  /// Los dos limites los hace cumplir `API_INS_ORDEN_TRABAJO_MANO_OBRA`; se
  /// repiten aca solo para AVISAR antes de enviar, no para decidir. Si el SP
  /// cambia de opinion, manda el SP.
  String? get _minutosMalos {
    final t = _minutosTexto.text.trim();
    if (t.isEmpty) return 'Escribe cuántos minutos estuvo.';

    final n = int.tryParse(t);
    if (n == null) return 'Los minutos van en números enteros.';
    if (n <= 0) return 'Tiene que ser más de cero minutos.';
    if (n > 1440) {
      return 'Un tramo no puede pasar de 24 horas (1440 minutos). Si de '
          'verdad fueron más, van en dos tramos.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final companeros = ref.watch(companerosProvider(widget.instalacionId));

    return HojaRecurso(
      titulo: 'Sumar a un compañero',
      detalle: 'Queda como participante del trabajo. El responsable no cambia.',
      children: [
        const SgRotulo('Quién participó'),
        const SizedBox(height: 9),

        /* FILTRAR POR OFICIO, NO POR NOMBRE

           Un trabajo lo hacen dos personas de oficios distintos: el mecánico
           desmonta y el eléctrico desconecta. En una planta donde no se conoce
           a todos, buscar «quién es eléctrico» es la pregunta real; buscar por
           nombre exige saber la respuesta de antemano.

           Los chips salen de las especialidades que la gente de ESTA planta
           tiene de verdad, no del catálogo entero: un filtro que siempre da
           cero ocupa sitio y enseña a ignorar la fila. Hoy la tabla
           `Usuario_Especialidad` está vacía, así que no se dibuja ninguno —y
           el día que se cargue aparecen solos, sin tocar la app—. */
        companeros.maybeWhen(
          data: (lista) {
            final oficios = <int, String>{};
            for (final c in lista) {
              final nombres = (c.ESPECIALIDADES ?? '').split(' · ');
              for (var i = 0; i < c.especialidades.length; i++) {
                if (i < nombres.length && nombres[i].trim().isNotEmpty) {
                  oficios[c.especialidades[i]] = nombres[i].trim();
                }
              }
            }

            if (oficios.isEmpty) return const SizedBox.shrink();

            final ids = oficios.keys.toList()
              ..sort((a, b) => oficios[a]!.compareTo(oficios[b]!));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ids.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return SgChip(
                        'Todos',
                        elegido: _especialidad == null,
                        onTap: () => setState(() => _especialidad = null),
                      );
                    }
                    final id = ids[i - 1];
                    return SgChip(
                      oficios[id]!,
                      elegido: _especialidad == id,
                      onTap: () => setState(() => _especialidad = id),
                    );
                  },
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.3,
          ),
          child: companeros.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SgAviso(
              e is ApiException
                  ? e.mensaje
                  : 'No se pudo cargar la lista de compañeros.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (todos) {
              final lista = _especialidad == null
                  ? todos
                  : todos
                        .where((c) => c.especialidades.contains(_especialidad))
                        .toList();

              if (lista.isEmpty) {
                return SgAviso(
                  todos.isEmpty
                      ? 'No hay nadie más asignado a esta planta. Las '
                            'asignaciones se hacen desde la web.'
                      : 'Nadie de esta planta tiene esa especialidad.',
                  icono: Icons.person_off_outlined,
                  color: sg.tinta2,
                );
              }

              /* AGRUPADA POR OFICIO, Y POR PERFIL CUANDO NO HAY OFICIO

                 En una lista plana de doce personas hay que leer la fila de
                 cada una para encontrar al electrico. Agrupada, se va al grupo
                 y se elige. `Companero.grupo` decide el encabezado —oficio si
                 lo tiene, perfil si no— y vive en el modelo porque las dos
                 hojas agrupan igual. */
              final grupos = agruparCompaneros(lista);
              final filas = <Widget>[];

              for (final g in grupos.entries) {
                filas.add(_Encabezado(g.key, cuantos: g.value.length));
                for (final c in g.value) {
                  final elegido = _elegido?.usu_id == c.usu_id;
                  filas.add(
                    SgFila(
                      texto: c.NOMBRE,
                      // El OFICIO manda sobre el perfil: para un acople
                      // eléctrico se suma al eléctrico, y «Técnico de
                      // Mantenimiento» no dice si lo es. El perfil queda de
                      // respaldo mientras las especialidades no estén cargadas.
                      detalle: c.ESPECIALIDADES ?? c.PERFIL_NOMBRE,
                      // Su foto, y si no tiene, sus iniciales.
                      iconoWidget: SgAvatar(
                        c.iniciales,
                        id: c.usu_id,
                        lado: 34,
                        ruta: c.FOTO_RUTA,
                      ),
                      derecha: Icon(
                        elegido
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: elegido ? sg.primarioTexto : sg.tinta3,
                      ),
                      onTap: () => setState(() => _elegido = c),
                    ),
                  );
                }
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: filas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => filas[i],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const SgRotulo('Cuánto estuvo'),
        const SizedBox(height: 9),
        /* LOS ATAJOS SIGUEN, PERO YA NO SON EL TECHO

           Los cuatro tramos redondos se quedan porque casi siempre aciertan:
           nadie recuerda el minuto exacto en que llegó un compañero. Pero eran
           lo ÚNICO que había, y el mayor era 4 h: un trabajo de seis horas no
           se podía registrar, aunque el SP acepta hasta 24.

           Ahora los chips solo rellenan el campo, y el campo manda. */
        Row(
          children: [
            for (final m in const [30, 60, 120, 240]) ...[
              Expanded(
                child: SgChip(
                  m < 60 ? '$m min' : '${m ~/ 60} h',
                  elegido: _minutos == m,
                  onTap: () => setState(() {
                    _minutos = m;
                    _minutosTexto.text = '$m';
                  }),
                ),
              ),
              if (m != 240) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SgCampo(
          controlador: _minutosTexto,
          icono: Icons.timer_outlined,
          hint: '60',
          teclado: TextInputType.number,
          rotulo: 'Minutos',
          onCambio: (v) => setState(() {
            final n = int.tryParse(v.trim());
            if (n != null) _minutos = n;
          }),
        ),
        /* Los dos límites los hace cumplir el SP —rechaza 0 o negativo y
           rechaza más de 1440—, y se avisan ACÁ para no descubrirlo después de
           haber elegido a la persona. El de 24 h no es un capricho: un tramo
           de treinta horas es un error de fecha, y grabarlo arruina el MTTR
           del activo por meses. */
        if (_minutosMalos != null) ...[
          const SizedBox(height: 10),
          SgAviso(
            _minutosMalos!,
            icono: Icons.error_outline,
            color: sg.rojoTexto,
          ),
        ],
        const SizedBox(height: 14),
        SgBoton(
          'Sumar al trabajo',
          icono: Icons.person_add_alt,
          onTap: (_elegido == null || _minutosMalos != null)
              ? null
              : () {
                  final ahora = DateTime.now();
                  Navigator.of(context).pop((
                    quien: _elegido!,
                    desde: ahora.subtract(Duration(minutes: _minutos)),
                    hasta: ahora,
                    // Con qué oficio participó. Si no se filtró, la primera
                    // que tenga: un tramo sin especialidad no se puede costear
                    // después, porque la tarifa depende del oficio.
                    especialidad:
                        _especialidad ??
                        (_elegido!.especialidades.isEmpty
                            ? null
                            : _elegido!.especialidades.first),
                  ));
                },
        ),
      ],
    );
  }
}

/// Elegir qué repuesto se consumió y cuánto — HU-116.
///
/// ## Por qué la lista sale de las existencias y no del catálogo
///
/// Lo que importa es **qué hay en la bodega de esta planta y cuánto queda**.
/// Ofrecer una pieza que el catálogo conoce pero la bodega no tiene manda al
/// técnico a buscar algo que no está, y ese viaje perdido es exactamente lo
/// que la app existe para evitar.
class HojaRepuesto extends ConsumerStatefulWidget {
  const HojaRepuesto({super.key, required this.ordenId});

  final int ordenId;

  @override
  ConsumerState<HojaRepuesto> createState() => _HojaRepuestoState();
}

class _HojaRepuestoState extends ConsumerState<HojaRepuesto> {
  final _buscar = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  RepuestoOrden? _elegido;
  String _filtro = '';

  /// El estante del que sale la pieza.
  ///
  /// **Obligatorio cuando la bodega tiene ubicaciones.** Sin esto el consumo
  /// respondia 400 —«ESTA BODEGA TIENE UBICACIONES: INDIQUE DE CUAL SALE O A
  /// CUAL ENTRA»— y en una bodega con estantes, que es lo normal, fallaba
  /// siempre. Se reinicia al cambiar de pieza: dos repuestos rara vez viven en
  /// el mismo estante, y arrastrar el anterior seria descontar del sitio
  /// equivocado sin que nadie lo note.
  int? _ubicacion;

  /// El último código leído que no calzó con nada. Se muestra tal cual: si la
  /// etiqueta dice «REP-6205» y no aparece, hay que poder ver QUÉ se leyó para
  /// saber si el problema es la etiqueta, la bodega o el escáner.
  String? _noEncontrado;

  @override
  void dispose() {
    _buscar.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  double? get _cuanto {
    final v = double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toString();

  /// Falso mientras la bodega tenga estantes y no se haya elegido uno, y
  /// tambien mientras la lista viaja: hasta que llegue no se sabe si hara
  /// falta, y habilitar el boton antes seria invitar al 400.
  bool get _puedeConsumir {
    if (_elegido == null) return false;

    final estantes = ref.watch(ubicacionesBodegaProvider(_elegido!.isa_bodega));

    return estantes.when(
      // Sin poder preguntar —sin señal— se deja pasar: el servidor decide, y
      // bloquear aqui dejaria el consumo imposible en el peor momento.
      error: (_, _) => true,
      loading: () => false,
      data: (lista) => lista.isEmpty || _ubicacion != null,
    );
  }

  /// Leer la etiqueta y elegir la pieza sin teclear.
  ///
  /// ## Por qué se resuelve contra la lista ya cargada
  ///
  /// Preguntarle al servidor qué es ese código sería un viaje de red delante
  /// del estante, donde casi nunca hay señal. La lista de lo que hay en esta
  /// bodega **ya está en la pantalla**: el código solo tiene que encontrarla.
  ///
  /// Se compara con el código y también con el nombre, y sin distinguir
  /// mayúsculas: las etiquetas de una planta las imprimieron cuatro personas
  /// distintas en diez años.
  Future<void> _escanear() async {
    final leido = await SgLector.abrir(
      context,
      titulo: 'Escanear el repuesto',
      ayuda: 'Apunta a la etiqueta del estante o de la caja',
    );

    if (leido == null || !mounted) return;

    final codigo = leido.trim().toLowerCase();
    final lista =
        ref.read(repuestosOrdenProvider(widget.ordenId)).valueOrNull ??
        const <RepuestoOrden>[];

    final calza = lista.where(
      (x) =>
          x.REPUESTO_CODIGO.toLowerCase() == codigo ||
          x.REPUESTO_NOMBRE.toLowerCase() == codigo,
    );

    setState(() {
      if (calza.isEmpty) {
        // No se limpia la lista: lo que se buscaba a mano sigue ahí, y el
        // aviso explica que el código no dio con nada.
        _noEncontrado = leido.trim();
        return;
      }

      _noEncontrado = null;
      _elegido = calza.first;
      _ubicacion = null;
      // Se filtra a esa pieza para que quede sola en pantalla: tras escanear,
      // ver una lista de veinte con una marcada obliga a buscarla otra vez.
      _buscar.text = calza.first.REPUESTO_CODIGO;
      _filtro = calza.first.REPUESTO_CODIGO.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final disponibles = ref.watch(repuestosOrdenProvider(widget.ordenId));

    // Pasarse del saldo lo rechaza el SP igual, pero avisar antes ahorra el
    // viaje de red y explica por qué: el número está a la vista.
    final sobrepasa =
        _elegido != null &&
        _cuanto != null &&
        _cuanto! > _elegido!.CANTIDAD_DISPONIBLE;

    return HojaRecurso(
      titulo: 'Consumir un repuesto',
      detalle:
          'Descuenta de la bodega y queda anotado en la orden, en una '
          'sola operación.',
      children: [
        Row(
          children: [
            Expanded(
              child: SgCampo(
                controlador: _buscar,
                icono: Icons.search,
                hint: 'Buscar por código o nombre',
                onCambio: (v) =>
                    setState(() => _filtro = v.toLowerCase().trim()),
              ),
            ),
            const SizedBox(width: 9),
            // Escanear la etiqueta del estante. Con guantes de nitrilo, un
            // «REP-6205» tecleado es donde más se falla, y un código mal
            // escrito devuelve una lista vacía que parece que la pieza no
            // existe.
            SgBotonIcono(
              Icons.qr_code_scanner,
              fondo: sg.tinte(sg.primario),
              color: sg.primarioTexto,
              lado: 52,
              tamano: 22,
              onTap: _escanear,
            ),
          ],
        ),
        if (_noEncontrado != null) ...[
          const SizedBox(height: 10),
          SgAviso(
            'Se leyó «$_noEncontrado» y no hay ninguna pieza con ese código '
            'con saldo en esta planta.',
            icono: Icons.search_off,
            color: sg.ambarTexto,
          ),
        ],
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.28,
          ),
          child: disponibles.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SgAviso(
              e is ApiException
                  ? e.mensaje
                  : 'No se pudieron cargar las existencias.',
              icono: Icons.error_outline,
              color: sg.rojoTexto,
            ),
            data: (lista) {
              final visibles = _filtro.isEmpty
                  ? lista
                  : lista
                        .where(
                          (x) => '${x.REPUESTO_CODIGO} ${x.REPUESTO_NOMBRE}'
                              .toLowerCase()
                              .contains(_filtro),
                        )
                        .toList();

              if (visibles.isEmpty) {
                return SgAviso(
                  _filtro.isEmpty
                      ? 'No hay existencias con saldo en esta planta.'
                      : 'Nada coincide con esa búsqueda.',
                  icono: Icons.inventory_2_outlined,
                  color: sg.tinta2,
                );
              }

              // El servidor ya las ordenó con lo compatible primero. La app no
              // vuelve a ordenar: dos criterios de orden terminan discrepando.
              final compatibles = visibles.where((x) => x.ES_COMPATIBLE).length;

              return ListView.separated(
                shrinkWrap: true,
                itemCount: visibles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = visibles[i];
                  final elegido = _elegido?.isa_id == x.isa_id;

                  // La primera que NO es compatible abre el grupo de abajo, y
                  // solo si antes hubo alguna que sí: sin compatibilidades
                  // declaradas, un aviso sobre la lista entera no dice nada.
                  final abreOtros =
                      compatibles > 0 && !x.ES_COMPATIBLE && i == compatibles;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (abreOtros) ...[
                        const SizedBox(height: 6),
                        SgAviso(
                          'De aquí abajo no está declarado que sirvan para '
                          'este equipo. Puede que sirvan igual.',
                          icono: Icons.info_outline,
                          color: sg.tinta2,
                          tenido: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                      SgFila(
                        texto: '${x.REPUESTO_CODIGO} · ${x.REPUESTO_NOMBRE}',
                        detalle:
                            '${_num(x.CANTIDAD_DISPONIBLE)} '
                            '${x.UNIDAD_SIMBOLO ?? ''} · '
                            '${x.BODEGA_NOMBRE ?? 'bodega'}',
                        icono: elegido
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        colorIcono: elegido ? sg.primarioTexto : sg.tinta3,
                        derecha: x.ES_COMPATIBLE
                            ? SgBadge(
                                'Compatible',
                                color: sg.verdeTexto,
                                icono: Icons.verified_outlined,
                                chico: true,
                              )
                            : null,
                        onTap: () => setState(() {
                          _elegido = x;
                          _ubicacion = null;
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        /* DE QUE ESTANTE SALE

           Solo aparece cuando la bodega de la pieza elegida tiene estantes: en
           una bodega de un solo hueco, preguntarlo es un tramite. Cuando los
           tiene, el SP no deja pasar el consumo sin el, y con razon: el saldo
           por ubicacion quedaria sin dueño y el proximo que vaya a buscar la
           pieza no sabria a que estante ir. */
        if (_elegido != null)
          SelectorEstante(
            bodegaId: _elegido!.isa_bodega,
            elegida: _ubicacion,
            onElegir: (v) => setState(() => _ubicacion = v),
          ),

        const SizedBox(height: 14),
        const SgRotuloCampo('Cantidad'),
        const SizedBox(height: 8),
        SgCampo(
          controlador: _cantidad,
          icono: Icons.tag,
          hint: '1',
          onCambio: (_) => setState(() {}),
        ),
        if (sobrepasa) ...[
          const SizedBox(height: 10),
          SgAviso(
            'Solo hay ${_num(_elegido!.CANTIDAD_DISPONIBLE)} '
            '${_elegido!.UNIDAD_SIMBOLO ?? ''} disponibles.',
            icono: Icons.warning_amber,
            color: sg.rojoTexto,
          ),
        ],
        const SizedBox(height: 14),
        SgBoton(
          'Consumir',
          icono: Icons.check,
          /* Si la bodega tiene estantes y no se eligio ninguno, el boton no
             responde: mas vale que no se pueda enviar a que el servidor lo
             rechace despues de haberlo llenado todo. Mientras la lista de
             estantes viaja, tampoco: no se sabe todavia si hara falta. */
          onTap:
              (_elegido == null ||
                  _cuanto == null ||
                  sobrepasa ||
                  !_puedeConsumir)
              ? null
              : () => Navigator.of(context).pop((
                  repuesto: _elegido!.isa_repuesto,
                  bodega: _elegido!.isa_bodega,
                  cantidad: _cuanto!,
                  ubicacion: _ubicacion,
                  nombre: _elegido!.REPUESTO_NOMBRE,
                )),
        ),
      ],
    );
  }
}

/// El envoltorio de las dos hojas: agarradera, título y el hueco del teclado.
class HojaRecurso extends StatelessWidget {
  const HojaRecurso({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.children,
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      decoration: BoxDecoration(
        color: sg.fondo,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SgRadius.hoja),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            // La hoja sube con el teclado: sin esto tapa el botón justo al
            // escribir la cantidad.
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
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
                Text(titulo, style: sora(17, 600, color: sg.tinta)),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: sora(13, 500, color: sg.tinta3, alto: 1.45),
                ),
                const SizedBox(height: 15),
                ...children,
                const SgBarraGestos(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El estante del que sale la pieza.
///
/// Se dibuja solo, y solo si la bodega tiene estantes: en una bodega de un
/// hueco preguntarlo es un trámite. Cuando los tiene, el SP no deja pasar el
/// movimiento sin él.
///
/// **Público a propósito.** Lo usan la hoja de consumo y la de movimientos, y
/// duplicarlo serían dos sitios donde arreglar el mismo defecto el día que la
/// regla del estante cambie.
class SelectorEstante extends ConsumerWidget {
  const SelectorEstante({
    super.key,
    required this.bodegaId,
    required this.elegida,
    required this.onElegir,
  });

  final int bodegaId;
  final int? elegida;
  final ValueChanged<int?> onElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = context.sg;
    final estantes = ref.watch(ubicacionesBodegaProvider(bodegaId));

    return estantes.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),

      /* Sin señal no se puede saber si la bodega tiene estantes. Se dice, y no
         se bloquea: el servidor decide. Callar aquí dejaría al técnico
         mirando un botón muerto sin entender por qué. */
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SgAviso(
          'No se pudo leer los estantes de esta bodega. Si tiene, el servidor '
          'va a pedir de cuál sale.',
          icono: Icons.cloud_off_outlined,
          color: sg.ambarTexto,
        ),
      ),

      data: (lista) {
        if (lista.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            const SgRotuloCampo('De qué estante sale'),
            const SizedBox(height: 4),
            Text(
              'Esta bodega tiene ${lista.length} ubicaciones. Sin decir cuál, '
              'el saldo queda sin dueño.',
              style: sora(12, 500, color: sg.tinta3, alto: 1.45),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SgChip(
                  lista[i].etiqueta,
                  elegido: elegida == lista[i].bub_id,
                  onTap: () => onElegir(lista[i].bub_id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Agrupa a los compañeros por su [Companero.grupo], conservando el orden que
/// trajo el servidor dentro de cada grupo.
///
/// Vive fuera de las dos hojas porque las dos agrupan igual: dos copias de esta
/// función se separan el día que alguien toque una.
Map<String, List<Companero>> agruparCompaneros(List<Companero> lista) {
  final salida = <String, List<Companero>>{};

  for (final c in lista) {
    salida.putIfAbsent(c.grupo, () => <Companero>[]).add(c);
  }

  /* Los grupos, por nombre. El servidor ordena a las PERSONAS y ese orden se
     conserva dentro de cada grupo; el orden de los grupos lo decide la app
     porque el servidor no sabe cómo se van a agrupar. */
  final claves = salida.keys.toList()..sort();
  return {for (final k in claves) k: salida[k]!};
}

/// El encabezado de un grupo, con cuántos hay debajo.
class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto, {required this.cuantos});

  final String texto;
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: sora(11, 700, color: sg.tinta3, espaciado: 0.6),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('$cuantos', style: sora(11, 600, color: sg.tinta3)),
        ],
      ),
    );
  }
}
