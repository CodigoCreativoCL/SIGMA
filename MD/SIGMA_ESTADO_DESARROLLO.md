# SIGMA — Estado del desarrollo

> **Documento vivo.** Es el traspaso de contexto entre sesiones de trabajo.
> Quien retome el proyecto debería poder leer solo esto y saber dónde está
> todo, qué se decidió y por qué, y qué falta.
>
> **Regla: cada vez que se cierre un bloque de trabajo, se actualiza este
> archivo en el mismo cambio.** Un documento de estado desactualizado es
> peor que ninguno, porque se le cree.

**Última actualización:** 04-10-2026 (Rediseño del módulo de Activos, bloque 344)
**Sprint vigente:** Sprint 1 — Fundaciones (02-09-2026 al 15-09-2026) ·
**Sprint 2 iniciado:** HU-035 (Activo) — capa de datos ejecutada y probada
contra la base; web construida y compilando (falta prueba en navegador)

---

## 1. Qué es esto y dónde está

SIGMA — Sistema Integrado de Gestión de Mantenimiento Industrial.
Capstone de Duoc UC, equipo **Código Creativo**.

| | |
|---|---|
| **Web** | `C:\Capstone\SIGMA\Web\Intranet` — ASP.NET WebForms (Web Site Project), .NET 4.8 |
| **API** | `C:\Capstone\SIGMA\Solucion\SIGMA\API` — ASP.NET Web API 2, .NET 4.8, JWT. Publicada en `http://localhost/SIGMA/Servicio/API`. **Su estado tiene documento propio: [`SIGMA_ESTADO_DESARROLLO_API.md`](SIGMA_ESTADO_DESARROLLO_API.md)**. Que cubre y que **no** cubre lo define [`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md) |
| **Scripts de BD** | `C:\Capstone\BD\` — 49 archivos `.sql`, numerados por orden de ejecución |
| **Documentación de análisis** | `C:\Capstone\MD\` — modelo de datos y anexos normativos |
| **Backlog y sprints** | `C:\Capstone\Fase 2\` |
| **Estándar de programación** | `C:\Capstone\PATRONES\ASP\` |
| **Base de datos** | SQL Server 2022 · `sql5112.site4now.net` / `db_acd593_sigma` |

**Roles:** Catalina Pescio (Product Owner) · Emilio Fuentes (Scrum Master) ·
Bryan Chávez (Developer).

---

## Entregables de la Fase 2 (obligatorios al cerrar los sprints)

Lista del Capstone registrada el 27-09-2026. Revisar al cerrar cada sprint; lo marcado ❌ no existe todavía.

| # | Entregable | Formato | Estado al 27-09-2026 |
|---|---|---|---|
| 1 | Objetivos y metodología ajustados post feedback Fase 1 | Word | ❌ No existe (hay Análisis Preliminar y Product Vision del 07-09) |
| 2 | Sprint Backlogs por sprint | Excel | ✅ S1–S6 en `Fase 2/Sprint Backlogs` |
| 3 | Definition of Done | Word 1 pág. | ⚠️ Existe (07-09); falta incorporar los ajustes de las retros 1–3 |
| 4 | Evidencia Daily Scrum / bitácora | Bitácora / GitHub Projects | ⚠️ Bitácora al día hasta S5; S6 sin escribir |
| 5 | Incrementos con commits en GitHub | Repositorio | ✅ En curso (ramas por integrante, master al día) |
| 6 | Sprint Review y Retrospectiva por sprint, con fotos/capturas | Word/PDF | ⚠️ S1–S3 listas **sin fotos/capturas**; S4–S6 pendientes |
| 7 | Burndown / Burnup | Excel | ⚠️ S1–S3 reconstruidos; S4–S6 vacíos |
| 8 | Plan de Pruebas + evidencias (unitarias, integración, rendimiento, seguridad) | `Fase 2/Pruebas/` — Plan + Mediciones de Rendimiento + 6 informes | ✅ Plan de Pruebas v1.1 (4 niveles, 4 tipos, trazabilidad a los RNF) · 285 casos de aceptación (281 conformes, 94 HU, 590 capturas) · 132 unitarias Flutter + **36 unitarias .NET** (`API.Pruebas`) · 51 casos de seguridad · **mediciones de rendimiento ejecutadas** (RNF-11/12/14/15). Único punto abierto: **RNF-19 (volumen de producción) no se puede verificar sobre la base del piloto** |
| 9 | Dockerización (Dockerfile, docker-compose, variables de entorno) | `docker-compose.yml`, `INFRAESTRUCTURA/docker/` | ⚠️ Escrito y validado (`docker compose config` OK): 2 Dockerfile multietapa, 2 entrypoints que inyectan la config, `.env.example` con 30 variables, `.dockerignore`, README. **Falta construir las imágenes** (requiere Docker Desktop en modo Windows y bajar varios GB) |
| 10 | Requisitos No Funcionales | SRS / Informe Final | ❌ No existe |
| 11 | Manual Técnico / Despliegue | `Fase 2/SIGMA_Manual_Tecnico_Despliegue.docx` | ✅ Requisitos, estructura, compilación, cambios de BD, pruebas, despliegue a SmarterASP, contenedores, convenciones y 8 problemas conocidos con su solución |
| 12 | Documento de Diseño: arquitectura C4, modelo ER, UML | `Fase 2/SIGMA_Documento_Diseno.docx` | ✅ 52 figuras: C4 Contexto/Contenedores, Despliegue (SmarterASP + Azure), Componentes, Mapa de 20 módulos, **MER completo de las 250 tablas** (vista global + los 20 módulos), diccionario de datos con 2.786 columnas, Casos de uso, Clases, 2 Secuencias y **ADR-01**. Imágenes y `.mmd` en `Fase 2/Diseno/capturas` y `.../capturas/mer` |

## 2. Lo primero que hay que leer antes de escribir código

> **Toda vista, modal o ficha nueva sigue el estándar de UI de `CLAUDE.md`** (raíz del repo), tomado de `Fase 2/Diseno/Planificacion360/SIGMA-Paleta-UI-Propuesta.html`: morado `#6732F4` = acción principal y pestaña activa, turquesa oscuro `#007F8A` = acción secundaria, azul `#087BEA` = abrir/navegar, turquesa `#16C6C9` = foco; cards blancas, rojo solo para destruir, sin degradados en cabeceras.

`C:\Capstone\PATRONES\ASP\` es **el estándar del grupo**, no una sugerencia.
Antes de la primera línea de C# o SQL:

1. `CONVENCIONES.md` — siempre. Naming, UTF-8 con BOM, prohibiciones.
2. El patrón que aplique: `BaseDatos/PATRON_SP.md`, `PATRON_TABLAS.md`,
   `Desarrollo/PATRON_MVC.md`, `PATRON_CONTROLES.md`, `PATRON_GRID_EVENTS.md`.
3. Un archivo real del proyecto del mismo tipo, para confirmar.

**Regla de precedencia** (README §3): ante diferencias, gana lo que ya existe
en el proyecto destino.

### La divergencia que SIGMA sí tiene

`PATRON_SEGURIDAD_MENUS.md` §3 y §4.1 **ya no aplican**. Describen
`Paginas.cs`, `enum menu_<N>` y `SecurityManagerVer`. En SIGMA eso se
eliminó: la seguridad es **por datos**.

```
Token.ExigirPagina()   →  la llama el master, ninguna página declara nada
Token.PuedePagina()    →  resuelve la URL contra Menus.mnu_link
Token.PuedeFuncion()   →  Menu_Funcion, por nombre de función
Token.Puede(codigo)    →  Permiso.prm_codigo
```

Registrar una pantalla nueva es un **INSERT en `Menus`**, no un cambio de
código. Una página sin fila en `Menus` **no se puede abrir**: se deniega por
defecto. Es la contrapartida de la decisión y hay que recordarla.

Excepciones (`Token.EXENTAS`): `default.aspx`, `login.aspx`,
`recuperarclave.aspx`, `restablecerclave.aspx`, `seleccionarcliente.aspx`,
`view/comun/procesamiento.aspx`, `privacidad/privacidad.aspx`.

---

## 3. Estado de la base

| | |
|---|---|
| Tablas | 239 |
| Stored procedures | 270 (incluye Activo, medidor, tipo, ficha, unidades, componentes, estado, modelos y atributos) |
| Funciones | 27 |
| Permisos | 76 (incluye Activos, Medidores, Tipos, Unidades y Componentes) |
| Perfiles | 9 |
| Páginas registradas en `Menus` | 91 (+1 Atributos técnicos) |
| Catálogos en el registro | 81 |
| Usuarios | 10 (3 de plataforma + 7 de Hamburgo) |
| Días de UF cargados | 31 |

### Cómo se despliega

Los scripts van **en orden numérico** y son **idempotentes**: se pueden
re-ejecutar. `00_MAESTRO.sql` los orquesta **todos** (62 bloques, 30-08); los
dos de datos demo van en su propia sección al final para poder comentarlos.

Bloques del Sprint 1 en adelante:

| Bloque | Qué hace |
|---|---|
| `25_SPRINT1_MODELO` | Columnas que faltaban en Cliente, Cliente_Instalacion y Usuario · tablas `Usuario_Password_Historial`, `Usuario_Recuperacion`, `Catalogo` |
| `26_SPRINT1_SEGURIDAD` | EP-01: login, bloqueo, recuperación, permisos puntuales |
| `27_SPRINT1_ORGANIZACION` | Áreas y centros de costo (árbol, sin ciclos) |
| `28_SPRINT1_EQUIPOS` | Grupos de trabajo y especialidades |
| `29_SPRINT1_CLIENTE_PLANTA` | HU-010 y HU-011 |
| `30_SPRINT1_USUARIOS_PERFILES` | HU-014 y HU-015 |
| `31_SPRINT1_CATALOGOS` | EP-03, catálogos genéricos |
| `32_SPRINT1_MENUS_PERMISOS` | Registro de las pantallas nuevas |
| `33_SPRINT1_AJUSTES` | SPs de apoyo · `Zona_Horaria` entra al registro |
| `34_SPRINT1_MENUS_WEB` | Páginas de detalle que aparecieron al construir |
| `35_SPRINT1_ICONOS_VALIDOS` | Iconos que no existen en MDI 5.0.45 |
| `36_SPRINT1_PERFILES_BASE` | Los 6 perfiles base y su matriz de permisos |
| `37_SPRINT1_DATOS_DEMO` | Ficha del cliente y planta |
| `38_SPRINT1_USUARIOS_DEMO` | Personal de Hamburgo · **corrige una FK rota** |
| `39_SPRINT1_IDENTIFICADOR_PAIS` | El identificador tributario depende del país |
| `40_SUSCRIPCION_UF` | Valor de la UF |
| `41_SUSCRIPCION_SPS` | Suscripción, períodos, pagos, cambio de plan |
| `42_SUSCRIPCION_ARCHIVOS` | `INS_ARCHIVO` / `SEL_ARCHIVO` / `DEL_ARCHIVO` · categoría `COMPROBANTE PAGO` |
| `43_SUSCRIPCION_MENUS` | Las 8 pantallas de Comercial, sus 8 permisos y sus 5 funciones |
| `44_PLANES_MANTENEDOR` | Crear y editar planes · **fijar precio versionando** |
| `45_SUSCRIPCION_KEY` | Reemitir la clave de suscripción |
| `46_PLAN_FUNCIONALIDADES` | Qué incluye cada plan y hasta cuánto |

> **Los bloques 42 a 46 están ejecutados** (30-08-2026), con sus
> comprobaciones en verde.

---

## 4. Sprint 1 — qué está hecho

Las 17 historias tienen su **capa de datos completa y probada**. La web está
construida y compila; **no está probada en navegador salvo lo que Bryan
reportó**.

### EP-01 · Acceso, seguridad y multicliente

| HU | Estado | Notas |
|---|---|---|
| HU-001 Iniciar sesión | ✅ probado | 6 escenarios verificados |
| HU-002 Seleccionar cliente | ✅ | selector + chip en la topbar |
| HU-003 Cerrar sesión / expirar | ✅ | sesión a 30 min · cabeceras anti-caché |
| HU-004 Recuperar contraseña | ⚠️ falta SMTP | ver §7 |
| HU-005 Editar mi perfil | ✅ probado | reglas de contraseña verificadas |
| HU-006 Aplicar permisos | ✅ | `FNC_USUARIO_TIENE_PERMISO` |
| HU-007 Permiso puntual | ✅ | ámbito Cliente / Planta / Área |

### EP-02 · Estructura organizacional

| HU | Estado | Notas |
|---|---|---|
| HU-010 Clientes | ✅ | + país, zona horaria, idioma, moneda |
| HU-011 Plantas | ✅ | código, zona horaria propia, coordenadas |
| HU-012 Áreas | ✅ probado | ciclo **indirecto** rechazado |
| HU-013 Centros de costo | ✅ probado | árbol, código único |
| HU-014 Usuarios del cliente | ✅ probado | "al menos una planta" |
| HU-015 Perfiles y permisos | ✅ probado | ⚠️ ver §7 |
| HU-016 Grupos de trabajo | ✅ probado | un solo líder **vigente** |
| HU-017 Especialidades | ✅ probado | panel de alertas a 30 días |

### EP-03 · Catálogos

| HU | Estado | Notas |
|---|---|---|
| HU-020 Consultar catálogos | ✅ probado | 81 catálogos, una sola pantalla |
| HU-021 Valores propios | ✅ probado | 16 catálogos ampliables |

### La API (30-08-2026)

`SIGMA/Solucion/SIGMA/API`. Cubre las **55 tareas de tipo API** del Sprint 1.
Compila en `exitcode=0`; **no está probada contra la base**.

**Las rutas NO llevan `/api/`.** La aplicación ya está publicada bajo
`.../Servicio/API`, así que el prefijo daría `API/api/clientes`. Los
`RoutePrefix` van sin él —igual que el `AuthController` heredado— y la ruta
convencional de `WebApiConfig` también se cambió. En el backlog las tareas
dicen "GET /api/clientes": eso nombra el recurso, no el segmento.

```
POST   /sesion                          HU-001   JWT con usuario y cliente
GET    /sesion · DELETE /sesion         HU-003
POST   /cliente-usuarios/seleccionar    HU-002   devuelve un token nuevo
GET    /usuario-permisos                HU-006   con caché de 60 s
GET    /catalogos · /catalogos/{c}/valores  HU-020  con caché
CRUD   /clientes · /cliente-instalaciones · /instalacion-areas
       /centros-costo · /cliente-usuarios · /perfiles · /grupo-trabajos
       /usuario-especialidades · /cliente-usuario-permisos · /catalogo-valores
GET,PUT /mi-perfil · POST /mi-perfil/password   HU-005
POST   /usuario-recuperaciones · /restablecer   HU-004
```

**Lo transversal está en `Utils/`, resuelto una vez y no quince:**

| | |
|---|---|
| `ErrorSql` | Traduce el `RAISERROR` de un SP a su código HTTP. **Severidad 16 = regla de negocio**; el texto decide 409 / 423 / 403 / 404 / 400. Todo lo demás es 500 y **su detalle no viaja al cliente**: nombres de tablas y de servidores son justo lo que sirve para atacar la base |
| `ApiBase` | El `try` que envuelve cada endpoint, el 404, y `ExigirUsuario` / `ExigirCliente` |
| `Datos` | Mapea el SP al DTO por reflexión. **El NULL se resuelve acá una vez**: es donde se colaba el `int.Parse()` sobre columna anulable que ya volteó tres pantallas |
| `Pagina` | Tope de 200 por página. El consumidor es un teléfono en una planta |
| `CacheCorta` | 60 s. Corta **porque son permisos**: uno revocado no puede quedar colgando |
| `SesionApi` | El usuario sale del **token firmado** y de ningún otro lado. Aceptarlo por parámetro dejaría operar como cualquiera cambiando un número |

**Decisiones que un tercero no deduciría del código:**

- **El usuario nunca viaja por parámetro.** Ni el cliente. Los dos salen del
  JWT. Un `?usuario=7` dejaría que cualquiera con token opere como otro, y
  la auditoría de cada tabla registraría a quien el atacante diga ser.
- **El token no lleva los permisos.** Dura ocho horas; los permisos cambian
  antes. Incrustarlos repetiría el error que se acaba de corregir en la web.
- **La sesión de la API dura 8 h y la de la web 30 min.** A propósito: un
  técnico en planta no puede quedar fuera a mitad de una orden por dejar el
  teléfono en el bolsillo.
- **Cerrar sesión no borra nada.** El JWT no se guarda. El endpoint existe
  igual para que la app tenga dónde avisar y para que el día que haya lista
  de revocación se implemente ahí sin que la app cambie.
- **La paginación se hace en memoria**, no en el SP: los `SEL_` son los
  mismos que consume la web y cambiarles la firma obligaría a tocar
  controllers ya probados. Correcto con los volúmenes del Sprint 1;
  **cuando entren activos y órdenes hay que paginar en SQL**.
- **`DELETE` es baja lógica en todos los recursos.** Donde no hay `DEL_`
  —grupos, permisos puntuales, valores de catálogo— se usa el `UPD_` con
  `habilitado = 0`, que es lo que el estándar pide igual.

### Pantallas nuevas

```
View/Organizacion/Plantas          Plantas.aspx · Planta.aspx
View/Organizacion/Areas            Areas.aspx · Area.aspx
View/Organizacion/CentrosCosto     CentrosCosto.aspx · CentroCosto.aspx
View/Organizacion/Grupos           Grupos.aspx · Grupo.aspx
View/Organizacion/Especialidades   UsuarioEspecialidades.aspx · UsuarioEspecialidad.aspx
View/Sistema/Catalogos             Catalogos.aspx · CatalogoValor.aspx
View/Root/.../PermisosUsuario      PermisosUsuario.aspx · PermisoUsuario.aspx
raíz                               SeleccionarCliente.aspx · RecuperarClave.aspx · RestablecerClave.aspx
```

---

## 5. Suscripción y modelo comercial

Base normativa: `MD/SIGMA_ANEXO_F_MODELO_COMERCIAL.md`.

**Ya estaba** (bloque 08): 17 tablas, 3 planes con 9 precios, 25
funcionalidades, catálogos de estado, y las funciones
`FNC_SUSCRIPCION_VIGENTE`, `FNC_VALOR_UF`, `FNC_CLIENTE_LIMITE`,
`FNC_CLIENTE_TIENE_FUNCIONALIDAD`.

**Bloque A — UF** ✅ · **Bloque B — SPs** ✅ · **Bloque C — web** ✅ ·
**Bloque D — bloqueo por límites y vencimiento** ✅ (bloques SQL 47 y 48 +
`SuscripcionAcceso` + `Renovar.aspx`).

| Plan | UF/mes | Trimestral | Anual | Plantas | Usuarios | Activos |
|---|--:|--:|--:|--:|--:|--:|
| BÁSICO | 9 | 25,7 | 90 | 1 | 5 | 150 |
| MEDIO | 22 | 62,7 | 220 | 3 | 25 | 750 |
| FULL | 45 | 128,3 | 450 | ∞ | ∞ | ∞ |

### Reglas que el código hace cumplir

- **§4.3 El valor de UF se congela en la transacción.** `Suscripcion_Periodo`
  guarda tres números (`spe_valor_uf_plan`, `spe_valor_uf_dia`,
  `spe_monto_clp`), **no una FK a `Valor_Uf`**. Un comprobante de hace dos
  años debe mostrar lo que se cobró, no un recálculo.
- **§6.1 `VENCIDA` y `EN GRACIA` no se guardan: se calculan.** Un estado que
  cambia solo porque pasó el tiempo no puede depender de que un job haya
  corrido anoche.
- **§8** Upgrade inmediato prorrateado; downgrade al cierre, sin devolución.
- **Tolerancia de pago**: la mayor entre $2.000 y 1% (`Sys_Parametros`). Sin
  ella, un período de $367.840 pagado con $366.340 quedaría impago por una
  comisión bancaria.

### El alimentador de UF

**No hay SQL Agent** en este hosting (sin acceso a `msdb`). El alimentador
corre en la web: `UfController.AsegurarValorDeHoy()`, llamado desde
`Default.master`, trabaja **una vez al día** y nunca lanza. Si la fuente cae,
arrastra el último valor y lo marca `ARRASTRE`; si no hay ninguno previo,
falla en vez de inventar.

> El día que haya SQL Agent: programar el job contra `INS_VALOR_UF` y quitar
> la llamada del master. Por eso escribe por SP y no por SQL directo.

### El estándar de modales

`Css/LookAndFeel/sigma-modal.css`. **Toda ficha que se abre en un
`RadWindow2` va con esto**, nueva o heredada. Reemplaza al patrón de
"fieldset" —label a la izquierda, control a la derecha— que en un modal
angosto se rompe y en uno ancho deja el label a treinta centímetros del dato.

```
.sigma-modal            contenedor
  .sigma-modal-eyebrow  contexto: MÓDULO · CLIENTE
  .sigma-modal-title    de qué registro se trata
  .sigma-modal-hero     icono + chip de estado + resumen
  .sigma-modal-grid     rejilla de campos (auto-fit, mín. 260px)
    .sigma-modal-field  label chico arriba, dato abajo
  .sigma-modal-note     regla de negocio que hay que saber ANTES del botón
  .sigma-modal-seccion  separador con icono
  .sigma-modal-actions  botones, a la DERECHA, principal al final
```

El label va arriba y en gris porque **el dato es lo que se viene a leer**:
con el label al lado y del mismo tamaño, la vista salta en zigzag para
juntar cada par.

**Migradas: las 25.** No queda ninguna con el patrón viejo.

La capa de **compatibilidad** que las adaptaba por CSS **se retiró** el
30-08, junto con la clase `sigma-modal-host` de `Simple.master`: ya no hay
nada que adaptar, y sostenerla de más significaría que el patrón viejo sigue
siendo válido y que la ficha 26 puede nacer con él.

La migración se hizo con un transformador (`scratchpad/migrar_modales.py`)
que **solo toca los `div` de maquetación**: nunca un control, un `ID`, un
atributo `runat="server"` ni el orden de los controles dentro de un campo.
Las filas con `id` + `runat="server"` —que el code-behind muestra y esconde—
conservan sus atributos. Lo que no encajaba en el patrón, el script lo dejó
intacto y lo reportó; esas nueve se hicieron a mano.

**Control de integridad**: se comparó el conjunto de `ID="..."` de cada
archivo antes y después. Cero diferencias en las 20. Eso descarta el riesgo
real —perder o renombrar un control y romper el code-behind— pero **no
reemplaza probarlas en navegador**, que sigue pendiente.

**Es una capa de transición, no el destino.** Una ficha que se toque por
otro motivo se migra a las clases `.sigma-modal-*`, que dan hero, chips de
estado y campos anchos. Cuando no quede ninguna con el patrón viejo, el
bloque de compatibilidad se borra.

### Qué contiene un plan, y qué lo limita

La pregunta "¿cómo le asocio al plan lo que incluye?" ya estaba resuelta en
el modelo desde el bloque 08; faltaba la pantalla, que es el bloque 46.

`Funcionalidad` tiene **25 filas con dos naturalezas**, marcadas por
`Funcionalidad_Tipo`:

| Tipo | Cuántas | Qué son |
|---|--:|---|
| `INCLUSION` | 21 | Se tiene o no: órdenes de trabajo, predictivo, voz, API… |
| `LIMITE` | 4 | Se tiene con tope: plantas, usuarios, activos, almacenamiento (GB) |

`Plan_Comercial_Funcionalidad` es la matriz plan × funcionalidad, con
`pcf_incluida` o `pcf_limite`. **Sin fila, la funcionalidad está negada**:
`FNC_CLIENTE_TIENE_FUNCIONALIDAD` devuelve 0 por defecto. La ausencia es
negación, no "sin definir" — por eso `SEL_PLAN_FUNCIONALIDAD` devuelve las
25 aunque no tengan fila.

Y **tope vacío con la funcionalidad incluida = sin límite**, que es como
está cargado FULL. Cero es otra cosa: cero es no poder crear ninguno.

Dos columnas hacen que esto no sea una tabla más:

- **`pcf_cliente` — la excepción por cliente.** En nulo es la regla del plan,
  para todos; con un cliente es una excepción solo para él, **y la excepción
  gana**. Es el mismo patrón que los permisos por usuario del ANEXO D. Sirve
  para lo que en la práctica siempre pasa: el cliente que negoció dos plantas
  extra sin cambiar de plan. Sin esto habría que crearle un plan a medida a
  cada uno, y en un año habría treinta planes de un cliente cada uno.
- **`pcf_vigencia_hasta` — la concesión que caduca sola.** "Le damos
  predictivo hasta fin de mes" se escribe con una fecha, no con un
  recordatorio en la agenda de alguien.

> **Los límites todavía no se hacen cumplir.** `FNC_CLIENTE_LIMITE` existe y
> responde bien, pero **ningún `INS_` la consulta**: hoy un cliente en BÁSICO
> puede crear diez plantas aunque su plan diga una. Eso es el bloque D.

### Bloque C — la web de suscripción

Siete pantallas bajo `View/Comercial/Suscripciones/`, todas registradas en
`Menus` por el bloque 43:

```
Planes.aspx                       la oferta y su precio vigente · solo lectura
Suscripciones.aspx  Suscripcion.aspx    ficha, contacto, estado, cambio de plan
Periodos.aspx       Periodo.aspx        emisión y detalle del cobro congelado
Pagos.aspx          Pago.aspx           declarar, y verificar contra la cartola
```

Capa de datos nueva: modelos `PlanComercial`, `Suscripcion`,
`SuscripcionPeriodo`, `SuscripcionPago`, `Archivo` y sus controllers, más
`ArchivoController`.

**Ocho permisos, no uno.** `VER PLANES COMERCIALES`, `VER SUSCRIPCIONES`,
`CREAR EDITAR SUSCRIPCIONES`, `CAMBIAR PLAN SUSCRIPCION`,
`EMITIR PERIODOS SUSCRIPCION`, `VER PAGOS SUSCRIPCION`,
`DECLARAR PAGO SUSCRIPCION`, `VERIFICAR PAGOS SUSCRIPCION`. Mirar el estado,
emitir un período (que es facturar) y verificar un pago (que es dar por
cobrado) las hace gente distinta. Con un permiso único, quien solo consulta
podría dar por pagada una factura, y el cliente podría verificarse a sí
mismo.

**Los archivos van a Blob Storage.** Ver §7.

---

## 6. Decisiones tomadas y su motivo

Esto es lo que más se pierde entre sesiones.

### ⚠ DECISIÓN ABIERTA — las dos formas de preguntar por un permiso

Hay **dos implementaciones** de *"¿este usuario tiene este permiso?"* y no
responden lo mismo:

| | Perfiles que cuenta | Regla de Root | Quién la usa |
|---|---|---|---|
| `SEL_USUARIO_PERMISOS` | `Usuario_Perfil` **y** `Cliente_Usuario_Perfil` | sí | `Token.Puede` (web), `Permisos.Tiene` (API) |
| `FNC_USUARIO_TIENE_PERMISO` | solo `Cliente_Usuario_Perfil` | sí, desde el bloque **62** | `SEL_MENU_APP`, `INS_CLIENTE_USUARIO_PERMISO` |

El bloque 62 igualó **la regla de Root**, que era la que dejaba el árbol de
la app vacío. La otra diferencia sigue abierta y **no se cerró a propósito**:

`Usuario_Perfil` está poblado **en espejo** de `Cliente_Usuario_Perfil` desde
el bloque 49, así que cada usuario de cliente tiene ahí su perfil. Si la
función empezara a contar los perfiles globales, un usuario de Hamburgo
resolvería sus permisos **en cualquier cliente**. Y al revés: si el SP dejara
de contarlos, las cuentas de plataforma —Soporte, Gerente Comercial— se
quedan sin nada, porque no tienen afiliación.

Hay que elegir una de las dos:

1. el SP deja de contar `Usuario_Perfil` **para los usuarios que sí tienen
   afiliación**, y lo cuenta solo para las cuentas de plataforma; o
2. el espejo deja de poblarse para los usuarios de cliente.

Adivinar cuál y aplicarla en silencio es como se abren agujeros. Se decide
antes de que la app tenga menús con permiso de verdad.


### Contraseñas en hash (bloque 26)

Estaban en **texto plano**. HU-005 obliga a guardar las tres anteriores de
cada persona; hacerlo en plano habría multiplicado el problema. Ahora
SHA2-256 con **sal por usuario**.

**La migración es progresiva**: si la cuenta no tiene sal, se compara en
plano y al acertar se convierte en esa misma llamada. Nadie tuvo que cambiar
su clave. El C# no cambió.

### El identificador tributario depende del país (bloque 39)

SIGMA opera en 5 países y el documento no se llama ni se valida igual. Se
llevó a `Paises`:

| País | Etiqueta | Regla | Largo |
|---|---|---|---|
| Chile | RUT | Módulo 11 | — |
| Perú | RUC | Sólo dígitos | 11 |
| Argentina | CUIT | Sólo dígitos | 11 |
| Ecuador | RUC | Sólo dígitos | 13 |
| Panamá | RUC | Ninguna | — |

`FNC_IDENTIFICADOR_VALIDO(@PAIS, @ID)` despacha. **Los DV de RUC/CUIT no se
implementaron a propósito**: existen, pero uno mal implementado rechaza
documentos válidos y nadie entiende por qué. Quedan validando estructura
hasta confirmarlos contra la fuente oficial.

### Perfiles base (bloque 36)

Salen de los documentos, no inventados (ANEXO A §554 y §655 pedían un
`05_PERFILES_BASE.sql` que nunca se escribió; ANEXO H §281 el Bodeguero).

| Perfil | Permisos | ¿Cierra OT? |
|---|--:|---|
| Administrador del Cliente | 20 | no |
| Jefe de Mantenimiento | 19 | **sí** |
| Planificador de Mantenimiento | 13 | **sí** |
| Supervisor de Mantenimiento | 11 | **sí** |
| Técnico de Mantenimiento | 8 | no — `per_solo_ejecucion = 1` |
| Bodeguero | 5 | no |

**No se crearon Prevencionista ni Contratista.** El ANEXO H §291 deja abierto
si el prevencionista necesita usuario — responderlo por el equipo no
corresponde. Y contratista no es usuario: es `Proveedor` con
`prv_es_contratista`.

### Los archivos viven en Blob Storage, y todavía no se puede subir ninguno

Decisión de Bryan (29-08): **todo archivo se almacena en Blob Storage**, y
quien habla con Azure **no es este sitio** sino una API .NET aparte que
además va a atender a la app móvil. Que la web y la app subieran por caminos
distintos garantizaría que algún día un archivo quede en un contenedor que la
otra no mira.

Esa API se construye después. Mientras tanto:

- `IAlmacenamiento` (`App_Code/SitioBase/Almacenamiento.cs`) define subir,
  descargar y eliminar. `AlmacenamientoApi` está **escrito completo** —es lo
  que hay que enchufar— pero `Disponible` devuelve falso mientras
  `AlmacenamientoApiUrl` conserve el texto `PENDIENTE`.
- **No se escribe a disco local como provisorio, a propósito.** Un provisorio
  que funciona es un provisorio que se queda: quedaría un comprobante de pago
  en un disco que nadie respalda y que la app no puede leer. Es mejor que la
  pantalla diga "todavía no se puede adjuntar" y que eso moleste.
- `arc_ruta` guarda la **ruta del blob** (`contenedor/cliente/carpeta/nombre`),
  no una URL firmada: una URL con token caduca y quedaría inservible guardada.
- El nombre almacenado es un GUID. Dos personas suben `comprobante.pdf` el
  mismo día y una pisaría a la otra; y un nombre elegido por quien sube es una
  ruta elegida por quien sube. El original se conserva en
  `arc_nombre_original`, que es donde sirve.
- El estado de antivirus nace `PENDIENTE`, no `LIMPIO`: no hay antivirus
  conectado y marcar limpio algo que nadie revisó sería mentirle al día en que
  sí lo haya.

Contrato esperado de la API (ajustable, está en el comentario de la clase):
`POST /archivo` con base64 → `{ruta, hash, tamano}` · `GET /archivo?ruta=` ·
`DELETE /archivo?ruta=` · cabecera `X-Api-Key`.

### La clave de suscripción se ve una sola vez

`INS_SUSCRIPCION` guarda el prefijo visible y **el hash del resto**. La ficha
la muestra al crearla, en un recuadro, sin cerrar el modal —cerrarlo se la
llevaría puesta—. Si no se copia, hay que emitir una nueva. Es incómodo a
propósito, por la misma razón por la que las contraseñas dejaron de estar en
texto plano en el bloque 26.

El alfabeto de la clave omite `I`, `O`, `0`, `1` y `L`: estas claves se dictan
por teléfono en soporte, y ahí una O y un cero son la misma letra.

### Otras

- **La suscripción no nace dentro de `INS_CLIENTE`**: un cliente puede
  existir mientras se negocia.
- **La implantación se emite en cero** salvo monto explícito: no hay precio
  definido y facturar un número no acordado es peor.
- **El comprobante de pago es obligatorio** (`spa_archivo` es `NOT NULL`).
- **Un administrador de plataforma puede elegir cualquier cliente** aunque no
  esté afiliado: quien da de alta un cliente tiene que poder configurarlo.
  La condición es tener `VER CLIENTES`, no "ser Root".

### El perfil del usuario de cliente (bloque 49)

- **`Cliente_Usuario_Perfil` es la fuente de verdad; `Usuario_Perfil` es su
  espejo.** El espejo se conserva porque hay pantallas heredadas que lo
  consultan, y reescribirlas todas de golpe es más riesgo que beneficio.
  `UPS_CLIENTE_USUARIO_PERFIL` lo mantiene sincronizado, y borra del espejo
  solo lo que la persona ya no tiene **en ningún cliente**: si es técnica en
  una empresa y supervisora en otra, cambiarle el perfil en una no puede
  borrarle el de la otra.
- **`VER CLIENTES` y `VER TODO CLIENTES` son cosas distintas.** El primero
  abre el listado comercial; el segundo decide quién ve **todas** las empresas
  en el selector. Estaban fundidos, y eso hacía imposible darle a un
  Administrador del Cliente acceso a su propia empresa sin darle de paso la
  lista de todas. Separarlos fue lo primero: poblar el espejo sin hacerlo
  habría convertido a cada usuario de cliente en cuenta de plataforma.
- **Sin perfil no se entra** (`403`). Un usuario sin perfil resuelve cero
  permisos: menú vacío y cada pantalla lo rebota. Decírselo en la puerta es
  mejor que dejarlo dando vueltas.
- **Organización, Catálogos y Permisos por usuario son del cliente**, y por
  eso cuelgan de Cliente. Estaban bajo Sistema, que es de la plataforma: por
  eso un técnico de Hamburgo veía ese nodo.
- **Organización volvió a ser un grupo, en un tercer nivel** (bloque 50).
  El bloque 49 las había colgado planas porque `MenusLateral` marcaba todos
  los submenús como `nav-second-level` y el tercer nivel salía con la misma
  sangría que el segundo. Adminto trae ese nivel a medias: el padding lo
  lleva `.nav-thrid-level` —con el typo— y `.nav-third-level` solo recibe el
  color del activo, y ninguna aplica sangría. Se arregló el renderer y se
  escribió el estilo en `sigma-layout.css`.
- **"Instalación" pasa a "Planta" solo en lo visible.** `Cliente_Instalacion`,
  `cin_*` y los SPs siguen igual: renombrar el esquema por una palabra de
  pantalla es mucho riesgo por ninguna ganancia. Excepción que no se tocó: en
  `Suscripcion.aspx`, "su instalación" es el software del cliente contra la
  API, no una planta.
- **El listado de clientes se queda en Comercial.** El nodo Cliente es *tu*
  empresa; Comercial es donde SIGMA da de alta empresas. Son dos cosas.
- **El hash de la contraseña ya no viaja en la grilla**, solo cuando se pide
  una persona (la ficha lo reenvía al guardar).

### Configuración de la app por planta (bloque 57)

- **Son dos capas distintas y no hay que confundirlas.** `Plan_Funcionalidad`
  es lo que el cliente **compró**; `Cliente_App_Instalacion` es lo que además
  **se permite en esa planta**. En una sala eléctrica clasificada no entra un
  teléfono sacando fotos aunque el plan las incluya. Por eso cada
  funcionalidad de app apunta a la funcionalidad de plan que la habilita, y
  **el interruptor solo aparece si el plan la incluye**: ofrecer un
  interruptor para algo no comprado deja al cliente creyendo que lo activó.
- **Sin suscripción no se filtra nada.** Misma regla del bloque 47: un
  cliente en configuración todavía no compró, no es que haya comprado cero.
  Sin esto la pantalla quedaba en blanco justo cuando alguien la está
  armando. (Me pasó: la primera versión escondía las seis.)
- **La lista salió del backlog, no de la imaginación.** Cada fila lleva en
  `app_origen` la historia que la justifica (US-073, US-080, US-081, US-085,
  US-092, US-130).
- **Qué quedó fuera y por qué.** Bandeja del día (US-074) y trabajo sin señal
  (US-071) son el núcleo de la app —el backlog llama al segundo "el
  diferenciador y no negociable"—: un interruptor que nadie debería mover no
  es una opción, es una trampa. Accesibilidad (US-082) es preferencia **de la
  persona**, no de la planta: quien necesita texto grande lo necesita en las
  cinco plantas donde trabaja.
- **Sin fila configurada rige `app_por_defecto`**, y el SP ya devuelve el
  valor efectivo. Antes venía `NULL` y la pantalla dejaba los dos radios
  apagados, sin decir cuál estaba vigente.

### El bloqueo por suscripción (bloque D)

- **Sin suscripción no se aplica ningún tope.** Un cliente que se está
  configurando todavía no contrató nada; tratarlo como moroso impediría
  darlo de alta. El tope aparece recién con la primera suscripción.
- **Ante la duda, se deja pasar.** `GetEstadoCliente` devuelve `null` si la
  consulta falla, y `SuscripcionAcceso` interpreta `null` como "seguir".
  Un error de base nunca debe dejar afuera a un cliente que pagó.
- **Las cuentas de plataforma no se bloquean nunca.** No tienen cliente en
  sesión, así que no hay suscripción que exigirles; y si se las bloqueara,
  no quedaría nadie que pudiera arreglar la suscripción.
- **`Default.aspx` no está exenta.** El tablero muestra datos de operación,
  que es justo lo que cierra §6.6: quien entra vencido cae en la renovación
  desde la primera pantalla. `Renovar.aspx` sí lo está —es el destino del
  redirect— y también `MiCuenta`, porque impedir cambiar una clave
  comprometida es peor que dejar ver una pantalla.
- **El tope se comprueba dentro del `INS_`, no en la página.** Así vale
  igual para la web, para la carga masiva y para la API que viene: nadie
  puede saltárselo llamando al SP directamente.
- **Bajar de plan no borra nada** (§8). Lo que excede queda donde está y se
  puede seguir viendo; lo único que se impide es crear más. Verificado:
  BÁSICO → FULL → BÁSICO deja las dos plantas en pie.
- **Con la suscripción caída, el único que entra es quien puede renovar.**
  Al resto lo rechaza `SEL_LOGIN` con código `402`: si cada pantalla los va
  a rebotar, el lugar donde decírselo es la puerta, no adentro. Además,
  renovar no es tarea de un técnico, y esa pantalla muestra saldos que no le
  corresponde ver.
- **Quién es "administrador" no lo decide el nombre del perfil**, lo decide
  el permiso `RENOVAR SUSCRIPCION` colgado de `~/Renovar.aspx` en `Menus`.
  Que mañana un cliente quiera que su jefe de mantenimiento también renueve
  es un `INSERT` en `Perfil_Permiso`, no un despliegue.
- **El estado comercial no se cuenta antes de validar la contraseña.** El
  chequeo va después: si fuera antes, probando correos se podría averiguar
  qué empresas están vencidas. Con la clave mala el mensaje sigue siendo el
  genérico `404`.
- **Con varios clientes basta que uno esté al día para entrar.** Al vencido
  lo ataja la compuerta de la web cuando lo elijan. Bloquear el login por un
  cliente moroso dejaría sin sistema a quien trabaja para otros dos que sí
  pagan.
- **`Renovar.aspx` no es un item de menú** (`mnu_visible = 0`). Se llega por
  el aviso del encabezado o porque la compuerta te mandó. Colgarla del árbol
  obligaría a elegir un nodo, y el natural —Comercial— es del equipo de
  SIGMA, no del cliente.

---

## 7. Pendientes y cosas que hay que saber

### Bloqueantes

- **SMTP sin configurar.** `Web.config` → `system.net/mailSettings` tiene
  valores de marcador. Hasta que estén los reales, HU-004 registra el token
  pero **nadie recibe el enlace**. La pantalla muestra igual su mensaje (no
  delata si el correo existe) y el fallo queda en `Sis_Excepcion`.

- **La API de almacenamiento no existe todavía.** `Web.config` →
  `AlmacenamientoApiUrl` = `PENDIENTE`. Consecuencia concreta: **no se puede
  declarar un pago**, porque el comprobante es obligatorio. `Pagos.aspx` y
  `Pago.aspx` lo dicen en pantalla y esconden el formulario en vez de fallar
  al guardar. Todo lo demás del bloque C funciona. Ver §6.

> Los bloques 42 y 43 figuraban aquí como no ejecutados. **Ya lo están**
> (30-08), igual que 44 a 46: verificado contra la base — `INS_ARCHIVO`,
> `INS_PLAN_COMERCIAL`, `UPD_SUSCRIPCION_KEY` y `SEL_PLAN_FUNCIONALIDAD`
> existen, y las 8 páginas de Comercial están en `Menus`.

### El estado de la API

**No existe el proyecto.** No hay solución ni carpeta en disco; los seis
procedimientos `API_*` de la base son heredados de FacilityGes —marcación,
dispositivos, parámetros— y no sirven para SIGMA salvo como referencia de
estilo.

Lo que S1 pedía era "esqueleto de la API con validación de KEY". La mitad de
base **ya está lista**, y conviene saberlo antes de empezar:

| Pieza | Dónde está |
|---|---|
| La KEY, hasheada, con prefijo visible y reemisión | `Suscripcion.sus_key_prefijo` + `sus_key_hash` (bloque 45) |
| **El validador de KEY** | `FNC_SUSCRIPCION_VIGENTE(@KEY_HASH)` → cliente, estado, `PUEDE_OPERAR` |
| Topes y funcionalidades del plan | `FNC_CLIENTE_LIMITE`, `FNC_CLIENTE_PUEDE_CREAR`, `FNC_CLIENTE_TIENE_FUNCIONALIDAD` |
| Qué ofrece la app por planta | `SEL_CLIENTE_APP_INSTALACION` (bloque 57) |
| Dispositivos y push | `Usuario_App_Dispositivo` + `API_UPS_USUARIO_APP_DISPOSITIVO` |
| **Sincronización sin duplicar** (US-072) | **21 tablas con `_uuid` e índice único, 21 de 21** |

Falta el proyecto: middleware que resuelva la KEY del encabezado contra
`FNC_SUSCRIPCION_VIGENTE` y responda `402` si la suscripción no permite
operar, login que devuelva token, y los endpoints de sincronización
descendente y ascendente. El detalle endpoint por endpoint está en la hoja
Tareas de cada Sprint Backlog.

### Decisiones abiertas

> **Las seis se cerraron el 30-08 en el bloque 52.** Se dejan aquí con su
> resolución, no borradas: una decisión sin su porqué se vuelve a discutir.

- ~~**HU-010**: ¿baja física o lógica?~~ → **Lógica.** `DEL_CLIENTE`
  deshabilita al cliente y a sus afiliaciones, y no borra nada. Motivo
  contable: hay períodos emitidos y pagos verificados apuntando a esa
  empresa, y borrarla deja el historial de facturación ilegible justo cuando
  alguien lo necesita. Además ya se comportaba a medias así —se negaba a
  borrar si el cliente tenía plantas—, o sea que el único borrable era el que
  no tenía nada. El botón dice ahora **"Dar de baja"**.
- ~~**Perfil 2 (Soporte)**~~ → **Ve todo, no modifica nada.** Se otorga por
  patrón (`prm_codigo LIKE 'VER %'`, hoy 29 permisos) y no por lista: la
  pantalla que nazca mañana la ve sin que nadie se acuerde de agregarla, y
  lo que no empieza con VER queda fuera por construcción.
- ~~**Perfil 3 (Gerente Comercial)** fuera de lo comercial~~ → **La
  organización del cliente, en solo lectura.** Es lo que determina el plan:
  los topes se miden en plantas, usuarios y activos, y negociar una
  renovación sin poder mirar cuántos hay es negociar a ciegas. Nada de
  operación —OT, activos, repuestos, permisos de trabajo—.
- **Administrador del Cliente** recibió ver planes, ver suscripción, ver
  pagos y declarar pago. **No verifica** —verificarse a sí mismo es lo que el
  flujo de §5.4 evita— ni emite períodos ni cambia de plan: eso lo ejecuta
  SIGMA después de acordarlo.
- ~~**Prevencionista**: ¿perfil o solo un nombre?~~ → **Perfil de verdad**
  (`per_id` 16, tipo Cliente). El argumento es concreto: existe el permiso
  `AUTORIZAR PERMISO TRABAJO`. Si fuera solo un nombre, no podría autorizar
  nada y el permiso de trabajo —lo único que su rol firma— tendría que
  firmarlo un jefe haciéndose pasar por él. Ve la organización en solo
  lectura; no cierra OT ni crea activos.
- ~~**DV de RUC peruano, CUIT y RUC ecuatoriano**~~ → **Implementados**, con
  los algoritmos verificados contra fuentes públicas antes de escribirlos.
  `FNC_RUC_VALIDO_PE`, `FNC_CUIT_VALIDO_AR`, `FNC_RUC_VALIDO_EC`, enchufados
  al despachador por `pai_identificador_validacion`. Ojo con la diferencia
  que casi se pasa por alto: Perú y Argentina usan los mismos pesos pero
  cierran distinto —Perú mapea 10→0 y 11→1; Argentina mapea 11→0 y considera
  **inválido** el 10—. Ecuador no tiene un algoritmo sino tres, y cuál toca
  lo dice el tercer dígito (0-5 natural módulo 10, 6 pública módulo 11 con
  DV en la 9, 9 privada módulo 11 con DV en la 10).

### Estado del Sprint 1 en el backlog

`Fase 2/Sprint Backlogs/SIGMA_Sprint_Backlog_S1.xlsx`, hoja **Tareas**:

| Tipo | Estado |
|---|---|
| Base de datos (93) · Seguridad (17) · **API (55)** | Terminada |
| Web (38) | En revisión |
| Pruebas (17) · Documentación (17) · Validación (2) | Por hacer — **Catalina Pescio** |
| Móvil (5) | Por hacer |

**165 de 244 tareas · 66,7 % de las horas.**

Las 17 historias siguen en **En revisión** (HU-004 **Bloqueada** por SMTP), y
tiene que seguir así: nada de lo construido está probado ni documentado, y
esas 34 tareas son de Catalina. Marcar una historia como terminada antes de
eso sería decir que se probó algo que nadie probó.

**Desviación registrada — T-1226.** La tarea pedía "POST /mi-perfil, alta
idempotente por uuid". Mi perfil no se crea, se edita: no hay alta ni uuid
que repetir. Se entregó `PUT /mi-perfil` y `POST /mi-perfil/password`, que
es lo que HU-005 necesita. Queda anotado en la observación de la tarea.

### No verificado

- **La API no se ha ejercitado contra la base.** Compila, y las firmas de
  los SPs se verificaron una a una contra `sys.parameters` en vez de
  suponerlas —de ahí salieron cuatro que no existen: `SEL_PERFIL`,
  `DEL_PERFIL`, `DEL_GRUPO_TRABAJO` y `DEL_CATALOGO_VALOR`, resueltos con
  los nombres reales o con baja lógica por `UPD_`—. Pero compilar no es
  llamar. Empezar por `POST /sesion`: de ahí salen los tokens del resto.

- Las pantallas **no se han recorrido en navegador**. El 30-08 se abrieron
  dos y aparecieron cuatro fallas que el compilador no ve: `dbo.SPLIT` que no
  existía, contraseñas guardadas en texto plano, una FK violada al cambiar de
  perfil y una tabla ausente. **Es el pendiente más grande que no depende de
  nadie externo**, y desde el 30-08 está asignado a Catalina en el Sprint
  Backlog: los 46 criterios de aceptación del Sprint 1 siguen en "No".

- **Ninguna historia del Sprint 1 cumple la Definition of Done.** Las 17
  están construidas y en estado "En revisión"; una (HU-004) bloqueada por
  SMTP. Puntos completados: 0 de 81. No es que no se hiciera el trabajo: es
  que la DoD exige criterios verificados, validación de la PO y revisión de
  código, y nada de eso ocurrió.
- **Los SPs del bloque 42 no se han ejercitado.** `INS_ARCHIVO` no se puede
  probar de punta a punta hasta que exista la API de almacenamiento.
- **HU-015 escenario 3** (`per_solo_ejecucion` bloquea CERRAR OT) no se pudo
  ejercitar: ninguna fila de `Menus` lleva ese permiso todavía. Será
  testeable cuando existan las pantallas de OT (Sprint 3).

- **Activos 06-10-2026 sin recorrer en navegador** (commits `0dcc911`…`310032b` en `CatalinaPescio`): guardar el asistente con los combos nuevos al editar, el ajuste de alto de la confirmación, «Agregar subactivo» desde el explorador, el orden por fecha y el badge «Nuevo» con datos reales, y guardar un componente colgado de un subactivo o de otro componente (en la ficha y en el centro 360). Solo se probó el alta de un activo.

### Deuda conocida

- ~~**21 modales con el markup viejo**~~ **Cerrado (30-08).** Las 25 fichas
  están migradas a `sigma-modal-*` y la capa de compatibilidad se retiró,
  junto con la clase `sigma-modal-host` de `Simple.master`. Si aparece una
  pantalla con el patrón viejo, lo correcto es migrarla, no revivir la capa.

- **El proyecto no está en git.** Es la deuda que más cuesta hoy: sin
  historial no hay diff que revisar, así que el criterio 9 de la Definition
  of Done —revisión de código— no se puede cumplir por definición. Y obliga
  a que lo retirado se mueva a `C:\Capstone\_RETIRADO\` en vez de borrarse,
  porque un borrado aquí es irreversible.

- **Once entidades del backlog no están modeladas todavía**: las firmas de
  orden de trabajo (`Orden_Trabajo_Firma`), toda la sincronización
  (`Sincronizacion_Lote`, `Sincronizacion_Conflicto`) y los indicadores
  (`Indicador_Valor`). Se detectó al detallar los Sprint Backlogs, cruzando
  las 132 historias contra `sys.tables`. En sus tareas la primera dice
  "CREAR la tabla", no "revisar": es trabajo que no estaba contado.

- **Reenviar la key sigue sin existir, y no va a existir.** La clave no está
  en claro en ninguna parte: solo el prefijo visible y el hash del resto.
  Recuperarla es tan imposible como recuperar la contraseña de alguien, y por
  la misma razón. Lo que sí hay ahora es **reemitir** (bloque 45): genera una
  nueva, la muestra una vez, y exige motivo porque **corta la integración del
  cliente** hasta que le carguen la nueva. Hacérsela llegar sigue siendo
  manual mientras el SMTP no esté.

- **La clave de Google Maps está sin restringir (por verificar).**
  `Web.config` → `GoogleMapsApiKey`. Esa clave es **pública por diseño**:
  viaja en el `<script src>` y cualquiera la lee en el fuente de la página.
  Lo que la protege no es esconderla sino restringirla por *referrer HTTP*
  en la consola de Google y habilitarle solo las APIs que se usan. Sin eso,
  quien la copie factura contra esta cuenta. **Hay que confirmar que la
  restricción esté puesta.**

- Queda el aviso de *permissions policy* por el evento `unload`. Es de una
  librería heredada y no rompe nada: el navegador solo avisa que ese evento
  está en desuso.

- **14 `.md` de `MD/` están sin BOM** (los anexos y modelos). La convención
  pide UTF-8 con BOM para `.md`. Se ven bien igual, así que no se tocaron
  para no ensuciar el changeset con 14 archivos por tres bytes. Las 49 `.sql`
  de `BD/` y todo el código sí lo tienen; los únicos sin BOM en la web son 18
  librerías de terceros, que no se tocan.

- ~~`00_MAESTRO.sql` no incluye los bloques 25 a 48.~~ **Cerrado (30-08).**
  Ahora referencia las 62 `.sql` del directorio. En disco hay 65: quedan
  fuera el propio maestro, `09_COSTOS_NUBE` (retirado) y `_RESPALDO`. Los bloques demo (37 y 38)
  van en su propia sección al final, para poder comentarlos y levantar un
  ambiente limpio. `09_COSTOS_NUBE` sigue fuera a propósito —está retirado— y
  `07_ICONOS_MDI`, que **nunca había estado**, entró después del 06 como pide
  su propia cabecera.
- `icono_guardar` se usa también para "Nuevo" y "Asociar".
- Los nombres `--fg-*` siguen dentro de `sigma-components.css`.
- Las pantallas de OT, activos, checklists y planes no existen (Sprint 3+).

### Trampas que ya costaron tiempo

- **`<input type="date">` dentro de un UpdatePanel no llega al servidor.**
  Un `asp:TextBox` con `TextMode="Date"` se renderiza como
  `<input type="date">`, y el serializador de formularios de ASP.NET AJAX
  —el que arma el postback parcial— solo conoce los tipos de input clásicos:
  **salta los tipos HTML5**. El campo se ve lleno en la pantalla, el postback
  ocurre, y el servidor lee vacío. El síntoma es «Indique la fecha» con la
  fecha escrita delante. Se resuelve registrando el botón para postback
  completo (`ScriptManager.GetCurrent(Page).RegisterPostBackControl(btn)`),
  que es la razón por la que las fichas del sitio tienen esa línea.

- **`OnClientClick="return ConfirSweetAlert(…)"` mata el postback de un
  `PushButton`.** ASP.NET pega el `__doPostBack` **detrás** de lo que diga
  `OnClientClick`: con un `return` delante, ese `__doPostBack` es código
  muerto. Y como `PushButton` se renderiza `type="button"`, devolver `true`
  tampoco envía el formulario. Resultado: la confirmación aparece, se aprieta
  SÍ y no pasa nada —sin error, sin mensaje—. En el resto del sitio el mismo
  patrón funciona porque son `LinkButton`, donde el postback va en el `href`
  y el `return false` solo cancela la navegación. Con un `PushButton` se
  escribe `if (!ConfirSweetAlert(…)) return false;`.

- **Un control `Enabled = false` no viaja en el postback.** Fijar un combo
  con `Enabled = false` para que nadie lo cambie deja su valor fuera del
  envío: si la pantalla tiene cualquier `AutoPostBack`, la selección se
  pierde y el Guardar rechaza por un campo que el usuario nunca tocó. La
  preselección tiene que reaplicarse en **cada** carga, no solo cuando
  `!IsPostBack`.

- **Los chips de estado se pintan en caja alta por CSS.** `innerText`
  devuelve el texto ya transformado, así que un guion de pruebas que compare
  contra `'Vencida'` no calza nunca —y si además usa un diccionario para
  ordenar, no calza ninguno y la comprobación pasa de vacío—. En los guiones
  de evidencia se compara con `.toUpperCase()`.

- **El markup dentro de un `asp:LinkButton` no sobrevive al postback.**
  `LinkButton` es un control de **texto** —implementa `ITextControl`—, no un
  contenedor: lo que se le escribe adentro se pinta la primera vez y, al
  volver del re-render asíncrono, queda un `<a>` vacío con su clase y su
  `href` intactos. Se ve como un problema de CSS y no lo es. Una tarjeta
  clickeable se arma como HTML de servidor, con un `LinkButton` escondido que
  solo dispara el viaje.

- **`__doPostBack(target, argumento)` desde un `onclick` llega sin
  argumento.** `GetPostBackClientHyperlink(control, arg)` produce la llamada
  correcta, el postback ocurre y no hay error de ninguna clase: simplemente
  `__EVENTARGUMENT` llega vacío y el handler no sabe qué se apretó, así que
  la pantalla no hace nada. Es el silencio lo que cuesta encontrarlo. El dato
  viaja en un `HiddenField` que el `onclick` escribe —el mismo par que usa el
  centro del plan con `hdnSeccion`— y el `LinkButton` solo dispara.

- **Registrar la pantalla en `Menus` no alcanza: faltan sus `Menu_Funcion`.**
  `mnu_permiso` dice quién ENTRA. `Menu_Funcion` dice quién puede hacer cada
  cosa adentro, y es lo que lee `Token.PuedeFuncion`. Sin esas filas la
  función no existe en el mapa, `PuedeFuncion` devuelve false y la barra de
  comandos de la grilla **no se dibuja para nadie**. El síntoma es el peor de
  todos: el usuario tiene el permiso y concluye que no lo tiene. Registrar
  una pantalla nueva son las dos cosas, en el mismo bloque.

- **`Css/LookAndFeel/v2/02-Sidebar.css` está muerto.** Sus reglas se movieron
  a `sigma-layout.css` hace tiempo, pero el archivo sigue en disco con el
  nombre más obvio del mundo para quien va a tocar el sidebar. Editarlo no
  produce ningún efecto y el síntoma es «el CSS no se aplica», que se
  confunde con un problema de caché. El sidebar se edita en
  `Css/LookAndFeel/sigma-layout.css`.

- **`?vrs=N` escrito a mano nunca refresca.** Un número fijo en el enlace del
  CSS o del JS solo cambia cuando alguien se acuerda de subirlo, así que el
  navegador sigue sirviendo el archivo viejo y la corrección «no funciona».
  Para eso está `Asset("~/ruta")`: devuelve la URL con el
  `LastWriteTimeUtc.Ticks` del archivo, y entonces el que cambia el archivo
  cambia la URL sin hacer nada más. Los `?vrs=` que quedan son deuda.

- **Un combo `ReadOnly` rompe `validaControl`.** `RadComboBox` en `ReadOnly`
  no renderiza sus ítems en el cliente y el validador se cae al recorrerlos,
  dejando el Guardar muerto sin mensaje. Para fijar un combo se usa
  `Enabled = false`; `ReadOnly` queda solo para el modo de solo lectura
  completo.

- **`AutoPostBack` junto a un botón = doble postback.** Un control con
  `AutoPostBack` que pierde el foco porque se apretó el botón dispara su
  propio viaje y el del botón: la acción se ejecuta dos veces. Si el
  `AutoPostBack` solo servía para pintar un asterisco, se saca y la regla se
  valida en el servidor al guardar.

- **Los iconos MDI no se veían, y no era la versión.** `icons.min.css` de
  Adminto declara la familia `Material Design Icons` pero **no trae ni un
  glifo**: solo los modificadores (`mdi-rotate-*`, `mdi-dark`). Y el
  `materialdesignicons.min.css` que sí los tenía **no lo enlazaba ningún
  master**. Resultado: *todo* icono `mdi` del sitio salía vacío —no roto,
  vacío— y se leía como un problema de permisos o de datos.

  Resuelto el 30-08: se descargó **MDI 7.4.47** (7.448 glifos) a
  `Css/LookAndFeel/mdi/`, fuera de Adminto, y se enlaza en los dos masters
  **después** de `icons.min.css` para que su `@font-face` gane.

  Sigue valiendo la regla: una clase de icono inexistente **no da error**,
  no pinta. Verificar contra
  `Css/LookAndFeel/mdi/css/materialdesignicons.min.css`, y ojo que en MDI 7
  el selector es `::before` (doble), no `:before`.

- **`Simple.master` no cargaba la marca.** Es el master de los 25 modales y
  solo traía `v2/`: cualquier clase de `sigma-components.css` usada dentro
  de una ficha simplemente no aplicaba. Por eso los modales se veían con el
  look heredado mientras el resto del sitio ya estaba relookeado. Corregido.

- **`?query=0` reventaba la ficha con un 500.** Los listados abren su
  formulario con `abrirX(0)` para "Nuevo", así que llega literalmente
  `?query=0`, que no es texto cifrado válido: `Tools.Crypto.Decrypt` lanza y
  la página muere antes de pintar. **El botón "Nuevo" no funcionaba en
  ninguna ficha del sitio**, y el error no quedaba en `Sis_Excepcion` porque
  esa tabla solo recibe lo que escriben los SPs.

  Resuelto con `SitioBase.Querystring` (`App_Code/SitioBase/Querystring.cs`):
  `Descifrar`, `Entero(query, "Id")` y `Texto(...)`, que nunca lanzan y
  tratan lo ilegible como "no vino nada". **Las 28 fichas ya lo usan; cero
  `Tools.Crypto.Decrypt` directo en `View/`.** Cifrar sigue siendo
  `Tools.Crypto.Encrypt`: esto es solo el camino de vuelta.

  Se hizo con un helper y no con 28 `try/catch` porque un helper se arregla
  una vez, y la ficha número 29 no nace con el bug otra vez.

- **jQuery UI 1.8 con jQuery 1.9: `$.browser` no existe.** jQuery 1.9 lo
  eliminó y jQuery UI 1.8rc3 (de 2010) lo usa sin comprobarlo:
  `Cannot read properties of undefined (reading 'mozilla')`, decenas de veces
  por página, dejando jQuery UI a medio inicializar.

  Resuelto con `Js/jquery-browser-shim.js`, cargado **entre** jquery y
  jquery-ui en los dos masters. Es lo que hace jQuery Migrate, reducido a la
  única propiedad que hace falta. Actualizar jQuery UI cambiaría nombres de
  opciones, marcado y clases CSS en pantallas que nunca se probaron: sería
  cambiar un error de consola por uno de producción. **El shim se borra el
  día que se suba jQuery UI.**

- **`PuedeFuncion` no sirve en una ficha.** Resuelve las funciones *de la
  página actual*, y `Menu_Funcion` cuelga del **listado**. Preguntando desde
  el modal la respuesta es siempre `false` y la ficha se abre en solo
  lectura hasta para Root. En las fichas se pregunta por el **código** del
  permiso con `Token.Puede(...)`, como hace `Planta.aspx`.
- **Columnas anulables + `int.Parse()`**. Varios controllers heredados
  parsean directo columnas que admiten NULL: `int.Parse("")` lanza
  `FormatException` y voltea la pantalla. **Auditado el 30-08**: se cruzaron
  los 199 `X.Parse(dr["COL"])` del sitio contra las 1.075 columnas anulables
  de la base. Quedaban 16 sin guarda, en `ClienteController`,
  `PaisesController` y `PerfilController`; todas corregidas. Hoy la auditoría
  da **0**. Ninguna tenía datos en NULL todavía: eran latentes, y la primera
  en despertar habría sido la del mantenedor de Países, que deja las columnas
  de actualización vacías hasta la primera edición.

  El auditor quedó en `Tools/auditar_nulos.py` con su `nullable.txt`.
  Devuelve código 1 si encuentra algo, así que sirve tal cual en un hook o
  en CI. Vale la pena repetirlo al agregar controllers y al agregar columnas
  anulables (hay que regenerar `nullable.txt`; la consulta está en el
  encabezado del script).
- **Colación mixta.** Las tablas heredadas son
  `SQL_Latin1_General_CP1_CI_AS`; la base es `Modern_Spanish_CI_AS`. Comparar
  `per_nombre` o `usu_login` contra una variable exige
  `COLLATE DATABASE_DEFAULT`.
- **Los logins cambian.** Ya pasó una vez. Los scripts de datos emparejan por
  **`usu_id`**, no por login.

- **La contraseña no se arrastra a la ficha.** Las dos fichas de usuario
  cargaban `usu_password` en el campo y lo devolvían al guardar. Con hash eso
  no puede funcionar: lo guardado ya no es la contraseña sino su hash, y
  devolverlo significa volver a hashear el hash. Ahora el campo va vacío al
  editar, es `TextMode="Password"`, y vacío significa "no la cambies". El
  validador de obligatorio solo aplica al crear.

- **El bug del `upe_id` apareció cinco veces.** FK de
  `Cliente_Usuario_Perfil`, `INS_CLIENTE_USUARIO`, `SEL_CLIENTE_USUARIO`,
  `DEL_USUARIO_ASOCIACION` y `UPD_CLIENTE_USUARIO`. Siempre el mismo error:
  confundir el id de la FILA de `Usuario_Perfil` con el id del PERFIL. Si
  aparece un sexto sitio, es esto.

- **Una clave cambiada desde Mi Perfil no se puede recuperar.** El 29-08 a las
  18:52 alguien le cambió la contraseña a `root` desde HU-005 y `1` dejó de
  servir; lo mismo con `emilio` (18:51) y `catalina` (18:52). El hash no se
  revierte y el flujo de recuperación **no sirve mientras SMTP siga sin
  configurar**: el token se emite pero el correo no sale.

  La salida es un `UPDATE` directo con `FNC_PASSWORD_HASH`, conservando la sal
  y limpiando `usu_intentos_fallidos` / `usu_bloqueado_hasta` —si no, la
  cuenta sigue cerrada aunque la clave ya sea correcta—. **No se puede hacer
  por `UPD_USUARIO_PASSWORD`**: ese SP rechaza una clave igual a alguna de las
  tres anteriores, y la que uno quiere restaurar suele ser justamente una de
  ellas. La validación está bien; es la reparación la que va por fuera.

  `root` quedó restablecida en `1`. **`emilio` y `catalina` también, el 30-08**,
  por el mismo camino y verificadas con `SEL_LOGIN`. Las tres cuentas del
  equipo entran con `1`.

- **El mensaje del login no distingue.** "Correo o contraseña incorrectos"
  cubre cuenta inexistente y clave mala, a propósito (HU-001 escenario 2). Para
  diagnosticar hay que mirar `Sis_Excepcion`, que sí registra cuál de los dos
  fue, y la fila de `Usuario`.


- **`SEL_ACTIVO_PLANTA` no tiene su versión completa en ningún archivo.** El último `CREATE` es el de `BD/346`; los bloques 348, 351, 353, 356 y 357 lo parchan leyendo `OBJECT_DEFINITION` y haciendo `REPLACE`. Reescribirlo desde `BD/346` borraría esos cambios: para tocarlo, seguir el mismo patrón sobre la definición viva.

- **`SigmaModal` solo crece.** Mide con `scrollHeight`, que nunca baja del alto actual del marco: si la página de adentro pasa a algo más corto (la confirmación de alta después de la ficha), queda espacio en blanco. La confirmación fija el alto del marco (`frameElement`) a lo que se ve y llama a `SigmaModal.resize()`.

- **Las variables `--af-*` cuelgan de `.af` y de `.af-listo`.** Lo que viva fuera del contenedor del asistente no las recibe y se dibuja sin bordes ni fondos (le pasó a la confirmación de alta: sin círculo, sin cajas y con el botón Listo en blanco).

- **Combo SIGMA en una ficha del servidor.** Libre (lo escrito es el valor): un `asp:TextBox` con `data-sgcombo` dentro de `span.sg-combo`. Con id (lista cerrada): el mismo `TextBox` para el texto + un `asp:HiddenField` al lado para el id, que es lo que lee el servidor; el `CustomValidator` va contra el `TextBox` y `afValor` mira el oculto.
---

## 8. Recetas

### Compilar (obligatorio antes de dar algo por terminado)

```
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe" -v "/Check" -p "C:\Capstone\SIGMA\Web\Intranet" "C:\temp\salida" -f
```

Debe terminar en `exitcode=0`. Los `warning CS0168` son preexistentes.

### UTF-8 con BOM

Todo archivo nuevo o tocado. `Write` no lo agrega:

```powershell
$p = 'C:\ruta\Archivo.cs'
$t = [System.IO.File]::ReadAllText($p)
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($true)))
```

### Publicar una pantalla nueva

1. Model + Controller en `App_Code/MVC/SitioBase/`
2. `.aspx` listado (`Default.master`) + `.aspx` formulario (`Simple.master`)
3. **INSERT en `Menus`** con su `mnu_permiso` — sin esto no abre
4. `Menu_Funcion` para la facultad de escritura
5. El permiso al perfil que corresponda
6. UTF-8 con BOM + compilar

---

## 9. Bitácora

| Fecha | Qué se hizo |
|---|---|
| 28-08-2026 | Modelo desplegado: 232/232 tablas · limpieza de FacilityGes · diseño de marca · seguridad por datos · iconos a MDI · responsivo |
| 29-08-2026 | **Sprint 1 completo en base de datos** (bloques 25–39) y web construida. Contraseñas a hash. Perfiles base. Identificador por país. **Suscripción bloques A y B** (40–41) |
| 29-08-2026 | `root@codigocreativo.cl` no entraba: le habían cambiado la clave desde Mi Perfil. Restablecida a `1` por `UPDATE` directo. Ver §7 |
| 29-08-2026 | **Suscripción bloque C — la web.** 7 pantallas en `View/Comercial/Suscripciones/`, 5 modelos y 5 controllers nuevos, `IAlmacenamiento` contra Blob Storage (preparado, sin conectar), bloques SQL 42 y 43. Compila en `exitcode=0`; los scripts 42 y 43 quedan **sin ejecutar** |
| 30-08-2026 | **La API del Sprint 1.** 14 controllers en `Solucion/SIGMA/API` cubriendo las 17 historias, sobre una base transversal (`ErrorSql`, `ApiBase`, `Datos`, `Pagina`, `CacheCorta`, `SesionApi`) y JWT con usuario y cliente. Las rutas van **sin `/api/`** para no repetir la palabra. Compila en `exitcode=0`, **sin probar contra la base**. Las 55 tareas API quedan Terminada en el Sprint Backlog S1 y el daily del 30-08 quedó registrado como trabajo previo al sprint |
| 30-08-2026 | **Puntos abiertos cerrados.** Bloques **44, 45 y 46** escritos y ejecutados: mantenedor de planes con precio versionado, reemisión de la clave, y la matriz de qué incluye cada plan. `Plan.aspx` nueva. `SitioBase.Querystring` elimina el 500 del botón "Nuevo" en **las 28 fichas** del sitio. Shim de `$.browser` para jQuery UI. BOM auditado en todo el proyecto |
| 30-08-2026 | **Planta**: migrada al estándar y geocodifica la dirección con Google Maps (en el navegador, al salir del campo; no pisa coordenadas escritas a mano). Las otras 21 fichas heredadas quedan con el look nuevo por la capa de compatibilidad de `sigma-modal.css` |
| 30-08-2026 | **42 y 43 ejecutados** (`Perfiles` no `Perfil`; el orden bajo Comercial chocaba con "Cliente"). **MDI 7.4.47** instalado fuera de Adminto: ningún icono del sitio se veía. `Simple.master` ahora carga la marca. Nace `sigma-modal.css` y se migran las 3 fichas del bloque C. Corregidos: 500 al abrir "Nuevo" (`?query=0`), fichas en solo lectura por usar `PuedeFuncion`, permisos cacheados en `Session` sin caducar, y el mapa de URLs que no veía los `INSERT` en `Menus`. Bloque **44** escrito, sin ejecutar |

| 30-08-2026 | **Suscripción bloque D — los topes se aplican.** Bloque **47**: `FNC_CLIENTE_CONSUMO`, `FNC_CLIENTE_PUEDE_CREAR`, `SEL_CLIENTE_LIMITE`, `SEL_SUSCRIPCION_ESTADO_CLIENTE`, `INS_SUSCRIPCION_BLOQUEO_LOG`, guardas dentro de `INS_CLIENTE_INSTALACION` e `INS_CLIENTE_USUARIO`, y las 2 FK que le faltaban a `Cliente_Instalacion_Usuario`. En la web nace `SuscripcionAcceso` (la compuerta que llama el master, igual que `Token`) más el aviso del encabezado y `Renovar.aspx`. Los 6 estados probados contra la base; bajar de plan **no borra** lo que sobra (§8) |
| 30-08-2026 | **Bloque 48 — el bloqueo distingue por perfil.** Con la suscripción caída ahora solo entra quien tiene `RENOVAR SUSCRIPCION` (Administrador del Cliente, Root, Gerente Comercial); al resto lo rechaza `SEL_LOGIN` con `402` antes de crear sesión. Nacen `FNC_CLIENTE_PUEDE_OPERAR` y `FNC_USUARIO_PUEDE_RENOVAR`, y `~/Renovar.aspx` pasa a ser una fila en `Menus` con permiso propio en vez de una página exenta. Probado con los 7 usuarios de Hamburgo |

| 30-08-2026 | **Limpieza de pendientes.** `00_MAESTRO.sql` vuelve a ser completo: 53 bloques, con los demo separados y `07_ICONOS_MDI` que nunca había estado. Auditoría de `int.Parse` sobre columnas anulables en todo el sitio: 16 casos sin guarda, corregidos, auditoría en 0. `emilio` y `catalina` recuperan su clave |

| 30-08-2026 | **Bloque 49 — el acceso del usuario de cliente.** Se cierra la última capa de FacilityGes sin migrar: el perfil. `SEL_CLIENTE_USUARIO` reescrito —leía `Usuario_Perfil` en vez de `Cliente_Usuario_Perfil`, unía por `upe_id`, y **concatenaba `@FILTRO` en el WHERE: inyección SQL desde el buscador**—. Se separa `VER CLIENTES` de `VER TODO CLIENTES`. `Usuario_Perfil` poblado en espejo y sincronizado. `SEL_LOGIN` rechaza sin perfil (`403`). `Token.PuedeMenu` deja de fallar abierto. El árbol se reordena: Organización, Catálogos y Permisos por usuario pasan bajo **Cliente** |

| 30-08-2026 | **Bloque 50 — Planta, y el árbol en tres niveles.** `Cliente > Organización > Plantas/Áreas/Centros/Grupos/Especialidades`; `MenusLateral` emite `nav-third-level` y `sigma-layout.css` le da sangría (Adminto lo traía a medias, con un typo). "Instalación" pasa a "Planta" en los rótulos visibles —no en tablas ni SPs—. Y dos bugs en `DEL_USUARIO_ASOCIACION`: comparaba `ciu_id_usuario` contra el **ucl_id** (podía borrar la planta de otra persona) y no limpiaba el espejo `Usuario_Perfil`, así que un usuario desafiliado seguía entrando |

| 30-08-2026 | **Pérdida de datos silenciosa en la ficha parcial de planta.** `UPD_CLIENTE_INSTALACION` escribe la fila entera y protegía con `ISNULL` solo `cin_codigo`: guardar desde `Instalaciones/Identidad.ascx` —que muestra 4 campos— **borraba la zona horaria y las coordenadas**. Probado contra la base. Corregido en el llamador: relee la planta y pisa solo lo que edita. `AsociarUsuario` migrada a `sigma-modal-*`, y su encabezado ahora distingue los dos modos (planta / cliente) que el rótulo heredado confundía |

| 30-08-2026 | **Las 20 fichas heredadas migradas a `sigma-modal-*`** y la capa de compatibilidad retirada, junto con `sigma-modal-host` de `Simple.master`. 85 campos convertidos por script + 9 casos a mano (filas de dos campos, notas, formularios en línea). Verificado que ningún control cambió de `ID`. Antes de eso: **pérdida de datos silenciosa** en la ficha parcial de planta —`UPD_CLIENTE_INSTALACION` borraba zona horaria y coordenadas—, corregida en el llamador |

| 30-08-2026 | **Una sola ficha de planta.** `NuevaInstalacion.aspx` y su `Identidad.ascx` se retiran del sitio (a `_RETIRADO/`, con su porqué: el proyecto no está en git y borrar sería irreversible). Sus dos pestañas útiles —configuración de la app y responsables— se mudan a `Planta.aspx` como secciones que aparecen con la planta ya creada. `Planta.aspx` acepta ahora `IdCliente` por querystring, porque desde Comercial la ficha puede ser de otra empresa que la de la sesión. Bloque **51** saca su fila de `Menus` |

| 30-08-2026 | **Auditoría de despliegue.** 120/120 SPs y funciones desplegados; los 52 enlaces de `Menus` apuntan a archivos que existen; cero markup heredado en modales; cero `int.Parse` sin guarda; BOM en todo salvo `data.config`. Encontrado y corregido: **`MiCuenta.aspx` era inalcanzable** —enlazada dos veces en el encabezado, sin fila en `Menus` y sin exención, así que rebotaba al tablero para todos—; y las **dos últimas instancias** del perfil de tipo Sistema clavado, en `Comercial/Clientes/Cliente.aspx.cs` y `Clientes/Cliente/Usuarios.aspx.cs` |

| 30-08-2026 | **Bloque 52 — las seis decisiones abiertas, cerradas.** Soporte ve todo y no toca nada; Gerente Comercial ve la organización en solo lectura; nace **Prevencionista de Riesgos**; HU-010 pasa a **baja lógica**; y los tres dígitos verificadores (RUC PE, CUIT AR, RUC EC) implementados y probados contra identificadores reales de SUNAT, AFIP y SRI. "Declarar pago" se muda a `Renovar.aspx` y `Pago.aspx` pasa a pedir `DECLARAR PAGO SUSCRIPCION`. De paso: esa ficha **cargaba por id sin comprobar de quién era el pago** —al abrirla a los clientes habría dejado ver banco y monto de otra empresa—; ahora lo verifica. `View/Clientes/Cliente/Instalaciones.aspx` retirada por huérfana |

| 30-08-2026 | **Bloque 53 — el árbol del cliente, por tema.** Nacen los grupos **Usuarios** (usuarios, permisos, especialidades, grupos de trabajo) y **Configuración** (catálogos); Organización queda con los lugares. Corregido el `IndexOutOfRangeException` de `Usuarios.ascx`: tomaba `GetItems(CommandItem)[0]` cinco veces sin comprobar que la barra existiera, y no existe cuando la grilla está en una pestaña no seleccionada. Y la **cuarta instancia** de los ids de FacilityGes: `Cliente.ascx.cs` filtraba por `"3,4,5,6,7"` para las cuentas de plataforma, ocultándoles casi toda la gente del cliente |

| 30-08-2026 | **Primera pasada por navegador: cuatro cosas rotas.** (1) **`dbo.SPLIT` no existía** y tres SPs la llamaban — guardar un usuario reventaba y dejaba una transacción abierta; se crea como envoltura de `STRING_SPLIT` y `UPD_CLIENTE_USUARIO` gana `XACT_ABORT ON`. (2) Ese mismo SP guardaba la **contraseña en texto plano y sin sal**: por eso una cuenta editada desde la ficha ya no podía entrar. Reescrito: hashea, y vacío significa "no la cambies". Las cuentas dañadas se repararon rehasheando lo que tenían. (3) La **última copia viva del bug del `upe_id`** estaba ahí: metía el id de la fila de `Usuario_Perfil` en `cup_id_perfil`, así que cambiar de perfil violaba la FK. (4) La tabla **`App` no existía** y `SEL_CLIENTE_APP_INSTALACION` la consultaba: la sección "Configuración de la app" salía vacía. Bloques **54** (nombres de menú más cortos), **55** y **56** |

| 30-08-2026 | **Bloque 57 — la configuración de la app, funcionando.** Seis funcionalidades cargadas desde las historias del backlog, cada una ligada a la funcionalidad de plan que la vende. El SP filtra por plan, cae al valor por defecto cuando la planta no está configurada, y agrupa por TERRENO / VOZ / CONSULTA. En la web: el controller hacía `int.Parse` sobre `APP_TIPO` —que ahora es texto— y habría dejado la sección vacía otra vez; modelo, controller y control actualizados, con mensaje honesto cuando el plan no incluye ninguna |

| 30-08-2026 | **Artefactos Scrum al día.** Los seis Sprint Backlogs pasan de 880 tareas genéricas a **1.783 detalladas** que nombran el objeto: `SEL_ACTIVO`, `GET /api/activos`, `Activo.aspx`. Las 132 historias se cruzaron contra `sys.tables` y aparecieron **11 entidades sin modelar**. Reparto: desarrollo alternado Bryan/Emilio, base de datos entre los tres, y pruebas, documentación y validación de Catalina. Sprint 1: 17 historias En revisión, 1 Bloqueada, 0 Terminadas, **0 de 46 criterios verificados** —las pruebas son de Catalina y no han empezado—. Cargados los 5 impedimentos reales en la bitácora |

| 30-08-2026 | **El alcance de la app, corregido.** Cada una de las 132 historias tenia tareas de API, incluidas las que nadie abre desde un telefono. Se fijan tres reglas en [`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md) y salen **270 tareas (202 h)** de los seis backlogs: 243 endpoints que no consume nadie —la web llama a los SP directo— y 27 pantallas web de historias que son solo del tecnico. Bloque **58**: `Perfiles.per_ambito` y `Menus.mnu_ambito`, porque el perfil Tecnico tenia cuatro permisos que le abrian **ocho paginas .aspx** y entraba a la web a navegar la organizacion del cliente; ahora `SEL_LOGIN` lo rechaza con 403 y el mensaje le dice que entre por la app. Nacen `SEL_MENU_APP` y `GET /menus`: la navegacion de Flutter se resuelve por datos, igual que la de la web. Y el hallazgo grande: **la API no validaba ningun permiso** —solo que el token fuera valido, asi que el token de un tecnico servia para llamar `POST /clientes`—; nace `ExigirPermiso` y quedan **52 endpoints** con el suyo |

