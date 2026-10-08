# Prompt para Claude Code — Centro de Planificación

Construye el **Centro de Planificación** de SIGMA. Úsalo como reemplazo de Planificación 360, de la creación de planes en otra pestaña y de los menús Programaciones y Procedimientos.

Trabajas con dos fuentes, y cada una manda en lo suyo:

| Fuente | Qué define | Si hay conflicto |
|---|---|---|
| `MD/CENTRO_PLANIFICACION_ALCANCE.md` | Qué hace el Centro: reglas (RE-*, RP-*), estados, SP, permisos y criterios CA-01 a CA-29. | **Manda siempre.** |
| `docs/rediseno-planificacion/sigma-centro-planificacion-referencia.html` | Cómo se ve y cómo se usa: layout, componentes, textos, estados vacíos, validaciones y flujo sin modales. | Manda en lo visual y en la interacción. |

Antes de tocar código, abre la referencia en el navegador y recorre el flujo completo:

1. **Nuevo plan** → escribe solo el nombre.
2. **Agregar activos** (panel lateral).
3. **Agregar intervención** → Calendario mensual → mira la vista previa de fechas.
4. **Agregar desde procedimiento** → elige un responsable.
5. **Activar plan**.
6. Edita un plan activo → **Aplicar cambios**.
7. Desactiva y reactiva un plan.
8. En **Ejecuciones**, genera OT en lote y reprograma una ejecución.
9. En **Cobertura**, crea un plan con activos sin plan.

La vista **Componentes** de la barra del prototipo muestra todos los estados de cada componente.

## Lo que NO se toca

- **Sidebar y topbar:** `Master/Default.master`, `sigma-layout.css`, `MenusLateral` y la topbar. El Centro se monta en la cáscara de Planificación 360 (cabecera con planta y período, KPI, pestañas por AJAX, estado en la URL).
- **Tareas recurrentes, Pautas de inspección, Hallazgos y Fallas.** El Centro solo los **referencia**:
  - «dónde se usa» de un calendario compartido;
  - los atajos de orientación del estado vacío.
- **Ejecución de la OT.** El Centro termina en la OT generada (§17.2). Asignar en detalle, ejecutar, registrar y cerrar siguen en el centro de la OT.
- **Fuera de alcance; no lo construyas aunque el código lo permita:**
  - Omitir ejecución (Fase 2).
  - Plan rápido (Fase 2).
  - Plantillas (Futuro).
  - Generación automática de OT (Fase 2).
  - «Nueva versión» de procedimiento (RP-11, opcional).
  - Personas por especialidad (Fase 2).
- **Vocabulario:** siempre «activo», nunca «equipo». El documento de alcance dice «equipos» en varios textos de interfaz; en pantalla usa «activo/activos». Los nombres de tablas, columnas y SP no cambian.

## Cómo quiero que trabajes

1. **Lee primero:**
   - `CLAUDE.md` (estándar de UI y colores por función);
   - los **PATRONES/ASP** del proyecto;
   - el documento de alcance **completo**, con atención a §8 a §17, §21, §25 y §26;
   - `WsPlanificacion360` y la página actual de Planificación 360.
2. **Revisa** los SP que ya existen y que el Centro reutiliza:
   - `GEN_PLAN_OCURRENCIAS`, `FNC_PROGRAMACION_FECHAS` y `FNC_PLAN_MEDIDOR_ESTADO`;
   - `INS_PLAN_ACTIVO`, `SEL_PLAN_ACTIVO_COBERTURA`, `INS_PLAN_VERSION_NUEVA` y `UPD_PLAN_VERSION_PUBLICAR`;
   - `INS_ORDEN_TRABAJO_OCURRENCIA`, `SEL_PLAN_OCURRENCIA_BANDEJA` y `SEL_PLANIFICACION_BORRADOR`.
3. **Presenta un plan y espera mi OK.** Debe incluir:
   - una tabla con cada bloque de la referencia, el SP o método web que lo alimenta, si existe o hay que crearlo, y su estado vacío;
   - el orden de trabajo de §26.1: arreglos previos → BD → servicio → interfaz → redirecciones.
