# Rediseño de Mantenimiento · estado para continuar en otra sesión

Última actualización: 09-10-2026 · rama `BryanChavez` (commit 494c26e + lo que se agregue después; `master` avanza por fast-forward).
Punto de entrada general del proyecto: `MD/SIGMA_ESTADO_DESARROLLO.md`. Este archivo solo cubre el menú **Mantenimiento**.

## Regla de oro

**Todo el módulo debe quedar tal cual el mockup.**
Referencia visual y de comportamiento: `docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html` (ábrela en el navegador; todo es navegable y con datos de ejemplo). Prompt y plan: `MD/PROMPT_CLAUDE_MODERNIZACION_MANTENIMIENTO.md` (+ Anexo v3 de Catalina) y `MD/PLAN_MODERNIZACION_MANTENIMIENTO.md`.

Reglas que el usuario repite (no olvidarlas):
- Cabecera del Centro de Planificación (`cp-hero`), combos de SIGMA (`SigmaCombo`) y calendario de SIGMA (`SigmaCalendario`, también en modo mes y año con `data-sgcal-modo="mes"`). Nunca `type=date/time`.
- «Ronda» se llama **«Inspección»** en toda la interfaz.
- Perfiles dinámicos por cliente: nunca escribir «supervisor / técnico / jefe de turno» en UI, mensajes ni comentarios (decir «quien tiene la facultad de cerrar OT», «quien ejecuta»).
- Combos de **Área**: desglosados (Planta › área padre › área). Combos de **Responsable**: foto, nombre, perfil y especialidad (componente SIGMA).
- Una OT puede tener **más de un responsable**.
- La ficha de OT contiene todo (no redirigir al menú legacy).
- Tarjetas con aire y sin espacios muertos (masonry `.cp-mas` o columnas flex con `gap:14px`).
- Todo objeto mantenible puede ser **activo, subactivo o componente**.

## Menú (5 lugares)

Planificación · Operación · Órdenes de trabajo · Avisos (contador rojo) · Recursos (ex Biblioteca; el mockup lo llama «Biblioteca»). Datos de menú: `BD/394`–`399` (aplicar DESPUÉS de `BD/385`, que renombra el menú 2222).

## Qué está hecho (en dev, verificado en navegador)

| Lugar | Estado |
|---|---|
| Avisos | Completo (descartar/deshacer, generar OT, vincular, reportar falla). `BD/397`, `WsAvisos`, `Js/sigma-mant-avisos.js`. |
| Órdenes de trabajo | Lista + ficha completa de 4 pestañas como el mockup: Resumen (2 columnas: Qué hay que hacer + Asignación · Avisos vinculados + Bitácora) · Pasos (tareas, mano de obra, servicios, indisponibilidad, evidencias) · Repuestos · Cierre (firmas dibujadas, hallazgo en OT). `BD/398`, `BD/404` (varios responsables), `WsOrdenes`, `Js/sigma-mant-ordenes.js`. |
| Operación | **Hoy** (agenda con «Ahora» primero y de lo más reciente a lo más antiguo, estado por área, atención, IA, tendencia), **Sala de control** (ex Monitoreo, `Js/sigma-mant-sala.js`, `BD/403`), **Ejecuciones** (lista/semana/mes, generar OT masivo), **Cumplimiento** (mes con calendario SIGMA, `BD/402`). Filtros persistentes: planta, área desglosada, responsable con foto, criticidad. `BD/400`, `401`, `WsOperacion`. |
| Planificación | Cabecera «Centro de Planificación»; sin franja de KPI ni Período; pestañas **Planes · Inspecciones · Tareas recurrentes · Cobertura**. Las listas de Inspecciones/Tareas existen (`BD/405`, `WsCentroPlanificacion.Inspecciones/Tareas`). Vista Lista/Tarjetas (Monitoreo pasó a Operación › Sala de control). |

## Qué falta (en este orden)

1. **Recursos** (`View/Mantenimiento/Biblioteca/Biblioteca.aspx`) es hoy un **marcador de posición** («llega en la parte e»). Debe tener las 4 pestañas del mockup, con su hint arriba y la tarjeta con buscador/filtros:
   - **Procedimientos** (tabla: Código vN · Nombre + puntos de control/mediciones · Tipo de activo · Pasos · Duración · Dónde se usa · Editar / «Copiar para usar» en los de Sistema) + botón **Nuevo procedimiento**.
   - **Pautas de inspección** + **Nueva pauta**.
   - **Calendarios compartidos** + **Nuevo calendario**.
   - **Ajustes** (categorías de tarea, tipos de OT, motivos de descarte; antes `TareaCategorias.aspx` redirigía a `Biblioteca.aspx#ajustes`).
   El código viejo de Biblioteca vive en `Js/sigma-centro-planificacion.js` (`libHTML`, `procLibHTML`, `calLibHTML`, `abrirProc`, `abrirCal`, `PANELS.proc`, `PANELS.cal` = asistente de 6 pasos).
