import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/imagen_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// La foto de un activo, un repuesto o un componente.
///
/// Recibe la **ruta del blob** —la misma que guarda la base—, no una URL ni
/// un asset. Resolver esa ruta es trabajo de [ImagenService]; este widget
/// solo dibuja los tres estados que puede tener una foto en terreno:
///
///   · **cargando** — un bloque del color de la superficie, sin spinner: un
///     spinner por cada miniatura de una lista es ruido.
///   · **sin foto o sin señal** — el ícono de la entidad sobre la superficie.
///     No es un error y no se pinta de rojo: que no haya llegado la foto no
///     impide trabajar.
///   · **la foto**, recortada (`cover`), nunca deformada: estirar una pieza
///     la hace irreconocible.
class SigmaImagen extends StatefulWidget {
  const SigmaImagen({
    super.key,
    required this.ruta,
    this.ancho,
    this.alto,
    this.radio = SgRadius.card,
    this.iconoVacio = Icons.image_outlined,
    this.ajuste = BoxFit.cover,
    this.ampliable = true,
    this.titulo,
  });

  /// Ruta del blob: `contenedor/cliente/carpeta/nombre.jpg`.
  /// Nula o vacía cuando la entidad todavía no tiene foto cargada.
  final String? ruta;

  final double? ancho;
  final double? alto;
  final double radio;
  final IconData iconoVacio;
  final BoxFit ajuste;

  /// Tocar la foto la abre a pantalla completa.
  ///
  /// Va en `true` por omisión porque es lo que se espera de una foto en un
  /// teléfono, y porque en terreno **es la razón de que la foto exista**: una
  /// miniatura de 52 dp no sirve para reconocer una pieza ni para leer la
  /// placa de un motor. Se apaga donde la imagen es decoración —un logotipo,
  /// un avatar— y ampliarla no aporta nada.
  final bool ampliable;

  /// Lo que se lee sobre la foto ampliada: el código del activo, el nombre
  /// del repuesto. Sin él, una foto a pantalla completa no dice de qué es.
  final String? titulo;

  @override
  State<SigmaImagen> createState() => _SigmaImagenState();
}

class _SigmaImagenState extends State<SigmaImagen> {
  Uint8List? _bytes;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  @override
  void didUpdateWidget(SigmaImagen anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.ruta != widget.ruta) {
      _bytes = null;
      _pedir();
    }
  }

  Future<void> _pedir() async {
    final ruta = widget.ruta;
    if (ruta == null || ruta.isEmpty) {
      // Sin ruta no hay nada que esperar. Sin esto, pasar de una entidad con
      // foto a una sin foto dejaba el bloque en «cargando» para siempre: ni
      // la imagen ni el ícono de vacío.
      if (_cargando) setState(() => _cargando = false);
      return;
    }

    setState(() => _cargando = true);
    final b = await ImagenService.instance.bytes(ruta);
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    Widget contenido;
    if (_bytes != null) {
      contenido = Image.memory(
        _bytes!,
        width: widget.ancho,
        height: widget.alto,
        fit: widget.ajuste,
        gaplessPlayback: true,
      );
    } else {
      contenido = Container(
        width: widget.ancho,
        height: widget.alto,
        color: sg.up,
        alignment: Alignment.center,
        child: _cargando
            ? null
            : Icon(widget.iconoVacio,
                color: sg.tinta3,
                size: ((widget.alto ?? 48) * 0.34).clamp(16, 36)),
      );
    }

    final recortada = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radio),
      child: SizedBox(
        width: widget.ancho,
        height: widget.alto,
        child: contenido,
      ),
    );

    // Solo se puede ampliar lo que ya está: pedir la foto otra vez desde el
    // visor dejaría la pantalla en negro justo al abrirla.
    if (!widget.ampliable || _bytes == null) return recortada;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black87,
          pageBuilder: (_, _, _) =>
              _Visor(bytes: _bytes!, titulo: widget.titulo, etiqueta: widget.ruta!),
          transitionsBuilder: (_, a, _, hijo) =>
              FadeTransition(opacity: a, child: hijo),
        ),
      ),
      child: Hero(tag: 'foto:${widget.ruta}', child: recortada),
    );
  }
}

/// La foto a pantalla completa.
///
/// ## Por qué se puede arrastrar y hacer zoom
///
/// La foto de un activo se toma para mirar un detalle: una fuga, una grieta,
/// el número grabado en una placa. Verla del tamaño de la pantalla y sin
/// acercar es no verla. `InteractiveViewer` da zoom con dos dedos y arrastre,
/// que es el gesto que cualquiera ya conoce.
///
/// El fondo es negro y no el lienzo de la app: acá la foto es lo único que
/// importa, y cualquier color alrededor cambia cómo se percibe la suya.
class _Visor extends StatelessWidget {
  const _Visor({required this.bytes, required this.etiqueta, this.titulo});

  final Uint8List bytes;
  final String etiqueta;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tocar fuera cierra: es lo que se intenta antes de buscar la X.
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Hero(
              tag: 'foto:$etiqueta',
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _BotonVisor(
                    Icons.close,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  if (titulo != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        titulo!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón que se lee sobre cualquier foto, clara u oscura.
class _BotonVisor extends StatelessWidget {
  const _BotonVisor(this.icono, {required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icono, color: Colors.white, size: 22),
          ),
        ),
      );
}