4. **Crea:**
   - `Planificacion.aspx` (+ `.cs`), rotulada «Centro de Planificación»;
   - `WsCentroPlanificacion.asmx`, para las **escrituras**: JSON, sin ViewState y `Token.Puede` en cada método;
   - `Js/sigma-centro-planificacion.js`;
   - `Css/LookAndFeel/sigma-centro-planificacion.css`.

   `WsPlanificacion360` sigue sirviendo las lecturas de Ejecuciones, Cumplimiento y Cobertura.
5. **SP nuevos (§26.2):**
   - `SEL_PLAN_CENTRO`
   - `SEL_PLAN_FICHA`
   - `UPS_PLAN_HITO_FRECUENCIA`
   - `UPD_PLAN_ACTIVAR` (también sirve para «Aplicar cambios»)
   - `SEL_PLAN_IMPACTO`
   - `UPD_PLAN_DESACTIVAR` y `UPD_PLAN_REACTIVAR`
   - `DEL_PLAN_VERSION_BORRADOR`
   - `INS_PLAN_DUPLICAR`

   **SP que cambian (§26.3):**
   - `INS_ORDEN_TRABAJO_OCURRENCIA` (asignación desde responsable y grupo);
   - `UPD_ORDEN_TRABAJO_CERRAR`;
   - `SEL_ORDEN_TRABAJO` (`@PLAN`);
   - `INS/UPD_PLAN_HITO` e `INS_PLAN_ACTIVIDAD` (código automático);
   - `SEL_PROGRAMACION*` (sin las privadas);
   - `SEL_PLAN_OCURRENCIA_BANDEJA` (estado de la OT).

   **Esquema de §19.3:** incluye `pro_es_privada` y su migración (§26.5).
6. **Convenciones (§26.4):**
   - UTF-8 con BOM y CRLF;
   - `type="button"` en todo `<button>`;
   - fechas con `SigmaCalendario.conectar()` y nunca `type=date` o `type=time`;
   - paneles con el componente de modal y panel del sitio;
   - compilar con `aspnet_compiler`;
   - SQL con `_scratch/aplicar_sql.py` (`-I` cuando corresponda);
   - actualizar `MD/SIGMA_ESTADO_DESARROLLO.md` al cerrar cada bloque.
7. **Nombres de clase:** la referencia renombró algunas clases para no chocar con el CSS del inicio (`.cbx`, `.pp`, `.rsel`, `.plist`, `.atn`). En el sitio, prefija todo con `cp-` y usa los tokens de `sigma-brand.css`.

## Estructura de la pantalla

### Cabecera (§10.1)

- Título «Centro de Planificación» + planta elegida.
- Filtros globales **Planta** y **Período** (mes y año): afectan a todas las pestañas.
- Acciones:
  - **Carga masiva** (turquesa) abre un panel lateral;
  - **Nuevo plan** (morado) abre un popover con nombre + planta → crea el borrador y lo abre en la ficha.
- **4 KPI** clicables. Cada uno navega a su vista filtrada:

| KPI | Destino |
|---|---|
| Requieren atención (vencidas + atrasadas) | Ejecuciones, filtro «Requieren atención» |
| Disponibles | Ejecuciones, filtro «Disponibles» |
| Cumplimiento del año | Cumplimiento |
| Carga próximas 4 semanas | Ejecuciones, vista Semana |

### Pestañas (§10.2)

Son exactamente 5: **Planes · Ejecuciones · Cumplimiento · Cobertura · Biblioteca**.

- Llevan contador. Ejecuciones lo muestra en rojo si hay algo que atender.
- Cambiar de pestaña no recarga la página: muestra un esqueleto mientras carga.
- La selección vive en la URL (`#tab=planes&plan=<id cifrado>`; la referencia usa `#plan-PLN-0012`).
- Permisos por pestaña según RP-15:
  - Planes, Ejecuciones, Cumplimiento y Cobertura exigen 116;
  - Biblioteca → Procedimientos exige 97;
  - Biblioteca → Calendarios exige 92.

