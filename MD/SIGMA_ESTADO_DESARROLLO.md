# SIGMA — Estado del desarrollo

> **Documento vivo.** Es el traspaso de contexto entre sesiones de trabajo.
> Quien retome el proyecto debería poder leer solo esto y saber dónde está
> todo, qué se decidió y por qué, y qué falta.
>
> **Regla: cada vez que se cierre un bloque de trabajo, se actualiza este
> archivo en el mismo cambio.** Un documento de estado desactualizado es
> peor que ninguno, porque se le cree.

**Última actualización:** 31-08-2026 (Sprint 2 · HU-035 Registrar un activo)
**Sprint vigente:** Sprint 1 — Fundaciones (02-09-2026 al 15-09-2026) ·
**Sprint 2 iniciado:** HU-035 (Activo) — capa de datos ejecutada y probada
contra la base; web construida y compilando (falta prueba en navegador)

---

## Programación del mantenimiento — bloques 103 a 107 (01-09-2026)

Las siete historias de programación del Sprint 3 (HU-070 a HU-076) tenían el
modelo hecho —diez tablas, catálogos poblados— y **cero procedimientos**. Ahora
tienen 23 SPs, una función, dos pantallas, el menú y los permisos.

### Lo que quedó construido

| Bloque | Qué |
|---|---|
| **101** | Se desplegó (estaba escrito y sin aplicar): `SEL/INS/UPD/DEL_PROCEDIMIENTO` + `SEL_VARIABLE_MEDICION`. Cierra la capa de datos de HU-061 y HU-062. |
| **103** | CRUD de la cabecera `Programacion`. |
| **104** | Detalle por tipo: fechas, calendario, intervalo, medidor. |
| **105** | Exclusiones, condiciones, `SEL_ACTIVO_VARIABLE` mínimo, menú y permisos. |
| **106** | `FNC_PROGRAMACION_FECHAS` + `SEL_PROGRAMACION_PROYECCION`. |
| **107** | `SEL_PROGRAMACION_CATALOGO`: los ocho combos de la ficha en un SP. |

Web: `View/Mantenimiento/Programaciones/Programaciones.aspx` y
`Programacion.aspx`, más `Model/Programacion.cs` y `ProgramacionController.cs`.
Compila con EXITCODE=0.

API: `AlertasController` (HU-077, T-3956) con `GET /alertas`,
`GET /alertas/resumen` y `POST /alertas/{id}/leer`. La API compila y genera
`bin\API.dll`.

### Una ficha y no cinco

El backlog proponía CRUD y pantalla propia por tipo —`ProgramacionCalendario`,
`ProgramacionMedidor`…—. El modelo dice otra cosa: `Programacion` es una
cabecera y `pro_programacion_tipo` elige cuál de las cinco tablas de detalle
aplica. Cinco pantallas serían las mismas cuatro secciones comunes copiadas
—vigencia, tolerancias, zona horaria, política— y se desincronizarían.
Quedó **un** CRUD y **una** ficha cuyo combo de tipo intercambia un panel.

### Dos columnas que faltaban en el modelo

