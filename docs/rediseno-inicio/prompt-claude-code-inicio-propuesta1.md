# Prompt para Claude Code — Inicio de SIGMA · Propuesta 1 (Default.aspx)

Implementa la **Propuesta 1** del inicio de SIGMA según la referencia `docs/rediseno-inicio/sigma-inicio-referencia.html`.

Ábrela en el navegador. En el control de abajo a la derecha elige **«Propuesta 1»** y **«Actual»** en el selector de sidebar. Pruébala en los dos escenarios: «Con datos» y «Sin órdenes aún».

Este trabajo es **solo el contenido de `Default.aspx`**. La Propuesta 2 y el sidebar nuevo quedan fuera; tienen su propia sección en `prompt-claude-code-inicio-sigma.md`.

## Lo que NO se toca

- **Topbar y sidebar quedan exactamente como están**: `Master/Default.master`, `sigma-layout.css`, `MenusLateral`, el selector de cliente, «Reportar problema», «Ayuda», la campana y el perfil.
- **El encabezado se mantiene**:
  - el eyebrow con la fecha (`cphEyebrow` / `litFecha`);
  - «¡Hola, {nombre}! 👋» (`cphTitulo`);
  - el subtítulo (`cphSubtitulo`).
  - Solo se agregan acciones a la derecha.
- La lógica de `Default.aspx.cs` que ya existe (`CargarEncabezado`) no cambia.
- Vocabulario: siempre «activo», nunca «equipo».

## Cómo quiero que trabajes

1. Lee `CLAUDE.md`, `Css/LookAndFeel/sigma-brand.css` (tokens `--sg-*`, tipografía Sora) y `sigma-layout.css`.
2. Respeta el estándar UI:
   - paleta #6732F4, #087BEA, #16C6C9 y #007F8A;
   - botones por función: primario morado, secundario cyan oscuro, outline azul, ghost, y rojo solo para acciones destructivas;
   - tarjetas blancas sin borde con sombra suave;
   - headers sin degradados.
3. Revisa antes de proponer:
   - `Default.aspx` y `Default.aspx.cs`;
   - `Imagen/sigma-ai/` (`sigma-ai-symbol-gradient.svg`, `sigma-ai-wordmark-dark.svg`) e `Imagen/sigma-twin/sigma-twin-symbol-gradient.svg`;
   - `View/SigmaAI/`, `AlertaController` (`GetResumen`, `GetAlertas`, `ES_PREDICCION`) y `WsAlertas`;
   - lo que exista de órdenes de trabajo, planificación y turnos (tablas y SP).
4. **Presenta un plan corto y espera mi OK.** Debe incluir una tabla con cada bloque, de dónde sale su dato, qué SP o servicio falta crear y qué muestra mientras no haya datos.
5. Crea:
   - `Css/LookAndFeel/sigma-inicio.css`;
   - `Js/sigma-inicio.js`;
   - los íconos de accesos en `Imagen/accesos/*.svg`.
   - Cárgalos desde `cphHeder` / `chpScript` de `Default.aspx`. Los estilos no van inline.
6. **No inventes cifras.** Hoy no hay órdenes de trabajo registradas. Cada bloque que dependa de OT muestra su estado vacío hasta que el SP devuelva filas, igual que el escenario «Sin órdenes aún» de la referencia.
7. Trabaja por pasos y verifica cada uno en 1920, 1280 y 390 px, sin scroll horizontal y también con el sidebar colapsado (`body.enlarged`).

## Diseño de la página

Contenedor de 1480 px máximo, centrado. De arriba hacia abajo:

1. Encabezado con sus acciones.
2. Accesos directos.
3. Una grilla de dos columnas, `minmax(0, 1fr) 380px`, con 22 px de separación:
   - **columna principal**: widget SIGMA AI, indicadores y órdenes de trabajo recientes;
   - **columna derecha**: «Hoy en tu turno» y «Requieren tu atención».

### 1. Acciones del encabezado (a la derecha del título)

- Chip de turno: punto verde y «Turno A · 07:00 – 15:00». Si no hay turnos configurados, el chip no se muestra.
- «Solicitud de trabajo» (outline).
- «+ Nueva orden de trabajo» (primario).

### 2. Accesos directos

