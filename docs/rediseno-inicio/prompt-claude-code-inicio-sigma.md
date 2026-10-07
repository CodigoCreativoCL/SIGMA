# Prompt para Claude Code — Inicio de SIGMA (Default.aspx)

Rediseña el contenido de la página de inicio de SIGMA según la referencia `docs/rediseno-inicio/sigma-inicio-referencia.html`. Ábrela en el navegador y pruébala antes de tocar código. En la esquina inferior derecha tiene un control para cambiar entre «Propuesta 1 / Propuesta 2», comparar «Sidebar nuevo / Actual» y ver los dos escenarios: «Con datos» y «Sin órdenes aún».

**Antes de empezar, pregúntame cuál propuesta del inicio implementamos.** La 1 está descrita en «Estructura del contenido»; la 2, en la sección «Propuesta 2» al final.

El trabajo tiene **dos etapas**: primero el contenido del inicio y después el sidebar nuevo (sección «Etapa 2»). No mezcles ambas en un mismo cambio.

## Lo que NO se toca (etapa 1)

- **La topbar queda exactamente como está**: el selector de cliente, «Reportar problema», «Ayuda», la campana y el perfil. Lo mismo el sidebar hasta la etapa 2: `Master/Default.master`, `sigma-layout.css` y el menú `MenusLateral`.
- El encabezado se mantiene: eyebrow con la fecha (`cphEyebrow` / `litFecha`), «¡Hola, {nombre}! 👋» (`cphTitulo`) y el subtítulo (`cphSubtitulo`). Solo se agregan acciones a la derecha.
- Vocabulario: siempre «activo», nunca «equipo».

## Cómo quiero que trabajes

1. Lee `CLAUDE.md`, `Css/LookAndFeel/sigma-brand.css` (tokens `--sg-*`, Sora) y `sigma-layout.css`. Respeta el estándar de botones:
   - primario morado;
   - secundario cyan oscuro;
   - outline azul;
   - ghost;
   - rojo solo para acciones destructivas.
2. Revisa:
   - `Default.aspx` y `Default.aspx.cs`;
   - los SVG de `Imagen/sigma-ai/` (`sigma-ai-symbol-gradient.svg`, `sigma-ai-wordmark-dark.svg`) y `Imagen/sigma-twin/sigma-twin-symbol-gradient.svg`;
   - `View/SigmaAI/`, `AlertaController` (`ES_PREDICCION`) y lo que exista de órdenes de trabajo.
3. Presenta un plan corto y espera mi OK. El plan debe decir:
   - de dónde sale cada dato;
   - qué SP o servicio falta crear;
   - qué queda en estado vacío mientras no haya datos.
4. Crea `Css/LookAndFeel/sigma-inicio.css` y `Js/sigma-inicio.js`, y cárgalos desde `cphHeder` / `chpScript` de `Default.aspx`. Los estilos no van inline.
5. **No inventes cifras.** Hoy `Default.aspx` explica que no hay tablas de OT con datos. Cada bloque que dependa de OT muestra su estado vacío hasta que el SP devuelva filas, igual que el escenario «Sin órdenes aún» de la referencia.
6. Verifica en 1920, 1280 y 390 px, sin scroll horizontal y con el sidebar colapsado (`body.enlarged`).

## Estructura del contenido (`cphBody`)

1. **Acciones del encabezado** (a la derecha del título):
   - chip de turno (punto verde y «Turno A · 07:00 – 15:00»; si no hay turnos configurados, se oculta);
   - «Solicitud de trabajo» (outline);
   - «+ Nueva orden de trabajo» (primario).
