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

### 6.3 · Multimedia — CERRADO

- [x] **Reductor de tamaño para toda imagen.** Y había un hueco real:
      **`recuperarPerdida()` no pasaba por él**. Cuando Android mata la app con
      la cámara abierta, `retrieveLostData` devuelve el archivo del disco del
      sistema y **no garantiza** que lleve aplicados el ancho y la calidad que
      se pidieron: una foto de cuatro megas entraba a la cola, que es
      exactamente lo que la hace pesada.

      Ahora todo pasa por `_comoEvidencia()`, con `flutter_image_compress`. Se
      comprueba antes de recomprimir —por debajo de 800 KB se deja tal cual—
      porque recomprimir un JPEG ya comprimido pierde calidad sin ganar
      tamaño. Y con `autoCorrectionAngle`, o media planta sale de lado.
- [x] **Poder escuchar el audio.** `SgReproductor`: la tarjeta de la nota de
      voz **se toca y suena**. Antes era una tarjeta muerta —decía que había una
      nota y no había forma de escucharla, que es peor que no mostrarla—.
- [x] **Poder reproducir el video.** Mismo reproductor. **Se transmite, no se
      descarga**: un video de treinta segundos son veinte megas y bajarlo
      entero antes de mostrar nada deja a la persona mirando una rueda con la
      pieza en la mano. Los dos reproductores aceptan cabeceras, así que el
      blob va con el mismo token: `/archivo/ver` valida que la ruta sea del
      cliente, y esa comprobación no se salta.

      Sin `chewie`: los controles que hacen falta son dos, y un paquete de
      controles trae pantalla completa, velocidad y subtítulos que habría que
      apagar.

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

### 6.6 · Trabajar con lo del día — CERRADO

- [x] **Ventana móvil de 24 h.** `TramoTiempo` en `sigma_fieldset.dart`, con
      cuatro tests. El caso que la justifica: a las 00:30, lo de las 23:00
      **sigue siendo de hoy** — con el día del calendario, un turno de noche ve
      desaparecer a medianoche lo que acaba de hacer.

      **Se AGRUPA, no se filtra.** Esconder lo anterior dejaría fuera una fuga
      anotada anteanoche que sigue sin resolverse, y una bitácora que oculta
      parte de su relato no sirve de bitácora. Lo reciente va primero y lo
      demás queda debajo, alcanzable.
- [x] **Agrupar los registros con estilo fieldset.** `SgFieldset`: el título
      montado sobre el canto, con el fondo detrás para que parezca que
      interrumpe el marco. El marco es **una superficie tenue, no una línea**,
      porque el v3 construye la jerarquía con superficies. Un rótulo suelto
      dice dónde empieza un grupo pero no dónde termina; el fieldset cierra.
      Aplicado a la bitácora y a las tres secciones de «Todo».

---

### 6.7 · «Órdenes que apremian» no se entiende — CERRADO

- [x] Hecho. El criterio era correcto —`SITUACION` es `VENCIDA` o `VENCE HOY`,
      y **lo decide el SP**— pero el nombre no lo decía: «apremiar» es un
      juicio, y quien lee una bandeja necesita el CRITERIO para confiar en que
      no se le queda nada fuera. Ahora los rótulos dicen la regla: «Órdenes
      vencidas o que vencen hoy», «Nada vence hoy», y el chip pasa de «Hoy»
      —que se lee como «las de hoy» y escondía las atrasadas— a «Vencen hoy».

---

### 6.8 · La bitácora no guarda nada — CERRADO

- [x] **No guarda la entrada, ni imagen, ni voz, ni video, y no aparece en su
      tab.** Eran **dos cosas**, no una.

      **La entrada:** era el 6.2. Se encolaba bien y el despachador estaba
      caído, así que nunca llegaba. Comprobado por HTTP que la API sí las
      guarda y las lista —4 entradas con `instalacion=3`, la del usuario—.

      **La multimedia:** `NuevaEntradaScreen` **no tenía dónde adjuntar nada**,
      y no era un olvido resoluble ahí: la evidencia cuelga de un id y hasta
      que el servidor lo asigna no hay de qué colgarla. Ahora al guardar se
      despacha, se esperan unos segundos al id y se abre la ficha —que sí
      tiene el bloque de foto, voz y video— con `pushReplacement`, para que
      volver atrás lleve a la bandeja y no al formulario ya enviado. Sin
      señal se dice tal cual: la entrada sale cuando vuelva la cobertura y la
      evidencia se adjunta entonces.

---

### 6.9 · Favoritos y compartir sin respuesta — CERRADO

- [x] **El botón de favoritos no anima.** Hecho con `SgPulso`: rebota al tocar
      y vibra (`selectionClick`), y la estrella entra con `AnimatedSwitcher`.
      El acuse va **antes** de la petición: confirma el gesto, no el resultado.
- [x] **Lo mismo el de compartir**, y los demás botones de vidrio de la ficha
      de OT, que usan el mismo `_Vidrio`.

---

### 6.10 · Campos obligatorios — CERRADO

- [x] **Etiqueta de obligatorio.** `SgRotuloCampo(obligatorio: true)` escribe
      la palabra, no un asterisco: en un teléfono con guantes un punto de tres
      píxeles no se ve, y la leyenda «los campos con * son obligatorios» no
      existe en esta app.
- [x] **Marca roja al guardar con el campo vacío.** Con **anillo**, no borde:
      el kit v3 dice «nada lleva borde» y marca la selección con anillo, así
      que se hace en su idioma. `SgCampo` ya lo tenía; lo que faltaba era otra
      cosa: **el botón se apagaba**, y un botón gris no dice CUÁL de los tres
      campos falta. Ahora responde siempre y al tocarlo marca lo que falta.
      Aplicado en bitácora, permiso de trabajo y ajuste de existencia.

---

### 6.11 · La card de SIGMA AI

- [x] **Convertirla en slider.** `_CarruselIa`: pasa sola cada 8 s con
      `easeInOutCubic`, y **se detiene mientras se toca** —que se mueva bajo el
      dedo es la forma más rápida de abrir la ficha equivocada—. Ocho segundos
      y no tres: hay que poder LEER la tarjeta antes de que cambie, y una que
      se va mientras se lee enseña a ignorarla. Alto fijo para que no salte
      entre páginas de distinto largo.

      Las páginas son los cuatro análisis más graves y **una de OT sin
      terminar** (estados 2 y 3, verificado contra la API): una recién abierta
      que nadie tomó no es «sin terminar», es «sin empezar».
- [x] **Más información de impacto.** Se suman el **valor actual contra el
      límite** —«82 °C de 95 °C»—, que convierte el aviso en algo comprobable
      mirando el equipo en vez de una afirmación que hay que creer, y **dónde
      está** (código y área): un plazo sin sitio obliga a buscar el activo
      antes de poder hacer nada.

      **La probabilidad se sigue sin pintar**, a propósito: no es probabilidad
      de falla sino certeza del modelo sobre su horizonte, y esa frase cabe en
      la ficha, no en una tarjeta. Un «87 %» sin la frase termina repitiéndose
      en una reunión significando otra cosa.
- [ ] **Notificación al celular con sonido de predicción** cuando llegue una
      alerta nueva de SIGMA AI. **Bloqueado por push/FCM (HU-077)**: sin el
      registro del token en `POST /dispositivos` y Firebase montado no hay por
      dónde entregarla. Es lo único de este punto que queda, y no es trabajo de
      la card sino del bloque de notificaciones.

---

### 6.12 · Skeletonizer — CERRADO

- [x] **Mejorar el esqueleto de carga.** `SgEsqueleto`: la **silueta** de lo
      que viene —cuadro de icono, título largo, subtítulo corto— con un brillo
      que barre, desfasado por fila. Eran tres rectángulos grises que decían
      «espera» y nada más; ahora la vista **no salta** al llegar los datos,
      porque lo que había ya ocupaba ese sitio. Sin paquete: `shimmer` trae su
      propio sistema de temas y acá los colores salen de los tokens del v3.

---

## Bloque 7 — Las vistas del diseño v3 que faltaban (§4 del traspaso)

De las 14 sin construir, quedan **8**. Las seis cerradas se listan con lo que
se decidió en cada una, porque la decisión es lo que no se ve en el código.

### 7.1 · Repuestos y bodegas — CERRADO

- [x] **10.2 Buscador de repuestos** (`repuestos_screen.dart`). Busca con
      `coincideBusqueda`, así que «rod 12» encuentra `ROD-0012`. Sale de la
      sábana: el catálogo ya baja al teléfono.
- [x] **10.5 Bodegas** (`bodegas_screen.dart`) y **10.6–10.8 ficha de bodega**
      (`ficha_bodega_screen.dart`): existencias, estantes y el movimiento.
- [x] **10.9–10.12 hoja de movimiento** (`hoja_movimiento.dart`), una sola hoja
      con el enum `TipoMovimiento` (ids 1/2/3/6) en vez de cuatro pantallas
      casi iguales. Cada tipo declara **su** permiso y si `resta` stock, y
      `_HojaAcciones` de la ficha del repuesto ofrece solo los movimientos que
      el perfil tiene. El bodeguero no ve «Ajuste» si no puede ajustar.
- [x] El selector de estante dejó de ser privado de una pantalla:
      `_Estante` → `SelectorEstante`, reusado por la hoja.

### 7.2 · Ficha del permiso de trabajo — CERRADO

- [x] **11.2** (`ficha_permiso_screen.dart`). El color de la cabecera lo manda
      `SITUACION`, **no** `ESTADO_CODIGO`: un permiso AUTORIZADO pero VENCIDO
      no puede leerse en verde, y el cruce estado × vigencia lo hace el SP.
      Verificado por HTTP: el permiso 10 vuelve `SOLICITADO` con situación
      `POR VENCER` y `DIAS_RESTANTES = 0` — el caso exacto que separa los dos
      campos.
- [x] No se autoriza desde el teléfono: `CK_PTR_AUTORIZADO` no deja un permiso
      autorizado sin su adjunto, y ofrecer el botón sería ofrecer un camino que
      la base rechaza. La pantalla lo dice en vez de callarlo.

### 7.3 · Equipos de la planta — CERRADO

- [x] **7.2** (`activos_screen.dart`), con filtro por área y la misma búsqueda
      tolerante. Sale de la sábana porque no hay `GET /activos` y no hace falta
      inventarlo. Si la sábana no se bajó, la lista sale vacía **y lo explica**.
- [x] `BD/201_APP_MENU_ACTIVOS.sql` aplicado: registrar la pantalla fue un
      INSERT en `Menus`, no código. El menú del jefe ya devuelve 13 rutas
      `app://`, con `activos`, `bodegas` y `repuestos`.

### 7.4 · Lo que queda (7 vistas)

Ninguna se puede construir sin decidir algo primero:

- [ ] **6.7 Firmas** (HU-118): no hay tabla ni ruta. Es diseño de base, no de
      pantalla.
- [ ] **8.1–8.4 Componentes**: sin endpoints. Cuatro vistas de una sola HU.
- [ ] **9.2 Historial de lecturas**: sin endpoint de listado.
- [ ] **7.4 / 10.4 Galerías** y **13.2 Centro de evidencias**: dependen de que
      se resuelva el 6.0 (¿se migran los blobs ya subidos con la ruta vieja?).
- [ ] **15.2 Conflicto de sincronización**: hoy el 409 se trata como éxito, así
      que la pantalla no tiene qué mostrar todavía.
### 7.5 · Accesibilidad — CERRADO salvo la lectura en voz alta

**16.2** (`accesibilidad_screen.dart` + `accesibilidad_service.dart`). Ocho de
los diez ajustes que pide la especificación, y **cada uno cambia algo de
verdad**: no hay interruptores decorativos.

- [x] **Tamaño del texto** en cuatro pasos, tope 1.5. Se aplica una sola vez en
      el `builder` de `MaterialApp`, así que vale también para lo que abre el
      `Navigator`. Se ignora el factor de Android a propósito: multiplicarlo
      con el nuestro corta texto sin que nadie entienda de dónde salió.
- [x] **Alto contraste**: `AppColors.contrastado` empuja fondo y tarjeta a los
      extremos y sube `tinta2`/`tinta3` —los metadatos al 40 % son lo primero
      que se pierde—. `SgCard` dibuja contorno, que es la única regla del v3
      («nada lleva borde») que este modo rompe, y la rompe a sabiendas: sin
      sombra visible la tarjeta se funde con el lienzo.
- [x] **Tema** claro/oscuro/auto, **mudado** desde «Mi perfil». Era el mismo
      ajuste en dos sitios.
- [x] **Movimiento reducido**, que viaja en `MediaQuery.disableAnimations` —la
      bandera que Flutter ya tiene— y no en un provider nuestro: así la miran
      también los widgets del framework, y ninguna animación se queda girando
      por olvido. Lo respetan `SgCargando` (figura quieta, y el mensaje pasa a
      ser obligatorio porque entonces es él quien dice que está trabajando),
      `SgEsqueleto` (siluetas sin barrido), `SgRadarIa`, `SgPulso` (además
      responde antes: sin rebote no hay 110 ms que esperar) y el carrusel de
      SIGMA AI, que deja de avanzar solo.
