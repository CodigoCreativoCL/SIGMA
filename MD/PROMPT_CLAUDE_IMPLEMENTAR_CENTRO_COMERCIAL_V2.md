# Prompt para Claude Code — Centro Comercial SIGMA · Iteración 2: drawers, pagos y clientes internacionales

> Pegar completo en Claude Code dentro de `C:\Capstone\SIGMA`.
>
> Antes de escribir código:
> - sigue `CLAUDE.md` (skill `sigma-cerebro`, `MD/SIGMA_ESTADO_DESARROLLO.md`);
> - lee `MD/PROMPT_CLAUDE_IMPLEMENTAR_CENTRO_COMERCIAL.md`, que es la iteración 1: Lead, Demo, Propuesta, Contrato, Firma y Reuniones con Jitsi.
>
> Este documento **no la reemplaza: la amplía**. Cierra cada bloque con `sigma-cerrar-bloque`.

---

## 0. Fuente de verdad del diseño

- **Canvas:** https://claude.ai/artifact/GYmumHyKwqy9mpsaw2H854. La página **«Iteración 2 · drawers y pagos»** es la que manda. El canvas es privado: compártelo si otra persona lo va a abrir.
- **Copia local:** `Fase 2/Evidencias Proyecto/Diseno/2_Diseno_Web/Redisenos/CentroComercial/artefacto/`. Está sincronizada con la versión 84 del canvas.
  - Cada `*.dc.html` es un artboard: estilos en línea y datos de ejemplo en `renderVals()`.
  - Léelos como especificación de medidas, colores, textos y estados.
  - **No los copies tal cual.** Son componentes del editor de diseño (`<x-dc>`, `<sc-for>`, `<sc-if>`, `<dc-import>`), no WebForms.
- **Brief de esta iteración:** `…/CentroComercial/BRIEF_CLAUDE_DESIGN_DRAWERS_Y_PAGOS.md`. Las capturas del sistema actual están en `capturas-drawers/` y `capturas-pago/`.
- **Solo modo claro.**

### 0.1 Primero verifica qué ya existe (no reinventar)

El brief dice que cobros y pagos **ya están construidos y funcionando en modo de prueba**. Antes de crear tablas o páginas, busca en el repo:

- `Suscripcion.aspx`, `Periodo.aspx`, `Pago.aspx`, `Plan.aspx`, `Cliente.aspx` (hoy son páginas con modales o pestañas);
- `Pagar.aspx` (página pública de pago);
- la integración Webpay Plus (Transbank, ambiente de integración);
- `Jobs.aspx` y las tablas `Job` / `Job_Ejecucion`: UF del día, emitir cobros, recordatorios, vencer demos;
- la tabla de UF diaria, `Suscripcion_Consumo`, y las plantillas de correo de cobro y comprobante.

Anota en `MD/SIGMA_ESTADO_DESARROLLO.md` qué existe y qué falta. **Esta iteración es sobre todo UI:** pasar todo a drawers, rediseñar las páginas públicas y los correos, y agregar la capa internacional (§5). Solo se crean tablas o columnas nuevas cuando no existan.

### 0.2 Mapa de artboards → pantallas