- Grilla `repeat(auto-fill, minmax(164px, 1fr))` con 14 px de separación.
- **Cada tarjeta**: ícono de marca en un cuadro de 52 px, nombre y una línea de estado en vivo («24 abiertas · 5 vencidas», «63 fuera de umbral»). El punto de color aparece solo cuando hay algo que atender.
- **Íconos**:
  - SIGMA Twin y SIGMA AI con fondo navy y su símbolo de degradado oficial;
  - el resto en el mismo lenguaje (trazo con el degradado teal → azul → violeta → rosa y nodos blancos con borde de color) sobre un fondo lila suave.
- **Al pasar el mouse**: la tarjeta sube 3 px y aparece una flecha.
- **«Personalizar»**:
  - entra en modo edición: las tarjetas tiemblan, cada una muestra una ✕ y aparece «+ Agregar acceso» con los módulos que faltan;
  - la selección se guarda por usuario (propón la tabla en el plan);
  - solo se ofrecen módulos a los que el perfil tiene permiso;
  - Esc sale del modo edición.
- **Por defecto**: SIGMA Twin, SIGMA AI, Órdenes de trabajo, Planificación, Control de activos, Centro de repuestos, Permisos de trabajo y Soporte.
- **También disponibles**: Alertas, Medidores, Terceros y Reportes.

### 3. Widget SIGMA AI (oscuro y futurista)

Es la única superficie oscura del contenido.

- **Fondo**: `#070B16` con halos radiales teal, violeta y rosa, una grilla de 32 px que se desvanece y una línea de escaneo lenta. Anillo violeta translúcido como borde y radio de 26 px.
- **Encabezado**:
  - símbolo de SIGMA AI dentro de un cuadro con un anillo cónico que gira;
  - wordmark oscuro con «Mantenimiento predictivo · {cliente}»;
  - a la derecha, «Analizando N activos · N señales/min» y la pastilla «EN VIVO» con un punto teal que late.
- **Predicción principal** (columna izquierda, unos 57 % del ancho):
  - «PREDICCIÓN PRINCIPAL» y la confianza del modelo en una pastilla;
  - componente como título y «activo · área · código · tipo de falla» debajo;
  - anillo de 118 px con la probabilidad de falla, con el trazo en el degradado de marca y animado al cargar;
  - «Falla probable en 12–16 días» con el plazo en texto degradado y la fecha límite;
  - 3 razones, cada una con su dato en negrita.
- **Gráfico de la señal que explica la predicción**:
  - una sola serie y un solo eje;
  - 30 días medidos (línea violeta de 2 px con área);
  - el punto «hoy» en vivo con brillo;
  - proyección de 21 días (línea rosa punteada con banda de incertidumbre);
  - línea de alarma ámbar rotulada;
  - etiquetas «hace 30 d · hace 15 d · hoy · +7 d · +14 d · +21 d»;
  - cruz con tooltip al pasar el mouse: fecha y valor, y en la proyección también el rango.
  - Arriba del gráfico, el valor actual en grande con su unidad y una leyenda: Medición, Proyección y Alarma.
- **Acciones**:
  - «Crear OT preventiva» (primario): abre la OT con el activo y la predicción ya cargados;
  - «Ver análisis»;
  - «Descartar»: registra el descarte para que el modelo aprenda y pasa a la siguiente predicción.
- **Flujo de predicciones** (columna derecha):
  - hasta 5 tarjetas con «activo · componente», falla, horizonte, «hace N min», % y una barra de color (≥ 70 % rosa, 50–69 % ámbar, < 50 % teal);
  - las nuevas entran arriba con un destello teal;
  - al hacer clic en una tarjeta, esa pasa a ser la predicción principal y la anterior vuelve a la lista;
  - abajo, 3 cifras: fallas anticipadas en el mes, horas de detención evitadas y % de aciertos del modelo.
- **Preguntar a SIGMA AI**:
  - campo «Pregúntale a SIGMA AI: ¿qué activos reviso esta semana?» con botón de envío (primario);
  - 3 sugerencias: «¿Qué reviso primero hoy?», «Resumen del turno» y «Repuestos en riesgo»;
  - la respuesta aparece dentro del widget con efecto de escritura y enlaza a la conversación completa en `View/SigmaAI/`.
- **Tiempo real**:
  - polling cada 15–30 s a un servicio (por ejemplo `WsSigmaAI.asmx/Predicciones`) que devuelva solo lo nuevo desde la última marca de tiempo;
  - el punto «hoy» y el contador de señales se actualizan entre polls;
  - se pausa con `document.hidden`;
  - con `prefers-reduced-motion`: sin escaneo, sin giro y sin animaciones.
