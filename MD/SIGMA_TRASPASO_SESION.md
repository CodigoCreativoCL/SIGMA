# SIGMA — Traspaso de sesión

**Fecha:** 08-09-2026
**Rama de trabajo:** `BryanChavez` · **Estado del remoto:** las cuatro ramas alineadas
**Working tree:** con el bloque de HU-120 **sin commitear** · **API compila:** 0 errores ·
**`flutter analyze lib`:** *No issues found!* · **auditorías:** 98 rutas y 67 SP, las dos limpias

Este documento es autocontenido: sirve para retomar en otra sesión o terminal sin
leer nada más. Lo primero de la sección 3 es lo que sigue.

---

## 1. Dónde está todo

| Cosa | Ruta |
|---|---|
| App Flutter | `C:\Capstone\SIGMA\App\sigma_app` |
| API (ASP.NET Framework 4.8) | `C:\Capstone\SIGMA\Solucion\SIGMA\API` |
| Scripts de base | `C:\Capstone\SIGMA\BD` (van numerados; el último es **192**) |
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
sqlcmd -S sql5112.site4now.net -d db_acd593_sigma -U db_acd593_sigma_admin -P <clave> -i C:\Capstone\_scratch\NNN.sql -f 65001
```

**`-f 65001` no es opcional.** Sin él sqlcmd lee el `.sql` como ANSI y todo
acento entra roto —el SP de la sábana tenía `seÃ±al` guardado— sin que nada
avise. Escribir el archivo con BOM también sirve.

Analizar la app:

```bash
cd App/sigma_app && flutter analyze lib
```

### Tres auditorías que conviene volver a correr antes de cerrar cualquier bloque

Están en `C:\Capstone\_scratch\`:

- `auditar_rutas.py` — cruza **toda llamada de la app** contra las **98 rutas** que
  declara la API, comparando ruta *y* verbo.
- `auditar_sp.py` — cruza los `Datos.Ejecutar` de los controllers contra
  `sys.parameters` de los **67 SP**.
- `auditar_muertos.py` — métodos del repositorio que ninguna pantalla llama,
  providers que nadie observa, y escrituras que se saltan el outbox.
- `auditar_id_output.py` — **la más importante hoy**: los SP que el controller
  llama con `devuelveId: true` y no declaran `@ID OUTPUT`. Cada uno es un
  endpoint que responde 400 y no hace nada. Hoy salen **ocho**; tiene que quedar
  en cero. Ver §3.1.5.

Las dos primeras salen limpias. La tercera **no está pensada para salir en cero**:
el repositorio es el mapa de la API —un método por endpoint— así que un método sin
pantalla es deuda conocida, no basura. Lo que sí tiene que quedar en cero son los
providers sin observadores.

Las tres encuentran lo que ni el compilador ni `flutter analyze` ven: el analizador
no avisa de un método público que nadie llama, porque para él es API de la
librería. Vale la pena correrlas cada vez que se agrega un endpoint o una pantalla.

---

## 2. Qué se cerró antes en el día

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

## 3. Cerrar una OT (HU-120) — construido y probado de punta a punta

> **Requisito del usuario:** «se exige que jefe de mantenimiento, supervisor o
> planificador puedan cerrarla», **y que se pueda cerrar tanto por la app como
> por la web**.

`MD/SIGMA_ALCANCE_APP.md` tenía HU-120 como historia de escritorio. Ese criterio
queda **revocado**: el cierre entra a la app **sin salir de la web**.

### Lo que se construyó

**1. API.** `OrdenesTrabajoController` suma dos rutas:

- `POST /ordenes-trabajo/{id}/cerrar` con `ExigirPermiso("CERRAR OT")`,
  `ExigirCliente()` y `ExigirUsuario()`. Recibe `CierreOrdenDto`
  —`motivo` (int), `observacion` (string), `uuid` (Guid?)— y llama a
  `UPD_ORDEN_TRABAJO_CERRAR`. El `@USUARIO` sale del token, nunca del cuerpo:
  `otr_usuario_cierre` es quien firma el cierre.
- `GET /ordenes-trabajo/motivos-cierre`, que lee el catálogo con
  `API_SEL_ORDEN_TRABAJO_CIERRE_MOTIVO` para que la app no lleve los seis
  motivos en duro.

**Ninguna regla se duplicó.** La jerarquía, el estado 3 previo, el motivo
habilitado y el bloqueo por permiso de trabajo sin autorizar los sigue haciendo
cumplir el SP; sus `RAISERROR` los traduce `ErrorSql`. La autorización sigue
siendo **por permiso y no por nombre de perfil**.

**2. `BD/189_APP_CIERRE_OT_UUID.sql` — aplicado y verificado.** Agrega
`otr_cierre_uuid` con índice único **filtrado** y el corte por uuid **antes** de
las validaciones, con el patrón de 177/186/188.

- *Por qué el corte va antes:* sin él, el reintento del outbox sobre una OT que
  **sí** se cerró vuelve a pasar por las validaciones y muere en «la OT no está
  en espera de cierre» —porque ese mismo uuid la dejó en 4—, es decir falla por
  haber funcionado, y la cola lo pinta como rechazo sobre un cierre correcto.
- *Por qué una columna propia y no `otr_uuid`:* aquel es el uuid de **creación**,
  lo usa `API_INS_ORDEN_TRABAJO`, y toda OT nacida en la app ya lo trae ocupado.
- *Por qué el índice es filtrado:* las OT que cierra la web no llevan uuid y son
  todas NULL; un unique normal dejaría pasar una sola en toda la tabla.

**3. App.** Botón «Cerrar» en el pie de la ficha de OT, visible solo con
`tienePermisoProvider('CERRAR OT')` y solo en estado 3, que abre
`lib/screens/ordenes/hoja_cierre.dart` —motivos como chips, observación libre y
opcional—. Encola con el `uuid` nacido **al abrir la hoja**. Sigue el patrón de
`hoja_ajuste.dart`. Al técnico sin el permiso el pie le sigue diciendo «En
espera de cierre», como antes.

**4.** `'CIERRE_OT'` entra al switch de iconos de `pendientes_screen.dart`.

### La web sigue cerrando igual, y está comprobado

`@UUID` es **opcional y va último**, así que la llamada de la web —tres o cuatro
argumentos, por nombre o posicional— se comporta exactamente como antes: con
`@UUID` en NULL el bloque de idempotencia ni se ejecuta. Verificado contra la
base cerrando dos OT sin uuid dentro de una transacción revertida, y comprobado
que varias OT cerradas por la web conviven con `otr_cierre_uuid` en NULL gracias
al índice filtrado.

**Ojo:** hoy **ninguna página de la intranet llama a `UPD_ORDEN_TRABAJO_CERRAR`**
— el SP existe y la pantalla web de cierre todavía no está construida. Lo que
está garantizado es que el contrato del SP no cambió para ella.

### Lo verificado

| Prueba | Resultado |
|---|---|
| Compilar la API (MSBuild) | ✅ 0 errores |
| `flutter analyze lib` | ✅ *No issues found!* |
| `auditar_rutas.py` | ✅ sin desajustes — **98** rutas (eran 96) |
| `auditar_sp.py` | ✅ sin desajustes — **67** SP (eran 65) |
| Doble llamada al SP con el mismo uuid, en transacción revertida | ✅ misma respuesta, historial **sin duplicar** |
| Sin uuid sobre una OT ya cerrada | ✅ rechaza, como debe |
| Usuario sin `CERRAR OT` (Marcela, 7) | ✅ rechazado por el SP |
| Motivo inexistente | ✅ rechazado por el SP |
| Cierre por la web (sin `@UUID`, por nombre y posicional) | ✅ intacto |
| `GET /ordenes-trabajo/motivos-cierre` por HTTP | ✅ 200 con los seis motivos |
| **Cierre de punta a punta por HTTP** | ✅ ver abajo |

### La prueba de punta a punta, corrida el 08-09-2026

Hoy había **0 OT en estado 3**. Se llegó a estado 3 **por la API**, con el flujo
real de HU-119, y no con un `UPDATE` a mano: `UPD_ORDEN_TRABAJO_FINALIZAR` no
exige ser el responsable —solo que la OT esté en estado 1 o 2— y el endpoint
pide `EJECUTAR ORDEN TRABAJO`, que Rodrigo (8) y Paula (10) tienen además de
`CERRAR OT`.

Sobre la **OT 11** («Cambio de sello mecánico»), con un `uuid` fijo:

| Paso | Quién | Resultado |
|---|---|---|
| `POST /ordenes-trabajo/11/finalizar` | Rodrigo (Jefe de Mantenimiento) | ✅ 200 · queda en 3 |
| `POST /ordenes-trabajo/11/cerrar` con `uuid` | Paula (Supervisor) | ✅ 200 · queda en 4 |
| **el mismo POST con el mismo `uuid`** | Paula | ✅ 200 · **sin fila nueva de historial** |
| el mismo POST **sin** `uuid` | Paula | ✅ 400 «La OT no esta en espera de cierre…» |
| motivo `99` | Paula | ✅ 400 «El motivo de cierre no es valido o fue deshabilitado.» |
| OT inexistente | Paula | ✅ 404 «La orden de trabajo no existe.» |

En base quedó `otr_orden_trabajo_estado = 4`, `otr_cierre_motivo = 1`,
`otr_usuario_cierre = 10`, `otr_cierre_uuid` grabado, y el historial con
**exactamente una** fila por transición: 1 → 2 → 3 → 4. Ése es el punto entero
del script 189: el reintento del outbox devolvió 200 sin duplicar nada.

Todos los errores llegan con el **mensaje del SP tal cual** y `esDeNegocio:true`,
que es lo que la pantalla de Pendientes muestra. Los cuatro caen en
`[400, 403, 404, 422]`, así que el outbox los marca **rechazados y no los
reintenta** — correcto: ninguno se arregla reintentando.

**Las dos cosas que la prueba dejó a la vista, ya corregidas:**

- **La OT 11 volvió a como estaba.** Se restauró a estado 2, con
  `otr_cierre_motivo`, `otr_usuario_cierre`, `otr_fecha_cierre` y
  `otr_cierre_uuid` en NULL, `otr_usuario_actualizacion` = 12 y
  `otr_fecha_actualizacion` = `2026-09-07 19:45:13.777`; y se borraron las dos
  filas de historial que creó la prueba (`oeh_id` 10 y 11). El conteo de OT por
  estado quedó idéntico al del inicio: dos en 1 y dos en 2. **Vuelve a haber 0
  OT en estado 3**, así que quien repita la prueba tiene que finalizar una otra
  vez —y ya no hace falta un `UPDATE` a mano: se llega por la API, ver arriba—.

- **Un motivo inválido ahora responde 400 y no 404.** El arreglo fue **el texto
  del `RAISERROR`, no `ErrorSql`**: aquel traduce a 404 todo mensaje que
  contenga «no existe», y ese traductor lo comparten unos 150 SP —cambiarlo
  para arreglar un endpoint habría movido el código de respuesta de toda la
  API—. El mensaje pasó a «El motivo de cierre no es valido o fue
  deshabilitado.», que cae en el 400 que le corresponde a un valor de campo
  rechazado. La distinción que ahora respeta la respuesta: **un recurso ausente
  es 404 —`/ordenes-trabajo/999999/cerrar` lo sigue siendo— y un campo inválido
  del cuerpo es 400.** El cambio está en `BD/189`, que se volvió a aplicar.

El 403 del endpoint para quien **no** tiene `CERRAR OT` no se probó por HTTP: de
los usuarios que entran con `Sigma2026`, todos lo tienen. La regla sí está
verificada contra el SP (Marcela, 7 → rechazada), y `ExigirPermiso` es el mismo
helper que usan los demás endpoints.

### El cierre ahora funciona sin señal — `BD/190`

La primera versión encolaba bien offline, pero **pedía los motivos por red**.
Sin conexión la hoja no mostraba ningún chip y no se podía cerrar: el encolado
offline no sirve de nada si no se puede llegar a él, y el cierre es justo una
acción de terreno. Los tipos y estados de permiso ya tenían esto resuelto
bajando en el bloque 8 de la sábana; los motivos ahora bajan en el **bloque 9,
`ORDENES_TRABAJO`**, con la misma forma.

- `BD/190_APP_SABANA_MOTIVO_CIERRE.sql` agrega la línea al manifiesto y el
  `IF (@TIPO = 9)`. **Se generó parcheando la definición viva del SP**, no
  reescribiéndola: son 19.000 caracteres y retipearlos es la forma más fácil de
  perder un bloque por el camino.
- El bloque va **sin `@DESDE`**: son seis filas, y el incremental se las
  saltaría en toda sincronización posterior a la primera, dejando la hoja vacía
  justo en el teléfono que ya venía sincronizado.
- `SigmaRepository.motivosCierre()` pasó a `_conRespaldo`.

**Dos trampas que costaron encontrar y quedaron con prueba:**

1. **La entidad se llama `ORDENES_TRABAJO`, sin `_0`.** La sincronización
   numera con sufijo solo los bloques de **varios** resultados; el de uno se
   guarda con el código pelado. Equivocarse no rompe nada —`CacheDatos.lista`
   devuelve vacío— así que la hoja se habría visto sin motivos sin decir por
   qué. Hay tres tests nuevos en `cache_datos_test.dart` que fijan esa regla.
2. **`SincronizacionController` tenía el rango `tipo > 8` escrito a mano.** El
   manifiesto lo arma el SP y el rango vivía en C#: dos verdades sobre lo
   mismo. Con el bloque 9 anunciado y rechazado con 400, la app lo marcaba
   fallido — y como la fecha de corte **solo se guarda si ningún bloque falla**,
   se habría roto el incremental de *todos* los demás. Ahora es la constante
   `BLOQUE_MAXIMO`, con el comentario que ata las dos mitades.

Verificado por HTTP: el manifiesto declara 9 bloques, **los nueve bajan**, el 9
trae un solo resultado con los seis motivos, y el 10 sigue rechazado.

### Limpieza: código que hacía creer que la app hacía algo que no hace

`flutter analyze` no avisa de un método público ni de un provider que nadie llama.
Nace `auditar_muertos.py` para verlo, y con él se limpió esto:

**Borrado — tres métodos que se saltaban la cola.** `registrarLectura`,
`registrarMedicion` y `registrarMovimiento` hacían `POST` directo a endpoints que
las pantallas **ya encolan** (`captura_screen` y `hoja_ajuste` usan el outbox).
No eran solo código sin usar: eran una trampa. El próximo que llamara a
`registrarLectura` perdía la captura sin señal sin enterarse, contra la
convención 4 —*toda captura de terreno se encola*—.

**Borrado — ocho providers que nadie observaba.** `areas`, `catalogos`,
`repuestos`, `repuesto`, `lotes`, `bodegas`, `movimientos` y `estadosPermiso`. Un
provider existe para que la UI lo observe; sin observadores no es deuda, es
sobra. Borrarlos **no dejó huérfanos** los métodos del repositorio de `areas`,
`catalogos`, `repuestos`, `bodegas` ni `movimientos`: esos se usan desde otro
lado.

**Los cuatro métodos sin pantalla ya la tienen.** Se marcaron primero como
deuda conocida y después se construyeron sus pantallas — ver §3.1. La auditoría
quedó en **cero** métodos sin uso y **cero** providers sin observadores.

**Un falso positivo que vale la pena conocer.** La auditoría marca
`subirEvidencia` por hacer `POST` directo a `/evidencias`, que también se encola.
Es deliberado: `sigma_evidencia.dart` intenta subir la foto para que aparezca al
instante y **solo encola si falla la red** —un 403 no mejora reintentando—. La
auditoría ahora lo distingue: lo que hay que borrar es el método que además no
llama nadie.

**Queda anotado, sin tocar:** `ambitoOrdenesProvider` se observa pero **nadie lo
escribe**, así que `ordenesTrabajoProvider` siempre pide ámbito 1. Los chips de
la bandeja filtran en el teléfono y «Disponibles» tiene su propio provider, así
que no hay defecto visible — pero el ámbito 3, *todas mis plantas*, no se puede
alcanzar desde la interfaz.

### 3.1 · Las cuatro pantallas que faltaban

Los cuatro métodos que la auditoría marcó «sin pantalla» ya no lo están.

**HU-110 · Abrir una correctiva desde terreno** —
`lib/screens/ordenes/nueva_orden_screen.dart`, con botón flotante en la bandeja
bajo `CREAR ORDEN TRABAJO`. Título, detalle, prioridad del catálogo, **cuándo
pasó** (no cuándo se escribe: de esa diferencia salen el MTTR y la detención),
si necesita permiso, y los pasos uno por línea. Encola con el `uuid` nacido al
abrir. La fecha no se deja mover al futuro.

**La otra mitad de compartir** — la alerta de trabajo compartido **no llevaba a
ninguna parte**: el tipo `COMPARTIDO` tenía `alt_ficha_id_columna` en NULL, así
que `FICHA_ID` salía nulo y la tarjeta se dibujaba sin botón. `BD/191` lo apunta
a `ale_orden_trabajo` — es un arreglo de **datos**, como corresponde—, y la
tarjeta suma «Sumarme», que **intenta y encola si falla la red**, igual que las
fotos. `alt_ficha_link` se queda en NULL a propósito: es la ruta de la intranet
y la página web de la OT no existe; la app distingue por `alt_codigo`.

**Filtro por estado en los permisos** — segunda fila de chips que sale de
`Permiso_Trabajo_Estado`, cruzada con los chips de arriba en vez de
reemplazarlos: «qué de lo que vence hoy ya está firmado» es la pregunta útil.
Solo se dibujan los estados que tienen algo. Filtra por **código** y no por id,
porque `GET /permisos-trabajo` no devuelve el id del estado.

**Ficha del repuesto (10.3)** —
`lib/screens/inventario/ficha_repuesto_screen.dart`: un repuesto, todas sus
bodegas y sus lotes, con el vencido arriba. El listado de existencias es una
fila **por bodega**; esta pantalla da vuelta la pregunta. Su entrada es un botón
propio y no el toque de la tarjeta: ahí tocar ya significa ajustar, y meterle un
paso al conteo del pasillo sería empeorar el uso de todos los días.

### Dos defectos que aparecieron al construirlas

**1. Los valores de catálogo llegaban vacíos.** `GET /catalogo-valores` devuelve
`valor_id` y `valor_nombre` —las propiedades de `CatalogoValorDto`— y
`CatalogoValor.fromJson` leía `ctv_id` y `ctv_nombre`, que son las **columnas**.
Cada valor llegaba con id 0 y nombre vacío.

No era un problema de la pantalla nueva: **el selector de estado del activo
(HU-038) llevaba pintando filas en blanco**, y como todas comparaban `0 == 0`,
ninguna se podía elegir. Lo mismo la severidad de la bitácora. Es el mismo
desajuste que borró el teléfono en `MiPerfilEdicionDto` y la misma regla —*los
nombres del cuerpo son los del DTO, no los de la columna*—. Corregido leyendo
`valor_*` con `ctv_*` de respaldo, con tres tests que lo fijan.

**2. `crearOrdenTrabajo` se borró, no se usó.** La pantalla encola, así que el
método quedó sin llamador **y** haciendo POST directo a un endpoint que la app
encola: exactamente la trampa por la que se borraron `registrarLectura` y sus
dos hermanos. El comentario que lo justificaba —«queda para quien lo necesite en
línea»— era la racionalización que la auditoría existe para rechazar, así que se
aplicó la regla propia y se borró.

### Los valores de catálogo ya viajan en la sábana — `BD/192`

Era lo que quedaba anotado, y era lo que más bloqueaba: el bloque 3 bajaba las
**cabeceras** de los catálogos y ningún valor, y `valoresDe()` no tenía respaldo
en disco. Sin señal, toda hoja de chips de catálogo se quedaba sin opciones —y
en dos casos eso **impide capturar**: cambiar el estado de un activo (HU-038) y
la severidad de la bitácora, las dos hechas delante del equipo—.

El bloque 3 devuelve ahora un segundo resultado con los valores de **todos** los
catálogos, cada fila con su `CATALOGO_CODIGO`. Verificado por HTTP: 82 cabeceras
y **539 valores**, y los nueve bloques siguen bajando.

- **Es SQL dinámico porque no hay una tabla de valores.** Viven en las 81 que
  declara `Catalogo.ctl_tabla`, cada una con su prefijo; el SP recorre el
  catálogo y las une, mirando `sys.columns` para las columnas opcionales
  —`_orden`, `_cliente`— igual que hace `SEL_CATALOGO_VALOR` para uno solo.
- **Bajan todos, no solo los tres que hoy se usan.** Son 539 filas contra los
  veinte activos del bloque 4. Traer solo los de hoy obligaría a tocar el SP —y
  a publicar la app— cada vez que una pantalla nueva use un catálogo.
- **`valoresDe()` filtra por `CATALOGO_CODIGO` al leer del disco.** Por la red no
  hace falta: el endpoint ya devuelve uno solo.

**La trampa que estaba anotada, y que efectivamente había que sortear:** el
bloque 3 pasó de uno a dos resultados, así que su primer resultado dejó de
llamarse `CATALOGOS` y pasó a `CATALOGOS_0`. `CacheDatos.catalogos` se actualizó
en el mismo cambio; de no hacerlo habría devuelto vacío **sin fallar**. Hay un
test que fija los dos nombres.

### Y una que apareció al hacerlo: los .sql entraban como ANSI

Al extraer el SP para parchearlo se vio que decía `seÃ±al` donde el script
decía «señal», y `4 Â· ACTIVOS` donde decía `4 · ACTIVOS`. **sqlcmd venía leyendo
los `.sql` UTF-8 como ANSI**, así que todo acento de los comentarios lleva
tiempo guardándose mal —no es de esta sesión—.

Es cosmético mientras nadie lea el SP desde la base, y deja de serlo justo
cuando alguien lo hace, que es lo que se estaba haciendo. El texto se reparó al
regenerar el 192, y de aquí en adelante:

```bash
sqlcmd ... -i C:\Capstone\_scratch\NNN.sql -f 65001
```

`-f 65001` le dice a sqlcmd que el archivo es UTF-8. Sin eso —o sin BOM— los
acentos entran rotos y nada avisa.

### Un arreglo que no estaba en el plan: la API estaba caída

Antes de poder probar nada, **todas las rutas respondían 500 con cuerpo vacío**,
incluida la raíz. No era el código nuevo: `API.csproj` seguía apuntando al
paquete `Microsoft.Bcl.Memory` **9.0.0** (ensamblado `9.0.0.0`) mientras
`packages.config` y el `bindingRedirect` de `Web.config` ya decían **9.0.14**
(`9.0.0.14`). Cada compilación copiaba a `bin` la DLL que el redirect rechaza, y
el grupo de aplicaciones no arrancaba —`ConfigurationErrorsException` en el
registro de eventos—. Es la advertencia `MSB3277` que la compilación venía
mostrando. Corregida la referencia a `9.0.14`, el conflicto desaparece y el
sitio vuelve.

**Lección:** `MSB3277` no es ruido. Compilar sin errores no significa que el
sitio levante, porque el enlace de ensamblados ocurre al arrancar y no al
compilar. Después de compilar conviene pedir una ruta cualquiera.

### Datos que sirven para probar

- **Cerrar OT en el cliente 1:** pueden 1, 2, 3, 8 (Rodrigo, Jefe de
  Mantenimiento), 9 y 10 (Paula, Supervisor). **No** pueden 7, 11, 12 y 13.
- **Entran con `Sigma2026`:** `rodrigo.quezada@hamburgo.cl`,
  `emilio.fuentes@hamburgo.cl`, `paula.barriga@hamburgo.cl`.
- **Estados de la OT:** 1 ABIERTA · 2 EN EJECUCIÓN · 3 EN ESPERA DE CIERRE ·
  4 CERRADA. **Motivos:** 1 Trabajo realizado · 2 Sin hallazgo · 3 Resuelta en
  otra OT · 4 Duplicada · 5 Anulada por error de registro · 6 No aplica.
- **`sqlcmd` necesita `SET QUOTED_IDENTIFIER ON`** para escribir en
  `Orden_Trabajo`: el índice filtrado nuevo lo exige y sqlcmd por omisión lo
  trae apagado. Los scripts de `BD/` ya lo ponen; una consulta suelta, no.

---

## 3.1.5 · DEFECTOS ABIERTOS — empezar por aquí

Reportados por Bryan probando la app el 08-09-2026 y **reproducidos por HTTP**.
Ninguno está arreglado. El primero explica la mayoría.

---

### 1 · El `@ID OUTPUT` que ocho SP no declaran — nueve endpoints caídos

**Es el defecto grande.** `Datos.Ejecutar(sp, params, devuelveId: true)` agrega
un parámetro que **no está en el diccionario**:

```csharp
cmd.Parameters.Add("@ID", SqlDbType.Int).Direction = ParameterDirection.Output;
```

Si el SP no lo declara, SQL Server responde `@ID is not a parameter for
procedure X` —o `has too many arguments specified`— y `ErrorSql` lo traduce a un
**400 con ese texto técnico**. La pantalla muestra el error y **la acción no se
hace**.

`PATRON_SP.md` línea 139 ya lo exige: «`@ID INT = NULL OUTPUT` **siempre
primero**». Así que **el SP es el que incumple, no el controller**: el arreglo es
agregar el parámetro y `SET @ID = SCOPE_IDENTITY()`, no quitar el `true`.

| SP | Qué rompe |
|---|---|
| `API_INS_ORDEN_TRABAJO` | **Crear OT correctiva** (HU-110, la pantalla nueva) |
| `API_INS_ORDEN_TRABAJO_MANO_OBRA` | **Registrar mi tiempo**, **Sumar compañero** y **Sumarme** a un trabajo compartido |
| `API_INS_BITACORA` | **Escribir en la bitácora** |
| `API_INS_BITACORA_COMENTARIO` | **Comentar** una entrada |
| `API_INS_BITACORA_RECTIFICACION` | **Rectificar** una entrada |
| `API_INS_EVIDENCIA` | **Subir cualquier foto de evidencia** |
| `API_INS_CHECKLIST_EJECUCION` | **Empezar una pauta** |
| `API_INS_TAREA_COMENTARIO` | **Comentar una tarea** |

Verificado por HTTP, textual:

```
POST /ordenes-trabajo        -> 400 "@ID is not a parameter for procedure API_INS_ORDEN_TRABAJO."
POST /bitacora               -> 400 "@ID is not a parameter for procedure API_INS_BITACORA."
POST /bitacora/1/comentarios -> 400 "@ID is not a parameter for procedure API_INS_BITACORA_COMENTARIO."
POST /bitacora/1/rectificaciones -> 400 "... API_INS_BITACORA_RECTIFICACION has too many arguments specified."
POST /ordenes-trabajo/11/mano-obra -> 400 "@ID is not a parameter for procedure API_INS_ORDEN_TRABAJO_MANO_OBRA."
```

**Por qué ninguna auditoría lo veía.** `auditar_sp.py` cruza los parámetros del
`Dictionary` contra `sys.parameters`, y `@ID` **no está en el diccionario**: lo
agrega `Datos.Ejecutar`. Compila, `flutter analyze` pasa, las tres auditorías
salen limpias, y el endpoint responde 400. Solo se ve llamándolo.

Nace **`C:\Capstone\_scratch\auditar_id_output.py`**, que lo cruza y los
lista. **Correrla es obligatorio antes de dar cualquier bloque por cerrado**, y
tiene que quedar en cero.

---

### 2 · Consumir repuesto: falta la ubicación

```
POST /ordenes-trabajo/11/repuestos -> 400
  "ESTA BODEGA TIENE UBICACIONES: INDIQUE DE CUAL SALE O A CUAL ENTRA."
