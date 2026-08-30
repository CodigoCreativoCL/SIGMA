# SIGMA — Product Backlog Priorizado

**Sistema Integrado de Gestión de Mantenimiento Industrial**
Cliente piloto: Hamburgo S.A. — Planta Renca, Chile
Versión del documento: 1.0 · 20 de agosto de 2026
Entrega objetivo: **15 de noviembre de 2026**

---

## 0. Cómo se lee este documento

Este es el documento operativo del proyecto: de aquí salen los sprints, de aquí salen las
pantallas y de aquí sale el mockup. Tiene cinco partes y cada una responde una pregunta distinta.

| Parte | Responde |
|---|---|
| **1. Quién** | Los seis roles reales de la planta, con lo que cada uno puede y no puede hacer |
| **2. Cómo se prioriza** | El método de puntaje, para que "prioridad ALTA" signifique algo y no sea una opinión |
| **3. Las épicas** | Los quince bloques de valor, con su decisión de alcance para el 15 de noviembre |
| **4. El backlog** | 73 historias de usuario con criterios de aceptación, **inputs campo por campo**, tablas y endpoint |
| **5. SIGMA Intelligence** | La especificación completa del panel predictivo en web y app |
| **6. Pantallas** | El inventario de pantallas y el mapa de navegación, que es lo que consume el diseño |

### Convenciones

- **US-nn** identifica una historia. El número no cambia nunca, aunque la historia se mueva de sprint.
- **Inputs**: cada tabla de inputs trae el nombre técnico del campo, la etiqueta que ve el usuario,
  el tipo de control, si es obligatorio, la validación y **la columna de base de datos donde
  aterriza**. Ese último dato es lo que hace que el mockup y el modelo no se separen.
- **Plataforma**: `WEB` (ASP.NET WebForms), `APP` (Flutter), `AMBAS`.
- Los catálogos se citan por su nombre de tabla. Todos vienen precargados por
  `04_CATALOGOS_SIGMA.sql` — **ninguno se digita a mano**.

### Estado del proyecto al escribir esto

El modelo de datos está **terminado y verificado**: 235 tablas, 610 claves foráneas,
21 scripts idempotentes con orden de ejecución comprobado. Lo que sigue es construir encima.

---

## 1. Los roles

Los roles salen de las entrevistas en planta, no de un organigrama teórico. Cada uno tiene una
restricción que importa, y esa restricción es la que define los permisos.

| Rol | Dónde trabaja | Lo que hace | **La restricción que importa** |
|---|---|---|---|
| **Técnico de mantenimiento** | Terreno, con la app, **frecuentemente sin señal** | Toma OT, ejecuta checklists, dicta observaciones, saca fotos, registra hallazgos | **Puede abrir una OT correctiva, pero NO puede cerrarla.** Si toma una OT, otro técnico ya no puede tomarla — pero él sí puede sumar a un compañero |
| **Bodeguero** | Bodega, web y app | Registra el stock mínimo y máximo de cada repuesto, entrega repuestos contra OT | **No compra ni cotiza.** Su alcance es el stock, nada más |
| **Supervisor de mantenimiento** | Planta, web principalmente | Supervisa la ejecución, valida trabajo | **Sí puede cerrar OT** |
| **Jefe de mantenimiento** | Oficina y planta, web | Aprueba, cierra, adjunta el informe de la OT externa, mira indicadores | **Sí puede cerrar OT.** Es quien adjunta el informe del tercero |
| **Planificador** | Oficina, web | Crea planes, publica versiones, genera y asigna OT, decide sobre hallazgos y predicciones | **Cierra OT. Su bandeja de "EN ESPERA DE CIERRE" es la medida directa de su atraso** |
| **Administrador del cliente** | Oficina, web | Usuarios, perfiles, plantas, áreas, centros de costo, suscripción | No ejecuta trabajo |
| **Administrador SIGMA** | Nosotros | Clientes, planes comerciales, modelos predictivos globales | Es el único rol que cruza clientes |

> **Regla transversal de multicliente.** Ningún rol ve datos de otro cliente. La única excepción
> es el Administrador SIGMA. Esto no es una decisión de interfaz: está en el modelo, con
> `<pfx>_cliente` en cada tabla transaccional y claves foráneas compuestas
> (`UX_ACT_CLIENTE_ID`) que hacen imposible que una OT de un cliente apunte al activo de otro.

---

## 2. Cómo se prioriza

Se usa **WSJF simplificado** — Weighted Shortest Job First. Cada historia recibe cuatro números:

```
                    VALOR + URGENCIA + HABILITACIÓN
       WSJF   =    ─────────────────────────────────
                              ESFUERZO
```

| Factor | Qué mide | Escala |
|---|---|---|
| **VALOR** | Cuánto duele hoy en la planta que esto no exista | 1–10 |
| **URGENCIA** | Qué se pierde si se hace en diciembre en vez de octubre | 1–10 |
| **HABILITACIÓN** | Cuántas otras historias se destraban al terminar esta | 1–10 |
| **ESFUERZO** | Puntos de historia (Fibonacci: 1, 2, 3, 5, 8, 13, 21) | 1–21 |

**Por qué HABILITACIÓN pesa igual que VALOR.** Sin esa columna, el login queda al fondo del
backlog: nadie en la planta pide "un login", su valor de negocio directo es bajo. Pero sin login
no hay nada más. HABILITACIÓN es lo que evita que el backlog quede ordenado por entusiasmo.

**Cómo se traduce a MoSCoW:**

| WSJF | MoSCoW | Significa |
|---|---|---|
| ≥ 4,0 | **MUST** | Va sí o sí antes del 15 de noviembre. Sin esto no hay demo |
| 2,0 – 3,9 | **SHOULD** | Va, salvo que el calendario se rompa |
| 1,0 – 1,9 | **COULD** | Solo si sobra tiempo |
| < 1,0 | **WON'T (esta entrega)** | Modelado, con script de tablas y documentado. No se construye interfaz |

> **Sobre WON'T.** No significa descartado. Significa que la tabla existe, el script la crea, y
> el anexo explica la decisión de diseño — que es exactamente lo que se está entregando como
> trabajo de modelado. Lo que no se construye es la **pantalla**. La diferencia entre llegar y no
> llegar al 15 de noviembre es, casi toda, interfaz.

---

## 3. Mapa de épicas

| ID | Épica | Historias | Puntos | Decisión al 15-nov | Sprints |
|---|---|:--:|:--:|---|---|
| **EP-01** | Fundaciones, acceso y multicliente | 6 | 34 | **Construir** | S1 |
| **EP-02** | Maestro de activos y ubicación técnica | 7 | 47 | **Construir** | S2–S3 |
| **EP-03** | Mediciones y horómetros | 4 | 21 | Recortar: horómetro + 1 variable | S3 |
| **EP-04** | Motor de programación | 4 | 34 | **Construir completo** | S4 |
| **EP-05** | Planes de mantenimiento | 5 | 34 | **Construir completo** | S6 |
| **EP-06** | Checklist dinámico | 6 | 42 | **Construir completo** | S5 |
| **EP-07** | Órdenes de trabajo | 8 | 55 | Recortar: sin permisos de trabajo | S4, S6–S7 |
| **EP-08** | Terreno sin señal (app) | 5 | 42 | **Construir** — es el diferenciador | S3–S7 |
| **EP-09** | Voz e inclusión | 3 | 21 | **Construir** — motor del teléfono | S6 |
| **EP-10** | Evidencias y archivos | 3 | 16 | Recortar: fotos sí, análisis visual no | S7 |
| **EP-11** | **SIGMA Intelligence** | 6 | 42 | **Construir** — datos sintéticos | S10 |
| **EP-12** | Repuestos y consumo | 4 | 21 | Recortar fuerte: solo consumo en OT | S7 |
| **EP-13** | Indicadores y reportes | 3 | 21 | Construir 4 indicadores | S9 |
| **EP-14** | Suscripción y bloqueo | 3 | 21 | **Construir** | S8 |
| **EP-15** | Bitácora | 2 | 13 | Recortar: texto y voz dentro de la OT | S7 |
| **EP-16** | Terceros y OT externas | 2 | 13 | **No construir** — modelado y documentado | — |
| **EP-17** | Importación masiva | 1 | 13 | **No construir** — la demo carga por script | — |
| | **TOTAL** | **73** | **490** | | |

**Capacidad disponible:** 12 sprints × 2 pistas. Con 3 personas a medio tiempo la velocidad
realista es **30–35 puntos por sprint**, es decir **360–420 puntos**. El backlog tiene 490.

> **Ese desajuste es el dato más importante del documento.** Los 490 puntos no caben en 420. La
> diferencia — unos 90 puntos — es exactamente lo que está marcado como WON'T y COULD. Si el
> equipo intenta hacerlo todo, no termina nada. El corte ya está hecho y está en la tabla de
> arriba: **EP-16 y EP-17 no se construyen**, y EP-03, EP-10 y EP-12 van recortadas.

---

## 4. El backlog

### EP-01 · Fundaciones, acceso y multicliente

---

#### US-001 · Iniciar sesión

| | |
|---|---|
| **Como** | usuario de SIGMA |
| **Quiero** | entrar al sistema con mi correo y contraseña |
| **Para** | acceder solo a lo que me corresponde, en el cliente que me corresponde |
| **Plataforma** | AMBAS |
| **Valor / Urgencia / Habilitación / Esfuerzo** | 4 / 9 / 10 / 5 |
| **WSJF** | **4,6** — MUST |
| **Sprint** | S1 |

**Inputs — pantalla `LOGIN`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtCorreo` | Correo electrónico | Texto, `type=email`, autofocus | Sí | Formato correo, máx. 200 | `Usuario.usu_email` |
| `txtClave` | Contraseña | Password, con botón "ver" | Sí | Mín. 8 caracteres | `Usuario.usu_clave` (hash) |
| `chkRecordar` | Mantener sesión iniciada | Checkbox | No | — | — |
| `ddlCliente` | Cliente | Combo — **solo aparece si el usuario pertenece a más de uno** | Sí (si visible) | Debe existir en `Cliente_Usuario` | `Cliente.cli_id` |

**Acciones:** `Ingresar` (primaria) · `Olvidé mi contraseña` (enlace)

**Criterios de aceptación**

```gherkin
Escenario: Credenciales correctas, un solo cliente
  Dado que existo en Usuario con estado habilitado
    Y pertenezco a exactamente un Cliente
  Cuando ingreso correo y contraseña correctos
  Entonces entro directamente a la portada
    Y NO se me pregunta por el cliente

Escenario: Credenciales correctas, varios clientes
  Dado que pertenezco a dos o más Cliente
  Cuando ingreso credenciales correctas
  Entonces se muestra el selector de cliente antes de entrar

Escenario: Suscripción vencida
  Dado que la Suscripcion del cliente está vencida
  Cuando ingreso credenciales correctas
  Entonces entro, pero solo veo la pantalla de renovación
    Y el resto del menú está deshabilitado

Escenario: Credenciales incorrectas
  Cuando ingreso una contraseña incorrecta
  Entonces se muestra "Correo o contraseña incorrectos"
    Y NO se indica cuál de los dos falló
    Y se registra el intento en Sis_Excepcion
```

**Tablas:** `Usuario`, `Cliente_Usuario`, `Cliente`, `Usuario_Perfil`, `Perfiles`, `Suscripcion`
**Endpoint:** `POST /api/auth/login` → `{ token, usuario, cliente, perfiles, permisos[], suscripcion }`

---

#### US-002 · Ver mis permisos aplicados en la interfaz

| | |
|---|---|
| **Como** | usuario con un perfil asignado |
| **Quiero** | ver únicamente los menús y botones que puedo usar |
| **Para** | no perder tiempo en pantallas que me van a rechazar |
| **Plataforma** | AMBAS |
| **V/U/H/E** | 6 / 7 / 9 / 5 · **WSJF 4,4** — MUST |
| **Sprint** | S1 |

**Criterios de aceptación**

```gherkin
Escenario: El botón que no puedo usar no existe
  Dado que mi perfil no tiene el permiso OT_CERRAR
  Cuando abro el detalle de una orden de trabajo
  Entonces el botón "Cerrar OT" no se muestra

Escenario: El permiso también se valida en el servidor
  Dado que mi perfil no tiene el permiso OT_CERRAR
  Cuando invoco directamente POST /api/ot/{id}/cerrar
  Entonces recibo 403
    Y la orden NO cambia de estado
```

> **Por qué el segundo escenario es obligatorio.** Ocultar el botón es comodidad, no seguridad.
> Un permiso que solo vive en la interfaz es un permiso que no existe.

**Tablas:** `Permiso`, `Perfil_Permiso`, `Cliente_Usuario_Permiso`, `Usuario_Perfil`
**Endpoint:** `GET /api/auth/permisos`

---

#### US-003 · Administrar usuarios del cliente

| | |
|---|---|
| **Como** | administrador del cliente |
| **Quiero** | crear usuarios, asignarles perfil, planta y especialidad |
| **Para** | que cada persona entre con lo suyo |
| **Plataforma** | WEB · **V/U/H/E** 6/6/7/8 · **WSJF 2,4** — SHOULD · **Sprint** S1 |

**Inputs — pantalla `USUARIO_EDITAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtRut` | RUT | Texto con máscara | Sí | Dígito verificador válido, único por cliente | `Usuario.usu_rut` |
| `txtNombre` | Nombres | Texto | Sí | Máx. 100 | `Usuario.usu_nombre` |
| `txtApellido` | Apellidos | Texto | Sí | Máx. 100 | `Usuario.usu_apellido` |
| `txtEmail` | Correo | Texto email | Sí | Único en todo SIGMA | `Usuario.usu_email` |
| `txtTelefono` | Teléfono | Texto | No | Formato +56 9 XXXX XXXX | `Usuario.usu_telefono` |
| `ddlPerfil` | Perfil | Combo | Sí | De `Perfiles` | `Usuario_Perfil.upe_perfil` |
| `chkInstalaciones` | Plantas asignadas | Multi-check | Sí, ≥1 | De `Cliente_Instalacion` | `Cliente_Instalacion_Usuario` |
| `grdEspecialidades` | Especialidades | Grilla editable | No | Ver bloque siguiente | `Usuario_Especialidad` |
| `chkHabilitado` | Habilitado | Switch | — | Por defecto activo | `Usuario.usu_habilitado` |

**Sub-grilla de especialidades** — una fila por especialidad:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `ddlEspecialidad` | Especialidad | Combo de `Especialidad` | Sí | `ues_especialidad` |
| `ddlNivel` | Nivel | Combo de `Especialidad_Nivel` | No | `ues_especialidad_nivel` |
| `txtCertificacion` | Certificación | Texto | No | `ues_certificacion` |
| `dtpVencimiento` | Vence el | Fecha | No | `ues_fecha_vencimiento` |

```gherkin
Escenario: Certificación vencida
  Dado que un técnico tiene una especialidad con fecha de vencimiento pasada
  Cuando el planificador lo elige para asignar una OT que exige esa especialidad
  Entonces se muestra la advertencia "Certificación vencida el {fecha}"
    Y la asignación se permite igual, pero queda registrada la advertencia
