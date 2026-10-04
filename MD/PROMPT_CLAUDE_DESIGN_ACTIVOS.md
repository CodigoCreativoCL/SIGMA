# Prompt para Claude Design: módulo de Activos

Preparado el 04-10-2026 para rediseñar la vista del activo y su creación en
Claude Design. Se pega tal cual y se adjuntan las capturas actuales del
listado, el modal de alta (pasos 1, 2 y 3), la ficha en edición, la pestaña
Componentes, Condición y medidores y el menú «Más».

```text
# Rediseño: módulo de Activos de SIGMA (para cualquier persona, sin conocimientos técnicos)

## Contexto
SIGMA es un sistema web de gestión de mantenimiento industrial (una planta de panadería
industrial, "Hamburgo"). Lo usan bodegueros, técnicos, jefes de mantenimiento y
administrativos. Muchos NO son usuarios de tecnología: piensa que lo usa una persona
mayor que nunca tomó un curso de computación. Si algo requiere explicación, el diseño falló.

Necesito rediseñar dos cosas:
1. La vista de un activo ("Centro de activos 360°"): que cualquiera entienda de un vistazo
   QUÉ es el equipo, QUÉ máquinas dependen de él, QUÉ partes tiene y QUÉ repuestos le sirven.
2. La creación de un activo: un asistente guiado, amable y prolijo.

## Los cuatro conceptos que el usuario debe entender SIN leer un manual
- ACTIVO (equipo): una máquina de la planta con vida propia.
  Ej.: "Cámara de frío 1", "Horno túnel línea 1".
- SUBACTIVO: una máquina con vida propia que DEPENDE de otra más grande. Tiene número de
  serie, se saca y se repara aparte.
  Ej.: el "Compresor Bitzer" de la Cámara de frío 1.
- COMPONENTE: una PARTE de una máquina que se sigue por separado. No existe fuera de ella.
  Ej.: "Motor de la cinta", "Rodamiento lado motor", "Burlete de la puerta".
  Un componente puede tener sus propias partes (el rodamiento DEL motor).
- REPUESTO: algo que se compra por cantidad y se guarda en bodega. Uno es igual a otro.
  Ej.: "Filtro secador" (hay 3 en bodega), "Correa A-42".
  Un repuesto puede servirle a un activo, a un subactivo o a un componente.

Regla para el usuario, que debe estar presente en la interfaz:
"¿Le importa ESA pieza en particular? → subactivo o componente.
 ¿Da lo mismo cuál uses de la bodega? → repuesto."

## Datos de ejemplo (úsalos en todos los mockups)
Cámara de frío 1 · ACT-CAMARA-1 · Operativo · Criticidad crítica · Planta Renca › Refrigeración › Línea 1
├─ Subactivo: Compresor Bitzer 4FES-5 · Operativo
├─ Subactivo: Compresor Copeland ZB45 · En mantenimiento (está en el taller)
│   └─ Componente: Válvula de descarga · Fuera de servicio
├─ Componente: Ventilador del evaporador · Operativo
├─ Componente: Termostato · Operativo
├─ Componente: Burlete de la puerta · Con observación (gastado)
└─ Repuestos que le sirven: Filtro secador (hay 3), Burlete 2 m (hay 0: sin stock),
   Refrigerante R-404A (bajo el mínimo)
Otros activos: Horno túnel línea 1 (5 componentes), Amasadora espiral línea 1 (4),
Bomba dosificadora Grundfos DDA (3), Caldera de vapor 1 (2).

## Pantallas a diseñar

### A. Listado de activos
- El árbol se ve: los subactivos van debajo de su máquina principal, con conector visual.
- Cada fila: foto o ícono, nombre grande, código pequeño, ubicación legible
  ("Refrigeración › Línea 1"), estado con color, criticidad y chips de lo que cuelga de él
  ("2 subactivos · 3 componentes · 4 repuestos").
- Búsqueda simple arriba y un botón principal claro: "+ Nuevo activo".
- Estados vacíos amables y útiles.

### B. Ficha del activo (centro 360°), cabecera y pestañas
Pestañas, en este orden: Resumen · Ficha · Componentes · Condición y medidores ·
Historial · Órdenes de trabajo · Más (Mantenimiento, Inspecciones y tareas, Fallas,
Documentos y galería, Repuestos y costos, Bitácora). SIGMA AI va aparte, a la derecha.
- Cabecera: foto, nombre, estado, criticidad, ubicación completa y, si es subactivo,
  "Es parte de: Cámara de frío 1" con enlace.
- Pestaña COMPONENTES = "¿De qué está hecho este equipo?". Es la pantalla clave:
  un diagrama tipo organigrama con el equipo arriba y, debajo, tres grupos con un color fijo
  (Subactivos · Componentes · Repuestos), cada uno con una frase corta que dice qué es.
  Los repuestos muestran el stock en lenguaje simple ("Hay 3", "Sin stock",
  "Quedan pocos"). Cada elemento se puede tocar para abrirlo.
  Botón "+ Agregar" que abre la pregunta "¿Qué vas a agregar?" con 3 tarjetas grandes
  (Una máquina que depende de esta / Una parte de este equipo / Un repuesto que le sirve),
  cada una con su regla y un ejemplo.
  Hoy debajo del diagrama hay una segunda vista repetida (árbol + tabla + detalle):
  propón cómo integrar el detalle sin duplicar información.
- Leyenda de colores siempre visible.

### C. Crear (y editar) un activo: asistente de 3 pasos
Es el mismo formulario en un modal ("Nuevo activo") y en la pestaña "Ficha" al editar.
Paso 1, "Qué es y dónde está": nombre*, tipo* (se elige o se escribe uno nuevo y se crea
  solo), modelo, estado*, criticidad*, foto, planta*, área, centro de costo y
  "¿Depende de otra máquina?" (eso lo convierte en subactivo).
Paso 2, "Datos técnicos": número de serie, marca (se elige o se escribe), año,
  puesta en marcha, descripción, datos técnicos libres (nombre + valor + unidad,
  ej. "Potencia 5,5 kW") y documentos (manuales, certificados).
Paso 3, "Sus partes": agregar componentes en filas (nombre · qué es · dónde va),
  con sugerencias.
Requisitos:
- Se puede guardar desde el paso 1 (es lo único obligatorio). Los pasos 2 y 3 son opcionales.
- Indicador de pasos claro, botones Anterior / Siguiente / Guardar siempre en el mismo lugar.
- Validación amable: dice qué falta y lleva al campo; nada de bordes rojos sin explicación.
- Al terminar: confirmación clara y sugerencia del próximo paso
  ("¿Agregar sus partes?", "¿Registrar sus repuestos?").
- Textos de ayuda cortos y en lenguaje común (prohibido: "baja lógica", "atributo",
  "entidad", "registro").

## Problemas actuales que deben desaparecer (se ven en las capturas)
- La ficha en modo edición se estira a todo el ancho: inputs enormes, texto diminuto,
  mucho blanco y la foto en una columna angosta con el texto partido en 6 líneas.
- En el modal hay márgenes y anchos inconsistentes: campos de distinto ancho en la misma
  fila, el bloque de imagen desalineado, "Siguiente" separado de "Guardar" en otra barra,
  y la barra de navegación del paso pegada al pie sin respiro.
- En el paso 3 sobra un espacio vacío enorme bajo la única fila.
- En "Condición y medidores" hay demasiados botones al mismo nivel
  (Configurar / Nuevo contador / Registrar lectura) sin jerarquía clara.
- El chip "En mantenimiento" no cabe y se monta sobre la columna de al lado.
- Hay información repetida en la pestaña Componentes (diagrama + árbol + tabla + detalle).
- El menú "Más" se abre encima del contenido sin separación visual.

## Sistema visual de SIGMA (obligatorio)
Tokens (úsalos como variables, no como hex sueltos):
--sigma-purple #6732F4 (acción principal, pestaña activa) · --sigma-purple-dark #4820C9 ·
--sigma-purple-soft #F2EFFF · --sigma-blue #087BEA (enlaces, botones de contorno) ·
--sigma-blue-soft #EAF4FF · --sigma-cyan #16C6C9 (foco, gráficos; nunca con texto blanco) ·
--sigma-cyan-dark #007F8A · --sigma-cyan-soft #E8FBFB · --ink #17223B (texto) ·
--muted #68738A · --line #E2E7F0 · --surface #FFFFFF · --canvas #F4F6FA ·
--success #16855B · --warning #B65C00 · --danger #C7352B.
- Botones: primario morado (una sola acción morada por grupo), secundario turquesa oscuro
  con texto blanco, contorno azul para navegar, ghost morado suave para cancelar,
  rojo solo para eliminar. Radio 9–10 px, peso 700, 13 px.
- Cards blancas, borde --line, radio 14 px, sombra suave. El color va en íconos y chips,
  no en el fondo de las cards.
- Pestaña activa: texto morado + subrayado de 3 px. Foco: anillo turquesa.
- Estados de negocio con los colores semánticos (verde operativo, ámbar con observación o
  en mantenimiento, rojo detenido o fuera de servicio); el morado NUNCA para alertas.
- Sin degradados en cabeceras.
- Íconos: Material Design Icons (mdi). Tipografía sans moderna, legible.
Colores fijos por concepto (en el diagrama, las leyendas y los chips del listado):
Equipo = morado · Subactivo = azul · Componente = turquesa · Repuesto = ámbar.

## Accesibilidad y legibilidad
- Texto base 14–15 px, títulos claros, contraste AA, áreas de clic de 40 px o más.
- Una idea por bloque; máximo una línea de ayuda por concepto.
- Que funcione a 1366 px, a 1920 px y en un modal de unos 1060 px de ancho
  (en móvil, apilado).
- Grilla de espaciado de 4/8 px, consistente. Mismos paddings en todas las cards.

## Entregables
1. Listado de activos en árbol (con y sin resultados).
2. Centro del activo: cabecera + pestaña Componentes ("¿De qué está hecho este equipo?")
   con el asistente "¿Qué vas a agregar?" abierto.
3. Asistente de creación: los 3 pasos en el modal, más el estado de error de validación
   y la confirmación final.
4. La misma ficha en modo edición dentro de la pestaña "Ficha" (ancho controlado).
5. Una mini guía de estilos: espaciados, tamaños, estados de chips y botones usados.
Escribe todos los textos en español neutro (Chile), en lenguaje simple.
```
