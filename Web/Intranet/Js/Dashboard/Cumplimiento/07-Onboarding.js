    function dclSaveCurrentLayout() {
        dclPromptSaveLayout(dclGetCfg());
        dclCloseLayoutsPanel();
    }
     
    // ═══════════════════════════════════════════════════════════════════
    // ONBOARDING — tour guiado con spotlight
    // Se muestra UNA sola vez (se marca como visto tanto al terminarlo como al
    // saltarlo). El botón de ayuda lo relanza a pedido.
    // ═══════════════════════════════════════════════════════════════════
    var _DCL_ONB_KEY     = 'dcl_onb_visto';       // tour del dashboard
    var _DCL_ONB_BLD_KEY = 'dcl_onb_bld_visto';   // tour del constructor
    var _dclOnbPasos     = [];
    var _dclOnbIdx       = 0;
    var _dclOnbKeyActual = _DCL_ONB_KEY;          // clave del tour en curso

    var _dclOnbAgendado = false;   // evita agendarlo dos veces en la misma carga

    function dclOnbVistoKey(key) {
        try { return localStorage.getItem(key) === '1'; } catch (e) { return true; }
    }

    // Agenda el tour para cuando el splash de entrada haya desaparecido.
    // Se espera a que el elemento REALMENTE se vaya del DOM en vez de asumir una
    // duración fija: el splash se quita a los ~3.4 s y un timeout de 3.2 s lo
    // abrea por debajo de la pantalla de bienvenida.
    function dclOnbAgendar() {
        if (_dclOnbAgendado || dclOnbVisto()) return;
        _dclOnbAgendado = true;

        var intentos = 0;
        (function esperarSplash() {
            intentos++;
            var splash = document.getElementById('dcl-splash');
            if (!splash || intentos > 45) {          // tope ~9 s por si no hay splash
                setTimeout(function () { dclOnboardingStart(false); }, 300);
                return;
            }
            setTimeout(esperarSplash, 200);
        })();
    }
    function dclOnbVisto() { return dclOnbVistoKey(_DCL_ONB_KEY); }
    function dclOnbMarcarVisto() {
        try { localStorage.setItem(_dclOnbKeyActual, '1'); } catch (e) { }
    }

    // Primer elemento del selector que esté REALMENTE VISIBLE. Es clave: todos
    // los widgets se renderizan siempre y el layout oculta los que no usa, así
    // que querySelector() podía devolver uno con display:none — su rect es 0×0 y
    // el spotlight quedaba en una esquina sin enfocar nada.
    function dclOnbBuscar(sel) {
        var els = document.querySelectorAll(sel);
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            if (e.offsetParent === null) continue;          // oculto o sin layout
            var r = e.getBoundingClientRect();
            if (r.width > 0 && r.height > 0) return e;
        }
        return null;
    }

    // Los pasos apuntan a selectores; los que no existen o no están visibles en
    // la vista actual se descartan (p.ej. el combo de cliente no se muestra si
    // el usuario tiene uno solo).
    function dclOnbDefinirPasos() {
        return [
            {
                sel: '.dcl-filter-row--datos',
                tit: 'Filtros de datos',
                txt: 'Aquí eliges <b>qué</b> ver: cliente, instalación, zona y el rango de fechas. ' +
                     'Todo el dashboard se recalcula con esta selección.'
            },
            {
                sel: '.dcl-btn-buscar',
                tit: 'Buscar',
                txt: 'Aplica los filtros. La carga es instantánea, sin recargar la página.'
            },
            {
                sel: '.dcl-filter-row--cfg',
                tit: 'Configuración del dashboard',
                txt: 'Esta segunda fila controla <b>cómo</b> se ve el dashboard, no qué datos trae.'
            },
            {
                sel: '.dcl-filter-row--cfg .dcl-btn--tool',
                tit: 'Personalizar layout',
                txt: 'Abre el constructor: agregas filas de 1 a 4 columnas y arrastras los widgets ' +
                     'que quieras. Cada nivel (General, Instalación, Zona) tiene su propio layout.'
            },
            {
                sel: '#dcl-layouts-btn',
                tit: 'Mis Layouts',
                txt: 'Guarda distintas configuraciones con nombre y cambia entre ellas con un clic. ' +
                     'El layout <b>Por defecto del sistema</b> siempre está disponible.'
            },
            {
                sel: '#dcl-refresh-btn',
                tit: 'Actualización automática',
                txt: 'Definís cada cuánto se refrescan los datos solos. Útil para dejar el dashboard ' +
                     'en pantalla como monitoreo.'
            },
            {
                sel: '#dcl-meta-btn',
                tit: 'Parametrización de gráficos',
                txt: 'Ajustas la <b>meta de cumplimiento</b>. Ese porcentaje define el velocímetro y ' +
                     'los colores de las barras en todo el dashboard.'
            },
            {
                sel: '#dcl-reset-btn',
                tit: 'Restablecer configuración',
                txt: 'Vuelve todo al layout por defecto del sistema y borra tus layouts guardados. ' +
                     'Pide confirmación antes de hacerlo.'
            },
            {
                sel: '#btnExportExcel, [id$="btnExportExcel"]',
                tit: 'Exportar a Excel',
                txt: 'Descarga un archivo con <b>una hoja por cada widget</b> que tengas en pantalla, ' +
                     'respetando el layout y el nivel en el que estés.'
            },
            {
                // Se enfoca una fila clickeable real (barra de instalación/zona);
                // si el layout no tiene ninguna, cae al primer widget visible.
                sel: '.dcl-bar-row--drill, .dcl-inst-row, #dcl-content .dcl-section',
                tit: 'Navegación entre niveles',
                txt: 'En cumplimiento por instalación o por zona, <b>haz clic en una fila</b> para entrar ' +
                     'a su dashboard. Vuelves con la ruta de navegación que aparece arriba.'
            },
            {
                sel: '#dcl-help-btn',
                tit: '¿Necesitás repasarlo?',
                txt: 'Este botón vuelve a mostrar el tutorial cuando quieras. ¡Listo para empezar!'
            }
        ];
    }

    // ── Tour del constructor de dashboards ────────────────────────────────
    // Incluye una DEMOSTRACIÓN del gesto de arrastrar: explicarlo con palabras
    // no alcanza, y es la interacción central del constructor.
    function dclOnbPasosBuilder() {
        return [
            {
                sel: '.dcl-bld-modal-hd',
                tit: 'Constructor de dashboards',
                txt: 'Aquí armás el layout: definís las filas y colocás en cada columna el widget ' +
                     'que quieras. El layout pertenece a la <b>categoría</b> que ves en el encabezado.'
            },
            {
                sel: '.dcl-bld-addrow-bar',
                tit: '1. Agrega una fila',
                txt: 'Elige de cuántas columnas la quieres: <b>1, 2, 3 o 4</b>. Puedes apilar todas las ' +
                     'filas que necesites y borrarlas con la papelera de cada una.'
            },
            {
                sel: '.dcl-bld-aside',
                tit: '2. Elige un widget',
                txt: 'Este panel lista los widgets disponibles <b>para este nivel</b>. Puedes buscarlos ' +
                     'por nombre o filtrar por KPI, Gráfico o Tabla.'
            },
            {
                // Con el lienzo en blanco todavía no hay filas: se enfoca el canvas
                // para que el paso no desaparezca. La demo solo corre si ya hay
                // una columna donde soltar.
                sel: '.dcl-bld-row-body, .dcl-bld-canvas',
                tit: '3. Arrastralo a una columna',
                txt: 'Tomá el widget del panel y soltalo sobre un hueco. La columna se ilumina ' +
                     'cuando puedes soltar. <i>(Si todavía no agregaste una fila, hacelo primero.)</i>',
                demo: 'drag'
            },
            {
                sel: '.dcl-bld-row-body .dcl-bld-col, .dcl-bld-canvas',
                tit: 'Una columna, un widget',
                txt: 'Si soltás sobre una columna ocupada, los widgets <b>se intercambian</b>. Con la ' +
                     '<b>✕</b> vaciás la columna: dejarla vacía sirve como separador.'
            },
            {
                sel: '.dcl-bld-clear-btn',
                tit: 'Limpiar',
                txt: 'Vacía el lienzo completo y devuelve todos los widgets al panel, por si quieres ' +
                     'empezar de nuevo.'
            },
            {
                sel: '.dcl-bld-apply-btn',
                tit: 'Aplicar vs. Guardar',
                txt: '<b>Aplicar</b> usa el layout ahora sin darle nombre. <b>Guardar como…</b> lo ' +
                     'conserva en Mis Layouts para volver a él cuando quieras.'
            }
        ];
    }

    function dclOnbBuilderStart(forzado) {
        if (!forzado && dclOnbVistoKey(_DCL_ONB_BLD_KEY)) return;
        dclTourIniciar(dclOnbPasosBuilder(), _DCL_ONB_BLD_KEY);
    }

    function dclOnboardingStart(forzado) {
        if (!forzado && dclOnbVisto()) return;
        // No superponer el tour del dashboard a un overlay (builder/presentación).
        if (!forzado && dclHayOverlayAbierto()) return;
        // Antesala de bienvenida: da contexto antes de empezar a señalar botones.
        dclOnbBienvenida(function () {
            dclTourIniciar(dclOnbDefinirPasos(), _DCL_ONB_KEY);
        });
    }

    // ── Bienvenida del tutorial (overlay fullscreen) ──────────────────────
    // NO es un modal: ocupa toda la pantalla, presenta el logo y el saludo con
    // una secuencia animada, y se retira sola a los pocos segundos dando paso
    // al recorrido. Fondo sólido de la paleta (sin degradados fuertes, que
    // apagaban el texto) y un único acento para el detalle.
    var _dclOnbWelTimers = [];
    // Duración total antes del auto-cierre. Debe coincidir con la animación
    // .dcl-onb-wel-prog-bar del CSS, que es la que muestra el avance.
    var _DCL_ONB_WEL_MS  = 8000;

    function dclOnbBienvenida(onComenzar) {
        dclOnbWelLimpiar();

        var nombre = (window._dclUsuarioNombre || '').trim();
        var saludo = nombre ? ('Bienvenido, ' + dclEsc(nombre)) : 'Bienvenido';
        var logo   = window._dclLogoUrl || '';

        var ov = document.createElement('div');
        ov.id = 'dcl-onb-wel';
        ov.className = 'dcl-onb-wel';
        ov.innerHTML =
            '<div class="dcl-onb-wel-bg"></div>' +
            '<div class="dcl-onb-wel-in">' +
            (logo ? '<img src="' + logo + '" alt="FacilityGes" class="dcl-onb-wel-logo" />' : '') +
            '<div class="dcl-onb-wel-line"></div>' +
            '<h2 class="dcl-onb-wel-tit">' + saludo + '</h2>' +
            '<p class="dcl-onb-wel-sub">Dashboard de Cumplimiento de Checklists</p>' +
            '<p class="dcl-onb-wel-txt">A continuaci&oacute;n ver&aacute;s un breve recorrido para aprender ' +
            'a filtrar la informaci&oacute;n, armar tu propio dashboard y navegar hasta el detalle de cada zona.</p>' +
            '<div class="dcl-onb-wel-prog"><span class="dcl-onb-wel-prog-bar"></span></div>' +
            '<button type="button" class="dcl-onb-wel-skip" data-act="skip">Saltar tutorial</button>' +
            '</div>';

        ov.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== ov && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            if (el && el.getAttribute && el.getAttribute('data-act') === 'skip') {
                // Saltar desde aquí cuenta como visto: no vuelve a salir solo.
                _dclOnbKeyActual = _DCL_ONB_KEY;
                dclOnbMarcarVisto();
                dclOnbWelCerrar(ov, null);
            }
        });

        document.body.appendChild(ov);
        document.body.classList.add('dcl-onb-activo');

        // Secuencia: entra el fondo → aparecen los elementos escalonados (CSS) →
        // la barra de progreso marca el tiempo → sale.
        requestAnimationFrame(function () { ov.classList.add('dcl-onb-wel--open'); });
        _dclOnbWelTimers.push(setTimeout(function () {
            dclOnbWelCerrar(ov, onComenzar);
        }, _DCL_ONB_WEL_MS));
    }

    function dclOnbWelLimpiar() {
        for (var i = 0; i < _dclOnbWelTimers.length; i++) clearTimeout(_dclOnbWelTimers[i]);
        _dclOnbWelTimers = [];
        var previo = document.getElementById('dcl-onb-wel');
        if (previo && previo.parentNode) previo.parentNode.removeChild(previo);
    }

    function dclOnbWelCerrar(ov, cb) {
        for (var i = 0; i < _dclOnbWelTimers.length; i++) clearTimeout(_dclOnbWelTimers[i]);
        _dclOnbWelTimers = [];
        if (!ov || !ov.parentNode) { if (cb) cb(); return; }

        ov.classList.remove('dcl-onb-wel--open');
        ov.classList.add('dcl-onb-wel--out');
        setTimeout(function () {
            if (ov.parentNode) ov.parentNode.removeChild(ov);
            document.body.classList.remove('dcl-onb-activo');
            if (cb) cb();
        }, 620);   // acompaña a la animación de salida
    }

    function dclTourIniciar(defs, key) {
        if (document.getElementById('dcl-onb')) return;

        _dclOnbKeyActual = key;
        _dclOnbPasos = [];
        for (var i = 0; i < defs.length; i++) {
            if (dclOnbBuscar(defs[i].sel)) _dclOnbPasos.push(defs[i]);
        }
        if (!_dclOnbPasos.length) return;

        _dclOnbIdx = 0;

        var ov = document.createElement('div');
        ov.id = 'dcl-onb';
        ov.className = 'dcl-onb';
        ov.innerHTML =
            '<div class="dcl-onb-spot" id="dcl-onb-spot"></div>' +
            '<div class="dcl-onb-pop" id="dcl-onb-pop">' +
            '<div class="dcl-onb-pop-hd">' +
            '<span class="dcl-onb-step" id="dcl-onb-step"></span>' +
            '<button type="button" class="dcl-onb-skip" data-act="skip">Saltar tutorial</button>' +
            '</div>' +
            '<h4 class="dcl-onb-tit" id="dcl-onb-tit"></h4>' +
            '<p class="dcl-onb-txt" id="dcl-onb-txt"></p>' +
            '<div class="dcl-onb-dots" id="dcl-onb-dots"></div>' +
            '<div class="dcl-onb-acts">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="prev">' +
            '<i class="mdi mdi-chevron-left"></i>&nbsp;Anterior</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="next" id="dcl-onb-next">' +
            'Siguiente&nbsp;<i class="mdi mdi-chevron-right"></i></button>' +
            '</div>' +
            '</div>';

        ov.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== ov && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            var act = (el && el.getAttribute) ? el.getAttribute('data-act') : null;
            if (act === 'skip')      dclOnboardingEnd();
            else if (act === 'prev') dclOnbIr(_dclOnbIdx - 1);
            else if (act === 'next') dclOnbIr(_dclOnbIdx + 1);
        });

        document.body.appendChild(ov);
        document.body.classList.add('dcl-onb-activo');
        document.addEventListener('keydown', _dclOnbTeclas);
        requestAnimationFrame(function () {
            ov.classList.add('dcl-onb--open');
            dclOnbIr(0);
        });
    }

    function _dclOnbTeclas(e) {
        if (e.key === 'Escape')     { dclOnboardingEnd(); }
        else if (e.key === 'ArrowRight') { dclOnbIr(_dclOnbIdx + 1); }
        else if (e.key === 'ArrowLeft')  { dclOnbIr(_dclOnbIdx - 1); }
    }

    function dclOnbIr(idx) {
        if (idx < 0) return;
        if (idx >= _dclOnbPasos.length) { dclOnboardingEnd(); return; }
        _dclOnbIdx = idx;

        var paso = _dclOnbPasos[idx];
        var el   = dclOnbBuscar(paso.sel);
        // Pudo dejar de estar visible entre el armado de los pasos y este momento
        // (p.ej. un refresh cambió el layout): se salta en vez de enfocar la nada.
        if (!el) { dclOnbIr(idx + 1); return; }

        // Traer el objetivo a la vista antes de medirlo.
        try { el.scrollIntoView({ block: 'center', behavior: 'smooth' }); } catch (e) { }

        setTimeout(function () {
            var r    = el.getBoundingClientRect();
            var pad  = 6;
            var spot = document.getElementById('dcl-onb-spot');
            var pop  = document.getElementById('dcl-onb-pop');
            if (!spot || !pop) return;

            // El "agujero" se logra con un box-shadow gigante alrededor del rect.
            spot.style.top    = (r.top - pad) + 'px';
            spot.style.left   = (r.left - pad) + 'px';
            spot.style.width  = (r.width + pad * 2) + 'px';
            spot.style.height = (r.height + pad * 2) + 'px';

            document.getElementById('dcl-onb-tit').innerHTML  = paso.tit;
            document.getElementById('dcl-onb-txt').innerHTML  = paso.txt;
            document.getElementById('dcl-onb-step').textContent =
                'Paso ' + (idx + 1) + ' de ' + _dclOnbPasos.length;

            var next = document.getElementById('dcl-onb-next');
            if (next) {
                next.innerHTML = (idx === _dclOnbPasos.length - 1)
                    ? '<i class="mdi mdi-check"></i>&nbsp;Entendido'
                    : 'Siguiente&nbsp;<i class="mdi mdi-chevron-right"></i>';
            }
            var prev = pop.querySelector('[data-act="prev"]');
            if (prev) prev.style.visibility = idx === 0 ? 'hidden' : 'visible';

            // Puntitos de progreso
            var dots = document.getElementById('dcl-onb-dots');
            if (dots) {
                var h = '';
                for (var d = 0; d < _dclOnbPasos.length; d++)
                    h += '<span class="dcl-onb-dot' + (d === idx ? ' dcl-onb-dot--on' : '') + '"></span>';
                dots.innerHTML = h;
            }

            dclOnbPosicionarPop(pop, r);

            // Pasos con demostración animada del gesto.
            if (paso.demo === 'drag') dclOnbDemoDrag();
            else                       dclOnbDemoParar();
        }, 220);
    }

    // ── Demostración del arrastre ─────────────────────────────────────────
    // Clona un tile del panel y lo desplaza hasta un hueco del lienzo, marcando
    // la columna como zona de destino. Es solo visual: no modifica el layout.
    var _dclOnbDemoTimers = [];
    function dclOnbDemoParar() {
        for (var i = 0; i < _dclOnbDemoTimers.length; i++) clearTimeout(_dclOnbDemoTimers[i]);
        _dclOnbDemoTimers = [];
        var g = document.getElementById('dcl-onb-ghost');
        if (g && g.parentNode) g.parentNode.removeChild(g);
        var prev = document.querySelector('.dcl-bld-col--onb-demo');
        if (prev) prev.classList.remove('dcl-bld-col--onb-demo');
    }

    function dclOnbDemoDrag() {
        dclOnbDemoParar();

        var tile = dclOnbBuscar('.dcl-bld-aside .dcl-bld-tile:not(.dcl-bld-tile--placed)')
                || dclOnbBuscar('.dcl-bld-aside .dcl-bld-tile');
        // Preferir una columna vacía como destino; si no hay, cualquiera.
        var col = dclOnbBuscar('.dcl-bld-row-body .dcl-bld-col > .dcl-col-slot');
        if (col) col = col.parentNode;
        if (!col) col = dclOnbBuscar('.dcl-bld-row-body .dcl-bld-col');
        if (!tile || !col) return;

        var rt = tile.getBoundingClientRect();
        var rc = col.getBoundingClientRect();

        var ghost = document.createElement('div');
        ghost.id = 'dcl-onb-ghost';
        ghost.className = 'dcl-onb-ghost';
        ghost.style.top    = rt.top + 'px';
        ghost.style.left   = rt.left + 'px';
        ghost.style.width  = rt.width + 'px';
        ghost.style.height = rt.height + 'px';
        ghost.innerHTML = '<span class="dcl-onb-ghost-lbl">' +
                          dclEsc((tile.textContent || 'Widget').trim().split('\n')[0].substring(0, 26)) +
                          '</span><i class="mdi mdi-cursor-move dcl-onb-ghost-cur"></i>';
        document.body.appendChild(ghost);

        // Destino: centro de la columna, corregido por el tamaño del fantasma.
        var dx = (rc.left + rc.width / 2) - (rt.left + rt.width / 2);
        var dy = (rc.top + rc.height / 2) - (rt.top + rt.height / 2);

        function ciclo() {
            ghost.style.transition = 'none';
            ghost.style.transform  = 'translate(0,0) scale(1)';
            ghost.style.opacity    = '0';
            col.classList.remove('dcl-bld-col--onb-demo');

            _dclOnbDemoTimers.push(setTimeout(function () {
                ghost.style.transition = 'opacity .18s';
                ghost.style.opacity    = '1';
            }, 60));

            _dclOnbDemoTimers.push(setTimeout(function () {
                ghost.style.transition = 'transform 1.05s cubic-bezier(.4,.1,.25,1)';
                ghost.style.transform  = 'translate(' + dx + 'px,' + dy + 'px) scale(.9)';
            }, 260));

            // Al llegar, se ilumina la columna (igual que en un drag real)
            _dclOnbDemoTimers.push(setTimeout(function () {
                col.classList.add('dcl-bld-col--onb-demo');
            }, 1050));

            _dclOnbDemoTimers.push(setTimeout(function () {
                ghost.style.transition = 'opacity .22s, transform .22s';
                ghost.style.opacity    = '0';
            }, 1600));

            // Se repite mientras el paso siga visible.
            _dclOnbDemoTimers.push(setTimeout(function () {
                if (document.getElementById('dcl-onb-ghost')) ciclo();
            }, 2200));
        }
        ciclo();
    }

    // Coloca el globo debajo del objetivo; si no entra, arriba; y lo mantiene
