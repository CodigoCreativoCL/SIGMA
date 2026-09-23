/* ============================================================================
   LA TAREA RECURRENTE EN EL NAVEGADOR

   Las pestañas las maneja sigma-orden.js, que busca por clase y funciona
   igual en esta pantalla. Aca va lo propio:

   · filtrar la tabla de ocurrencias por estado y buscar en los comentarios,
     que con doce filas ya cargadas no tiene por que costar un viaje;
   · responder a un comentario, que es anotar a quien y llevar el foco;
   · dictar, que escribe en la caja con el reconocimiento de voz del
     navegador.

   Todo se vuelve a armar despues de cada postback asincrono: el UpdatePanel
   reemplaza el HTML y con el se van los listeners.
   ============================================================================ */
(function () {
    'use strict';

    /* ------------------------------------------------- interruptores */

    /* El texto de al lado -"Sí/No", "Activa/Apagada"- lo escribe el servidor
       al pintar, asi que sin esto quedaba diciendo "No" con el interruptor ya
       encendido hasta el proximo guardado. */
    function interruptores() {
        var casillas = document.querySelectorAll('.sg-ta-toggle input[type="checkbox"]');

        for (var i = 0; i < casillas.length; i++) {
            (function (c) {
                var txt = c.parentNode.querySelector('.sg-ta-toggle-txt');
                if (!txt) return;

                /* Las dos palabras salen del propio texto pintado: asi el JS
                   no tiene que saber cual interruptor es cual. */
                var par = txt.getAttribute('data-par');
                if (!par) {
                    par = /activa|apagada/i.test(txt.textContent) ? 'Activa|Apagada' : 'Sí|No';
                    txt.setAttribute('data-par', par);
                }

                var palabras = par.split('|');

                c.onchange = function () { txt.textContent = c.checked ? palabras[0] : palabras[1]; };
            })(casillas[i]);
        }
    }

    /* ------------------------------------------- ocurrencias: los cubos */

    function ocurrencias() {
        var chips = document.querySelectorAll('.sg-ta-conteos .sg-ot-ev-chip');
        var filas = document.querySelectorAll('.sg-ta-oc');
        if (!chips.length || !filas.length) return;

        function filtrar(estado) {
            for (var i = 0; i < filas.length; i++) {
                var calza = estado === 'todas' || filas[i].getAttribute('data-grupo') === estado;
                filas[i].style.display = calza ? '' : 'none';
            }
        }

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar(this.getAttribute('data-estado'));
            };
    }

    /* ------------------------------------------ comentarios: buscar */

    function buscarComentarios() {
        var caja = document.getElementById('sgTaBuscarComentario');
        var hilos = document.getElementById('sgTaHilos');
        if (!caja || !hilos) return;

        caja.oninput = function () {
            var q = caja.value.trim().toLowerCase();
            var articulos = hilos.querySelectorAll('.sg-ta-com');

            for (var i = 0; i < articulos.length; i++) {
                var calza = !q || (articulos[i].textContent || '').toLowerCase().indexOf(q) !== -1;
                articulos[i].style.display = calza ? '' : 'none';
            }

            /* Un hilo sin ningun comentario a la vista sobra: deja su
               cabecera sola y parece que la ocurrencia no tiene nada. */
            var secciones = hilos.querySelectorAll('.sg-ta-hilo');
            for (var s = 0; s < secciones.length; s++) {
                var vivos = secciones[s].querySelectorAll('.sg-ta-com');
                var alguno = false;
                for (var v = 0; v < vivos.length; v++) if (vivos[v].style.display !== 'none') alguno = true;
                secciones[s].style.display = alguno ? '' : 'none';
            }
        };
    }

    /* --------------------------------------------- responder a alguien */

    function responder() {
        var enlaces = document.querySelectorAll('.sg-ta-responder-a');
        var hidOc = document.getElementById('hidOcurrencia');
        var hidPa = document.getElementById('hidPadre');
        var etiqueta = document.getElementById('sgTaRespondiendo');
        var caja = document.getElementById('txtComentario');

        for (var i = 0; i < enlaces.length; i++)
            enlaces[i].onclick = function (ev) {
                ev.preventDefault();

                if (hidOc) hidOc.value = this.getAttribute('data-ocurrencia');
                if (hidPa) hidPa.value = this.getAttribute('data-padre');

                if (etiqueta)
                    etiqueta.innerHTML = 'Respondiendo a <strong>' + this.getAttribute('data-nombre') + '</strong>';

                if (caja) { caja.focus(); caja.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
            };

        var cancelar = document.getElementById('sgTaCancelarRespuesta');
        if (cancelar) cancelar.onclick = function (ev) {
            ev.preventDefault();
            if (hidPa) hidPa.value = '';
            if (etiqueta) etiqueta.innerHTML = 'Comentario nuevo en la ocurrencia elegida';
        };
    }

    /* ------------------------------------------------------- dictar */

    function dictar() {
        var boton = document.getElementById('sgTaDictar');
        var caja = document.getElementById('txtComentario');
        if (!boton || !caja) return;

        var Reconocimiento = window.SpeechRecognition || window.webkitSpeechRecognition;

        /* Sin reconocimiento de voz el boton no se ofrece: un boton que no
           hace nada es peor que no tenerlo. */
        if (!Reconocimiento) { boton.style.display = 'none'; return; }

        var escuchando = false, motor = null;

        boton.onclick = function (ev) {
            ev.preventDefault();

            if (escuchando && motor) { motor.stop(); return; }

            motor = new Reconocimiento();
            motor.lang = 'es-CL';
            motor.interimResults = false;
            motor.continuous = true;

            motor.onstart = function () {
                escuchando = true;
                boton.classList.add('sg-ta-dictando');
                boton.innerHTML = '<i class="mdi mdi-stop-circle-outline"></i>Detener';
            };

            motor.onresult = function (e) {
                var texto = '';
                for (var i = e.resultIndex; i < e.results.length; i++)
                    if (e.results[i].isFinal) texto += e.results[i][0].transcript;

                if (!texto) return;

                /* Se agrega al final en vez de reemplazar: quien dicta suele
                   haber escrito algo antes, y perderlo seria el peor momento
                   para descubrir como funciona el boton. */
                caja.value = (caja.value ? caja.value.replace(/\s*$/, '') + ' ' : '') + texto.trim();
            };

            motor.onerror = function () { motor.stop(); };

            motor.onend = function () {
                escuchando = false;
                boton.classList.remove('sg-ta-dictando');
                boton.innerHTML = '<i class="mdi mdi-microphone-outline"></i>Dictar';
                caja.focus();
            };

            motor.start();
        };
    }

    function armar() {
        interruptores();
        ocurrencias();
        buscarComentarios();
        responder();
        dictar();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);
})();
