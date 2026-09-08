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
  });

  /// Ruta del blob: `contenedor/cliente/carpeta/nombre.jpg`.
  /// Nula o vacía cuando la entidad todavía no tiene foto cargada.
  final String? ruta;

  final double? ancho;
  final double? alto;
  final double radio;
  final IconData iconoVacio;
  final BoxFit ajuste;

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radio),
      child: SizedBox(
        width: widget.ancho,
        height: widget.alto,
        child: contenido,
      ),
    );
  }
}