```

> **Por qué se permite igual.** Bloquear la asignación haría que la planta deje de usar el
> sistema el día que una certificación venza un viernes por la tarde. Advertir y registrar
> resuelve el problema real — que nadie se entere — sin detener el trabajo.

**Tablas:** `Usuario`, `Usuario_Perfil`, `Cliente_Usuario`, `Cliente_Instalacion_Usuario`, `Usuario_Especialidad`

---

#### US-004 · Administrar plantas y áreas

| | |
|---|---|
| **Como** | administrador del cliente · **WEB** · V/U/H/E 5/6/8/5 · **WSJF 3,8** — SHOULD · **S1** |

**Inputs — pantalla `AREA_EDITAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlInstalacion` | Planta | Combo | Sí | — | `iar_cliente_instalacion` |
| `ddlAreaPadre` | Área superior | Combo jerárquico (árbol) | No | No puede ser ella misma ni un descendiente | `iar_area_padre` |
| `txtCodigo` | Código | Texto | Sí | Único por planta, mayúsculas, sin espacios | `iar_codigo` |
| `txtNombre` | Nombre | Texto | Sí | Máx. 200 | `iar_nombre` |
| `ddlTipo` | Tipo de área | Combo de `Instalacion_Area_Tipo` | No | — | `iar_instalacion_area_tipo` |
| `txtDescripcion` | Descripción | Área de texto | No | Máx. 500 | `iar_descripcion` |

> **Sobre la jerarquía.** `Planta 2 → Producción → Línea 1` no es cosmético: es lo que permite
> preguntar "cuántas horas de paro tuvo Producción" sumando sus hijas. Sin árbol, ese total hay
> que mantenerlo a mano y a los tres meses está mal.

---

#### US-005 · Administrar centros de costo · WEB · WSJF 2,0 — SHOULD · S1
#### US-006 · Cambiar mi contraseña y mi foto · AMBAS · WSJF 1,5 — COULD · S1

---

### EP-02 · Maestro de activos y ubicación técnica

---

#### US-010 · Registrar una posición funcional

| | |
|---|---|
| **Como** | planificador |
| **Quiero** | definir posiciones funcionales estables (CB01, CB02) |
| **Para** | que el QR pegado en la sala siga sirviendo aunque cambien la máquina |
| **Plataforma** | WEB · V/U/H/E 7/7/9/5 · **WSJF 4,6** — MUST · **S2** |

> **La decisión de diseño que hay que entender antes de dibujar esta pantalla.**
> La posición es el lugar; el activo es la máquina que hoy ocupa ese lugar. Si el blower 1 se
> manda a reparar y entra otro en su lugar, la posición CB01 no cambia — cambia qué activo la
> ocupa, y eso queda en `Activo_Posicion_Historial`. **El QR se pega en la posición, no en la
> máquina.** Sin esta separación, cada intercambio de equipos rompe la trazabilidad histórica.

**Inputs — pantalla `POSICION_EDITAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlInstalacion` | Planta | Combo | Sí | — | `apo_cliente_instalacion` |
| `ddlArea` | Área | Combo en cascada de la planta | Sí | — | `apo_instalacion_area` |
| `txtCodigo` | Código de posición | Texto | Sí | **Único por cliente.** Es el contenido del QR | `apo_codigo` |
| `txtNombre` | Nombre | Texto | Sí | Ej. "Blower 1 sala de blowers" | `apo_nombre` |
| `ddlActivoTipo` | Tipo de activo admitido | Combo de `Activo_Tipo` | No | — | `apo_activo_tipo` |
| `chkCritica` | Posición crítica | Switch | — | Por defecto no | `apo_critica` |

**Acciones:** `Guardar` · `Guardar e imprimir QR` · `Ver historial de ocupación`

```gherkin
Escenario: Imprimir el QR
  Cuando presiono "Guardar e imprimir QR"
  Entonces se genera un PDF con el código QR, el código de posición y el nombre
    Y el contenido del QR es el apo_codigo, no el act_id

Escenario: Historial de ocupación
  Dado que la posición CB01 fue ocupada por el activo A y luego por el B
  Cuando abro "Ver historial de ocupación"
  Entonces veo dos filas con fecha de inicio y fin
    Y la fila vigente tiene fecha de fin vacía
```

**Tablas:** `Activo_Posicion`, `Activo_Posicion_Historial`, `Instalacion_Area`

---

#### US-011 · Registrar un activo

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 9/8/10/8 · **WSJF 3,4** — MUST · **S2** |

**Inputs — pantalla `ACTIVO_EDITAR`, pestaña "Identificación"**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtCodigo` | Código | Texto | Sí | Único por cliente | `act_codigo` |
| `txtNombre` | Nombre | Texto | Sí | Máx. 200 | `act_nombre` |
| `ddlInstalacion` | Planta | Combo | Sí | — | `act_cliente_instalacion` |
| `ddlArea` | Área | Combo en cascada | No | Debe pertenecer a la planta | `act_instalacion_area` |
| `ddlPosicion` | Posición funcional | Combo en cascada del área | No | Debe estar libre o pedir confirmación | `act_activo_posicion` |
| `ddlActivoTipo` | Tipo | Combo jerárquico | Sí | — | `act_activo_tipo` |
| `ddlActivoModelo` | Modelo | Combo en cascada del tipo | No | — | `act_activo_modelo` |
| `ddlActivoPadre` | Activo superior | Combo | No | No puede ser sí mismo ni descendiente | `act_activo_padre` |
| `ddlEstado` | Estado | Combo de `Activo_Estado` | Sí | Por defecto OPERATIVO | `act_activo_estado` |
| `ddlCriticidad` | Criticidad | Combo de `Criticidad_Nivel` | Sí | — | `act_criticidad` |
| `ddlCentroCosto` | Centro de costo | Combo | No | — | `act_centro_costo` |

**Pestaña "Datos técnicos"**

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `txtSerie` | Número de serie | Texto | No | `act_serie` |
| `txtFabricante` | Fabricante | Texto | No | `act_fabricante` |
| `dtpPuestaMarcha` | Puesta en marcha | Fecha | No | `act_fecha_puesta_marcha` |
| `grdAtributos` | Ficha técnica | Grilla dinámica según `Atributo_Tecnico` | No | `Activo_Atributo` |

**Pestaña "Medición"** — ver US-020.
**Pestaña "Componentes"** — ver US-012.

```gherkin
Escenario: La posición ya está ocupada
  Dado que la posición CB01 está ocupada por otro activo
  Cuando la elijo para este activo
  Entonces se muestra "CB01 está ocupada por {activo}. ¿Desea reemplazar?"
    Y al confirmar se cierra el historial del activo anterior con fecha de fin
    Y se abre una fila nueva en Activo_Posicion_Historial para este activo

Escenario: El código QR se genera solo
  Cuando guardo el activo por primera vez
  Entonces se le asigna un act_uuid
    Y ese UUID es la clave de sincronización con la app
```

**Tablas:** `Activo`, `Activo_Tipo`, `Activo_Modelo`, `Activo_Posicion`, `Activo_Posicion_Historial`, `Activo_Atributo`, `Atributo_Tecnico`, `Activo_Estado_Historial`
**Endpoints:** `POST /api/activo` · `GET /api/activo/{uuid}` · `GET /api/activo/sincronizar?desde={fecha}`

---

#### US-012 · Registrar componentes de un activo

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 7/6/8/5 · **WSJF 4,2** — MUST · **S2** |

**Inputs — panel `COMPONENTE_EDITAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlComponentePadre` | Componente superior | Combo (árbol del activo) | No | — | `aco_componente_padre` |
| `txtCodigo` | Código | Texto | Sí | Único por activo | `aco_codigo` |
| `txtNombre` | Nombre | Texto | Sí | Ej. "Rodamiento lado acople" | `aco_nombre` |
| `ddlTipo` | Tipo de componente | Combo de `Componente_Tipo` | No | — | `aco_tipo` |
| `txtPosicion` | Posición física | Texto | No | Ej. "lado A", "lado B" | `aco_posicion` |
| `ddlCriticidad` | Criticidad | Combo | Sí | — | `aco_criticidad` |
| `ddlEstado` | Estado | Combo de `Activo_Componente_Estado` | Sí | — | `aco_activo_componente_estado` |
| `dtpInstalacion` | Fecha de instalación | Fecha | No | No futura | `aco_fecha_instalacion` |

**Tablas:** `Activo_Componente`, `Componente_Repuesto_Instalacion`

---

#### US-013 · Buscar un activo escaneando su QR

| | |
|---|---|
| **Como** | técnico en terreno · **APP** · V/U/H/E 9/8/6/5 · **WSJF 4,6** — MUST · **S3** |

```gherkin
Escenario: Escaneo con señal
  Cuando escaneo el QR de la posición CB01
  Entonces se abre la ficha del activo que ocupa esa posición
    Y veo su estado, criticidad, componentes y OT abiertas

Escenario: Escaneo SIN señal
  Dado que el activo está en la base local del teléfono
  Cuando escaneo el QR sin conexión
  Entonces se abre la ficha igual, desde la base local
    Y se muestra el aviso "Datos locales, última sincronización {fecha}"

Escenario: Posición desocupada
  Cuando escaneo un QR de una posición sin activo asignado
  Entonces se ofrece "Registrar un activo en esta posición"
```

> **El tercer escenario es la razón de ser del diseño posición/activo.** Un QR que apunta a una
> posición vacía sigue siendo útil: es el punto de partida para dar de alta lo que hay ahí.
> Un QR pegado a una máquina que ya no está, no sirve para nada.

**Tablas:** `Activo_Posicion`, `Activo`, `Activo_Componente`, `Orden_Trabajo`

---

#### US-014 · Ver la ficha de un activo con su historial
#### US-015 · Cambiar el estado de un activo con motivo
#### US-016 · Administrar tipos y modelos de activo

*(WEB · WSJF 3,1 / 2,8 / 2,2 — todas SHOULD · S2–S3)*

---

### EP-03 · Mediciones y horómetros

---

#### US-020 · Configurar el horómetro de un activo

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 8/8/9/3 · **WSJF 8,3** — MUST · **S3** |

> **La historia con mayor WSJF de todo el backlog.** Tres puntos de esfuerzo que destraban el
> plan por horas, la alerta de mantenimiento próximo y la mitad de las características del
> modelo predictivo.

**Inputs — pestaña "Medición" de `ACTIVO_EDITAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtMedidorCodigo` | Código del medidor | Texto | Sí | Único por activo | `amd_codigo` |
| `ddlMedidorTipo` | Tipo | Combo: HORÓMETRO / CONTADOR / ODÓMETRO | Sí | — | `amd_medidor_tipo` |
| `ddlUnidad` | Unidad | Combo de `Unidad_Medida` | Sí | Horas, ciclos, km | `amd_unidad_medida` |
| `numValorActual` | Lectura actual | Numérico decimal | Sí | ≥ 0 | `amd_valor_actual` |
| `chkAcumulativo` | Es acumulativo | Switch | — | Por defecto sí | `amd_acumulativo` |
| `numMaximoDiario` | Máximo razonable por día | Numérico | No | Ej. 24 para un horómetro en horas | `amd_maximo_diario` |

```gherkin
Escenario: Lectura menor que la anterior en un medidor acumulativo
  Dado un horómetro acumulativo con lectura 8.700 h
  Cuando alguien registra 8.200 h
  Entonces se rechaza con "La lectura no puede ser menor que la anterior (8.700 h)"
    Y se ofrece "¿El medidor se reemplazó o se reinició?" como alternativa

Escenario: Salto imposible
  Dado un horómetro con máximo diario de 24 h y última lectura de ayer
  Cuando se registra un salto de 400 h
  Entonces se acepta pero se marca como sospechosa
    Y aparece en el informe de lecturas a revisar
```

> **Por qué se acepta y se marca, en vez de rechazar.** El salto puede ser real: la máquina
> estuvo dos semanas sin que nadie tomara lectura. Rechazarlo obliga al técnico a inventar un
> número que pase la validación, y ese número inventado envenena al modelo predictivo. Aceptar
> y marcar conserva el dato real y avisa a quien puede investigarlo.

**Tablas:** `Activo_Medidor`, `Activo_Medidor_Lectura`, `Unidad_Medida`

---

#### US-021 · Registrar una lectura de horómetro desde terreno

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 8/8/8/3 · **WSJF 8,0** — MUST · **S3** |

**Inputs — pantalla `LECTURA_REGISTRAR` (app)**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `lblActivo` | Activo | Solo lectura, viene del QR | — | — | `aml_activo_medidor` |
| `numLectura` | Lectura | **Teclado numérico grande** + botón de dictado | Sí | Ver US-020 | `aml_valor` |
| `lblUnidad` | Unidad | Solo lectura | — | — | derivada del medidor |
| `dtpFecha` | Fecha y hora | Fecha-hora, por defecto ahora | Sí | No futura | `aml_fecha_lectura_utc` |
| `txtObservacion` | Observación | Texto multilínea + dictado | No | Máx. 500 | `aml_observacion` |
| `btnFoto` | Foto del medidor | Cámara | No | JPG, máx. 4 MB | `Archivo_Vinculo` |

> **Sobre el teclado numérico grande.** El técnico está de pie, con guantes, frente a una máquina
> ruidosa. Un campo de texto estándar con teclado alfanumérico completo es la diferencia entre
> que registre la lectura y que la anote en un papel para "pasarla después" — que significa nunca.

**Tablas:** `Activo_Medidor_Lectura`, `Activo_Medidor`, `Archivo`, `Archivo_Vinculo`
**Endpoint:** `POST /api/medidor/{uuid}/lectura` — idempotente por `aml_uuid`

---

#### US-022 · Registrar una medición de condición · APP/WEB · WSJF 3,0 — SHOULD · S3
#### US-023 · Ver la serie histórica de una variable · WEB · WSJF 2,5 — SHOULD · S9

---

### EP-04 · Motor de programación

---

#### US-030 · Crear una programación por medidor

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 9/8/10/8 · **WSJF 3,4** — MUST · **S4** |

> Esta es la programación que hace posible "cada 500 horas". Es una de seis, y las seis viven en
> **una sola tabla** `Programacion` con una hija por tipo. Un motor, tres consumidores: planes,
> tareas y checklists. Si cada uno tuviera su propia recurrencia, "cada segundo martes del mes"
> habría que implementarlo tres veces, y a los seis meses las tres se comportarían distinto ante
> el mismo feriado.