2. **Los drawers deben ser de una sola página, tal cual el mockup** (hoy los de procedimiento y calendario son asistentes/otros diseños). En el HTML de referencia: `PANELS.proc` (~línea 3597), `PANELS.scal` (calendario, ~3671), `PANELS.pau` (pauta, ~4367), `PANELS.rone` (inspección, ~4338 y 5229 con selector de activos y objeto mantenible), `PANELS.tare` (tarea, ~4351, con `PN.comp`), `freqEd()` (~4328: Semanal / Mensual / Calendario compartido + próximas fechas).
3. **Nueva inspección / Nueva tarea** (botones de la cabecera de Planificación; hoy abren el formulario legacy: `ChecklistProgramacion.aspx` en modal y `Tarea.aspx`). Deben ser drawers del mockup con: nombre, pauta o categoría, planta, **selector de activos con objeto mantenible (activo / subactivo / componente)**, frecuencia, responsable (componente con foto), duración. Backend ya existente que se puede reutilizar:
   - `INS_PROGRAMACION_PRIVADA`, `UPS_PROGRAMACION_CALENDARIO/INTERVALO`, `INS_PROGRAMACION_FECHA`, `INS_PROGRAMACION_EXCLUSION` (los usa `WsCentroPlanificacion.GuardarFrecuencia` y `CrearCalendario`).
   - `INS_CHECKLIST_PROGRAMACION(@CLIENTE,@CHECKLIST_PLANTILLA,@PROGRAMACION,@ACTIVO,@INSTALACION_AREA,@GRUPO_TRABAJO,@USUARIO_RESPONSABLE,@NOMBRE,@USUARIO)`: **un activo por fila** → una inspección con N activos = N filas con la misma `Programacion`; agrupar por programación en `SEL_PLAN_INSPECCIONES` (hoy lista una fila por programación de checklist).
   - `INS_TAREA(@CODIGO,@TITULO,@DESCRIPCION,@TAREA_PRIORIDAD,@CLIENTE_INSTALACION,@INSTALACION_AREA,@ACTIVO,@TAREA_CATEGORIA,@DURACION_ESTIMADA_MINUTO,@REQUIERE_EVIDENCIA)` + `INS_TAREA_PROGRAMACION(@TAREA,@PROGRAMACION,@USUARIO_RESPONSABLE,@GRUPO_TRABAJO)`.
   - Falta decidir/crear: dónde guardar el **subactivo/componente** de una tarea o inspección (hoy `Tarea` y `Checklist_Programacion` solo tienen `activo` y `área`); revisar `Activo_Componente` y cómo lo resuelven los planes (`Plan_Mantenimiento_Activo.pac_activo_componente`).
4. **Parte f**: repuestos dentro de las actividades; **SIGMA AI Chat / SIGMA Twin** habilitados por plan comercial (nuevas filas en `Funcionalidad` y `Plan_Comercial_Funcionalidad`).
5. Operación: botón «Registrar» de inspección, detalle de la tarjeta SIGMA AI, botón Recorridos.
6. Pendientes operativos: aplicar `BD/381`–`405` en **Azure** (producción: `codigocreativo.database.windows.net` / SIGMA, usuario `sigma`; el clasificador bloquea `sqlcmd` contra producción hasta que el usuario dé permiso) y programar el job nocturno en Azure (el usuario lo dejó pendiente).
7. Filtrar por un área padre (ej. «Despacho») todavía no incluye las áreas hijas (los SP comparan `act_instalacion_area = @AREA`).

## Cómo se construyó (para seguir sin perder tiempo)

