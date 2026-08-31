# SIGMA — Estado del desarrollo · API

> **Documento vivo.** Es el traspaso de contexto de la API entre sesiones.
> Quien la retome debería poder leer solo esto y saber cómo está construida,
> qué se decidió y por qué, y qué falta.
>
> El estado general del proyecto —base de datos, web, sprints— vive en
> [`SIGMA_ESTADO_DESARROLLO.md`](SIGMA_ESTADO_DESARROLLO.md). Este archivo no
> lo repite: lo complementa.
>
> **Regla: cada vez que se cierre un bloque de trabajo, se actualiza este
> archivo en el mismo cambio.**

**Última actualización:** 30-08-2026
**Estado:** construida y compilando · **no probada contra la base**

---

## 1. Qué es y dónde está

La API REST de SIGMA. Es la puerta por la que va a entrar la **app móvil**, y
la que va a usar cualquier integración externa.

| | |
|---|---|
| **Proyecto** | `C:\Capstone\SIGMA\Solucion\SIGMA\API` |
| **Solución** | `C:\Capstone\SIGMA\Solucion\SIGMA\SIGMA.sln` |
| **Tecnología** | ASP.NET Web API 2 (`System.Web.Http` 5.2.9) · .NET Framework 4.8 |
| **Autenticación** | JWT (`System.IdentityModel.Tokens.Jwt` 8.6.1) |
| **URL** | `http://localhost/SIGMA/Servicio/API` |
| **Base de datos** | La misma que la web · `sql5112.site4now.net` / `db_acd593_sigma` |

Es un **proyecto de aplicación**, no un Website: cada archivo nuevo hay que
agregarlo al `API.csproj` o simplemente no se compila, sin avisar.

---

## 2. Las rutas NO llevan `/api/`

La aplicación ya está publicada bajo `.../Servicio/**API**`. Poner además el
prefijo `api/` en los controllers daría:

```
http://localhost/SIGMA/Servicio/API/api/clientes     ← la palabra repetida
http://localhost/SIGMA/Servicio/API/clientes         ← lo que se usa
```

Los `RoutePrefix` van **sin** ese segmento —igual que el `AuthController`
heredado, que ya venía con `[RoutePrefix("auth")]`— y la ruta convencional de
`WebApiConfig` se cambió a `{controller}/{id}`.

> En el Sprint Backlog las tareas dicen "GET /api/clientes". Eso **nombra el
> recurso**, no el segmento de la URL. La ruta real es la de arriba.

---

## 3. Cómo está construida

```
API/
├── Controllers/          los endpoints, uno por recurso
│   └── Token/            AuthController: la cuenta de servicio (heredado)
├── MVC/Model/Dto.cs      los DTOs de entrada y salida
├── Utils/                lo transversal
│   ├── ApiBase.cs        base de todos los controllers
│   ├── ErrorSql.cs       RAISERROR → código HTTP
│   ├── Datos.cs          SP → DTO
│   ├── Pagina.cs         paginación
│   ├── CacheCorta.cs     caché de 60 s
│   ├── SesionApi.cs      quién llama, según el token
│   ├── TokenGenerator.cs firma los JWT
│   └── Conexion.cs       acceso a SQL (heredado)
└── App_Start/WebApiConfig.cs
```

### Lo transversal, resuelto una vez y no quince

Las 55 tareas de API del Sprint 1 repetían las mismas cuatro frases en cada
historia: "traduce el error del SP", "DTO sin exponer columnas internas",
"con filtros y paginación", "caché corta". Escribirlas quince veces significa
arreglarlas quince veces.

| Pieza | Qué resuelve |
|---|---|
| **`ErrorSql`** | Traduce el `RAISERROR` de un SP a su código HTTP con mensaje legible |
| **`ApiBase`** | El `try` que envuelve cada endpoint, el 404, `ExigirUsuario` / `ExigirCliente` / `ExigirCuerpo`, y el 201 con `Location` |
| **`Datos`** | Ejecuta el SP y mapea a DTO por reflexión |
| **`Pagina` / `Paginado<T>`** | Página, tamaño con tope, filtro y total |
| **`CacheCorta`** | Caché de 60 s con clave por usuario y cliente |
| **`SesionApi`** | El usuario y el cliente, leídos del token |

---

## 4. Endpoints

