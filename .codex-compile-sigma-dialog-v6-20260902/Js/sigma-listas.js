/* ============================================================================
   SIGMA · mejora progresiva para vistas maestras existentes

   No reemplaza RadGrid ni replica datos. Lee la fila ya renderizada para el
   drawer y deja que Telerik conserve seleccion, orden, paginacion y postbacks.
   ============================================================================ */
(function () {
    'use strict';

    var rutas = [
        '/view/terceros/proveedores/proveedores.aspx',
        '/view/terceros/permisostrabajo/permisotrabajos.aspx',
        '/view/terceros/permisostrabajo/permisotrabajovigentes.aspx',
        '/view/inventario/bodegas/bodegas.aspx',
        '/view/inventario/repuestos/repuestos.aspx',
        '/view/inventario/compatibilidades/repuestocompatibilidades.aspx',
        '/view/organizacion/plantas/plantas.aspx',
        '/view/organizacion/areas/areas.aspx',
        '/view/organizacion/centroscosto/centroscosto.aspx',
        '/view/activos/activos/activos.aspx',
        '/view/activos/medidores/activomedidores.aspx',
        '/view/activos/tipos/activotipos.aspx',
        '/view/activos/ficha/activoficha.aspx',
        '/view/activos/componentes/activocomponentes.aspx',
        '/view/activos/estado/activoestado.aspx',
        '/view/activos/modelos/activomodelos.aspx',
        '/view/activos/atributos/atributotecnicos.aspx'
    ];

    var path = (window.location.pathname || '').toLowerCase();
    var activa = rutas.some(function (ruta) { return path.slice(-ruta.length) === ruta; });

    if (!activa) return;

    document.documentElement.classList.add('sgx-page');

    var host = null;
    var drawer = null;
    var activeRow = null;
    var originalEdit = null;
    var drawerDismissed = false;
    var observedList = null;
    var aligning = false;
    var drawerTimeline = null;

    function all(selector, scope) {
        return Array.prototype.slice.call((scope || document).querySelectorAll(selector));
    }

    function one(selector, scope) {
        return (scope || document).querySelector(selector);
    }

    function closest(element, selector) {
        while (element && element !== document) {
            if (element.matches && element.matches(selector)) return element;
            element = element.parentNode;
        }
        return null;
    }

    function text(element) {
        return element ? (element.textContent || '').replace(/\s+/g, ' ').trim() : '';
    }

    function htmlEscape(value) {
        var node = document.createElement('div');
        node.textContent = value || '';
        return node.innerHTML;
    }

    function titleCase(value) {
        value = (value || '').toLowerCase();
        value = value.replace(/(^|\s)([a-záéíóúñ])/g, function (_, space, letter) {
            return space + letter.toUpperCase();
        });

        return value.replace(/\bRut\b/g, 'RUT').replace(/\bId\b/g, 'ID').replace(/\bOt\b/g, 'OT');
    }

    function pageTitle() {
        return text(one('.sg-page-head h1')) || 'Detalle';
    }

    function iconFor(label) {
        label = (label || '').toLowerCase();

        if (/fecha|vigencia|desde|hasta|inicio|término|termino/.test(label)) return 'mdi-calendar-blank-outline';
        if (/estado|habilitad|situación|situacion/.test(label)) return 'mdi-check-circle-outline';
        if (/correo|email/.test(label)) return 'mdi-email-outline';
        if (/teléfono|telefono|contacto/.test(label)) return 'mdi-account-outline';
        if (/planta|área|area|ubicación|ubicacion|bodega/.test(label)) return 'mdi-map-marker-outline';
        if (/código|codigo|rut|folio|id/.test(label)) return 'mdi-identifier';
        if (/tipo|categoría|categoria|origen/.test(label)) return 'mdi-shape-outline';
        if (/cantidad|stock|saldo|unidad/.test(label)) return 'mdi-package-variant-closed';
        if (/documento|archivo|adjunto/.test(label)) return 'mdi-paperclip';
        if (/responsable|usuario|asignad/.test(label)) return 'mdi-account-multiple-outline';
        return 'mdi-information-outline';
    }

    function statusInfo(value) {
        var normalized = (value || '').toLowerCase();
        if (/por vencer|advertencia|pendiente|sin /.test(normalized))
            return { css: 'is-warning', icon: 'mdi-clock-alert-outline' };
        if (/vencido|rechazad|deshabilitad|baja|cerrad|no$/.test(normalized))
            return { css: 'is-danger', icon: 'mdi-alert-circle-outline' };
        if (/habilitad|vigente|activo|sí|si|ok|disponible/.test(normalized))
            return { css: '', icon: 'mdi-check-circle-outline' };
        return { css: 'is-muted', icon: 'mdi-information-outline' };
    }

    function cleanValue(cell) {
        var copy = cell.cloneNode(true);
        all('input, button, select, .icono_Editar, .icono_ver, .icono_ver_Lupa, .rgCheck', copy)
            .forEach(function (node) { if (node.parentNode) node.parentNode.removeChild(node); });
        return copy.innerHTML.replace(/^\s+|\s+$/g, '');
    }

    function gridFields(row) {
        var table = closest(row, 'table');
        /* Telerik puede poner CommandItemTemplate como primera fila del thead.
           Los .rgHeader son la cabecera real; tomar el primer tr dejaba el
           drawer sin campos en las grillas que tienen Nuevo/Dar de baja. */
        var headers = all('thead th.rgHeader, thead td.rgHeader', table);
        if (!headers.length) headers = all('th.rgHeader, td.rgHeader', table);
        var cells = Array.prototype.slice.call(row.cells || []);
        var fields = [];

        cells.forEach(function (cell, index) {
            var label = headers[index] ? text(headers[index]) : '';
            var valueText = text(cell);
            var hasControlOnly = !!one('input[type="checkbox"]', cell) && valueText === '';
            var hasEditOnly = !!one('.icono_Editar, .icono_ver, .icono_ver_Lupa', cell) && valueText === '';

            if (!label || hasControlOnly || hasEditOnly || (!valueText && !one('.grid-estado-chip, img', cell))) return;

            fields.push({
                label: titleCase(label),
                value: cleanValue(cell),
                valueText: valueText,
                primary: !!one('strong', cell),
                primaryText: text(one('strong', cell))
            });
        });

        return fields;
    }

    function treeFields(row) {
        var meta = text(one('.meta', row));
        var chips = text(one('.chips', row));
        var fields = [];

        if (meta) fields.push({ label: 'Ubicación y tipo', value: htmlEscape(meta), valueText: meta, primary: false });
        fields.push({ label: 'Nivel en la estructura', value: htmlEscape(row.getAttribute('data-nivel') || '1'), valueText: row.getAttribute('data-nivel') || '1', primary: false });
        if (chips) fields.push({ label: 'Información', value: one('.chips', row).innerHTML, valueText: chips, primary: false });

        return fields;
    }

    function rowFields(row) {
        return row.classList.contains('sg-arbol-fila') ? treeFields(row) : gridFields(row);
    }

    function rowTitle(row, fields) {
        if (row.classList.contains('sg-arbol-fila')) return text(one('.nombre', row));

        var primary = fields.filter(function (field) { return field.primary; })[0];
        if (primary) return primary.primaryText || primary.valueText;

        var useful = fields.filter(function (field) {
            return !/^(Estado|Habilitado|Situación|Origen)$/i.test(field.label);
        })[0];

        return useful ? useful.valueText : pageTitle();
    }

    function findState(fields, row) {
        if (row.classList.contains('is-deshabilitada')) return 'Deshabilitada';

        var field = fields.filter(function (item) {
            return /estado|habilitad|situación|situacion/i.test(item.label);
        })[0];

        return field ? field.valueText : '';
    }

    function findEdit(row) {
        if (row.classList.contains('sg-arbol-fila'))
            return one('.sg-arbol-accion:not(.is-peligro):not(.is-inerte)', row);

        return one('.sgx-original-edit, .icono_Editar, .icono_ver, .icono_ver_Lupa, a[onclick*="abrir"]', row);
    }

    function addDetailTrigger(row) {
        if (row.classList.contains('sg-arbol-fila') || one('.sgx-detail-trigger', row)) return;

        var edit = findEdit(row);
        var targetCell = edit ? closest(edit, 'td') : null;
        var cells = Array.prototype.slice.call(row.cells || []);

        if (!edit) return;

        if (edit) {
            edit.classList.add('sgx-original-edit');
            edit.setAttribute('tabindex', '-1');
            edit.setAttribute('aria-hidden', 'true');
        }

        if (!targetCell) {
            targetCell = cells.filter(function (cell) {
                return !one('input[type="checkbox"]', cell) && text(cell) === '';
            })[0] || cells[0];
        }

        if (!targetCell) return;

        var trigger = document.createElement('button');
        trigger.type = 'button';
        trigger.className = 'sgx-detail-trigger';
        trigger.setAttribute('data-sgx-action', 'modal');
        trigger.setAttribute('aria-label', 'Abrir ficha de ' + rowTitle(row, rowFields(row)));
        trigger.setAttribute('title', 'Abrir ficha');
        trigger.innerHTML = '<i class="mdi mdi-magnify" aria-hidden="true"></i>';
        targetCell.appendChild(trigger);
    }

    function buildDrawer() {
        if (!host) return null;

        var current = one('#sgxDrawer', host);
        if (current) return current;

        current = document.createElement('aside');
        current.id = 'sgxDrawer';
        current.className = 'sgx-drawer';
        current.setAttribute('aria-label', 'Detalle del registro');
        current.setAttribute('aria-live', 'polite');
        current.innerHTML =
            '<button type="button" class="sgx-drawer-close" data-sgx-action="close" aria-label="Cerrar detalle">' +
                '<i class="mdi mdi-close" aria-hidden="true"></i></button>' +
            '<div class="sgx-drawer-content"></div>' +
            '<div class="sgx-drawer-actions"></div>';
        host.appendChild(current);
        return current;
    }

    function visibleList() {
        var candidates = all('.RadGrid, .sg-arbol', host);

        for (var i = 0; i < candidates.length; i++) {
            if (candidates[i].offsetWidth > 0 && candidates[i].offsetHeight > 0) return candidates[i];
        }

        return candidates.length ? candidates[0] : null;
    }

    function fitListToViewport(list) {
        if (!list || list.offsetHeight <= 0) return 0;

        var top = list.getBoundingClientRect().top;
        var available = Math.max(300, Math.round(window.innerHeight - top - 16));

        if (list.classList.contains('sg-arbol')) {
            list.style.minHeight = '0px';
            var treeNatural = Math.round(list.getBoundingClientRect().height);
            var treeHeight = Math.max(treeNatural, available);
            list.style.minHeight = treeHeight + 'px';
            return treeHeight;
        }

        var table = one('table.rgMasterTable', list);
        var body = table ? one('tbody', table) : null;
        if (!table || !body) return Math.max(Math.round(list.getBoundingClientRect().height), available);

        var spacer = one('tr.sgx-grid-spacer', body);

        if (!spacer) {
            spacer = document.createElement('tr');
            spacer.className = 'sgx-grid-spacer';
            spacer.setAttribute('aria-hidden', 'true');

            var cell = document.createElement('td');
            var sample = one('tr.rgRow, tr.rgAltRow', body);
            cell.colSpan = sample && sample.cells ? sample.cells.length : Math.max(1, all('th.rgHeader', table).length);
            spacer.appendChild(cell);
            body.appendChild(spacer);
        }

        /* La fila neutra empuja el paginador al borde inferior sin estirar
           las filas con datos. Se vuelve a medir desde su altura natural en
           cada cambio de viewport o postback. */
        list.style.height = 'auto';
        spacer.style.height = '0px';
        one('td', spacer).style.height = '0px';

        var natural = Math.round(list.getBoundingClientRect().height);
        var target = Math.max(natural, available);
        var extra = Math.max(0, target - natural);

        spacer.style.height = extra + 'px';
        one('td', spacer).style.height = extra + 'px';
        list.style.height = target + 'px';

        return target;
    }

    function alignDrawer() {
        if (!host || !drawer || aligning) return;

        aligning = true;
        window.requestAnimationFrame(function () { aligning = false; });

        /* En escritorio el drawer pertenece visualmente a la lista, no a la
           barra de acciones ni al texto de ayuda. Ambos bordes se calculan
           desde la RadGrid real (o desde el arbol de Areas), incluido su
           paginador. En el breakpoint movil CSS lo convierte en overlay. */
        var list = visibleList();
        if (!list || list.offsetHeight <= 0) return;

        var fittedHeight = fitListToViewport(list);

        if (window.innerWidth <= 1330) {
            drawer.style.removeProperty('--sgx-drawer-offset');
            drawer.style.removeProperty('--sgx-drawer-height');
            return;
        }

        var mainColumn = Array.prototype.slice.call(host.children).filter(function (child) {
            return child !== drawer;
        })[0];
        var mainBox = mainColumn ? mainColumn.getBoundingClientRect() : host.getBoundingClientRect();
        var listBox = list.getBoundingClientRect();
        var offset = Math.max(0, Math.round(listBox.top - mainBox.top));

        drawer.style.setProperty('--sgx-drawer-offset', offset + 'px');
        drawer.style.setProperty('--sgx-drawer-height', fittedHeight + 'px');
    }

    function openRow(row) {
        if (!row || !drawer) return;

        var wasOpen = host.classList.contains('has-drawer');
        var fields = rowFields(row);
        var title = rowTitle(row, fields);
        var state = findState(fields, row);
        var stateStyle = statusInfo(state);
        var content = one('.sgx-drawer-content', drawer);
        var actions = one('.sgx-drawer-actions', drawer);

        activeRow = row;
        originalEdit = findEdit(row);
        drawerDismissed = false;

        all('.sgx-detail-row.is-current, .sg-arbol-fila.is-current', host)
            .forEach(function (item) { item.classList.remove('is-current'); });
        row.classList.add('is-current');

        var body = '<span class="sgx-drawer-kicker"><i class="mdi mdi-view-list-outline"></i>' +
            htmlEscape(pageTitle()) + '</span>' +
            '<h2>' + htmlEscape(title) + '</h2>' +
            '<p class="sgx-drawer-subtitle">Detalle del registro seleccionado</p>';

        if (state) {
            body += '<span class="sgx-drawer-state ' + stateStyle.css + '"><i class="mdi ' +
                stateStyle.icon + '"></i>' + htmlEscape(state) + '</span>';
        }

        body += '<div class="sgx-drawer-fields">';

        fields.forEach(function (field) {
            body += '<div class="sgx-drawer-field"><i class="mdi ' + iconFor(field.label) +
                '" aria-hidden="true"></i><div><label>' + htmlEscape(field.label) +
                '</label><div class="value">' + field.value + '</div></div></div>';
        });

        body += '</div>';
        var actionsHtml = originalEdit
            ? '<button type="button" data-sgx-action="edit"><i class="mdi mdi-pencil-outline"></i>Editar registro</button>'
            : '<p><i class="mdi mdi-eye-outline"></i> Este registro es de solo lectura.</p>';

        function renderNewContent() {
            content.innerHTML = body;
            actions.innerHTML = actionsHtml;
            host.classList.add('has-drawer');
            window.requestAnimationFrame(function () {
                alignDrawer();
                animateDrawer(wasOpen);
            });
        }

        if (wasOpen && window.gsap) {
            if (drawerTimeline) drawerTimeline.kill();
            var previousItems = all(
                '.sgx-drawer-kicker, .sgx-drawer h2, .sgx-drawer-subtitle, ' +
                '.sgx-drawer-state, .sgx-drawer-field, .sgx-drawer-actions > *',
                drawer
            );
            gsap.killTweensOf(previousItems);
            drawerTimeline = gsap.timeline({ onComplete: renderNewContent });
            drawerTimeline.to(previousItems, {
                autoAlpha: 0,
                x: -10,
                duration: .16,
                stagger: .012,
                ease: 'power2.in'
            });
        } else renderNewContent();
    }

    function animateDrawer(wasOpen) {
        if (!window.gsap || !drawer) return;

        var contentItems = all(
            '.sgx-drawer-kicker, .sgx-drawer h2, .sgx-drawer-subtitle, ' +
            '.sgx-drawer-state, .sgx-drawer-field, .sgx-drawer-actions > *',
            drawer
        );
        var fromX = window.innerWidth <= 1330 ? 54 : 24;

        if (drawerTimeline) drawerTimeline.kill();
        gsap.killTweensOf([drawer, contentItems]);
        gsap.set(drawer, { clearProps: 'opacity,visibility,transform' });

        drawerTimeline = gsap.timeline({ defaults: { overwrite: 'auto' } });

        if (!wasOpen) {
            drawerTimeline.fromTo(drawer,
                { autoAlpha: 0, x: fromX, scale: .985 },
                {
                    autoAlpha: 1,
                    x: 0,
                    scale: 1,
                    duration: .56,
                    ease: 'power4.out',
                    clearProps: 'opacity,visibility,transform'
                },
                0
            );
        }

        drawerTimeline.fromTo(contentItems,
            { autoAlpha: 0, x: wasOpen ? 12 : 0, y: wasOpen ? 2 : 11 },
            {
                autoAlpha: 1,
                x: 0,
                y: 0,
                duration: .34,
                stagger: .035,
                ease: 'power3.out',
                clearProps: 'opacity,visibility,transform'
            },
            wasOpen ? 0 : .14
        );
    }

    function closeDrawer(immediate) {
        drawerDismissed = true;
        activeRow = null;
        originalEdit = null;
        all('.sgx-detail-row.is-current, .sg-arbol-fila.is-current', host)
            .forEach(function (item) { item.classList.remove('is-current'); });

        function finish() {
            host.classList.remove('has-drawer');
            if (window.gsap && drawer)
                gsap.set(drawer, { clearProps: 'opacity,visibility,transform' });
        }

        if (!immediate && window.gsap && drawer && host.classList.contains('has-drawer')) {
            if (drawerTimeline) drawerTimeline.kill();
            gsap.killTweensOf(drawer);
            drawerTimeline = gsap.timeline({ onComplete: finish });
            drawerTimeline
                .to(all('.sgx-drawer-content > *, .sgx-drawer-actions', drawer), {
                    autoAlpha: 0,
                    y: -5,
                    duration: .15,
                    stagger: .018,
                    ease: 'power2.in'
                }, 0)
                .to(drawer, {
                    autoAlpha: 0,
                    x: window.innerWidth <= 1330 ? 48 : 20,
                    scale: .99,
                    duration: .28,
                    ease: 'power3.in'
                }, .04);
        } else finish();
    }

    function rowCheckboxes() {
        var result = [];
        all('.RadGrid tr.rgRow, .RadGrid tr.rgAltRow', host).forEach(function (row) {
            var check = one('input[type="checkbox"]', row);
            if (check && !check.disabled) result.push(check);
        });
        return result;
    }

    function findBulkAction() {
        return one('.sigma-acciones-barra a[id*="lnkEliminar"], .RadGrid .rgCommandRow .icono_eliminar', host);
    }

    function bulkLabel() {
        var original = findBulkAction();
        var label = text(original);
        return label || 'Aplicar acción';
    }

    function selectionBar() {
        var grid = one('.RadGrid', host);
        if (!grid || rowCheckboxes().length === 0) return null;

        var existing = one('.sgx-selection', host);
        if (existing) return existing;

        var bar = document.createElement('div');
        bar.className = 'sgx-selection';
        bar.innerHTML = '<i class="mdi mdi-checkbox-marked-circle-outline"></i>' +
            '<strong data-sgx-selection-text>0 registros seleccionados</strong><span></span>' +
            (findBulkAction() ? '<button type="button" data-sgx-action="bulk"><i class="mdi mdi-pause-circle-outline"></i><span>' + htmlEscape(bulkLabel()) + '</span></button>' : '') +
            '<button type="button" class="is-cancel" data-sgx-action="clear"><i class="mdi mdi-close"></i><span>Cancelar selección</span></button>';
        grid.parentNode.insertBefore(bar, grid);
        return bar;
    }

    function paintSelection() {
        var bar = selectionBar();
        if (!bar) return;

        var count = rowCheckboxes().filter(function (check) { return check.checked; }).length;
        var label = one('[data-sgx-selection-text]', bar);

        bar.classList.toggle('is-visible', count > 0);
        label.textContent = count + (count === 1 ? ' registro seleccionado' : ' registros seleccionados');
    }

    function clearSelection() {
        rowCheckboxes().filter(function (check) { return check.checked; }).forEach(function (check) {
            check.click();
        });
        window.setTimeout(paintSelection, 0);
    }

    function enhanceRows() {
        var rows = all('.RadGrid tr.rgRow, .RadGrid tr.rgAltRow', host)
            .concat(all('.sg-arbol-fila', host));

        rows.forEach(function (row) {
            row.classList.add('sgx-detail-row');
            row.setAttribute('tabindex', '0');
            row.setAttribute('aria-label', 'Ver detalle de ' + rowTitle(row, rowFields(row)));
            addDetailTrigger(row);
        });

        // Un rebind de Telerik reemplaza las filas completas. Si la fila que
        // alimentaba el drawer ya no existe, cerramos también su estado visual
        // para no dejar un detalle antiguo asociado a la nueva grilla.
        if (activeRow && !document.documentElement.contains(activeRow)) closeDrawer(true);
    }

    function enhanceHeaders() {
        all('.RadGrid th.rgHeader, .RadGrid td.rgHeader', host).forEach(function (header) {
            Array.prototype.slice.call(header.childNodes || []).forEach(function (node) {
                if (node.nodeType === 3 && node.nodeValue && node.nodeValue.trim())
                    node.nodeValue = titleCase(node.nodeValue);
            });

            var link = one('a', header);
            if (link) {
                Array.prototype.slice.call(link.childNodes || []).forEach(function (node) {
                    if (node.nodeType === 3 && node.nodeValue && node.nodeValue.trim())
                        node.nodeValue = titleCase(node.nodeValue);
                });
            }
        });
    }

    function clickHandler(event) {
        var action = closest(event.target, '[data-sgx-action]');

        if (action && host && host.contains(action)) {
            var name = action.getAttribute('data-sgx-action');

            if (name === 'close') closeDrawer();
            else if (name === 'modal') {
                var modalRow = closest(action, '.sgx-detail-row');
                var modalLink = modalRow ? findEdit(modalRow) : null;
                if (modalLink) modalLink.click();
            }
            else if (name === 'edit' && originalEdit) originalEdit.click();
            else if (name === 'clear') clearSelection();
            else if (name === 'bulk') {
                var original = findBulkAction();
                if (original) original.click();
            }

            event.preventDefault();
            return;
        }

        var row = closest(event.target, '.sgx-detail-row');
        if (!row || !host || !host.contains(row)) return;
        if (closest(event.target, 'a, button, input, select, textarea, label')) return;

        openRow(row);
    }

    function changeHandler(event) {
        if (closest(event.target, '.RadGrid') && event.target.type === 'checkbox')
            window.setTimeout(paintSelection, 0);
    }

    function keyHandler(event) {
        var row = closest(event.target, '.sgx-detail-row');
        if (!row || (event.keyCode !== 13 && event.keyCode !== 32)) return;
        if (closest(event.target, 'a, button, input, select, textarea')) return;

        event.preventDefault();
        openRow(row);
    }

    function init() {
        host = one('.content-page .container-fluid > .row.card-box');
        if (!host) return;

        host.classList.add('sgx-host');
        drawer = buildDrawer();
        enhanceHeaders();
        enhanceRows();
        paintSelection();
        window.requestAnimationFrame(alignDrawer);

        var list = visibleList();
        if (window.ResizeObserver && list && list !== observedList) {
            observedList = list;
            new ResizeObserver(alignDrawer).observe(list);
        }
    }

    if (!window.sgxListEventsBound) {
        window.sgxListEventsBound = true;
        document.addEventListener('click', clickHandler);
        document.addEventListener('change', changeHandler);
        document.addEventListener('keydown', keyHandler);
        window.addEventListener('resize', alignDrawer);
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(init);
})();
