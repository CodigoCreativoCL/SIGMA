/* ============================================================================
   SIGMA — El contador de alertas se refresca solo
   ----------------------------------------------------------------------------

   QUE HACE

     Cada tanto le pregunta al servidor si hay algo nuevo y actualiza el numero
     de la campana y los del menu, sin recargar la pagina. Del otro lado, el
     mismo llamado dispara el detector si al freno de la base le toca.

   POR QUE UN SONDEO Y NO ALGO EN VIVO

     Un canal permanente -WebSocket, SignalR- daria el aviso en el instante,
     pero exige una conexion abierta por pestana y un servidor preparado para
     sostenerlas. Para un hallazgo de inventario, saberlo un minuto despues no
     cambia ninguna decision: nadie repone un rodamiento en sesenta segundos.

   NO PREGUNTA CUANDO NADIE MIRA

     Con la pestana en segundo plano el sondeo se detiene. Una pestana olvidada
     un viernes no tiene por que estar consultando la base todo el fin de
     semana, y al volver se pregunta de inmediato, que es cuando importa.

   SI LA SESION CAYO, DEJA DE PREGUNTAR

     El servicio contesta sesion:false y el sondeo se apaga. Sin eso, una
     pestana abierta despues de un logout seguiria golpeando el servidor.

   EL SERVICIO ES ASMX, NO UN HANDLER

     PATRON_WEBSERVICE_AJAX.md lo dice en su primera linea: nunca .ashx. Y la
     respuesta llega envuelta en .d, que es el error mas comun al portar.
   ============================================================================ */

