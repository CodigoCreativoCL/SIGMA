# Brief para Claude Design — Centro Comercial de SIGMA

> Pegar este documento completo en Claude Design como primer mensaje y adjuntar los archivos de la sección 9.
> Objetivo: propuesta visual (no código productivo) del módulo comercial. Debe parecer «SIGMA ahora tiene capacidades comerciales», nunca «un CRM pegado a SIGMA».

---

## 1. Qué es SIGMA

SIGMA es un SaaS B2B chileno de gestión de mantenimiento industrial (activos, OT, planificación, inspecciones, inventario, SIGMA AI y SIGMA Twin como módulos). Web en ASP.NET WebForms con sidebar y topbar fijos; existe también app móvil Flutter (fuera de alcance aquí).

Usuario de este diseño: **ejecutivo comercial de Código Creativo** (empresa dueña de SIGMA), que acompaña a un prospecto desde el formulario web hasta que es cliente con suscripción activa.

## 2. Alcance de la propuesta

Diseñar, en escritorio (1440 px) y validar a 1280 px:

| # | Pantalla / estado | Prioridad |
|---|---|---|
| A | Centro Comercial — pestaña **Resumen** (métricas + alertas de demos por vencer) | Alta |
| B | Centro Comercial — pestaña **Pipeline** (lista/kanban por estado con filtros) | Alta |
| C | **Ficha del Lead** en drawer lateral: cabecera, stepper Lead → Demo → Propuesta → Contrato, acciones contextuales, timeline, información | Alta |
| D | Drawer **Crear Demo** (duración, plan demo, módulos, límites, usuario principal) | Alta |
| E | Sección **Seguimiento de Demo** dentro de la ficha (uso vs. límites, último acceso, actividad) | Alta |
| F | Drawer **Crear Propuesta**: plan estándar vs. personalizado (módulos, límites, precios, descuento, vigencia) | Media |
| G | Sección **Contrato** en la ficha (estados BORRADOR / ENVIADO / VISUALIZADO / FIRMADO / ANULADO, versiones) | Media |
| H | **Página pública de firma** `/firma/contrato/{token}` (sin sidebar, foco único en firmar) | Alta |
| I | Estados de la página de firma: firmado OK, enlace vencido, enlace ya usado | Media |
| J | **Cambio obligatorio de contraseña** en primer ingreso (variante del Login actual) | Media |
| K | Centro Comercial — pestaña **Clientes** (concretados con su suscripción) | Baja |
| L | Correos HTML: lead nuevo (a comercial), credenciales demo, contrato para firmar, contrato firmado | Baja |

## 3. Reglas de experiencia (no negociables)

1. **Un solo menú** en el sidebar: `COMERCIAL › Centro Comercial`. Nada de menús Leads/Demos/Propuestas/Contratos.
2. **Solo drawer lateral, sin modales.** Toda creación/edición abre un cajón a la derecha; la lista sigue visible detrás y se actualiza al instante.
3. **Pocos clics:** de una métrica o alerta se llega al lead en 1 clic; las acciones aparecen según el estado (divulgación progresiva: la ficha muestra Demo/Propuesta/Contrato solo cuando existen).
4. **Sin recorridos guiados (tours).**
5. **Mensajes genéricos por facultad**, nunca por rol («Puedes crear demos», no «el supervisor…»).
6. Fechas con el calendario propio de SIGMA (no el date-picker del navegador); combos con el combo propio (buscable).
7. Español de Chile, montos en CLP y/o UF.

## 4. Sistema visual de SIGMA

**Tipografía:** Sora (Google Fonts). **Iconos:** Material Symbols (Material 3). Modo claro y oscuro.

### Tokens

| Token | Color | Uso |
|---|---|---|
| `--sigma-purple` | `#6732F4` | Acción principal, pestaña activa, valor destacado |
| `--sigma-purple-dark` | `#4820C9` | Hover del primario |
| `--sigma-purple-soft` | `#F2EFFF` | Chips, selección, zonas de apoyo |
| `--sigma-blue` | `#087BEA` | Enlaces, botones de contorno, información |
| `--sigma-blue-dark` | `#0565C2` | Hover contorno |
| `--sigma-blue-soft` | `#EAF4FF` | Chips informativos |
| `--sigma-cyan` | `#16C6C9` | Gráficos, anillos, **foco** (nunca con texto blanco) |
| `--sigma-cyan-dark` | `#007F8A` | Botón secundario (texto blanco) |
| `--sigma-cyan-soft` | `#E8FBFB` | Notas, info suave |
| `--ink` | `#17223B` | Texto principal y números KPI |
| `--muted` | `#68738A` | Texto secundario |
| `--line` | `#E2E7F0` | Bordes |
| `--surface` / `--canvas` | `#FFFFFF` / `#F4F6FA` | Cards / fondo |
| `--success` / `--warning` / `--danger` | `#16855B` / `#B65C00` / `#C7352B` | Estados semánticos |