- **`Programacion_Intervalo.pin_desde_ejecucion`** — los dos criterios de
  HU-072 piden cosas opuestas: contar desde la última ejecución (#1) o desde
  la fecha programada (#2, "un atraso no desplaza las siguientes"). No había
  ninguna columna que dijera cuál. Sin ella HU-072 solo puede cumplir uno de
  sus dos criterios.
- **`Programacion_Exclusion.pxc_desplaza`** — HU-075 #2 quiere que el feriado
  **corra** la fecha al siguiente día hábil guardando la original; #3 quiere
  que la parada de planta **elimine** las fechas del período. Son efectos
  distintos sobre la misma tabla.

Las dos son aditivas y con default.

### La proyección, que es lo que salva el sprint

Los 21 criterios de las siete historias dicen "entonces **se genera la
ocurrencia**". Y una ocurrencia no se puede insertar:
`Plan_Mantenimiento_Ocurrencia.pmo_plan_mantenimiento_hito` es NOT NULL contra
`Plan_Mantenimiento_Hito`, que es **HU-081 del Sprint 4** y tiene cero filas.

`FNC_PROGRAMACION_FECHAS(@PROGRAMACION, @DESDE, @HASTA)` separa las dos
mitades: **cuándo toca** se calcula y se prueba hoy; **qué se crea** es HU-076
y espera al Sprint 4. Es el 80% del algoritmo de HU-076 escrito y verificado
ahora, y el generador la va a llamar tal cual.

Comprobado contra los criterios, con datos reales en la base:

| Criterio | Resultado |
|---|---|
| HU-071 #1 semanal martes y jueves | 1, 6, 8, 13, 15, 20, 22, 27, 29 de enero 2026 |
| HU-071 #2 último día del mes | 31-01, **28-02** (2026) y **29-02** (2028) |
| HU-071 #3 último viernes | 30-01, 27-02, 27-03, 24-04 |
| HU-072 #1 cada 90 días desde el 10-01 | 10-01, 10-04, 09-07, 07-10 |
| HU-070 #1 cuatro fechas puntuales | las cuatro, independientes |
| HU-075 #3 parada de planta | desaparecen 6, 8, 13 y 15 de enero |
| HU-075 #2 feriado el viernes 30-01 | pasa a **lunes 02-02**, `FECHA_ORIGINAL = 30-01`, motivo "Feriado" |
| Aislamiento entre clientes | el cliente 2 recibe "LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE" |

### Dos errores que aparecieron al probar

1. **`SELECT @ID = col FROM …` no pone NULL cuando no hay filas**: deja la
   variable como estaba. Como `@ID` es OUTPUT, entraba con el valor de la
   llamada anterior y los tres `UPS_` actualizaban la fila de **otra**
   programación. Se corrigió con `SET @ID = NULL` antes del SELECT.
2. **El desplazamiento saltaba todos los fines de semana**, incluso sin
   exclusiones: una programación diaria habría perdido cada sábado en
   silencio. Ahora el fin de semana solo se salta cuando la fecha **ya venía
   desplazada** por una exclusión.

### Lo que sigue bloqueado, y por qué

| Historia | Pts | Bloqueo |
|---|--:|---|
| **HU-074** condición | 5 | `Activo_Variable` tiene 0 filas y ningún mantenedor: es **HU-041, del Sprint 2**, todavía "Por hacer". El CRUD de condiciones está hecho; el combo va vacío hasta que se cierre. |
| **HU-076** generación | 8 | Necesita `Plan_Mantenimiento_Hito` (HU-081, Sprint 4). |
| **HU-151** sincronización | 13 | Cero tablas `Sincronizacion%`. Las tareas T-3005 y T-3006 de API dependen de eso. |

### Decisiones que quedan para el equipo

1. **`Programacion_Medidor.pme_activo_medidor` es NOT NULL**, así que la regla
   "cada 500 horas" está obligada a nombrar UN horómetro. HU-073 #3 pide un
   plan sobre cuatro blowers disparando con el horómetro de cada uno sin
   crear cuatro programaciones, y eso sale de
   `Plan_Mantenimiento_Activo.pac_activo_medidor`. Debería ser nullable.
2. **No existe tabla de feriados.** HU-075 #2 habla de "excluyo los feriados"
   como calendario nacional, y SIGMA es multipaís. Hoy se cargan a mano como
   exclusiones con desplazamiento.
3. **`Zona_Horaria` solo tiene Chile** (continental e Isla de Pascua). Un
   cliente peruano no tiene zona que elegir.

### Cuatro historias están hechas y marcadas "Por hacer"

HU-051 (3 pts), HU-060 (5), HU-063 (3) y HU-064 (3) tienen sus SPs
desplegados, sus pantallas en disco y sus filas en `Menus`, y sus tareas ya
están en "Terminada". Lo que quedó viejo es el estado de la **historia**: son
14 puntos que hoy cuentan como deuda y no lo son.


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

## 2. Lo primero que hay que leer antes de escribir código

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
| Stored procedures | 223 (incluye Activo, Activo_Medidor y Activo_Tipo) |
| Funciones | 27 |
| Permisos | 70 (incluye Activos, Medidores y Tipos de activo) |
| Perfiles | 9 |
| Páginas registradas en `Menus` | 72 (las 2 de Activo, 2 de Medidores y 2 de Tipos) |
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

### Los permisos se preguntan de UNA sola forma — CERRADO (bloque 102)

Había **dos implementaciones** de *"¿este usuario tiene este permiso?"* y se
contradecían **en los dos sentidos**. Medido contra la base antes de tocar
nada:

| Caso | `SEL_USUARIO_PERMISOS` | `FNC_USUARIO_TIENE_PERMISO` |
|---|--:|--:|
| Marcela (Admin. del Cliente **solo en Hamburgo**) preguntando por un cliente **ajeno** | **34 permisos** | 0 |
| Una cuenta de plataforma que no sea Root (Soporte, Gerente Comercial) | 32 permisos | **0** |

La primera fila es un agujero de aislamiento entre clientes. La segunda es lo
que dejaba el árbol de la app vacío para Soporte.

**La causa es la misma:** el SP miraba `Usuario_Perfil` sin preguntarse de qué
tipo era el perfil, y la función no lo miraba nunca.

#### La regla que se adoptó

> Un perfil en `Usuario_Perfil` otorga permisos **solo si es de plataforma**
> (`per_tipo = 1`). Los de tipo Cliente que están ahí son el **espejo** del
> bloque 49 —una copia para las pantallas heredadas— y una copia no otorga
> nada: dentro de un cliente los permisos salen de `Cliente_Usuario_Perfil`
> de **ese** cliente.

Una sola frase, aplicada igual en las dos implementaciones, apoyada en un
dato que ya existe en vez de en una lista que alguien tenga que mantener. Los
datos la respaldan: hoy las tres cuentas de plataforma tienen perfil tipo 1 y
cero afiliaciones, los siete usuarios de Hamburgo tienen tipo 2 y una, y **no
hay ni un cruce**.

#### Por qué no fue ninguna de las dos opciones que este documento proponía

Ninguna arreglaba el segundo caso: la función seguía dejando sin permisos a
Soporte y a Gerente Comercial. Había que tocar las dos puntas, no elegir una.

Y **vaciar el espejo tampoco era viable**: `SEL_CLIENTE_USUARIO_ELEGIBLE`
decide quién ve todos los clientes mirando `Usuario_Perfil`, y
`SEL_CLIENTE_USUARIO` exige una fila ahí para listar a alguien. Vaciarlo
rompe las dos.

#### La tercera diferencia, que no estaba registrada

La función exigía autorización vigente en la planta
(`Cliente_Instalacion_Usuario`) y el SP no la miraba. Estaba **latente**
—todos los llamadores pasan `@INSTALACION` en NULL— pero se activaba sola el
día que la app pasara la planta. Se agregó al SP con la misma semántica.

Con una excepción en ambas: **la autorización de planta alcanza a lo que
viene del cliente, no a un permiso de plataforma.** Quien da soporte no está
asignado a ninguna planta y nunca va a estarlo.

#### Comprobado después del cambio

| Caso | SP | Función |
|---|--:|--:|
| Marcela en **su** cliente | 34 | sí |
| Marcela en un cliente **ajeno** | **0** | **no** |
| Soporte (plataforma) | 32 | **sí** |
| Root | 79 (todos) | sí |
| Técnico en su cliente / con su planta | 15 | sí |
| Técnico en una planta **ajena** | **0** | **no** |

Y el árbol de la app: Root 58 nodos · Marcela 42 · Técnico 32 ·
**Soporte 46, que antes daba 0**.


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

### Los archivos viven en Blob Storage — CONECTADO (01-09-2026)

Decisión de Bryan (29-08): **todo archivo se almacena en Blob Storage**, y
quien habla con Azure **no es este sitio** sino la API .NET, que además
atiende a la app móvil. Que la web y la app subieran por caminos distintos
garantizaría que algún día un archivo quede en un contenedor que la otra no
mira.

**Esa API ya existe.** Cuenta `sigmacodigocreativo`, contenedor `sigma`.

#### Las dos piezas

| Dónde | Qué |
|---|---|
| `API/Services/BlobService.cs` | Habla con Azure. Subir, leer, ver, actualizar, propiedades, borrar. |
| `API/Controllers/ArchivoController.cs` | `POST /archivo` · `GET /archivo` · `GET /archivo/ver` · `GET /archivo/propiedades` · `PUT /archivo` · `DELETE /archivo` · `GET /archivo/estado` |
| `Web/Intranet/App_Code/SitioBase/Services.cs` | **La única puerta de la web hacia la API.** Toda llamada pasa por acá. |
| `Almacenamiento.cs` | Sigue implementando `IAlmacenamiento`, pero ahora **delega** en `Services`. Su `WebClient` propio se eliminó: dos clientes HTTP para el mismo servicio son dos sitios donde arreglar lo mismo. |

#### REST y no el SDK de Azure

`Azure.Storage.Blobs` obligaría a meter el paquete y sus dependencias en un
proyecto .NET 4.8 que hoy no tiene ninguna, y lo que aporta —reintentos,
streaming en bloques, paralelismo— es para escenarios que este módulo no
tiene: se suben permisos y comprobantes, de pocos MB, de a uno. **Con un SAS
la API REST no necesita firmar nada**: el token *es* la credencial. Son tres
verbos HTTP.

#### La estructura de carpetas

```
sigma / 0001-hamburgo / permisos-trabajo / 2026 / 09 / a1b2c3….pdf
└cont┘ └── cliente ──┘ └──── módulo ────┘ └─ cuándo ─┘ └─ nombre ─┘
```

- **Id y nombre juntos.** Solo el id no dice de quién es nada al abrir el
  portal de Azure; solo el nombre no sirve porque cambia y puede repetirse.
  El id va delante y relleno a cuatro dígitos para que **ordene**: `0002`
  antes que `0010`, cosa que `2` y `10` no hacen alfabéticamente.
- **El cliente arriba del módulo**, porque el aislamiento entre empresas es
  lo que no se puede equivocar: un SAS acotado a un prefijo deja fuera a las
  demás de una sola regla.
- **Año y mes** para que ninguna carpeta llegue a ser imposible de listar.
- El nombre del archivo es un **GUID**: dos personas suben `permiso.pdf` el
  mismo día. El original se conserva en `arc_nombre_original`.

#### Ver un archivo tiene una lista blanca, y es una defensa real

`GET /archivo/ver` devuelve el mime real con `inline` para que el navegador
muestre el PDF sin descargarlo. **Solo para PDF, imágenes de mapa de bits y
texto plano.**

Servir `text/html` o `image/svg+xml` con `inline` desde nuestro dominio es
ejecutar HTML y javascript **ajeno con nuestro origen**: quien suba un `.html`
con un script puede leer lo que el navegador guarde para este sitio. Es XSS
almacenado y el vector es exactamente "poder ver el archivo". Todo lo que no
está en la lista sale como descarga, más `X-Content-Type-Options: nosniff`
para que el navegador tampoco adivine.

#### Actualizar conserva la ruta

`PUT /archivo` reemplaza el contenido **sin cambiar la ruta**, porque
`Archivo.arc_ruta` apunta ahí: una ruta nueva obligaría a actualizar también
la fila, y entre una cosa y otra hay una ventana en la que la base apunta a
un blob que ya no está. El costo es que se pierde la versión anterior; si
hace falta conservarla, lo que corresponde es **activar el versionado del
contenedor en Azure**, no inventar rutas.

Y comprueba que la ruta exista antes: en Blob Storage un PUT sobre una ruta
inexistente la **crea**, así que sin esa comprobación "actualizar" una ruta
mal escrita dejaría un huérfano y quien lo pidió creería que actualizó el
suyo.

#### ⚠ El SAS que está configurado es más amplio de lo necesario

El token del portal es de **cuenta completa**: `sp=rwdlacupiytfx` (leer,
escribir, borrar, listar, y más) sobre `ss=bfqt` (blob, cola, tabla,
archivos) con `srt=sco` (servicio, contenedor y objeto). Permite borrar
**cualquier cosa de la cuenta**, no solo lo de este módulo.

Para lo que la API hace basta un SAS **acotado al contenedor `sigma`** con
`sp=rcwd` y `srt=co`. `BlobService.AsegurarContenedor` ya trata el 403 como
"ya existe" justamente para poder funcionar con un SAS así.

**Vence el 2027-03-01.** Ese día las subidas empiezan a fallar con 403 y el
mensaje de Azure no dice que el token expiró.

> **La clave `ServiciosApiKey` tiene que ser la misma en los dos
> `Web.config`.** Si difieren, la API responde 401 y `Services.Traducir` lo
> convierte en un mensaje que dice cuál revisar, en vez de un
> "(401) No autorizado" que no indica nada.

#### Un documento siempre se puede ver Y descargar — `wuc:Adjunto`

Regla del 01-09-2026: **todo adjunto tiene que poder abrirse y bajarse.**
Está escrito una vez, no en cada ficha:

| Archivo | Qué hace |
|---|---|
| `View/Comun/Controls/Adjunto.ascx` | El control. Resuelve los **cuatro** estados: lo tiene (nombre, peso, *Ver*, *Descargar*) · no lo tiene y se puede subir · no se puede subir y dice por qué · no hay y es solo lectura. |
| `View/Comun/Archivos/VerArchivo.aspx` | Entrega el binario, `inline` o `attachment` según el modo. |

```aspx
<wuc:Adjunto runat="server" ID="wucAdjunto" Modulo="permisos-trabajo" Categoria="13" />
```
```csharp
wucAdjunto.Mostrar(entidad.ptr_archivo);   // al cargar
int archivo = wucAdjunto.Guardar();        // al guardar; 0 si no eligió nada
```

**Lo que viaja es el id cifrado, nunca la ruta.** Si el navegador conociera
`sigma/0001-hamburgo/…/x.pdf` podría pedir otra cambiando el texto. Llega un
id, se resuelve contra la base —que dice de qué cliente es— y recién entonces
se pide el archivo. Y se comprueba el cliente **otra vez** acá: adivinar un id
correlativo es barato. Un archivo ajeno responde **404 y no 403**, porque
decir "existe pero no es tuyo" confirma que ese id existe.

**Ver y Descargar son `<a>`, no `LinkButton`.** Un `LinkButton` con
`target="_blank"` pierde el postback y no abre nada; y un postback que escribe
un binario rompe el `UpdatePanel`, que espera un fragmento y recibe un PDF.

> **Pendiente:** `Pago.aspx` todavía tiene su propio bloque de adjunto, escrito
> antes que el control. Funciona, pero solo ofrece descargar. Migrarlo a
> `wuc:Adjunto` le agrega *Ver* y deja una sola implementación.

#### Verificado contra Azure real (01-09-2026)

Ciclo completo con la ruta definitiva: crear contenedor, subir, propiedades
por `HEAD`, ver, actualizar, 404 en ruta inexistente, borrar. Los seis pasos
correctos.

**No verificado:** los endpoints de la API por HTTP —solo se probó el REST de
Azure directamente— ni ninguna pantalla en el navegador.
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

### Proveedores: módulo Terceros, y sin código automático (bloque 91)

HU-060, primera historia construida de **EP-07**. Tres decisiones que un
tercero no podría deducir del código:

**Vive en un módulo nuevo, `Terceros`, no en Inventario.** La tabla existe
desde las fundaciones y `Repuesto_Lote` apunta a ella, así que colgarla junto
a Repuestos y Bodegas era lo cómodo. Pero la historia es de EP-07 —*"Terceros,
procedimientos y permisos de trabajo"*— y habla de **contratistas**: tres de
las cuatro tablas que dependen de `Proveedor` son de órdenes de trabajo.
Ponerla en Inventario obligaría a mudarla en cuanto llegue HU-063, y un menú
que cambia de sitio es un menú que la gente deja de encontrar. Ahí van a
colgar después los permisos de trabajo (HU-063, HU-064) y el historial del
proveedor (HU-065).

**No lleva código automático, y es correcto.** El bloque 77 le puso
`XXX-<id>` a los módulos con columna de código. `Proveedor` no la tiene y
**no se le agrega**: una empresa ya tiene un identificador único y universal,
que es su RUT, y `UX_PRV_CLIENTE_RUT` ya garantiza que no esté dos veces
dentro de un cliente. Un `PRV-12` al lado sería un segundo nombre para lo
mismo, y quien busque por uno no encontraría el otro. *La tarea T-3143 pedía
"confirmar el índice único del código": no aplica a esta tabla.*

**El RUT se valida con `FNC_IDENTIFICADOR_VALIDO(@PAIS, @RUT)`,** el mismo
despachador por país del bloque 39, y la etiqueta del campo sale de
`SEL_PAIS_IDENTIFICADOR`. Escribir una comprobación de módulo 11 acá sería
correcta en un país de los cinco y rechazaría documentos buenos en los otros
cuatro.

> **Nombre de la pantalla.** Las tareas dicen `Proveedors.aspx` —plural
> generado por plantilla—. Se creó **`Proveedores.aspx`**, que es el plural
> real y la convención del resto del sitio (`Repuestos`, `Bodegas`).

**Eliminar deshabilita, no borra.** Un proveedor con lotes recibidos o
servicios contratados aparece en el historial de compra y en el gasto del
año, que es justo lo que HU-065 va a leer. `DEL_PROVEEDOR` rechaza y dice
**cuántos** registros dependen de él; el listado muestra esa cuenta en su
propia columna para que se sepa antes de apretar el botón.

### Compatibilidad de repuestos: una fila, un alcance (bloques 92 y 93)

HU-051. Cuatro decisiones, y la primera es que **el texto de las tareas
apuntaba a la tabla equivocada**.

**T-3159 decía `Componente_Repuesto_Instalacion`. No es esa.** Esa tabla es
el *historial* —qué pieza se montó dónde, con qué horómetro, por qué se
retiró— y es lo que necesita **HU-058**. Lo que pide HU-051 —*"indicar en qué
equipos o modelos aplica cada repuesto"*— es **`Repuesto_Compatibilidad`**,
que existe desde el bloque 12 y estaba sin usar. La tarea también pedía
"confirmar el índice único del código": esta tabla no tiene columna de código
y no la necesita — no es algo que alguien nombre, es una afirmación.

**Una fila declara un solo alcance.** `CK_RCO_ALCANCE` exige al menos uno de
tipo/modelo/componente pero no impide los tres. Una fila con `tipo=BOMBA` y
`modelo=NB 65-200` a la vez no se puede leer: ¿las bombas *más* ese modelo, o
las bombas *que sean* ese modelo? Los SP exigen **exactamente uno**; si aplica
a varios, son varias filas — y así se puede quitar una sin tocar la otra.

**El borrado es físico, contra lo que pedía T-3163.** No hay
`rco_habilitado` y no se agregó. Una compatibilidad es una afirmación de
hecho: si está mal, está mal, no hay historia que preservar y **ninguna tabla
la referencia**. Guardar una compatibilidad equivocada "deshabilitada" es
dejar puesto justo el dato que la historia quiere evitar, esperando a que
alguien la vuelva a encender.

**El aislamiento va por el repuesto.** La tabla **no tiene `rco_cliente`**:
la pertenencia sale de `rco_repuesto → Repuesto.rep_cliente`, y por eso todos
los SP hacen ese JOIN. El alcance también se valida — un tipo o modelo de
otro cliente se rechaza; los de `cliente NULL` son globales y sí se aceptan.

> **Lo que sí se agregó al modelo:** `rco_usuario_actualizacion` y
> `rco_fecha_actualizacion` (T-3162 pide un `UPD_`, y un `UPD_` sin "quién lo
> cambió" en un sistema cuya premisa es la trazabilidad no se sostiene), más
> `UX_RCO_ALCANCE` —nada impedía declarar dos veces lo mismo— y
> `IX_RCO_INVERSO` para la consulta al revés, que es como la usa el técnico.

**Bloque 93 — los combos que no existían.** `Activo_Modelo` y
`Activo_Componente` están desde las fundaciones y **nunca se habían leído
desde la aplicación**: no tenían ningún `SEL_`. Se crearon
`SEL_ACTIVO_MODELO` y `SEL_ACTIVO_COMPONENTE`, solo de consulta — el
mantenedor de esas entidades es del módulo de activos.

> **Componentes: cero filas.** El alcance por componente está soportado de
> punta a punta pero no se puede ejercitar todavía; la ficha lo dice en el
> combo en vez de quedarse en blanco. Poblar `Activo_Componente` es del
> módulo de activos. Los 3 `Activo_Modelo` de demo **sí** se crearon: sin
> ellos el alcance por modelo —que la historia nombra explícitamente— no
> tenía cómo probarse.

### Permisos de trabajo: la tabla exige el documento (bloque 94)

HU-063. **El hallazgo importante está en el esquema, no en el código:**

```sql
CK_PTR_AUTORIZADO: ptr_permiso_trabajo_estado <> 2 OR ptr_archivo IS NOT NULL
```

**Un permiso no puede quedar AUTORIZADO sin su documento adjunto.** Es
exactamente lo que pide la historia —*"dejar constancia de que el trabajo se
ejecutó con la autorización correspondiente"*—: la constancia **es** el papel
firmado, no la fila.

Y adjuntar está bloqueado: `Almacenamiento.Disponible` devuelve falso
mientras `AlmacenamientoApiUrl` conserve `PENDIENTE`. Las dos cosas juntas
significan que **hoy ningún permiso puede llegar a AUTORIZADO**. No es un
defecto: es el modelo haciendo su trabajo contra una infraestructura que
todavía no existe.

Lo que sí funciona: registrar el permiso como **Solicitado** con su tipo,
folio, vigencia, solicitante, orden y observación. Que es útil por sí solo.

**Lo que se hizo para que esto no sorprenda a nadie:**

- `INS_` y `UPD_` comprueban la regla **antes** que el CHECK y devuelven
  *"UN PERMISO AUTORIZADO NECESITA EL DOCUMENTO FIRMADO ADJUNTO"*. Dejar que
  saltara el constraint devuelve `The INSERT statement conflicted with the
  CHECK constraint CK_PTR_AUTORIZADO`, que no le dice nada a quien está
  llenando el formulario.
- El listado y la ficha **preguntan por `Almacenamiento.Disponible`** y
  muestran el motivo. El hueco del adjunto está conectado de punta a punta
  —`ptr_archivo`, el `SEL_` devuelve nombre y peso, `SubirDocumento()` está
  escrita— así que el día que la API exista basta cambiar el `Web.config`.
- Los datos de prueba quedan **todos en Solicitado**, porque AUTORIZADO es
  literalmente imposible de insertar hoy.

**La situación se calcula, no se guarda.** El catálogo tiene un estado
VENCIDO, pero un estado guardado envejece solo: un permiso que venció anoche
seguiría diciendo AUTORIZADO hasta que alguien corriera un proceso. El `SEL_`
devuelve `SITUACION` contra la fecha de hoy —VIGENTE, POR VENCER (7 días o
menos), VENCIDO, CERRADO— que es lo que **HU-064** va a consumir sin poder
quedar desactualizado.

**El folio no lleva código automático.** `ptr_numero` guarda el número que
trae el formulario de prevención. Meter un `PTR-12` ahí lo haría
indistinguible del folio oficial, que es el dato por el que alguien busca.
Es el mismo criterio que el RUT del proveedor (bloque 91).

#### La API del módulo (bloque 96 · `PermisosTrabajoController`)

`GET /permisos-trabajo` · `GET /permisos-trabajo/{id}` ·
`POST /permisos-trabajo` · `PUT /permisos-trabajo/{id}` ·
`GET /permisos-trabajo/tipos` · `GET /permisos-trabajo/estados`

**El alta es idempotente por `uuid`, y hubo que agregar la columna.**
`Permiso_Trabajo` **no tenía `ptr_uuid`**, así que la idempotencia que pedía
T-3222 no era implementable: la única forma de distinguir un reintento de dos
permisos legítimamente iguales es que el cliente traiga un identificador que
él generó.

Importa más acá que en otros módulos: el permiso se registra **en terreno**,
con la red de una planta. La app manda, se corta, no sabe si llegó. Sin
idempotencia quedan dos permisos para la misma faena y el prevencionista no
sabe cuál firmó — y si el reintento fallara por una regla, la app mostraría un
error por algo que **sí** se guardó.

- El cortocircuito va **antes de toda validación**, como en
  `INS_INVENTARIO_MOVIMIENTO`: un reintento no tiene por qué volver a pasar
  reglas que ya pasó.
- `SET @ID = NULL` explícito antes del `SELECT`: un `SELECT` sin filas **no
  toca la variable**, y el llamador manda 0. Sin eso, *todo* permiso con uuid
  respondería "ya estaba registrado" sin guardar nada. Es el error que ya se
  cometió una vez.
- `UX_PTR_UUID` es **único y filtrado**. Único porque es lo que de verdad
  cierra la ventana entre el `SELECT` y el `INSERT` de dos peticiones
  simultáneas; filtrado porque las filas existentes tienen uuid `NULL` y en un
  índice único de SQL Server los `NULL` se comparan **iguales entre sí**.

Verificado: dos llamadas con el mismo uuid → mismo id, **una sola fila**.

> **Pendiente de HU-063:** `T-3227` (Móvil, de Bryan) y las dos de Catalina
> (pruebas y documentación). **Nada de la API se ha ejercitado por HTTP**:
> compila y los SP están probados, pero ningún endpoint se ha llamado.

### Permisos vigentes: la regla vive en una función (bloques 97 y 98)

HU-064. La situación —VIGENTE, POR VENCER, VENCIDO— **se calcula, no se
guarda**: un estado guardado envejece solo, y un permiso que venció anoche
seguiría diciendo AUTORIZADO hasta que alguien corriera un proceso.

**`FNC_PERMISO_SITUACION` la define una sola vez.** El bloque 94 la había
escrito dentro de `SEL_PERMISO_TRABAJO`, en un `CASE` repetido dos veces —una
para devolverla, otra para poder filtrar por ella—. Al llegar
`SEL_PERMISO_TRABAJO_VIGENTE` habrían quedado **cuatro copias**, y el día que
alguien cambie el umbral tres se van a actualizar: la pantalla de alertas
diría una cosa y la ficha otra, y las dos parecerían correctas.

> En SQL Server 2019+ las funciones escalares se incorporan al plan
> (*inlining*), así que no cuesta la llamada fila por fila que costaría en una
> versión vieja.

**El estado manda sobre el calendario.** Un permiso RECHAZADO o CERRADO no
está vigente aunque su fecha no haya pasado. Uno sin fecha de fin no está
vencido ni vigente: está **SIN VIGENCIA**, que es un dato incompleto y no una
situación. Los dos quedan fuera de la pantalla de alerta, y por eso los datos
de prueba incluyen uno de cada uno — sin ellos no se puede comprobar que **no**
aparecen, que es la mitad del criterio de aceptación.

**No hay paginación en el SP, a propósito.** T-3310 la pide, pero el proyecto
pagina en C# con `Paginado<T>.Armar` y todos los listados de la API funcionan
así. Un SP que pagine por su cuenta obligaría a mantener dos mecanismos.

**La pantalla abre con tres números y son botones.** Alguien entra con una
pregunta —"¿tengo algo vencido?"— y la respuesta cabe en un número; contar
filas para saberlo es hacerle el trabajo al revés. El color va en el borde y
el icono, **no en el número**: un "0" en rojo grande se lee como un problema,
y cero vencidos es la buena noticia.

### Limpieza: seis SP que no existían y el módulo de material de apoyo

**827 líneas de código muerto eliminadas** (01-09-2026). Seis controladores
heredados llamaban a procedimientos que **no existen en la base**:
`SEL_FUNCION_MENU`, `SEL_MENU_MATERIAL_APOYO`,
`SEL_MENU_MATERIAL_APOYO_ESTADISTICAS`, `SEL_NACIONALIDAD`, `SEL_SQLITE`,
`SEL_USUARIO_GELOCALIZACION`.

No daban error: los controladores atrapan la excepción y devuelven lista
vacía, así que cualquiera que los llamara vería "no hay datos" en vez de "esto
no está implementado".

| Qué | Acción |
|---|---|
| `MenuMaterialApoyo{,Estadistica}Controller` + sus modelos | Borrados. No se usará material de apoyo. |
| `NacionalidadController` + `Nacionalidad` | Borrados. Nadie los llamaba. |
| `SqLiteController` + `SqLite` | Borrados. Nadie los llamaba. |
| `AccesoController.GetMenuFuncion` | Borrado. El modelo `MenuFuncionPerfil` **se queda**: lo usa `Accesos.aspx.cs`. |
| `ClienteUsuarioController.GetUsuariosGeolocalizacion` | Borrado. Nadie lo llamaba. |
| `Default.master.cs` | Tenía `private MenuMaterialApoyoController menuCapsulaController = new …` **declarado y nunca usado**: un `new` en cada carga de página que no hacía nada. |

La base **no tenía nada** de material de apoyo: ni tablas, ni SP, ni menús, ni
permisos. Era solo C#.

### El logo y la foto se fueron a Blob (bloque 100)

Eran `varbinary(max)` dentro de SQL Server —`Cliente.cli_logo`,
`Usuario.usu_foto`— y se servían como `data:image/jpeg;base64,…` **incrustado
en el HTML**. Es decir: la imagen entera viajaba en **cada** carga de página
—el avatar está en la cabecera de todas— y ningún navegador podía cachearla,
porque no era un recurso sino texto dentro del documento.

Ahora son un id de `Archivo` y la imagen se pide por URL a
`VerArchivo.aspx`, que el navegador sí cachea.

**No hubo nada que migrar**: cero clientes con logo, cero usuarios con foto,
cero filas en `Cliente_Binario`. Se comprobó antes de escribir el bloque.

**Dos SP chicos en vez de tocar nueve.** Poner un logo no es "editar el
cliente": es una operación con un solo dato. `UPD_CLIENTE_LOGO` y
`UPD_USUARIO_FOTO` hacen una cosa cada uno, y los nueve grandes —entre ellos
los del camino de autenticación— quedaron intactos.

Las columnas viejas **no se borraron**: están vacías y ya nadie las escribe,
pero dropear es irreversible y `SEL_CLIENTE_USUARIO` todavía las nombra con
su `@DEVUELVE_FOTO`. Quedan muertas y anotadas.

#### ⚠ Rompí el SP del login, y así se evita

Agregar la columna a los tres `SEL_` exigía tocar el texto de procedimientos
que arman su SELECT dinámicamente. Dos intentos fallaron y **el segundo hizo
daño**:

1. **`CREATE` → `ALTER` con `STUFF`** sobre la primera aparición de `CREATE`.
   La cabecera de `SEL_USUARIO` trae el comentario estándar de SSMS
   `-- Create date: …`, así que `CHARINDEX` cayó **dentro del comentario** y
   destrozó el encabezado. El error fue *"Incorrect syntax near 'date:'"*, que
   no menciona por ningún lado el problema real.

2. **`DROP` y después `CREATE`.** El `CREATE` de `SEL_CLIENTE_USUARIO` falló
   —*"Invalid column name 'usu_archivo_foto'"*— porque ese SP arma un CTE
   llamado `BASE` y la columna hay que agregarla en **dos** sitios: dentro del
   CTE y en el SELECT final. Como el `DROP` ya se había ejecutado,
   **`SEL_CLIENTE_USUARIO` quedó borrado — y es el procedimiento del login.**
   Hubo que restaurarlo del bloque 49.

> **La regla:** no se borra un objeto antes de saber que el reemplazo
> compila. `scratchpad/parchar_sel.ps1` crea primero una copia con nombre
> temporal; solo si ésa compila toca el procedimiento real, y si el original
> dice `CREATE OR ALTER` ni siquiera necesita borrarlo.

> **Y otra:** `` `u{001F} `` **no es un escape en PowerShell 5.1** — queda como
> texto literal. Un `-split` con eso nunca separa. Se usa `[char]0x1F`. El
> guard del script lo detectó y abortó sin tocar nada, que es como tenía que
> comportarse.

#### Verificado

Las tres `SEL_` devuelven la columna nueva —`SEL_USUARIO` sólo con
`@DEVUELVE_FOTO = 1`, que es como la llama el login— las dos columnas y los
dos SP existen, y el sitio compila.

**No verificado en navegador:** subir un logo, subir una foto, y que el avatar
de la cabecera aparezca por URL.

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

### Deuda conocida

- **Existencia atrapada en Bodega Central** (bloque 87 lo detectó, bloque 90
  abrió la salida — 01-09-2026). Dos filas de `Inventario_Saldo` quedaron con
  `isa_bodega_ubicacion = NULL` en una bodega que **sí** tiene ubicaciones.
  Como la ubicación es obligatoria ahí (error 15), esas unidades **no se
  podían sacar por ningún camino** — y la reubicación (tipo 9), que es
  literalmente la operación "esto va a otro estante", tampoco servía: exigía
  ubicación de **origen**, y el origen de lo atrapado es ninguna.

  | Repuesto | Cantidad | Estado |
  |---|---|---|
  | `DEMO-ROD-6205` | 1,00 | **Resuelto.** Movimiento 63, reubicado a `PA-E1-N1` |
  | `DEMO-FUS-NH1-100` | 4,00 | **Pendiente:** falta decidir el estante |

  El rodamiento se pudo resolver porque el historial no dejaba duda: entró
  por compra a `PA-E1-N1`, ahí siguen otras 2, y la unidad devuelta volvió
  sin estante. Se corrigió **con un movimiento de reubicación**, no con un
  `UPDATE`: la existencia es la consecuencia del libro, y una corrección sin
  rastro es indistinguible de un error.

  El fusible no tiene esa respuesta. Llegó por traslado desde el Pañol de
  Sala Eléctrica y ninguna de las seis ubicaciones de Bodega Central es la
  suya de forma evidente. Lo decide el bodeguero.

  > **La causa se repite.** El traslado entre bodegas genera la entrada del
  > otro lado **sin ubicación de destino** —así llegó el fusible—, así que
  > esto vuelve a pasar cada vez que alguien traslada mercadería. El bloque
  > 90 abre la salida; **cerrar la entrada sigue pendiente** y toca la
  > pantalla: el formulario de traslado no tiene dónde pedir la ubicación de
  > destino, así que exigirla hoy dejaría el traslado imposible de completar.

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

- **Un método de javascript que no existía, y nadie se enteró** (01-09-2026).
  Tres sitios llamaban a `sigmaAlertas.leer(id)` para marcar una alerta como
  vista al abrirla: el panel de la campana, la pantalla de Alertas y el aviso
  emergente. **`sigma-alertas.js` nunca expuso ese método.** Un error dentro
  de un `onclick` no detiene la navegación ni se ve en pantalla, así que la
  ficha se abría igual y el contador simplemente no bajaba nunca.

  El endpoint `WsAlertas/Leer` tampoco era llamable: pedía el id **cifrado**
  y el javascript no tiene con qué cifrar. Se dejó en claro, que es lo
  correcto acá —`UPD_ALERTA_LEER` filtra por cliente, usuario y permiso, así
  que el id no es una llave— y además ya estaba impreso en el `onclick` de la
  propia página.

  > Un cifrado que impide usar el método y no impide nada más es una reja
  > puesta en un sitio donde no hay puerta.

- **`Page_PreRender` con `if (IsPostBack) return;` en un listado**
  (01-09-2026). Es lo que hacía que los filtros de Alertas no filtraran. El
  botón *Buscar* de `wucFiltro` es un `PushButton` **sin `OnClick`**: lo único
  que provoca es el postback, y cada listado arma su lista en `PreRender`.
  Al saltárselo, la página se redibujaba desde el ViewState con los datos de
  antes: se elegía una categoría, parpadeaba y mostraba lo mismo. No fallaba
  con un error, fallaba mostrando datos viejos.

- **La pantalla mostraba una cifra y el SP validaba otra** (bloque 87,
  01-09-2026). El movimiento de inventario decía *"Existencia actual:
  340,00 L"* y al registrar respondía *"13.- EXISTENCIA INSUFICIENTE EN ESA
  UBICACIÓN: HAY 0.00"*. Las dos cosas eran ciertas: el rótulo mostraba el
  total de la **bodega** y `INS_INVENTARIO_MOVIMIENTO` valida contra el
  **cubo** `(bodega, ubicación, lote)` desde el bloque 71.

  Se sumaban dos defectos de la pantalla, no de la base:

  1. El combo de ubicaciones ofrecía **las seis** de la bodega, incluidas las
     vacías, sin decir cuál tenía existencia.
  2. El lote **solo se pedía en el ingreso por compra**, así que toda salida
     de un repuesto con lote mandaba `@LOTE = NULL` y consultaba el cubo
     sin lote, que está en cero. Por la misma razón una **devolución** de un
     repuesto con lote era imposible de completar: el SP la rechaza con el
     error 7 y el formulario no ofrecía dónde elegirlo.

  Corregido con `SEL_INVENTARIO_ORIGEN`: en una salida se elige **el cubo**
  —un solo combo, con la cantidad y el lote en la etiqueta, ordenado por
  vencimiento— en vez de armarlo entre dos campos que pueden no
  corresponderse.

  > **La regla:** un número junto a un campo tiene que ser el que se va a
  > validar. Mostrar un agregado al lado de una decisión que se toma al
  > detalle no ayuda: invita a confiar en él.

- **`@@ROWCOUNT` se lee en la línea siguiente o no se lee** (bloque 89,
  01-09-2026). El bloque 77 metió el código automático **entre** el `INSERT`
  y su comprobación:

  ```sql
  INSERT ...
  SET @ID = SCOPE_IDENTITY()
  IF (@CODIGO = 'AUTO') UPDATE ... SET codigo = FNC_CODIGO_AUTOMATICO(...)
  IF @@ROWCOUNT = 0 -> ROLLBACK
  ```

  `@@ROWCOUNT` es de la **última sentencia ejecutada**. Con un código escrito
  a mano el `IF` no se cumple, **un `IF` que no se cumple deja `@@ROWCOUNT`
  en 0**, y el procedimiento deshacía una inserción que había funcionado
  reportando *"4.- NO FUE POSIBLE INSERTAR…"*.

  Rompió **siete altas**: `INS_ACTIVO`, `INS_CENTRO_COSTO`,
  `INS_CLIENTE_INSTALACION`, `INS_ESPECIALIDAD`, `INS_GRUPO_TRABAJO`,
  `INS_INSTALACION_AREA`, `INS_PLAN_COMERCIAL`.

  Con `'AUTO'` funcionaba **de casualidad** —el `UPDATE` se ejecutaba y dejaba
  `@@ROWCOUNT` en 1—, y por eso el defecto no se vio al escribir el bloque 77:
  apareció recién cuando alguien escribió un código a mano.

  > **La regla:** `@@ROWCOUNT` y `@@ERROR` se leen en la línea siguiente o se
  > capturan en una variable. Cualquier sentencia intermedia —incluido un `SET`
  > o un `IF` que no se cumple— los reescribe.

- **`DataTable.Load($rd)` consume todos los resultsets.** `ejecutar.ps1`
  imprimía solo el primer `SELECT` de cada lote y los demás desaparecían sin
  error, así que una prueba con varios `SELECT` parecía no haber corrido.
  Para consultas usar `scratchpad/consulta.ps1`, que llena un `DataSet` con
  `SqlDataAdapter` y los muestra todos.

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

| 31-08-2026 | **Sprint 2 · HU-030 — Administrar tipos de activo (Emilio, todas las tareas).** Tercera entidad del Sprint 2. `Activo_Tipo` es un **árbol** (`ati_activo_tipo_padre`) cuyas filas pueden ser **globales de SIGMA** (`ati_cliente` NULL) o **del cliente** — se construyó sobre la plantilla de `Centro_Costo`. **T-2221**: modelo revisado; el código es único **por cliente** (`UX_ATI_CLIENTE_CODIGO`), y como NULL e id de cliente son claves distintas, el cliente puede tener su propio "MOTOR" aunque exista el global. **Bloque 80** (T-2222–T-2225): se **amplió** `SEL_ACTIVO_TIPO` —el del bloque 74 solo servía al combo de la ficha de activo— a árbol con ruta/nivel, `@FILTRO` escapado, auditoría con nombre de usuario y una columna `ES_GLOBAL`, conservando los parámetros previos para no romper el combo; `INS_` valida código único por cliente y padre del mismo cliente o global; `UPD_` con `ISNULL`, validación de ciclo por CTE y **rechazo de editar un tipo global**; `DEL_` baja lógica que **rechaza si hay subtipos, activos o modelos** que usan el tipo. **Bloque 81** (T-2226): tipos del cliente Hamburgo en dos niveles (ROTATIVO → motor/bomba/ventilador; ESTATICO → intercambiador/estanque). **Bloque 82** (T-2233): pantallas `Tipos de activo` bajo el nodo Activos, permisos `VER TIPOS ACTIVO` / `CREAR EDITAR TIPOS ACTIVO`, `Menu_Funcion` y perfiles (el planificador es el dueño de HU-030). **Web** (T-2231, T-2232, T-2234): `ActivoTipos.aspx` (árbol con indentación por nivel y columna de ámbito SIGMA/Cliente) y `ActivoTipo.aspx` (ficha `sigma-modal-*`; un tipo global se abre en **solo lectura con aviso**, porque el SP lo rechaza igual); se ampliaron el modelo `ActivoTipo` y el `ActivoTipoController` (que ya existían para el combo) con la jerarquía, la auditoría y el CRUD. **Compila en `exitcode=0`; bloques 80–82 ejecutados y SPs probados en transacciones revertidas** (árbol correcto, duplicado por cliente rechazado, global no editable, DEL con subtipos rechazado, baja lógica). Queda pendiente la prueba en navegador (T-2235) |

| 31-08-2026 | **Sprint 2 · HU-042 — Configurar el medidor de un activo (Emilio).** Segunda entidad del Sprint 2, sobre la misma plantilla. **T-2018**: el modelo `Activo_Medidor` ya existía (bloque 11); se revisó y se confirmó su índice único. **Hallazgo y decisión**: el código del medidor es único **por activo** (`UX_AME_ACTIVO_CODIGO (ame_activo, ame_codigo)`), no por cliente como decía la plantilla de la tarea. Es lo correcto: un activo no puede tener dos "HOROMETRO", pero dos activos distintos sí; `INS_`/`UPD_` validan por activo. **Probado contra la base**: mismo código rechazado en el mismo activo, permitido en otro. **Bloque 77** (T-2019 a T-2022): `SEL_ACTIVO_MEDIDOR` (dinámico, `@FILTRO` escapado, auditoría con nombre de usuario), `INS_` en transacción con código único por activo, `UPD_` con `ISNULL` y el activo inmutable, `DEL_` baja lógica que **rechaza si el medidor tiene lecturas** (`Activo_Medidor_Lectura`). Otra decisión: `ame_fecha_valor_actual_utc` se sella con `GETUTCDATE()` —su sufijo `_utc` lo pide; la app compara lecturas de husos distintos—, mientras la auditoría va con `FNC_PAIS_HORA`. **Bloque 78** (T-2023): sembró las unidades que un medidor necesita —**horas, ciclos, kilómetros**, que no existían (solo había unidades de inventario)— y 4 medidores demo en Hamburgo. Un índice filtrado permite una sola unidad base por magnitud, así que CICLO y KILÓMETRO cuelgan de las bases ya presentes (UNIDAD, METRO) y HORA es la base de TIEMPO. **Bloque 79** (T-2030): pantallas `Medidores` colgando del nodo Activos, permisos `VER MEDIDORES` / `CREAR EDITAR MEDIDORES`, `Menu_Funcion` y `Perfil_Permiso`. **Web** (T-2028, T-2029, T-2031): `ActivoMedidores.aspx` (grilla + `wucFiltro` + baja) y `ActivoMedidor.aspx` (ficha `sigma-modal-*` seccionada: Identificación y Medición, con combos de Activo y Unidad por `SEL_`, y `wuc:Auditoria`); `ActivoMedidor.cs` + `ActivoMedidorController.cs`. Seguridad en el servidor: filtro por `Session.ClienteId()` y `Token.Puede`/`PuedeFuncion`. **Compila en `exitcode=0`; bloques 77–79 ejecutados y SPs probados en transacciones revertidas.** Falta prueba en navegador |
| 31-08-2026 | **El año de fabricación del activo pasa a desplegable.** En `Activo.aspx` se escribía a mano en un `TextBox2` con parseo y guarda de rango (`LeerAnio`). Se reemplaza por un `RadComboBox2` poblado del año actual hacia 1950, con opción "Sin dato". Elegir de una lista evita el tipeo de un "20226" o un año futuro y quita la validación a mano. Mismo criterio que la puesta en marcha, que ya es calendario |

| 31-08-2026 | **Sprint 2 · HU-030 — Administrar tipos de activo (Emilio, todas las tareas).** Tercera entidad del Sprint 2. `Activo_Tipo` es un **árbol** (`ati_activo_tipo_padre`) cuyas filas pueden ser **globales de SIGMA** (`ati_cliente` NULL) o **del cliente** — se construyó sobre la plantilla de `Centro_Costo`. **T-2221**: modelo revisado; el código es único **por cliente** (`UX_ATI_CLIENTE_CODIGO`), y como NULL e id de cliente son claves distintas, el cliente puede tener su propio "MOTOR" aunque exista el global. **Bloque 80** (T-2222–T-2225): se **amplió** `SEL_ACTIVO_TIPO` —el del bloque 74 solo servía al combo de la ficha de activo— a árbol con ruta/nivel, `@FILTRO` escapado, auditoría con nombre de usuario y una columna `ES_GLOBAL`, conservando los parámetros previos para no romper el combo; `INS_` valida código único por cliente y padre del mismo cliente o global; `UPD_` con `ISNULL`, validación de ciclo por CTE y **rechazo de editar un tipo global**; `DEL_` baja lógica que **rechaza si hay subtipos, activos o modelos** que usan el tipo. **Bloque 81** (T-2226): tipos del cliente Hamburgo en dos niveles (ROTATIVO → motor/bomba/ventilador; ESTATICO → intercambiador/estanque). **Bloque 82** (T-2233): pantallas `Tipos de activo` bajo el nodo Activos, permisos `VER TIPOS ACTIVO` / `CREAR EDITAR TIPOS ACTIVO`, `Menu_Funcion` y perfiles (el planificador es el dueño de HU-030). **Web** (T-2231, T-2232, T-2234): `ActivoTipos.aspx` (árbol con indentación por nivel y columna de ámbito SIGMA/Cliente) y `ActivoTipo.aspx` (ficha `sigma-modal-*`; un tipo global se abre en **solo lectura con aviso**, porque el SP lo rechaza igual); se ampliaron el modelo `ActivoTipo` y el `ActivoTipoController` (que ya existían para el combo) con la jerarquía, la auditoría y el CRUD. **Compila en `exitcode=0`; bloques 80–82 ejecutados y SPs probados en transacciones revertidas** (árbol correcto, duplicado por cliente rechazado, global no editable, DEL con subtipos rechazado, baja lógica). Queda pendiente la prueba en navegador (T-2235) |

| 01-09-2026 | **Bloque 102 — los permisos se preguntan de una sola forma.** Se cierra la decisión que quedaba marcada con ⚠ desde el bloque 62. Las dos implementaciones se contradecían **en los dos sentidos**, medido: Marcela resolvía **34 permisos en un cliente ajeno** por el SP, y Soporte resolvía **0** por la función —árbol de app vacío—. Regla adoptada: un perfil en `Usuario_Perfil` otorga permisos **solo si es de plataforma** (`per_tipo = 1`); los de tipo Cliente son el espejo del bloque 49 y una copia no otorga nada. De paso se igualó una tercera diferencia que no estaba registrada: la autorización de planta, que la función exigía y el SP no |

### Cómo actualizar este documento

Al cerrar un bloque de trabajo: agregar la fila en la bitácora, mover lo
hecho de §7 a §4 o §5, y anotar en §6 **toda decisión que un tercero no
podría deducir del código**. Esa sección es la que evita rehacer discusiones
ya cerradas.
