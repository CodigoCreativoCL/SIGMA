/// Las piezas del kit **v3**.
///
/// ## La regla de la que sale todo lo demás
///
/// **Nada lleva borde.** El v3 construye la jerarquía con tres superficies
/// —`card`, `up`, `up2`—, dos sombras y un divisor tenue entre filas
/// hermanas. Donde el v2 dibujaba un contorno de 1 px, acá hay un cambio de
/// color; donde marcaba una selección con borde de 2, acá hay un **anillo**.
///
/// El anillo importa más de lo que parece. En CSS el kit lo escribe
/// `box-shadow: 0 0 0 2px var(--pri)`, que pinta por fuera de la caja; en
/// Flutter es un `BoxShadow` con `spreadRadius: 2` y `blurRadius: 0`. Un
/// `Border` habría hecho lo mismo a la vista pero **empujando el contenido
/// dos píxeles hacia dentro al aparecer**, y una lista donde el texto salta
/// cuando eliges una fila se siente rota aunque no lo esté.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';

/// El anillo del v3: `0 0 0 <ancho>px <color>`, por fuera y sin desenfoque.
List<BoxShadow> anillo(Color color, {double ancho = 2}) => [
      BoxShadow(color: color, spreadRadius: ancho, blurRadius: 0),
    ];

// ───────────────────────────────────────────────────────────── BOTONES ──

/// El botón de acción. **Dos variantes y ninguna más.**
///
/// `primario` va relleno de morado y **proyecta su propio color** hacia abajo
/// —`0 12px 26px -14px` del morado al 95 %—, que es lo que lo levanta del
/// lienzo sin necesidad de contorno. El secundario es relleno `up`: en el v2
/// era contorno, y sin bordes esa variante dejó de existir.
class SgBoton extends StatelessWidget {
  const SgBoton(
    this.texto, {
    super.key,
    this.icono,
    this.iconoAlFinal = false,
    this.primario = true,
    this.onTap,
    this.cargando = false,
    this.colorIcono,
    this.color,
    this.colorTexto,
    this.alto = SgMedida.boton,
    this.tamanoTexto = 16,
  });

  final String texto;
  final IconData? icono;
  final bool iconoAlFinal;
  final bool primario;
  final VoidCallback? onTap;
  final bool cargando;

  /// El kit pinta el ícono de «Ingresar con huella» en teal mientras el texto
  /// queda en tinta.
  final Color? colorIcono;

  /// Para el botón destructivo y para el que va sobre una superficie de IA.
  final Color? color;
  final Color? colorTexto;

  /// 52 en el pie de pantalla; **44 dentro de una tarjeta**, que es la única
  /// otra medida que usa el kit.
  final double alto;
  final double tamanoTexto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final relleno = color ?? (primario ? sg.primario : sg.up);
    final tinta = colorTexto ?? (primario ? Colors.white : sg.tinta);

