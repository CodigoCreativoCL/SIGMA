    // =====================================================================
    // Dashboard Checklists — Power BI Experience
    // =====================================================================
 
    // La configuración se guarda POR NIVEL: cada nivel tiene distintos widgets,
    // así que un layout de Zona aplicado a General dejaría slots vacíos.
    // (dclNivelActual se define más abajo; solo se invoca en runtime, no al cargar.)
    // ── Tooltips enriquecidos ─────────────────────────────────────────────
    // Los botones de la 2ª fila de filtros son solo íconos. El title nativo no
    // alcanza (tarda ~1s, es gris chico y no admite formato) y hacerlo con
    // ::after del propio botón depende del overflow y del stacking context de
    // la barra sticky. Se monta UN elemento en <body> y se posiciona a mano.
    // 
    // El texto de data-tip lleva título y descripción separados por \n.
    var _dclTipEl = null;

    function dclTipNodo() {
        if (_dclTipEl && _dclTipEl.parentNode) return _dclTipEl;
        _dclTipEl = document.createElement('div');
        _dclTipEl.className = 'dcl-tip';
        _dclTipEl.innerHTML = '<span class="dcl-tip-tit"></span>' +
                              '<span class="dcl-tip-desc"></span>' +
                              '<span class="dcl-tip-arrow"></span>';
        document.body.appendChild(_dclTipEl);
        return _dclTipEl;
    }

    function dclTipOcultar() {
        if (_dclTipEl) _dclTipEl.classList.remove('dcl-tip--on');
    }

    function dclTipMostrar(el) {
        var txt = el.getAttribute('data-tip');
        if (!txt) return;
        var partes = txt.split('\n');
        var tip = dclTipNodo();
        tip.querySelector('.dcl-tip-tit').textContent = partes[0] || '';
        var desc = tip.querySelector('.dcl-tip-desc');
        desc.textContent = partes.slice(1).join(' ');
        desc.style.display = partes.length > 1 ? 'block' : 'none';

        // Medir con el tooltip ya visible pero transparente
        tip.style.left = '0px';
        tip.style.top = '-9999px';
        tip.classList.add('dcl-tip--on');

        var r = el.getBoundingClientRect();
        var w = tip.offsetWidth, h = tip.offsetHeight;
        var margen = 8;

        // Centrado bajo el botón, recortado para no salirse de la ventana
        var left = r.left + (r.width / 2) - (w / 2);
        if (left < margen) left = margen;
        if (left + w > window.innerWidth - margen) left = window.innerWidth - margen - w;

        var top = r.bottom + 9;
        if (top + h > window.innerHeight - margen) top = r.top - h - 9;   // no entra abajo → arriba

        tip.style.left = Math.round(left) + 'px';
        tip.style.top = Math.round(top) + 'px';

        // La flecha apunta al centro del botón, esté donde esté el tooltip
        var flecha = tip.querySelector('.dcl-tip-arrow');
        var cx = r.left + (r.width / 2) - left - 5.5;
        cx = Math.max(9, Math.min(w - 20, cx));
        flecha.style.left = Math.round(cx) + 'px';
        flecha.style.display = (top < r.top) ? 'none' : '';   // tooltip arriba → sin flecha
    }

    // Delegación en document: sobrevive a los refrescos AJAX que reemplazan
    // #dcl-content, así que no hay que re-enlazar nada tras cada actualización.
    function dclInitTooltips() {
        if (document._dclTipBound) return;
        document._dclTipBound = true;

        function buscar(t) {
            while (t && t !== document && !(t.getAttribute && t.getAttribute('data-tip'))) t = t.parentNode;
            return (t && t !== document) ? t : null;
        }
        document.addEventListener('mouseover', function (e) {
            var el = buscar(e.target);
            if (el) dclTipMostrar(el); else dclTipOcultar();
        });
        document.addEventListener('mouseout', function (e) {
            if (buscar(e.target)) dclTipOcultar();
        });
        document.addEventListener('focusin', function (e) {
            var el = buscar(e.target);
            if (el) dclTipMostrar(el);
        });
        document.addEventListener('focusout', dclTipOcultar);
        document.addEventListener('click', dclTipOcultar);
        window.addEventListener('scroll', dclTipOcultar, true);
    }

    function dclCfgKey() { return 'dcl_cfg_' + window._dclUsuarioId + '_' + dclNivelActual(); }
      
    // ── Versión del layout por defecto del sistema ────────────────────────
    // SUBIR ESTE NÚMERO cada vez que cambie dclDefaultCfg(). Sin esto, el cfg
    // que el usuario ya tenía en localStorage/servidor gana siempre y nunca ve
    // la estructura nueva (el default solo se aplicaba si el cfg estaba vacío).
    // v9: los cfg guardados de Zona quedaron marcados _vista='instalacion' por el
    // bug de dclReconcileVistaLayout, congelando el layout de Instalación en Zona.
    // Ese cfg corrupto ya está en localStorage/servidor de cada usuario: solo se
    // limpia subiendo la versión.
    var _DCL_DEFAULT_VER   = '9';
    var _dclCfgFueReseteado = false;
    function dclCfgVerKey() { return 'dcl_cfgver_' + window._dclUsuarioId; }
    function dclResetCfgSiVersionVieja() {
        var guardada = '';
        try { guardada = localStorage.getItem(dclCfgVerKey()) || ''; } catch (e) { }
        if (guardada === _DCL_DEFAULT_VER) return;
        try {
            var niveles = ['general', 'instalacion', 'zona'];
            for (var i = 0; i < niveles.length; i++)
                localStorage.removeItem('dcl_cfg_' + window._dclUsuarioId + '_' + niveles[i]);
            localStorage.setItem(dclCfgVerKey(), _DCL_DEFAULT_VER);
            sessionStorage.removeItem('dcl_dflt_applied');
            _dclCfgFueReseteado = true;   // ignora el cfg del servidor en esta carga
        } catch (e) { }
    }

    var _dclEstadoActivo = '';   // segmento del pie actualmente seleccionado
    var _dclSupActivo = '';   // barra de supervisor actualmente seleccionada

    // ── Config localStorage + DB ──────────────────────────────────────────
    // El "modulo" persistido tambien lleva el nivel: la tabla guarda un JSON por
    // (usuario, modulo), asi que sin esto los 3 niveles se pisarian entre si.
    function dclWsModule() { return 'checklists_' + dclNivelActual(); }
    function dclGetCfg() {
        try { return JSON.parse(localStorage.getItem(dclCfgKey())) || {}; } catch (e) { return {}; }
    }
    var _dclSaveSrvTimer = null;
    function dclSaveCfg(cfg) {
        try { localStorage.setItem(dclCfgKey(), JSON.stringify(cfg)); } catch (e) { }
        // Debounce: evita spam de requests al servidor en operaciones rápidas
        // (resize, drag continuo). Se persiste 600 ms después del último cambio.
        if (_dclSaveSrvTimer) clearTimeout(_dclSaveSrvTimer);
        _dclSaveSrvTimer = setTimeout(function () {
            _dclSaveSrvTimer = null;
            var latest = dclGetCfg();
            dclSaveCfgToServer(latest);
        }, 600);
    }

    // Persistencia en servidor (sin bloquear UI)
    function dclSaveCfgToServer(cfg) {
        if (typeof _dclWsBase === 'undefined') return;
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', _dclWsBase + '/SaveConfig', true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.send(JSON.stringify({ module: dclWsModule(), layoutJson: JSON.stringify(cfg) }));
        } catch (e) { }
    }
    function dclLoadCfgFromServer(onLoaded) {
        if (typeof _dclWsBase === 'undefined') { onLoaded(null); return; }
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', _dclWsBase + '/GetConfig', true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 || xhr.status !== 200) return;
                try {
                    var resp = JSON.parse(xhr.responseText);
                    var json = (resp && typeof resp.d === 'string') ? resp.d : '';
                    onLoaded(json ? JSON.parse(json) : null);
                } catch (e) { onLoaded(null); }
            };
            xhr.send(JSON.stringify({ module: dclWsModule() }));
        } catch (e) { onLoaded(null); }
    }

    // ── Configuración por defecto para nuevos usuarios ────────────────────
    // MODELO DE FILAS (v2): cada fila tiene `cols` (1-4) y `slots` (array). Cada
    // slot puede ser: un id (string), null (columna vacía) o un objeto
    // { sec:'id', span:N } para que una sección ocupe N columnas. Esto permite
    // control manual absoluto incluyendo anchos por columnas (span).

    // ¿Estamos en la vista por instalación? (hf>0 o título "INFORME CHECKLIST")
    // Se conserva por compatibilidad; para decidir layout usar dclNivelActual().
    function dclIsVistaInstalacion() {
        var hf = document.getElementById('hfInstalacion');
        if (hf && parseInt(hf.value || '0', 10) > 0) return true;
        var t = document.querySelector('.dcl-page-title-data');
        if (t && /INFORME CHECKLIST/i.test(t.textContent || '')) return true;
        return false;
    }

    // Layout por defecto del sistema, uno por nivel de drill-down.
    // Cada nivel muestra SOLO widgets de su nivel (ver _DCL_SECTIONS_POR_NIVEL):
    // un layout de Zona aplicado a General dejaría slots vacíos.
    function dclDefaultCfg(forceNivel) {
        var nivel = forceNivel || dclNivelActual();

        if (nivel === 'zona') {
            // NIVEL ZONA
            //   Fila 1 → Indicadores Clave (KPIs), ya filtrados por cliente+instalación+zona.
            //   Fila 2 → columna izq: SLA (tipos 1/2/3, con control de horario) y
            //            debajo los tipos SIN control de horario (tipo 4);
            //            columna der: detalle de checklists de la zona (timeline
            //            con respuestas y hallazgos desplegables).
            // El motor de layout es por filas y un slot = un widget, así que la
            // "columna izquierda con dos widgets apilados" se expresa como dos
            // filas: el timeline queda a la derecha de la primera.
            // dcl-sla ya incluye el bloque "sin control de horas" (tipo 4) debajo
            // de un divider, así que no hace falta un widget aparte en el layout.
            return {
                rows: [
                    { cols: 1, slots: ['dcl-kpi'] },
                    { cols: 2, slots: ['dcl-sla', 'dcl-resp-dia'] }
                ],
                sectionHeights: { 'dcl-kpi': '1', 'dcl-sla': '3', 'dcl-resp-dia': '4' }
            };
        }

        if (nivel === 'instalacion') {
            // NIVEL INSTALACIÓN — KPIs, cumplimiento por zona (click → dashboard de
            // la zona) y el bloque de control de horario del período.
            return {
                rows: [
                    { cols: 1, slots: ['dcl-kpi'] },
                    { cols: 2, slots: ['dcl-zonas', 'dcl-kpi-horario'] }
                ],
                sectionHeights: {
                    'dcl-kpi': '1', 'dcl-zonas': '3', 'dcl-kpi-horario': '3'
                }
            };
        }

        // NIVEL GENERAL — indicadores clave arriba; abajo el velocímetro de
        // cumplimiento global (izq., con meta configurable en el engranaje) y el
        // cumplimiento por instalación (der., click en la fila → nivel instalación).
        return {
            rows: [
                { cols: 1, slots: ['dcl-kpi'] },
                { cols: 2, slots: ['dcl-gauge', 'dcl-install-bar'] }
            ],
            sectionHeights: { 'dcl-kpi': '1', 'dcl-gauge': '3', 'dcl-install-bar': '3' }
        };
    }

    // Extrae el id de sección de un slot (string | {sec} | null)
    function dclSlotSec(slot) {
        if (!slot) return null;
        if (typeof slot === 'string') return slot;
        return slot.sec || null;
    }
    // Extrae el span (nº de columnas) de un slot. Default 1.
    function dclSlotSpan(slot) {
        if (slot && typeof slot === 'object' && slot.span) {
            return Math.max(1, parseInt(slot.span, 10) || 1);
        }
        return 1;
    }

    // Normaliza una fila al modelo v2. `slots` se completa hasta `cols` celdas
    // EFECTIVAS contando los spans. Cada slot con sección puede ocupar varias
    // columnas (span), por lo que el total de spans + huecos === cols.
    function dclNormalizeRow(row) {
        var cols = Math.max(1, Math.min(4, parseInt(row && row.cols, 10) || 1));
        var raw = (row && row.slots && row.slots.length) ? row.slots.slice(0) : [];
        var slots = [];
        var used = 0;
        for (var i = 0; i < raw.length && used < cols; i++) {
            var sp = dclSlotSpan(raw[i]);
            if (used + sp > cols) sp = cols - used;       // recortar span al ancho restante
            var sec = dclSlotSec(raw[i]);
            slots.push(sp > 1 ? { sec: sec, span: sp } : (sec || null));
            used += sp;
        }
        while (used < cols) { slots.push(null); used++; }  // rellenar con huecos
        return { cols: cols, slots: slots };
    }
    function dclNormalizeRows(rows) {
        if (!rows || !rows.length) return [];
        var out = [];
        for (var i = 0; i < rows.length; i++) out.push(dclNormalizeRow(rows[i]));
        return out;
    }
    // ¿La fila tiene formato v2 válido (slots)? Si trae el formato viejo
    // (sections sin slots), se considera inválida y dispara reset al default.
    function dclCfgIsV2(cfg) {
        if (!cfg || !cfg.rows || !cfg.rows.length) return true; // sin filas → válido (default se aplica aparte)
        for (var i = 0; i < cfg.rows.length; i++) {
            if (!cfg.rows[i] || !cfg.rows[i].slots) return false;
        }
        return true;
    }

    function dclApplyDefaultCfgIfEmpty() {
        var cfg = dclGetCfg();
        var hasLayout = cfg.rows && cfg.rows.length;
        // Reset de layouts: si viene en formato viejo (sections), descartar y aplicar default v2
        if (hasLayout && !dclCfgIsV2(cfg)) { hasLayout = false; }
        if (!hasLayout) {
            var def = dclDefaultCfg();
            // dclNivelActual(), NO dclIsVistaInstalacion(): en Zona el hidden de
            // instalación también viene con valor, así que el ternario marcaba
            // _vista='instalacion' sobre un cfg de Zona. Ver dclReconcileVistaLayout.
            def._vista = dclNivelActual();
            dclSaveCfg(def);
        }
    }

    // Reconcilia el layout con la vista actual. Si el layout activo es el del
    // sistema y la vista cambió (general ↔ instalación), aplica la variante
    // correcta de esa vista. Soluciona que al elegir una instalación no cambiara
    // el default a la estructura solicitada para esa vista.
    function dclReconcileVistaLayout() {
        // La vista es el NIVEL, con Zona como valor de primera clase. Antes se
        // derivaba de dclIsVistaInstalacion(), que en Zona da true (el hidden de
        // instalación está poblado): el cfg de Zona quedaba marcado
        // _vista='instalacion' y el CASO 1 lo daba por bueno, así que un layout
        // de Instalación se congelaba en Zona y sus widgets propios (dcl-sla,
        // dcl-resp-dia) nunca entraban en ninguna fila → no se renderizaban.
        var vistaActual = dclNivelActual();
        var cfg = dclGetCfg();

        // CASO 1: el cfg ya pertenece a la vista actual → NO tocar. Preserva los
        // cambios de altura/estructura del usuario (incluso sobre el layout del
        // sistema). El cfg solo se marca con la vista al aplicarse un layout.
        if (cfg._vista === vistaActual && cfg.rows && cfg.rows.length) {
            return;
        }

        // La vista CAMBIÓ (o el cfg no tiene vista marcada).
        var activeName = dclGetActiveLayoutName();
        var saved = dclGetSavedLayouts();
        var sysLayout = null, userLayout = null;
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].isSystem) sysLayout = saved[i];
            else if (activeName && saved[i].name === activeName) userLayout = saved[i];
        }

        // CASO 2: hay un layout de USUARIO guardado con el nombre activo → respetarlo
        // (su cfg es el mismo en cualquier vista, ya que todas las secciones existen).
        if (userLayout && userLayout.cfg && userLayout.cfg.rows && userLayout.cfg.rows.length) {
            var uclone = JSON.parse(JSON.stringify(userLayout.cfg));
            uclone._vista = vistaActual;
            dclSaveCfg(uclone);
            return;
        }

        // CASO 3 (default): cualquier otro caso (layout del sistema, "Personalizado"
        // sin guardar, o sin nombre) → aplicar la variante del sistema de la vista
        // actual. Esto garantiza que al cambiar a instalación se vea su default.
        if (sysLayout) {
            var src = dclLayoutCfgForView(sysLayout);
            if (src && src.rows && src.rows.length) {
                var clone = JSON.parse(JSON.stringify(src));
                clone._vista = vistaActual;
                dclSaveCfg(clone);
                dclSetActiveLayoutName(sysLayout.name);
                return;
            }
        }
        // Sin layout del sistema (no debería pasar) → default v2 de la vista
        var def = dclDefaultCfg(vistaActual);
        def._vista = vistaActual;
        dclSaveCfg(def);
    }

    // ¿El cfg referencia alguna sección que no está renderizada en el DOM actual?
    function dclCfgReferenciaSeccionesInexistentes(cfg) {
        if (!cfg || !cfg.rows || !cfg.rows.length) return false;
        var container = document.getElementById('dcl-content');
        if (!container) return false;
        var present = {};
        var secs = container.querySelectorAll('.dcl-section[data-section]');
        for (var i = 0; i < secs.length; i++) present[secs[i].getAttribute('data-section')] = true;
        var totalRef = 0, faltan = 0;
        for (var r = 0; r < cfg.rows.length; r++) {
            var slots = cfg.rows[r].slots || [];
            for (var s = 0; s < slots.length; s++) {
                var sid = dclSlotSec(slots[s]);
                if (!sid) continue;
                totalRef++;
                if (!present[sid]) faltan++;
            }
        }
        // Si más de la mitad de las secciones referenciadas no existen → vista incompatible
        return totalRef > 0 && faltan >= Math.ceil(totalRef / 2);
    }

    // ── Init (post-render y post-UpdatePanel) ────────────────────────────
    function dclInit() {
        // Limpiar estado del builder si quedó activo tras postback del UpdatePanel
        var _ov = document.getElementById('dcl-bld-overlay');
        if (document.body.classList.contains('dcl-building') || _ov) {
            var _c = document.getElementById('dcl-content');
            // Rescatar secciones reales que quedaron dentro del overlay del builder
            if (_ov && _c) {
                var _rescued = _ov.querySelectorAll('.dcl-section[data-section]');
                for (var _k = 0; _k < _rescued.length; _k++) {
                    _rescued[_k].classList.remove('dcl-sec-pooled');
                    _c.appendChild(_rescued[_k]);
                }
                if (_ov.parentNode) _ov.parentNode.removeChild(_ov);
            }
            if (_c) {
                var _pl = _c.querySelectorAll('.dcl-sec-pooled');
                for (var _j = 0; _j < _pl.length; _j++) _pl[_j].classList.remove('dcl-sec-pooled');
            }
            document.body.classList.remove('dcl-building');
            _bldDraggingTile = null;
            _bldDraggingSection = null;
        }
        // En primer render: cargar config desde servidor, validar formato y
        // aplicar el layout default guardado (si existe).
        var _isFirstRender = !sessionStorage.getItem('dcl_srv_loaded');

        // La migración de versión va FUERA de _isFirstRender: esa bandera vive en
        // sessionStorage y sobrevive a las recargas, así que con solo haber abierto
        // el dashboard antes en la misma sesión el cfg viejo nunca se descartaba.
        // Es barata: si la versión ya coincide, retorna de inmediato.
        dclResetCfgSiVersionVieja();

        if (_isFirstRender) {
            sessionStorage.setItem('dcl_srv_loaded', '1');
            dclEnsureSystemLayout();   // garantiza el layout "Por defecto del sistema"
            dclLoadCfgFromServer(function (srvCfg) {
                // Solo aceptar config del servidor si está en el modelo v2 (slots).
                // Una config vieja (sections) se ignora → reset al default.
                // Si el default del sistema cambió de versión en esta carga, el cfg
                // del servidor también quedó obsoleto: se descarta y se re-persiste
                // el nuevo default (dclSaveCfg lo sube solo).
                if (srvCfg && dclCfgIsV2(srvCfg) && !_dclCfgFueReseteado) {
                    try { localStorage.setItem(dclCfgKey(), JSON.stringify(srvCfg)); } catch (e) { }
                }
                dclApplyDefaultSavedLayout();   // aplica el layout marcado default
                dclApplyDefaultCfgIfEmpty();    // si sigue vacío/viejo → default v2
                if (_dclCfgFueReseteado) dclSaveCfg(dclGetCfg());
                dclApplySectionState();
            });
            // Aplicación optimista inmediata mientras llega la respuesta del server
            dclApplyDefaultSavedLayout();
            dclApplyDefaultCfgIfEmpty();
        }

        // Si la vista cambió (general ↔ instalación) y el layout activo es el del
        // sistema, re-aplicar la variante de la nueva vista. También cubre el caso
        // en que el cfg quedó apuntando a secciones de la otra vista.
        dclReconcileVistaLayout();

        dclApplySectionState();
        dclInitSectionDnD();
        dclInitTableSorting();
        dclInitTableFilters();
        dclInitColumnDnD();
        dclApplyColumnOrders();
        dclInitStatsRows();
        dclApplyKpiOrder();
        dclInitKpiDnD();
        dclInitDarkMode();
        dclInitTooltips();
        dclUpdateRefreshBtnUI();
        dclMetaInputSync();
        dclRenderActiveLayoutName();
        dclRenderBreadcrumb();

        // Tutorial guiado: se agenda siempre que el usuario no lo haya visto.
        // NO puede depender de _isFirstRender: esa bandera sale de una clave de
        // sessionStorage que sobrevive a las recargas, así que con solo haber
        // abierto la página antes en la misma sesión el tour no se agendaba nunca.
        dclOnbAgendar();
        _dclEstadoActivo = '';
        _dclSupActivo = '';
    }


    // ── Tema oscuro / claro ──────────────────────────────────────────────
    function dclInitDarkMode() {
        var saved = '';
        try { saved = localStorage.getItem('dcl_theme') || ''; } catch (e) { }
        if (saved) _dclApplyTheme(saved, false);
    }
    function dclToggleTheme() {
        var cur = document.documentElement.getAttribute('data-dcl-theme') || 'light';
        var next = cur === 'dark' ? 'light' : 'dark';
        _dclApplyTheme(next, true);
    }
    function _dclApplyTheme(theme, save) {
        document.documentElement.setAttribute('data-dcl-theme', theme);
        if (save) { try { localStorage.setItem('dcl_theme', theme); } catch (e) { } }
        var btn = document.getElementById('dcl-theme-btn');
        if (!btn) return;
        var icon = btn.querySelector('i');
        if (icon) icon.className = theme === 'dark' ? 'mdi mdi-weather-sunny' : 'mdi mdi-weather-night';
        btn.setAttribute('data-tip', 'Tema\n' + (theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'));
    }

    // ── Resize handle — arrastrar borde inferior de card ─────────────
    var _dclRszSec = null, _dclRszY0 = 0, _dclRszH0 = 0;

    function _dclBlockDragstart(e) { e.preventDefault(); e.stopPropagation(); }

    function dclRszStart(e, handle) {
        var sec = handle.parentNode;
        if (!sec) return;
        e.preventDefault(); e.stopPropagation();
        // Desactivar draggable en la card para que el browser no lance DnD HTML5
        // en vez de disparar mousemove (conflicto: card tiene draggable="true")
        sec.setAttribute('draggable', 'false');
        sec.addEventListener('dragstart', _dclBlockDragstart);
        _dclRszSec = sec; _dclRszY0 = e.clientY; _dclRszH0 = sec.offsetHeight;
        sec.classList.add('dcl-rsz-active');
        document.addEventListener('mousemove', dclRszMove);
        document.addEventListener('mouseup', dclRszEnd);
    }
    function dclRszMove(e) {
        if (!_dclRszSec) return;
        e.preventDefault();
        var newH = Math.max(80, _dclRszH0 + (e.clientY - _dclRszY0));
        _dclRszSec.style.height = newH + 'px';
    }
    function dclRszEnd() {
        if (!_dclRszSec) return;
        // Restaurar draggable para el DnD de reordenar cards
        _dclRszSec.setAttribute('draggable', 'true');
        _dclRszSec.removeEventListener('dragstart', _dclBlockDragstart);
        _dclRszSec.classList.remove('dcl-rsz-active');
        var sid = _dclRszSec.getAttribute('data-section');
        if (sid) {
            var cfg = dclGetCfg();
            if (!cfg.sectionHeightsPx) cfg.sectionHeightsPx = {};
            var h = _dclRszSec.style.height;
            if (h) {
                cfg.sectionHeightsPx[sid] = h;
                // La altura px MANDA sobre el nivel: quitar data-height para que el
                // min-height del nivel no pelee con el px asignado por el resize.
                _dclRszSec.removeAttribute('data-height');
                if (cfg.sectionHeights) delete cfg.sectionHeights[sid];
            } else {
                delete cfg.sectionHeightsPx[sid];
            }
            dclSaveCfg(cfg);
        }
        document.removeEventListener('mousemove', dclRszMove);
        document.removeEventListener('mouseup', dclRszEnd);
        _dclRszSec = null;
    }

    // ── Resize handle — arrastrar borde derecho para ajustar ancho ──
    var _dclRszWSec = null, _dclRszWNumCols = 2;

    function dclRszWStart(e, handle) {
        var sec = handle.parentNode;
        if (!sec) return;
        e.preventDefault(); e.stopPropagation();
        sec.setAttribute('draggable', 'false');
        sec.addEventListener('dragstart', _dclBlockDragstart);

        var content = document.getElementById('dcl-content');
        _dclRszWNumCols = parseInt(content ? (content.getAttribute('data-cols') || '2') : '2', 10);
        _dclRszWSec = sec;

        sec.classList.add('dcl-rsz-w-active');
        document.body.style.cursor = 'ew-resize';
        document.addEventListener('mousemove', dclRszWMove);
        document.addEventListener('mouseup', dclRszWEnd);
    }
    function dclRszWMove(e) {
        if (!_dclRszWSec) return;
        e.preventDefault();

        var content = document.getElementById('dcl-content');
        if (!content) return;
        var rect = content.getBoundingClientRect();
        var contentW = rect.width;
        if (contentW <= 0) return;

        // Ratio del mouse dentro del grid (0 = inicio, 1 = fin)
        var ratio = Math.max(0.001, Math.min(1, (e.clientX - rect.left) / contentW));

        // span = columnas que ocupa la card.
        // ceil(ratio * numCols): en cuanto el mouse entra en la siguiente columna, la card crece.
        var span = Math.max(1, Math.min(_dclRszWNumCols, Math.ceil(ratio * _dclRszWNumCols)));

        var widthVal;
        if (span >= _dclRszWNumCols) widthVal = 'full';
        else if (span === 2) widthVal = 'w2';
        else widthVal = 'half';

        if (_dclRszWSec.getAttribute('data-width') !== widthVal)
            _dclRszWSec.setAttribute('data-width', widthVal);
    }
    function dclRszWEnd() {
        if (!_dclRszWSec) return;
        _dclRszWSec.setAttribute('draggable', 'true');
        _dclRszWSec.removeEventListener('dragstart', _dclBlockDragstart);
        _dclRszWSec.classList.remove('dcl-rsz-w-active');
        document.body.style.cursor = '';

        var sid = _dclRszWSec.getAttribute('data-section');
        if (sid) {
            var cfg = dclGetCfg();
            if (!cfg.sectionWidths) cfg.sectionWidths = {};
            cfg.sectionWidths[sid] = _dclRszWSec.getAttribute('data-width') || 'half';
            dclSaveCfg(cfg);
        }
        document.removeEventListener('mousemove', dclRszWMove);
        document.removeEventListener('mouseup', dclRszWEnd);
        _dclRszWSec = null;
    }

    // ══════════════════════════════════════════════════════════════
    // PRESENTATION MODE — picker de modo + slide por elemento + layout completo
    // ══════════════════════════════════════════════════════════════
    var _presTimer = null, _presIdx = 0, _presPlaying = true;
    var _presInterval = 6000;
    var _presLayoutScaleFn = null; // referencia para cleanup

    // ── Entrada: picker de modo ────────────────────────────────────
