# Prompt para Claude Code — Implementar el Centro Comercial de SIGMA

> Pegar completo en Claude Code dentro de `C:\Capstone\SIGMA`. Antes de escribir código, sigue `CLAUDE.md` (skill `sigma-cerebro`, `MD/SIGMA_ESTADO_DESARROLLO.md`) y cierra cada bloque con `sigma-cerrar-bloque`.

---

## 0. Fuente de verdad del diseño

- **Diseño navegable (canvas):** https://claude.ai/artifact/GYmumHyKwqy9mpsaw2H854. Es privado: hay que compartirlo para que el equipo lo abra.
- **Copia local del diseño:** `Fase 2/Evidencias Proyecto/Diseno/2_Diseno_Web/Redisenos/CentroComercial/artefacto/`.
  - Cada `*.dc.html` es un artboard.
  - Los estilos van en línea y los datos de ejemplo están en `renderVals()`: léelos como especificación de medidas, colores, textos y comportamiento.
  - No los copies tal cual. Son componentes del editor de diseño (`<x-dc>`, `<sc-for>`, `<sc-if>`), no WebForms.
- **Brief original:** `…/CentroComercial/BRIEF_CLAUDE_DESIGN.md`. Capturas actuales en `…/CentroComercial/capturas/`.
- **Paleta oficial:** `…/Redisenos/Planificacion360/SIGMA-Paleta-UI-Propuesta.html` y la sección «Estándar de UI» de `CLAUDE.md`.
- **Solo modo claro.** No implementar tema oscuro.

### Mapa de artboards → pantallas

| Artboard | Qué es | Dónde vive en SIGMA |
|---|---|---|
| `Main.dc.html` | A · Resumen (shell + header + pestañas + KPIs + «Requiere atención» + próximas acciones) | `View/Comercial/CentroComercial.aspx`, pestaña Resumen |
| `B-Pipeline.dc.html`, `B-Tablero.dc.html` | B · Pipeline lista / tablero | misma página, pestaña Pipeline |
| `K-Clientes.dc.html` | K · Clientes concretados | misma página, pestaña Clientes |
| `Ficha.dc.html` (+ `C-Ficha`, `G-Contrato`) | C/E/G · Ficha del lead en drawer, con Demo, Propuesta y Contrato | drawer `K.Panel` |
| `CrearDemo.dc.html` (+ `D-CrearDemo`) | D · Crear demo | drawer que reemplaza la ficha |
| `CrearPropuesta.dc.html` (+ `F-Propuesta`) | F · Crear propuesta | drawer que reemplaza la ficha |
| `Reunion.dc.html` (+ `M-Reunion`, `M-Resumen`) | M · Agendar reunión (Jitsi Meet + invitación por correo) y Registrar reunión | drawer (600 px) |
| `Firma.dc.html` (+ `H-FirmaMovil`, `I-EstadosFirma`) | H/I · Firma pública y sus estados | página pública `Firma.aspx?t={token}` |
| `J-Clave.dc.html` | J · Cambio obligatorio de contraseña | variante de `Login.aspx` |
| `L-Correos.dc.html` | L · 5 correos HTML (L5 = invitación a reunión) | plantillas de correo |
| `Componentes.dc.html` | Hoja de componentes y estados | CSS/JS reutilizable |

---

## 1. Objetivo

SIGMA debe poder llevar a un prospecto desde el formulario web hasta cliente con suscripción activa, sin salir de SIGMA:

> Formulario web → Lead → Demo con límites → Propuesta → Contrato con firma electrónica simple → Cliente + Suscripción activa.

Debe sentirse como «SIGMA ahora tiene capacidades comerciales», no como un CRM pegado.

**Usuario:** ejecutivo comercial de Código Creativo, que trabaja dentro del cliente/empresa Código Creativo en SIGMA.

---

## 2. Lo que ya existe (verificado en el repo, no reinventar)

