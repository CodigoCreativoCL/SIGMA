# SIGMA — Traspaso de sesión

**Fecha:** 08-09-2026
**Rama de trabajo:** `BryanChavez` · **Estado del remoto:** las cuatro ramas alineadas
**Working tree:** limpio · **API compila:** 0 errores · **`flutter analyze lib`:** *No issues found!*

Este documento es autocontenido: sirve para retomar en otra sesión o terminal sin
leer nada más. Lo primero de la sección 3 es lo que sigue.

---

## 1. Dónde está todo

| Cosa | Ruta |
|---|---|
| App Flutter | `C:\Capstone\SIGMA\App\sigma_app` |
| API (ASP.NET Framework 4.8) | `C:\Capstone\SIGMA\Solucion\SIGMA\API` |
| Scripts de base | `C:\Capstone\SIGMA\BD` (van numerados; el último es **188**) |
| Web / intranet | `C:\Capstone\SIGMA\Web\Intranet` |
| Documentación | `C:\Capstone\SIGMA\MD` |

**Base de datos** (una sola, compartida por los tres): `sql5112.site4now.net` ·
`db_acd593_sigma` · usuario `db_acd593_sigma_admin`. La contraseña sale de
`Solucion/SIGMA/API/Web.config`, no se escribe en ningún otro lado.

**IIS sirve la API directamente desde la carpeta del proyecto** en
`http://192.168.1.38/SIGMA/Servicio/API`: compilar *es* desplegar.

### Comandos que se usan siempre