### Botones (el color lo da la función)
- Primario morado = acción principal (Crear demo, Enviar propuesta, Firmar contrato).
- Secundario turquesa oscuro = acción paralela (Reenviar credenciales, Nueva versión).
- Contorno azul = navegar/abrir (Ver ficha, Ver PDF).
- Ghost morado suave = Cancelar/cerrar.
- Rojo solo destructivo (Anular contrato, Marcar perdido).
- Máximo 1 morado + 1 turquesa por grupo. Radio 9–10 px, peso 700, 13 px. Deshabilitado = opacidad .42.

### Contenedores
- Cards blancas neutras, borde `--line`, radio 14 px, sombra suave. El color va en iconos/chips, no en el fondo.
- KPI: icono sobre fondo suave, número en `--ink` (nunca el número en color).
- Chips: pill, fondo suave + texto del tono, 11–12 px, peso 800.
- Pestaña activa: texto morado + subrayado 3 px morado. Foco: anillo turquesa `3px rgba(22,198,201,.27)`.
- Etiquetas de campo 11 px peso 800 `#4A556D`; inputs borde `#CFD6E3` radio 9 px.

### Prohibido
- **Degradados en cabeceras.**
- Morado para alertas o errores.
- «Arcoíris» de colores sin significado; exceso de cards; look de CRM genérico (Salesforce/HubSpot).
- Modales.

### Colores por estado comercial (propuesta a validar)

| Estado | Tono chip |
|---|---|
| NUEVO | blue |
| CONTACTADO / CALIFICADO | cyan |
| DEMO / PROPUESTA / NEGOCIACIÓN | purple |
| CONTRATO | warning |
| CONCRETADO | success |
| PERDIDO | muted (gris) |
| Demo vence ≤ 3 días / vencida | warning / danger |

## 5. Flujo a representar

```
Formulario web (inicio.aspx) → LEAD (NUEVO) → correo a comercial@codigocreativo.cl
 → Ejecutivo asignado → CONTACTADO → CALIFICADO
 → [Crear Demo] → usuario + clave temporal por correo → DEMO (7 días, límites)
 → seguimiento de uso → alertas «vence en 3 días / mañana / vencida»
 → [Crear Propuesta] estándar o personalizada → PDF → PROPUESTA → NEGOCIACIÓN
 → [Generar Contrato] → token seguro → correo «Revisar y firmar» → CONTRATO
 → Página pública de firma → FIRMADO (hash SHA-256, IP, user-agent)
 → CONCRETADO → Cliente + Suscripción activa → correo con PDF firmado
```

## 6. Contenido de ejemplo (usar datos realistas)

- Lead: **Hamburgo S.A.** · Juan Pérez · Jefe de Mantenimiento · juan.perez@hamburgo.cl · +56 9 8765 4321 · Interés: Mantenimiento, OT, SIGMA AI.
- Métricas Resumen: Leads 24 · Demos 7 · Propuestas 5 · Contratos 3 · Concretados 12.
- Demo: ACTIVA · inicio 15/10/2026 · expira 22/10/2026 · Usuarios 1/2 · Activos 7/10 · OT 12/20 · Programaciones 2/5 · Checklists 3/5 · Último acceso 15/10/2026 18:42.
- Límites demo por defecto: 7 días, 2 usuarios, 10 activos, 20 OT, 5 programaciones, 5 checklists, 20 repuestos, 1 bodega, 1 planta.
- Propuesta: Plan Enterprise · Implementación 45 UF · Mensualidad 18 UF · Descuento 10 % · Vigencia 12 meses.
- Timeline: 15 OCT Lead recibido · 15 OCT Email a comercial · 15 OCT Ejecutivo asignado · 16 OCT Primer contacto (llamada) · 17 OCT Demo creada · 18 OCT Demo utilizada · 20 OCT Propuesta enviada · 22 OCT Contrato generado · 23 OCT Contrato firmado · 23 OCT Cliente activado.
- Actividad manual: tipos Llamada / Email / Reunión / Nota.

## 7. Detalle por pantalla

**A. Resumen** — Header del Centro (mismo estilo que el Centro de Planificación: título, subtítulo, pestañas Resumen · Pipeline · Clientes). Fila de 5 KPIs clicables (filtran el pipeline). Debajo, bloque «Requiere atención»: demos por vencer, leads nuevos sin ejecutivo, contratos enviados sin abrir. Sin gráficos decorativos.