2. **Accesos directos**:
   - Grilla `repeat(auto-fill, minmax(164px, 1fr))`. Cada tarjeta lleva el ícono de marca, el nombre y una línea de estado en vivo («24 abiertas · 5 vencidas», «63 fuera de umbral»). Un punto de color aparece solo cuando hay algo que atender.
   - **SIGMA Twin y SIGMA AI** van con fondo navy y su símbolo de degradado oficial. El resto usa el mismo lenguaje (trazo con el degradado teal → azul → violeta → rosa y nodos blancos con borde de color) sobre un fondo lila suave. Los íconos nuevos van como SVG en `Imagen/accesos/`.
   - «Personalizar» entra en modo edición: las tarjetas tiemblan, cada una muestra una ✕ y aparece «+ Agregar acceso» con la lista de módulos que faltan. La selección se guarda por usuario en una tabla de preferencias o en el perfil (propón cuál en el plan). Solo se ofrecen módulos a los que el usuario tiene permiso.
   - Por defecto: SIGMA Twin, SIGMA AI, Órdenes de trabajo, Planificación, Control de activos, Centro de repuestos, Permisos de trabajo y Soporte.
3. **Widget SIGMA AI**: oscuro y futurista. Es la única superficie oscura del contenido.
   - **Fondo**: `#070B16` con halos radiales teal, violeta y rosa, una grilla de 32 px que se desvanece y una línea de escaneo lenta. El borde es un anillo violeta translúcido.
   - **Encabezado**:
     - símbolo de SIGMA AI con un anillo cónico que gira;
     - wordmark oscuro con «Mantenimiento predictivo · {cliente}»;
     - a la derecha, «Analizando N activos · N señales/min» y la pastilla «EN VIVO» con un punto teal que late.
   - **Predicción principal** (columna izquierda):
     - confianza del modelo;
     - activo y componente;
     - **anillo con la probabilidad de falla** (degradado de marca);
     - «Falla probable en 12–16 días» con texto en degradado y la fecha límite;
     - 3 razones con su dato en negrita.
   - **Gráfico** de la señal que la explica:
     - una sola serie y un solo eje;
     - 30 días medidos (línea violeta con área) y el punto «hoy» en vivo con brillo;
     - proyección de 21 días (línea rosa punteada con banda de incertidumbre);
     - línea de alarma ámbar rotulada.
     - Debe tener cruz con tooltip al pasar el mouse: fecha y valor, y en la proyección también el rango.
     - Acciones: «Crear OT preventiva» (primario, abre la OT con el activo y la predicción ya cargados), «Ver análisis» y «Descartar». Descartar alimenta el aprendizaje del modelo.
   - **Flujo de predicciones** (columna derecha):
     - hasta 5 tarjetas con activo · componente, falla, horizonte, «hace N min», % y una barra de color (≥ 70 % rosa, 50–69 % ámbar, < 50 % teal);
     - las nuevas entran arriba con un destello teal;
     - al hacer clic en una tarjeta, esa pasa a ser la predicción principal y la anterior vuelve a la lista.
     - Abajo, 3 cifras: fallas anticipadas en el mes, horas de detención evitadas y % de aciertos del modelo.
   - **Preguntar a SIGMA AI**:
     - campo de pregunta con botón de envío y 3 sugerencias;
     - la respuesta aparece dentro del widget con efecto de escritura;
     - desde ahí se puede pasar a la conversación completa de `View/SigmaAI/`.
   - **Tiempo real**:
     - polling liviano cada 15–30 s a un servicio (por ejemplo `WsSigmaAI.asmx/Predicciones`) que devuelva solo lo nuevo desde la última marca de tiempo;
     - el punto «hoy» y el contador de señales se actualizan entre polls;
     - el polling se pausa con `document.hidden` y se respeta `prefers-reduced-motion`.
   - **Estado «Aprendiendo»** (sin historial suficiente):
     - anillo teal «12 de 30 días de lecturas»;
     - «SIGMA AI está aprendiendo cómo funciona tu planta» con su explicación;
     - activos conectados, señales por minuto y «Primeras predicciones en ~N días»;
     - la caja de preguntas sigue disponible.