- [x] **Confirmación háptica**, con `SgPulso` consultándola antes de vibrar.
- [x] **Avisos** del teléfono, mudado también desde «Mi perfil».
- [x] **Horario de silencio**, que **cruza la medianoche** —22:00 a 07:00 es el
      caso normal, no el raro—. La regla vive en `enSilencio()`, no en el
      llamador, y tiene cuatro pruebas: una comparación ingenua callaría de día
      y sonaría de noche. Todavía no calla nada porque nada suena: lo consumirá
      HU-077.
- [x] **Persistentes por usuario**: la clave es `sigma_acc_<usuario>_<campo>` y
      se releen al entrar y al salir. El teléfono de planta pasa de turno en
      turno, y heredar la letra grande del turno anterior se lee como que la
      app se descompuso.

**Lo que quedó fuera, y por qué:** «lectura en voz alta» y «velocidad de
lectura». Exigen un motor TTS (`flutter_tts`, dependencia nueva) y, sobre todo,
**decidir qué se lee**: una OT entera no se escucha, y leer solo el título no
sirve de nada. No es trabajo de esta pantalla sino de las que leerían. Está en
la cola de abajo.

- [ ] **Lectura en voz alta y velocidad** (HU-162, la mitad que falta).

---

## Bloque 8 — Las seis vistas que faltaban del v3

Todas las que quedaban bloqueadas. **El v3 queda completo.** Base, API y app:
seis scripts (202 a 207), tres controladores y nueve pantallas.

### 8.1 · Componentes — 8.1 a 8.4 — CERRADO

- [x] `Archivo_Vinculo` tenía una columna por cada cosa a la que se cuelga un
      archivo —OT, falla, repuesto, activo— y el componente era el único que
      faltaba: la galería 8.4 **no tenía dónde existir**. Se agregó con su FK
      y un índice **filtrado**, porque casi ningún vínculo es de un componente.
- [x] `API_SEL_ACTIVO_COMPONENTE_FICHA`: instalación, lecturas, fallas, OT,
      repuestos, sustituciones y bitácora, en una sola línea de tiempo.
- [x] **No** se escribió SP nuevo para el listado ni la ficha:
      `SEL_ACTIVO_COMPONENTE` ya recibe `@ACTIVO` y `@FILTRO` y lo usa la web.
- [x] La ficha del activo ganó la pestaña **Componentes** que pedía 7.3.
- [x] Menú `app://componentes` (BD/205), para el caso que la pestaña no puede
      resolver: se tiene el código de una pieza y no se sabe de qué equipo es.

**Lo que NO trae, y por qué:** los cambios de estado del componente. El
componente guarda su estado en una columna **sin historial**, y deducirlos de
`aco_fecha_actualizacion` diría «cambio de estado» cada vez que alguien
corrigió una falta de ortografía en el nombre. Es base que falta, no pantalla.

- [ ] **Historial de estado del componente**: hace falta una tabla
      `Activo_Componente_Estado_Historial`, como la que ya tiene el activo.

### 8.2 · Historial de lecturas — 9.2 — CERRADO

- [x] `API_SEL_ACTIVO_MEDIDOR_LECTURA` calcula el incremento con `LAG()`
      **sobre la serie completa, no sobre el rango pedido**: filtrando primero,
      la primera lectura del tramo saldría sin incremento y «desde junio»
      pintaría un mes vacío que en realidad tuvo 600 horas.
- [x] Un reinicio devuelve incremento **NULL, no cero**: no se sabe cuánto
      corrió, y cero diría que no corrió.
- [x] El gráfico dibuja el **incremento** y no el acumulado —7.500 h no
      significan nada y una recta que sube tampoco— y destaca el salto que
      supera el doble del promedio, que es el «salto no razonable» de 9.1.
      Dibujado a mano: una librería de gráficos traería su tema propio a una
      app donde todo color sale de `context.sg`.
- [x] Los umbrales salen de `Programacion_Medidor` —«cada 500 h desde 0»— y no
      de una tabla de umbrales que habría que inventar. Es el umbral real del
      negocio y ya lo mantiene alguien. **Sin programación configurada la
      pantalla no dibuja líneas**: dice que no hay ninguna, que es distinto de
      decir que todo va bien.
- [x] Se llega desde el medidor del componente **y desde el activo**. Lo
      segundo lo encontró `auditar_muertos.py`: `medidoresProvider` no lo
      observaba nadie, y detrás había un hueco real —un equipo sin componentes
      no tenía ningún camino a sus lecturas—.

### 8.3 · Galerías — 7.4, 8.4 y 10.4 — CERRADO

- [x] **Una pantalla y no tres.** Las tres especificaciones piden lo mismo
      —cuadrícula cronológica, fecha, autor, observación, zoom— y solo cambia
      de dónde salen las fotos.
- [x] `API_SEL_ACTIVO_FOTO` ganó fecha de captura, autor y observación: una
      galería sin eso no responde «cómo estaba esto en marzo», que es la única
      pregunta que se le hace. Y nació su gemelo `API_SEL_REPUESTO_FOTO`.
- [x] La fecha es la de **captura**, no la de subida: en terreno se fotografía
      sin señal y se sube al volver, y ordenar por la de subida cuenta la
      historia en el orden equivocado.
- [x] Agrupa por mes. Las fotos sin fecha van en su propio grupo al final: una
      foto sin fecha no es una foto de hoy, y ponerla ahí sería inventarle una.

### 8.4 · Centro de evidencias — 13.2 — CERRADO

- [x] Responde **«¿se subieron mis fotos?»**. Hasta ahora la única forma de
      saberlo era abrir una por una las órdenes, tareas y bitácoras donde se
      sacaron.
- [x] `API_SEL_EVIDENCIA_MIAS` filtra por usuario —la vuelta al revés de
      `API_SEL_EVIDENCIA`, que filtra por destino— y devuelve el destino
      **resuelto en palabras**: «Orden de trabajo · OT-31», no «destino 412».
- [x] Las dos listas juntas: lo que falta subir y lo que ya está. Separarlas
      obligaría a mirar en dos sitios para responder una sola pregunta.
- [x] El componente pasó a ser destino válido de evidencia (BD/206): la
      galería podía **ver** fotos de una pieza y no se podía subir ninguna.

**Lo que NO tiene, y por qué:** barra de progreso por archivo. La evidencia se
manda en un solo POST con el contenido en base64 —no hay carga por trozos que
medir— y dibujar una barra que avanza sola sería inventar información. Se dice
lo que se sabe: cuánto pesa, cuántos intentos lleva y qué contestó el servidor.

Tampoco se muestra «pendiente de revisión»: `arc_archivo_antivirus_estado`
existe y `API_INS_EVIDENCIA` lo deja siempre en 1 = Pendiente, pero **no hay
proceso que lo mueva a Limpio**. Mostrarlo pondría esa alarma en el 100 % de
los archivos para siempre.

- [ ] **Antivirus de archivos**: existe la columna y el catálogo, no el
      proceso. Cuando exista, la pantalla lo pinta.

### 8.5 · Conflicto de sincronización — 15.2 — CERRADO, con una advertencia

**SIGMA no versiona registros.** No hay columna de versión ni bloqueo
optimista, así que la comparación campo a campo «versión local contra versión
del servidor» que pide la especificación **no se puede hacer sin mentir**.

Lo que sí existe, y es el conflicto real de terreno: el servidor se movió
mientras el teléfono estaba sin señal, y el envío queda **rechazado**. La
pantalla pone lo capturado frente a lo que contestó el servidor, traduce el
código a algo que se entienda —«el registro ya no existe», «una regla del
negocio lo impide»— y deja decidir.

- [x] El 409 no llega nunca a esta pantalla: es el reintento que llegó dos
      veces y la cola lo marca como enviado. Es literalmente el «no mostrar
      conflicto si los datos son equivalentes» de la especificación, resuelto
      antes de que nadie tenga que mirarlo.
- [x] Dos opciones y no tres: reintentar y descartar. **No hay «editar y
      reenviar»**: cambiar acá el valor de una lectura tomada en terreno
      convertiría el registro en algo que nadie midió, y ese registro es el que
      después se audita.
- [ ] **Decisión para Bryan:** si se quiere el diff real de dos versiones, hay
      que agregar versión o marca de tiempo a las tablas que se editan y que
      los SP de UPDATE la comprueben. Es trabajo de base y toca todo lo que se
      escribe, no solo la app.

### 8.6 · Firmas — 6.7 (HU-118) — CERRADO

**El traspaso decía «no existe tabla ni ruta». La mitad era falsa:**
`Orden_Trabajo_Validacion` existe desde el modelo original y responde punto por
punto —tipo, firmante, resultado, fecha, motivo y archivo de firma—, y
`Validacion_Tipo` ya traía cargados aceptación, validación y ejecución.

- [x] Lo que faltaba: `otv_uuid` con índice único **filtrado**, los dos SP, el
      permiso `VALIDAR ORDEN TRABAJO` —otorgado a los mismos cuatro perfiles
      que pueden `CERRAR OT`— y las tres rutas.
- [x] «Nueva validación sin eliminar la anterior» sale gratis: la tabla es de
      solo agregar. Firmar dos veces deja dos filas; la más nueva se ve
      primera y la anterior queda atenuada debajo. Una firma que se puede
      reemplazar no prueba nada.
- [x] La firma manuscrita se dibuja con `CustomPainter` y sale en **PNG con
      fondo transparente**: en JPEG cada curva sale con halo, y un fondo blanco
      pegado se ve como un parche en modo oscuro.
- [x] **La firma viaja dentro del mismo envío**, no en dos. Subir el PNG por
      `/evidencias` y después mandar su id son dos peticiones que la cola no
      puede encolar juntas: sin señal entraría la primera y no la segunda, y
      quedaría una firma huérfana. Un envío, un uuid, un reintento.
- [x] El dibujo es **opcional**: lo que siempre queda es quién firmó y cuándo,
      y eso sale del token y del reloj del servidor. Exigirlo dejaría sin
      firmar a quien esté con guantes gruesos, que es media planta.

**Un error que quedó anotado en el propio script:** el SP validaba «ACEPTADA»
y «RECHAZADA» —las palabras de la especificación— mientras la tabla ya traía
`CK_OTV_RESULTADO`, que solo admite `APROBADO` y `RECHAZADO`. Todos los INSERT
rebotaban. La regla vive en el CHECK; el SP ahora traduce en vez de competir.

### 8.7 · Datos de prueba

`Activo_Componente`, `Activo_Medidor` y `Activo_Medidor_Lectura` estaban en
**cero**, así que las pantallas no se podían ni mirar: una lista vacía se ve
igual estando bien que estando rota.
`BD/_SEMILLA_COMPONENTES_Y_LECTURAS.sql` mete tres componentes con estados y
criticidades distintas, un horómetro y doce lecturas mensuales con un mes de
parada y un salto grande. Es idempotente y va con guion bajo porque **no es
una migración**.

- [ ] **`INS_ACTIVO_MEDIDOR` no recibe `@ACTIVO_COMPONENTE`**, aunque la
      columna existe y la usa la ficha del componente. Hoy no hay forma de
      colgar un medidor de un componente desde ningún SP: ni la web puede. La
      semilla lo hace con un UPDATE directo porque son datos de prueba.
- [ ] Quedan en la base, como datos de prueba: el permiso `PT-2026-0001` y las
      firmas de la OT 14. **Dime si los borro.**

---

## Bloque 9 — La tarjeta de SIGMA AI se desbordaba en el Inicio

Reportado con captura: «BOTTOM OVERFLOWED BY 59 PIXELS» sobre las cifras de la
predicción. **Eran dos errores a la vez, y el segundo era el de fondo.**

- [x] **La cifra se partía en dos líneas.** «6,35 mm/s» no cabe a tamaño 20 en
      un tercio del ancho de un teléfono. Ahora se encoge —`scaleDown`, no
      `ellipsis`: media cifra es peor que una cifra chica, porque la cifra es
      lo que se viene a leer— y el valor va separado de su unidad, que estaba
      pegado («6,35mm/s» no es un número, son dos cosas juntas).
- [x] **El alto del carrusel estaba mal desde el principio: decía 254 y la
      tarjeta ocupa 297.** Ese número no salió de ninguna medición; funcionaba
      de casualidad mientras las predicciones traían dos cifras y no tres.
- [x] **El título se partía en dos líneas en teléfonos angostos**, y eso hacía
      la tarjeta 23 px más alta *solo en los aparatos chicos*. Un alto fijo que
      depende del ancho es un desbordamiento esperando al teléfono más barato
      de la planta. Va a una línea, como el detalle.
- [x] **El alto sigue al tamaño de texto del usuario.** Con el ajuste de
      accesibilidad en Máximo (1,5×, vista 16.2) todo lo de dentro crece: un
      alto fijo habría vuelto a reventar el Inicio sin que nadie tocara nada.
      Ese error lo introduje yo al construir 16.2 y no lo vi hasta esta
      captura.
