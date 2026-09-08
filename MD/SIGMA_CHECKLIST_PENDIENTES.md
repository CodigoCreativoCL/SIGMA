# SIGMA — Checklist de pendientes

**Abierto:** 08-09-2026 · **Rama:** `BryanChavez`

Todo lo encargado, en el orden en que conviene hacerlo. Marcar con `[x]` al
cerrar cada punto, y **solo** cuando esté verificado por HTTP o en la app, no
cuando compile.

Regla para todos: **ningún botón ni acción puede quedar sin hacer algo.**

---

## Bloque 0 — Cerrado

- [x] **Nueve endpoints respondían 400.** Ocho SP no declaraban `@ID OUTPUT`.
  `BD/193`, aplicado. Los ocho ejercitados por HTTP: bitácora, comentario,
  rectificación, OT, mano de obra, comentario de tarea, evidencia y pauta.
  `auditar_id_output.py` en cero.

---

## Bloque 1 — Defectos abiertos (§3.1.5 del traspaso) — CERRADO

Van primero porque son cosas rotas, no cosas nuevas.

- [x] **1.1 · Consumir repuesto falla por la ubicación.** Hecho. La hoja pide
  el estante **solo cuando la bodega tiene**, y el botón no responde hasta
  elegirlo: más vale que no se pueda enviar a que el servidor lo rechace
  después de llenarlo todo. Probado por HTTP contra la bodega 12: sin
  ubicación → 400; con la 28 → `{"otr_id":14}`.

- [x] **1.2 · Los chips de la bandeja se desbordan 81 px.** Hecho: fila
  scrollable en órdenes y en permisos.
  `ordenes_screen.dart`: `Row` fijo → el cuarto chip («★ Míos») queda
  inalcanzable. Por eso «los tabs internos no funcionan». Pasar a scrollable.
  Revisar también `permisos_trabajo_screen.dart`, que es otro `Row` fijo.

- [x] **1.3 · Favoritos se guarda y la pantalla no se entera.** Hecho con
  `favoritosLocalesProvider`: el contador y el filtro se enteran sin
  reordenar la lista bajo el dedo.
  Falta invalidar `ordenesTrabajoProvider` tras alternar: el contador del chip
  y el filtro siguen con el `ES_FAVORITO` viejo.

- [x] **1.4 · `ScaffoldMessenger` con el widget desmontado.** Hecho y barrido:
  `barrer_mounted.py` pasó de 59 candidatos a cero.
  `entrada_bitacora_screen.dart:64` revienta tras el `await`. Falta
  `if (!mounted) return;`. **Barrer todas las pantallas** buscando lo mismo.

- [x] **1.5 · Tres botones inertes.** Los dos micrófonos, cableados a
  `mostrarPanelVoz`. El biométrico, **quitado**: no era cableable —falta
  `local_auth` y, sobre todo, decidir qué se guarda en el teléfono para
  reabrir la sesión con la huella, que no es una decisión técnica. Ya no queda
  ningún botón que se disculpe en toda la app.

- [x] **1.6 · «Más»: menús repetidos.** Hecho. La sección «Trabajo» era
  `_conRuta` **sin filtrar** —las 10 rutas—, así que repetía las 6 de la barra
  y la bandeja **y** las 4 de «Mi menú». Se elimina, y `yaVisible` suma
  `mi-perfil` y `sincronizacion`, que ya tienen su sitio en esta misma
  pantalla. «Mi menú» queda con 2 filas y ninguna repetida: SIGMA AI y
  Existencias.
  *(El rediseño «más corporativo» sigue en el bloque 5: hay que preguntarlo.)*

---

## Bloque 2 — QR y escaneo — CERRADO

Encargo del 08-09-2026. **Son dos defectos distintos con una causa común.**

- [x] **2.1 · El QR de la web lleva una URL, y debe llevar el código.** Hecho:
  `GenerarQr(item.Token)`. La intranet compila con `aspnet_compiler`, 0 errores.
  `EtiquetaController.GetEtiquetas` hace `GenerarQr(urlBase + item.Token)`. Debe
  generar **solo el token** (`ACT-33`, `REP-12`, `UBI-17`, `BOD-4`), que es lo
  que la app sabe leer. **Aplica a todas las etiquetas**, no solo a activos.
  *Lo que ya está bien y no hay que tocar:* `Interpretar()` —en la web y en la
  API— acepta las dos formas, así que las etiquetas ya impresas con URL siguen
  funcionando. El cambio es solo en lo que se genera de aquí en adelante.

- [x] **2.2 · Escanear un activo no abre su ficha.** Hecho, y eran **dos**
  causas: la API rechazaba `ACT`, y la app comparaba los tipos contra palabras
  completas cuando el servidor manda tres letras — así que **ningún** escaneo
  abría nada, tampoco los repuestos. Los cuatro tipos probados por HTTP.
  **Causa raíz encontrada:** `SEL_ETIQUETA` sí emite tokens `ACT-<id>`, pero
  `EscaneoController.Resolver` solo tiene rama para `UBI` y `BOD`; **todo lo
  demás cae en `SEL_REPUESTO_DESGLOSE`**. Un `ACT-33` termina consultando el
  repuesto 33 — otra cosa distinta, o ninguna.
  Falta: rama `ACT` en el controller, y que la app abra la ficha del activo en
  vez de la hoja de desglose. La pantalla roja es el segundo síntoma: hay que
  reproducirla y arreglar la excepción, no solo el enrutado.

