# Prompt para Claude Code — Módulo Soporte (SIGMA)

1. Copia `sigma-soporte-referencia.html` en el repositorio, en `docs/rediseno-soporte/`. Es la **única referencia visual y de comportamiento** del módulo.
2. Copia todo lo que está debajo de la línea y pégalo en la sesión de Claude Code abierta en el repositorio de SIGMA.

---

Vamos a implementar el módulo **Soporte** de SIGMA: mesa de ayuda (tickets) + campañas + centro de ayuda (cápsulas, documentos, videos) + ayuda contextual + encuestas + analítica, como **un solo ecosistema**: usuario → ayuda → soporte → conocimiento → campañas → usuario.

La fuente de verdad es `docs/rediseno-soporte/sigma-soporte-referencia.html`. Ábrelo con doble clic. Arriba hay un selector **«Equipo de soporte / Usuario de planta»** para ver las dos experiencias, y abajo a la derecha **«Ver estados vacíos»** muestra cada pantalla sin datos. Lee su código para entender el comportamiento, pero reescríbelo con la arquitectura, los componentes y los tokens del proyecto. Los datos del archivo son de ejemplo y en SIGMA vienen de la base de datos.

**Vocabulario:** siempre «activo», nunca «equipo». El módulo de SIGMA se llama **Activos**.

## Cómo quiero que trabajes

1. **Explora primero, no edites todavía.** Lee `MD/SIGMA_ESTADO_DESARROLLO.md` y `CLAUDE.md`. Revisa cómo están hechos los menús (`mnu_*`, `mnu_visible`), `Simple.master` / `SigmaModal.open`, las notificaciones de la campana y los perfiles/permisos. Revisa también si ya existe algo de soporte o de ayuda.
2. **Muéstrame un plan** antes de implementar:
   - el modelo de datos (tablas y SP);
   - las páginas y los controles;
   - los permisos (quién ve «Equipo de soporte»);
   - cómo se captura el contexto de la pantalla.

   Espera mi OK.
3. **Implementa por etapas**, con un commit por etapa:
   - (a) tablas, SP y menús;
   - (b) «Reportar problema» con contexto detectado y sugerencia de ayuda;
   - (c) bandeja de problemas;
   - (d) detalle 360 del ticket con trazabilidad, respuestas, notas internas, asignación y estados;
   - (e) encuesta al resolver y reapertura;
   - (f) centro de ayuda, biblioteca, detalle de cápsula/documento y versionado;
   - (g) crear cápsula con vinculación contextual;
   - (h) ayuda contextual «? Ayuda» en el master;
   - (i) campañas: centro, asistente, constructor de audiencia, programación y vista previa;
   - (j) entrega de campañas al usuario: banner, modal, card y campana;
   - (k) analítica de soporte y del centro de ayuda;
   - (l) problemas recurrentes → crear cápsula precargada.
4. Convenciones del repo:
   - UTF-8 con BOM y CRLF;
   - `<button type="button">` dentro del form del master;
   - compilar con `aspnet_compiler` tras tocar C#;
   - SQL con `_scratch/aplicar_sql.py`;
   - los menús nunca se borran (`mnu_visible = 0`).
5. No metas librerías nuevas. Los gráficos del archivo son SVG/HTML simples y así deben quedar. Al cerrar cada etapa, actualiza la bitácora de `MD/SIGMA_ESTADO_DESARROLLO.md`.

## Sistema visual (obligatorio)

Usa el **Estándar de UI de `CLAUDE.md`**: tokens `--sigma-purple` #6732F4, `--sigma-blue` #087BEA, `--sigma-cyan` / `--sigma-cyan-dark` #007F8A, `--ink`, `--muted`, `--line`, `--canvas` y los semánticos. La tipografía es Sora.

- **Botones por función:**
  - primario morado (Nuevo problema, Cambiar estado, Publicar, Crear contenido);
  - secundario turquesa oscuro (Asignar, Nueva versión, Ver cápsula en sugerencias);
  - contorno azul para navegar (Ver problemas, Ver campaña, Ver análisis);
  - ghost morado suave para Cancelar;
  - rojo solo para lo destructivo.

  Máximo uno morado y uno turquesa por grupo.
- **Cards blancas sin borde** con sombra suave en capas, radio 16. El color va en íconos, chips y acciones.
- **Pestañas:** texto morado + subrayado de 3 px.
- **Foco:** anillo turquesa.
- **Sin degradados en encabezados.** La portada del centro de ayuda es navy sólido.
- **Estados del ticket** (chip con punto, colores semánticos, nunca morado):
  - Reportado, En revisión y Asignado en azul información;
  - En análisis y En corrección en ámbar;
  - Esperando usuario en turquesa;
  - Resuelto en verde;
  - Cerrado en gris;
  - Reabierto en rojo.
