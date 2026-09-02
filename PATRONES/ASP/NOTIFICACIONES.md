# Notificaciones y alertas

Cómo el sistema avisa lo que encuentra, y cómo agregar un aviso nuevo.

Este documento es normativo: si vas a hacer que un módulo notifique algo,
sigue esto y no inventes una tabla paralela.

---

## Lo que ya existe, y por qué no se creó nada nuevo

La tabla **`Alerta`** venía en el diseño original con diez tipos, cinco
estados y columnas para colgar el hallazgo de lo que sea —activo, medidor,
repuesto, bodega, orden de trabajo, predicción—. Estaba **vacía porque nadie
la llenaba**, no porque estuviera mal.

Una tabla nueva de "notificaciones" al lado habría terminado duplicando lo
mismo, y el día que alguien pregunte *"¿cuántos problemas abiertos hay?"*
habría dos respuestas distintas.

---

## Las tres piezas

| Pieza | Qué es | Dónde vive |
|---|---|---|
| **El hallazgo** | "Este repuesto está bajo su mínimo" | `Alerta` |
| **La lectura** | "Yo ya lo vi" | `Alerta_Lectura` |
| **El detector** | Lo que revisa y abre o cierra hallazgos | `GEN_ALERTA_*` |

### La alerta es del cliente; la lectura es de cada persona

Que un repuesto esté bajo el mínimo es **un** hecho, no uno por usuario. Pero
"no leídas" sí es de cada uno: que el jefe ya la haya visto no significa que
el bodeguero también.

Por eso `Alerta_Lectura` es una tabla aparte. Meter una marca de leído dentro
de `Alerta` obligaría a crear una fila por usuario y por hallazgo — con
cincuenta usuarios, cincuenta filas para decir una sola cosa.

### Abierta y no leída no son lo mismo

El punto rojo cuenta **lo no visto**. La bandeja muestra **lo abierto**, visto
o no.

Una alerta puede seguir abierta y ya vista: el bodeguero la leyó y está
pidiendo el repuesto. Si el contador mostrara lo abierto, no bajaría nunca, y
un badge que nunca baja deja de significar "mira esto" y pasa a ser decoración.

---

## Quién ve qué: el permiso, no una lista de destinatarios

Cada **tipo** de alerta declara en `alt_permiso` qué permiso hay que tener
para verla. Las consultas filtran con `FNC_USUARIO_TIENE_PERMISO`.

La alternativa —guardar destinatarios por alerta— obliga a decidir a quién
avisar **en el momento de detectar**, y ese día el organigrama todavía no
cambió. Con el permiso, cuando alguien entra al perfil de bodeguero ve las
alertas de bodega sin que nadie tenga que reasignar nada.

---

## El detector es idempotente, y cierra lo que ya no pasa

`GEN_ALERTA_INVENTARIO` se puede correr cada cinco minutos:

- Si el hallazgo sigue abierto, **no crea otro**.
- Si la condición dejó de cumplirse —alguien repuso el stock— la **cierra
  sola**, marcándola `RESUELTA`.

Lo segundo no es opcional. Una bandeja que solo acumula deja de leerse a la
semana.

**No se borra, se marca resuelta**: quien pregunte "¿cuántas veces nos
quedamos sin este repuesto?" necesita que la historia siga ahí.

---

## Dos destinos, y son distintos a propósito

| Columna | Apunta a | Para qué |
|---|---|---|
| `alt_menu_link` | Una **pantalla** | El número del menú lateral: "las tres son de Existencias" |
| `alt_ficha_link` | Un **registro** | Lo que se abre al tocar la notificación |

Al tocar una notificación se abre **el registro**, en el `RadWindow` del
master. Llevar al listado sería avisar y después hacer buscar, que es la mitad
del trabajo: la persona tendría que volver a encontrar el repuesto que la
notificación acaba de nombrarle.

Se abre en ventana modal y **no navegando** porque quien mira las
notificaciones está *en* otra pantalla; sacarlo de ahí le hace perder lo que
estaba haciendo.

### De qué columna sale el id

`Alerta` cuelga el hallazgo de columnas distintas según el tipo. En vez de un
`CASE` repartido por cada consulta, **el tipo declara su columna** en
`alt_ficha_id_columna`, y `SEL_ALERTA` resuelve `FICHA_ID`.

Así la web y la app no repiten la misma regla en dos idiomas.

---

## Cómo agregar un aviso nuevo

Ejemplo: avisar que una orden de trabajo lleva más de N días sin cerrar.

### 1. El tipo

```sql
INSERT INTO Alerta_Tipo (alt_codigo, alt_nombre, alt_orden, alt_habilitado)
VALUES ('OT ATRASADA', 'Orden de trabajo atrasada', 13, 1)

UPDATE t
SET    t.alt_permiso           = (SELECT prm_id FROM Permiso WHERE prm_codigo = 'VER ORDENES'),
       t.alt_icono             = 'mdi mdi-clock-alert-outline',
       t.alt_menu_link         = '~/View/Ordenes/Ordenes.aspx',
       t.alt_ficha_link        = '~/View/Ordenes/Orden.aspx',
       t.alt_ficha_id_columna  = 'ale_orden_trabajo'
FROM   Alerta_Tipo t
WHERE  t.alt_codigo = 'OT ATRASADA'
```