### Planes · workspace (§10.3)

**Lista (380 px, scroll propio)**

- Buscador por nombre, código, activo o intervención.
- Chips con conteo: Todos · Activos · Borradores · Con cambios · Inactivos · Requieren atención.
- **Orden:** primero los que requieren atención; después por próxima ejecución.
- **Fila compacta:**
  - nombre, chip de estado, código y planta;
  - «N activos · M intervenciones»;
  - próxima ejecución (fecha + activo; en un borrador, «Proyección:»);
  - resumen de frecuencias y responsable principal;
  - indicador de vencidas o atrasadas, y «Configuración incompleta» o «Listo para activar» en los borradores.
- **Selección múltiple:** casilla al pasar el puntero, con barra de lote:
  - Duplicar (solo de a uno);
  - Desactivar (solo los activos);
  - quitar selección.
- **Bajo 1.100 px**, lista y ficha se alternan con «← Planes».

**Ficha**

Encabezado (§11.1):

- Nombre editable en línea; código de solo lectura; chip de estado.
- Versión vigente («v3 activa desde 12-09-2026»): al tocarla baja al historial.
- Alcance (planta · tipo · modelo) e indicador de guardado: «Guardando…», «Cambios guardados» o «No se pudo guardar: {mensaje del SP}».
- Acciones según el estado, con la tabla de §11.1:

| Estado | Primaria (morado) | Otras |
|---|---|---|
| Borrador | Activar plan | Duplicar · Eliminar (rojo) |
| Activo | — | Duplicar · Desactivar · Ver historial |
| Activo · cambios sin aplicar | Aplicar cambios | Descartar cambios (ghost) · Desactivar |
| Inactivo | Reactivar | Duplicar · Ver historial · Eliminar si nunca generó |

  **Desactivar no es rojo:** va en el menú «⋯» con confirmación.

Banners (uno a la vez, por prioridad):

- éxito tras activar o aplicar, con «Ver ejecuciones»;
- «Estás editando cambios sin aplicar…» con el n.º de cambios;
- «Plan inactivo» con motivo, fecha y quién;
- vencidas o atrasadas, con «Revisar y generar OT».

**Franja resumen** Qué · Sobre qué · Dónde · Cómo · Cuándo · Quién:

- cada celda baja a su sección;
- lo que falta va en ámbar («Falta», «Sin responsable»).

Secciones numeradas:

1. **Qué mantener** (§11.3):
   - alcance en línea (planta, tipo y modelo opcional; el modelo depende del tipo);
   - aviso de los activos que quedan fuera del alcance;
   - tarjetas de activo con:
     - componente («Activo completo»);
     - lectura del medidor;
     - chip «También en PLN-x»;
     - «Ver ficha del activo» (contorno);
     - quitar (rojo, con **Deshacer** en el toast).
   - estado vacío «La planificación necesita al menos un activo», que se marca en rojo después de intentar activar.
2. **Qué hacer, cómo y cuándo** (§11.4): una tarjeta desplegable por intervención.
   - **Cabecera:**
     - código, nombre;
     - frecuencia en lenguaje natural + tolerancia;
     - próximas 3 fechas (o «al llegar a N h» si es por medidor);
     - chips: parada, overhaul, actividades, duración, tipo · prioridad;
     - responsable e interruptor Habilitada.
   - **Cuerpo**, en bloques:
     - *Datos de la OT*: nombre, tipo, prioridad, duración (> 0), parada, overhaul, descripción;
     - *Cuándo*: el editor de frecuencia (ver abajo);
     - *Qué se hace*: las actividades;
     - *Quién*: responsable + grupo, con el texto «Cada OT nacerá asignada a…».
   - «Agregar intervención» crea la tarjeta abierta con el nombre enfocado y el código automático `INT-0n`.
   - Una intervención solo se puede quitar si nunca generó ejecuciones; si ya generó, se deshabilita con el interruptor.
3. **Próximas ejecuciones** (§11.5):
   - las 10 siguientes, con situación y OT;
   - en un borrador, la proyección rotulada «Proyección: se generarán al activar».