| Pieza | Dónde | Cómo usarla |
|---|---|---|
| Formulario público de asesoría | `Web/Intranet/Inicio.aspx`, `#formAsesoria` (campos `asNombre`, `asApellido`, `asCorreo`, `asTelefono`, `asEmpresa`, `asPais`, `asActivos`, `asPlan`, `asMensaje` + consentimiento) | Hoy hace `mailto:`. **Reemplazar** por un POST a `WsComercial.asmx/CrearLeadPublico` y mantener el mensaje de éxito. |
| Planes, precios UF, suscripciones, pagos | `BD/08_SUSCRIPCION.sql` (`Plan_Comercial`, `Plan_Comercial_Precio`, `Plan_Comercial_Funcionalidad`, `Suscripcion`, `Suscripcion_Periodo`, `Valor_Uf`…), SPs en `41_`, `45_`, `228_` | La propuesta estándar sale de `Plan_Comercial`. Al firmar, se crea la `Suscripcion` con estos SPs. |
| Vistas comerciales actuales | `View/Comercial/Clientes/*`, `View/Comercial/Suscripciones/*` | No se borran. Quedan accesibles desde la ficha y desde la pestaña Clientes. El menú nuevo es uno solo (ver §3). |
| Patrón de «Centro» con header oscuro y pestañas | `View/Mantenimiento/Planificacion.aspx` + `Js/sigma-centro-planificacion.js` + `WebService/WsCentroPlanificacion.asmx` | Copiar estructura: header de banda oscura sin degradado, pestañas con icono + subtítulo, buscador, chips con contador, Lista/Tarjetas. |
| Drawer lateral | `Panel` / `K.Panel` en `Js/sigma-mant-comun.js` (uso en `sigma-mant-avisos.js`) | Toda creación o edición va en este drawer. **Nada de modales.** Agregar ancho variable (600 / 960 px). |
| Calendario y combo propios | `Js/sigma-calendario.js`, `Js/sigma-combo.js` | Todas las fechas y combos (buscables). Nunca `input type=date` ni `<select>` nativo. |
| Envío de correo | `App_Code/MVC/SitioBase/Controller/CuentaController.cs` (SmtpClient) | Extraer a un servicio reutilizable si no existe. Los 4 correos usan plantillas HTML de 600 px. |
| SIGMA AI | Ver `Boveda/SIGMA AI automatico.md` y `WsAiCentro.asmx` | Hoy no usa modelo de lenguaje (reglas, gratis). **No** se usa para resumir reuniones en esta entrega (§7). |
| Última migración | `BD/453_ML_SENAL_CIERRE_OT.sql` | Las nuevas parten en **454**. Confírmalo con `Dev/indexar_bd.py` antes. |

Lee también `Boveda/Patrones/CONVENCIONES.md`, `Boveda/Patrones/CHECKLIST_ENTIDAD_NUEVA.md`, `Boveda/Seguridad por datos.md` y `Boveda/Web services.md`. Mandan sobre este prompt si chocan.

---

## 3. Reglas de experiencia (no negociables)

1. **Un solo menú:** `COMERCIAL › Centro Comercial`. Sin menús Leads, Demos, Propuestas ni Contratos. Los menús viejos no se borran; se ocultan con `mnu_visible = 0` si sobran.
2. **Solo drawer, sin modales.** La lista sigue visible detrás y se actualiza al guardar.
3. **Pocos clics:** desde una métrica o alerta se llega a la ficha en 1 clic. Divulgación progresiva: las secciones Demo, Propuesta y Contrato aparecen solo si existen, y la de la etapa actual viene abierta.
4. **Sin tours.**
5. **Mensajes por facultad, no por rol:** «Puedes crear demos», nunca «el supervisor…».
6. Calendario y combo propios de SIGMA. Español de Chile. Montos en UF; CLP solo como equivalente según la UF del día.
7. Estándar de UI de `CLAUDE.md`:
   - máximo 1 morado + 1 turquesa por grupo;
   - contorno azul para navegar;
   - ghost para cancelar;
   - rojo solo para destructivo (Marcar perdido, Anular contrato, Terminar llamada);
   - KPIs con número en `--ink`;
   - foco con anillo turquesa;
   - sin degradados en cabeceras.
8. Archivos UTF-8 con BOM y CRLF (`Dev/bom.py`). Todo `<button>` dentro del form lleva `type="button"`.

---

## 4. Modelo de datos (migraciones 454+)