Si la columna que necesitas no está en el `CASE` de `SEL_ALERTA`, agrégala
ahí: es el único sitio donde vive esa traducción.

### 2. El detector

Escribe `GEN_ALERTA_ORDENES` copiando la forma de `GEN_ALERTA_INVENTARIO`:

1. Una tabla temporal `#HALLAZGO` con lo que **hoy** está mal.
2. `INSERT` de lo que falta —con `NOT EXISTS` contra las abiertas, para no
   duplicar—.
3. `UPDATE` a `RESUELTA` de lo abierto que **ya no** está en `#HALLAZGO`.

El paso 3 es el que suele olvidarse, y es el que decide si la bandeja sirve.

### 3. Llamarlo

`AlertaController.Detectar()` es donde se encadenan los detectores. Agrega el
tuyo ahí.

### 4. Nada más

No toques el panel, el menú, el CSS ni el modelo. El panel dibuja lo que
`SEL_ALERTA` devuelva, y el badge del menú sale de `alt_menu_link`. Ese es el
punto de que el catálogo esté en la base.

---

## Severidad: la decide el detector, el color lo decide la pantalla

`ale_severidad` usa el catálogo `Severidad` (NORMAL, BAJA, ADVERTENCIA, ALTA,
CRÍTICA). El SP guarda **cuán grave es**; el CSS decide **de qué color se ve**.

La traducción vive en `Default.master.cs` → `Severidad()`, y no en el SP,
porque la app va a pintar lo mismo de otra manera.

Lo que ordena la bandeja es la severidad, no el módulo: lo que decide si algo
se mira ahora es la gravedad, no de dónde viene.

---

## Lo que falta

- **El SVG de la marca**, en `.sg-notif-ilustracion` del panel vacío. El
  contenedor ya centra y acota a 140px de alto; el `<svg>` solo necesita su
  `viewBox` y medidas al 100%.
- **La app** todavía no consume nada de esto. Cuando lo haga, el endpoint
  natural es `GET /alertas` y `GET /alertas/resumen`, reusando `SEL_ALERTA` y
  `SEL_ALERTA_RESUMEN` tal como están.
- **Solo hay detector de inventario.** Activos, órdenes de trabajo,
  checklists y planes tienen sus tipos declarados en `Alerta_Tipo` desde el
  diseño original, pero nadie los llena todavía.

---

## Bloques SQL

| Bloque | Qué trae |
|---|---|
| `81_NOTIFICACIONES.sql` | `alt_permiso`, `alt_icono`, `alt_menu_link`, `Alerta_Lectura`, `GEN_ALERTA_INVENTARIO`, tipos de lote |
| `82_NOTIFICACIONES_CONSULTA.sql` | `SEL_ALERTA`, `SEL_ALERTA_RESUMEN`, `UPD_ALERTA_LEER` |
| `83_NOTIFICACION_ABRE_FICHA.sql` | `alt_ficha_link`, `alt_ficha_id_columna`, `SEL_ALERTA` con `FICHA_ID` |

---

## El detector corre solo

El navegador pregunta cada minuto a `Alertas.ashx`; ese mismo llamado dispara
`GEN_ALERTA_DETECTAR`, que decide si toca correr el detector y devuelve los
contadores en la misma respuesta.

### El freno vive en la base

`Alerta_Deteccion` guarda cuándo se corrió por última vez, por cliente. El
`UPDATE` que reclama el turno es **atómico**: de dos usuarios que entren en el
mismo segundo, solo uno gana. El otro no espera ni falla, simplemente no
ejecuta.

Podría guardarse en memoria del sitio, pero eso se pierde al reciclar el
proceso y no sirve si mañana hay dos servidores: los dos creerían que les toca.

**Intervalo: 5 minutos.** Un repuesto no baja de su mínimo dos veces en ese
rato, y es corto para que quien acaba de registrar una salida vea el aviso
antes de irse de la pantalla.

### Por qué un sondeo y no algo en vivo

Un canal permanente daría el aviso en el instante, pero exige una conexión
abierta por pestaña. Para un hallazgo de inventario, saberlo un minuto después
no cambia ninguna decisión: nadie repone un rodamiento en sesenta segundos.

### Lo que el sondeo no hace

- **No pregunta en segundo plano.** Con la pestaña oculta se detiene; al volver
  pregunta de inmediato. Una pestaña olvidada un viernes no consulta la base
  todo el fin de semana.
- **Se apaga si la sesión cayó.** El handler contesta `{"sesion":false}`.
- **No inventa badges nuevos en el menú.** Solo actualiza los que ya existen:
  el indicador del módulo padre lo dibuja el servidor, y un número colgando de
  una rama que no late quedaría huérfano. Para eso hay que recargar.

`Detectar(true)` se salta el freno — lo usa el botón **Revisar ahora**: si
alguien lo aprieta es porque quiere saber en este momento.