- [x] La cifra también crece con ese ajuste. Antes de esto habría sido lo único
      de la tarjeta que **no** crecía, justo lo que hay que poder leer.
- [x] `test/tarjeta_ia_test.dart`: cuatro casos —tres cifras con unidad, una
      cifra larguísima, un nombre largo en un teléfono de 320 dp y el texto en
      Máximo— que fallan si la tarjeta vuelve a crecer. **El próximo
      desbordamiento se ve en `flutter test`, no en el teléfono de un
      técnico.**

**Lo que dejó como lección:** una constante de alto sin una prueba que la
sostenga es una bomba de tiempo, y el ajuste de tamaño de texto que se agregó
en 16.2 la activó en toda la app.

### 9.1 · El barrido de los demás altos fijos — CERRADO

`auditar_altos.py` encontró **50 altos en duro con texto cerca**. La mayoría
son legítimos —un separador de 1 px, el riel de una barra de progreso, un
avatar, el visor de la cámara— y se descartaron a mano: crecerlos solo
desordenaría la pantalla. **Veintiuno sí envolvían texto** y se escalaron.

- [x] `context.alto(base)` en el sistema de diseño: un solo concepto, escrito
      a mano en cada sitio. **No se aplica solo**, y eso es deliberado: no todo
      alto envuelve texto, y un escalado automático crecería el avatar y el
      visor de la cámara.
- [x] En el kit, que arregla de una vez toda la app: `SgChip`, `SgBadge` en sus
      dos tamaños, `SgBoton` en sus dos altos y `SgContador`.
- [x] Los **rieles de chips** de siete pantallas: un `SizedBox` fijo con una
      fila de chips dentro. Si el riel no crece al paso del chip, el chip
      crecido se recorta contra su borde.
- [x] Los cuatro campos de búsqueda, las cabeceras de «Mi trabajo» y de
      permisos, las píldoras del escáner y el cuadro de evidencia.
- [x] `test/altos_escalados_test.dart`: ocho casos que **miden**.

**La primera versión de esa prueba no servía y estuvo en verde un rato.**
Miraba `takeException()`, como la de la tarjeta de SIGMA AI, pero ahí el
desbordamiento era de un `Column` dentro de una caja fija —eso Flutter lo
denuncia— y un `Container(height: 28)` con un texto de 30 **recorta en
silencio**. Se descubrió devolviendo el `SgChip` a su alto en duro: la prueba
seguía pasando. Ahora mide el alto a 1,0 y a 1,5 y exige que haya crecido; se
volvió a comprobar con el error puesto, y falla.

**Lo que quedó fuera, y por qué:**

- El visor de la cámara (`sigma_lector.dart`, 260) tiene un texto de error
  dentro que sí podría recortarse con la letra al máximo. Crecer el visor es
  peor: es una ventana a la cámara, no una caja de texto.
- **Con la letra en Máximo, un chip de texto largo mide 344 px de ancho.** En
  la app viven dentro de rieles que hacen scroll, así que no se ve; pero un
  chip así puesto en una fila fija se saldría por el costado. Es otro problema
  —de ancho, no de alto— y no se tocó.

- [ ] Revisar los anchos con la letra en Máximo, que es el mismo problema
      girado 90 grados y todavía sin mirar.

---

## Bloque 10 — Web y API: el backlog del 12-09-2026

Bryan pasó la lista de tareas de la hoja del sprint y pidió hacer **solo las
que no chocan con Catalina ni con Emilio**. Se revisaron sus ramas antes de
tocar nada:

- **Emilio** tiene el módulo **Checklist** de la web entero
  (`View/Mantenimiento/Checklist/*`, sus BD/189–194, los controladores
  `ChecklistPlantilla/Estructura`) y metió **Swagger** en la API
  (`SwaggerConfig.cs`, `API.csproj`, `Web.config`). Las filas 2180–2182 de
  `Menus` que apuntan a archivos inexistentes en esta rama son suyas.
- **Catalina** no tiene nada fuera del Excel del backlog.

**Se toman:** HU-080, 081, 083, 085 (planes de mantenimiento: nadie toca
`Plan_Mantenimiento*`) y HU-102, 104 (tareas: no hay páginas web de Tarea en
ninguna rama; la API de comentarios `/tareas/{id}/comentarios` ya existe y es
código compartido).

**No se toman:** HU-095, 096, 097, 093 (checklist, de Emilio); las tareas de
«documentar en Swagger» de cualquier HU (`SwaggerConfig.cs` es suyo); y la
validación con la PO, que no la puede hacer una sesión.

**Para el día del merge:** los números de BD chocan —Emilio usa 189–194 y esta
rama también, con archivos distintos; no es conflicto de git pero deja dos
«193»— y `API.csproj`/`Web.config` los tocamos ambos (él Swagger, yo
controladores): conflicto textual, resoluble.

### 10.1 · HU-080 Crear un plan de mantenimiento — CERRADO

`BD/212_PLAN_MANTENIMIENTO.sql`, `PlanMantenimiento.cs`,
`PlanMantenimientoController.cs`, `View/Mantenimiento/Planes/*`.

- [x] **T-4001 modelo:** `UX_PMA_CLIENTE_CODIGO` confirma el código único por
      cliente. Lo importante que salió de revisarlo: entre el plan y sus hitos
      hay una tabla intermedia, `Plan_Mantenimiento_Version` (Borrador /
      Publicado / Retirado, HU-084). **Los hitos y los activos cuelgan de la
      versión, no del plan.**
- [x] **T-4003 INS:** por eso **crea la versión 1 en borrador en la misma
      transacción**. Un plan que naciera solo no tendría dónde recibir su
      primer hito, y haría falta un botón «crear versión» que nadie sabe que
      hay que apretar antes.
- [x] **T-4002 SEL:** devuelve la auditoría con nombre —una auditoría que solo
      se lee por SSMS no sirve— y la versión que manda (la publicada si hay;
      si no, la última) con sus conteos de hitos y equipos.
- [x] **T-4004 UPD:** `ISNULL` para lo que la ficha no manda, y banderas
      `@QUITA_*` para los combos opcionales: vacío al editar significa
      «quítalo», y sin la bandera el ISNULL conservaría el valor viejo en
      silencio. Quitar el tipo quita también el modelo.
- [x] **T-4005 DEL:** baja lógica. Rechaza si el plan ya generó ocurrencias
      (es historia: hay OT que nacieron de él) o si tiene versión publicada.
      Los tres mensajes dicen qué hacer, no solo que no.
- [x] **T-4006 semilla:** `_SEMILLA_PLANES_MANTENIMIENTO.sql`, por el SP y no
      por INSERT, para que nazcan con versión como los reales. Tres casos:
      acotado con código escrito, sin alcance con código automático, y uno
      deshabilitado para que el filtro tenga que esconder algo.
- [x] **T-4011 listado:** grilla con chip de versión, filtro de planta desde la
      base y «cualquiera» donde un vacío no se entiende.
- [x] **T-4012 ficha:** dos secciones, código con prefijo `PMA-` de
      `Modulo_Codigo`, cascada tipo → modelo, versión de solo lectura y
      `wuc:Auditoria`.
- [x] **T-4013 menú:** listado y ficha en `Menus`, con `Menu_Funcion` «Crear y
      editar» y «Eliminar». **Después de Programaciones y Procedimientos**: un
      hito apunta a una programación, así que quien entra por primera vez tiene
      que haber pasado por ahí antes.
- [x] **T-4014 seguridad:** permisos `VER` y `CREAR EDITAR PLANES
      MANTENIMIENTO` a los cuatro perfiles que ya manejan programaciones. El
      cliente sale de la sesión; el SP además valida que planta y modelo sean
      de ese cliente.

**Verificado en el navegador** (`http://localhost/SIGMA/Intranet`, Rodrigo):
listar → filtrar → crear (`PMA-PRUEBA-WEB`, nació con v1 borrador) → editar
(Renca · Horno · Diosna, la cascada tipo→modelo sobrevivió al postback) →
eliminar. Y por SQL las tres reglas del SP: código duplicado rechazado,
versión publicada rechazada, borrador deshabilitado. `aspnet_compiler` exit 0.

El caso «usuario sin permiso», con los usuarios de Hamburgo:

- **Técnico** (Cristián Muñoz): la web lo frena en el login —«Tu perfil
  trabaja desde la aplicación móvil, no desde la web»—. Es la puerta
  correcta para ese rol: ni llega a la pantalla.
- **Usuario de web sin el permiso** (Ximena Leiva, Bodeguero): quedó
  verificado en datos, no en pantalla. No tiene `VER PLANES MANTENIMIENTO` y
  `ExigirPagina()` la mandaría a `Default.aspx` por la misma ruta que
  protege todo el sitio. Su clave no es la de prueba, así que no se pudo
  mirar. **Si Bryan se la restablece desde la web, se prueba en un minuto.**

- [ ] Quedan en la base como prueba: los planes 1–4 (`PMA-HORNOS-L1`, `PMA-2`,
      `PMA-ANTIGUO`, `PMA-PRUEBA-WEB`). Los dos últimos están deshabilitados.

### 10.2 · HU-081 Definir los hitos de un plan — CERRADO

`BD/213_PLAN_MANTENIMIENTO_HITO.sql`, `PlanHito.cs`, `PlanHitoController.cs`,
`PlanHito.aspx` (modal). El listado `PlanHitos.aspx` **ya no existe**: los
hitos son la pestaña *Hitos* del centro de operaciones (10.4).

- [x] **T-4018 modelo:** `UX_PMH_VERSION_CODIGO` dice que el código del hito
      es único **dentro de la versión**, no dentro del cliente como decía la
      plantilla de la tarea. Tiene sentido: dos versiones del mismo plan
      tendrán un `LUB-500` cada una. El SP valida contra lo que dice el
      índice. Los CHECK de orden y duración se traducen a mensajes antes de
      que rebote la tabla; la regla vive en la tabla.
- [x] **T-4020 INS:** recibe el **plan**, no la versión, y le cuelga el hito a
      su borrador. Pedirle al usuario que elija la versión sería pedirle que
      entienda una tabla que existe por trazabilidad, no por él. Sin borrador,
      rechaza y dice qué hacer. Sin orden, va al final.
- [x] **T-4021 UPD / T-4022 DEL:** **solo sobre un borrador**. Una versión
      publicada ya está generando mantenciones; cambiarle un hito por debajo
      es cambiar lo que se comprometió. El DEL es lógico y rechaza si el hito
      generó ocurrencias o tiene actividades.
- [x] **T-4023 semilla:** `_SEMILLA_PLAN_HITOS.sql`. `Programacion` estaba en
      **cero** —un hito sin programación no se guarda—, así que crea una
      mensual por sus propios SP y dos hitos: uno normal y un overhaul con
      parada, para que las marcas de la grilla tengan algo que marcar.
- [x] **T-4028 listado:** chip de versión, programación con su tipo debajo
      («Intervalo de tiempo»), y parada/overhaul como marcas y no como dos
      columnas de SI/NO.
- [x] **T-4029 ficha:** tres secciones. El combo de plan solo ofrece los que
      tienen borrador al crear. Si la versión ya no está en borrador, la ficha
      lo dice **arriba** y bloquea los campos: enterarse al apretar Guardar es
      la peor forma. Los números se validan con mensaje propio, porque «abc»
      en la duración es un tipeo y el error de SQL no lo explica.
- [x] **T-4030 / T-4031:** mismos permisos que el plan —los hitos son su
      contenido, y un permiso aparte se otorgaría siempre junto con el otro—.
      Menú justo después de Planes; `Menu_Funcion` con las dos funciones.

**Verificado en el navegador:** los cuatro combos poblados desde la base
(planes deshabilitados excluidos), el tipeo en duración rechazado con
mensaje, `REC-SEG` creado sobre el borrador de `PMA-2`, y con la v1 de hornos
publicada a la fuerza: el candado en la ficha, sin botón Guardar, y el SP
rechazando el UPD. `aspnet_compiler` exit 0.

- [ ] Quedan como prueba: la programación «Mensual (semilla)» y tres hitos
      (`LUB-MENSUAL`, `OVH-QUEMADOR`, `REC-SEG`).

**La IP de la API volvió a cambiar** (ahora `192.168.1.31`); `localhost`
sirve igual y es lo que conviene usar.

### 10.3 · HU-083 Asociar equipos a un plan — CERRADO

`BD/214_PLAN_MANTENIMIENTO_ACTIVO.sql`, `PlanActivo.cs`, `PlanActivoController.cs`,
`PlanActivo.aspx` (modal) y `_SEMILLA_PLAN_ACTIVOS.sql`.

- [x] **T-4095 modelo:** `Plan_Mantenimiento_Activo` no tiene `habilitado`
      ni auditoría de actualización: es un **vínculo**, no una entidad. Por
      eso el DEL es **físico** (quitar un equipo del plan es quitarlo, no
      apagarlo) y solo sobre un borrador; rechaza si ese equipo ya generó
      ocurrencias con el plan.