| 31-08-2026 | **La API se recorta a lo que la app usa.** 7 controllers a `_RETIRADO/API/` y 4 recortados a sus `GET`: de **64 endpoints a 21**. Entre los retirados iba el `ValuesController` de la plantilla de Visual Studio, que llevaba desde el primer día respondiendo en `.../API/values`. Y en los seis Sprint Backlogs: las listas de **Responsable** y **Estado** de la hoja Tareas no dejaban escribir nada —era **una sola validación de lista sin origen** cubriendo `G6:H<n>`, o sea las dos columnas con una lista vacía—; ahora son dos listas con su origen y su rango hasta la última fila real | Al anotarlas apareció que 8 de las 42 descartadas del S1 eran los `GET` de plantas, áreas y catálogos, que la app **sí** consume al sincronizar: vuelven a Terminada.

| 31-08-2026 | **Bloque 59 — lo que faltaba del modulo de suscripcion.** Al cerrar HU-190 y HU-194 aparecio que tres tareas no se sostenian: `DEL_PLAN_COMERCIAL` no existia (habia `DEL_PLAN_COMERCIAL_PRECIO`, que cierra un precio y no da de baja el plan) y `UPD_SUSCRIPCION_PAGO` tampoco (habia `UPD_SUSCRIPCION_PAGO_VERIFICAR`, que es otra operacion). Los nombres se parecen lo suficiente como para que un cierre en bloque pasara sin que nadie lo notara. **La baja del plan rechaza si hay suscripciones vivas** y arrastra precios y funcionalidades; en la web, dar de baja desde la ficha pasaba por `UPD_PLAN_COMERCIAL` —que no comprueba nada— y ahora pasa por la guarda. **Corregir un pago** no es verificarlo: arregla monto, fecha, banco y operacion, no acepta cambiar de periodo, rechaza si ya esta verificado, y un rechazado corregido vuelve a DECLARADO. 8 casos probados contra la base dentro de transacciones revertidas: la base quedo igual |