**Inputs — pantalla `PROGRAMACION_EDITAR`, paso 1: qué tipo**

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `ddlTipo` | Tipo de recurrencia | **Tarjetas seleccionables**, 6 opciones | Sí | `pro_programacion_tipo` |
| `txtNombre` | Nombre | Texto | Sí | `pro_nombre` |
| `dtpInicio` | Vigente desde | Fecha | Sí | `pro_fecha_inicio` |
| `dtpFin` | Vigente hasta | Fecha | No — vacío = indefinida | `pro_fecha_fin` |
| `ddlZonaHoraria` | Zona horaria | Combo | No — vacío = hereda de la planta | `pro_zona_horaria` |

Las seis tarjetas: `ABIERTA` · `FECHA ÚNICA` · `CALENDARIO` · `INTERVALO DE TIEMPO` · `MEDIDOR` · `CONDICIÓN`

**Paso 2 (si eligió MEDIDOR) — inputs de `Programacion_Medidor`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `numCadaCantidad` | Cada | Numérico | Sí | > 0. Ej. 500 | `pme_cada_cantidad` |
| `ddlUnidad` | Unidad | Combo | Sí | Horas / ciclos | `pme_unidad_medida` |
| `numAvisoAnticipacion` | **Avisar con** | Numérico | No | Ej. 50 h antes | `pme_aviso_anticipacion` |
| `numValorBase` | Desde la lectura | Numérico | No | Vacío = desde la actual | `pme_valor_base` |

**Paso 3 — tolerancias, comunes a los seis tipos**

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `numToleranciaAntes` | Se puede adelantar (min) | Numérico | Sí, por defecto 0 | `pro_tolerancia_antes_minuto` |
| `numToleranciaDespues` | Se puede atrasar (min) | Numérico | Sí, por defecto 0 | `pro_tolerancia_despues_minuto` |
| `chkGeneraAuto` | Generar automáticamente | Switch | Por defecto sí | `pro_genera_automaticamente` |

> **Las tolerancias son lo que convierte una fecha en una ventana.** Sin ellas, una mantención
> del martes que se hizo el miércoles figura como incumplida, y el indicador de cumplimiento deja
> de significar algo — con lo cual nadie lo mira, y el sistema pierde la mitad de su utilidad.

```gherkin
Escenario: El aviso anticipado
  Dado un plan cada 500 h con aviso 50 h antes
    Y un horómetro en 8.650 h con el último hito ejecutado a las 8.200 h
  Cuando se registra una lectura de 8.655 h
  Entonces se genera una Alerta de tipo MEDIDOR PROXIMO MANTENIMIENTO
    Y la alerta NO crea una orden de trabajo por sí sola
```

**Tablas:** `Programacion`, `Programacion_Medidor`, `Programacion_Generacion`, `Alerta`

---

#### US-031 · Crear una programación por calendario · WEB · WSJF 3,0 — MUST · S4
#### US-032 · Generar ocurrencias automáticamente (job) · SERVIDOR · WSJF 4,0 — MUST · S4
#### US-033 · Reprogramar una ocurrencia dejando rastro · WEB · WSJF 3,3 — MUST · S4

```gherkin
# US-033
Escenario: Reprogramar no borra
  Dado una ocurrencia programada para el 12 de marzo
  Cuando la reprogramo al 19 de marzo con motivo "sin repuesto"
  Entonces la ocurrencia original queda en estado REPROGRAMADA
    Y la nueva apunta a ella por pmo_ocurrencia_origen
    Y conserva pmo_fecha_programada_original_utc = 12 de marzo
    Y el indicador de cumplimiento se mide contra el 12, no contra el 19
```

> **Ese último criterio es todo el punto.** Si el cumplimiento se midiera contra la fecha nueva,
> bastaría reprogramar para tener 100% de cumplimiento siempre. Medir contra la original es lo
> que hace que el número signifique algo.

---

### EP-05 · Planes de mantenimiento

---

#### US-040 · Crear un plan con sus hitos

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 10/8/9/13 · **WSJF 2,1** — MUST · **S6** |

> **Entender el hito antes de dibujar la pantalla.** El plan real de los blowers Aerzen no dice
> "cambiar el filtro cada 500 horas". Dice: *"a las 500 HRS hacer estas cuatro cosas"*. El
> agrupador es el **hito**, y es el hito —no la actividad— lo que se programa.
>
> ```
> Plan "Preventivo Blower Aerzen GM10S"
> └── Versión v1 (publicada, inmutable)
>     ├── Aplica a: CB01 · CB02 · CB03 · CB04
>     ├── Hito "500 HRS"  →  Programación MEDIDOR cada 500 h
>     │     ├── Actividad 1 · Cambio de filtro de aire   → repuesto: filtro, 1 un
>     │     └── Actividad 2 · Cambio de aceite           → repuesto: aceite, 20 L
>     └── Hito "15000 HRS — Over Haul"  (es overhaul, requiere parada)
> ```
>
> Sin el hito, al llegar a las 500 horas el generador crea **dos órdenes sueltas** —una por
> actividad— y el técnico va dos veces a la misma máquina. Con el hito crea **una orden con dos
> pasos**. Esto corrige el defecto E-01 del modelo v1.

**Inputs — pantalla `PLAN_EDITAR`, cabecera**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtCodigo` | Código del plan | Texto | Sí | Único por cliente | `pma_codigo` |
| `txtNombre` | Nombre | Texto | Sí | Máx. 200 | `pma_nombre` |
| `ddlInstalacion` | Planta | Combo | No — vacío = todas | — | `pma_cliente_instalacion` |
| `ddlActivoTipo` | Para el tipo de activo | Combo | No | — | `pma_activo_tipo` |
| `ddlActivoModelo` | Para el modelo | Combo en cascada | No | — | `pma_activo_modelo` |
| `ddlPlanificador` | Planificador responsable | Combo de usuarios | No | — | `pma_usuario_planificador` |
| `txtDescripcion` | Descripción | Área de texto | No | — | `pma_descripcion` |

**Panel "Activos cubiertos"** — grilla con selector múltiple:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `chkActivos` | Activos | Selector múltiple con filtro por tipo | Sí, ≥1 | `pac_activo` |
| `ddlMedidorPorActivo` | Horómetro a usar | Combo por fila | No | `pac_activo_medidor` |

> **`pac_activo_medidor` es lo que hace posible un plan por horas sobre cuatro máquinas iguales.**
> Cada blower lleva su propio horómetro; las 500 h de CB01 no son las de CB02. Sin esta columna
> habría que crear cuatro planes idénticos y mantenerlos sincronizados a mano.

**Panel "Hitos"** — cada hito abre `HITO_EDITAR`:

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtHitoCodigo` | Código | Texto | Sí | Único en la versión. Ej. `H500` | `pmh_codigo` |
| `txtHitoNombre` | Nombre | Texto | Sí | Ej. "500 HRS" | `pmh_nombre` |
| `numOrden` | Orden | Numérico | Sí | ≥ 1 | `pmh_orden` |
| `btnProgramacion` | Recurrencia | **Abre el asistente de US-030** | Sí | — | `pmh_programacion` |
| `numValorMedidor` | Valor del medidor | Numérico | No | Ej. 500 | `pmh_valor_medidor` |
| `chkOverhaul` | Es overhaul | Switch | — | — | `pmh_es_overhaul` |
| `chkRequiereParada` | Requiere parada de máquina | Switch | — | — | `pmh_requiere_parada` |
| `numDuracion` | Duración estimada (min) | Numérico | No | > 0 | `pmh_duracion_estimada_minuto` |
| `ddlTipoOT` | Tipo de OT que genera | Combo | No | — | `pmh_orden_trabajo_tipo` |
| `ddlPrioridadOT` | Prioridad | Combo | No | — | `pmh_orden_trabajo_prioridad` |

**Panel "Actividades del hito"**:

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtActCodigo` | Código | Texto | Sí | Único en el hito | `paa_codigo` |
| `txtActNombre` | Nombre | Texto | Sí | Ej. "Cambio de filtro de aire" | `paa_nombre` |
| `numActOrden` | Orden | Numérico | Sí | ≥ 1 | `paa_orden` |
| `ddlProcedimiento` | Procedimiento | Combo de `Procedimiento` | No | — | `paa_procedimiento` |
| `txtActDescripcion` | Instrucción | Área de texto enriquecido | No | — | `paa_descripcion` |
| `numActDuracion` | Duración (min) | Numérico | No | — | `paa_duracion_estimada_minuto` |
| `chkObligatoria` | Obligatoria | Switch, por defecto sí | — | **Apagado = "a evaluar"** | `paa_obligatoria` |
| `chkRequierePermiso` | Requiere permiso de trabajo | Switch | — | — | `paa_requiere_permiso` |
| `ddlPermisoTipo` | Tipo de permiso | Combo, **obligatorio si el switch está encendido** | Condicional | — | `paa_permiso_trabajo_tipo` |
| `grdRepuestos` | Repuestos que consume | Grilla | No | Cantidad > 0 | `Plan_Actividad_Repuesto` |
| `grdEspecialidades` | Especialidades requeridas | Grilla | No | — | `Plan_Actividad_Especialidad` |
| `grdChecklists` | Checklists exigidos | Grilla con momento ANTES/DURANTE/DESPUÉS | No | — | `Plan_Actividad_Checklist` |

> **`paa_obligatoria = 0` modela literalmente la columna "a evaluar" del plan anual real de
> Hamburgo.** La actividad está escrita, pero el técnico decide en terreno si corresponde. Sin
> este switch habría que sacarla del plan, y con ella se perdería el hecho de que estaba prevista.

**Tablas:** `Plan_Mantenimiento`, `Plan_Mantenimiento_Version`, `Plan_Mantenimiento_Activo`, `Plan_Mantenimiento_Hito`, `Plan_Mantenimiento_Actividad`, `Plan_Actividad_Repuesto`, `Plan_Actividad_Especialidad`, `Plan_Actividad_Checklist`

---

#### US-041 · Publicar una versión del plan

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 8/7/7/5 · **WSJF 4,4** — MUST · **S6** |

```gherkin
Escenario: Publicar retira la anterior
  Dado un plan con la versión v1 publicada
    Y una versión v2 en borrador
  Cuando publico la v2
  Entonces la v1 pasa a RETIRADO con fecha y responsable
    Y la v2 pasa a PUBLICADO con fecha y responsable
    Y ambas cosas ocurren en la misma transacción

Escenario: No se publica un plan vacío
  Dado una versión sin hitos
  Cuando intento publicarla
  Entonces se rechaza con "No se puede publicar una versión sin hitos"

Escenario: No se publica sin activos
  Dado una versión sin activos asociados
  Cuando intento publicarla
  Entonces se rechaza con "No se puede publicar una versión sin activos asociados"

Escenario: Dos usuarios publican a la vez
  Dado que dos planificadores presionan Publicar en el mismo segundo
  Entonces uno publica
    Y el otro recibe "La versión ya no estaba en BORRADOR. Otro usuario la publicó o la retiró."
```

> **La carrera se decide en el `WHERE`, no en el código C#.** El `UPDATE` lleva
> `AND pmv_plan_version_estado = 1`, y si `@@ROWCOUNT = 0` se levanta el error. Sin eso, ambos
> usuarios verían "listo" y quedarían dos versiones publicadas del mismo plan.

**Procedimiento:** `UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR`

---

#### US-042 · Ver el calendario anual de mantenimiento · WEB · WSJF 2,6 — SHOULD · S6
#### US-043 · Duplicar un plan para otra máquina · WEB · WSJF 1,8 — COULD · S6
#### US-044 · Ver la bandeja de ocurrencias pendientes · WEB · WSJF 3,8 — MUST · S6

---

### EP-06 · Checklist dinámico

---

#### US-050 · Diseñar una plantilla de checklist

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 9/7/9/13 · **WSJF 1,9** — MUST · **S5** |

**Inputs — pantalla `CHECKLIST_DISEÑAR`, cabecera**

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `txtCodigo` | Código | Texto | Sí | `cpl_codigo` |
| `txtNombre` | Nombre | Texto | Sí | `cpl_nombre` |
| `ddlTipoUso` | Tipo de uso | Combo de `Checklist_Asignacion_Tipo` | No | `cpl_checklist_asignacion_tipo` |
| `ddlActivoTipo` | Para el tipo de activo | Combo | No | `cpl_activo_tipo` |

**Secciones** — agrupan ítems en pantalla:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `txtSeccionNombre` | Nombre de la sección | Texto | Sí | `cps_nombre` |
| `numSeccionOrden` | Orden | Arrastrar y soltar | Sí | `cps_orden` |

> **La sección existe por la pantalla del teléfono.** Veinte preguntas seguidas en una lista
> plana se llenan mal; agrupadas en "Motor", "Lubricación", "Seguridad" se llenan bien.

**Ítems** — el corazón del diseñador:

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `txtItemCodigo` | Código | Texto | Sí | Único en la versión | `cpi_codigo` |
| `txtItemTexto` | Pregunta | Texto | Sí | Máx. 500 | `cpi_texto` |
| `txtAyuda` | Texto de ayuda | Texto | No | — | `cpi_ayuda` |
| `ddlItemTipo` | Tipo de respuesta | Combo de `Checklist_Item_Tipo` | Sí | Sí/No, Numérico, Texto, Lista, Fecha, Foto | `cpi_checklist_item_tipo` |
| `chkObligatorio` | Obligatorio | Switch | — | Por defecto sí | `cpi_obligatorio` |
| `chkRequiereEvidencia` | Exige foto | Switch | — | — | `cpi_requiere_evidencia` |
| `ddlUnidad` | Unidad esperada | Combo, solo si tipo = Numérico | Condicional | — | `cpi_unidad_medida` |
| `chkGeneraMedicion` | **Alimenta la serie del activo** | Switch | — | — | `cpi_genera_medicion` |
| `ddlVariable` | Variable del activo | Combo, **obligatorio si el switch está encendido** | Condicional | — | `cpi_activo_variable` |

> **`cpi_genera_medicion` es el puente entre "el técnico anotó 78" y la serie histórica de
> temperatura.** Sin ese puente, el checklist y las mediciones son dos silos, y el modelo
> predictivo se queda sin la mitad de los datos que la planta ya recoge a diario. Es una casilla
> de verificación en el diseñador, y es una de las decisiones más rentables del sistema.

**Umbrales del ítem numérico** — panel `VALIDACION_EDITAR`:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `numMinimo` | Mínimo aceptable | Numérico | No | `civ_valor_minimo` |
| `numAdvertencia` | Umbral de advertencia | Numérico | No | `civ_valor_advertencia` |
| `numCritico` | Umbral crítico | Numérico | No | `civ_valor_critico` |
| `numMaximo` | Máximo aceptable | Numérico | No | `civ_valor_maximo` |
| `chkComentarioFueraRango` | Pedir comentario si sale del rango | Switch | — | `civ_requiere_comentario_fuera_rango` |
| `chkEvidenciaFueraRango` | Pedir foto si sale del rango | Switch | — | `civ_requiere_evidencia_fuera_rango` |
| `chkGeneraAlerta` | Generar alerta | Switch | — | `civ_genera_alerta` |
| `chkGeneraHallazgo` | Generar hallazgo | Switch | — | `civ_genera_hallazgo` |
| `txtMensaje` | Mensaje al técnico | Texto | No | `civ_mensaje` |

> **Los cuatro umbrales no son decoración.** Producen `cer_severidad`, y la severidad decide
> cuatro cosas distintas: si se pide comentario, si se exige foto, si nace un hallazgo y si nace
> una alerta. Sin umbrales, el checklist recoge números que nadie mira.

**Dependencias entre ítems** — panel `DEPENDENCIA_EDITAR`:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `ddlItemCondicion` | Si la respuesta de | Combo de ítems anteriores | Sí | `cid_item_condicion` |
| `ddlOperador` | es | Combo de `Operador_Comparacion` | Sí | `cid_operador_comparacion` |
| `txtValor` | el valor | Texto o combo según el tipo | Sí | `cid_valor_comparacion` |
| `ddlAccion` | entonces | Combo: MOSTRAR / OCULTAR / OBLIGAR | Sí | `cid_accion` |

---

#### US-051 · Publicar una versión de checklist · WEB · WSJF 4,4 — MUST · S5
#### US-052 · Ejecutar un checklist en terreno

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 10/9/8/13 · **WSJF 2,1** — MUST · **S5** |

**Inputs — pantalla `CHECKLIST_EJECUTAR` (app), por cada ítem según su tipo**

| Tipo de ítem | Control en la app | Columna BD |
|---|---|---|
| Sí / No | Dos botones grandes, verde y rojo | `cer_valor_booleano` |
| Numérico | Teclado numérico grande + **botón de dictado** + unidad visible | `cer_valor_numero` + `cer_unidad_medida` |
| Texto | Área de texto + **botón de dictado** | `cer_valor_texto` |
| Lista | Lista de opciones táctiles de `Checklist_Item_Opcion` | `Checklist_Respuesta_Opcion` |
| Fecha | Selector de fecha | `cer_valor_fecha` |
| Foto | Cámara, hasta 5 fotos | `Archivo_Vinculo` |

En todos los tipos, siempre disponibles: `btnComentario` (con dictado), `btnFoto`, `chkNoAplica`.

```gherkin
Escenario: Valor fuera de rango con foto obligatoria
  Dado un ítem "Temperatura del descanso" con crítico ≥ 80 y foto obligatoria fuera de rango
  Cuando ingreso 84
  Entonces el campo se marca en rojo con el mensaje configurado
    Y NO puedo avanzar hasta adjuntar una foto
    Y cer_severidad queda en CRITICO
    Y cer_fuera_rango queda en 1

