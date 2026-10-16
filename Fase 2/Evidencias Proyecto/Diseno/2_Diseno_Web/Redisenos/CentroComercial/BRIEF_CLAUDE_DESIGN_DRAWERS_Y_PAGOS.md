# Brief para Claude Design — Drawers del Centro Comercial y flujo de pagos

> Segunda iteración del canvas https://claude.ai/artifact/GYmumHyKwqy9mpsaw2H854.
> Pegar completo como primer mensaje y adjuntar las carpetas `capturas-drawers/` y `capturas-pago/`, `SIGMA-Paleta-UI-Propuesta.html` y los artboards actuales de `artefacto/`.

---

## 1. Qué pasó y qué se pide

El Centro Comercial ya está construido (Resumen · Pipeline · Clientes · Suscripciones) y el menú «Comercial» quedó con un solo ítem. Para no tener seis menús, las pantallas antiguas de suscripciones, períodos, pagos, planes y clientes se abrieron **dentro del drawer** cargando su ficha vieja en un iframe. **Se ve mal**:

- Las fichas viejas usan otro estilo: grillas Telerik, botones distintos y títulos dentro del contenido.
- «Cliente» trae el sitio completo (sidebar, topbar y el selector de empresa) metido en el drawer (`14_cliente_ficha.png`).
- «Suscripción» queda en blanco (`10_suscripcion_ficha.png`).
- Los drawers propios (ficha del lead, crear demo, propuesta y reunión) funcionan, pero necesitan una pasada de diseño para quedar al nivel del canvas.

**Se pide:**

1. Rediseñar **todos los drawers del Centro Comercial** como drawers nativos SIGMA. La regla está en la sección 3.
2. Diseñar el **flujo de pagos** de la suscripción (sección 5).

## 2. Capturas actuales (carpeta `capturas-drawers/`, 1440 px)

| Archivo | Drawer | Estado |
|---|---|---|
| `01_ficha_lead.png`, `02_ficha_lead_abajo.png` | Ficha del lead (etapa lead) | Funciona; pulir |
| `03_crear_demo.png` | Crear demo | Funciona; pulir |
| `04_crear_propuesta_estandar.png`, `05_…personalizada.png` | Crear propuesta | Funciona; pulir |
| `06_agendar_reunion.png` | Agendar reunión (Jitsi Meet) | Funciona; pulir |
| `07_registrar_reunion.png` | Registrar reunión | Funciona; pulir |
| `08_marcar_perdido.png` | Marcar perdido en línea | Funciona; pulir |
| `09_nuevo_lead.png` | Nuevo lead | Funciona; pulir |
| `10_suscripcion_lista.png` / `_ficha.png` | Suscripción | **Rehacer**: ficha vieja en blanco |
| `11_periodo_lista.png` / `_ficha.png` | Período de cobro | **Rehacer** |
| `12_pago_lista.png` / `_ficha.png` | Pago | **Rehacer** (sección 5) |
| `13_plan_lista.png` / `_ficha.png` / `_nuevo.png` | Plan comercial | **Rehacer** |
| `14_cliente_lista.png` / `_ficha.png` / `_nuevo.png` | Cliente (empresa) | **Rehacer**: mete el sitio entero |

## 3. Reglas (no negociables)

- **Nada de modales ni de SigmaModal.** Todo botón abre el drawer lateral. La lista sigue visible detrás y se actualiza al guardar.
- **Drawer de 600 px** por defecto y de **760 px** para los que tienen tabla, como el plan con sus funcionalidades.
- **Cabecera del drawer:**
  - antetítulo con el código, por ejemplo `SUS-0012 · Hamburgo SA`;
  - título;
  - chip de estado;
  - botón cerrar.
- **Cuerpo:** secciones colapsables en tarjetas blancas (borde `#E2E7F0`, radio 14). La sección de la tarea actual va abierta.
- **Barra inferior fija.** De izquierda a derecha:
  - acción destructiva en rojo de contorno (anular, rechazar, deshabilitar);
  - espacio;
  - acción de contorno azul (ver PDF, ver comprobante);
  - **una sola** acción morada (Guardar, Verificar, Emitir).
