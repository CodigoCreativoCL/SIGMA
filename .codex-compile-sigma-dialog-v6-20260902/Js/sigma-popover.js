/* ============================================================================
   SIGMA — popover de detalle

   PARA QUE SIRVE
     Mostrar un texto largo que no cabe en una celda: el motivo de un ajuste
     de inventario, una observacion, el detalle de un rechazo. En la grilla
     queda una lupa; el texto se abre al hacer clic.

   POR QUE NO title=""
     El tooltip del navegador tarda casi un segundo, se va solo, no se puede
     seleccionar para copiar y no admite mas de una linea. Este se abre al
     clic, se queda hasta que se cierra, y el texto se puede copiar.

   POR QUE UN SOLO PANEL Y NO UNO POR FILA
     Una grilla de doscientas filas serian doscientos nodos ocultos. Este se
     crea la primera vez que alguien abre uno, y se reposiciona.

   COMO SE USA DESDE EL SERVIDOR
     <a class="sigma-inv-lupa" href="javascript:void(0)"
        onclick="sgMotivo(this)"
        data-titulo="AJUSTE · DEMO-ROD-6205"
        data-motivo="Linea 1&#10;Linea 2">
       <i class="mdi mdi-magnify"></i>
     </a>

     El separador de lineas es el salto de linea (codigo 10). El texto va
     HtmlEncode al atributo y se inserta con textContent, NUNCA con
     innerHTML: lo escribio un usuario.

   POSITION FIXED, NO ABSOLUTE
     Las grillas tienen overflow propio. Con absolute el panel se corta
     contra el borde de la tabla justo en las ultimas filas, que son las que
     mas se consultan. Con fixed se posiciona contra la ventana y nunca se
     recorta.
   ============================================================================ */

var sgPop = null;

function sgMotivo(el) {
    if (!sgPop) {
        sgPop = document.createElement('div');
        sgPop.className = 'sigma-popover';
        document.body.appendChild(sgPop);
    }

    var abierta = el.className.indexOf('is-abierta') >= 0;

    sgCerrarMotivo();

    // Segundo clic en la misma lupa: cierra y no vuelve a abrir.
    if (abierta) return;

    sgPop.innerHTML = '';

    var titulo = el.getAttribute('data-titulo');

    if (titulo) {
        var t = document.createElement('div');
        t.className = 'titulo';
        t.textContent = titulo;
        sgPop.appendChild(t);
    }

    var lineas = (el.getAttribute('data-motivo') || '').split(String.fromCharCode(10));

    for (var i = 0; i < lineas.length; i++) {
        if (!lineas[i]) continue;

        var d = document.createElement('div');
        d.className = 'linea';
        d.textContent = lineas[i];
        sgPop.appendChild(d);
    }

    sgPop.className = 'sigma-popover is-abierto';
    el.className += ' is-abierta';

    /* Se posiciona DESPUES de mostrarlo: mientras esta oculto no tiene alto
       y no hay como saber si cabe hacia abajo. */
    var r = el.getBoundingClientRect();
    var alto = sgPop.offsetHeight;
    var ancho = sgPop.offsetWidth;

    var top = r.bottom + 6;
    if (top + alto > window.innerHeight - 8) top = r.top - alto - 6;
    if (top < 8) top = 8;

    var left = r.right - ancho;
    if (left < 8) left = 8;

    sgPop.style.top = top + 'px';
    sgPop.style.left = left + 'px';
}

function sgCerrarMotivo() {
    if (sgPop) sgPop.className = 'sigma-popover';

    var abiertas = document.querySelectorAll('.sigma-inv-lupa.is-abierta');

    for (var i = 0; i < abiertas.length; i++)
        abiertas[i].className = abiertas[i].className.replace(' is-abierta', '');
}

/* Cerrar al hacer clic afuera, con Escape, y al desplazar.

   El listener va en document y no en cada lupa: la grilla se repinta en
   cada postback parcial y los listeners de los elementos se perderian. */
document.addEventListener('click', function (e) {
    var n = e.target;

    while (n && n !== document) {
        if (n.className && typeof n.className === 'string' &&
            (n.className.indexOf('sigma-inv-lupa') >= 0 ||
             n.className.indexOf('sigma-popover') >= 0)) return;

        n = n.parentNode;
    }

    sgCerrarMotivo();
});

document.addEventListener('keydown', function (e) {
    if (e.keyCode === 27) sgCerrarMotivo();
});

window.addEventListener('scroll', sgCerrarMotivo, true);