Escenario: El valor alimenta la serie del activo
  Dado que el ítem tiene cpi_genera_medicion = 1
  Cuando registro 84 °C
  Entonces se inserta una fila en Activo_Medicion
    Y esa fila queda enlazada por amd_checklist_ejecucion_respuesta
    Y todo ocurre en la misma transacción

Escenario: Unidad distinta a la esperada
  Dado un ítem que espera bar y yo ingreso el valor en PSI
  Entonces se guarda cer_valor_numero = 87 con cer_unidad_medida = PSI
    Y también cer_valor_canonico = 6.0 con cer_unidad_canonica = bar
    Y la comparación contra el umbral se hace sobre el canónico
    Y la pantalla sigue mostrando 87 PSI, que es lo que el técnico escribió

Escenario: Ejecución sin señal
  Dado que estoy sin conexión
  Cuando completo el checklist entero
  Entonces todo queda en la base local con cej_offline_creado = 1
    Y los umbrales se evalúan localmente con la misma tabla que bajó en la sincronización
    Y al recuperar señal se sincroniza y el servidor recalcula la severidad
    Y si servidor y teléfono discrepan, se registra la discrepancia para revisión
```

> **El último criterio parece paranoia y no lo es.** Que el servidor recalcule lo que el teléfono
> ya calculó cuesta milisegundos, y es la única forma de detectar que una versión vieja de la app
> está evaluando con umbrales desactualizados. Sin esa comparación, el error queda escondido.

**Procedimiento:** `INS_CHECKLIST_EJECUCION_RESPUESTA` — una sola transacción que inserta la
respuesta, calcula el canónico, evalúa la validación, genera la medición si corresponde, genera
el hallazgo si corresponde y genera la alerta si corresponde.

---

#### US-053 · Revisar los hallazgos del checklist

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 9/8/7/5 · **WSJF 4,8** — MUST · **S5** |

```gherkin
Escenario: El hallazgo propone, no ordena
  Dado un hallazgo generado por un checklist fuera de rango
  Cuando lo abro desde la bandeja
  Entonces veo la respuesta que lo originó, el activo, la severidad y la foto
    Y tengo dos acciones: "Generar orden de trabajo" y "Descartar con motivo"
    Y mientras no elija ninguna, el hallazgo sigue en la bandeja

Escenario: Descartar exige motivo
  Cuando presiono "Descartar"
  Entonces se exige un motivo de al menos 10 caracteres
    Y queda registrado quién descartó y cuándo
```

> **Ni el hallazgo ni la alerta crean una OT automáticamente: proponen.** Un sistema que abre
> órdenes de trabajo por su cuenta genera ruido, y el ruido se ignora — con lo cual se pierden
> también las propuestas buenas. La bandeja creciendo es, además, un indicador útil: si crece,
> el problema no es del sistema, es que nadie está decidiendo.

**Vista:** `VW_CHECKLIST_HALLAZGO_PENDIENTE`

---

#### US-054 · Programar un checklist recurrente · WEB · WSJF 3,2 — SHOULD · S5
#### US-055 · Ver el historial de ejecuciones de un checklist · WEB · WSJF 2,4 — SHOULD · S9

---

### EP-07 · Órdenes de trabajo

---

#### US-060 · Crear una orden de trabajo correctiva

| | |
|---|---|
| **Como** | técnico, supervisor, jefe o planificador · **AMBAS** · V/U/H/E 10/9/10/8 · **WSJF 3,6** — MUST · **S4** |

> **"Al final todo termina siendo una OT."** Esa frase del planificador es la regla de diseño del
> módulo. **No existe una entidad `Solicitud_OT` separada**: lo que en otros sistemas es una
> solicitud, aquí es una OT en estado ABIERTA con `otr_usuario_solicitante` informado. Una tabla
> menos, un traspaso menos, y ningún momento en que el trabajo "todavía no existe".

**Inputs — pantalla `OT_CREAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `lblCorrelativo` | N° | Solo lectura, se asigna al guardar | — | Único por cliente | `otr_correlativo` |
| `txtTitulo` | Título | Texto | Sí | Máx. 200 | `otr_titulo` |
| `ddlInstalacion` | Planta | Combo | Sí | — | `otr_cliente_instalacion` |
| `ddlArea` | Área | Combo en cascada | No | — | `otr_instalacion_area` |
| `ddlActivo` | Activo | Combo con buscador **+ botón escanear QR** | No | — | `otr_activo` |
| `ddlComponente` | Componente | Combo en cascada del activo | No | — | `otr_activo_componente` |
| `ddlTipo` | Tipo | Combo: PREVENTIVA / CORRECTIVA / PREDICTIVA | Sí | — | `otr_orden_trabajo_tipo` |
| `ddlEstrategia` | Estrategia | Combo: RUTINARIO / PROGRAMADO / EMERGENCIA / INSPECCIÓN / OVERHAUL / MEJORA | Sí | — | `otr_orden_trabajo_estrategia` |
| `ddlPrioridad` | Prioridad | Combo: BAJA / MEDIA / ALTA / CRÍTICA | Sí | — | `otr_orden_trabajo_prioridad` |
| `ddlSolicitante` | Solicitado por | Combo de usuarios | No | — | `otr_usuario_solicitante` |
| `txtNumeroSolicitud` | N° de solicitud | Texto | No | — | `otr_numero_solicitud` |
| `dtpFechaEvento` | Fecha del evento | Fecha-hora | No | — | `otr_fecha_evento_utc` |
| `txtDescripcion` | Descripción | Área de texto **+ dictado** | No | — | `otr_descripcion` |
| `ddlCentroCosto` | Centro de costo | Combo | No | — | `otr_centro_costo` |
| `chkRequierePermiso` | Requiere permiso de trabajo | Switch | — | — | `otr_requiere_permiso` |
| `chkRegistroPosterior` | **Es un registro posterior** | Switch | — | Ver criterio abajo | `otr_registro_posterior` |

```gherkin
Escenario: El técnico puede abrir, pero no cerrar
  Dado que mi perfil es Técnico de mantenimiento
  Cuando creo una OT correctiva
  Entonces se crea en estado ABIERTA
    Y el botón "Cerrar OT" no aparece para mí en ningún momento

Escenario: Registro posterior — la OT de ayer
  Dado que el trabajo ocurrió ayer a las 22:00 y lo registro hoy a las 09:00
  Cuando marco "Es un registro posterior" e indico la fecha de ocurrencia
  Entonces otr_fecha_ocurrencia queda en ayer 22:00
    Y otr_fecha_creacion queda en hoy 09:00
    Y otr_registro_posterior queda en 1
    Y ambas fechas se muestran en la ficha

Escenario: El correlativo no se repite
  Dado que dos usuarios crean una OT en el mismo milisegundo
  Entonces cada una recibe un correlativo distinto
    Y si hay colisión, el segundo reintenta contra UX_OTR_CLIENTE_CORRELATIVO
```

> **Sobre guardar las dos fechas.** La tentación es guardar solo la fecha de ocurrencia y que
> parezca que el sistema se usó en el momento. Guardar las dos es más honesto y además es útil:
> si el 60% de las OT son registros posteriores, el problema no es el sistema, es que la gente no
> lo está usando en terreno — y eso hay que poder verlo.

**Tablas:** `Orden_Trabajo`, `Orden_Trabajo_Estado_Historial`
**Función:** `FNC_ORDEN_TRABAJO_CORRELATIVO`
**Endpoint:** `POST /api/ot` — idempotente por `otr_uuid`

---

#### US-061 · Tomar una orden de trabajo

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 9/8/7/3 · **WSJF 8,0** — MUST · **S4** |

```gherkin
Escenario: Dos técnicos la toman a la vez
  Dado una OT en estado ABIERTA
  Cuando dos técnicos presionan "Tomar" en el mismo segundo
  Entonces uno la toma y pasa a EN EJECUCIÓN
    Y el otro recibe "La orden ya fue tomada por otro usuario"
    Y NO se crean dos asignaciones responsables

Escenario: El que la tomó suma a un compañero
  Dado que tomé la OT y soy el responsable
  Cuando agrego a otro técnico como apoyo
  Entonces se crea una segunda fila en Orden_Trabajo_Asignacion con ota_es_responsable = 0
    Y sigue habiendo un solo responsable
```

> **La carrera se decide en el `WHERE`, no en el código C#.** El `UPDATE` lleva
> `AND otr_orden_trabajo_estado = 2` y comprueba `@@ROWCOUNT`. Sin esto, ambos técnicos verían
> "listo" y llegarían los dos a la máquina.

**Procedimiento:** `UPD_ORDEN_TRABAJO_TOMAR`

---

#### US-062 · Ejecutar una OT en terreno

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 10/9/8/13 · **WSJF 2,1** — MUST · **S6** |

**Inputs — pantalla `OT_EJECUTAR` (app), organizada en pestañas**

**Pestaña Pasos** — un acordeón por `Orden_Trabajo_Paso`:

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `chkCompletado` | Completado | Switch grande | — | `otp_completado` |
| `chkNoAplica` | No aplica | Switch | — | `otp_no_aplica` |
| `txtResultado` | Resultado | Texto + dictado | No | `otp_resultado` |
| `btnFotoPaso` | Foto | Cámara | No | `Archivo_Vinculo` |

**Pestaña Mano de obra** — una fila por bloque de trabajo:

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `dtpInicio` | Desde | Fecha-hora | Sí | — | `omo_fecha_inicio_utc` |
| `dtpFin` | Hasta | Fecha-hora | No | ≥ inicio | `omo_fecha_fin_utc` |
| `numMinutos` | Minutos | Numérico, se calcula solo | Sí | > 0 | `omo_minuto` |
| `ddlEspecialidad` | Especialidad | Combo | No | — | `omo_especialidad` |
| `chkHoraExtra` | Hora extra | Switch | — | — | `omo_es_hora_extra` |

**Pestaña Repuestos** — ver US-090.
**Pestaña Evidencias** — cámara y galería.
**Pestaña Observaciones** — texto libre con dictado; alimenta `Bitacora`.

**Acción final:** `btnFinalizar` → la OT pasa a **EN ESPERA DE CIERRE**, no a CERRADA.

```gherkin
Escenario: El técnico finaliza, no cierra
  Cuando presiono "Finalizar trabajo"
  Entonces la OT pasa a EN ESPERA DE CIERRE
    Y aparece en la bandeja del planificador
    Y yo ya no puedo modificarla
```

**Procedimiento:** `UPD_ORDEN_TRABAJO_FINALIZAR`

---

#### US-063 · Cerrar una orden de trabajo

| | |
|---|---|
| **Como** | planificador, supervisor o jefe · **WEB** · V/U/H/E 9/8/6/5 · **WSJF 4,6** — MUST · **S7** |

**Inputs — modal `OT_CERRAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlMotivoCierre` | Motivo de cierre | Combo de `Orden_Trabajo_Cierre_Motivo` | Sí | — | `otr_cierre_motivo` |
| `txtResultado` | Trabajo realizado | Área de texto | Sí | Mín. 20 caracteres | `otr_resultado` |
| `numMinutoParada` | Tiempo de paro del activo (min) | Numérico | No | ≥ 0 | `otr_minuto_parada_activo` |
| `ddlEstadoActivo` | Estado en que queda el activo | Combo de `Activo_Estado` | No | — | `Activo_Estado_Historial` |
| `txtObservacionCierre` | Observación | Área de texto | No | — | `otr_notas` |

```gherkin
Escenario: El técnico no puede cerrar
  Dado que mi perfil es Técnico de mantenimiento
  Cuando invoco POST /api/ot/{id}/cerrar
  Entonces recibo 403 con "Su perfil no tiene la facultad de cerrar órdenes de trabajo"

Escenario: Anular es cerrar con motivo
  Dado una OT creada por error
  Cuando la cierro con motivo "ANULADA POR ERROR"
  Entonces la OT queda en estado CERRADA
    Y el correlativo NO se pierde
    Y la OT sigue siendo consultable y auditable
```

