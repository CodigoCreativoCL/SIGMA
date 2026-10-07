# Prompt para Claude Code — SIGMA AI · Centro de monitoreo

Crea la vista principal de SIGMA AI como un **centro de monitoreo** según la referencia `docs/rediseno-sigma-ai/sigma-ai-centro-referencia.html`. Ábrela en el navegador y pruébala completa antes de tocar código: la planta 3D, la cola de predicciones, el copiloto, confirmar una foto y pedir un repuesto.

Hoy `View/SigmaAI/` solo tiene `Experimentos.aspx`, el laboratorio de Azure ML. Esta vista nueva es lo que ve el equipo de mantenimiento todos los días. El laboratorio se mantiene y se enlaza desde aquí.

## Lo que NO se toca

- Sidebar y topbar: `Master/Default.master`, `sigma-layout.css`, `MenusLateral` y la topbar. En el sidebar, el ítem SIGMA AI queda activo en esta vista.
- `Experimentos.aspx` y su lógica (datasets, corridas, versiones, publicar, verificar en Azure).
- Los servicios existentes: `/sigma-ai/predecir`, `/sigma-ai/vision/clasificar`, `/sigma-ai/entrenamientos`, `/sigma-ai/azure/modelos` y lo que alimenta `AlertaController` (`ES_PREDICCION`). Se reutilizan; no se duplican.
- Vocabulario: siempre «activo», nunca «equipo». Esto incluye los textos que hoy dicen «un equipo × una fecha de corte».

## Cómo quiero que trabajes

1. Lee `CLAUDE.md`, `Css/LookAndFeel/sigma-brand.css` (tokens `--sg-*`, Sora) y el widget SIGMA AI del inicio (`Js/sigma-inicio.js`, si ya existe). Esta vista usa el mismo lenguaje que el widget, en grande:
   - fondo `#060A14` con halos y grilla que se desvanece;
   - degradado de marca teal → azul → violeta → rosa solo como acento;
   - severidad: crítica `#FF5C8A`, alta `#FFB547`, media `#00E0C2`, saludable `#6F7CC8`.
2. Revisa:
   - `Experimentos.aspx` y `Experimentos.aspx.cs`: modelos `FALLA` (SIGMA FAILURE 30D), `RUL` (SIGMA RUL) y `VISION` (SIGMA VISION), sus tablas y SP (`mpv_parametro`, `Analisis_Visual_Revision`, `Analisis_Visual_Deteccion`, `avd_confirmado_humano`, `API_SEL_ML_DATASET_VISION`);
   - `Services.GetJson` y la API `/sigma-ai/*`;
   - `Js/three/three.module.min.js` (r160) y `Js/gsap/gsap.min.js` (3.12.5), y cómo los cargan `sigma-planta.js` / `sigma-bodega3d.js`.
3. **Presenta un plan y espera mi OK.** El plan debe tener una tabla con cada bloque de la vista, el endpoint o SP que lo alimenta, si existe o hay que crearlo, y su estado vacío.
4. Crea:
   - `View/SigmaAI/Centro.aspx` (+ `.cs`);
   - `Css/LookAndFeel/sigma-ai-centro.css`;
   - `Js/sigma-ai-centro.js`;
   - `Js/sigma-ai-planta3d.js` (módulo ES).
   - Agrega el ítem al menú con su permiso. `SIGMA AI` en el sidebar abre esta vista.
5. **No inventes cifras.** Todo número sale de la API o de un SP. Si un modelo no tiene versión publicada, su bloque muestra el estado «Aprendiendo / sin versión publicada» y un enlace al laboratorio.
6. Verifica en 1920, 1440, 1280 y 390 px, sin scroll horizontal, con el sidebar colapsado y con `prefers-reduced-motion`.

## Estructura de la vista

La vista es oscura de punta a punta; la topbar sigue blanca como en el resto de SIGMA.

- **Contenido**: columna principal + **copiloto** fijo a la derecha (380 px).
- **< 1280 px**: el copiloto pasa a panel deslizable con el botón flotante «Copiloto».

### Encabezado

- Miga «SIGMA AI / Centro de monitoreo».
- Símbolo de SIGMA AI con anillo cónico que gira, y el título «Centro de monitoreo **SIGMA AI**» con la marca en degradado.
- Una línea que explica qué hace la vista.
- **A la derecha**:
  - pastilla «EN VIVO»;
  - «Última puntuación hace N min · próxima en N min · 3 modelos publicados»;
  - **«Puntuar ahora»** (secundario cyan oscuro): llama `POST /sigma-ai/predecir`, gira mientras trabaja y escribe el resultado en la bitácora;
  - «Laboratorio» (enlace a `Experimentos.aspx`).
- **Navegación de secciones sticky** bajo la topbar: Monitoreo · Predicciones (contador de críticas) · Vida útil · Visión (contador de fotos por confirmar) · Modelos.
  - Cada una baja a su sección.
  - La sección visible se marca al hacer scroll.