- [x] **T-4097 INS:** valida que el equipo sea del cliente, que quepa en el
      **alcance** del plan (planta, tipo y modelo, si el plan los acota), que
      componente y medidor sean de ese equipo, y que no esté repetido. El
      combo de la ficha **no** filtra por alcance a propósito: sería repetir
      en C# la regla del SP, y el mensaje del SP («5.- EL ACTIVO ACT-35 NO ES
      DEL TIPO AL QUE ESTÁ ACOTADO EL PLAN») explica más que un combo que
      esconde equipos sin decir por qué.
- [x] **T-4099 semilla:** hornos L1 y L2 al plan de hornos; la modeladora con
      su motor y su horómetro al plan de seguridad. La semilla de planes
      apuntaba al **primer tipo por id** (Panificación) y el INS rechazaba
      los hornos: ahora busca el tipo por nombre.
- [x] **T-4105 ficha:** plan y equipo se fijan al editar; lo que se edita es
      sobre qué componente y con qué medidor. Un `RadComboBox` con
      `ReadOnly` **no renderiza sus ítems** y `validaControl` se cae al
      recorrerlos —el Guardar moría en silencio—; los combos fijos van con
      `Enabled = false`, como en `Area.aspx.cs`.

### 10.4 · El plan como centro de operaciones — CERRADO

Bryan, 12-09-2026: «centralizar todo en planes de mantenimiento … en un
único menú el cual tenga tabs de todo lo relevante al plan; será el centro
de operaciones», en `Default.master`.

`BD/215_PLAN_MANTENIMIENTO_CENTRO.sql`, `PlanMantenimiento.aspx(.cs)`
reescrito, `PlanMantenimientos.aspx` navega en vez de abrir modal,
`PlanHito.aspx.cs` / `PlanActivo.aspx.cs` leen `Plan` del query cifrado.
Borrados `PlanHitos.aspx(.cs)` y `PlanActivos.aspx(.cs)`.

- [x] **Un solo menú:** «Planes de mantenimiento». El 215 borra las filas de
      `Menus` / `Menu_Funcion` de los listados sueltos, deja los detalles
      (99, invisibles) y compacta el orden del padre. La fila de Emilio
      (Pautas de inspección) queda donde estaba.
- [x] **La ficha en `Default.master`** con pestañas Ficha / Hitos / Equipos.
      Un plan nuevo **esconde** las pestañas de hitos y equipos —no hay
      versión todavía—; al guardar redirige a sí misma con el id y aparecen.
      Título y subtítulo del layout llevan código, nombre, alcance y versión.
      Carga `sigma-modal.css` a mano porque el master no lo trae.
- [x] **Los modales reciben el plan** en el query cifrado (`Id=0&Plan=<n>`),
      lo preseleccionan y lo fijan. Al cerrar refrescan **solo la grilla que
      los abrió** (`gridPendiente`), sin cambiar de pestaña.
- [x] **`Menu_Funcion` en la ficha:** `Token.PuedeFuncion` mira la página
      actual, y los botones de las grillas ahora viven en ella.

**Verificado en el navegador (Rodrigo):** menú lateral sin las entradas
sueltas; entrar a `PMA-HORNOS-L1` muestra las tres pestañas con sus grillas;
«Asociar equipo» abre con el plan fijo, rechaza la Revolvedora con el mensaje
del SP y asocia `ACT-41 Horno L3` refrescando la pestaña Equipos al cerrar;
«Nuevo plan» sin pestañas → Guardar → centro con id 5 y pestañas; «Nuevo
hito» con el plan fijo; «Volver al listado». Negativos: Cristián Muñoz
(Técnico, Hamburgo) rechazado en el login por ámbito; URL directa sin sesión
→ Login. `aspnet_compiler` exit 0. Datos de prueba revertidos (plan 5 y
ACT-41).

- [ ] Sigue faltando un usuario web **sin** `VER PLANES MANTENIMIENTO` con
      clave conocida (Ximena Leiva, Bodeguero) para el negativo de permiso.
- [ ] Emilio (Checklist / Pautas de inspección): **pendiente, no se toca**
      hasta que Bryan lo pida.

### 10.5 · HU-085 Calendario del plan — CERRADO

`BD/216_PLAN_CALENDARIO.sql`, `_SEMILLA_PLAN_CALENDARIO.sql`,
`PlanOcurrencia.cs`, `PlanOcurrenciaController.cs`, pestaña **Calendario**
en `PlanMantenimiento.aspx`.

- [x] **T-4212 modelo:** `Plan_Mantenimiento_Ocurrencia` no tiene código
      —es (hito, equipo, fecha)—, así que el «único por código» de la
      plantilla no aplica. **Restricción que hay que saber:**
      `UX_PMO_PROGRAMACION_ACTIVO_FECHA` hace que dos hitos del mismo plan
      **no puedan compartir programación** sobre el mismo equipo: el segundo
      choca al generar. La semilla de hitos le dio al overhaul su propia
      programación «Semestral (semilla)». HU-076 (generador) tiene que
      respetarlo.
- [x] **T-4213 SP:** `SEL_PLAN_CALENDARIO` sin SQL armado, filtros por
      parámetro, `OFFSET/FETCH` y `TOTAL` en cada fila. La **situación**
      (cerrada / vencida / atrasada / disponible / futura) se deriva contra
      hoy, no se guarda. Fechas en UTC tal como están: se mira a día.
- [x] **T-4214 índices:** `IX_PMO_CLIENTE_FECHA` e `IX_PMO_ACTIVO_FECHA`;
      el que había partía por estado y un calendario no filtra por estado.
- [x] **T-4215 semilla:** publica la v1 de `PMA-HORNOS-L1` (sin borrador no
      se genera) y llena 2026 con `FNC_PROGRAMACION_FECHAS` hito × equipo:
      28 ocurrencias, las pasadas completadas y una omitida. **Efecto:** los
      hitos y equipos de hornos quedan de solo lectura (v1 publicada); PMA-2
      sigue en borrador para probar edición.
- [x] **T-4218 pantalla:** como **pestaña del centro**, no como página
      suelta (todo centralizado en Planes). Filtros año / mes / equipo del
      plan / estado, línea de resumen por situación, grilla con marcas y
      límite, y **Descargar Excel** con el mismo filtro (`RPT_PLAN_CALENDARIO_EXCEL`).
- [x] **T-4219 seguridad:** cliente siempre desde la sesión en el
      controlador; descarga exige `VER PLANES MANTENIMIENTO`.

**Verificado en el navegador (Rodrigo):** 28 ocurrencias del año con 18
cerradas · 2 vencidas · 2 disponibles · 6 futuras; filtro Septiembre → 4;
la pestaña se mantiene tras filtrar; descarga entrega `CALENDARIO
PMA-HORNOS-L1 <fecha>.xlsx`. `aspnet_compiler` exit 0.

### 10.6 · Carga masiva de planes completos — CERRADO

Bryan, 12-09-2026: «debo poder hacer cargas masivas también de planes de
mantenimientos completos».

`PlanMantenimientoCargaController.cs`, `CargaMasivaPlanes.aspx(.cs)`
(modal desde el listado, botón «Carga masiva»), `BD/217` (fila de menú,
99/invisible). **Sin SP nuevo.**

- [x] **Un libro, tres hojas** cruzadas por el código del plan: PLANES,
      HITOS, EQUIPOS; más hojas de ayuda (plantas, planificadores, tipos y
      modelos, programaciones, unidades, tipos y prioridades de OT, equipos)
      con los valores tal como hay que escribirlos.
- [x] **Reusa los INS de las fichas** fila por fila: las mismas reglas
      (código único, alcance del equipo, solo sobre borrador) y los mismos
      mensajes. Los hitos y equipos pueden apuntar a un plan ya existente.
- [x] **Nombres resueltos en memoria** una sola vez (diccionarios).
- [x] **Una fila mala no detiene la carga**: el resultado dice hoja, fila,
      código y motivo.

**Verificado en el navegador:** planilla de prueba con 2 planes (uno con
código AUTO), 3 hitos y 4 equipos → 6 cargados, 3 rechazados con motivo
(«La programación "Cada luna llena" no existe», «5.- EL ACTIVO ACT-35 NO ES
DEL TIPO…», «El plan "NOEXISTE" no existe ni viene en la hoja PLANES»).
Datos de prueba revertidos.

- [ ] Pendiente (mío, después): validar la subida por tamaño/extension en
      el servidor más allá del `.xlsx` (hoy igual que Repuestos).

### 10.7 · HU-102 Tarea recurrente + HU-104 Comentarios (web) — CERRADO

`BD/218_TAREA.sql`, `_SEMILLA_TAREAS.sql`, `Model/Tarea.cs` (Tarea,
TareaProgramacion, TareaComentario), `TareaController.cs`,
`View/Mantenimiento/Tareas/Tareas.aspx` (listado), `Tarea.aspx` (centro en
Default.master: Ficha / Programaciones / Comentarios) y
`TareaProgramacion.aspx` (modal). Un solo menú: **Tareas recurrentes**.

- [x] **T-4283 modelo:** `Tarea` solo la leía la app: **no había forma de
      crearla desde la web**, así que HU-102 arranca por `SEL/INS/UPD/DEL_TAREA`
      (código `TAR-` automático vía `Modulo_Codigo`). `Tarea_Programacion`
      es única por (tarea, programación); responsable y grupo opcionales,
      como dice la tabla —no se inventó la regla «al menos uno»—.
- [x] **T-4284/85/86 SP:** `INS_TAREA_PROGRAMACION` (revive una apagada en
      vez de chocar con el índice), `UPD` (solo quién la hace; cambiar la
      programación es quitar y agregar), `DEL` lógico. `DEL_TAREA` rechaza
      con ocurrencias pendientes y apaga sus programaciones.
- [x] **HU-104 web:** `SEL_TAREA_COMENTARIO` (hilo por tarea u ocurrencia) e
      `INS_TAREA_COMENTARIO`. Append-only como el modelo: se responde, no
      se edita. Desde la web no se exige pertenecer a la planta (eso es del
      técnico en `API_INS_TAREA_COMENTARIO`): se exige `COMENTAR TAREA` y
      que la ocurrencia sea del cliente. Mismo reintento tolerado (mismo
      texto, mismo usuario, 5 minutos).
- [x] **Pantallas:** listado con prioridad como chip y pendientes; centro
      con ficha (planta → área y equipo en cascada), programaciones (grilla
      + modal con la tarea fija) y **el hilo dibujado como conversación**
      (tarjeta por ocurrencia, respuestas con sangría, «Responder» y
      «Comentar»), no como grilla.
- [x] **Permisos:** `VER TAREAS` / `CREAR EDITAR TAREAS` a los perfiles de
      programaciones; `COMENTAR TAREA` (ya existía, ámbito app) también a
      los que editan.

**Verificado en el navegador (Rodrigo):** listado; TAR-001 con hilo real
(Cristián por voz, Marcela respondiendo); respuesta publicada desde la web
y visible con sangría; «Programar» con la tarea fija y el modal refresca la
grilla; tarea nueva con «abc» en duración → rechazo con mensaje; con 15 →
TAR-6 creada (AUTO) y redirigida al centro. `aspnet_compiler` exit 0.
Datos de prueba revertidos; semilla: TAR-001 mensual con Rodrigo, TAR-005
semestral sin responsable.

- [ ] Sin generador (HU-076) ninguna programación de tarea produce
      ocurrencias nuevas; las que hay son de la demo de la app.
- [ ] `Tarea_Categoria` está vacía y no tiene mantenedor: la ficha no la
      ofrece (el SP sí la acepta).

### 10.8 · HU-084 Publicar una versión del plan — CERRADO (pruebas + lo que faltaba)

En el backlog solo tenía pruebas y documentación: el `UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR`
del bloque 14 ya existía. Pero **no había forma de abrir la versión
siguiente** ni pantalla que publicara, así que la historia no se podía
ejercitar. `BD/219_PLAN_VERSION.sql`, `PlanVersion.cs`,
`PlanVersionController.cs`, pestaña **Versiones** en el centro.

- [x] `SEL_PLAN_VERSION` (versiones con hitos, equipos y ocurrencias
      contados), `INS_PLAN_VERSION_NUEVA` (abre v(n+1) en borrador **como
      copia de la vigente**: hitos, sus actividades si existen, y equipos;
      rechaza si ya hay un borrador —la tabla no lo impide, pero dos
      borradores no tienen sentido—) y `UPD_PLAN_VERSION_PUBLICAR` (delgado
      sobre el del bloque 14, agrega observación y mensajes numerados).
- [x] Pestaña Versiones: grilla con chip de estado, publicación y retiro;
      se ofrece **solo la acción que aplica** (Publicar si hay borrador,
      Abrir versión nueva si no). Son postback completo: la cabecera (título
      y versión) está fuera del UpdatePanel y se repinta.

**Casos ejecutados (criterios de HU-084):** publicar el borrador → queda
PUBLICADA con fecha y usuario y la anterior RETIRADA con fecha; abrir
versión nueva → v(n+1) BORRADOR con los mismos hitos y equipos; abrir una
segunda con borrador vigente → rechazo «2.- EL PLAN YA TIENE UNA VERSIÓN EN
BORRADOR»; publicar sin borrador → botón no ofrecido y SP rechaza; la
ficha de un hito de versión publicada muestra el candado (10.2). Estado
final de `PMA-HORNOS-L1`: v1 y v2 retiradas, v3 publicada (28 ocurrencias
siguen colgando de los hitos de v1: las ocurrencias no se mueven de
versión, es su trazabilidad).