SP-first, como el resto de SIGMA. Nombres orientativos: ajústalos a `CONVENCIONES.md`.

| Tabla | Campos clave |
|---|---|
| `Lead` | id, código (`LEAD-0142`), empresa, rut, rubro, contacto_nombre, contacto_cargo, correo, telefono, pais, n_activos, plan_interes, mensaje, intereses (módulos), origen (`FORM_WEB` / `MANUAL`), consentimiento + fecha + ip, estado (`NUEVO`, `CONTACTADO`, `CALIFICADO`, `DEMO`, `PROPUESTA`, `NEGOCIACION`, `CONTRATO`, `CONCRETADO`, `PERDIDO`), motivo_perdida, ejecutivo_id (usuario), proxima_accion_tipo, proxima_accion_fecha, fecha_estado, cliente_id (al concretar), auditoría |
| `Lead_Actividad` | lead_id, tipo (`LLAMADA`, `EMAIL`, `REUNION`, `NOTA`, `SISTEMA`), titulo, detalle, usuario_id (null = sistema), fecha, reunion_id (opcional) |
| `Lead_Demo` | lead_id, cliente_demo_id (empresa creada), usuario_principal_id, plan_demo_id, inicio, expira, estado (`ACTIVA`, `EXTENDIDA`, `VENCIDA`, `FINALIZADA`), módulos y límites (usuarios, activos, OT, programaciones, checklists, repuestos, bodegas, plantas), ultimo_acceso |
| `Config_Comercial` | límites demo por defecto (7 días, 2 usuarios, 10 activos, 20 OT, 5 programaciones, 5 checklists, 20 repuestos, 1 bodega, 1 planta), correo de aviso (`comercial@codigocreativo.cl`), días de vigencia del enlace de firma |
| `Propuesta` | lead_id, version, tipo (`ESTANDAR` / `PERSONALIZADA`), plan_comercial_id (si es estándar), nombre_plan, módulos, límites (usuarios, activos, plantas, bodegas, almacenamiento_gb), implementacion_uf, mensual_uf, descuento_pct, vigencia_meses, total_uf (calculado), estado (`BORRADOR`, `ENVIADA`, `ACEPTADA`, `RECHAZADA`), pdf_archivo_id, enviada_fecha, aperturas |
| `Contrato` + `Contrato_Version` | lead_id, propuesta_id, version, estado (`BORRADOR`, `ENVIADO`, `VISUALIZADO`, `FIRMADO`, `ANULADO`), motivo_anulacion, pdf_archivo_id, token_hash, token_expira, token_usado, visualizado_fecha, firmado_fecha, firmante_nombre, firmante_rut, firma_ip, firma_user_agent, pdf_sha256 |
| `Reunion` (+ `Reunion_Participante`) | Ver §7 |

**Uso de la demo:** sale de contar en las tablas reales del cliente demo (activos, OT, programaciones, checklists…) con un SP de consumo. Reutiliza `Suscripcion_Consumo` si ya calcula lo mismo. ≥ 80 % del límite se marca en ámbar.

**Datos sensibles:**
- El token de firma y el de reunión se guardan **hasheados** (32 bytes aleatorios, SHA-256).
- La clave temporal de la demo nunca se guarda en texto plano.
- El usuario demo queda con «debe cambiar contraseña» = 1.

---

## 5. Backend: `WebService/WsComercial.asmx`

Métodos mínimos. Cada uno valida sesión y permiso por facultad, menos los públicos:

- **Resumen:** `Resumen()`
  - KPIs: leads (NUEVO + CONTACTADO + CALIFICADO), demos activas, propuestas (PROPUESTA + NEGOCIACIÓN), contratos, concretados.
  - Bloques de «Requiere atención»: demos que vencen en ≤ 3 días o vencidas, leads nuevos sin ejecutivo, contratos enviados sin abrir.
  - Próximas acciones de hoy del ejecutivo.