| 31-08-2026 | **Bloques 60 y 61 — el modulo del bodeguero, completo.** Las 16 tablas de inventario estaban creadas desde las fundaciones y **no habia un solo SP**: el modelo llevaba meses listo y nadie lo habia tocado. Se construyen las 7 historias del bodeguero (HU-050, 052, 053, 054, 055, 056, 057) en base, web y API. **Un solo `INS_INVENTARIO_MOVIMIENTO` para los ocho tipos**: lo dificil de un inventario no es insertar la fila, es que `Inventario_Saldo` no se despegue de `Inventario_Movimiento`, y con seis procedimientos hay seis copias de esa logica. Idempotente por uuid, que es la unica defensa real contra el doble consumo cuando el telefono reintenta. En la web: 8 pantallas, 4 controllers, 3 modelos. En la API: 4 controllers, solo lo que la app usa. **18 casos probados contra la base** dentro de transacciones revertidas —incluido que el saldo cuadre con la suma de los movimientos—. Dos huecos del modelo tapados: `Unidad_Medida` estaba VACIA y `rep_unidad_medida` es NOT NULL, asi que no se podia crear ni un repuesto; y faltaba `rep_controla_lote`, sin la cual el criterio 2 de HU-054 no se puede cumplir |

| 31-08-2026 | **Bloque 62 — el boton que no aparecia, y lo que salio buscandolo.** Root no veia "Nuevo" en Bodegas ni en Repuestos: el bloque 60 creo las 8 filas de `Menus` y **ninguna de `Menu_Funcion`**. `Token.PuedeFuncion` busca la funcion de la pagina en el mapa que sale de esa tabla y sin fila devuelve `false` **para todos, Root incluido**; no hay error, solo una pantalla sin boton. Ya habia pasado con las fichas de suscripcion, asi que la regla queda escrita en `PATRONES/ASP/CHECKLIST_ENTIDAD_NUEVA.md` §5: **cada menu nuevo lleva su `Menu_Funcion`**. Buscandolo aparecio algo mas serio: hay **dos implementaciones de "tiene este permiso" que no coinciden**. `SEL_USUARIO_PERMISOS` tiene la regla "Root ve todo"; `FNC_USUARIO_TIENE_PERMISO` no, y ademas exige una fila en `Cliente_Usuario` que Root **no tiene** —es cuenta de plataforma—, asi que le devolvia 0 para TODO permiso. `SEL_MENU_APP` usa esa funcion: el arbol de la app le habria salido vacio a Root. Corregido. Queda **una decision abierta** (§6): el SP cuenta los perfiles de `Usuario_Perfil` y la funcion no, pero esa tabla esta poblada **en espejo** desde el bloque 49, asi que igualarlas sin pensar le daria a un usuario sus permisos en cualquier cliente |

| 31-08-2026 | **Bloque 63 — la vida util esperada del repuesto.** `Repuesto` traia `rep_vida_util_hora`, `_dia` y `_ciclo` desde las fundaciones y `SEL_REPUESTO` las devolvia, pero `INS_` y `UPD_REPUESTO` **no las recibian**: la consulta leia tres columnas condenadas a estar en NULL. Descuido del bloque 60. Tres medidas y no una a proposito —un rodamiento dura HORAS de marcha, un filtro de aire dura DIAS gire o no gire el equipo, un contacto dura CICLOS— y pueden convivir. Nace `@LIMPIA_VIDA_UTIL`: con `ISNULL(@X, columna)` un campo vacio significa "no lo toques", lo que hace **imposible borrar** un valor mal cargado; la bandera separa "no lo mandé" de "quiero borrarlo". 4 casos probados. **Esto es la vida util ESPERADA; la REAL es HU-058** y se calcula sobre `Componente_Repuesto_Instalacion`, que hoy **no la escribe nadie**: la fila nace cuando un tecnico instala o retira la pieza en una orden de trabajo (Sprint 5) |

| 31-08-2026 | **Bloques 64 y 65 — los datos de prueba, y el bug que destaparon.** Sembrado el inventario de Hamburgo / Planta Santiago con prefijo `DEMO-`: 2 bodegas, 7 ubicaciones, 10 repuestos, 8 umbrales, 2 lotes y 15 movimientos, elegidos para que se vean **todos** los estados —uno bajo el minimo, uno sobre el maximo, dos sin umbrales, dos que controlan lote—. Los 10 saldos cuadran con la suma de sus movimientos. **Sembrar destapo el bug:** las 8 llamadas a `UPS_REPUESTO_BODEGA_STOCK` dejaron **una sola fila**. En SQL Server un `SELECT @ID = col FROM ... WHERE <sin filas>` **NO toca la variable**, y los controllers de la web crean el parametro de salida con `AddWithValue("@ID", 0)`, asi que @ID entra valiendo 0: el SP se iba por la rama del `UPDATE ... WHERE rbs_id = 0` y **guardaba cero filas sin dar ningun error**. La misma trampa estaba en `INS_REPUESTO_LOTE` -respondia "el lote ya existia" para uno que no existe- y armada en `INS_INVENTARIO_MOVIMIENTO`, donde habria hecho que **todo movimiento con uuid se descartara en silencio**, que es justo la idempotencia de la que depende la app. Los tres con `SET @ID = NULL`. De paso, `INS_INVENTARIO_MOVIMIENTO` ahora valida que la orden de trabajo exista **y sea del cliente**: antes lo unico que ataja un numero inventado era la FK, con su mensaje en ingles, y una orden de otra empresa pasaba |

| 31-08-2026 | **Las cuatro fichas del inventario se abrian en blanco.** Editar un repuesto, una bodega, una existencia o un movimiento abria el modal sin datos. Causa: **doble descifrado**. `Querystring.Entero` descifra por dentro, y las cuatro fichas le pasaban el resultado de `Descifrar` —o sea el texto ya plano—, asi que la segunda pasada fallaba. Y como el helper **no lanza por diseño**, devolvia 0 en silencio: `Id = 0` es "registro nuevo", asi que la ficha se abria vacia sin ningun error, ni en pantalla ni en log. Las cuatro pasan a la forma de una linea que ya usaban Pago, Periodo, Plan y Suscripcion. El `<summary>` de `Querystring.Entero` ahora dice explicitamente que recibe el valor **tal como viene de la URL**, con el ejemplo de lo que NO hay que hacer |

| 31-08-2026 | **Las tres grillas del inventario, legibles.** `Existencias`: la cantidad y su umbral pasan a la MISMA celda —repartidos en tres columnas la comparacion la hace el ojo saltando de lado a lado— con badge de estado que dice **cuantas faltan**, franja de color en la fila en vez de fondo completo, y el aviso de arriba separa "bajo el minimo" de "sobre el maximo", que no son el mismo problema. `Movimientos`: badge por familia con color e icono —verde entra, rojo sale, ambar se corrigio, azul se movio— y el motivo detras de una **lupa con popover**, porque una frase de seis lineas en la grilla empuja fuera de pantalla la cantidad. `Repuestos`: la columna BODEGAS decia "1, 2, 0" sin explicar nada, y el 0 —que significa **sin existencia**— era el dato mas importante escrito como si fuera un detalle; ahora va junto a la cantidad, y fabricante y modelo bajan a segunda linea porque se usan para BUSCAR, no para comparar filas. En el camino: **`is-ok` no existe** en el CSS —la variante es `is-exito`— y estaba usada en 4 lugares, o sea 4 chips sin color; y faltaba la variante **ambar**, que es la que le corresponde a lo que pide atencion sin estar mal. Bloque **66**: el menu se reordena por dependencia, Bodegas primero |

| 31-08-2026 | **Los cuatro listados de inventario adoptan `wucFiltro`.** Habian nacido **sin buscador** —la nota al pie de Repuestos hasta prometia uno que no existia en pantalla— y el filtro de estado que se agrego primero era una barra propia, fuera del patron. Ahora los cuatro usan el control estandar en `cphFiltro`, con sus combos dentro de `FiltroPersonalizado`, y el texto libre viaja al `@FILTRO` **parametrizado** de cada `SEL_`. Filtros: Bodegas por planta y habilitada; Repuestos por controla-lote y con/sin existencia; Existencias por estado y bodega; Movimientos por tipo y bodega. El estado sale de **una sola funcion** `EstadoCodigo`, que alimenta el chip y el filtro: si el combo clasificara por su cuenta, tarde o temprano el filtro devolveria filas cuyo chip dice otra cosa. Bloque **67**: `SEL_INVENTARIO_MOVIMIENTO_TIPO`, para no escribir el catalogo de tipos a mano en el markup. La regla queda en el checklist |

| 31-08-2026 | **El lote: donde se entra y donde se consulta.** Se entraba solo en el ingreso de `Movimiento.aspx` —correcto, porque nadie sabe el numero de lote hasta que llega el camion— pero **incompleto**: la pantalla mandaba solo el codigo, asi que todo lote creado desde la web nacia **sin fecha de vencimiento** y no habia ninguna pantalla para arreglarlo. En un repuesto que controla lote eso vacia el proposito: se controla el lote justamente para poder avisar que vencio. Ahora el ingreso pide el vencimiento, y el combo lista **todos** los lotes y no solo los vigentes —un lote vencido que sigue en la estanteria hay que poder moverlo para darlo de baja por merma; esconderlo obligaba a inventar otro—. Y nacen los **lotes en la ficha del repuesto**, en solo lectura y solo si los controla, con chip por vencimiento: vencido, vence en menos de 60 dias, o sin fecha —que se dice, porque es un dato que falta, no una eleccion— |

| 31-08-2026 | **Trazabilidad, pestanas y secciones en el inventario.** Las seis tablas llevaban sus cuatro columnas de auditoria desde las fundaciones y los SP las escribian, pero **ningun `SEL_` las devolvia**: el dato existia y solo se podia leer por SSMS. Bloque **68**: los cinco `SEL_` devuelven usuario y fecha de creacion y actualizacion, con el NOMBRE y no el id, y nace `UPD_REPUESTO_LOTE` —un lote con la fecha mal puesta no se podia corregir desde ninguna parte—. Nace el control **`wuc:Auditoria`**, al pie de toda ficha. Bloque **69**: `@USUARIO` en `SEL_INVENTARIO_MOVIMIENTO` y `SEL_INVENTARIO_MOVIMIENTO_USUARIO`, que lista **solo a quienes registraron algun movimiento** —con todos los usuarios del cliente serian decenas que nunca tocaron el inventario—. En la web: Movimientos gana filtro por tipo, bodega, usuario y rango de fechas; las fichas de Repuesto y Bodega pasan a **pestanas** (`RadTabStrip2`) y su formulario queda **seccionado**; y el CSS del RadTabStrip se adapta del proyecto Workges a los tokens de SIGMA —violeta de marca, plano, sin el degradado azul del original— |
| 31-08-2026 | **Los formularios dejan de desperdiciar pantalla.** La rejilla de campos usaba `repeat(auto-fit, minmax(260px, 1fr))`, que en un escritorio ancho daba seis columnas — pero cualquier campo `is-ancho` ocupaba la fila entera y **cortaba la que se venia armando**: una fila de "ID + Codigo" seguida de un "Nombre" ancho dejaba cuatro columnas vacias a la derecha. Ahora son **doce columnas fijas** y cada campo declara cuanto mide (`is-mini`, `is-chico`, `is-medio`, `is-mitad`, `is-grande`, `is-ancho`); doce divide por 2, 3, 4 y 6, asi que casi cualquier combinacion cierra la fila exacta. La ficha de Repuesto pasa de cinco filas a **dos**. Ademas cada campo era una tarjeta con borde y 14px de relleno con un input adentro que trae **su propio borde**: dos bordes concentricos a 4px, y 28px de alto por fila sin aportar nada. Se elimina la caja. Para que la fila no quede escalonada, el rotulo mide siempre 15px y todo control arranca a 38px — un input, un combo, dos radios y un valor de solo lectura median distinto y ninguna fila alineaba. El encabezado de seccion tenia la linea bajo el rotulo, dejando la ayuda **del lado de los campos**, donde se leia como ayuda del primer campo; la linea pasa a cerrar el encabezado completo |
| 31-08-2026 | **El saldo pasa a llevarse por ubicacion y por lote.** `Inventario_Saldo` tenia la llave (cliente, repuesto, bodega): la ubicacion vivia solo en el movimiento, era "donde se dejo la ultima vez" y no "donde esta". Eso alcanza mientras nadie le pregunte a un estante que tiene adentro — en cuanto se imprime una etiqueta de ubicacion y se escanea, la respuesta tendria que **inventar un numero**. Bloque **71**: la llave pasa a (cliente, repuesto, bodega, ubicacion, lote). El lote entra en la MISMA migracion y no en una posterior, porque el saldo se reconstruye una sola vez. `Repuesto_Lote` **no tenia columna de cantidad**: en ninguna parte estaba escrito cuantas unidades vinieron en un lote, y nace `SEL_REPUESTO_LOTE_SALDO` con RECIBIDO / CONSUMIDO / QUEDA / dias para vencer, mas `SEL_REPUESTO_LOTE_UBICACION`. Tambien el tipo **9 REUBICACION** — cambiar de estante dentro de la misma bodega no tenia representacion, y la unica forma de corregir una ubicacion era una salida y una entrada, que ensucia el libro con movimientos que nunca ocurrieron — y `SEL_REPUESTO_UBICACION_HISTORIAL`, `SEL_UBICACION_DESGLOSE`, `SEL_BODEGA_DESGLOSE` |
| 31-08-2026 | **La reconstruccion del saldo hubo que hacerla reproduciendo el libro.** El primer intento agrupaba los movimientos por cubo y sumaba: **reviento contra `CK_ISA_CANTIDAD`**. Las entradas traian ubicacion y las salidas no, asi que las entradas caian en el estante y las salidas en el cubo nulo, que quedaba negativo mientras el estante conservaba todo. El total por bodega daba bien y **cada cubo daba mal** — el mismo error que se quiere dejar de cometer: un total correcto compuesto de partes falsas. La transaccion se deshizo sola, como estaba previsto. Se rehizo recorriendo los movimientos **en orden cronologico**, con asignacion **FIFO** cuando la salida no dice de donde sale. No se reescribe el libro: rellenar la ubicacion de las salidas viejas con la que FIFO eligio dejaria la trazabilidad viendose completa, y seria mentira — nadie registro esa ubicacion, la elegimos nosotros. Resultado verificado: los totales por bodega cuadran y **cero cubos negativos** |
| 31-08-2026 | **El movimiento mantiene el saldo por cubo, y la ubicacion se vuelve obligatoria.** Bloque **72**, obligatorio inmediatamente despues del 71: `INS_INVENTARIO_MOVIMIENTO` quedaba escribiendo con la llave vieja (`WHERE isa_repuesto = X AND isa_bodega = Y`), que ya no identifica una fila sino **todas las de esa bodega** — un ingreso de 5 habria sumado 5 a cada estante. Entre el 71 y el 72 el modulo esta roto; no se puede dejar a medias. Ahora el saldo suficiente **se mide en el cubo y no en la bodega**: que la bodega tenga 50 no ayuda si en ESE estante hay 2. La ubicacion pasa a ser obligatoria **solo si la bodega tiene estantes definidos** — una bodega sin estanteria sigue operando entera, y no se le exige un dato que no le aplica. Cinco pruebas contra la base, dentro de una transaccion deshecha: salida sin ubicacion rechazada, salida mayor que el estante rechazada, reubicacion 5 -> 3+2 correcta, reubicacion al mismo estante rechazada, y el total de la bodega intacto tras reubicar |
| 31-08-2026 | **Editar una ubicacion, y la descarga de repuestos.** Las ubicaciones se podian crear y no corregir: un codigo mal tipeado obligaba a dejarlo o a crear otra. `UPD_BODEGA_UBICACION` ya existia, faltaba la pantalla. Se agrega el lapiz por fila, con "Cancelar" que **solo aparece editando** y el boton que cambia a "Guardar ubicacion" — el mismo rotulo "Agregar" mientras se edita una fila promete un alta y hace una modificacion. El **codigo no se puede cambiar** al editar: identifica la ubicacion y ya esta impreso en la etiqueta del estante; cambiarlo dejaria las etiquetas pegadas apuntando a algo que no existe. Bloque **70**: `RPT_REPUESTO_EXCEL`, `RPT_REPUESTO_PLANTILLA` y `RPT_UNIDAD_MEDIDA_EXCEL`, **parametrizados** y no concatenando el filtro dentro de un VARCHAR como hace `RPT_CLIENTE_USUARIO_CARGA_MASIVA` — eso es lo que se corrigio en el bloque 49 y era inyeccion SQL. La plantilla usa **los mismos encabezados** que la descarga, para que exportar, editar y volver a cargar sea un ciclo cerrado |
| 31-08-2026 | **El listado de existencias vuelve a una fila por repuesto y bodega.** Defecto que introdujo el bloque 71 y que se detecto verificando: al partir el saldo por cubo, `SEL_INVENTARIO_SALDO` -un SELECT plano sobre la tabla- empezo a devolver **una fila por cubo**, y DEMO-ROD-6205 salia dos veces en la misma bodega. Lo grave no era la fila repetida: **BAJO_MINIMO comparaba el umbral contra la cantidad de UN cubo**, asi que un repuesto con minimo 3 y tres unidades repartidas en dos estantes disparaba alerta roja en ambos teniendo exactamente lo que debia. El nivel de la pregunta no es el nivel del dato: el saldo se guarda por cubo porque un estante tiene que poder decir que tiene, pero el umbral esta definido en `Repuesto_Bodega_Stock` por (repuesto, bodega) — nadie fija un minimo por estante. Bloque **73**: el listado agrupa y la alerta se calcula donde el umbral esta definido; el costo promedio se pondera por la cantidad de cada cubo, porque promediar los promedios daria el mismo peso a un estante con 300 litros que a uno con 2. Se agregan `UBICACIONES` y `LOTES`, y `UBICACION_CODIGO` cambia de significado: antes era "donde lo dejaron la ultima vez" sacado del ultimo movimiento —una aproximacion, porque ese movimiento pudo ser una salida—, ahora es donde ESTA cuando hay una sola, y **NULL cuando esta repartido**, en vez de elegir una arbitrariamente para llenar el hueco |

