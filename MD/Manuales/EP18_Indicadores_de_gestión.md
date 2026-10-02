# EP-18 - Indicadores de gestión

> Entregar a la jefatura los números que permiten decidir.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Inicio | Inicio | - | - |
| Alertas | Alertas | - | Ver existencias de bodega |
| Alerta (detalle) *(se abre desde otra pantalla)* | Alerta (detalle) | - | Ver existencias de bodega |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver existencias de bodega**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-053` - Definir el stock mínimo y máximo de un repuesto
- [ ] `HU-086` - Reprogramar una ocurrencia indicando el motivo
- [ ] `HU-091` - Definir los umbrales y las acciones de un ítem
- [ ] `HU-117` - Registrar los servicios contratados en una orden
- [ ] `HU-120` - Cerrar una orden de trabajo
- [ ] `HU-124` - Registrar la indisponibilidad de un equipo
- [ ] `HU-180` - Consultar el tablero de indicadores

## 4. Paso a paso

### HU-180 - Consultar el tablero de indicadores

**Para que.** Como jefe de mantenimiento, ver en una pantalla el estado del área, tomar decisiones con datos y no con impresiones.

*Web - Sprint 6*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Planta | Lista desplegable | No | Vacío incluye todas las plantas |
| Área | Lista desplegable dependiente | No | Vacío incluye todas las áreas |
| Activo | Lista desplegable con buscador | No | Vacío incluye todos los activos |
| Tipo de orden | Lista desplegable | No | Vacío incluye todos los tipos |
| Desde | Selector de fecha | Si | Por defecto el primer día del mes |
| Hasta | Selector de fecha | Si | Por defecto la fecha actual. Posterior a Desde |

**Como saber que quedo bien:**

1. **Tablero principal** - Cuando abro el tablero Entonces veo cumplimiento del plan, disponibilidad, tiempo medio entre fallas y órdenes pendientes de cierre Y cada indicador muestra su valor actual y su variación respecto del periodo anterior
2. **Filtros** - Cuando aplico un filtro por planta, área, activo o rango de fechas Entonces todos los indicadores se recalculan con ese filtro
3. **Detalle de un indicador** - Cuando selecciono un indicador Entonces veo el detalle de los registros que lo componen


### HU-181 - Consultar el cumplimiento del plan de mantenimiento

**Para que.** Como jefe de mantenimiento, saber qué porcentaje del plan se está cumpliendo, detectar a tiempo si el mantenimiento preventivo se está postergando.

*Web - Sprint 6*

**Como saber que quedo bien:**

1. **Cálculo del cumplimiento** - Cuando consulto el cumplimiento de un periodo Entonces se calcula como ocurrencias completadas sobre ocurrencias programadas Y se mide contra la fecha programada original y no contra la reprogramada
2. **Desglose** - Cuando abro el detalle Entonces veo las ocurrencias completadas, atrasadas, vencidas, omitidas y reprogramadas
3. **Cumplimiento por equipo** - Cuando agrupo por activo Entonces veo el cumplimiento de cada equipo ordenado de menor a mayor


### HU-182 - Consultar disponibilidad y confiabilidad de los equipos

**Para que.** Como jefe de mantenimiento, saber cuánto estuvo disponible cada equipo y cada cuánto falla, priorizar dónde intervenir con criterio y no por percepción.

*Web - Sprint 6*

**Como saber que quedo bien:**

1. **Disponibilidad** - Cuando consulto la disponibilidad de un equipo Entonces se calcula descontando la indisponibilidad no planificada del tiempo del periodo Y la indisponibilidad planificada se informa por separado
2. **Tiempo medio entre fallas** - Cuando consulto el tiempo medio entre fallas Entonces se calcula como tiempo operativo total sobre cantidad de fallas Y se indica cuando el periodo no tiene fallas suficientes para que el valor sea representativo
3. **Tiempo medio de reparación** - Cuando consulto el tiempo medio de reparación Entonces se calcula sobre la duración real de las órdenes correctivas cerradas


### HU-183 - Consultar los costos de mantenimiento

**Para que.** Como jefe de mantenimiento, saber cuánto costó mantener cada equipo y cada área, sustentar el presupuesto del área con cifras verificables.

*Web - Sprint 6*

**Como saber que quedo bien:**

1. **Costo por equipo** - Cuando consulto el costo de un equipo Entonces se muestra el costo de repuestos, de mano de obra y de servicios de terceros Y el total se presenta separado por moneda
2. **Costo por centro de costo** - Cuando agrupo por centro de costo Entonces el costo de cada centro incluye el de sus centros dependientes
3. **Comparación entre periodos** - Cuando comparo dos periodos Entonces se muestra la variación absoluta y porcentual


### HU-184 - Consultar la bandeja de alertas

**Para que.** Como planificador, ver en un solo lugar todo lo que el sistema detectó, no revisar cinco pantallas distintas para saber qué requiere atención.

*Web y App - Sprint 6*

**Como saber que quedo bien:**

1. **Bandeja unificada** - Cuando abro la bandeja Entonces veo las alertas abiertas ordenadas por severidad y antigüedad Y cada una indica su tipo, el equipo, el valor observado y el umbral superado
2. **Atender una alerta** - Cuando atiendo una alerta Entonces queda registrado quién la atendió y cuándo Y puedo generar una orden o descartarla indicando el motivo
3. **La alerta no crea trabajo por si sola** - Dado una alerta abierta Entonces no se genera ninguna orden de trabajo hasta que una persona lo decide


### HU-185 - Exportar e imprimir reportes

**Para que.** Como jefe de mantenimiento, llevarme los datos a una planilla o imprimirlos, presentar la información en las instancias donde no se usa el sistema.

*Web - Sprint 6*

**Como saber que quedo bien:**

1. **Exportación a planilla** - Cuando exporto un listado o un indicador Entonces se genera una planilla con los mismos filtros aplicados en pantalla Y el archivo incluye el encabezado con el cliente, el periodo y los filtros usados
2. **Impresión** - Cuando imprimo un reporte Entonces el documento conserva el formato y se ajusta al ancho de la página


## 5. Lo que el sistema no deja hacer

No hay reglas de rechazo declaradas en los criterios de este modulo.

## 6. Si algo no funciona

| Sintoma | Causa mas probable |
|---|---|
| No aparece la opcion en el menu | Falta el permiso de la seccion 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el boton no hace nada | Falta el permiso de la funcion: ver no es lo mismo que crear y editar |
| Dice que no se puede guardar, sin mas detalle | Alguna regla de la seccion 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacios | Falta construir lo de la seccion 3 |
| Estoy en la pantalla correcta y no veo el formulario | Falta pulsar la pestana que indica cada operacion en la seccion 4 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx`, la tabla `Menus` y las pestanas declaradas en los .aspx. Para actualizarlo: `python _scratch/gen_manuales.py`.*
