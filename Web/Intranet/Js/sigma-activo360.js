/* ============================================================================
   EL CENTRO DEL ACTIVO EN EL NAVEGADOR

   Cambiar de seccion, abrir el menu "Mas" y desplegar una orden de trabajo son
   gestos de mirar: el contenido de las trece secciones ya esta en la pagina y
   pedirselo de nuevo al servidor solo agregaria un parpadeo.

   Lo que escribe -filtrar, registrar, generar- sigue yendo por el UpdatePanel.

   Se rearma despues de cada postback asincrono: el UpdatePanel reemplaza el
   HTML y con el se van los listeners.
   ============================================================================ */
(function () {
    'use strict';

    function panelActivo() {
        var h = document.getElementById('hdnSeccion');
        return h && h.value ? h.value : 'resumen';
    }

    function irA(nombre) {
        var tabs = document.querySelectorAll('.sg-a3-tab[data-sec]');
        var ops = document.querySelectorAll('.sg-a3-mas-op[data-sec]');
        var paneles = document.querySelectorAll('.sg-a3-panel');
        var hay = false;

        for (var i = 0; i < paneles.length; i++)
            hay = hay || paneles[i].getAttribute('data-panel') === nombre;

        if (!hay) nombre = 'resumen';

        for (var t = 0; t < tabs.length; t++)
            tabs[t].classList.toggle('es-activa', tabs[t].getAttribute('data-sec') === nombre);

        var extra = null;
        for (var o = 0; o < ops.length; o++) {
            var esta = ops[o].getAttribute('data-sec') === nombre;
            ops[o].classList.toggle('es-activa', esta);
            if (esta) extra = ops[o].textContent.trim();
        }

        /* Si la seccion vive dentro de "Mas", su nombre se escribe al lado del
           boton: sin eso la pantalla no dice donde esta parado uno. */
        var etiqueta = document.getElementById('sgA3MasNombre');
        var boton = document.querySelector('.sg-a3-mas-btn');

        if (etiqueta) etiqueta.textContent = extra ? ' · ' + extra : '';
        if (boton) boton.classList.toggle('es-activa', !!extra);

        for (var p = 0; p < paneles.length; p++)
            paneles[p].classList.toggle('es-activo', paneles[p].getAttribute('data-panel') === nombre);

        var h = document.getElementById('hdnSeccion');
        if (h) h.value = nombre;

        cerrarMas();
    }

    function cerrarMas() {
        var mas = document.querySelector('.sg-a3-mas');
        if (mas) mas.classList.remove('es-abierto');
    }

    function navegacion() {
        var tabs = document.querySelectorAll('.sg-a3-tab[data-sec], .sg-a3-mas-op[data-sec], [data-ir-sec]');

        for (var i = 0; i < tabs.length; i++)
            tabs[i].onclick = function (ev) {
                ev.preventDefault();
                irA(this.getAttribute('data-sec') || this.getAttribute('data-ir-sec'));
            };

        var boton = document.querySelector('.sg-a3-mas-btn');
        if (boton) boton.onclick = function (ev) {
            ev.preventDefault();
            ev.stopPropagation();
            document.querySelector('.sg-a3-mas').classList.toggle('es-abierto');
        };

        /* Un menu que no se cierra al tocar fuera queda tapando la pantalla. */
        document.addEventListener('click', cerrarMas);
        document.addEventListener('keydown', function (ev) { if (ev.keyCode === 27) cerrarMas(); });

        irA(panelActivo());
    }

    /* ---- Las ordenes de trabajo se despliegan en su misma fila ---- */
    function ordenes() {
        var filas = document.querySelectorAll('.sg-a3-ot[data-ot]');

        for (var i = 0; i < filas.length; i++)
            filas[i].onclick = function (ev) {
                /* Un clic en "Abrir OT" navega; el resto de la fila despliega. */
                if (ev.target.closest && ev.target.closest('a, input, button')) return;

                var det = document.getElementById('det-' + this.getAttribute('data-ot'));
                if (!det) return;

                var abierto = det.classList.toggle('es-abierto');
                this.classList.toggle('es-abierta', abierto);
            };
    }

    /* ---- Inspecciones y tareas ----

       La fila se despliega en su lugar y los filtros -tipo, resultado y
       busqueda- son del navegador: pedirle al servidor que filtre una lista
       que ya esta en pantalla es recargarla para esconder filas. */
    function revisiones() {
        var filas = document.querySelectorAll('.sg-a3-rev');
        if (!filas.length) return;

        for (var i = 0; i < filas.length; i++) {
            filas[i].onclick = function (ev) {
                if (ev.target.closest('a, input, button, select')) return;

                var det = document.getElementById('rev-' + this.getAttribute('data-rev'));
                if (!det) return;

                var abierto = det.classList.contains('es-abierto');
                det.classList.toggle('es-abierto', !abierto);
                this.classList.toggle('es-abierta', !abierto);
            };
        }

        var chips = document.querySelectorAll('#sgA3RevTipos a[data-rev-tipo]');
        var buscar = document.getElementById('sgA3RevBuscar');
        var resultado = document.getElementById('sgA3RevResultado');

        /* El estado del filtro se lee del DOM en cada pasada y no de una
           variable: la pagina se repinta por UpdatePanel y una variable
           guardada en el cierre anterior filtra filas que ya no existen. */
        function filtrar() {
            var activa = document.querySelector('#sgA3RevTipos a.es-activa');
            var tipo = activa ? activa.getAttribute('data-rev-tipo') : 'todas';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();
            var res = resultado && resultado.value || '';
            var vivas = document.querySelectorAll('.sg-a3-rev');

            for (var i = 0; i < vivas.length; i++) {
                var f = vivas[i];
                var ok = (tipo === 'todas' || f.getAttribute('data-rev-tipo') === tipo)
                      && (res === '' || f.getAttribute('data-rev-res') === res)
                      && (texto === '' || (f.getAttribute('data-rev-txt') || '').indexOf(texto) !== -1);

                f.classList.toggle('es-oculta', !ok);
            }
        }

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;
        if (resultado) resultado.onchange = filtrar;
    }

    /* ---- Cualquier foto de la pantalla se puede agrandar ----

       La galeria de evidencias ya tenia su visor; la foto del equipo, la del
       componente y la del plan no, y son justo las que alguien acerca a la
       cara para decidir si esa es la maquina. Se reusa el mismo marco y el
       mismo Esc: dos visores distintos en la misma pagina se cierran de dos
       maneras distintas. */
    function ampliables() {
        var fotos = document.querySelectorAll('.sg-a3-foto img, .sg-plan-foto img, [data-ampliar] img, img[data-ampliar]');

        for (var i = 0; i < fotos.length; i++) {
            if (fotos[i].getAttribute('data-listo') === '1') continue;

            fotos[i].setAttribute('data-listo', '1');
            fotos[i].classList.add('sg-a3-ampliable');
            fotos[i].title = 'Ampliar';
            fotos[i].onclick = function () { ampliar(this.src, this.alt || 'Imagen'); };
        }
    }

    function ampliar(url, titulo) {
        var fondo = document.getElementById('sgOtLightbox');

        if (!fondo) {
            fondo = document.createElement('div');
            fondo.id = 'sgOtLightbox';
            fondo.className = 'sg-ot-lightbox';
            document.body.appendChild(fondo);
        }

        fondo.innerHTML =
            '<div class="sg-ot-lb-marco" role="dialog" aria-modal="true">' +
            '<header class="sg-ot-lb-cab">' +
            '<span class="sg-ot-card-ico"><i class="mdi mdi-image-outline"></i></span>' +
            '<h3></h3>' +
            '<a href="#" class="sg-ot-lb-cerrar" title="Cerrar (Esc)"><i class="mdi mdi-close"></i></a>' +
            '</header>' +
            '<div class="sg-ot-lb-foto"><img alt="" /></div>' +
            '<div class="sg-ot-lb-datos">' +
            '<a class="sg-ot-btn es-plano" target="_blank"><i class="mdi mdi-open-in-new"></i>Abrir original</a>' +
            '</div></div>';

        /* El titulo y la url se ponen por propiedad y no armando HTML: el
           nombre del archivo lo escribio una persona y puede traer comillas
           o angulos. */
        fondo.querySelector('h3').textContent = titulo;
        fondo.querySelector('.sg-ot-lb-foto img').src = url;
        fondo.querySelector('.sg-ot-lb-foto img').alt = titulo;
        fondo.querySelector('.sg-ot-lb-datos a').href = url;

        fondo.classList.add('es-abierto');

        function cerrar(ev) {
            if (ev) ev.preventDefault();
            fondo.classList.remove('es-abierto');
            fondo.innerHTML = '';
            document.removeEventListener('keydown', porEscape);
        }

        function porEscape(ev) { if (ev.keyCode === 27) cerrar(); }

        fondo.querySelector('.sg-ot-lb-cerrar').onclick = cerrar;
        fondo.onclick = function (ev) { if (ev.target === fondo) cerrar(ev); };
        document.addEventListener('keydown', porEscape);
    }

    function armar() {
        navegacion();
        ordenes();
        revisiones();
        ampliables();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);

    window.sigmaActivo360 = { irA: irA, ampliar: ampliar };
})();