4. **OT generadas** (§11.6):
   - filtro Abiertas · En espera de cierre · Cerradas;
   - «Abrir OT» en contorno.
5. **Historial** (§11.7): versiones de solo lectura; los cambios sin aplicar aparecen como la versión siguiente en borrador.

**Tarjeta «Listo para activar»** (§11.2): columna derecha y fija; arriba de las secciones cuando la ficha es angosta.

- Barra de progreso.
- Bloqueantes con ✓ / ✗ y advertencias con ⚠: cada ítem lleva directo al campo, abre la intervención o la actividad y lo enfoca.
- Impacto: «Al activar se generarán N ejecuciones entre hoy y el {hoy+90} para M activos».
- Activar queda `aria-disabled` mientras falte algo. Al tocarlo igual:
  - marca los vacíos en rojo;
  - lleva al primer bloqueante;
  - explica qué falta.
- En un plan activo muestra el resumen y Duplicar.
- Con cambios sin aplicar muestra los 4 conteos de impacto (se mantienen, se crean, se cancelan, con OT).

### Editor de frecuencia (§15)

**Tipos:** Calendario (por defecto) · Intervalo · Fechas puntuales · Por medidor · Por condición.

| Tipo | Campos |
|---|---|
| Calendario | Diaria, semanal, mensual o anual · «cada N» · días de la semana · día fijo **o** ordinal + día de la semana · mes · hora |
| Intervalo | Cada N + unidad · «a partir de» |
| Fechas puntuales | Chips de fechas con «Agregar fecha» |
| Por medidor | «Cada N» **una sola vez** · desde la lectura · avisar antes · tabla por activo: lectura actual, próximo disparo o «Sin medidor: nunca generará» |
| Por condición | Panel con variable, operador, umbral, duración mínima y severidad |

**Comunes:**

- vigencia desde y hasta;
- «Puede hacerse antes» y «Vence después de» (tolerancias);
- exclusiones: rango + motivo + correr u omitir.

**Vista previa en vivo:**

- las próximas 6 fechas en formato largo («lunes 12 de octubre»);
- las excluidas, tachadas con su motivo; las corridas, con su fecha original;
- para medidor y condición, el disparador.

**Calendario compartido:** «Usar calendario compartido» deja la frecuencia en solo lectura, con «Editar en Biblioteca» y «Convertir en propia».

**No muestres:** alcance, responsables de la programación, zona horaria, permite anticipada o atrasada, «desde la última ejecución» ni «genera automáticamente» (CA-09).

### Actividades (§14)

**Fila arrastrable** con:

- código `ACT-0n`, nombre;
- chip del procedimiento con n.º de pasos y repuestos;
- duración;
- chips Opcional, Parada y Permiso (este último en ámbar si falta el tipo).

**Al tocarla, se despliega en el lugar** con:

- nombre y duración;
- interruptores Obligatoria, Requiere parada y Requiere permiso de trabajo; si hay permiso, el tipo es obligatorio y su error va junto al campo;
- descripción;
- procedimiento: Ver pasos, Editar, Cambiar, quitar, o Elegir o Crear si no tiene;
- **repuestos con buscador en la misma fila**, sin guardar antes (CA-12);
- Subir, Bajar y Quitar.

**Debajo de la lista:** la suma de duraciones frente a la de la intervención, como dato. La OT usa la de la intervención.

### Procedimientos (§13)

- **Elegir procedimiento:** panel ancho con buscador, filtro «Solo {tipo}» y vista previa de pasos, puntos de control y mediciones. **No lista los globales.**
- **Agregar desde procedimiento:** crea la actividad con el nombre, la duración y el permiso del procedimiento.
- **Crear procedimiento desde una actividad:** panel ancho (~720 px) con el nombre de la actividad precargado. Al guardar queda vinculado, sin perder la ficha (CA-11).
- **Editor de pasos:**
  - nombre e instrucción de cada paso;
  - punto de control, evidencia, medición + variable, minutos;
  - reordenar, quitar, agregar e «Importar desde Excel».
  - Si el procedimiento está en uso, avisa: «Usado por N actividades de M planes activos. Las OT futuras tomarán los pasos nuevos; las ya generadas no cambian.»