**B. Pipeline** — Barra de filtros (chips de estado: Todos, Nuevos, Demo, Propuesta, Contrato… + buscador + ejecutivo). Tabla densa estilo SIGMA: empresa/contacto, estado (chip), ejecutivo, última actividad, próxima acción, días en el estado. Proponer opcionalmente vista kanban alternable. Clic en fila → drawer C.

**C. Ficha del Lead (drawer ~560–640 px)** — Cabecera: empresa, contacto, cargo, correo, chip de estado. Stepper horizontal Lead → Demo → Propuesta → Contrato → Cliente. Acción principal según estado (una sola morada). Secciones colapsables que aparecen solo si existen: Información, Demo, Propuesta, Contrato. Timeline vertical con «Agregar actividad» en línea (no modal).

**D. Crear Demo** — Drawer apilado o reemplazando la ficha con «volver». Campos: duración (días), plan demo (combo), módulos (chips seleccionables), límites (precargados desde configuración, editables), usuario principal (precargado del lead). Resumen final: «Se creará la empresa, el usuario y se enviarán credenciales a juan.perez@hamburgo.cl».

**E. Seguimiento de demo** — Barras de consumo uso/límite (cyan; warning al ≥ 80 %), días restantes, último acceso, actividad (logins, activos, OT, checklists, módulos usados). Acciones: Extender demo (secundario), Reenviar credenciales (contorno).

**F. Crear Propuesta** — Selector segmentado Estándar | Personalizado. Personalizado: nombre, módulos (Mantenimiento, OT, Planificación, Inspección, Inventario, SIGMA AI, SIGMA Twin — AI y Twin siempre como módulos de SIGMA), límites (usuarios, activos, plantas, bodegas, almacenamiento), precios (implementación, mensual, anual), descuento, vigencia. Panel de total en vivo. Acciones: Generar PDF (contorno) · Enviar propuesta (primario).

**G. Contrato** — Versión, fecha, estado con chip, lista de versiones, ver PDF, reenviar, anular (rojo). Indicador «Visualizado por el cliente el …».

**H. Firma pública** — Sin sidebar; header mínimo con logo Código Creativo / SIGMA. Visor del PDF a la izquierda (o arriba en móvil), panel derecho: cliente, plan, monto, checkbox «He leído y acepto», nombre, RUT, botón «Firmar contrato» (morado). Mensaje de seguridad discreto (enlace personal, vence el …). Debe verse bien en móvil (375 px).

**I. Estados de firma** — Éxito (check success, «Te enviamos una copia a…», descargar PDF), vencido, ya usado, inválido.

**J. Cambio de contraseña obligatorio** — Misma estética del Login actual; reglas de clave visibles en vivo; no permite saltar el paso.

**L. Correos** — Ancho 600 px, fondo blanco, un botón morado, sin imágenes pesadas.

## 8. Entregables pedidos a Claude Design

1. Pantallas A–J en alta fidelidad, modo claro; A, B y C también en modo oscuro.
2. Página H en escritorio y móvil.
3. Hoja de componentes nuevos usados (chip de estado comercial, stepper, barra de consumo, ítem de timeline, selector segmentado) con sus estados.
4. Notas breves de interacción (qué abre cada clic).

## 9. Archivos a adjuntar en Claude Design

- `Fase 2/Evidencias Proyecto/Diseno/2_Diseno_Web/Redisenos/Planificacion360/SIGMA-Paleta-UI-Propuesta.html` (paleta oficial).
- Capturas actuales de SIGMA a 1440 px (empresa Hamburgo), carpeta `capturas/`:
  - `01_inicio_landing.png` — landing pública completa (origen del lead).
  - `02_login.png` — base para la pantalla J (cambio de contraseña).
  - `03_home_sidebar_topbar.png` — sidebar, topbar y cards; el sidebar **ya tiene un grupo «Comercial»** donde colgar el Centro Comercial.
  - `04_centro_planificacion_header_pestanas.png` — **referencia principal del Centro Comercial**: header oscuro, pestañas con icono + subtítulo, buscador, chips de filtro con contador y alternar Lista/Tarjetas (la tabla aparece cargando, con skeleton).
  - `07_drawer_kpanel_abierto.png` — **patrón de drawer (K.Panel)**: cabecera con código + título, bloques de datos en tarjetas grises y barra inferior de acciones (ghost · contorno azul · secundario turquesa).
  - `05_tabla_ordenes_chips.png` — tabla densa con chips de estado.
  - `06_avisos_lista.png` — **header de módulo de referencia** (banda oscura sin degradado, título + subtítulo + acción morada), filtros en chips con contador y filas con acciones.
  - `08_sigma_ai_centro.png` — centro de módulo con KPIs.
- Logo SIGMA / Código Creativo (SVG o PNG).