- [ ] La grilla Hitos muestra los hitos de **todas** las versiones (con
      su chip). Con muchas versiones va a crecer; un filtro «solo la que
      manda» es mejora, no bloqueo.

### 10.9 · Cierre de todo lo de Bryan (12-09-2026, segunda mitad)

Bryan: «completemos todo lo de Bryan y marquemos los excels» · «revisa el
sprint 5 … asígnate lo de plan/tareas» · «revisa sprint 1, 2 y 3 … lo
bloqueado que dependía de otro sprint».

**HU-111 (S5, tomada por Bryan) — generar OT desde la ocurrencia.**
`BD/220`: `INS_ORDEN_TRABAJO_OCURRENCIA` en una transacción con
`XACT_ABORT` (orden origen PLAN + historial + un paso por actividad con el
texto **copiado** —o el hito como único paso si HU-082 aún no cargó
actividades— + repuestos planificados + ocurrencia EN EJECUCIÓN con
historial); idempotente (`YA_EXISTIA`). Generación **masiva** desde la
pestaña Calendario con resultado por fila. API `POST /plan-ocurrencias/{id}/orden`.

**HU-076 (S3, estaba Bloqueada; tomada por Bryan) — el generador.**
`BD/222`: `GEN_PLAN_OCURRENCIAS` / `GEN_TAREA_OCURRENCIAS` sobre
`FNC_PROGRAMACION_FECHAS`, solo versiones publicadas, idempotentes por los
dos índices únicos, marca de agua en `Programacion_Generacion`. Botón en el
centro del plan (horizonte 30/90/180/365) y en la tarea; API
`POST /plan-ocurrencias/generar` (`solo_automaticas` para el job nocturno,
**que no existe todavía**: hay que agendar la llamada).

**HU-096 — bandeja de hallazgos.** `BD/221` (SEL parametrizado con la
respuesta que lo originó, índices, Excel, permiso `VER HALLAZGOS`) y
`BD/223` (`INS_ORDEN_TRABAJO_HALLAZGO` origen HALLAZGO CHECKLIST y
`UPD_CHECKLIST_HALLAZGO_DESCARTAR` con motivo ≥ 10). Verificado: motivo
corto rechazado; OT-11 generada y el hallazgo salió de pendientes.

**HU-085 completada:** filtro «solo con parada» y **horas estimadas por
semana** (criterios 2 y 3).

**HU-041 (S2, sin dueño; bloqueaba HU-074 del S3) — variables de
condición.** `BD/224`: SEL completo + INS/UPD/DEL con umbrales en orden;
mantenedor `View/Activos/Variables/` junto a Medidores. **Decisión
HU-073 #3:** `Programacion_Medidor.pme_activo_medidor` pasa a NULL; con
NULL el horómetro lo aporta cada equipo del plan (`pac_activo_medidor`).
`_SEMILLA_PROGRAMACION_CONDICION.sql` desbloquea T-3261 (HU-074).

**Pruebas por HTTP (`_scratch/probar_hu_bryan.py`, Cristián Muñoz):**
HU-095 (abrir idempotente, obligatorios faltantes → 400 «Faltan 4 items»,
fuera de rango con mensaje, cierre con conteos), HU-103 (finalizar con
duración y ejecutor; reintento → `YA_ESTABA`), HU-104 (raíz + anidada;
vacío → 400), HU-140 (evidencia con lat/long y captura; reintento no
duplica; antivirus PENDIENTE). Todo OK.

**Excels marcados:** S4 (81 tareas Terminada, 10 Bloqueada por
desarrollos de Catalina/Emilio; 12 historias de Bryan En revisión; 30
criterios Sí), S3 (HU-076 Terminada/En revisión, T-3261, HU-073/074
observadas), S5 (HU-111 reasignada a Bryan y Terminada), S2 (HU-041
tomada y Terminada). Los libros quedan con `fullCalcOnLoad`: Excel
recalcula las fórmulas al abrir (LibreOffice no está en esta máquina).

- [ ] **Job nocturno** que llame `GEN_PLAN_OCURRENCIAS` /
      `GEN_TAREA_OCURRENCIAS` con `@SOLO_AUTOMATICAS = 1` (SQL Agent o
      tarea programada contra `POST /plan-ocurrencias/generar`).
