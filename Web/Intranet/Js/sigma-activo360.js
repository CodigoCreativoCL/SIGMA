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
        /* Salir de la ficha con cambios sin guardar pregunta primero: el
           formulario sigue vivo mientras la pestaña este abierta, pero se
           pierde en cuanto la pagina recargue. */
        if (!puedeSalirDeFicha(nombre)) return;

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

    /* ---- La ficha avisa antes de que se pierda lo escrito ----

       La pestaña Ficha es un formulario largo. Cambiar de seccion no recarga
       -las pestañas son del navegador-, pero el formulario sigue ahi con lo
       tecleado sin guardar, y al recargar la pagina se pierde. Se marca
       sucio al primer cambio y se pregunta antes de salir. */
    var fichaSucia = false;

    function ficha() {
        var panel = document.querySelector('.sg-a3-ficha');
        if (!panel || panel.getAttribute('data-listo') === '1') return;

        panel.setAttribute('data-listo', '1');

        panel.addEventListener('input', ensuciar, true);
        panel.addEventListener('change', ensuciar, true);

        /* Guardar y Cancelar hacen postback: lo que venia sin guardar deja de
           estarlo en cuanto se van al servidor. */
        var acciones = panel.querySelectorAll('.sg-a3-ficha-pie input, .sg-a3-ficha-pie button');
        for (var i = 0; i < acciones.length; i++)
            acciones[i].addEventListener('click', function () { limpiar(); });

        window.onbeforeunload = function () {
            if (fichaSucia) return 'Hay cambios sin guardar en la ficha del activo.';
        };
    }

    function ensuciar() {
        var panel = document.querySelector('.sg-a3-ficha');
        if (!panel) return;
        fichaSucia = true;
        panel.classList.add('es-sucia');
    }

    function limpiar() {
        var panel = document.querySelector('.sg-a3-ficha');
        fichaSucia = false;
        if (panel) panel.classList.remove('es-sucia');
    }

    /// Se pregunta solo al SALIR de la ficha: entrar a ella no arriesga nada.
    function puedeSalirDeFicha(destino) {
        if (!fichaSucia || destino === 'ficha') return true;

        if (confirm('La ficha tiene cambios sin guardar. ¿Descartarlos y cambiar de sección?')) {
            limpiar();
            return true;
        }

        return false;
    }

    /* ---- Componentes: el arbol, la lista y el detalle miran lo mismo ----

       Elegir una pieza en cualquiera de los tres lados marca los otros dos y
       acota el historial de reemplazos a esa pieza. Todo con lo que ya vino
       en la fila: pedirle al servidor lo que ya esta en pantalla es un viaje
       de mas y un parpadeo. */
    function componentes() {
        var filas = document.querySelectorAll('.sg-comp-fila');
        if (!filas.length) return;

        var chips = document.querySelectorAll('#sgCompTipos a[data-comp-estado]');
        var buscar = document.getElementById('sgCompBuscar');
        var detalle = document.querySelector('.sg-comp-detalle-cuerpo');
        var nodos = document.querySelectorAll('.sg-comp-nodo[data-ir-comp]');
        var reemplazos = document.querySelectorAll('.sg-comp-rep');

        function filtrar() {
            var activa = document.querySelector('#sgCompTipos a.es-activa');
            var estado = activa ? activa.getAttribute('data-comp-estado') : 'instalados';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();

            for (var i = 0; i < filas.length; i++) {
                var ok = filas[i].getAttribute('data-comp-estado') === estado
                      && (texto === '' || (filas[i].getAttribute('data-comp-txt') || '').indexOf(texto) !== -1);
                filas[i].classList.toggle('es-oculta', !ok);
            }
        }

        function elegir(id) {
            var fila = document.querySelector('.sg-comp-fila[data-comp="' + id + '"]');
            if (!fila) return;

            for (var i = 0; i < filas.length; i++) filas[i].classList.remove('es-elegida');
            fila.classList.add('es-elegida');

            for (var n = 0; n < nodos.length; n++)
                nodos[n].classList.toggle('es-elegido', nodos[n].getAttribute('data-ir-comp') === String(id));

            pintar(fila);

            /* El historial se acota a la pieza elegida: "cuantos rodamientos
               lleva este ventilador" es la pregunta, no cuantos lleva el
               equipo entero. */
            for (var r = 0; r < reemplazos.length; r++)
                reemplazos[r].classList.toggle('es-oculta', reemplazos[r].getAttribute('data-comp-rep') !== String(id));
        }

        function dato(etiqueta, valor) {
            if (!valor) return '';
            var d = document.createElement('div');
            d.className = 'sg-ot-dato';
            d.innerHTML = '<div><span class="sg-ot-dato-etq"></span><span class="sg-ot-dato-val"></span></div>';
            d.querySelector('.sg-ot-dato-etq').textContent = etiqueta;
            d.querySelector('.sg-ot-dato-val').textContent = valor;
            return d.outerHTML;
        }

        function pintar(fila) {
            if (!detalle) return;

            var d = function (n) { return fila.getAttribute('data-comp-' + n) || ''; };
            var html = '';

            /* La foto primero: es lo que identifica la pieza antes que su
               codigo. Si no tiene, no se deja un hueco gris. */
            if (d('foto')) html += '<span class="sg-comp-det-foto"><img alt="" /></span>';

            html += '<div><span class="sg-comp-det-tit"></span><span class="sg-comp-det-sub"></span></div>';
            html += '<div>' + (d('estado-txt') ? '<span class="sg-ot-chip ' +
                    (fila.getAttribute('data-comp-estado') === 'instalados' ? 'es-ok' : 'es-neutro') +
                    '">' + d('estado-txt') + '</span>' : '') + '</div>';

            html += dato('Tipo', d('tipo'));
            html += dato('Criticidad', d('criticidad'));
            html += dato('Posición', d('posicion'));
            html += dato('Componente superior', d('padre'));
            html += dato('Instalado el', d('instalacion'));
            html += dato('Descripción', d('desc'));

            if (d('motivo')) html += '<div class="sg-comp-det-motivo"></div>';

            html += '<a class="sg-ot-btn es-plano" href="javascript:void(0)" data-comp-abrir="1">' +
                    '<i class="mdi mdi-open-in-new"></i>Ver ficha del componente</a>';

            detalle.innerHTML = html;

            /* El nombre y el motivo se ponen por propiedad: los escribio una
               persona y pueden traer comillas o angulos. */
            var foto = detalle.querySelector('.sg-comp-det-foto img');
            if (foto) { foto.src = d('foto'); foto.alt = d('nombre'); }

            detalle.querySelector('.sg-comp-det-tit').textContent = d('nombre');
            detalle.querySelector('.sg-comp-det-sub').textContent = d('codigo');

            var motivo = detalle.querySelector('.sg-comp-det-motivo');
            if (motivo) motivo.textContent = d('motivo');

            var abrir = detalle.querySelector('[data-comp-abrir]');
            if (abrir) abrir.onclick = function () { abrirComponente(d('query')); };
        }

        for (var i = 0; i < filas.length; i++)
            filas[i].onclick = function (ev) {
                if (ev.target.closest('a, input, button')) return;
                elegir(this.getAttribute('data-comp'));
            };

        for (var n = 0; n < nodos.length; n++)
            nodos[n].onclick = function () { elegir(this.getAttribute('data-ir-comp')); };

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;

        filtrar();

        /* Se abre con la primera pieza elegida: un panel de detalle vacio al
           lado de una lista llena parece que no cargo. */
        var primera = document.querySelector('.sg-comp-fila:not(.es-oculta)');
        if (primera) elegir(primera.getAttribute('data-comp'));
    }

    /* ---- Condicion: la tarjeta elegida manda ----

       Elegir una variable marca su fila en la tabla, acota las ultimas
       lecturas a esa variable y llena el panel de la derecha. Todo con lo que
       ya vino en la tarjeta. */
    function condicion() {
        var tarjetas = document.querySelectorAll('.sg-a3-cond-card[data-var]');
        var vistas = document.querySelectorAll('#sgCondVistas a[data-cond-vista]');

        for (var v = 0; v < vistas.length; v++)
            vistas[v].onclick = function (ev) {
                ev.preventDefault();
                var cual = this.getAttribute('data-cond-vista');

                for (var k = 0; k < vistas.length; k++) vistas[k].classList.remove('es-activa');
                this.classList.add('es-activa');

                var paneles = document.querySelectorAll('.sg-cond-vista');
                for (var p = 0; p < paneles.length; p++)
                    paneles[p].classList.toggle('es-oculta', paneles[p].getAttribute('data-cond-vista') !== cual);
            };

        if (!tarjetas.length) return;

        var detalle = document.querySelector('.sg-cond-detalle-cuerpo');
        var filas = document.querySelectorAll('.sg-cond-fila');
        var lecturas = document.querySelectorAll('.sg-cond-lec');
        var deQuien = document.getElementById('sgCondLecturasDe');

        function dato(etiqueta, valor) {
            if (!valor) return '';
            var d = document.createElement('div');
            d.className = 'sg-ot-dato';
            d.innerHTML = '<div><span class="sg-ot-dato-etq"></span><span class="sg-ot-dato-val"></span></div>';
            d.querySelector('.sg-ot-dato-etq').textContent = etiqueta;
            d.querySelector('.sg-ot-dato-val').textContent = valor;
            return d.outerHTML;
        }

        function elegir(id) {
            for (var i = 0; i < tarjetas.length; i++)
                tarjetas[i].classList.toggle('es-elegida', tarjetas[i].getAttribute('data-var') === String(id));

            for (var f = 0; f < filas.length; f++)
                filas[f].classList.toggle('es-elegida', filas[f].getAttribute('data-var-fila') === String(id));

            var vistasLec = 0;
            for (var l = 0; l < lecturas.length; l++) {
                var suya = lecturas[l].getAttribute('data-var-lec') === String(id);
                lecturas[l].classList.toggle('es-oculta', !suya);
                if (suya) vistasLec++;
            }

            var card = document.querySelector('.sg-a3-cond-card[data-var="' + id + '"]');
            if (!card) return;

            var d = function (n) { return card.getAttribute('data-var-' + n) || ''; };

            if (deQuien) deQuien.textContent = ' · ' + d('nombre') + (vistasLec ? '' : ' (sin lecturas)');

            if (!detalle) return;

            var html = '<div><span class="sg-cond-det-tit"></span></div>' +
                       '<div class="sg-cond-det-val"></div>' +
                       '<div><span class="sg-ot-chip ' + chip(d('clase')) + '"></span></div>';

            html += dato('Rangos configurados', d('rango'));
            html += dato('Frecuencia esperada', d('frecuencia'));
            html += dato('Componente', d('componente'));

            html += '<a class="sg-ot-btn es-accion" href="' + d('serie') + '" target="_blank" rel="noopener">' +
                    '<i class="mdi mdi-chart-line"></i>Ver historial completo</a>';
            html += '<a class="sg-ot-btn es-accion" href="javascript:void(0)" data-var-abrir="1">' +
                    '<i class="mdi mdi-tune-variant"></i>Configurar umbrales</a>';

            detalle.innerHTML = html;
            detalle.querySelector('.sg-cond-det-tit').textContent = d('nombre');
            detalle.querySelector('.sg-cond-det-val').textContent = d('valor');
            detalle.querySelector('.sg-ot-chip').textContent = d('estado');

            var abrir = detalle.querySelector('[data-var-abrir]');
            if (abrir) abrir.onclick = function () { abrirVariable(d('query')); };
        }

        function chip(clase) {
            if (clase === 'es-normal') return 'es-ok';
            if (clase === 'es-critico') return 'es-rojo';
            if (clase === 'es-aviso') return 'es-aviso';
            return 'es-neutro';
        }

        for (var i = 0; i < tarjetas.length; i++)
            tarjetas[i].onclick = function () { elegir(this.getAttribute('data-var')); };

        for (var f = 0; f < filas.length; f++)
            filas[f].onclick = function () { elegir(this.getAttribute('data-var-fila')); };

        elegir(tarjetas[0].getAttribute('data-var'));
    }

    function armar() {
        navegacion();
        ficha();
        componentes();
        condicion();
        ordenes();
        revisiones();
        ampliables();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);

    window.sigmaActivo360 = { irA: irA, ampliar: ampliar };
})();