    return SizedBox(
      height: alto,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SgRadius.pill),
          boxShadow: primario && onTap != null
              ? [
                  BoxShadow(
                    color: relleno.withValues(alpha: 0.95),
                    blurRadius: 26,
                    spreadRadius: -14,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: relleno,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: cargando ? null : onTap,
            child: Center(
              child: cargando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: tinta),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icono != null && !iconoAlFinal) ...[
                          Icon(icono,
                              size: tamanoTexto + 5,
                              color: colorIcono ?? tinta),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(texto,
                              style: sora(tamanoTexto, 600, color: tinta),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (icono != null && iconoAlFinal) ...[
                          const SizedBox(width: 8),
                          Icon(icono,
                              size: tamanoTexto + 3,
                              color: colorIcono ?? tinta),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El botón de ícono: círculo de 44. Sin fondo por omisión; con `fondo: sg.up`
/// es el redondo de la barra superior del v3.
class SgBotonIcono extends StatelessWidget {
  const SgBotonIcono(
    this.icono, {
    super.key,
    this.onTap,
    this.color,
    this.fondo,
    this.tamano = 21,
    this.lado = 44,
  });

  final IconData icono;
  final VoidCallback? onTap;
  final Color? color;
  final Color? fondo;
  final double tamano;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return SizedBox(
      width: lado,
      height: lado,
      child: Material(
        color: fondo ?? Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icono, size: tamano, color: color ?? sg.tinta),
        ),
      ),
    );
  }
}

/// El botón redondo con contador montado en la esquina —la campana del
/// inicio—.
///
/// El contador lleva **anillo del color de la superficie de atrás**, no del
/// botón: es lo que lo separa cuando queda montado sobre el borde del
/// círculo. Por eso hay que decirle sobre qué está.
class SgBotonNotificacion extends StatelessWidget {
  const SgBotonNotificacion(
    this.icono, {
    super.key,
    this.onTap,
    this.contador = 0,
    this.sobre,
  });

  final IconData icono;
  final VoidCallback? onTap;
  final int contador;
  final Color? sobre;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SgBotonIcono(icono, fondo: sg.up, color: sg.tinta, onTap: onTap),
          if (contador > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                height: 20,
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: SgColor.rojo,
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                  boxShadow: anillo(sobre ?? sg.fondo),
                ),
                alignment: Alignment.center,
                child: Text(contador > 99 ? '99+' : '$contador',
                    style: sora(11, 700, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── TEXTO ──

/// El rótulo de un campo: **13/600 en tinta2**, y en `primarioTexto` cuando el
/// campo está enfocado.
///
/// Cambió respecto del v2, donde era 12/600 en versalitas con `letter-spacing`
/// 1.2. El v3 lo escribe en caja normal: es la etiqueta de un dato, no un
/// encabezado de sección, y las versalitas lo hacían competir con el rótulo de
/// bloque que sí las lleva.
class SgRotuloCampo extends StatelessWidget {
  const SgRotuloCampo(this.texto, {super.key, this.enfocado = false});

  final String texto;
  final bool enfocado;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Text(texto,
        style: sora(13, 600,
            color: enfocado ? sg.primarioTexto : sg.tinta2));
  }
}

/// El rótulo de sección: 13/600 con `letter-spacing` 1.1, en versalitas y
/// tinta3. «CLIENTE», «ESTADO DEL ENLACE», «JORNADA DE HOY».
class SgRotulo extends StatelessWidget {
  const SgRotulo(this.texto, {super.key, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: sora(13, 600,
            color: color ?? context.sg.tinta3, espaciado: 1.1),
      );
}

/// La cabecera de sección con una acción a la derecha: «MEDIDORES · Ver los 2».
class SgRotuloConAccion extends StatelessWidget {
  const SgRotuloConAccion(this.texto,
      {super.key, required this.accion, this.onTap});

  final String texto;
  final String accion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Row(
      children: [
        Expanded(child: SgRotulo(texto)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SgRadius.unidad),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(accion,
                style: sora(13, 600, color: sg.primarioTexto)),
          ),
        ),
      ],
    );
  }
}

/// El título grande de pantalla: 26/700 con `letter-spacing` −.02em.
class SgTitulo extends StatelessWidget {
  const SgTitulo(this.texto, {super.key, this.tamano = 26, this.color});

  final String texto;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: sora(tamano, 700,
            color: color ?? context.sg.tinta,
            alto: 1.2,
            espaciado: tamano * -0.02),
      );
}

/// La píldora de unidad: la clase `.u` del kit.
///
/// **Monoespaciada y a media altura.** Existe porque «42 MB» y «75 kW» mezclan
/// una cifra que se compara con una unidad que no: poner la unidad en otra
/// caja evita que el ojo la lea como parte del número, y el monoespaciado la
/// alinea entre filas de una lista.
class SgUnidad extends StatelessWidget {
  const SgUnidad(this.texto,
      {super.key, this.grande = false, this.dentro = false});

  final String texto;

  /// La variante `.u-lg`: 13 px en vez de 11.
  final bool grande;

  /// La variante `.u-in`: sobre un chip de color, hereda su tinta.
  final bool dentro;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final estilo = DefaultTextStyle.of(context).style;

    return Container(
      padding: grande
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dentro ? Colors.white.withValues(alpha: 0.10) : sg.up2,
        borderRadius:
            BorderRadius.circular(grande ? 9 : SgRadius.unidad),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Consolas', 'Menlo', 'monospace'],
          fontSize: grande ? 13 : 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.06 * (grande ? 13 : 11),
          color: dentro
              ? estilo.color?.withValues(alpha: 0.92)
              : sg.tinta2,
        ),
      ),
    );
  }
}

/// Una cifra con su unidad al lado, con la píldora `.u`.
class SgCifra extends StatelessWidget {
  const SgCifra(
    this.valor, {
    super.key,
    this.unidad,
    this.tamano = 20,
    this.color,
  });

  final String valor;
  final String? unidad;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(valor,
              style: sora(tamano, 700,
                  color: color ?? context.sg.tinta,
                  alto: 1,
                  espaciado: tamano * -0.025,
                  tabular: true)),
          if (unidad != null) ...[
            const SizedBox(width: 6),
            SgUnidad(unidad!, grande: tamano >= 24),
          ],
        ],
      );
}

// ────────────────────────────────────────────────────────────── BADGES ──

/// La píldora de estado: **alto 26**, padding 0 10, radio 999, fondo teñido y
/// texto del mismo matiz.
///
/// El `color` que se pasa es el **de texto** del modo activo —`sg.rojoTexto`,
/// no `SgColor.rojo`—, y el fondo sale de teñirlo. Es lo que hace que el mismo
/// badge se lea en oscuro y en claro con el mismo código.
class SgBadge extends StatelessWidget {
  const SgBadge(
    this.texto, {
    super.key,
    required this.color,
    this.icono,
    this.punto = false,
    this.chico = false,
    this.solido = false,
    this.unidad,
  });

  final String texto;
  final Color color;
  final IconData? icono;

  /// El punto de 7 px en vez de un ícono: «● En línea».
  final bool punto;

