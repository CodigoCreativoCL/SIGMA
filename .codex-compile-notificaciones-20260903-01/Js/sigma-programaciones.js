/* ============================================================================
   SIGMA · Listado de programaciones

   La base entrega todas las filas una sola vez. Buscar, filtrar, ordenar,
   paginar y abrir el panel lateral son acciones de lectura y se resuelven en
   el navegador. Deshabilitar y duplicar siguen siendo postbacks: los permisos
   y la barrera por cliente se validan en el servidor.
   ============================================================================ */
(function () {
    'use strict';

    var root = null;
    var rows = [];
    var activeRow = null;
    var menuRow = null;
    var drawerDismissed = false;
    var state = null;

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

    function attr(element, name) {
        return element ? (element.getAttribute(name) || '') : '';
    }

    function normalize(text) {
        text = (text || '').toLowerCase();

        if (text.normalize) text = text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
        return text;
    }

    function asNumber(value) {
        var number = parseInt(value, 10);
        return isNaN(number) ? 0 : number;
    }

    function currentPageRows() {
        return rows.filter(function (row) { return !row.hidden; });
    }

    function filteredRows() {
        var search = normalize(state.search);

        return rows.filter(function (row) {
            var enabled = attr(row, 'data-enabled');
            var assigned = attr(row, 'data-assigned');
            var exclusions = asNumber(attr(row, 'data-exclusions'));
            var next = attr(row, 'data-next');

            if (state.tab === 'habilitadas' && enabled !== '1') return false;
            if (state.tab === 'sin-responsable' && assigned !== '0') return false;
            if (state.tab === 'con-exclusiones' && exclusions === 0) return false;
            if (state.tab === 'proximas' && (next === '' || next.indexOf('9999') === 0)) return false;

            if (state.type && attr(row, 'data-type') !== state.type) return false;
            if (state.status && enabled !== state.status) return false;
            if (state.assignment && assigned !== state.assignment) return false;

            if (state.exclusions === '1' && exclusions === 0) return false;
            if (state.exclusions === '0' && exclusions > 0) return false;

            if (search && normalize(row.textContent).indexOf(search) < 0) return false;
            return true;
        });
    }

    function sortRows(list) {
        var key = state.sort;

        list.sort(function (a, b) {
            var av;
            var bv;

            if (key === 'name') {
                av = attr(a, 'data-name');
                bv = attr(b, 'data-name');
            } else if (key === 'type') {
                av = attr(a, 'data-type') + attr(a, 'data-name');
                bv = attr(b, 'data-type') + attr(b, 'data-name');
            } else if (key === 'start') {
                av = attr(a, 'data-start');
                bv = attr(b, 'data-start');
            } else {
                av = attr(a, 'data-next');
                bv = attr(b, 'data-next');
            }

            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
        });

        return list;
    }

    function apply() {
        if (!root) return;

        var tbody = one('#sgpRows', root);
        var empty = one('#sgpEmpty', root);
        var filtered = sortRows(filteredRows());
        var pages = Math.max(1, Math.ceil(filtered.length / state.pageSize));

        if (state.page > pages) state.page = pages;

        var start = (state.page - 1) * state.pageSize;
        var pageRows = filtered.slice(start, start + state.pageSize);

        rows.forEach(function (row) {
            row.hidden = true;
            tbody.appendChild(row);
        });

        pageRows.forEach(function (row) {
            row.hidden = false;
            tbody.appendChild(row);
        });

        tbody.appendChild(empty);
        empty.hidden = filtered.length !== 0;

        paintPager(filtered.length, pages, start, pageRows.length);
        paintMasterCheck();

        if (activeRow && filtered.indexOf(activeRow) < 0) activeRow = null;

        if (!activeRow && !drawerDismissed && pageRows.length > 0) openRow(pageRows[0]);
        else paintActiveRow();
    }

    function paintPager(total, pages, start, pageCount) {
        var info = one('#sgpPageInfo', root);
        var numbers = one('#sgpPageNumbers', root);

        info.textContent = total === 0
            ? 'Sin resultados'
            : 'Página ' + state.page + ' de ' + pages + ', items ' + (start + 1) +
              ' a ' + (start + pageCount) + ' de ' + total + '.';

        numbers.innerHTML = '';

        var from = Math.max(1, state.page - 2);
        var to = Math.min(pages, from + 4);
        from = Math.max(1, to - 4);

        for (var page = from; page <= to; page++) {
            var button = document.createElement('button');
            button.type = 'button';
            button.setAttribute('data-sgp-page', page);
            button.textContent = page;

            if (page === state.page) {
                button.className = 'is-active';
                button.setAttribute('aria-current', 'page');
            }

            numbers.appendChild(button);
        }

        all('[data-sgp-page="first"], [data-sgp-page="prev"]', root).forEach(function (button) {
            button.disabled = state.page <= 1;
        });

        all('[data-sgp-page="next"], [data-sgp-page="last"]', root).forEach(function (button) {
            button.disabled = state.page >= pages;
        });
    }

    function changePage(value) {
        var total = filteredRows().length;
        var pages = Math.max(1, Math.ceil(total / state.pageSize));

        if (value === 'first') state.page = 1;
        else if (value === 'prev') state.page = Math.max(1, state.page - 1);
        else if (value === 'next') state.page = Math.min(pages, state.page + 1);
        else if (value === 'last') state.page = pages;
        else state.page = Math.max(1, Math.min(pages, asNumber(value)));

        apply();
    }

    function selectTab(name) {
        state.tab = name || 'todas';
        state.page = 1;

        all('[data-sgp-tab]', root).forEach(function (button) {
            var active = attr(button, 'data-sgp-tab') === state.tab;
            button.classList.toggle('is-active', active);

            if (button.parentNode && button.parentNode.classList.contains('sgp-tabs')) {
                if (active) button.setAttribute('aria-current', 'page');
                else button.removeAttribute('aria-current');
            }
        });

        apply();
    }

    function openRow(row) {
        if (!row) return;

        activeRow = row;
        drawerDismissed = false;
        closeMenus();

        var source = one('.sgp-drawer-data', row);
        var content = one('#sgpDrawerContent', root);
        var drawer = one('#sgpDrawer', root);
        var actions = one('#sgpDrawerActions', root);
        var actionId = document.getElementById('hfAccionId');

        content.innerHTML = source ? source.innerHTML : '';
        drawer.classList.add('is-open');
        root.classList.add('has-drawer');
        actions.hidden = false;

        if (actionId) actionId.value = attr(row, 'data-id');

        var disable = all('[id$="lnkDeshabilitarDetalle"]', root)[0];
        if (disable) disable.hidden = attr(row, 'data-enabled') !== '1';

        paintActiveRow();
    }

    function closeDrawer() {
        drawerDismissed = true;
        activeRow = null;

        one('#sgpDrawer', root).classList.remove('is-open');
        one('#sgpDrawerActions', root).hidden = true;
        root.classList.remove('has-drawer');
        paintActiveRow();
    }

    function paintActiveRow() {
        rows.forEach(function (row) { row.classList.toggle('is-current', row === activeRow); });
    }

    function editActive() {
        if (!activeRow || typeof window.abrirProgramacion !== 'function') return;
        window.abrirProgramacion(attr(activeRow, 'data-query'));
    }

    function showCalendar() {
        if (!activeRow) return;

        var source = one('.sgp-calendar-data', activeRow);
        var modal = one('#sgpCalendarModal', root);
        var content = one('#sgpCalendarContent', root);

        content.innerHTML = source ? source.innerHTML : '';
        modal.hidden = false;
        document.documentElement.classList.add('sgp-modal-open');

        var close = one('.sgp-calendar-dialog [data-sgp-action="close-calendar"]', modal);
        if (close) close.focus();
    }

    function closeCalendar() {
        var modal = one('#sgpCalendarModal', root);
        if (!modal) return;

        modal.hidden = true;
        document.documentElement.classList.remove('sgp-modal-open');
    }

    function openHeaderMenu(button) {
        var menu = one('#sgpHeaderMenu', root);
        var willOpen = menu.hidden;

        closeMenus();
        menu.hidden = !willOpen;
        button.setAttribute('aria-expanded', willOpen ? 'true' : 'false');
    }

    function openRowMenu(button, row) {
        var menu = one('#sgpRowMenu', root);
        var rect = button.getBoundingClientRect();

        menuRow = row;
        openRow(row);
        menu.hidden = false;
        menu.style.left = Math.max(8, rect.right - 190) + 'px';
        menu.style.top = Math.min(window.innerHeight - 190, rect.bottom + 6) + 'px';
        button.setAttribute('aria-expanded', 'true');

        var duplicate = one('[data-sgp-menu-action="duplicate"]', menu);
        var disable = one('[data-sgp-menu-action="disable"]', menu);
        var serverDuplicate = all('[id$="lnkDuplicar"]', root)[0];
        var serverDisable = all('[id$="lnkDeshabilitarDetalle"]', root)[0];

        duplicate.hidden = !serverDuplicate;
        disable.hidden = !serverDisable || attr(row, 'data-enabled') !== '1';
    }

    function closeMenus() {
        var header = one('#sgpHeaderMenu', root);
        var row = one('#sgpRowMenu', root);

        if (header) header.hidden = true;
        if (row) row.hidden = true;

        all('[aria-haspopup="true"]', root).forEach(function (button) {
            button.setAttribute('aria-expanded', 'false');
        });
    }

    function toggleFilters(button) {
        var panel = one('#sgpFilters', root);
        var open = panel.hidden;

        panel.hidden = !open;
        button.setAttribute('aria-expanded', open ? 'true' : 'false');
    }

    function readFilters() {
        state.type = one('#sgpFilterType', root).value;
        state.status = one('#sgpFilterStatus', root).value;
        state.assignment = one('#sgpFilterAssignment', root).value;
        state.exclusions = one('#sgpFilterExclusions', root).value;
        state.page = 1;

        paintFilterCount();
        apply();
    }

    function clearFilters() {
        all('#sgpFilters select', root).forEach(function (select) { select.value = ''; });
        readFilters();
    }

    function paintFilterCount() {
        var count = [state.type, state.status, state.assignment, state.exclusions]
            .filter(function (value) { return value !== ''; }).length;
        var badge = one('#sgpFilterCount', root);

        badge.textContent = count;
        badge.hidden = count === 0;
    }

    function selectedChecks() {
        return all('.sgp-row-check:checked', root).filter(function (check) { return !check.disabled; });
    }

    function syncSelection() {
        var checks = selectedChecks();
        var hidden = document.getElementById('hfSeleccionadas');
        if (hidden) hidden.value = checks.map(function (check) { return check.value; }).join(',');
        return checks;
    }

    function paintSelection() {
        var checks = syncSelection();
        var bar = one('#sgpSelectionBar', root);
        var text = one('#sgpSelectionText', root);
        var total = checks.length;

        bar.classList.toggle('is-visible', total > 0);
        text.textContent = total + (total === 1 ? ' programación seleccionada' : ' programaciones seleccionadas');
        paintMasterCheck();
    }

    function paintMasterCheck() {
        var master = one('#sgpCheckAll', root);
        if (!master) return;

        var visible = currentPageRows().map(function (row) { return one('.sgp-row-check', row); })
            .filter(function (check) { return check && !check.disabled; });
        var selected = visible.filter(function (check) { return check.checked; }).length;

        master.checked = visible.length > 0 && selected === visible.length;
        master.indeterminate = selected > 0 && selected < visible.length;
        master.disabled = visible.length === 0;
    }

    function togglePageSelection(checked) {
        currentPageRows().forEach(function (row) {
            var check = one('.sgp-row-check', row);
            if (check && !check.disabled) check.checked = checked;
        });

        paintSelection();
    }

    function cancelSelection() {
        all('.sgp-row-check', root).forEach(function (check) { check.checked = false; });
        paintSelection();
    }

    function selectVisible() {
        togglePageSelection(true);
        closeMenus();
    }

    function clickServerLink(suffix) {
        var link = all('[id$="' + suffix + '"]', root)[0];
        if (link) link.click();
    }

    function copyId(button) {
        var value = attr(button, 'data-sgp-copy');

        function done() {
            var icon = one('i', button);
            if (!icon) return;
            icon.className = 'mdi mdi-check';
            window.setTimeout(function () { icon.className = 'mdi mdi-content-copy'; }, 1200);
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(value).then(done, function () { fallbackCopy(value); done(); });
            return;
        }

        fallbackCopy(value);
        done();
    }

    function fallbackCopy(value) {
        var input = document.createElement('textarea');
        input.value = value;
        input.setAttribute('readonly', 'readonly');
        input.style.position = 'fixed';
        input.style.opacity = '0';
        document.body.appendChild(input);
        input.select();
        document.execCommand('copy');
        document.body.removeChild(input);
    }

    function showHelp() {
        var text = 'Una programación define cuándo corresponde realizar un trabajo. ' +
                   'El plan de mantenimiento usa esa regla para generar órdenes. ' +
                   'Deshabilitar detiene las nuevas generaciones y conserva el historial.';

        if (window.Swal) Swal.fire('¿Cómo funcionan?', text, 'info');
        else window.alert(text);
    }

    function menuAction(name) {
        if (menuRow) openRow(menuRow);
        closeMenus();

        if (name === 'edit') editActive();
        if (name === 'calendar') showCalendar();
        if (name === 'duplicate') clickServerLink('lnkDuplicar');
        if (name === 'disable') clickServerLink('lnkDeshabilitarDetalle');
    }

    function clickHandler(event) {
        var target = event.target;
        var actionElement = closest(target, '[data-sgp-action]');
        var pageButton = closest(target, '[data-sgp-page]');
        var tabButton = closest(target, '[data-sgp-tab]');
        var menuButton = closest(target, '[data-sgp-menu-action]');
        var copyButton = closest(target, '[data-sgp-copy]');

        if (copyButton) {
            event.preventDefault();
            copyId(copyButton);
            return;
        }

        if (pageButton) {
            event.preventDefault();
            if (!pageButton.disabled) changePage(attr(pageButton, 'data-sgp-page'));
            return;
        }

        if (tabButton) {
            event.preventDefault();
            selectTab(attr(tabButton, 'data-sgp-tab'));
            return;
        }

        if (menuButton) {
            event.preventDefault();
            menuAction(attr(menuButton, 'data-sgp-menu-action'));
            return;
        }

        if (actionElement) {
            var action = attr(actionElement, 'data-sgp-action');
            var row = closest(actionElement, '.sgp-row');

            if (action === 'open-row') openRow(row);
            else if (action === 'row-menu') openRowMenu(actionElement, row);
            else if (action === 'header-menu') openHeaderMenu(actionElement);
            else if (action === 'filters') toggleFilters(actionElement);
            else if (action === 'clear-filters') clearFilters();
            else if (action === 'cancel-selection') cancelSelection();
            else if (action === 'select-visible') selectVisible();
            else if (action === 'refresh' && typeof window.refresh === 'function') window.refresh();
            else if (action === 'close-drawer') closeDrawer();
            else if (action === 'edit') editActive();
            else if (action === 'calendar') showCalendar();
            else if (action === 'close-calendar') closeCalendar();
            else if (action === 'help') showHelp();

            if (action !== 'filters') event.preventDefault();
            return;
        }

        var rowTarget = closest(target, '.sgp-row');
        if (rowTarget && !closest(target, 'input, a, button, select')) openRow(rowTarget);
    }

    function changeHandler(event) {
        var target = event.target;

        if (target.classList.contains('sgp-row-check')) paintSelection();
        else if (target.id === 'sgpCheckAll') togglePageSelection(target.checked);
        else if (target.id === 'sgpSort') {
            state.sort = target.value;
            state.page = 1;
            apply();
        } else if (target.id === 'sgpPageSize') {
            state.pageSize = asNumber(target.value) || 25;
            state.page = 1;
            apply();
        } else if (closest(target, '#sgpFilters')) readFilters();
    }

    function init() {
        root = document.getElementById('sgpProgramaciones');
        window.sgpListRoot = root;
        if (!root) return;

        rows = all('.sgp-row', root);
        activeRow = null;
        menuRow = null;
        drawerDismissed = false;
        state = {
            tab: 'todas',
            page: 1,
            pageSize: 25,
            sort: 'next',
            search: '',
            type: '',
            status: '',
            assignment: '',
            exclusions: ''
        };

        rows.forEach(function (row) {
            var check = one('.sgp-row-check', row);
            if (check && attr(row, 'data-enabled') !== '1') check.disabled = true;
        });

        root.onclick = clickHandler;
        root.onchange = changeHandler;

        var search = one('#sgpSearch', root);
        search.oninput = function () {
            state.search = search.value;
            state.page = 1;
            apply();
        };

        apply();
        paintSelection();
    }

    window.sgpConfirmarSeleccion = function (button) {
        if (!root) init();

        var selected = syncSelection();
        if (selected.length === 0) {
            if (window.Swal) Swal.fire('', 'Seleccione al menos una programación.', 'warning');
            else window.alert('Seleccione al menos una programación.');
            return false;
        }

        var message = selected.length === 1
            ? '¿Deshabilitar la programación seleccionada?'
            : '¿Deshabilitar las ' + selected.length + ' programaciones seleccionadas?';

        return window.ConfirSweetAlert ? ConfirSweetAlert(button, '', message) : window.confirm(message);
    };

    if (!window.sgpGlobalEvents) {
        window.sgpGlobalEvents = true;

        document.addEventListener('click', function (event) {
            var currentRoot = window.sgpListRoot;
            if (!currentRoot) return;

            if (!closest(event.target, '.sgp-menu') && !closest(event.target, '[aria-haspopup="true"]')) {
                var header = one('#sgpHeaderMenu', currentRoot);
                var row = one('#sgpRowMenu', currentRoot);
                if (header) header.hidden = true;
                if (row) row.hidden = true;
            }

            var filters = one('#sgpFilters', currentRoot);
            if (filters && !filters.hidden && !closest(event.target, '.sgp-filter-wrap')) {
                filters.hidden = true;
                var trigger = one('[data-sgp-action="filters"]', currentRoot);
                if (trigger) trigger.setAttribute('aria-expanded', 'false');
            }
        });

        document.addEventListener('keydown', function (event) {
            if (event.keyCode !== 27 || !window.sgpListRoot) return;

            var modal = one('#sgpCalendarModal', window.sgpListRoot);
            if (modal && !modal.hidden) closeCalendar();
            else closeMenus();
        });
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(init);
})();