> **Por qué ANULADA no es un estado.** Un correlativo que desaparece de la secuencia genera la
> pregunta "¿qué pasó con la 23.075?" cada vez que alguien audita. Cerrarla con motivo conserva
> la secuencia completa y deja el motivo escrito.
>
> Y por eso hay **cuatro estados, no nueve**: `ABIERTA → EN EJECUCIÓN → EN ESPERA DE CIERRE →
> CERRADA`. Se eliminaron ASIGNADA y VALIDADA porque son **derivables** — hay asignación si
> existe fila en `Orden_Trabajo_Asignacion`, hay validación si existe fila en
> `Orden_Trabajo_Validacion`. Un estado que se puede calcular no es un estado: es una consulta
> que alguien duplicó en una columna, y esa columna se desincroniza.

**Función:** `FNC_USUARIO_PUEDE_CERRAR_OT` · **Procedimiento:** `UPD_ORDEN_TRABAJO_CERRAR`

---

#### US-064 · Ver la bandeja "En espera de cierre"

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 8/7/5/2 · **WSJF 10,0** — MUST · **S7** |

> **El WSJF más alto del backlog, y por una buena razón.** Dos puntos de esfuerzo — es una grilla
> sobre una vista que ya existe — y el número que muestra es la medida directa del atraso del
> planificador. Contar esas filas es contar el trabajo terminado que todavía no está cerrado.

**Vista:** `VW_PLANIFICADOR_PENDIENTE_CIERRE` · **Índice:** `IX_OTR_ESPERA_CIERRE` (filtrado)

---

#### US-065 · Asignar una OT a un técnico, grupo o **empresa externa**

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 8/7/6/5 · **WSJF 4,2** — MUST · **S7** |

**Inputs — modal `OT_ASIGNAR`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `rdoTipoEjecutante` | Ejecuta | **Radio: Técnico / Grupo de trabajo / Empresa externa** | Sí | Exactamente uno | — |
| `ddlUsuario` | Técnico | Combo, visible si eligió Técnico | Condicional | — | `ota_usuario` |
| `ddlGrupo` | Grupo | Combo, visible si eligió Grupo | Condicional | — | `ota_grupo_trabajo` |
| `ddlProveedor` | Empresa | Combo de `Proveedor`, visible si eligió Externa | Condicional | — | `ota_proveedor` |
| `chkResponsable` | Es el responsable | Switch | — | Solo uno por OT | `ota_es_responsable` |
| `ddlRol` | Rol | Combo: EJECUTOR / APOYO / SUPERVISOR | No | — | `ota_rol_ejecucion` |

> **El ejecutante externo no es un `Usuario` de SIGMA.** Vixon no tiene cuenta en el sistema y no
> debería tenerla. Por eso `Orden_Trabajo_Asignacion` admite tres destinatarios con un `CHECK`
> que exige exactamente uno. Sin `ota_proveedor` habría que inventarle un usuario ficticio a cada
> contratista, y esos usuarios ficticios terminan contaminando los indicadores de dotación.

---

#### US-066 · Adjuntar el informe de una OT externa

| | |
|---|---|
| **Como** | jefe de mantenimiento · **WEB** · V/U/H/E 6/5/3/3 · **WSJF 4,7** — MUST · **S7** |

> El flujo de OT externas es **solo registro**: se adjunta el informe del tercero, se registran
> las horas y los montos, y hasta ahí. No se modela un flujo de aprobación con el contratista
> porque la planta no lo va a usar.

**Inputs — panel `OT_SERVICIO_EXTERNO`**

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlProveedor` | Empresa | Combo | Sí | — | `ots_proveedor` |
| `ddlTipoServicio` | Tipo | Combo: SERVICIO / ARRIENDO / MONTAJE / DESMONTAJE / HH / REPUESTO / FLETE | Sí | — | `ots_tipo` |
| `txtDescripcion` | Descripción | Texto | Sí | — | `ots_descripcion` |
| `numCantidad` | Cantidad | Numérico | No | — | `ots_cantidad` |
| `numMontoUnitario` | Valor unitario | Numérico | No | ≥ 0 | `ots_monto_unitario` |
| `numMonto` | Monto total | Numérico | Sí | ≥ 0 | `ots_monto` |
| `ddlMoneda` | Moneda | Combo: CLP / UF / USD | No | — | `ots_moneda` |
| `txtDocumento` | N° de OC o factura | Texto | No | — | `ots_documento_referencia` |
| `btnAdjuntar` | **Informe del trabajo** | Archivo PDF o foto | Sí | Máx. 10 MB | `Archivo_Vinculo` |

> **Por qué el monto en UF importa.** El informe de Vixon por la emergencia en Planta 2 cobra
> **2,4 UF por hora**. Nueve horas de esa emergencia cuestan más que un año completo del plan
> MEDIO de SIGMA. Poder sumar esos montos al cierre del año es, literalmente, el argumento
> comercial del producto — y no se puede sumar si el proveedor es texto libre y la moneda no está
> registrada.

---

#### US-067 · Registrar las tres firmas de la OT · WEB · WSJF 2,8 — SHOULD · S7
#### US-068 · Adjuntar evidencia de permiso de trabajo

| | |
|---|---|
| **Como** | técnico o jefe · **AMBAS** · V/U/H/E 5/4/2/3 · **WSJF 3,7** — SHOULD · **S7** |

> **Alcance deliberadamente mínimo.** SIGMA **no** gestiona la firma del prevencionista ni un
> flujo de aprobación. El permiso lo emite el área de prevención en su propio proceso; SIGMA
> guarda el número, el tipo, la vigencia y **la foto del documento firmado**. Nada más.
> Puede haber más de un permiso por OT.

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `ddlTipoPermiso` | Tipo de permiso | Combo de `Permiso_Trabajo_Tipo` | Sí | `ptr_permiso_trabajo_tipo` |
| `txtNumero` | N° de permiso | Texto | No | `ptr_numero` |
| `dtpVigenciaInicio` | Vigente desde | Fecha-hora | No | `ptr_fecha_vigencia_inicio_utc` |
| `dtpVigenciaFin` | Vigente hasta | Fecha-hora | No | `ptr_fecha_vigencia_fin_utc` |
| `btnEvidencia` | **Foto del permiso firmado** | Cámara o archivo | Sí | `ptr_archivo` |

---

### EP-08 · Terreno sin señal

---

#### US-070 · Sincronización descendente

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 9/9/10/13 · **WSJF 2,2** — MUST · **S2–S3** |

```gherkin
Escenario: Primera sincronización
  Dado que instalo la app e inicio sesión por primera vez
  Cuando presiono "Sincronizar"
  Entonces se descargan los catálogos, mis activos, mis OT abiertas
    Y las plantillas de checklist publicadas de mis activos
    Y se muestra el progreso por bloque

Escenario: Sincronización incremental
  Dado que ya sincronicé ayer
  Cuando vuelvo a sincronizar
  Entonces solo se descarga lo modificado desde la última marca
    Y la descarga tarda menos de 10 segundos en 4G
```

**Endpoint:** `GET /api/sincronizar/descendente?desde={utc}&instalacion={id}`

---

#### US-071 · Trabajar completamente sin señal

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 10/10/9/13 · **WSJF 2,2** — MUST · **S3–S6** |

```gherkin
Escenario: Un turno completo sin señal
  Dado que estoy sin conexión desde que entré a la planta
  Cuando escaneo QR, abro OT, ejecuto checklists, dicto observaciones y saco fotos
  Entonces todo funciona sin ningún mensaje de error de red
    Y un indicador permanente muestra "Sin conexión · N cambios pendientes"
```

> **Este es el diferenciador del producto y no es negociable.** La sala de blowers de Hamburgo no
> tiene señal. Un sistema que exige conexión para registrar trabajo es un sistema que se llena
> con datos tipeados al día siguiente desde la oficina — que es exactamente el problema que SIGMA
> viene a resolver.

---

#### US-072 · Sincronización ascendente sin duplicar

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 10/9/8/13 · **WSJF 2,1** — MUST · **S7** |

```gherkin
Escenario: La red se corta a la mitad de la subida
  Dado que tengo 12 cambios pendientes
  Cuando la red se corta después de subir 7
  Entonces al reintentar solo se suben los 5 restantes
    Y los 7 ya subidos NO se duplican, porque el servidor los reconoce por UUID

Escenario: Conflicto de edición
  Dado que edité una OT sin señal
    Y el planificador la modificó en la web mientras tanto
  Cuando sincronizo
  Entonces se muestra la comparación de ambas versiones campo por campo
    Y elijo cuál conservar
    Y la decisión queda registrada
```

> **Todas las tablas transaccionales del modelo llevan `<pfx>_uuid` con índice `UNIQUE`
> precisamente para esto.** Si el teléfono manda el mismo `POST` dos veces porque la red se cortó
> a medias, la segunda choca contra el índice en vez de crear un registro duplicado. Es una
> columna por tabla, y es la diferencia entre una sincronización confiable y una que produce
> trabajo fantasma.

---

#### US-073 · Registrar un componente descubierto en terreno

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 8/7/5/8 · **WSJF 2,5** — MUST · **S7** |

```gherkin
Escenario: El componente que no estaba en el sistema
  Dado que abro la máquina y encuentro un componente no registrado
  Cuando lo registro desde la app, sin señal
  Entonces se crea un Registro_Descubrimiento en estado PENDIENTE
    Y NO se crea todavía el Activo_Componente definitivo
    Y al sincronizar aparece en la bandeja del planificador para confirmar o fusionar

Escenario: Fusionar con uno existente
  Dado un descubrimiento que resulta ser un componente ya registrado con otro nombre
  Cuando el planificador elige "Fusionar con existente"
  Entonces se registra la fusión en Activo_Componente_Fusion
    Y las evidencias del descubrimiento quedan colgando del componente definitivo
```

> **Por qué no se crea el componente de inmediato.** Si cada técnico pudiera crear componentes
> directamente, en seis meses habría cuatro "rodamiento lado acople" con nombres distintos en la
> misma máquina, y el historial quedaría repartido entre los cuatro. El paso de confirmación es
> lo que mantiene el maestro limpio sin impedir que el técnico registre lo que vio.

---

#### US-074 · Ver mi bandeja de trabajo del día · APP · WSJF 4,0 — MUST · S4

---

### EP-09 · Voz e inclusión

---

#### US-080 · Dictar una observación

| | |
|---|---|
| **Como** | técnico con las manos ocupadas · **APP** · V/U/H/E 9/8/5/8 · **WSJF 2,8** — MUST · **S6** |

> **Todo el procesamiento de voz ocurre en el teléfono.** Nada de nube. Eso elimina el costo por
> minuto, elimina las cuotas, elimina la función que elegiría motor — y, lo más importante,
> **elimina una dependencia de red del camino sin señal**. Un dictado que necesitara consultar al
> servidor para decidir qué motor usar no funcionaría justamente donde más se necesita.

**Inputs — componente `DICTADO` (aparece junto a cada campo de texto)**

| Campo | Etiqueta | Control | Columna BD |
|---|---|---|---|
| `btnDictar` | Micrófono | Botón de mantener pulsado, con onda de audio en vivo | — |
| `lblTranscripcion` | Texto reconocido | Texto editable | `dvo_texto` |
| `btnConfirmar` | Confirmar | Botón grande | `dvo_confirmado` |
| `btnRepetir` | Repetir | Botón | — |
| `btnEscuchar` | Escuchar lo transcrito | Botón (texto a voz) | — |

```gherkin
Escenario: Dictar sin señal
  Dado que estoy sin conexión
  Cuando mantengo pulsado el micrófono y hablo
  Entonces la transcripción aparece en pantalla usando el motor del teléfono
    Y se registra Dictado_Voz con dvo_voz_motor = DISPOSITIVO

Escenario: El audio no se guarda
  Cuando confirmo la transcripción
  Entonces el audio se descarta del dispositivo
    Y solo persiste el texto
```

> **Por qué el audio se descarta.** Guardar el audio multiplicaría el almacenamiento por un
> factor grande a cambio de un beneficio que nadie pidió: nadie va a escuchar la grabación de una
> observación de hace ocho meses. El texto sí se lee. Y la confirmación ocurre **en el
> dispositivo, antes de descartar**, que es el momento en que el técnico todavía recuerda lo que
> quiso decir.

**Tablas:** `Dictado_Voz`, `Entrada_Modo`, `Voz_Motor`

---

#### US-081 · Escuchar el checklist en voz alta · APP · WSJF 2,0 — SHOULD · S6
#### US-082 · Configurar accesibilidad · APP · WSJF 1,6 — COULD · S6

---

### EP-10 · Evidencias y archivos

---

#### US-085 · Sacar y subir fotos desde terreno · APP · WSJF 3,3 — MUST · S7

```gherkin
Escenario: Subida por trozos con red intermitente
  Dado una foto de 4 MB y dos rayas de señal
  Cuando la subida falla al 60%
  Entonces al reintentar se retoma desde el 60%, no desde cero
    Y el progreso vive en Archivo_Carga
```

#### US-086 · Ver la galería de evidencias de una OT · AMBAS · WSJF 3,0 — SHOULD · S7
#### US-087 · Distinguir foto de referencia de foto de ejecución · AMBAS · WSJF 2,7 — SHOULD · S7

> **`avi_es_referencia` separa dos cosas que la interfaz no puede mezclar:** la imagen que puso el
> planificador para mostrar **cómo debe quedar** el trabajo, y la que tomó el técnico para
> documentar **cómo quedó**. Es la columna "IMAGEN DE REFERENCIA" de la matriz real de Hamburgo,
> que existe y está vacía porque hasta ahora no había dónde ponerla.

---

### EP-11 · SIGMA Intelligence

*Las seis historias de esta épica están especificadas en detalle en la **sección 5**, porque
requieren más que una tabla de inputs: requieren definir estados visuales, animación y sonido.*

| ID | Historia | Plataforma | WSJF | Sprint |
|---|---|---|---|---|
| **US-100** | Ver el panel SIGMA Intelligence en la portada | AMBAS | 3,4 — MUST | S10 |
| **US-101** | Recibir la alerta viva de una predicción crítica | AMBAS | 2,8 — MUST | S10 |
| **US-102** | Ver por qué el modelo predice lo que predice | AMBAS | 4,0 — MUST | S10 |
| **US-103** | Generar una OT desde una predicción | WEB | 4,5 — MUST | S10 |
| **US-104** | Registrar si la predicción acertó | WEB | 3,0 — MUST | S10 |
| **US-105** | Ver la salud del modelo | WEB | 1,4 — COULD | S10 |

---

### EP-12 · Repuestos y consumo

---

#### US-090 · Registrar el consumo de repuestos en una OT

| | |
|---|---|
| **Como** | técnico · **APP** · V/U/H/E 7/6/5/5 · **WSJF 3,6** — MUST · **S7** |

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlRepuesto` | Repuesto | Combo con buscador | Sí | — | `ore_repuesto` |
| `numCantidad` | Cantidad consumida | Numérico | Sí | > 0 | `ore_cantidad_consumida` |
| `ddlComponente` | Se instaló en | Combo de componentes del activo | No | — | `ore_activo_componente` |
| `numHorometroRetiro` | **Horómetro al retirar** | Numérico | **No — opcional** | ≥ 0 | `ore_horometro_retiro` |
| `numHorometroInstalacion` | **Horómetro al instalar** | Numérico | **No — opcional** | ≥ 0 | `ore_horometro_instalacion` |

