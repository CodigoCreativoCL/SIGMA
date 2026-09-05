# SIGMA App — Brief de mockups

> **Para qué sirve este documento.** Es el contexto completo que necesita una
> herramienta de diseño (Claude Design) para dibujar los mockups de la
> aplicación móvil de SIGMA. **Es autocontenido**: todo lo que hace falta
> —marca, tokens, medidas, contenido real de cada pantalla— está acá dentro.
> No hay que abrir ningún otro archivo para dibujar.
>
> Origen de los datos: `SIGMA_APP_DISENO.md` (tokens y reglas),
> `SIGMA_APP_FLUTTER.md` (historias) y `sigma-brand.css` (la marca).

Fecha: 04-09-2026 · Código Creativo

---

## 1. Qué es SIGMA y quién abre esta app

**SIGMA** es un sistema de gestión de mantenimiento industrial (CMMS). La
aplicación móvil es la herramienta de **terreno**: se usa de pie, dentro de una
planta, con casco, muchas veces con guantes, con ruido, con contraluz o de
noche, y **frecuentemente sin señal**.

Seis perfiles la abren:

| Perfil | Qué hace en el teléfono |
|---|---|
| **Técnico de Mantenimiento** | Ejecuta: su bandeja, pasos de la orden, lecturas, mediciones, evidencias, consumo de repuestos |
| **Supervisor** | Valida en planta: estado de activos, fallas, reasignar una orden |
| **Jefe de Mantenimiento** | Acepta órdenes, autoriza permisos de trabajo, mira el panel |
| **Planificador** | Consulta y alertas (su planificación es de escritorio) |
| **Bodeguero** | Ingreso, entrega, existencia y ajuste, **en el pasillo de la bodega** |
| **Prevencionista** | Permisos de trabajo: los registra y los verifica en el frente |

**No es una app de oficina.** Nada de tablas densas, gestos finos, ni textos
de 11 px. Cada pantalla tiene que poder usarse a un brazo de distancia, con
una sola mano, mirando el teléfono cinco segundos entre dos tareas.

---

## 2. La marca

### 2.1 Reglas que no se negocian

1. **Navy, morado, teal y rosado son identidad.** Verde, amarillo y rojo
   quedan **reservados a estados operativos**. Un chip verde tiene que
   significar «está bien», nunca «se veía lindo».
2. **El degradado es acento, jamás fondo** de una superficie de trabajo. Una
   franja de 3 px, un borde, un ícono. Nunca detrás de un formulario.
3. **La app es oscura.** No hay versión clara en esta fase.
4. **Sobre teal siempre va tinta navy, nunca blanca.** Blanco sobre `#00BFAE`
   da 2.32:1 y es ilegible; navy da 8.26:1.

### 2.2 Paleta

**Marca**

| Nombre | Hex | Uso |
|---|---|---|
| Navy | `#0B0F1A` | Tinta sobre teal, fondos de marca |
| Morado | `#6C5CFF` | **Acción principal**: botón primario, links, foco |
| Morado hover | `#5847E8` | Estado presionado |
| Teal | `#00E0C2` | Acento, íconos de módulo, gráficos |
| Teal accesible | `#00BFAE` | Teal cuando hay texto encima (con tinta navy) |
| Azul | `#2563EB` | Informativo |
| Rosado | `#FF4D9D` | Cierre del degradado, acento puntual |

**Superficies (tema oscuro)**

| Nombre | Hex | Uso |
|---|---|---|
| Fondo de pantalla | `#080C17` | El lienzo de todo |
| Superficie | `#111827` | Tarjetas, formularios, barra inferior |
| Superficie elevada | `#182235` | Tarjeta sobre tarjeta, bottom sheet, menú, chips |
| Borde | `#2A3548` | Bordes de tarjeta, separadores, campos |
| Texto primario | `#F8FAFC` | Títulos y datos |
| Texto secundario | `#A8B2C3` | Subtítulos, ayuda |
| Texto tenue | `#64748B` | Metadatos, marcas de tiempo |

**Estados operativos** (nunca decorativos)

| Estado | Hex | Significa |
|---|---|---|
| Éxito | `#16A34A` | Operativo, al día, enviado, dentro de rango |
| Advertencia | `#F59E0B` | Por vencer, stock bajo, atención |
| Peligro | `#DC2626` | Detenido, vencido, fuera de rango, rechazado |
| Informativo | `#2563EB` | Programado, pendiente sin urgencia |

