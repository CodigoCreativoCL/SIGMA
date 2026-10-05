# Prompt para Claude Code — Rediseño módulo de Activos (SIGMA)

1. Copia el archivo `sigma-activos-referencia.html` dentro del repositorio, en `docs/rediseno-activos/`. Es la **única referencia** para las vistas de la planta.
2. Copia todo lo que está debajo de la línea y pégalo en la sesión de Claude Code abierta en el repositorio de SIGMA.

---

Vamos a implementar el rediseño del módulo **Activos** de SIGMA (sistema web de gestión de mantenimiento industrial). El diseño aprobado está en este lienzo: https://claude.ai/artifact/QFTGMAEwZEajB8wNqJjXCQ (pantallas A1–A3, B1–B3, C1–C4, D2 y E1–E2). Si no puedes abrirlo, trabaja con esta especificación. Para las vistas de la sección 6 la única fuente de verdad es `docs/rediseno-activos/sigma-activos-referencia.html`.

**Vocabulario:** en la interfaz siempre se dice **activo**, nunca "equipo".

## Cómo quiero que trabajes

1. **Explora primero, no edites todavía.** Identifica el stack (framework de front, librería de componentes, estilos, íconos), dónde viven hoy: el listado de activos, el "Centro de activos 360°" (ficha con pestañas), el modal "Nuevo activo" de 3 pasos, la pestaña "Componentes" y la pestaña "Condición y medidores". Ubica también el modelo/API del activo, subactivo (activo con padre), componente y repuesto.
2. **Muéstrame un plan** con: archivos a tocar, componentes nuevos o reutilizables, mapeo de cada campo del formulario nuevo al campo actual del modelo, y cualquier dato que el diseño pida y el backend no tenga. Espera mi OK antes de implementar.
3. Implementa **por etapas** en este orden, con un commit por etapa: (a) tokens y componentes base, (b) «+ Nuevo activo» abre la ficha actual en modal + fotos con portada (sección 0), (c) Centro 360°: cabecera, barra de pestañas y Resumen, (d) Componentes, Condición y medidores, Historial y OT, (e) menú «Más» y SIGMA AI, (f) listado en árbol y estados vacíos, (g) menú de vistas + Vista Lista (E1) + Vista Tarjetas (E2), (h) Mapa por áreas (E3), (i) Vista 3D (E3), (j) Explorador del activo (E4).
4. **No cambies la API ni la base de datos** salvo que sea imprescindible; si lo es, pregúntame antes. No borres funcionalidad existente: si un campo actual no aparece en el diseño, avísame.
5. Reutiliza los componentes que ya existan en el proyecto; no metas librerías nuevas sin preguntar. Excepción ya aprobada: `gsap` (con Flip y Draggable) y `three` desde npm, solo para las vistas de la sección 6 y cargadas bajo demanda (import dinámico), nunca desde un CDN.
6. Al terminar cada etapa: corre el linter/tests que tenga el proyecto y revisa la pantalla a 1366 px, 1920 px y en móvil.

## Usuarios y tono

Lo usan bodegueros, técnicos, jefes de mantenimiento y administrativos; muchos no son usuarios de tecnología (piensa en una persona mayor sin cursos de computación). Textos en español de Chile, tuteo, frases cortas, una línea de ayuda como máximo por campo. Prohibido en la interfaz: "baja lógica", "atributo", "entidad", "registro".

## Los 4 conceptos (deben entenderse sin manual)

- **Activo:** máquina de la planta con vida propia. Ej.: Cámara de frío 1.
- **Subactivo:** máquina con vida propia que depende de otra más grande; tiene n° de serie y se repara aparte. Ej.: Compresor Bitzer de la Cámara de frío 1. Se crea eligiendo "Depende de (máquina principal)".
- **Componente (parte):** parte de una máquina que se sigue por separado; no existe fuera de ella. Ej.: Burlete de la puerta. Puede tener sus propias partes.
- **Repuesto:** se compra por cantidad y se guarda en bodega; uno es igual a otro. Ej.: Filtro secador. Le puede servir a un activo, subactivo o componente.

Regla visible en la interfaz: «¿Te importa esa pieza en particular? → subactivo o componente. ¿Da lo mismo cuál uses de la bodega? → repuesto.»

## Sistema visual (obligatorio)

Sigue el **Estándar de UI de `CLAUDE.md`** y su fuente `Fase 2/Diseno/Planificacion360/SIGMA-Paleta-UI-Propuesta.html`: tokens `--sigma-purple` #6732F4, `--sigma-blue` #087BEA, `--sigma-cyan` #16C6C9 / `--sigma-cyan-dark` #007F8A, `--ink`, `--muted`, `--line`, `--canvas`, y los semánticos `--success` / `--warning` / `--danger`. Nada de hex sueltos.