4. **Indicadores** (4 tarjetas): OT abiertas (con vencidas en rojo), cumplimiento del preventivo (barra con la meta marcada), disponibilidad y MTTR (variación contra el mes anterior y sparkline de 8 semanas).
5. **Órdenes de trabajo recientes**: OT, trabajo con activo y tipo, responsable con iniciales, prioridad (texto de color), estado en pastilla («Vencida hace 2 días» en rojo) y un chevron. Al final, «Ver todas».
6. **Columna derecha**:
   - «Hoy en tu turno»: línea de tiempo con hora, tarea, responsable y estado (hecha tachada en verde, en curso en morado, pendiente en gris). Si no hay tareas: «No hay tareas programadas para hoy» y el botón «Planificar la semana».
   - «Requieren tu atención»: las 4 notificaciones más importantes del centro de notificaciones, con la misma agrupación por tipo + lugar, y «Ver todas las notificaciones».
7. **Estado vacío del panel**: «Tus indicadores aparecen con la primera orden de trabajo» con 3 pasos (activos registrados ✓, plan preventivo, primera OT) y los botones «Crear la primera OT» y «Armar el plan preventivo».

## Responsive

- **< 1280 px**: la columna derecha baja debajo, en 2 columnas, y los indicadores quedan en 2 × 2.
- **< 1100 px**: el widget apila la predicción y el flujo.
- **< 900 px**:
  - el sidebar pasa a menú deslizable con scrim (el comportamiento actual de Adminto);
  - la topbar deja solo los íconos;
  - accesos directos en 2 columnas.
- **< 560 px**: la tabla de OT muestra solo trabajo y estado, y el gráfico oculta las etiquetas intermedias.

## Criterios de aceptación

- En la etapa 1, el sidebar y la topbar se ven idénticos a hoy.
- Ningún número del inicio está escrito a mano: cada uno sale de un SP o servicio, o se muestra su estado vacío.
- El widget de SIGMA AI se actualiza solo, sin recargar la página, y deja de consultar cuando la pestaña está oculta.
- Una predicción se convierte en OT en 2 clics.
- Los accesos directos se pueden personalizar y la elección persiste entre sesiones.

## Etapa 2 — Sidebar propuesto

En la referencia, elige «Sidebar propuesto» en el control de abajo a la derecha. Antes de tocar nada:

- Lee `MenusLateral` (el user control), `sigma-layout.css` (sección 1, SIDEBAR) y cómo Adminto / metismenu arma los submenús y el modo `body.enlarged`.
- Confirma en el plan de dónde salen los ítems del menú (tabla de menús y permisos) para no fijar nada en el HTML. El menú sigue respetando los permisos del perfil.

**Cambios:**

1. **Grupos con título** en vez de «MENUS». Los grupos, el orden de los ítems y el ícono de cada uno salen de la tabla de menús. Si hace falta, propón una columna `men_grupo` y otra de orden.
   - Sin título, arriba de todo: Inicio.
   - **Operación:** Mantenimiento, Activos, Inventario.
   - **Inteligencia:** SIGMA AI, SIGMA Twin.
   - **Gestión:** Soporte (Centro de soporte, Problemas detectados, Campañas, Centro de ayuda, Analítica), Terceros, Cliente.
   - **Sistema:** Utilidades.
2. **«Inicio»** como primer ítem, activo en `Default.aspx`, con el mismo estilo de ítem activo que ya existe (degradado violeta y acento teal).
3. **Sin duplicados con la topbar**:
   - «Alertas» sale del sidebar porque vive en la campana; sus pantallas siguen accesibles desde ahí y desde «Ir a…».
   - **Soporte se queda** en el sidebar (grupo Gestión), con un contador gris de tickets abiertos. Ahí viven las campañas, el centro de ayuda y la analítica. «Reportar problema» y «Ayuda» de la topbar son solo atajos para el usuario final.
4. **Nombres de una línea**: «Centro de Mantenimiento» → «Mantenimiento» y «Control de activos» → «Activos». El nombre completo queda en el submenú.
5. **Contadores** a la derecha del ítem, en pastilla: rojo para vencidas (Mantenimiento: OT vencidas), ámbar para umbrales (Inventario: repuestos fuera de umbral) y teal para novedades (SIGMA AI: predicciones nuevas).
   - Reutiliza `.sigma-menu-alert`.
   - Los conteos salen del mismo servicio que la campana y se refrescan con ella.
   - En el modo colapsado se convierten en un punto sobre el ícono.
