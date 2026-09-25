import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_app/models/modelos.dart';
import 'package:sigma_app/services/cache_datos.dart';

/// Lo que sostiene el modo sin conexión (HU-151).
///
/// La sábana guarda las columnas en MAYÚSCULAS —`ACT_ID`— y los `fromJson` de
/// la app están escritos contra el DTO del endpoint, que va en minúsculas
/// —`act_id`—. Si esa traducción falla, la app sin señal no muestra nada: no
/// revienta, que es peor, porque parece que no hay datos.
void main() {
  group('Claves tolerantes', () {
    test('el mismo valor se lee en los dos casos', () {
      final f = CacheDatos.conClavesTolerantes({
        'ACT_ID': 7,
        'act_codigo': 'MOT-001',
      });

      expect(f['ACT_ID'], 7);
      expect(f['act_id'], 7);
      expect(f['act_codigo'], 'MOT-001');
      expect(f['ACT_CODIGO'], 'MOT-001');
    });

    test('lo que ya venía en la fila manda sobre lo derivado', () {
      final f = CacheDatos.conClavesTolerantes({'ID': 1, 'id': 2});

      expect(f['ID'], 1);
      expect(f['id'], 2);
    });

    test('un nulo guardado sigue siendo nulo, no desaparece', () {
      // Si el valor nulo se perdiera, `putIfAbsent` volvería a escribirlo y un
      // campo opcional vacío se vería como ausente.
      final f = CacheDatos.conClavesTolerantes({'AREA_NOMBRE': null});

      expect(f.containsKey('area_nombre'), isTrue);
      expect(f['area_nombre'], isNull);
    });
  });

  group('Una fila de la sábana se mapea con el mismo fromJson', () {
    test('Activo', () {
      // Tal como lo devuelve `API_SEL_APP_SABANA_DATOS` con @TIPO = 4.
      final activo = Activo.fromJson(
        CacheDatos.conClavesTolerantes({
          'ACT_ID': 33,
          'ACT_CODIGO': 'MOT-001',
          'ACT_NOMBRE': 'Motor principal linea 3',
          'ACT_NUMERO_SERIE': 'WEG-99812',
          'ACT_FABRICANTE': 'WEG',
          'ACT_ACTIVO_ESTADO': 2,
          'PLANTA_NOMBRE': 'Quilicura',
          'AREA_NOMBRE': 'Envasado',
          'POSICION_CODIGO': 'L3-P02',
          'TIPO_NOMBRE': 'Motor electrico',
          'ESTADO_NOMBRE': 'Operativo',
          'ESTADO_CODIGO': 'OPERATIVO',
          'CRITICIDAD_NOMBRE': 'Alta',
        }),
      );

      expect(activo.act_id, 33);
      expect(activo.act_codigo, 'MOT-001');
      expect(activo.act_nombre, 'Motor principal linea 3');
      expect(activo.act_fabricante, 'WEG');
      expect(activo.act_activo_estado, 2);

      // Los que ya venían en mayúsculas por contrato no se rompen.
      expect(activo.PLANTA_NOMBRE, 'Quilicura');
      expect(activo.ESTADO_CODIGO, 'OPERATIVO');
      expect(activo.ruta, 'Quilicura › Envasado › L3-P02');
    });

    test('ClienteInstalacion', () {
      final planta = ClienteInstalacion.fromJson(
        CacheDatos.conClavesTolerantes({
          'CIN_ID': 4,
          'CIN_NOMBRE': 'Planta Quilicura',
          'CIN_CODIGO': 'QUI',
        }),
      );

      expect(planta.cin_id, 4);
      expect(planta.cin_nombre, 'Planta Quilicura');
      expect(planta.cin_codigo, 'QUI');
    });

    test('la respuesta del endpoint, en minúsculas, sigue funcionando', () {
      // La misma función tiene que servir para la red: si no, habría dos
      // modelos del mismo dato y se desincronizarían.
      final planta = ClienteInstalacion.fromJson(
        CacheDatos.conClavesTolerantes({
          'cin_id': 4,
          'cin_nombre': 'Planta Quilicura',
        }),
      );

      expect(planta.cin_id, 4);
      expect(planta.cin_nombre, 'Planta Quilicura');
    });

    test(
      'CierreMotivo — el cierre de OT tiene que poder hacerse sin señal',
      () {
        // Tal como lo devuelve `API_SEL_APP_SABANA_DATOS` con @TIPO = 9.
        final motivo = CierreMotivo.fromJson(
          CacheDatos.conClavesTolerantes({
            'OCM_ID': 2,
            'OCM_CODIGO': 'SIN HALLAZGO',
            'OCM_NOMBRE': 'Sin hallazgo, no requirió intervención',
            'OCM_ORDEN': 2,
          }),
        );

        expect(motivo.ocm_id, 2);
        expect(motivo.ocm_codigo, 'SIN HALLAZGO');
        expect(motivo.ocm_nombre, 'Sin hallazgo, no requirió intervención');
        expect(motivo.ocm_orden, 2);
      },
    );
  });

  group('CatalogoValor lee los nombres del DTO', () {
    /* POR QUE ESTO ES UNA PRUEBA

       `GET /catalogo-valores` devuelve `valor_id` y `valor_nombre` —las
       propiedades de `CatalogoValorDto`—, no `ctv_id` y `ctv_nombre`, que son
       las columnas. Leyendo las de la columna cada valor llegaba con id 0 y
       nombre vacío, y el selector de estado del activo pintaba filas en blanco
       que además comparaban 0 contra 0: ninguna se podía elegir.

       No falla, no revienta y `analyze` no lo ve. Solo se ve abriendo la hoja. */

    test('la respuesta del endpoint llega completa', () {
      final v = CatalogoValor.fromJson({
        'valor_id': 3,
        'valor_codigo': 'ALTA',
        'valor_nombre': 'Alta',
        'valor_orden': 3,
      });

      expect(v.ctv_id, 3);
      expect(v.ctv_codigo, 'ALTA');
      expect(v.ctv_nombre, 'Alta');
      expect(v.ctv_orden, 3);
    });

    test('la forma de la columna sigue sirviendo', () {
      final v = CatalogoValor.fromJson({'ctv_id': 3, 'ctv_nombre': 'Alta'});

      expect(v.ctv_id, 3);
      expect(v.ctv_nombre, 'Alta');
    });

    test('un valor sin nombre no puede colarse como chip vacío', () {
      // El caso que se veía en pantalla: id 0 y texto vacío.
      final v = CatalogoValor.fromJson({'otra_cosa': 1});

      expect(v.ctv_id, 0);
      expect(v.ctv_nombre, isEmpty);
    });
  });

  group('Un valor de catálogo sabe de qué catálogo es', () {
    test('la fila de la sábana trae su catálogo', () {
      // Tal como la devuelve el segundo resultado del bloque 3.
      final v = CatalogoValor.fromJson(
        CacheDatos.conClavesTolerantes({
          'CATALOGO_CODIGO': 'ACTIVO_ESTADO',
          'VALOR_ID': 3,
          'VALOR_CODIGO': 'DETENIDO',
          'VALOR_NOMBRE': 'Detenido',
          'VALOR_ORDEN': 3,
        }),
      );

      expect(v.CATALOGO_CODIGO, 'ACTIVO_ESTADO');
      expect(v.ctv_id, 3);
      expect(v.ctv_nombre, 'Detenido');
    });

    test('la respuesta del endpoint no lo trae, y no hace falta', () {
      // Ahí ya viene filtrado por catálogo, así que separar no es problema.
      final v = CatalogoValor.fromJson({'valor_id': 3, 'valor_nombre': 'Alta'});
      expect(v.CATALOGO_CODIGO, isNull);
    });
  });

  group('Sin señal se puede trabajar', () {
    /* LO QUE ESTO PROTEGE

       Responder una tarea y escribir en la bitácora ya se encolaban. Lo que
       faltaba era LLEGAR a la pantalla: la bandeja de tareas y los tipos de
       bitácora se pedían por red, así que sin señal salían vacíos y no había
       nada que responder ni con qué guardar. Encolar no sirve si la lectura
       que lo precede no es offline. */

    test('una tarea de la sábana se lee con el mismo fromJson', () {
      // Tal como la devuelve el bloque 10, que delega en API_SEL_TAREA.
      final t = TareaPendiente.fromJson(CacheDatos.conClavesTolerantes({
        'toc_id': 5,
        'tar_titulo': 'Purgar condensado de la linea de vapor',
        'TAREA_CODIGO': 'TAR-014',
        'PRIORIDAD_ID': 4,
        'PRIORIDAD_NOMBRE': 'Crítica',
        'ACTIVO_CODIGO': 'ACT-41',
        'tar_requiere_evidencia': 1,
        'ES_FAVORITO': 0,
      }));

      expect(t.toc_id, 5);
      expect(t.TAREA_CODIGO, 'TAR-014');
      expect(t.PRIORIDAD_NOMBRE, 'Crítica');
      expect(t.ACTIVO_CODIGO, 'ACT-41');
    });

    test('un bit del disco llega como 1, no como true', () {
      /* Es el error que no falla: `j['x'] == true` da FALSO para un 1, así que
         una tarea que exige evidencia dejaría de exigirla solo sin señal. */
      final conUno = TareaPendiente.fromJson({
        'toc_id': 1,
        'tar_titulo': 'x',
        'tar_requiere_evidencia': 1,
      });
      final conBool = TareaPendiente.fromJson({
        'toc_id': 1,
        'tar_titulo': 'x',
        'tar_requiere_evidencia': true,
      });

      expect(conUno.tar_requiere_evidencia, isTrue);
      expect(conBool.tar_requiere_evidencia, isTrue);
    });

    test('los tipos de bitácora salen del catálogo que ya está en el disco',
        () {
      // `tiposBitacora()` los arma desde BITACORA_TIPO del bloque 3.
      final v = CatalogoValor.fromJson(CacheDatos.conClavesTolerantes({
        'CATALOGO_CODIGO': 'BITACORA_TIPO',
        'VALOR_ID': 2,
        'VALOR_CODIGO': 'INCIDENTE',
        'VALOR_NOMBRE': 'Incidente',
      }));

      expect(v.CATALOGO_CODIGO, 'BITACORA_TIPO');
      final tipo = BitacoraTipo(
        bti_id: v.ctv_id,
        bti_nombre: v.ctv_nombre,
        bti_codigo: v.ctv_codigo,
      );
      expect(tipo.bti_id, 2);
      expect(tipo.esIncidente, isTrue);
    });
  });

  group('El nombre de la entidad guardada', () {
    /* POR QUE ESTO ES UNA PRUEBA Y NO UN COMENTARIO

       La sincronización numera con sufijo `_0`, `_1`… SOLO los bloques que
       traen varios resultados; el que trae uno se guarda con el código pelado.
       Equivocarse no rompe nada: `CacheDatos.lista` devuelve vacío y la
       pantalla se ve como si no hubiera datos. Es el error más caro de
       encontrar, porque no falla. */

    /// La misma regla que aplica `SincronizacionNotifier` al guardar.
    String entidadDe(String codigo, int cuantosResultados, int indice) =>
        cuantosResultados == 1 ? codigo : '${codigo}_$indice';

    test('un bloque de un solo resultado va sin sufijo', () {
      expect(entidadDe('ORDENES_TRABAJO', 1, 0), CacheDatos.motivosCierre);
    });

    test('uno de varios resultados sí lo lleva', () {
      expect(entidadDe('PERMISOS_TRABAJO', 2, 0), CacheDatos.permisosTipos);
      expect(entidadDe('PERMISOS_TRABAJO', 2, 1), CacheDatos.permisosEstados);
    });

    test('el bloque de inventario trae cuatro y los separa', () {
      expect(entidadDe('INVENTARIO', 4, 0), CacheDatos.repuestos);
      expect(entidadDe('INVENTARIO', 4, 1), CacheDatos.bodegas);
    });

    test('el bloque de tareas trae uno solo y va sin sufijo', () {
      expect(entidadDe('TAREAS', 1, 0), CacheDatos.tareas);
    });

    test('catalogos pasó de uno a dos resultados y cambió de nombre', () {
      /* El dia que el bloque 3 sumo los VALORES, su primer resultado dejo de
         llamarse `CATALOGOS` y paso a `CATALOGOS_0`. Si la constante se hubiera
         quedado atras, las cabeceras se leerian vacias sin fallar. */
      expect(entidadDe('CATALOGOS', 2, 0), CacheDatos.catalogos);
      expect(entidadDe('CATALOGOS', 2, 1), CacheDatos.catalogoValores);
    });
  });
}
