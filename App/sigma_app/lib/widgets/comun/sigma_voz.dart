import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/voz_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import 'sigma_v3.dart';

/// 2.4 · Panel global de voz.
///
/// Layout del artboard: hoja de radio 30 sobre el scrim; agarradera 44×4;
/// cabecera con el micrófono de 44 en rojo teñido, «Escuchando…» y el botón
/// de cerrar; **onda de 44** con trece barras; bloque TRANSCRIPCIÓN sobre
/// `up`; lista CAMPOS RECONOCIDOS con su estado por fila; y el pie de tres
/// botones —«Aplicar valores», reintentar, editar—.
///
/// ## Por qué es una hoja y no una pantalla
///
/// Dictar es un modo momentáneo sobre un formulario que ya está a medio
/// llenar. Si fuera una pantalla, entrar y salir perdería el foco del campo y
/// el desplazamiento; como hoja, el formulario sigue debajo y **se ve cómo se
/// rellena** al aplicar.
Future<List<CampoDictado>?> mostrarPanelVoz(
  BuildContext context, {
  required String titulo,
  required List<CampoDictado> Function(String texto) interpretar,
}) =>
    showModalBottomSheet<List<CampoDictado>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PanelVoz(titulo: titulo, interpretar: interpretar),
    );

class _PanelVoz extends StatefulWidget {
  const _PanelVoz({required this.titulo, required this.interpretar});

  final String titulo;
  final List<CampoDictado> Function(String texto) interpretar;

  @override
  State<_PanelVoz> createState() => _PanelVozState();
}

class _PanelVozState extends State<_PanelVoz> {
  final _voz = VozService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _voz.escuchar());
  }

  @override
  void dispose() {
    // Salir del panel corta el micrófono siempre: dejarlo abierto consumiría
    // batería y, peor, seguiría escuchando sin que nada lo muestre.
    _voz.cancelar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<EstadoVoz>(
      valueListenable: _voz.estado,
      builder: (_, estado, _) => ValueListenableBuilder<String>(
        valueListenable: _voz.texto,
        builder: (_, texto, _) {
          final campos =
              texto.trim().isEmpty ? const <CampoDictado>[] : widget.interpretar(texto);

          return Container(
            decoration: BoxDecoration(
              color: sg.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                    _Cabecera(estado: estado, motivo: _voz.motivo),
                    if (estado != EstadoVoz.noDisponible) ...[
                      const SizedBox(height: 15),
                      _Onda(escuchando: estado == EstadoVoz.escuchando),
                    ],
                    if (texto.trim().isNotEmpty) ...[
                      const SizedBox(height: 15),
                      _Transcripcion(texto: InterpreteVoz.normalizar(texto)),
                    ],
                    if (campos.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const SgRotulo('Campos reconocidos'),
                      const SizedBox(height: 9),
                      _Campos(campos: campos),
                    ],
                    const SizedBox(height: 15),
                    _Acciones(
                      estado: estado,
                      hayCampos: campos.isNotEmpty,
                      onAplicar: () => Navigator.of(context).pop(campos),
                      onReintentar: () {
                        _voz.limpiar();
                        _voz.escuchar();
                      },
                      onDetener: _voz.detener,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'El audio se descarta al obtener la transcripción. Los '
                      'valores quedan marcados como ingresados por voz.',
                      textAlign: TextAlign.center,
                      style: sora(12, 500, color: sg.tinta3, alto: 1.5),
                    ),
                    const SgBarraGestos(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.estado, this.motivo});

  final EstadoVoz estado;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final escuchando = estado == EstadoVoz.escuchando;
    final roto = estado == EstadoVoz.noDisponible;

    final (String titulo, String detalle) = switch (estado) {
      EstadoVoz.escuchando => (
          'Escuchando…',
          'Habla con normalidad. Toca detener al terminar.'
        ),
      EstadoVoz.transcrito => (
          'Listo',
          'Revisa lo que entendió antes de aplicarlo.'
        ),
      EstadoVoz.noDisponible => (
          'Sin dictado',
          motivo ?? 'Este teléfono no tiene reconocimiento de voz.'
        ),
      _ => ('Preparando el micrófono…', 'Un momento.'),
    };

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: sg.tinte(roto ? sg.tinta3 : sg.rojoTexto),
            shape: BoxShape.circle,
          ),
          child: Icon(
            roto ? Icons.mic_off : (escuchando ? Icons.mic : Icons.check),
            size: 23,
            color: roto ? sg.tinta3 : sg.rojoTexto,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: sora(17, 600, color: sg.tinta)),
              const SizedBox(height: 3),
              Text(detalle,
                  style: sora(12, 500, color: sg.tinta3, alto: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SgBotonIcono(Icons.close,
            fondo: sg.up,
            color: sg.tinta,
            tamano: 20,
            onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// La onda de 44 con trece barras.
///
/// **Se mueve con el nivel real del micrófono**, no con una animación en
/// bucle. Es lo único que distingue «te estoy escuchando» de «la app se
/// colgó», y una animación falsa mentiría justo cuando el micrófono no está
/// tomando nada —que es el caso que hay que poder ver—.
class _Onda extends StatelessWidget {
  const _Onda({required this.escuchando});

  final bool escuchando;

  /// Alturas de reposo, para que la onda no sea una línea plana.
  static const _base = [
    0.22, 0.44, 0.70, 1.00, 0.62, 0.86, 0.38, 0.56, 0.74, 0.30, 0.48, 0.26, 0.18
  ];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      height: 44,
      child: ValueListenableBuilder<double>(
        valueListenable: VozService.instance.nivel,
        builder: (_, nivel, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _base.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 140),
                  tween: Tween(
                    begin: 0.18,
                    end: escuchando
                        // El centro reacciona más que los extremos: así la
                        // onda se lee como una voz y no como un ecualizador.
                        ? (_base[i] * (0.28 + nivel * 0.85))
                            .clamp(0.14, 1.0)
                        : _base[i] * 0.35,
                  ),
                  builder: (_, alto, _) => FractionallySizedBox(
                    heightFactor: alto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: alto > 0.5
                            ? sg.primario
                            : (alto > 0.3 ? sg.tinte(sg.primario) : sg.up2),
                        borderRadius: BorderRadius.circular(SgRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Transcripcion extends StatelessWidget {
  const _Transcripcion({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sg.up,
        borderRadius: BorderRadius.circular(SgRadius.campo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SgRotulo('Transcripción', color: sg.tinta3)),
              Icon(Icons.edit_outlined, size: 14, color: sg.primarioTexto),
              const SizedBox(width: 6),
              Text('Editable al aplicar',
                  style: sora(12, 600, color: sg.primarioTexto)),
            ],
          ),
          const SizedBox(height: 8),
          Text('“$texto”',
              style: sora(15, 500, color: sg.tinta, alto: 1.6)),
        ],
      ),
    );
  }
}

class _Campos extends StatelessWidget {
  const _Campos({required this.campos});

  final List<CampoDictado> campos;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      decoration: BoxDecoration(
        color: sg.up,
        borderRadius: BorderRadius.circular(SgRadius.campo),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < campos.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: sg.div)),
              ),
              child: _FilaCampo(campo: campos[i]),
            ),
        ],
      ),
    );
  }
}

