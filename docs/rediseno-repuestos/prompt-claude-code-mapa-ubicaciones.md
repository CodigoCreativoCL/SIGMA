# Prompt para Claude Code — Mapa por ubicación por niveles (Centro de repuestos)

Rediseña la vista **«Mapa por ubicación»** del Centro de repuestos de SIGMA según la referencia `docs/rediseno-repuestos/sigma-mapa-ubicaciones-referencia.html`. Ábrela en el navegador y pruébala antes de tocar código.

## Cómo quiero que trabajes

1. Lee `CLAUDE.md` y respeta el estándar UI:
   - Paleta: #6732F4, #087BEA, #16C6C9 y #007F8A.
   - Botones por función: primario morado, secundario cyan oscuro, outline azul, ghost, y rojo solo para acciones destructivas.
   - Tarjetas blancas sin borde, con sombra suave. Headers sin degradados.
   - Vocabulario: siempre «activo», nunca «equipo».
2. Antes de editar, lee:
   - `Web/Intranet/Js/sigma-repuesto-mapa.js` (`rack()`, `tarjetaBodega()`, `drawer()`, `mover()`, `planograma()`, `ligar()`);
   - `Web/Intranet/Css/LookAndFeel/sigma-repuesto-centro.css` (clases `rm-*`);
   - `Web/Intranet/View/Inventario/Repuestos/RepuestoCentro.aspx` (`#rcMapa`, `data-rcview="mapa"`);
   - `WebService/WsBodegaMapa.asmx` (`Cargar`, `ReubicarCaja`, `GuardarPosiciones`, `GuardarBodega`, `GuardarUbicacion`).
3. Presenta un plan corto y espera mi OK. El plan debe decir qué cambia en el JS, qué cambia en el CSS y si hace falta algo en el servicio o la base de datos.
4. No cambies la lógica de negocio que ya funciona. Se mantienen igual:
   - mover a otro rack registra un movimiento «cambio de ubicación» (`ReubicarCaja`);
   - el nivel se guarda en el planograma (`GuardarPosiciones`);
   - cada llamada valida sesión y permisos (`permisos.ajuste`, `permisos.bodegas`).
5. Trabaja por pasos. Verifica en escritorio (1440 px) y en móvil (390 px) sin scroll horizontal.

## Problema actual

- Cada rack es una columna alta. Los niveles N4 a N1 aparecen vacíos y casi todo cae en «Sin nivel», así que una lista de 100 repuestos estira el rack hacia abajo.
- Los nombres se cortan («Polea trap…», «Cable TH…») y no se puede saber qué es cada cosa.
- Para encontrar un repuesto hay que recorrer columnas con la vista. No hay una respuesta directa a «¿dónde está?».
- Las alertas (bajo el mínimo / sobre el máximo) son una línea de color entre decenas de filas iguales.

## Diseño propuesto

La pantalla se divide en dos partes: **plano a la izquierda** (qué hay en cada rack, de un vistazo) y **panel a la derecha** (lista legible de lo que hay en el rack o la repisa elegida).

### 1. Barra superior

- **Buscador «¿Dónde está…?»**: busca por código, nombre o fabricante. La tecla `/` lo enfoca.
- Segmentado de bodega: Todas · Bodega Piso 1 · Bodega Piso 2…
- **Chips de estado con conteo**, que reemplazan la leyenda: Todos · Bajo el mínimo · Sobre el máximo · Sin nivel. Son excluyentes; un segundo clic vuelve a «Todos».

### 2. Plano

- Bodega como sección, con encabezado «Bodega Piso 1 · BOD-1 · 7 ubicaciones · FEFO» y a la derecha «140 repuestos · 12 bajo el mínimo · 21 sin nivel».
- Racks agrupados por **pasillo** en una grilla `repeat(auto-fill, minmax(168px, 1fr))`.
- **Cada rack se dibuja como un rack de verdad**:
  - parantes laterales y un larguero entre repisas;
  - niveles de arriba (N4) hacia abajo (N1);
  - cada repisa es una fila: etiqueta N#, un punto por repuesto y el conteo a la derecha.
- **Puntos**: gris = en orden, rojo = bajo el mínimo, ámbar = sobre el máximo. Se muestran máximo 18 por repisa (las alertas primero) y después «+n». Los nombres no se escriben en el plano.
- Debajo del rack, si corresponde, va una pastilla con borde punteado morado: **«17 sin nivel»**. Al hacer clic abre el rack en modo «Asignar niveles».
- Encabezado del rack: código, un badge rojo con la cantidad bajo el mínimo y el total.
- Hay una tarjeta punteada «+ Nueva ubicación» al final, que usa el formulario inline actual (`formUbic`).
- **Con búsqueda o filtro activo**:
  - los puntos que coinciden se ponen morados y el resto casi se apagan;
  - los racks sin coincidencias bajan a 38 % de opacidad;
  - el encabezado del rack muestra un badge morado con la cantidad de coincidencias.

### 3. Panel derecho

Es sticky, con su propio scroll. Tiene cuatro estados.

1. **Resumen**, cuando no hay nada elegido:
   - Caja «N repuestos sin nivel»: lista los racks con más pendientes, con una barra de % que ya tiene nivel. Cada fila abre ese rack en modo asignar.
   - Caja «N bajo el mínimo»: los 6 más críticos (stock / mínimo) con su ubicación «P1-A-R02 · Nivel 3». Cada uno abre el drawer del repuesto. Al final, «Ver los N en el mapa» activa el chip.
