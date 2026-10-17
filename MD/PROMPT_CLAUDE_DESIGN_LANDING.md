# Prompt para Claude Design — Modernización de la landing pública de SIGMA

Adjunta las 5 capturas (Inicio, Planes, Componentes, Quiénes somos, formulario de asesoría) y pega esto:

---

Rediseña la **landing pública de SIGMA** (Sistema Integrado de Gestión de Mantenimiento Industrial, de Código Creativo). Es la página que ve cualquier visitante antes de iniciar sesión. Las capturas adjuntas son el estado actual. Quiero una modernización de nivel: que se vea como un producto SaaS industrial premium, no como una plantilla.

## Qué es la página hoy
Una sola página con navegación por secciones (botones Inicio · Planes · Componentes · Quiénes somos, y botón «Ingresar» que lleva a Login.aspx):
1. **Inicio (hero):** fondo oscuro, titular «El mantenimiento industrial, bajo control.», bajada, CTA «Ingresar a SIGMA» y «Ver los planes», nota «¿Problemas para entrar? Contacta al administrador de tu planta.»
2. **Planes:** tres tarjetas sobre la misma plataforma — Básico (9 UF/mes, 90 UF/año, ahorra 17%), Medio (22 UF, «MÁS ELEGIDO»), Full (45 UF) — con chips de límites (plantas, usuarios, activos, GB), lista «Todo lo de X, más:» y botón «Comenzar». Nota al pie sobre app móvil y período de gracia.
3. **Formulario «Asesoría sin costo»** (bajo Planes): panel oscuro con beneficios (demo personalizada, acompañamiento, migración de activos y datos, respuesta en 1 día hábil) + formulario: nombre*, apellido, correo corporativo*, teléfono, empresa*, rubro, cargo, país, RUT, n.º de activos aprox., plan de interés, cuéntanos tu operación, consentimiento*.
4. **Componentes:** lista de módulos en filas desplegables — Control de activos, Centro de mantenimiento, Pautas de inspección, Inventario, Terceros y permisos, SIGMA AI, App móvil y sincronización.
5. **Quiénes somos:** «Hecho por Código Creativo», dos párrafos, tres valores (Pensado para terreno, Anticiparse no reaccionar, Accesible e inclusivo) y tarjeta «Nuestra misión» con 4 cifras (1 plataforma, 3 planes, +8 módulos, IA).
6. Footer con Contacto.

## Qué quiero que logres
- **Hero con impacto:** reemplazar el hero de solo texto por una composición con una **vista previa real del producto** (mockup de la web: panel/Centro de Planificación, y de la app móvil en terreno) flotando con profundidad. Que se entienda en 5 segundos qué hace SIGMA.
- **Prueba de valor:** franja de métricas/beneficios concretos (OT, activos, checklists, inventario, indicadores) y un bloque de «cómo funciona» en 3 pasos (del escritorio a la planta, y de vuelta).
- **Componentes:** pasar de lista plana a una cuadrícula/bento de módulos con ícono, una línea de valor y mini-ilustración del módulo; SIGMA AI y la app móvil destacados como módulos de SIGMA (nunca como productos aparte).
- **Planes:** tabla comparativa clara, toggle mensual/trimestral/anual, plan Medio resaltado, precios en UF con equivalencia en CLP como nota secundaria.
- **Formulario:** en pasos o más compacto, con validación visible, estados (error, enviando, éxito) y el consentimiento bien resuelto. Mantener los mismos campos.
- **Quiénes somos:** más humano y con confianza (cifras, valores, misión); sin relleno.
- **Movimiento:** microinteracciones sutiles (reveal al hacer scroll, hover en tarjetas, nav que marca la sección activa). Respetar `prefers-reduced-motion`.
- **Detalle de ingeniería:** hoy las secciones aparecen vacías hasta que corre una animación; el contenido debe verse siempre aunque la animación falle.

## Identidad (obligatoria)
Paleta de SIGMA, sacada del logo:
- Morado primario `#6732F4` (hover `#4820C9`, suave `#F2EFFF`) — acción principal y valor destacado.
- Azul `#087BEA` (hover `#0565C2`, suave `#EAF4FF`) — enlaces e información.
- Cian `#16C6C9` — acentos, anillos, foco; **nunca con texto blanco**. Cian oscuro `#007F8A` para botón secundario.
- Tinta `#17223B` (texto), `#68738A` (secundario), líneas `#E2E7F0`, lienzo `#F4F6FA`, tarjetas `#FFFFFF`.
- Estados: éxito `#16855B`, alerta `#B65C00`, error `#C7352B`.
- Se mantiene el hero oscuro con halos morado/cian y el resto de secciones claras. **Sin degradados en cabeceras de tarjetas**; el degradado se reserva al acento del titular.
- Tipografía geométrica sans actual (la de las capturas) o equivalente; etiquetas de campo 11 px peso 800; inputs con borde `#CFD6E3` y radio 9 px.

## Reglas de contenido
- Español de Chile, tono profesional y cercano. No inventes clientes, logos, testimonios ni cifras que no estén arriba; usa marcadores claros si necesitas ilustrar.
- Nada de «supervisor» o «técnico» como cargos fijos; habla de la facultad o la acción.
- Accesibilidad: contraste AA, foco visible, navegación por teclado, la página destaca «lectura en voz alta e inclusión».
- Responsive real: 375 px (móvil), 768 px y 1440 px; sin scroll horizontal.

## Entregable
Diseño de la página completa en desktop y móvil, con los estados del formulario y el hover de las tarjetas de planes. Después lo implementaré en ASP.NET WebForms (`Inicio.aspx`, HTML/CSS/JS propios, sin frameworks pesados), así que prefiere estructuras simples: secciones, grid/flex, variables CSS (`--sigma-*`) y JS vanilla.