Front-end de los «lugares» nuevos (Operación, Avisos, Órdenes, Recursos):
- `Js/sigma-mant-comun.js` → `window.MantKit` (íconos, fechas `fD/fDL/deDN/iso…`, `llamar(ws,método,datos)`, `combo`, `fecha`, `avatar`, `toast*`, `Panel` = drawer lateral, `Pop`, `bind`).
- `Js/sigma-mant-lugar.js` → `window.MantLugar` (pestañas `tab(k,{mount,hero})`, acciones `A.*` por `data-a`, `on({pv,combo,fecha,key})`, planta, hash).
- Las páginas `.aspx` se **generan** con `_scratch/gen_lugares.py` (config JSON: lugar, título, ws, pestañas, scripts `extra=`). **Editar `extra=` solo con la herramienta Edit**, nunca con reemplazos en heredoc (los `\n` rompen el script).
- CSS: `Css/LookAndFeel/sigma-mant-ot.css` se **genera** desde el mockup (`_scratch/gen_css_mock.py`, lista TARGET de clases; regenerar lo sobreescribe) y `sigma-mant-lugares.css` es a mano (fuente `_scratch/tmp_lugares.css`, instalar con `instalar.py`). La base es `sigma-centro-planificacion.css`.
- Servicios `.asmx` + `App_Code/WebService/Ws*.cs`: patrón `Ejecutar` / `Exigir` / `Token.Puede`, `SoporteDatos.Filas/Conjuntos`, tokens de registro con `Tools.Crypto.Encrypt("Id="+id)`.

Planificación y (por ahora) Recursos usan el script grande `Js/sigma-centro-planificacion.js` (estado `U`, panel `PN`/`PANELS.*`, acciones `A.*`, pestañas registradas en `TABR.*`, helpers `combo`, `fecha`, `ppTxt`, `mc`, `abrirModalSitio`).

## Trampas conocidas (ya costaron tiempo)

- Aplicar SQL con `-I` (QUOTED_IDENTIFIER ON): los SP con `FOR XML` fallan en ejecución sin él. `_scratch/aplicar_sql_prod.py` ya lo trae y aplica a **dev (MonsterASP, `db71936.public.databaseasp.net`)**. `BD/385` renombra el menú 2222: reaplicar 394–399 después.
- Un SP que hace `INSERT … EXEC` de otro **no puede usar una tabla temporal con el mismo nombre** (`#E` chocaba): usar nombres distintos (`#EJ`).
- Fechas: mandar siempre cadenas ISO al servidor (un `DateTime` tipado sale como número); en `K.fecha` pasar `K.deDN(valor)`.
- `Token.PuedeFuncion` no sirve dentro del servicio web: la facultad de cerrar OT se consulta con `SEL_OT_PUEDE_CERRAR`.
- Popover: el kit escribe `POP.r`; no guardar datos en `r`.
- El `TokenValidationHandler` valida el header antes de enrutar: nada anónimo debe llevar `Authorization`.
- Archivos en UTF-8 con BOM y CRLF (`_scratch/instalar.py`); todo `<button>` con `type="button"`.
- Compilar siempre: `/c/Windows/Microsoft.NET/Framework64/v4.0.30319/aspnet_compiler.exe -v /Check -p Web/Intranet -f -d /c/temp/cc_out`.
- La ficha de OT tarda unos segundos en cargar en dev (el catálogo); en las pruebas esperar ~8 s antes de capturar.

## Herramientas de verificación (carpeta `C:\Capstone\_scratch`, fuera del repo)

- `ver_cp.py "<ancho,alto>" "wait:4 ;; click:SEL ;; js:… ;; shot:nombre"` con `CPURL=<ruta>#hash` (Selenium headless; inicia sesión y cambia al cliente Hamburgo; guarda `cpv_<nombre>.png`).
- `ver_mock.py <hash> <ancho,alto> <nombre> "<js>"` → `mock_<nombre>.png` del mockup (para comparar lado a lado).
- `q_dev.py` (stdin → `sqlcmd` contra dev), `aplicar_sql_prod.py <archivo.sql>`, `instalar.py <origen> <destino>` (BOM+CRLF).
- Datos de prueba en dev: cliente Hamburgo; hay 2 tareas de ejemplo (`TAR-001`, `TAR-002`) sembradas el 09-10-2026; no hay inspecciones.

## Archivos clave

`BD/394`–`405` · `App_Code/WebService/WsAvisos.cs, WsOrdenes.cs, WsOperacion.cs, WsCentroPlanificacion.cs` · `Js/sigma-mant-{comun,lugar,avisos,ordenes,operacion,ejecuciones,cumplimiento,sala}.js` · `Js/sigma-centro-planificacion.js` · `View/Mantenimiento/{Operacion,Avisos,Ordenes,Biblioteca}/*.aspx` · `View/Mantenimiento/Planificacion.aspx`.