- **Pipeline:** `Pipeline(filtro, texto, ejecutivoId, pagina)`, `Tablero(...)`.
- **Clientes:** `Clientes(filtro, texto)`, con suscripción, plan, renovación y uso de usuarios.
- **Ficha y actividad:**
  - `Ficha(leadId)` devuelve cabecera, etapa, información, demo con consumo, propuesta, contrato con versiones y timeline.
  - `AsignarEjecutivo`, `CambiarEstado`, `MarcarPerdido(leadId, motivo)`.
  - `RegistrarActividad(leadId, tipo, detalle)`, `GuardarProximaAccion`.
- **Demo:**
  - `CrearDemo(leadId, dias, planDemoId, modulos, limites)` crea en una transacción la empresa demo, la planta, la bodega y el usuario principal con clave temporal. Envía el correo L2 y registra la actividad.
  - `ExtenderDemo(leadId, dias)`, `ReenviarCredenciales(leadId)`.
- **Propuesta:**
  - `CalcularPropuesta(...)` devuelve el total en vivo.
  - `GuardarPropuesta(..., enviar)` genera el PDF y, si `enviar`, manda el correo.
  - `NuevaVersionPropuesta`.
- **Contrato:**
  - `GenerarContrato(leadId, propuestaId)` crea el PDF, el token y el correo L3.
  - `ReenviarContrato`, `NuevaVersionContrato`, `AnularContrato(motivo)`.
- **Públicos, sin sesión:**
  - `CrearLeadPublico(...)`: honeypot + límite por IP + consentimiento obligatorio. Envía el correo L1.
  - `ContratoPorToken(t)`: marca VISUALIZADO la primera vez.
  - `FirmarContrato(t, nombre, rut, acepto)`:
    - valida RUT (módulo 11), token vigente y no usado;
    - calcula SHA-256 del PDF y guarda IP y user-agent;
    - marca el token usado, lead CONCRETADO y crea Cliente + Suscripción activa con los SPs existentes;
    - envía el correo L4 con el PDF firmado.
  - `SolicitarNuevoEnlace(t)`.
- **Tarea programada:** `VencerDemos` (diaria) pasa a VENCIDA, bloquea el acceso del cliente demo sin borrar datos y registra la actividad. Reutiliza el mecanismo de `Suscripcion_Bloqueo_Log` si aplica.

### Páginas públicas

- Usan `Publico.master`: sin sidebar, header mínimo SIGMA + Código Creativo.
- `Firma.aspx?t=` tiene estados `pendiente`, `firmado`, `vencido`, `usado` e `invalido`. Copia exacta de `Firma.dc.html`, y debe verse bien a 375 px.

### Primer ingreso

- `J-Clave.dc.html`: si el usuario tiene «debe cambiar contraseña», `Login.aspx` redirige a la variante de cambio obligatorio y no deja saltarla.
- Reglas en vivo: ≥ 10 caracteres, mayúscula y minúscula, número, símbolo, distinta a la temporal, ambas coinciden.

---

## 6. Front: `View/Comercial/CentroComercial.aspx` + `Js/sigma-centro-comercial.js`

- **Pestañas:** Resumen · Pipeline · Clientes, con `?tab=` para enlazar directo. Lista/Tablero se recuerda por usuario.
- **KPIs:**
  - cada KPI es un `<button>` que filtra el Pipeline;
  - Concretados va a Clientes;
  - los chips de estado no cambian su contador al filtrar.
- **Ficha (drawer 600 px):**
  - cabecera con código, empresa y chip de estado;
  - contacto con copiar correo;
  - botón turquesa **«Agendar reunión»**;
  - stepper Lead → Demo → Propuesta → Contrato → Cliente;
  - aviso del siguiente paso;
  - secciones colapsables;
  - timeline con «Agregar actividad» en línea: tipo + texto + Registrar;
  - barra inferior: Marcar perdido (rojo, pide motivo en línea) · acción de contorno · **una** acción morada según la etapa (Crear demo / Crear propuesta / Generar contrato / Reenviar para firma).
- **Crear demo y Crear propuesta:**
  - reemplazan la ficha con «Volver a la ficha»;
  - al confirmar vuelven a la ficha, muestran un toast y refrescan la fila.
- **Colores por estado comercial:**

