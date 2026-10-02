# EP-05 · Mediciones, medidores y variables de condición

> Capturar los valores que describen el estado de un equipo a lo largo del tiempo.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Variables de condición | Control de activos › Configuración de activos › Variables de condición | Ver variables de condición de los activos |
| Medidores *(no aparece en el menú; se abre desde otra pantalla)* | Control de activos › Medidores | Ver los medidores de los activos |
| Medidor de activo (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Control de activos › Medidor de activo (detalle) | Ver los medidores de los activos |
| Variable de condición (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Control de activos › Configuración de activos › Variable de condición (detalle) | Ver variables de condición de los activos |
| Serie de una variable (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Control de activos › Configuración de activos › Serie de una variable (detalle) | Ver variables de condición de los activos |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver los medidores de los activos**
- **Ver variables de condición de los activos**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-035` — Registrar un activo
- `HU-040` — Administrar unidades de medida
- `HU-041` — Administrar variables de condición
- `HU-042` — Configurar el medidor de un activo
- `HU-044` — Registrar una medición de condición


## 4. Paso a paso


### HU-042 · Configurar el medidor de un activo

**Para qué.** Como planificador, registrar el horómetro o contador de un equipo, poder programar mantenimiento por horas de uso y no solo por calendario.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código del medidor | Texto | Sí | Único por activo |
| Tipo | Lista desplegable: Horómetro / Contador / Odometro | Sí | Del catálogo de tipos de medidor |
| Unidad | Lista desplegable | Sí | Horas, ciclos o kilometros |
| Lectura actual | Numérico decimal | Sí | Mayor o igual a cero |
| Es acumulativo | Interruptor | Sí | Activado por defecto |
| Máximo razonable por día | Numérico decimal | No | Ejemplo: 24 para un horómetro en horas |

**Cómo saber que quedó bien:**

1. **Alta de medidor** — Cuando registro el horómetro de un blower con su lectura actual Entonces puedo programar planes por horas sobre ese equipo
2. **Lectura menor a la anterior** — Dado un medidor acumulativo con lectura 8.700 horas Cuando se registra una lectura de 8.200 horas Entonces se rechaza con "La lectura no puede ser menor que la anterior (8.700 h)" Y se ofrece registrar un reemplazo o reinicio del medidor
3. **Reemplazo de medidor** — Cuando registro el reemplazo del medidor Entonces se conserva el acumulado histórico Y la lectura nueva parte desde el valor indicado sin perder las horas anteriores


### HU-043 · Registrar una lectura de medidor desde terreno

**Para qué.** Como técnico de mantenimiento, anotar la lectura del horómetro estando frente a la máquina, que el plan por horas se dispare con el dato real y no con una estimación.

*App y Web · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Activo | Solo lectura, proviene del código QR escaneado | No | No editable |
| Lectura | Teclado numérico ampliado con botón de dictado | Sí | Mayor o igual a la lectura anterior en medidores acumulativos |
| Unidad | Solo lectura | No | Proviene de la configuración del medidor |
| Fecha y hora | Selector de fecha y hora | Sí | Por defecto el momento actual. No puede ser futura |
| Observación | Texto multilinea con dictado por voz | No | Máximo 500 caracteres |
| Fotografía del medidor | Cámara | No | JPG, máximo 4 MB |

**Cómo saber que quedó bien:**

1. **Registro con validación** — Cuando ingreso una lectura válida Entonces se guarda con la fecha y hora del registro Y el valor actual del medidor se actualiza
2. **Salto no razonable** — Dado un medidor con máximo diario de 24 horas Cuando registro un salto de 400 horas respecto de la lectura de ayer Entonces la lectura se acepta y se marca como pendiente de revisión Y aparece en el informe de lecturas a revisar
3. **Registro sin conexión** — Dado que estoy sin señal Cuando registro la lectura Entonces se guarda en el dispositivo y se sincroniza al recuperar conexión Y la fecha registrada es la del momento de la lectura, no la de la sincronización


### HU-044 · Registrar una medición de condición

**Para qué.** Como técnico de mantenimiento, registrar temperatura, vibración o presión de un equipo, construir la serie histórica que permite detectar una degradación antes de la falla.

*App y Web · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Variable | Lista desplegable de las variables del activo | Sí | Variables asociadas al activo |
| Valor | Teclado numérico con botón de dictado | Sí | Numérico con los decimales definidos |
| Unidad | Lista desplegable | Sí | Por defecto la unidad de la variable |
| Componente | Lista desplegable de los componentes del activo | No | Permite medir un punto específico |
| Fecha y hora | Selector de fecha y hora | Sí | Por defecto el momento actual |
| Observación | Texto multilinea con dictado | No | Máximo 500 caracteres |

**Cómo saber que quedó bien:**

1. **Registro con unidad distinta a la esperada** — Dado que la variable espera bar y registro el valor en PSI Entonces se guarda el valor tal como lo ingresé junto con su unidad Y además se guarda su equivalente en la unidad base Y la comparación contra el umbral se realiza sobre el equivalente
2. **Valor fuera de umbral** — Cuando el valor supera el umbral definido para la variable en ese activo Entonces se solicita un comentario Y se genera una alerta del tipo correspondiente


### HU-045 · Consultar la serie histórica de una variable

**Para qué.** Como jefe de mantenimiento, ver cómo ha evolucionado una variable en el tiempo, reconocer una tendencia antes de que se convierta en una falla.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Activo | Lista desplegable con buscador | Sí | Activos del cliente |
| Variable | Lista desplegable dependiente del activo | Sí | Variables asociadas al activo |
| Desde | Selector de fecha | Sí | Por defecto 90 días atrás |
| Hasta | Selector de fecha | Sí | Por defecto la fecha actual. Posterior a Desde |

**Cómo saber que quedó bien:**

1. **Gráfico de tendencia** — Cuando consulto la serie de una variable de un activo Entonces se muestra un gráfico de línea con la banda de valores normales sombreada Y los puntos fuera de umbral se destacan
2. **Origen del dato** — Cuando selecciono un punto del gráfico Entonces se indica quién lo registró, cuándo y si provino de un checklist o de una orden


### HU-041 · Administrar variables de condición

**Para qué.** Como planificador, definir qué variables se miden en los equipos, que las mediciones se registren siempre con el mismo nombre y la misma unidad.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código | Texto | Sí | Único por cliente |
| Nombre | Texto | Sí | Ejemplo: Temperatura de descanso |
| Unidad de medida | Lista desplegable | Sí | Del catálogo de unidades |
| Decimales | Numérico entero | No | Entre 0 y 6 |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |

**Cómo saber que quedó bien:**

1. **Alta de variable** — Cuando defino la variable Temperatura de descanso con unidad grados Celsius Entonces queda disponible para asociarla a activos y a ítems de checklist
2. **Variable asociada a un activo** — Cuando asocio la variable a un activo con sus umbrales Entonces las mediciones de ese activo se validan contra esos umbrales


### HU-040 · Administrar unidades de medida

**Para qué.** Como administrador del cliente, mantener las unidades y sus factores de conversión, que un valor registrado en PSI se pueda comparar con un umbral definido en bar.

*Web · Sprint 2*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Magnitud | Lista desplegable | Sí | Del catálogo de magnitudes |
| Código | Texto | Sí | Único por magnitud |
| Símbolo | Texto | Sí | Ejemplo: PSI |
| Nombre | Texto | Sí | Máximo 100 caracteres |
| Es unidad base | Interruptor | No | Una única unidad base por magnitud |
| Factor respecto de la base | Numérico decimal | No | Distinto de cero |
| Desplazamiento | Numérico decimal | No | Para escalas como grados Celsius y Fahrenheit |

**Cómo saber que quedó bien:**

1. **Alta de unidad derivada** — Cuando registro PSI como unidad de presión con su factor respecto de bar Entonces cualquier valor en PSI se convierte automáticamente para comparar con umbrales en bar
2. **Unidad base por magnitud** — Cuando defino una unidad base para una magnitud Entonces no puede existir una segunda unidad base para esa misma magnitud


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-042 · Lectura menor a la anterior** — Dado un medidor acumulativo con lectura 8.700 horas Cuando se registra una lectura de 8.200 horas Entonces se rechaza con "La lectura no puede ser menor que la anterior (8.700 h)" Y se ofrece registrar un reemplazo o reinicio del medidor
- **HU-040 · Unidad base por magnitud** — Cuando defino una unidad base para una magnitud Entonces no puede existir una segunda unidad base para esa misma magnitud


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
