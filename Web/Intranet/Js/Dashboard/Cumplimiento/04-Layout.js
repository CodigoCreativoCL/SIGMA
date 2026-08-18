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
                        th.dataset.tip = 'Click para ordenar';
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
                    td.innerHTML = '<span class="dcl-stat" data-tip="Promedio">Ø ' + avg.toFixed(1) + '</span>'
                        + '<span class="dcl-stat" data-tip="Mediana">⨁ ' + med.toFixed(1) + '</span>';
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
                        else { btn.classList.add('dcl-thumb--err'); btn.dataset.tip = 'No se pudo cargar la imagen'; }
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
            '<button type="button" class="dcl-lightbox-close" data-tip="Cerrar&#10;Cierra este panel"><i class="mdi mdi-close"></i></button>' +
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