  /// La variante de 24, para dentro de una tarjeta apretada.
  final bool chico;

  /// Relleno pleno con texto oscuro: solo para el perfil de la persona, que no
  /// es un estado que cambie.
  final bool solido;

  /// Una unidad al final, en la píldora `.u`.
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tinta = solido ? SgColor.navy : color;

    return Container(
      height: chico ? SgMedida.badgeChico : SgMedida.badge,
      padding: EdgeInsets.symmetric(horizontal: chico ? 9 : 10),
      decoration: BoxDecoration(
        color: solido ? color : sg.tinte(color),
        borderRadius: BorderRadius.circular(SgRadius.pill),
      ),
      child: DefaultTextStyle(
        style: sora(12, 600, color: tinta),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (punto) ...[
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ] else if (icono != null) ...[
              Icon(icono, size: chico ? 13 : 14, color: tinta),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(texto,
                  style: sora(12, 600, color: tinta),
                  overflow: TextOverflow.ellipsis),
            ),
            if (unidad != null) ...[
              const SizedBox(width: 5),
              SgUnidad(unidad!, dentro: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// El chip de filtro: **alto 28**, padding 0 11.
///
/// Elegido lleva el tinte del acento; sin elegir, `up`. Sin bordes en ninguno
/// de los dos estados —los diferencia la superficie—.
class SgChip extends StatelessWidget {
  const SgChip(
    this.texto, {
    super.key,
    required this.elegido,
    this.onTap,
    this.icono,
    this.contador,
    this.colorContador,
  });

  final String texto;
  final bool elegido;
  final VoidCallback? onTap;
  final IconData? icono;
  final int? contador;
  final Color? colorContador;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final tinta = elegido ? sg.acentoTexto : sg.tinta2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.pill),
      child: Container(
        height: SgMedida.chip,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: elegido ? sg.tinte(sg.acentoTexto) : sg.up,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 14, color: tinta),
              const SizedBox(width: 6),
            ],
            Text(texto, style: sora(12, 600, color: tinta)),
            if (contador != null && contador! > 0) ...[
              const SizedBox(width: 7),
              SgContador(contador!, color: colorContador ?? sg.primario),
            ],
          ],
        ),
      ),
    );
  }
}

/// El contador sólido: 20 de alto, o 17 cuando va montado en la barra
/// inferior.
class SgContador extends StatelessWidget {
  const SgContador(this.n,
      {super.key, required this.color, this.chico = false, this.sobre});

  final int n;
  final Color color;
  final bool chico;

  /// La superficie de atrás, para el anillo que lo separa cuando va montado.
  final Color? sobre;

  @override
  Widget build(BuildContext context) {
    final alto = chico ? 17.0 : 20.0;

    return Container(
      height: alto,
      constraints: BoxConstraints(minWidth: alto),
      padding: EdgeInsets.symmetric(horizontal: chico ? 4 : 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SgRadius.pill),
        boxShadow: sobre == null ? null : anillo(sobre!),
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style: sora(chico ? 10 : 11, 700, color: Colors.white)),
    );
  }
}

// ───────────────────────────────────────────────────────────── TARJETA ──

/// La tarjeta del v3: **radio 22, sin borde**, sombra `e1`.
///
/// `elegida` le pone el anillo morado y la sube a `e2`. Es la única variante
/// de selección que existe: en el v2 había un borde de 2 y una franja de
/// color a la izquierda, y ninguna de las dos sobrevivió.
class SgCard extends StatelessWidget {
  const SgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = SgRadius.card,
    this.onTap,
    this.elegida = false,
    this.colorAnillo,
    this.color,
    this.elevada = false,
    this.sinSombra = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final VoidCallback? onTap;

  /// Anillo de 2 y sombra `e2`.
  final bool elegida;

  /// El anillo es morado por omisión; la instalación elegida lo lleva teal.
  final Color? colorAnillo;

  final Color? color;

  /// Sombra `e2` sin estar elegida: el hero, la tarjeta que pide una decisión.
  final bool elevada;

  final bool sinSombra;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final radios = BorderRadius.circular(radio);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radios,
        boxShadow: [
          if (elegida) ...anillo(colorAnillo ?? sg.primario),
          if (!sinSombra) ...(elegida || elevada ? sg.e2 : sg.e1),
        ],
      ),
      child: Material(
        color: color ?? sg.card,
        borderRadius: radios,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// El cuadro de ícono teñido.
///
/// El kit lo usa en cuatro tamaños con radio propio: 42/14, 44/15, 48/16 y
/// 56/16. No es una escala lineal, así que el radio va con el lado y no se
/// calcula.
class SgIconoCuadro extends StatelessWidget {
  const SgIconoCuadro(
    this.icono, {
    super.key,
    required this.color,
    this.lado = 44,
    this.radio,
    this.tamanoIcono,
    this.fondo,
  });

  final IconData icono;
  final Color color;
  final double lado;
  final double? radio;
  final double? tamanoIcono;

  /// Por omisión el tinte del color; `sg.up2` para el cuadro neutro.
  final Color? fondo;

  double get _radio =>
      radio ??
      switch (lado) {
        <= 42 => SgRadius.icono42,
        <= 44 => SgRadius.icono44,
        <= 52 => 15.0,
        _ => SgRadius.icono48,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: fondo ?? context.sg.tinte(color),
        borderRadius: BorderRadius.circular(_radio),
      ),
      alignment: Alignment.center,
      child: Icon(icono, size: tamanoIcono ?? lado * 0.5, color: color),
    );
  }
}