| Artboard | Qué es | Dónde vive |
|---|---|---|
| `Main.dc.html` | Shell con 4 pestañas: Resumen, Pipeline, Clientes y **Suscripciones** (subvistas Suscripciones, Períodos, Pagos y Planes) | `View/Comercial/CentroComercial.aspx` |
| `S1-Suscripcion` … `S7-Resumen` | Main con el drawer abierto en cada caso | referencia de composición |
| `DSuscripcion.dc.html` | Drawer Suscripción. Modos: `ver`, `plan` (cambiar plan), `clave` (pedir motivo), `clave-emitida` (clave visible una vez) | drawer 600 px |
| `DPeriodo.dc.html` | Drawer Período. Modos: `emitido`, `emitir` | drawer 600 px |
| `DPago.dc.html` | Drawer Pago. Modos: `verificar` (760 px, comprobante a la izquierda), `informar`, `corregir`, `webpay` (solo lectura) | drawer |
| `DPlan.dc.html` | Drawer Plan: datos, precio versionado (UF y USD) y tabla de funcionalidades por módulo | drawer 760 px |
| `DCliente.dc.html` | Drawer Cliente. Modos: `ver`, `nuevo`. Secciones Identidad, Contactos, Usuarios y Plantas, más el **país y la moneda de cobro** | drawer 600 px |
| `NuevoLead.dc.html` | Drawer Nuevo lead: validación, aviso de dominio duplicado, país, identificador y chip de moneda | drawer 600 px |
| `MiSuscripcion.dc.html` | P6 · «Mi suscripción» para el administrador del cliente. Estados `pendiente`, `aldia`, `mora`; modos `ver`, `informar` | drawer dentro de SIGMA del cliente |
| `EstadosDrawers.dc.html` | Estados secundarios de Suscripción, Período y Pago | referencia |
| `Ficha.dc.html` + `FichaEtapas.dc.html` | Ficha del lead en las 7 etapas: lead, demo, propuesta, contrato, cliente, marcando perdido, perdido | drawer existente (pasada de diseño) |
| `Firma.dc.html` + `P2-Firmado` | Firma pública; en estado firmado, la acción principal es «Pagar $X con Webpay» | `Firma.aspx?t=` |
| `PagoPublico.dc.html` + `P3-Produccion`, `P3-Movil`, `P3-Estados`, `P3-USD` | P3 · Página de pago. Estados: pendiente, pagado, rechazado, anulado, al día, enlace vencido, inválido, informado. Props `prueba` y `moneda` (`clp` o `usd`) | `Pagar.aspx?t=` |
| `Comprobante.dc.html` | P5 · Comprobante PDF tamaño carta, con marca de agua en modo de prueba | generador de PDF |
| `CorreosCobro.dc.html` | P1/P4 · 7 correos: cobro emitido, vence en 3 días, vence hoy, en mora, comprobante, cobro al firmar (prueba) y **cobro en USD** | plantillas de correo |
| `L-Correos.dc.html` | Correos L1–L5 de la iteración 1, alineados al plan Full | plantillas de correo |
| `DrawerComponentes.dc.html` | Hoja de componentes del drawer | CSS/JS reutilizable |

---

## 1. Reglas de experiencia (no negociables)

- **Nada de modales ni de `SigmaModal`** en el módulo. Todo se abre en el drawer lateral (`K.Panel`); la lista sigue visible detrás y se refresca al guardar.
- **Ancho del drawer:**
  - 600 px por defecto;
  - **760 px** para Plan y para Pago en modo verificar.
- **Cabecera del drawer:**
  - antetítulo con el código, por ejemplo `SUS-0012 · Hamburgo S.A.`;
  - título;
  - chip de estado;
  - botón cerrar.
  - Sin degradados.
- **Cuerpo:** secciones colapsables en tarjetas blancas (borde `#E2E7F0`, radio 14). La sección de la tarea actual va abierta.
- **Barra inferior fija**, de izquierda a derecha:
  - acción destructiva en rojo de contorno (anular, rechazar, deshabilitar);
  - espacio;
  - acción de contorno azul (ver PDF, ver comprobante);
  - **una sola** acción morada `#6732F4` (Guardar, Verificar, Emitir).
  - El turquesa `#007F8A` se usa para la acción paralela, por ejemplo «Informar transferencia» junto a «Pagar ahora».
  - Cancelar es ghost morado suave.
- **Botón principal del header por pestaña:**

  | Pestaña | Botón | Abre |
  |---|---|---|
  | Resumen / Pipeline | «Nuevo lead» | drawer `nuevolead` |
  | Clientes | «Nuevo cliente» (nunca «Nueva empresa») | drawer cliente, modo `nuevo` |
  | Suscripciones | «Emitir período» | drawer período, modo `emitir` |

- Fechas con el calendario SIGMA y combos buscables SIGMA.
- Mensajes por facultad, nunca por rol.
- Español de Chile, y «activo» (nunca «equipo») para los bienes mantenibles.
- La **clave de suscripción** se muestra completa **una sola vez**, al emitirla o reemitirla, en un recuadro destacado con botón copiar. Después solo se ve el prefijo. Reemitir pide un motivo, que queda auditado.

---

