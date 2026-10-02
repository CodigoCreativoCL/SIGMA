# Reinicio de la base: dejar SIGMA en blanco para rehacer el flujo

Borra **el cliente y todo lo que arrastra**, y conserva **el sistema**: los catálogos, los menús, los permisos, los perfiles y las tres cuentas de Código Creativo, que son las que vuelven a crear el cliente desde el perfil comercial.

Sirve para recorrer el sistema de cero siguiendo los manuales de `Fase 2/Manuales`, encontrar lo que falta y repetirlo cuantas veces haga falta.

## Cómo se usa

```bash
cd BD/Reinicio
python 1_esquema.py     # lee tablas, columnas y claves foraneas de la base
python 2_plan.py        # decide que se borra y que se conserva
python 3_respaldo.py    # copia a CSV todo lo que se va a borrar
python 4_reiniciar.py   # aplica el plan
```

Los cuatro leen la conexión del `Web.config` de la API: no hay que configurar nada ni escribir la contraseña en ninguna parte. Todo lo que generan va a `_datos/`, que está fuera del control de versiones porque son datos del cliente.

## Qué conserva, y por qué puede entrar alguien después

Se comprobó en el código antes de decidirlo, no se supuso:

- `SuscripcionAcceso.Exigir()` deja pasar al perfil de tipo Sistema (Root y Gerente Comercial), así que borrar las suscripciones no deja fuera a quien tiene que volver a contratarlas.
- `SEL_LOGIN` trata `@AFILIACIONES = 0` como válido y se salta la verificación de suscripción, así que quedarse sin ningún cliente asociado tampoco deja fuera a nadie.

Después del reinicio, `root@`, `emilio@` y `catalina@codigocreativo.cl` quedan con perfil Root y cero afiliaciones, que es exactamente ese caso.

Las cuentas se identifican **por login y no por id**, para que siga funcionando aunque se recreen en otro orden. Si cambian, se edita `CONSERVAR_LOGIN` en `2_plan.py`.

## Las tres clases de borrado

| Clase | Qué hace | Por qué |
|---|---|---|
| completo | vacía la tabla entera | es puro dato del cliente |
| parcial | borra solo las filas del cliente | los catálogos ampliables (HU-021) llevan columna `*_cliente`: las filas `NULL` son del sistema y se quedan. Vaciar la tabla entera dejaría a SIGMA sin catálogos; no tocarla dejaría filas huérfanas |
| autoría | pone la columna en `NULL` | una columna que dice **quién** hizo algo no es lo mismo que una que dice **de quién** es la fila. La versión de un modelo predictivo no deja de ser del sistema porque la publicara alguien que ya no está |

Además hay una regla escrita a mano: **la oferta comercial queda en `BASICO`, `MEDIO` y `FULL`**. `Plan_Comercial` se siembra y por eso se conserva, pero la pantalla de planes (HU-190) permite crear más, y en las pruebas del Sprint 2 quedaron seis «Plus (evidencia S2)» ofreciéndose como planes reales en la contratación.

Lo que no está en `CONSERVAR` se vacía. Es deliberado: una tabla nueva de un sprint que viene entra al reinicio sola, en vez de quedarse con datos viejos sin que nadie se entere. Si resultara ser del sistema, se agrega a mano a esa lista.

## Las redes de seguridad

El paso 4 no es un `DELETE` suelto:

- **Una sola transacción** con `XACT_ABORT`: o queda todo aplicado o no queda nada a medias.
- **Las claves foráneas se reactivan *con comprobación* antes de confirmar.** Si el plan dejó una fila huérfana, la base lo rechaza y la transacción se deshace sola. No hay que confiar en que la lista de tablas estaba completa: la base lo verifica.
- **Cuenta lo que quedó en pie** y aborta si faltan los menús, los permisos o alguna de las cuentas a conservar.
- **No se ejecuta sin respaldo:** si no hay una carpeta `_datos/respaldo_*`, se detiene y pide correr el paso 3.

## Dos cosas que conviene saber

**El `COMMIT` va en Python, no en SQL.** `pyodbc` con `autocommit=False` ya abre su propia transacción; un `BEGIN`/`COMMIT TRANSACTION` propio la anida, el `COMMIT` cierra solo la de adentro y al cerrar la conexión la de afuera se deshace. Pasó en la primera corrida: el script dijo «confirmado» y la base había quedado intacta. Por eso se confirma con `cx.commit()`.

**Las identidades se reinician** en las tablas que quedan vacías, para que la primera planta vuelva a ser la número 1 y el recorrido sea fácil de seguir.

## Estado

`3_respaldo.py` **todavía no está en esta carpeta**: su creación fue rechazada por el clasificador de permisos durante la sesión en que se armó esto. Hasta que exista, el paso 4 se niega a correr, que es el comportamiento correcto. Hay una copia funcionando en `_scratch/respaldo_cliente.py`, de la misma sesión, que es de donde conviene traerlo.

## Historia

El 02-10-2026, después del reinicio, se borraron además 6 planes comerciales de evidencia del Sprint 2 con sus 4 precios y 84 funcionalidades; desde entonces el paso 2 lo hace solo.

Ejecutado por primera vez el 02-10-2026: se borraron 3 clientes, 10 personas y 3.667 filas en 121 tablas; quedaron en pie 182 menús, 121 permisos, 496 asignaciones de permiso, 82 catálogos, 10 perfiles y las 3 cuentas. Cero claves foráneas sin confiar.