- Tokens, botones por función, chips, foco turquesa y Sora + Material Symbols: igual que el Brief 1 y `CLAUDE.md`. **Sin degradados en cabeceras.**
- Fechas con el calendario SIGMA y combos buscables SIGMA. Montos en UF con su equivalente en CLP.
- Mensajes por facultad, nunca por rol.
- Solo modo claro.

## 4. Contenido de cada drawer a rehacer (campos reales del sistema)

**Suscripción** (de `Suscripcion.aspx`):
- **Datos:** ID; clave de suscripción (prefijo visible, la clave completa solo al emitirla); plan; estado (Activa, Suspendida, Cancelada; la vencida se calcula); habilitada; observación.
- **Contacto:** nombre, correo y teléfono.
- **Acciones:**
  - Guardar.
  - Cambiar de plan: plan nuevo y periodicidad (Mensual, Trimestral, Anual).
  - Reemitir clave: pide un motivo; la clave nueva se muestra **una sola vez**, en un recuadro destacado con botón copiar.
- **Agregar:** resumen de uso contra los topes (usuarios, activos, plantas y GB, con barras de consumo), vigencia con días restantes, y accesos a sus períodos y pagos filtrados.

**Período de cobro** (de `Periodo.aspx`):
- **Al emitir:** periodicidad, plan, monto en UF, «Es implantación» y observación.
- **Ya emitido:** plan, periodicidad, desde y hasta, monto UF, UF del día y monto CLP, pagado, saldo y estado.
- **Acción:** Emitir. Mostrar la línea de tiempo de pagos asociados.

**Pago** (de `Pago.aspx`). Ver la sección 5. Tiene tres modos:
- **Declarar:** período, monto transferido, fecha, banco, N° de operación y comprobante (archivo).
- **Verificar:** monto verificado; o rechazar con motivo.
- **Corregir:** monto, fecha, banco y N° de operación.

**Plan comercial** (de `Plan.aspx`):
- **Datos:** código, nombre, descripción, orden, días de gracia, público y habilitado.
- **Precio:** periodicidad, valor UF, descuento % y «rige desde». El precio **se versiona**: nunca se edita un precio vigente, se fija uno nuevo; mostrar el historial.
- **Contenido:** tabla de funcionalidades con «incluida» y «tope», agrupada por los módulos comerciales (Mantenimiento, OT, Planificación, Inspección, Inventario, SIGMA AI, SIGMA Twin).
- **Acciones:** Guardar, Fijar precio y Guardar contenido. Unificar en un solo «Guardar» si el diseño lo permite.

**Cliente (empresa)** (de `Cliente.aspx`, hoy con 4 pestañas):
- **Identidad:** logo corporativo, nombre, razón social, país, identificador según el país (RUT, RUC o CUIT), zona horaria, idioma, moneda y habilitada.
- **Contactos:** lista con alta en línea.
- **Usuarios:** lista con perfil y estado; invitar usuario.
- **Plantas:** lista con nombre, dirección y jornada.
- **En el drawer:** en vez de pestañas internas, usar secciones colapsables, con Identidad abierta. Agregar arriba un resumen con la suscripción, el plan y el ejecutivo comercial.

Botón de la lista: **«Nuevo cliente»** (no «Nueva empresa»).

## 5. Cobros y pagos — ya construido, falta diseñarlo bien

**Decidido y funcionando en modo de prueba (16-10-2026):** cobro **automático** y pago en línea con **Webpay Plus de Transbank**. El ambiente de integración es gratis y no pide cuenta: credenciales y tarjetas de prueba públicas, sin dinero real. Las capturas están en `capturas-pago/`. Las otras pasarelas (Khipu, Fintoc, Flow, Mercado Pago) quedan como alternativas; ninguna es gratis en producción, todas cobran comisión por transacción.

**El flujo, sin clics del ejecutivo:**