## 2. Drawers del Centro Comercial (pestaña Suscripciones y Clientes)

Los campos son los reales de las páginas actuales. Mover a drawer, no cambiar la lógica.

**Suscripción** (`DSuscripcion`):
- **Datos:** ID, clave (prefijo), plan, estado (Activa, Suspendida o Cancelada; la vencida se calcula), habilitada y observación.
- **Contacto de cobro:** nombre, correo y teléfono.
- **Uso contra topes:** usuarios, activos, plantas y GB, con barras de consumo (turquesa bajo 80 %, ámbar desde 80 %).
- **Vigencia:** días restantes.
- **Accesos:** a sus períodos y pagos, ya filtrados.
- **Acciones:** Guardar; Cambiar de plan (plan nuevo y periodicidad Mensual, Trimestral o Anual); Reemitir clave.

**Período de cobro** (`DPeriodo`):
- **Al emitir:** periodicidad, plan, monto (en UF o USD según el cliente, §5), «Es implementación» y observación.
- **Ya emitido:** plan, periodicidad, desde y hasta, monto, valor UF y monto CLP (solo si es UF), pagado, saldo, estado y línea de tiempo de pagos.

**Pago** (`DPago`), 4 modos:
- **Verificar** (760 px):
  - visor del comprobante a la izquierda; datos a la derecha;
  - monto verificado;
  - «Verificar» en morado y «Rechazar» en rojo de contorno, que pide motivo.
- **Informar:** período, monto, fecha, banco, N° de operación y comprobante (archivo).
- **Corregir:** monto, fecha, banco y N° de operación.
- **Webpay:** solo lectura, con tarjeta enmascarada, autorización, orden de compra y «verificado automáticamente».

**Plan** (`DPlan`, 760 px):
- **Datos:** código, nombre, descripción, orden, días de gracia, Público y Habilitado (toggles).
- **Precio versionado:**
  - Nunca se edita un precio vigente: «Fijar precio nuevo» abre un formulario en línea con moneda (**UF o USD**), periodicidad, valor, descuento % y «rige desde».
  - Se muestra el historial.
  - Cada plan tiene precio en UF (Chile) **y** en USD (exterior).
- **Qué incluye:** tabla de funcionalidades agrupada por módulo comercial (Mantenimiento, OT, Planificación, Inspección, Inventario, SIGMA AI, SIGMA Twin), con «incluida» y «tope».
- **Acción:** un solo «Guardar».

**Cliente** (`DCliente`):
- **Resumen arriba:** suscripción, plan y ejecutivo.
- **Secciones colapsables** (no pestañas):
  - Identidad (abierta): logo, nombre, razón social, **país**, **identificador según país**, zona horaria, idioma, **moneda de cobro** y habilitada;
  - Contactos (alta en línea);
  - Usuarios (perfil, estado, invitar);
  - Plantas (nombre, dirección, jornada).

**Nuevo lead** (`NuevoLead`):
- Obligatorios: empresa, contacto y correo.
- Aviso si el dominio del correo ya existe en otro lead o cliente.
- País con identificador dinámico y chip de cobro.
- Rango de activos, módulos de interés, origen, ejecutivo, próxima acción y nota.

**Pestaña Suscripciones** (`Main`, `tab=suscripciones`), subvistas:
- **Suscripciones:** filas con chip de cobro y filtros «Todas», «Pagado en línea», «Transferencia verificada», «Pendiente» y «En mora».
- **Períodos:** columnas Base (UF o USD) y Monto.
- **Pagos:** bandeja **«Por verificar»** con botón Verificar, y lista de pagos recientes.
- **Planes:** tarjetas con precio UF y USD.

**Resumen › Requiere atención:** nuevo grupo **«Cobros»** al inicio:
- transferencias por verificar, que abren el drawer de pago en modo verificar;
- cobros en mora;
- «Se suspende en N días», que abre la suscripción.

**Pasada de diseño a la ficha del lead** (`Ficha`):
- etapa **cliente**: stepper completo, chip CONCRETADO y sección Suscripción con estado AL DÍA;
- etapa **perdido**: motivo visible y footer «Reabrir lead»;
- el chip y el banner del contrato cambian entre VISUALIZADO y FIRMADO;
- las acciones de contrato aparecen solo en la etapa contrato;
- una sola acción morada por etapa.

