/* ============================================================================
   LA ORDEN DE TRABAJO EN EL NAVEGADOR

   Todo lo que no cambia datos se resuelve aca y no en el servidor: cambiar de
   pestaña, filtrar la galeria de evidencias, abrir el detalle de una de ellas
   y dibujar la firma del cierre. Son gestos de mirar, no de escribir, y con
   un postback cada uno la pantalla parpadeaba entera -menu, barra y siete
   pestañas- para mostrar algo que ya estaba en la pagina.

   Lo que si escribe -guardar, asignar, registrar una detencion, cerrar- va
   por el UpdatePanel: sigue siendo asincrono, la pagina no se recarga, pero
   pasa por las reglas del servidor, que es donde tienen que estar.

   TODO SE VUELVE A ARMAR DESPUES DE CADA POSTBACK ASINCRONO: el UpdatePanel
   reemplaza el HTML y con el se van los listeners.
   ============================================================================ */
(function () {
    'use strict';

    /* ------------------------------------------------------------ pestañas */

    function panelActivo() {
        var h = document.getElementById('hdnTab');
        return h && h.value ? h.value : 'resumen';
    }

    function irA(nombre) {
        var tabs = document.querySelectorAll('.sg-ot-tab');
        var paneles = document.querySelectorAll('.sg-ot-panel');
        var hay = false;

        for (var i = 0; i < tabs.length; i++) hay = hay || tabs[i].getAttribute('data-tab') === nombre;
        if (!hay) nombre = 'resumen';

        for (var j = 0; j < tabs.length; j++)
            tabs[j].classList.toggle('es-activa', tabs[j].getAttribute('data-tab') === nombre);

        for (var k = 0; k < paneles.length; k++)
            paneles[k].classList.toggle('es-activo', paneles[k].getAttribute('data-panel') === nombre);

        var h = document.getElementById('hdnTab');
        if (h) h.value = nombre;
    }

    function pestanas() {
        var n = document.getElementById('hdnNueva');
        var nueva = n && n.value === '1';

        var tabs = document.querySelectorAll('.sg-ot-tab');

        for (var i = 0; i < tabs.length; i++) {
            /* Una orden que todavia no existe no tiene a quien asignarle nada
               ni pasos que mostrar: esas pestañas no se ofrecen en vez de
               ofrecerlas vacias. */
            var suelta = tabs[i].getAttribute('data-tab') !== 'ficha';
            tabs[i].style.display = (nueva && suelta) ? 'none' : '';

            tabs[i].onclick = function (ev) {
                ev.preventDefault();
                irA(this.getAttribute('data-tab'));
            };
        }

        /* Los enlaces de "ver asignación", "revisar cierre" y compañía: son
           atajos a otra pestaña, no navegaciones. */
        var atajos = document.querySelectorAll('[data-ir]');
        for (var j = 0; j < atajos.length; j++)
            atajos[j].onclick = function (ev) {
                ev.preventDefault();
                irA(this.getAttribute('data-ir'));
            };

        var focos = document.querySelectorAll('[data-foco]');
        for (var k = 0; k < focos.length; k++)
            focos[k].onclick = function (ev) {
                ev.preventDefault();
                var destino = document.querySelector(this.getAttribute('data-foco'));
                if (destino) destino.scrollIntoView({ behavior: 'smooth', block: 'center' });
            };

        irA(panelActivo());
    }

    /* --------------------------------------------------------- evidencias */

    function evidencias() {
        var grid = document.getElementById('sgOtEvGrid');
        if (!grid) return;

        var cards = grid.querySelectorAll('.sg-ot-ev-card');
        var chips = document.querySelectorAll('.sg-ot-ev-chip');
        var buscar = document.getElementById('sgOtEvBuscar');
        var selPaso = document.getElementById('sgOtEvPaso');
        var detalle = document.getElementById('sgOtEvDetalle');

        /* El desplegable de pasos se arma con los pasos que REALMENTE tienen
           evidencia: ofrecer los diez cuando solo tres tienen fotos hace que
           filtrar devuelva vacio y parezca roto. */
        if (selPaso) {
            var vistos = {};
            selPaso.innerHTML = '<option value="">Todos los pasos</option>';
            for (var i = 0; i < cards.length; i++) {
                var id = cards[i].getAttribute('data-paso');
                var txt = cards[i].getAttribute('data-paso-txt');
                if (!id || vistos[id]) continue;
                vistos[id] = true;
                var op = document.createElement('option');
                op.value = id;
                op.textContent = txt;
                selPaso.appendChild(op);
            }
        }

        function filtrar() {
            var tipo = 'todas';
            for (var c = 0; c < chips.length; c++)
                if (chips[c].classList.contains('es-activa')) tipo = chips[c].getAttribute('data-tipo');

            var q = (buscar && buscar.value ? buscar.value : '').trim().toLowerCase();
            var paso = selPaso ? selPaso.value : '';

            for (var i = 0; i < cards.length; i++) {
                var calza = (tipo === 'todas' || cards[i].getAttribute('data-tipo') === tipo)
                         && (!q || (cards[i].getAttribute('data-buscar') || '').indexOf(q) !== -1)
                         && (!paso || cards[i].getAttribute('data-paso') === paso);
                cards[i].style.display = calza ? '' : 'none';
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
        if (selPaso) selPaso.onchange = filtrar;

        function abrir(card) {
            for (var i = 0; i < cards.length; i++) cards[i].classList.remove('es-elegida');
            card.classList.add('es-elegida');

            var d = function (n) { return card.getAttribute('data-' + n) || ''; };
            var esImagen = d('imagen') === '1';

            var html = '<header class="sg-ot-ev-det-cab">' +
                       '<span class="sg-ot-card-ico"><i class="mdi ' + d('icono') + '"></i></span>' +
                       '<h3>' + d('titulo') + '</h3>' +
                       '<a href="#" class="sg-ot-ev-cerrar" title="Cerrar"><i class="mdi mdi-close"></i></a></header>';

            html += esImagen
                ? '<a class="sg-ot-ev-det-foto" href="' + d('url') + '" target="_blank"><img src="' + d('url') + '" alt="' + d('titulo') + '" /></a>'
                : '<div class="sg-ot-ev-det-doc"><i class="mdi ' + d('icono') + '"></i></div>';

            html += '<div class="sg-ot-datos">';
            if (d('paso-txt')) html += dato('mdi-format-list-numbered', 'Paso asociado', d('paso-txt'));
            if (d('fecha')) html += dato('mdi-calendar-outline', 'Capturada', d('fecha'));
            if (d('usuario')) html += dato('mdi-account-outline', 'Enviada por', d('usuario'));
            if (d('obs')) html += dato('mdi-note-text-outline', 'Observación del técnico', d('obs'));
            html += '</div>';

            html += '<a class="sg-ot-btn es-plano sg-ot-ev-abrir" href="' + d('url') + '" target="_blank">' +
                    '<i class="mdi mdi-open-in-new"></i>Abrir original</a>';

            detalle.innerHTML = html;
            detalle.classList.add('es-abierto');

            var cerrar = detalle.querySelector('.sg-ot-ev-cerrar');
            if (cerrar) cerrar.onclick = function (ev) {
                ev.preventDefault();
                detalle.classList.remove('es-abierto');
                detalle.innerHTML = '';
                for (var i = 0; i < cards.length; i++) cards[i].classList.remove('es-elegida');
            };
        }

        function dato(icono, etiqueta, valor) {
            return '<div class="sg-ot-dato"><span class="sg-ot-dato-ico"><i class="mdi ' + icono + '"></i></span>' +
                   '<div><span class="sg-ot-dato-etq">' + etiqueta + '</span>' +
                   '<span class="sg-ot-dato-val">' + valor + '</span></div></div>';
        }

        /* Una miniatura que no carga -el blob se perdio, o el archivo se
           subio con la ruta mal- se reemplaza por el icono de su tipo. La
           imagen rota del navegador no dice nada y ensucia la galeria
           entera. */
        var fotos = grid.querySelectorAll('.sg-ot-ev-card img');
        for (var f = 0; f < fotos.length; f++)
            fotos[f].onerror = function () {
                var card = this.closest('.sg-ot-ev-card');
                var marco = this.parentNode;
                this.style.display = 'none';
                if (!marco.querySelector('.sg-ot-ev-icono')) {
                    var i = document.createElement('i');
                    i.className = 'mdi ' + (card ? card.getAttribute('data-icono') : 'mdi-image-off-outline') + ' sg-ot-ev-icono';
                    marco.appendChild(i);
                }
            };

        for (var j = 0; j < cards.length; j++)
            cards[j].onclick = function () { abrir(this); };

        filtrar();
    }

    /* -------------------------------------------------------------- firma */

    function firma() {
        var canvas = document.getElementById('sgOtFirma');
        if (!canvas) return;

        var campo = document.getElementById('hdnFirma');
        var ctx = canvas.getContext('2d');
        var dibujando = false, hubo = false;

        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.strokeStyle = '#0f172a';

        /* El canvas mide en pixeles propios y se pinta estirado por CSS: sin
           esta conversion el trazo aparece corrido respecto del puntero. */
        function punto(ev) {
            var r = canvas.getBoundingClientRect();
            var t = ev.touches && ev.touches.length ? ev.touches[0] : ev;
            return {
                x: (t.clientX - r.left) * (canvas.width / r.width),
                y: (t.clientY - r.top) * (canvas.height / r.height)
            };
        }

        function empezar(ev) {
            ev.preventDefault();
            dibujando = true;
            var p = punto(ev);
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
        }

        function mover(ev) {
            if (!dibujando) return;
            ev.preventDefault();
            var p = punto(ev);
            ctx.lineTo(p.x, p.y);
            ctx.stroke();
            hubo = true;
            canvas.parentNode.classList.add('es-firmado');
        }

        function terminar() {
            if (!dibujando) return;
            dibujando = false;
            if (campo && hubo) campo.value = canvas.toDataURL('image/png');
        }

        canvas.addEventListener('mousedown', empezar);
        canvas.addEventListener('mousemove', mover);
        window.addEventListener('mouseup', terminar);
        canvas.addEventListener('touchstart', empezar, { passive: false });
        canvas.addEventListener('touchmove', mover, { passive: false });
        canvas.addEventListener('touchend', terminar);

        var limpiar = document.getElementById('sgOtFirmaLimpiar');
        if (limpiar) limpiar.onclick = function (ev) {
            ev.preventDefault();
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            hubo = false;
            if (campo) campo.value = '';
            canvas.parentNode.classList.remove('es-firmado');
        };
    }

    /* ------------------------------------------------------------ arranque */

    function armar() {
        pestanas();
        evidencias();
        firma();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);

    window.sigmaOrden = { irA: irA };
})();