2. **Rack**, al hacer clic en un rack o en una repisa:
   - Encabezado: código, «Bodega · Pasillo A · Rack 02 · 4 niveles», cerrar.
   - Cifras: repuestos · bajo el mínimo · sin nivel.
   - Acciones: «Asignar niveles» (primario, solo si hay repuestos sin nivel), «Etiquetas QR» y «Ver en SIGMA Twin».
   - **Barra sticky**: código del rack y saltos N4 · N3 · N2 · N1 · Sin nivel, cada uno con su conteo. En móvil la barra suma el botón cerrar.
   - Llamado morado si hay repuestos sin nivel: «17 repuestos están en este rack pero no se sabe en qué repisa…» con el botón «Asignar».
   - **Una sección por nivel**, de arriba a abajo: «N4 Nivel 4 · arriba · 6 repuestos · 2 bajo el mínimo»; «N1 … · piso».
   - Cada fila muestra: ícono del tipo, **nombre completo** (sin truncar, puede ocupar 2 líneas), «código · fabricante», cantidad con unidad, una mini barra de stock con la marca del mínimo y, si hay alerta, «mín. X» o «máx. X».
   - Orden dentro de cada nivel: primero los que están bajo el mínimo, después alfabético.
   - Repisa vacía: «Repisa vacía · arrastra aquí un repuesto.»
   - Con filtro activo: «Mostrando X de Y por el filtro · Ver todos».
3. **Búsqueda**:
   - Título «Dónde está «correa»», con «14 repuestos en 2 racks».
   - Resultados agrupados por `Bodega › Rack › Nivel`. Al hacer clic en un grupo se abre el rack en ese nivel con la fila resaltada.
   - Las coincidencias se marcan en el texto.
   - Sin resultados: «No está en esta planta» y el botón «Buscar en todas las bodegas» cuando hay una bodega filtrada.
4. **Modo «Asignar niveles»**:
   - Barra de progreso «Asignando niveles · 3 de 17» y el botón «Terminar».
   - La sección «Sin nivel» pasa arriba, y cada fila muestra botones N4 · N3 · N2 · N1 (N4 = arriba).
   - Un clic asigna. La fila sale con animación y aparece el toast «ELE-261 quedó en P1-A-R02 · Nivel 2 · Deshacer».
   - Atajo de teclado: con una fila enfocada, las teclas 1 a N asignan y el foco pasa a la siguiente fila.
   - Al terminar: «Todo P1-A-R02 tiene nivel» y el botón «Listo».

### 4. Drawer del repuesto

Es el `drawer()` actual, reordenado.

- **«Dónde está»** como protagonista:
  - `Planta › Bodega`, el código del rack en grande y el nombre de la ubicación;
  - **«Nivel 3»** en morado a 22 px;
  - a la derecha, un **mini alzado del rack** con la repisa marcada.
- **Existencia**: número grande (rojo o ámbar si hay alerta) y una barra con marcas de mínimo y máximo rotuladas.
- **Mover dentro de la bodega**: select de ubicación más un segmentado de nivel con los niveles del rack destino. El botón «Mover» (secundario) queda deshabilitado si no hay cambio.
- «También está en»: otras bodegas o racks del mismo código.
- Pie: Etiqueta (plain), Mover (secundario), Abrir ficha (primario).

### 5. Mover

- Hay **arrastrar y soltar** desde cualquier fila del panel hacia una sección de nivel del panel o hacia una repisa del plano. La zona destino se resalta en cyan.
- Solo se puede soltar dentro de la misma bodega. Si es otra bodega: «Para llevarlo a otra bodega, registra un traslado.»
- Todo movimiento muestra el toast «quedó en X · Nivel N» con **Deshacer**.
- Mismo rack → solo `GuardarPosiciones`. Otro rack → `ReubicarCaja` y después el planograma, como hoy.

### 6. Móvil (< 900 px)

- Plano en una columna, con el pasillo como etiqueta horizontal y racks en 2 columnas.
- El panel del rack se abre como **bottom sheet** (88 vh) con scrim. Al cerrarlo vuelve el plano.
- El resumen queda debajo del plano.

## Datos

- Todo sale de `WsBodegaMapa.Cargar`, que ya trae `bodegas[].ubicaciones[]`, `saldos[]` (`c`, `n`, `fab`, `q`, `un`, `min`, `max`, `b`, `u`) y `posiciones[]` (`u`, `rep`, `n` = nivel, `p` = posición).
- **Cantidad de niveles por ubicación**: hoy se usa `max(4, nivel más alto)`. Si la tabla de ubicaciones no tiene columna de niveles, propón una en el plan (por ejemplo `ubi_niveles`, por defecto 4) y que se edite en el formulario «Nueva ubicación».
- **Pasillo**: se toma del nombre de la ubicación («Pasillo A · Rack 01»). Si existe un campo propio, úsalo. Si no hay pasillo, todos los racks van a un solo grupo, sin etiqueta.
- La nomenclatura se mantiene configurable, porque SIGMA es multicliente: «Nivel», «Pasillo» y «Rack» no van fijos en el código si ya existe un diccionario de etiquetas.

## Criterios de aceptación

- Con 100 repuestos en un rack, el plano sigue mostrando el rack completo en menos de 220 px de alto, y el panel lista los nombres completos.
- Buscar «correa» responde en el panel «Bodega › Rack › Nivel» sin recorrer el plano.
- Asignar 17 repuestos sin nivel toma 17 clics (o 17 teclas), y cada asignación se puede deshacer.
- Bajo el mínimo y sobre el máximo se distinguen en el plano sin leer texto.
- No hay scroll horizontal a 390 px. El foco es visible y Escape cierra el drawer, luego el rack y luego la búsqueda.