**Degradado de marca** (solo acento):
`linear-gradient(135deg, #00E0C2 0%, #2563EB 42%, #6C5CFF 72%, #FF4D9D 100%)`

### 2.3 Tipografía

**Sora** (variable 100–800). Fallback: Inter.

| Rol | Tamaño | Peso | Dónde |
|---|---:|---:|---|
| Título de pantalla | 30 | 600 | Cabecera |
| Título de sección | 26 | 600 | Bloques dentro de la pantalla |
| Título de tarjeta | 22 | 700 | Nombre del activo, del repuesto |
| Encabezado de fila | 17 | 600 | Primera línea de un ítem de lista |
| Texto principal | 16 | 500 | **Mínimo legible en planta** |
| Texto secundario | 15 | 500 | Segunda línea de un ítem |
| Metadato | 13 | 500 | Fechas, códigos, contadores |
| Botón | 14 | 600 | Etiquetas de acción |
| Etiqueta | 12 | 600 | MAYÚSCULAS, `letter-spacing 1.2` |

**Nada de datos por debajo de 13 px.**

### 2.4 Forma, sombra y movimiento

| Token | Valor |
|---|---|
| Radio chico | 8 px — chips, etiquetas |
| Radio medio | 12 px — campos, botones |
| Radio grande | 16 px — tarjetas |
| Radio XL | 22 px — bottom sheets, tarjetas hero |
| Píldora | 999 px — botón principal de formulario, badges |
| Sombra de tarjeta | `0 4px 16px rgba(11,15,26,.08)` |
| Sombra elevada | `0 12px 32px -8px rgba(11,15,26,.12)` |
| Transición | 200 ms · `cubic-bezier(0.2, 0, 0, 1)` |

En tema oscuro las tarjetas se separan del fondo **por color y borde**, no por
sombra: la sombra casi no se ve sobre `#080C17`.

---

## 3. Medidas y lienzo

| | |
|---|---|
| **Artboard** | **390 × 844** (referencia iPhone 14 / Android moderno) |
| Barra de estado | 44 px arriba, reservada |
| Barra de navegación del sistema | 34 px abajo, reservada |
| Margen lateral | **16 px** |
| Espaciado | Múltiplos de 8; separación entre bloques 12 o 16 |

| Elemento | Alto |
|---|---:|
| Barra superior de la app | 64 |
| Campo de formulario | **52** |
| Botón principal de formulario | **56**, ancho completo, píldora, fijo abajo |
| Fila de lista | **64** mínimo (dos líneas: el dato y su contexto) |
| Barra de navegación inferior | 72 |
| Objetivo tocable mínimo | **48 × 48** |
| Separación entre dos acciones | **12** |

> **Por qué tan grande.** Se toca con guantes, de pie, sin apoyar la mano. Un
> botón de 40 px que funciona perfecto en el escritorio del diseñador falla en
> la planta.

---

## 4. Componentes

| Componente | Especificación |
|---|---|
| **Barra superior** | 64 px, fondo `#111827` al 80% con desenfoque, borde inferior `#2A3548` al 30%. Izquierda: título o volver. Derecha: **campana de alertas** con badge y **píldora de conexión** |
| **Píldora de conexión** | Alto 28, píldora. `En línea` → texto tenue con punto teal · `Sin conexión` → **neutro `#A8B2C3`, nunca rojo** · `Sincronizando` → punto animado |
| **Campana** | Ícono + badge circular de 18 px con el número de **no leídas**. El badge usa `#DC2626` solo si hay alguna crítica; si no, morado |
| **Tarjeta** | Fondo `#111827`, borde 1 px `#2A3548`, radio 16, padding 16 |
| **Tarjeta con estado** | Igual + **franja izquierda de 4 px** del color del estado |
| **Botón primario** | Morado `#6C5CFF`, texto blanco, radio 12 (56 px si es el de guardar, en píldora) |
| **Botón secundario** | Transparente, borde `#2A3548`, texto `#F8FAFC` |
| **Chip de estado** | Fondo del color de estado al 15%, texto y borde del color pleno, radio 8, alto 26 |
| **Campo de texto** | Alto 52, fondo `#0F1524`, borde `#2A3548`, radio 12. Foco: borde morado 2 px |
| **Avatar** | Círculo de 40 px. Iniciales sobre uno de **doce tonos**, elegido por el id del usuario |
| **Bottom sheet** | Sube al 90% de la pantalla, radio superior 22, asa de 36 × 4 px en `#2A3548` |
| **Barra inferior** | 72 px, fondo `#111827`. Indicador de la pestaña activa: pastilla teal al 20% detrás del ícono |
| **Estado vacío** | Ícono de 64 px en `#182235`, frase en texto secundario y —si aplica— el botón que lo llenaría |
| **Carga** | **Esqueletos** con la forma del contenido, nunca un spinner en pantalla vacía |