/// El avatar redondo con iniciales.
///
/// El color sale de `AppColors.avatarDe(id)`, **el mismo criterio y la misma
/// paleta que `SitioBase.Avatar` en la web**. Si saliera de un hash del
/// nombre, la misma persona sería de un color en el navegador y de otro en el
/// teléfono, y el color dejaría de servir para reconocerla.
class SgAvatar extends StatelessWidget {
  const SgAvatar(this.iniciales, {super.key, this.id = 0, this.lado = 46});

  final String iniciales;
  final int id;
  final double lado;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          color: AppColors.avatarDe(id),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(iniciales,
            style: sora(lado * 0.33, 700,
                color: const Color(0xFFF8FAFC),
                espaciado: lado * -0.008,
                tabular: true)),
      );
}

/// El cuadro de una foto que vive en el Blob Storage.
///
/// El fondo es `--photo` y no `up`: una foto que todavía no bajó tiene que
/// leerse como un hueco de imagen, no como una tarjeta vacía.
class SgFoto extends StatelessWidget {
  const SgFoto({
    super.key,
    this.lado = 56,
    this.ancho,
    this.alto,
    this.radio = 16,
    this.child,
    this.icono = Icons.image_outlined,
  });

  final double lado;
  final double? ancho;
  final double? alto;
  final double radio;
  final Widget? child;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    return Container(
      width: ancho ?? lado,
      height: alto ?? lado,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: sg.foto,
        borderRadius: BorderRadius.circular(radio),
      ),
      child: child ??
          Center(
            child: Icon(icono,
                size: (ancho ?? lado) * 0.34, color: sg.tinta3),
          ),
    );
  }
}

// ──────────────────────────────────────────────────── FILAS Y BLOQUES ──

/// Una tarjeta cuyas filas se separan con el divisor tenue.
///
/// El divisor **solo va entre hermanos**: nunca arriba de la primera ni debajo
/// de la última. Un divisor al borde de la tarjeta sería un borde, y eso es lo
/// que el v3 quitó.
class SgBloque extends StatelessWidget {
  const SgBloque({
    super.key,
    required this.filas,
    this.rotulo,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> filas;

  /// Cuando va, se dibuja dentro de la tarjeta con padding 16/13/16/8.
  final String? rotulo;

  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SgRadius.card),
        boxShadow: sg.e1,
      ),
      child: Material(
        color: color ?? sg.card,
        borderRadius: BorderRadius.circular(SgRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rotulo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
                  child: SgRotulo(rotulo!),
                ),
              for (var i = 0; i < filas.length; i++)
                if (i == 0 && rotulo == null)
                  filas[i]
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: sg.div)),
                    ),
                    child: filas[i],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila dentro de un `SgBloque`: alto mínimo 54, o 60 con dos líneas.
class SgFila extends StatelessWidget {
  const SgFila({
    super.key,
    this.icono,
    this.iconoWidget,
    required this.texto,
    this.detalle,
    this.valor,
    this.colorIcono,
    this.colorTexto,
    this.derecha,
    this.chevron = false,
    this.onTap,
    this.alto = SgMedida.fila,
  });

  final IconData? icono;

  /// Un ícono dibujado en vez de uno de Material: lo usan las filas de una
  /// marca propia, como SIGMA AI.
  final Widget? iconoWidget;

  final String texto;

  /// La segunda línea, en tinta3.
  final String? detalle;

  /// El valor alineado a la derecha, en tinta.
  final String? valor;

  final Color? colorIcono;
  final Color? colorTexto;

  /// Un control a la derecha: interruptor, badge, segmentado.
  final Widget? derecha;

  final bool chevron;
  final VoidCallback? onTap;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final fila = Container(
      constraints: BoxConstraints(minHeight: detalle == null ? alto : SgMedida.filaAlta),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (iconoWidget != null) ...[
            SizedBox(width: 21, height: 21, child: iconoWidget),
            const SizedBox(width: 13),
          ] else if (icono != null) ...[
            Icon(icono, size: 21, color: colorIcono ?? sg.tinta3),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(texto,
                    style: sora(15, detalle == null ? 500 : 600,
                        color: colorTexto ?? sg.tinta),
                    overflow: TextOverflow.ellipsis),
                if (detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(detalle!,
                      style: sora(12, 500, color: sg.tinta3),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (valor != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(valor!,
                  textAlign: TextAlign.right,
                  style: sora(15, 500, color: sg.tinta),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
          if (derecha != null) ...[const SizedBox(width: 10), derecha!],
          if (chevron) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 21, color: sg.tinta3),
          ],
        ],
      ),
    );

    if (onTap == null) return fila;
    return InkWell(onTap: onTap, child: fila);
  }
}

