(function (window, document) {
    'use strict';

    var recargando = false;

    function parts() {
        var panel = document.querySelector('[data-sg-notif-panel]');
        if (!panel) return null;
        return {
            panel: panel,
            parent: panel.closest ? panel.closest('.dropdown') : panel.parentNode,
            trigger: panel.parentNode.querySelector('[data-toggle="dropdown"]')
        };
    }

    function closePanel(p) {
        if (!p) return;
        p.parent.classList.remove('show');
        p.panel.classList.remove('show');
        p.trigger.setAttribute('aria-expanded', 'false');
        p.trigger.focus();
    }

    /* ======================================================================
       VISTAS / SIN VER

       No sale del navegador. Cada fila trae `data-visto`, asi que filtrar es
       esconder las que no calzan: responde en el mismo fotograma del clic.
       Ir al servidor a pedir la misma lista para mostrar un subconjunto de si
       misma seria media pantalla de espera por un dato que ya esta aca.

       El estado elegido se recuerda entre recargas del panel: si alguien dejo
       puesto "Sin ver" y llega una alerta nueva, el panel se repinta y seria
       molesto tener que volver a elegirlo cada vez.
       ====================================================================== */
    var filtroVisto = '';

    function aplicarFiltro(panel) {
        if (!panel) return;

        var filas = panel.querySelectorAll('[data-alerta-id]');
        var visibles = 0;

        for (var i = 0; i < filas.length; i++) {
            var pasa = !filtroVisto || filas[i].getAttribute('data-visto') === filtroVisto;
            filas[i].hidden = !pasa;
            if (pasa) visibles++;
        }

        /* Los numeros de cada opcion. Se cuentan sobre lo que hay en el panel,
           que es la misma fuente que usa el filtro: asi el numero y lo que se
           ve al tocar no pueden discrepar.

           Van en el propio boton y no en un rotulo aparte: un filtro que dice
           "Sin ver" y al tocarlo no muestra nada ya hizo perder un clic. Con
           el numero al lado se sabe antes si vale la pena. */
        var sinVer = 0;

        for (var k = 0; k < filas.length; k++)
            if (filas[k].getAttribute('data-visto') === '0') sinVer++;

        var cuenta = { '': filas.length, '0': sinVer, '1': filas.length - sinVer };

        var botones = panel.querySelectorAll('[data-sg-notif-filtro]');

        for (var j = 0; j < botones.length; j++) {
            var valor = botones[j].getAttribute('data-sg-notif-filtro') || '';
            var suyo = valor === filtroVisto;
            var n = cuenta[valor];

            botones[j].classList.toggle('is-activo', suyo);
            botones[j].setAttribute('aria-pressed', suyo ? 'true' : 'false');

            /* Una opcion sin nada no se esconde -al desaparecer correria las
               otras de lugar y se tocaria la equivocada- pero se apaga. */
            botones[j].classList.toggle('is-vacia', n === 0 && !suyo);

            var hueco = botones[j].querySelector('.n');
            if (hueco) hueco.textContent = n;
        }

        /* Cuando el filtro deja la lista vacia hay que decirlo, y decir por
           que: el vacio de "no hay nada" ya tiene su propio mensaje, y
           confundirlos deja a alguien pensando que no le llego nada cuando lo
           que pasa es que puso un filtro. */
        var aviso = panel.querySelector('[data-sg-notif-sinfiltro]');
        var hayFilas = filas.length > 0;

        if (hayFilas && visibles === 0) {
            if (!aviso) {
                var cuerpo = panel.querySelector('.sg-notif-cuerpo');
                if (!cuerpo) return;

                aviso = document.createElement('div');
                aviso.className = 'sg-notif-vacio';
                aviso.setAttribute('data-sg-notif-sinfiltro', '1');
                cuerpo.appendChild(aviso);
            }

            aviso.innerHTML = '<div class="sg-notif-vacio-titulo">' +
                (filtroVisto === '0' ? 'No queda nada sin ver' : 'Todavía no has visto ninguna') +
                '</div><div class="sg-notif-vacio-texto">' +
                (filtroVisto === '0'
                    ? 'Ya revisaste las ' + filas.length + ' notificaciones del panel.'
                    : 'Las ' + filas.length + ' que hay siguen sin abrirse.') +
                '</div>';

            aviso.hidden = false;
        }
        else if (aviso) aviso.hidden = true;
    }

    /* ======================================================================
       LOS VECTORES SE ANIMAN, Y PARA ESO EL SVG TIENE QUE ESTAR EN LINEA

       POR QUE NO ALCANZA CON <img>

         Un <img> es una caja opaca: el navegador dibuja el SVG adentro pero su
         contenido no es parte del documento, asi que no hay nodos ni trazos
         que animar. Para llegar a los vectores hay que traer el archivo y
         ponerlo en el DOM como <svg>.

         Se descarga UNA vez por archivo y se guarda: seis filas del mismo tipo
         comparten el mismo dibujo, y bajarlo seis veces seria pagar seis
         viajes por lo mismo.

       QUE HACE LA ANIMACION

         Las lineas se DIBUJAN -de la nada hasta su largo completo- y los nodos
         aparecen despues, escalonados. Se lee como que el grafo se esta
         armando, que es lo que el simbolo representa: algo que se conecto y
         produjo un aviso.

         El destello de las predicciones entra girando y con rebote: es el
         unico elemento que no es parte del grafo, y es el que dice que esto
         salio de un modelo.

       UNA VEZ, NO EN BUCLE

         Es una lista de avisos, no una pantalla de carga. Algo que se mueve
         sin parar al lado de un texto que hay que leer compite con el texto.
       ====================================================================== */
    var cacheSvg = {};

    function claveDe(src) {
        var m = /sigma-ai-([a-z-]+)\.svg/i.exec(src || '');
        return m ? m[1] : '';
    }

    function animarVectores(svg) {
        if (!window.gsap) return;

        if (window.matchMedia &&
            matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        var trazos = svg.querySelectorAll('path[stroke]');
        var rellenos = svg.querySelectorAll('path[fill]:not([stroke])');

        var linea = gsap.timeline();

        for (var i = 0; i < trazos.length; i++) {
            var t = trazos[i];
            var largo = 0;

            /* `getTotalLength` puede fallar si el path no esta dibujado
               todavia; sin el largo no hay trazo que animar, pero el icono
               tiene que verse igual. */
            try { largo = t.getTotalLength(); } catch (e) { largo = 0; }

            if (!largo) continue;

            linea.fromTo(t,
                { strokeDasharray: largo, strokeDashoffset: largo },
                { strokeDashoffset: 0, duration: .55, ease: 'power2.out',
                  clearProps: 'strokeDasharray,strokeDashoffset' },
                i * 0.06);
        }

        /* El destello: es relleno, no trazo, asi que no se puede dibujar.
           Entra girando. */
        for (var j = 0; j < rellenos.length; j++) {
            linea.fromTo(rellenos[j],
                { scale: 0, rotate: -120, transformOrigin: 'center', opacity: 0 },
                { scale: 1, rotate: 0, opacity: 1, duration: .5, ease: 'back.out(2.4)',
                  clearProps: 'transform,opacity' },
                .28 + j * 0.05);
        }
    }

    function ponerSvg(img, texto) {
        var molde = document.createElement('div');
        molde.innerHTML = texto;

        var svg = molde.querySelector('svg');
        if (!svg || !img.parentNode) return;

        svg.setAttribute('data-sg-icono', claveDe(img.getAttribute('src')));
        svg.setAttribute('aria-hidden', 'true');
        svg.removeAttribute('width');
        svg.removeAttribute('height');

        img.parentNode.replaceChild(svg, img);
        animarVectores(svg);
    }

    function encenderIconos(panel) {
        if (!panel) return;

        var imgs = panel.querySelectorAll('.sg-notif-item .icono img');

        Array.prototype.forEach.call(imgs, function (img) {
            var src = img.getAttribute('src');
            if (!src) return;

            if (cacheSvg[src] === 'pendiente') return;

            if (typeof cacheSvg[src] === 'string' && cacheSvg[src] !== 'pendiente') {
                ponerSvg(img, cacheSvg[src]);
                return;
            }

            cacheSvg[src] = 'pendiente';

            if (typeof jQuery === 'undefined') { delete cacheSvg[src]; return; }

            jQuery.ajax({
                url: src, dataType: 'text', cache: true,
                success: function (texto) {
                    cacheSvg[src] = texto;
                    /* Puede haber llegado despues de que el panel se repinto:
                       se buscan de nuevo TODAS las que usan este archivo, no
                       solo la que disparo la descarga. */
                    var pendientes = document.querySelectorAll(
                        '.sg-notif-item .icono img[src="' + src + '"]');
                    Array.prototype.forEach.call(pendientes, function (n) {
                        ponerSvg(n, texto);
                    });
                },
                error: function () { delete cacheSvg[src]; }
            });
        });

        /* Los que ya estaban en linea de un repintado anterior tambien se
           animan: si no, al filtrar o al llegar una alerta nueva unos se
           mueven y otros no. */
        var yaVivos = panel.querySelectorAll('.sg-notif-item .icono svg[data-sg-icono]');
        Array.prototype.forEach.call(yaVivos, animarVectores);
    }

    function init() {
        var p = parts();
        if (!p || p.panel.getAttribute('data-sg-ready') === '1') return;
        p.panel.setAttribute('data-sg-ready', '1');

        p.panel.addEventListener('click', function (event) {
            var dismiss = event.target.closest && event.target.closest('[data-sg-notif-dismiss]');
            if (dismiss) {
                event.preventDefault();
                event.stopPropagation();
                closePanel(p);
                return;
            }

            var leerTodo = event.target.closest && event.target.closest('[data-sg-notif-leer-todo]');
            if (leerTodo) {
                event.preventDefault();
                event.stopPropagation();
                leerTodo.disabled = true;
                if (window.sigmaAlertas) {
                    var viaje = sigmaAlertas.leer(null);
                    if (viaje && viaje.always) viaje.always(recargar);
                    else leerTodo.disabled = false;
                }
                else leerTodo.disabled = false;
                return;
            }

            var filtro = event.target.closest && event.target.closest('[data-sg-notif-filtro]');
            if (filtro) {
                event.preventDefault();
                event.stopPropagation();
                filtroVisto = filtro.getAttribute('data-sg-notif-filtro') || '';
                aplicarFiltro(p.panel);
                return;
            }

            var item = event.target.closest && event.target.closest('[data-sg-notif-close]');
            if (item) return;
            event.stopPropagation();
        });

        aplicarFiltro(p.panel);
        encenderIconos(p.panel);

        p.panel.addEventListener('keydown', function (event) {
            if (event.key === 'Escape' || event.keyCode === 27) {
                event.preventDefault();
                closePanel(p);
                return;
            }
            if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
            var focusable = p.panel.querySelectorAll('a:not([hidden]), button:not([hidden])');
            if (!focusable.length) return;
            var index = Array.prototype.indexOf.call(focusable, document.activeElement);
            index += event.key === 'ArrowDown' ? 1 : -1;
            if (index < 0) index = focusable.length - 1;
            if (index >= focusable.length) index = 0;
            event.preventDefault();
            focusable[index].focus();
        });
    }

    function recargar() {
        if (recargando || typeof jQuery === 'undefined') return;

        var actual = parts();
        if (!actual) return;
        recargando = true;

        jQuery.ajax({
            type: 'GET',
            url: window.location.pathname + window.location.search,
            cache: false,
            success: function (html) {
                var pagina = new DOMParser().parseFromString(html, 'text/html');
                var nuevoPanel = pagina.querySelector('[data-sg-notif-panel]');
                var nuevaCampana = pagina.querySelector('.sigma-notification');

                if (nuevoPanel) {
                    actual.panel.innerHTML = nuevoPanel.innerHTML;

                    /* El panel llega del servidor sin filtrar: el filtro es
                       del cliente, asi que se vuelve a aplicar sobre lo que
                       acaba de entrar. Sin esto, una alerta nueva reventaba
                       el filtro puesto. */
                    aplicarFiltro(actual.panel);
                    encenderIconos(actual.panel);
                }

                /* El trigger conserva los listeners de Bootstrap: solo se
                   reconcilian las clases, el rótulo y el badge. */
                if (nuevaCampana && actual.trigger) {
                    actual.trigger.className = nuevaCampana.className;
                    actual.trigger.setAttribute('aria-label',
                        nuevaCampana.getAttribute('aria-label') || 'Alertas');

                    var viejoBadge = actual.trigger.querySelector('.sigma-notification__count');
                    var nuevoBadge = nuevaCampana.querySelector('.sigma-notification__count');

                    if (nuevoBadge) {
                        if (!viejoBadge) {
                            viejoBadge = document.createElement('span');
                            viejoBadge.className = 'sigma-notification__count';
                            viejoBadge.setAttribute('aria-hidden', 'true');
                            actual.trigger.appendChild(viejoBadge);
                        }
                        viejoBadge.textContent = nuevoBadge.textContent;
                    }
                    else if (viejoBadge && viejoBadge.parentNode) {
                        viejoBadge.parentNode.removeChild(viejoBadge);
                    }
                }

                recargando = false;
            },
            error: function () { recargando = false; }
        });
    }

    document.addEventListener('sigma:alertas-actualizadas', recargar);

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})(window, document);