### Ejecuciones (§10.4)

- **Vistas:** Lista · Semana · Mes, sobre el mismo filtro.
- **Filtros:**
  - chips de situación con conteo: Requieren atención · Vencidas · Atrasadas · Disponibles · Futuras · Con OT · Cerradas · Todas;
  - plan, activo, «Solo con parada» y texto.
- **Fila de la lista:**
  - fecha + «vence …» (o «Reprog. · era …»);
  - activo (y umbral del medidor);
  - intervención + plan, con chips;
  - situación, o estado de la OT (OT-4);
  - responsable;
  - acción: «Generar OT» en turquesa, o el n.º de OT en contorno.
- **Selección:** solo de las vencidas, atrasadas y disponibles, con una barra de lote que muestra las horas.
- **Generar OT en lote:** panel de resultado por fila (generada / ya existía / rechazada y por qué), con conteos (CA-24). Repetir no duplica.
- **Semana:** columnas por día con barra de carga (horas sobre la capacidad).
- **Mes:** grilla con columna de horas por semana; «+N más» abre esa semana.
- **Panel de una ejecución:**
  - situación y banner;
  - fechas programada, disponible, vence y original;
  - disparo del medidor, duración, responsable y grupo;
  - qué se hará (pasos);
  - bloque de la OT;
  - «Ir al plan»;
  - acciones Reprogramar y Generar OT (turquesa).
- **Reprogramar** se hace en el mismo panel (CA-25):
  - fecha nueva con el calendario de SIGMA;
  - motivo obligatorio;
  - aviso: «El cumplimiento se sigue midiendo contra la fecha original (dd-mm-aaaa)».

### Cumplimiento

- KPI:
  - año contra la meta de 90 %;
  - período;
  - vencidas sin OT;
  - reprogramadas.
- Barras de los últimos 6 meses con la línea de la meta.
- Tablas por plan y por activo (peor primero). Al tocar una fila, un panel muestra sus ejecuciones del período (§10.2).
- Nota: una reprogramada cuenta en el mes de su fecha original.

### Cobertura

- Anillo con el % de activos con plan.
- Chips Sin plan · Con plan · Todos, filtro de tipo y buscador.
- Selección múltiple con dos acciones:
  - **Crear plan con estos activos** (morado): precarga los activos y propone el alcance si comparten planta y tipo (§12.1);
  - **Agregar a un plan existente**: lista de planes con cuántos no calzan con el alcance.

### Biblioteca

- **Procedimientos:**
  - lista con buscador y tipo;
  - columnas de pasos, duración y «dónde se usa»;
  - marca «Sistema» con **Copiar para usar** para los globales;
  - Nuevo procedimiento (morado).
- **Calendarios compartidos:**
  - regla, próximas fechas y «dónde se usa» (planes, tareas, pautas);
  - advertencia «Choque: solo uno de los planes genera cada fecha» (§26.5);
  - Duplicar y Editar.
  - El editor va en un panel con vista previa. Exige marcar «Entiendo que el cambio aplica a los N usos» antes de guardar (RP-19).

### Paneles, confirmaciones y menús

- **Paneles laterales** para: agregar activos, elegir o crear procedimiento, duplicar, carga masiva, condición, calendario compartido, detalle de ejecución y resultado de generación.
  - Se cierran con Esc, con la X o tocando fuera.
  - **Agregar activos:**
    - prefiltrado por el alcance;
    - los que no calzan van al final, deshabilitados con su motivo («Otra planta», «Otro tipo»);
    - columna de cobertura;
    - componente y medidor por activo, editables antes de confirmar;
    - resultado por fila (CA-07).
- **Confirmaciones (modal), solo para:** Activar, Aplicar cambios (con los 4 conteos de `SEL_PLAN_IMPACTO`), Descartar cambios, Desactivar (motivo obligatorio + impacto), Reactivar y Eliminar. El resto del flujo **no usa modales** (CA-06).
- **Popovers** para:
  - Nuevo plan;
  - menú «⋯» del plan;
  - calendario de SIGMA;
  - elegir calendario compartido;
  - sugerencias de repuestos;
  - «Agregar a un plan».