var sigmaAlertas = (function () {

    var URL = '';
    var RUTA_SVG = '';
    var MS = 60000;               /* Un minuto. Ver el comentario de arriba. */
    var timer = null;
    var pidiendo = false;
    /* Cuenta ALERTAS ACTIVAS -nueva, reconocida, en gestion-, no las no
       leidas. Un jefe que abrio las doce alertas de la manana y no resolvio
       ninguna tenia la campana en cero con la planta igual de mal: el numero
       decia "ya miraste" cuando la pregunta es "que falta por resolver".
       null = todavia no se ha preguntado. */
    var ultimasActivas = null;
    var toastAbierto = 0;
    var sonido = null;


    /* ============================================================
       EL SONIDO

       Se genera con WebAudio en vez de cargar un archivo: son dos
       notas, y un .mp3 seria una peticion mas y un binario que
       versionar para algo que cabe en diez lineas.

       DOS NOTAS ASCENDENTES, CORTAS Y SUAVES

         Un pitido largo o grave se lee como error. Esto anuncia,
         no alarma: quien esta trabajando tiene que poder ignorarlo
         sin sobresaltarse.

       NO SUENA AL ENTRAR

         Igual que el aviso visual: solo cuando el contador SUBE. Un
         sonido en cada carga de pagina volveria loco a cualquiera.
       ============================================================ */
    function sonar() {
        try {
            var AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) return;

            if (!sonido) sonido = new AC();

            /* El navegador bloquea el audio hasta que la persona interactua
               con la pagina. No es un fallo: es la regla, y no se puede
               forzar. Se intenta reanudar y si no, se calla. */
            if (sonido.state === 'suspended') sonido.resume();

            tocar(880, 0);      /* la */
            tocar(1174, 0.12);  /* re */
        }
        catch (e) { /* sin sonido la alerta se ve igual */ }
    }

    function tocar(hz, retardo) {
        var t = sonido.currentTime + retardo;

        var osc = sonido.createOscillator();
        var vol = sonido.createGain();

        osc.type = 'sine';
        osc.frequency.value = hz;

        /* Entra y sale en rampa: un tono que arranca y corta de golpe suena a
           chasquido. */
        vol.gain.setValueAtTime(0, t);
        vol.gain.linearRampToValueAtTime(0.12, t + 0.02);
        vol.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);

        osc.connect(vol);
        vol.connect(sonido.destination);

        osc.start(t);
        osc.stop(t + 0.24);
    }


    /* ============================================================
       LOS CONTADORES
       ============================================================ */
    function badgeCampana(n) {
        var enlace = document.querySelector('.sigma-notification');
        if (!enlace) return;

        var badge = enlace.querySelector('.sigma-notification__count');

        if (n > 0) {
            if (!badge) {
                badge = document.createElement('span');
                badge.className = 'sigma-notification__count';
                badge.setAttribute('aria-hidden', 'true');
                enlace.appendChild(badge);
            }

            badge.textContent = n > 99 ? '99+' : n;
            enlace.setAttribute('aria-label', n + ' alertas sin leer');
        }
        else if (badge) {
            /* Se quita entero y no se deja en cero: un badge con "0" sigue
               pidiendo atencion para decir que no hay nada. */
            badge.parentNode.removeChild(badge);
            enlace.setAttribute('aria-label', 'Alertas');
        }
    }

    /* Los numeros del menu lateral. Solo se ACTUALIZAN los que ya existen: un
       menu que no tenia alerta no puede ganar una sin recargar, porque el
       indicador del modulo padre lo dibuja el servidor y quedaria un numero
       colgando de una rama que no late. */
    function badgesMenu(menus) {
        var badges = document.querySelectorAll('#side-menu .sg-menu-badge');

        for (var i = 0; i < badges.length; i++) {
            var enlace = badges[i].closest ? badges[i].closest('a') : null;
            if (!enlace) continue;

            var href = enlace.getAttribute('href') || '';
            var n = null;

            for (var link in menus) {
                if (!menus.hasOwnProperty(link)) continue;

                /* El servidor devuelve ~/View/... y el enlace trae la ruta ya
                   resuelta: se compara por el final, que es lo unico comun. */
                var cola = link.replace('~', '');

                if (href.length >= cola.length &&
                    href.substring(href.length - cola.length) === cola) {
                    n = menus[link];
                    break;
                }
            }

            if (n === null) continue;

            if (n > 0) badges[i].textContent = n > 99 ? '99+' : n;
            else badges[i].style.display = 'none';
        }
    }


    /* Baja el punto de no leídas AHORA, sin esperar al servidor.

       El viaje tarda entre cien y quinientos milisegundos, y en ese rato el
       usuario ya esta mirando la ficha que abrio. Si el numero baja recien
       cuando vuelve la respuesta, lo que ve es un contador que no reacciono a
       lo que acaba de hacer, y la conclusion razonable es que no funciono.

       Es un adelanto, no una suposicion: la respuesta del servidor manda, y
       cuando llega se reescriben los dos contadores con lo que diga. Si el
       marcado fallo, el numero vuelve solo a donde estaba. */
    function descontarUno(todos) {
        var enlace = document.querySelector('.sigma-notification');
        var badge = enlace ? enlace.querySelector('.sigma-notification__count') : null;
        if (!badge) return;

        var n = parseInt(badge.textContent, 10);
        if (todos || isNaN(n) || n <= 1) {
            badge.parentNode.removeChild(badge);
            enlace.setAttribute('aria-label', 'Alertas');
            return;
        }

        badge.textContent = n - 1;
        enlace.setAttribute('aria-label', (n - 1) + ' alertas sin leer');
    }


    /* ============================================================
       EL AVISO EMERGENTE

       Aparece cuando el contador SUBE, no cada vez que hay alertas
       abiertas. La diferencia importa: con tres alertas viejas sin resolver,
       un aviso en cada sondeo seria un cartel cada minuto hasta que alguien
       reponga el stock, y a los diez minutos la gente lo ignora.

       La primera respuesta nunca lo muestra. Al entrar al sitio el contador
       pasa de "no se" a "tres", y eso no es una novedad: es el estado que ya
       estaba ahi, y la campana ya lo dice.
       ============================================================ */
    function mostrarToast(a) {
        if (!a) return;

        /* CUANDO EL CENTRO DE ACCION OPERACIONAL ESTA ABIERTO, EL AVISO ES SUYO.

           Esa pantalla dibuja el toast DENTRO del contenido: puesto sobre la
           topbar taparia el selector de cliente y la campana, que es justo lo
           que la persona necesita mirar cuando entra un aviso.

           Se delega en vez de duplicar. Si un dia cambia el texto o el orden
           de los datos del aviso, cambia en un solo lugar. */
        if (window.sigmaToast) {
            var iconoAi = a.esPrediccion && window.sigmaToastIconoAi
                        ? window.sigmaToastIconoAi
                        : (RUTA_SVG ? RUTA_SVG + a.icono : '');

            window.sigmaToast(a.titulo, a.detalle, iconoAi,
                              (a.severidad || '') === 'CRITICA', a.id);
            return;
        }

        cerrarToast();

        var t = document.createElement('div');
        t.className = 'sg-toast sev-' + (a.severidad || 'NORMAL').toLowerCase();

        var icono = RUTA_SVG ? '<img src="' + RUTA_SVG + a.icono + '" alt="" />' : '';

        var accion = a.ficha
            ? '<a class="accion" href="javascript:void(0);">Ver detalle <span>&#8594;</span></a>'
            : '';

        t.innerHTML =
            '<div class="icono">' + icono + '</div>' +
            '<div class="cuerpo">' +
                '<div class="tipo">' + escapar(a.tipo) + '</div>' +
                '<div class="titulo">' + escapar(a.titulo) + '</div>' +
                '<div class="detalle">' + escapar(a.detalle) + '</div>' +
                accion +
            '</div>' +
            '<button type="button" class="cerrar" title="Cerrar">&#215;</button>' +
            '<div class="barra"></div>';

        document.body.appendChild(t);

        t.querySelector('.cerrar').onclick = function () { cerrarToast(); };

        var enlace = t.querySelector('.accion');

        if (enlace) {
            enlace.onclick = function () {
                if (window.abrirNotificacion) window.abrirNotificacion(a.ficha, a.query, a.id);
                else window.location = a.ficha + '?query=' + a.query;

                cerrarToast();
                return false;
            };
        }

        sonar();

        /* Se va solo. Ocho segundos alcanzan para leer tres lineas sin que el
           cartel se vuelva parte del decorado. */
        toastAbierto = window.setTimeout(cerrarToast, 8000);

        /* El siguiente cuadro, para que la transicion de entrada corra. */
        window.setTimeout(function () { t.classList.add('is-visible'); }, 20);
    }

    function cerrarToast() {
        if (toastAbierto) { window.clearTimeout(toastAbierto); toastAbierto = 0; }

        var viejo = document.querySelector('.sg-toast');
        if (!viejo) return;

        viejo.classList.remove('is-visible');

        /* Se espera la salida antes de sacarlo del DOM: quitarlo de golpe hace
           que desaparezca sin transicion. */
        window.setTimeout(function () {
            if (viejo.parentNode) viejo.parentNode.removeChild(viejo);
        }, 250);
    }

    function escapar(t) {
        if (!t) return '';

        return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }


    /* ============================================================
       LA CONSULTA
       ============================================================ */
    function preguntar() {
        if (pidiendo || document.hidden) return;
        if (!URL || typeof jQuery === 'undefined') return;

        pidiendo = true;

        jQuery.ajax({
            type: 'POST',
            url: URL + '/Resumen',
            data: '{}',
            contentType: 'application/json; charset=utf-8',
            dataType: 'json',
            success: function (result) {
                pidiendo = false;

                var r;

                /* La respuesta llega envuelta en .d: es el error mas comun al
                   portar este patron. */
                try { r = JSON.parse(result.d); }
                catch (e) { return; }

                if (r.sesion === false) { detener(); return; }
                if (r.error) return;

                /* Solo si SUBIO, y nunca en la primera respuesta. */
                if (ultimasActivas !== null && r.abiertas > ultimasActivas && r.nueva)
                    mostrarToast(r.nueva);

                ultimasActivas = r.abiertas;

                /* La campana dice qué NO se ha visto. Los contadores del menú
                   siguen diciendo qué queda activo: son preguntas distintas. */
                badgeCampana(r.noLeidas);
                if (r.menus) badgesMenu(r.menus);
            },
            error: function () {
                pidiendo = false;
            }
        });
    }

    function arrancar() {
        if (timer) return;
        timer = window.setInterval(preguntar, MS);
    }

    function detener() {
        if (!timer) return;
        window.clearInterval(timer);
        timer = null;
    }

    /* Al volver a la pestana se pregunta de inmediato: quien vuelve quiere ver
       el estado de ahora, no esperar hasta el proximo minuto. */
    document.addEventListener('visibilitychange', function () {
        if (document.hidden) { detener(); return; }

        arrancar();
        preguntar();
    });

    return {
        iniciar: function (url, segundos, rutaSvg) {
            URL = url;
            RUTA_SVG = rutaSvg || '';

            if (segundos && segundos > 0) MS = segundos * 1000;

            arrancar();

            /* La primera se retrasa: la pagina acaba de renderizar sus numeros
               del lado del servidor, y preguntar en el mismo instante seria un
               viaje para confirmar lo que ya esta en pantalla. */
            window.setTimeout(preguntar, MS);
        },

        /* Para despues de marcar leido en el servidor: los numeros ya
           cambiaron y el sondeo no tiene por que esperar un minuto. Se pone
           ultimasActivas en null para que este cambio -que baja el contador-
           no dispare el aviso emergente. */
        refrescar: function () {
            ultimasActivas = null;
            preguntar();
        },

        /* ABRIR UNA ALERTA ES HABERLA LEIDO.

           Lo llaman los tres sitios que abren la ficha de una alerta: el panel
           de la campana, la pantalla de Alertas y el aviso emergente. Los tres
           lo llamaban DESDE ANTES; lo que no existia era este metodo, asi que
           el onclick moria con "sigmaAlertas.leer is not a function" -en
           silencio, porque un error dentro de un onclick no detiene nada- y
           ninguna alerta se marcaba nunca.

           El id va en claro: UPD_ALERTA_LEER filtra por cliente, por usuario y
           por el permiso del tipo, asi que no es una llave sino un numero que
           el procedimiento valida. Y ya estaba impreso en el onclick de la
           propia pagina. */
        leer: function (id, href) {
            if (!URL || typeof jQuery === 'undefined') return null;

            var todos = id === null || typeof id === 'undefined' || id === '';

            descontarUno(todos);

            return jQuery.ajax({
                type: 'POST',
                url: URL + '/Leer',
                data: JSON.stringify({ datos: todos ? '' : String(id) }),
                contentType: 'application/json; charset=utf-8',
                dataType: 'json',
                success: function (result) {
                    var respuesta = null;
                    try { respuesta = JSON.parse(result.d); }
                    catch (e) { respuesta = { error: true }; }

                    /* La cifra de verdad la tiene el servidor: el descuento de
                       recien era para que la pantalla respondiera al toque. */
                    ultimasActivas = null;
                    preguntar();

                    if (!respuesta.error) avisarLectura(respuesta);
                },
                error: function () {
                    /* Si fallo, el sondeo devuelve el numero a donde estaba.
                       Se prefiere eso a dejar un contador adelantado que
                       nadie corrige. */
                    ultimasActivas = null;
                    preguntar();
                }
            });
        },

        ahora: preguntar,
        detener: detener
    };

    function avisarLectura(respuesta) {
        var evento;

        try {
            evento = new CustomEvent('sigma:alertas-actualizadas', {
                detail: respuesta
            });
        }
        catch (e) {
            evento = document.createEvent('CustomEvent');
            evento.initCustomEvent('sigma:alertas-actualizadas', true, true,
                                    respuesta);
        }

        document.dispatchEvent(evento);
    }
})();
