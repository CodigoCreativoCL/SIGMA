# SIGMA — Alcance de la app y de la API (normativo)

**Qué decide este documento:** qué se construye en la API y en la aplicación
móvil, y qué no. Es la respuesta a una pregunta concreta que apareció el
30-08-2026 mirando los seis Sprint Backlogs: *cada una de las 132 historias
tenía tareas de API, incluidas las que nadie va a abrir nunca desde un
teléfono.*

Fecha: 30-08-2026 · **actualizado el 31-08-2026** con el retiro efectivo (§6).
Sustituye cualquier criterio anterior sobre qué endpoints existen.

---

## 1. Quién usa la app

Seis perfiles. No siete, no "los usuarios del cliente":

| Perfil | Qué hace en la app |
|---|---|
| **Técnico de Mantenimiento** | ejecuta: su bandeja, los pasos de la OT, lecturas, mediciones, evidencias, bitácora, consumo de repuestos, descubrimiento en terreno |
| **Supervisor de Mantenimiento** | valida en planta: firmas, estado de activos, fallas, indisponibilidad, reasignar una OT |
| **Jefe de Mantenimiento** | acepta OT, autoriza permisos de trabajo, mira el panel |
| **Planificador de Mantenimiento** | consulta y alertas; **su trabajo de planificación es de escritorio** |
| **Bodeguero** | ingreso, entrega, existencia y ajuste de inventario, en el pasillo |
| **Prevencionista de Riesgos** | permisos de trabajo: los registra y los verifica en el frente |

El **Administrador del Cliente no está en esta lista**. Hace la configuración
base —usuarios, perfiles, plantas, áreas, centros de costo, catálogos,
especialidades, grupos— **desde la web**, para que los seis de arriba puedan
operar. Root, Soporte y Gerente Comercial tampoco: son cuentas de plataforma.

### El técnico no usa la web

No es una recomendación, es una restricción. Hasta el bloque 58 el perfil
`Técnico de Mantenimiento` tenía `VER PLANTAS`, `VER AREAS`, `VER CATALOGOS`
y `VER GRUPOS TRABAJO`; esos cuatro permisos abrían **ocho filas de `Menus`**
apuntando a páginas `.aspx`. Es decir: un técnico entraba a la web y navegaba
la organización del cliente.

Los permisos no se le quitaron —los necesita, la app lee esos mismos datos—.
Lo que se agregó es dónde vale cada cosa.

---

## 2. El mecanismo: `per_ambito` y `mnu_ambito`

`Permiso_Ambito` (WEB / APP / AMBOS) existía desde el Anexo D, pero colgaba
solo del permiso. El bloque **58** lo pone donde de verdad decide:

```text
Perfiles.per_ambito  ->  dónde puede operar quien tiene ese perfil
Menus.mnu_ambito     ->  en qué superficie vive esa opción
```

| Perfil | Ámbito |
|---|---|
| Root | AMBOS — es la cuenta con la que se prueba todo |
| Soporte, Gerente Comercial | WEB |
| **Administrador del Cliente** | **WEB** |
| Bodeguero, Jefe, Planificador, Supervisor, Prevencionista | AMBOS |
| **Técnico de Mantenimiento** | **APP** |

`SEL_LOGIN` recibe `@AMBITO` (DF 1 = WEB, para que la web siga llamando con
dos argumentos) y rechaza con **403** a quien no opera ahí. El mensaje dice
dónde sí puede entrar: *"Tu perfil trabaja desde la aplicación móvil de
SIGMA, no desde la web."* Un "acceso denegado" a secas manda al técnico a
llamar al administrador por algo que no es un problema.

Probado contra la base:

```text
cristian.munoz@hamburgo.cl  ámbito WEB -> 403
cristian.munoz@hamburgo.cl  ámbito APP -> 200
```

`per_ambito` nace con DF 1 (WEB) a propósito. Si alguien agrega un perfil y
se olvida de la columna, el perfil nace sin acceso móvil. Equivocarse hacia
"no entra a la app" es recuperable; hacia el otro lado es dar acceso móvil a
quien no debía.