// ────────────────────────────────────────────────────────────── CAMPOS ──

/// El campo de texto del v3: **alto 56, radio 18, sobre `field`**.
///
/// ## El anillo, otra vez
///
/// Enfocado, el campo gana `0 0 0 2px` del morado y **el rótulo de arriba se
/// tiñe con él**; con error, un anillo rojo de 1,5. Ninguno de los dos mueve
/// el texto de sitio, que es justo lo que pasaba con el borde del v2: al
/// enfocar, el cursor daba un salto de dos píxeles.
///
/// ## El micrófono
///
/// §2 del kit pide dictado **por campo**, no solo un botón global. La razón es
/// de terreno: con guantes de nitrilo y a −5 °C la pantalla capacitiva no
/// responde bien, y escribir un número de serie de catorce caracteres es
/// donde más se falla. El micrófono aparece solo donde dictar tiene sentido
/// —una observación, un código— y nunca en un campo de contraseña.
class SgCampo extends StatefulWidget {
  const SgCampo({
    super.key,
    required this.controlador,
    this.icono,
    this.hint,
    this.oculto = false,
    this.sufijo,
    this.validador,
    this.teclado,
    this.onSubmit,
    this.onCambio,
    this.espaciadoTexto,
    this.tamanoTexto = 16,
    this.pesoTexto = 500,
    this.conVoz = false,
    this.onVoz,
    this.habilitado = true,
    this.lineas = 1,
    this.autoenfoque = false,
    this.mayusculas = false,
    this.rotulo,
  });

  final TextEditingController controlador;
  final IconData? icono;
  final String? hint;
  final bool oculto;
  final Widget? sufijo;
  final String? Function(String?)? validador;
  final TextInputType? teclado;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<String>? onCambio;

  /// El kit escribe la contraseña con `letter-spacing: 3` para que los puntos
  /// se cuenten de un vistazo.
  final double? espaciadoTexto;

  final double tamanoTexto;
  final int pesoTexto;

  /// Muestra el micrófono de dictado.
  final bool conVoz;
  final VoidCallback? onVoz;

  final bool habilitado;
  final int lineas;
  final bool autoenfoque;
  final bool mayusculas;

  /// Cuando va, el rótulo se dibuja arriba y **se tiñe solo** al enfocar.
  final String? rotulo;

  @override
  State<SgCampo> createState() => _SgCampoState();
}

class _SgCampoState extends State<SgCampo> {
  final _foco = FocusNode();
  bool _enfocado = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (_foco.hasFocus != _enfocado) {
        setState(() => _enfocado = _foco.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    final campo = FormField<String>(
      validator: (_) => widget.validador?.call(widget.controlador.text),
      builder: (estado) {
        final hayError = estado.hasError;
        final acento =
            hayError ? sg.rojoTexto : (_enfocado ? sg.primarioTexto : sg.tinta3);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.rotulo != null) ...[
              SgRotuloCampo(widget.rotulo!,
                  enfocado: _enfocado && !hayError),
              const SizedBox(height: 8),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SgRadius.campo),
                boxShadow: [
                  if (hayError)
                    ...anillo(SgColor.rojo, ancho: 1.5)
                  else if (_enfocado)
                    ...anillo(sg.primario)
                  else
                    ...sg.e1,
                ],
              ),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: widget.lineas > 1
                      ? SgMedida.campo + 26.0 * (widget.lineas - 1)
                      : SgMedida.campo,
                ),
                padding: EdgeInsets.only(
                    left: 16, right: (widget.sufijo != null || widget.conVoz) ? 6 : 16),
                decoration: BoxDecoration(
                  color: widget.habilitado ? sg.campo : sg.up,
                  borderRadius: BorderRadius.circular(SgRadius.campo),
                ),
                child: Row(
                  crossAxisAlignment: widget.lineas > 1
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (widget.icono != null) ...[
                      Padding(
                        padding: EdgeInsets.only(
                            top: widget.lineas > 1 ? 18 : 0),
                        child: Icon(widget.icono, size: 20, color: acento),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextField(
                        controller: widget.controlador,
                        focusNode: _foco,
                        obscureText: widget.oculto,
                        enabled: widget.habilitado,
                        keyboardType: widget.teclado,
                        maxLines: widget.lineas,
                        minLines: widget.lineas,
                        autofocus: widget.autoenfoque,
                        textCapitalization: widget.mayusculas
                            ? TextCapitalization.characters
                            : TextCapitalization.sentences,
                        onSubmitted: widget.onSubmit,
                        onChanged: (v) {
                          widget.onCambio?.call(v);
                          if (hayError) estado.validate();
                        },
                        style: sora(widget.tamanoTexto, widget.pesoTexto,
                            color: sg.tinta, espaciado: widget.espaciadoTexto),
                        cursorColor: sg.primario,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: widget.lineas > 1 ? 18 : 0),
                          hintText: widget.hint,
                          hintStyle: sora(widget.tamanoTexto, 500,
                              color: sg.tinta3),
                        ),
                      ),
                    ),
                    if (widget.conVoz)
                      SgBotonIcono(Icons.mic_none,
                          color: sg.tinta2,
                          tamano: 21,
                          onTap: widget.onVoz),
                    ?widget.sufijo,
                  ],
                ),
              ),
            ),
            if (hayError) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 17, color: sg.rojoTexto),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(estado.errorText!,
                        style: sora(14, 500, color: sg.rojoTexto, alto: 1.4)),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );

    return campo;
  }
}