> **Los dos horómetros son opcionales a propósito.** Se pidieron en terreno para poder calcular
> la vida útil real de una pieza, pero exigirlos bloquearía el registro cuando la máquina no
> tenga horómetro o el técnico no lo haya mirado. Opcionales, se llenan cuando se puede, y cuando
> están son el dato más valioso que existe para el modelo predictivo: *este rodamiento duró
> 8.412 horas en esta posición*.

---

#### US-091 · Definir stock mínimo y máximo de un repuesto

| | |
|---|---|
| **Como** | **bodeguero** · **WEB** · V/U/H/E 6/5/4/3 · **WSJF 5,0** — MUST · **S7** |

| Campo | Etiqueta | Control | Oblig. | Validación | Columna BD |
|---|---|---|:--:|---|---|
| `ddlRepuesto` | Repuesto | Combo | Sí | — | `rbs_repuesto` |
| `ddlBodega` | Bodega | Combo | Sí | — | `rbs_bodega` |
| `numMinimo` | Stock mínimo | Numérico | Sí | ≥ 0 | `rbs_stock_minimo` |
| `numMaximo` | Stock máximo | Numérico | Sí | ≥ mínimo | `rbs_stock_maximo` |
| `numPuntoPedido` | Punto de pedido | Numérico | No | Entre mínimo y máximo | `rbs_punto_pedido` |

> **El alcance del bodeguero es exactamente este.** No compra, no cotiza, no aprueba. Define los
> umbrales y entrega contra OT. Modelar un flujo de compras que la planta resuelve por otro
> canal sería construir una pantalla que nadie abriría.

```gherkin
Escenario: Alerta de stock
  Dado un repuesto con mínimo 4 y stock actual 5
  Cuando una OT consume 2 unidades
  Entonces el stock queda en 3
    Y se genera una Alerta de tipo STOCK MINIMO
    Y la alerta NO genera una orden de compra por sí sola
```

---

#### US-092 · Consultar el stock de un repuesto · AMBAS · WSJF 2,6 — SHOULD · S7
#### US-093 · Ver la vida útil histórica de un repuesto por posición · WEB · WSJF 1,7 — COULD · S9

---

### EP-13 · Indicadores y reportes

---

#### US-110 · Ver el tablero de indicadores

| | |
|---|---|
| **Como** | jefe de mantenimiento · **WEB** · V/U/H/E 8/6/4/8 · **WSJF 2,3** — SHOULD · **S9** |

**Los cuatro indicadores que se construyen** — y solo cuatro, porque cada uno necesita
verificarse contra la planta y verificar veinte no cabe en el calendario:

| Indicador | Cómo se calcula | Tabla de origen |
|---|---|---|
| **Cumplimiento del plan** | ocurrencias completadas ÷ ocurrencias programadas, **medido contra `pmo_fecha_programada_original_utc`** | `Plan_Mantenimiento_Ocurrencia` |
| **Disponibilidad por activo** | 1 − (minutos de indisponibilidad no planificada ÷ minutos del período) | `Activo_Indisponibilidad` |
| **MTBF** | tiempo total operativo ÷ número de fallas | `Falla`, `Activo_Indisponibilidad` |
| **Backlog de cierre** | OT en EN ESPERA DE CIERRE, y hace cuántos días | `Orden_Trabajo` |

**Filtros:** planta, área, activo, tipo de OT, rango de fechas.

#### US-111 · Exportar un reporte a Excel · WEB · WSJF 2,0 — SHOULD · S9
#### US-112 · Imprimir una OT en el formato de la planta · WEB · WSJF 2,5 — SHOULD · S9

---

### EP-14 · Suscripción y bloqueo

---

#### US-120 · Ver el estado de mi suscripción · WEB · WSJF 3,0 — MUST · S8
#### US-121 · Bloqueo por suscripción vencida

| | |
|---|---|
| **Como** | SIGMA · **AMBAS** · V/U/H/E 9/8/3/5 · **WSJF 4,0** — MUST · **S8** |

```gherkin
Escenario: Aviso antes del vencimiento
  Dado que faltan 15 días para el vencimiento
  Cuando cualquier usuario entra
  Entonces se muestra un aviso persistente con los días restantes
    Y el sistema funciona con normalidad

Escenario: Bloqueo al vencer
  Dado que la suscripción venció y pasó el período de gracia
  Cuando un usuario entra
  Entonces solo puede ver la pantalla de renovación
    Y los datos NO se borran ni se pierden
    Y la app en terreno permite terminar el trabajo ya sincronizado, pero no tomar trabajo nuevo
```

> **Que la app deje terminar lo empezado no es generosidad comercial: es evitar un problema de
> seguridad.** Un técnico a mitad de un trabajo en altura no puede quedarse sin poder registrar
> lo que hizo porque a la empresa se le venció una factura.

#### US-122 · Registrar el pago con comprobante · WEB · WSJF 2,8 — SHOULD · S8

---

### EP-15 · Bitácora

#### US-130 · Registrar una entrada de bitácora con voz · APP · WSJF 3,0 — SHOULD · S7
#### US-131 · Rectificar una entrada de bitácora · WEB · WSJF 1,8 — COULD · S7

> **La bitácora no se edita.** Si el turno de noche anotó "se sintió un golpe en el blower 2" y a
> la semana el blower 2 se rompe, lo que importa es que **eso** se escribió **esa** noche. Las
> correcciones van en `Bitacora_Rectificacion` y la interfaz muestra el texto original tachado
> con la rectificación al lado — nunca reemplaza el texto en silencio. Es el mismo principio del
> libro de novedades en papel, donde no se borra: se tarja y se anota al lado.

---

### EP-16 y EP-17 · No se construyen

| ID | Historia | Estado |
|---|---|---|
| US-140 | Administrar proveedores | **Modelado y documentado.** Tabla `Proveedor` creada, sin mantenedor |
| US-141 | Administrar procedimientos reutilizables | **Modelado y documentado.** `Procedimiento` + `Procedimiento_Paso` |
| US-150 | Importar la matriz de OT desde Excel | **Modelado y documentado.** `Importacion_Carga` + `_Celda`. La demo carga por script |

> **Lo que se entrega de estas tres es el modelo, el script y la justificación de diseño.** Para
> `Importacion_Carga_Celda`, por ejemplo, está documentado por qué el grano es la **celda** y no
> la fila: cargar la matriz real de Hamburgo produce ambigüedades por celda —una frecuencia
> escrita como "500 hrs / anual"— y rechazar la fila entera obligaría a volver a tipear el activo
> y la descripción, que venían perfectos.

---

## 5. SIGMA Intelligence

### 5.1 Qué es, y qué no es

**SIGMA Intelligence es el nombre del panel predictivo del producto.** No es un módulo aparte ni
una pantalla que haya que ir a buscar: es **lo primero que se ve al entrar**, tanto en la web como
en la app.

La decisión de ponerlo en la portada tiene una razón. Una predicción que vive en un reporte que
alguien abre los martes no cambia ninguna decisión. Una predicción que aparece cuando la persona
enciende el computador compite por su atención en el momento en que todavía puede hacer algo.

**Lo que SIGMA Intelligence no es:** no es un sistema que abra órdenes de trabajo por su cuenta.
Propone; una persona decide. Un sistema que actúa solo genera ruido, y el ruido se ignora — con lo
cual se pierden también las propuestas buenas.

> **La limitación que hay que decir en voz alta, y decirla primero.**
> No existe todavía historia con qué entrenar. El modelo predictivo necesita series de mediciones a
> lo largo del tiempo terminadas en fallas confirmadas, y esos datos no existen — la razón misma de
> construir SIGMA es empezar a capturarlos.
>
> Para el 15 de noviembre se entrena con **datos sintéticos generados a propósito**: curvas de
> degradación de vibración y temperatura que terminan en falla. Lo que se demuestra no es que el
> modelo acierte, sino que **el pipeline funciona de extremo a extremo**: dataset → entrenamiento →
> versión ONNX → inferencia dentro de la API → predicción → explicación → registro del resultado
> real para reentrenar.
>
> Eso es defendible y además es la verdad del ciclo de vida de cualquier sistema predictivo: **el
> primer año se recolecta, el segundo se predice.** Ya está escrito así en el modelo comercial,
> donde el plan FULL con predictivo se vende a partir del mes 12. La coherencia entre el modelo de
> negocio y la limitación técnica juega a favor.

### 5.2 Los cuatro niveles

El nivel lo calcula la vista `VW_SIGMA_INTELLIGENCE` y **decide todo lo demás**: el color, si se
anima y si suena.

| Nivel | Cuándo | Color | Animación | Sonido |
|---|---|---|---|---|
| **CRÍTICO** | `pre_probabilidad ≥ mpr_umbral_critico` (def. 0,80) **o** `pre_dia_restante ≤ 7` | Rojo | Anillo pulsante continuo, 2 s por ciclo | **Sí**, una vez |
| **ALTO** | `pre_probabilidad ≥ mpr_umbral_alerta` (def. 0,60) | Ámbar | Entrada con desvanecido, sin pulso permanente | No |
| **MEDIO** | `pre_dia_restante ≤ 30` | Azul | Entrada suave | No |
| **INFORMATIVO** | Todo lo demás | Gris | Ninguna | No |

**Un quinto estado que no es un nivel: SIN DATOS SUFICIENTES.** Cuando un activo no tiene
mediciones bastantes para que el modelo se pronuncie, la tarjeta lo dice explícitamente y muestra
qué falta: *"Faltan 47 lecturas de horómetro para que el modelo pueda predecir sobre CB03."*

> **Ese quinto estado es el que sostiene la credibilidad del panel el primer año.** Un panel vacío
> parece roto. Un panel que explica por qué está vacío, y qué hay que hacer para llenarlo, convierte
> la limitación en una instrucción — y de paso empuja a la planta a tomar las lecturas.

### 5.3 La tarjeta de predicción — anatomía

```
┌─────────────────────────────────────────────────────────────┐
│  ⬤ CRÍTICO                                    hace 2 horas  │  ← franja de nivel + frescura
│                                                             │
│   ╭───────╮   BLOWER AERZEN GM10S · CB01                    │
│   │  87%  │   Sala de blowers · Planta 2                    │  ← anillo animado con la probabilidad
│   ╰───────╯                                                 │
│                                                             │
│   Falla probable en  ▸ 6 días                               │  ← contador que anima al aparecer
│                                                             │
│   Por qué:                                                  │
│   · Temperatura del descanso +14% en 3 semanas              │  ← las 3 razones principales
│   · 8.740 h desde el último cambio de rodamiento            │     (razon_principal de la vista)
│   · Vibración fuera de rango en 2 de las últimas 3 rondas   │
│                                                             │
│   [ Generar orden de trabajo ]  [ Ver detalle ]  [ Descartar ]│
└─────────────────────────────────────────────────────────────┘
```

**Elementos y de dónde sale cada uno:**

| Elemento | Origen | Nota |
|---|---|---|
| Franja de nivel | `nivel` de `VW_SIGMA_INTELLIGENCE` | Color y comportamiento |
| Frescura | `pre_fecha_calculo_utc` | "hace 2 horas", no una fecha absoluta |
| Anillo con porcentaje | `pre_probabilidad` | Anillo SVG, `stroke-dasharray` animado |
| Nombre y código | `act_nombre`, `act_codigo` | |
| Ubicación | Área + planta | |
| Días restantes | `pre_dia_restante` | Contador que sube de 0 al valor en 800 ms |
| Razones | `razon_principal` (las 3 primeras de `Prediccion_Explicacion` por `pex_orden`) | |
| Botones | Según permisos del usuario | |

> **Sin las razones, la tarjeta no sirve.** "El blower CB01 va a fallar en 6 días" no mueve a nadie.
> "…porque la temperatura del descanso subió 14% en tres semanas y el horómetro pasó las 8.700 h sin
> cambio de rodamiento" hace que el planificador abra la OT. Por eso `Prediccion_Explicacion` no es
> opcional en la práctica: es la diferencia entre un número que se ignora y una decisión que se toma.

### 5.4 La animación

| Elemento | Comportamiento | Duración |
|---|---|---|
| **Anillo de probabilidad** | Se dibuja de 0% al valor, con easing `ease-out` | 900 ms al aparecer |
| **Pulso de nivel CRÍTICO** | Halo que crece y se desvanece alrededor del anillo | Ciclo de 2 s, continuo |
| **Contador de días** | Sube de 0 al valor final | 800 ms |
| **Entrada de la tarjeta** | Desliza 12 px hacia arriba + aparece | 400 ms, escalonado 80 ms entre tarjetas |
| **Minigráfico de tendencia** | La línea se dibuja de izquierda a derecha | 1.200 ms |
| **Actualización en vivo** | Al llegar una predicción nueva, entra desde arriba y empuja a las demás | 500 ms |

**Reglas que no se negocian:**

1. **`prefers-reduced-motion`.** Si el sistema operativo del usuario pide movimiento reducido, todas
   las animaciones se reemplazan por transiciones de opacidad de 150 ms. El pulso continuo se apaga
   por completo. Esto no es opcional: un pulso permanente en pantalla puede provocar molestia real
   en personas con sensibilidad vestibular o fotosensibilidad.
2. **El pulso solo en CRÍTICO.** Si todo pulsa, nada llama la atención.
3. **Nada se mueve más de una vez.** La entrada anima; después la tarjeta queda quieta salvo el
   pulso de nivel crítico.

### 5.5 La alerta sonora

**Cuándo suena:** solo cuando aparece una predicción de nivel **CRÍTICO** que el usuario **no ha
visto todavía**.

**Cómo se sabe que no la ha visto — sin inventar una tabla.** El endpoint devuelve
`esNueva: true` cuando `pre_fecha_calculo_utc > usu_ultimo_acceso` del usuario. Es un dato derivado,
consistente con la regla del modelo: *un estado derivable no es un estado*. No hace falta una tabla
`Prediccion_Vista` que habría que mantener y purgar.

**El sonido:**