---

## 3. Flujo de pago (Webpay Plus) — páginas públicas y correos

El flujo funciona sin clics del ejecutivo.

1. **Firmar y pagar en el mismo paso.**
   - Al firmar, SIGMA emite la implementación y la primera mensualidad (con el descuento de la propuesta, en UF y CLP con la UF del día).
   - `Firma.aspx`, ya firmado, muestra:
     - el cuadro de cobros;
     - «Pagar $3.065.335 con Webpay» como acción morada;
     - «Descargar contrato firmado» como secundaria.
2. **`Pagar.aspx?t=…`** (`PagoPublico`):
   - detalle de lo pendiente, total, botón morado de Webpay y datos de transferencia plegables;
   - estados: pagado, rechazado, anulado, al día, enlace vencido, inválido e informado;
   - escritorio y móvil a 375 px.
3. **El pago entra solo:**
   - queda verificado, con comprobante PDF (`Comprobante`);
   - el período queda pagado y el acceso se extiende hasta el fin del período;
   - **el acceso dura mientras haya meses pagados.**
4. **Cada mes** el job emite el cobro unos días antes y envía el correo de cobro.
5. **Recordatorios:** 3 días antes, el día del vencimiento y al entrar en mora. Cada uno se envía **una sola vez**.
6. **Destinatarios:** todos los correos van al contacto de cobro **con copia al ejecutivo a cargo**.
7. **Transferencia como alternativa:**
   - el cliente la informa desde «Mi suscripción» o desde la página de pago;
   - el ejecutivo la verifica en la bandeja «Por verificar».
8. **Correos** (`CorreosCobro`):
   - cabecera de texto «SIGMA», sin imagen: muchos clientes de correo bloquean imágenes;
   - **un solo botón morado** por correo;
   - un bloque de detalle con los montos;
   - pie con el motivo del envío.
   - En HTML de correo usa tablas con estilos en línea; el artboard usa divs solo por el editor.

**Modo de prueba visible:**
- Mientras Webpay esté en integración, la página de pago, los correos y el comprobante muestran el aviso ámbar «MODO DE PRUEBA» con la tarjeta de prueba (4051 8856 0044 6623, CVV 123, RUT 11.111.111-1, clave 123).
- El comprobante lleva además una marca de agua.
- Todo depende de **un solo flag de configuración** (`Webpay.Ambiente = INTEGRACION | PRODUCCION`). En producción el aviso desaparece sin tocar plantillas.

**Mi suscripción (P6)**, para el administrador del cliente, dentro de su SIGMA:
- **Ver:** tarjeta de cobro, barras de uso, historial y footer con «Informar transferencia» (turquesa) y «Pagar ahora» (morado).
- **Informar:** datos bancarios, formulario y zona para soltar el comprobante.
- Solo lo ve quien tenga la facultad correspondiente, no un rol fijo.

---

## 4. Datos de ejemplo del diseño (para pruebas manuales)

- **UF:** $40.871,14.
- **Planes:**

  | Plan | UF/mes | USD/mes |
  |---|---|---|
  | Básico | 15 | 650 |
  | Medio | 30 | 1.300 |
  | Full | 45 | 1.950 |

- **Hamburgo S.A.** (SUS-0012, Full):
  - pagado el 02/10/2026 con Webpay: $3.065.335 = implementación 30 UF ($1.226.134) + octubre 45 UF ($1.839.201);
  - tarjeta ****6623, autorización 1213, orden SG4-261002205301;
  - acceso hasta el 01/11/2026.
- **Cecinas Valdivia** (SUS-0007): transferencia por verificar PAG-0047, $449.583, Banco de Chile, operación 0048213377.
- **Química Austral:** en mora; se suspende en 5 días.
- **Minera Andina Perú S.A.C.** (SUS-0014, RUC 20512345678): USD 1.950 por transferencia internacional.

---

## 5. Capa internacional — país del cliente y moneda de cobro (NUEVO)

SIGMA se vende fuera de Chile, así que **el país del cliente decide la moneda y los medios de pago.**

### 5.1 Regla