/// La casilla del kit: `mdi-checkbox-marked` en morado, texto 14/500 en tinta2.
class SgCasilla extends StatelessWidget {
  const SgCasilla(this.texto,
      {super.key, required this.marcada, required this.onCambio});

  final String texto;
  final bool marcada;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return InkWell(
      onTap: () => onCambio(!marcada),
      borderRadius: BorderRadius.circular(SgRadius.unidad),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(marcada ? Icons.check_box : Icons.check_box_outline_blank,
                size: 19, color: marcada ? sg.primario : sg.tinta3),
            const SizedBox(width: 7),
            Text(texto, style: sora(14, 500, color: sg.tinta2)),
          ],
        ),
      ),
    );
  }
}

/// Un enlace de texto: 14/600 en `primarioTexto`.
class SgEnlace extends StatelessWidget {
  const SgEnlace(this.texto, {super.key, this.onTap, this.tamano = 14});

  final String texto;
  final VoidCallback? onTap;
  final double tamano;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgRadius.unidad),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(texto,
              style: sora(tamano, 600, color: context.sg.primarioTexto)),
        ),
      );
}

/// El aviso dentro de una tarjeta: ícono + texto 13/1.55.
///
/// Es la pieza con la que el kit explica una consecuencia —«tienes 2 registros
/// guardados», «al cambiar de instalación se descargan sus datos»—. Va en
/// `card` cuando informa y teñido cuando advierte.
class SgAviso extends StatelessWidget {
  const SgAviso(
    this.texto, {
    super.key,
    this.icono = Icons.info_outline,
    this.color,
    this.tenido = false,
    this.radio = 20,
  });

  final String texto;
  final IconData icono;

  /// El color del ícono y, si `tenido`, del texto y del fondo.
  final Color? color;

  final bool tenido;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final c = color ?? sg.acentoTexto;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tenido ? sg.tinte(c) : sg.card,
        borderRadius: BorderRadius.circular(radio),
        boxShadow: tenido ? null : sg.e1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: sora(13, 500,
                    color: tenido ? c : sg.tinta2, alto: 1.55)),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── BARRAS ──

/// La barra superior: **alto 64**, botón de volver circular de 44 y título
/// 17/600. Sin línea inferior: la separación la da el fondo.
class SgBarra extends StatelessWidget implements PreferredSizeWidget {
  const SgBarra(
    this.titulo, {
    super.key,
    this.conVolver = true,
    this.acciones = const [],
    this.tamanoTitulo = 17,
    this.onVolver,
    this.tituloWidget,
  });

  final String titulo;

  /// Un título dibujado, no escrito: lo usa SIGMA AI para firmar con su
  /// logotipo. Cuando va, [titulo] queda solo como etiqueta de accesibilidad
  /// —un lector de pantalla no puede leer un SVG—.
  final Widget? tituloWidget;
  final bool conVolver;
  final List<Widget> acciones;
  final double tamanoTitulo;
  final VoidCallback? onVolver;

  @override
  Size get preferredSize => const Size.fromHeight(SgMedida.barraSuperior);

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Container(
      height: SgMedida.barraSuperior,
      color: sg.fondo,
      padding: EdgeInsets.symmetric(horizontal: conVolver ? 12 : 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (conVolver) ...[
              SgBotonIcono(Icons.arrow_back,
                  color: sg.tinta,
                  tamano: 22,
                  onTap: onVolver ?? () => Navigator.maybePop(context)),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: tituloWidget == null
                  ? Text(titulo,
                      style: sora(tamanoTitulo, 600, color: sg.tinta),
                      overflow: TextOverflow.ellipsis)
                  : Semantics(
                      label: titulo,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: tituloWidget)),
            ),
            ...acciones,
          ],
        ),
      ),
    );
  }
}

/// El pie fijo con el botón de acción: padding 12×16 sobre el lienzo.
class SgPie extends StatelessWidget {
  const SgPie({super.key, required this.child, this.conGestos = true});

  final Widget child;
  final bool conGestos;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.sg.fondo,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: child,
              ),
              if (conGestos) const SgBarraGestos(),
            ],
          ),
        ),
      );
}