| Atributo | Especificación | Por qué |
|---|---|---|
| Duración | 1,2 s | Suficiente para notarse, corto para no molestar |
| Forma | Dos tonos ascendentes, terminación suave | Se distingue de las notificaciones del sistema operativo |
| Carácter | **Advertencia atenta, no alarma de pánico** | Un sonido de emergencia usado a diario deja de significar emergencia |
| Volumen | 60% por defecto, ajustable, silenciable | |
| Repetición | **Una sola vez por predicción y por usuario** | Un sonido que se repite se silencia, y con él se silencian los que sí importaban |

**Reglas de implementación:**

1. **Web — la política de autoreproducción del navegador.** Chrome y Safari no permiten reproducir
   audio sin una interacción previa del usuario. La primera vez, la tarjeta muestra un botón
   **🔔 Activar alertas sonoras**; al pulsarlo se reproduce un tono de prueba y a partir de ahí el
   audio funciona en esa sesión. *Sin esta pasada explícita, el sonido simplemente no suena y nadie
   entiende por qué.*
2. **El sonido nunca es la única señal.** Siempre va acompañado de la tarjeta visible, del contador
   del menú y — en la app — de la vibración. Un usuario con audífonos puestos, con el volumen bajo o
   con pérdida auditiva tiene que recibir la misma información.
3. **App — notificación push.** Si la app está en segundo plano, la predicción crítica llega como
   notificación push de Android con el mismo sonido y con vibración corta. Al tocarla se abre
   directamente la tarjeta.
4. **Silencio nocturno.** Entre las 22:00 y las 07:00 hora local del cliente, la notificación llega
   pero **sin sonido**. La predicción de una falla en seis días no justifica despertar a nadie.
5. **Preferencia por usuario:** `Usuario_Accesibilidad` guarda `uac_alerta_sonora` y
   `uac_volumen_alerta`.

### 5.6 Dónde vive el panel

**WEB — portada (`INICIO`), es la pantalla por defecto tras el login:**

```
┌───────────────────────────────────────────────────────────────────────┐
│  SIGMA          Hamburgo S.A. · Planta Renca        🔔3   Bryan C. ▾ │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ◆ SIGMA INTELLIGENCE                     🔊 activo   ⟳ hace 12 min │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  [tarjeta CRÍTICO]   [tarjeta ALTO]   [tarjeta ALTO]     →      │ │  ← carrusel horizontal
│  └─────────────────────────────────────────────────────────────────┘ │
│   3 predicciones activas · 1 crítica            Ver todas (12) →     │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│  MI TRABAJO DE HOY                        │  ESTADO DE LA PLANTA      │
│  ┌──────────┬──────────┬──────────┐       │  ┌────────────────────┐   │
│  │ 4 OT     │ 7 en     │ 2        │       │  │  Cumplimiento 87%  │   │
│  │ abiertas │ espera   │hallazgos │       │  │  Disponibilidad 94%│   │
│  │          │ de cierre│pendientes│       │  │  MTBF     412 h    │   │
│  └──────────┴──────────┴──────────┘       │  └────────────────────┘   │
└───────────────────────────────────────────────────────────────────────┘
```

**APP — pantalla de inicio, primer bloque, sobre la bandeja de trabajo:**

```
┌───────────────────────────┐
│  ☰   SIGMA          🔔3  │
├───────────────────────────┤
│ ◆ SIGMA INTELLIGENCE      │
│ ┌───────────────────────┐ │
│ │ ⬤ CRÍTICO             │ │
│ │  ╭────╮ CB01 Blower 1 │ │  ← tarjeta compacta, deslizable
│ │  │87% │ Falla en 6 d  │ │
│ │  ╰────╯               │ │
│ │  Temp. descanso +14%  │ │
│ │  [ Ver ]  [ Generar ] │ │
│ └───────────────────────┘ │
│         ● ○ ○             │
├───────────────────────────┤
│ MI TRABAJO                │
│  ▸ OT 23074 · CB02        │
│  ▸ Ronda diaria blowers   │
├───────────────────────────┤
│ [Escanear QR]  (flotante) │
└───────────────────────────┘
```

> **En la app el panel es compacto y deslizable, no una lista.** El técnico entra a la app para
> hacer su trabajo, no para revisar predicciones. Una lista larga de tarjetas lo obligaría a
> desplazarse cada vez para llegar a lo suyo — y a los tres días dejaría de mirarlas. Una tarjeta
> visible con las demás a un deslizamiento de distancia respeta a qué vino.

### 5.7 Las historias en detalle

#### US-100 · Ver el panel SIGMA Intelligence en la portada

| | |
|---|---|
| **Como** | planificador o jefe de mantenimiento |
| **Quiero** | ver las predicciones activas al entrar, sin buscarlas |
| **Para** | enterarme de un problema mientras todavía puedo evitarlo |
| **Plataforma** | AMBAS · V/U/H/E 9/7/7/7 · **WSJF 3,3** — MUST · **S10** |

```gherkin
Escenario: Hay predicciones activas
  Cuando entro a la portada
  Entonces veo las predicciones vigentes ordenadas por nivel y luego por fecha
    Y las críticas aparecen primero
    Y cada tarjeta muestra activo, probabilidad, días restantes y tres razones

Escenario: No hay predicciones
  Cuando entro y no hay ninguna predicción vigente
  Entonces el panel muestra "Sin predicciones activas. El modelo está vigilando 34 activos."
    Y NO se muestra un espacio vacío ni un mensaje de error

Escenario: Datos insuficientes
  Dado un activo sin mediciones suficientes
  Entonces la tarjeta dice qué falta, en términos concretos y accionables
    Ejemplo: "Faltan 47 lecturas de horómetro para predecir sobre CB03"

Escenario: Multicliente
  Dado que soy usuario de dos clientes
  Entonces solo veo las predicciones del cliente con el que inicié sesión
```

**Vista:** `VW_SIGMA_INTELLIGENCE`
**Endpoint:** `GET /api/intelligence/resumen?instalacion={id}` →
```json
{
  "resumen": { "total": 12, "critico": 1, "alto": 2, "medio": 4, "vigilando": 34 },
  "predicciones": [{
    "preId": 8841, "uuid": "…", "nivel": "CRITICO", "esNueva": true,
    "activo": { "id": 112, "codigo": "CB01", "nombre": "Blower Aerzen GM10S",
                "area": "Sala de blowers", "planta": "Planta 2" },
    "probabilidad": 0.87, "diaRestante": 6, "confianza": 0.74,
    "fechaCalculoUtc": "2026-11-10T13:02:00Z",
    "razones": ["Temperatura del descanso +14% en 3 semanas",
                "8.740 h desde el último cambio de rodamiento",
                "Vibración fuera de rango en 2 de las últimas 3 rondas"],
    "tieneOrdenTrabajo": false, "fueRevisada": false,
    "modelo": { "nombre": "Falla de rodamiento — blowers", "version": 3 }
  }]
}
```

---

#### US-101 · Recibir la alerta viva de una predicción crítica

| | |
|---|---|
| **Como** | planificador · **AMBAS** · V/U/H/E 8/8/4/7 · **WSJF 2,9** — MUST · **S10** |

```gherkin
Escenario: Primera vez en la web
  Dado que nunca activé las alertas sonoras en este navegador
  Cuando entra una predicción crítica
  Entonces la tarjeta aparece con animación y se muestra "🔔 Activar alertas sonoras"
    Y NO se intenta reproducir audio, porque el navegador lo bloquearía

Escenario: Alertas activadas
  Dado que ya activé el sonido en esta sesión
  Cuando llega una predicción crítica nueva
  Entonces la tarjeta entra animada desde arriba
    Y suena la alerta una sola vez
    Y el contador del menú sube

Escenario: La misma predicción no vuelve a sonar
  Dado que ya vi una predicción crítica
  Cuando refresco la página
  Entonces la tarjeta se muestra sin animación de entrada y sin sonido

Escenario: Movimiento reducido
  Dado que mi sistema pide prefers-reduced-motion
  Entonces no hay pulso ni deslizamiento, solo una transición de opacidad
    Y el sonido sigue funcionando si está activado

Escenario: Silencio nocturno
  Dado que son las 23:40 hora de la planta
  Cuando llega una predicción crítica a la app
  Entonces la notificación llega sin sonido
    Y al abrir la app por la mañana la tarjeta está marcada como nueva
```

**Endpoint:** `GET /api/intelligence/nuevas?desde={utc}` — la web consulta cada 60 s;
la app recibe push por FCM.

---

#### US-102 · Ver por qué el modelo predice lo que predice

| | |
|---|---|
| **Como** | jefe de mantenimiento escéptico · **AMBAS** · V/U/H/E 9/7/4/5 · **WSJF 4,0** — MUST · **S10** |

**Pantalla `PREDICCION_DETALLE`:**

| Bloque | Contenido | Origen |
|---|---|---|
| Cabecera | Activo, nivel, probabilidad, días restantes, fecha del cálculo | `Prediccion` |
| **Todas las razones** | Lista completa ordenada por contribución, con barra proporcional y flecha ↑/↓ | `Prediccion_Explicacion` |
| Valores de entrada | Tabla con cada característica, su valor observado y su valor de referencia | `Prediccion_Caracteristica` + `Caracteristica_Modelo` |
| Serie histórica | Gráfico de la variable que más contribuyó, con la banda normal sombreada | `Activo_Medicion` |
| Modelo | Nombre, versión, algoritmo y métricas de esa versión | `Modelo_Predictivo_Version` |
| Intervalo | "Entre 4 y 9 días, con 74% de confianza" | `pre_intervalo_inferior/superior` |

```gherkin
Escenario: La pregunta incómoda
  Dado que el jefe pregunta "¿y de dónde sacaste eso?"
  Cuando abro el detalle
  Entonces veo cada característica con su valor exacto
    Y veo qué versión del modelo lo calculó y con qué métricas
    Y puedo reconstruir el razonamiento completo sin salir de la pantalla
```

> **Mostrar el intervalo y no solo el número es una decisión de honestidad que además protege al
> producto.** "Falla en 6 días" invita a que el 7 alguien diga que el modelo se equivocó. "Entre 4 y
> 9 días, con 74% de confianza" es lo que el modelo efectivamente sabe, y aguanta el escrutinio.

---

#### US-103 · Generar una orden de trabajo desde una predicción

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 9/8/5/5 · **WSJF 4,4** — MUST · **S10** |

**Inputs — modal `PREDICCION_GENERAR_OT`** (precargado con lo que la predicción ya sabe):

| Campo | Etiqueta | Precargado con | Editable | Columna BD |
|---|---|---|:--:|---|
| `txtTitulo` | Título | "Mantenimiento predictivo — {activo}" | Sí | `otr_titulo` |
| `ddlTipo` | Tipo | **PREDICTIVA**, fijo | No | `otr_orden_trabajo_tipo` |
| `ddlOrigen` | Origen | **PREDICCIÓN**, fijo | No | `otr_orden_trabajo_origen` |
| `ddlPrioridad` | Prioridad | ALTA si crítico, MEDIA si alto | Sí | `otr_orden_trabajo_prioridad` |
| `dtpProgramada` | Fecha programada | `pre_fecha_evento_estimada_utc` − 3 días | Sí | `otr_fecha_programada_utc` |
| `txtDescripcion` | Descripción | **Las razones de la predicción, ya redactadas** | Sí | `otr_descripcion` |
| `ddlActivo` | Activo | El de la predicción | No | `otr_activo` |

```gherkin
Escenario: Generar la OT
  Cuando confirmo la generación
  Entonces se crea la OT con otr_orden_trabajo_origen = PREDICCION
    Y otr_prediccion apunta a la predicción
    Y pre_orden_trabajo apunta a la OT
    Y la tarjeta pasa a mostrar "OT 23081 generada" en vez de los botones
    Y la tarjeta deja de sonar y de pulsar

Escenario: Descartar con motivo
  Cuando presiono "Descartar"
  Entonces se exige un motivo de al menos 10 caracteres
    Y la predicción sale del panel
    Y sigue contando para las métricas del modelo
```

> **Que la descripción venga precargada con las razones es lo que hace que esto se use.** El
> planificador que tiene que redactar de cero la justificación de una OT preventiva termina
> escribiendo "mantenimiento predictivo" y nada más — y el técnico que la recibe no sabe qué mirar.

---

#### US-104 · Registrar si la predicción acertó

| | |
|---|---|
| **Como** | planificador · **WEB** · V/U/H/E 7/6/5/6 · **WSJF 3,0** — MUST · **S10** |

**Inputs — modal `PREDICCION_EVALUAR`**

| Campo | Etiqueta | Control | Oblig. | Columna BD |
|---|---|---|:--:|---|
| `rdoOcurrio` | ¿Ocurrió el evento previsto? | Radio Sí / No | Sí | `prs_ocurrio` |
| `dtpFechaReal` | ¿Cuándo? | Fecha, si respondió Sí | Condicional | `prs_fecha_evento_real_utc` |
| `ddlFalla` | Falla registrada | Combo, si respondió Sí | No | `prs_falla` |
| `chkMantenimientoPrevio` | **¿Se intervino la máquina antes de la fecha prevista?** | Switch | Sí | `prs_mantenimiento_previo` |
| `txtObservacion` | Observación | Texto | No | `prs_observacion` |

> **`prs_mantenimiento_previo` es la columna más importante de todo el bloque de machine learning.**
> Sin ella es imposible distinguir dos casos que en los datos se ven idénticos:
>
> - *(a)* el modelo se equivocó: dijo que fallaría y no falló
> - *(b)* el modelo **acertó**: dijo que fallaría, alguien intervino, y por eso no falló
>
> Contar *(b)* como error entrena al modelo a **no avisar**. Es el error clásico del mantenimiento
> predictivo — el sistema se vuelve más silencioso justamente porque estaba funcionando — y aquí
> está modelado desde el principio, con su propia clasificación: `ACIERTO CON INTERVENCIÓN`.

```gherkin
Escenario: Acierto con intervención
  Dado una predicción de falla en 6 días
    Y una OT preventiva ejecutada al día 4
    Y ninguna falla ocurrida
  Cuando registro "no ocurrió" con "sí se intervino antes"
  Entonces prs_clasificacion queda en ACIERTO CON INTERVENCION
    Y NO cuenta como falso positivo en las métricas del modelo
```

---

#### US-105 · Ver la salud del modelo

| | |
|---|---|
| **Como** | administrador SIGMA · **WEB** · V/U/H/E 5/3/2/7 · **WSJF 1,4** — COULD · **S10** |

Muestra por versión y por mes: matriz de confusión con la columna extra de acierto-con-intervención,
métrica actual contra la de referencia, y deriva de datos. Si la deriva sube y la métrica baja, hay
que reentrenar.

> **Un modelo entrenado en 2026 con datos de 2025 se degrada solo:** la planta cambia de proveedor de
> aceite, se reemplaza un blower, se modifica el turno. Sin medir esa deriva, nadie se entera hasta
> que alguien comenta al pasar que "las predicciones ya no achuntan" — y para entonces se perdió la
> confianza, que es más difícil de recuperar que la precisión.

