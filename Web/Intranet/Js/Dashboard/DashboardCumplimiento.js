    // =====================================================================
    // Dashboard Checklists — Power BI Experience
    // =====================================================================
 
    // La configuración se guarda POR NIVEL: cada nivel tiene distintos widgets,
    // así que un layout de Zona aplicado a General dejaría slots vacíos.
    // (dclNivelActual se define más abajo; solo se invoca en runtime, no al cargar.)
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
        btn.title = theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro';
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
            '<button type="button" class="dcl-pres-btn" onclick="dclPresPrev()" title="Anterior (←)"><i class="mdi mdi-chevron-left"></i></button>' +
            '<button type="button" class="dcl-pres-btn" id="dcl-pres-playbtn" onclick="dclPresTogglePlay()" title="Pausar/Reanudar (P)"><i class="mdi mdi-pause"></i></button>' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresNext()" title="Siguiente (→)"><i class="mdi mdi-chevron-right"></i></button>' +
            '<span class="dcl-pres-counter" id="dcl-pres-counter"></span>' +
            '<input type="range" id="dcl-pres-speed" min="3" max="20" value="6" ' +
            'title="Velocidad (s)" oninput="dclPresSetSpeed(this.value)" ' +
            'style="width:70px;accent-color:#56F5F8;cursor:pointer" />' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresHelp()" title="Ayuda"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-exit" onclick="dclExitPresentation()" title="Salir (Esc)"><i class="mdi mdi-close-circle-outline"></i></button>' +
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
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll" onclick="dclPresFullScroll(-1)" title="Subir"><i class="mdi mdi-chevron-up"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll dcl-pres-btn--txt" id="dcl-pres-desplbtn" onclick="dclPresToggleDesplazamiento()" title="Desplazamiento automático del tablero">' +
            '<i class="mdi mdi-play"></i><span>Desplazamiento</span></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-scroll" onclick="dclPresFullScroll(1)" title="Bajar"><i class="mdi mdi-chevron-down"></i></button>' +
            // En modo ajustado, el play recorre el contenido DENTRO de cada widget.
            '<button type="button" class="dcl-pres-btn dcl-pres-solo-fit" id="dcl-pres-playbtn" onclick="dclPresToggleAutoScroll()" title="Recorrer el contenido de los widgets"><i class="mdi mdi-play"></i></button>' +
            // Selección de qué dashboards rotar (General / instalaciones / zonas)
            '<button type="button" class="dcl-pres-btn dcl-pres-btn--txt" onclick="dclPresAbrirSelector()" title="Elegir qué dashboards mostrar">' +
            '<i class="mdi mdi-view-grid-plus-outline"></i><span id="dcl-pres-dashlbl">Dashboards</span></button>' +
            '<button type="button" class="dcl-pres-btn" onclick="dclPresHelp()" title="Ayuda"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<button type="button" class="dcl-pres-btn dcl-pres-exit" onclick="dclExitPresentation()" title="Salir (Esc)"><i class="mdi mdi-close-circle-outline"></i></button>' +
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
            '<button type="button" class="dcl-cfg-close" onclick="dclCloseCardCfg()" title="Cerrar">&#10005;</button>' +
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
            '<button type="button" class="dcl-cfg-h-btn" data-h="0" onclick="dclCardCfgSetHeight(0)" title="Automática (según contenido)">Auto</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="1" onclick="dclCardCfgSetHeight(1)" title="Pequeña">S</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="2" onclick="dclCardCfgSetHeight(2)" title="Mediana">M</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="3" onclick="dclCardCfgSetHeight(3)" title="Grande">L</button>' +
            '<button type="button" class="dcl-cfg-h-btn" data-h="4" onclick="dclCardCfgSetHeight(4)" title="Extra grande">XL</button>' +
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
        if (btn) btn.title = 'Parametrización de gráficos — meta ' + dclGetMeta() + '%';
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
            '<button type="button" class="dcl-layouts-close" data-act="close" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-meta-panel-lbl">Cumplimiento Global de Checklists</div>' +
            '<div class="dcl-layouts-list">' + optsHtml + '</div>' +
            '<div class="dcl-refresh-custom-wrap">' +
            '<div class="dcl-layouts-ft dcl-refresh-custom">' +
            '<input type="number" min="1" max="100" step="1" class="dcl-refresh-custom-input" id="dcl-meta-custom-val" ' +
            'placeholder="Personalizado" value="' + (esPreset ? '' : actual) + '" />' +
            '<span class="dcl-refresh-custom-unit">%</span>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="custom" title="Aplicar"><i class="mdi mdi-check"></i></button>' +
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
            btn.title = hidden ? 'Mostrar filtros' : 'Ocultar filtros';
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
    function dclToggleWidth(btn) {
        var section = btn;
        while (section && !section.getAttribute('data-section')) section = section.parentNode;
        if (!section) return;
        var nw = (section.getAttribute('data-width') === 'full') ? 'half' : 'full';
        section.setAttribute('data-width', nw);
        var cfg = dclGetCfg();
        if (!cfg.sectionWidths) cfg.sectionWidths = {};
        cfg.sectionWidths[section.getAttribute('data-section')] = nw;
        dclSaveCfg(cfg);
    }

    // ── Aplicar orden, anchos y número de cols guardados ─────────────────
    function dclApplySectionState() {
        var cfg = dclGetCfg();
        var container = document.getElementById('dcl-content');
        if (!container) return;

        // Limpieza defensiva: eliminar overlays de drop-zone y estado de drag que
        // pudieran haber quedado de un reordenamiento interrumpido (causaban que el
        // recuento de slots fallara al re-aplicar un layout distinto).
        var _dz = container.querySelectorAll('.dcl-view-dz');
        for (var _i = 0; _i < _dz.length; _i++) if (_dz[_i].parentNode) _dz[_i].parentNode.removeChild(_dz[_i]);
        container.classList.remove('dcl-view-dragging');
        var _ds = container.querySelectorAll('.dcl-drag-src');
        for (var _j = 0; _j < _ds.length; _j++) _ds[_j].classList.remove('dcl-drag-src');
        _dclDragSrc = null;

        // Quitar wrappers .dcl-sec-row anteriores y mover secciones al raíz
        dclBldUnwrapRows(container);

        // Recoger todas las secciones del contenedor
        var allSecs = Array.prototype.slice.call(container.querySelectorAll('.dcl-section[data-section]'));

        // Aplicar atributos comunes (alto, título, encabezado) sin importar el modo
        for (var i = 0; i < allSecs.length; i++) {
            var sid = allSecs[i].getAttribute('data-section');
            if (cfg.sectionHeights && cfg.sectionHeights[sid]) allSecs[i].setAttribute('data-height', cfg.sectionHeights[sid]);
            else allSecs[i].removeAttribute('data-height');
            if (cfg.sectionHeightsPx && cfg.sectionHeightsPx[sid]) allSecs[i].style.height = cfg.sectionHeightsPx[sid];
            else allSecs[i].style.height = '';
            if (cfg.sectionTitles && cfg.sectionTitles[sid]) {
                var tSpan = allSecs[i].querySelector('.dcl-card-title');
                if (tSpan) tSpan.textContent = ' ' + cfg.sectionTitles[sid];
            }
            var hd2 = allSecs[i].querySelector('.dcl-card-hd');
            var rev = allSecs[i].querySelector('.dcl-card-reveal');
            var hdHide = !!(cfg.sectionHiddenHd && cfg.sectionHiddenHd[sid]);
            if (hd2) hd2.classList.toggle('dcl-card-hd--hidden', hdHide);
            if (rev) rev.classList.toggle('dcl-card-reveal--on', hdHide);
            // Defensa: nunca dejar una card atenuada por un drag interrumpido
            allSecs[i].classList.remove('dcl-drag-src');
            // Reset de span previo (se reaplica abajo solo si el slot lo define)
            allSecs[i].style.gridColumn = '';
        }

        if (cfg.rows && cfg.rows.length) {
            // ── Modo fila (row-layout) — CONTROL MANUAL ABSOLUTO ────────────
            // Renderiza cada fila como un grid de N columnas. Cada slot es una
            // celda independiente: si trae sección, se muestra; si es null, se
            // renderiza una celda VACÍA (placeholder invisible) que ocupa su
            // columna. NO se reorganiza, NO se centra, NO se rellenan huecos.
            container.classList.add('dcl-row-layout');
            // Ocultar todas por defecto; se mostrarán al colocarlas en filas
            for (var i = 0; i < allSecs.length; i++) allSecs[i].style.display = 'none';

            var secMap = {};
            for (var i = 0; i < allSecs.length; i++) secMap[allSecs[i].getAttribute('data-section')] = allSecs[i];

            var rows = dclNormalizeRows(cfg.rows);
            for (var r = 0; r < rows.length; r++) {
                var rowData = rows[r];
                var rowEl = document.createElement('div');
                rowEl.className = 'dcl-sec-row';
                rowEl.setAttribute('data-cols', rowData.cols);
                container.appendChild(rowEl);
                // Recorrer los SLOTS (preserva posición y respeta span de columnas)
                for (var c = 0; c < rowData.slots.length; c++) {
                    var slot = rowData.slots[c];
                    var sid2 = dclSlotSec(slot);
                    var span = dclSlotSpan(slot);
                    var sec = sid2 ? secMap[sid2] : null;
                    if (sec) {
                        sec.style.display = '';
                        sec.style.gridColumn = (span > 1) ? ('span ' + span) : '';
                        rowEl.appendChild(sec);
                    } else {
                        // Celda vacía: mantiene su(s) columna(s) ocupada(s) sin contenido
                        var hole = document.createElement('div');
                        hole.className = 'dcl-sec-hole';
                        if (span > 1) hole.style.gridColumn = 'span ' + span;
                        rowEl.appendChild(hole);
                    }
                }
            }
        } else {
            // ── Modo plano (grid clásico) ───────────────────────────────────
            container.classList.remove('dcl-row-layout');
            if (cfg.cols) container.setAttribute('data-cols', Math.min(parseInt(cfg.cols, 10) || 2, 3));

            for (var i = 0; i < allSecs.length; i++) {
                var sid = allSecs[i].getAttribute('data-section');
                if (cfg.sectionWidths && cfg.sectionWidths[sid]) allSecs[i].setAttribute('data-width', cfg.sectionWidths[sid]);
                allSecs[i].style.display = (cfg.sectionHidden && cfg.sectionHidden[sid]) ? 'none' : '';
            }

            if (cfg.sectionOrder && cfg.sectionOrder.length) {
                var ordered = [];
                for (var o = 0; o < cfg.sectionOrder.length; o++) {
                    for (var j = 0; j < allSecs.length; j++) {
                        if (allSecs[j].getAttribute('data-section') === cfg.sectionOrder[o]) {
                            ordered.push(allSecs[j]); break;
                        }
                    }
                }
                for (var j = 0; j < allSecs.length; j++) {
                    if (ordered.indexOf(allSecs[j]) === -1) ordered.push(allSecs[j]);
                }
                for (var i = 0; i < ordered.length; i++) container.appendChild(ordered[i]);
            }
        }

        dclPublicarLayoutSecs();
    }

    // Publica en un hidden las secciones VISIBLES en orden. Lo consume la
    // exportación a Excel para generar exactamente las hojas del layout activo
    // (antes exportaba un set fijo, sin relación con lo que el usuario veía).
    function dclPublicarLayoutSecs() {
        var hf = document.getElementById('hfLayoutSecs');
        if (!hf) return;
        var ids = [];
        var secs = document.querySelectorAll('#dcl-content .dcl-section[data-section]');
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].style.display === 'none') continue;
            var id = secs[i].getAttribute('data-section');
            if (id && ids.indexOf(id) === -1) ids.push(id);
        }
        hf.value = ids.join(',');
    }

    // ── Guardar estado del grid ──────────────────────────────────────────
    // En el modelo v2 (filas con slots) el orden y el ancho los define el
    // builder, NO el reordenamiento suelto. Esta función solo persiste alturas
    // (data-height / height px) de cada sección visible, sin tocar cfg.rows.
    function dclSaveSectionState() {
        var cfg = dclGetCfg();
        var container = document.getElementById('dcl-content');
        if (!container) return;
        if (!cfg.sectionHeights) cfg.sectionHeights = {};
        if (!cfg.sectionHeightsPx) cfg.sectionHeightsPx = {};
        var secs = container.querySelectorAll('.dcl-section[data-section]');
        for (var i = 0; i < secs.length; i++) {
            var sid = secs[i].getAttribute('data-section');
            if (!sid) continue;
            var h = secs[i].getAttribute('data-height');
            if (h) cfg.sectionHeights[sid] = h;
            var hpx = secs[i].style.height;
            if (hpx) cfg.sectionHeightsPx[sid] = hpx;
            else delete cfg.sectionHeightsPx[sid];
        }
        dclSaveCfg(cfg);
    }

    // ── Drag & drop de secciones EN LA VISTA (modo filas, fuera del builder) ──
    // Al arrastrar una card, aparecen "drop zones" con + en CADA celda de las
    // filas: soltar sobre una celda con sección las INTERCAMBIA; soltar sobre un
    // hueco mueve la card ahí. Da feedback visual dinámico y persiste cfg.rows.
    var _dclDragSrc = null;
    var _dclDzActive = false;

    function dclInitSectionDnD() {
        var container = document.getElementById('dcl-content');
        if (!container) return;
        if (container._dclViewDnDBound) return;
        container._dclViewDnDBound = true;

        container.addEventListener('mousedown', function (e) {
            var sec = dclClosestSection(e.target, container);
            if (!sec) return;
            var inHdr = false, node = e.target;
            while (node && node !== sec) {
                if (node.classList && (node.classList.contains('dcl-card-hd') ||
                    node.classList.contains('dcl-drag-handle'))) { inHdr = true; break; }
                node = node.parentNode;
            }
            sec.setAttribute('draggable', inHdr ? 'true' : 'false');
        });

        container.addEventListener('dragstart', function (e) {
            var sec = dclClosestSection(e.target, container);
            if (!sec || sec.getAttribute('draggable') !== 'true') { return; }
            _dclDragSrc = sec;
            e.dataTransfer.effectAllowed = 'move';
            try { e.dataTransfer.setData('text/plain', sec.getAttribute('data-section') || ''); } catch (ex) { }
            setTimeout(function () {
                sec.classList.add('dcl-drag-src');
                dclViewShowDropZones(container, sec);   // mostrar overlays con +
            }, 0);
        });

        container.addEventListener('dragend', function () {
            dclViewEndDrag(container);
        });

        container.addEventListener('dragover', function (e) {
            if (!_dclDragSrc) return;
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            var dz = dclViewClosestDz(e.target, container);
            var all = container.querySelectorAll('.dcl-view-dz--over');
            for (var j = 0; j < all.length; j++) all[j].classList.remove('dcl-view-dz--over');
            if (dz) dz.classList.add('dcl-view-dz--over');
        });

        container.addEventListener('drop', function (e) {
            if (!_dclDragSrc) return;
            e.preventDefault();
            var dz = dclViewClosestDz(e.target, container);
            if (dz) {
                var cell = dz.parentNode; // la celda (.dcl-section o .dcl-sec-hole) que contiene la DZ
                if (cell && cell !== _dclDragSrc) {
                    if (cell.classList.contains('dcl-section')) {
                        dclViewSwap(_dclDragSrc, cell);          // swap con otra card
                    } else {
                        // hueco → mover la card al hueco y dejar hueco en el origen
                        dclViewMoveToHole(_dclDragSrc, cell);
                    }
                    dclSaveRowsFromView();
                }
            }
            // NO limpiar aquí dcl-drag-src: dragend se encarga (orden drop→dragend).
            // Pero sí cerrar las drop zones para evitar parpadeo.
            dclViewClearDropZones(container);
        });
    }

    // Limpieza robusta al terminar el drag: quita dcl-drag-src de TODAS las cards
    // (no solo de _dclDragSrc), cierra drop zones y resetea estado. Esto corrige
    // el bug de la card que quedaba opaca tras soltar.
    function dclViewEndDrag(container) {
        if (!container) container = document.getElementById('dcl-content');
        if (container) {
            dclViewClearDropZones(container);
            var srcs = container.querySelectorAll('.dcl-section.dcl-drag-src');
            for (var i = 0; i < srcs.length; i++) {
                srcs[i].classList.remove('dcl-drag-src');
                srcs[i].setAttribute('draggable', 'false');
            }
        }
        _dclDragSrc = null;
    }

    // Inserta un overlay de drop-zone (con +) en cada celda elegible de las filas
    function dclViewShowDropZones(container, src) {
        if (_dclDzActive) return;
        _dclDzActive = true;
        container.classList.add('dcl-view-dragging');
        var cells = container.querySelectorAll('.dcl-sec-row > .dcl-section, .dcl-sec-row > .dcl-sec-hole');
        for (var i = 0; i < cells.length; i++) {
            var cell = cells[i];
            if (cell === src) continue;              // no sobre la propia card
            if (cell.querySelector(':scope > .dcl-view-dz')) continue;
            var dz = document.createElement('div');
            dz.className = 'dcl-view-dz';
            dz.innerHTML = '<span class="dcl-view-dz-plus"><i class="mdi mdi-plus"></i></span>' +
                '<span class="dcl-view-dz-txt">' +
                (cell.classList.contains('dcl-section') ? 'Intercambiar' : 'Mover aquí') +
                '</span>';
            // posicionar la DZ absoluta dentro de la celda (la celda es position:relative vía CSS)
            cell.appendChild(dz);
        }
    }

    function dclViewClearDropZones(container) {
        _dclDzActive = false;
        container.classList.remove('dcl-view-dragging');
        var dzs = container.querySelectorAll('.dcl-view-dz');
        for (var i = 0; i < dzs.length; i++) if (dzs[i].parentNode) dzs[i].parentNode.removeChild(dzs[i]);
    }

    // Encuentra la drop-zone más cercana al target del evento
    function dclViewClosestDz(node, container) {
        while (node && node !== container) {
            if (node.classList && node.classList.contains('dcl-view-dz')) return node;
            // si el cursor está sobre una celda que tiene DZ, devolver su DZ
            if (node.classList && (node.classList.contains('dcl-section') || node.classList.contains('dcl-sec-hole'))) {
                var dz = node.querySelector(':scope > .dcl-view-dz');
                if (dz) return dz;
            }
            node = node.parentNode;
        }
        return null;
    }

    // Sube por el DOM hasta la .dcl-section más cercana dentro del container
    function dclClosestSection(node, container) {
        while (node && node !== container) {
            if (node.classList && node.classList.contains('dcl-section') &&
                node.getAttribute('data-section')) return node;
            node = node.parentNode;
        }
        return null;
    }

    // Intercambia dos nodos (sección/hueco) en el DOM usando un marcador temporal
    function dclViewSwap(a, b) {
        if (a === b) return;
        var marker = document.createComment('dcl-swap');
        a.parentNode.insertBefore(marker, a);
        b.parentNode.insertBefore(a, b);
        if (marker.parentNode) marker.parentNode.insertBefore(b, marker);
        if (marker.parentNode) marker.parentNode.removeChild(marker);
    }

    // Mueve `sec` a la posición del `hole`, dejando un hueco nuevo donde estaba sec
    function dclViewMoveToHole(sec, hole) {
        var newHole = document.createElement('div');
        newHole.className = 'dcl-sec-hole';
        sec.parentNode.insertBefore(newHole, sec);
        hole.parentNode.insertBefore(sec, hole);
        if (hole.parentNode) hole.parentNode.removeChild(hole);
    }

    // Reconstruye cfg.rows leyendo el DOM actual de la vista (#dcl-content)
    // Lee el span (nº de columnas que ocupa) de una celda desde su grid-column
    function dclCellSpan(cell) {
        var gc = cell.style.gridColumn || '';
        var m = gc.match(/span\s+(\d+)/);
        return m ? Math.max(1, parseInt(m[1], 10)) : 1;
    }

    function dclSaveRowsFromView() {
        var container = document.getElementById('dcl-content');
        if (!container) return;
        var cfg = dclGetCfg();
        var rowEls = container.querySelectorAll('.dcl-sec-row');
        var rows = [];
        for (var r = 0; r < rowEls.length; r++) {
            var cells = rowEls[r].children;
            var slots = [];
            var cols = 0;
            for (var c = 0; c < cells.length; c++) {
                var cell = cells[c];
                if (cell.classList && cell.classList.contains('dcl-view-dz')) continue; // ignorar overlays
                var span = dclCellSpan(cell);
                cols += span;
                if (cell.classList && cell.classList.contains('dcl-section')) {
                    var sid = cell.getAttribute('data-section');
                    slots.push(span > 1 ? { sec: sid, span: span } : sid);
                } else if (cell.classList && cell.classList.contains('dcl-sec-hole')) {
                    slots.push(span > 1 ? { sec: null, span: span } : null);
                }
            }
            if (slots.length) rows.push({ cols: Math.max(cols, 1), slots: slots });
        }
        if (rows.length) {
            cfg.rows = rows;
            dclSaveCfg(cfg);
            if (dclGetActiveLayoutName() && dclGetActiveLayoutName() !== 'Personalizado') {
                dclSetActiveLayoutName('Personalizado');
            }
        }
    }

    // ── Ordenamiento de columnas de tabla ────────────────────────────────
    function dclInitTableSorting() {
        var tables = document.querySelectorAll('.dcl-table');
        for (var t = 0; t < tables.length; t++) {
            (function (table) {
                var ths = table.querySelectorAll('thead th');
                for (var h = 0; h < ths.length; h++) {
                    (function (th) {
                        th.title = 'Click para ordenar';
                        th.addEventListener('click', function () {
                            // Índice dinámico para soportar reordenamiento previo de columnas
                            var allThs = table.querySelectorAll('thead th');
                            var ci = 0;
                            for (var k = 0; k < allThs.length; k++) { if (allThs[k] === th) { ci = k; break; } }
                            dclSortTable(table, ci, th);
                        });
                    })(ths[h]);
                }
            })(tables[t]);
        }
    }

    function dclSortTable(table, colIdx, th) {
        var tbody = table.querySelector('tbody');
        if (!tbody) return;
        var staticRows = Array.prototype.slice.call(tbody.querySelectorAll('tr.dcl-total-row, tr.dcl-stats-row'));
        var dataRows = Array.prototype.slice.call(tbody.querySelectorAll('tr:not(.dcl-total-row):not(.dcl-stats-row)'));
        var asc = th.getAttribute('data-sort') !== 'asc';
        th.setAttribute('data-sort', asc ? 'asc' : 'desc');
        var allThs = table.querySelectorAll('thead th');
        for (var i = 0; i < allThs.length; i++) {
            if (allThs[i] !== th) { allThs[i].removeAttribute('data-sort'); allThs[i].innerHTML = allThs[i].innerHTML.replace(/ [▲▼]$/, ''); }
        }
        dataRows.sort(function (a, b) {
            var ac = a.querySelectorAll('td')[colIdx];
            var bc = b.querySelectorAll('td')[colIdx];
            if (!ac || !bc) return 0;
            var av = parseFloat(ac.textContent.replace(/[^0-9.\-]/g, ''));
            var bv = parseFloat(bc.textContent.replace(/[^0-9.\-]/g, ''));
            if (!isNaN(av) && !isNaN(bv)) return asc ? av - bv : bv - av;
            var as2 = ac.textContent.trim().toLowerCase();
            var bs2 = bc.textContent.trim().toLowerCase();
            return asc ? as2.localeCompare(bs2) : bs2.localeCompare(as2);
        });
        for (var i = 0; i < dataRows.length; i++) tbody.appendChild(dataRows[i]);
        for (var i = 0; i < staticRows.length; i++) tbody.appendChild(staticRows[i]);
        th.innerHTML = th.innerHTML.replace(/ [▲▼]$/, '') + (asc ? ' ▲' : ' ▼');
    }

    // ── Filtro de filas en tabla ─────────────────────────────────────────
    function dclInitTableFilters() {
        var wraps = document.querySelectorAll('.dcl-table-wrap');
        for (var i = 0; i < wraps.length; i++) {
            (function (wrap) {
                if (wrap.querySelector('.dcl-table-search')) return;
                var inp = document.createElement('input');
                inp.type = 'text'; inp.placeholder = 'Filtrar filas...'; inp.className = 'dcl-table-search';
                inp.addEventListener('input', function () {
                    var q = inp.value.toLowerCase();
                    var tbl = wrap.querySelector('.dcl-table');
                    if (!tbl) return;
                    var rows = tbl.querySelectorAll('tbody tr:not(.dcl-total-row):not(.dcl-stats-row)');
                    for (var j = 0; j < rows.length; j++) {
                        rows[j].style.display = rows[j].textContent.toLowerCase().indexOf(q) >= 0 ? '' : 'none';
                    }
                });
                wrap.insertBefore(inp, wrap.firstChild);
            })(wraps[i]);
        }
    }

    // ── Drag & drop de columnas (índice DINÁMICO) ────────────────────────
    var _dclColSrc = null;
    var _dclColTable = null;

    function dclInitColumnDnD() {
        var tables = document.querySelectorAll('.dcl-table');
        for (var t = 0; t < tables.length; t++) {
            (function (table, tblIdx) {
                table.setAttribute('data-tbl-id', 'tbl_' + tblIdx);
                var ths = table.querySelectorAll('thead th');
                for (var h = 0; h < ths.length; h++) {
                    (function (th) {
                        th.setAttribute('draggable', 'true');
                        th.addEventListener('dragstart', function (e) {
                            e.stopPropagation();
                            // ← ÍNDICE DINÁMICO: buscar posición actual del th en el DOM
                            _dclColSrc = _dclThIndex(table, th);
                            _dclColTable = table;
                        });
                        th.addEventListener('dragover', function (e) {
                            e.preventDefault(); e.stopPropagation();
                            if (_dclColTable === table) th.classList.add('dcl-col-drag-over');
                        });
                        th.addEventListener('dragleave', function () { th.classList.remove('dcl-col-drag-over'); });
                        th.addEventListener('drop', function (e) {
                            e.preventDefault(); e.stopPropagation();
                            th.classList.remove('dcl-col-drag-over');
                            // ← ÍNDICE DINÁMICO: posición actual del th destino
                            var tgtIdx = _dclThIndex(table, th);
                            if (_dclColTable === table && _dclColSrc !== null && _dclColSrc !== tgtIdx) {
                                dclMoveColumn(table, _dclColSrc, tgtIdx);
                                dclSaveColumnOrder(table);
                            }
                            _dclColSrc = null; _dclColTable = null;
                        });
                    })(ths[h]);
                }
            })(tables[t], t);
        }
    }

    // Devuelve la posición actual (DOM) del th en thead
    function _dclThIndex(table, th) {
        var ths = table.querySelectorAll('thead th');
        for (var k = 0; k < ths.length; k++) { if (ths[k] === th) return k; }
        return 0;
    }

    function dclMoveColumn(table, from, to) {
        var rows = table.querySelectorAll('tr');
        for (var i = 0; i < rows.length; i++) {
            var cells = Array.prototype.slice.call(rows[i].children);
            if (!cells[from] || !cells[to]) continue;
            if (from < to) rows[i].insertBefore(cells[from], cells[to].nextSibling || null);
            else rows[i].insertBefore(cells[from], cells[to]);
        }
    }

    function dclSaveColumnOrder(table) {
        var cfg = dclGetCfg();
        var tblId = table.getAttribute('data-tbl-id');
        var ths = table.querySelectorAll('thead th');
        var order = [];
        for (var i = 0; i < ths.length; i++) order.push(ths[i].textContent.trim().replace(/ [▲▼]$/, ''));
        if (!cfg.colOrders) cfg.colOrders = {};
        cfg.colOrders[tblId] = order;
        dclSaveCfg(cfg);
    }

    function dclApplyColumnOrders() {
        var cfg = dclGetCfg();
        if (!cfg.colOrders) return;
        var tables = document.querySelectorAll('.dcl-table[data-tbl-id]');
        for (var t = 0; t < tables.length; t++) {
            var table = tables[t];
            var tblId = table.getAttribute('data-tbl-id');
            var desired = cfg.colOrders[tblId];
            if (!desired) continue;
            var ths = table.querySelectorAll('thead th');
            var current = [];
            for (var i = 0; i < ths.length; i++) current.push(ths[i].textContent.trim().replace(/ [▲▼]$/, ''));
            for (var d = 0; d < desired.length; d++) {
                var cur = current.indexOf(desired[d]);
                if (cur !== -1 && cur !== d) {
                    dclMoveColumn(table, cur, d);
                    var moved = current.splice(cur, 1)[0];
                    current.splice(d, 0, moved);
                }
            }
        }
    }

    // ── Fila de estadísticas ─────────────────────────────────────────────
    function dclInitStatsRows() {
        var tables = document.querySelectorAll('.dcl-table');
        for (var t = 0; t < tables.length; t++) {
            var table = tables[t];
            var tbody = table.querySelector('tbody');
            if (!tbody) continue;
            var ths = table.querySelectorAll('thead th');
            var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr:not(.dcl-total-row):not(.dcl-stats-row)'));
            if (rows.length < 2) continue;
            var hasNum = false;
            var tr = document.createElement('tr'); tr.className = 'dcl-stats-row';
            for (var c = 0; c < ths.length; c++) {
                var td = document.createElement('td');
                var vals = [];
                for (var r = 0; r < rows.length; r++) {
                    var cell = rows[r].querySelectorAll('td')[c];
                    var num = cell ? parseFloat(cell.textContent.replace(/[^0-9.\-]/g, '')) : NaN;
                    if (!isNaN(num)) vals.push(num);
                }
                if (vals.length > 1) {
                    var sum = 0; for (var v = 0; v < vals.length; v++) sum += vals[v];
                    var avg = sum / vals.length;
                    var sorted = vals.slice().sort(function (a, b) { return a - b; });
                    var mid = Math.floor(sorted.length / 2);
                    var med = sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
                    td.innerHTML = '<span class="dcl-stat" title="Promedio">Ø ' + avg.toFixed(1) + '</span>'
                        + '<span class="dcl-stat" title="Mediana">⨁ ' + med.toFixed(1) + '</span>';
                    td.className = 'text-center'; hasNum = true;
                } else if (c === 0) { td.innerHTML = '<small style="color:#bbb">estadísticas</small>'; }
                tr.appendChild(td);
            }
            if (hasNum) tbody.appendChild(tr);
        }
    }

    // ── KPI cards – drag & drop dentro del row ───────────────────────────
    function dclApplyKpiOrder() {
        var cfg = dclGetCfg();
        if (!cfg.kpiOrder || !cfg.kpiOrder.length) return;
        var row = document.getElementById('dcl-kpi-row');
        if (!row) return;
        var order = cfg.kpiOrder;
        for (var i = 0; i < order.length; i++) {
            var card = row.querySelector('.dcl-kpi-card[data-kpi-id="' + order[i] + '"]');
            if (card) row.appendChild(card);
        }
    }

    function dclSaveKpiOrder() {
        var row = document.getElementById('dcl-kpi-row');
        if (!row) return;
        var cards = row.querySelectorAll('.dcl-kpi-card');
        var order = [];
        for (var i = 0; i < cards.length; i++) {
            var id = cards[i].getAttribute('data-kpi-id');
            if (id) order.push(id);
        }
        var cfg = dclGetCfg();
        cfg.kpiOrder = order;
        dclSaveCfg(cfg);
    }

    function dclInitKpiDnD() {
        var row = document.getElementById('dcl-kpi-row');
        if (!row) return;
        var dragging = null;
        var lastTarget = null;
        var lastSide = '';

        function kpiCardOf(el) {
            while (el && el !== row) {
                if (el.classList && el.classList.contains('dcl-kpi-card')) return el;
                el = el.parentNode;
            }
            return null;
        }
        function clearOvers() {
            var overs = row.querySelectorAll('.dcl-kpi-drag-over');
            for (var j = 0; j < overs.length; j++) overs[j].classList.remove('dcl-kpi-drag-over');
        }

        // dragstart / dragend en cada card (necesitan el elemento concreto)
        var cards = row.querySelectorAll('.dcl-kpi-card');
        for (var i = 0; i < cards.length; i++) {
            cards[i].addEventListener('dragstart', function (e) {
                e.stopPropagation(); // impide que el dragstart de la sección padre llame e.preventDefault()
                dragging = this;
                lastTarget = null;
                lastSide = '';
                e.dataTransfer.effectAllowed = 'move';
                var me = this;
                setTimeout(function () { me.classList.add('dcl-kpi-dragging'); }, 0);
            });
            cards[i].addEventListener('dragend', function () {
                this.classList.remove('dcl-kpi-dragging');
                clearOvers();
                dragging = null;
                lastTarget = null;
                lastSide = '';
                dclSaveKpiOrder();
            });
        }

        // dragover delegado en el contenedor — evita el problema de dragleave
        // al hacer insertBefore y previene oscilaciones con throttle por target+side
        row.addEventListener('dragover', function (e) {
            e.preventDefault();
            if (!dragging) return;
            e.dataTransfer.dropEffect = 'move';

            var target = kpiCardOf(e.target);
            if (!target || target === dragging) return;

            var rect = target.getBoundingClientRect();
            var side = (e.clientX < rect.left + rect.width / 2) ? 'before' : 'after';

            // Throttle: no hacer nada si target+side no cambió
            if (target === lastTarget && side === lastSide) return;
            lastTarget = target;
            lastSide = side;

            clearOvers();
            target.classList.add('dcl-kpi-drag-over');

            if (side === 'before') {
                row.insertBefore(dragging, target);
            } else {
                row.insertBefore(dragging, target.nextSibling);
            }
        });

        row.addEventListener('drop', function (e) {
            e.preventDefault();
            clearOvers();
        });
    }

    // ── Pie chart interactivo — filtrar + animar SVG ─────────────────────
    function dclFiltrarEstado(estado) {
        // Toggle: si se hace click en el mismo segmento, resetear
        if (estado && estado === _dclEstadoActivo) estado = '';
        _dclEstadoActivo = estado;

        var segs = document.querySelectorAll('.dcl-pie-seg');
        var valEl = document.getElementById('dcl-pie-val');
        var subEl = document.getElementById('dcl-pie-sub');

        // 1. Animar segmentos SVG
        for (var i = 0; i < segs.length; i++) {
            var seg = segs[i];
            var isMe = (!estado || seg.getAttribute('data-estado') === estado);
            if (!estado) {
                seg.style.transform = '';
                seg.style.opacity = '1';
                seg.style.filter = '';
            } else if (isMe) {
                var px = parseFloat(seg.getAttribute('data-pull-x') || '0');
                var py = parseFloat(seg.getAttribute('data-pull-y') || '0');
                seg.style.transform = 'translate(' + px + 'px,' + py + 'px)';
                seg.style.opacity = '1';
                seg.style.filter = 'drop-shadow(0 3px 8px rgba(0,0,0,.3))';
            } else {
                seg.style.transform = '';
                seg.style.opacity = '.22';
                seg.style.filter = '';
            }
        }

        // 2. Actualizar texto central del gráfico.
        //    subEl tiene 2 <tspan> (línea1 = 'cumplimiento', línea2 = 'x/y finaliz.').
        //    Para no destruirlos, actualizamos cada tspan por separado.
        if (valEl && subEl) {
            var sub1 = subEl.querySelector('tspan:nth-child(1)');
            var sub2 = subEl.querySelector('tspan:nth-child(2)');
            if (!estado) {
                // Reset: volver al % de cumplimiento global (guardado en data-base),
                // no al % del segmento "finalizado" (que no existe si es 0).
                valEl.textContent = (valEl.getAttribute('data-base') || valEl.textContent);
                if (sub1) sub1.textContent = 'cumplimiento';
                if (sub2) sub2.style.display = '';   // mostrar detalle (x/y finaliz.)
            } else {
                var selSeg = document.querySelector('.dcl-pie-seg[data-estado="' + estado + '"]');
                if (selSeg) {
                    valEl.textContent = selSeg.getAttribute('data-val');
                    if (sub1) sub1.textContent = selSeg.getAttribute('data-lbl');
                    if (sub2) sub2.style.display = 'none';  // ocultar detalle al filtrar
                }
            }
        }

        // 3. Dim/undim filas de detalle
        var rows = document.querySelectorAll('.dcl-det-row');
        for (var i = 0; i < rows.length; i++) {
            var pct = parseFloat(rows[i].getAttribute('data-pct') || '100');
            if (!estado) {
                rows[i].classList.remove('dcl-row-dim');
            } else if (estado === 'finalizado') {
                rows[i].classList.toggle('dcl-row-dim', pct < 99.9);
            } else if (estado === 'pendiente') {
                rows[i].classList.toggle('dcl-row-dim', pct >= 99.9);
            } else {
                rows[i].classList.remove('dcl-row-dim');
            }
        }

        // 4. Highlight en leyenda
        var items = document.querySelectorAll('.dcl-legend-item');
        for (var i = 0; i < items.length; i++) {
            items[i].classList.toggle('dcl-legend-active', !!estado && items[i].getAttribute('data-estado') === estado);
        }
    }

    // El filtro visual por instalación (atenuar otras tablas al clickear una
    // fila) se retiró: ese gesto ahora navega al dashboard de la instalación,
    // que entrega la misma información ya acotada.

    // ── Drill-down entre niveles (General → Instalación → Zona) ──────────
    // SIN postback: se actualizan los hidden fields y se re-renderiza
    // #dcl-content con el mismo endpoint AJAX del auto-refresh, que ya sabe
    // devolver el set de widgets del nivel pedido. Así la navegación es fluida
    // y no se pierde el scroll ni el estado del builder.
    // ── Sincronización de los combos Telerik con el nivel actual ─────────
    // El drill-down no hace postback, así que los combos quedarían mostrando la
    // selección anterior. Además de ser confuso, rompe el flujo: al pulsar
    // "Buscar" el servidor lee los combos y volvería a la vista General.
    function dclCboFind(clientId) {
        if (!clientId || typeof $find !== 'function') return null;
        try { return $find(clientId); } catch (e) { return null; }
    }
    // Selección PROGRAMÁTICA. Doble resguardo: se apaga el autopostback (por si
    // el markup quedara con AutoPostBack) y se marca _dclCboSync para que el
    // handler OnClientSelectedIndexChanged no interprete esto como un cambio del
    // usuario y dispare otra recarga en cascada.
    function dclCboSelectValue(combo, valor) {
        if (!combo) return false;
        var apb = null, ok = false, prevSync = _dclCboSync;
        _dclCboSync = true;
        try {
            if (combo.get_autoPostBack) { apb = combo.get_autoPostBack(); combo.set_autoPostBack(false); }
            var item = combo.findItemByValue(String(valor));
            if (item) { item.select(); ok = true; }
            else { combo.clearSelection(); }
        } catch (e) {
            ok = false;
        } finally {
            try { if (apb !== null && combo.set_autoPostBack) combo.set_autoPostBack(apb); } catch (e2) { }
            _dclCboSync = prevSync;
        }
        return ok;
    }
    // Repuebla el combo de zonas de una instalación y selecciona una (opcional).
    function dclCargarComboZonas(cinId, seleccionarCizId) {
        var combo = dclCboFind(window._dclCboZona);
        if (!combo || typeof window._dclWsZonasUrl === 'undefined') return;
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', window._dclWsZonasUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 || xhr.status !== 200) return;
                try {
                    var resp = JSON.parse(xhr.responseText);
                    var lista = resp.d !== undefined ? resp.d : resp;
                    if (!lista) return;
                    combo.trackChanges();
                    combo.get_items().clear();
                    var todas = new Telerik.Web.UI.RadComboBoxItem();
                    todas.set_text('Todas'); todas.set_value('0');
                    combo.get_items().add(todas);
                    for (var i = 0; i < lista.length; i++) {
                        var it = new Telerik.Web.UI.RadComboBoxItem();
                        it.set_text(lista[i].nombre); it.set_value(String(lista[i].id));
                        combo.get_items().add(it);
                    }
                    combo.commitChanges();
                    try { combo.enable(); } catch (e2) { }
                    dclCboSelectValue(combo, seleccionarCizId || 0);
                } catch (e) { }
            };
            xhr.send(JSON.stringify({ instalacion: cinId || 0 }));
        } catch (e) { }
    }
    // ── Filtros sin postback ──────────────────────────────────────────────
    // Los combos ya no son AutoPostBack: el cascadeo y la recarga los maneja el
    // cliente. _dclCboSync evita que la selección PROGRAMÁTICA (al sincronizar
    // tras un drill) dispare los handlers y provoque recargas en cadena.
    var _dclCboSync = false;

    function dclHf(id, valor) {
        var hf = document.getElementById(id);
        if (hf && valor !== undefined) hf.value = valor;
        return hf ? hf.value : '';
    }
    function dclCboTexto(combo) {
        try { var it = combo.get_selectedItem(); return it ? it.get_text() : ''; } catch (e) { return ''; }
    }
    function dclCboValor(combo) {
        try { var it = combo.get_selectedItem(); return it ? (parseInt(it.get_value(), 10) || 0) : 0; } catch (e) { return 0; }
    }

    // Repuebla un combo Telerik con [{id,nombre}] + opción "todos".
    function dclCboLlenar(combo, lista, textoTodos, seleccionar) {
        if (!combo) return;
        try {
            combo.trackChanges();
            combo.get_items().clear();
            var todos = new Telerik.Web.UI.RadComboBoxItem();
            todos.set_text(textoTodos); todos.set_value('0');
            combo.get_items().add(todos);
            for (var i = 0; i < (lista || []).length; i++) {
                var it = new Telerik.Web.UI.RadComboBoxItem();
                it.set_text(lista[i].nombre); it.set_value(String(lista[i].id));
                combo.get_items().add(it);
            }
            combo.commitChanges();
            try { combo.enable(); } catch (e2) { }
            dclCboSelectValue(combo, seleccionar || 0);
        } catch (e) { }
    }

    function dclCargarComboInstalaciones(cliId, seleccionar, onListo) {
        var combo = dclCboFind(window._dclCboInstalacion);
        if (!combo || typeof window._dclWsInstalUrl === 'undefined') { if (onListo) onListo(); return; }
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', window._dclWsInstalUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) return;
                var lista = [];
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        lista = (resp.d !== undefined ? resp.d : resp) || [];
                    } catch (e) { lista = []; }
                }
                _dclCboSync = true;
                dclCboLlenar(combo, lista, 'Todas', seleccionar);
                _dclCboSync = false;
                if (onListo) onListo();
            };
            xhr.send(JSON.stringify({ cliente: cliId || 0 }));
        } catch (e) { if (onListo) onListo(); }
    }

    // Cliente → reinicia instalación/zona y vuelve al nivel General.
    function dclOnClienteChanged() {
        if (_dclCboSync) return;
        var cli = dclCboValor(dclCboFind(window._dclCboCliente));
        dclHf('hfCliente', cli);
        dclHf('hfInstalacion', 0);
        dclHf('hfZona', 0);
        dclHf('hfNivel', 'general');
        dclHf('hfNomIns', '');
        dclHf('hfNomZona', '');

        var cboZon = dclCboFind(window._dclCboZona);
        _dclCboSync = true;
        dclCboLlenar(cboZon, [], 'Todas', 0);
        try { cboZon.disable(); } catch (e) { }
        _dclCboSync = false;

        dclCargarComboInstalaciones(cli, 0, function () {
            dclRenderBreadcrumb();
            dclAutoRefreshAjax(true);
        });
    }

    // Instalación → nivel Instalación (o General si eligió "Todas").
    function dclOnInstalacionChanged() {
        if (_dclCboSync) return;
        var combo = dclCboFind(window._dclCboInstalacion);
        var cin   = dclCboValor(combo);
        dclHf('hfInstalacion', cin);
        dclHf('hfZona', 0);
        dclHf('hfNomZona', '');
        dclHf('hfNomIns', cin > 0 ? dclCboTexto(combo) : '');
        dclHf('hfNivel', cin > 0 ? 'instalacion' : 'general');

        dclCargarComboZonas(cin, 0);
        dclRenderBreadcrumb();
        dclAutoRefreshAjax(true);
    }

    // Zona → nivel Zona (o vuelve a Instalación si eligió "Todas").
    function dclOnZonaChanged() {
        if (_dclCboSync) return;
        var combo = dclCboFind(window._dclCboZona);
        var ciz   = dclCboValor(combo);
        var cin   = parseInt(dclHf('hfInstalacion'), 10) || 0;
        dclHf('hfZona', ciz);
        dclHf('hfNomZona', ciz > 0 ? dclCboTexto(combo) : '');
        dclHf('hfNivel', ciz > 0 ? 'zona' : (cin > 0 ? 'instalacion' : 'general'));

        dclRenderBreadcrumb();
        dclAutoRefreshAjax(true);
    }

    // Buscar / Limpiar: devuelven false para cancelar el postback del control.
    function dclBuscarAjax() {
        dclSyncFechasHidden();
        dclAutoRefreshAjax(true);
        return false;
    }
    function dclLimpiarAjax() {
        _dclCboSync = true;
        dclCboSelectValue(dclCboFind(window._dclCboCliente), 0);
        dclCboSelectValue(dclCboFind(window._dclCboInstalacion), 0);
        var cboZon = dclCboFind(window._dclCboZona);
        dclCboLlenar(cboZon, [], 'Todas', 0);
        try { cboZon.disable(); } catch (e) { }
        _dclCboSync = false;

        dclHf('hfCliente', 0); dclHf('hfInstalacion', 0); dclHf('hfZona', 0);
        dclHf('hfNivel', 'general'); dclHf('hfNomIns', ''); dclHf('hfNomZona', '');

        dclCargarComboInstalaciones(0, 0, function () {
            dclRenderBreadcrumb();
            dclAutoRefreshAjax(true);
        });
        return false;
    }

    // Deja los 3 combos reflejando el nivel al que se navegó.
    function dclSyncCombos(nivel, cinId, cizId, cliId) {
        var cboIns = dclCboFind(window._dclCboInstalacion);
        var cboZon = dclCboFind(window._dclCboZona);
        var cboCli = dclCboFind(window._dclCboCliente);

        // Si se vena sin cliente elegido ("Todos"), al entrar a una instalación
        // hay que fijar SU cliente y recargar el combo de instalaciones con las
        // de ese cliente: si no, quedaba el listado completo y la instalación
        // seleccionada no correspondía al cliente mostrado.
        var cliPrevio = parseInt(dclHf('hfCliente'), 10) || 0;
        if (cboCli && cliId) {
            dclCboSelectValue(cboCli, cliId);
            dclHf('hfCliente', cliId);

            if (cliId !== cliPrevio && nivel !== 'general') {
                dclCargarComboInstalaciones(cliId, cinId || 0, function () {
                    var obj = (nivel === 'zona') ? (cizId || 0) : 0;
                    dclCargarComboZonas(cinId, obj);
                });
                return;   // el resto lo resuelve el callback ya con la lista correcta
            }
        }

        if (nivel === 'general') {
            dclCboSelectValue(cboIns, 0);
            if (cboZon) {
                try {
                    cboZon.trackChanges(); cboZon.get_items().clear();
                    var t = new Telerik.Web.UI.RadComboBoxItem();
                    t.set_text('Todas'); t.set_value('0');
                    cboZon.get_items().add(t); cboZon.commitChanges();
                    cboZon.set_text('Todas'); cboZon.disable();
                } catch (e) { }
            }
            return;
        }

        dclCboSelectValue(cboIns, cinId || 0);

        // Las zonas dependen de la instalación. Si el combo YA tiene la zona
        // (caso típico: drill instalación → zona, donde el combo se cargó al
        // entrar a la instalación), se selecciona directo: reconstruirlo por
        // AJAX dejaba la selección a merced de la respuesta y a veces no
        // alcanzaba a aplicarse. Solo se va al servidor si la zona no está.
        var objetivo = (nivel === 'zona') ? (cizId || 0) : 0;
        if (cboZon && objetivo > 0 && dclCboSelectValue(cboZon, objetivo)) {
            try { cboZon.enable(); } catch (e) { }
            return;
        }
        dclCargarComboZonas(cinId, objetivo);
    }

    function dclSetNivel(nivel, cinId, cizId, nomIns, nomZona, cliId) {
        var hfI = document.getElementById('hfInstalacion');
        var hfZ = document.getElementById('hfZona');
        var hfN = document.getElementById('hfNivel');
        var hI = document.getElementById('hfNomIns');
        var hZ = document.getElementById('hfNomZona');

        if (hfI) hfI.value = cinId || 0;
        if (hfZ) hfZ.value = cizId || 0;
        if (hfN) hfN.value = nivel;
        if (hI && typeof nomIns === 'string') hI.value = nomIns;
        if (hZ && typeof nomZona === 'string') hZ.value = nomZona;

        // Las fechas del drill son las que el usuario tiene puestas en los
        // calendarios, no las del último postback: sin esto se navegaba con el
        // rango viejo y el dashboard de instalación mostraba otro período.
        dclSyncFechasHidden();
        dclSyncCombos(nivel, cinId, cizId, cliId);

        dclRenderBreadcrumb();
        dclAutoRefreshAjax(true);   // true = navegación explícita, muestra "Cargando…"
    }

    // Copia el valor visible de los calendarios a los hidden que viajan al WS.
    // Se busca dentro del wrapper de cada calendario (#dcl-grp-desde/hasta): los
    // combos Telerik también renderizan input[type=text], así que un selector
    // genérico tomaría el input de búsqueda del combo en vez de la fecha.
    function dclFechaDeGrupo(grpId) {
        var grp = document.getElementById(grpId);
        if (!grp) return '';
        var inp = grp.querySelector('input[type=text]');
        return inp ? (inp.value || '') : '';
    }
    function dclSyncFechasHidden() {
        var hfD = document.getElementById('hfDesde');
        var hfH = document.getElementById('hfHasta');
        var d = dclFechaDeGrupo('dcl-grp-desde');
        var h = dclFechaDeGrupo('dcl-grp-hasta');
        if (hfD && d) hfD.value = d;
        if (hfH && h) hfH.value = h;
    }

    function dclDrillInstalacion(cinId, nomIns, cliId) {
        if (!cinId) return;
        dclSetNivel('instalacion', cinId, 0, nomIns || '', '', cliId);
    }
    function dclDrillZona(cizId, nomZona) {
        if (!cizId) return;
        var hfI = document.getElementById('hfInstalacion');
        var hI = document.getElementById('hfNomIns');
        dclSetNivel('zona', hfI ? (parseInt(hfI.value, 10) || 0) : 0, cizId,
            hI ? hI.value : '', nomZona || '');
    }
    function dclDrillUp(nivel) {
        if (nivel === 'instalacion') {
            var hfI = document.getElementById('hfInstalacion');
            var hI = document.getElementById('hfNomIns');
            dclSetNivel('instalacion', hfI ? (parseInt(hfI.value, 10) || 0) : 0, 0,
                hI ? hI.value : '', '');
        } else {
            dclSetNivel('general', 0, 0, '', '');
        }
    }

    // Ruta de navegación. Se arma en cliente (no en el servidor) porque el
    // drill-down ya no pasa por postback.
    function dclRenderBreadcrumb() {
        var cont = document.getElementById('dcl-breadcrumb');
        if (!cont) return;

        var nivel = dclNivelActual();
        if (nivel === 'general') { cont.innerHTML = ''; return; }

        var hI = document.getElementById('hfNomIns');
        var hZ = document.getElementById('hfNomZona');
        var nomIns = (hI && hI.value) ? hI.value : 'Instalación';
        var nomZona = (hZ && hZ.value) ? hZ.value : 'Zona';

        var h = "<div class='dcl-crumb'>" +
                "<button type='button' class='dcl-crumb-lnk' onclick=\"dclDrillUp('general')\">General</button>" +
                "<i class='mdi mdi-chevron-right dcl-crumb-sep'></i>";

        if (nivel === 'zona') {
            h += "<button type='button' class='dcl-crumb-lnk' onclick=\"dclDrillUp('instalacion')\">" +
                 dclEsc(nomIns) + "</button>" +
                 "<i class='mdi mdi-chevron-right dcl-crumb-sep'></i>" +
                 "<span class='dcl-crumb-cur'>" + dclEsc(nomZona) + "</span>";
        } else {
            h += "<span class='dcl-crumb-cur'>" + dclEsc(nomIns) + "</span>";
        }

        cont.innerHTML = h + "</div>";
    }

    function dclEsc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;')
            .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // ── Detalle de una respuesta (hallazgos) — carga bajo demanda ────────
    // No se precarga: el usuario abre solo unas pocas filas, y traer el detalle
    // de todas engordaría la carga inicial y cada ciclo de auto-refresh.
    var _dclDetCache = {};
    // Detalles abiertos por el usuario. El auto-refresh reemplaza #dcl-content
    // completo, así que sin esto todo dropdown abierto se cerraba solo.
    var _dclDetAbiertos = {};

    function dclToggleRespuesta(btn, ccrId) {
        var cont = document.getElementById('dcl-tl-det-' + ccrId);
        if (!cont) return;

        var abierto = cont.classList.contains('dcl-tl-det--open');
        if (abierto) delete _dclDetAbiertos[ccrId]; else _dclDetAbiertos[ccrId] = 1;
        dclPintarRespuesta(cont, btn, ccrId, !abierto);
    }

    // Reabre los detalles que estaban desplegados antes del refresh.
    function dclRestaurarRespuestasAbiertas() {
        for (var ccrId in _dclDetAbiertos) {
            if (!_dclDetAbiertos.hasOwnProperty(ccrId)) continue;
            var cont = document.getElementById('dcl-tl-det-' + ccrId);
            if (!cont) continue;   // esa respuesta ya no está en el período
            var btn = document.querySelector('.dcl-tl-exp[data-ccr="' + ccrId + '"]');
            dclPintarRespuesta(cont, btn, ccrId, true);
        }
    }

    function dclPintarRespuesta(cont, btn, ccrId, abrir) {
        cont.classList.toggle('dcl-tl-det--open', abrir);
        if (btn) {
            btn.setAttribute('aria-expanded', abrir ? 'true' : 'false');
            var ico = btn.querySelector('i');
            if (ico) ico.className = abrir ? 'mdi mdi-chevron-up' : 'mdi mdi-chevron-down';
        }
        if (!abrir) return;

        if (_dclDetCache[ccrId]) {
            cont.innerHTML = _dclDetCache[ccrId];
            dclCargarThumbs(cont);
            return;
        }

        cont.innerHTML = "<div class='dcl-tl-det-load'><i class='mdi mdi-loading mdi-spin'></i> Cargando detalle…</div>";
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', window._dclWsDetalleUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) return;
                if (xhr.status === 200) {
                    var html = '';
                    try { html = (JSON.parse(xhr.responseText).d) || ''; } catch (e) { html = ''; }
                    if (!html) html = "<p class='dcl-no-data'>Sin detalle de respuestas</p>";
                    _dclDetCache[ccrId] = html;
                    cont.innerHTML = html;
                    dclCargarThumbs(cont);
                } else {
                    // Mostrar el fallo en vez de dejar el panel colgado en "Cargando…"
                    cont.innerHTML = "<p class='dcl-no-data'>No se pudo cargar el detalle.</p>";
                }
            };
            xhr.send(JSON.stringify({ ccrId: ccrId }));
        } catch (e) {
            cont.innerHTML = "<p class='dcl-no-data'>No se pudo cargar el detalle.</p>";
        }
    }

    // ── Miniaturas de adjuntos ────────────────────────────────────────────
    // El HTML del detalle trae solo placeholders con data-arc: los binarios se
    // piden aquí (uno por archivo, cacheados) para no inflar la respuesta del
    // detalle ni, mucho menos, la del dashboard completo.
    var _dclImgCache = {};
    function dclCargarThumbs(cont) {
        if (!cont || typeof window._dclWsImagenUrl === 'undefined') return;
        var thumbs = cont.querySelectorAll('.dcl-thumb[data-arc]');
        for (var i = 0; i < thumbs.length; i++) {
            (function (btn) {
                var arc = btn.getAttribute('data-arc');
                if (!arc || btn.getAttribute('data-cargado') === '1') return;
                btn.setAttribute('data-cargado', '1');

                if (_dclImgCache[arc]) { dclPintarThumb(btn, _dclImgCache[arc]); return; }

                try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('POST', window._dclWsImagenUrl, true);
                    xhr.setRequestHeader('Content-Type', 'application/json');
                    xhr.onreadystatechange = function () {
                        if (xhr.readyState !== 4) return;
                        var d = null;
                        if (xhr.status === 200) {
                            try {
                                var resp = JSON.parse(xhr.responseText);
                                d = resp.d !== undefined ? resp.d : resp;
                            } catch (e) { d = null; }
                        }
                        if (d && d.ok && d.src) { _dclImgCache[arc] = d; dclPintarThumb(btn, d); }
                        else { btn.classList.add('dcl-thumb--err'); btn.title = 'No se pudo cargar la imagen'; }
                    };
                    xhr.send(JSON.stringify({ arcId: parseInt(arc, 10) }));
                } catch (e) { btn.classList.add('dcl-thumb--err'); }
            })(thumbs[i]);
        }
    }
    function dclPintarThumb(btn, d) {
        btn.innerHTML = '';
        var img = document.createElement('img');
        img.src = d.src;
        img.alt = d.nombre || 'Adjunto';
        btn.appendChild(img);
        btn.setAttribute('data-src', d.src);
        btn.setAttribute('data-nombre', d.nombre || '');
    }

    // Lightbox: amplía la miniatura ya cargada (no vuelve a pedirla).
    function dclAbrirImagen(btn) {
        var src = btn.getAttribute('data-src');
        if (!src) return;
        dclCerrarImagen();

        var ov = document.createElement('div');
        ov.id = 'dcl-lightbox';
        ov.className = 'dcl-lightbox';
        ov.innerHTML =
            '<div class="dcl-lightbox-bar">' +
            '<span class="dcl-lightbox-nom">' + dclEsc(btn.getAttribute('data-nombre') || 'Adjunto') + '</span>' +
            '<button type="button" class="dcl-lightbox-close" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<img src="' + src + '" alt="Adjunto" />';
        ov.addEventListener('click', function (e) {
            if (e.target === ov || (e.target.closest && e.target.closest('.dcl-lightbox-close'))) dclCerrarImagen();
        });
        document.body.appendChild(ov);
        requestAnimationFrame(function () { ov.classList.add('dcl-lightbox--open'); });
        document.addEventListener('keydown', _dclLightboxEsc);
    }
    function _dclLightboxEsc(e) { if (e.key === 'Escape' || e.keyCode === 27) dclCerrarImagen(); }
    function dclCerrarImagen() {
        var ov = document.getElementById('dcl-lightbox');
        if (ov && ov.parentNode) ov.parentNode.removeChild(ov);
        document.removeEventListener('keydown', _dclLightboxEsc);
    }

    document.addEventListener('click', function (e) {
        var el = e.target;

        // El click en una fila de instalación ahora NAVEGA al dashboard de esa
        // instalación (onclick inline → dclDrillInstalacion). Antes solo atenuaba
        // las otras tablas; ese filtro visual ya no aplica en el nivel general,
        // porque entrar a la instalación da la misma información mejor acotada.

        // Click en KPI → resetear filtro de estado del pie
        el = e.target;
        while (el && el !== document) {
            if (el.classList && el.classList.contains('dcl-kpi-card')) { dclFiltrarEstado(''); return; }
            el = el.parentNode;
        }
    });

    // ── Gráfico supervisores — filtrar + animar barras ───────────────────
    function dclFiltrarSupervisor(el) {
        var nombre = el.getAttribute ? el.getAttribute('data-sup') : '';
        if (nombre === _dclSupActivo) nombre = '';
        _dclSupActivo = nombre;

        var svg = document.getElementById('dcl-sup-svg');
        if (!svg) return;
        var groups = svg.getElementsByClassName('dcl-sup-bar-grp');
        for (var i = 0; i < groups.length; i++) {
            var grp = groups[i];
            var isMe = !nombre || grp.getAttribute('data-sup') === nombre;
            grp.style.opacity = (!nombre || isMe) ? '1' : '0.18';
            var rects = grp.getElementsByTagName('rect');
            for (var j = 0; j < rects.length; j++)
                rects[j].style.filter = (isMe && nombre) ? 'drop-shadow(0 2px 5px rgba(0,0,0,.28))' : '';
        }
    }

    // ── Builder de layout (modo personalizar) ─────────────────────────────
    function dclGetSectionMeta(sec) {
        var hd = sec.querySelector('.dcl-card-hd');
        if (!hd) return { icon: 'mdi mdi-view-dashboard-outline', name: sec.getAttribute('data-section') || 'Sección' };
        var iconEl = hd.querySelector('i');
        var icon = iconEl ? iconEl.className : 'mdi mdi-view-dashboard-outline';
        var titleEl = hd.querySelector('.dcl-card-title');
        var name = titleEl ? titleEl.textContent.replace(/^[ \s]+|[ \s]+$/g, '') : '';
        if (!name) name = sec.getAttribute('data-section') || 'Sección';
        return { icon: icon, name: name };
    }

    // Registro de metadatos por sección → categoría, color, descripción, nombre e
    // ícono para el builder.
    //
    // nom/ico son OBLIGATORIOS: el builder arma su pool desde este registro, no
    // desde el DOM. Así puede ofrecer los widgets de CUALQUIER categoría —
    // incluidos los que el servidor no renderizó en el nivel actual, que no
    // existen como nodo. Deben coincidir con el BeginCard(...) del Renderer.
    var _DCL_SECTION_REGISTRY = {
        'dcl-kpi': { cat: 'KPI', catClass: 'kpi', nom: 'Indicadores Clave', ico: 'mdi mdi-view-dashboard-outline', desc: 'Indicadores clave de cumplimiento global' },
        'dcl-install': { cat: 'TABLA', catClass: 'table', nom: 'Cumplimiento por Instalación (tabla)', ico: 'mdi mdi-domain', desc: 'Cumplimiento por instalación (tabla detallada)' },
        'dcl-install-bar': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Cumplimiento por Instalación', ico: 'mdi mdi-chart-bar', desc: 'Cumplimiento por instalación (barras, click para entrar)' },
        'dcl-tipo': { cat: 'TABLA', catClass: 'table', nom: 'Cumplimiento por Tipo de Revisión', ico: 'mdi mdi-format-list-checks', desc: 'Revisiones por tipo con historial mensual' },
        'dcl-topN': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Top Pendientes por Instalación', ico: 'mdi mdi-chart-bar-stacked', desc: 'Top instalaciones con más tareas pendientes' },
        'dcl-trend': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Tendencia Mensual de Cumplimiento', ico: 'mdi mdi-chart-line', desc: 'Tendencia de cumplimiento por mes' },
        'dcl-detalle': { cat: 'TABLA', catClass: 'table', nom: 'Tareas Completadas por Instalación y Checklist', ico: 'mdi mdi-clipboard-check-outline', desc: 'Detalle por instalación y checklist' },
        'dcl-pie': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Estado de Checklists', ico: 'mdi mdi-chart-donut', desc: 'Estado de checklists (donut interactivo)' },
        'dcl-ind': { cat: 'TABLA', catClass: 'table', nom: 'Indicadores Generales', ico: 'mdi mdi-poll', desc: 'Indicadores generales con porcentajes' },
        'dcl-tipos': { cat: 'TABLA', catClass: 'table', nom: 'Tipos de Revisión', ico: 'mdi mdi-format-list-checks', desc: 'Tipos de revisión con historial mensual' },
        'dcl-sup-chart': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Checklists por Supervisor', ico: 'mdi mdi-chart-bar', desc: 'Barras de cumplimiento por supervisor' },
        'dcl-sup-table': { cat: 'TABLA', catClass: 'table', nom: 'Cumplimiento por Supervisor', ico: 'mdi mdi-account-check-outline', desc: 'Tabla de cumplimiento por supervisor' },
        'dcl-pend-tipo': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Pendientes por Tipo de Revisión', ico: 'mdi mdi-chart-bar', desc: 'Pendientes por tipo de revisión (barras)' },
        'dcl-tipo-chart': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Cumplimiento por Tipo — Gráfico', ico: 'mdi mdi-chart-bar', desc: 'Cumplimiento por tipo — gauge visual' },
        'dcl-tipo-ins': { cat: 'TABLA', catClass: 'table', nom: 'Pendientes Tipo × Instalación', ico: 'mdi mdi-table-eye', desc: 'Pendientes cruzados: tipo × instalación' },
        'dcl-ctrl-hora': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Top Pendientes — Tipos con Control Hora', ico: 'mdi mdi-clock-alert-outline', desc: 'Top pendientes en tipos con control de hora' },
        // Niveles INSTALACION / ZONA (drill-down)
        'dcl-zonas': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Cumplimiento por Zona', ico: 'mdi mdi-map-marker-radius-outline', desc: 'Cumplimiento por zona (barras, click para entrar)' },
        'dcl-kpi-horario': { cat: 'KPI', catClass: 'kpi', nom: 'Resumen por Modalidad de Horario', ico: 'mdi mdi-timetable', desc: 'Resumen por modalidad de horario: con control y sin control en un solo widget' },
        'dcl-sla': { cat: 'KPI', catClass: 'kpi', nom: 'Tiempo de Respuesta · SLA', ico: 'mdi mdi-timer-sand', desc: 'Tiempo de respuesta (SLA) — solo tipos 1, 2 y 3' },
        'dcl-kpi-ch': { cat: 'KPI', catClass: 'kpi', nom: 'Con Control de Horario', ico: 'mdi mdi-clock-outline', desc: 'Con control de horario: respondido vs esperado' },
        'dcl-kpi-sch': { cat: 'KPI', catClass: 'kpi', nom: 'Sin Control de Horario', ico: 'mdi mdi-timer-off', desc: 'Sin control de horario: actividad del período' },
        'dcl-resp-dia': { cat: 'TABLA', catClass: 'table', nom: 'Respuestas del Día', ico: 'mdi mdi-timeline-clock-outline', desc: 'Respuestas del día con detalle y hallazgos' },
        'dcl-gauge': { cat: 'GRÁFICO', catClass: 'chart', nom: 'Cumplimiento Global', ico: 'mdi mdi-gauge', desc: 'Velocímetro de cumplimiento global con meta configurable' }
    };

    // Metadatos de una sección por id, sin depender de que exista en el DOM.
    function dclSecMetaPorId(secId) {
        var r = _DCL_SECTION_REGISTRY[secId] || {};
        return {
            nom: r.nom || secId,
            ico: r.ico || 'mdi mdi-widgets-outline',
            cat: r.cat || 'SECCIÓN',
            catClass: r.catClass || 'default',
            desc: r.desc || ''
        };
    }

    // Widgets disponibles por nivel de drill-down. El builder y el layout por
    // defecto solo consideran los de su nivel: mostrar "Cumplimiento por Zona"
    // en la vista General (donde no hay instalación elegida) no tendría datos.
    var _DCL_SECTIONS_POR_NIVEL = {
        general:     ['dcl-kpi', 'dcl-gauge', 'dcl-install-bar', 'dcl-install', 'dcl-pie', 'dcl-ind', 'dcl-tipo', 'dcl-tipos',
                      'dcl-pend-tipo', 'dcl-tipo-chart', 'dcl-tipo-ins', 'dcl-sup-chart',
                      'dcl-sup-table', 'dcl-ctrl-hora', 'dcl-topN', 'dcl-detalle', 'dcl-trend'],
        instalacion: ['dcl-kpi', 'dcl-zonas', 'dcl-kpi-horario', 'dcl-sla', 'dcl-kpi-ch', 'dcl-kpi-sch',
                      'dcl-pie', 'dcl-ind', 'dcl-tipo', 'dcl-detalle', 'dcl-trend', 'dcl-sup-table', 'dcl-resp-dia'],
        zona:        ['dcl-kpi', 'dcl-sla', 'dcl-kpi-horario', 'dcl-kpi-ch', 'dcl-kpi-sch', 'dcl-resp-dia',
                      'dcl-ind', 'dcl-detalle']
    };

    function dclNivelActual() {
        var hf = document.getElementById('hfNivel');
        var n = hf ? (hf.value || '') : '';
        return (n === 'zona' || n === 'instalacion') ? n : 'general';
    }

    // ── Categoría de layout ───────────────────────────────────────────────
    // Un layout SIEMPRE pertenece a un nivel: los widgets disponibles cambian
    // entre General / Instalación / Zona, así que un layout de Zona aplicado en
    // General dejaría slots vacíos. La separación ya existía en el storage
    // (dcl_saved_checklists_<nivel>); esto la hace explícita en la interfaz.
    var _DCL_NIVEL_INFO = {
        general:     { lbl: 'Dashboard General', ico: 'mdi-view-dashboard-outline', cls: 'dcl-cat--gen' },
        instalacion: { lbl: 'Por Instalación',   ico: 'mdi-domain',                 cls: 'dcl-cat--ins' },
        zona:        { lbl: 'Por Zona',          ico: 'mdi-map-marker-radius-outline', cls: 'dcl-cat--zon' }
    };
    function dclNivelInfo(nivel) {
        return _DCL_NIVEL_INFO[nivel || dclNivelActual()] || _DCL_NIVEL_INFO.general;
    }
    function dclNivelLabel(nivel) { return dclNivelInfo(nivel).lbl; }
    // Chip de categoría reutilizable (panel de layouts y builder).
    function dclCatChip(nivel, extraCls) {
        var i = dclNivelInfo(nivel);
        return '<span class="dcl-cat-chip ' + i.cls + ' ' + (extraCls || '') + '">' +
               '<i class="mdi ' + i.ico + '"></i>' + dclEsc(i.lbl) + '</span>';
    }

    // Etiquetas y px de altura para cada nivel (0=Auto, 1-4 incrementos)
    var _DCL_H_LBL = ['Auto', 'S', 'M', 'L', 'XL'];
    var _DCL_H_PX = [0, 180, 280, 400, 560];
    var _bldDraggingTile = null; // tile del panel que se está arrastrando al canvas
    var _bldDraggingSection = null; // sección del canvas que se mueve entre columnas
    var _bldNumCols = 1;    // columnas activas en el builder (legado, ya no determina cols global)
    var _presSlides = [];   // grupos de items por slide (modo layout slideshow)
    var _presSlideIdx = 0;    // índice de slide activo
    // nivel opcional: el builder necesita leer los layouts de la CATEGORÍA que
    // se está armando, que puede no ser el nivel en pantalla. Sin argumento
    // sigue resolviendo por el nivel actual, como siempre.
    function _dclSavedKeyFn(nivel) {
        return 'dcl_saved_' + (nivel ? ('checklists_' + nivel) : dclWsModule());
    }

    // Quita wrappers .dcl-sec-row y devuelve las secciones al contenedor raíz
    function dclBldUnwrapRows(container) {
        var rows = container.querySelectorAll('.dcl-sec-row');
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            var secsInRow = row.querySelectorAll('.dcl-section');
            for (var j = 0; j < secsInRow.length; j++) container.appendChild(secsInRow[j]);
            if (row.parentNode) row.parentNode.removeChild(row);
        }
    }

    function dclBldHLabel(n) { return _DCL_H_LBL[Math.max(0, Math.min(n, 4))]; }

    // Canvas del builder dentro del modal full-screen (donde viven las filas)
    function dclBldCanvas() { return document.getElementById('dcl-bld-canvas'); }

    // enBlanco = true → ignora el cfg actual y abre el canvas vacío (crear layout
    // desde cero). Sin esto, "Nuevo layout" arrancaba con el default cargado.
    // layoutId: layout guardado que se está editando; al aplicar/guardar, el
    // resultado se vuelca sobre él (ver dclBldPersistirEnLayout).
    function dclEnterBuilderMode(enBlanco, layoutId) {
        _bldLayoutId = layoutId || null;
        var content = document.getElementById('dcl-content');
        if (!content || document.getElementById('dcl-bld-overlay')) return;

        // 0. El dashboard real NO se toca: el builder trabaja con placeholders,
        //    así que las secciones se quedan montadas y visibles debajo del modal.
        //    El pool sale del registro de la categoría destino, no del DOM.
        _bldNivelDestino = dclNivelActual();
        var idsNivel = dclBldSeccionesDeNivel(_bldNivelDestino);

        // 1. Construir overlay MODAL full-screen: header + (canvas centro | pool derecha)
        var tilesHtml = dclBldBuildTiles(idsNivel);
        var overlay = document.createElement('div');
        overlay.id = 'dcl-bld-overlay';
        overlay.className = 'dcl-bld-overlay';
        overlay.innerHTML =
            '<div class="dcl-bld-modal">' +
            // ── Header ───────────────────────────────────────────────
            '<div class="dcl-bld-modal-hd">' +
            '<span class="dcl-bld-title"><i class="mdi mdi-view-quilt"></i>&nbsp;Armar Dashboard</span>' +
            // El layout que se arma aquí pertenece a ESTA categoría: los widgets
            // ofrecidos son solo los del nivel actual.
            dclCatChip(dclNivelActual(), 'dcl-cat-chip--bld') +
            // Categoría destino: permite armar el layout de General, Instalación
            // o Zona sin importar en qué nivel esté parado el usuario.
            dclBldNivelSelectHtml() +
            // Cargar un layout guardado de esta categoría directamente en el
            // canvas, sin tener que salir del modal, aplicarlo desde Mis Layouts
            // y volver a entrar.
            dclBldLayoutSelectHtml() +
            '<button type="button" class="dcl-bld-help-btn" onclick="dclOnbBuilderStart(true)" ' +
            'title="Ver cómo armar el dashboard"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<span id="dcl-bld-counter" class="dcl-bld-counter">0 / ' + idsNivel.length + '</span>' +
            '<div class="dcl-bld-hd-spacer"></div>' +
            '<button type="button" class="dcl-bld-clear-btn" onclick="dclBldClearCanvas()" title="Vaciar canvas">' +
            '<i class="mdi mdi-refresh"></i>&nbsp;Limpiar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--ghost dcl-bld-apply-btn" onclick="dclBldApplyOnly()" title="Aplicar sin guardar como layout">' +
            '<i class="mdi mdi-check"></i>&nbsp;Aplicar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" onclick="dclBldSaveAndExit()" title="Aplicar y guardar como layout con nombre">' +
            '<i class="mdi mdi-content-save"></i>&nbsp;Guardar como...</button>' +
            '<button type="button" class="dcl-btn dcl-btn--ghost dcl-bld-ghost-btn" onclick="dclExitBuilderMode(false)" title="Cancelar">' +
            '<i class="mdi mdi-close"></i></button>' +
            '</div>' +
            // ── Body: canvas + pool ──────────────────────────────────
            '<div class="dcl-bld-modal-body">' +
            '<div class="dcl-bld-canvas-wrap">' +
            '<div id="dcl-bld-canvas" class="dcl-bld-canvas"></div>' +
            '</div>' +
            '<aside class="dcl-bld-aside">' +
            '<div class="dcl-bld-aside-hd">' +
            '<i class="mdi mdi-widgets-outline"></i>&nbsp;Widgets disponibles' +
            '</div>' +
            // Buscador por texto
            '<div class="dcl-bld-search-wrap">' +
            '<i class="mdi mdi-magnify dcl-bld-search-i"></i>' +
            '<input type="text" id="dcl-bld-search" class="dcl-bld-search" ' +
            'placeholder="Buscar widget..." oninput="dclBldFilterPool()" />' +
            '</div>' +
            // Filtros por tipo (chips)
            '<div class="dcl-bld-filters" id="dcl-bld-filters">' +
            '<button type="button" class="dcl-bld-filter-chip dcl-bld-filter-chip--on" data-cat="all" onclick="dclBldSetFilter(this,\'all\')">Todos</button>' +
            '<button type="button" class="dcl-bld-filter-chip" data-cat="kpi" onclick="dclBldSetFilter(this,\'kpi\')"><i class="mdi mdi-numeric"></i> KPI</button>' +
            '<button type="button" class="dcl-bld-filter-chip" data-cat="chart" onclick="dclBldSetFilter(this,\'chart\')"><i class="mdi mdi-chart-line"></i> Gráfico</button>' +
            '<button type="button" class="dcl-bld-filter-chip" data-cat="table" onclick="dclBldSetFilter(this,\'table\')"><i class="mdi mdi-table"></i> Tabla</button>' +
            '</div>' +
            '<p class="dcl-bld-hint" id="dcl-bld-hint">' +
            '<i class="mdi mdi-gesture-tap-hold"></i>&nbsp;Arrastra un widget a una columna del canvas.' +
            '</p>' +
            '<div id="dcl-bld-pool" class="dcl-bld-pool">' + tilesHtml + '</div>' +
            '<div class="dcl-bld-pool-empty" id="dcl-bld-pool-empty" style="display:none">' +
            '<i class="mdi mdi-magnify-close"></i> Sin widgets que coincidan' +
            '</div>' +
            '</aside>' +
            '</div>' +
            '</div>';
        document.body.appendChild(overlay);

        var canvas = overlay.querySelector('#dcl-bld-canvas');

        // 2. Barra "Agregar fila" (1-4 columnas) al fondo del canvas
        var addBar = document.createElement('div');
        addBar.className = 'dcl-bld-addrow-bar';
        addBar.innerHTML =
            '<span class="dcl-bld-addrow-lbl"><i class="mdi mdi-plus-circle-outline"></i>&nbsp;Agregar fila</span>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(1)" title="1 columna (100%)"><i class="mdi mdi-view-stream"></i>&nbsp;1&nbsp;col</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(2)" title="2 columnas (50% / 50%)"><i class="mdi mdi-view-column"></i>&nbsp;2&nbsp;cols</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(3)" title="3 columnas (33% c/u)"><i class="mdi mdi-view-dashboard"></i>&nbsp;3&nbsp;cols</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(4)" title="4 columnas (25% c/u)"><i class="mdi mdi-view-grid"></i>&nbsp;4&nbsp;cols</button>';
        canvas.appendChild(addBar);

        // 3-4. Reconstruir filas desde cfg.rows y marcar los tiles colocados.
        // La lógica vive en dclBldPintarFilas porque el selector de layouts del
        // header la vuelve a ejecutar cada vez que se elige otro layout.
        var cfg = dclGetCfg();
        dclBldPintarFilas(enBlanco ? [] : dclNormalizeRows(cfg.rows));

        // Miniaturas de los widgets que no están en la página. Va después de
        // pintar: es asíncrono y repinta solo cuando llega la respuesta.
        dclBldCargarPreviews(_bldNivelDestino);

        // 5. Animar apertura
        requestAnimationFrame(function () {
            overlay.classList.add('dcl-bld-overlay--open');
            document.body.classList.add('dcl-building');
            // Tutorial del constructor: solo la primera vez que se abre. Se espera
            // a que termine la animación para medir bien los elementos.
            setTimeout(function () { dclOnbBuilderStart(false); }, 480);
        });

        // 6. Init DnD: el canvas modal es el contenedor de columnas
        dclInitBldPanelDnD(overlay.querySelector('#dcl-bld-pool'));
        dclInitBldColsDnD(canvas);
        dclInitBldColRemove(canvas);

        // 7. Delegación de clicks en el overlay
        overlay.addEventListener('click', function (e) {
            // a) Botón "Ampliar" del preview → modal ampliado
            var b = e.target;
            while (b && b !== overlay && !(b.getAttribute && b.getAttribute('data-expand'))) b = b.parentNode;
            if (b && b !== overlay) {
                e.preventDefault(); e.stopPropagation();
                dclBldExpandPreview(b.getAttribute('data-expand'));
                return;
            }
            // b) Click en el tile (fuera de botones/handle) → toggle preview inline
            var t = e.target;
            // ignorar si el click fue en un control interactivo
            var n = e.target;
            while (n && n !== overlay) {
                if (n.tagName === 'BUTTON' || (n.classList && (n.classList.contains('dcl-bld-drag-i') ||
                    n.classList.contains('dcl-bld-h-grp') || n.classList.contains('dcl-bld-prev-btn')))) return;
                n = n.parentNode;
            }
            while (t && t !== overlay && !(t.classList && t.classList.contains('dcl-bld-tile'))) t = t.parentNode;
            if (t && t.classList && t.classList.contains('dcl-bld-tile') && !t.classList.contains('dcl-bld-tile--placed')) {
                var pbtn = t.querySelector('.dcl-bld-prev-btn');
                if (pbtn) dclBldTogglePreview(pbtn);
            }
        });

        // Filtro inicial (muestra todos)
        dclBldFilterPool();
    }

    // ── Buscador y filtros del pool de widgets ───────────────────────────
    var _dclBldFilterCat = 'all';

    function dclBldSetFilter(btn, cat) {
        _dclBldFilterCat = cat || 'all';
        var chips = document.querySelectorAll('#dcl-bld-filters .dcl-bld-filter-chip');
        for (var i = 0; i < chips.length; i++)
            chips[i].classList.toggle('dcl-bld-filter-chip--on', chips[i] === btn);
        dclBldFilterPool();
    }

    function dclBldFilterPool() {
        var pool = document.getElementById('dcl-bld-pool');
        if (!pool) return;
        var inp = document.getElementById('dcl-bld-search');
        var q = inp ? inp.value.trim().toLowerCase() : '';
        var tiles = pool.querySelectorAll('.dcl-bld-tile');
        var visibles = 0;
        for (var i = 0; i < tiles.length; i++) {
            var t = tiles[i];
            var secId = t.getAttribute('data-section') || '';
            var reg = _DCL_SECTION_REGISTRY[secId] || {};
            var cat = reg.catClass || 'default';
            var nm = t.querySelector('.dcl-bld-sec-nm');
            var desc = t.querySelector('.dcl-bld-tile-desc');
            var text = ((nm ? nm.textContent : '') + ' ' + (desc ? desc.textContent : '')).toLowerCase();
            var okCat = (_dclBldFilterCat === 'all') || (cat === _dclBldFilterCat);
            var okTxt = !q || text.indexOf(q) !== -1;
            var show = okCat && okTxt;
            t.style.display = show ? '' : 'none';
            if (show) visibles++;
        }
        var empty = document.getElementById('dcl-bld-pool-empty');
        if (empty) empty.style.display = visibles ? 'none' : '';
    }

    // Construye el HTML de los tiles del pool de widgets (UI mejorada)
    // Recibe IDS de sección (no nodos): el pool se arma desde el registro, así el
    // builder puede ofrecer widgets de una categoría que el servidor no renderizó.
    function dclBldBuildTiles(ids) {
        var tilesHtml = '';
        var cfgH = dclGetCfg().sectionHeights || {};
        for (var i = 0; i < ids.length; i++) {
            var secId = ids[i];
            var meta = dclSecMetaPorId(secId);
            var h = parseInt(cfgH[secId] || '0', 10) || 0;
            var catLbl = meta.cat;
            var catCls = meta.catClass;
            var desc = meta.desc;
            var nmeta = dclHtmlEsc(meta.nom);
            tilesHtml +=
                '<div class="dcl-bld-tile dcl-bld-cat-' + catCls + '" draggable="true"' +
                ' data-section="' + secId + '" data-width="full" data-height="' + h + '">' +
                // Fila 1: icono + nombre completo (línea propia) + drag handle
                '<div class="dcl-bld-tile-top">' +
                '<span class="dcl-bld-tile-ico"><i class="' + meta.ico + '"></i></span>' +
                '<span class="dcl-bld-sec-nm" title="' + nmeta + '">' + nmeta + '</span>' +
                '<i class="mdi mdi-drag-horizontal-variant dcl-bld-drag-i" title="Arrastrar"></i>' +
                '</div>' +
                // Fila 2: chip categoría + descripción
                '<div class="dcl-bld-tile-meta">' +
                '<span class="dcl-bld-cat-chip dcl-bld-cat-chip--' + catCls + '">' + catLbl + '</span>' +
                (desc ? '<span class="dcl-bld-tile-desc" title="' + dclHtmlEsc(desc) + '">' + dclHtmlEsc(desc) + '</span>' : '') +
                '</div>' +
                // Preview (oculto por defecto)
                '<div class="dcl-bld-preview" style="display:none"></div>' +
                // Fila 3: acciones (vista previa + control de alto)
                '<div class="dcl-bld-tile-actions">' +
                '<button type="button" class="dcl-bld-prev-btn" onclick="dclBldTogglePreview(this)"' +
                ' title="Vista previa" ondragstart="event.stopPropagation()">' +
                '<i class="mdi mdi-eye-outline"></i><span>Vista previa</span></button>' +
                '<div class="dcl-bld-h-grp" title="Alto del widget">' +
                '<button type="button" class="dcl-bld-h-btn" onclick="dclBldH(this,-1)" ondragstart="event.stopPropagation()">&#8722;</button>' +
                '<span class="dcl-bld-h-val">' + dclBldHLabel(h) + '</span>' +
                '<button type="button" class="dcl-bld-h-btn" onclick="dclBldH(this,1)" ondragstart="event.stopPropagation()">+</button>' +
                '</div>' +
                '</div>' +
                '</div>';
        }
        return tilesHtml;
    }

    // Delegación: botón "quitar" de una sección colocada → devuelve al pool y
    // deja la columna vacía (control manual, sin reorganizar las demás).
    function dclInitBldColRemove(content) {
        if (content._dclRemoveBound) return;
        content._dclRemoveBound = true;
        content.addEventListener('click', function (e) {
            var btn = e.target;
            while (btn && btn !== content && !(btn.classList && btn.classList.contains('dcl-bld-col-rm'))) btn = btn.parentNode;
            if (!btn || btn === content) return;
            e.preventDefault(); e.stopPropagation();
            var col = btn;
            while (col && !(col.classList && col.classList.contains('dcl-bld-col'))) col = col.parentNode;
            if (!col) return;
            var sec = col.querySelector('.dcl-section');
            if (sec) dclBldReturnToPool(sec);
            dclBldSetColEmpty(col);
            dclBldUpdateCounter();
        });
    }

    // ─── Helper: crear slot de columna en el canvas builder ─────────────
    function dclMakeColSlot(isEmpty) {
        var sl = document.createElement('div');
        sl.className = 'dcl-col-slot' + (isEmpty ? ' dcl-col-slot--empty' : '');
        sl.innerHTML = '<i class="mdi mdi-plus-circle-outline"></i>' + (isEmpty ? '<span>Arrastra aquí</span>' : '');
        return sl;
    }

    // Control de ancho desde el tile del panel
    function dclBldW(btn, w) {
        var tile = btn;
        while (tile && !tile.classList.contains('dcl-bld-tile')) tile = tile.parentNode;
        if (!tile) return;
        tile.setAttribute('data-width', w);
        var wBtns = tile.querySelectorAll('.dcl-bld-w-btn');
        for (var i = 0; i < wBtns.length; i++)
            wBtns[i].classList.toggle('dcl-bld-w-btn--on', wBtns[i].getAttribute('data-w') === w);
        // Actualizar sección en canvas si ya fue colocada
        var secId = tile.getAttribute('data-section');
        var sec = document.querySelector('#dcl-content .dcl-section[data-section="' + secId + '"]:not(.dcl-sec-pooled)');
        if (sec) sec.setAttribute('data-width', w);
    }

    // Control de alto desde el tile del panel
    function dclBldH(btn, dir) {
        var tile = btn;
        while (tile && !tile.classList.contains('dcl-bld-tile')) tile = tile.parentNode;
        if (!tile) return;
        var cur = parseInt(tile.getAttribute('data-height') || '0', 10);
        var next = Math.max(0, Math.min(cur + dir, 4));
        tile.setAttribute('data-height', next);
        var lbl = tile.querySelector('.dcl-bld-h-val');
        if (lbl) lbl.textContent = dclBldHLabel(next);
        // Actualizar sección en canvas si ya fue colocada
        var secId = tile.getAttribute('data-section');
        var sec = document.querySelector('#dcl-content .dcl-section[data-section="' + secId + '"]:not(.dcl-sec-pooled)');
        if (sec) sec.setAttribute('data-height', next);
    }

    // Actualiza el contador "X / N" del panel builder
    function dclBldUpdateCounter() {
        var pool = document.getElementById('dcl-bld-pool');
        var el = document.getElementById('dcl-bld-counter');
        dclBldRefreshColButtons();
        if (!pool || !el) return;
        var total = pool.querySelectorAll('.dcl-bld-tile').length;
        var placed = pool.querySelectorAll('.dcl-bld-tile--placed').length;
        el.textContent = placed + ' / ' + total;
    }

    // Garantiza que cada columna ocupada tenga su botón "quitar" (vaciar columna).
    function dclBldRefreshColButtons() {
        var content = dclBldCanvas();
        if (!content) return;
        var cols = content.querySelectorAll('.dcl-bld-col');
        for (var i = 0; i < cols.length; i++) {
            var col = cols[i];
            var sec = col.querySelector('.dcl-section');
            var btn = col.querySelector('.dcl-bld-col-rm');
            if (sec && !btn) {
                btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'dcl-bld-col-rm';
                btn.title = 'Quitar de esta columna';
                btn.setAttribute('draggable', 'false');
                btn.innerHTML = '<i class="mdi mdi-close"></i>';
                col.appendChild(btn);
            } else if (!sec && btn) {
                if (btn.parentNode) btn.parentNode.removeChild(btn);
            }
        }
    }

    // Clona una sección para vista previa (desactiva interacción del clon)
    function dclBldClonePreview(secId) {
        var sec = document.querySelector('.dcl-section[data-section="' + secId + '"]');
        if (!sec) return null;
        var clone = sec.cloneNode(true);
        clone.classList.remove('dcl-sec-pooled');
        clone.removeAttribute('draggable');
        clone.style.display = '';
        clone.style.height = '';
        var nodes = clone.querySelectorAll('button,input,select,a,[onclick],[onmousedown]');
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].setAttribute('tabindex', '-1');
            nodes[i].style.pointerEvents = 'none';
            nodes[i].removeAttribute('onclick');
            nodes[i].removeAttribute('onmousedown');
        }
        // Ocultar handles/controles de edición en el preview
        var hide = clone.querySelectorAll('.dcl-rsz,.dcl-rsz-w,.dcl-card-cfg-btn,.dcl-width-btn,.dcl-drag-handle,.dcl-card-reveal');
        for (var k = 0; k < hide.length; k++) hide[k].style.display = 'none';
        return clone;
    }

    // Toggle preview inline de un tile del builder
    function dclBldTogglePreview(btn) {
        var tile = btn;
        while (tile && !tile.classList.contains('dcl-bld-tile')) tile = tile.parentNode;
        if (!tile) return;
        var prev = tile.querySelector('.dcl-bld-preview');
        if (!prev) return;
        var open = tile.classList.toggle('dcl-bld-tile--prev-open');
        var icon = btn.querySelector('i');
        if (open) {
            var secId = tile.getAttribute('data-section');
            var clone = dclBldClonePreview(secId);
            if (!clone) { tile.classList.remove('dcl-bld-tile--prev-open'); return; }
            prev.innerHTML =
                '<div class="dcl-bld-prev-bar">' +
                '<span class="dcl-bld-prev-bar-lbl"><i class="mdi mdi-eye-outline"></i> Vista previa</span>' +
                '<button type="button" class="dcl-bld-prev-expand" title="Ampliar" ' +
                'data-expand="' + dclHtmlEsc(secId) + '" ondragstart="event.stopPropagation()">' +
                '<i class="mdi mdi-arrow-expand-all"></i> Ampliar</button>' +
                '</div>';
            var holder = document.createElement('div');
            holder.className = 'dcl-bld-prev-holder';
            holder.appendChild(clone);
            prev.appendChild(holder);
            prev.style.display = 'block';
            if (icon) icon.className = 'mdi mdi-eye-off-outline';
        } else {
            prev.style.display = 'none';
            prev.innerHTML = '';
            if (icon) icon.className = 'mdi mdi-eye-outline';
        }
    }

    // Modal de preview AMPLIADO (clic en "Ampliar" o en el propio preview)
    function dclBldExpandPreview(secId) {
        var clone = dclBldClonePreview(secId);
        if (!clone) return;
        var meta = {};
        var sec = document.querySelector('.dcl-section[data-section="' + secId + '"]');
        if (sec) meta = dclGetSectionMeta(sec);
        var ov = document.createElement('div');
        ov.id = 'dcl-prev-modal';
        ov.className = 'dcl-prev-modal';
        ov.innerHTML =
            '<div class="dcl-prev-modal-box">' +
            '<div class="dcl-prev-modal-hd">' +
            '<span class="dcl-prev-modal-title"><i class="' + (meta.icon || 'mdi mdi-eye-outline') + '"></i>&nbsp;' +
            dclHtmlEsc(meta.name || 'Vista previa') + '</span>' +
            '<button type="button" class="dcl-prev-modal-close" data-close="1" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-prev-modal-body" id="dcl-prev-modal-body"></div>' +
            '</div>';
        document.body.appendChild(ov);
        ov.querySelector('#dcl-prev-modal-body').appendChild(clone);
        ov.addEventListener('click', function (e) {
            if (e.target === ov || (e.target.getAttribute && e.target.getAttribute('data-close')) ||
                (e.target.parentNode && e.target.parentNode.getAttribute && e.target.parentNode.getAttribute('data-close'))) {
                if (ov.parentNode) ov.parentNode.removeChild(ov);
            }
        });
        requestAnimationFrame(function () { ov.classList.add('dcl-prev-modal--open'); });
    }

    // ── Builder: funciones de fila dinámica ──────────────────────────────
    // Cada fila tiene N columnas (1-4). Cada columna (.dcl-bld-col) contiene
    // EXACTAMENTE un slot: vacío (placeholder) o con una sección. Una columna
    // nunca apila varias secciones — eso garantiza el modelo posicional
    // slots[col] y el respeto de columnas vacías.
    function dclBldMakeRow(cols) {
        cols = Math.max(1, Math.min(4, parseInt(cols, 10) || 1));
        var row = document.createElement('div');
        row.className = 'dcl-bld-row';
        row.setAttribute('data-row-cols', cols);
        var hd = document.createElement('div');
        hd.className = 'dcl-bld-row-hd';
        hd.innerHTML =
            '<i class="mdi mdi-drag-horizontal-variant dcl-bld-row-drag-i"></i>' +
            '<span class="dcl-bld-row-info">' + cols + ' columna' + (cols > 1 ? 's' : '') + '</span>' +
            '<button type="button" class="dcl-bld-row-del-btn" onclick="dclBldDelRow(this)" title="Eliminar fila">' +
            '<i class="mdi mdi-delete-outline"></i></button>';
        row.appendChild(hd);
        var body = document.createElement('div');
        body.className = 'dcl-bld-row-body';
        body.setAttribute('data-cols', cols);
        for (var c = 0; c < cols; c++) {
            var col = document.createElement('div');
            col.className = 'dcl-bld-col';
            col.appendChild(dclMakeColSlot(true));
            body.appendChild(col);
        }
        row.appendChild(body);
        return row;
    }

    function dclBldAddRow(cols) {
        var canvas = dclBldCanvas();
        var addBar = canvas && canvas.querySelector('.dcl-bld-addrow-bar');
        if (!canvas || !addBar) return;
        var emptyMsg = canvas.querySelector('.dcl-sheet-empty');
        if (emptyMsg && emptyMsg.parentNode) emptyMsg.parentNode.removeChild(emptyMsg);
        var rowEl = dclBldMakeRow(cols);
        canvas.insertBefore(rowEl, addBar);
        dclInitBldColsDnD(canvas);
        // Scroll suave a la nueva fila para feedback inmediato
        try { rowEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); } catch (e) { }
    }

    // Mensaje "canvas vacío" reutilizable
    function dclBldEmptyMsg() {
        var m = document.createElement('div');
        m.className = 'dcl-sheet-empty';
        m.innerHTML =
            '<i class="mdi mdi-view-quilt" style="font-size:44px;opacity:.22"></i>' +
            '<p>Empieza construyendo tu dashboard</p>' +
            '<p class="dcl-sheet-empty-sub">Agrega una fila con los botones de abajo y arrastra widgets</p>';
        return m;
    }

    function dclBldDelRow(btn) {
        var row = btn;
        while (row && !row.classList.contains('dcl-bld-row')) row = row.parentNode;
        if (!row) return;
        var secsInRow = row.querySelectorAll('.dcl-section');
        for (var i = 0; i < secsInRow.length; i++) dclBldReturnToPool(secsInRow[i]);
        if (row.parentNode) row.parentNode.removeChild(row);
        dclBldUpdateCounter();
        var canvas = dclBldCanvas();
        var addBar = canvas && canvas.querySelector('.dcl-bld-addrow-bar');
        var rows = canvas && canvas.querySelectorAll('.dcl-bld-row');
        if (canvas && addBar && rows && !rows.length) canvas.insertBefore(dclBldEmptyMsg(), addBar);
    }

    // Vaciar el canvas: eliminar filas, devolver secciones al pool
    // ── Builder por PLACEHOLDERS ──────────────────────────────────────────
    // El canvas ya no mueve las secciones reales del dashboard: usa tarjetas
    // representativas. Así se puede armar el layout de una categoría cuyos
    // widgets el servidor no renderizó (estando en General no existen los nodos
    // de Zona, y antes el pool salía vacío).
    //
    // El placeholder conserva class="dcl-section" y data-section porque
    // dclBldCollectCfg y el DnD de columnas leen por ese selector.
    var _bldNivelDestino = null;   // categoría que se está armando
    // Layout guardado que el builder está editando. Sin esto, armar un layout
    // recién creado solo actualizaba el cfg activo y el layout quedaba con
    // rows: [] — el trabajo se perdía al cambiar de layout.
    var _bldLayoutId = null;

    // HTML de widgets que NO están renderizados en la página (los de otra
    // categoría), traído del mismo WebService del auto-refresh. Solo se usa para
    // la vista previa del builder. Cachea por id de sección.
    var _bldPrevHtml = {};
    var _bldPrevPedido = {};   // niveles ya solicitados, para no repetir el XHR

    function dclBldNivelDestino() { return _bldNivelDestino || dclNivelActual(); }

    // Pide al servidor el tablero de un nivel y guarda el HTML de cada widget.
    // Al terminar repinta el canvas para que aparezcan las miniaturas que
    // faltaban. Es best-effort: si falla, los widgets quedan con su tarjeta.
    function dclBldCargarPreviews(nivel) {
        if (!nivel || _bldPrevPedido[nivel]) return;
        if (typeof window._dclWsAjaxUrl === 'undefined') return;
        var hfU = document.getElementById('hfUsuario');
        if (!hfU || !hfU.value) return;
        _bldPrevPedido[nivel] = true;

        // El nivel pedido necesita sus ids: se usan los del filtro actual y, si
        // no hay, 0 → el SP devuelve el widget vacío, que igual sirve de maqueta.
        var ins = parseInt(dclHf('hfInstalacion'), 10) || 0;
        var zon = parseInt(dclHf('hfZona'), 10) || 0;
        if (nivel === 'general') { ins = 0; zon = 0; }
        else if (nivel === 'instalacion') { zon = 0; }

        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', window._dclWsAjaxUrl, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4 || xhr.status !== 200) return;
                try {
                    var r = JSON.parse(xhr.responseText);
                    var d = r.d !== undefined ? r.d : r;
                    if (!d || !d.ok || !d.html) return;
                    var cont = document.createElement('div');
                    cont.innerHTML = d.html;
                    var secs = cont.querySelectorAll('.dcl-section[data-section]');
                    for (var i = 0; i < secs.length; i++) {
                        var sid = secs[i].getAttribute('data-section');
                        if (!_bldPrevHtml[sid]) _bldPrevHtml[sid] = secs[i].outerHTML;
                    }
                    // Repintar el canvas con lo que ya está armado
                    var cfgAct = dclBldCollectCfg();
                    if (cfgAct && cfgAct.rows && cfgAct.rows.length) {
                        dclBldClearCanvas();
                        dclBldPintarFilas(dclNormalizeRows(cfgAct.rows));
                    }
                } catch (e) { }
            };
            xhr.send(JSON.stringify({
                usuario: parseInt(hfU.value) || 0,
                cliente: parseInt(dclHf('hfCliente'), 10) || 0,
                instalacion: ins,
                zona: zon,
                desde: dclHf('hfDesde'),
                hasta: dclHf('hfHasta'),
                nomIns: dclHf('hfNomIns'),
                meta: dclGetMeta()
            }));
        } catch (e) { }
    }

    // Vuelca el cfg armado sobre el layout guardado que se está editando.
    // Devuelve su nombre, o '' si el builder no vena de un layout concreto.
    function dclBldPersistirEnLayout(cfg, nivel) {
        if (!_bldLayoutId) return '';
        var saved = dclGetSavedLayouts(nivel);
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id !== _bldLayoutId) continue;
            if (saved[i].isSystem) return '';        // protegido: nunca se pisa
            saved[i].cfg  = JSON.parse(JSON.stringify(cfg));
            saved[i].date = new Date().toISOString();
            dclSetSavedLayouts(saved, nivel);
            return saved[i].name || '';
        }
        return '';
    }

    function dclBldSeccionesDeNivel(nivel) {
        return (_DCL_SECTIONS_POR_NIVEL[nivel] || _DCL_SECTIONS_POR_NIVEL.general).slice();
    }

    function dclBldPlaceholder(secId, alto) {
        var meta = dclSecMetaPorId(secId);
        var el = document.createElement('div');
        el.className = 'dcl-section dcl-bld-ph dcl-bld-cat-' + meta.catClass;
        el.setAttribute('data-section', secId);
        el.setAttribute('data-height', alto || '0');
        el.setAttribute('draggable', 'true');
        el.innerHTML =
            '<div class="dcl-bld-ph-in">' +
            '<i class="' + meta.ico + ' dcl-bld-ph-ico"></i>' +
            '<span class="dcl-bld-ph-nom">' + dclHtmlEsc(meta.nom) + '</span>' +
            '<span class="dcl-bld-ph-cat dcl-bld-cat-chip--' + meta.catClass + '">' + dclHtmlEsc(meta.cat) + '</span>' +
            '</div>';

        // Vista real del widget cuando existe en la página: se clona el nodo ya
        // renderizado y se escala. Así el canvas muestra CÓMO va a quedar y no
        // solo el nombre. Para widgets de otra categoría el nodo no existe y se
        // mantiene la tarjeta con ícono + nombre, que es lo único disponible.
        var real = document.querySelector('#dcl-content .dcl-section[data-section="' + secId + '"]');

        // Si el widget no está en la página (es de otra categoría), se usa el
        // HTML que dclBldCargarPreviews trajo del WebService. Sin esto, widgets
        // como "Cumplimiento por Zona" nunca mostraban vista previa en General.
        if (!real && _bldPrevHtml[secId]) {
            var tmp = document.createElement('div');
            tmp.innerHTML = _bldPrevHtml[secId];
            real = tmp.firstElementChild;
        }

        if (real) {
            var prev = real.cloneNode(true);
            prev.removeAttribute('id');
            prev.removeAttribute('draggable');
            prev.removeAttribute('data-section');   // no confundir a dclBldCollectCfg
            prev.classList.add('dcl-bld-ph-real');
            prev.style.display = '';
            prev.style.height = '';
            // El clon es inerte: sin drag, sin foco y sin controles operables.
            var interactivos = prev.querySelectorAll('a,button,input,select,textarea,[draggable],[onclick]');
            for (var i = 0; i < interactivos.length; i++) {
                interactivos[i].removeAttribute('draggable');
                interactivos[i].removeAttribute('onclick');
                interactivos[i].setAttribute('tabindex', '-1');
                if (interactivos[i].tagName !== 'A') interactivos[i].disabled = true;
            }
            var wrap = document.createElement('div');
            wrap.className = 'dcl-bld-ph-prevwrap';
            wrap.appendChild(prev);
            el.appendChild(wrap);
            el.classList.add('dcl-bld-ph--conprev');
        }
        return el;
    }

    // <select> de categoría destino en el header del builder.
    function dclBldNivelSelectHtml() {
        var act = dclBldNivelDestino();
        var opts = '';
        var niveles = ['general', 'instalacion', 'zona'];
        for (var i = 0; i < niveles.length; i++) {
            opts += '<option value="' + niveles[i] + '"' + (niveles[i] === act ? ' selected' : '') + '>' +
                    dclHtmlEsc(dclNivelLabel(niveles[i])) + '</option>';
        }
        return '<select id="dcl-bld-nivelsel" class="dcl-bld-layoutsel" ' +
               'title="Categoría del dashboard que estás armando" ' +
               'onchange="dclBldCambiarNivel(this.value)">' + opts + '</select>';
    }

    // Cambia la categoría destino: repuebla el pool y arranca un canvas limpio,
    // porque los widgets de la categoría anterior no pertenecen a la nueva.
    function dclBldCambiarNivel(nivel) {
        if (!nivel || nivel === _bldNivelDestino) return;
        _bldNivelDestino = nivel;

        var pool = document.getElementById('dcl-bld-pool');
        if (pool) pool.innerHTML = dclBldBuildTiles(dclBldSeccionesDeNivel(nivel));

        dclBldClearCanvas();
        dclBldPintarFilas(dclNormalizeRows(dclDefaultCfg(nivel).rows));

        var chip = document.querySelector('.dcl-cat-chip--bld');
        if (chip) chip.outerHTML = dclCatChip(nivel, 'dcl-cat-chip--bld');

        // Los layouts guardados son por categoría: la lista debe seguirla.
        var selL = document.getElementById('dcl-bld-layoutsel');
        if (selL) selL.outerHTML = dclBldLayoutSelectHtml();

        dclInitBldPanelDnD(pool);
        dclBldCargarPreviews(nivel);   // miniaturas de los widgets de esa categoría
        dclSwalToast('Armando ' + dclNivelLabel(nivel), 'info');
    }

    // <select> de layouts guardados para el header del builder. Lista los de la
    // categoría actual (dcl_saved_checklists_<nivel>) más el del sistema.
    // Garantiza el layout "Por defecto del sistema" en la categoría indicada.
    // dclEnsureSystemLayout solo lo crea en el nivel actual, así que al cambiar
    // el combo a una categoría nunca visitada el selector salía sin él.
    function dclBldAsegurarSistema(nivel) {
        var saved = dclGetSavedLayouts(nivel);
        for (var i = 0; i < saved.length; i++) if (saved[i].isSystem) return saved;
        saved.unshift({
            id: _dclSystemLayoutId,
            name: 'Por defecto del sistema',
            cfg: dclDefaultCfg(nivel),
            cfgGeneral: dclDefaultCfg('general'),
            cfgInstalacion: dclDefaultCfg('instalacion'),
            cfgZona: dclDefaultCfg('zona'),
            nivel: nivel,
            date: new Date().toISOString(),
            isDefault: saved.length === 0,
            isSystem: true
        });
        dclSetSavedLayouts(saved, nivel);
        return saved;
    }

    function dclBldLayoutSelectHtml() {
        // Los layouts se listan de la CATEGORÍA destino: si se está armando Zona
        // desde General, ofrecer los de General no serviría de nada.
        var nivel  = dclBldNivelDestino();
        var saved  = dclBldAsegurarSistema(nivel);
        var activo = (nivel === dclNivelActual()) ? dclGetActiveLayoutName() : '';
        var opts   = '<option value="">Cargar layout…</option>';
        for (var i = 0; i < saved.length; i++) {
            var sel = (activo && saved[i].name === activo) ? ' selected' : '';
            opts += '<option value="' + dclHtmlEsc(saved[i].id) + '"' + sel + '>' +
                    dclHtmlEsc(saved[i].name || 'Sin nombre') +
                    (saved[i].isSystem ? ' (sistema)' : '') + '</option>';
        }
        return '<select id="dcl-bld-layoutsel" class="dcl-bld-layoutsel" ' +
               'title="Cargar un layout guardado en el canvas" ' +
               'onchange="dclBldCargarLayout(this.value)">' + opts + '</select>';
    }

    // Guía que se muestra cuando el canvas queda sin filas.
    function dclBldGuiaVacia() {
        var el = document.createElement('div');
        el.className = 'dcl-sheet-empty dcl-bld-guia';
        el.innerHTML =
            '<i class="mdi mdi-view-quilt dcl-bld-guia-ico"></i>' +
            '<p class="dcl-bld-guia-tit">Arma tu dashboard desde cero</p>' +
            '<ol class="dcl-bld-guia-pasos">' +
            '<li><b>Agrega una fila</b> con los botones <i class="mdi mdi-view-column"></i> de abajo ' +
            '(1 a 4 columnas). Puedes apilar todas las filas que necesites.</li>' +
            '<li><b>Arrastra un widget</b> desde el panel derecho hasta una columna. ' +
            'Busca por nombre o filtrá por KPI / Gráfico / Tabla.</li>' +
            '<li><b>Ajusta</b>: una columna admite un widget; si soltás sobre una ocupada se intercambian. ' +
            'Con <i class="mdi mdi-close"></i> vaciás la columna y puedes dejarla en blanco como separador.</li>' +
            '<li><b>Guarda</b> con <i class="mdi mdi-content-save"></i> <b>Guardar como...</b> para conservarlo ' +
            'con nombre, o <i class="mdi mdi-check"></i> <b>Aplicar</b> para usarlo sin guardarlo.</li>' +
            '</ol>' +
            '<p class="dcl-bld-guia-tip"><i class="mdi mdi-lightbulb-on-outline"></i> ' +
            'Solo se ofrecen los widgets del nivel actual: los datos de otro nivel quedarían vacíos.</p>';
        return el;
    }

    // Pinta el canvas del builder desde un modelo rows[]. La usan tanto la
    // apertura del modal como el selector de layouts del header: sin esto,
    // elegir otro layout obligaba a duplicar toda la reconstrucción.
    function dclBldPintarFilas(rows) {
        var canvas  = dclBldCanvas();
        var content = document.getElementById('dcl-content');
        if (!canvas || !content) return;
        var addBar = canvas.querySelector('.dcl-bld-addrow-bar');

        var vacio = canvas.querySelector('.dcl-sheet-empty');
        if (vacio && vacio.parentNode) vacio.parentNode.removeChild(vacio);

        if (rows && rows.length) {
            for (var r = 0; r < rows.length; r++) {
                var rowData = rows[r];
                var rowEl = dclBldMakeRow(rowData.cols);
                if (addBar) canvas.insertBefore(rowEl, addBar);
                else canvas.appendChild(rowEl);

                var colEls = rowEl.querySelectorAll('.dcl-bld-col');
                for (var c = 0; c < colEls.length; c++) {
                    // El slot puede ser string U objeto {sec, span} (modelo v2):
                    // usarlo crudo daba el selector [data-section="[object Object]"],
                    // no encontraba la sección y la columna quedaba vacía.
                    var secId2 = dclSlotSec(rowData.slots[c]);
                    if (!secId2) continue;   // columna vacía → mantiene su slot
                    // Placeholder, no la sección real: el widget puede pertenecer
                    // a una categoría que el servidor no renderizó.
                    var cfgH = dclGetCfg().sectionHeights || {};
                    colEls[c].innerHTML = '';
                    colEls[c].appendChild(dclBldPlaceholder(secId2, cfgH[secId2] || '0'));
                }
            }
        } else if (addBar) {
            canvas.insertBefore(dclBldGuiaVacia(), addBar);
        }

        // Marcar en el pool los tiles cuyas secciones ya están colocadas
        var placed = canvas.querySelectorAll('.dcl-section:not(.dcl-sec-pooled)');
        for (var i = 0; i < placed.length; i++) {
            var t = document.querySelector('#dcl-bld-pool .dcl-bld-tile[data-section="' +
                                           placed[i].getAttribute('data-section') + '"]');
            if (t) t.classList.add('dcl-bld-tile--placed');
        }
        dclBldUpdateCounter();
    }

    // Carga en el canvas un layout guardado (selector del header del builder).
    function dclBldCargarLayout(id) {
        if (!id) return;
        var nivel = dclBldNivelDestino();
        var saved = dclBldAsegurarSistema(nivel);
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id !== id) continue;
            // El layout del sistema guarda una variante por nivel: hay que tomar
            // la de la categoría destino, no la de la vista en pantalla.
            var src = saved[i].isSystem
                ? (saved[i]['cfg' + nivel.charAt(0).toUpperCase() + nivel.slice(1)] || dclDefaultCfg(nivel))
                : (saved[i].cfg || {});
            dclBldClearCanvas();                       // devuelve las secciones al pool
            dclBldPintarFilas(dclNormalizeRows(src.rows));
            dclInitSectionDnD();
            return;
        }
    }

    // Vacía el canvas: devuelve todas las secciones al pool y borra las filas.
    function dclBldClearCanvas() {
        var canvas = dclBldCanvas();
        if (!canvas) return;
        var rows = canvas.querySelectorAll('.dcl-bld-row');
        for (var r = 0; r < rows.length; r++) {
            var secsInRow = rows[r].querySelectorAll('.dcl-section');
            for (var s = 0; s < secsInRow.length; s++) dclBldReturnToPool(secsInRow[s]);
            if (rows[r].parentNode) rows[r].parentNode.removeChild(rows[r]);
        }
        if (!canvas.querySelector('.dcl-sheet-empty')) {
            var addBar = canvas.querySelector('.dcl-bld-addrow-bar');
            if (addBar) canvas.insertBefore(dclBldEmptyMsg(), addBar);
            else canvas.appendChild(dclBldEmptyMsg());
        }
        var placed = document.querySelectorAll('#dcl-bld-pool .dcl-bld-tile--placed');
        for (var i = 0; i < placed.length; i++) placed[i].classList.remove('dcl-bld-tile--placed');
        dclBldUpdateCounter();
    }

    // DnD: tiles del panel → las marcamos cuando empiezan a draggearse al canvas
    function dclInitBldPanelDnD(pool) {
        if (!pool) return;
        pool.addEventListener('dragstart', function (e) {
            var t = e.target;
            while (t && t !== pool) {
                if (t.classList && t.classList.contains('dcl-bld-tile')) break;
                t = t.parentNode;
            }
            if (!t || t === pool || t.classList.contains('dcl-bld-tile--placed')) {
                e.preventDefault(); return;
            }
            _bldDraggingTile = t;
            e.dataTransfer.effectAllowed = 'copyMove';
            e.dataTransfer.setData('text/plain', t.getAttribute('data-section') || '');
            setTimeout(function () { t.classList.add('dcl-bld-tile--dragging'); }, 0);
        });
        pool.addEventListener('dragend', function () {
            if (_bldDraggingTile) _bldDraggingTile.classList.remove('dcl-bld-tile--dragging');
            // Si no se soltó en el canvas (dragend sin drop), limpiar
        });
    }

    // (ELIMINADO) dclInitBldCanvasDnD — DnD de canvas plano de una sola columna.
    // Reemplazado por dclInitBldColsDnD (modelo multi-columna con slots).
    function _dclDeadBldCanvasDnD_unused(content) {
        if (true) return;
        if (!content) return;
        if (content._dclCanvasBound) return; // guard: evitar listeners duplicados
        content._dclCanvasBound = true;
        var dzOver = null; // drop zone actual bajo el cursor

        function nearestDz(clientY, clientX) {
            var dzs = content.querySelectorAll('.dcl-dz');
            var best = null, bestD = Infinity;
            var cols = parseInt(content.getAttribute('data-cols') || '1', 10);
            for (var i = 0; i < dzs.length; i++) {
                var r = dzs[i].getBoundingClientRect();
                var dy = Math.abs(clientY - (r.top + r.height / 2));
                var dx = (clientX !== undefined && cols > 1) ? Math.abs(clientX - (r.left + r.width / 2)) * 0.3 : 0;
                var d = dy + dx;
                if (d < bestD) { bestD = d; best = dzs[i]; }
            }
            return best;
        }
        function clearDzOver() {
            var dzs = content.querySelectorAll('.dcl-dz--over');
            for (var i = 0; i < dzs.length; i++) dzs[i].classList.remove('dcl-dz--over');
            dzOver = null;
        }

        content.addEventListener('dragover', function (e) {
            e.preventDefault();
            if (!_bldDraggingTile) return;
            e.dataTransfer.dropEffect = 'move';
            var dz = nearestDz(e.clientY, e.clientX);
            if (dz === dzOver) return;
            clearDzOver();
            if (dz) { dz.classList.add('dcl-dz--over'); dzOver = dz; }
        });

        content.addEventListener('dragleave', function (e) {
            // relatedTarget es null justo antes de drop — no limpiar en ese caso
            if (e.relatedTarget && !content.contains(e.relatedTarget)) clearDzOver();
        });

        content.addEventListener('drop', function (e) {
            e.preventDefault();
            if (!_bldDraggingTile) return;

            var secId = _bldDraggingTile.getAttribute('data-section');
            var width = _bldDraggingTile.getAttribute('data-width') || 'half';
            var height = parseInt(_bldDraggingTile.getAttribute('data-height') || '0', 10);
            // Fallback: si dragleave limpió antes del drop, buscar la más cercana por posición
            var target = content.querySelector('.dcl-dz--over') || nearestDz(e.clientY, e.clientX);
            clearDzOver();

            var sec = content.querySelector('.dcl-section[data-section="' + secId + '"]');
            if (!sec || !target) { _bldDraggingTile = null; return; }

            // Aplicar ancho y alto a la sección
            sec.setAttribute('data-width', width);
            sec.setAttribute('data-height', height);

            // Quitar clase de empty en la dz inicial (una sola vez)
            target.classList.remove('dcl-dz--empty');

            // Insertar [nueva-dz, sección] ANTES del target
            // El target queda como la dz DESPUÉS de la sección
            var newDz = document.createElement('div');
            newDz.className = 'dcl-dz';
            content.insertBefore(newDz, target);
            content.insertBefore(sec, target);

            // Mostrar sección
            sec.classList.remove('dcl-sec-pooled');

            // Marcar tile como colocado
            _bldDraggingTile.classList.add('dcl-bld-tile--placed');
            _bldDraggingTile = null;
            dclBldUpdateCounter();
        });
    }

    // ─── DnD multi-columna: UNA sección por columna ──────────────────────
    // Cada columna del builder admite exactamente UNA sección. Soltar sobre una
    // columna ocupada INTERCAMBIA (swap) la sección previa con la nueva. Esto da
    // control posicional absoluto y respeta columnas vacías (sin auto-acomodo).
    function dclInitBldColsDnD(content) {
        if (content._dclColsBound) return;
        content._dclColsBound = true;
        var _overCol = null;

        function colAt(clientX, clientY) {
            var cols = content.querySelectorAll('.dcl-bld-col');
            var best = null, bestD = Infinity;
            for (var i = 0; i < cols.length; i++) {
                var r = cols[i].getBoundingClientRect();
                // Solo columnas cuya banda vertical contiene el cursor (no saltar de fila)
                if (clientY < r.top - 40 || clientY > r.bottom + 40) continue;
                var cx = r.left + r.width / 2;
                var d = Math.abs(clientX - cx);
                if (d < bestD) { bestD = d; best = cols[i]; }
            }
            return best;
        }
        function clearOver() {
            if (_overCol) { _overCol.classList.remove('dcl-bld-col--over'); _overCol = null; }
        }
        // Detectar drag de sección ya colocada (para moverla entre columnas)
        content.addEventListener('dragstart', function (e) {
            var el = e.target;
            while (el && el !== content) {
                if (el.classList && el.classList.contains('dcl-section')) {
                    var par = el.parentNode;
                    if (par && par.classList && par.classList.contains('dcl-bld-col')) {
                        _bldDraggingSection = el;
                        _bldDraggingTile = null;
                        e.dataTransfer.effectAllowed = 'move';
                        e.dataTransfer.setData('text/plain', el.getAttribute('data-section') || '');
                        // Ghost compacto
                        var hd = el.querySelector('.dcl-card-title');
                        var ghost = document.createElement('div');
                        ghost.style.cssText = 'position:fixed;top:-999px;padding:5px 12px;background:#415f8d;color:#fff;font-size:11px;border-radius:4px;white-space:nowrap;box-shadow:0 2px 8px rgba(0,0,0,.3);';
                        ghost.textContent = '✥ ' + (hd ? hd.textContent.trim() : 'Mover sección');
                        document.body.appendChild(ghost);
                        try { e.dataTransfer.setDragImage(ghost, 0, 20); } catch (ex) { }
                        setTimeout(function () { if (ghost.parentNode) ghost.parentNode.removeChild(ghost); }, 0);
                    }
                    return;
                }
                el = el.parentNode;
            }
        });
        content.addEventListener('dragover', function (e) {
            if (!_bldDraggingTile && !_bldDraggingSection) return;
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            var col = colAt(e.clientX, e.clientY);
            if (col === _overCol) return;
            clearOver();
            if (col) { col.classList.add('dcl-bld-col--over'); _overCol = col; }
        });
        content.addEventListener('dragleave', function (e) {
            if (!content.contains(e.relatedTarget)) clearOver();
        });
        content.addEventListener('dragend', function () {
            clearOver();
            _bldDraggingSection = null;
            _bldDraggingTile = null;
        });
        content.addEventListener('drop', function (e) {
            e.preventDefault();
            var col = (_overCol) ? _overCol : colAt(e.clientX, e.clientY);
            clearOver();
            if (!col) { _bldDraggingTile = null; _bldDraggingSection = null; return; }

            if (_bldDraggingSection) {
                // ── Mover/intercambiar sección entre columnas ──
                var sec = _bldDraggingSection;
                _bldDraggingSection = null;
                var srcCol = sec.parentNode;
                if (srcCol === col) return; // soltó en su propia columna → nada
                var destSec = col.querySelector('.dcl-section');
                if (destSec) {
                    // SWAP: la sección destino pasa a la columna origen
                    srcCol.innerHTML = '';
                    srcCol.appendChild(destSec);
                    destSec.setAttribute('draggable', 'true');
                    col.innerHTML = '';
                    col.appendChild(sec);
                } else {
                    // Columna destino vacía: mover y dejar la origen vacía
                    col.innerHTML = '';
                    col.appendChild(sec);
                    dclBldSetColEmpty(srcCol);
                }
            } else if (_bldDraggingTile) {
                // ── Colocar sección nueva desde el pool ──
                var secId = _bldDraggingTile.getAttribute('data-section');
                var height = parseInt(_bldDraggingTile.getAttribute('data-height') || '0', 10);
                // Placeholder nuevo, NO la sección real: arrancarla del dashboard
                // lo desarmaba, y para un widget de otra categoría ni siquiera
                // existe el nodo (el servidor solo renderiza los del nivel actual).
                var secNew = dclBldPlaceholder(secId, height || '0');

                // Un widget no puede estar dos veces en el layout. Antes lo
                // impedía el hecho de mover un nodo único; con placeholders hay
                // que quitar a mano el que ya estuviera colocado, o
                // dclBldCollectCfg lo guardaría repetido.
                var canvasEl = dclBldCanvas();
                var yaPuesto = canvasEl && canvasEl.querySelector('.dcl-bld-row .dcl-section[data-section="' + secId + '"]');
                if (yaPuesto) {
                    var colPrev = yaPuesto.parentNode;
                    if (yaPuesto.parentNode) yaPuesto.parentNode.removeChild(yaPuesto);
                    if (colPrev && colPrev.classList && colPrev.classList.contains('dcl-bld-col')) dclBldSetColEmpty(colPrev);
                }

                // Si la columna ya tenía algo, se descarta antes de ocuparla
                var prev = col.querySelector('.dcl-section');
                col.innerHTML = '';
                if (prev) dclBldReturnToPool(prev);
                col.appendChild(secNew);
                _bldDraggingTile.classList.add('dcl-bld-tile--placed');
                _bldDraggingTile = null;
            }
            dclBldUpdateCounter();
        });
    }

    // Devuelve una sección colocada al pool (la oculta del canvas, desmarca tile)
    // Quitar del canvas = destruir el placeholder y desmarcar su tile. Ya no hay
    // sección real que devolver a #dcl-content: el dashboard nunca se desarma.
    function dclBldReturnToPool(sec) {
        if (!sec) return;
        var pool = document.getElementById('dcl-bld-pool');
        var tile = pool && pool.querySelector('.dcl-bld-tile[data-section="' + sec.getAttribute('data-section') + '"]');
        if (tile) tile.classList.remove('dcl-bld-tile--placed');
        if (sec.parentNode) sec.parentNode.removeChild(sec);
    }

    // Restablece una columna del builder a estado vacío (slot placeholder)
    function dclBldSetColEmpty(col) {
        if (!col) return;
        col.innerHTML = '';
        col.appendChild(dclMakeColSlot(true));
    }

    // Lee las filas del canvas modal y construye cfg.rows (modelo slots). Devuelve
    // el cfg actualizado, o null si no hay ninguna sección colocada.
    function dclBldCollectCfg() {
        var canvas = dclBldCanvas();
        if (!canvas) return null;
        var rows = Array.prototype.slice.call(canvas.querySelectorAll('.dcl-bld-row'));
        var cfg = dclGetCfg();
        cfg.rows = [];
        if (!cfg.sectionHeights) cfg.sectionHeights = {};
        delete cfg.sectionHidden; delete cfg.sectionOrder;
        delete cfg.sectionWidths; delete cfg.cols;
        var hasAny = false;
        for (var r = 0; r < rows.length; r++) {
            var numCols = Math.max(1, Math.min(4, parseInt(rows[r].getAttribute('data-row-cols') || '1', 10)));
            var colEls = rows[r].querySelectorAll('.dcl-bld-col');
            var slots = [];
            var rowHas = false;
            for (var c = 0; c < numCols; c++) {
                var sec = colEls[c] ? colEls[c].querySelector('.dcl-section') : null;
                if (sec) {
                    var sid = sec.getAttribute('data-section');
                    slots.push(sid);
                    cfg.sectionHeights[sid] = sec.getAttribute('data-height') || '0';
                    rowHas = true; hasAny = true;
                } else { slots.push(null); }
            }
            if (rowHas) cfg.rows.push({ cols: numCols, slots: slots });
        }
        return hasAny ? cfg : null;
    }

    // Muestra el error "agrega al menos 1 sección" en el hint del builder
    function dclBldWarnEmpty() {
        var hint = document.getElementById('dcl-bld-hint');
        if (hint) hint.innerHTML = '<i class="mdi mdi-alert-outline" style="color:#ef4444"></i>&nbsp;' +
            '<span style="color:#ef4444">Agrega al menos 1 sección al tablero antes de guardar.</span>';
    }

    // Aplicar sin nombrar: solo persiste el layout activo y cierra el builder.
    function dclBldApplyOnly() {
        var cfg = dclBldCollectCfg();
        if (!cfg) { dclBldWarnEmpty(); return; }
        // Sin dclSaveCfg aquí: escribiría en el nivel EN PANTALLA aunque se haya
        // armado otra categoría. dclExitBuilderMode persiste donde corresponde.
        var nivelA = dclBldNivelDestino();
        var nomA = dclBldPersistirEnLayout(cfg, nivelA);   // vuelca sobre el layout editado
        if (nivelA === dclNivelActual()) dclSetActiveLayoutName(nomA || 'Personalizado');
        dclExitBuilderMode(true, cfg);
        if (nomA) dclSwalToast('Layout "' + nomA + '" actualizado');
    }

    // Guardar como...: aplica el layout, cierra el builder y pide nombre (SweetAlert).
    function dclBldSaveAndExit() {
        var cfg = dclBldCollectCfg();
        if (!cfg) { dclBldWarnEmpty(); return; }
        // El nivel se lee ANTES de salir: dclExitBuilderMode limpia el estado
        // del builder y dclBldNivelDestino() volvería a caer en el nivel actual.
        var nivel = dclBldNivelDestino();
        // Si se vena editando un layout concreto, se actualiza ESE y no se pide
        // un nombre nuevo: si no, cada edición dejaba un duplicado.
        var nom = dclBldPersistirEnLayout(cfg, nivel);
        dclExitBuilderMode(true, cfg);
        if (nom) {
            if (nivel === dclNivelActual()) dclSetActiveLayoutName(nom);
            dclSwalToast('Layout "' + nom + '" actualizado');
        } else {
            dclPromptSaveLayout(cfg, nivel);
        }
    }

    // save=true → aplica cfg ya recogido; save=false → cancela y restaura.
    function dclExitBuilderMode(save, presetCfg) {
        var overlay = document.getElementById('dcl-bld-overlay');
        var canvas = dclBldCanvas();
        var content = document.getElementById('dcl-content');
        if (!content) return;

        if (save) {
            var cfg = presetCfg || dclBldCollectCfg();
            if (!cfg) {           // nada colocado → tratar como cancelar
                save = false;
            } else {
                // Con placeholders no hay nada que mover de vuelta: el canvas se
                // descarta con el overlay y dclApplySectionState reconstruye el
                // dashboard real desde cfg.rows.
                //
                // Si se armó OTRA categoría, el cfg no es el de la vista actual:
                // se guarda en su nivel y no se aplica aquí (dejaría slots vacíos).
                var nivelDest = dclBldNivelDestino();
                if (nivelDest !== dclNivelActual()) {
                    cfg._vista = nivelDest;
                    try {
                        localStorage.setItem('dcl_cfg_' + window._dclUsuarioId + '_' + nivelDest,
                                             JSON.stringify(cfg));
                    } catch (e) { }
                    dclSwalToast('Layout guardado en ' + dclNivelLabel(nivelDest) +
                                 '. Se verá al entrar a esa categoría.', 'info');
                } else {
                    cfg._vista = nivelDest;
                    dclSaveCfg(cfg);
                    setTimeout(dclApplySectionState, 0);
                }
            }
        }
        if (!save) {
            // Cancelar: el dashboard nunca se desarmó, solo se reaplica por si el
            // usuario tocó alturas mientras editaba.
            setTimeout(dclApplySectionState, 0);
        }

        document.body.classList.remove('dcl-building');
        if (overlay) {
            overlay.classList.remove('dcl-bld-overlay--open');
            setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 320);
        }
        _bldDraggingTile = null;
        _bldDraggingSection = null;
    }

    // ── Animación de entrada (splash) ────────────────────────────────────
    (function () {
        var splash = document.getElementById('dcl-splash');
        if (!splash) return;
        // Mostrar 2.6 s y luego desvanecer con scale-out
        setTimeout(function () {
            splash.classList.add('dcl-splash--out');
            setTimeout(function () { if (splash.parentNode) splash.parentNode.removeChild(splash); }, 780);
        }, 2600);
    })();

    // ── AJAX auto-refresh (sin postback, salta si hay overlay abierto) ───
    // Frecuencia a elección del usuario (botón reloj en la barra de filtros),
    // persistida en localStorage. 0 = auto-refresh desactivado.
    var _DCL_REFRESH_KEY = 'dcl_refresh_ms';
    var _DCL_REFRESH_PRESETS = [
        { ms: 0, lbl: 'Desactivado' },
        { ms: 15000, lbl: '15 segundos' },
        { ms: 30000, lbl: '30 segundos' },
        { ms: 60000, lbl: '1 minuto' },
        { ms: 120000, lbl: '2 minutos' },
        { ms: 300000, lbl: '5 minutos' },
        { ms: 600000, lbl: '10 minutos' },
        { ms: 1800000, lbl: '30 minutos' }
    ];
    var _dclRefreshTimer = null;
    var _dclCountdownTimer = null;
    var _dclRefreshMs = dclGetRefreshMs();

    function dclGetRefreshMs() {
        var raw = null;
        try { raw = localStorage.getItem(_DCL_REFRESH_KEY); } catch (e) { }
        if (raw === null) return 60000; // default: 1 minuto
        var ms = parseInt(raw, 10);
        if (isNaN(ms) || ms < 0) return 60000;
        return ms;
    }

    function dclSetRefreshMs(ms) {
        _dclRefreshMs = ms;
        try { localStorage.setItem(_DCL_REFRESH_KEY, String(ms)); } catch (e) { }
        dclStartAutoRefresh();
        dclStartCountdown();
        dclUpdateRefreshBtnUI();
    }

    function dclFormatIntervalo(ms) {
        var seg = Math.round(ms / 1000);
        if (seg < 60) return seg + ' s';
        var min = Math.round(seg / 60);
        return min + ' min';
    }

    function dclUpdateRefreshBtnUI() {
        var btn = document.getElementById('dcl-refresh-btn');
        if (!btn) return;
        if (_dclRefreshMs <= 0) {
            btn.title = 'Actualización automática: desactivada';
            btn.classList.add('dcl-refresh-btn--off');
        } else {
            btn.title = 'Actualización automática: cada ' + dclFormatIntervalo(_dclRefreshMs);
            btn.classList.remove('dcl-refresh-btn--off');
        }
    }

    // ¿El usuario tiene algo abierto encima del tablero? Si lo hay, el
    // auto-refresh NO debe correr: reemplaza #dcl-content y llama dclInit(), lo
    // que cerraba de golpe el dropdown o modal que se estaba usando.
    //
    // Antes se enumeraban 4 ids sueltos y quedaban fuera "Mis Layouts", el panel
    // de actualización automática, el de meta, los prompt/confirm y el selector
    // de dashboards de presentación — todos ellos se cerraban solos. Se listan
    // por selector para que agregar un panel nuevo no vuelva a romper esto:
    // los paneles del dashboard comparten el shell .dcl-layouts-panel.
    var _DCL_OVERLAY_SELS = [
        '#dcl-pres-overlay',
        '#dcl-bld-overlay',
        '#dcl-pres-picker',
        '#dcl-pres-dashsel',
        '#dcl-pres-help',
        '.dcl-layouts-panel',   // Mis Layouts, refresh, meta, prompt, confirm
        '.dcl-cfg-panel',
        '.dcl-onb-pop',         // tour guiado
        '.dcl-onb-wel'          // overlay de bienvenida
    ];

    function dclHayOverlayAbierto() {
        for (var i = 0; i < _DCL_OVERLAY_SELS.length; i++) {
            var els = document.querySelectorAll(_DCL_OVERLAY_SELS[i]);
            for (var j = 0; j < els.length; j++) {
                var el = els[j];
                if (!el.parentNode) continue;
                if (el.style && el.style.display === 'none') continue;
                return true;
            }
        }
        return false;
    }

    // ══════════════════════════════════════════════════════════════
    // SISTEMA DE CONFIGURACIONES GUARDADAS (localStorage)
    // ══════════════════════════════════════════════════════════════
    function dclGetSavedLayouts(nivel) {
        try { return JSON.parse(localStorage.getItem(_dclSavedKeyFn(nivel)) || '[]'); } catch (e) { return []; }
    }
    function dclSetSavedLayouts(arr, nivel) {
        try { localStorage.setItem(_dclSavedKeyFn(nivel), JSON.stringify(arr)); } catch (e) { }
    }

    // ── Layout "Por defecto del sistema" (auto-creado, protegido) ─────────
    // El sistema garantiza SIEMPRE un layout base llamado "Por defecto del
    // sistema" en Mis Layouts. Se crea automáticamente la primera vez, es el
    // default inicial y no se puede eliminar ni renombrar (isSystem:true).
    var _dclSystemLayoutId = 'cfg_system_default';
    // El layout del sistema almacena AMBAS vistas (general / instalación). El
    // campo `cfg` refleja la vista actual; `cfgGeneral`/`cfgInstalacion` guardan
    // cada variante. Así al cambiar de vista se aplica el default correcto.
    function dclEnsureSystemLayout() {
        var saved = dclGetSavedLayouts();
        var sys = null, idx = -1;
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === _dclSystemLayoutId || saved[i].isSystem) { sys = saved[i]; idx = i; break; }
        }
        var cfgGen = dclDefaultCfg('general');
        var cfgIns = dclDefaultCfg('instalacion');
        var cfgZon = dclDefaultCfg('zona');
        var cfgAct = dclDefaultCfg();   // variante del nivel actual (incluye zona)
        if (!sys) {
            var hayDefault = false;
            for (var j = 0; j < saved.length; j++) if (saved[j].isDefault) { hayDefault = true; break; }
            sys = {
                id: _dclSystemLayoutId,
                name: 'Por defecto del sistema',
                cfg: cfgAct,
                cfgGeneral: cfgGen,
                cfgInstalacion: cfgIns,
                cfgZona: cfgZon,
                date: new Date().toISOString(),
                isDefault: !hayDefault,
                isSystem: true
            };
            saved.unshift(sys);           // siempre primero en la lista
        } else {
            // Mantenerlo siempre actualizado al default del sistema (no editable)
            sys.id = _dclSystemLayoutId;
            sys.name = 'Por defecto del sistema';
            sys.isSystem = true;
            sys.cfgGeneral = cfgGen;
            sys.cfgInstalacion = cfgIns;
            sys.cfgZona = cfgZon;
            sys.cfg = cfgAct;
            // Asegurar que esté primero en la lista
            if (idx > 0) { saved.splice(idx, 1); saved.unshift(sys); }
        }
        dclSetSavedLayouts(saved);
        return sys;
    }

    // Garantiza que el layout del sistema exista, SIN reescribirlo si ya está
    // (para usar al abrir el panel sin pisar nada).
    function dclEnsureSystemLayoutExists() {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].isSystem) return saved[i];
        }
        return dclEnsureSystemLayout();
    }

    // Devuelve el cfg correcto de un layout según la vista actual (para el
    // layout del sistema que tiene cfgGeneral/cfgInstalacion).
    function dclLayoutCfgForView(layout) {
        if (!layout) return null;
        if (layout.isSystem) {
            // El layout del sistema guarda una variante por nivel: si se resolviera
            // solo por general/instalación, en Zona se aplicaría la de instalación
            // (widgets de otro nivel → slots vacíos).
            var nivel = dclNivelActual();
            var c = nivel === 'zona'        ? layout.cfgZona
                  : nivel === 'instalacion' ? layout.cfgInstalacion
                  :                           layout.cfgGeneral;
            if (c && c.rows && c.rows.length) return c;
            return dclDefaultCfg(nivel);   // variante ausente (layout viejo) → default del nivel
        }
        return layout.cfg || null;
    }

    // ── Diálogo propio para pedir un nombre (reemplaza el prompt() nativo) ─
    // Reutiliza el mismo shell .dcl-layouts-panel/.dcl-layouts-box que "Mis
    // Layouts" y "Actualización automática", sin depender de SweetAlert2.
    // onOk recibe el nombre ya trimmeado.
    function dclSwalPrompt(opts, onOk) {
        opts = opts || {};
        var old = document.getElementById('dcl-prompt-panel');
        if (old && old.parentNode) old.parentNode.removeChild(old);

        var panel = document.createElement('div');
        panel.id = 'dcl-prompt-panel';
        panel.className = 'dcl-layouts-panel dcl-prompt-panel';
        panel.onclick = function (e) { if (e.target === panel) dclClosePromptPanel(); };

        panel.innerHTML =
            '<div class="dcl-layouts-box dcl-prompt-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-pencil-outline"></i>&nbsp;' + dclHtmlEsc(opts.title || 'Nombre') + '</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="cancel" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-prompt-body">' +
            '<input type="text" class="dcl-refresh-custom-input dcl-prompt-input" id="dcl-prompt-input" placeholder="' + dclHtmlEsc(opts.placeholder || '') + '" value="' + dclHtmlEsc(opts.value || '') + '" />' +
            '<span class="dcl-refresh-custom-err" id="dcl-prompt-err"></span>' +
            '</div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="cancel">Cancelar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="ok">' + dclHtmlEsc(opts.confirmText || 'Guardar') + '</button>' +
            '</div>' +
            '</div>';

        function confirmar() {
            var inp = document.getElementById('dcl-prompt-input');
            var err = document.getElementById('dcl-prompt-err');
            var v = ((inp && inp.value) || '').trim();
            if (!v) {
                if (inp) { inp.classList.add('dcl-refresh-custom-input--err'); inp.focus(); }
                if (err) err.textContent = 'Ingresa un nombre.';
                return;
            }
            dclClosePromptPanel();
            onOk(v);
        }

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            if (!el || el === panel) return;
            var act = el.getAttribute('data-act');
            if (act === 'cancel') dclClosePromptPanel();
            else if (act === 'ok') confirmar();
        });

        document.body.appendChild(panel);

        var inp = document.getElementById('dcl-prompt-input');
        if (inp) {
            inp.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); confirmar(); }
                else if (e.key === 'Escape' || e.keyCode === 27) { dclClosePromptPanel(); }
            });
            inp.addEventListener('input', function () {
                inp.classList.remove('dcl-refresh-custom-input--err');
                var err = document.getElementById('dcl-prompt-err');
                if (err) err.textContent = '';
            });
        }

        requestAnimationFrame(function () {
            panel.classList.add('dcl-layouts-panel--open');
            if (inp) { inp.focus(); inp.select(); }
        });
    }

    function dclClosePromptPanel() {
        var panel = document.getElementById('dcl-prompt-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 200);
    }

    // ── Diálogo propio de confirmación (Sí/No) ─────────────────────────────
    function dclSwalConfirm(opts, onOk) {
        opts = opts || {};
        var old = document.getElementById('dcl-prompt-panel');
        if (old && old.parentNode) old.parentNode.removeChild(old);

        var panel = document.createElement('div');
        panel.id = 'dcl-prompt-panel';
        panel.className = 'dcl-layouts-panel dcl-prompt-panel';
        panel.onclick = function (e) { if (e.target === panel) dclClosePromptPanel(); };

        panel.innerHTML =
            '<div class="dcl-layouts-box dcl-prompt-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-alert-outline"></i>&nbsp;' + dclHtmlEsc(opts.title || 'Confirmar') + '</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="cancel" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-prompt-body"><p class="dcl-prompt-text">' + dclHtmlEsc(opts.text || '') + '</p></div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="cancel">' + dclHtmlEsc(opts.cancelText || 'Cancelar') + '</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary dcl-btn--danger" data-act="ok">' + dclHtmlEsc(opts.confirmText || 'Eliminar') + '</button>' +
            '</div>' +
            '</div>';

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && el.getAttribute('data-act'))) el = el.parentNode;
            if (!el || el === panel) return;
            var act = el.getAttribute('data-act');
            if (act === 'cancel') dclClosePromptPanel();
            else if (act === 'ok') { dclClosePromptPanel(); onOk(); }
        });

        document.body.appendChild(panel);
        requestAnimationFrame(function () { panel.classList.add('dcl-layouts-panel--open'); });
    }

    // ── Toast de confirmación breve (no bloqueante, propio) ────────────────
    // opts.duracion (ms, default 2200) = cierre automático. Devuelve un
    // objeto con .close() para cerrar antes (ej. cuando termina un AJAX).
    function dclSwalToast(msg, icon, opts) {
        opts = opts || {};
        var wrap = document.getElementById('dcl-toast-wrap');
        if (!wrap) {
            wrap = document.createElement('div');
            wrap.id = 'dcl-toast-wrap';
            wrap.className = 'dcl-toast-wrap';
            document.body.appendChild(wrap);
        }
        var ic = icon === 'info' ? 'information-outline'
            : icon === 'error' ? 'close-circle-outline'
            : icon === 'warning' ? 'alert-outline'
            : icon === 'loading' ? 'autorenew'
            : 'check-circle-outline';
        var toast = document.createElement('div');
        toast.className = 'dcl-toast dcl-toast--' + (icon || 'success');
        toast.innerHTML = '<i class="mdi mdi-' + ic + '"></i><span>' + dclHtmlEsc(msg) + '</span>';
        wrap.appendChild(toast);
        requestAnimationFrame(function () { toast.classList.add('dcl-toast--in'); });

        var cerrado = false;
        function cerrar() {
            if (cerrado) return;
            cerrado = true;
            toast.classList.remove('dcl-toast--in');
            setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 220);
        }
        var timer = setTimeout(cerrar, opts.duracion || 2200);
        return { close: function () { clearTimeout(timer); cerrar(); } };
    }

    // Guarda el cfg actual como layout con nombre (llamado desde el builder y panel)
    // nivelForzado: lo pasa el builder cuando se armó una categoría distinta a
    // la vista actual, para que el layout se guarde donde corresponde.
    function dclPromptSaveLayout(cfg, nivelForzado) {
        var nivel = nivelForzado || dclNivelActual();
        dclSwalPrompt({
            title: 'Guardar layout en ' + dclNivelLabel(nivel),
            placeholder: 'Nombre del layout',
            value: 'Mi layout ' + new Date().toLocaleDateString('es-CL'),
            confirmText: 'Guardar'
        }, function (name) {
            var saved = dclGetSavedLayouts(nivel);
            var isFirst = saved.length === 0;
            saved.push({
                id: 'cfg_' + Date.now(), name: name,
                cfg: JSON.parse(JSON.stringify(cfg || dclGetCfg())),
                nivel: nivel,   // queda asociado a la categoría donde se guardó
                date: new Date().toISOString(), isDefault: isFirst
            });
            dclSetSavedLayouts(saved, nivel);
            // El nombre activo solo aplica si el layout es de la vista en pantalla.
            if (nivel === dclNivelActual()) dclSetActiveLayoutName(name);
            dclSwalToast('Layout "' + name + '" guardado en ' + dclNivelLabel(nivel));
        });
    }

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
    // dentro de la ventana.
    function dclOnbPosicionarPop(pop, r) {
        var pw = pop.offsetWidth  || 340;
        var ph = pop.offsetHeight || 200;
        var m  = 14;

        var top = r.bottom + m;
        if (top + ph > window.innerHeight - 10) {
            top = r.top - ph - m;
            if (top < 10) top = Math.max(10, (window.innerHeight - ph) / 2);
        }
        var left = r.left + (r.width / 2) - (pw / 2);
        if (left < 10) left = 10;
        if (left + pw > window.innerWidth - 10) left = window.innerWidth - pw - 10;

        pop.style.top  = top + 'px';
        pop.style.left = left + 'px';
    }

    function dclOnboardingEnd() {
        dclOnbMarcarVisto();
        dclOnbDemoParar();
        var ov = document.getElementById('dcl-onb');
        document.removeEventListener('keydown', _dclOnbTeclas);
        document.body.classList.remove('dcl-onb-activo');
        if (!ov) return;
        ov.classList.remove('dcl-onb--open');
        setTimeout(function () { if (ov.parentNode) ov.parentNode.removeChild(ov); }, 240);
    }

    // ── Restablecer configuración ─────────────────────────────────────────
    // Deja el dashboard como viene de fábrica: borra layouts guardados, la
    // estructura de los TRES niveles, la meta y el intervalo de auto-refresh,
    // tanto en el navegador como en la BD del usuario. El tema claro/oscuro NO
    // se toca: es una preferencia de visualización, no configuración del
    // dashboard, y resetearlo sería un efecto sorpresa.
    function dclResetConfiguracion() {
        dclSwalConfirm({
            title: 'Restablecer configuración',
            text: 'Se eliminarán tus layouts guardados y volverá todo al layout por ' +
                  'defecto del sistema en General, Por Instalación y Por Zona. También se ' +
                  'restablecen la meta de cumplimiento y la frecuencia de actualización. ' +
                  'Esta acción no se puede deshacer.',
            confirmText: 'Sí, restablecer'
        }, function () {
            // 1. Local: todas las claves del dashboard salvo el tema.
            try {
                var borrar = [];
                for (var i = 0; i < localStorage.length; i++) {
                    var k = localStorage.key(i);
                    // Se preservan el tema (preferencia visual) y la marca del
                    // tutorial: restablecer el layout no es motivo para volver a
                    // mostrarle el onboarding a quien ya lo vio o lo saltó.
                    if (k && k.indexOf('dcl_') === 0 && k !== 'dcl_theme' && k !== _DCL_ONB_KEY) borrar.push(k);
                }
                for (var j = 0; j < borrar.length; j++) localStorage.removeItem(borrar[j]);
            } catch (e) { }

            try {
                sessionStorage.removeItem('dcl_dflt_applied');
                sessionStorage.removeItem('dcl_srv_loaded');
            } catch (e) { }

            // 2. Servidor: la config persistida de los tres niveles.
            dclBorrarCfgServidor(['checklists_general', 'checklists_instalacion', 'checklists_zona']);

            // 3. Reconstruir el estado por defecto y repintar.
            //    dclGetRefreshMs() ya devuelve el valor de fábrica: su clave se borró.
            _dclRefreshMs = dclGetRefreshMs();
            dclEnsureSystemLayout();
            dclSaveCfg(dclDefaultCfg());
            dclSetActiveLayoutName('Por defecto del sistema');
            dclApplySectionState();
            dclUpdateRefreshBtnUI();
            dclMetaInputSync();
            dclStartAutoRefresh();
            dclRenderActiveLayoutName();
            dclSwalToast('Configuración restablecida', 'success');
            dclAutoRefreshAjax(true);
        });
    }

    function dclBorrarCfgServidor(modulos) {
        if (typeof _dclWsBase === 'undefined') return;
        for (var i = 0; i < modulos.length; i++) {
            try {
                var xhr = new XMLHttpRequest();
                xhr.open('POST', _dclWsBase + '/DeleteConfig', true);
                xhr.setRequestHeader('Content-Type', 'application/json');
                xhr.send(JSON.stringify({ module: modulos[i] }));
            } catch (e) { }
        }
    }

    // Crea un layout NUEVO y entra al builder con el canvas EN BLANCO.
    // Antes partía del default del sistema: el usuario tenía que borrar widgets
    // uno por uno para poder armar el suyo desde cero.
    function dclNewLayout() {
        dclSwalPrompt({
            title: 'Nuevo layout',
            placeholder: 'Nombre del nuevo layout',
            value: 'Nuevo layout ' + new Date().toLocaleDateString('es-CL'),
            confirmText: 'Crear'
        }, function (name) {
            var saved = dclGetSavedLayouts();
            var base = { rows: [], sectionHeights: {} };   // lienzo vacío
            var nuevoId = 'cfg_' + Date.now();
            saved.push({
                id: nuevoId, name: name, cfg: base,
                nivel: dclNivelActual(),   // categoría a la que queda asociado
                date: new Date().toISOString(), isDefault: false
            });
            dclSetSavedLayouts(saved);
            dclSaveCfg(base);
            dclSetActiveLayoutName(name);
            dclApplySectionState();
            dclCloseLayoutsPanel();
            // Se pasa el id: lo que se arme queda guardado EN ese layout y no
            // solo como cfg activo (antes quedaba con rows vacío).
            setTimeout(function () { dclEnterBuilderMode(true, nuevoId); }, 80);
        });
    }

    function dclRenameSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                if (saved[i].isSystem) { dclSwalToast('El layout del sistema no se puede renombrar', 'info'); return; }
                (function (idx) {
                    dclSwalPrompt({
                        title: 'Renombrar layout',
                        value: saved[idx].name || '',
                        confirmText: 'Renombrar'
                    }, function (nn) {
                        var s2 = dclGetSavedLayouts();
                        if (s2[idx]) { s2[idx].name = nn; dclSetSavedLayouts(s2); }
                        dclOpenLayoutsPanel();
                    });
                })(i);
                return;
            }
        }
    }

    function dclLoadSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                // Para el layout del sistema, usar la variante de la vista actual
                var src = dclLayoutCfgForView(saved[i]) || saved[i].cfg || {};
                var clone = JSON.parse(JSON.stringify(src));
                // Conservar las preferencias de altura/título/header del cfg actual
                var cur = dclGetCfg();
                if (cur.sectionHeights && !clone.sectionHeights) clone.sectionHeights = cur.sectionHeights;
                if (cur.sectionHeightsPx) clone.sectionHeightsPx = cur.sectionHeightsPx;
                if (cur.sectionTitles) clone.sectionTitles = cur.sectionTitles;
                if (cur.sectionHiddenHd) clone.sectionHiddenHd = cur.sectionHiddenHd;
                // Debe marcarse con el NIVEL (incluido 'zona'): si no,
                // dclReconcileVistaLayout lo ve como de otra vista y descarta el
                // layout que el usuario acaba de aplicar.
                clone._vista = dclNivelActual();
                dclSaveCfg(clone);
                dclSetActiveLayoutName(saved[i].name || '');
                dclCloseLayoutsPanel();
                // Reaplicar tras cerrar el panel (asegura DOM estable y un solo render)
                setTimeout(function () {
                    dclApplySectionState();
                    dclInitSectionDnD();
                }, 0);
                return;
            }
        }
    }

    // Editar un layout guardado: lo aplica y abre "Armar Dashboard" sobre él,
    // para no obligar a "Aplicar" y después buscar el botón del builder aparte.
    // Se entra SIN el flag enBlanco: el builder debe arrancar con las filas del
    // layout, que es justamente lo que se va a editar.
    function dclEditSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id !== id) continue;

            // El layout del sistema es de solo lectura: editarlo lo pisaría para
            // todos los niveles. En vez de bloquear, se duplica y se edita la
            // copia — el usuario igual termina donde quería ir.
            if (saved[i].isSystem) {
                var copia = {
                    id      : 'cfg_' + Date.now(),
                    name    : 'Mi dashboard',
                    cfg     : JSON.parse(JSON.stringify(dclLayoutCfgForView(saved[i]) || saved[i].cfg || {})),
                    nivel   : dclNivelActual(),
                    date    : new Date().toISOString(),
                    isDefault: false
                };
                // Nombre libre: si "Mi dashboard" ya existe, se numera.
                var n = 2;
                for (var k = 0; k < saved.length; k++) {
                    if (saved[k].name === copia.name) { copia.name = 'Mi dashboard ' + n; n++; k = -1; }
                }
                saved.push(copia);
                dclSetSavedLayouts(saved);
                dclSwalToast('Se creó "' + copia.name + '" para editar sin tocar el del sistema', 'info');
                dclEditSavedLayout(copia.id);
                return;
            }

            dclLoadSavedLayout(id);   // aplica el cfg y cierra el panel
            // dclLoadSavedLayout reaplica el DOM en un setTimeout(0); el builder
            // tiene que entrar DESPUÉS de ese render, si no poolea secciones que
            // aún se están reordenando.
            setTimeout(function () { dclEnterBuilderMode(false, id); }, 120);
            return;
        }
    }

    // Aplica el layout marcado como default (si existe) al cargar la página.
    // Se ejecuta una sola vez por sesión para no pisar cambios en vivo del usuario.
    function dclApplyDefaultSavedLayout() {
        if (sessionStorage.getItem('dcl_dflt_applied')) return;
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].isDefault) {
                sessionStorage.setItem('dcl_dflt_applied', '1');
                var src = dclLayoutCfgForView(saved[i]) || saved[i].cfg || {};
                var clone = JSON.parse(JSON.stringify(src));
                clone._vista = dclNivelActual();
                dclSaveCfg(clone);
                dclSetActiveLayoutName(saved[i].name || '');
                return;
            }
        }
        sessionStorage.setItem('dcl_dflt_applied', '1');
    }

    function dclDeleteSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        // El layout del sistema no se puede eliminar
        var target = null;
        for (var k = 0; k < saved.length; k++) {
            if (saved[k].id === id) { target = saved[k]; break; }
        }
        if (!target) return;
        if (target.isSystem) {
            dclSwalToast('El layout del sistema no se puede eliminar', 'info');
            return;
        }
        dclSwalConfirm({
            title: 'Eliminar layout',
            text: '¿Eliminar el layout "' + target.name + '"? Esta acción no se puede deshacer.',
            confirmText: 'Eliminar'
        }, function () {
            var cur = dclGetSavedLayouts();
            var newArr = [];
            var eraDefault = false;
            for (var i = 0; i < cur.length; i++) {
                if (cur[i].id !== id) newArr.push(cur[i]);
                else if (cur[i].isDefault) eraDefault = true;
            }
            // Si se borró el default, devolver el default al layout del sistema
            if (eraDefault) {
                for (var j = 0; j < newArr.length; j++) newArr[j].isDefault = !!newArr[j].isSystem;
            }
            dclSetSavedLayouts(newArr);
            dclOpenLayoutsPanel();
            dclSwalToast('Layout "' + target.name + '" eliminado');
        });
    }

    function dclSetDefaultLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) saved[i].isDefault = (saved[i].id === id);
        dclSetSavedLayouts(saved);
        dclOpenLayoutsPanel();
    }

    function dclDuplicateSavedLayout(id) {
        var saved = dclGetSavedLayouts();
        for (var i = 0; i < saved.length; i++) {
            if (saved[i].id === id) {
                var copy = { id: 'cfg_' + Date.now(), name: saved[i].name + ' (copia)', cfg: saved[i].cfg, date: new Date().toISOString(), isDefault: false };
                saved.push(copy);
                dclSetSavedLayouts(saved);
                dclOpenLayoutsPanel();
                return;
            }
        }
    }

    // ── Nombre del layout activo (se fusiona en el título del master) ────
    function _dclActiveNameKey() { return 'dcl_active_name_' + dclWsModule(); }
    function dclSetActiveLayoutName(name) {
        try {
            if (name) localStorage.setItem(_dclActiveNameKey(), name);
            else localStorage.removeItem(_dclActiveNameKey());
        } catch (e) { }
        dclRenderActiveLayoutName();
    }
    function dclGetActiveLayoutName() {
        try { return localStorage.getItem(_dclActiveNameKey()) || ''; } catch (e) { return ''; }
    }
    // Título del master limpio (DashboardChecklist.master) + nombre del
    // layout activo, ej: "DASHBOARD GENERAL — CUMPLIMIENTO DE CHECKLISTS | Por defecto del sistema"
    function dclRenderActiveLayoutName() {
        var src = document.querySelector('.dcl-page-title-data');
        var dest = document.querySelector('.dcl-mt-title');
        if (!src || !dest) return;
        var texto = src.textContent.trim();
        var name = dclGetActiveLayoutName();
        if (name) texto += ' | ' + name;
        dest.textContent = texto;
    }

    // Toggle del dropdown Mis Layouts (abre/cierra anclado al botón)
    function dclToggleLayoutsPanel(btn) {
        if (document.getElementById('dcl-layouts-panel')) { dclCloseLayoutsPanel(); return; }
        dclOpenLayoutsPanel(btn);
    }

    function dclOpenLayoutsPanel(anchorBtn) {
        dclCloseLayoutsPanel();
        dclEnsureSystemLayoutExists();     // crear el layout del sistema solo si NO existe (sin reescribirlo)
        var saved = dclGetSavedLayouts();
        var btn = anchorBtn || document.getElementById('dcl-layouts-btn');
        var panel = document.createElement('div');
        panel.id = 'dcl-layouts-panel';
        panel.className = 'dcl-layouts-panel';
        // Backdrop transparente para cerrar al hacer click fuera
        panel.onclick = function (e) { if (e.target === panel) dclCloseLayoutsPanel(); };

        var _activeName = dclGetActiveLayoutName();   // layout actualmente aplicado en la vista
        var itemsHtml = '';
        if (!saved.length) {
            itemsHtml = '<div class="dcl-layouts-empty"><i class="mdi mdi-bookmark-outline"></i>' +
                        '<p>Sin layouts en ' + dclEsc(dclNivelLabel()) + '</p>' +
                        '<p class="dcl-layouts-empty-sub">Cada categoría tiene sus propios layouts. ' +
                        'Crea uno nuevo o guarda el actual con los botones de abajo</p></div>';
        } else {
            for (var i = 0; i < saved.length; i++) {
                var s = saved[i];
                var dt = s.date ? new Date(s.date).toLocaleDateString('es-CL') : '';
                var nm = dclHtmlEsc(s.name || 'Sin nombre');
                var esActivo = !!(_activeName && s.name === _activeName);
                var defMark = s.isDefault ? ' <span class="dcl-layouts-dflt-chip">default</span>' : '';
                var actMark = esActivo ? ' <span class="dcl-layouts-active-chip"><i class="mdi mdi-check"></i> activo</span>' : '';
                var sysMark = s.isSystem ? ' <span class="dcl-layouts-sys-chip"><i class="mdi mdi-shield-check-outline"></i> sistema</span>' : '';
                var idAttr = dclHtmlEsc(s.id);
                // Acciones: el layout del sistema solo permite Aplicar/Duplicar/Default
                var actsHtml =
                    '<button type="button" class="dcl-layouts-act-btn" data-act="load" data-id="' + idAttr + '" title="Aplicar"><i class="mdi mdi-check-circle-outline"></i></button>' +
                    '<button type="button" class="dcl-layouts-act-btn" data-act="dup" data-id="' + idAttr + '" title="Duplicar"><i class="mdi mdi-content-copy"></i></button>' +
                    '<button type="button" class="dcl-layouts-act-btn" data-act="default" data-id="' + idAttr + '" title="Marcar como default"><i class="mdi mdi-star' + (s.isDefault ? '' : '-outline') + '"></i></button>';
                if (s.isSystem) {
                    // También editable: no se toca el original, se duplica y se
                    // abre el builder sobre la copia (ver dclEditSavedLayout).
                    // Sin esto, quien tiene aplicado el layout del sistema —lo
                    // más habitual— no veía ningún botón de editar.
                    actsHtml +=
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--edit" data-act="edit" data-id="' + idAttr + '" title="Editar (crea una copia editable)"><i class="mdi mdi-view-quilt"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--lock" disabled title="Layout protegido del sistema"><i class="mdi mdi-lock-outline"></i></button>';
                } else {
                    actsHtml =
                        '<button type="button" class="dcl-layouts-act-btn" data-act="load" data-id="' + idAttr + '" title="Aplicar"><i class="mdi mdi-check-circle-outline"></i></button>' +
                        // Editar = aplicar el layout y abrir "Armar Dashboard" sobre él.
                        // Ícono de grilla, no lápiz: el lápiz ya es "Renombrar".
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--edit" data-act="edit" data-id="' + idAttr + '" title="Editar en Armar Dashboard"><i class="mdi mdi-view-quilt"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="rename" data-id="' + idAttr + '" title="Renombrar"><i class="mdi mdi-pencil-outline"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="dup" data-id="' + idAttr + '" title="Duplicar"><i class="mdi mdi-content-copy"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn" data-act="default" data-id="' + idAttr + '" title="Marcar como default"><i class="mdi mdi-star' + (s.isDefault ? '' : '-outline') + '"></i></button>' +
                        '<button type="button" class="dcl-layouts-act-btn dcl-layouts-act-btn--del" data-act="del" data-id="' + idAttr + '" title="Eliminar"><i class="mdi mdi-delete-outline"></i></button>';
                }
                // Categoría del layout: la guardada al crearlo o, para los
                // anteriores a este cambio, la del nivel donde está almacenado.
                var catChip = dclCatChip(s.nivel || dclNivelActual(), 'dcl-cat-chip--sm');

                itemsHtml +=
                    '<div class="dcl-layouts-item' + (esActivo ? ' dcl-layouts-item--active' : '') + (s.isSystem ? ' dcl-layouts-item--sys' : '') + '">' +
                    '<div class="dcl-layouts-item-info">' +
                    '<span class="dcl-layouts-item-name">' + nm + actMark + defMark + sysMark + '</span>' +
                    '<span class="dcl-layouts-item-date">' + catChip + '<span class="dcl-layouts-item-dt">' + dt + '</span></span>' +
                    '</div>' +
                    '<div class="dcl-layouts-item-acts">' + actsHtml + '</div>' +
                    '</div>';
            }
        }

        panel.innerHTML =
            '<div class="dcl-layouts-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-bookmark-multiple-outline"></i>&nbsp;Mis Layouts</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="close" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            // Categoría activa: deja claro que la lista es SOLO de este nivel y
            // que lo que se cree aquí quedará asociado a él.
            '<div class="dcl-layouts-cat">' +
            '<span class="dcl-layouts-cat-lbl">Categor&iacute;a</span>' +
            dclCatChip(dclNivelActual()) +
            '</div>' +
            '<div class="dcl-layouts-list">' + itemsHtml + '</div>' +
            '<div class="dcl-layouts-ft">' +
            '<button type="button" class="dcl-btn dcl-btn--ghost" data-act="new">' +
            '<i class="mdi mdi-plus-box-outline"></i>&nbsp;Crear nuevo</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="savecur">' +
            '<i class="mdi mdi-content-save-outline"></i>&nbsp;Guardar actual</button>' +
            '</div>' +
            '</div>';

        // Delegación de clicks (robusto: sin onclick inline con IDs)
        panel.addEventListener('click', function (e) {
            var btn = e.target;
            while (btn && btn !== panel && !(btn.getAttribute && btn.getAttribute('data-act'))) btn = btn.parentNode;
            if (!btn || btn === panel) return;
            var act = btn.getAttribute('data-act');
            var id = btn.getAttribute('data-id');
            if (act === 'load') dclLoadSavedLayout(id);
            else if (act === 'edit') dclEditSavedLayout(id);
            else if (act === 'rename') dclRenameSavedLayout(id);
            else if (act === 'dup') dclDuplicateSavedLayout(id);
            else if (act === 'default') dclSetDefaultLayout(id);
            else if (act === 'del') dclDeleteSavedLayout(id);
            else if (act === 'close') dclCloseLayoutsPanel();
            else if (act === 'new') dclNewLayout();
            else if (act === 'savecur') dclSaveCurrentLayout();
        });

        document.body.appendChild(panel);

        // Anclar el dropdown DEBAJO del botón de layouts
        var box = panel.querySelector('.dcl-layouts-box');
        if (box && btn) {
            var r = btn.getBoundingClientRect();
            var boxW = 340;
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

    function dclCloseLayoutsPanel() {
        var panel = document.getElementById('dcl-layouts-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 260);
    }

    // ── Skeleton de carga ─────────────────────────────────────────────────
    // Dibuja la ESTRUCTURA del layout al que se navega (mismas filas, columnas y
    // alturas del cfg de ese nivel) con bloques animados. Así el cambio de
    // dashboard no muestra datos viejos ni un salto en blanco.
    function dclSkeletonCard(secId, alturaNivel) {
        var reg = _DCL_SECTION_REGISTRY[secId] || {};
        var cat = reg.catClass || 'chart';
        var h   = _DCL_H_PX[parseInt(alturaNivel, 10) || 2] || 280;

        var cuerpo = '';
        if (cat === 'kpi') {
            cuerpo = '<div class="dcl-sk-kpis">' +
                     '<div class="dcl-sk-kpi"></div><div class="dcl-sk-kpi"></div>' +
                     '<div class="dcl-sk-kpi"></div><div class="dcl-sk-kpi"></div>' +
                     '</div>';
        } else if (cat === 'table') {
            cuerpo = '<div class="dcl-sk-rows">' +
                     '<div class="dcl-sk-line dcl-sk-line--hd"></div>' +
                     '<div class="dcl-sk-line"></div><div class="dcl-sk-line"></div>' +
                     '<div class="dcl-sk-line"></div><div class="dcl-sk-line dcl-sk-line--sm"></div>' +
                     '</div>';
        } else {
            cuerpo = '<div class="dcl-sk-rows">' +
                     '<div class="dcl-sk-bar"></div><div class="dcl-sk-bar dcl-sk-bar--2"></div>' +
                     '<div class="dcl-sk-bar dcl-sk-bar--3"></div><div class="dcl-sk-bar dcl-sk-bar--4"></div>' +
                     '</div>';
        }

        return '<div class="dcl-sk-card" style="min-height:' + h + 'px">' +
               '<div class="dcl-sk-hd"><span class="dcl-sk-dot"></span><span class="dcl-sk-tit"></span></div>' +
               '<div class="dcl-sk-body">' + cuerpo + '</div>' +
               '</div>';
    }

    function dclRenderSkeleton() {
        var content = document.getElementById('dcl-content');
        if (!content) return;

        // El nivel ya cambió en los hidden fields, así que dclGetCfg() devuelve
        // el layout del destino: el esqueleto calca esa grilla.
        var cfg    = dclGetCfg();
        var rows   = dclNormalizeRows(cfg.rows);
        if (!rows.length) rows = dclNormalizeRows(dclDefaultCfg().rows);
        var alturas = cfg.sectionHeights || {};

        var html = '<div class="dcl-skeleton" aria-busy="true" aria-label="Cargando dashboard">';
        for (var r = 0; r < rows.length; r++) {
            html += '<div class="dcl-sk-row" style="grid-template-columns:repeat(' + rows[r].cols + ',1fr)">';
            for (var c = 0; c < rows[r].slots.length; c++) {
                var slot = rows[r].slots[c];
                var sec  = dclSlotSec(slot);
                var span = dclSlotSpan(slot);
                if (!sec) { html += '<div></div>'; continue; }
                html += '<div style="grid-column:span ' + span + '">' +
                        dclSkeletonCard(sec, alturas[sec]) + '</div>';
            }
            html += '</div>';
        }
        html += '</div>';
        content.innerHTML = html;
    }

    // Si la carga falla, el esqueleto quedaría girando para siempre: se cambia
    // por un estado de error con reintento.
    function dclSkeletonError(msg) {
        var content = document.getElementById('dcl-content');
        if (!content) return;
        content.innerHTML =
            '<div class="dcl-sk-error">' +
            '<i class="mdi mdi-cloud-alert"></i>' +
            '<p class="dcl-sk-error-tit">No se pudo cargar el dashboard</p>' +
            '<p class="dcl-sk-error-msg">' + dclEsc(msg || '') + '</p>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" onclick="dclAutoRefreshAjax(true)">' +
            '<i class="mdi mdi-refresh"></i>&nbsp;Reintentar</button>' +
            '</div>';
    }

    // esNavegacion=true cuando viene de un drill-down (no del timer): en ese caso
    // el refresh no se puede saltar aunque haya un overlay abierto, y al terminar
    // hay que re-aplicar el layout del NUEVO nivel.
    function dclAutoRefreshAjax(esNavegacion) {
        if (!esNavegacion && dclHayOverlayAbierto()) return;

        var hfU = document.getElementById('hfUsuario');
        var hfC = document.getElementById('hfCliente');
        var hfI = document.getElementById('hfInstalacion');
        var hfZ = document.getElementById('hfZona');
        var hfD = document.getElementById('hfDesde');
        var hfH = document.getElementById('hfHasta');
        var hfN = document.getElementById('hfNomIns');
        if (!hfU || !hfU.value) return;

        var badge = document.getElementById('dcl-refresh-badge');
        if (badge) badge.classList.add('dcl-refreshing');

        // Navegación entre dashboards → esqueleto con la forma del layout destino.
        // Da sensación de continuidad (se ve DÓNDE va a aparecer cada widget) en
        // vez de dejar el contenido viejo congelado hasta que llegue la respuesta.
        // En el auto-refresh de fondo NO se usa: parpadearía todo cada ciclo.
        var toast = null;
        if (esNavegacion) dclRenderSkeleton();
        else toast = dclSwalToast('Actualizando...', 'loading', { duracion: 8000 });

        var params = JSON.stringify({
            usuario: parseInt(hfU.value) || 0,
            cliente: parseInt(hfC ? hfC.value : '0') || 0,
            instalacion: parseInt(hfI ? hfI.value : '0') || 0,
            zona: parseInt(hfZ ? hfZ.value : '0') || 0,
            desde: hfD ? hfD.value : '',
            hasta: hfH ? hfH.value : '',
            nomIns: hfN ? hfN.value : '',
            meta: dclGetMeta()
        });

        var url = window._dclWsAjaxUrl;
        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return;
            if (badge) badge.classList.remove('dcl-refreshing');
            if (toast) toast.close();
            if (xhr.status !== 200) {
                dclSwalToast('Error de conexión (' + xhr.status + ') al cargar el dashboard.', 'error');
                if (esNavegacion) dclSkeletonError('No se pudo conectar con el servidor.');
                return;
            }
            try {
                var resp = JSON.parse(xhr.responseText);
                var d = resp.d !== undefined ? resp.d : resp;
                // Un fallo del servidor se descartaba en silencio: el dashboard
                // quedaba con el contenido viejo y sin ninguna pista de por qué.
                if (!d || !d.ok) {
                    dclSwalToast((d && d.error) ? ('No se pudo cargar: ' + d.error)
                                                : 'No se pudo cargar el dashboard.', 'error');
                    if (esNavegacion) dclSkeletonError((d && d.error) ? d.error : 'No se pudo cargar el dashboard.');
                    return;
                }
                var content = document.getElementById('dcl-content');
                if (content) {
                    content.innerHTML = d.html;
                    setTimeout(function () {
                        dclInit();
                        // El refresh reemplaza el HTML: reabrir lo que el usuario
                        // tenía desplegado para no perder su contexto de lectura.
                        dclRestaurarRespuestasAbiertas();
                        if (esNavegacion) {
                            // El nivel cambió: aplicar SU layout (cada nivel tiene
                            // su propia cfg) y refrescar breadcrumb/título.
                            dclApplyDefaultCfgIfEmpty();
                            dclApplySectionState();
                            dclRenderBreadcrumb();
                            dclRenderActiveLayoutName();
                        }
                    }, 80);
                }
                var ts = document.querySelector('.dcl-refresh-text');
                if (ts && d.timestamp) ts.textContent = d.timestamp;
            } catch (e) { }
        };
        xhr.send(params);
    }

    function dclStartAutoRefresh() {
        if (_dclRefreshTimer) { clearInterval(_dclRefreshTimer); _dclRefreshTimer = null; }
        if (_dclRefreshMs > 0) {
            _dclRefreshTimer = setInterval(dclAutoRefreshAjax, _dclRefreshMs);
        }
    }

    // Countdown en el title del badge — sigue la frecuencia elegida por el usuario
    function dclStartCountdown() {
        if (_dclCountdownTimer) { clearInterval(_dclCountdownTimer); _dclCountdownTimer = null; }
        var badge = document.getElementById('dcl-refresh-badge');
        if (_dclRefreshMs <= 0) {
            if (badge) badge.title = 'Actualización automática desactivada';
            return;
        }
        var totalSeg = Math.max(1, Math.round(_dclRefreshMs / 1000));
        var seg = totalSeg;
        if (badge) badge.title = 'Próxima actualización en ' + seg + ' s';
        _dclCountdownTimer = setInterval(function () {
            seg--;
            if (seg <= 0) seg = totalSeg;
            var b = document.getElementById('dcl-refresh-badge');
            if (b) b.title = 'Próxima actualización en ' + seg + ' s';
        }, 1000);
    }

    // ── Panel: elegir frecuencia de actualización automática ──────────────
    function dclToggleRefreshPanel(btn) {
        if (document.getElementById('dcl-refresh-panel')) { dclCloseRefreshPanel(); return; }
        dclOpenRefreshPanel(btn);
    }

    function dclOpenRefreshPanel(anchorBtn) {
        dclCloseRefreshPanel();
        var btn = anchorBtn || document.getElementById('dcl-refresh-btn');
        var panel = document.createElement('div');
        panel.id = 'dcl-refresh-panel';
        panel.className = 'dcl-layouts-panel';
        panel.onclick = function (e) { if (e.target === panel) dclCloseRefreshPanel(); };

        var esPreset = false;
        var optsHtml = '';
        for (var i = 0; i < _DCL_REFRESH_PRESETS.length; i++) {
            var p = _DCL_REFRESH_PRESETS[i];
            var activo = (p.ms === _dclRefreshMs);
            if (activo) esPreset = true;
            optsHtml += '<button type="button" class="dcl-refresh-opt' + (activo ? ' dcl-refresh-opt--active' : '') + '" data-ms="' + p.ms + '">' +
                '<i class="mdi mdi-' + (activo ? 'check-circle-outline' : 'circle-outline') + '"></i>' +
                '<span>' + p.lbl + '</span></button>';
        }
        var customVal = (!esPreset && _dclRefreshMs > 0) ? Math.round(_dclRefreshMs / 1000) : '';

        panel.innerHTML =
            '<div class="dcl-layouts-box">' +
            '<div class="dcl-layouts-hd">' +
            '<span class="dcl-layouts-title"><i class="mdi mdi-clock-outline"></i>&nbsp;Actualización automática</span>' +
            '<button type="button" class="dcl-layouts-close" data-act="close" title="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
            '<div class="dcl-layouts-list">' + optsHtml + '</div>' +
            '<div class="dcl-refresh-custom-wrap">' +
            '<div class="dcl-layouts-ft dcl-refresh-custom">' +
            '<input type="number" min="5" step="1" class="dcl-refresh-custom-input" id="dcl-refresh-custom-val" placeholder="Personalizado" value="' + customVal + '" />' +
            '<span class="dcl-refresh-custom-unit">seg</span>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" data-act="custom" title="Aplicar"><i class="mdi mdi-check"></i></button>' +
            '</div>' +
            '<span class="dcl-refresh-custom-err" id="dcl-refresh-custom-err"></span>' +
            '</div>' +
            '</div>';

        function aplicarCustom() {
            var inp = document.getElementById('dcl-refresh-custom-val');
            var err = document.getElementById('dcl-refresh-custom-err');
            var seg = parseInt(inp && inp.value, 10);
            if (!seg || seg < 5) {
                if (inp) { inp.focus(); inp.classList.add('dcl-refresh-custom-input--err'); }
                if (err) err.textContent = 'Ingresa un número de al menos 5 segundos';
                return;
            }
            dclSetRefreshMs(seg * 1000);
            dclCloseRefreshPanel();
        }

        panel.addEventListener('click', function (e) {
            var el = e.target;
            while (el && el !== panel && !(el.getAttribute && (el.getAttribute('data-ms') || el.getAttribute('data-act')))) el = el.parentNode;
            if (!el || el === panel) return;
            var msAttr = el.getAttribute('data-ms');
            if (msAttr) {
                dclSetRefreshMs(parseInt(msAttr, 10));
                dclCloseRefreshPanel();
                return;
            }
            var act = el.getAttribute('data-act');
            if (act === 'close') dclCloseRefreshPanel();
            else if (act === 'custom') aplicarCustom();
        });

        var customInput = panel.querySelector('#dcl-refresh-custom-val');
        if (customInput) {
            customInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.keyCode === 13) { e.preventDefault(); aplicarCustom(); }
            });
            customInput.addEventListener('input', function () {
                customInput.classList.remove('dcl-refresh-custom-input--err');
                var err = document.getElementById('dcl-refresh-custom-err');
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

    function dclCloseRefreshPanel() {
        var panel = document.getElementById('dcl-refresh-panel');
        if (!panel) return;
        panel.classList.remove('dcl-layouts-panel--open');
        setTimeout(function () { if (panel.parentNode) panel.parentNode.removeChild(panel); }, 260);
    }

    // ── Hook UpdatePanel ─────────────────────────────────────────────────
    (function () {
        function afterRefresh() { setTimeout(dclInit, 80); }
        if (typeof Sys !== 'undefined' && Sys.WebForms && Sys.WebForms.PageRequestManager)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(afterRefresh);
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function () { dclInit(); dclStartAutoRefresh(); dclStartCountdown(); });
        } else {
            dclInit();
            dclStartAutoRefresh();
            dclStartCountdown();
        }
    })();