---

## 5. Las pantallas

Dos niveles de prioridad. **Nivel 1 son las ocho del Sprint 1 y hay que
dibujarlas todas**; el nivel 2 se dibuja si alcanza.

### NIVEL 1

---

#### 1. Login

- Fondo: `#080C17` con un halo difuso morado/teal arriba a la izquierda, muy
  suave. Es el único lugar donde el degradado puede ocupar superficie.
- Logo SIGMA centrado, arriba del centro. Debajo, «Gestión de mantenimiento
  industrial» en texto secundario, 15 px.
- Tarjeta de formulario: campo **Correo** (`cristian.munoz@hamburgo.cl`), campo
  **Contraseña** con ojo para mostrar, enlace **¿Olvidaste tu contraseña?** en
  morado, y botón **Ingresar** de 56 px en píldora morada.
- Abajo del todo, en texto tenue de 12 px: `v1.0.0 · Código Creativo`.
- **Variante de error a dibujar:** franja de error bajo el campo con
  «Correo o contraseña incorrectos.» en `#DC2626`, y un caso de cuenta
  bloqueada: «Cuenta bloqueada por 12 minutos tras 5 intentos fallidos.»

#### 2. Selección de cliente

Solo aparece si la persona pertenece a más de uno.

- Título: «¿Con qué cliente vas a trabajar?»
- Lista de tarjetas de 88 px: logo del cliente a la izquierda (48 px, sobre
  `#182235`), nombre en 17/600, y debajo «3 plantas» en texto tenue. Chevron a
  la derecha.
- Datos de ejemplo: **Hamburgo S.A.** · **Minera Los Andes** ·
  **Agrícola del Valle**.

#### 3. Sincronización inicial

Es lo primero que ve el técnico después de entrar. Tiene que dar la sensación
de que el trabajo se está preparando, no de que la app se colgó.

- Título «Preparando tus datos» y subtítulo «Puedes trabajar sin señal cuando
  esto termine».
- **Lista de bloques con su estado**, uno por fila de 56 px:
  `Organización ✓` · `Menú y permisos ✓` · `Catálogos ✓` ·
  `Activos — 1.240 de 3.180` (en curso, con barra) · `Medidores` (esperando,
  atenuado) · `Inventario` · `Existencias` · `Permisos de trabajo`.
- Barra de progreso global arriba, en teal.
- Botón secundario **Continuar en segundo plano**.

#### 4. Inicio

La pantalla que más se mira. Bento de tarjetas, no una lista de menú.

- Barra superior con avatar + «Hola, Cristian», campana con badge `3` y
  píldora de conexión.
- Debajo, una línea tenue: `Hamburgo S.A. · Planta Quilicura`.
- **Tarjeta destacada** (ancho completo, 120 px, fondo `#182235` con franja de
  degradado de 4 px arriba): «Mis órdenes de hoy» con un número grande — `4` —
  y «2 vencen hoy» en advertencia.
- **Cuatro tarjetas medianas** en dos columnas (radio 16, ícono de 40 px en
  teal sobre `#182235`): **Escanear QR** · **Activos** · **Existencias** ·
  **Permisos de trabajo**.
- **Tarjeta ancha inferior**: «Pendientes de envío» con `2 registros esperando
  conexión» y flecha. Si la cola está vacía, esta tarjeta no aparece.

#### 5. Alertas (bandeja)

- Título «Alertas» y a la derecha un enlace «Marcar todas leídas».
- Filtros en chips desplazables: `Todas` (activa) · `No leídas` · `Críticas`.
- Ítems de 88 px: **franja izquierda de 4 px con el color de la severidad**,
  ícono del tipo en 40 px, título en 17/600, detalle en 15/500 tenue, y hora
  relativa arriba a la derecha («hace 12 min»). Las **no leídas** llevan fondo
  `#182235` y un punto morado de 8 px.