- **Estado «Aprendiendo»** (sin historial suficiente):
  - anillo teal «12 de 30 días de lecturas»;
  - «SIGMA AI está aprendiendo cómo funciona tu planta» con su explicación;
  - pastillas con activos conectados, señales por minuto y «Primeras predicciones en ~N días»;
  - la caja de preguntas sigue disponible.

### 4. Indicadores (4 tarjetas en fila)

| Tarjeta | Contenido |
|---|---|
| OT abiertas | Número grande; «N vencidas» en rojo y «N de alta prioridad»; sparkline de 8 semanas. |
| Cumplimiento del preventivo | Porcentaje; barra con la meta marcada («Meta 90 % · semana N»). |
| Disponibilidad | Porcentaje; variación contra el mes anterior («▲ 0,8 pts»); sparkline. |
| MTTR | Horas; variación contra el mes anterior («▼ 0,4 h», en verde porque bajar es bueno); sparkline. |

- Sparklines en azul `#2563EB`, de 2 px, con un área suave.
- Íconos de línea en gris claro arriba a la derecha.

### 5. Órdenes de trabajo recientes

- Encabezado: «Órdenes de trabajo recientes · 5 de N abiertas» y «Ver todas».
- Columnas: OT (monoespaciada), trabajo (título y «activo · tipo»), responsable (iniciales en círculo y nombre), prioridad (texto de color: Crítica rojo, Alta ámbar, Media gris), estado en pastilla y chevron.
- Estados: Vencida (rojo), En curso (azul), Programada (gris) y Finalizada (verde).

### 6. Columna derecha

- **«Hoy en tu turno»**:
  - línea de tiempo con hora, tarea, responsable o contexto y estado;
  - hecha: punto verde y texto tachado; en curso: punto morado con halo; pendiente: punto vacío;
  - sin tareas: «No hay tareas programadas para hoy» y el botón «Planificar la semana» (ghost).
- **«Requieren tu atención»**:
  - las 4 notificaciones más importantes del centro de notificaciones, con la misma agrupación por tipo + lugar (por ejemplo «6 repuestos bajo el mínimo · Bodega Piso 2»);
  - ícono en cuadro de color suave y etiqueta de severidad (Crítica / Alta);
  - al final, «Ver todas las notificaciones».

### 7. Estado vacío del panel

Reemplaza los indicadores y las órdenes recientes cuando todavía no hay OT.

- Título: «Tus indicadores aparecen con la primera orden de trabajo», con una explicación corta.
- 3 pasos: activos registrados ✓, plan preventivo y primera OT.
- Botones «Crear la primera OT» (primario) y «Armar el plan preventivo» (outline).
- Los accesos directos que dependen de OT muestran «Sin órdenes aún».

## Responsive

- **< 1280 px**: la columna derecha baja debajo, en 2 columnas, y los indicadores quedan en 2 × 2.
- **< 1100 px**: el widget apila la predicción y el flujo, y la tabla de OT oculta responsable y prioridad.
- **< 900 px**: accesos directos en 2 columnas y las razones de la predicción debajo del anillo. Sidebar y topbar se comportan como hoy.
- **< 560 px**: indicadores en 2 columnas compactas, la tabla de OT muestra solo trabajo y estado, y el gráfico oculta las etiquetas intermedias.

## Orden sugerido de implementación

1. Estructura, CSS y accesos directos (con su preferencia por usuario).
2. Indicadores, órdenes recientes y columna derecha con sus estados vacíos.
3. Widget SIGMA AI con datos reales, primero en estado «Aprendiendo».
4. Gráfico, flujo de predicciones y tiempo real.
5. Preguntar a SIGMA AI, conectado a `View/SigmaAI/`.

## Criterios de aceptación

- Sidebar y topbar se ven idénticos a hoy.
- Ningún número está escrito a mano: cada uno sale de un SP o servicio, o se muestra su estado vacío.
- El widget de SIGMA AI se actualiza solo, sin recargar la página, y deja de consultar cuando la pestaña está oculta.
- Una predicción se convierte en OT en 2 clics.
- Los accesos directos se pueden personalizar y la elección persiste entre sesiones.
- Foco visible en todo, el gráfico tiene una descripción accesible y Esc cierra lo que esté abierto.
- Sin scroll horizontal a 390 px.