class _FilaCampo extends StatelessWidget {
  const _FilaCampo({required this.campo});

  final CampoDictado campo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final largo = campo.valor.length > 24;

    final icono = campo.confirmar ? Icons.error_outline : Icons.check_circle;
    final color = campo.confirmar ? sg.ambarTexto : sg.verdeTexto;

    // Un valor largo —una observación— no cabe en una fila de 52: pasa a dos
    // líneas en vez de recortarse, porque lo que se recorta no se revisa.
    if (largo) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 19, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(campo.rotulo, style: sora(14, 500, color: sg.tinta2)),
                  const SizedBox(height: 3),
                  Text(campo.valor,
                      style: sora(14, 500, color: sg.tinta, alto: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icono, size: 19, color: color),
            const SizedBox(width: 11),
            Expanded(
                child: Text(campo.rotulo,
                    style: sora(14, 500, color: sg.tinta2))),
            Text(campo.valor,
                style: sora(14, 600, color: sg.tinta, tabular: true)),
            if (campo.unidad != null) ...[
              const SizedBox(width: 6),
              SgUnidad(campo.unidad!),
            ],
            if (campo.confirmar) ...[
              const SizedBox(width: 8),
              SgBadge('Confirmar', color: sg.ambarTexto, chico: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.estado,
    required this.hayCampos,
    required this.onAplicar,
    required this.onReintentar,
    required this.onDetener,
  });

  final EstadoVoz estado;
  final bool hayCampos;
  final VoidCallback onAplicar;
  final VoidCallback onReintentar;
  final VoidCallback onDetener;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final escuchando = estado == EstadoVoz.escuchando;

    if (estado == EstadoVoz.noDisponible) {
      return SgBoton('Escribir a mano',
          icono: Icons.keyboard_outlined,
          primario: false,
          onTap: () => Navigator.of(context).pop());
    }

    return Row(
      children: [
        Expanded(
          child: escuchando
              ? SgBoton('Detener',
                  icono: Icons.stop_circle_outlined,
                  color: sg.tinte(sg.rojoTexto),
                  colorTexto: sg.rojoTexto,
                  colorIcono: sg.rojoTexto,
                  onTap: onDetener)
              : SgBoton('Aplicar valores',
                  icono: Icons.check,
                  onTap: hayCampos ? onAplicar : null),
        ),
        const SizedBox(width: 9),
        SgBotonIcono(Icons.restart_alt,
            fondo: sg.up, color: sg.tinta, lado: 52, tamano: 21,
            onTap: onReintentar),
      ],
    );
  }
}