---

## 3. El menú de la app se resuelve por datos, igual que el de la web

En la web, una pantalla sin fila en `Menus` no se abre. Si la app trajera sus
opciones escritas en Dart habría **dos modelos de permisos** que mantener, y
el día que se revoque uno la web lo escondería y el teléfono no.

Por eso nace `SEL_MENU_APP` y `GET /menus`:

- solo filas con `mnu_ambito` APP o AMBOS;
- con permiso, se compara contra los permisos vigentes del usuario —perfil +
  concesión + revocación + vigencia + planta— reutilizando
  `FNC_USUARIO_TIENE_PERMISO`;
- los grupos suben solos: un nodo padre aparece porque tiene hijos visibles,
  nunca vacío;
- `mnu_permiso NULL` = visible para quien entró. Mismo trato que
  `RecuperarClave.aspx` y `SeleccionarCliente.aspx` en la web, y solo para
  pantallas que no muestran datos de nadie más.

Hoy devuelve **dos opciones**: `app://inicio` y `app://mi-perfil`. Porque hoy
la app tiene dos pantallas. Las de órdenes, repuestos, checklists y permisos
de trabajo son filas nuevas en `Menus` y nacen en el sprint donde se
construye la pantalla. Sembrarlas antes daría un menú que navega a la nada
— que es exactamente el bug que costó tres correcciones en agosto.

`mnu_link` de la app usa el esquema `app://` para que se vea de un vistazo
que esa fila no apunta a ningún `.aspx`.

---

## 4. La API sí valida permisos (antes no validaba ninguno)

Hallazgo del 30-08: los 14 controllers llamaban a `ExigirUsuario()` —"el
token es válido"— y de ahí pasaban directo al SP. **Ni un solo endpoint
comprobaba un permiso.** El token de un técnico servía para llamar
`POST /clientes` o `DELETE /cliente-usuarios/{id}`.

La web nunca tuvo ese agujero porque `Token.Puede()` se consulta antes de
cada acción. Los SPs heredados tampoco tapan el hueco: muchos no validan
permiso porque dan por hecho que la pantalla ya lo hizo, y confiar en eso es
confiar en una comprobación que ocurre en otro proyecto.

Se agregó `ApiBase.ExigirPermiso(codigo)` y `ExigirAlgunPermiso(...)`, sobre
`Utils/Permisos.cs`, que lee de `SEL_USUARIO_PERMISOS` — la misma fuente que
la web — con caché de 60 segundos. **52 endpoints** quedaron con su permiso.

Responde **403**, no 401: el token está bien, quien lo trae no. La distinción
importa porque ante un 401 la app borra la sesión y vuelve a pedir
credenciales, y ahí reintentar no cambia nada.

Dos endpoints quedan deliberadamente sin permiso: `GET /cliente-usuarios/mis-clientes`
y `POST /cliente-usuarios/seleccionar`. Son parte de iniciar sesión; exigir un
permiso ahí dejaría a la persona con un token que no sirve para elegir el
cliente que ese mismo token necesita.

> Los 52 son del 30-08, cuando había 64 endpoints. Con el retiro del 31-08
> quedan **21**, y los que sobreviven conservan su `ExigirPermiso`. Que la
> superficie sea chica no reemplaza la comprobación: la app la usa gente con
> perfiles distintos, y un bodeguero no tiene por qué leer las áreas de una
> planta donde no está autorizado.

---

## 5. Las tres reglas que se aplicaron al backlog

| | Regla | Por qué |
|---|---|---|
| **R1** | Una historia **sin App** no lleva tareas de API ni de Móvil | La web es WebForms y llama a los SP directo: no pasa por la API. Un endpoint para una historia solo web **no lo consume nadie** |
| **R2** | Una historia **solo App** no lleva pantalla web | Es el mismo espejo, al revés |
| **R3** | El **técnico no usa la web**: toda historia cuyo único actor es el técnico pasa a App | §1 |
| **E1** | `HU-076` se excluye | Es un proceso de servidor; su "API" es el disparador del job, no una superficie de la app |
| **E2** | R1 no alcanza a **la lectura que otra historia de App consume** | Plantas, áreas y catálogos son historias de administración (web), pero la app necesita leer esos datos: son los que bajan al dispositivo en **HU-150**. Se conserva el `GET`, se retira la escritura |