```

`HojaRepuesto` no pregunta la ubicación y `OrdenTrabajoRepuestoAltaDto.ubicacion`
va en null. En una bodega con ubicaciones —la 12 de Renca lo es— **el consumo
falla siempre**.

`GET /bodegas/{id}/ubicaciones` **ya existe y nadie lo llama**. La hoja tiene que
pedirla cuando la bodega la exija. No hay que inventar el endpoint, hay que usarlo.

---

### 3 · Los chips de la bandeja se desbordan 81 px — «los tabs internos no funcionan»

En `ordenes_screen.dart`, la fila `Hoy / Mías / Disponibles / ★ Míos` es un `Row`
fijo. Con el cuarto chip **se desborda 81 píxeles** (franja amarilla y negra en
pantalla) y ese chip **queda inalcanzable**: por eso «★ Míos» no responde.

La cabecera de `MiTrabajoScreen` sí está bien —es un `ListView` horizontal—, así
que el problema es solo el de dentro de cada pestaña. Revisar también los chips
de `permisos_trabajo_screen.dart`, que son otro `Row` fijo.

---

### 4 · Favoritos: la estrella se guarda y la pantalla no se entera

La API funciona —`POST /favoritos` alterna y responde `es_favorito`, probado— y
`_EstrellaState` actualiza su estado local. Pero **no invalida
`ordenesTrabajoProvider`**, así que la lista sigue con el `ES_FAVORITO` viejo: el
contador del chip «★ Míos» no cambia y la orden no aparece al filtrar. Se ve
encendida y no sirve para nada hasta recargar a mano.

---

### 5 · `ScaffoldMessenger` usado con el widget ya desmontado

`entrada_bitacora_screen.dart:64` revienta con *Looking up a deactivated widget's
ancestor is unsafe* después del `await`. El `mensajero` se captura antes, que es
correcto, pero **se usa sin comprobar `mounted`** al volver. El patrón que ya usa
el resto de la app —`if (!mounted) return;` antes de tocar la UI— falta aquí.
Barrer las demás pantallas buscando lo mismo.

---

### 6 · Tres botones que no hacen nada

Bryan pidió que **ninguna acción quede sin hacer algo**:

- `existencias_screen.dart:210` — micrófono: «El dictado por voz llega más adelante».
- `permisos_trabajo_screen.dart:292` — micrófono: lo mismo.
- `login_screen.dart:238` — «El acceso biométrico llega más adelante».

El dictado **ya está resuelto** en `mostrarPanelVoz` + `InterpreteVoz` y se usa
en media app: los dos micrófonos de búsqueda son cablearlos, no construirlos. El
biométrico sí es una decisión: o se implementa o se quita el botón.

---

### 7 · «Más»: menús repetidos, y la causa exacta

> «tengo menus repetidos, hagamoslo mas corporativo y mas intuitivo»

`mas_screen.dart` arma dos secciones desde el **mismo** menú del servidor:

| Sección | De dónde sale |
|---|---|
| **Trabajo** | `_conRuta(menu, rutasApp.keys)` — toda ruta del menú que la app sabe abrir |
| **Mi menú** | `extra` — las que **no** están en `yaVisible` |

`yaVisible` —inicio, escaneo, alertas, permisos, órdenes, tareas, pautas y
bitácora— **solo se aplica a `extra`**, no a «Trabajo». De ahí salen las dos
repeticiones:

1. **`extra` ⊆ `_conRuta(...)`**, así que **todo lo de «Mi menú» aparece también
   en «Trabajo»**. Son dos filas para el mismo destino, una debajo de la otra.
2. «Trabajo» además repite lo que **ya está en la barra inferior** (Inicio,
   Escanear, Alertas) y lo que ya está dentro de **«Mi trabajo»** (órdenes,
   tareas, pautas, bitácora).

El comentario del código dice la intención correcta —«lo que ya tiene su sitio
en la barra o en la rejilla no se repite acá»— pero **el filtro no se aplica
donde debía**. Arreglar la duplicación es aplicar `yaVisible` también a
«Trabajo»; ahí las dos secciones dejan de solaparse y «Mi menú» pasa a ser lo
que su nombre dice.

**Sobre lo corporativo e intuitivo**, que es la otra mitad del encargo: una vez
quitada la repetición, «Más» queda con tres bloques —quién soy y dónde estoy,
el trabajo que no cabe en la barra, y este teléfono—. Vale la pena revisarlo con
Bryan antes de rediseñar: «más corporativo» puede querer decir la marca más
presente (logo, color de cabecera), o puede querer decir agrupar por módulo como
la intranet. **Son dos pantallas distintas y conviene preguntarlo**, no
adivinarlo — el resto del encargo sí es objetivo y se puede hacer ya.

---

## 3.2 · Lo que pidió Bryan el 08-09-2026, para la próxima sesión

Cuatro encargos. **Nada de esto está construido**: lo que sigue es el
levantamiento hecho contra el código y la base ese día, para que quien lo tome
no tenga que repetirlo.

---

### A · Bitácora y Tareas: cargar audio, imágenes y video al Blob Storage

> «en bitacora deben poder cargar audios a blobstorage, imagenes, videos» ·
> «lo mismo en tareas»

**Lo que ya existe y sirve.** `POST /evidencias` sube el archivo al Blob y deja
la fila y el vínculo en una sola llamada, es idempotente por `uuid` y el blob va
antes que la fila. `sigma_evidencia.dart` ya lo usa para fotos, con el patrón
«intenta y si falla la **red** encola». `Archivo_Vinculo` es polimórfica y **ya
tiene la columna `avi_bitacora`**: el modelo de datos no hay que tocarlo.

**Lo que falta, en orden:**

1. **`EvidenciasController.PermisoDe` no conoce `BITACORA`.** Hoy tiene TAREA,
   ORDEN, PASO, RESPUESTA, HALLAZGO, FALLA y ACTIVO; un `POST /evidencias` con
   `destino=BITACORA` responde **400**. Agregar
   `{ "BITACORA", "REGISTRAR BITACORA" }` — ése es el código de permiso que ya
   usa `BitacoraController` para escribir.
2. **`API_INS_EVIDENCIA` tampoco lo mapea.** Su `@DESTINO` documenta
   `TAREA | ORDEN | PASO | RESPUESTA | FALLA | HALLAZGO | ACTIVO`. Hay que
   sumar la rama que escribe `avi_bitacora`. La columna existe; falta el `CASE`.
3. **`Extension(mime)` solo entiende imágenes.** Mapea png/webp/heic y **todo lo
   demás cae en `jpg`**: un audio se guardaría como `.m4a` renombrado a `.jpg`.
   Hay que agregar audio (`audio/mp4`→m4a, `audio/aac`, `audio/mpeg`→mp3,
   `audio/ogg`, `audio/wav`) y video (`video/mp4`, `video/quicktime`→mov,
   `video/webm`, `video/3gpp`), y **rechazar el mime desconocido** en vez de
   inventarle una extensión.
4. **El tope de 12 MB es para fotos, y su comentario lo dice**: «corta el envío
   accidental de un video, que este camino no sabe manejar». Hay que separarlo
   por tipo — foto 12 MB, audio 25 MB, video 60 MB es un punto de partida
   razonable— **y entender la limitación real**: el contenido viaja en
   `contenido_base64` dentro del JSON, así que un video de 40 MB son ~54 MB de
   texto que además se guardan en una fila del outbox en SQLite. La forma
   correcta de acotarlo no es solo el tope del servidor sino **limitar la
   captura**: `image_picker` acepta `maxDuration` y calidad media al grabar.
   Si más adelante hacen falta videos largos, eso ya no es este camino: es una
   subida por partes, y eso cambia el contrato y el outbox.
5. **App.** `sigma_evidencia.dart` es hoy solo-foto. Video sale del
   `image_picker` que **ya está en el `pubspec`**; el audio necesita paquete
   nuevo (`record` es el estándar) más el permiso `RECORD_AUDIO` en el
   manifiesto de Android. Después, colgar el widget en
   `nueva_entrada_screen.dart` y `entrada_bitacora_screen.dart`, y revisar el
   de tareas para que ofrezca los tres.

---

### B · Sumar compañero: quiénes, con foto, agrupados y con los minutos a mano

> «en sumar compañero deben cargar los de perfil tipo tecnicos de mantenimiento
> muestra sus imagenes de usuario y ademas su especialidad debes mostrarla y
> agrupar por especialidades» · «en el cuanto estuvo que se ingrese manual ya
> que qué pasa si estuvo mas de 4 horas?»

**Hoy `API_SEL_APP_COMPANERO` devuelve a TODOS** los usuarios habilitados de la
instalación, sin filtrar por perfil. Devuelve `PERFIL_NOMBRE`, `ESPECIALIDADES`
y `ESPECIALIDAD_IDS`, y **no devuelve foto**.

1. **Filtrar por perfil.** Los ids reales son: **4** Bodeguero, **5** Jefe de
   Mantenimiento, **11** Planificador de Mantenimiento, **12** Supervisor de
   Mantenimiento, **13** Técnico de Mantenimiento. Conviene un parámetro
   `@PERFILES` (lista) y no una lista escrita dentro del SP, porque las dos
   hojas piden conjuntos distintos (ver C).
2. **La foto existe en la base**: `Usuario.usu_foto` y `usu_archivo_foto`. El SP
   no las devuelve. El camino ya está resuelto para activos —`ACTIVO_FOTO` viaja
   como **ruta de blob** y `SigmaImagen`/`ImagenService` la baja, deduplica y
   cachea—; hay que hacer lo mismo aquí. `Companero.iniciales` ya existe y sirve
   de respaldo cuando no hay foto.
3. **Agrupar por especialidad.** Ojo: **`Usuario_Especialidad` tiene 0 filas**.
   Mientras no se carguen desde la web, cualquier agrupación por especialidad
   sale vacía y la pantalla se verá igual que hoy. **Es un bloqueante de datos,
   no de código** — el mismo que ya afecta al badge «Compatible» del repuesto.
4. **Hay un defecto que impide que las especialidades se lean siquiera hoy.** El
   SP concatena con el separador `N' Â· '` —mojibake— y la app parte por
   `' · '` (`hojas_recursos.dart:90`). **Nunca calzan**, así que los chips de
   oficio no aparecerían aunque hubiera datos. Es la misma familia del
   `sqlcmd`-lee-ANSI de §3: al corregir el SP hay que aplicarlo con `-f 65001`.
5. **Los minutos, a mano.** Hoy son cuatro chips fijos —30, 60, 120 y 240— y
   `_minutos = 60` por omisión (`hojas_recursos.dart:194`). La pregunta de
   Bryan es exacta: **más de 4 horas no se puede registrar**. Hay que dejar
   escribir la cantidad. Dos límites que el campo tiene que respetar porque el
   SP los hace cumplir: `API_INS_ORDEN_TRABAJO_MANO_OBRA` **rechaza 0 o
   negativo** y **rechaza más de 1440 minutos** (24 h, «un tramo de 30 horas es
   un error de fecha»). Conviene avisarlo en la pantalla antes de enviar, como
   ya hace la vigencia al revés del permiso.

---

### C · Compartir: mismo conjunto de perfiles, agrupado por perfil y especialidad

> «en el compartir lo mismo deben ser entre tecnicos de mantenimiento,
> planificador de mantenimiento, supervisor de mantenimiento… y deben estar
> agrupados por perfil y por especialidad» · «y igual incluye al bodeguero» ·
> «en compartir y en sumar compañero»

**Las dos hojas beben del mismo sitio**: `HojaCompartir` y `HojaCompanero` usan
`companerosProvider` → `SigmaRepository.companeros()` →
`API_SEL_APP_COMPANERO`. Así que el filtro por perfil, la foto y el
agrupamiento se hacen **una vez** en el SP y sirven para las dos.

- **Compartir:** Técnico (13), Planificador (11), Supervisor (12) **y Bodeguero
  (4)**.
- **Agrupar por perfil y por especialidad** en las dos hojas.

**Decisión ya tomada por Bryan (08-09-2026), no volver a preguntarla:** los
perfiles son **Técnico de Mantenimiento (13), Bodeguero (4), Planificador (11) y
Supervisor (12)**, y valen **para las dos hojas** —compartir y sumar compañero—.
En las dos hay que mostrar la **foto del usuario** y su **especialidad**, y
agrupar por **perfil y especialidad**.

### D · Lo que estas tres tienen en común

Los tres encargos tocan `API_SEL_APP_COMPANERO` o `API_INS_EVIDENCIA`, los dos
SP que ya están escritos y probados. **Ninguno necesita tabla nueva.** Lo que
falta es: un parámetro de perfiles, dos columnas de foto en el SELECT, una rama
de `@DESTINO`, un mapa de mimes y un campo de texto. El trabajo grande de verdad
es el de la app —grabar audio y video— y el bloqueante real es de **datos**:
`Usuario_Especialidad` vacía.

---

## 4. Lo demás que queda pendiente

### Push / notificaciones (HU-077) — falta **solo el lado Flutter**

`POST` y `DELETE /dispositivos` son los únicos endpoints de escritura que la app
no llama. `firebase` aparece solo como **comentario** en `pubspec.yaml:35`, no
hay `google-services.json` y el token nunca se registra. Sin esto, compartir un
trabajo y las alertas dirigidas solo se ven si el usuario abre la app por su
cuenta.

**El servidor, en cambio, está completo** —conviene saberlo antes de estimar—:

| Pieza | Estado |
|---|---|
| Tabla `Usuario_App_Dispositivo` | ✅ existe (`uad_fcm_token`, `uad_dispositivo`, `uad_activo`) |
| `API_UPS_USUARIO_APP_DISPOSITIVO` | ✅ MERGE por token: el aparato compartido cambia de dueño, no queda en los dos |
| `DEL_USUARIO_APP_DISPOSITIVO` | ✅ el DELETE al cerrar sesión **no es opcional**: si no, el siguiente que use el teléfono recibe las alertas del anterior |
| `SEL_..._INSTALACION` y `SEL_..._USUARIO` | ✅ a quién notificar |
| `DispositivosController` | ✅ exige usuario y no permiso, a propósito: quien todavía no tiene permisos asignados es justo a quien hay que avisarle |

Así que HU-077 es **FCM en el cliente**, no un bloque de base y API.

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