/// Escribe en un campo lo que se dictó, **dejando el cursor al final**.
///
/// `controlador.text = v` parece equivalente y no lo es: el setter de Flutter
/// deja la selección en `offset: -1`, o sea sin cursor. El texto aparece, pero
/// al tocar el campo para corregir una cifra el cursor salta al principio y el
/// primer dígito que se escriba queda delante del valor dictado. En terreno
/// eso se ve como «la app cambió sola el número».
void escribirDictado(TextEditingController controlador, String texto) {
  controlador.value = TextEditingValue(
    text: texto,
    selection: TextSelection.collapsed(offset: texto.length),
  );
}

/// El botón de micrófono que va **dentro** de un campo, o en el pie.
///
/// Es el otro lado de §2: el panel global captura una frase con varios datos;
/// este dicta un campo suelto. Abre el mismo panel, pero interpretando solo
/// para ese campo, y devuelve el valor ya listo.
///
/// ## Los dos modos, y por qué hacen falta los dos
///
/// [onValor] entrega **una** cadena: sirve para el micrófono que vive dentro
/// de un campo, donde solo hay un destino posible.
///
/// [onCampos] entrega la lista completa. Es la que necesita el micrófono
/// grande del pie, porque en terreno se dicta la frase entera —«vibración 8
/// coma 4, ruido en el acople»— y ahí hay **dos** destinos: la cifra y la
/// observación. Con solo [onValor] la observación se perdía en silencio: se
/// veía reconocida en el panel y no llegaba a ningún campo.
class SgMicrofonoCampo extends StatelessWidget {
  const SgMicrofonoCampo({
    super.key,
    required this.rotulo,
    this.onValor,
    this.onCampos,
    this.unidadEsperada,
    this.soloTexto = false,
    this.lado = 44,
  }) : assert(onValor != null || onCampos != null,
            'Un micrófono sin destino no sirve de nada.');

  final String rotulo;

  /// El valor del campo principal —la cifra, o la frase si [soloTexto]—.
  final ValueChanged<String>? onValor;

  /// Todo lo que se reconoció, para repartirlo por `clave`.
  final ValueChanged<List<CampoDictado>>? onCampos;

  final String? unidadEsperada;

  /// Para una observación: se pega la frase entera en vez de buscar una cifra.
  final bool soloTexto;

  final double lado;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: lado,
      height: lado,
      child: Material(
        color: sg.tinte(sg.primario),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final campos = await mostrarPanelVoz(
              context,
              titulo: rotulo,
              interpretar: (t) => soloTexto
                  ? [
                      CampoDictado(
                          clave: 'texto',
                          rotulo: rotulo,
                          valor: InterpreteVoz.normalizar(t))
                    ]
                  : InterpreteVoz.paraMedicion(t,
                      rotulo: rotulo, unidadEsperada: unidadEsperada),
            );
            if (campos == null || campos.isEmpty) return;

            onCampos?.call(campos);

            if (onValor != null) {
              // El campo principal es el que corresponde a **este** micrófono,
              // no el primero de la lista: cuando se dicta «ruido en el
              // acople» sin cifra, el primero es la observación, y meterla en
              // un campo numérico lo deja con texto que no se puede guardar.
              final principal = campos.firstWhere(
                (c) => c.clave == (soloTexto ? 'texto' : 'valor'),
                orElse: () => campos.first,
              );
              if (!soloTexto && principal.clave != 'valor') return;
              onValor!(principal.valor);
            }
          },
          child: Icon(Icons.mic,
              size: max(18, lado * 0.45), color: sg.primarioTexto),
        ),
      ),
    );
  }
}