| 31-08-2026 | **Sprint 2 · HU-035 — Registrar un activo (Emilio).** Primera entidad del Sprint 2, construida de punta a punta sobre la plantilla de `Centro_Costo` y `Bodega`. **T-2001**: el modelo `Activo` ya existía desde el bloque 11; se revisó y se confirmó el índice único del código por cliente —`UX_ACT_CLIENTE_CODIGO (act_cliente, act_codigo)`, que es el escenario 2 de la HU—, garantizándolo de forma idempotente en el bloque 74 por si faltara. **Bloque 74** (T-2002 a T-2005): `SEL_ACTIVO` con el patrón dinámico `@SELECT/@FROM/@WHERE`, `@FILTRO` **parametrizado y escapado** (código, nombre, serie, fabricante), `ORDER BY act_codigo` estable —el código es único por cliente, así que no hay empates— y **las cuatro columnas de auditoría con el nombre del usuario** por `LEFT JOIN Usuario`, un solo SP para grilla y ficha; `INS_ACTIVO` en transacción, valida código único por cliente y que la planta y el padre sean del mismo cliente, y **sella la fecha con `FNC_PAIS_HORA`** (SIGMA opera en cinco países); `UPD_ACTIVO` con `ISNULL(@X, columna)` en lo que la ficha podría no traer; y `DEL_ACTIVO` que es **baja lógica** —`act_habilitado = 0` + `act_fecha_baja`, no borrado físico: un activo tiene historia— y **rechaza si tiene subactivos habilitados** en vez de dejarlos huérfanos. Se crearon además `SEL_ACTIVO_TIPO/_ESTADO/_CRITICIDAD_NIVEL` para poblar los combos (el estándar prohíbe escribir un catálogo a mano en el `.aspx`). **Bloque 75** (T-2006): tipos globales (motor, bomba…) y 4 activos demo en Hamburgo, resueltos los ids en tiempo de ejecución para no asumir "la planta es la 1". **Bloque 76** (T-2013): nodo `Activos` de nivel 2 junto a Inventario, las dos filas en `Menus` (listado + ficha con `mnu_orden 99` / `mnu_visible 0`), los permisos `VER ACTIVOS` / `CREAR EDITAR ACTIVOS`, la fila en **`Menu_Funcion`** —`Crear y editar`, sin la cual el botón "Nuevo" no aparece ni para Root— y `Perfil_Permiso`. **Web** (T-2011, T-2012, T-2014): `Activos.aspx` con grilla, buscador `wucFiltro`, filtro de habilitados y botón Nuevo; `Activo.aspx` en `RadWindow2` con las clases `sigma-modal-*` seccionadas (Identificación, Ubicación, Ficha técnica), combos por `SEL_`, validadores y `wuc:Auditoria`; `Activo.cs` + `ActivoController.cs` (con los tres controllers de lookup). **La seguridad es en el servidor**: el listado filtra siempre por `Session.ClienteId()` —barrera multicliente—, `Token.PuedeFuncion` decide la barra de comandos y `Token.Puede("CREAR EDITAR ACTIVOS")` bloquea la ficha, no el esconder el botón. **Compila en `exitcode=0`.** Los bloques SQL **74, 75 y 76 se ejecutaron contra la base** con sus comprobaciones en verde (2 permisos, 2 pantallas, 1 función; 4 tipos globales y 4 activos demo en Hamburgo). Los cinco SP se **probaron contra la base dentro de transacciones revertidas**: alta correcta, código duplicado rechazado con mensaje claro, edición, baja lógica (`act_habilitado=0` + `act_fecha_baja`) y el rechazo de la baja cuando el activo tiene subactivos habilitados. Queda pendiente **la prueba en navegador** (listar/filtrar/crear/editar/dar de baja, y con un usuario sin permiso) |

| 31-08-2026 | **La fecha de puesta en marcha del activo pasa a calendario.** La ficha `Activo.aspx` capturaba `act_fecha_puesta_marcha` como un `TextBox2` con formato `dd-mm-aaaa` y parseo a mano (`LeerFecha`). Se reemplaza por el control **`WebControls:Calendar`** que pide el estándar (`PATRONES/ASP/Desarrollo/PATRON_CONTROLES.md` §5.4): su `.Value` es `DateTime?`, se lee y escribe directo sin parsear, y en solo lectura se apaga con `.Enabled`. Se elimina `LeerFecha` y el `using System.Globalization`; queda solo la guarda de "no futura". Es el mismo control que ya usa `UsuarioEspecialidad.aspx` para "Vence el". El año de fabricación sigue siendo texto: es un número de cuatro dígitos, no una fecha. **El icono del calendario queda a la derecha del input, no debajo:** `DateBox.Render` (en `Librerias/Library/Web/UI/WebControls/DateBox.cs`) emite el `<input>` y, como hermano, el `<a>` del icono del `PopCalendar`; dentro del `.sigma-modal-field` —que apila en columna— el icono caía en la línea siguiente. Se envuelve el control en un `div.sigma-modal-fecha` (fila, `flex`) con su regla en `sigma-modal.css`: el input encoge para dejarle lugar al icono en vez de empujarlo fuera de la celda. Es el contenedor reutilizable para toda fecha nueva. Compila en `exitcode=0` |
| 31-08-2026 | **Motor de etiquetas con QR y escaneo con la camara del telefono.** Un solo `SEL_ETIQUETA` con `@ORIGEN` devuelve SIEMPRE las mismas columnas —TOKEN, CODIGO, TITULO, SUBTITULO, DETALLE, PIE— para bodegas, estantes, estante-con-repuesto, repuestos y activos: la pantalla que imprime **no sabe que esta imprimiendo**. `QRCoder.dll` ya estaba en `Bin` (version 1.0, API antigua: devuelve `Bitmap`, no bytes PNG), asi que cero dependencias nuevas; verificado en ejecucion, 294x294 px, ~287 dpi impresos. El QR se genera en el **controlador y no en la pantalla**: si dependiera de que la pagina se acuerde, la primera que lo olvide imprime una tirada entera de etiquetas inservibles. Va **embebido como data URI**, porque una hoja de 24 serian 24 peticiones y basta que una llegue tarde para que salga un recuadro vacio sobre una etiqueta que igual se va a pegar. Correccion de errores en **Q** y no en L: una etiqueta de bodega se raya, se moja y junta polvo. El **token del QR va en claro**, unica excepcion del sitio: una etiqueta pegada dura anos y el cifrado depende de una clave que algun dia cambia —ese dia habria que reimprimir la bodega entera—; lo que protege el dato es la pagina, que exige permiso, y el SP, que filtra por cliente |
| 31-08-2026 | **El codigo de la etiqueta no se recorta nunca, y el escaneo es mobile-first.** Llevaba `text-overflow: ellipsis` y DEMO-BOD-CENTRAL salia impreso como "DEMO-B...": una etiqueta cuyo codigo no se puede leer no sirve para nada, es el dato por el que existe. Ahora se parte en dos lineas y **el tamano lo decide su largo desde C#**, porque CSS no sabe cuantos caracteres vienen; verificado midiendo los 18 casos con JavaScript, ninguno desborda ni a lo ancho ni el alto fijo. El escaneo se rehizo **para la camara del telefono, no para pistola**: la camara nativa ya lee el QR —que guarda la URL completa— y abre la pantalla resuelta, sin permisos ni HTTPS. La camara EN pantalla usa `BarcodeDetector` sin biblioteca externa, y comprueba ANTES de pedirla que haya **HTTPS** y soporte —falta en Safari de iPhone—, diciendo cual de los dos falta en vez de dejar un boton que no responde. Boton de 56px porque se toca **con guantes**, y el desglose en tarjetas con la cantidad como elemento mas grande: es el numero que se compara contra lo que se tiene en la mano |
| 31-08-2026 | **Centro de etiquetas: el catalogo de lo imprimible es una tabla.** `Etiqueta_Origen` con codigo, nombre, icono, **permiso propio**, si admite filtro por bodega, y motivo cuando esta apagado. `CentroEtiquetas.aspx` lee esa tabla y dibuja lo que haya: agregar un modulo imprimible es un INSERT mas una rama en el SP, sin tocar ninguna vista —la misma idea que ya gobierna el menu y los permisos—. Cada origen declara SU permiso, asi que la pantalla no tiene una segunda copia de que permiso corresponde a que modulo. Los origenes apagados **se muestran con su motivo**: esconderlos haria pensar que el sistema no contempla ese modulo, y mostrarlos grises y mudos, que algo se rompio. La lista de ubicaciones de la bodega deja RadGrid por un **Repeater**: cinco a treinta estantes no tienen nada que paginar ni ordenar, y el modo InPlace dibujaba sus propios botones como texto plano en ingles —"Edit", "Update Cancel"—. Se edita **en la fila**: cargar la fila en el formulario de arriba dejaba dudando si se editaba esa o se creaba otra |
| 31-08-2026 | **Codigo automatico: prefijo del modulo mas ID.** Bloque **77**: `Modulo_Codigo` con los once modulos que tienen ficha, `FNC_CODIGO_AUTOMATICO`, y los once `INS_` generan `ACT-31`, `BOD-9`, `UBI-17`. El prefijo **coincide con el del QR**, asi que el codigo impreso y el token escaneado son la misma cadena. Alcance deliberado: de las ~110 tablas con columna de codigo, solo las 11 con `INS_` y ficha; el resto son catalogos donde el codigo es SEMANTICO y es la llave por la que se busca —`CLP`, `KG`, `PENDIENTE`— y convertir `CLP` en `MON-3` romperia cada consulta que compara por codigo, incluida la del propio motor de etiquetas. **El primer intento fallo en 7 de 11 y en silencio**: siete estan escritos como `CREATE` con TRES espacios y `PROCEDURE`, el literal no calzo, `CHARINDEX` devolvio 0, `STUFF` con posicion 0 devuelve NULL, y `sp_executesql` con NULL **no hace nada y tampoco falla**. Se dejo de tocar la cabecera: `DROP` y recrear dentro de una transaccion. Los registros existentes CONSERVAN su codigo: reescribirlos dejaria sin valor las etiquetas ya impresas |
| 31-08-2026 | **El sentinela AUTO, y por que no vacio.** Las ocho fichas con codigo dejan de pedirlo: campo de solo lectura con la ayuda "Se genera solo al guardar". El primer intento mandaba **cadena vacia**, y probandolo contra la base se vio que los SP **validan el codigo ANTES del insert**: cada alta habria fallado con "indique el codigo". Va `AUTO`, que pasa esa validacion y nunca queda guardado; verificado `UBI-26` y `BOD-11`, con los codigos escritos a mano y los antiguos intactos. Queda anotada la advertencia: en ubicaciones el codigo legible ES la funcion —`PA-E3-N2` es "Pasillo A, Estante 3, Nivel 2" y el bodeguero camina leyendolo— asi que ahi el campo se sigue admitiendo a mano y solo se genera si se deja vacio. `CatalogoValor.aspx` queda fuera por la misma razon que los catalogos de la base |
| 31-08-2026 | **El arbol de trabajo fue reemplazado a mitad de sesion, y se recupero lo perdido.** Una sesion paralela dejo el modulo de Activos (`View/Activos`, `ActivoController`, bloques 74-76) y su arbol sobrescribio el motor de impresion completo, sus CSS y JS, los bloques SQL 74-77 y los cambios de `Bodega.aspx`. **La base habia conservado lo ejecutado**, asi que quedaron dos menus visibles apuntando a paginas inexistentes. Se rehizo todo lo propio SIN tocar lo de Activos, renumerando los bloques a 77 y 78. De paso se integro: la etiqueta de activo estaba apagada porque cuando se registro no habia modulo —una etiqueta que se escanea y no lleva a ninguna parte se pega en una maquina y ahi se queda— y ahora que la ficha existe se encendio con un **UPDATE de una fila**, que era justamente el punto de haber dejado el catalogo en tabla. Escanear `ACT-<id>` abre esa ficha |
| 31-08-2026 | **Carga y descarga masiva de repuestos.** La carga **reusa `InsertRepuesto` fila por fila** y no escribe su propio INSERT: con un INSERT propio habria que repetir cada validacion del SP —codigo unico, unidad que exista, lote— y esas copias se desincronizan a la primera regla nueva. Pasando por el mismo camino que la ficha, lo que se puede crear a mano es exactamente lo que se puede cargar en masa. **Una fila mala no detiene la carga**: cada una va en su propio try, y con cien repuestos que la numero 40 tenga la unidad mal escrita no puede obligar a rehacer la planilla —se cargan 99 y se informa cual fallo, con su numero de fila y el motivo—. La plantilla lleva una **segunda hoja con las unidades validas**, porque sin ella se escribe "unidades", "un", "u." y cada una falla sin que se entienda por que; y una fila de ejemplo que la carga **ignora sola** por su codigo, asi que da lo mismo si se olvida borrarla. El SI/NO es tolerante (SI, S, 1, TRUE, X) y los numeros se prueban con la cultura del servidor Y con punto decimal, porque una planilla puede venir de un Excel en ingles y "1500.50" no debe volverse 150050. El **codigo puede ir vacio**: se genera como REP-<id>, igual que en la ficha |
| 31-08-2026 | **La descarga dice lo que hace, y las acciones salen de la grilla.** `RPT_REPUESTO_EXCEL` respeta el **texto buscado**: bajar el catalogo entero cuando la pantalla muestra diez filas es una sorpresa desagradable, y con cinco mil repuestos un archivo inutil. Pero los combos de lote y existencia los aplica la grilla **en memoria** —uno mira una columna, el otro un SUM que el SP calcula— asi que el RPT no los conoce: antes de inventarles parametros, el tooltip dice la verdad, "baja los repuestos que coinciden con la busqueda". Los tres accesos —crear, descargar, cargar— pasan del `CommandItemTemplate` de RadGrid a una **barra propia**: un control ahi dentro NO es un campo de la pagina, el code-behind no puede nombrarlo, y la descarga no compilaba. Ademas las tres son la misma tarea y juntas se eligen de un vistazo. El boton de descarga se registra como postback completo: escribe un binario en la respuesta, y eso no sobrevive a un UpdatePanel que espera un fragmento |
| 31-08-2026 | **Pestanas en la existencia y secciones en la ficha del cliente.** `Existencia.aspx` tenia sus dos grillas apiladas —"Donde esta" y "Ultimos movimientos"— y en una ventana modal eso significa que la mitad de la ficha no se sabe que existe. Pasan a `RadTabStrip2`, con el hero **arriba** de las pestanas: es la identidad del repuesto, no una de sus vistas. En Cliente, `Cliente.ascx` ya usaba pestanas; lo que faltaba era seccionar `Identidad.ascx` —diez campos leidos como una lista plana—, que ahora agrupa **Identificacion / Localizacion / Estado**, con la nota de que el pais decide como se rotula la identificacion (RUT, RUC, CUIT) y en que huso se leen las fechas. **No se reescribio su rejilla Bootstrap heredada**: ahi viven los validadores y el cargador de avatar, y rehacerla es donde esta el riesgo sin ganancia; solo se insertaron los rotulos entre los grupos que ya existian |
| 31-08-2026 | **El codigo de ubicacion tambien pasa a generarse.** Queda igual que las otras siete fichas: campo retirado del formulario y `UBI-<id>` automatico. Se deja anotado el costo, que era real: hasta hoy el codigo lo escribia una persona con significado —`PA-E3-N2` es "Pasillo A, Estante 3, Nivel 2" y el bodeguero camina leyendolo—. La nota de la pantalla se reescribio en consecuencia: ahora pide que ese significado vaya en el **nombre**, que es lo que se muestra al consultar un repuesto. Los registros existentes conservan su codigo |

| 31-08-2026 | **Sprint 2 · HU-042 — Configurar el medidor de un activo (Emilio).** Segunda entidad del Sprint 2, sobre la misma plantilla. **T-2018**: el modelo `Activo_Medidor` ya existía (bloque 11); se revisó y se confirmó su índice único. **Hallazgo y decisión**: el código del medidor es único **por activo** (`UX_AME_ACTIVO_CODIGO (ame_activo, ame_codigo)`), no por cliente como decía la plantilla de la tarea. Es lo correcto: un activo no puede tener dos "HOROMETRO", pero dos activos distintos sí; `INS_`/`UPD_` validan por activo. **Probado contra la base**: mismo código rechazado en el mismo activo, permitido en otro. **Bloque 77** (T-2019 a T-2022): `SEL_ACTIVO_MEDIDOR` (dinámico, `@FILTRO` escapado, auditoría con nombre de usuario), `INS_` en transacción con código único por activo, `UPD_` con `ISNULL` y el activo inmutable, `DEL_` baja lógica que **rechaza si el medidor tiene lecturas** (`Activo_Medidor_Lectura`). Otra decisión: `ame_fecha_valor_actual_utc` se sella con `GETUTCDATE()` —su sufijo `_utc` lo pide; la app compara lecturas de husos distintos—, mientras la auditoría va con `FNC_PAIS_HORA`. **Bloque 78** (T-2023): sembró las unidades que un medidor necesita —**horas, ciclos, kilómetros**, que no existían (solo había unidades de inventario)— y 4 medidores demo en Hamburgo. Un índice filtrado permite una sola unidad base por magnitud, así que CICLO y KILÓMETRO cuelgan de las bases ya presentes (UNIDAD, METRO) y HORA es la base de TIEMPO. **Bloque 79** (T-2030): pantallas `Medidores` colgando del nodo Activos, permisos `VER MEDIDORES` / `CREAR EDITAR MEDIDORES`, `Menu_Funcion` y `Perfil_Permiso`. **Web** (T-2028, T-2029, T-2031): `ActivoMedidores.aspx` (grilla + `wucFiltro` + baja) y `ActivoMedidor.aspx` (ficha `sigma-modal-*` seccionada: Identificación y Medición, con combos de Activo y Unidad por `SEL_`, y `wuc:Auditoria`); `ActivoMedidor.cs` + `ActivoMedidorController.cs`. Seguridad en el servidor: filtro por `Session.ClienteId()` y `Token.Puede`/`PuedeFuncion`. **Compila en `exitcode=0`; bloques 77–79 ejecutados y SPs probados en transacciones revertidas.** Falta prueba en navegador |
| 31-08-2026 | **El año de fabricación del activo pasa a desplegable.** En `Activo.aspx` se escribía a mano en un `TextBox2` con parseo y guarda de rango (`LeerAnio`). Se reemplaza por un `RadComboBox2` poblado del año actual hacia 1950, con opción "Sin dato". Elegir de una lista evita el tipeo de un "20226" o un año futuro y quita la validación a mano. Mismo criterio que la puesta en marcha, que ya es calendario |

| 31-08-2026 | **Sprint 2 · HU-030 — Administrar tipos de activo (Emilio, todas las tareas).** Tercera entidad del Sprint 2. `Activo_Tipo` es un **árbol** (`ati_activo_tipo_padre`) cuyas filas pueden ser **globales de SIGMA** (`ati_cliente` NULL) o **del cliente** — se construyó sobre la plantilla de `Centro_Costo`. **T-2221**: modelo revisado; el código es único **por cliente** (`UX_ATI_CLIENTE_CODIGO`), y como NULL e id de cliente son claves distintas, el cliente puede tener su propio "MOTOR" aunque exista el global. **Bloque 87** (T-2222–T-2225): se **amplió** `SEL_ACTIVO_TIPO` —el del bloque 74 solo servía al combo de la ficha de activo— a árbol con ruta/nivel, `@FILTRO` escapado, auditoría con nombre de usuario y una columna `ES_GLOBAL`, conservando los parámetros previos para no romper el combo; `INS_` valida código único por cliente y padre del mismo cliente o global; `UPD_` con `ISNULL`, validación de ciclo por CTE y **rechazo de editar un tipo global**; `DEL_` baja lógica que **rechaza si hay subtipos, activos o modelos** que usan el tipo. **Bloque 88** (T-2226): tipos del cliente Hamburgo en dos niveles (ROTATIVO → motor/bomba/ventilador; ESTATICO → intercambiador/estanque). **Bloque 89** (T-2233): pantallas `Tipos de activo` bajo el nodo Activos, permisos `VER TIPOS ACTIVO` / `CREAR EDITAR TIPOS ACTIVO`, `Menu_Funcion` y perfiles (el planificador es el dueño de HU-030). **Web** (T-2231, T-2232, T-2234): `ActivoTipos.aspx` (árbol con indentación por nivel y columna de ámbito SIGMA/Cliente) y `ActivoTipo.aspx` (ficha `sigma-modal-*`; un tipo global se abre en **solo lectura con aviso**, porque el SP lo rechaza igual); se ampliaron el modelo `ActivoTipo` y el `ActivoTipoController` (que ya existían para el combo) con la jerarquía, la auditoría y el CRUD. **Compila en `exitcode=0`; bloques 87–89 ejecutados y SPs probados en transacciones revertidas** (árbol correcto, duplicado por cliente rechazado, global no editable, DEL con subtipos rechazado, baja lógica). Queda pendiente la prueba en navegador (T-2235) |

| 01-09-2026 | **Sprint 2 · HU-037 — Consultar la ficha y el historial de un activo (Emilio).** Pantalla de **solo lectura** con las dos partes de la HU: la **ficha** (identificación, ubicación, tipo, estado, criticidad — la resuelve `SEL_ACTIVO`) y el **historial**, una línea de tiempo. **Bloque 90** (T-2050/T-2051): `SEL_ACTIVO_FICHA` une en un solo listado los **cambios de estado, cambios de posición y mediciones** (`Activo_Estado_Historial`, `Activo_Posicion_Historial`, `Activo_Medidor_Lectura`), con filtros por tipo de evento y rango de fechas, ordenamiento asc/desc y **paginación real** (`OFFSET/FETCH` + `@TOTAL` de salida) — **todo por parámetros, sin SQL concatenado**, materializando el UNION en `#temp` para contar el total y devolver la página sin recorrerlo dos veces; barrera multicliente en el propio SP. Índices de apoyo `IX_AEH_ACTIVO_FECHA` e `IX_APH_ACTIVO_FECHA`. Órdenes y fallas quedan preparadas como otro `UNION ALL` para cuando existan (Sprint 3+). **Bloque 91** (T-2052): historial demo de MOT-001 —3 cambios de estado y 3 mediciones—; devuelve los 6 eventos ordenados. **Bloque 92** (T-2057): pantalla registrada en `Menus` bajo el nodo Activos, reutilizando el permiso `VER ACTIVOS` (no lleva `Menu_Funcion` porque no hay escritura). **Web** (T-2055): `ActivoFicha.aspx` de solo lectura con filtros arriba (activo, tipo de evento, desde/hasta con `Calendar`), panel de ficha, grilla de historial y **exportación a Excel**; `ActivoFichaEvento.cs` + `ActivoFichaController.cs`. **API** (T-2053/T-2054): `GET /activos/{id}/ficha` en `ActivosController` (nuevo, con su `ActivoFichaEventoDto` y su include en `API.csproj`), con filtros, paginación y **caché corta** (`CacheCorta`); el cliente sale del **token**, no de la URL. **Compila `exitcode=0` (web y API); bloques 90–92 ejecutados y `SEL_ACTIVO_FICHA` probado contra la base** (filtro por tipo, por fecha, paginación y barrera multicliente). Falta la prueba en navegador; la consulta sin conexión (CA3) es de la app móvil |

| 31-08-2026 | **Sprint 2 · HU-042 — Configurar el medidor de un activo (Emilio).** Segunda entidad del Sprint 2, sobre la misma plantilla. **T-2018**: el modelo `Activo_Medidor` ya existía (bloque 11); se revisó y se confirmó su índice único. **Hallazgo y decisión**: el código del medidor es único **por activo** (`UX_AME_ACTIVO_CODIGO (ame_activo, ame_codigo)`), no por cliente como decía la plantilla de la tarea. Es lo correcto: un activo no puede tener dos "HOROMETRO", pero dos activos distintos sí; `INS_`/`UPD_` validan por activo. **Probado contra la base**: mismo código rechazado en el mismo activo, permitido en otro. **Bloque 77** (T-2019 a T-2022): `SEL_ACTIVO_MEDIDOR` (dinámico, `@FILTRO` escapado, auditoría con nombre de usuario), `INS_` en transacción con código único por activo, `UPD_` con `ISNULL` y el activo inmutable, `DEL_` baja lógica que **rechaza si el medidor tiene lecturas** (`Activo_Medidor_Lectura`). Otra decisión: `ame_fecha_valor_actual_utc` se sella con `GETUTCDATE()` —su sufijo `_utc` lo pide; la app compara lecturas de husos distintos—, mientras la auditoría va con `FNC_PAIS_HORA`. **Bloque 78** (T-2023): sembró las unidades que un medidor necesita —**horas, ciclos, kilómetros**, que no existían (solo había unidades de inventario)— y 4 medidores demo en Hamburgo. Un índice filtrado permite una sola unidad base por magnitud, así que CICLO y KILÓMETRO cuelgan de las bases ya presentes (UNIDAD, METRO) y HORA es la base de TIEMPO. **Bloque 79** (T-2030): pantallas `Medidores` colgando del nodo Activos, permisos `VER MEDIDORES` / `CREAR EDITAR MEDIDORES`, `Menu_Funcion` y `Perfil_Permiso`. **Web** (T-2028, T-2029, T-2031): `ActivoMedidores.aspx` (grilla + `wucFiltro` + baja) y `ActivoMedidor.aspx` (ficha `sigma-modal-*` seccionada: Identificación y Medición, con combos de Activo y Unidad por `SEL_`, y `wuc:Auditoria`); `ActivoMedidor.cs` + `ActivoMedidorController.cs`. Seguridad en el servidor: filtro por `Session.ClienteId()` y `Token.Puede`/`PuedeFuncion`. **Compila en `exitcode=0`; bloques 77–79 ejecutados y SPs probados en transacciones revertidas.** Falta prueba en navegador |
| 31-08-2026 | **El año de fabricación del activo pasa a desplegable.** En `Activo.aspx` se escribía a mano en un `TextBox2` con parseo y guarda de rango (`LeerAnio`). Se reemplaza por un `RadComboBox2` poblado del año actual hacia 1950, con opción "Sin dato". Elegir de una lista evita el tipeo de un "20226" o un año futuro y quita la validación a mano. Mismo criterio que la puesta en marcha, que ya es calendario |

| 31-08-2026 | **Sprint 2 · HU-030 — Administrar tipos de activo (Emilio, todas las tareas).** Tercera entidad del Sprint 2. `Activo_Tipo` es un **árbol** (`ati_activo_tipo_padre`) cuyas filas pueden ser **globales de SIGMA** (`ati_cliente` NULL) o **del cliente** — se construyó sobre la plantilla de `Centro_Costo`. **T-2221**: modelo revisado; el código es único **por cliente** (`UX_ATI_CLIENTE_CODIGO`), y como NULL e id de cliente son claves distintas, el cliente puede tener su propio "MOTOR" aunque exista el global. **Bloque 80** (T-2222–T-2225): se **amplió** `SEL_ACTIVO_TIPO` —el del bloque 74 solo servía al combo de la ficha de activo— a árbol con ruta/nivel, `@FILTRO` escapado, auditoría con nombre de usuario y una columna `ES_GLOBAL`, conservando los parámetros previos para no romper el combo; `INS_` valida código único por cliente y padre del mismo cliente o global; `UPD_` con `ISNULL`, validación de ciclo por CTE y **rechazo de editar un tipo global**; `DEL_` baja lógica que **rechaza si hay subtipos, activos o modelos** que usan el tipo. **Bloque 81** (T-2226): tipos del cliente Hamburgo en dos niveles (ROTATIVO → motor/bomba/ventilador; ESTATICO → intercambiador/estanque). **Bloque 82** (T-2233): pantallas `Tipos de activo` bajo el nodo Activos, permisos `VER TIPOS ACTIVO` / `CREAR EDITAR TIPOS ACTIVO`, `Menu_Funcion` y perfiles (el planificador es el dueño de HU-030). **Web** (T-2231, T-2232, T-2234): `ActivoTipos.aspx` (árbol con indentación por nivel y columna de ámbito SIGMA/Cliente) y `ActivoTipo.aspx` (ficha `sigma-modal-*`; un tipo global se abre en **solo lectura con aviso**, porque el SP lo rechaza igual); se ampliaron el modelo `ActivoTipo` y el `ActivoTipoController` (que ya existían para el combo) con la jerarquía, la auditoría y el CRUD. **Compila en `exitcode=0`; bloques 80–82 ejecutados y SPs probados en transacciones revertidas** (árbol correcto, duplicado por cliente rechazado, global no editable, DEL con subtipos rechazado, baja lógica). Queda pendiente la prueba en navegador (T-2235) |

| 01-09-2026 | **Sprint 2 · HU-040 — Administrar unidades de medida (Emilio).** Primer mantenedor **de plataforma** del Sprint 2: `Unidad_Medida` es un **catálogo global** (no tiene cliente), así que va bajo **Sistema → Mantenedores** —junto a Catálogos— y su administración es de **Root**, no del cliente: editar una unidad la cambia para todas las empresas. Los combos de medidores/repuestos/variables la leen del `SEL_` directo, así que no dependen de ese permiso. **Bloque 93** (T-2279–T-2283): se **reescribió** `SEL_UNIDAD_MEDIDA` (antes solo `@ID/@HABILITADO` para el combo) con filtros por magnitud, texto y habilitado, la magnitud y la unidad base resueltas por JOIN, y auditoría con nombre de usuario; nace `SEL_MAGNITUD` para el combo; `INS_`/`UPD_`/`DEL_`. Decisiones: el código es único **global** (`UX_UME_CODIGO`), no por cliente; las fechas se sellan con `GETDATE()` —no `FNC_PAIS_HORA`: sin cliente no hay país—; el `INS_` **respeta el índice de una sola base por magnitud** (`UX_UME_MAGNITUD_BASE`) y avisa "elija una unidad base" en vez del error crudo; y valida que la base sea de la misma magnitud. `DEL_` es baja lógica que **rechaza si la unidad está en uso** (medidores, repuestos, variables, atributos) o si otra la usa como base. **Bloque 94** (T-2284): se sembró **temperatura** (Kelvin base + Celsius con `offset` 273,15), el primer caso que ejercita el offset. **Bloque 95** (T-2291/T-2292): pantallas bajo Sistema, permisos `VER`/`CREAR EDITAR UNIDADES MEDIDA` y `Menu_Funcion`; solo a Root. **Web** (T-2289/T-2290): `UnidadMedidas.aspx` (listado con búsqueda) y `UnidadMedida.aspx` (ficha `sigma-modal-*` con secciones Identificación y Conversión, combos de Magnitud y Unidad base, y nota que explica factor/offset); se ampliaron el modelo `UnidadMedida` y el `UnidadMedidaController` —conservando `GetUnidades()` que usan los combos de medidor y repuesto— y nace `MagnitudController`. **Compila `exitcode=0`; bloques 93–95 ejecutados y SPs probados en transacciones revertidas** (código duplicado rechazado, segunda base por magnitud rechazada, edición, y baja rechazada cuando la unidad está en uso). Falta prueba en navegador |

| 01-09-2026 | **Sprint 2 · HU-036 — Registrar los componentes de un activo (Emilio).** Mantenedor de `Activo_Componente` (rodamiento, sello, eje…), sobre la plantilla del módulo Activos. **T-2104**: el código es único **por activo** (`UX_ACO_ACTIVO_CODIGO`), no por cliente; además hay un índice `(activo, tipo, posición)` que impide dos componentes del mismo tipo en la misma posición de un activo. **Bloque 96** (T-2105–T-2108): `SEL/INS/UPD/DEL_ACTIVO_COMPONENTE` (patrón dinámico, `@FILTRO` escapado, auditoría con nombre de usuario) más los `SEL_` de los tres catálogos que pueblan los combos y no existían —`SEL_COMPONENTE_TIPO`, `SEL_ACTIVO_COMPONENTE_ESTADO`, `SEL_COMPONENTE_POSICION`—. El `INS_` valida código único por activo, **traduce el índice tipo+posición a un mensaje claro** ("ya hay un componente de ese tipo en esa posición") en vez del error crudo, y sella con `FNC_PAIS_HORA`; `UPD_` con `ISNULL` y el activo inmutable; `DEL_` baja lógica que rechaza si hay subcomponentes habilitados. **Bloque 97** (T-2109): 3 componentes demo en MOT-001, cada uno de un tipo distinto (por el índice tipo+posición), con los ids resueltos en runtime. **Bloque 98** (T-2116/T-2117): pantallas `Componentes` bajo el nodo Activos, permisos `VER`/`CREAR EDITAR COMPONENTES`, `Menu_Funcion` y perfiles. **Web** (T-2114/T-2115): `ActivoComponentes.aspx` (grilla + búsqueda + baja) y `ActivoComponente.aspx` (ficha `sigma-modal-*` seccionada: Identificación y Detalle, combos de Activo/Tipo/Estado/Criticidad/Posición/Superior por `SEL_`, fecha de instalación con `Calendar`, `wuc:Auditoria`); `ActivoComponente.cs` + `ActivoComponenteController.cs` con los tres controllers de lookup. Seguridad: filtro por `Session.ClienteId()` y `Token.Puede`. **Compila `exitcode=0`; bloques 96–98 ejecutados y SPs probados en transacciones revertidas** (código duplicado, restricción tipo+posición, edición y baja lógica). Falta prueba en navegador |