6. **Submenús en acordeón** con línea guía a la izquierda. El estado abierto o cerrado de cada grupo se recuerda por usuario.
7. **«Ir a…» con Ctrl + K** (⌘ K en Mac):
   - botón arriba del menú;
   - abre una paleta centrada que busca pantallas (según permisos), activos, OT y repuestos;
   - flechas para moverse, Enter para abrir y Esc para cerrar;
   - sin texto muestra Recientes y las pantallas principales.
   - En el sidebar propuesto, el «Buscar...» de la topbar abre la misma paleta.
   - Propón en el plan el servicio de búsqueda (por ejemplo `WsBuscar.asmx`, con un tope de 12 resultados).
8. **Recientes** al final del menú: las últimas 3 fichas o pantallas abiertas, guardadas por usuario.
9. **SIGMA AI y SIGMA Twin** con su símbolo de marca (`Imagen/sigma-ai/sigma-ai-symbol-gradient.svg` y `Imagen/sigma-twin/sigma-twin-symbol-gradient.svg`) dentro del chip del ícono.
10. **Contraer menú**: botón abajo, sobre la ficha del usuario, que alterna `body.enlarged` y se recuerda. En el modo colapsado:
    - los títulos de grupo pasan a ser separadores;
    - Recientes se oculta;
    - al pasar el mouse o con foco, el submenú se abre **flotando** a la derecha con el nombre del módulo como título.
11. **Accesibilidad**:
    - títulos de grupo al 55 % de opacidad (hoy 34 %);
    - íconos de 17 px en un chip de 30;
    - `aria-expanded` en los padres;
    - `aria-current="page"` en el activo;
    - foco visible.

**Criterios de aceptación de la etapa 2:**

- Ningún módulo queda inaccesible: todo lo que salió del sidebar se alcanza desde la topbar o desde «Ir a…».
- Con el menú colapsado, todas las opciones de los submenús se alcanzan con mouse y con teclado.
- El menú sin submenús abiertos cabe en una pantalla de 1366 × 768 sin scroll.

## Propuesta 2 — Inicio con SIGMA AI al centro

En la referencia, elige «Propuesta 2». Usa las librerías que ya están en el repo, sin agregar otras:

- `Js/gsap/gsap.min.js` (GSAP 3.12.5). Draggable y Flip están disponibles. No hay ScrollTrigger, así que las entradas al hacer scroll se resuelven con `IntersectionObserver` + GSAP.
- `Js/three/three.module.min.js` (Three.js r160, módulo ES). Revisa cómo lo cargan `sigma-planta.js` y `sigma-bodega3d.js` y sigue el mismo patrón (`<script type="module">` o import map).

Crea `Js/sigma-inicio-ai3d.js` (módulo) con el núcleo 3D y `Js/sigma-inicio.js` con el resto.

### 1. Héroe oscuro con el núcleo 3D

Es una sola superficie oscura, con el mismo fondo que el widget SIGMA AI: halos, grilla que se desvanece y anillo violeta translúcido. Unos 560 px de alto en escritorio.

- **Escena Three.js** a la derecha:
  - un **núcleo** (icosaedro con shader fresnel en el degradado de marca teal → azul → violeta → rosa, bandas que respiran, malla de alambre y una coraza de ~1.100 partículas);
  - **tres órbitas** con los activos de la planta, un punto por activo:
    - los saludables van en azul tenue;
    - los que tienen predicción usan el color de su severidad (≥ 70 % rosa, 50–69 % ámbar, < 50 % teal), laten y tienen un **enlace de datos** al núcleo con «paquetes» que viajan hacia él;
  - fondo de estrellas.
  - **Interacción**:
    - paralaje suave con el mouse;
    - hover sobre un activo: tooltip blanco con nombre, componente y «78 % · falla en 12–16 días», o «Salud 94/100» si está saludable;
    - clic: SIGMA AI explica esa predicción en la caja de respuestas.
  - **Etiquetas flotantes** HTML proyectadas desde 3D para las 2 predicciones principales («78 % · Amasadora espiral línea 1»).
  - **Intro con GSAP**: el núcleo crece, las órbitas se abren y los activos llegan a su órbita en cascada.
  - **Rendimiento**:
    - `setPixelRatio(min(dpr, 1,75))`;
    - se pausa fuera de pantalla (`IntersectionObserver`) y con `document.hidden`;
    - `dispose()` completo al salir.
  - **Respaldo**: si WebGL no está disponible o el módulo no carga, se muestra un orbe en CSS y la página sigue funcionando.
  - **`prefers-reduced-motion`**: escena estática, sin intro ni rotación.