1. **Firmar y pagar en el mismo paso.** Al firmar, SIGMA emite la **implementación** y la **primera mensualidad** (la mensualidad con el descuento de la propuesta, en UF y CLP con la UF del día). La página de firma muestra «Pagar ahora con Webpay». Captura: `20_firmado_pagar_ahora.png`.
2. **Página de pago** (`Pagar.aspx?t=…`): detalle de lo pendiente, total y botón «Pagar $X con Webpay» (`21_pagar_pendiente.png`). Lleva al sitio seguro de Transbank (`22`–`26`).
3. **Resultado** (`29_resultado.png`): «Pago recibido» con monto, tarjeta, autorización y orden; o los estados «rechazado», «anulado», «estás al día», «enlace vencido» e «inválido».
4. **El pago entra solo.** Se registra como pago **verificado** (con su comprobante PDF), el período queda pagado y el acceso se extiende hasta el fin del período. En SIGMA **el acceso dura mientras haya meses pagados**; la vigencia del contrato solo dice hasta cuándo se cobra.
5. **Cada mes**, el job diario emite el cobro siguiente unos días antes de que empiece y envía el **correo de cobro** con el botón «Pagar con Webpay».
6. **Recordatorios automáticos:** 3 días antes, el día que vence y al entrar en mora. Cada uno se envía una sola vez.
7. **Todos los correos** (cobro, recordatorios, comprobante) van al contacto del cliente **con copia al ejecutivo a cargo**.
8. **Transferencia** como alternativa: el cliente la informa y el ejecutivo la verifica (bandeja «Por verificar»).

**Jobs en la base (HostChile):** la tabla `Job` guarda qué corre y cuándo:
- ocurrencias nocturnas;
- UF del día;
- vencer demos;
- emitir cobros;
- recordatorios;
- retención de notas.

Plesk llama a `Jobs.aspx` con una clave cada pocos minutos y cada corrida queda en `Job_Ejecucion`. No necesita pantalla en esta entrega; se puede diseñar después una vista «Tareas automáticas».

**Modo de prueba visible:** mientras Webpay esté en integración, la página de pago, los correos y el comprobante muestran «MODO DE PRUEBA» y la tarjeta de prueba. El diseño debe incluir ese aviso (ámbar, discreto) y su versión sin aviso para producción.

**Artboards a entregar para pagos:**
- P1 · correo de cobro (y sus variantes: vence en 3 días, vence hoy, en mora), con copia al ejecutivo;
- P2 · página de firma en estado «firmado» con «Pagar ahora» como acción principal;
- P3 · página de pago `Pagar.aspx`: pendiente y estados (aprobado, rechazado, anulado, al día, enlace vencido, inválido), en escritorio y móvil (375 px), con y sin aviso de modo de prueba;
- P4 · correo de comprobante con el PDF adjunto;
- P5 · comprobante PDF;
- P6 · drawer «Mi suscripción» para el administrador del cliente (estado, próximo cobro, historial, «Pagar ahora», «Informar transferencia»);
- P7 · bandeja «Por verificar» y drawer de verificación de transferencias (comprobante a la izquierda, datos a la derecha, Verificar y Rechazar con motivo);
- P8 · en el Centro Comercial › Suscripciones: chips «Pagado en línea», «Transferencia verificada», «Pendiente» y «En mora», y alertas de cobro en el Resumen (pagos por verificar, cobros en mora, suscripciones que se suspenden en X días).

## 6. Entregables

1. Drawers rehechos: Suscripción, Período, Pago (tres modos), Plan (con historial de precios y funcionalidades) y Cliente (secciones).
2. Pasada de diseño a los drawers que ya funcionan: ficha del lead en cada etapa, crear demo, crear propuesta, agendar y registrar reunión, nuevo lead y marcar perdido.
3. Artboards de pagos P1–P8.
4. Hoja de componentes del drawer: cabecera, sección colapsable, barra inferior, recuadro de clave visible una vez, visor de comprobante y tabla de funcionalidades.
