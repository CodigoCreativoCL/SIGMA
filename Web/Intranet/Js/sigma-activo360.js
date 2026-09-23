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

    function armar() {
        navegacion();
        ordenes();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);

    window.sigmaActivo360 = { irA: irA };
})();