- [x] Generación **por medidor** (HU-073 #1/#2) y **por condición**
      (HU-074 #1-#3): construida el 17-09-2026 en `BD/243` (ver §10.23).
- [ ] HU-004 sigue bloqueada por SMTP (infra, no código).
- [ ] No verificados (quedan en «No» en los Excels): HU-081 #1/#3, HU-083
      #2/#3, HU-084 #4, HU-095 #4, HU-102 #2, HU-103 #2.

### 10.10 · Sprint 5, lo más complejo: el ciclo de la OT en la web (14-09-2026)

Bryan: «del sprint 5 asígname a Bryan Chávez las funcionalidades más
complejas y realicémoslas». Tomadas HU-110 (8), HU-123 (8), HU-112 (5),
HU-120 (5), HU-124 (5) y HU-122 (3): 39 puntos que cierran el ciclo
falla → orden → asignación → parada del equipo → cierre.

**Modelo de pantallas.** Dos centros más sobre `Default.master`, con el
mismo esquema del plan y la tarea: `Ordenes/OrdenTrabajo.aspx` (Ficha /
Asignación / Pasos / Indisponibilidad / Cierre) y `Fallas/Falla.aspx`
(Ficha / Diagnósticos / Acciones / Indisponibilidad). Modales sobre
`Simple.master` para asignar (`OrdenTrabajoAsignacion.aspx`) y para la
indisponibilidad (`Fallas/ActivoIndisponibilidad.aspx`, se abre desde la
orden y desde la falla con equipo/orden/falla cifrados en el query). Los
listados `OrdenTrabajos.aspx` y `Fallas.aspx` son los únicos menús
visibles; el resto son fichas (99).

**`BD/225_ORDEN_TRABAJO_WEB.sql`** — 18 SP + permisos + menús. Decisiones:

- **HU-110.** `INS_ORDEN_TRABAJO` (web) exige área cuando no hay equipo;
  registro posterior = `otr_registro_posterior` + `otr_fecha_ocurrencia`
  (cuándo pasó) distinta de la de creación (#3); origen MANUAL, o FALLA si
  viene `@FALLA`; correlativo por cliente con UPDLOCK. Dónde y el registro
  posterior se fijan al crear. El alta desde el teléfono
  (`API_INS_ORDEN_TRABAJO`) no se tocó.
- **HU-112.** `INS_ORDEN_TRABAJO_ASIGNACION`: técnico **o** empresa
  externa (que tiene que ser contratista); **un único responsable** — al
  nombrar otro, el anterior pasa a apoyo (`UX_OTA_RESPONSABLE` filtrado);
  si la orden pide una especialidad que el técnico no tiene se asigna igual
  y vuelve `ADVERTENCIA` en el result set (`Usuario_Especialidad` está
  vacía, así que hoy nunca advierte). Notifica si existe `INS_NOTIFICACION`.
- **HU-120.** `UPD_ORDEN_TRABAJO_CERRAR_WEB`: jerarquía por
  `FNC_USUARIO_PUEDE_CERRAR_OT` (permiso `CERRAR OT`: perfiles 12, 1, 5,
  11 — el técnico 13 no); motivos 1-3 exigen EN ESPERA DE CIERRE;
  DUPLICADA / ANULADA / NO APLICA cierran desde cualquier estado y
  conservan el correlativo; «Trabajo realizado» exige resultado ≥ 5
  caracteres. Si la OT vino de una ocurrencia del plan la marca COMPLETADA
  u OMITIDA. **El cierre del teléfono (`UPD_ORDEN_TRABAJO_CERRAR`) sigue
  exigiendo espera de cierre para todos los motivos**: anular desde
  ABIERTA hoy es sólo web.
- **HU-122.** No hay SP aparte: `SEL_ORDEN_TRABAJO` con `@ESTADO = 3`
  ordena por antigüedad y devuelve `DIAS_ESPERA_CIERRE` y
  `PERMISOS_PENDIENTES`. En `OrdenTrabajos.aspx` ese estado activa el
  cierre masivo con motivo común: cada orden se cierra por su cuenta y el
  resultado se muestra por fila (probado: 2 cerradas, 1 queda).
- **HU-123.** Diagnósticos y acciones son hilos (INS, nunca UPD). Un solo
  diagnóstico definitivo: marcar uno desmarca los anteriores. La primera
  acción **definitiva** fija `fal_fecha_solucion_utc`; las provisorias
  mantienen la falla abierta. `PROVISORIAS_DEL_EQUIPO` cuenta las
  provisorias de todas las fallas del mismo equipo: ≥ 2 pinta el aviso
  «equipo que pide atención». El estado posterior (#4) se registra con
  `ACTIVO_CAMBIAR_ESTADO` (historial del activo) **solo si difiere del
  actual**: una segunda falla sobre un equipo ya detenido se guarda sin
  error. `Falla_Sintoma/Modo/Causa` siguen vacíos: se aceptan, no se exigen.
  «Generar orden correctiva» abre una correctiva de EMERGENCIA con
  prioridad = criticidad de la falla y la redirige a la orden nueva.
- **HU-124.** Minutos calculados en el SP de inicio a término; abierta (sin
  término) `MINUTOS_ACUMULADOS` corre contra la hora del servidor.
  Planificada / no planificada es la marca del indicador. Orden y falla
  opcionales (un corte de energía no tiene ninguna). Motivo: catálogo
  `Indisponibilidad_Motivo` (1-6) o texto libre, uno de los dos.
- Permiso nuevo **`REGISTRAR FALLA`** (perfiles 5, 11, 12, 13);
  `VER/CREAR ORDEN TRABAJO` pasan a ámbito 3. `Menu_Funcion` «Crear y
  editar» y «Cerrar» en las páginas de órdenes; «Crear y editar» en fallas.

**API.** `FallasController` (`/fallas`: GET, GET {id}, POST, PUT {id},
GET/POST `{id}/diagnosticos`, GET/POST `{id}/acciones`, POST `{id}/orden`),
`IndisponibilidadesController` (`/activo-indisponibilidades`: GET, GET
{id}, POST, PUT {id}) y en `OrdenesTrabajoController` GET/POST
`{id}/asignaciones` y DELETE `asignaciones/{id}`. DTOs al final de
`Dto.cs`. El permiso de lectura es `VER ORDENES TRABAJO` (en plural: así
está en `Permiso`).

**Pruebas.** SP: OT-13 (área, anulada), OT-14 (registro posterior,
cambio de responsable, técnico rechazado, cierre normal). Navegador con
Rodrigo: F-1 sobre ACT-34 (quedó Detenido, con historial) → diagnóstico
definitivo → acción provisoria (cabecera «reparada de forma provisoria»)
→ OT-15 desde la falla → asignación de Cristián por modal (grilla
refrescada) → indisponibilidad 210 min → cerrar OT-15 abierta con «Trabajo
realizado» rechazado por el SP con su mensaje → bandeja con días de espera
→ cierre masivo OT-3 y OT-4. HTTP (`_scratch/probar_ot_s5.py`): 23 casos
OK — F-5/OT-17 por API, un solo definitivo, técnico 403 al cerrar, usuario
y proveedor a la vez 400, responsable único `[(11,True),(12,False)]`,
105 min calculados, término anterior al inicio 400, falla resuelta no
abre otra orden. **La prueba negativa web con Cristián no se pudo hacer
porque los técnicos entran solo por la app (ámbito 2)**: la cobertura
negativa es el SP + la API (403) + la función «Cerrar» ligada a
`CERRAR OT`. Marcela y Ximena ya no entran con `Sigma2026`.

**Hallazgos de entorno, no de código.**
- En este IIS local **DELETE y PUT devuelven 404 de IIS (StaticFile)**
  también para `/sesion` y `/dispositivos`, que ya existían. El
  `Web.config` ya quita WebDAV; hay que revisar el sitio padre
  (`applicationHost.config`) con permisos de administrador. Hasta entonces
  `DELETE asignaciones/{id}` y `PUT /activo-indisponibilidades/{id}` se
  validan por SP y desde la web.
- `PushButton` + `ConfirSweetAlert` no postea (ya visto en 10.7): el botón
  de cierre pasó a `LinkButton`.

**Excel S5:** 78 tareas de estas seis historias a Bryan y Terminada, 4
quedan «Por hacer» a su nombre porque son de la app (T-5011, T-5901,
T-5175, T-5190: consumo Flutter, los endpoints están); historias En
revisión; 21 criterios Sí.

- [ ] Pantallas Flutter de falla, reasignación e indisponibilidad (los
      endpoints están).
- [ ] Decidir si el cierre del teléfono también permite anular desde
      cualquier estado (hoy sólo la web).
- [ ] Cargar `Usuario_Especialidad` para que la advertencia de HU-112 #4
      se vea alguna vez.
- [ ] Impresión de la OT (HU-125) y servicios contratados (HU-117) no se
      tomaron.

### 10.11 · Sprint 5, la app: todo lo de OT a nombre de Bryan (14-09-2026)

Bryan: «del sprint 5 asígname todo lo correspondiente a las OTs, haz la APP».

**Lo que ya estaba y se verificó** (HU-113 tomar, HU-114 pasos, HU-115 mano de
obra, HU-116 repuestos, HU-118 firmas, HU-119 finalizar, HU-121 bandeja): las
pantallas existían de sesiones anteriores; hoy se corrieron sus criterios por
HTTP (`_scratch/probar_ot_app.py`, 32 casos OK con Cristián y Rodrigo) y
salieron tres defectos, todos en el servidor:

- **HU-119 #2 no se cumplía**: `UPD_ORDEN_TRABAJO_FINALIZAR` dejaba pasar
  obligatorios pendientes; la app solo apagaba el botón. `BD/227` la lleva
  al SP (rechaza nombrando los pasos), guarda `otr_resultado` y
  `otr_fecha_fin_real_utc`, y devuelve `ADVERTENCIA` sin mano de obra (#3).
- **HU-116**: el técnico no podía elegir estante (`GET /bodegas/{id}/ubicaciones`
  exigía `VER BODEGAS`); ahora acepta `EJECUTAR ORDEN TRABAJO`.
- **HU-115 #3**: ejecutante inválido → FK cruda; ahora mensaje (BD/227).

**Lo nuevo en la app** (HU-123, HU-112, HU-124 y la mitad app de HU-110):
`screens/fallas/` (listado, nueva, ficha con diagnósticos / acciones / parada
/ abrir correctiva), `ordenes/hoja_asignar.dart`, `ordenes/hoja_indisponibilidad.dart`,
bloques «Equipo» y «Cuánto estuvo detenido» en la ficha de la OT, «Registrar
una falla» en la ficha del activo, menú `app://fallas` (BD/226). Modelos
`Falla`, `FallaDiagnostico`, `FallaAccion`, `Indisponibilidad`,
`AsignacionOrden`; providers y repositorio; iconos de la cola.

**Idempotencia (BD/226)**: `INS_FALLA`, `INS_FALLA_DIAGNOSTICO`,
`INS_FALLA_ACCION`, `INS_ACTIVO_INDISPONIBILIDAD` e
`INS_ORDEN_TRABAJO_ASIGNACION` reciben `@UUID` (último, opcional: la web no
cambia) con corte antes de validar; columnas `fdi_uuid`, `fac_uuid`,
`ain_uuid`, `ota_uuid` con índices únicos filtrados. Probado: el mismo uuid
devuelve el mismo id.

**Excel S5**: 76 tareas más a Bryan y Terminada; T-5244/T-5245 (pantallas
web de firmas) quedan Por hacer; criterios en «No»: HU-114 #5 (offline no
re-probado hoy), HU-121 #2, HU-116 #2 (horómetro de la pieza sin datos),
HU-115 #2 (proveedor sin datos). 14 historias de OT En revisión.

- [ ] Probar el flujo nuevo en el teléfono (emulador): falla → OT → asignar →
      parada; hoy se verificó por HTTP y con `analyze`/tests.
- [ ] Pantallas web de firmas (T-5244/5245) si la PO las quiere fuera de la
      ficha de la OT.
- [ ] `Usuario_Especialidad` sigue vacía: la advertencia de HU-112 #4 no
      aparece nunca.

---

### 10.12 · Pruebas documentadas de los sprints 1–5 y siete defectos corregidos (14/15-09-2026)

Bryan: «las pruebas documéntalas tú, sácale screenshot tú; de API usaremos el
Swagger; usuarios de Hamburgo; screenshot cuando el modal ya cargó; un Word
por sprint; si encuentras errores los solucionas y lo documentas».

**Cómo se hizo.** `_scratch/evidencia.py` maneja Chrome headless (Selenium)
contra la intranet y contra el Swagger de la API, y anota cada caso en
`Fase 2/Pruebas/capturas/<S>/manifiesto.json` (usuario, pasos, esperado,
obtenido, veredicto, capturas). Los guiones por sprint son `ev_s1.py`…
`ev_s5b.py`; `generar_docx.py` arma un Word por sprint con portada, entorno,
resumen, un caso por criterio con sus capturas y la lista de defectos;
`marcar_criterios.py` pone Sí/No en la hoja *Criterios de aceptación* de cada
Sprint Backlog. Resultado: **S1 26 casos (22 ✓), S2 18 (17 ✓), S3 22 (21 ✓),
S4 23 (20 ✓), S5 48 (48 ✓)**, en `Fase 2/Pruebas/SIGMA_Informe_Pruebas_Sprint_N.docx`.
Los «no cumple» son criterios sin construir (HU-014 #2/#3, HU-004 #2/#3 sin
SMTP, HU-076 #4, HU-083 #3, HU-102 #2, HU-095 #4, HU-193 #4 app), no fallas.

**Defectos que salieron al probar y quedaron corregidos** (cada uno es un
caso «Defecto corregido» en el Word, con captura del antes y del después):

| Sprint | Dónde | Qué pasaba | Corrección |
|---|---|---|---|
| S3 HU-050 | `RepuestoController.InsertRepuesto` | «too many arguments» en `INS_REPUESTO`: parámetros de vida útil duplicados por un merge | Se quitaron los duplicados |
| S2 HU-190 | `SEL_PLAN_COMERCIAL` + `Plan.aspx` | Un plan recién creado, sin precio, no aparecía en Planes y la ficha se cerraba: no había forma de fijarle precio | `BD/228` (LEFT JOIN, «Sin precio»), controller null-safe, la ficha se queda abierta mostrando Precios |
| S2 HU-193 | `SuscripcionAcceso.Exigir` | La compuerta de suscripción mandaba a Renovar.aspx también a Root/Gerente Comercial: nadie podía emitirle el primer período a un cliente recién contratado | No se aplica a perfiles de tipo Sistema |
| S2 HU-194 | `Renovar.aspx` | «Declarar pago» no hacía nada: el RadWindow vivía dentro del panel ajaxificado y `$find` lo perdía tras el postback (`setUrl` de null) | Abre el mismo `SigmaModal` que Pagos.aspx |
| S2 HU-041 | `CapturaTerrenoController.Medicion` | El 201 traía solo `{id}`: el veredicto contra los umbrales que calcula `API_INS_ACTIVO_MEDICION` se tiraba | `Datos.Listar<MedicionRegistradaDto>` y `{id, mensaje}`; `ApiBase.Creado(id, cuerpo)` |
| S1 HU-010 | `SEL_LOGIN` | Root creaba un cliente (INS_CLIENTE lo afilia), lo daba de baja y ya no podía entrar: «Su cuenta no está habilitada» | `BD/229`: las cuentas con perfil de tipo Sistema no dependen de ningún cliente |
| S5 HU-119/116/115 | SP y API | Ya documentados en 10.11 (finalizar con obligatorios, ubicaciones para el técnico, FK cruda en mano de obra) | `BD/227`, `BodegasController`, validación previa |

**Trampas del entorno que no son defectos.** El SQL Server del hosting va en
UTC−7: entre las 00:00 y las 03:00 hora local un precio «desde hoy» todavía
no rige para `GETDATE()`. `DELETE`/`PUT` devuelven 404 en el IIS local (módulo
StaticFile), así que esos verbos se probaron con `curl`/la app y no desde
Swagger. El `Sí` de HU-001 #4 bloquea a Ximena 15 minutos: el guion la
desbloquea al final.

**Datos de prueba que quedaron en la base** (todos marcados «evidencia S1/S2»):
planes PLC-PLUS*, cliente «Panadería del Valle» (deshabilitado), áreas
Producción/Línea 1, centros CCO-CC00xx, usuario prueba.s1.*@hamburgo.cl,
suscripción de CCU con un período emitido y el pago TRX-778899 verificado.

- [ ] Correr `ev_s2b.py` con `HACER_041` para HU-041 #1 si se quiere repetir;
      la variable Temperatura de ACT-35 ya existe (ava_id 20).
- [ ] HU-014 #2/#3 (usuario sin planta, vigencia en la planta) siguen sin
      pantalla que los ejercite: son de la afiliación planta-usuario.

---

### 10.13 · La hora de la base es la de Santiago (15-09-2026)

Bryan: «arregla el UTC, debe ser la hora de Chile actual de Santiago».

El SQL Server del hosting corre en UTC−7, así que `GETDATE()` iba cuatro
horas atrás de Chile: entre las 20:00 y las 24:00 la base creía que era el
día anterior (un precio comercial «desde hoy» no regía; las fechas de
auditoría que no pasaban por `FNC_PAIS_HORA` quedaban atrasadas).

- **`BD/230_HORA_SANTIAGO.sql`** — `FNC_AHORA()` (`SYSDATETIMEOFFSET() AT
  TIME ZONE 'Pacific SA Standard Time'`, horario de verano incluido) y la
  recreación de los **125 módulos** que todavía llamaban `GETDATE()` con
  `[dbo].[FNC_AHORA]()` en su lugar, más los **155 DEFAULT** de auditoría.
  El script lo genera `_scratch/gen_230.py` leyendo `sys.sql_modules`, es
  idempotente, y `GETUTCDATE()` (columnas `*_utc` de la app) no se toca.
  `FNC_PAIS_HORA(@PAIS)` sigue siendo el reloj de cada cliente.
- **Web y API**: `SitioBase.Hora` / `API.Utils.Hora` (`Ahora`, `Hoy`) y los
  36 usos de `DateTime.Now`/`Today` reemplazados (`global::SitioBase.Hora`
  porque dentro del namespace `SitioBase` hay una clase con ese nombre).
- Regla para lo que venga: en SQL **nunca `GETDATE()`**, siempre
  `FNC_AHORA()` o `FNC_PAIS_HORA(@PAIS)`; en C# **nunca `DateTime.Now`**,
  siempre `Hora.Ahora`/`Hora.Hoy`.

---

### 10.14 · Sprint 2 · Posiciones funcionales: HU-033, HU-034 y HU-154 (15-09-2026)

Estaban las tablas (bloque 11) y `Activo.act_activo_posicion`, pero sin SP,
sin pantalla, sin etiqueta y sin escaneo: las tres tablas vacías.

- **`BD/231_ACTIVO_POSICION.sql`** — `SEL/INS/UPD/DEL_ACTIVO_POSICION`
  (código `POS-` automático por `Modulo_Codigo`, único por cliente, área de
  la misma planta, baja lógica si ya tuvo equipo), `UPD_ACTIVO_POSICION_OCUPAR`
  (cierra el periodo del ocupante anterior y el del equipo si venía de otra
  posición; idempotente por `aph_uuid`) y `_LIBERAR`,
  `SEL_ACTIVO_POSICION_HISTORIAL` (con las fechas también en hora de
  Santiago), `SEL_ACTIVO_POSICION_MOTIVO`; rama `POSICION` en `SEL_ETIQUETA`
  (parche dinámico como el bloque 76) y tarjeta en `Etiqueta_Origen`;
  permisos `VER POSICIONES` / `CREAR EDITAR POSICIONES`, menú Activos ›
  Posiciones, `Menu_Funcion`, perfiles 1/5/10/11 escriben, 4/12/13 ven.
- **Web** — `View/Activos/Posiciones/Posiciones.aspx` (filtros planta/área/
  ocupación, chip Libre/equipo, «Imprimir etiquetas» masivo: las marcadas o
  todas las del filtro) y `Posicion.aspx` (pestañas Datos y Ocupación:
  asignar/dejar libre + historial; etiqueta individual). `ActivoPosicion`
  modelo y controller. `Etiquetas.aspx` conoce el origen.
- **API** — `PosicionesController` (`GET /posiciones`, `/{id}`,
  `/{id}/historial`, `POST /{id}/ocupar`) y `GET /escaneo?c=POS-<id>` que
  devuelve el equipo que ocupa la posición o `pos_libre`.
- **App** — `escaneo_screen` entiende `POS`: abre la ficha del equipo que la
  ocupa (HU-154 #1) o, si está vacía, «Poner un equipo aquí» →
  `HojaOcuparPosicion` (equipos de la sábana, se encola con uuid) (#3); el 404
  del servidor se muestra tal cual (#4). 127 tests.
- **Etiquetas**: un código de 8 caracteres (`POS-CB22`) se partía en dos
  líneas y sacaba el pie de la etiqueta; los umbrales de `Escala()` bajaron a
  6/9/14 y el detalle va en una línea con puntos suspensivos.

- [x] HU-154 #2 (escaneo sin señal): **`BD/232`** agrega el bloque 11
      `POSICIONES` a la sábana (posición, área, planta y el equipo que la
      ocupa o LIBRE; baja entero, sin `@DESDE`, porque la ocupación cambia en
      `Activo`, no en la posición). `BLOQUE_MAXIMO` = 11. La app lo guarda
      como `POSICIONES` y `escanear()` resuelve `POS-` y `ACT-` desde la
      sábana cuando no hay señal, marcando el resultado como local con la
      fecha de la última sincronización.
- [ ] La ocupación desde la web no pide OT ni permite «traslado» explícito;
      el motivo lo decide el SP (inicial/reemplazo) salvo que se elija.

---

### 10.15 · Sprint 2 · HU-045 Serie histórica de una variable (16-09-2026)

Lo medido en terreno quedaba en `Activo_Medicion` sin ninguna pantalla que
lo mostrara: la ficha de la variable solo contaba las mediciones.

- **`BD/233_ACTIVO_MEDICION_SERIE.sql`** — `SEL_ACTIVO_MEDICION_SERIE`
  (un punto por medición en el rango, por defecto 90 días, con el valor **en
  la unidad de la variable** —vuelto desde el canónico con factor y offset,
  porque comparar 318 K contra un umbral de 80 °C daba CRÍTICO a 45 °C—, el
  `NIVEL` calculado con la misma regla de `API_INS_ACTIVO_MEDICION`, el
  origen, quién, cuándo, OT o ejecución de checklist, entrada teclado/voz y
  las fechas en Santiago), `SEL_ACTIVO_MEDICION_SERIE_RESUMEN` (puntos,
  críticos, advertencias, fuera de rango, último valor, promedio), la fila
  en `Menus` (oculta, `VER VARIABLES ACTIVO`) y un parche a
  `API_INS_ACTIVO_MEDICION`: con orden de trabajo el `Dato_Origen` es ORDEN
  TRABAJO, no MANUAL (se leía «Ingreso manual · Orden OT-34»).
- **Web** — `View/Activos/Variables/ActivoVariableSerie.aspx`: cabecera
  (equipo, variable, unidad, chips de umbrales, KPIs), filtro de fechas,
  gráfico Highcharts (el `highcharts.js` 3.0 que ya carga el master) con la
  banda normal sombreada, bandas de advertencia/crítico, líneas de umbral,
  puntos fuera de umbral en color y más grandes, eje que siempre incluye el
  crítico; al tocar un punto (o una fila) el panel dice valor, cuándo, quién,
  origen (checklist #n / OT-n / manual, teclado o voz), calidad y
  observación (HU-045 #2). Tabla del rango con el nivel por fila. Icono
  «serie» por fila en `ActivoVariables.aspx`.
- **Trampa**: el master emite `chpScript` **después** del cuerpo; un
  `var sgSerie = null` ahí pisaba los datos que la página inyecta en un
  `Literal`. Se usa `window.sgSerie = window.sgSerie || null`.

---

### 10.16 · Sprint 2 · HU-192 Consultar mi suscripción (16-09-2026)

`Renovar.aspx` («Mi suscripción») ya mostraba estado, plan, vigencia, días
y el uso del plan; faltaban dos cosas del criterio:

- **Qué incluye tu plan** (#1): bloque nuevo con las funcionalidades de
  inclusión del plan contratado en dos listas (incluido / no incluido),
  desde `SEL_PLAN_FUNCIONALIDAD` con la excepción por cliente; los límites
  numéricos no se repiten porque ya están en «Uso de tu plan».
- **Aviso al 80 %** (#2): la fila del límite pasa a «Cerca del límite» y
  arriba de la grilla sale «Estás cerca del límite en máximo de activos
  (20 de 24)». Para la evidencia se dejó a Hamburgo un tope de 24 activos
  como excepción por cliente (`UPS_PLAN_FUNCIONALIDAD @CLIENTE = 1`).
- `sigma-modal.css` **no carga en las páginas del master Default** (solo en
  los modales): los estilos del aviso van en `sigma-components.css` (`vrs=9`).

---

### 10.17 · Sprint 2 · HU-150 Sincronizar los datos hacia el dispositivo (16-09-2026)

La sábana (bloque 140) ya bajaba por bloques con progreso, incremental por
`desde` y tolerante a un bloque fallido; lo que faltaba del criterio #1 eran
**mis órdenes abiertas y las plantillas publicadas**, que se pedían por red
en cada apertura.

- **`BD/234_APP_SABANA_ORDENES_CHECKLISTS.sql`** — bloque 12
  `ORDENES_ABIERTAS` (bandeja delegada en `API_SEL_ORDEN_TRABAJO` ámbito 3,
  más pasos y asignados de las órdenes no cerradas) y bloque 13 `CHECKLISTS`
  (pendientes delegadas en `API_SEL_CHECKLIST` tipo 1, más items y opciones
  de todas las versiones que esas pendientes usan, con `VERSION_ID`).
  `BLOQUE_MAXIMO` = 13.
- **App** — `ordenesTrabajo()` y `ordenTrabajo(id)` se arman desde
  `ORDENES_ABIERTAS_0/1/2` sin señal (el ámbito se aplica en local con
  `ES_MIA` y estado); `checklistPendientes()` y `checklistPlantilla(v)`
  desde `CHECKLISTS_0/1/2`. 129 tests.
- Las tareas de plantilla del backlog que hablaban de `Sincronizacion_Lote`
  y de una subida por lotes quedaron **Descartadas**: la subida es por
  recurso, cada `POST` con su uuid (patrón 209), y no hay lote que recibir.

---

### 10.18 · Sprint 2 · Captura en terreno: HU-043, HU-044 y HU-038 (16-09-2026)

Los SP y los endpoints existían (bloque 141), pero faltaban tres reglas y
la app no podía usarlos.

- **Defecto en la app (HU-043/044)**: `CapturaScreen` encolaba el cuerpo con
  `act_id`, `ame_id`, `fecha_evento` y `origen`, nombres que la API no
  conoce (`LecturaAltaDto`/`MedicionAltaDto` esperan `activo_medidor` /
  `activo_variable`, `fecha_lectura_utc`/`fecha_medicion_utc`, `uuid`,
  `entrada_modo`): cada captura rebotaba con «el medidor no existe». Además
  la medición no llevaba variable: la ficha abría la captura solo con el
  activo. Ahora el cuerpo usa los nombres del DTO, la ficha pide elegir la
  variable (de la sábana `MEDICION_1`, `VariableActivo`) y la lectura se
  registra desde el medidor (`HistorialLecturasScreen`). 130 tests.
- **`BD/235_CAPTURA_REGLAS_HU043_HU044.sql`** —
  · HU-043 #2: `Activo_Medidor.ame_maximo_diario` (ficha web, campo «Máximo
    diario», SP propio `UPD_ACTIVO_MEDIDOR_MAXIMO_DIARIO`); una lectura que
    salte más que máximo × días se acepta con `Medicion_Calidad` 5
    «Pendiente de revisión» y abre una alerta `LECTURA A REVISAR` (tipo
    nuevo), que es el informe de lecturas a revisar en la bandeja.
  · HU-044 #1: el veredicto contra los umbrales se toma sobre el
    **equivalente en la unidad de la variable** (120 psi → 8,27 bar), no
    sobre el número tecleado.
  · HU-044 #2: fuera de umbral sin comentario → 400 «indique un comentario»;
    con comentario se registra y abre una alerta `MEDICION FUERA RANGO`
    (severidad 4 crítico / 3 advertencia / 2 fuera de rango). La app pide el
    comentario antes de encolar con los umbrales de la variable.
  · `POST /captura/lecturas` devuelve `{id, mensaje}` como la medición.
- HU-038 se probó tal como estaba (`ACTIVO_CAMBIAR_ESTADO`): motivo
  obligatorio y cierre del periodo anterior con la misma fecha. Requiere
  `CAMBIAR ESTADO ACTIVO` (supervisor hacia arriba; el técnico recibe 403).

Con esto **todas las tareas de Bryan del Sprint 2 quedan Terminadas o
Descartadas** (S2: 41 casos de evidencia, 40 ✓).

---

### 10.19 · Sprint 3 · HU-058, HU-065, HU-151 (servidor) y HU-077 detectores (16-09-2026)

Regla de este bloque: **lo de la app no se marca en los Excel** (es el MVP
que trabaja Bryan). Solo web, API, base, documentación y pruebas.

- **HU-058 vida útil real** — el bloque 108 había dejado
  `SEL_REPUESTO_VIDA_UTIL` y el 109 una siembra que ya no enganchaba con
  el catálogo (0 filas). `BD/236`: el SP gana fechas en hora de Santiago,
  la vida útil **esperada** (bloque 63) al lado de la real y los
  correlativos de las OT; datos de prueba sobre `REP-6205` en `CMP-33-03`
  con el horómetro `MED-33-H` (300 → 8.712 = 8.412 h; 3.388 h; una abierta;
  una correa sin horómetro). `RepuestoVidaUtil.aspx` (Inventario › Operación,
  permiso `VER REPUESTOS`): una tarjeta por repuesto con promedio / mínima /
  máxima **solo de las cerradas** y el veredicto contra la esperada; grilla y
  Excel. 3 criterios ✓.
- **HU-065 historial del proveedor** — `SEL_PROVEEDOR_HISTORIAL` tenía un
  defecto: el rango de fechas se aplicaba después de contar las órdenes.
  Corregido en `BD/236` (el rango entra en la base). `ProveedorHistorial.aspx`
  (Terceros › Proveedores, `VER PROVEEDORES`): una tarjeta **por moneda**
  (730.000 CLP y 12,50 UF nunca se suman; «sin moneda» aparte con borde
  punteado) + órdenes distintas; filtros proveedor / tipo / rango; enlace
  desde el maestro. 2 criterios ✓.
  - Lección: `sigma-calendario.js` toma como disparador de calendario
    **todo lo pulsable dentro de `.filtroPersonalizado`** y le quita el
    `onclick`. Un botón «Aplicar» ahí no hace postback. El rango vive en su
    propia tarjeta, como en la serie histórica.
- **Menú Terceros ordenado** (`BD/237`, pedido de Bryan): carpetas
  «Proveedores» (Maestro de proveedores, Historial de servicios) y «Permisos
  de trabajo» (Registro de permisos, Vigentes y por vencer), como Inventario.
- **HU-151 lado servidor** — `SuscripcionHandler` en el pipeline de Web API
  (T-3007): con cliente en el token y `PUEDE_OPERAR = 0` responde **402**
  con el cuerpo estándar antes del controller; misma fuente de verdad que la
  web y el login (`SEL_SUSCRIPCION_ESTADO_CLIENTE` → `FNC_SUSCRIPCION_VIGENTE`);
  caché 60 s por cliente; registra en `Suscripcion_Bloqueo_Log` origen API una
  vez por minuto; exentas `/sesion`, `/cliente-usuarios`, `/mi-perfil`. Probado
  con Root en CCU (vencida): 402; Hamburgo: 200. T-3005 ya existía (la sábana);
  T-3001/T-3004 (`Sincronizacion_Lote`) Descartadas por la misma razón que en
  HU-150. **T-3009/T-3011 (móvil) siguen Por hacer**: son del MVP de la app.
- **HU-077 T-3957 detectores de los otros módulos** — `BD/238`:
  `GEN_ALERTA_OPERACION` abre y cierra (RESUELTA) por llave funcional:
  ocurrencia vencida sin OT (ALTA a los 7 días), permiso vencido aún
  solicitado/autorizado, variable con frecuencia sin medición, hallazgo
  alto/crítico sin OT, activo/medidor descubierto en terreno sin revisar, y
  horómetro próximo al disparo del plan (`Programacion_Medidor`). `Alerta`
  gana `ale_permiso_trabajo`, `ale_activo_variable`, `ale_checklist_hallazgo`.
  `GEN_ALERTA_DETECTAR` corre los dos detectores en el mismo turno.
  `CK_ALE_ATENCION` exige `ale_usuario_atencion` cuando hay fecha de atención:
  el cierre automático lo firma el usuario que disparó el detector.
- Evidencia S3: **37 casos, 36 ✓** (`ev_s3c/d/e.py`); Word S3 regenerado.
  Datos de prueba que quedan: instalaciones `DEMO-058-*`, servicios
  `DEMO-F-*`, la ocurrencia 74 atrasada a propósito, y las alertas nuevas.

Pendiente de Bryan en S3 después de esto: solo lo móvil (T-3009/T-3011,
T-3109, T-3227, T-3902) y T-3041 (validación con la PO).

---

### 10.20 · Cambio de alcance: la app móvil se entrega en el Sprint 6 (16-09-2026)

Acordado con el cliente en la **Sprint Review 1** (15-09-2026) y recogido
por la PO: los Sprints 1–5 concentran los entregables en la **web** (la
configuración base tiene que existir antes de poner la app en manos de los
técnicos); la app se entrega **completa en el Sprint 6**, renombrado «App
móvil, inteligencia y cierre».

- Actas Scrum en `Fase 2/Ceremonias/`: `SIGMA_Sprint_Review_Sprint_1.docx`
  y `SIGMA_Sprint_Retrospective_Sprint_1.docx` (Guía Scrum 2020: asistentes,
  incremento, feedback, decisiones sobre el Product Backlog, riesgos,
  próximos pasos; retro con qué salió bien / mal / acuerdos con dueño y
  fecha).
- `SIGMA_Product_Backlog_por_Sprint.xlsx`: las 22 historias de plataforma
  App (154 pts) pasan de los Sprints 2–5 al Sprint 6 (hoja Backlog
  completo, hojas Sprint N, Seguimiento, Plan de Sprints, Épicas).
- Sprint Backlogs: 304 tareas Móvil (y todas las de las historias App)
  quedan **«Movida a Sprint 6»** en S1–S5 y aparecen en S6 **todas Por
  hacer** (nada de la app cuenta como realizado: lo adelantado es el MVP
  interno de Bryan para la hackatón del equipo). Las historias «Web y App»
  figuran en S6 con 0 pts y «solo la parte móvil».
- Burndown: comprometidos S1 81 · S2 83 · S3 139 · S4 109 · S5 72 ·
  **S6 301**. Ese 301 es el riesgo que quedó anotado en la Review y en el
  acuerdo A4 de la retro: refinar el Sprint 6 (app primero; AI/dashboard/
  importación contra ella, y lo que no quepa al Cierre).
- **Infraestructura y servicios externos también al Sprint 6** (Decisión 5
  de la Review, lo provee Código Creativo): SMTP (T-6301), almacenamiento de
  archivos (T-6302), clave de Google Maps (T-6303), push/Firebase (T-6304)
  y HTTPS de la API para el login de la app (T-6305). Impedimentos 1, 2 y 4
  quedan «En gestión» con esa fecha; HU-004 pasa a En revisión en S1 (el
  criterio del correo se verifica en S6).
- Scripts: `_scratch/mover_app_s6.py`, `infra_s6.py`, `s6_sin_realizado.py`
  y `gen_ceremonias.py`.

---

### 10.21 · Pruebas del Sprint 2 completo (17-09-2026)

El informe S2 pasa de «lo de Bryan» a **todo el Sprint**: 52 casos, 49 ✓,
100 figuras (`ev_s2l.py`, `ev_s2l3.py`, `ev_s2m.py`, `ev_s2m2.py`;
`generar_docx.py` ahora lista desarrollador y plataforma por historia).
Los casos de las historias App (HU-043/044/150/154) se sacaron del
manifiesto S2 y viven en `capturas/S6/manifiesto.json` (apuntan a las
capturas de S2).

Al probar las historias de Emilio salieron dos defectos reales y dos
faltantes de pantalla, corregidos:
- **`BD/239`** `SEL_ACTIVO`: filtrar por un tipo padre no traía a los
  subtipos (HU-030 #1). Misma técnica que `@AREAS`.
- **`BD/240`** `UPD_ACTIVO`: aceptaba que un activo colgara de su propio
  subactivo (HU-035 #4); ahora recorre la rama.
- `Activos.aspx` gana el filtro **Tipo de activo** (con sangría por nivel).
- `ActivoFicha.aspx` gana la pestaña **Componentes** (árbol por padre),
  que HU-036 #2 y HU-037 #1 pedían y no existía.
- `Posicion.aspx`: asignar equipo a una posición ocupada **confirma
  diciendo quién la ocupa** (HU-035 #2).

Lo que no cumple y queda anotado: **HU-036 #3** (el estado del componente
cambia con fecha y usuario, pero no pide motivo ni hay historial de
estados del componente — base pendiente) y los criterios de app
(HU-037 #3, HU-193 #4) que son del Sprint 6.

Datos de prueba que quedan: tipo global «Equipo rotatorio», tipo Blower,
modelo Aerzen GM10S, activos ACT-55 (Blower de aireación 1) y ACT-56
(Motor del blower 1) con componentes, medidor «Horómetro del blower» y la
unidad kgf/cm².

---

### 10.22 · Pruebas del Sprint 3 completo (17-09-2026)

Informe S3 de todo el sprint: **64 casos, 55 ✓, 74 figuras**
(`ev_s3f.py` programaciones, `ev_s3g*.py` terceros/repuestos/procedimientos/
permisos). Los casos de HU-151 pasan al manifiesto de S6.

- **Programaciones (HU-070/071/072/075)**: las reglas se ejercitan sobre
  `FNC_PROGRAMACION_FECHAS` con programaciones reales «Evidencia S3 · …»
  (martes/jueves, último día del mes con y sin bisiesto, último viernes,
  fechas puntuales, fecha pasada aceptada, intervalo desde ejecución /
  desde programada, ventana 2/3, feriado desplazado con fecha original,
  parada de planta descartada) y la ficha muestra la proyección.
- **Correcciones**: `BD/241` la OT generada desde una ocurrencia trae **un
  paso por cada paso del procedimiento** de la actividad, con el texto
  copiado (HU-062 #1, HU-061 #2; antes ignoraba `paa_procedimiento`);
  `BD/242` **tomar una OT con todos sus permisos vencidos se rechaza**
  pidiendo uno vigente (HU-063 #3) y **consumir contra una OT un repuesto
  no declarado compatible con el equipo exige el motivo** (HU-051 #2).
- No cumplen y quedan anotados: **HU-073 #1/#2 y HU-074 #1-#3** (el
  disparo por lectura/medición no está construido, ya en §10.9) y
  **HU-062 #2/#3** (la exigencia al ejecutar el paso es de la app, S6).
- Datos que quedan: 8 programaciones «Evidencia S3 · …», proveedor Montajes
  Andinos SpA, compatibilidades de REP-EV2319/REP-EV2323 con GM10S,
  procedimiento PRC-ACEITE-BLW (v2) con 4 pasos, actividad del hito
  «Lubricación cada 500 horas» y la OT generada (correlativo 47) con sus
  permisos PT-S3-ALT/PT-S3-CAL; PT-2026-0001 quedó asociado a una OT del
  horno L2.

---

### 10.23 · Lo que no estaba construido del Sprint 3, ahora sí (17-09-2026)

Bryan tomó HU-073/074 y el lado servidor de HU-062 #2/#3. Informe S3:
**64 casos, 63 ✓** (queda HU-076 #4, «programación deshabilitada», que se
verificó por SP y no por pantalla).

- **`BD/243` generación por medidor y por condición.** El disparo vive en
  los SP de captura, después del `COMMIT` y con su propio `TRY` (lo
  capturado nunca se pierde por un error del plan):
  - `FNC_PLAN_MEDIDOR_ESTADO(@CLIENTE)`: por hito × equipo de los planes
    publicados con programación por medidor, **qué horómetro manda** en ese
    equipo (`pme_activo_medidor` → `pac_activo_medidor` → primer horómetro
    del activo) y el **próximo valor** desde la última ocurrencia generada
    (`pmo_valor_medidor_objetivo`) o el valor inicial. Es lo que resuelve
    HU-073 #3: un plan sobre N equipos dispara N veces con su propio
    horómetro.
  - `GEN_PLAN_OCURRENCIAS_MEDIDOR`: al alcanzar el próximo valor, ocurrencia
    PENDIENTE con ese objetivo (tope 5 por lectura); dentro de la
    anticipación, alerta `MEDIDOR PROXIMO MANTENIMIENTO` sin OT, que se
    cierra sola al generar. `GEN_ALERTA_OPERACION` usa la misma función.
    `UPS_PROGRAMACION_MEDIDOR` acepta medidor vacío (= el de cada equipo).
  - `GEN_PLAN_OCURRENCIAS_CONDICION`: evalúa cada condición sobre la última
    medición **en la unidad de la variable** (canónico → factor/offset);
    con duración mínima, cuenta solo si la **racha** de mediciones que
    cumplen (desde la última que no) lleva esos minutos: una aislada no
    dispara; política TODOS = todas a la vez, UNO/MINIMO = cualquiera; una
    ocurrencia viva por hito y equipo.
- **`BD/244` completar un paso de la OT.** `API_UPD_ORDEN_TRABAJO_PASO`
  gana `@VALOR_MEDICION` / `@UNIDAD_MEDIDA`: un paso del procedimiento que
  exige medición no se completa CONFORME/NO CONFORME sin el valor, y el
  valor entra por `API_INS_ACTIVO_MEDICION` contra la variable del equipo
  de la orden con la OT como origen (serie histórica + umbrales + alerta);
  un punto de control pendiente bloquea los pasos siguientes.
  `PasoResultadoDto` gana `valor_medicion` y `unidad_medida`.
- Evidencia `ev_s3h.py` (API, Cristián): aviso a 8.655 h sin OT, disparo a
  8.700 con objetivo 8.700 y cierre del aviso, ACT-35 y ACT-43 disparan
  con su propio horómetro y ACT-44 no; 84→70 °C no dispara y 84/85/86
  sostenidos 35 min sí; vibración sola no, vibración + corriente sí; paso 5
  bloqueado por el punto de control 4; paso 3 sin valor rechazado y con
  4,2 bar registrado en `Activo_Medicion`.
- Datos que quedan: programación «Lubricación cada 500 horas (por
  medidor)» en el hito 10, horómetros MED-35/43/44-H, hitos COND-TEMP
  (versión 9) y COND-VIB-CORR (versión 11) con la programación «Vibración
  y corriente altas (todas)», OTs 56–58 de las revolvedoras.

---

## Antes de dar cualquier bloque por cerrado

- [ ] MSBuild → 0 errores, **y después pedir una ruta**: compilar sin errores no
      significa que el sitio levante.
- [ ] `flutter analyze lib` limpio.
- [ ] `flutter test` — hoy 112 verdes.
- [ ] Las **cinco** auditorías de `C:\Capstone\_scratch\`: `auditar_rutas.py`,
      `auditar_sp.py`, `auditar_muertos.py`, `auditar_id_output.py` y
      `no_consumidas.py`.
- [ ] Probar por HTTP contra `http://localhost/SIGMA/Servicio/API`.
      Entran con `Sigma2026`: `rodrigo.quezada@hamburgo.cl`,
      `paula.barriga@hamburgo.cl`, `emilio.fuentes@hamburgo.cl`.
- [ ] Actualizar `MD/SIGMA_APP_ESTADO.md` y `MD/SIGMA_TRASPASO_SESION.md`.
- [ ] **No** hacer push a `master` ni a las ramas de Emilio y Catalina sin que
      Bryan lo pida.

---

## Más atrás en la cola

No se han olvidado; están fuera de este encargo hasta que Bryan diga.

- Push / notificaciones (HU-077): falta solo el lado Flutter.
- Diseño v3: **completo**. Las ~40 vistas de la especificación están
  construidas. Lo que queda anotado no son vistas sino base que falta:
  historial de estado del componente, antivirus de archivos, versionado para
  el diff real de 15.2 y `@ACTIVO_COMPONENTE` en `INS_ACTIVO_MEDIDOR`.
- `Repuesto_Compatibilidad` y `Usuario_Especialidad` están vacías: el código
  está hecho, pero sin datos el badge «Compatible» y los chips de especialidad
  no aparecen nunca. **Se cargan desde la web, no programando.**

### 10.24 · Investigación Azure Machine Learning · SIGMA FAILURE 30D (18-09-2026)

El camino completo de un modelo que aprende, probado sin costo. Detalle,
decisiones y guía para Bryan en `SIGMA_INVESTIGACION_AZURE_ML.md`.

- **`BD/245`**: modelo SIGMA FAILURE 30D + 15 características;
  `FNC_ML_ACTIVO_HISTORICO_V1` (características antes del corte, label
  después); `API_SEL_ML_DATASET_FALLA`, `API_INS_ML_DATASET`,
  `API_INS_ML_ENTRENAMIENTO`, `API_INS_ML_MODELO_VERSION`,
  `API_UPD_ML_MODELO_VERSION_PUBLICAR`, `API_SEL_ML`,
  `API_INS_PREDICCION_FALLA`; `mpv_parametro`; permiso ENTRENAR MODELOS;
  menú SIGMA AI › Experimentos.
- **API** `SigmaAiController` (`/sigma-ai/*`), `PuntuadorFalla`, `AzureMl`,
  `ClaveServicio` (sesión delegada por la web, acotada al controller).
- **Web** `View/SigmaAI/Experimentos.aspx`; `Services.GetJsonLibre` y los
  encabezados X-Sigma-Usuario/Cliente en `Services.Preparar`.
- **`ML/entrenar_falla.py`**: dataset por la API → logística → ONNX
  (contrastado con los pesos) → MLflow/Azure ML → informa a la API.
- Probado: dataset real (12 filas, 0 positivas: el historial no alcanza),
  demo sintético 800 filas (AUC 0,763; ONNX = pesos a 1e-7), publicación,
  puntuación de 22 equipos con razones y alertas, pantalla completa.
- **Azure ML real (18-09)**: `az login` con la cuenta de Bryan (CLI vía
  pip, código de dispositivo) y corrida `319576fc…` + modelo
  `SIGMA_FAILURE_30D` v1 registrados en SIGMA_AI; sin cómputo. `mlflow<3`
  por compatibilidad con `azureml-mlflow`. Versión v2 publicada en SIGMA
  con la ruta del activo de Azure.
- **Pendiente**: la lectura desde la API (tarjeta 5) necesita una entidad
  de servicio y el tenant de grupoexpro no permite registrarla; ONNX
  Runtime en la API; `Prediccion_Resultado`.
