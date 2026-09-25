import 'package:flutter/material.dart';

import '../../services/accesibilidad_service.dart';
import '../../services/preferencias_service.dart';
import '../../services/tema_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/sigma_tokens.dart';
import '../../widgets/comun/sigma_v3.dart';

/// Accesibilidad y apariencia — vista 16.2 del diseño v3 (HU-161, HU-162).
///
/// ## Por qué no hay botón de «Guardar»
///
/// Porque cada ajuste **se aplica mientras se mira esta pantalla**: subir el
/// tamaño del texto agranda esta misma lista, encender el alto contraste
/// repinta este mismo fondo. Un botón de guardar obligaría a salir para ver el
/// efecto y volver a entrar para corregirlo, que es justo lo que no puede
/// hacer quien está buscando un tamaño en el que pueda leer.
///
/// Es también por qué la pantalla no tiene vista previa: la vista previa es la
/// pantalla.
///
/// ## Por qué el tema vive acá y ya no en «Mi perfil»
///
/// Era el mismo ajuste en dos sitios. Claro/oscuro es una decisión de cómo se
/// ve la app, igual que el contraste y el tamaño de la letra, y tenerlo
/// separado hacía que quien buscaba «que se vea mejor» encontrara la mitad.
class AccesibilidadScreen extends StatelessWidget {
  const AccesibilidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return Scaffold(
      backgroundColor: sg.fondo,
      appBar: const SgBarra('Accesibilidad', tamanoTitulo: 22),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: context.conBarraSistema(
            const EdgeInsets.fromLTRB(16, 14, 16, 16),
          ),
          children: [
            const SgRotulo('Cómo se lee'),
            const SizedBox(height: 10),
            const _TamanoTexto(),
            const SizedBox(height: 12),
            SgBloque(
              filas: [
                SgFila(
                  icono: Icons.contrast,
                  texto: 'Alto contraste',
                  colorTexto: sg.tinta2,
                  derecha: _Interruptor(
                    valor: AccesibilidadService.instance.altoContraste,
                    cambiar: AccesibilidadService.instance.cambiarContraste,
                  ),
                ),
                SgFila(
                  icono: Icons.palette_outlined,
                  texto: 'Tema',
                  colorTexto: sg.tinta2,
                  derecha: const _SelectorTema(),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const SgRotulo('Cómo responde'),
            const SizedBox(height: 10),
            SgBloque(
              filas: [
                SgFila(
                  icono: Icons.motion_photos_off_outlined,
                  texto: 'Movimiento reducido',
                  colorTexto: sg.tinta2,
                  derecha: _Interruptor(
                    valor: AccesibilidadService.instance.movimientoReducido,
                    cambiar: AccesibilidadService.instance.cambiarMovimiento,
                  ),
                ),
                SgFila(
                  icono: Icons.vibration,
                  texto: 'Confirmación al tocar',
                  colorTexto: sg.tinta2,
                  derecha: _Interruptor(
                    valor: AccesibilidadService.instance.haptica,
                    cambiar: AccesibilidadService.instance.cambiarHaptica,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SgAviso(
              'Con el movimiento reducido nada gira ni avanza solo: las '
              'tarjetas de SIGMA AI se cambian deslizando.',
              icono: Icons.info_outline,
              color: sg.tinta3,
            ),

            const SizedBox(height: 20),
            const SgRotulo('Avisos'),
            const SizedBox(height: 10),
            SgBloque(
              filas: [
                SgFila(
                  icono: Icons.notifications_active_outlined,
                  texto: 'Recibir avisos en este teléfono',
                  colorTexto: sg.tinta2,
                  derecha: _Interruptor(
                    valor: PreferenciasService.instance.avisos,
                    cambiar: PreferenciasService.instance.cambiarAvisos,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _HorarioSilencio(),

            const SizedBox(height: 20),
            SgAviso(
              'Estos ajustes son tuyos y de este teléfono. Quien entre con '
              'otra cuenta ve los suyos.',
              icono: Icons.person_outline,
              color: sg.tinta3,
            ),
            const SgBarraGestos(),
          ],
        ),
      ),
    );
  }
}

/// El tamaño del texto, en cuatro pasos con nombre.
///
/// Cuatro y no un deslizador: un deslizador continuo obliga a buscar y deja
/// tamaños intermedios donde una tarjeta corta el texto por dos píxeles. Cada
/// paso está probado contra los altos fijos del v3.
class _TamanoTexto extends StatelessWidget {
  const _TamanoTexto();

  static const _pasos = [
    (valor: 1.0, texto: 'Normal'),
    (valor: 1.15, texto: 'Grande'),
    (valor: 1.3, texto: 'Mayor'),
    (valor: 1.5, texto: 'Máximo'),
  ];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return SgCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SgIconoCuadro(
                Icons.format_size,
                color: sg.primarioTexto,
                lado: 40,
                tamanoIcono: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tamaño del texto',
                  style: sora(14, 600, color: sg.tinta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<double>(
            valueListenable: AccesibilidadService.instance.escalaTexto,
            builder: (_, actual, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _pasos)
                  SgChip(
                    p.texto,
                    elegido: (actual - p.valor).abs() < 0.01,
                    onTap: () =>
                        AccesibilidadService.instance.cambiarEscala(p.valor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El horario de silencio, que puede cruzar la medianoche.
///
/// De 22:00 a 07:00 es el caso normal y no el raro, así que la pantalla lo
/// dice con todas sus letras en vez de dejar que alguien crea que puso mal las
/// horas. Quién decide callar es `AccesibilidadService.enSilencio`.
class _HorarioSilencio extends StatelessWidget {
  const _HorarioSilencio();

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;
    final acc = AccesibilidadService.instance;

    return ValueListenableBuilder<int?>(
      valueListenable: acc.silencioDesde,
      builder: (_, desde, _) => ValueListenableBuilder<int?>(
        valueListenable: acc.silencioHasta,
        builder: (contexto, hasta, _) {
          final puesto = desde != null && hasta != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SgBloque(
                filas: [
                  SgFila(
                    icono: Icons.bedtime_outlined,
                    texto: 'No molestar desde',
                    colorTexto: sg.tinta2,
                    valor: puesto ? _hhmm(desde) : 'Sin horario',
                    onTap: () => _elegir(contexto, esDesde: true),
                  ),
                  SgFila(
                    icono: Icons.wb_twilight,
                    texto: 'Hasta',
                    colorTexto: sg.tinta2,
                    valor: puesto ? _hhmm(hasta) : 'Sin horario',
                    onTap: () => _elegir(contexto, esDesde: false),
                  ),
                ],
              ),
              if (puesto) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => acc.cambiarSilencio(null, null),
                    child: Text(
                      'Quitar el horario',
                      style: sora(12, 600, color: sg.tinta3),
                    ),
                  ),
                ),
                if (desde > hasta)
                  Text(
                    'Cruza la medianoche: calla desde las ${_hhmm(desde)} '
                    'hasta las ${_hhmm(hasta)} del día siguiente.',
                    style: sora(12, 500, color: sg.tinta3, alto: 1.45),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _elegir(BuildContext context, {required bool esDesde}) async {
    final acc = AccesibilidadService.instance;
    final actual = esDesde ? acc.silencioDesde.value : acc.silencioHasta.value;

    final elegida = await showTimePicker(
      context: context,
      initialTime: actual == null
          // 22:00 y 07:00 de partida: es el turno de noche, que es para lo que
          // se usa. Arrancar en la hora actual obligaría a girar el reloj
          // entero cada vez.
          ? (esDesde
                ? const TimeOfDay(hour: 22, minute: 0)
                : const TimeOfDay(hour: 7, minute: 0))
          : TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
    );
    if (elegida == null) return;

    final minutos = elegida.hour * 60 + elegida.minute;
    // Poner una sola punta deja el horario a medias; se completa con la otra
    // por omisión para que quede algo que de verdad se pueda aplicar.
    final otra = esDesde ? acc.silencioHasta.value : acc.silencioDesde.value;
    final completada = otra ?? (esDesde ? 7 * 60 : 22 * 60);

    await acc.cambiarSilencio(
      esDesde ? minutos : completada,
      esDesde ? completada : minutos,
    );
  }

  static String _hhmm(int? m) => m == null
      ? '--:--'
      : '${(m ~/ 60).toString().padLeft(2, '0')}:'
            '${(m % 60).toString().padLeft(2, '0')}';
}

/// El interruptor del kit, sobre cualquier `ValueNotifier<bool>`.
class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.valor, required this.cambiar});

  final ValueNotifier<bool> valor;
  final Future<void> Function(bool) cambiar;

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<bool>(
      valueListenable: valor,
      builder: (_, activo, _) => Switch.adaptive(
        value: activo,
        activeThumbColor: Colors.white,
        activeTrackColor: sg.primario,
        inactiveTrackColor: sg.up2,
        onChanged: cambiar,
      ),
    );
  }
}

/// El selector de modo, en la píldora segmentada del kit.
///
/// Tres opciones y no dos: **Auto** existe porque quien tiene el teléfono en
/// cambio automático espera que la app lo siga. Pero el de fábrica es
/// **Oscuro**: la app se usa en planta, y dejar que Android decida haría que
/// el técnico entre en claro solo porque nunca tocó ese ajuste.
class _SelectorTema extends StatelessWidget {
  const _SelectorTema();

  static const _opciones = [
    (modo: ThemeMode.dark, texto: 'Oscuro', icono: Icons.dark_mode_outlined),
    (modo: ThemeMode.light, texto: 'Claro', icono: Icons.light_mode_outlined),
    (modo: ThemeMode.system, texto: 'Auto', icono: Icons.brightness_auto),
  ];

  @override
  Widget build(BuildContext context) {
    final sg = context.sg;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaService.instance.modo,
      builder: (_, actual, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sg.up,
          borderRadius: BorderRadius.circular(SgRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in _opciones)
              InkWell(
                onTap: () => TemaService.instance.cambiar(o.modo),
                borderRadius: BorderRadius.circular(SgRadius.pill),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: actual == o.modo ? sg.primario : null,
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        o.icono,
                        size: 14,
                        color: actual == o.modo ? Colors.white : sg.tinta2,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        o.texto,
                        style: sora(
                          12,
                          600,
                          color: actual == o.modo ? Colors.white : sg.tinta2,
                        ),
                      ),
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