/// El margen de siempre, **más lo que ocupa la barra del sistema**.
///
/// ## El problema que resuelve
///
/// Los artboards del kit terminan en un margen fijo —24, 28— porque un diseño
/// no tiene barra de navegación. Un teléfono sí: gestos o tres botones, entre
/// 24 y 48 dp que se dibujan **encima** de la app. Con el margen fijo, lo
/// último de cada pantalla queda debajo de esa barra y no hay forma de
/// alcanzarlo: el scroll ya llegó al final. En la ficha de análisis eso
/// escondía los botones de «Reconocer» y «Descartar».
///
/// ## Por qué `padding` y no `viewPadding`
///
/// `MediaQuery.paddingOf` ya viene descontado de lo que el `Scaffold`
/// resolvió por su cuenta: en una pantalla con `SgPie` o barra inferior vale
/// cero, porque esa barra ya está por encima del sistema. Con `viewPadding`
/// —el inset crudo— esas pantallas sumarían el espacio dos veces y quedaría
/// un hueco vacío al final.
///
/// Se aplica al **contenido del scroll**, no al widget: así la lista sigue
/// dibujándose por debajo de la barra —que es lo que se espera— pero se puede
/// desplazar hasta ver el último elemento completo.
extension SgMargenSistema on BuildContext {
  EdgeInsets conBarraSistema(EdgeInsets base) =>
      base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(this).bottom);
}

/// La barra de gestos de Android, que el kit dibuja al pie de cada pantalla.
class SgBarraGestos extends StatelessWidget {
  const SgBarraGestos({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: SgMedida.barraGestos,
        child: Center(
          child: Container(
            width: 134,
            height: 5,
            decoration: BoxDecoration(
              color: color ?? context.sg.indicador,
              borderRadius: BorderRadius.circular(SgRadius.pill),
            ),
          ),
        ),
      );
}

// ────────────────────────────────────────────────────── BARRA INFERIOR ──

/// Un destino de la barra inferior.
class SgDestino {
  const SgDestino({
    required this.icono,
    required this.texto,
    this.onTap,
    this.contador = 0,
    this.punto = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  /// Un número montado sobre el ícono —«Mi trabajo · 4»—.
  final int contador;

  /// El punto rojo de «hay algo nuevo». Sin número: en la barra, dos cifras no
  /// se alcanzan a leer de paso y el punto sí.
  final bool punto;
}

/// La barra inferior del v3: **alto 76 sobre `card`, cinco destinos y
/// Escanear al centro en un botón elevado**.
///
/// El central sube 24 px fuera de la barra y lleva la sombra proyectada del
/// morado. No es adorno: escanear es la acción con la que empieza casi todo el
/// trabajo en terreno —abrir un activo, mover un repuesto, tomar una lectura—
/// y ponerla en el pulgar, al centro, la deja al alcance con una mano y con
/// guantes.
class SgBarraInferior extends StatelessWidget {
  const SgBarraInferior({
    super.key,
    required this.activo,
    required this.destinos,
    required this.centro,
  });

  /// El índice dentro de [destinos]; −1 si ninguno.
  final int activo;

  /// Los **cuatro** destinos laterales, en orden: dos a la izquierda del
  /// centro y dos a la derecha.
  final List<SgDestino> destinos;

  /// El del medio, que se dibuja distinto.
  final SgDestino centro;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ColoredBox(
      color: sg.card,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: SgMedida.barraInferior,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: sg.div)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Destino(d: destinos[0], activo: activo == 0),
                  _Destino(d: destinos[1], activo: activo == 1),
                  _Centro(d: centro),
                  _Destino(d: destinos[2], activo: activo == 2),
                  _Destino(d: destinos[3], activo: activo == 3),
                ],
              ),
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }
}

class _Destino extends StatelessWidget {
  const _Destino({required this.d, required this.activo});

  final SgDestino d;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return InkWell(
      onTap: d.onTap,
      borderRadius: BorderRadius.circular(SgRadius.bloque),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activo ? sg.tinte(sg.acentoTexto) : null,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                  child: Icon(d.icono,
                      size: 21, color: activo ? sg.acentoTexto : sg.tinta3),
                ),
                if (d.contador > 0)
                  Positioned(
                    top: 1,
                    right: 6,
                    child: SgContador(d.contador,
                        color: sg.primario, chico: true, sobre: sg.card),
                  )
                else if (d.punto)
                  Positioned(
                    top: 3,
                    right: 13,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: SgColor.rojo,
                        shape: BoxShape.circle,
                        boxShadow: anillo(sg.card),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(d.texto,
                style: sora(11, activo ? 600 : 500,
                    color: activo ? sg.tinta : sg.tinta2)),
          ],
        ),
      ),
    );
  }
}

