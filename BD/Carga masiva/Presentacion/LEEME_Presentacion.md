# Libros para la presentación del miércoles 21-10-2026 — Utilidades › Carga de datos

Datos de demostración: **ampliación de la Línea 2 de Planta Renca (Hamburgo SA)**. Todos los códigos llevan el prefijo `L2-` para no chocar con lo que ya existe. Los libros están hechos sobre las plantillas oficiales de SIGMA (con sus hojas de ayuda y desplegables).

## Orden de la demostración

| # | Archivo | Módulo | Qué se ve | Resultado esperado |
|---|---|---|---|---|
| 1 | `1_Carga_Inventario_Linea2.xlsx` | Inventario | 2 bodegas, 8 racks (aparecen en el mapa 3D), 24 repuestos, 24 umbrales y 24 ingresos de stock inicial con lote y vencimiento | **Revisar:** 82 se crearían, 0 errores. **Cargar:** 82 creadas |
| 2 | `2b_Activos_con_errores_para_mostrar.xlsx` | Activos | Un archivo corto con errores a propósito: SIGMA los explica antes de escribir nada | **Revisar:** 5 se crearían y 5 filas con error (planta inexistente, criticidad inválida, activo padre inexistente, año/fecha futuros, falta el tipo). **No se carga** |
| 3 | `2_Carga_Activos_Linea2.xlsx` | Activos | 12 activos con jerarquía, 31 datos técnicos, 31 componentes, 11 variables con umbrales, 7 medidores y 32 repuestos compatibles (los del archivo 1) | **Revisar:** sin errores. **Cargar:** 124 creadas |
| 4 | `3_Carga_Mantenimiento_Linea2.xlsx` | Mantenimiento | 6 frecuencias, 6 tareas y su programación, 2 checklists con 13 campos (se publican solos), 3 checklists programados, 2 planes con 5 hitos, 11 actividades y 6 equipos | **Revisar:** sin errores. **Cargar:** 60 creadas |

**Siempre en ese orden**: el 3 nombra repuestos del 1, y el 4 nombra los activos del 3. Si se revisa un libro antes de cargar el anterior, SIGMA lo dice (por ejemplo, «El repuesto no existe. Créelo antes en la carga de Inventario»); eso también sirve para mostrar que las dependencias se validan.

## Cómo contarlo (3 pasos por módulo)
1. **Descargar la plantilla** (o usar el libro ya preparado): encabezados morados = obligatorios, celestes = opcionales; hojas de ayuda con los valores de la empresa.
2. **Revisar**: SIGMA dice qué pasará con cada fila (crear, actualizar, error) sin escribir nada. El avance se ve en vivo.
3. **Cargar**: se escribe fila por fila por los mismos procedimientos que las fichas. Una fila mala no detiene la carga y el informe de errores se baja en Excel.

## Detalles que conviene saber
- **Se puede repetir**: volver a cargar el mismo libro no duplica; con «Actualizar» las filas existentes se actualizan (las celdas vacías conservan lo que había) y con «Omitir» se saltan.
- **Los planes quedan en borrador** (`ACTIVAR = NO`). Para mostrar la generación automática, cambiar `ACTIVAR` a `SI` en la hoja PLANES y volver a cargar, o activarlos desde el Centro de Planificación. Al activar, el job «Ocurrencias y OT automáticas» (cada hora) crea las OT cuando llegan a su fecha.
- **Los datos quedan en la base de Hamburgo** (es la misma base de desarrollo). Ensayar con *Revisar*, que no escribe nada; *Cargar* solo en la presentación. Quien quiera repetir la demostración desde cero necesita borrar antes lo cargado (pedirlo y se prepara el script).
- **Cómo se probó**: los tres libros se ejecutaron en cadena contra la base dentro de una transacción que se revirtió (82 + 124 + 60 filas, 0 errores) y se revisaron por la web con el lector real del Centro de carga.
- La hoja `COMPATIBILIDADES` del libro de Inventario va vacía a propósito: los repuestos compatibles se cargan desde la hoja `REPUESTOS COMPATIBLES` del libro de Activos.

## Corrección que salió de la prueba
Un dato técnico de texto sin unidad (por ejemplo «Refrigerante: R404A») fallaba al cargar activos (`PRC_CARGA_ACTIVOS` mandaba la unidad como 0 y no como vacía). Quedó corregido en `BD/367` y `BD/473`.