| Estado | Tono del chip |
|---|---|
| NUEVO | blue |
| CONTACTADO / CALIFICADO | cyan |
| DEMO / PROPUESTA / NEGOCIACIÓN | purple |
| CONTRATO | warning |
| CONCRETADO | success |
| PERDIDO | gris |
| Demo vence ≤ 3 días | warning |
| Demo vencida | danger |
| Contrato BORRADOR | gris |
| Contrato ENVIADO | blue |
| Contrato VISUALIZADO | cyan |
| Contrato FIRMADO | success |
| Contrato ANULADO | danger |

- **Componentes nuevos:** chip de estado comercial, stepper, barra de consumo, ítem de timeline y selector segmentado.
  - Van en `Css/` y en un JS reutilizable, no dentro de la página.
  - Estados exactos en `Componentes.dc.html`.

---

## 7. Reuniones con el lead — **sin costo**

**Decisión:** no se integra Microsoft Teams, porque Código Creativo no tiene Microsoft 365 empresa. Tampoco se construye video ni streaming dentro de SIGMA: Azure Communication Services, Azure AI Speech, JaaS o un servidor Jitsi propio tienen costo. **La videollamada se hace en Jitsi Meet** (gratis): la sala vive fuera de SIGMA, y SIGMA hace dos cosas: **agenda por correo** y **registra el resultado en la ficha**.

### 7.1 Agendar reunión (`fase = agendar` de `Reunion.dc.html`)

- Se abre desde el botón turquesa «Agendar reunión» de la ficha (drawer 600 px).
- Campos:
  - fecha (calendario SIGMA), hora (combo SIGMA) y duración (30 / 45 / 60);
  - participantes: contactos del lead más agregar por correo; quien organiza recibe copia;
  - **Dónde:** Videollamada · Presencial · Teléfono;
  - motivo.
- **Videollamada (por defecto) = Jitsi Meet:**
  - Al abrir el drawer, SIGMA genera la sala: `https://meet.jit.si/SIGMA-<empresa-sin-espacios>-<6 caracteres aleatorios>`. Usa `RandomNumberGenerator`, para que el nombre sea difícil de adivinar.
  - Es solo una URL: sin API, sin cuenta de servicio, sin costo.
  - **Nueva sala** genera otro nombre. El campo es editable: si prefieren Meet o Zoom, se pega ese enlace.
  - Se guarda en `Reunion.enlace` y va en el botón del correo L5 y en el `.ics` (`LOCATION` y `URL`).
  - El cliente entra desde el navegador, sin cuenta. Quien organiza debe iniciar sesión en Jitsi para abrir la sala; verifica en meet.jit.si cómo funciona hoy antes de implementarlo.
  - No se incrusta Jitsi dentro de SIGMA: meet.jit.si ya no permite incrustarlo en otro sitio. El botón «Unirme» abre la sala en otra pestaña.
