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

## Bloque 4 — Lo levantado el 08-09 (§3.2 del traspaso) — CERRADO

- [x] **4.1 · Sumar compañero.** Hecho: filtro por perfil en el SP (`BD/196`),
  avatar con foto o iniciales, agrupado por oficio —perfil de respaldo— y campo
  de minutos con aviso de los dos límites que el SP hace cumplir (0 y 1440).

- [x] **4.2 · Compartir.** Hecho, con la misma función de agrupamiento y el
  mismo avatar.

- [x] **4.3 · Resolver 4.1 y 4.2 una sola vez.** Hecho:
  `SigmaRepository.perfilesDeTerreno`, `Companero.grupo` y
  `agruparCompaneros()` son una sola fuente para las dos hojas.

- [x] **4.4 · Bitácora y Tareas: audio, imágenes y video al Blob Storage.**
  Hecho. `BD/198` abre el destino `BITACORA` en los dos SP de evidencia
  —`avi_bitacora` ya existía—; la API acepta mimes de audio y video con un tope
  propio para video (48 MB contra 12); la app graba nota de voz (`record`, AAC
  64 kbps mono) y video (`image_picker`, 1 min). Probado por HTTP: `.m4a` y
  `.mp4` subidos a la entrada 4 y listados con su mime.

---

## Bloque 5 — Imagen y avatar — CERRADO

- [x] **5.1 · La card de SIGMA AI en el Home no muestra la foto del activo.**
  La cadena estaba bien —`/predicciones` trae `ACTIVO_FOTO` y `/archivo/ver` la
  sirve, probado—: lo que fallaba era el caso **sin** foto, que pintaba un marco
  de imagen vacío. Ahora va el icono del equipo.

- [x] **5.2 · En alertas debe verse la foto del activo, repuesto o componente**,
  y si no hay, un icono como respaldo. Hecho. `SEL_ALERTA` ya devolvía la
  identidad y **`AlertaDto` no la declaraba**, así que se tiraba en silencio;
  `BD/199` agrega además `FOTO_RUTA`. La tarjeta muestra la foto, o el icono
  del tipo, y una línea que dice de qué equipo habla.

- [x] **5.3 · El avatar del usuario: foto, y si no hay, las iniciales estilo
  Teams.** Hecho en `SgAvatar`, con color estable por persona. `BD/197` y
  `GET /mi-perfil` traen la ruta del blob; los cinco sitios donde aparece el
  avatar la pasan cuando la tienen.

- [x] **5.4 · «Más» más corporativo e intuitivo.** Resuelto el 08-09-2026:
  Bryan pidió la opción que cumpliera con el negocio. **Se descartó agrupar por
  módulo como la intranet** —la app tiene ~10 pantallas y «Mi menú» quedó con 2
  filas: encabezados de módulo sobre dos elementos son burocracia, y esa
  jerarquía resuelve un problema de escala que la app no tiene—. Se hizo lo
  otro, pero no por decoración: **el contexto pasa a protagonista**. SIGMA es
  multi-cliente y multi-planta, y registrar con la planta equivocada deja el
  dato mal en un sistema auditado. La marca va en la cabecera, el perfil a la
  vista, y «Cambiar de contexto» sube de tercera fila de «Este teléfono» a
  tarjeta propia con aviso cuando falta la planta.

---

## Bloque 6 — Reporte de Bryan del 08-09-2026 (tarde)

Probando la app. Lo que está **[x]** ya se corrigió en esta sesión; lo demás
lleva anotada la causa cuando ya la encontré, para no volver a investigarla.

---

### 6.0 · Blob Storage sin cliente — CORREGIDO

- [x] **Lo que sube la app no se guardaba a nivel de cliente.**
  La API armaba `"sigma/" + destino + "/" + archivo`; la intranet usa
  `RutaArchivo.Armar` → `sigma/0001-hamburgo-sa/<modulo>/2026/09/<archivo>`.
  Dos estructuras en el mismo contenedor, y una mezclando empresas.

  **No es orden, es aislamiento:** con el cliente arriba, un SAS acotado a un
  prefijo deja fuera a las demás empresas con una sola regla; sin él no hay
  prefijo que acotar. Nace `API/Services/RutaArchivo.cs` con la misma regla que
  la web —copiada, no referenciada: la intranet es un sitio con App_Code y la
  API un ensamblado aparte; si la regla cambia, cambia en los dos—.

  Verificado: `sigma/0001-hamburgo-sa/bitacora/2026/09/3aa3…png`.

  **Pendiente de decisión:** los archivos ya subidos con la ruta vieja siguen
  donde están y se encuentran (su ruta vive en `Archivo.arc_ruta`). Moverlos es
  una migración —copiar en Azure y actualizar la columna—. **¿Se migran?**

---

### 6.1 · Escaneo QR

- [ ] **Pantalla roja al escanear.** Reproducir y cazar la excepción. En esta
      sesión se arreglaron dos causas de que no abriera nada (rama `ACT` en la
      API y los tipos de tres letras en la app) pero **no** se llegó a ver el
      error rojo.
- [x] **No deja escanear otra vez: queda pegado lo anterior.** Corregido.
      `codigoEscaneadoProvider` es global y sobrevivía a salir de la pantalla,
      así que al volver se veía lo último leído — y como `_alDetectar` no pisa
      lo que ya hay, **la cámara quedaba muda**. Ahora se limpia al entrar, en
      un `postFrameCallback` para no escribir durante el build.
- [x] **Escanear un repuesto debe abrir la ficha del repuesto.** Corregido:
      `REP` → `FichaRepuestoScreen` y `BOD` → `FichaBodegaScreen`. `UBI` se
      queda en existencias porque su contenido ya se ve en la tarjeta del
      resultado.