**Tabla:** `Modelo_Monitoreo`

---

## 6. Inventario de pantallas

Esto es lo que consume el diseño. Cada pantalla trae su ruta, quién la usa y las historias que la
justifican.

### 6.1 Web — 32 pantallas

| # | Pantalla | Ruta | Rol | Historias |
|---|---|---|---|---|
| W-01 | Login | `/login` | Todos | US-001 |
| W-02 | Selector de cliente | `/cliente` | Multi-cliente | US-001 |
| W-03 | **Portada con SIGMA Intelligence** | `/` | Todos | US-100, US-110 |
| W-04 | Detalle de predicción | `/intelligence/{id}` | Planif., Jefe | US-102, US-103, US-104 |
| W-05 | Todas las predicciones | `/intelligence` | Planif., Jefe | US-100 |
| W-06 | Salud del modelo | `/intelligence/salud` | Admin SIGMA | US-105 |
| W-07 | Lista de activos | `/activos` | Todos | US-014 |
| W-08 | Ficha de activo | `/activos/{id}` | Todos | US-011, US-014 |
| W-09 | Editar activo | `/activos/{id}/editar` | Planif. | US-011, US-012, US-020 |
| W-10 | Posiciones funcionales | `/posiciones` | Planif. | US-010 |
| W-11 | Editar posición + QR | `/posiciones/{id}` | Planif. | US-010 |
| W-12 | Tipos y modelos de activo | `/activos/tipos` | Planif. | US-016 |
| W-13 | Lista de OT | `/ot` | Todos | US-064 |
| W-14 | Ficha de OT | `/ot/{id}` | Todos | US-063, US-065, US-066, US-067 |
| W-15 | Crear OT | `/ot/nueva` | Todos | US-060 |
| W-16 | **Bandeja de cierre** | `/ot/espera-cierre` | Planif., Sup., Jefe | US-064 |
| W-17 | Imprimir OT | `/ot/{id}/imprimir` | Todos | US-112 |
| W-18 | Lista de planes | `/planes` | Planif. | US-040 |
| W-19 | Diseñar plan (hitos y actividades) | `/planes/{id}/editar` | Planif. | US-040, US-041 |
| W-20 | Calendario anual | `/planes/calendario` | Planif., Jefe | US-042 |
| W-21 | Ocurrencias pendientes | `/planes/ocurrencias` | Planif. | US-044, US-033 |
| W-22 | Lista de checklists | `/checklists` | Planif. | US-050 |
| W-23 | **Diseñador de checklist** | `/checklists/{id}/diseñar` | Planif. | US-050, US-051 |
| W-24 | Bandeja de hallazgos | `/hallazgos` | Planif. | US-053 |
| W-25 | Historial de ejecuciones | `/checklists/ejecuciones` | Planif., Jefe | US-055 |
| W-26 | Bandeja de alertas | `/alertas` | Planif. | EP-13 |
| W-27 | Repuestos y stock | `/repuestos` | Bodeguero | US-091, US-092 |
| W-28 | Tablero de indicadores | `/indicadores` | Jefe | US-110 |
| W-29 | Usuarios | `/admin/usuarios` | Admin cliente | US-003 |
| W-30 | Plantas y áreas | `/admin/areas` | Admin cliente | US-004 |
| W-31 | Centros de costo | `/admin/centros-costo` | Admin cliente | US-005 |
| W-32 | Suscripción y renovación | `/suscripcion` | Admin cliente | US-120, US-121, US-122 |

### 6.2 App Flutter — 16 pantallas

| # | Pantalla | Rol | Historias | **Funciona sin señal** |
|---|---|---|---|:--:|
| A-01 | Login | Todos | US-001 | Sí, con credenciales guardadas |
| A-02 | **Inicio con SIGMA Intelligence** | Todos | US-100, US-074 | Sí, con lo sincronizado |
| A-03 | Detalle de predicción | Todos | US-102 | Sí |
| A-04 | Mi bandeja de trabajo | Técnico | US-074 | **Sí** |
| A-05 | Escáner QR | Técnico | US-013 | **Sí** |
| A-06 | Ficha de activo | Técnico | US-013, US-014 | **Sí** |
| A-07 | Componentes del activo | Técnico | US-012 | **Sí** |
| A-08 | Registrar lectura de medidor | Técnico | US-021 | **Sí** |
| A-09 | Ficha de OT | Técnico | US-061 | **Sí** |
| A-10 | **Ejecutar OT** (pasos, mano de obra, repuestos) | Técnico | US-062, US-090 | **Sí** |
| A-11 | **Ejecutar checklist** | Técnico | US-052 | **Sí** |
| A-12 | Cámara y evidencias | Técnico | US-085 | **Sí**, cola de subida |
| A-13 | **Dictado por voz** | Técnico | US-080, US-081 | **Sí**, motor del teléfono |
| A-14 | Registrar componente descubierto | Técnico | US-073 | **Sí** |
| A-15 | Bitácora de turno | Técnico | US-130 | **Sí** |
| A-16 | Sincronización y estado | Todos | US-070, US-072 | Muestra pendientes |

### 6.3 Mapa de navegación — web

```
LOGIN ──▶ [selector de cliente] ──▶ PORTADA (SIGMA Intelligence + mi trabajo + estado)
                                        │
        ┌───────────────┬───────────────┼───────────────┬──────────────┐
        ▼               ▼               ▼               ▼              ▼
   INTELLIGENCE      ACTIVOS      ÓRDENES DE      PLANES Y        ADMINISTRACIÓN
        │               │          TRABAJO        CHECKLISTS            │
    ┌───┴───┐       ┌───┴───┐      ┌───┴───┐      ┌───┴────┐      ┌────┴────┐
  detalle  salud   ficha  posic.  bandeja ficha  diseñador  cal.  usuarios  suscrip.
    │                                │             │
    └── genera OT ───────────────────┘             └── publica versión
```

### 6.4 Mapa de navegación — app

```
LOGIN ──▶ INICIO (SIGMA Intelligence · mi trabajo · botón QR flotante)
              │
    ┌─────────┼─────────────┬──────────────┐
    ▼         ▼             ▼              ▼
  ESCANEAR  BANDEJA     PREDICCIÓN    SINCRONIZAR
    QR         │
    │       ┌──┴───┐
    ▼       ▼      ▼
  ACTIVO   OT   CHECKLIST
    │       │      │
    │       ▼      ▼
    │   EJECUTAR OT / CHECKLIST
    │       │
    │   ┌───┼────┬────────┬──────────┐
    │   ▼   ▼    ▼        ▼          ▼
    │ pasos MO repuestos cámara   DICTADO
    ▼
 LECTURA · COMPONENTES · COMPONENTE DESCUBIERTO
```

---

## 7. El backlog repartido en sprints

| Sprint | Fechas | Pista A · Base y web | Pista B · API y app | Pts |
|:--:|---|---|---|:--:|
| **S0** | 19–23 ago | Contratar Premium. Ejecutar los 21 scripts **dos veces** | Cuenta Google Play. Reclutar 15 testers. Desplegar web y API | — |
| **S1** | 24–30 ago | US-001 · US-002 · US-003 · US-004 · US-005 | Esqueleto API con validación de KEY. Esqueleto Flutter | 34 |
| **S2** | 31 ago–6 sep | US-010 · US-011 · US-012 | US-070 · endpoints de catálogos y activos | 34 |
| **S3** | 7–13 sep | US-014 · US-015 · US-016 · US-020 | US-013 · US-021 · US-071 (base) | 32 |
| **S4** | 14–20 sep | US-030 · US-031 · US-032 · US-033 | US-060 · US-061 · US-074 | 36 |
| **S5** | 21–27 sep | US-050 · US-051 · US-053 · US-054 | US-052 (ejecutar checklist en la app) | 38 |
| **S6** | 28 sep–4 oct | US-040 · US-041 · US-044 | US-062 · US-080 · US-081 | 40 |
| **S7** | 5–11 oct | US-063 · US-064 · US-065 · US-066 · US-091 | US-072 · US-073 · US-085 · US-090 · US-130 | 44 |
| **S8** | 12–18 oct | US-120 · US-121 · US-122 | ⚠️ **15 oct: APK a Google Play** | 21 |
| **S9** | 19–25 oct | US-110 · US-111 · US-112 · US-055 | ⚠️ **22 oct: arranca la prueba cerrada** | 24 |
| **S10** | 26 oct–1 nov | US-103 · US-104 · US-105 | **US-100 · US-101 · US-102** · ONNX en la API | 42 |
| **S11** | 2–8 nov | Datos de demo de Hamburgo. Ensayo cronometrado | ⚠️ **5 nov: solicitar acceso a producción** | 13 |
| **S12** | 9–15 nov | **Margen.** Ensayos finales | Revisión de Google. Margen para un rechazo | — |

**Los tres hitos que no se mueven.** Si uno se pasa, hay que cambiar el plan **ese mismo día**, no
esperar a ver si se recupera:

1. **15 de octubre — APK a Play.** Si no está, no hay publicación en producción.
2. **22 de octubre — arranca la prueba cerrada.** Última fecha compatible con los 14 días que exige
   Google.
3. **5 de noviembre — solicitud de producción.** Con menos margen, un rechazo mata la fecha.

> **La única holgura real del plan es la semana 12, y ya está comprometida con la revisión de
> Google.** Cualquier atraso de más de una semana en la pista B se come el margen completo. Por eso
> S10 —donde vive SIGMA Intelligence— está tan tarde: es lo más vistoso de la demo, pero también lo
> único que se puede recortar a un panel con datos precargados si el calendario aprieta.

---

## 8. Definición de Listo y de Terminado

**Definición de Listo (DoR)** — una historia entra al sprint solo si:

1. Tiene criterios de aceptación en Gherkin, escritos y revisados.
2. Tiene su tabla de inputs con nombre de campo, tipo, validación y **columna de base de datos**.
3. Las tablas que toca existen en el script y están creadas en la base de desarrollo.
4. Está estimada por el equipo, no por una persona.
5. Se sabe qué pantalla toca y si es web, app o ambas.

**Definición de Terminado (DoD)** — una historia sale del sprint solo si:

1. Todos los criterios de aceptación pasan, verificados por alguien que no la programó.
2. Los permisos se validan **en el servidor**, no solo escondiendo el botón.
3. Si toca la app: **funciona sin señal** y sincroniza sin duplicar.
4. Los textos están en español de Chile, sin cadenas quemadas en el código.
5. Ningún dato de otro cliente es alcanzable — probado explícitamente con dos clientes.
6. Los `SELECT`/`INSERT`/`UPDATE` van por procedimiento almacenado, con el prefijo del patrón.
7. Está en el ambiente de demostración y alguien ajeno al equipo la usó sin explicación previa.

> **El punto 7 es el más incómodo y el más útil.** Una pantalla que necesita que su programador esté
> al lado explicándola no está terminada; está demostrada. Y en la defensa no va a haber nadie al
> lado del evaluador.

---

## 9. Trazabilidad — historia → tablas

| Épica | Tablas principales que toca |
|---|---|
| EP-01 | `Usuario` · `Perfiles` · `Permiso` · `Perfil_Permiso` · `Cliente_Usuario_Permiso` · `Cliente_Instalacion` · `Instalacion_Area` · `Centro_Costo` · `Grupo_Trabajo` · `Usuario_Especialidad` |
| EP-02 | `Activo` · `Activo_Tipo` · `Activo_Modelo` · `Activo_Posicion` · `Activo_Posicion_Historial` · `Activo_Componente` · `Activo_Atributo` · `Activo_Estado_Historial` |
| EP-03 | `Activo_Medidor` · `Activo_Medidor_Lectura` · `Activo_Variable` · `Activo_Medicion` · `Unidad_Medida` |
| EP-04 | `Programacion` (+6 hijas) · `Programacion_Generacion` |
| EP-05 | `Plan_Mantenimiento` · `_Version` · `_Activo` · `_Hito` · `_Actividad` · `Plan_Actividad_*` · `Plan_Mantenimiento_Ocurrencia` · `Plan_Ocurrencia_Historial` |
| EP-06 | `Checklist_Plantilla` · `_Version` · `_Seccion` · `_Item` · `Checklist_Item_*` · `Checklist_Ocurrencia` · `Checklist_Ejecucion` · `_Respuesta` · `Checklist_Hallazgo` |
| EP-07 | `Orden_Trabajo` + 9 hijas · `Falla` + 5 · `Activo_Indisponibilidad` |
| EP-08 | Todas, vía `<pfx>_uuid` · `Registro_Descubrimiento` · `*_Fusion` |
| EP-09 | `Dictado_Voz` · `Usuario_Accesibilidad` · `Entrada_Modo` · `Voz_Motor` |
| EP-10 | `Archivo` · `Archivo_Carga` · `Archivo_Vinculo` |
| **EP-11** | **`Modelo_Predictivo` · `_Version` · `Caracteristica_Modelo` · `Dataset_Entrenamiento` · `Entrenamiento_Ejecucion` · `Prediccion` · `_Caracteristica` · `_Explicacion` · `_Resultado` · `Modelo_Monitoreo`** |
| EP-12 | `Repuesto` · `Repuesto_Bodega_Stock` · `Orden_Trabajo_Repuesto` · `Componente_Repuesto_Instalacion` |
| EP-13 | `VW_ORDEN_TRABAJO_TABLERO` · `VW_PLAN_OCURRENCIA_PENDIENTE` · `Activo_Indisponibilidad` · `Falla` |
| EP-14 | `Suscripcion` · `_Periodo` · `_Pago` · `_Bloqueo_Log` · `Plan_Comercial` · `Valor_Uf` |
| EP-15 | `Bitacora` · `Bitacora_Comentario` · `Bitacora_Rectificacion` |

---

## 10. Los cinco riesgos, con fecha de chequeo

| # | Riesgo | Se chequea el | Si se cumple |
|---|---|---|---|
| 1 | **Google Play rechaza la app** | 22 oct | Plan B: APK distribuida directamente para la defensa, publicación después |
| 2 | **La sincronización sin señal resulta más cara de lo estimado** | 11 oct (fin S7) | Recortar EP-12 y EP-15 completos de la app |
| 3 | **El equipo baja de 3 a 2 personas** | Continuo | Bajar EP-13 a 2 indicadores y mover EP-11 a datos precargados |
| 4 | **El modelo con datos sintéticos no convence en la defensa** | 1 nov | Preparar la explicación del ciclo recolectar→predecir con el modelo comercial de respaldo |
| 5 | **Se acaba el espacio en SmarterASP Premium** | 20 oct | Purgar los binarios de prueba; el plan cubre holgado el volumen de la demo |

---

*Documento generado el 20 de agosto de 2026 · SIGMA · Bryan Chávez*
*Modelo de datos de referencia: 235 tablas, 610 claves foráneas, 21 scripts idempotentes*