- **Presencial:** dirección. **Teléfono:** se muestra el número del lead.
- Muestra la vista previa del correo.
- **Enviar invitación**:
  - manda el correo L5 a cada participante con un adjunto **`.ics`** (texto iCalendar armado en C#, sin librerías pagas), así se agrega a su calendario;
  - crea la `Lead_Actividad` tipo REUNION en estado AGENDADA;
  - deja la próxima acción del lead en esa fecha.

### 7.2 Registrar reunión (`fase = registrar`)

- Cuando pasa la hora de la reunión, «Requiere atención» muestra «Reunión sin registrar».
- Contenido:
  - **notas o transcripción pegada** (opcional; si la herramienta usada la entrega, se pega aquí);
  - resumen, acuerdos (checklist editable), objeción principal (Precio, Plazo, Funcionalidad, Otra);
  - próxima acción (tipo + fecha);
  - datos para la propuesta (descuento, vigencia, módulos).
- **Aplicar a la propuesta** precarga esos datos en Crear propuesta.
- **Guardar en la ficha** deja la actividad REUNION en estado REALIZADA.
- **Todo se completa a mano.** No hay transcripción automática ni resumen con SIGMA AI: ambos requieren servicios con costo.

### 7.3 Tablas

- `Reunion`: lead_id, actividad_id, fecha_inicio, duracion_min, lugar (`VIDEO` / `PRESENCIAL` / `TELEFONO`), enlace, direccion, estado (`AGENDADA` / `REALIZADA` / `CANCELADA`), notas, resumen, acuerdos_json, objecion, creada_por.
- `Reunion_Participante`: reunion_id, nombre, correo, es_organizador, invitacion_enviada.

### 7.4 Privacidad

- Las notas pueden traer datos personales: retención configurable en `Config_Comercial` (sugerido: 12 meses).
- Si alguna vez se pega una transcripción, se debe haber avisado a los participantes.

## 8. Orden de implementación (un bloque = un commit, cerrar cada uno con `sigma-cerrar-bloque`)

1. Migraciones 454+ y SPs de Lead, Actividad y Config, más el menú `COMERCIAL › Centro Comercial`.
2. `CrearLeadPublico` + cambio de `Inicio.aspx` (fuera `mailto:`) + correo L1.
3. Centro Comercial: Resumen, Pipeline (lista y tablero) y Clientes, con datos reales.
4. Ficha en drawer: información, timeline, actividad en línea, asignar ejecutivo, marcar perdido.
5. Demo: crear, consumo, extender, reenviar, vencimiento diario, correo L2 + cambio obligatorio de contraseña (J).
6. Propuesta: estándar/personalizada, total en vivo, PDF, correo.
7. Contrato: versiones, token, página pública de firma (H/I), evidencia SHA-256/IP/UA, alta de Suscripción, correos L3 y L4.
8. Reuniones (§7): agendar con sala de Jitsi Meet + correo + `.ics`, y registrar a mano.

**Tras cada bloque:**

- `aspnet_compiler -v /Check -p Web/Intranet …`;
- SQL con `Dev/sql_aplicar.py`;
- revisar a 1440 y 1280 px (las páginas públicas también a 375 px);
- comparar con el artboard correspondiente.

---

## 9. Criterios de aceptación

1. El sidebar muestra un solo ítem nuevo: `COMERCIAL › Centro Comercial`.
2. Enviar el formulario de `Inicio.aspx` crea un Lead NUEVO, avisa a comercial y aparece en «Requiere atención» si no tiene ejecutivo.
3. Cada KPI filtra el pipeline en 1 clic; Concretados abre Clientes.
4. Toda creación o edición ocurre en drawer. No hay ningún modal en el módulo.
5. La ficha muestra solo las secciones que existen y una sola acción morada según la etapa.
6. Crear demo crea empresa, usuario y clave temporal, y envía el correo. El primer ingreso obliga a cambiar la clave.
7. La barra de consumo usa turquesa bajo 80 % y ámbar desde 80 %. «Vence en ≤ 3 días» y «Vencida» aparecen en Resumen.
8. El total de la propuesta se recalcula en vivo (implementación + mensual con descuento × vigencia) y coincide con el PDF.
9. El enlace de firma es de un solo uso y con vencimiento. Visualizar marca VISUALIZADO.
10. Firmar guarda SHA-256 del PDF, IP, user-agent, nombre y RUT validado; crea Cliente + Suscripción y envía el PDF firmado.
11. Los estados vencido, usado e inválido muestran su página propia, con la salida correcta.
12. «Agendar reunión» envía el correo L5 con `.ics` a cada participante y deja la próxima acción en la fecha. Por defecto se crea una sala de Jitsi Meet única; el enlace se puede reemplazar por uno de Meet o Zoom.
13. «Registrar reunión» guarda notas, resumen, acuerdos, objeción y próxima acción. «Aplicar a la propuesta» precarga descuento, vigencia y módulos. No se agrega ningún servicio con costo.
14. Todo cumple el Estándar de UI de `CLAUDE.md`, en español de Chile, con «activo» (nunca «equipo») para los bienes mantenibles.

## 10. Fuera de alcance

- Modo oscuro.
- Integración con Microsoft Teams (no hay licencia de Microsoft 365 empresa).
- Video o streaming dentro de SIGMA y transcripción automática (tienen costo).
- Resumen automático de reuniones con SIGMA AI (requiere un modelo de lenguaje con costo).
- App Flutter.
- Facturación electrónica (SII).
- Firma electrónica avanzada (se implementa firma electrónica simple con evidencia).
- Integraciones con CRMs externos.