- **Texto** a la izquierda:
  - pastilla «SIGMA AI EN VIVO» con la fecha y el turno;
  - saludo según la hora («Buenos días / Buenas tardes / Buenas noches,»), con el nombre en degradado; las letras entran en cascada con GSAP;
  - **resumen del día escrito por SIGMA AI**: activos vigilados, señales por minuto en vivo y las 2 predicciones más urgentes como **chips clicables** con un punto de severidad;
  - botones «Ver qué viene esta semana» (primario, baja a la línea de 30 días) y «Preguntar a SIGMA AI».
- **4 cifras en vidrio** con conteo animado:
  - salud de la planta (anillo 0–100 y variación contra ayer);
  - activos vigilados y señales por minuto;
  - fallas anticipadas en el mes;
  - horas de detención evitadas.
- **Barra «Pregúntale a SIGMA AI»**:
  - monta sobre el borde inferior del héroe, con un borde en degradado que gira (`@property --ang`) y una onda de voz animada;
  - el placeholder escribe y borra preguntas de ejemplo;
  - debajo, 3 sugerencias y la respuesta con efecto de escritura.
  - Conéctala al mismo servicio de `View/SigmaAI/`.

### 2. «Próximos 30 días según SIGMA AI»

Línea de tiempo de las fallas previstas.

- **Ejes**: Hoy, +1 sem, +2 sem, +3 sem, +4 sem.
- **Filas**: activo, componente, anillo con la probabilidad y una cápsula entre los días mínimo y máximo de la falla, con el color de su severidad. Las cápsulas crecen desde la izquierda al entrar en pantalla.
- **Detenciones programadas** como columnas rayadas. Salen del calendario de planificación; el prototipo usa los sábados.
- **Sugerencia de SIGMA AI por fila**:
  - «Programar el sáb 10» si hay una detención antes de la falla;
  - «Crear OT urgente» si no alcanza.
  - Al confirmar se crea la OT preventiva y aparece un rombo ✓ sobre la detención elegida.
- Al pasar el mouse por una fila, el activo late en el núcleo 3D.

### 3. «Tus módulos» (bento)

- **SIGMA Twin y SIGMA AI** como tarjetas grandes oscuras (2 × 2) con su símbolo flotando.
- 8 tarjetas chicas con dato en vivo: Órdenes de trabajo, Planificación, Control de activos, Centro de repuestos, **Soporte (tickets y campañas activas)**, Permisos de trabajo, Alertas y Medidores.
- Inclinación magnética al pasar el mouse (GSAP, con retorno elástico).

### 4. Debajo

Indicadores, órdenes de trabajo recientes, «Hoy en tu turno» y «Requieren tu atención», iguales a la Propuesta 1.

### Estado «Sin órdenes aún»

- El núcleo se calma: sin activos en riesgo ni enlaces.
- El resumen explica el aprendizaje («día 12 de 30, primeras predicciones en ~18 días»).
- Las cifras pasan a aprendizaje.
- La línea de 30 días muestra la barra de aprendizaje.
- Los contadores de Mantenimiento y SIGMA AI del sidebar se ocultan.

### Criterios de aceptación

- Ningún número está escrito a mano.
- El héroe mantiene 60 fps en un equipo de oficina, y la escena deja de dibujar cuando no se ve.
- Sin WebGL, la página es igual de útil.
- Todo lo que muestra el 3D también se puede leer en texto: el resumen y la línea de 30 días.