| País | Precio | Cobro | Medios de pago |
|---|---|---|---|
| **Chile** | UF | CLP, con la UF del día de emisión | Webpay Plus o transferencia nacional |
| **Otro país** | USD | USD | Transferencia internacional (SWIFT), informada por el cliente y verificada por el ejecutivo |

- **Tarjeta en USD: «próximamente».** Webpay Plus cobra en pesos, así que la página de pago en USD muestra el botón deshabilitado «Pagar con tarjeta en USD · próximamente». Se habilitará cuando se elija un procesador en USD; ese procesador queda fuera de alcance y tiene costo por transacción.
- Los gastos bancarios de la transferencia internacional corren por cuenta del cliente; los correos lo dicen.
- La moneda **se fija al crear el cliente** y no cambia sola. Cambiarla exige una facultad y queda auditado. Un período ya emitido conserva su moneda.

### 5.2 Dónde se pregunta el país

- **Formulario público de `Inicio.aspx` y drawer Nuevo lead:**
  - campo **País** (Chile por defecto; Perú, Colombia, México, Otro… idealmente un combo buscable ISO-3166);
  - la etiqueta del identificador cambia según el país: RUT (Chile), RUC (Perú), NIT (Colombia), RFC (México) o «Identificador tributario» (otro);
  - **solo el RUT chileno se valida con dígito verificador**; el resto, formato libre con largo máximo;
  - chip informativo: «Se cotiza en UF y se cobra en pesos (CLP)» o «Se cotiza y se cobra en dólares (USD)».
- **Propuesta:** se cotiza en la moneda del lead. Con USD, los totales y el PDF van en USD y no muestran la UF.
- **Contrato y firma:** los montos van en la moneda del lead. Con USD, después de firmar la acción principal es «Ver datos e informar el pago», no Webpay.
- **Cliente** (`DCliente`): país, identificador y **moneda de cobro**, con un recuadro cyan que explica el medio de pago.

### 5.3 Modelo de datos (solo lo que no exista)

| Tabla | Cambio |
|---|---|
| `Lead` | `pais_iso` (char 2, por defecto `CL`) e `identificador_tributario`. Mantener `rut` por compatibilidad o migrarlo |
| `Cliente` / Empresa | `pais_iso`, `identificador_tipo` (`RUT` / `RUC` / `NIT` / `RFC` / `OTRO`), `identificador_tributario` y `moneda_cobro` (`UF` / `USD`), derivada del país al crear |
| `Plan_Precio` (versionado) | columna `moneda` (`UF` / `USD`). Un plan tiene filas de precio vigentes por moneda y periodicidad |
| `Propuesta` | `moneda`; montos en esa moneda (`implementacion`, `mensual`, `total`) |
| `Periodo` | `moneda`, `monto_base` (UF o USD), `valor_uf` (null si es USD) y `monto_cobro` (CLP o USD) |
| `Pago` | `moneda`; `medio` (`WEBPAY` / `TRANSFERENCIA_NACIONAL` / `TRANSFERENCIA_INTERNACIONAL`) |
| `Config_Comercial` | datos bancarios para transferencias nacionales e internacionales (banco, SWIFT, cuenta, beneficiario), editables en Configuración. **No los dejes fijos en código ni en plantillas** |

En SP y C#, los montos van en `decimal`, nunca en `float`.

**Formato de montos** (`es-CL`):
- CLP sin decimales: `$1.839.201`;
- UF con 2 decimales: `45,00 UF`;
- USD con 2 decimales: `USD 1.950,00`.

### 5.4 Pantallas afectadas por la moneda

- **`Pagar.aspx` con moneda USD** (artboard `P3-USD`):
  - datos SWIFT;
  - referencia de pago (`SUS-0014-NOV26`);
  - botón morado «Ya transferí: informar el pago», que deja el pago en estado **informado**;
  - botón de tarjeta USD deshabilitado.
- **Correo de cobro en USD:** el 7.º de `CorreosCobro`.
- **Comprobante:** en USD, columnas sin «Valor UF».
- **Listas y KPIs:**
  - nunca sumes CLP con USD;
  - muestra los totales por moneda, o convierte a CLP solo para el KPI con la etiqueta «aprox.».