| 01-09-2026 | **Código automático para las entidades del Sprint 2 (Emilio).** Se sumaron **Activo_Medidor (MED-), Activo_Componente (COM-), Activo_Tipo (TIP-) y Unidad_Medida (UNI-)** al sistema de código automático que ya había armado Bryan (`Modulo_Codigo` + `FNC_CODIGO_AUTOMATICO` + el parche que inyecta la generación tras `SET @ID`). No se reimplementó nada: el **bloque 100** registra las 4 entidades en `Modulo_Codigo` y reejecuta el mismo parche, que dejó los cuatro `INS_` generando `PREFIJO-<id>` (probado: `MED-7`, `UNI-19`, `TIP-14`). En las 4 fichas el campo Código pasó a **solo lectura** (sin validador, ayuda "se genera al guardar"); al crear envían `AUTO` y el SP lo reemplaza. **Decisión de Emilio, con una salvedad anotada:** Bryan había dejado **fuera** a propósito los catálogos de código semántico —su comentario cita `Unidad_Medida.KG`—, porque `UNI-8` deja de ser legible y va contra las búsquedas por código; se automatizaron igual por pedido explícito, y los registros que ya existían conservan su código (solo los nuevos se generan). De paso apareció otra colisión de numeración con un compañero: **dos bloques `77`** (mi `77_SPRINT2_ACTIVO_MEDIDOR` y su `77_CODIGO_AUTOMATICO`); conviven con nombres distintos, como las otras. Compila `exitcode=0` |

| 01-09-2026 | **Sprint 2 · HU-038 — Cambiar el estado de un activo indicando el motivo (Emilio).** No es un mantenedor, es una **acción** que escribe en `Activo_Estado_Historial` — y **empieza a poblar de verdad el historial de la ficha (HU-037)**. **Bloque 101** (T-2147/T-2148/T-2149): el proceso `ACTIVO_CAMBIAR_ESTADO` (renombrado —`ACTIVO_ESTADO` chocaba con la tabla `Activo_Estado`, insensible a mayúsculas) hace todo en **una transacción con `SET XACT_ABORT ON`**: cierra el tramo de estado vigente, abre uno nuevo con el motivo y deja el activo con su estado actual (denormalización controlada). **Las reglas viven en el SP, no en la pantalla** (T-2148), para que web y API den lo mismo: activo del cliente, estado válido, no repetir estado, y **motivo obligatorio cuando el activo sale de operación** (detenido, fuera de servicio, dado de baja). `SEL_ACTIVO_ESTADO_HISTORIAL` devuelve la línea de tiempo con el nombre del estado, el usuario y si el tramo está vigente. **Probado**: cambio aplicado, motivo obligatorio, mismo estado y otro cliente rechazados, y **un solo tramo vigente** a la vez. **Bloque 102** (T-2150): ejercita el propio proceso sobre BMB-001. **Bloque 103** (T-2155): pantalla `Cambiar estado` bajo Activos con el permiso `CAMBIAR ESTADO ACTIVO`. **Web** (T-2153): `ActivoEstado.aspx` —elige activo, muestra su estado, pide nuevo estado y motivo, y lista el historial— con `ActivoEstadoHistorial.cs` + su controller. **API** (T-2151/T-2152): `POST /activo-estados` en `ActivoEstadosController` (nuevo); el manejo de errores no se reescribió —`ErrorSql` ya traduce cada `RAISERROR` a su HTTP, no a un 500—. **Compila `exitcode=0` (web y API); bloques 101–103 ejecutados y el proceso probado en transacciones revertidas.** Falta prueba en navegador |

| 01-09-2026 | **Sprint 2 · HU-031 — Administrar modelos de activo (Emilio).** Un mantenedor del catálogo de modelos (fabricante + modelo, p. ej. "WEG W22 132S") que puede tener cada **tipo de activo**. **Revisión del modelo** (T-2263): `Activo_Modelo` **no tiene código** —un modelo se identifica por fabricante + nombre dentro de su tipo; el "código único" de la plantilla es herencia y no aplica—; y `amo_cliente` es **anulable**: hay modelos **globales de la plataforma** (que todos ven pero nadie edita desde el cliente) y modelos **propios del cliente**. **Bloque 104**: `INS_ACTIVO_MODELO` (crea uno propio, sin duplicar tipo+fabricante+modelo), `UPD_ACTIVO_MODELO` (edición con `ISNULL`; **rechaza editar un modelo global**), `DEL_ACTIVO_MODELO` (baja lógica que **rechaza si algún activo, plan o repuesto lo usa** —no deja dependientes huérfanos—). El `SEL_ACTIVO_MODELO` ya existía (de Catalina); se **amplió de forma aditiva** para exponer la auditoría que necesita la ficha, sin tocar sus parámetros ni columnas previas. **Probado** en transacción revertida: duplicado rechazado, edición y baja OK. **Bloque 105** (T-2268): siembra modelos ejercitando el propio INS. **Bloque 106** (T-2275/T-2276): pantallas bajo Activos con permisos `VER MODELOS ACTIVO` / `CREAR EDITAR MODELOS ACTIVO`; la seguridad de datos la hace el filtro por cliente + el SP, no esconder el botón. **Web**: `ActivoModelos.aspx` (listado que marca "Global"/"Del cliente" y no ofrece lápiz en los globales) + `ActivoModelo.aspx` (ficha; los globales salen en solo lectura) con su `ActivoModelo.cs` y controller. **Compila `exitcode=0`; bloques 104–106 ejecutados y los SP probados.** Falta prueba en navegador |
| 02-09-2026 | **Centro de Acción Operacional — bloques 111–117.** `111_ALERTA_BANDEJA_SP` (los procedimientos de la bandeja: `SEL_ALERTA`, `SEL_ALERTA_RESUMEN`, `SEL_ALERTA_HISTORIAL`, `SEL_ALERTA_PREDICCION`, `UPD_ALERTA_ESTADO`, `UPD_ALERTA_RESPONSABLE`). `112` la condición que vuelve a darse (`UPD_ALERTA_REPETICION`, el contador ×N de la cola). `113` y `115` tendencia y serie diaria de los cinco indicadores (`SEL_ALERTA_TENDENCIA`). `114` predicción de demo para el panel de SIGMA AI. `116` la curva de riesgo (tercer resultado de `SEL_ALERTA_PREDICCION`). `117` `INS_ORDEN_TRABAJO_DESDE_PREDICCION`: **desde un análisis predictivo se abre la OT**. |
| 02-09-2026 | **Programación — bloques 118–121 y 123.** `118` alcance y asignación (`pro_cliente_instalacion`, `pro_instalacion_area`, `pro_activo`, responsable) con `CK_PRO_ALCANCE_JERARQUIA` y `CK_PRO_RESPONSABLE_UNICO`. `119` `SEL_PROGRAMACION_CATALOGO_ALCANCE` con lista blanca de catálogos. **`120` corrige un error propio**: el grupo responsable es un `Grupo_Trabajo`, no un `Perfil` — se renombró `pro_perfil_responsable` a `pro_grupo_trabajo`. `121` `UPD_PROGRAMACION_FECHA`. `123` `Programacion_Responsable`: **varios responsables sin tener que crear una cuadrilla** (`UPS_PROGRAMACION_RESPONSABLE` reemplaza la lista completa y rechaza mezclar personas con grupo). |
| 02-09-2026 | **Cliente y proveedor — bloques 122, 124, 126.** `122` `SEL_CLIENTE_FICHA` (ficha corporativa con catálogos resueltos, rótulo del identificador según país y `CONFIGURACION_COMPLETA`). `124` `Cliente_Contacto` con SEL/INS/UPD/DEL, índice único filtrado de principal y `CK_CCN_CONTACTABLE`; **probado**: el primero queda principal solo, sin correo ni teléfono se rechaza, un principal nuevo degrada al anterior, y al borrar el principal asciende el siguiente. `126` `SEL_PROVEEDOR_SERVICIO` con sus adjuntos. **Se descartó el bloque 125**: `SEL_PROVEEDOR` ya devolvía todo — el SP se eliminó de la base y el archivo del repositorio. |
| 03-09-2026 | **El panel lateral — bloques 127 y 129.** `127` `SEL_DETALLE_FICHA`: pares SECCIÓN/ETIQUETA/VALOR contra lista blanca de entidades, para que el panel muestre lo que **no** cabe en la grilla. `129` `SEL_DETALLE_INVENTARIO` suma EXISTENCIA y MOVIMIENTO y, sobre todo, un **segundo resultado** con los ocho movimientos recientes (fecha, tipo, sentido, cantidad, responsable con avatar, motivo, OT y ubicación). El SENTIDO se resuelve en el SP desde el tipo, porque `imo_cantidad` siempre es positiva; REUBICACION queda NEUTRO para que los números cuadren con el saldo. `128_ALERTA_DESTINO_ACTIVO` da destino de ficha a las alertas de activos. |
| 03-09-2026 | **Bloque 130 — la hora del país deja de depender de dónde esté el servidor.** Síntoma: en la ficha de un grupo se agregaba a alguien como líder *desde hoy* y el resumen seguía diciendo «Sin líder vigente» mientras la fila mostraba el chip LÍDER. **Causa**: el servidor de base de datos corre en **UTC−07:00** y el cliente trabaja en Chile; pasadas las 21:00 locales, para el servidor todavía es el día anterior, así que la fecha elegida queda en el futuro y el tramo se marca PENDIENTE. `FNC_PAIS_HORA` no ayudaba: sumaba un desfase **entero** guardado en `PAISES`, configurado para cuando el servidor vivía en Chile (por eso Chile estaba en 0), y un entero fijo tampoco sabe de horario de verano. **Corrección aditiva**: `PAISES.pai_zona_horaria` + `AT TIME ZONE`, que resuelve contra UTC y aplica el horario de verano solo; un país sin zona configurada se comporta exactamente como antes. Alcance real del arreglo: **todo lo que compara fechas** — permisos vencidos, proyecciones de programación, estados de activo. **Verificado** contra la base: el integrante pasa a VIGENTE. |
| 03-09-2026 | **Barrido de diseño y cuatro bugs de raíz.** (1) *El panel lateral no abría en las dos pantallas de permisos*: `sigma-listas.js` buscaba las filas por `tr.rgRow`, clase de Telerik, y esas dos son las únicas que escriben `item.CssClass` para teñir la fila — eso reemplaza el atributo `class` y se lleva el `rgRow`. Ahora se buscan por **estructura**, así que ninguna pantalla futura vuelve a romperlo. (2) *Las tarjetas de resumen salían como enlaces azules*: su CSS base vivía en `sigma-modal.css`, que **solo carga `Simple.master`**, y la pantalla corre sobre `Default.master`. (3) *El modal crecía lento «de la nada»*: un `MutationObserver` con `attributes: true` remedía el alto en cada `style` que escribe GSAP, ~60 veces por segundo durante la animación de entrada. (4) *La cabecera del panel se perdía*: sí era `sticky`, lo que se veía pasar era el `padding-top` del contenedor, una franja transparente por encima. |
| 03-09-2026 | **`SitioBase.Avatar` — las personas se dibujan igual en todo el producto.** Los avatares nacieron como métodos privados dentro de `Programaciones.aspx.cs`: cada pantalla nueva que mostrara usuarios tenía que copiarlos, y una copia se desincroniza — el mismo usuario terminaba azul en una pantalla y verde en otra, con lo que el color dejaba de servir para reconocerlo. Ahora es una clase compartida (foto si la subió, iniciales sobre el color que le toca **por id**, nunca por un hash del nombre: con los siete usuarios reales daba solo cuatro colores) más `sigma-avatares.css` en los dos masters. Aplicado en Programaciones, los dos listados de permisos, los integrantes de grupo y la línea de tiempo de movimientos. |
| 03-09-2026 | **Integrantes de grupo: repeater en vez de RadGrid.** Una grilla resuelve tablas de muchas filas y muchas columnas; un grupo tiene entre tres y quince personas y de cada una interesan cuatro cosas. La grilla traía su paginador («Registros por página: 25», debajo de una sola fila), su cabecera en mayúsculas y su ancho fijo por columna, que dejaba las especialidades cortadas mientras la columna LÍDER sobraba vacía en todas las filas menos una. Ahora cada persona es una tarjeta. El borrado sigue siendo un comando de servidor con su confirmación y su chequeo de permiso. Las fechas del alta pasan a decir **opcional** en el rótulo: se llenaban por las dudas, y llenarlas era justo lo que dejaba al integrante sin vigencia. |
| 03-09-2026 | **Centro de alertas y campana, full AJAX — y su regresión visual.** La página se repinta pidiéndose a sí misma con `sgAjax=1` y cambiando cuatro fragmentos; los `LinkButton` pasaron a `<button>` nativos (correcto: no navegan a ninguna parte, y un botón se activa con Espacio y un enlace no). Pero la hoja estaba escrita para `<a>`, que no trae estilo propio: un `<button>` sí — borde, fondo gris, tipografía del sistema, **texto centrado** y ancho ajustado al contenido. Cada alerta apareció como una cajita gris. Se agregó un reset **con la clase sola, sin `button` delante**: con `button.sg-alerta` la especificidad sería mayor y el `border: 0` mataría el `border-bottom` que cada pieza declara más abajo. Ver §6. |

| 01-09-2026 | **Sprint 2 · HU-032 — Definir los atributos técnicos de un tipo de activo (Emilio).** El mantenedor que dice **qué datos técnicos** describe cada tipo de activo ("Potencia" decimal en kW, "Voltaje" entero en V, "Requiere certificación" booleano). **Revisión del modelo** (T-2295): `Atributo_Tecnico` **sí tiene código** con índice único por cliente (`UX_ATE_CLIENTE_CODIGO`) → se **automatiza** (`ATR-<id>`, decisión de Emilio) para que la unicidad la garantice el id y nadie teclee códigos; `ate_cliente` y `ate_activo_tipo` son **anulables** (atributos **globales** de la plataforma, y atributos que aplican a **todos los tipos** o a uno concreto). **Bloque 107**: `INS/UPD/DEL_ATRIBUTO_TECNICO` (con reglas: tipo de dato válido, tipo de activo del cliente o global, unidad válida; **no editar/dar de baja globales**; **no dar de baja un atributo con valores ya capturados** en `Activo_Atributo`) + `SEL_ATRIBUTO_TECNICO` (grilla y ficha, con marca de global y auditoría) + `SEL_TIPO_DATO` (combo). **Bloque 108**: integra `Atributo_Tecnico` al **código automático** de Bryan (prefijo ATR, parcheando `INS_ATRIBUTO_TECNICO` tras el `SCOPE_IDENTITY`) — mismo mecanismo del bloque 100. **Probado**: alta genera **ATR-1/2/3** (no 'AUTO'), edición y baja OK, tipo de dato inexistente rechazado. **Bloque 109** (T-2300): siembra ejercitando el INS. **Bloque 110** (T-2307/T-2308): pantallas bajo Activos con permisos `VER ATRIBUTOS TECNICOS` / `CREAR EDITAR ATRIBUTOS TECNICOS`; seguridad por filtro de cliente + SP. **Web**: `AtributoTecnicos.aspx` (listado que marca "Global"/"Del cliente" y no ofrece lápiz en los globales) + `AtributoTecnico.aspx` (ficha con código readonly, combos de tipo de dato/tipo de activo/unidad; los globales en solo lectura) con su `AtributoTecnico.cs` (+ `TipoDato`) y controller. **Compila `exitcode=0`; bloques 107–110 ejecutados y los SP probados.** Falta prueba en navegador |

| 01-09-2026 | **Sprint 3 · HU-061 — Administrar procedimientos reutilizables (Emilio).** Un procedimiento es la "receta" de un trabajo (pasos en orden), que se escribe una vez y se reutiliza en planes y órdenes. **La BD ya estaba hecha** (bloque 101 del track paralelo): revisé y confirmé los 5 SPs (`SEL/INS/UPD/DEL_PROCEDIMIENTO` + `SEL_VARIABLE_MEDICION`) — siguen el estándar (transacciones, `FNC_PAIS_HORA`, `ISNULL` parcial, rechazo de dependientes en `Plan_Mantenimiento_Actividad` y `Orden_Trabajo_Paso`, protección de globales). **Hallazgo clave**: aquí el código **NO es automático** y está bien así — la llave es (cliente, código, **versión**), o sea el mismo código se repite una fila por versión para no falsear lo ya ejecutado; un código auto por-id rompería el versionado (por eso `Procedimiento` no está en `Modulo_Codigo`). **Lo que faltaba y construí**: **bloque 130** (T-3206) datos de prueba ejercitando el propio INS (3 procedimientos); **bloque 131** (T-3213/T-3214) pantallas bajo **Mantenimiento → Procedimientos** con permisos `VER PROCEDIMIENTOS` / `CREAR EDITAR PROCEDIMIENTOS`; **web** (T-3211/T-3212) `Procedimientos.aspx` (listado que marca "Global"/"Del cliente", sin lápiz en globales) + `Procedimiento.aspx` (ficha con código/versión readonly al editar, tipo de activo opcional, y sección de permiso de trabajo con combo condicional) con su `Procedimiento.cs` y controller. **Primera vista con el patrón de diseño nuevo**: el listado abre la ficha con `SigmaModal.open({url,title,width,initialHeight})` (ya no `RadWindow2` en el body); la ficha sigue con `Simple.master` + clases `sigma-modal-*` porque el diálogo le inyecta el adaptador `radWindow`. **Compila `exitcode=0`; bloques 130–131 ejecutados y la demo verificada.** Falta prueba en navegador |