### 1. Monitoreo

**Planta en vivo (3D, 8 de 12 columnas, unos 540 px de alto):**

- **Escena** con Three.js:
  - piso con grilla;
  - cada **área** de la planta como plataforma con borde violeta y su etiqueta HTML proyectada («PANADERÍA · 14 activos · 2 en riesgo»);
  - cada **activo** como un pilar: el alto depende de la probabilidad de falla y el color de su severidad; los saludables son bajos y tenues;
  - los activos en riesgo tienen brillo, **ondas que se expanden en el piso** y un **arco de datos** hacia el **núcleo de SIGMA AI**, que flota sobre la planta (icosaedro con shader fresnel en el degradado de marca, malla, halo y anillo) con «paquetes» viajando por el arco.
- **Interacción**:
  - arrastrar para girar (sin capturar la rueda del mouse);
  - giro lento automático cuando nadie interactúa;
  - hover: tooltip con nombre, área, código, componente y «71 % · falla en 3–4 días» o «Saludable · salud 94/100»;
  - clic en un activo con predicción: lo selecciona (anillo blanco que late en su base, la cámara se acerca con GSAP) y baja al detalle.
- **Controles**:
  - chips «Todos / Solo en riesgo» (los saludables se atenúan);
  - leyenda de severidad;
  - «Centrar vista»;
  - «Abrir en SIGMA Twin».
- **Datos**: áreas y posiciones desde la jerarquía de ubicaciones del cliente (es multicliente: las áreas no van fijas en el código) y la última puntuación de SIGMA FAILURE 30D por activo.
- **Rendimiento y accesibilidad**:
  - `setPixelRatio(min(dpr, 1,75))`;
  - pausa fuera de pantalla y con `document.hidden`;
  - `dispose()` al salir;
  - **respaldo sin WebGL**: grilla de áreas con un cuadro de color por activo, clicable.

**Columna de estado (4 de 12):**

- **Salud de la planta**: anillo 0–100 con conteo animado, variación contra ayer, una frase («2 activos explican el 70 % del riesgo») y una sparkline de 30 días.
- **Los N activos**: barra apilada por severidad (Crítica, Alta, Media, Saludables) con su leyenda y conteos.
- **Señales en vivo**:
  - señales por minuto con un histograma de los últimos 40 s que se desplaza;
  - sensores en línea («186/190»);
  - latencia.

**Bitácora en vivo (12 de 12):**

- Registro monoespaciado de todo lo que SIGMA AI hace y detecta: hora (24 h), etiqueta del origen (FAILURE 30D, RUL, VISION, SENSOR, OT) y mensaje con lo importante en negrita.
- Las entradas nuevas entran arriba con un destello teal.
- Si el evento es de un activo, lleva «Ver →», que lo selecciona.
- Propón en el plan de dónde salen los eventos (tabla de eventos de SIGMA AI, lecturas fuera de rango, puntuaciones, OT creadas desde una predicción).

### 2. Predicciones (SIGMA FAILURE 30D)

**Cola priorizada (7 de 12):**

- Filtros: Todas, Críticas, Altas, Sin OT.
- Filas: activo y componente, probabilidad (número + barra de color), horizonte, sparkline de la probabilidad en 14 días y estado («Nueva», «En revisión», «OT creada · 4587», «Descartada»).
- Clic en una fila: la selecciona, actualiza el detalle y la acerca en el 3D.

**Detalle (5 de 12, sticky):**

- Severidad y %, componente, activo, área y código; etiqueta «FAILURE 30D · v7».
- Anillo con la probabilidad y «Falla probable en 3–4 días · antes del 10 de octubre · confianza 86 %».
- **«Por qué lo dice SIGMA AI»**:
  - barras divergentes desde el centro con el aporte de cada característica a la fila de hoy;
  - rosado sube el riesgo y teal lo baja, con el valor (+0,34 / −0,06);
  - salen de las razones y pesos que ya guarda `/sigma-ai/predecir` (`mpv_parametro` × características estandarizadas).
- **«La señal que lo explica»**:
  - una sola serie: 30 días medidos, punto «hoy», proyección de 21 días con banda y línea de alarma;
  - cruz con tooltip.
- **«Qué hacer»**: la recomendación (acción, cuándo, duración, repuesto y stock).
- **Acciones**:
  - «Crear OT preventiva» (primario): crea la OT con el activo y la predicción enlazados y pasa el estado a «OT creada»;
  - «Asignar»;
  - «Preguntar» (al copiloto);
  - «Descartar»: pide el motivo («Ya se intervino», «Falsa alarma», «El sensor tiene una falla», «Otro»), lo guarda como retroalimentación para el próximo dataset y permite reabrir.

### 3. Vida útil (SIGMA RUL)