- **Toasts** con «Deshacer» en los quitar: activo, intervención nueva, actividad, repuesto, procedimiento, exclusión.

## Diseño

- **Colores por función (§10.5):**
  - **morado:** una sola acción primaria por grupo (Activar, Aplicar cambios, Nuevo plan, Guardar procedimiento, Crear plan con estos activos);
  - **turquesa oscuro:** Generar OT, Reprogramar, Carga masiva;
  - **contorno azul:** abrir o navegar (Abrir OT, Ver ficha del activo, Ver ejecuciones, Agregar…);
  - **ghost:** Cancelar;
  - **rojo:** solo destructivo (Eliminar borrador, Quitar activo, Quitar actividad).
- **Superficies:**
  - tarjetas blancas sin borde con sombra suave;
  - **sin degradados en cabeceras**;
  - foco turquesa visible con teclado;
  - Sora.
- **Estados:**
  - del plan: Borrador (gris) · Activo (verde) · Activo · cambios sin aplicar (morado) · Inactivo (contorno);
  - de la ejecución: Vencida (rojo) · Atrasada (ámbar) · Disponible (turquesa) · Futura · Cerrada · Proyección;
  - de la OT: Abierta (azul) · En ejecución (morado) · En espera de cierre (ámbar) · Cerrada (verde).
- **Validaciones junto al campo**, no en alertas:
  - «La intervención necesita un nombre.»
  - «La duración debe ser mayor que 0.»
  - «Indica el tipo de permiso: la OT lo exigirá antes de empezar.»
  - «Elige al menos un día de la semana.»
  - «Esta intervención necesita una frecuencia para poder activarse.»
- **Responsive:** escritorio primero.

  | Ancho | Comportamiento |
  |---|---|
  | Ficha angosta | Contenedor con `container-type` y una sola columna: la tarjeta «Listo para activar» sube. |
  | < 1.100 px | La lista y la ficha se alternan. |
  | < 900 px | Ejecuciones pasa a filas apiladas; Semana y Mes hacen scroll horizontal dentro de su tarjeta. |
  | < 560 px | KPI en 2 columnas. |

  La página nunca hace scroll horizontal.
- **Accesibilidad:**
  - las filas clicables son `role="button"` con Enter/Espacio;
  - los paneles son `role="dialog"`; las confirmaciones, `alertdialog`;
  - Esc cierra la capa superior;
  - `aria-live` en la vista previa de fechas.

## Datos del prototipo

Todo es simulado en el navegador:

- los planes;
- las fechas (un motor equivalente a `FNC_PROGRAMACION_FECHAS`);
- las OT;
- el rechazo de PH-205 al generar;
- la fila con error de la carga masiva;
- el activo dado de baja EL-01.

En el sitio, cada número y cada mensaje sale de los SP. Los mensajes de error son los de los SP: no los reescribas en el JS.

## Criterios de aceptación

- **CA-01 a CA-29** de `MD/CENTRO_PLANIFICACION_ALCANCE.md` §25, uno por uno, con evidencia.
- La interfaz coincide con la referencia en layout, textos, estados vacíos, validaciones y colores por función.
- **Prueba de flujo CA-06:** crear un plan con 1 intervención mensual, 1 actividad con un procedimiento existente y 3 activos, y activarlo.
  - Sin abrir otra página, otra pestaña ni un modal (salvo la confirmación de Activar).
  - Con una sola acción explícita de guardado.
- Desde «Listo para activar», cada bloqueante lleva al campo exacto y lo enfoca.
- El indicador de guardado pasa por «Guardando…» → «Cambios guardados». Ante un error del SP, muestra «No se pudo guardar: {motivo}» y no pierde lo escrito.
- No aparece «equipo» en ninguna pantalla del Centro, ni el texto «Se generan al publicar la versión» (CA-29).
