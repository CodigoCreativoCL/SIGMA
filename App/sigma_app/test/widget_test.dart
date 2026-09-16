import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';
import 'package:sigma_app/services/api_client.dart';
import 'package:sigma_app/theme/app_theme.dart';
import 'package:sigma_app/theme/sigma_tokens.dart';

void main() {
  group('Tokens de marca', () {
    test('son los mismos que el kit v2', () {
      // Si alguno falla, el diseño y la app dejaron de ser la misma marca.
      // Se corrige el que esté mal, no el test.
      expect(SgColor.oscuroFondo, const Color(0xFF080C17));
      expect(SgColor.oscuroCard, const Color(0xFF111827));
      expect(SgColor.claroFondo, const Color(0xFFEFF3F9));
      expect(SgColor.claroCard, const Color(0xFFFFFFFF));
      expect(SgColor.navy, const Color(0xFF0B0F1A));
    });

    test('el morado baja de luminosidad en claro', () {
      // #6C5CFF sobre blanco pierde contraste en el texto del botón.
      expect(AppColors.oscuro.primario, const Color(0xFF6C5CFF));
      expect(AppColors.claro.primario, const Color(0xFF5847E8));
    });
  });

  group('Los dos modos', () {
    test('el texto de cada estado cambia, el relleno no', () {
      // Es la decisión que hace legibles los dos modos con el mismo código:
      // el relleno es el mismo color; lo que cambia es con qué se escribe.
      expect(AppColors.oscuro.rojoTexto, const Color(0xFFFB7185));
      expect(AppColors.claro.rojoTexto, const Color(0xFFB91C1C));
      expect(AppColors.oscuro.verdeTexto, isNot(AppColors.claro.verdeTexto));
      // El relleno sólido no depende del modo.
      expect(SgColor.rojo, const Color(0xFFDC2626));
    });

    test('el teal lleva tinta navy en los dos modos', () {
      // Blanco sobre #00BFAE da 2.32:1 y es ilegible.
      for (final tema in [AppTheme.oscuro(), AppTheme.claro()]) {
        expect(tema.colorScheme.onSecondary, SgColor.navy);
      }
    });

    test('cada modo trae su propio AppColors en el tema', () {
      // Si esto falla, una pantalla leería los colores del modo equivocado.
      expect(AppTheme.oscuro().extension<AppColors>()!.esOscuro, isTrue);
      expect(AppTheme.claro().extension<AppColors>()!.esOscuro, isFalse);
    });

    test('el tinte de estado es más suave en claro', () {
      // Sobre blanco, un 16 % ya se ve sucio.
      final o = AppColors.oscuro.tinte(SgColor.rojo).a;
      final c = AppColors.claro.tinte(SgColor.rojo).a;
      expect(c, lessThan(o));
    });
  });

  group('Medidas', () {
    test('el botón principal y la fila tocable alcanzan el mínimo táctil', () {
      // 48 dp es el mínimo de Material; en planta se toca con guantes.
      expect(SgMedida.boton, greaterThanOrEqualTo(48.0));
      expect(SgMedida.campo, greaterThanOrEqualTo(48.0));
      expect(SgMedida.fila, greaterThanOrEqualTo(48.0));
      expect(SgMedida.tocable, 48.0);
    });

    test('la tarjeta usa el radio 22 del kit v3', () {
      // El v3 subio de 18 a 22 al quitar el borde: un radio mayor sin
      // contorno lee como superficie apoyada, no como caja dibujada.
      expect(SgRadius.card, 22.0);
      expect(SgRadius.campo, 18.0);
    });

    test('sora() pide el peso por el eje variable, no solo por fontWeight', () {
      // Sora es una fuente variable: sin fontVariations el peso no cambia.
      final s = sora(16, 600);
      expect(s.fontVariations, isNotEmpty);
      expect(s.fontVariations!.first.value, 600);
    });
  });

  group('ApiException', () {
    test('401 y 403 no significan lo mismo', () {
      // Ante un 401 la app renueva la sesión; ante un 403, NUNCA la cierra:
      // el token está bien y reintentar no cambia nada.
      const noAutenticado = ApiException('x', codigo: 401);
      const sinPermiso = ApiException('x', codigo: 403);

      expect(noAutenticado.sesionInvalida, isTrue);
      expect(noAutenticado.sinPermiso, isFalse);
      expect(sinPermiso.sinPermiso, isTrue);
      expect(sinPermiso.sesionInvalida, isFalse);
    });

    test('sin código es un fallo de red: se reintenta', () {
      const red = ApiException('Sin conexión al servidor.');
      expect(red.esDeRed, isTrue);
    });

    test('el 409 cierra el círculo de la idempotencia', () {
      // Es el reintento que llegó dos veces: el servidor ya lo tenía.
      const duplicado = ApiException('x', codigo: 409);
      expect(duplicado.duplicado, isTrue);
    });
  });

  group('Modelos', () {
    test('un NULL de la base no revienta el mapeo', () {
      // La lección que costó tres pantallas en la web: int.Parse() sobre una
      // columna anulable lanza excepción. Acá tiene que dar el valor por
      // defecto, no fallar.
      final s = InventarioSaldo.fromJson(const {
        'isa_id': null,
        'REPUESTO_NOMBRE': null,
        'CANTIDAD_DISPONIBLE': null,
        'rbs_stock_minimo': null,
        'isa_fecha_ultimo_movimiento': null,
      });

      expect(s.isa_id, 0);
      expect(s.REPUESTO_NOMBRE, '');
      expect(s.CANTIDAD_DISPONIBLE, 0);
      expect(s.rbs_stock_minimo, isNull);
      expect(s.isa_fecha_ultimo_movimiento, isNull);
    });

    test('BAJO_MINIMO lo decide el SP, no la pantalla', () {
      final bajo = InventarioSaldo.fromJson(const {'BAJO_MINIMO': 1});
      final ok = InventarioSaldo.fromJson(const {'BAJO_MINIMO': 0});
      expect(bajo.bajoMinimo, isTrue);
      expect(ok.bajoMinimo, isFalse);
    });

    test('Paginado acepta el objeto y la lista pelada', () {
      // Hay endpoints que devuelven {datos:[...]} y otros un array: /menus y
      // /repuestos/{id}/lotes son arrays.
      final objeto = Paginado.desde(const {
        'total': 2,
        'pagina': 1,
        'datos': [
          {'ctl_id': 1},
          {'ctl_id': 2},
        ],
      }, Catalogo.fromJson);
      final lista = Paginado.desde(const [
        {'ctl_id': 7},
      ], Catalogo.fromJson);

      expect(objeto.datos.length, 2);
      expect(objeto.total, 2);
      expect(lista.datos.single.ctl_id, 7);
      expect(lista.total, 1);
    });

    test('la antigüedad de una alerta se lee en palabras', () {
      expect(Alerta.fromJson(const {'MINUTOS': 12}).hace, 'hace 12 min');
      expect(Alerta.fromJson(const {'MINUTOS': 180}).hace, 'hace 3 h');
      expect(Alerta.fromJson(const {'MINUTOS': 1500}).hace, 'ayer');
    });
    // ---- Sprint 5: el ciclo de la OT en terreno ----

    test('la situación de una falla se deriva al mirar, no viaja', () {
      expect(
        Falla.fromJson(const {
          'FAL_ID': 1,
          'FAL_ACTIVO': 1,
          'FAL_TITULO': 'x',
        }).situacion,
        'Abierta',
      );
      expect(
        Falla.fromJson(const {
          'FAL_ID': 1,
          'FAL_ACTIVO': 1,
          'FAL_TITULO': 'x',
          'DIAGNOSTICOS': 1,
        }).situacion,
        'Diagnosticada',
      );
      expect(
        Falla.fromJson(const {
          'FAL_ID': 1,
          'FAL_ACTIVO': 1,
          'FAL_TITULO': 'x',
          'DIAGNOSTICOS': 1,
          'ACCIONES_PROVISORIAS': 2,
        }).situacion,
        'Provisoria',
      );
      final r = Falla.fromJson(const {
        'FAL_ID': 1,
        'FAL_ACTIVO': 1,
        'FAL_TITULO': 'x',
        'ACCIONES_PROVISORIAS': 2,
        'FAL_FECHA_SOLUCION_UTC': '2026-09-14T19:00:00',
      });
      expect(r.situacion, 'Resuelta');
      expect(r.resuelta, isTrue);
      expect(r.codigo, 'F-1');
    });

    test('dos provisorias del equipo es un equipo que pide atención', () {
      expect(
        Falla.fromJson(const {
          'FAL_ID': 1,
          'FAL_ACTIVO': 1,
          'FAL_TITULO': 'x',
          'PROVISORIAS_DEL_EQUIPO': 1,
        }).equipoConHistorial,
        isFalse,
      );
      expect(
        Falla.fromJson(const {
          'FAL_ID': 1,
          'FAL_ACTIVO': 1,
          'FAL_TITULO': 'x',
          'PROVISORIAS_DEL_EQUIPO': 2,
        }).equipoConHistorial,
        isTrue,
      );
    });

    test(
      'la indisponibilidad lee los minutos del servidor y los dice en horas',
      () {
        final abierta = Indisponibilidad.fromJson(const {
          'AIN_ID': 1,
          'AIN_ACTIVO': 40,
          'AIN_FECHA_INICIO_UTC': '2026-09-14T08:00:00',
          'MINUTOS_ACUMULADOS': 45,
        });
        expect(abierta.abierta, isTrue);
        expect(abierta.duracion, '45 min');
        final cerrada = Indisponibilidad.fromJson(const {
          'AIN_ID': 2,
          'AIN_ACTIVO': 40,
          'AIN_FECHA_INICIO_UTC': '2026-09-14T08:00:00',
          'AIN_FECHA_FIN_UTC': '2026-09-14T11:30:00',
          'AIN_MINUTO': 210,
          'MINUTOS_ACUMULADOS': 210,
        });
        expect(cerrada.abierta, isFalse);
        expect(cerrada.duracion, '3 h 30 min');
      },
    );

    test(
      'la asignación distingue técnico de empresa externa y lee la advertencia',
      () {
        final t = AsignacionOrden.fromJson(const {
          'OTA_ID': 1,
          'OTA_USUARIO': 11,
          'USUARIO_NOMBRE': 'Cristián',
          'OTA_ES_RESPONSABLE': true,
        });
        expect(t.esExterna, isFalse);
        expect(t.quien, 'Cristián');
        expect(t.conAdvertencia, isFalse);
        final e = AsignacionOrden.fromJson(const {
          'OTA_ID': 2,
          'OTA_PROVEEDOR': 3,
          'PROVEEDOR_NOMBRE': 'Frío Sur',
          'OTA_OBSERVACION':
              'Advertencia: la orden pide la especialidad ELÉCTRICA',
        });
        expect(e.esExterna, isTrue);
        expect(e.quien, 'Frío Sur');
        expect(e.conAdvertencia, isTrue);
      },
    );

    test('el escaneo de una posición dice si está libre y qué equipo la ocupa', () {
      final libre = Escaneo.fromJson(const {
        'tipo': 'POS',
        'id': 7,
        'cabecera': {
          'pos_id': 7,
          'pos_codigo': 'CB01',
          'pos_nombre': 'Blower 1',
          'AREA': 'Sala de blowers',
          'PLANTA': 'Renca',
          'pos_libre': true,
          'act_id': 0,
        },
        'lineas': [],
      });
      expect(libre.tipo, 'POS');
      expect(libre.cabecera?.pos_codigo, 'CB01');
      expect(libre.cabecera?.pos_libre, isTrue);
      expect(libre.cabecera?.AREA, 'Sala de blowers');

      final ocupada = Escaneo.fromJson(const {
        'tipo': 'POS',
        'id': 7,
        'cabecera': {
          'pos_id': 7,
          'pos_codigo': 'CB01',
          'pos_libre': false,
          'act_id': 35,
          'act_codigo': 'ACT-35',
          'act_nombre': 'Revolvedora 1',
        },
      });
      expect(ocupada.cabecera?.pos_libre, isFalse);
      expect(ocupada.cabecera?.act_id, 35);
    });
  });
}
