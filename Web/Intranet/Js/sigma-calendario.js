/* ============================================================================
   SIGMA — El calendario del producto
   ----------------------------------------------------------------------------

   POR QUE UNO PROPIO

     Los campos de fecha usaban PopCalendar, un componente compilado de 2008.
     No se puede recolorear, abre una ventana con tabla de los 90, no
     responde al teclado y su icono es un GIF que se ve borroso en cualquier
     pantalla actual. Se podia maquillar el icono por fuera —y se hizo— pero
     el panel que abre seguia siendo otro producto.

   NO REEMPLAZA AL CONTROL DE SERVIDOR

     El <input> sigue siendo el mismo que renderiza `Calendar` / `Calendar2`,
     con su name y su id. Este componente solo le escribe el valor en el
     formato que el servidor ya espera —dd-mm-aaaa—, asi que el postback, la
     validacion y `Value` del code-behind funcionan sin tocar una linea de C#.

     Cambiar el control por uno nuevo habria obligado a revisar veinte
     pantallas y su code-behind. Esto no cambia ninguna.

   COMO ENCUENTRA LOS CAMPOS

     Por el disparador que el control ya emite al lado del input. Se le quita
     su `onclick` —que es lo que abria el popup viejo— y se conecta este.
   ============================================================================ */
