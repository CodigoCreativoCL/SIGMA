# Demo del miércoles 21-10-2026 · Codelco (minería)

Todo se hace **a mano en la presentación**: no hay nada creado de antemano en el sistema para este cliente. Los datos son inventados (la «Concentradora Cerro Alto» no existe).

## El recorrido

1. **Lead:** se parte en el **formulario público de SIGMA (Inicio)**: empresa **Codelco**, país Chile, RUT con dígito verificador válido y **Rubro: Minería**. Al enviarlo nace el lead y suena la campana de los perfiles comerciales (también se puede crear desde Comercial › Centro Comercial › *Nuevo lead*).
2. **Del lead al contrato:** asignar ejecutivo → demo (opcional) → propuesta (plan Medio o Full) → **Generar contrato** → enviarlo → **firma** desde el enlace. Al firmar nace el cliente.
3. **Crear el usuario del cliente** (administrador de Codelco) y **entrar con él**.
4. **Crear a mano, antes de cargar** (Cliente › Organización):
   - **Planta:** `Concentradora Cerro Alto`
   - **Áreas** (el código tiene que ser exactamente este): `CHA` Chancado · `MOL` Molienda · `FLO` Flotación · `REL` Espesado y relaves
5. **Utilidades › Carga de datos**, siempre en este orden, primero *Revisar* y después *Cargar*:

| # | Archivo | Módulo | Resultado esperado al cargar |
|---|---|---|---|
| 1 | `1_Carga_Inventario_Codelco.xlsx` | Inventario | 87 creadas: 3 bodegas, 12 racks (con sus niveles), 24 repuestos (con tipo), 24 umbrales, 24 ingresos de stock ubicados por pasillo · rack · nivel · posición |
| 2b | `2b_Activos_con_errores_para_mostrar.xlsx` | Activos | Solo **Revisar**: dos filas correctas y cuatro con errores a propósito, cada uno explicado (planta inexistente, criticidad inválida, fecha futura y activo padre inexistente, falta el tipo). **No se carga** |
| 2 | `2_Carga_Activos_Codelco.xlsx` | Activos | 129 creadas: 12 activos, 32 datos técnicos, 30 componentes, 11 variables, 7 medidores, 37 repuestos compatibles |
| 3 | `3_Carga_Mantenimiento_Codelco.xlsx` | Mantenimiento | 57 creadas: 6 frecuencias, 6 tareas, 2 inspecciones (13 campos), 2 planes, 5 hitos, 11 actividades, 3 equipos |

Después de cargar: **Inventario › SIGMA Twin** muestra las tres bodegas con sus racks; **Activos** muestra la jerarquía (molino SAG, correa CV-101, bombas de pulpa…); en el **Centro de Planificación** los dos planes quedan en borrador (`ACTIVAR = NO`): activarlos genera las ocurrencias y el job horario crea las órdenes.

## Qué trae cada libro (minería)

- **Inventario:** los racks declaran sus **NIVELES** y el stock se ubica con **PASILLO · RACK · NIVEL · POSICION · FILA**; cada repuesto trae TIPO (Revestimientos, Rodamientos, Lubricantes…), vida útil en horas/días/ciclos, descripción y método de salida (FEFO para lo que vence). Bodegas: Bodega Central de Repuestos, Bodega de Piezas de Desgaste (liners, mantos, bolas, banda, rodillos) y Bodega de Lubricantes y Reactivos (con lote y vencimiento: aceites, grasa, xantato).
- **Activos:** chancador giratorio 60-89, alimentador de placas, correa transportadora CV-101, subestación 23 kV, molino SAG 36x19, molino de bolas 26x40, bombas de pulpa, celda de flotación rougher, soplador, espesador de 90 m.
- **Mantenimiento:** inspecciones de chancado y molienda/flotación, plan del molino SAG y plan de la correa CV-101, con tareas, inspecciones y frecuencias.

## Detalles
- Los libros **no traen hojas de ayuda**: la empresa es nueva y no tiene datos propios todavía. Los TIPOS de repuesto no hay que crearlos: la carga los crea con el nombre del libro. Los responsables de las tareas van vacíos (el cliente aún no tiene personas asignables).
- Volver a cargar el mismo libro **no duplica**, y SIGMA avisa que esa planilla ya se procesó.
- Cómo se probó (17-10-2026): los tres libros se ejecutaron en cadena contra la base dentro de una transacción que se revirtió, con la planta y las cuatro áreas creadas en esa misma transacción: 87 + 129 + 57 filas, 0 errores (incluida la ubicación de cada repuesto en su rack y nivel). No quedó nada en la base.
- Regenerar los libros: `python generar_libros_codelco.py` (lee las columnas reales del Centro de carga desde `CargaMasivaController.cs`; ya no necesita plantillas).
