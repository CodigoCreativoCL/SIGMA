# SIGMA — instrucciones para Claude

Punto de entrada del proyecto: `MD/SIGMA_ESTADO_DESARROLLO.md` (estado, decisiones, trampas y bitácora). Se lee antes de escribir código y se actualiza al cerrar cada bloque.

## Estándar de UI — obligatorio en toda vista, modal, ficha o componente nuevo

**Fuente:** `Fase 2/Diseno/Planificacion360/SIGMA-Paleta-UI-Propuesta.html` (paleta extraída del logo). Antes de diseñar o modificar una pantalla, léela; si algo de esta sección no alcanza, manda ese archivo.

### Tokens (no repetir hex sueltos: declarar estas variables y usarlas)

| Token | Color | Uso |
|---|---|---|
| `--sigma-purple` | `#6732F4` | Acción principal (CTA), pestaña activa, valor destacado |
| `--sigma-purple-dark` | `#4820C9` | Hover del primario |
| `--sigma-purple-soft` | `#F2EFFF` | Chips, selección, zonas de apoyo |
| `--sigma-blue` | `#087BEA` | Enlaces, botones de contorno, información |
| `--sigma-blue-dark` | `#0565C2` | Hover de enlaces/contorno |
| `--sigma-blue-soft` | `#EAF4FF` | Hover de contorno, chips informativos |
| `--sigma-cyan` | `#16C6C9` | Gráficos, anillos, bordes, **foco**; nunca con texto blanco |
| `--sigma-cyan-dark` | `#007F8A` | Botón secundario (texto blanco); hover `#006872` |
| `--sigma-cyan-soft` | `#E8FBFB` | Estados informativos, foco suave, notas |
| `--ink` | `#17223B` | Texto principal y números de KPI |
| `--muted` | `#68738A` | Texto secundario |
| `--line` | `#E2E7F0` | Bordes y separadores |
| `--surface` / `--canvas` | `#FFFFFF` / `#F4F6FA` | Cards / fondo de página |
| `--success` / `--warning` / `--danger` | `#16855B` / `#B65C00` / `#C7352B` | Estados semánticos |

### Botones — el color lo decide la FUNCIÓN, y es el mismo en todo SIGMA
- **Primario (morado):** la acción principal del grupo. Ej.: Guardar, Publicar, **Generar OT**.
- **Secundario (turquesa oscuro, texto blanco):** la acción paralela. Ej.: **Reprogramar**, Versiones.
- **Contorno (azul):** navegar/abrir. Ej.: **Abrir plan**, Ver detalle, Ver calendario.
- **Ghost (morado suave):** Cancelar / cerrar.
- **Peligro (rojo):** solo acciones destructivas (Eliminar). El rojo nunca se usa para "variar".
- Máximo **una acción morada y una turquesa por grupo**. Deshabilitado = opacidad ~.42 y `cursor:not-allowed`, sin cambiar color.
- Radio 9–10 px, peso 700, 13 px.

### Contenedores y lectura
- **Cards blancas y neutras** (borde `--line`, radio 14 px, sombra suave). El color va en iconos, chips y acciones, no en el fondo de la card.
- **KPIs:** icono en fondo suave (purple/cyan/blue/warning-soft), número en tinta oscura (`--ink`), nunca el número en color.
- **Chips:** fondo suave + texto del tono (`purple`, `cyan`, `blue`, `warning`), pill, 11–12 px, peso 800.
- **Estados de negocio** (vencida, atrasada, parada…) usan los semánticos, no la marca: morado **nunca** para alertas o errores.

### Navegación y formularios
- **Pestaña activa:** texto morado + subrayado de 3 px morado. Inactivas en `--muted`.
- **Foco:** anillo turquesa `outline: 3px solid rgba(22,198,201,.27)` y borde `--sigma-cyan-dark`. El morado marca *ubicación*, el turquesa marca *foco*.
- Etiquetas de campo 11 px, peso 800, `#4A556D`; inputs con borde `#CFD6E3` y radio 9 px.

### Evitar
- Texto blanco sobre turquesa claro.
- Alternar colores sin significado ("arcoíris").
- Morado para alertas críticas o errores.
- **Degradados en cabeceras de pantalla:** la guía los sugiere, pero Bryan los rechazó en Planificación 360 (26-09-2026). No usarlos salvo que él lo pida.

### Modales y fichas
Mismas reglas: la ficha en `Simple.master` (vía `SigmaModal.open`) usa cards blancas, un primario morado para guardar, secundario turquesa si hay acción paralela y ghost para cancelar.

## Convenciones técnicas que no se deben romper
- Archivos en **UTF-8 con BOM y CRLF** (`_scratch/bom.py`), o los acentos salen rotos.
- Dentro del `<form>` del master, **todo `<button>` lleva `type="button"`** salvo que deba enviar.
- Compilar con `aspnet_compiler -v /Check -p Web/Intranet …` tras tocar C#; SQL con `_scratch/aplicar_sql.py` (con `-I` si el SP usa `FOR XML` o índices filtrados).
- Menús nunca se borran: `mnu_visible = 0`.
