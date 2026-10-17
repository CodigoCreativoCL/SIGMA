/* ============================================================================
   SIGMA · COMBO DE SIGMA SOBRE LOS RadComboBox (17-10-2026)

   Toda lista desplegable del sitio usa el SigmaCombo (Js/sigma-combo.js). Las páginas WebForms viejas declaran
   <rad:RadComboBox2>; este adaptador pone un SigmaCombo en su lugar y oculta el de Telerik, que sigue siendo la fuente de
   verdad: al elegir se llama a item.select() del RadComboBox, así que el estado del cliente, las validaciones, el
   AutoPostBack y el servidor funcionan igual que antes.

   Se adaptan los combos de selección simple. Quedan con Telerik los que no se pueden reproducir sin perder función:
   los de casillas (CheckBoxes), los que cargan por demanda, los deshabilitados y los del paginador/filtros de grilla.
   Para apagarlo en una página: window.SIGMA_SIN_COMBO_NUEVO = true.
   ============================================================================ */
(function (window, document) {
    'use strict';

    var PREF = 'sgad_';

    function adaptable(combo, root) {
        if (!combo || !combo.get_items || !combo.get_enabled || !combo.get_enabled()) return false;
        if (combo.get_checkBoxes && combo.get_checkBoxes()) return false;
        if (combo.get_enableLoadOnDemand && combo.get_enableLoadOnDemand()) return false;
        if (root.closest('.rgPager, .rgFilterRow, .rcbSlide')) return false;
        return combo.get_items().get_count() > 0;
    }

    function adaptar() {
        if (window.SIGMA_SIN_COMBO_NUEVO || !window.SigmaCombo || !window.$find) return;
        [].slice.call(document.querySelectorAll('.RadComboBox')).forEach(function (root) {
            if (!root.id || root.getAttribute('data-sg-ad')) return;
            try {
                var combo = window.$find(root.id);
                if (!adaptable(combo, root)) return;
                var items = combo.get_items(), lista = [], i, n = items.get_count();
                for (i = 0; i < n; i++) lista.push({ id: String(i), n: items.getItem(i).get_text() });
                var sel = combo.get_selectedIndex();
                var vacio = null;
                for (i = 0; i < n; i++) if (items.getItem(i).get_value() === '' || items.getItem(i).get_value() === '0') { vacio = i; break; }
                var ph = vacio != null ? items.getItem(vacio).get_text() : 'Seleccione';
                var html = window.SigmaCombo.html(PREF + root.id, lista, sel >= 0 ? String(sel) : '', { ph: ph, clave: PREF + root.id, etiqueta: ph });
                root.insertAdjacentHTML('beforebegin', html);
                var caja = root.previousElementSibling;
                caja.setAttribute('data-sg-ad-de', root.id);
                var ancho = root.style.width;
                if (ancho) { caja.style.display = 'block'; caja.style.width = ancho.replace(/\s*!important/, ''); }
                root.style.display = 'none';
                root.setAttribute('data-sg-ad', '1');
            } catch (e) { /* si algo falla, el combo de Telerik queda visible y funciona como siempre */ }
        });
    }

    document.addEventListener('change', function (e) {
        var inp = e.target;
        if (!inp || !inp.matches || !inp.matches('input[data-sgcombo^="' + PREF + '"]')) return;
        var id = inp.getAttribute('data-sgcombo').slice(PREF.length);
        var hid = inp.parentNode.querySelector('input[type=hidden]');
        try {
            var combo = window.$find(id);
            if (!combo) return;
            var items = combo.get_items(), v = hid ? hid.value : '', item = null;
            if (v !== '') item = items.getItem(parseInt(v, 10));
            else for (var i = 0; i < items.get_count(); i++) { var x = items.getItem(i); if (x.get_value() === '' || x.get_value() === '0') { item = x; break; } }
            if (item && combo.get_selectedIndex() !== item.get_index()) item.select();
        } catch (ex) {
            /* sin acceso al combo de Telerik: se vuelve a mostrar para que la persona no quede bloqueada */
            var root = document.getElementById(id); if (root) { root.style.display = ''; var c = inp.closest('[data-sg-ad-de]'); if (c) c.parentNode.removeChild(c); }
        }
    });

    function iniciar() {
        adaptar();
        try {
            if (window.Sys && window.Sys.Application) window.Sys.Application.add_load(adaptar);
            var prm = window.Sys && window.Sys.WebForms && window.Sys.WebForms.PageRequestManager.getInstance();
            if (prm) prm.add_endRequest(function () { window.setTimeout(adaptar, 0); });
        } catch (e) { }
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar);
    else iniciar();
    window.SigmaComboAdaptador = { adaptar: adaptar };
})(window, document);
