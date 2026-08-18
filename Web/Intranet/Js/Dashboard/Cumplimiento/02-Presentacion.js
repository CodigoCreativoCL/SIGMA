    // El selector de modo se retiró: presentación = TODO el layout, directo.
    // Tener que elegir en un modal cada vez era un paso extra sin valor; los
    // dashboards a rotar se eligen ya dentro, con el botón "Dashboards".
    function dclEnterPresentation() {
        if (document.getElementById('dcl-pres-overlay')) return;
        var cards = document.querySelectorAll('#dcl-content .dcl-section.dcl-card:not(.dcl-sec-pooled)');
        if (!cards.length) return;
        dclPresStartLayout();
    } 
    function dclPresPickerClose() {
        var pk = document.getElementById('dcl-pres-picker');
        if (pk && pk.parentNode) pk.parentNode.removeChild(pk);
    }

    // ── Presentacion: helpers slideshow layout ───────────────────────────
    function dclEstSectionHeightPres(sec) {
        if (sec.offsetHeight > 20) return sec.offsetHeight;
        var lv = parseInt(sec.getAttribute('data-height') || '0', 10);
        return [380, 180, 280, 420, 580][lv] || 380;
    }

    function dclPresCleanClone(clone) {
        var draggables = clone.querySelectorAll('[draggable]');
        for (var i = 0; i < draggables.length; i++) draggables[i].removeAttribute('draggable');
        var hideEls = clone.querySelectorAll('.dcl-rsz,.dcl-rsz-w,.dcl-card-cfg-btn,.dcl-width-btn,.dcl-drag-handle,.dcl-card-reveal,.dcl-bld-addrow-bar,.dcl-rsz-h-btn,.dcl-rsz-sep-h');
        for (var i = 0; i < hideEls.length; i++) hideEls[i].style.display = 'none';
        // Se elimina del DOM (no solo se oculta con CSS) para que no quede
        // rastro del filtro de filas en ningún modo de presentación.
        var searchBoxes = clone.querySelectorAll('.dcl-table-search');
        for (var i = 0; i < searchBoxes.length; i++) {
            if (searchBoxes[i].parentNode) searchBoxes[i].parentNode.removeChild(searchBoxes[i]);
        }
        var interactives = clone.querySelectorAll('button,input,select,textarea');
        for (var i = 0; i < interactives.length; i++) {
            interactives[i].setAttribute('tabindex', '-1');
            interactives[i].style.pointerEvents = 'none';
        }
    }

    function dclPresSlideGo(n) {
        if (!_presSlides.length) return;
        _presSlideIdx = ((n % _presSlides.length) + _presSlides.length) % _presSlides.length;
        var stage = document.getElementById('dcl-pres-stage');
        var content = document.getElementById('dcl-content');
        if (!stage || !content) return;

        var slideData = _presSlides[_presSlideIdx];
        var slideEl = document.createElement('div');
        slideEl.className = 'dcl-pres-slide';

        for (var r = 0; r < slideData.length; r++) {
            var rowData = slideData[r];
            var rowEl = document.createElement('div');
            rowEl.className = 'dcl-pres-row';
            rowEl.setAttribute('data-cols', rowData.cols || 1);
            var slotArr = rowData.slots || [];
            for (var s = 0; s < slotArr.length; s++) {
                var sid = slotArr[s];
                if (!sid) {
                    // Hueco: celda vacía para respetar la posición de la columna
                    var hole = document.createElement('div');
                    hole.className = 'dcl-pres-hole';
                    rowEl.appendChild(hole);
                    continue;
                }
                var sec = content.querySelector('.dcl-section[data-section="' + sid + '"]');
                if (!sec) { var h2 = document.createElement('div'); h2.className = 'dcl-pres-hole'; rowEl.appendChild(h2); continue; }
                var clone = sec.cloneNode(true);
                clone.style.cssText = '';
                clone.classList.add('dcl-pres-card');
                dclPresCleanClone(clone);
                rowEl.appendChild(clone);
            }
            if (rowEl.children.length) slideEl.appendChild(rowEl);
        }

        stage.innerHTML = '';
        stage.appendChild(slideEl);
        void stage.offsetWidth;
        slideEl.classList.add('dcl-pres-slide--in');

        var counter = document.getElementById('dcl-pres-counter');
        if (counter) counter.textContent = (_presSlideIdx + 1) + ' / ' + _presSlides.length;

        var dots = document.getElementById('dcl-pres-dots');
        if (dots) {
            dots.innerHTML = '';
            for (var i = 0; i < _presSlides.length; i++) {
                var d = document.createElement('button');
                d.type = 'button';
                d.className = 'dcl-pres-dot' + (i === _presSlideIdx ? ' dcl-pres-dot--on' : '');
                (function (idx2) { d.onclick = function () { dclPresSlideGo(idx2); dclPresResetTimer(); }; })(i);
                dots.appendChild(d);
            }
        }
        var prog = document.getElementById('dcl-pres-prog');
        if (prog) {
            prog.style.transition = 'none'; prog.style.width = '0%';
            void prog.offsetWidth;
            if (_presPlaying) { prog.style.transition = 'width ' + (_presInterval / 1000) + 's linear'; prog.style.width = '100%'; }
        }
    }

    // ── Modo 1: Slide elemento a elemento ─────────────────────────
    function dclPresStartSlide() {
        var cards = document.querySelectorAll('#dcl-content .dcl-section.dcl-card:not(.dcl-sec-pooled)');
        if (!cards.length) return;

        var ov = document.createElement('div');
        ov.id = 'dcl-pres-overlay';
        ov.className = 'dcl-pres-overlay';
        ov.innerHTML =
            '<div class="dcl-pres-hd">' +
            '<span class="dcl-pres-logo"><i class="mdi mdi-play-circle-outline"></i></span>' +
            '<span class="dcl-pres-title" id="dcl-pres-title"></span>' +
            '<div class="dcl-pres-acts">' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresPrev()" data-tip="Anterior (←)"><i class="mdi mdi-chevron-left"></i></button>' +
            '<button type="button" class="dcl-pres-btn" id="dcl-pres-playbtn" onclick="dclPresTogglePlay()" data-tip="Pausar/Reanudar (P)"><i class="mdi mdi-pause"></i></button>' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresNext()" data-tip="Siguiente (→)"><i class="mdi mdi-chevron-right"></i></button>' +
            '<span class="dcl-pres-counter" id="dcl-pres-counter"></span>' +
            '<input type="range" id="dcl-pres-speed" min="3" max="20" value="6" ' +
            'data-tip="Velocidad (s)" oninput="dclPresSetSpeed(this.value)" ' +
            'style="width:70px;accent-color:#56F5F8;cursor:pointer" />' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresHelp()" data-tip="Ayuda"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-exit" onclick="dclExitPresentation()" data-tip="Salir (Esc)"><i class="mdi mdi-close-circle-outline"></i></button>' +
            '</div>' +
            '</div>' +
            '<div class="dcl-pres-stage" id="dcl-pres-stage"></div>' +
            '<div class="dcl-pres-dots" id="dcl-pres-dots"></div>' +
            '<div class="dcl-pres-progress-bar" id="dcl-pres-prog"></div>';

        document.body.appendChild(ov);
        document.body.classList.add('dcl-pres-mode');
        if (ov.requestFullscreen) ov.requestFullscreen().catch(function () { });
        else if (ov.webkitRequestFullscreen) ov.webkitRequestFullscreen();

        _presIdx = 0; _presPlaying = true;
        dclPresShow(0);
        dclPresStartTimer();
        dclPresInitAutoHide(ov);
        document.addEventListener('keydown', dclPresKeyHandler);
    }

    // ── Auto-hide del header al dejar el mouse quieto ────────────────────
    var _presIdleTimer = null;
    function dclPresInitAutoHide(ov) {
        if (!ov) return;
        function showHd() {
            ov.classList.remove('dcl-pres-idle');
            if (_presIdleTimer) clearTimeout(_presIdleTimer);
            _presIdleTimer = setTimeout(function () { ov.classList.add('dcl-pres-idle'); }, 2800);
        }
        ov.addEventListener('mousemove', showHd);
        ov.addEventListener('mousedown', showHd);
        ov.addEventListener('touchstart', showHd);
        showHd();
    }

    // ── Panel de ayuda (atajos + guía), alineado al diseño del dashboard ──
    function dclPresHelp() {
        if (document.getElementById('dcl-pres-help')) {
            var ex = document.getElementById('dcl-pres-help');
            if (ex.parentNode) ex.parentNode.removeChild(ex);
            return;
        }
        var isFull = !!document.querySelector('.dcl-pres-overlay--full');
        var navTxt = isFull
            ? '<li><b>↑ / ↓</b> &nbsp;Desplazar el dashboard</li>' +
            '<li><b>Espacio / P</b> &nbsp;Auto-scroll on/off</li>'
            : '<li><b>← / →</b> &nbsp;Slide anterior / siguiente</li>' +
            '<li><b>Espacio</b> &nbsp;Siguiente slide</li>' +
            '<li><b>P</b> &nbsp;Pausar / reanudar</li>';
        var h = document.createElement('div');
        h.id = 'dcl-pres-help';
        h.className = 'dcl-pres-help';
        h.innerHTML =
            '<div class="dcl-pres-help-box">' +
            '<div class="dcl-pres-help-hd"><i class="mdi mdi-help-circle-outline"></i>&nbsp;Ayuda — Modo presentación' +
            '<button type="button" class="dcl-pres-help-close" onclick="dclPresHelp()"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-pres-help-body">' +
            '<p class="dcl-pres-help-sub">Atajos de teclado</p>' +
            '<ul class="dcl-pres-help-list">' + navTxt +
            '<li><b>Esc</b> &nbsp;Salir de la presentación</li>' +
            '</ul>' +
            '<p class="dcl-pres-help-sub">Material de apoyo</p>' +
            '<p class="dcl-pres-help-txt">El dashboard refleja tu layout guardado. Cierra la presentación ' +
            'para personalizarlo desde <b>Armar Dashboard</b> o gestionar tus vistas en <b>Mis Layouts</b>.</p>' +
            '</div>' +
            '</div>';
        h.addEventListener('click', function (e) { if (e.target === h) dclPresHelp(); });
        var ov = document.getElementById('dcl-pres-overlay');
        (ov || document.body).appendChild(h);
        requestAnimationFrame(function () { h.classList.add('dcl-pres-help--open'); });
    }

    // ── Modo 2: TODO el layout en fullscreen, IDÉNTICO al principal ─────────
    // Clona el #dcl-content completo (con sus filas v2 ya aplicadas) y lo muestra
    // a pantalla completa con scroll. No reconstruye ni pagina → se ve tal cual.
    function dclPresStartLayout() {
        var content = document.getElementById('dcl-content');
        if (!content) return;

        var ov = document.createElement('div');
        ov.id = 'dcl-pres-overlay';
        ov.className = 'dcl-pres-overlay dcl-pres-overlay--full';
        ov.innerHTML =
            '<div class="dcl-pres-hd">' +
            '<span class="dcl-pres-logo"><i class="mdi mdi-presentation-play"></i></span>' +
            '<span class="dcl-pres-title" id="dcl-pres-title">DASHBOARD</span>' +
            '<div class="dcl-pres-acts">' +
            // Subir/Bajar y "Desplazamiento" solo tienen sentido cuando el tablero
            // NO entra en pantalla (más de 3 filas). dclPresMarcarScroll los muestra.
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll" onclick="dclPresFullScroll(-1)" data-tip="Subir"><i class="mdi mdi-chevron-up"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll dcl-pres-btn--txt" id="dcl-pres-desplbtn" onclick="dclPresToggleDesplazamiento()" data-tip="Desplazamiento automático del tablero">' +
            '<i class="mdi mdi-play"></i><span>Desplazamiento</span></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll" onclick="dclPresFullScroll(1)" data-tip="Bajar"><i class="mdi mdi-chevron-down"></i></button>' +
            // En modo ajustado, el play recorre el contenido DENTRO de cada widget.
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-fit" id="dcl-pres-playbtn" onclick="dclPresToggleAutoScroll()" data-tip="Recorrer el contenido de los widgets"><i class="mdi mdi-play"></i></button>' +
            // Selección de qué dashboards rotar (General / instalaciones / zonas)
            '<button type="button" class="dcl-pres-btn dcl-pres-btn--txt" onclick="dclPresAbrirSelector()" data-tip="Elegir qué dashboards mostrar">' +
            '<i class="mdi mdi-view-grid-plus-outline"></i><span id="dcl-pres-dashlbl">Dashboards</span></button>' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresHelp()" data-tip="Ayuda"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-exit" onclick="dclExitPresentation()" data-tip="Salir (Esc)"><i class="mdi mdi-close-circle-outline"></i></button>' +
            '</div>' +
            // Cuenta regresiva visual hasta el próximo dashboard de la rotación.
            // Solo se hace visible cuando hay más de un tablero seleccionado.
            '<div class="dcl-pres-dashprog" id="dcl-pres-dashprog"><span></span></div>' +
            '</div>' +
            '<div class="dcl-pres-fullstage" id="dcl-pres-stage"></div>';

        document.body.appendChild(ov);
        document.body.classList.add('dcl-pres-mode');
        if (ov.requestFullscreen) ov.requestFullscreen().catch(function () { });
        else if (ov.webkitRequestFullscreen) ov.webkitRequestFullscreen();

        // Clonar TODO el contenido del dashboard tal cual está renderizado
        var stage = ov.querySelector('#dcl-pres-stage');
        var clone = content.cloneNode(true);
        clone.removeAttribute('id');
        clone.classList.add('dcl-pres-clone');
        // Desactivar interacción/edición en el clon
        dclPresCleanClone(clone);
        var drags = clone.querySelectorAll('[draggable]');
        for (var i = 0; i < drags.length; i++) drags[i].removeAttribute('draggable');
        stage.appendChild(clone);

        // Los botones de +/- altura se quitaron: con el ajuste a pantalla el alto
        // lo reparte el layout (flex), así que no hacían nada y solo ensuciaban
        // cada widget en modo presentación.

        // Con pocas filas el tablero se ajusta a la pantalla; con muchas,
        // repartir el alto las dejaría ilegibles y conviene permitir scroll.
        dclPresMarcarScroll(stage, clone);

        _presPlaying = false;
        dclPresInitAutoHide(ov);
        document.addEventListener('keydown', dclPresKeyHandler);
    }

    // Ajusta el nivel de altura de un widget en presentación (0=auto..3=máx)
    function dclPresAdjustHeight(card, dir) {
        var cur = parseInt(card.getAttribute('data-pres-h') || '0', 10);
        var next = Math.max(0, Math.min(3, cur + dir));
        if (next > 0) card.setAttribute('data-pres-h', next);
        else card.removeAttribute('data-pres-h');
    }

    // Scroll manual del modo full
    function dclPresFullScroll(dir) {
        var stage = document.getElementById('dcl-pres-stage');
        if (!stage) return;
        stage.scrollBy({ top: dir * Math.round(stage.clientHeight * 0.85), behavior: 'smooth' });
    }
    // Auto-scroll lento del modo full (loop infinito: al final, reinicia arriba)
    var _presAutoScroll = null;
    var _presRewinding = false;   // true mientras vuelve al inicio (evita re-disparos)
    // soloEscenario=true → viene del botón "Desplazamiento" (modo con scroll):
    // recorre el TABLERO. Sin ese flag viene del play del modo ajustado, que
    // recorre el contenido DENTRO de cada widget y no toca el escenario.
    function dclPresToggleAutoScroll(soloEscenario) {
        var btn = document.getElementById('dcl-pres-playbtn');
        var icon = btn ? btn.querySelector('i') : null;
        var stage = document.getElementById('dcl-pres-stage');

        if (!soloEscenario) {
            // Modo ajustado: alterna el recorrido interno, en bucle continuo.
            if (_presBodyRaf) {
                dclPresPararAutoBody();
                if (icon) icon.className = 'mdi mdi-play';
            } else {
                dclPresAutoScrollBody(true);
                if (icon) icon.className = 'mdi mdi-pause';
            }
            return;
        }

        if (_presAutoScroll) {
            clearInterval(_presAutoScroll); _presAutoScroll = null;
            _presRewinding = false;
            if (icon) icon.className = 'mdi mdi-play';
            return;
        }
        if (!stage) return;
        _presRewinding = false;
        var pausaFin = 0;   // pausa breve al llegar al final antes de reiniciar
        _presAutoScroll = setInterval(function () {
            var st = document.getElementById('dcl-pres-stage');
            if (!st) { clearInterval(_presAutoScroll); _presAutoScroll = null; return; }
            // Si el contenido cabe completo, no hay scroll → no hacer nada
            if (st.scrollHeight <= st.clientHeight + 4) return;

            if (_presRewinding) {
                // Esperando a que termine el rewind al tope (scrollTop ~ 0)
                if (st.scrollTop <= 2) { _presRewinding = false; pausaFin = 0; }
                return;
            }
            var atBottom = (st.scrollTop + st.clientHeight) >= (st.scrollHeight - 2);
            if (atBottom) {
                // Pausa ~1.2s en el final, luego salto instantáneo al inicio
                pausaFin += 24;
                if (pausaFin >= 1200) {
                    _presRewinding = true;
                    st.scrollTo({ top: 0, behavior: 'auto' }); // instantáneo (no smooth → sin re-disparos)
                }
            } else {
                pausaFin = 0;
                st.scrollTop += 1;   // avance constante (sin smooth para fluidez del loop)
            }
        }, 24);
    }

    // ── Teclado ────────────────────────────────────────────────────
    function dclPresKeyHandler(e) {
        var isFull = !!document.querySelector('.dcl-pres-overlay--full');
        if (e.key === 'Escape') { dclExitPresentation(); return; }
        if (isFull) {
            // Modo "todo el layout": flechas = scroll, espacio/P = auto-scroll
            if (e.key === 'ArrowDown' || e.key === 'ArrowRight') { e.preventDefault(); dclPresFullScroll(1); }
            else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') { e.preventDefault(); dclPresFullScroll(-1); }
            // Espacio/P alterna lo que corresponda al modo: desplazamiento del
            // tablero si hay scroll, recorrido interno si el tablero ya entra.
            else if (e.key === ' ' || e.key === 'p' || e.key === 'P') {
                e.preventDefault();
                if (_presModoScroll) dclPresToggleDesplazamiento();
                else                 dclPresToggleAutoScroll();
            }
            return;
        }
        if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); dclPresNext(); }
        if (e.key === 'ArrowLeft') { e.preventDefault(); dclPresPrev(); }
        if (e.key === 'p' || e.key === 'P') dclPresTogglePlay();
    }

    // ── Slide show — funciones de navegación ──────────────────────
    function dclPresShow(idx) {
        var cards = document.querySelectorAll('#dcl-content .dcl-section.dcl-card:not(.dcl-sec-pooled)');
        if (!cards.length) return;
        _presIdx = ((idx % cards.length) + cards.length) % cards.length;

        var stage = document.getElementById('dcl-pres-stage');
        var title = document.getElementById('dcl-pres-title');
        var counter = document.getElementById('dcl-pres-counter');
        if (!stage) return;

        var clone = cards[_presIdx].cloneNode(true);
        clone.style.cssText = '';
        clone.classList.add('dcl-pres-card');
        dclPresCleanClone(clone);
        var rsz = clone.querySelector('.dcl-rsz');
        if (rsz) rsz.removeAttribute('onmousedown');

        stage.innerHTML = '';
        stage.appendChild(clone);
        stage.classList.remove('dcl-pres-stage--anim');
        void stage.offsetWidth;
        stage.classList.add('dcl-pres-stage--anim');

        var hd = cards[_presIdx].querySelector('.dcl-card-title');
        var hdIcon = cards[_presIdx].querySelector('.dcl-card-hd i');
        if (title) {
            title.innerHTML = (hdIcon ? '<i class="' + hdIcon.className + '"></i> ' : '') +
                (hd ? hd.textContent.trim() : '');
        }
        if (counter) counter.textContent = (_presIdx + 1) + ' / ' + cards.length;

        var dots = document.getElementById('dcl-pres-dots');
        if (dots) {
            dots.innerHTML = '';
            for (var i = 0; i < cards.length; i++) {
                var d = document.createElement('button');
                d.type = 'button';
                d.className = 'dcl-pres-dot' + (i === _presIdx ? ' dcl-pres-dot--on' : '');
                (function (n) { d.onclick = function () { dclPresShow(n); dclPresResetTimer(); }; })(i);
                dots.appendChild(d);
            }
        }

        var prog = document.getElementById('dcl-pres-prog');
        if (prog) {
            prog.style.transition = 'none';
            prog.style.width = '0%';
            void prog.offsetWidth;
            if (_presPlaying) {
                prog.style.transition = 'width ' + (_presInterval / 1000) + 's linear';
                prog.style.width = '100%';
            }
        }

        // Nueva tarjeta en pantalla → reiniciar el recorrido interno.
        dclPresAutoScrollBody();
    }

    function dclPresNext() {
        if (_presSlides.length) { dclPresSlideGo(_presSlideIdx + 1); dclPresResetTimer(); }
        else { dclPresShow(_presIdx + 1); dclPresResetTimer(); }
    }
    function dclPresPrev() {
        if (_presSlides.length) { dclPresSlideGo(_presSlideIdx - 1); dclPresResetTimer(); }
        else { dclPresShow(_presIdx - 1); dclPresResetTimer(); }
    }

    function dclPresSetSpeed(v) {
        _presInterval = parseInt(v, 10) * 1000;
        if (_presPlaying) dclPresResetTimer();
        // Si hay rotación de dashboards activa, su turno también cambia de
        // duración; si no se recrea el timer, la barra mostraría otro tiempo.
        if (_presDashTimer) {
            clearInterval(_presDashTimer);
            _presDashMs = Math.max(8000, _presInterval);
            _presDashTimer = setInterval(function () {
                dclPresCargarDash(_presDashIdx + 1);
            }, _presDashMs);
            dclPresProgresoDash(_presDashMs);
        }
    }
    // ── Recorrido interno de los widgets en presentación ──────────────────
    // La pantalla nunca scrollea: el widget se ajusta al alto disponible. Si su
    // contenido no entra, se recorre SOLO dentro de la tarjeta durante el tiempo
    // que dura la diapositiva, para que igual se alcance a ver completo.
    var _presBodyRaf = null;

    function dclPresPararAutoBody() {
        if (_presBodyRaf) { cancelAnimationFrame(_presBodyRaf); _presBodyRaf = null; }
    }

    // ══════════════════════════════════════════════════════════════════
    // ROTACIÓN ENTRE DASHBOARDS EN PRESENTACIÓN
    // Permite mostrar varios tableros (General, una instalación, una zona)
    // turnándose en pantalla. Cada uno se pide al MISMO WebService del
    // auto-refresh, así que no hay una segunda fuente de verdad del HTML.
    // ══════════════════════════════════════════════════════════════════
    var _presDash      = [];     // [{nivel, cli, cin, ciz, nombre}]
    var _presDashIdx   = 0;
    var _presDashTimer = null;
    var _presDashMs    = 0;      // duración real del turno; la usa la barra de progreso

    function dclPresPararRotacion() {
        if (_presDashTimer) { clearInterval(_presDashTimer); _presDashTimer = null; }
        dclPresProgresoDash(0);
    }

    // Barra de cuenta regresiva del turno. Con ms=0 se oculta (no hay rotación).
    // La animación es puramente CSS: se fuerza un reflow entre el reset y el
    // arranque, si no el navegador colapsa ambos cambios de width en uno solo y
    // la barra nunca se ve avanzar.
    function dclPresProgresoDash(ms) {
        var barra = document.getElementById('dcl-pres-dashprog');
        if (!barra) return;
        var relleno = barra.querySelector('span');
        if (!relleno) return;

        relleno.style.transition = 'none';
        relleno.style.width      = '0%';

        if (!ms) { barra.classList.remove('dcl-pres-dashprog--on'); return; }

        barra.classList.add('dcl-pres-dashprog--on');
        void relleno.offsetWidth;
        relleno.style.transition = 'width ' + (ms / 1000) + 's linear';
        relleno.style.width      = '100%';
    }

    // Opciones de un combo Telerik como [{v,t}], omitiendo el "Todos/Todas".
    function dclPresItemsCombo(clientId) {
        var out = [], cbo = dclCboFind(clientId);
        if (!cbo) return out;
        try {
            var items = cbo.get_items();
            for (var i = 0; i < items.get_count(); i++) {
                var it = items.getItem(i);
                var v = parseInt(it.get_value(), 10) || 0;
                if (v > 0) out.push({ v: v, t: it.get_text() });
            }
        } catch (e) { }
        return out;
    }

    // Selector por CATEGORÍA (General / Por Instalación / Por Zona). Listar cada
    // instalación y cada zona sueltas era confuso: no se entendía que eran
    // niveles distintos del mismo tablero. Ahora se elige el nivel y, cuando
    // hace falta, CUÁL mostrar en un desplegable al lado.
    function dclPresAbrirSelector() {
        var previo = document.getElementById('dcl-pres-dashsel');
        if (previo) { previo.parentNode.removeChild(previo); return; }

        var insts = dclPresItemsCombo(window._dclCboInstalacion);
        var zonas = dclPresItemsCombo(window._dclCboZona);
        var cinAct = parseInt(dclHf('hfInstalacion'), 10) || 0;
        var cizAct = parseInt(dclHf('hfZona'), 10) || 0;

        // Estado actual de la selección, para reabrir el panel como quedó.
        function elegido(niv) {
            for (var i = 0; i < _presDash.length; i++) if (_presDash[i].nivel === niv) return _presDash[i];
            return null;
        }
        var selGen = elegido('general'), selIns = elegido('instalacion'), selZon = elegido('zona');

        function opciones(lista, actual) {
            var h = '';
            for (var i = 0; i < lista.length; i++)
                h += '<option value="' + lista[i].v + '"' + (lista[i].v === actual ? ' selected' : '') + '>' +
                     dclEsc(lista[i].t) + '</option>';
            return h;
        }

        var cinSel = selIns ? selIns.cin : (cinAct || (insts.length ? insts[0].v : 0));
        var cizSel = selZon ? selZon.ciz : (cizAct || (zonas.length ? zonas[0].v : 0));

        var clientes = dclPresItemsCombo(window._dclCboCliente);
        // Reabrir el panel debe respetar el cliente ya elegido aquí dentro.
        var cliPrev  = (selGen && selGen.cli) || (selIns && selIns.cli) || (selZon && selZon.cli) || 0;
        var cliSel   = cliPrev || parseInt(dclHf('hfCliente'), 10) || (clientes.length ? clientes[0].v : 0);
        // Con un solo cliente el combo del filtro está oculto: se muestra igual
        // como opción única para que la cascada quede explícita.
        if (!clientes.length) clientes = [{ v: cliSel, t: 'Cliente actual' }];

        var panel = document.createElement('div');
        panel.id = 'dcl-pres-dashsel';
        panel.className = 'dcl-pres-dashsel';
        panel.innerHTML =
            '<div class="dcl-pres-dashsel-box">' +
            '<div class="dcl-pres-dashsel-hd">' +
            '<span><i class="mdi mdi-view-grid-plus-outline"></i>&nbsp;Dashboards a mostrar</span>' +
            '<button type="button" data-act="close"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<p class="dcl-pres-dashsel-sub">Elige qué niveles mostrar. Si marcas más de uno, ' +
            'se van turnando en pantalla; con uno solo, queda fijo.</p>' +
            '<div class="dcl-pres-dashsel-list">' +

            // Cliente: encabeza la cascada. Al cambiarlo se recargan las
            // instalaciones y, con ellas, las zonas.
            '<div class="dcl-pres-dash-cli">' +
            '<label for="dcl-pd-cli">Cliente</label>' +
            '<select id="dcl-pd-cli" class="dcl-pres-dash-sel">' + opciones(clientes, cliSel) + '</select>' +
            '</div>' +

            '<div class="dcl-pres-dash-op">' +
            '<input type="checkbox" id="dcl-pd-gen"' + (selGen ? ' checked' : '') + ' />' +
            '<label for="dcl-pd-gen"><b>Dashboard General</b>' +
            '<span>Todas las instalaciones del cliente elegido</span></label>' +
            '</div>' +

            // Instalación y Zona SIEMPRE habilitadas: sus listas las llena la
            // cascada al abrir el panel. Antes dependían de los combos de la
            // barra de filtros y, en nivel General, el de zonas viene vacío →
            // "Dashboard por Zona" quedaba deshabilitado sin poder elegirse.
            '<div class="dcl-pres-dash-op">' +
            '<input type="checkbox" id="dcl-pd-ins"' + (selIns ? ' checked' : '') + ' />' +
            '<label for="dcl-pd-ins"><b>Dashboard por Instalación</b>' +
            '<select id="dcl-pd-ins-sel" class="dcl-pres-dash-sel">' + opciones(insts, cinSel) + '</select>' +
            '</label></div>' +

            '<div class="dcl-pres-dash-op">' +
            '<input type="checkbox" id="dcl-pd-zon"' + (selZon ? ' checked' : '') + ' />' +
            '<label for="dcl-pd-zon"><b>Dashboard por Zona</b>' +
            '<select id="dcl-pd-zon-sel" class="dcl-pres-dash-sel">' + opciones(zonas, cizSel) + '</select>' +
            '<span>Zonas de la instalación elegida arriba</span>' +
            '</label></div>' +

            '</div>' +
            '<div class="dcl-pres-dashsel-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="close">Cancelar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="ok">Aplicar</button>' +
            '</div></div>';

        panel.addEventListener('click', function (e) {
            if (e.target === panel) { panel.parentNode.removeChild(panel); return; }
            var b = e.target;
            while (b && b !== panel && !(b.getAttribute && b.getAttribute('data-act'))) b = b.parentNode;
            var act = (b && b.getAttribute) ? b.getAttribute('data-act') : null;
            if (act === 'close') { panel.parentNode.removeChild(panel); return; }
            if (act !== 'ok') return;

            // El cliente del panel manda sobre el de la barra de filtros: el
            // Dashboard General ES por cliente, así que se muestra el elegido aquí.
            var selC   = panel.querySelector('#dcl-pd-cli');
            var cliPan = selC ? (parseInt(selC.value, 10) || 0) : 0;
            var nomCli = (selC && selC.selectedIndex >= 0) ? selC.options[selC.selectedIndex].text : '';

            var sel = [];
            if (panel.querySelector('#dcl-pd-gen').checked)
                sel.push({
                    nivel: 'general', cli: cliPan, cin: 0, ciz: 0,
                    nombre: nomCli ? ('General · ' + nomCli) : 'Dashboard General'
                });

            var chkI = panel.querySelector('#dcl-pd-ins');
            var selI = panel.querySelector('#dcl-pd-ins-sel');
            if (chkI && chkI.checked && selI && selI.selectedIndex >= 0) {
                sel.push({
                    nivel: 'instalacion', cli: cliPan, cin: parseInt(selI.value, 10) || 0, ciz: 0,
                    nombre: selI.options[selI.selectedIndex].text
                });
            }

            var chkZ = panel.querySelector('#dcl-pd-zon');
            var selZ = panel.querySelector('#dcl-pd-zon-sel');
            if (chkZ && chkZ.checked && selZ && selZ.selectedIndex >= 0) {
                // La zona necesita su instalación: se toma la del desplegable de
                // instalación (que es de donde salió el listado de zonas), esté o
                // no marcado el checkbox de "Dashboard por Instalación".
                sel.push({
                    nivel: 'zona',
                    cli  : cliPan,
                    cin  : (selI ? (parseInt(selI.value, 10) || 0) : 0) || cinAct,
                    ciz  : parseInt(selZ.value, 10) || 0,
                    nombre: 'Zona: ' + selZ.options[selZ.selectedIndex].text
                });
            }

            panel.parentNode.removeChild(panel);
            dclPresAplicarDash(sel);
        });

        var ov = document.getElementById('dcl-pres-overlay') || document.body;
        ov.appendChild(panel);

        // ── Cascada Cliente → Instalación → Zona ──────────────────────────
        // Se piden al servidor con los mismos WebMethods que usan los combos de
        // la barra de filtros, así el selector nunca ofrece algo que no existe.
        var selCli = panel.querySelector('#dcl-pd-cli');
        var selIn  = panel.querySelector('#dcl-pd-ins-sel');
        var selZo  = panel.querySelector('#dcl-pd-zon-sel');

        function llenar(sel, lista, vSel) {
            if (!sel) return;
            var h = '';
            for (var i = 0; i < lista.length; i++)
                h += '<option value="' + lista[i].id + '"' + (lista[i].id === vSel ? ' selected' : '') + '>' +
                     dclEsc(lista[i].nombre) + '</option>';
            sel.innerHTML = h;
            sel.disabled = !lista.length;
        }

        function pedir(url, cuerpo, onOk) {
            if (typeof url === 'undefined') { onOk([]); return; }
            try {
                var xhr = new XMLHttpRequest();
                xhr.open('POST', url, true);
                xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
                xhr.onreadystatechange = function () {
                    if (xhr.readyState !== 4) return;
                    var lista = [];
                    if (xhr.status === 200) {
                        try {
                            var r = JSON.parse(xhr.responseText);
                            lista = (r.d !== undefined ? r.d : r) || [];
                        } catch (e) { lista = []; }
                    }
                    onOk(lista);
                };
                xhr.send(JSON.stringify(cuerpo));
            } catch (e) { onOk([]); }
        }

        function cargarZonas(cin, vSel) {
            pedir(window._dclWsZonasUrl, { instalacion: cin || 0 }, function (l) { llenar(selZo, l, vSel || 0); });
        }

        if (selCli) {
            selCli.addEventListener('change', function () {
                var cli = parseInt(selCli.value, 10) || 0;
                pedir(window._dclWsInstalUrl, { cliente: cli }, function (l) {
                    llenar(selIn, l, l.length ? l[0].id : 0);
                    cargarZonas(l.length ? l[0].id : 0, 0);
                });
            });
        }
        if (selIn) {
            selIn.addEventListener('change', function () {
                cargarZonas(parseInt(selIn.value, 10) || 0, 0);
            });
        }

        // Poblado inicial: las instalaciones del cliente elegido y las zonas de
        // la instalación resultante. Sin esto, "Por Zona" arrancaba vacío cuando
        // se entra a presentación desde el nivel General.
        pedir(window._dclWsInstalUrl, { cliente: cliSel }, function (l) {
            var destino = cinSel;
            var existe = false;
            for (var i = 0; i < l.length; i++) if (l[i].id === destino) existe = true;
            if (!existe && l.length) destino = l[0].id;
            if (l.length) llenar(selIn, l, destino);
            cargarZonas(destino, cizSel);
        });
    }

    function dclPresAplicarDash(sel) {
        dclPresPararRotacion();
        _presDash = sel || [];
        _presDashIdx = 0;

        var lbl = document.getElementById('dcl-pres-dashlbl');
        if (lbl) lbl.textContent = _presDash.length ? ('Dashboards (' + _presDash.length + ')') : 'Dashboards';

        if (!_presDash.length) return;          // sin selección → queda el actual

        // La duración del turno se fija ANTES de la primera carga: dclPresCargarDash
        // arranca la barra de progreso con este valor y, si se calculara después,
        // el primer dashboard quedaría sin cuenta regresiva.
        _presDashMs = _presDash.length > 1 ? Math.max(8000, _presInterval) : 0;

        dclPresCargarDash(0);

        // Con más de uno, se turnan. Con uno solo queda fijo (pero recargado).
        if (_presDashMs) {
            _presDashTimer = setInterval(function () {
                dclPresCargarDash(_presDashIdx + 1);
            }, _presDashMs);
        }
    }

    function dclPresCargarDash(idx) {
        if (!_presDash.length) return;
        _presDashIdx = ((idx % _presDash.length) + _presDash.length) % _presDash.length;
        var d = _presDash[_presDashIdx];

        var stage = document.getElementById('dcl-pres-stage');
        var hfU   = document.getElementById('hfUsuario');
        if (!stage || !hfU || typeof window._dclWsAjaxUrl === 'undefined') return;

        // Título con el dashboard visible y su posición en la rotación, para que
        // en pantalla siempre se sepa QUÉ se está mirando.
        var titulo = document.getElementById('dcl-pres-title');
        if (titulo) {
            var pos = _presDash.length > 1
                ? '<span class="dcl-pres-rot">' + (_presDashIdx + 1) + ' / ' + _presDash.length + '</span>'
                : '';
            // Sin ícono: el encabezado ya trae uno en .dcl-pres-logo y se veía duplicado.
            titulo.innerHTML = dclEsc(d.nombre) + pos;
        }

        // Reinicia la cuenta regresiva junto con el turno, no al llegar la
        // respuesta: así la barra queda alineada con el setInterval.
        dclPresProgresoDash(_presDashMs);

        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', window._dclWsAjaxUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 || xhr.status !== 200) return;
                var html = '';
                try {
                    var r = JSON.parse(xhr.responseText);
                    var dd = r.d !== undefined ? r.d : r;
                    if (dd && dd.ok) html = dd.html;
                } catch (e) { }
                if (!html) return;

                // Se reemplaza el contenido del clon manteniendo su estructura de
                // presentación (clases y ajuste a pantalla).
                var clone = stage.querySelector('.dcl-pres-clone');
                if (!clone) return;
                clone.innerHTML = html;
                dclPresCleanClone(clone);
                dclPresAplicarLayoutClon(clone, d.nivel);
                dclPresMarcarScroll(stage, clone);
                dclPresAutoScrollBody(true);
            };
            xhr.send(JSON.stringify({
                usuario    : parseInt(hfU.value) || 0,
                // Cliente del dashboard elegido en el selector; si no vino, el del filtro.
                cliente    : d.cli || parseInt(dclHf('hfCliente'), 10) || 0,
                instalacion: d.cin || 0,
                zona       : d.ciz || 0,
                desde      : dclHf('hfDesde'),
                hasta      : dclHf('hfHasta'),
                nomIns     : d.nombre,
                meta       : dclGetMeta()
            }));
        } catch (e) { }
    }

    // El HTML del WS viene plano (todas las secciones seguidas). Se aplica el
    // layout guardado de ESE nivel para que la presentación respete las filas
    // que el usuario configuró en cada categoría.
    function dclPresAplicarLayoutClon(clone, nivel) {
        var cfg = {};
        try { cfg = JSON.parse(localStorage.getItem('dcl_cfg_' + window._dclUsuarioId + '_' + nivel)) || {}; } catch (e) { }
        var rows = dclNormalizeRows(cfg.rows);
        if (!rows.length) rows = dclNormalizeRows(dclDefaultCfg(nivel).rows);
        if (!rows.length) return;

        var frag = document.createDocumentFragment();
        for (var r = 0; r < rows.length; r++) {
            var fila = document.createElement('div');
            fila.className = 'dcl-sec-row';
            fila.style.display = 'grid';
            fila.style.gap = '10px';
            fila.style.gridTemplateColumns = 'repeat(' + rows[r].cols + ', 1fr)';

            for (var c = 0; c < rows[r].slots.length; c++) {
                var sec = dclSlotSec(rows[r].slots[c]);
                var span = dclSlotSpan(rows[r].slots[c]);
                var el = sec ? clone.querySelector('.dcl-section[data-section="' + sec + '"]') : null;
                if (!el) { var hueco = document.createElement('div'); fila.appendChild(hueco); continue; }
                if (span > 1) el.style.gridColumn = 'span ' + span;
                fila.appendChild(el);
            }
            frag.appendChild(fila);
        }
        // Lo que no entró en ninguna fila no se muestra (igual que en el dashboard).
        clone.innerHTML = '';
        clone.appendChild(frag);
    }

    // ── Modo de encaje del tablero en presentación ────────────────────────
    // Hasta 3 filas el tablero se ajusta a la pantalla (sin scroll) y el play
    // recorre el contenido dentro de cada widget. Con más filas, repartir el
    // alto las dejaría ilegibles: se habilita el scroll del escenario, las
    // tarjetas usan su alto natural y aparece el botón "Desplazamiento".
    var _presModoScroll = false;
    var _DCL_PRES_MAX_FILAS = 3;

    function dclPresMarcarScroll(stage, clone) {
        if (!stage || !clone) return;

        // Filas reales: los wrappers .dcl-sec-row y las secciones sueltas.
        var filas = 0;
        for (var i = 0; i < clone.children.length; i++) {
            var el = clone.children[i];
            if (!el.classList) continue;
            if (el.classList.contains('dcl-sec-row') || el.classList.contains('dcl-section')) filas++;
        }

        _presModoScroll = filas > _DCL_PRES_MAX_FILAS;
        stage.classList.toggle('dcl-pres-scroll', _presModoScroll);

        var ov = document.getElementById('dcl-pres-overlay');
        if (ov) ov.classList.toggle('dcl-pres-modo-scroll', _presModoScroll);
    }

    // Botón "Desplazamiento": recorre el TABLERO completo (solo en modo scroll).
    function dclPresToggleDesplazamiento() {
        var btn  = document.getElementById('dcl-pres-desplbtn');
        var icon = btn ? btn.querySelector('i') : null;

        if (_presAutoScroll) {
            clearInterval(_presAutoScroll); _presAutoScroll = null;
            _presRewinding = false;
            if (icon) icon.className = 'mdi mdi-play';
            return;
        }
        if (icon) icon.className = 'mdi mdi-pause';
        dclPresToggleAutoScroll(true);
    }

    function dclPresAutoScrollBody(forzar) {
        dclPresPararAutoBody();
        if (!_presPlaying && !forzar) return;

        var ov = document.getElementById('dcl-pres-overlay');
        if (!ov) return;

        // Cubre los dos modos: tarjeta a tarjeta (.dcl-pres-card) y tablero
        // completo (.dcl-pres-clone), donde el escenario ya no scrollea.
        var todos = ov.querySelectorAll('.dcl-pres-card .dcl-card-body, .dcl-pres-clone .dcl-card-body');
        var cuerpos = [];
        for (var i = 0; i < todos.length; i++) {
            todos[i].scrollTop = 0;
            if (todos[i].scrollHeight > todos[i].clientHeight + 4) cuerpos.push(todos[i]);
        }
        if (!cuerpos.length) return;

        // Recorrido con requestAnimationFrame (no setInterval): sigue el refresco
        // real de la pantalla, así el movimiento es continuo y no a saltos.
        // Ciclo: pausa arriba → baja → pausa abajo → vuelve → repite.
        var PAUSA = 1100;                                   // quieto en cada extremo
        var VIAJE = Math.max(2600, _presInterval * 0.75);   // duración de cada tramo
        var CICLO = (PAUSA + VIAJE) * 2;
        var t0    = 0;

        // Suavizado en ambos extremos: arranca y frena de a poco.
        function suavizar(x) { return 0.5 - Math.cos(Math.PI * x) / 2; }

        function frame(ts) {
            if (!_presBodyRaf) return;                      // detenido
            if (!t0) t0 = ts;

            var t = (ts - t0) % CICLO;
            var frac;
            if (t < PAUSA)                       frac = 0;                                   // quieto arriba
            else if (t < PAUSA + VIAJE)          frac = suavizar((t - PAUSA) / VIAJE);        // bajando
            else if (t < PAUSA * 2 + VIAJE)      frac = 1;                                   // quieto abajo
            else                                 frac = 1 - suavizar((t - PAUSA * 2 - VIAJE) / VIAJE); // subiendo

            for (var j = 0; j < cuerpos.length; j++) {
                var el = cuerpos[j];
                var max = el.scrollHeight - el.clientHeight;
                if (max > 0) el.scrollTop = max * frac;
            }
            _presBodyRaf = requestAnimationFrame(frame);
        }
        _presBodyRaf = requestAnimationFrame(frame);
    }

    function dclPresStartTimer() {
        if (_presTimer) clearInterval(_presTimer);
        _presTimer = setInterval(function () {
            if (_presSlides.length) dclPresSlideGo(_presSlideIdx + 1);
            else dclPresShow(_presIdx + 1);
        }, _presInterval);
        dclPresAutoScrollBody();
    }
    function dclPresResetTimer() {
        if (_presTimer) { clearInterval(_presTimer); _presTimer = null; }
        if (_presPlaying) dclPresStartTimer();
    }
    function dclPresTogglePlay() {
        _presPlaying = !_presPlaying;
        var btn = document.getElementById('dcl-pres-playbtn');
        var icon = btn ? btn.querySelector('i') : null;
        var prog = document.getElementById('dcl-pres-prog');
        if (icon) icon.className = _presPlaying ? 'mdi mdi-pause' : 'mdi mdi-play';
        if (_presPlaying) {
            dclPresStartTimer();
            if (prog) { prog.style.transition = 'width ' + (_presInterval / 1000) + 's linear'; prog.style.width = '100%'; }
        } else {
            if (_presTimer) { clearInterval(_presTimer); _presTimer = null; }
            // Al pausar, el contenido también se queda quieto donde está.
            dclPresPararAutoBody();
            if (prog) { prog.style.transition = 'none'; prog.style.width = prog.getBoundingClientRect().width + 'px'; }
        }
    }

    // ── Salir (ambos modos) ────────────────────────────────────────
    function dclExitPresentation() {
        if (_presTimer) { clearInterval(_presTimer); _presTimer = null; }
        if (_presAutoScroll) { clearInterval(_presAutoScroll); _presAutoScroll = null; }
        dclPresPararAutoBody();
        dclPresPararRotacion();
        _presDash = []; _presDashIdx = 0; _presDashMs = 0;
        _presRewinding = false;
        if (_presIdleTimer) { clearTimeout(_presIdleTimer); _presIdleTimer = null; }
        if (_presLayoutScaleFn) { window.removeEventListener('resize', _presLayoutScaleFn); _presLayoutScaleFn = null; }
        var helpEl = document.getElementById('dcl-pres-help');
        if (helpEl && helpEl.parentNode) helpEl.parentNode.removeChild(helpEl);
        document.removeEventListener('keydown', dclPresKeyHandler);
        // Salir de fullscreen solo si realmente estamos en fullscreen. exitFullscreen
        // devuelve una promesa que puede rechazarse ("Document not active") → capturar.
        try {
            var fsEl = document.fullscreenElement || document.webkitFullscreenElement;
            if (fsEl) {
                if (document.exitFullscreen) {
                    var p = document.exitFullscreen();
                    if (p && p.catch) p.catch(function () { });
                } else if (document.webkitExitFullscreen) {
                    document.webkitExitFullscreen();
                }
            }
        } catch (e) { }
        var ov = document.getElementById('dcl-pres-overlay');
        if (ov && ov.parentNode) ov.parentNode.removeChild(ov);
        document.body.classList.remove('dcl-pres-mode');
        _presSlides = [];
        _presSlideIdx = 0;
    }

    // ══════════════════════════════════════════════════════════════
