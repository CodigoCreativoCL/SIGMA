    // BUILDER WIZARD — paso 1: selección de layout
    // ══════════════════════════════════════════════════════════════
    function dclEnterBuilderWizard() { dclEnterBuilderMode(); }
    function dclBldWizGo(cols) { dclEnterBuilderMode(); }
    function dclBldWizClose() {
        var wiz = document.getElementById('dcl-bld-wizard');
        if (wiz) { wiz.classList.remove('dcl-bld-wizard--open'); setTimeout(function () { if (wiz.parentNode) wiz.parentNode.removeChild(wiz); }, 260); }
    }
     
    // ══════════════════════════════════════════════════════════════
    // CARD CONFIG PANEL — panel derecho de configuración de widget
    // ══════════════════════════════════════════════════════════════
    var _dclCfgCard = null;

    function dclOpenCardCfg(btn) {
        var sec = btn;
        while (sec && !sec.classList.contains('dcl-card')) sec = sec.parentNode;
        if (!sec) return;
        _dclCfgCard = sec;

        var existing = document.getElementById('dcl-card-cfg-panel');
        if (existing && existing.parentNode) existing.parentNode.removeChild(existing);

        var titleEl = sec.querySelector('.dcl-card-title');
        var curTitle = titleEl ? titleEl.textContent.trim() : '';
        var hd = sec.querySelector('.dcl-card-hd');
        var hdHidden = hd ? hd.classList.contains('dcl-card-hd--hidden') : false;

        var panel = document.createElement('div');
        panel.id = 'dcl-card-cfg-panel';
        panel.className = 'dcl-card-cfg-panel';
        panel.innerHTML =
            '<div class="dcl-cfg-hd">' +
            '<span><i class="mdi mdi-cog-outline"></i>&nbsp;Configurar Sección</span>' +
            '<button type="button" class="dcl-cfg-close" onclick="dclCloseCardCfg()" data-tip="Cerrar&#10;Cierra este panel">&#10005;</button>' +
            '</div>' +
            '<div class="dcl-cfg-body">' +
            '<label class="dcl-cfg-lbl">Título</label>' +
            '<input type="text" id="dcl-cfg-title-input" class="dcl-cfg-input" value="' + dclHtmlEsc(curTitle) + '" />' +
            '<button type="button" class="dcl-cfg-apply-btn" onclick="dclCardCfgApplyTitle()"><i class="mdi mdi-check"></i> Aplicar título</button>' +

            '<div class="dcl-cfg-sep"></div>' +

            // NOTA: el control de "Ancho" se removió. El ancho lo determina la
            // columna de la fila donde se ubica la sección (builder). Cambiar la
            // distribución se hace en "Personalizar" → estructura por fila.

            '<label class="dcl-cfg-lbl">Encabezado</label>' +
            '<label class="dcl-cfg-switch">' +
            '<input type="checkbox" id="dcl-cfg-hd-chk"' + (hdHidden ? '' : ' checked') + ' onchange="dclCardCfgToggleHd(this)" />' +
            '<span class="dcl-cfg-slider"></span>' +
            '<span class="dcl-cfg-switch-lbl">Mostrar encabezado</span>' +
            '</label>' +

            '<div class="dcl-cfg-sep"></div>' +

            '<label class="dcl-cfg-lbl">Altura del widget</label>' +
            '<div class="dcl-cfg-h-grp">' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="0" onclick="dclCardCfgSetHeight(0)" data-tip="Automática (según contenido)">Auto</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="1" onclick="dclCardCfgSetHeight(1)" data-tip="Pequeña">S</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="2" onclick="dclCardCfgSetHeight(2)" data-tip="Mediana">M</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="3" onclick="dclCardCfgSetHeight(3)" data-tip="Grande">L</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="4" onclick="dclCardCfgSetHeight(4)" data-tip="Extra grande">XL</button>' +
            '</div>' +
            '<button type="button" class="dcl-cfg-reset-h-btn" onclick="dclCardCfgResetHeight()">' +
            '<i class="mdi mdi-restore"></i> Restablecer altura libre' +
            '</button>' +
            dclCfgExtraMeta(sec) +
            '</div>';

        document.body.appendChild(panel);
        // Resaltar el nivel de altura actual del widget
        var curH = sec.getAttribute('data-height');
        dclCardCfgSyncHBtns(curH !== null ? curH : -1);
        requestAnimationFrame(function () { panel.classList.add('dcl-card-cfg-panel--open'); });
    }
    function dclHtmlEsc(s) { return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

    // El velocímetro suma al panel de configuración un campo propio: la meta
    // (el "corte") de cumplimiento. Solo aparece en ese widget.
    function dclCfgExtraMeta(sec) {
        var secWrap = sec.parentNode;
        var secId = secWrap && secWrap.getAttribute ? secWrap.getAttribute('data-section') : '';
        if (secId !== 'dcl-gauge') return '';

        var meta = dclGetMeta();
        return '<div class="dcl-cfg-sep"></div>' +
            '<label class="dcl-cfg-lbl">Meta de cumplimiento</label>' +
            '<div class="dcl-cfg-meta-row">' +
            '<input type="number" min="1" max="100" step="1" id="dcl-cfg-meta-input" ' +
            'class="dcl-cfg-meta-input" value="' + meta + '" />' +
            '<span class="dcl-bar-sub">%</span>' +
            '<button type="button" class="dcl-cfg-apply-btn" onclick="dclCardCfgApplyMeta()">' +
            '<i class="mdi mdi-check"></i> Aplicar</button>' +
            '</div>';
    }

    function dclGetMeta() {
        var cfg = dclGetCfg();
        var m = parseFloat(cfg.metaCumplimiento);
        return (m > 0 && m <= 100) ? m : 90;
    }

    // ── Parametrización de gráficos (dropdown) ────────────────────────────
    // Mismo patrón que el panel de actualización automática: un botón de la
    // barra abre un dropdown anclado. Es el mismo valor que edita el engranaje
    // de cada card; vive en el cfg del usuario para que velocímetro y barras
    // usen SIEMPRE el mismo umbral.
    function dclSetMeta(v) {
        var cfg = dclGetCfg();
        cfg.metaCumplimiento = v;
        dclSaveCfg(cfg);
        dclMetaInputSync();
        dclAutoRefreshAjax(true);   // el servidor recalcula con la meta nueva
    }
    // Refleja la meta guardada en el botón (tooltip + chip con el valor).
    function dclMetaInputSync() {
        var btn = document.getElementById('dcl-meta-btn');
        if (btn) btn.setAttribute('data-tip', 'Meta de cumplimiento\nActualmente ' + dclGetMeta() + '%. Define el objetivo del velocímetro y las barras');
    }

    function dclToggleMetaPanel(btn) {
        if (document.getElementById('dcl-meta-panel')) { dclCloseMetaPanel(); return; }
        dclOpenMetaPanel(btn);
    }
    function dclCloseMetaPanel() {
        var panel = document.getElementById('dcl-meta-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 260);
    }
    function dclOpenMetaPanel(anchorBtn) {
        dclCloseMetaPanel();
        var btn = anchorBtn || document.getElementById('dcl-meta-btn');
        var actual = dclGetMeta();

        var panel = document.createElement('div');
        panel.id = 'dcl-meta-panel';
        panel.className = 'dcl-layouts-panel';
        panel.onclick = function (e) { if (e.target === panel) dclCloseMetaPanel(); };

        var presets = [80, 85, 90, 95, 100];
        var optsHtml = '';
        for (var i = 0; i < presets.length; i++) {
            var activo = (presets[i] === actual);
            optsHtml += '<button type="button" class="dcl-refresh-opt' + (activo ? ' dcl-refresh-opt--active' : '') +
                '" data-meta="' + presets[i] + '">' +
                '<i class="mdi mdi-' + (activo ? 'check-circle-outline' : 'circle-outline') + '"></i>' +
                '<span>' + presets[i] + '%</span></button>';
        }
        var esPreset = presets.indexOf(actual) >= 0;

        panel.innerHTML =
            '<div class="dcl-layouts-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-tune"></i>&nbsp;Parametrización de gráficos</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="close" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-meta-panel-lbl">Cumplimiento Global de Checklists</div>' +
            '<div class="dcl-layouts-list">' + optsHtml + '</div>' +
            '<div class="dcl-refresh-custom-wrap">' +
            '<div class="dcl-layouts-ft dcl-refresh-custom">' +
            '<input type="number" min="1" max="100" step="1" class="dcl-refresh-custom-input" id="dcl-meta-custom-val" ' +
            'placeholder="Personalizado" value="' + (esPreset ? '' : actual) + '" />' +
            '<span class="dcl-refresh-custom-unit">%</span>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="custom" data-tip="Aplicar&#10;Usa este layout en el dashboard ahora"><i class="mdi mdi-check"></i></button>' +
            '</div>' +
            '<span class="dcl-refresh-custom-err" id="dcl-meta-custom-err"></span>' +
            '</div>' +
            '</div>';

        function aplicarCustom() {
            var inp = document.getElementById('dcl-meta-custom-val');
            var err = document.getElementById('dcl-meta-custom-err');
            var v = parseInt(inp && inp.value, 10);
            if (!(v > 0 && v <= 100)) {
                if (inp) { inp.focus(); inp.classList.add('dcl-refresh-custom-input--err'); }
                if (err) err.textContent = 'Ingresa un porcentaje entre 1 y 100';
                return;
            }
            dclSetMeta(v);
            dclCloseMetaPanel();
        }

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && (el.getAttribute('data-meta') || el.getAttribute('data-act')))) el = el.parentNode;
            if (!el || el === panel) return;
            var metaAttr = el.getAttribute('data-meta');
            if (metaAttr) { dclSetMeta(parseInt(metaAttr, 10)); dclCloseMetaPanel(); return; }
            var act = el.getAttribute('data-act');
            if (act === 'close') dclCloseMetaPanel();
            else if (act === 'custom') aplicarCustom();
        });

        var customInput = panel.querySelector('#dcl-meta-custom-val');
        if (customInput) {
            customInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); aplicarCustom(); }
            });
            customInput.addEventListener('input', function () {
                customInput.classList.remove('dcl-refresh-custom-input--err');
                var err = document.getElementById('dcl-meta-custom-err');
                if (err) err.textContent = '';
            });
        }

        document.body.appendChild(panel);

        var box = panel.querySelector('.dcl-layouts-box');
        if (box && btn) {
            var r = btn.getBoundingClientRect();
            var boxW = 260;
            var left = Math.min(r.right - boxW, window.innerWidth - boxW - 10);
            if (left < 10) left = 10;
            box.style.position = 'fixed';
            box.style.top = (r.bottom + 8) + 'px';
            box.style.right = 'auto';
            box.style.left = left + 'px';
            box.style.width = boxW + 'px';
        }
        requestAnimationFrame(function () { panel.classList.add('dcl-layouts-panel--open'); });
    }

    function dclCardCfgApplyMeta() {
        var inp = document.getElementById('dcl-cfg-meta-input');
        if (!inp) return;
        var v = parseFloat(inp.value);
        if (!(v > 0 && v <= 100)) {
            inp.classList.add('dcl-refresh-custom-input--err');
            return;
        }
        inp.classList.remove('dcl-refresh-custom-input--err');

        var cfg = dclGetCfg();
        cfg.metaCumplimiento = v;
        dclSaveCfg(cfg);          // persiste en localStorage + USUARIO_DASHBOARD_CONFIGURACION

        dclCloseCardCfg();
        // El velocímetro se dibuja en el servidor con la meta, así que hay que
        // pedirle el HTML de nuevo para que se redibujen zonas y marcador.
        dclAutoRefreshAjax(true);
    }
    function dclCloseCardCfg() {
        var p = document.getElementById('dcl-card-cfg-panel');
        if (p) {
            p.classList.remove('dcl-card-cfg-panel--open');
            setTimeout(function () { if (p.parentNode) p.parentNode.removeChild(p); }, 260);
        }
        _dclCfgCard = null;
    }
    function dclCardCfgApplyTitle() {
        if (!_dclCfgCard) return;
        var inp = document.getElementById('dcl-cfg-title-input');
        var t = inp ? inp.value.trim() : '';
        var span = _dclCfgCard.querySelector('.dcl-card-title');
        if (span && t) {
            span.textContent = ' ' + t;
            var sid = _dclCfgCard.getAttribute('data-section');
            var cfg = dclGetCfg();
            if (!cfg.sectionTitles) cfg.sectionTitles = {};
            cfg.sectionTitles[sid] = t;
            dclSaveCfg(cfg);
        }
    }
    function dclCardCfgSetWidth(w) {
        if (!_dclCfgCard) return;
        _dclCfgCard.setAttribute('data-width', w);
        var sid = _dclCfgCard.getAttribute('data-section');
        var cfg = dclGetCfg();
        if (!cfg.sectionWidths) cfg.sectionWidths = {};
        cfg.sectionWidths[sid] = w;
        dclSaveCfg(cfg);
    }
    function dclCardCfgToggleHd(chk) {
        if (!_dclCfgCard) return;
        var hd = _dclCfgCard.querySelector('.dcl-card-hd');
        var reveal = _dclCfgCard.querySelector('.dcl-card-reveal');
        if (!hd) return;
        var hide = !chk.checked;
        hd.classList.toggle('dcl-card-hd--hidden', hide);
        // reveal: visible cuando el header está oculto — es la única forma de volver a configurar
        if (reveal) reveal.classList.toggle('dcl-card-reveal--on', hide);
        var sid = _dclCfgCard.getAttribute('data-section');
        var cfg = dclGetCfg();
        if (!cfg.sectionHiddenHd) cfg.sectionHiddenHd = {};
        if (hide) cfg.sectionHiddenHd[sid] = true;
        else delete cfg.sectionHiddenHd[sid];
        dclSaveCfg(cfg);
    }
    // Asigna un nivel de altura (0=Auto, 1=S, 2=M, 3=L, 4=XL) al widget actual.
    // El contenido (tabla/gráfico) se adapta y scrollea dentro de esa altura.
    function dclCardCfgSetHeight(level) {
        if (!_dclCfgCard) return;
        level = Math.max(0, Math.min(4, parseInt(level, 10) || 0));
        var sid = _dclCfgCard.getAttribute('data-section');
        var cfg = dclGetCfg();
        if (!cfg.sectionHeights) cfg.sectionHeights = {};
        // Quitar altura libre (px) — manda el nivel
        _dclCfgCard.style.height = '';
        if (cfg.sectionHeightsPx) delete cfg.sectionHeightsPx[sid];
        cfg.sectionHeights[sid] = String(level);
        _dclCfgCard.setAttribute('data-height', String(level));
        dclSaveCfg(cfg);
        dclCardCfgSyncHBtns(level);
    }
    // Resalta el botón de nivel activo en el panel de config
    function dclCardCfgSyncHBtns(level) {
        var btns = document.querySelectorAll('.dcl-cfg-h-btn');
        for (var i = 0; i < btns.length; i++) {
            btns[i].classList.toggle('dcl-cfg-h-btn--on', btns[i].getAttribute('data-h') === String(level));
        }
    }
    function dclCardCfgResetHeight() {
        if (!_dclCfgCard) return;
        _dclCfgCard.style.height = '';
        var sid = _dclCfgCard.getAttribute('data-section');
        var cfg = dclGetCfg();
        if (cfg.sectionHeightsPx) delete cfg.sectionHeightsPx[sid];
        if (cfg.sectionHeights) delete cfg.sectionHeights[sid];
        _dclCfgCard.removeAttribute('data-height');
        dclSaveCfg(cfg);
        dclCardCfgSyncHBtns(-1);
    }

    // ── Toggle ocultar / mostrar barra de filtros ─────────────────────
    function dclToggleFiltros() {
        var bar = document.querySelector('.dcl-filter-bar');
        var fab = document.getElementById('dcl-flt-show-fab');
        var btn = document.getElementById('dcl-flt-toggle');
        if (!bar) return;
        var hidden = bar.classList.toggle('dcl-flt-hidden');
        if (fab) fab.style.display = hidden ? 'flex' : 'none';
        if (btn) {
            var icon = btn.querySelector('i');
            if (icon) icon.className = hidden ? 'mdi mdi-chevron-down' : 'mdi mdi-chevron-up';
            btn.setAttribute('data-tip', hidden ? 'Mostrar filtros\nVuelve a desplegar la barra de filtros' : 'Ocultar filtros\nContrae la barra para ganar espacio en pantalla');
        }
    }

    // ── Control de alto de card (desde botones en el header) ─────────────
    function dclCardSetHeight(btn, delta) {
        var sec = btn;
        while (sec && !sec.getAttribute('data-section')) sec = sec.parentNode;
        if (!sec) return;
        var cur = parseInt(sec.getAttribute('data-height') || '0', 10);
        var next = Math.max(0, Math.min(4, cur + delta));
        if (next === cur) return;
        if (next === 0) sec.removeAttribute('data-height');
        else sec.setAttribute('data-height', next);
        var lbls = ['Auto', 'S', 'M', 'L', 'XL'];
        var hd = sec.querySelector('.dcl-card-hd');
        var hval = hd ? hd.querySelector('.dcl-rsz-hval-hd') : null;
        if (hval) hval.textContent = lbls[next];
        var cfg = dclGetCfg();
        if (!cfg.sectionHeights) cfg.sectionHeights = {};
        var sid = sec.getAttribute('data-section');
        if (next === 0) delete cfg.sectionHeights[sid];
        else cfg.sectionHeights[sid] = next;
        dclSaveCfg(cfg);
    }

    // ── Toggle ancho de card (span-1 ↔ span-all) ────────────────────────
