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
            'data-tip="Ayuda&#10;Ver el tutorial del armador de dashboard"><i class="mdi mdi-help-circle-outline"></i></button>' +
            '<span id="dcl-bld-counter" class="dcl-bld-counter">0 / ' + idsNivel.length + '</span>' +
            '<div class="dcl-bld-hd-spacer"></div>' +
            '<button type="button" class="dcl-bld-clear-btn" onclick="dclBldClearCanvas()" data-tip="Limpiar&#10;Quita todas las filas y devuelve los widgets al panel">' +
            '<i class="mdi mdi-refresh"></i>&nbsp;Limpiar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--ghost dcl-bld-apply-btn" onclick="dclBldApplyOnly()" data-tip="Aplicar&#10;Usa esta distribución sin guardarla como layout con nombre">' +
            '<i class="mdi mdi-check"></i>&nbsp;Aplicar</button>' +
            '<button type="button" class="dcl-btn dcl-btn--primary" onclick="dclBldSaveAndExit()" data-tip="Guardar&#10;Aplica la distribución y la guarda como layout">' +
            '<i class="mdi mdi-content-save"></i>&nbsp;Guardar como...</button>' +
            '<button type="button" class="dcl-btn dcl-btn--ghost dcl-bld-ghost-btn" onclick="dclExitBuilderMode(false)" data-tip="Cancelar">' +
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
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(1)" data-tip="1 columna (100%)"><i class="mdi mdi-view-stream"></i>&nbsp;1&nbsp;col</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(2)" data-tip="2 columnas (50% / 50%)"><i class="mdi mdi-view-column"></i>&nbsp;2&nbsp;cols</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(3)" data-tip="3 columnas (33% c/u)"><i class="mdi mdi-view-dashboard"></i>&nbsp;3&nbsp;cols</button>' +
            '<button type="button" class="dcl-bld-addrow-btn" onclick="dclBldAddRow(4)" data-tip="4 columnas (25% c/u)"><i class="mdi mdi-view-grid"></i>&nbsp;4&nbsp;cols</button>';
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
                '<span class="dcl-bld-sec-nm" data-tip="' + nmeta + '">' + nmeta + '</span>' +
                '<i class="mdi mdi-drag-horizontal-variant dcl-bld-drag-i" data-tip="Arrastrar"></i>' +
                '</div>' +
                // Fila 2: chip categoría + descripción
                '<div class="dcl-bld-tile-meta">' +
                '<span class="dcl-bld-cat-chip dcl-bld-cat-chip--' + catCls + '">' + catLbl + '</span>' +
                (desc ? '<span class="dcl-bld-tile-desc" data-tip="' + dclHtmlEsc(desc) + '">' + dclHtmlEsc(desc) + '</span>' : '') +
                '</div>' +
                // Preview (oculto por defecto)
                '<div class="dcl-bld-preview" style="display:none"></div>' +
                // Fila 3: acciones (vista previa + control de alto)
                '<div class="dcl-bld-tile-actions">' +
                '<button type="button" class="dcl-bld-prev-btn" onclick="dclBldTogglePreview(this)"' +
                ' data-tip="Vista previa" ondragstart="event.stopPropagation()">' +
                '<i class="mdi mdi-eye-outline"></i><span>Vista previa</span></button>' +
                '<div class="dcl-bld-h-grp" data-tip="Alto del widget">' +
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
                btn.dataset.tip = 'Quitar de esta columna';
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
                '<button type="button" class="dcl-bld-prev-expand" data-tip="Ampliar" ' +
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
            '<button type="button" class="dcl-prev-modal-close" data-close="1" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
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
            '<button type="button" class="dcl-bld-row-del-btn" onclick="dclBldDelRow(this)" data-tip="Eliminar fila">' +
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
               'data-tip="Categoría&#10;Elige si armás el dashboard General, por Instalación o por Zona" ' +
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
               'data-tip="Cargar layout&#10;Trae al canvas un layout ya guardado de esta categoría" ' +
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
            btn.setAttribute('data-tip', 'Actualización automática\nDesactivada. Los datos no se refrescan solos');
            btn.classList.add('dcl-refresh-btn--off');
        } else {
            btn.setAttribute('data-tip', 'Actualización automática\nLos datos se refrescan cada ' + dclFormatIntervalo(_dclRefreshMs));
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