- **Botones por función:** primario morado (Guardar, Crear OT, Nuevo activo) · secundario turquesa oscuro con texto blanco (Ubicaciones, acción paralela) · contorno azul (Abrir 360°, ver/navegar) · ghost morado suave (Cancelar) · rojo solo para eliminar. Máximo una morada y una turquesa por grupo.
- **Pestañas del módulo:** texto morado + subrayado de 3 px, contador en chip morado suave.
- **Encabezado:** navy sólido (#141B33), **sin degradados** (Bryan los rechazó) y sin efecto vidrio.
- **Superficies estilo 2026:** tarjetas blancas **sin borde** (solo un hairline casi invisible `0 0 0 1px rgba(23,34,59,.04)`) con sombras suaves en capas, radio 20 px en cards y 14 px en elementos internos. **Nada de bordes de color** en las tarjetas: el color va en íconos (fondo suave), chips y acciones. Filas internas sobre fondo gris muy claro en vez de líneas separadoras.
- **Color por concepto:** Activo morado · Subactivo azul · Componente turquesa oscuro · Repuesto ámbar #E08A00 (texto #8F4E00).
- **Chips:** pill, 11–12 px, peso 800, fondo suave + texto del tono. Estados siempre con punto: Operativo verde, Con observación / En mantenimiento ámbar, Detenido / Fuera de servicio rojo. Morado nunca para alertas.
- **KPIs:** ícono sobre fondo suave, número en `--ink`.
- **Formularios:** etiquetas 11 px peso 800 #4A556D; inputs borde #CFD6E3 radio 9; foco `outline: 3px solid rgba(22,198,201,.27)` + borde `--sigma-cyan-dark`.
- Criticidad: chip de contorno con escudo (Baja gris, Media gris oscuro, Alta ámbar, Crítica rojo). Stock en palabras: «Hay 3», «Quedan pocos», «Sin stock».
- Accesibilidad: contraste AA, áreas de clic ≥ 40 px, `<button type="button">` dentro del form del master, `aria-label` en botones de solo ícono.

## 0. Lo que YA está hecho y NO se rediseña: la ficha en 6 pasos

La pestaña **Ficha** (`View/Activos/Activos/ActivoForm.ascx`: riel de 6 pasos — Información básica, Ubicación, Datos técnicos, Componentes, Variables, Medidores —, tarjeta de ayuda por paso, «Sobre esta ficha», pie Anterior · Paso n de 6 · Cancelar · Siguiente · Guardar) ya fue modernizada. **No la cambies.** Solo dos ajustes:
- **«+ Nuevo activo» abre esa misma ficha en un modal ancho** (`pnlAccionesModal`: Cancelar / Siguiente / Guardar) y al guardar muestra la confirmación que ya existe (`pnlListo`: «Agregar sus componentes», «Registrar sus repuestos», «Abrir su centro 360°», «Crear otro activo», «Listo»). En el archivo de referencia: botón «+ Nuevo activo».
- **Fotos con portada:** el campo de foto pasa a aceptar **varias fotos**; cada miniatura tiene una **estrella** y la que tiene la estrella llena (morada) es la **portada** (la que se ve en tarjetas, mapa, 3D, explorador y cabecera del 360). La primera que se sube queda de portada; cambiarla es tocar otra estrella. Lo mismo en el visor de fotos («Usar como portada» / «Es la portada»), en «Documentos y galería» y en el explorador. Datos: tabla de fotos por activo con un campo `es_portada` (una sola por activo).

Los textos de la ficha que hoy dicen «equipo» pasan a «activo».

> Las secciones 1 y 2 de abajo describen el asistente del lienzo (C1–C4). Quedan **solo como referencia histórica**: manda la ficha actual de SIGMA.

## 1. Asistente "Crear nuevo activo" (referencia histórica, no implementar) — pantallas C1–C4

Modal de ~1060 px de ancho (en móvil, pantalla completa y columna de pasos arriba).

**Estructura (igual en los 4 pasos):**
- Encabezado: cuadrado morado 40 px con "+" blanco, título "Crear nuevo activo" (22/800), subtítulo "Completa la información principal del activo para registrarlo en tu centro.", botón X para cerrar.
- Columna izquierda (248 px, fondo --rail, borde derecho): lista vertical de pasos con círculo numerado 36 px y una línea vertical que los une. Paso actual: card --sigma-purple-soft, círculo morado con número blanco, título morado. Paso completado: círculo verde suave con ✓. Pendiente: círculo #EDF0F5. Cada paso es clicable.
- Debajo de los pasos: **tarjeta de ayuda** (borde --line, radio 12, fondo blanco) con círculo morado "i" y texto propio de cada paso (primera frase en negrita).
- Derecha: ícono morado + título de sección (19/800) + subtítulo gris; campos en grilla de 2 columnas, inputs de 46 px, radio 10, borde --field, etiquetas 14/700 con `*` rojo en obligatorios.
- Pie dentro de la columna derecha: izquierda botón de contorno gris con flecha ← ("Cancelar" en el paso 1, "Anterior" en los demás); derecha botón morado "Siguiente →" (en el último paso: "✓ Guardar activo").

**Paso 1 · Información básica** — "Datos principales del activo."
Grilla 2 columnas: Código* (input con botón interno de escanear QR) · Nombre* · Tipo* (select, se elige o se escribe uno nuevo y se crea al guardar) · Modelo (select) · Estado* (select con punto de color) · Criticidad* (select con punto de color) · Marca (select, se elige o se escribe) · N° Serie (input con botón interno de escanear código de barras) · Descripción (textarea a todo el ancho con contador "53/500") · **Fotografía del activo** (franja a todo el ancho, borde punteado, miniatura 64 px, "Arrastra una foto aquí", "PNG o JPG, hasta 5 MB…", botón "Elegir foto").
Ayuda: «Completa los datos principales del activo. Luego podrás agregar sus datos técnicos, documentos y partes en los siguientes pasos.»

**Paso 2 · Ubicación** — "Ubicación física del activo."
Planta* · Área · Centro de costo · Depende de (máquina principal) — opción por defecto "Ninguna: es una máquina principal"; ayuda corta: "Déjalo en «Ninguna» si no depende de otra máquina." (si elige una, el activo queda como subactivo).
Ayuda: «Indica dónde está el activo. Si depende de otra máquina más grande, por ejemplo el compresor de una cámara de frío, elígela en «Depende de» y quedará como su subactivo.»

**Paso 3 · Datos técnicos** (opcional) — "Placa, año y documentos."
Año de fabricación (select, "Sin dato") · Puesta en marcha (fecha con botón calendario) · Habilitado* (radio Sí/No como botones, Sí por defecto; ayuda "Si eliges «No», se oculta de las listas sin borrar su historia.") · **Datos de placa**: tabla editable Nombre / Valor / Unidad + botón quitar por fila + "Agregar dato" (ej. Potencia 5,5 kW) · **Documentos**: franja de arrastrar y soltar igual a la de la foto, "PDF, Word o imágenes, hasta 20 MB cada uno", botón "Elegir archivos".
Ayuda: «Este paso es opcional. Copia lo que dice la placa o el manual del activo. Puedes completarlo ahora o después, desde la ficha del activo.»

**Paso 4 · Partes** (opcional) — "Sus partes: motor, rodamientos…"
Filas de componentes: Nombre de la parte · Qué es · Dónde va (select) · quitar. Botón "Agregar parte". Caja de sugerencias "Partes comunes de una [tipo] · toca para agregarla" con chips (las sugerencias dependen del Tipo elegido; si no hay sugerencias para ese tipo, no muestres la caja).
Ayuda: «Este paso es opcional. Si la parte tiene número de serie y se repara aparte, mejor créala como subactivo. Filtros, correas o refrigerante son repuestos: se agregan después.»

**Validación amable:** al intentar avanzar o guardar con obligatorios vacíos, no solo bordes rojos: mensaje bajo el campo con ícono que dice qué hacer ("Escribe cómo se llama este activo"), el paso con error marcado en la columna izquierda, y foco en el primer campo con error.

**Al guardar:** cerrar el modal, mostrar confirmación clara y llevar al activo (o volver al listado con el nuevo activo resaltado).

## 2. Ficha en modo edición (pestaña "Ficha")

Debe usar **exactamente el mismo asistente** (mismos 4 pasos, misma columna de pasos y tarjetas de ayuda), pero dentro de la pestaña con **ancho controlado** (máx. ~1060 px, nunca estirado a todo el ancho), pasos libres para saltar entre ellos, botón final "Guardar cambios" y "Cancelar". Mostrar "Creado por / Último cambio" y un aviso "Hay cambios sin guardar" cuando corresponda. Problema actual a eliminar: inputs gigantes a todo el ancho, texto diminuto y la foto en una columna angosta con texto partido.

## 3. Centro 360° del activo (manda el archivo de referencia → «Abrir 360°»)

En el archivo de referencia, «Abrir 360°» (lista, tarjetas, explorador) abre la página completa del activo. Es la fuente de verdad visual; lo de abajo (B1/B3 del lienzo) queda como apoyo.
- **Página propia**, sin la banda navy: migas «Volver · Control de activos / Activos / CÓDIGO» y una **cabecera blanca** con la foto de portada (120 px, etiqueta «★ Portada · n fotos», abre el visor), nombre, chips de estado, criticidad y piezas con aviso, código · tipo · ubicación (o «Es parte de …» con enlace) · modelo, y acciones «Editar ficha» (contorno azul → pestaña Ficha) y «+ Nueva OT» (morado).
- **Barra de pestañas fija al hacer scroll** (tarjeta blanca): Resumen · Ficha · Componentes (contador) · Condición y medidores (contador rojo si hay lecturas fuera de rango) · Historial · Órdenes de trabajo (abiertas) · **Más ▾** (Mantenimiento, Inspecciones y tareas, Fallas e indisponibilidad, Documentos y galería, Repuestos y costos, Bitácora y trazabilidad; la pestaña muestra «Más · [elegida]») · separador · **SIGMA AI** (botón morado suave con punto turquesa; morado lleno cuando está activo). Flechas ← → recorren las pestañas.
- **Resumen:** 4 KPIs clicables (OT abiertas, Fallas abiertas, Próxima mantención, Disponibilidad 30 días); «Requiere atención» (fallas, subactivos con aviso, lecturas fuera de rango, repuestos bajo mínimo, OT abiertas; cada fila lleva a su pestaña) o «Nada pendiente»; «Actividad reciente» (5 eventos → Historial); «Condición en breve» con mini gráficos; a la derecha «Fotos del activo» (portada grande + miniaturas con estrella), «Identidad del activo», y SIGMA AI resumido (anillo de salud + primer hallazgo).
- **Ficha:** la ficha actual (sección 0), con «Cambios sin guardar».
- **Componentes:** organigrama — nodo del activo → 3 columnas iguales Subactivos · Componentes · Repuestos con flechas; buscador en la columna si hay más de 6; tocar un subactivo abre **su** Centro 360°, tocar un componente o repuesto abre el explorador con esa pieza seleccionada; «Agregar …» al pie de cada columna.
- **Condición y medidores:** «+ Agregar qué medir ▾» (Una variable de condición / Un contador), filtros Todas · Variables · Contadores, buscador y estado; tarjetas con valor grande, chip (Normal / Cerca del borde / Fuera de rango), tendencia «↑ 32 % en 14 días», gráfico con la banda normal sombreada y «Registrar lectura» en línea.
- **Historial:** línea de tiempo agrupada por mes con filtros (Órdenes, Fallas, Inspecciones, Lecturas, Cambios, Notas), buscador, «Exportar», y panel «Evento seleccionado» con «Abrir el registro de origen».
- **Órdenes de trabajo:** mini KPIs (Total, Abiertas, Cerradas), filtros, filas N° · trabajo · tipo · fecha y responsable · estado; al tocar se despliega el detalle (trabajo, repuestos, horas y evidencias) con «Ver OT completa» y «Cerrar OT».
- **Mantenimiento:** planes con barra de avance del ciclo, próximas actividades («Generar OT»), tareas recurrentes, alcance; a la derecha agenda del mes con puntos (planificada / con OT) y «Cómo se lee».
- **Inspecciones y tareas**, **Fallas e indisponibilidad** (disponibilidad % + franja de 30 días), **Documentos y galería** (fotos con estrella, documentos, evidencias de terreno), **Repuestos y costos** (4 KPIs, consumos/devoluciones/costo por mes, repuestos compatibles con «Pedir a bodega»), **Bitácora y trazabilidad** (notas con autor y origen App/Web, «Publicar», auditoría no editable).
- **SIGMA AI:** «Lo que el modelo observó en este activo, para que una persona lo revise.» Anillo de salud 0–100, hallazgos con riesgo (alto/medio/bajo), «Qué vio» / «Qué sugiere», barra de confianza y acciones Descartar (ghost) · Agendar revisión (turquesa) · Crear OT (morado); «Pregúntale a SIGMA AI» con preguntas sugeridas. Sin datos suficientes: estado vacío «Sin análisis predictivo para este activo».
- Cada pestaña tiene su **estado vacío** con una frase y, si corresponde, la acción para empezar (créalo con «+ Nuevo activo» en el archivo para verlos).

## 3b. Centro del activo — detalle del lienzo (B1, apoyo)

- **Cabecera:** migas (Activos › nombre), foto o ícono 88 px, nombre 26/800, chip de estado, chip de criticidad, código · tipo · ubicación completa "Planta › Área › Línea". Si es subactivo: "Es parte de: [máquina principal]" con enlace. Acciones: "Editar ficha" (contorno azul) y "+ Nueva OT" (morado).
- **Pestañas en este orden:** Resumen · Ficha · Componentes · Condición y medidores · Historial · Órdenes de trabajo · Más ▾ (Mantenimiento, Inspecciones y tareas, Fallas, Documentos y galería, Repuestos y costos, Bitácora). SIGMA AI va aparte, a la derecha, separado por una línea, como botón suave morado.
- **Componentes = "¿De qué está hecho este activo?"** con botón morado "+ Agregar", la regla (con ícono ampolleta) y la **leyenda de colores siempre visible**.
  - Diagrama tipo organigrama: nodo del activo arriba (borde morado), línea hacia 3 columnas: **Subactivos** (azul), **Componentes** (turquesa), **Repuestos** (ámbar). Cada columna: ícono, título, contador y una frase que explica qué es. Cada elemento es una card clicable con nombre, dato secundario y chip de estado (el chip va en su propia línea para que nunca se monte). Los componentes de un subactivo se muestran anidados bajo él con un conector. Repuestos muestran el stock en palabras y a qué le sirven ("Para: Burlete de la puerta"). Enlaces "Ver partes retiradas (n)" y "Ver en Inventario".
  - **Eliminar la vista duplicada** que hoy está debajo del diagrama (árbol + tabla + detalle). En su lugar: al tocar un elemento se marca seleccionado (borde turquesa) y se abre un **panel de detalle** al lado (debajo en pantallas angostas) con: nombre, chip de concepto, estado, observación destacada, datos (es parte de, qué es, dónde va, criticidad, instalado el, código), repuesto que le sirve con su stock, "Cambios anteriores" (historial de reemplazos), acciones "Crear OT" (morado) y "Registrar cambio" (turquesa) y enlace "Abrir la ficha completa".
- **Diálogo "¿Qué vas a agregar?" (B2):** al tocar "+ Agregar". Tres tarjetas grandes tipo radio: "Una máquina que depende de esta" (Subactivo), "Una parte de este activo" (Componente), "Un repuesto que le sirve" (Repuesto); cada una con su ícono y color, una regla y un ejemplo. Abajo la regla general, enlace "¿La parte ya está registrada en otro activo? Búscala y muévela aquí", botones "Cancelar" y "Continuar con «…»".

## 4. Condición y medidores + menú "Más" (B3)

- Menú "Más": desplegable con borde, sombra marcada y separación de 8 px de la barra (hoy se monta sobre el contenido sin separación). Ítems de 44 px con ícono.
- Jerarquía: hoy hay 3 botones al mismo nivel (Configurar / Nuevo contador / Registrar lectura). Cuando no hay nada configurado: solo un botón morado "Agregar qué medir" y dos tarjetas explicativas ("Una variable de condición" — ej. temperatura de la cámara en °C; "Un contador" — ej. horas de marcha del compresor). "Registrar lectura" aparece como acción principal solo cuando ya hay algo que medir; "Configurar" pasa a cada variable. No mostrar filtros cuando la lista está vacía.

## 5. Listado de activos en árbol (A1–A3)

- Título "Activos de la planta", subtítulo corto, acciones "Importar o exportar ▾" (contorno azul) y "+ Nuevo activo" (morado, abre el asistente).
- Buscador grande ("Busca por nombre, código o lugar…"), selector "Mostrar: Solo los que están en uso / También los que ya no se usan", filtros tipo chip con contador: Todos · Necesitan atención · En mantenimiento · Detenidos, y leyenda de colores de lo que cuelga de cada activo.
- Columnas: Activo · Dónde está · Estado (172 px, chips con `white-space: nowrap`) · Criticidad · OT abiertas · "Abrir ›". En pantallas chicas la tabla hace scroll horizontal dentro de su caja.
- Fila: ícono/foto 44 px, nombre 15/700, código · tipo, chips de lo que cuelga ("2 subactivos · 3 componentes · 3 repuestos" con su color), y si una parte necesita atención una línea corta con ícono ("Válvula de descarga: fuera de servicio"). Ubicación en dos líneas: "Refrigeración › Línea 1" y "Planta Renca".
- **Árbol:** los subactivos van debajo de su máquina principal, indentados, con conector en L azul claro y fondo levemente distinto.
- Estados vacíos: (a) búsqueda sin resultados — "No encontramos «…»", sugerencia "¿Quizás buscabas?", botones "Borrar la búsqueda" y "Crear «…» como activo nuevo", y aviso de que las piezas/repuestos se buscan dentro de cada activo o en Inventario; (b) planta sin activos — "Todavía no hay activos en esta planta", botones "Crear el primer activo" y "Cargar varios desde Excel", y 4 tarjetas que explican activo/subactivo/componente/repuesto con ejemplo.

## 6. Vistas de la planta y explorador del activo (E1–E4)

### Una sola referencia
Todo lo de esta sección sale de **un solo archivo**: `docs/rediseno-activos/sigma-activos-referencia.html`. Ábrelo con doble clic en el navegador (necesita internet para GSAP y three.js) y úsalo como fuente de verdad visual y de comportamiento:

| Pantalla | Dónde verla en el archivo |
|---|---|
| **E1 · Vista Lista** | Menú «Ver como» → **Lista** |
| **E2 · Vista Tarjetas** | Menú «Ver como» → **Tarjetas** |
| **E3 · Mapa por áreas** | Menú «Ver como» → **Mapa por áreas** |
| **E3 · Vista 3D** | Menú «Ver como» → **Vista 3D** |
| **E4 · Explorador del activo** | Tocar cualquier activo en cualquier vista |
| **Centro 360° del activo** | Botón «Abrir 360°» (lista, tarjetas o explorador) |
| **Nuevo activo (ficha en modal)** | Botón «+ Nuevo activo» |
| **Fotos con portada (estrella)** | Centro 360° → Resumen o Documentos y galería (prueba con «Dosificador de Manteca», trae 3 fotos) |

Reglas:
- No uses otras pantallas del lienzo para estas vistas; si algo del lienzo contradice este archivo, manda el archivo.
- Lee su código para entender el comportamiento, pero reescríbelo con la arquitectura, los componentes y los tokens del proyecto (no copies los estilos en línea tal cual).
- Los datos del archivo son de ejemplo; en SIGMA vienen de la API.

### Pestañas del módulo (ya implementadas en la web por Emilio)
Arriba de las vistas va la barra de pestañas **Activos · Componentes · Variables · Medidores · Tipos de activo · Modelos**, cada una con su contador. Respétala tal como está en la web (y en el archivo de referencia): contenedor gris claro con radio 14, pestaña activa blanca con sombra, texto morado y contador en morado suave. El menú «Ver como» (Lista · Tarjetas · Mapa por áreas · Vista 3D) y la vista elegida van **dentro del panel de la pestaña Activos**, debajo de las pestañas.

### Encabezado de la página
Banda de color sólido azul noche SIGMA (#141B33), limpia: sin degradados, sin transparencias ni efecto vidrio. Sobretítulo «Control de activos», título «Centro de activos 360°», bajada «Historial, mantenimiento y condición de tus activos.», botones «Importar o exportar ▾» (Importar desde Excel · Descargar plantilla · Exportar a Excel) y «+ Nuevo activo», Debajo de la banda, 4 indicadores en tarjetas blancas con ícono de color: Activos, Operativos, Detenidos, En mantenimiento. En toda la pantalla, nada de efecto vidrio (`backdrop-filter`) ni fondos semitransparentes.

### Qué abre cada clic (igual en todas las vistas)
- Tocar un activo (tarjeta completa, fila de la lista, tarjeta del mapa o tótem 3D) → **Explorador del activo** (E4).
- Botón **«Abrir 360°»** → **Centro 360° del activo** (sección 3, página completa).
- «Crear OT» → Nueva OT con el activo ya elegido.

### Menú «Ver como» (común a las 4 vistas)

Control segmentado como en el diseño: **Lista · Tarjetas · Mapa por áreas · Vista 3D**. Recordar la última vista de cada usuario. Buscador y filtros del diseño (E1/E2) arriba; en Mapa y 3D se reemplazan por sus propios controles.

### E3 · Mapa por áreas (2D)
- Cada lugar principal es una tarjeta blanca sin borde de color: chip del tipo («ÁREA»), ícono de ubicación en fondo suave, nombre, resumen de lo que tiene dentro («1 línea · 1 activo») y chip «Todo bien» / «n con avisos».
- Dentro, una fila por línea con la etiqueta a la izquierda y las tarjetas de activo (foto de portada en miniatura, nombre, código · tipo, estado, criticidad, hasta 3 subactivos más «y N más», conteo de partes y aviso). **Sin flechas entre activos**: no todos los clientes tienen un flujo de proceso.
- Bandeja lateral **«Por ubicar»** con los activos sin área. Arrastrar y soltar entre bandeja y líneas (GSAP Draggable + Flip para la animación) y alternativa accesible: el campo «Ubicación» del explorador.
- Sobre el mapa: ruta del nivel actual a la izquierda y, a la derecha, el botón **«Ir a un lugar o activo /»** que abre el *Navegador de ubicaciones* (ver más abajo) y «Subir un nivel».
- «+ Agregar línea» por área y «+ Agregar área» al final, en línea, sin salir de la vista. Cada cambio muestra un aviso con **Deshacer**.
- **Ubicaciones en árbol libre** (botón «Ubicaciones»): cada lugar tiene nombre y **tipo** (Área, Línea, Pasillo, Edificio, Piso, Sala… y la empresa puede crear tipos propios). Cada lugar se divide a su manera o no se divide, con hasta 5 niveles, y los activos pueden ir en cualquier lugar. Ejemplo: Panadería › Línea 1; Bodega › Pasillo A; Oficinas (sin dividir); Edificio Calderas › Piso 1 › Sala de máquinas. Editor: agregar dentro, renombrar, subir/bajar y eliminar (los activos quedan en «Por ubicar»). Los textos se arman con el tipo de cada lugar («+ Agregar pasillo», «2 pisos · 1 activo»). El mapa muestra un nivel a la vez con ruta («Planta Renca › Edificio Calderas»), «Entrar ›» y «Subir un nivel». Datos: tabla `ubicaciones` (id, padre, tipo, nombre, orden) + catálogo `tipos_de_lugar` (singular y plural) por empresa; el activo apunta a una sola ubicación.

### E3 · Vista 3D
- three.js con carga diferida al entrar a la vista; si no hay WebGL, mensaje amable y el resto sigue funcionando. Respetar `prefers-reduced-motion`, limitar `devicePixelRatio` a 2 y liberar geometrías/texturas al salir o reconstruir.
- **No se modelan máquinas.** Cada área es una plataforma con su color y el nombre pintado en el piso; cada activo es un **tótem con su foto de portada** (o una imagen por tipo si no tiene foto) que siempre mira a la cámara, con anillo y franja de color según estado y etiqueta HTML con nombre y estado. Subactivos como tótems chicos delante (máx. 3 + «+N»). Las etiquetas no se montan: si chocan, la menos importante se reduce a un punto.
- Navegación (todo esto es obligatorio, es lo que le da sentido a la vista):
  - **Navegador de ubicaciones** arriba a la izquierda (ver más abajo): ‹ anterior · botón con la ruta actual («Planta Renca › Bodega») y contador de avisos · siguiente ›. Elegir un lugar vuela la cámara a él (si es un sub-lugar, a su fila) y atenúa el resto; elegir un activo lo enfoca. **No usar una barra de chips con scroll horizontal**: con 40 áreas no escala.
  - Panel del área enfocada con sus activos por línea, anterior/siguiente para recorrer áreas y «Abrir» para ir al explorador.
  - **«Recorrer avisos (n)»**: va de activo con problemas en activo (los más graves primero), con tarjeta de avisos y Anterior / Siguiente / Explorar / Terminar.
  - Controles de cámara (acercar, alejar, girar 45°, vistas 3D / Planta / Frente, ver toda la planta, giro automático), «Solo con aviso», doble clic para acercarse, clic derecho para mover, teclado (flechas, + y −, 0, Esc).

### Navegador de ubicaciones (común a Mapa por áreas y Vista 3D)
Reemplaza cualquier barra de áreas. Debe funcionar igual con 3 o con 300 lugares.
- **Disparador único:** botón con ícono de ubicación, la ruta actual, badge rojo con avisos del lugar y tecla `/` visible. En 3D va acompañado de ‹ › para recorrer los lugares principales en orden.
- **Panel flotante** (popover de 420 px anclado al botón; se abre hacia arriba si no hay espacio abajo; en pantallas < 640 px es una hoja inferior):
  - Buscador con foco automático: «Busca un lugar o un activo…». Busca en nombre, ruta y tipo de lugar, y en nombre y código de activo (máx. 10 activos). Resalta la coincidencia.
  - Filtros pill: **Todo · Con avisos · Sin activos**.
  - Lista: «Toda la planta» arriba; luego **Ubicaciones · n** en orden de árbol con sangría por nivel (al buscar, sin sangría y con la ruta del padre en la segunda línea); «Por ubicar» si hay activos sin lugar; y al buscar, **Activos · n** con foto/ícono, código · ubicación y chip de estado. Cada lugar muestra su tipo, resumen de hijos, badge de avisos y «n activos». El lugar actual lleva una marca morada de 3 px a la izquierda.
  - Teclado: `/` lo abre desde cualquier parte de esas dos vistas, ↑ ↓ para moverse, Enter para ir, Esc para cerrar y devolver el foco al botón. Pie con esa ayuda (oculto en móvil).
- **Al elegir:** en 3D vuela la cámara (lugar → área o fila; activo → tótem; «Toda la planta» → vista general). En el Mapa cambia el nivel mostrado para que el lugar quede visible, hace scroll hasta él y lo destaca con un pulso morado breve; si es un activo, además abre su explorador.
- Accesible: `role="dialog"`, input `role="combobox"` con `aria-controls`, lista `role="listbox"` y opciones `role="option"`.

### E4 · Explorador del activo (modal)
- Cabecera: foto o ícono, nombre, código · tipo · ubicación, chips de estado, criticidad y «n piezas con aviso», migas cuando se entra a un subactivo y botón «Volver».
- Foto de portada arriba al centro (16:10) con **Ampliar** (abre el visor con todas las fotos, anterior/siguiente y «Usar como portada»), **Agregar fotos** y **Quitar**, dentro de la misma foto; la etiqueta dice «Portada · n fotos». Sin puntos ni números sobre la foto.
- Debajo, flechas tipo organigrama hacia **3 columnas iguales: Subactivos · Componentes · Repuestos**. Cada columna: título con contador y chip de estado; con más de 6 ítems, buscador y filtro «Con aviso» / «Por reponer»; lo urgente primero; scroll propio (debe funcionar con 40+ subactivos y 40+ componentes).
- En la Lista desplegada y en «Necesita atención» de las tarjetas, tocar un subactivo abre su explorador y tocar un componente o repuesto abre el del activo con esa pieza seleccionada.
- Tarjetas iguales: nombre arriba, estado debajo, chevron a la derecha. Componente o repuesto: el detalle se abre **dentro de su tarjeta** (estado editable + «Crear OT para esta pieza»; stock + «Ver la pieza» + «Pedir a bodega»). Al abrir un componente, la columna Repuestos se filtra a los que le sirven. Subactivo: entra a sus propias partes.
- Pie: Estado del activo, Ubicación (o «Es parte de»), «Abrir centro 360°» y «Crear OT».
- Es el mismo diagrama que la pestaña Componentes (B1): reutiliza los componentes.

### Datos que estas vistas necesitan (avísame si el backend no los tiene)
Foto de portada por activo; estructura de ubicación configurable por empresa (nombres de nivel 1 y 2, nivel 2 opcional); orden de los activos dentro de su línea; a qué componente le sirve cada repuesto («para»); stock y mínimo de cada repuesto; activos sin ubicación («Por ubicar»).

## Datos de ejemplo (solo para probar en local o en seeds, nunca hardcodeados)

Cámara de frío 1 · ACT-CAMARA-1 · Operativo · Crítica · Planta Renca › Refrigeración › Línea 1. Subactivos: Compresor Bitzer 4FES-5 (Operativo), Compresor Copeland ZB45 (En mantenimiento, con componente Válvula de descarga fuera de servicio). Componentes: Ventilador del evaporador, Termostato, Burlete de la puerta (Con observación). Repuestos: Filtro secador (hay 3), Burlete 2 m (sin stock), Refrigerante R-404A (bajo el mínimo).

## Criterios de aceptación

- El asistente tiene exactamente 4 pasos (Información básica, Ubicación, Datos técnicos, Partes) con la columna lateral, tarjetas de ayuda por paso y pie descritos; mismo componente para crear y para editar.
- La pestaña Componentes ya no repite información (sin árbol + tabla debajo del diagrama).
- Ningún chip se corta ni se monta sobre otra columna; nada se estira a todo el ancho en formularios.
- Una sola acción morada por grupo; tokens usados como variables, no hex sueltos.
- Funciona bien a 1366 px, 1920 px, en el modal de ~1060 px y en móvil (apilado).
- Navegable con teclado, foco visible turquesa, contraste AA.
- Las cuatro vistas y el explorador se ven y se comportan igual que `sigma-activos-referencia.html`, incluida la navegación con el Navegador de ubicaciones (buscador, filtros, teclado y `/`) y el recorrido de avisos.
- Ningún texto dice "equipo" ni asume que existen líneas.

Empieza por el paso 1 de "Cómo quiero que trabajes": explora el repo y tráeme el plan.