---

## Bloque 3 — Permisos por perfil (transversal) — CERRADO

> «no deben llegarle alertas al técnico de tipo bodega de inventario. Lo mismo
> con el bodeguero: no deben llegarle notificaciones de OT. Lo mismo con los
> menús: al jefe de mantenimiento un CRUD de repuestos no puede hacerlo,
> movimientos tampoco, solo el bodeguero. **Respetar esos permisos debe
> aplicarse en todo.**»

Es una regla transversal, no una pantalla. Va antes que las mejoras porque
cambia qué ve cada quien.

- [x] **3.1 · Alertas filtradas por perfil.** Hecho en `BD/194` y `BD/195`. Que `GET /alertas` no devuelva
  alertas de inventario a quien no tiene permiso de inventario, ni de OT a quien
  no tiene el de OT. **En el servidor**, no ocultando en la app: ocultar en el
  cliente deja el dato viajando.

- [x] **3.2 · Menús por permiso.** El jefe y el planificador pierden el CRUD de
  repuestos y los movimientos; el menú «Movimientos» pasa a exigir GESTIONAR
  STOCK. Verificado: los tres perfiles reciben **403** al intentar un ajuste. Revisar `Menus` y `Menu_Perfil` contra lo que
  cada perfil puede hacer de verdad. El CRUD de repuestos y los movimientos de
  inventario son del bodeguero.

- [x] **3.3 · Barrido.** El menú de la app ya es dirigido por datos
  (`mnu_permiso`) y difiere por perfil sin tocar código. Una vez definida la regla, comprobarla en toda pantalla
  que liste algo: bandeja, existencias, alertas, «Más» y la rejilla del Home.

**Resuelto el 08-09-2026:** el jefe **ve pero no toca**. Conserva VER
EXISTENCIAS y VER REPUESTOS —planificar sin saber si hay repuestos es planificar
a ciegas— y pierde CREAR EDITAR REPUESTOS, AJUSTAR INVENTARIO, GESTIONAR STOCK,
REGISTRAR INGRESO REPUESTO y ENTREGAR REPUESTO. Lo mismo el planificador.

---

## Bloque 4 — Lo levantado el 08-09 (§3.2 del traspaso)

- [x] **4.1 · Sumar compañero.** Hecho: filtro por perfil en el SP (`BD/196`),
  avatar con foto o iniciales, agrupado por oficio —perfil de respaldo— y campo
  de minutos con aviso de los dos límites que el SP hace cumplir (0 y 1440).

- [x] **4.2 · Compartir.** Hecho, con la misma función de agrupamiento y el
  mismo avatar.

- [x] **4.3 · Resolver 4.1 y 4.2 una sola vez.** Hecho:
  `SigmaRepository.perfilesDeTerreno`, `Companero.grupo` y
  `agruparCompaneros()` son una sola fuente para las dos hojas.

- [ ] **4.4 · Bitácora y Tareas: audio, imágenes y video al Blob Storage.**

---

## Bloque 5 — Imagen y avatar

- [ ] **5.1 · La card de SIGMA AI en el Home no muestra la foto del activo.**

- [ ] **5.2 · En alertas debe verse la foto del activo, repuesto o componente**,
  y si no hay, un icono como respaldo.

- [x] **5.3 · El avatar del usuario: foto, y si no hay, las iniciales estilo
  Teams.** Hecho en `SgAvatar`, con color estable por persona. `BD/197` y
  `GET /mi-perfil` traen la ruta del blob; los cinco sitios donde aparece el
  avatar la pasan cuando la tienen.

- [ ] **5.4 · «Más» más corporativo e intuitivo.**
  **Preguntar antes de rediseñar.** «Más corporativo» puede ser la marca más
  presente (logo, color de cabecera) o agrupar por módulo como la intranet: son
  dos pantallas distintas.

---

## Antes de dar cualquier bloque por cerrado

- [ ] MSBuild → 0 errores, **y después pedir una ruta**: compilar sin errores no
      significa que el sitio levante.
- [ ] `flutter analyze lib` limpio.
- [ ] `flutter test` — hoy 78 verdes.
- [ ] Las **cuatro** auditorías de `C:\Capstone\_scratch\`: `auditar_rutas.py`,
      `auditar_sp.py`, `auditar_muertos.py`, `auditar_id_output.py`.
- [ ] Probar por HTTP contra `http://192.168.1.38/SIGMA/Servicio/API`.
      Entran con `Sigma2026`: `rodrigo.quezada@hamburgo.cl`,
      `paula.barriga@hamburgo.cl`, `emilio.fuentes@hamburgo.cl`.
- [ ] Actualizar `MD/SIGMA_APP_ESTADO.md` y `MD/SIGMA_TRASPASO_SESION.md`.
- [ ] **No** hacer push a `master` ni a las ramas de Emilio y Catalina sin que
      Bryan lo pida.

---

## Más atrás en la cola

No se han olvidado; están fuera de este encargo hasta que Bryan diga.

- Push / notificaciones (HU-077): falta solo el lado Flutter.
- Diseño v3: 14 vistas sin construir (§4 del traspaso).
- `Repuesto_Compatibilidad` y `Usuario_Especialidad` están vacías: el código
  está hecho, pero sin datos el badge «Compatible» y los chips de especialidad
  no aparecen nunca. **Se cargan desde la web, no programando.**