(function (window, document) {
    'use strict';

    if (window.SigmaCalendario) return;

    var MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    /* Lunes primero: es como se lee un calendario en Chile, y una semana que
       empieza en domingo hace contar dos veces para ubicar un martes. */
    var DIAS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    var panel = null;
    var campoActivo = null;
    var mesVista = null;

    /* En que esta el panel: 'dias', 'meses' o 'anios'.

       Sin esto, ir de septiembre de 2026 a marzo de 2019 son ochenta y nueve
       clics en la flecha. El titulo es un boton: abre la lista de meses, y
       otra vez la de años. */
    var vista = 'dias';

    /* ------------------------------------------------------------------
       Fechas: siempre dd-mm-aaaa, que es lo que el servidor ya espera.
       ------------------------------------------------------------------ */
    function aTexto(d) {
        if (!d) return '';

        var dd = ('0' + d.getDate()).slice(-2);
        var mm = ('0' + (d.getMonth() + 1)).slice(-2);

        return dd + '-' + mm + '-' + d.getFullYear();
    }

    function aFecha(txt) {
        var m = /^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/.exec((txt || '').trim());
        if (!m) return null;

        var dia = parseInt(m[1], 10);
        var mes = parseInt(m[2], 10) - 1;
        var anio = parseInt(m[3], 10);

        var d = new Date(anio, mes, dia);

        /* Se comprueba que la fecha EXISTA: `new Date(2026, 1, 31)` no falla,
           se corre al 3 de marzo en silencio. Un 31 de febrero escrito a mano
           tiene que rechazarse, no convertirse en otra cosa. */
        if (d.getDate() !== dia || d.getMonth() !== mes || d.getFullYear() !== anio)
            return null;

        return d;
    }

    function mismoDia(a, b) {
        return a && b && a.getDate() === b.getDate() &&
               a.getMonth() === b.getMonth() && a.getFullYear() === b.getFullYear();
    }

    /* ------------------------------------------------------------------
       El panel
       ------------------------------------------------------------------ */
    function crear() {
        if (panel) return panel;

        panel = document.createElement('div');
        panel.className = 'sg-cal';
        panel.setAttribute('role', 'dialog');
        panel.setAttribute('aria-label', 'Seleccionar fecha');
        panel.style.display = 'none';

        document.body.appendChild(panel);

        /* El clic dentro no cierra; el de afuera si. */
        panel.addEventListener('mousedown', function (e) { e.stopPropagation(); });

        return panel;
    }

    function pintar() {
        if (!panel || !mesVista) return;

        var hoy = new Date();
        var elegida = aFecha(campoActivo ? campoActivo.value : '');

        var anio = mesVista.getFullYear();
        var mes = mesVista.getMonth();

        /* El paso de las flechas depende de la vista: en meses avanza un año,
           en años avanza una decada. Si siempre avanzara un mes, en la vista
           de años la flecha no haria nada visible. */
        var paso = vista === 'dias' ? 'mes' : (vista === 'meses' ? 'anio' : 'decada');

        var titulo = vista === 'dias' ? MESES[mes] + ' ' + anio
                   : vista === 'meses' ? String(anio)
                   : decadaDe(anio) + ' – ' + (decadaDe(anio) + 11);

        var html = '<div class="sg-cal-cab">' +
            '<button type="button" class="sg-cal-nav" data-cal="-1" aria-label="Anterior">' +
            '<i class="mdi mdi-chevron-left"></i></button>' +
            '<button type="button" class="sg-cal-mes" data-cal-vista="1" ' +
            'aria-label="Cambiar mes o año">' + titulo +
            (vista === 'anios' ? '' : '<i class="mdi mdi-chevron-down"></i>') + '</button>' +
            '<button type="button" class="sg-cal-nav" data-cal="1" aria-label="Siguiente">' +
            '<i class="mdi mdi-chevron-right"></i></button>' +
            '</div>';

        /* ---- vista de meses ---- */
        if (vista === 'meses') {
            html += '<div class="sg-cal-saltos">';

            for (var mi = 0; mi < 12; mi++) {
                html += '<button type="button" class="sg-cal-salto' +
                        (mi === mes ? ' is-actual' : '') + '" data-mes="' + mi + '">' +
                        MESES[mi].slice(0, 3) + '</button>';
            }

            html += '</div>';
            panel.innerHTML = html + pie();
            return;
        }

        /* ---- vista de años ---- */
        if (vista === 'anios') {
            var base = decadaDe(anio);

            html += '<div class="sg-cal-saltos">';

            for (var ai = 0; ai < 12; ai++) {
                var a2 = base + ai;
                html += '<button type="button" class="sg-cal-salto' +
                        (a2 === anio ? ' is-actual' : '') + '" data-anio="' + a2 + '">' +
                        a2 + '</button>';
            }

            html += '</div>';
            panel.innerHTML = html + pie();
            return;
        }

        html += '<div class="sg-cal-semana">';

        for (var i = 0; i < 7; i++) html += '<span>' + DIAS[i] + '</span>';

        html += '</div><div class="sg-cal-dias">';

        var primero = new Date(anio, mes, 1);

        /* getDay() da 0 para domingo. Se convierte a "lunes = 0" para que la
           primera columna sea el lunes. */
        var desfase = (primero.getDay() + 6) % 7;

        for (var h = 0; h < desfase; h++) html += '<span class="sg-cal-dia is-vacio"></span>';

        var ultimo = new Date(anio, mes + 1, 0).getDate();

        for (var d = 1; d <= ultimo; d++) {
            var fecha = new Date(anio, mes, d);

            var clase = 'sg-cal-dia';
            if (mismoDia(fecha, hoy)) clase += ' is-hoy';
            if (mismoDia(fecha, elegida)) clase += ' is-elegido';

            /* Sábado y domingo se atenúan: en mantenimiento se trabaja, así
               que no se bloquean —solo se distinguen. */
            if (fecha.getDay() === 0 || fecha.getDay() === 6) clase += ' is-finde';

            html += '<button type="button" class="' + clase + '" data-dia="' + d + '">' + d + '</button>';
        }

        panel.innerHTML = html + '</div>' + pie();
    }

    /* El mismo pie en las tres vistas: "Hoy" y "Limpiar" tienen sentido
       siempre, y moverlos de lugar segun la vista obliga a buscarlos. */
    function pie() {
        return '<div class="sg-cal-pie">' +
            '<button type="button" class="sg-cal-accion" data-cal-hoy="1">Hoy</button>' +
            '<button type="button" class="sg-cal-accion is-limpiar" data-cal-limpiar="1">Limpiar</button>' +
            '</div>';
    }

    /* La decada empieza en el año terminado en 0 menos uno, para que la
       cuadricula de 12 muestre el año actual con contexto a los dos lados. */
    function decadaDe(anio) {
        return Math.floor(anio / 10) * 10 - 1;
    }

    function ubicar(campo) {
        var r = campo.getBoundingClientRect();

        panel.style.display = 'block';

        var alto = panel.offsetHeight;
        var ancho = panel.offsetWidth;

        /* Se abre hacia arriba si abajo no cabe: un calendario cortado por el
           borde de la ventana obliga a desplazar la pagina para elegir un
           dia. */
        var abajo = window.innerHeight - r.bottom;
        var top = abajo < alto + 12 && r.top > alto + 12
                ? r.top - alto - 6
                : r.bottom + 6;

        /* En pantalla angosta el panel ocupa casi todo el ancho, asi que
           anclarlo al campo lo dejaria cortado: se centra. */
        var left = window.innerWidth < 460
                 ? Math.max(8, (window.innerWidth - ancho) / 2)
                 : Math.min(r.left, window.innerWidth - ancho - 12);

        /* position: fixed, no absolute: los filtros y los modales tienen su
           propio scroll, y con absolute el panel se recorta contra ellos. */
        panel.setAttribute('data-arriba', top < r.top ? '1' : '0');

        panel.style.top = Math.max(8, top) + 'px';
        panel.style.left = Math.max(8, left) + 'px';
    }

    function abrir(campo) {
        if (!campo || campo.readOnly || campo.disabled) return;

        crear();

        campoActivo = campo;

        /* Siempre se abre en los dias, aunque la vez anterior se haya quedado
           en la lista de años: lo que se viene a hacer es elegir un dia. */
        vista = 'dias';

        var actual = aFecha(campo.value);
        mesVista = actual ? new Date(actual.getFullYear(), actual.getMonth(), 1)
                          : new Date(new Date().getFullYear(), new Date().getMonth(), 1);

        pintar();
        ubicar(campo);
        animarEntrada();
    }

    /* ==================================================================
       LA ENTRADA

       El panel crece desde la esquina que toca el campo, no desde su centro:
       asi se lee como que SALE del campo y no como que aparece encima. Por
       eso el `transformOrigin` cambia segun se abra hacia arriba o hacia
       abajo.

       Los dias entran escalonados y muy rapido —dos centesimas entre uno y
       otro—. Mas lento se convierte en una espera; sin escalonar, la
       cuadricula aparece de golpe y se pierde la sensacion de que se esta
       armando.

       Si GSAP no esta, el panel simplemente aparece. Nada depende de la
       animacion para funcionar.
       ================================================================== */
    function animarEntrada() {
        if (!window.gsap || !panel) return;

        gsap.killTweensOf(panel);

        panel.style.transformOrigin = panel.getAttribute('data-arriba') === '1'
            ? 'left bottom' : 'left top';

        gsap.fromTo(panel,
            { opacity: 0, scale: .94, y: panel.getAttribute('data-arriba') === '1' ? 6 : -6 },
            { opacity: 1, scale: 1, y: 0, duration: .22, ease: 'power3.out',
              clearProps: 'transform,opacity' });

        animarDias();
    }

    /* Los dias, o los meses/años segun la vista. */
    function animarDias() {
        if (!window.gsap || !panel) return;

        var celdas = panel.querySelectorAll('.sg-cal-dia:not(.is-vacio), .sg-cal-salto');

        if (!celdas.length) return;

        gsap.fromTo(celdas,
            { opacity: 0, scale: .8 },
            { opacity: 1, scale: 1, duration: .18, ease: 'back.out(2)',
              stagger: 0.012, clearProps: 'transform,opacity' });
    }

    /* Al cambiar de mes solo se rehace la cuadricula: animar el panel entero
       otra vez lo haria saltar en su sitio. */
    function animarCambio(dir) {
        if (!window.gsap || !panel) return;

        var caja = panel.querySelector('.sg-cal-dias, .sg-cal-saltos');

        if (!caja) return;

        gsap.fromTo(caja,
            { opacity: 0, x: dir > 0 ? 14 : -14 },
            { opacity: 1, x: 0, duration: .2, ease: 'power2.out',
              clearProps: 'transform,opacity' });
    }

    function cerrar() {
        if (panel) panel.style.display = 'none';
        campoActivo = null;
    }

    function elegir(dia) {
        if (!campoActivo || !mesVista) return;

        var d = new Date(mesVista.getFullYear(), mesVista.getMonth(), dia);

        escribir(campoActivo, d);
        cerrar();
    }

    /* ==================================================================
       ESCRIBIR LA FECHA — Y QUE SOBREVIVA AL POSTBACK

       El RadDatePicker de Telerik (`Calendar2`) NO lee del input visible: su
       valor real vive en un campo oculto de estado que el control mantiene.
       Escribir solo el input dejaba la pantalla mostrando la fecha, pero al
       hacer postback el control leia su estado —vacio— y el filtro se perdia.

       Por eso, cuando el campo pertenece a un RadPicker, se le avisa por su
       propia API: `set_selectedDate` actualiza el estado oculto y ahi si
       viaja en el postback.

       Para los `Calendar` normales basta con el input, que es lo que postea.
       ================================================================== */
    function escribir(campo, fecha) {
        var texto = fecha ? aTexto(fecha) : '';

        campo.value = texto;

        // ---- si es un RadDatePicker, su estado tambien ----
        var picker = campo.closest ? campo.closest('.RadPicker') : null;

        if (picker && window.$find) {
            try {
                var api = $find(picker.id);

                if (api && api.set_selectedDate) {
                    api.set_selectedDate(fecha ? new Date(fecha.getTime()) : null);
                }
                else if (api && api.get_dateInput) {
                    var di = api.get_dateInput();
                    if (di && di.set_selectedDate) di.set_selectedDate(fecha || null);
                }
            } catch (err) {
                /* Si la API de Telerik cambia, al menos el input queda escrito
                   y se ve; no se pierde lo que la persona eligio. */
            }
        }

        /* Hay pantallas que escuchan el input para habilitar un boton o
           recalcular algo. Escribir el value sin disparar el evento las deja
           sin enterarse. */
        disparar(campo, 'input');
        disparar(campo, 'change');

        /* El control viejo valida en blur; sin esto la validacion no corre y
           el campo puede quedar marcado en rojo con una fecha valida. */
        disparar(campo, 'blur');
    }

    function disparar(el, tipo) {
        var e;

        try {
            e = new Event(tipo, { bubbles: true });
        } catch (err) {
            e = document.createEvent('Event');
            e.initEvent(tipo, true, false);
        }

        el.dispatchEvent(e);
    }

    /* ------------------------------------------------------------------
       Los clics del panel
       ------------------------------------------------------------------ */
    document.addEventListener('click', function (e) {
        if (!panel || panel.style.display === 'none') return;

        var t = e.target;
        var boton = t.closest ? t.closest('button') : null;

        if (!boton || !panel.contains(boton)) return;

        e.preventDefault();

        if (boton.hasAttribute('data-cal')) {
            var dir = parseInt(boton.getAttribute('data-cal'), 10);

            if (vista === 'dias')
                mesVista = new Date(mesVista.getFullYear(), mesVista.getMonth() + dir, 1);
            else if (vista === 'meses')
                mesVista = new Date(mesVista.getFullYear() + dir, mesVista.getMonth(), 1);
            else
                mesVista = new Date(mesVista.getFullYear() + dir * 12, mesVista.getMonth(), 1);

            pintar();
            animarCambio(dir);
            return;
        }

        /* El titulo sube un nivel: dias -> meses -> años. */
        if (boton.hasAttribute('data-cal-vista')) {
            vista = vista === 'dias' ? 'meses' : 'anios';
            pintar();
            ubicar(campoActivo);
            animarDias();
            return;
        }

        /* Y elegir baja de vuelta, un nivel a la vez. */
        if (boton.hasAttribute('data-mes')) {
            mesVista = new Date(mesVista.getFullYear(),
                                parseInt(boton.getAttribute('data-mes'), 10), 1);
            vista = 'dias';
            pintar();
            ubicar(campoActivo);
            animarDias();
            return;
        }

        if (boton.hasAttribute('data-anio')) {
            mesVista = new Date(parseInt(boton.getAttribute('data-anio'), 10),
                                mesVista.getMonth(), 1);
            vista = 'meses';
            pintar();
            ubicar(campoActivo);
            animarDias();
            return;
        }

        if (boton.hasAttribute('data-dia')) {
            elegir(parseInt(boton.getAttribute('data-dia'), 10));
            return;
        }

        if (boton.hasAttribute('data-cal-hoy')) {
            var hoy = new Date();
            vista = 'dias';
            mesVista = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
            elegir(hoy.getDate());
            return;
        }

        if (boton.hasAttribute('data-cal-limpiar')) {
            escribir(campoActivo, null);
            cerrar();
        }
    });

    document.addEventListener('mousedown', function () { cerrar(); });

    document.addEventListener('keydown', function (e) {
        if (e.keyCode === 27) cerrar();
    });

    /* ==================================================================
       AL DESPLAZAR O REDIMENSIONAR, EL PANEL SE REUBICA. NO SE CIERRA.

       EL SINTOMA

         Dentro de una ventana modal, el calendario se abria y a los pocos
         milisegundos desaparecia solo.

       LA CAUSA

         Aca decia `cerrar`. Y el modal de SIGMA mide el alto de su contenido
         para ajustar el iframe: cuando algo cambia en el DOM de adentro,
         vuelve a medir y le cambia la altura. Abrir el calendario AGREGA un
         nodo, o sea dispara esa medicion, o sea cambia el alto del iframe, o
         sea el iframe emite `resize`... y el calendario se cerraba a si
         mismo. Se abria por el clic y se cerraba por haberse abierto.

       LA CORRECCION

         El motivo de cerrar era que el panel quedaria flotando lejos de su
         campo. Pero eso se arregla moviendolo, no escondiendolo: se vuelve a
         anclar al campo y sigue abierto, que es lo que la persona pidio al
         hacer clic.

         Solo se cierra si el campo dejo de estar a la vista -por ejemplo si
         se desplazo hasta sacarlo de la pantalla-: ahi el panel ya no tiene
         a que apuntar.
       ================================================================== */
    function seguirAlCampo() {
        if (!panel || panel.style.display === 'none' || !campoActivo) return;

        /* Si el campo ya no esta en pantalla, el panel no tiene anclaje. */
        var r = campoActivo.getBoundingClientRect();
        var fuera = r.bottom < 0 || r.top > (window.innerHeight || 0) ||
                    r.right < 0 || r.left > (window.innerWidth || 0);

        if (fuera) cerrar();
        else ubicar(campoActivo);
    }

    window.addEventListener('scroll', seguirAlCampo, true);
    window.addEventListener('resize', seguirAlCampo);

    /* ------------------------------------------------------------------
       CONECTAR LOS CAMPOS

       El disparador es el elemento que el control emite al lado del input.
       Se le quita su `onclick` —lo que abria el popup viejo— y se le pone
       este. El input tambien abre al hacer clic, que es lo que la gente
       intenta primero.
       ------------------------------------------------------------------ */
    /* ======================================================================
       EL DISPARADOR SE BUSCA POR ESTRUCTURA, NO POR ETIQUETA

       EL SINTOMA

         Al hacer clic en el campo se abria el calendario de SIGMA, y al hacer
         clic en el icono de al lado se abria el viejo. Dos calendarios
         distintos en el mismo campo, segun donde se tocara.

       LA CAUSA

         La lista de disparadores nombraba etiquetas concretas: `img`, `a`,
         `input[type=image]`. PopCalendar es un componente compilado de 2008 y
         no siempre emite el mismo elemento -segun la version y la
         configuracion puede salir un <button> o un <input type=button>-.
         Cuando salia uno de esos, no lo tomaba nadie: el campo quedaba
         conectado al calendario nuevo y el icono seguia con el viejo.

       LA CORRECCION

         Se recorre el ENVOLTORIO y se toma como disparador todo lo que sea
         pulsable y no sea el campo de texto. Deja de importar que etiqueta
         elija emitir el control.

       Y SE CLONA ANTES DE CONECTAR

         Quitar el atributo `onclick` solo desarma el manejador escrito en el
         HTML. Si el control se engancho por codigo -`attachEvent` o
         `addEventListener`- ese manejador no se puede quitar sin la
         referencia a la funcion, que no tenemos.

         Reemplazar el elemento por un clon de si mismo se lleva TODOS sus
         escuchas de una vez: el clon es identico en aspecto y atributos, pero
         nace sin nada conectado. Recien ahi se le pone el nuestro.
       ====================================================================== */
    var ENVOLTORIOS = '.sigma-modal-fecha, .sigma-filtro-fecha, .filtroPersonalizado, .RadPicker';

    /* Pulsable y que no sea el campo donde se escribe la fecha. */
    var PULSABLES = 'a, img, button, input[type="image"], input[type="button"], input[type="submit"], .rcCalPopup';

    function disparadoresDe(raiz) {
        var cajas = (raiz || document).querySelectorAll(ENVOLTORIOS);
        var lista = [];

        Array.prototype.forEach.call(cajas, function (caja) {
            Array.prototype.forEach.call(caja.querySelectorAll(PULSABLES), function (el) {
                /* El campo de texto no es un disparador: tiene su propio
                   manejador mas abajo, y conectarle este ademas lo haria
                   abrir y cerrar en el mismo clic. */
                if (el.tagName === 'INPUT' && (el.type === 'text' || el.type === 'hidden')) return;
                lista.push(el);
            });
        });

        /* Los de Telerik pueden vivir fuera de un envoltorio conocido. */
        Array.prototype.forEach.call((raiz || document).querySelectorAll('.rcCalPopup'), function (el) {
            if (lista.indexOf(el) < 0) lista.push(el);
        });

        return lista;
    }

    function conectar(raiz) {
        var disparadores = disparadoresDe(raiz);

        disparadores.forEach(function (dis) {
            if (dis.getAttribute('data-sgcal') === '1') return;

            /* El de Telerik se deja como esta. Su calendario ya se apaga por
               la API en `apagarTelerik()`, y el control guarda una referencia
               a ESTE elemento: cambiarselo por un clon lo dejaria apuntando a
               un nodo que ya no esta en la pagina, y con el se irian tambien
               `set_selectedDate` y el resto del estado que las pantallas de
               Movimientos necesitan para que la fecha sobreviva al postback. */
            var esTelerik = dis.classList && dis.classList.contains('rcCalPopup');

            /* El clon nace sin escuchas. Se reemplaza ANTES de marcarlo y de
               conectarle nada, porque el clon es otro elemento. */
            if (!esTelerik && dis.parentNode) {
                var limpio = dis.cloneNode(true);
                dis.parentNode.replaceChild(limpio, dis);
                dis = limpio;
            }

            dis.setAttribute('data-sgcal', '1');

            /* Lo que quedaba escrito en el HTML. El `href` tambien: un
               `javascript:` en un <a> se ejecuta al navegar, y eso es otra
               forma de abrir el popup viejo. */
            dis.removeAttribute('onclick');
            dis.onclick = null;

            if (dis.tagName === 'A') {
                dis.removeAttribute('href');
                dis.style.cursor = 'pointer';
            }

            var campo = campoDe(dis);
            if (!campo) return;

            /* El estado se lee en MOUSEDOWN, antes de que el cierre global
               lo borre; la accion se hace ahi mismo. Con el click era tarde:
               el panel ya estaba cerrado y volvia a abrirse siempre. */
            dis.addEventListener('mousedown', function (e) {
                e.preventDefault();
                e.stopPropagation();

                var abierto = campoActivo === campo && panel && panel.style.display !== 'none';

                if (abierto) cerrar();
                else abrir(campo);
            });

            /* El click se anula: el control viejo lo usaba para su popup. */
            dis.addEventListener('click', function (e) {
                e.preventDefault();
                e.stopPropagation();
                return false;
            });
        });

        var campos = (raiz || document).querySelectorAll(
            '.sigma-modal-fecha input[type="text"], .sigma-filtro-fecha input[type="text"],' +
            '.RadPicker input.riTextBox');

        Array.prototype.forEach.call(campos, function (campo) {
            if (campo.getAttribute('data-sgcal') === '1') return;
            campo.setAttribute('data-sgcal', '1');

            /* El control viejo abria su popup al enfocar. Se corta. */
            campo.removeAttribute('onfocus');
            campo.onfocus = null;

            campo.addEventListener('mousedown', function (e) {
                e.stopPropagation();

                var abierto = campoActivo === campo && panel && panel.style.display !== 'none';

                if (!abierto) abrir(campo);
            });
        });
    }

    /* El input que le corresponde a un disparador: el hermano de texto mas
       cercano hacia atras, y si no, el primero de su contenedor. */
    /* De que campo es este disparador.

       Primero se prueba entre HERMANOS, que es el caso simple y el mas
       seguro: si en una fila hay dos fechas -"Desde" y "Hasta"-, el icono de
       cada una esta al lado de su propio campo, y buscar en el envoltorio
       comun devolveria siempre el primero.

       Recien si no hay hermano se sube al envoltorio. Eso cubre a los
       controles que se dibujan dentro de una tabla, donde el icono y el
       campo quedan en celdas distintas y por lo tanto no son hermanos. */
    function campoDe(dis) {
        var prev = dis.previousElementSibling;

        while (prev) {
            if (prev.tagName === 'INPUT' && prev.type === 'text') return prev;

            var dentro = prev.querySelector && prev.querySelector('input[type="text"]');
            if (dentro) return dentro;

            prev = prev.previousElementSibling;
        }

        var caja = dis.parentNode;

        while (caja && caja !== document) {
            var campo = caja.querySelector && caja.querySelector('input[type="text"]');
            if (campo) return campo;

            /* No se sube mas alla del envoltorio: fuera de el, el primer
               input de texto que aparezca puede ser el buscador de la
               pantalla, y el calendario terminaria escribiendo ahi. */
            if (caja.matches && caja.matches(ENVOLTORIOS)) break;

            caja = caja.parentNode;
        }

        return null;
    }

    /* Telerik vuelve a enganchar su popup en cada refresco, asi que no basta
       con quitar el onclick una vez: se le apaga por su propia API. */
    function apagarTelerik() {
        if (!window.$find || !window.Telerik) return;

        var pickers = document.querySelectorAll('.RadPicker');

        Array.prototype.forEach.call(pickers, function (nodo) {
            try {
                var p = $find(nodo.id);

                if (p && p.get_datePopupButton) {
                    var b = p.get_datePopupButton();
                    if (b) b.onclick = function () { return false; };
                }

                if (p && p.set_showPopupOnFocus) p.set_showPopupOnFocus(false);
            } catch (err) { /* si la API cambia, el resto sigue funcionando */ }
        });
    }

    if (document.readyState === 'loading')
        document.addEventListener('DOMContentLoaded', function () { conectar(); apagarTelerik(); });
    else {
        conectar();
        apagarTelerik();
    }

    /* Tras un refresco parcial los campos son otros y hay que reconectarlos. */
    if (window.Sys && window.Sys.WebForms && Sys.WebForms.PageRequestManager) {
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
            cerrar();
            conectar();
            apagarTelerik();
        });
    }

    window.SigmaCalendario = { abrir: abrir, cerrar: cerrar, conectar: conectar };

})(window, document);