---

### 6.2 · El outbox no envía — y es la causa del 6.8

- [x] **`Row too big to fit into CursorWindow`.** Corregido.
      **Causa encontrada:** `base_local_service.dart:310` hace
      `SELECT * FROM outbox … LIMIT 200`, y `*` incluye `cuerpo_json`, que
      desde que se suben fotos, audio y video contiene el base64 completo. Una
      sola fila puede pesar megas y el `CursorWindow` de Android son 2 MB.
      `pendientesDeEnvio()` (línea 300) tiene el mismo `SELECT *`, así que
      **revienta también el despachador**: por eso no sale nada de la cola.
      **Arreglo:** las dos consultas dejan de traer `cuerpo_json`
      (`_columnasLigeras`), y el despachador lo pide aparte con `cuerpoDe()`,
      que lo lee **por trozos de 256 KB con `substr`** — el límite es por FILA,
      así que pedir solo esa columna tampoco alcanzaba. El base64 sigue en la
      base a propósito: guardar solo la ruta dejaría la evidencia a merced de
      que Android limpie la caché antes de que haya señal.

---

### 6.3 · Multimedia

- [ ] **Reductor de tamaño para toda imagen.** Hoy solo lo hace `image_picker`
      al capturar (1600 px, calidad 82). Una imagen **elegida de la galería**
      pasa por el mismo camino, pero una que llegue por otra vía no. Revisar y
      dejar el reductor en un solo sitio.
- [ ] **Poder escuchar el audio** subido a una bitácora o tarea.
- [ ] **Poder reproducir el video.** Hoy la miniatura es una tarjeta con icono
      y no abre nada. Necesita dependencia de reproductor.

---

### 6.4 · Retomar la app

- [x] **Al volver no toma bien la planta y el cliente seleccionados**, y los
      datos deben recargarse siempre al retomar. Corregido.
      **Causa:** `instalacionProvider` era un `StateProvider` en memoria —su
      comentario decía que perderla al reiniciar era «un inconveniente menor»,
      y no lo era: la sábana baja **por planta**—. Ahora el id se persiste y
      `restaurar()` lo repone **comprobando contra las plantas autorizadas**:
      a alguien le pueden haber quitado una desde la web mientras la app estaba
      cerrada. Y `SgAlRetomar` envuelve la app y llama a `asegurar()` en cada
      `resumed`.
- [x] **Pantalla de carga al abrir/retomar:** logo de SIGMA con animación de
      figuras geométricas al estilo Google. Hecho: `SgCargando` dibuja el
      isotipo y un polígono que muta de 3 a 6 lados **interpolando vértices**
      —cambiar de golpe parpadea, y un parpadeo en una carga se lee como un
      error—. Se pinta, no es un GIF, para tomar el color del tema en claro y
      en oscuro. Tapa opaco: dejar la lista vieja a la vista invita a tocarla.

---

### 6.5 · Buscadores que encuentren de verdad — CERRADO

- [x] **Coincidencia tolerante.** Hecho en `lib/services/buscador.dart`:
      normaliza los dos lados —minúsculas, tildes, separadores y ceros a la
      izquierda de cada número— y exige **todos** los términos, no cualquiera.
      `ot4` encuentra `OT-04`, `OT-4`, `OT 04` y `ot/4`. Siete tests propios.
      La `ñ` **se conserva**: «caña» y «cana» son cosas distintas.
- [x] **En los cuatro:** órdenes, tareas, bitácora y pautas. Y era peor de lo
      reportado: **tareas, pautas y bitácora no tenían buscador ninguno**.
      Ahora «Mi trabajo» tiene **una sola caja arriba** que vale para las
      cuatro pestañas y para «Todo»; órdenes embebida esconde la suya y lee esa
      misma, para que la misma búsqueda no funcione en tres sitios y en uno
      no.

---

### 6.6 · Trabajar con lo del día

- [ ] **Ventana móvil de 24 h**, no «desde ayer»: si son las 21:50, lo de las
      21:50 de ayer hacia acá.
- [ ] **Agrupar los registros** con estilo tipo *fieldset*, en su versión más
      moderna.

---

### 6.7 · «Órdenes que apremian» no se entiende

- [ ] Cambiar el nombre y explicarlo. Hoy `_apremia` mezcla vencimiento y
      prioridad en un solo concepto sin decir cuál.

---

### 6.8 · La bitácora no guarda nada

- [ ] **No guarda la entrada, ni imagen, ni voz, ni video, y no aparece en su
      tab.** **Muy probablemente es el 6.2**: la entrada se encola y el
      despachador está caído por el `CursorWindow`. Arreglar 6.2 primero y
      volver a probar; si sigue, mirar el filtro del tab de bitácora.

---

### 6.9 · Favoritos y compartir sin respuesta

- [ ] **El botón de favoritos no anima.** Hoy solo cambia el ícono. Debe
      animarse o al menos cambiar de color.
- [ ] **Lo mismo el de compartir.**

---

### 6.10 · Campos obligatorios

- [ ] **Etiqueta de obligatorio** en los inputs que lo son.
- [ ] **Borde rojo** al guardar con el campo vacío. Limpio, sin gritar.

---

### 6.11 · La card de SIGMA AI

- [ ] **Convertirla en slider**, cambiando con animación sutil entre los
      análisis y las OT no finalizadas.
- [ ] **Más información de impacto** para que el usuario le haga caso.
- [ ] **Notificación al celular con sonido de predicción** cuando llegue una
      alerta nueva de SIGMA AI. *(Depende de push/FCM, HU-077.)*

---

### 6.12 · Skeletonizer

- [ ] **Mejorar el esqueleto de carga de las vistas:** limpio y moderno.

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