- Contenido de ejemplo, en este orden:
  1. **CRÍTICA** (rojo) — «Rodamiento 6205 bajo stock mínimo» ·
     «Bodega Central · quedan 2 de 10» · hace 12 min · no leída
  2. **ADVERTENCIA** (ámbar) — «Permiso de trabajo por vencer» ·
     «PT-0042 · vence en 3 horas» · hace 1 h · no leída
  3. **ADVERTENCIA** — «Medidor sin lectura hace 15 días» ·
     «MOT-001 · Horómetro» · ayer · no leída
  4. **INFO** (azul, leída, sin fondo) — «Orden de trabajo asignada» ·
     «OT-1180 · Cambio de sello» · hace 2 días

#### 6. Mi perfil

- Cabecera: avatar de 88 px centrado, nombre en 26/600, perfil en chip teal
  («Técnico de Mantenimiento») y correo en texto tenue.
- Tarjeta **Mis datos**: nombre, apellidos, teléfono, correo (solo lectura,
  con ícono de candado).
- Tarjeta **Seguridad**: fila «Cambiar contraseña» con chevron.
- Tarjeta **Aplicación**: versión, «Datos sincronizados hace 8 minutos»,
  «Notificaciones» con interruptor.
- Botón secundario **Cerrar sesión** en rojo, abajo.

#### 7. Pendientes de envío

La pantalla que hace visible lo que la app todavía no pudo mandar. Sin ella la
cola es una caja negra.

- Encabezado: «2 pendientes · 1 rechazado» y botón **Reintentar todo**.
- Ítems de 80 px con ícono de tipo, título, y **chip de estado**:
  1. `Pendiente` (ámbar) — «Lectura de medidor · MOT-001» ·
     «Capturada hoy 09:12 · sin conexión»
  2. `Pendiente` (ámbar) — «Entrega de repuestos · OT-1180» ·
     «Capturada hoy 10:40 · 2 intentos»
  3. `Rechazado` (rojo) — «Ajuste de inventario · Rodamiento 6205» ·
     **«La cantidad excede el saldo disponible.»** con un botón pequeño
     **Corregir**.

#### 8. Estados del sistema (una lámina con los cuatro)

Cuatro tarjetas o pantallas pequeñas en un mismo artboard:

- **Sin conexión** — banner neutro, no rojo: «Sin conexión. Puedes seguir
  trabajando; lo enviaremos solo cuando vuelva la señal.»
- **Sin permiso (403)** — ícono de candado, «No tienes permiso para ver esto»
  y «Pídeselo al administrador de tu empresa». **Botón Volver**, jamás
  «Reintentar» ni un cierre de sesión.
- **Suscripción vencida (402)** — «La suscripción de Hamburgo S.A. venció el
  31-08-2026» + «Contacta a tu administrador». Sin acción de reintento.
- **Lista vacía** — ícono en `#182235`, «Todavía no hay lecturas registradas»
  y botón **Registrar la primera**.

---

### NIVEL 2

#### 9. Escáner QR

Cámara a pantalla completa, oscurecida salvo un marco de 260 × 260 con
esquinas en teal. Arriba, texto «Apunta al código de la posición o de la
etiqueta». Abajo, botón secundario **Ingresar el código a mano** y un interruptor
de linterna. Debajo del marco, cuando reconoce: una tarjeta que sube desde
abajo con «MOT-001 · Motor bomba principal · Área Envasado» y botón **Abrir
ficha**.

#### 10. Ficha de activo

- Cabecera: código `MOT-001` en etiqueta, nombre «Motor bomba principal» en
  22/700, y **chip de estado** `Operativo` en verde. Debajo, ruta:
  `Hamburgo S.A. › Quilicura › Envasado › Línea 3`.
- Fila de tres datos en tarjeta: Tipo, Modelo, Criticidad (`Alta`, en ámbar).
- Pestañas: **Ficha** · **Historial** · **Medidores**.
- En Historial, línea de tiempo vertical: punto de color por tipo de evento,
  fecha, y una línea de texto («Cambio de estado: Operativo → Detenido ·
  Motivo: falla de rodamiento · Cristian Muñoz»).
- Barra inferior fija con dos acciones: **Registrar lectura** (primaria) y
  **Cambiar estado** (secundaria).