- **Prioridad:** chip con barras de señal además del color. Crítica es rojo lleno; Alta, rojo suave; Media, ámbar; Baja, gris.
- **SLA:** se muestra en palabras: «Vence en 3h 48m», «Vencido hace 12 min», «SLA cumplido».
- Notificaciones con un **punto**, no con contadores grandes.

## Mapa de pantallas (dónde verlas en el archivo)

| # | Pantalla | Dónde |
|---|---|---|
| 1 | Centro de Soporte (hub) | Menú Soporte → Inicio de soporte |
| 2 | Bandeja «Problemas detectados» | Menú → Problemas detectados |
| 3, 19 | Crear problema + contexto detectado + sugerencia de ayuda | «+ Nuevo problema» o «Reportar problema» en la barra superior (escribe «No sé cómo crear una ubicación») |
| 4, 5 | Detalle 360 del ticket + trazabilidad | Cualquier ticket (ej. SUP-001248) |
| 6 | Encuesta del usuario | En el ticket: Cambiar estado → Resuelto → «Ver como usuario» → Responder |
| 7 | Analítica de soporte + problemas recurrentes | Menú → Analítica → Soporte |
| 8 | Centro de campañas | Menú → Campañas |
| 9–12 | Crear campaña: contenido, audiencia, comportamiento, programación, vista previa, publicar | «+ Crear campaña» |
| 13 | Centro de ayuda | Menú → Centro de ayuda |
| 14 | Biblioteca (Cápsulas / Documentos / Videos) | Submenús del centro de ayuda |
| 15 | Detalle de cápsula | «Cómo crear una ubicación» |
| 16, 17 | Crear cápsula + vinculación contextual | «+ Crear contenido» (paso 3: Ubicación) |
| 18, 22 | Ayuda contextual | Vista «Usuario de planta» → «? Ayuda» |
| 20 | Analítica del centro de ayuda | Menú → Analítica → Centro de ayuda |
| 21 | Historial / versionado | «Manual de Inventario» → Versiones → Historial |
| 26 | Problema recurrente → cápsula precargada | Analítica → «Ver análisis» → «Crear cápsula» |
| 27 | Campaña que promociona contenido | Detalle de cápsula → «Promocionar» |
| 28 | Experiencia del usuario final | Selector «Usuario de planta» |
| 29 | Notificaciones | Campana |
| 30 | Responsive | Menú lateral reducido bajo 1180 px; bajo 720 px, barra inferior |
| 32 | Estados vacíos | «Ver estados vacíos» (abajo a la derecha) |

## Reglas de comportamiento clave

- **Contexto automático:** cada reporte guarda módulo, pantalla, registro, cliente, planta, usuario, fecha, navegador y URL. El usuario solo puede corregir la pantalla y el registro; lo demás va bloqueado con candado. El master debe exponer el contexto de la pantalla actual, por ejemplo con un `data-` en el body o una función JS por página.
- **Sugerencia antes del ticket:** mientras escribe el título o la descripción, se buscan contenidos publicados vinculados a esa pantalla o con palabras parecidas.
  - Las opciones son «Ver cápsula», «Sí, se resolvió» (no crea ticket y se registra como ticket evitado) y «Continuar con el reporte».
  - Si continúa, queda en la trazabilidad: «Se sugirió X y la ayuda no resolvió el problema».
- **Trazabilidad:** todo cambio es un evento inmutable con tipo, autor, fecha y payload.
  - Tipos: reporte, comentario, solicitud de información, archivo, cambio de estado, cambio de asignación, nota interna, resolución, encuesta y sistema.
  - Se distingue visualmente: usuario en azul, soporte en morado, sistema en gris, nota interna en ámbar y resolución en verde.
  - Hay filtros: Todo, Conversación, Cambios, Archivos y Notas internas.
- **Respuesta:** hay dos modos, «Responder al usuario» y «Nota interna» (esta última solo la ve soporte).
  - «Pedir información» pasa el ticket a Esperando usuario y pausa el SLA. Cuando el usuario responde, vuelve a En análisis.
  - Se puede insertar contenido de ayuda en la respuesta.
- **Resolver:** pide la nota de solución y envía la encuesta.
  - La encuesta pregunta «¿Tu problema fue solucionado?» (Sí, Parcialmente o No) con estrellas de 1 a 5 y un comentario.
  - Registra CSAT, comentario, usuario, fecha, ticket y responsable.
  - Con «No», el botón cambia a **«Reabrir problema»** y el ticket pasa a Reabierto.