| 04-09-2026 | **Documentación de arranque de la app móvil.** Siete documentos nuevos en `MD/` — [`SIGMA_APP_ESTADO.md`](SIGMA_APP_ESTADO.md), [`SIGMA_APP_ARQUITECTURA.md`](SIGMA_APP_ARQUITECTURA.md), [`SIGMA_APP_DISENO.md`](SIGMA_APP_DISENO.md), [`SIGMA_APP_DATOS_SINCRONIZACION.md`](SIGMA_APP_DATOS_SINCRONIZACION.md), [`SIGMA_APP_NOTIFICACIONES.md`](SIGMA_APP_NOTIFICACIONES.md) [`SIGMA_APP_README.md`](SIGMA_APP_README.md) y el brief de mockups [`SIGMA_APP_MOCKUP_BRIEF.md`](SIGMA_APP_MOCKUP_BRIEF.md) —. La arquitectura se toma de **FacilityGes** y **AgendamientosControlGate** (Riverpod + Repository, offline-first), leyendo su código fuente completo y el de `FacilityGesApi2.0`; el patrón de carga inicial sale de `API_2_SEL_USUARIO_SABANA_DATOS`. Tres divergencias deliberadas y documentadas: **códigos HTTP reales** en vez de `Status` dentro del cuerpo, **una cola de salida única** en vez de una marca `enviado` por tabla, y la bandeja de avisos servida por `GET /alertas` en vez de vivir solo en el teléfono. **Cuatro hallazgos del cruce con los Sprint Backlogs S1–S3**: las tres promociones a App (HU-004, HU-057, HU-064) **ya están corregidas** en el xlsx —cerrar esa desalineación en `SIGMA_APP_FLUTTER.md` §10—; el conteo de **52 endpoints en 20 controllers** es correcto y el «de 64 a 21» de `SIGMA_ALCANCE_APP.md` §6 está vencido; **HU-059 y HU-077 están marcadas «Web y App» y no tienen ninguna tarea de Móvil**; y **las 17 h de Móvil de S1–S3 no cubren ni la base de la app** (~40 h solo el andamiaje: proyecto, tema, `ApiClient`, SQLite, cola, router por datos y Firebase). Falta además construir `API_SEL_APP_SABANA_DATOS` + `GET /sincronizacion` para HU-150 y la tabla `Usuario_App_Dispositivo` para el push de HU-077. **No se escribió código Dart a propósito**: el bloque 0 es arreglar los dos defectos de la API que rompen el login desde un cliente externo |
| 15-09-2026 | **Pruebas documentadas de los sprints 1–5, con evidencia (Selenium + Swagger) y un Word por sprint** en `Fase 2/Pruebas/`; Sí/No en los Sprint Backlogs. Salieron y se corrigieron seis defectos además de los tres del 14-09: `INS_REPUESTO` con parámetros duplicados, plan comercial sin precio invisible (`BD/228`), la compuerta de suscripción rebotando a Root (`SuscripcionAcceso`), «Declarar pago» muerto en `Renovar.aspx` (RadWindow → SigmaModal), la API tirando el veredicto de umbrales de la medición (`{id, mensaje}`), y `SEL_LOGIN` dejando fuera al Root que da de baja a un cliente que creó (`BD/229`). Detalle en `SIGMA_CHECKLIST_PENDIENTES.md` §10.12 |
| 15-09-2026 | **La hora de negocio es la de Santiago (`BD/230`).** El hosting va en UTC−7 y `GETDATE()` atrasaba cuatro horas: `FNC_AHORA()` y los 125 módulos + 155 DEFAULT regenerados sin `GETDATE()`; `SitioBase.Hora`/`API.Utils.Hora` reemplazan `DateTime.Now` en web y API. Checklist §10.13 |
| 15-09-2026 | **Sprint 2 · Posiciones funcionales (HU-033/034/154).** `BD/231`: SP del mantenedor, ocupar/liberar con historial de periodos e idempotencia por uuid, etiqueta `POS-` en el centro de etiquetas, permisos y menú. Web `View/Activos/Posiciones/*`, API `PosicionesController` + escaneo `POS-`, app: escanear una posición abre el equipo que la ocupa o permite ponerle uno. Etiquetas: códigos largos ya no se parten. Checklist §10.14 |
| 16-09-2026 | **Las posiciones bajan en la sábana (`BD/232`, bloque 11).** Sin señal, escanear `POS-`/`ACT-` se resuelve desde el teléfono con la fecha de la última sincronización (HU-154 #2). `BLOQUE_MAXIMO` = 11 |
| 16-09-2026 | **Sprint 2 · HU-045 serie histórica de una variable.** `BD/233` (serie en la unidad de la variable con el nivel del SP, resumen, origen ORDEN TRABAJO al medir con OT) y `ActivoVariableSerie.aspx` con Highcharts: banda normal, umbrales, puntos destacados y el origen de cada dato al tocarlo. Checklist §10.15 |
| 16-09-2026 | **Sprint 2 · HU-192 Mi suscripción.** «Qué incluye tu plan» (incluido / no incluido) y aviso «Cerca del límite» al 80 % del tope en `Renovar.aspx`. Checklist §10.16 |
| 16-09-2026 | **Sprint 2 · HU-150 sincronización descendente completa.** `BD/234`: bloques 12 (órdenes abiertas con pasos y asignados) y 13 (pautas pendientes con items y opciones) en la sábana; la bandeja, la ficha de la OT y la plantilla de checklist abren sin señal. Checklist §10.17 |
| 16-09-2026 | **Sprint 2 cerrado para Bryan: captura en terreno (HU-043/044/038).** `BD/235`: salto no razonable → pendiente de revisión + alerta, veredicto sobre el equivalente en la unidad de la variable, comentario obligatorio y alerta fuera de umbral; máximo diario en la ficha del medidor. App: el cuerpo de la captura usaba nombres que la API no conocía (rebotaba siempre) y la medición no llevaba variable — corregido, con elección de variable y lectura desde el medidor. Checklist §10.18 |
| 16-09-2026 | **Sprint 3 · HU-058, HU-065, HU-151 (servidor) y HU-077 detectores.** `BD/236`: vida útil real (esperada al lado, fechas Santiago, siembra sobre el catálogo real) e historial del proveedor (el rango ya filtra las órdenes) con sus dos pantallas de solo lectura + Excel; `BD/237` menú Terceros en carpetas; `SuscripcionHandler` → 402 en la API cuando la suscripción no permite operar; `BD/238` `GEN_ALERTA_OPERACION` (ocurrencias vencidas, permisos vencidos, variables sin medición, hallazgos sin OT, descubrimientos sin revisar, medidor próximo al plan). Lo móvil de HU-151 no se marca: es el MVP de la app. Checklist §10.19 |
| 16-09-2026 | **Cambio de alcance: app móvil al Sprint 6.** Pedido por Hamburgo en la Sprint Review 1 (15-09) y aceptado por la PO: Sprints 1–5 web, app completa en el Sprint 6. Actas en `Fase 2/Ceremonias/`; Product Backlog, Sprint Backlogs (304 tareas Móvil «Movida a Sprint 6») y Burndown actualizados. Checklist §10.20 |
| 17-09-2026 | **Pruebas del Sprint 2 completo** (todas las historias web del sprint, incluidas las de Emilio): 52 casos, 49 ✓. Correcciones: `BD/239` (SEL_ACTIVO tipo + subtipos), `BD/240` (UPD_ACTIVO rechaza ciclos), filtro por tipo en Activos, pestaña Componentes en la ficha, confirmación de posición ocupada. Checklist §10.21 |
| 17-09-2026 | **Pruebas del Sprint 3 completo**: 64 casos, 55 ✓. Programaciones probadas sobre `FNC_PROGRAMACION_FECHAS`; `BD/241` (la OT despliega los pasos del procedimiento), `BD/242` (permiso vencido al tomar la OT; repuesto no compatible exige motivo). Checklist §10.22 |
| 17-09-2026 | **Generación por medidor y por condición + paso con medición / punto de control.** `BD/243` (`FNC_PLAN_MEDIDOR_ESTADO`, `GEN_PLAN_OCURRENCIAS_MEDIDOR`, `GEN_PLAN_OCURRENCIAS_CONDICION`, hooks en los SP de captura), `BD/244` (`API_UPD_ORDEN_TRABAJO_PASO` exige la medición y respeta el punto de control; DTO con `valor_medicion`). HU-073/074 y HU-062 #2/#3 con evidencia; informe S3 62/64. Checklist §10.23 |

| 18-09-2026 | **Investigación Azure Machine Learning · SIGMA FAILURE 30D.** `BD/245` (modelo, 15 características, `FNC_ML_ACTIVO_HISTORICO_V1` sin fuga, SP de dataset/entrenamiento/versión/publicación/predicción, permiso y menú), API `/sigma-ai/*` con `PuntuadorFalla` (pesos de la versión publicada) y `AzureMl` (solo lectura, client credentials), web `SigmaAI/Experimentos.aspx`, `ML/entrenar_falla.py`. Cero costo: entrenamiento local, Azure ML solo como registro, puntuación en la API. Probado de punta a punta con demo sintético; el historial real (8 fallas) no alcanza para aprender. Guía en `SIGMA_INVESTIGACION_AZURE_ML.md`. Checklist §10.24 |

| 18-09-2026 | **Azure ML entrega el modelo sin entidad de servicio (`BD/246`).** La API baja el artefacto registrado por el almacenamiento del área (contenedor `azureml`, SAS existente), verifica el SHA-256 del `.onnx` y puede tomar los pesos desde Azure; `mpv_registro` y `mpv_fecha_verificacion_utc`. Corridas y modelo `SIGMA_FAILURE_30D` v1/v2 registrados en SIGMA_AI con la cuenta de Bryan (`az login` por código; `mlflow<3`). Sin cómputo, sin endpoints (el de Studio costaría ~216 USD/mes). Checklist §10.24 |

| 18-09-2026 | **SIGMA RUL y SIGMA VISION por el mismo camino (`BD/247`, `BD/248`).** RUL: dataset por instalación de repuesto con censura, AFT log-normal (scipy) en `entrenar_rul.py`, `PuntuadorRul` en la API (mediana + intervalo 80 %), `SIGMA_RUL:1` registrado en Azure ML, v1 publicada. VISION: dataset de imágenes confirmadas por persona, Azure Custom Vision F0 por claves (`CustomVision.cs`, `entrenar_vision.py`), revisión visual sin confirmar + confirmación humana. `/sigma-ai/*?modelo=`, selector en Experimentos, `sigma_ml.py` común. Checklist §10.25 |
| 22-09-2026 | **Sprints 1, 2 y 3 cerrados con evidencia; lo de la app al Sprint 6.** S1: `BD/249`–`BD/252` (hora por planta, grupo → líder, certificación vencida y alerta 15, contraseña vs. tres anteriores, candidatos), plantas/vigencia en el usuario del cliente, Catálogos «Nuevo valor» arreglado; 45/46 criterios ✓. S2: `BD/253` (historial de estado del componente con motivo), validador de combos ReadOnly que mataba el Guardar; 42 ✓ + 14 → S6. S3: 18 criterios escritos y probados para HU-059/066/067/068/069/077, `BD/254` (escaneo por código), `BD/255` (admin crea repuestos), `BD/256` (el detector de inventario cerraba con error 547), existencia por estante y lote, rollo térmico en A4; 73 ✓ + 3 → S6. Historias: 17 + 18 + 28 Terminada; solo quedan las validaciones con la PO. Informes S1–S3 regenerados. Checklist §10.26 |
| 22-09-2026 | **El Burndown/Burnup deja de estar en cero.** La columna diaria de los Sprints 1, 2 y 3 se reconstruyó desde la Bitácora de Daily Scrum (una historia quema sus puntos el último día en que el registro la nombra trabajada; el día de la Review no cuenta porque repasa todas). Cuadran con lo comprometido —81, 83 y 139— y cierran en cero: S1 con retraso hasta el día 6 y cierre el día 9, S2 siempre por sobre la ideal con cierre el último día, S3 con 25 puntos de retraso al día 4 y 50 puntos cerrados entre los días 8 y 9. S4–S6 siguen vacíos (sin dailies escritos y sin historias Terminada). Checklist §10.26 |
| 22-09-2026 | **La bitácora de dailies llega hasta el Sprint 5.** Las 57 participaciones que faltaban de los Sprints 4 y 5, escritas contra lo que existe en el repositorio (65 y 89 tareas Terminada, con su historia y su rango de tareas) y con lo no hecho registrado como tal: las 10 tareas bloqueadas por HU-082/091/097, lo que no avanzó de Emilio y lo que no entró de Catalina. Las historias construidas quedan En revisión —falta la validación de la PO—, así que el burndown de S4 y S5 sigue vacío. El Sprint 6 no se escribe. Queda dicho en el Resumen de la bitácora, en el traspaso §2 y en los acuerdos de cierre de S4 y S5 por qué el registro va por delante del calendario: el alcance del sistema obligó a adelantar construcción. Checklist §10.26 |

| 23-09-2026 | **Los centros 360 y el menú por módulos.** El **centro del activo** queda completo con sus trece vistas: `BD/267` suma cuatro procedimientos que preguntan al revés que el resto del sistema —dado UN equipo, qué se le revisó, qué se le cambió, cuánto costó y qué se anotó—, porque los que existían leen por plantilla, por tarea o por orden y armar la ficha con ellos costaba una llamada por orden. Inspecciones separa el **estado** (avance) del **resultado técnico** (evaluación): una inspección puede estar completada y con hallazgos. Repuestos muestra «Sin costo cargado» y no `$0` cuando hay líneas sin precio, para no inducir la conclusión de que mantener el equipo salió barato. Bitácora escribe por `API_INS_BITACORA`, el mismo camino que la app: dos caminos de escritura darían dos formatos y la auditoría dejaría de servir. El **plan de mantenimiento** pasa a centro con la misma cáscara y pestañas del navegador; la cabecera lee el año completo y el calendario su propio filtro, y los hitos y equipos son los de la versión que manda —la grilla vieja traía los de todas y el plan se leía con el doble de hitos de los que se ejecutan—. La grilla del calendario se queda: generar órdenes trabaja sobre lo seleccionado. **Menús por módulo**: `BD/268` unifica Activos en el Centro del activo (el listado suelto se esconde, no se borra, y el alta y los componentes se crean desde el centro con el equipo ya fijado); `BD/269` crea Planificación (Programaciones + Planes); `BD/270` crea Tareas y Órdenes de trabajo y fallas. **Fallas va con órdenes y no aparte** porque es la misma épica del backlog —EP-12 se llama «Órdenes de trabajo y fallas»— y el mismo recorrido: falla → diagnóstico → orden correctiva → cierre → indisponibilidad que alimenta los indicadores. La inspección la agrupa Emilio Fuentes. Lo pendiente de fallas no es de menú: **HU-123 y HU-124 solo deben su tarea de Móvil** (T-5175 y T-5190, movidas al Sprint 6) y **HU-182 —disponibilidad y confiabilidad, EP-18— está entera por hacer** y se calcula justamente con `Falla` + `Activo_Indisponibilidad`. Evidencia: `ui_a360_*`, `ui_plan_*`, `ui_menu_*` y `ui_componente_desde_centro` en `Fase 2/Pruebas/capturas/S3` |

| 24-09-2026 | **El centro del activo queda como los trece mockups (`BD/271`–`BD/285`).** Se audita pestaña por pestaña contra las imágenes y se ejecuta en siete pasos. **Un motor de filtros declarativo** (paso 1) reemplaza el filtro por pestaña: la zona declara `data-filtra`, los controles llevan `data-f` y las filas `data-fecha`/`data-txt`/`data-<campo>`; una fila **sin fecha nunca se esconde** por período y el período **no corta hacia adelante**, porque lo agendado es justamente lo que se quiere ver. **Condición y medidores** pasa a tarjetas (variable con valor, unidad, estado, umbrales y última lectura; contador con acumulado, próximo mantenimiento y cuánto falta) y la lectura se anota desde la web con `RegistrarLectura.aspx` (`BD/277`, `BD/278`). **Todo archivo se ve donde está**: `BD/272` y `BD/282` traen los adjuntos de inspecciones, tareas y órdenes —los de la inspección cuelgan de la **respuesta** y los de la tarea de la **ejecución**—, con miniatura, ampliar, video y audio, y un visor que se mueve entre evidencias con las flechas. **La foto de la pieza y del repuesto** (`BD/274`, `BD/280`) y, de paso, `VIN_ACTIVO_COMPONENTE_IMAGEN`, que **violaba `CK_AVI_UN_PADRE` desde que nació**: ninguna imagen de componente se había podido vincular nunca (`BD/281`). **Carga masiva de activos** desde planilla (`BD/283`), **repuestos con bodega, consumos, devoluciones y costos** (`BD/284`) y el **cierre de la falla** con su diagnóstico definitivo (`BD/285`). La búsqueda avanzada de la lista se saca —no filtraba nada— y con ella los combos de planta, área y línea: **dentro de un activo ya se sabe dónde está**. Los dos números de la lista abren su detalle en un popover, y el de la agenda es un calendario del mes de verdad (`BD/279`). Regla del paso 7: **lo que no tenemos cómo capturar no se hace**, así que de las columnas del mockup entran solo serie, fabricante y modelo del componente (`BD/288`), que tienen dónde escribirse; la etapa de la evidencia se elige al sacar la foto —o sea en la app— y nacería vacía para siempre |
| 24-09-2026 | **El módulo se llama «Control de activos» y el menú sigue el ciclo de vida (`BD/286`, `BD/287`).** «Activos > Centro del activo» repetía la palabra y escondía detrás de ella la pantalla de todos los días; y ofrecía el centro de un equipo antes de que existiera con qué clasificarlo. Queda **Configuración de activos** primero y **Activos** al final, que es el orden en que se usan. El nombre no cabe en una línea del sidebar: se arregla **dejando envolver en dos líneas** los nodos de primer nivel (`#sidebar-menu > ul > li > a > span` con `white-space: normal` y 42 px de `padding-right`, porque Adminto posiciona `.menu-arrow` en absoluto y no ocupa espacio en el flex), no recortando el nombre —recortarlo fue lo que produjo el problema original—. Dos trampas anotadas en §7: `Css/LookAndFeel/v2/02-Sidebar.css` **está muerto** (sus reglas viven en `sigma-layout.css`) y los `?vrs=N` escritos a mano nunca refrescan, así que el sitio usa `Asset()`, que cuelga el `LastWriteTimeUtc` del archivo |
| 24-09-2026 | **Sprint 4: las 31 tareas pendientes del plan de mantenimiento pasan a Bryan Chávez.** Reparto por historia completa, como desde el Sprint 4: dueño único por HU. Se desbloquean 3. Respaldo en `SIGMA_Sprint_Backlog_S4_BACKUP_PRE_REASIGNACION_PLAN.xlsx`. Quedan tres decisiones para el equipo: las 6 tareas de Swagger (el proyecto de API no existe), las 3 de validación con la PO, y las horas que quedaron parejas solo entre Bryan y Catalina |
| 25-09-2026 | **HU-082 · Actividades de un hito (`BD/289`, `BD/290`).** Lo que el hito no dice: el hito resuelve **cada cuánto**, la actividad resuelve **qué se hace**. Los cuatro SP siguen el molde del bloque 213: `SEL` con `@SELECT/@FROM/@WHERE` y `@FILTRO` escapado, `INS` que valida antes de abrir transacción, `UPD` con `ISNULL(@X, columna)` más banderas `@QUITA_` explícitas —incluida `@QUITA_DURACION`, porque sin ella vaciar la duración y guardar dejaba la vieja y el usuario veía que la pantalla ignoró lo que escribió—, y `DEL` lógico que **rechaza si la actividad ya fue copiada en una orden**. El código es único por hito, el procedimiento se valida contra el cliente —sus pasos se copian dentro de la orden generada—, «requiere permiso» sin tipo se rechaza en la pantalla y en el SP, y **nada se escribe sobre una versión publicada**: esa versión ya generó órdenes con estos pasos dentro, y cambiarla haría que la orden de ayer y el plan de hoy cuenten historias distintas. Dos pantallas: la lista de las actividades de un hito —se entra **desde el hito**, en el centro del plan; el enlace lleva el hito en el query cifrado— y su ficha en modal. Las dos van **invisibles** en `Menus` con el permiso **116 VER PLANES MANTENIMIENTO**, como el resto de los detalles del módulo: un ítem propio abriría la grilla sin hito y mostraría todas las actividades de todos los planes. La escritura la sigue pidiendo la función «Crear y editar», y se vuelve a exigir **en el servidor** al guardar y al eliminar, no solo escondiendo el botón. Semilla `_SEMILLA_PLAN_ACTIVIDADES.sql` con 15 actividades en cuatro hitos: uno en borrador para probar la escritura y tres publicados para ver la pantalla llena |
| 25-09-2026 | **HU-082 cerrada de punta a punta, y tres cosas que aparecieron al probarla.** Los criterios de la historia no se cumplen con el CRUD: dicen que la actividad TERMINE dentro de la orden. Se recorrió el camino completo —agregar el repuesto, publicar la versión, generar las ocurrencias, generar la orden y mirarla— y salieron tres huecos reales. **Uno**: `Plan_Actividad_Repuesto` tenía tabla, índice único y un `INS_ORDEN_TRABAJO_OCURRENCIA` que la leía para escribir la cantidad planificada de la orden… y **ninguna pantalla ni SP que la escribiera**, así que esa consulta siempre leía cero. `BD/291` (`SEL/INS/DEL_PLAN_ACTIVIDAD_REPUESTO`) y la lista dentro de la ficha de la actividad, con aviso cuando en bodega hay menos de lo planificado. Sin `UPD` a propósito: es una lista de materiales, cambiar la cantidad es quitar y volver a agregar. **Dos**: la orden recibía `otp_obligatorio` del plan y **no lo mostraba en ninguna parte** —seis pasos idénticos y ninguna forma de saber cuál se puede declarar «no aplica»—; ahora el paso opcional se marca en la lista y el detalle lo explica. Solo se marca lo opcional: si casi todo es obligatorio, un cartel en cada fila esconde justamente al que importa. **Tres**: al abrir una versión nueva, sus hitos quedaban **sin ninguna puerta**. El centro del plan mostraba siempre «la versión que manda» —la publicada—, así que la pantalla decía «para cambiarlo, abra una versión nueva» y después no había dónde entrar. El centro pasa a mostrar el **borrador** cuando existe, que es para lo que se abrió; el listado sigue mostrando la publicada, que es lo que se quiere ver en una lista. De paso, la lista de actividades dejó de ofrecer «Nueva» y «Eliminar» sobre una versión publicada, dos líneas debajo del aviso que dice que no se edita. **Y una trampa que costó una corrida entera**: registrar una pantalla en `Menus` **no alcanza** —`Token.PuedeFuncion` lee `Menu_Funcion`, y sin esas filas la barra de comandos no se dibuja para nadie, con el peor síntoma posible: el usuario tiene el permiso y concluye que no lo tiene. Quedó en `BD/290` y en §7. 13 casos de evidencia, los cuatro criterios en verde |
| 26-09-2026 | **HU-087 · Bandeja de mantenciones (`BD/292`, `BD/293`).** Lo que está por vencer o ya venció, de todos los planes y en una pantalla. **Por qué un SP propio y no un parámetro más en `SEL_PLAN_CALENDARIO`**: se parecen, y esa es la trampa. El calendario responde «qué le toca a ESTE plan este año» y filtra por **estado**, que es un dato guardado; la bandeja responde «qué tengo encima AHORA» y filtra por **situación**, que es derivada —vencida, atrasada, disponible y futura no existen en ninguna tabla— y para filtrar por ella hay que calcularla primero, de ahí el CTE. Además devuelve un **segundo result set con los contadores**, que cuentan todo lo que cumple el filtro y no la página que se mira; la situación elegida no se les aplica, porque son la botonera con la que se cambia de situación y filtrándose a sí mismos no habría cómo salir. `IX_PMO_ABIERTAS` es un índice **filtrado** por los estados abiertos: las cerradas se acumulan para siempre y las abiertas no, así que sin él el recorrido crecía sin que creciera lo buscado. La pantalla va **visible** en el menú —es de entrada, no un detalle— y suma «Generar órdenes de trabajo» sobre lo seleccionado: el criterio 3 de la historia, con el SP que ya existía; una bandeja que muestra siete vencidas sin poder hacer nada con ellas obliga a entrar plan por plan. Un hito **sin actividades** se avisa en la fila, antes de generar, porque esa orden sale con un solo paso. Semilla `_SEMILLA_BANDEJA_DISPONIBLES.sql`: tres situaciones salían solas de los datos, DISPONIBLE no aparece nunca porque dura lo que la ventana de tolerancia. **Y dos defectos que aparecieron probándola**: el markup metido dentro de un `asp:LinkButton` **no sobrevive al re-render asíncrono** —la primera carga pinta la tarjeta y al apretarla vuelve un `<a>` vacío—, y `__doPostBack(target, argumento)` desde un `onclick` armado en servidor **llega sin argumento**: el postback ocurre, sin error, y el handler no sabe qué se apretó. Los dos se resuelven con el par que ya usa el centro del plan: campo oculto + un LinkButton que solo dispara. El segundo también tenía muerto el «Quitar» de los repuestos de la actividad. 3 casos de evidencia, los tres criterios en verde |
| 26-09-2026 | **Cierre de las historias del plan: HU-080, 081, 083, 085 y 086 (`BD/294`, `BD/295`).** Las tareas pendientes eran de pruebas y documentación, pero dos criterios no se podían probar porque **nadie había escrito la funcionalidad**, y escribir un caso de prueba sobre algo que no existe no lo hace existir. **HU-083 #3**: el criterio pide *advertir* que el equipo ya está en otro plan vigente y *permitir continuar*. La diferencia importa: dos planes sobre un mismo equipo a veces es un descuido y a veces es lo correcto —uno de lubricación y otro de inspección legal—, y el sistema no puede distinguirlos; el planificador sí. Por eso es un `SELECT` (`SEL_PLAN_ACTIVO_COBERTURA`) consultado al elegir el equipo y no una validación del `INS`: una regla en el INS solo puede dejar pasar o rechazar, y acá hace falta una tercera cosa. **HU-086 #2**: el indicador de cumplimiento no existía. `SEL_PLAN_CUMPLIMIENTO` lo mide contra `pmo_fecha_programada_original_utc` —nunca contra la reprogramada— y devuelve **las dos cuentas** para que la pantalla muestre la diferencia; hoy marca 4,5% contra la original y 6,8% contra la vigente. Si reprogramar corriera también la vara, el indicador se dejaría en 100% moviendo fechas y medir dejaría de servir. La tolerancia viaja con la fecha: al medir contra la original se aplica la misma ventana que le dio su programación. **Y HU-086 estaba entera muerta**: `PlanOcurrenciaReprogramar.aspx` existía desde el bloque 202, con su SP y su fila en `Menus`, y **ningún lugar la abría**. Se le dio entrada desde la bandeja, en las filas abiertas y sin orden, que es lo que el SP acepta. Al usarla por primera vez salieron **tres defectos que nunca se habían ejecutado**: (1) `PLAN_OCURRENCIA_REPROGRAMAR` copiaba la ventana de tolerancia sin moverla, así que reprogramar más allá de la tolerancia —el caso normal— reventaba contra `CK_PMO_LIMITE`, y cuando no reventaba la ocurrencia nueva nacía ya vencida (`BD/295`); (2) el botón llevaba `OnClientClick="return ConfirSweetAlert(…)"` y en un `PushButton` eso deja al `__doPostBack` que ASP.NET agrega detrás como código muerto: mostraba la confirmación, se apretaba SI y no pasaba absolutamente nada; (3) «Nueva fecha» es un `<input type="date">` y el serializador de formularios de ASP.NET AJAX salta los tipos HTML5, así que dentro de un UpdatePanel la fecha nunca llegaba al servidor —«Indique la nueva fecha» con la fecha escrita en la pantalla—. Se resolvió registrando el botón para postback completo, que es la razón por la que las otras fichas del módulo tienen esa línea. De paso, en `PlanActivo.aspx` el combo de plan iba `Enabled = false` y un control deshabilitado no viaja en el postback: al elegir el equipo se perdía y Guardar rechazaba por «Plan(\*)» sin que nadie hubiera tocado ese campo |
| 26-09-2026 | **El módulo se llama Centro de Mantenimiento, y Planificación pasa a ser su punto de entrada (`BD/296`).** Se analizó unificar Programaciones, Plan de mantenimiento y Bandeja en un solo controlador/vista: **no conviene**, y es una medición, no una opinión — Programaciones pesa 80 KB de ViewState y 2.314 nodos de DOM con el listado vacío, su ficha 45 KB, el Centro del plan 25 KB, la Bandeja 34 KB, y ninguna desactiva ViewState en ningún control; juntarlas suma ese peso en cada postback parcial. Lo que sí se unificó es la **entrada**: el nodo padre «Mantenimiento» (2154) pasa a llamarse **Centro de Mantenimiento**, y su hijo «Planificación» (2222) deja de ser carpeta y apunta a `Planificacion.aspx`, una página liviana —sin RadGrid ni UpdatePanel— con los KPIs y tres tarjetas hacia las pantallas reales. Programaciones, Planes y Bandeja salen del sidebar (`mnu_visible = 0`) **sin cambiar su permiso**. No se dejó el nodo como carpeta con hijos visibles porque `MenusLateral.ascx.cs` resuelve un nodo por una sola rama: con link real, agrega los `<li>` de sus hijos sin envolverlos en un `<ul>` —código nunca ejercitado, ningún nodo del sistema tenía link y hijos a la vez—. El hub exige el permiso 116: quien solo tiene 92 (Programaciones) no lo ve y sigue entrando por URL; unificar permisos es otra decisión. Además, para Diseño: **propuesta de Planificación 360** (pestañas Resumen, Bandeja, Calendario, Planes, Programaciones, Cumplimiento —que cerraría HU-181 reusando `SEL_PLAN_CUMPLIMIENTO`— y Cobertura), con pestañas cargadas por WebMethod al abrirlas (precedente: `WsProgramacion.cs`) y meta de <10 KB de ViewState; y 31 capturas de todas las pantallas del dominio en `Fase 2/Diseno/Planificacion360/`. Al recorrerlas apareció otra pantalla huérfana: `PlanVersion.aspx` está en el menú y nada la abre |
| 26-09-2026 | **Planificación 360 implementada según la entrega de Diseño (7 vistas) — `BD/297`, `BD/298`, `BD/299`.** La página `Planificacion.aspx` pasa a ser el centro completo: cabecera con planta y período (selector propio de mes y año, no la lista del navegador), cuatro KPIs (atención y disponibles a hoy, cumplimiento enero-hoy, carga de 4 semanas) y siete pestañas — Resumen, Bandeja, Calendario (grilla de mes tipo Outlook + carga semanal + agenda del día; cada mantención abre su registro en otra pestaña: la OT si existe, si no el Centro del plan en su calendario vía `Sec=calendario`), Planes (versión publicada y borrador por separado), Programaciones (fecha única muestra UNA fecha, calendario/intervalo hasta tres, medidor/condición su disparador; «dónde se usa» enlaza planes, tareas y pautas), Cumplimiento (cohorte por fecha original, denominador programadas, reprogramadas transversal) y Cobertura. **Sin UpdatePanel, sin RadGrid, ViewState apagado**: todo se pide a `WsPlanificacion360.asmx` al abrir cada pestaña, con sesión y permiso validados en cada llamada (92 para Programaciones, 116 el resto, CREAR ORDEN TRABAJO para generar; el SP de generar OT devuelve la existente, no duplica). Pestaña, planta y período viven en la URL (`#tab=…`) para volver igual desde un editor. **Dos bugs corregidos de la versión previa**: las pestañas eran `<button>` sin `type` dentro del form del master (= submit y postback) y el code-behind hacía `if (IsPostBack) return` con ViewState apagado, así que el postback dejaba la página vacía. `BD/298`/`299` agregan lo que los mockups piden y no existía: id y estado de la OT en actividad reciente, criticidad/área y filtros en cobertura, sus cuatro números, atrasadas/omitidas por equipo, personas/repuestos/permiso por hito y cambios/última edición/responsable de cada borrador. Los SP con `FOR XML` exigen aplicar con `-I` (QUOTED_IDENTIFIER). Programaciones (2155) quedó visible en el menú a propósito (`BD/297`): Planificación exige 116 y quien solo tiene 92 perdía la entrada. Sin dato de origen, «Responsable» de Cobertura no se muestra. Evidencia: `_scratch/ev_p360_diseno.py` (16/16) y `ev_p360_periodo.py` (9/9) |
| 26-09-2026 | **Identidad SIGMA y menú de Programaciones (`BD/300`).** El estándar de UI queda en `CLAUDE.md` (fuente: `Fase 2/Diseno/Planificacion360/SIGMA-Paleta-UI-Propuesta.html`) y Planificación 360 lo aplica: morado `#6732F4` primario y pestaña activa, turquesa oscuro `#007F8A` para Reprogramar y Carga masiva, contorno azul `#087BEA` para abrir/editar/exportar, foco turquesa, semánticos solo para estados; sin degradados (rechazados por Bryan). **Programaciones (2155) pasa a hermana de Planificación** bajo Centro de Mantenimiento (orden 2; Procedimientos corre a 3): `BD/297` la había vuelto visible pero seguía colgando de Planificación, que desde `BD/296` es página y no carpeta — `MenusLateral` agrega los hijos de una página sin `<ul>` y salía como ítem huérfano con otra sangría; además a quien solo tiene 92 no se le muestra el padre (116). Se ajustó además el ancho: a ≤1500 px las 7 pestañas caben y el Resumen se apila. Regresión: `ev_p360_diseno.py` 16/16, `ev_p360_periodo.py` 9/9 |
| 27-09-2026 | **HU-084 pasa a Bryan y queda con sus 5 criterios verificados (`BD/301`); HU-094 y HU-102 quedan al equipo.** El #4 (publicación simultánea) se probó con dos sesiones `sqlcmd` a la vez sobre PMA-2 v2 (`_scratch/ev_hu084_carrera.py`): A publica y retiene el bloqueo 6 s, B queda esperando y, al liberarse, la validación de estado del envoltorio ve la versión ya publicada y la rechaza. La carrera ya estaba bien resuelta (`UPDATE … WHERE estado = BORRADOR` + `@@ROWCOUNT`); lo que no calzaba era el **mensaje** — el rechazado leía «Solo se publica una versión en borrador», que suena a error suyo; `BD/301` lo cambia a «La versión ya no está en borrador: otro usuario la publicó o la retiró» en el envoltorio y en el SP base, y en el base deja el ROLLBACK solo en el CATCH. **Trampa:** restaurar datos pasando texto no ASCII por `sqlcmd -Q` lo corrompe (U+FFFD); se reparó la observación de la v1 de PMA-2 y el script ya no reescribe textos. **Traspaso al equipo (Bryan no las cierra):** HU-094 (Emilio; pruebas T-4210 y doc T-4211 de Catalina) **no puede cumplir sus criterios #1 y #2 porque no existe generador de ocurrencias de pautas** — `GEN_PLAN_OCURRENCIAS` y `GEN_TAREA_OCURRENCIAS` existen, el de `Checklist_Programacion` no. Queda una propuesta escrita y probada en transacción revertida en `BD/propuestas/HU-094_GEN_CHECKLIST_OCURRENCIAS.sql` (generador idempotente + asignación al responsable/grupo + índice único filtrado + `SEL_CHECKLIST_PROGRAMACION_OCURRENCIA`), **retirada de la base**: le falta el botón en `ChecklistProgramacion.aspx`. El #3 (sin objetivo) ya se rechaza en la ficha y en el SP. HU-102 #2 (T-4294/T-4295, Emilio): la generación funciona — con la programación 35 «Evidencia S4 · HU-102 · Cuatro fechas» asociada a TAR-EV1822 se generan 4 ocurrencias independientes (ids 21-24), cada una con su detalle; esos datos quedan para que Emilio los use o los reemplace. La evidencia de Bryan no se dejó en el manifiesto: HU-102 la construyó Bryan y la verificación es cruzada |
| 27-09-2026 | **Las actividades del hito se crean dentro del hito (Centro del plan › Hitos).** Antes el hito desplegado solo tenía un enlace a `PlanActividades.aspx`, otra página. Ahora el detalle del hito trae su lista de actividades (N°, código, actividad con su procedimiento, duración, lo que exige, estado) con **«Nueva actividad»** y el lápiz para editar, ambos en el modal de siempre (`PlanActividad.aspx`, con el hito ya elegido). Al guardar y cerrar, el centro se refresca en la pestaña Hitos y **el mismo hito vuelve desplegado** (`hdnHitoAbierto`). Las actividades de todos los hitos salen en una sola consulta por versión. En versión publicada la lista se lee (ojo en vez de lápiz) y no aparece «Nueva actividad». Las dadas de baja no se muestran. `PlanActividades.aspx` sigue existiendo pero ya no se enlaza desde el centro. Evidencia: `_scratch/ev_actividad_inline.py` 12/12 |
| 27-09-2026 | **HU-118 en la web: UN cuadro de firma en la pestaña Cierre de la orden, sin modal (`BD/302`).** La firma de cierre y las de aceptación/ejecución/validación eran dos cuadros y se leían como dos cosas que firmar: ahora es un solo trazo con «Qué firma» (aceptación, validación, ejecución), resultado (aprobado/rechazado, motivo obligatorio al rechazar), observación y dos acciones — **«Registrar firma»** (turquesa, permiso VALIDAR ORDEN TRABAJO) y **«Firmar y cerrar OT»** (morado, facultad Cerrar). Arriba, el historial (tipo, resultado, quién, cuándo, observación, la imagen de la firma) y la condición **derivada al leer**: Validada / Validación rechazada / Sin validar según la ÚLTIMA firma de validación. Escribe por `API_INS_ORDEN_TRABAJO_VALIDACION`, el SP de la app (idempotente por uuid; el uuid nace antes de guardar), y lee con `SEL_ORDEN_TRABAJO_VALIDACION` (nuevo: devuelve el id del archivo de la firma). La tabla `Orden_Trabajo_Firma` que nombraban las tareas nunca existió: se hizo como `Orden_Trabajo_Validacion`. Una primera versión con ficha modal dejó la fila de menú 2231 oculta y sin página (no se borra). `sigma-orden.css` gana `es-ok/es-error/es-neutro` y `es-secundario`. Evidencia `_scratch/ev_hu118_firma_unica.py` 11/11 |
| 27-09-2026 | **Backlog ordenado (S1, S4, S5) y nuevo criterio de reparto.** S1: T-1040 y T-1069 validadas con la PO. S4: T-4197/T-4198 desbloqueadas (el desarrollo de HU-093 existe); T-4135 a T-4137 (HU-091) y T-4304/T-4305 (HU-097) desbloqueadas y pasadas a Catalina, dueña de esas historias, para que no esperen a otra persona; **HU-101 conciliada** — sus 10 tareas de BD/web/seguridad ya estaban hechas con HU-102 (BD/218, `Tareas.aspx`, `Tarea.aspx`, menús 2190/2191) y quedan Terminadas sin horas, faltan sus pruebas/doc; HU-160 y HU-103 corregidas a «Movida a Sprint 6». S5: T-5244/T-5245 de HU-118 terminadas y las seis historias pendientes repartidas **por historia completa, sin verificación cruzada** (decisión de Bryan): Bryan HU-117 + HU-125 (tocan la OT, que él construyó) 11,5 h; Catalina HU-142 + HU-143 (ambas sobre `Archivo_Vinculo`) 10 h, menos porque arrastra HU-091/092/097 del S4; Emilio HU-131 + HU-162 14 h. Riesgo anotado: HU-142/143 dependen de HU-140 y HU-131 de HU-130, que son de la app (S6) — la web puede avanzar con los archivos y la bitácora que ya existen. Respaldos `_BACKUP_PRE_ORDEN_27092026.xlsx` |
| 27-09-2026 | **Centro del plan con combo de planta (`BD/303`).** En la cabecera, igual al de Planificación: todas las plantas del cliente; filtra lo que se VE —indicadores, resumen, equipos y calendario (`filtro_instalacion`)—, no el plan: hitos y actividades son los mismos en todas las plantas. Si el plan está acotado a una planta, el combo queda fijo en ella y deshabilitado. `SEL_PLAN_ACTIVO` devuelve además `PLANTA_ID` para filtrar por id y no por nombre. Evidencia `_scratch/ev_plan_planta.py` 10/10 |
| 27-09-2026 | **OT con la identidad SIGMA y combos con su flecha; merge a medias resuelto.** Una sesión de Claude en la nube subió a `origin/BryanChavez` tres commits (`ad10caa` menos morado en la OT, `59f1e86` quita la línea de los RadComboBox, `256c915` quita el border-left junto al combo) y alguien hizo `git pull` aquí: quedó un merge con conflicto en `OrdenTrabajo.aspx` y **los marcadores `<<<<<<<` se veían en la página**. Se resolvió (sigma-modal vrs=9, sigma-orden vrs=6) y quedó con `git add`, **sin el commit del merge**. Además: `59f1e86` anuló el background de la celda de la flecha y se llevó también **la flecha** (el skin la dibujaba con ese sprite) — ahora es un chevron SVG propio con la celda fija en 32 px (`RadComboBox.css`, vrs=4 en los tres masters). En la OT, dentro de `.sg-ot`: violeta de marca `#6732F4`, enlaces e iconos informativos azul `#087BEA`, «Volver a órdenes» con contorno azul (`es-contorno`), la estrategia deja el rojo por turquesa suave (el rojo es para lo crítico), los cuatro KPIs alternan morado/turquesa/azul/ámbar suaves y el foco es turquesa |
| 27-09-2026 | **Documentos al día (sin los informes de pruebas).** S2 cerrado: T-2017 validada (regla de Bryan: las validaciones con la PO se registran siempre como OK). Borradores de **Sprint Review 2 y Retrospective 2** (`Fase 2/Ceremonias`, generador `_scratch/gen_ceremonias_s2.py`): datos, pruebas (51/53; los 2 son de la app sin conexión) y seguimiento de los acuerdos A1–A7 completos; comentarios del cliente, decisiones y acuerdos nuevos quedan para completar en la reunión del 29-09. `SIGMA_Pendientes_por_Sprint.xlsx` regenerado desde los seis backlogs (`_scratch/datos_pendientes.py` rearma `reporte.json`, que venía con los acentos rotos): S1 y S2 en 0, S3 4, S4 53, S5 69. `SIGMA_Product_Backlog_por_Sprint.xlsx`: estado y responsable de 108 historias sincronizados desde los Sprint Backlogs. Bitácora de dailies: las filas de S4/S5 que decían que HU-082 bloqueaba a Bryan y que la web de HU-118 quedaba pendiente se corrigieron con lo real (reparto del plan a Bryan, HU-082, HU-087, cierre de HU-080..086, carrera de HU-084, firma web y reparto por historia completa). Respaldos `_BACKUP_PRE_27092026`. Los informes de pruebas S4/S5 se regeneran cuando se cierren las tareas que faltan |
| 27-09-2026 | **Sprint 3 cerrado — y la etiqueta A4 medía mal.** Validaciones de la PO T-3029, T-3041 y T-3055 en OK. T-3928 (HU-066, «la etiqueta mide lo que dice») pasa de Catalina a Bryan y se verifica midiendo el PDF de impresión con modo impresión emulado (`_scratch/ev_hu066_medida.py`): el térmico medía 50 × 25 exacto, pero **las hojas A4 salían de 68 × 36 y 97 × 56 mm** en vez de 70 × 37 y 99 × 57 — con 8 mm de margen y 2 mm entre etiquetas la plancha no cabía y alguien había achicado las etiquetas, así que impresas sobre la plancha troquelada no calzaban. Corregido: tamaños exactos en `sigma-impresion.css` (vrs=3), sin separación al imprimir, y `@page` por formato en `Etiquetas.aspx.cs` (3 × 8 sin margen, 2 × 5 con 6 mm, térmico 50 × 25). Los tres formatos miden lo declarado (±1 mm). Falta solo la verificación con regla sobre papel real. El Sprint 3 queda sin pendientes |
| 01-10-2026 | **Entregable #12 de Fase 2 — Documento de Diseño.** `Fase 2/SIGMA_Documento_Diseno.docx`, generado por `_scratch/gen_diseno.py` sobre 8 diagramas Mermaid renderizados a PNG vía la API pública `mermaid.ink` (`_scratch/render_mermaid.py`; el endpoint real exige `width` o `height` junto a `scale`, si no tira 400). Contiene: C4 Contexto y Contenedores, diagrama de Componentes (patrón Controller/Model, seguridad por datos), modelo ER de los dos núcleos del dominio (Plan de Mantenimiento y Orden de Trabajo, con las FK reales de la base), diagrama de Casos de Uso por épica, diagrama de Clases y diagrama de Secuencia del flujo real `PlanOcurrenciaController.GenerarOrden()` (idempotente por `yaExistia`, transaccional con `XACT_ABORT`). El código fuente de cada diagrama queda en el Anexo del documento para que el equipo lo pueda regenerar o corregir editando texto. Entregable #1 (Objetivos y metodología ajustados) sigue explícitamente fuera por pedido de Bryan |
| 01-10-2026 | **Manual de Operación en Word: `Fase 2/SIGMA_Manual_de_Operacion.docx`.** Bryan lo pidió en Word, no en MD. Un solo documento con los **20 módulos** como capítulos —misma razón por la que se consolidó el informe de pruebas: veinte archivos sueltos obligan a buscar—. 148 tablas. Abre con el **orden para recorrer el sistema desde cero** (acceso → plantas → catálogos → activos → medidores → repuestos → terceros → programaciones → planes → checklist → tareas → órdenes → bitácora → evidencias → SIGMA AI e indicadores) y cierra con una tabla de síntomas. Los MD de `MD/Manuales` se mantienen: son la versión consultable desde el repositorio y comparten el generador. Ambos se regeneran (`gen_manuales.py` y `gen_manuales_word.py`) |
| 01-10-2026 | **Manuales de operación: uno por módulo, en `MD/Manuales`.** Veinte manuales más un índice, generados por `_scratch/gen_manuales.py` desde fuentes que ya existen y están verificadas: el objetivo sale de la hoja **Épicas**, lo que se puede hacer de las **138 historias** con su «como/quiero/para», el paso a paso de los **563 campos de entrada** declarados por historia (etiqueta, control, si es obligatorio y qué valida), las reglas de los **409 criterios de aceptación**, y las pantallas y permisos de la tabla **`Menus`** —que es la fuente de verdad: en SIGMA una pantalla existe cuando tiene su fila ahí—. Cada manual trae: dónde está en el menú con su ruta y permiso, qué permisos hacen falta, **qué tiene que existir antes** (las dependencias entre historias, que es lo que evita empezar por el módulo equivocado), el paso a paso por historia, **lo que el sistema no deja hacer** (los criterios de rechazo, que viven en el servidor y aplican también desde la API y la app) y una tabla de síntomas. El índice propone el orden para recorrer el sistema desde cero: acceso → plantas → catálogos → activos → medidores → repuestos → terceros → programaciones → planes → checklist → tareas → órdenes → bitácora → evidencias → SIGMA AI → indicadores. **Se regeneran**, no se editan a mano: si cambia una historia, el manual queda al día; escrito a mano, a la tercera semana diría algo distinto del sistema. Trampa encontrada: `sqlcmd` devolvía los nombres de menú con los acentos rotos al pasar por la consola — hay que volcar con `-o` para que respete el `-f 65001` |
| 01-10-2026 | **Repositorio limpio: 2,1 GB menos, un informe por sprint y cero respaldos dentro.** **(1) Temporales:** se eliminaron `_program files_git/`, `_program files_git_check/` y `_program files_git_intranet/` (476 MB de salida de `aspnet_compiler`, 1.711 archivos) más el `build/` de Flutter y el `obj/` de la API (1,65 GB, se regeneran). Ojo: `_program files_git/` **no estaba en el `.gitignore`** y se coló en un commit de 1.104 archivos; se deshizo con `reset --soft` antes de publicar y la regla quedó agregada. **(2) Evidencia consolidada:** los nueve informes por historia del S4 y el de la API de HU-001 se **incrustaron completos** —texto, tablas y capturas, con `docxcompose`— dentro del informe de su sprint, y recién entonces se eliminaron los archivos sueltos. El informe del S4 queda con 723 párrafos, 94 tablas y 114 capturas; el del S1 sumó 10 capturas. **Quedan cero informes por historia sueltos.** **(3) Respaldos:** se eliminaron los 20 `_BACKUP_PRE_*` de Word, Excel y JSON — el historial de git ya guarda la versión anterior de cada archivo— y el `.gitignore` ahora los excluye. **Cambio de práctica por instrucción de Bryan: los respaldos se hacen en `_scratch`, fuera del repositorio, nunca dentro de `Fase 2`.** **(4) Credenciales:** se borraron los temporales de consulta y el `_body.json` que había quedado con una contraseña dentro |
| 01-10-2026 | **Sprint 4 cerrado — y las pruebas que faltaban destaparon un defecto de dos semanas.** Quedaban 9 tareas: 5 validaciones con la PO (cierran OK por la regla del proyecto) y 4 de trabajo real, las pruebas y la documentación de **HU-090** y **HU-093**, las dos únicas historias sin evidencia. Las tres tareas de HU-090 que eran de Emilio **pasan a Bryan** por instrucción suya. Al ejecutar HU-090 CA1 apareció el defecto: **`INS_CHECKLIST_PLANTILLA` creaba la plantilla sin su versión 1 en borrador** —ni el SP ni `ChecklistPlantillaController` la insertaban—, así que una plantilla recién creada no se podía completar (secciones e ítems cuelgan de la versión) y al publicarla respondía «3.- NO HAY UNA VERSIÓN EN BORRADOR PARA PUBLICAR». Corregido en **`BD/321`**: la versión 1 se crea en la misma transacción que la plantilla, más la reparación de las plantillas que ya habían quedado sin versión (reparó 2). Va en el SP y no en el controller porque la plantilla y su versión 1 son un solo hecho de negocio: si la creara la web, la API y cualquier carga masiva tendrían que acordarse de hacerlo. Con eso, **8 de 8 casos conformes** y el Sprint 4 queda en **19 historias terminadas (109 pts), 5 movidas al S6 (39 pts), 218 tareas terminadas, cero pendientes**. Los datos de prueba (`PRB-S4-*`) se eliminaron de la base al terminar |
| 01-10-2026 | **Informe de pruebas del S4 consolidado, y por qué hacía falta.** El equipo usó **dos formatos de evidencia**: el manifiesto compartido y **nueve informes por historia** (`SIGMA_Pruebas_HU-0XX.docx`) que escribieron Catalina y Emilio. Contar solo el manifiesto daba un falso negativo —HU-091, 092, 094, 097, 100 y 101 parecían sin probar y no lo estaban—. `_scratch/consolidar_pruebas_s4.py` lee los nueve informes y anexa al informe del sprint sus casos y el resumen: **20 historias con evidencia, 78 casos**. Quedó como acuerdo **A14** de la retrospectiva: todo caso entra al manifiesto, cualquiera sea el formato en que se documente además. **Ceremonias del S4** generadas con fecha 27-10-2026 (`_scratch/gen_ceremonias_s4.py`): Review con los 4 comentarios del cliente —el versionado de la pauta era su mayor duda y fue lo que más tranquilidad dio— y Retrospective con el seguimiento de A10–A13 (A12, horas reales, **tercer sprint incumplido**) y los acuerdos A14–A17 |
| 01-10-2026 | **Equipo sincronizado: se integra el trabajo de Catalina y Emilio.** 18 commits que no estaban en `BryanChavez`: **12 de Catalina** (HU-091 umbrales y acciones de un ítem, HU-092 dependencias entre ítems, HU-094 generador de ocurrencias, HU-096 bandeja de hallazgos, HU-097 historial de ejecuciones, HU-100 categorías de tarea, HU-101 mantenedor de tareas, HU-102, HU-104) y **5 de Emilio** (Pautas 360 fase 1, Inspección 360 con borrador clonado y guardado no destructivo). Merge **sin conflictos**: 80 archivos, +6.229 líneas; la Intranet compila con `aspnet_compiler`. **Ojo con el push a `CatalinaPescio`: fue rechazado porque tenía un commit sin integrar** (`bfc6bd2`, tildes de los menús de checklist con NCHAR para evitar mojibake al aplicar los scripts 308 y 310) — se trajo con merge en vez de pisarlo. Las cuatro ramas quedan en `e0e2324`. **Hallazgo sobre la evidencia:** Catalina y Emilio documentan las pruebas como **un Word por historia** (`Fase 2/Pruebas/SIGMA_Pruebas_HU-0XX.docx`, nueve archivos) y **no** en el manifiesto JSON compartido, así que un conteo contra el manifiesto da falso negativo: HU-091, 092, 094, 097, 100 y 101 parecen «sin evidencia» y no lo están. Conviene unificar el formato o el informe del sprint quedará incompleto |
| 01-10-2026 | **Faltaban 36 archivos del disco: `Fase 2/Diseno/Planificacion360` entero.** Aparecieron como borrados sin confirmar en `git status` —la paleta `SIGMA-Paleta-UI-Propuesta.html` que `CLAUDE.md` declara como fuente obligatoria del estándar de UI, los dos MD de propuesta, las 32 capturas y el .zip—. No fue un commit de nadie: estaban eliminados solo en el árbol de trabajo. Restaurados con `git checkout --`; no se perdió nada porque estaban versionados |
| 01-10-2026 | **Intento de construir las imágenes: bloqueado por el equipo, y dos defectos reales encontrados.** Docker Desktop está en modo Linux y al cambiarlo responde **«windows containers have been disabled for this installation»**: el servicio **`cexecsvc` no existe**, o sea la característica **Containers** de Windows no está instalada. **No es política de la organización** —no hay `admin-settings.json` ni claves en `HKLM\SOFTWARE\Policies\Docker`—, solo falta habilitarla con `Enable-WindowsOptionalFeature -Online -FeatureName Containers -All` **como administrador y reiniciando**. Sin eso no se puede construir. Lo que sí se validó con `docker build --check` (que no necesita construir) destapó **dos defectos reales en los Dockerfile**: (1) faltaba **`# escape=\`` en la primera línea** — sin eso cada `C:\inetpub` se interpreta como escape y el backtick de continuación de PowerShell rompe el análisis con `unknown instruction`; es la trampa clásica de los contenedores Windows; (2) la restauración de NuGet apuntaba a `Solucion\packages` cuando el `HintPath` del csproj busca en **`Solucion\SIGMA\packages`** (`..\packages` relativo al proyecto) — y eso no falla en la restauración, compila igual de mal con cientos de errores de tipo. Ambos corregidos y documentados en el README. Además se verificó nativamente que los comandos del Dockerfile funcionan: `Library.csproj` y `API.csproj` compilan con el MSBuild de VS2022. Quedan dos advertencias del `--check` que **no** son defectos (`InvalidBaseImagePlatform` y `WorkdirRelativePath`): son del comprobador corriendo en modo Linux, donde `C:\src` le parece ruta relativa |
| 01-10-2026 | **Entregables #9 y #11 — Dockerización y Manual Técnico.** **Docker:** `docker-compose.yml` en la raíz y `INFRAESTRUCTURA/docker/` con dos Dockerfile multietapa, dos entrypoints PowerShell, `.env.example` (30 variables) y README. `docker compose config` valida OK; **las imágenes no se han construido** (hay que poner Docker Desktop en modo Windows y bajar varios GB). Decisiones que quedan escritas: **contenedores Windows obligatorios** (WebForms 4.8 sobre IIS, no hay imagen Linux posible); **la base NO se contenedoriza** —no existe imagen oficial de SQL Server para contenedores Windows y Docker no corre Linux y Windows a la vez, y además en producción la administra el hosting—; **se compila dentro de la imagen** porque `bin/` está en `.gitignore` y copiar un bin local haría que el contenedor dependiera del equipo de quien lo construyó; **ninguna credencial en la imagen** (quedaría en el historial de capas para siempre), todo entra por variable al arrancar; **dos imágenes, no una**, para reproducir la separación de app pools; y **sin `SIGMA_DB_CONNECTION` o `SIGMA_JWT_SECRET` el contenedor no arranca** a propósito. Hallazgos del camino: el `Bin` de la Intranet es **exactamente** la salida de `Librerias/Library/bin/Release` (43 archivos, coinciden uno a uno), las dependencias de terceros **sí** están versionadas en `Librerias/Library/Lib`, y el **MSBuild del Framework v4.0 no sirve** —la tarea de licencias de Telerik exige MSBuild 15+, hay que usar el de VS2022. Se agregó `.env`/`.env.*` al `.gitignore` con excepción para `.env.example`: no estaba, y un `.env` con credenciales reales se habría versionado. **Manual:** `Fase 2/SIGMA_Manual_Tecnico_Despliegue.docx` con requisitos, estructura, compilación, scripts de BD, pruebas, orden de despliegue a SmarterASP, contenedores, convenciones y 8 problemas conocidos con su causa y solución |
| 01-10-2026 | **Pruebas unitarias de la API: nace `API.Pruebas`.** 36 pruebas con xUnit sobre .NET 4.8, agregadas a `SIGMA.sln` y corriendo con `dotnet test` en ~1 s, sin servidor web ni base. **No referencia `API.csproj`: enlaza los archivos fuente** (`<Compile Include="..\API\Utils\...">`), porque compilar el proyecto web clásico arrastra toda la cadena de ASP.NET y vuelve la corrida lenta y frágil; lo que se prueba es lógica pura, así que se prueba el mismo archivo que compila la API. Cubre **PuntuadorFalla** (21: estandarización, sigmoide, imputación de la característica que falta, orden por contribución, el umbral de 0,05 bajo el cual no se genera frase, que la frase nunca afirme que el equipo va a fallar, y los parámetros inconsistentes que deben reventar al construir) y **Pagina/Paginado** (15: que el tope se aplique, que recorrer todas las páginas no pierda ni duplique filas, que pedir más allá del final devuelva vacío y no error). **Validadas por mutación:** se invirtió el signo de la sigmoide y se anuló el tope de página, fallaron 6 pruebas, y se restauró verificando md5 — una prueba que no falla cuando el código se rompe no prueba nada |
| 01-10-2026 | **Mediciones de rendimiento ejecutadas — y lo que de verdad dejaron.** `_scratch/ev_rendimiento.py` mide las cuatro cosas que el Plan de Pruebas declara, con umbrales declarados en el archivo y su motivo; el informe `Fase 2/Pruebas/SIGMA_Mediciones_Rendimiento.docx` se genera desde `rendimiento.json`, sin transcribir números. **RNF-15:** los 10 endpoints medidos cumplen con holgura (mediana 12–351 ms contra un umbral de 1500). **RNF-12:** pedir 5.000 filas devuelve tamaño 200 — el tope se aplica en el servidor; es la única verificación que no depende del volumen. **RNF-14:** todas las pantallas cumplen, pero **Activos (91,8 KB) y Programaciones (90,2 KB) rozan el techo de 100 KB de ViewState** y crecen con las filas de la grilla. **RNF-11 — el hallazgo:** `SEL_ORDEN_TRABAJO` hace **5.155 lecturas lógicas para 59 filas (~87 por fila)**, contra 19 de `SEL_ACTIVO` y 18 de `SEL_REPUESTO`; hoy no se nota, con volumen va a doler. Hay que mirar su plan de ejecución. **RNF-19 no queda verificado y está dicho así en el informe:** la base tiene **5.667 filas en total** (23 activos, 59 órdenes, 8 repuestos) — es el juego del piloto, y un buen tiempo sobre 23 activos no dice nada sobre 40.000 |
| 01-10-2026 | **Trampas del camino a esas mediciones (quedan documentadas para no repetirlas).** (1) **No existe base de pruebas:** el servidor tiene una sola base, `db_acd593_sigma`, y el SQL Server local solo tiene BikeZ. El Plan de Pruebas v1.0 afirmaba que había una base separada —era falso, se corrigió en la v1.1—. Bryan decidió medir sobre la base real, solo lectura. (2) **`rodrigo` y `jonathan` tienen una contraseña distinta a la de `usuarios_prueba.json`** (se la cambiaron desde Mi Perfil, igual que le pasó a root). Se detectó **sin gastar intentos**, comparando el hash contra `FNC_PASSWORD_HASH` en vez de probar el login; ojo que la comparación hay que hacerla **emparejando cada usuario con su propia clave**, no cruzando todos contra todas, o da falso positivo. Aun así rodrigo quedó bloqueado 15 minutos por los intentos previos. Las corridas usan **`emilio`** (ámbito app y web, 64 permisos). (3) `SEL_LOGIN` devuelve el mismo mensaje para cuenta inexistente, clave mala y afiliación deshabilitada — por diseño, para no revelar qué correos existen; eso obliga a diagnosticar por la base. (4) Las rutas de la API y de las páginas hay que sacarlas de los `RoutePrefix`/`Route("")` y de la tabla `Menus`: `/activos` no tiene GET raíz y las URL inventadas dan 404 o caen al login (DOM de 20 nodos es la señal) |
| 01-10-2026 | **Entregable #8 — Plan de Pruebas.** `Fase 2/Pruebas/SIGMA_Plan_de_Pruebas.docx` (generador `_scratch/gen_plan_pruebas.py`). Es la **estrategia**, no el resultado: los resultados siguen en los seis informes por sprint. Define cuatro niveles (unitario, integración, sistema/aceptación, regresión), cuatro tipos (funcionales, seguridad, rendimiento, usabilidad/accesibilidad), el entorno, los seis perfiles de usuario de prueba, las herramientas, los criterios de entrada y salida, la gestión de defectos, la trazabilidad y los riesgos de la propia estrategia. Las pruebas de seguridad y de rendimiento **citan el RNF que verifican** (RNF-01..07, 10 para seguridad; RNF-11, 14, 15, 19 para rendimiento), así que los dos documentos quedan enganchados. Números reales de los manifiestos: **285 casos de aceptación, 281 conformes, 94 historias, 590 capturas, 15 defectos** (todos corregidos en su sprint y con caso de regresión), más **132 pruebas unitarias en Flutter** en 13 archivos. Principios que quedaron escritos porque son los que de verdad se aplicaron: un criterio de aceptación = un caso; se prueba donde vive la regla (si está en el SP, se prueba contra la base, porque probar una regla de servidor solo por pantalla da falso positivo); cada caso declara su usuario, y los casos de permiso se corren con el perfil que **no** debe poder; el informe se genera desde el manifiesto para que el documento no pueda decir algo distinto de lo que la corrida arrojó. **Lo que falta para cerrar el entregable: ejecutar las mediciones de rendimiento (no hay ninguna hoy) y decidir si se agregan unitarias en .NET (hoy no existe proyecto de pruebas)** |
| 01-10-2026 | **`EntrenadorFalla` queda planificado en el Sprint 6.** Bryan decidió no implementarlo ahora: las 5 tareas entran en **HU-172** («Entrenar y publicar una versión del modelo»), que ya estaba en el S6 — **T-6307** el entrenador en .NET dentro de la API (4 h), **T-6308** que `POST /sigma-ai/entrenamientos` entrene en el servidor en vez de recibir los pesos de fuera (2 h), **T-6309** exportar el ONNX y registrar la corrida en Azure ML (2 h), **T-6310** el criterio de aceptación del ADR-01 —entrenador .NET y de referencia dan los mismos pesos y la misma probabilidad— (2 h) y **T-6311** medir tiempo y memoria de una corrida, que es el umbral de revisión del ADR (1 h). Todas de Bryan. De paso se corrigió un defecto previo del archivo: **`Sprint!C32` («Horas planificadas en tareas») sumaba solo hasta la fila 204 de 514**, así que el total del sprint y la holgura venían mal; ahora cubre hasta la última fila, igual que en el S4 y el S5. Los `SUMIF` de horas por historia también se extendieron. Respaldo `_BACKUP_PRE_ENTRENADOR_01102026` |
| 01-10-2026 | **ADR-01 — SIGMA AI se entrena y se puntúa dentro de la API, en SmarterASP.** Decisión de Bryan tras evaluar tres opciones; queda documentada como registro de decisión de arquitectura en el §12.1 del Documento de Diseño, para poder defenderla ante la comisión. **Descartado A (Azure ML con cómputo):** el endpoint administrado cobra desde que se despliega aunque nadie lo llame y el job cobra por corrida; quedaría cubierto solo mientras dure el crédito de estudiante, o sea el sistema dejaría de funcionar por una razón administrativa, y además exige una entidad de servicio en Entra ID que **el tenant de grupoexpro no permite crear**. **Descartado B (el equipo del desarrollador):** es gratis y fue el camino con el que se probó la factibilidad, pero deja un paso del producto corriendo en el notebook de una persona. **Elegido C:** el entrenamiento se implementa en .NET como componente de la API (`EntrenadorFalla`), se lanza desde SIGMA AI › Experimentos y corre en el app pool que ya se paga (3 GB del plan Premium); Azure ML se mantiene **solo como registro** de modelos, corridas y artefactos, que no tiene cargo. Criterio de revisión explícito: si una corrida supera el minuto o la memoria se acerca al límite del app pool, se reevalúa la opción A. **Ojo: el código todavía entrena con `ML/entrenar_falla.py` en Python y local — falta implementar `EntrenadorFalla` en .NET dentro de la API; el algoritmo es el mismo y el criterio de aceptación es que ONNX y pesos den el mismo resultado** |
| 01-10-2026 | **MER completo: las 250 tablas documentadas, módulo por módulo.** Bryan pidió los ER de **todos** los módulos, no solo Plan y OT. `_scratch/esquema_dump.py` vuelca el esquema real por sqlcmd (`esquema.json`: **250 tablas, 2.786 columnas, 667 FK**) y `_scratch/gen_mer.py` lo agrupa en los **20 módulos** del Product Backlog —cobertura verificada: 249 de 249 tablas del modelo, `sysdiagrams` excluida— y genera **41 figuras** en `Fase 2/Diseno/capturas/mer`: una vista global de relaciones entre módulos (solo las de 3 FK o más, si no es ilegible) y el MER de cada módulo con **todas sus tablas y todas sus columnas**, partido en bloques de 9 entidades para que se lea en una página. El Documento de Diseño queda en **52 imágenes y 2.891 filas de tabla** (19 MB): §7 el MER completo con las convenciones del modelo, §8 el **diccionario de datos** con las 2.786 columnas (tipo exacto, nulabilidad, PK/FK y a qué tabla apunta cada FK). Trampa: `sqlcmd` no acepta `-W` junto con `-Y`, y en Mermaid un `#` en una etiqueta la trunca (`EntrenadorFalla (C#)` salía como `EntrenadorFalla (C`) |
| 01-10-2026 | **El Documento de Diseño pasa a cubrir el sistema completo, con Azure y SmarterASP.** Bryan pidió tres cosas: que el Word no imprimiera el código Mermaid (se veía como texto suelto en medio del documento), que los diagramas representaran el sistema **entero** —incluidos los servicios de Azure y el hosting productivo— y que las imágenes quedaran en una carpeta aparte para poder presentarlas. Hecho: **11 figuras** (antes 8) en `Fase 2/Diseno/capturas`, cada PNG con su `.mmd` al lado; el Word lleva **solo las imágenes**, escaladas para que cada una quepa completa en su página (ninguna supera 20 cm de alto). Nuevos diagramas: **despliegue** (SmarterASP.NET Premium con la Intranet y la API como dos sitios con app pool propio sobre el mismo IIS y SQL Server, más la base de pruebas separada; Azure Blob Storage, Machine Learning y Custom Vision colgando de la API), **mapa de los 20 módulos** (las 20 épicas reales del Product Backlog agrupadas por dependencia) y **secuencia de SIGMA AI** (dataset → entrenar en el equipo propio → registrar en Azure ML → publicar versión → puntuar dentro de la API). Contexto y contenedores ahora incluyen Azure, Google Maps, FCM, Google Play y el entrenador de modelos. Corregido de paso: la épica EP-19 es «Suscripción y modelo comercial», no «Validación del incremento» como decía la primera versión del diagrama de casos de uso. **Trampas de mermaid.ink que costaron varios intentos:** `direction` dentro de un `subgraph` se ignora (haya o no aristas entre subgrafos) y los enlaces invisibles `~~~` tampoco apilan — un mapa de 5 grupos salió de 2800×91 px y después de 2800×15887; la solución fue un nodo por grupo con sus ítems en el `<br/>` del rótulo. Además `width` fuerza el escalado, así que un diagrama naturalmente angosto se vuelve gigantesco: conviene orientarlo `LR` antes que subir la resolución. El servicio devuelve **503 esporádicos**: `render_mermaid.py` ya reintenta 3 veces |
| 01-10-2026 | **Los diagramas C4 y de casos de uso salieron ilegibles — rehechos como flowchart.** Bryan los vio: cajas y líneas superpuestas en los dos C4 (`C4Context`/`C4Container` de Mermaid no controla bien el layout cuando hay más de ~6 `Rel()`, las líneas atraviesan las cajas) y el de casos de uso con **fondo negro** más un abanico de líneas cruzadas (un actor conectado a cada caso de uso individual, no al grupo). Corregido en `_scratch/gen_diagramas.py`: los dos C4 pasan a `flowchart TB` con `classDef` (persona/sistema/contenedor/datos/externo) en vez de la sintaxis `C4Context`/`C4Container`; casos de uso conecta cada actor al **subgrafo de la épica**, no a cada caso suelto, lo que baja de ~20 aristas a ~12 y elimina el cruce. `render_mermaid.py` ahora fuerza `&bgColor=FFFFFF` en la URL (el fondo negro era mermaid.ink, no el visor). **Lección:** para C4 en mermaid.ink, usar `flowchart`/`graph` con `classDef` en vez de la sintaxis `C4Context`/`C4Container` — rinde mucho más prolijo |
| 03-10-2026 | **Mapa 3D de bodegas (`BD/325`, commit `ffaf756`).** Inventario › Mapa 3D de bodegas, con Three.js 0.160 **incluido en `Js/three`** (sin CDN: la demo no depende de que responda). La escena sale solo de la base —`SEL_BODEGA_MAPA_ESTRUCTURA` y `SEL_BODEGA_MAPA_SALDOS`—: el código de ubicación `P1-A-R01` se lee como pasillo A, rack 01 (impares a la izquierda, pares a la derecha); el stock sin ubicación se ve en una zona de recepción en vez de esconderse. **Sin postback ni modales**: todo va por `WsBodegaMapa.asmx` a los controllers de siempre (bodegas, racks con modo edición de racks fantasma, repuestos con fotos y umbrales, movimientos con las reglas de `Movimiento.aspx`). Las etiquetas de vigas, cabeceras, puntales, cajas y la de la bodega usan **el diseño y el QR del Centro de etiquetas** (`EtiquetaController.QrMatriz`, mismo token y corrección Q): lo que se ve en el fierro del mapa es lo que se imprime. La ficha del repuesto se abre en una ventana dentro del mapa. **Recorrido de pasillo** en primera persona con tablet: lista las cajas a medida que se miran, marca lo bajo mínimo, se pausa y salta de rack. **Defecto real encontrado de paso:** `Movimiento.aspx` no manda la ubicación de destino en el traslado (tipo 6), así que no se puede trasladar a una bodega con ubicaciones (regla 17 del SP); el mapa sí la manda. **Trampa:** generar un QR cuesta ~10 ms — mandar los 600 de los repuestos en cada carga la llevaba a 9 s; ahora los QR se cachean por proceso y los de repuesto se piden en lote (`Qr()`) solo para las cajas a las que se acerca la cámara |
| 03-10-2026 | **Conteo cíclico desde el recorrido (`BD/326`).** Nacen `Inventario_Conteo` (cabecera: bodega, alcance, quién, inicio, cierre, exactitud) e `Inventario_Conteo_Detalle` (una línea por caja: sistema, contado, diferencia calculada, movimientos que la corrigieron), con `INS_INVENTARIO_CONTEO`, `UPS_INVENTARIO_CONTEO_DETALLE`, `UPD_INVENTARIO_CONTEO_CERRAR` y `SEL_INVENTARIO_CONTEO_ULTIMO`. Con «Contar» activo, el recorrido se detiene en cada rack y la tablet pide lo que hay en cada caja (✓ si coincide, «Todo coincide», o la cantidad). **El conteo no mueve stock por su cuenta**: `WsBodegaMapa.ContarRack` ajusta la diferencia con `INS_INVENTARIO_MOVIMIENTO` (tipo 5 falta, sacado FEFO de los lotes de esa caja; tipo 4 sobra, al lote más reciente o al que indique el bodeguero), con permiso AJUSTAR INVENTARIO y motivo «Conteo cíclico N°…». **Lo que «decía el sistema» lo lee el servidor al confirmar**, no la pantalla. Recontar una caja actualiza su línea (no duplica) y conserva el primer valor del sistema para la exactitud. El panel del rack muestra el último conteo («hoy · 3/3 · 100%») y avisa si pasó más de 30 días o nunca se contó. Probado en local con 3 cajas coincidentes (conteo N° 1, cerrado al 100 %, **cero movimientos**); **el camino con diferencia —que sí genera ajustes en el kardex— no se probó contra la base** para no dejar ajustes en los datos del cliente. El reinicio (`BD/Reinicio`) no requiere cambios: lee las FK de la base y vacía toda tabla que no esté en `CONSERVAR` |
| 03-10-2026 | **Picking desde el mapa 3D (`BD/327`) y método de salida configurable FEFO / FIFO / LIFO (`BD/328`).** **Picking:** botón del carrito en la barra del mapa o «Agregar al picking» en el panel de una caja. Se elige una OT abierta —`SEL_ORDEN_TRABAJO_PICKING` trae lo pendiente, planificado menos consumido— o se arma un retiro libre. El mapa reparte cada repuesto entre sus cajas **en el orden de su método de salida** y arma la ruta en «S» (un pasillo hacia el fondo, el siguiente hacia la entrada). El recorrido en primera persona va caja por caja: la caja se asoma, la tablet dice cuánto, de qué posición y por qué lote, y «Retirar» registra una **SALIDA POR CONSUMO (tipo 2)** contra la OT con `WsBodegaMapa.RetirarPicking`. **No hay tabla de picking**: lo pendiente se recalcula desde `Orden_Trabajo_Repuesto`, que suma el propio `INS_INVENTARIO_MOVIMIENTO`. Si la compatibilidad con el equipo de la OT pide motivo (regla 8 del SP), la tablet lo pide y reintenta. Si una caja no alcanza, no se retira nada: no queda un retiro a medias en silencio. **Método de salida:** `bod_metodo_salida` (FEFO por defecto) y una excepción opcional `rep_metodo_salida`, con `FNC_METODO_SALIDA`. **El método se aplica en `SEL_INVENTARIO_ORIGEN`**, que ahora ordena los orígenes según él, así que `Movimiento.aspx` (combo «Sale de»), el picking y los faltantes del conteo cíclico salen en el mismo orden, y el visor ya no ordena por su cuenta. La «fecha de ingreso» de un saldo es la del lote o, sin lote, la del último ingreso a esa caja (`FNC_SALDO_FECHA_INGRESO`). Se configura en la ficha de bodega y en la del repuesto del mapa. **Ojo:** `230_HORA_SANTIAGO.sql` también define `SEL_INVENTARIO_ORIGEN`; si se vuelve a correr, hay que correr `328` después. **Probado en local:** la ruta A → B → C con cruce de pasillos, el resumen y el cambio FIFO ↔ FEFO con rechazo de un método inválido (la bodega quedó en FEFO). **Sin probar contra la base:** «Retirar», porque registra una salida real del stock del cliente. Hamburgo no tiene OT todavía, así que el picking por OT tampoco se probó con datos |
| 03-10-2026 | **Traslado en `Movimiento.aspx` y el mapa 3D completo (`BD/329`).** **Corrección:** `Movimiento.aspx` no mandaba la ubicación de destino en el traslado (tipo 6) y el SP la exige si la bodega de destino tiene ubicaciones (regla 17); nace el combo «Ubicación en destino», obligatorio en ese caso (commit `39b24f2`). **`BD/329` y el visor:** (1) **posiciones reales** — `Bodega_Ubicacion_Posicion` es el planograma de cada rack (nivel-posición por repuesto, «Fijar posiciones» y «Cambiar de posición»); el stock **sigue por ubicación**, la posición no entra al kardex a propósito (obligaría a que web, app y carga masiva la indiquen); (2) **medidas y peso** por repuesto y **carga admisible por nivel** del rack, con aviso de sobrecarga; (3) **análisis**: rotación ABC por frecuencia de retiro (90 días, `SEL_BODEGA_MAPA_ROTACION`) con sugerencias para acercar la clase A a la entrada y moverla con un clic (`ReubicarCaja`, tipo 9 por lote), quiebre proyectado, «por vencer» (30/60/90) y «¿qué tengo para esta máquina?» (`SEL_BODEGA_MAPA_COMPATIBLES`, misma regla que el SP de movimientos); (4) **solicitud de reposición** (`Solicitud_Reposicion` + detalle, correlativo por cliente, PENDIENTE → ENVIADA → RECIBIDA o ANULADA, imprimible); (5) **plano editable**: mover un rack en el piso con detección de choques y giro (`Bodega_Plano_Rack`; sin fila, el rack se ubica por su código) y zonas del piso (`Bodega_Zona`: recepción, cuarentena, despacho, muelle, paso peatonal); (6) **historial**: el stock al cierre de cualquier día de los últimos 90 (`SEL_BODEGA_MAPA_SALDOS_FECHA`: saldo de hoy menos lo movido después) y la reproducción de los movimientos del día sobre la escena; (7) **trabajo en equipo**: cada 15 s `SEL_BODEGA_MAPA_VERSION` y, si otro usuario movió algo, el mapa se refresca solo (o, con un formulario abierto, ofrece «Actualizar»); (8) **escanear**: lector USB, cámara (BarcodeDetector) o texto → vuela al rack, la caja o la bodega; `?ir=UBI-17` en la URL, y `Escanear.aspx` ofrece «Ver en el mapa 3D». Las acciones secundarias de la barra pasan a un menú «Más» para que las pestañas de bodega no se corten. **Probado en local (solo lectura):** los cinco modos de análisis, el formulario de reposición (66 candidatos en Piso 1), el de posición, el historial (ayer 0 cajas, hoy 600) y su reproducción, el escaneo (rack encontrado y código inexistente rechazado), `?ir=UBI-6`, mover un rack con choque detectado y cancelado. **Sin probar contra la base** (escriben): fijar posiciones, mover un rack, guardar zonas, crear y cambiar solicitudes, reubicar por ABC, guardar medidas y carga. Rotación y quiebre se ven vacíos hasta que haya salidas por consumo; compatibles, hasta que haya equipos con compatibilidades |
| 03-10-2026 | **Mapa 3D: caja que se abre, maqueta y navegación (commits `850d3ba`, `27341fe`).** Clic en una caja: sale al pasillo, abre la tapa (o las cuatro solapas del cartón) y muestra adentro una pieza procedural según el tipo (rodamiento, piñón, correa, motor, válvula…) o, si el repuesto tiene foto, una tarjeta con la foto mirando a la cámara; el encuadre usa el FOV para que la tarjeta no se corte. **Con más de 3 bodegas o más de 1.500 saldos** las que no se miran se dibujan como **maqueta** (un `InstancedMesh` por bodega) y solo la elegida tiene detalle; el selector de bodegas pasa a un **combo** con flechas, y **← →** cambian de bodega; con una caja seleccionada, **← → ↑ ↓** recorren las vecinas (mismo nivel, salta al rack contiguo; ↑↓ cambian de nivel). **Sin parpadeo** al mover la cámara: `logarithmicDepthBuffer`, `polygonOffset` en calcomanías del piso y presupuesto de etiquetas por vuelta |
| 03-10-2026 | **Centro del repuesto alineado con la bodega (`BD/330`).** `SEL_REPUESTO_ALMACENAMIENTO` (una fila por caja: método que rige, ingreso, vencimiento, posición del planograma y último conteo), `SEL_REPUESTO_CONSUMO` (90 días), `SEL_REPUESTO_CONTEOS` y `SEL_REPUESTO_REPOSICIONES`, leídos por `RepuestoAlmacenamientoController`. En `RepuestoCentro.aspx`: «Ver en el mapa 3D» (`?ir=REP-id`), 5.º KPI de consumo con «se agota en ~N días», método de salida, medidas y peso en el resumen, método por bodega en existencias, pestaña **Posiciones** por caja con enlace al rack en el mapa, y pestaña nueva **Reposición y conteos** (solicitar reposición en línea, con permiso GESTIONAR STOCK; solicitudes y conteos del repuesto). En `Repuesto.aspx`: sección **Almacenamiento** (método de salida — «según la bodega» por defecto — y largo/ancho/alto/peso), guardada por los mismos SP del mapa después de guardar el repuesto. **Defecto previo corregido:** el Centro usaba la clase `es-prim`, que no existe (es `es-primario`): Editar, Nuevo, Solicitar y los demás primarios se veían como texto plano |
| 03-10-2026 | **Etiquetas en QR o código de barras (`BD/331`) y QR que quedaban a medio dibujar en el mapa.** **Corrección:** el mapa pide los QR de los repuestos en lote al acercarse; si un lote fallaba (servidor ocupado, sitio reiniciándose), las etiquetas en pantalla se quedaban con el impostor —tres esquinas y un cuadro gris— hasta alejarse, porque nada volvía a pedir. Ahora el lote se reintenta con espera creciente y cada vuelta del nivel de detalle redibuja o vuelve a pedir las que siguen pendientes (probado forzando 3 fallos: las 28 etiquetas vivas terminaron con su QR). **Simbología:** `Cliente.cli_etiqueta_simbolo` (`QR` por defecto, o `BARRAS`). La hoja de impresión ofrece «Código: QR / Código de barras · Code 128»; lo elegido queda como predeterminado de la empresa. El mapa dibuja las etiquetas (cajas, vigas, puntal) con ese código, se puede mirar con el otro desde «Más», y lo que se imprime desde el mapa sale como se está viendo. Code 128 juego B **sin biblioteca** (`App_Code/MVC/SitioBase/Code128.cs`, SVG vectorial; la misma tabla en `sigma-bodega3d.js`), validado contra `python-barcode`: los 107 patrones y la etiqueta impresa de `REP-1201` coinciden módulo a módulo. El contenido es el mismo token, así que las etiquetas QR ya pegadas siguen sirviendo; los escáneres de la intranet y del mapa leen `code_128` además de `qr_code`. **Pendiente:** el lector de la app móvil (S6) también debe aceptar Code 128 |
| 03-10-2026 | **Ficha de bodega alineada con el mapa 3D (`BD/332`).** El menú Inventario › Bodegas creaba ubicaciones `UBI-<id>`, que el mapa no sabe ubicar (las ponía todas en un pasillo «UBI»). Ahora los racks se crean **por pasillo** con la convención que lee el mapa —`<prefijo>-<pasillo>-R<nn>`, el prefijo sale de los racks existentes o del código de la bodega, igual que `sugerirRack`/`prefijoBodega` del JS— de 1 a 30 por vez, con vista previa de los códigos antes de crear (`BodegaAlmacenamientoController.CrearRacks`; si uno falla, dice cuántos alcanzó a crear). La lista de racks va **agrupada por pasillo** (los que no calzan, al final como «Fuera de la convención») con lo que guarda cada uno, la **carga por nivel** editable en la fila (`UPD_UBICACION_CARGA`), si se movió en el plano, el **último conteo** y un acceso al rack en el mapa (`?ir=UBI-id`). En Datos: **método de salida** FEFO/FIFO/LIFO (`UPD_BODEGA_METODO_SALIDA`), resumen del mapa y «Abrir en el mapa 3D». El listado suma las columnas Salida y Contados 30 d, el acceso al mapa por fila y «Ver mapa 3D». Lecturas nuevas: `SEL_BODEGA_RESUMEN_MAPA`, `SEL_BODEGA_UBICACIONES_MAPA`. **Probado en local (solo lectura):** listado, ficha, agrupación (3 pasillos × 5 racks en Piso 1), vista previa de códigos (sigue B → P1-B-R06; abre D → P1-D-R01) y edición en fila abierta y cancelada. **Sin probar contra la base:** crear racks, guardar carga y método desde la ficha |
| 03-10-2026 | **Fabricantes y modelos estandarizados (`BD/333`).** Eran texto libre («Fleetguard», «fleetguard», «FLEETGUARD » serían tres). Catálogo por cliente `Fabricante` (único sin mayúsculas ni acentos, `CI_AI`) y `Fabricante_Modelo` colgando de su fabricante, sembrado con lo existente (61 fabricantes, 600 modelos; respaldo previo en `_scratch/respaldo_repuesto_fabricante_20261003.txt`). **`TRG_REPUESTO_FABRICANTE`** en `Repuesto` (AFTER INSERT/UPDATE): limpia espacios, busca en el catálogo y guarda la forma canónica; si no existe, la agrega. Va en la base y no en la pantalla porque los repuestos entran por la web, el mapa, la carga masiva y la API: una regla para todas las puertas; las columnas siguen siendo texto, así que etiquetas, búsqueda, API y reportes no cambian. Probado en transacción con rollback: «  fleetGUARD » → «Fleetguard», «lf3000 » → «LF3000», un fabricante nuevo se registra con espacios limpios. **Pantallas:** `Js/sigma-fabricante.js` (compartido por `Repuesto.aspx` y el formulario del mapa) sugiere mientras se escribe, corrige a la forma del catálogo al salir del campo, avisa «fabricante/modelo nuevo: se agrega al guardar», y el modelo ofrece solo los de ese fabricante (cascada; si se cambia de fabricante, el modelo que no le pertenece se limpia). **Controla lote** ahora explica qué implica en ambas fichas: cada ingreso pide código de lote (o uno existente) y vencimiento, las salidas descuentan por lote (FEFO por vencimiento) y el stock previo queda «sin lote»; la regla 7 de `INS_INVENTARIO_MOVIMIENTO` ya exigía el lote al ingresar. **Pendiente:** el modelo de activos (`Activo_Modelo.amo_fabricante`) podría usar el mismo catálogo |
| 03-10-2026 | **Centro de carga de datos (`BD/334`, `BD/335`) — Utilidades › Carga de datos.** Un solo lugar para dejar cada módulo listo desde planillas. **Acceso:** permiso `GESTIONAR CARGAS MASIVAS` (perfiles Root y Administrador del Cliente) con `prm_asignable_usuario = 1`: el administrador lo delega a un usuario sin darle su perfil. **Motor:** la aplicación lee el .xlsx (EPPlus; hojas y encabezados se reconocen sin mayúsculas, acentos ni «_», con sinónimos; números y fechas de Excel a un formato único) y lo sube completo con `SqlBulkCopy` a `Carga_Masiva_Fila` (una fila = un JSON); `PRC_CARGA_<MODULO>` valida con consultas de conjunto y después escribe fila por fila **llamando a los SP de las fichas** dentro de la base (sin viajes por fila); corre en segundo plano (`HostingEnvironment.QueueBackgroundWorkItem`) y la pantalla consulta `Carga_Masiva` cada segundo. Modos **Revisar** (dice qué pasará con cada fila sin escribir) y **Cargar** (o «Cargar ahora» lo revisado, sin volver a subir: `INS_CARGA_MASIVA_DESDE`); existentes **Actualizar** (celdas vacías conservan) u **Omitir**; una fila mala no detiene la carga (`Carga_Masiva_Error`, descargable en Excel); una carga a la vez por empresa; lo que quedó colgado por un reinicio se marca fallido. **«Alertar un problema»** guarda `Carga_Masiva_Incidencia` con el contexto (fase, avance, tiempo, navegador). **Inventario de punta a punta:** BODEGAS → RACKS (convención del mapa, autonumerados) → REPUESTOS (las 15 columnas de la carga de siempre + método y medidas) → UMBRALES → STOCK INICIAL (ingreso tipo 1 con lote y vencimiento; se rechaza si ya hay stock en ese rack: no duplica). Cada hoja puede nombrar lo que crea una anterior del mismo archivo. **Plantilla** generada por módulo: LEAME, encabezados morados (obligatorios) / celestes, comentarios, listas desplegables y hojas de ayuda con los valores de la empresa. **Pantalla** sin postback con escena Three.js (núcleo y un nodo por módulo; los datos fluyen hacia el módulo al ritmo del avance), asistente de 3 pasos, recuadro flotante con tiempo transcurrido, resultado por hoja e historial. **Probado:** revisión por la interfaz (13 filas en 2 s, errores esperados en cada hoja, referencias a bodega y racks nuevos del mismo archivo, «4.200,50» como número) y la carga real dentro de una transacción con rollback (bodega `BOD-n`, racks `BOD-n-A-R01`, fabricante normalizado, lote con vencimiento; nada quedó). **Pendiente:** módulos Activos y Mantenimiento (tareas, checklists, planes y programación) — la pantalla los muestra «en preparación»; la carga real (modo Cargar desde la pantalla) no se ejecutó contra Hamburgo |
| 03-10-2026 | **El mapa 3D pasa a llamarse SIGMA Twin (`BD/336`).** Menú, cabecera y marca de la barra: «SIGMA Twin · gemelo digital de bodegas». El enlace y el permiso no cambian |
| 04-10-2026 | **Bugs 13–18 del Centro de repuestos (`BD/337`).** (13) Carga masiva: capa «Cargando planilla…» al pulsar Cargar (sin doble clic). (14) No se reprodujo: los 601 repuestos tienen tipo y `SEL_REPUESTO_TIPO` los cuenta. (15) Adjuntar no subía nada: la ficha llega por postback asíncrono y el `<form>` quedaba sin `multipart` → `Page.Form.Enctype` + `RegisterPostBackControl(lnkSubir)`; las imágenes apuntaban a `~/Archivo.aspx`, que no existe → `SitioBase.UrlArchivo.Ver/Descargar`. Evidencia gana visor ampliado (recorre la galería), eliminar y «usar como portada» en fotos, ver/descargar/eliminar en documentos. (16) **Pestaña Ficha** reemplaza a Resumen: lectura en grupos (identificación, fabricante y costo, cómo se opera, vida útil, almacenamiento) y **Editar** (único, en el encabezado) la vuelve formulario en el lugar, sin modal, guardando con los mismos métodos de `Repuesto.aspx` (baja por `DEL_REPUESTO`, `UPD_REPUESTO`, método y medidas por sus SP); umbrales siguen en Existencias; las pestañas bajan de línea en vez de dar scroll horizontal. (17) El permiso `REGISTRAR MOVIMIENTOS DE INVENTARIO` que pedía el botón no existía: creado y dado a Root y Bodeguero; desde el centro, `Movimiento.aspx` ya no pide el repuesto (paso 2 oculto, `RepuestoFijo`; `AplicarContexto` nunca se llamaba). (18) `SEL_REPUESTO` no tenía `@REPUESTO_TIPO`: el filtro de tipo no filtraba (Rodamientos → 21). **Probado con Selenium:** 15, 17, 18 y el visor. **Sin probar por Selenium:** guardar la ficha en línea (el login de prueba empezó a rechazar; validado por Bryan en pantalla) y la capa de carga del 13. **Trampa:** las cuentas de `usuarios_prueba.json` (ximena, root) dejaron de entrar durante la sesión |
| 04-10-2026 | **Perfiles definidos por cada cliente (`BD/341`, bug 8).** Menú nuevo **Cliente › Usuarios › Perfiles** (antes de Usuarios; permiso `GESTIONAR PERFILES CLIENTE`, dado a Root y Administrador del Cliente). El Administrador crea los cargos de su empresa (nombre, descripción, dónde trabaja web/app/ambos, «solo ejecuta») y marca sus permisos por área con interruptores; buscador, contador, «Todo el área», «Empezar con los permisos de…» (propios o «Modelo SIGMA») y Duplicar. Reglas en los SP (`UPS_PERFIL_CLIENTE`, `UPS_PERFIL_CLIENTE_PERMISO`, `SEL_PERFIL_CLIENTE`, `SEL_PERFIL_CLIENTE_PERMISO`): el perfil debe ser del cliente de la sesión; solo entran permisos con `prm_asignable_cliente = 1` (94: lo operativo y lo que ya tenía el Administrador; nunca comercial, sistema ni «ver todo»); «Crear y editar X» agrega «Ver X»; un perfil «solo ejecuta» no puede cerrar OT; no se desactiva con usuarios; los del sistema no se editan. El motor (`SEL_USUARIO_PERMISOS`) no cambió: ya calculaba por `Cliente_Usuario_Perfil`. **Migración A1:** cada empresa recibió copia propia **solo de los perfiles fijos que sus usuarios usaban** (Hamburgo: Bodeguero, Jefe, Planificador, Técnico; CCU ninguno — corregido tras copiar a todos, decisión de Bryan: cada cliente arma sus cargos); permisos idénticos verificados; los fijos quedan deshabilitados como «Modelo SIGMA»; el Administrador del Cliente sigue siendo del sistema. Combos de perfil en Usuarios, Nuevo usuario y Asociar usuario pasan `@CLIENTE` (`Perfil.cliente`). Respaldo previo: `_scratch/respaldo_perfiles_20261004.txt`. **Probado:** reglas de los SP en transacción con rollback y la pantalla con Selenium (listado, validación del nombre, dependencia Ver/Editar, bloqueo de cerrar OT, guardado y resaltado). **Trampa:** `usuarios_prueba.json` está desactualizado — ximena y marcela ya no existen en la base. **Pendiente:** algunas descripciones de `Permiso` son notas técnicas («Separado de VER ACTIVOS a propósito…») y se leen en la pantalla |
| 04-10-2026 | **Ciclo de vida del activo simplificado (`BD/342`, `BD/343`).** Revisión del cliente: «lo lento son los menús y tras menús». (1) Se ocultan los 5 menús de Configuración de activos (tipos, modelos, atributos, variables, posiciones; `mnu_visible = 0`). (2) La ficha crea todo al vuelo: tipo, modelo (filtrado por tipo **y** fabricante) y fabricante con texto libre (`UPS_ACTIVO_CATALOGO`; el fabricante usa el catálogo compartido con repuestos vía `TRG_ACTIVO_FABRICANTE` y `FNC_NOMBRE_PROPIO`), componentes en la misma ficha con «qué es» libre (`UPS_COMPONENTE_TIPO_NOMBRE`, tipo propio del cliente). Atributos técnicos y variables: opción A (se definen en la ficha y en Condición, sin menú). **Posiciones fuera del flujo** por decisión de Bryan. (3) La ficha es un **asistente de 3 pasos** (qué es y dónde está + foto · datos técnicos y documentos · componentes), igual en el modal de alta y en la pestaña; Guardar siempre disponible, un obligatorio vacío vuelve al paso 1. (4) Pestañas: Resumen · Ficha · Componentes · Condición y medidores · Historial · Órdenes; el resto en «Más». (5) **Componentes** abre con el diagrama «¿De qué está hecho este equipo?» (`SEL_ACTIVO_ESTRUCTURA`, una llamada): equipo, subactivos (azul), componentes (turquesa) y repuestos compatibles con stock (ámbar), y el asistente «¿Qué vas a agregar?» (subactivo con `Padre=` → `ActivoForm.PadreFijo`; componente; repuesto con `Activo=` → `RepuestoCompatibilidad.ActivoFijo`). (6) Listado como árbol con chips y área completa («Refrigeración › Línea 1», `SEL_ACTIVO_ARBOL_LISTA`). Corregidos: tipo vacío en combos con texto libre (falta `Text`), componentes de todos los activos en la ficha (`filtro_activo`), «Nuevo activo» visible sin permiso, chip de estado montado sobre la criticidad. Datos de ejemplo cargados (horno, amasadora, cámara con 2 compresores, bomba; respaldo `_scratch/respaldo_activos_20261004.txt`). **Trampa:** un `id` de botón igual al nombre de una función rompe el `onclick` (el formulario expone el elemento con ese nombre): `fpSiguiente is not a function`. **Medido:** abrir el 360 tarda ~11 s en local (8 pestañas, ~60 consultas × 170 ms a la base remota); carga por demanda queda pendiente |
| 04-10-2026 | **Usuarios por cliente vuelve (`BD/344`, revierte `BD/326`).** Al traer `master` a la rama de Catalina chocaron dos decisiones: ella había borrado `~/View/Clientes/Cliente/Usuarios.aspx` y ocultado su menú (`BD/326`), y Bryan la mantuvo usando el cliente de la barra superior (b993620) y armó en `BD/341` el flujo **Cliente › Usuarios: primero Perfiles, luego Usuarios**. Se conserva la de Bryan y `BD/344` deja de nuevo `mnu_visible = 1` (menú 41). `BD/341` ya estaba aplicado en la base compartida (permiso 134, menú 2243 y los 4 SP de `PERFIL_CLIENTE`), así que no se volvió a correr. **Trampa:** la página 404 de Perfiles no era un error de la página, sino que el commit de Bryan no estaba en la rama activa que sirve IIS |
| 04-10-2026 | **Rediseño del módulo de Activos: creación y centro 360 (`BD/344`).** Implementa las maquetas «SIGMA · Rediseño módulo de Activos» (Claude Design). (1) **Asistente de creación/edición** (`ActivoForm.ascx`, el mismo en el modal y en la pestaña Ficha): **4 pasos** con riel lateral (Información básica · Ubicación · Datos técnicos · Partes) y una ayuda corta por paso; Marca y N° de serie pasan al paso 1 (el modelo depende de tipo y marca); «¿Está en uso?» (antes Habilitado) al paso 3; «¿Depende de otra máquina?» como Sí/No que muestra el combo. **Una sola barra al pie**: Anterior · Paso n de 4 · Cancelar · Siguiente · Guardar; al crear, Siguiente es el morado hasta el paso 4 y Guardar es turquesa (en edición, Guardar siempre morado). **Validación amable**: los obligatorios usan `afRequerido`/`afRequeridoLibre` (rótulo y borde rojo + frase de qué hacer) y una banda junta lo que falta con un botón que lleva al campo y al paso; Siguiente valida solo el paso actual. Al crear: Estado «Operativo» por defecto y la planta preseleccionada si hay una sola. **Confirmación final**: alta exitosa en el modal redirige a `Activo.aspx?query=Id=..&Creado=1` y muestra «Listo, el equipo quedó creado» con Agregar sus partes / Registrar sus repuestos / Abrir su centro 360° / Crear otro / Listo. Foto y documentos aceptan arrastrar y soltar; partes con sugerencias (tipos comunes de SIGMA). En el centro, ancho controlado (1120 px) y «Sobre esta ficha» (auditoría + cuánto cuelga del equipo) en el riel. (2) **Centro**: cabecera con foto, chips, código · tipo · ubicación completa (`RutaUbicacion`) y «Es parte de: X» si es subactivo; «Editar ficha» (contorno) + «Nueva OT» (primario). **Componentes = un diagrama y su detalle al lado**: se eliminó la segunda vista repetida (árbol + tabla + detalle + historial de reemplazos, que ya está en Repuestos y costos); cada elemento lleva su detalle en `data-det` (JSON) y `esVer` lo pinta; partes retiradas a pedido; stock en palabras (Hay N en bodega / Quedan pocos / Sin stock); regla y leyenda siempre visibles. «¿Qué vas a agregar?» con tarjetas seleccionables y «Continuar con «…»». Menú «Más» con título y sombra que lo separa del contenido. Condición: una sola acción morada (Registrar lectura, oculta si no hay nada que medir) y «Agregar qué medir» como menú. (3) **`BD/344`**: `SEL_ACTIVO_ESTRUCTURA` agrega `PARA_ID/PARA` a repuestos y un 5º resultado con las partes de los subactivos (compatible hacia atrás). Aplicado `EXIT 0`; compila `exitcode=0`. **Falta la prueba en navegador** (la sesión de prueba no se pudo iniciar desde el agente). **Trampa:** `sigma-activo360.js` limpiaba «cambios sin guardar» con cualquier botón del pie; ahora solo con los `input[type=submit]` de `.af-pie` (Anterior/Siguiente no guardan) |
| 04-10-2026 | **Activos, segunda vuelta tras la revisión de Bryan (`BD/345`).** (1) **Asistente de 6 pasos** (Información básica · Ubicación · Datos técnicos · Componentes · Variables · Medidores): «Partes» pasa a llamarse **Componentes**; «Qué es» y «Dónde va» son combos con texto libre (`afCombo`, opciones en `AF_OPC`) que **crean lo que no existe** (`UPS_COMPONENTE_TIPO_NOMBRE` y el nuevo `UPS_COMPONENTE_POSICION_NOMBRE`); **foto por componente** (`co_foto` → `ActivoComponenteImagenController.VincularImagen`) y **foto por dato de placa** (`fuDato`/`nd_foto` → queda en Documentos del activo con el nombre del dato, p. ej. «Potencia.jpg»); pasos nuevos de **variables de condición** (qué se mide + unidad + rango normal; la variable se crea por nombre con el nuevo `UPS_VARIABLE_MEDICION_NOMBRE`) y **medidores** (nombre + unidad + lectura de hoy); la marca y el modelo dicen que se crean si no están. **Bug corregido:** «¿Depende de otra máquina? Sí» no mostraba el combo: el radio se llamaba `afDepende` igual que la función (misma trampa del `id`/función ya anotada). **Bug corregido:** los combos y las sugerencias salían vacíos porque los tipos/lugares comunes de SIGMA traen `cto_cliente`/`cpn_cliente` nulo y la comparación con 0 los descartaba (`Convert.ToInt32`). (2) **Centro**: «¿Qué vas a agregar?» ya no abre otra ventana: el **componente se crea ahí mismo** con el diseño nuevo (`lnkEsGuardarComp_Click`, con foto, «es parte de», estado y fecha) y el subactivo/repuesto se cargan **dentro de la misma ventana** (iframe con `radWindow` compatible, así `closeWindow()` refresca el centro); el botón Continuar quedaba blanco sobre blanco porque el asistente vive fuera de `.sg-a3`. Diagrama a todo el ancho con el detalle en un **panel que se abre al tocar**; cada **subactivo es un recuadro con sus propios componentes**; la palabra es **Activo** (no «equipo»). (3) **Listado** alineado a la maqueta A1: «Activos de la planta», «Importar o exportar» como menú, **«Crear»** (componente, variable, medidor, tipo, modelo, ver tipos) y la vista **Activos | Componentes** (todos los componentes agrupados por su activo o subactivo) **en vez del menú lateral**. (4) **Menús (`BD/345`)**: «Tipos de activo» y su nodo «Configuración de activos» vuelven a verse; «Componentes» queda **oculto** en el menú lateral (vive dentro del Centro). Aplicado `EXIT 0`, compila `exitcode=0`, probado en navegador (asistente, combos, validación, subactivo embebido, «Sí, depende») |
| 04-10-2026 | **Ficha del componente con la piel del asistente.** `ActivoComponente.aspx` (crear y editar, desde el centro y desde «Crear › Componente») pasa a **3 pasos** (Qué es · Estado · Placa y foto) con el mismo riel, barra al pie y validación amable del activo. «Es parte del activo» lista activos **y subactivos** («Compresor Copeland · … (subactivo de Cámara de frío 1)»); «Qué es» y «Dónde va» con texto libre que **crea** lo que no existe (`ResolverPorNombre`); marca desde el catálogo compartido; al crear: estado Operativo, fecha de hoy y la criticidad de su activo; al editar, «¿Por qué cambia el estado?» aparece **solo si cambia** el estado, y el historial y «Sobre esta ficha» quedan a la vista. **Refactor:** la piel y el JS del asistente salieron de `ActivoForm.ascx` a **`Css/LookAndFeel/sigma-asistente.css`** y **`Js/sigma-asistente.js`** (pasos, validación, combo con texto libre, foto por fila, soltar archivos); cada página fija `var AF_PASOS` antes de cargarlo. **Trampa:** en el centro los carga la página en su cabecera y no el control, porque la ficha puede llegar en un postback parcial y ahí un `<script src>` no se ejecuta. Compila `exitcode=0`; probado en navegador (alta, validación, edición, motivo de estado, asistente del activo en modal y en la pestaña Ficha) |
| 05-10-2026 | **Activos: vistas de la planta, catálogos en línea, centro 360 alineado al mockup, SIGMA AI, compatibilidades y bitácora en hilo (`BD/346`–`BD/356`).** Única referencia: `docs/rediseno-activos/sigma-activos-referencia.html`. (1) **Planta** (`ActivoFicha.aspx` sin activo): encabezado, KPIs, pestañas del módulo y «Ver como» Lista · Tarjetas · Mapa por áreas · Vista 3D · Explorador, portados de la referencia a `Js/sigma-planta.js` (se arma con `_scratch`/scratchpad `portjs.py` sobre `planta_cab.js`+referencia+`planta_pie.js`) y `Css/LookAndFeel/sigma-activos.css` (`portcss.py`, todo bajo `.sgap`; la fuente es **Sora**). Datos por `WsActivos.asmx` (patrón ASMX) y `ActivoPlantaController`; los cambios se guardan por diferencia (SYNC). Esqueleto de tarjetas al cargar; entra siempre en Tarjetas; combo de planta (solo las asignadas a la persona; sin asignación, todas); permiso **CREAR EDITAR AREAS** para lugares; GSAP Flip/Draggable y three.js r160 bajo demanda. (2) **Catálogos en línea** (Variables, Medidores, Tipos, Modelos): crear/editar/borrar en la fila, lecturas debajo de la variable, bajas lógicas con «No se usan» y «Volver a usar»; **combo con búsqueda** que ofrece «Crear «…»» solo si no existe (sin distinguir mayúsculas). (3) **Fotos**: varias por activo con portada (`avi_es_foto`/`avi_es_referencia`), reducidas con `ArchivoController.Alivianar` → `ReducirImagen` (1600 px, JPEG 80, respeta EXIF) en todas las subidas del módulo; `BD/353` separa las fotos de componentes de las del activo (el 348 las había mezclado) y repara los datos. (4) **Centro 360** con ámbito `.sg-a3--v3`: Volver + miga, cabecera con portada 120 px, barra de pestañas fija que **mueve a la barra las secciones de «Más» que caben**, SIGMA AI con su logo horizontal; «Etiqueta» (QR/código de barras, `EtiquetaOrigen.Activo`); «equipo» → «activo» en todo el módulo; «Datos de placa» → «Datos técnicos». (5) **SIGMA AI**: panel oscuro con señal (línea de monitor si no hay lecturas), pronóstico, fuentes, factores y cola predictiva; íconos de estado en línea y animados. (6) **Compatibilidades** (`BD/351`): `rco_activo` (activo o subactivo), «Agregar repuesto compatible» en el explorador y en el asistente del centro (nativo, con foto y stock). (7) **Bitácora en hilo** (`BD/352`, `bit_padre`); `BD/355` alinea `API_INS_BITACORA` con la regla de plantas; la web mandaba `@ENTRADA_MODO=0` (no existe) → 1. (8) Observación del componente = motivo del último cambio de estado o su descripción (`BD/356`). (9) Menú: un módulo con una sola pantalla es enlace directo; «Nueva OT» fuera de la barra superior; campos `TextBox2` de solo lectura con forma de campo en todo SIGMA. **Trampas:** el `-webkit-display` de la referencia descentraba el explorador; `PopCalendar` no se carga y su script cortaba los postbacks asíncronos (objeto mudo en las maestras); un postback asíncrono no sube archivos (`RegisterPostBackControl` + `multipart`). Aplicados 346–356 `EXIT 0`; compila `exitcode=0`; probado en navegador. |
| 05-10-2026 | **Pendientes de Bryan: un solo combo y aperturas más rápidas.** Nace `Js/sigma-combo.js` + `Css/LookAndFeel/sigma-combo.css` (`SigmaCombo`): el combo con búsqueda de la planta pasa a ser el único del sitio (busca mientras se escribe, «Crear» solo si no existe sin distinguir mayúsculas ni tildes, foto y línea secundaria). `sa-combo` (planta) y `af-combo` (asistente) quedan como envoltorios; el asistente usa el modo libre (el input lleva el `name`, el servidor no cambia). Rendimiento: `SitioBase.Paralelo` (consultas en paralelo con el HttpContext), `WsActivos.Planta` pide sus 13 consultas a la vez, los prefijos de `CodigoModulo` pasan al caché del sitio (10 min) y la ficha de componente lee los permisos mientras viaja la primera tanda. Probado en el navegador: `Planta` de ~3,4 s a ~1,1 s en caliente, la ficha de componente ~0,4 s; combo en planta, asistente, repuesto compatible y «Nuevo componente» del centro. «+ Nuevo componente» desde la planta llena «Qué es» y «Dónde va» con lo que ya usan sus componentes (`sigmaPlanta.datos()`), y en el centro 360 `sigma-planta.js` ya no lanza errores en cada clic y tecla por buscar `#gal`/`#navpop`, que ahí no existen. «Se instaló el» del nuevo componente usa el calendario de SIGMA (`.sigma-modal-fecha`, dd-mm-aaaa) en vez del `input type="date"` del navegador |
| 06-10-2026 | **Activos: todo el asistente con el combo SIGMA, componente colgado de cualquier parte, orden por fecha y badge «Nuevo» (`BD/357`).** (1) **Asistente del activo** (`ActivoForm.ascx`, modal y pestaña Ficha): ya no usa combos de Telerik. Tipo, modelo y marca son `SigmaCombo` en modo libre (el modelo se filtra en el navegador por tipo y marca, sin postback; elegir un modelo pone su marca); estado, criticidad, planta, área, centro de costo, máquina padre y año son `SigmaCombo` con id (`asp:TextBox` + `asp:HiddenField`; las listas salen de `Lista/Fijar/Elegido` y se validan al guardar). Se eliminaron `LoadControls` y `SeleccionarCombo`. (2) **Confirmación de alta**: check en círculo verde, opciones en cajas, todo centrado y la ventana ajustada al contenido. (3) **«Agregar subactivo»** en el panel Subactivos del explorador de la planta (`qSub`). (4) **Planta**: orden «Más nuevos primero» / «Más antiguos primero» (`BD/357` agrega `CREADO` a `SEL_ACTIVO_PLANTA`) y badge dorado **«Nuevo»** bajo el estado de la tarjeta las primeras 24 h (lo decide `WsActivos` con `SitioBase.Hora.Ahora`). (5) **Componente**: «Es parte del activo» + «Va dentro de otra parte» pasan a ser un solo **«¿De qué es parte?»** (`a:<id>` / `c:<id>`): el activo, sus subactivos o un componente de cualquiera de ellos; igual en `ActivoComponente.aspx` y en el formulario del centro 360 / pestaña Componentes de la planta. `sigma-combo.js`: no abre la lista en un campo de solo lectura y dibuja el cuadro de foto solo si la lista trae `img`. Baja lógica de ACT-13 «prueba1» (Hamburgo) a pedido. Aplicado `BD/357` `EXIT 0`; compila `exitcode=0`. **Sin probar en navegador** salvo el alta de un activo (ACT-11 «Laminador», hecho por Catalina): la sesión de prueba no estuvo disponible |
| 06-10-2026 | **Arrastrar un componente a un subactivo en el explorador (`BD/358`).** El panel Subactivos del explorador de la planta es un árbol (cada subactivo con sus componentes debajo). Un componente se arrastra desde «Componentes» a un subactivo, o desde el árbol de un subactivo a «Componentes» para volverlo al activo abierto; sin mouse, «Mover a» en su detalle. `UPD_ACTIVO_COMPONENTE_MOVER` (el UPD nunca cambia `aco_activo`): mueve la pieza con lo que cuelga de ella, la deja directo en el destino y valida código único y un tipo por posición. **Decisión:** lo que describe a la pieza la sigue (variables, medidores, fotos, repuestos compatibles, planes asignados); lo histórico (OT, fallas, bitácora, mediciones, alertas, hallazgos, predicciones, ocurrencias) queda en el activo donde ocurrió. `WsActivos.MoverComponente` con permiso `CREAR EDITAR COMPONENTES`. Aplicado `EXIT 0`, probado en transacción con rollback; compila `exitcode=0`. **Sin probar el arrastre en navegador** |

### Cómo actualizar este documento

Al cerrar un bloque de trabajo: agregar la fila en la bitácora, mover lo
hecho de §7 a §4 o §5, y anotar en §6 **toda decisión que un tercero no
podría deducir del código**. Esa sección es la que evita rehacer discusiones
ya cerradas.
| 06-10-2026 | **Módulo Soporte (etapas a–l).** Referencia única: `docs/rediseno-soporte/sigma-soporte-referencia.html`. **BD 359–364** (aplicados en dev): `Soporte_Ticket`/`_Evento` (inmutable por trigger `INSTEAD OF`)/`_Encuesta`/`_Recurrente`/`_Evitado`/`_Lectura`, catálogos de estado, prioridad (SLA en horas), categoría y área; `Ayuda_Pantalla` (sincronizada desde Menus), `Ayuda_Contenido` + pasos, recomendaciones, vínculo Módulo › Submódulo › Pantalla › Sección, versión (foto JSON; restaurar publica una versión nueva), vista, valoración y búsqueda; `Campana` + condición, segmento y entrega. Audiencia en `FNC_CAMPANA_AUDIENCIA` (estado/perfil/cliente/planta/usuario, es/no es, Y/O). Permisos: `SOPORTE REPORTAR` y `AYUDA VER` a todos los perfiles; `SOPORTE GESTIONAR`, `AYUDA ADMINISTRAR`, `CAMPANAS ADMINISTRAR` y `SOPORTE ANALITICA` solo a Root y al perfil Soporte (de plataforma, se pueden dar a otro perfil desde Sistema › Perfiles). Menú **Soporte** con 13 pantallas en `View/Soporte/` (base `SitioBase.SoportePagina`). Avisos por la **campana existente**: 9 tipos `SOPORTE *`/`AYUDA NUEVA`/`CAMPANA`, columnas `ale_soporte_ticket`, `ale_ayuda_contenido`, `ale_campana`; BD 363 hace que `SEL_ALERTA`, `SEL_ALERTA_RESUMEN` y `UPD_ALERTA_LEER` sigan al destinatario en cualquier cliente (y corrige que el resumen contaba avisos dirigidos a otros). Web: `WsSoporte`/`WsAyuda`/`WsCampanas` + `SoporteController` (filas del SP tal cual, la autorización la decide el SP), `Js/sigma-soporte.js` y `Css/LookAndFeel/sigma-soporte.css` (portado bajo `.sgs` por `_scratch/port_soporte_css.py`; lo propio va en `_scratch/soporte_css_extra.css`). El master muestra «Reportar problema» y «? Ayuda», y entrega campañas (banner, modal, card y la campana). `VerArchivo` deja abrir adjuntos de soporte y ayuda publicada de otro cliente (`SEL_SOPORTE_ARCHIVO_PERMITIDO`). **Pendiente:** aplicar 359–364 en la base de producción antes de mezclar a PRODUCCION. Probado el ciclo completo en una transacción revertida; las 11 pantallas cargan sin errores. |