- **Jobs de emisión:**
  - con UF, toman la UF del día;
  - con USD, emiten el monto del precio vigente en USD, sin conversión.

---

## 6. Orden de implementación (un bloque = un commit)

1. **Inventario de lo existente (§0.1)** y migraciones que falten, numeradas a partir de la última del repo. Incluye la capa internacional del §5.3.
2. **Componentes del drawer** (`DrawerComponentes`): cabecera, sección colapsable, barra inferior, recuadro de clave visible una vez, visor de comprobante, tabla de funcionalidades, barra de consumo y chips de cobro. Van en CSS/JS reutilizable.
3. **Pestaña Suscripciones** con sus 4 subvistas, más los drawers Suscripción y Período.
4. **Drawer Pago** (4 modos) y bandeja «Por verificar», más el grupo «Cobros» en Resumen.
5. **Drawer Plan** con precio versionado UF/USD y funcionalidades.
6. **Drawer Cliente** (secciones, país, moneda) y botón «Nuevo cliente». Retira las páginas viejas o redirige a ellas.
7. **Nuevo lead y formulario público** con país, identificador y chip de moneda. La propuesta y el contrato toman la moneda del lead.
8. **Firma en estado firmado** con «Pagar ahora» y **`Pagar.aspx` rediseñada**: estados, móvil, modo de prueba y variante USD.
9. **Correos de cobro, recordatorios y comprobante** (CLP y USD) y **comprobante PDF**, con el flag de modo de prueba.
10. **«Mi suscripción»** para el administrador del cliente: ver, pagar e informar transferencia.
11. **Pasada de diseño a la ficha del lead** (7 etapas) y a los drawers existentes: crear demo, crear propuesta y reunión.

**Tras cada bloque:**
- `aspnet_compiler -v /Check -p Web/Intranet …`;
- SQL con `Dev/sql_aplicar.py`;
- revisar a 1440 y 1280 px, y las páginas públicas y correos también a 375 px;
- comparar contra el artboard.

Archivos en **UTF-8 con BOM + CRLF**.

---

## 7. Criterios de aceptación

1. No queda ningún modal en Suscripción, Período, Pago, Plan ni Cliente: todo es drawer y la lista se refresca al guardar.
2. Cada drawer tiene una sola acción morada. La destructiva va en rojo de contorno a la izquierda.
3. La clave de suscripción se ve completa una sola vez y reemitirla exige un motivo, que queda auditado.
4. Un precio vigente no se puede editar; «Fijar precio nuevo» crea una versión y el historial la muestra. Hay precio en UF y en USD.
5. Pagar con Webpay (integración) marca el pago como verificado, genera el comprobante PDF, deja el período pagado, extiende el acceso y envía el correo con copia al ejecutivo.
6. Los recordatorios de 3 días, del vencimiento y de mora se envían una sola vez cada uno.
7. Una transferencia informada aparece en «Por verificar» y en «Requiere atención». Verificarla o rechazarla (con motivo) actualiza período, chips y correo.
8. Con `Webpay.Ambiente = INTEGRACION` se ve «MODO DE PRUEBA» en la página de pago, los correos y el comprobante; con `PRODUCCION` no aparece.
9. **Un cliente de Perú** se crea con RUC, moneda USD y cotización en USD. Su cobro se emite en USD sin UF. La página de pago ofrece solo transferencia internacional y la tarjeta USD aparece como «próximamente».
10. **Un cliente de Chile** sigue igual: UF → CLP con la UF del día y Webpay.
11. Ningún total suma CLP con USD.
12. Los datos bancarios salen de Configuración, no del código.
13. Todo cumple el Estándar de UI de `CLAUDE.md`, en español de Chile, con «activo» (nunca «equipo»).

## 8. Fuera de alcance

- Modo oscuro.
- Procesador de tarjetas en USD (Stripe, PayPal, dLocal u otro): todos tienen costo por transacción. Se deja el botón «próximamente».
- Facturación electrónica: el comprobante no la reemplaza y se emite por separado.
- Pantalla de «Tareas automáticas» para los jobs.
- Conversión automática de moneda para clientes existentes.
- Microsoft Teams, streaming y transcripción automática (ver iteración 1).