#### 11. Registrar lectura de medidor

- Contexto arriba en tarjeta compacta: activo, medidor `Horómetro`, y
  «Última lectura: 12.480 h · hace 15 días».
- **Campo numérico grande**: 72 px de alto, dígitos en 34/600 alineados a la
  derecha, con la unidad `h` a la derecha en texto tenue. Teclado numérico.
- Aviso en línea cuando el valor es menor al anterior: franja ámbar
  «El valor es menor que la última lectura. ¿Se reinició el medidor?»
- Campo de observación opcional y área de adjuntos (chips de 72 × 72 con
  miniatura y una X).
- Botón **Guardar lectura**, 56 px, píldora morada, fijo abajo.

#### 12. Existencias / dónde está el repuesto

- Buscador arriba y chips: `Todas` · `Bajo mínimo` (con contador `3` en rojo).
- Ítems de 88 px: nombre del repuesto en 17/600, código en etiqueta,
  **cantidad grande a la derecha** con su unidad, y debajo la ubicación:
  `Bodega Central · Pasillo B · Estante 3 · Lote L-2291`.
- Los que están bajo mínimo llevan franja roja y chip `Bajo mínimo`.
- Pie de la pantalla, en tenue: «Existencias al 04-09-2026 14:32» — porque sin
  conexión hay que decir **de cuándo** es lo que se muestra.

#### 13. Movimiento de inventario

Formulario con selector de tipo arriba en chips desplazables: `Ingreso` ·
`Entrega` · `Devolución` · `Ajuste` · `Traslado` · `Merma`. Debajo: repuesto
(con botón de escanear), bodega y ubicación, lote, cantidad (campo numérico
grande), orden de trabajo asociada si es entrega, y motivo. Botón **Registrar
movimiento** abajo.

#### 14. Permiso de trabajo

Formulario con tipo, activo o área, responsable, vigencia (dos campos de
fecha y hora), descripción, y una zona de **evidencia** con tres botones
—cámara, galería, archivo— y sus chips de adjuntos. Botón **Registrar
permiso**.

Y su listado **Vigentes**: tarjetas con chip de tiempo restante
(`vence en 3 h` en ámbar, `vencido` en rojo, `vigente` en verde).

---

## 6. Reglas de contenido para los mockups

- **Datos realistas, del cliente demo.** Empresa: `Hamburgo S.A.`. Plantas:
  `Quilicura`, `San Bernardo`. Áreas: `Envasado`, `Sala de máquinas`.
  Activos: `MOT-001 Motor bomba principal`, `BMB-001 Bomba centrífuga`.
  Repuesto: `Rodamiento 6205`. Personas: `Cristian Muñoz` (técnico),
  `Paula Ríos` (supervisora). Órdenes: `OT-1180`. Permisos: `PT-0042`.
  Nada de «Lorem ipsum» ni de «Nombre del activo».
- **Fechas en formato chileno**: `04-09-2026 14:32`. Horas en 24 h.
- **Números con separador de miles con punto**: `12.480 h`.
- **Toda pantalla con datos necesita su variante vacía**, y toda pantalla con
  lista larga, su variante cargando (esqueletos).
- **Nunca solo color** para comunicar estado: color **más** ícono o texto. Un
  chip rojo también dice «Detenido».

---

## 7. Lo que NO hay que dibujar

- Nada de administración: usuarios, perfiles, permisos, plantas, áreas, centros
  de costo, catálogos, proveedores. Eso es web.
- Nada de planificación: calendarios, planes de mantenimiento, programaciones.
- Nada del módulo comercial: planes, suscripciones, pagos.
- Nada de informes ni exportación a Excel.
- **Nada de tema claro.**
- Nada de tablas de varias columnas: en 390 px se leen como lista.

---

## 8. Cómo entregar

- Un artboard por pantalla, **390 × 844**, fondo `#080C17`.
- Nombre del artboard = número y nombre de la §5 (`01 Login`, `05 Alertas`).
- Las variantes (error, vacío, cargando) van como artboards aparte con sufijo:
  `01 Login · error`.
- Barra de estado y barra del sistema dibujadas como referencia tenue, no como
  contenido.
- Si algo del brief no alcanza para decidir, **elegir lo más simple y
  anotarlo** en el propio artboard, en una nota al costado. Inventar una regla
  nueva de marca no.