R3 salió limpia en los ocho casos porque el backlog **ya tenía la historia de
escritorio separada**: finalizar (HU-119, técnico) frente a cerrar (HU-120,
planificador); mi bandeja (HU-121) frente a la bandeja de supervisión
(HU-122); adjuntar (HU-140) frente a la galería (HU-142); capturar la lectura
(HU-043/044) frente a consultar la serie (HU-045). No hubo que inventar
ninguna.

### Plataforma corregida — 12 historias

**Promovidas a App** (el perfil las necesita en terreno):

| HU | Título | Por qué |
|---|---|---|
| HU-004 | Recuperar mi contraseña | el técnico no tiene web donde pedirla |
| HU-057 | Registrar un ajuste de inventario | el bodeguero cuenta en el pasillo |
| HU-064 | Consultar permisos vigentes y por vencer | el prevencionista verifica en el frente de trabajo |
| HU-112 | Asignar una orden de trabajo | el supervisor reasigna en planta cuando alguien no llega |

**Pasadas a solo App** (R3): HU-043, HU-044, HU-115, HU-116, HU-119, HU-121,
HU-130, HU-140.

### Lo que salió

| Sprint | Tareas fuera de alcance | Horas |
|---|---:|---:|
| S1 | 34 | 17,75 |
| S2 | 58 | 33,50 |
| S3 | 52 | 31,75 |
| S4 | 61 | 48,00 |
| S5 | 30 | 29,75 |
| S6 | 35 | 41,25 |
| **Total** | **270** | **202,00** |

243 tareas de API que no iba a consumir nadie y 27 pantallas web de historias
que son solo del técnico.

> El primer recuento decía 278 y 206 h. Ocho tareas del Sprint 1 volvieron a
> *Terminada* al aplicar **E2**: son los `GET` de plantas, áreas y catálogos,
> que existen y los consume la app. Marcarlas descartadas decía algo falso
> sobre endpoints que están publicados y funcionando.

**En S1 no se borraron**: esos 34 endpoints ya están construidos. Quedan como
`Descartada` con el motivo escrito, porque reescribir el registro de un
sprint para que parezca que nunca se hizo el trabajo es peor que dejar la
constancia de que se hizo de más. En S2–S6 se eliminaron: no existían todavía.

Se agregaron **10 tareas nuevas** (`T-19xx`, `T-39xx`, `T-59xx`) con lo que sí
hay que construir: `mnu_ambito` / `per_ambito`, `SEL_MENU_APP`, el guard de
ámbito en `SEL_LOGIN`, `GET /menus`, `ExigirPermiso`, la navegación Flutter
desde el árbol, y las cuatro pantallas móviles de las historias promovidas.

---

## 6. Inventario de endpoints al 30-08-2026

**De la app** — se mantienen y se prueban primero:

| Endpoint | HU |
|---|---|
| `POST /sesion` · `GET /sesion` · `DELETE /sesion` | HU-001, HU-003 |
| `GET /cliente-usuarios/mis-clientes` · `POST /cliente-usuarios/seleccionar` | HU-002 |
| `GET /usuario-permisos` · `GET /usuario-permisos/tengo/{codigo}` | HU-006 |
| **`GET /menus`** | HU-006 (nuevo) |
| `GET /mi-perfil` · `PUT /mi-perfil` · `POST /mi-perfil/password` | HU-005 |
| `POST /usuario-recuperaciones` · `POST /usuario-recuperaciones/restablecer` | HU-004 |

**Lectura que la app necesitará desde el Sprint 2** (HU-150, sincronización
hacia el dispositivo). Se conserva el `GET`; la escritura es de la web:

`GET /cliente-instalaciones` · `GET /instalacion-areas` · `GET /catalogos` ·
`GET /catalogos/{codigo}/valores`