Compilar la API (obligatorio tras **cada** cambio en C#):

```bash
"/c/Program Files/Microsoft Visual Studio/2022/Professional/MSBuild/Current/Bin/MSBuild.exe" "Solucion/SIGMA/API/API.csproj" -v:m -nologo
```

Aplicar un script de base (desde PowerShell; copiar antes el `.sql` a
`C:\Capstone\_scratch\` porque `sqlcmd -i` falla con rutas largas):

```bash
sqlcmd -S sql5112.site4now.net -d db_acd593_sigma -U db_acd593_sigma_admin -P <clave> -i C:\Capstone\_scratch\NNN.sql
```

Analizar la app:

```bash
cd App/sigma_app && flutter analyze lib
```

### Dos auditorías que conviene volver a correr antes de cerrar cualquier bloque

Están en `C:\Capstone\_scratch\` y hoy las dos salen limpias:

- `auditar_rutas.py` — cruza **toda llamada de la app** contra las **96 rutas** que
  declara la API, comparando ruta *y* verbo.
- `auditar_sp.py` — cruza los `Datos.Ejecutar` de los controllers contra
  `sys.parameters` de los **65 SP**.

Encontraron cuatro defectos que ni el compilador ni `flutter analyze` ven. Vale la
pena correrlas cada vez que se agrega un endpoint.

---

## 2. Qué se cerró hoy

Seis commits, ya en `master`, `EmilioFuentes` y `CatalinaPescio`.

**Defectos corregidos** (los cuatro silenciosos: compilaban y analizaban limpio):

1. **El cambio de estado del activo no llegaba nunca.** La app encolaba contra
   `POST /activos/{id}/estado`, que no existe — el alta vive en
   `POST /activo-estados`. Como el outbox confirma contra el disco, la pantalla
   decía «estado cambiado» sobre un 404 que se quedaba en Pendientes.
2. **Guardar el teléfono lo borraba.** La app mandaba `usu_telefono` (el nombre de
   la *columna*) y `MiPerfilEdicionDto` recibe `telefono`; el binder lo dejaba en
   null y el SP asignaba `usu_telefono = @TELEFONO` sin `ISNULL`.
3. **La contraseña no se podía cambiar.** La ruta es `[HttpPost]` y la app llamaba
   con PUT → 405.
4. **La mano de obra tampoco.** `API_INS_ORDEN_TRABAJO_MANO_OBRA` recibía `@UUID`
   sin declararlo: ni el propio tramo ni sumar al compañero funcionaban.

**Historias cerradas:** HU-063 (solicitar permiso de trabajo desde el terreno) y
HU-057 (ajustar existencia contando en el pasillo).

**Scripts de base nuevos:** `186_APP_ACTIVO_ESTADO_UUID.sql`,
`187_APP_MI_PERFIL_TELEFONO.sql`, `188_APP_MANO_OBRA_UUID.sql`. **Ya aplicados**
en la base compartida y verificados llamando dos veces al SP con el mismo `uuid`
dentro de una transacción revertida.

---

## 3. Lo siguiente: cerrar una OT (HU-120)

> **Requisito del usuario:** «se exige que jefe de mantenimiento, supervisor o
> planificador puedan cerrarla».

`MD/SIGMA_ALCANCE_APP.md` había dejado HU-120 como historia de escritorio
—finalizar (HU-119, técnico) frente a cerrar (HU-120, planificador)—. Ese criterio
queda **revocado**: el cierre entra a la app.

### La base ya está hecha. No hay que tocarla.

Verificado contra la base el 08-09-2026:

| Objeto | Estado |
|---|---|
| `UPD_ORDEN_TRABAJO_CERRAR` | ✅ existe |
| `FNC_USUARIO_PUEDE_CERRAR_OT` | ✅ existe |
| Permiso `CERRAR OT` | ✅ existe |
| Columnas `otr_cierre_motivo`, `otr_usuario_cierre`, `otr_fecha_cierre` | ✅ existen |
| Catálogo `Orden_Trabajo_Cierre_Motivo` | ✅ 6 motivos habilitados |

**Firma del SP:**

```
UPD_ORDEN_TRABAJO_CERRAR
    @ORDEN_TRABAJO  INT
    @USUARIO        INT
    @CIERRE_MOTIVO  INT
    @OBSERVACION    NVARCHAR(500) = NULL
```

**El permiso `CERRAR OT` lo tienen exactamente estos perfiles** — que son los tres
que pide el requisito, más Root:

- Jefe de Mantenimiento (5)
- Planificador de Mantenimiento (11)
- Supervisor de Mantenimiento (12)
- Root (1)

`FNC_USUARIO_PUEDE_CERRAR_OT` comprueba **por permiso y no por nombre de perfil**,
a propósito: el día que un cliente llame distinto a sus cargos, la regla sigue
funcionando. No cambiar eso.

**Estados de la OT:** 1 ABIERTA · 2 EN EJECUCIÓN · 3 EN ESPERA DE CIERRE · 4 CERRADA.

**Motivos de cierre:** 1 Trabajo realizado · 2 Sin hallazgo · 3 Resuelta en otra OT ·
4 Duplicada · 5 Anulada por error de registro · 6 No aplica.

### Reglas que el SP ya hace cumplir (no duplicarlas en C# ni en Dart)

- Solo cierra quien tiene `CERRAR OT`; si no, mensaje explícito.
- Solo se cierra **desde el estado 3 (EN ESPERA DE CIERRE)**: el técnico tiene que
  finalizarla primero.
- **Un permiso de trabajo exigido y sin autorizar bloquea el cierre.** Textual del
  SP: cerrar una OT cuyo permiso nunca se firmó es documentar una mentira.
- El motivo de cierre tiene que existir y estar habilitado.

Los `RAISERROR` los traduce `ErrorSql` a su código HTTP; no escribir manejo de
errores propio.

### Lo que falta construir

**1. API — no existe la ruta.** Hoy `OrdenesTrabajoController` expone `tomar`,
`pasos/{id}`, `finalizar`, `mano-obra`, `repuestos` y `repuestos-disponibles`. Falta:

- `POST /ordenes-trabajo/{id}/cerrar` con `ExigirPermiso("CERRAR OT")`,
  `ExigirCliente()` y `ExigirUsuario()`.
- Un `CierreOrdenDto` con `motivo` (int), `observacion` (string) y `uuid` (Guid?).
- Un `GET /ordenes-trabajo/motivos-cierre` que lea `Orden_Trabajo_Cierre_Motivo`,
  para que la app no traiga los seis motivos en duro.

**2. Idempotencia.** El SP **no** tiene corte por `uuid` todavía. Si el cierre se va
a encolar en el outbox —y debería, es una acción de terreno—, hace falta un script
**189** con el mismo patrón que 177/186/188: el corte por uuid **antes** de las
validaciones, para que un reintento sobre una OT ya cerrada no responda «la OT no
está en espera de cierre» por algo que sí se hizo. `Orden_Trabajo` ya tiene columna
`otr_uuid`, pero es la de creación: hay que agregar una propia del cierre
(`otr_cierre_uuid`) con índice único filtrado.

**3. App.** Botón «Cerrar» en la ficha de OT, visible solo con
`tienePermisoProvider('CERRAR OT')`, que abra una hoja con los motivos como chips y
un campo de observación. Encolar con `uuid` nacido al abrir la hoja. Seguir el
patrón de `lib/screens/inventario/hoja_ajuste.dart` y
`lib/screens/permiso_trabajo/nuevo_permiso_screen.dart`, que son los dos más
recientes y ya usan `HojaRecurso`.

**4. Añadir `'CIERRE_OT'` al icono de Pendientes** en
`lib/screens/pendientes/pendientes_screen.dart`.

**Ojo al probar:** hoy hay **0 OT en estado 3**. Para probar el cierre hay que
finalizar una primero desde la app (HU-119), o mover una a mano dentro de una
transacción revertida.

---

## 4. Lo demás que queda pendiente

### Push / notificaciones (HU-077)

`POST /dispositivos` es el único endpoint de escritura de la API que la app no
llama. `firebase` aparece solo como **comentario** en `pubspec.yaml:35`, no hay
`google-services.json` y el token nunca se registra. Sin esto, compartir un trabajo
y las alertas dirigidas solo se ven si el usuario abre la app por su cuenta.

### Diseño v3 — 14 vistas sin construir

De las ~40 de `MD/SIGMA-APP-Especificacion-Vistas-UI-UX.md` hay 26 hechas.

**Con endpoint disponible** (solo falta pantalla):

- 6.2 Nueva OT correctiva (HU-110) — `POST /ordenes-trabajo`
- 10.3 Ficha del repuesto — `GET /existencias/repuesto/{id}`
- 10.5–10.8 Bodegas y ubicaciones — `GET /bodegas`, `/bodegas/{id}/ubicaciones`
- 10.9–10.12 Ingreso, entrega, devolución y traslado — `POST /inventario-movimientos`
  con tipos 1, 2, 3 y 6 (el ajuste, tipos 4 y 5, ya está hecho)
- 11.2 Ficha del permiso — `GET /permisos-trabajo/{id}`
- 10.2 Listado de repuestos — `GET /repuestos`

**Sin endpoint** (hay que construir API y base primero):

- 6.7 Firmas (HU-118) — no existe tabla ni ruta
- 8.1–8.4 Componentes: listado, ficha, historial y galería. La ficha del activo
  tampoco tiene el tab Componentes que pide 7.3 (hoy solo Ficha e Historial)
- 9.2 Historial de lecturas con gráfico de tendencia y umbrales
- 7.4 y 10.4 Galerías: cuadrícula cronológica con filtros
- 13.2 Centro de evidencias
- 15.2 Conflicto de sincronización (versión local contra versión del servidor)
- 16.2 Accesibilidad: tamaño de texto, alto contraste, movimiento reducido

### Datos, no código

`Repuesto_Compatibilidad` y `Usuario_Especialidad` están **vacías**. El código está
hecho y probado, pero mientras no se carguen desde la web el badge «Compatible» del
repuesto no aparece nunca y los chips de especialidad salen vacíos.

---

## 5. Convenciones que no se negocian

1. **Leer el patrón antes de escribir la primera línea.** `PATRONES/ASP/BaseDatos/PATRON_SP.md`
   y `PATRON_TABLAS.md`: prefijo `API_` para SP de la app, `Pascal_Snake_Case` en
   tablas, prefijo de tres letras en columnas, `CREATE OR ALTER`, scripts idempotentes.
2. **Compilar la API siempre** tras cada cambio en C#.
3. **La seguridad es por datos, no por páginas.** No hay `Paginas.cs`: registrar una
   pantalla es un `INSERT` en `Menus`.
4. **Toda captura de terreno se encola**, con el `uuid` generado **al encolar** (no al
   enviar), el **409 tratado como éxito**, y nada descartado por número de intentos.
5. **El cliente sale del token**, nunca de la URL ni del cuerpo.
6. **Los nombres del cuerpo son los del DTO**, no los de la columna. Ese fue el
   defecto 2 de hoy.
7. **`MD/SIGMA_ESTADO_DESARROLLO.md` y `MD/SIGMA_APP_ESTADO.md` se actualizan al
   cerrar cada bloque.** Son el traspaso entre sesiones.

---

## 6. Estado de git

| Rama | Commit | Contenido |
|---|---|---|
| `master` | `621a12f` | todo |
| `BryanChavez` | `621a12f` | todo |
| `EmilioFuentes` | `adcc3a1` | merge de master |
| `CatalinaPescio` | `1f20b0e` | merge de master |

El precompilado de la intranet (`_program files_git_intranet/`, 294 MB de DLL) salió
del repositorio y está en `.gitignore`. **Un `git pull` lo borra del disco** — es el
comportamiento normal de git al traer un commit que elimina archivos rastreados. Si
alguien lo necesita para su IIS local:

```bash
git archive 5083efe "_program files_git_intranet" | tar -x
```

O simplemente republicar la intranet desde Visual Studio.