- **Bandeja:**
  - Pestañas: Todos, Mis tickets, Sin asignar, Críticos, Esperando usuario y Cerrados.
  - Búsqueda global.
  - Filtros como chips con menú: Estado, Prioridad, Categoría, Cliente, Planta, Usuario, Perfil, Área responsable, Responsable, Módulo, Fecha y SLA.
  - Lista híbrida con borde rojo a la izquierda para lo crítico, punto azul para novedades sin leer y etiqueta «Recurrente».
- **Problemas recurrentes:** se agrupan tickets parecidos (mismo módulo y pantalla, y texto similar).
  - «Crear cápsula» o «Crear artículo» abre el asistente con categoría, módulo, pantalla, contexto y causa ya cargados.
  - Desde entonces, la cápsula se sugiere en los nuevos reportes de esa pantalla.
- **Vinculación contextual:** cada contenido se vincula a Módulo › Submódulo › Pantalla › Sección, mediante un catálogo de pantallas por empresa.
  - El botón «? Ayuda» del master muestra hasta 3 contenidos de la pantalla actual: primero el de la sección exacta y luego los del nivel superior.
  - También incluye «Ver todo el contenido» y «Reportar problema».
- **Versionado:** cada publicación crea una versión con número, fecha, autor, estado y nota. Se puede restaurar una versión anterior, y la restauración se publica como una versión nueva.
- **Campañas:**
  - Pasos: Contenido, Audiencia, Comportamiento, Programación, Vista previa y Publicar.
  - **Audiencia:** condiciones (Usuario, Estado, Perfil, Cliente, Planta, Área, Rol, Módulo y Grupo) con «es / no es» y Y/O, más segmentos guardados. El conteo de usuarios alcanzados se recalcula al instante con un SP.
  - **Formatos:** banner, modal, card («Te puede interesar») y centro de notificaciones.
  - **Frecuencia:** una vez, una vez por usuario, hasta que lo lea o repetir cada X días.
  - Se registran visualizaciones e interacciones por usuario.
  - **Vista previa** en escritorio, tablet y móvil.
- **Promocionar contenido:** desde una cápsula o un documento se abre el asistente de campañas con el contenido y el botón «Ver cápsula» ya puestos.
- **Notificaciones:** nueva campaña, respuesta de soporte, cambio de estado, ticket asignado, solicitud de información, ticket resuelto, nueva cápsula, nueva documentación y contenido recomendado. Muestran un punto de no leído y se puede «Marcar todo como leído».

## Modelo de datos sugerido (confírmalo en el plan)

- **Tickets:**
  - `sop_ticket`: id, código SUP-000000, título, descripción, categoría, prioridad, estado, usuario, cliente, planta, perfil, módulo, pantalla, registro, URL, navegador, responsable, área, fecha de creación, fecha de actualización, SLA objetivo, recurrente_id.
  - `sop_ticket_evento`: ticket, tipo, autor, fecha, texto, estado_desde, estado_hasta, asignado_a, archivo, contenido_id, es_interno.
  - `sop_ticket_archivo` y `sop_encuesta` (ticket, respuesta, estrellas, comentario, usuario, fecha, responsable).
  - `sop_recurrente`.
- **Conocimiento:**
  - `ayu_contenido`: tipo (cápsula, video, manual, documento, guía, FAQ), título, descripción, objetivo, duración, páginas, estado, autor y audiencia.
  - `ayu_contenido_version`, `ayu_contenido_paso` (orden, texto, segundo), `ayu_contenido_recomendacion`, `ayu_contenido_vinculo` (pantalla_id) y `ayu_categoria`.
  - `ayu_pantalla`: módulo, submódulo, pantalla, sección y ruta.
  - Métricas: `ayu_vista` (usuario, contenido, fecha, segundos vistos, descargó) y `ayu_valoracion`. La búsqueda sin resultados va en `ayu_busqueda`.
- **Campañas:** `cam_campana` (tipo, título, descripción, medio, CTA, contenido promocionado, formatos, cierre, confirmación, inicio, término, frecuencia, estado), `cam_condicion` (campo, operador, valor, unión), `cam_segmento` y `cam_entrega` (usuario, campaña, vista, interacción, fecha).

## Criterios de aceptación

- Las pantallas se ven y se comportan como en `sigma-soporte-referencia.html`, en escritorio, tablet y móvil.
- Un usuario de planta puede:
  - reportar desde cualquier pantalla sin escribir el contexto;
  - ver la sugerencia de ayuda;
  - seguir su reporte en «Mis problemas»;
  - responder lo que soporte le pidió;
  - contestar la encuesta y reabrir.
- Soporte ve toda la trazabilidad, con notas internas que el usuario nunca ve.
- Cada pantalla vacía muestra una frase útil y su acción para empezar.
- Las campañas llegan solo a la audiencia calculada y se miden.