**Retirado el 31-08-2026.** Estaba construido y funcionaba; se fue porque no
lo consume nadie —la web llama a los SP directo y la app no hace esa tarea—.

| Controller | Historia |
|---|---|
| `ClientesController` | HU-010 · alta de clientes de la plataforma |
| `PerfilesController` | HU-015 · perfiles y su matriz |
| `CentrosCostoController` | HU-013 |
| `GrupoTrabajosController` | HU-016 |
| `UsuarioEspecialidadesController` | HU-017 |
| `ClienteUsuarioPermisosController` | HU-007 · `ASIGNAR PERMISO TERRENO` es ámbito **WEB** (Anexo D §6) |
| `ValuesController` | el controller de ejemplo de la plantilla de Visual Studio, que respondía en `.../API/values` por la ruta convencional |

Y cuatro recortes sin retirar el archivo:

| Controller | Queda | Se fue |
|---|---|---|
| `ClienteUsuariosController` | `mis-clientes` y `seleccionar` (HU-002) | el CRUD de HU-014 |
| `ClienteInstalacionesController` | los dos `GET` | `POST` `PUT` `DELETE` |
| `InstalacionAreasController` | los dos `GET` | `POST` `PUT` `DELETE` |
| `CatalogosController` | los cuatro `GET` | `POST` `PUT` `DELETE` |

Con eso la API pasa de **64 a 21 endpoints**, en 9 controllers. Los 16 DTOs que
se quedaron sin dueño salieron de `Dto.cs`.

Todo quedó en `_RETIRADO/API/`, no borrado: **el proyecto no está en git**, así
que borrar es irreversible. El `LEEME.md` de esa carpeta explica cómo volver
atrás — y recuerda el paso que se olvida siempre, agregar el `<Compile Include>`
al `API.csproj`, porque es un proyecto de aplicación y no compila lo que no esté
declarado.

---

## 7. Lo que falta

- **La API sigue sin ejercitarse contra la base por HTTP.** Compila en
  `exitcode=0` y `SEL_LOGIN` está probado con SQL directo, pero ningún
  endpoint se ha llamado. Empezar por `POST /sesion` con
  `cristian.munoz@hamburgo.cl`: es el caso que ahora distingue web de app.
- La app Flutter no existe. Las 5 tareas móviles de S1 siguen `Por hacer`.
- `GET /menus` devuelve dos opciones hasta que haya pantallas que ofrecer.
- Pruebas y documentación de las historias: son de Catalina Pescio y no han
  empezado. Ninguna historia sale de *En revisión* sin eso.
- Ni `/sesion` ni la recuperación tienen límite de intentos por IP. El bloqueo
  por cuenta existe; nada impide probar mil correos distintos.

---

## 8. Bitácora

| Fecha | Qué |
|---|---|
| 31-08-2026 | **Retirados los endpoints que no van.** 7 controllers a `_RETIRADO/API/` —6 de historias solo web más el `ValuesController` de la plantilla de Visual Studio, que respondía en `.../API/values`— y 4 recortados a sus `GET`. De **64 endpoints a 21**, en 9 controllers. También salieron los 16 DTOs que quedaron sin dueño. Al anotar las tareas del S1 apareció **E2**: 8 de las 42 descartadas eran los `GET` de plantas, áreas y catálogos, que **no** se retiraron porque la app los consume al sincronizar; vuelven a Terminada y el recuento queda en **270 tareas y 202 h**. Compila en `exitcode=0` |
| 30-08-2026 | Nace este documento. Bloque **58**: `per_ambito`, `mnu_ambito`, `FNC_USUARIO_OPERA_AMBITO`, `SEL_MENU_APP`, `SEL_LOGIN` con `@AMBITO`. En la API: `Utils/Permisos.cs`, `ExigirPermiso` en 52 endpoints, `MenusController`. Los seis Sprint Backlogs corregidos: 278 tareas fuera de alcance (206 h), 12 historias con plataforma corregida, 10 tareas nuevas |
