/* Centro de Acción Operacional: interacción completa por AJAX, sin postbacks. */
(function (window, document) {
    'use strict';

    var root = null;
    var estado = { tab: 'ACTIVAS', alerta: 0 };
    var cargando = false;
    var pendiente = false;
    var filtroTimer = null;

    /* Cada peticion se lleva un token. Si mientras vuelve la persona ya hizo
       clic en otra alerta, la respuesta vieja llega DESPUES y pintaria el
       detalle equivocado: se compara el token y las viejas se descartan. */
    var viaje = 0;

    /* El esqueleto no aparece de inmediato. Si la respuesta tarda 60ms, verlo
       aparecer y desaparecer es un parpadeo que se siente PEOR que no mostrar
       nada. Solo se dibuja si la espera se nota. */
    var esqueletoTimer = null;

    function uno(selector, dentro) {
        return (dentro || document).querySelector(selector);
    }

    function valor(selector) {
        var control = uno(selector, root);
        return control ? control.value : '';
    }

    function entero(valor) {
        var n = parseInt(valor, 10);
        return isNaN(n) ? 0 : n;
    }

    function notificar(texto, error) {
        texto = texto || (error ? 'No se pudo completar la acción.' : 'Cambio guardado.');

        if (window.sigmaToast) {
            window.sigmaToast(error ? 'Atención' : 'Listo', texto, '', !!error, 0);
            return;
        }

        if (window.Swal) {
            window.Swal.fire('', texto, error ? 'warning' : 'success');
            return;
        }

        if (error) window.alert(texto);
    }

    function respuesta(result) {
        try { return JSON.parse(result.d); }
        catch (e) { return { error: true, detalle: 'El servidor devolvió una respuesta no válida.' }; }
    }

    function llamar(metodo, datos, alTerminar) {
        if (!root || cargando || typeof jQuery === 'undefined') return;

        ocupado(true);

        jQuery.ajax({
            type: 'POST',
            url: root.getAttribute('data-servicio') + '/' + metodo,
            data: JSON.stringify(datos || {}),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json',
            success: function (result) {
                var r = respuesta(result);

                if (r.error) {
                    ocupado(false);
                    notificar(r.detalle, true);
                    return;
                }

                notificar(r.detalle, false);
                ocupado(false);

                if (typeof alTerminar === 'function') alTerminar(r);
                else refrescar();

                if (window.sigmaAlertas) sigmaAlertas.refrescar();
            },
            error: function () {
                ocupado(false);
                notificar('No se pudo comunicar con el servidor.', true);
            }
        });
    }

    /* ======================================================================
       EL ESQUELETO

       Tiene la FORMA del detalle real -chips arriba, titulo ancho, dos lineas
       de texto, una tarjeta grande-. Un rectangulo generico o una ruedita
       girando no dicen nada sobre lo que viene; con la forma, el ojo ya
       encuentra donde va a estar cada cosa y cuando llega el contenido no hay
       salto.

       Las barras NO son todas del mismo largo: un bloque de barras iguales se
       lee como una tabla, no como un texto que esta por llegar.
       ====================================================================== */
    function esqueletoHtml() {
        return '<div class="sg-esq" aria-hidden="true">' +
               '<div class="sg-esq-fila">' +
                   '<span class="sg-esq-chip"></span>' +
                   '<span class="sg-esq-chip is-corto"></span>' +
               '</div>' +
               '<span class="sg-esq-barra is-titulo"></span>' +
               '<span class="sg-esq-barra is-meta"></span>' +
               '<span class="sg-esq-barra"></span>' +
               '<span class="sg-esq-barra is-medio"></span>' +
               '<div class="sg-esq-caja">' +
                   '<span class="sg-esq-barra is-corto"></span>' +
                   '<div class="sg-esq-cols">' +
                       '<span class="sg-esq-bloque"></span>' +
                       '<span class="sg-esq-bloque"></span>' +
                       '<span class="sg-esq-bloque"></span>' +
                   '</div>' +
               '</div>' +
               '</div>';
    }

    function mostrarEsqueleto() {
        var panel = uno('.sg-detalle', root);
        if (!panel) return;

        panel.setAttribute('data-sg-esqueleto', '1');
        panel.innerHTML = esqueletoHtml();

        if (!window.gsap) return;

        gsap.fromTo(panel.querySelectorAll('.sg-esq > *'),
            { opacity: 0, y: 6 },
            { opacity: 1, y: 0, duration: .22, stagger: .04, ease: 'power2.out' });
    }

    function pedirEsqueleto() {
        window.clearTimeout(esqueletoTimer);
        esqueletoTimer = window.setTimeout(mostrarEsqueleto, 180);
    }

    function cancelarEsqueleto() {
        window.clearTimeout(esqueletoTimer);
        esqueletoTimer = null;
    }

    /* La entrada del detalle nuevo. Se anima el contenido, NO la caja: animar
       el panel entero lo haria saltar en su sitio en cada clic, y la caja no
       cambia -lo que cambia es lo que tiene adentro-. */
    function animarDetalle() {
        var panel = uno('.sg-detalle', root);
        if (!panel || !window.gsap) return;

        var piezas = panel.querySelectorAll(
            '.sg-det-cab, .sg-det-titulo, .sg-det-meta, .sg-det-texto, ' +
            '.sg-ai, .sg-det-bloque, .sg-vacio, .sg-cierre');

        if (!piezas.length) piezas = panel.children;
        if (!piezas.length) return;

        gsap.killTweensOf(piezas);
        gsap.fromTo(piezas,
            { opacity: 0, y: 10 },
            { opacity: 1, y: 0, duration: .32, stagger: .045, ease: 'power3.out',
              clearProps: 'transform,opacity' });
    }

    function ocupado(si) {
        cargando = si;
        if (!root) return;
        root.setAttribute('aria-busy', si ? 'true' : 'false');
        if (si) root.classList.add('is-loading');
        else root.classList.remove('is-loading');
    }

    function reemplazar(origen, selector) {
        var actual = uno(selector, root);
        var nuevo = uno(selector, origen);
        if (!actual || !nuevo || !actual.parentNode) return;

        actual.parentNode.replaceChild(document.importNode(nuevo, true), actual);
    }

    /* ======================================================================
       SOLO SE CAMBIA LO QUE CAMBIO

       Antes cada clic reemplazaba los cuatro fragmentos: indicadores,
       pestañas, cola y detalle. Elegir una alerta no cambia ninguno de los
       tres primeros -son los mismos numeros, las mismas pestañas y la misma
       lista-, asi que era trabajo sin resultado visible. Y peor: destruia y
       rehacia el DOM de la cola en cada clic, con lo que se perdia la
       posicion del desplazamiento y el foco del teclado. Eso es lo que hacia
       que el clic se sintiera pesado.

       `soloDetalle` lo evita. Los indicadores y la cola se repintan cuando de
       verdad cambian: al filtrar, al cambiar de pestaña o despues de una
       accion que mueve la alerta de estado.
       ====================================================================== */
    function refrescar(opciones) {
        if (!root || typeof jQuery === 'undefined') return;

        opciones = opciones || {};

        if (cargando) {
            pendiente = opciones;
            return;
        }

        pendiente = false;
        ocupado(true);

        var soloDetalle = opciones.soloDetalle === true;
        var mio = ++viaje;

        if (soloDetalle) pedirEsqueleto();

        function seguir() {
            cancelarEsqueleto();
            ocupado(false);
            if (pendiente) {
                var p = pendiente;
                pendiente = false;
                window.setTimeout(function () { refrescar(p); }, 0);
            }
        }

        jQuery.ajax({
            type: 'GET',
            url: root.getAttribute('data-pagina'),
            cache: false,
            data: {
                sgAjax: 1,
                tab: estado.tab,
                alerta: estado.alerta,
                filtro: valor('[data-sg-cao-filtro="texto"]'),
                severidad: valor('[data-sg-cao-filtro="severidad"]'),
                tipo: valor('[data-sg-cao-filtro="tipo"]')
            },
            success: function (html) {
                /* Llego tarde: ya se pidio otra cosa. Pintarla mostraria el
                   detalle de una alerta que la persona dejo de mirar. */
                if (mio !== viaje) return;

                var pagina = new DOMParser().parseFromString(html, 'text/html');
                var nuevoRoot = uno('[data-sg-cao]', pagina);

                if (!nuevoRoot) {
                    seguir();
                    notificar('No se pudo actualizar la bandeja.', true);
                    return;
                }

                if (!soloDetalle) {
                    reemplazar(nuevoRoot, '.sg-kpis');
                    reemplazar(nuevoRoot, '.sg-tabs');
                    reemplazar(nuevoRoot, '.sg-cola-lista');
                }

                reemplazar(nuevoRoot, '.sg-detalle');

                var panel = uno('.sg-detalle', root);
                if (panel) panel.removeAttribute('data-sg-esqueleto');

                /* La cola llega del servidor sin el filtro de visto/sin ver,
                   que es del cliente: se vuelve a aplicar sobre lo que acaba
                   de entrar. */
                if (!soloDetalle) filtrarEnPantalla();

                seguir();

                animarDetalle();

                if (window.sigmaAnimar) window.sigmaAnimar();
            },
            error: function () {
                if (mio !== viaje) return;
                seguir();
                notificar('No se pudo actualizar la bandeja.', true);
            }
        });
    }

    /* ======================================================================
       FILTRAR ES INSTANTANEO PORQUE NO SALE DEL NAVEGADOR

       QUE PASABA

         Cada tecla del buscador y cada cambio de combo pedian la pagina
         entera al servidor para volver a dibujar la cola. Pero la cola YA
         estaba en pantalla: se pedia de nuevo la misma lista para mostrar un
         subconjunto de si misma. Entre el viaje y el re-render habia medio
         segundo largo en el que la pantalla no reaccionaba, con lo que
         escribir en el buscador se sentia trabado.

       QUE HACE AHORA

         Cada fila trae en sus datos con que se la filtra -gravedad, tipo, si
         esta vista y su texto ya en minusculas-. Filtrar es recorrer las
         filas y esconder las que no calzan: no hay red de por medio, asi que
         responde en el mismo fotograma que la tecla.

       CUANDO SI HACE FALTA PREGUNTAR

         El procedimiento corta en 300 alertas. Mientras no se llegue a ese
         tope, lo que hay en pantalla es todo lo que hay y filtrar aca es
         exacto. Si se llego al tope, podria haber coincidencias que quedaron
         fuera: ahi -y solo ahi- se pregunta al servidor, ademas de filtrar en
         el acto para que igual se vea la respuesta enseguida.
       ====================================================================== */
    function normalizar(texto) {
        texto = (texto || '').toLowerCase();

        /* Sin acentos: quien busca "electrica" espera encontrar "Eléctrica".
           Obligarlo a teclear la tilde es hacerle adivinar como se escribio. */
        if (texto.normalize) texto = texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

        return texto;
    }

    function filtrarEnPantalla() {
        if (!root) return 0;

        var filas = root.querySelectorAll('.sg-cola-lista [data-alerta-id]');
        var texto = normalizar(valor('[data-sg-cao-filtro="texto"]'));
        var sev = valor('[data-sg-cao-filtro="severidad"]');
        var tipo = valor('[data-sg-cao-filtro="tipo"]');
        var visto = valor('[data-sg-cao-filtro="visto"]');
        var visibles = 0;

        for (var i = 0; i < filas.length; i++) {
            var f = filas[i];
            var pasa = true;

            if (sev && f.getAttribute('data-sev') !== sev) pasa = false;
            if (pasa && tipo && f.getAttribute('data-tipo') !== tipo) pasa = false;
            if (pasa && visto && f.getAttribute('data-visto') !== visto) pasa = false;

            if (pasa && texto) {
                var campo = normalizar(f.getAttribute('data-buscar') || '');
                if (campo.indexOf(texto) < 0) pasa = false;
            }

            f.hidden = !pasa;
            if (pasa) visibles++;
        }

        pintarVacio(filas.length, visibles);

        return visibles;
    }

    /* El vacio de "no hay nada" y el de "el filtro no encontro" son dos
       situaciones distintas: una se resuelve esperando y la otra borrando lo
       que se escribio. Decirlas igual deja a alguien buscando un problema
       donde solo hay un filtro puesto. */
    function pintarVacio(total, visibles) {
        var lista = uno('.sg-cola-lista', root);
        if (!lista) return;

        var aviso = uno('[data-sg-cao-sinfiltro]', lista);

        if (total > 0 && visibles === 0) {
            if (!aviso) {
                aviso = document.createElement('div');
                aviso.className = 'sg-vacio';
                aviso.setAttribute('data-sg-cao-sinfiltro', '1');
                aviso.innerHTML = '<div class="sg-vacio-titulo">Nada coincide</div>' +
                    '<div class="sg-vacio-texto">Ninguna de las ' + total +
                    ' alertas de esta pestaña calza con los filtros.</div>' +
                    '<button type="button" class="sg-btn" data-sg-cao-action="limpiar-filtros">' +
                    'Quitar los filtros</button>';
                lista.appendChild(aviso);
            }
            aviso.hidden = false;
        }
        else if (aviso) aviso.hidden = true;
    }

    function limpiarFiltros() {
        var campos = root.querySelectorAll('[data-sg-cao-filtro]');

        for (var i = 0; i < campos.length; i++) campos[i].value = '';

        filtrarEnPantalla();
    }

    /* Si la lista venia cortada en el tope, filtrar en pantalla puede esconder
       coincidencias que nunca llegaron. Solo en ese caso se vuelve a
       preguntar, y con calma: ya se mostro una respuesta. */
    function filtrar() {
        filtrarEnPantalla();

        var lista = uno('.sg-cola-lista', root);

        if (!lista || lista.getAttribute('data-sg-cao-tope') !== '1') return;

        window.clearTimeout(filtroTimer);
        filtroTimer = window.setTimeout(refrescar, 450);
    }

    function mostrarPanel(selector, mostrar) {
        var panel = uno(selector, root);
        if (!panel) return;
        panel.hidden = !mostrar;
        if (mostrar) {
            var foco = panel.querySelector('select, textarea, input');
            if (foco) foco.focus();
        }
    }

    function iniciarCierre(modo) {
        var panel = uno('[data-sg-cao-cierre]', root);
        var rotulo = uno('[data-sg-cao-cierre-rotulo]', root);
        var motivo = uno('[data-sg-cao-motivo]', root);
        if (!panel) return;

        panel.setAttribute('data-modo', modo);
        if (rotulo) rotulo.textContent = modo === 'DESCARTADA'
            ? '¿Por qué se descarta esta alerta?'
            : 'Observación de cierre (opcional)';
        if (motivo) motivo.value = '';
        mostrarPanel('[data-sg-cao-asignar]', false);
        mostrarPanel('[data-sg-cao-cierre]', true);
    }

    function ejecutarAccion(accion) {
        if (accion === 'limpiar-filtros') {
            limpiarFiltros();
            return;
        }

        if (accion === 'revisar') {
            llamar('Revisar', {});
            return;
        }

        if (!estado.alerta) {
            notificar('Elija una alerta.', true);
            return;
        }

        if (accion === 'tomar') llamar('CambiarEstado', {
            alerta: estado.alerta, estado: 'RECONOCIDA', motivo: null
        });
        else if (accion === 'gestionar') llamar('CambiarEstado', {
            alerta: estado.alerta, estado: 'EN GESTION', motivo: null
        });
        else if (accion === 'asignar') {
            mostrarPanel('[data-sg-cao-cierre]', false);
            mostrarPanel('[data-sg-cao-asignar]', true);
        }
        else if (accion === 'asignar-cancelar') mostrarPanel('[data-sg-cao-asignar]', false);
        else if (accion === 'asignar-confirmar') {
            var responsable = entero(valor('[data-sg-cao-responsable]'));
            if (!responsable) {
                notificar('Elija a quién se le asigna.', true);
                return;
            }
            llamar('Asignar', { alerta: estado.alerta, responsable: responsable });
        }
        else if (accion === 'resolver') iniciarCierre('RESUELTA');
        else if (accion === 'descartar') iniciarCierre('DESCARTADA');
        else if (accion === 'cierre-cancelar') mostrarPanel('[data-sg-cao-cierre]', false);
        else if (accion === 'cierre-confirmar') {
            var panel = uno('[data-sg-cao-cierre]', root);
            var modo = panel ? panel.getAttribute('data-modo') : '';
            var motivo = valor('[data-sg-cao-motivo]').replace(/^\s+|\s+$/g, '');

            if (modo === 'DESCARTADA' && motivo.length < 5) {
                notificar('Indique el motivo del descarte.', true);
                return;
            }

            llamar('CambiarEstado', {
                alerta: estado.alerta, estado: modo, motivo: motivo || null
            });
        }
        else if (accion === 'generar-ot') llamar('GenerarOrden', {
            alerta: estado.alerta
        });
    }

    /* La fila elegida, marcada en el acto. Tambien quita la marca de "nueva":
       se acaba de abrir, asi que ya no lo es -y esperar al refresco para
       quitarla la dejaba parpadeando. */
    function marcarSeleccion(fila) {
        var todas = root.querySelectorAll('[data-alerta-id]');

        for (var i = 0; i < todas.length; i++)
            todas[i].classList.remove('is-seleccionada');

        if (!fila) return;

        fila.classList.add('is-seleccionada');
        fila.classList.remove('is-nueva');
        fila.classList.add('is-leida');
    }

    function click(event) {
        var tab = event.target.closest && event.target.closest('[data-sg-cao-tab]');
        if (tab && root.contains(tab)) {
            event.preventDefault();
            estado.tab = tab.getAttribute('data-sg-cao-tab') || 'ACTIVAS';
            estado.alerta = 0;

            /* La pestaña se pinta activa en el acto, por lo mismo que la fila:
               es un dato que el navegador ya tiene. */
            var pestanas = root.querySelectorAll('[data-sg-cao-tab]');
            for (var i = 0; i < pestanas.length; i++)
                pestanas[i].classList.toggle('is-activa', pestanas[i] === tab);

            refrescar();
            return;
        }

        var alerta = event.target.closest && event.target.closest('[data-alerta-id]');
        if (alerta && root.contains(alerta)) {
            event.preventDefault();
            estado.alerta = entero(alerta.getAttribute('data-alerta-id'));

            /* ------------------------------------------------------------------
               LA SELECCION SE MARCA ANTES DE PEDIR NADA

               La fila se pinta como elegida en el mismo instante del clic. Es
               informacion que el navegador YA tiene -cual se toco- y esperar
               al servidor para mostrarla hacia que el primer medio segundo la
               pantalla no acusara recibo del clic.
               ------------------------------------------------------------------ */
            marcarSeleccion(alerta);

            /* Marcar como leida y traer el detalle van EN PARALELO. Estaban en
               serie -primero el POST de lectura, y solo cuando volvia se pedia
               el detalle-, o sea dos esperas sumadas para mostrar algo que no
               depende de la primera. */
            if (window.sigmaAlertas && estado.alerta) sigmaAlertas.leer(estado.alerta);

            refrescar({ soloDetalle: true });
            return;
        }

        var boton = event.target.closest && event.target.closest('[data-sg-cao-action]');
        if (boton && root.contains(boton)) {
            event.preventDefault();
            ejecutarAccion(boton.getAttribute('data-sg-cao-action'));
        }
    }

    /* Sin espera de ningun tipo: ni para el combo ni para la tecla. El
       retardo existia para no inundar al servidor de peticiones; ahora no hay
       peticion que inundar. */
    function cambio(event) {
        if (!event.target.matches || !event.target.matches('[data-sg-cao-filtro]')) return;
        filtrar();
    }

    function entrada(event) {
        if (!event.target.matches || !event.target.matches('[data-sg-cao-filtro="texto"]')) return;
        filtrar();
    }

    function boot() {
        root = uno('[data-sg-cao]');
        if (!root) return;

        var tab = uno('[data-sg-cao-tab].is-activa', root);
        var alerta = uno('[data-alerta-id].is-seleccionada', root);
        estado.tab = tab ? tab.getAttribute('data-sg-cao-tab') : 'ACTIVAS';
        estado.alerta = alerta ? entero(alerta.getAttribute('data-alerta-id')) : 0;

        root.addEventListener('click', click);
        root.addEventListener('change', cambio);
        root.addEventListener('input', entrada);

        window.sigmaNotificaciones = { refrescar: refrescar };
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})(window, document);
