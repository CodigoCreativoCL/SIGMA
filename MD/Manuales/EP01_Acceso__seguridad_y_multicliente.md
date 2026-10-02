# EP-01 · Acceso, seguridad y multicliente

> Que cada persona entre a SIGMA y vea únicamente lo que le corresponde, en el cliente que le corresponde.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Reasignaciones | Comercial › Reasignaciones | Ver la reasignacion de clientes |
| Clientes | Comercial › Clientes | Ver el listado comercial de clientes |
| Perfiles | Sistema › Acceso › Perfiles | Ver el mantenedor de perfiles |
| Usuarios | Cliente › Usuarios › Usuarios | Ver los usuarios del cliente |
| Módulos | Sistema › Mantenedores › Módulos | Ver los modulos del sistema |
| Usuarios | Sistema › Acceso › Usuarios | Ver el mantenedor de usuarios |
| Privacidad | Sistema › Mantenedores › Privacidad | Ver la privacidad de modulos |
| Permisos | Cliente › Usuarios › Permisos | Ver los permisos puntuales de un usuario |
| Menús | Sistema › Acceso › Menús | Ver el mantenedor de accesos y menus |
| Mantenedor | Sistema › Acceso › Mantenedor | Ver el mantenedor de menus y funciones |
| Perfil (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Perfil (detalle) | Ver el mantenedor de perfiles |
| Usuario (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Usuario (detalle) | Ver el mantenedor de usuarios |
| Usuario paises (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Usuario paises (detalle) | Ver el mantenedor de usuarios |
| Usuario perfiles (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Usuario perfiles (detalle) | Ver el mantenedor de usuarios |
| Cliente (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Cliente (detalle) | Ver el listado comercial de clientes |
| Reasignacion (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Comercial › Reasignacion (detalle) | Ver la reasignacion de clientes |
| Menu (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Menu (detalle) | Ver el mantenedor de menus y funciones |
| Funcion de menu (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Acceso › Funcion de menu (detalle) | Ver el mantenedor de menus y funciones |
| Modulo de sistema (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Modulo de sistema (detalle) | Ver los modulos del sistema |
| Privacidad (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Privacidad (detalle) | Ver la privacidad de modulos |
| Permiso de usuario (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Cliente › Usuarios › Permiso de usuario (detalle) | Ver los permisos puntuales de un usuario |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver el listado comercial de clientes**
- **Ver el mantenedor de accesos y menus**
- **Ver el mantenedor de menus y funciones**
- **Ver el mantenedor de perfiles**
- **Ver el mantenedor de usuarios**
- **Ver la privacidad de modulos**
- **Ver la reasignacion de clientes**
- **Ver los modulos del sistema**
- **Ver los permisos puntuales de un usuario**
- **Ver los usuarios del cliente**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-001` — Iniciar sesión en SIGMA
- `HU-006` — Aplicar mis permisos en la interfaz y en el servidor


## 4. Paso a paso


### HU-001 · Iniciar sesión en SIGMA

**Para qué.** Como usuario de SIGMA, ingresar con mi correo y mi contraseña, acceder al sistema con la identidad y los permisos que me corresponden.

*Web y App · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Correo electrónico | Texto (email), foco inicial | Sí | Formato de correo válido. Máximo 200 caracteres |
| Contraseña | Contraseña con botón mostrar/ocultar | Sí | Mínimo 8 caracteres |
| Mantener sesión iniciada | Casilla de verificación | No | Extiende la sesión a 30 días en el dispositivo |

**Cómo saber que quedó bien:**

1. **Credenciales válidas** — Dado que mi cuenta está habilitada Cuando ingreso correo y contraseña correctos Entonces accedo a la pantalla de inicio Y el sistema registra la fecha y hora de mi último acceso
2. **Credenciales invalidas** — Cuando ingreso una contraseña incorrecta Entonces se muestra el mensaje "Correo o contraseña incorrectos" Y el mensaje no indica cuál de los dos campos falló Y el intento queda registrado en el log de excepciones
3. **Cuenta deshabilitada** — Dado que mi cuenta fue deshabilitada Cuando ingreso credenciales correctas Entonces se muestra "Su cuenta no está habilitada. Contacte al administrador" Y no se inicia sesión
4. **Bloqueo por intentos fallidos** — Cuando fallo cinco veces consecutivas en quince minutos Entonces la cuenta se bloquea por quince minutos Y se informa el tiempo restante


### HU-006 · Aplicar mis permisos en la interfaz y en el servidor

**Para qué.** Como usuario con un perfil asignado, ver solo los menús y acciones que puedo usar, no perder tiempo en pantallas que el sistema va a rechazar.

*Web y App · Sprint 1*

**Cómo saber que quedó bien:**

1. **La acción sin permiso no se muestra** — Dado que mi perfil no incluye el permiso de cerrar órdenes de trabajo Cuando abro el detalle de una orden Entonces la acción Cerrar orden no aparece
2. **El permiso también se valida en el servidor** — Dado que mi perfil no incluye el permiso de cerrar órdenes de trabajo Cuando se invoca directamente el servicio de cierre Entonces la solicitud es rechazada con código 403 Y la orden no cambia de estado
3. **Aislamiento entre clientes** — Dado que inicie sesión en el cliente A Cuando se solicita un registro que pertenece al cliente B Entonces la solicitud es rechazada Y el resultado es idéntico a solicitar un registro inexistente El aislamiento entre clientes se prueba de forma explícita con dos clientes cargados en el ambiente de pruebas. Es criterio obligatorio de la Definición de Terminado.


### HU-002 · Seleccionar cliente cuando pertenezco a más de uno

**Para qué.** Como usuario que trabaja para más de un cliente, elegir con qué cliente voy a trabajar, no mezclar información de dos empresas distintas.

*Web y App · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Cliente | Lista desplegable con buscador | Sí | Solo clientes en los que el usuario está habilitado |

**Cómo saber que quedó bien:**

1. **Pertenezco a un solo cliente** — Cuando inicio sesión Entonces accedo directamente a la pantalla de inicio Y no se muestra el selector de cliente
2. **Pertenezco a varios clientes** — Cuando inicio sesión Entonces se muestra la lista de clientes a los que pertenezco Y debo elegir uno antes de continuar
3. **Cambiar de cliente durante la sesión** — Dado que estoy trabajando en un cliente Cuando selecciono otro cliente desde el encabezado Entonces la sesión se reinicia en el nuevo cliente Y ningún dato del cliente anterior permanece en pantalla


### HU-003 · Cerrar sesión y expirar la sesión inactiva

**Para qué.** Como usuario de SIGMA, que mi sesión se cierre cuando dejo de usar el sistema, que nadie use mi cuenta si dejo el equipo abierto en planta.

*Web y App · Sprint 1*

**Cómo saber que quedó bien:**

1. **Cierre manual** — Cuando selecciono Cerrar sesión Entonces vuelvo a la pantalla de ingreso Y el botón Atrás del navegador no permite volver a la aplicación
2. **Expiración por inactividad** — Dado que no realizo ninguna acción durante 30 minutos Entonces la sesión expira y se solicita ingresar nuevamente Y el trabajo no guardado se conserva localmente para continuar después
3. **La app conserva el trabajo pendiente** — Dado que la sesión expira en la aplicación móvil con cambios sin sincronizar Entonces los cambios permanecen en el dispositivo Y se sincronizan al volver a ingresar


### HU-007 · Otorgar un permiso puntual a un usuario

**Para qué.** Como administrador del cliente, conceder o revocar un permiso específico a una persona sin cambiar su perfil, resolver excepciones sin crear un perfil nuevo por cada caso particular.

*Web · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Usuario | Lista desplegable con buscador | Sí | Usuarios habilitados del cliente |
| Permiso | Lista desplegable agrupada por módulo | Sí | Del catálogo de permisos |
| Ámbito | Lista desplegable: Cliente / Planta / Área | Sí | Determina el alcance de la excepción |
| Planta | Lista desplegable | No | Plantas del cliente |
| Efecto | Botones de opción: Concede / Deniega | Sí | Denegar prevalece sobre el permiso del perfil |
| Vigente hasta | Selector de fecha | No | Vacío significa sin vencimiento |
| Motivo | Texto multilinea | Sí | Mínimo 10 caracteres |

**Cómo saber que quedó bien:**

1. **Conceder una excepción** — Cuando concedo a un técnico el permiso de cerrar órdenes en una planta Entonces ese permiso aplica solo en esa planta Y queda registrado quién lo concedió y en qué fecha
2. **Revocar una excepción** — Cuando revoco el permiso Entonces el usuario vuelve a lo que define su perfil Y la revocación queda registrada
3. **Vigencia acotada** — Cuando concedo un permiso con fecha de término Entonces deja de aplicar automáticamente al vencer esa fecha


### HU-004 · Recuperar mi contraseña

**Para qué.** Como usuario que olvidó su contraseña, restablecerla por mi cuenta, volver a trabajar sin depender del administrador.

*Web · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Correo electrónico | Texto (email) | Sí | Formato de correo válido |
| Contraseña nueva | Contraseña | Sí | Mínimo 8 caracteres, al menos una letra y un número |
| Repetir contraseña | Contraseña | Sí | Debe coincidir con la anterior |

**Cómo saber que quedó bien:**

1. **Solicitud de recuperación** — Cuando ingreso mi correo y solicito recuperar la contraseña Entonces se envía un enlace de un solo uso con vigencia de 60 minutos Y el mensaje en pantalla es el mismo exista o no el correo
2. **Uso del enlace** — Cuando abro el enlace dentro de la vigencia Entonces puedo definir una contraseña nueva Y el enlace queda invalidado inmediatamente después de usarlo
3. **Enlace vencido** — Cuando abro un enlace de más de 60 minutos Entonces se informa que expiró y se ofrece solicitar uno nuevo


### HU-005 · Editar mi perfil y cambiar mi contraseña

**Para qué.** Como usuario de SIGMA, mantener actualizados mis datos y mi contraseña, que mis notificaciones lleguen y mi cuenta siga siendo segura.

*Web y App · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Teléfono | Texto con máscara | No | Formato +56 9 XXXX XXXX |
| Fotografía | Carga de imagen o cámara | No | JPG o PNG, máximo 2 MB |
| Idioma | Lista desplegable | Sí | Valor por defecto: el idioma del cliente |
| Contraseña actual | Contraseña | No | Debe coincidir con la registrada |
| Contraseña nueva | Contraseña | No | Mínimo 8 caracteres, distinta de las tres anteriores |

**Cómo saber que quedó bien:**

1. **Cambio de contraseña** — Cuando cambio mi contraseña Entonces se exige la contraseña actual Y la nueva no puede ser igual a ninguna de las tres anteriores
2. **Actualización de datos** — Cuando modifico mi teléfono o mi fotografía Entonces el cambio se refleja de inmediato en el encabezado


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-001 · Bloqueo por intentos fallidos** — Cuando fallo cinco veces consecutivas en quince minutos Entonces la cuenta se bloquea por quince minutos Y se informa el tiempo restante
- **HU-006 · El permiso también se valida en el servidor** — Dado que mi perfil no incluye el permiso de cerrar órdenes de trabajo Cuando se invoca directamente el servicio de cierre Entonces la solicitud es rechazada con código 403 Y la orden no cambia de estado
- **HU-006 · Aislamiento entre clientes** — Dado que inicie sesión en el cliente A Cuando se solicita un registro que pertenece al cliente B Entonces la solicitud es rechazada Y el resultado es idéntico a solicitar un registro inexistente El aislamiento entre clientes se prueba de forma explícita con dos clientes cargados en el ambiente de pruebas. Es criterio obligatorio de la Definición de Terminado.
- **HU-005 · Cambio de contraseña** — Cuando cambio mi contraseña Entonces se exige la contraseña actual Y la nueva no puede ser igual a ninguna de las tres anteriores


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