33, en 13 controllers. Qué cubre y qué **no** cubre lo decide
[`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md): solo lo que hacen en terreno
los seis perfiles móviles.

```
POST   /sesion                                HU-001  inicia sesión, devuelve JWT
                                                      pasa @AMBITO = 2: el perfil
                                                      de solo web no entra acá
GET    /sesion                                        quién soy según el token
DELETE /sesion                                HU-003  cerrar sesión

GET    /cliente-usuarios/mis-clientes         HU-002  a qué clientes pertenezco
POST   /cliente-usuarios/seleccionar          HU-002  elegir → token nuevo

GET    /menus                                 HU-006  el árbol de la app, por permiso
GET    /usuario-permisos                      HU-006  mis permisos (caché 60 s)
GET    /usuario-permisos/tengo/{codigo}       HU-006  ¿tengo este permiso?

GET,PUT /mi-perfil                            HU-005
POST   /mi-perfil/password                    HU-005  exige la clave actual

POST   /usuario-recuperaciones                HU-004  pedir el enlace
POST   /usuario-recuperaciones/restablecer    HU-004  usarlo

-- lectura de referencia: lo que baja al dispositivo en HU-150 (Sprint 2).
-- La escritura de estos tres es del Administrador del Cliente, desde la web.

GET    /cliente-instalaciones                 HU-011  plantas
GET    /cliente-instalaciones/{id}
GET    /instalacion-areas                     HU-012  áreas
GET    /instalacion-areas/{id}
GET    /catalogos                             HU-020  el registro de catálogos
GET    /catalogos/{codigo}/valores            HU-020  los valores de uno
GET    /catalogo-valores                      HU-021
GET    /catalogo-valores/{id}

-- INVENTARIO · el modulo del bodeguero (Sprint 3, bloques 60 y 61)

GET    /existencias                            HU-056  cuanto hay y donde esta
                                                       ?alerta=true -> solo lo que
                                                       esta fuera de umbral
GET    /existencias/repuesto/{id}              HU-056  todas sus bodegas, sin paginar
POST   /inventario-movimientos                 HU-054  ingreso
                                               HU-055  entrega y devolucion
                                               HU-057  ajuste, traslado y merma
GET    /inventario-movimientos                 HU-057  historial, con FAMILIA
GET    /inventario-movimientos/{id}
GET    /repuestos                              HU-050  lectura de referencia (E2)
GET    /repuestos/{id}
GET    /repuestos/{id}/lotes                   HU-054  solo los vigentes
GET    /bodegas                                HU-052  lectura de referencia (E2)
GET    /bodegas/{id}
GET    /bodegas/{id}/ubicaciones               HU-052
```

**Un solo POST para las tres historias de movimiento.** Del lado de la base
son el mismo procedimiento con distinto tipo, y partirlo en la API crearía
tres caminos que pueden divergir contra uno que no puede. El **permiso sí
depende del tipo** y se resuelve antes de llamar al SP: entregar no es
ajustar, y no todos los que entregan deberían poder corregir el conteo.

**Es idempotente por `uuid`**, que lo genera el teléfono al *encolar* el
movimiento, no al enviarlo: generado al enviar, cada reintento traería uno
nuevo y la idempotencia no serviría de nada. Probado — dos llamadas con el
mismo uuid devuelven el mismo id y el saldo se mueve una sola vez.

**`/existencias` no se cachea, a propósito.** Es el dato que no puede estar
viejo: un técnico que baja a buscar una pieza que ya no está perdió el viaje.
Lo que sí viaja es `isa_fecha_ultimo_movimiento`, con la que la app puede
decir *de cuándo* es lo que muestra sin conexión (HU-056 CA2).

### Lo que ya no está

`/clientes`, `/perfiles`, `/centros-costo`, `/grupo-trabajos`,
`/usuario-especialidades`, `/cliente-usuario-permisos`, el CRUD de
`/cliente-usuarios`, las escrituras de plantas, áreas y catálogos, y el
`ValuesController` de la plantilla —que respondía en `.../API/values`—.

Retirados el 31-08-2026 a `_RETIRADO/API/`, con su `LEEME.md`. No estaban
rotos: no los consumía nadie. La web llama a los SP directo y esas historias
son del Administrador del Cliente, que trabaja desde la web.

**Antes de agregar un endpoint nuevo, comprobar contra el documento de alcance
que alguno de los seis perfiles lo va a llamar.** Es la comprobación que no se
hizo el 30-08 y costó 251 tareas de backlog.

**Parámetros comunes de todo listado:** `?pagina=1&tamano=50&filtro=texto`.

---

## 5. Decisiones tomadas y su motivo

Esto es lo que más se pierde entre sesiones.

### El usuario y el cliente salen del token, nunca de un parámetro

Sería más cómodo aceptar `?usuario=7` y pasarlo al SP. También permitiría que
cualquiera con un token válido operara **como cualquier otro** cambiando un
número en la URL, y que la auditoría de cada tabla —`usu_usuario_creacion` y
compañía— registrara a quien el propio atacante dijera ser.

El cliente en contexto va en el token por la misma razón: SIGMA es
multicliente y casi toda consulta se acota por cliente. Cambiarlo exige
emitir otro token (`POST /cliente-usuarios/seleccionar`), que **revalida la
pertenencia contra la base** sin confiar en el id que llega.

> `/clientes` es el único recurso que no se acota así: lista los clientes
> mismos, y `SEL_CLIENTE` decide qué ve cada persona por `@USUARIO`. Pedirle
> un cliente seleccionado a quien todavía no eligió ninguno haría imposible
> dar de alta el primero.

### El token no lleva los permisos

Dura ocho horas; los permisos cambian antes. Incrustarlos significaría que
revocar uno no surte efecto hasta que la persona vuelva a entrar — que es
**exactamente el error que se acaba de corregir en el sitio web**, donde los
permisos vivían en `Session` sin caducidad.

Se consultan, con caché de 60 segundos.

### Por qué la caché dura un minuto

Porque lo que se cachea son **permisos**. Un permiso revocado tiene que dejar
de valer pronto, y "pronto" no puede depender de que la persona cierre
sesión. Un minuto ahorra la ráfaga de peticiones de una navegación —la app
consulta permisos antes de pintar cada pantalla— y es lo bastante corto para
que una revocación no quede colgando.

La clave incluye **siempre** usuario y cliente. Una caché de permisos con la
clave mal armada le entrega los permisos de una persona a otra, y ese es el
tipo de error que nadie nota hasta que alguien ve lo que no debía.

### La severidad 16 es la frontera entre "regla" y "falla"

Todas las reglas de negocio de SIGMA viven en los SPs y se comunican con
`RAISERROR(..., 16, 1)`. `ErrorSql` usa esa severidad para dividir:

| | |
|---|---|
| **Severidad 16** | Regla de negocio prevista. El **texto** decide el código: `YA EXISTE` → 409 · `BLOQUEAD` → 423 · `NO TIENE PERMISO` / `NO PERTENECE` → 403 · `NO EXISTE` → 404 · cualquier otra → 400 |
| **Cualquier otra** | Falla de infraestructura → 500 con **texto genérico** |

Sacar el código del texto no es elegante. La alternativa —un catálogo de
códigos por SP— hay que mantenerla sincronizada con 150 procedimientos, y el
día que se desincronice mentirá con más seguridad que esto.

**El detalle de un 500 no viaja al cliente.** Nombres de tablas, de columnas
y de servidores son justo lo que sirve para atacar la base; quedan en el log
del servidor, que es donde hacen falta.

También busca la `SqlException` recorriendo `InnerException`: los controllers
heredados relanzan con `new Exception(ex.Message)` y pierden el tipo. Sin
eso, toda regla de negocio que pasara por uno de ellos se vería como un 500.

### El NULL se resuelve una vez, en `Datos`

El sitio web escribe el bucle de lectura columna por columna en cada
controller, y ahí es donde se coló el error **que ya costó tiempo tres
veces**: `int.Parse()` sobre una columna que admite NULL lanza
`FormatException` y voltea la pantalla.

`Datos` mapea por reflexión —la propiedad del DTO se llama igual que la
columna, que es lo que ya exige el patrón del grupo— y si la columna viene
nula y la propiedad no admite nulos, deja el valor por defecto en vez de
reventar. Una vez, para las quince entidades.

### La sesión de la API dura 8 horas y la de la web 30 minutos

A propósito. Un técnico en planta no puede quedar fuera a mitad de una orden
de trabajo por dejar el teléfono en el bolsillo. El riesgo es distinto: un
computador olvidado en una oficina, contra un teléfono con clave en el
bolsillo de su dueño.

### Cerrar sesión no borra nada, y el endpoint existe igual

El JWT no se guarda: se firma y se valida en cada petición. No hay una fila
que marcar como cerrada, así que cerrar sesión es que el cliente deje de
mandar el token.

`DELETE /sesion` no es decorativo: le da a la app un lugar donde avisar, deja
la acción registrada, y el día que haya lista de revocación se implementa ahí
**sin que la app cambie una línea**.

### La paginación se hace en memoria, y tiene fecha de vencimiento

Los `SEL_` no reciben `OFFSET`/`FETCH`: son los mismos que consume la web y
cambiarles la firma obligaría a tocar controllers ya probados. Se trae el
conjunto y se recorta en `Paginado<T>`.

Con los volúmenes del Sprint 1 —decenas de plantas, cientos de usuarios— es
correcto y barato. **Cuando entren activos y órdenes de trabajo, esos `SEL_`
necesitan paginar en SQL.**

El tope de 200 por página sí se aplica siempre: un listado sin tope funciona
perfecto en desarrollo con diez filas y deja el teléfono colgado el día que
el cliente tiene cuarenta mil activos.

### `DELETE` es baja lógica, siempre

Donde no hay `DEL_` —grupos de trabajo, permisos puntuales, valores de
catálogo— se usa el `UPD_` con `habilitado = 0`. No es un atajo: es lo que el
estándar del grupo pide para tablas maestro, y lo que evita que un registro
con historial deje ese historial apuntando a nada.

### La recuperación de contraseña responde igual exista o no el correo

Siempre 200 con el mismo mensaje (HU-004 escenario 1). Si la respuesta
cambiara, este endpoint sería una forma de **averiguar qué correos están
registrados** probándolos de a uno, sin credenciales y sin límite.

El token es de 32 bytes de `RNGCryptoServiceProvider` —no de `Random`, que se
siembra con el reloj y haría adivinable el token sabiendo la hora— y **no se
devuelve en la respuesta**: viaja por correo y solo por correo. Devolverlo
convertiría "pedir recuperación" en "obtener acceso".

### Cuatro SPs no existían

Las firmas se verificaron una a una contra `sys.parameters` en vez de
suponerlas. De ahí salieron cuatro que el nombre esperado no encontraba:

| Esperado | Real |
|---|---|
| `SEL_PERFIL` | **`SEL_PERFILES`** (plural) |
| `DEL_PERFIL` | **`DEL_PERFILES`** (plural) |
| `DEL_GRUPO_TRABAJO` | no existe → baja por `UPD_GRUPO_TRABAJO` |
| `DEL_CATALOGO_VALOR` | no existe → baja por `UPD_CATALOGO_VALOR` |

El plural de perfiles es una inconsistencia heredada: `INS_` y `UPD_` están
en singular. Se respeta el nombre real en vez de "corregirlo", que rompería
la web.

---

## 6. Pendientes y cosas que hay que saber

### Bloqueantes

- **SMTP sin configurar.** `POST /usuario-recuperaciones` genera y guarda el
  token, pero el correo no sale, así que HU-004 no se puede completar. Es el
  mismo bloqueante que tiene la web.

### No verificado

- **Nada se ha ejercitado contra la base.** La API compila en `exitcode=0` y
  las firmas de los SPs están verificadas, pero compilar no es llamar.
  Empezar por `POST /sesion`: de ahí salen los tokens del resto.
- **Las 34 tareas de Pruebas y Documentación del Sprint 1 son de Catalina
  Pescio** y siguen pendientes. Ninguna historia pasa de "En revisión" hasta
  que estén.

### Deuda conocida

- **La paginación en memoria** deja de servir cuando entren activos y órdenes
  (§5).
- **`AuthController` sigue con la cuenta de servicio en `Web.config`**
  (`Username` / `Password` en texto plano). Sirve para que un sistema se
  identifique, no una persona; el login de personas es `POST /sesion`. Habría
  que decidir si esa cuenta se conserva o se retira.
- **No hay Swagger.** Está en las tareas de documentación de Catalina. El
  proyecto trae el área `HelpPage` de plantilla, sin usar.
- **No hay límite de intentos por IP** en `/sesion` ni en
  `/usuario-recuperaciones`. El bloqueo por cuenta sí existe —lo hace
  `SEL_LOGIN` a los cinco intentos— pero nada impide probar mil correos
  distintos. La IP se registra en la recuperación; falta actuar sobre ella.
- **La clave de conexión está en `Web.config` en texto plano**, igual que en
  la web.

---

## 7. Recetas

### Compilar (obligatorio antes de dar algo por terminado)

```
"C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe" "C:\Capstone\SIGMA\Solucion\SIGMA\SIGMA.sln" /t:Build /p:Configuration=Debug /v:minimal
```

Debe terminar en `exitcode=0`. Los avisos `MSB3277` sobre `System.Net.Http`
son preexistentes.

### Archivo nuevo

`API.csproj` lista los `Compile Include` uno por uno. **Un archivo que no
esté ahí no se compila y no avisa**: el endpoint simplemente no existe en
tiempo de ejecución.

```
<Compile Include="Controllers\MiControlador.cs" />
```

### Probar el login

```bash
curl -X POST http://localhost/SIGMA/Servicio/API/sesion -H "Content-Type: application/json" -d "{\"login\":\"root@codigocreativo.cl\",\"password\":\"1\"}"
```

Devuelve el `token`, que va en las demás llamadas:

```bash
curl http://localhost/SIGMA/Servicio/API/usuario-permisos -H "Authorization: Bearer <token>"
```

### Publicar una entidad nueva

1. DTO de salida y DTO de alta en `MVC/Model/Dto.cs` — **solo las columnas
   que pueden salir**, con el nombre igual al del SP.
2. Controller que herede de `ApiBase`, con `[RoutePrefix("recurso")]` **sin**
   `api/`.
3. Cada endpoint dentro de `Ejecutar(() => { ... })`, con **`ExigirPermiso("CODIGO")`**
   —el mismo código que usa la web— y `ExigirCliente()` según corresponda.
   `ExigirUsuario()` a secas solo sirve para lo propio del que llama
   (mi perfil, mis permisos, mi menú): en todo lo demás deja el endpoint
   abierto a cualquier token válido.
4. Agregarlo al `API.csproj`.
5. UTF-8 con BOM + compilar.

---

## 8. Bitácora

| Fecha | Qué se hizo |
|---|---|
| 30-08-2026 | **Nace la API del Sprint 1.** 14 controllers cubriendo las 17 historias, sobre una base transversal (`ErrorSql`, `ApiBase`, `Datos`, `Pagina`, `CacheCorta`, `SesionApi`) y JWT con usuario y cliente. Rutas sin `/api/`. Las firmas de los SPs verificadas contra `sys.parameters`; cuatro no existían. Compila en `exitcode=0`, **sin probar**. Las 55 tareas API quedan Terminada en el Sprint Backlog S1 |
| 30-08-2026 | **El alcance, y el permiso que faltaba.** [`SIGMA_ALCANCE_APP.md`](SIGMA_ALCANCE_APP.md) fija qué cubre la API: solo lo que hacen los seis perfiles de terreno. De los 14 controllers, **7 rutas son de la app**, 4 son lectura que la app necesitará desde el Sprint 2, y el resto es excedente construido para historias solo web. Hallazgo: **ningún endpoint validaba permisos** —solo `ExigirUsuario()`, o sea que el token era válido—; nace `Utils/Permisos.cs` sobre `SEL_USUARIO_PERMISOS` con caché de 60 s, más `ExigirPermiso` / `ExigirAlgunPermiso` en `ApiBase`, y quedan **52 endpoints** con el suyo, respondiendo 403. Nace `MenusController` (`GET /menus`): la navegación de la app se resuelve por datos con `SEL_MENU_APP`, igual que la web. `POST /sesion` pasa `@AMBITO = 2` y maneja 403 y 402 explícitos: el Administrador del Cliente no entra a la app y el Técnico no entra a la web |

| 31-08-2026 | **Retirados los endpoints que no van.** 7 controllers a `_RETIRADO/API/` y 4 recortados a sus `GET`: de **64 endpoints a 21**, en 9 controllers. Se fueron `/clientes`, `/perfiles`, `/centros-costo`, `/grupo-trabajos`, `/usuario-especialidades`, `/cliente-usuario-permisos`, el CRUD de `/cliente-usuarios` y el `ValuesController` de la plantilla de Visual Studio, que respondía en `.../API/values` por la ruta convencional. También los 16 DTOs que quedaron sin dueño. Nada estaba roto: no lo consumía nadie. Compila en `exitcode=0` |

| 31-08-2026 | **El modulo del bodeguero (Sprint 3).** 4 controllers nuevos: `existencias`, `inventario-movimientos`, `repuestos` y `bodegas`. Un solo POST para ingreso, entrega, devolucion, ajuste, traslado y merma, con el **permiso resuelto por tipo**. `/repuestos` y `/bodegas` van solo en lectura por la excepcion **E2** del documento de alcance: son historias solo web, pero sin leerlas la app no puede ofrecer que mover ni a donde |

### Cómo actualizar este documento

Al cerrar un bloque: agregar la fila en la bitácora, mover lo hecho de §6 a
§4 o §5, y anotar en §5 **toda decisión que un tercero no podría deducir del
código**. Esa sección es la que evita rehacer discusiones ya cerradas.