- Gráfico de intervalos: por cada repuesto instalado, la mediana de días restantes (punto) y su intervalo del 80 % (barra), en un eje de 0 a 180 días, con la línea de aviso en 30 días (ámbar, punteada).
- Color: < 30 rosa, < 60 ámbar, el resto teal.
- Columnas: días (mediana y rango) y **stock en bodega** (stock y mínimo).
- Si no alcanza: **«Pedir reposición»**, que crea la solicitud de compra; queda «✓ Pedido».
- Ordenado de menos a más días. Sale de las predicciones vigentes del modelo `RUL` cruzadas con el inventario.

### 4. Visión (SIGMA VISION)

- Aviso con las fotos que esperan confirmación: «Cada confirmación mejora SIGMA VISION v3».
- **Tarjetas de fotos**:
  - imagen real con el **recuadro de la detección** y su etiqueta y probabilidad;
  - estado («Por confirmar» / «✓ Confirmada»);
  - activo, quién la subió y cuándo;
  - las 3 etiquetas con su barra.
- **Acciones**:
  - «Confirmar {etiqueta}» (primario): marca `avd_confirmado_humano = 1` con el usuario;
  - «Corregir»: elige otra etiqueta y la guarda como corrección.
  - Ambas escriben en la bitácora. La confirmación es siempre de una persona; la vista nunca confirma sola.

### 5. Modelos

- **Una tarjeta por modelo publicado** (FAILURE 30D, RUL, VISION):
  - versión, pastilla «Publicada», qué responde y algoritmo;
  - **métricas** de la versión vigente: AUC, precisión, recall y F1 para falla; error medio en días, cobertura del intervalo del 80 %, repuestos y umbral para RUL; precisión por etiqueta para visión;
  - **sparkline de la métrica principal por versión**, indicando cuándo más bajo es mejor;
  - **chequeos**: hash del `.onnx` verificado en Azure ML, tamaño del dataset y fecha de entrenamiento, y deriva de datos si existe (en ámbar).
- **«Cómo le fue a SIGMA AI este mes»**: fallas anticipadas, falsas alarmas, fallas no anticipadas y horas de detención evitadas. Sale de cruzar las predicciones con las OT correctivas reales.
- **«Abrir el laboratorio»** lleva a `Experimentos.aspx`.

### Copiloto SIGMA AI (panel derecho)

- **Encabezado**: símbolo, «Copiloto SIGMA AI», «Conectado a N modelos» y cerrar. Al cerrar aparece el botón flotante «Copiloto»; la preferencia se recuerda.
- **Contexto**: «Mirando: {activo} · {componente}». Cambia con la selección.
- **Conversación**:
  - al entrar, un saludo con el resumen del día y botones de acción;
  - burbujas propias en morado;
  - las respuestas muestran puntos de «pensando», se escriben letra a letra y terminan con **fuentes** (modelo · versión · hora de puntuación) y **acciones** (Crear OT, Pedir la correa, Ir a las fotos, Ver los modelos).
- **Sugerencias** que cambian con el activo seleccionado: «¿Por qué {activo}?», «¿Qué reviso primero hoy?», «Repuestos en riesgo», «Fotos por confirmar».
- **Campo de pregunta** con borde en degradado que gira.
- **Backend**: un endpoint de conversación (por ejemplo `POST /sigma-ai/copiloto`) que responda solo con datos de SIGMA (predicciones, RUL, visión, OT, inventario) y devuelva siempre sus fuentes. Si no sabe algo, lo dice.

### Tiempo real

- **Polling**:
  - cada 15–30 s para eventos y puntuaciones nuevas (solo lo nuevo desde la última marca de tiempo);
  - cada 1 s solo para el contador de señales si hay una fuente de lecturas en vivo; si no la hay, ese bloque muestra la última lectura con su hora.
- Todo se pausa con `document.hidden`.
- Animaciones con GSAP:
  - entrada del encabezado y las tarjetas;
  - anillos que se llenan;
  - intervalos que crecen;
  - cámara del 3D.
- Con `prefers-reduced-motion`: sin animaciones, sin giro automático y texto del copiloto sin efecto de escritura.

## Criterios de aceptación

- Cada número de la vista sale de la API o de un SP; nada está escrito a mano.
- Una predicción se explica (por qué), se ve en la planta y se convierte en OT en 2 clics.
- Descartar pide un motivo y ese motivo queda disponible para el próximo entrenamiento.
- Una foto solo cuenta como confirmada cuando una persona la confirma.
- Sin WebGL, la vista es igual de útil gracias a la grilla de respaldo, la cola, el detalle y la bitácora.
- La escena 3D mantiene 60 fps en un equipo de oficina y deja de dibujar cuando no se ve.
- Foco visible, Esc cierra lo abierto, `aria-live` en la bitácora y descripción accesible en los gráficos.
- Sin scroll horizontal a 390 px.
