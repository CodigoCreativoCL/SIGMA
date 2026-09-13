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
