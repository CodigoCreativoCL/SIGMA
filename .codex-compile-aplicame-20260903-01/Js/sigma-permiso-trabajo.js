(function (window, document) {
    'use strict';

    var hooked = false;

    function bySuffix(root, suffix) {
        return root.querySelector('[id$="_' + suffix + '"], [id$="' + suffix + '"]');
    }

    function combo(root, name) {
        var host = bySuffix(root, name);
        if (!host) return { value: '', text: '' };
        try {
            var control = window.$find && window.$find(host.id);
            if (control) return { value: String(control.get_value() || ''), text: String(control.get_text() || '') };
        } catch (ignore) { }
        var input = host.querySelector ? host.querySelector('input[type="text"]') : null;
        return { value: host.value || '', text: input ? input.value : (host.value || '') };
    }

    function input(root, name) {
        var host = bySuffix(root, name);
        if (!host) return '';
        var nested = host.matches && host.matches('input,textarea') ? host : host.querySelector('input,textarea');
        return nested ? String(nested.value || '').trim() : '';
    }

    function hasNewFile(root) {
        var files = root.querySelectorAll('input[type="file"]');
        for (var i = 0; i < files.length; i++) if (files[i].value) return true;
        return false;
    }

    function parseDate(value) {
        var parts = String(value || '').match(/^(\d{1,2})[-\/]([0-1]?\d)[-\/](\d{4})$/);
        if (!parts) return null;
        return new Date(Number(parts[3]), Number(parts[2]) - 1, Number(parts[1]));
    }

    function summary(root, key, value) {
        var node = root.querySelector('[data-sg-summary="' + key + '"]');
        if (node) node.textContent = value;
    }

    function state(button, value) {
        button.classList.remove('is-complete', 'is-incomplete', 'is-error');
        button.classList.add('is-' + value);
        button.setAttribute('data-status', value);
    }

    function refresh(root) {
        var tipo = combo(root, 'cboTipo');
        var responsable = combo(root, 'cboSolicitante');
        var orden = combo(root, 'cboOrden');
        var estado = combo(root, 'cboEstado');
        var folio = input(root, 'txtNumero');
        var detalle = input(root, 'txtObservacion');
        var desdeText = input(root, 'calDesde');
        var hastaText = input(root, 'calHasta');
        var desde = parseDate(desdeText);
        var hasta = parseDate(hastaText);
        var documento = root.getAttribute('data-documento') === '1' || hasNewFile(root);
        var autorizado = estado.text.toLowerCase() === 'autorizado';
        var fechaError = desde && hasta && hasta.getTime() < desde.getTime();

        var buttons = root.querySelectorAll('[data-sg-permit-tab]');
        for (var i = 0; i < buttons.length; i++) {
            var key = buttons[i].getAttribute('data-sg-permit-tab');
            if (key === 'general') state(buttons[i], tipo.value ? 'complete' : 'incomplete');
            else if (key === 'responsable' || key === 'trabajo') state(buttons[i], 'complete');
            else if (key === 'vigencia') state(buttons[i], fechaError || !estado.value ? 'error' : 'complete');
            else if (key === 'documentos') state(buttons[i], autorizado && !documento ? 'error' : (documento ? 'complete' : 'incomplete'));
        }

        var invalid = !tipo.value || !estado.value || fechaError || (autorizado && !documento);
        var review = root.querySelector('[data-sg-permit-tab="revision"]');
        if (review) state(review, invalid ? 'error' : 'complete');

        summary(root, 'tipo', tipo.value ? tipo.text : 'Sin tipo seleccionado');
        summary(root, 'folio', folio ? 'Folio ' + folio : 'Sin folio');
        summary(root, 'responsable', responsable.text || 'Yo mismo');
        summary(root, 'orden', orden.value ? orden.text : 'Sin orden asociada');
        summary(root, 'detalle', detalle || 'Sin observación');
        summary(root, 'vigencia', desdeText || hastaText ? (desdeText || 'Sin inicio') + ' → ' + (hastaText || 'Sin término') : 'Sin fechas definidas');
        summary(root, 'estado', estado.text || 'Sin estado');
        summary(root, 'documento', documento ? 'Documento adjunto' : 'Sin documento adjunto');

        var validation = root.querySelector('[data-sg-permit-validation]');
        if (validation) {
            validation.classList.toggle('is-error', invalid);
            if (!tipo.value) validation.innerHTML = '<i class="mdi mdi-alert-circle-outline"></i> Falta seleccionar el tipo de permiso.';
            else if (!estado.value) validation.innerHTML = '<i class="mdi mdi-alert-circle-outline"></i> Falta seleccionar el estado.';
            else if (fechaError) validation.innerHTML = '<i class="mdi mdi-alert-circle-outline"></i> La fecha de término es anterior a la fecha de inicio.';
            else if (autorizado && !documento) validation.innerHTML = '<i class="mdi mdi-file-alert-outline"></i> Para autorizar debe adjuntar el documento firmado.';
            else validation.innerHTML = '<i class="mdi mdi-check-circle-outline"></i> El permiso está listo para guardar.';
        }
    }

    function show(root, name, focusTab) {
        var panels = root.querySelectorAll('[data-sg-permit-panel]');
        var tabs = root.querySelectorAll('[data-sg-permit-tab]');
        var activeTab = null;
        for (var i = 0; i < panels.length; i++) {
            var active = panels[i].getAttribute('data-sg-permit-panel') === name;
            panels[i].hidden = !active;
            panels[i].classList.toggle('is-active', active);
        }
        for (var j = 0; j < tabs.length; j++) {
            var selected = tabs[j].getAttribute('data-sg-permit-tab') === name;
            tabs[j].classList.toggle('is-active', selected);
            tabs[j].setAttribute('aria-selected', selected ? 'true' : 'false');
            if (selected) activeTab = tabs[j];
        }
        var hidden = bySuffix(root, 'hidPaso');
        if (hidden) hidden.value = name;
        if (focusTab && activeTab) activeTab.focus();
        refresh(root);
    }

    function init() {
        var root = document.querySelector('.sg-permit-modal');
        if (!root || root.getAttribute('data-sg-ready') === '1') return;
        root.setAttribute('data-sg-ready', '1');

        root.addEventListener('click', function (event) {
            var tab = event.target.closest && event.target.closest('[data-sg-permit-tab]');
            var next = event.target.closest && event.target.closest('[data-sg-permit-next]');
            var back = event.target.closest && event.target.closest('[data-sg-permit-back]');
            if (tab) show(root, tab.getAttribute('data-sg-permit-tab'), true);
            else if (next) show(root, next.getAttribute('data-sg-permit-next'), true);
            else if (back) show(root, back.getAttribute('data-sg-permit-back'), true);
        });
        root.addEventListener('input', function () { refresh(root); });
        root.addEventListener('change', function () { window.setTimeout(function () { refresh(root); }, 0); });

        var hidden = bySuffix(root, 'hidPaso');
        show(root, hidden && hidden.value ? hidden.value : 'general', false);
    }

    function boot() {
        init();
        if (!hooked && window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
            hooked = true;
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(init);
        }
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})(window, document);