class _Centro extends StatelessWidget {
  const _Centro({required this.d});
  final SgDestino d;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: sg.primario.withValues(alpha: 0.9),
                    blurRadius: 24,
                    spreadRadius: -10,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: sg.primario,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: d.onTap,
                  child: Icon(d.icono, size: 25, color: Colors.white),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Text(d.texto, style: sora(11, 600, color: sg.tinta)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── MARCA ──

/// El isotipo, del SVG oficial. No cambia entre modos: es identidad.
class SgIsotipo extends StatelessWidget {
  const SgIsotipo({super.key, this.alto = 66});
  final double alto;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/sigma-isotipo-gradient.svg',
        height: alto,
      );
}

/// El logotipo tipográfico, que **sí** cambia: la versión oscura está pensada
/// para fondo oscuro y sobre blanco desaparece.
class SgWordmark extends StatelessWidget {
  const SgWordmark({super.key, this.alto = 24});
  final double alto;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        context.sg.esOscuro
            ? 'assets/images/sigma-wordmark-dark.svg'
            : 'assets/images/sigma-wordmark-light.svg',
        height: alto,
      );
}

/// El distintivo de SIGMA AI.
class SgBadgeIa extends StatelessWidget {
  const SgBadgeIa({super.key, this.alto = 18});
  final double alto;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        context.sg.esOscuro
            ? 'assets/images/sigma-ai-badge-dark.svg'
            : 'assets/images/sigma-ai-badge-light.svg',
        height: alto,
      );
}

/// El logotipo horizontal de SIGMA AI: símbolo y palabra.
///
/// Es el que va donde antes decía «SIGMA AI» escrito con la tipografía de la
/// app. Un producto con identidad propia se firma con su logotipo, no con su
/// nombre en texto: el texto lo escribe cualquiera, y al lado del distintivo
/// se leían como dos marcas distintas en la misma barra.
class SgLogoIa extends StatelessWidget {
  const SgLogoIa({super.key, this.alto = 24});
  final double alto;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        context.sg.esOscuro
            ? 'assets/images/sigma-ai-logo-horizontal-dark.svg'
            : 'assets/images/sigma-ai-logo-horizontal-light.svg',
        height: alto,
      );
}

/// El ícono de aplicación de SIGMA AI, para una fila de menú.
///
/// Reemplaza a la estrellita genérica de Material: SIGMA AI es un producto con
/// su propia identidad dentro de la app, y con un ícono del sistema se leía
/// como una función más.
class SgIconoIaApp extends StatelessWidget {
  const SgIconoIaApp({super.key, this.lado = 24});
  final double lado;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        context.sg.esOscuro
            ? 'assets/images/sigma-ai-app-icon-dark.svg'
            : 'assets/images/sigma-ai-app-icon-light.svg',
        width: lado,
        height: lado,
      );
}

/// Los cuatro símbolos de estado de SIGMA AI.
/// El nombre del archivo lleva `status`, y no es un detalle: los cuatro SVG
/// del kit se llaman `sigma-ai-status-*.svg`. Sin ese segmento el asset no
/// existe, `flutter_svg` lanza al cargarlo y **los cuatro símbolos de SIGMA AI
/// no se dibujaban**. No fallaba a la vista como un error: fallaba como un
/// hueco.
enum SgIconoIa {
  prediccion('sigma-ai-status-prediction'),
  analizando('sigma-ai-status-analyzing'),
  recomendacion('sigma-ai-status-recommendation'),
  tiempoReal('sigma-ai-status-realtime');

  const SgIconoIa(this.archivo);
  final String archivo;
}

class SgSimboloIa extends StatelessWidget {
  const SgSimboloIa(this.cual, {super.key, this.lado = 34});

  final SgIconoIa cual;
  final double lado;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/${cual.archivo}.svg',
        width: lado,
        height: lado,
      );
}

/// El halo radial de las pantallas de acceso.
///
/// Va **detrás** del contenido y no captura toques: es atmósfera, no
/// superficie.
class SgHalo extends StatelessWidget {
  const SgHalo({
    super.key,
    this.arriba = true,
    this.abajo = false,
  });

  final bool arriba;
  final bool abajo;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    // En claro el halo se apaga: sobre un fondo claro, un degradado morado al
    // 26 % se ve como una mancha de impresión, no como luz.
    final f = sg.esOscuro ? 1.0 : 0.35;

    return IgnorePointer(
      child: Stack(
        children: [
          if (arriba)
            Positioned(
              top: -150,
              left: -110,
              child: _Circulo(
                lado: 420,
                colores: [
                  SgColor.oscuroPrimario.withValues(alpha: 0.26 * f),
                  SgColor.teal.withValues(alpha: 0.09 * f),
                  sg.fondo.withValues(alpha: 0),
                ],
                paradas: const [0.0, 0.46, 0.72],
              ),
            ),
          if (abajo)
            Positioned(
              bottom: -170,
              right: -130,
              child: _Circulo(
                lado: 400,
                colores: [
                  SgColor.teal.withValues(alpha: 0.16 * f),
                  sg.fondo.withValues(alpha: 0),
                ],
                paradas: const [0.0, 0.70],
              ),
            ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({
    required this.lado,
    required this.colores,
    required this.paradas,
  });

  final double lado;
  final List<Color> colores;
  final List<double> paradas;

  @override
  Widget build(BuildContext context) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colores, stops: paradas),
        ),
      );
}
