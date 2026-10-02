# EP-15 · Aplicación móvil y trabajo sin conexión

> Que el técnico pueda trabajar un turno completo en una sala sin señal.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Inicio | Inicio | — |
| Análisis de SIGMA AI | Análisis de SIGMA AI | Ver el analisis de SIGMA AI |
| Mis tareas | Mis tareas | Ejecutar tarea en terreno |
| Pautas de inspección | Pautas de inspección | Ejecutar checklist en terreno |
| Mis órdenes de trabajo | Mis órdenes de trabajo | Ver ordenes de trabajo |
| Existencias de bodega | Existencias de bodega | Ver existencias de bodega |
| Permisos de trabajo | Permisos de trabajo | Ver permisos de trabajo |
| Sincronización | Sincronización | — |
| Bitácora de planta | Bitácora de planta | Ver la bitacora de planta |
| Fallas | Fallas | Ver ordenes de trabajo |
| Mi perfil | Mi perfil | — |
| Catálogo de repuestos | Catálogo de repuestos | Ver el maestro de repuestos |
| Bodegas y estantes | Bodegas y estantes | Ver bodegas y ubicaciones |
| Equipos de la planta | Equipos de la planta | Ver los activos del cliente |
| Componentes | Componentes | Ver los componentes de los activos |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ejecutar checklist en terreno**
- **Ejecutar tarea en terreno**
- **Ver bodegas y ubicaciones**
- **Ver el analisis de SIGMA AI**
- **Ver el maestro de repuestos**
- **Ver existencias de bodega**
- **Ver la bitacora de planta**
- **Ver los activos del cliente**
- **Ver los componentes de los activos**
- **Ver ordenes de trabajo**
- **Ver permisos de trabajo**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-034` — Generar e imprimir el código QR de una posición
- `HU-035` — Registrar un activo
- `HU-150` — Sincronizar los datos hacia el dispositivo
- `HU-151` — Trabajar sin conexión
- `HU-152` — Sincronizar los cambios hacia el servidor sin duplicar
- `HU-154` — Escanear el código QR de una posición


## 4. Paso a paso


### HU-150 · Sincronizar los datos hacia el dispositivo

**Para qué.** Como técnico de mantenimiento, descargar al teléfono lo que voy a necesitar en terreno, poder trabajar después sin depender de la señal.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Primera sincronización** — Cuando sincronizo por primera vez Entonces se descargan catálogos, mis activos, mis órdenes abiertas y las plantillas publicadas Y se muestra el progreso por bloque
2. **Sincronización incremental** — Dado que ya sincronicé antes Cuando vuelvo a sincronizar Entonces solo se descarga lo modificado desde la última marca
3. **Sincronización interrumpida** — Cuando la sincronización se interrumpe a la mitad Entonces al reintentar continúa desde donde quedó Y los datos ya descargados permanecen utilizables


### HU-154 · Escanear el código QR de una posición

**Para qué.** Como técnico de mantenimiento, llegar a la ficha del equipo escaneando el código pegado en la máquina, no buscar el equipo en una lista estando frente a él.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Escaneo con conexión** — Cuando escaneo el código de una posición Entonces se abre la ficha del activo que la ocupa Y veo su estado, criticidad, componentes y órdenes abiertas
2. **Escaneo sin conexión** — Dado que el activo está sincronizado en el dispositivo Cuando escaneo sin conexión Entonces la ficha se abre desde los datos locales Y se indica la fecha de la última sincronización
3. **Posición sin activo asignado** — Cuando escaneo el código de una posición desocupada Entonces se ofrece registrar un activo en esa posición
4. **Código no reconocido** — Cuando escaneo un código que no corresponde a una posición del cliente Entonces se informa que el código no pertenece a esta instalación


### HU-151 · Trabajar sin conexión

**Para qué.** Como técnico de mantenimiento, usar la aplicación completa aunque no tenga señal, no interrumpir el trabajo por una condición que la planta no puede resolver.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Turno completo sin señal** — Dado que estoy sin conexión desde que entré a la planta Cuando escaneo códigos, abro órdenes, ejecuto checklists, dicto observaciones y tomo fotografías Entonces todo funciona sin ningún mensaje de error de red
2. **Indicador permanente** — Cuando estoy sin conexión Entonces un indicador visible muestra el estado y la cantidad de cambios pendientes
3. **Espacio disponible** — Cuando el almacenamiento del dispositivo está por agotarse Entonces se advierte antes de que impida seguir capturando evidencias


### HU-152 · Sincronizar los cambios hacia el servidor sin duplicar

**Para qué.** Como técnico de mantenimiento, que lo que registre en terreno llegue al servidor una sola vez, que el planificador no vea trabajo duplicado ni perdido.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Envío parcial interrumpido** — Dado que tengo doce cambios pendientes Cuando la conexión se corta después de enviar siete Entonces al reintentar solo se envian los cinco restantes Y los siete ya enviados no se duplican
2. **Reenvio del mismo registro** — Cuando el mismo registro se envía dos veces por un reintento Entonces el servidor lo reconoce y no crea un duplicado
3. **Fecha real del registro** — Dado que registré un trabajo a las 22:00 sin señal y sincronizo a las 07:00 Entonces la fecha del registro es las 22:00 Y además se conserva la fecha de sincronización Cada registro creado en terreno lleva un identificador propio generado en el dispositivo. Es lo que permite al servidor reconocer un reenvio y no crear trabajo fantasma.


### HU-153 · Resolver un conflicto de sincronización

**Para qué.** Como técnico de mantenimiento, decidir qué versión se conserva cuando el mismo registro cambio en dos lados, no perder trabajo por una edición simultanea.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Detección del conflicto** — Dado que edité una orden sin señal Y el planificador la modifico en la web mientras tanto Cuando sincronizo Entonces se muestra la comparación campo por campo de ambas versiones
2. **Resolución** — Cuando elijo que versión conservar Entonces la decisión queda registrada con mi nombre y fecha Y la versión descartada queda disponible para consulta
3. **Sin conflicto real** — Dado que los cambios afectan campos distintos Entonces se combinan automáticamente y no se solicita intervención


### HU-155 · Registrar un componente descubierto en terreno

**Para qué.** Como técnico de mantenimiento, dar aviso de un componente que no estaba registrado, que el maestro se complete con lo que realmente hay en la máquina.

*App · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Activo | Solo lectura, proviene del código QR | No | No editable |
| Nombre del componente | Texto con dictado por voz | Sí | Máximo 200 caracteres |
| Tipo de componente | Lista desplegable | No | Del catálogo de tipos de componente |
| Posición física | Texto | No | Ejemplo: lado A, lado B |
| Descripción | Texto multilinea con dictado | No | Máximo 500 caracteres |
| Fotografías | Cámara, hasta 5 imágenes | Sí | Al menos una fotografía |

**Cómo saber que quedó bien:**

1. **Registro del descubrimiento** — Cuando registro un componente no encontrado en el sistema Entonces se crea un descubrimiento pendiente de confirmación Y no se crea todavía el componente definitivo
2. **Registro sin conexión** — Dado que estoy sin señal Entonces el descubrimiento se guarda localmente con sus fotografías Y se sincroniza al recuperar conexión
3. **Confirmación por el planificador** — Cuando el planificador confirma el descubrimiento Entonces se crea el componente definitivo Y las evidencias del descubrimiento quedan asociadas a él
4. **Fusión con un componente existente** — Cuando el planificador determina que corresponde a un componente ya registrado con otro nombre Entonces fusiona ambos registros Y la fusión queda documentada


### HU-156 · Consultar el estado de la sincronización

**Para qué.** Como técnico de mantenimiento, saber qué tengo pendiente de enviar y cuándo sincronicé por última vez, confiar en que lo que registré efectivamente llegó.

*App · Sprint 6*

**Cómo saber que quedó bien:**

1. **Panel de sincronización** — Cuando abro el panel Entonces veo la fecha de la última sincronización, los cambios pendientes y los archivos en cola
2. **Error de envío** — Cuando un registro no puede enviarse Entonces se indica el motivo y la acción sugerida Y el registro permanece en el dispositivo hasta resolverse


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-151 · Turno completo sin señal** — Dado que estoy sin conexión desde que entré a la planta Cuando escaneo códigos, abro órdenes, ejecuto checklists, dicto observaciones y tomo fotografías Entonces todo funciona sin ningún mensaje de error de red
- **HU-151 · Espacio disponible** — Cuando el almacenamiento del dispositivo está por agotarse Entonces se advierte antes de que impida seguir capturando evidencias
- **HU-156 · Error de envío** — Cuando un registro no puede enviarse Entonces se indica el motivo y la acción sugerida Y el registro permanece en el dispositivo hasta resolverse


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
